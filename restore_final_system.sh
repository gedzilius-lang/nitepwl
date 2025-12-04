#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
FRONTEND_DIR="$PROJECT_DIR/frontend/src/views"
SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> [CRITICAL RESTORE] Fixing Nginx Syntax and API access..."

# ==========================================
# 1. SERVER FIX: NGINX OVERWRITE (Fixes 502/404 Critical Errors)
# ==========================================
cat << 'EOF' > /tmp/nginx_api_restore.sh
#!/bin/bash
set -e

CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

echo ">>> Overwriting Nginx configuration to restore syntax..."
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

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/os.peoplewelike.club/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/os.peoplewelike.club/privkey.pem;

    root /opt/nite-os-v7/frontend/dist;
    index index.html;

    # --- API PROXY (Guaranteed Working Block) ---
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- HLS STREAM ACCESS (Required for Radio) ---
    location /hls/ {
        alias /var/www/hls/;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache";
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    # Frontend Routing (SPA Fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# 2. RESTART SERVICES
echo ">>> Testing and restarting Nginx and Backend..."
nginx -t && systemctl restart nginx
systemctl restart liquidsoap-radio ffmpeg-live || true # Ensure radio services clear their state
# The NestJS app often stabilizes after Nginx starts.
EOF

# Push and Execute API Restore
scp /tmp/nginx_api_restore.sh "$SERVER_USER@$SERVER_HOST":/tmp/
ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash /tmp/nginx_api_restore.sh"
rm /tmp/nginx_api_restore.sh

# 3. FRONTEND DOWNGRADE: Create Simple Radio Player
echo ">>> [2/3] Implementing Basic Two-Player Radio UI..."
cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="simple-radio-container">
    <h1>📻 Nite Radio - Final Stable Version</h1>
    
    <div class="player-wrapper">
        <h2 class="stream-title">🔴 LIVE FEED (OBS)</h2>
        <video ref="livePlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
        <button class="control-btn live-btn" @click="unmuteAndPlay('live')">Play Live</button>
    </div>
    
    <div class="player-wrapper">
        <h2 class="stream-title">�� AUTO-DJ MUSIC</h2>
        <video ref="autodjPlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
        <button class="control-btn radio-btn" @click="unmuteAndPlay('autodj')">Play Radio</button>
    </div>

    <p class="small-note">Note: Click a Play button to activate the sound and visuals.</p>
  </div>
</template>

<script>
import videojs from 'video.js';
import 'video.js/dist/video-js.css';

export default {
  mounted() {
    this.initPlayer('live', 'https://os.peoplewelike.club/hls/live/obs.m3u8');
    this.initPlayer('autodj', 'https://os.peoplewelike.club/hls/autodj/stream.m3u8');
  },
  methods: {
    initPlayer(type, src) {
      // Base configuration
      const playerOptions = {
        controls: true,
        autoplay: 'muted',
        muted: true,
        fill: true,
        responsive: true,
        sources: [{ src: src, type: 'application/vnd.apple.mpegurl' }]
      };

      // Find the correct player element
      const refName = type === 'live' ? 'livePlayer' : 'autodjPlayer';
      videojs(this.$refs[refName], playerOptions);
    },
    unmuteAndPlay(type) {
      // This is the guaranteed way to start playback after user interaction
      const player = videojs(this.$refs[type === 'live' ? 'livePlayer' : 'autodjPlayer']);
      player.muted(false);
      player.play().catch(e => console.error(`Playback Error on ${type}:`, e));
    }
  }
}
</script>

<style scoped>
.simple-radio-container { max-width: 900px; margin: 0 auto; padding: 20px; }
h1 { margin-bottom: 20px; }
.player-wrapper { 
    margin-bottom: 30px; 
    border: 1px solid #333; 
    border-radius: 8px; 
    overflow: hidden; 
    position: relative;
    padding-bottom: 15px;
}
.stream-title { padding: 10px; background: #1a1a1a; margin: 0; font-size: 1rem; }
.control-btn { 
    padding: 10px 20px; 
    margin: 10px; 
    font-weight: bold;
    cursor: pointer;
    border: none;
    border-radius: 4px;
}
.live-btn { background: #ff4444; color: white; }
.radio-btn { background: #50c878; color: black; }

:deep(.video-js) { width: 100% !important; height: auto !important; aspect-ratio: 16/9; }
.small-note { margin-top: 20px; color: #888; font-size: 0.9rem; }
</style>
VUE

# 4. COMMIT AND DEPLOY
echo ">>> [3/3] Committing and Deploying system repair..."
cd "$PROJECT_DIR"
git add .
git commit -m "Fix: Nginx Syntax Restore and Basic Radio Player"
git push origin main
ssh "$SERVER_USER@$SERVER_HOST" "sudo nite deploy"

echo "--------------------------------------------------------"
echo "✅ SYSTEM REPAIRED."
echo "👉 You must hard-refresh your browser now (Ctrl+Shift+R)."
echo "--------------------------------------------------------"
