#!/bin/bash
set -e

echo ">>> [Phase 7] Installing Radio Infrastructure on VPS..."

cat << 'EOF' > /tmp/remote_radio_install.sh
#!/bin/bash
set -e

# 1. Install Dependencies
echo ">>> [1/5] Installing Media Tools..."
apt-get update
apt-get install -y ffmpeg liquidsoap libnginx-mod-rtmp

# 2. Create Directories
echo ">>> [2/5] Creating Stream Directories..."
mkdir -p /var/www/hls/live
mkdir -p /var/www/hls/autodj
mkdir -p /var/www/autodj/music

# Permissions: Nginx needs to read, FFmpeg needs to write
chown -R www-data:www-data /var/www/hls
chmod -R 755 /var/www/hls

# 3. Liquidsoap Auto-DJ Script
echo ">>> [3/5] Configuring Auto-DJ..."
mkdir -p /etc/liquidsoap
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", true)
set("init.allow_root", true)

# Music Playlist
audio = playlist("/var/www/autodj/music")

# Fallback if playlist empty (Silence)
audio = mksafe(audio)

# Output to local RTMP
output.rtmp(
  url="rtmp://127.0.0.1/autodj/stream",
  audio
)
LIQ
chmod +x /etc/liquidsoap/autodj.liq

# 4. Systemd Services (FFmpeg Muxers)
echo ">>> [4/5] Creating Background Services..."

# Service: AutoDJ -> HLS
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

# Service: Live OBS -> HLS
cat << 'SVC' > /etc/systemd/system/ffmpeg-live.service
[Unit]
Description=FFmpeg Live HLS
After=network.target

[Service]
# Note: This will fail/restart loop until you actually stream, which is fine.
ExecStart=/usr/bin/ffmpeg -i rtmp://127.0.0.1/live/obs -c:v copy -c:a aac -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments /var/www/hls/live/obs.m3u8
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# Service: Liquidsoap
cat << 'SVC' > /etc/systemd/system/liquidsoap-radio.service
[Unit]
Description=Liquidsoap AutoDJ
After=network.target

[Service]
ExecStart=/usr/bin/liquidsoap /etc/liquidsoap/autodj.liq
Restart=always

[Install]
WantedBy=multi-user.target
SVC

# 5. Enable Services
systemctl daemon-reload
systemctl enable ffmpeg-autodj
systemctl enable ffmpeg-live
systemctl enable liquidsoap-radio

# Don't start yet until we configure Nginx (next step)
echo ">>> Infrastructure Installed."
EOF

# Execute on VPS
scp /tmp/remote_radio_install.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/remote_radio_install.sh"
rm /tmp/remote_radio_install.sh
