#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
BACKEND_SRC="$PROJECT_DIR/backend/src"
FRONTEND_SRC="$PROJECT_DIR/frontend/src"
SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> NiteOS HARD RESET: Purging all Media/Radio Components"
echo ">>> Executing script on $SERVER_HOST as $SERVER_USER"

# ==========================================
# PART A: Remote Media Cleanup on VPS
# ==========================================
cat << 'EOF' > /tmp/remote_media_purge.sh
#!/bin/bash
set -e

echo ">>> Stopping and disabling all media services..."
systemctl stop liquidsoap-radio ffmpeg-autodj ffmpeg-live || true
systemctl disable liquidsoap-radio ffmpeg-autodj ffmpeg-live || true

echo ">>> Deleting media systemd unit files..."
rm -f /etc/systemd/system/liquidsoap-radio.service
rm -f /etc/systemd/system/ffmpeg-autodj.service
rm -f /etc/systemd/system/ffmpeg-live.service
rm -f /etc/liquidsoap/autodj.liq

echo ">>> Removing media directories and configs..."
rm -rf /var/www/hls
rm -rf /var/www/autodj
rm -f /var/www/html/now_playing.json
rm -f /var/www/html/radio_status.json

echo ">>> Purging old project directories (v5/v6/v7 backups)..."
find /opt/ -maxdepth 1 -type d -name "nite-os-v*" -exec rm -rf {} \; || true
find /opt/ -maxdepth 1 -type d -name "nite-os_backup_*" -exec rm -rf {} \; || true

echo ">>> Re-cloning fresh Git repo to /opt/nite-os (new home)..."
rm -rf /opt/nite-os
mkdir -p /opt/nite-os
cd /opt/nite-os
git init
git remote add origin git@github.com:gedzilius-lang/nitepwl.git
git fetch --all
git reset --hard origin/main
chown -R nite_dev:nite_dev /opt/nite-os
chown -R root:nite_dev /opt/nite-os-v7 || true # Preserve CI/CD dir structure until new deploy.sh is made

echo ">>> Deleting RTMP/HLS configuration from Nginx core..."
# Overwrite nginx.conf without the 'rtmp' block
cat << 'NGINX_CLEAN' > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events { worker_connections 1024; }

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINX_CLEAN

echo ">>> Testing Nginx configuration and restarting..."
nginx -t && systemctl restart nginx
EOF

# Execute remote purge script
scp /tmp/remote_media_purge.sh "$SERVER_USER@$SERVER_HOST":/tmp/
ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash /tmp/remote_media_purge.sh"
rm /tmp/remote_media_purge.sh

# ==========================================
# PART B: Local Codebase Purge
# ==========================================

echo ">>> [Local] Removing media modules and files..."

# 1. Backend Code Cleanup
rm -rf "$BACKEND_SRC/modules/radio" # Remove dedicated radio module folder
rm -f "$BACKEND_SRC/modules/liquidsoap-metadata"
rm -f "$BACKEND_SRC/modules/stream-status"

# 2. Frontend Code Cleanup
rm -f "$FRONTEND_SRC/views/Radio.vue" # Remove dedicated Radio page
rm -f "$FRONTEND_SRC/views/RadioEmbed.vue"

# 3. Infra / Ops Cleanup
rm -f "$PROJECT_DIR/fix_autodj.sh"
rm -f "$PROJECT_DIR/fix_liquidsoap.sh"
rm -f "$PROJECT_DIR/fix_nginx_hls.sh"
rm -f "$PROJECT_DIR/fix_radio_final.sh"
rm -f "$PROJECT_DIR/fix_radio_loading.sh"
rm -f "$PROJECT_DIR/fix_radio_manual.sh"
rm -f "$PROJECT_DIR/fix_radio_manual_controls.sh"
rm -f "$PROJECT_DIR/fix_radio_playback.sh"
rm -f "$PROJECT_DIR/fix_radio_player.sh"
rm -f "$PROJECT_DIR/install_radio.sh"
rm -f "$PROJECT_DIR/restore_final_system.sh"
rm -f "$PROJECT_DIR/restore_legacy_radio.sh"
rm -f "$PROJECT_DIR/restore_radio_backend.sh"
rm -f "$PROJECT_DIR/setup_fresh_radio.sh"
rm -f "$PROJECT_DIR/upgrade_radio_ux.sh"
rm -f "$PROJECT_DIR/ops/configs/autodj.liq"
rm -f "$PROJECT_DIR/ops/configs/liquidsoap-radio.service"
rm -f "$PROJECT_DIR/ops/configs/nginx.conf"

# 4. Update Core Modules to remove imports (App.vue, Router, AppModule)
echo ">>> [Local] Updating Core Modules..."

# Update App Module (Ensure no rogue imports)
# Note: The current app.module.ts doesn't have media imports, but this is a defensive check.
cat << 'EOF' > "$BACKEND_SRC/app.module.ts"
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

# Update Router (Remove /radio route if present)
# The latest fully-provided router from `implement_admin.sh` does not include radio. We ensure the *clean* version is used.
cat << 'EOF' > "$FRONTEND_SRC/router/index.js"
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

# Update App.vue (Remove Radio link if present)
# The latest fully-provided App.vue from `implement_admin.sh` does not include radio. We ensure the *clean* version is used.
cat << 'EOF' > "$FRONTEND_SRC/App.vue"
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
.admin-link { color: #ff4444 !important; margin-left: auto; font-weight: bold; }
</style>
EOF

# 5. Commit Changes
echo ">>> [Local] Committing and pushing the hard reset..."
cd "$PROJECT_DIR"
git add .
git commit -m "Hard Reset: Purge all media/radio stack. NiteOS is now core economy only." || echo "Nothing new to commit."
git push origin main

echo "--------------------------------------------------------"
echo "✅ HARD RESET SCRIPT COMPLETE."
echo "   The remote server has been scrubbed of media config."
echo "   The local git repo has been scrubbed and pushed."
echo "👉 The next GitHub Action will deploy the clean code."
echo "--------------------------------------------------------"
