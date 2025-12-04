<template>
  <h1>Nite Feed</h1>
  <div v-for="item in items" :key="item.id" class="card">
    <h3>{{ item.title }}</h3>
    <p>{{ item.body }}</p>
  </div>
</template>
<script>
import axios from 'axios'
export default {
  data() { return { items: [] } },
  async mounted() {
    try { const res = await axios.get('/api/feed'); this.items = res.data; } 
    catch (e) { console.error(e); }
  }
}
</script>
