#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    echo "Loading environment from secrets/.env..."
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
elif [ -f "${PROJECT_ROOT}/example.env" ]; then
    echo "Loading environment from example.env..."
    export $(grep -v '^#' "${PROJECT_ROOT}/example.env" | xargs)
else
    echo "No env file found, using defaults..."
fi

CPU="${MINIKUBE_CPU:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"

echo "Starting Minikube with ${CPU} CPUs and ${MEMORY}MB Memory..."
minikube start --cpus="${CPU}" --memory="${MEMORY}" --driver=docker

echo "Enabling Ingress addon in Minikube..."
minikube addons enable ingress

echo "Minikube setup complete. To run the tunnel, run: minikube tunnel"
