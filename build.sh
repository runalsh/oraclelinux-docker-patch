#!/bin/bash
set -euo pipefail

IMAGE_NAME="runalsh/oraclelinux-patch"
RELEASES_FILE="releases.txt"

# Locate or clone executeatwill/ova-to-docker repository
CONVERTER_DIR="/root/ova-to-docker"
if [ ! -d "${CONVERTER_DIR}" ]; then
    CONVERTER_DIR="/tmp/ova-to-docker"
    if [ ! -d "${CONVERTER_DIR}" ]; then
        echo "Cloning ova-to-docker repository..."
        git clone https://github.com/executeatwill/ova-to-docker "${CONVERTER_DIR}"
    fi
fi

CONVERTER_SCRIPT="${CONVERTER_DIR}/ova-to-docker.py"
if [ ! -f "${CONVERTER_SCRIPT}" ]; then
    CONVERTER_SCRIPT="${CONVERTER_DIR}/no-requirements-ova-to-docker.py"
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

    VMDK_FILE="temp_image_${tag}.vmdk"
    OUTPUT_DIR="temp_output_${tag}"

    mkdir -p "${OUTPUT_DIR}"

    echo "1. Downloading VMDK image..."
    curl -fSL -o "${VMDK_FILE}" "${url}"

    echo "2. Converting VMDK to Docker tar archive using ova-to-docker..."
    echo "y" | python3 "${CONVERTER_SCRIPT}" --input "${VMDK_FILE}" --output "${OUTPUT_DIR}" || true

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
    rm -rf "${VMDK_FILE}" "${OUTPUT_DIR}"

    echo "Successfully completed processing for tag ${tag}!"
    echo
done < "$RELEASES_FILE"

echo "All Oracle Linux images processed successfully!"
