# Analytics 동의 철회·삭제 점검

점검일: 2026-09-11. 코드 및 기존 테스트 확인 결과이며 실기 네트워크 검증 완료를 의미하지 않는다.

## 후속 구현: Google Analytics 사용자 삭제 요청

2026-09-11 앱과 Worker에 Firebase `app_instance_id` 기반 삭제 요청 흐름을 구현하고 운영 Worker까지 연결했다. 실제 테스트 앱 인스턴스의 삭제 요청은 제출하지 않았으므로 Google 접수까지 완료됐다는 뜻은 아니다.

- 이용 통계에 동의한 동안 앱 인스턴스 ID를 기기 보안 저장소에만 보관한다. 일반 철회 때도 식별자 확보를 시도하지만 그 완료를 기다리지 않고 수집부터 중단하며, 확보 실패가 수집 중단을 막지 않게 했다.
- 별도 ‘전송된 이용 통계 삭제 요청’에서 수집을 먼저 중단하고 설치별 서버 인증을 거쳐 Worker에 식별자를 전송한다. 앱 서버 설치 ID와 Firebase 앱 인스턴스 ID를 동일한 값으로 취급하지 않는다.
- Worker는 삭제 전용 서비스 계정으로 `analytics.edit` 범위의 토큰을 발급받아 Analytics Admin API `properties.submitUserDeletion`에 `appInstanceId`만 전송한다. 비공개키는 Wrangler secret으로만 받는다.
- Google이 요청을 접수한 뒤에만 Firebase `resetAnalyticsData()`로 기기의 분석 데이터와 앱 인스턴스 ID를 초기화한다. 접수 상태를 먼저 보안 저장소에 기록해 앱이 중단된 경우 원격 요청을 불필요하게 반복하지 않는다.
- 원격 요청 실패 시 수집은 중단된 상태로 유지하고 식별자를 남겨 재시도한다. Google 요청 접수 후 로컬 초기화가 실패하면 두 상태를 구분해 안내한다. UI는 실제 삭제 완료가 아니라 ‘요청 접수’로만 표현한다.
- Worker 클라이언트·인증 라우트와 앱 저장소·중단·재시도·UI 흐름 테스트를 추가했다. 운영 자격증명의 OAuth 토큰 발급과 속성 읽기까지 확인했지만, 실제 Android/iOS 기기에서 삭제 요청을 제출하는 종단 검증은 남아 있다.

운영 연결 순서:

1. Google Cloud 프로젝트에서 Google Analytics Admin API를 활성화한다.
2. 삭제 전용 서비스 계정을 만들고 별도의 Cloud IAM 역할은 부여하지 않는다.
3. Google Analytics 속성 `549443110`의 속성 액세스 관리에 서비스 계정 이메일을 추가하고 편집자 역할을 부여한다. 계정 전체가 아니라 이 속성에만 부여한다.
4. Worker secret `GA_ADMIN_CLIENT_EMAIL`, `GA_ADMIN_PRIVATE_KEY`를 등록하고 배포한다. 키 원문은 저장소·명령 기록·문서에 넣지 않는다.
5. 테스트 전용 앱 인스턴스로 실제 요청을 한 번 제출해 HTTP 접수시각, 앱 수집 중단, 로컬 ID 초기화와 재시도 문구를 확인한다. 공식 한도는 속성당 하루 500건이므로 자동 반복 시험을 하지 않는다.

운영 연결 결과:

- Google Cloud 프로젝트 `weather-care-2aaa8`에서 Google Analytics Admin API를 활성화했다.
- 삭제 전용 서비스 계정 `analytics-deletion@weather-care-2aaa8.iam.gserviceaccount.com`을 만들고 Analytics 속성 `549443110`에만 편집자 권한을 부여했다. Google Cloud 프로젝트 IAM 역할과 Analytics 계정 수준 권한은 부여하지 않았다.
- 운영 키의 이메일과 비공개키를 Cloudflare Worker secret `GA_ADMIN_CLIENT_EMAIL`, `GA_ADMIN_PRIVATE_KEY`로 등록했다. 키 원문은 저장소·문서·명령행 인자에 기록하지 않았다.
- 운영 자격증명으로 `analytics.edit` OAuth 토큰 발급과 Analytics Admin API 속성 읽기가 각각 HTTP 200으로 성공했다.
- 서버 전체 테스트 35개 파일 259개, TypeScript 검사와 Wrangler dry-run을 통과한 뒤 Worker 버전 `efd6c82f-ed3a-4696-95f5-0c0ae0119c14`를 배포했다. `/health`는 200, 올바른 형식의 미인증 삭제 요청은 401을 반환했다.
- 다운로드한 운영 키 JSON의 계정과 키 ID를 확인한 뒤 로컬 파일을 삭제했다. 다운로드 재시도로 생성됐지만 사용하지 않은 키 2개도 Google Cloud에서 삭제했으며, 키 목록에는 운영 키 `9a533a062f2084f19ccef0073bc2e930909c4810` 하나만 남겼다.
- 운영 연결 직후에는 테스트 전용 앱 인스턴스가 준비되지 않아 실제 삭제 API를 호출하지 않았다. 이후 별도 종단 검증 결과는 다음 절에 기록한다.

## Android 테스트 인스턴스 운영 종단 검증

2026-09-11 Android 17/API 37 `emulator-5554`에서만 삭제 요청을 1회 제출했다. 앱 인스턴스 ID와 설치 인증값은 출력하거나 문서에 기록하지 않았다.

- 운영 Worker 주소를 주입한 최신 x86_64 debug APK를 기존 앱 데이터 유지 방식으로 설치했다. 범용 APK는 에뮬레이터 저장공간 부족으로 덮어쓰기가 거부돼 ABI 전용 APK를 사용했으며 앱 데이터 전체 삭제는 하지 않았다.
- 설정 화면에서 기존 미동의 상태를 확인한 뒤 테스트 목적으로 명시적 동의를 적용했다. 스위치가 허용 상태로 바뀐 것을 확인하고 앱이 보관한 테스트 인스턴스로 ‘수집 중단 및 삭제 요청’을 실행했다.
- 운영 Worker 버전 `efd6c82f-ed3a-4696-95f5-0c0ae0119c14`의 인증된 `POST /api/v1/installations/:id/analytics-deletion`이 HTTP 202로 완료됐고 Worker 예외는 없었다. 이 응답은 Google Analytics Admin API가 유효한 `deletionRequestTime`을 반환한 경우에만 생성된다.
- 앱에 `Google Analytics에 삭제 요청이 접수됐어요. 기기의 분석 데이터도 초기화했어요.`가 표시됐고 이용 통계 스위치는 즉시 꺼졌다.
- 앱을 force-stop한 뒤 콜드 시작해도 이용 통계 스위치가 꺼진 상태로 유지됐다. 일회성 성공 문구는 사라졌고 보안 저장소의 `analytics_deletion_record_v1` 키도 남아 있지 않았다.
- 이는 테스트 인스턴스에 대한 삭제 **요청 접수**, 앱 수집 중단과 로컬 초기화의 종단 검증이다. Google 서버에서 과거 자료가 실제로 모두 제거된 시각을 확인한 결과는 아니며 실제 이용자 기기·Android 실물·iOS 검증도 아니다.

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

다음 우선순위: Android 실물과 iOS에서 같은 동의 경계를 확인하고 필요하면 패킷 단위 검증을 추가한다. 아래 에뮬레이터 검증만으로 모든 네트워크 전송 부재를 보장하지 않는다.

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

## 후속 FCM 데이터 메시지 백그라운드 경계 검증

2026-09-11 Android 17/API 37 `emulator-5554`에서 운영 FCM 경로의 데이터 전용 메시지로 앱을 백그라운드 시작해 확인했다. 실제 이용자 토큰·설치 ID·인증값은 출력하거나 문서에 기록하지 않았다.

- 앱을 홈으로 보낸 뒤 `am kill`로 프로세스만 종료했다. 패키지는 `stopped=false`였고, 메시지 전송 전 앱 프로세스가 없음을 확인했다.
- 운영 D1에 최근 갱신된 유일한 테스트 토큰을 참조하는 임시 설치 ID를 만들고, 기존 소유권 확인 라우트로 데이터 전용 FCM을 1회 전송했다. 운영 Worker가 HTTP 200 `ok`를 반환했다.
- 전송 1초 안에 새 앱 프로세스와 `FlutterFirebaseMessagingBackgroundService` 시작이 확인됐다. 앱 Activity는 전경에 나타나지 않았다.
- 같은 백그라운드 프로세스 로그에서 `App measurement disabled by setAnalyticsCollectionEnabled(false)`와 `Analytics storage consent denied`를 확인했다.
- 앱 전용 `google_app_measurement_local.db`를 메모리에서 읽은 결과 Analytics 로컬 `messages` 대기열은 0건이었다. 이후 앱을 강제 종료하고 콜드 시작한 설정 화면에서도 `앱 이용 통계 수집 (선택)`은 `checked=false`로 유지됐다.
- 별도 1회 전송에서는 프로세스 종료 뒤 앱 UID의 BPF 누적 수신·송신 바이트와 패킷 수가 3초 동안 변하지 않는 기준선을 먼저 확인했다. 데이터 전용 FCM 전송 뒤 1초·10초·30초 이상 시점까지 네 수치가 모두 기준선과 같았다. 이때 백그라운드 서비스 시작과 앱 Activity 미노출은 다시 확인됐고 Analytics 로컬 대기열도 0건이었다.
- 테스트 직후 임시 설치 ID와 연결된 설치·설정·발송 이력·특보 상태·소유권 확인·인증·활동 레코드가 모두 0건임을 확인했다. 실제 설치 레코드는 삭제하지 않았다.
- 이 결과는 Android 에뮬레이터의 해당 FCM 2회에서 비동의 상태, 로컬 대기열 0건 및 두 번째 관측의 앱 UID 통신량 무증가를 확인한 것이다. UID 통계는 목적지와 내용을 식별하는 패킷 캡처가 아니며 FCM을 수신한 Google Play 서비스 UID의 통신도 별도다. 짧은 관측 구간을 넘어선 지연 전송, Google Play 서비스 내부 큐, Android 실물, iOS 및 모든 백그라운드 진입 경로의 무전송을 입증하지는 않는다.

## 확인 결과

| 항목 | 현재 구현 |
| --- | --- |
| 최초 미동의 | SharedPreferences 기본 false, Android/iOS 수집 기본값 false |
| 명시적 동의 | 확인창 승인 → 동의 저장 → SDK 수집 허용 |
| 정상 철회 | SDK 수집 중단 → false 저장 → 거부 동의 적용 |
| 광고 관련 동의 | SDK 적용 시 광고 저장·사용자 데이터·개인화 동의 false |
| 철회 저장 실패 | 현재 실행에서는 수집 중단을 재시도하고 오류 표시 |
| 실패 후 재시작 | 이전 true 값이 남으면 initialize가 다시 수집을 허용할 수 있음. 보완 필요 |
| 이미 Google에 전송한 데이터 삭제 | Android 에뮬레이터 테스트 인스턴스로 운영 Worker·Google 요청 접수 1회 검증. 실제 삭제 완료시각과 Android 실물·iOS는 미확인 |
| 서버 내 나의 데이터 삭제 | 앱 서버 설치 데이터 DELETE만 실행. Google Analytics 삭제와 별개 |
| 로컬 Analytics 초기화 | Google 요청 접수 뒤 resetAnalyticsData 호출. 원격 실제 삭제 완료와 동일시하지 않음 |

확인 코드: `weather_care_app/lib/services/analytics_consent.dart`, `features/settings/analytics_consent_control.dart`, `services/server_data_access.dart`, `main.dart`, Android Manifest, iOS Info.plist.

기존 `flutter test test/analytics_consent_test.dart` 4개 통과. 주입된 apply 콜백을 검증하는 테스트이므로 실제 Firebase 전송 중단을 입증하지 않는다. 저장 실패 후 새 컨트롤러 생성/앱 재시작, SDK 초기화 이전·백그라운드 전송은 별도 검증이 필요하다.

## 최초 점검 당시 보완 순서

1. 철회 의사를 저장하는 과정의 실패/재시작 안전성 보완. 기존 true 동의가 자동 복구되지 않는 지속 상태와 시작 경계를 설계하고 재시작 회귀 테스트를 추가한다. 모든 저장 장치 실패를 단일 로컬 bool로 해결했다고 주장하지 않는다.
2. Analytics 삭제 요청 대상 식별·요청 권한·실패 재시도·보관 범위를 설계한다. Google은 Firebase app_instance_id 기반 사용자 삭제 요청을 지원하지만 현재 앱 서버 설치 ID와 다른 값이다. 임의 ID를 받아 다른 사람의 데이터를 삭제하지 않도록 권한 검증이 필요하다.
3. 원격 삭제 요청에 필요한 식별정보를 안전하게 확보하기 전에 SDK 초기화로 ID를 없애지 않는다. 이미 철회한 기기의 ID 조회 가능 여부와 구버전 데이터 처리 범위도 실제 SDK에서 검증한다. 삭제를 위해 수집을 다시 켜지 않는다.
4. Google 삭제 API 인증정보는 서버에만 두며 최소 권한으로 구성한다. 요청 접수와 실제 삭제 완료를 구분하고 완료가 확인되지 않은 상태에서 삭제 완료 문구를 출력하지 않는다.
5. Android/iOS 실기에서 미동의·동의·철회·재시작·오류 상태의 네트워크 확인 후 앱 문구와 개인정보처리방침을 최종화한다.

최초 점검 시점에는 앱 동작 변경·삭제 요청·운영 배포를 하지 않았다. 이후 상단의 원격 삭제 요청 흐름을 구현하고 운영 Worker까지 배포한 뒤 Android 에뮬레이터 테스트 인스턴스로 요청 접수까지 검증했다. Google 서버의 실제 삭제 완료시각은 확인하지 않았다. 보호자 동의 구현 보류도 유지한다.

공식 참고: [Google Analytics 사용자 삭제 요청](https://developers.google.com/analytics/devguides/config/admin/v1/rpc/google.analytics.admin.v1alpha#google.analytics.admin.v1alpha.SubmitUserDeletionRequest), [Firebase 로컬 데이터 초기화 안내](https://firebase.google.com/support/release-notes/unity).
