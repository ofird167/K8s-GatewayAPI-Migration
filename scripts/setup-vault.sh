#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_ROOT}/secrets/.env" ]; then
    export $(grep -v '^#' "${PROJECT_ROOT}/secrets/.env" | xargs)
fi

echo "Adding HashiCorp Helm repository..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

echo "Deploying Vault in Dev mode..."
# Enable server dev mode, enable vault injector, wait for deployment to complete
helm upgrade --install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.token=root" \
  --set "injector.enabled=true" \
  --wait

echo "Waiting for Vault pod to be ready..."
kubectl wait --for=condition=Ready pod/vault-0 --timeout=2m


# Execute Vault configuration inside vault-0 pod
echo "Configuring Kubernetes authentication inside Vault..."
kubectl exec -i vault-0 -- sh << 'EOF'
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

# Enable Kubernetes Auth method
vault auth enable kubernetes || true

# Configure Kubernetes Auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc"

# Create a policy for reading app secrets
vault policy write app-policy - << 'POLICY'
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/data/app" {
  capabilities = ["read"]
}
POLICY

# Create a role for the applications
vault write auth/kubernetes/role/app-role \
    bound_service_account_names="*" \
    bound_service_account_namespaces="*" \
    policies="app-policy" \
    ttl="24h"
EOF

# Write application secrets to Vault
if [ -z "${DOCKER_USERNAME}" ] || [ -z "${DOCKER_PASSWORD}" ]; then
    echo "ERROR: DOCKER_USERNAME and DOCKER_PASSWORD must be configured in secrets/.env!"
    exit 1
fi

DOCKER_USER="${DOCKER_USERNAME}"
DOCKER_PASS="${DOCKER_PASSWORD}"

echo "Writing application secrets to Vault KV store..."
kubectl exec -i vault-0 -- sh -c "export VAULT_ADDR='http://127.0.0.1:8200' && export VAULT_TOKEN='root' && vault kv put secret/app docker_username=\"$DOCKER_USER\" docker_password=\"$DOCKER_PASS\" api_key=\"mock-secret-key-from-vault\""

echo "Vault setup complete!"
