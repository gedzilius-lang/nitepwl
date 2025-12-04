<template>
  <h1>Market</h1>
  <p>Venue: Supermarket</p>
  <div v-for="item in items" :key="item.id" class="card">
    <h3>{{ item.title }}</h3>
    <p>{{ item.priceNite }} NITE</p>
  </div>
</template>
<script>
import axios from 'axios'
export default {
  data() { return { items: [] } },
  async mounted() {
    try { const res = await axios.get('/api/market/1/items'); this.items = res.data; }
    catch (e) { console.error(e); }
  }
}
</script>
