#!/bin/bash
set -e

echo ">>> [Radio] Applying 'Rock-Solid' Playback Fix..."

# ==========================================
# 1. SERVER FIX: FORCE CORS & MIME TYPES
# ==========================================
cat << 'EOF' > /tmp/nginx_cors_fix.sh
#!/bin/bash
set -e

# Overwrite the site config to guarantee CORS headers are present
cat << 'NGINX' > /etc/nginx/sites-available/os.peoplewelike.club.conf
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

    # --- FIXED HLS ROUTES (WITH CORS) ---
    location /hls/ {
        alias /var/www/hls/;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Expose-Headers Content-Length;
        
        # Force MIME types for HLS
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
    }

    # API Proxy
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }

    # Metadata
    location /now_playing.json {
        alias /var/www/html/now_playing.json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-cache, no-store";
        default_type application/json;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# Restart Nginx to apply
nginx -t && systemctl restart nginx
echo ">>> Nginx CORS Headers Enforced."
EOF

scp /tmp/nginx_cors_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/nginx_cors_fix.sh"
rm /tmp/nginx_cors_fix.sh

# ==========================================
# 2. FRONTEND FIX: ROBUST PLAYER LOGIC
# ==========================================
FRONTEND_DIR="$HOME/nitepwl/frontend/src/views"

cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="pwl-radio-body">
    <header>
        <div class="logo">peoplewelike</div>
        <div class="header-controls">
            <button class="btn-base live-btn" :class="{ active: currentSource === 'live' }" @click="setSource('live')">
              🔴 WATCH LIVE
            </button>
            <button class="btn-base radio-btn" :class="{ active: currentSource === 'autodj' }" @click="setSource('autodj')">
              🤖 LISTEN RADIO
            </button>
            <button class="btn-base" @click="shareSite">SHARE</button>
        </div>
    </header>

    <div class="player-toolbar">
        <div class="meta-info" @click="copyTrack">
            <span class="meta-label">Now Playing</span>
            <div class="meta-content">
                <span class="now-playing">{{ trackTitle }}</span>
                <span v-if="timerDisplay && currentSource === 'autodj'" class="time-remaining">{{ timerDisplay }}</span>
            </div>
        </div>
        <div class="mini-controls">
            <button class="icon-btn" @click="toggleVisuals">{{ visualsEnabled ? '🌊' : '⬛' }}</button>
            <button class="icon-btn" @click="togglePiP">🔲</button>
        </div>
    </div>

    <div class="stage">
        <div v-if="showStartOverlay" class="start-overlay" @click="startPlayback">
            <div class="play-btn">▶ CLICK TO START</div>
        </div>

        <div id="audio-overlay" v-show="currentSource === 'autodj' && visualsEnabled">
            <canvas ref="visualizer" class="audio-visualizer"></canvas>
            <div class="audio-meta-large">{{ trackTitle }}</div>
            <div class="audio-label">AUDIO ONLY</div>
        </div>

        <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered" 
               crossorigin="anonymous" playsinline></video>
    </div>
  </div>
</template>

<script>
import videojs from 'video.js';
import 'video.js/dist/video-js.css';

export default {
  data() {
    return {
      player: null,
      currentSource: 'autodj',
      showStartOverlay: true,
      visualsEnabled: true,
      trackTitle: "Loading...",
      timerDisplay: "",
      audioContext: null,
      analyser: null,
      dataArray: null,
      animationId: null,
      intervals: [],
      currentDuration: 0,
      currentStartTime: 0,
      sources: {
        live: 'https://os.peoplewelike.club/hls/live/obs.m3u8',
        autodj: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8'
      }
    }
  },
  mounted() {
    this.initPlayer();
    this.intervals.push(setInterval(this.updateStats, 5000));
    this.intervals.push(setInterval(this.tickTimer, 1000));
    this.updateStats();
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    this.intervals.forEach(clearInterval);
    if (this.animationId) cancelAnimationFrame(this.animationId);
    if (this.audioContext) this.audioContext.close();
  },
  methods: {
    initPlayer() {
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: false, // Manual start
        preload: 'auto',
        fill: true,
        responsive: true,
        muted: true, // Muted init helps avoid autoplay blocks
        html5: { vhs: { overrideNative: true } }
      });

      // Hook for visualizer
      this.player.on('play', () => {
        this.showStartOverlay = false;
        if (this.currentSource === 'autodj' && this.visualsEnabled && !this.audioContext) {
            this.initVisualizer();
        }
      });
      
      // Pre-load AutoDJ source
      this.player.src({ src: this.sources.autodj, type: 'application/vnd.apple.mpegurl' });
    },

    startPlayback() {
        this.showStartOverlay = false;
        this.player.muted(false); // Unmute on user click
        this.player.play().catch(e => console.warn("Play blocked:", e));
    },

    setSource(type) {
        this.currentSource = type;
        // Reset player to ensure clean switch
        this.player.reset();
        
        // Re-apply options lost on reset
        this.player.src({ src: this.sources[type], type: 'application/vnd.apple.mpegurl' });
        this.player.load();
        this.player.play().catch(() => {});

        if (type === 'live') {
            this.trackTitle = "Live Broadcast";
        } else {
            this.updateStats();
        }
    },

    async updateStats() {
        if (this.currentSource === 'live') return;
        try {
            const res = await fetch('https://os.peoplewelike.club/now_playing.json?t=' + Date.now());
            if (res.ok) {
                const meta = await res.json();
                this.trackTitle = meta.title ? `${meta.artist} - ${meta.title}` : "NiteOS Radio";
                this.currentDuration = parseFloat(meta.duration) || 0;
                this.currentStartTime = parseFloat(meta.start) || 0;
            }
        } catch (e) {}
    },

    tickTimer() {
        if (this.currentSource === 'live' || !this.currentStartTime) {
            this.timerDisplay = ""; return;
        }
        const now = Date.now() / 1000;
        const elapsed = now - this.currentStartTime;
        const remaining = this.currentDuration - elapsed;
        if (remaining > 0) {
            const m = Math.floor(remaining / 60);
            const s = Math.floor(remaining % 60);
            this.timerDisplay = `${m}:${s.toString().padStart(2, '0')}`;
        } else {
            this.timerDisplay = "";
        }
    },

    // Visualizer Logic (Same as before)
    async initVisualizer() {
        try {
            const videoEl = this.$refs.videoPlayer.querySelector('video') || this.$refs.videoPlayer;
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            this.audioContext = new AudioContext();
            const source = this.audioContext.createMediaElementSource(videoEl);
            this.analyser = this.audioContext.createAnalyser();
            source.connect(this.analyser);
            this.analyser.connect(this.audioContext.destination);
            this.analyser.fftSize = 128;
            this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);
            this.drawVisualizer();
        } catch (e) { console.warn("Visualizer Error:", e); }
    },
    drawVisualizer() {
        if (!this.visualsEnabled || this.currentSource === 'live') return;
        const canvas = this.$refs.visualizer;
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
        this.animationId = requestAnimationFrame(this.drawVisualizer);
        this.analyser.getByteFrequencyData(this.dataArray);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const barWidth = (canvas.width / this.dataArray.length) * 2.5;
        let x = 0;
        for(let i = 0; i < this.dataArray.length; i++) {
            const barHeight = (this.dataArray[i] / 255) * canvas.height;
            ctx.fillStyle = `rgba(80, 200, 120, ${this.dataArray[i]/255})`; 
            ctx.fillRect(x, canvas.height - barHeight, barWidth, barHeight);
            x += barWidth + 2;
        }
    },
    toggleVisuals() { this.visualsEnabled = !this.visualsEnabled; if(this.visualsEnabled) this.drawVisualizer(); },
    togglePiP() { const v = this.$refs.videoPlayer.querySelector('video') || this.$refs.videoPlayer; if(document.pictureInPictureElement) document.exitPictureInPicture(); else if(v.requestPictureInPicture) v.requestPictureInPicture(); },
    shareSite() { if(navigator.share) navigator.share({url: window.location.href}); else { navigator.clipboard.writeText(window.location.href); this.toastMessage="COPIED"; this.toastVisible=true; setTimeout(()=>this.toastVisible=false, 3000); } },
    copyTrack() { navigator.clipboard.writeText(this.trackTitle); this.toastMessage="COPIED"; this.toastVisible=true; setTimeout(()=>this.toastVisible=false, 3000); }
  }
}
</script>

<style scoped>
.pwl-radio-body {
    --bg: #000000; --panel: #0a0a0a; --text: #e0e0e0; 
    --accent-primary: #50c878; --accent-secondary: #9b59b6; --accent-live: #ff0000; --dim: #444;
    background-color: var(--bg); color: var(--text); 
    font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    min-height: 100vh;
}
header { display: flex; justify-content: space-between; align-items: center; padding: 15px 20px; border-bottom: 1px solid #111; background: #000; }
.logo { font-weight: bold; font-size: 16px; color: #fff; }
.header-controls { display: flex; gap: 8px; }
.btn-base { background: transparent; border: 1px solid #333; color: var(--dim); padding: 8px 12px; font-size: 10px; font-weight: bold; cursor: pointer; transition: 0.3s; }
.btn-base:hover { border-color: var(--text); color: var(--text); }
.live-btn.active { background: var(--accent-live); color: white; border-color: var(--accent-live); box-shadow: 0 0 10px rgba(255,0,0,0.5); }
.radio-btn.active { background: var(--accent-primary); color: #000; border-color: var(--accent-primary); }

.stage { width: 100%; height: 50vh; background: #000; position: relative; border-bottom: 1px solid #111; }
@media (min-width: 768px) { .stage { height: 65vh; } }
.start-overlay { position: absolute; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.7); z-index: 20; display: flex; justify-content: center; align-items: center; cursor: pointer; }
.play-btn { border: 2px solid white; padding: 20px 40px; color: white; font-weight: bold; border-radius: 50px; transition: transform 0.2s; }
.play-btn:hover { transform: scale(1.1); background: white; color: black; }

#audio-overlay { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: #050505; z-index: 5; display: flex; flex-direction: column; justify-content: center; align-items: center; pointer-events: none; }
.audio-visualizer { width: 100%; height: 100%; position: absolute; opacity: 0.6; }
.audio-meta-large { font-size: 14px; color: #fff; z-index: 6; }
.audio-label { font-size: 10px; color: var(--dim); margin-top: 10px; z-index: 6; }

.player-toolbar { background: var(--panel); border-bottom: 1px solid #111; padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; }
.now-playing { color: var(--text); font-size: 12px; font-weight: 500; text-transform: uppercase; }
.time-remaining { font-family: monospace; font-size: 10px; color: var(--accent-primary); margin-left: 10px; }
.icon-btn { background: transparent; border: none; color: #888; font-size: 16px; cursor: pointer; }

:deep(.video-js) { width: 100% !important; height: 100% !important; }
:deep(.vjs-control-bar) { background: rgba(0,0,0,0.7) !important; }

#toast { visibility: hidden; min-width: 200px; background-color: #222; color: #fff; text-align: center; border-radius: 4px; padding: 12px; position: fixed; z-index: 1000; left: 50%; bottom: 30px; transform: translateX(-50%); border-bottom: 2px solid var(--accent-primary); opacity: 0; transition: opacity 0.5s; }
#toast.show { visibility: visible; opacity: 1; bottom: 50px; }
footer { text-align: center; padding: 40px 20px; color: var(--dim); font-size: 10px; }
</style>
VUE

echo ">>> [Git] Pushing Fix..."
cd "$HOME/nitepwl"
git add .
git commit -m "Fix: Enable CORS for HLS and Robust Player Logic"
git push origin main

echo "--------------------------------------------------------"
echo "✅ FIX APPLIED."
echo "👉 Run 'nite deploy' now."
echo "--------------------------------------------------------"
