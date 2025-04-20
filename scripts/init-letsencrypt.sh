#!/bin/bash

# 초기 인증서 발급을 위한 스크립트
# 반드시 nginx 컨테이너가 먼저 기동된 상태에서 실행

set -e

DOMAIN="chat.leecod.ing"
EMAIL="shlee.super@gmail.com"
WEBROOT_PATH="/var/www/certbot"

if [ -d "./certbot/conf/live/$DOMAIN" ]; then
  echo "✅ 이미 인증서가 존재합니다. 건너뜁니다."
  exit 0
fi

echo "🚀 nginx 컨테이너를 HTTP로 기동합니다..."
docker compose -f ../deploy-compose.yml up -d nginx

echo "🔐 Let's Encrypt 인증서를 발급 중입니다..."
docker run --rm \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  certbot/certbot certonly \
  --webroot \
  --webroot-path=$WEBROOT_PATH \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  -d $DOMAIN

echo "🔄 nginx를 재시작하여 HTTPS 설정을 반영합니다..."
docker compose -f ../deploy-compose.yml restart nginx
