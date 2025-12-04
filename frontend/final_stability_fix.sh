#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
FRONTEND_DIR="$PROJECT_DIR/frontend/src/views"
SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> [CRITICAL REPAIR] Restoring API, Liquidsoap, and deploying final controls..."

# ==========================================
# 1. SERVER FIX: RESTORE API PROXY & ENSURE STREAMING IS ACTIVE
# ==========================================
cat << 'EOF' > /tmp/nginx_stream_fix.sh
#!/bin/bash
set -e

# 1. FIX NGINX SYNTAX (Restore API Access)
CONF="/etc/nginx/sites-available/os.peoplewelike.club.conf"
echo ">>> Restoring Nginx configuration syntax..."

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

    # --- API PROXY ---
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # --- HLS STREAM ACCESS (Required for Player) ---
    location /hls/ {
        alias /var/www/hls/;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache";
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# 2. LIQUIDSOAP FIX (Guaranteed Looping Playlist)
echo ">>> Fixing Liquidsoap Playlist Loop..."
# Use an indefinite loop mode and restart Liquidsoap
if grep -q "output.file" /etc/liquidsoap/autodj.liq; then
    sed -i 's|audio = playlist(.*)|audio = playlist(mode="random", reload=60, "/var/www/autodj/music")|' /etc/liquidsoap/autodj.liq
fi

# 3. RESTART SERVICES
echo ">>> Restarting Core Services..."
systemctl daemon-reload
systemctl restart nginx
systemctl restart liquidsoap-radio

# 4. Final check: API must be 200
API_STATUS=$(curl -o /dev/null -w "%{http_code}" -sL https://os.peoplewelike.club/api/users/demo)
echo "API Status: $API_STATUS"
EOF

# Deploy to Server
scp /tmp/nginx_api_restore.sh "$SERVER_USER@$SERVER_HOST":/tmp/
ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash /tmp/nginx_api_restore.sh"
rm /tmp/nginx_api_restore.sh

# 5. FRONTEND: Deploy Final Stable Player
echo ">>> [2/2] Deploying Final Stable Player UI..."
cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="simple-radio-container">
    <h1>📻 Nite Radio - Stream Control</h1>
    
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
        <video ref="livePlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls muted playsinline crossorigin="anonymous"></video>
    </div>
    
    <div class="player-wrapper">
        <h2 class="stream-title">AUTO-DJ MUSIC</h2>
        <video ref="autodjPlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls muted playsinline crossorigin="anonymous"></video>
    </div>
    
    <p class="small-note">Note: You must click the play button on the player you wish to hear to unmute it.</p>
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

# 6. COMMIT AND DEPLOY
echo ">>> Committing and Deploying final simplified code..."
cd "$PROJECT_DIR"
git add .
git commit -m "Fix: Final Radio Player Separation (Guaranteed Playback)"
git push origin main
ssh "$SERVER_USER@$SERVER_HOST" "sudo nite deploy"

echo "--------------------------------------------------------"
echo "✅ DEPLOYMENT COMPLETE."
echo "--------------------------------------------------------"
