#!/bin/bash
set -e

echo ">>> [Radio Final Fix] Restoring Systemd Service Units..."

cat << 'EOF' > /tmp/restore_units.sh
#!/bin/bash
set -e

# 1. STOP & CLEANUP
echo ">>> Stopping all radio services..."
systemctl stop liquidsoap-radio ffmpeg-autodj ffmpeg-live || true

# 2. RECREATE SYSTEMD UNITS (The missing links)
echo ">>> Creating systemd service units..."

# Service 1: Liquidsoap -> HLS Writer (Pipe)
cat << 'SVC' > /etc/systemd/system/liquidsoap-radio.service
[Unit]
Description=NiteOS Radio Engine (AutoDJ Source)
After=network.target

[Service]
# This command forces Liquidsoap to pipe raw PCM audio into FFmpeg, 
# which then outputs the final HLS stream directly to disk.
ExecStart=/bin/bash -c '/usr/bin/liquidsoap /etc/liquidsoap/autodj.liq 2>/dev/null | /usr/bin/ffmpeg -f s16le -ar 44100 -ac 2 -i pipe:0 -vn -c:a aac -b:a 192k -f hls -hls_time 4 -hls_list_size 10 -hls_flags delete_segments /var/www/hls/autodj/stream.m3u8'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# Service 2: Live OBS RTMP -> HLS Files (Needed for Live Takeover)
# This handles the live video stream from OBS.
cat << 'SVC' > /etc/systemd/system/ffmpeg-live.service
[Unit]
Description=FFmpeg Live HLS Transcoder
After=network.target

[Service]
ExecStart=/usr/bin/ffmpeg -i rtmp://127.0.0.1/live/obs -c:v copy -c:a aac -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments /var/www/hls/live/obs.m3u8
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 3. START UP
echo ">>> Reloading daemon and starting services..."
systemctl daemon-reload
systemctl enable --now liquidsoap-radio
systemctl enable --now ffmpeg-live

echo ">>> FINAL CHECK: HLS Output Files"
sleep 5
ls -lh /var/www/hls/autodj/
EOF

# Execute on VPS
scp /tmp/restore_units.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/restore_units.sh"
rm /tmp/restore_units.sh
