# 운영 SSH 진단 접속 안내

이 진단은 완료됐고 아래 임시 공개키 등록과 로컬 키는 제거했습니다. 아래 명령은 당시 접속 준비 기록입니다.

시흥시 은행동의 수집 실패 원인을 확인하려면 운영 서버의 스케줄러 로그, API 사용량 및 자료 저장 시각을 읽어야 합니다. 현재 이 PC의 SSH 공개키 인증이 거절되어 임시 공개키 등록이 필요합니다.

## 사용자 실행 순서

1. PowerShell에서 기존 방법으로 서버에 접속합니다. 이미 `ubuntu@soha-01` 서버 셸에 접속했다면 이 단계는 생략합니다.

```powershell
ssh ubuntu@soha-01
```

2. 아래 명령 전체를 **접속한 Ubuntu 서버 셸**에서 실행합니다.

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'restrict,expiry-time="20261003181247Z" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP2oJF34lhtx2+rdhJcSjUIG1aNrqmJ2jLHU8WMr6iHe weather-care-diagnose-20261003-2312' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

3. 채팅에 `등록 완료`라고 알려주세요. 로그인 비밀번호와 개인키 내용은 보내지 않습니다.

## 접속 범위와 정리

- 이 키는 포트 포워딩과 PTY 등 SSH 기능을 제한하며, 2026년 10월 4일 오전 3시 12분 47초(한국 시각)에 만료됩니다. 셸 명령 실행 자체를 읽기 전용으로 강제하는 키는 아닙니다.
- 접속 후에는 서비스 실행 상태, 수집 실패 로그, 운영 DB의 API 예약량과 캐시 갱신 시각을 조회합니다. 원인 조사 단계에서 운영 코드·DB 값·서비스 설정은 수정하지 않습니다.
- 조사 종료 후 이번 공개키 등록과 로컬 임시키를 제거합니다. 기존 접속키와 사용자가 열어 둔 SSH 세션은 유지합니다.
