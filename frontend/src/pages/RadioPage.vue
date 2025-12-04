<template>
  <section class="card">
    <h2>Radio</h2>
    <p class="muted">
      This page is meant to host your radio player iframe.
      Replace the <code>src</code> below with your real player URL.
    </p>

    <div class="player-wrapper">
      <iframe
        class="player"
        src="https://example.com/radio-player"
        title="Nite OS Radio Player"
        frameborder="0"
        allow="autoplay; encrypted-media"
      ></iframe>
    </div>
  </section>
</template>

<script setup lang="ts">
</script>

<style scoped>
.card {
  background: #020617;
  border-radius: 1rem;
  border: 1px solid #1f2937;
  padding: 1.25rem;
}

.card h2 {
  font-size: 1.2rem;
  margin-bottom: 0.4rem;
}

.muted {
  font-size: 0.85rem;
  color: #9ca3af;
  margin-bottom: 0.8rem;
}

.player-wrapper {
  margin-top: 0.75rem;
  border-radius: 1rem;
  overflow: hidden;
  border: 1px solid #111827;
  background: #020617;
}

.player {
  width: 100%;
  height: 260px;
}
</style>
