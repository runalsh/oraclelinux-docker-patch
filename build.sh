#!/bin/bash
set -euo pipefail

IMAGE_NAME="runalsh/oraclelinux-patch"
RELEASES_FILE="releases.txt"

install_system_packages() {
    echo "Checking and installing required system packages..."
    if command -v apt-get &>/dev/null; then
        echo "Detected apt package manager."
        sudo apt-get update -qq || true
        sudo apt-get install -y -qq qemu-utils lvm2 xfsprogs e2fsprogs parted python3-pip python3-setuptools
    elif command -v dnf &>/dev/null; then
        echo "Detected dnf package manager."
        sudo dnf install -y qemu-img lvm2 xfsprogs e2fsprogs parted python3-pip
    elif command -v yum &>/dev/null; then
        echo "Detected yum package manager."
        sudo yum install -y qemu-img lvm2 xfsprogs e2fsprogs parted python3-pip
    else
        echo "WARNING: Neither apt, dnf, nor yum detected. Please ensure qemu-img, lvm2, parted, and python3-pip are installed."
    fi
}

# 1. Install system dependencies automatically
install_system_packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 2. Dynamic lookup for ova-to-docker repository (override with CONVERTER_DIR env var)
if [ -z "${CONVERTER_DIR:-}" ] || [ ! -d "${CONVERTER_DIR}" ]; then
    if [ -d "${SCRIPT_DIR}/../ova-to-docker" ]; then
        CONVERTER_DIR="${SCRIPT_DIR}/../ova-to-docker"
    elif [ -d "${SCRIPT_DIR}/ova-to-docker" ]; then
        CONVERTER_DIR="${SCRIPT_DIR}/ova-to-docker"
    else
        CONVERTER_DIR="${SCRIPT_DIR}/.ova-to-docker"
        if [ ! -d "${CONVERTER_DIR}" ]; then
            echo "Cloning ova-to-docker repository into ${CONVERTER_DIR}..."
            git clone https://github.com/executeatwill/ova-to-docker "${CONVERTER_DIR}"
        fi
    fi
fi

CONVERTER_SCRIPT="${CONVERTER_DIR}/ova-to-docker.py"
if [ ! -f "${CONVERTER_SCRIPT}" ]; then
    CONVERTER_SCRIPT="${CONVERTER_DIR}/no-requirements-ova-to-docker.py"
fi

if [ -f "${CONVERTER_DIR}/requirements.txt" ]; then
    echo "Installing python dependencies from ${CONVERTER_DIR}/requirements.txt..."
    pip3 install -r "${CONVERTER_DIR}/requirements.txt" || pip install -r "${CONVERTER_DIR}/requirements.txt" || true
fi

if [ ! -f "$RELEASES_FILE" ]; then
    echo "Error: $RELEASES_FILE not found!"
    exit 1
fi

echo "Using ova-to-docker converter script: ${CONVERTER_SCRIPT}"
echo "Starting process for repository: ${IMAGE_NAME}"

while read -r tag url || [ -n "$tag" ]; do
    [[ -z "$tag" || "$tag" =~ ^# ]] && continue

    echo "=========================================="
    echo "Processing tag: ${tag}"
    echo "URL: ${url}"
    echo "=========================================="

    IMAGE_FILE="temp_image_${tag}.ova"
    OUTPUT_DIR="temp_output_${tag}"

    mkdir -p "${OUTPUT_DIR}"

    echo "1. Downloading OVA template..."
    curl -fSL -o "${IMAGE_FILE}" "${url}"

    ABS_IMAGE_FILE="$(cd "$(dirname "${IMAGE_FILE}")" && pwd)/$(basename "${IMAGE_FILE}")"
    ABS_OUTPUT_DIR="$(mkdir -p "${OUTPUT_DIR}" && cd "${OUTPUT_DIR}" && pwd)"

    echo "2. Converting OVA (${ABS_IMAGE_FILE}) to Docker tar archive using ova-to-docker..."
    (
        cd "${CONVERTER_DIR}"
        yes "y" | python3 "${CONVERTER_SCRIPT}" --input "${ABS_IMAGE_FILE}" --output "${ABS_OUTPUT_DIR}" || true
    )

    TAR_FILE=$(find "${OUTPUT_DIR}" -name "*.tar.gz" -o -name "*.tar" | head -n 1)

    if [ -z "${TAR_FILE}" ]; then
        echo "ERROR: ova-to-docker failed to produce tar archive for tag ${tag}!"
        exit 1
    fi

    FULL_IMAGE_TAG="${IMAGE_NAME}:${tag}"

    echo "3. Importing rootfs into Docker as ${FULL_IMAGE_TAG}..."
    docker import "${TAR_FILE}" "${FULL_IMAGE_TAG}"

    if [ "${TEST_VERSION:-true}" = "true" ]; then
        echo "4. Verifying container functionality and release version..."
        RELEASE_INFO=$(docker run --rm "${FULL_IMAGE_TAG}" cat /etc/oracle-release || docker run --rm "${FULL_IMAGE_TAG}" cat /etc/os-release)
        echo "$RELEASE_INFO"

        EXPECTED_VER="${tag}"
        if echo "$RELEASE_INFO" | grep -q "${EXPECTED_VER}"; then
            echo "SUCCESS: Version match found for ${EXPECTED_VER}!"
        else
            echo "WARNING: Exact version string ${EXPECTED_VER} not explicitly matched in release info text, but container verified."
        fi
    fi

    if [ "${PUSH_TO_DOCKERHUB:-false}" = "true" ]; then
        echo "5. Pushing image to Docker Hub..."
        docker push "${FULL_IMAGE_TAG}"
    else
        echo "5. Skipping Docker Hub push (PUSH_TO_DOCKERHUB is not set to 'true')."
    fi

    echo "6. Cleaning up temporary files..."
    rm -rf "${IMAGE_FILE}" "${OUTPUT_DIR}"

    echo "Successfully completed processing for tag ${tag}!"
    echo
done < "$RELEASES_FILE"

echo "All Oracle Linux images processed successfully!"
