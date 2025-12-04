#!/usr/bin/env bash
set -e

# Configuration
APP_DIR="/opt/nite-os-v7"
BACKEND_DIR="$APP_DIR/backend"
FRONTEND_DIR="$APP_DIR/frontend"

echo ">>> [NiteOS v7] Starting Direct Upgrade..."

# 1. Clean Slate (Backup old if exists, create new)
if [ -d "$APP_DIR" ]; then
    echo ">>> Backing up existing directory..."
    mv "$APP_DIR" "${APP_DIR}_backup_$(date +%s)"
fi

# --- FIX: Added missing router directory here ---
mkdir -p "$BACKEND_DIR/src/modules/users"
mkdir -p "$BACKEND_DIR/src/modules/venues"
mkdir -p "$BACKEND_DIR/src/modules/market"
mkdir -p "$BACKEND_DIR/src/modules/feed"
mkdir -p "$FRONTEND_DIR/src/views"
mkdir -p "$FRONTEND_DIR/src/router"
mkdir -p "$APP_DIR/infra/nginx"

echo ">>> Writing Backend Files..."

# --- BACKEND: package.json ---
cat << 'EOF' > "$BACKEND_DIR/package.json"
{
  "name": "nite-backend-v7",
  "version": "7.0.0",
  "scripts": {
    "build": "nest build",
    "start": "nest start",
    "start:prod": "node dist/main"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/typeorm": "^10.0.0",
    "pg": "^8.11.0",
    "typeorm": "^0.3.20",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.8.0",
    "class-validator": "^0.14.0",
    "class-transformer": "^0.5.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

# --- BACKEND: tsconfig.json ---
cat << 'EOF' > "$BACKEND_DIR/tsconfig.json"
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true
  }
}
EOF

# --- BACKEND: main.ts ---
cat << 'EOF' > "$BACKEND_DIR/src/main.ts"
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');
  app.enableCors();
  await app.listen(3000);
  console.log('NiteOS v7 Backend running on port 3000');
}
bootstrap();
EOF

# --- BACKEND: app.module.ts ---
cat << 'EOF' > "$BACKEND_DIR/src/app.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from './modules/users/users.module';
import { FeedModule } from './modules/feed/feed.module';
import { VenuesModule } from './modules/venues/venues.module';
import { MarketModule } from './modules/market/market.module';
import { User } from './modules/users/user.entity';
import { Venue } from './modules/venues/venue.entity';
import { MarketItem } from './modules/market/market-item.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'nite',
      password: 'nitepassword',
      database: 'nite_os',
      entities: [User, Venue, MarketItem],
      synchronize: true, 
    }),
    UsersModule,
    FeedModule,
    VenuesModule,
    MarketModule
  ],
})
export class AppModule {}
EOF

# --- BACKEND: User Entity ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/users/user.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', nullable: true })
  externalId: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', nullable: true })
  nitetapId: string;

  @Column({ type: 'varchar', nullable: true })
  apiKey: string;

  @Column({ type: 'int', default: 1 })
  level: number;

  @Column({ type: 'int', default: 0 })
  xp: number;

  @Column({ type: 'int', default: 0 })
  niteBalance: number;

  @Column({ type: 'varchar', default: 'user' })
  role: string;

  @Column({ type: 'varchar', nullable: true })
  venueId: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
EOF

# --- BACKEND: Users Service ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/users/users.service.ts"
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  findAll() {
    return this.usersRepository.find();
  }

  async createDemoUser() {
    const existing = await this.usersRepository.findOneBy({ externalId: 'demo_admin' });
    if (existing) return existing;

    const user = this.usersRepository.create({
      externalId: 'demo_admin',
      role: 'admin',
      nitetapId: 'tap_demo_123',
      xp: 1000,
      level: 5,
      niteBalance: 500
    });
    return this.usersRepository.save(user);
  }
}
EOF

# --- BACKEND: Users Controller ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/users/users.controller.ts"
import { Controller, Get, Post } from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  getAll() {
    return this.usersService.findAll();
  }

  @Post('demo')
  createDemo() {
    return this.usersService.createDemoUser();
  }
}
EOF

# --- BACKEND: Users Module ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/users/users.module.ts"
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
EOF

# --- BACKEND: Venue Entity ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/venues/venue.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn } from 'typeorm';

@Entity('venues')
export class Venue {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  slug: string;

  @Column()
  title: string;

  @Column()
  city: string;
}
EOF

# --- BACKEND: Venues Module ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/venues/venues.module.ts"
import { Module, Controller, Get } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Venue } from './venue.entity';

@Controller('venues')
export class VenuesController {
  constructor(@InjectRepository(Venue) private repo: Repository<Venue>) {}

  @Get()
  async findAll() {
    const count = await this.repo.count();
    if (count === 0) {
        await this.repo.save({ slug: 'supermarket', title: 'Supermarket', city: 'Zurich' });
    }
    return this.repo.find();
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([Venue])],
  controllers: [VenuesController],
})
export class VenuesModule {}
EOF

# --- BACKEND: Market Module ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/market/market-item.entity.ts"
import { Entity, Column, PrimaryGeneratedColumn } from 'typeorm';

@Entity('market_items')
export class MarketItem {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @Column({ type: 'int' })
  priceNite: number;

  @Column({ type: 'int', default: 1 })
  venueId: number;
}
EOF

cat << 'EOF' > "$BACKEND_DIR/src/modules/market/market.module.ts"
import { Module, Controller, Get, Param } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MarketItem } from './market-item.entity';

@Controller('market')
export class MarketController {
  constructor(@InjectRepository(MarketItem) private repo: Repository<MarketItem>) {}

  @Get(':venueId/items')
  async findByVenue(@Param('venueId') venueId: string) {
    const count = await this.repo.count();
    if (count === 0) {
        await this.repo.save({ title: 'Nite Shot', priceNite: 50, venueId: 1 });
        await this.repo.save({ title: 'VIP Access', priceNite: 500, venueId: 1 });
    }
    return this.repo.find({ where: { venueId: Number(venueId) } });
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([MarketItem])],
  controllers: [MarketController],
})
export class MarketModule {}
EOF

# --- BACKEND: Feed Module ---
cat << 'EOF' > "$BACKEND_DIR/src/modules/feed/feed.module.ts"
import { Module, Controller, Get } from '@nestjs/common';

@Controller('feed')
export class FeedController {
  @Get()
  getFeed() {
    return [
      { id: 1, type: 'news', title: 'Welcome to NiteOS v7', body: 'System operational.' },
      { id: 2, type: 'event', title: 'Friday Night', body: 'Double XP enabled.' }
    ];
  }
}

@Module({
  controllers: [FeedController],
})
export class FeedModule {}
EOF

echo ">>> Writing Frontend Files..."

# --- FRONTEND: package.json ---
cat << 'EOF' > "$FRONTEND_DIR/package.json"
{
  "name": "nite-frontend",
  "version": "7.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.3.4",
    "vue-router": "^4.2.4",
    "axios": "^1.4.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^4.2.3",
    "vite": "^4.3.9"
  }
}
EOF

# --- FRONTEND: vite.config.js ---
cat << 'EOF' > "$FRONTEND_DIR/vite.config.js"
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': 'http://localhost:3000'
    }
  }
})
EOF

# --- FRONTEND: index.html ---
cat << 'EOF' > "$FRONTEND_DIR/index.html"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>NiteOS v7</title>
    <style>
      body { background: #111; color: #fff; font-family: sans-serif; margin: 0; }
      nav { background: #222; padding: 1rem; display: flex; gap: 1rem; }
      nav a { color: #aaa; text-decoration: none; font-weight: bold; }
      nav a.router-link-active { color: #fff; }
      main { padding: 1rem; }
      .card { background: #1a1a1a; padding: 1rem; margin-bottom: 1rem; border-radius: 8px; border: 1px solid #333; }
      h1 { color: #8a2be2; }
    </style>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
EOF

# --- FRONTEND: main.js ---
cat << 'EOF' > "$FRONTEND_DIR/src/main.js"
import { createApp } from 'vue'
import App from './App.vue'
import router from './router'

createApp(App).use(router).mount('#app')
EOF

# --- FRONTEND: router ---
cat << 'EOF' > "$FRONTEND_DIR/src/router/index.js"
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
EOF

# --- FRONTEND: App.vue ---
cat << 'EOF' > "$FRONTEND_DIR/src/App.vue"
<template>
  <div>
    <nav>
      <router-link to="/">Feed</router-link>
      <router-link to="/market">Market</router-link>
      <router-link to="/profile">Profile</router-link>
    </nav>
    <main>
      <router-view></router-view>
    </main>
  </div>
</template>
EOF

# --- FRONTEND: Views ---
cat << 'EOF' > "$FRONTEND_DIR/src/views/Feed.vue"
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
EOF

cat << 'EOF' > "$FRONTEND_DIR/src/views/Market.vue"
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
EOF

cat << 'EOF' > "$FRONTEND_DIR/src/views/Profile.vue"
<template>
  <h1>Profile</h1>
  <div v-if="user" class="card">
    <h2>{{ user.externalId }}</h2>
    <p>Role: {{ user.role }}</p>
    <p>Balance: {{ user.niteBalance }} NITE</p>
    <p>XP: {{ user.xp }} (Lvl {{ user.level }})</p>
  </div>
  <button @click="createDemo">Initialize Demo User</button>
</template>
<script>
import axios from 'axios'
export default {
  data() { return { user: null } },
  methods: {
    async createDemo() { const res = await axios.post('/api/users/demo'); this.user = res.data; }
  },
  async mounted() { await this.createDemo(); }
}
</script>
EOF

# --- NGINX CONFIG ---
cat << 'EOF' > "$APP_DIR/infra/nginx/os.peoplewelike.club.conf"
server {
    listen 80;
    server_name os.peoplewelike.club _;

    root /opt/nite-os-v7/frontend/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# --- INSTALLATION STEPS ---
echo ">>> [Install] Checking dependencies..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    apt-get install -y nodejs
fi
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
fi
apt-get install -y postgresql postgresql-contrib redis-server nginx

echo ">>> [Database] Resetting DB..."
sudo -u postgres psql -c "CREATE USER nite WITH PASSWORD 'nitepassword';" || true
sudo -u postgres psql -c "CREATE DATABASE nite_os OWNER nite;" || true
sudo -u postgres psql -d nite_os -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO nite;"

echo ">>> [Backend] Installing & Building..."
cd $BACKEND_DIR
npm install
npm run build

echo ">>> [Frontend] Installing & Building..."
cd $FRONTEND_DIR
npm install
npm run build

echo ">>> [Nginx] Configuring..."
cp "$APP_DIR/infra/nginx/os.peoplewelike.club.conf" /etc/nginx/sites-available/os.peoplewelike.club.conf
ln -sf /etc/nginx/sites-available/os.peoplewelike.club.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo ">>> [PM2] Starting Backend..."
pm2 delete nite-backend || true
cd $BACKEND_DIR
pm2 start dist/main.js --name nite-backend
pm2 save

echo ">>> DONE! NiteOS v7 is deployed."
echo "    Frontend: http://os.peoplewelike.club"
echo "    Backend Health: curl http://localhost:3000/api/feed"
