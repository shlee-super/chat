#!/bin/bash

# 인증서 갱신 스크립트 (매일 cron에서 실행 권장)
# 인증서가 30일 이하로 남은 경우에만 갱신 시도

set -e

echo "Let's Encrypt 인증서 갱신을 확인합니다..."

docker compose -f ../deploy-compose.yml run --rm certbot \
  renew --webroot --webroot-path=/var/www/certbot

echo "nginx를 재시작하여 갱신된 인증서를 반영합니다..."
docker compose -f ../deploy-compose.yml exec nginx nginx -s reload
