#!/bin/bash

# ❗️ عدّل هذا المتغير إلى اسم نطاقك الحقيقي
DOMAIN="n8n.yourdomain.com"
EMAIL="you@example.com"  # استخدم بريدك لاستلام إشعارات SSL

# ✅ Step 1: تحديث النظام وتثبيت المتطلبات
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release nginx ufw

# ✅ Step 2: إعداد Docker + Docker Compose
sudo apt remove docker docker-engine docker.io containerd runc -y || true

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) 
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release; echo "$UBUNTU_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io 
docker-buildx-plugin docker-compose-plugin

# ✅ Step 3: إعداد n8n باستخدام Docker Compose
mkdir -p ~/n8n && cd ~/n8n

cat > docker-compose.yml <<EOF
version: '3.8'
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
      - WEBHOOK_URL=https://${DOMAIN}
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

docker compose up -d

# ✅ Step 4: إعداد NGINX كـ Reverse Proxy
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;

        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host  \$host;

        proxy_set_header Upgrade           \$http_upgrade;
        proxy_set_header Connection        "upgrade";

        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        client_max_body_size 50m;
    }
}
NGINX

sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default || true
sudo nginx -t && sudo systemctl reload nginx

# ✅ Step 5: تثبيت Certbot باستخدام Snap
sudo snap install core && sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# ✅ Step 6: الحصول على شهادة SSL من Let's Encrypt
sudo certbot --nginx --non-interactive --agree-tos --email $EMAIL -d 
$DOMAIN

# ✅ Step 7: اختبار التجديد التلقائي
sudo certbot renew --dry-run

# ✅ Step 8: تمكين الجدار الناري للسيرفر
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "✅ Done! Open https://$DOMAIN in your browser."
