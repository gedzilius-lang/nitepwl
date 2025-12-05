#!/bin/bash
set -e

echo ">>> [NiteOS Local] Initializing Development Environment..."

# 1. KILL ZOMBIE PROCESSES (Fixes EADDRINUSE errors)
echo ">>> [1/4] Cleaning up ports 3000 and 5173..."
# We use fuser to kill processes on specific TCP ports
if command -v fuser &> /dev/null; then
    fuser -k 3000/tcp > /dev/null 2>&1 || true
    fuser -k 5173/tcp > /dev/null 2>&1 || true
else
    # Fallback if fuser is missing
    lsof -ti:3000 | xargs -r kill -9
    lsof -ti:5173 | xargs -r kill -9
fi
echo "    Ports cleared."

# 2. START DATABASES
echo ">>> [2/4] Starting Docker Databases..."
# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker Desktop for Windows."
    exit 1
fi
docker compose up -d
echo "    Databases are UP."

# 3. INSTALL DEPENDENCIES (Only if missing)
echo ">>> [3/4] Checking Dependencies..."

if [ ! -d "backend/node_modules" ]; then
    echo "    Installing Backend deps..."
    cd backend && npm install && cd ..
fi

if [ ! -d "frontend/node_modules" ]; then
    echo "    Installing Frontend deps..."
    cd frontend && npm install && cd ..
fi

# 4. START EVERYTHING
echo ">>> [4/4] Launching NiteOS (Backend + Frontend)..."
echo "---------------------------------------------------"
echo "👉 Frontend: http://localhost:5173"
echo "👉 Backend:  http://localhost:3000/api"
echo "---------------------------------------------------"
echo "Press CTRL+C to stop everything."
echo ""

# Use npx concurrently to run both in parallel with colored output
# We explicitly prefix the commands to run in the correct folders
npx concurrently \
    -n "BACKEND,FRONTEND" \
    -c "blue,magenta" \
    "npm run start:dev --prefix backend" \
    "npm run dev --prefix frontend"
