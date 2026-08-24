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

### 수치 기준 선정 대화 진행 방식
- `docs/수치_기준_근거자료_선정_항목.md`의 항목을 한 번에 하나씩 사용자에게 질문함.
- 각 질문에는 항목명만 제시하지 않고 항목의 의미, 선택 가능한 근거 방향과 실제 앱 출력 표현 예시를 함께 제공함.
- 사용자가 선택한 결과는 해당 문서에 순차 기록하고 다음 항목으로 진행함.

### 기준 선정 2-1: 실제 기온 구간 표현
- 사용자가 사실·감각·공식 출력을 분리하고, 감각 표현에는 한국인이 실제 응답한 연구자료를 적용하는 방향을 채택함.
- `docs/수치_기준_근거자료_선정_항목.md`에 첫 채택 결과를 기록함.
  - 사실: 기상청 `TMP` 숫자와 최저·최고기온만 표시하고 실제 기온에 임의 감각 구간을 붙이지 않음.
  - 감각: 한국인 19명 환경실험(Kang et al., 2022), 서울·수원 시민 120명 야외 설문(Shin et al., 2025), 한국어 온열감 어휘 설문을 우선 근거로 선정함.
  - 공식: 기상청이 실제 발표한 특보 또는 공식 조건을 별도 출력함.
- 한국형 PT의 경계를 현재 기상청 체감온도에 그대로 옮기면 지수 불일치가 생기므로, 감각 수치 경계는 다음 항목 `체감온도 산출식` 결정과 연동하도록 보류함.
- 여름 표현은 `조금 더움/더움/매우 더움`을 사용하고 `따뜻함`을 고온 위험 표현으로 사용하지 않음.
- 한국인 야외 한랭 감각의 충분한 현장 근거는 아직 선정하지 않았으므로 임의의 한랭 구간을 새로 확정하지 않음.
- 문서만 변경했으며 제품 코드, 테스트, 배포와 커밋은 수행하지 않음.

### 기준 선정 2-2: 체감온도 산출식
- 사용자가 기상청 체감온도와 한국형 PT를 역할별로 함께 사용하는 방식을 채택함.
- `docs/수치_기준_근거자료_선정_항목.md`에 두 번째 채택 결과를 기록함.
  - `airTemperature`: 실제 기온 사실
  - `kmaApparentTemperature`: 기상청 공식 위험·행동 기준
  - `koreanPerceivedTemperature`: 한국인 감각 문구 선택용 내부 값
  - `officialWeatherAdvisory`: 실제 발표된 공식 특보
- PT 입력이 부족할 때 기상청 체감온도에 PT 경계를 대신 적용하지 않고 `체감 판단 미지원`으로 처리하기로 함.
- 현재 서버·앱의 단일 `apparentTemperature` 계약을 즉시 변경하지는 않았으며, 한국형 PT 입력 Provider와 산식 검증을 포함한 후속 구현 대상으로 기록함.
- 문서만 변경했으며 코드 테스트, 배포와 커밋은 수행하지 않음.

### 기준 선정 2-3: 한국인 온열감 표현
- 사용자가 연구의 7단계 내부 분류를 유지하되 화면에는 자연스러운 짧은 표현을 사용하는 안을 채택함.
- 화면 표현을 `많이 추움 / 추운 편 / 선선한 편 / 무난함 / 살짝 더움 / 더운 편 / 많이 더움`으로 확정해 `docs/수치_기준_근거자료_선정_항목.md`에 기록함.
- 감각 표현에는 공식 위험 단어를 넣지 않고, 한국형 PT의 `Hot/Very hot` 차이는 다음 `폭염·고온 위험` 항목에서 구분하기로 함.
- `포근함/따뜻함`의 쾌적 의미와 `매서움/무더움`의 바람·습도 의미가 섞이지 않도록 순수 온열감 문구에서 제외함.
- 제품 코드에는 아직 적용하지 않았으며 전체 기준 선정 후 데이터 계약·표현·테스트를 함께 정비해야 함.

### 기준 선정 2-4: 폭염·고온 위험
- 사용자가 기상청 공식 기준을 기본으로 국내 건강 연구와 취약계층 기준을 함께 적용하는 안을 채택함.
- 감각, 앱 사전 행동, 취약계층 행동, 실제 공식 특보의 네 출력 층을 분리해 `docs/수치_기준_근거자료_선정_항목.md`에 기록함.
- 예보가 공식 기준값에 도달해도 실제 발표 전에는 특보명을 사용하지 않고, 예상되는 최고 체감온도·지속기간과 행동을 사실형 문장으로 안내하기로 함.
- 국내 건강 연구는 공식 특보 단계를 대체하지 않고 취약계층 및 활동 조건의 행동 강도와 우선순위를 보완하는 데 사용하기로 함.
- 제품 코드에는 아직 적용하지 않았으며 전체 기준 선정 후 구현·테스트해야 함.

### 폭염·한파 사전 행동 및 취약계층 근거 추가 조사
- 사용자가 특보 기준 외에 2-4 폭염과 2-5 한파의 사전 행동·취약계층 근거를 추가 확인하도록 요청함.
- 폭염 근거를 확인함.
  - 서울 연구는 온열질환이 일 최고 실제 기온 약 30℃부터 증가하고 사망 기준 약 33℃ 전에 질환의 53.5%가 발생했다고 보고함.
  - 전국 975명 연구는 실제 최고기온 31.2℃를 전체 질환 경계로 추정했으나 지역별 28.8~34.0℃ 차이가 있어 전국 단일 실제 기온의 한계를 확인함.
  - 질병관리청 2025 감시는 실외 79.2%, 실외 작업장 32.1%, 14~17시 집중, 65세 이상 환자 30.0%·사망 58.6%를 보고함.
  - 일반인은 기상청 폭염 영향예보 관심, 야외근로자는 별도 작업장 체감 31/33℃ 기준을 쓰는 권장안을 문서에 추가함.
- 한파 근거를 확인함.
  - 2026 기상청 한파 영향예보는 지역군별 최저기온과 전일 대비 7℃ 이상 급락을 포함한 비특보 사전 행동 기준을 제공함.
  - 질병관리청 감시는 65세 이상 54.8%, 추정 사망 87.5%, 저체온증 80.2%를 보고함.
  - 6개 절기 분석은 실외·06~09시 집중과 90세 이상 고위험을, 서울 연구는 급격한 최저기온 하강과 저온의 지연 사망 영향을 뒷받침함.
- 조사 결과와 권장안을 `docs/수치_기준_근거자료_선정_항목.md`의 2-4 추가 근거와 2-5 검토 절에 기록함.
- 아직 사용자의 최종 채택 전이므로 권장안을 제품 코드에 적용하지 않음.
- 문서만 변경했으며 코드 테스트, 배포와 커밋은 수행하지 않음.

### 기준 선정 원칙 보완 및 2-4 최종 확정
- 사용자가 2-4 폭염·고온 위험의 사전 행동·취약계층 권장안을 최종 확정함.
- 공식 특보·법정 기준·공식 등급은 원문을 사용하고, 그 외 사전 행동·생활 행동·취약계층 보정은 임의 수치가 아니라 연구·리서치·질환 감시·현장 설문을 근거로 선정하기로 함.
- 한국인·국내 자료를 우선하고 국내 근거가 부족할 때만 국외 연구를 보조로 사용하며 적용 한계를 기록하기로 함.
- 질문 과정의 표현은 이해용 예시로만 보관하고 실제 앱·서버 문구 정비는 모든 기준을 확정한 뒤 한 번에 진행하기로 함.
- 위 원칙을 `docs/수치_기준_근거자료_선정_항목.md`의 문서 사용 원칙과 2-4 적용안에 반영함.
- 제품 코드와 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 선정 2-5: 한파·저온 위험 최종 확정
- 사용자가 지역별 한파 영향예보를 기본으로 국내 한랭질환 연구와 취약계층 기준을 보완하는 권장안을 확정함.
- 일반 사전 행동은 기상청 `한파 영향예보 보건분야 관심 이상`을 우선 사용하기로 함.
- 영향예보가 없으면 지역군별 관심 기준을 사용하며, 서울·수원 등 `그 외 지역`은 `전일 대비 7℃ 이상 하강하면서 아침 최저 3℃ 이하` 또는 `아침 최저 -9℃ 이하가 2일 지속`을 적용하기로 함.
- 65세 이상과 심뇌혈관질환·당뇨·고혈압은 같은 단계에서 알림 우선순위와 행동 강도를 높이고, 80세 이상은 최우선 취약군으로 분류하기로 함.
- 06~09시 실외 활동과 급격한 기온 하강을 별도 위험 보정으로 사용하며, 연구의 비교값인 `0℃`나 `-1℃`를 임의 발동 기준으로 만들지 않기로 함.
- 이해용 표현 예시는 보관하되 실제 앱·서버 문구는 모든 기준을 확정한 뒤 일괄 정비하기로 함.
- 위 내용을 `docs/수치_기준_근거자료_선정_항목.md`에 채택 상태로 반영함.
- 제품 코드와 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-1: 강수확률·실시간 강수·강수 행동
- 사용자가 강수확률은 해석 문구가 아닌 사실 숫자로 표시하기로 확정함.
- `현재 비가 오는 상태`에 사용할 수 있는 국내 자료를 조사함.
  - 기상청 초단기실황은 대표 AWS의 `PTY`, `RN1`을 매 정시 제공하며 현재 앱·서버에는 미연결 상태임.
  - 기상청 API허브는 전국 약 510개 AWS의 매분자료를 제공함.
  - 레이더 합성자료는 전국 강수 범위와 이동경향을 10분 주기로 제공함.
  - 기상청 CCTV 기반 도로날씨는 비·눈·안개·맑음과 강도를 실시간 판별하지만 2024년 기준 고속도로 11개 노선 중심이고 야간 성능이 낮음.
- 현재 강수는 초단기실황/AWS 지상관측을 우선하고 레이더·CCTV는 공간 보조 증거로 사용하는 권장안을 `docs/수치_기준_근거자료_선정_항목.md`에 기록함.
- 우산 준비·일정 변경·우산 종류는 하나의 강수확률 임계값으로 묶지 않고 국내 연구 수집, 비용-손실 모델, 한국인 이산선택실험, 실제 날씨 사후검증 순서로 근거를 만들도록 기록함.
- 큰 우산은 풍하중이 커질 수 있어 강한 비·바람에서 일률 권장하지 않고 접이식·튼튼한 장우산·우비·우산 자제 선택으로 재구성하는 방향을 검토함.
- 구체적인 행동 임계값은 아직 확정하지 않았고 최종 문구도 전체 기준 확정 후 일괄 작업하기로 함.
- 제품 코드, 테스트, 배포와 커밋은 수행하지 않음.

### 기준 선정 3-1 최종 확정
- 사용자가 3-1의 강수확률 표시, 실시간 강수 다중자료 판정과 강수 행동 근거 선정 방법을 확정함.
- 강수확률은 사실 숫자로만 표시하고 현재 강수·강수량·지속시간을 강수확률 하나로 추정하지 않기로 함.
- 현재 강수는 초단기실황/AWS 지상관측을 우선하고, 레이더는 주변 강수·이동, CCTV 도로날씨는 가까운 주간 지점의 보조 증거로 사용하기로 함.
- 곧 올 비는 초단기예보와 레이더 이동자료로 현재 강수와 분리하며, 자료시각·관측거리·출처·신선도를 품질정보로 관리하기로 함.
- 우산 준비·일정 변경·우산 종류는 국내 연구, 행동별 비용-손실, 한국인 선택실험, 풍하중 연구와 실제 날씨 검증 절차로 선정하기로 함.
- 기존 국내 근거가 충분한 행동에는 해당 근거를 우선 사용하고 근거가 부족한 행동만 신규 한국인 선택실험 대상으로 남기기로 함.
- 데이터 신선도·거리와 구체적인 행동 임계값은 후속 근거 선정 대상으로 남겼으며 제품 코드와 최종 문구는 변경하지 않음.
- 테스트, 배포와 커밋은 수행하지 않음.

### 기준 검토 3-2: 시간당 강수량 공식 강도와 생활 체감
- 사용자가 공식 강도명과 연구·리서치 기반 생활 체감을 함께 출력하는 구조를 요청함.
- 기상청 공식 강도는 `3mm 미만 약한 비`, `3~15mm 미만 보통 비`, `15~30mm 미만 강한 비`, `30mm 이상 매우 강한 비`임을 확인함.
- 기상청 시간당 강수량 체감영상이 실험실 촬영과 국내 실제 사례를 바탕으로 5·15·30·50·70·100mm/h의 보행·의복·시야·침수 영향을 제시함을 확인함.
- 국내 체감 기준점은 5mm 우산 필요·큰 불편 적음, 15mm 우산을 써도 장시간 노출 시 의복 젖음·물고임, 30mm 배수 취약지 신발 젖음·통행 불편, 50mm 정상 보행·운행 곤란, 70/100mm 침수 위험으로 구분함.
- 서울대학교 강우탑 실험은 성인 남성 8명이 150mm/h 인공강우에서 직접 젖음과 불편감을 평가해 보행·노출시간·의복 영향을 뒷받침함. 참가자 국적이 논문에 명시되지 않고 강우강도가 극단적으로 높아 일반 한국인의 임계값으로 직접 쓰지 않기로 함.
- `장화를 신지 않으면 신발이 젖는다`는 직접 근거가 없으므로 `배수가 좋지 않은 곳에서는 신발이 젖을 수 있다`로 한정하는 권장안을 문서에 기록함.
- 장화 준비는 30mm/h 단독 조건으로 확정하지 않고 보행시간·배수 취약 경로·물고임과 결합해 한국인 선택실험 및 현장검증 대상으로 남김.
- `docs/수치_기준_근거자료_선정_항목.md`에 3-2 검토 절과 사용자 선택 대기 권장안을 추가함.
- 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-2: 국내 생활행동 실측 근거 보강
- 시간당 강수량에 직접 연결할 수 있는 사람 체감 자료 외에, 국내 운전·보행·자전거·대중교통·공원 이용의 실제 변화 자료를 추가 조사함.
- 서울-춘천고속도로 RWIS·차량검지기 연구에서 강수 시 속도·교통량 감소와 `0.4mm/5분`, `0.8mm/5분` 변곡점을 확인함. 이는 운전행태 보조 근거이며 시간당 체감 경계로 단순 환산하지 않음.
- 한국건설기술연구원 실도로 재현 강우 실험에서 40mm/h 이상일 때 LiDAR 성능의 뚜렷한 저하를 확인함. 센서 실험이므로 인간의 시야 체감 임계값으로 직접 사용하지 않음.
- 대전 2023년 시간대별 자료에서 강수 뒤 공유자전거 이용이 즉시 감소하고, 주중 첨두는 지하철 대체, 주중 비첨두는 시간 조정, 주말은 통행 포기가 두드러짐을 확인함. 연구의 `0.5mm/h 미만=0` 처리는 분석 규칙이지 감각 임계값이 아님.
- 고양 공공자전거, 서울 보행량·서울숲 공원, 부산 대중교통 연구를 통해 강수 영향이 이동수단·필수성·여가성·계절·토지이용에 따라 달라짐을 확인함.
- 5분 강우·시간 강우·일 누적강우를 서로 바꿔 쓰지 않고, 기상청 체감영상은 기본 생활 체감, 국내 이용행태 연구는 활동별 행동 보정으로 분리하는 원칙을 문서에 추가함.
- `docs/수치_기준_근거자료_선정_항목.md`의 3-2 검토 절에 근거 표와 제한사항을 보강함.
- 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-2: 젖음 외 생활·환경 영향 근거 확장
- 사용자가 강수의 젖음 체감 외에 일상생활과 환경에 미치는 영향 자료를 추가 요청함.
- 즉시 영향으로 한국도로교통공단 빗길사고 통계, 당일 영향으로 한국은행 카드소비·빨래 건조 물리요인·서울 미세먼지 세정 연구를 확인함.
- 비가 그친 뒤 영향으로 국내 꽃가루 관측, 침수·누수 주택 곰팡이 연구, 특별재난지역의 호우 후 알레르기 외래환자 지연 증가 연구를 확인함.
- 환경 영향으로 강우가 대기 미세먼지를 씻어낼 수 있지만 모든 강수사상에서 PM10·PM2.5가 함께 감소하지는 않으며, 동시에 도로·주차장·농지의 비점오염물질을 하천으로 운반할 수 있음을 확인함.
- 출력 시점을 `강수 사실·공식 강도 / 즉시 생활 영향 / 별도 관측이 필요한 환경·지연 영향` 3층으로 분리하고, 비가 온다는 사실 하나로 공기질 개선·곰팡이·꽃가루·수질을 단정하지 않는 원칙을 문서에 추가함.
- `docs/수치_기준_근거자료_선정_항목.md`의 3-2 절에 근거 표, 적용 제한, 표현 예시를 추가함.
- 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 선정 3-2 최종 확정
- 사용자가 시간당 강수량의 공식 강도와 젖음 외 생활·환경 영향을 포함한 권장 구조를 확정함.
- `기상청 공식 강도 / 즉시 생활 영향 / 별도 관측 기반 환경·지연 영향`의 세 출력 층을 채택함.
- 즉시 생활 영향은 빗길 운전·이동·외출·빨래를 활동 종류와 사용자 맥락으로 보정하기로 함.
- 미세먼지 세정·꽃가루 재상승·실내 곰팡이·알레르기 지연·비점오염 유출은 비가 온다는 사실만으로 생성하지 않고, 각 항목에 필요한 별도 관측이나 사건 정보가 있을 때만 출력하기로 함.
- 공식 특보·긴급재난문자·영향예보와 실제 통제정보는 생활 체감보다 우선하도록 확정함.
- `docs/수치_기준_근거자료_선정_항목.md`의 3-2 제목·채택 상태·적용안을 갱신함.
- 다음 선정 항목은 3-3 `누적 강수량`이며 제품 코드와 최종 문구는 아직 변경하지 않음. 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-3: 누적 강수량
- 기상청 누적강수 관측의 기간누적·시간누적·일누적 구분과 최대 72시간 조회, 단기예보 PCP의 기본 1시간·연장기간 3시간 유효구간을 확인함.
- 관측 누적과 예상 누적을 분리하고, 예상 PCP의 `미만/범위/이상`을 최솟값 하나로 축소하지 않는 권장안을 문서에 추가함.
- 2026년 현재 호우특보는 예상 3시간·12시간 누적량, 기존 호우 긴급재난문자는 관측 1시간·3시간, 추가된 재난성호우 긴급재난문자는 관측 15분·1시간을 사용함을 확인함.
- 산사태는 산림청 토양함수지수와 공식 예측·발령정보, 하천 홍수는 하천별 수위·유량과 공식 특보를 사용하므로 앱의 24·72시간 누적량으로 자체 위험단계를 만들지 않는 원칙을 기록함.
- 한국은행의 일 20mm 이상 카드소비 연구와 부산의 일 10mm 이상 대중교통 연구는 집단 행동의 보조 문맥으로만 사용하고 개인 안전·외출 취소 임계값으로 사용하지 않기로 권고함.
- 현재 서버는 PCP 범위의 최솟값을 일별로 합산하고 앱 자체 예보는 첫 숫자만 읽어 범위 의미를 잃으며, 관측 누적·공식 호우/산사태/홍수 정보 계약이 없음을 확인함.
- 권장 데이터 계약은 `observedAccumulation`, `forecastAccumulationRange`, `officialAlerts`, `sourceWindow` 분리이며 사용자 최종 확정 전이라 제품 코드는 변경하지 않음.
- `docs/수치_기준_근거자료_선정_항목.md`에 3-3 검토 근거, 적용 제한, 현재 연결 상태와 표현 예시를 추가함. 테스트, 배포와 커밋은 수행하지 않음.

### 기준 선정 3-3 최종 확정
- 사용자가 다음 항목 진행을 요청해 3-3 누적 강수량 권장안을 확정한 것으로 반영함.
- 관측 누적과 예상 누적범위를 분리하고, 시간창·관측지점·발표시각을 보존하며 PCP의 `미만/범위/이상`을 단일 숫자로 축소하지 않는 안을 채택함.
- 공식 호우·산사태·하천홍수 정보는 누적량으로 앱이 추정하지 않고 실제 공식 데이터를 사용하며, 국내 일 10mm·20mm 행동 연구는 이동·소비의 보조 문맥으로만 사용하기로 함.
- 현재 서버·앱의 PCP 합산 및 데이터 계약 개선은 전체 기준 선정 후 구현 대상으로 유지함.

### 기준 검토 3-4: 호우·집중호우
- 2026년 기상청의 호우 발생가능성, 예비특보, 주의보, 경보, 긴급재난문자로 이어지는 5단계 대응체계를 확인함.
- `집중호우`는 현행 공개 예보용어의 독립 수치등급이 아니므로 앱이 자체 임계값으로 생성하지 않고, 공식 통보문 또는 시간·공간 집중 사실을 함께 제시할 때만 설명어로 쓰도록 권고함.
- 기존 호우 긴급재난문자와 2026년 신설 재난성호우 긴급재난문자의 관측 기준과 역할을 분리함.
- 최근 10년 풍수해 인명피해 분석에서 오전 6~12시 50%, 60대 이상 61%였으며, 이동·재해예방 활동·차량 이동 중 침수·휩쓸림과 산지 인접 주택의 매몰이 주요 행동 맥락임을 확인함.
- 60세 이상 비율은 풍수해 집단 관찰값으로만 두고, 직접 행동 보정은 정부 정책에 맞춰 `65세 이상 또는 자력대피 곤란`과 공식 위험지역이 함께 있을 때 적용하도록 권고함.
- 호우 전에 배수구 점검·차량 이동을 끝내고 비가 시작된 뒤에는 같은 행동을 권하지 않으며, 경보 이상에서는 생활 TODO보다 통제·대피 정보를 우선하도록 기록함.
- 현재 서버의 `HEAVY_RAIN`은 10mm 또는 `POP 70% + 5mm`로 생성되어 공식 강수강도·호우특보와 모두 다르며, 실제 `WeatherWarning.activeWarnings` Provider도 미연결임을 확인함.
- `docs/수치_기준_근거자료_선정_항목.md`에 용어, 공식 단계, 국내 인명피해·취약성 근거, 단계별 행동, 현재 연결 오류와 표현 예시를 추가함.
- 사용자 최종 확정 전이라 제품 코드는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-4: 기상청 수치 기준 명시
- 사용자가 호우·집중호우에 기상청 자체 기준이 있는지 재확인을 요청함.
- 기상청에는 시간당 강수강도, 예상 누적량 기반 호우주의보·경보, 관측 누적량 기반 호우·재난성호우 긴급재난문자 기준이 각각 존재함을 재확인함.
- 호우주의보는 예상 3시간 60mm 또는 12시간 110mm, 호우경보는 예상 3시간 90mm 또는 12시간 180mm 기준임.
- 기존 호우 긴급재난문자는 관측 1시간 50mm와 3시간 90mm 동시 충족 또는 1시간 72mm, 2026년 재난성호우 긴급재난문자는 관측 1시간 100mm 또는 1시간 85mm와 15분 25mm 동시 충족 기준임.
- `집중호우`는 기상청 내부에서도 용도에 따라 30mm/h 탐지 대상, 50mm/h 발생빈도 통계처럼 서로 다른 기준을 사용하므로 단일 공식 특보 등급으로 취급하지 않기로 정리함.
- 위 구분과 수치표를 `docs/수치_기준_근거자료_선정_항목.md` 3-4 절에 추가했으며 제품 코드는 변경하지 않음.

### 기준 검토 3-4: 공식 단계 전 내부 집중호우 안내 원칙
- 사용자가 공식 특보가 발생하면 공식 정보를 사용하고, 공식 단계가 없을 때는 최근 5년 내 분석자료를 바탕으로 내부 집중호우 예상·주의 안내를 제공하도록 결정함.
- 최근 자료에서 기상청 집중호우 탐지 연구의 30mm/h, 2021~2025년 발생빈도 통계의 50mm/h, 2024·2025년 반복된 100mm/h 이상 극단 사례를 확인함.
- 내부 권장 경계는 예상 `30mm/h 이상`, 주의 `50mm/h 이상 또는 예상 3시간 90mm 이상`으로 제안함. 72·85·100mm/h 예상은 별도 공식 명칭을 만들지 않고 내부 주의 행동과 알림만 강화하도록 함.
- 범위형 예보는 하한이 임계값을 넘어야 해당 내부 단계를 확정하고 상한만 넘으면 가능성과 원래 범위를 표시하도록 정리함.
- 공식 호우 발생가능성·예비특보·주의보·경보·긴급재난문자가 있으면 내부 단계를 숨기며, 6시간 이내는 10분 간격 초단기 강수예측과 레이더를 우선하도록 함.
- 국지성 보정을 위해 현재 격자뿐 아니라 인접 격자를 확인하고 인접 격자만 충족하면 `현재 위치`가 아니라 `주변` 예상으로 표현하도록 함.
- 위 원칙, 근거표, 판정표와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-4 절에 반영함.
- 세부 임계값은 사용자 최종 확인 전이며 제품 코드와 최종 문구는 변경하지 않음. 테스트, 배포와 커밋도 수행하지 않음.

### Android 적응형 앱 아이콘 및 앱 이름 정리
- Android 8 이상 런처가 일반 정사각형 아이콘을 흰 원 안에 다시 축소하던 문제를 적응형 아이콘 자원으로 해결함.
  - `pubspec.yaml`에 적응형 배경색, 전경 이미지와 12% 안전 여백을 추가함.
  - `mipmap-anydpi-v26/ic_launcher.xml`, 전경 density 자원과 배경색 자원을 생성함.
  - 원형 마스크 안에서 구름·해·비·눈 요소가 잘리지 않으면서 파란 배경이 원 전체를 채우도록 조정함.
- 앱 표시 이름을 Android와 iOS 모두 `날씨챙겨`로 통일함.
  - Android `AndroidManifest.xml`의 `android:label` 변경.
  - iOS `Info.plist`의 `CFBundleDisplayName`, `CFBundleName` 변경.
- 검증 결과:
  - `flutter analyze`: 이슈 없음.
  - `flutter test`: 20개 모두 통과.
  - `flutter build apk --debug`: 성공.
  - Android 17/API 37 에뮬레이터에 재설치해 앱 서랍의 원형 아이콘과 `날씨챙겨` 이름, 콜드 스타트 시작 화면의 원형 아이콘을 시각 확인함.
  - Windows 환경이므로 iOS Xcode 빌드는 실행하지 않음.

### 기준 선정 3-4 최종 확정 및 3-5 소나기 검토
- 사용자가 다음 항목 진행을 요청해 3-4의 공식 단계 우선 및 내부 집중호우 예상 30mm/h, 주의 50mm/h 또는 예상 3시간 90mm 기준을 확정한 것으로 반영함.
- 3-5 소나기는 강수량 등급이 아니라 강수 발생형태로 보고 PTY, POP, 강도, 낙뢰·돌풍·우박, 공식 특보를 분리함.
- 기존 공개 API 가이드에서는 `PTY=4`가 단기예보 소나기 코드이며 초단기 PTY에는 소나기 코드가 없음을 확인함. 기상청 2026년 시행계획은 6월부터 초단기예보 소나기 요소 신규 제공을 명시하므로 구현 전에 최신 필드·코드와 실제 응답을 검증하도록 기록함.
- 단기예보 `PTY=4`, 검증된 초단기 소나기 요소와 지역 통보문을 소나기 판정의 기본으로 사용하고 강수확률·기온·습도로 자체 추정하지 않는 권장안을 작성함.
- `지역 내 소나기 가능`, `현재 위치 소나기 예상`, `주변 소나기 접근`, `현재 비`, `현재 소나기`를 구분함. 현재 소나기는 공식 현상 설명과 AWS·레이더 강수 관측을 함께 확인하도록 함.
- 단기예보의 표시시각은 직전 1시간 현상을 뜻하므로 정시값을 유효구간으로 변환하고, 소나기 예상량 범위를 현재 위치 확정값이나 시간당 값으로 바꾸지 않도록 함.
- 소나기 강도는 3-2 기준을 재사용하고 30·50mm/h 이상은 3-4 내부 집중호우 예상·주의를 별도로 평가하도록 함.
- 기상청 1시간 단위 예보 조사 1,482명·유용도 85.1%와 이용 경험을 근거로 하루 합계보다 위치·시간창·최신 레이더 확인을 우선하도록 함.
- 천둥·번개 예상 또는 낙뢰 관측이 있을 때만 30-30 낙뢰 행동요령과 비옷 준비를 우선하고, 소나기 자체에서 낙뢰·돌풍·우박을 자동 추정하지 않도록 함.
- 현재 서버는 단기예보 PTY=4 변환만 연결돼 있고 첫 미래 슬롯을 current로 사용함. 초단기·AWS·레이더·통보문·낙뢰·우박 Provider가 없어 접근·현재 소나기·낙뢰 동반 판정은 아직 불가능함.
- 위 근거, 권장 판정, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-5 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-5: 갑작스러운 약한 강수까지 알림 확대
- 사용자가 기상학적 소나기보다 `갑자기 비가 온다`는 경험을 알림 기준으로 삼고, 기존 소나기 강도보다 약한 이슬비·가랑비도 알리도록 요청함.
- 기상청 날씨알리미가 현재 위치에서 1시간 안에 10분 강수량 0.1mm 이상이 예상되면 강수 시작을 알리는 기준을 사용함을 확인함.
- 현재 10분 강수가 0.1mm 미만이고 앞으로 1시간 안에 처음 0.1mm 이상으로 예측되면 `갑작스러운 비 예상`, 직전 무강수에서 최신 관측이 0.1mm 이상으로 바뀌면 `갑작스러운 비 시작`으로 제안함.
- 공식 소나기 현상과 갑작스러운 강수 시작 이벤트를 분리하고, 소나기·갑작스러운 비의 강도는 기존 3-2 시간당 강수강도를 그대로 쓰도록 함.
- 이슬비는 작은 물방울의 별도 관측현상이며 단순히 양이 적다는 이유로 붙이면 안 됨을 확인함. 공식 DZ·기상현상이 있을 때만 `이슬비`를 사실명으로 사용함.
- 공식 이슬비 현상이 없고 3mm/h 미만이면 `약한 비`를 사실값으로 저장하며, 사용자 표현으로 `가랑비처럼 약한 비`를 사용할 수 있도록 함.
- 현재 서버에는 10분 초단기 강수예측과 실황 Provider가 없어 1시간 내 강수 시작·갑작스러운 약한 비 알림을 아직 만들 수 없음을 기록함.
- 기준 문서 3-5 절에 판정표, 이슬비·가랑비 구분, 데이터 구조와 표현 예시를 반영함. 정확한 종료·재시작 기준은 다음 항목으로 넘김.
- 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### Android 앱 아이콘 안전 여백 추가 조정
- 사용자 요청에 따라 적응형 아이콘 전경 여백을 12%에서 16%로 늘림.
- Android 17/API 37 에뮬레이터에 Debug APK를 재설치해 원형 아이콘 둘레의 파란 여백이 늘고 해·구름·비·눈 요소가 모두 원 안에 유지되는 것을 확인함.
- 비교 이미지 `weather_care_app/build/icon-inset-comparison-12-16.png`를 생성함. 왼쪽은 기존 12%, 오른쪽은 16% 예시임.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter build apk --debug` 성공.

### Today `오늘 하루` 시간 간격 확인
- Today 탭은 앱에서 시간을 다시 계산하지 않고 서버 응답의 `today.timeline`을 그대로 표시함.
- 서버 `buildTimeline()`은 1시간 단위 예보의 인덱스 `0`, `6`, `12`를 선택하므로 기본 구성은 첫 유효 예보 시각부터 6시간 간격의 3개 시점임.
- 시작 시각은 고정값이 아니라 현재 시각에 가까운 첫 유효 예보 슬롯에 따라 달라짐.
- 앱의 기상청 직접 조회 fallback은 현재 `timeline`을 만들지 않으므로 운영 서버 기능을 사용할 때만 이 구성이 표시됨.

### 기준 검토 3-6: 강수 시작·종료 판단
- 사용자가 `다음 항목` 진행을 요청해 3-5의 갑작스러운 비와 약한 이슬비·가랑비 알림안을 채택 상태로 변경함.
- 기상청 10분 강수예측은 강수 시작·종료와 강약을 10분 간격으로 최대 12시간 제공하고, AWS는 강우감지센서의 강수 유무를 매분 갱신함을 확인함.
- 강수량계는 장비별 분해능 차이가 있어 약한 비가 `0mm`로 보일 수 있으므로 강수유무 센서 ON이면 종료로 판단하지 않도록 함.
- 기상청의 `한때/가끔`은 예보기간 내 지속비율 표현이지 정확한 종료시각이 아니며, 전국 공통 `몇 분 무강수면 완전 종료`라는 공식 기준은 확인되지 않음.
- 2022년 국내 IETD 연구는 독립 강우사상의 무강수 간격이 분석 목적과 대상기간에 따라 달라짐을 보여 수문학용 6·10시간 등을 사용자 알림에 직접 적용하지 않도록 함.
- 권장 상태를 `RAIN_START_EXPECTED`, `RAIN_STARTED`, `RAINING`, `TEMPORARY_BREAK`, `RAIN_ENDED`, `NO_RAIN_NEXT_6H`, `RAIN_RESTART_EXPECTED`, `RAIN_RESTARTED`로 분리함.
- 현재 한 개의 완전한 10분 구간이 무강수이고 앞으로 1시간 안에 다시 0.1mm/10분 이상이 있으면 `잠시 그침`, 앞으로 1시간 전체가 0.1mm 미만이면 `그침`으로 권고함. 이는 공식 종료 기준이 아닌 10분 자료 해상도에 맞춘 앱 운영값임을 명시함.
- 6·12시간 무강수는 `앞으로 N시간 비 예보 없음`으로만 표시하고 `오늘 비가 완전히 끝남`으로 확대하지 않도록 함.
- 기존 서버가 시간 단위 예보의 두 시간 이상 건조구간을 `RAIN_BREAK_WINDOW`로 생성하지만 관측된 소강·종료는 아니며, AWS·10분 강수예측·레이더 Provider 연결 뒤 새 상태모델로 교체해야 함을 기록함.
- 예상시각 변경 재알림 임계값은 임의 수치로 넣지 않고 추후 알림 발송 기준에서 실제 사용자 반응과 오경보·누락 비용을 근거로 선정하도록 남김.
- 위 근거, 권장 판정표, 중복 알림 원칙, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-6 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-7: 강설 가능성
- 사용자가 3-6 권장안을 확정해 기준 문서를 채택 상태로 변경하고 다음 항목인 강설 가능성을 조사함.
- 기상청 단기·초단기예보 PTY의 없음(0), 비(1), 비/눈(2), 눈(3), 소나기(4), 빗방울(5), 빗방울/눈날림(6), 눈날림(7)을 강수형태 사실의 기본으로 선정함.
- 강수확률 POP는 비·눈을 포함한 강수 발생 가능성이고 별도 눈 확률이 아니므로 `눈 확률`로 복사하지 않는 권장안을 작성함.
- 단기예보 도움말과 눈일수 정의를 근거로, 눈이 내리지만 매우 적거나 녹아 SNO가 없을 수 있으므로 `눈이 내림`과 `눈이 쌓임`을 분리함.
- 기상청 2024 예보기술 자료에서 눈·비 판별에 대기층 두께, 습구온도 약 1.2℃, 925·850hPa 온도와 기압계 구조를 함께 사용함을 확인함. 실제 기온 0℃나 습구온도 하나로 앱이 공식 눈 예보를 새로 만들지 않도록 함.
- 권장 상태를 `SNOW_FORECAST`, `RAIN_SNOW_FORECAST`, `SNOW_FLURRY_FORECAST`, `RAIN_SNOW_FLURRY_FORECAST`, `SNOW_OBSERVED`, `SNOW_NO_ACCUMULATION_FORECAST`, `SNOW_ACCUMULATION_FORECAST`, `REGIONAL_SNOW_POSSIBLE`, `PRECIPITATION_PHASE_UNCERTAIN`으로 분리함.
- 현재 프로젝트는 PTY 2·3·6·7과 SNO 양수를 눈 예상으로 인식해 기본 연결은 되어 있으나 PTY 6·7의 약한 현상 구분을 정규화 과정에서 잃는 문제를 확인함.
- 서버가 눈 관련 PTY의 POP를 `snowProbability`에 그대로 복사하고 `SNOW_LIKELY` 심각도를 POP 최소 50점으로 사용하는 문제를 확인함. 후속 구현에서 강수확률, 눈 관련 공식 형태, 적설·위험을 분리해야 함.
- 단기예보 첫 슬롯을 현재로 사용하는 구조여서 현재 눈 관측은 불가능하며 초단기실황과 ASOS 현재일기 Provider가 필요함을 기록함.
- 위 근거, 판정 상태, 사실·행동 연결 원칙, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-7 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-8: 시간당 적설량
- 사용자가 3-7 강설 가능성 권장안을 확정해 기준 문서를 채택 상태로 변경하고 다음 항목인 시간당 적설량을 조사함.
- 화면의 시간당 적설량을 데이터상 `1시간 신적설`, 즉 한 시간 동안 새로 내려 쌓인 깊이로 정의하고 현재 전체 적설·눈의 강도·무게와 분리함.
- 기상청 정량 SNO가 `0.5cm 미만`, 0.5~4.9cm 실수값, `5cm 이상`, 적설없음으로 제공됨을 확인하고 범위와 열린 상한을 그대로 보존하도록 함.
- 기상청 2024 단기예보 개편의 대국민 설문 2,985명과 전문가 자문을 근거로 `1cm/h 미만=(보통) 눈`, `1cm/h 이상=많은 눈` 정성단계를 권고함.
- 3시간 요약 SNO 정성코드 1·2는 실제 1cm·2cm가 아니라 구간 내 가장 강한 1시간의 보통 눈·많은 눈이라는 점을 기록함.
- 관측은 API허브 `SD_H01` 최근 1시간 신적설, 예보는 SNO의 정시 전 1시간 구간으로 구분하고 관측지점·거리·시각을 표시하도록 함.
- `많은 눈`은 기상청 정성 예보 용어이지 대설특보나 폭설 주의가 아니므로 시간당 1cm 하나로 위험 추천을 만들지 않도록 함.
- 현재 서버는 범위 하한만 호환 숫자로 사용하고 앱 fallback은 첫 숫자만 읽어 `미만/이상` 의미를 잃는 문제를 확인함.
- 연장기간 SNO 정성코드 1·2를 실제 cm로 오독할 수 있고, 서버의 1cm/h·3시간 3cm가 `HEAVY_SNOW`와 `폭설 주의`에 연결되는 문제를 기록함.
- 누적 적설은 슬롯 하한을 단순 합산해 범위와 정성코드 의미를 잃으므로 다음 누적 적설량 항목에서 별도로 정하도록 함.
- 위 근거, 정량·정성 표현표, 판정 원칙, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-8 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-9: 누적 적설량
- 사용자가 3-8 시간당 적설량 권장안을 확정해 기준 문서를 채택 상태로 변경하고 다음 항목인 누적 적설량을 조사함.
- `누적 적설량`을 하나의 숫자로 취급하지 않고 `현재 적설`, `최근 N시간 관측 신적설`, `앞으로 N시간 예상 신적설`, `기상청 통보문 지역 예상 적설`로 분리함.
- 기상청 API허브의 `SD`, `SD_H01·SD_H03·SD_H24`, `SD_DAY·SD_D01` 정의와 현재 적설이 녹음·다져짐으로 줄 수 있다는 공식 설명을 근거로 현재 적설과 신적설을 서로 환산하지 않도록 함.
- 관측 누적은 제공기관이 산출한 해당 시간창 값을 우선하고 겹치는 1시간 이동값을 반복 합산하지 않도록 함.
- 예상 누적은 같은 발표본의 겹치지 않는 1시간 정량 SNO만 합산하며, 누락을 0으로 채우지 않고 `미만·이상`의 열린 범위를 보존하도록 함.
- `0.5cm 미만 + 1.0cm`는 `1.0cm 이상 1.5cm 미만`, `5cm 이상 + 1.2cm`는 `6.2cm 이상`으로 계산하는 범위 연산을 기록함.
- 연장기간의 3시간 SNO 정성코드 `1·2`는 누적 cm가 아니라 구간 내 가장 강한 1시간의 정성단계이므로 합계에서 제외함.
- 기상청 통보문의 기간·지역·`많은 곳` 조건을 보존하고 위치 격자 합계와 서로 덮어쓰거나 평균내지 않도록 함.
- 현재 서버가 SNO 범위 하한을 일·24시간 합계로 단순 합산하고 앱 fallback은 첫 숫자를 정확한 값으로 읽어 서로 다른 잘못된 누적을 만들 수 있음을 확인함.
- 현재 적설·관측 신적설·격자 적설·통보문 Provider와 종류·시간창·범위·출처를 담을 응답 모델이 없다는 구현 공백을 기록함.
- 위 근거, 범위 합산 규칙, 출력 원칙, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-9 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

### 기준 검토 3-10: 대설·폭설
- 사용자가 3-9 누적 적설량 권장안을 확정해 기준 문서를 채택 상태로 변경하고 다음 항목인 대설·폭설을 조사함.
- 기상청의 공식 특보는 대설주의보·대설경보이며 `폭설주의보·폭설경보`는 없으므로, 폭설을 앱의 독립 수치단계로 만들지 않도록 함.
- 공식 대설주의보는 예상 24시간 신적설 5cm 이상, 경보는 20cm 이상·산지 30cm 이상이나 수치 충족만으로 공식 발효를 생성하지 않고 실제 특보 원문을 요구하도록 함.
- 대설 발생가능성 정보, 예비특보, 주의보, 경보, 대설 재난문자와 앱 내부 수치 예상을 분리하고 공식 원문·구역·발표/발효/해제시각을 우선하도록 함.
- 공식 발표가 없을 때 24시간 예상범위가 5cm를 걸치면 `대설 기준 가능성`, 하한이 5cm 이상이면 `대설 수준 예상`으로 표시하는 범위 기반 내부상태를 제안함.
- 2025년 기상청 대설 재난문자의 관측 1시간 5cm 교통사고 대응, 관측 24시간 20cm와 1시간 3cm 동시 시설물 대응 기준을 확인하고 예보는 피해조건 예상, 관측·실제 문자는 즉시행동으로 분리함.
- 2026년 8월 현재 대설 재난문자는 수도권·충남권·전북 시범운영 상태이고 2026년 12월 전국 확대 예정이므로 미운영 지역의 무문자를 안전으로 해석하지 않도록 함.
- 2025년 기상청 정책연구의 피해사례 분석에서 0→10cm 평균 약 3.5시간, 10→20cm 약 2시간, 20→30cm 약 5시간이 걸린 결과를 확인해 10cm 예상 시 이동·시설물 준비 완료를 앞당기도록 함. 평균시간은 개별 강설 도달시간 예측으로 사용하지 않음.
- 같은 연구가 778건 구조물 피해사례를 분석해 습설이 건설보다 약 1.5~2배 무겁고 일부 습설 사례는 약 10cm에도 지붕 붕괴가 나타났다고 보고한 점을 반영함.
- 기상청 공식 `가벼운·보통·무거운 눈` 정보를 적설깊이와 결합하고, 무거운 눈이면 노후지붕·가설물·비닐하우스 점검을 더 일찍 노출하도록 함. 앱이 SNO만으로 눈 무게를 자체 생성하지 않음.
- 보행 취약 사용자·어린이·고령자·거동 불편 가족은 별도 임의 적설 임계값 대신 같은 단계에서 동행·외출조정·안부확인을 우선하도록 함.
- 현재 서버의 1시간 1cm 또는 3시간 3cm `HEAVY_SNOW`가 앱 `폭설 주의` 추천과 최우선 알림을 만드는 오류, 특보·예비특보·재난문자·눈 무게 Provider 부재를 기록함.
- 위 근거, 공식/내부 상태표, 최근 분석에 따른 행동 연결, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-10 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음.

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

### 기준 채택 3-10 보완: 공식 대설특보 미발표 시 연구 기반 판정
- 사용자가 공식 특보가 없을 때에는 대설특보 수치를 복제하지 말고 폭설·대설 관련 연구를 확인해 적용하도록 요청함.
- 2025년 기상청 정책연구 원문 523쪽을 내려받아 관련 본문·표·시뮬레이션 페이지를 추출·렌더링해 확인함.
- 연구대상은 2014~2025년 구조물 붕괴·파손 778건이며 일반 교통사고, 보행자 낙상, 경미한 제설사고가 제외됐음을 확인함. 따라서 연구 수치를 일반 이동·보행 대설단계에 사용하지 않도록 범위를 제한함.
- 공식 특보 미발표 시 예상·관측 적설은 사실정보로만 표시하고, 예상 24시간 신적설 5cm 특보기준을 앱의 `대설 기준 가능성·대설 수준`으로 복제하던 기존 권장안을 철회함.
- 연구가 제안한 `현재 적설 10·15·20cm + 최근 1시간 3cm 또는 3시간 5cm 신적설` 복합조건을 각각 `취약시설 사전점검·접근제한·대피` 내부상태로 제한해 적용함.
- 복합조건 포착값은 본문 표 기준 464/778, 59.64%이며 결론부의 `70% 이상` 표현과 불일치함을 기록함. 미충족 사례 약 40%를 안전으로 해석하거나 개별 건물 붕괴 예측에 사용하지 않도록 함.
- 평택·안성 2개 피해 시뮬레이션의 선행시간과 평균 적설 증가시간은 사례가 제한돼 개별 강설의 도달·붕괴시각 예측에 사용하지 않도록 함.
- 공식 `무거운 눈` 정보와 10cm 안팎 적설 가능성이 결합하면 취약시설 사전점검을 앞당기되 앱이 SNO만으로 눈 무게를 계산하지 않도록 함.
- 서울연구원의 최근 5개 겨울철 분석을 추가해 교통·보행 위험은 획일적 적설심보다 도로구조·교통·기상·결빙을 함께 봐야 하므로 후속 도로결빙 항목에서 별도 선정하도록 함.
- 위 보완안과 적용 제한, 출처, 상태표, 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-10 절에 반영함.
- 사용자 요청에 따라 보완안을 3-10 최종 선정안으로 채택했으며 다음 검토 항목은 3-11 도로 결빙임.
- 제품 코드와 최종 화면 문구는 변경하지 않았으며 문서 검토만 수행함. 테스트, 배포와 커밋도 수행하지 않음.

### 기준 채택 3-11: 도로 결빙
- 사용자가 3-10 대설·폭설 보완안을 확정하고 다음 항목 진행을 요청해 도로 결빙의 공식정보·국내 최근 연구·사고자료를 검토함.
- 기상청 2024 지상기상관측지침에서 노면상태를 마름·젖음·서리·결빙·적설 등으로 1분 간격 처리하며, 비·눈·어는비·안개가 0℃ 이하 노면과 접촉할 때 도로살얼음이 발생한다고 설명한 점을 확인함.
- 표준 노면온도 센서 정확도 ±0.8℃를 반영해 `Tlow=Ts-u`, `Thigh=Ts+u`로 범위를 만들고, 같은 도로구간의 젖음 근거와 결합해 `결빙 환경 가능/뚜렷`을 구분하는 보조판정식을 제안함.
- 기상청 도로기상정보시스템은 `안전 0·관심 1·주의 2·위험 3`을 제공하며 2025년 12월부터 12개 재정고속도로·366개 관측소 기반 정보와 API를 전면 개방했음을 확인함. 공식 단계는 그대로 수집하고 앱이 수치로 복원하지 않도록 함.
- 2025년 기상청 연구계획이 고정·이동식 도로관측, ASOS·AWS·레이더, 초단기예측·수치모델을 함께 써 +12시간 모형을 검증한 점을 근거로 TMP·POP만으로 공식 단계를 모방하지 않도록 함.
- 2021년 중앙고속도로 132.5km·7회 관측 연구에서 노면온도 0℃ 이하와 수분 결합, 교량 및 낮은 하늘시계·음영구간의 취약성을 확인하되 한 노선의 상대지수를 전국 절대단계로 전용하지 않도록 함.
- 한국도로교통공단 2019~2023년 결빙사고 3,944건·사망 95명, 12~1월 79%, 06~10시 34.9%, 고속도로 치사율 4.5배 결과를 알림·행동 우선순위에만 사용하고 물리적 결빙단계에는 사용하지 않도록 함.
- 결빙사고 다발지역 API의 최근 5년·반경 200m·3건 이상 또는 사망 포함 2건 이상 기준을 경로 재확인 보정으로 사용하되 현재 결빙 관측으로 표현하지 않도록 함.
- 행정안전부의 빙판길 제한속도 20~50% 감속, 안전거리 2배 이상, 급조작 금지 행동을 실제 결빙·공식 위험정보에 연결함.
- 현재 서버가 비·눈 예상과 `min(실제 기온, 체감온도)≤0℃`만으로 `ICY_ROAD_RISK` 점수 95를 만들고, POP만으로도 강수조건이 참이 될 수 있는 연결 오류를 확인함. 도로 Provider와 구간·노면자료는 없음.
- 위 근거, 공식/관측/내부 보조판정 우선순위, 센서 불확도 식, 시간·구간 보정, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-11 절에 추가함.
- 사용자가 3-11 권장안을 최종 확정했으며 제품 코드와 최종 화면 문구는 아직 변경하지 않음. 테스트, 배포와 커밋도 수행하지 않았고 다음 항목은 3-12 블랙아이스임.

### 조합형 날씨 아이콘 위젯화 및 Week 제약 버그 수정
- `WeatherConditionIcon` 내부의 해+구름, 겹친 구름, 비, 혼합 강수, 눈 조합을 각각 독립 `StatelessWidget`으로 분리함.
- Week의 42px 원형 부모가 21px 조합 아이콘을 강제 확장하면서 구름은 위, 빗방울은 아래로 떨어지던 제약 충돌을 확인함.
- 공통 아이콘에 중앙 제약층을 추가해 큰 부모 안에서도 실제 조합 영역은 요청한 정사각 크기를 유지하도록 수정함. Main·Detail·Week 호출부는 공통 위젯 하나만 계속 사용함.
- 큰 부모 안에서 9종 조합 아이콘의 실제 크기와 모든 구성 요소가 조합 영역 안에 유지되는지 확인하는 회귀 테스트를 추가함.
- 검증: `flutter analyze` 통과, Flutter 테스트 26개 통과. Android 에뮬레이터 1080×2400 Week 화면에서 비·소나기·흐림·구름 많음 아이콘이 분리되지 않는 것을 확인함.
- 배포와 커밋은 수행하지 않음.

### 기준 채택 3-11 및 검토 3-12: 블랙아이스(도로살얼음)
- 사용자가 3-11 도로 결빙 권장안을 확정해 채택 상태로 변경하고 다음 항목인 블랙아이스·도로살얼음을 조사함.
- 블랙아이스는 일반 도로결빙보다 높은 별도 단계가 아니라 얇고 투명해 식별하기 어려운 도로살얼음 형태로 정의하고, 기본 UI 용어를 기상청 명칭인 `도로살얼음`으로 권고함.
- 기상청의 구간·방향별 `안전 0·관심 1·주의 2·위험 3` 공식 정보를 최우선으로 사용하고, 앱의 기온·강수확률로 공식 단계를 복원하지 않도록 함.
- 공식·명시적 도로살얼음 관측만 `도로살얼음 관측`으로 표시하고 일반 노면센서의 결빙은 두께·투명도를 알 수 없어 `노면 결빙 관측`으로 유지하도록 함.
- 공식 정보가 없는 구간은 3-11의 수분·노면온도·센서 불확도 조건에 `비·융설수 뒤 재결빙`, `어는 강수`, `안개·이슬·서리` 중 하나의 형성 경로가 더 확인될 때만 `도로살얼음 형성조건 가능/뚜렷`을 생성하는 권장안을 제안함.
- CCTV에서 도로가 검거나 마르게 보이는 것, 실제 기온, 체감온도, POP 또는 높은 습도 하나로 도로살얼음 발생·안전을 확정하지 않도록 함.
- 2022년 초기 시범모형의 마찰계수 단계와 도로관리기관의 기온·습도·노면온도 사전살포 후보값은 현행 시민용 발생기준이 아니므로 앱 단계로 사용하지 않도록 함.
- 2026년 기상청 연구계획에서도 고정·이동 도로관측, ASOS·AWS, 레이더, 초단기예측·수치모델을 결합한 도로살얼음 모형을 계속 검증·개선 중임을 확인해 내부 판정을 확률·확정 발생으로 과장하지 않도록 함.
- 현재 서버는 전용 도로살얼음 상태나 도로 Provider 없이 체감온도·POP가 포함된 `ICY_ROAD_RISK` 점수 95만 생성할 수 있어 새 권장 상태를 신뢰성 있게 출력할 수 없음을 기록함.
- 위 근거, 상태 우선순위, 세 형성 경로, 내부 판정식, 행동 보정, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-12 절에 추가함.
- 사용자 최종 확정 전이라 제품 코드와 최종 화면 문구는 변경하지 않았으며 테스트, 배포와 커밋도 수행하지 않음. 다음 항목은 3-13 서리·차량 성에임.

### 수치 기준 검토 컨텍스트 종료 지점
- 사용자가 이번 컨텍스트의 최종 확정 범위를 **3-11 도로 결빙까지**로 지정함. `docs/수치_기준_근거자료_선정_항목.md`에서 3-11까지는 채택 상태임.
- 3-12 블랙아이스(도로살얼음)는 근거와 권장안이 작성돼 있지만 **사용자 미확정 초안**이다. 다음 컨텍스트에서는 새 조사를 처음부터 반복하지 말고 3-12의 공식정보 우선·세 형성 경로·허용 출력안을 사용자에게 다시 제시하거나 필요한 수정부터 진행한다.
- 3-12가 확정되기 전에는 3-13 서리·차량 성에로 넘어가지 않는다. 확정 시 3-12를 채택 상태로 변경한 뒤 3-13을 조사한다.
- 사용자는 모든 수치 기준 항목이 끝난 뒤 표현과 제품 기능을 한꺼번에 작업하기로 했으므로, 별도 요청 전에는 앱·서버 판정 코드와 최종 화면 문구를 변경하지 않는다.
- 이번 종료 작업에서는 문서의 확정/미확정 상태와 인계 기록만 수정했으며 테스트, 배포, 커밋은 수행하지 않음.

## 2026-08-24

### 이어서 할 일 확인
- 다음 작업은 미확정 초안인 **3-12 블랙아이스(도로살얼음)** 권장안을 사용자에게 다시 제시하고 확정 또는 수정하는 것임.
- 3-12 확정 전에는 3-13 서리·차량 성에 조사와 앱·서버 판정 코드·최종 화면 문구 변경을 진행하지 않음.
- 작업 트리에는 수치 기준 문서, 앱 탭 현황 문서, 날씨 아이콘 위젯 및 회귀 테스트 변경이 아직 커밋되지 않은 상태임.
- 이번 작업은 상태 확인과 인계 기록만 수행했으며 테스트, 배포, 커밋은 수행하지 않음.

### 3-12 도로살얼음 권장안 재제시
- 기존 조사 내용을 반복 조사하지 않고 공식 도로살얼음 정보 우선, 명시적 관측과 일반 노면결빙의 구분, 세 형성 경로 기반 내부안, 허용·금지 표현을 사용자에게 다시 제시함.
- 사용자가 제품 기본 명칭을 친화적인 `블랙아이스(도로살얼음)`로 정하고 이후에는 `블랙아이스`를 공식 사용하도록 요청해 3-12 문서에 반영함. 사용자 입력의 `도로살어름`은 표준 표기인 `도로살얼음`으로 바로잡음.
- 공식 제공기관이 실제 발생·관측을 명시하면 `발생했어요·관측됐어요` 확정형을 사용하고, 내부 상태는 `생길 수 있어요·생길 위험이 있어요` 가능성 표현을 사용하도록 상태표·판정 원칙·예시를 수정함.
- 기상청의 공식 `발생가능 단계`는 공식 정보이지만 실제 발생·관측 사실은 아니므로 원 단계와 가능성 표현을 유지하도록 구분함.
- 3-12는 사용자 수정사항을 반영했지만 최종 채택 여부는 아직 확인되지 않았으며, 확정 전에는 3-13 조사와 제품 코드·최종 문구 변경을 진행하지 않음.
- 이번 작업은 문서 내용 확인과 권장안 제시만 수행했으며 테스트, 배포, 커밋은 수행하지 않음.

### 기준 채택 3-12 및 검토 3-13: 서리·차량 성에
- 사용자가 3-12 블랙아이스 권장안을 확정해 문서 제목과 채택 상태를 최종 선정안으로 변경함.
- 다음 항목인 3-13 서리·차량 성에를 조사해 `지역 서리`, `차량 외부 성에`, `차량 내부 김서림`, `차량 내부 성에`를 분리하는 미확정 권장안을 작성함.
- 기상청 서리 발생 가능성 서비스는 농업 사전대응용 전국 5km 격자 확률로, 10~5월에 전날 18시~당일 09시를 대상으로 하루 2회 05시·17시에 내일·모레·글피 정보를 제공함. 원 확률·추천 임계값·격자·발표시각을 보존하고 차량별 성에 확률로 바꾸지 않도록 함.
- 공식 관측소의 서리 관측은 관측소 범위에서 `관측됐어요`라고 확정형으로 표시하고, 차량 자료가 없을 때에는 `야외 주차 차량 유리에 성에가 낄 수 있어요` 보조안내까지만 허용하도록 함.
- 차량 성에 내부상태는 외부 유리 표면온도와 서리점 또는 실제 수분막이 있을 때만 `낄 수 있어요·낄 위험이 있어요`로 만들고, 실제 차량 센서·검증된 판별·사용자 확인이 있을 때만 `성에가 확인됐어요`라고 확정하도록 함.
- 차량 내부 김서림은 안쪽 유리 표면온도와 실내 노점, 내부 성에는 안쪽 유리 표면온도와 실내 서리점이 필요하므로 외부 기상 습도로 대신 계산하지 않도록 함.
- 현재 서버의 05~09시 `기온≤0℃ + 습도≥80% 또는 과거 젖음` 기반 `VEHICLE_FROST_RISK` 점수 75는 유리 표면온도·서리점·복사냉각·주차환경을 확인하지 않아 후속 구현에서 제거·분리해야 함을 기록함.
- 행동은 차량별 사용설명서의 서리 제거 기능, 겨울용 와셔액, 얼어붙은 와이퍼 강제 작동 금지, 모든 유리·거울의 시야 확보 후 출발로 연결함.
- 3-13은 사용자 미확정 초안이며, 확정 전에는 다음 항목인 동파 위험으로 넘어가지 않음. 제품 코드와 최종 문구는 변경하지 않았고 테스트, 배포, 커밋도 수행하지 않음.

### 기준 채택 3-13 및 검토 3-14: 동파 위험
- 사용자가 3-13 서리·차량 성에 권장안을 확정해 문서 제목과 채택 상태를 최종 선정안으로 변경함.
- 다음 항목인 3-14 동파 위험을 조사해 기상청 동파가능지수, 지자체·수도사업자 발령, 실제 배관 동결, 실제 계량기·배관 동파, 앱 내부 설비판정, 날씨 보조안내를 분리하는 미확정 권장안을 작성함.
- 기상청 동파가능지수는 기온 기반 공식 생활기상지수이며 11~3월 하루 8회 3시간 간격, `낮음 25·보통 50·높음 75·매우높음 100`으로 제공됨을 확인함. 값을 발생확률로 바꾸거나 앱 기온식으로 복원하지 않도록 함.
- 서울시 2025~2026년 수도계량기 동파대책은 `관심·주의·경계·심각` 4단계와 지역 행동기준을 사용함. 기상청 지수와 서울시 운영단계를 환산·병합하지 않고 각 기관의 원 단계·지역·발표 및 유효시각을 보존하도록 함.
- 지자체·수도사업자의 발령은 `경계가 발령됐어요`처럼 발령 사실을 확정형으로 표시하되, 특정 설비의 동파 발생으로 표현하지 않도록 함. 수도사업자·관리자·검증센서·사용자 확인이 있을 때만 `배관 동결이 확인됐어요·동파가 확인됐어요`라고 확정하도록 함.
- 앱 내부 판단은 실제 기온 시간열과 저온 지속시간뿐 아니라 배관·계량기 온도, 보온 손상·젖음, 실외·외벽·비난방 노출, 외풍, 관경·재질, 물의 정체·사용, 난방상태를 반영한 검증모델이 있을 때만 `얼 수 있어요·동파 위험이 있어요` 가능성 표현을 사용하도록 함.
- 체감온도는 배관 동결 계산에서 제외하고 풍속은 실제 기온 아래로 배관을 낮추는 값이 아니라 냉각속도·외풍 보정으로만 사용하도록 함. 설비자료 없이 실제 기온만 있으면 노출 배관 대상 날씨 보조안내까지만 허용함.
- 국내 외벽측 급수관 연구에서 보온재 두께·손상상태가 동결시간을 크게 바꾸고, 해외 노출 급탕배관 모델에서 30년 시간별 기상·관경·보온·온수 사용이 동결확률에 영향을 준 점을 확인함. 개별 연구의 동결시간·확률을 전국 공통 경계로 복사하지 않도록 함.
- 서울시 최신 대책의 물 흘림 양처럼 지역·기간별 행동수치는 해당 수도사업자의 최신 안내에만 사용하고 전국 공통값으로 고정하지 않도록 함.
- 현재 서버에는 `FREEZE_CAUTION`, `WeatherSnapshot.freezeRisk`, 문구 템플릿만 있고 실제 생성규칙·Provider·필드 사용은 없음. 배관·건물 데이터도 없어 현재 상태로는 신뢰할 수 있는 설비별 동파 판정이 불가능함을 기록함.
- 3-14는 사용자 미확정 초안이며, 확정 전에는 다음 4-1 풍속 단계로 넘어가지 않음. 제품 코드와 최종 문구는 변경하지 않았고 문서 변경이라 테스트·배포·커밋도 수행하지 않음.

### 3-14 내부판정 국내 최근 발생환경 기반 재검토
- 사용자가 동파 앱 내부판정을 기존 조사·연구와 최근 한국 실제 발생환경 중심으로 다시 검토하도록 요청함. 공식 기상청 지수·지자체 발령의 분리와 공식/내부 표현원칙은 유지하고 내부 보조판정만 보완함.
- 서울시 2026년 3월 최근 5년 자료에서 수도계량기 동파 19,010건, 연평균 3,802건이 발생했고 복도식 아파트 약 50%, 연립·다세대 18%, 상가빌딩 15%, 공사현장 10%였음을 확인함. 건물명보다 외부 복도·외기 직접 노출을 입력으로 사용하도록 함.
- 2023년 12월 서울 초기 동파 44건 중 아파트 18건, 그중 16건이 방풍창 없는 복도식이었고 2025년 12월 29일까지 433건 중 아파트가 344건이었음을 확인함. 방풍창과 외기노출을 별도 사용자 프로필로 추가함.
- 서울시 2025~2026년 대책에서 직전 겨울 동파 2,046건의 97%가 보온 미비 또는 장기 부재 가구였음을 확인해 보온재 없음·손상·젖음·틈, 장기 부재·최근 무사용을 `관리취약` 조건으로 묶음.
- 서울시 2026 기계식 계량기 실증에서 `-5℃ 485분·-10℃ 290분·-15℃ 152분·-20℃ 120분`에 동파가 발생하고 디지털 계량기는 시험한 -5~-20℃에서 발생하지 않았음을 확인함. 공개자료에 시험 상세가 제한돼 외기 직접 노출 기계식 계량기의 별도 `MECHANICAL_METER_TEST_WINDOW`에만 사용하고 일반 수도관·보온 계량기·정확한 파손시각으로 확대하지 않음.
- K-water가 22개 지방상수도에서 계량기함 내부온도와 스마트미터 수돗물 사용량으로 0~3단계 가구별 동파위험을 제공했고, 2023년 국내 연구도 외기온도 대신 계량기함 온도와 가상센서 모델을 제안했음을 확인함. 내부판정 우선순위를 `공식 K-water 결과 > 국내 검증 센서모델 > 기계식 계량기 실증창 > 발생환경 결합 > 기온 사전점검`으로 변경함.
- 국내 서울물연구원 실제자료에서 최저기온 3일 평균·지면온도·수온·풍속의 상관이 컸고 -5℃ 한파 1일차와 6일차의 취약시설 유형이 달랐음을 근거로 최근 3일 최저기온과 연속 한파일수를 모델 입력에 추가함. 오래된 서울자료이므로 전국 확률·절대경계로 쓰지 않음.
- 센서가 없는 내부 보조판정은 `-5℃ 이하 사전점검`, `-5~-10℃ + 고노출 AND 관리취약이면 동결 가능`, `-10℃ 이하 + 고노출 또는 관리취약이면 동결 가능`, `-10℃ 이하 2일 이상 + 취약조건 또는 -15℃ 미만 + 취약조건이면 동파 위험`으로 재설계함.
- `고노출`은 방풍창 없는 외부 복도·옥외/공사현장 계량기함·외벽/마당 노출관, `관리취약`은 보온 미비·손상·젖음·틈·장기 부재·최근 무사용으로 정의함. 설비정보 없이 기온만 있으면 가구별 위험이 아니라 사전점검만 제공함.
- 계량기함 온도 범위가 0℃에 닿거나 아래이고 최근 사용량이 없을 때는 `얼 수 있는 온도범위` 가능성만 표시하며 실제 동결·동파로 확정하지 않음. 디지털 계량기 파손 가능성과 연결 배관 동결 가능성도 분리함.
- 새 내부 상태와 국내 근거·제한·표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 3-14에 반영함. 3-14는 여전히 사용자 미확정이며 제품 코드·최종 문구·테스트·배포·커밋은 변경하거나 수행하지 않음.

### Detail 탭 시간별 타임라인 하루치 제한
- Detail 탭의 `타임라인 상세`가 응답의 전체 hourly 목록을 그대로 표시하던 동작을 최대 24개 시간 슬롯만 표시하도록 변경함.
- 30개 시간별 예보가 들어와도 처음 24개만 렌더링되는 위젯 회귀 테스트를 추가함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 27개 모두 통과.

### 기준 채택 3-14 및 검토 4-1: 풍속 단계
- 사용자가 국내 최근 발생환경 중심으로 보완한 3-14 동파 위험 권장안을 확정해 문서 제목과 채택 상태를 최종 선정안으로 변경함.
- 다음 항목인 4-1 풍속 단계를 조사해 기상청 공식 예보용어의 `4·9·14m/s` 경계를 권고하는 미확정안을 작성함. `약한 바람 <4`, `약간 강한 바람 4~9 미만`, `강한 바람 9~14 미만`, `매우 강한 바람 특보 수준 이상 예상`을 사용함.
- 기상청 2025 정책연구가 1994~2023년 국내 30년 풍속 관측분포와 군집화 결과를 검토해 같은 구간을 최종 정성정보안으로 제시했음을 확인함. 현재 앱의 6m/s 경계보다 국내자료를 검토해 공식화된 경계를 우선하도록 함.
- 풍속 숫자·공식 세기 표현은 활동별 위험단계와 분리함. 보행·자전거·운전은 4-4, 우산은 4-5에서 국내 실제 환경 근거를 별도로 검토하고 내부 판단은 `영향을 받을 수 있어요·위험이 있어요` 가능성으로 표현하도록 함.
- 단기·초단기예보는 `예상돼요`, 공식 AWS·ASOS·기상청 실황은 지점·시각·측정종류와 함께 `관측됐어요`, 공식 강풍특보는 `발표됐어요·발효 중이에요`로 표현하도록 분리함.
- 현재 `KmaWeatherProvider`가 단기예보 `getVilageFcst`만 호출하면서 가장 가까운 예보 슬롯을 `current`로 만들고 `forecastAt`을 `observedAt`에도 넣는 문제를 확인함. 현재 값은 관측이 아니라 `현재 시간대 예보`로 표시해야 함.
- 서버와 앱의 `6m/s 이상 주의/STRONG_WIND`, `9m/s 이상 danger`는 공식 단계와 맞지 않음. 6m/s 공통 경계와 명칭은 폐기하고, 9~14m/s는 `강한 바람`으로 표시하되 특보·모든 활동의 위험으로 확정하지 않도록 함.
- 평균풍속과 최대순간풍속, 일반 육상과 산지, 수치기준 접근과 실제 강풍특보 발표를 분리함. 관측 1분·10분 평균, 최대순간풍속, 특보 Provider 부재도 기록함.
- 위 근거, 단계표, 출처별 표현, 데이터 필드, 현재 연결상태와 표현 예시를 `docs/수치_기준_근거자료_선정_항목.md` 4-1 절에 추가함.
- 4-1은 사용자 미확정 권장안이다. 모든 기준 확정 전이라 제품 코드·최종 문구는 변경하지 않았고 문서 변경만 수행해 테스트·배포·커밋도 수행하지 않음. 다음 항목은 4-2 강풍 위험임.

### 4-1 내부 생활판정 국내 피해·활동 근거 재검토
- 사용자가 풍속에 따른 내부 생활판정을 국내 연구·리서치·실제 사건환경을 중심으로 다시 검토하도록 요청함. 공식 풍속 단계 `4·9·14m/s`와 관측·예보·공식특보의 표현 분리는 유지하고 생활판정만 보완함.
- 기상청 2026 정책연구가 소방청의 2014~2024년 강풍 출동 6,581건과 인근 관측을 연결했으며 도로 39%, 건물 23%, 수목·가로수 18%, 가건물 6%였고 최대순간풍속 10~20m/s에 피해신고가 집중됐음을 확인함.
- 위 국내 피해분석을 바탕으로 평균예보 `9m/s 이상`은 준비 확인, 최대순간풍속 `10m/s 이상`은 야외 물건·시설 영향 가능성, 같은 지역·시간의 `10분 평균 14m/s 이상 AND 최대순간 23m/s 이상`은 시설물 파손·낙하물 피해 가능성으로 역할을 분리하는 권장안을 작성함.
- 최대순간 10m/s 구간은 노출빈도를 보정한 개인 사고확률이 아니므로 공통 `위험` 단계가 아니라 사전 준비에만 사용하고, 평균 WSD로 순간풍속을 추정하거나 대체하지 않도록 함.
- 국토교통부 빌딩풍 가이드라인의 보행자 `1시간 평균 15m/s` 안전대책 기준은 국내 보행자료 부족으로 해외기준을 참고한 건물별 풍환경 평가값이므로 격자 WSD에 직접 대입하지 않도록 함.
- 인천연구원 2025년 교량 연구에서 보행자·자전거의 명문화된 악천후 수치기준 공백을 확인해, 두 활동에는 평균 `9m/s`부터 가능성형 준비 안내만 제공하고 자체 통행금지나 확정 위험선을 만들지 않도록 함.
- 기상청 부산·울산·경남 교량 맞춤형 `7·10·15·20m/s` 단계는 해당 교량에만 적용하고, 국내 차량 횡풍 연구의 버스 5~7m/s·승용차 약 13m/s 및 고속도로 15/25m/s 제안값은 차량·속도·노출에 따른 오래된 모형 결과라 일반 도로 통제선으로 확대하지 않도록 함.
- 타워크레인 순간풍속 10/15m/s와 철골작업 10m/s 법정 작업중지 기준은 사용자 작업프로필·현장 측정종류가 정확히 일치할 때만 적용함. 예보 접근은 `넘을 수 있어요`, 현장 확인은 `법정 작업중지 기준에 해당해요`로 구분함.
- 우산 실험은 3.2~7.5m/s에서도 자세·근활성 증가를 확인했지만 보편 사용불가 임계값은 제시하지 않아 강수와 평균 9m/s 또는 최대순간 10m/s가 함께 있을 때만 `우산 사용이 어려울 수 있어요`로 보수적으로 안내함.
- 새 근거표, 내부 상태 8종, 활동별 제한, 데이터 필드와 권장안 8~10번을 `docs/수치_기준_근거자료_선정_항목.md` 4-1에 반영함. 4-1은 여전히 사용자 미확정이며 제품 코드·최종 문구·테스트·배포·커밋은 변경하거나 수행하지 않음.

### 기준 채택 4-1 및 검토 4-2: 강풍 위험
- 사용자가 국내 실제 피해·활동 근거로 보완한 4-1 풍속 단계를 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-2 강풍 위험을 조사해 `공식 발생가능성 정보 → 예비특보 → 주의보·경보 발표/발효 → 해제`의 행정 상태와 관측·예보·앱 내부 피해 가능성을 분리하는 미확정 권장안을 작성함.
- 현행 일반 육상 강풍특보는 주의보 `풍속 14m/s 이상 OR 순간풍속 20m/s 이상`, 경보 `21 OR 26m/s`, 산지는 주의보 `17 OR 25m/s`, 경보 `24 OR 30m/s`가 예상될 때임을 확인함. 육상 기준에는 해상 풍랑특보의 3시간 지속조건을 붙이지 않도록 함.
- 공식 발생가능성 정보, 예비특보, 발표 후 발효 전, 발효 중, 해제를 별도 상태로 보존하고 `발표됐어요·발효 중이에요·해제됐어요`로 확정형 표시함. 공식 강풍 발생가능성 정보는 제공 사실과 원 단계만 확정하고 실제 강풍 발생으로 바꾸지 않음.
- 현재 기상청 대국민 영향예보 공식 설명은 폭염·한파를 대상으로 하므로 강풍 발생가능성 정보를 `강풍 영향예보`로 임의 개명하지 않도록 함. 실제 연계된 공식 원정보가 없으면 제공 중이라고 가정하지 않음.
- 기상청 특·정보 API가 구역, 발표·발효·종료시각, 종류, 수준, 명령을 구조화해 제공함을 확인해 후속 Provider 필드로 기록함. 사용자 위치와 특보구역코드를 정확히 매칭하도록 함.
- 관측값 비교에는 AWS·ASOS의 10분 평균과 최대순간풍속을 분리하고 `관측됐어요 · 주의보/경보 수치 수준이에요`라고 표현하되, 관측값만으로 공식 특보가 발효됐다고 선언하지 않도록 함.
- 국내 강풍 피해분석에서 재난급 사례의 평균풍속은 약 4~5m/s, 90% 이상이 10m/s 이하였지만 최대순간풍속 10~20m/s에 피해가 집중됐음을 확인함. 평균 WSD가 낮다는 이유로 `위험 없음`을 만들지 않고 특보·최대순간풍속이 없으면 `판단자료 부족`으로 처리함.
- 정책연구의 `10분 평균 14m/s AND 최대순간 23m/s`는 강풍 CBS 잠정 제안이므로 4-1의 내부 중대피해 가능성에만 사용하고 현행 공식 특보·재난문자 발송기준으로 표현하지 않도록 함.
- 발생가능성·예비특보에는 창문·옥외물건·시설물 고정, 특보 발효 중에는 야외활동·작업 자제·낙하물 회피·감속과 안전거리, 해제 뒤에는 전깃줄·파손시설 잔류위험 확인을 연결함. 해제를 즉시 `안전`으로 바꾸지 않음.
- 태풍특보는 여러 기상조건으로 발표될 수 있고 풍랑특보는 해상 기준이므로 둘을 육상 강풍특보로 자동 변환하지 않도록 함. 지자체·도로관리기관·소방의 실제 통제·대피·현장 재난문자가 있으면 가장 먼저 표시함.
- 현재 서버의 단일 `STRONG_WIND`는 평균 예보 6m/s부터 생성되고 9m/s부터 심각도 90이며 야외활동·빨래·통근·창문·추위 보정에 함께 사용됨. 특보 Provider와 순간풍속도 없어 후속 구현에서 공식 특보, 관측, 예보 수치비교, 내부 피해 가능성, 활동별 판정으로 분리해야 함을 기록함.
- 4-2는 사용자 미확정 권장안이다. 제품 코드·최종 화면 문구는 변경하지 않았고 문서 변경만 수행했으며 테스트·배포·커밋은 수행하지 않음. 확정 전에는 다음 4-3 돌풍 위험으로 넘어가지 않음.

### 4-2 공식 예보·특보와 내부 피해·활동판정 재분리
- 사용자가 예보와 강풍특보 발표·발효는 공식정보로 안내하고, 내부 피해 가능성·활동별 판정은 국내 연구·리서치·최근 실제 피해환경과 풍속을 근거로 다시 마련하도록 요청함.
- 기상청 「재난문자의 사회·경제적 효과 분석」 원문 PDF의 피해분포와 결론 페이지를 렌더링해 확인함. 재난급 피해는 최대순간풍속 10~20m/s에 집중됐지만 10분 평균은 약 4~5m/s, 90% 이상이 10m/s 이하였고, 잠정 복합조건 `10분 평균 ≥14m/s AND 최대순간 ≥23m/s`는 추가 검증이 필요하다고 명시되어 있었음.
- 보고서의 분석기간 표기가 본문 `2014~2024`와 결론 `2014~2025`로 혼재함을 확인해 세부 연도별 발생률로 재계산하지 않고 피해구간과 측정종류의 한계만 사용하도록 함.
- 공식정보층은 기상청 예보 발표·예보 내용·발생가능성 정보·예비특보·주의보·경보·해제를 원 상태와 시각대로 보존하고, `발표됐어요·발효 예정이에요·발효 중이에요·해제됐어요`로 안내하도록 함. 앱 내부 결과는 예보·예비특보·주의보·경보 명칭을 만들지 않도록 함.
- 내부 시설판정은 평균예보 9m/s 이상 또는 최대순간 10m/s 이상을 사전점검으로 사용하고, 최대순간 10m/s 이상에 미고정·노후 시설, 가건물, 수목, 공사자재, 도심협곡, 해안·산지 노출 중 하나 이상이 있을 때만 비구조재·야외물건 영향 가능성을 만들도록 보완함.
- 같은 지역·시간의 `10분 평균 ≥14m/s AND 최대순간 ≥23m/s`만 내부 중대 시설피해 가능성으로 사용하고, 공식 특보·재난문자 기준으로 표현하지 않도록 함. 최대순간풍속이나 취약조건이 없으면 `판단자료 부족`으로 처리함.
- 2023년 강릉 산불의 북강릉 22.4m/s·동해 30.6m/s, 2025년 경북 산불 확산 시 하회 27.6m/s·영덕 25.4m/s·옥산 21.9m/s·단북 20.4m/s 관측을 최근 국내 사례로 확인함. 두 사건 모두 건조·고온·지형·연료가 결합한 복합재난이므로 단일 생활 풍속 임계값으로 역산하지 않고 산불 확산 가능성의 복합조건 근거로만 사용함.
- 보행·자전거·우산은 평균 9m/s 또는 최대순간 10m/s에 각 활동의 노출·취약조건이 함께 있을 때만 가능성 안내를 제공함. 보행자 높이 1시간 평균 15m/s는 현장센서·건물별 풍환경 평가가 있을 때만 사용하고 전국 격자 보행 위험선으로 쓰지 않도록 함.
- 차량은 터널 출구·교량·해안의 노선 수준 횡풍과 차량종류가 확인될 때 국내 풍동연구의 버스·대형차 7m/s, 승용차 13m/s를 보조값으로만 사용함. 실제 도로·교량 운영기관의 공식 단계와 통제를 우선하고 전국 통제선으로 확대하지 않도록 함.
- 타워크레인·철골작업은 정확한 작업유형과 현장 측정값이 법정 기준에 일치할 때만 `법정 작업중지 기준에 해당해요`라고 확정 안내하고, 예보는 `넘을 수 있어요`로 표현하도록 함.
- 위 근거와 표현 경계, 공식 상태, 내부 피해상태, 활동별 조건, 근거등급, 데이터 필드, 현재 프로젝트 결손을 `docs/수치_기준_근거자료_선정_항목.md` 4-2에 반영함. 4-2는 여전히 사용자 미확정이며 제품 코드·최종 문구·테스트·배포·커밋은 변경하거나 수행하지 않음.

### 4-2 내부 피해·활동판정 가능성 문구 통일
- 사용자가 앱 내부 피해 가능성과 활동별 판정에는 모두 가능성이 있다는 느낌의 문구만 사용하도록 요청함.
- 4-1과 4-2의 내부판정 사용자 문구를 `~할 수 있어요·~될 수 있어요·~하기 어려울 수 있어요` 계열로 통일함.
- 내부 사전점검 문구를 `야외 물건과 이동 경로를 확인해요`에서 `가벼운 야외 물건이 움직일 수 있어요`로, 중대 시설피해 문구를 `피해 위험이 있어요`에서 `시설물이 파손되거나 낙하물이 생길 수 있어요`로 변경함.
- 우산·교량 노출·창문·옥외물건·야외건조물 문구에서 `고려해요·감속해요·확인해요` 같은 명령형을 제거하고 모두 영향 가능성 문장으로 변경함.
- 특정 교량·도로의 공식 단계·통제정보와 현장 작업의 법정 기준 해당 사실은 내부 활동판정에서 제외함. 발신기관·적용노선·현장 측정값이 확인된 경우에만 공식정보층에서 `안내됐어요·기준에 해당해요`처럼 확정형으로 표시하도록 분리함.
- 내부판정에는 `~해야 해요·~하세요·위험해요·통행금지예요·사용할 수 없어요`를 사용하지 않는 금지 원칙을 문서에 명시함. 공식 관측·특보·기관 통제·확인된 현장 사실만 확정형을 유지함.
- 4-2는 여전히 사용자 미확정이며 제품 코드·최종 화면 문구는 변경하지 않았고 테스트·배포·커밋도 수행하지 않음.

### 기준 채택 4-2 및 검토 4-3: 돌풍 위험
- 사용자가 공식 예보·특보와 내부 피해·활동판정을 분리하고 내부 문구를 가능성형으로 통일한 4-2 강풍 위험을 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-3 돌풍 위험을 조사해 기상청 예보문의 돌풍 가능성, 공식 최대순간풍속 예측, 관측된 최대순간풍속, 공식적으로 확인된 돌풍 발생, 앱 내부 영향 가능성을 분리하는 미확정 권장안을 작성함.
- 기상청 대국민 기상특보 11종에는 별도 `돌풍주의보·돌풍경보`가 없고 순간풍속 기준은 강풍특보에 포함됨을 확인함. 앱이 별도 돌풍특보 명칭·단계를 만들지 않도록 함.
- 예보 발표 사실은 `발표됐어요`, 예보 내용은 `돌풍 가능성이 안내됐어요·예상돼요`, 공식 최대순간 관측은 `관측됐어요`, 기상청 사후분석이 명시한 실제 돌풍은 `발생했어요·확인됐어요`로 구분함.
- 공식 최대순간풍속 하나는 관측된 극값 사실만 보여주므로 앱이 `돌풍이 관측됐어요`로 바꾸지 않도록 함. 시간별 단기예보 WSD만으로 최대순간풍속·돌풍계수·돌풍 가능성을 추정하지 않도록 함.
- 항공기상 통계의 GUST는 10분 평균보다 10KT 이상 강한 3초 평균을 사용하는 전용 정의임을 확인함. 이를 전국 육상 생활돌풍 임계값으로 확대하지 않고 항공 관측체계에서만 보존하도록 함.
- 국립기상과학원 연구진의 2025년 농경지 연구는 3m 고도 LENS·AAOS 돌풍 확률 예측을 검증했고 `10m/s` 기존 방법과 `17m/s` 검증수준을 다뤘음. 두 값을 일반 생활피해선으로 사용하지 않고 지역·높이·기간이 검증된 농업 전용모델에만 적용하도록 함.
- 국내 68개 관측소의 지표면조도별 돌풍률 연구에서 주변환경에 따라 평균·3초 가스트 관계가 달라짐을 확인해 전국 공통 돌풍계수를 두지 않도록 함.
- 2023년 상주 과수 맞춤형 서비스가 돌풍을 일최대순간풍속과 예상시각으로 제공하고 소나기·우박·돌풍 가능성을 문자로 전달한 사례를 확인함. 공식 전용상품이 실제 제공되는 지역에서만 원 값·시간을 사용하도록 함.
- 2025년 경북 산불 때 기상청이 매우 강한 바람과 돌풍 발생을 공식 분석했고 하회 27.6m/s·영덕 25.4m/s·옥산 21.9m/s·단북 20.4m/s 최대순간풍속을 제시했음을 확인함. 고온·건조·기압계·지면가열이 겹친 복합사례라 일반 돌풍 발생선으로 역산하지 않도록 함.
- 내부 영향 가능성은 공식 돌풍 문구와 노출조건의 결합 또는 `최대순간 ≥10m/s AND 취약·노출조건`에서만 만들고 모두 `영향을 받을 수 있어요·움직일 수 있어요·파손될 수 있어요`처럼 가능성형으로 표현하도록 함. `10분 평균 ≥14m/s AND 최대순간 ≥23m/s`는 4-2의 잠정 중대 시설피해 가능성으로만 재사용함.
- 소나기·천둥·번개·우박만으로 돌풍을 추론하지 않고 기상청 원 예보가 돌풍을 함께 명시하거나 검증된 전용모델이 있을 때만 대류성 돌풍 가능성을 만들도록 함.
- 현재 프로젝트에는 일반 WSD만 있고 공식 돌풍 예보문, 최대순간 예측·관측, 기상속보·사후분석 Provider와 노출·농업 입력이 없어 4-3 상태를 생성할 수 없음을 기록함.
- 4-3은 사용자 미확정 권장안이다. 보행·자전거·운전은 4-4, 우산은 4-5에서 별도 검토하며 제품 코드·최종 화면 문구·테스트·배포·커밋은 변경하거나 수행하지 않음.

### 최신 UI 문구 문서 반영 및 Setting 공통 헤더 적용
- 마지막 커밋 `문구 변경`의 UI 명칭을 확인해 `Check List`, `간단한 타임라인`, `챙길 이유`, `타임라인`, `한눈에 보는 이번주`를 `docs/앱_탭_구성_현황.md`와 앱 개발명세 DOCX에 반영함.
- 앱 개발명세의 Setting 설명에 `SETTING / 설정` 공통 페이지 헤더와 `안전과 간단한 타임라인 알림을 관리해요` 문구를 반영하고, Detail의 최대 24개 시간 슬롯 표시도 함께 기록함.
- Setting 탭의 기존 개별 제목/설명 영역을 `TabPageHeader`로 교체하고 `SETTING`, `설정`, 설명 문구, 설정 아이콘을 다른 탭과 같은 구조로 표시함.
- 회귀 테스트에 embedded Setting의 공통 헤더 구조 검증을 추가함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 28개 모두 통과.
- 앱 개발명세는 Microsoft Word로 14페이지를 PDF/PNG 렌더링해 전 페이지를 확인했으며 잘림·겹침·표 깨짐·한글 깨짐이 없음. 기본 `render_docx.py`는 LibreOffice 실행 파일 부재로 실패해 Word 렌더링으로 대체함.

### 기준 채택 4-3 및 검토 4-4: 보행·자전거·운전 위험 풍속
- 사용자가 예보·특보·관측·확인된 발생은 확정형으로, 앱 내부 피해·활동판정은 가능성형으로 분리한 4-3 돌풍 위험을 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-4 보행·자전거·운전 위험 풍속을 국내 연구·정책자료·실제 운영환경 중심으로 조사해 미확정 권장안을 작성함.
- 확인한 국내 자료에는 전국 보행자·자전거·운전자 개인사고를 같은 위치·시각의 풍속·활동노출과 연결한 공통 임계값이 없어 세 활동에 공통인 `안전·주의·위험·통제` 풍속표를 만들지 않도록 함.
- 도로관리기관의 실제 감속·차종 제한·보행자 또는 자전거 진입 제한·전면 통제는 노선·방향·대상·시각과 함께 `안내됐어요·시작됐어요·해제됐어요`로 확정 안내하고 앱 내부 가능성과 분리함.
- 기상청 부산·울산·경남 교량 맞춤형 `7·10·15·20m/s` 단계는 해당 교량의 공식 원정보로만 사용함. 맞춤형 정보의 조치사항과 도로관리기관이 실제 시행한 통제를 별도 상태로 보존하고 전국 일반도로로 확대하지 않도록 함.
- 2025년 인천연구원 제3연륙교 연구가 교량의 국지풍, 보행자·자전거·고상차량 노출과 현장센서 필요성을 제시했음을 확인함. 부록의 `10·15·20·25m/s` 통제안은 지역 조례·운영 제안이므로 시행 중인 공식기준으로 표시하지 않도록 함.
- 보행·자전거는 `평균풍속 예보 ≥9m/s OR 공식 최대순간풍속 ≥10m/s OR 공식 돌풍 가능성·강풍특보`에 교량·해안·산지·개방지·도심협곡 등 노출조건이나 이용자 취약조건이 겹칠 때만 영향 가능성을 만들도록 함. 이 값은 사고 발생선이나 통행금지선이 아님.
- 보행자 높이 `1시간 평균 15m/s`는 국토교통부 빌딩풍 가이드라인의 건물별 E등급 안전대책 검토값이므로 현장센서·풍동·CFD가 있는 해당 건물 주변에만 사용하고 격자 WSD에 적용하지 않도록 함.
- 국내 2007년 터널 출구 횡풍 풍동연구의 대형버스 `5~7m/s`, 승용차 약 `13m/s` 결과는 보수적으로 횡풍성분 `7·13m/s`의 내부 보조값으로만 사용함. 노선방향·같은 위치와 시간의 풍향·풍속·차량종류가 있을 때만 적용하고 공식 감속·통제선으로 사용하지 않도록 함.
- 내부 사용자 문구는 모두 `균형을 잡기 어려울 수 있어요·옆바람의 영향을 받을 수 있어요·진행 방향이 흔들릴 수 있어요·조향과 제동이 어려울 수 있어요`처럼 가능성형으로 작성함.
- 서버에는 단기예보 `WSD·VEC`가 있으나 앱이 풍향을 보존하지 않고, 양쪽 모두 최대순간·현장센서·노선구간·활동·차량·공식통제 정보가 없어 현재 4-4 상태를 완전하게 생성할 수 없음을 기록함.
- 제품 코드와 최종 화면 문구는 변경하지 않았고 문서만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-4는 사용자 미확정 권장안이며 확정 후 다음 항목은 4-5 우산 사용이 어려운 풍속임.

### Detail 타임라인 한국시간 오늘 날짜 제한
- 기존 구현은 날짜를 확인하지 않고 첫 예보부터 24개 항목을 표시해, 오후 조회 시 다음 날 예보가 섞일 수 있었음을 확인함.
- `HourlyWeatherItem.forecastDate`를 추가해 운영 서버의 `forecastAt`/`observedAt` 날짜와 앱 직접 기상청 조회의 한국시간 날짜를 보존함.
- Detail 타임라인은 날짜 정보가 있는 예보를 한국시간 기준 오늘 날짜로 필터링함. 오늘이 24일이면 24일 23시까지만 표시하고 25일 예보는 제외함.
- 날짜 정보가 없는 레거시 데이터는 기존 호환성을 위해 최대 24개 표시를 유지함.
- `docs/앱_탭_구성_현황.md`와 앱 개발명세 DOCX의 기존 `첫 예보부터 최대 24개` 설명을 오늘 날짜 기준으로 정정함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 28개 모두 통과.
- 앱 개발명세는 Microsoft Word로 14페이지를 PDF/PNG 렌더링해 전 페이지를 확인했으며 잘림·겹침·표 깨짐·한글 깨짐이 없음. 기본 `render_docx.py`는 LibreOffice 실행 파일 부재로 실패해 Word 렌더링으로 대체함.

### Main 상단 카드 어제 비교 및 세로 스크롤
- 첨부 화면을 시각 참고자료로 사용하고, Main 최상단 카드에 현재 기온·체감온도와 함께 `어제와 비교` 패널을 추가함.
- 비교 패널은 어제와 오늘의 하늘 상태, 기온 차이, 체감온도 차이, PM2.5 우선 미세먼지 차이를 `어제보다 … 높아요/낮아요/많아요/적어요` 형식으로 표시함. 어제 저장값이 없거나 운영 서버가 연결되지 않으면 비교 데이터가 쌓일 때 표시된다는 정상 안내를 제공함.
- Main의 고정 높이·`Expanded` 구성을 `CustomScrollView`와 `SliverList` 기반 자연 높이 구성으로 교체함. 상단 브리핑은 말줄임 없이 표시하고 생활 날씨 카드까지 아래로 스크롤되며, 하단 탭과 당겨서 새로고침은 기존대로 유지함.
- 앱의 `ComparisonResponse`를 타입이 지정된 비교 모델로 교체하고 Home이 Today 조회 성공 후 어제 비교 API를 함께 불러 Main에 전달하도록 연결함.
- 운영 Worker는 Today 조회 때 현재 기온·체감온도·PM10·PM2.5·하늘 상태를 기존 D1 일별 스냅샷 테이블에 한국시간 날짜로 저장하고, 비교 API가 한국시간 기준 어제 행을 반환하도록 수정함. 기존 저장소의 잘못된 컬럼 조회와 중복 PM2.5 조회도 바로잡음.
- Worker의 D1 접근은 `D1Database` 타입과 준비된 문장을 사용하고, 응답 지연이나 저장 실패가 Today 응답을 깨뜨리지 않도록 `executionCtx.waitUntil` 백그라운드 저장과 구조화 오류 로그를 적용함.
- `docs/앱_탭_구성_현황.md`와 앱 개발명세 DOCX에 Main 어제 비교 데이터·빈 상태·세로 스크롤 계약·회귀 기준을 반영함. DOCX 표에 남아 있던 `스크롤 금지`와 `Expanded` 문구도 새 계약으로 정정함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 29개 통과, `npx tsc --noEmit` 통과, 서버 `npm test` 39개 통과.
- Android 에뮬레이터와 로컬 Wrangler/D1을 연결해 어제 비교값이 실제 화면에 표시되고 Main이 아래로 스크롤되며 고정 하단 탭과 레이아웃 오버플로가 정상인지 확인함. 검증용 D1 행과 임시 Wrangler 서버는 확인 후 제거함.
- 앱 개발명세는 Microsoft Word로 14페이지를 PDF/PNG 렌더링해 전 페이지를 재확인했으며 잘림·겹침·표 깨짐·한글 깨짐이 없음. 기본 `render_docx.py`는 LibreOffice 실행 파일 부재로 실패해 Word 렌더링으로 대체함.

### Main 체감 안내 배치와 문구 가독성 개선
- Main 상단 카드에서 체감온도 오른쪽에 있던 짧은 날씨 표현과 하늘 상태 아이콘을 체감온도 아래의 독립 행으로 이동함.
- 체감 안내를 `하늘 상태 문장 + 체감온도 기준으로 느껴질 수 있는 정도`의 두 문장으로 확장하고, 말줄임 없이 자연스럽게 줄바꿈하도록 함.
- 체감 안내 글자 크기를 기존 11pt에서 13pt로 키우고 날씨 아이콘도 compact 20px·기본 23px로 조금 확대함.
- 위젯 회귀 테스트에 체감 안내 문구, 13pt 글자 크기, 체감온도 행보다 아래에 배치되는지 검증을 추가함.
- `docs/앱_탭_구성_현황.md`의 Main 상단 카드 설명을 새 배치와 문구 규칙으로 갱신함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 29개 통과, 서버 `npx tsc --noEmit` 통과, `npm test` 39개 통과.
