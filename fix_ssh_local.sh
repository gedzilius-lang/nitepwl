#!/usr/bin/env bash
set -e

KEY_PATH="$HOME/.ssh/id_ed25519_github"
EMAIL="gedzi@local" # You can change this if you want

echo ">>> [1/5] Fixing Git Identity..."
# Fixes 'empty ident name' error
git config --global user.name "Gedzi Local"
git config --global user.email "$EMAIL"

echo ">>> [2/5] Generating New SSH Key..."
# Generates a secure key with NO passphrase (automatic login)
if [ ! -f "$KEY_PATH" ]; then
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
else
    echo "   Key already exists. Skipping generation."
fi

echo ">>> [3/5] Configuring SSH to use this key..."
# Tells SSH to always use this key for GitHub
mkdir -p ~/.ssh
CONFIG_FILE="$HOME/.ssh/config"
touch "$CONFIG_FILE"

if ! grep -q "Host github.com" "$CONFIG_FILE"; then
cat << EOF >> "$CONFIG_FILE"

Host github.com
  IdentityFile $KEY_PATH
  User git
  StrictHostKeyChecking no
EOF
fi
chmod 600 "$CONFIG_FILE"

echo ">>> [4/5] Switching Repo to SSH..."
cd ~/nitepwl
# Changes remote from https://... to git@github.com...
git remote set-url origin git@github.com:gedzilius-lang/nitepwl.git

echo "=================================================================="
echo ">>> ACTION REQUIRED: Copy the key below and add it to GitHub"
echo ">>> Go to: https://github.com/settings/ssh/new"
echo ">>> Title: NiteOS Local"
echo ">>> Key:"
echo ""
cat "$KEY_PATH.pub"
echo ""
echo "=================================================================="
