# DevOps Quickstart Guide (TL;DR)

> 📚 **Looking for full details?** View the [Detailed Documentation Guide](README.md).

---

### 1. Setup Environment Variables
Create the `/secrets` directory and populate your credentials:
```bash
mkdir -p secrets
cp example.env secrets/.env
```
*Open `secrets/.env` and update your `DOCKER_USERNAME` and `DOCKER_PASSWORD`. Ensure `MINIKUBE_MEMORY=2048` to prevent resource allocation errors on WSL2/local hosts.*

---

### 2. Boostrap Minikube & Tools
Start the Minikube cluster and install the `ingress2gateway` conversion tool:
```bash
./scripts/setup-minikube.sh
./scripts/install-tools.sh
```

---

### 3. Deploy Secrets Management (Vault)
Provision HashiCorp Vault inside Minikube and populate keys:
```bash
./scripts/setup-vault.sh
```

---

### 4. Build Images & Render YAML Templates
Build application container images inside Minikube's Docker env and render manifest templates:
```bash
./scripts/build.sh
./scripts/render-manifests.sh
```
*Note: We render templates (`.yaml.tmpl` to `.yaml`) dynamically because Kubernetes does not natively support env variable interpolation in YAML files.*

---

### 5. Deploy Ingress (Before) & Gateway API (After)
Deploy both routing layers side-by-side:
```bash
# Deploy NGINX Ingress rules
./scripts/deploy-ingress.sh

# Deploy Envoy Gateway rules
./scripts/setup-gateway.sh
./scripts/deploy-gateway.sh
```

---

### 6. Expose Routing Proxies & Validate
1. Run port-forwarding to map cluster proxies to host ports:
   ```bash
   # NGINX Ingress
   kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8085:80 --address=0.0.0.0 &
   kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8443:443 --address=0.0.0.0 &

   # Envoy Gateway
   ENVOY_SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=devops-gateway -o jsonpath='{.items[0].metadata.name}')
   kubectl port-forward svc/$ENVOY_SVC -n envoy-gateway-system 8086:80 --address=0.0.0.0 &
   kubectl port-forward svc/$ENVOY_SVC -n envoy-gateway-system 8446:443 --address=0.0.0.0 &
   ```
2. Execute automated verification curls:
   ```bash
   ./scripts/test-routing.sh
   ```
3. Map `127.0.0.1 ingress-test.local` to `/etc/hosts` and access visual dashboards:
   - NGINX Ingress Dashboard: `https://ingress-test.local:8443/`
   - Envoy Gateway Dashboard: `https://ingress-test.local:8446/`
