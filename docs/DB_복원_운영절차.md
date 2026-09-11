# DB 복원 운영절차

2026-09-11 확정. 이 문서는 장애 시 수동 절차이며 배포 시 자동 실행하지 않는다.

## 확정 정책

- 복원된 과거 사용자 등록·인증·위치·토큰·설정·발송 이력을 재사용하지 않는다.
- 가능한 경우 DB 전체 복원 대신 공용 기상자료를 다시 수집한다.
- 전체 복원이 불가피하면 API와 알림 작업을 중단하고 개인 데이터를 제거·검증한 뒤 재개한다. 삭제하지 않은 사용자도 재등록이 필요할 수 있다.
- 앱은 등록 소실을 확인하면 자동 등록을 멈춘다. 사용자가 `서버 기능 다시 사용`을 선택해야 하며 알림은 OFF부터 시작한다. 기기에 남은 데이터는 별개다.

## 1. 사고별 승인과 서비스 격리

운영자가 대상 계정·DB ID·복원 시점·전체 사용자 재등록 영향을 확인하고 별도 승인을 받는다. 이 정책 승인은 실제 운영 DB 삭제·복원 실행 승인이 아니다.

서버 디렉터리에서 `npx wrangler secret put RECOVERY_MODE`를 실행하고 값 `on`을 입력한다. 이 값은 D1 밖에 보관하므로 과거 DB 복원으로 해제되지 않는다. 미설정 또는 정확히 `off`만 정상 모드이며 다른 값은 차단된다. 복구 중 이 secret을 삭제하지 않는다.

배포가 100% 적용됐는지 확인한다. `/health`와 API가 `503 SERVICE_RECOVERY`, `Cache-Control: no-store`를 반환하는지 확인한다. 복구 모드의 cron은 정리·조회·발송을 시작하지 않는다. 다른 Worker나 도구가 DB에 쓰는 경로도 모두 중단한다.

**이미 실행 중인 요청에는 새 설정이 소급 적용되지 않는다.** 마지막 정상 cron 실행 이후 최소 15분을 고려하되, 시간 경과만으로 전체 중단을 증명하지 않는다. HTTP 요청은 연결 중 실행시간 상한이 없으므로 실행 상태 등으로 기존 쓰기·발송 요청 종료를 확인해야 한다. 확인할 수 없으면 복원을 진행하지 않고 격리를 유지한다. 사용자 원문 로그나 토큰을 수집해 확인하지 않는다. 이미 FCM에 전달한 알림은 회수할 수 없다.

## 2. 복원과 스키마 검토

종료 확인 후에만 승인된 정확한 대상·시점으로 복원한다. 이 문서에는 오실행 방지를 위해 실제 복원 명령을 넣지 않는다. Time Travel은 기존 DB를 덮어쓰며 과거 복원 지점을 삭제하지 않는다.

복원 후에도 차단을 유지한다. 현재 검토된 마이그레이션과 스키마를 적용·대조한다. 알 수 없는 테이블이나 누락된 테이블이 있으면 중단하고 분류·정리 스크립트를 먼저 수정한다. 현재 검증 스크립트가 기대하는 개인·파생 테이블은 아래 9개다.

`installations`, `notification_settings`, `notification_history`, `installation_warning_state`, `installation_credentials`, `installation_activity`, `installation_ownership_challenges`, `legacy_installation_ownership`, `active_regions`.

`weather_cache`, `daily_weather_snapshots`는 공용 자료만 담는다는 것을 확인한 경우에만 유지한다. 출처나 내용 분류가 불분명하면 그대로 재사용하지 말고 별도 검토 후 재수집한다. 시스템 테이블 허용 목록은 모든 미래 시스템 테이블을 포괄하지 않는다.

## 3. 개인 데이터 정리와 검증

다음 명령은 **승인된 사고 대응 시에만** 서버 디렉터리에서 실행한다. 계정·설정의 DB ID가 승인 대상과 일치하는지 먼저 확인한다.

```powershell
npx wrangler d1 execute weather_care_db --remote --file ops/recovery-reset.sql
npx wrangler d1 execute weather_care_db --remote --file ops/recovery-verify.sql
```

정리는 생성 시점과 무관하게 9개 테이블을 비운다. 파일 전체의 원자성을 가정하지 않으며 오류가 하나라도 발생하면 차단을 유지한다. 재실행할 수 있으나 성공 안내만으로 완료 처리하지 않는다.

검증 통과 조건: 9개 `remaining` 값이 전부 0, `unreviewed_table` 결과 없음, `foreign_key_check` 결과 없음. 부분 출력이나 명령 실패를 0으로 해석하지 않는다. 기존 쓰기 작업이 종료됐는지 재확인하고 재개 직전 검증을 반복한다. 원본 사용자 행은 출력하지 않는다.

## 4. 재개

현재 보안 수정이 포함된 서버 버전을 유지한다. 과거 코드로 되돌리지 않는다. 모든 검증 통과 후에만 `npx wrangler secret put RECOVERY_MODE`로 `off`를 입력한다. `/health` 200과 정상 API를 확인한다.

사용자 등록은 앱의 명시적인 재사용 경로로 시작한다. 앱은 알림 OFF를 기기에 저장한 후 등록을 재개한다. 서버는 알림 설정이 없는 설치에 발송하지 않는다. 새 앱의 로컬 저장 실패 시 등록을 재개하지 않는다.

복원 전 사본·Time Travel 기록 자체가 이 정리로 사라지는 것은 아니다. 다시 복원할 때도 같은 절차가 필요하다. 이 장치는 수동 운영 절차를 대체하는 자동 복원 보장이 아니다.

## 근거와 검증 범위

- [D1 Time Travel](https://developers.cloudflare.com/d1/reference/time-travel/): 제자리 복원 및 복원 기록 동작.
- [Workers 실행 제한](https://developers.cloudflare.com/workers/platform/limits/): cron 실행시간과 HTTP 연결 중 실행시간 구분.
- 로컬 합성 DB로 정리 반복 실행·개인정보 0건·공용 자료 유지·미검토 테이블 탐지 검증. 복구 모드 API/cron 차단 테스트 포함.
- 이번 구현에서는 운영 복원·삭제·복구 모드 활성화·장애 훈련을 수행하지 않는다. 실제 무중단 종료 증명과 사고 대응 실행은 별도다.
