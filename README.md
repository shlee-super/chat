# LibreChat on Oracle Cloud Infrastructure (OCI)

이 저장소는 Oracle Cloud Infrastructure(OCI)에서 [LibreChat](https://github.com/danny-avila/Lib## 🔄 자동화 워크플로우

### 인증서 자동 갱신
- **스케줄**: 2개월마다 1일 오전 2시 (UTC)
- **수동 실행**: GitHub Actions에서 수동 트리거 가능
- **모니터링**: 만료 30일 전 갱신 시도
- **강제 갱신**: 수동 실행 시 만료일 무시 옵션

## 🚀 수동 배포

### 인스턴스 배포 방법

```bash
# 1. 인스턴스에 SSH 접속
ssh ubuntu@<instance-ip>

# 2. 프로젝트 디렉터리로 이동
cd ~/librechat

# 3. 최신 코드 가져오기
git pull origin main

# 4. 환경 설정 확인
cp .env.example .env
# .env 파일을 실제 환경에 맞게 수정

# 5. Docker 이미지 업데이트
docker-compose pull

# 6. 서비스 재시작
docker-compose down
docker-compose up -d

# 7. 상태 확인
docker-compose ps
./scripts/health-check.sh
```d Balancer와 Certificate Manager를 사용하여 안전하고 확장 가능하게 호스팅하기 위한 템플릿입니다.

## 🏗️ 아키텍처 개요

```
Internet
    ↓
OCI Load Balancer (Public IP)
    ↓ (SSL Termination)
LibreChat Instance (Private Subnet)
    ↓
MongoDB Container
    ↓
RAG API Container
```

## 📁 프로젝트 구조

```
repo-root/
├── docker-compose.yml              # Docker Compose 설정
├── .env.example                   # 환경 변수 템플릿
├── librechat.yaml                 # LibreChat 설정
├── terraform/                     # OCI 인프라 Terraform 코드
│   ├── main.tf                   # 주요 리소스 정의
│   ├── variables.tf              # 입력 변수
│   ├── outputs.tf                # 출력 값
│   └── terraform.tfvars.example  # 변수 값 예제
├── scripts/                       # 유틸리티 스크립트
│   ├── renew-oci-certificate.sh  # OCI 인증서 갱신
│   └── health-check.sh           # 애플리케이션 상태 확인
├── .github/workflows/             # GitHub Actions 워크플로우
│   ├── renew-certificate.yml     # 인증서 자동 갱신
│   └── deploy.yml                # 자동 배포
├── docs/                          # 문서
│   └── OCI-SETUP-GUIDE.md        # 상세 설정 가이드
└── README.md                      # 이 파일
```

---

## 🚀 빠른 시작

### 1. 사전 요구사항

- OCI 계정 및 적절한 권한
- OCI CLI 설치 및 구성
- Terraform 설치 (선택사항)
- 도메인 소유권 및 DNS 접근 권한

### 2. 저장소 클론

```bash
git clone https://github.com/shlee-super/chat.git
cd chat
```

### 3. 환경 설정

```bash
# 환경 변수 파일 생성
cp .env.example .env
# .env 파일을 실제 환경에 맞게 수정

# Terraform 변수 파일 생성
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# terraform.tfvars 파일을 실제 값으로 수정
```

### 4. 인프라 배포 (Terraform 사용)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 5. 애플리케이션 배포

```bash
# 인스턴스에서 실행
docker-compose up -d
```

---

## 🔧 주요 특징

### OCI Load Balancer 통합
- **SSL/TLS 종료**: Load Balancer에서 SSL 처리
- **자동 확장**: 트래픽에 따른 자동 스케일링 준비
- **고가용성**: 다중 가용성 도메인 지원

### Certificate Manager 통합
- **Let's Encrypt 와일드카드**: DNS-01 Challenge로 `*.leecod.ing`, `leecod.ing` 인증서 발급
- **자동 갱신**: GitHub Actions를 통한 2개월마다 자동 갱신
- **OCI DNS**: DNS-01 Challenge를 위한 OCI DNS 서비스 연동

### CI/CD 자동화
- **인증서 모니터링**: 만료 30일 전 자동 갱신
- **실패 알림**: 인증서 갱신 실패 시 GitHub Issue 자동 생성

---

## 📋 설정 가이드

### GitHub Secrets 설정

다음 secrets을 GitHub 리포지토리에 추가해야 합니다:

#### Let's Encrypt 관련
- `LETSENCRYPT_EMAIL`: Let's Encrypt 계정 이메일

#### OCI 관련 (Load Balancer 사용 시)
- `OCI_CLI_REGION`: OCI 리전 (예: ap-seoul-1)  
- `OCI_CLI_TENANCY`: 테넌시 OCID
- `OCI_CLI_USER`: 사용자 OCID
- `OCI_CLI_FINGERPRINT`: API 키 지문
- `OCI_CLI_KEY_CONTENT`: API 개인 키 내용
- `LOAD_BALANCER_ID`: Load Balancer OCID

### DNS 설정

다음 DNS 레코드를 설정합니다:

```
A    leecod.ing           <load-balancer-public-ip>
A    *.leecod.ing         <load-balancer-public-ip>
```

**중요**: DNS는 OCI DNS 서비스를 사용해야 하며, DNS-01 Challenge를 위한 API 접근이 필요합니다.

---

## � 자동화 워크플로우

### 인증서 자동 갱신
- **스케줄**: 2개월마다 1일 오전 2시 (UTC)
- **수동 실행**: GitHub Actions에서 수동 트리거 가능
- **모니터링**: 만료 30일 전 갱신 시도
- **강제 갱신**: 수동 실행 시 만료일 무시 옵션

### 자동 배포
- **트리거**: main 브랜치 push 시
- **과정**: 코드 동기화 → Docker 이미지 갱신 → 서비스 재시작
- **상태 확인**: 배포 후 health check 실행

---

## 🔍 모니터링 및 유지보수

### Health Check

```bash
# 애플리케이션 상태 확인
./scripts/health-check.sh

# Docker 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f librechat
```

### 수동 인증서 갱신

```bash
# 인증서 상태 확인
./scripts/renew-letsencrypt-certificate.sh

# 강제 갱신 (개발/테스트용)
FORCE_RENEWAL=true ./scripts/renew-letsencrypt-certificate.sh

# 드라이런 테스트
certbot renew --dry-run --cert-name leecod.ing
```

---

## 📚 상세 문서

- [OCI 설정 가이드](docs/OCI-SETUP-GUIDE.md): 완전한 설정 가이드
- [Let's Encrypt DNS-01 가이드](docs/LETSENCRYPT-DNS-GUIDE.md): 인증서 설정 및 트러블슈팅  
- [수동 배포 가이드](docs/MANUAL-DEPLOYMENT-GUIDE.md): 안전한 수동 배포 절차
- [LibreChat 공식 문서](https://docs.librechat.ai/): LibreChat 설정 및 사용법

---

## 🐛 트러블슈팅

### 일반적인 문제들

1. **Load Balancer 연결 실패**
   ```bash
   # Backend 상태 확인
   oci lb backend-health get --load-balancer-id <lb-ocid> --backend-set-name <backend-set-name>
   ```

2. **인증서 갱신 실패**
   ```bash
   # 인증서 상태 확인
   certbot certificates
   
   # OCI DNS 확인
   dig TXT _acme-challenge.leecod.ing
   ```

3. **애플리케이션 시작 실패**
   ```bash
   # 컨테이너 로그 확인
   docker-compose logs librechat
   ```

### 로그 위치

- **애플리케이션 로그**: `docker-compose logs`
- **시스템 로그**: `/var/log/syslog`
- **GitHub Actions 로그**: GitHub 리포지토리의 Actions 탭

---

## 🤝 기여하기

1. Fork 생성
2. Feature 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경사항 커밋 (`git commit -m 'Add some amazing feature'`)
4. 브랜치에 Push (`git push origin feature/amazing-feature`)
5. Pull Request 생성

---

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

## 📞 지원

문제가 발생하면 다음을 확인해보세요:

1. [Issues](https://github.com/shlee-super/chat/issues)에서 기존 문제 검색
2. [OCI 설정 가이드](docs/OCI-SETUP-GUIDE.md) 재확인
3. [LibreChat 공식 문서](https://docs.librechat.ai/) 참조

새로운 이슈를 생성할 때는 다음 정보를 포함해주세요:
- 운영 체제 및 버전
- OCI 리전 및 설정
- 에러 메시지 및 로그
- 재현 단계

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
