#!/bin/bash

# 초기 Let's Encrypt 인증서 발급 스크립트
# 실행 전 deploy-compose.yml의 nginx 컨테이너가 정의되어 있어야 함

set -e

DOMAIN="chat.leecod.ing"
EMAIL="shlee.super@gmail.com"
WEBROOT_PATH="/var/www/certbot"
COMPOSE_FILE="../deploy-compose.yml"

CERT_PATH="./certbot/conf/live/$DOMAIN"

if [ -d "$CERT_PATH" ]; then
  echo "✅ 인증서가 이미 존재합니다: $CERT_PATH"
  echo "🚫 발급을 건너뜁니다."
  exit 0
fi

echo "🚀 nginx 컨테이너를 HTTP로 기동합니다..."
docker compose -f $COMPOSE_FILE up -d nginx

echo "🔐 Let's Encrypt 인증서를 발급 중입니다..."
docker compose -f $COMPOSE_FILE run --rm certbot \
  certonly --webroot \
  --webroot-path=$WEBROOT_PATH \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  -d $DOMAIN

echo "♻️ nginx를 재시작하여 HTTPS 설정을 반영합니다..."
docker compose -f $COMPOSE_FILE restart nginx

echo "✅ 인증서 발급 및 nginx 재시작 완료"
