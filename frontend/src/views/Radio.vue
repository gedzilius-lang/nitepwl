<template>
  <div class="radio-page">
    <h1>📻 Nite Radio</h1>
    <div class="player-wrapper">
      <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered"></video>
    </div>
    <div class="status">
      <span v-if="isLive" class="live-badge">🔴 LIVE NOW</span>
      <span v-else class="auto-badge">🤖 AUTO DJ</span>
    </div>
    <div class="embed-info">
      <h3>Embed this player:</h3>
      <code>&lt;iframe src="https://os.peoplewelike.club/radio/embed" width="100%" height="100"&gt;&lt;/iframe&gt;</code>
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
        fluid: true,
        sources: [{ src: this.sources.autodj, type: 'application/x-mpegURL' }]
      });
    },
    async checkStreamStatus() {
      try {
        const res = await fetch(this.sources.live, { method: 'HEAD' });
        const liveAvailable = res.ok;

        if (liveAvailable && !this.isLive) {
          // Switch to Live
          console.log('Switching to LIVE');
          this.isLive = true;
          this.player.src({ src: this.sources.live, type: 'application/x-mpegURL' });
          this.player.play();
        } else if (!liveAvailable && this.isLive) {
          // Switch back to AutoDJ
          console.log('Live ended, switching to AutoDJ');
          this.isLive = false;
          this.player.src({ src: this.sources.autodj, type: 'application/x-mpegURL' });
          this.player.play();
        }
      } catch (e) {
        // Live check failed, assume offline
      }
    }
  }
}
</script>

<style scoped>
.radio-page { max-width: 800px; margin: 0 auto; text-align: center; }
.player-wrapper { margin: 20px 0; border: 1px solid #333; border-radius: 8px; overflow: hidden; }
.status { margin: 20px 0; }
.live-badge { background: red; color: white; padding: 5px 10px; border-radius: 4px; font-weight: bold; animation: pulse 1.5s infinite; }
.auto-badge { background: #333; color: #aaa; padding: 5px 10px; border-radius: 4px; }
.embed-info code { background: #111; padding: 10px; display: block; margin-top: 10px; word-break: break-all; color: #8a2be2; }
@keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.5; } 100% { opacity: 1; } }
</style>