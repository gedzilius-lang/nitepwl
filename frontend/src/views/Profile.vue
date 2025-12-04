<template>
  <div>
    <h1>👤 My Profile</h1>
    
    <div v-if="user" class="profile-card">
      <div class="header">
        <h2>{{ user.externalId }}</h2>
        <span class="badge">{{ user.role }}</span>
      </div>
      
      <div class="xp-container">
        <div class="xp-info">
          <span>Lvl {{ user.level }}</span>
          <span>{{ user.xp }} XP</span>
        </div>
        <div class="xp-bar-bg"><div class="xp-bar-fill" :style="{width: (user.xp % 100) + '%'}"></div></div>
      </div>

      <div class="stats">
        <div class="stat">
          <label>Balance</label>
          <div class="value">{{ user.niteBalance }} <small>NITE</small></div>
        </div>
      </div>
    </div>

    <div v-if="history.length" class="history">
      <h3>📜 Recent Activity</h3>
      <div v-for="tx in history" :key="tx.id" class="tx-row">
        <span :class="['tx-type', tx.type]">{{ tx.type }}</span>
        <span class="tx-amount">{{ tx.amount }} NITE</span>
      </div>
    </div>

    <button @click="refresh" style="margin-top:20px; padding:10px; width:100%;">🔄 Refresh</button>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  data() { return { user: null, history: [] } },
  async mounted() { await this.refresh() },
  methods: {
    async refresh() {
      try {
        const userRes = await axios.post('/api/users/demo')
        this.user = userRes.data
        const histRes = await axios.get(`/api/nitecoin/history/${this.user.id}`)
        this.history = histRes.data
      } catch (e) { console.error(e) }
    }
  }
}
</script>

<style scoped>
.profile-card { background: #1a1a1a; padding: 2rem; border-radius: 12px; border: 1px solid #333; margin-bottom: 20px; }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
.badge { background: #333; padding: 4px 8px; border-radius: 4px; font-size: 0.8rem; text-transform: uppercase; }
.stats { display: flex; gap: 2rem; margin-top: 1.5rem; }
.stat .value { font-size: 1.5rem; font-weight: bold; color: #fff; }
.xp-bar-bg { height: 8px; background: #333; border-radius: 4px; overflow: hidden; margin-top:5px; }
.xp-bar-fill { height: 100%; background: linear-gradient(90deg, #8a2be2, #ff00ff); }
.history { background: #1a1a1a; border-radius: 8px; border: 1px solid #333; padding: 10px; }
.tx-row { display: flex; justify-content: space-between; padding: 12px; border-bottom: 1px solid #222; }
.tx-type.spend { color: #ff4444; font-weight: bold; text-transform: uppercase;}
.tx-type.earn { color: #00c851; font-weight: bold; text-transform: uppercase;}
</style>
