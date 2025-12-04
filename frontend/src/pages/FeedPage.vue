<template>
  <section class="card">
    <h2>Feed</h2>
    <p class="muted">
      This is a stub UI for your social / event feed.
      Below you see live data fetched from <code>/api/feed</code>.
    </p>

    <button class="btn" @click="loadFeed" :disabled="loading">
      {{ loading ? 'Loading…' : 'Ping /api/feed' }}
    </button>

    <pre v-if="response" class="code-block">{{ response }}</pre>
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const loading = ref(false);
const response = ref<string | null>(null);

async function loadFeed() {
  loading.value = true;
  response.value = null;
  try {
    const res = await fetch('/api/feed');
    const json = await res.json();
    response.value = JSON.stringify(json, null, 2);
  } catch (err: any) {
    response.value = 'Error: ' + (err?.message || String(err));
  } finally {
    loading.value = false;
  }
}
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

.btn {
  background: #8b5cf6;
  color: #0b1120;
  border: none;
  padding: 0.45rem 0.9rem;
  border-radius: 999px;
  font-size: 0.85rem;
  cursor: pointer;
}

.btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.code-block {
  margin-top: 0.9rem;
  font-size: 0.8rem;
  background: #020617;
  border-radius: 0.75rem;
  border: 1px solid #111827;
  padding: 0.75rem;
  overflow-x: auto;
}
</style>
