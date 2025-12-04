# Nite OS – Ultra-Simple Monolith Skeleton (ZIP v5)

This repo is a **clean monolith skeleton** for Nite OS, designed around your 6-part system:

1. One VPS, one repo, one command: `bash launch.sh`
2. Three databases: Postgres, Mongo, Redis
3. One NestJS backend with modules:
   - users, venues, nitecoin, market, feed, pos, auth, analytics
4. One Vue + Vite SPA frontend:
   - Feed, Market, Profile, Radio (iframe)
5. Local Docker sandbox:
   - `docker compose up`
6. CI/CD stub for push → deploy

## Quick Start (Production-ish on VPS)

```bash
# upload nite-os-v5.zip to /opt
cd /opt
unzip nite-os-v5.zip
cd nite-os-v5

# run as root
bash launch.sh
```

What `launch.sh` does:

- Installs Node, npm, pm2 (if missing)
- Installs Postgres, Mongo, Redis, Nginx (if missing)
- Creates Postgres user+DB `nite` / `nite_os`
- Installs backend dependencies, builds, starts with pm2 as `nite-backend`
- Installs frontend deps, builds SPA
- Writes `/etc/nginx/sites-available/nite-os.conf` pointing to:
  - backend: `http://127.0.0.1:3000/api`
  - frontend: static files from `frontend/dist`
- Enables + restarts Nginx
- Installs `nite` CLI into `/usr/local/bin/nite`
- Saves pm2 state (`pm2 save`)

After that:

- Backend API: `http://your-domain/api/*` (e.g. `/api/market`, `/api/feed`)
- Frontend SPA: `http://your-domain/`

## Quick Start (Local Dev with Docker)

Requirements: Docker + docker compose.

```bash
cd nite-os-v5
docker compose up --build
```

- Nginx: http://localhost
- Frontend dev server behind Nginx (`/`)
- Backend dev server behind Nginx (`/api/*`)
- Postgres, Mongo, Redis in containers

Or use the helper CLI:

```bash
./nite dev         # docker compose up
./nite db status   # docker compose ps
./nite db reset    # docker compose down -v + clean DB containers
```

## Backend

- NestJS-like monolith (no Nest CLI required at runtime)
- Located in `backend/`
- Global prefix: `/api`
- Modules:
  - `/api/users`
  - `/api/venues`
  - `/api/nitecoin`
  - `/api/market`
  - `/api/feed`
  - `/api/pos`
  - `/api/auth`
  - `/api/analytics`

Each controller returns a simple JSON stub so you can verify wiring.

Build & run manually:

```bash
cd backend
npm install
npm run build
npm start
```

## Frontend

- Vue 3 + Vite SPA in `frontend/`
- Simple router with:
  - `/` → Feed
  - `/market`
  - `/profile`
  - `/radio` (iframe for your radio player)

Build & preview manually:

```bash
cd frontend
npm install
npm run dev      # local dev
npm run build
npm run preview
```

## CI/CD

- `.github/workflows/deploy.yml` – GitHub Actions stub
- `infra/ci-cd/deploy.sh` – server-side deploy script example

Wire it to your existing repo later by:

```bash
git init
git remote add origin <your-remote-url>
git add .
git commit -m "Nite OS monolith skeleton v5"
git push -u origin main
```

You can then adapt the scripts to match your real SSH host, paths, and environment.
