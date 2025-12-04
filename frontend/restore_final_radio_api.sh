#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
FRONTEND_DIR="$PROJECT_DIR/frontend/src/views"
SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> [CRITICAL REPAIR] Restoring API and deploying FINAL stable Radio."

# ==========================================
# 1. SERVER FIX: NGINX RESTORE (Guarantees API access)
# ==========================================
cat << 'EOF' > /tmp/nginx_api_restore.sh
#!/bin/bash
set -e

CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"

echo ">>> Overwriting Nginx site config for stable API access..."
cat << 'NGINX' > "$CONF"
server {
    listen 80;
    server_name os.peoplewelike.club;
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

    # Frontend Routing (SPA Fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

echo ">>> Testing and restarting Nginx..."
nginx -t && systemctl restart nginx
echo ">>> API access should now be restored."
EOF

# Push and Execute API Restore
scp /tmp/nginx_api_restore.sh "$SERVER_USER@$SERVER_HOST":/tmp/
ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash /tmp/nginx_api_restore.sh"
rm /tmp/nginx_api_restore.sh

# 2. FRONTEND DOWNGRADE: Deploy the Final Two-Player Design
echo ">>> [2/2] Deploying Final Stable Player UI..."
cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="simple-radio-container">
    <h1>📻 Nite Radio - Final Stable Stream</h1>
    
    <div class="controls-bar">
        <button class="control-btn live-btn" @click="setSource('live')">
            🔴 WATCH LIVE
        </button>
        <button class="control-btn radio-btn" @click="setSource('autodj')">
            🤖 LISTEN RADIO
        </button>
    </div>

    <div class="player-wrapper">
        <h2 class="stream-title">LIVE FEED (OBS)</h2>
        <video ref="livePlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
    </div>
    
    <div class="player-wrapper">
        <h2 class="stream-title">AUTO-DJ MUSIC</h2>
        <video ref="autodjPlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls muted playsinline crossorigin="anonymous"></video>
    </div>
    
    <p class="small-note">Note: Click the corresponding play button to activate the stream.</p>
  </div>
</template>

<script>
import videojs from 'video.js';
import 'video.js/dist/video-js.css';

export default {
  data() {
    return {
      livePlayer: null,
      autodjPlayer: null,
      currentSource: 'live',
      sources: {
        live: 'https://os.peoplewelike.club/hls/live/obs.m3u8',
        autodj: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8'
      }
    }
  },
  mounted() {
    // Initialize both players
    this.livePlayer = this.initPlayer(this.$refs.livePlayer, this.sources.live);
    this.autodjPlayer = this.initPlayer(this.$refs.autodjPlayer, this.sources.autodj);
    // Set default source to Live to avoid AutoDJ loading issues first
    this.setSource('live');
  },
  beforeUnmount() {
    if (this.livePlayer) this.livePlayer.dispose();
    if (this.autodjPlayer) this.autodjPlayer.dispose();
  },
  methods: {
    initPlayer(el, src) {
      const player = videojs(el, {
        controls: true,
        autoplay: 'muted',
        muted: true,
        fill: true,
        responsive: true,
        sources: [{ src: src, type: 'application/vnd.apple.mpegurl' }]
      });
      return player;
    },
    setSource(type) {
      if (type === 'live') {
        this.livePlayer.muted(false);
        this.livePlayer.play();
        this.autodjPlayer.pause();
        this.autodjPlayer.muted(true);
      } else {
        this.autodjPlayer.muted(false);
        this.autodjPlayer.play();
        this.livePlayer.pause();
        this.livePlayer.muted(true);
      }
      this.currentSource = type;
    }
  }
}
</script>

<style scoped>
.simple-radio-container { max-width: 900px; margin: 0 auto; padding: 20px; }
h1 { margin-bottom: 20px; }
.player-wrapper { margin-bottom: 30px; border: 1px solid #333; border-radius: 8px; overflow: hidden; position: relative; }
.stream-title { padding: 10px; background: #1a1a1a; margin: 0; font-size: 1rem; }
.controls-bar { margin-bottom: 20px; display: flex; justify-content: space-around; }
.control-btn { padding: 10px 20px; margin: 10px; font-weight: bold; cursor: pointer; border: none; border-radius: 4px; }
.live-btn { background: red; color: white; }
.radio-btn { background: #50c878; color: black; }
:deep(.video-js) { width: 100% !important; height: auto !important; aspect-ratio: 16/9; }
.small-note { margin-top: 20px; color: #888; font-size: 0.9rem; }
</style>
VUE

# 3. COMMIT AND DEPLOY
echo ">>> Committing and Deploying system repair..."
cd "$PROJECT_DIR"
git add .
git commit -m "Fix: Final Stable Radio Player Deployment"
git push origin main
ssh "$SERVER_USER@$SERVER_HOST" "sudo nite deploy"

echo "--------------------------------------------------------"
echo "✅ DEPLOYMENT COMPLETE."
echo "--------------------------------------------------------"
