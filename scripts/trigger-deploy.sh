#!/bin/bash
set -e

echo ">>> Deployment triggered by GitHub Action..."
cd /opt/nite-os-v7

# 1. Pull latest code
git fetch --all
git reset --hard origin/main

# 2. Install Dependencies
echo ">>> Installing dependencies..."
cd backend && npm install && cd ..
cd frontend && npm install && cd ..

# 3. Build
echo ">>> Building..."
cd backend && npm run build && cd ..
cd frontend && npm run build && cd ..

# 4. Restart Backend
echo ">>> Restarting PM2..."
pm2 restart nite-backend

echo ">>> Deployment Successful!"
