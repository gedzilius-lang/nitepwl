#!/usr/bin/env bash
set -e

KEY_PATH="$HOME/.ssh/id_ed25519_github_auto"
EMAIL="root@nite-os-vps"

echo ">>> [1/5] Generating new SSH Key..."
# -t: type ed25519 (modern, secure)
# -f: file path
# -C: comment/label
# -N: empty passphrase (for automatic connection without password)
if [ -f "$KEY_PATH" ]; then
    echo "   Key already exists at $KEY_PATH. Overwriting..."
    rm "$KEY_PATH" "$KEY_PATH.pub"
fi
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""

echo ">>> [2/5] Configuring SSH Agent..."
# Ensure .ssh directory permissions
chmod 700 "$HOME/.ssh"
# Start agent
eval "$(ssh-agent -s)"
# Add key
ssh-add "$KEY_PATH"

echo ">>> [3/5] Configuring SSH Config..."
# Create or append to config to ensure this key is used for github.com
CONFIG_FILE="$HOME/.ssh/config"
touch "$CONFIG_FILE"
# Check if config already exists to avoid duplicate entries
if ! grep -q "IdentityFile $KEY_PATH" "$CONFIG_FILE"; then
    echo -e "\nHost github.com\n  IdentityFile $KEY_PATH\n  User git\n  StrictHostKeyChecking no" >> "$CONFIG_FILE"
fi
chmod 600 "$CONFIG_FILE"

echo "=================================================================="
echo ">>> ACTION REQUIRED: Copy the key below and add it to GitHub"
echo ">>> Go to: https://github.com/settings/ssh/new"
echo ">>> Title: NiteOS VPS Auto"
echo ">>> Key:"
echo ""
cat "$KEY_PATH.pub"
echo ""
echo "=================================================================="

read -p ">>> Once you have added the key to GitHub, press ENTER to continue..."

echo ">>> [4/5] Testing Connection..."
# Attempt ssh connection (ssh -T git@github.com returns exit code 1 on success "Hi username!", so we handle that)
ssh -T git@github.com || true

echo ">>> [5/5] Updating Git Repository Remote..."
APP_DIR="/opt/nite-os-v7"
if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR"
    # Switch remote URL from HTTPS to SSH
    git remote set-url origin git@github.com:gedzilius-lang/nitepwl.git
    echo "   Remote updated to: $(git remote get-url origin)"
    
    echo ">>> Attempting Push..."
    git push -u origin main
else
    echo "   Error: Directory $APP_DIR not found. Skipping repo update."
fi

echo ">>> DONE! Your VPS is now connected to GitHub via SSH."
