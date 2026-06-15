#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${PROJECT_ROOT}/bin"

mkdir -p "${BIN_DIR}"

echo "Checking if ingress2gateway is already installed..."
if [ -f "${BIN_DIR}/ingress2gateway" ]; then
    echo "ingress2gateway is already installed at ${BIN_DIR}/ingress2gateway."
    "${BIN_DIR}/ingress2gateway" --version || true
    exit 0
fi

VERSION="v1.1.0"
TAR_FILE="ingress2gateway_Linux_x86_64.tar.gz"
DOWNLOAD_URL="https://github.com/kubernetes-sigs/ingress2gateway/releases/download/${VERSION}/${TAR_FILE}"

echo "Downloading ingress2gateway ${VERSION} from ${DOWNLOAD_URL}..."
curl -L -o "/tmp/${TAR_FILE}" "${DOWNLOAD_URL}"

echo "Extracting ingress2gateway..."
tar -xzf "/tmp/${TAR_FILE}" -C "/tmp"

echo "Moving binary to ${BIN_DIR}..."
mv "/tmp/ingress2gateway" "${BIN_DIR}/ingress2gateway"
chmod +x "${BIN_DIR}/ingress2gateway"

echo "Cleaning up..."
rm -f "/tmp/${TAR_FILE}"

echo "ingress2gateway installation complete!"
"${BIN_DIR}/ingress2gateway" --version || true
