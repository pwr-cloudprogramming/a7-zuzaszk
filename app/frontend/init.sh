#!/bin/sh
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

cat /usr/share/nginx/html/game.js
sed -i "s|__SERVER_URL__|http://${PUBLIC_IP}:5000|g" /usr/share/nginx/html/game.js
cat /usr/share/nginx/html/game.js

echo "Starting nginx"
echo "Public IP: ${PUBLIC_IP}"
echo "Server URL: http://${PUBLIC_IP}:5000"

nginx -g 'daemon off;'
