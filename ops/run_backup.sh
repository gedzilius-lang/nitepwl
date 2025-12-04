#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="/var/backups/postgres/nite_os_$TIMESTAMP.sql.gz"
# Dump DB, compress, save
pg_dump -U nite nite_os | gzip > "$BACKUP_PATH"
# Delete backups older than 7 days
find /var/backups/postgres -type f -name "*.sql.gz" -mtime +7 -delete
echo "Backup created: $BACKUP_PATH"
