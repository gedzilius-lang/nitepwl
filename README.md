# NiteOS – Core Venue OS & Nitecoin Economy

**Status:** v0.1 – Core architecture online, features under active development
**Live:** [https://os.peoplewelike.club](https://os.peoplewelike.club)

NiteOS is a compact “OS for nightlife venues”. It runs:

* User identities (NiteTap / bracelets / cards)
* Venue profiles
* An internal currency (Nitecoin)
* POS & Market logic (what can be bought, at which price)
* Feed & basic analytics

There is **no media stack** inside NiteOS. Any media/live content is handled by separate infrastructure and — if ever needed — only embedded as a simple external link or iframe on the frontend.

---

## 1. Architecture Overview

### 1.1 Backend (NestJS Monolith)

* **Location:** `/backend`
* **Port:** `3000` (proxied behind nginx)
* **Database:** PostgreSQL via TypeORM
* **Modules:**
    * **Users**: NiteOS users, NiteTap linkage, XP, level, Nitecoin balance, flags.
    * **Venues**: Venue registry: slug, title, city, status, config.
    * **Nitecoin**: Ledger for earning/spending Nitecoin, transaction records per user/venue.
    * **POS**: Checkout logic: what was bought, at which price, by which user/staff/venue.
    * **Market**: Item catalog per venue (CHF price, Nitecoin price, active flags).
    * **Feed**: Simple posts & announcements shown in the app.
    * **Auth**: JWT-based authentication and role handling (user, staff, venue admin, Nitecore admin).
    * **Analytics**: Event logs & metrics (stored in Mongo).

The backend is intentionally monolithic. If we ever need microservices, they will be split out of these modules later.

---

### 1.2 Frontend (Vue 3 + Vite SPA)

* **Location:** `/frontend`
* **Dev port:** `5173`
* Deployed as a static SPA behind nginx.

Screens:

* **Feed** – `/`
    * Displays feed items from `/api/feed`.
* **Market** – `/market`
    * Venue selector.
    * Item list with CHF + Nitecoin prices from `/api/market/:venueId/items`.
* **Profile** – `/profile`
    * Shows “current user”:
        * NiteTap ID (if linked)
        * Nitecoin balance
        * XP & level
        * Basic recent activity.
* **(Planned) Admin** – `/admin`
    * Manage venues, items, staff, and basic configuration.

No media player UI is present in this project.

---

### 1.3 Databases & Infra

* **PostgreSQL** (`nite_os`)
    * Core schema: users, venues, market_items, nitecoin_transactions, pos_transactions, feed_items.
* **Redis**
    * Sessions, rate limiting, simple counters (active users, etc.).
* **MongoDB**
    * Event logs and analytics snapshots.

* **nginx**
    * `https://os.peoplewelike.club/` → frontend SPA
    * `https://os.peoplewelike.club/api/*` → NestJS backend on `localhost:3000`

No streaming-related locations or ports are configured on this machine.

---

## 2. Operations

### 2.1 One-command bootstrap

On a fresh Ubuntu VPS:

```bash
git clone git@github.com:gedzilius-lang/nitepwl.git /opt/nite-os
cd /opt/nite-os
bash launch.sh
