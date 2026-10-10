# 날씨 항목별 데이터 출처·API 및 운영 수집 정책

- 수정일: 2026-10-10 (KST), 적설 정의와 현행 운영 안내 정정
- 기존 점검 기준 소스: Git `5664bcb`
- 앱 기본 운영 API: `https://weather-api.codesoha.com`
- 비교 기준: 기상청 날씨누리 및 각 원본 API의 발표/관측 시각
- 목적: **현재는 가능한 한 최신 관측값**, **미래/예상은 해당 대상 시각의 예보값**, **선택 위치에는 그 위치에 가장 적합한 데이터**를 안정적으로 제공한다. 또한 **처음 선택한 지역·GPS 이동 직후·운영서버 재배포 직후에도 Week 카드가 비지 않도록** 단기/중기예보의 캐시 키와 보충 수집 방식을 분리한다.

2026-10-10 현행 변경과 운영 상태는 [적설 정의 정정과 운영 잔여 이슈](적설_정의_정정_및_운영_잔여이슈_20261010.md)를 우선한다. 현재 적설량은 기존 눈을 포함한 시각별 총 깊이다. `kma_snow1.php sd=tot&snow=0`의 활용승인과 실제 응답 검증은 완료됐으며 정규 수집기·앱 연결은 남아 있다. 요청 시각과 달라도 응답 행의 실제 관측 시각을 보존한다. 단기예보 SNO는 예상 신적설이고, 과거 `sd_day_max`는 일 최심신적설이다. 본문의 AWS 실황 대체 설계는 현재 운영에서 제거됐으며, 원본 결측은 GPS 인근 격자 실황과 지점예보로 보충한다. 점검 대상 자료는 2026-10-01 이후이며 작년 비교 복구는 범위에서 제외한다.

---

## 1. 최종 운영 원칙

이 문서에서 데이터 선택 기준은 아래 4개 원칙을 최우선으로 한다.

### 1.1 `현재`의 정의

`현재`, `지금`, `실시간`으로 표시하는 값은 **현재 시각보다 미래인 예보값을 현재값으로 사용하지 않는다.**

우선순위는 다음과 같다.

1. 선택한 `nx/ny`와 정확히 일치하는 최신 관측/실황 격자값
2. 정확한 격자값이 결측이거나 공급 지연이면 선택 위치와 가장 가까운 유효 관측소의 최신 관측값
3. 관측 자체가 존재하지 않는 항목만 현재 시각에 가장 가까운 최신 예측/나우캐스트를 사용하고, 반드시 `FORECAST_PROXY` 또는 `NOWCAST_FALLBACK`으로 구분
4. 오래된 관측값을 아무 표시 없이 `현재`로 사용하지 않음

현재값에는 반드시 `observedAt`, `fetchedAt`, `dataAgeMinutes`, `sourceLocation`을 남긴다.

### 1.2 `미래`·`예상`의 정의

`미래`, `예상`, `시간별 예보`, `내일`, `N시 예상`은 **표시하려는 대상 시각(`forecastAt`)에 해당하는 예보값**을 사용한다.

- `14시 예상 기온`이면 `forecastAt=14:00`의 `TMP`를 사용한다.
- 최신 발표분이 있으면 같은 `forecastAt`을 가진 값 중 가장 최근 `issuedAt`을 우선한다.
- 현재 실황을 미래값으로 복사하지 않는다.
- 이전/다음 시각의 값을 임의로 당겨 쓰지 않는다.
- 제공 주기가 3시간/일 단위인 자료는 시간별 값처럼 위장하지 않고 `timeMatch=BUCKET` 또는 `DAILY`로 표시한다.

### 1.3 위치의 정의

사용자가 선택한 위치가 모든 판단의 기준이다. 단, 서버 내부의 위치 식별자는 **하나로 합치지 않고 두 계층으로 분리**한다.

1. **격자 위치(Grid identity)**: `nx/ny`
   - 단기예보·10분 실황 등 5 km 동네예보 격자 자료에 사용한다.
2. **행정/예보구역 위치(Region identity)**: `adminCode + sido + sigungu + eupMyeonDong` 및 여기서 해석한 `midTermLandRegId`, `midTermTaRegId`
   - 중기육상예보·중기기온처럼 `nx/ny`가 아닌 별도 예보구역 코드를 요구하는 자료에 사용한다.

운영 규칙:

- GPS 사용 시: 실제 `latitude/longitude`를 기준 좌표로 사용하고, 공식 변환으로 `nx/ny`를 구한다. 동시에 좌표에 해당하는 행정지역을 해석해 Region identity를 만든다.
- 수동 지역 선택 시: 앱이 알고 있는 행정지역 코드/명칭과 공식 `nx/ny`를 함께 서버에 전달한다.
- 격자형 자료: **정확히 동일한 `nx/ny` 값**을 사용한다.
- 중기예보: `nx/ny`만으로 지역코드를 추측하지 않고 Region identity로 `regId`를 결정한다.
- 관측소형 자료: 실제 GPS 좌표가 있으면 GPS와 가장 가까운 유효 관측소, 없으면 `nx/ny` 대표 좌표와 가장 가까운 유효 관측소를 사용한다.
- 어떤 경우에도 `nx=60, ny=121` 같은 기본값이나 이웃 격자의 지역코드로 조용히 대체하지 않는다.

이 분리가 필요한 이유는 **하나의 5 km 격자가 둘 이상의 행정지역과 겹칠 수 있고, 반대로 서로 다른 `nx/ny`가 같은 중기예보 자료를 공유할 수 있기 때문**이다. 따라서 `57/125 -> 부천`, `58/125 -> 광명`처럼 격자 자체에 중기기온 지역을 고정 매핑하는 방식은 최종 판정 기준으로 사용하지 않는다.

### 1.4 위치 fallback 규칙

위치가 맞지 않는 데이터를 보여주는 것보다 source를 명확히 바꾸는 것이 우선이다.

- 예보 격자: 정확한 `nx/ny` 우선. 다른 격자의 예보를 조용히 대체값으로 사용하지 않는다.
- 실황 격자: 정확한 `nx/ny`가 결측이면 가장 가까운 AWS 관측으로 보강할 수 있다.
- 측정소형 자료: 가장 가까운 유효 측정소를 사용하되 `stationId`, `stationName`, `distanceKm`를 기록한다.
- fallback이 발생하면 `locationMatch`와 `qualityFlags`에 남긴다.

권장 값:

```text
locationMatch = EXACT_GRID | NEAREST_STATION | NEAREST_VALID_GRID | REGION | GLOBAL
qualityFlags  = [] | OBSERVATION_STALE | LOCATION_FALLBACK | FORECAST_PROXY | SOURCE_DELAYED | ...
```

---

## 2. 핵심 변경 사항

기존 구현/운영에서 가장 큰 문제는 `current`가 단기예보 `TMP`를 반환한 점이다. 2026-09-22 08:30 KST 운영 조회에서는 다음 상태가 확인됐다.

```text
current.dataRole      = FORECAST
current.providerField = TMP,REH,WSD,VEC,POP,PTY,PCP,SNO,SKY
```

이를 다음 목표 계약으로 변경한다.

```text
현재 기온/습도/풍속/강수형태
  -> 기상청 APIHub 10분 동네예보 실황 격자
  -> nph-dfs_odam_grd
  -> T1H / REH / WSD / VEC / PTY / RN1

결측 또는 공급 지연 시
  -> 가장 가까운 AWS 최신 관측
  -> 위치 fallback임을 응답에 명시

미래 시간별 날씨
  -> getVilageFcst
  -> TMP / REH / WSD / VEC / SKY / POP / PTY / PCP / SNO
  -> 요청한 forecastAt과 정확히 일치하는 슬롯
```

기상청 APIHub 동네예보 실황은 2024-03-04 10시 이후 10분 간격으로 발표되며, `T1H`, `REH`, `WSD`, `VEC`, `PTY`, `RN1`을 제공한다.

---

## 3. 서버 전체 데이터 흐름

```text
Flutter 앱
  │
  ├─ GPS 모드: latitude/longitude + 변환된 nx/ny
  └─ 수동 모드: 선택 지역 nx/ny
          │
          ▼
weather-api.codesoha.com
          │
          ├─ 1) 전역 스냅샷 캐시
          │      - 10분 실황 격자
          │      - AWS 최신 관측
          │      - 레이더
          │      - 특보
          │      - 대기질 전국/시도 스냅샷
          │
          ├─ 2) 위치별/구역별 영속 캐시
          │      - 단기예보: nx/ny
          │      - 중기육상예보: midTermLandRegId
          │      - 중기기온: midTermTaRegId
          │      - UV: areaNo
          │      - 행정지역 ↔ 예보구역 매핑
          │      - 기타 위치 종속 자료
          │
          ├─ 3) cache miss on-demand fetch
          │      - 신규 지역
          │      - GPS 이동으로 새 nx/ny 진입
          │      - 배포 직후 미수집 위치
          │
          └─ 4) single-flight / distributed lock
                 - 같은 source+시각+위치 요청은 한 번만 원본 호출
```

### 중요한 원칙

**중앙수집 캐시에 데이터가 있어야만 응답 가능한 구조로 만들지 않는다.**

읽기 순서는 다음과 같다.

```text
1. 최신 정상 캐시 확인
2. 없거나 stale이면 원본 즉시 조회
3. 동시에 들어온 동일 조회는 single-flight로 1회만 호출
4. 성공값을 영속 캐시에 저장
5. 원본 일시 장애면 허용 범위 안의 마지막 정상값 사용 + STALE 표시
```

이 구조가 신규 지역 선택, GPS 이동, 서버 재배포 시 누락을 막는 핵심이다.

---

## 4. 위치 결정 규칙

### 4.1 GPS 모드

```text
기기 GPS latitude/longitude
    ↓
공식 동네예보 격자 변환
    ↓
nx/ny
```

- 기상청 격자 자료는 변환된 `nx/ny`의 값을 사용한다.
- 관측소 기반 자료는 원래 GPS 좌표를 우선 사용해 거리 계산한다.
- GPS 좌표가 이동해 새로운 `nx/ny`로 바뀌면 새 격자를 즉시 요청한다.
- 동일 `nx/ny` 안에서 GPS만 조금 움직인 경우 격자 예보는 재호출하지 않고, 관측소/도로/대기질 등 거리 기반 항목만 필요할 때 갱신한다.

### 4.2 수동 지역 모드

- 선택 지역의 공식 `nx/ny`를 사용한다.
- 관측소 거리 계산이 필요하면 해당 격자의 대표 위·경도를 사용한다.
- 사용자가 선택한 지역명과 실제 `nx/ny` 매핑은 서버에서 재검증한다.

### 4.3 격자와 행정지역/중기예보 구역 분리

`nx/ny`는 동네예보 격자의 식별자이지 행정동 또는 중기예보 구역의 식별자가 아니다.

따라서 서버는 다음 구조를 유지한다.

```text
LocationContext
  ├─ latitude / longitude        # GPS가 있을 때
  ├─ nx / ny                     # 단기·실황 격자
  ├─ adminCode                   # 행정지역 식별
  ├─ sido / sigungu / eupMyeonDong
  ├─ midTermLandRegId            # getMidLandFcst용
  └─ midTermTaRegId              # getMidTa용
```

판정 우선순위:

```text
수동 지역 선택
  앱이 가진 adminCode/지역명
      ↓
  서버의 행정지역 → 중기예보구역 매핑
      ↓
  midTermLandRegId / midTermTaRegId

GPS 위치
  lat/lon
      ↓
  행정지역 해석
      ↓
  adminCode
      ↓
  중기예보구역 매핑
```

금지:

```text
nx/ny 하나만 보고 중기기온 regId 결정
이웃 격자의 midTerm regId를 자동 상속
앱의 '활성 지역 등록 완료' 여부를 중기예보 조회 조건으로 사용
```

예를 들어 항동과 인접 지역이 동일하거나 가까운 격자 경계에 걸리더라도 **사용자가 선택한 `서울특별시 구로구 항동`이라는 행정지역 identity를 유지**해야 한다. `57/125`라는 숫자만 보고 부천 중기기온 구역으로 판정해서는 안 된다.

### 4.4 위치 일치 검증

응답마다 다음을 남긴다.

```json
{
  "requestedLocation": {
    "mode": "GPS",
    "nx": 60,
    "ny": 121,
    "adminCode": "<행정지역코드>"
  },
  "resolvedRegion": {
    "sido": "서울특별시",
    "sigungu": "구로구",
    "eupMyeonDong": "항동",
    "midTermLandRegId": "<육상예보구역코드>",
    "midTermTaRegId": "<중기기온구역코드>"
  },
  "sourceLocation": {
    "type": "GRID",
    "nx": 60,
    "ny": 121,
    "locationMatch": "EXACT_GRID"
  }
}
```

관측소 기반이면:

```json
{
  "sourceLocation": {
    "type": "STATION",
    "stationId": "...",
    "stationName": "...",
    "distanceKm": 3.2,
    "locationMatch": "NEAREST_STATION"
  }
}
```

---

## 5. `현재` 항목별 데이터 원본

| 앱 표시 항목 | 1순위 원본 | 보조 원본 | 시간 기준 | 위치 기준 | 비고 |
| --- | --- | --- | --- | --- | --- |
| 현재 기온 | APIHub `nph-dfs_odam_grd` | 최신 AWS 관측 | 가장 최근 10분 실황 | 정확한 `nx/ny`; fallback은 최근접 AWS | `T1H` |
| 현재 습도 | APIHub `nph-dfs_odam_grd` | 최신 AWS 관측 | 현재 기온과 동일 시각 우선 | 동일 | `REH` |
| 현재 풍속·풍향 | APIHub `nph-dfs_odam_grd` | 최신 AWS 관측 | 동일 | 동일 | `WSD+VEC` |
| 현재 강수형태 | APIHub `nph-dfs_odam_grd` | 레이더/최근접 관측 | 동일 | 동일 격자 | `PTY` |
| 현재 1시간 강수 | APIHub `nph-dfs_odam_grd` | 레이더/관측 | 동일 | 동일 격자 | `RN1` |
| 현재 체감온도 | 서버 계산 | 없음 | 같은 관측시각의 `T1H+REH+WSD` | 같은 source set | 관측값끼리 계산 |
| 현재 하늘 상태 | 최근접 유효 AWS 운량/현천 | 최신 나우캐스트/예보 | 관측 우선 | 최근접 관측소 | 예보 fallback이면 `FORECAST_PROXY` |
| 현재 미세먼지 | 에어코리아 실시간 측정 | 다음 최근접 유효 측정소 | 최신 측정 `dataTime` | GPS/격자 대표점에서 최근접 | PM10 |
| 현재 초미세먼지 | 에어코리아 실시간 측정 | 다음 최근접 유효 측정소 | 동일 | 동일 | PM2.5 |
| 현재 오존 | 에어코리아 실시간 측정 | 다음 최근접 유효 측정소 | 동일 | 동일 | O3 |
| 현재 가시거리 | APIHub 지상/관측소 시정 | 다음 최근접 유효 지점 | 최신 관측 | 최근접 ASOS/AWS | 거리·시각 표시 |
| 현재 자외선 | 생활기상지수의 현재 시각 대응 슬롯 | 이전 유효 슬롯 | 최신 발표 중 현재 시각 대응 | `areaNo` | 관측이 아니므로 `FORECAST_CURRENT_SLOT` |
| 현재 기상특보 | APIHub 발효 특보 | 마지막 정상 snapshot | 현재 발효 상태 | 특보구역 매핑 | 이벤트 데이터 |
| 현재 비 상세 | 격자 `PTY/RN1` + 전국 레이더 | 관측분석 | 최신 5~10분 | 실제 GPS 우선 | 레이더는 좌표 픽셀 추출 |
| 블랙아이스 | 도로살얼음 공식 정보 | 마지막 정상 snapshot | 최신 제공분 | GPS 3 km 내 지원 도로 | 동절기 전용 |
| 도로 통제 | ITS 돌발상황 | 마지막 정상 snapshot | 최신 제공분 | GPS 3 km | 전국 snapshot 후 로컬 필터 권장 |
| 일출·일몰 | 서버 계산 | 없음 | 해당 날짜 | 실제 좌표/격자 대표점 | 계산값 |

### 5.1 현재 실황 freshness 기준

권장 기준:

```text
0~20분   : 정상 CURRENT
20~30분  : CURRENT + SOURCE_DELAYED 가능
30분 초과: 10분 격자 실황을 현재값으로 단독 사용하지 않음
           -> 최신 AWS 관측 fallback 시도
```

AWS fallback도 지정된 freshness를 넘으면 `OBSERVATION_STALE`을 표시한다. 오래된 값을 단기예보 `TMP`로 조용히 교체하지 않는다.

### 5.2 현재 하늘 상태 예외

하늘상태는 기온처럼 전국 모든 위치에 동일 품질의 직접 관측값이 항상 존재하지 않는다.

따라서 다음 순서를 사용한다.

1. 최근접 유효 관측소의 현천/운량
2. 관측값이 없으면 현재 시각에 대응하는 최신 초단기/단기 예보 `SKY`
3. 2번을 사용한 경우 응답은 `dataRole=FORECAST_PROXY`로 구분

UI가 순수 관측만을 의미해야 한다면 항목명을 `현재 하늘 상태`가 아니라 `하늘 상태`로 두는 편이 안전하다.

---

## 6. `미래`·`예상` 항목별 데이터 원본

| 앱 표시 항목 | 원본 | 필드 | 시간 선택 규칙 |
| --- | --- | --- | --- |
| 예상 기온 | 기상청 단기예보 | `TMP` | `forecastAt`과 정확히 일치 |
| 예상 체감온도 | 서버 계산 | `TMP+REH+WSD` | 같은 `forecastAt` 값끼리 계산 |
| 예상 습도 | 단기예보 | `REH` | 정확히 같은 시각 |
| 예상 풍속·풍향 | 단기예보 | `WSD+VEC` | 정확히 같은 시각 |
| 예상 하늘상태 | 단기예보 | `SKY` | 정확히 같은 시각 |
| 예상 강수형태 | 단기예보 | `PTY` | 정확히 같은 시각 |
| 예상 강수확률 | 단기예보 | `POP` | 정확히 같은 시각 |
| 예상 강수량 | 단기예보 | `PCP` | 정확히 같은 시각 |
| 예상 신적설 | 단기예보 | `SNO` | 해당 시각까지의 1시간, 현재 총 적설과 구분 |
| 예상 자외선 | 생활기상지수 | `h0~h75` | 제공 3시간 슬롯 기준, 시간별 값으로 위장 금지 |
| 미래 대기질 | 에어코리아 예보통보 | PM10/PM2.5/O3 지역 등급 | `informData` 대상 날짜 사용 |
| 4~10일 날씨 | 중기육상예보 | `wfNAm/wfNPm`, `rnSt*` | 오전/오후 슬롯 사용 |
| 4~10일 최저·최고 | 중기기온 | `taMinN/taMaxN` | 대상 날짜 사용 |

### 6.1 예보 선택 알고리즘

```text
target = 사용자가 보고 있는 미래 시각

1. forecastAt == target 인 후보만 선택
2. 후보 중 issuedAt이 가장 최근인 것 선택
3. source fetch 시각은 값 선택 기준이 아님
4. exact slot이 없으면 provider의 공식 시간 단위를 사용하고 timeMatch를 명시
5. 현재 관측값을 target 미래시각에 복사하지 않음
```

### 6.2 현재 시각을 지난 예보 슬롯

현재 시각 이전 슬롯은 `현재` 카드에 사용하지 않는다. 과거 비교나 예보 정확도 분석 용도로만 유지한다.

---

## 7. Week 데이터

| 항목 | 우선 원본 | 처리 원칙 |
| --- | --- | --- |
| 오늘~단기 범위 | 단기예보 | 최신 발표분의 해당 날짜 슬롯 |
| 단기 범위 이후 | 중기육상예보 | `midTermLandRegId` 기준 대상 날짜·오전/오후 정확히 매칭 |
| 중기 최저·최고 | 중기기온 | `midTermTaRegId` 기준 대상 날짜 사용 |
| 단기 최저·최고 | `TMN/TMX` 우선 | 없으면 같은 날짜 `TMP` 최솟값/최댓값을 fallback으로 명시 |
| 평균 습도 | 단기 `REH` | 해당 날짜 슬롯만 평균 |
| 최대 풍속 | 단기 `WSD` | 해당 날짜 슬롯만 최대 |
| 최대 자외선 | 생활기상지수 | 해당 날짜 제공 슬롯 최댓값 |
| 강수 | 단기 `POP/PCP`, 이후 중기 | 날짜/시간 범위를 섞지 않음 |
| 예상 신적설·눈 예보 | 단기 `SNO/PTY` | 해당 날짜 범위, 현재 총 적설과 구분 |
| 대기질 | 에어코리아 일/주간 예보 | 측정값을 미래로 복사 금지 |
| 과거 실제값 | APIHub 지상·AWS 일자료 | 최근접 유효 관측소 + 거리 표시 |

### 7.1 Week 응답은 활성지역 등록 여부에 의존하지 않는다

`/weekly` 요청을 받은 서버는 앱의 설치정보/활성지역 등록이 먼저 끝났는지 확인하지 않는다. 요청 자체에 포함된 `LocationContext`만으로 필요한 자료를 준비한다.

```text
GET /weekly
  ↓
요청 지역의 nx/ny + adminCode 해석
  ↓
단기예보 캐시 확인
  ├─ miss/stale -> 즉시 getVilageFcst 보충
  ↓
응답해야 할 날짜 범위 계산
  ↓
단기예보가 덮지 못하는 날짜가 있는가?
  ├─ NO  -> 단기 자료로 조립
  └─ YES -> midTermLandRegId / midTermTaRegId 해석
              ↓
           중기 캐시 확인
              ├─ miss/stale -> 즉시 getMidLandFcst/getMidTa 보충
              ↓
           단기 + 중기 병합 후 응답
```

**중기 캐시가 없다는 이유로 해당 날짜 카드를 빈 객체로 반환하지 않는다.** 필요한 중기자료를 즉시 보충한 뒤 응답하는 것이 기본 동작이다. 원본 API 장애까지 겹쳐 즉시 보충할 수 없을 때만 `sourceStatus=UNAVAILABLE`을 명시하며, 이전 정상 발표분이 대상 날짜를 포함하면 last-known-good를 사용할 수 있다.

### 7.2 단기/중기 경계는 고정 날짜가 아니라 실제 coverage로 결정

`오늘+N일`처럼 하드코딩하지 않는다. 최신 단기예보 응답에서 실제로 존재하는 가장 마지막 `forecastAt`을 구해 coverage를 만든다.

```text
shortTermCoverageEnd = max(forecastAt of valid short-term cache)

cardDate의 필요한 시각 <= shortTermCoverageEnd
  -> 단기 우선
그 이후
  -> 중기 필요
```

따라서 날짜가 하루 지나 단기예보 범위가 9월 26일까지 늘어나는 것과 관계없이, 그 전날에도 필요한 9월 26일 중기자료가 자동 보충되어야 한다.

### 7.3 중기예보 캐시는 `nx/ny`가 아니라 `regId` 단위로 공유

현재처럼 `57/125`, `58/125`별로 중기자료를 따로 보관하지 않는다.

```text
getMidLandFcst cache key
  = midTermLandRegId + tmFc

getMidTa cache key
  = midTermTaRegId + tmFc
```

여러 격자가 동일한 중기예보구역을 사용하면 같은 캐시를 공유한다. 이 구조는 호출량을 줄이고, 한 격자만 중기자료가 빠지는 문제를 제거한다. 기상청 중기예보는 일 2회(06시·18시) 발표되고 별도의 중기 예보구역을 사용하므로 격자별 중복 호출이 필요하지 않다.

---

## 8. 데이터 수집 주기

아래 주기는 **사용자 수와 독립적으로 서버가 한 번 수집하여 공유**하는 것을 원칙으로 한다.

### 8.1 기상청 APIHub 전역 데이터

| 데이터 | API | 수집 주기 | 1일 기본 호출량 | 비고 |
| --- | --- | ---: | ---: | --- |
| 10분 격자 실황 | `nph-dfs_odam_grd` | 10분 | `6변수 × 144 = 864` | `T1H,REH,WSD,VEC,PTY,RN1`; 전국 격자를 한 번 수집 |
| AWS 최신 fallback | `nph-aws2_min`, `stn=0` | 5분 | 288 | 전국 지점 snapshot |
| AWS 현천/운량 | 관련 AWS 현천·운량 API | 10분 | 최대 288 | 현재 하늘상태 보조 |
| 가시거리 | `kma_sfctm5.php`, `VS`, `stn=0` | 10분 | 144 | 전국 지점 snapshot |
| 레이더 HSR | `nph-rdr_cmp1_api` | 5분 | 288 | 전국 500m 자료를 서버에서 좌표 추출 |
| 발효 특보 | `wrn_now_data_new.php` | 5분 | 288 | 전국 snapshot |
| 과거 일관측 | `sfc_aws_day.php` | 1일 1회 | 수 회 | 전일 확정값 수집 |
| 도로살얼음 | `road_file_down.php` | 동절기 30분 기본 | `48 × 지원노선수` | 아래 동적 예산 적용 |

### 8.2 APIHub 호출 예산

APIHub 일반회원 기본 한도는 일 20,000호출, 5GB이므로 운영 목표를 다음처럼 잡는다.

```text
정상 상시 수집 목표        <= 6,000 calls/day
동절기 포함 목표           <= 10,000 calls/day
경고 임계치                 12,000 calls/day
신규 비필수 수집 중단선     14,000 calls/day
절대 하드스톱               granted_limit의 80%
```

`20,000`을 끝까지 쓰는 것이 아니라 최소 20% 이상을 장애 재시도·긴급 on-demand용으로 남긴다.

도로살얼음은 지원 노선 수가 많아지면 다음 예산을 적용한다.

```text
ROAD_ICE_DAILY_BUDGET = 2400
기본 주기 = 30분

48 × routeCount > 2400 이면
  -> routeCount에 맞춰 60분 이상으로 자동 완화
```

하절기에는 도로살얼음 API를 호출하지 않는다.

### 8.3 단기예보 `getVilageFcst`

발표 시각:

```text
02, 05, 08, 11, 14, 17, 20, 23 KST
```

수집 방식:

1. 최근 사용된 `nx/ny`는 새 발표분이 조회 가능해진 후 갱신
2. 신규 `nx/ny` 요청은 캐시 미스 시 즉시 원본 조회
3. 같은 `nx/ny + base_date + base_time` 동시 요청은 single-flight 1건으로 합침
4. 이전 발표분도 유효기간 동안 보존하여 원본 장애 시 대상 시각 데이터가 사라지지 않게 함

권장 스케줄:

```text
02:15, 05:15, 08:15, 11:15,
14:15, 17:15, 20:15, 23:15
```

고정 `15분`은 단순 지연 가정이 아니라 **최신 발표분 조회 성공 여부를 확인하고 실패하면 backoff**하도록 구현한다.

공공데이터포털 개발계정 기본 10,000건/일 기준 예산:

```text
70%  활성/고정 지역 정기 갱신
20%  신규 지역·GPS 이동 cache miss
10%  재시도·운영 여유
```

실제 운영계정에 승인된 일 한도 `Q`를 설정값으로 읽고, 모든 비율 계산은 `Q` 기준으로 한다.

### 8.4 단기예보 용량 사전 검증

누락 없는 운영을 보장하려면 배포 전에 다음을 계산한다.

```text
A = 하루 동안 새 발표분을 적극 갱신해야 하는 최대 unique nx/ny 수
N = 하루 신규/이동으로 처음 조회되는 unique nx/ny 예상치
R = 재시도 예산
Q = 실제 승인된 getVilageFcst 일 한도

8 × A + N + R <= 0.8 × Q
```

이 조건을 만족하지 않으면:

- 정기 갱신 대상의 active window를 줄이거나,
- 운영계정 트래픽 증량을 신청한 뒤,
- 조건이 만족될 때만 `누락 없음`을 운영 보장으로 선언한다.

**일일 quota를 넘겨서 데이터를 잃는 구조는 허용하지 않는다.**

### 8.5 중기예보

- 공식 발표: 06시, 18시
- 수집: `06:15`, `18:15` + 실패 시 backoff
- **활성 `nx/ny` 목록이 아니라 서버가 지원하는 unique `midTermLandRegId` / `midTermTaRegId` 목록을 기준으로 갱신**
- `getMidLandFcst`와 `getMidTa`는 각각 `regId + tmFc` 단위의 서버 공용 캐시 사용
- 신규 지역 요청에서 필요한 `regId` 캐시가 없거나 최신 발표분이 비어 있으면 `/weekly` 처리 중 즉시 on-demand 조회
- on-demand와 정기 collector가 동시에 같은 `regId + tmFc`를 요청하면 single-flight로 1회만 외부 호출
- 앱의 설치정보/활성지역 등록 여부는 중기예보 수집·응답 조건으로 사용하지 않음

중기예보는 격자별로 수집하지 않으므로 호출 예산은 대략 다음과 같다.

```text
L = 지원하는 unique midTermLandRegId 수
T = 지원하는 unique midTermTaRegId 수

정기 호출량/일 ≈ 2 × (L + T)
추가 호출량   = 신규/미수집 regId에 대한 on-demand 보강분
```

동일 `regId`를 공유하는 수십~수백 개 격자가 있어도 중기 원본 호출은 증가하지 않는다. 공공데이터포털의 중기예보 서비스는 개발계정 기준 10,000건/일이며 운영계정은 증량 신청이 가능하므로, 이 방식은 격자별 수집보다 훨씬 작은 호출량으로 안정적으로 운영할 수 있다.

### 8.6 자외선

생활기상지수는 3시간 단위 값이므로 10분마다 재조회하지 않는다.

```text
활성 areaNo: 3시간마다 최신 발표 여부 확인
신규 areaNo: cache miss 즉시 조회
캐시: 발표분 전체 h0~h75 보존
```

현재 시각 표시에서는 현재보다 미래인 슬롯을 `현재 관측`처럼 사용하지 않고 `FORECAST_CURRENT_SLOT`으로 구분한다.

### 8.7 에어코리아 실시간 대기질

측정소별 사용자 요청 방식보다 서버 공용 snapshot 방식이 안정적이다.

권장:

```text
측정소 메타데이터: 1일 1회
시도별 실시간 측정: 매시 10분, 18개 시도 일괄
```

최대 대략:

```text
18 × 24 = 432 calls/day
```

서버는 전국 측정소 좌표를 보유하고, GPS/격자 대표점과의 거리를 계산하여 가장 가까운 **유효값이 있는 측정소**를 선택한다.

### 8.8 에어코리아 예보

미세먼지 예보는 공식 발표에 맞춰 수집한다.

```text
05:10, 11:10, 17:10, 23:10
PM10 / PM2.5 / 필요 시 O3
```

오존은 계절별 제공 여부를 따르고, 비시즌 빈 결과를 오류로 취급하지 않는다.

주간 초미세먼지 전망은 17:30 발표 후 17:40경 1회 수집한다.

### 8.9 ITS 도로 통제

GPS별로 API를 직접 반복 호출하지 않는다.

권장:

```text
전국 또는 충분히 큰 권역 snapshot: 5분
서버가 사용자 GPS 3km 안의 이벤트만 필터
```

발급받은 ITS 키의 실제 일 한도를 `ITS_DAILY_LIMIT`으로 설정하고, 80% 하드스톱을 둔다. 공개 문서에서 일 한도가 명확하지 않은 경우 임의 숫자를 코드에 가정하지 않는다.

---

## 9. 누락 방지 설계

### 9.1 새로운 지역 선택

새 `nx/ny` 또는 새 행정지역이 서버 캐시에 없어도 빈 응답을 반환하지 않는다.

```text
요청 수신
  ↓
LocationContext 해석
  ├─ nx/ny
  ├─ adminCode
  ├─ midTermLandRegId
  └─ midTermTaRegId
  ↓
단기 캐시 조회
  ↓ miss
single-flight lock 획득
  ↓
getVilageFcst 즉시 호출/저장
  ↓
Week 범위가 중기자료를 요구하는지 확인
  ↓ YES
중기 regId 캐시 조회
  ↓ miss
getMidLandFcst/getMidTa 즉시 호출/저장
  ↓
단기+중기 조립 후 응답
```

실황은 전국 격자를 주기적으로 수집하므로 새 지역이라고 별도 원본 호출이 필요하지 않는 구조가 이상적이다. **중기예보도 해당 지역의 설치 등록을 기다리지 않고 `/weekly` 요청 안에서 필요한 경우 즉시 준비한다.**

### 9.2 GPS 위치 이동

앱이 위치를 갱신할 때:

```text
새 lat/lon
   ↓
새 nx/ny 계산
   ↓
old nx/ny와 비교
```

- 동일 격자: 단기예보 재조회 불필요. 단, 행정지역이 달라졌다면 중기 `regId`는 다시 판정한다.
- 다른 격자: 새 격자 단기 캐시 사용, 없으면 즉시 on-demand fetch. 동일 중기 `regId`라면 중기 캐시는 그대로 재사용한다.
- 행정지역 변경: `midTermLandRegId` 또는 `midTermTaRegId`가 바뀌면 해당 공용 캐시로 즉시 전환하고, 없으면 on-demand fetch한다.
- 대기질/도로/관측소 항목: GPS 실제 좌표 기준 최근접 source를 다시 선택

권장 위치 변경 판정:

```text
격자형 날씨: nx/ny가 바뀔 때
거리 기반 데이터: 1 km 이상 이동 또는 5분 경과 중 먼저 충족
```

불필요한 GPS 미세 이동으로 API를 계속 호출하지 않는다.

### 9.3 운영서버 신규 배포

배포가 캐시 초기화를 의미하면 안 된다.

필수 조건:

1. 날씨 캐시는 컨테이너/프로세스 메모리가 아니라 영속 DB에 저장
2. 신규 버전 배포 시 기존 cache table 삭제 금지
3. 스키마 변경은 backward-compatible migration 사용
4. 배포 직후 collector가 뜨기 전에도 기존 정상 캐시를 읽을 수 있어야 함
5. cache miss는 on-demand fetch가 보강
6. collector는 distributed lease를 획득해 중복 수집 방지

### 9.4 첫 설치/완전 빈 DB

DB가 정말 비어 있는 첫 구축은 readiness gate를 사용한다.

최소 준비 항목:

```text
- 최신 10분 실황 전국 격자
- AWS 최신 fallback snapshot
- 특보
- 레이더 최신분
- 대기질 측정소 메타데이터
- 행정지역 → 중기육상/중기기온 regId 매핑 테이블
```

위 공용자료가 준비된 뒤 weather API를 `ready`로 올린다.

위치별 단기예보는 요청 시 on-demand fetch가 가능하므로 모든 지역을 미리 기다릴 필요는 없다.

### 9.5 원본 API 장애

원본 실패를 `null`로 즉시 덮어쓰지 않는다.

```text
fresh cache 있음 -> fresh cache
fresh 없음 + 원본 성공 -> 새 값 저장/응답
fresh 없음 + 원본 실패 -> 마지막 정상값 + STALE 표시
마지막 정상값도 없음 -> 보조 source 조회
```

`현재` 자료는 stale 허용시간을 짧게, `미래` 예보는 동일 `forecastAt`의 이전 발표분을 더 오래 fallback할 수 있다.

---

## 10. 캐시 키와 보존 정책

### 10.1 실황 격자

```text
key = provider + variable + observedAt
value = 전국 nx/ny grid
```

최신 6시간 정도를 보존하고, 장기 과거 분석이 필요하면 별도 history storage로 이동한다.

### 10.2 단기예보

```text
key = nx + ny + issuedAt + forecastAt + category
```

- 동일 `forecastAt`에 여러 `issuedAt`을 보존
- 응답 시 최신 `issuedAt` 우선
- 이전 발표분은 장애 fallback 및 예보 정확도 분석용으로 유지

### 10.3 중기예보

```text
육상날씨 key = midTermLandRegId + issuedAt(tmFc)
기온 key     = midTermTaRegId + issuedAt(tmFc)
```

- `nx/ny`는 중기예보 cache key에 포함하지 않는다.
- 같은 `regId`를 사용하는 모든 격자가 같은 cache row를 공유한다.
- 최신 발표분 외에도 이전 정상 발표분을 보존해 원본 장애 시 대상 날짜가 포함되는지 검사한 뒤 fallback할 수 있게 한다.
- 행정지역→`regId` 매핑은 별도 버전 관리하며, 격자 catalog와 분리한다.

### 10.4 대기질

```text
station metadata -> 장기 캐시
realtime value   -> stationId + dataTime
forecast         -> informCode + informData + issuedAt
```

---

## 11. API 호출 한도 관리

### 11.1 확인된 기본 한도

- 기상청 APIHub 일반회원: 일 최대 20,000호출, 일 최대 5GB
- 공공데이터포털 기상청 단기예보 개발계정: 10,000건/일, 운영계정은 활용사례 등록 후 증량 가능
- 공공데이터포털 기상청 중기예보 개발계정: 10,000건/일, 운영계정 증량 가능
- 생활기상지수도 개발계정 기본 10,000건/일 수준으로 운영계정 증량 가능
- 에어코리아도 개발/운영계정의 실제 승인 트래픽을 설정값으로 읽어 관리

### 11.2 코드에서 반드시 구현할 quota guard

각 외부 provider마다 일별 counter를 둔다.

```text
provider
service
dateKst
usedCalls
failedCalls
bytesDownloaded(optional)
limitCalls
warningThreshold
hardStopThreshold
```

권장:

```text
warning  = 60%
softStop = 70%   -> 비필수 background 축소
hardStop = 80%   -> cache miss용 reserve 제외 신규 background 금지
reserve  = 20%   -> 장애 재시도·신규 위치용
```

중요한 것은 **API가 오류를 반환할 때 무한 retry하지 않는 것**이다.

권장 retry:

```text
1차 실패 -> 30초
2차 실패 -> 60초
3차 실패 -> 2분
그 이후 -> 다음 정규 주기 + stale cache
```

동일 요청은 retry도 single-flight로 합친다.

---

## 12. API별 호출 예제

### 12.1 10분 동네예보 실황 — 현재값 1순위

공식 APIHub:

```bash
curl "https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-dfs_odam_grd?tmfc=202609220840&vars=T1H&authKey=<APIHUB_KEY>"
```

같은 시각에 필요한 변수:

```text
T1H, REH, WSD, VEC, PTY, RN1
```

각 결과에서 선택 위치의 정확한 `nx/ny` cell을 사용한다.

### 12.2 AWS 최신 fallback

```bash
curl "https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-aws2_min?tm2=<YYYYMMDDHHMM>&stn=0&disp=1&help=0&authKey=<APIHUB_KEY>"
```

전국 지점을 한 번 받아 서버에서 선택 위치와 가장 가까운 유효 지점을 찾는다.

### 12.3 단기예보

```bash
curl "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst?serviceKey=<SERVICE_KEY>&pageNo=1&numOfRows=1000&dataType=JSON&base_date=20260922&base_time=0500&nx=60&ny=121"
```

현재 기온을 만들기 위해 `TMP`를 사용하지 않는다. `TMP`는 해당 `forecastAt`의 미래/예상 기온에만 사용한다.

### 12.4 중기예보

```bash
curl "https://apis.data.go.kr/1360000/MidFcstInfoService/getMidTa?ServiceKey=<SERVICE_KEY>&pageNo=1&numOfRows=10&dataType=JSON&regId=11B20601&tmFc=202609220600"

curl "https://apis.data.go.kr/1360000/MidFcstInfoService/getMidLandFcst?ServiceKey=<SERVICE_KEY>&pageNo=1&numOfRows=10&dataType=JSON&regId=11B00000&tmFc=202609220600"
```

### 12.5 자외선

```bash
curl "https://apis.data.go.kr/1360000/LivingWthrIdxServiceV5/getUVIdxV5?ServiceKey=<SERVICE_KEY>&pageNo=1&numOfRows=10&dataType=JSON&areaNo=<10자리_행정코드>&time=2026092206"
```

### 12.6 에어코리아

측정소 목록:

```bash
curl "https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList?serviceKey=<SERVICE_KEY>&returnType=json&numOfRows=1000&pageNo=1"
```

시도별 실시간 값은 `getCtprvnRltmMesureDnsty`를 사용해 서버 공용 snapshot으로 모으는 것을 권장한다.

### 12.7 레이더

```bash
curl "https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-rdr_cmp1_api?tm=<YYYYMMDDHHMM>&cmp=HSR&qcd=MSK&obs=ECHO&map=HB&disp=B&authKey=<APIHUB_KEY>" --output radar.bin
```

### 12.8 특보·도로살얼음

```bash
curl "https://apihub.kma.go.kr/api/typ01/url/wrn_now_data_new.php?fe=e&tm=<YYYYMMDDHHMM>&disp=0&help=0&authKey=<APIHUB_KEY>"

curl "https://apihub.kma.go.kr/api/typ04/url/road_file_down.php?roadNum=001&authKey=<APIHUB_KEY>" --output road-001.zip
```

---

## 13. 서버 응답 계약

### 13.1 현재값

```json
{
  "current": {
    "dataRole": "OBSERVATION",
    "observedAt": "2026-09-22T08:40:00+09:00",
    "fetchedAt": "2026-09-22T08:42:10+09:00",
    "dataAgeMinutes": 2,
    "temperature": 20.4,
    "humidity": 68,
    "windSpeed": 1.8,
    "provider": "KMA_APIHUB_DFS_OBSERVATION",
    "providerField": "T1H,REH,WSD,VEC",
    "sourceLocation": {
      "type": "GRID",
      "nx": 60,
      "ny": 121,
      "locationMatch": "EXACT_GRID"
    },
    "qualityFlags": []
  }
}
```

AWS fallback이면:

```text
dataRole = OBSERVATION
provider = KMA_AWS_MINUTE
locationMatch = NEAREST_STATION
qualityFlags += LOCATION_FALLBACK
```

### 13.2 미래값

```json
{
  "forecast": {
    "dataRole": "FORECAST",
    "issuedAt": "2026-09-22T08:00:00+09:00",
    "forecastAt": "2026-09-22T14:00:00+09:00",
    "temperature": 24,
    "providerField": "TMP",
    "timeMatch": "EXACT",
    "sourceLocation": {
      "type": "GRID",
      "nx": 60,
      "ny": 121,
      "locationMatch": "EXACT_GRID"
    }
  }
}
```

### 13.3 Week 지역·출처 계약

`/weekly`에는 지역 판정과 단기/중기 coverage를 확인할 수 있는 메타데이터를 남긴다.

```json
{
  "region": {
    "nx": 57,
    "ny": 125,
    "adminCode": "1153080000",
    "name": "서울특별시 구로구 항동",
    "midTermLandRegId": "11B00000",
    "midTermTaRegId": "11B10101"
  },
  "weeklyCoverage": {
    "shortTermUntil": "2026-09-25T23:00:00+09:00",
    "midTermIssuedAt": "2026-09-21T18:00:00+09:00",
    "midTermCacheStatus": "HIT|MISS_REFRESHED|STALE_FALLBACK|UNAVAILABLE"
  }
}
```

각 날짜 카드도 `source=SHORT_TERM | MID_TERM | MIXED`를 기록해 특정 날짜가 왜 비었는지 서버 로그와 응답만으로 추적할 수 있게 한다.

---

## 14. 배포 전 검증 항목

배포 전에 아래 테스트를 자동화한다.

### 현재값

- [ ] `/main`, `/today`의 현재 기온이 `TMP`가 아님
- [ ] `dataRole=OBSERVATION`
- [ ] `providerField`에 `T1H` 포함
- [ ] `observedAt <= now`
- [ ] `dataAgeMinutes <= CURRENT_MAX_AGE`
- [ ] 요청한 `nx/ny`와 source grid가 동일하거나 fallback이 명시됨

### 미래값

- [ ] 표시한 시각과 `forecastAt`이 동일
- [ ] 최신 정상 `issuedAt`을 선택
- [ ] 현재 실황을 미래값에 복사하지 않음
- [ ] 다른 시각의 값을 임의로 보간/복사하지 않음

### 신규 지역

- [ ] 캐시가 없는 `nx/ny` 요청 시 on-demand fetch
- [ ] 동시에 100개 요청해도 원본 호출은 single-flight 1회
- [ ] 성공 후 영속 캐시에 저장

### Week/중기예보 누락

- [ ] 한 번도 활성지역으로 등록되지 않은 `nx/ny`를 첫 요청해도 중기 날짜 카드가 채워짐
- [ ] 단기 coverage 밖 날짜가 있으면 `/weekly`가 중기 cache miss를 즉시 보충한 뒤 응답
- [ ] 중기 cache miss 후 10분 collector를 기다리지 않음
- [ ] 같은 `midTermLandRegId`/`midTermTaRegId`를 공유하는 서로 다른 `nx/ny`가 같은 cache를 재사용
- [ ] `57/125` 항동 요청에 행정지역이 서울 구로구 항동으로 주어지면 격자 catalog의 부천 매핑을 우선하지 않음
- [ ] 행정지역 정보 없이 모호한 격자만 들어오면 잘못된 중기구역을 추측하지 않고 region resolution을 수행하거나 명시적 오류/quality flag 반환
- [ ] 지역 변경 직후 별도의 '활성지역 등록 완료' 이벤트 없이도 WEEK 응답이 완성됨

### GPS 이동

- [ ] 격자 경계를 넘어가면 새 `nx/ny`로 즉시 전환
- [ ] 같은 격자 내 이동은 예보 API 중복 호출 없음
- [ ] 최근접 측정소/도로 이벤트는 새 좌표 기준 재선택

### 재배포

- [ ] 프로세스 재시작 전후 캐시 유지
- [ ] DB migration이 기존 자료를 삭제하지 않음
- [ ] collector 시작 전 기존 캐시 응답 가능
- [ ] collector 중복 실행 방지 lock 동작

### API 한도

- [ ] provider별 일일 사용량 counter
- [ ] 60/70/80% 임계치 동작
- [ ] retry 폭주 방지
- [ ] 동절기 도로살얼음 추가 호출 포함해 budget 이내

---

## 15. 현재 운영에서 반드시 수정할 부분

기존 운영 조회에서는 `current.dataRole=FORECAST`, `providerField=TMP,...`가 확인됐다. 따라서 다음을 가장 먼저 수정한다.

1. 운영 서버가 최신 소스/실행 경로를 사용하고 있는지 확인
2. Cloudflare Tunnel이 올바른 원본 프로세스를 가리키는지 확인
3. 배포 후 프로세스 재시작 여부 확인
4. `current` 조립 코드에서 `TMP`를 현재 기온으로 사용하는 경로 제거
5. APIHub 10분 실황 collector 추가
6. AWS fallback collector 추가
7. 캐시 miss on-demand + single-flight 구현
8. `/weekly`에서 단기 coverage 밖 날짜가 있으면 중기예보 cache miss를 즉시 보충
9. 중기예보 캐시 키를 `nx/ny`에서 `midTermLandRegId` / `midTermTaRegId`로 변경
10. `kmaMidTermGridCatalog`의 격자→중기지역 직접 판정을 최종 판정 기준에서 제거하고 행정지역 기반 resolver로 교체
11. 앱의 지역 등록 완료 여부와 WEEK 데이터 준비를 분리
12. 캐시를 영속 DB로 유지하고 배포 시 삭제하지 않기
13. response에 `observedAt`, `forecastAt`, `issuedAt`, `sourceLocation`, `locationMatch`, `dataAgeMinutes`를 강제하고 `/weekly`에는 `midTerm*RegId`, coverage, cacheStatus도 기록

### 금지 규칙

```text
현재 기온 = 단기예보 TMP                         금지
현재 시각보다 미래 forecastAt을 현재값으로 사용    금지
다른 nx/ny 예보를 아무 표시 없이 사용              금지
GPS 이동 후 이전 격자 캐시를 계속 사용              금지
배포 시 캐시 초기화                                  금지
원본 오류 시 null로 정상 캐시 덮어쓰기               금지
quota 소진까지 background polling                    금지
활성 격자에만 중기예보를 수집                         금지
중기예보 cache key에 nx/ny 사용                         금지
nx/ny만으로 행정지역/중기기온 구역 확정                금지
중기 cache miss 상태로 빈 Week 카드를 정상 응답         금지
```

---

## 16. 관련 코드 위치

| 목적 | 파일 |
| --- | --- |
| 앱 운영 서버 주소 | `weather_care_app/lib/services/app_config.dart` |
| 앱 서버 호출 파라미터 | `weather_care_app/lib/services/weather_service.dart` |
| Main·Today·Week API 조립 | `weather_care_server/src/api/weather.ts` |
| 어제 비교 API | `weather_care_server/src/api/comparison.ts` |
| 기존 초단기실황 | `weather_care_server/src/providers/weather/kmaUltraShortObservationProvider.ts` |
| **신규 10분 격자 실황 provider 권장** | `weather_care_server/src/providers/weather/kmaGridObservationProvider.ts` |
| **신규 AWS fallback provider 권장** | `weather_care_server/src/providers/weather/kmaAwsMinuteProvider.ts` |
| 단기예보·체감온도 | `weather_care_server/src/providers/weather/kmaWeatherProvider.ts` |
| 중기예보 | `weather_care_server/src/providers/weather/kmaMidTermProvider.ts` |
| **기존 격자→중기지역 catalog (리팩터링 대상)** | `weather_care_server/src/regions/kmaMidTermGridCatalog.ts` |
| **신규 행정지역→중기지역 resolver 권장** | `weather_care_server/src/regions/kmaMidTermRegionResolver.ts` |
| **Week 즉시 중기 보충 로직 권장** | `weather_care_server/src/services/weeklyForecastHydrator.ts` |
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
| **quota guard 권장** | `weather_care_server/src/collection/providerQuotaGuard.ts` |
| **single-flight 권장** | `weather_care_server/src/collection/requestCoalescer.ts` |
| 규칙 기준 | `weather_care_server/src/config/ruleConfig.ts` |
| 준비물 추천 | `weather_care_server/src/recommendations/recommendationEngine.ts` |

---

## 17. 운영 진단용 필수 로그

정밀 GPS 원문과 인증키는 로그에 남기지 않는다.

다음만 기록한다.

```text
requestId
region.nx / region.ny
region.adminCode
region.midTermLandRegId
region.midTermTaRegId
locationMode
provider
providerField
dataRole
observedAt
forecastAt
issuedAt
fetchedAt
dataAgeMinutes
locationMatch
stationId(optional)
distanceKm(optional)
qualityFlags
cacheStatus = HIT | MISS | STALE | REFRESHED | MISS_REFRESHED
shortTermCoverageEnd(optional)
weeklyCardSource(optional) = SHORT_TERM | MID_TERM | MIXED
quotaUsedRatio
```

---

## 18. 공식 참고자료

- 기상청 APIHub 동네예보 조회: https://apihub.kma.go.kr/apiList.do?seqApi=10
- 기상청 APIHub 이용안내/호출한도: https://apihub.kma.go.kr/apiInfo.do
- 기상청 APIHub AWS 매분자료: https://apihub.kma.go.kr/apiList.do?seqApi=2&seqApiSub=239
- 기상청 단기예보 조회서비스: https://www.data.go.kr/data/15084084/openapi.do
- 기상청 중기예보 조회서비스: https://www.data.go.kr/data/15059468/openapi.do — 중기예보는 일 2회(06/18시) 발표하며 단기 5 km 격자와 별도의 중기 예보구역을 사용
- 기상청 생활기상지수 조회서비스: https://www.data.go.kr/data/15085288/openapi.do
- 에어코리아 대기오염정보: https://www.data.go.kr/data/15073861/openapi.do
- 에어코리아 대기질 예보: https://airkorea.or.kr/web/dustForecast
- 국가교통정보센터 오픈데이터: https://www.its.go.kr/opendata/intro

---

## 19. 최종 구현 우선순위

### P0 — 현재 기온 오류 제거

1. `current=TMP` 경로 제거
2. APIHub 10분 실황 `T1H` 적용
3. `observedAt`/freshness 적용
4. 정확한 `nx/ny` cell 검증

### P1 — 누락 없는 지역/Week 전환

1. `/weekly` 자체에서 단기/중기 coverage 확인 및 cache miss 즉시 보충
2. 중기 캐시를 `midTermLandRegId` / `midTermTaRegId` 단위로 공용화
3. 행정지역 기반 중기구역 resolver 도입, `nx/ny` 단독 판정 제거
4. 지역 활성 등록과 날씨 응답의 의존성 제거
5. cache miss on-demand + single-flight
6. GPS `nx/ny` 및 행정지역 변경 감지
7. 최근접 관측소 fallback
8. 영속 cache

### P2 — 수집 주기와 quota

1. 전역 snapshot collector
2. provider별 quota counter
3. 계절별 road-ice 스케줄
4. retry/backoff
5. 60/70/80% budget policy

### P3 — 운영 안정성

1. rolling deployment에서도 cache 유지
2. readiness bootstrap
3. distributed collector lock
4. source/time/location 진단 로그
5. 원본 장애 시 last-known-good 유지

이 순서대로 구현하면 `현재=최신 관측`, `미래=해당 시각 예보`, `위치=선택한 좌표 기준`, `새 지역/GPS 이동/재배포=누락 최소화`라는 운영 계약을 일관되게 지킬 수 있다.

---

## 20. 항동 `57/125` / 구로동 `58/125` 누락 사례에 대한 설계 적용

### 20.1 기존 실패 흐름

2026-09-21 18:50 기준 사례는 다음과 같이 설명된다.

```text
구로동 58/125
  -> 기존 활성 격자
  -> 중기예보 캐시 존재
  -> 9/26 카드 정상

항동 57/125
  -> 새로 선택한 격자
  -> 단기예보는 존재하지만 당시 coverage는 9/25까지
  -> 9/26에는 중기예보 필요
  -> 활성지역 등록/10분 보충수집 전에 /weekly가 먼저 실행
  -> 57/125용 중기 캐시 없음
  -> 9/26 카드 누락
```

이 구조의 문제는 **중기예보 준비 여부가 `활성 nx/ny` 등록과 collector 주기에 묶여 있었다는 것**이다.

### 20.2 수정 후 정상 흐름

```text
사용자가 '서울특별시 구로구 항동' 선택
  ↓
앱이 /weekly 요청에
  nx=57, ny=125,
  adminCode/지역명 전달
  ↓
서버 LocationContext 생성
  ├─ grid = 57/125
  ├─ admin = 서울특별시 구로구 항동
  ├─ midTermLandRegId = 행정지역 기준 resolver 결과
  └─ midTermTaRegId   = 행정지역 기준 resolver 결과
  ↓
단기 cache 확인
  -> 9/25까지 존재
  ↓
Week가 9/26도 요구함을 확인
  ↓
해당 midTerm regId cache 확인
  ↓ miss
single-flight
  ↓
getMidLandFcst + getMidTa 즉시 조회
  ↓
regId 공용 영속 cache 저장
  ↓
9/26 포함 전체 Week 조립
  ↓
한 번의 /weekly 요청에서 완성된 응답 반환
```

따라서 앱이 별도의 지역 등록 완료를 기다리거나 10분 뒤 재시도할 필요가 없다.

### 20.3 항동 지역 정확성 문제

`57/125`가 부천 일부와 같은 격자 관계를 가진다는 이유만으로 중기기온을 부천 코드로 연결하지 않는다. **중기예보 구역 판정 입력은 사용자가 선택한 행정지역 또는 GPS로 해석한 행정지역**이다.

권장 요청 예:

```json
{
  "nx": 57,
  "ny": 125,
  "latitude": 37.0,
  "longitude": 126.0,
  "adminCode": "1153080000",
  "regionName": "서울특별시 구로구 항동"
}
```

정밀 좌표 예시는 계약 형태를 설명하기 위한 것이며 실제 로그에는 원문 좌표를 남기지 않는다.

### 20.4 앱-서버 요청 순서 수정

기존처럼:

```text
1. 지역 선택
2. 비동기 활성지역 등록 시작
3. 등록 완료를 기다리지 않고 /weekly 호출
4. 서버 collector가 나중에 중기예보 보충
```

하지 않는다.

권장 구조:

```text
지역 선택/GPS 갱신
  ↓
날씨 요청 자체에 완전한 LocationContext 전달
  ↓
서버가 응답에 필요한 source를 스스로 hydrate
  ↓
응답

활성지역 등록은 별도 비동기 최적화 정보일 뿐,
응답 완전성을 위한 선행조건이 아님
```

앱은 서버가 `MISS_REFRESHED`로 보충한 경우에도 별도 재호출 없이 첫 응답을 그대로 사용할 수 있어야 한다.

### 20.5 API 한도 영향

이 수정은 호출량을 늘리는 방향보다 **줄이는 방향**이다.

기존:

```text
중기예보 호출량 ∝ 활성 nx/ny 수
```

수정:

```text
중기예보 호출량 ∝ unique midTerm regId 수 × 하루 2회
                  + 아주 드문 cache miss 보강
```

따라서 구로동/항동처럼 서로 가까운 여러 격자를 각각 수집하는 중복을 제거할 수 있다. `/weekly`의 on-demand fetch도 같은 `regId + tmFc` 요청은 single-flight로 합치므로 신규 사용자가 동시에 몰려도 동일 원본을 반복 호출하지 않는다.

### 20.6 완료 판정 기준

아래가 모두 통과해야 이 이슈를 해결한 것으로 본다.

```text
[1] 서버 DB에서 57/125를 활성지역에서 제거
[2] 해당 중기 regId 최신 cache도 의도적으로 제거
[3] 앱/테스트에서 항동을 처음 선택
[4] 단 한 번 /weekly 호출
[5] 단기 coverage 밖의 날짜까지 카드가 채워짐
[6] 응답 midTermCacheStatus = MISS_REFRESHED 또는 HIT
[7] 두 번째 동일 지역 요청은 HIT
[8] 같은 midTerm regId를 공유하는 다른 nx/ny 요청도 외부 중기 API 추가 호출 없이 HIT
[9] 항동의 resolvedRegion이 서울 구로구 항동과 일치
[10] 운영서버 재배포 직후에도 1~9가 동일하게 동작
```

이 테스트는 **신규 지역**, **GPS 이동**, **캐시 미스**, **중기 공용 캐시**, **지역 정확성**, **재배포 후 누락 방지**를 한 번에 검증한다.




---

## 21. 구현 고정값 및 자동 회귀 테스트

항동 사례는 아래 값을 구현과 테스트에서 exact assertion으로 고정한다.

```text
LocationContext {
  nx: 57
  ny: 125
  sido: "서울특별시"
  sigungu: "구로구"
  eupMyeonDong: "항동"
  adminCode: "1153080000"
}

midTermTaRegId   == "11B10101"
midTermLandRegId == "11B00000"
```

격자 fallback 자체는 `57/125 → 부천(11B20204)`일 수 있지만, 행정지역 identity가 함께 들어오면 반드시 서울을 우선한다. 따라서 `nx/ny`만으로 중기기온 구역을 덮어쓰는 변경은 회귀 테스트에서 실패해야 한다.

`/weekly` 통합 테스트는 다음 흐름을 한 번에 검증한다.

1. 중기 원본 캐시와 57/125의 중기 조립 결과가 없는 상태로 시작한다.
2. 단기예보는 2026-09-25까지 존재하도록 준비한다.
3. `서울특별시 구로구 항동 + 1153080000 + 57/125`로 요청한다.
4. 같은 요청 처리 중 `getMidTa(11B10101)`와 `getMidLandFcst(11B00000)`를 호출한다.
5. 2026-09-26 카드의 최저·최고기온과 날씨가 비어 있지 않은지 확인한다.
6. 첫 응답의 `midTermCacheStatus`가 `MISS_REFRESHED`인지 확인한다.
7. 두 번째 동일 요청은 `HIT`이고 외부 중기 API 호출 횟수가 증가하지 않는지 확인한다.
8. 같은 중기 `regId`를 쓰는 다른 격자도 공용 캐시를 재사용하는지 확인한다.
9. 활성지역 등록 또는 10분 수집 Job 실행 없이 위 흐름이 완료되는지 확인한다.

현재 구현 파일은 다음과 같다.

- 지역 identity 우선 판정: `weather_care_server/src/regions/kmaMidTermRegionCatalog.ts`
- `regId + tmFc` 공용 캐시와 D1 single-flight: `weather_care_server/src/services/midTermForecastCache.ts`
- `/weekly` on-demand 보충과 coverage 메타데이터: `weather_care_server/src/api/weather.ts`
- 지원 중기구역 선수집: `weather_care_server/src/collection/weatherCollectionJob.ts`
- exact resolver 테스트: `weather_care_server/test/kmaMidTermProvider.test.ts`
- `/weekly` 통합 테스트: `weather_care_server/test/weatherApi.test.ts`
