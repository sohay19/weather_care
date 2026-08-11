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
cd server
npm install
npm run dev
```

## 핵심 구조

- `src/rules/*`: 날씨 데이터 -> RuleFact
- `src/lifestyle/*`: RuleFact -> LifestyleInsight
- `src/recommendations/*`: Insight + 사용자 설정 -> Recommendation
- `src/notification/*`: 추천 결과의 push payload 생성
- `src/database/*`: D1 저장/조회 함수
- `migrations/0001_init.sql`: 테이블 DDL

