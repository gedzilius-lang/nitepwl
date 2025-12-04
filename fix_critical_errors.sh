#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
FRONTEND_FILE="$PROJECT_DIR/frontend/src/views/Radio.vue"
SERVER_USER="nite_dev"
SERVER_HOST="srv925512.hstgr.cloud"

echo ">>> [CRITICAL FIX] Fixing Frontend Syntax and Diagnosing CI/CD..."

# 1. FIX SYNTAX ERROR in Radio.vue (The backslash escaping issue)
echo ">>> [1/3] Fixing VUE Syntax Error in Radio.vue..."
# We use sed to replace the broken template literal with safer string concatenation
sed -i "s|this.trackTitle = meta.title ? \\\`\\\${meta.artist} - \\\${meta.title}\\\` : \"NiteOS Radio\";|this.trackTitle = meta.title ? meta.artist + ' - ' + meta.title : \"NiteOS Radio\";|" "$FRONTEND_FILE"

# 2. PUSH CLEAN CODE
echo ">>> [2/3] Committing and Pushing Clean Code..."
cd "$PROJECT_DIR"
git add "$FRONTEND_FILE"
git commit -m "Fix: Corrected template literal syntax error in Radio.vue" || echo "Nothing to commit"
git push origin main

# 3. RUN REMOTE DIAGNOSTIC (Find out why CI is failing)
echo ">>> [3/3] Running remote CI/CD diagnostics..."
ssh -t "$SERVER_USER@$SERVER_HOST" "
    # Check services and disk output first
    sudo systemctl status liquidsoap-radio --no-pager
    sudo ls -lh /var/www/hls/autodj/
    
    # Check Nginx error logs for connection failures from PM2
    echo '--- NGINX ERROR LOGS (PM2 Proxy Errors) ---'
    sudo tail -n 20 /var/log/nginx/error.log
"
