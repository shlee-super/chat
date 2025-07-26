# OCI Load Balancer와 Certificate Manager 설정 가이드

이 가이드는 Oracle Cloud Infrastructure(OCI)에서 LibreChat 애플리케이션을 Load Balancer와 Certificate Manager를 사용하여 구성하는 방법을 설명합니다.

## 사전 요구사항

1. OCI 계정 및 적절한 권한
2. OCI CLI 설치 및 구성
3. Terraform 설치 (선택사항)
4. 도메인 소유권 및 DNS 접근 권한

## 1. OCI 네트워크 설정

### VCN 및 서브넷 생성

```bash
# VCN 생성
oci network vcn create \
  --compartment-id <compartment-ocid> \
  --display-name "librechat-vcn" \
  --cidr-block "10.0.0.0/16"

# 인터넷 게이트웨이 생성
oci network internet-gateway create \
  --compartment-id <compartment-ocid> \
  --vcn-id <vcn-ocid> \
  --display-name "librechat-igw" \
  --is-enabled true

# 라우트 테이블 업데이트
oci network route-table update \
  --rt-id <route-table-ocid> \
  --route-rules '[{
    "destination": "0.0.0.0/0",
    "destinationType": "CIDR_BLOCK",
    "networkEntityId": "<internet-gateway-ocid>"
  }]'

# 퍼블릭 서브넷 생성 (Load Balancer용)
oci network subnet create \
  --compartment-id <compartment-ocid> \
  --vcn-id <vcn-ocid> \
  --display-name "librechat-public-subnet" \
  --cidr-block "10.0.1.0/24" \
  --route-table-id <route-table-ocid> \
  --security-list-ids '["<security-list-ocid>"]'

# 프라이빗 서브넷 생성 (애플리케이션 인스턴스용)
oci network subnet create \
  --compartment-id <compartment-ocid> \
  --vcn-id <vcn-ocid> \
  --display-name "librechat-private-subnet" \
  --cidr-block "10.0.2.0/24" \
  --prohibit-public-ip-on-vnic true
```

### 보안 리스트 규칙 설정

```bash
# Load Balancer용 보안 규칙 추가
oci network security-list update \
  --security-list-id <security-list-ocid> \
  --ingress-security-rules '[
    {
      "source": "0.0.0.0/0",
      "protocol": "6",
      "isStateless": false,
      "tcpOptions": {
        "destinationPortRange": {
          "min": 80,
          "max": 80
        }
      }
    },
    {
      "source": "0.0.0.0/0", 
      "protocol": "6",
      "isStateless": false,
      "tcpOptions": {
        "destinationPortRange": {
          "min": 443,
          "max": 443
        }
      }
    }
  ]'
```

## 2. 인스턴스 설정

### LibreChat 인스턴스 생성

```bash
# 인스턴스 생성
oci compute instance launch \
  --compartment-id <compartment-ocid> \
  --availability-domain <AD-name> \
  --display-name "librechat-instance" \
  --image-id <ubuntu-image-ocid> \
  --shape "VM.Standard.E4.Flex" \
  --shape-config '{"ocpus": 2, "memoryInGBs": 16}' \
  --subnet-id <private-subnet-ocid> \
  --ssh-authorized-keys-file ~/.ssh/id_rsa.pub
```

### 인스턴스 설정 스크립트

```bash
#!/bin/bash

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Docker Compose 설치
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 프로젝트 클론
git clone https://github.com/your-username/chat.git librechat
cd librechat

# 환경 파일 설정
cp .env.example .env
# .env 파일을 적절히 수정

# 애플리케이션 시작
docker-compose up -d
```

## 3. Terraform을 사용한 자동 배포

### Terraform 초기화 및 배포

```bash
cd terraform

# Terraform 초기화
terraform init

# terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일을 실제 값으로 수정

# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

### terraform.tfvars 예제

```hcl
region           = "ap-seoul-1"
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaaaaa..."
fingerprint      = "aa:bb:cc:dd:ee:ff..."
private_key_path = "~/.oci/oci_api_key.pem"
compartment_id   = "ocid1.compartment.oc1..aaaaaaaa..."
vcn_id           = "ocid1.vcn.oc1.ap-seoul-1.aaaaaaaa..."
public_subnet_id = "ocid1.subnet.oc1.ap-seoul-1.aaaaaaaa..."
private_subnet_id= "ocid1.subnet.oc1.ap-seoul-1.aaaaaaaa..."
instance_private_ip = "10.0.2.100"
domain_name      = "chat.leecod.ing"
app_name         = "librechat"
```

## 4. DNS 설정

### 도메인 DNS 레코드 설정

Load Balancer 배포 후 반환된 공개 IP 주소를 사용하여 DNS A 레코드를 설정합니다:

```
A    chat.leecod.ing    <load-balancer-public-ip>
```

## 5. Certificate Manager 설정

### SSL 인증서 생성

```bash
# 인증서 생성
oci certificates-management certificate create \
  --compartment-id <compartment-ocid> \
  --name "librechat-certificate" \
  --certificate-config '{
    "configType": "MANAGED",
    "subject": {
      "commonName": "chat.leecod.ing"
    },
    "certificateProfileType": "TLS_SERVER_OR_CLIENT",
    "validity": {
      "timeOfValidityNotAfter": "2025-12-31T23:59:59.999Z"
    }
  }'
```

### 인증서 상태 확인

```bash
# 인증서 상태 확인
oci certificates-management certificate get \
  --certificate-id <certificate-ocid> \
  --query 'data."lifecycle-state"'
```

## 6. GitHub Secrets 설정

GitHub 리포지토리의 Settings > Secrets and variables > Actions에서 다음 secrets을 설정하세요:

### OCI 관련 Secrets

```
OCI_CLI_REGION=ap-seoul-1
OCI_CLI_TENANCY=ocid1.tenancy.oc1..aaaaaaaa...
OCI_CLI_USER=ocid1.user.oc1..aaaaaaaa...
OCI_CLI_FINGERPRINT=aa:bb:cc:dd:ee:ff...
OCI_CLI_KEY_CONTENT=-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
COMPARTMENT_ID=ocid1.compartment.oc1..aaaaaaaa...
LOAD_BALANCER_ID=ocid1.loadbalancer.oc1.ap-seoul-1.aaaaaaaa...
CERTIFICATE_NAME=librechat-certificate
DOMAIN_NAME=chat.leecod.ing
```

### 배포 관련 Secrets

```
INSTANCE_IP=10.0.2.100
SSH_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
SSH_USER=ubuntu
```

### 알림 관련 Secrets (선택사항)

```
WEBHOOK_URL=https://hooks.slack.com/services/...
```

## 7. 모니터링 및 로그

### CloudWatch 설정

```bash
# CloudWatch 에이전트 설치 (인스턴스에서)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/oracle_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm
```

### 로그 모니터링

```bash
# 애플리케이션 로그 확인
docker-compose logs -f librechat

# 시스템 로그 확인
sudo journalctl -u docker -f
```

## 8. 백업 및 복원

### 데이터베이스 백업

```bash
# MongoDB 백업
docker exec librechat_mongo_1 mongodump --db LibreChat --out /data/backup

# 백업 파일 복사
docker cp librechat_mongo_1:/data/backup ./backup
```

### 자동 백업 스크립트

```bash
#!/bin/bash
# 매일 자동 백업
0 2 * * * /home/ubuntu/librechat/scripts/backup.sh
```

## 트러블슈팅

### 일반적인 문제들

1. **Load Balancer 연결 실패**
   - 보안 그룹 규칙 확인
   - Backend 서비스 상태 확인
   - Health Check 설정 확인

2. **인증서 갱신 실패** 
   - DNS 설정 확인
   - 도메인 소유권 확인
   - Certificate Manager 권한 확인

3. **애플리케이션 시작 실패**
   - Docker 로그 확인
   - 환경 변수 설정 확인
   - 포트 충돌 확인

### 유용한 명령어들

```bash
# Load Balancer 상태 확인
oci lb load-balancer get --load-balancer-id <lb-ocid>

# Backend 서비스 상태 확인
oci lb backend-health get --load-balancer-id <lb-ocid> --backend-set-name <backend-set-name>

# 인증서 상태 확인
oci certificates-management certificate get --certificate-id <cert-ocid>

# 인스턴스 연결
ssh -i ~/.ssh/private_key ubuntu@<instance-ip>
```

## 보안 고려사항

1. **네트워크 보안**
   - 최소 권한 원칙 적용
   - 불필요한 포트 차단
   - Private 서브넷 사용

2. **애플리케이션 보안**
   - 강력한 패스워드 사용
   - 정기적인 업데이트
   - 로그 모니터링

3. **인증서 관리**
   - 자동 갱신 설정
   - 만료 알림 설정
   - 백업 인증서 준비

이 가이드를 따라 설정하면 안전하고 확장 가능한 LibreChat 환경을 OCI에서 운영할 수 있습니다.
