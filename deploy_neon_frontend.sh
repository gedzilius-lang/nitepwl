#!/bin/bash
set -e

FRONTEND_DIR="$HOME/nitepwl/frontend/src/views"

echo ">>> [Phase 8] Installing Neon Frontend..."

cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="neon-radio">
    <div class="stage">
      <video ref="videoPlayer" id="plw-player" class="video-js vjs-default-skin vjs-big-play-centered"></video>
      
      <div id="audio-overlay" :class="{ active: !videoEnabled }">
        <div class="audio-visualizer">
          <div class="bar"></div><div class="bar"></div><div class="bar"></div><div class="bar"></div>
        </div>
        <div class="audio-meta-large">{{ trackTitle }}</div>
        <div class="audio-label">AUDIO ONLY</div>
      </div>
    </div>

    <div class="player-toolbar">
      <div class="meta-info">
        <span class="meta-label">Now Playing</span>
        <div class="meta-content">
          <span class="now-playing">{{ trackTitle }}</span>
          <span v-if="timerDisplay" class="time-remaining">{{ timerDisplay }}</span>
        </div>
      </div>
      
      <div class="controls">
        <button :class="['live-btn', { available: isLiveAvailable, watching: isWatchingLive }]" @click="handleLiveClick">
          {{ liveBtnText }}
        </button>
        <button class="btn-base" @click="toggleVideo">
          {{ videoEnabled ? 'VIDEO ON' : 'AUDIO ONLY' }}
        </button>
      </div>
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
      videoEnabled: true,
      isLiveAvailable: false,
      isWatchingLive: false,
      trackTitle: "Loading...",
      timerDisplay: "",
      checkInterval: null,
      metaInterval: null,
      timerInterval: null,
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
      if (this.isWatchingLive) return "WATCHING LIVE";
      return "STUDIO ON-AIR";
    }
  },
  mounted() {
    this.initPlayer();
    this.checkInterval = setInterval(this.checkLiveStream, 5000);
    this.metaInterval = setInterval(this.updateStats, 5000);
    this.timerInterval = setInterval(this.tickTimer, 1000);
    this.checkLiveStream();
    this.updateStats();
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    clearInterval(this.checkInterval);
    clearInterval(this.metaInterval);
    clearInterval(this.timerInterval);
  },
  methods: {
    initPlayer() {
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: 'muted',
        preload: 'auto',
        fluid: true,
        responsive: true,
        html5: { vhs: { overrideNative: true } }
      });
      // Start with AutoDJ
      this.player.src({ src: this.sources.autodj, type: 'application/vnd.apple.mpegurl' });
    },
    async checkLiveStream() {
      try {
        const res = await fetch(this.sources.live, { method: 'HEAD' });
        if (res.ok) {
          if (!this.isLiveAvailable) this.isLiveAvailable = true;
        } else {
          if (this.isLiveAvailable) this.isLiveAvailable = false;
          if (this.isWatchingLive) this.switchToRadio();
        }
      } catch (e) {
        this.isLiveAvailable = false;
      }
    },
    handleLiveClick() {
      if (!this.isLiveAvailable) return;
      if (this.isWatchingLive) this.switchToRadio();
      else this.switchToLive();
    },
    switchToLive() {
      this.player.src({ src: this.sources.live, type: "application/vnd.apple.mpegurl" });
      this.player.play().catch(()=>{});
      this.isWatchingLive = true;
      this.trackTitle = "Live Broadcasting In Progress...";
      this.timerDisplay = "";
    },
    switchToRadio() {
      this.player.src({ src: this.sources.autodj, type: "application/vnd.apple.mpegurl" });
      this.player.play().catch(()=>{});
      this.isWatchingLive = false;
      this.updateStats();
    },
    async updateStats() {
      if (this.isWatchingLive) return;
      try {
        const res = await fetch('https://os.peoplewelike.club/now_playing.json?t=' + Date.now());
        if (res.ok) {
          const meta = await res.json();
          this.trackTitle = meta.title ? `${meta.artist} - ${meta.title}` : "PEOPLE WE LIKE RADIO";
          this.currentDuration = parseFloat(meta.duration) || 0;
          this.currentStartTime = parseFloat(meta.start) || 0;
        }
      } catch (e) {}
    },
    tickTimer() {
      if (this.isWatchingLive || !this.currentStartTime) {
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
    toggleVideo() {
      this.videoEnabled = !this.videoEnabled;
      const videoEl = this.$el.querySelector('.video-js');
      if (this.videoEnabled) {
        videoEl.style.opacity = "1"; videoEl.style.zIndex = "1";
      } else {
        videoEl.style.opacity = "0"; videoEl.style.zIndex = "0";
      }
    }
  }
}
</script>

<style scoped>
.neon-radio { background: #000; color: #e0e0e0; font-family: 'Helvetica Neue', sans-serif; }
.stage { width: 100%; position: relative; border-bottom: 1px solid #111; aspect-ratio: 16/9; background: #000; }

/* Player Overrides */
:deep(.video-js) { width: 100% !important; height: 100% !important; }
:deep(.vjs-control-bar) { background: rgba(0,0,0,0.7) !important; }

/* Audio Overlay */
#audio-overlay { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: #050505; z-index: 0; display: flex; flex-direction: column; justify-content: center; align-items: center; opacity: 0; transition: opacity 0.5s; pointer-events: none; }
#audio-overlay.active { opacity: 1; pointer-events: auto; z-index: 2; }

.audio-visualizer { display: flex; gap: 5px; height: 40px; margin-bottom: 20px; }
.bar { width: 6px; background: #444; animation: eq 1s infinite ease-in-out; }
.bar:nth-child(odd) { animation-duration: 0.8s; }
@keyframes eq { 0%, 100% { height: 10px; opacity: 0.5; } 50% { height: 40px; opacity: 1; background: #50c878; } }

.audio-meta-large { font-size: 16px; color: #fff; text-transform: uppercase; letter-spacing: 1px; font-weight: bold; }
.audio-label { font-size: 10px; color: #555; letter-spacing: 2px; margin-top: 10px; }

/* Toolbar */
.player-toolbar { background: #0a0a0a; padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #222; }
.meta-label { font-size: 9px; color: #666; text-transform: uppercase; letter-spacing: 1px; font-weight: bold; display: block; }
.now-playing { color: #fff; font-size: 14px; font-weight: 500; letter-spacing: 0.5px; text-transform: uppercase; }
.time-remaining { font-family: monospace; font-size: 11px; color: #50c878; background: rgba(80, 200, 120, 0.1); padding: 2px 5px; border-radius: 2px; margin-left: 10px; }

/* Buttons */
.controls { display: flex; gap: 10px; }
.btn-base { background: transparent; border: 1px solid #333; color: #888; padding: 8px 12px; font-size: 10px; font-weight: bold; cursor: pointer; transition: 0.3s; }
.btn-base:hover { border-color: #fff; color: #fff; }

.live-btn { opacity: 0.3; pointer-events: none; border: 1px solid #222; background: transparent; color: #555; padding: 8px 12px; font-size: 10px; font-weight: bold; }
.live-btn.available { opacity: 1; pointer-events: auto; color: #ff0000; border-color: #ff0000; animation: pulse-red 1.5s infinite; }
.live-btn.watching { opacity: 1; color: #fff; background: #ff0000; animation: none; }

@keyframes pulse-red { 0% { box-shadow: 0 0 0 0 rgba(255, 0, 0, 0.4); } 70% { box-shadow: 0 0 0 6px rgba(255, 0, 0, 0); } 100% { box-shadow: 0 0 0 0 rgba(255, 0, 0, 0); } }
</style>
VUE

echo ">>> Frontend Upgraded. Deploying..."
cd "$HOME/nitepwl"
git add .
git commit -m "Feat: Implement Neon Radio Design"
git push origin main
nite deploy

echo "--------------------------------------------------------"
echo "✅ MISSION COMPLETE."
echo "👉 Check: https://os.peoplewelike.club/radio"
echo "--------------------------------------------------------"
