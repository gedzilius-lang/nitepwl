#!/bin/bash
set -e

FRONTEND_DIR="$HOME/nitepwl/frontend/src/views"

echo ">>> [Phase 9] Porting 'Rock-Solid' Player Logic..."

cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="radio-page">
    <h1>📻 Nite Radio</h1>

    <div class="player-container">
      <canvas ref="visualizer" class="audio-visualizer" v-show="!isWatchingLive && visualsEnabled"></canvas>
      
      <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered" playsinline></video>
      
      <div v-if="!isWatchingLive" class="meta-overlay">
        <div class="equalizer-icon">ililil</div>
        <div class="track-info">
          <span class="artist">{{ currentSong.artist || 'NiteOS' }}</span>
          <span class="title">{{ currentSong.title || 'Auto-DJ' }}</span>
        </div>
      </div>
    </div>

    <div class="controls-bar">
      <div class="status-badge">
        <span v-if="isWatchingLive" class="live">🔴 WATCHING LIVE</span>
        <span v-else-if="isLiveAvailable" class="available" @click="forceLive">📡 LIVE AVAILABLE (CLICK TO WATCH)</span>
        <span v-else class="auto">🤖 AUTO DJ</span>
      </div>

      <div class="actions">
        <button @click="toggleVisuals" class="btn-icon">
          {{ visualsEnabled ? '🌊 Visuals ON' : '⬛ Visuals OFF' }}
        </button>
        <button @click="togglePiP" class="btn-icon">
          🔲 PiP
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
      isLiveAvailable: false,
      isWatchingLive: false,
      visualsEnabled: true,
      currentSong: { artist: '', title: '' },
      intervals: [],
      audioContext: null,
      analyser: null,
      dataArray: null,
      animationId: null,
      // EXACT URLs from your index.html backup
      sources: {
        live: 'https://os.peoplewelike.club/hls/live/obs.m3u8',
        autodj: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8'
      }
    }
  },
  mounted() {
    this.initPlayer();
    // Check immediately
    this.checkLiveStream();
    
    // Poll every 5 seconds (Robustness logic)
    this.intervals.push(setInterval(this.checkLiveStream, 5000));
    this.intervals.push(setInterval(this.fetchMetadata, 3000));
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    this.intervals.forEach(clearInterval);
    if (this.animationId) cancelAnimationFrame(this.animationId);
    if (this.audioContext) this.audioContext.close();
  },
  methods: {
    initPlayer() {
      // "Best Known Stable Config" from your PDF [cite: 144-147]
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: 'muted',
        preload: 'auto',
        fluid: true,
        liveui: true,
        html5: {
          vhs: { 
            overrideNative: true,
            enableLowInitialPlaylist: true
          }
        }
      });

      // Visualizer Hook
      this.player.ready(() => {
        this.player.on('play', () => {
          if (!this.audioContext && this.visualsEnabled) this.initVisualizer();
        });
        
        // Start default stream (AutoDJ) if Live isn't found immediately
        if (!this.isWatchingLive) {
          this.switchToRadio();
        }
      });
    },

    async checkLiveStream() {
      try {
        // Simple HEAD request to see if the live file exists [cite: 148-152]
        const res = await fetch(this.sources.live, { method: 'HEAD' });
        
        if (res.ok) {
          // Live is available!
          if (!this.isLiveAvailable) {
            console.log(">>> LIVE STREAM DETECTED");
            this.isLiveAvailable = true;
            // Auto-switch if we prefer live
            if (!this.isWatchingLive) this.switchToLive(); 
          }
        } else {
          // Live is gone
          if (this.isLiveAvailable) {
            console.log(">>> LIVE STREAM ENDED");
            this.isLiveAvailable = false;
            if (this.isWatchingLive) this.switchToRadio();
          }
        }
      } catch (e) {
        this.isLiveAvailable = false;
      }
    },

    forceLive() {
      this.switchToLive();
    },

    switchToLive() {
      if (this.isWatchingLive) return; // Already watching
      console.log(">>> SWITCHING TO LIVE");
      this.isWatchingLive = true;
      this.player.src({ src: this.sources.live, type: 'application/x-mpegURL' });
      this.player.play().catch(e => console.warn("Autoplay blocked:", e));
    },

    switchToRadio() {
      if (!this.isWatchingLive && this.player.src() === this.sources.autodj) return; // Already on radio
      console.log(">>> SWITCHING TO AUTODJ");
      this.isWatchingLive = false;
      this.player.src({ src: this.sources.autodj, type: 'application/x-mpegURL' });
      this.player.play().catch(e => console.warn("Autoplay blocked:", e));
    },

    // --- Visualizer & Metadata (Same as before) ---
    async fetchMetadata() {
      if (this.isWatchingLive) return;
      try {
        const res = await fetch('https://os.peoplewelike.club/now_playing.json?t=' + Date.now());
        if (res.ok) {
          const data = await res.json();
          this.currentSong = {
            artist: data.artist || 'NiteOS',
            title: data.title || 'Auto-DJ'
          };
        }
      } catch(e) {}
    },
    
    async initVisualizer() {
      // (Keeping your existing visualizer logic intact)
      try {
        const videoEl = this.$refs.videoPlayer.querySelector('video') || this.$refs.videoPlayer;
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        this.audioContext = new AudioContext();
        const source = this.audioContext.createMediaElementSource(videoEl);
        this.analyser = this.audioContext.createAnalyser();
        source.connect(this.analyser);
        this.analyser.connect(this.audioContext.destination);
        this.analyser.fftSize = 256;
        this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);
        this.drawVisualizer();
      } catch (e) { console.warn("Visualizer error:", e); }
    },
    
    drawVisualizer() {
      if (!this.visualsEnabled) return;
      const canvas = this.$refs.visualizer;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      const width = canvas.width = canvas.clientWidth;
      const height = canvas.height = canvas.clientHeight;
      this.animationId = requestAnimationFrame(this.drawVisualizer);
      this.analyser.getByteFrequencyData(this.dataArray);
      ctx.clearRect(0, 0, width, height);
      const barWidth = (width / this.dataArray.length) * 2.5;
      let x = 0;
      for(let i = 0; i < this.dataArray.length; i++) {
        let barHeight = this.dataArray[i] / 2;
        const gradient = ctx.createLinearGradient(0, height, 0, 0);
        gradient.addColorStop(0, '#8a2be2');
        gradient.addColorStop(1, '#00d2ff');
        ctx.fillStyle = gradient;
        ctx.fillRect(x, height - barHeight, barWidth, barHeight);
        x += barWidth + 1;
      }
    },

    toggleVisuals() { this.visualsEnabled = !this.visualsEnabled; if(this.visualsEnabled) this.drawVisualizer(); },
    togglePiP() {
       const v = this.$refs.videoPlayer.querySelector('video') || this.$refs.videoPlayer;
       if (document.pictureInPictureElement) document.exitPictureInPicture();
       else if (v.requestPictureInPicture) v.requestPictureInPicture();
    }
  }
}
</script>

<style scoped>
.radio-page { max-width: 900px; margin: 0 auto; text-align: center; }
.player-container { position: relative; width: 100%; background: #000; border: 1px solid #333; border-radius: 12px; overflow: hidden; }
/* Force Player Size */
:deep(.video-js) { width: 100% !important; height: auto !important; aspect-ratio: 16/9; }

/* Overlay Styles */
.audio-visualizer { position: absolute; bottom: 0; left: 0; width: 100%; height: 60%; z-index: 5; pointer-events: none; opacity: 0.8; }
.meta-overlay { position: absolute; top: 20px; right: 20px; background: rgba(0,0,0,0.8); padding: 10px 15px; border-radius: 8px; z-index: 10; display: flex; gap: 10px; border: 1px solid #444; }
.track-info { text-align: left; display: flex; flex-direction: column; }
.artist { font-size: 0.8rem; color: #ccc; }
.title { font-size: 1rem; color: #fff; font-weight: bold; }

/* Controls */
.controls-bar { display: flex; justify-content: space-between; align-items: center; background: #1a1a1a; padding: 15px; border-radius: 8px; margin-top: 15px; border: 1px solid #333; }
.status-badge span { padding: 6px 12px; border-radius: 4px; font-weight: bold; font-size: 0.9rem; }
.live { background: #ff0000; color: white; animation: pulse 2s infinite; }
.available { background: #ff4444; color: white; cursor: pointer; border: 1px solid white; }
.auto { background: #333; color: #888; }
.actions { display: flex; gap: 10px; }
.btn-icon { background: #2a2a2a; border: 1px solid #444; color: white; padding: 8px 12px; border-radius: 4px; cursor: pointer; }

@keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.6; } 100% { opacity: 1; } }
</style>
VUE

echo ">>> Pushing Fix to GitHub..."
cd "$HOME/nitepwl"
git add .
git commit -m "Fix: Apply Rock-Solid Radio Logic from PDF"
git push origin main

echo "--------------------------------------------------------"
echo "✅ Player Logic Updated."
echo "👉 1. Run 'nite deploy' on the server."
echo "👉 2. Clear Browser Cache & Test."
echo "--------------------------------------------------------"
