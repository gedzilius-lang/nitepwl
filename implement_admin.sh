#!/usr/bin/env bash
set -e

PROJECT_DIR="$HOME/nitepwl"
BACKEND_DIR="$PROJECT_DIR/backend/src/modules"
FRONTEND_DIR="$PROJECT_DIR/frontend/src"

echo ">>> [Phase 6] Building Admin Dashboard & Dynamic Feed..."

# ==========================================
# 1. BACKEND: Dynamic Feed System
# ==========================================

# --- Feed Entity (Database Table for Posts) ---
cat << 'EOF' > "$BACKEND_DIR/feed/feed-item.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('feed_items')
export class FeedItem {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  type: string; // 'news', 'event'

  @Column()
  title: string;

  @Column()
  body: string;

  @Column({ nullable: true })
  venueId: string;

  @CreateDateColumn()
  createdAt: Date;
}
EOF

# --- Feed Service (Logic to Save/Load Posts) ---
cat << 'EOF' > "$BACKEND_DIR/feed/feed.service.ts"
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FeedItem } from './feed-item.entity';

@Injectable()
export class FeedService {
  constructor(
    @InjectRepository(FeedItem)
    private repo: Repository<FeedItem>,
  ) {}

  async findAll() {
    return this.repo.find({ order: { createdAt: 'DESC' } });
  }

  async create(data: Partial<FeedItem>) {
    return this.repo.save(this.repo.create(data));
  }

  async seed() {
    const count = await this.repo.count();
    if (count === 0) {
      await this.create({ type: 'news', title: 'Welcome to NiteOS v7', body: 'System Online. Economy Active.' });
      await this.create({ type: 'event', title: 'Launch Party', body: 'Double XP is now ENABLED.' });
    }
  }
}
EOF

# --- Feed Controller (API Endpoints) ---
cat << 'EOF' > "$BACKEND_DIR/feed/feed.controller.ts"
import { Controller, Get, Post, Body } from '@nestjs/common';
import { FeedService } from './feed.service';

@Controller('feed')
export class FeedController {
  constructor(private readonly service: FeedService) {}

  @Get()
  async getFeed() {
    await this.service.seed(); // Auto-seed if empty
    return this.service.findAll();
  }

  @Post()
  createPost(@Body() body: any) {
    return this.service.create(body);
  }
}
EOF

# --- Feed Module Registration ---
cat << 'EOF' > "$BACKEND_DIR/feed/feed.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FeedItem } from './feed-item.entity';
import { FeedService } from './feed.service';
import { FeedController } from './feed.controller';

@Module({
  imports: [TypeOrmModule.forFeature([FeedItem])],
  controllers: [FeedController],
  providers: [FeedService],
})
export class FeedModule {}
EOF

# --- Nitecoin History Endpoint ---
# We need an endpoint to fetch transaction history for the Profile UI
cat << 'EOF' > "$BACKEND_DIR/nitecoin/nitecoin.controller.ts"
import { Controller, Get, Param } from '@nestjs/common';
import { NitecoinService } from './nitecoin.service';

@Controller('nitecoin')
export class NitecoinController {
  constructor(private readonly service: NitecoinService) {}

  @Get('history/:userId')
  getHistory(@Param('userId') userId: string) {
    return this.service.getHistory(userId);
  }
}
EOF

# Register the Controller
cat << 'EOF' > "$BACKEND_DIR/nitecoin/nitecoin.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NitecoinTransaction } from './nitecoin-transaction.entity';
import { NitecoinService } from './nitecoin.service';
import { NitecoinController } from './nitecoin.controller';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([NitecoinTransaction]),
    UsersModule
  ],
  controllers: [NitecoinController],
  providers: [NitecoinService],
  exports: [NitecoinService],
})
export class NitecoinModule {}
EOF

# --- Register New Entity in App Module ---
# We must add FeedItem to the database config
cat << 'EOF' > "$PROJECT_DIR/backend/src/app.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from './modules/users/users.module';
import { FeedModule } from './modules/feed/feed.module';
import { VenuesModule } from './modules/venues/venues.module';
import { MarketModule } from './modules/market/market.module';
import { NitecoinModule } from './modules/nitecoin/nitecoin.module';
import { PosModule } from './modules/pos/pos.module';

import { User } from './modules/users/user.entity';
import { Venue } from './modules/venues/venue.entity';
import { MarketItem } from './modules/market/market-item.entity';
import { NitecoinTransaction } from './modules/nitecoin/nitecoin-transaction.entity';
import { PosTransaction } from './modules/pos/pos-transaction.entity';
import { FeedItem } from './modules/feed/feed-item.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: 5432,
      username: 'nite',
      password: 'nitepassword',
      database: 'nite_os',
      entities: [User, Venue, MarketItem, NitecoinTransaction, PosTransaction, FeedItem],
      synchronize: true, 
    }),
    UsersModule,
    FeedModule,
    VenuesModule,
    MarketModule,
    NitecoinModule,
    PosModule
  ],
})
export class AppModule {}
EOF

# ==========================================
# 2. FRONTEND: Admin Dashboard & Profile
# ==========================================

# --- Admin View ---
cat << 'EOF' > "$FRONTEND_DIR/views/Admin.vue"
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
EOF

# --- Enhanced Profile (With Transactions) ---
cat << 'EOF' > "$FRONTEND_DIR/views/Profile.vue"
<template>
  <div>
    <h1>👤 My Profile</h1>
    
    <div v-if="user" class="profile-card">
      <div class="header">
        <h2>{{ user.externalId }}</h2>
        <span class="badge">{{ user.role }}</span>
      </div>
      
      <div class="xp-container">
        <div class="xp-info">
          <span>Lvl {{ user.level }}</span>
          <span>{{ user.xp }} XP</span>
        </div>
        <div class="xp-bar-bg"><div class="xp-bar-fill" :style="{width: (user.xp % 100) + '%'}"></div></div>
      </div>

      <div class="stats">
        <div class="stat">
          <label>Balance</label>
          <div class="value">{{ user.niteBalance }} <small>NITE</small></div>
        </div>
      </div>
    </div>

    <div v-if="history.length" class="history">
      <h3>📜 Recent Activity</h3>
      <div v-for="tx in history" :key="tx.id" class="tx-row">
        <span :class="['tx-type', tx.type]">{{ tx.type }}</span>
        <span class="tx-amount">{{ tx.amount }} NITE</span>
      </div>
    </div>

    <button @click="refresh" style="margin-top:20px; padding:10px; width:100%;">🔄 Refresh</button>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  data() { return { user: null, history: [] } },
  async mounted() { await this.refresh() },
  methods: {
    async refresh() {
      try {
        const userRes = await axios.post('/api/users/demo')
        this.user = userRes.data
        const histRes = await axios.get(`/api/nitecoin/history/${this.user.id}`)
        this.history = histRes.data
      } catch (e) { console.error(e) }
    }
  }
}
</script>

<style scoped>
.profile-card { background: #1a1a1a; padding: 2rem; border-radius: 12px; border: 1px solid #333; margin-bottom: 20px; }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; }
.badge { background: #333; padding: 4px 8px; border-radius: 4px; font-size: 0.8rem; text-transform: uppercase; }
.stats { display: flex; gap: 2rem; margin-top: 1.5rem; }
.stat .value { font-size: 1.5rem; font-weight: bold; color: #fff; }
.xp-bar-bg { height: 8px; background: #333; border-radius: 4px; overflow: hidden; margin-top:5px; }
.xp-bar-fill { height: 100%; background: linear-gradient(90deg, #8a2be2, #ff00ff); }
.history { background: #1a1a1a; border-radius: 8px; border: 1px solid #333; padding: 10px; }
.tx-row { display: flex; justify-content: space-between; padding: 12px; border-bottom: 1px solid #222; }
.tx-type.spend { color: #ff4444; font-weight: bold; text-transform: uppercase;}
.tx-type.earn { color: #00c851; font-weight: bold; text-transform: uppercase;}
</style>
EOF

# --- Navigation Update ---
cat << 'EOF' > "$FRONTEND_DIR/App.vue"
<template>
  <div>
    <nav>
      <router-link to="/">Feed</router-link>
      <router-link to="/market">Market</router-link>
      <router-link to="/profile">Profile</router-link>
      <router-link to="/admin" class="admin-link">Admin</router-link>
    </nav>
    <main>
      <router-view></router-view>
    </main>
  </div>
</template>
<style>
.admin-link { color: #ff4444 !important; margin-left: auto; }
</style>
EOF

# --- Router Update ---
cat << 'EOF' > "$FRONTEND_DIR/router/index.js"
import { createRouter, createWebHistory } from 'vue-router'
import Feed from '../views/Feed.vue'
import Market from '../views/Market.vue'
import Profile from '../views/Profile.vue'
import Admin from '../views/Admin.vue'

const routes = [
  { path: '/', component: Feed },
  { path: '/market', component: Market },
  { path: '/profile', component: Profile },
  { path: '/admin', component: Admin }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
EOF

echo "--------------------------------------------------------"
echo "✅ ADMIN & PROFILE UPGRADE COMPLETE!"
echo "👉 Local environment is auto-reloading..."
echo "--------------------------------------------------------"
