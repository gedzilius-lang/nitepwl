#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
FILE_TO_EDIT="$APP_DIR/backend/src/main.ts"

echo ">>> [1/3] Simulating a code change..."
# Ensure we are in the right directory
cd "$APP_DIR"

# Generate a unique message with timestamp
NEW_MSG="NiteOS v7 Backend - Auto-Deployed at $(date +'%H:%M:%S')"

# Use sed to replace the console.log line in main.ts
# Matches: console.log('...'); and replaces with new message
sed -i "s|console.log('.*');|console.log('$NEW_MSG');|" "$FILE_TO_EDIT"

echo "    Modified: backend/src/main.ts"
echo "    New Log Message: $NEW_MSG"

echo ">>> [2/3] Committing and Pushing to GitHub..."
git add backend/src/main.ts
git commit -m "CI/CD Test: Update backend log message"
git push origin main

echo "--------------------------------------------------------"
echo ">>> [3/3] Change Pushed Successfully!"
echo ">>> NOW DO THIS:"
echo "    1. Open your GitHub Repo in a browser."
echo "    2. Click the 'Actions' tab."
echo "    3. Watch the 'Deploy to VPS' workflow turn GREEN."
echo "    4. Wait ~2 minutes, then check logs on this server:"
echo "       pm2 logs nite-backend --lines 20"
echo "--------------------------------------------------------"
