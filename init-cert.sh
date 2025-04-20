#!/bin/bash

# 도메인과 이메일 설정
domain="chat.leecod.ing"
email="shlee@leecod.ing"  # 변경 필요

# 필요한 디렉토리 생성
mkdir -p certbot/www
mkdir -p certbot/conf

# 기존 컨테이너 정리
docker compose down

# nginx 설정 테스트
docker compose up -d nginx
echo "Nginx 시작 대기 중..."
sleep 5

# certbot 실행
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    -d $domain \
    --force-renewal

# 컨테이너 재시작
docker compose down
docker compose up -d