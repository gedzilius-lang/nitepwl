#!/usr/bin/env bash
set -e

# Configuration
VPS_USER="nite_dev"
VPS_HOST="srv925512.hstgr.cloud"

echo ">>> Upgrading local 'nite' CLI to God Mode..."

cat << EOF > "$HOME/bin/nite"
#!/bin/bash
PROJECT_ROOT="\$HOME/nitepwl"
VPS_TARGET="$VPS_USER@$VPS_HOST"

case "\$1" in
  # --- LOCAL COMMANDS ---
  dev)
    echo ">>> [Local] Starting Docker Environment..."
    cd "\$PROJECT_ROOT" && docker compose up -d
    echo "✅ Databases UP."
    echo "   Backend: cd backend && npm run start:dev"
    echo "   Frontend: cd frontend && npm run dev"
    ;;
  stop)
    echo ">>> [Local] Stopping Docker..."
    cd "\$PROJECT_ROOT" && docker compose down
    ;;

  # --- REMOTE COMMANDS ---
  ssh)
    echo ">>> [Remote] Connecting to VPS..."
    ssh -t \$VPS_TARGET
    ;;
  deploy)
    echo ">>> [Remote] Triggering Manual Deployment..."
    # We use 'sudo' because the PM2 process is owned by root
    ssh -t \$VPS_TARGET "sudo nite deploy"
    ;;
  logs)
    echo ">>> [Remote] Streaming Logs..."
    ssh -t \$VPS_TARGET "sudo nite logs"
    ;;
  status)
    echo ">>> [Remote] Checking Status..."
    ssh -t \$VPS_TARGET "sudo nite status"
    ;;
  *)
    echo "NiteOS God CLI"
    echo "--------------------------------"
    echo "Local:  nite dev | nite stop"
    echo "Remote: nite ssh | nite deploy | nite logs | nite status"
    echo "--------------------------------"
    ;;
esac
EOF
chmod +x "$HOME/bin/nite"

echo "✅ Upgrade Complete!"
echo "   Try 'nite deploy' now."
