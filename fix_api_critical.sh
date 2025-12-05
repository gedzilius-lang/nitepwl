#!/bin/bash
set -e

SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> [CRITICAL RESTORE] Forcing application reload and Nginx sync..."

# Execute the restoration script on the VPS via SSH
ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash -s" << 'EOF'
#!/bin/bash
set -e

# 1. FIX NGINX SYNTAX (Ensure API Proxy is perfect and guaranteed to work)
echo ">>> [1/3] Restoring clean Nginx configuration to guarantee API proxy..."
CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

# The most reliable Nginx site configuration
cat << 'NGINX' > "$CONF"
server {
    listen 80;
    server_name os.peoplewelike.club;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name os.peoplewelike.club;

    ssl_certificate /etc/letsencrypt/live/os.peoplewelike.club/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/os.peoplewelike.club/privkey.pem;

    root /opt/nite-os-v7/frontend/dist;
    index index.html;

    # --- API PROXY (FIXED) ---
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- HLS STREAM ACCESS ---
    location /hls/ {
        alias /var/www/hls/;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache";
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# 2. FORCE NESTJS APPLICATION RELOAD
echo ">>> [2/3] Forcing application stop and clean restart to re-register routes..."
# Stop and restart PM2 cleanly
pm2 stop nite-backend
sleep 2
pm2 start nite-backend

# 3. VERIFY NGINX AND API
echo ">>> [3/3] Testing configuration and verifying API..."
nginx -t
systemctl restart nginx

# API Status Check
API_FINAL_STATUS=$(curl -o /dev/null -w "%{http_code}" -sL https://os.peoplewelike.club/api/users/demo)
echo "Final API Status: $API_FINAL_STATUS"

if [ "$API_FINAL_STATUS" -eq "200" ]; then
    echo "✅ FIX SUCCESS: API and site functionality restored."
else
    echo "❌ FIX FAILED: Application is likely crashing on startup. Check 'pm2 logs nite-backend --err'."
fi
EOF
