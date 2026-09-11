# Analytics 동의 철회·삭제 점검

점검일: 2026-09-11. 코드 및 기존 테스트 확인 결과이며 실기 네트워크 검증 완료를 의미하지 않는다.

## 확인 결과

| 항목 | 현재 구현 |
| --- | --- |
| 최초 미동의 | SharedPreferences 기본 false, Android/iOS 수집 기본값 false |
| 명시적 동의 | 확인창 승인 → 동의 저장 → SDK 수집 허용 |
| 정상 철회 | SDK 수집 중단 → false 저장 → 거부 동의 적용 |
| 광고 관련 동의 | SDK 적용 시 광고 저장·사용자 데이터·개인화 동의 false |
| 철회 저장 실패 | 현재 실행에서는 수집 중단을 재시도하고 오류 표시 |
| 실패 후 재시작 | 이전 true 값이 남으면 initialize가 다시 수집을 허용할 수 있음. 보완 필요 |
| 이미 Google에 전송한 데이터 삭제 | 삭제 API 연동 없음 |
| 서버 내 나의 데이터 삭제 | 앱 서버 설치 데이터 DELETE만 실행. Google Analytics 삭제와 별개 |
| 로컬 Analytics 초기화 | resetAnalyticsData 호출 없음. 추가하더라도 원격 삭제와 동일시 금지 |

확인 코드: `weather_care_app/lib/services/analytics_consent.dart`, `features/settings/analytics_consent_control.dart`, `services/server_data_access.dart`, `main.dart`, Android Manifest, iOS Info.plist.

기존 `flutter test test/analytics_consent_test.dart` 4개 통과. 주입된 apply 콜백을 검증하는 테스트이므로 실제 Firebase 전송 중단을 입증하지 않는다. 저장 실패 후 새 컨트롤러 생성/앱 재시작, SDK 초기화 이전·백그라운드 전송은 별도 검증이 필요하다.

## 다음 보완 순서

1. 철회 의사를 저장하는 과정의 실패/재시작 안전성 보완. 기존 true 동의가 자동 복구되지 않는 지속 상태와 시작 경계를 설계하고 재시작 회귀 테스트를 추가한다. 모든 저장 장치 실패를 단일 로컬 bool로 해결했다고 주장하지 않는다.
2. Analytics 삭제 요청 대상 식별·요청 권한·실패 재시도·보관 범위를 설계한다. Google은 Firebase app_instance_id 기반 사용자 삭제 요청을 지원하지만 현재 앱 서버 설치 ID와 다른 값이다. 임의 ID를 받아 다른 사람의 데이터를 삭제하지 않도록 권한 검증이 필요하다.
3. 원격 삭제 요청에 필요한 식별정보를 안전하게 확보하기 전에 SDK 초기화로 ID를 없애지 않는다. 이미 철회한 기기의 ID 조회 가능 여부와 구버전 데이터 처리 범위도 실제 SDK에서 검증한다. 삭제를 위해 수집을 다시 켜지 않는다.
4. Google 삭제 API 인증정보는 서버에만 두며 최소 권한으로 구성한다. 요청 접수와 실제 삭제 완료를 구분하고 완료가 확인되지 않은 상태에서 삭제 완료 문구를 출력하지 않는다.
5. Android/iOS 실기에서 미동의·동의·철회·재시작·오류 상태의 네트워크 확인 후 앱 문구와 개인정보처리방침을 최종화한다.

이번 작업은 점검만 수행했다. 앱 동작 변경·삭제 요청·운영 배포는 하지 않았다. 보호자 동의 구현 보류도 유지한다.

공식 참고: [Google Analytics 사용자 삭제 요청](https://developers.google.com/analytics/devguides/config/admin/v1/rpc/google.analytics.admin.v1alpha#google.analytics.admin.v1alpha.SubmitUserDeletionRequest), [Firebase 로컬 데이터 초기화 안내](https://firebase.google.com/support/release-notes/unity).
