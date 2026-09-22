# 날씨 항목별 데이터 출처·API와 기온 차이 점검

- 작성일: 2026-09-22 (KST)
- 점검 기준 소스: Git `5664bcb`
- 앱 기본 운영 API: `https://weather-api.codesoha.com`
- 비교 대상: [기상청 날씨누리](https://www.weather.go.kr/w/index.do)

## 1. 결론 요약

현재 프로젝트와 기상청 날씨누리의 기온을 비교할 때는 숫자만 비교하면 안 된다. 같은 기관의 자료를 사용해도 **자료 역할, 위치, 대상 시각, 발표 시각, 수집 시각**이 다르면 값이 달라진다.

현재 확인된 가장 중요한 사항은 다음과 같다.

1. 저장소의 최신 서버 코드는 `현재 기온·습도·풍속`에 기상청 `초단기실황(getUltraSrtNcst)`의 `T1H·REH·WSD`를 사용하도록 되어 있다.
2. 그러나 2026-09-22 08:30 KST 운영 API 실조회에서는 `current.dataRole=FORECAST`, `provider=KMA`, `providerField=TMP,REH,WSD,...`가 반환됐다. 즉 운영 서버는 현재도 `단기예보(getVilageFcst)`의 현재 시간대 예보를 `current`로 내보내고 있다.
3. 따라서 사용자가 설치한 앱이 기본 운영 주소를 사용한다면, 날씨누리의 현재 관측기온과 앱의 현재 시간대 **예보기온**을 비교하게 될 수 있다. 큰 차이의 최우선 원인 후보다.
4. 저장소 코드와 운영 배포가 일치하더라도 초단기실황은 휴대전화 위치의 직접 센서값이 아니다. 기상청 공식 설명상 5 km 동네예보 격자에 매칭된 대표 AWS 관측값이다.
5. 날씨누리는 선택한 행정동·현재 위치·관측지점에 따라 표시 기준이 달라질 수 있다. 앱의 `nx/ny`, 날씨누리 선택 지역, 날씨누리 관측지점이 같지 않으면 같은 시각에도 차이가 날 수 있다.
6. 앱의 체감온도는 기상청이 내려준 별도 실황 숫자가 아니라 기온·습도·풍속을 기상청 산식에 넣어 서버에서 계산한 값이다.

### 바로 판별하는 기준

운영 API의 `current`가 아래 중 어느 형태인지 먼저 확인한다.

| 판별 필드 | 정상 목표 | 현재 운영 실조회 | 의미 |
| --- | --- | --- | --- |
| `current.dataRole` | `OBSERVATION` | `FORECAST` | 운영값이 실황이 아니라 예보임 |
| `current.provider` | `KMA_ULTRA_SHORT_OBSERVATION+KMA_FORECAST` | `KMA` | 기온은 초단기실황, 하늘은 예보여야 하나 운영은 전체가 단기예보임 |
| `current.providerField` | `T1H,REH,WSD;SKY=FORECAST` | `TMP,REH,WSD,VEC,POP,PTY,PCP,SNO,SKY` | 운영 기온 원본이 `T1H`가 아니라 `TMP`임 |
| `current.observedAt` | 최근 초단기실황 기준시각 | 예보 대상 시각과 동일 | 운영값이 관측시각이 아님 |
| `current.forecastAt` | 없음 | 있음 | 운영값이 예보 슬롯임 |

## 2. 앱에서 서버까지의 실제 데이터 흐름

```text
Flutter 앱
  ├─ 빠른 첫 화면: GET /api/v1/weather/main
  ├─ 전체 오늘 자료: GET /api/v1/weather/today
  ├─ 주간 자료: GET /api/v1/weather/weekly
  └─ 어제 비교: GET /api/v1/weather/comparison/yesterday
             ↓
weather-api.codesoha.com
  ├─ main/today/weekly: 중앙 수집 캐시(SQLite 또는 D1) 조회
  └─ comparison/yesterday: 현재 코드상 요청 시 외부 초단기실황 API도 직접 호출
             ↓
기상청·에어코리아·ITS 원본 API
```

앱은 기상청 API 키를 갖고 있지 않으며 외부 기상 API를 직접 호출하지 않는다. 기본 서버 주소는 앱의 `AppConfig`와 `config/kma.config.json` 모두 `https://weather-api.codesoha.com`이다.

### 위치 기준

- GPS 모드: 기기 좌표를 기상청 동네예보 `nx/ny`로 변환해 지역 날씨를 요청한다.
- 수동 지역: 사용자가 선택한 예보 격자의 `nx/ny`를 사용한다.
- 정밀 좌표가 있을 때만 위도·경도를 `/today`에 함께 보내며, 현재 강수·도로결빙·도로통제와 가까운 대기질 측정소 선택에 사용한다.
- 정밀 좌표가 없으면 예보 격자의 대표 좌표를 대기질 측정소 선택과 일출·일몰 계산에 사용한다.
- 기본 인수값은 `nx=60`, `ny=121`이지만 정상 앱 흐름에서는 선택 지역의 격자를 전달한다.

## 3. 화면 항목별 원본과 가공 방식

### 3.1 Main·Today의 현재 항목

| 앱 표시 항목 | 현재 저장소가 의도한 원본 | 원본 필드 | 자료 역할·공간 기준 | 서버 가공·주의점 |
| --- | --- | --- | --- | --- |
| 현재 기온 | 기상청 초단기실황 `getUltraSrtNcst` | `T1H` | 관측, 선택 `nx/ny`의 5 km 격자 대표 AWS 값 | 최근 자료가 없거나 2시간 초과면 단기예보로 대체하지 않고 결측 처리하도록 구현됨 |
| 현재 습도 | 기상청 초단기실황 | `REH` | 관측, 같은 격자·시각 | 현재 기온과 같은 관측 레코드를 사용 |
| 현재 풍속 | 기상청 초단기실황 | `WSD` | 관측, 같은 격자·시각 | 현재 코드에서는 관측 풍향을 사용하지 않아 `windDirection`은 비움 |
| 현재 체감온도 | 앱 서버 계산 | `T1H+REH+WSD` | 계산값 | 여름/겨울 기상청 산식을 사용하며 별도 관측센서값이 아님 |
| 현재 하늘 상태 | 기상청 단기예보 `getVilageFcst` | `SKY+PTY` | 예보, 선택 격자 | 현재 기온이 실황이어도 하늘 상태는 예보이며 `SKY_FROM_FORECAST`로 구분 |
| 현재 자외선 | 기상청 생활기상지수 V5 | `h0~h75` 중 대상 시각 | 3시간 간격 예측 | 대상 시각 이전 3시간 이내 가장 가까운 값을 병합 |
| 현재 미세먼지 | 에어코리아 측정소별 실시간 관측 | `pm10Value` | 가까운 측정소 관측 | 사용자 자리의 직접 측정값이 아님 |
| 현재 초미세먼지 | 에어코리아 측정소별 실시간 관측 | `pm25Value` | 가까운 측정소 관측 | 가까운 후보 최대 5곳에서 한 측정소의 사용 가능한 값을 선택 |
| 현재 오존 | 에어코리아 측정소별 실시간 관측 | `o3Value` | 가까운 측정소 관측 | PM 값과 같은 측정소 응답을 사용 |
| 가시거리 | 기상청 APIHub 지상 시간관측 | `VS` | 가장 가까운 ASOS 지점 | 원본을 10배해 m로 변환, 거리 30 km 이내·3시간 이내만 사용 |
| 일출·일몰 | 외부 API 없음 | 위도·경도·날짜 | 서버 계산 | 천문 근사식과 태양 천정각 90.833° 사용 |
| 현재 기상특보 | 기상청 APIHub 특보현황 | 특보종류·단계·발효시각·구역 | 공식 발효 특보 | 예비·미발효 자료는 제외 |
| 현재 비 | 기상청 초단기실황 + 관측분석 + 레이더 | `PTY`, `rn_ox`, HSR `ECHO` | 정밀 좌표 주변 500 m 분석 | 관측분석과 레이더의 비 판정 일치 여부를 `RAIN/DRY/MISMATCH`로 보존 |
| 블랙아이스 | 기상청 도로살얼음 발생 가능 정보 | 공식 0~3 단계 | GPS 3 km 이내 지원 고속도로 | 11월 15일~3월 15일만 수집, 0은 안전이 아니라 정보없음 |
| 도로 통제 | 국가교통정보센터 돌발상황정보 | 통제 종류·차로·시작/종료·좌표 | GPS 3 km 이내 | 사고·공사라는 이유만으로 통제를 추정하지 않음 |

### 3.2 미래 예상 날씨·시간별 예보

| 앱 표시 항목 | 원본 | 원본 필드 | 서버 처리 |
| --- | --- | --- | --- |
| 예상 기온 | 기상청 단기예보 | `TMP` | 다음 미래 시각 또는 시간별 슬롯의 값 |
| 예상 체감온도 | 서버 계산 | `TMP+REH+WSD` | 같은 예보 시각의 값으로 계산 |
| 예상 습도 | 기상청 단기예보 | `REH` | % 숫자 유지 |
| 예상 풍속·풍향 | 기상청 단기예보 | `WSD+VEC` | m/s와 각도를 앱에서 방향 문자로 표시 |
| 하늘·강수 형태 | 기상청 단기예보 | `SKY+PTY` | 맑음·구름 많음·흐림·비·비/눈·눈·소나기 등으로 정규화 |
| 강수확률 | 기상청 단기예보 | `POP` | % 유지 |
| 시간당 강수량 | 기상청 단기예보 | `PCP` | `강수없음`, `1mm 미만`, 범위, 이상 표현을 보존 |
| 시간당 적설 | 기상청 단기예보 | `SNO` | cm 단위의 없음·미만·범위·이상 표현을 보존 |
| 예상 자외선 | 기상청 생활기상지수 V5 | `h0~h75` | 시간별 예보 슬롯에 병합 |
| 다음 시간 대기질 | 에어코리아 통보 | 날짜별 PM2.5 등급 | 실시간 관측값을 미래값처럼 복사하지 않고 통보 등급 사용 |

단기예보 발표 후보 시각은 코드상 `02·05·08·11·14·17·20·23시`이며, 발표 지연을 고려해 15분을 뺀 시각에서 최신 발표분을 고른다.

### 3.3 Week 항목

| 앱 표시 항목 | 우선 원본 | 보조 원본 | 비고 |
| --- | --- | --- | --- |
| 오늘~단기 범위 날씨 | 기상청 단기예보 | 없음 | `SKY+PTY`의 날짜 대표 상태 |
| 4~10일 날씨 | 기상청 중기육상예보 `getMidLandFcst` | 단기예보와 겹치면 단기 우선 | 오전·오후 날씨와 강수확률 사용 |
| 일 최저·최고기온 | 단기 `TMN/TMX` | 시간별 `TMP` 최솟값·최댓값, 이후 중기 `getMidTa` | 시간별 대체값이면 `HOURLY`로 표시 |
| 평균 습도 | 단기 시간별 `REH` | 없음 | 받은 슬롯의 산술평균 |
| 최대 풍속 | 단기 시간별 `WSD` | 없음 | 받은 슬롯의 최댓값 |
| 최대 자외선 | 생활기상지수 V5 | 없음 | 해당 날짜 포인트의 최댓값 |
| 강수 예보 | 단기 `POP+PCP` | 중기 강수확률 | 단기 시간별과 연장 정성예보를 구분 |
| 예상 강설 | 단기 `SNO+PTY` | 중기 날씨 문구 | 단기 강설량 합계는 보수적 하한값 기반 |
| 대기 상태 | 에어코리아 단기·주간 통보 | 없음 | PM10·PM2.5·오존 등급, 황사 언급, 신뢰도 |
| 지난 날짜 최저·최고·강수·적설 | 기상청 APIHub 지상·AWS 일자료 | 저장된 당시 예보 | 예보 격자 대표점에서 가장 가까운 관측소를 사용하고 거리 표시 |
| 날짜별 준비물 | 위 항목들의 앱 규칙 결과 | 없음 | 지난 실제 관측일은 추천하지 않음 |

### 3.4 앱이 자체 생성하는 항목

다음 항목은 원본 API가 완성된 문장이나 추천을 주는 것이 아니라 프로젝트가 생성한다.

- 한 줄 브리핑
- `Check List` 준비물 추천
- 시간대별 타임라인 상태 문구
- 생활 날씨·행동 안내
- 데이터 상태 안내
- 체감온도
- 일출·일몰
- 날짜 대표 날씨, 일평균 습도, 최대 풍속
- `어제와 비교`의 차이 문구

주요 판단 입력과 기본 기준은 다음과 같다.

| 판단 | 주요 입력 | 현재 기본 기준 |
| --- | --- | --- |
| 비 대비 | `POP`, `PCP`, `PTY` | 강수확률 40% 이상 또는 시간 강수 하한 0.5 mm 이상, 일반적으로 연속 2슬롯 확인 |
| 많은 비 | `POP`, `PCP` | 시간 강수 하한 30 mm 이상 또는 확률 70% 이상이면서 15 mm 이상 |
| 눈 대비 | `PTY`, `SNO` | 눈·비/눈 또는 적설 하한 0 cm 초과 |
| 많은 눈 | `SNO` | 1시간 또는 최근 3시간 적설 하한 5 cm 이상 |
| 자외선 대비 | 자외선지수 | 6 이상, 8 이상은 높은 우선순위 |
| 더위 대비 | 계산 체감온도 | 낮 시간 33℃ 이상, 35℃ 이상은 즉시 판단 |
| 추위 대비 | 기온·계산 체감온도 | 기온 12℃ 이하 또는 체감 10℃ 이하 |
| 큰 일교차 | 시간별 기온 | 최고-최저 8℃ 이상 |
| 강풍 | `WSD` | 9 m/s 이상, 14 m/s 이상은 높은 우선순위 |
| 대기질 | PM10·PM2.5·오존 | 각각 81 ㎍/㎥, 36 ㎍/㎥, 0.091 ppm 이상 또는 나쁨 등급 |

준비물은 비(우산·우비·장화), 햇빛(선크림·양산·선글라스), 더위(물·휴대용 선풍기·쿨링제품), 추위(두꺼운 겉옷·목도리·핫팩), 눈·결빙(스노우체인·방한부츠·보조배터리), 대기질(마스크)로 만들어진다. 응답의 `recommendationCatalog=PREPARATION_15`가 확장 카탈로그 사용 신호다.

## 4. 외부 API 목록과 호출 예제

아래 예제의 키는 반드시 서버 Secret에서 주입해야 한다. 실제 키를 문서·로그·앱 바이너리·URL 공유 기록에 남기지 않는다.

### 4.1 초단기실황: 현재 기온·습도·풍속·강수 참고

- 공식 서비스: [기상청 단기예보 조회서비스](https://www.data.go.kr/data/15084084/openapi.do)
- 엔드포인트: `getUltraSrtNcst`
- 주요 응답: `T1H`, `REH`, `WSD`, `PTY`, `RN1`
- 코드의 기준시각: 현재 시각에서 50분을 뺀 뒤 정시로 내림

```bash
curl "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst?serviceKey=<SERVICE_KEY>&pageNo=1&numOfRows=20&dataType=JSON&base_date=20260922&base_time=0700&nx=60&ny=121"
```

기상청 설명에 따르면 초단기실황은 예보 구역에 대한 대표 AWS 관측값이며 전국 5 km×5 km 동네예보 격자를 사용한다. 휴대전화 좌표의 직접 관측값으로 해석하면 안 된다.

### 4.2 단기예보: 시간별·현재 하늘·주간 앞부분

- 엔드포인트: `getVilageFcst`
- 주요 응답: `TMP`, `TMN`, `TMX`, `REH`, `WSD`, `VEC`, `POP`, `PTY`, `PCP`, `SNO`, `SKY`

```bash
curl "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst?serviceKey=<SERVICE_KEY>&pageNo=1&numOfRows=1000&dataType=JSON&base_date=20260922&base_time=0500&nx=60&ny=121"
```

### 4.3 중기예보: 4~10일 기온·육상날씨

- 공식 서비스: [기상청 중기예보 조회서비스](https://www.data.go.kr/data/15059468/openapi.do)
- 엔드포인트: `getMidTa`, `getMidLandFcst`
- 주요 응답: `taMinN`, `taMaxN`, `wfNAm`, `wfNPm`, `rnStNAm`, `rnStNPm`

```bash
curl "https://apis.data.go.kr/1360000/MidFcstInfoService/getMidTa?ServiceKey=<SERVICE_KEY>&pageNo=1&numOfRows=10&dataType=JSON&regId=11B20601&tmFc=202609220600"

curl "https://apis.data.go.kr/1360000/MidFcstInfoService/getMidLandFcst?ServiceKey=<SERVICE_KEY>&pageNo=1&numOfRows=10&dataType=JSON&regId=11B00000&tmFc=202609220600"
```

운영 코드는 `KMA_APIHUB_KEY`가 있으면 APIHub 중기예보 경로를 우선하고 공공데이터포털 키를 보조로 사용한다.

### 4.4 자외선지수

- 공식 서비스: [기상청 생활기상지수 조회서비스](https://www.data.go.kr/data/15085288/openapi.do)
- 엔드포인트: `getUVIdxV5`
- 주요 응답: 발표시각 `date`, 3시간 간격 `h0~h75`

```bash
curl "https://apis.data.go.kr/1360000/LivingWthrIdxServiceV5/getUVIdxV5?ServiceKey=<SERVICE_KEY>&pageNo=1&numOfRows=10&dataType=JSON&areaNo=<10자리_행정코드>&time=2026092206"
```

### 4.5 에어코리아 현재 대기질·측정소 목록

- 공식 서비스: [에어코리아 대기오염정보](https://www.data.go.kr/data/15073861/openapi.do)
- 현재 관측: `getMsrstnAcctoRltmMesureDnsty`
- 측정소 목록: `getMsrstnList`

```bash
curl "https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList?serviceKey=<SERVICE_KEY>&returnType=json&numOfRows=1000&pageNo=1"

curl "https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty?serviceKey=<SERVICE_KEY>&returnType=json&numOfRows=6&pageNo=1&stationName=<측정소명>&dataTerm=DAILY&ver=1.3"
```

### 4.6 에어코리아 대기질 통보

```bash
curl "https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMinuDustFrcstDspth?serviceKey=<SERVICE_KEY>&returnType=json&numOfRows=100&pageNo=1&searchDate=2026-09-22&InformCode=PM25"

curl "https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMinuDustWeekFrcstDspth?serviceKey=<SERVICE_KEY>&returnType=json&numOfRows=100&pageNo=1&searchDate=2026-09-22"
```

### 4.7 APIHub 지상 시간관측·일관측

가시거리와 지난 날짜 Week 카드는 기상청 APIHub의 전국 지점 자료를 받고 앱 격자 대표점에서 가까운 관측소를 선택한다.

```bash
# 시간 관측: TA 기온, HM 습도, WS 풍속, VS 시정 중 하나씩 요청
curl "https://apihub.kma.go.kr/api/typ01/url/kma_sfctm5.php?tm1=202609220600&tm2=202609220600&obs=VS&stn=0&disp=1&help=0&authKey=<APIHUB_KEY>"

# 일 관측: ta_min, ta_max, rn_day, sd_day_max 중 하나씩 요청
curl "https://apihub.kma.go.kr/api/typ01/url/sfc_aws_day.php?tm1=20260920&tm2=20260921&obs=ta_min&stn=0&disp=1&help=0&authKey=<APIHUB_KEY>"
```

### 4.8 현재 강수 관측분석·레이더

```bash
# 좌표 지점의 5분 강수 유무 분석
curl "https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-sfc_obs_nc_pt_api?obs=rn_ox&tm1=<YYYYMMDDHHMM>&tm2=<YYYYMMDDHHMM>&itv=5&lon=<경도>&lat=<위도>&authKey=<APIHUB_KEY>"

# 전국 500 m HSR 레이더 합성장 바이너리
curl "https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-rdr_cmp1_api?tm=<YYYYMMDDHHMM>&cmp=HSR&qcd=MSK&obs=ECHO&map=HB&disp=B&authKey=<APIHUB_KEY>" --output radar.bin
```

### 4.9 기상특보·도로살얼음·ITS 통제

```bash
# 발효 특보 현황
curl "https://apihub.kma.go.kr/api/typ01/url/wrn_now_data_new.php?fe=e&tm=<YYYYMMDDHHMM>&disp=0&help=0&authKey=<APIHUB_KEY>"

# 특보구역-관측지점 매핑
curl "https://apihub.kma.go.kr/api/typ01/url/wrn_reg_aws2.php?tm=&disp=0&help=0&authKey=<APIHUB_KEY>"

# 도로살얼음 자료 ZIP, 지원 노선별 호출
curl "https://apihub.kma.go.kr/api/typ04/url/road_file_down.php?roadNum=001&authKey=<APIHUB_KEY>" --output road-001.zip

# ITS 좌표 경계 내 돌발상황
curl "https://openapi.its.go.kr:9443/eventInfo?apiKey=<ITS_API_KEY>&type=all&eventType=all&minX=<최소경도>&maxX=<최대경도>&minY=<최소위도>&maxY=<최대위도>&getType=json"
```

## 5. 앱 서버 API 호출 예제

운영 서버 날씨 조회에는 기상청 키를 노출하지 않는다.

```bash
# 빠른 Main
curl "https://weather-api.codesoha.com/api/v1/weather/main?nx=60&ny=121"

# Today: 정밀 좌표가 없으면 현재 강수·도로 근접 항목이 제한됨
curl "https://weather-api.codesoha.com/api/v1/weather/today?nx=60&ny=121&recommendationCatalog=PREPARATION_15"

# 정밀 좌표 포함 예
curl "https://weather-api.codesoha.com/api/v1/weather/today?nx=60&ny=121&latitude=<위도>&longitude=<경도>&recommendationCatalog=PREPARATION_15"

# Week
curl "https://weather-api.codesoha.com/api/v1/weather/weekly?nx=60&ny=121&recommendationCatalog=PREPARATION_15"

# 다음 시간 예보와 어제 같은 시각 초단기실황 비교
curl "https://weather-api.codesoha.com/api/v1/weather/comparison/yesterday?nx=60&ny=121"
```

### 응답에서 반드시 확인할 필드

```json
{
  "region": { "nx": 60, "ny": 121, "name": "수원" },
  "generatedAt": "2026-09-21T23:30:38.003Z",
  "current": {
    "dataRole": "FORECAST",
    "forecastAt": "2026-09-22T08:00:00+09:00",
    "issuedAt": "2026-09-22T05:00:00+09:00",
    "fetchedAt": "2026-09-21T22:20:00Z",
    "temperature": 20,
    "provider": "KMA",
    "providerField": "TMP,REH,WSD,VEC,POP,PTY,PCP,SNO,SKY"
  }
}
```

위 예시는 2026-09-22 08:30 KST 운영 `/main?nx=60&ny=121` 실조회 일부다. 값은 시각에 따라 변하지만 `dataRole/provider/providerField`는 자료 종류를 판별하는 핵심이다.

## 6. 현재 운영 실조회 결과

2026-09-22 08:30 KST에 기본 운영 주소를 조회한 결과다.

| 경로 | 결과 |
| --- | --- |
| `/health` | HTTP 200 `ok` |
| `/weather/main?nx=60&ny=121` | HTTP 200, `dataSource=기상청 단기예보 · 서버 중앙 수집`, `current.dataRole=FORECAST` |
| `/weather/today?nx=60&ny=121` | HTTP 200, `current.dataRole=FORECAST`, 시간별 47개, 자외선·대기질은 `UNAVAILABLE` |
| `/weather/weekly?nx=60&ny=121` | HTTP 200, 단기예보와 지상·AWS 실제 관측 반환 |
| `/weather/comparison/yesterday?nx=60&ny=121` | HTTP 200, `KMA_FORECAST_VS_ULTRA_SHORT_OBSERVATION` |

저장소의 `currentFromUltraShortObservation()`은 신선한 초단기실황 캐시가 있으면 다음처럼 반환하도록 구현되어 있다.

```json
{
  "dataRole": "OBSERVATION",
  "provider": "KMA_ULTRA_SHORT_OBSERVATION+KMA_FORECAST",
  "providerField": "T1H,REH,WSD;SKY=FORECAST"
}
```

이 경우 `forecastAt` 필드는 `null`이 아니라 응답에서 생략되고 실제 관측시각은 `observedAt`에 들어간다.

운영 결과가 이 계약과 다르므로 다음 중 하나 이상을 점검해야 한다.

- 최신 서버 소스가 미니 PC 운영 경로에 배포되지 않음
- 배포됐지만 실제 서비스가 이전 디렉터리·프로세스를 실행 중임
- Cloudflare Tunnel이 다른 원본을 가리킴
- 배포 후 프로세스 재시작이 누락됨

단순히 초단기실황 캐시가 비어 있는 경우 최신 코드는 기온을 단기예보로 되돌리지 않고 `CURRENT_OBSERVATION_UNAVAILABLE`과 결측값을 반환해야 한다. 따라서 현재 운영의 `FORECAST` 반환은 캐시 결측만으로는 설명되지 않는다.

## 7. 기상청 날씨누리와 기온이 달라지는 원인 우선순위

### 1순위: 운영 앱은 현재 예보값을 표시 중

운영 응답의 현재 기온은 단기예보 `TMP`다. 날씨누리의 현재 관측기온과 비교하면 같은 시각처럼 보여도 `예보 대 관측` 비교가 된다. 특히 전선 통과, 소나기, 일출 직후, 해풍 유입처럼 기온이 빠르게 변할 때 차이가 커질 수 있다.

### 2순위: 위치 기준 불일치

- 앱: 선택한 5 km 격자 `nx/ny`
- 초단기실황: 그 격자의 대표 AWS 관측값
- 날씨누리 현재날씨: 선택 화면과 항목에 따라 특정 관측지점 또는 위치 기반 자료
- 가시거리·지난 날 Week: 앱 격자에서 가까운 별도 ASOS/AWS 지점

행정동 이름이 같아도 산지·해안·하천·도심·고도·관측소 거리 때문에 실제 대표점이 다를 수 있다.

### 3순위: 기준 시각 불일치

초단기실황 Provider는 발표 지연을 고려해 `현재-50분`의 정시를 선택한다. 예를 들어 08:30에는 07:00 실황을 요청한다. 날씨누리 화면이 08:20 또는 08:30 갱신 관측을 보여주면 이미 1시간 이상 차이가 난다.

또한 중앙 수집은 활성 지역을 10분마다 확인하지만, 최신 초단기실황 레코드는 최대 2시간까지 허용한다. 화면에서 시각을 확인하지 않고 숫자만 비교하면 오래된 값과 최신 값을 비교할 수 있다.

### 4순위: 한 화면 안의 자료 종류 혼합

최신 저장소 설계에서도 현재 카드의 기온·습도·풍속은 초단기실황이지만 하늘 상태는 단기예보다. 자외선은 생활기상지수 예측, 대기질은 에어코리아 측정소, 가시거리는 인근 ASOS, 일출·일몰은 서버 계산이다. 카드 전체가 같은 센서·같은 시각의 관측값은 아니다.

### 5순위: 체감온도 비교 대상 불일치

프로젝트의 체감온도는 다음과 같이 계산한다.

- 5~9월: 기온·상대습도와 Stull 습구온도를 이용한 기상청 여름 산식
- 10~4월: 기온 10℃ 이하, 풍속 1.3 m/s 이상에서 겨울 풍속냉각 산식
- 조건 미충족: 코드상 기온을 소수 첫째 자리로 반환

[기상청 체감온도 설명](https://data.kma.go.kr/climate/windChill/selectWindChillChart.do)도 관측 기반 계산값과 날씨누리 생활기상지수 예보값이 다를 수 있다고 안내한다. 따라서 날씨누리의 `기온`, `체감온도`, `생활기상지수` 중 무엇과 비교했는지 구분해야 한다.

### 큰 차이의 주원인이 아닌 항목

- 소수점 반올림: 일반적으로 0.1~0.5℃ 수준이며 큰 차이를 설명하기 어렵다.
- 앱 렌더링: 모델은 서버의 숫자를 그대로 `double`로 파싱하고, 화면에서 주로 소수 첫째 자리 또는 정수로 표시한다.
- 섭씨·화씨 혼동: 현재 코드에는 화씨 변환 경로가 없다.

## 8. 재현·진단 절차

기온 차이를 신고하거나 재현할 때 다음 자료를 같은 순간에 기록한다.

1. 앱에 표시된 지역명과 설정 모드(GPS/직접 선택)
2. 앱의 현재 기온·체감온도와 표시 시각
3. 날씨누리의 선택 지역, 관측지점명, 현재 기온, 기준시각
4. 앱 요청의 `nx/ny`; 정밀 좌표는 문서나 이슈에 원문을 남기지 말고 필요하면 대략적 지역만 기록
5. `/main` 또는 `/today` 응답의 아래 필드

```text
region.nx, region.ny, region.name
generatedAt
current.dataRole
current.observedAt
current.forecastAt
current.issuedAt
current.fetchedAt
current.temperature
current.provider
current.providerField
current.qualityFlags
```

### 판정표

| 확인 결과 | 판단 |
| --- | --- |
| `dataRole=FORECAST` | 현재 관측이 아니라 단기예보를 표시 중. 운영 배포 정합성부터 수정 |
| `dataRole=OBSERVATION`, `providerField`에 `T1H` 없음 | 응답 계약 이상 |
| `observedAt`이 2시간 초과 | 최신 코드라면 사용되면 안 됨. 서버 시계·캐시·배포 점검 |
| 앱과 날씨누리의 지역/격자/관측소가 다름 | 같은 위치 비교가 아님 |
| 시각이 다름 | 같은 시각으로 맞춘 뒤 재비교 |
| 위치·시각·자료 역할이 같은데 차이가 남음 | 원본 `getUltraSrtNcst`의 동일 `base_date/base_time/nx/ny`와 서버 응답 대조 |

## 9. 수정 권장 순서

1. 현재 저장소의 서버 코드를 운영 미니 PC에 배포하고 실제 실행 경로·서비스 재시작·Tunnel 원본을 확인한다.
2. 배포 직후 `/main`과 `/today`에서 `OBSERVATION`, `T1H,REH,WSD;SKY=FORECAST`가 반환되는지 확인한다.
3. 앱의 현재 카드에 `초단기실황 기준시각`과 `5 km 격자 대표 AWS 자료`임을 계속 노출한다.
4. 날씨누리 비교용 진단 로그에는 값이 아니라 `nx/ny`, 자료 역할, 원본 필드, 기준시각, 수집시각만 남긴다. 정밀 GPS와 인증키는 로그에 남기지 않는다.
5. `comparison/yesterday`는 이름과 달리 현재 실황 비교가 아니라 **다음 시간 예보 대 어제 같은 시각 초단기실황**이다. UI·문서에서 이 의미를 유지하고 현재 기온 검증 자료로 사용하지 않는다.
6. 서버 README의 “comparison도 외부 제공자를 호출하지 않는다”는 설명은 현재 `comparison.ts` 구현과 다르므로 별도 정정이 필요하다.

## 10. 관련 코드 위치

| 목적 | 파일 |
| --- | --- |
| 앱 운영 서버 주소 | `weather_care_app/lib/services/app_config.dart` |
| 앱 서버 호출 파라미터 | `weather_care_app/lib/services/weather_service.dart` |
| Main·Today·Week API 조립 | `weather_care_server/src/api/weather.ts` |
| 어제 비교 API | `weather_care_server/src/api/comparison.ts` |
| 초단기실황 | `weather_care_server/src/providers/weather/kmaUltraShortObservationProvider.ts` |
| 단기예보·체감온도 | `weather_care_server/src/providers/weather/kmaWeatherProvider.ts` |
| 중기예보 | `weather_care_server/src/providers/weather/kmaMidTermProvider.ts` |
| 지상 시간관측·가시거리 | `weather_care_server/src/providers/weather/kmaHourlyObservationProvider.ts` |
| 지상·AWS 일관측 | `weather_care_server/src/providers/weather/kmaDailyObservationProvider.ts` |
| 자외선 | `weather_care_server/src/providers/uv/kmaUvProvider.ts` |
| 대기질 현재 관측 | `weather_care_server/src/providers/air/airKoreaAirQualityProvider.ts` |
| 대기질 통보 | `weather_care_server/src/providers/air/airKoreaForecastProvider.ts` |
| 관측분석·레이더 | `weather_care_server/src/providers/precipitation/precipitationObservationProvider.ts` |
| 특보 | `weather_care_server/src/providers/warnings/kmaWarningProvider.ts` |
| 도로살얼음 | `weather_care_server/src/providers/road/kmaRoadIceProvider.ts` |
| ITS 통제 | `weather_care_server/src/providers/traffic/itsRoadControlProvider.ts` |
| 중앙 수집 주기·캐시 | `weather_care_server/src/collection/weatherCollectionJob.ts` |
| 규칙 기준 | `weather_care_server/src/config/ruleConfig.ts` |
| 준비물 추천 | `weather_care_server/src/recommendations/recommendationEngine.ts` |

## 11. 공식 참고자료

- [기상청 날씨누리](https://www.weather.go.kr/w/index.do)
- [기상청 날씨누리 도시별 현재날씨 도움말](https://www.weather.go.kr/wnuri_help/html/observation/city-obs.jsp)
- [기상청 단기예보 조회서비스](https://www.data.go.kr/data/15084084/openapi.do)
- [기상청 중기예보 조회서비스](https://www.data.go.kr/data/15059468/openapi.do)
- [기상청 생활기상지수 조회서비스](https://www.data.go.kr/data/15085288/openapi.do)
- [기상청 체감온도 자료 설명](https://data.kma.go.kr/climate/windChill/selectWindChillChart.do)
- [에어코리아 대기오염정보](https://www.data.go.kr/data/15073861/openapi.do)
- [국가교통정보센터 오픈데이터](https://www.its.go.kr/opendata/intro)
