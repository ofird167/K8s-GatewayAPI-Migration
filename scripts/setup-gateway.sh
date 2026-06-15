#!/bin/bash
set -e

echo "Deploying Envoy Gateway via Helm..."
# Enable OCI support if needed (enabled by default in newer Helm versions)
export HELM_EXPERIMENTAL_OCI=1

# Install Envoy Gateway
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.1.0 \
  -n envoy-gateway-system \
  --create-namespace \
  --wait

echo "Waiting for Envoy Gateway controller to be ready..."
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

echo "Envoy Gateway setup complete!"
