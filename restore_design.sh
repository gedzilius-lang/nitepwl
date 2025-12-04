#!/bin/bash
set -e

FRONTEND_DIR="$HOME/nitepwl/frontend/src/views"

echo ">>> [Phase 9] Restoring 'Backup' Radio Design (PeopleWeLike)..."

cat << 'VUE' > "$FRONTEND_DIR/Radio.vue"
<template>
  <div class="pwl-radio-body">
    <header>
        <div class="logo">peoplewelike</div>
        <div class="header-controls">
            <button 
              class="btn-base live-btn" 
              :class="{ available: isLiveAvailable, watching: isWatchingLive }" 
              @click="handleLiveClick">
              {{ liveBtnText }}
            </button>
            
            <button class="btn-base" @click="shareSite">SHARE</button>
            
            <button 
              class="btn-base av-toggle" 
              :class="{ active: !videoEnabled }" 
              @click="toggleVideo">
              {{ videoEnabled ? 'VIDEO ON' : 'AUDIO ONLY' }}
            </button>
        </div>
    </header>

    <div class="player-toolbar">
        <div class="meta-info" @click="copyTrack">
            <span class="meta-label">Now Playing</span>
            <div class="meta-content">
                <span class="now-playing">{{ trackTitle }}</span>
                <span v-if="timerDisplay" class="time-remaining">{{ timerDisplay }}</span>
            </div>
        </div>
        <div class="listener-badge">
            <span class="listener-count">{{ listenerCount }}</span> LISTENING
        </div>
    </div>

    <div class="stage">
        <div id="audio-overlay" :style="{ opacity: videoEnabled ? 0 : 1, pointerEvents: videoEnabled ? 'none' : 'auto' }">
            <div class="audio-visualizer">
              <div class="bar"></div><div class="bar"></div><div class="bar"></div><div class="bar"></div>
            </div>
            <div class="audio-meta-large">{{ trackTitle }}</div>
            <div class="audio-label">AUDIO ONLY</div>
        </div>

        <video ref="videoPlayer" class="video-js vjs-default-skin vjs-big-play-centered" crossorigin="anonymous" playsinline></video>
    </div>

    <div class="main-container">
        <div class="schedule-wrapper">
            <div class="carousel-label">Weekly Schedule</div>
            <div class="carousel">
               <div class="carousel-item today">
                 <div class="c-day">TODAY</div>
                 <div class="c-show">NiteOS Radio</div>
                 <div class="c-time">24/7</div>
               </div>
            </div>
        </div>
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
      videoEnabled: true,
      isLiveAvailable: false,
      isWatchingLive: false,
      trackTitle: "Loading...",
      timerDisplay: "",
      listenerCount: 0,
      toastVisible: false,
      toastMessage: "LINK COPIED",
      
      // TIMERS
      intervals: [],
      currentDuration: 0,
      currentStartTime: 0,
      
      // SOURCES
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
    
    // Start Polling
    this.checkLiveStream();
    this.updateStats();
    
    this.intervals.push(setInterval(this.checkLiveStream, 5000));
    this.intervals.push(setInterval(this.updateStats, 5000));
    this.intervals.push(setInterval(this.tickTimer, 1000));
  },
  beforeUnmount() {
    if (this.player) this.player.dispose();
    this.intervals.forEach(clearInterval);
  },
  methods: {
    initPlayer() {
      this.player = videojs(this.$refs.videoPlayer, {
        controls: true,
        autoplay: 'muted',
        preload: 'auto',
        fluid: false, // We control size via CSS
        fill: true,
        responsive: true,
        muted: true,
        html5: {
          vhs: {
            overrideNative: true, // Bypass native HLS for better control
            enableLowInitialPlaylist: true
          }
        }
      });

      // Default to AutoDJ
      if (!this.isWatchingLive) {
        this.player.src({ src: this.sources.autodj, type: 'application/vnd.apple.mpegurl' });
      }
      
      this.player.ready(() => {
        this.player.play().catch(() => {});
      });
    },

    // --- LIVE LOGIC ---
    async checkLiveStream() {
      try {
        const res = await fetch(this.sources.live, { method: 'HEAD' });
        if (res.ok) {
          if (!this.isLiveAvailable) {
             this.isLiveAvailable = true;
             // Auto-switch if desired, or just show button
          }
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
      this.updateStats(); // Fetch song title immediately
    },

    // --- METADATA ---
    async updateStats() {
      if (this.isWatchingLive) return;
      try {
        // Matches the file created by our backend script
        const res = await fetch('/now_playing.json?t=' + Date.now());
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

    // --- UI ACTIONS ---
    toggleVideo() {
      this.videoEnabled = !this.videoEnabled;
      const el = this.$refs.videoPlayer.querySelector('video') || this.$refs.videoPlayer;
      // We manipulate the DOM element directly to match index.html logic
      if (this.videoEnabled) {
        el.style.opacity = "1"; 
        el.style.zIndex = "1";
      } else {
        el.style.opacity = "0"; 
        el.style.zIndex = "0";
      }
    },

    shareSite() {
      if (navigator.share) { 
        navigator.share({ title: 'People We Like Radio', url: window.location.href }); 
      } else { 
        navigator.clipboard.writeText(window.location.href); 
        this.showToast("LINK COPIED"); 
      }
    },

    copyTrack() {
       if(this.trackTitle.includes("Loading") || this.trackTitle.includes("Live")) return;
       navigator.clipboard.writeText(this.trackTitle).then(() => { 
         this.showToast("COPIED: " + this.trackTitle); 
       });
    },

    showToast(msg) {
      this.toastMessage = msg;
      this.toastVisible = true;
      setTimeout(() => { this.toastVisible = false; }, 3000);
    }
  }
}
</script>

<style scoped>
/* RESTORING CSS FROM BACKUP */
.pwl-radio-body {
    --bg: #000000; --panel: #0a0a0a; --text: #e0e0e0; 
    --accent-primary: #50c878; --accent-secondary: #9b59b6; --accent-live: #ff0000; --dim: #444;
    background-color: var(--bg); color: var(--text); 
    font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    min-height: 100vh;
}

/* HEADER */
header { display: flex; justify-content: space-between; align-items: center; padding: 15px 20px; border-bottom: 1px solid #111; background: #000; }
.logo { font-weight: bold; font-size: 16px; letter-spacing: -0.5px; color: #fff; }
.header-controls { display: flex; gap: 8px; align-items: center; }
.btn-base { background: transparent; border: 1px solid #333; color: var(--dim); padding: 8px 12px; font-size: 10px; font-weight: bold; letter-spacing: 1px; text-transform: uppercase; cursor: pointer; border-radius: 2px; transition: all 0.3s; white-space: nowrap; }
.btn-base:hover { border-color: var(--text); color: var(--text); }

/* LIVE BUTTON */
.live-btn { opacity: 0.3; pointer-events: none; border-color: #222; }
.live-btn.available { opacity: 1; pointer-events: auto; color: var(--accent-live); border-color: var(--accent-live); animation: pulse-red 1.5s infinite; }
.live-btn.watching { opacity: 1; color: #fff; background: var(--accent-live); animation: none; }
@keyframes pulse-red { 0% { box-shadow: 0 0 0 0 rgba(255, 0, 0, 0.4); } 70% { box-shadow: 0 0 0 6px rgba(255, 0, 0, 0); } 100% { box-shadow: 0 0 0 0 rgba(255, 0, 0, 0); } }

/* STAGE */
.stage { width: 100%; height: 50vh; background: #000; position: relative; border-bottom: 1px solid #111; }
@media (min-width: 768px) { .stage { height: 65vh; } }

/* Override VideoJS styles to fit stage */
:deep(.video-js) { width: 100% !important; height: 100% !important; }
:deep(.vjs-control-bar) { background: rgba(0,0,0,0.7) !important; }

/* AUDIO OVERLAY */
#audio-overlay { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: #050505; z-index: 0; display: flex; flex-direction: column; justify-content: center; align-items: center; transition: opacity 0.5s ease; }
.audio-visualizer { display: flex; gap: 5px; height: 40px; align-items: center; margin-bottom: 20px; }
.bar { width: 4px; background: var(--dim); animation: eq 1s infinite ease-in-out; }
.bar:nth-child(odd) { animation-duration: 0.8s; }
@keyframes eq { 0%, 100% { height: 10px; opacity: 0.5; } 50% { height: 30px; opacity: 1; } }
.audio-meta-large { font-size: 14px; color: #fff; text-transform: uppercase; letter-spacing: 1px; text-align: center; max-width: 80%; line-height: 1.4; }
.audio-label { font-size: 10px; color: var(--dim); letter-spacing: 2px; margin-top: 10px; text-transform: uppercase; }

/* TOOLBAR */
.player-toolbar { background: var(--panel); border-bottom: 1px solid #111; padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; }
.meta-info { display: flex; flex-direction: column; gap: 4px; cursor: pointer; flex: 1; overflow: hidden; }
.meta-label { font-size: 9px; color: var(--dim); text-transform: uppercase; letter-spacing: 1px; font-weight: bold; }
.now-playing { color: var(--text); font-size: 12px; font-weight: 500; letter-spacing: 0.5px; text-transform: uppercase; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.time-remaining { font-family: 'Courier New', monospace; font-size: 10px; color: var(--accent-primary); background: rgba(80, 200, 120, 0.1); padding: 2px 4px; border-radius: 2px; }
.listener-badge { font-size: 10px; color: var(--dim); letter-spacing: 1px; font-weight: bold; white-space: nowrap; margin-left: 10px; }
.listener-count { color: var(--accent-secondary); }

/* SCHEDULE (Carousel) */
.main-container { max-width: 1000px; margin: 0 auto; padding: 20px; }
.schedule-wrapper { position: relative; padding-bottom: 40px; }
.carousel-label { font-size: 10px; color: var(--dim); letter-spacing: 2px; text-transform: uppercase; margin-bottom: 15px; }
.carousel { display: flex; gap: 15px; overflow-x: auto; }
.carousel-item { min-width: 160px; flex: 0 0 auto; border-left: 1px solid #222; padding-left: 15px; opacity: 0.6; }
.carousel-item.today { opacity: 1; border-left-color: var(--accent-secondary); }
.c-day { font-size: 10px; font-weight: bold; color: #fff; margin-bottom: 8px; }
.c-show { font-size: 12px; color: var(--text); margin-bottom: 4px; }
.c-time { font-size: 10px; color: var(--dim); font-family: monospace; }

/* TOAST */
#toast { visibility: hidden; min-width: 200px; background-color: #222; color: #fff; text-align: center; border-radius: 4px; padding: 12px; position: fixed; z-index: 1000; left: 50%; bottom: 30px; transform: translateX(-50%); font-size: 11px; text-transform: uppercase; letter-spacing: 1px; border-bottom: 2px solid var(--accent-primary); opacity: 0; transition: opacity 0.5s, bottom 0.5s; }
#toast.show { visibility: visible; opacity: 1; bottom: 50px; }
footer { text-align: center; padding: 40px 20px; color: var(--dim); font-size: 10px; text-transform: uppercase; letter-spacing: 1px; }

/* MOBILE */
@media (max-width: 600px) { header, .player-toolbar { padding: 15px 20px; } .now-playing { max-width: 150px; } }
</style>
VUE

echo ">>> [Git] Pushing Restored Design..."
cd "$HOME/nitepwl"
git add .
git commit -m "Design: Restore PeopleWeLike Radio Backup"
git push origin main

echo "--------------------------------------------------------"
echo "✅ Design Restored."
echo "👉 Run 'nite deploy' on your VPS to go live."
echo "--------------------------------------------------------"
