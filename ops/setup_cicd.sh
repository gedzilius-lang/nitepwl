#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
mkdir -p "$APP_DIR/.github/workflows"
mkdir -p "$APP_DIR/scripts"

echo ">>> [1/3] Creating Server Deployment Script..."
# This is the script GitHub will trigger via SSH
cat << 'EOF' > "$APP_DIR/scripts/trigger-deploy.sh"
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
EOF
chmod +x "$APP_DIR/scripts/trigger-deploy.sh"

echo ">>> [2/3] Creating GitHub Workflow..."
# This tells GitHub what to do when you push code
cat << 'EOF' > "$APP_DIR/.github/workflows/deploy.yml"
name: Deploy to VPS

on:
  push:
    branches: [ "main" ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: bash /opt/nite-os-v7/scripts/trigger-deploy.sh
EOF

echo ">>> [3/3] Pushing CI/CD configuration to GitHub..."
cd "$APP_DIR"
git add .
git commit -m "Add CI/CD pipeline scripts"
git push origin main

echo ">>> Done! Deployment scripts are on GitHub."
echo ">>> NOW: You must go to your GitHub Repo Settings -> Secrets and add:"
echo "    1. VPS_HOST (Your IP)"
echo "    2. VPS_USER (root)"
echo "    3. VPS_SSH_KEY (Your private SSH key content)"
