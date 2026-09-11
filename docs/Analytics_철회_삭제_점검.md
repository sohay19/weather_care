# Analytics 동의 철회·삭제 점검

점검일: 2026-09-11. 코드 및 기존 테스트 확인 결과이며 실기 네트워크 검증 완료를 의미하지 않는다.

## 후속 수정: 철회 실패·재시작 방어

2026-09-11 사용자 구현 승인 후 `AnalyticsConsentStore` 추가. 아래 최초 점검 표는 수정 전 기록이다.

- 일반 설정과 보안 저장소의 동의값이 모두 허용일 때만 Dart 초기화가 수집을 다시 허용한다. 보안 저장소 값이 없는 기존 버전은 자동 승계하지 않고 명시적 재동의를 받는다.
- 철회 시 SDK 중단 실패와 무관하게 두 저장소에 거부값 기록을 시도한다. 한 저장소가 실패해도 다른 저장소 기록을 생략하지 않는다. 실패는 오류로 알리고 중단/거부 저장을 재시도한다.
- 허용은 기존 동의 무효화 후 두 저장소에 기록하고 SDK에 적용한다. 허용 과정 실패 시 거부 상태로 되돌리는 작업을 시도한다.
- 앱의 Dart 초기화는 저장값을 읽기 전에 SDK 중단을 먼저 호출한다. 정상/저장소별 실패/SDK 중단 실패/기존 버전/읽기 오류/허용 중간 실패/전체 저장 실패 후 재시도 등 관련 테스트 총11개 통과.
- 한계: 모든 영구 저장이 실패하면 이전 허용값을 디스크에서 제거했다고 보장할 수 없다. Firebase 네이티브 자동 시작은 Dart보다 앞서므로 프로세스 초기·백그라운드 네트워크 무전송까지 검증된 것은 아니다. Android/iOS 실기 검증이 남아 있다.
- Google 원격 Analytics 삭제는 이번 수정에 포함하지 않는다. 배포/기기 설치 없음.

## 후속 Android 에뮬레이터 실행 검증

2026-09-11 수정본 debug APK 빌드 성공. Android17/API37 emulator-5554에서 실행 확인. 실제 휴대전화와 iOS 기기는 연결되지 않았다.

- 최초 `install -r`은 설치된 versionCode2026085100보다 빌드2026081100이 낮아 거절됨. 그 직후 기존 앱 실행은 검증 결과에서 제외했다.
- `install -r -d`로 데이터 유지 디버그 다운그레이드 설치 성공. uninstall/pm clear는 실행하지 않았다. 운영/스토어 배포 없음.
- 설치 후 콜드 스타트 성공, 홈 이동 후 앱 복귀 성공, force-stop 후 두 번째 콜드 스타트 성공.
- 첫 콜드 스타트 FA 로그: `App measurement disabled via the manifest`, `Analytics storage consent denied; will not get app instance id`.
- 두 번째 콜드 스타트 FA 로그: `App measurement disabled by setAnalyticsCollectionEnabled(false)`, 동일한 analytics storage 거부 메시지.
- 이 결과는 현재 미동의 상태의 SDK 로그 확인이다. 패킷 캡처를 통한 전송 부재, 기존 허용 상태에서의 업그레이드, 실제 동의→철회 UI, 저장장치 오류 주입, FCM 수신에 의한 백그라운드 시작을 검증한 것은 아니다. 홈 이동은 FCM 백그라운드 테스트를 대신하지 않는다.
- 기기 저장소 조회에서 대상 동의 항목을 추출하지 못했으므로 해당 결과를 설정 증거로 사용하지 않았다. 전체 저장내용/토큰/식별자를 출력하지 않았다.

다음 우선순위: 별도 테스트 환경에서 동의→철회→재시작 및 FCM 백그라운드 경계 검증. 실기 네트워크 검증 전 무전송 보장을 선언하지 않는다. Google 원격 삭제 연동은 별도 미구현이다.

## 후속 Android 오프라인 동의·철회 UI 검증

2026-09-11 emulator-5554에서 현재 설치된 수정본 대상으로 실행.

1. 원래 airplane_mode=0, wifi_on=1 확인 후 비행기 모드ON·Wi-Fi OFF. 네트워크 전환이 완료돼 `Active default network: none`인 상태에서만 동의 시험 시작.
2. 앱 설정의 ‘앱 이용 통계 수집 (선택)’ checked=false 확인.
3. 스위치 선택 시 동의창 표시 확인. ‘동의’를 눌러 checked=true 확인.
4. 스위치를 다시 눌러 철회 후 checked=false 확인.
5. force-stop 후 COLD 시작 성공. 오프라인으로 표시된 서버 연결 오류 안내에서 ‘단기예보만 보기’를 선택하여 닫고 설정으로 이동. checked=false 유지 확인.

ADB UI 계층의 실제 버튼 영역으로 조작했고 위치·알림 스위치 및 서버 데이터 삭제는 조작하지 않았다. 이 실행에서는 FA 로그 필터 결과가 비어 SDK 로그 증거로 추가하지 않았다. 단순 UI 확인을 Google 전송·삭제 완료로 해석하지 않는다.

**인계 시 에뮬레이터는 비행기 모드ON·Wi-Fi OFF로 남겨둔다.** 오프라인 동의 과정의 대기 이벤트 유무를 확인하지 못했으므로 시험 통계의 후속 전송을 피하기 위한 조치다. 원래 네트워크로 복원하기 전에 대기 데이터 처리 계획을 검토한다. 앱 데이터 전체 삭제로 해결하지 않는다. 실제 휴대전화·iOS·FCM 백그라운드·패킷 검증·Google 삭제 API는 미완료다.

## 후속 대기열 확인·네트워크 복원

2026-09-11 위 오프라인 인계 상태를 해제했다. 앱을 force-stop한 뒤 앱 전용 `databases/google_app_measurement_local.db`를 ADB로 메모리에만 읽어 Python SQLite의 query_only 상태에서 검사했다. 호스트에 DB 사본을 저장하지 않았으며 이벤트 내용·식별자·토큰을 출력하지 않았다.

- DB integrity_check=ok, messages 행 수=0, rollback journal=0바이트.
- SDK 저장값 measurement_enabled=false, measurement_enabled_from_api=false 및 앱 analytics_consent_v1=false 확인.
- 대기열이 비어 있어 삭제/초기화 작업은 하지 않았다. 앱을 종료한 상태로 airplane_mode=0·wifi_on=1 복원.
- 이는 앱의 로컬 대기열/설정 검사다. Google Play 서비스 내부 큐·원격 Google 데이터·네트워크 전체 무전송을 검증하거나 보장하지 않는다. 로컬0건을 원격 삭제 완료로 표현하지 않는다.

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
