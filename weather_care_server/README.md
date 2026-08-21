# 날씨챙겨 Server

Cloudflare Workers + TypeScript + Hono + D1 기반의 서버 뼈대입니다.

날씨·환경 원본 데이터는 공공데이터포털의 다음 서비스를 사용합니다.

- [기상청 단기예보 조회서비스](https://www.data.go.kr/data/15084084/openapi.do)
- [기상청 생활기상지수 조회서비스](https://www.data.go.kr/data/15085288/openapi.do) V5 `getUVIdxV5`
- [한국환경공단 에어코리아 대기오염정보](https://www.data.go.kr/data/15073861/openapi.do)

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

먼저 공공데이터포털에서 단기예보, 생활기상지수(5.0), 에어코리아 대기오염정보를 각각 활용신청한 뒤 발급받은 일반 인증키를
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
- `src/providers/uv/kmaUvProvider.ts`: 생활기상지수 V5 자외선 3시간 예측 정규화
- `src/providers/air/airKoreaAirQualityProvider.ts`: 에어코리아 PM10·PM2.5·오존 실시간 관측 정규화
- `src/providers/environmental/environmentalDataService.ts`: 환경 데이터 캐시·부분 실패·Today 병합
- `src/regions/regionCatalog.ts`: 격자별 자외선 행정코드와 에어코리아 측정소 매핑
- `migrations/0001_init.sql`: 테이블 DDL

`/weather/today`는 기상청 단기예보와 자외선·대기질을 병합해 `current.uvIndex`, `current.pm10`, `current.pm25`, `current.ozone`을 반환합니다. 자외선 예측은 해당 시간의 `hourly[].uvIndex`에도 병합하고, 실시간 대기질 관측값은 미래를 의미하지 않으므로 `current`와 첫 시간 슬롯에만 적용합니다.

`environmentalSources.uv` / `environmentalSources.airQuality`은 각각 `AVAILABLE`, `CACHED`, `STALE`, `UNAVAILABLE`, `UNSUPPORTED_REGION` 상태를 제공합니다. D1 캐시는 자외선 2시간, 대기질 30분을 신선 기준으로 사용하고, 새 조회 실패 시 자외선 최대 8시간·대기질 최대 3시간의 이전 값만 `STALE`로 허용합니다. 환경 Provider가 실패해도 단기예보가 정상이면 Today API는 200을 유지합니다.

`current.apparentTemperature`와 `hourly[].apparentTemperature`는 [기상청 공식 체감온도 산식](https://data.kma.go.kr/climate/windChill/selectWindChillChart.do)을 사용합니다. 5~9월은 기온·상대습도·Stull 습구온도 기반 여름 산식, 10~익년 4월은 기온 10℃ 이하·풍속 1.3m/s 이상일 때 겨울 풍속냉각 산식을 적용합니다. 앱의 표현 경계와 연구 근거는 [`docs/체감온도_표현_기준.md`](../docs/체감온도_표현_기준.md)에 있습니다.

현재 환경 지역 카탈로그는 앱에서 사용하는 수원 `60:121`(자외선 `4111000000`, 인계동 측정소)와 검증용 서울 `60:127`(자외선 `1100000000`, 종로구 측정소)를 지원합니다. 지역 선택 기능을 확장할 때 행정코드와 측정소를 카탈로그에 함께 등록해야 합니다.

`/weather/weekly`는 단기예보가 제공하는 오늘부터 글피까지의 날짜만 반환하며 가짜 날짜를 채우지 않습니다.
