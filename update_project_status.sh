#!/bin/bash
set -e

PROJECT_DIR="$HOME/nitepwl"
README_FILE="$PROJECT_DIR/README.md"

echo ">>> [Documentation] Updating README.md with full project status..."

cat << 'EOF' > "$README_FILE"
# �� NiteOS v7 - Modular Monolith Platform

**Status:** Production Ready (v7.0.0)  
**Live URL:** [https://os.peoplewelike.club](https://os.peoplewelike.club)  
**Admin:** [https://os.peoplewelike.club/admin](https://os.peoplewelike.club/admin)  

## 📌 Project Overview
NiteOS v7 is a consolidated "Modular Monolith" designed to replace the legacy microservices architecture. It powers a venue management system with an integrated economy, live radio streaming, and user gamification.

---

## 🏗️ Architecture

### **1. Backend (NestJS)**
* **Location:** `/backend`
* **Port:** `3000`
* **Database:** PostgreSQL (TypeORM)
* **Modules:**
    * `Users`: Profile management, XP, Leveling.
    * `Nitecoin`: Internal economy ledger (Earn/Spend).
    * `POS`: Point-of-Sale logic for venues to charge users.
    * `Market`: Item listings and purchasing logic.
    * `Feed`: Dynamic news and event system.
    * `Radio`: Metadata handling for the streaming engine.

### **2. Frontend (Vue 3 + Vite)**
* **Location:** `/frontend`
* **Dev Port:** `5173`
* **Features:**
    * **Radio Player:** "Rock-Solid" logic switching between Live (OBS) and Auto-DJ. Includes Visualizer and PiP.
    * **Profile:** Real-time balance, XP progress bar, transaction history.
    * **Admin Dashboard:** Interface to post news/events to the feed.
    * **Market:** Storefront for purchasing items with Nitecoin.

### **3. Radio Station (Media Engine)**
* **Stack:** Nginx (RTMP Module) + Liquidsoap + FFmpeg.
* **Flow:**
    * **Auto-DJ:** Liquidsoap reads MP3s -> Pipes to FFmpeg -> Pushes to Nginx RTMP.
    * **Live:** OBS pushes to Nginx RTMP (`/live`).
    * **Distribution:** Nginx segments stream into HLS (`.m3u8` + `.ts`) for web playback.
* **Paths:**
    * Music Upload: `/var/www/autodj/music`
    * HLS Output: `/var/www/hls/`
* **Streaming Config:**
    * Server: `rtmp://os.peoplewelike.club/live` (or IP: `31.97.126.86`)
    * Key: `obs`

---

## 🛠️ Operational Guide (God Mode)

### **Development Workflow**
1.  **Start Local Environment:**
    ```bash
    nite dev
    # Starts Docker (Postgres/Redis), Backend (Watch), and Frontend (Vite)
    ```
2.  **Deploy to Production:**
    ```bash
    git add .
    git commit -m "Your message"
    git push origin main
    # GitHub Action triggers auto-deploy. 
    # If it fails, run 'nite deploy' locally to force it.
    ```

### **Server Management**
* **SSH Access:** `nite ssh` (Connects as `nite_dev`)
* **Logs:** `nite logs` (Streams backend logs)
* **Status:** `nite status` (Checks PM2/Nginx/DB)
* **Manual Deploy:** `nite deploy` (Pulls code & rebuilds on server)

### **Disaster Recovery**
* **Database Backups:** Located at `/var/backups/postgres/` (Runs daily at 3 AM).
* **Infrastructure Configs:** Saved in `/ops/configs/` (Nginx, Liquidsoap, Systemd).

---

## ✅ Completed Features (v7 Roadmap)
- [x] **Infrastructure:** VPS setup, Firewall (UFW), SSL (Certbot), Auto-Updates.
- [x] **Economy:** Nitecoin transaction ledger & XP gamification engine.
- [x] **Radio:** Live/Auto-DJ switching, Metadata JSON API, Visualizer.
- [x] **UI/UX:** "Neon" & "Classic" designs implemented, Mobile responsive.
- [x] **DevOps:** CI/CD Pipeline via GitHub Actions.

## 🔭 Future Aims
1.  **Authentication:** Replace "Demo User" with real JWT Auth (Login/Register).
2.  **Media Uploads:** Allow Admins to upload images for Feed/Market items (S3 or Local).
3.  **Payment Gateway:** Integrate Stripe/PayPal to buy Nitecoin.
4.  **Chat:** Connect the Socket.io frontend to a real NestJS Gateway.

---
*Documentation generated automatically by NiteOS Ops.*
EOF

# Git Push
echo ">>> [Git] Adding new documentation..."
cd "$PROJECT_DIR"
git add README.md

echo ">>> [Git] Committing..."
git commit -m "Docs: Update README with full v7 status and architecture" || echo "Nothing to commit"

echo ">>> [Git] Pushing to GitHub..."
git push origin main

echo "--------------------------------------------------------"
echo "✅ BACKUP COMPLETE."
echo "👉 View your project status: https://github.com/gedzilius-lang/nitepwl"
echo "--------------------------------------------------------"
