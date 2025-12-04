#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
FRONTEND_DIR="$PROJECT_DIR/frontend/src/views"
CONFIG_DIR="$PROJECT_DIR/ops/configs/production"

echo ">>> [SYSTEM RESTORE] Fixing API and simplifying Radio..."

# 1. SERVER FIX: RESTORE NGINX SITE CONFIG (Guaranteed working syntax)
# This fixes the 502/404 API errors caused by previous config scripts.
cat << 'EOF' > /tmp/nginx_api_restore.sh
#!/bin/bash
set -e

CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

cat << 'NGINX' > "$CONF"
server {
    listen 80;
    server_name os.peoplewelike.club;
    # Force HTTPS redirect
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name os.peoplewelike.club;

    ssl_certificate /etc/letsencrypt/live/os.peoplewelike.club/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/os.peoplewelike.club/privkey.pem;

    root /opt/nite-os-v7/frontend/dist;
    index index.html;

    # --- API PROXY (FIXED) ---
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- HLS STREAM ACCESS (Restored for Player) ---
    location /hls/ {
        alias /var/www/hls/;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache";
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    # Metadata (for basic display)
    location /now_playing.json {
        alias /var/www/html/now_playing.json;
        add_header Access-Control-Allow-Origin *;
        default_type application/json;
    }

    # Frontend Routing (SPA Fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

echo ">>> Testing and restarting Nginx..."
nginx -t && systemctl restart nginx
echo ">>> API should be back."
EOF

# Push and Execute API Restore
scp /tmp/nginx_api_restore.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/nginx_api_restore.sh"
rm /tmp/nginx_api_restore.sh

# 2. FRONTEND DOWNGRADE: Create Simple Radio Player
echo ">>> Replacing complex Radio component with simple player..."
cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="simple-radio-container">
    <h1>📻 Nite Radio - Basic Stream</h1>
    <p>Status: Click play below. Live status is shown by the video stream.</p>

    <div class="player-wrapper">
        <h2 class="stream-title">🔴 LIVE FEED</h2>
        <video ref="livePlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
    </div>
    
    <div class="player-wrapper">
        <h2 class="stream-title">🎧 AUTO-DJ MUSIC</h2>
        <video ref="autodjPlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
    </div>

    <p class="small-note">Note: For simultaneous playback, browsers often prefer only one player active.</p>
  </div>
</template>

<script>
import videojs from 'video.js';
import 'video.js/dist/video-js.css';

export default {
  mounted() {
    this.initLivePlayer();
    this.initAutodjPlayer();
  },
  methods: {
    initLivePlayer() {
      // Live Stream (OBS)
      videojs(this.$refs.livePlayer, {
        controls: true,
        autoplay: 'muted',
        sources: [{ src: 'https://os.peoplewelike.club/hls/live/obs.m3u8', type: 'application/vnd.apple.mpegurl' }]
      });
    },
    initAutodjPlayer() {
      // Auto-DJ (Music)
      videojs(this.$refs.autodjPlayer, {
        controls: true,
        autoplay: 'muted',
        sources: [{ src: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8', type: 'application/vnd.apple.mpegurl' }]
      });
    }
  }
}
</script>

<style scoped>
.simple-radio-container { max-width: 900px; margin: 0 auto; padding: 20px; }
.player-wrapper { margin-bottom: 30px; border: 1px solid #333; border-radius: 8px; overflow: hidden; background: #000; }
.stream-title { padding: 10px; background: #1a1a1a; margin: 0; font-size: 1rem; }
/* Ensure players scale */
:deep(.video-js) { width: 100% !important; height: auto !important; aspect-ratio: 16/9; }
.small-note { margin-top: 20px; color: #888; font-size: 0.9rem; }
</style>
VUE

# 3. COMMIT AND DEPLOY
echo ">>> Committing and Deploying final simplified code..."
cd "$PROJECT_DIR"
git add .
git commit -m "Fix: Final Radio Simplification (Two Manual Players)"
git push origin main
ssh nite_dev@srv925512.hstgr.cloud "sudo nite deploy"

echo "--------------------------------------------------------"
echo "✅ API RESTORED. RADIO SIMPLIFIED."
echo "👉 Check API: https://os.peoplewelike.club/api/users/demo"
echo "👉 Check Radio: https://os.peoplewelike.club/radio"
echo "--------------------------------------------------------"
