# BusinessMath MCP Server - Production Deployment Guide

## Overview

This guide covers deploying the BusinessMath MCP Server in production with HTTP + SSE transport, including security, HTTPS, monitoring, and high availability.

---

## Table of Contents

- [Security Configuration](#security-configuration)
- [HTTPS / TLS Setup](#https--tls-setup)
- [Environment Configuration](#environment-configuration)
- [Deployment Options](#deployment-options)
- [Monitoring & Logging](#monitoring--logging)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

---

## Security Configuration

### API Key Authentication

The server supports API key authentication via environment variables.

**Enable Authentication:**

```bash
# Set one or more API keys (comma-separated)
export MCP_API_KEYS="prod-key-1,prod-key-2,backup-key-3"

# Ensure authentication is required (default: true)
export MCP_AUTH_REQUIRED=true

# Start server
./businessmath-mcp-server --http 8080
```

**Best Practices:**

1. **Generate Strong Keys**
   ```bash
   # Generate cryptographically secure API keys
   openssl rand -base64 32  # Example: "xK8pQ2mN9vR..."
   ```

2. **Key Rotation**
   - Rotate keys every 90 days
   - Support multiple keys during rotation period
   - Remove old keys after clients migrate

3. **Key Management**
   - Never commit keys to version control
   - Use secrets management (AWS Secrets Manager, HashiCorp Vault)
   - Different keys per environment (dev/staging/prod)

4. **Client Usage**
   ```bash
   # Clients include Authorization header
   curl -X POST http://localhost:8080/mcp \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   ```

### CORS Configuration

CORS is enabled by default to support browser-based clients.

**Headers Included:**
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type, Authorization, X-Session-ID`
- `Access-Control-Max-Age: 86400` (24 hours)

**For stricter CORS:**
Modify `HTTPServerTransport.swift` to whitelist specific origins:
```swift
Access-Control-Allow-Origin: https://yourdomain.com
```

---

## HTTPS / TLS Setup

**⚠️ IMPORTANT:** Always use HTTPS in production when using API key authentication. API keys are sent in plaintext headers.

### Option 1: Reverse Proxy (Recommended)

Use Nginx or Caddy as a reverse proxy to handle TLS termination.

#### Nginx Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name mcp.yourdomain.com;

    # TLS/SSL Certificates
    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    # Modern TLS configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Proxy to MCP server
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        # SSE support
        proxy_set_header Connection '';
        proxy_set_header Cache-Control 'no-cache';
        proxy_buffering off;
        chunked_transfer_encoding off;

        # Forward headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # SSE endpoint configuration
    location /mcp/sse {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;

        # SSE-specific settings
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;  # 24 hours
        proxy_send_timeout 86400s;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name mcp.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

#### Caddy Configuration (Simpler)

```caddyfile
mcp.yourdomain.com {
    reverse_proxy localhost:8080 {
        # SSE support
        flush_interval -1
    }
}
```

Caddy automatically handles:
- HTTPS certificates (Let's Encrypt)
- HTTP → HTTPS redirects
- Modern TLS configuration

### Option 2: Docker with Traefik

```yaml
# docker-compose.yml
version: '3.8'

services:
  mcp-server:
    build: .
    command: ["./businessmath-mcp-server", "--http", "8080"]
    environment:
      - MCP_API_KEYS=${MCP_API_KEYS}
      - MCP_AUTH_REQUIRED=true
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mcp.rule=Host(`mcp.yourdomain.com`)"
      - "traefik.http.routers.mcp.entrypoints=websecure"
      - "traefik.http.routers.mcp.tls.certresolver=letsencrypt"
      - "traefik.http.services.mcp.loadbalancer.server.port=8080"

  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@yourdomain.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - web

networks:
  web:
    external: true
```

---

## Environment Configuration

### Required Environment Variables

```bash
# API Keys (comma-separated)
MCP_API_KEYS="key1,key2,key3"

# Authentication (default: true)
MCP_AUTH_REQUIRED=true  # or false for development
```

### Optional Environment Variables

```bash
# Server port (override --http flag)
MCP_HTTP_PORT=8080

# Log level (if implemented)
LOG_LEVEL=info  # debug, info, warning, error

# Session timeout (SSE, in seconds)
SSE_SESSION_TIMEOUT=300  # 5 minutes

# Heartbeat interval (SSE, in seconds)
SSE_HEARTBEAT_INTERVAL=30  # 30 seconds
```

---

## Deployment Options

### Systemd Service (Linux)

```ini
# /etc/systemd/system/businessmath-mcp.service
[Unit]
Description=BusinessMath MCP Server
After=network.target

[Service]
Type=simple
User=mcp
WorkingDirectory=/opt/businessmath-mcp
Environment="MCP_API_KEYS=your-key-here"
Environment="MCP_AUTH_REQUIRED=true"
ExecStart=/opt/businessmath-mcp/businessmath-mcp-server --http 8080
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/businessmath-mcp

[Install]
WantedBy=multi-user.target
```

**Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable businessmath-mcp
sudo systemctl start businessmath-mcp
sudo systemctl status businessmath-mcp
```

### Docker

```dockerfile
# Dockerfile
FROM swift:5.9-jammy

WORKDIR /app

# Copy source
COPY . .

# Build
RUN swift build -c release

# Runtime
FROM swift:5.9-jammy-slim
WORKDIR /app
COPY --from=0 /app/.build/release/businessmath-mcp-server .

EXPOSE 8080

CMD ["./businessmath-mcp-server", "--http", "8080"]
```

**Build and run:**
```bash
docker build -t businessmath-mcp .
docker run -d \
  -p 8080:8080 \
  -e MCP_API_KEYS="your-key" \
  -e MCP_AUTH_REQUIRED=true \
  --name mcp-server \
  --restart unless-stopped \
  businessmath-mcp
```

### Kubernetes

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: businessmath-mcp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: businessmath-mcp
  template:
    metadata:
      labels:
        app: businessmath-mcp
    spec:
      containers:
      - name: mcp-server
        image: businessmath-mcp:latest
        ports:
        - containerPort: 8080
        env:
        - name: MCP_API_KEYS
          valueFrom:
            secretKeyRef:
              name: mcp-secrets
              key: api-keys
        - name: MCP_AUTH_REQUIRED
          value: "true"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: businessmath-mcp
spec:
  selector:
    app: businessmath-mcp
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
---
apiVersion: v1
kind: Secret
metadata:
  name: mcp-secrets
type: Opaque
stringData:
  api-keys: "prod-key-1,prod-key-2"
```

---

## Monitoring & Logging

### Health Checks

```bash
# Health endpoint (no auth required)
curl http://localhost:8080/health
# Response: OK

# Server info
curl http://localhost:8080/mcp
# Returns: server version, endpoints, auth status
```

### Logging

**Redirect logs:**
```bash
./businessmath-mcp-server --http 8080 2>&1 | tee /var/log/mcp/server.log
```

**With systemd:**
```bash
# View logs
journalctl -u businessmath-mcp -f

# Export logs
journalctl -u businessmath-mcp --since today > mcp-logs.txt
```

### Metrics (Future Enhancement)

Consider implementing:
- Request count per endpoint
- Authentication success/failure rate
- Active SSE connections
- Average request duration
- Error rates

---

## Performance Tuning

### Connection Limits

The server uses Swift's Network framework which handles concurrency efficiently via actors.

**Monitor active connections:**
- SSE sessions tracked in `SSESessionManager`
- Configure session timeout: 5 minutes default
- Heartbeat interval: 30 seconds default

### Resource Limits

```bash
# Increase file descriptor limit (Linux)
ulimit -n 65536

# Set in systemd service
[Service]
LimitNOFILE=65536
```

### Scaling

**Horizontal Scaling:**
- Multiple server instances behind load balancer
- Session affinity required for SSE connections
- Use sticky sessions based on X-Session-ID

**Vertical Scaling:**
- Each SSE connection is lightweight (actor-based)
- Memory scales linearly with active sessions
- CPU usage primarily during JSON-RPC processing

---

## Troubleshooting

### Authentication Failures

**Problem:** All requests return 401 Unauthorized

**Solutions:**
1. Check API keys are set:
   ```bash
   echo $MCP_API_KEYS
   ```
2. Verify correct header format:
   ```bash
   curl -v -H "Authorization: Bearer YOUR_KEY" http://localhost:8080/mcp
   ```
3. Check server logs for "invalid API key" messages

### SSE Connection Issues

**Problem:** SSE connections timeout or disconnect

**Solutions:**
1. Check reverse proxy buffering is disabled
2. Verify firewall allows long-lived connections
3. Increase proxy timeout:
   ```nginx
   proxy_read_timeout 86400s;
   ```
4. Monitor heartbeat frequency (30s default)

### CORS Errors in Browser

**Problem:** Browser blocks cross-origin requests

**Solutions:**
1. Verify CORS headers present:
   ```bash
   curl -i http://localhost:8080/health | grep Access-Control
   ```
2. Check browser console for specific error
3. Ensure OPTIONS preflight succeeds (204 response)

### High Memory Usage

**Problem:** Server memory grows over time

**Solutions:**
1. Check for session leaks:
   - Monitor SSESessionManager.activeSessionCount()
   - Verify cleanup task running (logs show "Cleaned up expired session")
2. Reduce session timeout if needed
3. Implement connection limits

### Connection Refused

**Problem:** Cannot connect to server

**Solutions:**
1. Verify server is running:
   ```bash
   ps aux | grep businessmath-mcp-server
   ```
2. Check port is listening:
   ```bash
   lsof -i :8080
   ```
3. Check firewall rules:
   ```bash
   sudo ufw status
   ```

---

## Security Checklist

Before deploying to production:

- [ ] API keys configured via environment variables
- [ ] HTTPS enabled (reverse proxy or cloud load balancer)
- [ ] API keys are strong (32+ random characters)
- [ ] Keys rotated every 90 days
- [ ] Secrets not committed to version control
- [ ] CORS configured appropriately (restrict origins if possible)
- [ ] Health endpoint monitored
- [ ] Logs reviewed regularly for auth failures
- [ ] Firewall rules restrict access
- [ ] TLS 1.2+ only
- [ ] HTTP redirects to HTTPS
- [ ] Security headers configured (HSTS, X-Frame-Options)
- [ ] Rate limiting considered (via reverse proxy)

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/anthropics/businessmath/issues
- Documentation: See README.md
- MCP Protocol Spec: https://modelcontextprotocol.io

---

**Version:** 2.0.0
**Last Updated:** 2025-01-29
**Protocol:** MCP over HTTP + SSE with API Key Authentication
