#!/usr/bin/env bash
set -e

SWAP_SIZE="2G"
SWAP_FILE="/swapfile"

echo ">>> [Swap] Checking existing swap..."
if grep -q "swap" /etc/fstab; then
    echo "   Swap already configured. Skipping."
    exit 0
fi

echo ">>> [Swap] Creating $SWAP_SIZE swap file..."
fallocate -l $SWAP_SIZE $SWAP_FILE
chmod 600 $SWAP_FILE
mkswap $SWAP_FILE
swapon $SWAP_FILE

echo ">>> [Swap] Persisting in /etc/fstab..."
echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab

echo ">>> [Swap] Tuning Swappiness..."
# Set swappiness to 10 (use RAM mostly, swap only when necessary)
sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf

echo ">>> [Swap] Done. Current Memory Status:"
free -h
