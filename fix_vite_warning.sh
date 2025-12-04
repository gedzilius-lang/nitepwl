#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
CONFIG_FILE="$PROJECT_DIR/frontend/vite.config.js"

echo ">>> [Fix] Adjusting Vite Build Limit..."

# Rewrite vite.config.js with a higher limit (2000kB)
cat << 'EOF' > "$CONFIG_FILE"
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
EOF

echo ">>> Config updated."

echo ">>> [Test] Rebuilding Frontend..."
cd "$PROJECT_DIR/frontend"
npm run build

echo "--------------------------------------------------------"
echo "✅ DONE. The warning should be gone."
echo "--------------------------------------------------------"
