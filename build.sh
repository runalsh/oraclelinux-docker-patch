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
    GHCR_IMAGE_NAME="ghcr.io/$(echo "${IMAGE_NAME}" | tr '[:upper:]' '[:lower:]')"
    FULL_GHCR_TAG="${GHCR_IMAGE_NAME}:${tag}"

    MAJOR_VER="${tag%%.*}"
    LATEST_IN_TRACK=$(grep -E "^${MAJOR_VER}\." "$RELEASES_FILE" | sort -V | tail -n 1 | awk '{print $1}')
    
    IS_LATEST_MAJOR=false
    if [ "$tag" = "$LATEST_IN_TRACK" ]; then
        IS_LATEST_MAJOR=true
        echo "Tag ${tag} is the latest for major version ${MAJOR_VER}. Will also tag as major tag ${MAJOR_VER}!"
    fi

    NEEDS_DOCKERHUB_PUSH=false
    NEEDS_GHCR_PUSH=false

    if [ "${SKIP_EXISTS_CHECK:-false}" = "true" ]; then
        echo "SKIP_EXISTS_CHECK is true. Forcing build and push for ${tag}..."
        [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ] && NEEDS_DOCKERHUB_PUSH=true
        [ "${PUSH_TO_GHCR:-false}" = "true" ] && NEEDS_GHCR_PUSH=true
    else
        if [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ]; then
            if ! docker manifest inspect "${FULL_IMAGE_TAG}" &>/dev/null && ! curl -sfSL "https://hub.docker.com/v2/repositories/${IMAGE_NAME}/tags/${tag}/" &>/dev/null; then
                echo "Tag ${FULL_IMAGE_TAG} missing on Docker Hub."
                NEEDS_DOCKERHUB_PUSH=true
            fi
        fi

        if [ "${PUSH_TO_GHCR:-false}" = "true" ]; then
            if ! docker manifest inspect "${FULL_GHCR_TAG}" &>/dev/null; then
                echo "Tag ${FULL_GHCR_TAG} missing on GHCR."
                NEEDS_GHCR_PUSH=true
            fi
        fi

        if [ "${NEEDS_DOCKERHUB_PUSH}" = "false" ] && [ "${NEEDS_GHCR_PUSH}" = "false" ]; then
            if [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ] || [ "${PUSH_TO_GHCR:-false}" = "true" ]; then
                echo "Tag ${tag} already exists on all enabled remote registries. Skipping download and build!"
                echo
                continue
            fi
        fi
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

    echo "5. Creating optimized rootfs tar archive (excluding kernel, modules, firmware, grub, caches, docs)..."
    sudo tar -C "${MOUNT_DIR}"         --exclude="./usr/lib/modules"         --exclude="./lib/modules"         --exclude="./boot/vmlinuz*"         --exclude="./boot/initramfs*"         --exclude="./boot/System.map*"         --exclude="./usr/lib/firmware"         --exclude="./lib/firmware"         --exclude="./usr/lib/grub*"         --exclude="./boot/grub*"         --exclude="./etc/grub.d"         --exclude="./usr/share/GeoIP"         --exclude="./var/cache/dnf/*"         --exclude="./var/cache/yum/*"         --exclude="./usr/share/doc/*"         --exclude="./usr/share/man/*"         --exclude="./usr/share/info/*"         --exclude="./tmp/*"         --exclude="./var/log/*"         --exclude="./var/tmp/*"         -czf "${TAR_FILE}" .

    echo "6. Importing rootfs into Docker as ${FULL_IMAGE_TAG}..."
    docker import       -c 'ENV container=docker'       -c 'ENV LANG=en_US.UTF-8'       -c 'CMD ["/bin/bash"]'       "${TAR_FILE}" "${FULL_IMAGE_TAG}"

    if [ "${TEST_VERSION:-true}" = "true" ]; then
        echo "7. Verifying container functionality and release version..."
        RELEASE_INFO=$(docker run --rm "${FULL_IMAGE_TAG}" cat /etc/oracle-release || docker run --rm "${FULL_IMAGE_TAG}" cat /etc/os-release)
        echo "$RELEASE_INFO"
    fi

    if command -v trivy &>/dev/null || [ "${ENABLE_TRIVY_SCAN:-false}" = "true" ]; then
        echo "8. Generating Trivy SBOM and vulnerability files (silent console)..."
        trivy image --format spdx-json --output "trivy-reports/sbom-${tag}.json" "${FULL_IMAGE_TAG}" 2>/dev/null || true
        trivy image --format json --output "trivy-reports/vulnerabilities-${tag}.json" "${FULL_IMAGE_TAG}" 2>/dev/null || true
    fi

    if [ "${NEEDS_DOCKERHUB_PUSH}" = "true" ] || [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ]; then
        echo "9. Pushing image to Docker Hub (${FULL_IMAGE_TAG})..."
        docker push "${FULL_IMAGE_TAG}" || true
        if [ "$IS_LATEST_MAJOR" = "true" ]; then
            MAJOR_TAG="${IMAGE_NAME}:${MAJOR_VER}"
            echo "Pushing major alias tag to Docker Hub (${MAJOR_TAG})..."
            docker tag "${FULL_IMAGE_TAG}" "${MAJOR_TAG}"
            docker push "${MAJOR_TAG}" || true
        fi
    else
        echo "9. Skipping Docker Hub push."
    fi

    if [ "${NEEDS_GHCR_PUSH}" = "true" ] || [ "${PUSH_TO_GHCR:-false}" = "true" ]; then
        echo "10. Pushing image to GitHub Packages / GHCR (${FULL_GHCR_TAG})..."
        docker tag "${FULL_IMAGE_TAG}" "${FULL_GHCR_TAG}"
        docker push "${FULL_GHCR_TAG}" || true
        if [ "$IS_LATEST_MAJOR" = "true" ]; then
            GHCR_MAJOR_TAG="${GHCR_IMAGE_NAME}:${MAJOR_VER}"
            echo "Pushing major alias tag to GHCR (${GHCR_MAJOR_TAG})..."
            docker tag "${FULL_IMAGE_TAG}" "${GHCR_MAJOR_TAG}"
            docker push "${GHCR_MAJOR_TAG}" || true
            if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ]; then
                docker rmi -f "${GHCR_MAJOR_TAG}" 2>/dev/null || true
            fi
        fi
        if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ]; then
            docker rmi -f "${FULL_GHCR_TAG}" 2>/dev/null || true
        fi
    else
        echo "10. Skipping GHCR push."
    fi

    echo "11. Cleaning up temporary mounts and files..."
    sudo umount "${MOUNT_DIR}" 2>/dev/null || true
    sudo vgchange -an 2>/dev/null || true
    sudo qemu-nbd -d /dev/nbd0 2>/dev/null || true
    sudo rm -rf "${QCOW_FILE}" "${TAR_FILE}" "${MOUNT_DIR}"

    if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ]; then
        echo "Removing local Docker image ${FULL_IMAGE_TAG} to save disk space..."
        docker rmi -f "${FULL_IMAGE_TAG}" 2>/dev/null || true
    fi

    echo "Successfully completed processing for tag ${tag}!"
    echo
done < "$RELEASES_FILE"

echo "All Oracle Linux images processed successfully!"
