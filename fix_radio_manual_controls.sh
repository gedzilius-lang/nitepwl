#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
FRONTEND_DIR="$PROJECT_DIR/frontend/src/views"

echo ">>> [Phase 11] Implementing Final Manual Radio Controls..."

# 1. FRONTEND: MANUAL PLAYER (Vue)
# This design features two independent buttons and the mandatory mobile start overlay.
cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="pwl-radio-body">
    <header>
        <div class="logo">peoplewelike</div>
        <div class="header-controls">
            <button 
              class="btn-base live-btn" 
              :class="{ active: currentSource === 'live', available: isLiveAvailable }" 
              @click="setSource('live')"
              :disabled="!isLiveAvailable">
              🔴 WATCH LIVE
            </button>
            
            <button 
              class="btn-base radio-btn" 
              :class="{ active: currentSource === 'autodj' }" 
              @click="setSource('autodj')">
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
        <div class="controls-right">
             <button class="icon-btn" @click="toggleVideo">{{ videoEnabled ? 'VIDEO ON' : 'AUDIO ONLY' }}</button>
             <button class="icon-btn" @click="togglePiP">🔲</button>
        </div>
    </div>

    <div class="stage">
        <div v-if="showStartOverlay" class="start-overlay" @click="startPlayback">
            <div class="play-btn">▶ START RADIO</div>
        </div>

        <div id="audio-overlay" :style="{ opacity: videoEnabled ? 0 : 1, pointerEvents: 'none' }">
            <div class="audio-visualizer">
                <div class="bar"></div><div class="bar"></div><div class="bar"></div><div class="bar"></div>
            </div>
            <div class="audio-meta-large">{{ trackTitle }}</div>
            <div class="audio-label">AUDIO ONLY</div>
        </div>

        <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered" 
               playsinline crossorigin="anonymous"></video>
    </div>
    
    <div id="toast" :class="{ show: toastVisible }">{{ toastMessage }}</div>
    <footer>&copy; 2025 peoplewelike.club</footer>
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
      videoEnabled: true,
      isLiveAvailable: false, // Tracks if OBS stream is accessible
      trackTitle: "Loading...",
      timerDisplay: "",
      toastVisible: false,
      toastMessage: "",
      intervals: [],
      currentDuration: 0,
      currentStartTime: 0,
      sources: {
        live: 'https://os.peoplewelike.club/hls/live/obs.m3u8',
        autodj: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8'
      }
    }
  },
  computed: {
    liveBtnText() {
      if (this.currentSource === 'live') return "WATCHING LIVE";
      if (this.isLiveAvailable) return "🔴 WATCH LIVE";
      return "STUDIO OFFLINE";
    }
  },
  mounted() {
    this.initPlayer();
    this.checkLiveStream(); 
    this.intervals.push(setInterval(this.checkLiveStream, 5000));
    this.intervals.push(setInterval(this.updateStats, 5000));
    this.intervals.push(setInterval(this.tickTimer, 1000));
    this.updateStats();
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    this.intervals.forEach(clearInterval);
  },
  methods: {
    initPlayer() {
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: false, // MUST be false for manual control
        preload: 'auto',
        fill: true,
        responsive: true,
        muted: true, // Muted init is required for eventual playback attempt
        html5: { vhs: { overrideNative: true } }
      });
      // Load AutoDJ as default source
      this.player.src({ src: this.sources.autodj, type: 'application/vnd.apple.mpegurl' });
      this.player.on('play', () => { this.showStartOverlay = false; });
    },

    startPlayback() {
        this.showStartOverlay = false;
        this.player.muted(false); // Unmute on user gesture
        this.player.play().catch(e => console.error("Playback failed (CORS/Video.js):", e));
    },

    setSource(type) {
        if (this.currentSource === type) return;
        this.currentSource = type;
        
        // Reset and force reload stream
        this.player.reset(); 
        this.player.src({ src: this.sources[type], type: 'application/vnd.apple.mpegurl' });
        this.player.load();
        
        // Attempt to play (unmuted if user already clicked start)
        this.player.play().catch(() => {});

        if (type === 'live') {
            this.trackTitle = "LIVE BROADCAST";
        } else {
            this.updateStats();
        }
    },

    async checkLiveStream() {
        // Only checks if the live stream file is present on the server
        try {
            const res = await fetch(this.sources.live, { method: 'HEAD' });
            this.isLiveAvailable = res.ok;
        } catch (e) {
            this.isLiveAvailable = false;
        }
    },

    async updateStats() {
        if (this.currentSource === 'live') return;
        try {
            // Fetch metadata
            const res = await fetch('https://os.peoplewelike.club/now_playing.json?t=' + Date.now());
            if (res.ok) {
                const meta = await res.json();
                this.trackTitle = meta.title ? \`\${meta.artist} - \${meta.title}\` : "NiteOS Radio";
                this.currentDuration = parseFloat(meta.duration) || 0;
                this.currentStartTime = parseFloat(meta.start) || 0;
            }
        } catch (e) {}
    },

    tickTimer() {
        if (this.currentSource === 'live' || !this.currentStartTime) { this.timerDisplay = ""; return; }
        const now = Date.now() / 1000;
        const elapsed = now - this.currentStartTime;
        const remaining = this.currentDuration - elapsed;
        if (remaining > 0) {
            const m = Math.floor(remaining / 60);
            const s = Math.floor(remaining % 60);
            this.timerDisplay = \`\${m}:\${s.toString().padStart(2, '0')}\`;
        } else { this.timerDisplay = ""; }
    },
    
    toggleVideo() {
        this.videoEnabled = !this.videoEnabled;
        const el = this.$refs.videoPlayer.querySelector('video');
        if (el) el.style.opacity = this.videoEnabled ? 1 : 0;
    },
    togglePiP() {
       const v = this.$refs.videoPlayer.querySelector('video');
       if (document.pictureInPictureElement) document.exitPictureInPicture();
       else if (v && v.requestPictureInPicture) v.requestPictureInPicture();
    },
    shareSite() {
        navigator.clipboard.writeText(window.location.href);
        this.toastMessage = "LINK COPIED";
        this.toastVisible = true;
        setTimeout(() => this.toastVisible=false, 3000);
    },
    copyTrack() {
        navigator.clipboard.writeText(this.trackTitle);
        this.toastMessage = "COPIED";
        this.toastVisible = true;
        setTimeout(() => this.toastVisible=false, 3000);
    }
  }
}
</script>

<style scoped>
/* CSS styles were omitted for brevity but align with previous responses */
.pwl-radio-body { --bg: #000; --panel: #0a0a0a; --text: #e0e0e0; --accent-primary: #50c878; --accent-live: #ff0000; --dim: #444; background: var(--bg); color: var(--text); min-height: 100vh; font-family: 'Helvetica Neue', sans-serif; }
header { display: flex; justify-content: space-between; padding: 15px 20px; border-bottom: 1px solid #111; background: #000; }
.logo { font-weight: bold; font-size: 16px; color: #fff; }
.header-controls { display: flex; gap: 8px; }
.btn-base { background: transparent; border: 1px solid #333; color: var(--dim); padding: 8px 12px; font-size: 10px; font-weight: bold; letter-spacing: 1px; text-transform: uppercase; cursor: pointer; transition: 0.2s; }
.btn-base:hover { border-color: var(--text); color: var(--text); }
.live-btn.active { background: var(--accent-live); color: white; border-color: var(--accent-live); box-shadow: 0 0 10px rgba(255,0,0,0.5); }
.live-btn.available { color: var(--accent-live); border-color: var(--accent-live); animation: pulse 1.5s infinite; }
.radio-btn.active { background: var(--accent-primary); color: #000; border-color: var(--accent-primary); }
button:disabled { opacity: 0.3; cursor: not-allowed; animation: none; }
.stage { width: 100%; height: 50vh; position: relative; border-bottom: 1px solid #111; background: #000; }
@media (min-width: 768px) { .stage { height: 65vh; } }
.start-overlay { position: absolute; width:100%; height:100%; background:rgba(0,0,0,0.8); z-index: 20; display: flex; justify-content: center; align-items: center; cursor: pointer; }
.play-btn { border: 2px solid white; padding: 15px 30px; color: white; font-weight: bold; border-radius: 50px; }
.play-btn:hover { background: white; color: black; }
#audio-overlay { position: absolute; width: 100%; height: 100%; background: #050505; z-index: 5; display: flex; flex-direction: column; justify-content: center; align-items: center; pointer-events: none; transition: opacity 0.5s; }
.audio-visualizer { display: flex; gap: 5px; height: 40px; margin-bottom: 20px; }
.bar { width: 4px; background: #444; animation: eq 1s infinite ease-in-out; }
.bar:nth-child(odd) { animation-duration: 0.8s; }
@keyframes eq { 0%, 100% { height: 10px; opacity: 0.5; } 50% { height: 30px; opacity: 1; background: var(--accent-primary); } }
@keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
.player-toolbar { background: var(--panel); padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #222; }
.now-playing { color: #fff; font-size: 12px; font-weight: 500; text-transform: uppercase; }
.time-remaining { font-family: monospace; font-size: 10px; color: var(--accent-primary); margin-left: 10px; }
.icon-btn { background: transparent; border: none; color: #888; font-size: 14px; cursor: pointer; margin-left: 10px; }
:deep(.video-js) { width: 100% !important; height: 100% !important; }
:deep(.vjs-control-bar) { background: rgba(0,0,0,0.8) !important; }
#toast { visibility: hidden; min-width: 200px; background: #222; color: #fff; padding: 12px; position: fixed; left: 50%; bottom: 30px; transform: translateX(-50%); z-index: 100; text-align: center; font-size: 11px; border-bottom: 2px solid var(--accent-primary); opacity: 0; transition: opacity 0.5s; }
footer { text-align: center; padding: 40px; color: #444; font-size: 10px; }
</style>
VUE

echo ">>> Pushing Final Player Fix..."
cd "$HOME/nitepwl"
git add .
git commit -m "Fix: Final Player Configuration with Manual Controls"
git push origin main

echo "--------------------------------------------------------"
echo "✅ FIX APPLIED."
echo "👉 Run 'nite deploy' on your VPS to go live."
echo "--------------------------------------------------------"
