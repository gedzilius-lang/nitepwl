#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
BACKEND_DIR="$APP_DIR/backend"

echo ">>> [Debug] Forcing Manual Update..."

# 1. Ensure the code exists (Check if POS module is present)
if [ ! -d "$BACKEND_DIR/src/modules/pos" ]; then
    echo "ERROR: POS module missing. The previous script didn't finish writing files."
    exit 1
fi

# 2. Rebuild the Backend
echo ">>> [1/3] Building Backend..."
cd "$BACKEND_DIR"
npm install
npm run build

# 3. Restart PM2
echo ">>> [2/3] Restarting Backend Process..."
pm2 restart nite-backend

# 4. Wait for Boot
echo ">>> [3/3] Waiting for NestJS to boot (10s)..."
sleep 10

# 5. Verify
echo ">>> Checking Status..."
pm2 ls
pm2 logs nite-backend --lines 20

echo "--------------------------------------------------------"
echo ">>> RETRYING YOUR CHECKOUT TEST:"
USER_ID=$(sudo -u postgres psql -d nite_os -t -c "SELECT id FROM users WHERE \"externalId\"='demo_admin';" | tr -d ' ')

if [ -z "$USER_ID" ]; then
    echo "Error: Demo user not found. Creating..."
    curl -X POST http://localhost:3000/api/users/demo
    USER_ID=$(sudo -u postgres psql -d nite_os -t -c "SELECT id FROM users WHERE \"externalId\"='demo_admin';" | tr -d ' ')
fi

echo "Spending 50 NITE for User $USER_ID..."
curl -X POST -H "Content-Type: application/json" \
     -d "{\"userId\": \"$USER_ID\", \"amount\": 50, \"items\": [{\"name\": \"Beer\"}]}" \
     http://localhost:3000/api/pos/1/checkout
echo ""
echo "--------------------------------------------------------"
