# 날씨챙겨 Server

Cloudflare Workers + TypeScript + Hono + D1 기반의 서버 뼈대입니다.

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

```bash
cd weather_care_server
npm install
npm run db:migrate
npm run dev -- --ip 0.0.0.0 --port 8787
```

`db:migrate`는 로컬 D1에 `weather_cache`를 포함한 필수 테이블을 생성합니다.
Android 에뮬레이터는 호스트의 이 서버를 `http://10.0.2.2:8787`로 접근합니다.

## 핵심 구조

- `src/rules/*`: 날씨 데이터 -> RuleFact
- `src/lifestyle/*`: RuleFact -> LifestyleInsight + 생활 문구 카탈로그
- `src/recommendations/*`: Insight + 사용자 설정 -> Recommendation + 준비물 문구 카탈로그
- `src/notification/*`: 추천 결과의 push payload 생성
- `src/database/*`: D1 저장/조회 함수
- `migrations/0001_init.sql`: 테이블 DDL

`/weather/today`는 현재/추천과 함께 Detail 탭용 `hourly` 배열을 반환합니다. 시간대별 판단 기준과 문구 운영 규칙은 서버 개발명세 22~24장을 따릅니다.
