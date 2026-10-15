# 시험 서버 운영

시험 API는 미니 PC의 `127.0.0.1:8788`에서 실행되고, Cloudflare Tunnel의
`weather-test-api.codesoha.com`으로 연결한다. 운영 API `8787`과 DB는 변경하지 않는다.

- API 서비스: `weather-care-test-api.service`
- 시험 DB: `/var/lib/weather-care/weather-care-test.sqlite`
- 시험 환경 파일: `/etc/weather-care/weather-care-test.env` (저장소 밖, 0640)
- 날씨 캐시 동기화: `weather-care-test-cache-sync.timer`, 5분 간격
- 시험 수집기: `weather-care-test-missing.service`를 필요할 때 한 번 실행한다.

배포 시 `prepare_test_db.py`가 SQLite 온라인 백업으로 운영 DB를 복사한다.
복사본의 설치 ID, 인증 정보, 알림 설정·이력은 기존 시험 DB 값으로 교체한다.
API 사용량은 운영과 시험의 기록 중 큰 값을 유지해 재배포로 호출 한도가
초기화되지 않게 한다. 운영 DB는 읽기 전용으로 연다. 이후 5분 타이머는
행정경계와 날씨 캐시 네 테이블만 운영 DB에서 동기화한다.

운영 DB에 없는 `grid_extra_snapshots`는 기존 시험 DB 값을 유지한다.
누락 수집은 이미 저장된 제공처·대상·시간 슬롯을 건너뛰고, 없는 슬롯에만
외부 API를 호출한다. 시험 정기 수집기와 시험 알림 전송 작업은 실행하지 않는다.

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
