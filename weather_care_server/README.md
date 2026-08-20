# 날씨챙겨 Server

Cloudflare Workers + TypeScript + Hono + D1 기반의 서버 뼈대입니다.

날씨 원본 데이터는 공공데이터포털의
[기상청 단기예보 조회서비스](https://www.data.go.kr/data/15084084/openapi.do)를 사용합니다.

## API

- `GET /api/v1/weather/today?nx=60&ny=121`
- `GET /api/v1/weather/weekly?nx=60&ny=121`
- `GET /api/v1/weather/comparison/yesterday?nx=60&ny=121`
- `GET /api/v1/weather/comparison/last-year?nx=60&ny=121`
- `PUT /api/v1/installations/{installationId}`
- `PUT /api/v1/installations/{installationId}/notification-settings`
- `GET /api/v1/notification-settings?installationId=...`
- `PUT /api/v1/notification-settings/{installationId}`

## 실행

먼저 공공데이터포털에서 단기예보 조회서비스 활용신청 후 발급받은 일반 인증키를
로컬 Secret 파일에 저장합니다. `.dev.vars`는 Git에서 제외되어 있습니다.

```bash
cp .dev.vars.example .dev.vars
```

`.dev.vars`의 `KMA_SERVICE_KEY` 값을 실제 키로 교체한 뒤 실행합니다.

```bash
cd weather_care_server
npm install
npm run db:migrate
npm run dev -- --ip 0.0.0.0 --port 8787
```

`db:migrate`는 로컬 D1에 `weather_cache`를 포함한 필수 테이블을 생성합니다.
Android 에뮬레이터는 호스트의 이 서버를 `http://10.0.2.2:8787`로 접근합니다.

운영 Worker에는 키를 소스나 `wrangler.toml`에 넣지 않고 다음 명령의 대화형
입력으로 등록합니다.

```bash
npx wrangler secret put KMA_SERVICE_KEY
npm run deploy
```

## 핵심 구조

- `src/rules/*`: 날씨 데이터 -> RuleFact
- `src/lifestyle/*`: RuleFact -> LifestyleInsight + 생활 문구 카탈로그
- `src/recommendations/*`: Insight + 사용자 설정 -> Recommendation + 준비물 문구 카탈로그
- `src/notification/*`: 추천 결과의 push payload 생성
- `src/database/*`: D1 저장/조회 함수
- `src/providers/weather/kmaWeatherProvider.ts`: 기상청 응답 검증·정규화
- `migrations/0001_init.sql`: 테이블 DDL

`/weather/today`는 현재/추천과 함께 Detail 탭용 `hourly` 배열과
`dataSource=기상청 단기예보`를 반환합니다. `/weather/weekly`는 단기예보가 제공하는
오늘부터 글피까지의 날짜만 반환하며 가짜 날짜를 채우지 않습니다. 기상청 단기예보에
없는 미세먼지와 자외선은 현재 결측값으로 유지합니다.
