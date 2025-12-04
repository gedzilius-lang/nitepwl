#!/bin/bash
set -e

echo ">>> [Radio] Fixing Auto-DJ Signal Chain..."

cat << 'EOF' > /tmp/radio_deep_fix.sh
#!/bin/bash

# 1. Install Missing Liquidsoap Plugins (The common culprit)
echo ">>> [1/4] Ensuring Liquidsoap has RTMP support..."
# On Ubuntu, we often need the ffmpeg/cry plugins explicitly
apt-get update
apt-get install -y liquidsoap-plugin-all ffmpeg || true

# 2. Restart Nginx First (To ensure the door is open)
echo ">>> [2/4] Restarting Nginx (RTMP Server)..."
systemctl restart nginx
# Wait for Nginx to bind port 1935
sleep 2

# 3. Restart Liquidsoap (The Source)
echo ">>> [3/4] Restarting Auto-DJ (Liquidsoap)..."
systemctl restart liquidsoap-radio
# Wait for Liquidsoap to connect to Nginx
sleep 5

# 4. Restart FFmpeg (The Recorder)
echo ">>> [4/4] Restarting HLS Transcoder..."
systemctl restart ffmpeg-autodj

# 5. DIAGNOSTICS (Show us the truth)
echo "===================================================="
echo ">>> DIAGNOSTIC LOGS (Review Carefully)"
echo "===================================================="

echo "--- 1. Liquidsoap Logs (Last 20 lines) ---"
journalctl -u liquidsoap-radio -n 20 --no-pager

echo ""
echo "--- 2. Nginx RTMP Logs (Last 10 lines) ---"
tail -n 10 /var/log/nginx/error.log

echo ""
echo "--- 3. FFmpeg AutoDJ Logs (Last 20 lines) ---"
journalctl -u ffmpeg-autodj -n 20 --no-pager

echo ""
echo "--- 4. RESULT: HLS File Check ---"
ls -lh /var/www/hls/autodj/
EOF

# Run remotely
scp /tmp/radio_deep_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/radio_deep_fix.sh"
rm /tmp/radio_deep_fix.sh
