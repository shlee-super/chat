#!/bin/bash

# 초기 인증서 발급을 위한 스크립트
# 반드시 deploy-compose.yml에서 nginx 컨테이너가 먼저 기동된 상태에서 실행

set -e

DOMAIN="chat.leecod.ing"
EMAIL="shlee.super@gmail.com" # 인증서 갱신 알림을 받을 이메일
WEBROOT_PATH="/var/www/certbot"

if [ -d "./certbot/conf/live/$DOMAIN" ]; then
  echo "이미 인증서가 존재합니다. 건너뜁니다."
  exit 0
fi

echo "인증서 발급을 위해 nginx 컨테이너를 시작합니다..."
docker compose -f ../deploy-compose.yml up -d nginx

echo "Let's Encrypt 인증서를 발급합니다..."
docker compose -f ../deploy-compose.yml run --rm certbot \
  certonly --webroot \
  --webroot-path=$WEBROOT_PATH \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  -d $DOMAIN

echo "nginx를 재시작하여 HTTPS 설정을 반영합니다..."
docker compose -f ../deploy-compose.yml restart nginx
