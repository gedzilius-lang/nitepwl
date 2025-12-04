#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"

echo ">>> [Fix] Waiting for apt lock to release (system updates running)..."
# Loop until the lock file is gone
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "    ...Waiting for background updates to finish..."
    sleep 5
done

echo ">>> [Fix] Installing Glances..."
apt-get install -y glances

echo ">>> [Fix] Pushing new Ops scripts to GitHub..."
cd "$APP_DIR"
# Ensure we capture the backup script created in the previous step
git add ops/run_backup.sh
git commit -m "Ops: Add automated DB backups and monitoring" || echo "Nothing to commit"
git push origin main

echo "--------------------------------------------------------"
echo ">>> DONE! Glances installed & Code backed up."
echo "--------------------------------------------------------"
