#!/bin/bash
set -e

SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"
APP_PATH="/opt/nite-os-v7"
API_URL="https://os.peoplewelike.club/api/users/demo"

echo ">>> [API RESTORE] Forcing clean build and application restart..."

cat << 'EOF' > /tmp/app_restore.sh
#!/bin/bash
set -e

APP_PATH="/opt/nite-os-v7"
cd "$APP_PATH"

# 1. CLEANUP (Remove old build/cache files)
echo ">>> [1/3] Clearing build cache and old node modules..."
rm -rf backend/dist
rm -rf frontend/dist

# 2. REBUILD (Force install and clean build)
echo ">>> [2/3] Rebuilding both Backend and Frontend..."
npm install --prefix backend
npm run build --prefix backend

npm install --prefix frontend
npm run build --prefix frontend

# 3. RESTART PM2 (Must be done as root to manage the running service)
echo ">>> [3/3] Restarting Backend service..."
systemctl restart nginx # Ensure Nginx is not serving cached errors
sudo pm2 restart nite-backend

echo ">>> Application state refresh complete."
EOF

# Execute the script on the VPS
scp /tmp/app_restore.sh "$SERVER_USER@$SERVER_HOST":/tmp/
ssh -t "$SERVER_USER@$SERVER_HOST" "sudo bash /tmp/app_restore.sh"
rm /tmp/app_restore.sh
