<template>
  <section class="card">
    <h2>Profile</h2>
    <p class="muted">
      Placeholder for NiteTap / Nitecoin profile view.
      Wire this later to <code>/api/users</code>, <code>/api/nitecoin</code>, etc.
    </p>
    <ul class="list">
      <li><span class="label">Status</span> <span class="value">Stub user</span></li>
      <li><span class="label">Level</span> <span class="value">0</span></li>
      <li><span class="label">Nitecoins</span> <span class="value">0.00</span></li>
    </ul>
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

.list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.list li {
  display: flex;
  justify-content: space-between;
  padding: 0.35rem 0;
  font-size: 0.9rem;
}

.label {
  color: #9ca3af;
}

.value {
  color: #e5e7eb;
  font-weight: 500;
}
</style>
