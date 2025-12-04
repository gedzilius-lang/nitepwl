#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
FRONTEND_DIR="$APP_DIR/frontend/src/views"

echo ">>> [Phase 4] Connecting Frontend to Economy..."

# 1. UPDATE MARKET (Enable Purchasing)
# ---------------------------------------------------------
cat << 'EOF' > "$FRONTEND_DIR/Market.vue"
<template>
  <div>
    <h1>🛒 Supermarket</h1>
    <div v-if="loading">Loading market data...</div>
    <div v-else class="grid">
      <div v-for="item in items" :key="item.id" class="card">
        <h3>{{ item.title }}</h3>
        <p class="price">{{ item.priceNite }} NITE</p>
        <button @click="buy(item)" :disabled="processing">
          {{ processing ? '...' : 'Buy Now' }}
        </button>
      </div>
    </div>
    <p v-if="message" class="status-msg">{{ message }}</p>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  data() {
    return { 
      items: [], 
      loading: true, 
      processing: false,
      message: '',
      venueId: 1 // Default demo venue
    } 
  },
  async mounted() {
    await this.loadItems()
  },
  methods: {
    async loadItems() {
      try {
        const res = await axios.get(`/api/market/${this.venueId}/items`)
        this.items = res.data
      } catch (e) {
        console.error(e)
      } finally {
        this.loading = false
      }
    },
    async buy(item) {
      this.processing = true
      this.message = ''
      try {
        // 1. Get current user (Demo mode: auto-login as demo_admin)
        const userRes = await axios.post('/api/users/demo')
        const userId = userRes.data.id

        // 2. Process Checkout
        await axios.post(`/api/pos/${this.venueId}/checkout`, {
          userId: userId,
          amount: item.priceNite,
          items: [{ id: item.id, title: item.title }]
        })

        this.message = `✅ Successfully bought ${item.title}!`
      } catch (e) {
        this.message = `❌ Error: ${e.response?.data?.message || e.message}`
      } finally {
        this.processing = false
      }
    }
  }
}
</script>

<style scoped>
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; }
.card { background: #1a1a1a; padding: 1.5rem; border-radius: 8px; border: 1px solid #333; text-align: center; }
.price { color: #8a2be2; font-weight: bold; font-size: 1.2rem; margin: 10px 0; }
button { background: #8a2be2; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; font-weight: bold; }
button:disabled { opacity: 0.5; cursor: not-allowed; }
.status-msg { margin-top: 20px; font-weight: bold; color: #fff; background: #222; padding: 10px; border-radius: 4px; display: inline-block;}
</style>
EOF

# 2. UPDATE PROFILE (Show Balance & History)
# ---------------------------------------------------------
cat << 'EOF' > "$FRONTEND_DIR/Profile.vue"
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
EOF

# 3. REBUILD FRONTEND
# ---------------------------------------------------------
echo ">>> [Build] Recompiling Frontend..."
cd "$APP_DIR/frontend"
npm run build

echo ">>> [Deploy] Backup changes to GitHub..."
cd "$APP_DIR"
git add frontend/src/views/Market.vue frontend/src/views/Profile.vue
git commit -m "Feat: Connect Frontend to POS Economy" || echo "Nothing to commit"
git push origin main

echo "--------------------------------------------------------"
echo ">>> DONE! The 'Market' page is now live and working."
echo ">>> Go to: https://os.peoplewelike.club/market"
echo ">>> Try buying an item, then check Profile for balance update."
echo "--------------------------------------------------------"
