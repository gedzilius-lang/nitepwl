#!/usr/bin/env bash
set -e

echo ">>> [Firewall] Installing UFW..."
apt-get install -y ufw

echo ">>> [Firewall] Configuring Rules..."
# Allow SSH first (CRITICAL so you don't lock yourself out)
ufw allow OpenSSH
# Allow Web Traffic
ufw allow 'Nginx Full'
# Allow internal loopback (so backend can talk to DB)
ufw allow from 127.0.0.1

echo ">>> [Firewall] Enabling..."
# 'yes' automatically answers the "Command may disrupt existing ssh connections" prompt
echo "y" | ufw enable

echo ">>> [Firewall] Status:"
ufw status verbose
