#!/usr/bin/env bash
set -e

# Example server-side deploy script.
# Intended to be called via SSH from a CI pipeline.
REPO_DIR="/opt/nite-os-v5"

echo "[deploy.sh] Using repo dir: $REPO_DIR"

cd "$REPO_DIR"

echo "[deploy.sh] Pulling latest git changes (if this is a git repo)..."
if [ -d .git ]; then
  git pull --rebase || true
fi

echo "[deploy.sh] Building backend..."
cd backend
npm install
npm run build

echo "[deploy.sh] Restarting backend with pm2..."
pm2 delete nite-backend >/dev/null 2>&1 || true
pm2 start dist/main.js --name nite-backend
pm2 save

echo "[deploy.sh] Building frontend..."
cd "$REPO_DIR/frontend"
npm install
npm run build

echo "[deploy.sh] Reloading Nginx..."
nginx -t
systemctl reload nginx

echo "[deploy.sh] Deploy complete."
