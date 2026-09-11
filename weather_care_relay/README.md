# Weather Care ITS relay

Cloudflare Worker에서 직접 연결되지 않는 국가교통정보센터 ITS `9443` API를
대한민국의 Ubuntu 서버를 통해 조회하는 전용 중계 서비스다.

## 보안 경계

- 서비스는 기본적으로 `127.0.0.1:8788`에만 바인딩한다.
- 외부에는 Tailscale Funnel의 HTTPS 주소만 노출한다.
- `/v1/its/event-info`는 32자 이상의 Bearer 토큰이 반드시 필요하다.
- 사용자 좌표가 URL 접근 로그에 남지 않도록 좌표는 POST JSON 본문으로 받는다.
- 대한민국 범위의 작은 검색영역만 허용하고 요청·응답 크기를 제한한다.
- ITS 전국 돌발상황을 기본 1시간 동안 메모리에 보관하고 요청 위치 자료만 반환한다.
- ITS API 키와 중계 토큰은 저장소나 로그에 기록하지 않는다.

## 로컬 실행

Node.js 20 이상이 필요하다.

```bash
npm ci
npm run build
ITS_API_KEY='...' RELAY_TOKEN='32자 이상의 임의 토큰' npm start
```

확인:

```bash
curl -sS http://127.0.0.1:8788/health
sudo /opt/weather-care-relay/deploy/smoke-test.sh
```

## Ubuntu 운영 경로

- 앱: `/opt/weather-care-relay`
- 환경파일: `/etc/weather-care-relay.env`
- systemd 서비스: `/etc/systemd/system/weather-care-relay.service`

환경파일 형식:

```dotenv
ITS_API_KEY=발급받은_국가교통정보센터_키
RELAY_TOKEN=32자_이상의_무작위_토큰
HOST=127.0.0.1
PORT=8788
ITS_CACHE_TTL_MS=3600000
```

`ITS_CACHE_TTL_MS` 기본값 1시간은 월 1,000건 호출 한도에서 상시 운영해도
월 최대 약 720회만 공식 ITS API를 조회하도록 잡은 값이다. 중계 프로세스 안에서
동시에 들어온 요청은 하나의 전국 조회를 공유하고, 각 응답에는 요청한 좌표 범위의
자료만 포함한다.

환경파일 권한은 `root:root`, `600`으로 제한한다. 서비스 계정은 로그인할 수 없는
전용 시스템 계정 `weather-care-relay`를 사용한다.

서비스가 정상화된 뒤 Funnel을 백그라운드로 연결한다.

```bash
sudo tailscale funnel --bg 8788
tailscale funnel status
```

출력된 `https://...ts.net` 주소를 Worker의 `ITS_RELAY_URL`에 등록한다. 같은
`RELAY_TOKEN` 값은 Worker의 `ITS_RELAY_TOKEN` Secret으로 등록한다.

## 릴레이 로그만 3일 보관

사용자 확정 및 운영 설정 확인: 2026-09-11. 사용자 실행 결과에서 **health 200,
relay active, 전용 LogNamespace, 3day 설정 및 타이머 예약**을 확인했다.
정리 oneshot의 종료 결과와 3일 경과 로그 삭제 실증은 별도 미확인이다.
systemd 245 이상에서 전용 journal namespace를 사용한다. 공용 journal/rsyslog 설정,
환경파일, 과거 공용 로그는 변경하거나 삭제하지 않는다. 설치 시 릴레이가 한 번
재시작되어 진행 중인 요청이 끊길 수 있다.

현재 PC의 PowerShell에서 배포 파일만 Ubuntu 홈으로 복사한다(인증은 직접 입력).

```powershell
scp -r D:/IdeaProjects/weather_care/weather_care_relay/deploy ubuntu@100.105.212.26:weather-care-log-setup
```

Ubuntu에서 다음을 실행한다. 기존 설치 대상 파일이 있으면 덮어쓰지 않고 중단한다.

```bash
sudo bash ~/weather-care-log-setup/install-relay-logging.sh
curl --fail --silent --show-error http://127.0.0.1:8788/health
sudo systemctl show weather-care-relay.service -p LogNamespace -p StandardOutput -p StandardError
sudo systemd-analyze cat-config systemd/journald@weather-care-relay.conf
sudo systemctl list-timers weather-care-relay-log-prune.timer --all
sudo journalctl --namespace=weather-care-relay -u weather-care-relay.service --since '-5min' --no-pager
```

기대값은 `LogNamespace=weather-care-relay`, 출력 두 항목 `journal`, 건강 확인 성공,
전용 journal의 `relay_listening` 이벤트 및 정리 타이머의 다음 실행시각이다.
합성 설정에 다른 drop-in이 기간/전달 설정을 덮어쓰는지 반드시 확인한다.
로그 원문이나 환경파일을 채팅에 붙이지 않는다. 커스텀 포트를 쓰면 health 주소를 맞춘다.

- `MaxRetentionSec=3day`, 파일 회전 15분, 정리 타이머 15분(정밀도 1분).
  삭제는 파일 단위이므로 정상 가동 중에도 회전·정리 지연이 있다. 정확히 72시간에
  개별 기록이 즉시 사라진다는 보장은 아니며 서버 정지 시 다음 실행까지 지연된다.
- 전용 journal 용량 목표는 32MiB(런타임 16MiB)여서 공간에 따라 더 일찍 지워질 수 있다.
- syslog·커널·콘솔·wall 전달은 끈다. 별도 외부 수집기가 namespace를 읽는지는 별도 확인 대상이다.
- 적용 전 공용 로그는 기존 보관 규칙으로 남는다. 서비스 시작/종료 등 systemd 관리자
  자체 메시지도 공용 journal에 남을 수 있으므로 모든 시스템 기록의 3일 삭제 정책은 아니다.

설치 도중 오류면 새 설정 파일만 자동 제거하고 기존 서비스 재시작을 시도한다.
성공 후 수동 복구가 필요하면 **이번 설치 파일이 이후 변경되지 않았는지 확인 후** 실행한다.
로그 파일은 삭제하지 않으며 복구하면 이후 서비스 출력은 다시 공용 journal로 들어간다.

```bash
sudo systemctl disable --now weather-care-relay-log-prune.timer
sudo rm -- /etc/systemd/system/weather-care-relay.service.d/30-relay-journal.conf /etc/systemd/journald@weather-care-relay.conf /etc/systemd/system/weather-care-relay-log-prune.service /etc/systemd/system/weather-care-relay-log-prune.timer
sudo systemctl daemon-reload
sudo systemctl restart weather-care-relay.service
curl --fail --silent --show-error http://127.0.0.1:8788/health
```

근거: [systemd journalctl 공식 문서](https://github.com/systemd/systemd/blob/v255/man/journalctl.xml),
[journald 설정 공식 문서](https://www.freedesktop.org/software/systemd/man/252/journald.conf.html).
