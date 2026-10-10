# 운영 SSH 상시 접속 안내

사용자 요청으로 이 Windows PC에서 계속 사용하는 ED25519 키를 만들었다. 임시 키처럼 만료되거나 조사 종료 후 삭제되지 않는다. 2026년 10월 4일 서버 공개키 등록과 비대화형 SSH 인증 성공을 확인했다.

- 개인키: `C:\Users\SOHA\.ssh\weather-care-soha-pc`
- 공개키: 같은 경로의 `.pub` 파일
- SSH 설정: `C:\Users\SOHA\.ssh\config`, 별칭 `weather-care`
- 대상: `ubuntu@soha-01` (Tailscale)
- 개인키는 암호 없이 자동 접속에 사용하며 Windows 파일 권한을 현재 사용자 읽기로 제한했다. 개인키 내용은 공유하지 않는다.

## 최초 등록

PowerShell에서 기존 방법으로 접속한다. 이미 서버 셸이 열려 있으면 생략한다.

```powershell
ssh ubuntu@soha-01
```

접속한 **Ubuntu 서버 셸**에서 아래 명령을 실행한다. 같은 명령을 다시 실행해도 키가 중복 등록되지 않으며 기존 키를 보존한다.

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdxI4FaW5GgSust5BuurJscv4TXgC2EIKF2dnJuImN4 weather-care-soha-pc'
grep -qxF "$key" ~/.ssh/authorized_keys 2>/dev/null || printf '%s\n' "$key" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

등록 후 이 PC의 PowerShell에서 다음 명령으로 접속한다.

```powershell
ssh weather-care
```

키 인증은 계속 유지된다. 연결이 끊어지거나 PC를 재시작하면 같은 명령으로 재접속한다. Tailscale과 서버 SSH 서비스가 실행 중이어야 한다. 이 등록은 ubuntu 계정의 일반 SSH 셸 접근을 허용하며 운영 코드 배포나 서비스 변경 자체를 수행하지 않는다.
