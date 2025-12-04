#!/bin/bash
set -e

echo ">>> [Radio] Starting Signal Repair..."

cat << 'EOF' > /tmp/radio_fix.sh
#!/bin/bash

# 1. FIX PERMISSIONS (Crucial for AutoDJ)
echo ">>> [1/4] Fixing File Permissions..."
# Ensure Nginx/Liquidsoap can read the music
chown -R nite_dev:www-data /var/www/autodj/music
chmod -R 775 /var/www/autodj/music

# Ensure FFmpeg can write the streams
chown -R www-data:www-data /var/www/hls
chmod -R 755 /var/www/hls

# 2. CHECK MUSIC FILES
echo ">>> [2/4] Verifying Music Library..."
SONG_COUNT=$(ls /var/www/autodj/music | wc -l)
if [ "$SONG_COUNT" -eq "0" ]; then
    echo "⚠️  WARNING: No music found in /var/www/autodj/music!"
    echo "   Please upload MP3s via SFTP."
else
    echo "✅ Found $SONG_COUNT songs."
fi

# 3. RESTART TRANSCODING ENGINES
echo ">>> [3/4] Restarting Transcoders..."
# Stop everything first to clear locks
systemctl stop ffmpeg-live ffmpeg-autodj liquidsoap-radio

# Clear old stuck stream segments
rm -f /var/www/hls/live/*.ts /var/www/hls/live/*.m3u8
rm -f /var/www/hls/autodj/*.ts /var/www/hls/autodj/*.m3u8

# Start Liquidsoap (The Source)
systemctl start liquidsoap-radio
sleep 2

# Start AutoDJ Transcoder
systemctl start ffmpeg-autodj

# Start Live Transcoder
systemctl start ffmpeg-live

# 4. DIAGNOSTICS
echo ">>> [4/4] System Health:"
echo "--- Liquidsoap Status ---"
systemctl status liquidsoap-radio --no-pager | grep "Active:"
echo "--- FFmpeg AutoDJ Status ---"
systemctl status ffmpeg-autodj --no-pager | grep "Active:"
echo "--- HLS Output Files (Should show .ts files) ---"
ls -lh /var/www/hls/autodj/ | head -n 5

echo ">>> REPAIR COMPLETE."
EOF

# Run remotely
scp /tmp/radio_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/radio_fix.sh"
rm /tmp/radio_fix.sh
