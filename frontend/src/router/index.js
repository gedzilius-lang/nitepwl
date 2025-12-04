import { createRouter, createWebHistory } from 'vue-router'
import Feed from '../views/Feed.vue'
import Market from '../views/Market.vue'
import Profile from '../views/Profile.vue'
import Admin from '../views/Admin.vue'
import Radio from '../views/Radio.vue' // <--- Import
import RadioEmbed from '../views/RadioEmbed.vue' // <--- Import

const routes = [
  { path: '/', component: Feed },
  { path: '/market', component: Market },
  { path: '/profile', component: Profile },
  { path: '/admin', component: Admin },
  { path: '/radio', component: Radio }, // <--- Add
  { path: '/radio/embed', component: RadioEmbed, meta: { layout: 'empty' } } // <--- Add Embed
]
// ... rest of file