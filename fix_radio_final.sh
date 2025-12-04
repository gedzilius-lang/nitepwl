#!/bin/bash
set -e

echo ">>> [Radio] Applying Master Fix (HTTPS + Filenames)..."

cat << 'EOF' > /tmp/radio_master_fix.sh
#!/bin/bash
set -e

# ==========================================
# 1. SANITIZE MUSIC FILENAMES (Fix "Loading" on AutoDJ)
# ==========================================
echo ">>> [1/3] Sanitizing MP3 Filenames..."
cd /var/www/autodj/music

# Rename files to remove spaces and special characters
# Example: "My Song!.mp3" -> "My_Song_.mp3"
find . -depth -name "* *" -execdir rename 's/ /_/g' "{}" \;
find . -depth -name "*[^a-zA-Z0-9._-]*" -execdir rename 's/[^a-zA-Z0-9._-]/_/g' "{}" \;

echo "✅ Music filenames sanitized."

# ==========================================
# 2. RECONFIGURE NGINX (Fix HTTPS & HLS Serving)
# ==========================================
echo ">>> [2/3] Rewriting Nginx Site Config..."

# We assume Certbot has already generated keys.
# We explicitly add the HLS routes to the SSL block.

cat << 'NGINX_SITE' > /etc/nginx/sites-available/os.peoplewelike.club.conf
server {
    listen 80;
    server_name os.peoplewelike.club;
    # Redirect all HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name os.peoplewelike.club;

    # SSL Certs (Standard Certbot path)
    ssl_certificate /etc/letsencrypt/live/os.peoplewelike.club/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/os.peoplewelike.club/privkey.pem;

    # Web Root (Frontend)
    root /opt/nite-os-v7/frontend/dist;
    index index.html;

    # --- RADIO STREAMING ROUTES (Crucial) ---
    
    # Auto-DJ HLS
    location /hls/autodj/ {
        alias /var/www/hls/autodj/;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    # Live HLS
    location /hls/live/ {
        alias /var/www/hls/live/;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    # Backend API Proxy
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Metadata JSON (Current Song)
    location /radio_status.json {
        alias /var/www/html/radio_status.json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control no-cache;
        default_type application/json;
    }

    # Frontend Routing (SPA Fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX_SITE

# Link it
ln -sf /etc/nginx/sites-available/os.peoplewelike.club.conf /etc/nginx/sites-enabled/os.peoplewelike.club.conf

# ==========================================
# 3. RESTART SYSTEM
# ==========================================
echo ">>> [3/3] Restarting Radio Services..."

# Restart Nginx to apply new routes
nginx -t && systemctl restart nginx

# Restart Liquidsoap to reload sanitized playlist
systemctl restart liquidsoap-radio

# Give it a moment to generate the first segment
sleep 5

# Verify files exist
echo "--- HLS Status ---"
ls -lh /var/www/hls/autodj/ | head -n 5

echo ">>> FIX COMPLETE."
EOF

# Execute on VPS
scp /tmp/radio_master_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/radio_master_fix.sh"
rm /tmp/radio_master_fix.sh
