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
