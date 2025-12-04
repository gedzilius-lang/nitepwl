#!/usr/bin/env bash
set -e

echo ">>> Installing Certbot..."
apt-get update
apt-get install -y certbot python3-certbot-nginx

echo ">>> Requesting SSL Certificate for os.peoplewelike.club..."
# This runs certbot in non-interactive mode. 
# It assumes you accept terms and want to redirect HTTP to HTTPS.
# REPLACE 'your-email@example.com' below if you want failure notifications from Let's Encrypt
certbot --nginx -d os.peoplewelike.club --non-interactive --agree-tos -m admin@peoplewelike.club --redirect

echo ">>> SSL Setup Complete!"
