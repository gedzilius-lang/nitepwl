#!/bin/bash
set -e

echo ">>> [Phase 8] Aligning Backend with Neon Frontend..."

cat << 'EOF' > /tmp/neon_backend.sh
#!/bin/bash
set -e

# 1. UPDATE LIQUIDSOAP (Add Timestamps for Progress Bar)
# The Neon frontend expects 'duration' and 'start' time in the JSON.
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", false)
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

# Music
audio = playlist("/var/www/autodj/music")
audio = mksafe(audio)

# Metadata Handler (Writes proper JSON for Neon Player)
def on_metadata(m) =
  artist = m["artist"]
  title = m["title"]
  duration = m["duration"] 
  # Fallback if duration missing
  duration = if duration == "" then "0" else duration end
  
  # Current Unix Timestamp
  start_time = time() 

  # Create JSON string manually
  json = '{"artist": "#{artist}", "title": "#{title}", "duration": #{duration}, "start": #{start_time}}'
  
  # Write to 'now_playing.json' (Neon Frontend expects this filename)
  system("echo '#{json}' > /var/www/html/now_playing.json")
end

audio = on_metadata(on_metadata, audio)

# Output
output.file(
  %wav, 
  "/dev/stdout", 
  audio
)
LIQ
chmod +x /etc/liquidsoap/autodj.liq

# 2. UPDATE NGINX (Serve the new JSON file)
SITE_CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

# Ensure the route exists for the new JSON filename
if ! grep -q "now_playing.json" "$SITE_CONF"; then
    # We insert the location block before the last closing brace
    sed -i '$d' "$SITE_CONF"
    cat << 'NGINX' >> "$SITE_CONF"

    location /now_playing.json {
        alias /var/www/html/now_playing.json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        default_type application/json;
    }
}
NGINX
fi

# 3. PERMISSIONS
touch /var/www/html/now_playing.json
chown liquidsoap:www-data /var/www/html/now_playing.json
chmod 664 /var/www/html/now_playing.json

# 4. RESTART
systemctl restart nginx
systemctl restart liquidsoap-radio

echo ">>> Backend Aligned. JSON is now at /now_playing.json"
EOF

scp /tmp/neon_backend.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/neon_backend.sh"
rm /tmp/neon_backend.sh
