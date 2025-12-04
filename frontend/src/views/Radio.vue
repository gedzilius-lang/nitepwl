<template>
  <div class="simple-radio-container">
    <h1>📻 Nite Radio - Basic Stream</h1>
    <p>Status: Click play below. Live status is shown by the video stream.</p>

    <div class="player-wrapper">
        <h2 class="stream-title">🔴 LIVE FEED</h2>
        <video ref="livePlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
    </div>
    
    <div class="player-wrapper">
        <h2 class="stream-title">🎧 AUTO-DJ MUSIC</h2>
        <video ref="autodjPlayer" class="video-js vjs-default-skin vjs-big-play-centered" controls autoplay muted playsinline crossorigin="anonymous"></video>
    </div>

    <p class="small-note">Note: For simultaneous playback, browsers often prefer only one player active.</p>
  </div>
</template>

<script>
import videojs from 'video.js';
import 'video.js/dist/video-js.css';

export default {
  mounted() {
    this.initLivePlayer();
    this.initAutodjPlayer();
  },
  methods: {
    initLivePlayer() {
      // Live Stream (OBS)
      videojs(this.$refs.livePlayer, {
        controls: true,
        autoplay: 'muted',
        sources: [{ src: 'https://os.peoplewelike.club/hls/live/obs.m3u8', type: 'application/vnd.apple.mpegurl' }]
      });
    },
    initAutodjPlayer() {
      // Auto-DJ (Music)
      videojs(this.$refs.autodjPlayer, {
        controls: true,
        autoplay: 'muted',
        sources: [{ src: 'https://os.peoplewelike.club/hls/autodj/stream.m3u8', type: 'application/vnd.apple.mpegurl' }]
      });
    }
  }
}
</script>

<style scoped>
.simple-radio-container { max-width: 900px; margin: 0 auto; padding: 20px; }
.player-wrapper { margin-bottom: 30px; border: 1px solid #333; border-radius: 8px; overflow: hidden; background: #000; }
.stream-title { padding: 10px; background: #1a1a1a; margin: 0; font-size: 1rem; }
/* Ensure players scale */
:deep(.video-js) { width: 100% !important; height: auto !important; aspect-ratio: 16/9; }
.small-note { margin-top: 20px; color: #888; font-size: 0.9rem; }
</style>
