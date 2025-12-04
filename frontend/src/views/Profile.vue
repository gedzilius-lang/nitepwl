<template>
  <h1>Profile</h1>
  <div v-if="user" class="card">
    <h2>{{ user.externalId }}</h2>
    <p>Role: {{ user.role }}</p>
    <p>Balance: {{ user.niteBalance }} NITE</p>
    <p>XP: {{ user.xp }} (Lvl {{ user.level }})</p>
  </div>
  <button @click="createDemo">Initialize Demo User</button>
</template>
<script>
import axios from 'axios'
export default {
  data() { return { user: null } },
  methods: {
    async createDemo() { const res = await axios.post('/api/users/demo'); this.user = res.data; }
  },
  async mounted() { await this.createDemo(); }
}
</script>
