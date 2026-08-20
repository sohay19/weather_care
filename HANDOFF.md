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
