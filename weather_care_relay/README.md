# Weather Care ITS relay

Cloudflare Worker에서 직접 연결되지 않는 국가교통정보센터 ITS `9443` API를
대한민국의 Ubuntu 서버를 통해 조회하는 전용 중계 서비스다.

## 보안 경계

- 서비스는 기본적으로 `127.0.0.1:8788`에만 바인딩한다.
- 외부에는 Tailscale Funnel의 HTTPS 주소만 노출한다.
- `/v1/its/event-info`는 32자 이상의 Bearer 토큰이 반드시 필요하다.
- 사용자 좌표가 URL 접근 로그에 남지 않도록 좌표는 POST JSON 본문으로 받는다.
- 대한민국 범위의 작은 검색영역만 허용하고 요청·응답 크기를 제한한다.
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
```

환경파일 권한은 `root:root`, `600`으로 제한한다. 서비스 계정은 로그인할 수 없는
전용 시스템 계정 `weather-care-relay`를 사용한다.

서비스가 정상화된 뒤 Funnel을 백그라운드로 연결한다.

```bash
sudo tailscale funnel --bg 8788
tailscale funnel status
```

출력된 `https://...ts.net` 주소를 Worker의 `ITS_RELAY_URL`에 등록한다. 같은
`RELAY_TOKEN` 값은 Worker의 `ITS_RELAY_TOKEN` Secret으로 등록한다.
