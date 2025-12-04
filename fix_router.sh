#!/usr/bin/env bash
set -e

ROUTER_FILE="$HOME/nitepwl/frontend/src/router/index.js"

echo ">>> [Fix] Repairing Frontend Router..."

cat << 'EOF' > "$ROUTER_FILE"
import { createRouter, createWebHistory } from 'vue-router'
import Feed from '../views/Feed.vue'
import Market from '../views/Market.vue'
import Profile from '../views/Profile.vue'
import Admin from '../views/Admin.vue'
import Radio from '../views/Radio.vue'
import RadioEmbed from '../views/RadioEmbed.vue'

const routes = [
  { path: '/', component: Feed },
  { path: '/market', component: Market },
  { path: '/profile', component: Profile },
  { path: '/admin', component: Admin },
  { path: '/radio', component: Radio },
  { path: '/radio/embed', component: RadioEmbed, meta: { layout: 'empty' } }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
EOF

echo "✅ Router Fixed. 'export default router' is now present."
