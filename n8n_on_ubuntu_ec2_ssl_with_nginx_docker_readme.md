## 0) Prerequisites
- **Ubuntu 22.04/24.04** EC2 instance (x86_64).
- Security Group allows inbound **TCP 80** and **TCP 443**.
- DNS **A record**: `n8n-youtube.neoonai.com → <EC2 public IP>` (or your chosen hostname).
- SSH access as `ubuntu` (or your user) with `sudo` rights.

> If you’re using Cloudflare, set the subdomain to **DNS-only (grey cloud)** while issuing the certificate.

---

## 1) Set your domain as a shell variable
```bash
export DOMAIN="n8n-youtube.neoonai.com"   # change me
```
Sanity-check DNS:
```bash
dig +short "$DOMAIN"
```
It should return your EC2 public IP.

---

## 2) Install Docker Engine & Compose plugin (official repo)
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker repo (jammy/noble auto-detected)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $UBUNTU_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Optional: run docker without sudo (relog after this)
sudo usermod -aG docker $USER
```

Verify:
```bash
docker --version
docker compose version
```

---
## 3) Start n8n (choose **one**)
> We’ll keep n8n bound to **localhost** and let NGINX proxy it. This hides port 5678 from the internet.

### A) Single container (recommended for simplicity)
**Named volume** for persistent data:
```bash
docker volume create n8n_data

# Stop any old container on 5678 (ignore errors)
docker rm -f n8n 2>/dev/null || true

# Run n8n on localhost only
docker run -d --name n8n \
  --restart unless-stopped \
  -p 127.0.0.1:5678:5678 \
  -e N8N_HOST="$DOMAIN" \
  -e N8N_PROTOCOL="https" \
  -e N8N_PORT="5678" \
  -e N8N_EDITOR_BASE_URL="https://$DOMAIN/" \
  -e WEBHOOK_URL="https://$DOMAIN/" \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n:latest

# Local health check
curl -I http://127.0.0.1:5678
```

### B) Docker Compose (if you prefer a file)
Create a project folder:
```bash
mkdir -p ~/n8n && cd ~/n8n
echo "DOMAIN=$DOMAIN" > .env
```
`docker-compose.yml`:
```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"  # private
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - N8N_EDITOR_BASE_URL=https://${DOMAIN}/
      - WEBHOOK_URL=https://${DOMAIN}/
    volumes:
      - ./n8n_data:/home/node/.n8n
```
Start it:
```bash
docker compose up -d
curl -I http://127.0.0.1:5678
```

> **If port is busy:** free it with `docker ps | awk '/5678->/ {print $1}' | xargs -r docker rm -f` or change the host mapping to `127.0.0.1:5680:5678` (and later point NGINX to `5680`).

---

## 4) Install NGINX and create a reverse proxy
```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable --now nginx
# If UFW is enabled:
sudo ufw allow 'Nginx Full' || true
```

Create an NGINX site for your domain (HTTP → proxy to n8n):
```bash
sudo tee /etc/nginx/sites-available/$DOMAIN >/dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name n8n-youtube.neoonai.com;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;

        # Required headers for apps behind a reverse proxy
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host  $host;

        # WebSocket/SSE
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";

        # Timeouts & payloads
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        client_max_body_size 50m;
    }
}
NGINX

# Enable the site and (optionally) disable the default
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
sudo rm -f /etc/nginx/sites-enabled/default || true

# Test config and reload
sudo nginx -t && sudo systemctl reload nginx
```

> If you mapped n8n to `127.0.0.1:5680`, change `proxy_pass` to `http://127.0.0.1:5680;`.

---

## 5) Issue a Let’s Encrypt certificate (Certbot)
Use **snap** (recommended):
```bash
sudo mkdir -p /var/www/certbot
sudo snap install core && sudo snap refresh core
sudo apt-get remove -y certbot 2>/dev/null || true
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Obtain and install cert (auto-adds HTTPS server block + redirect)
sudo certbot --nginx -d "$DOMAIN"
# If using apex and www:
# sudo certbot --nginx -d neoonai.com -d www.neoonai.com

# Dry-run renew test
sudo certbot renew --dry-run
```

Open in browser: `https://$DOMAIN` → you should see the n8n UI.

---

## 6) Post‑setup sanity checks
```bash
# DNS → IP
dig +short "$DOMAIN"

# n8n local
curl -I http://127.0.0.1:5678

# HTTPS via NGINX
curl -I https://$DOMAIN

# NGINX errors (if 502/404)
sudo tail -n 100 /var/log/nginx/error.log
```

Common fixes:
- **502 Bad Gateway** → n8n not running / wrong port → `docker ps`, `curl http://127.0.0.1:5678`.
- **Empty OAuth redirect like `https:///rest/...`** → set `N8N_HOST`, `N8N_PROTOCOL=https`, `N8N_EDITOR_BASE_URL`, `WEBHOOK_URL`.
- **Cloudflare** → switch to **DNS-only** for issuance or use DNS challenge.

---

## 7) Google OAuth (e.g., Google Drive credentials)
n8n will display a redirect like:
```
https://$DOMAIN/rest/oauth2-credential/callback
```
Add **that exact URL** to Google Cloud Console → APIs & Services → **Credentials** → your OAuth 2.0 Client → **Authorized redirect URIs**.

If the URL is missing the host (`https:///rest/...`), recreate the container with the envs in Step 3 (A/B).

---

## 8) Backups & updates
- **Data volume** contains workflows/creds: `n8n_data` or `~/n8n/n8n_data`.
- **Backup** (named volume):
  ```bash
  docker run --rm -v n8n_data:/data -v $PWD:/backup alpine tar czf /backup/n8n_backup_$(date +%F).tgz -C / data
  ```
- **Update n8n**:
  ```bash
  docker pull docker.n8n.io/n8nio/n8n:latest
  docker rm -f n8n && \
  docker run -d --name n8n \
    --restart unless-stopped \
    -p 127.0.0.1:5678:5678 \
    -e N8N_HOST="$DOMAIN" \
    -e N8N_PROTOCOL="https" \
    -e N8N_PORT="5678" \
    -e N8N_EDITOR_BASE_URL="https://$DOMAIN/" \
    -e WEBHOOK_URL="https://$DOMAIN/" \
    -v n8n_data:/home/node/.n8n \
    docker.n8n.io/n8nio/n8n:latest
  ```

---

## 9) Troubleshooting quick commands
```bash
# Who owns port 5678?
sudo ss -ltnp | grep :5678 || true

# Remove any container publishing 5678
docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | awk '/:5678->/ {print $1}' | xargs -r docker rm -f

# Container logs
docker logs --tail=100 n8n

# Validate NGINX
sudo nginx -t && sudo systemctl reload nginx
sudo tail -n 100 /var/log/nginx/error.log
```

---

## 10) Optional hardening
- Keep only necessary inbound ports open in the Security Group (80/443).
- Remove the default NGINX site (`/etc/nginx/sites-enabled/default`).
- Use a firewall (UFW) if desired: `sudo ufw allow 'Nginx Full'`.
- Consider automatic OS updates: `sudo unattended-upgrades`.

---

### You’re done!
- n8n runs privately on `127.0.0.1:5678`.
- NGINX serves `https://$DOMAIN` with a valid Let’s Encrypt cert.
- OAuth redirects work at `https://$DOMAIN/rest/oauth2-credential/callback`.

