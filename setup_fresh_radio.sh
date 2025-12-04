#!/bin/bash
set -e

echo ">>> [Radio] Starting Fresh Installation (Liquidsoap Architecture)..."

cat << 'EOF' > /tmp/fresh_install.sh
#!/bin/bash
set -e

# 1. CLEANUP (Remove everything from previous attempts)
echo ">>> [1/6] Wiping old configurations..."
systemctl stop liquidsoap-radio ffmpeg-autodj ffmpeg-live nginx || true
rm -f /etc/systemd/system/liquidsoap-radio.service
rm -f /etc/systemd/system/ffmpeg-autodj.service
rm -f /etc/systemd/system/ffmpeg-live.service
rm -rf /var/www/hls/live
rm -rf /var/www/hls/autodj
# Note: We keep /var/www/autodj/music so you don't lose songs

# 2. PREPARE DIRECTORIES
echo ">>> [2/6] Creating Directories..."
mkdir -p /var/www/hls/live
mkdir -p /var/www/hls/autodj
mkdir -p /var/www/autodj/music
mkdir -p /var/log/liquidsoap

# Permissions
chown -R www-data:www-data /var/www/hls
chmod -R 755 /var/www/hls
chown -R nite_dev:www-data /var/www/autodj/music
chmod -R 775 /var/www/autodj/music
chown -R www-data:www-data /var/log/liquidsoap

# 3. SANITIZE MUSIC (Prevents Liquidsoap crashes)
echo ">>> [3/6] Sanitizing Music Filenames..."
cd /var/www/autodj/music
# Replace spaces and weird chars with underscores
find . -depth -name "* *" -execdir rename 's/ /_/g' "{}" \;
find . -depth -name "*[^a-zA-Z0-9._-]*" -execdir rename 's/[^a-zA-Z0-9._-]/_/g' "{}" \;

# 4. NGINX CONFIG (Live Video Engine)
echo ">>> [4/6] Configuring Nginx..."
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

        # LIVE STREAMING (OBS connects here)
        application live {
            live on;
            record off;
            
            # Native HLS Generation (Efficient for Video)
            hls on;
            hls_path /var/www/hls/live;
            hls_fragment 2s;
            hls_playlist_length 10s;
            hls_cleanup on;
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

# 5. LIQUIDSOAP CONFIG (Auto-DJ Audio Engine)
echo ">>> [5/6] Configuring Liquidsoap..."
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", false)
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

# 1. Source: Playlist
# Checks for new files every 60 seconds
audio = playlist(mode="randomize", reload=60, "/var/www/autodj/music")
audio = mksafe(audio)

# 2. Metadata: Write to JSON for Frontend
def on_metadata(m) =
  # Escape quotes to prevent broken JSON
  def escape(s) = string.replace(pattern='\"', by='\\\\"', s) end
  
  artist = escape(m["artist"])
  title = escape(m["title"])
  duration = m["duration"]
  duration = if duration == "" then "0" else duration end
  start_time = time() 

  json = '{"artist": "#{artist}", "title": "#{title}", "duration": #{duration}, "start": #{start_time}}'
  system("echo '#{json}' > /var/www/html/now_playing.json")
end

audio = on_metadata(on_metadata, audio)

# 3. Output: Pipe raw WAV to STDOUT (for FFmpeg to pick up)
output.file(%wav, "/dev/stdout", audio)
LIQ
chmod +x /etc/liquidsoap/autodj.liq

# 6. SERVICE: Liquidsoap -> FFmpeg -> HLS
echo ">>> [6/6] Creating System Service..."
cat << 'SVC' > /etc/systemd/system/liquidsoap-radio.service
[Unit]
Description=NiteOS Radio Engine
After=network.target

[Service]
# This command runs Liquidsoap, pipes audio to FFmpeg, which writes HLS files
ExecStart=/bin/bash -c '/usr/bin/liquidsoap /etc/liquidsoap/autodj.liq | /usr/bin/ffmpeg -f wav -i pipe:0 -vn -c:a aac -b:a 192k -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments /var/www/hls/autodj/stream.m3u8'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 7. START UP
systemctl daemon-reload
systemctl enable --now nginx
systemctl enable --now liquidsoap-radio

# Initialize dummy JSON to prevent 404 errors before music starts
echo '{"title": "Loading..."}' > /var/www/html/now_playing.json
chown liquidsoap:www-data /var/www/html/now_playing.json
chmod 664 /var/www/html/now_playing.json

echo ">>> INSTALLATION COMPLETE."
echo ">>> Verifying Signal..."
sleep 5
ls -lh /var/www/hls/autodj/
EOF

scp /tmp/fresh_install.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/fresh_install.sh"
rm /tmp/fresh_install.sh
