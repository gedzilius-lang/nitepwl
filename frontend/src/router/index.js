import { createRouter, createWebHistory } from 'vue-router'
import Feed from '../views/Feed.vue'
import Market from '../views/Market.vue'
import Profile from '../views/Profile.vue'

const routes = [
  { path: '/', component: Feed },
  { path: '/market', component: Market },
  { path: '/profile', component: Profile }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
