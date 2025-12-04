import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': 'http://localhost:3000'
    }
  },
  build: {
    // Increase chunk size warning limit to 3MB (silences the warning)
    chunkSizeWarningLimit: 3000
  }
})
