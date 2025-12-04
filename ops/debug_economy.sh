#!/usr/bin/env bash

# 1. Get the Demo User ID
USER_ID=$(sudo -u postgres psql -d nite_os -t -c "SELECT id FROM users WHERE \"externalId\"='demo_admin';" | tr -d ' ' | tr -d '\n')

echo ">>> Debugging Economy for User: $USER_ID"

# 2. Check Balance BEFORE
BALANCE_BEFORE=$(sudo -u postgres psql -d nite_os -t -c "SELECT \"niteBalance\" FROM users WHERE id='$USER_ID';" | tr -d ' ')
echo "💰 Balance BEFORE: $BALANCE_BEFORE NITE"

# 3. Buy a Beer (Spend 50) via API
echo ">>> Buying Beer (50 NITE)..."
curl -s -X POST -H "Content-Type: application/json" \
     -d "{\"userId\": \"$USER_ID\", \"amount\": 50, \"items\": [{\"name\": \"Debug Beer\"}]}" \
     http://localhost:3000/api/pos/1/checkout > /dev/null

# 4. Check Balance AFTER
BALANCE_AFTER=$(sudo -u postgres psql -d nite_os -t -c "SELECT \"niteBalance\" FROM users WHERE id='$USER_ID';" | tr -d ' ')
echo "💰 Balance AFTER:  $BALANCE_AFTER NITE"

# 5. Show Last Transaction
echo ">>> Last Transaction Log:"
sudo -u postgres psql -d nite_os -c "SELECT type, amount, \"createdAt\" FROM nitecoin_transactions ORDER BY \"createdAt\" DESC LIMIT 1;"
