# 수동 배포 가이드

이 문서는 LibreChat 애플리케이션을 OCI 인스턴스에 수동으로 배포하는 방법을 설명합니다.

## 🎯 배포 전 준비사항

### 1. 로컬 환경 확인
- Git 최신 커밋 확인
- 변경사항 테스트 완료
- Docker Compose 파일 검증

### 2. 인스턴스 접근 준비
```bash
# SSH 키 권한 확인
chmod 600 ~/.ssh/your-private-key.pem

# 인스턴스 연결 테스트
ssh -i ~/.ssh/your-private-key.pem ubuntu@<instance-ip>
```

## 🚀 배포 단계

### 1단계: 인스턴스 접속
```bash
ssh -i ~/.ssh/your-private-key.pem ubuntu@<instance-ip>
```

### 2단계: 프로젝트 디렉터리로 이동
```bash
cd ~/librechat
```

### 3단계: 현재 상태 백업 (선택사항)
```bash
# 현재 환경 설정 백업
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# 현재 실행 중인 컨테이너 상태 확인
docker-compose ps > deployment.log
echo "=== Backup completed at $(date) ===" >> deployment.log
```

### 4단계: 최신 코드 가져오기
```bash
# 현재 브랜치 확인
git branch

# 최신 코드 가져오기
git fetch origin
git pull origin main

# 변경사항 확인
git log --oneline -5
```

### 5단계: 환경 설정 확인
```bash
# 환경 파일이 없다면 생성
if [ ! -f .env ]; then
    cp .env.example .env
    echo "⚠️  .env 파일을 설정하세요!"
fi

# 환경 설정 검증
echo "현재 환경 설정:"
grep -E '^[^#]' .env | head -10
```

### 6단계: Docker 이미지 업데이트
```bash
# 최신 이미지 가져오기
docker-compose pull

# 이미지 확인
docker images | grep -E "(librechat|mongo|rag)"
```

### 7단계: 서비스 중단 및 시작
```bash
# 현재 서비스 중단
docker-compose down

# 서비스 시작
docker-compose up -d

# 시작 로그 확인
docker-compose logs -f --tail=50
```

### 8단계: 배포 검증
```bash
# 컨테이너 상태 확인
docker-compose ps

# Health Check 실행
if [ -f "./scripts/health-check.sh" ]; then
    ./scripts/health-check.sh
else
    # 수동 health check
    sleep 30
    curl -f http://localhost:3080 || echo "Health check failed!"
fi

# 로그 확인
docker-compose logs librechat --tail=20
```

## 🔧 트러블슈팅

### 서비스 시작 실패
```bash
# 상세 로그 확인
docker-compose logs librechat

# 환경 변수 확인
docker-compose config

# 포트 충돌 확인
sudo netstat -tlnp | grep :3080
```

### 데이터베이스 연결 문제
```bash
# MongoDB 컨테이너 상태 확인
docker-compose logs mongo

# 네트워크 연결 확인
docker network ls
docker network inspect librechat_app-network
```

### 메모리/디스크 부족
```bash
# 시스템 리소스 확인
df -h
free -m

# 사용하지 않는 Docker 리소스 정리
docker system prune -f
docker volume prune -f
```

## 📊 배포 후 모니터링

### 성능 모니터링
```bash
# CPU/메모리 사용률
docker stats --no-stream

# 컨테이너별 리소스 사용량
docker-compose top
```

### 로그 모니터링
```bash
# 실시간 로그 확인
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f librechat

# 오류 로그만 확인
docker-compose logs librechat 2>&1 | grep -i error
```

### 애플리케이션 상태 확인
```bash
# 웹 인터페이스 접근 테스트
curl -I http://localhost:3080

# 데이터베이스 연결 테스트
docker-compose exec mongo mongosh --eval "db.runCommand({connectionStatus: 1})"
```

## 🔄 롤백 절차

배포에 문제가 있을 경우 이전 상태로 롤백할 수 있습니다.

### 1. 즉시 롤백
```bash
# 서비스 중단
docker-compose down

# 이전 커밋으로 롤백
git log --oneline -10  # 이전 커밋 확인
git checkout <previous-commit-hash>

# 환경 설정 복원
cp .env.backup.<timestamp> .env

# 서비스 재시작
docker-compose up -d
```

### 2. 데이터베이스 롤백 (필요시)
```bash
# MongoDB 백업 복원
docker-compose exec mongo mongorestore --drop /data/backup/<backup-date>
```

## 📋 배포 체크리스트

### 배포 전
- [ ] 코드 변경사항 검토 완료
- [ ] 로컬 테스트 완료
- [ ] 백업 생성
- [ ] 점검 시간 공지 (필요시)

### 배포 중
- [ ] SSH 연결 확인
- [ ] 최신 코드 가져오기
- [ ] 환경 설정 확인
- [ ] Docker 이미지 업데이트
- [ ] 서비스 재시작
- [ ] Health Check 수행

### 배포 후
- [ ] 애플리케이션 접근 확인
- [ ] 주요 기능 테스트
- [ ] 로그 모니터링
- [ ] 성능 확인
- [ ] 배포 완료 기록

## 📝 배포 기록

배포할 때마다 다음 정보를 기록하는 것을 권장합니다:

```bash
# 배포 기록 파일 생성
cat >> deployment-history.md << EOF

## $(date +'%Y-%m-%d %H:%M:%S') - 배포

### 변경사항
- $(git log --oneline -1)

### 배포한 사람
- $(whoami)

### 이슈
- 없음

---
EOF
```

## 🆘 긴급 상황 대응

### 서비스 완전 중단
```bash
# 모든 컨테이너 강제 종료
docker-compose kill

# 시스템 리부트 (최후 수단)
sudo reboot
```

### 데이터 손실 방지
```bash
# 긴급 백업
docker-compose exec mongo mongodump --out /data/emergency-backup-$(date +%Y%m%d_%H%M%S)

# 볼륨 백업
docker run --rm -v librechat_mongo-data:/data -v $(pwd):/backup ubuntu tar czf /backup/mongo-backup-$(date +%Y%m%d_%H%M%S).tar.gz /data
```

이 가이드를 따라 안전하고 체계적으로 배포를 수행하시기 바랍니다.
