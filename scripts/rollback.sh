#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
fi

echo "=== Starting Routing Rollback to NGINX Ingress ==="

# 1. Delete Gateway API resources to disable Envoy routing
echo "Removing Envoy HTTPRoutes and Gateway resources..."
kubectl delete -f "${PROJECT_ROOT}/manifests/gateway-after/httproute-https.yaml" --ignore-not-found
kubectl delete -f "${PROJECT_ROOT}/manifests/gateway-after/httproute-http.yaml" --ignore-not-found
kubectl delete -f "${PROJECT_ROOT}/manifests/gateway-after/gateway.yaml" --ignore-not-found

# 2. Ensure NGINX Ingress is fully applied
echo "Restoring original NGINX Ingress rules..."
kubectl apply -f "${PROJECT_ROOT}/manifests/ingress-before/ingress.yaml"

# 3. Verify Rollback Status
echo "Waiting 5 seconds for routing paths to update..."
sleep 5

echo "Testing Ingress connection..."
STATUS_INGRESS=$(curl -s -k -o /dev/null -w "%{http_code}" -H "Host: ${INGRESS_DOMAIN:-ingress-test.local}" https://127.0.0.1:8443/service-a)

if [ "$STATUS_INGRESS" -eq 200 ]; then
    echo "SUCCESS: Rollback complete! NGINX Ingress is successfully routing traffic on port 8443."
else
    echo "WARNING: Ingress test returned status code $STATUS_INGRESS. Please verify the ingress controller logs."
fi

echo "=== Rollback completed. ==="
