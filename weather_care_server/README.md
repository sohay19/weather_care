# 날씨챙겨 Server

TypeScript + Hono 서버입니다. 현재 운영 원본은 미니 PC의 Node.js + SQLite입니다.
공개 주소 `https://weather-api.codesoha.com`은 Cloudflare Tunnel로 이 서버에 연결됩니다.
소스에 남은 `D1Database` 타입과 `cf` 요청 옵션은 이전 구현과 호환되는 코드이며,
현재 운영 데이터베이스나 수집기가 Cloudflare Workers/D1에서 실행된다는 뜻은 아닙니다.

날씨·환경 원본 데이터는 공공데이터포털의 다음 서비스를 사용합니다.

- [기상청 단기예보 조회서비스](https://www.data.go.kr/data/15084084/openapi.do)
- [기상청 중기예보 조회서비스](https://www.data.go.kr/data/15059468/openapi.do)
- [기상청 지상·AWS 일통계 관측자료](https://apihub.kma.go.kr/apiList.do?seqApi=2&seqApiSub=239)
- [기상청 생활기상지수 조회서비스](https://www.data.go.kr/data/15085288/openapi.do) V5 `getUVIdxV5`
- [한국환경공단 에어코리아 대기오염정보](https://www.data.go.kr/data/15073861/openapi.do)
- [국가교통정보센터 돌발상황정보](https://www.its.go.kr/opendata/opendataList?service=event)

## API

- `GET /api/v1/weather/main?nx=60&ny=121`
- `GET /api/v1/weather/today?nx=60&ny=121&recommendationCatalog=PREPARATION_15`
- `GET /api/v1/weather/weekly?nx=60&ny=121&recommendationCatalog=PREPARATION_15`
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

먼저 공공데이터포털에서 단기예보, 생활기상지수, 에어코리아 대기오염정보를
각각 활용신청하고 발급받은 키를 저장소 밖의 환경 파일에 보관합니다.
`KMA_SERVICE_KEY`와 Firebase 서비스 계정 JSON의
`client_email`, `private_key`를 각각 `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`로
교체합니다. 현재 위치의 500m 강수 판정과 실제 발효 특보 조회에는 기상청
API허브에서 중기예보·지상·AWS 일통계·고해상도 격자자료·레이더·기상특보·도로위험기상정보 API 활용신청 후 발급된
`KMA_APIHUB_KEY`도 필요합니다.
현재 시행 중인 도로 통제를 조회하려면 국가교통정보센터에서 돌발상황정보
Open API 활용신청을 하고 발급받은 키를 운영 미니 PC의 `ITS_API_KEY`에 저장해야
합니다. 미니 PC는 10분마다 전국 돌발상황을 한 번 직접 조회해 SQLite 공용
스냅샷으로 저장하고, 각 위치의 3km 이내 통제는 외부 재호출 없이 로컬에서
판정합니다. 31일 기준 최대 호출 수는 4,464회이며 내부 월 안전한도는 9,000회입니다.
Firebase 프로젝트 ID는 공개 설정값
`weather-care-2aaa8`로 고정되어 있습니다.

### 운영 서버: 미니 PC Node.js + SQLite

Node.js 22 이상에서 SQLite 마이그레이션과 Hono 앱을 사용합니다. 운영
환경변수는 저장소 밖에서 주입하며 기본 DB 경로는 `./data/weather-care.sqlite`, API
바인딩은 `127.0.0.1:8787`입니다.

```bash
cd weather_care_server
npm ci
npm run node:db:migrate
npm run node:server
```

별도 프로세스에서 `npm run node:scheduler`를 실행하면 중앙 수집·알림을 수행합니다.
운영은 `weather-care-api.service`, `weather-care-scheduler.service`,
`cloudflared.service`로 실행하며 설정과 SQLite 파일은 저장소 밖에 둡니다.
`ops/mini-pc/README.md`의 이전 절차는 과거 전환 이력이며 현재 배포 절차가 아닙니다.

Node 중앙 수집기는 기본적으로 앱이 지원하는 전국 1,633개 예보 격자를 18개 묶음으로
나눠 10분마다 한 묶음씩 갱신합니다. 따라서 정상 운영 중에는 모든 격자의 기본 예보가
3시간 안에 순환 갱신됩니다.

운영 스케줄러는 시작할 때 보충 수집과 정각 core 수집을 하나의 선수집으로
실행합니다. 전국 1,633개의 기본·현재·주간 예보, 자외선·대기질·특보와
ASOS 가시거리, 최근 7일 일관측을 채웁니다. 전국 강수·도로 통제 원본을
좌표 등록 없이 저장하고, 도로살얼음 원본은 제공 계절에 전국 수집합니다.
필수 캐시와 최근 7일 일관측을 전수 검증해 키 누락·빈
payload·손상 JSON·`UNAVAILABLE`이 있으면 최대 3회 재시도하고, 그래도 빈 항목이
있으면 성공으로 처리하지 않고 정규 스케줄러를 시작하지 않습니다.
`npm run node:prewarm`은 같은 선수집·검증을 수동으로 다시 실행할 때 사용합니다.

| 자료 | 미니 PC 중앙 수집 | 새 GPS 좌표 조회 |
| --- | --- | --- |
| 기온·예보·시정 | 전국 1,633개 격자 | 해당 예보 격자 캐시 |
| 자외선 | 전국 공식 행정코드, 약 6시간 간격 | 해당 격자 행정코드 캐시 |
| 현재 대기질 | 에어코리아 전국 17개 시도, 약 1시간 간격 | 요청 좌표에 가까운 공식 측정소 관측 |
| 대기질 예보 | 전국 예보 통보 원본을 발표 시각별 공통 조회 | 해당 예보 권역 값 |
| 발효 특보 | 전국 지역표와 특보 현황, 30분 간격 | GPS에서 가장 가까운 특보 지역 |
| 현재 강수·도로 통제 | 전국 원본, 각각 15~30분·10분 간격 | GPS 지점에서 계산 |
| 도로살얼음 | 제공 계절에 전국 지원 도로, 30분 간격 | GPS 3km 이내 위험 구간 |

위 수집 범위는 앱이 지원하는 국내 위치에 적용됩니다. 제공처가 관측값을
발표하지 않았거나 요청·사용량 제한으로 수집이 실패하면 값을 임의로 만들지 않고
자료 상태를 표시합니다. 도로살얼음은 지원 고속도로와 제공 계절 밖에서는
표시 대상 자체가 아닙니다.

정규 core 작업은 10분마다 가시거리 수집 완료 여부를 다시 확인합니다. 정각 작업이
중복으로 건너뛰거나 외부 요청이 실패해도 10분 뒤에 재시도하며, 일관측 보충도
오전 2시 정각 한 번에만 의존하지 않고 2시대 core 작업에서 누락을 다시 확인합니다.

운영 비밀값은 미니 PC의 `/etc/weather-care/weather-care.env`에서 주입합니다.
SQLite 파일은 `/var/lib/weather-care/weather-care-release.sqlite`에 있습니다.
이전 Tailscale ITS 중계 서비스는 운영 경로에서 사용하지 않습니다.

## 핵심 구조

- `src/rules/*`: 날씨 데이터 -> RuleFact
- `src/lifestyle/*`: RuleFact -> LifestyleInsight + 생활 문구 카탈로그
- `src/recommendations/*`: Insight + 사용자 설정 -> Recommendation + 준비물 문구 카탈로그
- `src/notification/*`: 추천 결과 생성·중복 방지·FCM HTTP v1 전송
- `src/database/*`: SQLite 저장/조회 함수 (`D1Database` 호환 타입 사용)
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

`/weather/main`, `/weather/today`, `/weather/weekly`, `/weather/comparison`은 외부 제공자를 호출하지 않고 중앙 수집 결과만 읽습니다. Node 운영 서버는 앱 지원 전국 격자를 미리 채우므로 최초 선수집이 끝난 뒤 지역 선택으로 외부 API 호출이나 `WEATHER_CACHE_NOT_READY`가 새로 발생하지 않습니다.

Cron은 10분마다 전국 격자 한 묶음의 단기예보와 활성 설치의 환경·특보를 수집하고 알림을 평가합니다. 전국 500m 레이더는 `2,17,32,47분`에 한 번만 받아 모든 활성 좌표를 배치 판독하고, 공공데이터포털 초단기실황과 강수 판단이 다른 좌표만 APIHub 지점 관측분석으로 최대 40개까지 재검증합니다. 도로살얼음은 동절기 `7,37분`에 12개 노선을 한 번씩만 받아 모든 활성 좌표를 함께 판정합니다.

`/weather/today`는 기상청 단기예보와 자외선·대기질을 병합해 `current.uvIndex`, `current.pm10`, `current.pm25`, `current.ozone`을 반환합니다. 자외선 예측은 해당 시간의 `hourly[].uvIndex`에도 병합하고, 실시간 대기질 관측값은 미래를 의미하지 않으므로 `current`와 첫 시간 슬롯에만 적용합니다.

`environmentalSources.uv` / `environmentalSources.airQuality`은 각각 `AVAILABLE`, `CACHED`, `STALE`, `UNAVAILABLE`, `UNSUPPORTED_REGION` 상태를 제공합니다. 전국 자외선은 지원 격자를 6시간 간격으로 갱신하고, 에어코리아 시도별 관측은 1시간 간격으로 공통 조회합니다. `/main`과 `/today`는 지역 예보에 포함된 이전 환경 값 대신 최신 환경 캐시와 전국 대기질 원본을 다시 병합합니다. 자외선은 저장·발표 후 최대 8시간, 대기질은 저장 후 최대 3시간·관측 후 최대 4시간까지만 사용합니다. 기간을 넘기면 이전 숫자를 제거하고 `UNAVAILABLE`로 표시합니다.

대기질 예보는 전국 공통 원본을 `/main`·`/today`·`/weekly`에서 직접 읽습니다.
같은 예보 격자가 여러 행정 구역에 걸칠 수 있으므로 요청의 행정코드·지역명을
격자 대표 지역보다 우선합니다. 경기북부 11개 시군과 강원 영동 7개 시군은
[에어코리아 공식 권역 기준](https://airkorea.or.kr/web/board/5/1171/?pMENU_NO=144)을
행정코드에 대응시키며 위도·경도 경계로 구분하지 않습니다. 행정코드와 지역명이
없으면 기상청 격자표의 대표 행정코드를 사용합니다.

운영 선수집 검사는 환경 캐시 객체의 존재에 더해 현재 시간의 자외선 예측값과
PM10·PM2.5·오존 관측값을 각각 확인합니다. 환경 결측은
`environmentalMissingSample`에 격자 캐시 키와 누락 항목을 기록합니다.
대기질 예보는 최신 발표 회차의 19개 권역에 오늘 PM10·PM2.5 예보가 있어야 완료로
판정합니다. 제공처의 이전 발표를 현재 회차로 저장하지 않습니다.

APIHub 일일 예약량의 설계 추정은 2026-10-01 운영 예약량에서 기존 레이더 예약을
제외하고 전국 분석·레이더를 더하면 비동절기 약 3.887GB/일입니다. 동절기에는
전국 분석·레이더를 30분 간격으로 줄이고 도로살얼음 12개 노선의 회당 최대 예약
25.2MB를 포함하면 약 3.653GB/일이며 내부 한도는 4.5GB/일입니다. 이는 정상 회차의
예약 추정으로, 추가 재시도·제공처 실제 전송량·계정 사용량은 운영에서 따로 확인해야 합니다.

현재 관측과 미래 예보의 `apparentTemperature`는 적용 조건을 충족할 때 [기상청 공식 체감온도 산식](https://data.kma.go.kr/climate/windChill/selectWindChillChart.do)을 사용합니다. 5~9월은 기온·상대습도·Stull 습구온도 기반 여름 산식, 10~익년 4월은 기온 10℃ 이하·풍속 1.3m/s 이상일 때 겨울 풍속냉각 산식을 적용합니다. 이 조건 밖에 있고 같은 시각의 기온·습도·풍속이 모두 있으면 [호주 기상청의 Steadman 비복사 산식](https://www.bom.gov.au/info/thermal_stress/)으로 추정 체감온도를 계산합니다. 이때 `apparentTemperatureSource`는 관측 또는 예보 Steadman 출처를 기록하며 `kmaApparentTemperature`는 비워 기상청 공식 적용 범위의 값과 구분합니다. 입력값이 빠졌으면 숫자를 만들지 않습니다. 앱의 표현 경계와 연구 근거는 [`docs/체감온도_표현_기준.md`](../docs/체감온도_표현_기준.md)에 있습니다.

자외선은 전국 공식 격자·행정코드 표를 사용하고, 대기질은 전국 측정소 위치와 시도별 묶음 관측에서 가까운 유효 측정소를 선택합니다. 특보는 전국 지역 측정소와 발효 자료를 저장한 뒤 요청 GPS 좌표에서 지역을 결정합니다.

`/weather/weekly`는 지역 단기예보를 우선하고, 공식 일 최저·최고가 없는 겹침 날짜와 이후 빈 날짜를 중기 기온·육상예보로 보충합니다. 단기와 중기 Provider는 독립 처리해 한쪽이 실패해도 나머지 자료를 반환합니다. 지난 날짜는 예보격자 대표점에 가장 가까운 기상청 지상·AWS 관측소의 실제 일통계를 우선 반환하고, 관측 미수신 시에만 SQLite에 남은 `저장된 예보`를 보조로 사용합니다. 두 예보와 관측·저장 기록이 모두 없으면 날씨를 추정하지 않고 결측 상태를 반환합니다.

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

신규 앱은 `recommendationCatalog=PREPARATION_15`를 전달해 비(우산·우비·장화),
햇빛·자외선(양산·선크림·선글라스), 더위(물·휴대용 선풍기·쿨링제품),
추위(두꺼운 겉옷·목도리·핫팩), 눈·결빙(스노우체인·보조배터리·방한부츠)의
확장 준비물 추천을 받습니다. 이 값이 없으면 구버전 앱 호환을 위해 기존 추천 타입만
반환합니다. 새 준비물은 DB 컬럼을 늘리지 않고 같은 날씨군의 기존 설정을 함께
따릅니다.
