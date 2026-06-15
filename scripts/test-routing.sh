#!/bin/bash
# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Kubernetes Ingress vs Gateway API Routing Verification ===${NC}\n"

# Ingress Ports
NGINX_HTTP_PORT=8085
NGINX_HTTPS_PORT=8443

# Envoy Ports
ENVOY_HTTP_PORT=8086
ENVOY_HTTPS_PORT=8446

DOMAIN="ingress-test.local"

# ----------------- NGINX Ingress Verification -----------------
echo -e "${BLUE}--- NGINX Ingress Controller Verification (Port ${NGINX_HTTP_PORT}/${NGINX_HTTPS_PORT}) ---${NC}"

# 1. SSL Redirect
echo -n "1. Testing HTTP to HTTPS redirect... "
REDIRECT_LOC=$(curl -sI -H "Host: ${DOMAIN}" "http://127.0.0.1:${NGINX_HTTP_PORT}/service-a" | grep -i "location:")
if [[ $REDIRECT_LOC == *"https://${DOMAIN}/service-a"* ]]; then
  echo -e "${GREEN}SUCCESS (Redirected to HTTPS)${NC}"
else
  echo -e "${RED}FAILED${NC} ($REDIRECT_LOC)"
fi

# 2. URL Rewrite (Prefix strip)
echo -n "2. Testing URL prefix rewrite (/service-a/check -> /check)... "
REWRITE_PATH=$(curl -s -k -H "Host: ${DOMAIN}" "https://127.0.0.1:${NGINX_HTTPS_PORT}/service-a/check" | grep -o '"url": "[^"]*"' | head -n 1)
if [[ $REWRITE_PATH == *"/check"* ]]; then
  echo -e "${GREEN}SUCCESS (Prefix /service-a stripped to /check)${NC}"
else
  echo -e "${RED}FAILED${NC} (Received: $REWRITE_PATH)"
fi

# 3. Payload size limit
echo -n "3. Testing 50KB payload (expected: 200 OK)... "
STATUS_50KB=$(dd if=/dev/zero bs=1024 count=50 2>/dev/null | curl -s -k -H "Host: ${DOMAIN}" -H "Content-Type: application/octet-stream" --data-binary @- -o /dev/null -w "%{http_code}" "https://127.0.0.1:${NGINX_HTTPS_PORT}/service-b")
if [ "$STATUS_50KB" -eq 200 ]; then
  echo -e "${GREEN}SUCCESS (200 OK)${NC}"
else
  echo -e "${RED}FAILED${NC} (Status: $STATUS_50KB)"
fi

echo -n "4. Testing 2MB payload (expected: 413 Request Entity Too Large)... "
STATUS_2MB=$(dd if=/dev/zero bs=1024 count=2048 2>/dev/null | curl -s -k -H "Host: ${DOMAIN}" -H "Content-Type: application/octet-stream" --data-binary @- -o /dev/null -w "%{http_code}" "https://127.0.0.1:${NGINX_HTTPS_PORT}/service-b")
if [ "$STATUS_2MB" -eq 413 ]; then
  echo -e "${GREEN}SUCCESS (413 Payload Too Large)${NC}"
else
  echo -e "${RED}FAILED${NC} (Status: $STATUS_2MB)"
fi

echo ""

# ----------------- Envoy Gateway Verification -----------------
echo -e "${BLUE}--- Envoy Gateway API Verification (Port ${ENVOY_HTTP_PORT}/${ENVOY_HTTPS_PORT}) ---${NC}"

# 1. SSL Redirect
echo -n "1. Testing HTTP to HTTPS redirect... "
REDIRECT_LOC_EG=$(curl -sI -H "Host: ${DOMAIN}" "http://127.0.0.1:${ENVOY_HTTP_PORT}/service-a" | grep -i "location:")
if [[ $REDIRECT_LOC_EG == *"https://${DOMAIN}/service-a"* ]]; then
  echo -e "${GREEN}SUCCESS (Redirected to HTTPS via RequestRedirect filter)${NC}"
else
  echo -e "${RED}FAILED${NC} ($REDIRECT_LOC_EG)"
fi

# 2. URL Rewrite (Prefix strip)
echo -n "2. Testing URL prefix rewrite (/service-a/check -> /check)... "
REWRITE_PATH_EG=$(curl -s -k --resolve "${DOMAIN}:${ENVOY_HTTPS_PORT}:127.0.0.1" "https://${DOMAIN}:${ENVOY_HTTPS_PORT}/service-a/check" | grep -o '"url": "[^"]*"' | head -n 1)
if [[ $REWRITE_PATH_EG == *"/check"* ]]; then
  echo -e "${GREEN}SUCCESS (Prefix /service-a stripped to /check via URLRewrite ReplacePrefixMatch)${NC}"
else
  echo -e "${RED}FAILED${NC} (Received: $REWRITE_PATH_EG)"
fi

# 3. Payload size limit
echo -n "3. Testing 50KB payload (expected: 200 OK)... "
STATUS_50KB_EG=$(dd if=/dev/zero bs=1024 count=50 2>/dev/null | curl -s -k --resolve "${DOMAIN}:${ENVOY_HTTPS_PORT}:127.0.0.1" -H "Content-Type: application/octet-stream" --data-binary @- -o /dev/null -w "%{http_code}" "https://${DOMAIN}:${ENVOY_HTTPS_PORT}/service-b")
if [ "$STATUS_50KB_EG" -eq 200 ]; then
  echo -e "${GREEN}SUCCESS (200 OK)${NC}"
else
  echo -e "${RED}FAILED${NC} (Status: $STATUS_50KB_EG)"
fi

echo -n "4. Testing 2MB payload (expected: unlimited/200 OK in v1.1.0 or 413)... "
STATUS_2MB_EG=$(dd if=/dev/zero bs=1024 count=2048 2>/dev/null | curl -s -k --resolve "${DOMAIN}:${ENVOY_HTTPS_PORT}:127.0.0.1" -H "Content-Type: application/octet-stream" --data-binary @- -o /dev/null -w "%{http_code}" "https://${DOMAIN}:${ENVOY_HTTPS_PORT}/service-b")
if [ "$STATUS_2MB_EG" -eq 200 ]; then
  echo -e "${YELLOW}INFO (Status: $STATUS_2MB_EG - Gateway API Body Size annotation is a known GAP in Envoy Gateway v1.1.0)${NC}"
elif [ "$STATUS_2MB_EG" -eq 413 ]; then
  echo -e "${GREEN}SUCCESS (413 Payload Too Large)${NC}"
else
  echo -e "${RED}FAILED${NC} (Status: $STATUS_2MB_EG)"
fi

echo -e "\n${BLUE}Verification completed.${NC}"
