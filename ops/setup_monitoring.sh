#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
BACKUP_DIR="/var/backups/postgres"
LOG_RETENTION="7"

echo ">>> [Phase 2.5] Installing Reliability & Monitoring..."

# --- 1. RELIABILITY (Fixing missing backups) ---
echo ">>> [1/5] Configuring PM2 Log Rotation..."
pm2 install pm2-logrotate > /dev/null
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain $LOG_RETENTION
pm2 set pm2-logrotate:rotateInterval '0 0 * * *'
pm2 save

echo ">>> [2/5] Creating Database Backup Script..."
mkdir -p "$BACKUP_DIR"
chown postgres:postgres "$BACKUP_DIR"
mkdir -p "$APP_DIR/ops"

cat << 'EOF' > "$APP_DIR/ops/run_backup.sh"
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="/var/backups/postgres/nite_os_$TIMESTAMP.sql.gz"
# Dump DB, compress, save
pg_dump -U nite nite_os | gzip > "$BACKUP_PATH"
# Delete backups older than 7 days
find /var/backups/postgres -type f -name "*.sql.gz" -mtime +7 -delete
echo "Backup created: $BACKUP_PATH"
EOF
chmod +x "$APP_DIR/ops/run_backup.sh"

echo ">>> [3/5] Scheduling Daily Backup (3 AM)..."
CRON_JOB="0 3 * * * root bash $APP_DIR/ops/run_backup.sh >> /var/log/nite_db_backup.log 2>&1"
if ! grep -q "nite_os_backup" /etc/crontab; then
    echo "$CRON_JOB" >> /etc/crontab
    echo "   Cron job added."
else
    echo "   Cron job already exists."
fi

# --- 2. SECURITY UPDATES ---
echo ">>> [4/5] Enabling Auto-Security Updates..."
apt-get install -y unattended-upgrades > /dev/null
echo 'Unattended-Upgrade::Allowed-Origins { "${distro_id}:${distro_codename}-security"; };' > /etc/apt/apt.conf.d/50unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# --- 3. MONITORING ---
echo ">>> [5/5] Installing Glances (System Monitor)..."
apt-get install -y glances > /dev/null

# --- GIT SYNC ---
echo ">>> Backing up infrastructure code to GitHub..."
cd "$APP_DIR"
git add ops/run_backup.sh
git commit -m "Ops: Add backup script and monitoring" || echo "Nothing to commit"
git push origin main

echo "--------------------------------------------------------"
echo ">>> DONE! System is hardened and monitored."
echo "--------------------------------------------------------"
