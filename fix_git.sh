#!/usr/bin/env bash
set -e

APP_DIR="/opt/nite-os-v7"
# The URL you provided
NEW_REPO_URL="https://github.com/gedzilius-lang/nitepwl.git"

echo ">>> Fixing Git Remote for $APP_DIR..."
cd $APP_DIR

# 1. Reset remote origin to the correct HTTPS URL
if git remote | grep -q "origin"; then
    git remote remove origin
fi
git remote add origin $NEW_REPO_URL

# 2. Ensure we are on 'main' branch
git branch -M main

echo ">>> Verifying Remote URL..."
git remote -v

echo ">>> Ready. Run the push command below."
