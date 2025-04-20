# LibreChat Docker Deploy Template

이 저장소는 Ubuntu 환경에서 [LibreChat](https://github.com/danny-avila/LibreChat)을 HTTPS로 안전하게 호스팅하기 위한 템플릿입니다.

## 📁 디렉터리 구조

```
repo-root/
├── deploy-compose.yml              # Docker Compose V2 파일
├── .env                            # 환경 변수 파일
├── nginx/
│   ├── nginx.conf                 # 기본 nginx 설정
│   └── librechat.conf            # LibreChat용 서버 블록 설정
├── certbot/
│   ├── www/                      # Certbot webroot 인증용 폴더
│   └── conf/                     # Certbot 인증서와 설정 파일 저장
├── systemd/
│   └── librechat.service         # 시스템 부팅 시 LibreChat 자동 실행
├── scripts/
│   ├── init-letsencrypt.sh      # 인증서 최초 발급 스크립트
│   └── renew-cron.sh            # 인증서 갱신용 cron 스크립트
└── README.md                      # 사용법 및 설명 문서
```

---

## 🚀 설치 방법

### 1. 필수 패키지 설치 (Ubuntu 기준)
```bash
sudo apt update && sudo apt install -y docker.io docker-compose curl certbot
```

### 2. Git 저장소 클론 및 설정
```bash
git clone https://github.com/your-org/librechat-deploy-template.git
cd librechat-deploy-template
```

`.env` 파일을 생성하여 필요한 환경변수를 설정합니다.

### 3. 도메인 설정
DNS에서 `chat.leecod.ing`가 이 서버의 IP를 가리키도록 설정하세요.

### 4. nginx 및 certbot 설정

#### (1) 최초 인증서 발급
```bash
bash scripts/init-letsencrypt.sh
```

#### (2) 이후 인증서 자동 갱신 (cron 등록)
```bash
crontab -e
```
다음 라인을 추가:
```cron
0 3 * * * /bin/bash /path/to/repo-root/scripts/renew-cron.sh >> /var/log/certbot-renew.log 2>&1
```

---

## 🔄 시스템 부팅 시 자동 실행 설정

LibreChat과 nginx가 서버 재부팅 후에도 자동으로 실행되도록 `systemd`를 설정합니다:

```bash
sudo cp systemd/librechat.service /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl enable librechat.service
sudo systemctl start librechat.service
```

---

## 🐳 Docker Compose 파일

`deploy-compose.yml` 파일은 LibreChat, MongoDB, nginx, Certbot을 구성합니다.

```yaml
version: '3.8'

services:
  librechat:
    image: ghcr.io/danny-avila/librechat:latest
    container_name: librechat
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - librechat-data:/app/backend/data
    depends_on:
      - mongo
    networks:
      - librechat-net

  mongo:
    image: mongo:6
    container_name: librechat-mongo
    restart: unless-stopped
    volumes:
      - mongo-data:/data/db
    networks:
      - librechat-net

  nginx:
    image: nginx:latest
    container_name: librechat-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/librechat.conf:/etc/nginx/conf.d/librechat.conf:ro
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    depends_on:
      - librechat
    networks:
      - librechat-net

volumes:
  librechat-data:
  mongo-data:

networks:
  librechat-net:
```

---

## 📦 LibreChat 업데이트 방법
```bash
git pull origin main
sudo systemctl restart librechat.service
```

---

## 🧪 테스트
브라우저에서 `https://chat.leecod.ing` 접속하여 LibreChat이 정상적으로 구동되는지 확인하세요.

---

## 🧾 라이선스
MIT

---

문의 사항은 이슈를 남겨주세요!
