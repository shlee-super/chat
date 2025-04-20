#!/bin/bash

set -e

DOMAIN="chat.leecod.ing"
EMAIL="shlee.super@gmail.com"
WEBROOT_PATH="/var/www/certbot"

if [ -d "./certbot/conf/live/$DOMAIN" ]; then
  echo "✅ 이미 인증서가 존재합니다. 건너뜁니다."
  exit 0
fi

# 초기 설정으로 nginx 시작
cp nginx/initial.conf nginx/conf.d/librechat.conf
echo "🚀 nginx 컨테이너를 초기 설정으로 기동합니다..."
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

# 인증서 발급 후 전체 설정 적용
cp nginx/librechat.conf nginx/conf.d/librechat.conf
echo "🔄 nginx를 재시작하여 HTTPS 설정을 반영합니다..."
docker compose -f ../deploy-compose.yml restart nginx