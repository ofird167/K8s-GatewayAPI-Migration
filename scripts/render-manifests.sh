#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment from secrets/.env or example.env
if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    echo "Loading environment from secrets/.env..."
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
elif [ -f "${PROJECT_ROOT}/example.env" ]; then
    echo "Loading environment from example.env..."
    export $(grep -v '^#' "${PROJECT_ROOT}/example.env" | xargs)
fi

# Fallbacks for variables
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io/devops-user}"
export INGRESS_DOMAIN="${INGRESS_DOMAIN:-ingress-test.local}"

echo "Rendering templates with DOCKER_REGISTRY=${DOCKER_REGISTRY} and INGRESS_DOMAIN=${INGRESS_DOMAIN}..."

# List of template directories
TEMPLATE_DIRS=(
  "${PROJECT_ROOT}/manifests/ingress-before"
  "${PROJECT_ROOT}/manifests/gateway-after"
)

for dir in "${TEMPLATE_DIRS[@]}"; do
  if [ -d "${dir}" ]; then
    echo "Processing templates in ${dir}..."
    find "${dir}" -name "*.yaml.tmpl" | while read -r tmpl; do
      yaml="${tmpl%.tmpl}"
      echo "Rendering ${tmpl} -> ${yaml}"
      envsubst '$DOCKER_REGISTRY $INGRESS_DOMAIN' < "${tmpl}" > "${yaml}"
    done
  fi
done

echo "Template rendering complete!"
