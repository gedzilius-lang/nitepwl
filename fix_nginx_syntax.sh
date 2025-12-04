#!/bin/bash
set -e

echo ">>> [API FIX] Surgically restoring Nginx config..."
CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

cat << 'EOF' > /tmp/nginx_syntax_fix.sh
#!/bin/bash
set -e

# 1. OVERWRITE SITE CONFIG (Guaranteed correct syntax)
echo ">>> Rewriting site config to fix syntax errors..."

cat << 'NGINX' > /etc/nginx/sites-available/os.peoplewelike.club.conf
server {
    listen 80;
    server_name os.peoplewelike.club;
    # Redirect all HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name os.peoplewelike.club;

    # SSL configuration
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

    # --- RADIO HLS FILES (Verified Working) ---
    location /hls/ {
        alias /var/www/hls/;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache";
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    # Metadata JSON
    location /now_playing.json {
        alias /var/www/html/now_playing.json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache";
        default_type application/json;
    }

    # Frontend Routing (SPA Fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# 2. FINAL RESTART
echo ">>> Testing configuration and restarting Nginx..."
nginx -t && systemctl restart nginx

# 3. VERIFY API STATUS
echo ">>> Re-checking API status..."
sleep 5
API_STATUS=$(curl -o /dev/null -w "%{http_code}" -sL https://os.peoplewelike.club/api/users/demo)
echo "New API Status: $API_STATUS"

if [ "$API_STATUS" -eq "200" ]; then
    echo "✅ SUCCESS: API access restored. The site is back online."
else
    echo "❌ ERROR: API still inaccessible. Check 'sudo nite logs' for pm2 errors."
fi
EOF

scp /tmp/nginx_syntax_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/nginx_syntax_fix.sh"
rm /tmp/nginx_syntax_fix.sh
