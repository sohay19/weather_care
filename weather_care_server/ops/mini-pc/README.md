# 미니 PC 이전 운영 절차

이 디렉터리는 기존 Cloudflare Worker를 즉시 제거하지 않고, 같은 Hono 앱과 수집
로직을 Node.js + SQLite에서 검증한 뒤 전환하기 위한 파일을 담습니다. 앱 API 계약과
발표 주기 기반 수집 로직은 Worker와 Node 런타임이 같은 소스를 사용합니다.

## 운영 전제

- Node.js 22 이상을 사용합니다. 권장은 현재 LTS입니다.
- API는 기본값인 `127.0.0.1:8787`에만 바인딩하고 Cloudflare Tunnel로 공개합니다.
- SQLite DB, 백업, 환경변수 파일은 Git 저장소 밖에 둡니다.
- Worker Cron과 미니 PC 스케줄러를 동시에 실행하지 않습니다. 동시에 실행하면
  기상청 APIHub 호출·전송량이 중복되어 현재 최적화와 일일 예산을 훼손합니다.
- Flutter `SERVER_URL`은 미니 PC의 병행 검증이 끝날 때까지 기존 Worker URL을
  유지합니다.

## 1. 서버 설치

아래 경로를 기준으로 제공된 systemd 파일이 작성되어 있습니다. 다른 경로를 쓰면
각 유닛의 `WorkingDirectory`를 함께 바꿉니다.

```bash
sudo useradd --system --home /opt/weather-care --shell /usr/sbin/nologin weather-care
sudo mkdir -p /opt/weather-care /etc/weather-care /var/lib/weather-care /var/backups/weather-care
sudo chown -R weather-care:weather-care /opt/weather-care /var/lib/weather-care /var/backups/weather-care
sudo install -o root -g weather-care -m 0640 \
  ops/mini-pc/weather-care.env.example /etc/weather-care/weather-care.env
```

저장소를 `/opt/weather-care`에 배치한 뒤 의존성을 설치합니다.

```bash
cd /opt/weather-care/weather_care_server
sudo -u weather-care npm ci --omit=dev
```

`/etc/weather-care/weather-care.env`의 모든 자리표시자를 운영 Secret으로 바꿉니다.
Private Key의 줄바꿈은 기존 Worker Secret과 같이 `\\n` 문자열로 저장할 수 있습니다.

## 2. D1 스냅샷으로 로컬 검증

먼저 운영 Worker와 Cron을 그대로 둔 상태에서 읽기 전용 검증용 스냅샷을 만듭니다.
이 파일에는 설치 식별자와 FCM 토큰 등 개인정보가 포함될 수 있으므로 외부에
공유하지 않고, 권한을 `0600`으로 제한하며 7일 안에 삭제합니다.

Wrangler 로그인이 설정된 개발 PC에서 내보낸 뒤 암호화된 경로로 미니 PC의
`/var/lib/weather-care/d1-shadow.sql`에 전달합니다.

```bash
npx wrangler d1 export weather_care_db --remote --output=./d1-shadow.sql
```

미니 PC에서는 내보낸 파일만 가져옵니다.

```bash
cd /opt/weather-care/weather_care_server
sudo -u weather-care env \
  NODE_DATABASE_PATH=/var/lib/weather-care/weather-care.sqlite \
  npm run node:db:import -- /var/lib/weather-care/d1-shadow.sql
sudo -u weather-care env \
  NODE_DATABASE_PATH=/var/lib/weather-care/weather-care.sqlite \
  npm run node:db:migrate
```

이 단계에서는 `node:scheduler`를 실행하지 않습니다. `node:server`만 로컬에서 띄워
`/health`, `/main`, `/today`, `/weekly`, `/comparison/yesterday` 응답을 기존 Worker와
비교합니다. `generatedAt`처럼 요청 시각에 따라 달라지는 필드는 제외하고 응답 계약과
자료 기준시각을 확인합니다.

## 3. systemd 등록

```bash
sudo cp ops/mini-pc/systemd/*.service ops/mini-pc/systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now weather-care-migrate.service
sudo systemctl enable --now weather-care-api.service
sudo systemctl enable --now weather-care-backup.timer
```

API와 백업까지만 먼저 켭니다. 스케줄러는 최종 수집 주체 전환 때 켭니다.

```bash
curl --fail http://127.0.0.1:8787/health
systemctl status weather-care-api.service weather-care-backup.timer
```

## 4. Cloudflare Tunnel 연결

Cloudflare Tunnel은 미니 PC에서 외부 방향 연결을 만들기 때문에 공유기의 공개 포트를
열 필요가 없습니다. `cloudflared`를 설치하고 Tunnel과 공개 호스트명을 만든 뒤,
예시 설정의 UUID·호스트명·자격증명 경로를 실제 값으로 바꿉니다.

```bash
sudo install -o root -g root -m 0644 \
  ops/mini-pc/cloudflared-config.example.yml /etc/cloudflared/config.yml
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

외부 호스트명의 `/health`와 주요 읽기 API를 확인하되 앱 URL은 아직 바꾸지 않습니다.
공식 문서는 [Hono Node.js 어댑터](https://hono.dev/docs/getting-started/nodejs)와
[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)을 참고합니다.

## 5. 최종 전환

최종 전환은 쓰기 누락을 막기 위해 짧은 점검 창에서 진행합니다.

1. 앱 배포 전환 전 운영 D1을 다시 백업합니다.
2. Worker에 `LEGACY_ORIGIN_URL=https://새-API-호스트명`을 설정한 전환 버전을
   배포합니다. 이 모드에서는 구버전 앱 요청을 Node API로 전달하고 Worker Cron은
   자동으로 종료됩니다.
3. Worker의 쓰기를 잠시 막은 뒤 최신 D1 스냅샷을 `weather-care-cutover.sqlite`처럼
   새 파일로 가져오고 `/etc/weather-care/weather-care.env`의
   `NODE_DATABASE_PATH`를 새 파일로 바꿉니다. 기존 shadow DB를 덮어쓰지 않습니다.
4. `weather-care-api`와 `weather-care-scheduler`를 시작하고 첫 10분·15분·30분 작업의
   성공 로그와 `api_usage_daily` 증가량을 확인합니다.
5. Tunnel API와 Worker API의 응답 계약을 다시 비교합니다.
6. Flutter `SERVER_URL`을 Tunnel 호스트명으로 바꾸고 단계적으로 배포합니다. 이미
   설치된 구버전 앱은 `workers.dev` 브리지를 통해 계속 같은 Node API를 사용합니다.
7. 안정화 기간에는 Worker 코드와 D1 백업을 롤백 경로로 보존하되 Worker Cron은
   계속 꺼 둡니다.

`LEGACY_ORIGIN_URL`은 소스나 `wrangler.toml`에 저장하지 않고 전환 시 Worker
Secret으로 등록합니다.

```bash
npx wrangler secret put LEGACY_ORIGIN_URL
npx wrangler deploy --keep-vars --strict --message "미니 PC API 전환 브리지"
```

브리지 배포 뒤 Wrangler의 Cron 설정 자체는 남아 있어도 `scheduled` 핸들러가 즉시
종료하므로 외부 제공자를 호출하지 않습니다. 운영 로그와 `api_usage_daily`로 실제
중복 수집이 없는지 확인한 뒤 Node 스케줄러를 켭니다.

스케줄러 전환 명령은 다음과 같습니다.

```bash
sudo systemctl enable --now weather-care-scheduler.service
journalctl -u weather-care-scheduler.service -f
```

## 6. 백업과 복구

`weather-care-backup.timer`는 매일 03:30 KST에 SQLite Online Backup을 실행하고
기본 7일을 보관합니다. 복구 시 API와 스케줄러를 먼저 중지한 뒤 검증된 백업을
`NODE_DATABASE_PATH` 위치에 복사합니다.

```bash
sudo systemctl stop weather-care-scheduler.service weather-care-api.service
sudo systemctl start weather-care-backup.service
```

## 롤백 기준

- 첫 수집 주기에서 자료 기준시각이 갱신되지 않음
- APIHub 예약량이 기존 예상보다 중복 증가함
- 설치 등록·설정 저장·FCM 발송 중 하나라도 기존 API 계약과 다름
- Tunnel 외부 헬스 체크가 반복 실패함

이 경우 앱 URL은 기존 Worker로 유지하거나 되돌리고 Node 스케줄러를 끕니다. Worker
`LEGACY_ORIGIN_URL`을 제거해 기존 API와 Cron을 되살리기 전 Node 스케줄러가 완전히
종료됐는지 반드시 확인합니다.
