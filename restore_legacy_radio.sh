#!/bin/bash
set -e

echo ">>> [Radio] Restoring Legacy Architecture (PDF Based)..."

cat << 'EOF' > /tmp/restore_radio.sh
#!/bin/bash
set -e

# 1. STOP EVERYTHING
systemctl stop nginx liquidsoap-radio ffmpeg-autodj ffmpeg-live || true

# 2. CLEANUP NGINX (Revert to Pure RTMP - No HLS Generation)
# We remove 'hls on' because FFmpeg will handle it (as per PDF)
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

        # Live Ingest (OBS)
        application live {
            live on;
            record off;
            # Allow local FFmpeg to read this
            allow play 127.0.0.1;
        }

        # AutoDJ Ingest (Liquidsoap)
        application autodj {
            live on;
            record off;
            # Only allow localhost to publish
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

# 3. CONFIGURE LIQUIDSOAP (AutoDJ + Metadata)
# Adapted: Uses pipe to FFmpeg to push to RTMP (Fixes 'no method rtmp' error)
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", false)
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

# 1. Load Music
audio = playlist("/var/www/autodj/music")
audio = mksafe(audio)

# 2. Metadata Handler (Writes JSON for Frontend Visuals)
def on_metadata(m) =
  artist = m["artist"]
  title = m["title"]
  json = '{"artist": "#{artist}", "title": "#{title}"}'
  system("echo '#{json}' > /var/www/html/radio_status.json")
end
audio = on_metadata(on_metadata, audio)

# 3. Output: Pipe raw audio to STDOUT
output.file(
  %wav, 
  "/dev/stdout", 
  audio
)
LIQ
chmod +x /etc/liquidsoap/autodj.liq

# 4. SYSTEMD SERVICE: LIQUIDSOAP (Feeds Nginx RTMP)
cat << 'SVC' > /etc/systemd/system/liquidsoap-radio.service
[Unit]
Description=Liquidsoap AutoDJ (Source)
After=network.target

[Service]
# Pipes Audio -> FFmpeg -> RTMP (application autodj)
ExecStart=/bin/bash -c '/usr/bin/liquidsoap /etc/liquidsoap/autodj.liq | /usr/bin/ffmpeg -re -f wav -i pipe:0 -c:a aac -b:a 128k -f flv rtmp://127.0.0.1/autodj/stream'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 5. SYSTEMD SERVICE: FFMPEG AUTODJ (RTMP -> HLS)
# [cite_start]Matches PDF Page 5 [cite: 105-113]
cat << 'SVC' > /etc/systemd/system/ffmpeg-autodj.service
[Unit]
Description=FFmpeg AutoDJ HLS
After=network.target

[Service]
# Reads RTMP, writes .m3u8 file
ExecStart=/usr/bin/ffmpeg -i rtmp://127.0.0.1/autodj/stream \
    -vn -c:a aac -b:a 128k -f hls \
    -hls_time 4 -hls_list_size 5 -hls_flags delete_segments \
    /var/www/hls/autodj/stream.m3u8
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 6. SYSTEMD SERVICE: FFMPEG LIVE (RTMP -> HLS)
# [cite_start]Matches PDF Page 5 [cite: 94-102]
cat << 'SVC' > /etc/systemd/system/ffmpeg-live.service
[Unit]
Description=FFmpeg Live HLS
After=network.target

[Service]
# Reads RTMP, writes .m3u8 file
ExecStart=/usr/bin/ffmpeg -i rtmp://127.0.0.1/live/obs \
    -c:v copy -c:a aac -f hls \
    -hls_time 2 -hls_list_size 6 -hls_flags delete_segments \
    /var/www/hls/live/obs.m3u8
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 7. RESET DIRECTORIES
rm -rf /var/www/hls/live/*
rm -rf /var/www/hls/autodj/*
mkdir -p /var/www/hls/live
mkdir -p /var/www/hls/autodj
chown -R www-data:www-data /var/www/hls
chmod -R 775 /var/www/hls

# 8. START EVERYTHING
systemctl daemon-reload
systemctl restart nginx
systemctl enable --now liquidsoap-radio
systemctl enable --now ffmpeg-autodj
systemctl enable --now ffmpeg-live

echo ">>> [Radio] Architecture Restored."
echo "    1. Liquidsoap -> RTMP (AutoDJ)"
echo "    2. FFmpeg -> HLS (AutoDJ)"
echo "    3. FFmpeg -> HLS (Live)"
echo "--------------------------------"
echo "Verifying Files..."
sleep 5
ls -lh /var/www/hls/autodj/
EOF

scp /tmp/restore_radio.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/restore_radio.sh"
rm /tmp/restore_radio.sh
