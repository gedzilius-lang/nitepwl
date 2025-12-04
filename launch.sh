#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[launch.sh] ERROR: run this script as root (sudo bash launch.sh)"
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[launch.sh] Base directory: $DIR"

export DEBIAN_FRONTEND=noninteractive

echo "[launch.sh] Updating apt cache..."
apt-get update -y

# --- Core packages (git, curl, build-essential, nginx, dbs) ---
echo "[launch.sh] Installing system packages (git, curl, build-essential, nginx, Postgres, Redis, Mongo)..."
apt-get install -y git curl build-essential nginx redis-server postgresql postgresql-contrib

# Try basic Mongo if available (package name differs per distro; ignore failure)
if ! command -v mongod >/dev/null 2>&1; then
  echo "[launch.sh] Attempting to install MongoDB (may fail silently on some distros)..."
  apt-get install -y mongodb || true
fi

# --- Node + npm + pm2 ---
if ! command -v node >/dev/null 2>&1; then
  echo "[launch.sh] Installing Node.js (via Nodesource 20.x)..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
else
  echo "[launch.sh] Node.js already installed: $(node -v)"
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "[launch.sh] ERROR: npm is not available even after Node install."
  exit 1
fi

if ! command -v pm2 >/dev/null 2>&1; then
  echo "[launch.sh] Installing pm2 globally..."
  npm install -g pm2
else
  echo "[launch.sh] pm2 already installed: $(pm2 -v)"
fi

# --- Postgres bootstrap (user + db) without interactive password prompt ---
echo "[launch.sh] Initialising Postgres role + database..."
PG_DB_NAME="nite_os"
PG_ROLE_NAME="nite"
PG_ROLE_PASS="nitepassword"

# If PG_SUPER_PASS is set, use password auth non-interactively
if [ -n "$PG_SUPER_PASS" ]; then
  echo "[launch.sh] Using PG_SUPER_PASS for postgres superuser auth (no prompt)."
  PGPASSWORD="$PG_SUPER_PASS" psql -h localhost -U postgres <<EOF || true
DO
\$do\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$PG_ROLE_NAME') THEN
    CREATE ROLE $PG_ROLE_NAME LOGIN PASSWORD '$PG_ROLE_PASS';
  END IF;
END
\$do\$;

DO
\$do\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$PG_DB_NAME') THEN
    CREATE DATABASE $PG_DB_NAME OWNER $PG_ROLE_NAME;
  END IF;
END
\$do\$;
EOF

# Otherwise try classic sudo -u postgres (works on default installs that don't require a password)
else
  echo "[launch.sh] No PG_SUPER_PASS set, trying sudo -u postgres psql (may fail if postgres requires a password)..."
  sudo -u postgres psql <<EOF || true
DO
\$do\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$PG_ROLE_NAME') THEN
    CREATE ROLE $PG_ROLE_NAME LOGIN PASSWORD '$PG_ROLE_PASS';
  END IF;
END
\$do\$;

DO
\$do\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$PG_DB_NAME') THEN
    CREATE DATABASE $PG_DB_NAME OWNER $PG_ROLE_NAME;
  END IF;
END
\$do\$;
EOF
fi

# --- Backend build + pm2 ---
echo "[launch.sh] Installing backend dependencies..."
cd "$DIR/backend"
npm install

echo "[launch.sh] Building backend..."
npm run build

echo "[launch.sh] Restarting backend with pm2..."
pm2 delete nite-backend >/dev/null 2>&1 || true
pm2 start dist/main.js --name nite-backend
pm2 save

# --- Frontend build ---
echo "[launch.sh] Installing frontend dependencies..."
cd "$DIR/frontend"
npm install

echo "[launch.sh] Building frontend..."
npm run build

# --- Nginx production config ---
NGINX_CONF_PATH="/etc/nginx/sites-available/nite-os.conf"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled/nite-os.conf"
FRONT_DIST="$DIR/frontend/dist"

echo "[launch.sh] Writing Nginx config to $NGINX_CONF_PATH..."
cat > "$NGINX_CONF_PATH" <<NGINXCONF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    # Frontend SPA
    root $FRONT_DIST;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        try_files \$uri /index.html;
    }
}
NGINXCONF

if [ ! -L "$NGINX_ENABLED_PATH" ]; then
  ln -sf "$NGINX_CONF_PATH" "$NGINX_ENABLED_PATH"
fi

echo "[launch.sh] Testing Nginx config..."
nginx -t

echo "[launch.sh] Enabling + restarting Nginx..."
systemctl enable nginx
systemctl restart nginx

# --- Install 'nite' CLI ---
echo "[launch.sh] Installing 'nite' CLI to /usr/local/bin/nite..."
install -m 755 "$DIR/nite" /usr/local/bin/nite

echo "[launch.sh] DONE."
echo
echo "Backend:   http://<server-ip-or-domain>/api/market"
echo "Frontend:  http://<server-ip-or-domain>/"
echo
