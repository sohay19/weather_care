# 시험 서버 운영

스토어 신규 버전의 매일 오전 9시 OS별 업데이트 푸시는
[스토어 업데이트 운영 안내](STORE_UPDATE.md)를 참고한다. 별도 서비스로 배치하며
Android는 Google Play Developer API 연결 설정이 필요하다.

시험 API는 미니 PC의 `127.0.0.1:8788`에서 실행되고, Cloudflare Tunnel의
`weather-test-api.codesoha.com`으로 연결한다. 운영 API `8787`과 DB는 변경하지 않는다.

2026-10-22 현재 시험 릴리스는
`/opt/weather-care/releases/20261022-test-legacy-compat-0018/weather_care_server`이며
안정 링크 `/opt/weather-care/weather_care_test_server`가 가리킨다. 하위 호환 변경
8개 소스와 `0018_lightning_client_support.sql`만 기존 시험 릴리스에 추가했다.
로컬 최신 준비물 근거 기능 등 다른 미배포 변경은 포함하지 않았다.

- API 서비스: `weather-care-test-api.service`
- 시험 DB: `/var/lib/weather-care/weather-care-test.sqlite`
- 시험 환경 파일: `/etc/weather-care/weather-care-test.env` (저장소 밖, 0640)
- 날씨 캐시 동기화: `weather-care-test-cache-sync.timer`, 5분 간격
- 자외선·생활지수·기상특보·적설·일최대풍속 보완 수집: `weather-care-test-weather-refresh.timer`, 30분 간격
- 자외선 실측: `weather-care-test-uv.timer`, 10분 간격(정각 슬롯의 30초 뒤)
- 낙뢰 수집·감지 알림: `weather-care-test-lightning.timer`, 매시 05·15·25·35·45·55분
- 시험 수집기: `weather-care-test-missing.service`를 필요할 때 한 번 실행한다.

시험 DB 초기 복제 시 `prepare_test_db.py`가 SQLite 온라인 백업으로 운영 DB를 복사한다.
복사본의 설치 ID, 인증 정보, 알림 설정·이력은 기존 시험 DB 값으로 교체한다.
복제 중간 파일은 생성 시부터 소유자만 읽을 수 있다.
API 사용량은 운영과 시험의 기록 중 큰 값을 유지해 재배포로 호출 한도가
초기화되지 않게 한다. 운영 DB는 읽기 전용으로 연다. 이후 5분 타이머는
행정경계와 날씨 캐시 네 테이블만 운영 DB에서 동기화한다.
동기화된 대기질 관측은 날짜별로 시험 DB에 8일간 보관한다. 운영 DB의
현재 캐시에 남아 있는 관측부터 쌓으므로 이전 날짜의 대기질을 소급하지는 않는다.
기존 시험 DB에 기능을 추가할 때는 시험 DB 자체를 온라인 백업하고 대기 중인
마이그레이션만 적용한다. 2026-10-21 낙뢰 배포도 이 방식으로 시험 설치·설정·
기존 수집 자료를 유지했다. 운영 DB를 시험 DB 위에 덮어쓰지 않는다.
습도 일평균은 보관 중인 격자 관측으로 24시간이 모두 채워진 날만 계산한다.
일최대풍속은 시험 수집기가 KMA APIHub에 추가 조회한다. 최초 7일 범위는
한 번의 요청으로 받고, 이후 새 날짜마다 한 번 더 요청한다.
시험 보완 수집은 시험 DB에만 저장한다. 적설은 제공처에 최근 관측값이 없거나
요청이 실패하면 결측으로 유지한다.

자외선 실측은 `kma_sfctm_uv.php`의 전체 지점을 한 번에 받는다. 지점명·좌표는
`stn_inf.php?inf=UV`로 한국 날짜마다 한 번 갱신한다. 성공·실패 시도 슬롯을
SQLite에 저장해 프로세스 재실행과 중복 실행으로 호출이 늘지 않게 한다.
관측 요청에는 완료된 직전 10분 슬롯을 `tm`으로 명시한다. 이 값을 생략하면
제공처가 정시 자료를 반환하는 현상을 확인했다.
지점별 게시 시차로 새 응답에서 누락된 관측소는 직전 실제 관측을 최대 30분간
유지한다. Today는 사용자 좌표에서 가장 가까운 유효 관측소의 지수·시각·거리와
이름을 제공한다. 관측이 없으면 자료 없음으로 표시하며 예보로 채우지 않는다.
시간별·주간 자외선 예보는 기존 생활기상지수 자료를 사용한다.
정상 추가 호출은 관측 144회+지점정보 1회로 하루 145회이며 APIHub 공유 예산의
`UV_OBSERVATION`, `UV_STATIONS`에 합산한다.

운영 DB에 없는 `grid_extra_snapshots`는 기존 시험 DB 값을 유지한다.
누락 수집은 이미 저장된 제공처·대상·시간 슬롯을 건너뛰고, 없는 슬롯에만
외부 API를 호출한다. 일반 예보 알림과 바다·하천 정기 수집은 실행하지 않는다.
낙뢰만 별도 타이머로 최근 구간을 수집하고 실제 새 관측이 있는 시험 설치에 알린다.
서비스는 시험 DB 경로를 실행 전에 검사하며 전체/낙뢰 설정과 앱 지원 표시를 따른다.
`0016_lightning_alerts.sql` 적용 후 서비스·타이머를 등록한다. 낙뢰의 30분
표시 유효 시간과 조회 실패 표시는 `docs/격자_부가자료_수집_설정.md`를 참고한다.
이안류·ROMS·K-water 별도 수위 지점은 수집 설정이 없으면 요청하지 않는다.
해파리 목록은 기존 수집 코드의 한국 시간 6시간 간격 실행 조건을 따른다.

## 이동에 따른 알림 지역 갱신

2026-10-21 시험 DB에 `0017_background_location.sql`을 적용하고 다음 릴리스로 전환했다.

- 시험 릴리스: `/opt/weather-care/releases/20261021-test-background-location-0017/weather_care_server`
- 안정 링크: `/opt/weather-care/weather_care_test_server`
- 이전 릴리스: `/opt/weather-care/releases/20261021-test-lightning-3d11d03/weather_care_server`
- 백업: `/var/backups/weather-care/test-background-location-20261021`

기존 시험 DB를 온라인 백업한 뒤 시험 API와 시험 수집 타이머를 잠시 중지해 0017만
적용했다. 기존 설치·인증·알림 설정·발송 이력·활동 자료를 백업과 비교해 보존을
확인했고 API·타이머를 복구했다. 운영 릴리스와 운영 DB는 변경하지 않았다.

설치 소유자 인증과 시험 접근 키를 모두 사용한다. 앱에서 별도 동의한 GPS 모드·전체
알림·서버 사용 상태에서 `PUT /api/v1/installations/:id/background-location`으로 감시
세션을 등록한 뒤 `PUT /api/v1/installations/:id/location`으로 최신 위치를 반영한다.
토큰·개별 알림 설정은 보존하며 정밀 조건을 충족하지 않으면 지역 격자만 저장한다.
수동 지역·전체 알림 끄기·감시 해제·삭제는 이전 세션의 갱신을 차단한다.

공개 API의 서울↔부산 이동·지연/중복·중지 조건 12개, 배포된 알림 코드의 새 지역
선택·이전 지역 제외·중복 방지·전체 알림 끄기 8개, 실제 앱 Dart 서비스의 공개 서버
왕복 1개를 검증했다. 합성 설치와 임시 인증정보는 제거했다. 기기 GPS·권한 브리지는
모의 처리했으며 실기기 이동·OS 백그라운드·푸시 수신은 실행하지 않았다.
알림 대상 생성은 격리 DB와 모의 sender로 확인했고 기기로 실제 푸시는 보내지 않았다.

검증 기록은 [`docs/백그라운드_위치_시험배포_검증_20261021.json`](../../../docs/백그라운드_위치_시험배포_검증_20261021.json)에 있다.

```bash
sudo systemctl start weather-care-test-missing.service
journalctl -u weather-care-test-missing.service -n 100 --no-pager
```

시험 API는 `TEST_ACCESS_KEY`가 지정되면 모든 요청에
`X-Weather-Care-Test-Key`가 있어야 응답한다. 시험 앱의 빌드 설정은
`weather_care_app/config/kma.config.json`에 저장하며 Git에서 제외한다.
키는 시험 APK 안에 포함되므로 APK를 배포하거나 공유하면 키를 교체해야 한다.

```powershell
cd weather_care_app
D:\flutter_3.47.4\bin\flutter.bat run -d <기기 ID>
```

진단은 다음 명령으로 한다.

```bash
systemctl status weather-care-test-api.service weather-care-test-cache-sync.timer
systemctl status weather-care-test-cache-sync.service
journalctl -u weather-care-test-api.service -n 50 --no-pager
```

## 2026-10-22 구버전 앱 하위 호환 보완 시험 배포

- 시험 DB 온라인 백업 약 2.95GB를 `/var/backups/weather-care/test-legacy-compat-20261022/before.sqlite`에 보관했다. 시험 API·관련 타이머를 잠시 중지하고 0018만 적용했다. 기존 사용자 관련 12개 테이블의 기존 열 해시와 전체 테이블 행 수를 대조해 보존을 확인했고 DB 무결성·외래 키 검사도 통과했다.
- Main·Today의 `nextForecast`를 복원하고, 위젯의 지원 표시가 없으면 기존 준비물 카탈로그를 사용한다. 새 18종은 명시한 요청에만 제공한다. 구버전의 설정 저장만으로 낙뢰 지원 표시가 켜지지 않는다. 낙뢰 설정을 보낸 새 시험 앱은 지원 표시를 갱신하므로 기존 새 앱도 설정을 한 번 동기화해야 한다.
- 패치를 적용한 시험 소스 사본에서 Node 46개와 타입 검사, 서버 Linux 모듈 로딩을 통과했다. 공개 시험 API 검사 28회 및 구버전 두 버전의 실제 HTTP 24회로 서울·시흥·부산을 확인했다. 구버전 HTTP·날씨·앱 생성 위젯 6개와 과거 Main 카드 렌더 6개가 모두 통과했다. 구버전 HTTP 코드에는 시험 접근 키 헤더만 주입했으며 요청 계약과 응답 파싱 코드는 그대로 사용했다.
- 합성 설치로 두 설정 저장 경로·설치 인증·낙뢰 지원 표시를 확인한 뒤 관련 데이터를 삭제했다. 배포된 낙뢰 모듈도 격리 메모리 DB와 모의 sender로 구버전 차단·지원 앱 대상·중복 방지를 확인했다. 실제 FCM은 호출하지 않았다. APK/IPA 설치와 운영체제 네이티브 위젯 실행은 하지 않았다.
- 운영 릴리스 `20261012-juso-202609`, 전체 소스·환경 파일·API/스케줄러/터널 프로세스와 마이그레이션 0014는 그대로다. 시험 API와 기존 타이머 4개는 active로 복구했다. 운영 배포·커밋·push는 하지 않았다.
- 배포·복구 자료는 `/tmp/weather-care-compat-deploy-20261022`, 검증 도구·공개 응답·로그는 앱의 Git 제외 `build/compat-test-deploy-20261022`에 있다. [검증 기록](../../../docs/하위호환_시험배포_검증_20261022.json)을 참고한다. 이전 시험 릴리스도 복구용으로 보존한다.

## 2026-10-21 Data 관측소 이름·오늘 자료

- 최종 시험 릴리스: `/opt/weather-care/releases/20261021-test-data-today-ready/weather_care_server`. 작업 전 릴리스는 `20261021-test-lightning-radius`이고 안정 링크는 기존 경로를 유지한다.
- 하천 관측소 제원과 K-water 관측소 코드/이름을 일별 스냅샷으로 저장하고 Data 카탈로그에서 코드에 연결한다. 이름이 없는 경우 코드를 유지한다. 오늘 수치 유무를 기본 지점 선택에 사용한다.
- 오늘 바다·하천 자료는 단발 수집했으며 정기 수집 설정은 변경하지 않았다. 백업·수집 원장·집계는 `/tmp/weather-care-data-today-20261021`에 있다. DB 마이그레이션이나 운영 서버 변경은 없다.

## 2026-10-21 기상특보 해제예고 시간대 해석 복구

- 현재 시험 릴리스: `/opt/weather-care/releases/20261021-test-warning-release-period/weather_care_server`. 이전 릴리스는 `20261021-test-data-today-ready`이며 안정 링크는 기존 경로를 유지한다.
- 기상청 `ED_TM` 열의 `21일 밤(21시~24시)`·`22일 새벽(03시~06시)` 형식을 지원한다. 실제 응답의 시간대 표현을 읽되 기존 발표·발효·특보수준·해제 판정과 알 수 없는 필드 오류 처리는 유지한다. 배포 파일은 `src/providers/warnings/kmaWarningProvider.ts` 하나이다.
- 한국시간 11:53:41에 특보 수집을 한 번 실행해 지역 매핑 711개·육상 특보 39건을 저장했다. 공개 시험 Today에서 구로 표본의 확인 불가 안내 해소와 시흥 표본의 강풍주의보 반환, 시험 health HTTP200을 확인했다.
- 시험 DB 온라인 백업·진단 원문·배포 매니페스트·단발 실행 스크립트는 `/tmp/weather-care-warning-fix-20261021`에 있다. 특보 정기 수집은 기존 30분 주기를 유지하며 운영 소스·DB·서비스 설정과 알림 발송은 변경하지 않았다.

## 2026-10-21 하천 필드·기간 이력 시험 반영

- 안정 릴리스는 `/opt/weather-care/releases/20261021-test-river-fields-history/weather_care_server`이다. 직전 릴리스는 `20261021-test-warning-release-period`이며 기상특보 수정은 유지한다.
- K-water의 hourwal=수위, flux=유량을 반영하고 시험 저장 자료 4,600행을 교정했다. 백업·원복 스크립트·출처 비교·감사 결과는 `/tmp/weather-care-river-fields-20261021`에 있다.
- 오늘 하천 934곳에 시간별 이력을 단발 수집했다. API가 관측소별 이력과 전국 최신 관측을 합친다. 운영 서버·정기 수집 타이머·알림 설정은 변경하지 않았다.

## 2026-10-21 하천 통합·검색 시험 반영

- 현재 안정 릴리스는 `/opt/weather-care/releases/20261021-test-river-merged-search-time/weather_care_server`이다. 이전 완성 릴리스는 `20261021-test-river-fields-history`이며 기상특보 등 다른 작업의 변경을 유지한다.
- 배포 파일은 `src/api/gridExtra.ts`, `src/collection/riverStationLinks.ts`이다. 관측소 제원과 K-water 추가 항목을 통합하고 검증한 서로 다른 코드도 연결한다. 기관별 시간 표기를 한국 표준시로 정규화해 같은 시각의 자료가 중복되지 않게 한다.
- 원격 비교·배포 자료는 `/tmp/weather-care-river-merge-20261021`에 있다. 스키마·관측 스냅샷·운영 서버·정기 수집 설정은 변경하지 않았다. 시험 API만 재시작했다. 앱에서 K-water 별도 칩을 제거하며 기존 K-water API는 유지한다.

## 2026-10-21 Data 관측소 거리 반영

- 현재 안정 릴리스는 `/opt/weather-care/releases/20261021-test-data-station-distance-v2/weather_care_server`이다. 직전 완성 릴리스는 `20261021-test-river-merged-search-time`이며 기존 기상특보·하천 통합 등의 변경을 유지한다.
- 변경 배포는 API·수집기와 새 좌표 정규화/기준 위치 모듈 네 파일이다. 시험 HRFCO 제원 1건의 payload에 유효 좌표 1,400개를 보완했다. DB 스키마·관측값·수집 주기·운영 서버는 변경하지 않았다.
- 원격 `/tmp/weather-care-data-stations-20261021`에 온라인 백업, 변경 전 제원, 배포 해시, 제원 보완·원복 스크립트가 있다. 첫 적용은 좌표 개수 검증 조건에서 중단돼 원복했고, 원본의 유효 좌표가 정확히 1,400개임을 확인해 재적용했다. 운영 API·운영 스케줄러는 유지하며 시험 API만 재시작했다.

### 2026-10-21 누락 관측소 위치 후속 보완

- 1차 보완 릴리스: `/opt/weather-care/releases/20261021-test-station-coordinate-backfill/weather_care_server`. 직전 `20261021-test-data-station-distance-v2`를 복제하고 API와 좌표 보완표 2개만 이전·이후 SHA256 대조 후 배포했다. 시험 API만 재시작하며 DB·정기 수집·운영 서버는 변경하지 않았다.
- 공식 2026 홍수통제소 CSV의 코드·이름 일치 10곳과 OneClick 코드 확인 2곳, 낙동강하굿둑 시설 위치 1곳, BUOY 예측 코드 연결 3곳을 추가했다. 하천 1,479/1,551개, 댐 59/59개, 해역 예측 27/27개에 거리 제공. 하천 미확인 72곳과 잘못된 제주 공통 좌표 제외 근거는 `docs/관측소_좌표_보완_검증_20261021.json`에 있다.
- API/수집/좌표 검사 27개와 타입 검사 통과. 실제 시험 API에서 16개 추가 위치·미확인 72개 유지, 보완 하천 2곳·댐 1곳·해역 1곳의 지점 좌표 요청 시 거리 0을 확인했다. 원격 배포 기록·원복 기준은 `/tmp/weather-care-coordinate-backfill-20261021`, 로컬 공개 응답 검증은 `weather_care_app/build/coordinate-backfill-20261021/verification.json`이다. 앱 수정·재설치·사용자 위치 변경은 없다.

### 2026-10-21 WAMIS 재조회·연보 추가 검증

- 재조회 릴리스: `/opt/weather-care/releases/20261021-test-station-coordinate-retry/weather_care_server`. 1차 보완 릴리스를 복제하고 좌표 보완표 1파일만 해시 검사 후 배포했다. DB·정기 수집·운영 서버를 변경하지 않았다. 원격 기록은 `/tmp/weather-care-coordinate-retry-20261021`에 있다.
- WAMIS 30곳 모두 응답 확보(5곳 등록 제원 공란·25곳 해당 코드 자료 없음), 새 유효 좌표 없음. 2021 XLS·2025 연보의 이름/주소/명칭 변경과 관측 시계열을 추가 대조해 상사4교·청도 당호리/임당리·주암조절지 방수로·덕치 5곳을 보완했다. 위치만 연결하고 관측소 코드는 보존한다.
- 실제 시험 API에서 기존 1,551개 코드·이름·연결 코드·기존 좌표 유지와 하천 1,484곳 위치 제공·미확인67곳을 확인했다. 추가5곳 모두 해당 위치 요청 시 거리0이다. API/수집/좌표28개·타입 검사 통과. 근거·최신 미확인 목록은 `docs/관측소_좌표_재조회_검증_20261021.json`, 로컬 공개 검증은 `weather_care_app/build/coordinate-retry-20261021/verification.json`이다.

### 2026-10-21 남은 67곳 공식 주소·설치 자료 대조

- 설치 자료 보완 릴리스: `/opt/weather-care/releases/20261021-test-station-installations/weather_care_server`. 직전 재조회 릴리스를 복제하고 좌표표 1파일만 전후 SHA256 검사 후 반영했다. 시험 API만 재시작했으며 시험/운영 API·운영 스케줄러 active를 확인했다. 원격 기록·원복 기준은 `/tmp/weather-care-station-installations-20261021`에 있다.
- 두평9000242와 주암조절지댐방수로8000020를 공식 관측소명·주소·관리기관·관리댐/유역으로 대조해 위치만 추가했다. 현재 HRFCO 수위관측소 제원3007606/4104625의 좌표를 사용한다. 원 코드별 센서 이력과 측정값 동일성은 확정하지 않으므로 코드·자료 이력은 합치지 않는다.
- 실제 공개 시험 API3회 조회로 기존1,551개 식별·연결 코드·기존 좌표 유지, 위치1,486개·미확인65개, 신규2곳의 지점 좌표 요청 시 거리0을 확인했다. API/수집/좌표28개 및 타입 검사 통과. 같은 위치의 별도 코드도 각각 남는다. 서버 좌표표 변경이므로 APK 빌드·설치는 없다.
- 공식 자료 PDF5개와 현재/기존 제원을 대조했다. 2011 보고서를 업로드 연도2022 자료로 오인하지 않으며 두평 개시일 오기는 주소·좌표 근거와 분리했다. 주천교/동정교는 문서 간 위치 차이, 보 하류·보조수위·감지·갑문 등은 센서 설치 대응 부족으로 추정 대입하지 않았다. 최신 근거·미확인65곳은 `docs/관측소_설치자료_위치검증_20261021.json`, 공개 검증은 `weather_care_app/build/station-installations-20261021/verification.json`에 있다.

### 2026-10-21 미확인 65곳 공식 GIS 후속 대조

- 현재 시험 릴리스: `/opt/weather-care/releases/20261021-test-station-official-gis/weather_care_server`. 직전 설치 자료 릴리스를 복제하고 좌표표 1파일만 전후 SHA256 검사 후 교체했다. 원격 배포·원복 기준은 `/tmp/weather-care-station-official-deploy-20261021`, 읽기 전용 수위 대조는 `/tmp/weather-care-station-official-20261021`에 있다. 시험 API만 재시작했고 시험/운영 API·운영 스케줄러 active이다.
- 공식 GIS 수위627개·20260410 수위1,076개·DIIS356개·상세 제원1,724개 대조 후12곳을 보완했다. 원 코드 위치9곳, 원 코드의 현재 명칭이 확인된 구포/삼랑진/진동3곳이다. DIIS 구좌표는 서버의 명시적 EPSG:4326 반환 geometry를 쓴다. 원코드의 다른 시설명(대아저수지/굴포·경천저수지/시화호) 충돌은 제외한다. 일부 과거 제원의 폐국 표시는 현재 운영/자료 제공 여부와 구분해 기록한다.
- 공개 시험 API13회로 전체1,551개 코드·명칭·연결 코드·기존 좌표 유지, 위치1,498곳·미확인53곳, 신규12곳 각각 해당 좌표 요청 시 거리0을 확인했다. API/수집/좌표28개·타입 검사 통과. DB·수집·운영 배포·앱 빌드/설치는 변경하지 않았다.
- 최신 출처·주소·좌표계·명칭 이력·미확인53곳은 `docs/관측소_공식GIS_위치검증_20261021.json`, 로컬 공개 검증은 `weather_care_app/build/station-official-20261021/verification.json`에 있다. 앞선65곳 기록은 당시 조사 이력으로 보존한다.
