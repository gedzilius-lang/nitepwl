<template>
  <div>
    <h1>🛡️ Venue Admin</h1>
    
    <div class="admin-section">
      <h2>📢 Post to Feed</h2>
      <div class="form-group">
        <select v-model="post.type">
          <option value="news">News</option>
          <option value="event">Event</option>
        </select>
        <input v-model="post.title" placeholder="Title (e.g. Happy Hour)" />
        <textarea v-model="post.body" placeholder="Details..."></textarea>
        <button @click="createPost">Post Live</button>
      </div>
    </div>
    
    <p v-if="msg" class="msg">{{ msg }}</p>
  </div>
</template>

<script>
import axios from 'axios'
export default {
  data() {
    return {
      post: { type: 'news', title: '', body: '' },
      msg: ''
    }
  },
  methods: {
    async createPost() {
      try {
        await axios.post('/api/feed', this.post)
        this.msg = '✅ Posted successfully! Check the Feed.'
        this.post = { type: 'news', title: '', body: '' }
      } catch (e) { this.msg = '❌ Error posting' }
    }
  }
}
</script>

<style scoped>
.admin-section { background: #1a1a1a; padding: 20px; border-radius: 8px; border: 1px solid #333; }
.form-group { display: flex; flex-direction: column; gap: 10px; max-width: 400px; }
input, textarea, select { padding: 10px; background: #222; color: white; border: 1px solid #444; border-radius: 4px; }
button { padding: 10px; background: #ff4444; color: white; border: none; font-weight: bold; cursor: pointer; border-radius: 4px; }
.msg { margin-top: 10px; padding: 10px; background: #333; display: inline-block; border-radius: 4px; }
</style>
