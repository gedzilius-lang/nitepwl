#!/bin/bash
set -e

echo ">>> [1/2] Syncing to GitHub..."
cd ~/nitepwl

# Stage all changes (including the roadmap files we just created)
git add .

# Commit only if there are changes
if ! git diff-index --quiet HEAD --; then
    git commit -m "Release: NiteOS v7.1 (Auth + Economy + Analytics)"
    git push origin main
    echo "    Code pushed to GitHub."
else
    echo "    No local changes to push. GitHub is up to date."
fi

echo ">>> [2/2] Deploying to Production..."
# Triggers the remote update and restart
nite deploy

echo "--------------------------------------------------------"
echo "✅ PRODUCTION SYNC COMPLETE."
echo "👉 API: https://os.peoplewelike.club/api/feed"
echo "--------------------------------------------------------"
