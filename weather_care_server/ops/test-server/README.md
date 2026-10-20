# 시험 서버 운영

시험 API는 미니 PC의 `127.0.0.1:8788`에서 실행되고, Cloudflare Tunnel의
`weather-test-api.codesoha.com`으로 연결한다. 운영 API `8787`과 DB는 변경하지 않는다.

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
서비스는 시험 DB 경로를 실행 전에 검사하며 전체/낙뢰 설정을 따른다.
`0016_lightning_alerts.sql` 적용 후 서비스·타이머를 등록한다. 낙뢰의 30분
표시 유효 시간과 조회 실패 표시는 `docs/격자_부가자료_수집_설정.md`를 참고한다.
이안류·ROMS·K-water 별도 수위 지점은 수집 설정이 없으면 요청하지 않는다.
해파리 목록은 기존 수집 코드의 한국 시간 6시간 간격 실행 조건을 따른다.

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
