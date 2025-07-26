# Let's Encrypt DNS-01 Challenge Setup Guide (OCI DNS)

이 가이드는 OCI DNS를 사용하여 와일드카드 인증서를 DNS-01 Challenge로 발급받고 자동 갱신하는 방법을 설명합니다.

## Prerequisites

1. **OCI CLI configured** with appropriate permissions for DNS zone management
2. **certbot and certbot-dns-oci plugin** installed:
   ```bash
   # Install certbot
   sudo apt-get update
   sudo apt-get install certbot

   # Install OCI DNS plugin
   pip3 install certbot-dns-oci
   ```
3. **DNS zones** configured in OCI DNS service for your domains

## DNS-01 Challenge Process

The `certbot-dns-oci` plugin automates the DNS-01 challenge process:

1. **Challenge Creation**: When requesting a certificate, certbot uses the OCI DNS plugin to automatically create the required `_acme-challenge` TXT records
2. **Validation**: Let's Encrypt validates domain ownership by checking these DNS records
3. **Cleanup**: After validation, the plugin automatically removes the temporary TXT records
4. **Certificate Issuance**: Let's Encrypt issues the certificate for your domains

### Certificate Request Command

```bash
# Request wildcard certificate using OCI DNS plugin
certbot certonly \
  --dns-oci \
  --dns-oci-credentials /path/to/oci/credentials \
  -d leecod.ing \
  -d *.leecod.ing \
  --agree-tos \
  --email your-email@example.com \
  --non-interactive
```

## 🔧 OCI DNS 설정

### 1. DNS Zone 생성
```bash
# DNS Zone 생성
oci dns zone create \
  --compartment-id <compartment-ocid> \
  --name "leecod.ing" \
  --zone-type "PRIMARY"

# Zone 상태 확인
oci dns zone get --zone-name-or-id "leecod.ing"
```

### 2. OCI API 키 설정
- [OCI Console](https://cloud.oracle.com/)에 로그인
- 우측 상단 프로필 → "User Settings" 클릭
- "API Keys" 섹션에서 "Add API Key" 클릭
- 키 생성 후 설정 정보 저장

### 3. OCI CLI 설정
```bash
# OCI CLI 설치
curl -L -O https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
bash install.sh --accept-all-defaults

# 설정 초기화
oci setup config
```

## 🚀 GitHub Secrets 설정

GitHub 리포지토리의 Settings > Secrets and variables > Actions에서 다음 secrets을 추가하세요:

### Let's Encrypt 관련
```
LETSENCRYPT_EMAIL=admin@leecod.ing
```

### OCI 관련
```
OCI_CLI_REGION=ap-seoul-1
OCI_CLI_TENANCY=ocid1.tenancy.oc1..aaaaaaaa...
OCI_CLI_USER=ocid1.user.oc1..aaaaaaaa...
OCI_CLI_FINGERPRINT=aa:bb:cc:dd:ee:ff...
OCI_CLI_KEY_CONTENT=-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
LOAD_BALANCER_ID=ocid1.loadbalancer.oc1.ap-seoul-1.aaaaaaaa...
```

## 📝 DNS-01 Challenge 과정

### 1. DNS 레코드 생성
Certbot과 OCI DNS 훅이 자동으로 다음과 같은 TXT 레코드를 생성합니다:
```
_acme-challenge.leecod.ing     TXT    "challenge-token"
_acme-challenge.leecod.ing     TXT    "wildcard-challenge-token"
```

### 2. 도메인 검증
Let's Encrypt가 OCI DNS의 TXT 레코드를 확인하여 도메인 소유권을 검증합니다.

### 3. 인증서 발급
검증 완료 후 다음 도메인들을 포함하는 인증서가 발급됩니다:
- `*.leecod.ing` (와일드카드)
- `leecod.ing` (루트 도메인)

## 🔄 자동 갱신 스케줄

### 기본 스케줄
- **주기**: 2개월마다 1일 오전 2시 (UTC)
- **조건**: 만료 30일 전에만 갱신 시도

### 수동 실행
GitHub Actions에서 "Renew Let's Encrypt Certificate" 워크플로우를 수동으로 실행할 수 있습니다:

1. GitHub 리포지토리 → Actions 탭
2. "Renew Let's Encrypt Certificate" 선택
3. "Run workflow" 버튼 클릭
4. 옵션 설정:
   - **Force renewal**: 만료 날짜 무시하고 강제 갱신
   - **Domains**: 갱신할 도메인 (기본: `*.leecod.ing,leecod.ing`)

## 📁 인증서 파일 위치

갱신된 인증서는 다음 위치에 저장됩니다:
```
/etc/letsencrypt/live/leecod.ing/
├── fullchain.pem    # 인증서 + 중간 인증서
├── privkey.pem      # 개인 키
├── cert.pem         # 인증서만
└── chain.pem        # 중간 인증서만
```

## 🔧 OCI Load Balancer 연동

### 자동 업데이트
스크립트가 인증서 갱신 후 자동으로 OCI Load Balancer를 업데이트합니다:

1. **새 인증서 업로드**: Load Balancer에 새 인증서 추가
2. **리스너 업데이트**: HTTPS 리스너가 새 인증서 사용하도록 변경
3. **구 인증서 정리**: 이전 인증서 제거 (선택사항)

### 수동 업데이트
필요 시 수동으로 Load Balancer를 업데이트할 수 있습니다:

```bash
# 인증서 업로드
oci lb certificate create \
  --load-balancer-id "ocid1.loadbalancer..." \
  --certificate-name "leecod-ing-$(date +%Y%m%d)" \
  --public-certificate "$(cat /etc/letsencrypt/live/leecod.ing/fullchain.pem)" \
  --private-key "$(cat /etc/letsencrypt/live/leecod.ing/privkey.pem)"

# 리스너 업데이트
oci lb listener update \
  --load-balancer-id "ocid1.loadbalancer..." \
  --listener-name "https-listener" \
  --ssl-configuration '{
    "certificateName": "leecod-ing-$(date +%Y%m%d)",
    "verifyPeerCertificate": false
  }'
```

## 🔍 모니터링 및 로그

### GitHub Actions 로그
- 워크플로우 실행 로그는 GitHub Actions에서 확인
- 실패 시 자동으로 Issue 생성
- 로그 파일은 Artifact로 30일간 보관

### 로컬 테스트
로컬에서 스크립트를 테스트할 수 있습니다:

```bash
# 환경 변수 설정
export EMAIL="admin@leecod.ing"
export DOMAINS="*.leecod.ing,leecod.ing"

# OCI CLI 설정 확인
oci dns zone list --compartment-id "$(oci iam compartment list --query 'data[0].id' --raw-output)" --limit 1

# 테스트 실행 (드라이런)
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --manual-auth-hook "./scripts/oci-dns-auth.sh" \
  --manual-cleanup-hook "./scripts/oci-dns-cleanup.sh" \
  --dry-run \
  -d "*.leecod.ing" \
  -d "leecod.ing"
```

## 🚨 트러블슈팅

### 일반적인 문제들

#### 1. OCI API Token 오류
```
Error: Invalid API Token or insufficient permissions
```
**해결방법**: 
- API 키 권한 확인 (DNS 영역 관리 권한 필요)
- OCI CLI 설정 파일 확인 (~/.oci/config)
- 테넌시 및 컴파트먼트 ID 확인

#### 2. DNS Zone 접근 오류
```
Error: Zone not found or access denied
```
**해결방법**:
- DNS Zone이 올바른 컴파트먼트에 있는지 확인
- Zone 이름 확인: `oci dns zone list`
- 사용자에게 DNS 영역 접근 권한이 있는지 확인

#### 3. DNS 전파 지연
```
Error: DNS challenge failed
```
**해결방법**:
- DNS 전파 대기 시간 증가 (스크립트의 sleep 시간 조정)
- DNS 설정 확인: `dig TXT _acme-challenge.leecod.ing`
- OCI DNS 레코드 확인

#### 3. Rate Limit 오류
```
Error: too many certificates already issued
```
**해결방법**:
- Let's Encrypt Rate Limit 확인 (주당 50개 인증서 제한)
- 테스트 시 `--dry-run` 옵션 사용

#### 4. Load Balancer 업데이트 실패
```
Error: Invalid certificate format
```
**해결방법**:
- 인증서 파일 형식 확인
- OCI CLI 권한 확인
- Load Balancer 상태 확인

### 유용한 명령어들

```bash
# 인증서 상태 확인
certbot certificates

# 인증서 수동 갱신
certbot renew --cert-name leecod.ing

# DNS 레코드 확인
dig TXT _acme-challenge.leecod.ing

# 인증서 만료일 확인
openssl x509 -in /etc/letsencrypt/live/leecod.ing/fullchain.pem -noout -enddate

# OCI DNS Zone 확인
oci dns zone list --compartment-id "$(oci iam compartment list --query 'data[0].id' --raw-output)"

# OCI DNS 레코드 확인
oci dns record get --zone-name-or-id "leecod.ing" --domain "_acme-challenge.leecod.ing" --rtype "TXT"
```

## 📞 지원

문제가 발생하면 다음을 확인해보세요:

1. **GitHub Actions 로그**: 자세한 오류 메시지 확인
2. **OCI Console**: DNS Zone 및 API 키 상태
3. **Let's Encrypt Status**: [https://letsencrypt.status.io/](https://letsencrypt.status.io/)
4. **OCI Console**: Load Balancer 및 인증서 상태

새로운 이슈를 생성할 때는 다음 정보를 포함해주세요:
- 도메인 이름
- 오류 메시지 및 로그
- OCI 리전 및 컴파트먼트 정보
- 재현 단계
