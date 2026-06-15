const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const SERVICE_NAME = process.env.SERVICE_NAME || 'unknown-service';

// Function to read and parse Vault secrets if they exist
function getVaultSecrets() {
  const secretPath = '/vault/secrets/credentials';
  const secrets = {
    docker_username: 'Not Loaded',
    docker_password: 'Not Loaded',
    api_key: 'Not Loaded'
  };

  if (fs.existsSync(secretPath)) {
    try {
      const content = fs.readFileSync(secretPath, 'utf8');
      const lines = content.split('\n');
      lines.forEach(line => {
        const parts = line.split('=');
        if (parts.length >= 2) {
          const key = parts[0].trim();
          const val = parts.slice(1).join('=').trim().replace(/^"|"$/g, '');
          if (key === 'DOCKER_USERNAME') secrets.docker_username = val;
          if (key === 'DOCKER_PASSWORD') secrets.docker_password = val;
          if (key === 'API_KEY') secrets.api_key = val;
        }
      });
    } catch (err) {
      console.error('Error reading Vault secret file:', err);
    }
  }
  return secrets;
}

const server = http.createServer((req, res) => {
  // Read secrets dynamically on each request
  const vaultSecrets = getVaultSecrets();

  // Mask secrets for display
  const mask = (val) => {
    if (!val || val === 'Not Loaded') return val;
    if (val.length <= 4) return '****';
    return val.substring(0, 2) + '*'.repeat(val.length - 4) + val.substring(val.length - 2);
  };

  const responseData = {
    service: SERVICE_NAME,
    status: 'UP',
    hostname: require('os').hostname(),
    url: req.url,
    method: req.method,
    headers: req.headers,
    timestamp: new Date().toISOString(),
    secrets: {
      docker_username: vaultSecrets.docker_username,
      docker_password: mask(vaultSecrets.docker_password),
      api_key: mask(vaultSecrets.api_key)
    }
  };

  // Add latency/delay if header exists (for testing/canary demonstration)
  const delay = req.headers['x-test-delay'] ? parseInt(req.headers['x-test-delay'], 10) : 0;

  setTimeout(() => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(responseData, null, 2));
  }, delay);
});

server.listen(PORT, () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});
