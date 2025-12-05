#!/bin/bash
set -e

SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> [Public Access] Fixing Nginx Frontend Path..."

ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash -s" << 'REMOTE'
set -e

# 1. Update Nginx Site Config
# We replace the old path '/opt/nite-os-v7' with the new '/opt/nite-os'
CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

echo "   --> Updating $CONF..."
cat << 'NGINX' > "$CONF"
server {
    listen 80;
    server_name os.peoplewelike.club;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name os.peoplewelike.club;

    # SSL Certificates (Managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/os.peoplewelike.club/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/os.peoplewelike.club/privkey.pem;

    # --- FRONTEND ROOT (CORRECTED PATH) ---
    root /opt/nite-os/frontend/dist;
    index index.html;

    # --- API PROXY ---
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # --- SPA FALLBACK ---
    # Any route not found (like /market or /profile) falls back to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# 2. Restart Nginx to apply changes
echo "   --> Restarting Nginx..."
nginx -t && systemctl restart nginx

echo "✅ SUCCESS: Website is now serving from /opt/nite-os/frontend/dist"
REMOTE
