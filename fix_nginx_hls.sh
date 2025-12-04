#!/bin/bash
set -e

echo ">>> [Radio] Enabling Native HLS in Nginx..."

cat << 'EOF' > /tmp/nginx_hls_fix.sh
#!/bin/bash

# 1. Rewrite Nginx Config with 'hls on;'
cat << 'NGINX' > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        # Live Stream (OBS)
        application live {
            live on;
            record off;
            
            # Enable HLS Generation
            hls on;
            hls_path /var/www/hls/live;
            hls_fragment 2s;
            hls_playlist_length 10s;
            
            # Cleanup
            hls_cleanup on;
        }

        # Auto-DJ Stream (Liquidsoap)
        application autodj {
            live on;
            record off;
            
            # Enable HLS Generation
            hls on;
            hls_path /var/www/hls/autodj;
            hls_fragment 4s;
            hls_playlist_length 20s;
            
            # Only allow localhost to publish here
            allow publish 127.0.0.1;
            deny publish all;
        }
    }
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINX

# 2. Ensure Directories exist and are writable by Nginx
mkdir -p /var/www/hls/live
mkdir -p /var/www/hls/autodj
chown -R www-data:www-data /var/www/hls
chmod -R 755 /var/www/hls

# 3. Restart Nginx to apply HLS settings
systemctl restart nginx

# 4. Restart Liquidsoap to reconnect
systemctl restart liquidsoap-radio

# 5. Verify
echo ">>> Waiting for HLS segments..."
sleep 5
echo "--- AutoDJ HLS Files ---"
ls -lh /var/www/hls/autodj/
EOF

# Run remotely
scp /tmp/nginx_hls_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/nginx_hls_fix.sh"
rm /tmp/nginx_hls_fix.sh
