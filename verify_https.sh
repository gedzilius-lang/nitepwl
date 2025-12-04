#!/bin/bash
set -e

echo ">>> [HTTPS Check] Verifying all endpoints are secure..."

# Test 1: HTTP REDIRECT (Should force 301 to HTTPS)
echo "--- 1. Testing HTTP -> HTTPS Redirect (Port 80) ---"
curl -ILs http://os.peoplewelike.club/ | grep -E 'HTTP/1.1 301|Location: https'

# Test 2: API Proxy Access (Checks Nginx Proxy over 443)
echo -e "\n--- 2. Testing Secure API Proxy (Port 443) ---"
curl -s -L https://os.peoplewelike.club/api/users/demo | grep -o "demo_admin"

# Test 3: HLS Stream Access (Checks Static File Serving over 443)
echo -e "\n--- 3. Testing Secure HLS File Access ---"
curl -s -L https://os.peoplewelike.club/hls/autodj/stream.m3u8 | grep -o '#EXTM3U'

echo -e "\n>>> Verification Complete. Check the outputs above."
