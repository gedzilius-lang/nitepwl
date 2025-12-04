#!/bin/bash
set -e

echo ">>> [Radio] Restoring PDF Architecture (FFmpeg HLS)..."

cat << 'EOF' > /tmp/restore_backend.sh
#!/bin/bash
set -e

# 1. STOP & CLEANUP
systemctl stop liquidsoap-radio ffmpeg-autodj ffmpeg-live nginx || true
rm -rf /var/www/hls/live/*
rm -rf /var/www/hls/autodj/*
mkdir -p /var/www/hls/live
mkdir -p /var/www/hls/autodj
mkdir -p /var/www/autodj/music

# 2. SANITIZE MUSIC (Fixes "Loading" issue caused by bad filenames)
cd /var/www/autodj/music
find . -depth -name "* *" -execdir rename 's/ /_/g' "{}" \;
find . -depth -name "*[^a-zA-Z0-9._-]*" -execdir rename 's/[^a-zA-Z0-9._-]/_/g' "{}" \;

# 3. NGINX CONFIG (Pure RTMP + Static HLS serving)
cat << 'NGINX' > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events { worker_connections 1024; }

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        # OBS Input
        application live {
            live on;
            record off;
            allow play 127.0.0.1; # Only local FFmpeg can read this
        }

        # AutoDJ Input
        application autodj {
            live on;
            record off;
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

# 4. LIQUIDSOAP (Audio Source -> Pipe -> RTMP)
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", false)
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

audio = playlist("/var/www/autodj/music")
audio = mksafe(audio)

# JSON Metadata for Frontend
def on_metadata(m) =
  artist = m["artist"]
  title = m["title"]
  json = '{"artist": "#{artist}", "title": "#{title}"}'
  system("echo '#{json}' > /var/www/html/now_playing.json")
end
audio = on_metadata(on_metadata, audio)

# Pipe audio to stdout
output.file(%wav, "/dev/stdout", audio)
LIQ
chmod +x /etc/liquidsoap/autodj.liq

# 5. SERVICES (The PDF Architecture)

# Liquidsoap -> RTMP
cat << 'SVC' > /etc/systemd/system/liquidsoap-radio.service
[Unit]
Description=Liquidsoap AutoDJ
After=network.target
[Service]
ExecStart=/bin/bash -c '/usr/bin/liquidsoap /etc/liquidsoap/autodj.liq | /usr/bin/ffmpeg -re -f wav -i pipe:0 -c:a aac -b:a 128k -f flv rtmp://127.0.0.1/autodj/stream'
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVC

# AutoDJ RTMP -> HLS Files
cat << 'SVC' > /etc/systemd/system/ffmpeg-autodj.service
[Unit]
Description=FFmpeg AutoDJ HLS
After=network.target
[Service]
ExecStart=/usr/bin/ffmpeg -i rtmp://127.0.0.1/autodj/stream -vn -c:a aac -b:a 128k -f hls -hls_time 4 -hls_list_size 5 -hls_flags delete_segments /var/www/hls/autodj/stream.m3u8
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVC

# Live OBS RTMP -> HLS Files
cat << 'SVC' > /etc/systemd/system/ffmpeg-live.service
[Unit]
Description=FFmpeg Live HLS
After=network.target
[Service]
ExecStart=/usr/bin/ffmpeg -i rtmp://127.0.0.1/live/obs -c:v copy -c:a aac -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments /var/www/hls/live/obs.m3u8
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SVC

# 6. PERMISSIONS & RESTART
chown -R www-data:www-data /var/www/hls
chmod -R 755 /var/www/hls
# Allow Nite Dev to upload music
chown -R nite_dev:www-data /var/www/autodj/music
chmod -R 775 /var/www/autodj/music
# Create initial JSON to prevent 404
echo '{"title": "Loading..."}' > /var/www/html/now_playing.json
chown liquidsoap:www-data /var/www/html/now_playing.json
chmod 664 /var/www/html/now_playing.json

systemctl daemon-reload
systemctl enable --now liquidsoap-radio ffmpeg-autodj ffmpeg-live nginx

echo ">>> Backend Restored. Checking files..."
sleep 5
ls -lh /var/www/hls/autodj/
EOF

scp /tmp/restore_backend.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/restore_backend.sh"
rm /tmp/restore_backend.sh
