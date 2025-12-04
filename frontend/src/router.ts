import { createRouter, createWebHistory } from 'vue-router';
import FeedPage from './pages/FeedPage.vue';
import MarketPage from './pages/MarketPage.vue';
import ProfilePage from './pages/ProfilePage.vue';
import RadioPage from './pages/RadioPage.vue';

const routes = [
  { path: '/', name: 'Feed', component: FeedPage },
  { path: '/market', name: 'Market', component: MarketPage },
  { path: '/profile', name: 'Profile', component: ProfilePage },
  { path: '/radio', name: 'Radio', component: RadioPage },
];

export const router = createRouter({
  history: createWebHistory(),
  routes,
});
