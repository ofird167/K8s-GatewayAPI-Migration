// Config
const services = {
  'service-a': '/service-a',
  'service-b': '/service-b',
  'service-c': '/service-c'
};

// Console logger helper
function logToConsole(message, type = 'info') {
  const consoleEl = document.getElementById('console-output');
  if (consoleEl.innerHTML === 'Select a test from the playground or click Refresh to fetch live cluster metadata...') {
    consoleEl.innerHTML = '';
  }
  
  const timestamp = new Date().toLocaleTimeString();
  let color = '#e5e7eb';
  if (type === 'success') color = '#34d399'; // Emerald
  if (type === 'error') color = '#f87171'; // Rose
  if (type === 'warning') color = '#fbbf24'; // Yellow
  if (type === 'header') color = '#60a5fa'; // Blue

  consoleEl.innerHTML += `<span style="color: ${color}">[${timestamp}] ${message}</span>\n`;
  consoleEl.scrollTop = consoleEl.scrollHeight;
}

function clearConsole() {
  document.getElementById('console-output').innerHTML = '';
}

// Check active gateway controller by reading response headers
function detectController(headers) {
  const controllerEl = document.getElementById('active-controller');
  const controllerNameEl = document.getElementById('controller-name');
  
  let serverHeader = headers.get('server') || '';
  let envoyTimeHeader = headers.get('x-envoy-upstream-service-time');
  
  if (serverHeader.toLowerCase().includes('nginx') || serverHeader.toLowerCase().includes('openresty')) {
    controllerEl.className = 'active-controller-badge nginx';
    controllerNameEl.textContent = 'Active: NGINX Ingress Controller';
    return 'nginx';
  } else if (serverHeader.toLowerCase().includes('envoy') || envoyTimeHeader !== null) {
    controllerEl.className = 'active-controller-badge envoy';
    controllerNameEl.textContent = 'Active: Envoy Gateway (Gateway API)';
    return 'envoy';
  }
  return 'unknown';
}

// Refresh status of a single service
async function checkServiceStatus(name, path) {
  const statusEl = document.getElementById(`status-${name}`);
  const hostEl = document.getElementById(`host-${name}`);
  const rowEl = document.getElementById(`row-${name}`);

  try {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), 3000);
    
    const response = await fetch(path, { signal: controller.signal });
    clearTimeout(id);

    if (response.ok) {
      const data = await response.json();
      
      // Update UI elements
      statusEl.textContent = 'ONLINE';
      statusEl.className = 'status-tag status-online';
      hostEl.textContent = data.hostname;
      
      // Detect controller from response headers
      detectController(response.headers);
      
      // Update Vault credentials panel if returned
      if (data.secrets && data.secrets.docker_username !== 'Not Loaded') {
        document.getElementById('vault-connection-status').textContent = 'CONNECTED';
        document.getElementById('vault-connection-status').className = 'status-tag status-online';
        document.getElementById('secret-user').textContent = data.secrets.docker_username;
        document.getElementById('secret-pass').textContent = data.secrets.docker_password;
        document.getElementById('secret-key').textContent = data.secrets.api_key;
      }

      return { name, data, headers: response.headers, ok: true };
    }
  } catch (err) {
    console.error(`Error checking ${name}:`, err);
  }

  statusEl.textContent = 'OFFLINE';
  statusEl.className = 'status-tag status-offline';
  hostEl.textContent = '-';
  return { name, ok: false };
}

// Refresh all service statuses
async function refreshAllStatuses() {
  logToConsole('Refreshing cluster and service metadata...', 'header');
  
  let activeServicesCount = 0;
  for (const [name, path] of Object.entries(services)) {
    const result = await checkServiceStatus(name, path);
    if (result.ok) {
      activeServicesCount++;
      logToConsole(`Service ${name.toUpperCase()} is online at hostname: ${result.data.hostname}`, 'success');
      logToConsole(`Server Header: "${result.headers.get('server') || 'None'}"`, 'info');
    } else {
      logToConsole(`Service ${name.toUpperCase()} is offline or unreachable.`, 'error');
    }
  }
  
  if (activeServicesCount === 0) {
    logToConsole('WARNING: All services are offline. Verify minikube tunnel is running.', 'warning');
    document.getElementById('vault-connection-status').textContent = 'UNREACHABLE';
    document.getElementById('vault-connection-status').className = 'status-tag status-offline';
  }
}

// Verification Test: Rewrite Target
async function testRewrite() {
  logToConsole('Testing URL rewrite annotation targeting /service-a/check-rewrite...', 'header');
  try {
    const response = await fetch('/service-a/check-rewrite');
    if (response.ok) {
      const data = await response.json();
      logToConsole(`Request path sent by client: "/service-a/check-rewrite"`, 'info');
      logToConsole(`Path received by Pod: "${data.url}"`, 'success');
      
      if (data.url === '/check-rewrite') {
        logToConsole(`SUCCESS: Route prefix "/service-a" was successfully rewritten (stripped).`, 'success');
      } else {
        logToConsole(`FAILED: Route prefix was not rewritten. Received: ${data.url}`, 'error');
      }
    } else {
      logToConsole(`HTTP error: ${response.status}`, 'error');
    }
  } catch (err) {
    logToConsole(`Network error: ${err.message}`, 'error');
  }
}

// Verification Test: SSL Redirect
function testSSLRedirect() {
  logToConsole('Testing SSL/TLS Enforcement Redirect...', 'header');
  const currentHost = window.location.hostname;
  
  logToConsole(`Client is running at: ${window.location.protocol}//${currentHost}`, 'info');
  logToConsole('To verify SSL redirect locally, run the CLI validation script or curl HTTP directly:', 'info');
  logToConsole(`curl -i -H "Host: ${currentHost}" http://${currentHost}/`, 'warning');
  logToConsole('The controller must return a 301/308 redirect status with Location header pointing to https://...', 'success');
}

// Verification Test: Proxy Body Size (Payload Limits)
async function testPayload(sizeKb) {
  logToConsole(`Sending ${sizeKb}KB payload to verify proxy body size limit (Max: 1MB)...`, 'header');
  
  // Generate a dummy string of approximate KB size (1 char = 1 byte)
  const charCount = sizeKb * 1024;
  const payload = 'A'.repeat(charCount);
  
  try {
    const response = await fetch('/service-b', {
      method: 'POST',
      headers: {
        'Content-Type': 'text/plain',
      },
      body: payload
    });
    
    logToConsole(`HTTP Response Status: ${response.status} ${response.statusText}`, response.ok ? 'success' : 'error');
    
    if (response.status === 200) {
      logToConsole(`SUCCESS: Payload size ${sizeKb}KB accepted by the gateway.`, 'success');
    } else if (response.status === 413) {
      logToConsole(`BLOCKED: Payload size ${sizeKb}KB rejected with 413 Payload Too Large.`, 'success');
    } else {
      logToConsole(`UNEXPECTED RESPONSE: Received status code ${response.status}`, 'warning');
    }
  } catch (err) {
    logToConsole(`Request failed: ${err.message}. This might indicate the connection was reset by the server/gateway due to body size constraints (desired behavior).`, 'warning');
  }
}

// Auto-run on page load
window.addEventListener('DOMContentLoaded', () => {
  // Wait a short duration to let initial layout render
  setTimeout(refreshAllStatuses, 1000);
});
