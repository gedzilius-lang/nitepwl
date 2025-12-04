<template>
  <div>
    <h1>👤 My Profile</h1>
    
    <div v-if="user" class="profile-card">
      <div class="header">
        <h2>{{ user.externalId }}</h2>
        <span class="badge">{{ user.role }}</span>
      </div>
      
      <div class="stats">
        <div class="stat">
          <label>Balance</label>
          <div class="value">{{ user.niteBalance }} <small>NITE</small></div>
        </div>
        <div class="stat">
          <label>XP / Level</label>
          <div class="value">{{ user.xp }} <small>Lvl {{ user.level }}</small></div>
        </div>
      </div>

      <button @click="refresh" class="refresh-btn">🔄 Refresh Data</button>
    </div>

    <div v-else>Loading profile...</div>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  data() { return { user: null } },
  async mounted() {
    await this.refresh()
  },
  methods: {
    async refresh() {
      try {
        // In v7 Demo, we force the demo user state
        const res = await axios.post('/api/users/demo')
        this.user = res.data
      } catch (e) {
        console.error(e)
      }
    }
  }
}
</script>

<style scoped>
.profile-card { background: #1a1a1a; padding: 2rem; border-radius: 12px; border: 1px solid #333; max-width: 400px; }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
.badge { background: #333; padding: 4px 8px; border-radius: 4px; font-size: 0.8rem; text-transform: uppercase; }
.stats { display: flex; gap: 2rem; margin-bottom: 2rem; }
.stat label { display: block; color: #888; font-size: 0.9rem; margin-bottom: 4px; }
.stat .value { font-size: 1.5rem; font-weight: bold; color: #fff; }
.stat small { font-size: 0.9rem; color: #8a2be2; }
.refresh-btn { background: #222; color: #aaa; border: 1px solid #444; padding: 8px 16px; border-radius: 4px; cursor: pointer; width: 100%; }
.refresh-btn:hover { background: #333; color: white; }
</style>
