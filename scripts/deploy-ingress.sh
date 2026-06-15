#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
fi

DOMAIN="${INGRESS_DOMAIN:-ingress-test.local}"

echo "Creating 'devops' namespace..."
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/namespace.yaml"

echo "Generating self-signed TLS certificate for ${DOMAIN}..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=${DOMAIN}"

echo "Creating SSL TLS secret in Kubernetes..."
kubectl create secret tls ingress-tls \
  --key=/tmp/tls.key \
  --cert=/tmp/tls.crt \
  -n devops \
  --dry-run=client -o yaml | kubectl apply -f -

# Clean up local cert files
rm -f /tmp/tls.key /tmp/tls.crt

echo "Applying microservices and frontend manifests..."
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/service-a.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/service-b.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/service-c.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/frontend.yaml"

echo "Applying NGINX Ingress rules..."
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/ingress.yaml"

echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/service-a -n devops --timeout=2m
kubectl rollout status deployment/service-b -n devops --timeout=2m
kubectl rollout status deployment/service-c -n devops --timeout=2m
kubectl rollout status deployment/frontend -n devops --timeout=2m

echo "Deployment of Ingress before-state complete!"
