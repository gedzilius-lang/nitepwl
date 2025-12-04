<template>
  <div class="app">
    <header class="app-header">
      <h1>Nite OS</h1>
      <p class="subtitle">Supermarket for Nightlife – Monolith Skeleton</p>
    </header>

    <nav class="nav">
      <router-link to="/" class="nav-link" active-class="active" exact>Feed</router-link>
      <router-link to="/market" class="nav-link" active-class="active">Market</router-link>
      <router-link to="/profile" class="nav-link" active-class="active">Profile</router-link>
      <router-link to="/radio" class="nav-link" active-class="active">Radio</router-link>
    </nav>

    <main class="main">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.app {
  min-height: 100vh;
  background: #050608;
  color: #f5f5f5;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  padding: 1.5rem;
}

.app-header {
  text-align: center;
  margin-bottom: 1rem;
}

.app-header h1 {
  font-size: 1.8rem;
  margin-bottom: 0.2rem;
}

.subtitle {
  font-size: 0.9rem;
  color: #9ca3af;
}

.nav {
  display: flex;
  justify-content: center;
  gap: 1rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.nav-link {
  padding: 0.4rem 0.9rem;
  border-radius: 999px;
  border: 1px solid #374151;
  font-size: 0.85rem;
  text-decoration: none;
  color: #e5e7eb;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}

.nav-link:hover {
  border-color: #8b5cf6;
}

.nav-link.active {
  background: #8b5cf6;
  border-color: #8b5cf6;
  color: #0b1120;
}

.main {
  max-width: 960px;
  margin: 0 auto;
  margin-top: 0.5rem;
}
</style>
