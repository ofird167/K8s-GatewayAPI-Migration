# NGINX Ingress to Kubernetes Gateway API Migration

> ⚡ **Looking for the Quickstart?** Jump straight to the [DevOps Quickstart Guide (TL;DR)](readmeTL;DR.md).

An end-to-end DevOps migration workspace demonstrating the transition from NGINX Ingress Controller to the Kubernetes Gateway API (using Envoy Gateway). The cluster runs locally on Minikube, integrates HashiCorp Vault for dynamic secret injection via mutating webhooks, and includes a premium status dashboard for validation.

---

## 1. Local Development & Setup

### Prerequisites
- Docker (with WSL2 if on Windows)
- Minikube
- Kubectl
- Helm v3+
- Openssl (for self-signed cert generation)

### Configuration
We use a git-ignored `/secrets/.env` file to customize the environment.
1. Create the `secrets/` directory and populate `.env` using the template `example.env` in the root:
   ```bash
   mkdir -p secrets
   cp example.env secrets/.env
   ```
2. Open `secrets/.env` and configure your settings:
   - `MINIKUBE_CPU`: Number of CPUs (default: `2`)
   - `MINIKUBE_MEMORY`: Memory allocation in MB. Set to `2048` to avoid resource over-allocation on local VM/WSL2 hosts.
   - `DOCKER_REGISTRY`: Your Docker registry prefix (e.g. `docker.io/username`).
   - `INGRESS_DOMAIN`: Host domain name (default: `ingress-test.local`).

### Bootstrapping the Cluster
Start the local Minikube cluster and enable the NGINX Ingress addon (for before-state verification):
```bash
./scripts/setup-minikube.sh
```

---

## 2. Secrets Management (HashiCorp Vault)

We deploy HashiCorp Vault inside Minikube using Helm and configure it to dynamically inject secrets into our microservices using the Vault Agent Injector sidecar.

### Deploying & Configuring Vault
1. Deploy Vault, configure Kubernetes Auth, establish access policies, and populate application secrets:
   ```bash
   ./scripts/setup-vault.sh
   ```
2. The script writes `docker_username`, `docker_password`, and a mock `api_key` to the Vault key-value store (`secret/data/app`).
3. Application pods specify Vault annotations to request secret injection at path `/vault/secrets/credentials`.

---

## 3. Image Compilation & Manifest Rendering

### Image Compilation
To build the application containers directly inside Minikube's Docker daemon:
```bash
./scripts/build.sh
```

### Manifest Rendering
Because Kubernetes does not support environment variable interpolation (like `${DOCKER_REGISTRY}`) in standard YAML manifests out of the box, we use template files (`.tmpl`) and render them locally:
```bash
./scripts/render-manifests.sh
```
This generates standard `.yaml` files under `manifests/ingress-before/` and `manifests/gateway-after/` with actual env values. Rendered `.yaml` files are git-ignored.

---

## 4. Deployment & Migration Validation

To compare routing behaviors, we deploy the before-state (NGINX Ingress) and after-state (Envoy Gateway) side-by-side.

### 1. Deploy NGINX Ingress ("Before" State)
Deploy self-signed TLS certificates for `ingress-test.local`, the 3 microservices, the dashboard app, and NGINX Ingress:
```bash
./scripts/deploy-ingress.sh
```

### 2. Deploy Envoy Gateway ("After" State)
Install Envoy Gateway controller and deploy the Gateway API resources (GatewayClass, Gateway, HTTPRoutes):
```bash
./scripts/setup-gateway.sh
./scripts/deploy-gateway.sh
```

### 3. Expose Services via Port-Forwarding
Since Minikube's docker-driver IP is inside a private Docker bridge, port-forward the services to your local host:
* **NGINX Ingress**:
  ```bash
  # Forward HTTP (80) -> 8085, HTTPS (443) -> 8443
  kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8085:80 --address=0.0.0.0 &
  kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8443:443 --address=0.0.0.0 &
  ```
* **Envoy Gateway**:
  ```bash
  # Forward HTTP (80) -> 8086, HTTPS (443) -> 8446
  ENVOY_SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/infra-name=devops-gateway -o jsonpath='{.items[0].metadata.name}')
  kubectl port-forward svc/$ENVOY_SVC -n envoy-gateway-system 8086:80 --address=0.0.0.0 &
  kubectl port-forward svc/$ENVOY_SVC -n envoy-gateway-system 8446:443 --address=0.0.0.0 &
  ```

---

## 5. Verification Playground

We supply an automated verification script to validate URL prefix rewrites, SSL redirection, and request body size limits on both routing interfaces:
```bash
./scripts/test-routing.sh
```

### Manual Verification (Browser)
1. Add the domain to your local `/etc/hosts` file:
   ```text
   127.0.0.1 ingress-test.local
   ```
2. Navigate to the visual status dashboard:
   - **NGINX Ingress Dashboard**: `https://ingress-test.local:8443/`
   - **Envoy Gateway Dashboard**: `https://ingress-test.local:8446/`
3. Use the **Playground** inside the dashboard to trigger live HTTP requests verifying rewrites and payload constraints.

---

## 6. Incident Runbook & Troubleshooting

### Incident A: Vault Secret Injection Fails (Pod Blocks on InitContainer)
If pods fail to start and show `Init:CrashLoopBackOff`:
1. Verify the Vault pod is ready:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=vault
   ```
2. Inspect the init-container logs of the failing pod:
   ```bash
   kubectl logs <pod-name> -c vault-agent-init -n devops
   ```
3. Common cause: The Vault role or policy configuration was not loaded. Re-run `./scripts/setup-vault.sh` to refresh the configurations.

### Incident B: Port-Forward Bind Address Already in Use
If port forwarding fails with `Address already in use`:
1. Find the process using the port (e.g. 8085):
   ```bash
   fuser 8085/tcp
   ```
2. Kill the conflicting background process:
   ```bash
   fkill -9 <PID>
   ```
