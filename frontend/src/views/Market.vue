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
