#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    echo "Loading environment from secrets/.env..."
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
fi
if [ -z "${DOCKER_REGISTRY}" ]; then
    echo "ERROR: DOCKER_REGISTRY must be configured in secrets/.env!"
    exit 1
fi

REGISTRY="${DOCKER_REGISTRY}"
SERVICE_IMAGE="${REGISTRY}/microservice:latest"
FRONTEND_IMAGE="${REGISTRY}/frontend:latest"


echo "Pointing shell to Minikube's Docker daemon..."
eval $(minikube -p minikube docker-env)

echo "Building microservice image: ${SERVICE_IMAGE}..."
docker build -t "${SERVICE_IMAGE}" "${PROJECT_ROOT}/app/service"

echo "Building frontend dashboard image: ${FRONTEND_IMAGE}..."
docker build -t "${FRONTEND_IMAGE}" "${PROJECT_ROOT}/app/frontend"

echo "Images built successfully inside Minikube's Docker daemon!"
docker images | grep -E "microservice|frontend" || true
