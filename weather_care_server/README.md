# 날씨챙겨 Server

Cloudflare Workers + TypeScript + Hono + D1 기반의 서버 뼈대입니다.

날씨·환경 원본 데이터는 공공데이터포털의 다음 서비스를 사용합니다.

- [기상청 단기예보 조회서비스](https://www.data.go.kr/data/15084084/openapi.do)
- [기상청 중기예보 조회서비스](https://www.data.go.kr/data/15059468/openapi.do)
- [기상청 지상·AWS 일통계 관측자료](https://apihub.kma.go.kr/apiList.do?seqApi=2&seqApiSub=239)
- [기상청 생활기상지수 조회서비스](https://www.data.go.kr/data/15085288/openapi.do) V5 `getUVIdxV5`
- [한국환경공단 에어코리아 대기오염정보](https://www.data.go.kr/data/15073861/openapi.do)
- [국가교통정보센터 돌발상황정보](https://www.its.go.kr/opendata/opendataList?service=event)

## API

- `GET /api/v1/weather/main?nx=60&ny=121`
- `GET /api/v1/weather/today?nx=60&ny=121`
- `GET /api/v1/weather/weekly?nx=60&ny=121`
- `GET /api/v1/weather/comparison/yesterday?nx=60&ny=121`
- `GET /api/v1/weather/comparison/last-year?nx=60&ny=121`
- `PUT /api/v1/installations/{installationId}`
- `PUT /api/v1/installations/{installationId}/notification-settings`
- `GET /api/v1/notification-settings?installationId=...`
- `PUT /api/v1/notification-settings/{installationId}`

설치 등록과 신규 설치 자격·기존 설치 소유권 이전 요청은
`minimumAgeConfirmed: true`, `agePolicyVersion: 1`을 필수로 받습니다. 현재 정책 확인이
없는 기존 설치는 알림 대상에서 제외되며, 최신 앱에서 만 14세 이상 확인 후 다시
등록해야 알림이 재개됩니다.

## 실행

먼저 공공데이터포털에서 단기예보, 생활기상지수(5.0), 에어코리아 대기오염정보를 각각 활용신청한 뒤 발급받은 일반 인증키를
로컬 Secret 파일에 저장합니다. `.dev.vars`는 Git에서 제외되어 있습니다.

```bash
cp .dev.vars.example .dev.vars
```

`.dev.vars`의 `KMA_SERVICE_KEY`와 Firebase 서비스 계정 JSON의
`client_email`, `private_key`를 각각 `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`로
교체합니다. 현재 위치의 500m 강수 판정과 실제 발효 특보 조회에는 기상청
API허브에서 중기예보·지상·AWS 일통계·고해상도 격자자료·레이더·기상특보·도로위험기상정보 API 활용신청 후 발급된
`KMA_APIHUB_KEY`도 필요합니다.
현재 시행 중인 도로 통제를 조회하려면 국가교통정보센터에서 돌발상황정보
Open API 활용신청을 하고 발급받은 키를 홈서버 중계 서비스의 `ITS_API_KEY`에
저장해야 합니다. 운영 Worker에는 Tailscale Funnel의 HTTPS 주소와 같은 중계 토큰을
각각 `ITS_RELAY_URL`, `ITS_RELAY_TOKEN` Secret으로 저장합니다. 두 중계 Secret이
없을 때만 Worker의 기존 `ITS_API_KEY`를 직접 조회용으로 사용합니다.
Firebase 프로젝트 ID는 공개 설정값
`weather-care-2aaa8`로 고정되어 있습니다.

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
npx wrangler secret put KMA_APIHUB_KEY
npx wrangler secret put ITS_RELAY_URL
npx wrangler secret put ITS_RELAY_TOKEN
npx wrangler secret put FCM_CLIENT_EMAIL
npx wrangler secret put FCM_PRIVATE_KEY
npx wrangler d1 migrations apply weather_care_db --remote
npm run deploy
```

`ITS_API_KEY`를 Worker에 등록하는 방식은 중계 서비스가 없는 로컬 개발 또는 비상
직접조회에만 선택적으로 사용합니다.

## 핵심 구조

- `src/rules/*`: 날씨 데이터 -> RuleFact
- `src/lifestyle/*`: RuleFact -> LifestyleInsight + 생활 문구 카탈로그
- `src/recommendations/*`: Insight + 사용자 설정 -> Recommendation + 준비물 문구 카탈로그
- `src/notification/*`: 추천 결과 생성·중복 방지·FCM HTTP v1 전송
- `src/database/*`: D1 저장/조회 함수
- `src/providers/weather/kmaWeatherProvider.ts`: 기상청 응답 검증·정규화
- `src/providers/weather/kmaMidTermProvider.ts`: 06시 중기 기온·육상예보(4~10일) 검증·정규화
- `src/providers/weather/kmaDailyObservationProvider.ts`: 인근 지상·AWS 관측소의 지난 날 일 최저·최고기온·강수·적설 정규화
- `src/providers/uv/kmaUvProvider.ts`: 생활기상지수 V5 자외선 3시간 예측 정규화
- `src/providers/air/airKoreaAirQualityProvider.ts`: 에어코리아 PM10·PM2.5·오존 실시간 관측 정규화
- `src/providers/environmental/environmentalDataService.ts`: 환경 데이터 캐시·부분 실패·Today 병합
- `src/providers/precipitation/precipitationObservationProvider.ts`: 현재 위치의 500m 관측분석·레이더 일치 판정
- `src/providers/warnings/kmaWarningProvider.ts`: 기상청 발효시각 기준 특보현황 조회와 예비·미발효 자료 제외
- `src/providers/road/kmaRoadIceProvider.ts`: 고속도로 1km 구간별 도로살얼음 공식 단계와 현재 위치 거리 판정
- `src/providers/traffic/itsRoadControlProvider.ts`: 국가교통정보센터의 현재 돌발상황 중 위치 3km 안의 실제 차로·전면 통제 판정
- `src/regions/regionCatalog.ts`: 격자별 자외선 행정코드·대기질 측정소·특보구역 매핑
- `migrations/0001_init.sql`~`0011_central_weather_collection.sql`: 테이블 DDL, 사용자별 상태, 중앙 수집 캐시와 APIHub 일일 호출·용량 예산

`/weather/main`, `/weather/today`, `/weather/weekly`, `/weather/comparison`은 외부 제공자를 호출하지 않고 D1에 저장된 중앙 수집 결과만 읽습니다. 자료가 아직 없으면 `WEATHER_CACHE_NOT_READY` 503을 반환하며 요청 수에 따라 외부 API 호출이 늘어나지 않습니다.

Cron은 10분마다 활성 설치의 예보 격자를 중복 제거해 단기예보·환경·특보·강수를 수집합니다. 전국 500m 레이더는 한 번만 받아 모든 활성 좌표를 배치 판독하고, 공공데이터포털 초단기실황과 강수 판단이 다른 좌표만 APIHub 지점 관측분석으로 재검증합니다. 도로살얼음은 15분마다 12개 노선을 한 번씩만 받아 모든 좌표를 함께 판정합니다.

`/weather/today`는 기상청 단기예보와 자외선·대기질을 병합해 `current.uvIndex`, `current.pm10`, `current.pm25`, `current.ozone`을 반환합니다. 자외선 예측은 해당 시간의 `hourly[].uvIndex`에도 병합하고, 실시간 대기질 관측값은 미래를 의미하지 않으므로 `current`와 첫 시간 슬롯에만 적용합니다.

`environmentalSources.uv` / `environmentalSources.airQuality`은 각각 `AVAILABLE`, `CACHED`, `STALE`, `UNAVAILABLE`, `UNSUPPORTED_REGION` 상태를 제공합니다. D1 캐시는 자외선 2시간, 대기질 30분을 신선 기준으로 사용하고, 새 조회 실패 시 자외선 최대 8시간·대기질 최대 3시간의 이전 값만 `STALE`로 허용합니다. 환경 Provider가 실패해도 단기예보가 정상이면 Today API는 200을 유지합니다.

`current.apparentTemperature`와 `hourly[].apparentTemperature`는 [기상청 공식 체감온도 산식](https://data.kma.go.kr/climate/windChill/selectWindChillChart.do)을 사용합니다. 5~9월은 기온·상대습도·Stull 습구온도 기반 여름 산식, 10~익년 4월은 기온 10℃ 이하·풍속 1.3m/s 이상일 때 겨울 풍속냉각 산식을 적용합니다. 앱의 표현 경계와 연구 근거는 [`docs/체감온도_표현_기준.md`](../docs/체감온도_표현_기준.md)에 있습니다.

현재 환경 지역 카탈로그는 앱에서 사용하는 수원 `60:121`(자외선 `4111000000`, 인계동 측정소)와 검증용 서울 `60:127`(자외선 `1100000000`, 종로구 측정소)를 지원합니다. 지역 선택 기능을 확장할 때 행정코드와 측정소를 카탈로그에 함께 등록해야 합니다.

`/weather/weekly`는 지역 단기예보를 우선하고, 공식 일 최저·최고가 없는 겹침 날짜와 이후 빈 날짜를 중기 기온·육상예보로 보충합니다. 단기와 중기 Provider는 독립 처리해 한쪽이 실패해도 나머지 자료를 반환합니다. 지난 날짜는 예보격자 대표점에 가장 가까운 기상청 지상·AWS 관측소의 실제 일통계를 우선 반환하고, 관측 미수신 시에만 D1에 남은 `저장된 예보`를 보조로 사용합니다. 두 예보와 관측·저장 기록이 모두 없으면 날씨를 추정하지 않고 결측 상태를 반환합니다.

`/weather/today`의 현재 강수는 관측분석과 500m 레이더 일치를 선택 자료로 병합합니다. 레이더 합성장의 초기 로드가 공통 3.5초 제한을 넘어 정상 결과도 `null`로 반환되던 경로는 강수 전용 8초 대기로 분리했습니다. 전체 API 응답은 앱의 20초 제한 안에서 유지합니다.

알림 Cron은 10분마다 실행됩니다. 현재 만 14세 이상 정책 버전이 확인된 설치만
대상으로 삼고, 설치별 시간대와 알림 시간을 확인해 아침 브리핑을
한 번만 보내며, 중요한 대설 알림은 설정된 항목이 활성화된 경우 당일 최초 한 번
전송합니다. FCM 성공 응답을 받은 알림만 `notification_history`에 기록하고,
Firebase가 `UNREGISTERED`로 응답한 토큰은 설치 정보에서 제거합니다.
기상특보는 예비특보와 발효 예정 상태를 알리지 않습니다. 실제 발효된 주의보·
경보만 표시하고, 설치별 마지막 상태와 비교해 신규 발효·수준 변경·해제 때만
푸시합니다. 앱 화면과 푸시 본문 모두 직접행동을 공식 사실보다 먼저 배치합니다.

블랙아이스(도로살얼음)는 11월 15일~3월 15일에 제공되는 기상청 공식
`도로살얼음 발생 가능 정보`만 사용합니다. GPS에서 3km 이내인 지원 고속도로
1km 구간의 `관심 1·주의 2·위험 3`만 표시하며, 공식 파일의 `0`은 안전이 아닌
`정보없음`이므로 노출하지 않습니다. 표준노드링크의 시작·종료 좌표는 보존하지만
공식 방향명이 없으면 사용자용 방향을 임의로 만들지 않습니다.

출퇴근 경로 항목은 GPS에서 3km 이내인 국가교통정보센터 돌발상황 중 차단
차로나 통제가 명시되고 시작시각이 지났으며 종료되지 않은 자료만 표시합니다.
단순 사고·공사 정보만으로 통제를 추정하지 않습니다. 돌발상황정보에는 공식
우회도로 필드가 없으므로 특정 우회도로명을 만들지 않고, 전면 통제 때는 다른
경로와 대중교통 운행정보를 확인하도록 안내합니다. 같은 통제가 이어지는 동안은
푸시를 반복하지 않고 통제 종류가 바뀌거나 종료 후 다시 시작될 때만 새로 알립니다.

`/weather/today`와 `/weather/weekly`에 `installationId`를 전달하면 설치별 알림
설정을 Recommendation의 `recommended` 값에 적용합니다. 설정 API는 camelCase로
응답하며, 알림 시간은 24시간제 `HH:mm`만 허용합니다.
