#!/bin/bash
set -euo pipefail

IMAGE_NAME="runalsh/oraclelinux-patch"
RELEASES_FILE="releases.txt"

install_system_packages() {
    echo "Checking and installing required system packages..."
    if command -v apt-get &>/dev/null; then
        echo "Detected apt package manager."
        sudo apt-get update -qq || true
        sudo apt-get install -y -qq qemu-utils lvm2 xfsprogs e2fsprogs parted curl tar
    elif command -v dnf &>/dev/null; then
        echo "Detected dnf package manager."
        sudo dnf install -y qemu-img lvm2 xfsprogs e2fsprogs parted curl tar
    elif command -v yum &>/dev/null; then
        echo "Detected yum package manager."
        sudo yum install -y qemu-img lvm2 xfsprogs e2fsprogs parted curl tar
    else
        echo "WARNING: Ensure qemu-utils (qemu-nbd), lvm2, parted, and tar are installed."
    fi
}

install_system_packages

if [ ! -f "$RELEASES_FILE" ]; then
    echo "Error: $RELEASES_FILE not found!"
    exit 1
fi

mkdir -p trivy-reports

sudo modprobe nbd max_part=16 2>/dev/null || true

echo "Starting QCOW/QCOW2 -> Docker build process for repository: ${IMAGE_NAME}"

while read -r tag url || [ -n "$tag" ]; do
    [[ -z "$tag" || "$tag" =~ ^# ]] && continue

    echo "=========================================="
    echo "Processing tag: ${tag}"
    echo "URL: ${url}"
    echo "=========================================="

    FULL_IMAGE_TAG="${IMAGE_NAME}:${tag}"

    if [ "${SKIP_EXISTS_CHECK:-false}" != "true" ]; then
        echo "Checking if ${FULL_IMAGE_TAG} already exists on Docker Hub..."
        if docker manifest inspect "${FULL_IMAGE_TAG}" &>/dev/null || curl -sfSL "https://hub.docker.com/v2/repositories/${IMAGE_NAME}/tags/${tag}/" &>/dev/null; then
            echo "Tag ${FULL_IMAGE_TAG} already exists on Docker Hub. Skipping download and build!"
            echo
            continue
        fi
        echo "Tag ${FULL_IMAGE_TAG} not found on Docker Hub. Proceeding with build..."
    else
        echo "SKIP_EXISTS_CHECK is 'true'. Skipping Docker Hub check and forcing build for ${FULL_IMAGE_TAG}..."
    fi

    EXT="${url##*.}"
    QCOW_FILE="temp_${tag}.${EXT}"
    TAR_FILE="temp_${tag}.tar.gz"
    MOUNT_DIR="/mnt/oraclelinux_root"

    # Pre-cleanup in case previous run was interrupted
    sudo qemu-nbd -d /dev/nbd0 2>/dev/null || true
    sudo vgchange -an 2>/dev/null || true
    sudo umount -f "${MOUNT_DIR}" 2>/dev/null || true
    sudo rm -rf "${MOUNT_DIR}" "${QCOW_FILE}" "${TAR_FILE}"
    sudo mkdir -p "${MOUNT_DIR}"

    echo "1. Downloading QCOW image (${EXT})..."
    curl -fSL -o "${QCOW_FILE}" "${url}"

    echo "2. Attaching QCOW image to NBD block device..."
    sudo qemu-nbd -c /dev/nbd0 "${QCOW_FILE}"
    sleep 2

    echo "3. Dynamically discovering root partition/volume..."
    sudo vgscan --mknodes 2>/dev/null || true
    sudo vgchange -ay 2>/dev/null || true

    ROOT_DEV=""
    TEST_MOUNT_POINT="/tmp/check_root_fs"
    sudo rm -rf "${TEST_MOUNT_POINT}"
    sudo mkdir -p "${TEST_MOUNT_POINT}"

    # Check all LVM logical volumes dynamically
    for lv in $(sudo lvs --noheadings -o lv_path 2>/dev/null || true); do
        if sudo mount -o ro "${lv}" "${TEST_MOUNT_POINT}" 2>/dev/null; then
            if [ -f "${TEST_MOUNT_POINT}/etc/oracle-release" ] || [ -f "${TEST_MOUNT_POINT}/etc/os-release" ]; then
                ROOT_DEV="${lv}"
                sudo umount "${TEST_MOUNT_POINT}"
                break
            fi
            sudo umount "${TEST_MOUNT_POINT}"
        fi
    done

    # If no LVM root found, check raw partitions /dev/nbd0p* and /dev/nbd0
    if [ -z "${ROOT_DEV}" ]; then
        for part in /dev/nbd0p* /dev/nbd0; do
            [ -b "${part}" ] || continue
            if sudo mount -o ro "${part}" "${TEST_MOUNT_POINT}" 2>/dev/null; then
                if [ -f "${TEST_MOUNT_POINT}/etc/oracle-release" ] || [ -f "${TEST_MOUNT_POINT}/etc/os-release" ]; then
                    ROOT_DEV="${part}"
                    sudo umount "${TEST_MOUNT_POINT}"
                    break
                fi
                sudo umount "${TEST_MOUNT_POINT}"
            fi
        done
    fi

    sudo rm -rf "${TEST_MOUNT_POINT}"

    if [ -z "${ROOT_DEV}" ]; then
        echo "ERROR: Could not locate root filesystem containing /etc/os-release!"
        sudo qemu-nbd -d /dev/nbd0 2>/dev/null || true
        exit 1
    fi

    echo "Found root device: ${ROOT_DEV}"

    echo "4. Mounting root filesystem..."
    sudo mount "${ROOT_DEV}" "${MOUNT_DIR}"

    echo "5. Creating rootfs tar archive..."
    sudo tar -C "${MOUNT_DIR}" -czf "${TAR_FILE}" .

    echo "6. Importing rootfs into Docker as ${FULL_IMAGE_TAG}..."
    docker import "${TAR_FILE}" "${FULL_IMAGE_TAG}"

    if [ "${TEST_VERSION:-true}" = "true" ]; then
        echo "7. Verifying container functionality and release version..."
        RELEASE_INFO=$(docker run --rm "${FULL_IMAGE_TAG}" cat /etc/oracle-release || docker run --rm "${FULL_IMAGE_TAG}" cat /etc/os-release)
        echo "$RELEASE_INFO"
    fi

    if command -v trivy &>/dev/null || [ "${ENABLE_TRIVY_SCAN:-false}" = "true" ]; then
        echo "8. Generating SBOM and scanning vulnerabilities with Trivy..."
        trivy image --format spdx-json --output "trivy-reports/sbom-${tag}.json" "${FULL_IMAGE_TAG}" 2>/dev/null || true
        echo "--- Trivy Vulnerability Report for ${FULL_IMAGE_TAG} ---"
        trivy image --exit-code 0 --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL "${FULL_IMAGE_TAG}" || true
        echo "--------------------------------------------------------"
    fi

    if [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ]; then
        echo "9. Pushing image to Docker Hub..."
        docker push "${FULL_IMAGE_TAG}"
    else
        echo "9. Skipping Docker Hub push."
    fi

    echo "10. Cleaning up temporary mounts and files..."
    sudo umount "${MOUNT_DIR}" 2>/dev/null || true
    sudo vgchange -an 2>/dev/null || true
    sudo qemu-nbd -d /dev/nbd0 2>/dev/null || true
    sudo rm -rf "${QCOW_FILE}" "${TAR_FILE}" "${MOUNT_DIR}"

    if [ "${CLEANUP_DOCKER_IMAGES:-false}" = "true" ]; then
        echo "Removing local Docker image ${FULL_IMAGE_TAG} to save disk space..."
        docker rmi -f "${FULL_IMAGE_TAG}" 2>/dev/null || true
    fi

    echo "Successfully completed processing for tag ${tag}!"
    echo
done < "$RELEASES_FILE"

echo "All Oracle Linux images processed successfully!"
