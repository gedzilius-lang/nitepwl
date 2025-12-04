<template>
  <div class="radio-embed">
    <div class="player-wrapper">
      <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered"></video>
    </div>
    
    <div class="status-overlay">
      <span v-if="isLive" class="live-badge">🔴 LIVE NOW</span>
      <span v-else class="auto-badge">🤖 AUTO DJ</span>
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
      checkInterval: null,
      sources: {
        live: 'https://os.peoplewelike.club/hls/live/obs.m3u8',
        autodj: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8'
      }
    }
  },
  mounted() {
    this.initPlayer();
    this.checkStreamStatus();
    // Check stream status every 5 seconds
    this.checkInterval = setInterval(this.checkStreamStatus, 5000);
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    if (this.checkInterval) clearInterval(this.checkInterval);
  },
  methods: {
    initPlayer() {
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: 'muted',
        preload: 'auto',
        fluid: true, // Responsive
        sources: [{ src: this.sources.autodj, type: 'application/x-mpegURL' }]
      });
    },
    async checkStreamStatus() {
      try {
        // Check if Live stream exists (HEAD request)
        const res = await fetch(this.sources.live, { method: 'HEAD' });
        const liveAvailable = res.ok;

        if (liveAvailable && !this.isLive) {
          console.log('Switching to LIVE');
          this.isLive = true;
          const currentTime = this.player.currentTime();
          this.player.src({ src: this.sources.live, type: 'application/x-mpegURL' });
          this.player.play().catch(() => {});
        } else if (!liveAvailable && this.isLive) {
          console.log('Live ended, switching to AutoDJ');
          this.isLive = false;
          this.player.src({ src: this.sources.autodj, type: 'application/x-mpegURL' });
          this.player.play().catch(() => {});
        }
      } catch (e) {
        // Ignore fetch errors (offline)
      }
    }
  }
}
</script>

<style scoped>
/* Full-screen embed style */
.radio-embed { 
  width: 100%; 
  height: 100vh; 
  margin: 0;
  padding: 0;
  background: #000; 
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.player-wrapper { 
  width: 100%; 
  height: 100%;
}

/* Force video.js to fill the container */
:deep(.video-js) {
  width: 100% !important;
  height: 100% !important;
}

/* Overlay the status badge on top left */
.status-overlay {
  position: absolute;
  top: 15px;
  left: 15px;
  z-index: 20;
  pointer-events: none; /* Allow clicks to pass through to the player */
}

.live-badge { 
  background: rgba(220, 20, 60, 0.9); 
  color: white; 
  padding: 6px 12px; 
  border-radius: 4px; 
  font-weight: bold; 
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  animation: pulse 1.5s infinite; 
  box-shadow: 0 2px 10px rgba(0,0,0,0.5);
}

.auto-badge { 
  background: rgba(30, 30, 30, 0.8); 
  color: #ccc; 
  padding: 6px 12px; 
  border-radius: 4px; 
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  box-shadow: 0 2px 10px rgba(0,0,0,0.5);
  backdrop-filter: blur(4px);
}

@keyframes pulse { 
  0% { opacity: 1; } 
  50% { opacity: 0.6; } 
  100% { opacity: 1; } 
}
</style>