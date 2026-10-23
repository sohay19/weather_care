# API 활용기간 갱신 안내 메일

사용자가 2026-10-23 제공한 공공데이터포털의 15개 활용신청을 등록한다.
실제 API 인증키를 저장하거나 만료된 키를 재발급하는 기능은 없다.
Gmail SMTP로 `sy40222@gmail.com`에서 같은 주소로 안내 메일을 보낸다.

| 안내일 오전 9시(한국시간) | 등록된 만료 예정일 | 대상 |
| --- | --- | --- |
| 2028-10-03 | 2028-10-10 | 기상청 중기예보·생활기상지수·단기예보 3개(운영) |
| 2028-10-06 | 2028-10-13 | 기상청 꽃가루농도위험지수 1개(개발) |
| 2028-10-07 | 2028-10-14 | K-water 수문 운영·댐코드·우량수위 및 해양조사원 조위·부이·고저조·조석 시계열·ROMS·이안류 9개(개발) |
| 2028-10-13 | 2028-10-20 | 에어코리아 측정소정보·대기오염정보 2개(운영) |

## 동작

- 독립 systemd 타이머가 매일 오전 9시 확인한다. 날씨 API·수집기와 실행 파일·DB·환경 파일을 분리한다.
- `Persistent=true`로 중지 기간의 예약을 보충한다. 안내일을 넘겼어도 미발송이면 다음 실행에 안내한다. 실제 실행은 부팅·네트워크·시스템 상태로 지연될 수 있다.
- 같은 만료일의 미발송 서비스를 한 통에 묶는다. 서비스 ID·만료일·수신자를 SQLite에 기록하여 정상 발송 이후 반복 실행·재시작 때 중복을 막는다. 실패한 묶음은 성공으로 기록하지 않으며 systemd가 한 시간 후 재시도한다.
- 전송 중 전용 SQLite 쓰기 잠금으로 수동 실행과 타이머의 동시 발송을 막는다. SMTP 접수 직후 DB 기록 전에 프로세스가 종료되거나 서버 응답이 유실되면 재시도에 중복될 수 있다. 동일 Message-ID를 사용하지만 메일 제공자의 중복 제거를 보장하지 않는다.
- SMTP 접수는 받은편지함 도착 확인과 다르다. 스팸·반송·발신 제한은 수신함과 Gmail 계정에서 확인해야 한다.
- 갱신 후 `/etc/weather-care/api-renewals.json`의 해당 `expiresOn`을 실제 새 만료일로 바꾼다. 타이머가 다음 실행에 다시 읽으므로 재시작은 필요 없다. 자동으로 2년을 더하거나 포털의 갱신 완료 여부를 추정하지 않는다.
- 서버 시간 자체를 2028년으로 바꿔 시험하지 않는다. 테스트는 주입한 시각과 격리 DB·모의 발송기를 사용한다.

## 배치 경로

| 용도 | 미니 PC 경로 |
| --- | --- |
| 실행 파일 | `/opt/weather-care-api-renewal/reminder.cjs` |
| 비표시 Gmail 설정 도구 | `/opt/weather-care-api-renewal/configure-gmail.py` |
| 신청별 만료일·수신자 | `/etc/weather-care/api-renewals.json` |
| SMTP 인증정보 | `/etc/weather-care/api-renewal.env` (root 소유, weather-care 그룹 읽기, 0640) |
| 전용 발송 이력 | `/var/lib/weather-care-api-renewal/state.sqlite` |
| 예약 | `weather-care-api-renewal.timer` |
| 실행·재시도 | `weather-care-api-renewal.service` |

`NODE_PATH`는 기존 운영 릴리스의 `better-sqlite3`만 참조한다. 메일러와 설정 검증기는 번들에 포함한다.
번들 실행에는 기존 서버와 같은 Node.js 24를 사용한다. 기존 날씨 서비스·DB에 새 스키마를 적용하지 않는다.

## Gmail 앱 비밀번호 입력과 최종 활성화

Google 계정에서 2단계 인증을 사용하고 [앱 비밀번호](https://myaccount.google.com/apppasswords)를 발급한다.
개인용 Gmail이라도 계정 보안 정책에 따라 앱 비밀번호 발급이 제한될 수 있다.
일반 Google 로그인 비밀번호나 앱 비밀번호를 채팅·저장소·명령행 인수로 전달하지 않는다.

현재 Windows PC의 PowerShell에서 다음을 실행한다.

```powershell
ssh -t -i "$env:USERPROFILE\.ssh\id_ed25519_weather_care" ubuntu@100.105.212.26 'sudo /opt/weather-care-api-renewal/configure-gmail.py'
```

입력은 표시되지 않는다. 도구가 SMTP 인증 및 설정 확인 메일 접수를 검증한 뒤,
현재 날짜의 점검을 실행하고 타이머를 활성화한다. 인증·발송 실패 시 기존 환경 파일을 복원한다.
API 키·Google 비밀번호·SMTP 응답 원문은 로그에 기록하지 않는다.
서버에서 재설정할 때도 같은 도구를 사용한다.

예약·최근 결과는 서버에서 다음으로 확인한다.

```bash
systemctl list-timers weather-care-api-renewal.timer --no-pager
systemctl status weather-care-api-renewal.service --no-pager
sudo journalctl -u weather-care-api-renewal.service -n 20 --no-pager
```

`oneshot` 실행의 정상 완료 후 `inactive (dead)`는 정상이며 `Result=success`·종료코드 0으로 확인한다.
SMTP 오류가 발생하면 코드만 출력하고 서비스는 실패 상태로 남아 한 시간 뒤 재시도한다.

## 로컬 검증·번들

```powershell
npm run typecheck
npm run test:node -- test-node/apiRenewalReminder.test.ts test-node/apiRenewalSmtp.test.ts
$env:API_RENEWAL_CONFIG_PATH = 'ops/api-renewal/api-renewals.json'
npm run node:api-renewal -- --preview
npm run build:api-renewal
```

`--preview`는 SMTP 연결·DB 생성·메일 발송 없이 등록 내역과 계산한 안내일만 출력한다.
`--verify-smtp`는 SMTP 연결·인증만 검사하고, `--test-email`은 실제 수신자에게 설정 확인용 메일 한 통을 보낸다.
두 모드는 발송 이력을 변경하지 않는다. 배포 시 `build/api-renewal/reminder.cjs`, 이 폴더의
설정 도구와 systemd 단위를 설치하고, JSON·환경 파일은 기존 파일이 있으면 덮어쓰지 않는다.
앱 비밀번호 미입력 상태에서는 타이머를 활성화하지 않는다.

### 2026-10-23 미니 PC 배치 확인

실행 번들·설정 도구·서비스/타이머·15개 신청 정보를 위 경로에 설치했다.
번들 SHA256은 `ccdd18de99a9bfe5558208ddedf0dd6dec4975cc7a3d43a7cb6984aa94c6079b`다.
서버의 weather-care 계정으로 실제 번들의 비발송 미리보기를 실행해 네 안내일과 15개 항목을 검증했다.
Gmail 465 TLS 연결·EHLO 250, systemd 단위 검증·한국시간 예약 해석, 설정 파일 0640을 확인했다.
SMTP 인증정보가 없으면 안전한 오류 코드로 중단한다. 최초 배치에서는 앱 비밀번호 미입력으로
타이머를 disabled/inactive로 두었으며, 아래 최종 활성화 기록을 현재 상태로 따른다.
기존 운영 API·스케줄러·Cloudflare Tunnel은 active, 로컬 `/health`는 HTTP 200이다.

로컬 타입 검사·번들 생성·전용 15개를 포함한 Node 전체 265개 테스트를 통과했다.
첫 전체 병렬 실행에서는 기존 HTTP 서버 기동 2개가 5초 제한에 걸렸으며,
동시 실행 수를 2개로 낮춘 재실행에서 265개 모두 통과했다. 기존 테스트의 제한시간·코드는 바꾸지 않았다.

### 2026-10-23 09:20 KST 발송 확인·예약 활성화

사용자가 앱 비밀번호 입력을 완료한 뒤 SMTP 인증 성공과 설정 확인 메일 1통의 Gmail 서버 접수를 확인했다.
받은편지함의 실제 도착 여부는 사용자 수신함에서 확인해야 한다. 정기 서비스는 09:20:11 KST에
정상 점검 완료했으며, 아직 안내일 전이므로 발송 대상 0개·정기 메일 0통이 정상이다.
전용 SQLite 무결성 검사는 `ok`이고 정기 발송 이력은 0건이다.

타이머는 `enabled / active(waiting)`, 다음 점검은 **2026-10-24 09:00 KST**이다.
기존 날씨 API·스케줄러·터널은 active이며 `/health` HTTP 200을 확인했다.

최초 가동 전 `systemctl reset-failed`가 로드되지 않은 oneshot 서비스를 대상으로 실패해
예약 활성화를 중단시키는 문제를 발견했다. 불필요한 이 명령을 설정 도구에서 제거하고
실제 서비스 시작→타이머 활성화를 완료했다. 수정한 도구의 Python 구문 검사와 서버/로컬
SHA256 `51ad2b1d5f51ea3ae00b35eb379e0fbfd9a7409ae2a5277da2817858c5110ac9` 일치를 확인했다.
SMTP 인증정보·기존 환경 파일·Node 실행 번들은 변경하지 않았다.

## 호출 응답으로 만료 확인

공공데이터포털의 공통 오류 `31 / DEADLINE_HAS_EXPIRED_ERROR`는 사용기한 만료를 의미한다.
응답 본문의 코드와 메시지를 확인해야 하며 HTTP 상태나 `401`·`403`만으로 만료라고 확정하지 않는다.
제공처에 따라 JSON·XML 오류나 세부 코드가 달라질 수 있다. 정상 자료 응답에서 신청의 만료 예정일을
제공하지 않으므로 7일 전 안내는 이 등록표를 사용한다.

기존 기상청 단기·중기 Provider는 `31`을 인증 실패로 취급한다. 이번 메일 서비스가 모든 Provider의
실제 만료 오류를 자동 구독하거나 추가 메일로 전송하는 것은 아니다.

- [공공데이터포털 공통 인증 오류 안내](https://www.data.go.kr/data/15061362/openapi.do)
- [Nodemailer SMTP 설정](https://nodemailer.com/smtp)
- [Google 앱 비밀번호 안내](https://support.google.com/accounts/answer/185833?hl=ko)
