# HANDOFF

## 2026-08-11

### 작업 목표
- 내부 문서(앱/서버 개발명세 기반)로 프로젝트 골격을 생성.

### 완료 내용
- `/weather_care_app` Flutter 프로젝트 골격 작성
  - 앱 진입점(`main.dart`, `app.dart`)
  - 모델/서비스/테마/홈/설정 화면 위주로 최소 동작 구조 추가
  - Today/주간/비교 API 호출을 위한 네트워크 서비스 뼈대 포함
- `/weather_care_server` Cloudflare Workers + TypeScript + Hono + D1 프로젝트 골격 작성
  - 엔드포인트 라우트(`/today`, `/weekly`, `/comparison/...`, 설치/알림설정) 구성
  - Weather Rule Engine / Lifestyle Engine / Recommendation Engine / Notification Builder/Scheduler 뼈대 구성
  - D1 스키마 초안 및 Wranger 설정 템플릿 작성
- 작업 종료 시점: `/weather_care_app`, `/weather_care_server` 디렉터리를 생성해 내부 명세 기반 초기 구조 완료
- 확인되지 않은 항목: 실 디바이스 연동(위치권한, FCM 전송, 실제 Provider/API Adapter) 및 문법 검증은 다음 단계에서 수행 필요
- 내부 문서에서 제시한 데이터 모델(RecommendationType, AppSettings, API 응답 구조), 우선순위/구조 기준 반영

### 추적 포인트
- 다음 단계에서 실제 기상 API Provider 어댑터, FCM 실제 전송, 실제 위치 권한/토큰 갱신 로직, 상세 화면 기능을 구현해야 함

### Flutter 프로젝트 구조 보완
- `D:\IdeaProjects\letter` 구조를 참고해 `/weather_care_app`에 Flutter 공식 Android/iOS 플랫폼 프로젝트를 추가함.
- `.metadata`, `weather_care.iml`, `test/widget_test.dart`를 추가함.
- 현재 Flutter SDK에서 해결 가능한 버전으로 `flutter_lints`를 `^6.0.0`으로 조정함.
- Android applicationId 및 iOS bundle identifier 기본값은 `com.weathercare.weather_care`로 생성함.

### Android Java 전환
- 변경된 `AGENTS.md`에 맞춰 앱/서버 경로 기록을 `/weather_care_app`, `/weather_care_server`로 정정함.
- 앱 개발명세서에는 Kotlin/Java 구현 언어가 명시되어 있지 않아 문서는 수정하지 않음.
- Android 네이티브 진입점을 `MainActivity.kt`에서 `MainActivity.java`로 전환함.
- Flutter 공식 Java 템플릿 기준에 따라 Gradle의 Kotlin 플러그인과 `kotlinOptions`는 유지함.
- Android 빌드에서 발견된 `sourceCompatibility` 참조 오류를 `JavaVersion.VERSION_11`로 수정함.
- `flutter build apk --debug` 성공: `build/app/outputs/flutter-apk/app-debug.apk` 생성 확인.

### Android Gradle Groovy DSL 전환
- 사용자 요청에 따라 Android Gradle 설정을 Kotlin DSL에서 Groovy DSL로 전환함.
- `android/build.gradle.kts`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`를 제거함.
- 각각 `android/build.gradle`, `android/settings.gradle`, `android/app/build.gradle`로 대체함.
- Flutter/Android/Kotlin 플러그인 버전과 Java 11 컴파일 설정은 기존과 동일하게 유지함.
- Groovy DSL 전환 후 `flutter build apk --debug` 성공을 확인함.

### IntelliJ Flutter 프로젝트 인식 복구
- `/weather_care_app/.idea`에 자동 생성된 중복 모듈 `app.iml`, `weather_care_app.iml`을 제거함.
- 공식 Flutter 프로젝트 구조에 맞춰 `modules.xml`에서 `weather_care.iml`과 Android 모듈을 연결함.
- Flutter `main.dart` 실행 구성과 `KotlinJavaRuntime` 라이브러리 정의를 복원함.
- Computer Use 런타임의 문서 API가 설치된 버전과 맞지 않아 IntelliJ UI 직접 조작은 수행하지 않음.
- `flutter doctor -v`에서 IntelliJ IDEA 2024.3.5, Flutter 플러그인 88.1.0, Dart 플러그인 및 Android toolchain 정상 인식을 확인함.

### Android 에뮬레이터 런타임 오류 수정
- 실행 중인 `emulator-5554`(Android 15/API 35)에 앱을 설치하고 실제 화면을 검증함.
- `InputChip`에 `onSelected`와 `onPressed`가 동시에 지정되어 발생하던 Flutter assertion 오류를 수정함.
  - 칩 본문은 선택 상태 변경, 정보 아이콘은 상세 화면 이동으로 역할을 분리함.
- 타임라인 추천 칩이 `ListTile.trailing` 폭을 차지해 상태 문구가 세로로 깨지던 레이아웃을 좁은 화면 대응 구조로 변경함.
- 설정의 deprecated `RadioListTile.groupValue/onChanged`를 최신 `RadioGroup` 구조로 전환함.
- 불필요한 문자열 보간 경고를 제거함.
- 추천 칩 선택/상세 이동과 360px 타임라인 레이아웃 회귀 테스트를 추가함.
- 검증 결과:
  - `flutter analyze`: 이슈 없음
  - `flutter test`: 3개 테스트 모두 통과
  - 에뮬레이터 재설치 및 홈/추천 상세/설정 GPS→MANUAL 전환 확인
  - AndroidRuntime/Flutter 오류 로그 없음

### 개발명세 기반 Soft Weather UI 개편
- 앱 개발명세의 Final Home 정보 우선순위와 Soft Weather 디자인 토큰을 기준으로 UI를 전면 개편함.
  - 상단 한 줄 브리핑 → 오늘의 가방 → 오늘 하루 타임라인 → 생활 날씨 → 상세 수치 → 주간 날씨 순서로 재배치
  - 저채도 날씨 배경, 흰색 Surface, Recommendation별 의미 색상, 공통 섹션 헤더와 카드 스타일 적용
  - 추천 카드는 하루 단위 체크 상태와 상세 이유 이동을 분리하고 0~3개 이상에서도 안정적인 Wrap 레이아웃 사용
- `MaterialApp.debugShowCheckedModeBanner=false`로 디버그 배너를 제거함.
- 홈 상단에 데이터 출처 배지를 추가함.
  - 서버 연결 성공 시 `실시간 서버`, 실패 시 `샘플 데이터`로 표시
  - Android 에뮬레이터의 기본 로컬 서버 주소를 `http://10.0.2.2:8787`로 사용하고 `SERVER_URL` 지정값을 우선함.
- 서버가 없어도 첫 화면이 즉시 보이도록 앱 내 샘플 Today/Weekly 응답을 초기 상태로 사용하고, Today/Weekly 서버 요청은 병렬 실행함.
- 설정 화면을 위치 모드, 전체 알림, 알림 시간, 준비물 알림, 주의/날씨 알림 카드로 재구성함.
  - 현재 설정이 메모리 내 데모 상태이며 서버 저장이 연결되지 않았음을 화면 하단에 명시함.
- 추천 상세/상세 날씨 화면도 동일한 테마로 정리하고 서버 근거 데이터 미연결 상태를 명시함.
- Android 15/API 35 에뮬레이터에서 홈 전체 스크롤, 상태바 SafeArea, GPS→MANUAL 전환, 추천 상세 이동을 시각 검증함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 3개 통과, AndroidRuntime/Flutter 오류 로그 없음.

### 현재 앱/서버 연결 상태
- 앱은 외부 기상 API를 직접 호출하거나 Recommendation Threshold를 계산하지 않음.
- 서버 미연결 시 `lib/data/sample_payloads.dart`의 이미 계산된 샘플 Recommendation/Lifestyle/Timeline을 표시함.
- 서버 프로젝트의 Today API, Rule/Lifestyle/Recommendation Engine, D1 저장 라우트는 골격이 있으나 Weather/Air/Historical Provider는 Dummy 구현임.
- FCM 전송은 TODO/no-op이고 알림 대상 Recommendation 조회도 빈 배열을 반환하므로 실제 Push는 아직 동작하지 않음.

### 루트 README 앱/서버 책임 문서화
- 저장소 루트에 `README.md`를 추가함.
- 앱과 서버의 책임 경계, 서버 처리 파이프라인, 서버 없이 앱이 샘플 데이터로 동작하는 과정, 데이터 출처 배지 의미를 문서화함.
- 현재 앱의 미구현 항목과 서버의 Dummy Provider/하드코딩 Weekly/FCM TODO 상태를 명시함.
- Android 에뮬레이터의 로컬 서버 주소 `10.0.2.2:8787`과 `SERVER_URL` 지정 예시를 추가함.
- 하위 앱/서버 README의 실행 경로를 실제 디렉터리명으로 정정함.

## 2026-08-18

### IntelliJ 에뮬레이터 실행 대상 미인식 진단
- IntelliJ 우측의 임베디드 Android 에뮬레이터 프로세스는 실행 중이나, ADB에서 `emulator-5554 offline`으로 표시됨.
- `flutter devices -v`는 Android 에뮬레이터를 제외하고 Windows/Chrome/Edge만 실행 가능 대상으로 인식함.
- IntelliJ 상단 실행 대상은 `Windows (desktop)`이며, Debug 콘솔에서도 `flutter attach --device-id=windows` 실행 후 종료된 상태를 확인함.
- 결론: Flutter 실행 구성이나 Run 버튼 문제가 아니라 ADB와 에뮬레이터 간 연결이 offline 상태여서 IntelliJ가 Android 실행 대상으로 노출하지 못한 문제임.
- `adb kill-server/start-server`와 `adb reconnect offline` 후에도 offline 상태가 유지됨.
- ADB와 Emulator는 모두 `D:\Android\sdk`의 단일 설치본을 사용하며, 5037/5554/5555 포트 연결도 정상이라 SDK 중복이나 포트 충돌은 아님.
- `Medium_Phone.avd/config.ini`에서 `fastboot.forceFastBoot=yes`를 확인했고 Quick Boot 스냅샷에 `ram.img.dirty`가 남아 있어, 화면만 복원되고 게스트 `adbd`가 멈춘 스냅샷 문제로 판단함.
- 다음 조치: IntelliJ Device Manager에서 `Medium_Phone`을 종료한 뒤 `Cold Boot`하고, `adb devices`가 `emulator-5554 device`로 바뀌는지 확인해야 함.

### 5개 탭 UI 및 시간대별 판단 명세 개편
- Flutter 1차 화면을 `Today - Detail - Main - Week - Setting` 고정 바텀 내비게이션으로 재구성함.
  - 시작 탭은 중앙 `Main`(`selectedIndex=2`).
  - `Main`: 비스크롤 고정 화면, 최상단 브리핑 카드 + 생활 날씨 3카드.
  - `Today`: 오늘의 가방 + 오늘 하루 타임라인.
  - `Detail`: 현재 상세 지표 + 추천 근거 + 시간별 온도/체감/강수/강설/바람.
  - `Week`: 주간 요약 + 7일 카드와 대표 준비물.
  - `Setting`: 기존 설정 화면을 탭에 임베드하고 상태를 유지함.
- `HourlyWeatherItem`과 Today 응답의 `hourly` 배열을 앱/서버 계약에 추가함.
- 앱 샘플 payload와 Dummy Today API에 06/09/12/15/18/21시 hourly 데이터를 추가함.
- 서버에 Recommendation 7종 다중 문구 카탈로그와 Lifestyle 문구 카탈로그를 추가하고 Today 응답에 친화 문구를 사용함.
- 앱/서버 개발명세서 개정:
  - 앱: 5개 탭 계약, 360×800 Main 비스크롤 규칙, Detail hourly 필드/결측 표시, 회귀 테스트.
  - 서버: 시간 구간, Trigger/Release와 2슬롯 hysteresis, 강수·강설·체감온도·바람·UV·빨래·환기 초기 기준, 결측/충돌/우선순위, 문구 예시와 카탈로그 운영 규칙.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 4개 테스트 통과. 5탭 순서/시작 탭/Main subtree 비스크롤/360×800 overflow를 포함함.
  - Android 17/API 37 `emulator-5554`: APK 빌드·설치 후 Main/Today/Detail/Week/Setting 시각 검증, Flutter/RenderFlex/AndroidRuntime 오류 없음.
  - 서버 `npx tsc --noEmit`: 통과. Dummy Provider의 interface 인자도 정합화함.
  - DOCX: Word 16 PDF 렌더 후 앱 13페이지, 서버 16페이지 전 페이지 PNG 검토. 잘림/겹침/한글 깨짐 없음. 서버 기준표의 페이지 분할 행을 수정 후 재검토함.
  - DOCX 접근성 감사: high 0건. medium은 기존 표의 반복 헤더 미지정만 앱 7건/서버 6건이며 이번에 추가한 표는 반복 헤더 지정됨.
- 현재 한계:
  - 명세의 시간대별 집계 기준은 운영 초안이며, 실제 WeatherRuleEngine은 아직 Dummy/current snapshot 중심임. Provider hourly 정규화·캐시·2슬롯 집계 구현이 다음 단계임.
  - 실제 DB 문구 테이블 대신 TypeScript fallback 카탈로그를 구현함. D1 이전 스키마 필드는 서버 명세 23.3에 기록함.
  - `npm install` 감사에서 기존 의존성 기준 2 moderate/4 high가 보고됐으나 breaking 변경 가능성이 있어 자동 `audit fix --force`는 적용하지 않음.

### 에뮬레이터 실서버 연결 및 전 탭 재검증
- 실행 중인 Android 17/API 37 `emulator-5554`에서 로컬 Workers 서버를 실제 연결해 Main/Today/Detail/Week/Setting의 상단·하단과 상호작용을 재검증함.
- 최초 연결 실패의 직접 원인은 `10.0.2.2:8787`에 서버가 실행되지 않은 상태였음. 서버 기동 후에는 로컬 D1의 `weather_cache` 테이블 누락으로 Today API 500을 추가 확인함.
- 로컬 실행 복구:
  - `package.json`의 D1 대상 이름을 `weather_care_db`로 수정함.
  - `wrangler.toml`의 cron 설정을 올바른 `[triggers]` 테이블로 수정함.
  - `npm run db:migrate`로 로컬 D1 7개 명령을 적용하고 캐시 저장 행 생성까지 확인함.
  - README에 `npm install -> npm run db:migrate -> npm run dev -- --ip 0.0.0.0 --port 8787` 순서를 기록함.
- 실서버 응답/UI 정합성 수정:
  - Weekly 더미 응답을 현재 요일부터 7일로 확장하고 6일의 대표 준비물을 추가함.
  - `소나기`를 비 예보 집계와 우산 아이콘에 포함함.
  - 현재 하늘 상태 `Cloudy`를 `흐림`으로 현지화함.
  - Today 타임라인 추천을 시점별로 분리해 07시는 0개, 12시는 선크림, 18시는 우산만 표시함.
  - 서버 LifestyleInsight 13종을 Flutter가 모두 해석하고 타입별 아이콘/색상을 표시하도록 확장함.
  - Today 추천 정보 버튼은 오래된 정적 안내 화면 대신 실제 근거와 시간대 수치를 제공하는 Detail 탭으로 이동함.
- 런타임 확인:
  - `/health`, Today, Weekly 모두 200. Today hourly 6개, Weekly 7일, 타임라인 추천 개수 `0/1/1` 확인.
  - Main의 `실시간 서버` 배지, Today 카드 체크 상태, 추천 정보 버튼의 Detail 탭 이동, Week 7일 끝까지 스크롤, Setting GPS→직접 선택 상태의 탭 이동 후 유지, 수동 새로고침을 확인함.
  - 앱 PID 기준 `Connection refused`, fallback, Flutter/RenderFlex, unhandled/FATAL 로그 0건.
  - `flutter analyze` 이슈 없음, `flutter test` 4개 통과, 서버 `npx tsc --noEmit` 통과.
- 검증용 `node_modules`, `package-lock.json`, `.wrangler/state`, 화면 캡처는 종료 시 정리함. 다시 실행할 때는 `weather_care_server`에서 `npm install`, `npm run db:migrate`, `npm run dev -- --ip 0.0.0.0 --port 8787` 순서로 실행함.

### 로컬 서버 상시 실행 및 fallback 로그 정리
- 사용자가 다시 확인한 `Connection refused`는 이전 검증 종료 시 로컬 서버를 함께 종료한 데서 발생했으며 앱/네트워크 주소 오류가 아님.
- 서버 의존성과 로컬 D1 마이그레이션을 다시 구성하고 Wrangler dev 서버를 `0.0.0.0:8787`에서 실행 상태로 유지함.
- `weather_care_server/.gitignore`를 추가해 `node_modules`, `.wrangler`, `.dev.vars`, 로그가 작업 트리에 노출되지 않도록 함.
- 의도된 샘플 fallback에서 전체 예외/스택을 출력하지 않고 API 종류와 예외 타입만 한 줄로 기록하도록 `weather_service.dart`를 수정함.
- 최신 Debug APK를 `emulator-5554`에 재설치하고 Main 화면을 열어둠.
- 최종 확인: `실시간 서버` 배지 표시, Today/Weekly 200, 앱 PID 기준 fallback/Connection refused/Flutter/RenderFlex/FATAL 로그 0건, 8787 listener 동작 중.
- `I/ImeTracker ... ALREADY_HIDDEN`과 Google Ads/Chromium `jsLoaded GMSG`는 오류가 아닌 SDK 정보 로그임.
- 재검증: `flutter analyze` 이슈 없음, `flutter test` 4개 통과, `npx tsc --noEmit` 통과, Debug APK 빌드·설치 성공.

### 시간대별 판단 기준 및 문구 카탈로그 독립 명세
- `docs/날씨챙겨_시간대별_판단기준_및_문구카탈로그.docx`를 신규 작성함.
- 시간대별 `WeatherSnapshot`/`TodayWeatherResponse.hourly` 필드, 단위, 정규화, 결측 처리와 최소 24시간·권장 48시간 계약을 문서화함.
- 강수·강설·결빙·체감온도·바람·자외선·빨래·환기의 Trigger/Release, 연속 슬롯 hysteresis, severity, 우선순위, 충돌/결측 억제 기준을 표로 고정함.
- 현재 단일 snapshot 중심 구현과 목표 시계열 엔진을 상태표로 구분했으며, 현재 빨래 확률 비교와 일교차 계산의 정합화 필요 사항을 명시함.
- 현재 TypeScript fallback과 같은 Recommendation 21개 문구, Lifestyle 26개 문구를 D1 seed 키 체계와 함께 수록함.
- 향후 D1 이전용 `message_groups`, `message_variants`, `message_rule_bindings` 3테이블 SQL, 인덱스, seed 예, deterministic selection, code fallback, 단계적 이전/rollback을 문서화함.
- DOCX 검증 결과:
  - Word 16 PDF 렌더 + Poppler PNG 변환으로 15페이지 전부 검토함.
  - 잘림·겹침·표 분할·한글 깨짐·단독 이월 페이지 없음.
  - 접근성 감사 high/medium/low 모두 0건, Heading 1 14개/Heading 2 25개, 표 30개 반복 머리글 확인.
  - 기본 `render_docx.py`는 로컬 LibreOffice 실행 파일 부재로 실패해 설치된 Word 렌더링으로 대체 검증함.

## 2026-08-20

### Cloudflare 운영 배포 절차 점검
- 서버의 Cloudflare Workers/D1 배포 준비 상태와 필요한 명령을 점검함.
- `npx tsc --noEmit`과 `npx wrangler deploy --dry-run`은 성공했으며 번들 생성과 `DB` 바인딩 인식까지 확인함.
- 현재 로컬 Wrangler는 3.114.17이고 4.x 업데이트 경고가 있으며, Cloudflare 계정은 로그인되지 않은 상태임.
- `wrangler.toml`의 D1 `database_id`는 아직 `replace-with-your-d1-id`이므로 D1 생성/조회 후 실제 UUID로 교체해야 함.
- 운영 D1에는 로컬 전용 `npm run db:migrate`가 아니라 `npx wrangler d1 migrations apply weather_care_db --remote`를 사용해야 함.
- 실제 계정 로그인, D1 생성, 원격 마이그레이션 및 Worker 배포는 외부 리소스 변경이므로 이번 설명 작업에서는 수행하지 않음.
- 배포 후 Flutter 앱 실행/빌드 시 `--dart-define=SERVER_URL=https://...workers.dev`로 Worker HTTPS 주소를 주입해야 함.
- 현재 Cron 표현식은 UTC 기준이므로 `0 7 * * *`, `10 5 * * *`는 한국 시간으로 각각 매일 16:00, 14:10에 실행됨.

### Cloudflare D1 원격 마이그레이션 오류 해결
- `database_id = "replace-with-your-d1-id"`가 Cloudflare API에 전달되어 `Invalid uuid [code: 7400]`가 발생한 것을 확인함.
- 로그인된 Cloudflare 계정의 D1 목록에서 기존 `weather_care_db`와 실제 UUID를 확인하고 `weather_care_server/wrangler.toml`에 반영함.
- `npx wrangler d1 migrations apply weather_care_db --remote`로 `0001_init.sql`의 7개 명령을 원격 D1에 정상 적용함.
- 원격 DB에서 `installations`, `active_regions`, `notification_settings`, `weather_cache`, `daily_weather_snapshots`, `notification_history`, `d1_migrations` 테이블 생성을 확인함.
- 원격 마이그레이션 재조회 결과 대기 항목이 없고, `npx tsc --noEmit` 및 `npx wrangler deploy --dry-run`도 실제 D1 바인딩으로 통과함.
- 실제 Worker 배포는 수행하지 않았으며 다음 명령은 `npm run deploy`임.

### Cloudflare D1 UUID 확인 방법
- `weather_care_server`에서 `npx wrangler d1 info weather_care_db --json`을 실행해 DB 이름과 UUID를 직접 확인하는 방법을 검증함.
- 현재 `weather_care_db`의 UUID는 `9d1c83ca-9626-4b92-b4ea-db7433115324`이며 `wrangler.toml` 설정값과 일치함.
- 계정의 모든 D1을 표로 확인할 때는 `npx wrangler d1 list`를 사용할 수 있음.

### Flutter SERVER_URL 입력 위치 확인
- 앱은 `HomeScreen._resolveServerUrl()`에서 `String.fromEnvironment('SERVER_URL')`을 읽으므로 런타임 환경변수나 Cloudflare 설정이 아니라 Flutter 빌드 인자로 전달해야 함.
- 기존 IntelliJ `main.dart` Run Configuration의 `Additional run args`에 `--dart-define=SERVER_URL=https://...`를 저장하면 Run 버튼 실행 때마다 자동 적용할 수 있음.
- 현재 Flutter 3.35.6에서 `--dart-define-from-file=<json|.env>` 지원도 확인했으며, 별도 설정 파일 방식도 사용할 수 있음.
- 실제 배포 URL이 아직 확정되지 않아 Run Configuration이나 설정 파일은 이번 작업에서 변경하지 않음.

### Flutter 운영 SERVER_URL 기본 적용
- Wrangler 배포 기록과 로그에서 운영 Worker 주소 `https://weather-care-server.sy40222.workers.dev`를 확인함.
- `HomeScreen._resolveServerUrl()`의 `String.fromEnvironment` 기본값을 운영 Worker 주소로 변경해, 별도 `Additional run args`나 `--dart-define` 없이 모든 플랫폼에서 운영 서버를 사용하도록 함.
- 로컬 개발 시에만 `--dart-define=SERVER_URL=http://...`로 기본값을 덮어쓰도록 앱/루트 README를 갱신함.
- 운영 Worker `/health` 응답 `ok`, Today/Weekly API HTTP 200을 확인함.
- `flutter analyze` 이슈 없음, `flutter test` 4개 모두 통과함.

### 누적 수정내역 분리 커밋 및 운영 데이터 출처 확인
- 누적된 앱, 서버, 실행 설정, IntelliJ 설정, README, DOCX 명세 변경을 기능 단위 커밋으로 분리함.
- 커밋 전 검증 결과:
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 4개 테스트 모두 통과.
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 `npx wrangler deploy --dry-run`: 실제 D1 바인딩을 포함해 통과.
- 로컬 `8787` 포트에는 실행 중인 서버가 없고, 앱 기본 대상인 운영 Worker `https://weather-care-server.sy40222.workers.dev`는 `/health`와 Today API가 정상 응답함.
- 운영 Today 응답의 온도, 강수확률, 미세먼지 값이 저장소의 `DummyWeatherProvider` 및 `DummyAirQualityProvider` 고정값과 일치함을 확인함.
- 현재 서버는 기상청이나 외부 날씨 API를 호출하지 않으며 Dummy Provider가 생성한 데이터를 정규화·판단한 뒤 D1 `weather_cache`에 저장하고 반환함.

### 기상청 단기예보 Provider 구현
- 공공데이터포털의 `기상청_단기예보 조회서비스`를 사용하는 `KmaWeatherProvider`를 추가함.
  - `getVilageFcst` JSON 응답을 Zod로 검증함.
  - 한국시간 기준 최근 발표시각을 선택하고 최신 자료가 아직 없으면 이전 발표분까지 재시도함.
  - `TMP`, `REH`, `WSD`, `POP`, `PCP`, `SNO`, `PTY`, `SKY`, `TMN`, `TMX`를 현재·시간별·일별 공통 모델로 변환함.
  - 체감온도는 기온·습도·풍속으로 계산하고 강수/적설 문구 값을 숫자로 정규화함.
- Today API의 고정 날씨·고정 타임라인을 기상청 예보 기반 브리핑, 향후 48시간, 추천 타임라인으로 교체함.
- Weekly API의 7일 하드코딩을 제거하고 기상청 단기예보가 제공하는 오늘부터 글피까지의 날짜만 반환하도록 변경함.
- 기상청에 없는 미세먼지·자외선 값은 Dummy 값으로 채우지 않고 결측으로 유지함.
- 사용하지 않게 된 Dummy Weather/Air Provider와 기존 범용 WeatherNormalizer를 제거함.
- API 응답에 `dataSource=기상청 단기예보`를 추가하고 Flutter 홈 배지에 표시함.
- Secret 관리:
  - 로컬은 Git 제외 대상 `.dev.vars`의 `KMA_SERVICE_KEY`를 사용함.
  - 운영은 `npx wrangler secret put KMA_SERVICE_KEY`로 등록해야 함.
  - 현재 로컬·환경변수·운영 Worker Secret 목록에는 키가 없어 실제 운영 배포는 수행하지 않음.
  - 키 등록 전까지 현재 운영 Worker는 이전 Dummy Provider 배포본으로 계속 동작함.
- 검증 결과:
  - 서버 Vitest/Workers Pool: 기상청 Provider 테스트 4개 통과.
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 `npx wrangler deploy --dry-run`: 통과.
  - 서버 `npx wrangler check startup`: 활성 CPU 약 3.4ms.
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 4개 모두 통과.
  - `npm audit`: 취약점 0건.
- 생성 커밋:
  - `ccfa574 feat(server): 기상청 단기예보 연동`
  - `32a4944 feat(app): 기상청 데이터 출처 표시`
  - `c255a36 docs: 기상청 API 설정 안내`

### 운영 서버 장애 시 앱 직접 조회 Fallback
- 앱의 런타임 샘플 데이터 Fallback을 제거함.
- 조회 순서를 `운영 서버 -> 앱의 기상청 단기예보 직접 조회 -> 미지원`으로 변경함.
  - 운영 서버만 실패하고 인터넷이 연결된 경우 `KMA_SERVICE_KEY` Flutter 빌드 인자로 기상청 원시 예보를 직접 조회함.
  - 직접 조회에서는 기온, 습도, 바람, 강수, 하늘 상태와 시간별·일별 예보만 표시함.
  - 추천, 생활 날씨, 준비물, 타임라인, 체감온도처럼 서버 연산이 필요한 항목은 `운영 서버 미연결로 미지원`으로 표시함.
  - 인터넷 연결 확인은 Cloudflare 204 응답을 사용하며 연결 불가 시 날씨 화면 전체를 `인터넷 연결 불가로 미지원`으로 표시함.
- Android Release에서도 네트워크를 사용할 수 있도록 Main Manifest에 `INTERNET` 권한을 추가함.
- IntelliJ 공유 `main.dart` 실행 구성에 운영 Worker URL을 명시함. 직접 조회 키는 저장소에 넣지 않고 `Additional run args`에 `--dart-define=KMA_SERVICE_KEY=...`로 로컬 설정해야 함.
- IntelliJ Debug 연결 진단:
  - 기존 실행 구성에는 `SERVER_URL` 덮어쓰기가 없었고 앱 기본값도 운영 Worker URL이어서 주소 구성 문제는 아니었음.
  - 운영 `/health`는 200이지만 Today API는 502 `WEATHER_PROVIDER_UNAVAILABLE`을 반환함.
  - Wrangler Tail에서 `KmaWeatherProvider`의 `TypeError`를 확인했고, 네이티브 `fetch`가 Provider 인스턴스에 메서드로 바인딩되지 않도록 전역 호출 래퍼로 수정함.
  - 운영 Worker에는 `KMA_SERVICE_KEY` Secret이 등록되어 있음을 이름 목록으로 확인함.
- 검증 결과:
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 7개 모두 통과.
  - 운영 URL을 지정한 Debug APK 빌드 및 Android 17 에뮬레이터 설치 성공.
  - 배포 전 운영 502 상태에서 앱이 샘플 대신 `KMA_SERVICE_KEY 미설정으로 직접 조회 미지원`을 표시하고, 앱 로그에 FATAL/RenderFlex/Unhandled 오류가 없음을 확인함.
  - 서버 Vitest 4개, `npx tsc --noEmit`, `npx wrangler deploy --dry-run` 모두 통과.
- 생성 커밋:
  - `a90a1b1 fix(server): 기상청 fetch 호출 바인딩 수정`
  - `23bc30b feat(app): 서버 장애 시 기상청 직접 조회`
  - `45dd7b3 chore(app): IntelliJ 운영 URL 명시`
- 남은 운영 작업:
  - `a90a1b1` 이후 서버 코드를 `npm run deploy`로 재배포해야 Today/Weekly 502가 해소됨.
  - 앱 직접 조회를 실제 Debug/배포 빌드에서 사용하려면 별도의 Flutter `KMA_SERVICE_KEY` 빌드 인자가 필요함.

### KMA Debug 설정 자동 적용 및 샘플 소스 제거
- 앱 프로젝트에 로컬 입력 문서 `kma.debug.json`을 생성함.
  - `SERVER_URL`은 운영 Worker 주소로 입력함.
  - `KMA_SERVICE_KEY`는 사용자가 발급키를 직접 입력할 수 있도록 빈 값으로 둠.
  - 실제 파일은 `.gitignore`에 추가하고, 형식 공유용 `kma.debug.example.json`만 추적함.
- IntelliJ 공유 `main.dart` Run/Debug 구성을 `--dart-define-from-file=kma.debug.json`으로 변경함.
  - 이후 `kma.debug.json`만 수정하면 IntelliJ Run/Debug에 자동 적용됨.
  - 현재 로컬 `workspace.xml`의 동일 실행 구성도 같은 인자로 맞춤.
- 더 이상 사용하지 않는 `lib/data/sample_payloads.dart`를 삭제함.
- 서버의 `sampleSettings`는 날씨 샘플이 아닌 기본 알림 설정이므로 `defaultSettings`로 이름을 정리함.
- 앱·서버·현재 README에서 `sample`/`샘플` 및 `sample_payloads` 참조가 0건임을 확인함.
- 검증 결과:
  - 실제 로컬 `kma.debug.json`이 Git 제외 대상이고 예제 파일만 추적됨.
  - IntelliJ 실행 구성 XML과 실제/예제 JSON 파싱 성공.
  - `flutter analyze` 이슈 없음, `flutter test` 7개 통과.
  - `flutter build apk --debug --dart-define-from-file=kma.debug.json` 성공.
  - 서버 Vitest 4개와 `npx tsc --noEmit` 통과.
- 생성 커밋:
  - `9d1fb1a chore(app): KMA 디버그 설정 자동 적용`
  - `0ce7c41 refactor: 샘플 데이터 제거`

### KMA 설정 Debug/Release 공통 적용
- 사용자가 키를 입력한 기존 추적 대상 예제 파일을 확인했으며 키 값을 출력하지 않고 Git 제외 대상 `weather_care_app/config/kma.config.json`으로 이동함.
- 추적 예제는 `weather_care_app/config/kma.config.example.json`으로 교체하고 실제 설정 파일은 `.gitignore`에 등록함.
- `config/` 디렉터리를 Flutter 자산으로 등록하고 `AppConfig`가 앱 시작 시 `config/kma.config.json`을 읽도록 구현함.
  - Debug/Release 및 IntelliJ/CLI 실행 방식과 관계없이 같은 설정을 적용함.
  - 설정 파일이 없거나 잘못된 경우 기존 `String.fromEnvironment`와 운영 서버 기본값으로 안전하게 Fallback함.
  - 명시적인 `--dart-define` 값은 로컬 파일보다 우선해 로컬 서버와 CI Override를 유지함.
- IntelliJ Run Configuration의 `--dart-define-from-file` 의존성을 제거함.
- 검증 결과:
  - `flutter analyze` 이슈 없음, `flutter test` 8개 통과.
  - 별도 Dart Define 없이 Debug APK와 Release APK 빌드 성공.
  - 두 APK 모두 `assets/flutter_assets/config/kma.config.json`을 정확히 1개 포함함.
  - 실제 키 파일은 Git 제외 상태이며 저장소 추적 목록에 포함되지 않음.
- 생성 커밋:
  - `9c2e832 feat(app): KMA 설정을 모든 빌드에 적용`
  - `da6de87 fix(app): 빌드 인자 우선순위 보장`

### v1.1 시간대별 판단 기준 및 출처 UI 반영
- `docs/날씨챙겨_시간대별_판단기준_및_문구카탈로그_v1.1.docx` 24페이지를 Word PDF 렌더와 Poppler 이미지로 전 페이지 확인하고 v1.0과 변경점을 대조함.
- 앱 출처 UI:
  - Main 상단의 `기상청 단기예보`/직접 조회 출처 배지를 제거함.
  - Setting 최하단에 9px 보조 문구 `날씨 정보는 기상청 공식 API를 사용합니다.`를 추가함.
  - 시간대별 눈 정보는 공식 확률처럼 보이는 `%` 표시를 제거하고 PTY·SNO 기반 `눈 예상` 파생값으로 표시함.
  - 서버 응답 시간은 `forecastAt`을 우선 사용하고 기존 `observedAt`은 하위 호환으로 유지함.
- 서버 v1.1 핵심 반영:
  - KMA `PCP`/`SNO`의 없음·미만·범위·이상 값을 `AmountRange`로 보존하고 기존 숫자 필드는 보수적 하한값으로 유지함.
  - `forecastAt`, `validFrom/To`, `issuedAt`, `fetchedAt`, `provider`, `rawValue`, `qualityFlags`, `precipitationType`, `snowExpected` 메타데이터를 추가함.
  - Today 판단을 current 1건 집계에서 향후 24시간 시계열 엔진으로 교체함.
  - 일반 2슬롯, 빨래 3슬롯, 출퇴근 비/안전 high 1슬롯 즉시, 주제별 2슬롯 Release hysteresis를 구현함.
  - POP/PCP 강수, PTY/SNO 강설, 결빙 위험, 체감더위, 겉옷, 체감추위, 6/9m/s 바람, 6/8 UV, 실제 일교차, 급격한 기온 하강, 빨래, 환기, 고·저습 기준을 v1.1 값으로 정합화함.
  - `decisionVersion=weather-rules-1.1.0`, `catalogVersion=ko-KR-2026.08.2`와 추천 근거·원본 필드를 응답에 추가함.
  - v1.1 추가 Lifestyle 문구 카탈로그를 코드 fallback에 추가하고 시간·마감 placeholder 누락 시 빈 문자열이나 `null`을 노출하지 않도록 처리함.
  - 출퇴근 변화, 비 공백, 이동 위험, 젖은 노면, 세차 미루기, 실내 건조, 창문 확인, 제습/가습, 차량 성에 등 KMA 단기예보만으로 근거가 충분한 항목을 시계열에서 생성함.
  - 외출 최적 시간과 환기 긍정 문구는 UV·PM·오존 등 필수 입력이 모두 있을 때만 생성하며, KMA 단기예보만 있는 현재 응답에서는 억제함.
- 아직 별도 연동이 필요한 v1.1 범위:
  - 에어코리아 PM/오존, 기상청 생활기상지수·공식 특보, 꽃가루·동파 입력은 Provider가 없어 생성하지 않음.
  - 개인화 context가 필요한 빨래 걷기·반려동물 산책과 D1 문구 primary/shadow 단계는 미구현이며 TypeScript fallback을 계속 사용함.
  - 운영 서버 미연결 시 앱 직접 조회는 기존처럼 원시 날씨만 제공하고 서버 판단·추천은 미지원으로 표시함.
- 검증 결과:
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 10개 통과.
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 Vitest: 3파일 13개 통과. 범주 파싱, 강수 경계, 출퇴근 즉시 발동, Release hysteresis, PTY 눈 판단, 빨래 결측 억제, 일교차, 문구 placeholder를 포함함.
- 배포:
  - 운영 서버에 v1.1 판단/문구를 적용하려면 `weather_care_server`를 재배포해야 함. D1 마이그레이션은 없음.
  - 앱의 배지 제거·설정 안내·눈 예상 표시는 새 앱 빌드/배포가 필요함. IntelliJ Debug는 현재 소스 실행 즉시 반영됨.
- 생성 커밋:
  - `3046c04 refactor(app): 기상청 출처 안내 위치 변경`
  - `0d38b42 feat(server): v1.1 판단 및 문구 반영`
  - `bdd5f23 test(app): 기상청 출처 안내 검증`
  - `edbb4fb refactor(app): 눈 예상을 파생값으로 표시`

### Flutter UI 단일 톤 색상 체계 정리
- 앱 전역 팔레트를 화이트/쿨그레이 Surface와 저채도 슬레이트 블루 강조색 중심으로 재정의함.
- 추천 종류별로 달랐던 주황·보라·초록·청록 계열 색상을 제거하고, 준비물·추천·생활 날씨는 공통 강조색을 사용하며 아이콘과 문구로 종류를 구분하도록 변경함.
- 날씨 상태별 배경도 서로 다른 웜/쿨 컬러 대신 같은 블루그레이 계열의 명도 차이만 사용하도록 통일함.
- 색상이 남는 영역을 메인 날씨 카드, 선택/활성 상태, 설정의 알림 활성 카드로 제한함.
- 설정 저장 미연결 안내는 의미 전달이 필요한 예외로 두고 저채도 주의색을 유지함.
- 화면에 흩어진 배경/테두리 색을 `WeatherCareTheme`의 공통 Surface 토큰으로 교체하고, 추천 색상 통일 회귀 테스트를 추가함.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 11개 모두 통과.
  - Debug APK 빌드 및 Android 에뮬레이터 설치 성공.
  - 360×800 기준 Main/Today/Setting 화면 시각 검증 완료. RenderFlex/overflow/FATAL/Unhandled 오류 없음.

### Flutter 온도 단위 표기 통일 및 UI 변경 커밋
- Main 현재/체감온도, Detail 현재/체감·시간대별 온도, Week 요약·최저·최고 온도를 모두 `°C` 형식으로 변경함.
- 공통 상세 날씨 카드에 현재·체감온도가 `°C`로 표시되는 회귀 테스트를 추가함.
- `°` 뒤에 `C`가 없는 앱 소스·테스트 표기는 0건임을 확인함.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 12개 모두 통과.
  - Debug APK 빌드 및 Android 에뮬레이터 설치 성공.
  - 360×800 Week 화면에서 `°C` 표기와 레이아웃을 확인했으며 RenderFlex/overflow/FATAL/Unhandled 오류 없음.

### Flutter 역할별 커스텀 폰트 적용
- `weather_care_app/assets/fonts`의 파일명을 기준으로 4개 폰트 패밀리를 등록함.
  - `SUITE`: Light~Heavy 7개 굵기를 앱 기본 폰트로 적용.
  - `ChosunCentennial`: 작은 보조문구, 얇은 설명, 9~12px 마이크로 텍스트에 적용.
  - `Mona`: 작은 도트 라벨에 적합한 `Mona10` Regular/Bold를 `TODAY/DETAIL/WEEK`, 날짜 눈썹 라벨과 추천 태그에 제한 적용.
  - `NeoHyundai`: L/R/B/EB/EBK를 등록하고 페이지·섹션 타이틀과 큰 브리핑 문구에 적용.
- Mona의 다른 도트 규격 파일은 향후 용도 선택을 위해 원본 자산으로 보존하되 현재 APK에는 실제 사용하는 `Mona10` 2개만 번들링함.
- 테마에 폰트 역할 상수와 `specialLabelStyle`, `microTextStyle`을 추가해 화면별 직접 지정이 흩어지지 않도록 함.
- 4개 역할 매핑을 검증하는 테마 회귀 테스트를 추가함.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 13개 모두 통과.
  - Debug APK 빌드 및 Android 에뮬레이터 설치 성공.
  - APK `FontManifest.json`에서 SUITE·ChosunCentennial·Mona·NeoHyundai 등록을 확인함.
  - 360×800 Main/Today/Week/Setting 시각 검증에서 한글 깨짐과 RenderFlex/overflow/FATAL/Unhandled/폰트 자산 오류 없음.

### NeoHyundai 타이틀 우선 적용 복구
- 사용자 재요청에 따라 페이지·섹션 타이틀, 큰 브리핑, 알림 카드 등 기존 타이틀 역할에 NeoHyundai를 다시 우선 적용함.
- SUITE는 앱 기본 본문 폰트로 유지하고, NeoHyundai는 명시적으로 지정된 큰 제목에만 사용함.
- `pubspec.yaml`에 NeoHyundai L/R/B/EB/EBK 등록을 복구함.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 13개 모두 통과.
  - Debug APK 빌드 성공 및 `FontManifest.json`에서 NeoHyundai 5개 굵기 포함 확인.
  - Android 에뮬레이터 Main 화면에서 타이틀 렌더링 정상, RenderFlex/overflow/FATAL/Unhandled/폰트 자산 오류 없음.

### 보조 폰트 및 타이틀 굵기 조정
- 작은 보조문구용 폰트를 `ChosunCentennial`에서 `ChosunSg`로 교체함.
- NeoHyundai 타이틀과 SUITE 중간 제목의 굵기를 600으로 낮춰 화면의 시각적 무게를 조정함.
- 실제 자산명 `ChosunSg.TTF`와 `pubspec.yaml`, 테마 상수, 회귀 테스트 참조를 일치시킴.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 13개 모두 통과.
  - Debug APK 빌드 성공 및 `FontManifest.json`에서 ChosunSg·NeoHyundai 등록 확인.

## 2026-08-21

### 날씨챙겨 앱 아이콘 1차 시안
- 기존 Soft Weather 팔레트에 맞춰 구름·해·비·눈을 하나의 기상 심볼로 조합한 앱 아이콘 시안을 생성함.
- 슬레이트 블루 전체 배경, 흰 구름, 따뜻한 노란 해, 파란 빗방울 2개, 흰 눈송이 1개로 구성해 작은 크기에서도 요소가 구분되도록 함.
- 1차 생성물의 원형 비네팅과 어두운 모서리를 제거하고, 정사각형 전체를 채우는 평면형 배경으로 보정함.
- 최종 마스터 시안: `weather_care_app/assets/branding/weather_care_app_icon_v1.png`
  - 1024×1024 PNG, RGB 불투명 배경, SHA-256 `8CB2D458994D41BA8A9DAADDB398C240B55ED41A1715775C192078A9856742E1`
- 기존 Android/iOS 런처 아이콘은 덮어쓰지 않았으며, 시안 확정 후 플랫폼별 아이콘 세트로 적용할 수 있음.

### iOS/Android 앱 아이콘 적용
- `weather_care_app/store/appIcon.png`를 최종 원본으로 Android 및 iOS 런처 아이콘을 생성함.
  - 원본은 1254×1254 PNG, RGB 불투명 이미지임.
- `flutter_launcher_icons` 설정을 `pubspec.yaml`에 추가해 같은 원본 경로로 아이콘 세트를 재생성할 수 있게 함.
- Android `mipmap-mdpi`부터 `mipmap-xxxhdpi`까지 48/72/96/144/192px `ic_launcher.png`를 교체함.
  - Main Manifest의 `android:icon="@mipmap/ic_launcher"` 연결과 Debug APK 내부의 5개 아이콘 포함을 확인함.
- iOS `AppIcon.appiconset`의 iPhone/iPad/App Store용 25개 슬롯을 생성함.
  - 모든 파일의 실제 픽셀 크기가 `Contents.json` 정의와 일치하고 투명도 없는 RGB 이미지임을 확인함.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter build apk --debug`: 성공.
  - Windows 환경에서는 iOS Xcode 빌드를 실행할 수 없어 AppIcon 세트 구조·크기·불투명도 검증으로 대체함.

### 앱 5개 탭 구성 기준 문서화
- 현재 Flutter 구현 코드를 기준으로 `docs/앱_탭_구성_현황.md`를 신규 작성함.
- 수정 진행 순서를 `Main → Today → Detail → Week → Setting`으로 정하고, 하단 내비게이션의 실제 표시 순서 및 Main 최초 진입 규칙을 별도로 기록함.
- 각 탭을 목적, 화면 구성 순서, 데이터와 동작, 운영 서버/기상청 직접 조회 상태, 현재 한계와 확인 포인트로 구분해 문서화함.
- 공통 `IndexedStack` 상태 유지, 새로고침 방식, 운영 서버 장애 시 UI 차이, Setting과 실제 날씨 조회 설정의 미연결 상태를 함께 기록함.
- 탭별 `현재 구성 문서화 → 요구사항 확정 → 구현 → 회귀 검증` 진행표를 추가해 이후 수정 시 계속 갱신할 수 있게 함.
- 코드 변경은 없으며 문서 작성만 수행해 별도 앱 빌드·테스트는 실행하지 않음.

### 전역 새로고침 흐름 및 Main 탭 1차 개편
- 하단 내비게이션의 선택/비선택 아이콘에 같은 색상을 명시해 탭 선택 시 아이콘 색상이 변하지 않도록 함.
- Main/Today/Detail/Week 헤더의 새로고침 버튼을 모두 제거함.
- Main, Today, Detail, Week, Setting과 날씨 미지원 상태 화면을 모두 `RefreshIndicator` + `AlwaysScrollableScrollPhysics` 구조로 맞춰 아래로 당겨 새로고침할 수 있게 함.
- 운영 서버 실패 흐름을 자동 Fallback에서 사용자 선택 방식으로 변경함.
  - 운영 서버 Today/Weekly를 먼저 조회함.
  - 실패 시 준비물 추천과 TODO에는 운영 서버가 필요하다는 안내와 함께 `운영 서버 다시 시도`를 우선 권유함.
  - 보조 선택지 `단기예보만 보기`를 선택할 때만 앱이 기상청 단기예보를 직접 조회함.
  - 날씨 미지원 화면의 별도 다시 시도 버튼은 제거하고 당겨서 새로고침 안내로 교체함.
- Main 헤더:
  - 앞 아이콘을 제거함.
  - 타이틀을 `오늘 {지역명}이라면 확인하세요`로 변경함.
- Main 상단 날씨 카드:
  - 전체 높이 비중과 내부 글자 크기를 줄이고 TODO 대시보드 비중을 확대함.
  - 브리핑을 최대 3줄로 확장함.
  - 현재 기온의 크기·굵기를 줄이고 10글자 이내 날씨 표현과 하늘 상태 아이콘을 같은 행에 배치함.
  - 다음 행에 `체감온도`, 10글자 이내 비유, 실제 체감온도 또는 미지원 상태를 표시함.
  - 습도/풍속/자외선 지표를 유지함.
- Main `생활 날씨`를 `오늘의 TODO`로 개편함.
  - 타이틀 앞 아이콘을 `TODAY` 라벨로 교체함.
  - 부제를 `오늘 날씨에 해야할 일들이에요`로 변경함.
  - 각 TODO를 아이콘 + 제목/설명 Row로 만들고 3개 항목을 세로로 배치함.
  - 서버 응답이 항상 최소 3개 생활 문구를 제공하도록 `DAILY_WEATHER_CHECK`, `DAILY_HYDRATION`, `FLEXIBLE_DAY_PLAN` 기본 TODO 타입을 추가함.
  - 구버전 운영 서버가 3개 미만을 반환해도 앱에서 부족한 TODO 슬롯을 보완함.
- 서버 브리핑은 온도 숫자와 원시 하늘 상태를 직접 나열하지 않고, 시간대와 우산·그늘·옷깃·발걸음 등을 사용한 간접적이고 감성적인 규칙형 문구로 교체함.
- `docs/앱_탭_구성_현황.md`의 전역 정책, Main 구성, 체크리스트와 진행표를 현재 구현에 맞게 갱신함.
- 검증 결과:
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 16개 모두 통과.
  - 앱 Debug APK 빌드 및 Android 17/API 37 에뮬레이터 설치 성공.
  - 360×800 Main 화면에서 새 카드 비율, TODO 3행, 동일 탭 아이콘 색상과 오버플로 없음 확인.
  - 앱 PID 기준 RenderFlex/overflow/Unhandled/FATAL 로그 없음.
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 Vitest: 4파일 17개 통과.
  - `npx wrangler deploy --dry-run`: D1 바인딩을 포함해 통과.
- 운영 반영 주의:
  - 새 감성 브리핑과 서버 기본 TODO 3개 보장은 Worker를 재배포해야 운영 응답에 적용됨.
  - 이번 작업에서는 운영 Worker 배포를 수행하지 않음.

### Main TODO 중요도 및 생활 지표 위험도 표시
- Main 상단 지표를 습도/풍속/자외선/미세먼지 4개로 확장함.
  - PM2.5가 있으면 `초미세먼지`로 우선 표시하고, 없으면 PM10 `미세먼지`로 대체함.
  - 두 값이 모두 없으면 `--`와 중립 색상을 표시함.
  - 양호는 슬레이트 블루, 주의는 앰버, 위험은 레드로 수치와 아이콘 색을 함께 변경함.
  - PM2.5는 36/76, PM10은 81/151㎍/㎥ 경계를 사용하며 에어코리아 등급을 기준으로 함.
  - 습도는 35/70/80%, 풍속은 6/9m/s, 자외선은 6/8을 경계로 사용함.
- 4개 지표가 360px 폭에 들어가도록 아이콘-수치-라벨을 세로형으로 재배치함.
- 날씨 표현과 체감 비유 Row는 남은 폭을 `Expanded`로 제한하고 말줄임 처리해 좁은 화면의 가로 오버플로를 제거함.
- TODO 생활 문구 응답에 서버 판단 `score`를 추가하고 Flutter 모델까지 전달함.
  - 우산/양산/겉옷/마스크/물/선크림 계열 TODO만 중요도 색상을 적용함.
  - 80점 이상은 앰버, 60~79점은 블루, 60점 미만은 옅은 블루 배경·아이콘을 사용함.
  - 중요도 색상이 바뀌는 모든 TODO 카드에서 테두리를 제거해 동일한 무테 스타일을 유지함.
  - 빨래/환기/일정 같은 일반 행동 TODO는 중립 배경을 유지함.
  - 구버전 서버 또는 기본 TODO의 누락 점수는 0점으로 안전하게 파싱함.
- Main 대시보드 타이틀/부제를 확정 문구인 `오늘의 TODO`, `오늘 날씨에 해야할 일들이에요`로 맞춤.
- `docs/메인_브리핑_문구_기획.md`를 추가함.
  - 브리핑을 사실 재진술이 아닌 `대표 장면 → 말투 계열 → 검수된 문구` 구조로 정의함.
  - 직접 날씨·기온·수치 금칙, 날짜/지역 기반 결정적 선택, 7일 중복 방지, 장면별 최소 6개 문구, 내부 `sceneCode/templateId/triggerFacts` 기록을 제안함.
  - 이번 작업에서는 기획만 확정했으며 기존 규칙형 브리핑을 장면 카탈로그로 전환하는 서버 구현은 다음 단계임.
- `docs/앱_탭_구성_현황.md`의 Main 지표, 위험도 임계값, TODO 점수 색상, 브리핑 후속 항목을 갱신함.
- 검증 결과:
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 18개 모두 통과. 360×800 레이아웃, PM2.5 위험색, 서버 점수 파싱, 챙길 TODO 점수별 배경색을 포함함.
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 Vitest: 4파일 17개 통과. 생활 문구의 원본 점수 전달과 기본 TODO 0점 보완을 포함함.
- 운영 반영 주의:
  - 생활 문구 `score` 필드를 운영 앱이 받으려면 Worker 재배포가 필요함.
  - 이번 작업에서는 운영 Worker 배포를 수행하지 않음.

### 서버 한 줄 브리핑 20개 템플릿·슬롯 카탈로그
- 기존 조건별 고정 문장 1개 방식의 `weatherBrief.ts`를 장면 선택기와 슬롯 카탈로그 구조로 교체함.
- 대표 장면 7개를 우선순위로 선택함.
  - `CAREFUL_STEPS`, `WET_TRAVEL`, `MASK_READY`, `SHADE_BREAK`, `LAYER_READY`, `STEADY_PACE`, `DAILY_RHYTHM`
- `weatherBriefCatalog.ts`에 완성형 템플릿을 정확히 20개 구성함.
  - 각 템플릿은 `시간대 + 행동/준비 + 생활 효과` 3개 슬롯을 사용함.
  - 공통 시간 슬롯 1개와 장면별 행동·효과 슬롯 14개로 총 15개 슬롯 풀을 구성함.
  - 모든 슬롯 풀은 중복 없는 후보를 정확히 10개씩 가짐.
  - 이론상 전체 카탈로그에서 최대 20,000개 조합을 만들 수 있으나 시간 슬롯은 실제 발생 시각으로 고정해 사실과 맞지 않는 시간 표현을 방지함.
- 직접적인 기온·날씨·수치 표현 없이 우산/마스크/그늘/겉옷/발걸음 같은 생활 사물과 행동으로 표현함.
- 현재값과 다음 24시간 예보에서 대표 장면을 선택하고, Today API가 `nx:ny` 지역 키를 브리핑 생성기에 전달하도록 변경함.
- 날짜·지역·장면 기반의 결정적 순환을 적용함.
  - 같은 날짜/지역/장면에서 새로고침하면 같은 문장을 반환함.
  - 템플릿과 행동·효과 슬롯을 날짜별로 함께 순환해 같은 완성 문장이 7일 안에 반복되지 않도록 함.
- 모든 슬롯의 최장 후보를 조합해도 47자를 넘지 않도록 문구를 압축해 Main 최대 3줄 안에 들어가도록 함.
- `buildWeatherBriefResult()`가 `text`, `scene`, `templateId`, 실제 `slots`, `catalogVersion`을 반환하고, 기존 Today API 계약에는 `text`만 `brief`로 전달함.
- `docs/메인_브리핑_문구_기획.md`와 `docs/앱_탭_구성_현황.md`를 실제 구현 수량·장면·반복 규칙에 맞춰 갱신함.
- 검증 결과:
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 Vitest: 4파일 22개 통과.
  - 브리핑 테스트는 템플릿 20개, 장면 7개, 슬롯별 후보 10개, 후보 중복 없음, 금칙어 없음, 미해결 슬롯 없음, 최장 47자, 동일일 안정성, 7일 문장 무반복을 포함함.
- 운영 반영 주의:
  - 새 브리핑 카탈로그를 운영 API에 반영하려면 Worker 재배포가 필요함.
  - 이번 작업에서는 운영 Worker 배포를 수행하지 않음.

### Main 대시보드 무테 스타일 및 현재 문구 동기화
- 중요도에 따른 TODO 카드의 배경색과 아이콘 색은 유지하고, 모든 상태의 테두리를 제거해 동일한 무테 스타일로 통일함.
- 높음·중간·중립 카드의 `BoxDecoration.border` 값이 모두 `null`인지 위젯 테스트로 고정함.
- 현재 Main 구현을 그대로 보존하며 헤더를 `{지역명}이라면 확인하세요`, 대시보드를 `Check List` / `오늘 날씨에 체크해야할 일들이에요`로 문서와 테스트에 동기화함.
- 검증 결과:
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 18개 모두 통과.
  - 앱 `flutter build apk --debug`: `app-debug.apk` 생성 성공.
  - 서버 `npx tsc --noEmit`: 통과.
  - 서버 Vitest: 4파일 22개 모두 통과.

### 운영 자외선·미세먼지 결측 진단
- 사용자가 수정한 Main 헤더 부제 `화면을 아래로 당기면 최신 날씨 정보를 가져와요`는 그대로 보존함.
- 운영 `/api/v1/weather/today`를 수원(60,121)과 서울(60,127)에서 조회했으며 둘 다 200 응답이지만 `current` 내 `uvIndex`, `pm10`, `pm25`가 필드 자체로 없음.
- 각 응답의 `hourly` 48개에도 자외선·PM10·PM2.5가 포함된 슬롯은 0개임.
- 원인은 앱 파싱이 아니라 서버 Provider 미구현임.
  - Today API는 `KmaWeatherProvider` 하나만 호출함.
  - 해당 Provider는 기상청 단기예보의 `TMP, REH, WSD, VEC, POP, PTY, PCP, SNO, SKY`만 정규화하며 `uvIndex`, `pm10`, `pm25`를 생성하지 않음.
  - `AirQualityProvider` 인터페이스는 존재하지만 구현체와 Today API 주입·병합 로직이 없음.
  - `ServerEnv`와 운영 비밀값 안내도 `KMA_SERVICE_KEY`만 정의해 대기질 Provider용 설정이 없음.
- 앱의 `CurrentWeather.fromJson()`과 Main 지표 UI는 세 필드를 정상 파싱·표시하므로 서버가 값을 제공하면 추가 앱 계약 변경 없이 표시 가능함.
- 이번 작업은 진단만 수행했으며 Provider 구현·운영 secret 등록·Worker 배포는 수행하지 않음.

### 운영 자외선·미세먼지 Provider 구현 및 전체 문서 동기화
- 기존 진단에서 확인한 환경 데이터 결측을 실제 서버 기능으로 구현함.
  - `KmaUvProvider`: 기상청 생활기상지수 V5 `getUVIdxV5`의 `h0`~`h75` 값을 3시간 간격 자외선 예측으로 정규화함.
  - `AirKoreaAirQualityProvider`: 에어코리아 측정소별 실시간 자료에서 PM10·PM2.5·오존과 등급을 정규화함.
  - 수원 `60:121`은 자외선 행정코드 `4111000000`·인계동 측정소, 서울 `60:127`은 `1100000000`·종로구 측정소로 매핑함.
- Today API가 단기예보와 환경 Provider를 병렬 조회한 뒤 병합하도록 변경함.
  - 자외선은 유효한 3시간 구간의 `current`와 `hourly`에 반영함.
  - 대기질은 실시간 관측을 미래 예보로 오해하지 않도록 `current`와 첫 `hourly`에만 반영함.
  - `environmentalSources`에 `AVAILABLE`, `CACHED`, `STALE`, `UNAVAILABLE`, `UNSUPPORTED_REGION`을 독립적으로 반환함.
  - 환경 Provider 한쪽 또는 양쪽이 실패해도 단기예보가 정상이면 Today 응답 전체를 실패시키지 않음.
- 기존 D1 `weather_cache`를 이용해 자외선 2시간·대기질 30분 fresh 캐시를 적용함. 새 조회 실패 시 자외선 최대 8시간, 대기질 최대 3시간 값만 `STALE`로 허용함.
- `KMA_SERVICE_KEY`를 세 서비스가 함께 사용하는 일반 인증키로 유지하고 Worker 필수 secret 및 observability 설정을 명시함. 비밀값은 로그나 저장소에 추가하지 않음.
- 현재 앱의 Main 부제 `화면을 아래로 당기면 최신 날씨 정보를 가져와요`를 보존함. 앱은 이미 `uvIndex`, `pm10`, `pm25` 결측·위험색 표시 계약을 지원하므로 별도 JSON 모델 변경이 필요하지 않음.
- 현재 기준에 맞춰 루트·앱·서버 README, `docs/앱_탭_구성_현황.md`, `docs/메인_브리핑_문구_기획.md`를 갱신함.
- DOCX 4종을 2026-08-21 기준으로 갱신함.
  - 앱/서버 개발명세와 문구 카탈로그 v1.0/v1.1에 환경 Provider 원본 시간, 병합 범위, 결측·캐시 정책, 운영 승인 조건을 추가함.
  - `scripts/update_docx_specs.py`로 날짜·현재 새로고침 설명·환경 부록 표 서식·접근성 속성 보정을 반복 적용할 수 있게 함.
  - 문서 제목 메타데이터, 모든 표의 반복 머리글, 빈 셀 부재를 검사함.
  - Microsoft Word 최종 렌더 기준 서버 17쪽, v1.0 17쪽, v1.1 24쪽, 앱 14쪽이며 전체 페이지와 환경 부록에서 잘림·의도치 않은 빈 페이지가 없음을 확인함.
- 검증 결과:
  - 서버 `npm test`: 7파일 29개 모두 통과.
  - 서버 `npx tsc --noEmit`: 통과.
  - `wrangler types --check`, `wrangler deploy --dry-run`, `wrangler check startup`: 모두 통과. 실제 배포는 수행하지 않음.
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 18개 모두 통과.
  - 앱 `flutter build apk --debug`: 성공.
- 운영 반영 전 외부 전제조건:
  - 공공데이터포털 계정에서 기상청 단기예보, 생활기상지수(5.0), 에어코리아 대기오염정보를 각각 활용신청·승인해야 함.
  - 로컬에 있던 일반 인증키로 세 API를 실호출했을 때 `SERVICE_KEY_IS_NOT_REGISTERED_ERROR`가 반환되어 실제 값의 종단간 검증은 승인된 키가 준비된 뒤 가능함.
  - 승인된 키를 Worker secret `KMA_SERVICE_KEY`에 등록하고 Worker를 배포한 뒤 수원·서울 Today 응답의 `current.uvIndex`, `current.pm10`, `current.pm25`, `environmentalSources`를 운영 스모크 테스트해야 함.

### 공공데이터포털 서비스 키 입력 위치 확인
- 현재 서버 구현은 단기예보·생활기상지수(5.0)·에어코리아에 공공데이터포털 일반 인증키 하나를 공유하며 환경변수 이름은 `KMA_SERVICE_KEY`임.
- 운영 서버는 `weather_care_server`에서 `npx wrangler secret put KMA_SERVICE_KEY`로 대화형 입력한 뒤 `npx wrangler deploy`해야 함. 운영 Worker에는 해당 Secret 이름이 이미 등록되어 있음.
- 로컬 Worker는 Git 제외 파일 `weather_care_server/.dev.vars`에 `KMA_SERVICE_KEY=...`로 입력함.
- 앱의 Git 제외 파일 `weather_care_app/config/kma.config.json`에도 같은 필드가 있지만 운영 서버 장애 시 앱의 단기예보 직접 조회에만 사용하며 자외선·대기질 Provider에는 사용하지 않음.
- 세 API 페이지에서 동일 계정의 일반 인증키를 사용하더라도 각 서비스를 별도로 활용신청·승인해야 함. 운영 로그에서 두 환경 Provider가 모두 실패하고 있어 Secret 위치 누락보다는 서비스 승인·키 상태 확인이 우선임.

### Main 체감온도 표현 기준 확인
- Main의 감성 체감 표현은 앱 내부 고정 구간으로 `33℃ 이상=한낮의 온실`, `28~32.9℃=따뜻한 햇살`, `20~27.9℃=가벼운 바람`, `10~19.9℃=선선한 산책길`, `0~9.9℃=차가운 공기`, `0℃ 미만=얼어붙은 아침`임.
- 체감온도 31.4℃는 현재 `28~32.9℃` 구간이어서 `따뜻한 햇살`로 표시됨.
- 이 문구 구간은 공식 위험 기준이 아닌 UI 감성 표현이며 서버의 더위 Rule은 체감온도 33℃부터 판단하므로, 28℃ 이상을 단순히 `따뜻한`으로 표현하는 것은 사용자 체감상 과도하게 온화할 수 있음. 이번 확인에서는 코드를 변경하지 않음.
- Git 이력상 이 구간은 `950de88` Main 개편 커밋에서 체감 비유 UI와 함께 처음 추가됐으며, 명세·코드·커밋에 기상청·보건 기준 등의 근거 출처는 없음. 33℃는 서버 더위 Rule과 숫자가 같지만 나머지 28/20/10/0℃ 경계는 단순 UX 구간이고, `햇살`·`바람` 표현도 실제 일사량이나 풍속을 입력으로 사용하지 않음.

### 체감온도·온열감 표현 기준 리서치
- 현재 서버의 여름 체감값은 미국 NWS Rothfusz Heat Index 회귀식을 사용하며, 기상청 여름철 체감온도·한국인 PT(Perceived Temperature)·UTCI와는 서로 다른 지수임. 같은 숫자라도 다른 지수의 임계값을 직접 적용하면 안 됨.
- 국립기상과학원·서울대 연구(Kang et al., 2022, DOI `10.1007/s00484-022-02261-x`)가 서울 거주 한국인 19명의 고온다습 환경 실험으로 도출한 PT 구간은 `20℃ 미만=쾌적 가능`, `20~27.9=약간 따뜻함`, `28~35.9=따뜻함`, `36~42.9=더움`, `43 이상=매우 더움`임. 표본이 젊은 성인 중심이고 PT 전용 구간이라는 한계가 있음.
- 한국어 온열감 연구(Lee et al., 2009, DOI `10.2114/jpa2.28.37`; Kim et al., 2022, DOI `10.1016/j.buildenv.2022.109343`)는 한국어 `따뜻하다`가 열감보다 편안하고 긍정적인 상태를 강하게 함축해 영어 `warm`의 직역어로 쓰면 의미 편향이 생긴다고 보고함. 여름 앱 문구는 `따뜻함`보다 `조금 더움/더움/매우 더움`이 적합함.
- 기상청은 2022-06-02부터 여름 체감온도에 기온·습구온도 기반 별도 산식을 사용함. 폭염 기준은 일 최고 체감온도 33℃ 이상 2일=주의보, 35℃ 이상 2일=경보, 38℃ 이상 1일 등의 조건=중대경보이며, 이는 주관적 온열감이 아니라 건강·재난 위험 기준임.
- UTCI는 기온·습도·풍속·복사환경을 반영한 야외 열스트레스 지수이며 `26~31.9=중간 열스트레스`, `32~37.9=강한 열스트레스`로 구분함. 현재 예보에는 평균복사온도 입력이 없어 정확한 UTCI 계산을 위해 추가 데이터가 필요함.
- 단기 적용 권고는 현재 Heat Index 값을 유지할 경우 NWS 위험 구간과 행동 문구를 사용하고, 한국인 주관적 온열감 문구를 쓰려면 PT 또는 KMA 체감온도로 산식부터 통일하는 것임. 체감값 31.4를 현 구조에서 `따뜻한 햇살`로 표현하는 것은 연구 근거와 한국어 어감 모두에 맞지 않음.

### 한국인 PT·기상청 기준 체감온도 적용
- 서버의 미국 NWS Rothfusz Heat Index를 기상청 공식 계절별 체감온도 산식으로 교체함.
  - 5~9월: 기온·상대습도·Stull 습구온도 기반 기상청 여름 산식.
  - 10~익년 4월: 기온 10℃ 이하·풍속 1.3m/s 이상일 때 기상청 겨울 풍속냉각 산식.
  - 조건 또는 필수 입력이 없으면 기온을 소수점 첫째 자리로 반환함.
- 운영 서버 장애 시 앱이 직접 조회하는 단기예보에도 동일 산식을 구현해 `current`와 `hourly` 체감온도를 제공하도록 변경함.
- Main 체감 표현을 한국인 PT 감각 경계와 기상청 33/35/38℃ 위험값의 조합으로 교체함.
  - `20~27.9=조금 더움`, `28~32.9=더움`, `33~34.9=더위 주의`, `35~37.9=더위 경계`, `38 이상=위험한 더위`.
  - 체감 31.4℃는 `더움`으로 표시함.
  - 단일 시점 값이 공식 특보 발효로 오해되지 않도록 `폭염주의보/폭염경보` 명칭은 쓰지 않음.
- 한국인 대상 추가 기준을 조사해 `docs/체감온도_표현_기준.md`에 정리함.
  - 2025 서울·수원 야외조사: PT는 주관한서감 R² 0.991, 기상청 폭염체감온도는 온열쾌적감 R² 0.986.
  - 서울·대구 성인 남성 400명: 지역 순응에 따라 야외 온열 경계 약 1℃ 차이.
  - 수원 시민과학 조사와 국내 고령자·의료자료: 공간·연령·취약성에 따른 별도 보호 필요.
  - 서울 온열질환 자료: 체감온도 36℃ 초과에서 비선형 위험 증가.
  - 서울 사무실 연구: 실내 SET* 중립 25.3℃·쾌적 23.8~26.8℃이나 야외 기준에는 미적용.
- 문서 동기화: 루트/서버 README, `docs/앱_탭_구성_현황.md`, 신규 근거 문서를 갱신함.
- 검증 결과:
  - 서버 `npm test`: 7파일 30개 모두 통과.
  - 서버 `npx tsc --noEmit`: 통과.
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 20개 모두 통과.
- 기존 사용자 삭제 상태인 `weather_care_app/config/kma.config.example.json`은 복원하거나 변경하지 않음.
- Worker 운영 재배포와 앱 배포는 수행하지 않았으며, 배포 전후 같은 입력의 체감값 스모크 테스트가 필요함.

### 체감온도 외 수치 기준 전수 점검
- 화면 간격·폰트 같은 레이아웃 수치를 제외하고 사용자 색상·문구·추천·데이터 신선도에 영향을 주는 임계값을 점검함.
- 주요 서버 판단값은 `ruleConfig.ts`의 강수, 적설, UV, 더위, 추위, 바람, 대기질, 빨래, 습도와 `weatherRuleEngine.ts`의 시간대·해제·급강하·수면불편·환기 조건임.
- 앱 자체 표시값은 Main의 습도/풍속/UV/PM 위험색, TODO 점수 60/80, Detail의 강수확률 40% 강조임.
- 별도 하드코딩 기준도 확인함.
  - 브리핑: 강수 50%, 체감 28/8℃, UV 6, 풍속 6m/s, PM2.5 36·PM10 81.
  - 외출 적합: 체감 10~30℃, UV 6 미만, 풍속 1~5m/s.
  - 결빙 추정: 젖은 상태에서 0℃ 이하. 서리성 아침: 5~9시, 0℃ 이하, 습도 80% 이상 또는 직전 습윤.
  - 환경 캐시: UV fresh 2시간/stale 8시간, 대기질 fresh 30분/stale 3시간.
- 우선 정합화가 필요한 불일치를 확인함.
  - PM2.5: Main 색상은 36/76인데 서버 추천은 55 이상.
  - 비: 엔진·Detail은 40%인데 브리핑은 50%.
  - 추위: 엔진은 기온 12℃/체감 10℃인데 브리핑은 체감 8℃.
  - 더위: 브리핑 장면은 체감 28℃, 추천은 33℃이며 의도 구분이 코드에 명시되지 않음.
  - Week 추천은 기상청 체감온도가 아니라 일 최고기온을 `apparentTemperature`로 대입함.
- 조사·정비 우선순위는 `대기질 정합화 → 강수·적설 → 추위·일교차·급강하 → 바람·습도 → 빨래·환기·외출·수면 → 점수/시간 슬롯`으로 판단함.
- 이번 작업은 진단만 수행했으며 코드·기준 문서는 변경하지 않음.

### 수치 기준별 출력 확정용 마스터 목록 정리
- 후속 협의에서 항목을 바로 지칭할 수 있도록 날씨 판단 `W`, 생활 행동 `L`, 브리핑 `B`, 화면 표시 `U`, 점수·운영 `S/O` 그룹으로 구분함.
- 각 항목에서 확정해야 할 값은 `입력 임계값`, `지속/해제`, `내부 Fact`, `생활 TODO`, `준비물`, `브리핑 장면`, `색상·점수`, `결측 처리`의 8종임.
- 현재 연결 구조를 재확인함.
  - WeatherRuleFact 22종, LifestyleInsight 카탈로그 36종, 준비물 Recommendation 7종.
  - 브리핑 장면은 눈→비→대기질→더위/UV→추위→바람→일상 순으로 첫 조건을 선택함.
  - Main TODO는 점수순 상위 3개이며 60/80점으로 챙길 항목 색상을 구분함.
- 현재 규칙이 생성하지 않는 카탈로그 항목을 확인함: 반려동물 산책, 빨래 회수, 우산 건조, 알레르기, 호흡기, 동파 주의. 세차는 미루기 출력만 생성되고 좋은 날 출력은 생성되지 않음.
- 출력 연결 오류 후보를 확인함.
  - `LAUNDRY_GOOD`이 준비물 `PARASOL`로 변환됨.
  - 일반적인 눈 예상도 준비물 제목 `폭설 주의`로 변환됨.
  - 대기질 등급만 `나쁨`이고 PM 수치가 임계값 미만이면 `AIR_QUALITY_BAD` Fact는 생기지만 마스크 Insight는 생기지 않음.
  - Week는 최고기온을 체감온도로 대입해 추천을 계산함.
- 이번 작업은 목록·연결 진단만 수행했으며 제품 코드와 기준 문서는 변경하지 않음.

### 근거 문서 선정 대상 항목으로 범위 재정의
- 사용자는 임계값을 하나씩 직접 정하려는 것이 아니라, 각 판단에 적용할 공식 문서·행정 기준·한국인 대상 연구를 선정하려는 것임.
- 후속 응답과 조사에서는 현재 코드 숫자·출력 문구보다 `근거를 정해야 하는 항목명`을 먼저 제시해야 함.
- 대상은 온열, 강수·적설, 바람·습도, 대기환경, 생활 행동, 출력 운영 기준으로 구분함.
- 이번 작업은 범위 재정의와 항목 목록 제공만 수행했으며 제품 코드는 변경하지 않음.

### 수치 기준 근거자료 선정 항목 문서화
- 마지막 협의 목록을 `docs/수치_기준_근거자료_선정_항목.md`로 신규 문서화함.
- 기온·체감, 강수·적설, 바람·습도, 자외선·대기환경, 생활 행동, 출력·운영의 6개 범주를 수록함.
- 구체적인 임계값을 확정하지 않고 각 항목에 적용할 공식 문서·행정 기준·연구자료를 선정하는 목적임을 명시함.
- 후속 조사 결과를 일관되게 기록할 수 있도록 우선 기준, 보조 기준, 한국인 근거, 적용 대상·범위, 채택 상태, 예외·한계와 연결 기능 기록 양식을 추가함.
- 제품 코드는 변경하지 않았으며 기존 사용자 삭제 상태인 `weather_care_app/config/kma.config.example.json`도 건드리지 않음.

### 판단·출력 연결 오류 우선 정비
- 야간 구간을 `21:00~04:59`로 바로잡아 00시를 포함함. `git blame`과 도입 커밋 `0d38b420`에는 00시를 제외할 기획 근거가 없었으며, `1~4` 조건을 작성하면서 자정 경계를 빠뜨린 구현 누락으로 확인함.
- 준비물 연결을 바로잡음.
  - `LAUNDRY_GOOD`은 생활 TODO로만 유지하고 양산 준비물로 변환하지 않음.
  - 일반적인 눈 예상은 이동 주의 TODO로 유지하되, `HEAVY_SNOW` Fact가 있을 때만 `폭설 주의` 준비물을 생성함.
  - PM 수치가 낮더라도 에어코리아 통합등급이 `Bad` 또는 `Very Bad`이면 마스크를 생성하고 근거 필드에 `airQualityGrade`를 기록함.
- Week 준비물 계산은 같은 날짜의 시간대별 예보와 기상청 체감온도를 사용함. 시간대별 값이 없는 날짜의 일 최고기온은 체감온도로 대입하지 않음.
- PM 경계를 화면·서버 추천·브리핑 모두 PM2.5 36㎍/㎥, PM10 81㎍/㎥부터 나쁨으로 통일함.
- 강수 가능성 경계를 엔진·Detail·브리핑 모두 40%로 통일함.
- 더위 수치의 코드 역할을 이름으로 분리함.
  - 28℃: 감각·브리핑 장면
  - 33℃: 준비 행동
  - 35℃: 즉시 행동
  - 38℃: Main 위험 표현
  - 31℃ 미만: 지속 판단 해제
- 아직 수치 규칙이 없는 출력 8종은 임의 생성하지 않음. 기존 자료만으로 만들 수 있는 항목, 사용자 상태 저장이 필요한 항목, 새 외부 데이터가 필요한 항목으로 나눠 후속 설계해야 함.
- 문서 동기화: `docs/체감온도_표현_기준.md`, `docs/앱_탭_구성_현황.md`에 역할과 연결 규칙을 반영함.
- 검증 결과:
  - 서버 `npm test`: 8파일 37개 모두 통과.
  - 서버 `npx tsc --noEmit`: 통과.
  - 앱 `flutter analyze`: 이슈 없음.
  - 앱 `flutter test`: 20개 모두 통과.
- 기존 사용자 삭제 상태인 `weather_care_app/config/kma.config.example.json`은 복원하거나 변경하지 않음.
- Worker 배포와 커밋은 수행하지 않음.

### 현재 미연결 출력 8종의 근거 선정 항목 추가
- `docs/수치_기준_근거자료_선정_항목.md`에 현재 생성 규칙이 없는 출력 8종을 별도 절로 추가함.
  - 반려동물 산책 시간
  - 빨래 걷기 마감시간
  - 우산 말리기 알림
  - 꽃가루·알레르기 주의
  - 호흡기 주의
  - 수도관 동파 주의
  - 세차하기 좋은 날
  - 오존 자체 위험 안내
- 항목별로 선정해야 할 공식·연구 근거 범위와 프로필, 사용자 상태, 외부 Provider 등 추가 적용 조건을 기록함.
- 현재 데이터로 가능한 항목, 사용자 상태·프로필이 필요한 항목, 새 외부 데이터가 필요한 항목으로 구분함.
- 임계값이나 출력 규칙은 아직 확정하거나 제품 코드에 적용하지 않음.
- 문서 변경만 수행해 코드 테스트는 재실행하지 않음.

### 누적 변경사항 커밋
- 기상청 계절별 체감온도 산식 통일, 판단·출력 연결 오류 정비, 수치 기준 근거자료 선정 문서를 현재 작업트리 기준으로 함께 커밋함.
- 커밋 전 최종 검증 기준은 서버 테스트 37개·앱 테스트 20개 통과, TypeScript 검사와 `flutter analyze` 통과임.
- 사용자가 기존에 스테이징한 `weather_care_app/config/kma.config.example.json` 삭제도 현재 수정사항에 포함해 그대로 반영함.

### 앱 탭 구성 문서 요구사항 구현 및 날씨 아이콘 통일
- `docs/앱_탭_구성_현황.md`의 직접 수정사항을 Today·Detail·Week·Setting UI와 서버 응답 생성 코드에 반영하고, 문서를 현재 구현 기준의 상태표·아이콘 매핑표·검증 기록 구조로 정리함.
- Main·Detail·Week가 공통 `WeatherConditionIcon`을 사용하도록 통일함. 비는 우산 대신 구름+빗방울로 표시하고, 서버의 맑음·구름 많음·흐림·빗방울·비·소나기·눈날림·눈·약한 혼합 강수·일반 혼합 강수를 모두 서로 다른 형태로 구분함. 우산은 준비물/알림 의미에만 유지함.
- Today 타임라인을 3시간 간격 5개 시점(총 12시간)으로 확대하고 추천에 맞춘 `~하기 좋은 때` 문구를 생성하도록 서버를 변경함.
- Detail의 헤더와 현재 카드, 챙김 근거, 타임라인 상세를 재구성함. 지표 기준 팝업, 추천별 수치 근거, 시간별 UV/미세먼지 태그, 강수·눈·33℃ 이상 행 강조를 추가함.
- Week의 비/눈 예보 일수 집계, 날짜별 준비물 최대 3개, `준비물 없음` 문구를 적용함.
- Setting에서 전체 알림을 끄면 알림 시간도 비활성화되도록 하고 폭우·폭설·폭염·한파·소나기/약한 비·오늘 날씨 스위치와 실제 데이터 출처를 표시함. 새 설정값은 아직 화면 메모리 전용이며 서버 저장/알림 스케줄러에는 연결하지 않음.
- 챙겨요 항목은 현재 서버 추천 타입과 일치하는 우산·양산·겉옷·마스크·물·선크림 6종을 유지함. 우비·장화·장갑·모자는 서버 타입과 판단 기준이 생길 때 추가 검토함.
- 소나기·이슬비·가랑비는 하나의 설정 아래 관리하되 같은 현상으로 합치지 않고, 실제 알림 연동 시 Provider의 현상명과 강도를 보존한다는 원칙을 문서에 명시함.
- 검증: `flutter analyze`, Flutter 테스트 25개, `npx tsc --noEmit`, 서버 테스트 38개 통과. Android 에뮬레이터 1080×2400에서 5개 탭과 강수/구름 조합 아이콘, 상세 스크롤, 설정 하단을 확인함.
- 운영 반영 시 Today/Week 서버 변경을 포함한 Worker 재배포가 필요함. 배포는 수행하지 않음.
