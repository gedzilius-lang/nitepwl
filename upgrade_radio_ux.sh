#!/bin/bash
set -e

echo ">>> [Phase 8] Upgrading Radio UI/UX..."

# ==========================================
# 1. BACKEND: Metadata Exporter
# ==========================================
# We update Liquidsoap to write current song info to a JSON file
cat << 'EOF' > /tmp/radio_metadata_fix.sh
#!/bin/bash
set -e

# 1. Create status file and set permissions
touch /var/www/html/radio_status.json
chown liquidsoap:www-data /var/www/html/radio_status.json
chmod 664 /var/www/html/radio_status.json

# 2. Update Liquidsoap Config
cat << 'LIQ' > /etc/liquidsoap/autodj.liq
#!/usr/bin/liquidsoap
set("log.stdout", false)
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

# Music Source
audio = playlist("/var/www/autodj/music")
audio = mksafe(audio)

# Metadata Handler (Writes JSON to webroot)
def on_metadata(m) =
  # Extract tags, default to "Unknown" if missing
  artist = m["artist"]
  title = m["title"]
  
  # Handle missing tags gracefully
  json = '{"artist": "#{artist}", "title": "#{title}"}'
  
  # Write to file
  system("echo '#{json}' > /var/www/html/radio_status.json")
end

audio = on_metadata(on_metadata, audio)

# Output Pipe
output.file(
  %wav, 
  "/dev/stdout", 
  audio
)
LIQ

# 3. Restart Service
chmod +x /etc/liquidsoap/autodj.liq
systemctl restart liquidsoap-radio

echo ">>> Backend Metadata System Updated."
EOF

# Deploy Backend Changes
scp /tmp/radio_metadata_fix.sh nite_dev@srv925512.hstgr.cloud:/tmp/
ssh -t nite_dev@srv925512.hstgr.cloud "sudo bash /tmp/radio_metadata_fix.sh"
rm /tmp/radio_metadata_fix.sh

# ==========================================
# 2. FRONTEND: Visualizer & Controls
# ==========================================

FRONTEND_DIR="$HOME/nitepwl/frontend/src/views"

cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="radio-page">
    <h1>📻 Nite Radio</h1>

    <div class="player-container">
      <canvas ref="visualizer" class="audio-visualizer" v-show="!isLive && visualsEnabled"></canvas>
      
      <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered" crossorigin="anonymous"></video>
      
      <div v-if="!isLive && currentSong.title" class="meta-overlay">
        <div class="equalizer-icon">ililil</div>
        <div class="track-info">
          <span class="artist">{{ currentSong.artist || 'NiteOS' }}</span>
          <span class="title">{{ currentSong.title || 'Auto-DJ' }}</span>
        </div>
      </div>
    </div>

    <div class="controls-bar">
      <div class="status-badge">
        <span v-if="isLive" class="live">🔴 LIVE</span>
        <span v-else class="auto">🤖 AUTO DJ</span>
      </div>

      <div class="actions">
        <button @click="toggleVisuals" class="btn-icon" title="Toggle Visuals">
          {{ visualsEnabled ? '🌊 Visuals ON' : '⬛ Visuals OFF' }}
        </button>
        <button @click="togglePiP" class="btn-icon" title="Picture in Picture">
          🔲 PiP
        </button>
      </div>
    </div>

    <div class="embed-info">
      <h3>Embed:</h3>
      <code>&lt;iframe src="https://os.peoplewelike.club/radio/embed" width="100%" height="300"&gt;&lt;/iframe&gt;</code>
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
      isLive: false,
      visualsEnabled: true,
      currentSong: { artist: '', title: '' },
      checkInterval: null,
      metaInterval: null,
      audioContext: null,
      analyser: null,
      dataArray: null,
      animationId: null,
      sources: {
        live: 'https://os.peoplewelike.club/hls/live/obs.m3u8',
        autodj: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8'
      }
    }
  },
  mounted() {
    this.initPlayer();
    this.checkStreamStatus();
    this.checkInterval = setInterval(this.checkStreamStatus, 5000);
    this.metaInterval = setInterval(this.fetchMetadata, 3000);
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    if (this.checkInterval) clearInterval(this.checkInterval);
    if (this.metaInterval) clearInterval(this.metaInterval);
    if (this.animationId) cancelAnimationFrame(this.animationId);
    if (this.audioContext) this.audioContext.close();
  },
  methods: {
    initPlayer() {
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: 'muted',
        preload: 'auto',
        fluid: true,
        html5: {
          vhs: { overrideNative: true },
          nativeAudioTracks: false,
          nativeVideoTracks: false
        }
      });

      this.player.ready(() => {
        // Hook up Visualizer only after user interaction (Browser Policy)
        this.player.on('play', () => {
          if (!this.audioContext && this.visualsEnabled) {
            this.initVisualizer();
          }
        });
      });
    },
    async initVisualizer() {
      try {
        const videoEl = this.$refs.videoPlayer.querySelector('video') || this.$refs.videoPlayer;
        
        // Create Audio Context
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        this.audioContext = new AudioContext();
        
        // Create Source & Analyser
        const source = this.audioContext.createMediaElementSource(videoEl);
        this.analyser = this.audioContext.createAnalyser();
        
        // Connect: Source -> Analyser -> Speakers
        source.connect(this.analyser);
        this.analyser.connect(this.audioContext.destination);
        
        // Config Analyser
        this.analyser.fftSize = 256;
        const bufferLength = this.analyser.frequencyBinCount;
        this.dataArray = new Uint8Array(bufferLength);
        
        this.drawVisualizer();
      } catch (e) {
        console.warn("Visualizer init failed (CORS or Autoplay policy):", e);
      }
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
      let barHeight;
      let x = 0;
      
      for(let i = 0; i < this.dataArray.length; i++) {
        barHeight = this.dataArray[i] / 2; // Scale down
        
        // Gradient Color
        const gradient = ctx.createLinearGradient(0, height, 0, 0);
        gradient.addColorStop(0, '#8a2be2');
        gradient.addColorStop(1, '#00d2ff');
        
        ctx.fillStyle = gradient;
        ctx.fillRect(x, height - barHeight, barWidth, barHeight);
        
        x += barWidth + 1;
      }
    },
    async fetchMetadata() {
      if (this.isLive) return; // Don't fetch metadata for live video
      try {
        const res = await fetch('https://os.peoplewelike.club/radio_status.json?t=' + Date.now());
        if (res.ok) {
          const data = await res.json();
          // Clean up potential empty fields
          this.currentSong = {
            artist: data.artist && data.artist !== 'Unknown' ? data.artist : '',
            title: data.title || 'Playing...'
          };
        }
      } catch(e) {}
    },
    toggleVisuals() {
      this.visualsEnabled = !this.visualsEnabled;
      if (this.visualsEnabled && !this.animationId) this.drawVisualizer();
      else if (!this.visualsEnabled && this.animationId) cancelAnimationFrame(this.animationId);
    },
    togglePiP() {
      const videoEl = this.$refs.videoPlayer.querySelector('video');
      if (document.pictureInPictureElement) {
        document.exitPictureInPicture();
      } else if (videoEl.requestPictureInPicture) {
        videoEl.requestPictureInPicture();
      }
    },
    async checkStreamStatus() {
      // (Existing Logic preserved...)
      try {
        const res = await fetch(this.sources.live, { method: 'HEAD' });
        const liveAvailable = res.ok;

        if (liveAvailable && !this.isLive) {
          this.isLive = true;
          this.player.src({ src: this.sources.live, type: 'application/x-mpegURL' });
          this.player.play().catch(()=>{});
        } else if (!liveAvailable && this.isLive) {
          this.isLive = false;
          this.player.src({ src: this.sources.autodj, type: 'application/x-mpegURL' });
          this.player.play().catch(()=>{});
        }
      } catch (e) {}
    }
  }
}
</script>

<style scoped>
.radio-page { max-width: 900px; margin: 0 auto; text-align: center; padding-bottom: 50px; }
.player-container { position: relative; width: 100%; height: 0; padding-bottom: 56.25%; border: 1px solid #333; border-radius: 12px; overflow: hidden; background: #000; }

/* Visualizer Overlay */
.audio-visualizer {
  position: absolute;
  bottom: 0;
  left: 0;
  width: 100%;
  height: 50%; /* Takes up bottom half */
  z-index: 5;
  pointer-events: none;
  opacity: 0.8;
}

/* Metadata Overlay */
.meta-overlay {
  position: absolute;
  top: 20px;
  right: 20px;
  background: rgba(0,0,0,0.7);
  backdrop-filter: blur(5px);
  padding: 10px 15px;
  border-radius: 8px;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid rgba(255,255,255,0.1);
  animation: slideIn 0.5s ease-out;
}

.track-info { text-align: left; display: flex; flex-direction: column; }
.artist { font-size: 0.8rem; color: #ccc; text-transform: uppercase; }
.title { font-size: 1rem; color: #fff; font-weight: bold; }
.equalizer-icon { color: #8a2be2; font-family: monospace; letter-spacing: -2px; animation: pulse 1s infinite; }

/* Controls Bar */
.controls-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #1a1a1a;
  padding: 15px;
  border-radius: 8px;
  margin-top: 15px;
  border: 1px solid #333;
}

.status-badge span { padding: 6px 12px; border-radius: 4px; font-weight: bold; }
.live { background: red; color: white; animation: pulse 2s infinite; }
.auto { background: #333; color: #888; }

.actions { display: flex; gap: 10px; }
.btn-icon { background: #2a2a2a; border: 1px solid #444; color: white; padding: 8px 12px; border-radius: 4px; cursor: pointer; transition: background 0.2s; }
.btn-icon:hover { background: #444; }

@keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
@keyframes slideIn { from { transform: translateY(-20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }

/* Force video.js to fill container */
:deep(.video-js) { position: absolute; top: 0; left: 0; width: 100% !important; height: 100% !important; }
</style>
VUE

echo ">>> Frontend Updated. Pushing to Production..."
cd "$HOME/nitepwl"
git add .
git commit -m "Feat: Radio Visualizer, Metadata, and PIP"
git push origin main

echo "--------------------------------------------------------"
echo "✅ UPGRADE COMPLETE."
echo "👉 1. Run 'nite deploy' to update the server."
echo "👉 2. Refresh browser."
echo "--------------------------------------------------------"
