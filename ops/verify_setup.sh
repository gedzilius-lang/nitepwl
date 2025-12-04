#!/usr/bin/env bash
echo ">>> 1. Checking API Health..."
RESPONSE=$(curl -s http://localhost:3000/api/feed)
echo "Feed Response: $RESPONSE"

echo -e "\n>>> 2. Checking Database Tables..."
# This queries the Postgres system catalog to list table names in the public schema
sudo -u postgres psql -d nite_os -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"

echo -e "\n>>> 3. Creating a Demo User (via API)..."
# This triggers the backend to write to the DB
curl -X POST http://localhost:3000/api/users/demo
echo -e "\n"
