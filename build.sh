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

sudo modprobe nbd max_part=16 2>/dev/null || true

echo "Starting QCOW2 -> Docker build process for repository: ${IMAGE_NAME}"

while read -r tag url || [ -n "$tag" ]; do
    [[ -z "$tag" || "$tag" =~ ^# ]] && continue

    echo "=========================================="
    echo "Processing tag: ${tag}"
    echo "URL: ${url}"
    echo "=========================================="

    QCOW2_FILE="temp_${tag}.qcow2"
    TAR_FILE="temp_${tag}.tar.gz"
    MOUNT_DIR="/mnt/oraclelinux_root"

    sudo qemu-nbd -d /dev/nbd0 2>/dev/null || true
    sudo vgchange -an 2>/dev/null || true
    sudo umount -f "${MOUNT_DIR}" 2>/dev/null || true
    sudo rm -rf "${MOUNT_DIR}"
    mkdir -p "${MOUNT_DIR}"

    echo "1. Downloading QCOW2 image..."
    curl -fSL -o "${QCOW2_FILE}" "${url}"

    echo "2. Attaching QCOW2 to NBD block device..."
    sudo qemu-nbd -c /dev/nbd0 "${QCOW2_FILE}"
    sleep 2

    echo "3. Scanning LVM volume groups and partitions..."
    sudo vgscan --mknodes 2>/dev/null || true
    sudo vgchange -ay 2>/dev/null || true

    ROOT_DEV=""
    if [ -b "/dev/vg_main/lv_root" ]; then
        ROOT_DEV="/dev/vg_main/lv_root"
    elif [ -b "/dev/nbd0p4" ]; then
        ROOT_DEV="/dev/nbd0p4"
    elif [ -b "/dev/nbd0p2" ]; then
        ROOT_DEV="/dev/nbd0p2"
    elif [ -b "/dev/nbd0p1" ]; then
        ROOT_DEV="/dev/nbd0p1"
    else
        ROOT_DEV="/dev/nbd0"
    fi

    echo "Found root device: ${ROOT_DEV}"

    echo "4. Mounting root filesystem..."
    sudo mount "${ROOT_DEV}" "${MOUNT_DIR}"

    echo "5. Creating rootfs tar archive..."
    sudo tar -C "${MOUNT_DIR}" -czf "${TAR_FILE}" .

    FULL_IMAGE_TAG="${IMAGE_NAME}:${tag}"

    echo "6. Importing rootfs into Docker as ${FULL_IMAGE_TAG}..."
    docker import "${TAR_FILE}" "${FULL_IMAGE_TAG}"

    if [ "${TEST_VERSION:-true}" = "true" ]; then
        echo "7. Verifying container functionality and release version..."
        RELEASE_INFO=$(docker run --rm "${FULL_IMAGE_TAG}" cat /etc/oracle-release || docker run --rm "${FULL_IMAGE_TAG}" cat /etc/os-release)
        echo "$RELEASE_INFO"
    fi

    if [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ]; then
        echo "8. Pushing image to Docker Hub..."
        docker push "${FULL_IMAGE_TAG}"
    else
        echo "8. Skipping Docker Hub push."
    fi

    echo "9. Cleaning up temporary mounts and files..."
    sudo umount "${MOUNT_DIR}"
    sudo vgchange -an vg_main 2>/dev/null || true
    sudo qemu-nbd -d /dev/nbd0 2>/dev/null || true
    rm -rf "${QCOW2_FILE}" "${TAR_FILE}" "${MOUNT_DIR}"

    echo "Successfully completed processing for tag ${tag}!"
    echo
done < "$RELEASES_FILE"

echo "All Oracle Linux images processed successfully!"
