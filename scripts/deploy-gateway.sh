#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
fi

echo "Applying GatewayClass..."
kubectl apply -f "${PROJECT_ROOT}/manifests/gateway-after/gatewayclass.yaml"

echo "Applying Gateway..."
kubectl apply -f "${PROJECT_ROOT}/manifests/gateway-after/gateway.yaml"

echo "Applying HTTPRoute redirects (HTTP to HTTPS)..."
kubectl apply -f "${PROJECT_ROOT}/manifests/gateway-after/httproute-http.yaml"

echo "Applying HTTPS HTTPRoute (Routing & prefix rewrites)..."
kubectl apply -f "${PROJECT_ROOT}/manifests/gateway-after/httproute-https.yaml"

echo "Applying BackendTrafficPolicy (Payload buffering limits)..."
kubectl apply -f "${PROJECT_ROOT}/manifests/gateway-after/traffic-policy.yaml" || echo "WARNING: BackendTrafficPolicy could not be applied. This is a known version compatibility gap."


echo "Waiting for Gateway to be programmed..."
# Envoy Gateway will create the Envoy proxy pods and set Accepted status to true
kubectl wait --for=condition=Accepted gateway/devops-gateway -n devops --timeout=2m

echo "Gateway API deployment complete!"
echo "Retrieving Envoy service details in envoy-gateway-system..."
kubectl get svc -n envoy-gateway-system
