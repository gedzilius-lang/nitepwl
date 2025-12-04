#!/bin/bash
set -e

echo ">>> [Radio] Re-architecting Auto-DJ (Pipe Mode)..."

cat << 'EOF' > /tmp/radio_pipe_fix.sh
#!/bin/bash
set -e

# 1. Stop Services
systemctl stop ffmpeg-autodj liquidsoap-radio

# 2. Rewrite Liquidsoap Script (Output to Pipe)
# Instead of output.rtmp, we output to a raw audio pipe (fd:1 = stdout)
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", false) # Disable logs to stdout so we don't corrupt the audio pipe
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

# Playlist
audio = playlist("/var/www/autodj/music")
audio = mksafe(audio)

# Output RAW audio to STDOUT (Pipe)
output.file(
  %wav, 
  "/dev/stdout", 
  audio
)
LIQ
chmod +x /etc/liquidsoap/autodj.liq
mkdir -p /var/log/liquidsoap
chown -R www-data:www-data /var/log/liquidsoap

# 3. Rewrite Systemd Service (Pipe Architecture)
# We pipe Liquidsoap (Audio) -> FFmpeg (Encoder) -> RTMP (Nginx)
cat << 'SVC' > /etc/systemd/system/liquidsoap-radio.service
[Unit]
Description=Liquidsoap AutoDJ (Pipe to FFmpeg)
After=network.target

[Service]
# The Magic: Liquidsoap | FFmpeg -> RTMP
ExecStart=/bin/bash -c '/usr/bin/liquidsoap /etc/liquidsoap/autodj.liq | /usr/bin/ffmpeg -f wav -i pipe:0 -c:a aac -b:a 128k -f flv rtmp://127.0.0.1/autodj/stream'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 4. Disable the old standalone ffmpeg-autodj service
# (Since ffmpeg is now part of the liquidsoap pipeline)
systemctl disable --now ffmpeg-autodj

# 5. Restart
systemctl daemon-reload
systemctl start liquidsoap-radio

# 6. Diagnostics
echo ">>> Waiting for stream to initialize..."
sleep 5
echo "--- Service Status ---"
systemctl status liquidsoap-radio --no-pager | grep "Active:"
echo "--- HLS Files Check ---"
ls -lh /var/www/hls/autodj/
EOF

# Run
scp /tmp/radio_pipe_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/radio_pipe_fix.sh"
rm /tmp/radio_pipe_fix.sh
