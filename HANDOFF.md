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

### 기준 채택 4-4 및 검토 4-5: 우산 사용이 어려운 풍속
- 사용자가 공식 노선 바람정보·통제와 보행·자전거·운전의 내부 영향 가능성을 분리한 4-4를 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-5 우산 사용이 어려운 풍속을 국내 공식기준·인체공학 연구·최근 피해환경과 해외 보조연구를 대조해 미확정 권장안으로 작성함.
- 기상청에는 우산 전용 주의보·경보가 없고, 확인한 국내 자료에도 우산을 든 한국인의 상해·넘어짐·제품파손을 같은 위치·시간의 풍속과 연결한 공통 사고 임계값이 없어 앱이 우산 공식단계·사용금지를 만들지 않도록 함.
- 기상청 풍력계급 교육자료는 보퍼트 6계급 `10.8~13.8m/s`에서 우산 사용 어려움을 설명하지만 한국인 실험이나 공식 통제기준은 아니므로 정성 보조근거로만 사용하도록 함.
- 2024년 한국 연구진 참여 성인 17명 우산 조작성 실험에서 `3.2~7.5m/s` 바람에 주관적 자세변동과 손목 폄근 활성도가 커졌지만 객관적 자세변동과 보편 사용불가·파손 임계값은 확인되지 않았음. 참가자 국적·실험지역도 초록에 명시되지 않아 한국인 대표 표본으로 취급하지 않도록 함.
- 국가기술표준원의 현행 우산 구조안전성 시험은 풍향 쪽 `45±1°`, `12±0.5m/s`, `20초` 조건에서 절단·구부러짐이 없어야 하는 제품 시험임을 확인함. 이를 사람의 안전 사용풍속, 특정 제품의 내풍보증 또는 `12m/s부터 파손`으로 해석하지 않도록 함.
- 내부 낮은 부담 가능성은 강수·도보 외출과 `평균 4m/s 이상 9m/s 미만`에 긴 노출·큰 캐노피·한 손 짐·유아동반·고령·손목/악력 취약·교량·해안·개방지 중 하나 이상이 겹칠 때만 만들도록 함.
- 안정적 사용 어려움 가능성은 강수·도보 외출과 `평균 ≥9m/s OR 공식 최대순간 ≥10m/s OR 공식 돌풍 가능성 OR 강풍특보`가 겹칠 때 만들고 `우산이 흔들려 안정적으로 사용하기 어려울 수 있어요`처럼 가능성형으로만 안내하도록 함.
- `15mm/h 이상` 강수의 우산 차폐 부족 가능성은 풍속 조작성과 분리해 `우산을 써도 옷이 젖을 수 있어요`로 안내하고, 두 조건이 겹치면 강한 비와 바람이라는 원인을 모두 보존하도록 함.
- 공식 낙뢰 예상·관측이 있으면 기상청의 우산보다 비옷 준비와 안전장소 대피 행동요령을 일반 우산 편의판정보다 우선함. 공식 제공 사실은 확정형, 내부 노출판정은 `낙뢰에 노출될 수 있어요`처럼 가능성형으로 분리함.
- 현재 서버는 강수확률 `40%` 또는 강수량 하한 `0.5mm`부터 `RAIN_LIKELY → RAIN_GEAR_USEFUL → UMBRELLA`를 만들며 바람·강우차폐·낙뢰·외출·우산특성을 구분하지 않음. 추천문구도 `챙겨요·확인하세요` 형태라 후속 구현에서 가능성형 상태로 분리해야 함을 기록함.
- 제품 코드와 최종 화면 문구는 변경하지 않았고 문서만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-5는 사용자 미확정 권장안이며 확정 후 다음 항목은 4-6 실내 적정 습도임.

### Detail 타임라인 한국시간 오늘 날짜 제한
- 기존 구현은 날짜를 확인하지 않고 첫 예보부터 24개 항목을 표시해, 오후 조회 시 다음 날 예보가 섞일 수 있었음을 확인함.
- `HourlyWeatherItem.forecastDate`를 추가해 운영 서버의 `forecastAt`/`observedAt` 날짜와 앱 직접 기상청 조회의 한국시간 날짜를 보존함.
- Detail 타임라인은 날짜 정보가 있는 예보를 한국시간 기준 오늘 날짜로 필터링함. 오늘이 24일이면 24일 23시까지만 표시하고 25일 예보는 제외함.
- 날짜 정보가 없는 레거시 데이터는 기존 호환성을 위해 최대 24개 표시를 유지함.
- `docs/앱_탭_구성_현황.md`와 앱 개발명세 DOCX의 기존 `첫 예보부터 최대 24개` 설명을 오늘 날짜 기준으로 정정함.
- 검증 결과: `flutter analyze` 이슈 없음, `flutter test` 28개 모두 통과.
- 앱 개발명세는 Microsoft Word로 14페이지를 PDF/PNG 렌더링해 전 페이지를 확인했으며 잘림·겹침·표 깨짐·한글 깨짐이 없음. 기본 `render_docx.py`는 LibreOffice 실행 파일 부재로 실패해 Word 렌더링으로 대체함.

### 기준 채택 4-5 및 검토 4-6: 실내 적정 습도
- 사용자가 국내 근거와 가능성형 내부문구를 반영한 4-5 우산 사용이 어려운 풍속을 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-6 실내 적정 습도를 환경부·질병관리청 지침, 현행 시설별 법정기준, 부산의 2019·2024년 실제 취약시설 조사와 현재 프로젝트 구현을 대조해 미확정 권장안으로 작성함.
- 일반 주거·생활공간의 대표 실내 상대습도 목표는 환경부·질병관리청의 `40~60%`로 권장함. 이를 모든 사람·시설의 법정 안전선, 질병 예방선, 개인 최적값으로 표시하지 않도록 함.
- 학교 교실의 법정 조절기준 `30~80%`, 적용 대상 근로자 휴게시설의 `50~55%를 유지할 수 있는 설비기능`을 일반 목표와 목적이 다른 시설별 공식기준으로 분리함. 개인용 센서값으로 공식 법정 적합·위반을 확정하지 않도록 함.
- 질병관리청 아토피피부염 예방관리수칙은 환자에 따라 편안한 조건을 유지하도록 하면서 `40~50%`를 참고범위로 제시함을 반영해 질환·민감사용자는 의료진·질환별 지침·개인 반응을 일반 범위보다 우선하도록 함.
- 부산 2019년 소규모 어린이집 조사에서 실제 습도 `28~81%`, 적정범위 이탈 `49.7%`, 여름철 이탈 `66.9%`가 보고됐음을 국내 실제 환경근거로 사용함. 이를 전국 주택 분포나 개인 건강확률로 확대하지 않도록 함.
- 부산 2024년 취약계층 이용시설 152곳 조사에서 `25℃ 이상·습도 60% 이상`이 많았던 6~10월에 폼알데하이드·총부유세균·부유곰팡이가 상대적으로 높았고 연구진이 해당 시설의 `25℃ 미만·50% 미만` 관리를 제안했음을 확인함. 지역 관찰조사이므로 일반 목표를 40~50%로 좁히거나 60%를 곰팡이 발생선으로 쓰지 않도록 함.
- 공식 지침·법정기준·검사결과·기상청 실외 관측은 `안내하고 있어요·기준은 30~80%예요·관측됐어요`, 등록된 실내 센서의 직접 측정은 방과 시각을 붙여 `측정됐어요`로 확정 안내하도록 함.
- 앱 내부 목표범위·쾌적성·시설범위 연결은 `무난하게 느껴질 수 있어요·범위와 가까울 수 있어요·판단하기 어려울 수 있어요`처럼 가능성형으로만 안내하고 `안전·정상·쾌적·위험` 확정등급을 만들지 않도록 함.
- 기상청 단기예보 `REH`는 실외 격자 상대습도이므로 실내 습도나 제습·가습 필요성에 직접 대입하지 않도록 함. 실내 판정에는 실내 센서값, 같은 위치·시각의 온도, 방·센서 위치, 정확도·품질·보정정보가 필요함.
- 현재 서버는 실외 `humidity`에 `low=35·high=80`을 적용하고 이를 `DEHUMIDIFIER_USEFUL/HUMIDIFIER_USEFUL`로 연결하며, 앱은 `35 이하·70~79 주의, 80 이상 위험, 그 밖 안전`으로 표시함을 확인함. 후속 구현에서 `outdoorRelativeHumidity`와 `indoorRelativeHumidityMeasurement`를 분리해야 함.
- `40·60%` 단일 순간 초과로 즉시 경고하거나 이번 항목만으로 제습기·가습기를 추천하지 않도록 함. 센서 불확도·응답시간과 4-7~4-10 고습·저습·제습·가습 근거가 확정된 뒤 지속시간과 히스테리시스를 정하도록 함.
- 제품 코드·최종 화면 문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-6은 사용자 미확정 권장안이며 확정 후 다음 항목은 4-7 고습·불쾌감임.

### 4-6 실내 적정 습도 체감근거 보완
- 사용자가 특정 온습도에서 사람들이 실제로 어떻게 느끼고 행동했는지 연구·리서치·뉴스를 참고해 체감 기준을 보강하도록 요청함. 4-6은 아직 사용자 미확정 상태를 유지함.
- 한국 대학생 14명의 여름 환경챔버 연구에서 `24~30℃·40~80%`의 8개 온습도 조합을 각 3시간 경험하게 하고 온열감·쾌적감을 15분마다 조사한 원문을 전 페이지 확인함. 온열감과 쾌적감은 관련됐지만 습도 단독 체감 임계값은 제시되지 않았고 반복성·의복·지역·노출이력 한계가 보고돼 온도·습도·기류·활동·의복을 함께 보는 근거로만 사용함.
- 서울 공동주택 실거주자의 평균 냉방 시작 `29.76℃`·종료 `27.31℃`, 서울 계절별 24·6·36가구의 온열감·냉난방 행동, 2014~2016년 대구 공동주택의 TSV·CSV·PD 기반 수용영역, 국내 11가구의 온열민감도 `0.356/K`, 국내 사무실 참가자 22명의 `쾌적감·만족도와 덥고 추운 정도는 같지 않음`, 2025년 한국 남자대학 기숙사 20개 방의 온습도·CO2·만족도 결과를 체감 보정근거로 추가함.
- 해외 보조 인체실험도 대조함. `26℃·10%`에 노출된 25명에서도 보편적인 건조·불쾌 응답은 나타나지 않았으나 눈·코·목·입술의 국소 건조감이 두드러졌고, `26.6·30.6·37.4℃`에서 `50%·70%`를 비교한 24명 연구는 높은 습도의 체감영향이 온도에 따라 달라짐을 보였음. 두 연구 모두 한국인 대표값이나 앱의 단독 임계값으로 사용하지 않도록 함.
- `40~60%`는 공식 일반 안내범위로 유지하되 체감은 별도 가능성 상태로 분리함. 겨울 `18~21℃·40~60%`, 여름 `24~27℃·40~60%`와 유효한 실내센서·예외 없음이 함께 있을 때만 `무난하게 느껴질 수 있어요`라는 낮은 강도의 내부 가능성을 만들도록 보완함.
- 같은 방·계절·활동수준에서 반복된 사용자 체감응답이 있으면 일반 연구값보다 개인 이력을 우선하는 `PERSONAL_COMFORT_MATCH_POSSIBLE`을 추가함. 단일 응답이나 다른 공간·계절로 개인 최적범위를 확정하지 않도록 함.
- 같은 지점의 온도나 기류·냉난방·활동 맥락이 부족하면 `습도만으로는 덥거나 건조하게 느낄지 판단하기 어려울 수 있어요`로 낮추고, `60%면 습함·70%면 불쾌·30%면 누구나 건조` 같은 습도 단독 체감표를 금지함. 고습·불쾌감과 저습·건조의 조합·지속시간은 4-7·4-8에서 별도 검토함.
- 체감 개인화를 위해 `indoorComfortContext`와 `userComfortFeedback` 데이터 요구사항을 추가함. 제품 코드·최종 화면 문구는 변경하지 않았고 테스트·배포·커밋은 수행하지 않음.

### 4-6 친화적 체감 표현 보완
- 사용자가 `끈적하다`처럼 수치보다 바로 이해되는 다양한 일상 표현으로 체감느낌을 알려줄 수 있는지 요청함. 4-6은 아직 사용자 미확정 상태를 유지함.
- 내부 과학적 상태와 사용자 문구를 분리하고 `무난·눅눅·후텁지근·피부 끈적임·땀이 잘 마르지 않는 느낌·서늘하고 축축함·답답함·메마름·눈·코·목·입술 마름·피부 당김·거침`의 친화적 체감 표현 사전을 추가함.
- 각 표현은 모두 `~하게 느껴질 수 있어요` 가능성형으로 끝내도록 함. `끈적임`은 따뜻하고 습한 조합과 활동·의복·개인이력, `땀이 잘 마르지 않음`은 발한 가능성이 있는 활동, `답답함`은 CO2·환기 부족·사용자 반복응답, 국소 건조감은 저습과 민감도·노출·개인이력이 함께 있을 때만 사용하도록 조건을 분리함.
- 같은 상태에서 여러 동의어를 무작위 노출하지 않고 대표 체감 1개와 필요한 경우 신체 체감 1개까지만 표시하도록 함. `눅눅·끈적·후텁지근·답답`을 한 화면에 모두 나열해 가능성을 과장하지 않도록 함.
- 사용자 직접 응답 선택지로 `무난해요·눅눅해요·후텁지근해요·끈적해요·답답해요·메말라요·눈·코·목이 말라요·피부가 당겨요·잘 모르겠어요`를 제안함. 응답 사실과 앱 추론을 분리하고 이후 앱 안내는 계속 가능성형으로 생성하도록 함.
- `userComfortFeedback`과 `perceptionPhrase` 데이터 요구사항, 표현 연결 예시를 문서에 반영함. 4-7·4-8에서 고습·저습의 온습도 조합과 지속시간을 확정한 뒤 표현 발동조건을 연결하며, 제품 코드·최종 화면 문구는 변경하지 않았고 테스트·배포·커밋은 수행하지 않음.

### 기준 채택 4-6 및 검토 4-7: 고습·불쾌감
- 사용자가 실내 적정 습도와 친화적 체감 표현을 확정해 4-6 제목·상태를 채택으로 변경함.
- 다음 항목인 4-7 고습·불쾌감을 기상청 현행 체감온도 산식·2026년 폭염/열대야 특보, 한국 인체실험, 최근 수도권 주택 냉방행동, 2024년 한국 대학기숙사 실측·만족도 자료와 현재 프로젝트 구현을 대조해 미확정 권장안으로 작성함.
- 기상청 여름철 체감온도 산식은 실외 `기온+상대습도` 결합효과를 산출하는 공식 근거로 사용하되, 앱이 `TMP·REH`로 계산한 값과 기상청이 직접 발표·관측한 값을 산출주체·예보/관측·산식버전으로 구분하도록 함. 실외 산식을 실내 쾌적성에 적용하지 않도록 함.
- 열지수·불쾌지수 서비스가 2020년 9월 이후 종료되고 생활기상지수 체감온도 서비스도 2026년 5월 11일 종료됐음을 확인함. 옛 불쾌지수 `68·75·80`과 불쾌인원 비율을 현재 공식단계 또는 한국인 대표 체감비율로 사용하지 않도록 함.
- 2026년 6월 1일부터 폭염주의보 `일 최고 체감온도 33℃ 이상 2일 예상`, 경보 `35℃ 이상 2일 예상`, 중대경보 `35℃ 이상 2일 관측 지역에서 체감온도 38℃ 이상 또는 기온 39℃ 이상 1일 예상` 기준이 운영됨을 반영함. 실제 발표·발효·해제만 확정 안내하고 한 시점 앱 계산값으로 특보를 추정하지 않도록 함.
- 한국 대학생 14명의 `24~30℃·40~80%` 챔버 실험은 온도·습도·기류·의복·활동의 조합과 개인차를 지지하지만 습도 단독 보편 불쾌선을 제시하지 않았음을 반영함.
- 서울·경기·인천 주택의 2004·2007·2024년 비교에서 2024년 에어컨 가동 시작 `29.02℃`, 종료 `26.99℃`로 2004년보다 약 `1.2℃` 낮고 실내온도 변동이 작아졌음을 확인함. 시대·기기·선호에 따라 냉방행동이 달라진 근거로만 사용하고 습도 임계값으로 확대하지 않도록 함.
- 2024년 9월 한국 남자대학 기숙사 20개 방에서 평균 상대습도 `86.4~88.5%`가 측정되고 높은 평균·중앙값·최저습도가 전반적 만족도와 음의 상관을 보였지만, 온도 만족도 `5.7/7`·전체 실내환경 만족도 `5.3/7`로 모두가 불만족한 것은 아니었음을 반영함. 고습 지속성과 개인차의 직접근거로만 사용함.
- 실외 잠정 상태는 `기온 ≥27℃ AND RH ≥60% AND 기상청식 앱 계산 체감온도 ≥28℃ AND 체감-기온 ≥0.8℃`를 2개 예보슬롯에서 충족할 때 `습도가 더해져 후텁지근하게 느껴질 수 있어요`로 제안함. `기온 ≥28℃·RH ≥70%·계산 체감 ≥30℃`에 발한활동이 확인될 때만 끈적임·땀이 잘 마르지 않는 느낌을 보조문구로 허용함.
- 실내 잠정 상태는 `RH ≥65%·2시간` 눅눅 가능성, `온도 ≥28℃·RH ≥60%·30분` 후텁지근 가능성, 따뜻하고 습한 상태에 `RH ≥70%`와 활동·약한 기류·반복 개인응답 중 하나가 있을 때 끈적임 가능성, `온도 ≤24℃·RH ≥70%·2시간` 서늘하고 축축할 가능성으로 제안함.
- 최근 국내 기숙사의 장시간 고습 결과를 반영해 직전 24시간 유효측정의 80% 이상이 `RH ≥80%`일 때 오래 눅눅하게 느껴질 가능성을 별도 잠정상태로 두고, 순간값보다 지속시간을 우선하도록 함. 모든 정확한 진입값·지속시간은 C등급 잠정 운영값이며 공식 위험선·보편 불쾌 발생선이 아님을 명시함.
- `눅눅·후텁지근·끈적·땀이 잘 마르지 않음·서늘하고 축축`을 온도·활동 맥락에 맞춰 대표 1개와 필요시 신체체감 1개까지만 사용하도록 함. `답답함`은 CO2·환기 또는 반복된 사용자 응답 없이는 습도만으로 생성하지 않도록 함.
- 공식 예보·관측·특보·센서 측정 사실은 `발표됐어요·예상돼요·관측됐어요·발효 중이에요·측정됐어요`, 모든 앱 내부 체감·피해·활동판정은 `~하게 느껴질 수 있어요·~하기 어려울 수 있어요` 가능성형으로 제한함.
- 현재 앱은 실외 습도 `70~79 주의·80 이상 위험`, 계산 체감온도 `28·33·35·38` 고정등급을 표시하고 서버는 실외 `humidity ≥80`을 `HUMIDITY_HIGH → VERY_HOT_AND_HUMID/DEHUMIDIFIER_USEFUL`로 연결함을 확인함. 실내·실외 분리, 공식/앱 계산 분리, 실외 습도의 실내 제습 연결 제거가 필요함을 기록함.
- 원문 PDF 2개는 PDF 스킬 절차에 따라 전 페이지를 PNG로 렌더링해 표·본문을 육안 확인했으며 임시 렌더 이미지는 작업 종료 전에 제거함. 원문 PDF는 근거 재검토용으로 `tmp/pdfs/`에 남김.
- 제품 코드·최종 화면 문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-7은 사용자 미확정 권장안이며 확정 후 다음 항목은 4-8 저습·건조임.

### 기준 채택 4-7 및 검토 4-8: 저습·건조
- 사용자가 온도·습도·활동·지속시간과 다양한 친화적 표현을 결합한 4-7 고습·불쾌감 권장안을 확정해 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-8 저습·건조를 기상청 현행 건조특보, 질병관리청 실내환경 안내, 한국 겨울 아파트 현장측정, 최근 한국인 피부실험, 국내 극저습 작업환경·건성안 연구, 국내 실제 정전기 화재사례와 해외 주관체감 실험을 대조해 미확정 권장안으로 작성함.
- 건조주의보 `실효습도 35% 이하·2일 이상 예상`, 건조경보 `25% 이하·2일 이상 예상`은 목재 등의 건조도를 나타내는 화재기상 기준임을 확인함. 단기예보 실외 상대습도 `REH`, 공식 관측소 상대습도, 실내 센서 상대습도와 데이터 타입부터 분리하도록 함.
- 기상청의 특보 발표·발효·해제와 실효습도 발표, 실외 상대습도 관측·예보, 등록된 실내 센서 측정값은 출처·장소·시각을 붙여 확정 안내함. 사람의 메마름·눈·입술·코·목·피부·정전기 체감은 모두 `느껴질 수 있어요·판단하기 어려울 수 있어요` 가능성형으로만 안내하도록 함.
- 2010~2011년 청주 아파트 20가구의 겨울철 상대습도가 `23.0~54.1%`, 평균 `35.4%`였고 평가범위 하단보다 낮은 6가구 평균은 `26.7%`였음을 확인함. 가구당 한 번 측정한 환경자료이므로 사람들의 공통 건조감 발생선으로 사용하지 않도록 함.
- 2023년 정상 피부 한국 여성의 `25±1℃·RH 20% 미만·6시간` 노출에서 얼굴 거칠기·홍조·주름과 팔 수분·경피수분손실 일부가 변했지만 얼굴 수분·경피수분손실은 유의하지 않아 부위차가 있었음을 반영함. 객관적 피부지표를 모든 사람의 주관적 당김이나 질환으로 확정하지 않도록 함.
- 국내 극저습 클린룸 `RH 1% 이하` 장기근무자 352명에게 눈 관련 검사·설문 변화가 누적된 연구는 극단적 직업환경 근거로만 사용함. 한국인 건성안 연구들은 습도와의 연관성을 보였지만 실외 연평균 또는 치료환자의 지난 1주 기상자료이므로 실내 순간 임계값으로 확대하지 않도록 함.
- 경기도 의약품 원료공장의 `22℃·31%RH` 정전기 화재는 인화성 헵탄 증기, 개방형 여과기, 비접지 호스, 스플래시 필링이 결합된 실제 사고임을 확인함. `31%면 생활 정전기·화재 발생`으로 일반화하지 않고 재질·마찰·접지·인화성 물질 맥락을 요구하도록 함.
- 실내 잠정 상태는 `RH ≤35%·2시간`에 낮은 강도의 메마름 가능성, `RH ≤30%·2시간+화면응시·콘택트렌즈·얼굴 기류·반복 개인응답`에 눈·입술 마름 가능성, `RH <20%·6시간` 또는 낮은 습도와 반복 개인응답에 코·목·피부 체감 가능성을 제안함. 모두 C등급 잠정 운영값이며 공식 경보선·질환 발생선·보편 체감선이 아님을 명시함.
- `메마르게·뻑뻑하게·마른 것처럼·당기거나 거칠게·따끔하게`를 체감 부위와 맥락에 맞춰 구분하고 한 화면에는 대표 표현 1개와 필요한 국소 체감 1개까지만 표시하도록 함. 같은 방·계절·활동에서 3회 이상 반복된 사용자의 직접 응답은 개인화 보정에 사용할 수 있지만 앱의 다음 안내는 계속 가능성형으로 유지함.
- 저습 체감과 가습 필요성을 분리함. 4-8에서는 `가습해야 해요·가습기를 켜세요`를 생성하지 않고 기기 사용조건·위생·과습 전환은 4-10에서 별도 검토하도록 함.
- 현재 서버는 실외 `REH ≤35%`를 `HUMIDITY_LOW`로 만들고 이를 `HUMIDIFIER_USEFUL`과 `공기가 건조해요 · 가습과 피부 보습을 챙겨요`로 직접 연결하며, 앱도 같은 실외값을 `주의`로 표시함. 실효습도·실외 상대습도·실내 센서·체감·가습 상태를 분리하고 확정·권고 문구를 제거해야 함을 기록함.
- 청주 아파트 원문 PDF는 PDF 스킬 절차에 따라 10쪽 전부를 PNG로 렌더링해 표·본문을 육안 확인했으며 임시 렌더 이미지는 작업 종료 전에 제거함. 원문 PDF는 근거 재검토용으로 `tmp/pdfs/`에 남김.
- 제품 코드·최종 화면 문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-8은 사용자 미확정 권장안이며 확정 후 다음 항목은 4-9 제습 필요성임.

### 기준 채택 4-8 및 검토 4-9: 제습 필요성
- 사용자가 실효습도·실외 상대습도·실내 센서와 사람의 건조 체감을 분리한 4-8 저습·건조 권장안을 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-9 제습 필요성을 환경부·질병관리청 일반 실내습도 안내, 국토교통부·LH 공동주택 결로자료, 최근 한국 기숙사·부산 취약시설 실측, 서울시 반복 침수 주택 개선사례, 한국소비자원 2024년 제습기·에어컨 시험과 현재 프로젝트 구현을 대조해 미확정 권장안으로 작성함.
- 제습 필요성을 하나의 확정등급으로 만들지 않고 `실내 수분을 줄이는 것이 도움이 될 가능성`, `바깥 공기를 이용한 환기가 도움이 될 가능성`, `제습기 같은 기계식 제습이 도움이 될 가능성`으로 분리함. 모든 방법판정은 `낮아질 수 있어요·도움이 될 수 있어요·잘 낮아지지 않을 수 있어요`로 안내하도록 함.
- 공식기관·관리기관이 확인한 누수·침수·결로·곰팡이와 등록된 실내 센서 측정값은 장소·시각·확인주체를 붙여 `확인됐어요·발생했어요·측정됐어요`로 확정 안내하고, 앱이 추론한 재발·잔류수분·곰팡이 환경·방법 적합성은 계속 가능성형으로 유지함.
- 국토교통부는 결로 물방울을 닦고 잘 말린 뒤 제습기 또는 주기적 환기로 습기가 남지 않게 관리하도록 안내하며, 북측 발코니·높은 실내습도·벽 밀착가구·실내빨래·환기 미작동·신축 콘크리트 수분을 결로환경으로 제시함. 제습기 하나를 모든 공간의 정답으로 만들지 않도록 반영함.
- LH 공동주택 자료에서 결로는 표면온도가 실내 이슬점보다 낮을 때 발생하고 누수와 구분해야 하며, 세탁물·샤워·조리 수증기, 환기부족, 단열·열교·외기틈, 정체공간이 함께 작용할 수 있음을 확인함. `80% 이상`이 지속되는 정체공간에서는 곰팡이가 서식할 수 있지만 방 중앙의 순간값으로 발생을 확정하지 않도록 함.
- 2024년 9월 한국 남자 대학기숙사 20개 방에서 평균 상대습도 `86.4~88.5%`가 4일간 측정된 최근 사례와 부산 취약시설 152곳에서 `25℃ 이상·60% 이상`이 많았던 6~10월에 부유곰팡이·세균 등이 상대적으로 높았던 조사결과를 재사용함. 모두 공간·기간·다른 환경요인이 섞인 자료이므로 보편 제습기 작동선으로 확대하지 않음.
- 서울시 2024년 반복 침수·곰팡이 주택의 실제 개선이 곰팡이 제거뿐 아니라 배수관 연결·단열·창호·비막이·차수까지 함께 시행됐음을 확인함. 누수·침수·역류·단열문제는 제습기만으로 해결됐다고 판단하지 않고 원인·젖은 재료·잔류 공기수분을 분리하도록 함.
- 한국소비자원 2024년 제습기 9종 시험에서 제습성능·효율·소음·전력·물통용량 차이가 있었고, 공인 1일 제습량과 사용공간 면적 확인을 안내했음을 반영함. 기기 제안에는 전용면적·작동온도·전력·소음·배수조건을 요구하고 특정 모델을 자동 추천하지 않도록 함.
- 한국소비자원의 2024년 에어컨 냉방·제습모드 5시간 비교에서 평균 온도·습도·소비전력에 유의미한 차이가 없었음을 확인함. `에어컨 제습이 항상 더 잘 마르고 저렴하다`는 문구를 금지하고 기기·설정·실제 전후 측정을 보도록 함.
- 4-7에서 채택한 `RH ≥65%·2시간`을 수분관리 방법 검토의 C등급 잠정 가드레일로 재사용함. 수증기량이 실외에서 충분히 낮고 대기질·강수·온도·방범·소음 제약이 없으면 환기 가능성, 그렇지 않거나 정상 환기 뒤에도 같은 고습이 2시간 이어지면 기계식 제습 가능성을 검토하도록 함.
- `직전 24시간 유효측정 중 80% 이상이 RH ≥80%`이고 붙박이장·벽 밀착가구·발코니 같은 정체공간이 확인될 때만 곰팡이 서식환경 지속 가능성을 만들도록 함. 이는 C등급 제품 가드레일이며 실제 곰팡이·건강피해·재료손상 발생선이 아님을 명시함.
- 결로 가능성은 표면온도 범위와 실내 이슬점 또는 실제 물방울 확인, 누수·침수 뒤 건조 가능성은 원인차단과 재료수분·젖음·실내 고습을 요구함. 실외 상대습도나 비 예보만으로 실내 피해와 제습 방법을 만들지 않도록 함.
- 제습 중 `RH ≤40%` 또는 4-8 저습상태가 생성되면 `공기가 메마르게 느껴질 수 있어요`라는 과도한 건조 가능성을 만들고 방법 추천을 다시 평가하도록 함. 자동 기기제어는 사용자 동의·기기안전·실패대응 기준 전에는 수행하지 않도록 함.
- 현재 서버는 실외 `REH ≥80%` 3시간을 `HUMIDITY_HIGH`로 만들고 바로 `DEHUMIDIFIER_USEFUL` 및 `제습이 도움돼요·제습을 이용하세요`에 연결함. 실외 고습 사실·실내 고습노출·수분영향·환기/기계식 방법 가능성을 분리하고 확정·명령형 템플릿을 제거해야 함을 기록함.
- 현재 프로젝트에는 실내 온습도·표면온도·재료수분 센서, 방·가구·수분원, 실내외 수증기량 비교, 누수·결로·곰팡이 확인, 환기 제약, 제습기 프로필·사용결과가 없어 4-9 상태를 생성하거나 방법을 선택할 수 없음을 기록함.
- 제품 코드·최종 화면 문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-9는 사용자 미확정 권장안이며 확정 후 다음 항목은 4-10 가습 필요성임.

### 4-9 제습 필요성 추가 국내 연구 보강
- 사용자가 다른 연구결과·리서치를 더 확인하도록 요청해 4-9를 미확정 상태로 유지하고 한국건설기술연구원·LH 보고서, 국내 공동주택 드레스룸 현장측정·제어연구, 건축자재 곰팡이 실험, 2024년 제습환기·중앙공조 실험을 추가 대조함.
- 한국건설기술연구원 공동주택 결로 종합대책 보고서는 곰팡이 발아에 자재 표면온도·표면습도·영양분·노출시간이 함께 작용하고, 종별 최저 ERH가 `71~94%`로 넓으며 방의 평균 RH `80%` 하나는 의미가 제한된다고 설명함. 이에 방 중앙 `80%·24시간`만으로 곰팡이 환경 가능성을 만들지 않도록 기준을 수정함.
- 같은 표면 상대습도라도 건축자재의 함수량이 많을수록 곰팡이가 더 빨리 성장한 국내 실험을 반영함. 누수·침수·결로 뒤 건조상태는 공기 RH만으로 해제하지 않고 재료수분·젖음·재발을 함께 보도록 함.
- 김포 공동주택 1세대 드레스룸 실험에서 욕실 문을 연 뒤 10분간 상부 RH가 `61%→69.3%`, 하부는 `63.8%→65.1%`로 변하고 상부 노점온도가 `1.44℃` 높았음을 확인함. 1세대·10분 결과는 보편 임계값으로 쓰지 않고 국소 수증기 이동·취약부 근접측정의 근거로만 사용함.
- 서울대 드레스룸 평가연구는 욕실 수증기 차단과 욕실 환기팬이 우선 효과적이었고 팬 용량보다 사용 뒤 가동시간 선택이 중요했음을 보고함. 2020년 후속 제어연구는 기저습도가 매번 달라 고정 종료값을 제시할 수 없다고 밝혀, `환기 30분·제습 2시간` 같은 보편 종료명령 대신 같은 방의 기저 절대습도·이슬점 회복 추세를 보도록 함.
- LH 대구 33㎡ 빈 세대 실험에서 물 `1L` 가열 15분 뒤 RH `90% 이상`, 공용배기 평균 `189CMH`·개별배기 `122CMH`, 공용배기 절대습도 증가량이 층별 `11~35%` 낮았음을 확인함. 반면 대전 실거주 개별배기 38세대·공용배기 44세대의 각 72시간 측정 평균 RH는 `54.3%·56.8%`로 유사해, 단기 발생원 배기효과와 장기 생활공간 평균효과를 분리함.
- `SOURCE_EXHAUST_OPTION_POSSIBLE`을 추가해 샤워·조리처럼 수분원이 확인된 때 욕실·주방 국소배기의 도움 가능성을 창문환기·이동식 제습기보다 먼저 검토하도록 함. 실제 풍량·설비상태·기저회복에 따라 효과가 달라질 수 있으므로 고정 가동시간·풍량증가를 명령하지 않도록 함.
- `RH ≥65%·2시간`은 제습방법 진입선에서 `INDOOR_MOISTURE_REVIEW_POSSIBLE` 관찰 진입값으로 낮춤. 수분원·평소 기저보다 높은 수증기량·취약부 근접센서/재료 젖음·같은 방 반복이력 중 하나가 더 있어야 수분감소 방법 가능성을 만들도록 함.
- `80%·24시간`은 붙박이장·모서리·벽 밀착가구 같은 취약부 근접센서 또는 표면온습도·재료수분·반복 결로가 있을 때만 곰팡이 환경 가능성의 C등급 보조 가드레일로 허용함. 방 중앙값만 있으면 판단불명으로 낮추도록 함.
- 2024년 창문형 액체식 제습환기 실험은 `86.1㎥·25℃·60%·1시간`에서 유입·유출 평균 RH `62%·43%`를, 용인 59㎡ 액체식 중앙공조 45시간 실증은 여름 외기에서 열쾌적 범위 유지를 보고했지만 모두 특수 시스템임. 이동식 압축식 제습기의 필요선·용량·보편 운전시간으로 확대하지 않도록 함.
- 데이터 요구사항에 계절·난방·재실·문/창·수분원별 `roomMoistureBaseline`, 수분원·문/댐퍼·국소배기 실측풍량·취약부 근접센서·표면온도·재료수분을 담는 `localMoistureContext`를 추가함.
- 한국건설기술연구원 결로 종합대책·실내환경 성능개선, LH 공용 루프팬, 한국태양에너지학회 2024년 자료집 PDF의 관련 22쪽을 PNG로 렌더링해 표·그래프·실험조건을 육안 확인함. 임시 PNG·추출 텍스트·도우미 스크립트는 제거하고 원문 PDF 4개만 `tmp/pdfs/`에 근거 재검토용으로 남김.
- 제품 코드·최종 화면 문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-9는 계속 사용자 미확정 권장안이며 4-10으로 이동하지 않음.

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

### 기준 채택 4-9 및 검토 4-10: 가습 필요성
- 사용자가 국내 공동주택 실측·추가 제습 연구로 보강한 4-9 제습 필요성 권장안을 확정해 문서 제목과 상태를 채택으로 변경함.
- 다음 항목인 4-10 가습 필요성을 질병관리청 레지오넬라증 지침, 가습기살균제 피해 공식체계, 한국소비자원 2024년 가열식 안전조사·2025년 13종 성능비교, 국내 공동주택 연속가습·바이오에어로졸·초음파식 입자 연구, 최근 한국인 겨울철 피부실험과 공동주택 장기측정을 대조해 미확정 권장안으로 작성함.
- `가습 필요·불필요`를 확정등급으로 만들지 않고 `실내 수분을 보충하는 것이 도움이 될 가능성`, `가습기 같은 기계식 가습이 도움이 될 가능성`, `기기 위생·입자·화상·과습 가능성`으로 분리함.
- 건조특보·공식 관측·제품 안전정보와 등록 센서의 측정사실은 `발표됐어요·발효 중이에요·관측됐어요·측정됐어요`로 확정 안내하고, 앱 내부의 건조영향·방법 적합성·기기영향은 모두 `~할 수 있어요·판단하기 어려울 수 있어요`로 제한함.
- 4-8에서 채택한 실내 `RH ≤35%·2시간`을 가습기 작동선이 아니라 `INDOOR_HUMIDIFICATION_REVIEW_POSSIBLE` C등급 관찰 진입값으로 재사용함. 같은 방의 계절별 기저범위, 센서품질, 국소 건조맥락·반복 개인반응이 더 있어야 수분보충 가능성을 검토하도록 함.
- 기계식 가습 가능성에는 공인 가습량·적용면적, 기기유형, 설명서상 물 종류, 물 교체·세척·완전 건조, 어린이·반려동물·전선·설치면을 요구함. 현재 확인한 국내 자료는 `35%·2시간이면 모든 가정에 가습기가 필요`하거나 감염·질환을 예방·치료한다는 근거를 제시하지 않았음을 명시함.
- 질병관리청의 매일 물 교체·세척 뒤 완전 건조와 시설용 물·필터 계통 청소 안내를 반영함. 가습기살균제 건강피해의 공식 확인을 우선해 살균제·소독제·향료·임의 첨가물은 권하지 않고 제품 설명서가 명시한 물 범위만 따르도록 함.
- 한국소비자원 조사에서 가열식 위해사례 164건, 화상 92건 중 만 6세 이하 71건, 조사제품 21개 모두 전도 시 물 유출, 밥솥형 17개에서 `97~100℃` 물 유출이 확인된 결과를 반영해 뜨거운 물·증기와 전도 노출 가능성을 별도 상태로 둠.
- 국내 공동주택 한 방의 장시간 초음파 가습 실험에서 시작 `45%`가 24시간 뒤 `84%`, 3일 뒤 `93%`로 측정되고 이후 세균 증가와 벽지 곰팡이 성장이 관찰된 결과를 과습 감시 근거로 사용함. 한 방·한 기기 실험이므로 `80% 곰팡이 발생선`으로 일반화하지 않음.
- 국내 `31.4㎥` 챔버의 초음파 가습 실험에서 물 종류에 따라 PM2.5 `16~350㎍/㎥`가 측정된 결과를 반영함. 수돗물 전체를 위험 또는 정수·증류수를 보편 안전으로 확정하지 않고, 제품 설명서·기기유형·같은 방 PM 전후반응이 있을 때만 입자·센서상승 가능성을 안내하도록 함.
- 2023년 정상 피부 한국 여성의 `25±1℃·20%RH 미만·6시간` 연구는 건조 노출에 따른 피부지표 변화 근거지만 가습기를 시험하지 않았음을 명시해 기기 필요성·치료효과 근거로 확대하지 않음.
- 가습 중 `RH >60%`이며 상승이 이어지면 과습 가능성을 우선하고, `RH ≥65%·2시간`은 4-7 고습상태, 표면온도-이슬점 또는 실제 물방울은 결로 상태로 넘기도록 함. `60%` 한 번을 곰팡이·피해 발생선으로 쓰지 않음.
- 현재 서버가 실외 `REH ≤35%`를 `HUMIDITY_LOW → HUMIDIFIER_USEFUL`로 직접 연결하고 앱도 이를 `주의`로 표시하지만, 프로젝트에는 실내 센서·기저범위·개인반응·가습기 성능/관리·가정 노출·실내 PM·결로·사용결과가 없어 4-10 상태를 생성할 수 없음을 기록함.
- 원문 PDF 6개는 PDF 스킬 절차에 따라 5개 PDF 전 43쪽과 질병관리청 지침의 관련 2쪽을 PNG로 렌더링해 표·본문·시험조건을 육안 확인함. 임시 렌더 이미지는 작업 종료 전에 제거하고 원문 PDF만 `tmp/pdfs/`에 근거 재검토용으로 남김.
- 제품 코드·최종 화면 문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 4-10은 사용자 미확정 권장안이며 확정 전에는 다음 항목으로 이동하지 않음.

### 4-10 가습 필요성 추가 연구·뉴스 탐색
- 사용자가 앱 내부 판단의 기준자료를 더 탐색하도록 요청해 4-10을 미확정 상태로 유지하고 국내 습도지각 실험, 국내 대규모 호흡기 연구, 가습 개입 체계적 문헌고찰, 국소 탁상형 가습기 무작위시험, 2026년 국내 가습기 화재·리콜을 추가 대조함. 기준 문서와 제품 코드는 아직 변경하지 않음.
- 2016년 단국대 환경챔버의 한국 대학생 26명 실험은 `18·24·30℃`와 목표 `30·40·60%RH` 7조건에서 조건별 55분 적응 뒤 습도감각·선호를 조사함. 실제 `30%` 조건은 약 `29.3~33.2%`로 측정됐고 같은 조건에서도 성별·온도에 따라 습도 인식이 달랐으며, 연구진도 건물용도·연령·기류·복사열을 포함한 후속연구가 필요하다고 밝힘. `30%에서 모두 건조함`, `30%에서 가습기 필요`의 근거로 사용하지 않고 온도·개인응답 결합의 근거로만 사용함.
- 2021년 Cochrane 체계적 문헌고찰은 13개 연구·최소 4,551명을 포함했지만 직장 가습이 눈·피부·상기도 건조증상을 줄이는 효과는 낮거나 매우 낮은 확실성으로 일관되지 않았고 겨울철 실내 습도의 쾌적범위를 정의할 수 없다고 결론내림. 포함연구는 상기도감염 자체를 조사하지 않았고 결근 감소도 매우 불확실했으며, 두 교차시험에서는 답답함 인식이 증가함. 최초 가습 제안에서 `메마른 느낌이 줄어들 수 있어요·감염을 예방할 수 있어요`를 기본 출력하지 않는 보강근거로 사용함.
- 2024년 국민건강영양조사 2016~2018 자료의 한국 성인 10,396명 분석은 기상·대기질 모델로 주소지 주변의 실외/지역 습도 노출을 추정한 단면연구임. 높은 습도와 폐기능·기침의 연관방향이 기간·지표에 따라 섞였고 연구진도 인과관계를 정할 수 없다고 명시함. 실내 센서값·가습기 개입자료가 아니므로 실내 가습기 작동선·호흡기질환 예방문구에 사용하지 않음.
- 2017년 뉴질랜드 컴퓨터 사용자 44명의 무작위 교차시험은 탁상형 USB 가습기로 눈 주변 상대습도가 약 `5.4%p` 높아졌을 때 눈물막 파괴시간 중앙값이 `4초` 늘고 편안함 증가 응답이 `36% 대 5%`로 관찰됐지만 눈물량·지질층은 유의하게 달라지지 않음. 1시간 화면작업의 국소 효과 근거이며 방 전체·피부·코·목·감염효과로 확대하지 않음.
- 2024년 일본의 특정 광촉매 탁상형 가습기 무작위시험은 31명 중 가습 15명·대조 16명이 1시간 화면작업을 수행함. 얼굴 가까이의 RH가 평균 `47.6%→70.3%`로 측정되고 단기 눈 증상·일부 눈물막 지표가 개선됐지만 참가자의 26명이 여성이고 추적은 종료 뒤 1.5시간까지였으며, 특정 제품·국소 분무·약 70%를 넘는 습도와 제조사 연구비·저자 이해관계가 있었음. 일반 방 목표습도나 모든 가습기의 증상완화 기준으로 사용하지 않음.
- 2026년 1월 24일 국내 가습기 전지 화재사고가 발생했고 국가기술표준원은 2월 2일부터 모델 `STH-600G·STH-600P` 393,548대 전량의 자발적 리콜이 실시됐다고 공식 발표함. 리콜 대상 사실과 국표원의 사용중단·리콜 신청 안내는 확정형으로 최우선 표시하며, 다른 제품의 화재 발생을 추정하지 않음.
- 보강 권장안은 첫 가습 판단을 증상완화가 아니라 `같은 방의 습도를 올리는 데 도움이 될 수 있어요`로 제한하는 것임. `메마른 느낌·눈의 불편이 줄어들 수 있어요`는 같은 방·활동·기기에서 가습 뒤 실제 습도상승과 같은 개인반응이 서로 다른 3회 이상 반복될 때만 C등급 개인화 문구로 허용하는 방안을 제안함. `3회`는 연구 임계값이 아닌 출시 전 검증할 운영 가드레일임.
- 화면작업 중 눈 건조는 별도 `LOCAL_EYE_HUMIDIFICATION_RESPONSE_POSSIBLE` 후보로 분리할 수 있으나, 1시간 외국 단기시험 두 편만으로 전국 공통 RH·가동시간을 만들지 않음. 화면시간·콘택트렌즈·얼굴 기류·깜박임·기존 건조응답과 같은 공간의 전후반응이 있어야 `국소 수분 보충이 눈의 편안함에 도움이 될 수 있어요`를 허용하는 방안을 제안함.
- Cochrane 결과에 따라 `GENERAL_DRYNESS_RELIEF_UNKNOWN`과 `RESPIRATORY_PREVENTION_EVIDENCE_INSUFFICIENT` 후보를 추가해, 개인 반복반응이 없으면 `가습기로 건조 증상이 줄어들지 판단하기 어려울 수 있어요`, 감염·질환 예방 질문에는 `현재 자료만으로 예방효과를 판단하기 어려울 수 있어요`로 낮추는 방안을 제안함.
- 4-7의 답답함 원칙을 유지해 가습만으로 `답답해요`를 만들지 않고, 가습 뒤 RH 상승과 같은 사용자의 반복된 답답함 응답 또는 CO2·환기 맥락이 있을 때만 `공기가 답답하게 느껴질 수 있어요`를 허용함.
- 기기안전 데이터에 `officialProductSafetyStatus`, 모델·제조번호·전원방식·충전지·사고/리콜 발표시각·조치·출처를 추가하고, `OFFICIAL_HUMIDIFIER_RECALL_ACTIVE`를 모든 내부 가습 도움 상태보다 우선하는 공식 상태로 두는 방안을 제안함. 리콜과 일치하지 않는 충전식 제품은 화재를 확정하지 않고 손상·비정상 발열·충전상태가 있을 때만 내부 가능성을 별도 평가함.
- 한국 습도지각 실험 9쪽과 일본 탁상형 가습기 무작위시험 12쪽 원문 PDF를 전 페이지 렌더링해 표·그림·시험조건·한계·이해관계를 육안 확인함. 임시 렌더 이미지는 작업 종료 전에 제거하고 원문 PDF 2개만 `tmp/pdfs/`에 근거 재검토용으로 남김.
- 이번 탐색은 판단 기준 보강안 제시까지이며 4-10을 채택하거나 기준 문서·앱·서버 코드를 변경하지 않았고 테스트·배포·커밋은 수행하지 않음.

### 기준 채택 4-10 및 검토 5-1: 자외선지수 단계
- 사용자가 추가 연구·뉴스로 보강한 4-10 가습 필요성을 확정해 기준 문서의 제목과 상태를 채택으로 변경함.
- 2016년 한국 대학생 26명의 습도지각 실험, Cochrane 13개 연구·최소 4,551명 문헌고찰, 국민건강영양조사 성인 10,396명의 지역 실외습도 연구, 뉴질랜드 44명·일본 31명의 국소 탁상형 가습기 시험을 근거표와 판단기준에 반영함.
- 최초 가습효과 문구를 증상완화가 아니라 `공기 중 수분을 보충하면 이 방의 습도가 올라갈 수 있어요`로 제한함. 같은 방·활동·기기에서 습도 상승과 같은 개인반응이 서로 다른 3회 이상 반복될 때만 C등급 개인화 증상문구를 허용하고, 국소 눈 반응·일반 건조증상 불확실·감염/질환 예방근거 불충분 상태를 분리함.
- `3회`는 연구 임계값이 아닌 출시 전 검증할 운영값으로 명시함. 습도 상승만 반복되면 기기 환경효과의 신뢰도만 보정하고, 개인 증상반응이 함께 반복돼야 증상 가능성 문구를 허용함.
- 2026년 가습기 전지 화재와 `STH-600G·STH-600P` 393,548대 리콜을 반영해 정확한 모델 일치 시 `OFFICIAL_HUMIDIFIER_RECALL_ACTIVE`를 모든 내부 가습효과보다 우선함. 국표원 발표·사용중단/리콜 신청 조치는 확정형, 다른 충전식 제품의 손상·팽창·비정상 발열·충전 이상은 과열·화재 가능성형으로 분리함.
- 다음 항목인 5-1 자외선지수 단계를 기상청 현행 생활기상지수·공공데이터 API·위성 자외선지수, WHO 국제 UVI, 국내 안면도·제주 관측연구와 현재 프로젝트 구현을 대조해 미확정 권장안으로 작성함.
- 기상청 공식 5단계 `낮음(<3)·보통(3~5)·높음(6~7)·매우높음(8~10)·위험(11+)`을 변경 없이 사용하고 앱의 기존 `양호·주의·위험` 3단계 축약은 사용하지 않도록 권장함. 공식 `위험`은 출처가 붙은 단계명으로만 사용하며 내부 피해확정문이나 자외선주의보·경보로 확대하지 않음.
- 기상청 시간별 자외선지수는 예측시각부터 다음 시각 사이의 최대 예측값이므로 `12~15시 최대 UVI 7이 예상돼요`로 안내하고, 이를 `현재 UVI 7이 관측됐어요`로 바꾸지 않도록 함. 예보 발표사실은 확정형, 예보내용은 가능성형, 직접 지상관측은 `관측됐어요`, 위성 기반 값은 `산출됐어요`로 분리함.
- 공공데이터포털의 현재 공개목록 이름은 `(4.0)`이지만 실제 명세 호스트와 기능은 `LivingWthrIdxServiceV5/getUVIdxV5`임을 확인함. 목록버전·엔드포인트버전·앱 판정버전을 별도 필드로 두도록 함.
- 현재 서버가 UV 예보의 `issuedAt`을 공통 `observedAt`에 넣고 첫 예보를 `current.uvIndex`로 병합하는 충돌을 기록함. Provider의 3시간 발표후보는 기상청 현행 `매일 8회·3시간 간격`과 맞지만 `30분 발행지연`은 앱 운영가정이므로 실제 `item.date`로 검증하도록 했고, 공식 발표·예보 유효구간·조회·캐시시각을 각각 분리하도록 권장함.
- 현재 앱이 `<6 양호·6~7 주의·8 이상 위험`으로 표시해 공식 `낮음/보통`과 `매우높음/위험`을 합치는 문제, 화면별 정수/소수 표기가 다른 문제, 서버가 `6 이상`을 모두 `UV_HIGH`로 합치는 문제를 기록함.
- 5-1은 공식 단계와 자료유형까지만 다루며 피부영향·노출시간·선크림·양산·모자 행동판정은 5-2~5-4로 넘김. 제품 코드·최종 화면 문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-1은 사용자 미확정 권장안이며 확정 전에는 다음 항목으로 이동하지 않음.

### 5-1 자외선지수 체감기준 검토
- WHO·ARPANSA 공식 안내를 재확인한 결과 자외선은 눈으로 보거나 피부에서 직접 느낄 수 없고, 햇빛의 밝음·뜨거움·따가움은 가시광선·적외선·기온·복사열·피부상태 등의 영향이 섞일 수 있어 자외선지수 단계별 직접 체감으로 사용하지 않도록 권장함.
- 기상청의 `낮음(<3)·보통(3~5)·높음(6~7)·매우높음(8~10)·위험(11+)`은 공식 노출강도 단계로 유지하되, 앱의 체감 안내는 모든 단계에 `자외선은 덥거나 따갑게 바로 느껴지지 않을 수 있어요`라는 공통 원칙을 적용하고 단계가 높을수록 같은 시간 노출에서 피부·눈 영향 가능성이 커질 수 있다는 문구만 가능성형으로 차등화하는 방안을 제안함.
- 기상청이 안내하는 일반적인 일광화상 가능 노출시간은 공식 참고정보일 뿐 실제 사용자의 체감 시작시간이나 개인별 화상 타이머로 사용하지 않음. 피부유형·노출시간·고도·반사환경·의약품·차단수단 등에 따라 달라질 수 있으므로 세부 영향·활동판정은 후속 5-2~5-4에서 별도로 다루도록 함.
- 피부 붉어짐·통증·눈 불편감은 노출 뒤 늦게 나타날 수 있는 반응이므로 현재 자외선의 실시간 체감으로 역산하지 않음. 사용자가 실제 증상을 기록한 경우에만 기록사실을 확정형으로 안내하고, 원인·피해 판단은 가능성형으로 제한함.
- 이번 작업은 5-1의 체감 원칙에 대한 연구 검토와 권장안 제시만 수행했으며 기준 문서·앱·서버 코드는 변경하지 않았고 테스트·배포·커밋은 수행하지 않음. 5-1은 여전히 사용자 미확정 상태임.

### 5-1 자외선 수치·체감 추가 연구 검토
- UVI와 표준홍반선량(SED)의 수치 관계를 확인함. ICNIRP 자료에서 `UVI 1 = 홍반가중 유효복사조도 0.025 W/㎡ = 시간당 0.9 SED`, `1 SED = 100 J/㎡`로 정의되므로 일정한 주변 UVI가 지속된다는 가정의 환경 참고선량은 `ambientSed = Σ(UVI × 노출분 × 0.015)`, 1 SED 누적시간은 `66.7/UVI분`으로 계산할 수 있음. 이는 수평면 주변 선량의 이론값이며 개인 피부가 실제 받은 선량이나 화상 타이머가 아님.
- 국내 1994년 한국 의대생 128명 연구에서는 Fitzpatrick 설문상 I·II형이 13.3%였으나 실제 `MED <40 mJ/㎠`의 자외선 민감군은 14.8%였고 두 분류가 잘 일치하지 않아, 자가 피부형만으로 한국인 개인 민감도를 판정하지 않도록 함.
- 국내 1998년 한국 청년층 연구는 UVB 최소홍반량을 등 `92.6±17.3 mJ/㎠`, 팔 `123.0±24.2`, 허벅지 `126.6±28.3`으로 측정하고 24시간 뒤 판독함. 같은 사람도 부위별 반응값이 달라 얼굴·팔·다리 전체에 한 개의 화상시간을 적용하지 않도록 함.
- 국내 2024년 한국 성인 14명(여성 13명·남성 1명, 피부형 II·III)의 인공태양광 실험은 등 피부의 육안 최소홍반량 평균을 `300.14±84.16 J/㎡`로 측정했으며 홍반은 조사 뒤 `16~24시간`에 판독함. 표본이 작고 실험광원·분광가중 방식이 실외 UVI와 같다고 볼 수 없으므로 이 평균을 한국인 공통 화상선이나 UVI별 개인시간으로 직접 환산하지 않음.
- 2026년 피부형 I~III 58명 실험에서는 0.7·1.6 SED를 UVI 2.8 또는 8.0의 강도로 조사했을 때 같은 총선량이면 강도 차이보다 누적선량이 DNA 손상지표를 좌우했고, 0.7 SED에서도 측정 가능한 변화가 관찰됨. 낮은 UVI도 시간이 길면 선량이 누적될 수 있고 `1 SED 미만=영향 없음`으로 표기하지 않도록 함. 한국인 연구가 아니므로 0.7 SED를 국내 공통 경계값으로 채택하지 않음.
- 사람 대상 UVB 통증모델 연구들은 홍반이 수시간 뒤 진행되고 열·기계 자극에 대한 과민반응이 대체로 24시간 전후에 커지는 결과를 보였으며, 조사 중 자발적인 통증이 UVI 강도를 알려주는 감각으로 작동하지 않았음. 피부 붉어짐·화끈거림·접촉 시 따가움은 `현재 UVI 체감`이 아니라 `노출 뒤 지연 반응 가능성`으로 분리함.
- 기상청의 공식 단계와 일반 피부화상 가능시간인 `보통 2~3시간·높음 1~2시간·매우높음/위험 수십 분`은 출처가 붙은 공식 대응정보로 안내하되 체감 시작시간이나 개인별 남은시간으로 표시하지 않음. 이론적 주변 SED 시간과 차이가 날 수 있는 이유로 피부 입사각·노출부위·그늘·의복·차단제·반사환경·피부 민감도와 UVI 시간변화를 기록함.
- 권장 앱 구조는 모든 UVI 단계의 직접 체감을 `UV_NOT_DIRECTLY_PERCEPTIBLE`로 통일하고, 햇볕의 뜨거움·땀·끈적함은 복사열·체감온도·습도 판정으로 분리하는 것임. 실제 외부 노출시간이 없으면 공식 UVI 단계만 표시하고, 시간이 있을 때도 계산값은 `주변 누적 노출량 참고값`으로만 사용함. 실제 개인선량·화상발생·안전잔여시간으로 확정하지 않음.
- 연구용 내부 후보로 `AMBIENT_UV_DOSE_REFERENCE`와 `DELAYED_SKIN_RESPONSE_POSSIBLE`을 분리함. 2 SED 부근은 민감 피부의 지연 반응 가능성 검토선, 3 SED 부근은 지연 반응 가능성 증가 검토선으로 사용할 수 있으나 국내 출시 전 실제 노출자료로 검증할 운영후보이며 안전/위험 확정선이 아님. 0.7·1.6 SED는 근거 관찰점으로 저장하되 단일 연구값을 제품 경계값으로 채택하지 않음.
- 이번 작업은 추가 연구조사와 미확정 권장안 제시만 수행했으며 기준 문서·앱·서버 코드는 변경하지 않았고 테스트·배포·커밋은 수행하지 않음. 5-1은 사용자 미확정 상태이며 다음 항목으로 이동하지 않음.

### 기준 채택 5-1 및 검토 5-2: 자외선 노출시간
- 사용자가 자외선지수 5-1을 `기상청 공식 5단계 + 직접 체감 불가 + 실제 야외시간이 있을 때만 주변 SED 참고값` 기준으로 확정해 기준 문서의 제목과 상태를 채택으로 변경함.
- 5-1 근거표에 WHO·ARPANSA의 직접 체감 불가 원칙, ICNIRP의 `UVI 1=0.025 W/㎡=0.9 SED/시간·1 SED=100 J/㎡`, 한국인 피부형/부위별 MED 연구, 2024년 한국인 14명 MED 연구, 2026년 0.7·1.6 SED 저선량 인체연구를 추가함.
- 모든 UVI 단계의 직접 체감은 `UV_NOT_DIRECTLY_PERCEPTIBLE`로 통일하고 햇볕의 뜨거움은 복사열·체감온도, 땀·끈적함은 기온·습도 판단으로 분리함. `ambientSedReference=Σ(UVI×분×0.015)`는 수평면 주변 선량 참고값으로만 사용하며 개인선량·MED·화상시간으로 표시하지 않도록 채택함.
- 다음 항목 5-2 자외선 노출시간을 미확정 권장안으로 작성함. 기상청의 `보통 2~3시간·높음 1~2시간·매우높음/위험 수십 분 이내 피부화상 가능` 안내는 출처가 붙은 공식 일반정보로 전달하고, 앱은 `안전시간·화상 카운트다운`을 만들지 않도록 권장함.
- 질병관리청은 일광화상 증상이 과도한 노출 뒤 `3~6시간`에 나타나기 시작해 `12~24시간`에 가장 심해지고 약 72시간 뒤 완화될 수 있다고 안내함. 증상이 없다는 사실을 현재 UVI·누적선량·무영향의 근거로 사용하지 않고, 실제 반응 기록은 확정형·자외선 원인은 가능성형으로 분리함.
- 시간자료를 A~D등급으로 나눔. 짧은 간격 공식 지상관측과 실제 야외시간은 주변 SED 참고값, 검증된 단시간격 예측과 계획시간은 계획 참고값, 현행 기상청 3시간 구간 최대예측은 해당 최대값이 계속된다고 가정한 `주변 상한 참고값`만 허용함. 일최고 또는 야외시간 결측으로는 계산하지 않음.
- 현행 `h0~h75`가 3시간 구간 최대값이므로 이를 평균 UVI처럼 적분하지 않음. 예시 문구도 `구간 최대값이 계속된다고 가정하면 주변 노출량 참고값은 최대 …일 수 있어요`로 제한함.
- `2 SED·3 SED`는 ICNIRP의 민감 피부 MED 범위와 국내외 인체연구를 참고한 출시 전 C등급 운영후보로만 제시함. 0.7 SED에서도 세포수준 변화가 측정된 최근 연구 때문에 그 아래를 무영향으로 부르지 않고, 한국인 연구의 개인차·부위차 때문에 그 위를 화상발생으로 확정하지 않음.
- 주변 UVI와 개인 피부선량의 차이를 보여주는 39명 개인선량 실측연구를 보조근거로 반영함. 그늘·의복·차단제·자세·노출부위에 임의 감소계수를 적용하지 않고 보호수단별 근거는 5-3·5-4로 넘김.
- 현재 앱·서버에는 실제/계획 야외 세션, 시간해상도가 충분한 UVI, 그늘·노출부위·차단수단, 주변 SED와 지연 피부반응 기록이 없어 5-2 개인화 상태를 생성할 수 없음. 현재 `UV_HIGH → 야외활동은 짧게` 규칙에는 노출시간·SED·화상 카운트다운을 연결하지 않음.
- 제품 코드는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-2는 사용자 미확정 권장안이며 확정 전에는 선크림 필요 기준으로 이동하지 않음.

### 기준 채택 5-2 및 검토 5-3: 선크림 필요 기준
- 사용자가 5-2 자외선 노출시간 기준을 확정해 기준 문서의 제목·상태·최종 기준을 채택으로 변경함. 기상청의 단계별 일반 피부화상 가능시간은 출처가 붙은 공식 정보로 유지하고 개인 안전시간·화상 카운트다운은 만들지 않음.
- 실제/계획 야외시간과 충분한 시간해상도의 UVI가 있을 때만 주변 SED 참고값을 계산하며, 현행 3시간 구간 최대예보는 `주변 상한 참고값`으로만 사용함. `2·3 SED`는 가능성 문구용 출시 전 C등급 운영값으로 유지하고 안전·화상 확정선으로 사용하지 않음.
- 다음 항목인 5-3 선크림 필요 기준을 미확정 권장안으로 작성함. 기상청과 WHO가 보호조치를 안내하기 시작하는 `UVI 3 이상`, 즉 공식 `보통` 단계를 일반안내 진입점으로 두되, 앱 내부 도움 가능성은 실제/계획 야외활동과 옷으로 가리지 않은 피부가 모두 확인될 때만 생성하도록 권장함.
- `UVI 0~2`도 자동 `선크림 불필요`로 만들지 않음. 장시간 노출은 5-2의 주변 SED 참고값과 함께 낮은 신뢰도의 가능성으로 다시 검토하고, 민감 맥락은 사용자의 직접 과거반응 또는 정확한 의약품·제품의 공식 광과민 주의가 확인됐을 때만 추가하도록 함.
- 질병관리청의 일반 `SPF 15 이상·PA++ 이상·2시간 재도포`, 2024년 건강정보의 외출 15분 전 충분한 도포·물놀이 내수성 제품, 식약처 2026년 기능성화장품 표시·SPF·PA·1~2시간 재도포 안내를 국내 A등급 근거로 반영함. 출처별 맥락이 다르므로 UVI만으로 SPF·PA를 자동 지정하지 않음.
- 건국대의 건강한 성인 15명 도포량 실험에서 표시 SPF는 `2mg/㎠`에서 재현되고 적게 바르면 효과가 유의하게 낮아졌으며 일상 사용량으로 제시된 `0.5mg/㎠`에서는 실제 SPF 예측이 어려웠음을 반영함. 국내 실제 사용조건 연구와 국내 판매 제품 시간경과 연구도 표시 SPF와 개인 실제효과를 동일시하지 않는 보조근거로 사용함.
- `SPF×안전시간`, 완전차단, 남은 보호시간, 선크림을 근거로 한 야외시간 연장은 금지함. 제품의 기능성화장품·SPF·PA·내수성은 실제 조회/입력으로 확인된 사실만 확정 안내하고, 실제 차단효과·필요성·피부영향은 모두 가능성형으로 유지함.
- 재도포는 확인된 도포 뒤 2시간 또는 땀·물·마찰이 있을 때 검토 가능성만 안내함. 제품설명서와 정확한 도포정보가 없으면 잔여효과를 계산하지 않으며, 사용자 피부반응 기록은 확정형·제품 원인은 가능성형으로 분리함.
- 현재 서버는 `uv.highThreshold=6`에서만 `UV_HIGH`를 만들고 바로 `SUNSCREEN_USEFUL`로 변환해 공식 `보통(3~5)`은 빠지면서 사용자 야외·노출피부·제품·도포 맥락 없이 추천을 생성함. 앱/서버의 `필요한 날이에요·챙겨요·발라요·준비를 하세요` 문구도 내부 확정·명령형이므로 후속 구현에서 공식 일반안내와 가능성 상태로 분리할 필요가 있음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-3은 사용자 미확정 권장안이며 확정 전에는 5-4 양산·모자 필요 기준으로 이동하지 않음.

### 5-3 국내 실제 수치·체감 추가 연구
- 사용자가 국내 한국 기준의 실제 수치와 체감 연구를 더 확인하도록 요청해 5-3을 미확정으로 유지하고, 기상청·질병관리청·식약처 공식자료와 국내 자외선 관측·한국인 MED·피부체표면적·선크림 도포량·사용인식 연구를 추가 대조해 기준 문서를 보강함.
- 2004~2010년 서울 Brewer 실측에서 정오 연최대 UVI `9~11`, 연구기간 최고 `11`, 일최대 UVI `8 이상`이 연평균 약 9일 관측됐고 흐린 하늘의 자외선 투과율이 약 58%로 총일사 약 40%보다 높았음을 반영함. 오래된 서울 단일지점 자료이므로 현재 전국 빈도나 개인 노출량으로 일반화하지 않고 밝기·구름 체감의 한계 근거로만 사용함.
- 한국인 의대생 128명 연구에서 설문상 I·II형 13.3%, 실측 `MED <40mJ/㎠` 민감군 14.8%였으나 두 조건이 함께 확인된 학생은 전체의 2.3%였고, 후속 707명 설문·남성 156명 실측도 피부형과 MED 관계가 약했음을 반영함. 앱은 피부색·자가 피부형만으로 개인 화상시점이나 선크림 필요성을 만들지 않음.
- 2024년 한국인 14명의 실험실 UVR 연구에서 육안 MED 평균 `300.14±84.16J/㎡`, 기기 MED 평균 `303.29±77.99J/㎡`가 측정됐지만 소표본이고 실험광원·부위·지연평가 조건이 야외 UVI와 달라 UVI별 체감시간이나 한국인 공통 화상선으로 환산하지 않음.
- 식품의약품안전청이 2007~2009년 한국인 691명을 실측한 성인 평균 얼굴면적은 여성 `371㎠`, 남성 `419㎠`임. 여기에 SPF 시험 도포량 `2mg/㎠`를 단순 곱한 얼굴 전용 산술 참고량 `0.742~0.838g`, 약 `0.8g`을 선택적 교육정보로 추가함. 개인 얼굴·제품의 정확한 1회량, 실제 도포완료, 표시 SPF 달성을 뜻하지 않으며 귀·목·팔다리나 동전·두 손가락 환산으로 확대하지 않음.
- 건국대 건강한 성인 15명 실험의 `0.5·1.0·1.5·2.0mg/㎠` 결과를 다시 확인해 표시 SPF가 `2mg/㎠`에서 재현되고 적게 바르면 효과가 유의하게 낮아졌지만 `0.5mg/㎠`의 실제 SPF는 예측하기 어려웠음을 명시함. 앱은 도포량을 모르면 개인 차단율·보호시간을 계산하지 않음.
- 한국 여성 340명 설문에서 제품 사용감과 자외선 차단지수가 주요 구매요인이었고 편리성·유효성·사용성·안전성 인식이 만족·재구매와 관련됐음을 사용지속 가능성의 보조근거로 반영함. 편의표본 자기보고이므로 끈적임이 차단효과를 몇 % 낮춘다는 수치나 임상 이상반응률로 사용하지 않음.
- 제품 사용감 입력을 `산뜻함·촉촉함·끈적임·무거움·번들거림·백탁·화장 밀림·눈시림/따가움·잘 모르겠음`으로 제안함. 사용자가 고른 느낌은 `기록됐어요`로 확정하고 `이 느낌 때문에 충분히 바르거나 덧바르기 어려울 수 있어요`처럼 사용영향만 가능성형으로 안내하며, 사용감으로 차단효과·도포량·제품원인을 확정하지 않음.
- 국내 근거를 추가해도 공식 일반안내 진입점은 기상청 `UVI 3 이상`을 유지하는 권장안임. 앱 내부 도움 가능성은 실제/계획 야외활동과 노출 피부가 함께 확인될 때만 만들고, `UVI 0~2` 자동 불필요·한국인 별도 UVI 임계값·SPF별 안전시간은 만들지 않음.
- `SUNSCREEN_FACE_REFERENCE_AMOUNT_AVAILABLE`, `USER_REPORTED_SUNSCREEN_FEEL`, `SUNSCREEN_USE_COMFORT_BARRIER_POSSIBLE` 상태와 `sunscreenAmountReference`, `sunscreenFeelFeedback` 자료구조 후보를 기준 문서에 추가함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-3은 계속 사용자 미확정 권장안이며 확정 전에는 5-4로 이동하지 않음.

### 기준 채택 5-3 및 검토 5-4: 양산·모자 필요 기준
- 사용자가 국내 실제 수치·체감 연구로 보강한 5-3 선크림 필요 기준을 확정해 기준 문서 제목·상태·최종 목록을 채택으로 변경함.
- 다음 항목인 5-4 양산·모자 필요 기준을 기상청 자외선 단계별 대응요령, 질병관리청 자외선·온열질환 행동요령, 국가기술표준원 현행 우산·양산 안전기준, 국내 시판 모자 원단시험·농작업용 일광차단모 야외착용 연구, 해외 모자 얼굴선량 모델·휴대용 우산 실측과 4-5 채택 풍속기준을 대조해 미확정 권장안으로 작성함.
- 기상청이 모자를 안내하는 공식 진입점은 `UVI 3 이상`, 즉 `보통` 단계로 두고 `기상청은 '보통' 단계부터 모자를 이용하도록 안내하고 있어요`라고 기관·단계·유효시간과 함께 확정 안내하도록 함. 기상청에는 별도 양산지수·양산주의보·모자 필요 단계가 없으므로 만들지 않음.
- 내부 모자 판단은 실제/계획 야외활동과 머리·얼굴·귀·목의 노출이 확인될 때만 노출감소의 도움 가능성으로 생성함. `챙이 넓음`과 얼굴·귀·목 가림은 둘레챙·목가림·착용방향이 실제 확인됐을 때만 추가하고, 야구모자·선바이저의 원단차단율을 얼굴 전체 보호율로 바꾸지 않음.
- 내부 양산 판단은 `UVI ≥3 + 실제/계획 야외활동 + 직사광선 또는 고정그늘 부족 + 손에 들 수 있는 활동`이 함께 확인될 때만 `양산이 직사광선을 가리는 데 도움이 될 수 있어요`라는 휴대용 그늘 가능성을 생성함. 자전거·킥보드·양손작업·유아 안기처럼 손에 드는 사용이 맞지 않으면 자동 추천하지 않음.
- `UVI 0~2`도 자동 양산·모자 불필요로 만들지 않음. 장시간 야외활동은 5-2의 주변 SED 참고값 `2 SED`를 출시 전 C등급 운영값으로 재사용하고, 민감 맥락은 사용자 직접반응이나 정확한 공식 광과민 주의가 있을 때만 가능성형으로 검토함.
- 국가기술표준원 현행 PDF 전 4쪽을 확인함. 인공태양광·KS K 0850 시험에서 일반 양산 및 우산·양산 겸용은 자외선 차단율 `85% 이상`, 골프용 양산 및 우산·양산 겸용은 `90% 이상`이고 제품에 차단율을 표시함. 일부 면·마 40% 이상·자수·번아웃 원단은 요구율 예외가 가능하지만 차단율 표시는 필요함.
- 양산의 `85%·90%`는 원단 표준시험과 제품 표시사실로만 사용함. 사람의 얼굴·목·팔 실제 노출감소율, 보호시간, 완전보호로 복사하지 않고 정확한 모델·라벨이 확인됐을 때만 `차단율 90%가 표시됐어요`로 확정함.
- 국내 2007년 시판 모자 6종 인공광 시험에서 선바이저 `81.5·89.8%`, 폴리에스터 야구모자 `91.7·96.3%`, 겹원단 클로슈 `100%`의 원단 차단율이 측정됐지만 제품 6개·원단시험이므로 색상 우열·얼굴 보호율로 일반화하지 않음.
- 국내 2004년 특정 양산형 농작업모 야외착용 연구에서 기존 농작업모보다 피부온·심박수·발한량·모자 안 온도가 낮고 모자 안 온도차 평균 `7.72℃`, 덜 덥고 덜 습하며 더 쾌적하다는 주관응답이 관찰됐지만 모자 안 측정습도는 더 높고 직장온은 유의하게 다르지 않았음. 특정 개발모 결과이므로 일반모자 체온효과로 확대하지 않고 측정값과 체감이 다를 수 있다는 근거로 사용함.
- 해외 3차원 모자 모델은 넓은 챙이 얼굴선량을 가장 낮췄지만 어떤 형태도 모든 얼굴부위를 완전 보호하지 못했고 최대 예측효과가 76%였으며, 휴대용 우산 23종의 UVI 8 실측은 제품별 `77~99%` 차이를 보였음. 국내 제품표시를 우선하고 산란·반사광·각도·제품차이의 보조근거로만 사용함.
- 양산 바람 영향은 4-5 채택 운영값을 재사용함. `평균 4~9m/s 미만 + 긴 노출/큰 캐노피/한 손 짐/유아동반/손목취약`은 손목·팔 부담 가능성, `평균 ≥9m/s OR 공식 최대순간 ≥10m/s OR 돌풍·강풍특보`는 안정적 사용 어려움 가능성으로만 안내함. 국가 `12±0.5m/s·45°·20초`는 제품 구조시험이며 사람의 안전풍속이 아님.
- 모자 사용감은 `그늘감·덜 뜨거움·머리 열감·습함·답답함·무게·시야 가림·바람 흔들림`, 양산 사용감은 `그늘감·덜 뜨거움·무게·손목 부담·바람 흔들림·시야 방해·잘 모르겠음`으로 직접 기록하도록 제안함. 선택한 느낌은 `기록됐어요`로 확정하고 다음 사용의 편의·지속 가능성만 가능성형으로 안내하며 자외선 차단율·체온을 체감으로 추정하지 않음.
- 현재 서버는 `UV_HIGH(UVI ≥6) AND TEMPERATURE_HIGH(기온 ≥33℃) → STRONG_SUN_EXPOSURE → PARASOL`로 직접 연결해 공식 `보통(3~5)`을 빠뜨리고 야외·직사광선·그늘·이동수단·제품·바람 없이 양산을 추천함. 앱·서버에는 `HAT` 유형이 없고 `parasolEnabled`는 알림 선택일 뿐 보유·사용·필요 증거가 아니며 `양산 챙겨요` 문구는 명령형임을 기록함.
- PDF 스킬 절차에 따라 국가기술표준원 안전기준 PDF 전 3쪽의 구판과 국가법령정보센터 현행 4쪽 텍스트를 대조하고 구판 3쪽을 PNG로 렌더링해 표·시험조건·표시사항을 육안 확인함. 임시 PDF·PNG는 작업 종료 전에 제거함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-4는 사용자 미확정 권장안이며 확정 전에는 PM10 등급으로 이동하지 않음.

### 5-4 국내 실제 수치·체감 추가 연구
- 사용자가 국내 한국 기준의 실제 수치와 체감 연구를 더 조사하도록 요청해 5-4를 미확정으로 유지하고, 2026년 한국소비자원 우양산 시험·서울/진주 고정 그늘 실측·한국인 PT 온열감 연구·국내 보도의 양산 체감온도 수치 출처를 추가 대조해 기준 문서를 보강함.
- 한국소비자원이 국내 온라인 판매 우양산 12종을 2026년 시험한 결과 암막 10종은 자외선 차단율 `99.9%`, 암막이 없는 일반 2종은 `96.9~97.1%`로 측정됨. 광 차단율은 암막 10종 `100%`, 감색 일반제품 `95.8%`, 회색 일반제품 `87.4%`였고 6종은 필수 표시 누락·소재명 부정확 등 표시사항이 미흡했음.
- 이 결과를 근거로 자외선 차단, 눈에 보이는 어두움·그늘감, 열감·쾌적감을 서로 다른 데이터와 상태로 분리함. 정확한 소비자원 시험모델이 일치할 때만 자외선·광 차단 측정값을 `측정됐어요`로 확정하고, 암막·검정·우양산 판매표현만으로 차단율이나 열감 하락을 추정하지 않음.
- 2012년 8월 서울 가로수 그늘 실측에서는 WBGT가 햇빛 노출지보다 약 `1~4℃` 낮고 15~16시에는 약 `32 대 29`, 즉 `3~4℃` 차이가 측정됐으며 현장설문도 그늘의 열쾌적감을 확인함. 이는 고정 가로수 그늘 결과라 양산 아래의 고정 온도차로 복사하지 않음.
- 2018년 7~8월 진주 폭염 가로실측에서는 1·2열 가로수와 쉘터·어닝이 햇빛 노출지보다 UTCI 열스트레스 단계를 `0.3~1.0` 낮췄지만 차양 아래도 대부분 `매우 강한 열스트레스` 범위였음. 그늘이 도움 될 수 있어도 더위가 사라지거나 안전해졌다고 확정하지 않는 한계근거로 사용함.
- 서울 거주 한국인 19명의 환경실험에서 한국형 PT의 Warm/Hot/Very hot 진입점 `28/36/43℃`가 도출됐지만 양산 전후 시험이 아니므로 양산·모자 사용선이나 효과온도로 사용하지 않음.
- 국내 보도에서 반복되는 `양산 사용 시 체감온도 3~7℃ 또는 최대 10℃ 하락`은 일본 실험이나 고정 그늘 설명과 함께 인용되는 경우가 많았고, 한국인 대상 일반 양산 실외시험의 공통값으로 확인되지 않았음. 국내 2004년 특정 농작업용 일광차단모의 모자 안 온도차 `7.72℃`도 일반모자 효과로 확대하지 않음. 따라서 `양산은 체감온도를 10℃ 낮춰요`, `모자는 머리온도를 7.72℃ 낮춰요`를 금지문구로 추가함.
- 공식 모자 일반안내 진입점은 기상청 `UVI 3 이상`으로 유지함. 내부 양산 상태도 `UVI ≥3 + 야외활동 + 직사광선/고정그늘 부족 + 손에 들 수 있는 활동`에서 휴대용 그늘의 도움 가능성만 생성하는 권장안을 유지하며, 별도 공식 양산단계나 사용명령은 만들지 않음.
- 정확한 공식 광 차단 시험값을 위한 `PARASOL_LIGHT_BLOCK_TEST_CONFIRMED`, 어둡고 그늘진 체감 가능성을 위한 `PARASOL_DARK_SHADE_FEEL_POSSIBLE` 후보를 추가함. 공식 시험사실은 확정형, 사용자 쾌적·열감 영향은 가능성형으로 분리함.
- 모자 체감 선택지를 `그늘진 느낌·햇볕이 덜 뜨거움·머리가 후끈함·땀이 차서 끈적함·눅눅함·답답함·무게감·시야 가림·바람에 들썩임·잘 모르겠음`, 양산은 `그늘져 편함·햇볕이 덜 뜨거움·눈부심이 덜함·손목이 묵직함·바람에 잡아당겨짐·걸리적거림·휴대 번거로움·잘 모르겠음`으로 확장함.
- 한 번의 사용자 응답은 해당 시점의 기록사실로만 확정하고 다음 사용의 편의·불편은 같은 제품·비슷한 환경의 누적기록을 함께 볼 때 가능성형으로만 안내함. 누적 횟수의 숫자 임계값은 이를 검증한 국내 연구가 없어 임의로 만들지 않음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-4는 사용자 미확정 권장안이며 확정 전에는 PM10 등급으로 이동하지 않음.

### 기준 채택 5-4 및 검토 5-5: PM10 등급
- 사용자가 국내 실제 수치·체감 연구로 보강한 5-4 양산·모자 필요 기준을 확정해 기준 문서 제목·상태·최종 목록을 채택으로 변경함. 제품 반영 전 경계·제품·바람·사용감 회귀검증 원칙은 유지함.
- 다음 항목인 5-5 PM10 등급을 에어코리아 공식 등급·통합대기환경지수·실시간/최종확정자료·주의보/경보, 대기환경기준, 기상청 황사기준, 국립보건연구원·국내 역학연구, 2024년 실제 황사 발령사례를 대조해 미확정 권장안으로 작성함.
- 공식 PM10 4등급은 `좋음 0~30`, `보통 31~80`, `나쁨 81~150`, `매우나쁨 151 이상`을 명칭 변경 없이 사용하도록 권장함. 앱의 `safe/caution/danger`, `안전/주의/위험` 3단계로 바꾸지 않음.
- 최근 1시간 측정값 `pm10Value`, 공식 1시간 등급 `pm10Grade1h`, 24시간 예측이동평균 `pm10Value24/pm10Grade`, 권역 일예보 `informGrade`, 공식 주의보/경보를 분리함. `150`은 공식 4등급에서 나쁨 상한이면서 주의보의 `시간평균 150 이상 2시간 지속` 숫자이고 `151`은 매우나쁨 시작값이므로 시간기준과 공식 발령을 반드시 함께 표시함.
- 주의보 `150 이상 2시간`, 경보 `300 이상 2시간`은 기상조건 등을 검토한 시·도 공식 발령·전환·해제 이벤트만 확정형으로 안내함. 단일 측정값이나 앱이 관찰한 두 값으로 자체 주의보·경보를 생성하지 않음.
- 대기환경기준 `연 50·24시간 100`, 기상청 황사경보 `800 이상 2시간 예상`, 황사 위기경보는 PM10 4등급·일반 대기오염경보와 별도 제도로 유지함. 2024-03-29 수도권 등에서 `300 이상 2시간` 지속으로 황사 위기경보 주의가 발령된 실제 사례를 지속조건과 기관발령 분리의 근거로 반영함.
- 서울 2006~2010 연구에서 PM10 `10㎍/㎥` 증가가 전체사망 `0.44%`, 심혈관사망 `0.95%` 증가와 연관됐고, 서울 2000~2014 연구에서는 날씨유형·연령에 따라 연관성이 달랐음을 반영함. 이는 집단수준 연속위험 근거로만 사용하고 `81·151`을 개인 증상발생선으로 바꾸지 않음.
- PM10은 눈에 보이지 않을 정도로 작고, 국내 자료에서 등급경계별 공통 감각 임계값은 확인되지 않았음. `눈 뻑뻑함·따가움·가려움·눈물`, `코답답함·콧물·목 칼칼함·따끔함·입안 텁텁함`, `기침·쌕쌕거림·숨참·가슴답답함`, `공기 텁텁함·뿌연 하늘·거슬리는 냄새·잘 모르겠음`은 사용자가 직접 기록한 사실만 확정하고 PM10 원인은 가능성형으로만 안내함.
- 실시간 측정자료는 시각·측정소·품질플래그와 함께 `측정됐어요`로 안내하되 최종검증 전 `최종확정됐어요`라고 하지 않음. 현행 `30분 fresh·3시간 stale`은 C등급 운영값으로만 두고 stale 자료는 과거 참고로 표시하며 현재 등급·경보 확정 입력에서 제외하도록 권장함.
- 현재 서버는 `pm10Value24`, PM10 별도 1시간/24시간 등급, `pm10Flag`, 측정망·거리, 예보·경보 이벤트를 보존하지 않고 PM10·PM2.5의 더 나쁜 1시간 등급을 `airQualityGrade` 하나로 합침. 결측 PM10을 `0`으로 바꾸고 `pm10>=81`에서 곧바로 `PM10_HIGH/AIR_QUALITY_BAD→MASK_USEFUL`로 연결하는 문제를 기록함.
- 현재 앱은 PM10 `0~80 safe`, `81~150 caution`, `151+ danger`와 `주의/위험` 문구로 공식 네 등급을 세 단계로 바꾸며, PM2.5가 있으면 이를 `미세먼지` 대표값으로 우선 표시함. 5-5 반영 때 공식 네 명칭·시간기준·측정시각을 보존하고 PM2.5 동시표시는 5-6에서 확정하도록 권장함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-5는 사용자 미확정 권장안이며 확정 전에는 5-6 PM2.5 등급으로 이동하지 않음.

### 5-5 국내 실제 수치·체감 추가 연구
- 사용자가 국내 한국 기준의 실제 수치와 체감 연구를 더 조사하도록 요청해 5-5를 미확정으로 유지하고, 국내 증상일지·천식 패널·개인노출 패널·국민건강영양조사·최근 2026년 복합오염 연구를 추가 대조해 기준 문서를 보강함.
- 2012년 인천 알레르기비염 환자 108명·대조군 47명의 120일 일지에서 PM10이 `105.53·139.8·116.13㎍/㎥`로 오른 세 날에도 코막힘·콧물·재채기·가려움·수면방해·약물사용과 PM10의 유의한 연관성이 관찰되지 않았고, 야외활동 시간은 총 코증상점수와 유의하게 연관됐음. 이를 `81·100`의 공통 체감선 반례로 반영하되 한 계절·고농도 3일 자료이므로 `150 미만 무증상`이나 `150부터 증상`으로 확대하지 않음.
- 2002년 인천 천식 성인 64명의 황사 패널에서 14개 황사일 일평균 PM10 `188.5㎍/㎥`, 비황사일 `60.0㎍/㎥`가 기록됐고 PM10 증가와 야간 증상·평균 PEF 감소·PEF 변동 `20% 초과`가 연관됐음. 낮 증상·기관지확장제 사용은 연관되지 않았고 증상 상대위험은 경계수준 `1.05(95% CI 0.99~1.17)`이어서 `188.5`를 일반 체감 임계값으로 쓰지 않음.
- 2004년 서울 경증천식 아동 52명의 56일 연구에서 황사일·노출 뒤 2일·비교일의 평균 일별 기침 비율은 `42.9·33.0·20.2%`, 인후통 `24.2·20.2·6.1%`, 눈 자극 `24.5·16.1·7.8%`였음. 황사일 아침 PEF는 개인 최고치의 `87.9%`로 비교일 `94.2%`보다 낮고 아침 PEF `10% 초과` 감소 비율은 `57.3% 대 21.4%`였음. 사용자 확인 천식·호흡기 민감성과 고농도 황사 야외노출이 함께 있을 때만 같은 날~2일 지연기록을 연결하는 후보로 반영하고 일반 사용자에게 확대하지 않음.
- 2013~2015년 국내 성인 165명(COPD 75명·대조군 90명) 패널의 PM10은 2월 평균 `62.0`·범위 `14.5~455.9`, 5월 평균 `55.9`·범위 `15.9~156.3`, 7월 평균 `35.0`·범위 `12.6~84.8㎍/㎥`였고 높은 PM10이 일상활동 점수·날씨 관련 기침·쌕쌕거림과 연관됐음. 넓은 실제범위 근거로만 사용하고 계절별 설문과 복합오염 한계 때문에 단일 체감 경계를 만들지 않음.
- 수도권 ANGEL 연구는 아토피피부염 아동 177명·천식 성인 70명을 17개월간 매일 추적했고, 최근접 측정소값과 실내농도·시간활동·흡입량을 반영한 개인노출 추정의 분포와 천식 효과크기가 달랐음. 측정소값만 있고 실내외 시간·이동·활동강도가 없으면 `PM10_PERSONAL_EXPOSURE_UNCERTAIN`을 유지하도록 반영함.
- 2010~2012년 국민건강영양조사 16,824명에서는 PM10과 잦은 눈 통증·불편 또는 안구건조 진단의 유의한 연관성이 관찰되지 않았고 오존 증가·습도 감소가 연관됐음. 2016~2018년 안구건조 환자 43명 연구에서는 PM10이 눈물막파괴시간 감소와 연관됐지만 주관적 안구불편점수는 오존·PM2.5와 연관됐음. 눈 뻑뻑함·따가움을 PM10 고유 체감이나 등급 판별감각으로 사용하지 않음.
- 2026년 국민건강영양조사 13,980명 연구는 임상 안구건조 유병률 `15.9%`, SO2·NO2·PM2.5·PM10 복합지수의 고농도일 1일 증가당 조정 오즈비 `1.04(95% CI 1.02~1.06)`를 보고했지만 연평균 통합대기지수는 유의하지 않았음. 복합 잠재경계를 PM10 `81·151`이나 개인의 당일 눈 체감선으로 바꾸지 않음.
- 국내 추가 연구를 대조한 결론은 공식 4등급 `좋음 0~30·보통 31~80·나쁨 81~150·매우나쁨 151 이상`을 그대로 유지하되 별도 농도별 공통 체감표는 만들지 않는 것임. 앱 체감은 자발적 기록, `나쁨/매우나쁨 또는 활성 경보 + 야외노출`에서의 C등급 선제질문, 민감 호흡기의 제한적 같은 날~2일 추적, 눈 불편 원인분리, 개인노출 불확실 상태로 구성함.
- `PM10_PERSONAL_EXPOSURE_UNCERTAIN`, `PM10_FEEL_CHECK_AVAILABLE`, `PM10_DELAYED_RESPIRATORY_FEEL_POSSIBLE`, `PM10_NO_NOTICEABLE_CHANGE_RECORDED` 상태와 증상 시작/종료시각·실내외 체류·민감성 직접확인 자료구조 후보를 추가함. 모든 내부 피해·체감·활동 판단 문구는 가능성형으로 유지하고 사용자 직접입력과 공식 발표·측정만 확정형으로 안내함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-5는 계속 사용자 미확정 권장안이며 확정 전에는 5-6 PM2.5 등급으로 이동하지 않음.

### 기준 채택 5-5 및 검토 5-6: PM2.5 등급
- 사용자의 `확정 후 다음` 반복 입력은 동일 지시의 중복으로 해석함. 국내 실제 수치·체감 연구로 보강한 5-5 PM10 기준을 확정해 기준 문서 제목·상태·최종 목록을 채택으로 변경했고, 아직 제시되지 않았던 5-6까지 자동 확정하지 않고 미확정 권장안을 작성함.
- 5-5의 공식 PM10 `좋음 0~30·보통 31~80·나쁨 81~150·매우나쁨 151 이상`, 시간자료·C24E·권역예보·경보 분리, 공통 체감경계 미생성, 개인노출 불확실·제한적 체감추적 원칙을 최종 채택함. 제품 반영 전 회귀검증 원칙은 유지함.
- 5-6 공식 PM2.5 4등급은 `좋음 0~15`, `보통 16~35`, `나쁨 36~75`, `매우나쁨 76 이상`을 명칭 변경 없이 사용하도록 권장함. 앱의 `safe/caution/danger`, `안전/주의/위험` 세 단계로 바꾸지 않음.
- 최근 1시간 `pm25Value/pm25Grade1h`, 24시간 예측이동평균 `pm25Value24/pm25Grade`, PM2.5 권역 `informGrade`, 시·도 주의보/경보, 초미세먼지 위기경보, 비상저감조치를 서로 다른 필드·상태로 분리함. 에어코리아 C24E의 PM2.5 보정값 `M=30`은 계산계수일 뿐 새 등급·체감·행동 임계값으로 쓰지 않음.
- `35`는 공식 보통 상한이면서 24시간 대기환경기준, `36`은 나쁨 시작값임. `75`는 나쁨 상한이면서 시간평균 `75 이상 2시간 지속` 주의보 조건의 시작값이고 `76`은 매우나쁨 시작값임. `150 이상 2시간 지속`은 경보 조건이므로 수치가 같거나 인접해도 시간기준과 공식 기관 발령을 함께 확인하도록 함.
- 위기경보·비상저감조치는 4등급·대기오염경보와 별도 제도로 저장함. `관심`은 당일 0~16시 평균 `50 초과 + 다음날 50 초과 예상`, 당일 주의보/경보 `+ 다음날 50 초과 예상`, 다음날 `75 초과 예상` 등의 조건을 사용하며 상위단계도 고농도 지속과 다음날 예보를 조합함. 앱이 `매우나쁨`만 보고 위기경보나 비상저감조치를 만들지 않음.
- 2025-01-21 환경부가 서울·인천·경기 등 9개 시도에 초미세먼지 위기경보 `관심`을 발령하고 1월 22일 비상저감조치를 시행한 실제 사례를 반영함. 당일평균·다음날예보 또는 주의보·다음날예보를 결합한 공식 발령사실로 사용하고 개인 피해사례로 바꾸지 않음.
- 2026년 봄 국립환경과학원 전망자료에서 2015~2024년 황사일 제외 봄철 전국 PM2.5 평균 `23.6㎍/㎥`, 나쁨 이상 일수 평균 `12일`이 확인됐지만 10년 계절평균을 특정 날짜·지역의 측정값이나 개인 체감으로 사용하지 않음.
- 2022~2024년 서울 알레르기질환 성인 93명의 개인 PM2.5 장기측정에서 평균 `17.38㎍/㎥`, 개인 간 변이 약 `43.5%`가 관찰됐고 실내외 오염·체류환경·흡연·기상·공기청정기 등에 따라 달랐음. 측정소값만 있고 실내외 체류·이동·흡연/조리·활동자료가 없으면 `PM25_PERSONAL_EXPOSURE_UNCERTAIN`을 유지하도록 함.
- 2026년 서울 천식아동 20명·1,436 child-day 예비연구에서 72시간 개인센서 PM2.5 평균 `29.4㎍/㎥`, 탐색적 `25㎍/㎥` 전후 PEFR 감소 관찰률 `5.7% 대 41.9%`가 보고됐고 고정측정소보다 개인센서가 PEFR 감소와 강하게 연관됐음. 연구진도 경계값을 탐색적으로 명시했으므로 `25`를 일반 체감·등급·알림 임계값으로 쓰지 않고 5-7 민감군 검토자료로 넘김.
- 전국 249개 지역 2006~2021년 연구에서 일 PM2.5 `10㎍/㎥` 증가와 심혈관 입원 `0.94%`, 호흡기 입원 `1.43%` 증가가 연관됐고, 전국 호흡기 입원 약 139만 건 연구에서는 사분위범위 `34.5㎍/㎥` 증가와 당일~4일 입원 `1.73%` 증가가 연관됐음. 집단수준 연속·지연 연관성으로만 사용하고 개인 입원확률·증상창·`36`의 급격한 시작으로 해석하지 않음.
- PM2.5도 `16·36·76`의 공통 감각 경계는 확인되지 않아 하늘빛·냄새·목의 칼칼함·공기 텁텁함으로 공식 등급을 역산하지 않음. 체감은 PM10과 같은 기록 틀을 공유할 수 있지만 동시 PM10·PM2.5·오존·실내환경을 보존하고 오염물질 원인은 가능성형으로만 안내함.
- PM10과 PM2.5가 모두 있으면 물질명·값·등급을 각각 표시함. 한 줄 요약이 필요하면 같은 시간범위에서 더 높은 등급의 원인물질을 밝힌 `PM_WORST_HOURLY_SUMMARY_CALCULATED`를 사용할 수 있지만 앱 요약임을 표시하고 공식 통합대기환경지수나 농도합계로 부르지 않음. PM2.5가 있다는 이유로 PM10을 숨기거나 `미세먼지`라는 일반 라벨로 값을 표시하지 않음.
- 현재 서버는 `pm25Value24`, `pm25Flag`, PM2.5 별도 1시간/24시간 등급을 반환하지 않고 `pm25Grade1h ?? pm25Grade`와 PM10 등급을 `airQualityGrade` 하나로 합침. 결측 PM2.5를 `0`으로 바꾸고 `pm25>=36`에서 `PM25_HIGH`를 만들며 심각도를 `pm10+pm25`로 계산함. 현재 앱은 PM2.5 우선값 하나를 `미세먼지`로 표시하고 `0~35 safe·36~75 caution·76+ danger`로 공식 4등급을 3단계로 바꿈.
- `OFFICIAL_PM25_FORECAST_GRADE`, `OFFICIAL_PM25_24H_GRADE`, `OFFICIAL_PM25_1H_GRADE`, `OFFICIAL_PM25_ALERT_ACTIVE`, `OFFICIAL_PM25_CRISIS_ACTIVE`, `OFFICIAL_PM25_EMERGENCY_REDUCTION_ACTIVE`, `PM25_PERSONAL_EXPOSURE_UNCERTAIN`, `PM25_FEEL_CHECK_AVAILABLE`, `PM25_FEEL_RESPONSE_RECORDED`, `PM25_NO_NOTICEABLE_CHANGE_RECORDED`, `PM_WORST_HOURLY_SUMMARY_CALCULATED` 상태와 관련 데이터모델 후보를 추가함.
- 공식 발표·측정은 확정형, 내부 피해·체감·활동판정은 모두 가능성형으로 유지함. 제품 코드·최종 화면문구는 변경하지 않았고 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-6은 사용자 미확정 권장안이며 확정 전에는 5-7 민감군 미세먼지 기준으로 이동하지 않음.

### 기준 채택 5-6 및 검토 5-7: 민감군 미세먼지 기준
- 사용자의 `확정 후 다음`에 따라 5-6 PM2.5 등급 권장안을 확정해 기준 문서 제목·상태·최종 목록을 채택으로 변경함. 공식 PM2.5 4등급, 1시간/C24E/권역예보·경보·위기경보·비상저감조치 분리, PM10 동시표시, 공통 체감경계 미생성 원칙을 최종 채택함.
- 다음 항목인 5-7 민감군 미세먼지 기준을 에어코리아·환경보건포털 공식 민감군 범위와 등급별 행동요령, 국내 천식아동·COPD·호흡기입원·임신부·노년층·연령별 천식입원·알레르기비염 연구를 대조해 미확정 권장안으로 작성함.
- 공식 민감군 표현은 `임산부·영유아, 어린이, 노인, 심뇌혈관질환자, 호흡기·알레르기질환자` 등을 보존하도록 함. 앱은 별도 민감군 PM 등급이나 점수를 만들지 않고 5-5·5-6의 공식 네 등급을 그대로 사용함.
- 민감군 대상은 사람별 사용자/보호자 직접선택 또는 동의한 의료진 행동계획으로 기록하도록 함. 약 이름·혈압값·기침·흡입기 소지로 질환을 추정하거나 외모·문장으로 임신을 추정하지 않으며, 한 사람의 민감군 맥락을 가족 전체에 적용하지 않음.
- 공식 페이지에는 `노인·어린이`의 제품용 단일 나이경계가 없어 연구의 `15세 미만·65세 이상·80세 이상` 구간을 자동 분류선으로 사용하지 않음. 생년월일 자동분류는 적용할 공공정책·법적 생애단계와 버전이 별도 확정된 뒤 검토하도록 함.
- 공식 민감군 행동요령은 `보통`에서 몸상태에 따라 유의, `나쁨`에서 장시간·무리한 실외활동 제한, `매우나쁨`에서 가급적 실내활동·실외활동 시 의사와 상의로 확인함. 공식 안내가 제공됐다는 사실은 확정형으로, 앱의 개인 영향·활동조정은 가능성형으로 분리함.
- `보통`은 피해 시작선이 아니라 `민감군 맥락 + 관련 실외활동`에서 몸상태 확인을 제안할 수 있는 진입선으로만 사용함. 평소와 다른 불편이나 개인 행동계획이 없으면 모든 민감군의 실외활동을 자동 축소하지 않음.
- `나쁨/매우나쁨` 또는 활성 공식 경보와 확인된 사람별 민감군 맥락, 관련 시간의 실제/계획 실외활동이 함께 있을 때만 `오래 있거나 숨이 찰 만큼 움직이면 불편이 두드러질 수 있어요`, `시간·강도·실내대안 조정이 도움이 될 수 있어요` 같은 가능성을 생성하도록 함.
- 공식자료와 국내 연구에서 `장시간·무리한 활동`의 공통 분·속도·MET 경계는 확인되지 않아 `30분·1시간` 같은 임의 제한선을 만들지 않음. 활동시간·강도·평소 반응을 저장하고 운영값은 별도 검증하도록 함.
- 현재/오늘/내일 자료를 활동시간과 맞춰 사용하도록 함. 지금 활동은 활성 경보와 유효한 최근 측정, 미래 일정은 해당 날짜·권역 공식 예보를 우선하고, PM10·PM2.5는 각각 보존하며 서로 다른 시간의 최악값을 현재 판정으로 합치지 않음.
- 2026년 서울 천식아동 예비연구의 개인센서 `25㎍/㎥·72시간`은 소표본 탐색값이라 공통 행동선에서 제외함. 2025년 국내 COPD 105명 패널의 실내 `16.2±8.4`·실외 `17.2±5.0㎍/㎥`와 계절별 임상연관도 당일 임계값으로 사용하지 않음.
- 전국 약 139만 건 호흡기입원의 여성·아동·노인 차이, 임신부 662명 개인노출 연구, 65세 이상 536만여 명 12개월 장기노출 연구는 민감군 국내 근거로 반영하되 집단·누적 시간창을 당일 개인 증상·외출분수·결과예측으로 바꾸지 않음.
- 국내 7대 도시 연구에서 PM10-천식입원 연관성이 65세 초과에서 성인보다 컸지만 15세 미만에서는 성인보다 작았고, 인천 알레르기비염 일지에서는 고농도 3일에도 코 증상 연관성이 관찰되지 않은 반례를 반영함. 민감군 내부도 균일하지 않아 유형 수를 합산해 심각도를 올리지 않음.
- `PM_SENSITIVE_GUIDANCE_TARGET_RECORDED`, `PM_SENSITIVE_CONTEXT_UNKNOWN`, `OFFICIAL_PM_SENSITIVE_GUIDANCE_SHOWN`, `PM_SENSITIVE_BODY_CHECK_AVAILABLE`, `PM_SENSITIVE_OUTDOOR_LOAD_POSSIBLE`, `PM_SENSITIVE_ACTIVITY_ADJUSTMENT_POSSIBLE`, `PM_SENSITIVE_PERSONAL_PLAN_RELEVANT`, `PM_SENSITIVE_EFFECT_CAUSE_UNCERTAIN`, `PM_SENSITIVE_TIMING_MISMATCH`, `PM_SENSITIVE_DATA_INSUFFICIENT` 상태 후보를 추가함.
- 현재 앱·서버에는 사람별 건강 프로필·보호자관계·개인 행동계획·활동시간/강도 모델이 없고, 서버는 PM 고농도를 사람 맥락 없이 합산 심각도와 마스크 추천에 연결함. 현재 PM 값만으로 5-7 상태를 생성할 수 없음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-7은 사용자 미확정 권장안이며 확정 전에는 5-8 마스크 권고 기준으로 이동하지 않음.

### 5-7 국내 실제 수치·체감 추가 연구
- 사용자가 국내 한국 기준의 실제 수치와 체감 연구를 더 조사하도록 요청해 5-7을 미확정으로 유지하고, 천식아동 가정 실내 PM2.5·PEFR 교차시험, 아토피피부염 아동 실내/실외 PM·매일 증상일지, 천식 성인 황사 증상일지, 2026년 인천 노인 실내 PM2.5 교육 중재를 추가 대조해 기준 문서를 보강함.
- 2020년 인천 천식아동 26명의 가정 7주 교차시험에서 필터 사용 시 실내 PM2.5가 최대 `43%` 낮아졌고 조건 간 중앙값 차이는 `6.5㎍/㎥`였음. 일 단위 PM2.5 `1㎍/㎥` 증가와 PEFR `0.2%`, 주 단위 증가와 `1.2%` 감소가 연관됐지만 공통 주관증상 발생농도는 제시하지 않아 `1·6.5`를 체감·활동·기기작동선으로 사용하지 않음.
- 2021년 수도권 아토피피부염 아동 64명의 `9,321 person-day` 가정 실측에서 실내 PM2.5 평균 `28.7±24.3`, 겨울 `47.1±29.6㎍/㎥`가 측정됐고 가려움·수면방해·붉어짐·건조·진물·붓기를 매일 기록함. 전체 `10㎍/㎥` 증가당 증상 `0.9%` 증가는 유의하지 않았지만 봄 `16.5%`, 겨울 `12.6%` 증가는 유의해 계절·환경별 차이를 반영함.
- 위 피부연구의 `28.7·47.1`은 실내센서 일평균과 연구표본 평균이며 공식 실외 PM2.5 등급·개인 가려움 시작선이 아님. 온습도·포름알데히드·계절·알레르겐 감작·공기청정기 유무가 함께 달라 `47.1부터 피부가 가려워요` 문구를 금지함.
- 2017년 수도권 5세 이하 아토피피부염 아동 177명의 17개월·`35,158 person-day` 일지에서 실외 PM10 `10㎍/㎥` 증가와 같은 날 증상 `3.2%` 증가가 연관됐음. 온도·습도·일교차·강수·NO2·오존도 각각 연관돼 PM10 단독 원인·특정 농도 문턱으로 사용하지 않음.
- 2002년 인천 천식 성인 64명의 하루 두 번 증상·PEF 일지에서 14개 황사일 PM10 일평균 `188.5㎍/㎥`, 비교일 `60.0㎍/㎥`가 기록됨. PM10 증가는 야간증상·평균 PEF 감소·PEF 변동 `20% 초과`와 연관됐지만 주간증상·기관지확장제 사용과는 연관되지 않아 낮에 느낌이 없더라도 객관변화가 없다고 판단하지 않도록 함.
- 2026년 인천 65세 이상 59명의 6주 비무작위 예비중재에서 마지막 주 실내 PM2.5가 중재군 `11.1±5.7`, 대조군 `19.6±15.8㎍/㎥`로 측정되고 예측 FEV1·FEV6가 개선됐지만 자기효능감과 여러 자기보고 인식 변화는 작고 대부분 유의하지 않았음. 객관적 폐기능·환경수치와 주관인식이 함께 변하지 않을 수 있는 C등급 근거로 반영함.
- 국내 실제자료를 추가해도 PM10 `31·81·151`, PM2.5 `16·36·76` 또는 연구값 `11.1·16.2·17.2·19.6·25·28.7·29.4·47.1·60·188.5` 중 공통 체감 시작농도는 확인되지 않았음. 체감기준을 농도표가 아니라 `관련 공식 정보가 있을 때 민감군 유형별로 무엇을 물을지` 정하는 질문기준으로 변경함.
- 호흡기 선택지는 `목이 까끌까끌/칼칼함·기침·쌕쌕거림·숨참·가슴답답/묵직함·밤기침/수면방해·활동이 버거움`, 피부는 `간질간질/가려움·푸석함/당김·붉어짐·진물·붓기·수면방해`, 눈·코는 `뻑뻑함/따가움·코막힘·콧물·재채기·가려움`으로 구체화함.
- 심뇌혈관질환은 국내 연구가 입원·응급실·사망 중심이라 농도별 공통 감각선을 만들지 않고 공식 행동요령의 가슴 압박감·통증·두근거림을 현재 몸상태 확인항목으로만 둠. 임산부 연구도 임신기간 결과를 다뤘으므로 태아상태나 조산을 체감문구로 만들지 않음.
- 영유아·말로 표현하기 어려운 어린이는 보호자 관찰 `기침이 잦아 보임·쌕쌕거림이 들림·가려워 긁음·잠을 설침·활동량이 달라 보임`, 아이 직접응답, PEFR 같은 기기측정을 별도 기록하도록 함. 보호자 관찰을 아이의 직접체감이나 진단으로 바꾸지 않음.
- 체감 기본 확인시점은 관련 활동 직후 또는 같은 날로 두고, 사용자 확인 천식·호흡기 민감성과 고농도 황사/PM10 노출이 함께 있을 때만 다음날·2일 뒤 선택적 기록을 허용함. 이 창을 PM 원인확정이나 모든 민감군·PM2.5·피부·심혈관 추적기간으로 확대하지 않음.
- `PM_SENSITIVE_GROUP_FEEL_CHECK_AVAILABLE`, `PM_SENSITIVE_GUARDIAN_OBSERVATION_RECORDED`, `PM_SENSITIVE_OBJECTIVE_CHANGE_RECORDED` 상태와 `pmGroupSpecificFeel`, `pmObjectiveResponse`, 기록주체 구분을 추가함. 사용자/보호자 기록은 확정형, 검증된 기기 측정은 `측정됐어요`, 내부 원인·영향은 가능성형으로 유지함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정했으며 테스트·배포·커밋은 수행하지 않음. 5-7은 계속 사용자 미확정 권장안이며 5-8로 이동하지 않음.

### 기준 채택 5-7 및 검토 5-8: 마스크 권고 기준
- 사용자의 `확정 후 다음`에 따라 국내 실제 수치·체감 연구로 보강한 5-7 민감군 미세먼지 기준을 최종 채택함. 기준 문서의 제목·상태·최종 목록을 채택으로 변경했고 제품 반영 전 회귀검증 원칙은 유지함.
- 다음 항목인 5-8 마스크 권고 기준을 에어코리아 공식 행동요령, 식약처 2026년 최신 안내·KF등급/의약외품 구분·품목허가 조회방법, 한국소비자원 KF94 비교시험, 국내 실제 착용·밀착·운동·질환 연구를 대조해 미확정 권장안으로 작성함.
- 공식 PM 예보·측정·경보와 공식 행동요령, 정확한 제품의 식약처 보건용 마스크 품목허가 사실은 `예보됐어요·측정됐어요·발령됐어요·공식 행동요령이 제공됐어요·허가 제품으로 확인됐어요`처럼 확정형으로 안내하도록 함. 앱이 계산하는 노출감소 도움·밀착·호흡/피부 부담·활동 적합성은 가능성형으로만 안내함.
- KF80은 평균 `0.6㎛` 입자 `80% 이상`, KF94·KF99는 평균 `0.4㎛` 입자 각각 `94%·99% 이상`을 걸러내는 식약처 시험등급으로만 사용함. KF 수치를 개인의 실제 PM 노출감소율·질환예방률·안전보장률로 바꾸거나 `나쁨=KF80·매우나쁨=KF94/99` 같은 일률 표를 만들지 않음.
- 2026-03-04 식약처가 미세먼지가 심한 날에는 보건용 마스크의 `의약외품(KF)` 여부를 확인해 사용하도록 다시 공식 안내한 최신자료를 반영함. 정확한 제품명·업체·허가 식별자·KF등급을 의약품안전나라 `[32200] 보건용 마스크` 현재 결과와 대조하고 조회시각을 저장하도록 함.
- KF-AD는 비말차단용, 수술용은 별도 목적의 의약외품이므로 KF80·94·99 보건용 마스크와 합치지 않음. 방한대·천/스포츠마스크·제품불명·해외/민간표시는 미세먼지 차단성능이나 KF 환산등급을 만들지 않음.
- 식약처 안내상 자진취하·취소 제품은 현재 품목검색에서 보이지 않을 수 있고 수출용은 국내 판매대상이 아니며 제품명이 변경될 수 있어, 과거 `허가됨=true` 캐시를 영구 사실로 쓰지 않도록 함. 포장의 `의약외품·KF` 표시는 사용자 기록으로 보존하되 현재 품목 일치 전 정품·현재 허가·성능을 확정하지 않음.
- 공식 고농도 행동요령 진입선인 관련 시간의 `나쁨/매우나쁨` 또는 활성 경보와 실제/계획 실외노출이 함께 있을 때만 마스크 도움 가능성을 검토함. `좋음/보통`, 실외활동 없음·결측, 시간·지역 불일치에서는 PM만으로 자동 마스크 권고를 만들지 않으며 마스크 불필요도 확정하지 않음.
- 2020년 서울 고령 여성 21명의 6일 KF80 생활환경 준실험에서 밀착을 반영한 추정 PM2.5 노출이 대조기간 `28.8㎍/㎥` 대비 `19.8㎍/㎥`였고 안정시 수축기혈압은 `5.3mmHg` 낮았지만 일부 생리적 스트레스 지표는 증가했음. 노출감소 도움과 착용부담이 함께 있을 수 있는 국내 B등급 근거로 사용하고 `20㎍/㎥·9㎍/㎥·5.3mmHg`를 앱 행동선·개인효과로 사용하지 않음.
- 국내 의료진 귀걸이형 KF94 연구에서는 성인 30명의 정량 밀착계수 중앙값이 일반착용 `6`, 연결클립 밀착착용 `29`로 달랐고, 별도 30명·330회 N95/KF94 시험도 제품·착용자·귀끈 고정에 따라 결과가 달랐음. 병원 감염관리 기준·클립 결과를 생활 미세먼지 의무나 개인 보호율로 옮기지 않고 필터등급과 얼굴밀착을 분리할 근거로만 사용함.
- 한국소비자원 2021년 KF94 대형 흰색 9개 제품은 당시 분진포집효율·안면부누설률·안면부흡기저항 기준을 충족했지만 같은 대형도 형태·치수가 달랐음. 조사제품 결과를 현재 모든 KF94 또는 개인 밀착보장으로 확대하지 않고 제품·얼굴 조합을 별도로 확인하도록 함.
- 2022년 국내 건강한 남성 15명의 단계별 운동실험은 KF94·스포츠마스크 조건의 주관 불편이 무마스크보다 높고 활동단계가 오를수록 증가했지만 심박수·산소포화도·에너지효율의 조건 간 유의차는 없었음. `들이쉴 때 뻑뻑함·안쪽이 후끈함·습기가 차 눅눅함·활동할수록 답답함`을 친화적 체감 선택지로 쓰되 보편 산소저하·안전보장·운동금지선으로 바꾸지 않음.
- 인천 COPD 환자 97명의 N95 휴식·6분 보행시험에서 7명이 전 과정을 착용하지 못했고 착용실패군의 호흡곤란 점수와 폐기능이 달랐음. 호흡기질환자의 개인 착용 가능성을 별도로 확인할 보조근거로만 사용하고 N95 결과를 KF등급에 환산하거나 앱이 COPD 중증도·사용금지를 판정하지 않음.
- 얼굴 밀착과 착용반응은 `코가 나옴·턱으로 내려감·콧등/볼/턱 옆으로 바람이 샘·말할 때 들썩임·들이쉴 때 뻑뻑함·숨이 답답함·후끈함·눅눅함·달라붙음·쓸림/가려움·귀 당김·안경 김서림·냄새·잘 모르겠음`으로 직접 기록하도록 함. 기록사실만 확정하고 주관적 누설감·셀카·안경 김서림·불편 없음으로 정량 밀착·보호를 확정하지 않음.
- 세탁·재사용·수건/휴지 덧대기·변형·젖음·오염은 제품상태와 공식 사용법 확인으로 다루고 잔존 필터성능을 계산하지 않음. 숨쉬기 힘듦·가슴통증 직접기록이 있으면 즉시 벗고 무리해 착용하지 않도록 한 식약처·에어코리아 공식 주의사항을 확정형으로 보여주되 앱이 원인질환·산소저하를 진단하거나 약·진료를 지시하지 않음.
- `OFFICIAL_PM_MASK_GUIDANCE_SHOWN`, `OFFICIAL_HEALTH_MASK_PRODUCT_CONFIRMED`, `MASK_PRODUCT_STATUS_UNKNOWN`, `PM_MASK_OUTDOOR_CONTEXT_MISSING`, `PM_MASK_EXPOSURE_REDUCTION_POSSIBLE`, `PM_MASK_FIT_RECHECK_AVAILABLE`, `PM_MASK_FIT_UNCERTAIN`, `PM_MASK_BREATHING_BURDEN_POSSIBLE`, `PM_MASK_HEAT_MOISTURE_DISCOMFORT_POSSIBLE`, `PM_MASK_SKIN_COMFORT_BARRIER_POSSIBLE`, `PM_MASK_OFFICIAL_STOP_GUIDANCE_RELEVANT`, `PM_MASK_USER_RESPONSE_RECORDED`, `PM_MASK_PERSONAL_PLAN_RELEVANT`, `PM_MASK_TIMING_MISMATCH`, `PM_MASK_DATA_INSUFFICIENT` 후보를 추가함.
- `MASK_REQUIRED/SAFE/NOT_NEEDED`, `KF94_ALWAYS_REQUIRED`, `KF80_ALWAYS_SUFFICIENT`, `KF99_BEST_FOR_ALL`, 개인 보호율 계산, 셀카 밀착확정, 무증상 안전확정, 질환예방 확정 상태는 만들지 않음.
- 현재 서버는 `PM10>=81` 또는 `PM2.5>=36`에서 `PM_HIGH/AIR_QUALITY_BAD`를 만들고 `lifestyleBuilder.ts`가 사람·활동·제품 없이 바로 `MASK_USEFUL`을 생성함. 앱의 `마스크 챙겨요`와 `외출 전에 대기질을 확인하고 마스크를 챙겨요` 문구도 제품허가·밀착·착용반응을 반영하지 않음.
- 현재 `maskEnabled`는 알림 수신설정이지 보건용 마스크 보유·제품·밀착·착용 가능 정보가 아님. 식약처 품목조회, 제품ID/KF등급, 실외활동시간, 사람별 민감 맥락, 밀착·불편·중단 기록이 없어 현재 값만으로 5-8 상태를 생성할 수 없음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 문서 전용 변경이라 자동테스트·배포·커밋은 수행하지 않았으며 `git diff --check`만 확인함. 5-8은 사용자 미확정 권장안이고 확정 전에는 5-9 오존 등급으로 이동하지 않음.

## 2026-08-25

### Cloudflare Worker Git 자동 배포 검토
- 서버는 Cloudflare Pages 애플리케이션이 아니라 `weather_care_server/wrangler.toml`을 사용하는 Cloudflare Worker이며, 운영 주소도 `workers.dev`임을 확인함.
- 현재 Cloudflare Workers Builds는 GitHub/GitLab 저장소의 선택 브랜치 push를 감지해 `npx wrangler deploy`를 자동 실행할 수 있음. 모노레포 Root directory는 `weather_care_server`, production branch는 현재 로컬 기준 `master`, deploy command는 `npm run deploy` 또는 `npx wrangler deploy`가 적합함.
- 이 서버는 별도 산출물 생성용 `build` 스크립트가 없으며 Wrangler 배포가 TypeScript 번들링을 포함함. 따라서 로컬 빌드 완료를 트리거로 삼기보다 Git push 기반 Workers Builds를 Pages 배포와 별도로 연결하는 구성을 권장함.
- Worker 이름 `weather-care-server`와 Wrangler 설정 이름은 이미 일치하고 Wrangler 4.x가 개발 의존성으로 선언되어 있음. D1 바인딩과 기존 런타임 Secret은 같은 Worker에 유지하되 Build variables와 Runtime variables/secrets를 구분해야 함.
- 로컬 저장소에는 Git remote가 등록되어 있지 않아 자동 배포 구성 전에 GitHub 또는 GitLab 원격 저장소에 먼저 push해야 함.
- 설명 및 구성 검토만 수행했으며 Cloudflare 설정, 소스 코드, 배포, 테스트, 커밋은 변경하거나 실행하지 않음.

### 기준 채택 5-8 및 검토 5-9: 오존 등급
- 사용자의 `확정 후 다음`에 따라 5-8 마스크 권고 기준을 최종 채택함. 기준 문서의 제목·상태를 채택으로 바꾸고 `확정 전 변경하지 않는다`는 문구를 공식자료·실외활동·정확한 허가제품·밀착·착용반응 결합조건의 구현·검증 후 반영하는 원칙으로 변경함.
- 다음 항목인 5-9 오존 등급을 에어코리아 공식 4등급·통합대기환경지수·권역예보·대기환경기준·시도 경보, 수도권 최근 발령현황, 국내 천식환자 개인노출·안구건조·국민건강영양조사·서울 장기추세·폭염 동시노출 연구를 대조해 미확정 권장안으로 작성함.
- 공식 오존 4등급은 `좋음 0~0.030ppm`, `보통 0.031~0.090ppm`, `나쁨 0.091~0.150ppm`, `매우나쁨 0.151ppm 이상`을 한국어 명칭 그대로 사용하도록 권장함. 공식 원표 `0~0.0300·0.0301~0.0900·0.0901~0.1500·0.1500 초과`를 보존하고 표시값을 반올림한 뒤 재분류하지 않도록 함.
- `0.120ppm`은 공식 4등급의 나쁨이면서 주의보 발령기준 시작값이지만 수치 비교와 시·도 공식 발령을 분리함. `0.150ppm`은 나쁨이고 `0.151ppm`부터 매우나쁨이며, 경보화면의 `0.12 미만 보통`은 경보 미발령 구간 표기라 4등급 보통으로 저장하지 않음.
- 권역 예보, 측정소 1시간 값·오존 개별등급, 오존 개별지수, 전체 CAI, 국내 대기환경기준 `8시간 0.06·1시간 0.1ppm`, 시·도 주의보/경보/중대경보 `0.12/0.30/0.50ppm` 발령·전환·해제를 별도 자료와 상태로 분리함.
- 공식 예보·측정·발령·해제·국가 기준은 `예보됐어요·측정됐어요·발령됐어요·해제됐어요·정해졌어요`로 확정 안내하고, 실시간 측정은 최종확정 전 자료임을 표시하도록 함. 앱의 개인노출·체감·건강영향·원인·활동 적합성은 가능성형으로만 안내함.
- 수도권대기환경청의 2025년 현황에서 수도권 오존주의보 `32일·122회`, 서울 `16일(16회)`, 인천 `16일(39회)`, 경기 `29일(67회)`가 공식 집계됐고, 에어코리아 최근 현황에서 2026-08-24 사천 `15시 발령·16시 해제`, 진주 `15시 발령·17시 해제`, 경주 `15시 발령·19시 해제`가 확인됨. 일예보나 하루 최고값으로 경보 활성시간을 대신하지 않을 근거로 반영함.
- 현재 운영상 오존 예보는 `4월 1일~10월 31일` 제공되고 당일 등급은 `05시·11시`, 특이사항은 `17시` 정보로 제공될 수 있음을 기록함. 발표일정은 바뀔 수 있어 발표시각·대상 날짜·원문 유형을 저장하고, 예보 결측을 좋음으로 채우지 않도록 함.
- 2005년 천안·청주 중등도~중증 천식환자 17명의 개인측정 연구에서 일평균 오존 `28.2±23.6ppb`, 범위 `3.4~315.3ppb`가 측정됐고 전체 증상점수는 오존과 약한 양의 상관 `ρ=0.303`, `80ppb 미만`에서도 `ρ=0.298`이었음. 아침 가슴답답함·숨참은 약하게 연관됐지만 같은 날~3일 PEF와 증상완화제 사용은 유의하지 않아 `28.2·80ppb`를 공통 체감·행동선으로 쓰지 않음.
- 국내 안구건조증 환자 33명 연구에서 검사 전 1주 평균 오존 `0.01ppm` 증가가 OSDI `3.43점` 증가·눈물분비 `1.43mm` 감소와 연관됐고, 국민건강영양조사 16,824명에서는 연평균 오존 `0.003ppm` 증가가 잦은 눈 통증·불편과 안구건조 진단의 높은 오즈와 연관됐음. 환자군·주평균·연평균 결과라 당일 등급경계별 체감값으로 바꾸지 않음.
- 서울 2001~2019년 MDA8 연구의 `60ppb 초과일`, 한국 7대 도시 2014~2023년 폭염·고오존 동시노출 연구의 평균 MDA8 `0.050ppm`과 평균 일최고기온 `27.8℃`는 기상·지속시간·건강연관성의 보조근거로만 사용함. 공식 1시간 등급·주의보·개인 피해선으로 사용하지 않음.
- 국내 연구를 추가해도 `0.031·0.091·0.151ppm`의 공통 감각문턱은 확인되지 않아 농도별 체감표를 만들지 않음. 체감은 `눈 시큰/따끔/뻑뻑함·눈물`, `코가 찡함·목 따끔/칼칼함`, `마른기침·쌕쌕거림·숨참·가슴답답/깊은 숨 불편`, `톡 쏘거나 매캐한 공기 인상·평소와 비슷함·잘 모르겠음`의 직접기록으로 분리함.
- `끈적함·눅눅함·후텁지근함`과 `매캐함·톡 쏘는 냄새`는 사용자가 느낀 사실로 기록할 수 있지만 오존 고유체감이나 등급판별 감각으로 쓰지 않음. 온습도·땀·PM·연기·VOCs·꽃가루 등 동시요인을 보존하고 원인은 가능성형으로만 안내함.
- `OFFICIAL_O3_FORECAST_GRADE`, `OFFICIAL_O3_1H_GRADE`, `OFFICIAL_O3_ALERT_ACTIVE/LIFTED`, `O3_ALERT_THRESHOLD_OBSERVED`, `O3_ENVIRONMENTAL_STANDARD_REFERENCE_SHOWN`, `O3_FORECAST_MEASUREMENT_DIFFER`, `O3_WEATHER_FORMATION_CONTEXT_POSSIBLE`, `O3_FEEL_CHECK_AVAILABLE/RESPONSE_RECORDED/NO_NOTICEABLE_CHANGE_RECORDED`, `O3_PERSONAL_EXPOSURE_UNCERTAIN`, `O3_EFFECT_CAUSE_UNCERTAIN`, `O3_TIMING_MISMATCH`, `O3_DATA_INSUFFICIENT` 후보를 추가함.
- `O3_SAFE/DANGER/DAMAGE_OCCURRED/SYMPTOM_CAUSED/ALERT_INFERRED/NO_SYMPTOM_SAFE/OUTDOOR_FORBIDDEN/MASK_PROTECTED` 상태는 만들지 않음. 오존은 기체 오염물질이므로 PM용 KF등급과 결합해 개인 오존 보호율을 만들지 않도록 함.
- 현재 서버는 `o3Value/o3Grade`를 `ozone/ozoneGrade`로 보존하지만 `o3Flag`, 측정소 코드·측정망·거리, 원자료 정밀도, 실시간/최종확정, 공식 한국어 원등급, 권역예보·경보·CAI·환경기준을 보존하지 않음. 현재 실시간 공기질은 첫 시간대에만 병합되고 미래 오존예보가 없으며 Flutter 앱에는 오존 표시·체감입력 연결이 확인되지 않음.
- 현재 환기·외출 후보 로직은 `Bad/Very Bad` 오존등급을 제외하기만 하고 공식 행동요령·경보·사람별 활동·체감을 연결한 오존 사실을 만들지 않음. 현재 `ozoneGrade=Bad` 하나로 개인 영향·주의보 활성·야외활동 제한을 생성할 수 없고, 구체적 활동조건은 다음 5-10에서 검토하도록 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 5-9는 사용자 미확정 권장안이며 확정 전에는 5-10 오존 야외활동 기준으로 이동하지 않음.

### 앱·서버 모노레포 배포 구조 확인
- `weather_care_app`과 `weather_care_server`가 하나의 Git 저장소에 함께 올라가는 모노레포 구조여도 Cloudflare 자동 배포가 가능함을 확인함.
- Worker의 Git 연결에서 Root directory를 `weather_care_server`로 지정하면 Wrangler 설정과 명령은 서버 하위 폴더 기준으로 실행됨.
- 앱 변경만으로 불필요한 서버 배포가 발생하지 않도록 Worker Build watch include path를 `weather_care_server/*`로 제한하는 구성을 권장함. 향후 공유 패키지가 생기면 해당 공유 경로도 include에 추가해야 함.
- Pages 또는 별도 앱 배포가 필요하면 같은 Git 저장소를 독립 프로젝트로 한 번 더 연결하고 Root directory와 watch path를 `weather_care_app`으로 분리할 수 있음.
- 설명 및 구성 검토만 수행했으며 Cloudflare 설정, 소스 코드, 배포, 테스트, 커밋은 변경하거나 실행하지 않음.

### Workers Builds 대시보드 설정 화면 검토
- 사용자가 제공한 Cloudflare Workers Builds 화면에서 Git 저장소 `sohay19/weather_care`, production branch `master`, Root directory `weather_care_server`, deploy command `npx wrangler deploy`, non-production deploy command `npx wrangler versions upload`가 현재 저장소와 일치함을 확인함.
- Build command가 비어 있어도 Wrangler deploy가 TypeScript 번들링을 수행하므로 배포 자체에는 문제가 없음. 별도 타입검사나 테스트를 배포 전 품질 게이트로 둘 때만 Build command를 추가하면 됨.
- Build watch include path `weather_care_server/*`는 저장소 루트 기준 서버 하위 변경을 감시하는 올바른 모노레포 설정임.
- `node_modules/**`, `.git/`은 Git push 변경 경로에 포함되지 않으므로 exclude에서 제거해도 되며, 유지하려면 UI에서 각각 별도 패턴으로 확정 입력해야 함.
- `프로덕션 이외 분기에 대한 빌드`는 브랜치별 preview version이 필요할 때만 켜고, `master` 배포만 원하면 끄는 것이 적합함.
- 로컬 Git remote `weather_care`가 `https://github.com/sohay19/weather_care.git`으로 등록된 것도 확인함.
- 화면 검토와 인계 기록만 수행했으며 Cloudflare 설정 변경, 배포, 테스트, 커밋은 실행하지 않음.

### 기준 채택 5-9 및 검토 5-10: 오존 야외활동 기준
- 사용자의 `확정 후 다음`에 따라 5-9 오존 등급을 최종 채택함. 기준 문서의 제목·상태를 채택으로 바꾸고 제품 반영 전 공식자료 종류·유효시간·지역·품질·체감기록을 분리 구현하고 회귀검증하는 원칙은 유지함.
- 다음 항목인 5-10 오존 야외활동 기준을 에어코리아 공식 등급·경보 행동요령, 서울시 최근 실제 발령·지속시간, 국내 엘리트선수·광양만 어린이·천식환자 연구, 국제 통제노출·등산 현장연구를 대조해 미확정 권장안으로 작성함.
- 공식 오존 예보·측정과 주의보·경보·중대경보의 발표·발령·전환·해제, 단계·대상군별 공식 행동요령은 출처·지역·유효시간과 함께 확정형으로 안내함. 공식 원문의 `자제·제한·피해야 함·금지·중지`는 그대로 표시하고 앱이 임의로 완화·강화하지 않음.
- 앱 개인화는 관련 야외활동의 계획/실제 시간·실내외·위치, 사용자가 느낀 숨참 정도, 사용자 확인 민감군, 직접반응, 개인 행동계획을 별도로 결합해 노출부담·불편·시간/강도 조정·실내대안의 가능성만 안내함.
- 에어코리아의 `장시간 또는 무리한 실외활동`에는 공식 분·속도·심박수/MET 정의가 없고 국내 연구에도 공통 수치경계가 없어 `30분·60분·몇 km/h` 같은 자체 행동선을 만들지 않음. 실제 분 수는 기록하되 `59분=괜찮음·60분=장시간`으로 분류하지 않음.
- 활동부담은 종목명으로 확정하지 않고 `숨이 평소와 비슷함·조금 빨라지지만 문장으로 말할 수 있음·자주 차고 짧게 말함·평소보다 버거움·잘 모르겠음`의 직접기록으로 받도록 함. 이는 사용자 기록이지 표준 운동강도·폐기능값이 아님.
- 좋음은 공식 행동요령 표의 `-`를 표시하되 안전·무영향으로 바꾸지 않음. 보통은 일반인에게 자동 활동축소 가능성을 만들지 않고 사용자 확인 민감군·개인계획·과거 직접반응이 있으면 몸상태·공식정보 재확인 가능성을 제시함.
- 나쁨/매우나쁨과 관련 야외계획이 겹치면 대상군별 공식 행동요령을 확정 표시하고 `시간을 줄이거나 숨이 덜 차는 움직임·실내대안을 고르는 편이 도움이 될 수 있어요`처럼 앱의 조정 판단을 가능성형으로 분리함.
- 주의보·경보·중대경보는 공식 발령 이벤트가 있을 때만 활성화하고, 사용자 무증상·마스크·과거 경험을 공식 행동요령의 예외로 사용하지 않음. 해제는 공식 해제사실만 확정하며 즉시 안전·좋음·개인영향 종료로 바꾸지 않음.
- 서울시 공식 분석에서 2024년 8월까지 주의보 `31일·109회`, 평균 지속 `3.2시간`, 실제 `1~10시간`, 가장 늦은 해제 `23시`가 확인됨. `오후만 피하면 됨·일몰 후 자동 해제·3.2시간 뒤 해제` 같은 고정 시간규칙을 만들지 않을 최근 국내 실제 근거로 반영함.
- 2019~2020년 한국체육대 엘리트선수 59명·10회 방문 연구에서는 O3와 폐기능 연관 방향이 단일/다중오염물질 모형에서 달랐고 다중모형에서 기온 영향이 가장 컸음. 운동·오존·다른 오염물질·기상을 함께 보존할 근거로 쓰되 일반인 운동금지선으로 사용하지 않음.
- 2009년 광양만 주민 2,283명 연구에서는 9~14세 어린이의 FVC·FEV1과 오존 간 음의 연관이 관찰되고 검사일~2일 전 평균에서 연관이 가장 컸으며 노출추정법·측정소·시간활동패턴의 중요성이 제시됨. 어린이 맥락과 노출불확실성 근거로만 쓰고 1시간 등급별 분·속도 기준으로 바꾸지 않음.
- 국제 MOSES는 55~70세 87명의 `0·70·120ppb·3시간 간헐운동`, 2026년 연구는 19~34세 38명의 `0.07ppm·6.6시간 간헐운동`, 등산객 연구는 530명의 `21~74ppb` 혼합노출을 다룸. 시간·활동부담을 함께 고려할 보조근거로만 사용하고 연구 수치·변화율을 개인 안전시간·손상률·국내 등급경계로 사용하지 않음.
- `OFFICIAL_O3_FORECAST_ACTIVITY_GUIDANCE_SHOWN`, `OFFICIAL_O3_ALERT_ACTIVITY_GUIDANCE_SHOWN`, `O3_ACTIVITY_RECHECK_POSSIBLE`, `O3_ACTIVITY_LOAD_ADJUSTMENT_POSSIBLE`, `O3_INDOOR_ALTERNATIVE_POSSIBLE`, `O3_OUTDOOR_DISCOMFORT_POSSIBLE`, `O3_FEEL_CHECK_AVAILABLE`, `O3_ACTIVITY_RESPONSE_RECORDED`, `O3_PERSONAL_PLAN_RELEVANT`, `O3_ACTIVITY_TIMING_MISMATCH/CONTEXT_MISSING/CAUSE_UNCERTAIN` 후보를 추가함.
- `O3_ACTIVITY_SAFE/DANGEROUS/ALLOWED/FORBIDDEN`, `O3_DAMAGE_OCCURRED`, `O3_SAFE_MINUTES`와 연구결과 기반 개인 폐기능 변화율·안전시간 상태는 만들지 않음. 사용자 반응·활동축소·실내이동·중단은 `기록됐어요`로 확정하고 오존 원인·질환악화·손상은 가능성으로 남김.
- 현재 서버는 실시간 `o3Value/o3Grade`만 저장하고 `Bad/Very Bad`를 환기·외출 후보에서 제외할 뿐 미래 오존예보·공식 경보/행동요령·민감군·활동시간/숨참·체감이 없음. `RESPIRATORY_CAUTION`의 `긴 야외활동은 줄이는 편이 좋아요` 템플릿도 자료·사람·활동 조건이 드러나지 않아 공식 카드와 내부 가능성 카드로 분리한 뒤 연결하도록 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 5-10은 사용자 미확정 권장안이며 확정 전에는 다음 `대기 정체` 항목으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 기준 채택 5-10 및 검토 5-11: 대기 정체
- 사용자의 `확정 후 다음`에 따라 5-10 오존 야외활동 기준을 최종 채택함. 기준 문서 제목·상태를 채택으로 변경했고 공식 행동요령과 앱 내부 가능성 판단을 분리하며 자체 분·속도·안전/금지선을 만들지 않는 원칙을 유지함.
- 다음 5-11 대기 정체를 기상청 공식 대기정체지수, 공공데이터 계약, 에어코리아 원인분석, 환경부 최근 실제 기상·고농도 분석, 국내 지역·장거리이동 연구와 대조해 미확정 권장안으로 작성함.
- 기상청 대기정체지수의 발표·예측시각·지역·공식 `낮음/보통/높음/매우 높음`은 `예측됐어요`로 확정 안내함. 지수 자체가 `대기가 정체될 수 있는 가능성`을 뜻하므로 공식 문장 안의 가능성 표현을 유지하고, 이를 실제 오염농도·경보·개인피해로 바꾸지 않음.
- 국립환경과학원·에어코리아가 `대기 정체·기류 수렴으로 미세먼지가 축적될 것으로 예상`, `바람·강수·연직 확산으로 감소 예상` 같은 원인분석을 발표하면 원문·발표시각·날짜·권역과 함께 확정형으로 표시함. 앱의 개인노출·불편·피해는 가능성형으로 분리함.
- 공공데이터 설명의 `0~7`은 정체에 유리한 기상학적 임계조건을 만족한 요소 개수이며 `0~2 낮음·3~5 보통·6 높음·7 매우 높음`임. 2023년 명칭변경 공지의 `25 낮음·50 보통·75 높음·100 매우 높음` 계약과 구분하고, 원값을 확률이나 공통척도로 비교하지 않음.
- 공급자·API/스키마버전·단위/방향·발표/유효시각이 없는 기존 `WeatherSnapshot.airStagnationIndex?: number`는 `0~7`과 `25~100` 중 계약을 알 수 없어 공식등급·추세판정에 사용하지 않도록 함. `STAGNATION_INDEX_CONTRACT_UNKNOWN` 상태를 제안함.
- 공식 지수 `높음/매우 높음`만 있으면 `공기 흐름이 더디게 이어질 가능성`까지만 안내함. 같은 시간·지역의 높은/상승 PM10·PM2.5·O3·NO2가 있을 때만 `오염물질이 가까운 공기층에 머물 가능성이 있어요`를 검토하고 단독원인·미래농도·피해는 확정하지 않음.
- 공식 지수가 높지만 오염등급이 좋으면 현재 축적·고농도를 확정하지 않음. 반대로 PM이 나쁘지만 지수가 낮음/보통이면 PM 공식 행동요령을 그대로 보여주고 정체 원인을 붙이거나 PM 자료를 약화하지 않도록 비대칭 결합규칙을 둠.
- 환경부 2024년 분석의 `풍속 0.5m/s 이하 무풍`은 19개 지점 연도별 발생빈도 조건, 2022년 계절관리제의 `일평균 2m/s 미만`은 34개 지점 정체일수 조건, 전북 2017년 연구의 `1.8m/s 미만`은 특정 지형·지점 결과임. 국내 실제 근거로 보존하되 전국 시간별 정체 임계값으로 사용하지 않음.
- 2024년 한국 연구에서 환기지수와 PM2.5 상관은 `-0.23`, NO2는 `-0.60`이었고 고농도일 장거리이동 영향은 지역배출 영향의 `2.9배`, 장거리이동-환기지수 상관은 `-0.03`이었음. 한국에서는 환기지수 하나로 PM2.5를 예측하기 어려워 정체지수→PM 농도 변환식을 만들지 않음.
- 혼합고·역전·환기지수·상층풍·역궤적·지형은 출처·방법·시간해상도를 보존한 보조맥락으로만 사용함. 임의 혼합고 위험선이나 지상풍 한 값으로 공식 4단계를 생성하지 않음.
- 사용자 체감은 `공기가 갇힌 듯 답답함·멀리 뿌옇게 보임·매캐/텁텁함·냄새가 오래 머무는 듯함·목/코 불편·바람 거의 없음·평소와 비슷함·잘 모름`으로 직접 기록함. 기록은 확정하고 정체·미세먼지·건강영향 원인은 가능성형으로만 안내함.
- `끈적함·눅눅함`은 주로 습도 체감일 수 있어 대기정체 전용 선택지에서 분리함. 안개·습도·연기·냄새원·실내 CO2·건물 차폐를 함께 보존하고 체감으로 공식 지수나 오염농도를 역산하지 않음.
- `OFFICIAL_KMA_STAGNATION_FORECAST`, `OFFICIAL_STAGNATION_GUIDANCE_SHOWN`, `OFFICIAL_AIR_QUALITY_STAGNATION_CAUSE`, `STAGNATION_FLOW_SLOW_POSSIBLE`, `POLLUTANT_ACCUMULATION_POSSIBLE`, `STAGNATION_HAZE_DISCOMFORT_POSSIBLE`, `WEAK_SURFACE_WIND_OBSERVED`, `VERTICAL_MIXING_LIMITED_POSSIBLE`, `STAGNATION_POLLUTION_DIVERGE`, `STAGNATION_FEEL_CHECK_AVAILABLE/RECORDED`, `STAGNATION_CAUSE_UNCERTAIN`, `STAGNATION_TIMING_MISMATCH`, `STAGNATION_INDEX_CONTRACT_UNKNOWN`, `STAGNATION_DATA_INSUFFICIENT` 후보를 추가함.
- `AIR_STAGNATION_OCCURRED`, `STAGNATION_SAFE/DANGEROUS/DAMAGE_OCCURRED`, 풍속·혼합고 기반 자체 공식등급, 정체지수 기반 PM등급, 사용자 체감 기반 원인확정, 새 측정 없는 오염해소 확정은 만들지 않음.
- 현재 `lifestyleTemplates.ts`의 `대기가 정체되는 시간이에요 · 민감하다면 실외운동을 미루세요.`는 공식 지수·오염도·사람·시간·가능성 근거가 드러나지 않아 바로 사용하지 않도록 함. 공식 지수·공식 대기질 원인·앱 가능성·사용자 기록 카드를 분리한 뒤 연결하도록 제안함.
- 5-11은 정체와 오염축적 가능성까지만 다루고 `창문 닫기·환기 금지/가능·공기청정기 필수`는 판정하지 않음. 다음 미확정 항목은 5-12 `환기 가능 대기질`이며, 5-11을 사용자가 확정하기 전에는 자동으로 이동하지 않음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않았으며 `git diff --check`로 형식을 검증함.

### 기준 채택 5-11 및 검토 5-12: 환기 가능 대기질
- 사용자의 `확정 후 다음`에 따라 5-11 대기 정체 권장안을 최종 채택함. 기상청 공식 지수·에어코리아 공식 원인분석은 확정형, 앱의 오염축적·답답함 가능성은 가능성형으로 분리하고 풍속 `0.5·1.8·2m/s`를 전국 공통 정체선으로 쓰지 않는 원칙을 유지함.
- 다음 5-12 환기 가능 대기질을 환경부 2024 공동주택 관리요령, 국가미세먼지정보센터·질병관리청 행동요령, 국내 공동주택·학교의 실내외 PM2.5·CO2·창문/기계환기 실측연구와 대조해 미확정 권장안으로 작성함.
- 환기 결과를 단일 `좋음/나쁨`으로 만들지 않고 `실외 공기 유입부담`, `실내 공기교환 필요 맥락`, `창문·국소배기·필터형 기계환기 등 방법 적합성` 세 축으로 분리함. 세 축이 모두 확인되지 않으면 창문 개방 문구를 만들지 않음.
- 환경부 공동주택 공식 안내상 대기 미세먼지 보통 이하에서는 하루 3번 30분 자연환기·맞통풍, 나쁨 이상에서는 창문을 닫고 기계식 환기/공기정화장치를 사용하며 장치가 없으면 자연환기 10분 이내를 안내함. 이 공식 시간은 해당 상황과 함께 확정 표시하되 앱의 보편 안전시간·제거완료시간으로 사용하지 않음.
- 국가미세먼지정보센터의 평시 `10~21시·하루 3번 30분 이상·도로변 외 창문`, 고농도 자연환기 자제, 조리 뒤 30분 이상 환기를 공식 안내로 보존함. `10~21시`를 매일 고정 최적시간으로 만들지 않고 현재 측정을 우선함.
- 질병관리청은 가스레인지·조리 중 NO2·CO·미세먼지 등이 발생할 수 있어 조리 전부터 창문 또는 후드를 사용하고 조리 뒤 30분까지 환기하도록 안내함. 조리 발생원이 있을 때 공식 안내를 보여주되 `30분이면 제거 완료`로 바꾸지 않음.
- PM10 `81㎍/㎥`, PM2.5 `36㎍/㎥`는 공식 나쁨 시작값으로 고농도 환기 안내의 진입점으로 사용하되 단일 값으로 경보·절대 환기금지를 만들지 않음. PM10·PM2.5를 각각 보존하고 통합 농도나 자체 환기 위험등급을 만들지 않음.
- `OUTDOOR_AIR_INTAKE_LOWER_BURDEN_POSSIBLE`은 현재 PM10·PM2.5·오존이 같은 시간·지역에서 모두 좋음/보통이고 경보·황사/연기/화학사고 통제가 없을 때만 검토함. 문구에는 `확인된 PM과 오존 기준으로`를 넣고 전체 공기 안전·환기 필요로 확정하지 않음.
- 오존이 나쁨 이상이거나 공식 경보가 활성 중이면 PM이 좋아도 외기부담 낮음 상태를 만들지 않음. 국내 공식 오존등급별 창문 개방시간이 확인되지 않아 자체 환기금지 농도·시간은 만들지 않음.
- 실내 CO2 `1,000~2,000ppm`에서 불쾌감이 나타날 수 있다는 질병관리청 보건정보는 공기교환 검토·체감질문의 참고범위로만 사용함. `1,000ppm`을 가정 건강피해·두통원인·자동창문 개방선으로 사용하지 않음.
- 2014년 한국 공동주택 연구에서 필터형 기계환기가 자연환기보다 입자 실내외비를 서브마이크론 `26%`, 큰 미세입자 `65%` 낮췄지만 연구설비 결과이므로 모든 제품·가정의 제거율로 복사하지 않음.
- 2022년 한국 아파트 조리실험에서 초기 실내 PM2.5 약 `150㎍/㎥`, 실외 `40㎍/㎥`, 창가풍속 `0.4m/s`, 후드+20분 자연환기 조건 뒤 실내 `57㎍/㎥`가 관찰됨. 실내가 실외보다 높으면 외기가 나쁨이어도 환기가 실내입자를 낮출 수 있는 상충근거로 사용하되 `20분·0.4m/s·57`을 완료시간·최소풍속·목표값으로 쓰지 않음.
- 2021년 한국 아파트 10가구 연구에서 최고 실내입자는 주로 조리로 발생하고 비효율적 환기 시 오래 남았으며 일일 통합 입자노출의 실내·실외 발생원 기여는 `21.4%·78.6%`였음. 10가구 평균을 특정 집의 원인비율로 쓰지 않고 실내발생원·외기유입을 함께 볼 근거로 사용함.
- 2023년 국내 도시학교 13곳 연구는 자연환기가 CO2·공기전파 관련 부담을 낮추는 반면 실외 PM을 들일 수 있는 상충을 보여줌. 학교조건을 가정의 개방시간으로 복사하지 않고 공기교환 필요와 외기오염 유입을 분리하는 근거로 사용함.
- 2015~2019년 8개 국내 지역 시간자료에서 PM은 아침에 높고 오후에 낮아졌다 저녁에 다시 오르는 평균경향과 `14~18시` 제안이 있었지만 지역·계절 차이가 컸음. 현재 앱의 `오후에는 창문을 짧게 열어도 좋아요`를 확정문구로 쓰지 않고 당일 현재 측정을 재확인하도록 함.
- 실내가 실외보다 오염도가 높은 조리 등 상충상황에서는 후드·필터형 기계환기·짧은 맞통풍의 도움 가능성을 비교함. `밖이 나쁨=무조건 무환기` 또는 `환기하면 항상 깨끗`으로 처리하지 않음.
- 외기공급형 기계환기와 실내 재순환형 공기청정기를 분리함. 공기청정기는 실내입자 저감 가능성만 안내하고 CO2·라돈·발생원을 외부로 내보내는 환기완료로 표시하지 않음.
- 도로변 반대편 창, 강수·강풍·온도·실내외 수증기량·방범·소음은 방법 선택의 가능성 보정으로만 사용함. 현재 서버의 강수확률 `<20%`, 풍속 `1~5m/s`, 2개 슬롯을 공식 환기 가능 대기질 경계로 사용하지 않음.
- 환기 전후 체감은 `퀴퀴함·갇힌 듯 답답함·냄새·까끌거림·후끈/눅눅함·산뜻함·덜 답답함·찬바람·건조함·매캐/도로냄새·차이 없음·잘 모름`으로 직접 기록함. 기록은 확정하고 CO2·PM·VOC·효과·건강영향 원인은 가능성형으로 남김.
- `OFFICIAL_RESIDENTIAL_VENTILATION_GUIDANCE_SHOWN`, `OFFICIAL_HIGH_PM_VENTILATION_GUIDANCE_SHOWN`, `OFFICIAL_COOKING_VENTILATION_GUIDANCE_SHOWN`, `OUTDOOR_AIR_INTAKE_LOWER_BURDEN_POSSIBLE`, `NATURAL_VENTILATION_PARTICLE_INFLOW_POSSIBLE`, `OUTDOOR_O3_INTAKE_BURDEN_POSSIBLE`, `INDOOR_AIR_EXCHANGE_REVIEW_POSSIBLE`, `INDOOR_POLLUTANT_REMOVAL_BY_VENTILATION_POSSIBLE`, `VENTILATION_TRADEOFF_REVIEW_POSSIBLE`, `FILTERED_MECHANICAL_VENTILATION_POSSIBLE`, `SOURCE_EXHAUST_OPTION_POSSIBLE`, `ROADSIDE_INTAKE_BURDEN_POSSIBLE`, `VENTILATION_WEATHER_CONSTRAINT_POSSIBLE`, `VENTILATION_FEEL_CHECK_AVAILABLE/RESPONSE_RECORDED`, `VENTILATION_TIMING_MISMATCH`, `VENTILATION_METHOD_UNKNOWN`, `VENTILATION_DATA_INSUFFICIENT`, `OTHER_OUTDOOR_AIR_INPUT_MISSING` 후보를 추가함.
- `VENTILATION_SAFE/DANGEROUS/REQUIRED/FORBIDDEN`, `CLEAN_AIR_CONFIRMED`, 공기청정기=환기, 10/30분 제거완료, 오후 고정최적, 풍속 1~5m/s 허용선, 체감으로 농도·효과 역산 상태는 만들지 않음.
- 현재 서버 `VENTILATION_GOOD`는 PM 숫자가 나쁨이어도 `airQualityGrade`가 비어 있으면 통과할 수 있고 오존도 숫자만 있을 때 고농도를 제외하지 못함. 에어코리아 현재값은 첫 시간슬롯에만 병합되는데 2개 연속슬롯을 요구해 실제 시간창 근거도 부족함.
- `timeSeriesLifestyleBuilder`의 최소 `10분`, 템플릿의 `환기하기 좋은 시간이에요·10분 정도 창문을 열어요`, Flutter의 `오후에는 창문을 짧게 열어도 좋아요`는 공식 고농도 상황·실내 필요·설비방법 없이 확정/지시하므로 5-12 구조가 구현되기 전에는 사용하지 않도록 함.
- 프로젝트에는 실내 CO2·PM·VOC·CO·라돈 센서, 조리/연소/냄새 사건, 창 방향·도로측, 외기형 기계환기/재순환청정기 구분, 필터·풍량·점검상태, 환기 전후 기록이 없어 현재 데이터만으로 개인화된 5-12 상태를 생성할 수 없음.
- 꽃가루는 다음 5-13에서 공식 위험지수와 사용자 알레르기 맥락을 검토하기 전까지 `OTHER_OUTDOOR_AIR_INPUT_MISSING`으로 유지함. 5-12는 사용자 미확정 권장안이며 확정 전에는 5-13 꽃가루·알레르기 위험으로 이동하지 않음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않았으며 `git diff --check`로 형식을 검증함.

### 기준 채택 5-12 및 검토 5-13: 꽃가루·알레르기 위험
- 사용자의 `확정 후 다음`에 따라 5-12 환기 가능 대기질 권장안을 최종 채택함. 공식 PM10·PM2.5·오존과 기관별 환기 행동요령은 확정형, 외기유입·실내오염배출·방법 적합성·체감변화는 가능성형으로 분리하는 원칙을 유지함.
- 다음 5-13 꽃가루·알레르기 위험을 기상청 공식 꽃가루농도위험지수, 국립기상과학원 최신 관측 달력, 질병관리청 예방·관리 안내, 국내 서울·구리 수종별 농도-증상 연구, 전국 국민건강영양조사 감작 연구와 대조해 미확정 권장안으로 작성함.
- 기상청 꽃가루농도위험지수는 기온·풍속·강수·습도로 꽃가루농도와 알레르기질환 발생 가능 정도를 예측하는 공식 정보이며 현재 `3~6월·8~10월`, 하루 `06·18시` 두 번 글피까지 참나무·소나무·잡초류의 `낮음/보통/높음/매우높음`을 제공함.
- 공식 수종군·단계·발표/유효시각·지역과 단계별 대응요령은 `예측했어요·안내했어요`로 확정 전달함. 공식 매우높음의 외출 자제·선글라스/마스크·창문 닫기·증상 악화 시 전문의 방문 등은 기관 안내로 표시하고 앱 자체 의무·금지로 다시 만들지 않음.
- 앱 개인화는 사용자가 확인해 둔 감작/알레르기 수종, 실제 야외·창문·환기 노출, 코·눈·목·호흡·피부의 직접기록을 분리해 개인노출·불편·활동조정·실내유입 가능성만 안내함. 공식 지수를 실제 꽃가루 개수·개인증상·알레르기 진단으로 바꾸지 않음.
- 국립기상과학원 2025 달력은 `2014~2024년` 8개 도시·13종 관측을 통계 처리한 생물계절 자료이며 실제 해 기상에 따라 날림시기가 `1~2주` 달라질 수 있음. 오늘의 예보·실측·개인증상으로 사용하지 않음.
- 현재 기상청 서비스 안내 `3~6월·8~10월`, 질병관리청 2024 설명 `4~6월·8~10월`, 관측연구의 2~11월 꽃가루 존재 가능성을 별도 출처로 보존함. 공급자 최신 실제 운영기간을 우선하고 서비스기간 밖 결측을 `0·낮음·알레르기 없음`으로 채우지 않음.
- 2010~2017년 서울·구리의 감작 확인 환자 `792명` 연구에서 같은 날 꽃가루-증상지수 상관계수는 참나무 `0.20`, 소나무 `0.16`, 돼지풀 `0.31`, 환삼덩굴 `0.34`였음. 상관계수를 개인 증상확률·인과로 계산하지 않음.
- 같은 연구의 수종별 일평균 참고경계는 참나무 `0~2/3~11/12~28/29 이상`, 소나무 `0~4/5~42/43~66/67 이상`, 환삼덩굴 `0~8/9~10/11~19/20 이상`, 돼지풀 `0~1/2~6/7~33/34 이상 개/㎥`임.
- 이 경계는 수도권·감작 확인 환자·Burkard 채집기·9~47세·교란요인 미보정 연구등급임. 수종별 차이가 커 전국 통합선을 만들지 않고 현재 기상청 공식 4단계로 변환하지 않으며, 비교 가능한 실측이 있어도 `수도권 연구 참고등급`으로만 사용함.
- 6년 서울·구리 `596명` 연구는 5월·9월 농도 정점과 증상지수 관련성을 보였지만 연구의 참나무 `day 1`, 환삼덩굴 `day 0`을 모든 사용자의 고정 증상시차·인과규칙으로 만들지 않음.
- 2019 국민건강영양조사 `2,386명` 분석의 하나 이상 감작 `45.1%`, 참나무 `11.2%`, 자작나무 `10.2%`, 돼지풀 `8.7%`, 환삼덩굴 `7.0%`는 개인별·수종별 차이의 전국 근거로 사용함. 인구비율로 특정 사용자의 감작·진단·오늘 증상을 추정하지 않음.
- 공식 단계가 높음/매우높음이어도 감작수종 미확인이면 공식 정보만 보여주고 개인 증상을 예측하지 않음. 수종 불일치는 별도 상태로 남기고 소나무→참나무, 잡초류→환삼덩굴/돼지풀/쑥의 일치나 교차반응을 자동확정하지 않음.
- 공식 낮음도 심하게 민감한 환자에게 증상이 나타날 수 있다는 기상청 안내를 보존해 `낮음=안전·무증상`을 만들지 않음. 달력만 있거나 예측/실측/활동 시각이 다르면 현재 개인노출을 확정하지 않음.
- 친화적 체감 선택지는 `코 간질간질·연속 재채기·맑은 콧물·코막힘·눈 가려움/눈물/충혈/모래알 같은 까끌함·입천장/목/귀 가려움·잔기침·쌕쌕거림·가슴답답·숨참·피부 가려움·피로·평소와 비슷함·잘 모름`으로 구성함.
- 사용자/보호자의 실제 체감·야외활동·창문개방·마스크/세안/샤워 기록은 확정형으로 보존함. 꽃가루·수종·미세먼지·감염·건조·실내항원 중 원인과 행동효과·질환악화는 가능성형으로만 안내함.
- 5-12와 연계해 PM·오존이 좋음/보통이어도 꽃가루 높음/매우높음과 일치 감작이 있으면 `POLLEN_WINDOW_INTAKE_BURDEN_POSSIBLE`을 외기유입부담에 추가하도록 함. 앱 자체 창문 절대금지·몇 분까지 안전 상태는 만들지 않음.
- `OFFICIAL_POLLEN_RISK_FORECAST_SHOWN`, `OFFICIAL_POLLEN_GUIDANCE_SHOWN`, `POLLEN_CALENDAR_CONTEXT_SHOWN`, `POLLEN_SENSITIZATION_MATCH_RECORDED`, `POLLEN_PERSONAL_EXPOSURE_POSSIBLE`, `POLLEN_OUTDOOR_DISCOMFORT_POSSIBLE`, `POLLEN_WINDOW_INTAKE_BURDEN_POSSIBLE`, `POLLEN_ACTIVITY_ADJUSTMENT_POSSIBLE`, `POLLEN_FEEL_CHECK_AVAILABLE/RESPONSE_RECORDED`, `POLLEN_GROUP_MISMATCH`, `POLLEN_FORECAST_OBSERVATION_DIFFER`, `POLLEN_TIMING_MISMATCH`, `POLLEN_SEASON_SERVICE_UNAVAILABLE`, `POLLEN_EFFECT_CAUSE_UNCERTAIN`, `POLLEN_DATA_INSUFFICIENT` 후보를 추가함.
- `POLLEN_SAFE/DANGEROUS/ALLERGY_OCCURRED`, 앱의 알레르기 진단, 외출·창문 금지, 약 복용 명령, 마스크 보호확정, 기온 `20~30℃·풍속 2m/s` 기반 자체 단계, 체감·보이는 가루 기반 원인/등급 역산은 만들지 않음.
- 현재 서버에는 계약 없는 `WeatherSlot.pollenRisk?: string`만 있고 공급자 매핑·생활규칙 사용이 없음. `ALLERGY_CAUTION` 열거형과 `꽃가루가 많이 날릴 수 있어요/민감하다면 마스크를 챙기세요`, `외출 후 꽃가루를 털어주세요` 템플릿은 생성 규칙에 연결되지 않았고 공식 출처·수종·단계·사람·시각도 드러나지 않음.
- 구현 전 공식지수/관측/달력/감작/노출/체감을 각각 저장하는 데이터모델이 필요함. 현재 값만으로 5-13 개인화 상태를 생성할 수 없고, 기존 템플릿은 공식 행동요령 카드와 앱 가능성 카드로 분리한 뒤 연결해야 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 5-13은 사용자 미확정 권장안이며 확정 전에는 다음 5-14 `호흡기질환자 행동 기준`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 기준 채택 5-13 및 검토 5-14: 호흡기질환자 행동 기준
- 사용자의 `확정 후 다음`에 따라 5-13 꽃가루·알레르기 위험 권장안을 최종 채택함. 기상청 공식 꽃가루 수종군·단계·발표/유효시각·대응요령은 확정형, 앱의 개인노출·불편·활동조정·실내유입·행동효과는 가능성형으로만 표시하는 원칙을 유지함.
- 다음 5-14 호흡기질환자 행동 기준을 기상청 천식폐질환 가능지수, 에어코리아 호흡기·알레르기질환자 행동요령, 질병관리청 최신 천식·COPD 안내, 국내 천식/COPD 응급실·입원·개인노출·증상일지·스마트폰 행동계획 연구와 대조해 미확정 권장안으로 작성함.
- 기상청 천식폐질환 가능지수는 최저기온·일교차·현지기압·상대습도 기반이며 연중 하루 `06·18시` 두 번 글피까지 `낮음/보통/높음/매우높음`을 예측함. 공식 단계·대응요령은 확정 전달하되 개인 증상·현재 폐기능·PM/오존 실측·질환악화로 변환하지 않음.
- 공식 지수 낮음도 `호흡기질환자 안전·무증상`으로 표시하지 않음. 높음의 `자주 환기`와 `대기오염 증가 시 문을 닫기`는 상황조건이 다르므로 5-12 외기유입부담·실내 공기교환 필요·환기방법을 함께 확인하도록 함.
- 정보 우선순위는 최신 의료진 개인 행동계획 → 사용자의 현재 직접기록과 계획구간 → 유효한 공식 경보·행동요령 → 공식 예보/측정·기상청 가능지수 → 앱 활동조정 가능성 순으로 정함. 앱이 계획의 PEF·약물·산소·연락 빈칸을 채우지 않음.
- PM10·PM2.5·오존·꽃가루·기상지수는 각각 공식카드로 보존함. 합산 `호흡기 위험점수`나 최댓값 하나를 만들지 않고 각 출처·물질·단계·시간을 확정 안내한 뒤 개인 활동부담·시간/강도/장소 조정은 가능성형으로만 붙임.
- 질병관리청 2025 천식 안내의 `말하기 힘든 숨참`, `눕기 힘든 숨참`, `불안을 동반한 숨참`, `약 사용 뒤에도 나아지지 않는 호흡곤란`을 사용자가 직접 기록하면 기록사실과 질병관리청의 즉시 병원방문 안내를 각각 확정 표시함. 앱이 천식발작·원인·중증도를 진단하지 않음.
- 질병관리청 COPD 안내의 평소보다 심한 호흡곤란·기침, 가래 양/색 변화, 갑작스러운 일상활동 곤란·기존치료로 조절 어려움과 병원방문 안내를 보존함. 사용자의 변화기록은 확정하지만 앱이 COPD 급성악화·감염·치료를 확정하지 않음.
- 직접체감은 같은 활동 대비 `숨이 더 참·계단에서 쉬게 됨·말하며 걷기 버거움·헐떡임`, `띠로 조이는 듯한 가슴·묵직함·쌕쌕거림`, `마른/젖은 기침·밤기침`, `더 끈끈한 가래·양/색 변화·목에 걸린 듯함`, 잠·일상 변화로 기록함. 사용자/보호자 기록은 확정하고 원인·질환악화는 가능성으로 남김.
- 국내 2007~2013년 의료이용 연구는 낮은 평균기온/습도·큰 일교차/기압·PM/오존과 입원/응급실 이용의 연관성을, 2013~2018년 COPD `1,404,505명·악화 15,282건` 연구는 비선형 환경관계와 최대 10일 지연을 보여줌. 연구 수치·지연일을 개인 임계값·알림 지속일로 사용하지 않음.
- 춘천 `583명·660건` 천식 응급실 연구의 낮은 습도 1~2일, 높은 풍속 1~3일 연관과 국내 COPD `594명` 연구의 낮은 최저기온·인플루엔자·과거 악화 연관을 보존함. 공통 습도%·풍속m/s·기온℃ 증상선을 만들지 않음.
- 경기도 천식 입원 `290,464건`·COPD 입원 `85,301건`, COPD 개인 PM2.5 `105명`, 인천 황사 천식성인 `64명` 연구를 실제 국내 근거로 추가함. 집단 입원확률·연구평균 `16.2/17.2/188.5㎍/㎥`를 개인 체감·외출금지선으로 쓰지 않음.
- 국내 성인 천식 스마트폰 예비시험 `44명`은 작성된 행동계획·증상·PEF·연구진 직접연락을 함께 사용했음. 앱 기반 기록 가능성의 보조근거로만 쓰고 의료진 없는 독립진단·자동치료지시의 효과로 확장하지 않음.
- 대한천식알레르기학회 행동지침의 개인 최대 PEF 대비 `80/50%` 구간은 의료진이 작성하는 개인계획 구조로만 사용함. 질병관리청 COPD 안내의 안정상태 `SpO2 88% 이하`는 가정 산소치료 적용 맥락이므로 모든 질환의 공통 응급·안전선으로 쓰지 않음.
- `RESPIRATORY_CONTEXT_UNCONFIRMED`, `RESPIRATORY_OUTDOOR_BURDEN_POSSIBLE`, `RESPIRATORY_ACTIVITY_ADJUSTMENT_POSSIBLE`, `KMA_RESPIRATORY_INDEX_PLAN_RECHECK_POSSIBLE`, `RESPIRATORY_CHANGE_RECORDED`, `RESPIRATORY_ENVIRONMENT_RELATION_POSSIBLE`, `RESPIRATORY_PERSONAL_PLAN_RELEVANT`, `OFFICIAL_RESPIRATORY_URGENT_GUIDANCE_RELEVANT`, `RESPIRATORY_TIMING_OR_REGION_MISMATCH`, `RESPIRATORY_OTHER_TRIGGER_UNKNOWN`, `RESPIRATORY_DATA_INSUFFICIENT` 후보를 추가함.
- `RESPIRATORY_SAFE`, `OUTDOOR_EXERCISE_ALLOWED`, `ASTHMA_ATTACK_OCCURRED`, `COPD_EXACERBATION_CONFIRMED`, `LUNG_DAMAGE_OCCURRED`, 자체 복약/산소 명령, 기온·습도·풍속·일교차·PEF·SpO2 공통 위험/안전선, 환경·증상 합산점수는 만들지 않음.
- 현재 서버에는 `RESPIRATORY_CAUTION` 열거형과 두 템플릿만 있고 이를 실제 생성하는 규칙은 확인되지 않음. 공식 지수/경보·대상사람·활동시간/강도·개인 행동계획·평소 대비 증상·PEF/SpO2 품질 모델이 없어 기존 템플릿을 바로 노출하지 않도록 함.
- 구현 전 사람별 건강맥락·보호자 관계·행동계획 버전/출처·활동·직접증상·기기품질·약 사용·감염/연기/실내노출·공식 진료안내 버전과 동의 기반 연락흐름이 필요함. 현재 날씨값만으로 5-14 개인화 상태를 생성하지 않음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 5-14는 사용자 미확정 권장안이며 확정 전에는 6장 첫 항목 `우산 준비`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 기준 채택 5-14 및 검토 6-1: 우산 준비
- 사용자의 `확정 후 다음`에 따라 5-14 호흡기질환자 행동 기준을 최종 채택함. 공식 천식폐질환 가능지수·공기질/꽃가루 정보·경보·행동요령과 사용자 직접기록은 확정형, 앱의 호흡불편·활동부담·조정은 가능성형으로만 안내하고 자체 질환단계·복약지시를 만들지 않는 원칙을 유지함.
- 다음 6-1 우산 준비를 기상청 현행 1시간/연장 3시간 단기예보 계약, 2017년 기상청 전국 이용자 조사와 서울 예보검증, 2004~2013년 서울·부산 예보가치 연구, 2014년 수도권 한국 출생 성인 직접문항, 국내 기상예보 트위터 이용행태, 기상청 1시간 예보 이용조사·강우체감·강풍/낙뢰 행동요령과 대조해 미확정 권장안으로 작성함.
- 공식 강수확률·강수형태·강수량·예보시간과 강수 관측·특보는 발표기관·지역·발표/관측·유효시각을 붙여 `발표됐어요·예보됐어요·관측됐어요·발효 중이에요`로 확정 안내함. 앱의 우산/비옷 휴대·젖음·사용불편은 `비를 만날 수 있어요·도움이 될 수 있어요·젖을 수 있어요·불편할 수 있어요`로만 표현함.
- 2017년 전국 성인 `1,500명` RDD 조사에서 우산 준비 최소 강수확률 평균은 상·하반기 `53.3%·52.6%`였지만, 같은 해 서울 24시간 예보의 정확도·F1은 `30%`, 만족가치는 `30~40%`에서 높았음. 연령별 기준과 임계값 변경효과도 달라 한 값을 한국인의 고정 행동선으로 만들지 않음.
- 2014년 서울·인천·경기 한국 출생 참가자 `161명` 직접문항의 평균은 `40.8%`, 표준편차 `20.5`였음. 수도권 소표본·위험성향 보조문항이라는 제한을 붙여 현재 프로젝트의 `40%`를 일반 기본 **C등급 후보선**으로 유지하는 근거로만 사용함.
- 일반 기본 준비 가능성은 `사용자의 비가림 없는 외출시간과 겹치는 POP ≥40%`로 제안함. `30% ≤ POP <40%`는 비를 놓치는 불편이 크다고 사용자가 직접 선택했거나 같은 맥락의 반복기록이 있을 때의 개인화된 이른 알림 후보로만 사용하고 일반 푸시·일정변경선으로 쓰지 않음.
- 공식 PTY가 비·비/눈·소나기·빗방울 계열이거나 PCP가 `강수없음`이 아니면 POP가 40%보다 낮다는 이유로 준비 가능성을 누락하지 않음. 순수 강설은 사용자 선호 또는 혼합강수 없이 일반 우산 추천으로 자동 연결하지 않음.
- `40% 미만=우산 불필요`, `40% 이상=비 발생/우산 필수`, POP의 지역비율·시간비율·강도 해석, 시간별 POP 합산이나 독립확률 계산, 예보하락 뒤 `괜히 챙김`, 우산 미지참을 사용자 책임으로 평가하는 문구는 만들지 않음.
- 하루 최대 POP 대신 출발·이동·환승·귀가의 비가림 없는 구간과 겹치는 슬롯을 사용함. 외출시간 미확인 시 공식 예보시간을 밝히고 `그 시간에 외출한다면` 조건부 가능성만 제공함. 출발지·경로·목적지 격자도 분리함.
- 정상 1시간 수치 슬롯과 2024년 11월 이후 연장기간 3시간 정성 슬롯은 `slotDuration·rawValue`를 보존하고 같은 강수량으로 합산하지 않음. 시간별 확률도 합계나 `1-∏(1-p)`로 하루 확률을 만들지 않음.
- `≥15mm/h`에는 우산을 써도 머리카락·어깨·바짓단·신발이 젖을 가능성, 평균풍속 `4~9m/s 미만`과 취약/노출조건에는 손목·팔 부담 가능성, 평균 `≥9m/s`·공식 최대순간 `≥10m/s`·돌풍·강풍특보에는 안정적 사용 어려움 가능성을 4-5에서 재사용함.
- 공식 낙뢰 예상/관측·호우특보·침수/급류 정보가 있으면 일반 우산 편의카드보다 기상청의 비옷 준비·안전장소 대피 등 공식 행동요령을 우선함. 강한 비·바람을 더 큰 우산 추천으로 단순 치환하지 않고 비옷·후드·가방 방수커버 대안의 편의 가능성을 제시함.
- 국내 2014년 트윗 `15,783건` 중 의견·감정 `2,921건` 분석에서 쓰지 않은 우산을 더운 날 들고 다닌 불편과 비를 놓쳐 퇴근길에 젖은 표현이 함께 확인됨. 두 손실을 모두 개인 설정·피드백으로 수집하되 비대표 소셜미디어 표본을 수치선으로 사용하지 않음.
- 직접체감은 `얼굴/안경에 빗방울·머리/어깨 축축·바짓단/신발 젖음·옷 눅눅함·손목 뻐근함·한 손이 묶여 불편·우산 미사용`으로 구체화함. 사용자 기록은 확정하고 날씨·예보오류·행동효과·다음 최적기준은 가능성으로만 남김.
- 현재 서버는 `POP ≥40% OR PCP 하한 ≥0.5mm → RAIN_LIKELY → RAIN_GEAR_USEFUL → UMBRELLA`로 연결해 40% 후보는 맞지만 PTY 단독비·활동시간·경로·대안장비·바람/낙뢰를 반영하지 못함. 24시간 최대 POP와 슬롯 PCP 하한합은 무관한 시간 추천과 강수량 오해 가능성이 있음.
- Flutter 상세화면도 시간별 POP `40%`를 표시선으로 쓰고, 설정에는 `umbrellaEnabled`만 있어 개인 POP 기준·젖음/헛휴대 손실·노출시간·결과기록이 없음. 현재 `우산을 챙겨요·확인하세요` 명령형 템플릿은 공식 예보카드와 앱 가능성 카드로 분리해야 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-1은 사용자 미확정 권장안이며 확정 전에는 다음 6-2 `양산 준비`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 기준 채택 6-1 및 검토 6-2: 양산 준비
- 사용자의 `확정 후 다음`에 따라 6-1 우산 준비 권장안을 최종 채택함. 공식 강수 예보·관측·특보는 확정형, 앱의 비 만남·젖음·우산/비옷 도움·우산 조작부담은 가능성형으로 분리하고 일반 POP `40%`, 개인화된 이른 알림 `30~40% 미만` 후보와 PTY·PCP 보완조건을 유지함.
- 다음 6-2 양산 준비를 기상청 자외선지수 대응요령, 질병관리청 2025·2026년 폭염 행동요령, 국가 우산·양산 안전기준, 한국소비자원 2026년 우양산 12종 시험, 서울·진주의 고정 그늘 열환경 실측, 한국인 PT 온열감 연구 및 5-4·4-5 채택 기준과 대조해 미확정 권장안으로 작성함.
- 기상청 자외선지수 예보·관측과 폭염 영향예보·특보, 질병관리청의 외출 시 양산·모자 햇볕 차단 안내는 기관·시각·지역·유효시간과 함께 `예보됐어요·관측됐어요·발표됐어요·발효 중이에요·안내했어요`로 확정 안내함.
- 앱 내부 양산 준비는 `유효한 UVI 3 이상 + 실제/계획 야외구간 + 직사광선 또는 고정그늘 부족 + 손에 들 수 있는 활동`이 모두 확인될 때만 휴대용 그늘의 도움 가능성을 생성함. `UVI 3`은 기상청의 공식 일반 보호행동 진입점을 재사용한 후보선이지 양산 필수선이 아님.
- 자외선 가림과 더위 그늘을 분리함. 폭염 공식정보 또는 2-4 채택 더위 맥락과 야외 직사광선이 겹치면 햇볕의 뜨거움·눈부심이 덜 느껴질 가능성만 안내하고 온열질환 예방·기온/체감온도/중심체온의 고정 하락값을 만들지 않음.
- UVI `3 미만`도 5-2의 `2 SED` 장시간 참고맥락 또는 사용자 확인 자외선 민감 맥락이 있으면 가림수단의 도움 가능성을 다시 검토함. `2 SED`는 출시 전 검증용 C등급 참고값이며 필요선·안전시간이 아님.
- 기상청 UVI의 3시간 슬롯 최대 예측값을 사용자의 실제 야외구간과 연결함. 하루 최대 UVI를 하루 종일 적용하지 않고 예보·관측의 자료유형을 서로 바꾸지 않음. 출발 알림은 고정시각이 아니라 사용자 일정과 준비여유시간으로 계산하도록 제안함.
- 국가기준·한국소비자원 자료는 정확한 제품의 라벨·공식 시험값만 확정 표시함. 소비자원 12종 시험의 자외선 차단율 `96.9~99.9%`, 광 차단율 `87.4~100%`, 무게 `121~311g`, 6종 표시미흡을 모든 양산·암막·색상에 일반화하지 않음.
- 자외선 차단율·광 차단율·비 저항·제품무게·열감·중심체온을 별도 속성으로 저장함. 무게 범위가 커 현재 템플릿의 `가벼운 양산` 표현은 정확한 제품값 없이 쓰지 않도록 함.
- 평균풍속 `4~9m/s 미만 + 긴 사용·큰 캐노피·한 손 짐·유아동반·손목민감`은 손목·팔 부담 가능성, 평균 `9m/s 이상` 또는 공식 최대순간 `10m/s 이상`·돌풍·강풍특보는 안정적 사용 어려움 가능성으로 4-5를 재사용함. 구조시험풍속을 사람의 안전풍속으로 바꾸지 않음.
- 달리기·자전거·양손작업·유모차/휠체어/보행보조·짐 운반은 손과 시야 사용맥락을 별도로 확인함. 양산이 걸리적거리거나 쓰기 어려울 가능성과 챙이 넓은 모자·그늘진 경로의 대안 가능성만 안내하고 사용금지·위험을 확정하지 않음.
- 직접체감은 `그늘져 편함·햇볕이 덜 뜨거움·눈부심이 덜함·손목이 묵직함·팔이 뻐근함·손에 땀이 차 끈적함·바람에 잡아당겨짐·들썩임·걷는 데 걸리적거림·휴대가 번거로움·물기가 남아 눅눅함·가지고 갔지만 쓰지 않음·잘 모름`으로 기록함. 직접기록은 확정하고 다음 유사상황의 체감·편의·불편은 가능성형으로만 안내함.
- `OFFICIAL_UV_FORECAST_LINKED`, `OFFICIAL_UV_OBSERVATION_LINKED`, `OFFICIAL_HEAT_GUIDANCE_LINKED`, `PARASOL_PREP_POSSIBLE`, `PROLONGED_LOW_UV_PARASOL_POSSIBLE`, `PARASOL_HEAT_SHADE_POSSIBLE`, `PARASOL_PRODUCT_PERFORMANCE_CONFIRMED`, `PARASOL_CARRY_LOAD_POSSIBLE`, `PARASOL_STABILITY_IMPACT_POSSIBLE`, `HANDHELD_SHADE_INCOMPATIBLE_POSSIBLE`, `SUN_COVER_ALTERNATIVE_POSSIBLE`, `PARASOL_DATA_INSUFFICIENT` 후보를 추가함.
- `PARASOL_REQUIRED/NOT_NEEDED/FULL_UV_PROTECTION/COOLING_CONFIRMED/HEAT_ILLNESS_PREVENTED/SAFE_TO_USE`와 고정 냉각수치·가벼움 무게선은 만들지 않음. 공식 기상청 UVI 단계명 `위험`은 원문 표시할 수 있지만 앱의 개인 상태명으로 옮기지 않음.
- 현재 서버는 `UVI >=6`과 기온 `>=33℃`가 동시에 있을 때만 `STRONG_SUN_EXPOSURE → PARASOL`을 생성해 UVI `3~5`, 실제 외출·직사광선·고정그늘·활동·제품·바람을 반영하지 못함. 공식 자외선·폭염 카드, 양산 준비 가능성, 제품/바람/활동, 직접기록을 분리한 뒤 연결하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-2는 사용자 미확정 권장안이며 확정 전에는 다음 6-3 `선크림 준비`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 기준 채택 6-2 및 검토 6-3: 선크림 준비
- 사용자의 `확정 후 다음`에 따라 6-2 양산 준비 권장안을 최종 채택함. 공식 자외선·폭염정보와 기관 행동요령은 확정형, 앱의 휴대용 그늘·더위/눈부심 변화·휴대/조작 부담은 가능성형으로만 안내하고 `UVI 3 이상 + 야외 + 직사광선/그늘 부족 + 손 사용 가능` 조건을 유지함.
- 다음 6-3 선크림 준비를 5-3 채택 기준, 기상청 자외선지수, 질병관리청 자외선·피부 건강정보, 식약처 2026년 자외선차단제 사용안내, 한국소비자원 2025년 실제 제품조사·판매중단/환불, 국내 도포량·SPF·제형별 사용량·사용감 연구와 대조해 미확정 권장안으로 작성함.
- 공식 카드에서는 기관 원문 명칭 `자외선 차단제`, 생활 준비카드에서는 친화적인 `선크림`을 사용하고 첫 노출에서 `선크림(자외선 차단제)`로 연결함.
- 기상청의 UVI 예보·관측·대응요령, 식약처·질병관리청의 제품선택·외출 약 15분 전 도포·2시간 덧바름·분사형 취급·이상반응 안내, 정확한 제품의 기능성 상태·회수/환불은 기관·시각·제품식별·유효상태를 붙여 확정형으로 표시함.
- 앱 내부의 첫 도포 도움 가능성은 `유효한 UVI 3 이상 + 실제/계획 야외구간 + 옷으로 가리지 않은 피부`가 모두 확인될 때만 생성함. `UVI 3`은 공식 일반안내 진입점이지 선크림 필수선이 아님.
- `첫 도포`, `외출 중 휴대`, `덧바름`을 분리함. 첫 도포 후보에는 출발시각과 도포기록을, 휴대 후보에는 외출 중 공식 재안내 시점·땀/물/수건/마찰·외부 제품 접근 가능성을 추가 확인함.
- 식약처의 `외출 약 15분 전`은 사용자 출발시각에 연결해 공식 안내로 확정 표시하고 내부 준비 도움은 가능성형으로 붙임. 출발시각이 없으면 고정 07시나 하루 최대 UVI 기준 개인알림을 만들지 않음.
- 질병관리청의 `2시간마다`는 확인된 도포 뒤 공식 안내를 다시 보여줄 시점으로 사용함. `2시간=효과 0·완전보호 종료`가 아니며, 땀·물·수건·마찰은 효과가 더 일찍 달라질 가능성만 생성함.
- UVI `3 미만`도 5-2의 `2 SED` 장시간 참고맥락 또는 사용자 확인 자외선 민감 맥락이 있으면 선크림의 추가 보호 가능성을 재검토함. `2 SED`는 출시 전 검증용 C등급 참고값이지 필요선·안전시간이 아님.
- 식약처의 `내수성 약 1시간·지속내수성 약 2시간`은 입수·자연건조 반복 뒤 SPF가 사용 전 대비 `50% 이상` 유지되는 시험표시로 보존함. 개인의 물놀이 허용시간·완전보호시간·재도포 면제시간으로 바꾸지 않음.
- 식약처 기능성화장품 상태, SPF, PA, 내수성, 제형, 사용법, 사용기한/개봉후기간, 공식 회수/환불을 별도 제품필드로 저장하도록 제안함. UVI만으로 SPF·PA 등급을 배정하거나 온라인 광고의 워터프루프·저자극·미백·트러블케어를 제품사실로 저장하지 않음.
- 한국소비자원 2025년 38개 제품 조사에서 6개의 기능성 오인 가능 광고와 1개의 온라인/제품 성분표시 불일치가 확인된 실제 판매환경을 반영함. 광고문구보다 식약처 인정·정확한 라벨·공식 조사상태를 우선함.
- 별도 40개 제품 조사에서 2개 제품의 4-MBC가 국내 한도 `4%`보다 높은 `5%`로 검출돼 판매중단·재고폐기·환불이 발표된 최근 실제사례를 반영함. 제품명·용량·책임판매사·제조번호가 정확히 일치할 때만 공식 조치를 최우선 확정 안내하고 건강피해·환불완료는 확정하지 않음.
- 국내 15명 도포량 실험의 `2mg/㎠`, 한국인 얼굴면적 기반 `0.74~0.84g`, 해운대 1,255명의 스프레이/크림 하루 평균 `44.52/20.51g`을 교육·제형차이 근거로만 사용함. 개인 1회량·휴대용량·실제 도포량으로 복사하지 않음.
- 분사·분무형은 식약처의 얼굴 직접분사 회피·손에 덜어 바름 안내를 공식 카드로 표시함. 6개월 미만 영유아와 어린이 첫 사용도 식약처 공식 안내와 정확한 제품 사용법을 전달할 뿐 앱이 제품·성분·양을 자동 선정하지 않음.
- 직접체감은 `뻑뻑함·두껍고 무거움·촉촉함·산뜻함·손/얼굴 끈적함·번들거림·답답하게 덮인 느낌·백탁·화장 밀림·땀과 섞여 미끈거림·눈시림·따가움·가려움·붉어짐·오돌토돌함·꺼내기 번거로움·챙겼지만 쓰지 않음`으로 기록함. 직접기록은 확정하고 효과·원인·제품 관련성·다음 반응은 가능성형으로만 안내함.
- 식약처가 이상반응 발생 시 사용 중지와 전문의 상담을 안내한 사실은 출처와 함께 확정 전달함. 사용자의 반응기록은 확정하되 앱이 알레르기·일광화상·제품 원인·중증도를 진단하지 않음.
- `OFFICIAL_UV_SUNSCREEN_GUIDANCE_LINKED`, `SUNSCREEN_INITIAL_APPLICATION_POSSIBLE`, `SUNSCREEN_PREDEPARTURE_REMINDER_POSSIBLE`, `SUNSCREEN_CARRY_POSSIBLE`, `SUNSCREEN_REAPPLICATION_REVIEW_POSSIBLE`, `PROLONGED_LOW_UVI_SUNSCREEN_POSSIBLE`, `UV_SENSITIVE_CONTEXT_PROTECTION_POSSIBLE`, `SUNSCREEN_PRODUCT_STATUS_CONFIRMED`, `OFFICIAL_SUNSCREEN_RECALL_LINKED`, `SUNSCREEN_WATER_RESISTANCE_RELEVANT`, `SUNSCREEN_SPRAY_HANDLING_GUIDANCE_LINKED`, `SUNSCREEN_USE_COMFORT_BARRIER_POSSIBLE`, `USER_REPORTED_SUNSCREEN_REACTION`, `SUNSCREEN_DATA_INSUFFICIENT` 후보를 추가함.
- `SUNSCREEN_REQUIRED/NOT_NEEDED/APPLIED_ASSUMED/SUFFICIENT/FULL_PROTECTION/PROTECTION_REMAINING_MINUTES/DAMAGE_PREVENTED/SAFE_FOR_USER` 상태는 만들지 않음. 공식 기상청 단계명 `위험`과 식약처 사용중지·상담 안내는 원문 표시할 수 있지만 앱의 개인 위험·의무판정으로 바꾸지 않음.
- 현재 서버는 `UVI >=6 → UV_HIGH → SUNSCREEN_USEFUL → SUNSCREEN`으로 연결해 UVI 3~5, 일정·노출피부·제품·도포·땀/물/마찰·제품접근·회수정보를 반영하지 못함. `선크림이 필요한 날이에요`, `챙겨요·발라요·준비하세요` 명령/확정 템플릿은 공식 카드와 내부 가능성 카드로 분리해야 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-3은 사용자 미확정 권장안이며 확정 전에는 다음 6-4 `마스크 준비`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 6-3 국내 실제 수치·체감 추가 연구
- 사용자가 6-3 선크림 준비를 확정하기 전 국내 한국 기준의 실제 수치·체감 연구를 더 확인하도록 요청해, 해운대 현장조사·국내 골프 이용자 설문·수도권/강원 성인 설문·한국인 여성 사용인식·한국인 최소홍반량 연구를 추가 대조함.
- 해운대 하루 현장조사 `1,255명`에서 스프레이/크림 평균 사용횟수 `2.34/2.13회`, 하루 총사용량 `44.52/20.51g`이 관측됐고, 사용부위도 크림은 얼굴 `68.5%`·팔 `64.5%`·다리 `49.5%`·몸통 `24.3%`, 스프레이는 `37.6%·62.5%·63.9%·17.7%`로 달랐음. 하루 평균을 개인 목표횟수·1회량·적정량·휴대량으로 사용하지 않음.
- 국내 골프 이용자 `365명` 설문에서 하루 한 번 `47.7%`, 2~3시간마다 `15.3%`, 3~4시간마다 `23.8%`, 4~5시간마다 `13.2%`가 보고됐음. 다수행동을 올바른 행동으로 바꾸지 않고, 공식 `2시간마다` 안내를 실제로 이행했다고 추정하지 말아야 한다는 근거로만 사용함.
- 같은 골프 표본의 주 사용부위는 얼굴 `84.1%`, 목 `8.8%`, 팔·손 `7.1%`, 주 제형은 크림 `73.7%`, 스틱 `21.6%`, 스프레이 `3.3%`, 쿠션 `1.4%`였음. `주 사용부위`를 다른 부위의 미도포율로 해석하지 않고 얼굴·귀·목·팔·손·다리 기록을 별도로 확인하도록 함.
- 한국인 성인 여성 `340명` 연구에서 보통 `3~5시간` 간격, 야외활동 때 더 잦은 덧바름, 에어쿠션의 높은 덧바름 사용과 편리성-만족/재구매 관련성이 보고됐음. `3~5시간`을 새 재도포선으로 쓰지 않고 제형·제품 접근성·메이크업 위 사용·꺼내기 편의를 질문할 근거로 사용함.
- 2011년 수도권·강원 성인 `466명` 설문에서 얇게 도포 `47.4%`, 외출 때 매일 사용 `57.1%`, 외출 30분 전 사용 `48.3%`, 여성 응답자의 끈적임 문제 `33.1%`가 보고됐음. 오래된 편의표본이므로 현재 전국 비율·알림시점·체감등급·도포감소율로 사용하지 않고 `얇게 발랐음·끈적함·무거움` 직접기록 어휘의 근거로만 사용함.
- 2024년 서울의 한국인 `14명` 시험에서 시각적 최소홍반량은 평균 `300.14±84.16J/㎡`, 개인 `200~523J/㎡`였고 식약처 시험정의상 홍반은 조사 `16~24시간` 뒤 판독함. 뜨거움·따가움·붉어짐이 없다는 현재 느낌을 충분한 보호·안전시간으로, 느낌이 있다는 기록을 UVI·노출량으로 역산하지 않음.
- 추가 조사 뒤에도 첫 도포 도움 기본조건은 `유효한 공식 UVI 3 이상 + 실제/계획 야외구간 + 옷으로 가리지 않은 피부`로 유지함. `외출 약 15분 전·2시간마다`는 식약처·질병관리청 공식 사용안내로만 확정 표시하고 앱의 개인 첫 도포·휴대·덧바름·효과는 가능성형으로 유지함.
- `SUNSCREEN_BODY_AREA_RECORD_INCOMPLETE` 후보를 추가해 일부 부위 도포기록이 있어도 다른 노출부위를 바름/미도포로 추정하지 않도록 함. 직접 사용감 기록은 확정하되 `비슷한 상황에서 충분히 바르거나 덧바르기 어려울 수 있어요`처럼 다음 사용장벽만 가능성으로 안내함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-3은 계속 사용자 미확정 권장안이며 확정 전에는 6-4 `마스크 준비`로 이동하지 않음.

### 기준 채택 6-3 및 검토 6-4: 마스크 준비
- 사용자의 `확정 후 다음`에 따라 국내 실제 사용횟수·제형·부위·사용감·최소홍반량 연구로 보강한 6-3 선크림 준비를 최종 채택함. 공식 자외선·제품·사용·회수정보는 확정형, 앱의 첫 도포·휴대·덧바름·부위별 추가확인·사용장벽은 가능성형으로 분리한 기준을 유지함.
- 다음 6-4 마스크 준비를 5-8 채택 마스크 권고 기준, 에어코리아 고농도 행동요령, 식약처 2025·2026년 보건용 마스크 안내·기준규격, 한국소비자원 KF94 9종 비교시험, 국내 생활환경·밀착·운동·사용감·피부반응 연구와 대조해 미확정 권장안으로 작성함.
- 공식 PM10·PM2.5 예보·측정·경보·행동요령과 식약처의 보건용 마스크 허가·KF등급·사용기한·세탁/재사용 주의는 기관·물질·지역·대상시간·발표/측정/발령시각·제품식별·조회시각을 붙여 확정 안내하도록 함.
- 앱 내부의 마스크 준비 도움 가능성은 `관련 시간의 공식 나쁨/매우나쁨 또는 활성 경보 + 실제/계획 실외구간`이 함께 확인될 때만 생성함. 공식 행동요령은 확정 안내하고 `미리 확인·휴대·여분이 도움이 될 수 있어요` 같은 앱 판단은 가능성형으로만 표시함.
- `제품을 가지고 있음`, `보관위치`, `가방에 넣음`, `착용 시작/종료`, `얼굴 밀착느낌`, `여분 준비`, `제품상태`, `노출감소`, `질환예방`을 서로 다른 사실로 저장하도록 함. `maskEnabled`·알림노출/클릭을 제품 보유·휴대·착용으로 간주하지 않음.
- 미세먼지용 보건용 마스크는 현재 식약처 허가와 정확히 일치하는 KF80·KF94·KF99로 한정해 확인함. KF-AD·수술용·방한대·천/스포츠·제품불명은 같은 근거로 합치지 않고, KF 숫자를 개인 보호율·질환예방률로 사용하지 않음.
- 한국소비자원 KF94 9종 시험에서 같은 대형도 가로길이 최대 `42mm`, 세로길이 `17mm`, 끈 길이 `48mm` 차이가 확인됐음을 반영해 제품 등급과 형태·치수·개인 밀착을 분리함. 9개 결과를 모든 현재 제품·개인 밀착보장으로 확대하지 않음.
- 국내 마스크 사용경험 `433명` 조사에서 숨참 `25.5%`, 귀끈 통증 `22.8%`, 말하기 어려움 `22.2%`, 말할 때 움직임 `18.8%`가 보고됐고 안경 김서림·땀/습기·피부·화장 번짐 자유응답도 확인됨. 감염병 시기 자기보고이므로 미세먼지 상황 발생률·KF 선택선으로 쓰지 않고 직접체감 질문어휘로만 사용함.
- 국내 건강한 남성 `15명` 고강도 운동과 `20명` 근력운동 연구에서 활동 중 주관 불편·호흡곤란·습기·열감·호흡저항·조임이 높아진 결과를 활동강도·착용부담 가능성의 소표본 근거로 사용함. 일반 생활·여성·고령자·질환자 안전이나 마스크 해제시간으로 일반화하지 않음.
- 국내 병원 종사자 중심 `303명` 조사에서 가려움·건조/당김·따가움·붉어짐과 장시간 착용 관련성이 보고됐음을 피부·마찰·습기 질문 근거로만 사용함. 표본의 피부증상 비율을 일반 사용자의 발생확률·교체시간으로 사용하지 않음.
- 여분 준비는 고정 시간·장수로 만들지 않음. 분리 착용구간 또는 비·눈·땀·오염·구김 가능성이 있고 외부 새 제품 접근이 어렵다고 확인될 때만 도움이 될 가능성을 검토함. 식약처의 세탁·재사용 회피 안내는 확정 표시하되 잔존성능·교체시각을 계산하지 않음.
- 직접체감은 `들이쉴 때 뻑뻑함·숨이 답답함·활동할수록 버거움·안쪽이 후끈함·습기가 차 눅눅함·얼굴에 달라붙음·귀가 당김·콧등/볼 쓸림·가려움/따가움·말하기 불편·안경 김서림·화장 번짐`으로 기록함. 기록은 확정하고 원인·다음 반응·제품 적합성은 가능성형으로만 안내함.
- `MASK_PREPARATION_POSSIBLE`, `MASK_PRODUCT_CHECK_POSSIBLE`, `MASK_CARRY_POSSIBLE`, `MASK_SPARE_PREPARATION_POSSIBLE`, `MASK_POSSESSION_RECORDED`, `MASK_CARRY_RECORDED`, `MASK_WEARING_RECORDED`, `MASK_PRODUCT_STATE_RECHECK_POSSIBLE`, `MASK_FIT_RECHECK_POSSIBLE`, `MASK_COMFORT_BARRIER_POSSIBLE`, `MASK_ALTERNATIVE_FORM_REVIEW_POSSIBLE`, `MASK_OFFICIAL_STOP_GUIDANCE_RELEVANT`, `MASK_PREPARATION_DATA_INSUFFICIENT` 후보를 추가함.
- `MASK_REQUIRED/NOT_NEEDED`, `KF94/KF99_REQUIRED`, `MASK_CARRY/WORN_ASSUMED`, `MASK_FIT_CONFIRMED`, `MASK_PROTECTION_PERCENT`, `MASK_SAFE_FOR_USER`, `MASK_DISEASE_PREVENTED`, 고정 교체시간 상태는 만들지 않음.
- 현재 서버는 PM10 `81` 또는 PM2.5 `36` 이상과 `Bad/Very Bad`를 실외일정·제품 없이 `MASK_USEFUL→MASK`로 연결하고, 앱·브리핑은 `마스크 챙겨요·가벼운/잘 맞는/익숙한/여분 마스크·바깥 호흡이 편안해져요`를 확정적으로 표시함. 공식정보, 시간별 외출, 제품·접근성, 휴대/착용, 밀착·불편 상태로 분리한 뒤 연결하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-4는 사용자 미확정 권장안이며 확정 전에는 6-5 `물·수분 보충`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않음.

### 기준 채택 6-4 및 검토 6-5: 물·수분 보충

- 사용자가 `확정 후 다음`을 지시해 6-4 `마스크 준비`의 권장안을 내용 변경 없이 채택 상태로 전환함.
- 다음 6-5 `물·수분 보충`을 기상청 폭염 영향예보, 질병관리청 2025년 대상자별 온열질환 예방 매뉴얼과 2026년 예방수칙·2025년 확정 감시결과, 2025 한국인 영양소 섭취기준, 국민건강영양조사 기반 국내 수분섭취 연구, 국내 시설노인 수분섭취 장벽 연구, 2015~2024 국내 온열질환·체감온도 연구와 대조해 미확정 권장안으로 작성함.
- 2025년 온열질환자는 4,460명, 추정사망자는 29명으로 확정됐고 실외 79.2%, 실외작업장 32.1%, 논밭 12.2%, 길가 11.7%, 14~17시 집중, 65세 이상 환자 30%·추정사망자 58.6%를 확인함. 이 값은 실외·작업·고령·오후 준비의 우선순위를 뒷받침하되 개인확률·유일 시간선·실외 전용 기준으로 쓰지 않도록 함.
- 공식 폭염 영향예보·특보와 질병관리청 행동요령·응급조치는 `발표됐어요·발효 중이에요·안내했어요`로 확정 표시하고, 앱의 물 준비·휴대·접근·섭취시점·체감 관련 판단은 모두 `도움이 될 수 있어요·관련됐을 수 있어요·판단하기 어려울 수 있어요`로 제한함.
- 6-5의 진입점은 2-4의 채택 기준을 재사용함. 기상청 보건-일반인 영향예보 `관심` 이상 또는 활성 폭염특보를 우선하며, 공식정보가 없을 때만 2-4의 실제 최고기온·기상청 체감온도 지속 보조조건을 사용하도록 함. 관련 시간의 실제·계획 실외노출 또는 유효한 실내 열측정이 함께 있어야 개인 준비 가능성을 만들도록 함.
- 질병관리청은 갈증이 없어도 규칙적으로 물을 자주 마시도록 안내하지만 일반 사용자용 고정 mL·간격은 제시하지 않음을 확인함. 앱은 `하루 몇 L`, `몇 분마다 몇 mL`, 특정 병 용량·개수, 스포츠음료·전해질·소금 자동권고를 만들지 않도록 함.
- 2020 수분기준 검토의 2,167.3mL/일·62% 미달과 2008~2012 한국 성인의 2.4L/일은 음식·물·음료를 합한 집단 자료임을 확인함. 현재 기준은 2025 KDRI를 우선하되 국가 영양기준과 과거 국민 평균을 외출용 물병·개인 더위노출 목표량으로 전용하지 않도록 함.
- 국내 4개 시설노인 111명 연구에서 평균 1,035±359mL, 범위 210~2,050mL, 연구기준 미달 52%와 실금 걱정이라는 장벽이 확인됐지만 2006년 소규모 시설자료이므로 일반 섭취량 기준으로 쓰지 않음. 고령·돌봄 맥락의 화장실 걱정·이동·용기조작·보호자 도움·휴식 접근 질문에만 제한적으로 반영함.
- `물병이 있음`, `가방에 넣음`, `마셨음`, `마신 양`, `갈증 없음`, `입안이 덜 마름`, `충분히 보충됨`, `온열질환 예방`을 모두 별도 상태로 분리함. 알림 노출·스누즈, 구매, 병 무게감소·빈 병을 직접 섭취로 간주하지 않고 사용자가 확인한 시각·양·종류만 확정 기록하도록 함.
- 체감기록에 `입안이 바싹 마름`, `혀가 끈적하게 달라붙음`, `목이 타는 듯함`, `땀이 송골송골/줄줄 흐름`, `등이 축축함`, `옷이 몸에 들러붙음`, `힘이 쭉 빠짐`, `물이 미지근해 손이 안 감`, `배가 출렁거림`, `화장실 걱정`, `일을 멈추기 어려움` 등을 추가함. 직접느낌은 확정하고 더위·활동·수분과의 관계는 가능성형으로만 해석하도록 함.
- 입안 마름·갈증·땀·소변색·두통 하나로 탈수·전해질 이상·온열질환을 진단하지 않고, 갈증 없음도 충분함의 증거로 사용하지 않도록 함. 마신 뒤 편해졌다는 기록도 체감변화만 확정하고 `수분 회복·충분·안전`으로 바꾸지 않도록 함.
- 질병관리청의 신장·심장·혈압 관련 질환자 수분조절 안내를 반영해 사용자가 등록한 의료진 계획이 있으면 일반 추가섭취 문구를 억제하고 원문을 우선하도록 함. 질환명·나이·약만으로 제한량을 추정하거나 앱이 의료진 계획의 양·간격을 변경하지 않도록 함.
- 의식없음이 직접 확인되면 일반 물 알림보다 질병관리청의 `즉시 119 신고·음료 금지` 안내를 우선함. 심한 땀·두통·어지러움·경련·구토·극심한 피로·의식저하 기록은 확정하되 앱이 중증도·원인·회복을 진단하지 않도록 함.
- `OFFICIAL_HEAT_HYDRATION_GUIDANCE_LINKED`, `WATER_PREPARATION_POSSIBLE`, `WATER_CARRY_POSSIBLE`, `WATER_ACCESS_REVIEW_POSSIBLE`, `WATER_POSSESSION_RECORDED`, `WATER_CARRY_RECORDED`, `WATER_INTAKE_RECORDED`, `WATER_INTAKE_RECORD_UNCONFIRMED`, `REGULAR_DRINKING_REVIEW_POSSIBLE`, `THIRST_DRY_MOUTH_RECORDED`, `SWEAT_HEAT_FEEL_RECORDED`, `WATER_COMFORT_BARRIER_POSSIBLE`, `HYDRATION_ACCESS_BARRIER_POSSIBLE`, `PERSONAL_FLUID_PLAN_RELEVANT`, `OFFICIAL_HEAT_ILLNESS_GUIDANCE_RELEVANT`, `OFFICIAL_HEAT_EMERGENCY_GUIDANCE_LINKED`, `HYDRATION_DATA_INSUFFICIENT` 후보를 추가함.
- 현재 서버는 `APPARENT_TEMPERATURE_HIGH`만으로 `HYDRATION_IMPORTANT`를 만들고 `HUMIDITY_HIGH`면 점수를 더해 `WATER`로 변환함. 공식 폭염정보·질병관리청 출처, 실제 노출구간, 물 접근·물병·휴대·섭취기록·체감·장벽·개인 수분계획·응급우선순위가 없고 서버·앱에 `물을 가까이 두세요·조금씩 자주 마셔요·갈증 전부터 수분을 보충해요·작은 물병을 준비하세요` 같은 명령형이 남아 있음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-5는 사용자 미확정 권장안이며 확정 전에는 6-6 `겉옷 준비`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 `git diff --check`로 형식만 검증함.

### 기준 채택 6-5 및 검토 6-6: 겉옷 준비

- 사용자의 `확정 후 다음`에 따라 6-5 `물·수분 보충` 권장안을 최종 채택함. 공식 폭염정보·건강수칙·응급조치는 확정형, 앱의 물 준비·휴대·접근·섭취시점·체감·생활장벽 판단은 가능성형으로만 표시하는 원칙을 유지함.
- 다음 6-6 `겉옷 준비`를 기상청 2026년 한파 영향예보 개선, 질병관리청 2025-2026절기 한랭질환 감시결과·건강수칙, 한국 성인의 계절별 착의량·상의 겹수 실험, 국내 청소년 학교 안팎 온열감 연구, 한국 청년의 -5℃ 바람·의복단열 실험, 서울·경기 성인의 겨울 재킷 불편 연구와 대조해 미확정 권장안으로 작성함.
- 공식 한파 영향예보·특보, 기온·기상청 체감온도·바람 예보/관측과 질병관리청 행동요령은 `발표됐어요·발효 중이에요·예보됐어요·관측됐어요·안내했어요`로 확정 표시함. 앱의 준비·휴대·조절·방풍층·젖은 옷 접근·돌봄 확인은 모두 `도움이 될 수 있어요·관련됐을 수 있어요·판단하기 어려울 수 있어요`로 제한함.
- 2025-2026절기 한랭질환자 364명·사망 14명, 저체온증 79.7%, 65세 이상 57.4%, 80세 이상 32.4%, 실외 75.0%, 도로 23.6%, 주거지 주변 19.8%, 6~9시 20.9%를 최근 국내 우선순위 근거로 반영함. 개인 발생확률·외투 필요선·예방효과로 계산하지 않음.
- 질병관리청의 `얇은 옷 여러 겹, 장갑·목도리·모자·마스크`, `추운 날 젖은 옷·신발은 신속히 마른 것으로 교체`를 공식 안내로 확정 연결함. 겉옷과 말초 준비를 별도 상태로 두고 겉옷 착용만으로 손·귀 보호나 한랭질환 예방을 확정하지 않음.
- 한국인 20명의 좌식 인공기후실 실험에서 14℃의 상의 평균 겹수 3.2와 넓은 의복단열 범위가 확인됐지만 작은 정지기류·60분 실험임. 14℃를 `OUTER_LAYER_REVIEW_POSSIBLE`의 C등급 첫 사용자 보조선으로만 두고 보편 겉옷 필요선·고정 겹수·특정 제품으로 사용하지 않음.
- 개인 한 겹 경계 후보는 서로 다른 외출 2회 이상, 유사 활동·노출시간·젖음 맥락, ±2℃ 이내 구간에서 직접 체감·착용기록 3회 이상이라는 제품 검증용 최소조건으로 제안함. 이는 연구의 의학 절단값이 아니며 출시 전 표본·계절별 재학습·거짓 알림률을 검증하고 사용자 직접 선호선을 우선하도록 함.
- 한국 청년 남성 10명의 -5℃·풍속 0/2/4.5/7m/s 실험에서 풍속이 강해질수록 유효 단열 저하와 말초 냉각이 관찰됐지만, 이 숫자를 전국 공통 방풍외투 경계로 쓰지 않음. 기상청 체감온도에 이미 바람이 반영된 경우 풍속을 다시 가산하지 않고 바람스밈 직접기록이 반복될 때만 방풍층 검토 가능성을 만들도록 함.
- 하루 일교차는 단독 진입조건에서 제외함. 출발·귀가의 실제 실외구간이 개인 경계 또는 14℃ 보조선의 서로 다른 쪽에 있고 중간에 옷을 꺼낼 수 없을 가능성이 있을 때만 당일 휴대 도움 가능성을 검토하도록 함.
- 실내가 따뜻하다는 판단은 실측이나 사용자 직접기록이 있을 때만 하며, 실내외 전환·활동량이 큰 구간에는 두꺼운 옷 확정보다 탈착·통풍·보관의 도움 가능성을 안내함. 옷의 상품명·종류·라벨만으로 실제 clo·방풍·방수·보온효과를 확정하지 않음.
- 서울·경기 성인 480명 겨울 재킷 조사에서 착용불편 420명과 화장실·앉기·어깨·목·겨드랑이 문제가 확인됐음을 옷의 위치·휴대뿐 아니라 맞음새·동작·여밈·부피·보관 장벽도 확인할 근거로 사용함. 조사비율을 현재 전국 발생률이나 특정 제품 적합성으로 일반화하지 않음.
- 체감기록에 `찬 기운이 옷 사이로 스며듦`, `등골이 서늘함`, `목덜미가 시림`, `손끝·귀끝이 얼얼함`, `바람이 옷깃 안으로 파고듦`, `안쪽이 후끈함`, `등에 열이 갇힘`, `안감이 축축하게 달라붙음`, `어깨가 묵직함`, `팔을 올리기 어려움`, `벗어 들기 번거로움`, `가방에 안 들어감`, `화장실에서 걸리적거림` 등을 추가함. 기록은 확정하고 원인·옷 충분성·다음 반응은 가능성형으로만 해석함.
- `OUTER_LAYER_REVIEW_POSSIBLE`, `OUTERWEAR_PREPARATION_POSSIBLE`, `OUTERWEAR_CARRY_POSSIBLE`, `OUTERWEAR_ACCESS_REVIEW_POSSIBLE`, 보유/휴대/착용/탈의 직접기록, `PERSONAL_COLD_LAYER_RESPONSE_POSSIBLE`, `WIND_PENETRATION_RESPONSE_POSSIBLE`, 젖음/마른 옷 공식안내, 실내외 조절, 동작·열습기 장벽, 말초 보호, 돌봄 확인, `OUTERWEAR_DATA_INSUFFICIENT` 후보를 추가함.
- `OUTERWEAR_REQUIRED/NOT_NEEDED`, `PADDED_COAT_REQUIRED`, `JACKET_WARM_ENOUGH`, `WINDPROOF/WATERPROOF_CONFIRMED`, 고정 겹수, `COLD_ILLNESS_PREVENTED`, `SAFE_WITH_OUTERWEAR` 상태는 만들지 않음.
- 현재 서버는 기온 12℃·체감온도 10℃·일교차 8℃·기온-체감 차 4℃·풍속 6m/s 고정값을 `TEMPERATURE_LOW/COLD_STRESS_RISK/STRONG_WIND → OUTERWEAR_USEFUL`로 연결함. 공식 한파정보, 외출구간·활동·실내외 전환, 옷의 보유·접근·휴대·착용·젖음, 개인 체감·생활장벽이 없고 체감온도와 바람을 중복 가중할 수 있으며 템플릿에 `유용해요·좋아요·챙겨요`가 남아 있음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-6은 사용자 미확정 권장안이며 확정 전에는 다음 6-7 `빨래 가능 여부`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않으며 형식검증 후 마무리함.

### 기준 채택 6-6 및 검토 6-7: 빨래 가능 여부

- 사용자의 `확정 후 다음`에 따라 6-6 `겉옷 준비` 권장안을 최종 채택함. 공식 한파·기상·건강수칙은 확정형, 앱의 겉옷 준비·휴대·조절·방풍·젖음·체감·돌봄 판단은 가능성형으로만 표시하고 14℃를 첫 사용자의 한 겹 검토 보조선으로만 사용하는 원칙을 유지함.
- 다음 6-7 `빨래 가능 여부`를 기상청 현재 생활기상정보·단기예보 API, KS K 0021 섬유제품 취급표시, 한국소비자원의 최근 세탁분쟁·소형건조기·일체형 세탁건조기 시험, 국내 의류건조 열·물질전달 연구, 한국 공동주택 실내 빨래 수증기 실측, 국내 세탁 냄새경험 조사와 대조해 미확정 권장안으로 작성함.
- 6-7은 세탁기 작동 하나가 아니라 사용자가 정한 마감시각까지 `세탁→꺼내기→널기/기계건조→마름확인→회수`를 이어갈 여건의 가능성으로 정의함. 실외·실내 방식 비교는 6-8, 이미 널어둔 빨래 회수시각은 6-9로 분리함.
- 현재 확인한 기상청 공식 생활기상정보 공개목록에서는 빨래 완료를 판정하는 공식 지수를 찾지 못함. 강수형태·확률·강수량·기온·상대습도·풍속·특보는 각각 `발표됐어요·예보됐어요·관측됐어요·발효 중이에요`로 확정 표시하고 앱의 `시작·완료·지연·방식전환`은 가능성형으로만 표시함.
- 현행 서버의 `강수확률 <20%·상대습도 ≤75%·풍속 1~6m/s·3슬롯`은 국내 보편 건조완료선이 아니므로 채택하지 않음. `PTY·PCP·POP`, 실황·레이더·초단기/단기예보·특보를 분리하고 강수확률 원값과 사용자 직접 선호를 보존하도록 함.
- 상대습도는 기온에 따라 의미가 달라 기온과 함께 계산한 수증기압차/VPD를 같은 장소·방법의 후보시간 상대비교에만 사용함. 고정 VPD를 마름·냄새·곰팡이 경계로 만들지 않고, 구름상태를 일사량으로 보거나 `맑음=잘 마름·흐림=안 마름`으로 바꾸지 않음.
- 바람은 표면 수분교환에 도움을 줄 수 있지만 빨래 겹침·집게 이탈·낙하 가능성도 늘릴 수 있으므로 4-1의 공식 풍속단계를 사실로 표시하고 고정·차폐·최대순간풍속을 확인함. 현행 1~6m/s를 유리구간으로 사용하지 않음.
- 국가 취급표시 KS K 0021과 정확한 제품 라벨을 날씨보다 우선함. 물세탁·탈수·회전식건조·자연건조·뉘어건조를 소재명만으로 추정하지 않으며 최근 한국소비자원 세탁분쟁 3,875건의 제조판매사 책임 31.9%·세탁사업자 과실 25.2%, 세탁과실 중 방법부적합 50.8%를 실제 손상환경의 근거로 반영하되 개인 손상확률로 사용하지 않음.
- 한국소비자원 소형 의류건조기 8종 시험에서 표준코스 시간 최대 1시간 23분 차이와 건조성능 차이가, 일체형 세탁건조기 2종 시험에서 원스톱 약 2시간 30~40분이 확인됨. 기기 존재를 완료로 보지 않고 정확한 모델·코스·부하·표시시간을 사실로 저장하되 실제 완료·마름은 가능성으로 남김.
- 국내 건조기 연구에서 높은 온도·기류, 낮은 공기수분이 건조를 도왔지만 섬유종류·부하무게·탈수 뒤 함수량에 따라 결과가 달랐음. 기계 내부 40/60/80℃·절대습도·CMM 값을 실외 기온·습도·풍속 임계값으로 옮기지 않고 세탁물 종류·양·두께·탈수상태·배치를 필수 입력으로 추가함.
- 2015년 송도 공동주택 한 곳의 약 3kg 빨래 2회 실내건조에서 평균 약 1,643.6g/회·173.6g/h 수분방출이 측정됨. 실내 대안도 공간습도·환기·수분배출 확인이 필요할 수 있다는 보조근거로만 사용하고 보편 3kg 건조시간·실내 영향으로 복사하지 않음.
- 개인 완료가능성은 같은 방식·공간·비슷한 부하·탈수·배치와 자연건조 날씨가 비교 가능한 직접 완료기록 5회 이상·사흘 이상 있을 때만 후보로 만듦. 이는 연구 절단값이 아니라 우연한 한두 번을 예측으로 굳히지 않기 위한 제품 최소조건이며 출시 전 실제 오차를 검증함. 1~4회는 관찰범위만 보여주고 정확한 완료시각·확률을 만들지 않음.
- 체감기록에 `물기가 뚝뚝·축 처지고 묵직함·차고 눅눅함·겉만 보송함·옷끼리 닿은 면이 축축함·허리밴드/주머니/후드/솔기/이불 가운데가 덜 마름·젖은 수건 냄새·퀴퀴함·시큼한 쉰내·빨랫대가 빽빽함·옷끼리 붙음·바람에 펄럭임·널거나 회수할 시간이 없음` 등을 추가함. 직접기록은 확정하고 함수량·미생물·곰팡이·원인·재세탁 필요는 확정하지 않음.
- `OFFICIAL_LAUNDRY_WEATHER_FACTS_SHOWN`, 취급표시·기기표시시간과 과정 직접기록, `LAUNDRY_START_CONDITIONS_POSSIBLE`, `LAUNDRY_WEATHER_SUPPORT_POSSIBLE`, `LAUNDRY_COMPLETION_BEFORE_DEADLINE_POSSIBLE`, `LAUNDRY_DRYING_DELAY_POSSIBLE`, `LAUNDRY_METHOD_SWITCH_POSSIBLE`, `LAUNDRY_METHOD_REVIEW_POSSIBLE`, 부위별 마름·냄새 기록, 처리공백 가능성, `LAUNDRY_DATA_INSUFFICIENT` 후보를 추가함.
- `LAUNDRY_GOOD/BAD`, `LAUNDRY_POSSIBLE_CONFIRMED/IMPOSSIBLE`, `WILL_DRY_TODAY`, 정확한 마름시간, 실외건조 안전, 기기 있음=완료, 전체건조 추정, 재세탁 필요·세균·곰팡이·냄새발생 확정 상태는 만들지 않음.
- 현재 코드의 `LAUNDRY_DRYING_GOOD→LAUNDRY_GOOD`와 `빨래는 오전에 끝내요·건조하기 무난한 날이에요·오전에 널면 좋아요` 템플릿은 공식정보·취급표시·세탁물·기기·일정·방법·직접기록 없이 확정/명령형을 만들 수 있음을 기록함. 임계값을 유지하고 문구만 부드럽게 바꾸지 않도록 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-7은 사용자 미확정 권장안이며 확정 전에는 다음 6-8 `실외·실내 건조 선택`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-7 및 검토 6-8: 실외·실내 건조 선택

- 사용자의 `확정 후 다음`에 따라 6-7 `빨래 가능 여부` 권장안을 최종 채택함. 공식 기상·취급표시는 확정형, 앱의 시작·완료·지연·방식전환은 가능성형으로만 표시하고 `강수확률 <20%·상대습도 ≤75%·풍속 1~6m/s·3슬롯`을 보편 빨래 가능선으로 사용하지 않는 원칙을 유지함.
- 다음 6-8 `실외·실내 건조 선택`을 기상청 단기예보·꽃가루농도위험지수, 에어코리아·환경부 공동주택 환기안내, 질병관리청 꽃가루 관리, KS K 0021, 국토교통부 결로 저감 안내, 국내 섬유 입자오염 실험, 공동주택 수증기·결로·장기 온습도 연구, 한국소비자원 건조기 시험과 대조해 미확정 권장안으로 작성함.
- 건조장소는 `완전 노출 실외`, `외기에 열린 발코니`, `닫힌 발코니`, `일반 실내`, `국소배기 가능한 욕실`, `회전식 건조기`, `공용 건조시설`, `중간 전환`으로 구분함. `베란다`라는 이름만으로 실외/실내를 정하지 않고 외창·강수유입·차폐·실내 온습도·표면·배기/제습 상태를 확인하도록 함.
- 앱은 `실외 재젖음`, `바람에 의한 펄럭임·겹침·집게이탈·낙하`, `입자/꽃가루 접촉`, `실내 수분축적·결로·공기교환`, `취급표시·설비·공간·접근성`을 별도 축으로 표시함. 단일 실외/실내 점수나 `최선·안전·필수` 상태를 만들지 않음.
- 공식 강수·풍속·특보, PM10·PM2.5 측정/예보/경보, 꽃가루 공식 단계와 취급표시는 `발표됐어요·예보됐어요·관측/측정됐어요·발령/발효 중이에요·표시됐어요`로 확정 안내함. 앱의 재젖음·비산·입자접촉·꽃가루접촉·수분축적·결로맥락·방법선택은 모두 `~수 있어요·가능성이 있어요`로 제한함.
- 국내 2021년 직물오염 연구는 규산염 입자를 면·나일론 표면에 통제 부착해 정량 비교법을 개발했지만 실제 야외 젖은 빨래 연구가 아님. `PM 나쁨=빨래 오염·재세탁 필요`를 만들지 않고 직물 표면 접촉 가능성의 B등급 보조근거로만 사용함.
- 기상청 꽃가루 단계와 질병관리청의 외출 뒤 옷 털기 안내를 반영하되 빨래의 부착량·수종·증상확률은 만들지 않음. 공식 높음/매우높음과 사용자 확인 감작수종이 일치하면 접촉부담 가능성의 우선순위만 높이고 감작 미확인이면 공식정보와 접촉 가능성만 표시함.
- 2015년 송도 한 주택의 약 3kg 빨래 2회 실내건조에서 평균 1,643.6g/회·173.6g/h 수분방출이 측정됐음을 반영함. 특정 집·적은 반복이므로 모든 가정의 가습량·건조시간·RH 경계로 복사하지 않음.
- 국내 저소득 공공임대주택 연구의 평균 수분초과량 4.69g/㎥와 기계환기 부족·개방형 구조·실내건조 관련성, 2019년 한국 공동주택 연구의 건조장소 거실 58%·발코니 26%·침실 18%·전기건조기 10%·일일 환기 1회 70%를 반영함. 분포·평균을 권장비율이나 실내건조 허용/금지선으로 사용하지 않음.
- 서울 8개 공동주택 1년 IoT 연구가 한국의 건강기반 실내 온·RH 경계 미확립을 지적한 점을 반영해 `RH 60/70/75%=실내건조 금지`, `50%=결로 없음`을 만들지 않음. 같은 방의 건조 전후 온습도·절대습도 추세와 물방울·찬 표면을 사용하고 실외 RH를 실내에 복사하지 않음.
- 창문·벽 물방울은 직접기록으로 확정하고 국토교통부의 물방울 제거·건조·제습/주기적 환기 안내를 공식문구로 연결함. 빨래 단독원인·건물하자·곰팡이 발생은 확정하지 않으며 이슬점과 해당 표면온도가 모두 품질 있게 측정될 때만 결로 가능 맥락을 보조표시함.
- 5-12의 외기유입부담·실내 공기교환 필요·방법 적합성을 재사용함. 외기필터 기계환기·욕실 외부배기·제습기·재순환 공기청정기를 분리하고 공기청정기를 수분·CO2 배출이나 제습으로 표시하지 않음. 제습기·에어컨 제습도 정확한 제품·사용범위·물통/배수·가동상태 없이 같은 효과로 간주하지 않음.
- 정확한 라벨의 그늘/줄/뉘어/회전식건조 허용·금지를 날씨보다 우선함. 직사광선을 살균·청정·모든 제품에 유리한 요소로 보지 않고 건조기도 정확한 모델·코스·용량·표시시간을 확인해 완료·손상없음을 확정하지 않음.
- 개인 방법비교는 방법별 비교 가능한 기록 5회 이상·사흘 이상, 비슷한 부하·탈수·배치·완료마감과 날씨/실내상태를 요구하는 제품 최소조건으로 제안함. 이는 연구 절단값이 아니며 실외 5회·실내 1회 같은 불균형 기록으로 승자를 만들지 않음.
- 체감기록에 실외 `살랑임·세게 펄럭임·한쪽으로 몰림·집게 빠짐·다시 축축·먼지가 내려앉은 듯 까슬함·노란 가루·도로 냄새`, 실내 `방이 눅눅·공기가 묵직하고 답답·창문 물방울·벽 모서리 축축·옷 사이 습기가 갇힌 듯함·제습기 물통·후끈함·소음·통로/수면공간 방해`, 옷 상태 `겉만 보송·속은 눅눅·바삭/뻣뻣·정전기·줄어든 듯함`을 추가함. 직접기록은 확정하고 원인·입자종류·곰팡이·손상은 가능성으로 남김.
- `OUTDOOR_DRYING_OPTION_POSSIBLE`, 실외 재젖음/바람취급/입자/꽃가루/영하 반응 가능성, `INDOOR_DRYING_OPTION_POSSIBLE`, 실내 수분축적/결로/공기교환, 필터형 기계환기·제습·회전식건조·중간전환 가능성, 상충검토, 공간/이동/체감 직접기록, 개인 방법반응, 정보부족 상태를 제안함.
- `INDOOR_DRYING_PREFERRED/OUTDOOR_DRYING_PREFERRED`, 실내/실외 안전, 빨래 청정확정, 꽃가루 없음, 결로 없음, 곰팡이 발생, 제습기/건조기 필수, 최적방법·합산점수는 만들지 않음.
- 현재 서버는 외부의 비 신호와 RH `≥75%`가 3슬롯 이어지면 `INDOOR_DRYING_PREFERRED`를 만들고 `오늘은 실내 건조가 안전해요·야외 건조가 어려운 날이에요`를 표시함. 실내 센서·수분배출·결로·공간·대기질·꽃가루·취급표시·설비·사용자 기록이 없어 기존 상태 생성을 중단하고 다축 가능성 상태로 분리하도록 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-8은 사용자 미확정 권장안이며 확정 전에는 다음 6-9 `빨래 회수 시점`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-8 및 검토 6-9: 빨래 회수 시점

- 사용자의 `확정 후 다음`에 따라 6-8 `실외·실내 건조 선택` 권장안을 최종 채택함. 공식 기상·대기질·꽃가루·취급표시는 확정형, 앱의 재젖음·비산·접촉·실내 수분축적·결로·방법선택은 가능성형으로만 표시하고 단일 선호·안전 점수를 만들지 않는 원칙을 유지함.
- 다음 6-9 `빨래 회수 시점`을 기상청 10분 AWS 관측·레이더 강수예측·단기예보 API·강풍/낙뢰 국민행동요령·이슬 관측교재, KS K ISO 139, 국내 공동주택 빨래 수분방출 실측, 2022년 국내 스마트 건조 시제품 연구, 2014~2024년 국내 강풍 출동자료 연구와 대조해 미확정 권장안으로 작성함.
- 기상청이 발표·관측한 강수·풍속·특보와 공식 행동요령은 출처·지점·대상구간·발표/관측/발효시각을 붙여 `예보됐어요·관측됐어요·발표됐어요·발효 중이에요·안내했어요`로 확정 표시함. 앱의 마름확인·이동·회수·고정·야간 재확인은 모두 `~수 있어요·도움이 될 수 있어요·판단하기 어려울 수 있어요`로 제한함.
- `CHECK_DRYNESS`, `MOVE_TO_CONTINUE_DRYING`, `COLLECT_FOR_STORAGE`를 분리함. 비·바람 때문에 덜 마른 빨래를 실내로 옮기는 것과 관련부위가 마른 뒤 보관을 위해 걷는 것을 같은 `회수`로 처리하지 않음.
- 세탁 시작·종료·널기 알림이나 알림 열기만으로 현재도 빨래가 밖에 있다고 확정하지 않음. 사용자의 장소·시각 포함 직접확인 또는 품질이 확인된 현장센서가 있어야 현재 노출을 활성화하고, 회수기록이 오래 없으면 `아직 밖에 있나요?`만 질문하도록 함.
- 강수 근거는 같은 위치·시간에서 `직접 빗방울/현장센서 → 품질정상 인근 AWS → 현재~2시간 레이더 강수예측 → 초단기실황/예보 → 단기예보 PTY·PCP·POP` 순으로 사용함. 관측지점의 비와 센서판 젖음을 사용자 빨래의 실제 젖음으로 확정하지 않으며 10분 영상·한 시간 예보보다 세밀한 시작시각을 만들지 않음.
- 2025년 기상청이 정확도 향상을 위해 레이더 강수예측영상 범위를 기존 6시간에서 2시간으로 조정한 사실을 반영해 2시간 밖으로 영상을 외삽하지 않음. POP만 있을 때 6-1 우산의 40%를 빨래 회수선으로 복사하지 않고 확률 원값과 사용자 선호를 보존함.
- 회수 시작 후보는 `가장 이른 날씨 영향구간 시작 - 개인 보수 회수소요시간 - 확인된 접근준비시간`으로 계산함. 개인 직접설정은 사실로 사용하고 자동 개인화는 같은 장소·비슷한 양·같은 접근자의 직접기록 5회 이상·사흘 이상일 때만 후보화하며, 이는 연구 절단값이 아니라 제품 최소조건임.
- 계산값은 `안전 마감시각`, `반드시 걷을 시각`, `그때까지 비가 오지 않음`이 아니라 `옮기기 시작해볼 시점`으로만 표시함. 현존·소요시간·접근·날씨자료 해상도 중 핵심값이 없으면 임의 `30분 전`을 넣지 않고 정확한 시각을 만들지 않음.
- 일몰은 천문사실일 뿐 빨래 표면이 젖는 시각이 아니므로 `일몰 전`, `오후 6시`, `RH 75%`를 보편 회수선으로 사용하지 않음. 직접 표면 젖음·물방울·표면온도와 이슬점·비교 가능한 개인 반복기록을 우선하고 기온·RH만으로 이슬·재젖음을 확정하지 않음.
- 강풍특보와 공식 풍속단계는 확정 표시하되 평균 9m/s·순간 10m/s의 내부 준비후보만으로 낙하·분실·회수필요를 확정하지 않음. 강풍·낙뢰·호우·태풍이 이미 발생해 옥상·마당 접근부담이 커질 수 있으면 빨래 회수 푸시를 억제하고 공식 야외작업 자제·대피 안내를 우선하도록 함.
- 겉면뿐 아니라 허리밴드·주머니·후드·솔기·접힌 안쪽의 촉감과 비교무게를 확인하도록 함. `겉은 보송하지만 안쪽은 차고 눅눅함`이면 계속건조 이동 가능성, 사용자가 관련부위를 모두 보송하다고 확인했으면 보관 회수 가능성을 만들되 위생·무균·정확한 함수량·재세탁 필요는 확정하지 않음.
- 체감·장벽 기록에 `보송함·차고 눅눅함·축축한 기운·살짝 끈적하게 달라붙음·다시 묵직함·빗방울 자국·집게/난간 물방울·세게 펄럭임·빨랫대 덜컹거림·집게가 많아 오래 걸림·젖은 계단·옥상문·여러 번 운반·아이/반려동물 돌봄·알림이 늦음/너무 이름` 등을 추가함. 직접기록은 확정하고 원인·다음 소요시간·피해예방은 가능성으로만 해석함.
- 날씨 영향 이벤트와 빨래 묶음별 노출·회수 이벤트를 버전 관리하고 예보가 앞당겨짐·늦어짐·사라짐·관측으로 전환됨을 보존하도록 함. `모두 걷음·실내로 옮김·이번에는 두기` 직접입력은 해당 범위 알림만 종료하고 알림 열기·스누즈를 회수 시작/완료로 간주하지 않음.
- `LAUNDRY_OUTDOOR_PRESENCE_RECORDED`, 현존 재확인·회수시점 검토·강수 전 이동·개인 회수시작·현재 강수확인·바람 고정/이동·공식 안전안내 우선·원격/실내제어·야간 습윤 재확인·마름확인·계속건조 이동·보관 회수·직접 시작/완료/이동/재젖음 기록·개인 소요시간·알림 갱신/억제·정보부족 상태를 제안함.
- `LAUNDRY_PICKUP_DUE/REQUIRED`, `LAST_SAFE_PICKUP_TIME`, `NO_RAIN_BEFORE_DEADLINE`, 날씨만으로 마름확정, 일몰 이슬확정, RH 75% 회수, 재세탁 필요, 야외회수 안전, 자동 빨랫대 성공 추정 상태는 만들지 않음.
- 현재 서버에는 `LifestyleInsightType.LAUNDRY_PICKUP_DUE`와 명령형 템플릿만 있고 실제 생성규칙·테스트·추천엔진 매핑은 확인되지 않음. `timeSeriesLifestyleBuilder.ts`의 고정 `위험시각-30분`은 창문 닫기용으로만 쓰이며 빨래 기준으로 복사할 근거가 없음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-9는 사용자 미확정 권장안이며 확정 전에는 다음 6-10 `우산 건조 필요성과 알림 시점`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-9 및 검토 6-10: 우산 건조 필요성과 알림 시점

- 사용자의 `확정 후 다음`에 따라 6-9 `빨래 회수 시점` 권장안을 최종 채택함. 공식 강수·풍속·특보·행동요령은 확정형, 앱의 마름확인·이동·회수·고정·야간 재확인은 가능성형으로만 표시하고 `비 30분 전·일몰 전·RH 75%`를 보편 회수선으로 사용하지 않는 원칙을 유지함.
- 다음 6-10 `우산 건조 필요성과 알림 시점`을 기상청 10분 실황·AWS·레이더 강수예측, 국가기술표준원 우산·양산 안전기준, 한국소비자원 2026년 우양산 12종 시험, 2020년 국내 자동 제수 시스템 연구, 2023년 국내 스마트 우산꽂이 연구, 서울특별시학교안전공제회 바닥 물기 예방안내와 대조해 미확정 권장안으로 작성함.
- 공식 강수 예보·관측·레이더·실황은 출처·지점/격자·발표/관측시각·유효구간을 붙여 `예보됐어요·관측됐어요·제공됐어요`로 확정 표시함. 앱의 우산 물기·말리기·재확인·보관 판단은 모두 `~수 있어요·도움이 될 수 있어요·판단하기 어려울 수 있어요`로 제한함.
- 6-1의 `우산 추천`, `가져감`, `실제 펼쳐 사용`, `물기 확인`, `임시 물기 처리`, `말리기 시작`, `확인한 부위가 마름`, `접어 보관`을 모두 별도 상태로 분리함. 추천 노출·알림 열기·비 예보만으로 우산 사용이나 젖음을 확정하지 않음.
- 건조행동은 `CHECK_UMBRELLA_WETNESS`, `TEMPORARY_DRAIN_OR_WIPE`, `AIR_EXPOSE_FOR_DRYING`, `FOLD_AND_STORE_AFTER_CHECK`로 나눔. 물방울을 임시로 처리한 상태를 전체 건조나 보관완료로 보지 않음.
- 알림의 핵심 진입조건을 `실제 사용 또는 품질이 확인된 직접 물기자료 + 우산 현존 + 사용자 가용 + 말릴 수 있는 공간 + 수신동의`로 정함. 사용만 확인되고 물기 미확인이면 `말리세요`가 아니라 `접힘 사이 물기를 살펴볼 수 있어요`만 한 번 제시함.
- 국내 공식·연구자료에서 모든 우산에 적용할 `비 종료 후 몇 분`, `실내 RH 몇 %`, `몇 시간 뒤 완전건조` 기준을 확인하지 못함. 알림은 비 종료 뒤 고정 30분/1시간이 아니라 사용자가 젖은 우산과 함께 집·사무실 등 말릴 수 있는 장소에 도착한 첫 적절한 맥락을 우선하도록 함.
- 기상청 실황의 `PTY 없음·RN1 0`, AWS 강수없음, 레이더 강수영역 소멸은 해당 지점·격자·시각의 공식자료로만 표시함. 이를 `비가 모두 그쳤어요`, `이제 다시 안 와요`, `우산이 마르기 시작했어요`로 확대하지 않음.
- `다음 비까지 시간이 있어요`는 건조 필요성의 근거에서 제외함. 다음 강수예보는 건조 중인 같은 우산을 실제 외출에서 다시 사용할 가능성이 있을 때만 `그전에 물기를 확인하면 도움이 될 수 있어요`라는 재사용 맥락으로 제한함.
- 국가기술표준원 2024년 우산·양산 안전기준과 정확한 제품 표시·제조자 안내를 우선함. 완전/반쯤 펼침, 거꾸로 세움, 걸기, 송풍·열풍·헤어드라이어 사용을 제품과 공간 확인 없이 보편 명령으로 만들지 않음.
- 한국소비자원 2026년 우양산 12종에서 내수성 기준 적합·습윤저항성 5급이 확인됐지만 시험대상은 특정 신제품이고 6종의 필수표시 누락/소재표시 부정확이 확인됐음. 높은 발수성을 `사용 뒤 물기 없음`으로 바꾸거나 오래된 우산·비닐우산·장우산 전체에 일반화하지 않음.
- 2020년 자동 제수 연구가 압력센서·에어컴프레서와 우산 재질별 건조율 시험을 사용한 점을 직접 무게·재질·처리상태를 분리할 근거로 사용함. 특정 장치의 건조율을 자연건조 완료시간이나 가정용 자동가열 승인으로 전용하지 않음.
- 2023년 스마트 우산꽂이 연구는 로드셀·물받이 수위센서·열풍을 사용했지만 장우산만 구현했고 작은/3단 우산은 추가연구가 필요하다고 밝힘. 우산 투입을 젖음으로, 장치 OFF를 일반 우산 완전건조로, 시제품 존재를 제품 안전검증으로 확대하지 않음.
- 후속 확인은 사용자 직접설정 또는 같은 우산·비슷한 펼침상태·같은 공간에서 `건조시작→부위별 마름확인` 직접기록 5회 이상·사흘 이상일 때 관찰범위로만 제안함. 이는 연구 절단값이 아니라 한두 번을 고정 알림으로 굳히지 않기 위한 제품 최소조건임.
- 확인부위를 천 바깥/안쪽·접힌 골·우산끈·끝부분·살대/중봉 주변·우산커버 안쪽으로 나눔. `물방울이 송골송골·끝에서 똑똑·접힌 골이 축축·우산끈이 눅눅·천끼리 차갑고 축축하게 달라붙음·커버 안쪽이 미끈함`을 직접 상태어휘로 추가함.
- 공간·생활장벽에 `우산꽂이 바닥 물 고임·현관매트 축축·통로 좁아짐·살대 끝 방향·아이/반려동물 접근·걸 곳 없음·물받이 비우기 번거로움`을 추가함. 통로·계단·공용공간에서는 넓게 펼치기보다 제품·공간규칙과 물받이/흡수매트/지정공간을 다시 살필 가능성을 제안함.
- `비 냄새·퀴퀴한 냄새·붉은 얼룩·버튼 뻑뻑함` 직접기록은 확정하되 앱이 곰팡이·세균·녹·고장·유일한 원인을 진단하지 않도록 함. 무게감소·물받이 수위·센서판 건조 하나로 숨은 접힘까지 완전건조를 확정하지 않음.
- `OFFICIAL_UMBRELLA_PRECIPITATION_FACT_SHOWN`, 우산 휴대/사용/미사용/물기 직접기록, 물기 재확인·임시 물처리·건조공간 검토·공기노출 건조·후속확인·재사용 전 확인·마른 부위/건조시작/보관 직접기록, 제품안내 연결, 알림 억제·정보부족 상태를 제안함.
- `UMBRELLA_DRYING_REQUIRED`, 예보로 젖음 추정, 모든 비 종료, 비 종료 30분 뒤, RH 75% 건조, 날씨로 완전건조, 안전보관, 곰팡이/세균 위험확정, 부식예고, 냄새예방, 자동건조 성공추정 상태는 만들지 않음. 기존 `UMBRELLA_DRYING_REMINDER`는 가능성 상태군으로 교체하도록 제안함.
- 현재 서버에는 `LifestyleInsightType.UMBRELLA_DRYING_REMINDER`와 `비가 모두 그쳤어요 / 젖은 우산을 펼쳐 말리세요`, `다음 비까지 시간이 있어요 / 우산을 말려두면 좋아요` 템플릿만 있고 실제 생성규칙·테스트·추천엔진 매핑·Flutter 생활메시지 타입은 확인되지 않음. `umbrellaEnabled`도 추천 노출만 저장해 건조대상을 알 수 없음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-10은 사용자 미확정 권장안이며 확정 전에는 다음 6-11 `환기 가능 여부`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-10 및 검토 6-11: 환기 가능 여부

- 사용자의 `확정 후 다음`에 따라 6-10 `우산 건조 필요성과 알림 시점` 권장안을 최종 채택함. 공식 강수정보와 사용자 직접기록은 확정형, 앱의 물기확인·공기노출 건조·재확인·보관 판단은 가능성형으로만 표시하고 비 종료 뒤 고정시간·RH 75%·다음 비까지의 시간을 건조필요선으로 사용하지 않는 원칙을 유지함.
- 다음 6-11 `환기 가능 여부`를 기존 채택 5-12 `환기 가능 대기질`, 5-13 `꽃가루·알레르기 위험`, 환경부 2024 공동주택 실내공기질 관리요령, 국가미세먼지정보센터 대응요령, 질병관리청 생활 속 연소가스, 기상청 꽃가루농도위험지수, 국내 공동주택·아파트 조리·도시학교·시간대 PM 연구와 현재 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 공식 평시/고농도/조리 환기요령, PM10·PM2.5·오존의 예보·측정·경보, 꽃가루농도위험지수와 재난·사고 창문/환기 안내는 기관·대상·지역·발표/관측시각·유효시간을 붙여 확정형으로 표시함. 조리·청소·샤워·빨래·연소·냄새·재실과 실제 방법·시작·종료·전후 느낌의 사용자 직접기록도 확정형으로 저장함.
- 생활결과를 `환기 가능/불가능` 한 단어가 아니라 `공식 외기정보`, `실내 공기교환을 살펴볼 맥락`, `실제 사용할 수 있는 방법`, `비·바람·온습도·방범·소음·접근성 제약` 네 층으로 분리함. 앱은 창문·맞통풍·후드·필터형 외기환기·재순환 공기청정기의 역할별 도움·유입·불편 가능성만 제시함.
- 환경부·국가미세먼지정보센터의 `30분·10분 이내·10~21시`와 질병관리청의 `조리 전부터 조리 뒤 30분까지`는 대상상황을 붙인 공식 안내로만 표시함. 이를 앱의 일반 안전시간·최소/완료시간·고정 최적시간으로 사용하지 않음.
- 국내 2014년 공동주택 연구는 자연환기와 필터형 기계환기의 입자유입 차이를, 2022년 아파트 조리실험은 실내 조리입자와 실외농도·창가풍속에 따른 결과 차이를, 2023년 13개 도시학교 연구는 CO2 공기교환과 실외 PM 유입의 상충을 보여줌. 각 연구의 감소율·20분·0.4m/s·학교 창문조건을 다른 집의 보편 완료시간·최소풍속·효과로 복사하지 않음.
- 2015~2019년 국내 8개 지역 평균에서 오후 PM이 낮은 경향이 있었지만 지역·계절 차이가 컸으므로 `14~18시`나 `10~21시`를 개인 고정 환기시간으로 만들지 않음. 시간해상도 있는 PM10·PM2.5·오존·관련 꽃가루 자료가 없으면 현재 측정 한 건을 미래 슬롯에 복사하지 않고 열기 직전 재확인 가능성만 안내함.
- PM 좋음/보통이어도 오존 나쁨·경보, 꽃가루 높음/매우높음, 황사·산불연기·화학사고·악취 공식안내가 있으면 외기부담이 낮다고 만들지 않음. 공식 안내는 우선 확정 표시하고 앱의 개인 유입·불편·방법조정은 가능성형으로 남김.
- 실내 조리입자·CO2·수분원 등이 크고 실외 입자도 높은 상충상황은 한 점수로 상쇄하지 않음. 국소배기·필터형 외기환기·짧은 자연환기·다른 시각 재확인·재순환 청정을 역할별 후보로 나열하고 어느 것도 안전·필수·완료로 표시하지 않음.
- 공기청정기는 재순환형이면 실내입자 저감 가능성만, 제습기는 실내 수분 저감 가능성만 안내함. 외기를 공급하지 않으면 CO2·라돈·발생원을 밖으로 내보내는 환기완료로 기록하지 않음.
- 알림 진입은 조리·청소·스프레이·샤워·실내빨래·연소·다수재실·새 가구/공사 직접기록, 같은 방의 품질이 확인된 센서 관찰조건, 직접 불편기록과 비교요청, 사용자가 설정한 공식 일반안내 구독 중 하나를 요구함. 날씨가 좋아 보인다는 이유만으로 개인 환기 푸시를 만들지 않음.
- 체감 선택지에 환기 전 `공기가 갇힌 듯 답답·퀴퀴·음식냄새·눈코목 까끌·후끈하고 눅눅·끈적한 공기·평소와 비슷·잘 모름`, 환기 중/후 `산뜻·냄새 옅음·덜 답답·찬바람·건조·덥고 끈적한 외기·매캐/도로냄새·빗물·창 흔들림·소음·차이 없음`을 추가함. 직접기록은 확정하고 CO2·PM·습도기준·효과·완료·원인은 가능성형으로만 해석함.
- 5-12 상태군을 재사용하고 생활층에 `VENTILATION_CONTEXT_REVIEW_POSSIBLE`, 한쪽 창/맞통풍/필터형 방법 후보, 현재자료 재확인, 방법 접근·시작·종료·반응 직접기록, 공식자료 변경에 따른 후보갱신 상태를 제안함. `VENTILATION_GOOD/WINDOW/SAFE/DANGEROUS/REQUIRED/FORBIDDEN`, `CLEAN_AIR_CONFIRMED`는 만들지 않음.
- 현재 서버는 등급 문자열이 나쁘지 않고 강수확률 `<20%`, 강수량 없음, 풍속 `1~5m/s`가 2개 슬롯 이어지면 `VENTILATION_GOOD`를 만들며, 시간대 빌더는 이를 최소 10분 `VENTILATION_WINDOW`로 바꿈. 숫자만 있는 PM/O3 고농도 누락 가능성, 현재 에어코리아 첫 슬롯과 미래자료 결측, 비공식 강수·풍속·슬롯 경계, 공식 10분의 일반화 문제를 기록함.
- Flutter의 `환기하기 좋은 시간이에요`와 서버의 `환기하기 무난해요·지금부터 ○분 정도 환기하세요`를 제품화 전에 비활성화하고, 공식 카드·실내 발생원 직접기록·방법 프로필·열기 전 현재자료 재확인·시작/종료 직접기록을 갖춘 가능성 상태로 교체하도록 제안함.
- 6-11은 지금 고려할 수 있는 방법까지만 다룸. 창문을 언제 닫을지, 외기악화·비·돌풍 전에 얼마나 먼저 알릴지는 다음 6-12 `창문을 닫아야 하는 시점`에서 별도로 정의함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-11은 사용자 미확정 권장안이며 확정 전에는 다음 6-12로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-11 및 검토 6-12: 창문을 닫아야 하는 시점

- 사용자의 `확정 후 다음`에 따라 6-11 `환기 가능 여부` 권장안을 최종 채택함. 공식 외기·환기요령과 사용자 직접기록은 확정형, 창문·후드·필터형 외기환기의 도움·유입·불편 판단은 가능성형으로만 표시하고 `PM 좋음=안전`, `강수확률 20%·풍속 1~5m/s·2슬롯=환기 가능`, `모든 상황=10분`을 만들지 않는 원칙을 유지함.
- 다음 6-12 `창문을 닫아야 하는 시점`을 행정안전부·기후에너지환경부 2026년 화학물질 유·누출 행동요령, 국민안전24 강풍·산불·황사 행동요령, 국가미세먼지정보센터·환경부 환기요령, 기상청 꽃가루농도위험지수·10분 강수예측, 2026년 국내 강풍 피해 정책연구, 한국소비자원 베란다 안전사고, 국내 공동주택 환기 연구와 현재 서버 로직에 대조해 미확정 권장안으로 작성함.
- 공식 기관이 실제 발표한 `즉시 닫기·모든 창문 닫기·환기장치 중지·실내대기`는 기관·재난종류·대상지역·발표/발령시각·유효상태를 붙여 확정형으로 최우선 전달함. 앱의 일반 비·바람·PM·꽃가루·온습도·타이머가 공식 지시를 완화하거나 자체 종료/복귀를 선언하지 않음.
- 2026년 6월 행정안전부·기후에너지환경부 화학물질 유·누출 안내는 사고 초기 실내에서 창문을 즉시 닫고 환기구·틈을 막으며 에어컨 등 환기장치를 중지하도록, 사고 종료·복귀 때 즉시 환기하도록 안내함. 두 이벤트를 분리하고 실제 종료·복귀 안내 전에는 앱이 환기재개를 만들지 않음.
- 강풍은 국민안전24의 실제 공식 행동요령과 특보를 우선함. 기상청 2014~2024년 소방청 강풍 출동 6,581건 분석에서 최대순간풍속 10~20m/s에 피해가 집중되고 창문·지붕 마감재 손상이 15~20m/s에서도 가능하다고 설명했지만, 이를 모든 창문의 자동폐쇄·파손확정선으로 사용하지 않고 최대순간풍속·노후/틈·창짝 고정·건물노출을 함께 봄.
- 산불 대상지역 행동요령의 모든 창문·문 폐쇄, 황사 위기경보 중 창문 폐쇄와 해제 뒤 환기·청소, 기상청 꽃가루 매우높음의 창문 폐쇄, 미세먼지 나쁨 이상의 시설별 자연환기 자제/창문 폐쇄 안내는 각각 원래 기관·상황을 붙여 확정 표시함. 한 자료를 다른 경보·모든 가정의 자체 폐쇄선으로 바꾸지 않음.
- 6-12는 특정 창문이 실제로 열렸다는 사용자 직접기록 또는 품질이 확인된 접촉센서가 있어야 개인 닫기 후보를 만듦. 환기카드 열기·알림 확인·과거 열림·현관출입만으로 현재도 열려 있다고 확정하지 않음.
- 창문 열림·닫힘·잠금·개방폭·스마트창 명령수락·동작·접촉센서 닫힘을 서로 다른 상태로 저장함. `센서 CLOSED=잠김`, `명령 성공=실제 닫힘`, `한 창 닫힘=모든 창 닫힘`을 만들지 않음.
- 일반 닫기 시작 후보는 `가장 이른 관련 영향구간 하한 - 확인된 접근시간 - 확인된 닫기 소요범위 - 사용자 직접 여유시간`으로 계산함. 자료가 10분/1시간 단위면 그 해상도를 보존하고 핵심값이 없으면 임의 30분을 넣지 않으며 계산값을 안전 마감·필수 시각으로 부르지 않음.
- 접근·닫기 개인시간은 직접설정 또는 같은 사람·장소·창문에서 `알림 확인→창 접근→닫음 확인`의 비교 가능한 직접기록 5회 이상·사흘 이상일 때 관찰범위로만 제안함. 이는 연구 절단값이 아니라 한두 번을 고정시간으로 굳히지 않기 위한 제품 최소조건임.
- 10분 강수예측과 강우감지·창 안쪽 수분기록은 비 접근/유입 가능성에 사용하되, POP 40%만으로 정확한 도달·실내유입을 확정하지 않음. 창 방향·처마/차양·층·개방폭·이전 들이침 기록이 없으면 exact 닫기시각을 만들지 않음.
- 평균풍속 9m/s는 공식 `강한 바람` 표현의 시작값이지만 창문 공식 폐쇄·파손선이 아님. 최대순간풍속·특보·창호·노출을 분리하고 앱 문구는 `창짝이 흔들리거나 물건이 움직일 수 있어 닫기를 살펴볼 수 있어요`처럼 가능성형으로 제한함.
- PM10/PM2.5·오존·황사·연기·악취·꽃가루가 변하면 공식 사실을 확정 표시하고 현재 창문방법 재검토 가능성만 안내함. `PM 나쁨=모든 창 즉시 폐쇄`, `오존 나쁨=자동닫기`, `꽃가루 낮음=계속 열어도 안전`을 만들지 않음.
- 조리 뒤 30분·일반 환기 10/30분·사용자 타이머·실내 CO2/PM/VOC 관찰범위는 닫기 재확인 맥락일 뿐 오염제거·환기완료·건강안전을 뜻하지 않음. 창문을 닫은 뒤에도 조리·CO2·라돈·수분원이 남을 수 있어 6-11의 다른 방법을 함께 보여줄 수 있음.
- 외출·수면·방범·소음, 어린이·반려동물 접근은 날씨와 별도 생활안전 맥락으로 둠. 한국소비자원 2016~2018년 베란다 위해 1,158건 중 10세 미만 43.6%, 새시 관련 40.3%, 난간 밖 추락 14건·손가락 절단 5건을 잠금·접근 확인 근거로 반영하되 특정 가정의 사고확률이나 모든 외출의 창문 폐쇄의무로 바꾸지 않음.
- 체감·현장기록에 `창 안쪽 빗방울·커튼/바닥 축축·창 덜컹·틈새 휘파람소리·찬바람·덥고 끈적한 외기·매캐/도로냄새·노란 가루·연기냄새·소음·벌레·뻑뻑함·닫은 뒤 틈 느낌·평소와 비슷·잘 모름`을 추가함. 직접기록은 확정하고 파손·누수·꽃가루·산불·원인은 가능성형으로만 해석함.
- 날씨·대기질·재난문자만으로 일반 스마트창을 자동으로 닫지 않음. 명시적 사용자 승인, 정확한 창문, 제조자 원격폐쇄 허용, 온라인·위치·장애물/끼임방지·수동해제·전원/통신·최종센서가 모두 확인되는 별도 자동화로 다루며 어린이·반려동물·손·커튼·피난/배연계획이 불명하면 자동동작을 제안하지 않음.
- `OFFICIAL_WINDOW_CLOSURE_GUIDANCE_SHOWN`, 열림/닫힘/잠금 직접기록, 비유입·바람·외기질·꽃가루·온습도·외출/수면·어린이/반려동물 닫기 검토 가능성, `WINDOW_CLOSE_START_CANDIDATE`, 알림 갱신·상태불명·정보부족 상태를 제안함.
- `WINDOW_CLOSE_SOON/REQUIRED/MUST_CLOSE`, `LAST_SAFE_WINDOW_CLOSE_TIME`, `WINDOW_SAFE_TO_KEEP_OPEN`, `WINDOW_DANGER`, `RAIN_WILL_ENTER`와 `닫아야 해요·반드시·위험해요·안전 마감·환기 완료` 내부문구는 만들지 않음.
- 현재 서버는 2시간 안에 `PTY/강수량/POP≥40%` 또는 풍속 `≥9m/s`인 첫 슬롯을 찾고 무조건 30분을 빼 `WINDOW_CLOSE_SOON.actionDeadline`을 만듦. 비 또는 바람 하나만 있어도 두 source fact를 모두 넣고, 현재 영향이면 과거 마감시각을 만들 수 있으며 열린 창·10분 강수·순간풍·특보·대기질·재난·꽃가루·실내/생활맥락이 없음.
- 현재 `WINDOW_CLOSE_SOON`과 고정 `영향시각-30분`은 제품화 전에 비활성화하고 `열림/닫힘 직접기록 → 공식 재난 창문안내 → 10분 강수접근 → PM/꽃가루/강풍 변화 → 개인 접근시간 → 센서/자동창` 순으로 교체하도록 제안함. Flutter 전용 매핑과 생성 테스트도 확인되지 않음을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-12는 사용자 미확정 권장안이며 확정 전에는 다음 6-13 `외출하기 좋은 시간`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 6-12 국내 실제 수치·체감 근거 보강

- 사용자 요청에 따라 6-12 `창문을 닫아야 하는 시점`을 국내 가구 현장관측·주관 온열응답·공식 실내공기정보·공동주택 환기설비기준·KS 창호시험자료로 다시 검토함. 6-12는 계속 미확정 권장안이며 다음 항목으로 이동하지 않음.
- 2016년 국내 20가구 연속측정에서 창문 열기 이유는 청소 40%, 신선한 공기 33%, 조리 27%였고 하루 평균 개방은 0.5~1.8회, 합계 개방시간은 0.4~0.6시간이었음. 실외기온 12.7℃ 초과에서 열린 창 비율이 가파르게 달라졌고 닫기 행동은 개방 뒤 실내온도 하강과 관련됐지만, 12.7℃와 0.4~0.6시간은 각각 열기 행동변곡·하루 합계값이라 닫기선이나 1회 환기시간으로 쓰지 않음.
- 2023년 수도권 13가구의 2017-12-07~2022-12-31 장기자료는 실내외 물리변수 20개를 비교했으며 집·계절마다 결정요인이 달랐고 열기와 닫기의 주요변수도 달랐음. 실내외 변수 7개를 쓴 예측은 정확도가 높아졌지만 모든 집에 통하는 전형적 변수묶음은 없었으므로 기온·풍속 하나의 전국 공통 폐쇄선을 두지 않음.
- 2022년 국내 공동주택 30가구 10분 자료는 난방기 평균 실내 약 21℃, 일평균 실외 18℃ 이후 개방시간·환기횟수 증가를 관측했고, 2019년 연간 연구는 실외 17℃ 이후 가구차이 확대와 약 300m³/h의 환기량, 풍향·풍속·층수 영향을 보고함. 17/18℃·10분·300m³/h는 행동·측정·조사주택 유량값이라 닫기 온도·알림여유·완료기준으로 전용하지 않음.
- 2020년 국내 11가구의 5분 간격 실내환경·주관응답·행동연구는 실내온도-온열감 보정 회귀계수 0.356/K를 추정해 사무실의 보편값 0.5/K와 차이를 확인함. 0.356/K는 집단 회귀계수라 0.356℃ 또는 1℃ 하강 폐쇄선으로 쓰지 않고 동일 사용자·동일 주거의 직접 체감을 우선하는 근거로 사용함.
- 2022년 국내 온열감 표현어휘 연구는 평균 20.3℃·RH 47.9%의 같은 환경에서도 `시원함/서늘함`, `더움/따뜻함`의 어감에 따라 온열감·쾌적감·선호 응답분포가 달라짐을 보였음. 체감 선택지를 `산뜻·덜 답답·변화 없음`, `살짝 시원·얼굴/목덜미 서늘·발목 찬 기운·더 따뜻했으면 함`, `보송·후끈·눅눅하고 끈적`, `바람소리/덜컹·빗방울`로 넓히고 느낀 상태와 원하는 변화를 분리하도록 보강함.
- 질병관리청은 CO2 1,000~2,000ppm 도달 시 불쾌감을 유발한다고 안내함. 이 공식 정보는 실내 교환 맥락으로 쓰되 `1,000ppm 아래=환기 완료·닫기`, `2,000ppm=창문만 열기`로 바꾸지 않음. 현행 신축공동주택의 시간당 0.5회 기준도 설비 설치성능일 뿐 열린 창의 닫기시간이 아님.
- KS F 2293 수밀성은 물 분무·맥동압에서 누수를, KS F 2296 내풍압은 정·부압에서 변위·잔류변형을 제품별 시험함. 기상관측소 풍속·강수량을 제품 시험압력에 단순 환산하지 않고 사용자가 해당 창호의 제품등급·시험성적서를 입력한 경우에만 보조정보로 보존함.
- 내부 운영안을 `공식 폐쇄안내 확정 전달 → 실제 열린 창 확인 → 직접 빗물/수분·흔들림/진동·불편·해당 창 과거기록이 있으면 가능성형 검토후보 → 예보 숫자만 있으면 확인정보`로 강화함. 평균풍속 9m/s 또는 최대순간 10m/s만 있으면 `WIND_CONTEXT_SHOWN`으로 두고 공식 특보/행동요령·직접변화·비교기록 중 관련 추가근거가 있을 때만 `WIND_WINDOW_HANDLING_REVIEW_POSSIBLE`을 만들도록 수정함.
- 구현 경계검증에 12.7/17/18℃ 전후, 하루 합계 24/36분, 실내온도 하강 0/1/2/3℃, CO2 999/1,000/1,999/2,000ppm, 환기설비 0.5회/h, 평균/최대순간풍속과 공식·직접·개인기록 조합을 추가함. 어느 숫자도 단독 닫기·안전·위험·환기완료 상태를 만들지 않음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 보강함. 테스트·배포·커밋은 수행하지 않으며 형식검증으로 마무리함.

### 기준 채택 6-12 및 검토 6-13: 외출하기 좋은 시간

- 사용자의 `확정 후 다음`에 따라 6-12 `창문을 닫아야 하는 시점` 권장안을 최종 채택함. 공식 창문 폐쇄·환기장치 중지·복귀 안내와 사용자/센서의 실제 창상태는 확정형, 일반 비·바람·외기질·온습도·생활맥락의 닫기 판단은 가능성형으로만 표시하고 고정 30분·POP 40%·평균풍속 9m/s를 닫기 의무선으로 사용하지 않는 원칙을 유지함.
- 다음 6-13 `외출하기 좋은 시간`을 현재 기상청 공항·산악·생활/지수종합정보, 1시간 단위 예보 이용자 조사, 폭염·한파·호우·낙뢰 공식 행동요령, 국립공원 통제안내, 서울숲 보행량 연구, 한국은행 카드자료, 대전 시간대별 자전거·대중교통 연구, 수원 시민과학 온열감 연구, 한국인 PT·온열표현 연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 현재 기상청 종합목록에는 산악·해수욕장예보와 자외선·대기정체·꽃가루농도위험지수가 제공되지만 모든 활동에 공통인 일반 `외출지수/가장 좋은 시간`은 열거돼 있지 않음. 대상·환경별 체감온도 서비스는 2026-05-01 종료됐으므로 종료된 표를 현행 공식 외출기준으로 사용하지 않도록 함.
- 특보·영향예보·행동요령·측정·시설/탐방로 통제는 기관·대상지역/장소·발표/관측시각·유효구간을 붙여 확정형으로 표시함. 앱의 시간대별 부담·느낌·대체시간/경로 판단은 모두 `~수 있어요·가능성이 있어요·도움이 될 수 있어요·판단하기 어려울 수 있어요`로 제한함.
- 2021년 1,482명 기상청 조사에서 1시간 예보의 일상 유용도 85.1%와 강수시작·바깥활동·외출·퇴근 활용이 보고됐지만, 이를 개인 후보의 정확도/성공률로 사용하지 않음.
- 2025년 서울숲 연구는 2021·2022년 시간자료에서 보행량 최대 기온 약 20~22℃, 비가 온 시간 보행량 약 40~59% 감소, 풍속·습도·PM10 음의 관계와 일조 양의 관계를 확인함. 특정 공원의 집단 이용량 결과이므로 전국 공통 쾌적·안전온도나 개인 외출취소확률로 쓰지 않음.
- 한국은행 2023Q1~2025Q2 카드자료의 폭염·한파·강수 시 대면소비 중심 약 7%·3%·6% 감소와 대전 2023 시간교통 연구의 필수통행/조정가능통행/여가별 다른 대체반응을 외출목적을 분리할 근거로 사용함. 일별 집단 소비효과와 연구 전처리값을 개인의 시간대 기준으로 전용하지 않음.
- 수원 3년 시민과학 연구에서 32℃ 초과 시 공간별 온열감 차이와 호수공원 +3.5, 개방형 고·저층지역 +2.0이 관측됐으며 연령차도 있었음. 목적지 그늘·수변·건물배치·연령·직접체감을 받을 근거로 쓰되 32℃를 금지선, 낮은 고연령층 보고온열감을 낮은 생리부담으로 해석하지 않음.
- 한국인 19명 고온다습 환경실험의 PT 따뜻함/더움/매우더움 28/36/43℃와 988명 한국어 표현연구의 `따뜻하다=쾌적 80.4%`, `약간 덥다=불쾌 54.3%`는 체감어휘 분화 근거로만 사용함. 전 연령·전 계절·직사광선/활동강도의 외출 절단값으로 사용하지 않음.
- 외출 전 목적·필수/조정가능·출발지/목적지/경로·수단·전체/실외/대기시간·활동강도·동행자·그늘/대피처·운영/통제·사람특성·줄이고 싶은 부담을 받도록 함. 계획이 없으면 개인 `좋은 시간` 푸시를 만들지 않고 시간대별 사실 비교만 제공함.
- 시간후보는 공식정보/통제 우선 → 관측/예보 출처·해상도 보존 → 체감온도·강수/낙뢰·평균/순간풍속·UV·PM/O3·꽃가루·노면을 차원별 표시 → 계획 실외시간 전체 포함 → 차원별 비지배 후보 2~3개와 상충 표시 순으로 계산함.
- 한 부담의 낮은 값을 다른 부담의 높은 값과 상쇄하는 단일 점수를 두지 않음. 후보가 하나여도 `가장 좋음`이 아니라 `현재 자료에서 비교 가능한 시간대`로 표시하고 90분 계획에 1시간 슬롯 하나만 맞으면 후보를 만들지 않음.
- `OFFICIAL_OUTING_GUIDANCE_SHOWN`, 목적지 운영/통제·계획 직접기록·시간대 사실, `OUTING_LOWER_BURDEN_WINDOW_POSSIBLE`, 상충·실내/차양 경로·후보갱신·정보부족과 온열/강수/바람/대기/볕/꽃가루 차원별 가능성 상태를 제안함.
- `BEST_OUTING_WINDOW/PERFECT_OUTING_TIME/OUTING_GOOD/SAFE/RECOMMENDED/REQUIRED/FORBIDDEN`은 만들지 않음. `가장 편안·무난·안전·외출해도 됨`, 체감온도 10~30℃·UV<6·풍속 1~5m/s 결합으로 좋음을 확정하는 내부문구도 사용하지 않음.
- 체감 직접기록에 `볕이 포근·그늘은 선선·얼굴/목덜미 서늘·손끝 시림·후끈·피부/등이 끈적·바람이 옷자락/우산을 잡아당김·보슬비·신발/바짓단 축축·햇볕 따가움·매캐·눈코목 까끌·숨참·평소와 비슷·잘 모름`을 추가함. 직접느낌은 확정하고 원인·다음 느낌·시간조정 도움은 가능성형으로 해석함.
- 현재 서버는 체감온도 10~30℃·UV<6·평균풍속 1~5m/s·비 없음·AQ/O3 나쁨 아님·경고 없음이 2슬롯 연속인 첫 구간을 `BEST_OUTING_WINDOW`, 고정점수 55, 빈 sourceFacts로 생성함. 계획·경로·실외시간·순간풍속·PM2.5/꽃가루·그늘/공간·시설통제·상충·신선도가 없고 첫 구간이 최저부담이라는 근거도 없음.
- 서버의 `가장 편안해요/상대적으로 무난해요` 템플릿을 사용하지 않도록 제안함. Flutter에는 `BEST_OUTING_WINDOW` 전용 enum 매핑이 없어 미등록 타입이 `outdoorCaution`으로 대체되고 `야외활동은 짧게` 또는 `해 질 무렵이 편안해요`처럼 서버와 다른 의미가 표시될 수 있음을 기록함.
- 현행 `BEST_OUTING_WINDOW`는 제품화 전에 비활성화하고 `계획입력 → 공식정보/시설통제 → 시간대 사실 → 차원별 비교 → 후보·상충 → 직접경험` 순으로 교체하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-13은 사용자 미확정 권장안이며 확정 전에는 다음 6-14 `운동 가능 시간`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-13 및 검토 6-14: 운동 가능 시간

- 사용자의 `확정 후 다음`에 따라 6-13 `외출하기 좋은 시간` 권장안을 최종 채택함. 공식 특보·행동요령·관측/측정·시설통제는 확정형, 앱의 시간대별 부담·대체경로·개인체감은 가능성형으로만 표시하고 단일점수·고정 2시간·전국 공통 10~30℃로 `가장 좋은 외출시간`을 만들지 않는 원칙을 유지함.
- 다음 6-14 `운동 가능 시간`을 질병관리청 신체활동 지침·2025 온열질환 연보·2025~2026 한랭질환 결과, 기상청 폭염/한파/호우/낙뢰 행동요령, 에어코리아 PM/O3 행동요령, 국내 고온다습 운동·반복 고온운동·엘리트선수 대기오염·미세먼지 운동참여·마라톤 열사병 연구 및 현재 서버/Flutter 구현과 대조해 미확정 권장안으로 작성함.
- 목록 제목은 `운동 가능 시간`으로 유지하되 사용자 결과명은 `운동계획과 날씨 비교`로 제안함. 앱이 의료적 운동허가·금지·안전·위험을 자체 확정하지 않고 시간·강도·길이·장소·실내대안 조정 가능성만 표시하도록 함.
- 질병관리청 공식 설명의 중강도 `3.0~5.9 MET·심박/호흡 조금 증가`, 성인 고강도 `6.0 MET 이상·심박/호흡 많이 증가`, 성인 주 `중강도 150~300분/고강도 75~150분`, 근력 주 2일을 확정형으로 표시함. 이를 개인 MET 자동계산·매일 30분·한 회 최소/최대시간·날씨별 운동허가로 바꾸지 않음.
- 실제 폭염/한파 특보·영향예보, PM/O3 등급·경보, 호우/낙뢰 행동요령, 시설·대회 취소/통제를 기관·대상·발표/측정시각·유효구간과 함께 확정형으로 우선 표시함. 공식 운동자제·대피·통제가 유효하면 같은 시간의 긍정 실외운동 후보를 만들지 않고 공식안내와 실내/다른 날 비교 가능성을 분리함.
- 2025년 온열질환 4,460명·추정사망 29명, 실외 3,534명(79.2%), 운동장/공원 237명(5.3%; 열사병 28·열탈진 167)을 반영함. 운동장/공원 발생이 하루 여러 시간대에 기록됐지만 신고자료에 노출분모가 없고 운동 외 활동도 포함될 수 있어 개인확률·시간대 발생률·`저녁=안전`을 만들지 않음.
- 질병관리청이 최종 정리한 2025-12-01~2026-02-28 한랭질환 364명·추정사망 14명, 실외 273명(75.0%), 저체온증과 국소성 한랭손상을 합친 운동장/공원 1·스키장 3·산 33·강가/해변 38명을 반영함. 자발적 참여 응급실 신고자료이고 장소별 분모와 활동목적이 없어 기온·장소별 운동허용선으로 사용하지 않고 바람·젖음·노출시간·고립·대피거리를 분리함.
- 국내 20대 남성 13명의 33±0.5℃, RH 35/55/85%, VO2max 60% 실험에서 고막온·최대산소섭취량·최대심박수·일부 회복반응의 습도차가 관측된 점을 반영함. 33℃·RH값은 소표본 통제실험 조건이라 운동 허용/중단선으로 쓰지 않음.
- 2016년 국내 반복 고온운동에서 두 번째 부하 뒤 피부/고막온 상승과 시간에 따른 운동자각도 누적이 관측된 점을 반영해 같은 날 앞선 운동·연속수업·예선/본선·회복을 함께 받도록 함. 연구결과로 개인 휴식시간을 산출하지 않음.
- 2019~2020년 한국체대 엘리트선수 59명 10회 추적에서 대기오염·기상과 훈련 뒤 폐기능/호흡증상의 누적연관이 관측되고 단일오염모형의 PM2.5 10㎍/㎥ 증가가 FEV1 32.31mL·FEV6 36.93mL 감소와 연관됐지만, 관찰회귀를 개인 폐기능 변화·흡입량·운동중단선으로 계산하지 않음.
- 2025년 논문의 2018 수도권·부산 성인 726명 자료에서 미세먼지 때 청년/중장년 운동빈도·시간 감소와 노년층 실외걷기/실내수영·요가 유지가 다르게 나타난 점을 연령·생활여건별 대안 차이 근거로 사용함. 집단행동을 개인행동·적합성으로 확정하지 않음.
- 국내 마라톤 열사병 24명 임상자료의 초기 직장체온 평균 39.9±1.3℃, 실신 70.8%, 의식변화 29.2%는 고강도 장거리운동의 실제 중증사례와 직접 이상증상 우선 근거로만 사용함. 오래된 단일병원 환자군이라 발생률·날씨경계를 만들지 않음.
- 운동계획에 종류·개인/수업/대회·사용자가 느끼는 호흡강도·준비/본/정리/이동·반복세션·경로·표면·그늘/대피·물/휴식·시설·동행·운동경험·당일 앞선 운동·직접상태·의료진 계획을 받도록 함. 운동명만 있고 강도·전체노출시간이 없으면 시간후보를 만들지 않음.
- 후보는 공식안내/통제 우선 → 6-13 시간대별 온열·한랭·강수/낙뢰·바람·UV·PM/O3·꽃가루·표면·조명 벡터 → 운동강도·전체노출·반복·대피거리 → 전 구간을 담는 비지배 후보·상충 순으로 계산함. 합산 `exerciseScore`를 두지 않음.
- 고강도 20분과 중강도 40분의 주간 환산을 같은 날씨부담으로 상쇄하지 않음. 실내대안도 운영·실내온습도·환기·PM/CO2·혼잡·기구상태가 확인된 범위에서만 비교하고 `실내=양호`를 만들지 않음.
- `OFFICIAL_EXERCISE_GUIDANCE_SHOWN`, 시설/대회 상태, 운동계획·시간대 사실, `LOWER_WEATHER_BURDEN_EXERCISE_WINDOW_POSSIBLE`, 강도조정·실내대안·직접반응·공식건강안내·후보갱신·정보부족과 차원별 가능성 상태를 제안함.
- `EXERCISE_ALLOWED/SAFE/GOOD/RECOMMENDED/REQUIRED/FORBIDDEN`, `MEDICALLY_FIT_TO_EXERCISE`, `BEST_EXERCISE_TIME`과 `지금 달려도 돼요·오늘은 운동하면 안 돼요·30분만 하면 괜찮아요` 같은 앱 허가/금지/안전확정 문구를 만들지 않음.
- 체감·직접반응에 `몸이 가볍고 잘 풀림·관절 뻣뻣·숨 약간/많이 가쁨·평소보다 빨리 참·다리 묵직·땀 송골송골·등/목 축축·옷이 끈적하게 달라붙음·얼굴 화끈·햇볕 따가움·바람이 몸/자전거를 옆으로 밂·손귀 얼얼·몸떨림·젖은 옷이 차갑게 붙음·눈목 까끌·기침/쌕쌕·가슴불편·머리 띵·어지러움·메스꺼움·노면 미끄러움·평소와 비슷·잘 모름`을 추가함. 직접사실은 확정하고 질환·원인·다음 반응은 가능성으로 남김.
- 직접 이상증상은 반복 개인화 최소횟수와 무관하게 공식 건강/응급안내를 우선 연결하되 앱이 질환·중증도·회복을 진단하지 않음. 심박계 수치는 측정사실로 저장할 수 있지만 나이공식 하나로 최대심박·안전구간을 확정하지 않음.
- 현재 서버에는 운동 전용 타입/계획이 없고 `OUTDOOR_ACTIVITY_CAUTION`은 `STRONG_WIND` 하나로만 생성됨. 열·습도·PM·UV 일반 메시지는 분리돼 있으며 `RESPIRATORY_CAUTION`은 enum/템플릿만 있고 생성규칙이 확인되지 않음. 기본 체감온도/기온 33℃·풍속 6/9m/s·UV 6/8·PM10 81·PM2.5 36도 운동 허용/중단선이 아님.
- Flutter `outdoorCaution`은 `야외활동은 짧게 하고 휴식을 챙겨요` 또는 `해 질 무렵이 편안해요`로 고정돼 운동종류·강도·시간·근거가 드러나지 않음. 6-13 `BEST_OUTING_WINDOW`도 전체운동노출과 강도가 없어 운동시간으로 재사용하지 않도록 기록함.
- 현행 일반 야외활동 메시지를 운동판정으로 확장하지 않고 `운동계획/강도 → 공식 특보·대기·시설안내 → 전체노출 시간선 → 차원별 부담·상충 → 강도/길이/장소 조정 가능성 → 직접반응·공식 건강안내` 순으로 별도 구현하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-14는 사용자 미확정 권장안이며 확정 전에는 다음 6-15 `반려동물 산책 가능 시간`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-14 및 검토 6-15: 반려동물 산책 가능 시간

- 사용자의 `확정 후 다음`에 따라 6-14 `운동 가능 시간` 권장안을 최종 채택함. 공식 운동·기상·대기·시설 안내는 확정형, 앱의 시간·강도·길이·장소·실내대안 판단은 가능성형으로만 표시하고 의료적 운동허가·단일점수·전국 공통 운동선을 만들지 않는 원칙을 유지함.
- 다음 6-15 `반려동물 산책 가능 시간`을 농림축산식품부 2025~2026년 계절별 반려동물 돌봄요령, 기상청 2026년 반려동물 여름 안전 가이드, 국내 반려견 독사교상·SFTSV·산책로 진드기·동물 폐 탄분증·산책환경 연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 첫 출시 지원종을 `반려견`으로 제한하고 사용자 결과명은 `반려견 산책계획과 날씨 비교`로 제안함. 고양이·토끼·조류·파충류 등에 개 규칙을 적용하지 않고 수의사 계획과 보호자 직접기록이 있을 때만 사실을 정리하도록 함.
- 공식 폭염·한파·강수/낙뢰·강풍·산불·PM/O3·공원통제와 농식품부 계절 돌봄·증상·진료·목줄/인식표/배변수거 안내는 기관·대상·발표/측정시각·유효구간을 붙여 확정형으로 표시함. 앱의 산책시간·길이·경로·배변외출·실내놀이 판단은 모두 가능성형으로 제한함.
- 농식품부 2025 여름안내의 이른 아침/저녁 짧은 산책, 아스팔트 직접확인, 잔디/흙 경로, 단두·노령·비만·짙은 털 상태확인을 반영함. `이른 아침/저녁`을 고정 시각으로, 개체특성을 금지분류로 바꾸지 않음.
- 기상청 2026 캠페인의 기온 33℃일 때 아스팔트 50℃ 이상 사례와 손등 확인 안내를 반영하되 `33℃→모든 노면 50℃`, `33℃ 미만→산책 가능`, 손등 확인 통과를 발바닥 안전검사로 사용하지 않음. 노면재질·일사·그늘·경과시간·실측/당시 직접확인을 분리함.
- 농식품부 2026 여름안내의 과도한 헐떡임·침 흘림·구토·무기력 관찰 시 시원한 곳 이동과 동물병원 진료 안내를 공식문구로 연결함. 직접 행동은 확정 기록하되 앱이 열사병·중증도·회복을 진단하지 않음.
- 농식품부 2025 겨울안내의 짧고 잦은 산책, 눈/염화칼슘 노출 뒤 발 세척·보습, 젖은 털 건조를 반영함. 0℃/-5℃ 같은 고정 한랭선 없이 바람·젖음·노면·제설제·발상태·대피거리를 분리함.
- 2022년 국내 한 병원 독사교상 개 59마리에서 사건이 주로 4~10월 12~17시, 초지, 목줄 산책 중 관찰된 결과를 계절·풀/초지·수변·탐색행동·병원접근 확인 근거로 사용함. 노출분모가 없어 흐림/비·시간·경로별 개체 교상확률이나 고정 금지선을 만들지 않음.
- 2026년 국내 개 혈액 715건 중 SFTSV RNA 16건(2.2%), 반려견 405건 중 3건(0.7%), 보호소 개 310건 중 13건(4.2%) 검출과 계절·지역·출처 차이를 반영함. 전국 반려견 유병률 연구가 아니므로 0.7%를 개인감염확률·가을 산책금지·기온선으로 쓰지 않음.
- 대전 반려동물/산책로 진드기 연구를 풀숲·경로이탈·산책 후 몸확인 근거로, 전북 사후검사 반려동물 124마리 중 56마리(45.2%) 탄소입자 관찰을 PM·도로변 체류·직접호흡 확인 근거로 사용함. 지역 채집·선택된 사후표본 결과를 개별 공원·PM 허용선·증상인과로 계산하지 않음.
- 국내 보호자 249명 설문에서 하루 1회 이상 산책 47.8%, 1회 1시간 미만 78.3%와 교통·야간·다른 개·휴식/녹지 환경요인이 조사됐지만 자기보고 행동분포일 뿐이므로 1시간을 권장·최소·최대 산책시간으로 사용하지 않음.
- 반려견 프로필에 종·단두·나이·체중/체형·털·평소활동·발/보행·수의사계획·과거 직접반응을, 계획에 배변/탐색/운동/훈련·전체시간·경로·노면·그늘·풀숲·수변·눈/제설제·물/대피·시설규정·보호자 맥락을 받도록 함.
- 후보는 공식 통제/행동요령 우선 → 반려견·보호자 계획 → 개와 보호자의 별도 부담벡터 → 전체노출을 담는 비지배 시간/경로 2~3개와 상충 → 직접행동/공식 수의행동안내 순으로 계산함. 합산 `petWalkScore`, 기본 20/30/60분, `저녁=안전`을 두지 않음.
- 더운 날 실제 노면 측정·당시 보호자 확인·재질/그늘/일사가 없으면 노면부담을 정보부족으로 남김. 흙/잔디 경로도 진드기·뱀·위생부담이 있을 수 있어 모든 차원의 양호경로로 확정하지 않음.
- `OFFICIAL_PET_CARE_GUIDANCE_SHOWN`, 공식 경로상태, 개 프로필·산책계획·노면사실·직접행동, `LOWER_COMBINED_BURDEN_PET_WALK_WINDOW_POSSIBLE`, 그늘/부드러운 노면·짧게 나누기·진드기/뱀·겨울 발/털·실내활동·공식 수의행동·갱신·정보부족 상태를 제안함.
- `PET_WALK_ALLOWED/SAFE/GOOD/RECOMMENDED/REQUIRED/FORBIDDEN`, `BEST_PET_WALK_TIME`, `PET_MEDICALLY_FIT_FOR_WALK`과 `지금 산책해도 돼요·아침 7시가 가장 안전해요·20분만 걸으면 괜찮아요` 같은 앱 허가/금지/안전확정 문구를 만들지 않음.
- 반려견 행동을 `걸음이 가벼움·느려짐·멈춤/눕기·집으로 되돌아가려 함·그늘이동·헐떡임·침·구토·무기력·앞발 번갈아 들기·발 핥기·절뚝·떨림·젖은 털·기침/쌕쌕·진드기 부착·평소와 비슷·잘 모름`으로 직접기록하고 원인·질환·다음 반응은 가능성으로 남김. 보호자의 후끈함·축축하고 끈적함·목줄 잡은 손 미끄러움·바람/노면 부담도 별도 기록함.
- 현재 서버는 `PET_WALK_WINDOW` enum과 `산책은 {{timeLabel}}가 좋아요`, `더위와 자외선이 약해지는 시간이에요`, `비와 대기질을 피한 산책 시간` 템플릿만 있고 생성규칙은 확인되지 않음. Flutter 전용 타입매핑도 없어 전송 시 일반 `outdoorCaution`으로 대체될 수 있음.
- 현행 `PET_WALK_WINDOW` 확정형 템플릿은 제품화 전에 비활성화하고 `지원종 → 반려견/보호자 계획 → 공식 안내/통제 → 경로 노면/그늘/생물노출 → 개·보호자 후보·상충 → 직접행동/공식 수의행동안내` 순으로 구현하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-15는 사용자 미확정 권장안이며 확정 전에는 다음 6-16 `출퇴근 위험`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-15 및 검토 6-16: 출퇴근 위험

- 사용자의 `확정 후 다음`에 따라 6-15 `반려동물 산책 가능 시간` 권장안을 최종 채택함. 첫 출시 반려견 한정, 공식 돌봄·시설·기상·대기 안내는 확정형, 앱의 산책시간·길이·경로·배변외출·실내놀이 판단은 가능성형으로만 표시하고 수의학적 허가·단일점수·고정시간을 만들지 않는 원칙을 유지함.
- 다음 6-16 `출퇴근 위험`을 기상청과 기존 채택 기준, 서울시 TOPIS, 한국도로교통공단 TAAS/사고분석, 도로·대중교통 운영기관 정보, 서울·대전·부산 교통행동 연구, 2024년 수도권 대설 실제사례와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 `출퇴근 위험`으로 유지하되 사용자 결과명은 `출퇴근 경로와 날씨 비교`로 제안함. 앱이 개인 사고·지각·환승실패·안전/위험을 확정하지 않고 시간·경로·수단·준비 대안을 살펴볼 수 있다는 가능성만 표시하도록 함.
- 기상청 특보·예보·관측, 도로/교량/지하차도 통제·해제, 열차 지연·운휴·증편, 버스 우회·무정차, TOPIS 구간속도·사고/고장 등은 기관·노선/구간·방향·발표/측정시각·유효시간과 함께 확정형으로 표시함. 미공지·결측을 정상운행·정시도착으로 바꾸지 않음.
- TOPIS 서울 일반도로 `25km/h 이상 원활, 15~25 서행, 15 미만 정체`는 공식 소통범례로만 표시하고 전국 도로·개인 위험선으로 확대하지 않음. TAAS 위험도로 4단계도 원 서비스가 해당 링크에 안내한 경우에만 공식 원정보로 표시함.
- 2021~2023년 폭설 때 서울 북악산로·와룡공원길·인왕산로 등 실제 통제이력을 결빙취약 경로맥락으로 사용하되 과거 통제를 오늘 통제로 확정하지 않고 현재 운영기관 발표를 우선함.
- 서울특별시·KT 2024 생활이동 자료의 평일 07~09시 경기·인천→서울 평균 70.3분·16.5km/h, 오전 서울유입 비귀가 통행 중 통근 77.1%를 혼잡·방향·목적별 기준선 필요 근거로 사용함. 이를 개인 기본시간이나 전국 고정 출퇴근창으로 쓰지 않음.
- 2025년 논문의 2023 대전 05~23시 6,935개 시간자료에서 강수·폭염·한파 때 공유자전거와 버스·지하철의 동적 변화, 주중 첨두/비첨두/주말별 다른 대체·시간조정·통행포기를 반영함. 집단 VAR 결과와 강수 0.5mm 전처리값을 개인 수단전환·금지선으로 쓰지 않음.
- 2024년 서울 25개 자치구 대중교통·기상·대기 분석에서 기상/대기 악화와 이용량 감소의 연관, 주말 영향이 주중보다 큼, 버스보다 지하철의 대기환경 영향이 작게 나타난 결과를 반영함. 정류장·역 접근/대기와 차량/열차 내부를 분리하되 지하철을 항상 더 낮은 부담으로 확정하지 않음.
- 부산 2011~2015 교통카드 분위회귀에서 온도·습도·강우의 영향이 버스·지하철·버스-버스·버스-지하철 환승과 평일/휴일·통행량 분위에 따라 달랐던 결과를 환승별 분리 근거로 사용함. 오래된 집계 회귀계수를 개인 환승실패확률·추가분으로 사용하지 않음.
- 한국도로교통공단의 2020~2024년 7월 빗길 사고가 오후 9시 전후 13%로 가장 많았고, 2018~2022년 여름 빗길 치사율이 맑은 날의 약 1.5배였던 분석을 야간·곡선/내리막·고속도로·시야/제동 분리 근거로 사용함. 개인확률·금지시간으로 전용하지 않음.
- 2020~2024년 빙판길 사고 4,112건, 교량·고가도로가 일반도로보다 노면온도가 약 5~6℃ 낮을 수 있고 결빙 사고 치사율이 마른 노면의 2~4배였던 분석을 반영함. 대기기온·교량 여부만으로 노면온도를 보정하거나 사고확률·통제를 만들지 않음.
- `블랙아이스(도로살얼음)` 명칭을 사용자 문구에 우선 사용함. 공식 노면관측·운영단계·통제는 확정형, 비/눈 가능성과 기온/사람 체감온도만 있으면 형성 가능성·정보부족으로만 표시함.
- 2024-11-27 수도권 대설 때 서울 9호선 한때 8~9분 지연, 오전 8시 30분 서울 전체 평균속도 18.0km/h·도심 15.6km/h, 4개 도로통제와 사고·부분통제가 함께 발생한 사례를 실시간 다중 Provider 필요 근거로 사용함. 적설량만으로 지연분·출발여유를 재현하지 않음.
- 출퇴근 계획에 목적/필수성, 사용자의 실제 출발가능범위·도착제약, 문 앞부터 목적지까지 보행/대기/승차/환승/주행 구간, 걷기·휠체어·자전거·PM·오토바이·버스·철도·승용차 복합수단, 환승/엘리베이터/동행·주차/인계시간, 개인 맥락과 유사통행 직접기록을 받도록 함.
- 후보는 공식 사고/통제/운행·기상 우선 → 실제 일정·경로분절 → 구간별 시공간 예보/관측 → 수단별 보행/대기·자전거/PM·도로주행·철도/지하철 부담 → 최신 ETA/개인기록 범위 → 비지배 시간/경로/수단·상충 순으로 계산함. 합산 `commuteScore`와 임의 `+10/+20/+30분`을 두지 않음.
- 4-4 보행·자전거·운전 풍속기준을 그대로 재사용해 공식 노선 바람·통제를 우선하고 평균 6m/s를 모든 수단의 위험선으로 쓰지 않음. 버스·지하철도 정류장/역 접근·대기·환승·혼잡을 포함함.
- `OFFICIAL_COMMUTE_WEATHER_INFORMATION_SHOWN`, 공식 운행장애·경로통제·경로관측, 출퇴근계획·구간날씨 사실, 도착지연·환승여유감소·보행노면·비바람취급·도로시야/제동 가능성, 대체경로/수단·출발시각 검토, 직접경험·정보부족 상태를 제안함.
- `COMMUTE_SAFE/DANGER/HIGH_RISK/LOW_RISK`, `BEST_COMMUTE_TIME`, `SAFE_ROUTE`, `COMMUTE_RECOMMENDED/REQUIRED/FORBIDDEN`과 `출퇴근이 위험해요·30분 일찍 나가세요·차를 두고 가세요·반드시 지하철·가장 안전한 경로` 같은 내부 확정·명령 문구를 만들지 않음.
- 직접경험에 빗물 맺힌 안경/전면유리, 축축한 신발·양말·바짓단, 우산/가방이 끌림, 미끄러운 발 느낌, 손발 시림, 등이 축축하고 끈적함, 후끈한 환승통로, 답답함·숨참, 옆바람에 자전거/차가 밀리는 느낌, 실제 출발/도착/대기/환승실패·평소 대비 시간을 추가함. 직접사실은 확정하고 원인·다음 결과는 가능성으로 남김.
- 현재 서버는 `05~09/17~20시` 고정, 아침/저녁 4℃ 차, 비/눈+평균풍속 6m/s, 추정 `ICY_ROAD_RISK`를 점수 75/85/95로 `COMMUTE_WEATHER_CHANGE/RISK`에 연결함. 사용자 일정·경로·수단·실시간 운행·통제·도착제약·순간풍속·노면자료가 없음.
- 현재 `COMMUTE_RISK.sourceFacts`는 실제 존재하지 않을 수 있는 비·강풍·결빙 세 유형을 항상 담고, 템플릿은 `여유가 필요해요·우산을 챙기세요·속도를 낮추세요`처럼 내부 판단/명령을 확정함. 실제 존재한 근거만 구간·시각과 함께 보내고 가능성형으로 교체하도록 제안함.
- Flutter에는 두 출퇴근 타입 전용 매핑이 없어 기본 `outdoorCaution`으로 대체되고 `해 질 무렵이 편안해요` 같은 무관한 표현이 표시될 수 있음. 전용 타입·근거·구간·신선도 계약을 추가하도록 제안함.
- `현재 미연결 출력의 근거자료 선정 항목`에 `출퇴근 경로와 날씨 비교` 행을 추가해 실시간 교통 Provider, 사용자 일정/전체경로, 고정시간·풍속 6m/s·임의 추가분·단일점수 금지, 공식사실/가능성 분리 조건을 기록함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-16은 사용자 미확정 권장안이며 확정 전에는 다음 6-17 `보행·운전 주의`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 채택 6-15 수의사·수의학 근거 재검토

- 사용자의 요청에 따라 이미 채택한 6-15 `반려동물 산책 가능 시간`을 국내 수의사 설명, 국내 반려견 재활 연구, 국립축산과학원 안내, 국제 수의학 생애주기·골관절염 합의지침, 관절염 보행분석·수의사 처방 활동·열관련질환 연구로 다시 검토함. 6-16 `출퇴근 위험`의 미확정 상태는 바꾸지 않음.
- 국립축산과학원의 `가벼운 산책부터 서서히 증가·상태관찰·건강상태에 따른 수의사 상담`을 국내 공식 일반원칙으로 추가함. 같은 오래된 교육자료의 견종별 단정·자전거/달리기 예시는 개체별 처방이나 필수활동으로 쓰지 않음.
- 박순석 수의사의 2026년 폭염·장마철 설명에서 개의 주된 헐떡임 열배출, 고온다습 환경, 노령·비만·심장/호흡기 질환·단두형 맥락, 초기 행동변화를 확인함. 임상 칼럼이므로 공식 특보·전국 합의문으로 취급하지 않고 농식품부 행동요령 및 연구와 같은 방향을 보이는 보조근거로만 사용함.
- AAHA 생애주기 체크리스트의 나이·품종·기질별 운동/정신자극, BCS/MCS·통증·이동성·환경회피능력과 ACVS/COAST 골관절염 자료의 환자별 계획·통제된 저충격 활동을 반영함. `관절 문제=산책 없음`, `걷기=항상 유익` 두 방향의 단정을 모두 금지함.
- 골관절염견 10마리와 대조견 10마리의 1.2km 트로트 뒤 보행지표 연구에서 골관절염군의 절뚝임 악화가 관찰된 점을 산책 중뿐 아니라 귀가 뒤·휴식 뒤·다음 날 회복기록이 필요한 근거로 사용함. 작은 표본의 단회 운동이라 1.2km를 거리선으로 쓰지 않음.
- VCA 골관절염 자료의 `10분 걷기 하루 3회`는 규칙적 운동을 하지 않던 골관절염견의 임상 시작 예시이고, 퇴행성 판막질환 자료도 질환 맥락에서 평소활동과 지속 고강도 활동을 구분함. 앱에 `10분×3`이나 질환명별 허용시간을 넣지 않고 보호자가 등록한 담당 수의사 계획을 우선함.
- 수의사 처방 신체활동 8주 연구의 건강하지만 활동이 부족한 개-보호자 59쌍에서 활동량 증가가 관찰된 결과를 계획·기록·점진적 증가의 보조근거로 사용함. 웨어러블 피드백군과 비표시군의 주요 차이가 없었으므로 기기 목표를 의학적 적합성으로 확정하지 않음.
- 영국 VetCompass의 90만 5,543마리 진료기록에서 열관련질환 1,259건, 원인기록 879건 중 운동성 652건(74.2%)과 사건일 최대 WBGT 중앙값 16.9℃를 확인함. 이는 운동강도·시간·개체특성·휴식/탈출·직접징후를 기온과 함께 볼 근거이며, 영국 후향자료의 16.9℃를 한국 기온선이나 개인확률로 쓰지 않음.
- 2026년 브라질 단모 혼종견 5마리·135회·12분 산책 생리연구에서 발바닥온도와 지면온도의 강한 상관, 공기온도와 복사열을 함께 쓴 모델의 설명력을 확인함. 작은 열대 적응표본이므로 흑구온도 35℃·TSI 170을 한국 전 품종의 앱 경계로 쓰지 않고 일사·그늘·노면·시간·회복을 분리할 근거로만 사용함.
- 국내 동물재활센터 보호자-개 28쌍의 6주 피트니스 교육 관찰연구에서 운동순응도와 보호자 보고 LOAD/CBPI 개선이 관찰됐지만 대조군이 없고 `주 1회 60분`은 교육시간임을 기록함. 산책시간 처방이나 날씨 경계로 전용하지 않음.
- 6-15 입력에 `veterinaryExercisePlan`과 `conditioningAndRecoveryBaseline`, 산책 중·귀가 직후·휴식 뒤·다음 날 관찰시점을 추가함. 수의사 계획의 출처·설정/재평가일·활동형태·강도·연속시간/거리·횟수/휴식·노면/경사 제한을 그대로 보존하고 누락된 제한을 앱이 추정하지 않도록 함.
- `VETERINARY_EXERCISE_PLAN_RECORDED`, `GRADUAL_CONDITIONING_REVIEW_POSSIBLE`, `CONTROLLED_LOW_IMPACT_WALK_REVIEW_POSSIBLE`, `POST_WALK_RECOVERY_CHANGE_RECORDED`, `VETERINARY_PLAN_REVIEW_POSSIBLE` 상태와 가능성형 문구를 추가함. 수의사 계획과 보호자의 직접기록은 확정형 사실, 앱의 원인·부담·조정·재확인 판단은 가능성형으로 분리함.
- 검증항목에 건강견/관절/심폐/수술회복 사이 숫자 복사 금지, 수의사 계획 밖 확대 금지, 산책 중과 다음 날 반응 분리, WBGT 16.9℃·흑구온도 35℃·TSI 170의 한국 허용선 전용 금지, 냄새탐색/평지걷기/달리기의 같은 시간 동일부담 처리 금지를 추가함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 보완함. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않음.

### 기준 채택 6-16 및 검토 6-17: 보행·운전 주의

- 사용자의 `확정 후 다음`에 따라 6-15 수의사·수의학 보완검토와 6-16 `출퇴근 위험` 권장안을 최종 확정함. 6-16은 공식 특보·관측·도로/교통 통제·운행 지연을 확정형으로, 앱의 도착지연·환승·보행/주행 부담·시간/경로/수단 대안은 가능성형으로 표시하고 고정 출퇴근창·단일점수·임의 추가시간을 만들지 않는 원칙을 유지함.
- 다음 6-17 `보행·운전 주의`를 현행 도로교통법 시행규칙 제19조, 기상청·행정안전부 대설/한파/호우/태풍 행동요령, 한국도로교통공단 빗길·빙판길·안개 사고분석, 질병관리청 2025년 겨울철 노인 낙상 자료, 2025년 강원 폭설 실제 피해, 4-4 강풍 기준과 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 결과명은 `보행·운전 경로와 노면 확인`으로 제안함. 6-16은 일정·도착지연·환승을, 6-17은 특정 보도/도로 구간의 노면·시야·횡풍·통제와 법정 행동을 다루도록 경계를 분리함.
- 도로교통법상 비로 젖은 노면·20mm 미만 적설 때 최고속도 20% 감속, 가시거리 100m 이내·노면결빙·20mm 이상 적설 때 50% 감속, 가변형 속도제한표지 우선을 공식 법정 기준으로 확정 안내함. 현재 도로 최고속도·가변표지·실제 조건이 없으면 숫자 km/h를 계산하지 않고 보행자·자전거에 차량 감속률을 복사하지 않음.
- 기상청 대설/한파 행동요령의 넓은 밑창·장갑·보폭 10~20% 축소, 운전 전 성에 제거·저속·차간거리·커브/교량/결빙구간 사전감속과 호우/태풍 행동요령의 침수도로·지하차도·교량 통행금지를 공식 안내로 연결함. 앱 자체 보행·운전 판단과 섞지 않고 출처·적용대상·유효시각을 붙임.
- 2020~2024년 7월 빗길 사고의 오후 9시 전후 13%, 2018~2022년 여름 빗길 치사율 2.0명/100건 대 맑은 날 1.3, 2020~2024년 빙판길 사고 4,112건과 교량/고가 결빙사고 치사율 2~4배를 야간·곡선/내리막·교량·노면관측을 확인할 근거로 사용함. 집단통계를 개인 확률·금지시간·노면온도 보정식으로 전용하지 않음.
- 2016~2020년 안개 교통사고 1,187건·사망 105명·부상 2,057명, 전체 치사율 8.8명/100건·보행자 사고 25명/100건·오전 6~8시 40.5%를 운전자 시야/등화/차간거리와 보행자 횡단/차량발견을 함께 볼 근거로 사용함. 법정 가시거리 100m는 실제 관측값이 있을 때만 적용하고 집계수치를 개인 사망확률로 쓰지 않음.
- 질병관리청 2025년 자료의 국내 65세 이상 겨울철 낙상 응급실 내원·입원 증가와 주된 장소 `길·도로`, 눈/빙판 환경요인을 반영해 고령·균형/보행보조기구·불규칙 지면·계단을 별도 맥락으로 받도록 함. 노인 집단 결과를 전 연령 기온/적설 낙상선으로 사용하지 않음.
- 2025-03-04 강원 산지 약 14~20cm 적설 때 교통사고 11건·차량고립 3건·낙상 3건 등 24건 신고 사례를 보행과 차량 피해가 다른 경로에서 함께 나타날 수 있다는 실제사례로 사용함. 단일 하루의 관측소 적설을 앱 임계값이나 법의 노면 적설과 같은 값으로 보지 않음.
- 보행·운전 역할, 경로/방향/시각, 횡단·계단·경사·지하차도·교량·터널입출구·그늘/수변, 신발·짐·보조기구/동행, 차종·적재/견인·타이어/와이퍼 확인상태, 공식 통제·노면·가시거리·바람과 사용자 직접관찰을 입력으로 받도록 함.
- 판단 순서는 `공식 통제/법정 감속 → 역할/경로/시각 → 노면·가시거리·바람 사실 → 보행/운전별 가능성 → 비지배 대안 → 직접경험`으로 제안함. 자전거·개인형 이동장치·오토바이는 보행/승용차에 합치지 않고 4-4 별도 수단기준을 재사용함.
- `OFFICIAL_ADVERSE_WEATHER_DRIVING_RULE_SHOWN`, 공식 통제·노면관측, 보행/운전계획, 보행 미끄러짐/균형·횡단시야, 운전 시야/제동·횡풍 조향, 젖은 노면 잔류 가능성, 대안검토·직접반응·정보부족 상태를 제안함.
- `WALK_SAFE/DANGER`, `DRIVE_SAFE/DANGER`, `SAFE_SPEED`, `CAN_DRIVE`, `BEST_ROUTE`, 개인 사고확률은 만들지 않음. 공식 법정감속·통제·관측은 확정형, 앱의 미끄러짐·낙상·발견지연·제동·조향·침수 노출 판단은 모두 `~수 있어요·가능성이 있어요·도움이 될 수 있어요`로 제한함.
- 체감기록에 신발 밑 미끄러짐·미끈한 바닥·연석을 가린 물웅덩이·안경 빗물·우산 끌림·횡단신호 흐림·앞차 물보라·불빛 번짐·제동이 길게 느껴짐·교량 차량 쏠림·핸들 보정·ABS 작동·성에를 추가함. 직접관찰/차량표시는 확정하되 블랙아이스(도로살얼음)·수막·횡풍·결빙 원인은 자동확정하지 않음.
- 현행 `SNOW_TRAVEL_CAUTION`은 눈 예상만으로 보행과 운전에 명령형을 함께 표시하고, `WET_ROAD_CAUTION`은 비/눈 예보가 끝난 첫 스냅샷만으로 점수 70과 `길이 젖어 있어요`를 확정함. `ICY_ROAD_RISK`는 비/눈과 사람 체감온도 0℃만으로 점수 95를 만들 수 있어 노면온도·수분·형성경로가 없음.
- Flutter에는 `WET_ROAD_CAUTION` 전용 매핑이 없어 일반 `outdoorCaution`으로 대체됨. 기존 단일점수 경로를 비활성화하고 공식 사실·보행 가능성·운전 가능성·경로/신선도 근거를 분리하는 데이터 계약과 전용 표시를 추가하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-17은 사용자 미확정 권장안이며 확정 전에는 다음 6-18 `세차 가능 여부`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-17 및 검토 6-18: 세차 가능 여부

- 사용자의 `확정 후 다음`에 따라 6-17 `보행·운전 주의` 권장안을 최종 채택함. 법정 감속·공식 특보/관측·통제·가변속도는 확정형, 앱의 미끄러짐·낙상·시야·제동·조향·대안 판단은 가능성형으로 표시하고 보행/운전 분리·단일점수/임의 안전속도 금지 원칙을 유지함.
- 다음 6-18 `세차 가능 여부`를 기상청 단기/10분 강수예측·황사관측/특보·가뭄 행동요령, 현대자동차 차종별 외장/부식방지/세차 지침, 기아 방문세차 실제 운영조건, 국내 도로 강우유출 연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 결과명은 `세차 계획과 날씨 비교`로 제안함. 앱이 `가능/불가·좋음/미루기`를 확정하지 않고 작업중단·재젖음/재오염·물자국·잔수동결·비산수 취급 부담과 시간/방식/장소 대안을 살펴볼 수 있다는 가능성만 표시함.
- 기상청 공식 예보·관측·황사경보, 에어코리아 측정, 지자체 물 사용 제한, 세차장 영업/취소, 등록 차종 설명서는 출처·위치/대상·발표/측정시각·유효시간을 붙여 확정형으로 표시함. 예보를 관측으로, 결측을 무강수·영업중·세차가능으로 바꾸지 않음.
- 초단기 강수예측의 10분 해상도는 작업시간에 맞추되 발생보증/정확도로 해석하지 않음. 세차 이동·대기·예비세척·본세척·헹굼·물기제거/건조·코팅 전체에 관측/초단기/단기예보를 붙이고 일부 무강수 슬롯만으로 전체 작업을 가능하다고 확정하지 않음.
- 기상청 황사경보 `PM10 1시간 평균 800㎍/㎥ 이상 2시간 지속 예상`과 황사 관측은 공식 원정보로만 표시함. 이 수치나 일반 PM 등급을 차량 표면 침착량·재오염선·세차금지선으로 변환하지 않고 실외 작업자 공식 행동요령을 별도로 우선함.
- 기상청 가뭄 행동요령의 자동잠금호스·받아 둔 물 사용과 지자체 실제 제한을 반영함. 기상가뭄 단계만으로 세차금지나 세차장 영업중단을 앱이 확정하지 않음.
- 현대자동차 설명서의 직사광선·뜨거운 차체에서 세차/왁스 회피, 물기제거/건조, 세차 뒤 브레이크 점검, 겨울 도어 주변 잔수, 염화칼슘·해안염분·진흙/분진·새 배설물/벌레 노출 뒤 적절한 관리 지침을 반영함. 한 차종 정성지침을 전국 공통 기온·일사·습도 임계값으로 쓰지 않고 정확한 차종/연식 설명서를 우선함.
- 기아 제휴 방문세차의 영하권 약제결빙·폭염/우천 실외작업 불가와 특정 오염 일반세차 제외는 해당 서비스 운영정보로만 확정 표시함. 워터리스 방문세차 조건을 모든 손세차·자동·실내세차의 공통 불가선으로 확대하지 않음.
- 국내 도로 강우유출 연구의 건기 축적 오염물질·초기강우 집중유출 관찰을 세차 직후 젖은 도로 주행 때 하부/측면 재부착 가능성을 살펴볼 보조근거로 사용함. 차량 재오염량·도장손상을 측정한 연구가 아니므로 강수량/건기일수로 개인 차량 결과를 계산하지 않음.
- 국내 공식·학술자료에서 강수확률 30/40/50%, 무강수 12/24/48시간, 기온 0/5/30℃, 습도·풍속 한 값으로 일반 세차 성공·도장보호·경제성을 검증한 공통 기준은 확인하지 못함. 현행 POP 40%·점수 55를 검증된 세차 경계로 사용하지 않음.
- 세차목적을 외관/광택, 유리·센서, 염화칼슘/염분/진흙, 새 배설물/벌레/수액/타르, 하부, 실내, 코팅/왁스로 나누고 방식·전체시간·사후주차/주행·차종설명서/마감·오염·시설/물 제한·차체/날씨·직접결과를 받도록 함.
- 외관 유지와 설명서가 관리 대상으로 둔 오염 제거를 분리함. 비가 다시 예보돼도 염화칼슘·해안 염분·새 배설물 같은 오염 제거까지 자동 연기하지 않고 `부분 제거 후 전체세차`, 다른 방식/시간/시설 등 목적을 보존하는 비지배안을 표시함.
- 판단 순서는 `공식 운영/물 제한·행동요령 → 세차목적·차종설명서/오염 → 방식·시설 → 전체 작업시간 공식날씨 → 차체·건조·사후노출 → 후보/상충 → 직접결과`로 제안함. 합산 carWashScore와 고정 무강수시간을 두지 않음.
- `OFFICIAL_CAR_WASH_SERVICE_STATUS_SHOWN`, 공식 날씨사실, 차종관리지침, 계획/오염기록, 야외작업중단·재젖음/재부착·고온차체 얼룩·잔수동결·바람 비산수 가능성, 상충후보·직접결과·정보부족 상태를 제안함.
- `CAR_WASH_ALLOWED/FORBIDDEN`, `CAR_WASH_GOOD/BAD/POSTPONE`, `BEST_CAR_WASH_DAY`, `CAR_WASH_SUCCESS`, `PAINT_SAFE`를 만들지 않음. 공식 업체의 이용불가/예약취소와 차종설명서 원문만 출처를 붙여 확정형으로 표시함.
- 체감/직접결과에 뿌연 먼지·노란가루·하부 흰자국·배설물/벌레/수액·유막, 뜨거운 차체·빠른 물/세제 마름·비산수·손시림·미끄러운 바닥, 물기제거·도어틈 잔수·매끈/까슬·물방울자국·브레이크 느낌·다음날 먼지/비를 추가함. 직접사실은 확정하고 꽃가루·염화칼슘·도장손상·황사 등 원인은 자동확정하지 않음.
- 현재 서버는 강수형태 존재, 강수량 최솟값 양수 또는 POP 40% 이상 스냅샷 하나만 있으면 `CAR_WASH_SCORE` 55와 `POSTPONE`을 만들고 `오늘 세차는 미뤄도 좋아요`를 표시함. 시간·목적·방식·장소·관측/예보·사후노출 구분이 없음.
- 템플릿의 `GOOD` 문맥 `당분간 강수 가능성이 낮아요 · 세차하기 무난해요`는 생성경로가 연결되지 않았고 `당분간` 범위도 없음. Flutter에는 `CAR_WASH_SCORE` 전용 매핑이 없어 기본 `outdoorCaution`으로 대체될 수 있음.
- 현행 `CAR_WASH_SCORE`를 제품화 전에 비활성화하고 전용 목적·방식·시간·근거·신선도 계약으로 교체하도록 제안함. `현재 미연결 출력` 행과 데이터 준비 분류도 새 기준에 맞춰 수정함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-18은 사용자 미확정 권장안이며 확정 전에는 다음 6-19 `야외행사 진행 가능 여부`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-18 및 검토 6-19: 야외행사 진행 가능 여부

- 사용자의 `확정 후 다음`에 따라 6-18 `세차 가능 여부` 권장안을 최종 채택함. 사용자 결과명 `세차 계획과 날씨 비교`, 공식 예보/관측·업체/제한·차종설명서 확정형, 앱의 중단·재젖음/재오염·얼룩·잔수동결·비산수 영향 가능성형, 목적/방식/전체작업·사후노출 분리와 POP 40%·단일점수/좋음·미루기 금지 원칙을 유지함.
- 다음 6-19 `야외행사 진행 가능 여부`를 2026년 현행 재난 및 안전관리 기본법 시행령 제73조의9, 행정안전부 `지역축제장 안전관리 매뉴얼(2024)` 원문, 기상청 낙뢰·강풍 등 현상별 공식 행동요령, 2024년 실제 축제·달리기/마라톤·어린이날 행사 운영사례와 현행 서버/Flutter에 대조해 미확정 권장안으로 작성함.
- 행정안전부 매뉴얼 PDF는 원문 250쪽을 추출하고 주요 84·86·87·88·90·171쪽을 렌더링해 확인함. 매뉴얼은 특보·예비특보뿐 아니라 특보 없는 갑작스러운 기상악화도 다루고, 강풍·폭우 등 발생 시 개최자·지자체·경찰·소방의 상황판단회의로 진행 여부를 결정하도록 안내함.
- 목록 제목은 유지하되 사용자 결과명은 `야외행사 일정과 현장정보`로 제안함. 주최자·지자체·시설·경찰·소방의 정상운영·축소·시간/장소변경·연기·중단·취소·재개·입장통제·대피/귀가와 공식 기상특보/관측은 대상·시각·출처를 붙여 확정형으로 표시함.
- 앱은 임시시설·젖은 노면·낙뢰노출·더위/추위·대기/퇴장·귀가 영향과 회차/실내·동선 대안을 `~수 있어요·가능성이 있어요·도움이 될 수 있어요`로만 표시함. 공식 정상운영도 `안전`, 특보 없음도 `영향 없음`, 비 예보도 `취소`로 변환하지 않음.
- 현행 시행령의 순간 최대 관람객 1천명 이상 또는 산·수면·불/폭죽·폭발성 물질 사용 지역축제 안전관리계획 대상을 반영함. 1천명은 법정 계획 대상선이지 999/1천명의 개인 안전 경계·혼잡점수·행사 취소선이 아님.
- 매뉴얼의 시간당 강수 5·7·10mm, 순간최대풍속 5·8·11m/s 표는 `기상악화 대책 작성 예시`임을 원문·렌더링으로 확인함. 행사별 계획 작성 예시를 전국 공통 Blue~Red·정상진행/취소·시설전도 경계로 채택하지 않고 실제 행사 공개기준을 우선함.
- 매뉴얼의 2024년 특보 없는 순간풍속 11.2m/s 돌풍에 대형부스 천막 22동이 날아간 뒤 개막식 취소·철거 사례와 특보 없이 집중호우가 온 야간 달리기를 지자체·경찰이 중단·추적/귀가 조치한 사례를 반영함. 11.2m/s를 자동취소선으로 쓰지 않고 최대순간 관측·임시시설·야간/산악·연락/철수체계 필요 근거로 사용함.
- 같은 매뉴얼의 열대야 당시 30℃ 야간 마라톤에서 시작 40분 만에 28명 탈진·조기종료 사례와, 특보가 없어도 체감온도 33℃/35℃에 주의보/경보에 준한 운영대책을 이행하도록 한 지침을 반영함. 30·33·35℃를 모든 관람/공연의 참석금지선으로 쓰지 않고 활동강도·직사광선·그늘/쉼터·물/휴식·의료·취약성을 분리함.
- 2024-05-05 광주·전남 호우·강풍 때 누적 90~134.5mm, 시간당 최고 28.5mm가 관측되고 행사가 실내변경·축소·취소된 실제사례를 반영함. 같은 날도 주최자·프로그램별 결정이 달랐으므로 특정 강수량을 전국 행사 취소선으로 전용하지 않음.
- 주최/운영·설치/철거·출연/선수·능동참가·입석/좌석관람·보호자 역할, 설치부터 귀가까지 전체 일정, 무대/천막·드론/불꽃·산/수면·경사/잔디, 인원/입퇴장·대피/쉼터/급수/의료·교통, 공식 날씨와 직접현장정보를 입력으로 받도록 함.
- 판단 순서는 `공식 행사상태/통제·대피 → 공식 기상사실/행동요령 → 법정/행사별 안전계획 → 역할·전체 일정 → 행사특성별 영향 가능성 → 공식 운영을 벗어나지 않는 비지배안 → 직접경험/갱신`으로 제안함. 공식 취소·통제·대피 중에는 대체 참석 후보를 만들지 않음.
- 공식 행사상태/통제·행사별 안전정보·계획, 임시시설/젖은 노면·낙뢰·더위/추위·대기/퇴장 영향 가능성, 낮은 노출 후보·직접경험·정보부족 상태를 제안함. `EVENT_CAN_PROCEED/CANNOT_PROCEED`, `EVENT_SAFE/UNSAFE`, `ATTEND_RECOMMENDED/FORBIDDEN`, `BEST_EVENT_TIME`, `EVENT_RISK_SCORE`, `AUTO_CANCEL_EVENT`는 만들지 않음.
- 직접관찰에 햇볕 아래 긴 줄·그늘 부족·천막/배너 흔들림·고인 물·질척한 잔디·미끄러운 계단, 옷이 등에 달라붙고 끈적함·화끈거림·갈증/어지러움·손발시림/떨림, 실제 변경문자·대기/입퇴장·셔틀/귀가를 추가함. 직접사실은 확정하고 돌풍·구조불량·온열질환·인파사고·기상원인은 자동확정하지 않음.
- 서버·Flutter에서 야외행사 전용 결과 타입·생성규칙·데이터 계약·문구 매핑은 확인되지 않음. 일반 야외주의로 대체하지 않고 행사 Provider의 공식 상태/대상·역할/전체일정·구역/시설·대피/교통과 기상 객체 위치·신선도를 분리하는 신규 계약을 제안함.
- `현재 미연결 출력의 근거자료 선정 항목`에 `야외행사 일정과 현장정보` 행을 추가하고 새 외부·사용자 직접 데이터 분류에 행사 공식 운영/통제·안전계획·역할/전체일정·현장/대피/교통정보를 반영함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-19는 사용자 미확정 권장안이며 확정 전에는 다음 6-20 `수면환경 관리`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-19 및 검토 6-20: 수면환경 관리

- 사용자의 `확정 후 다음`에 따라 6-19 `야외행사 진행 가능 여부` 권장안을 최종 채택함. 사용자 결과명 `야외행사 일정과 현장정보`, 주최자·관계기관의 운영/통제·대피와 공식 기상 발표/관측 확정형, 앱의 시설·노면·낙뢰·더위/추위·대기/귀가 영향 가능성형, 행사별 계획 우선과 단일 진행점수/공통 취소선 금지 원칙을 유지함.
- 다음 6-20 `수면환경 관리`를 기상청 열대야·2026년 열대야주의보, 국내 아파트 침실 실측, 여름 온열챔버, 겨울 온풍난방·이불 속 환경, 수면 전후반 온도제어, 한국인 발 보온 연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 결과명은 `잠자리 환경과 밤 날씨 비교`로 제안함. 공식 열대야주의보 발표·발효·해제와 관측된 열대야, 공식 밤 예보/관측은 확정형으로, 앱의 덥고 습함·끈적함·침구 열·손발시림·건조·답답함·빛/소음 영향과 조절 후보는 가능성형으로만 표시함.
- 기상청 열대야는 전날 18:01~다음 날 09:00 야외 최저기온 25℃ 이상인 관측 통계임을 반영함. 2026년 열대야주의보는 일최고체감온도 33℃ 이상 2일 지속 예상과 지역별 밤최저기온 일반 25℃·대도시/해안/도서 26℃·제주 27℃ 조건을 함께 쓰는 공식 특보이므로 앱이 자체 계산하지 않고 실제 발표·발효만 확정 표시하도록 함.
- 서울·인근 여성 24명 침실 현장연구에서 온도·복사온도·습도·CO2·빛·소음과 수면호흡을 함께 측정했고 계절·연령별 반응이 달랐음을 반영함. 겨울/봄 다수 침실 평균 CO2 1,000ppm 초과와 계절 평균값은 현장 관찰이지 최적값·수면불편·환기명령 경계가 아님.
- 20~22세 여성 5명의 여름 챔버 연구가 제안한 28.1℃ 상한은 실제 침실온도 필요성의 보조근거로만 사용하고 전 연령의 쾌적/불쾌선으로 쓰지 않음. 겨울 난방연구의 방 평균 22.7℃와 침구 온습도, 수면효율 차이도 표본·통계적 한계를 보존하고 권장 설정값으로 전용하지 않음.
- 수면 전후반 별도 제어 연구를 근거로 고정 21~04시를 폐기하고 실제 취침·각성·기상 시간선을 받도록 함. 한국인 젊은 남성 6명의 양말 연구는 같은 방 환경에서도 의복·말초 보온과 주관/객관 반응이 다를 수 있다는 근거로만 사용하고 양말 또는 효과크기를 일반 권고로 만들지 않음.
- 입력을 공식 밤 날씨, 실제 수면창, 침대/머리 높이 근처 온습도·복사열·CO2·빛/소음·기류와 센서 위치/신선도, 냉난방/환기·제습/가습 운전, 침구/잠옷·동침, 개인맥락과 직접 체감/수면결과로 분리함. 외기만 있으면 실내·수면상태를 추정하지 않고 정보부족으로 남김.
- 판단 순서는 `공식 발표/관측 → 실제 수면창과 침실측정 → 환경요인별 비교 → 제어/침구·전후반 연결 → 직접기록 → 상충하는 조절후보 → 개인기준 갱신`으로 제안함. 단일 최적 온습도·수면점수·숙면보장·질환진단을 만들지 않음.
- 공식 열대야주의보·관측열대야·밤 날씨, 수면창·침실측정·제어/침구기록, 덥고 습한 침실·침구 열·손발시림·건조·답답한 공기·빛/소음·조절상충 가능성, 직접 수면반응·정보부족 상태를 제안함. `SLEEP_DISCOMFORT_EXPECTED`, `SLEEP_GOOD/BAD`, `OPTIMAL_SLEEP_TEMPERATURE`, `GOOD_SLEEP_SCORE`, `INSOMNIA_RISK`는 만들지 않음.
- 체감기록에 후끈함, 등/목 축축함, 피부와 이불이 달라붙어 끈적함, 눅눅한 베개, 이불을 걷어참, 손발시림, 얼굴에 닿는 찬 바람, 목·코·피부 건조, 공기 답답함, 빛/소음, 실제 잠든 시간·각성·조절·아침 느낌을 추가함. 직접사실은 확정하고 날씨·습도·CO2·냉난방과의 인과는 자동확정하지 않음.
- 현행 서버는 고정 21~04시 외기온 25℃ 이상·외기습도 75% 이상이 3시간 연속이면 `SLEEP_DISCOMFORT_EXPECTED` 점수 70을 만들고 실내 온습도 조절을 명령함. 이는 기상청 열대야/열대야주의보 정의도, 국내 수면연구의 검증된 침실 경계도 아님.
- 현행 로직은 실내센서·실제 수면창·복사열/CO2/빛/소음·냉난방/환기·침구/직접반응을 받지 않고, 대체 템플릿의 체감온도 하강도 근거가 없음. Flutter 전용 수면 타입 매핑도 없어 일반 야외주의로 대체될 수 있음.
- 제품화 전 외기 기반 `SLEEP_DISCOMFORT_EXPECTED`와 점수 70을 비활성화하고 공식 야간 기상·사용자 수면창·침실환경·제어/침구·직접반응의 전용 계약과 Flutter 표시를 추가하도록 제안함. `현재 미연결 출력` 표와 새 외부·사용자 데이터 분류에도 반영함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-20은 사용자 미확정 권장안이며 확정 전에는 다음 6-21 `냉방·난방 권고`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-20 및 검토 6-21: 냉방·난방 권고

- 사용자의 `확정 후 다음`에 따라 6-20 `수면환경 관리` 권장안을 최종 채택함. 사용자 결과명 `잠자리 환경과 밤 날씨 비교`, 공식 열대야주의보·관측열대야와 밤 예보/관측 확정형, 앱의 덥고 습함·끈적함·침구 열·손발시림·건조·답답함·조절후보 가능성형, 실제 수면창/침실측정 우선과 외기 기반 단일 수면점수·최적온도 금지 원칙을 유지함.
- 다음 6-21 `냉방·난방 권고`를 국민안전24 폭염 행동요령, 한국에너지공단 2025년 절약 캠페인, 질병관리청 2025년 온열질환·2025~2026절기 한랭질환 감시, 국내 주거 냉방행동·겨울 온열환경·개인 열민감도·에너지빈곤 실측, 연령별 추위반응과 소방청 냉난방기 화재·일산화탄소 안전자료 및 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 결과명은 `실내 온도와 냉난방 방법 비교`로 제안함. 공식 기상·재난 행동요령, 에너지 절약 캠페인, 공급/정전·시설점검·제품 안전안내와 실내센서/사용자 직접기록은 출처·위치·시각을 붙여 확정형으로 표시함.
- 앱의 실내 더위·끈적한 더위·추위·건조한 난방감·직접기류 불편·방별 불균형·냉난방/환기 대안과 피해 영향은 모두 `~수 있어요·가능성이 있어요·도움이 될 수 있어요`로 제한함. 실외기온만으로 실내상태·냉난방 필요·온열/한랭질환을 확정하지 않음.
- 국민안전24의 폭염 시 실내 26~28℃ 유지·실내외 차이 5℃ 내외 안내는 일반 국민행동요령으로 표시함. 한국에너지공단의 여름 26℃·겨울 20℃는 에너지 절약 캠페인 목표이므로 두 숫자 모두 보편적 건강·쾌적 경계나 에어컨/난방 자동설정값으로 전용하지 않음.
- 질병관리청의 2025년 온열질환자 4,460명·사망 29명 중 실내 발생 926명(20.8%)·집 237명과, 2025~2026절기 한랭질환자 364명·사망 14명 중 실내 91명·집 62명을 반영함. 실내에서도 피해가 발생했다는 공식 감시결과로 사용하되 특정 실내온도·냉난방 설정·개인 발생확률을 역산하지 않음.
- 국내 여름 아파트 연구에서 냉방 가동 시작 시 평균 공기온도 29.76℃·SET* 28.89℃, 정지 시 27.31℃·23.70℃가 관찰된 결과는 실제 행동자료로만 사용함. 거주자의 선택이 관찰된 값이지 앱 공통 가동/정지선이나 건강 경계가 아님.
- 국내 겨울 아파트 20가구의 실내온도 21.2~27.2℃·상대습도 19.5~58.8%와 중립~약간 따뜻한 응답, 11가구 실측의 열민감도 0.356/K, 에너지빈곤 23가구의 냉방지원 여부별 여름 실내온도 차이를 개인차·주거/비용·설비조건 분리 근거로 사용함. 작은 표본·특정 주거집단의 수치이므로 전국 최적온도·불쾌선·지원효과로 일반화하지 않음.
- 19℃ 환경에서 젊은 여성 11명·고령 여성 12명의 반응을 비교한 연구는 같은 실내온도에서도 연령·말초감각·의복 반응이 다를 수 있다는 보조근거로만 사용함. 19℃를 고령자 안전/위험선이나 난방 시작점으로 사용하지 않음.
- 2021~2025년 냉방기기 화재 2,184건·사망 31명·부상 136명과 2021~2023년 전기난로·전기장판 화재 1,403건·사망 21명·부상 142명, 소방청의 일산화탄소 예방안내를 반영함. 기기 작동·이상징후·공식 점검/회수는 사실로, 과열·화재·CO 노출 영향은 앱 가능성형으로 분리하고 긴급상황은 공식 신고/대피안내를 우선함.
- 입력을 공식 안내/서비스, 공간·재실·활동, 방별 실내 온습도·복사열·기류와 센서 위치/신선도, 냉난방 종류·설정/가동·성능, 공급/비용·접근성, 환기/대기질, 연령·건강/약물·의복, 직접 체감과 기기 이상징후로 분리함. 실내측정이 없으면 외기에서 실내값을 추정하지 않고 정보부족으로 남김.
- 판단 순서는 `공식 긴급/서비스·안전안내 → 실제 방별 측정 → 재실자·취약맥락 → 기기/설정과 측정값 → 비지배 대안 → 환기·비용·안전 상충 → 직접반응 재확인`으로 제안함. 한 숫자·합산점수로 냉방과 난방을 명령하지 않음.
- 공식 실내기후/에너지/서비스 안내, 실내측정·냉난방 운전기록, 더위·끈적함·추위·건조·직접기류·방별 불균형·냉방/난방/환기 대안·연소난방 CO 노출 가능성, 직접반응·정보부족 상태를 제안함. `COOLING_REQUIRED`, `HEATING_REQUIRED`, `SET_AC_TO_26`, `SET_HEATING_TO_20`, `INDOOR_SAFE/DANGEROUS`, `OPTIMAL_INDOOR_TEMPERATURE`, 온열/한랭질환 개인위험 판정은 만들지 않음.
- 체감기록에 공기가 후끈함·피부/옷이 달라붙어 끈적함·열이 안 빠지는 느낌, 손발시림·찬 기운·외풍, 목/코/피부 건조·얼굴에 닿는 바람·방마다 다른 느낌, 기기 소음/냄새·플러그/코드 열·CO 경보기 작동과 조절 뒤 변화를 추가함. 직접사실은 확정하고 습도·단열·기기고장·화재·CO 등 원인은 자동확정하지 않음.
- 현행 서버는 외기 체감온도 33℃ 이상 연속슬롯 또는 35℃ 이상 즉시 더위, 외기온 12℃ 이하·체감온도 10℃ 이하 연속슬롯으로 추위 규칙을 만들지만 실내 온습도·방/재실·냉난방 종류/운전·환기·비용·안전 입력과 전용 냉난방 결과는 없음. Flutter의 체감온도 라벨도 냉난방 설정과 연결할 근거가 없음.
- 실내 계약과 안전입력이 마련되기 전에는 기존 실외 더위/추위 규칙을 냉방·난방 명령으로 확대하거나 원격제어에 연결하지 않도록 제안함. `현재 미연결 출력` 표와 새 외부·사용자 데이터 분류에 `실내 온도와 냉난방 방법 비교`를 반영함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 6-21은 사용자 미확정 권장안이며 확정 전에는 7장 첫 항목 `안전·관심·주의·경고·위험 단계`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 6-21 및 검토 7-1: 공식 위험정보와 앱 안내 상태

- 사용자의 `확정 후 다음`에 따라 6-21 `냉방·난방 권고` 권장안을 최종 채택함. 사용자 결과명 `실내 온도와 냉난방 방법 비교`, 공식 기상/재난·에너지/서비스/기기안내와 실내측정·직접기록 확정형, 앱의 더위·끈적함·추위·건조·기류·방별 불균형·대안/피해 가능성형, 26~28℃·실내외 5℃와 여름 26℃·겨울 20℃의 목적 분리 및 외기 기반 자동설정 금지 원칙을 유지함.
- 다음 7-1 `안전·관심·주의·경고·위험 단계`를 기상청 현행 영향예보·특보, 에어코리아 통합대기환경지수, 산림청 산사태 위기경보, 현행 재난문자 운영규정과 2026년 중복저감 운영결과, 위기경보 명칭 혼동 공식 문제제기, 국립기상과학원 참여 영향예보 평가연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 결과명은 `공식 위험정보와 앱 안내 상태`로 제안함. 기상청 영향예보의 `관심·주의·경고·위험`은 공식 폭염·한파 분야별 단계로만 확정 표시하고 앱 자체 단계명으로 재사용하지 않음.
- 기상특보의 예비특보·주의보·경보/중대경보, 기상청 영향예보 4단계, 산림청 등 위기경보의 관심·주의·경계·심각, 에어코리아의 좋음·보통·나쁨·매우 나쁨, 재난문자의 위급·긴급·안전안내를 기관 원문 상품으로 각각 보존함. 같은 단어가 있어도 서로 번역·서열비교·최고단계 합산하지 않음.
- 기상청 영향예보는 현재 폭염·한파를 대상으로 지역 취약성·노출과 분야별 영향을 고려하고 보건 분야 관심 이상 예상 시 전일 11:30 발표함. 일반/취약·보건/산업·시설물 등 분야를 지역 단일단계로 합치거나 외기값·앱 점수에서 공식 단계를 재산출하지 않음.
- 국립기상과학원 참여 2018년 연구의 한국 165개 지역·4×4 위험행렬, 예측 저온편향과 보정 필요, 온열질환 사망/이환 검증을 공식 영향단계가 단순 선형점수가 아님을 보여주는 근거로 사용함. 2021년 지역차 개선 사례의 해안/내륙 차등기준과 기존 적색 과대산출 감소·추가평가 필요성도 전국 공통 임의 단계 금지 근거로 반영함.
- 행정안전부 2017년 자료가 단계명 이해 어려움과 `심각`의 피해정도 오해를 공식적으로 지적한 사실을 반영해 단계명만 표시하지 않고 기관·현상·분야·지역·시각·행동요령을 함께 표시함. 오래된 공모자료는 현행 단계 변경 근거로 쓰지 않음.
- 2025년 10월부터 일부 지역에서 재난문자 중복 사전검토를 시범운영해 6개월간 기상특보 관련 중복문자가 80% 이상 감소했고 2026년 5월 전국 확대된 운영결과를 반영함. 같은 공식정보는 묶되 단계·지역·유효시간·행동 변경은 변경점이 드러나도록 갱신함.
- 앱 내부는 피해·안전 등급이 아니라 `NO_ADDITIONAL_GUIDANCE_FOUND`, `INFORMATION_REVIEW_POSSIBLE`, `PREPARATION_REVIEW_POSSIBLE`, `PLAN_ADJUSTMENT_REVIEW_POSSIBLE`, `OFFICIAL_IMMEDIATE_ACTION_SHOWN`, `DIRECT_EMERGENCY_OBSERVATION_RECORDED`, `GUIDANCE_DATA_INSUFFICIENT`, `OFFICIAL_STATUS_CHANGED` 같은 안내 라우팅 상태로 제안함.
- 사용자 화면에는 `추가 안내 없음·정보 확인·미리 준비·조정 검토·즉시 확인·정보 부족`을 사용함. `정보 확인→미리 준비→조정 검토`는 피해확률/심각도의 서열이 아니며 `즉시 확인`은 공식 대피/통제/사용중지·119 안내 또는 사용자 직접 긴급사실이 있을 때만 사용함.
- `특보 없음`, `점수 임계 미만`, `예보 없음`, `센서값 임계 미만`, `데이터 없음`을 `안전`으로 바꾸지 않음. 기관의 안전점검 완료·통제해제·정상운영이나 사용자 직접관찰은 대상·시각 범위에서만 확정하고 전체 활동 안전으로 확장하지 않음.
- 공식 발표/발효/해제, 관측/측정, 사용자 직접관찰·기기경보는 확정형으로 보존함. 앱의 영향·피해·불편·준비/조정 효과는 모두 `~수 있어요·가능성이 있어요·도움이 될 수 있어요`로 제한함.
- 블랙아이스(도로살얼음)는 공식 도로관측·관리기관 발표가 있으면 확정 표시하고 기온·수분·그늘 조건만 있으면 형성 가능성으로만 표시함. 도로 전체의 안전/위험 단계로 단정하지 않음.
- `officialStatuses[]`, `appGuidanceState`, `evidenceKind`, `actionTiming`, `confidenceAndQuality`, `changeSet`으로 계약을 분리함. 현행 공통 `level`은 deprecated 내부 필드로만 남기고 UI·알림·우선순위·색상·공식문구의 근거로 사용하지 않도록 제안함.
- 판단 순서는 `공식 원문 상품/단계/행동 → 관측·예보·직접사실 구분 → 기능별 채택근거와 사용자 노출 → 앱 안내상태 → 공식 즉시행동/직접긴급 우선 → 중복제거·변경점 갱신`으로 제안함. 현상 간 브리핑 우선순위는 7-8·7-9에서 별도 정함.
- 서버 `recommendationLevel()`은 서로 다른 점수를 40/70/90/95로 잘라 INFO/CAUTION/WARNING/DANGER를 생성함. 자외선×10, PM 농도/합, 습도/100-습도, 풍속×10, 강수확률/강수량 배수와 고정 생활점수가 같은 척도가 아니므로 공통 피해단계로 사용할 근거가 없음.
- 같은 score가 priority·level·일부 알림자격·TODO 중요도에 재사용되고 폭설만 별도 가중됨. 위험수준·표시순서·알림긴급성·준비물 중요도를 7-2 이후 항목에서 각각 분리하도록 제안함.
- 서버 `WeatherWarning` 계약은 최소필드만 있고 공식 영향예보의 분야/지역/원문행동 표시경로가 확인되지 않으며 `providerRefs`는 실제 근거와 무관하게 KMA로 고정됨. Flutter는 서버 level/score/reasons/providerRefs를 파싱하지 않고 홈 지표에 별도 `안전·주의·위험` 3단계를 사용함.
- 제품화 전 공통 `recommendationLevel()`과 화면 `안전` 라벨을 사용자 위험판정에서 비활성화하고 공식 원문상태·근거종류·앱 안내상태·행동시점·데이터품질·변경점을 전용 타입으로 표시하도록 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-1은 사용자 미확정 권장안이며 확정 전에는 다음 7-2 `점수 산정 방식`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-1 및 검토 7-2: 공식 수치와 앱 판단 근거

- 사용자의 `확정 후 다음`에 따라 7-1 `안전·관심·주의·경고·위험 단계` 권장안을 최종 채택함. 사용자 결과명 `공식 위험정보와 앱 안내 상태`, 공식 단계/상품 원문 보존, 앱의 `정보 확인·미리 준비·조정 검토·즉시 확인·정보 부족` 라우팅 분리, 특보/점수/데이터 없음의 안전판정 금지와 내부 영향 가능성형 원칙을 유지함.
- 다음 7-2 `점수 산정 방식`을 기상청 강수확률 정의·예보검증, 에어코리아 CAI 공식 산식, 기상청 자외선·생활기상지수, 안전보건공단 위험성평가, 국립기상과학원 참여 영향예보 연구, 서울·전국 폭염 건강영향 연구, 행정안전부 지역안전지수와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 결과명은 `공식 수치와 앱 판단 근거`로 제안함. 앱이 자외선·강수·기온·바람·대기질·생활판정을 합친 사용자용 `0~100 위험점수`나 개인 피해확률을 만들지 않도록 함.
- 강수확률은 유사 기상상황에서 지정 장소·예보기간 중 강수가 발생할 가능성, CAI는 6개 오염물질의 구간별 공식지수·최댓값·다중오염 가산, 자외선지수는 복사량 지수와 0~2/3~5/6~7/8~10/11+ 단계임. 공식 원값·단위·원등급을 보존하고 서로 100점으로 정규화·합산·비교하지 않음.
- 같은 기상청 생활기상정보 안에서도 자외선은 5단계이고 식중독지수는 별도 모델과 55·71·86 경계를 사용함. 기관 내부의 서로 다른 공식 지수도 산식·대상·행동이 다르므로 한 지수의 점수컷을 앱 공통단계로 복사하지 않음.
- 안전보건공단 위험성평가는 사업장의 유해·위험요인별 발생가능성·중대성을 추정해 감소대책을 세우는 절차이며 3×3 곱셈은 예시이고 덧셈·행렬·3/5단계 등 사업장별 방법을 허용함. 이를 전 생활날씨의 국가 공통 가능성×중대성 산식으로 전용하지 않음.
- 국립기상과학원 참여 폭염 영향예보 연구의 4×4 행렬은 한국 165개 지역, 확률·건강영향·예측편향 보정과 온열질환 사망/이환 검증을 포함함. 앱의 `체감온도×2.5`, `습도 +10` 같은 임의 산식으로 공식 영향단계를 재현하지 않음.
- 서울 2011~2018년 연구에서 온열질환 이환·사망을 서로 다른 결과로 분석해 30℃·33℃ 임계와 수준별 다른 AUC를 얻은 결과, 전국 229개 시군구 연구의 도시/농촌·연령/원인별 차이를 결과정의·지역·집단별 검증 필요 근거로 사용함. 연구 집단통계를 개인 건강위험점수로 쓰지 않음.
- 행정안전부 지역안전지수도 전년도 통계로 6개 분야 지자체 안전역량을 동일 행정단위 안에서 상대평가하는 연간 등급임. 1등급을 오늘 특정 위치·사람의 안전점수로 전용하지 않음.
- 앱 판단계약을 `sourceMetric`, `ruleEvaluation`, `appGuidanceState`, `dataQuality`, 선택적 `modelEstimate`로 분리함. 공식 원값, 규칙 충족/미충족/판단불가, 안내상태, 데이터 신선도/결측, 실제 검증모델 확률이 같은 score 필드로 섞이지 않도록 함.
- 규칙평가는 `MATCHED | NOT_MATCHED | UNKNOWN`으로 제안함. 조건충족·미충족은 입력과 규칙에 대한 사실로 확정 기록하고 생활 영향·준비/조정 효과는 가능성형으로 표시함. 결측·충돌·시공간 불일치는 `UNKNOWN`이며 0점·미충족·안전으로 대체하지 않음.
- 기온℃·습도%·풍속m/s·강수확률%·강수량mm·UV·PM·공식등급의 합/평균/최댓값을 금지함. 체감온도에 이미 반영된 습도/바람을 +10으로 재가산하거나 고령/질환/장시간에 임의 가중치를 붙이지 않음.
- 공식 대피·통제·운휴·리콜·119 안내와 사용자 직접 긴급사실은 점수계산 없이 공식/긴급 경로로 우선함. 사용자 직접반응은 확정된 경험으로 보존하되 한 번의 결과를 다음 상황의 효과점수·성공/사고확률로 만들지 않음.
- 실제 확률모델은 관측 가능한 결과정의, 모집단·지역·계절·선행시간, 학습/검증기간·표본수, 시간분리 외부검증, 보정도와 Brier/log loss·민감도/특이도/AUC, 버전·한계를 모두 갖출 때만 `eventProbability`로 허용함. 검증 전에는 modelEstimate를 비우고 가능성형 규칙문구만 제공함.
- 허용 숫자는 `강수확률 60%`, `자외선지수 8.4·매우높음`, `PM2.5 42㎍/㎥`, `실내 29.4℃·72%`처럼 이름·단위·출처·시각이 있는 원값과 공식등급임. `오늘 위험도 87점`, `산책 안전점수 72점`, `건강위험 65%`, `사고확률 40%`, `신뢰도 90점`은 결과정의·검증 없이 만들지 않음.
- 현행 서버는 `WeatherRuleFact.severity → LifestyleInsight.score → Recommendation.priority/level/score`를 한 축으로 연결하고 40/70/90/95에서 공통단계를 만듦. 자외선×10, PM 농도/합, 습도/100-습도, 추위 `100-체감`, 풍속×10, 강수량 배수와 고정 55~80이 같은 단위가 아님.
- 에어코리아 CAI와 달리 서버는 PM10+PM2.5를 100에서 자르며, 체감온도 35℃는 단일 스냅샷 경로에서 35점이지만 시간열 경로에서는 ×2.5 또는 90점이 될 수 있음. 같은 값이 `/today`와 timeline에서 다른 점수·단계가 될 수 있는 구조를 기록함.
- 습도/바람이 반영된 체감온도에 습도·강풍 +10을 다시 더하고, 같은 타입의 최고 score만 남겨 시공간 근거를 지우며, score가 단계·정렬·알림·TODO 중요도에 재사용됨. 실제 결과자료로 검증되지 않은 중복가산·최고값·고정가중을 제거하도록 제안함.
- 제품화 전 severity/score 전파와 공통 단계변환을 비활성화하고 `sourceMetric + ruleEvaluation + appGuidanceState + dataQuality + 선택적 modelEstimate`로 교체함. 표시순서·색상·준비물·알림은 이후 항목에서 목적별로 별도 정함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-2는 사용자 미확정 권장안이며 확정 전에는 다음 7-3 `색상 단계`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-2 및 검토 7-3: 출처와 의미를 함께 보여주는 색상

- 사용자의 `확정 후 다음`에 따라 7-2 `점수 산정 방식` 권장안을 최종 채택함. 공식 원값·단위·원등급 보존, `MATCHED | NOT_MATCHED | UNKNOWN`, 단일 0~100 위험/안전점수·개인 피해확률·서로 다른 단위 합산 금지, 결측의 판단불가 처리와 내부 영향 가능성형 원칙을 유지함.
- 다음 7-3 `색상 단계`를 에어코리아 CAI 공식 색상, 기상청 영향예보, 재난 및 안전관리 기본법의 위기경보, 국내 모바일/웹 접근성 지침, 국내 고령자 색지각 연구, 재난안전분야 안전디자인 가이드와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자·설계 결과명은 `출처와 의미를 함께 보여주는 색상`으로 제안함. 색상은 새 위험단계나 점수가 아니라 7-1의 공식 원상태와 앱 안내역할을 구분하는 표현수단으로 한정함.
- 에어코리아 CAI의 `좋음=파랑 #0000FF`, `보통=초록 #00FF00`, `나쁨=노랑 #FFFF00`, `매우나쁨=빨강 #FF0000`을 해당 공식상품 안에서만 보존함. 초록 `보통`을 앱 전체 `안전`, 노랑/빨강을 다른 현상의 주의/위험으로 바꾸지 않음.
- 기상청 영향예보·기관 위기경보 등은 기관·상품·원단계·원색상·지역/분야·시각을 함께 표시함. 공식 명세에 RGB가 없으면 화면에서 추출하거나 `주의=노랑·경고=주황·위험=빨강`을 앱이 추정하지 않음.
- 국내 모바일 접근성 지침의 색과 무관한 인식·전경/배경 구분·다중 알림 원칙, KWCAG 2.2의 일반 텍스트 4.5:1과 큰 글자 3:1, 테두리/무늬/간격 구분을 Flutter 설계 수용기준으로 반영함.
- 국내 고령자 색지각 연구에서 인접색 지각은 흑색/순색량 5%, 색상 혼합비 10% 이상 차이, 순간가독은 흑색/순색량 10%·혼합비 20% 이상 차이에서 관찰되고 노랑계열이 더 흐릿했다는 결과를 반영함. 이를 RGB 임계로 직접 전용하지 않고 색만으로 단계구분 금지와 고령자 실제기기 검증 근거로 사용함.
- 색상 계약을 `officialVisual`, `appSemanticTone`, `appGuidanceState`, `dataQualityVisual`, `accessiblePresentation`으로 분리함. 공식 원색과 앱 디자인토큰은 별도 namespace와 버전으로 관리하고 score/level에서 색을 계산하지 않음.
- 앱 역할색은 중립표면 `추가 안내 없음`, 청회색 `정보 확인`, 황갈색 `미리 준비/조정 검토`, 회색 점선 `정보 부족`, 제한된 빨강 `공식 즉시 안내/직접 긴급기록`으로 제안함. 초록은 앱 안전판정에 쓰지 않고 준비→조정을 노랑→주황 수직단계로 만들지 않음.
- 빨강 강조는 공식 대피·통제·사용중지·119 같은 즉시행동 또는 사용자의 CO/화재경보기 등 직접 긴급기록에만 허용함. 내부 가능성 계산으로 빨강에 진입하지 않고 `공식 즉시 안내`와 `직접 긴급기록`을 출처·아이콘·라벨로 분리함.
- 현재 팔레트 상대휘도 계산에서 `primaryDeep/primarySoft 5.84:1`, `attentionDeep/attentionSoft 5.73:1`, `danger/white 4.91:1`을 확인함. `attention/attentionSoft 3.32:1`, `textSecondary/white 4.05:1`은 작은 텍스트 4.5:1에 미달하므로 장식 제한 또는 더 어두운 텍스트토큰이 필요함.
- 공식 밝은 원색 위에 흰 글씨를 얹지 않고 원색은 견본/테두리로 보존하며 상태명은 별도 고대비 표면에 표시함. 라이트/다크·고대비·색각이상·회색조·200% 글자확대·스크린리더와 모든 실제 전경/배경 조합을 검증하도록 함.
- Flutter `_MetricRisk`는 습도·풍속·UV·PM을 `safe/caution/danger/unavailable`로 공통 재분류함. 자외선 8 `매우높음`과 PM2.5 76 `매우나쁨`이 모두 앱 `위험`으로 바뀌고 임계 안쪽은 `안전`으로 표시돼 7-1·7-2와 충돌함.
- 서버의 score 40/70/90/95→INFO/CAUTION/WARNING/DANGER 및 Flutter TODO score 60/80→청회색/황갈색 연결을 색상근거로 사용하지 않음. 추천 카테고리가 같은 중립 팔레트를 쓰고 아이콘/문구로 구분하는 방향은 유지하되 공식·앱·결측 전용 구성요소를 새로 둠.
- 블랙아이스(도로살얼음)는 도로관리기관의 공식 관측/안내가 있으면 출처·시각과 확정 표시하고, 기온·수분 조건만 있으면 황갈색 앱 역할카드에서 형성 가능성으로만 표시하도록 색상 예시에도 반영함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-3은 사용자 미확정 권장안이며 확정 전에는 다음 7-4 `준비물 중요도`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-3 및 검토 7-4: 출발 전에 살펴볼 준비 항목

- 사용자의 `확정 후 다음`에 따라 7-3 `색상 단계` 권장안을 최종 채택함. 공식 원색과 앱 역할색·데이터 품질표시 분리, 앱 초록 안전판정 금지, 빨강의 공식 즉시행동/직접 긴급기록 제한, 색 외 라벨·아이콘·테두리와 작은 텍스트 4.5:1 대비 원칙을 유지함.
- 다음 7-4 `준비물 중요도`를 기상청 낙뢰·대설 행동요령, 질병관리청 2025년 대상별 온열질환 예방 매뉴얼과 실제 온열질환 감시결과, 에어코리아 일반/계층별 행동요령, 국민안전24 비상용 생활필수품 및 앞서 채택한 6-1~6-6과 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 목록 제목은 유지하되 사용자 화면명은 `출발 전에 살펴볼 준비 항목`, 판단개념은 `준비 시점과 대안`으로 제안함. 품목 자체에 상·중·하, 필수·권장·선택, 0~100점의 고정 중요도를 부여하지 않음.
- 공식 요구/행동요령, 사용자가 등록한 의료진·보호자·본인 계획, 앱 내부 준비 가능성, 직접 준비/사용기록, 정보부족을 별도 상태로 분리함. 공식 사실과 직접기록은 확정형, 앱의 준비·대체·효과 판단은 모두 가능성형으로 제한함.
- 기상청 낙뢰 행동요령이 외출 시 우의를 준비하고 낙뢰 때 우산 같은 긴 물건을 멀리하도록 안내한 점을 반영해 강수 시 우산을 무조건 최우선으로 두지 않음. 우의·실내경로·안전한 장소와 낙뢰/강풍 상충을 함께 표시함.
- 기상청 대설 행동요령의 보행자 신발·장갑·일정조정/대중교통과 운전자 월동장구·체인·염화칼슘·삽·연료·비상식량을 이동수단별로 분리함. `폭설 주의`는 준비물 하나가 아니며 공식 통제·운휴는 7-1 즉시행동 경로로 보냄.
- 질병관리청 온열지침의 물·시원한 장소·가벼운 옷/모자/양산·휴식/활동조정 묶음과 신장·심장·혈압 관련 질환자의 의료진 상담 구분을 반영함. 2025년 8월 21일까지 3,815명, 전년 같은 기간 3,004명의 1.26배라는 실제 피해는 준비 안내의 배경으로만 쓰고 개인확률·물병 점수로 환산하지 않음.
- 에어코리아의 마스크·물·야외활동 조정, 올바른 마스크 착용과 이상증상 시 중지, 질환자의 처방 응급약/의료진 계획 구분을 반영함. 마스크·약·물의 공통 순위를 만들지 않고 제품상태·맞음새·실제 야외노출·개인계획을 따로 확인함.
- 국민안전24의 장기 비축품·유효기간·비상가방 안내는 가정 비축/대피맥락으로 분리하고 매일의 날씨 준비목록 상위에 자동 노출하지 않음.
- 판단축을 `근거 역할, 실제 노출구간, 마지막 행동시각, 준비·접근 상태, 대체수단/상충, 개인·제품 제약, 데이터 품질`로 분리함. 전역 점수합산 없이 공식/개인계획, 출발 전 확인, 이동 중 접근·대체, 준비됨, 정보 더 필요 묶음으로 표시함.
- 상태는 `OFFICIAL_REQUIREMENT_SHOWN`, `OFFICIAL_GUIDANCE_ITEM_SHOWN`, `PERSONAL_PLAN_ITEM_SHOWN`, `PREPARE_BEFORE_DEPARTURE_REVIEW_POSSIBLE`, `ACCESS_OR_SUBSTITUTE_REVIEW_POSSIBLE`, `READY_RECORDED`, `IN_USE_RECORDED`, `PREPARATION_DATA_INSUFFICIENT`, `NO_ADDITIONAL_PREPARATION_FOUND`로 제안함.
- 우산/우의/실내경로, 양산/모자/그늘/복장, 선크림 첫 적용/재적용/제품접근, 마스크/활동조정/개인계획, 물병/급수/휴식/그늘, 겉옷/장갑/마른 옷, 대설 이동수단별 장비를 목적별 대안 묶음으로 보존함. 하나를 무조건 최고 또는 최선으로 선택하지 않음.
- 같은 물건도 목적·시간이 다르면 `candidateId + purpose + exposureWindow + actionDeadline`을 보존함. 사용자가 하나의 물건으로 여러 후보를 충족할 수 있음을 연결하되 서버가 타입별 최고점 하나만 남기지 않도록 함.
- 계약을 `preparationCandidate`의 근거역할, 노출구간, 행동마감, 준비상태, 접근/대체/상충, 개인제약, 제품상태, 데이터품질, 직접기록으로 제안함. `priority/score/HIGH·MEDIUM·LOW/앱 required/recommended`는 제거하고 알림자격·알림설정은 7-5에서 별도 결정함.
- 직접기록은 최소 `UNKNOWN/AT_HOME_RECORDED/PACKED_RECORDED/ACCESS_VERIFIED/USED_RECORDED/UNAVAILABLE_RECORDED`와 일정·날짜·목적·항목·기록시각을 가져야 함. `챙김`, `접근 가능`, `사용`, `효과`를 서로 추정하지 않음.
- 현행 서버는 score를 priority/level로 바꾸어 정렬하고 대설 100점, 타입별 최고점, 알림설정 연동 recommended, KMA 고정 providerRefs를 사용함. Flutter는 근거·대안·상충·마감·품질을 파싱하지 않고 타입만 키로 한 메모리 체크와 고정 상태문구를 사용함.
- 현행 `필요한 것만 모았어요`, `오늘은 특별히 챙길 준비물이 없어요`와 TODO의 score 60/80·상위 세 개·무조건 물 기본값은 결측과 사용자 제약을 숨길 수 있어 제거하도록 제안함. `추가 후보를 찾지 못했어요`는 전체 안전/준비 불필요를 뜻하지 않게 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-4는 사용자 미확정 권장안이며 확정 전에는 다음 7-5 `알림 발송 기준`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-4 및 검토 7-5: 어떤 변화를 알림으로 받을지

- 사용자의 `확정 후 다음`에 따라 7-4 `준비물 중요도` 권장안을 최종 채택함. 사용자 화면명 `출발 전에 살펴볼 준비 항목`, 품목 고정 상·중·하/점수 금지, 공식·개인계획·앱 가능성·직접 준비/사용·정보부족 분리, 실제 노출/행동마감·준비/접근·대안/상충·개인제약·품질 판단축을 유지함.
- 다음 7-5 `알림 발송 기준`을 2026년 현행 재난문자방송 기준 및 운영규정과 별표 발송요청 고려요건, 행정안전부 2026년 중복검토 전국 확대 결과, 기상청 날씨알리미/위치정보 정책과 재난문자 정책연구, 국내 재난문자 요구사항 KCI 연구·2025년 폭염 재난문자 학위연구, 2025년 광주·전남 집중호우 반복문자 사례, Android/FCM/Apple 권한 및 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 설정명은 `어떤 변화를 알림으로 받을까요`로 제안함. 일반 앱 푸시는 국가 재난문자방송이나 기상청 공식 강제푸시가 아니므로 `날씨챙겨 긴급재난문자`처럼 가장하지 않고 발행기관·원상품·지역·시각을 명시함.
- 공식 새 발표/발효/관측/통제/해제 또는 행동·지역·유효시각의 의미 있는 변경은 확정형으로, 앱 준비·활동 후보는 실제 일정/노출·행동마감·실행가능 대안·유효데이터·새 의미를 모두 확인한 뒤 가능성형으로만 알림 후보를 만듦.
- `알릴 내용의 자격(contentEligibility)`, `사용자/OS의 전달 허용(deliveryAuthorization)`, `실제 전달 결과(deliveryOutcome)`를 분리함. 화면노출·알림자격·허용·성공을 `recommended`나 `notificationEligible` boolean 하나로 합치지 않음.
- 현행 공식 규정의 위험성·확산성·시급성·유일성·대중성 적합요소와 빈도성·기지성·관련성·부분성 제한요소를 반영함. 이를 앱 점수표나 국가 발송자격으로 복사하지 않고 시공간 관련성·행동가능성·중복·대상범위·대체채널을 독립 확인하는 근거로 사용함.
- 2025년 10월부터 시범운영한 유사·중복 사전검토가 기상특보 관련 중복문자를 최근 6개월간 80% 이상 줄였고 2026년 5월 전국 확대된 결과를 반영함. 과거 발송의 사건·지역·대상·행동·유효시각과 새 `changeSet`을 비교하고 의미가 같으면 억제함.
- 기상청 날씨알리미의 현 위치 기반 중요정보와 사용자 선택 정보/시각 구분, 상세정보·행동요령 연결을 참고함. 날씨챙겨는 현재/저장/일정 위치와 위치동의 범위를 분리하고 정부/기상청 채널의 대체물이 아닌 사용자가 선택한 보조채널로 둠.
- 기상청 정책연구가 수신 후 행동·신뢰/긴급성·만족·피로 없는 수용성·지자체/민간 중복·선호채널을 함께 평가한 점을 반영함. 열람률만 품질지표로 쓰지 않고 관련성·행동가능성·출처신뢰·중복·거부·실제 준비/조정 결과를 출시 후 측정함.
- 2005~2020년 뉴스를 분석한 KCI 연구가 경보음·내용·기준·빈도·속도·수신범위·시간·언어 문제, 특히 내용·빈도·범위 개선요구를 확인한 결과를 반영함. 특정 하루 횟수나 쿨다운 숫자를 역산하지 않음.
- 2025년 20대/60대 폭염문자 설문에서 구체성·신속성·관련성·신뢰성과 피로·위험지각·행동의도의 관련성, 특히 관련성의 큰 설명력이 보고된 점을 위치·일정·행동마감·변경이유 표시 근거로 사용함. 단일 학위논문의 연령 효과를 개인 가중치로 쓰지 않음.
- 2025년 광주·전남 기록적 호우 이틀간 400건 이상 반복문자가 보도된 실제사례를 기관별 사실은 보존하되 같은 행동은 변경요약 한 번으로 묶는 근거로 사용함. 공식 통제·대피 대상이나 행동이 다르면 합치지 않음.
- 내용자격은 `OFFICIAL_CHANGE_RELAY_ELIGIBLE`, `APP_ACTIONABLE_GUIDANCE_ELIGIBLE`, `SCHEDULED_DIGEST_ELIGIBLE`, `IN_APP_ONLY`, `NOTIFICATION_DATA_INSUFFICIENT`, `SUPPRESSED_SEMANTIC_DUPLICATE`, `SUPPRESSED_ALREADY_ACTED`, `SUPPRESSED_ACTION_WINDOW_PASSED`로 제안함.
- 알림자격 판단순서는 `출처/사건 → 현재 유효성 → 시공간/대상 관련성 → 행동가능성 → 의미 변경 → 중복/묶음 → 사용자 선택/OS권한 → 7-6 시각판단`으로 제안함. 수치 1 변화·수집시각 갱신·동일 원문의 재수집은 새 의미로 보지 않음.
- 공식 단계·통제·지역·시각·행동, 앱 후보의 노출구간·마감·선택지, 사용자 일정/위치 변경이 실제 행동을 바꾸면 새 알림을 재평가함. 공식 해제도 행동이 바뀌는 범위에서 전달할 수 있지만 전체 안전으로 확대하지 않음.
- 사용자 설정을 `앱 알림 사용(UNSET/허용/거부)`, `공식정보 변경 전달`, `출발 전 준비 확인`, `일정 조정 확인`, `정기 날씨 브리핑`, `현재/저장/일정 위치`, `잠금화면 개인정보`로 제안함. 품목토글은 생활후보 필터일 뿐 화면후보를 숨기지 않음.
- 앱 설정·목적설정·OS권한·토큰 중 하나라도 없으면 푸시하지 않고 화면정보는 유지함. 누락설정을 true로 대체하거나 공식 보조푸시로 사용자 거부를 우회하지 않으며, 건강계획·정확한 일정/위치는 잠금화면에서 기본 숨김 처리함.
- 중복키를 source event/episode, source version/발행시각, 지역/대상, 공식행동/앱목적, 노출구간, 행동마감, 결정버전의 semantic hash로 제안함. 원문 철자/공백 변화가 아니라 사용자 행동의 `changeSet`을 비교함.
- 고정 하루횟수·쿨다운은 근거 없이 채택하지 않음. 의미중복은 항상 억제하고 실제 공식행동 변경은 같은 날에도 재평가함. 기술 무한루프용 circuit breaker는 운영가드로 분리하고 정확값은 부하시험/운영자료로 정함.
- 알림 계약을 source event, 위치/대상 일치, 노출/행동마감, 내용자격/이유, 변경점, semantic key, 품질, 앱동의·목적/지역·OS권한·토큰 snapshot, 개인정보표시로 구성함. 전달이력은 queued/providerAccepted/deviceDelivered/displayed/opened/expired/failed를 구분함.
- 7-5는 eligibleFrom/actionDeadline/latestUsefulDeliveryAt까지만 전달하고 실제 즉시·사전·브리핑/야간 처리와 시각은 다음 7-6에서 정함.
- 현행 서버는 겉옷만 score 70으로 알림자격을 가르고 나머지를 사실상 true로 두며, builder는 notificationEligible/목적설정을 무시하고 대설을 고정 IMPORTANT, 나머지를 MORNING_BRIEF로 묶음. 7-2~7-5와 충돌함.
- 스케줄러는 존재하지 않는 `installations.notification_enabled` 열을 조회하고 저장된 notification_time을 사용하지 않음. Cloudflare Cron은 UTC인데 현재 07:00/05:10 UTC는 16:00/14:10 KST이며 사용자 07:00 설정과 무관함.
- `/today` 화면조회 뒤 전체 설치 알림작업을 실행하고, recommendation 조회/FCM send는 placeholder/no-op인데도 발송이력을 남길 수 있음. 예보수집·결정·사용자별 예약/큐·전달 Worker를 분리해야 함.
- notification_history는 발송 전 중복조회 없이 `INSERT OR REPLACE`하며 payload_hash도 본문 앞 80자라 사건·지역·버전/행동을 식별하지 못함. 원자적 idempotency 선점과 전달단계별 이력이 필요함.
- Flutter 설정은 local demo/fallback 전체 true이고 서버 저장이 연결되지 않음. `firebase_messaging`, Android POST_NOTIFICATIONS, 토큰/권한·전경/배경 처리도 없어 현재 실제 푸시 수신경로는 없음. 앱과 서버의 알림항목 스키마도 불일치함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-5는 사용자 미확정 권장안이며 확정 전에는 다음 7-6 `즉시 알림과 사전 알림 구분`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-5 및 검토 7-6: 즉시 알림과 사전 알림 구분

- 사용자의 `확정 후 다음`에 따라 7-5 `알림 발송 기준` 권장안을 최종 채택함. `알릴 내용의 자격`, `사용자·OS의 전달 허용`, `실제 전달 결과` 분리, 공식 새 사실/변경의 확정형, 앱 내부 생활판정의 가능성형, 의미중복 억제와 명시동의 원칙을 유지함.
- 다음 7-6 `즉시 알림과 사전 알림 구분`을 기상청 2026년 5단계 호우 대응체계, 2026년 첫 재난성호우 긴급재난문자 실제 발송, 특보 발표/발효 시각, 기상청 재난문자 효과 정책연구, 국내 재난유형별 발송 적절성 연구, 날씨알리미 현상별 선행기술과 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 기상청 2026년 체계의 최대 2~3일 전 발생가능성, 예비특보·주의보·경보, 관측 기반 긴급재난문자를 별도 단계로 보존함. 2~3일과 해제예고 3~6시간을 생활알림 공통 선행시간으로 복사하지 않음.
- 2026년 7월 17일 22시 10분 대구 수성구 지산1동에서 시간당 100 mm 수준 강우가 관측돼 첫 재난성호우 긴급재난문자가 발송된 사례를 공식 즉시행동은 정기 브리핑으로 미루지 않는 근거로 반영함. 제3자 앱의 야간 보조푸시는 별도 명시동의와 OS 상태를 지키며 국가 CBS와 혼동하지 않음.
- 기상청 정책연구에서 호우문자 수신 후 외출·이동 변경, 우회, 시설점검 등이 나타났고 다수가 5분 이내 행동한 결과를 반영함. 5분은 수신 뒤 행동결과이지 앱의 `5분 전` 사전알림값이 아니므로 전용하지 않음.
- 국내 `재난유형별 재난문자 발송의 적절성 연구`에서 호우·폭설 같은 예측 가능한 재난은 관련성, 순간 재난은 긴급성이 발송 적절성 인식에 중요했던 결과를 반영함. 예보형 앱 알림은 위치·일정·행동가능성을 요구하고 돌발 공식 즉시행동은 긴급성을 보존함.
- 날씨알리미의 레이더 1시간 강수예측과 우박 45분 선행시간은 각 공식 탐지·예측 상품의 특성으로 보고 전 생활항목의 고정 `1시간/45분 전`으로 복사하지 않음.
- 발송시각 경로를 `OFFICIAL_IMMEDIATE_ACTION_RELAY`, `OFFICIAL_FUTURE_EFFECTIVE_RELAY`, `APP_PRE_ACTION_REMINDER`, `USER_SCHEDULED_BRIEF`, `IN_APP_ONLY_TIMING_UNKNOWN`, `EXPIRED_BEFORE_DELIVERY`로 제안함. 이는 앱 위험등급이 아니라 공식 행동시점·개인 행동창·전달방식을 구분하는 상태임.
- 미래 발효 특보는 수집 직후 발표사실과 발표/발효시각을 확정 전달하고 발효시각에 동일 내용을 자동 반복하지 않음. 별도 사전확인은 실제 사용자 행동마감이 있을 때만 `APP_PRE_ACTION_REMINDER`로 계산함.
- 앱 내부 생활판정은 공식 즉시경로로 승격하지 않고 `도움이 될 수 있어요`, `조정할 수 있어요` 가능성형만 사용함. 공식 원문·통제·관측은 `발표했어요`, `발효한다고 안내했어요`, `관측했어요`, `통제했어요` 확정형으로 보존함.
- 사전시각은 `eventAt`, `actionWindowOpensAt`, `actionDeadline`, `requiredActionDuration`, `desiredDeliveryAt`, `latestUsefulDeliveryAt`, `expiresAt`을 분리함. 사용자 선택·직접기록·공식 운영정보·제품설명 등 출처 없는 공통 30분/1시간을 만들지 않음.
- 우산이 집에 있고 16시 20분 출발이면 16시 20분 행동마감은 확정할 수 있지만 15시 50분 알림은 사용자 여유설정이나 실제 준비소요 근거 없이는 만들지 않음. 현행 빨래 `강수 30분 전` 고정값도 제거 대상으로 기록함.
- 일반 생활 사전알림과 브리핑은 방해금지를 지키고 종료 뒤에도 행동시간이 남을 때만 재계산함. 공식 즉시행동의 야간 보조푸시는 사용자가 별도 허용한 경우에만 시도하고 OS 권한·방해금지를 우회하지 않음.
- 예약은 source event/version, 지역/대상, 일정/목적, 행동마감, timingClass 기반 의미키를 사용함. 공식·예보·일정·직접 준비기록이 행동을 바꾸면 취소·교체하고 수집시각만 바뀌었으면 새 예약을 만들지 않음.
- 큐·Provider 지연 뒤 `latestUsefulDeliveryAt`이나 `expiresAt`을 넘으면 늦은 `지금 챙기세요`를 보내지 않고 만료함. Provider 접수·단말전달·표시·열람·만료·실패를 구분하고 정시전달을 보장한다고 표현하지 않음.
- 계약을 공식 발표/발효/행동/만료시각, 사용자 timezone·일정·노출, 행동창/소요/출처, 희망·마지막유용·만료시각, 방해금지정책, 재예약키, 이유·품질·상태로 제안함. 단일 `scheduled_at`으로 시각을 덮지 않음.
- 현행 `Recommendation`의 validFrom/validUntil/actionDeadline은 builder가 무시하고 대설 `IMPORTANT`/나머지 `MORNING_BRIEF`로 묶음. `WINDOW_CLOSE_SOON`의 고정 30분, UTC 고정 Cron, 미사용 notification_time, 방해금지/TTL/취소·교체 부재가 7-6과 충돌함.
- FCM과 추천조회가 placeholder/no-op인데 sent_at 이력을 남길 수 있고 Flutter 실제 수신·권한 경로와 서버설정이 연결되지 않아 현재 즉시·사전 전달을 보장할 수 없음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-6은 사용자 미확정 권장안이며 확정 전에는 다음 7-7 `브리핑 장면 선택 기준`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-6 및 검토 7-7: 내 일정에 맞는 날씨 브리핑

- 사용자의 `확정 후 다음`에 따라 7-6 `즉시 알림과 사전 알림 구분` 권장안을 최종 채택함. 공식 즉시행동/미래발효 전달, 개인 행동마감 기반 사전확인, 사용자 timezone 브리핑, 야간 별도동의, 지연 시 만료와 고정 30분/1시간 금지 원칙을 유지함.
- 다음 7-7 `브리핑 장면 선택 기준`을 기상청 영향예보의 지역·분야 구분, 단기/초단기예보의 시공간 해상도, 2024년 생활시간조사, 국내 Z세대 상황인식 앱 연구, 기상청 날씨알리미 관심지역/위치기반 서비스, 재난문자 관련성 연구와 2026년 실제 야간 재난성호우 사례, 현행 브리핑 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `내 일정에 맞는 날씨 브리핑`으로 제안함. `장면`은 내부 설계용어이며 `누가, 어디서, 언제, 무엇을 하거나 결정하려는지`가 묶인 실제 생활 에피소드로 정의함.
- 비·눈·미세먼지·더위 같은 기상현상이나 아침·퇴근길 같은 고정 시간대를 곧바로 장면으로 쓰지 않음. 공식 대피·통제·운휴는 생활문구로 각색하지 않고 별도 공식 블록에 확정형으로 표시함.
- 기상청 영향예보가 폭염/한파 영향을 보건·산업·시설·농축산·수산 등 분야와 지역별로 구분하는 점을 반영함. 공식 분야·대상·시각을 보존하고 한 기상값으로 모든 활동장면을 만들지 않음.
- 기상청 단기예보의 5 km 격자·1시간 간격과 초단기예보의 6시간 범위·10분 갱신을 실제 장소구간·시간창과 교차함. 격자와 시각이 세밀해도 개인의 실내외 노출을 증명하는 것으로 보지 않음.
- 2024년 생활시간조사는 전국 1만 2,750표본가구 약 2만 5천 명을 사계절 조사하고 일·학습·가사·돌봄·이동·여가가 연령·요일·취업·가구·지역별로 달랐음. 집단 평균을 개인의 출퇴근·취침 고정시각으로 사용하지 않음.
- 20대 150명 국내 앱 연구에서 시간대보다 외출 전·이동 중·자기 전 같은 상황 차이가 더 중요했고 외출 전 날씨와 교통을 함께 확인한 사례를 실제 일정·목적지·교통 맥락 기반 장면의 보조근거로 사용함. Z세대 연구결과를 전 연령 자동장면으로 일반화하지 않음.
- 기상청 날씨알리미의 현재위치와 사용자 관심지역 구분을 반영해 현재·저장·일정 위치를 합치지 않고, 위치동의가 없으면 저장지역/직접선택만 사용함.
- 장면유형을 `OFFICIAL_ACTION_CONTEXT`, `NOW_AND_NEXT_MOVE_CONTEXT`, `DEPARTURE_ROUTE_CONTEXT`, `SCHEDULED_OUTDOOR_CONTEXT`, `RETURN_OR_LOCATION_CHANGE_CONTEXT`, `HOME_TASK_CONTEXT`, `CARE_OR_DEPENDENT_CONTEXT`, `SLEEP_NIGHT_CONTEXT`, `USER_SELECTED_OVERVIEW_CONTEXT`로 제안함.
- 장면 후보 판단순서는 `앵커 → 주체/목적 → 시공간 에피소드 → 근거 교차 → 결정기회 → 정보품질 → 역할별 문장 → 후보 보존`으로 제안함. 사용자 미허용 캘린더·백그라운드 위치·건강정보를 사용하지 않음.
- 후보상태를 `OFFICIAL_APPLICABLE`, `MATCHED`, `NOT_MATCHED`, `UNKNOWN`, `DIRECT_STATE_RECORDED`, `USER_SELECTED_OVERVIEW`, `NO_CONTEXTUAL_SCENE_FOUND`로 제안함. 결측을 안전/준비불필요로 바꾸지 않음.
- 공식 발표·발효·관측·통제와 사용자 직접 일정/기록은 확정형, 앱 내부 영향·준비·조정·효과는 가능성형으로 분리함. `안심돼요/편안해져요/목적지까지 닿아요` 같은 내부 결과확정 문구를 제거 대상으로 기록함.
- 여러 장면 후보를 동시에 보존하며 같은 비 예보가 귀가와 빨래 회수에 각각 겹치면 목적·행동마감이 다른 후보로 유지함. 7-7에서 하나만 고르지 않고 우선표시는 다음 7-8, 한 장면의 복합위험은 7-9에서 결정함.
- 계약을 scene/eligibility/anchor, 주체·목적·활동, 위치·시간·노출, 공식/관측/예보/내부후보/직접기록, 겹침·결정기회·마감, 출처시각·권한 snapshot·결측/충돌·품질·표현역할·버전으로 제안함. score/priority/color를 포함하지 않음.
- 현행 `selectScene()`은 현재+24시간에서 `눈→비→대기질→체감28℃/UV6→체감8℃→풍속6m/s→DAILY_RHYTHM` 첫 하나를 반환해 후보자격과 우선순위를 섞고 일정·노출·마감이 없음.
- 현재 `WET_TRAVEL` 등은 생활 에피소드가 아니라 기상조건 문구묶음이며 40% 비만으로 우산장면을 만들고 시각만으로 `출근길/퇴근길`을 붙임. 교대근무·휴일·여행·실내일정과 충돌할 수 있음.
- `DAILY_RHYTHM`은 정보가 없어도 산책·외출·바깥시간을 권하고, 템플릿은 준비효과·호흡·도착·안심을 확정함. `USER_SELECTED_OVERVIEW/NO_CONTEXTUAL_SCENE_FOUND`와 가능성형 문구로 교체가 필요함.
- API가 scene/template/slots/version을 버리고 brief 문자열만 반환하며 Flutter도 근거·위치·시간·상태 없이 반복 표시함. 누락 기본문구 `오늘은 덥다가 퇴근할 때 비가 와요`도 임의 장면이므로 데이터 상태로 대체가 필요함.
- 현행 테스트의 정확히 20개 템플릿·슬롯별 10개·47자·7일 회전은 문구 다양성만 검증함. 실제 일정겹침·역할분리·정보부족·여러 후보 보존 검증이 필요함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-7은 사용자 미확정 권장안이며 확정 전에는 다음 7-8 `브리핑 우선순위`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-7 및 검토 7-8: 먼저 확인할 내용

- 사용자의 `확정 후 다음`에 따라 7-7 `브리핑 장면 선택 기준` 권장안을 최종 채택함. 장면을 실제 생활 에피소드로 정의하고 공식 블록 분리, 사용자 선택/일정·시공간·대상·행동기회 기반 후보, `MATCHED/NOT_MATCHED/UNKNOWN`, 다중후보 보존, 공식·직접기록 확정형/내부 가능성형 원칙을 유지함.
- 다음 7-8 `브리핑 우선순위`를 2026년 재난문자 운영규정, 기상청 5단계 호우 대응체계와 첫 재난성호우 실제 발송, 기상청 재난문자 효과 정책연구, 국내 재난유형/폭염문자 연구, 행정안전부 중복감축 결과, VMS 정보순서 연구, 상황인식 앱 연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `먼저 확인할 내용`으로 제안함. `우선순위 95점/가장 위험/1위 준비물` 대신 공식 행동시점·사용자 선택·행동마감·실제 노출로 `왜 먼저 보이는지`를 설명함.
- 브리핑을 전역 점수 한 줄이 아니라 `OFFICIAL_NOW`, `OFFICIAL_UPCOMING_CHANGE`, `FOCUSED_SCENE`, `TIME_BOUNDED_ACTION`, `UPCOMING_EXPOSURE`, `USER_OVERVIEW`의 독립 표시영역으로 제안함.
- 적용 가능한 공식 즉시대피·통제·운휴·현재 관측 기반 행동은 일반 생활장면과 경쟁시키지 않고 화면 맨 위 공식블록에 기관·지역·시각·원행동을 확정형으로 표시함.
- 미래 발효 특보·예비특보·예정 통제/운영변경 중 사용자 행동이 달라지는 새 공식정보는 별도 예정변경 영역에 발표/발효시각과 변경점을 확정 표시함.
- 사용자가 현재 직접 선택·검색·핀한 장면은 일반 자동후보에 밀리지 않게 `FOCUSED_SCENE`에 보존함. 결측이어도 unrelated 장면으로 교체하지 않고 필요한 입력을 설명함. 공식영역은 별도로 위에 유지함.
- 일반 실행후보는 앱 피해추정이 아니라 가장 이른 `latestUsefulDeliveryAt`, 그다음 `actionDeadline`으로 배열하고, 마감 없는 후보는 실제 `episodeWindow.start` 순으로 표시함.
- 공식 단계/행동, 예보 유효시각, 일정/선택지가 실제로 달라졌을 때만 `ACTION_RELEVANT_CHANGE`를 기록함. 단순 수집시각·문구변경·반복횟수는 재배치 근거가 아님.
- 시각까지 같으면 사용자 핀순서, 일정 생성시각, 안정적인 sceneCandidateId를 사용함. 문구회전·랜덤·Provider 응답순서로 카드가 새로고침 때 움직이지 않게 함.
- `SCENE_DATA_INSUFFICIENT`는 전역 최하위로 내리지 않고 사용자 초점장면이면 그 자리에서 부족정보를 표시함. 자동후보 결측은 상세목록에 UNKNOWN으로 보존하며 결측을 낮은 위험/안전으로 바꾸지 않음.
- 같은 의미는 `SUPPRESSED_SEMANTIC_DUPLICATE`, 직접 준비완료는 `SUPPRESSED_ALREADY_ACTED`, 마감경과는 `EXPIRED_BEFORE_PRESENTATION`으로 처리함. 공식 행동변경은 별도 재평가함.
- 제한된 화면에서도 상위 3개 밖의 후보를 삭제하지 않고 영역별 첫 항목·개수와 전체보기로 복원하게 함. 스크린리더 읽기순서도 공식행동→사용자초점→행동마감→다음노출→개요로 고정함.
- 건강·돌봄·정확한 일정은 홈/잠금화면에서 기본 축약하고 상세 인증을 적용함. 개인정보 축약이 표시영역 자체를 삭제하는 근거는 아님.
- displayLane, displayState, priorityReasonCodes, 공식 행동/발효시각, user focus/pin, latestUseful/actionDeadline, episodeWindow, meaningfulChange, 품질/개인정보, 안정키와 이유를 가진 `briefPresentationDecision` 계약을 제안함. priorityScore/현상 weight/개인 피해확률은 저장하지 않음.
- 현행 `selectScene()`은 눈→비→대기질→더위/UV→추위→바람 첫 하나를 반환하고 후보자격과 우선순위를 섞음. 공식영역·사용자초점·행동마감·다중후보가 없음.
- `recommendationPriority.ts`는 대설만 weight 100, 나머지는 80이며 lifestyle 엔진은 같은 타입 중 최고 score만 남겨 score 내림차순 정렬함. 실제 일정·목적·마감이 다른 후보가 사라질 수 있음.
- 서버/Flutter 일별·상세·주간은 slice/take 3을 사용하고 Flutter 메인도 처음 세 개 뒤 무조건 시간확인·물·여유 fallback을 채움. 숨긴 후보와 제외이유를 복원할 수 없음.
- Flutter TODO는 score 80/60으로 high/medium/low 색을 정하고 알림 builder는 대설만 IMPORTANT로 분리함. 화면 배열·알림시각·색상역할을 서로 다른 결정으로 분리해야 함.
- API에는 displayLane/priorityReasonCodes/userFocus/actionDeadline/meaningfulChange/stableTieKey가 없어 Flutter가 먼저 보이는 이유를 설명할 수 없음. 표현 회전과 배열 결정을 분리해야 함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-8은 사용자 미확정 권장안이며 확정 전에는 다음 7-9 `여러 위험이 겹칠 때 우선순위`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-8 및 검토 7-9: 함께 확인할 조건

- 사용자의 `확정 후 다음`에 따라 7-8 `브리핑 우선순위` 권장안을 최종 채택함. 단일 위험점수 대신 공식 즉시행동→공식 예정변경→사용자 초점→행동마감→실제 노출→개요의 독립 표시영역, 의미변경·중복·만료·결측 상태, 가능성형 내부문구 원칙을 유지함.
- 다음 7-9 `여러 위험이 겹칠 때 우선순위`를 2026년 전북 복합재난 연구, 기상청 호우·낙뢰·태풍·강풍 행동요령, 2023년 오송 지하차도 실제 피해와 2026년 통제정보 내비게이션 연계, 2026년 여름철 인명피해 감축대책·선행강우 후 추가피해 지시, 한국산업안전보건공단 위험통제계층과 현행 서버 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `함께 확인할 조건`으로 제안함. 현상별 `주위험/복합점수`가 아니라 공식 행동제약, 공통행동, 행동충돌, 대안과 자료부족을 보여주는 방식임.
- 같은 사용자/대상·일정/경로·시공간 노출·결정목적이 실제로 겹칠 때만 `compoundScene`으로 묶음. 위치·시간·목적이 다르면 별도 7-7 장면으로 보존하고 7-8 표시순서를 적용함.
- 공식 발표·관측·통제, 예보, 앱 가능성, 직접기록을 구성요소별로 분리함. 한 구성요소가 공식이라고 전체 복합장면을 공식 확정형으로 바꾸지 않음.
- 관계상태를 `OFFICIAL_ACTION_CONSTRAINT`, `OFFICIALLY_STATED_CASCADE`, `POSSIBLE_CASCADE`, `SHARED_EXPOSURE`, `ACTION_COMPATIBLE`, `ACTION_CONFLICT`, `COINCIDENT_ONLY`, `RELATION_UNKNOWN`으로 제안함.
- 공식기관이 복합재난·연쇄원인을 발표하지 않은 단순 조건겹침은 앱이 `복합재난 발생`으로 확정하지 않음. 공식 연결은 발표범위만 확정하고 내부 연쇄판단은 가능성형으로만 표시함.
- 적용 가능한 공식 대피·통제·운휴·사용중지·야외활동 중단을 `공식 행동제약`으로 먼저 적용함. 공식 지하차도 통제가 있으면 감속·우산·장비조언보다 통제구간 제외와 공식 우회정보를 확정 표시함.
- 같은 기관·사건의 명시적 정정/해제/대체는 버전으로 연결함. 다른 기관·대상·지역의 행동은 모두 보존하고 실제 충돌이 해결되지 않으면 `OFFICIAL_SOURCE_CONFLICT`로 앱 판단을 중단함.
- 내부 행동후보는 `공식 행동 적용→충돌 사전제외→노출 회피/종료→시간·경로·방법 대체→분리/차단→확인/준비→개인용품→잔여조건` 순으로 검토함. 이는 위험현상 서열이 아니라 행동후보 필터임.
- KOSHA의 제거→대체→공학적→관리적→개인보호구 순서는 일반생활 명령이 아니라 준비물보다 노출회피·대체를 먼저 검토하는 보조원칙으로만 사용함. 사용자 실행가능성·건강/수의사 계획을 모르면 명령형으로 쓰지 않음.
- 낙뢰 행동요령이 태풍·호우 동반 가능성, 외출/야외활동 자제, 우산보다 비옷을 안내하는 점을 대표 행동충돌로 반영함. 비만 보고 우산을 자동추천하지 않고 실내이동/일정조정 공통행동과 비옷 대안을 검토함.
- 호우가 하천범람·산사태·침수를 함께 유발할 수 있고 위험지역 이탈·침수도로/지하차도 진입금지를 안내하는 점을 반영함. 우산·감속 같은 보조행동이 공식 진입금지를 완화하지 않음.
- 2023년 오송 참사의 미호강 제방붕괴·지하차도 침수와 14명 사망·16명 부상, 이후 2026년 통제정보/우회경로 내비게이션 연계를 운전장면에서 실제 통제를 수치보다 먼저 적용하는 근거로 반영함.
- 2026년 정부가 선행강우·산사태/산불피해지·저지대·지하차도·홍수/침수를 함께 관리한 점을 반영해 현재 한 시간값만 보지 않고 선행조건·장소취약성·통제상태를 별도 보존함. 선행강우만으로 개인 위치 피해를 확정하지 않음.
- 해결상태를 `OFFICIAL_ACTION_APPLIES`, `COMMON_ACTION_AVAILABLE`, `COMPATIBLE_ACTION_SET`, `ALTERNATIVES_REQUIRED`, `OFFICIAL_SOURCE_CONFLICT`, `COMPOUND_DATA_INSUFFICIENT`, `NO_COMPOUND_ACTION_NEEDED`로 제안함.
- 계약을 구성요소별 evidenceRole/source/시각/겹침/품질, 구성요소 관계와 근거, 공식 행동제약, 행동별 도움/악화 가능 구성요소·공식/사용자계획 충돌·행동창, 공통행동·잔여조건·제외이유·미해결충돌로 구성함. combinedRiskScore/primaryHazardByWeight/damageProbabilitySum은 저장하지 않음.
- 현행 `selectScene()`은 눈→비→대기질→더위/UV→추위→바람 첫 하나만 반환하며 복합 구성요소와 관계가 없음. `WeatherRuleFactType`에도 낙뢰·홍수·산사태·공식 통제/운휴가 없고 activeWarnings로 기관·지역·원행동을 복원할 수 없음.
- `lifestyleBuilder`는 더위+습도/추위+강풍에 +10, 더위+UV에 max를 쓰며 `COMMUTE_RISK`는 비+바람 또는 블랙아이스(도로살얼음)를 단일 점수/문구로 덮음. 서로 다른 근거·행동충돌을 복원할 수 없음.
- 추천엔진은 비를 곧바로 UMBRELLA로 매핑하고 낙뢰 구성요소가 없어 우산/비옷 충돌을 검사하지 못함. 우산·양산·선크림 공존 주석 뒤에도 타입중복 제거만 있고 공통행동/상충 검사는 없음.
- 빨래 적합에서 비·강풍을 제외하고 BEST_OUTING_WINDOW에서 필수값·특보 부재를 요구하는 개별가드는 보수적 출발점이나 전 장면의 공식제약·충돌·결측을 일관되게 처리하지 못함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-9는 사용자 미확정 권장안이며 확정 전에는 다음 7-10 `시간대 구분`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-9 및 검토 7-10: 정확한 시간과 친화적 시간대

- 사용자의 `확정 후 다음`에 따라 7-9 `여러 위험이 겹칠 때 우선순위` 권장안을 최종 채택함. 현상별 복합점수 대신 공식 행동제약→행동충돌 제외→공통 노출회피/대체→보조 준비→잔여조건의 행동 필터, 구성요소별 근거역할, 미해결충돌/결측 상태와 가능성형 내부문구 원칙을 유지함.
- 다음 7-10 `시간대 구분`을 기상청 현행 예보용어해설·단기예보 시간단위/요소별 슬롯 의미·시간범주 개선자료, 통계청 2024 생활시간조사, 한국천문연구원 일출일몰 계산, 국내 상황인식 앱 연구와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 핵심은 정확한 현지 날짜·시각/범위를 먼저 표시하고 친화적 시간대명은 보조로 붙이는 것임. `아침·밤`만으로 생활행동·일조·노출·피해를 판단하지 않음.
- 앱 자체 `clockBand`는 기상청 8등분을 따라 `새벽 00~03`, `늦은 새벽 03~06`, `아침 06~09`, `오전 09~12`, `낮 12~15`, `늦은 오후 15~18`, `저녁 18~21`, `밤 21~24`로 제안함. 내부 interval은 시작포함·종료미포함 `[start,end)`로 처리함.
- 사용자 화면에는 `아침(오전 6~9시)`처럼 범위를 함께 표시함. 자정·정오·다음 날 자정을 명시하고 24:00 단독표현을 피함.
- 공식 예보용어는 2등분 `오전 00~12/오후 12~24`, 4등분 `새벽 00~06/오전 06~12/오후 12~18/밤 18~24`, 8등분을 모두 사용할 수 있어 `오전/밤` 단어만으로 앱 구간을 추정하지 않음. 공식 원라벨·원범위를 확정형으로 보존함.
- 공식 `자정 무렵` 등은 원문과 기관의 불확실성을 보존함. 앱이 정확한 1시간값을 임의로 넓히거나 불확실한 예보를 분단위로 정밀화하지 않음.
- 단기예보는 1시간 단위지만 같은 19시에도 기온·체감·바람·습도는 정시값이고 날씨·강수량 등은 이전 1시간을 가리킬 수 있어 `POINT_IN_TIME/PREVIOUS_INTERVAL/VALID_INTERVAL`을 필드별로 저장하도록 함.
- 통계청 2024 생활시간조사의 평균 기상 06:59·취침 23:28과 연령·평일/주말 차이를 반영해 집단평균을 개인의 기상·취침·출퇴근 시각으로 사용하지 않음.
- `출근길/등굣길/귀가/산책/취침 전·중`은 사용자 직접 일정·선택이 있을 때만 사용함. 05~09·17~20 같은 시계구간만으로 통근을 만들지 않음.
- `지금`은 현재시각이 자료 유효구간 안에 있고 신선도·역할이 확인될 때만, `곧`은 절대시각과 남은 시간을 함께 표시할 때만 사용함. 오래된 상대문구를 저장해 재사용하지 않음.
- `오늘/내일`은 선택 지역 timezone의 00:00 경계로 나누고 `앞으로 24시간`과 구분함. 자정을 넘는 사건은 하나로 보존하되 `오늘 밤 11시~내일 오전 2시`처럼 두 날짜를 표시함.
- 일출·일몰은 한국천문연구원 날짜·위치별 자료를 별도 `SUN_EVENT`로 사용함. clockBand `낮 12~15/밤 21~24`를 실제 일조·어둠으로 확정하지 않음.
- 시간역할을 sourceIssuedAt, officialEffectiveWindow, observedAt/interval, forecastValidWindow, userEpisodeWindow, actionWindow/deadline, presentationNow, sunEvent로 분리함. 하나의 eventAt/observedAt에 발표·발효·관측·예보·일정을 합치지 않음.
- 원시 instant/interval은 UTC로 정규화하면서 sourceTimezone, offset, IANA timezone, 원문시각을 보존함. 기상청 국내자료는 Asia/Seoul/KST(+09:00), 화면은 선택 날씨지역 현지시각을 기본으로 하고 단말/일정 timezone이 다르면 구분함.
- 사용자 일정은 일정 timezone을 보존해 UTC에서 예보와 겹침을 계산하고 문자열 `slice(11,13)`로 현지시각을 결정하지 않음. 핵심 시간정보가 없거나 충돌하면 TIME_CONTEXT_INSUFFICIENT/TIMEZONE_CONFLICT로 남김.
- 계약을 원시간역할/원문, UTC instant/interval과 intervalSemantics, source/presentation timezone·offset, 현지 날짜/시각·날짜교차, clockBand/공식라벨/장면관계/sunEvent/상대표현 계산시각, 발표·관측·예보·발효·행동창, 정밀도·불확실성·신선도·결측/충돌로 구성함.
- 현행 `timeSlotIndex()`는 `<6,<8,<10,<12,<14,<16,<18,<20,<22`로 자르고 출근길/퇴근길을 자동부여하며 기상청 구간·사용자 일정·timezone과 맞지 않음.
- `localHour()`는 ISO 11~13번째 문자열을 그대로 사용하고 commute 05~09/17~20, day 10~16, night 21~04로 고정함. 생활행동·공식 시간범주·일조상태가 혼용됨.
- `buildTimeline()`은 배열 0/3/6/9/12번째와 observedAt을 사용하고 06~18 이외를 실제 일정 없이 `귀가 날씨 확인하기 좋은 때`로 표시함. forecastAt/validFrom과 역할분리가 필요함.
- KMA Provider는 +09:00을 보존하지만 snapshotEnd의 `-1ms`와 `:59:59` 닫힌구간, 필드별 정시/이전1시간 의미 미분리가 남아 있음.
- 설치 timezone과 notificationTime은 저장되지만 규칙/브리핑/notification builder가 사용하지 않음. Flutter도 ISO substring 또는 UTC+9 직접가산을 사용해 KST 이외 offset과 일정 timezone을 처리하지 못함.
- 테마/fallback의 `오후부터 필요`, `아침저녁에 추천`, `오후·저녁 예상`, `퇴근할 때 비`는 실제 유효구간·일정 없이 시간과 행동을 확정하므로 정확 범위·상태 기반으로 교체가 필요함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-10은 사용자 미확정 권장안이며 확정 전에는 다음 7-11 `연속 발생 인정시간`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-10 및 검토 7-11: 이어지는 구간

- 사용자의 `확정 후 다음`에 따라 7-10 `시간대 구분` 권장안을 최종 채택함. 정확한 현지 날짜·시각/범위 우선, 기상청 3시간대 보조라벨, 공식 원시간범주 보존, 사용자 일정과 일출일몰 분리, `[start,end)`·timezone·시간역할 분리 원칙을 유지함.
- 다음 7-11 `연속 발생 인정시간`을 기상청 현행 예보용어·발표간격/갱신주기·ASOS 시간해상도/QC·특보 통보/해제예고, 국내 강우사상 분리 연구와 현행 서버 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `이어지는 구간`으로 제안함. 모든 현상에 공통인 90분/3시간/6시간 허용공백은 두지 않고 같은 조건·근거역할·위치의 활성 interval이 겹치거나 정확히 맞닿을 때만 연속으로 인정함.
- 확인된 비활성 구간, 결측·오류, 출처충돌, 위치·요소 시간의미 변경에서 조건 run을 끊음. 결측은 비활성 0도 지속활성도 아닌 `UNKNOWN_GAP`으로 보존함.
- 공백 뒤 재활성은 새 `CONDITION_RUN`으로 저장함. 같은 사용자 일정·경로에 관련되면 하나의 `DECISION_EPISODE`에서 간헐구간으로 함께 보여줄 수 있으나 `계속`으로 합치거나 첫 시작~마지막 종료를 activeDuration으로 세지 않음.
- 공식 특보·통제의 발표→변경/연장→해제 사슬은 `OFFICIAL_STATE_EPISODE`로 별도 보존함. 공식 발효상태가 이어진 사실을 강수·바람 등 기상현상이 매분 연속 발생한 사실로 바꾸지 않음.
- 해제예고는 예상시간이며 연장되거나 조기해제될 수 있어 실제 공식 해제 통보 전에는 공식 상태를 종료하지 않음. 해제 뒤 새 발표는 짧은 간격이어도 새 공식 에피소드로 분리함.
- 기상청 `한때`는 예보대상 구간 안에서 연속 1회, `가끔`은 띄엄띄엄 여러 번이라는 원의미를 보존함. 상세 슬롯이 없으면 앱이 정확한 시작·종료·공백을 임의로 만들지 않음.
- 초단기예보의 1시간 간격과 10분 갱신주기, 별도 10분 강수량 자료를 구분함. 같은 유효시각의 응답 갱신을 새 활성슬롯이나 반복발생으로 세지 않음.
- ASOS가 분·시간·일 등 여러 해상도와 QC 오류/결측을 제공하는 점을 반영해 `2슬롯`을 공통 지속시간으로 쓰지 않음. minimumActiveDuration이 필요한 현상은 실제 interval 합집합의 분 수로 판단함.
- 서울 강우·유출 연구가 IETD에 국내 일관값이 없다고 정리하고 서울 연구의 10~13시간을 근거로 10시간을 사용한 반면, 부산·목포 일강우 분해 연구는 IETD 1일을 사용한 점을 확인함. 연구용 강우사상 분리값을 현재 비의 연속발생·전국 생활알림·다른 현상에 전용하지 않음.
- 시간의미 정규화→같은 비교축 확인→현상별 활성 interval 생성→접촉/겹침 병합→공백상태 분류→activeDuration/wallClockSpan 분리→공식/생활 연결→7-12 해제평가 위임 순으로 제안함.
- `POINT_IN_TIME` 관측 여러 개는 관측시점만 확정 표시하고, 기관이 유지구간을 제공하거나 공인 집계의 interval을 복원할 수 없으면 그 사이를 자동 채우지 않음.
- 상태를 `OFFICIAL_ACTIVE_CHAIN`, `CONTINUOUS_INTERVALS_CONFIRMED`, `INTERMITTENT_INTERVALS_CONFIRMED`, `POINTS_ONLY_CONTINUITY_UNKNOWN`, `UNKNOWN_DATA_GAP`, `SOURCE_CONTINUITY_CONFLICT`, `OFFICIAL_RELEASED`, `NEW_OFFICIAL_EPISODE_AFTER_RELEASE`, `TIME_CONTEXT_INSUFFICIENT`로 제안함.
- 계약에 evidenceRole/location/criterionVersion, 공식 사건·통보문 사슬, intervalSemantics·source/update cadence, 활성 interval과 gap, 조건/생활/공식 에피소드 참조, activeDuration·wallClockSpan, 상태·결측·충돌·다음 해제평가를 포함함. globalAllowedGapMinutes와 공통 consecutiveSlotCount는 두지 않음.
- 현행 `timeWindows.ts`는 모든 run에 시작시각 차이 90분을 공통 적용해 1시간 슬롯 사이 30분 무자료도 연결할 수 있음. active가 된 hysteresis run은 이후 trigger의 인접성을 검사하지 않아 몇 시간 뒤 값도 같은 run에 추가될 수 있음.
- 현행 `generalSlots=2`, `laundrySlots=3`, 환기 2슬롯, 습도 3슬롯은 자료해상도가 바뀌면 지속시간이 달라지며, `factForRun()`은 중간공백 없이 첫 시작~마지막 종료 하나로 덮음. 타입별 최고 severity만 남겨 분리 run도 유실될 수 있음.
- `snapshotEnd()`의 기본 1시간 `-1ms`, KMA Provider의 `:59:59`는 `[start,end)`와 다르고 점자료까지 1시간 지속으로 만들 수 있음. Provider 요소별 시간의미에 따른 interval 복원이 필요함.
- 현행 강수 테스트는 10·11시 활성, 12시 해제후보, 13시 재활성을 하나의 10:00~13:59:59 fact로 기대함. 간헐·결측·장시간 재활성·점관측·공식 해제/재발표 시나리오가 필요함.
- 공식 발표·발효·관측·통제 및 사용자 직접기록은 그 사실을 확정형으로, 예보사실은 `예보했어요`로 표시함. 앱 내부 피해·불편·활동영향은 `이어질 수 있어요/두 구간에 겹칠 수 있어요` 가능성형으로만 제안함.
- 블랙아이스(도로살얼음)는 도로관리기관의 시점별 관측·통제사실만 확정 표시하고, 두 시점 사이 지속은 공식 근거가 없으면 확정하지 않음. 기온·수분 조건이 끊겨 있으면 형성 가능성도 두 구간으로 표현함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-11은 사용자 미확정 권장안이며 확정 전에는 다음 7-12 `판정 해제 기준`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-11 및 검토 7-12: 안내 상태

- 사용자의 `확정 후 다음`에 따라 7-11 `연속 발생 인정시간` 권장안을 최종 채택함. 공통 허용공백 없이 같은 조건·근거역할·위치의 유효 활성 interval이 겹치거나 맞닿을 때만 연속으로 인정하고, 결측·비활성·충돌 뒤 재발동은 별도 run으로 보존하는 원칙을 유지함.
- 다음 7-12 `판정 해제 기준`을 기상청 특보 해제예고/통보문, 대기환경보전법·에어코리아 미세먼지/오존 해제기준, 2026년 국내 호우특보 해제 뒤 대응유지 사례, 국내 블랙아이스(도로살얼음)·실내습도 연구와 현행 서버 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `안내 상태`로 제안함. `공식 해제됨`, `조건 완화 확인 중`, `잔류 가능성 확인 중`, `일정 종료로 알림 마침`, `새 자료 필요`를 분리하고 `주의 끝/이제 안전/피해 없음/마음 놓아도 돼요`를 쓰지 않음.
- `OFFICIAL_STATE`, `FORECAST_WINDOW`, `OBSERVED_CONDITION`, `DERIVED_IMPACT_POSSIBILITY`, `USER_DECISION_EPISODE`, `ACTION_REMINDER`, `DATA_USABILITY`를 각각 다른 해제대상으로 제안함. 하나의 isReleased/isSafe boolean으로 합치지 않음.
- 공식 특보·대기오염경보·통제·대피·운휴·재개는 해당 기관의 실제 해제·취소·단계하향·재개 발표와 적용구역·시각만 확정 표시함. 해제예고 도달, 관측값 하락, 예보 만료, 자료 미수신으로 앱이 공식 상태를 먼저 해제하지 않음.
- 에어코리아 기준에서 PM10 주의보는 150㎍/㎥ 이상 2시간 발령 뒤 100 미만 해제, PM2.5는 75 이상 2시간 발령 뒤 35 미만 해제이며 경보 하향기준도 별도임. 오존주의보도 0.12ppm 이상 발령과 0.1ppm 미만 해제가 비대칭이므로 공통 2슬롯·진입경계 역조건을 사용하지 않음.
- 2026년 7월 19일 호우특보가 모두 06시에 해제된 뒤에도 침수·토석류/낙석·대피자·추가 산사태 우려 때문에 중앙재난안전대책본부가 대응을 유지한 사례를 반영함. 호우특보 해제가 통제·대피·복구·잔류피해 가능성의 자동 종료가 아님.
- 국내 블랙아이스(도로살얼음) 연구가 기온·노면온도·수분·이슬점·재결빙·서리/안개·일사/그늘·제설상태의 시계열을 함께 사용한 점을 반영함. 비·눈 종료나 대기기온 한 번 상승만으로 블랙아이스(도로살얼음) 형성 가능성을 해제하지 않음.
- 국내 욕실 습도연구가 공간별 기저습도와 회복구간을 사용한 점을 반영해 샤워 뒤 30분/제습기 2시간 같은 공통 타이머로 실내 고습·눅눅함 가능성을 종료하지 않음.
- 내부 해제는 활성판정과 같은 criterionVersion/대상/위치에서 현상별로 이미 채택한 별도 releaseBoundary와 실제 minimumReleaseDuration을 유효하고 연속된 자료가 충족할 때만 후보로 전환함. 현상별 근거가 없으면 임의 `-1℃/-2m/s/-10%/2슬롯`을 만들지 않고 `RELEASE_CRITERION_NOT_ESTABLISHED`로 둠.
- 완화 확인 중 결측·오류·오래된 캐시·출처충돌이 끼면 해제 timer를 완료하지 않고 `DATA_UNKNOWN_HOLD/SOURCE_CONFLICT_HOLD`로 전환함. 다시 진입조건이 나타나면 `REACTIVATED_BEFORE_RELEASE`로 후보를 취소함.
- 복합 내부판정은 각 원인조건과 잔류상태를 따로 확인함. 원인 기상입력이 끝나도 침수·낙석·파손·젖은 노면/재료·실내 열축적은 공식 현장정보·센서·사용자 직접기록 등 별도 근거가 없으면 `RESIDUAL_CONDITION_PENDING`으로 보존함.
- 일정 종료·취소·경로변경은 해당 사용자 장면/알림만 종료하고 지역의 공식·기상상태와 다음 일정은 유지함. 행동완료는 직접기록 사실만 확정하고 행동효과·피해방지·안전을 확정하지 않음.
- `releaseEffectiveFrom`, `releaseConfirmedAt`, `presentationEndedAt`을 분리함. 완화구간 시작, 근거충족 확인, 화면/알림 종료가 같은 시각일 필요가 없음.
- 상태를 공식활성/해제/하향, 자료구간종료/새버전대체, 내부완화후보/확인, 잔류확인, 사용자일정종료/행동완료, 재발동, 자료결측/출처충돌, 해제기준미채택으로 제안함.
- `releaseDecision` 계약에 해제대상·근거역할·공식 사건/통보문·진입/해제경계·완화 interval·세 해제시각·구성/잔류조건·사용자 장면/행동·신선도/품질/결측/충돌을 포함함. `isSafe/releasedBecauseMissing/globalReleaseSlots/officialReleasedByApp/allImpactsCleared`는 저장하지 않음.
- 현행 `findHysteresisRuns()`는 기본 releaseLength=2 슬롯을 모든 현상에 적용하고, 해제에 사용된 슬롯과 해제시각/이유를 버리며 현재활성/과거종료도 구분하지 못함. 중립·결측·품질오류도 동일하게 처리됨.
- 현행 규칙은 강수 POP<30+강수량없음, 눈 비눈아님+적설없음, 더위 체감<31℃, 추위 기온>14℃·체감>12℃, 강풍<4m/s, 자외선<5 또는 문자열 17시 이후를 해제조건으로 하드코딩했으며 국내 근거·지역·계절·자료시간의미와 연결되지 않음.
- `WeatherWarning`에 공식 사건·통보문 lifecycle이 없고 `activeWarnings.length===0`은 해제와 미제공을 구분하지 못함. PM 결측을 0으로 바꾸고 기간 최고 severity만 유지하며 UV 최대 8시간/AQ 최대 3시간 stale 캐시를 규칙이 해제보류와 분리하지 않는 구현차이를 기록함.
- 공식 발표·발효·관측·통제 및 사용자 직접기록은 사실범위만 확정형으로, 앱 내부 피해·불편·회복·활동영향은 해제단계에서도 `낮아질 수 있어요/남을 수 있어요/추가 확인이 필요할 수 있어요` 가능성형으로만 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-12는 사용자 미확정 권장안이며 확정 전에는 다음 7-13 `예보 판단 범위`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-12 및 검토 7-13: 미리 보는 기간

- 사용자의 `확정 후 다음`에 따라 7-12 `판정 해제 기준` 권장안을 최종 채택함. 공식 해제·예보구간 종료·내부조건 완화·잔류상태·사용자 일정/행동·자료 노후를 분리하고, 공식/직접기록 확정형과 내부 영향 가능성형을 유지함.
- 다음 7-13 `예보 판단 범위`를 기상청 현행 예보발표안내·단기예보 도움말·2024년 5일 연장자료·중기 신뢰도·최근 예보평가, 2025년 국내 동네예보 강수연구, 기상청 자외선·에어코리아 대기질 범위와 현행 서버/Flutter 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `미리 보는 기간`으로 제안함. `지금 확인/6시간 안쪽/날짜별 상세/미리 계획/주·계절 참고/예보범위 밖/새 발표 확인 필요`를 구분함.
- 모든 생활판정에 공통인 앞으로 24시간/48시간/7일을 두지 않음. `사용자 일정 ∩ 제품 유효구간 ∩ 요소 유효구간 ∩ 위치범위 ∩ 자료 사용가능구간`으로 실제 판단범위를 계산함.
- 기상청 초단기예보는 현재부터 6시간 이내, 단기예보는 실제 발표본이 제공하는 최대 5일 이내, 중기예보는 단기 이후 약 10일까지, 1개월/3개월 전망은 주별/월별 정보라는 공식 계층을 보존함.
- 공식 특보·예비특보·영향예보·통제·운휴는 일반 앱 horizon보다 길어도 기관이 발표한 적용구역·대상·발효/유효구간과 원행동을 확정 표시함. 예보 최대범위 밖이라는 이유로 숨기거나 일반 수치로 해제하지 않음.
- 초단기는 가까운 시간의 상세후보, 단기는 필요한 요소·시간/공간 해상도가 일정에 맞는 날짜별 후보, 중기는 계획·재확인 후보, 장기/기후전망은 넓은 배경으로만 사용함. 중기·장기를 시간별 산책·출근·빨래판정으로 세분하지 않음.
- 2024년 기상청이 먼 미래 불확실성 때문에 5일째 강수량·신적설·풍속을 정량값 대신 정성정보로 제공한다고 밝힌 점을 반영함. `약한 비/강한 바람`을 임의 mm·cm·m/s로 복원하지 않음.
- 중기예보의 공식 신뢰도 높음/보통/낮음은 다음 발표에서도 예보가 유지될 가능성임. 날씨 발생확률이나 반대날씨 가능성으로 바꾸지 않고 원라벨·뜻을 보존함.
- 2025년 8월~2026년 7월 기상청 전국 월평균 최고기온예보 MAE가 월별 1.0~1.7℃였음을 확인함. 전국·월평균 성능을 특정 동네·시각·개인 체감오차로 사용하지 않음.
- 2025년 국내 연구가 2021.7~2024.12 전국 78개 지점, 리드타임 T=1~24를 각각 검증하고 동네예보의 복잡지형·일부지역 구조편향을 지적한 점을 반영함. 연구 보정모델의 RMSE 16.5% 감소·상관계수 53.9% 향상을 미구현 앱 성능으로 주장하지 않음.
- 초단기·단기 경계, 단기·중기 경계, 자정, 위치/경로 경계를 넘는 일정은 같은 제품·정밀도 구간별로 분할함. 덮이지 않는 부분은 `UNCOVERED/PARTIALLY_COVERED`로 보존하고 맑음·영향없음으로 채우지 않음.
- 판단 전에 강수형태/확률/양, 적설, 노면, UVI 등 필요한 필드를 선언함. 제품 기간은 덮지만 필요한 요소가 없으면 0이 아니라 `REQUIRED_FIELD_MISSING`으로 처리함.
- 일정창보다 시간해상도가 넓거나 권역/격자가 사용자 위치보다 넓으면 `PLANNING_PREVIEW`로 낮춤. 오전예보를 오전 9시 20분 강수로, 권역 일평균 대기질을 특정 측정소·시각 농도로 정밀화하지 않음.
- 최신 적용 발표본의 issuedAt/baseTime/fetchedAt/validWindow를 구분하고 새 발표는 이전본을 `SUPERSEDED`로 연결함. 조회시각이 새롭다는 이유로 오래된 발표본을 최신예보로 부르지 않음.
- 기관이 발표한 강수확률·정성등급·중기 신뢰도를 원뜻 그대로 보존하며 리드타임만으로 앱 정확도 90/70%를 만들거나 시간별 강수확률을 더하지 않음.
- 자외선 3시간값은 다음 시각까지의 최대 예측 interval로 저장함. 에어코리아 측정소 실시간 관측과 권역별 오늘·내일·모레 일평균 예보를 별도 객체로 두고 현재 측정값을 미래로 복사하지 않음.
- 블랙아이스(도로살얼음)는 5일 뒤 최저기온·비눈 아이콘만으로 특정 도로/시각의 가능성 알림을 만들지 않음. 필요한 상세 기상·노면·경로범위를 확보해도 내부 문구는 가능성형만 사용함.
- 상태를 OFFICIAL_APPLIES, OBSERVED_AT_TIME, NEAR_TERM/SCHEDULE_DECISION_CANDIDATE, PLANNING_PREVIEW, CLIMATE_CONTEXT_ONLY, PARTIALLY_COVERED, OUT_OF_PRODUCT_RANGE, REQUIRED_FIELD_MISSING, 시간/공간해상도부족, SUPERSEDED, 제품충돌로 제안함.
- `forecastScopeDecision` 계약에 사용자/목표구간·필요필드·제품/발표본·요소별 유효구간·시간/공간해상도·리드타임·covered/uncovered·정량/정성필드·공식 확률/신뢰도·재확인시각·품질/충돌을 포함함. globalForecastHours/first24Slots/appConfidencePercent/missingForecastMeansClear를 저장하지 않음.
- 현행 `/today`는 배열 첫 24개를 판단범위로 쓰고 brief는 current와 같은 hourly[0]을 중복 포함함. 결측·불규칙 간격·사용자 일정과 실제 24시간 교차를 확인하지 않음.
- 서버와 Flutter 직접조회는 KMA 단기예보만 수집하고 초단기·중기·특보제품을 수집하지 않음. 현재 이후 hourly를 48개로 자르고 daily는 4일만 남겨 공식 최대 5일·화면 `한 주`와 불일치함.
- KMA 요청은 page 1/numOfRows=1000만 읽고 totalCount·다음페이지를 확인하지 않아 5일 발표본의 전체 요소 수집완전성을 검증하지 못함.
- 48개 hourly 밖 날짜는 하루 최고/최저·최대강수확률·합계량을 정오 snapshot 하나로 만들고 observedAt에 넣어 시간별 추천을 실행함. 예보/관측역할과 일자료/시간자료를 혼동할 수 있음.
- WeatherSnapshot에 제품종류·제품/요소별 유효범위·해상도·공간범위·다음발표·covered 상태가 없고 모든 예보 슬롯에 observedAt=forecastAt을 함께 넣어 예보를 관측으로 표현할 위험이 있음.
- 자외선은 원래 3시간 구간 최대라는 의미 없이 직전값을 전달하고, AirKorea는 현재 측정소 관측만 합치며 공식 미래 대기질예보는 수집하지 않음. 통합 dataSource 문자열만으로 역할·범위를 구분하지 못함.
- 공식 예보 발표·범위·관측은 사실범위를 확정형으로 표시함. 앱 내부 활동영향·준비·변경은 모든 리드타임에서 `겹칠 수 있어요/필요할 수 있어요/달라질 수 있어요` 가능성형으로만 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-13은 사용자 미확정 권장안이며 확정 전에는 다음 7-14 `관측값과 예보값 사용 원칙`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-13 및 검토 7-14: 확인된 날씨와 예보

- 사용자의 `확정 후 다음`에 따라 7-13 `예보 판단 범위` 권장안을 최종 채택함. 전역 24/48시간 대신 사용자 일정과 제품/요소 유효범위·해상도·위치·자료품질의 교집합을 사용하고 초단기/단기/중기/장기 역할과 공식/내부 표현을 분리하는 원칙을 유지함.
- 다음 7-14 `관측값과 예보값 사용 원칙`을 기상청 2025년 동네예보 데이터 안내·AWS QC/지점이력·수치예보 검증보고서, 2025년 관측망 정밀도 연구, 서울 ASOS/AWS 국지강우 연구, 에어코리아 실시간 생산/이상선별·최종확정 구분과 현행 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `확인된 날씨와 예보`로 제안함. `○○관측소에서 확인/현재시간대 예보/앞으로의 예보/사용자 기록/자료 품질 확인 필요`와 출처시각을 표시함.
- 수집단계에서 OFFICIAL_OBSERVATION, OFFICIAL_FORECAST, OFFICIAL_STATE_NOTICE, REMOTE_SENSING_OR_ANALYSIS, USER_REPORTED_OBSERVATION, DEVICE_OBSERVATION, DERIVED_FROM_OBSERVATION/FORECAST로 근거역할을 고정함.
- 공식 관측은 기관·관측소·요소·관측시각/집계구간·품질이 확인된 범위에서 `관측되었다`고 확정 표시함. 대표지점 값을 사용자 집·도로·경로 전체의 발생으로 확장하지 않음.
- 공식 예보는 기관이 해당 구간을 `예보했다`는 사실을 확정 표시하고 실제 미래 발생·개인 영향은 확정하지 않음. 앱 내부 체감·피해·활동영향은 관측입력을 써도 가능성형으로만 표시함.
- 기상청 초단기실황은 5km 격자에 대표 AWS를 매칭한 10분 관측값임. 선택위치 직접측정이 아니며, 2018.7.11 이전 분석값과 이후 대표 AWS값의 생산방식 버전을 구분함.
- AWS 분·시간자료의 바람·습도·기압 등에 QC 0 정상/1 오류/9 결측이 제공되고 동일 stationId도 기간별 위치가 달라질 수 있음을 반영함. 관측당시 좌표·고도·지점이력·요소별 QC를 저장함.
- 기상청 2025 보고서가 75 ASOS·244 AWS 관측을 예측과 별도로 맞춰 강수를 검증하는 점을 반영해 관측/예보를 같은 snapshot 필드로 만들지 않음. 요소·지점대응·interval·리드타임이 다르면 예보 맞음/틀림을 계산하지 않음.
- 2025년 국내 연구에서 AWS/TM 배치·공간밀도에 따라 강수량 편차가 컸고 우량계 분해능별 강우강도 오차가 달랐음을 반영함. 연구의 1.45/7.32/16.3%를 앱 센서 정확도로 전용하지 않음.
- 서울 국지강우 연구에서 ASOS/AWS 지점별 강수차가 유출량 차이로 이어진 점을 반영해 한 AWS 무강수를 도시·경로 전체 무강수로 확정하지 않음.
- 에어코리아 실시간 측정은 NAMIS 수집·이상자료 선별을 거치지만 최종확정자료와 별도임. REALTIME_PROVISIONAL과 FINAL_CONFIRMED를 분리하고 역사비교·평가에는 가능한 경우 확정자료를 사용함.
- 이미 지난 구간은 품질확인 관측, 현재는 유효 관측, 미래는 최신 예보, 역사비교는 같은 역할/요소/공간/집계의 확정 또는 품질확인 관측을 사용함. 관측이 없는 현재에는 `현재시간대 예보`를 표시할 수 있으나 관측으로 승격하지 않음.
- 한 객체는 하나의 primary evidenceRole만 가지며 같은 시각의 기온예보·PM관측·UVI예보는 별도 evidence를 presentation 단계에서 조합함. observedAt=forecastAt을 생성하지 않음.
- station/grid/권역/사용자 위치의 대응방식·거리·고도를 보존함. 가장 가까운 관측소는 같은 위치가 아니며 경로가 여러 지점/격자를 지나면 범위를 나눔.
- 관측과 예보가 다르면 OBSERVATION_FORECAST_DIVERGENCE로 두 값·시각·위치를 보존함. 과거/현재 행동에는 관측을, 이후 계획에는 최신 예보를 적용하고 한쪽을 임의 삭제하지 않음.
- 체감온도·눅눅함·노면·블랙아이스(도로살얼음)·활동후보는 입력 evidence refs와 가장 약한 품질/공간범위를 상속함. 관측을 입력했다고 앱 파생값이 공식관측으로 바뀌지 않음.
- 특보·통제·경보는 자체 lifecycle을 유지함. 대표 AWS 한 점이 임계 아래거나 예보가 달라도 앱이 공식 상태를 수정·해제하지 않음.
- 사용자 직접기록은 기록사실을 확정형으로, 개인센서는 센서 위치·보정·품질범위에서 측정사실을 확정형으로 보존함. 공식관측·주변지역 전체로 확장하지 않음.
- 상태를 공식관측 정상/실시간미확정/QC오류/결측/대표지점한정, 공식예보 유효/현재시간예보/대체됨, 관측예보불일치, 사용자기록/센서관측, 파생가능성, 비교불가로 제안함.
- weatherEvidence 계약에 근거역할/상태·제품/버전·요소/값/단위·관측/예보시간·관측소/격자/좌표/고도/거리·QC/확정상태·파생입력·센서/사용자기록·대체/충돌을 포함함. 비교쌍에는 위치대응·interval·lead time·비교가능성을 별도 저장함.
- 서버와 Flutter 직접조회는 KMA 단기예보만 수집하고 초단기실황/ASOS/AWS 관측 Provider가 없음. `snapshotFromSlot()`이 예보시각을 observedAt/forecastAt/validFrom 모두에 넣고 hourly[0] 예보를 current로 사용함.
- Flutter 메인·상세는 이 current를 `현재 기온/체감/습도`로 확정 표시함. 체감온도는 예보 기온·습도·풍속으로 앱이 계산했지만 입력역할·방법이 API에서 사라짐.
- 환경자료 결합은 기상예보·UVI예보·AirKorea 측정소 관측을 한 WeatherSnapshot에 넣고 provider 문자열을 합침. PM관측이 기상예보 validTo를 공유해 한 시간 미래값처럼 보일 수 있고 화면은 시각/측정소/미확정상태 없이 현재 PM으로 표시함.
- saveDailyWeatherSnapshot은 예보 current를 observation_date에 저장하고 온도/체감/하늘/PM을 요청별 upsert함. 서로 다른 시각·역할·출처가 한 행에 섞일 수 있으며 observedAt/issuedAt/station/QC가 없음.
- yesterday/last-year API는 이 저장 예보를 실제 과거날씨처럼 반환해 역사관측 비교나 예보검증으로 사용할 수 없음. 비교가능 관측 Provider와 스키마 분리가 필요함.
- weather cache도 CURRENT라는 이름으로 첫 예보슬롯을 저장하고 Flutter 모델은 forecastAt??observedAt을 observedAt 변수에 넣어 UI시각을 만들어 역할구분을 다시 제거함.
- 주간 fallback은 일예보 요약을 정오 observedAt으로 만들어 시간별 규칙을 실행하고 상세근거는 예보 hourly 최대값과 관측 PM current를 출처 없이 섞어 표시함.
- 공식 관측·예보발표·공식상태·사용자 직접기록은 각 사실범위에서 확정형, 앱 내부 체감·피해·활동영향은 `느껴질 수 있어요/영향이 있을 수 있어요/형성될 수 있어요` 가능성형으로만 제안함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-14는 사용자 미확정 권장안이며 확정 전에는 다음 7-15 `결측값 처리`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-14 및 검토 7-15: 자료 확인 상태

- 사용자의 `확정 후 다음`에 따라 7-14 `관측값과 예보값 사용 원칙` 권장안을 최종 채택함. 공식관측·공식예보·공식상태·사용자 직접기록·센서·앱 파생값의 역할을 수집단계부터 분리하고 관측/발표 사실은 확정형, 내부 체감·피해·활동영향은 가능성형으로 유지함.
- 다음 7-15 `결측값 처리`를 기상청 AWS QC, 기상관측데이터 품질 통계 관리 지침, 단기예보 API/강수표시, 에어코리아 이상자료·최종확정자료, 국립환경과학원 제품별 `-999`, 국토교통부 결측 강우 보완연구와 현행 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `자료 확인 상태`로 제안함. `자료 확인 중/일부 자료만 확인/기관에서 자료없음으로 표시/이 항목은 제공되지 않음/품질 확인 필요/이전 자료`를 원인별로 구분함.
- 결측은 0·정상·좋음·맑음·무강수·무풍·특보 없음·영향 없음이 아니며, 결측만으로 안전이나 위험 어느 쪽도 만들지 않고 내부판정을 `UNDETERMINED`로 둠.
- 공식 기관의 자료상태와 앱 미수신 사실은 확인범위에서 확정형으로 표시하고, 결측 때문에 체감·피해·활동판정이 어려운 상태는 `판단하기 어려울 수 있어요/추가 확인이 필요할 수 있어요` 가능성형으로만 제안함.
- 기상청은 이론수집·실제수집·미수집을 나누고 수집자료도 QC 0 정상/1 오류/9 결측으로 분리함. 앱도 요청성공, 필드수신, QC 정상, 최종확정, 신선도를 하나의 available 불리언으로 합치지 않음.
- KMA 단기예보 API의 resultCode/resultMsg, pageNo/numOfRows/totalCount를 보존하고 모든 페이지·기대 슬롯·필드가 확인돼야 `SUCCESS_COMPLETE`로 판정함. HTTP 200이나 첫 페이지 항목 존재만으로 완전수신을 선언하지 않음.
- `EXPLICIT_ZERO`, `EXPLICIT_NONE`, `BELOW_REPORTING_LIMIT`, `NOT_APPLICABLE`, `NOT_PROVIDED_BY_PRODUCT`, `FIELD_MISSING`, `UNPARSABLE_VALUE`를 분리함. `강수없음`, 0mm, `1mm 미만`, PCP 누락은 서로 다른 상태임.
- 에어코리아의 `-999`는 실제 음수농도나 좋음이 아니며 제품별 의미를 확인함. 최종확정 다운로드의 장비점검·통신장애 등 이상자료 표시와 8시간 일평균 제품의 유효자료 획득률 75% 미만 규칙을 다른 endpoint에 일반화하지 않음.
- 수집단계에서 null·빈문자·`-`·`-999`·누락 key와 raw token을 보존하고 제품별 코드사전으로 해석함. 사전에 없는 특수값은 정상 숫자로 사용하지 않음.
- 부분응답은 슬롯 전체를 버리지 않고 필드별 availability로 보존함. 한 시각 TMP가 빠져도 정상 PCP·WSD와 그 슬롯의 결측 존재를 유지함.
- 규칙마다 requiredFields/alternativeSufficientFields/optionalFields를 선언함. 필수입력이 없으면 해당 규칙만 RULE_INPUT_INCOMPLETE로 두되, 유효한 강수량처럼 독립근거가 충분하면 그 경로만으로 가능성 안내를 만들 수 있음.
- 부재·안전의 부정판정은 관련 입력과 공식 목록의 완전성이 확인됐을 때만 생성함. fact/추천이 생성되지 않은 것을 영향 없음이나 안전으로 바꾸지 않음.
- 공식 특보·통제·운휴는 생활판정 결측과 독립된 lifecycle로 유지함. 공식 목록은 대상·시각·전체 페이지를 성공적으로 조회한 빈 배열일 때만 발표 없음 후보로 해석함.
- 인접 관측소·다른 격자·예보·레이더·사용자 직접기록은 원 결측필드를 채우지 않고 별도 evidence로 저장하며 위치·시간·역할 차이와 7-14 공간범위를 상속함.
- 현재·가까운 미래의 안전·피해·활동판정, 공식관측 표시, 특보해제에는 자동 보간을 사용하지 않음. 분석·차트용 보간은 별도 검증·오차·불확실성·IMPUTED 라벨을 가진 파생자료로만 검토함.
- 마지막 정상값을 현재값으로 복사하지 않고 관측/발표시각과 `이전 자료`를 표시함. 구체적 stale 허용시간과 만료정책은 다음 7-16에서 정함.
- 요소별로 PTY 누락→NONE, PCP/SNO 누락→0, POP 누락→0%, 바람 누락→무풍, UVI 누락→낮음, PM 결측→좋음, 특보 미수집→빈 목록, 노면자료 결측→블랙아이스(도로살얼음) 없음 변환을 금지함.
- dataAvailability 계약에 요청/페이지/totalCount·기대/수신 슬롯·fieldState/raw/valueRange·결측사유·QC/확정/신선도/충돌·대체근거·보간·차단규칙·회복근거를 포함함. ruleInputDecision에는 필수/대체충분/선택필드와 결과상태를 포함함.
- 서버 KMA Provider는 page 1/1000만 읽고 totalCount를 수집하지 않으며 PTY 결측을 0으로, parsePrecipitationAmount/amountMinimum을 통해 누락을 0으로 만들 수 있음. TMP 누락은 슬롯 전체를 삭제하고 일합계·일최대 계산도 슬롯 결측을 0으로 합산함.
- 비·눈·강풍·자외선·공기질 규칙의 다수 `?? 0` 경로는 입력부재와 임계 미충족을 모두 fact 미생성으로 끝냄. airQualityRule은 PM 결측을 0으로 쓰고 AirKorea `numericValue()`는 `-999`를 숫자로 통과시킬 수 있음.
- timeSeriesLifestyleBuilder의 `(activeWarnings?.length ?? 0) === 0`은 특보목록 미수집과 공식 발표 없음이 동일해지는 구현차이임. 환경 서비스가 계산한 AVAILABLE/CACHED/STALE/UNAVAILABLE도 snapshot 결합 뒤 개별 규칙입력에서 사라짐.
- Flutter CurrentWeather는 기온 결측을 0℃로, HourlyWeatherItem은 기온·강수확률·강수량·적설·풍속을 0으로, 하늘상태를 맑음으로 바꿈. 직접 KMA 조회도 PTY/POP/PCP/SNO/풍속 누락을 0, 해석불가 날씨를 맑음으로 처리함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-15는 사용자 미확정 권장안이며 확정 전에는 다음 7-16 `오래된 데이터 허용시간`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-15 및 검토 7-16: 마지막 확인 시각

- 사용자의 `확정 후 다음`에 따라 7-15 `결측값 처리` 권장안을 최종 채택함. 결측을 0·정상·좋음·현상없음으로 바꾸지 않고 request/field/QC/finality/freshness/conflict를 분리하며, 공식 자료상태는 확인범위에서 확정형, 내부 판단보류·체감·피해·활동영향은 가능성형으로 유지함.
- 다음 7-16 `오래된 데이터 허용시간`을 기상청 API허브·예보업무·생활기상지수 변경안내, 국립환경과학원 1시간 측정자료, 에어코리아 4회 예보, 기상청 특보 해제예고와 현행 구현에 대조해 미확정 권장안으로 작성함.
- 모든 자료에 공통인 30분/2시간/8시간 TTL을 두지 않음. 원기관 observedAt/issuedAt, 제품별 공식 생산주기, valid window, nextExpectedAt을 기준으로 현재성을 판정함.
- 현재판정의 허용 누락주기는 0회로 제안함. 다음 발표·관측슬롯이 아직 예정되지 않았고 target이 유효구간 안인 최신 자료만 현재 내부판정과 새 알림에 사용함.
- 새 자료가 예정됐으나 미수신이면 이전값은 `이전 자료·새 자료 확인 중`으로만 표시하고 새로운 체감·피해 가능성·활동판정·푸시를 만들지 않음. 오래된 자료만으로 기존 episode가 안전해졌다고 해제하지도 않음.
- 공식 페이지에서 제품별 생산·발표주기는 확인했지만 모든 API에 공통인 최대 전달지연 SLA는 확인하지 못함. 이는 조사자료에 근거한 판단이며 현행 15분·30분 구현가정을 공식값으로 채택하지 않음.
- deliveryGrace는 Provider 문서값을 우선하고, 없으면 firstAvailableAt-scheduledAt을 제품·endpoint·지역·버전별로 실측해 근거기간·표본수·지연분포·상위분위·장애사례·재검토일과 함께 채택하도록 제안함. 검증 전에는 예정시각부터 확인 중으로 두고 이전 자료로 새 판단을 만들지 않음.
- 사용자 화면명은 `마지막 확인 시각`으로 제안함. 관측·발표·마지막 확인·이전 자료를 분리하고 상대시간만 아니라 절대시각과 날짜경계를 표시함.
- observedAt/issuedAt/validFrom/validTo/scheduledAt/nextExpectedAt/firstAvailableAt/fetchedAt/cachedAt/lastSuccessfulCheckAt/evaluatedAt을 분리함. fetch·cache가 새로워져도 동일 원자료의 freshness는 회복되지 않음.
- 최신성 상태를 LATEST_APPLICABLE, AWAITING_EXPECTED_RELEASE, STALE_REFERENCE_ONLY, OUTSIDE_VALID_WINDOW, SUPERSEDED, LAST_CONFIRMED_RECHECK_NEEDED, ARCHIVAL_VALID, FUTURE_TIMESTAMP_OR_CLOCK_ERROR로 제안함.
- 기상청 현재 API허브 격자자료의 단기예보는 02/05/08/11/14/17/20/23시, 초단기예보·실황은 안내된 현재 버전에서 10분 주기임. 실제 호출 endpoint·버전별 baseTime 계약이 다를 수 있어 KMA 전역 TTL 대신 providerProductId/endpointVersion/scheduleVersion을 둠.
- 기상청 예보업무의 중기예보 06/18시, 1개월전망 목요일, 3개월전망 매월 23일을 확인함. 초단기·단기·중기·장기를 같은 시간허용값으로 처리하지 않음.
- 자외선지수는 오늘~글피 3시간 단위·3시간 간격 생산, 일반대기 측정은 측정소별 1시간 단위, 에어코리아 대기질예보는 05/11/17/23시 일 4회임. 측정소 관측·권역예보·UVI 구간을 서로 다른 제품계약으로 판정함.
- 공식 특보·통제·운휴는 발표 후 경과시간으로 자동 만료하지 않음. 해제예고는 연장·단축될 수 있고 공식 해제 전까지 유지된다는 기상청 안내를 반영해 최신 공식상태를 재확인함.
- 공식 상태 재확인 실패 시 마지막 성공 확인 당시의 발표·발효 사실과 시각은 확정형으로 남기되 현재도 유지/해제됐다고 새로 단정하지 않음. API 실패·부분 빈 목록·해제예고 도달·cache TTL 종료는 공식 해제가 아님.
- 품질확인 과거 관측과 당시 예보 발표본은 현재카드에서는 오래됐지만 일치하는 과거 target의 비교·검증에는 ARCHIVAL_VALID일 수 있음. 역사보존기간과 현재판정 TTL을 분리함.
- 사용자 직접기록은 특정 시각에 기록한 사실로 계속 보존하되 현재상태로 자동 연장하지 않음. 개인·실내·노면센서도 기기 샘플링주기와 QC에 따른 최신 예상 샘플만 해당 위치 판단에 사용함.
- 블랙아이스(도로살얼음) 공식 발생·관측은 기관이 발표한 도로·구간·시각 범위에서 확정 표시함. 오래된 사실을 현재 전 구간 노면으로 연장하지 않고 앱 내부 형성·주행영향은 가능성형 또는 판단보류로만 유지함.
- freshnessDecision 계약에 모든 source/retrieval/cache/decision 시각, 예상·수신버전, supersede, missedCycleCount, deliveryGrace 근거버전, quality/finality/request completeness, target overlap와 용도별 허용플래그를 포함함.
- 환경자료 서비스는 UVI FRESH 2시간/MAX_STALE 8시간, 대기질 FRESH 30분/MAX_STALE 3시간을 캐시 updatedAt 기준으로 계산함. 동일 오래된 원자료 재저장으로 fresh가 다시 시작될 수 있음.
- AirKorea Provider는 최대 4시간 된 측정값을 수용할 수 있어 새 캐시 뒤 cache age 30분까지 fresh, 3시간까지 stale로 남기면 원측정시각 기준 최대 약 7시간 된 값이 남을 수 있음.
- 환경 source status는 WeatherSnapshot 결합 뒤 규칙에 전달되지 않고 Flutter TodayWeatherResponse도 environmentalSources를 모델링하지 않아 stale 판정·시각을 규칙과 사용자 화면이 사용할 수 없음.
- KMA 서버·Flutter는 15분 publication delay와 이전 4개 단기 발표본 fallback을 사용해 최신 예정본 미수신 시 최대 9시간 전 발표본을 이전자료 표시 없이 쓸 수 있음. UVI도 30분 지연가정과 이전 네 생산본 fallback을 사용함.
- `uvForTime()`은 직전 point를 최대 3시간 전달하지만 3시간 최대예측 interval·발표본 최신성을 함께 검증하지 않고, weather CURRENT cache 조회도 원자료시각·제품주기 만료검사가 없음.
- scheduledAt/nextExpectedAt/firstAvailableAt/lastSuccessfulCheckAt, 제품별 지연 telemetry와 공식 특보 Provider가 없어 권장 lifecycle을 현재 구현에서 수행할 수 없음.
- 공식 발표·관측·발효·해제는 확인된 기관·구역·시각 범위에서 `발표됐어요/관측됐어요/발효 중이에요/해제됐어요` 확정형을 사용함. 이전 자료를 바탕으로 한 체감·피해·활동영향은 `달라졌을 수 있어요/판단이 달라질 수 있어요/형성될 수 있어요` 가능성형만 사용함.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-16은 사용자 미확정 권장안이며 확정 전에는 다음 7-17 `취약계층 개인화`로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-16 및 검토 7-17: 날씨 돌봄 설정

- 사용자의 `확정 후 다음`에 따라 7-16 `오래된 데이터 허용시간` 권장안을 최종 채택함. 전역 TTL 없이 원기관 생산주기·발표본·유효구간·다음 예상시각을 따르고 현재의 새 판정에는 누락주기 0회를 요구하며, 공식 상태는 재확인하고 이전 자료는 참고·이력으로 분리하는 원칙을 유지함.
- 다음 7-17 `취약계층 개인화`를 기상청 영향예보, 질병관리청 대상자별 온열질환 매뉴얼과 2025 온열·2024~2025 한랭질환 감시결과, 에어코리아 오존 행동요령, 환경부 미세먼지 보호범위, 안전보건공단 폭염작업 수칙, 개인정보보호법과 국내 인구집단 연구에 대조해 미확정 권장안으로 작성함.
- 전역 `취약/비취약` 라벨, 질환개수 합산, 위험점수·배수, 공식단계 가감은 만들지 않음. 공식 예보·특보·영향예보·관측·공기질등급은 모든 사용자에게 같은 상태로 보존함.
- 사용자 화면명은 낙인을 줄이는 `날씨 돌봄 설정`으로 제안함. 미설정 상태는 `일반인/건강함/비취약`이나 영향 없음으로 해석하지 않고 일반 공식정보·기본 생활안내를 동일하게 제공함.
- 개인화 입력은 사용자가 직접 선택하거나 적법하게 등록한 생애단계, 건강안내 범주, 기능·이동·의사소통 지원, 실제/계획 노출, 냉난방·쉼터·교통·연락 같은 대응여건, 보호관계, 의료진·사업장 개인계획, 직접 체감·행동기록으로 분리함. 앱은 질환·임신·장애·약물영향을 추정하거나 진단하지 않음.
- 개인화는 공식 대상자 행동요령 선택, 안내 우선순위, 더 이른 준비·재확인, 일정·강도·경로·대안 조정 가능성, 보호자 확인·접근성만 바꿀 수 있음. 공식단계 변경, 외출·작업중지·약 용량·수분량·진료의 앱 처방은 금지함.
- 질병관리청 2025 감시결과의 온열질환 4,460명, 65세 이상 30.0%, 실외 79.2%, 14~17시 집중과 2024~2025 한랭질환 334명, 80세 이상 30.8%, 실외 74.0%를 우선순위 근거로 반영함. 집단비율·상대위험을 개인 발생확률로 변환하지 않음.
- 임신부 매뉴얼의 실외온도 28℃ 이상 활동점검과 29℃ 이상 노출연구는 임신부가 직접 등록되고 일정이 겹칠 때의 이른 확인신호로만 사용함. 개인 조산·입원선, 공식 폭염단계, 공통 외출금지선으로 사용하지 않음.
- 안전보건공단의 체감온도 31℃ 이상 예방조치와 33℃ 이상 매 2시간 이내 20분 휴식은 실제 야외작업과 최신 사업장 조건에 한정해 공식 수칙으로 표시함. 일반 산책·통근으로 확대하거나 앱이 사업주의 조치완료·법위반을 판정하지 않음.
- PM10·PM2.5와 오존은 공식 4등급·예경보를 그대로 유지하고 직접 등록한 민감안내와 실외시간·강도가 겹칠 때 기관의 민감군 행동요령을 먼저 연결함. 자체 민감군 농도등급이나 개인 질환악화선은 만들지 않음.
- 고령·장애·독거·만성질환은 서로 더하지 않고 고령수칙, 이동지원, 안부확인, 냉난방·쉼터 대안처럼 별도 근거와 행동후보로 보존함. 국내 연구의 지역별 28/30℃ 차이는 다음 7-18 지역보정의 검토근거이며 `취약하면 -2℃`로 복사하지 않음.
- 비·눈·강풍·블랙아이스(도로살얼음)·호우·침수·대설에서는 공식 관측·발표·통제만 확정형으로 표시하고 이동지원·동행·경로·대체교통·안부확인이 도움이 될 가능성만 추가함. 취약맥락으로 현상·낙상·사고·대피단계를 생성하지 않음.
- 공식 발표·관측, 사용자가 등록·기록한 사실은 해당 범위에서 확정형으로 표시함. 앱 내부 개인 영향·피해·체감·활동조정은 모두 `커질 수 있어요/도움이 될 수 있어요/알맞을 수 있어요/판단하기 어려울 수 있어요` 같은 가능성형만 사용함.
- 건강·임신·장애 맥락은 민감정보로 별도 동의, 최소수집, 목적·보유기간, 철회·삭제가 필요함. 만 14세 미만 프로필은 법정대리인 동의·확인과 쉬운 설명을 요구하고, 가능한 건강원문은 기기 안에 두며 서버에는 필요한 최소 파생태그만 보내도록 제안함.
- `careProfile`과 `personalizationDecision` 계약에 사람/권한/동의·유효기간, 각 맥락의 출처, 일정 교집합, 공식 근거와 `officialStateUnchanged`, 적용한 개인화 방식, 가능성 문구키, 개인계획 우선, 보호자 공유범위와 만료를 포함함. isVulnerable/vulnerabilityScore/riskMultiplier/inferredDiagnosis 등은 저장하지 않음.
- 현행 Flutter AppSettings는 설치 단위 준비물·주의알림 토글뿐이고 서버에도 person/guardian/care profile이 없음. 규칙엔 개인화 입력·공식 대상자 지침·개인계획 override가 없고 PM 결측 0 처리와 근거 없는 `민감하다면` 템플릿이 남아 있어 현재 구현으로는 근거 있는 사람별 판정을 만들 수 없음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-17은 사용자 미확정 권장안이며 확정 전에는 다음 7-18 `지역별 기준 보정`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-17 및 검토 7-18: 이 지역 기준

- 사용자의 `확정 후 다음`에 따라 7-17 `취약계층 개인화` 권장안을 최종 채택함. 전역 취약라벨·합산점수·공식단계 가감 없이 직접 등록한 생애단계·건강안내·기능지원·노출·대응여건·보호관계·개인계획으로 공식 수칙 선택과 안내 우선순위·활동선택 가능성만 조정하는 원칙을 유지함.
- 다음 7-18 `지역별 기준 보정`을 기상청 영향예보·2026년 한파 영향예보 지역기준·특보구역·5km 동네예보·1991~2020 기후평년, 에어코리아 예보권역, 국내 229개 시군구·도시/농촌·도시열·7개 도시 시간변화 연구와 현행 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `이 지역 기준`으로 제안함. 적용 위치, 기상청 특보구역, 동네예보 격자, 대기질 예보권역/측정소, 평년 비교 지점·기간, 경로 중 다른 구역을 서로 분리해 표시함.
- 앱이 시·도 이름에 따라 모든 임계값을 ±N℃·±Nmm·위험 +1단계로 바꾸는 전역 지역보정은 두지 않음. 공식 기관이 지역별 기준과 구역을 정한 제품은 최신 원기관 기준·구역·단계를 그대로 적용하고 앱 보정을 다시 더하지 않음.
- 기상청 영향예보가 특보구역 단위로 지역의 노출·취약성·대응역량을 이미 반영하므로 공식 영향예보의 정확한 공간매칭을 지역보정 1순위로 정함. 앱의 인구·기후점수로 공식단계를 수정·해제하지 않음.
- 2026년 보건분야 한파 영향예보의 지속저온 기준을 공식 제품값으로 기록함. 제주도 산지 제외는 관심/주의/경고 -3/-5/-7℃ 2일, 위험 -12℃ 1일이고 남·동해안·제주 산지는 -5/-7/-9℃ 2일, -14℃ 1일, 그 외 지역은 -9/-12/-15℃ 2일, -20℃ 1일임.
- 급격한 하강은 관심 전일대비 7℃ 이상 하강·3℃ 이하, 주의 10℃ 이상 하강·3℃ 이하·평년보다 3℃ 이상 낮음, 경고 15℃ 이상 하강·3℃ 이하·평년보다 3℃ 이상 낮음이라는 원기관 조건을 보존함. 앱이 위경도 해안거리·주소문자열·고도추정으로 공식 세 범주를 재생성하지 않음.
- 공식 영향예보 미수신 때 예보기온으로 같은 4단계를 모방하지 않고 2-5 일반 내부 가능성판정과 `공식 영향예보 확인 필요`를 분리함. 구역·수치·지속일수·제품 변경에는 version/effective date를 적용하고 과거 episode는 당시 버전을 보존함.
- 기상청 동네예보·초단기실황은 5km×5km 격자와 격자별 대표 AWS임. 행정동 이름, 격자 대표값, 관측소 관측, 사용자 위치 직접측정을 구분하고 한 격자값을 산·해안·골짜기·도시블록 전체의 실제값으로 확장하지 않음.
- 기상청 특보구역의 산지/평지·도서·중산간·세부 방위구역을 최신 공식 polygon/code로 매칭함. 제주 중산간 200~600m 미만·산지 600m 이상 같은 공식 정의가 있어도 앱 고도추정만으로 공식구역을 바꾸지 않음.
- 에어코리아 PM/O3 예보는 경기 남부/북부, 강원 영동/영서와 그 밖의 광역자치단체 권역등급을 그대로 사용함. 권역예보를 동네 관측으로, 측정소 한 점을 권역 전체 관측으로 변환하지 않음.
- 기상청 1991~2020 평년은 동일 지점·요소·집계기간·지점이력을 맞춘 보조비교에만 사용함. 평년은 오늘의 안전선·예보·관측·주민 내성이 아니며 최근 몇 년 평균을 임의의 새 평년으로 부르지 않음.
- 한국 229개 시군구 연구의 서늘한 지역 28℃·더운 지역 30℃ 증가경향과 도시 92백분위·농촌 95백분위 결과는 지역차 가능성의 연구근거로만 둠. 현재 시군구 알림선, `농촌 +3`, 공식 폭염단계, 개인 더위내성으로 복사하지 않음.
- 전국 도시·농촌 연구의 인구밀도 U자형 관계, 수도권 도시열·녹지 연구, 7개 도시의 시기별 영향변화는 단일 지역가중치와 영구 지역계수가 부적절함을 뒷받침함. 병상·쉼터·녹지·냉난방·이동지원은 현재 자료로 직접 확인함.
- 같은 도시명 아래에도 특보구역, 5km 격자, 대표 AWS/ASOS, PM 예보권역, 대기질 측정소, 평년지점, 도로·하천·해역이 다른 공간단위임. API의 regionName 하나로 이들을 합치지 않음.
- 지점·경로·polygon·시설·도로·해역의 대상공간과 시간을 먼저 정하고 공식구역 매칭, 점/격자 대표성, 경로분할, 공식 지역기준, 평년·연구맥락, 7-17 개인화 순으로 판단함. 경계불명·버전불일치·지원범위 밖은 판단보류 상태로 둠.
- 첫 출시에는 공식 지역기준 적용과 공간매칭까지만 채택하고 앱 자체 지역 수치모델은 두지 않음. 향후 특정 활동·결과 모델은 최신 국내 다지역자료, 지역/시간분리 검증, silent run, calibration·오탐/미탐·지역격차·유효기간을 모두 갖춘 별도 실험으로만 검토함.
- 공식 발표·관측·예보·지역구역 적용사실은 범위에서 확정형으로 표시하고 앱 내부 체감·피해·활동영향·행동조정은 지역과 무관하게 `달라질 수 있어요/도움이 될 수 있어요/판단하기 어려울 수 있어요` 가능성형만 사용함.
- spatialTarget/regionalBasisDecision 계약에 대상 geometry·정확도/프라이버시, 공식구역·경계버전·부분중첩, 격자·관측소·거리/고도/대표성, 예보권역과 측정소 역할, 평년지점/기간/이력, 경로구간, mapping state, 공식상태 불변과 연구 context-only를 포함함.
- 현행 Flutter는 nx=60/ny=121 수원을 하드코딩하고 서버 region catalog는 수원·서울 두 곳에 UVI areaNo와 AirKorea 측정소를 고정함. 공식 특보·영향예보·구역 Provider, 위경도/고도/경계버전·경로·평년·예보권역 모델이 없어 현재 구현으로 공식 지역차를 신뢰성 있게 적용할 수 없음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-18은 사용자 미확정 권장안이며 확정 전에는 다음 7-19 `계절별 기준 전환`으로 이동하지 않음. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 기준 채택 7-18 및 검토 7-19: 계절 전환 안내

- 사용자의 `확정 후 다음`에 따라 7-18 `지역별 기준 보정` 권장안을 최종 채택함. 공식 기관의 최신 지역별 제품기준·구역·단계는 그대로 적용하고, 앱이 지역명에 따른 공통 ±수치·위험단계 보정이나 주민 적응 추정을 더하지 않는 원칙을 유지함.
- 다음 7-19 `계절별 기준 전환`을 기상청 예보업무규정·체감온도 자료설명·생활기상지수, 질병관리청 온열/한랭질환 감시, 에어코리아 오존예보, 환경부 미세먼지 계절관리제, 국립기상과학원 꽃가루 달력, 국내 계절 내 더위·기온변동 연구와 현행 구현에 대조해 미확정 권장안으로 작성함.
- 사용자 화면명은 `계절 전환 안내`로 제안함. 앱 전체를 날짜 하나로 여름/겨울 모드 전환하지 않고 공식 제품 운영기간, 공식 산식 적용·병용기간, 기후통계 계절, 첫/급격한 실제 더위·추위 episode, 현상별 제공기간, 사용자 노출을 분리함.
- 공식 운영·발표·예보·관측·감시기간과 이번 운영기간 첫 공식 episode는 확인범위에서 확정형으로 표시함. 계절·초기노출을 이용한 앱 내부 체감·피해·활동영향·적응판단은 모두 가능성형으로만 표시함.
- 공식 제품의 운영·감시기간은 자료계약이지 현상의 발생 가능기간이나 안전기간이 아님. 기간 밖·새 연도 미공지·결측·서비스 종료·지원지역 밖·정상자료상 현상없음을 서로 다른 상태로 보존함.
- 기상청 예보업무규정상 습도형 체감온도는 5~9월, 풍속형은 10월~다음 해 4월에 우선 적용하되 기온변동이 큰 4~5월·9~10월에는 필요시 두 산식을 병용할 수 있음을 반영함. 전환기 결과는 방법별로 보존하며 평균·최댓값·최솟값 하나로 합치지 않음.
- 겨울형 체감온도는 기온 10℃ 이하·풍속 1.3m/s 이상 적용조건을 지키고, 조건 미충족·입력부족 때 실제 기온을 체감온도 필드에 복사하지 않음. 공식 제공값과 앱 계산값, 관측과 예보도 분리함.
- 2026년 질병관리청 온열질환 감시는 5월 15일~9월 30일, 2025~2026 한랭질환 감시는 12월 1일~다음 해 2월 28일임을 해당 연도 계약으로 기록함. 다음 연도 날짜를 자동 연장하지 않으며 감시기간 밖에도 실제 공식 고온·저온 자료와 생활 가능성안내를 끄지 않음.
- 국내 2011~2019년 65세 이상 연구의 초여름/늦여름 위험비 차이와 2022년 온열질환의 33%가 이른 폭염 시기에 발생했다는 분석은 계절 초 준비·몸상태 확인의 우선순위 근거로만 사용함. 날짜·기온·집단 RR을 개인 임계값·발생확률·적응완료일·공식단계 가중치로 사용하지 않음.
- 2-4의 `5~6월 첫 더위 추가 가중`은 월별 severity 가중이 아니라 같은 지역·공식제품에서 첫 공식 episode가 확인됐을 때 냉방·일정·몸상태·보호자 확인을 먼저 제안하는 `계절 초 준비 우선`으로 구체화함. 늦여름이라고 보호수칙을 자동 완화하지 않음.
- 첫 추위는 11월 1일 같은 달력 날짜가 아니라 채택된 공식 한파 영향예보의 전일/평년 대비 급락·지속저온 또는 실제 저온 episode를 사용함. 환절기도 봄/가을 라벨이 아니라 실제 일교차·전일대비 변화와 일정 교집합을 사용함.
- 에어코리아 오존예보 4월 1일~10월 31일은 공식 예보기간으로 기록하되 기간 밖 예보없음을 관측 0·좋음으로 처리하지 않음. 미세먼지 계절관리제는 정책상태이고 PM 공식 4등급을 바꾸지 않으며, 현행 UVI는 연중 표시하고 꽃가루 달력은 당일 관측으로 승격하지 않음.
- 비·호우·태풍·눈·결빙·블랙아이스(도로살얼음)·강풍은 전형적 계절 밖이어도 실제 공식 발표·관측·예보가 있으면 그대로 표시함. 계절명만으로 현상·피해를 만들거나 계절 밖이라는 이유로 규칙을 끄지 않음.
- `seasonalProductContract`와 `seasonTransitionDecision`에 제품·버전·운영기간·발표주기·산식조건/병용·기간 밖 의미, 공식 lifecycle, 방법별 결과와 미적용/결측, episode 연속성·첫 episode·급변근거, 연구 context-only, 준비 우선순위와 가능성 문구를 보존하도록 제안함.
- 현행 서버와 Flutter는 월 기준으로 5~9월 습도형/10~4월 풍속형 하나만 선택하고, 조건 미충족·입력부족 때 기온을 단일 apparentTemperature로 반환함. 공식 제품기간·산식버전·첫 episode·KDCA 감시·오존예보·꽃가루 Provider와 기간 밖/결측 상태가 없어 권장 전환을 구현할 수 없음.
- 제품 코드·최종 화면문구는 변경하지 않았고 기준 문서와 인계 기록만 수정함. 7-19는 사용자 미확정 권장안임. 7-19가 채택되면 7장 선택항목은 끝나므로 다음은 이미 개별 검토한 8장 항목을 되풀이하지 않고 전체 기준의 상충·중복 점검과 구현 우선순위 선정으로 전환하는 편이 적절함. 문서 전용 변경이므로 자동테스트·배포·커밋은 수행하지 않고 형식검증으로 마무리함.

### 문구·표현 기준서 신설 및 검토 1-1: 한 항목 안의 정보 배치

- 사용자가 수치·기준이 아니라 항목별 문구·표현방법을 별도로 순서대로 정리해 달라고 요청해 `docs/항목별_문구_표현_기준.md`를 신설함.
- 새 문서는 수치 기준을 다시 정하지 않고 채택된 판정을 `어떤 근거·확실성·어조·길이로 사용자에게 말할지`만 다룸. 수치 기준서는 판정조건, 새 문서는 사용자 표현을 담당하도록 역할을 분리함.
- 기존 대화에서 확정된 최상위 원칙을 새 문서에 상속함. 공식 발표·발효·예보·관측·해제는 확인범위에서 확정형, 내부 체감·피해 가능성·활동영향·행동선택은 가능성형, 사용자 직접기록은 기록사실만 확정형으로 둠.
- 공식 행동요령은 기관이 안내한 사실로 출처와 함께 전달할 수 있지만 앱이 고른 행동은 선택형·기대효과 가능성형으로 분리함. 명칭은 항상 `블랙아이스(도로살얼음)`로 통일함.
- 현행 서버에는 준비물 추천 7개 유형, 생활 메시지 36개 유형, 메인 브리핑 7개 장면/20개 템플릿과 별도 푸시조합이 있음. 버전 카탈로그·재현 가능한 후보선택·context/placeholder는 유지할 가치가 있음.
- 현행 문구는 주로 title+description 또는 완성문장만 저장해 공식 사실·내부해석·행동·근거가 분리되지 않음. `안전해요`, `위험이 있어요`, `좋아요`, `하세요`와 가능성형이 같은 후보군에 섞이고 알림 빌더가 명령형을 일괄 추가함.
- 새 문서의 검토순서는 공통 표현문법 1-1~1-13을 먼저 확정하고 기존 수치 기준서와 같은 기온·체감, 강수·적설·노면, 바람·습도, 자외선·대기, 생활행동, 출력·운영 순으로 항목별 문구를 검토하도록 정함.
- 첫 `권장안 1-1`은 각 항목을 `factLine`, `impactLine`, `actionLine`, `evidenceLine` 네 독립 슬롯으로 저장하는 구조임. fact는 공식/직접기록/검증 가능한 산술사실, impact는 가능성형, app action은 선택형, evidence는 기관·시각·구역·유효시간·자료상태를 담당함.
- 화면 제목은 `안전한 시간/위험한 도로/산책하기 좋은 시간` 같은 숨은 판단이 아니라 `강수/블랙아이스(도로살얼음)/산책계획/실내 건조` 같은 중립 label로 제안함.
- 카드·상세·준비물·푸시·접근성 읽기의 최소 슬롯을 구분하고, 문장 후보선택 seed가 확정형/가능성형 또는 제안/명령 강도를 바꾸지 못하도록 role과 certainty를 계약화함.
- 기존 문구의 구조 예시와 금지구조, 10개 검증 시나리오를 기록함. 개별 강풍·건조·산책·블랙아이스(도로살얼음) 예시는 1-1 구조 설명용이며 해당 항목의 최종 문구는 각 순서에서 다시 확정함.
- 제품 코드는 변경하지 않았고 새 문서·인계 기록만 작성함. 자동테스트·배포·커밋은 수행하지 않았으며 Markdown 형식만 검증함. 1-1은 사용자 미확정 권장안이고 확정 후 다음은 1-2 `근거 역할과 확실성 어미`임. 이전 수치 문서의 7-19도 사용자가 확정하지 않았으므로 권장안 상태를 유지함.

### 문구 기준 채택 1-1 및 검토 1-2: 근거 역할과 확실성 어미

- 사용자의 `확정해주고 다음`에 따라 1-1 `한 항목 안의 정보 배치`를 최종 채택함. 모든 항목은 factLine/impactLine/actionLine/evidenceLine을 독립 저장하고 공식·계산 사실→내부 영향 가능성→행동 선택지→근거 순으로 조합함.
- 제목은 `안전한 시간/위험한 도로/산책하기 좋은 시간` 같은 숨은 판단이 아니라 중립 label을 사용함. 슬롯이 없을 때 억지로 채우지 않고 홈·상세·알림 축약 뒤에도 공식/내부 역할과 확실성 수준을 유지함.
- 다음 1-2 `근거 역할과 확실성 어미`를 현행 준비물·생활·브리핑·알림 카탈로그의 어미 혼용 상태에 대조해 미확정 권장안으로 작성함.
- 현행 `예상돼요`는 공식 예보와 앱 추정을, `위험이 있어요`는 공식 단계와 내부 피해 가능성을 구분하지 못함. `안전해요/좋아요/무난해요/필요해요/중요해요`와 `하세요/해주세요/줄여요/미루세요`도 근거 역할 없이 섞여 있음.
- 문장 역할을 OFFICIAL_LIFECYCLE_FACT, OFFICIAL_OBSERVATION_FACT, OFFICIAL_FORECAST_FACT, OFFICIAL_GUIDANCE_FACT, CALCULATED_FACT, USER_RECORDED_FACT, RESEARCH_CONTEXT_FACT, INTERNAL_POSSIBILITY, APP_ACTION_OPTION, DATA_STATUS_FACT로 분리함.
- 공식 발표·발효·관측·예보·해제는 기관·제품·대상·시공간 범위에서 확정형으로 제안함. 공식 예보가 발표됐다는 사실은 확정하지만 미래 예측을 실제 발생·관측으로 바꾸지 않으며, 공식 피해예상 발표도 피해발생 확정으로 바꾸지 않음.
- 공식 주체가 문장에 들어갈 수 있으면 `기상청은 … 발표했어요/예보했어요` 같은 능동형을 우선함. 수동형을 쓸 때는 기관명을 가까이 두며 기관 없이 `관측됐어요/확인됐어요`만 단독 사용하지 않음.
- 앱 내부 체감·피해 가능성·활동영향은 `~할 수 있어요`, `~할 가능성이 있어요`, `~할 위험이 있어요`, `~하기 어려울 수 있어요`만 기본으로 사용함. `위험이 있어요`만 쓰지 않고 `미끄러질 위험이 있어요`처럼 결과를 밝히며 무근거 확률강도와 이중 가능성 표현을 금지함.
- 앱 행동제안은 `~하는 편이 도움이 될 수 있어요`, `~을 고려할 수 있어요`, `~을 확인해볼 수 있어요`로 제안함. 공식 행동요령은 기관이 안내한 사실로 출처와 대상을 밝히며, 법적 통제·운휴·대피명령은 원기관 상태를 임의로 약화하거나 앱의 일반명령으로 바꾸지 않음.
- 사용자 직접기록은 기록사실, 산술비교는 계산범위, 국내 연구는 집단연구에서 관찰된 사실까지만 확정형으로 사용함. 각각 원인·질환·안전·개인 발생확률·공식단계로 승격하지 않음.
- 결측·오래됨·충돌·지원범위 밖·새 자료 확인 중은 자료상태 자체를 확정형으로 표시하고 현재 현상·피해를 새로 확정하지 않음. 완전조회에서 유효 공식발표가 없더라도 조회범위의 부재만 표시하고 안전·위험없음으로 확장하지 않음.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 8개 항목에 role/어미 예시를 모두 넣음. 이는 공통 문법 예시이며 최종 항목별 카탈로그는 각 순서에서 다시 확정함.
- evidenceRole/certainty/subject/authority/predicate/scope/attribution/source/original official modality/endingKey/actionOrigin/prohibitedTransforms와 surface variant를 메시지 계약으로 제안하고 16개 검증 시나리오를 기록함.
- 제품 코드는 변경하지 않았고 문서와 인계 기록만 수정함. 자동테스트·배포·커밋은 수행하지 않고 Markdown 구조·표기를 검증함. 1-2는 사용자 미확정 권장안이며 확정 후 다음은 1-3 `공식 발표·발효·연장·변경·해제 문구`임. 이전 수치 문서의 7-19는 별도 미확정 상태를 유지함.

### 문구 기준 채택 1-2 및 검토 1-3: 공식 lifecycle 문구

- 사용자의 `권장안확정 다음 항목`에 따라 1-2 `근거 역할과 확실성 어미`를 최종 채택함. 공식 사실·직접기록·산술사실은 범위에서 확정형, 내부 체감·피해 가능성·활동영향은 가능성형, 앱 행동은 선택형으로 고정함.
- 다음 1-3 `공식 발표·발효·연장·변경·해제 문구`를 2026년 6월 1일 시행 현행 예보업무규정, 2026년 6월 30일 시행 기상법 시행령 제8조의2, 기상청 특보 종합과 2026년 6월 1일 해제예고 안내에 대조해 미확정 권장안으로 작성함.
- 예비특보는 예상 특보종류·구역·발표 예상시점을 미리 알리는 별도 공식제품이며 실제 특보 발표·발효로 승격하지 않음. 예상시점이 지나도 공식 통보문 없이 자동 발표하지 않음.
- 발표시각과 발효시각을 분리함. 발효 전에는 `발표했어요 · ○시부터 발효될 예정이에요`, 최신 공식확인 뒤 발효 중에는 `○시부터 발효 중이에요`로 표시함. 발효시각 결측에 발표시각을 복사하지 않음.
- lifecycle을 PRELIMINARY_NOTICE_PUBLISHED, PUBLISHED_NOT_EFFECTIVE, IN_EFFECT_CONFIRMED, LEVEL_REPLACED, AREA_CHANGED, EFFECTIVE_TIME_CHANGED, CLEAR_FORECAST_PUBLISHED/EXTENDED, OFFICIALLY_CLEARED, REISSUED_AFTER_CLEAR, LATEST_STATUS_UNCONFIRMED으로 분리함.
- 기관별 공식동사를 보존함. 기상청 특보의 발표/발효/변경·대치/해제예고/해제, 대기오염의 발령/해제, 도로의 통제/해제, 교통의 지연/운휴/재개를 서로 바꾸지 않음.
- `다시/연장/확대/축소/상향/하향`은 이전·현재 공식 event 관계가 확인됐을 때만 사용함. 원 action이 대치라면 저장하고 사용자 문구는 이전·현재 단계가 명확한 `주의보를 경보로 변경해 발표했어요`처럼 풀어쓸 수 있음.
- 해제예고는 해제 예상시간이지 실제 해제가 아님. 기상청 안내상 유지 중 연장되거나 예상보다 일찍 해제될 수 있으므로 해제예고 도달·cache 만료·앱 수치 하락으로 자동 해제하지 않고 최신 공식 해제 통보문 뒤에만 `해제했어요`를 사용함.
- 공식 해제 뒤에도 젖은 노면·블랙아이스(도로살얼음)·교통지연·시설복구 같은 후속 영향은 별도 근거에서 가능성형으로 계속 표시할 수 있음. 공식상태와 내부영향은 서로 on/off 조건으로 사용하지 않음.
- 최신 공식상태 재조회 실패 때 마지막 성공 확인 당시 발표·발효사실과 시각은 확정형으로 남기되 `현재 유지·변경·해제 여부를 다시 확인하고 있어요`로 분리함. API 오류·부분응답·빈 첫 페이지는 공식 해제가 아님.
- 홈·상세·푸시·잠금화면·접근성 표시를 구분하고 같은 bulletin 재수신은 새 발표알림을 만들지 않음. 발효 전 재알림은 별도 key로 둘 수 있지만 최신상태가 확인되지 않으면 발효 완료를 확정하지 않음.
- 강풍에는 기상청 특보 lifecycle, 블랙아이스(도로살얼음)에는 도로관리기관 관측·통제 lifecycle, 자외선에는 발표본·수정본, 출퇴근에는 도로통제·운휴 등 기관별 lifecycle을 적용함. 존재하지 않는 `기상청 블랙아이스(도로살얼음) 특보`나 자외선 주의보를 앱이 만들지 않음.
- officialLifecycleEvent/state 계약에 authority/product/version, bulletin/episode id, raw action/text, zone, issued/effective/clearedAt, previous/supersede relation, 해제예고 history, request completeness와 마지막 성공확인을 포함함.
- 현행 서버에는 공식 특보 Provider가 없고 WeatherWarning에는 발표/발효/해제시각·zone·bulletin/episode·예비특보·해제예고·대치관계가 없음. activeWarnings 결측도 빈 배열처럼 처리되고 Flutter lifecycle 화면·공식 푸시도 없어 현재 구현으로 권장 문구를 생성할 수 없음.
- 제품 코드는 변경하지 않았고 문서와 인계 기록만 수정함. 자동테스트·배포·커밋은 수행하지 않고 Markdown 구조·명칭을 검증함. 1-3은 사용자 미확정 권장안이며 확정 후 다음은 1-4 `공식 관측·예보와 앱 산술비교 문구`임. 이전 수치 문서의 7-19는 별도 미확정 상태를 유지함.

### 문구 기준 채택 1-3: 예비특보 문구 수정

- 사용자의 요청에 따라 1-3의 예비특보 사실 문구를 `기상청은 내일 새벽 수원에 강풍특보 발표가 예상된다고 알렸어요`로 변경하고 1-3 `공식 발표·발효·연장·변경·해제 문구`를 최종 채택함.
- lifecycle table과 예비특보 상세 예시 두 곳을 같은 문구로 통일함. 제목 `강풍 예비특보`, 공식 발표시각·예상 특보종류·구역·발표 예상시점, 실제 특보 발표·발효와 분리하는 상태계약은 유지함.
- 예비특보 예상시점이 지나도 공식 통보문 없이 특보를 자동 발표하지 않고, 해제예고도 실제 해제가 아니라는 1-3의 나머지 기준을 그대로 채택함.
- 제품 코드는 변경하지 않았고 문서·인계 기록만 수정함. 자동테스트·배포·커밋은 수행하지 않고 문구 일치와 Markdown 형식을 검증함. 다음 검토항목은 1-4 `공식 관측·예보와 앱 산술비교 문구`이며 아직 권장안을 작성하지 않은 대기 상태임.

### 문구 검토 1-4: 공식 관측·예보와 앱 산술비교

- 사용자의 `다음 항목` 요청에 따라 1-4 `공식 관측·예보와 앱 산술비교 문구`를 기상청 동네예보/초단기실황·AWS QC·단기예보 시간의미, 에어코리아 실시간 확정 전/최종확정자료, 기존 채택 7-14와 현행 구현에 대조해 미확정 권장안으로 작성함.
- 공식 관측은 기관·관측소/도로구간·요소·관측시각/집계구간·단위·QC/finality가 확인된 범위에서 `관측됐어요/측정됐어요/발생이 확인됐어요`로 확정 표시함. 대표 AWS·인근 측정소를 내 위치·도시 전체 관측으로 확장하지 않음.
- 공식 예보는 기관·발표시각·대상시각/interval·5km 격자/권역·요소를 밝히고 `예보했어요`로 확정함. 미래현상 발생은 확정하지 않고 대상시각이 지났다는 이유로 예보를 관측으로 승격하지 않음.
- 화면 label을 `현재 관측/현재시간대 예보/앞으로의 예보/앱 계산`으로 분리함. 현재 관측이 없으면 예보를 대체표시할 수 있지만 `현재 관측`이나 실제발생처럼 말하지 않음.
- 앱 산술은 같은 요소·단위·공간·시간해상도·interval semantics와 입력상태가 맞을 때 `비교하면`으로 계산범위에서 확정형 표시함. 공식 산식을 앱에서 재계산한 값도 `앱 계산`으로 표시하며 공식 관측·공식 제공값·공식단계로 승격하지 않음.
- 계산된 값의 차이·합계·최대/최소는 재현 가능한 산술사실로 둘 수 있지만 체감·피해·활동영향은 별도 possibility role로 `~수 있어요`를 유지함. 비교조건이 맞지 않으면 결과를 만들지 않고 비교불가 이유를 표시함.
- 기상청 공식안내상 초단기실황은 5km 격자별 대표 AWS 관측이고 초단기/단기예보와 별도 제품임. AWS QC 0 정상/1 오류/9 결측과 지점 위치이력을 보존하고 오류·결측을 0·정상관측으로 바꾸지 않음.
- 기상청 단기예보의 정시 기온 point와 표시시각 이전 1시간 날씨·강수량 interval을 구분함. 같은 `15시` 표기만으로 순간값·구간값을 합치지 않음.
- 에어코리아 측정소 실시간값은 `실시간 확정 전 자료`, 역사자료는 `최종확정자료`로 분리함. 측정소·측정시각·장비/품질상태 없이 권역 전체 현재값으로 확정하지 않음.
- 관측과 당시 예보가 다르면 두 값을 보존하고 일반 화면에는 `관측과 예보가 달라요`로 사실만 표시함. 맞음/틀림은 같은 요소·공간대응·집계구간·lead time·품질을 갖춘 공식 검증조건에서만 제한적으로 계산함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 8개 항목에 공식 관측/예보와 앱 비교·영향 문구 예시를 모두 넣음. 최종 항목별 카탈로그는 각 순서에서 다시 확정함.
- weatherEvidence/evidenceComparison 계약에 role/state, station/grid/zone/road, observed/issued/valid interval, QC/finality, spatial relation, derived refs/formula/rounding, 비교가능성·불가사유를 포함함.
- 현행 서버·Flutter는 단기예보 target을 observedAt에도 저장하고 첫 미래예보 슬롯을 current로 사용함. KMA 예보·UVI예보·AirKorea 관측을 한 snapshot에 합치며 field provenance가 사라지고 예보 기반 current를 과거 관측처럼 저장해 현재/어제/작년 문구를 신뢰성 있게 만들 수 없음.
- 제품 코드는 변경하지 않았고 문서와 인계 기록만 수정함. 자동테스트·배포·커밋은 수행하지 않고 Markdown 구조·명칭을 검증함. 1-4는 사용자 미확정 권장안이며 확정 후 다음은 1-5 `내부 체감·피해 가능성·활동 영향 문구`임. 이전 수치 문서의 7-19는 별도 미확정 상태를 유지함.

### 문구 기준 채택 1-4: 관측·예보 불일치 문구 수정

- 사용자 요청에 따라 관측과 당시 예보가 다른 경우의 문구를 연결형 세 문장으로 변경하고 1-4를 채택 상태로 확정함.
- 채택 문구: `오후 2시 수원 AWS에서 비가 관측됐으나,` → `오전 11시 발표 예보에는 오후 2시 무강수로 예보됐어요` → `관측과 당시 예보가 달라요`.
- 공식 관측과 당시 공식 예보의 내용은 출처·지점·시각 범위 안에서 확정적으로 안내하되, 예보의 정오 판단은 하지 않는 기존 원칙을 유지함.
- 제품 코드는 변경하지 않았고 문서·인계 기록만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 다음 검토항목은 1-5 `내부 체감·피해 가능성·활동 영향 문구`임.

### 문구 검토 1-5: 내부 체감·피해 가능성·활동 영향

- 사용자의 `다음 항목` 요청에 따라 1-5 `내부 체감·피해 가능성·활동 영향 문구`를 미확정 권장안으로 작성함.
- 새 수치나 단계를 만들지 않고 기존 채택 기준의 국내 연구·리서치·최근 피해사례를 표현 근거로 연결함. 집단 관련성을 현재 개인 피해확률·진단·원인·확정 결과로 바꾸지 않음.
- 내부 판단을 `체감 가능성`, `현상·상태 형성 가능성`, `구체적 피해 가능성`, `활동 영향 가능성`으로 나누고 각각 `느껴질 수 있어요`, `형성될 가능성이 있어요`, `미끄러질 위험이 있어요`, `하기 어려울 수 있어요`를 쓰도록 제안함.
- `위험이 있어요`는 단독으로 쓰지 않고 미끄러짐·낙상·파손·낙하처럼 구체적 결과가 있을 때만 사용함. 단순 불편·부담·활동제약에는 `불편할 수 있어요/부담이 커질 수 있어요/하기 어려울 수 있어요`를 사용함.
- 내부 문장에 대상·위치·시간·활동·조건·결과를 남기고 실제 사용자 일정·경로·실외 빨래·산책·취침시간과 자료 유효구간이 겹칠 때만 생성하도록 함. 조건 미충족은 `안전/괜찮음/영향 없음`이 아니며 영향문구 생략 또는 판단곤란으로 처리함.
- `조금·크게·매우·높은 가능성`은 채택된 단계·검증된 보정·직접기록 없이 붙이지 않고, `더/덜/상대적으로`는 같은 범위의 비교가 성립할 때만 사용함. 공식 `높음·매우높음·위험`을 내부 피해 가능성 강도로 복사하지 않음.
- 여러 근거가 같은 활동의 같은 결과를 만들면 조건절로 합칠 수 있지만 서로 다른 결과·위치·시간·대상은 포괄적인 `오늘 위험해요`로 병합하지 않음. 카드 대표 영향 1개, 상세 보조 영향 1개를 권장함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경의 내부 가능성 예시와 금지 변환을 모두 작성함.
- 자외선은 공식 UVI를 즉시 느끼는 더위·따가움 단계로 바꾸지 않고, 반려견은 사람 기준·주관적 감각을 복사하지 않으며, 수면환경은 외기 예보를 침실 측정·수면결과로 확장하지 않도록 함.
- 현행 서버의 `이동하기 좋아요/산책은 ○○가 좋아요/실내 건조가 안전해요/동파 위험이 있어요`와 알림의 일괄 `이동할 때 주의하세요`는 후속 구현 교체 대상으로 기록함. 제품 코드는 변경하지 않음.
- 자동테스트·배포·커밋은 수행하지 않고 Markdown 구조·명칭·상태를 검증함. 1-5는 사용자 미확정 권장안이며 확정 후 다음은 1-6 `공식 행동요령과 앱 행동제안 문구`임.

### 문구 검토 1-5 보완: 실제 상황·자연스러운 표현·직접 해결책

- 사용자가 `오후 야외 이동`의 이동대상과 실제 균형영향을 뒷받침하는 풍속조건이 불명확하고, 문구는 기준상 실제 일어날 수 있는 상황을 자연스럽게 말하며 가능한 경우 직접 해결책을 제시해야 한다고 지적함.
- `이동/야외활동/주의` 같은 포괄어를 금지하고 보행·자전거·개인형 이동장치·승용차·대형차·산책·빨래 회수 등 실제 수단·활동명으로 바꾸도록 1-5를 수정함. 수단·경로·노출조건이 없으면 영향문구를 만들지 않음.
- 기존 채택 4-4를 다시 연결함. 보행은 `(평균풍속 예보 ≥9m/s OR 공식 최대순간풍속 ≥10m/s OR 공식 돌풍 가능성·강풍특보)`와 교량·해안·개방지·도심협곡·젖거나 언 노면·큰 짐·유아동반·이동보조기구 중 하나가 같은 구간·시간에 겹칠 때 `몸이 흔들릴 수 있어요`를 사용함.
- 위 `9·10m/s`는 사전 영향신호이지 걷기 어려움·사고·통행금지선이 아니므로 `걷기 어려울 수 있어요`까지 높이지 않음. 해당 건물의 보행자 높이 현장센서·풍동·CFD에서 1시간 평균 `15m/s 이상`이 확인된 경우에만 `이 건물 주변에서는 바람 때문에 걷기 어려울 수 있어요`를 사용함.
- 자전거, 대형·고상차량, 승용차를 각각 노출구간·횡풍조건과 연결하고 일반 격자 평균풍속만 있을 때 활동영향과 해결책을 생성하지 않도록 함.
- 1-5 문장 구조를 `수치/공식상태 → 실제 사용자 상황 → 구체적 영향 가능성 → 직접 해결책`으로 변경함. 영향·피해·체감·활동판정은 기존대로 가능성형을 유지하되 저부담·가역적이고 실행 가능한 해결책은 `챙기세요/들여놓으세요/피하세요/확인하세요`로 직접 표시함.
- 직접 해결책은 판정수치·유효시간·적용위치, 사용자 대상·계획, 실행가능성, 낮은 비용·가역성, 원자료에 맞는 마감 정밀도가 확인된 경우에만 사용함. 고비용·의료·수의사 판단·일정취소는 계속 선택형 또는 원기관/전문가 확인으로 둠.
- 사용자 예시의 취지를 `오후 4시부터 실외 빨래가 비에 젖을 수 있어요 · 오후 4시 전에 실외 빨래를 실내로 들여놓으세요`로 반영함. `실내로 옮기는 편이 도움이 될 수 있어요`처럼 해결책을 돌려 말하지 않고 원자료보다 정밀한 임의 마감도 만들지 않음.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 표를 `생성에 필요한 실제 상황/권장 영향문구/직접 해결책` 구조로 전면 교체함.
- 새 지침과 충돌하던 채택 1-1·1-2의 actionLine도 함께 보완함. 앱 직접행동 role을 추가하고 저부담 예방행동에는 직접형을 허용하되 영향의 가능성형, 공식·내부 역할분리, 근거 없는 강제 금지는 유지함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-5는 여전히 사용자 미확정 권장안임.

### 문구 기준 채택 1-5 및 다음 1-6 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-5 `내부 체감·피해 가능성·활동 영향 문구`를 채택 상태로 확정함.
- 1-5는 체감·형성·피해·활동영향을 가능성형으로 유지하되 `이동/야외활동/주의` 같은 포괄어를 실제 수단·활동·해결동사로 바꾸고, 기준·사용자 상황·실행가능성이 확인된 저부담 해결책은 직접형으로 표시하는 최종 보완안을 포함해 채택함.
- 다음 1-6 `공식 행동요령과 앱 행동제안 문구`를 미확정 권장안으로 작성함.
- 행동 출처를 `OFFICIAL_ORDER_CONTROL`, `OFFICIAL_GUIDANCE`, `EXPERT_OR_USER_PLAN`, `APP_DIRECT`, `APP_OPTION`으로 구분함. 공식 통제·명령·행동요령은 기관·대상·구역·시각·원문 강도를 보존해 확정 안내함.
- 공식 원문의 `유의·권고·자제·피해야 함·금지·통제·대피·신고`를 같은 `주의하세요`로 합치거나 앱이 임의 강화·완화하지 않도록 함.
- APP_DIRECT는 영향기준·대상·시공간·실행가능성·저부담·가역성·자료해상도·공식지침 비충돌이 확인된 경우에만 `챙기세요/들여놓으세요/피하세요/확인하세요`로 직접 표시함. 행동효과와 안전은 가능성형으로 남김.
- 사용자의 `실내 빨래를 들여야 해요` 취지는 `오후 4시 전에 실외 빨래를 실내로 들여놓으세요`처럼 마감과 실행동사가 자연스러운 직접문구로 반영함. 공식 의무가 아니면 출처가 불명확한 `~해야 해요`보다 구체적인 직접동사를 우선함.
- 일정취소·고비용 교통수단 변경·의료·수의사 판단·장기 활동중단·공식 통행금지는 앱이 단독으로 직접 명령하지 않고 비교선택 또는 원기관·전문가 계획 확인으로 분리함.
- 행동 우선순위를 `공식 대피·통제·금지·운휴 → 공식 행동요령 → 등록된 전문가·개인 계획 → APP_DIRECT → APP_OPTION`으로 정함.
- 비와 낙뢰의 우산/비옷, 강풍·낙뢰와 옥상 빨래회수, 침수통제와 최단경로, 나쁜 대기질과 창문환기, 반려견 이상행동과 일반 산책후보, CO경보기와 냉난방 조절의 충돌·억제 예시를 작성함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 여덟 항목에 공식 행동·앱 직접 해결책·직접형 억제조건을 모두 넣음.
- 현재 추천·생활 템플릿과 알림 빌더는 행동 출처·원문강도·적용대상·실행가능성·충돌 억제 구조가 없으므로 후속 구현대상으로 기록함. 제품 코드는 변경하지 않음.
- 자동테스트·배포·커밋은 수행하지 않고 문서 구조·상태·명칭을 검증함. 1-6은 사용자 미확정 권장안이며 확정 후 다음은 1-7 `사용자 직접기록과 원인 추정 문구`임.

### 문구 검토 1-6 보완: 조건부 직접행동 표현 수정

- 사용자 요청에 따라 반려견 산책 직접행동을 `가능하다면 산책시간을 오후 8시로 옮기세요`로 변경함.
- 출퇴근 우회 직접행동을 `우회할 수 있다면 ○○지하차도를 피해서 △△도로로 가세요`로 변경함.
- 수면환경 직접행동을 `잠들기 전에 냉방이나 제습으로 수면 환경을 조절하세요`로 변경함.
- 같은 예문이 1-5의 항목별 표, 1-6의 직접행동 예시·여덟 항목 표·모호한 표현 교체표에 중복돼 있어 모두 같은 문구로 통일함.
- 반려견 산책과 출퇴근 경로는 사용자의 일정·대체경로·접근성에 따라 실행할 수 없는 경우가 있으므로 `가능하다면/우회할 수 있다면`을 문장 안에 남김. 수면환경은 사용자에게 친숙한 대상명 `수면 환경`을 사용함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-6은 사용자 미확정 권장안 상태를 유지함.

### 문구 기준 채택 1-6 및 다음 1-7 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-6 `공식 행동요령과 앱 행동제안 문구`를 채택 상태로 확정함.
- 1-6은 공식 통제·명령, 공식 행동요령, 등록된 전문가·개인 계획, 앱 직접 해결책, 앱 선택제안을 구분하고 공식 원문강도와 행동 우선순위·충돌억제·직접형 조건을 유지한 최종 보완안을 포함해 채택함.
- 다음 1-7 `사용자 직접기록과 원인 추정 문구`를 미확정 권장안으로 작성함.
- 사용자 직접기록을 계획·행동·느낌·사용자 관찰·보호자 관찰·결과·자원·변화없음·잘모름으로 구분하고 `사용자가 그렇게 입력했다는 사실`만 `기록했어요`로 확정하도록 함.
- 계획→출발→완료, 우산 휴대→사용→젖음→건조, 빨래 회수 시작→일부회수→전체회수→마름·보관을 자동 전환하지 않으며 알림 열기·스누즈도 행동완료로 처리하지 않도록 함.
- 사용자 입력은 `기록했어요`, 검증된 센서는 `측정됐어요`, 공식기관은 `관측됐어요/확인됐어요`로 역할동사를 분리함. 보호자 관찰은 당사자의 주관적 체감·진단으로 바꾸지 않음.
- 원인상태를 `SAME_TIME_CONTEXT_ONLY`, `RELATED_POSSIBILITY`, `MULTIPLE_CAUSES_POSSIBLE`, `CAUSE_UNDETERMINED`, `PERSONAL_PATTERN_POSSIBLE`, `OFFICIAL_CAUSE_CONFIRMED`로 구분함.
- 같은 시간·장소의 공식 날씨와 직접기록은 각각 확정하되 원인은 `관련이 있을 수 있어요/영향을 줬을 수 있어요/이 기록만으로 판단하기 어려울 수 있어요`로 분리함. `~때문에/~덕분에/~로 생겼어요/~가 막아줬어요`는 앱 원인문구에서 금지함.
- 사용자 자유입력에 원인 주장이 있으면 사용자 진술로 인용할 수 있지만 앱이 확인한 원인으로 바꾸지 않음. `평소와 비슷해요`, `잘 모르겠어요`, 질문 건너뜀, 알림 무응답도 서로 다른 상태로 보존함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 여덟 항목의 직접기록·원인 가능성 예시를 작성함.
- 응급 관련 직접기록은 원인추정보다 1-6의 공식 행동요령을 먼저 표시하고, 반복 직접기록은 다음 질문·후보순서를 개인화할 수 있어도 공식 단계·수치기준·진단을 바꾸지 않도록 함.
- 현행 앱·서버에는 직접기록 사건모델·API·입력 UI가 확인되지 않아 후속 구현대상으로 기록함. eventAt/recordedAt·기록주체·대상·완료범위·수정삭제·동의범위를 분리하는 데이터계약을 제안함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-7은 사용자 미확정 권장안이며 확정 후 다음은 1-8 `결측·오래된 자료·충돌·미지원 문구`임.

### 문구 기준 채택 1-7 및 다음 1-8 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-7 `사용자 직접기록과 원인 추정 문구`를 채택 상태로 확정함.
- 1-7은 계획·행동·느낌·사용자/보호자 관찰·결과·자원·변화없음·잘모름을 기록범위에서 확정하고 공식관측·센서측정과 역할동사를 분리하며, 원인·효과·진단은 가능성형으로 유지하는 권장안을 그대로 채택함.
- 다음 1-8 `결측·오래된 자료·충돌·미지원 문구`를 미확정 권장안으로 작성함.
- 자료상태 자체는 `수신되지 않았어요/제공되지 않아요/이전 자료예요/서로 달라요`처럼 이유·범위·시각을 확정형으로 표시하고, 그 자료가 필요한 체감·피해·활동영향은 `판단하기 어려울 수 있어요` 가능성형으로 분리함.
- 명시적 숫자 0, 기관이 명시한 현상없음, 표시한계 미만, 기관 자료없음 응답, 앱 미수신, 필드누락, 제품 미제공, 해당없음을 서로 다른 상태와 문구로 나눔. `없어요`에는 반드시 자료·발표·항목 등 대상을 붙임.
- 요청상태를 완전수신·부분수신·기관 자료없음·Provider 장애·요청거절·범위 미지원·위치권한 미부여로 구분하고, 일시장애와 미지원을 바꾸어 말하지 않도록 함.
- QC 오류·결측·파싱불가·실시간 미확정·최종확정·센서상태 미확인을 분리하고, 결측 자체로 위험을 가정하거나 정상·0으로 채우지 않도록 함.
- 이전자료는 원 관측/발표시각·생산주기·유효구간·다음 예정자료를 기준으로 `새 자료 확인 중/이전 자료/적용시간 지남/최신본에 대치됨/과거자료`를 구분함. 절대시각을 표시하고 stale 자료로 새 내부판정·APP_DIRECT·푸시를 만들지 않음.
- 공식 특보·통제·운휴는 오래됐다는 이유로 해제하지 않고 최신 전체조회 실패 때 `마지막 확인 당시 상태 + 현재 재확인 필요`로 표시함. 실패·부분응답·캐시만료·해제예고를 공식 해제로 바꾸지 않음.
- 관측과 예보의 차이, 다른 역할·공간·시간의 자료, 같은 역할·구간의 실제 공식 충돌을 구분함. 실제 충돌은 기관·제품·발표시각·값을 병렬표시하고 평균·최댓값 임의선택 없이 내부판정을 보류함.
- 지역·도로·시간·요소 미지원, 앱 기능 미구현, 위치 불확실을 분리하고 인접지역·주변도로·마지막 값을 조용히 대체하지 않도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 여덟 항목의 구체적인 자료상태·판단보류·확인행동 문구를 작성함.
- 화면에는 `자료 확인 중/일부 자료/이전 자료/미지원` label과 원시각을 표시하고, 정상인 독립근거·공식상태는 다른 필드 결측 때문에 숨기지 않으며 stale·충돌·부분자료만으로 새 알림을 만들지 않도록 함.
- 현행 Provider·WeatherSnapshot·Flutter는 완전성·필드별 역할/품질/최신성/결측원인·충돌상태가 충분히 보존되지 않아 후속 구현대상으로 기록함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-8은 사용자 미확정 권장안이며 확정 후 다음은 1-9 `위치·시간·대상·출처 표시 순서`임.

### 문구 검토 1-8 보완: 다섯 자료상태 표현 수정

- 사용자 요청에 따라 1-8의 다섯 자료상태 표현만 수정하고 나머지 기준·상태·순서는 유지함.
- 기관 명시 없음: `오전 11시 발표에는 오후 3시 강수없음으로 예보됐어요`.
- 앱 미수신: `오후 4시 습도 자료를 받아오지 못했어요`.
- 품질오류: `오후 2시 풍속은 자료에 오류가 있어 확인이 어려워요`.
- 이전 자료: `마지막 관측은 오후 1시 50분 자료예요 · 현재 상태는 달라졌을 수 있어요`를 그대로 유지함.
- 출처 차이: `초단기예보 기준 오후 3시, 단기예보 기준 오후 5시부터 비를 예상했어요`.
- 같은 예문이 1-4의 품질오류 예시와 1-8의 상태표·영향예시·자연어 교체표에 반복돼 있어 지정한 표현으로 통일함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-8은 미확정 권장안 상태를 유지함.

### 문구 기준 채택 1-8 및 다음 1-9 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-8 `결측·오래된 자료·충돌·미지원 문구`를 최종 보완문구까지 포함해 채택 상태로 확정함.
- 다음 1-9 `위치·시간·대상·출처 표시 순서`를 미확정 권장안으로 작성함. 이 단계는 수치기준이 아니라 이미 만들어진 공식 사실·내부판정·행동을 어떤 정보순서로 표시할지 정함.
- 공식 발표·특보·통제는 기관을 주체로 밝히고, 공식 관측은 관측시각과 관측지점, 공식 예보는 적용지역과 대상시간, 내부판정은 실제 시간·장소·활동을 앞쪽에 두도록 역할별 어순을 분리함.
- 기본 표시를 `factLine → impactLine → actionLine → evidenceLine`으로 정하고 공식 사실은 확정형, 내부 체감·피해·활동영향은 가능성형, 근거가 확인된 저부담 해결책은 직접형으로 유지함.
- 현재 위치·공식 적용구역·예보격자·관측지점·경로구간·실내공간·사용자 기록장소를 별도 위치역할로 구분함. 관측지점을 현재 위치로, 예보격자를 관측지점으로, 경로 일부를 전체 경로로 바꾸지 않도록 함.
- 발표시각·발효구간·관측시각·예보 유효구간·행동마감·사용자 계획·사건시각·입력시각·조회시각을 구분하고 사용자 행동에 필요한 대상시간을 본문, 생산·조회시각을 근거줄에 두는 원칙을 정함.
- 공식기관·제품·관측망·도로관리기관·센서·사용자기록·앱 생활판정을 별도 출처역할로 보존함. 기관이 말하지 않은 내부판정을 기관 발언처럼 표시하거나 여러 예보시각을 평균내지 않도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 여덟 항목에 `사실 → 영향 가능성 → 행동 → 근거` 예시를 작성함.
- 현행 서버·Flutter에는 일부 시간필드와 측정소명이 있으나 공간·시간·대상·출처 역할을 문구까지 일관되게 유지하는 공통계약이 부족해 후속 구현대상으로 기록함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-9는 사용자 미확정 권장안이며 확정 후 다음은 1-10 `제목·요약·상세·근거 줄의 길이와 역할`임.

### 문구 기준 채택 1-9 및 다음 1-10 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-9 `위치·시간·대상·출처 표시 순서`를 채택 상태로 확정함.
- 다음 1-10 `제목·요약·상세·근거 줄의 길이와 역할`을 미확정 권장안으로 작성함. 푸시·잠금화면·접근성 전용 표현은 다음 1-11로 분리함.
- 제목은 결론이 아닌 중립 항목명으로 고정하고 여덟 항목을 `강풍`, `블랙아이스(도로살얼음)`, `자외선`, `비와 우산 준비`, `빨래 회수`, `반려견 산책계획`, `출퇴근 경로`, `수면환경`으로 명시함.
- 요약은 공식 긴급상태 → 임박한 직접행동 → 구체적 영향 가능성 → 공식사실 → 판정을 막는 자료상태 순으로 검증된 역할문장 하나를 선택하도록 함. 사실·영향·행동을 요약용 새 문장으로 섞지 않음.
- 상세는 `factLine → impactLine → actionLine → dataStatusLine → evidence` 순서의 완결문장·요소로 나누고, 근거는 기관·제품·시각·공간·자료상태를 식별하는 미리보기와 전체보기로 분리함.
- 항목 label, 요약, 역할문장, 근거 미리보기, 상태 label, 버튼에 작성 예산을 제시하되 글자 수를 서버 강제 자르기 기준으로 사용하지 않고 실제 기기 폭·글꼴·글자크기로 검증하도록 함.
- 공간이 부족하면 반복 메타데이터와 보조역할을 상세로 옮기고 카드 높이·줄수를 조절하며, 부정·가능성 어미·공식 생명주기·대상시간·도로구간·행동마감·오래된 자료시각·출처충돌은 생략하지 않도록 함.
- 서버 말줄임 저장, 문장 중간 절단, `수 있어요` 삭제, 명사형 확정결론으로 축약, 공식자료 평균화, `블랙아이스(도로살얼음)` 명칭축약을 금지함.
- 여덟 항목에 중립 제목, 카드 요약, 상세 사실·영향·행동, 근거 미리보기 예시를 작성함. 카드 요약이 행동문장이어도 상세 영향은 가능성형으로 유지함.
- 현행 `title + description`, Flutter의 1·2줄 말줄임, 상세의 설명+수치 결합, 알림의 제목 일괄연결·임의 당부 추가는 역할과 확실성을 보존하기 어려워 후속 구현대상으로 기록함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-10은 사용자 미확정 권장안이며 확정 후 다음은 1-11 `푸시알림·잠금화면·접근성 읽기 문구`임.

### 문구 기준 채택 1-10 및 다음 1-11 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-10 `제목·요약·상세·근거 줄의 길이와 역할`을 채택 상태로 확정함.
- 다음 1-11 `푸시알림·잠금화면·접근성 읽기 문구`를 미확정 권장안으로 작성함.
- Android 공식 알림 디자인·잠금화면 공개범위, Apple 알림·미리보기 지침, Flutter 접근성·큰 글자 지침을 2026-08-27 기준으로 확인하고 공식 링크를 문서에 기록함. Android 제목 30자·본문 40자는 편집목표로만 사용하고 의미를 자르는 하드 제한으로 사용하지 않음.
- 푸시 하나에는 공식상태·내부영향·직접행동 중 하나를 제목에, 그 이유가 되는 공식사실·가능성형 영향·구체적 행동 하나를 본문에 두도록 함. 앱 이름·`알림`·포괄 `주의` 반복과 여러 제목의 `·` 연결을 금지함.
- 공식 특보·통제·운휴·해제는 기관·공식명칭·발표/발효 상태를 확정 안내하고, 앱 내부알림은 `수 있어요` 가능성형 또는 조건이 확인된 직접행동으로 분리함. 앱 내부 단계에 `주의보/경보/통제/운휴`를 붙이지 않음.
- 잠금화면 privacy state를 일반공개·개인맥락·민감기록으로 나누고 정확한 집·회사·경로·반려견·산책계획·빨래상태·수면·방센서·건강/수의사 기록은 기본 공개문구에서 가리도록 함. 운영체제 미리보기 설정을 우선함.
- 지연도착을 고려해 `곧/지금`만 쓰지 않고 대상·마감·만료시각을 보존하며, 같은 사건은 event/collapse 관계로 갱신함. 시간경과·조회실패를 공식 해제나 안전으로 바꾸지 않음.
- 알림 버튼을 `행동요령 보기/우산 챙김/빨래 회수/산책시간 변경/대체경로 보기/실내 상태 확인`처럼 대상+동사로 작성하고 탭·열람·미루기·전송성공을 행동완료와 분리함.
- TalkBack·VoiceOver 읽기순서를 제목→상태→사실→영향→행동→근거→버튼으로 정하고 `오후 3~5시`, `9m/s`, `32℃`, `72%`, `수원 AWS`, `블랙아이스(도로살얼음)`의 자연어 semantic label을 제안함.
- 큰 글자에서는 글자배율을 낮추지 않고 카드확장·세로배치·상세이동으로 대응하며 가능성 어미·부정·행동마감·자료상태·공식명칭을 숨기지 않도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경의 전체 푸시 제목·본문·잠금화면 공개문구 예시를 작성함.
- 현행 서버 FCM 전송과 설치별 추천조회는 TODO/placeholder이고 Flutter에도 푸시수신·플랫폼 권한/채널 설정이 없어 실제 푸시는 미구현임. 문구계약만 작성하고 제품 코드는 변경하지 않음.
- 자동테스트·배포·커밋은 수행하지 않음. 1-11은 사용자 미확정 권장안이며 확정 후 다음은 1-12 `명칭·용어·존댓말·친근감·금지 표현`임.

### 문구 검토 1-11 보완: 직접행동·영향 우선 노출

- 사용자 요청에 따라 카드·푸시·잠금화면의 첫 노출을 공식 사실·상태보다 `실행 가능한 직접행동 → 구체적인 영향 가능성` 순으로 변경함.
- 사용자가 문구를 보고 들어온 앱 상세 상단에서 공식기관·공식상태·관측/예보사실·적용구역·발표/발효시각을 먼저 확인하고, 그 아래 영향근거·행동·전체출처를 보도록 1-1·1-3·1-9·1-10·1-11을 함께 보완함.
- 공식 대피·금지·통제에 즉시 행동이 포함돼 있으면 그 공식 행동을 앱 직접행동보다 우선함. 근거 있는 행동·영향을 만들 수 없을 때는 문구를 지어내지 않고 공식상태 자체를 푸시하는 fallback을 유지함.
- 푸시 제목과 본문을 `직접행동 + 영향 가능성` 또는 `영향 가능성 + 직접행동`으로 짝지음. 공식 사실·현재 상태는 `officialFactRef/deferredOfficialFactRefs`로 연결하고 알림 deep link의 상세 첫 영역에서 표시함.
- 예보변경·자료오래됨·출처충돌 알림도 `다시 확인하세요` 행동과 `판단하기 어려울 수 있어요` 영향을 먼저 표시하고 제품별 공식시각·마지막 관측시각은 상세에서 확인하도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경 예시표를 `푸시 행동/영향 → 잠금화면 공개문구 → 상세 상단 공식사실·상태` 구조로 변경함.
- 제품 코드는 변경하지 않았고 문서·HANDOFF만 수정함. 자동테스트·배포·커밋은 수행하지 않음. 1-11은 사용자 미확정 권장안 상태를 유지함.

### 문구 기준 채택 1-11 및 다음 1-12 검토

- 사용자의 `확정 후 다음` 요청에 따라 직접행동·영향 우선 노출 보완까지 포함한 1-11 `푸시알림·잠금화면·접근성 읽기 문구`를 채택 상태로 확정함.
- 다음 1-12 `명칭·용어·존댓말·친근감·금지 표현`을 미확정 권장안으로 작성함.
- 여덟 화면 제목을 `강풍`, `블랙아이스(도로살얼음)`, `자외선`, `비와 우산 준비`, `빨래 회수`, `반려견 산책계획`, `출퇴근 경로`, `수면환경`으로 고정하고 본문용 띄어쓰기·용어와 금지 변형을 정함.
- 공식 특보 발표/발효/예비특보/관측/예보/강수없음/통제, 센서측정, 사용자기록의 역할동사와 사용자용 확정형 문구를 사전으로 정리함.
- 앱 기본문체를 해요체로 두고 공식사실 `~했어요/됐어요`, 내부영향 `~수 있어요/~할 위험이 있어요`, 직접행동 `~하세요`, 조건부 행동 `가능하다면/우회할 수 있다면 + ~하세요`, 앱 재확인 `~할게요`로 역할별 종결을 분리함.
- 일반 문구에서 `당신/고객님/사용자님`을 쓰지 않고 `반려견`, 필요할 때 `보호자`를 사용하며 `애완견/강아지/우리 아이`를 기본명칭으로 사용하지 않도록 함.
- 끈적함·눅눅함·꿉꿉함·후텁지근함·답답함·서늘함·쌀쌀함 등 친근한 체감어를 피부·침구·실내공기·열감·바람 등 실제 대상과 조건별 feelKey로 나누고 임의 동의어 교체를 금지함.
- `안전/좋음/무난/쾌적/최적`, 단독 `주의/조심/유의`, 대상 없는 `위험`, `필수/꼭/반드시`, 포괄 `이동/야외활동/주변/곧`의 문제와 구체적 대체문구를 정리함.
- 행동동사를 `챙기세요/들여놓으세요/고정하세요/피하세요/이용하세요/옮기세요/바르세요/조절하세요/확인하세요`로 구체화하고 `해주세요`보다 `하세요`를 기본으로 정함.
- 사용자 행동버튼의 `챙길게요` 계획, `챙겼어요/우산 챙김` 완료, `사용했어요` 실제사용, `30분 뒤 다시 알림` 재알림을 별도 기록범위로 구분함.
- `32℃`, `9m/s`, `72%`, `1mm 미만`, `자외선지수 8`, 시간범위·자정통과·AWS의 화면/음성 표기와 `·`·마침표·말줄임·이모지 규칙을 정함.
- 사용자 행동에는 친숙한 `선크림`, 공식 원문에는 `자외선 차단제`를 보존할 수 있게 하고 `선블록/썬크림/자차` 무작위 alias를 금지함.
- 동적 위치·기관·도로명에 맞는 한국어 조사 formatter와 unresolved placeholder 차단, canonical term/version·role ending·forbidden term lint 데이터계약을 제안함.
- 현행 카탈로그에는 `안전해요/좋아요/무난해요/주의하세요/이동/야외활동`과 여러 행동어미가 혼재해 후속 구현대상으로 기록함. 제품 코드는 변경하지 않음.
- 자동테스트·배포·커밋은 수행하지 않음. 1-12는 사용자 미확정 권장안이며 확정 후 다음은 1-13 `중복 병합·우선순위·메시지 계약·자동검증`임.

### 문구 기준 채택 1-12 및 다음 1-13 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-12 `명칭·용어·존댓말·친근감·금지 표현`을 채택 상태로 확정함.
- 다음 1-13 `중복 병합·우선순위·메시지 계약·자동검증`을 미확정 권장안으로 작성함.
- 현행 서버는 같은 추천/insight 유형에서 최고 priority·score 하나만 남기고, 폭설우선+점수순으로 정렬하며, 알림에서 여러 제목을 `·`로 연결하고 포괄 `이동할 때 주의하세요`를 추가함. 알림이력도 날짜+notification key와 앞 80자 payload hash만 사용해 사건·수명주기·의미변경을 구분하지 못하는 상태로 기록함.
- 처리순서를 `유효성 차단 → 사건 식별 → 역할별 중복제거 → 의미 병합 → 우선순위 → 노출면 선택 → 렌더링 → 자동검증 → 전송/표시`로 정하고 event/message/render 단위와 semantic/render hash를 분리함.
- 같은 event·역할·대상·활동·공간·시간·action/impact signature만 중복으로 보며, 다른 시간·장소·대상·출처·수명주기·행동 origin은 병합하지 않도록 함. 공식값 충돌은 병렬표시하고 내부판정을 보류함.
- 우선순위를 P0 공식 즉시행동, P1 마감 있는 직접행동, P2 구체적 영향 가능성, P3 공식상태 fallback, P4 자료 재확인, P5 보조근거로 정함. 같은 등급은 사용자계획 중첩·행동마감·공간중첩·대상구체성·근거품질·동일항목 판정강도·평가시각·고정순서로 결정함.
- 서로 다른 항목의 raw score를 같은 척도로 비교하지 않고 같은 항목·같은 rule version 후보 안에서만 사용하도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경이 겹치는 대표 병합·분리·우선노출 사례를 작성함.
- 공통 message contract에 event/episode/item 식별, 역할문장, evidence/basis refs, priority reasons, action/impact signature, semantic/render hash, surface/privacy/accessibility variants와 판정·카탈로그·용어·병합·우선순위 버전을 포함함.
- Schema·참조무결성·역할/확실성·고정용어·금지어·placeholder/조사·단위/시간·중복제거 성질·우선순위 재현·stale/conflict gate·알림 멱등성·스냅샷·개인정보·접근성·서버앱 호환 자동검증안을 정함.
- 제품 코드는 변경하지 않았고 자동테스트·배포·커밋은 수행하지 않음. 1-13은 사용자 미확정 권장안이며 확정 후 다음은 2-1 `실제 기온 문구`임.

### 문구 기준 채택 1-13 및 다음 2-1 검토

- 사용자의 `확정 후 다음` 요청에 따라 1-13 `중복 병합·우선순위·메시지 계약·자동검증`을 채택 상태로 확정함. 이로써 1-1~1-13 공통 표현문법 검토가 완료됨.
- 다음 2-1 `실제 기온 문구`를 미확정 권장안으로 작성하고 수치 기준 문서의 채택 2-1을 상속함. 실제 기온은 숫자 사실로 표시하고 덥다·춥다 체감, 폭염·한파특보와 분리함.
- 현행 서버의 `current`는 공식 관측이 아니라 기상청 단기예보에서 현재시각 30분 전 이후 구간 중 가장 앞선 `TMP` 슬롯을 복사한 값인데 Flutter가 `현재 기온`으로 표시함. 예보 snapshot에 `observedAt=forecastAt`을 함께 넣어 역할혼동 가능성이 있고, 결측 temperature를 Flutter가 0으로 바꿀 수 있음을 기록함.
- 공식 `TMN/TMX`가 없을 때 제공된 시간대 TMP의 min/max를 fallback으로 사용하지만 공식 일 최저·최고와 계산값을 구분하는 역할필드·계산범위가 없음을 기록함.
- 관측기온 `관측됐어요`, 예보기온 `예보했어요/예보됐어요`, 실내센서 `측정됐어요`, 사용자기록 `기록했어요`로 동사를 분리하고 관측시각/지점, 발표시각/대상시각/예보구역을 필수로 표시하도록 함.
- 예보 첫 슬롯은 `현재 기온`이 아니라 `오후 3시 예상기온 32℃` 또는 `기상청은 수원의 오후 3시 기온은 32℃라고 예보했어요`로 표시하도록 함. `현재 기온`은 freshness·공간범위를 확인한 공식 관측/센서 측정에만 제한함.
- 공식 TMN/TMX는 `오늘 최저/최고기온 예보`, 일부 슬롯의 계산값은 `오전 6시~오후 11시 예보기온 가운데 가장 낮은/높은 값`으로 구분하고 진행 중 관측극값에는 `오후 4시까지 관측된` 집계범위를 표시하도록 함.
- 관측문구를 `오후 2시 수원(관측지점기준)에서 기온 31.2℃가 관측됐어요`로 정하고, 관측과 당시 예보 비교도 같은 위치표기를 사용하도록 함. 같은 역할·공간·대상시각 비교만 허용함.
- 화면단위를 `32℃/-2℃/31.2℃`로 통일하고 접근성은 `섭씨 32도/영하 2도`로 읽으며 원자료·승인 반올림보다 정밀도를 늘리거나 줄이지 않도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경에서 실제 기온이 보조근거가 될 수 있는 범위와 단독 확정하면 안 되는 현상을 표로 정리함.
- temperatureRole, 값/정밀도, 관측/예보 시각·공간, 일 극값 역할·집계범위, 비교쌍, 자료상태, textKey/evidenceRefs를 포함한 실제 기온 데이터계약과 18개 검증 시나리오를 제안함.
- 제품 코드는 변경하지 않았고 자동테스트·배포·커밋은 수행하지 않음. 2-1은 사용자 미확정 권장안이며 확정 후 다음은 2-2 `체감온도 문구`임.

### 문구 검토 2-1 보완: TMP·AWS 사용자 표현 교체

- 사용자 요청에 따라 현재시각과 가까운 단기예보 TMP의 화면 요약을 `오후 3시 예상기온 32℃`로 변경함. `TMP`는 구현·근거 설명에만 남기고 사용자 화면에는 노출하지 않음.
- 관측문구를 `오후 2시 수원(관측지점기준)에서 기온 31.2℃가 관측됐어요`로 변경하고 2-1의 관측·극값·비교·출처차이 예시에 같은 위치표기를 적용함.
- 공식 예보문구는 `기상청은 수원의 오후 3시 기온은 32℃라고 예보했어요`로 변경함.
- 2-1에서 사용자용 축약표현은 `예상기온`, 상세 공식사실은 `기온 …로 예보했어요/예보됐어요`로 역할을 구분함.
- 제품 코드는 변경하지 않았고 자동테스트·배포·커밋은 수행하지 않음. 2-1은 사용자 미확정 권장안 상태를 유지함.

### 문구 검토 2-1 보완: 공식 기온예보 문장 변경

- 사용자 요청에 따라 2-1의 공식 예보 예문을 `기상청은 수원의 오후 3시 기온은 32℃라고 예보했어요`로 변경함.
- 예보기온 설명, 출처 포함문장, 상세 상단 예시에 반복된 기존 문구를 모두 같은 표현으로 통일함.
- 제품 코드는 변경하지 않았고 2-1은 사용자 미확정 권장안 상태를 유지함.

### 문구 기준 채택 2-1 및 다음 2-2 검토

- 사용자의 `확정 후 다음` 요청에 따라 TMP·관측지점·공식 예보문구 보완을 포함한 2-1 `실제 기온 문구`를 채택 상태로 확정함.
- 다음 2-2 `체감온도 숫자·계산출처 문구`를 미확정 권장안으로 작성함. 체감 느낌 표현은 2-3, 폭염·한파 피해·행동은 2-4·2-5로 분리함.
- 수치 기준의 채택 2-2를 상속해 실제 기온 `airTemperature`, 기상청 계산방식의 `kmaApparentTemperature`, 한국형 감각판정 `koreanPerceivedTemperature`, 공식 특보를 서로 다른 역할로 유지함.
- 현행 체감온도는 기상청이 직접 예보한 값이 아니라 단기예보 기온·습도·바람으로 서버/앱이 기상청 계산방식을 구현해 계산한 값임. 따라서 `기상청이 체감온도를 예보했어요`가 아니라 `기상청 계산방식으로 … 계산했어요`를 사용하도록 함.
- 예보입력 계산값은 `오후 3시 예상 체감온도 34.1℃`, 상세는 `기상청 계산방식에 수원의 오후 3시 예상 기온·습도·바람을 적용한 체감온도는 34.1℃예요`로 제안함.
- 관측입력 계산값은 체감온도 자체가 관측됐다고 하지 않고 `오후 2시 수원(관측지점기준)의 관측된 기온·습도·바람을 기상청 계산방식에 적용한 체감온도는 33.4℃예요`로 구분함.
- 공식 체감온도 예보제품을 실제로 받은 경우에만 `기상청은 수원의 오후 3시 체감온도는 34℃라고 예보했어요`처럼 공식동사를 사용하도록 함. 관측자료 기반 체감온도는 계산값이므로 체감온도 자체가 `관측됐어요`라고 표현하지 않도록 함.
- 예보입력 계산값에는 `현재 체감온도`를 사용하지 않고 공식/관측 현재값 또는 freshness를 통과한 관측입력 계산값에만 현재 label을 허용함.
- 계산완료·공식조건 비해당·기온/습도/바람 누락·품질오류·이전자료를 별도 calculationStatus로 구분하고, 필수입력 누락 시 실제 기온을 체감온도로 조용히 대입하지 않도록 함.
- 제공구간의 체감온도 min/max에는 집계 시작·종료와 발생시각을 표시하고 일부 시간대 최댓값을 `오늘 최고 체감온도`로 확대하지 않도록 함.
- 현행 aggregate snapshot이 다음 24시간 최댓값을 current apparentTemperature에 덮어쓰고 시각을 잃을 수 있는 점, Main이 기상청 계산값에 PT 임시경계·폭염 위험·근거부족 한랭 label을 함께 적용하는 점, weatherBrief가 결측을 실제 기온으로 대체하는 점을 후속 변경대상으로 기록함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경에서 사람용 체감온도의 사용범위와 단독 확정 금지문구를 정리함. 반려견에는 사람용 체감온도를 적용하지 않음.
- apparentTemperature 역할·계산출처/status/formula version·입력 evidence·관측/예보 시공간·구간극값·비교가능성·자료상태·문구 version을 포함한 데이터계약과 20개 검증 시나리오를 제안함.
- 제품 코드는 변경하지 않았고 자동테스트·배포·커밋은 수행하지 않음. 2-2는 사용자 미확정 권장안이며 확정 후 다음은 2-3 `덥고 춥고 끈적한 체감 문구`임.

### 문구 기준 채택 2-2 및 다음 2-3 검토

- 사용자의 `확정 후 다음` 요청에 따라 2-2 `체감온도 숫자·계산출처 문구`를 채택 상태로 확정함.
- 다음 2-3 `덥고 춥고 끈적한 체감 문구`를 미확정 권장안으로 작성함. 새 수치경계를 만들지 않고 채택된 한국형 체감단계와 고습 상태 key의 사용자 표현만 정함.
- Kang et al. 한국인 PT 연구, 서울·수원 야외 현장검증, 한국어 온열감 어휘연구, 한국 대학생 온습도 실험, 국내 기숙사·수원 시민과학 연구를 표현근거와 적용한계로 정리함.
- 내부 `Slightly warm/Warm/Hot`을 `조금 덥게/덥게/많이 덥게 느껴질 수 있어요`로 변환하고 `Neutral`은 `무난함` 대신 기본 알림을 만들지 않도록 함.
- 한국인 야외 한랭감각의 고정경계가 미채택이므로 현행 `10℃/0℃`만으로 `선선/쌀쌀/추움`을 자동 생성하지 않고, 검증된 한랭지수나 같은 맥락의 반복 직접기록이 있을 때만 가능성형 문구를 허용함.
- `후텁지근`은 따뜻하고 습한 공기·열감, `끈적`은 활동·발한근거가 있는 피부감, `눅눅`은 지속된 실내 고습의 공기·침구·옷, `꿉꿉`은 사용자 선호·반복기록이 있는 눅눅 상태의 대체어, `서늘하고 축축`은 낮은 실내온도+고습, `답답`은 CO2·환기·기류 또는 반복기록이 있을 때로 대상을 구분함.
- 대표 체감어는 반복된 개인기록 → 대상이 구체적인 표현 → 온습도 복합표현 → 한국형 체감단계 순으로 하나를 선택하고, 활동 관련 보조체감은 하나까지만 추가하도록 함. 가능한 체감어를 한 문장에 나열하거나 무작위 교체하지 않음.
- 실외 체감은 같은 격자·시간의 기온·습도·바람과 활동·노출공간, 실내 체감은 같은 방 센서·지속시간·국지 수분원을 사용하고 서로 대체하지 않도록 함.
- 직접기록은 `후텁지근했다고 기록했어요`처럼 과거 기록사실로 확정하되 다음 체감은 `느껴질 수 있어요`로 유지하고 같은 공간·계절·활동·기상조건의 반복기록만 개인화에 사용하도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경별 허용 체감문구와 연결 제한을 정리함. 사람용 체감지수를 반려견·노면·빨래·침실의 직접판정값으로 사용하지 않음.
- feelKey/family·대상·활동·공간·시간·온습도/바람/일사/센서/직접기록 근거·표현선호·품질·버전을 포함한 데이터계약과 22개 검증 시나리오를 제안함.
- 제품 코드는 변경하지 않았고 자동테스트·배포·커밋은 수행하지 않음. 2-3은 사용자 미확정 권장안이며 확정 후 다음은 2-4 `폭염·고온 피해·행동 문구`임.

### 2-3 한랭 생활체감 기준 재설계

- 사용자의 요청에 따라 2-3에서 보류했던 한랭 생활표현을 다시 검토하고 `선선하게/쌀쌀하게/춥게 느껴질 수 있어요`를 실제로 생성할 수 있는 `COLD_FEEL_KR_V1` 미확정 권장안을 추가함.
- 창원·대구 892명의 계절별 야외 현장설문에서 가을 `17.2~23.9℃`에 `Slightly cool~Warm`, 겨울 `4.6~6.5℃`에 `Slightly cool~Cold` 응답이 주로 나타난 결과, 기상청 날씨해설의 `쌀쌀` 실제 사용, 기상청 겨울 체감온도 산식, 안전보건공단 한랭질환 기준을 재검토함.
- 세 표현의 공식 전국 공통 절단점은 확인되지 않아 공식기준으로 표기하지 않고, 국내 근거가 겹치는 가장자리에서 강한 표현을 줄인 앱 내부 초기값으로 `15~20℃ 미만=선선`, `5~15℃ 미만=쌀쌀`, `5℃ 미만=춥게`, `20℃ 이상=기본 한랭문구 없음`을 제안함.
- 같은 위치·대상시각의 공식 겨울 체감온도, 기상청 방식 앱 계산값, 기온 대리값 순으로 `coldFeelValue`를 선택하고 출처역할과 바람 반영 여부를 보존하도록 함. 바람이 이미 반영된 계산값에는 강풍 보정을 중복 적용하지 않음.
- 전일대비 하강·비·바람은 기본단계를 임의로 낮추지 않고 같은 단계 안의 비교·노출 보조문장으로만 사용함. 실내·차량·반려견에는 사람의 실외 한랭단계를 적용하지 않음.
- 푸시는 같은 단계가 연속 두 예보시간에 유지될 때만 보내고, 같은 공간·계절·활동·유사조건에서 세 차례 이상 반복된 직접기록이 있을 때 인접한 한 단계까지만 개인화하도록 함.
- 한파특보·한파 영향예보·한랭질환 위험과 생활 감각단계를 분리하고 공식 사실은 확정형, 내부 감각은 모두 `~하게 느껴질 수 있어요`로 유지함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 2-3 한랭 기준은 사용자 미확정 권장안임.

### 문구 기준 채택 2-3 및 다음 2-4 검토

- 사용자의 `확정 후 다음` 요청에 따라 새로 정한 `COLD_FEEL_KR_V1`을 포함한 2-3 `덥고 춥고 끈적한 체감 문구`를 채택 상태로 확정함.
- 다음 2-4 `폭염·고온 피해·행동 문구`를 미확정 권장안으로 작성함. 새 임계값은 만들지 않고 `수치_기준_근거자료_선정_항목.md`의 채택 2-4를 그대로 상속함.
- 현행 기상청 폭염특보 발표기준·영향예보, 2026년 폭염중대경보, 질병관리청 2025년 온열질환 결과와 대상자별 건강수칙, 기상청 산업분야 폭염 영향예보, 온열질환 응급조치를 문구근거로 확인함.
- 공식 특보·영향예보·관측·예보는 `발표했어요/발효 중이에요/관측됐어요/예보했어요`로 확정하고, 앱의 보행·운동·작업 부담과 온열질환 판단은 `~수 있어요/~할 위험이 있어요`로만 표현하도록 함.
- 카드·푸시에서는 구체적인 직접행동을 먼저, 내부 영향 가능성을 다음에 표시하고, 공식상태와 수치·계산근거는 상세 상단에서 확인하도록 노출순서를 정함.
- 일반 보행·운동은 오후 2~5시의 실제 일정과 시간별 고온판정이 겹칠 때만 시간조정·휴식 문구를 제시하고, 포괄 `이동/야외활동` 대신 `실외 보행/실외 운동/옥외작업`을 사용하도록 함.
- 65세 이상은 수치단계를 낮추지 않고 같은 단계에서 우선노출·냉방상태·안부확인 행동을 구체화함. 신장·심장·혈압 관련 수분제한 가능성이 있으면 일반 수분문구 대신 담당 의료진의 지시를 따르도록 분리함.
- 옥외작업자에게만 사업장 체감온도 31/33/35/38℃의 휴식·작업조정·작업중지 문구를 적용하고, 실제 폭염중대경보에는 야외 보행·운동·작업 즉시중단, 냉방시설 이동, 가족·이웃 안부확인을 직접행동으로 제시함.
- 사용자가 두통·어지러움·근육경련 또는 의식저하를 직접 입력한 경우에만 응급행동을 최우선으로 제시하며, 의식저하 시 즉시 119 신고·몸 식히기·물 금지를 직접 안내하도록 함. 날씨만으로 증상을 추정하지 않음.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경과 고온문구의 결합범위와 금지추론을 정리함. 사람용 폭염기준을 반려견이나 침실상태에 복사하지 않음.
- 공식상태·영향예보·사용자맥락·기상근거·건강입력·문구역할·자료상태를 포함한 데이터계약, 현행 구현 후속변경 8개, 검증 시나리오 27개를 제안함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 2-4는 사용자 미확정 권장안이며 확정 후 다음은 2-5 `한파·저온 피해·행동 문구`임.

### 2-4 폭염 문구 수정 및 2-1 이후 최소 5개 표현 규칙

- 사용자 요청에 따라 2-4 기본문구를 공식 사실 `수원에는 폭염경보가 발효 중이에요`, 내부 판단 `오후 2~5시 실외 운동 시, 온열질환이 발생할 수 있어요`, 직접행동 `가능하다면 오후 2~5시 실외 운동을 다른 시간대로 옮기세요`, 중대경보 행동 `야외 보행·운동·작업을 즉시 중단하세요`, 의식저하 대응 `즉시 119에 신고하세요 · 물은 마시게 하지 마세요`로 수정함.
- 온열질환 내부판정의 `발생할 위험이 있어요` 예문을 `발생할 수 있어요`로 통일하고 judgementKey도 `HEAT_EXERCISE_ILLNESS_POSSIBLE`, `HEAT_ILLNESS_POSSIBLE`, `HEAT_WORK_ILLNESS_POSSIBLE`, `OLDER_ADULT_HEAT_ILLNESS_POSSIBLE`로 정리함.
- `다른 시간대로 옮기세요`는 관련 시간대의 고온·강수·강풍·자외선과 활동별 기준을 다시 평가해 기존 시간보다 적정한 대체시간이 하나 이상 확인됐을 때만 사용하도록 함. 구체적 시각을 추천하려면 해당 시각 자체가 검증돼야 하며, 확인하지 못했으면 `미루거나 실내 운동으로 바꾸세요`를 사용하도록 함.
- 2-1 이후 반복노출하는 특정 factKey·judgementKey·actionKey 하나마다 승인된 표현 variant를 최소 5개 두는 공통 규칙을 추가함. 숫자·조사만 바꾼 복제본은 세지 않고 문장역할·확실성·행동강도·meaningSignature를 동일하게 유지함.
- variant는 무작위로 선택하지 않고 카드·푸시·상세·접근성과 확보된 시간·장소·출처·활동정보에 따라 결정적으로 선택하도록 함. 정보가 부족하면 표현을 만들거나 placeholder로 채우지 않고 canonical 문장만 사용함.
- 2-1에는 관측기온 5개와 예보기온 5개, 2-2에는 예보입력 체감온도 계산값 5개, 2-3에는 `쌀쌀하게 느껴질 수 있어요`의 시간·활동·장소·비교·행동연결 문장틀 5개, 2-4에는 다섯 기본 표현역할을 명시함.
- 기존 예문 총수가 5개를 넘는 것만으로 통과하지 않고 최저·최고·비교·자료상태, 관측입력 계산값, 모든 feelKey, 2-4의 반복노출 key에도 실제 카탈로그 구현 시 승인 variant 5개가 필요하다는 점검표와 자동검사 조건을 추가함. 2-5부터는 권장안 단계에서 기본 표현 5개 이상을 함께 제시해야 함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 2-4는 사용자 미확정 권장안 상태를 유지함.

### 2-1~2-4 등록 문구 목록 확인

- 사용자 요청에 따라 문서에 현재 등록된 2-1 관측기온·예보기온 각 5개, 2-2 예보입력 체감온도 계산문구 5개, 2-3 `쌀쌀하게 느껴질 수 있어요` 문장틀 5개, 2-4 기본 표현역할 5개를 원문 그대로 확인함.
- 문구 기준 문서는 변경하지 않았고 제품 코드·자동테스트·배포·커밋도 수행하지 않음. 2-4는 미확정 권장안 상태를 유지함.

### 최소 5개 표현 규칙의 의미 수정 및 관측지점 표기 변경

- 사용자가 `최소 5개 표현`은 사실·계산·행동문장의 어순 variant가 아니라 한 체감항목에서 실제로 다른 감각을 말하는 표현을 뜻한다고 정정함. 앞서 추가한 2-1 이후 factKey·judgementKey·actionKey별 5개 variant 공통규칙과 2-1·2-2의 최소 5개 문장 예시를 문서에서 제거함.
- 2-1 관측문구는 지역명 중간의 `수원(관측지점기준)` 표기를 제거하고 문장을 완전히 작성한 뒤 맨 뒤에 `(기상관측장비지점기준)`을 붙이도록 변경함. 관측 최저·최고, 관측/예보 비교, 출처차이와 2-2·2-4에서 관측지점을 참조하는 사용자문구도 같은 방식으로 통일함.
- 2-3 추위 체감표현을 `선선하게 느껴질 수 있어요`, `공기가 서늘하게 느껴질 수 있어요`, `쌀쌀하게 느껴질 수 있어요`, `춥게 느껴질 수 있어요`, `찬 바람에 손끝이나 귀가 시리게 느껴질 수 있어요`의 5종으로 재구성함.
- `선선/쌀쌀/춥게`는 기존 `COLD_FEEL_KR_V1`의 전반적인 냉감 기본단계로 유지하고, `서늘하게`는 공기·그늘·찬 공기 유입, `시리게`는 낮은 한랭단계·바람·실외 노출시간·노출 신체부위가 확인될 때만 사용하는 맥락형 체감표현으로 분리함. 새 숫자단계를 만들지 않음.
- 한국어기초사전의 `쌀쌀하다/시리다` 뜻풀이, 국립국어원 냉각 형용사 관련 연구를 표현 구분 근거로 문서에 추가함.
- 2-4의 공식 사실·내부 판단·직접행동·중대경보·응급행동 5개는 `기본 안전문구`로 유지하되 체감표현 개수에는 포함하지 않는다고 명시함.
- 2-4 고온 체감표현을 `많이 덥게 느껴질 수 있어요`, `기온과 습도가 함께 높아 무덥게 느껴질 수 있어요`, `습도가 더해져 후텁지근하게 느껴질 수 있어요`, `움직이면 피부가 끈적하게 느껴질 수 있어요`, `움직이면 땀이 잘 마르지 않는 것처럼 느껴질 수 있어요`의 5종으로 추가함.
- 고온 체감 5종은 강도단계의 동의어가 아니라 사람 전체·덥고 습한 날씨·공기·피부·땀의 서로 다른 감각대상으로 분리하고 입력조건을 확인한 표현만 사용하도록 함. 국립국어원 고온다습 어휘설명과 기상청의 실제 `매우 무덥겠다` 사용을 근거로 추가함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 2-3 수정내용은 반영됐고 2-4는 미확정 권장안 상태를 유지함.

### 관측·예보 차이문구 및 체감기준별 3종 문구

- 사용자가 `관측과 당시 예보가 2.2℃ 달라요`만으로는 어느 시각의 기온인지 알 수 없다고 지적해 `오후 2시 수원에서 기온 31.2℃가 관측됐어요. 오전 11시에 발표된 오후 2시 예보기온 29℃보다 관측기온이 2.2℃ 높아요 (기상관측장비지점기준)`로 변경함.
- 관측·예보 비교문장에는 예보 발표시각, 예보 대상시각, 예보값, 관측값이 예보보다 높은지 낮은지 방향을 반드시 넣고, `달라요`만 사용하는 요약을 금지함. 출처차이 예문도 같은 방향형 문장으로 변경함.
- 사용자의 추가 설명에 따라 체감문구 수는 체감항목 전체의 총개수가 아니라 각 내부 기준·단계별로 3종씩 필요하다고 문서 원칙을 수정함.
- 현재 추위 수치기준은 `선선/쌀쌀/춥게` 3단계이며 `서늘함/시림`은 공기·노출 신체 부위의 맥락기준이므로, 총 5개 추위 체감기준 각각에 문구 3종을 작성함. 새 수치단계는 만들지 않음.
- Neutral, 약한 온감, 뚜렷한 온감, 강한 온감, 실외 후텁지근함, 피부 끈적함, 땀 마름, 실내 눅눅함·후텁지근함·서늘하고 축축함·꿉꿉함·답답함 등 2-3의 나머지 모든 feelKey에도 문구 3종을 작성함.
- 2-4 고온 체감 5개 기준인 사람 전체의 강한 온열감, 기온·습도가 함께 높은 무더위, 따뜻하고 습한 실외공기, 피부의 끈적함, 땀이 더디게 마르는 감각에도 각각 문구 3종을 작성함.
- 각 3종은 같은 feelKey·감각대상·강도를 유지하고, 한낮·활동·그늘·일몰·바람·노출 부위·침구·환기 등 variant별 맥락이 실제로 확인된 경우에만 선택하도록 함. 조건이 부족하면 각 기준의 1번 canonical을 사용함.
- 체감 데이터계약에 `expressionVariantSetId`, `expressionVariantId`, `variantSelectionCondition`을 추가하고 모든 체감기준·단계에 승인문구 3종이 있는지 확인하는 검증 시나리오를 추가함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 2-4는 미확정 권장안 상태를 유지함.

### 관측·예보 비교문구 간소화

- 사용자 요청에 따라 관측·예보 비교문구를 `오후 2시 수원에서 기온 31.2℃가 관측됐어요. 예보기온 29℃보다 관측기온이 2.2℃ 높아요 (기상관측장비지점기준)`로 확정함.
- 화면 문구에서는 `오전 11시에 발표된 오후 2시`처럼 예보 발표시각과 이미 제시된 대상시각을 반복하지 않도록 함.
- 비교 정합성을 위해 예보 발표시각·대상시각은 비교근거 데이터에 계속 보존하고, 당시 이용 가능했던 동일 대상시각 예보와 비교하는 내부조건은 유지함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음.

### 체감문구 가능성형 4종 적용

- 사용자가 반복되는 `느껴질 수 있어요`를 문장 어감에 따라 `~게 느껴질 수 있어요`, `~한 느낌이 들 수 있어요`, `~함을 느낄 수도 있어요`, `~고 느낄 수도 있어요`의 네 형태로 나눠 사용하도록 요청함.
- 2-3 추위 5개 기준, 나머지 온열·습도·실내 12개 기준, 2-4 고온 5개 기준의 각 3종 문구를 네 형태 가운데 자연스러운 종결형이 섞이도록 수정함.
- 단순 순번이나 무작위로 어미를 배분하지 않고 상태의 자연스러운 발생, 감각의 인상, 직접 감각대상, 사용자의 주관적 평가에 맞춰 종결형을 선택하는 공통규칙을 추가함.
- 사용자가 제시한 추위 문구의 뜻을 반영하되 `시려울 수 있어요`처럼 다소 어색한 조합은 `시린 느낌이 들 수 있어요`처럼 자연스러운 문장으로 정리함.
- 체감의 강도·대상·가능성은 기존 기준과 동일하게 유지했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음.

### 앞으로 할 문구 검토 순서 확인

- 공통 표현문법 1-1~1-13과 실제 기온 2-1, 체감온도 2-2, 체감표현 2-3은 채택 상태임.
- 현재 바로 확정할 항목은 여러 차례 문구를 보완했지만 아직 미확정인 2-4 `폭염·고온 피해·행동 문구`임.
- 2-4 확정 후 2-5 한파·저온, 3장 강수·적설·노면, 4장 바람·습도, 5장 자외선·대기환경, 6장 생활행동 순으로 검토함.
- 전체 문구 확정 뒤에는 문서 내용을 실제 서버 카탈로그·판정 데이터계약·앱 노출순서·자동검증과 테스트에 구현하는 작업이 남아 있음.
- 이번에는 진행상태와 향후 순서만 확인했으며 제품 코드·문구 기준 문서·자동테스트·배포·커밋은 변경하지 않음.

### 문구 기준 채택 2-4 및 다음 2-5 검토

- 사용자의 `확정 후 다음` 요청에 따라 체감기준별 3종 문구와 네 가지 가능성형 보완을 포함한 2-4 `폭염·고온 피해·행동 문구`를 채택 상태로 확정함.
- 다음 2-5 `한파·저온 피해·행동 문구`를 미확정 권장안으로 작성함. 새 임계값은 만들지 않고 `수치_기준_근거자료_선정_항목.md`의 채택 2-5를 그대로 상속함.
- 2026년 기상청 한파 영향예보 보건분야 지역별 기준, 현재 한파특보 발표기준, 질병관리청 2025~2026절기 한랭질환 결과·응급조치, 안전보건공단 옥외작업 예방지침, 국민안전24 동파 행동요령을 최신 공식자료로 대조함.
- 공식 한파특보·영향예보·기온 관측·예보는 `발표했어요/발효 중이에요/관측됐어요/예보했어요`로 확정하고, 앱의 한랭질환·저체온증·동상·동파 판단은 `~수 있어요/~할 가능성이 있어요`로만 표현하도록 함.
- 2025~2026절기 국내 한랭질환자 364명 중 저체온증 79.7%, 65세 이상 57.4%, 실외 발생 75.0%, 오전 6~9시 발생 20.9%를 시간·대상 우선노출 근거로 사용하되 개인질환이나 전국 공통 발동경계로 사용하지 않도록 함.
- 기본 역할문구를 공식 사실 `수원에는 한파경보가 발효 중이에요`, 내부 판단 `오전 6~9시 실외 보행 시, 한랭질환이 발생할 수 있어요`, 직접행동 `오전 6~9시 외출 전에 모자·목도리·장갑을 챙기세요`, 중대한 상황 행동 `실외 보행·운동을 미루고 난방되는 실내에 머무르세요`, 의식저하 대응 `즉시 119에 신고하세요 · 따뜻한 곳으로 옮기고 음료는 마시게 하지 마세요`로 제안함.
- 일반 외출·운동, 65세 이상·인지장애 돌봄, 심뇌혈관질환 등 등록대상, 옥외작업, 수도계량기·배관, 저체온증·동상 입력별 직접행동과 금지표현을 분리함.
- 구체적 대체시간은 기온·체감온도·강풍·강수·적설·도로결빙·자외선과 활동별 기준을 다시 평가해 기존 시간보다 부담이 낮을 때만 추천하고 `안전한 시간/좋은 시간`으로 확정하지 않도록 함.
- 저체온증은 심부체온 35℃ 미만 또는 의식소실 입력 시 즉시 119를 우선하며, 의식이 흐리거나 없으면 음료를 금지함. 동상은 신속한 진료·문지르기와 직접열 금지를 우선하고 37~39℃ 물 처치는 즉시 진료 곤란·재동결 위험 없음 조건에서만 표시함.
- 추위 체감표현은 2-3의 다섯 기준·각 3종을 그대로 재사용하고 2-5에서 `매섭게/살을 에는 듯/뼛속까지` 같은 새 체감어를 임의 생성하지 않도록 함.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경과 저온문구의 결합범위·금지추론을 정리함.
- 공식상태·영향예보·사용자맥락·기상근거·노출·시설·건강입력·체감 variant·자료상태를 포함한 데이터계약, 현행 구현 후속변경 9개, 검증 시나리오 30개를 제안함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 2-5는 사용자 미확정 권장안이며 확정 후 다음은 3-1 `강수확률 문구`임.

### 고령자 돌봄 문구 수정·2-5 채택 및 다음 3-1 검토

- 사용자 요청에 따라 고령자 돌봄 직접행동을 `오전 6시 전에 주변 어르신의 난방 상태와 안부를 확인하세요`로 변경하고, 첫 노출 예시에도 같은 문장을 적용함.
- `주변 어르신` 문구는 실제 돌봄일정이 있거나 사용자가 주변 어르신 확인 알림을 켠 경우에만 표시하고 모든 사용자에게 반복하지 않는 조건을 유지함.
- 사용자의 `확정 후 다음` 요청에 따라 2-5 `한파·저온 피해·행동 문구`를 채택 상태로 확정함.
- 다음 3-1 `강수확률 문구`를 미확정 권장안으로 작성함. 새 확률 임계값은 만들지 않고 수치 기준 문서의 채택 3-1을 상속함.
- 기상청 강수확률은 해당 예보기간과 장소에 강수가 내릴 가능성을 나타내는 공식 확률값으로 안내하고, 시간비율·공간비율·강수량·강도로 해석하지 않도록 함.
- 단기예보 시간별 강수확률은 사용자 화면에서 실제 적용구간을 `오후 2~3시 강수확률 60%`처럼 표시하고, 중기예보 오전·오후 값은 임의로 한 시간 단위로 세분화하지 않도록 함.
- 공식 예보는 `기상청은 수원의 오후 2~3시 강수확률을 60%로 예보했어요`, 현재 관측은 `오후 2시 수원에서 비가 관측됐어요 (기상관측장비지점기준)`, 내부 영향은 `오후 2~3시 외출 중 비를 맞을 수 있어요`, 직접행동은 별도 우산 행동기준을 통과했을 때 `오후 2시 전에 우산을 챙기세요`로 역할을 분리함.
- 관측과 당시 예보가 다르면 `오후 2시 수원에서 비가 관측됐어요. 오전 11시 발표 예보에는 오후 2시 강수없음으로 예보됐어요. 관측과 당시 예보가 달라요 (기상관측장비지점기준)`로 관측·당시 예보·차이를 순서대로 표시함.
- 공식 0%, 공식 강수없음, 관측된 강수없음, 앱 미수신, 품질오류, 이전 자료를 각각 다른 상태와 문구로 보존하도록 함.
- 초단기예보와 단기예보가 다르면 `초단기예보 기준 오후 3시, 단기예보 기준 오후 5시부터 비를 예상했어요`처럼 제품명을 밝히고 어느 하나를 오류로 단정하지 않도록 함.
- 강수확률만으로 현재 비, 우산 종류, 빨래의 실외 상태, 블랙아이스(도로살얼음), 지하차도 침수, 반려견 산책 가능 여부를 확정하지 않도록 함. 우산·빨래·일정변경은 각각의 행동기준과 사용자 계획을 확인한 뒤 연결함.
- 현행 Flutter·서버에서 POP 누락을 0으로 바꾸는 문제, `비 60% · 0.0mm` 축약, 40% 공통 trigger, 최대 확률의 발생시간 손실, `비 가능성이 높아요/접이식 우산이 있으면 좋아요` 문구를 후속 변경대상으로 기록함.
- 공식 예보·관측·레이더·사용자계획·비교·자료상태·문구역할을 포함한 데이터계약, 현행 구현 후속변경 10개, 검증 시나리오 25개를 제안함.
- 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-1은 사용자 미확정 권장안이며 확정 후 다음은 3-2 `시간당 강수량 문구`임.

### 고령자 돌봄 거주지 명시 및 2-5 최종 확정

- 사용자 요청에 따라 고령자 돌봄 직접행동을 `오전 6시 전에 주변 어르신 거주지의 난방 상태와 안부를 확인하세요`로 수정함.
- 2-5의 직접행동 목록과 첫 노출 예시에 같은 문장을 반영해 `난방 상태`를 확인하는 장소가 어르신의 거주지임을 명확히 함.
- 2-5 `한파·저온 피해·행동 문구`는 수정문구를 포함해 채택 상태로 확정함.
- 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 다음 검토항목은 미확정 권장안 3-1 `강수확률 문구`임.

### 3-1 관측지점 괄호표기 대안 검토

- 사용자가 3-1을 확정하기 전에 `(기상관측장비지점기준)`을 대신할 관측 관련 표현을 요청함.
- 기상청 사용자 화면에서 사용하는 `관측지점`, `가까운 관측지점`을 확인하고, 장비종류를 노출하지 않으면서 지점관측의 공간적 한계를 남기는 기본표현으로 `(관측지점 기준)`을 권장함.
- `가까운 관측지점 기준`은 실제로 가장 가까운 지점을 선택했을 때만, `대표 관측지점 기준`은 초단기실황처럼 선택 격자의 대표 AWS임이 확인됐을 때만 사용해야 함.
- 지점명과 거리를 확보한 경우 상세에는 `현재 위치에서 3.2km 떨어진 수원 관측지점의 자료예요`처럼 공간관계를 별도로 안내하는 방식을 권장함.
- `기상관측소 기준`은 모든 ASOS·AWS 지점이 일반 사용자가 떠올리는 관측소와 같지 않아 공통표현으로 채택하지 않고, `기상청 관측자료 기준`은 출처는 밝히지만 지점자료라는 한계를 전달하지 못하므로 보조표현으로만 검토함.
- 이번에는 대안만 검토했으며 문구 기준 문서와 제품 코드는 변경하지 않음. 3-1의 최종 확정은 사용자의 괄호표기 선택 후 반영해야 함.

### 3-1 실제 강수 관측방법 확인

- 사용자가 앞선 질문은 관측지점 표기 대안이 아니라 실제로 비가 오는지 알아내는 관측방법에 관한 것이라고 정정함.
- 기상청 AWS의 강우감지센서는 해당 지점의 강수 유무를 직접 감지하고, 우량계는 15분·60분 등 구간별 강수량을 측정한다. 강수유무와 강수량은 서로 다른 관측요소이므로 현재 강수판정은 강수유무를 우선하고 강수량은 양의 보조근거로 사용해야 함.
- 기상청 초단기실황 API는 선택한 예보격자의 대표 AWS 관측값을 제공하므로 앱에서 가장 먼저 연결하기 쉬운 공식 실황자료다. 다만 사용자 휴대전화 위치의 직접측정은 아니므로 대표 관측지점이라는 공간범위를 보존해야 함.
- ASOS는 강수유무·강수량과 함께 일부 일기현상을 자동 또는 목측으로 관측하므로 비·눈 등 현상종류 확인에 사용할 수 있지만 지점 수와 갱신주기·접근방식을 함께 확인해야 함.
- 기상레이더는 넓은 지역의 강수입자·강수영역·종류와 이동을 원격 관측하는 보조근거다. 비강수에코와 지상 미도달 가능성이 있으므로 레이더만으로 사용자의 정확한 위치에서 비가 내린다고 확정하지 않음.
- 사용자 위치에서 직접 설치한 강우센서나 사용자의 `지금 비가 와요` 기록은 정확한 위치의 근거가 될 수 있으나 각각 개인센서 감지사실·사용자 기록사실로 표시하고 기상청 공식관측으로 바꾸지 않음.
- 권장 우선순위는 `현장 직접센서/사용자 기록 → 품질정상 지상 강수유무 관측 → 초단기실황 대표 관측값 → 레이더 보조근거 → 예보`이며, 각 근거의 역할을 문구에서 구분함.
- 현행 Flutter와 서버는 모두 `getVilageFcst` 단기예보만 호출하고 `getUltraSrtNcst`, AWS·ASOS 또는 레이더 Provider를 사용하지 않는다. 따라서 현재 구현만으로는 `비가 관측됐어요`를 생성할 수 없음.
- 이번에는 조사와 설명만 수행했으며 문구 기준 문서·제품 코드·자동테스트·배포·커밋은 변경하지 않음. 3-1 최종 확정 전에 채택할 관측근거와 그에 맞는 문구를 결정해야 함.

### 3-1 사용자 실제 위치 강수알림 권장안 보완

- 사용자는 수원시 전체가 아니라 구·동 안에서도 실제 사용자가 있는 위치를 기준으로 비가 관측됐을 때 알림을 받는 것이 목표라고 설명함.
- 행정구역명은 표시용으로만 사용하고 마지막으로 확인한 사용자 위도·경도·위치정확도·확인시각을 관측자료에 연결하도록 3-1 권장안을 보완함.
- 기상청 고해상도 격자자료가 AWS·부이·등표 등 관측자료를 객관분석한 `500m` 격자이며 `강수유무(rn_ox)`와 15분·60분 강수량을 `5분` 간격으로 생산하고 특정 위도·경도를 조회할 수 있음을 확인함. 실제 관측과 차이가 있을 수 있으므로 현장 직접관측으로 표현하지 않음.
- 기상청 레이더 합성자료도 `500m` 해상도·`5분` 간격으로 제공되므로 사용자 좌표가 포함된 셀과 위치정확도 범위의 인접 셀을 공간 보강근거로 사용하도록 함. 레이더만으로 사용자 지면의 비를 확정하지 않음.
- 현장센서·사용자 직접기록, 지상 강수유무 센서, 강수현상 지상관측, 고해상도 관측분석 격자, 레이더, 초단기실황을 각각 다른 factKey와 문구로 분리함.
- 500m 관측분석 격자와 레이더가 함께 강수를 나타내면 두 공식자료의 사실을 상세에서 확정 안내하고 사용자 지면상태는 `현재 위치에 비가 내리고 있을 수 있어요`로 가능성형 표시하도록 함.
- 한 근거만 있거나 인근 AWS에만 강수가 있으면 사용자 위치에서 비가 온다고 확정하지 않도록 함. 사용자 위치에 설치된 강우센서만 해당 센서 위치의 감지사실을 직접 확정할 수 있음.
- 현재 Flutter 홈은 수원 격자 `60,121`을 고정하고 설치정보는 `nx/ny`만 저장하며, 알림 스케줄러는 사용자 추천조회가 빈 배열인 placeholder라 수원 내부 위치별 강수 시작알림을 보낼 수 없음을 현행 문제로 기록함.
- 후속 구현에 사용자 좌표·정확도·신선도 또는 개인정보를 줄인 500m 격자 식별자 저장, 관측분석·레이더·지상관측 Provider, 같은 격자 사용자 묶음조회, 시작이벤트 중복방지를 추가함.
- 위치별 분리, 오래된 GPS, 격자경계, 근거역할, 레이더·분석 결합, 이동, 중복알림, 좌표 최소저장을 검증하는 시나리오를 추가해 총 36개로 확장함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-1은 사용자 미확정 권장안 상태임.

### 3-1 위치 격자 축소 및 관측분석·레이더 차이 정리

- 사용자 요청에 따라 위치기반 강수알림의 기본 감시범위를 사용자 좌표를 포함하는 `500m×500m 한 셀`로 축소함.
- 같은 행정동 전체, 기존 5km 동네예보 격자 전체, 선택 셀 주변 3×3 인접 셀을 기본 감시범위에서 제외함.
- 관측분석과 레이더 격자가 같은 원점·배열·격자번호를 쓴다고 가정하지 않고 각 자료에서 사용자 좌표를 포함하는 한 셀을 각각 찾도록 함.
- GPS 정확도 범위가 셀 경계를 넘으면 인접 셀을 합치지 않고 위치를 다시 확인하거나 해당 위치기반 시작알림을 보류하도록 함. 경계 부근 GPS 흔들림은 새 셀의 반복확인 뒤 전환하도록 함.
- 공식 원자료가 모두 500m이므로 앱이 250m·100m 가상격자를 만들어 더 정밀한 관측처럼 표시하는 것을 금지함.
- 관측분석은 AWS·부이·등표 등 지상·해양 관측지점 자료에 지형효과를 반영한 객관분석 격자이며, 레이더는 대기 중 강수입자의 전자기파 반사신호를 합성한 원격관측 영역이라고 구분함.
- 관측분석은 지상상태 추정과 강수유무·누적량 확인에 유리하지만 관측소 사이의 분석값이고, 레이더는 좁은 소나기·분포·이동 확인에 유리하지만 지상 미도달·비강수에코 가능성이 있음을 기록함.
- 문구동사는 관측분석 `강수가 표시됐어요`, 레이더 `강수영역이 관측됐어요`로 구분하고 두 근거를 결합한 사용자 지면상태는 `현재 위치에 비가 내리고 있을 수 있어요`로 유지함.
- 데이터계약에 `CONTAINING_CELL_ONLY`, 격자경계 상태를 추가하고 격자 임의세분화·자료별 좌표매칭·경계 흔들림 검증을 추가해 3-1 검증 시나리오를 39개로 확장함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-1은 사용자 미확정 권장안 상태임.

### 3-1 위치 강수 출처표기와 알림 후 행동문구 수정

- 사용자 요청에 따라 관측분석과 레이더의 위치 강수문장 본문을 `오후 2시 현재 위치 주변에서 비가 내리고 있을 수 있어요`로 동일하게 통일함.
- 관측분석 근거에는 `(기상청 관측분석자료)`, 레이더 근거에는 `(기상청 레이더)`를 문장 끝에 붙여 출처만 구분함.
- 두 근거가 함께 사용될 때 동일 본문을 두 번 반복하지 않고 알림에는 `현재 위치에 비가 내리고 있을 수 있어요`를 한 번만 표시하며 상세에서 출처별 근거를 확인하도록 함.
- 두 출처별 문구는 기관이 사용자 위치의 비를 공식 확정한 문장이 아니라 공식자료를 근거로 앱이 생성한 `INTERNAL_CURRENT_RAIN_POSSIBILITY` 역할로 분류함.
- 현재 위치 강수알림에서는 앱 내부 판단 `현재 위치에 비가 내리고 있을 수 있어요`를 먼저 알리고, 알림 확인 후 `비가 내리고 있을 수 있어요. 지금 외출한다면 우산을 챙기세요`를 행동추천으로 표시하도록 순서를 변경함.
- `지금 외출한다면`이라는 조건이 있으므로 등록된 외출일정 없이도 표시할 수 있지만, 강풍 등으로 우산 사용이 부적절하면 4-5의 대체행동으로 교체하도록 함.
- 문구 데이터계약에 `currentRainPossibilityTextKey`, `sourceDisplayLabel`, `postAlertActionTextKey`를 추가하고 출처문구·역할·알림순서·강풍대체를 검증하는 시나리오를 추가해 총 43개로 확장함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-1은 사용자 미확정 권장안 상태임.

### 3-1 두 강수근거 결합 시 출처괄호 제거

- 사용자 요청에 따라 기상청 관측분석자료와 기상청 레이더가 모두 같은 위치 강수판단에 사용되면 출처 괄호를 붙이지 않고 `오후 2시 현재 위치 주변에서 비가 내리고 있을 수 있어요`만 한 번 출력하도록 변경함.
- 관측분석 또는 레이더 한 자료만 사용된 경우에는 기존처럼 동일한 가능성문장 뒤에 `(기상청 관측분석자료)` 또는 `(기상청 레이더)`를 표시함.
- 두 자료가 함께 사용될 때 사용자 화면에는 출처별 동일문장을 따로 나열하지 않지만 내부 근거데이터에는 두 자료의 식별자·시각·품질을 모두 보존하도록 함.
- 위치 강수 내부판단 표에 `COMBINED_PRECIP_EVIDENCE`를 추가하고 문구 데이터계약에 `sourceDisplayMode=SINGLE_SOURCE_SUFFIX|COMBINED_NO_SUFFIX`를 추가함.
- 결합근거의 무괄호·단일근거의 출처괄호가 올바르게 선택되는지 기존 검증 시나리오 32·40을 수정함. 전체 시나리오 수는 43개로 유지함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-1은 사용자 미확정 권장안 상태임.

### 3-1 최종 채택 및 3-2 시간당 강수량 문구 권장안

- 사용자의 `확정 후 다음 항목` 요청에 따라 3-1 `강수확률 문구`를 채택 상태로 확정함.
- 관측분석 또는 레이더 한 자료만 사용하면 `오후 2시 현재 위치 주변에서 비가 내리고 있을 수 있어요` 뒤에 해당 출처를 괄호로 붙이고, 두 자료를 함께 사용하면 출처괄호 없이 문구만 한 번 표시하는 최종안을 포함해 채택함.
- 다음 3-2 `시간당 강수량 문구`를 미확정 권장안으로 작성함. 새 수치기준은 만들지 않고 수치 기준 문서의 채택 3-2에 있는 기상청 공식 강도와 `5·15·30·50·70·100mm/h` 생활영향 기준점을 그대로 상속함.
- 공식 예보는 `기상청은 수원에 오후 2~3시 시간당 18mm의 강한 비를 예보했어요`, 지점관측은 `오후 1~2시 수원에서 강수량 18.2mm가 관측됐어요 (기상관측장비지점기준)`처럼 시간구간·장소·수치·자료역할을 명확히 표시하도록 함.
- 정확한 값, 범위, 미만, 이상, 공식 없음의 원자료 형태를 보존하고 `10~19mm`를 하한·중간값으로 축약하거나 `30mm 이상`에 임의 상한을 넣지 않도록 함.
- 관측지점 실측, 500m 관측분석 60분 강수량, 레이더 추정강수량을 서로 다른 문구와 factKey로 분리하고 두 공간자료의 값을 평균하거나 임의 합성하지 않도록 함.
- 관측·예보 비교는 같은 한 시간 구간을 사용해 관측값이 정확한 예보값보다 몇 mm 많거나 적은지, 또는 예보범위 안·상한 초과·하한 미만인지를 구체적으로 표시하도록 함. 화면에서는 불필요한 발표시각 반복을 생략하되 내부 비교근거에는 보존함.
- 생활영향은 기상청 체감영상에서 확인된 기준점별로 가능성형 승인문구 3종과 선택조건을 작성함. 우산을 써도 젖음, 물고임, 신발 젖음, 보행·차량 이동 곤란, 하천 주변 차량 침수, 차량 부유·건물 하단 침수를 배수·지형·노출·활동조건과 함께 사용하도록 함.
- 직접행동은 `오후 2시 전에 실외 빨래를 실내로 들여놓으세요`, `오후 2~3시 불필요한 외출을 미루고 최신 통제정보를 확인하세요`처럼 먼저 노출하고, 구체적인 대체시간·우회경로는 실제로 더 적합하고 통행 가능한 대안이 확인된 경우에만 추천하도록 함.
- 공식 강도명과 생활영향 가능성, 직접행동, 공식 특보·긴급재난문자를 서로 다른 역할로 분리함. `강한 비/매우 강한 비`를 호우주의보·경보로 바꾸지 않고, 실제 공식 안전정보가 있으면 생활문구보다 우선하도록 함.
- 현행 서버의 PCP 범위 하한 대표값·하한 합산, Flutter의 첫 숫자 파싱·누락 0 변환, Detail의 `비 60% · 0.0mm`와 시간구간 없는 최대강수량 표시를 후속 변경대상으로 기록함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-2는 사용자 미확정 권장안이며 확정 후 다음은 3-3 `누적 강수량 문구`임.

### 3-2 옷 젖음 문구 및 관측 출처표기 공통규칙 수정

- 사용자 요청에 따라 15mm/h 내부 생활영향 문구에서 `오래 걸으면`을 제거하고 `오후 2~3시에는 우산을 써도 옷이 젖을 수 있어요`로 수정함.
- 문구에서는 노출시간을 생략했지만 기상청 체감영상의 적용한계를 보존하기 위해 해당 문구의 내부 선택조건에는 보행 노출시간을 계속 반영함.
- 사용자용 문구 기준 문서 전체에서 기존 `(기상관측장비지점기준)` 표기를 제거함. 관측지점에서 직접 측정한 공식 사실은 시간·장소·값을 본문에 표시하고 관측망·지점번호·현재 위치와의 거리는 상세근거에 보존하도록 함.
- 관측분석자료나 레이더를 실제로 사용하지 않은 관측지점 수치에 두 출처명을 대신 붙이지 않도록 함. 레이더가 관측하지 않는 기온·습도 등의 요소에도 `(기상청 레이더)`를 붙이지 않음.
- 모든 날씨·생활항목에서 사용자 현재 위치 주변을 공간자료로 판단한 가능성문장은 관측분석 단독이면 `(기상청 관측분석자료)`, 레이더 단독이면 `(기상청 레이더)`, 두 자료를 함께 사용하면 괄호 없이 문구만 한 번 표시하는 공통규칙을 적용함.
- 위 규칙을 채택 1-9 `위치·시간·대상·출처 표시 순서`에 추가하고 공통 데이터계약에 `sourceDisplayMode=SINGLE_SOURCE_SUFFIX|COMBINED_NO_SUFFIX|DETAIL_ONLY`를 반영함.
- 3-2의 관측지점 최근 1시간 강수량과 관측·예보 비교문구에서는 기존 장비지점 괄호를 제거하고, 관측분석·레이더 시간당 강수량에는 출처를 문장 끝 괄호로 통일함.
- 두 공간자료가 서로 다른 강수량을 제공하면 합성하거나 평균하지 않고 각 값 뒤에 해당 출처를 붙여 상세에 나란히 표시하며, 두 자료가 함께 지지하는 생활영향 가능성문장만 무괄호 한 문장으로 병합함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-2는 사용자 미확정 권장안 상태를 유지함.

### 기상관측지점 위치와 관측분석·레이더 영역 비교

- 사용자가 기상관측장비 지점의 지역별 위치와 관측분석·레이더 영역 차이를 질문해 기상청 공식 지점정보·지역별 상세관측·API허브 자료를 확인함.
- 기상청 지상기상관측 지점정보 API는 조회시점별 `SFC/AWS` 목록과 지점번호, 위도·경도, 지점명, 법정동코드를 제공하므로 앱에서 현재 운영지점의 정확한 위치를 관리할 수 있음. 장비는 행정구역마다 하나씩 배치된 구조가 아니며 신설·이전·종료될 수 있으므로 고정목록보다 시점별 메타데이터 갱신이 적합함.
- 기상청 날씨누리 현재 목록에서 수원 지점은 `119`, 경기도 수원시 권선구 고색동, 고도 약 40m로 확인됨. 이는 수원 전체나 사용자 현재 위치를 직접 관측한 값이 아님.
- 고해상도 관측분석자료는 AWS·해양부이·등표 등 여러 관측값과 지형효과를 객관분석해 남한·연해의 500m 격자를 5분 주기로 생산하며, 기온·습도·풍속·강수유무·15/60분 강수량·시정·체감온도·적설 등을 제공함.
- 레이더 합성자료도 500m 해상도·5분 주기이므로 명목상 셀 크기는 관측분석과 같지만, 여러 레이더가 상공의 강수입자 반사신호를 원격관측한 자료이며 한반도·레이더 관측영역을 대상으로 함.
- 두 자료는 격자 원점·배열·투영과 유효영역이 같다고 보장되지 않으므로 같은 GPS 좌표를 각 자료의 위경도 격자에 별도로 매핑해야 함. 같은 격자번호나 배열 인덱스를 공유하면 안 됨.
- 차이의 핵심은 셀 크기보다 자료 의미임. 관측분석은 지상관측 사이를 분석한 지면 상태 추정이고, 레이더는 공간적으로 촘촘한 상공 강수에코이므로 지상 미도달·지형차폐·비강수에코·관측소 사이 보간 때문에 같은 500m 부근에서도 강수판정이 달라질 수 있음.
- 앱 권장구조는 현재 위치 알림에 두 자료별 `사용자 좌표 포함 500m 한 셀`을 독립 조회하고, 관측지점 값은 현재 위치 판정이 아니라 지점명·거리와 함께 상세 비교자료로 사용하는 것임. 두 공간자료가 일치하면 무괄호 가능성문장, 하나만 확인되면 해당 출처괄호, 서로 다르면 단일근거 표시 또는 보류와 상세 차이표시를 사용함.
- 이번에는 조사·설명과 HANDOFF 기록만 수행했으며 문구 기준 문서·제품 코드·자동테스트·배포·커밋은 변경하지 않음.

### 현재 위치 강수알림의 관측장비 제외·두 공간자료 AND 조건 채택

- 사용자가 현재 위치 강수판정에서 관측장비를 완전히 제외하고 관측분석·레이더가 일치할 때만 알림을 보내며 사용자 문구에는 출처괄호를 전혀 쓰지 않기로 결정함.
- 적용범위는 현재 위치의 자동 강수판정·알림과 이를 사용하는 비와 우산 준비·빨래 회수·반려견 산책계획·출퇴근 경로 등 생활항목임. 레이더가 관측하지 않는 기온·습도·풍속까지 두 자료 일치조건으로 확대하지 않음.
- 현재 위치 강수알림의 발동근거에서 지상 관측장비·관측지점, 현장센서, 사용자 직접기록, 초단기실황을 제외함. 사용자 기록은 별도 기록기능에 보존할 수 있지만 자동 알림을 발동하지 않음.
- 사용자 좌표를 포함하는 관측분석 500m 한 셀과 레이더 500m 한 셀을 각 자료의 격자에 독립 매핑하고, 같은 기준시각·정상 품질에서 두 셀이 모두 `강수 있음`을 나타낼 때만 알림을 생성하도록 함.
- `일치`는 두 강수량 숫자가 완전히 같다는 뜻이 아니라 두 셀이 모두 강수 존재를 나타낸다는 뜻으로 확정함. 한 자료만 강수이거나 한 자료가 미수신·오래됨·품질오류이면 문구와 알림을 모두 보류함.
- 사용자 문구는 `오후 2시 현재 위치 주변에서 비가 내리고 있을 수 있어요`로만 표시하고 출처괄호를 붙이지 않음. 출처는 상세에서 `기상청 관측분석자료 · 오후 2시 · 강수 있음`, `기상청 레이더 · 오후 2시 · 강수 있음` 같은 별도 근거행으로 표시함.
- 두 자료의 60분 강수량 숫자가 다르면 평균·합산하지 않고 `기상청 관측분석자료 · …`, `기상청 레이더 · …` 두 상세행으로 각각 보존함.
- 현재 강수량 기반 생활영향 단계는 두 공간자료가 모두 해당 기준점 이상일 때만 생성함. 구현상 두 값 중 낮은 값을 판정에 사용하는 것과 같지만 사용자에게 합성된 하나의 강수량으로 표시하지 않음.
- 3-1의 단일출처 문구·출처괄호·지상관측 factKey·관측장비 Provider 요구·관측과 예보 비교문구를 결합판정 정책에 맞게 제거하거나 수정함. 3-2의 관측지점 한 시간 실측과 비교문구도 관측분석·레이더 기반으로 교체함.
- 공통 데이터계약의 출처표시는 `COMBINED_NO_SUFFIX|DETAIL_LABEL_ONLY`로 변경하고 단일출처 suffix 모드를 제거함.
- 문구 기준 문서와 HANDOFF만 변경했으며 제품 코드·자동테스트·배포·커밋은 수행하지 않음. 3-1은 수정안을 포함한 채택 상태이고 3-2는 사용자 미확정 권장안 상태임.

### 관측분석·레이더 500m 셀 정확도와 강수량 결합방식 검토

- `500m`는 두 자료의 출력 격자 간격이며 사용자 위치의 강수량이 500m 정확도로 직접 측정된다는 의미가 아님을 확인함.
- 기상청 고해상도 관측분석자료는 AWS·부이·등표 등 관측값과 지형효과를 이용한 2차원 객관분석으로 `rn_ox`, `rn_15m`, `rn_60m`를 생산한다. 기상청은 실제 관측과 차이가 있을 수 있다고 명시하지만 강수유무·강수량에 대한 전국 공통 POD·FAR·MAE·RMSE는 공개 API 안내에 제시하지 않음.
- 기상청 레이더 500m 자료는 HSR 및 HSR 기반 누적강수 `PCPH`를 5분 주기로 제공한다. 지상에 가까운 고도각과 품질관리를 사용하지만 지형차폐·관측고도·증발·강수입자 특성·레이더 거리 등에 따라 오차가 달라져 전국 모든 셀에 적용할 하나의 정확도 수치는 없음.
- 2015년 서울 호우 2사례 교차검증에서는 기상청 AWS만 공간보간한 강우장의 10분 RMSE가 `0.54·0.97mm`, 원시 광덕산 레이더 강우는 `0.91·1.54mm`였고, 레이더는 과소추정·지상망은 공간 평활화 경향을 보였다. 이는 현재 운영 중인 500m 관측분석·HSR 제품의 공식 성능표가 아니라 두 자료유형의 장단점을 보여주는 제한적 사례로만 사용함.
- 2025년 7월 충청권 폭우 1주·AWS 42지점 연구에서는 KMA HSR을 1시간 누적해 비교한 평균 성능이 `MAE 1.52mm`, `RMSE 3.68mm`, `R² 0.70`이었다. 이 또한 특정 지역·기간·강우사례 결과이므로 앱의 전국 고정 오차값으로 사용하지 않음.
- 단순 산술평균은 두 자료가 같은 편향·오차분산을 갖는다는 검증이 없어 권장하지 않음. 두 값 중 최솟값도 실제 강수량의 최적 추정치가 아니라 고단계 생활영향 오탐을 줄이는 의사결정 규칙임.
- 초기 운영 권장안은 강수 시작 알림은 기존 `관측분석 강수 있음 AND 레이더 강수 있음`을 유지하고, 두 60분 강수량은 상세에서 별도로 보존·표시하며 합성 강수량은 만들지 않는 것임. 생활영향에서 오탐 최소화가 목표라면 최솟값과 같은 `두 자료 모두 기준 이상` 규칙을 사용할 수 있으나 공식 특보·통제·응급안전 판단에는 적용하지 않음.
- 대표 강수량 하나가 반드시 필요하면 단순평균 대신 독립 검증지점에 대한 교차검증으로 계절·지역·강우강도·레이더 거리별 가중치를 학습한 보정/조건부 합성값을 별도 제품으로 만들어야 함. 관측분석이 입력으로 사용한 지점을 그대로 정답으로 평가하지 않고 제외지점 또는 독립 우량계를 사용해야 함.
- 이번에는 조사·권장안 설명과 HANDOFF 기록만 수행했으며 문구 기준 문서·제품 코드·자동테스트·배포·커밋은 변경하지 않음. 최솟값 유지·대표값 별도·보정합성 개발 중 최종 정책은 사용자 미확정 상태임.

### 관측지점·관측분석·레이더 과거자료 비교검증 설계

- 과거 지상관측 강수량과 같은 시각·좌표의 관측분석 500m 셀 및 레이더 500m 셀을 결합해 직접 비교할 수 있음을 확인함.
- 지상 기준자료는 기상자료개방포털의 ASOS·AWS 분자료와 지점 위경도 변경이력을 사용한다. ASOS는 105개, AWS는 약 554개 지점의 강수자료를 제공하며 AWS는 1997년 이후 자료와 장기 파일셋을 제공함.
- 관측분석은 `rn_ox`, `rn_15m`, `rn_60m`, 레이더는 HSR 기반 `PCPH` 60분 누적자료를 사용한다. 레이더 500m·5분 형식은 2019년 9월 이후이므로 현재 알고리즘과 시간해상도 정합성을 고려한 1차 비교기간은 `2023~2025년`을 권장함.
- 비교행은 `기준시각(KST)·지점번호·당시 위경도·지점 60분강수·관측분석 포함셀 rn_60m·레이더 포함셀 PCPH(acc=60)·QC·자료버전`으로 구성하고 세 자료 모두 동일한 종료시각의 `(t-60분, t]` 구간으로 맞춤.
- 앱이 실제로 사용자 좌표 포함 한 셀을 사용하므로 검증에서도 최근접 셀이나 3×3 평균으로 바꾸지 않고 각 자료에서 관측지점 좌표를 포함하는 한 셀을 독립 매핑함.
- 기상청 ASOS·AWS 및 일부 공공기관 지점은 관측분석의 입력자료일 수 있으므로 이 비교는 우선 `관측지점 일치도`와 시간·좌표 매핑 검증으로만 사용하며 독립 정확도라고 부르지 않음.
- 의사결정용 독립검증은 관측분석 입력망에 포함되지 않았음을 확인한 지자체·도로·하천·민간 우량계 또는 입력지점을 제외하고 관측분석을 다시 만든 leave-one-station-out 자료가 필요함. 입력망 여부를 확인하지 못한 공공기관 지점을 임의로 독립 정답으로 취급하지 않음.
- 강수유무에는 혼동행렬, precision, recall/POD, FAR, CSI를 사용하고 강수량에는 bias, MAE, RMSE를 사용함. 앱 생활기준점별로 `관측분석 단독·레이더 단독·최솟값·산술평균·최댓값·학습가중값`의 단계 적중·오탐·미탐을 별도로 비교함.
- 모델 선택용 기간과 최종 평가기간을 호우사례 단위로 분리하고 계절·지역·지형·레이더거리·강수강도별 결과를 나눠야 함. 같은 호우사례의 일부 시각을 학습과 평가에 동시에 넣지 않음.
- 과거 확정자료 비교만으로는 실시간 최초 수신값의 지연·누락·사후수정까지 평가할 수 없으므로 실제 운영 전 한 우기 이상 shadow 수집으로 최초수신시각과 수정이력을 별도 검증함.
- 이번에는 비교 가능성·자료원·검증절차를 설명하고 HANDOFF만 갱신했으며 분석코드 작성·대용량자료 다운로드·API 호출·제품 코드·문구 기준 문서·자동테스트·배포·커밋은 수행하지 않음. 실제 비교분석 범위와 실행 여부는 사용자 미확정 상태임.

### 최근 1년 강수자료 비교 범위 및 자료접근 확인

- 사용자 요청에 따라 관측지점·관측분석·레이더 비교기간을 오늘 진행 중인 하루를 제외한 최근 1년인 `2025-08-27 00:00~2026-08-26 23:55 KST`로 한정함. 이전에 검토한 2015년 사례, 2025년 7월 사례 및 2024년까지의 연구자료는 이 기간의 성능값으로 사용하지 않음.
- 기상자료개방포털에서 수원 ASOS 119의 해당 기간 시간 강수자료가 조회되는 것은 확인했으나, 비회원 CSV 다운로드는 시간자료 24건으로 제한되어 최근 1년 전체 자료를 확보하지 못함.
- 저장소의 기존 공공데이터포털 서비스키로 ASOS 과거자료를 호출하면 `403 SERVICE_KEY_IS_NOT_REGISTERED_ERROR`, 기상청 API허브 관측분석자료를 호출하면 `401`이 반환되어 현재 키로는 비교에 필요한 세 자료를 일괄 수집할 수 없음. 키 값 자체는 출력하거나 기록하지 않음.
- 최근 1년 범위를 실제 산출하려면 같은 종료시각마다 `수원 ASOS 119의 60분 강수량`, `해당 좌표를 포함하는 관측분석 500m 셀의 rn_60m`, `해당 좌표를 포함하는 레이더 500m 셀의 PCPH(acc=60)`을 수집해야 함. 시간자료 기준 최대 8,760개 비교시점이며 세 자료의 결측·QC·버전도 함께 보존함.
- 최근 1년 기간을 직접 포함하는 공개 검증연구는 확인하지 못했으므로, 다른 기간의 논문 성능값을 최근 1년 결과처럼 인용하거나 최소값·평균값 선택근거로 사용하지 않음.
- 현재 단계에서는 정확도 수치나 결합방식 우열을 확정할 수 없음. 전체 원자료 확보 후 관측분석 단독·레이더 단독·둘 중 낮은 값·평균값을 동일 표본에서 비교하고, 강수유무의 CSI/POD/FAR와 생활기준점별 오탐·미탐을 기준으로 결정해야 함.
- 이번에는 자료조회·권한 확인과 HANDOFF 기록만 수행했으며 제품 코드·문구 기준 문서·자동테스트·배포·커밋은 변경하지 않음. 실제 최근 1년 분석은 기상자료개방포털 로그인 다운로드 또는 필요한 Open API/API허브 권한이 확보될 때까지 미완료 상태임.

### 최근 강수 비교자료의 발표일·관측기간 구분

- 발표일이 가장 최근인 국내 레이더·우량계 결합 관련 자료는 2026년 4월 28일 공개된 `RRBF-KMA` 사전논문이지만 사용자료는 2016~2024년이므로 요청한 최근 1년 실측근거에는 포함하지 않음.
- 관측기간이 가장 최근인 국내 HSR 레이더·AWS 비교연구는 2025년 7월 14~20일 충청권 폭우 사례이며 2025년 12월 31일 발행됨. 현재 기준 최근 1년 시작일인 2025년 8월 27일보다 약 한 달 이전이므로 역시 최근 1년 분석에서 제외함.
- 기상청 운영 원자료 자체는 2026년 8월 26일까지 조회 대상으로 설정할 수 있으므로, 요청기간을 실제로 충족하는 가장 최근 자료는 논문이 아니라 기상청 관측지점·관측분석·레이더 원자료임. 전체 다운로드/API 권한이 없어 아직 수치 비교는 완료하지 못함.

### 2024년 한정 레이더·지상강수 자료 분석

- 사용자 요청에 따라 이후 분석범위를 관측연도 `2024-01-01~2024-12-31 KST`로 한정함. 여러 해를 합산한 성능값과 2022년 여름 사례값은 2024년 정확도 수치로 사용하지 않음.
- 기상청 2025년도 성과관리 시행계획에 인용된 `2024년도 범부처 이중편파레이더 기반 강수 추정 정확도`에서 2024년 `전체 강수 82.1%`, `대류성 위험 강수 85.1%`가 확인됨.
- 해당 지표는 2024년 5~10월 AWS 628지점의 1시간 누적강수 `G`와 범부처 이중편파레이더 합성 강수장 `R`을 비교한 `(1 - 평균 절대상대오차) × 100` 계열 산식임. 따라서 산식상 오차분은 각각 약 `17.9%`, `14.9%`에 해당하지만 `비가 온 시각·셀의 82.1%를 맞혔다`는 탐지적중률이나 앱 알림 정확도로 해석하면 안 됨.
- 위 공식 수치는 KMA APIHub의 운영 HSR/PCPH 한 셀과 동일 제품인지 확인되지 않았고, 관측분석자료 `rn_60m`는 비교대상에 포함되지 않음. 따라서 이 수치만으로 관측분석 대 레이더의 우열, 두 값 중 최소값 대 산술평균의 우열을 결정할 수 없음.
- RRBF-KMA 공개자료의 2024년 부분은 500m·10분 간격 결합강수장으로, 2024년 기대 52,704시각 중 `2024-03-20 17:00·17:10 KST` 두 시각만 누락되어 시간완전성은 약 `99.996%`임. Figure 5의 그래프 판독상 분석영역 연평균 누적강수는 약 `1,850mm` 수준이나 원문에 연도별 숫자표가 없으므로 근삿값으로만 취급함.
- RRBF-KMA의 2024년 월별 압축파일은 총 약 `9.45GiB`이나 Zenodo 공개본은 결합결과 `RR`와 보정계수 `C_EWMA` 중심이며 동일 시각의 원시 지상우량·레이더·기상청 관측분석 세 값이 함께 제공되지 않음. 이 파일만으로 앱의 `관측분석·레이더 최소값/평균값` 비교를 재현할 수 없음.
- 2024년 한정 근거의 앱 적용 결론은 `산술평균을 대표강수량으로 채택할 근거 없음`, `최소값 역시 실제 강수량의 최적 추정치가 아니라 두 자료 모두 기준을 넘을 때만 알리는 보수적 의사결정 규칙`임. 사용자 선택인 두 자료 일치 알림은 유지할 수 있지만 이 지표로 오탐·미탐 성능이 검증됐다고 표현하지 않음.
- 정확한 결합정책 비교에는 2024년 동일 종료시각의 지상 1시간 누적강수, 관측분석 `rn_60m`, 레이더 `PCPH(acc=60)` 원자료가 필요함. 이번에는 공식 문서·논문·Zenodo 구조를 분석하고 HANDOFF만 갱신했으며 제품 코드·문구 기준 문서·자동테스트·배포·커밋은 변경하지 않음.

### 사용자가 요구한 최소값 대 평균값 비교지표 명확화

- 사용자가 원하는 분석은 각 동일 시각·지점의 `지점 관측강수량 G`, `관측분석 셀 O`, `레이더 셀 R`을 놓고 `L=min(O,R)`과 `A=(O+R)/2` 중 어느 값의 절대오차가 작은지를 2024년 전체에서 직접 비교하는 것임.
- 예시 `G=18.0, O=16.2, R=22.4mm`에서는 `L=16.2`, `A=19.3`, 최소값 절대오차 `1.8mm`, 평균값 절대오차 `1.3mm`이므로 평균값이 `0.5mm` 더 가깝고 최소값 대비 오차가 약 `27.8%` 작음.
- 최종 결과에는 `최소값 승리 건수·비율`, `평균값 승리 건수·비율`, `동률`, 두 방식의 `MAE·RMSE·평균편향`, 평균 절대오차 차이와 개선율을 제시해야 함. 무강수 시각을 모두 포함한 결과와 지점강수 `0.1mm 이상` 결과를 분리함.
- 현재 확인된 2024년 공식 보고서는 레이더와 AWS의 집계 정확도만 제공하고, RRBF 공개본도 기상청 관측분석 `rn_60m` 원값을 포함하지 않으므로 위 승률·오차차이는 아직 계산할 수 없음. 세 원자료를 확보하기 전까지 수치를 추정하거나 공식 레이더 정확도 82.1%를 대신 사용하지 않음.

### 2024년 세 원자료의 존재와 현재 접근제약 확인

- 2024년 비교에 필요한 자료 자체는 모두 존재함. AWS는 1997년 이후 554개 지점의 강수 분·시간자료와 QC를 제공하고, 고해상도 관측분석은 1997년 이후 500m·5분 주기의 `rn_60m`, 레이더는 2016년 이후 500m·5분 주기의 HSR 기반 `PCPH(acc=60)`을 제공함.
- 준비된 결합 비교파일이 없는 것이며, 세 자료를 각각 내려받아 2024년 동일 종료시각과 당시 관측지점 좌표를 기준으로 결합해야 함.
- 현재 저장소의 키는 지상 과거자료 호출에서 403, API허브 관측분석 호출에서 401을 반환함. 브라우저의 기상자료개방포털도 비로그인 상태여서 시간자료 CSV가 24건으로 제한됨.
- 따라서 실제 2024년 최소값 대 평균값 비교를 진행하려면 기상자료개방포털 로그인 다운로드와 API허브의 고해상도 격자자료·레이더 활용승인 및 인증키가 필요함. 자료가 없다고 표현하지 않고 `자료는 있으나 현재 접근권한이 없어 미수집`으로 기록함.

### 2024년 최소값 대 평균값 검증용 자료 확보 체크리스트

- 앱의 전국 공통 결합정책을 정하려면 2024년 전국 AWS와 ASOS 운영지점을 표본으로 삼고 관측망별 결과도 분리하는 것을 권장함. 수원 119 한 지점만 사용하면 수원 사례분석은 가능하지만 전국 정책의 근거로 확대하지 않음.
- 기상자료개방포털에서 `데이터 > 기상관측 > 지상 > 방재기상관측(AWS) > 시간 자료`와 `종관기상관측(ASOS) > 시간 자료`를 각각 열어 전체 운영지점과 강수를 선택해 CSV/파일셋으로 받음. 2024년 안에 완전히 포함되는 60분 구간을 만들기 위해 종료시각 기준 `2024-01-01 01:00~2025-01-01 00:00 KST`를 확보함. AWS 분석에는 `지점번호·시각(KST)·1시간 강수량 RN_HR1`이 필요하며 가능한 경우 `RN_HR1_MI`와 결측/QC도 포함함. ASOS는 `지점번호·시각·시간강수량 RN`과 강수자료구분/QC를 확보하고 두 관측망을 별도로 표시함.
- `데이터 > 메타데이터 > 지점정보 > 관측지점정보`에서 2024년에 유효한 AWS/ASOS 지점이력을 내려받음. 필요한 열은 `지점번호·시작일·종료일·위도·경도·지점명`이며, 같은 지점번호의 연중 이전·변경 이력을 보존함.
- API허브에서 `융합기상 > 고해상도 격자자료 > 1. 고해상도 격자자료 조회(500m)`의 활용신청을 하고 요소 `rn_60m`을 사용함. 비교 종료시각은 `2024-01-01 01:00~2025-01-01 00:00` 매 정시 8,784개이며 파일방식이면 `1.4 파일 다운로드(NetCDF4)`, 지점방식이면 `1.2 특정지점 단일요소`를 사용함. 관측분석 위·경도 격자파일도 한 번 받음.
- API허브에서 `레이더 > 레이더 강수량(HSR) > 2.2.2 HSR기반 1시간 누적` 활용신청을 하고 `cmp=PCPH`, `qcd=MSK`, `acc=60`, `map=HB`를 사용함. 화면 이미지·반사도 HSR이 아니라 60분 누적강수 격자값이 필요함. 레이더 PCP 격자 위·경도 NetCDF도 한 번 받음.
- 레이더의 `AWS지점별 합성자료값`은 HSP 강우강도(mm/h)를 제공하므로 5분값 12개를 직접 누적하는 대안은 될 수 있지만, 앱이 사용할 `PCPH(acc=60)`과 동일 제품을 검증하려는 1차 자료에는 사용하지 않음.
- 받지 않아도 되는 자료는 레이더 원시 볼륨, PNG 레이더영상, HSR 반사도 자체, 일·월강수량, 예보 강수확률, RRBF 결합자료임.
- 전국 2024년 정시 비교는 관측분석·레이더 각각 8,784시각이므로 수동 다운로드 대신 두 API 활용승인과 인증키를 로컬 환경에 설정한 뒤 자동수집하는 방식을 권장함. 최종 비교구간은 각 정시 `t`에 끝나는 `(t-60분,t]`로 통일함.

### 기상청 계정·인증정보 안전 처리

- 사용자에게 기상자료개방포털/API허브의 아이디·비밀번호나 API 인증키를 채팅으로 전달받지 않음.
- 사용자가 인앱 브라우저의 기상청 로그인 화면에서 직접 로그인하면, 로그인된 세션을 이용해 필요한 자료 선택·다운로드와 활용신청 화면 작성을 이어서 지원할 수 있음.
- 약관 동의, 개인정보 입력, 활용목적 확정 및 최종 신청 제출처럼 계정 권한이나 법적 동의가 수반되는 단계는 사용자가 직접 처리하거나 제출 직전 명시적으로 승인한 범위에서만 진행함.
- API 인증키는 채팅에 붙이지 않고 저장소의 로컬 비밀설정 파일에 APIHub 전용 환경변수로 저장하며, 버전 관리에 포함되지 않았는지 확인한 뒤 자동수집에 사용함.
- 이번에는 안전한 계정 사용방식만 안내하며 포털 로그인·신청·다운로드·코드 변경·자동테스트·배포·커밋은 수행하지 않음.

### 기상청 API허브 인앱 로그인 대기

- 일반 Chrome과 로그인 쿠키가 분리될 수 있어 Codex 인앱 브라우저에 `https://apihub.kma.go.kr/`를 열고 사용자에게 보이도록 유지함.
- 로그인 입력·본인인증은 사용자가 직접 수행하며, 로그인 완료 안내를 받은 뒤 고해상도 격자자료 및 레이더 1시간 누적강수 활용권한을 확인할 예정임.
- 이번에는 로그인 화면만 열었으며 활용신청 제출·자료 다운로드·코드 변경·자동테스트·배포·커밋은 수행하지 않음.

### API허브 로그인·활용권한 확인 및 레이더 신청서 작성

- 인앱 브라우저에서 API허브 로그인 상태를 확인함. 계정의 개인정보와 인증키는 HANDOFF 및 사용자 응답에 기록하거나 노출하지 않음.
- `융합기상 > 고해상도 격자자료 > /url/sfc_grid_nc_down.php`는 `2026-08-27~2028-08-27` 승인 상태이며, 관측분석 `rn_60m` NetCDF 다운로드에 사용할 수 있음을 확인함.
- 필요한 레이더 엔드포인트는 `레이더 > 레이더 강수량(HSR) > 레이더 합성자료 조회 > /cgi-bin/url/nph-rdr_cmp1_api`이며, `cmp=PCPH`, `qcd=MSK`, `acc=60`, `map=HB`로 1시간 누적강수를 조회할 수 있음을 재확인함.
- 레이더 활용신청 양식에서 분야를 `서비스/영업`, 세부목적을 `기상현상 분석`, 설명을 `날씨챙겨 앱의 강수 알림 기준 연구와 2024년 관측분석·레이더 강수량 비교 검증에 활용`로 입력함.
- 최종 `활용신청` 버튼은 즉시 API 접근권한을 생성하는 외부 상태변경이므로 누르지 않고 사용자 확인을 기다리는 상태임. 해당 신청 탭은 후속 작업을 위해 유지함.
- 이번에는 권한 확인과 신청서 작성만 수행했으며 최종 제출·자료 다운로드·코드 변경·자동테스트·배포·커밋은 수행하지 않음.

### 레이더 API 승인 및 2024년 호출 검증

- 사용자 확인 후 레이더 `/cgi-bin/url/nph-rdr_cmp1_api` 활용신청을 최종 제출함. 포털은 이미 신청된 API라는 안내를 표시했고, 마이페이지에서 `2026-08-27~2028-08-27` 승인 상태를 확인함.
- 마이페이지에는 고해상도 관측분석 NetCDF와 레이더 합성자료 API 두 건이 모두 승인 상태로 표시됨.
- 계정 인증키를 응답·로그·HANDOFF에 노출하지 않고 런타임 메모리에서만 사용해 `2024-07-18 12:00 KST` 시험자료를 호출함.
- 관측분석 `rn_60m` NetCDF 압축응답은 HTTP 200, `218,120 bytes`; 레이더 `PCPH, qcd=MSK, acc=60, map=HB, disp=B`는 HTTP 200, `13,281,414 bytes`로 실제 2024년 과거자료 접근이 가능함을 확인함.
- 레이더 한 시각이 약 13.28MB이므로 2024년 정시 8,784개 전부를 받으면 약 116.7GB로 APIHub 일일 5GB 한도를 크게 초과함. AWS 강수시각으로 후보를 줄이거나 대용량 API를 이용하는 수집전략이 필요함.

### 추가 필수 API 신청서 3건 제출 대기

- 2024년 지상강수와 격자값 결합에 필요한 아래 세 신청서를 제출 직전까지 작성함.
  - AWS 시간통계 강수 `/url/awsh.php` (`RN_HR1`, route 443)
  - 방재기상관측지점 일람표 `/openApi/AwsYearlyInfoService/getAwsStnLstTbl` (지점좌표, route 428)
  - 레이더 합성장 격자 위경도 NetCDF `/url/rdr_latlon_file_down.php` (route 1126)
- 세 신청서 모두 분야 `서비스/영업`, 세부목적 `기상현상 분석`, 설명 `날씨챙겨 앱의 강수 알림 기준 연구와 2024년 관측분석·레이더·지상강수 비교 검증에 활용`로 작성함.
- 세 API는 최종 제출 시 즉시 접근권한이 생성되므로 사용자 확인 전 `활용신청` 버튼을 누르지 않았고, 신청 탭들을 후속 작업용으로 유지함.
- 제품 코드·자동테스트·배포·커밋은 수행하지 않음.

### 2024년 관측분석·레이더 결합방식 예비 실측분석 완료

- 사용자 확인 후 AWS 시간통계 강수 `/url/awsh.php`, 방재기상관측지점 일람표 `/openApi/AwsYearlyInfoService/getAwsStnLstTbl`, 레이더 격자 위경도 NetCDF `/url/rdr_latlon_file_down.php` 활용신청을 제출했고 모두 `2026-08-27~2028-08-27` 승인 상태를 확인함. 기존 관측분석 NetCDF와 레이더 합성자료를 포함해 분석에 필요한 API 5종이 승인됨.
- 계정 인증키는 브라우저 세션 메모리에서만 사용하고 파일·로그·HANDOFF·응답에 저장하거나 노출하지 않음.
- AWS `RN_HR1`로 `2024-01-01 01:00~2025-01-01 00:00 KST` 정시 8,784개를 전수 스캔함. 오류 0건, 유효 AWS 지점-시각 6,075,269건, 전국 한 지점 이상에서 0.1mm 이상 강수가 있었던 시각 5,510개를 확인함.
- 레이더 일일 5GB 한도를 고려해 5,510개 강수시각 중 월별 25시간, 각 월의 전국 최대 지점강수량 5분위별 5시간인 총 300시간 층화표본을 구성함. 300시간의 AWS·관측분석 `rn_60m`·레이더 `PCPH/MSK/acc=60` 다운로드를 오류 없이 완료했고 임시파일도 남지 않음.
- 2024년 AWS 유효지점 526개를 각 자료의 위경도 격자에 독립적으로 최근접 매핑함. 관측분석은 2049×2049, 레이더는 2881×2305 격자이며 지점-최근접 셀 거리는 두 자료 모두 최대 약 0.350km였음.
- 레이더 포맷의 `-25000`은 결측이 아니라 에코 미탐지이므로 0mm로 처리하고, `-30000` 관측영역 밖만 제외함. API 문서대로 반사도 정수값을 dBZ×100으로 해석해 기상청 데이터위키의 Marshall–Palmer `Z=200R^1.6`으로 강수량을 변환했으며, 국내 2020 운용식 `Z=148R^1.59`도 민감도 분석함.
- 표본 300시간에는 관측분석이 유효한 AWS 지점-시각 148,072건이 포함됨. 앱 조건과 같이 `O>=0.1mm AND R>=0.1mm`이며 AWS도 `G>=0.1mm`인 Marshall–Palmer 비교행은 14,990건이었음.
- 위 앱 조건에서 `A=(O+R)/2`가 지점강수에 더 가까운 표본행은 11,376건, `L=min(O,R)`이 더 가까운 행은 3,614건이었음. 2024년 강수시각 모집단 가중 승률은 평균값 75.71%, 낮은 값 24.29%로 평균값이 51.41%p 앞섰고, 평균값 승률의 층화 부트스트랩 참고범위는 73.75~77.73%였음.
- 같은 조건의 MAE는 평균값 0.775mm, 낮은 값 1.068mm로 평균값이 0.293mm, 27.5% 낮았음. 국내 2020 운용식으로 바꿔도 평균값 승률 67.18%, 낮은 값 32.82%, MAE 0.769mm 대 0.939mm로 결론이 유지됨.
- 두 공간자료 모두 0.1mm 이상인 조건은 표본 내 AWS 0.1mm 이상 지점-시각을 가중 기준 86.0% 포착했고, 그 조건이 성립한 사례 중 AWS도 0.1mm 이상인 비율은 99.4%였음. 단, 전국 어딘가에 비가 있었던 300개 표본시각 안의 수치이므로 연중 완전 무강수시각을 포함한 연간 precision으로 부르지 않음.
- 관측분석 단독 MAE 0.735mm가 평균값 0.775mm보다 작았음. 따라서 두 값 중 하나의 합성값이 꼭 필요하면 낮은 값보다 평균값이 낫지만, 운영대안으로 관측분석을 수치 주자료로 사용하고 레이더를 강수 확인자료로 쓰는 방식도 검토할 가치가 있음. 관측분석에 AWS가 입력될 수 있어 이 비교는 독립 정확도 검증이 아니라 지점 일치도 비교임.
- 결과는 5,510개 강수시각 전체가 아닌 300시간 예비표본임. 전체 강수시각의 약 73GB 레이더 자료를 받으려면 APIHub 대용량 API 이용계획서를 `kmadatahub@korea.kr`로 제출해 일시 증량 승인을 받아야 하며 공식 안내상 심사에 2~3주가 걸릴 수 있음. 이메일 발송은 별도 사용자 확인 전 수행하지 않음.
- 재현파일은 `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/analyze_precip_sample.py`이며 결과는 `tmp/rainfall_2024_preliminary/analysis_report.md`, `analysis_results.json`에 저장함. Python 구문검사와 분석 재실행을 통과함.
- 제품 코드·문구 기준 문서·자동테스트·배포·커밋은 변경하지 않음. 현재 HANDOFF의 기존 낮은 값 정책을 평균값으로 교체하는 것은 사용자 최종확정 전이며, 이번 권장안만 기록함.

### 3-2 시간당 강수량 문구와 목적별 판정값 최종 채택

- 사용자가 2024년 예비 실측분석을 반영한 목적별 운영안을 확정함. 이 절이 이전 HANDOFF의 `낮은 값 정책`과 `사용자 최종확정 전` 기록을 대체함.
- 현재 비 여부는 최근 60분 누적량으로 판정하지 않음. 같은 기준시각·위치의 관측분석 `rn_ox`와 레이더 현재 강수에코가 모두 강수일 때만 `현재 위치 주변에서 비가 내리고 있을 수 있어요`라는 내부 가능성판정을 생성함.
- 사용자에게 표시하는 최근 60분 주 강수량은 관측분석 `rn_60m`으로 채택함. `관측됐어요`가 아니라 `분석됐어요`를 사용하며 레이더 `PCPH(acc=60)` 추정량은 상세 근거로 보존함.
- 생활영향 판정은 목적별로 분리함. `5mm/h` 우산 영향은 관측분석 주값, `15mm/h` 옷 젖음·물고임 영향은 시각·좌표·품질이 유효하고 모두 0.1mm 이상인 두 60분 값의 산술평균을 사용함. 현재 상태의 영향문구에는 `rn_ox`와 현재 레이더 에코의 강수 일치를 추가로 요구함. 이 평균은 앱 내부 판정값이며 사용자용 공식 강수량으로 표시하지 않음.
- `30mm/h` 이상은 레이더 변환식에 따라 관측분석과 평균의 F1 우세가 달라 평균값으로 자동승격하지 않음. 관측분석 주값·레이더 상세와 실제 특보·긴급재난문자·통제정보를 함께 확인하며, `50·70·100mm/h`는 예비표본의 사례 부족 때문에 공식 안전정보를 우선함.
- 두 값 중 낮은 값은 대표 강수량과 일반 생활영향 판정값에서 제외함. 최근 60분 수치가 남아 있다는 사실만으로 현재 비 알림을 만들지 않음.
- Marshall–Palmer 기준 가중 F1은 `5mm/h`에서 관측분석 85.6%·평균 81.8%·낮은 값 71.8%, `15mm/h`에서 관측분석 70.3%·평균 75.5%·낮은 값 57.2%, `30mm/h`에서 57.4%·50.9%·44.2%였음. 국내 2020 운용식에서는 `30mm/h` 평균 F1이 68.1%로 관측분석 57.4%보다 높아 고강도 자동 평균정책을 보류함.
- `docs/항목별_문구_표현_기준.md`의 3-1 현재 강수 역할과 3-2 시간당 강수량 문구, `docs/수치_기준_근거자료_선정_항목.md`의 2024년 비교근거를 위 정책으로 갱신함. 3-2는 채택 완료했으며 문구 순서상 다음 항목은 3-3 `누적 강수량 문구`임.
- `scripts/analyze_precip_sample.py`에 기준점별 precision·recall·F1 비교를 추가하고 `tmp/rainfall_2024_preliminary/analysis_results.json`과 `analysis_report.md`를 재생성함. Python 구문검사와 300시간 표본 재실행을 통과함. 재실행을 위해 임시 분석 의존성 폴더에 `numpy`, `cftime`, `netCDF4`를 보완함.
- 이번에는 기준문서·분석스크립트·임시 분석결과·HANDOFF만 변경했으며 앱·서버 제품 코드, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-1 관측분석 누적과 예상 누적 역할 확정

- 사용자가 3-3-1 권장안을 확정함. 현재 위치 누적 강수량에서는 관측장비·관측지점 값을 제외하고 사용자 좌표가 포함된 500m 관측분석 격자를 주자료로 사용하며 레이더 누적추정량은 상세 확인자료로 분리함.
- 해당 시간창을 직접 제공하는 공식 관측분석 누적 필드를 우선하고, 직접 필드가 없으면 완결된 비중첩 `rn_60m` 구간만 합산함. 5분 간격의 겹치는 60분 이동누적을 반복 합산하지 않으며 관측분석·레이더 평균이나 낮은 값으로 대표 누적량을 만들지 않음.
- 누적 강수량 사실은 현재 강수판정과 분리함. 누적값이 남아 있어도 현재 비 알림을 만들지 않고, 현재 `rn_ox`와 레이더 강수에코가 같은 기준시각에 모두 강수일 때만 `현재 위치 주변에서 비가 내리고 있을 수 있어요`를 생성함.
- 관측분석 누적과 예상 누적은 두 문장으로 분리함. 공식 누적예보 원문은 `기상청은 … 예보했어요`, 같은 발표본의 시간별 예보를 앱이 합산한 값은 `기상청의 시간별 예보를 합산하면 … 예상돼요`로 구분함. 두 값을 더한 혼합합계를 메인 대표값이나 공식 사실로 표시하지 않음.
- 채택 대표문구는 `오늘 0시부터 오후 2시까지 현재 위치 주변의 누적 강수량은 18mm로 분석됐어요`, `기상청은 수원에 오후 2시부터 오후 8시까지 25~40mm의 비가 더 내릴 것으로 예보했어요`임.
- `docs/항목별_문구_표현_기준.md`에 진행 3-3과 채택 3-3-1, 다음 권장안 3-3-2를 추가함. `docs/수치_기준_근거자료_선정_항목.md`의 기존 AWS 관측누적·관측지점 문구와 데이터계약을 관측분석 누적 정책으로 갱신함.
- 다음 결정은 3-3-2 `누적 시간창의 읽기 방식`임. 메인 `오늘 누적·앞으로 6시간`, 상세 최근·예상 `3·12·24시간`, 실제 시작·종료시각 병기, 72시간 제한, 누락 시 생성보류를 확정할 차례임.
- 이번에는 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-2 누적 시간창 읽기 방식 확정

- 사용자가 3-3-2 권장안을 확정함. 메인은 `오늘 0시~마지막 완결 분석시각`의 관측분석 누적과 그 이후 `앞으로 6시간` 예상 누적을 분리하고, 상세는 최근·예상 `3·12·24시간`에 실제 시작·종료시각을 함께 표시함.
- 실제 자료 종료시각이 현재시각과 같을 때만 `지금까지`를 사용할 수 있음. 그 외에는 `오후 2시까지`처럼 종료시각을 직접 표시하고, 자료가 오래됐으면 `누적 강수량은 오후 1시까지 분석된 자료예요 · 이후 상태는 달라졌을 수 있어요`를 사용함.
- 자정을 넘는 시간창은 `어제/오늘` 또는 실제 날짜를 표시하고 달력 날짜별 누적과 이동 24시간 누적을 섞지 않음. 72시간은 호우 지속·선행강수 맥락의 상세에서만 사용함.
- 중간 구간이 하나라도 누락되면 0mm로 채우지 않고 해당 누적값 생성을 보류함.
- `docs/항목별_문구_표현_기준.md`에서 3-3-2를 채택 상태로 변경하고 다음 권장안 3-3-3 `범위형 예상 누적 문구`를 추가함.
- 3-3-3 권장안은 정확값·미만·범위·이상·공식 강수없음·미수신을 분리하고, 같은 발표본의 비중첩 구간만 범위 연산으로 합산하는 구조임. 직접 공식 누적예보와 앱의 시간별 예보 합산문구도 분리함.
- 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-3 범위형 예상 누적 문구 확정

- 사용자가 3-3-3 권장안을 확정함. 정확값·미만·범위·이상·공식 강수없음·미수신을 분리하고 같은 발표본의 겹치지 않는 정량 PCP 구간만 범위 연산으로 합산함.
- `1mm 미만 + 1mm 미만 → 2mm 미만`, `1mm 미만 + 4mm → 4mm 이상 5mm 미만`, `5~10mm + 10~19mm → 15~29mm`, `30mm 이상 + 5mm → 35mm 이상`으로 열린 경계를 보존함.
- 공식 강수없음만 0mm로 더하고 미수신·품질오류·정성자료는 0으로 바꾸지 않음. 발표본이 섞이거나 한 구간이 누락되면 누적값 생성을 보류함.
- 기상청이 누적범위를 직접 발표한 사실은 `기상청은 … 예보했어요`, 앱이 시간별 공식예보를 범위 합산한 결과는 `기상청의 시간별 예보를 합산하면 … 예상돼요`로 구분함. 범위 중간값이나 평균값을 대표 누적으로 만들지 않음.
- `docs/항목별_문구_표현_기준.md`에서 3-3-3을 채택 상태로 변경하고 다음 권장안 3-3-4 `생활영향·직접행동·공식 안전정보 연결`을 추가함. `docs/수치_기준_근거자료_선정_항목.md`에도 예상 누적 범위 합산 규칙을 추가함.
- 3-3-4 권장안은 누적량 하나로 피해·활동제한을 단정하지 않고 지속강수·사용자 일정·배수·공식 통제·검증된 대안을 함께 확인함. 일반 화면은 행동·가능성문장을 먼저 보여 주되 실제 공식 긴급정보는 최우선으로 함.
- 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-4 생활영향·행동·공식 안전정보 연결 확정

- 사용자가 3-3-4 권장안을 확정함. 누적 강수량 하나로 침수·외출금지·산책불가를 단정하지 않고, 지속 강수시간·사용자 일정·배수상태·공식 통제·검증된 대안을 함께 확인함.
- 일반 생활화면은 `직접행동 → 내부 생활영향 가능성 → 공식 예보·분석 사실 → 상세근거`를 유지하고, 실제 호우특보·긴급재난문자·침수·통제정보가 있으면 공식 안전행동을 최우선으로 표시함.
- 내부 피해·활동문구는 모두 가능성형으로, 직접행동은 실제 사용자 상태와 행동마감 또는 안전한 대체시간·경로가 확인될 때만 명령형으로 표시함.
- 예상 누적범위가 호우특보 수치기준을 포함해도 앱이 `호우주의보 수준·예상`을 만들지 않고, 실제 기상청 발표가 있을 때만 `수원에는 호우주의보가 발효 중이에요`를 사용함.
- 국내 일 강수량 10mm 대중교통·20mm 카드사용 연구는 집단 수준의 생활영향 보조근거로만 사용하고 개인 외출 취소선이나 안전 임계값으로 사용하지 않음.
- `docs/항목별_문구_표현_기준.md`에서 3-3-4를 채택 상태로 바꾸고 다음 권장안 3-3-5 `자료상태·갱신·차이 문구`를 추가함.
- 3-3-5 권장안은 공식 강수없음·실제 0mm·미수신·품질오류·오래된 자료·예보갱신·관측분석/레이더 차이를 각각 다른 문구와 상태로 처리하며, 불완전한 부분합계를 전체 누적처럼 표시하지 않는 구조임.
- 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-5 사용자 수정안 반영

- 사용자가 3-3-5 권장문구 중 실제 0mm, 앱 미수신, 품질오류, 예보 감소, 관측분석·레이더 차이 표현을 직접 수정해 해당 문구를 반영함.
- 실제 0mm는 `오늘 0시부터 오후 2시까지 현재 위치 주변의 누적 강수량은 0mm예요`로 간결화함.
- 앱 미수신은 `자료를 받아오지 못해 오후 2~8시 예상 누적량을 계산하기 어려워요`, 품질오류는 `자료에 오류가 있어 오후 2~8시 예상 누적량을 계산하기 어려워요`로 변경함. 누락된 원 구간은 데이터에는 보존하되 사용자 문구에서는 생략함.
- 예보 감소는 `오후 3~9시 예상 누적량은 20~30mm예요. 오전 11시 발표 예보의 25~40mm보다 줄었어요`로 변경함. 비교 대상 시간창이 같고 양 끝값이 모두 감소했을 때만 사용한다는 조건은 유지함.
- 자료 간 차이는 `오늘 0시~오후 2시 누적 강수량, 18mm/25mm (기상청 관측분석자료/기상청 레이더)` 형식으로 변경함. 출처 괄호는 두 값의 순서를 매핑하는 상세 비교행에만 사용하고, 두 공간자료가 함께 지지하는 현재 강수 가능성문장의 무괄호 원칙은 유지함.
- 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 3-3-5는 아직 사용자 최종확정 전 권장안 상태임. 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-5 자료상태·갱신·차이 문구 확정

- 사용자가 수정된 3-3-5 권장안을 확정함. 공식 강수없음·실제 0mm·미수신·품질오류·오래된 자료·예보갱신·관측분석/레이더 차이를 각각 다른 상태와 문구로 유지함.
- 불완전한 구간이 있으면 부분합계를 전체 누적처럼 표시하지 않고, 그 누적값만을 근거로 한 생활판정도 보류함. 공식 특보·재난문자·통제정보는 누적 계산 성공 여부와 무관하게 계속 최우선 표시함.
- `docs/항목별_문구_표현_기준.md`에서 3-3-5를 채택 상태로 변경하고 다음 권장안 3-3-6 `여덟 생활항목 연결 문구`를 추가함.
- 3-3-6 권장안은 강풍·블랙아이스(도로살얼음)·자외선·비와 우산 준비·빨래 회수·반려견 산책계획·출퇴근 경로·수면환경 각각에 내부 가능성문구, 직접행동, 필수 추가조건을 연결함.
- 어느 항목도 누적량 하나로 판정하지 않으며 사용자 활동시간과 누적/예보 시간창의 교집합, 항목별 필수 근거, 검증된 대안을 요구함. 중복 행동은 하나로 합치고 공식 안전정보는 생활문구보다 우선함.
- 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3-6 시점·비 표현 다양화

- 사용자가 `비가 이어지면` 같은 반복형 문구를 피하고, `오늘은·낮에는·밤에는·새벽에는·낮 동안은·밤 동안은·밤사이·하루 종일` 등의 시점표현과 `비로 인해·비가 와서·비 때문에·비가 오면·비가 내려·비가 이어져·비가 이어지고·빗방울·빗물`을 의미에 맞게 조합하도록 요청함.
- `docs/항목별_문구_표현_기준.md`의 3-3-4 배수 취약경로 예시와 3-3-6 여덟 생활항목 내부 가능성문구를 서로 다른 자연스러운 구조로 수정함.
- 문장 생성은 `[시점표현] + [비의 상태·원인·대상 표현] + [생활영향 가능성]` 구조를 기본으로 하되 실제 강수시간에 맞춰 시점을 치환하도록 정함.
- `비가 이어져·이어지고`는 연속 강수구간과 시점이 함께 확인될 때, `하루 종일`은 하루 전체 강수가 확인될 때만 사용함. `빗방울`은 사람·옷·털 등에 직접 닿는 영향, `빗물`은 노면·도로·물건에 남은 물을 설명할 때 사용하며 무작위 동의어 교체를 금지함.
- 3-3-6은 사용자 최종확정 전 권장안 상태를 유지함. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-3 완료 및 3-4-1 권장안 시작

- 사용자가 3-3-6 여덟 생활항목 연결 문구와 시점·비 표현 조합 원칙을 확정함. `docs/항목별_문구_표현_기준.md`에서 3-3-6과 3-3 누적 강수량 문구 전체를 채택 상태로 변경함.
- 다음 대항목은 수치기준 문서 순서에 따라 3-4 `호우·집중호우 문구`이며, 첫 결정항목으로 3-4-1 `공식 명칭과 앱 내부 가능성문구 분리` 권장안을 추가함.
- 현재 서버의 단일 `HEAVY_RAIN`은 시간별 강수량 하한 10mm 또는 강수확률 70% 이상과 강수량 하한 5mm 조건을 사용해 공식 강한 비·호우특보·긴급재난문자 어느 기준과도 일치하지 않으며, `WeatherWarning/activeWarnings`에는 실제 공식 특보 연결이 아직 없음.
- 권장안은 공식 강수강도 예보·호우 발생가능성·예비특보·주의보·경보·호우/재난성호우 긴급재난문자를 실제 공식 자료에만 확정형으로 표시하고, 앱 내부 강수집중 판단은 `비가 집중될 수 있어요`, `많은 비가 내릴 가능성이 있어요` 같은 가능성문장으로만 표시함.
- 내부 상태키에는 예상·주의 단계를 보존할 수 있지만 사용자 대표문장에는 공식 단계처럼 보이는 `집중호우 예상/주의 · 앱 분석` 제목을 쓰지 않고 `앱 분석`은 상세근거로 분리하는 방안을 권장함. 공식 정보와 내부 판단이 같은 지역·시간에 겹치면 공식 정보를 대표문장으로 사용함.
- 3-4-1은 아직 사용자 확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-1 확정 및 3-4-2 권장안

- 사용자가 3-4-1 `공식 명칭과 앱 내부 가능성문구 분리`를 확정함. 공식 강수강도·호우 발생가능성·예비특보·주의보·경보·긴급재난문자는 실제 공식 자료에만 확정형으로 표시하고 앱 내부 강수집중 판단은 가능성문장으로 표시함.
- `docs/항목별_문구_표현_기준.md`에서 3-4-1을 채택 상태로 바꾸고 다음 결정항목 3-4-2 `공식 단계별 발표·발효·행동 문구` 권장안을 추가함.
- 3-4-2는 호우특보 발표 가능성, 예비특보, 특보 발표·발효 전, 주의보, 경보, 공식 위험지역·대피 안내, 호우/재난성호우 긴급재난문자, 해제예고, 공식 해제, 최신상태 확인 실패를 각각 다른 사실·행동문구로 처리함.
- 일반 카드·푸시는 행동을 먼저, 공식 사실을 다음 줄에 표시함. 실제 긴급재난문자가 수신되면 일반 생활문구를 숨기고 즉시 안전행동과 공식 발송사실을 최우선 표시함.
- 비가 시작되기 전이고 안전할 때만 배수구 점검·실외 물건 회수·차량 이동 같은 준비행동을 허용함. 비가 시작된 뒤에는 사용자를 배수로·지하공간·침수우려 장소로 보내지 않으며, 공식 대피 요청·명령 또는 공식 위험지역과 현재 위치가 일치할 때만 대피 명령형을 사용함.
- 해제예고·내부 강수량 감소·예보 종료·API 오류·캐시 만료로 공식 특보를 자동 해제하지 않으며, 실제 해제 뒤에도 통제·침수·젖은 노면 근거가 남으면 관련 행동을 유지함.
- 3-4-2는 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-2 발생가능성·예비특보 행동문구 수정

- 사용자가 3-4-2의 호우특보 발표 가능성 행동문구를 `내일 새벽, 최신 예보를 다시 확인하세요`로 수정함.
- 호우 예비특보 행동문구는 `내일 새벽, 하천변과 지하차도를 피할 경로를 확인하세요`로 수정함.
- 두 문구 모두 `내일 새벽 전에`를 `내일 새벽,`으로 바꿨으며 공식 사실문구와 생성조건·제한은 유지함.
- 3-4-2는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-2 확정 및 3-4-3 권장안

- 사용자가 발생가능성 문구 `내일 새벽, 최신 예보를 다시 확인하세요`와 예비특보 문구 `내일 새벽, 하천변과 지하차도를 피할 경로를 확인하세요`로 수정된 3-4-2를 확정함.
- `docs/항목별_문구_표현_기준.md`에서 3-4-2를 채택 상태로 바꾸고 다음 결정항목 3-4-3 `내부 기준별 강수집중 가능성문구` 권장안을 추가함.
- 3-4-3은 공식 호우정보가 없는 경우에만 시간당 예상범위 하한 30mm, 50mm, 3시간 이동누적 하한 90mm와 내부 최우선 행동조건을 시스템 상태로 구분하되, 사용자에게 공식 단계형 제목을 표시하지 않고 시간·위치·실제 예상범위가 포함된 가능성문장으로 제공함.
- 범위 상한만 내부 기준을 넘으면 상위 상태를 확정하지 않고 원래 범위와 불확실성을 표시함. 공식 호우정보가 같은 지역·시간에 있으면 내부 대표문장을 숨기고 예상범위는 상세근거로만 남김.
- 내부 가능성문장은 강수형태에 따라 `집중될 수 있어요`, `내릴 가능성이 있어요`, `누적 강수량이 빠르게 늘 수 있어요`, `강하게 내릴지는 달라질 수 있어요`, `강해질 수도 있어요`를 의미에 맞게 선택함.
- 현재 관측은 가능성문구로 바꾸지 않고 3-2 관측사실 문구를 사용함. 배수·저지대·사용자 활동 조건이 없으면 침수·이동불가 같은 피해문구를 생성하지 않음.
- 3-4-3은 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 사용자 위치 기본전제에 따른 반복 위치문구 제거

- 사용자가 예보와 앱 판단은 사용자가 선택한 위치를 대상으로 한다는 것을 기본 전제로 두고 사용자 문장에서 `현재 위치 주변에`를 어디서든 제거하도록 요청함.
- 이 원칙을 문구 기준의 최상위 표현원칙으로 추가하고 `현재 위치 주변에/에서/의` 변형도 사용자용 문구에서 함께 제거함.
- 현재 강수판단은 `오후 2시에는 비가 내리고 있을 수 있어요`, 한 시간 분석량은 `오후 1~2시 강수량은 18mm로 분석됐어요`, 누적량은 `오늘 0시부터 오후 2시까지 누적 강수량은 18mm로 분석됐어요`처럼 시간과 값만 표시하도록 변경함.
- 시각을 따로 붙이지 않는 현재 강수 알림도 `현재 위치에 비가 내리고 있을 수 있어요`에서 `비가 내리고 있을 수 있어요`로 간결화함.
- 3-4-1·3-4-3의 내부 예보문구도 `오늘 저녁에는 시간당 30~50mm의 비가 집중될 수 있어요`, `앞으로 6시간 안에는 시간당 50~70mm의 비가 내릴 가능성이 있어요`처럼 수정함.
- 기상청 공식 발표구역인 `수원`, 사용자 위치와 실제 공간범위가 다른 인접 격자·인접 지역·다른 구역은 오해를 막기 위해 계속 명시함. 내부 계산에서는 사용자 좌표·격자정보를 그대로 보존함.
- 과거 결정 경위를 보존해야 하는 HANDOFF의 이전 기록은 수정하지 않고 이번 항목으로 새 원칙이 이전 문구를 대체했음을 기록함.
- 3-4-3은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-3 확정 및 3-4-4 권장안

- 사용자가 3-4-3 `내부 기준별 강수집중 가능성문구`와 사용자 위치를 문장의 기본 대상으로 보고 반복 위치문구를 생략하는 원칙을 확정함.
- 문구 기준 문서에서 3-4-3을 채택 상태로 바꾸고 다음 결정항목 3-4-4 `사용자 위치·인접지역·시간 문구` 권장안을 추가함.
- 수치기준 문서의 사용자 노출명 `집중호우 예상/주의 · 앱 분석`을 확정된 문구원칙과 맞게 내부 강수집중 가능성·주의 상태로 정리함. 사용자에게는 단계명이 아니라 실제 시간·예상범위가 들어간 가능성문장을 표시하고 `앱 분석`은 상세근거로 분리함.
- 3-4-4 권장안은 사용자 위치를 포함한 격자에서는 위치문구를 생략하고, 인접 격자만 강할 때는 검증 가능한 경우에 한해 `가까운 지역`, 실제 지역명 또는 둥근 방향·거리로 별도 표시함.
- 인접 지역 표현은 `확인된 지역명 → 둥근 방향·거리 → 채택된 거리기준 안의 가까운 지역 → 상세의 인접 예보격자` 순서로 선택하고, 공간관계를 확인하지 못하면 메인 알림을 만들지 않도록 권장함.
- 사용자 격자와 인접 격자의 값을 합치거나 인접 최대값을 사용자 예보로 승격하지 않음. 서로 다른 해상도의 격자는 셀 개수가 아니라 실제 도형·거리로 비교하며, 위치정확도·자료제품·발표본·유효시간이 맞지 않으면 인접 알림을 만들지 않음.
- 3-4-4는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 3-4-4 방위표현 대안 검토

- 사용자가 `북서쪽` 같은 나침반 방위는 인지하기 어렵다고 보고 더 친숙한 인접지역 표현을 요청함.
- 권장 대안은 방위보다 사용자가 이미 아는 공간관계를 우선하는 것으로, `광교동 쪽`, `수원역 주변`, `회사 근처`, `출근 경로 중 ○○지하차도 주변`처럼 확인된 행정동·지명·저장장소·등록경로를 사용함.
- 인식 가능한 장소명을 만들 수 없으면 `가까운 지역`과 지도 진입을 함께 제공하고, `북서쪽 약 3km` 같은 방위·거리는 메인 문구가 아니라 상세지도 보조정보로 내리는 방안을 권장함.
- `왼쪽·오른쪽·앞쪽`은 화면 회전이나 단말 방향에 따라 달라지므로 메인 위치표현으로 권장하지 않음. `서울 방향` 같은 도로방향도 실제 등록경로와 공식 도로방향이 확인될 때만 사용할 수 있음.
- 아직 3-4-4 본문은 수정하지 않았고 사용자 선택을 기다리는 권장안 상태임. 이번에는 HANDOFF만 변경했으며 앱·서버 제품 코드, 두 기준문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-4 확정 및 3-4-5 권장안

- 사용자가 북서쪽 같은 방위 대신 확인된 행정동·지역명, 주요 지명·시설, 저장장소·등록경로, 가까운 지역과 지도를 순서대로 사용하는 3-4-4 대안을 확정함.
- 문구 기준 문서에서 3-4-4를 채택 상태로 바꾸고 `북서쪽 약 3km` 메인 예시를 `광교동 쪽`, `수원역 주변`, `회사 근처`, `퇴근 경로 중 ○○지하차도 주변` 예시로 교체함. 방위·거리는 지도 상세 보조정보로만 보존함.
- 다음 결정항목으로 3-4-5 `여덟 생활항목 영향·행동 연결` 권장안을 추가함. 호우·강수집중 상태 하나로 모든 생활항목을 켜지 않고 각 항목의 시간·활동·환경·대안 조건이 확인될 때만 생성함.
- 강풍·블랙아이스(도로살얼음)·자외선·우산·빨래·반려견 산책·출퇴근·수면환경에 각각 가능성문구, 직접행동, 필수 추가조건을 연결함.
- 호우주의보는 공식 위험장소 회피를 먼저 표시하고 호우경보에서는 일반 생활추천을 숨김. 호우·재난성호우 긴급재난문자는 여덟 생활항목 전체를 숨기고 즉시 안전행동과 공식 문자내용만 표시함.
- 현재 서버의 단일 `HEAVY_RAIN`은 주로 우산 추천으로 연결되며, 출퇴근·자외선·빨래·산책·제습 등과 공식 호우정보의 충돌을 체계적으로 억제하지 못하는 구현상태를 기록함.
- 3-4-5는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-5 확정 및 3-4-6 권장안

- 사용자가 3-4-5 `여덟 생활항목 영향·행동 연결`을 확정함. 강풍·블랙아이스(도로살얼음)·자외선·우산·빨래·반려견 산책·출퇴근·수면환경은 호우상태 하나로 일괄 생성하지 않고 각 항목의 시간·활동·환경·안전한 대안이 확인될 때만 생성함.
- 문구 기준 문서에서 3-4-5를 채택 상태로 바꾸고 다음 결정항목 3-4-6 `자료상태·충돌·알림 우선순위` 권장안을 추가함.
- 공식 조회 성공·특보 없음, 공식 특보자료 미수신, 마지막 공식 상태가 오래됨, 예보 미수신·품질오류·오래된 자료, 공식 예보자료 간 차이, 공식 특보와 내부 판단의 차이를 각각 다른 상태와 문구로 분리함.
- 공식 특보자료 미수신을 `특보 없음`이나 `해제`로 바꾸지 않고, 예보자료 오류로 공식 특보를 낮추지 않도록 정함. 공식 특보가 없더라도 독립적인 유효 예보자료가 내부기준을 충족하면 앱 가능성문구를 함께 표시할 수 있음.
- 자료 간 차이는 평균이나 큰 값 선택으로 합치지 않고 수치기준에서 정한 선행시간별 우선자료를 사용하며, 우선관계를 정할 수 없으면 영향을 받는 내부 판단만 보류하도록 권장함.
- 알림은 P0 공식 즉시안전, P1 공식 특보, P2 앱 내부 고위험, P3 사전준비, P4 생활추천 순으로 정리함. 공식정보가 내부 알림 뒤 들어오면 중복알림 대신 기존 알림을 교체·승격하고, 같은 회차의 반복조회·표현변형·작은 수치변동으로는 재발송하지 않도록 권장함.
- 3-4-6은 아직 사용자 최종확정 전 권장안 상태임. 이 항목을 확정하면 3-4가 끝나고 3-5 `소나기·갑작스러운 강수 문구`로 이동함. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4-6 사용자 수정안 반영

- 공식 특보자료 미수신 문구를 `자료를 받아오지 못해 현재 호우특보 상태를 확인하기 어려워요`로 변경함. 첫 노출 예시에도 같은 문구를 적용함.
- 공식 예보자료 간 차이 문구는 비교 대상이 강수량임을 문장 앞에서 바로 알 수 있도록 `강수량, 초단기예보는 오후 4~5시 20~40mm, 단기예보는 같은 시간 30~50mm로 예상했어요`로 변경함.
- 미수신을 특보 없음·해제로 처리하지 않는 제한과 예보자료 간 값을 평균내거나 큰 값만 고르지 않는 원칙은 유지함.
- 3-4-6은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-4 완료 및 3-5-1 권장안 시작

- 사용자가 수정된 3-4-6 `자료상태·충돌·알림 우선순위`를 확정함. 공식 특보자료 미수신과 공식 특보 없음·해제를 구분하고, 예보자료 차이는 평균이나 큰 값 선택 없이 같은 시간의 값을 병기하며, 공식정보·앱 내부 판단·생활추천의 알림 우선순위와 중복갱신 규칙을 채택함.
- 문구 기준 문서에서 3-4-6과 3-4 `호우·집중호우 문구` 전체를 채택 상태로 변경함.
- 다음 대항목 3-5 `소나기·갑작스러운 강수 문구`를 시작하고 3-5-1 `공식 소나기와 앱의 갑작스러운 비 명칭·역할 분리` 권장안을 추가함.
- `소나기`는 기상청이 예보·통보한 공식 강수형태에만 사용하고, `갑작스러운 비`는 현재 무강수 뒤 짧은 시간 안에 비가 시작될 수 있음을 알리는 앱의 생활알림 개념으로 분리함. 앱 판단에는 가능성형, 공식 예보·통보 사실에는 확정형 동사를 사용함.
- 공식 소나기 예보와 앱의 갑작스러운 비 조건이 모두 있으면 한 문장으로 확정하지 않고 `40분 안에 비가 시작될 수 있어요`와 `기상청은 수원에 오후 3~4시 소나기를 예보했어요`를 분리하도록 권장함.
- 현재 서버는 단기예보 `PTY=4`를 `SHOWER/소나기`로 변환하지만 소나기 전용 규칙상태가 없고 첫 미래 예보슬롯을 현재값으로 사용함. 초단기 강수예측·현재 강수분석/레이더·공식 통보문·낙뢰 자료가 연결되지 않아 갑작스러운 비 시작·비구름 접근·현재 소나기를 아직 근거 있게 만들 수 없는 상태를 기록함.
- 3-5는 명칭분리, 갑작스러운 비 예상·접근·시작, 소나기 공간·현재상태, 약한 비 표현, 동반위험 행동, 여덟 생활항목, 자료상태·알림 순의 일곱 세부항목으로 진행함.
- 3-5-1은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-1 확정 및 3-5-2 권장안

- 사용자가 3-5-1 `공식 소나기와 앱의 갑작스러운 비 명칭·역할 분리`를 확정함. `소나기`는 기상청이 예보·통보한 공식 강수형태에만 사용하고 앱의 짧은 시간 비 시작 판단은 `갑작스러운 비` 가능성문구로 분리함.
- 문구 기준 문서에서 3-5-1을 채택 상태로 바꾸고 다음 결정항목 3-5-2 `갑작스러운 비 예상·비구름 영향·강수 시작 문구` 권장안을 추가함.
- 갑작스러운 비 예상은 같은 기준시각의 관측분석·레이더가 모두 무강수를 나타내고 앞으로 1시간 안에 첫 10분 예상강수량이 0.1mm 이상일 때만 `40분 안에 비가 시작될 수 있어요`처럼 표시하도록 권장함.
- 강수영역 이동예측은 있지만 사용자 격자의 시작조건이 충족되지 않으면 `40분 안에 비구름의 영향을 받을 수 있어요`로 구분하고 기본 푸시는 보내지 않도록 권장함.
- 직전 정상자료의 무강수 뒤 관측분석·레이더가 모두 강수를 나타내면 `오후 2시부터 비가 내리고 있을 수 있어요`, 직전자료가 없어 시작전이를 확인할 수 없으면 `오후 2시에는 비가 내리고 있을 수 있어요`를 사용하도록 권장함. 앱 판단이므로 `비가 시작됐어요`라고 확정하지 않음.
- 상대시간은 알림 생성시각에 다시 계산하고 카드·상세에는 절대 예상시각을 함께 제공함. 시작예상시각 변경은 예측값의 변경사실로 확정형 표시할 수 있지만 실제 강수발생은 확정하지 않음.
- 종료·잠시 그침·재시작과 같은 강수사상 중복판정은 3-6으로 남김. 3-5-2는 아직 사용자 최종확정 전 권장안 상태임.
- 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-2 확정 및 3-5-3 권장안

- 사용자가 3-5-2 `갑작스러운 비 예상·비구름 영향·강수 시작 문구`를 확정함. 현재 무강수와 1시간 이내 첫 10분 강수예측, 비구름 영향 가능성, 신규 강수확인, 시작시각 미확인 상태를 분리함.
- 문구 기준 문서에서 3-5-2를 채택 상태로 바꾸고 다음 결정항목 3-5-3 `지역 내 소나기·사용자 위치 예상·현재 소나기 문구` 권장안을 추가함.
- 공식 통보문의 `수원 일부 지역·곳에 따라`와 사용자 예보격자의 소나기 코드, 사용자와 다른 격자·저장장소·등록경로의 소나기, 현재 강수분석을 서로 다른 공간상태로 분리함.
- 사용자 격자의 공식 소나기 예보는 `기상청은 수원에 오후 3~4시 소나기를 예보했어요`, 넓은 통보문은 `기상청은 오늘 오후 수원 일부 지역에 소나기가 내릴 수 있다고 알렸어요`로 권장함. 넓은 지역 가능성을 사용자 위치의 소나기로 좁히지 않음.
- 현재 강수분석만 있으면 `오후 2시에는 비가 내리고 있을 수 있어요`로 표시하고, 공식 현재 소나기 통보가 함께 있어도 공식 지역사실과 앱 현재 강수 가능성문구를 두 줄로 분리함.
- 단기예보 정시 소나기 코드는 그 정시 직전 한 시간으로 표시하고, 공식 통보문의 `오후·저녁·밤`을 임의의 정확한 시간범위로 바꾸지 않도록 권장함.
- 사용자와 다른 격자는 확인된 행정동·지명·저장장소·등록경로를 사용하고 `북서쪽`, `현재 위치 주변에`를 메인 문구에서 제외함. 인접 소나기를 사용자 예보로 승격하거나 값을 합치지 않음.
- 3-5-3은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-3 확정 및 3-5-4 권장안

- 사용자가 3-5-3 `지역 내 소나기·사용자 위치 예상·현재 소나기 문구`를 확정함. 공식 통보문의 넓은 지역 가능성, 사용자 예보격자, 다른 지역·저장장소·등록경로, 현재 강수분석을 서로 다른 공간상태로 분리함.
- 문구 기준 문서에서 3-5-3을 채택 상태로 바꾸고 다음 결정항목 3-5-4 `약한 비·이슬비·빗방울·가랑비 표현` 권장안을 추가함.
- `이슬비`는 기상청이 실제 현상으로 식별했을 때만, `빗방울`은 공식 예보코드로, `약한 비`는 시간당 3mm 미만의 강도표현으로, `가랑비처럼 약한 비`는 공식 세부현상을 모를 때의 친숙한 생활표현으로 분리함.
- 관측장비 지점값을 사용자 위치의 현재 이슬비·빗방울 알림으로 사용하지 않음. 관측분석·레이더가 함께 약한 강수를 지지해도 앱은 `오후 2시에는 약한 비가 내리고 있을 수 있어요`까지만 판단하도록 권장함.
- `1mm 미만`은 0mm 또는 강수없음이 아니며, 10분 예상강수량 0.1mm 이상이면 약한 비도 갑작스러운 강수 시작알림에서 제외하지 않음.
- 약한 비의 시간형태에 따라 `시작될 수 있어요`, `가랑비처럼 약한 비`, `이어질 수 있어요`, `잠깐 내릴 수도 있어요`, `내리고 있을 수 있어요`를 구분하고 무작위 동의어 교체를 금지함.
- 외출·보행시간이 겹치고 낙뢰·강한 돌풍이 없을 때만 접이식 우산 행동과 옷·머리카락이 젖을 수 있다는 영향문구를 연결함. 약한 비라는 이유로 우산 불필요나 도로 안전을 확정하지 않음.
- 현재 서버는 PTY=5를 화면에서는 빗방울로 표시하지만 내부에서는 일반 RAIN으로 바꾸며, 이슬비·빗방울·약한 비 전용 상태가 없다는 구현상태를 기록함.
- 3-5-4는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-4 가랑비 표현 제외

- 사용자가 `가랑비`를 자동 문구에서 제외하고 공식 세부현상이 확인되지 않은 약한 비의 친숙한 표현을 `40분 안에 이슬비처럼 약한 비가 시작될 수 있어요`로 변경함.
- 문구 기준 문서와 수치기준 문서에서 `가랑비처럼 약한 비`를 모두 `이슬비처럼 약한 비`로 바꾸고 3-5-4 명칭에서도 가랑비를 제거함.
- `이슬비`를 단독 현상명으로 사용하는 공식 문장과 `이슬비처럼 약한 비`라는 앱 비유형 문장을 구분함. 후자는 공식 이슬비 상태로 저장하지 않고 `LIGHT_RAIN`으로 유지함.
- `가랑비`, `보슬비`, `부슬비`는 자동 문구와 단계명에 사용하지 않도록 권장함. 현재 앱 설정문구·날씨 아이콘 분류·위젯 테스트에는 `가랑비`가 남아 있으며 이번 문구 검토 단계에서는 제품 코드를 변경하지 않음.
- 3-5-4는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-4 확정 및 3-5-5 권장안

- 사용자가 `가랑비`를 제외하고 `이슬비처럼 약한 비`를 친숙한 비유형 표현으로 사용하는 수정안을 포함해 3-5-4를 확정함. 공식 이슬비 단독 현상명과 앱의 비유형 약한 비 문구는 계속 분리함.
- 문구 기준 문서에서 3-5-4를 채택 상태로 바꾸고 다음 결정항목 3-5-5 `소나기 강도·낙뢰·돌풍·우박 행동문구` 권장안을 추가함.
- 소나기 강도는 3-2의 시간당 강수강도 `3·15·30mm/h` 구간을 재사용하고 `50mm/h` 또는 3시간 `90mm` 이상이면 3-4 강수집중 조건도 별도로 평가하도록 권장함.
- 낙뢰·돌풍·우박은 소나기라는 이유로 추정하지 않고 실제 기상청 예측·관측이 있을 때만 공식 사실문구를 생성함. 공식 사실은 `예보했어요·알렸어요·관측됐어요`, 앱 영향은 모두 가능성형으로 분리함.
- 공식 천둥·번개 예상이나 낙뢰 관측이 있으면 일반 우산행동을 숨기고 안전한 건물·자동차 안으로 이동하는 행동을 먼저 표시함. 돌풍은 우산 대신 비옷, 우박은 사람의 실내 이동을 차량·물건 이동보다 우선하도록 권장함.
- 시간당 15mm 이상에서는 `우산을 써도 옷이 젖을 수 있어요`를 사용하고, 대체시간은 실제 강수·낙뢰·바람이 더 적합할 때만 구체적으로 제시함.
- 현재 서버에는 낙뢰·돌풍·우박 전용 필드·Provider가 없고 일반 우산추천을 공식 동반위험 행동으로 교체하는 구조가 없다는 구현상태를 기록함.
- 3-5-5는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-5 약한 소나기 인지표현·노출순서 수정

- 사용자가 3mm 미만과 3~15mm 미만 소나기를 사람이 알아차리기 쉬운 표현으로 설명하고, 내부 생활영향 가능성문구를 공식 예보사실보다 먼저 표시하도록 요청함.
- 3mm 미만은 피부의 가벼운 빗방울, 옷깃·머리카락의 살짝 젖음, `이슬비처럼 약한 비`를 상황별 가능성문구로 추가함.
- 3~15mm 미만은 비가 뚜렷하게 느껴질 수 있음, 5mm/h 이상에서 우산이 없으면 옷·신발이 젖을 수 있음, 안경·차량 유리에 빗물이 맺혀 앞이 흐려 보일 수 있음을 상황별 가능성문구로 추가함.
- `5mm/h` 우산 필요는 3-2에서 채택한 국내 체감기준점이므로 3~15mm 구간 전체에 적용하지 않고 실제 예상범위 하한이 5mm/h 이상일 때만 사용함. 그보다 낮으면 일반 체감문구를 사용함.
- 강도표의 열 순서를 내부 영향 가능성문구 뒤에 공식 사실문구가 오도록 변경함. 실제 노출은 직접행동이 있으면 `직접행동 → 내부 영향 가능성 → 공식 예보사실`, 없으면 `내부 영향 가능성 → 공식 예보사실` 순으로 정리함.
- 15~30mm 예시도 사용자 요청대로 `오후 3~4시에는 우산을 써도 옷이 젖을 수 있어요` 다음에 `기상청은 수원에 오후 3~4시 시간당 15~30mm의 강한 소나기를 예보했어요`가 오도록 유지함.
- 3-5-5는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-5 낙뢰·돌풍 행동 및 3~5mm 구간 수정

- 사용자가 낙뢰 공식 관측문구를 `기상청은 오후 2시 수원에서 낙뢰를 관측했어요`로 변경하고, 낙뢰·돌풍·우박 행동에 현상 원인을 직접 넣도록 요청함.
- 낙뢰 행동은 `낙뢰를 피해 안전한 건물이나 자동차 안으로 이동하세요`를 기본으로 하고, 첫 노출은 `오후 3시 전, 낙뢰를 피해 야외활동을 마치고 안전한 건물이나 자동차 안으로 이동하세요`와 `오후 3~4시 낙뢰 예보가 있으니 야외활동을 자제하세요` 순으로 변경함.
- 돌풍은 공식 가능성 예보일 때 `돌풍이 불 수 있으니 외출해야 한다면 우산 대신 비옷을 준비하세요`, 같은 시간·지역에서 공식 관측됐을 때만 `돌풍이 부니 …`를 사용하도록 구분함. 우박 행동은 사용자가 제시한 기존 문구를 유지함.
- `5mm/h`는 사람이 비를 처음 느끼는 공식 경계가 아니라 3-2에서 채택한 기상청 체감자료의 우산 행동기준이므로 `3~15mm/h 미만`을 `3~5mm/h 미만`과 `5~15mm/h 미만`으로 분리함.
- 3~5mm/h 미만은 빗방울이 이어짐, 옷깃·머리카락이 조금씩 젖음, 안경·차량 유리에 빗방울이 맺힘으로 표현함. 5~15mm/h 미만은 비가 뚜렷하게 느껴짐, 우산이 없으면 옷·신발이 젖음, 유리에 빗물이 맺혀 앞이 흐려질 수 있음으로 표현함.
- 3mm 미만 첫 표현은 사용자 요청대로 `얼굴이나 팔에 가벼운 빗방울이 닿을 수 있어요`로 간결화함.
- 수치기준 문서의 소나기 강도표도 3~5와 5~15mm/h 미만으로 분리함. 이 구분은 앱 생활표현·행동 선택용이며 새로운 공식 강수강도명이 아님.
- 3-5-5는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-5 약한 강수구간 표현 간소화

- 사용자가 `3mm/h 미만`에서 옷깃·머리카락이 젖는다는 영향을 제거하고 `가벼운 빗방울이 떨어질 수 있어요`처럼 빗방울 자체만 설명하도록 요청함.
- `3~5mm/h 미만`에서는 `비가 이어진다`, `비를 느낀다`는 표현을 제거하고 `옷깃이나 머리카락이 조금씩 젖을 수 있어요`만 생활영향으로 사용하도록 변경함.
- `5~15mm/h 미만`에서는 `비가 내리는 것이 뚜렷하게 느껴질 수 있어요`와 같은 추상적인 강도 체감표현을 제거하고, 우산이 없을 때 옷·신발이 젖는 영향과 안경·차량 유리의 시야 영향만 유지함.
- 각 구간의 문구 다양성은 서로 다른 영향을 추가하지 않고 같은 채택 의미에 시간·활동조건을 연결하는 범위에서 유지함.
- 3-5-5는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-5 3~5mm/h 대표문구 수정

- 사용자가 `3~5mm/h 미만` 대표문구를 `오후 3~4시에는 옷이나 머리카락이 조금 젖을 만큼 비가 올 수도 있어요`로 변경함.
- `옷깃`, `조금씩 젖을 수 있어요` 표현을 각각 `옷`, `조금 젖을 만큼 비가 올 수도 있어요`로 바꾸고 강도표·세부 변형·첫 노출 예시·수치기준 문서를 같은 의미로 통일함.
- 3-5-5는 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-5 확정 및 3-5-6 권장안

- 사용자가 최종 수정된 3-5-5 `소나기 강도·낙뢰·돌풍·우박 행동문구`를 확정함. `3mm/h 미만`은 가벼운 빗방울, `3~5mm/h 미만`은 옷이나 머리카락이 조금 젖을 만큼의 비, `5~15mm/h 미만`은 우산이 없을 때 옷·신발이 젖을 수 있다는 영향으로 채택함.
- 낙뢰·돌풍·우박의 공식 예측·관측 사실과 내부 생활영향을 분리하고, 낙뢰는 안전한 건물·자동차 안으로 이동, 돌풍은 우산 대신 비옷, 우박은 야외활동 종료와 실내 이동을 우선하는 행동을 채택함.
- 문구 기준 문서에서 3-5-5를 채택 상태로 바꾸고 다음 결정항목 3-5-6 `여덟 생활항목 영향·행동 연결` 권장안을 추가함.
- 3-5-6은 소나기·갑작스러운 비를 여덟 생활문구의 일괄 결론으로 사용하지 않고, 실제 활동시간과 항목별 추가조건이 맞을 때만 강풍·블랙아이스(도로살얼음)·자외선·우산·빨래·산책·출퇴근·수면 문구를 생성하도록 권장함.
- 직접행동을 내부 영향과 공식 사실보다 먼저 표시하며, 낙뢰·돌풍·우박이 있으면 일반 우산·빨래·산책 행동을 안전이동·비옷·실내대기 행동으로 교체하도록 권장함.
- 대체시간·경로·장소는 실제로 더 적합하고 이용 가능할 때만 구체적으로 표시하며, 사용자 계획이나 실내환경자료가 없으면 빨래·산책·경로·수면상태를 추정하지 않도록 권장함.
- 3-5-6은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-6 직접행동에 판단 이유 선행

- 사용자가 3-5-6의 직접행동만 보아도 이유를 알 수 있도록 모든 행동문장을 `판단 이유 → 행동` 순서로 변경하도록 요청함.
- 강풍·우산·빨래·산책·출퇴근·수면환경은 `소나기가 내릴 수 있으니` 또는 이를 포함한 시간·추가조건 문구를 행동 앞에 붙임.
- 블랙아이스(도로살얼음)는 `소나기로 젖은 도로가 밤사이 얼 수 있으니`, 자외선은 `소나기가 내린 이후, 자외선이 강할 수 있으니`를 각각 행동 이유로 사용함.
- 첫 노출 예시의 빨래·산책·운전 행동도 같은 이유 선행형 문장으로 변경함. 구체적인 시간·행동은 기존처럼 실제 활동과 더 적합한 대안이 확인될 때만 생성함.
- 3-5-6은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5-6 확정 및 3-5-7 권장안

- 사용자가 이유를 앞에 넣은 3-5-6 `여덟 생활항목 영향·행동 연결`을 확정함. 일반 항목은 소나기 가능성, 자외선은 소나기 이후의 실제 자외선지수, 블랙아이스(도로살얼음)는 소나기로 젖은 도로의 결빙 가능성을 행동 이유로 사용함.
- 문구 기준 문서에서 3-5-6을 채택 상태로 바꾸고 3-5의 마지막 결정항목인 3-5-7 `자료상태·충돌·알림 우선순위와 3-6 경계` 권장안을 추가함.
- 3-5-7은 공식 강수없음, 앱 미수신, 품질오류, 이전 자료, 일부 시간 누락, 예보제품 간 차이, 현재 강수판단과 당시 예보의 차이, 관측분석·레이더의 차이를 각각 다른 상태와 문구로 분리함.
- 관측분석과 레이더가 같은 좌표·시각의 강수를 함께 지지할 때만 현재 강수 가능성 알림을 만들고, 서로 다르면 결과를 병기하되 하나의 현재값으로 합치지 않도록 권장함.
- P0 즉시안전, P1 공식 동반위험, P2 현재 강수·강한 소나기, P3 갑작스러운 비 사전준비, P4 일반 생활판정 순으로 알림을 처리하고 같은 회차는 교체·승격하되 반복 발송하지 않도록 권장함.
- 자료 미수신·품질오류 자체는 보통 새 푸시를 만들지 않고, `비가 그쳤어요`와 다시 시작한 비의 새 회차·재알림 기준은 다음 3-6에서 정하도록 경계를 둠.
- 현재 알림 작업은 설치별 추천조회가 빈 구현이고, 날짜·일반 알림키 기록만으로는 소나기 발표본·격자·유효구간·행동마감을 구분한 중복억제가 어렵다는 구현상태를 기록함.
- 3-5-7은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 문구 기준 문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 수치기준 문서, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 공식 없음 변화노출 및 현재판단·예보 차이 문장 통일

- 사용자가 공식 `강수없음·강설없음` 등 현상없음 상태는 이전 공식자료와 달라지지 않았다면 안내하지 않도록 요청함.
- 공식 없음상태는 원자료와 내부 상태에는 보존하되 단독 알림·카드·대표문장은 만들지 않으며, 같은 위치·대상시간의 직전 현상예보가 최신 발표에서 없어졌을 때만 `마지막으로 확인한 소나기 예보와는 달리 오후 3시 강수없음으로 예보됐어요`처럼 변화사실을 한 번 표시하도록 전체 공통원칙과 강수 관련 채택문구에 적용함.
- 특보 없음은 변화가 없어도 안내하지 않고, 이전에 특보가 있었다면 빈 목록이 아니라 실제 공식 해제자료로 안내하도록 폭염·한파·호우 예시에도 적용함.
- 공식 없음예보와 앱 현재판단이 다를 때는 단독 없음안내의 예외로 공식 예보를 비교문장 안에 표시함. 비는 `오후 2시에는 비가 내리고 있을 수 있다고 예상되나, 기상청은 오후 2시 강수없음으로 예보했어요.`, `앱의 현재 강수판단과 예보가 달라요` 두 문장으로 변경함.
- 같은 문장틀을 눈·강풍 등 모든 기상항목에 적용하며 현상명·기관의 공식 없음표현·항목명만 바꾸고, 같은 시각·공간·요소를 비교할 수 있을 때만 사용함.
- 3-5-7은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-5 완료 및 3-6-1 권장안 시작

- 사용자가 공식 없음 변화노출, 현재판단·공식예보 차이문장, 자료상태·충돌·알림 우선순위를 포함한 3-5-7을 확정함. 문구 기준 문서에서 3-5-7과 3-5 전체를 채택 상태로 변경함.
- 다음 대항목 3-6 `강수 시작·종료 문구`를 시작하고, 첫 결정항목으로 3-6-1 `공식 예측·자료사실과 앱의 시작·종료 상태 분리` 권장안을 추가함.
- 3-6은 공식자료·앱상태 분리, 시작예상·현재시작, 잠시 그침·그침, 다시 시작, 강수회차·중복알림, 여덟 생활항목, 자료상태·3-7 경계의 일곱 세부항목으로 진행함.
- 이전 확정에 따라 관측장비 지점값을 사용자 위치 시작·종료 알림에 사용하지 않고, 같은 위치·시각의 기상청 관측분석자료와 레이더가 함께 강수 또는 무강수를 지지할 때만 앱의 시작·현재·잠시 그침·그침·재시작 가능성상태를 만들도록 권장함.
- 기상청 초단기 강수예측의 시작·종료 예상은 공식 예측사실로 확정형 안내하되 실제 발생으로 바꾸지 않고, 앱 현재판단은 `시작했을 수 있어요`, `내리고 있을 수 있어요`, `그친 상태일 수 있어요` 같은 가능성형으로 표시함.
- 변화 없는 공식 강수없음은 3-5-7 원칙에 따라 노출하지 않고, 이전 공식자료에서 비 예보가 없어졌거나 앱 현재판단과 공식예보를 비교할 때만 표시함.
- 현재 서버는 시간 단위 미래예보를 현재값처럼 사용하고, 관측분석·레이더·10분 강수예측 Provider와 강수회차 상태전이가 없어 3-6 상태를 아직 생성할 수 없다는 구현상태를 기록함.
- 3-6-1은 아직 사용자 최종확정 전 권장안 상태임. 이번에는 두 기준문서와 HANDOFF만 변경했으며 앱·서버 제품 코드, 분석자료, 자동테스트, 배포, 커밋은 수행하지 않음.

### 문구 기준 3-6-1 확정 및 3-6-2 권장안

- 사용자가 3-6-1 `공식 예측·자료사실과 앱의 시작·종료 상태 분리`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정 항목인 3-6-2 `곧 시작·시작확인·현재 내림 문구` 권장안을 추가했다.
- 세 상태를 다음과 같이 분리했다.
  - `곧 시작`: 현재는 무강수이고 1시간 안에 첫 강수가 예상됨 — `20분 뒤 비가 시작될 수 있어요`
  - `시작확인`: 관측분석·레이더가 모두 무강수에서 강수로 전환 — `오후 2시에는 비가 내리기 시작했을 수 있어요`
  - `현재 내림`: 두 공간자료가 모두 현재 강수를 나타냄 — `오후 2시에는 비가 내리고 있을 수 있어요`
- 현재 위치의 시작·현재 내림 판단에는 관측장비 지점값을 사용하지 않고, 같은 격자·기준시각의 기상청 관측분석자료와 레이더가 함께 지지하는 경우만 사용하도록 유지했다.
- `곧 시작` 알림 뒤 예정대로 비가 시작되면 새 푸시를 보내지 않고 기존 카드를 갱신한다. 준비시간이 줄거나 강도·낙뢰·돌풍·우박으로 행동이 달라질 때만 교체·승격 재알림을 허용한다.
- 강수강도별 체감·행동은 3-5-5에서 확정한 4개 구간을 그대로 연결했다.
- 공식 `강수없음`은 이전 발표와 같으면 숨기고, 직전 비 예보의 해제성 변경 또는 앱 현재판단과 충돌할 때만 표시하도록 반영했다.
- 현재 서버에는 관측분석·레이더·10분 초단기 강수예측 Provider와 강수회차·상태전이 저장구조가 없어 구현 전 추가가 필요하다.
- 다음 사용자 결정은 3-6-2 권장안의 문구와 알림규칙 확정 여부다. 확정 후 3-6-3 `잠시 그침·그침 문구`로 진행한다.

### 문구 기준 3-6-2 확정 및 3-6-3 권장안

- 사용자가 3-6-2 `곧 시작·시작확인·현재 내림 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정 항목인 3-6-3 `잠시 그침·그침 문구` 권장안을 추가했다.
- 앱의 `잠시 그침`은 현재 관측분석·레이더가 함께 무강수이지만 1시간 안에 비가 다시 예상되는 상태, `그침`은 두 자료가 함께 무강수이고 앞으로 1시간 안에 비가 예상되지 않는 상태로 구분했다.
- 두 상태 모두 공식 관측 종료가 아닌 앱 내부판단이므로 `지금은 비가 잠시 그친 상태일 수 있어요`, `현재는 비가 그친 상태일 수 있어요`처럼 가능성형을 사용했다.
- 기상청의 미래 종료예측은 `기상청 초단기 강수예측에서는 수원에 오후 4시부터 비가 그칠 것으로 예상했어요`라는 공식 예측사실로 분리하고, 예상시각 도달만으로 현재 그침판정을 만들지 않도록 했다.
- 잠시 그침은 기존 강수카드 갱신만 기본으로 하고, 그침은 앞서 같은 강수회차의 푸시를 보낸 경우에만 종료 갱신알림을 한 번 허용하는 방식을 권장했다.
- `비가 잠시 쉬어가요`, `비가 그쳤어요`, `비가 완전히 끝났어요`, `지금 이동하기 좋아요`는 각각 의인화·확정·시간범위 확대·안전조건 누락 문제가 있어 사용하지 않도록 했다.
- 변화 없는 공식 강수없음은 표시하지 않고, 직전 비 예보가 최신 발표에서 없어졌을 때만 변화문구를 한 번 표시하도록 유지했다.
- 현재 제품에는 필요한 공간자료·10분 예측 Provider와 강수회차·종료 상태전이가 없어 아직 이 판단과 중복억제를 구현할 수 없다.
- 다음 사용자 결정은 3-6-3 권장안의 문구·알림원칙 확정 여부다. 확정 후 3-6-4 `다시 시작 예상·재시작 문구`로 진행한다.

### 문구 기준 3-6-3 확정 및 3-6-4 권장안

- 사용자가 3-6-3 `잠시 그침·그침 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정 항목인 3-6-4 `다시 시작 예상·재시작 문구` 권장안을 추가했다.
- `다시`는 같은 사용자 격자에서 관측분석자료·레이더가 함께 앞선 강수, 완전한 10분 무강수, 이후 재강수 또는 재강수예측을 순서대로 확인한 경우에만 사용하도록 했다.
- 미래 재강수는 `40분 뒤 비가 다시 내릴 수 있어요`, 현재 재시작은 `오후 4시 10분부터 비가 다시 내리고 있을 수 있어요`라는 앱 가능성형으로 권장했다.
- 공식 예측사실은 앱의 이력해석을 섞지 않고 `기상청 초단기 강수예측에서는 수원에 오후 4시 40분부터 비를 예상했어요`로 분리했다.
- 잠시 그침 때 같은 재강수를 이미 안내했거나 재강수 예상알림을 보낸 뒤 예정대로 시작된 경우에는 새 푸시 없이 기존 카드를 갱신하도록 권장했다.
- 앞선 예상알림이 없었거나 예상보다 일찍 시작돼 행동마감이 달라진 경우, 강도·낙뢰·돌풍·우박으로 행동이 바뀐 경우에만 재알림을 허용했다.
- 자료 누락구간은 무강수이력이 아니므로 누락 뒤 자료가 복구돼 강수가 나타나도 자동으로 `다시`를 붙이지 않도록 했다.
- 현재 제품에는 공간자료·10분 예측 Provider, 강수회차·상태전이·세부 알림이력이 없어 아직 처음 시작과 재시작을 구현상 구분할 수 없다.
- 다음 사용자 결정은 3-6-4 권장안 확정 여부다. 확정 후 3-6-5 `강수회차·시간·공간·중복알림 처리`로 진행한다.

### 문구 기준 3-6-4 확정 및 3-6-5 권장안

- 사용자가 3-6-4 `다시 시작 예상·재시작 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정 항목인 3-6-5 `강수회차·시간·공간·중복알림 처리` 권장안을 추가했다.
- 사용자에게 `강수회차`를 표시하지 않고, 앱 내부에서는 시작예상부터 그침·재시작까지를 `appRainFlowId` 하나로 묶어 한 카드의 상태를 갱신하도록 권장했다. 이는 기상학적 강우사상이 아니라 알림 중복억제를 위한 운영단위다.
- `officialForecastId`, `appRainFlowId`, `transitionId`, `notificationPurpose`, `locationContextId`를 분리하고 공식 발표본이 바뀌었다는 이유만으로 새 푸시를 만들지 않도록 했다.
- 비 알림 묶음은 그침 직후 닫지 않고 공간자료 무강수와 앞으로 6시간의 비 없음이 함께 확인된 뒤 닫도록 권장했다. 6시간은 내부 알림 운영시간창이며 공식 강우사상 기준이나 사용자 문구로 사용하지 않는다.
- 발표시각, 유효시각, 분석·레이더 기준시각, 앱 상태전환시각, 평가시각, 발송시각을 각각 저장하고 상대시간은 절대시각에서 매번 다시 계산하도록 했다.
- 사용자 좌표를 각 공간자료의 셀로 독립 변환하고 서로 다른 자료의 셀 번호를 같은 공간으로 간주하지 않으며, 위치가 바뀌면 새 좌표에서 재평가하도록 했다.
- 상태전이별로 새 푸시·기존 카드 갱신·조건부 재알림을 구분하고, 같은 직접행동을 이미 알렸다면 문구나 공식 발표본만 바뀐 경우에는 다시 보내지 않도록 했다.
- 권장 중복키는 `installationId + locationContextId + appRainFlowId + transitionId + notificationPurpose + priority`이며 본문 문자열 대신 행동·위험·유효시간창·강수형태의 의미기반 해시를 권장했다.
- 현재 서버는 `notification_history`를 발송 전에 조회하지 않고 발송 뒤 덮어쓰며, 설치별 추천조회가 빈 구현이고 강수상태·위치·회차가 알림키에 없어 이번 권장안을 아직 구현하지 못한다.
- 다음 사용자 결정은 3-6-5 권장안 확정 여부다. 확정 후 3-6-6 `여덟 생활항목 영향·행동 연결`로 진행한다.

### 문구 기준 3-6-5 확정 및 3-6-6 권장안

- 사용자가 3-6-5 `강수회차·시간·공간·중복알림 처리`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정 항목인 3-6-6 `여덟 생활항목 영향·행동 연결` 권장안을 추가했다.
- 강수 시작·현재 내림·잠시 그침·그침·재시작은 여덟 생활항목을 일괄 생성·종료하는 결론이 아니라 각 항목을 다시 평가하는 입력으로 사용하도록 했다.
- 강풍, 블랙아이스(도로살얼음), 자외선, 우산, 빨래, 반려견 산책, 출퇴근 경로, 수면환경별로 시작·현재·재시작 및 잠시 그침·그침 뒤의 대표 행동·영향문구와 필수조건을 정리했다.
- 모든 직접행동은 이유를 앞에 두고, 내부 영향은 가능성형으로 유지하며, 공식 강수형태가 소나기일 때만 `소나기`를 사용하도록 했다.
- 그침 뒤에도 강풍·블랙아이스(도로살얼음)·자외선·젖은 노면·실내습도를 다시 평가하고, 짧은 잠시 그침만으로 이동·산책·실외건조를 권하지 않도록 했다.
- 같은 비에서 여덟 개의 푸시를 보내지 않고 가장 높은 안전우선순위와 가장 이른 행동마감을 가진 행동 한 개를 대표로 표시하며 나머지는 같은 카드 상세에 모으도록 했다.
- 블랙아이스(도로살얼음)·자외선·수면환경처럼 강수 뒤 다른 시간에 새 행동이 필요한 항목은 자체 유효시간과 추가조건이 충족될 때 별도 생활알림을 허용했다.
- 현재 서버에는 강수 상태전이, 사용자 생활계획, 동반위험·공간자료 Provider와 대표행동 교체 구조가 없어 권장문구를 아직 근거 있게 생성할 수 없다.
- 다음 사용자 결정은 3-6-6 권장안 확정 여부다. 확정 후 3-6-7 `자료상태·충돌·알림 우선순위와 3-7 강설 문구의 경계`로 진행한다.

### 문구 기준 3-6-6 확정 및 3-6-7 권장안

- 사용자가 3-6-6 `여덟 생활항목 영향·행동 연결`을 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 3-6의 마지막 결정항목인 3-6-7 `자료상태·충돌·알림 우선순위와 3-7 강설 문구의 경계` 권장안을 추가했다.
- 강수자료 미수신, 품질오류, 이전 자료, 관측분석·레이더 불일치, 강수예측 미수신·오류·일부 누락, 예보제품 간 시작시각 차이, 직전 비 예보의 강수없음 변경을 각각 다른 사용자 문구와 상태로 분리했다.
- 관측분석·레이더가 다를 때 값을 평균내거나 한쪽을 선택하지 않고 강수 시작·그침·재시작판단을 보류하며 두 자료를 각각 표시하도록 했다.
- 앱 현재 비 판단과 공식 강수없음, 앱 현재 그침판단과 공식 비 예보의 차이를 모두 `판단·예보 사실문장 + 앱의 현재 강수판단과 예보가 달라요` 두 문장 구조로 정리했다.
- P0 즉시안전, P1 공식 위험·행동승격, P2 현재 강수·즉시 생활행동, P3 시작·재시작 준비, P4 그침·후속 생활관리, 상태안내 순으로 알림을 처리하도록 권장했다.
- 3-6은 강수의 연속성을, 3-7은 공식 강수형태를 담당하도록 분리했다. 같은 강수가 비에서 눈으로 바뀌면 강수묶음은 유지하고 `오후 6시에는 비가 눈으로 바뀔 수 있어요`, `기상청은 수원에 오후 6시부터 눈을 예보했어요`로 현상문구만 교체하도록 했다.
- 현재 강수형태 enum이 PTY `1·5`, `2·6`, `3·7`을 각각 합쳐 약한 공식 현상명이 규칙단계에서 사라질 수 있다는 구현상태를 기록했다.
- 현재 서버에는 필요한 공간·예측 Provider, 자료별 품질·기준시각 상태, 우선순위·중복억제 구조가 없어 권장안을 아직 구현할 수 없다.
- 다음 사용자 결정은 3-6-7 권장안 확정 여부다. 확정되면 3-6 전체가 완료되고 다음 대항목 3-7 `강설 가능성 문구`로 진행한다.

### 문구 기준 3-6 완료 및 3-7-1 권장안 시작

- 사용자가 3-6-7 `자료상태·충돌·알림 우선순위와 3-7 강설 문구의 경계`를 확정해 문구 기준 문서에서 3-6-7과 3-6 전체를 채택 상태로 변경했다.
- 다음 대항목 3-7 `강설 가능성 문구`를 시작하고 공식 명칭·눈 예보와 현재 가능성·혼합강수·눈날림·적설정보 경계·여덟 생활항목·자료상태의 일곱 세부항목으로 나눴다.
- 첫 결정항목 3-7-1 `공식 강수형태 명칭과 앱 내부판단의 역할 분리` 권장안을 추가했다.
- PTY `2 비/눈`, `3 눈`, `6 빗방울/눈날림`, `7 눈날림`의 공식 원형을 보존하되 사용자 대표문장에는 `비 또는 눈`, `빗방울과 눈날림`처럼 자연스럽게 풀어 쓰도록 권장했다.
- 공식 PTY 예보는 `기상청은 수원에 오후 5~6시 눈을 예보했어요`처럼 확정형 예보사실로, 앱 상태는 `오후 5~6시에는 눈이 내릴 수 있어요`, `오후 4시에는 눈이 내리고 있을 수 있어요`처럼 가능성형으로 분리했다.
- 현재 눈 가능성은 사용자 좌표의 관측분석·레이더가 현재 강수를 함께 나타내고 공식 강수형태 자료가 눈을 지지할 때만 만들며, 관측장비 지점값을 사용자 위치의 현재 눈값으로 사용하지 않도록 했다.
- 일반 강수확률 POP를 별도 눈 확률로 표시하지 않고, 실제 기온·습구온도 하나로 공식 강수형태를 바꾸지 않도록 했다.
- 눈 예보는 적설·대설·결빙 확정이 아니며 적설량 없음도 강설없음이 아니라는 역할경계를 두고, 눈 PTY만으로 `폭설`, `도로가 얼었어요`, `눈이 쌓일 거예요`를 만들지 않도록 했다.
- 현재 서버·앱은 PTY 약한 현상코드를 큰 enum으로 합치고 POP를 `snowProbability`로 복사하며 첫 미래예보를 현재값처럼 사용해 역할분리가 구현되지 않았다는 상태를 기록했다.
- 다음 사용자 결정은 3-7-1 권장안 확정 여부다. 확정 후 3-7-2 `눈 예보·현재 눈 가능성·시간·위치 문구`로 진행한다.

### 문구 기준 3-7-1 확정 및 3-7-2 권장안

- 사용자가 3-7-1 `공식 강수형태 명칭과 앱 내부판단의 역할 분리`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-7-2 `눈 예보·현재 눈 가능성·시간·위치 문구` 권장안을 추가했다.
- 시간 단위 눈 PTY는 원래 유효구간을 `오후 5~6시`처럼 표시하고 인접한 정상 눈 구간만 합치며, 발표시각은 변화·최신성 설명이 필요할 때만 상세에 표시하도록 했다.
- 10분 강수예측과 시간 단위 눈 PTY의 시간범위가 다르면 `20분 뒤 비나 눈이 내리기 시작할 수 있어요`와 `기상청은 수원에 오후 5~6시 눈을 예보했어요`를 분리하고, 공식 근거 없이 `20분 뒤 눈`으로 좁히지 않도록 했다.
- 현재 눈 가능성은 같은 사용자 좌표·기준시각의 관측분석자료·레이더가 강수를 함께 나타내고 초단기실황 PTY가 눈을 지지할 때만 `오후 4시에는 눈이 내리고 있을 수 있어요`로 생성하도록 권장했다.
- 현재 눈 자동알림에는 관측장비 지점값을 사용하지 않고 세 공간자료의 명칭·기준시각·격자를 상세근거로 각각 보존하며 사용자 문장에는 출처괄호와 `현재 위치 주변에`를 붙이지 않도록 했다.
- 사용자 격자 눈 예보와 `경기남부 일부 지역` 같은 넓은 통보문을 분리하고, 지역 일부 예보만으로 수원의 눈이나 현재 눈을 단정하지 않도록 했다.
- 같은 강수묶음에서 눈 예보알림 뒤 예상대로 현재 눈이 확인되면 카드만 갱신하고, 앞선 알림이 없거나 예상보다 이른 시작·강수형태 변화로 행동이 달라질 때만 재알림을 허용했다.
- 현재 서버는 단기예보 첫 미래슬롯을 현재값처럼 사용하고 관측분석·레이더·초단기실황 PTY·10분 강수예측 Provider가 없어 이 구분을 구현하지 못한다.
- 다음 사용자 결정은 3-7-2 권장안 확정 여부다. 확정 후 3-7-3 `비·눈 혼합과 비에서 눈으로 바뀌는 문구`로 진행한다.

### 문구 기준 3-7-2 확정 및 3-7-3 권장안

- 사용자가 3-7-2 `눈 예보·현재 눈 가능성·시간·위치 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-7-3 `비·눈 혼합과 비에서 눈으로 바뀌는 문구` 권장안을 추가했다.
- 공식 PTY=2는 상세에서 `비/눈` 원형을 보존하고 대표 공식문장은 `비 또는 눈`, 앱 문장은 `비와 눈이 섞이거나 강수형태가 바뀔 수 있어요`로 풀어 쓰도록 했다.
- PTY=2만으로 `진눈깨비`라고 확정하지 않고, 실제 공식 관측·통보가 진눈깨비를 명시한 경우에만 공식 사실로 사용하도록 했다.
- 비 → 비/눈 → 눈, 눈 → 비/눈 → 비의 시간구간별 공식 예보사실과 앱 가능성문구를 정리했다.
- 관측분석·레이더가 강수 연속을 지지하면 비에서 눈으로 바뀌어도 같은 강수묶음을 유지하고 `비가 그쳤다`, `눈이 새로 시작됐다`는 중복알림을 만들지 않도록 했다.
- 강수형태가 눈으로 바뀌어 적설·도로 결빙정보 확인 등 행동이 새로 필요할 때만 기존 강수알림을 교체·재알림하고, 예상대로 전환된 경우에는 카드만 갱신하도록 했다.
- 눈이 비로 바뀌어도 적설·젖은 노면·결빙이 사라지거나 길이 안전해졌다고 판단하지 않도록 했다.
- 현재 서버는 PTY 2·6을 같은 `RAIN_SNOW`로 합치고 현재 강수형태 전환 Provider·상태가 없어 이 문구를 구현하지 못한다.
- 다음 사용자 결정은 3-7-3 권장안 확정 여부다. 확정 후 3-7-4 `눈날림·약한 눈·적설량 없음 문구`로 진행한다.

### 문구 기준 3-7-3 확정 및 3-7-4 권장안

- 사용자가 3-7-3 `비·눈 혼합과 비에서 눈으로 바뀌는 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-7-4 `눈날림·약한 눈·적설량 없음 문구` 권장안을 추가했다.
- 공식 `PTY=7 눈날림`은 공식 사실에서 그대로 보존하고, 앱 대표문장은 `오후 5~6시에는 눈이 가볍게 날릴 수 있어요`로 정했다. `가벼운 눈발이 날릴 수 있어요`, `눈이 흩날릴 수 있어요`를 대체문구로 추가했다.
- 현재 눈날림은 사용자 좌표의 관측분석·레이더가 현재 강수를 함께 나타내고 초단기실황 PTY=7이 같은 기준시각에서 확인될 때만 가능성형으로 생성하도록 권장했다.
- PTY는 강수형태이지 강도자료가 아니므로 `눈`, `눈날림`을 앱이 자동으로 `약한 눈`이라고 바꾸지 않으며, 공식 원문이 약한 눈을 명시한 경우에만 공식 사실로 보존하도록 했다.
- 눈이 내리는지, 쌓이는지, 얼마나 쌓이는지를 서로 다른 상태로 분리하고, 명시적 `적설없음·0`과 적설자료 누락·미수신을 구분했다.
- 눈 PTY와 `적설없음`이 함께 있으면 `눈은 내릴 수 있지만 바닥에 쌓이지 않을 수도 있어요`, 적설자료가 없으면 `눈은 내릴 수 있지만 얼마나 쌓일지는 판단하기 어려워요`로 표시하도록 권장했다.
- `적설없음`으로 강설없음이나 도로안전을 단정하지 않고 블랙아이스(도로살얼음)·젖은 노면·통제 상태도 자동 해제하지 않도록 했다.
- 눈날림 자체보다 새 직접행동의 유무를 푸시 기준으로 삼고, 쌓일 수 있는 눈·적설·대설특보·통제로 행동이 달라질 때만 재알림을 허용했다.
- 현재 서버는 PTY 3·7과 2·6을 각각 같은 enum으로 합치고 적설자료의 없음·범위·누락이 호환 숫자값과 앱 파싱에서 혼동될 수 있어 권장안을 아직 정확히 구현하지 못한다.
- 다음 사용자 결정은 3-7-4 권장안 확정 여부다. 확정 후 3-7-5 `강수확률·기온·적설·특보·결빙 연결 한계`로 진행한다.

### 문구 기준 3-7-4 확정 및 3-7-5 권장안

- 사용자가 3-7-4 `눈날림·약한 눈·적설량 없음 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-7-5 `강수확률·기온·적설·대설·결빙정보의 연결 제한` 권장안을 추가했다.
- 눈 PTY와 POP가 함께 있어도 POP는 `강수확률`로만 표시하고 `눈 올 확률`이나 눈 위험점수로 바꾸지 않도록 했다. 대표 공식문장은 `기상청은 수원에 오후 5~6시 눈을 예보했고, 같은 시간 강수확률은 60%예요`로 정했다.
- 예보·관측기온, 습구온도, 체감온도 하나로 강수형태를 새로 만들거나 바꾸지 않고, 눈과 영하기온이 함께 예보돼도 노면자료가 없으면 `도로가 얼지는 판단하기 어려워요`로 제한했다.
- 눈 PTY와 양의 SNO가 같은 유효시간에 있으면 `눈이 내려 쌓일 수 있어요`까지 연결하되 구체적인 1시간 신적설 양·체감·위험단계는 3-8로 넘겼다.
- SNO가 양수인데 눈 PTY가 없으면 눈 예보를 새로 만들지 않고 `강수형태와 적설량 자료가 달라요`라는 원자료 충돌로 표시하도록 했다.
- 공식 대설주의보·경보는 확정형 공식 사실로 우선 안내하고, 앱의 PTY·POP·SNO 조합으로 `대설주의보`, `대설경보`, `폭설`을 만들지 않도록 했다. 특보 없음은 직전 상태에서 달라졌을 때만 안내한다.
- 공식 노면 결빙과 공식 블랙아이스(도로살얼음) 관측을 구분하고, 일반 결빙을 블랙아이스(도로살얼음)로 바꾸거나 눈·적설·영하기온만으로 발생을 확정하지 않도록 했다.
- 도로통제·결빙·블랙아이스(도로살얼음) 관측과 대설특보를 일반 눈 예보보다 우선하며, POP나 기온만 바뀌고 직접행동이 같으면 카드만 갱신하도록 했다.
- 현재 서버는 POP를 `snowProbability`와 눈 심각도로 사용하고, SNO 양수만으로 눈 예상을 만들며, 임의 적설설정값으로 `HEAVY_SNOW`·`폭설 주의`를 생성할 수 있다. 공식 대설특보·도로상태 Provider도 없어 권장안대로 역할을 분리하지 못한다.
- 다음 사용자 결정은 3-7-5 권장안 확정 여부다. 확정 후 3-7-6 `여덟 생활항목 영향·행동 연결`로 진행한다.

### 문구 기준 3-7-5 확정 및 3-7-6 권장안

- 사용자가 3-7-5 `강수확률·기온·적설·대설·결빙정보의 연결 제한`을 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-7-6 `여덟 생활항목 영향·행동 연결` 권장안을 추가했다.
- 눈·비와 눈·눈날림은 여덟 생활항목을 모두 생성하는 결론이 아니라 각 항목을 다시 평가하는 입력으로 사용하고, 눈 시간과 사용자 활동시간 및 항목별 추가조건이 함께 확인될 때만 문구를 만들도록 했다.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경별 내부 영향 가능성문구·이유가 앞선 직접행동·필수조건을 정리했다.
- 눈과 강한 바람이 겹치면 일반 우산을 후드가 있는 방수 겉옷으로 교체하고, 눈 예보 하나로 바람의 시야·보행영향을 만들지 않도록 했다.
- 블랙아이스(도로살얼음)는 같은 구간의 실제 눈·젖은 노면·융설수와 노면온도·수분·재결빙시간을, 자외선은 남아 있는 적설면과 공식 자외선지수를 추가조건으로 요구했다.
- 실외 빨래에는 `눈이 내릴 수 있으니 오후 5시 전에 실외 빨래를 실내로 들여놓으세요`, 더 적합한 산책시간이 실제로 확인되면 `눈이 내릴 수 있으니 가능하다면 산책시간을 오후 8시로 옮기세요`를 대표행동으로 정했다.
- 반려견 산책은 개체상태·기온·바람·적설·노면·제설제를 확인하고 대체시간이 없으면 산책 후 발과 털을 씻어 말리는 행동을 제시하도록 했다.
- 출퇴근은 일반 눈 예보에서 도로·대중교통 운행정보 확인만 권하고, 공식 위험구간과 통행 가능한 대체경로가 있을 때만 `○○고가도로를 피해 △△도로로 가세요`라고 제안하도록 했다.
- 수면환경은 눈 자체가 아니라 취침시간 외기온과 실내온도 근거가 함께 있을 때 `잠들기 전에 난방으로 수면 환경을 조절하세요`를 만들도록 했다.
- 하나의 눈 상황에서 여덟 개 푸시를 보내지 않고 도로통제·대설경보·결빙관측, 야외안전, 시작 전 행동, 이동·방수준비, 사후생활관리 순으로 대표행동 한 개를 선택하도록 했다.
- 현재 서버는 눈 관련 생활추천을 일반 이동주의로 축약하고 사용자 일정·경로·실내환경 및 공식 특보·노면·제설·자외선 반사조건 Provider가 없어 이번 권장안을 구현하지 못한다.
- 다음 사용자 결정은 3-7-6 권장안 확정 여부다. 확정 후 3-7-7 `자료상태·충돌·알림 우선순위와 3-8 시간당 적설량 문구의 경계`로 진행한다.

### 문구 기준 3-7-6 확정 및 3-7-7 권장안

- 사용자가 3-7-6 `여덟 생활항목 영향·행동 연결`을 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 3-7의 마지막 결정항목 3-7-7 `자료상태·충돌·알림 우선순위와 3-8 시간당 적설량 문구의 경계` 권장안을 추가했다.
- 강수형태·현재 강수·적설량 자료의 미수신, 품질오류, 이전 자료, 시간대 누락, 제품 미제공을 각각 다른 사용자 문구와 상태로 구분하고 어느 것도 강수없음·적설없음·0cm로 바꾸지 않도록 했다.
- 관측분석·레이더가 현재 강수를 함께 지지하지만 강수형태 자료가 없으면 `오후 4시에는 비나 눈이 내리고 있을 수 있어요`까지만 표시하고 비인지 눈인지 판단을 보류하도록 했다.
- 눈 PTY가 정상이고 SNO만 부족하면 공식 눈 예보와 강설 가능성은 유지하고 `적설량 자료를 받아오지 못해 오후 5~6시 예상 신적설을 확인하기 어려워요`를 별도 표시하도록 했다.
- 초단기·단기예보 강수형태 차이, PTY 강수없음·SNO 양수 차이, 앱 현재 눈·공식 강수없음, 앱 현재 비·공식 눈을 각각 두 문장 비교형식으로 정리했다.
- 직전 눈 예보가 실제로 강수없음이나 비로 바뀐 경우에만 `마지막으로 확인한 눈 예보와는 달리 ...`라고 안내하고, 변화 없는 강수없음·적설없음·대설특보 없음은 표시하지 않도록 했다.
- P0 공식 통제·즉시회피, P1 대설·강풍특보와 결빙관측, P2 현재 눈·즉시행동, P3 눈 시작·형태변화 준비, P4 적설갱신·사후생활관리, 자료상태 순으로 알림 우선순위를 정했다.
- 3-7은 강수형태·눈 시간·현재 가능성·기본 생활준비를, 3-8은 1시간 신적설 값·범위·정성단계·시간당 영향문구를 담당하도록 분리했다.
- PTY와 양의 SNO가 함께 있으면 같은 눈 카드에 3-8 정보를 추가하고, SNO가 없으면 눈 문구는 유지하되 3-8 수치문구만 만들지 않으며, SNO만 양수이면 공식 SNO 사실과 자료차이만 표시하도록 했다.
- 현재 서버는 자료별 상태·시각을 독립 보존하지 않고 PTY 공식 구분과 SNO 범위를 축약하며 현재 강수·강수형태·특보·노면 Provider와 의미기반 알림키가 없어 이번 권장안을 구현하지 못한다.
- 다음 사용자 결정은 3-7-7 권장안 확정 여부다. 확정되면 3-7 전체가 완료되고 3-8 `시간당 적설량 문구`의 첫 항목으로 진행한다.

### 문구 기준 3-7 완료 및 3-8-1 권장안 시작

- 사용자가 3-7-7 `자료상태·충돌·알림 우선순위와 3-8 시간당 적설량 문구의 경계`를 확정해 문구 기준 문서에서 3-7-7과 3-7 전체를 채택 상태로 변경했다.
- 다음 대항목 3-8 `시간당 적설량 문구`를 시작하고 명칭·정량값·공식 정성단계와 체감표현·예보와 관측 비교·영향행동·여덟 생활항목·자료상태의 일곱 세부항목으로 나눴다.
- 첫 결정항목 3-8-1 `시간당 적설량·1시간 신적설 명칭과 시간창·역할 분리` 권장안을 추가했다.
- 카드·설정의 친숙한 항목명은 `시간당 적설량`, 상세·데이터와 공식 사실문구의 정확한 명칭은 `1시간 신적설`로 정했다.
- 오후 6시 SNO는 표시시각 직전 한 시간인 `오후 5~6시`로 읽고, `기상청은 수원의 오후 5~6시 1시간 신적설을 1.8cm로 예보했어요`라고 공식 사실을 표시하도록 했다.
- 앱 가능성문구는 `오후 5~6시에는 눈이 1.8cm가량 새로 쌓일 수 있어요`로 정하고, 공식 예보수치가 실제로 그대로 쌓인다고 확정하지 않도록 했다.
- 예보 1시간 신적설, 최근 1시간 관측 신적설, 현재 전체 적설을 서로 다른 값으로 분리하고 여러 시간별 값을 합친 누적은 3-9로 넘겼다.
- 관측분석·레이더·현재 강수형태는 현재 눈 가능성을 판단하는 자료이지만 새로 쌓인 눈의 깊이를 만들 수 없도록 했다.
- 공식 지점 적설관측은 사용자 좌표의 시간당 적설값으로 사용하지 않으며 현재 제품에는 사용자 위치의 최근 1시간 신적설 공간자료가 없어 자동 위치알림에는 단기예보 SNO만 사용하도록 했다.
- 1시간 신적설 하나로 많은 눈·강한 눈·폭설·대설주의보·미끄러운 도로·시설물 하중을 만들지 않고 각 후속항목으로 넘겼다.
- 현재 서버·앱은 SNO 범위를 호환 숫자나 첫 숫자로 축약하고 시간구간 의미를 문장에 반영하지 않으며, 시간당 1cm를 `HEAVY_SNOW`·`폭설 주의`로 연결해 이번 역할분리를 구현하지 못한다.
- 다음 사용자 결정은 3-8-1 권장안 확정 여부다. 확정 후 3-8-2 `정량값·미만·이상·단위·반올림 문구`로 진행한다.

### 3-8-1 사용자 친화 명칭 수정

- 사용자가 `신적설`이라는 단어가 익숙하지 않다고 지적해 3-8-1 권장안의 사용자 노출명칭을 수정했다.
- 카드·설정 항목명은 `시간당 적설량`, 사용자 명칭은 `새로 쌓인 눈`, 최근 관측문장은 `최근 한 시간 동안 새로 쌓인 눈`, 현재 총량은 `현재 쌓인 눈`으로 사용한다.
- `1시간 신적설`은 사용자 대표문장과 상세설명에서 제외하고 내부 데이터명·원자료 근거의 `SNO · 1시간 신적설`에서만 보존한다.
- 미래 예보문장은 시제에 맞게 `기상청은 수원에 오후 5~6시 눈이 1.8cm 새로 쌓일 것으로 예보했어요`로 수정했다.
- 사용자가 사용자 표현도 `새로 쌓인 눈`으로 해달라고 요청한 내용을 반영했다.
- 다음 사용자 결정은 수정된 3-8-1 권장안 확정 여부다. 확정 후 3-8-2로 진행한다.

### 문구 기준 3-8-1 확정 및 3-8-2 권장안

- 사용자가 수정된 3-8-1 `시간당 적설량·새로 쌓인 눈 명칭과 시간창·역할 분리`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-8-2 `정량값·미만·이상·단위·반올림 문구` 권장안을 추가했다.
- 공식 SNO의 적설없음·`0.5cm 미만`·정확한 실수값·`5cm 이상`·명시적 범위를 서로 다른 자료형으로 보존하고 사용자 문장에서도 경계표현을 유지하도록 했다.
- `0.5cm 미만`은 0cm나 정확히 0.5cm로, `5cm 이상`은 정확히 5cm나 임의 상한범위로 바꾸지 않도록 했다.
- 앱 가능성문구는 `오후 5~6시에는 눈이 1.8cm가량 쌓일 수 있어요`, 공식 사실은 `기상청은 수원에 오후 5~6시 눈이 1.8cm 쌓일 것으로 예보했어요`로 구분했다.
- 정확한 값의 앱 문구에만 `가량`을 허용하고, 미만·이상·명시적 범위에는 `가량`을 덧붙이지 않도록 했다.
- 변화 없는 적설없음은 표시하지 않고 직전 양의 적설량 예보에서 실제로 달라졌을 때만 `마지막으로 확인한 적설량 예보와는 달리 ...`라고 한 번 안내하도록 했다.
- 사용자 단위는 숫자와 붙인 `cm`로 통일하고 한 시간 구간을 문장에 표시하므로 `cm/h`를 사용하지 않으며 정수는 불필요한 `.0` 없이 표시하도록 했다.
- 공식 정성단계와 내부 판정은 반올림 전 원자료·범위경계를 사용하고, 반올림으로 1cm 경계를 넘나들어 단계를 바꾸지 않도록 했다.
- 현재 서버는 범위모델을 보존하는 기초가 있지만 호환 숫자에는 하한만 전달하고 앱은 첫 숫자만 읽으며 눈 규칙도 하한을 사용해 미만·이상 의미를 잃을 수 있다.
- 다음 사용자 결정은 3-8-2 권장안 확정 여부다. 확정 후 3-8-3 `공식 (보통) 눈·많은 눈과 기준별 체감표현 3종`으로 진행한다.

### 3-8 사용자 문장의 `새로` 반복 제거

- 사용자가 카드 제목 `새로 쌓인 눈`에서 의미가 이미 전달되므로 그 아래 사용자 문장에서 `새로`를 모두 빼달라고 요청했다.
- 카드 제목 `새로 쌓인 눈`은 유지하고 앱 문장은 `오후 5~6시에는 눈이 1.8cm가량 쌓일 수 있어요`, 공식 사실은 `기상청은 수원에 오후 5~6시 눈이 1.8cm 쌓일 것으로 예보했어요`로 수정했다.
- 적설없음은 `눈은 내릴 수 있지만 바닥에 쌓이지 않을 수도 있어요`, 자료상태는 `눈이 얼마나 쌓일지 확인하기 어려워요`로 수정했다.
- 다음 사용자 결정은 수정된 3-8-2 권장안 확정 여부다.

### 문구 기준 3-8-2 확정 및 3-8-3 권장안

- 사용자가 수정된 3-8-2 `정량값·미만·이상·단위·반올림 문구`를 확정해 `docs/항목별_문구_표현_기준.md`에서 채택 상태로 변경했다.
- 다음 결정항목 3-8-3 `공식 (보통) 눈·많은 눈과 기준별 체감표현 3종` 권장안을 추가했다.
- 기상청의 시간당 적설 정성분류인 `1cm 미만=(보통) 눈`, `1cm 이상=많은 눈`을 반올림 전 원자료·범위경계로 판정하고 공식 사실은 확정형으로 안내하도록 했다.
- 원자료·출처 상세에는 `(보통) 눈`을 보존하고 사용자 문장에서는 `시간당 분류는 보통 눈이에요`처럼 괄호 없이 자연스럽게 읽도록 했다.
- `(보통) 눈`과 `많은 눈` 각각에 `바닥 상태`, `쌓이는 모습`, `사용자가 알아차리는 정도`를 표현하는 가능성형 체감문구 3종을 마련했다.
- `많은 눈`은 시간당 정성분류일 뿐 대설특보·폭설·위험단계가 아니며, 이 명칭 하나로 결빙·교통통제·시야저하·시설물 피해를 생성하지 않도록 했다.
- `0.5~1.5cm`처럼 1cm 경계를 걸치는 범위는 앱이 정성단계를 임의 선택하지 않고, 공식 정성코드가 없으면 적설범위만 표시하도록 했다.
- 연장기간 정성코드 `1·2`는 각각 1cm·2cm나 3시간 누적이 아니라 해당 3시간 중 가장 강한 1시간의 `(보통) 눈·많은 눈`임을 문장에 명시하도록 했다.
- 사용자 체감문장과 정량·공식 사실문장에서는 카드 제목 아래 `새로`를 반복하지 않았다.
- 다음 사용자 결정은 3-8-3 권장안 확정 여부다. 확정 후 3-8-4 `예보·최근 한 시간 적설관측·현재 쌓인 눈 비교문구`로 진행한다.

### 3-8-3 국내 연구근거 재조사 및 내부 체감 4단계 수정

- 사용자가 시간당 적설 체감문구에 실제 사람의 체감연구나 리서치 기준이 있는지 재검토를 요청했다.
- 기상청 정책연구 `기상예보 유효성 확보 방안 연구`에서 최종 공식안 전에 시간당 신적설을 `0.1~0.5cm 미만`, `0.5~1.5cm 미만`, `1.5~3cm 미만`, `3cm 이상`의 4단계로 검토한 사실을 확인했다.
- 같은 연구에서 최종 공식 서비스는 미세한 수치차이로 단계가 달라지는 문제와 예보관·전문가 의견을 반영해 `1cm 미만=(보통) 눈`, `1cm 이상=많은 눈`의 2단계로 축소했다.
- 공개 보고서가 국민 체감과 기준안의 부합을 직접 확인했다고 적은 설문항목은 1시간 강수량과 풍속이며, 시간당 적설 4단계별 체감문장 선택결과나 응답률은 공개하지 않았다. 따라서 특정 한국어 문장을 사람 대상 연구로 검증됐다고 표현하지 않도록 했다.
- `docs/수치_기준_근거자료_선정_항목.md`에 정책연구의 4단계 검토안, 최종 2단계 도출과정, 설문근거의 한계를 추가했다.
- `docs/항목별_문구_표현_기준.md`의 3-8-3을 `공식 2단계 + 연구구간을 적용한 내부 체감 4단계` 구조로 수정하고, 네 단계마다 생활 체감·장면 가능성문구 3종을 마련했다.
- 공식 2단계는 기상청 사실문구에만, 내부 4단계는 체감문구 선택에만 사용한다. 내부 단계는 공식 `(보통) 눈·많은 눈`, 대설특보·폭설·피해단계를 대체하지 않는다.
- 원자료 범위가 여러 내부 경계를 걸치거나 3시간 정성코드만 제공되면 구체적인 내부 체감단계를 선택하지 않도록 했다.
- 다음 사용자 결정은 근거를 보강해 수정한 3-8-3 권장안 확정 여부다.

### 3-8-3 실제 적설량·사건·교통자료 비교 보강

- 사용자가 실제 적설량과 발생 사건을 비교해 시간당 적설 기준을 보강할 수 있는지 추가 확인을 요청했다.
- 국립기상과학원·강릉원주대의 강원도 일반국도 연구에서 기상청 적설과 VDS 교통자료를 시간 일치시킨 결과, 적설일의 교통량은 무적설일보다 11~22%, 주행속도는 5~10% 낮았음을 확인했다.
- 같은 연구에서 1시간 신적설과 시간대별 교통량의 상관은 모든 지점에서 0.2 미만이었고 주행속도에는 6시간 신적설이 가장 유의했으므로, 시간당 적설량 하나로 사고·정체·지연을 판정하지 않도록 했다.
- 2005~2017년 7개 광역시 연구에서 연도별 일 신적설 3cm·5cm·10cm 이상인 날 수와 교통사고의 상관계수는 각각 0.28·0.42·0.51이었으나, 이는 일 단위 누적 노출의 지역·연도 상관이므로 시간당 경계나 개별 사고 원인으로 옮기지 않도록 했다.
- 수도권기상청 대설 재난문자 운영기준에서 관측 1시간 신적설 5cm 이상은 교통사고 대응, 24시간 신적설 20cm 이상과 1시간 신적설 3cm 이상 동시 충족은 시설물 붕괴 대응 조건임을 확인했다.
- 2008~2012년 삼성교통안전문화연구소 분석 보도는 적설일 사고 1.6배, 적설량 1cm 증가 때 평균 사고 약 10% 증가, 7~8cm에서 최대라고 전했으나 원시자료·모형이 공개되지 않은 오래된 요약이므로 보조사례로만 기록했다.
- 2024년 11월 수원 일최심신적설 32.3cm·일최심적설 43.0cm와 경기도 확정 피해액 3,919억원을 극단적 누적·지속 강설 사례로 기록하되, 수원 지점값을 도 전체 피해의 단일 임계값으로 사용하지 않도록 했다.
- `docs/수치_기준_근거자료_선정_항목.md` 3-8 근거표와 실제 사건 비교 결론을 보강하고, `docs/항목별_문구_표현_기준.md` 3-8-3에 사건자료의 적용경계를 추가했다.
- 결론은 내부 체감 4단계는 유지하되 사건자료는 별도 영향·행동 조건으로 사용한다는 것이다. 공식 안전안내문자를 실제 수신하면 사실·행동을 먼저 안내하고, 수치만 충족하면 피해 가능성형 내부판정만 허용한다.
- 다음 사용자 결정은 사건근거까지 보강한 3-8-3 권장안 확정 여부다. 확정 후 3-8-4 `예보·최근 한 시간 적설관측·현재 쌓인 눈 비교문구`로 진행한다.

### 3-8-3 사용자 제시 체감문구 반영

- 사용자가 시간당 적설 내부 4단계의 체감문구 3종을 직접 수정해 제시했으며 `docs/항목별_문구_표현_기준.md`에 반영했다.
- `0.1~0.5cm 미만`은 바닥에 아주 얇게 쌓임·살짝 내려앉은 느낌·눈이 쌓일 것 같은 느낌으로 정리했다.
- `0.5~1.5cm 미만`은 바닥이 눈으로 덮일 가능성·눈이 쌓일 가능성·눈이 쌓였다고 느낄 가능성으로 정리했다.
- `1.5~3cm 미만`은 눈이 꽤 쌓일 가능성·바닥이 눈으로 꽤 덮인 느낌·눈이 꽤 쌓였다고 느낄 가능성으로 정리했다.
- `3cm 이상`은 짧은 시간 동안 빠르게 쌓일 가능성·바닥에 쌓인 눈이 빠르게 늘어날 가능성·빠르게 쌓였다고 느낄 가능성으로 정리했다.
- 사용자 원문의 `짧은 시간동안`은 내용 변경 없이 맞춤법에 따라 `짧은 시간 동안`으로 띄어썼다.
- 정량값과 함께 표시하는 0.8cm·1.8cm 예시의 첫 체감문장도 수정된 표현과 일치시켰다.
- 3-8-3은 아직 사용자 확정 전이다. 확정 후 다음 항목은 3-8-4 `예보·최근 한 시간 적설관측·현재 쌓인 눈 비교문구`다.

### 문구 기준 3-8-3 확정 및 3-8-4 권장안

- 사용자가 직접 수정한 시간당 적설 체감 4단계·단계별 문구 3종을 포함해 3-8-3을 확정했으며 `docs/항목별_문구_표현_기준.md`의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-8-4 `예보·최근 한 시간 적설관측·현재 쌓인 눈 비교문구` 권장안을 추가했다.
- 사용자에게는 전문용어 `신적설·SD_H01·SD`를 노출하지 않고 `오후 5~6시 쌓일 것으로 예보된 눈`, `최근 한 시간 동안 관측된 눈`, `현재 쌓인 눈`으로 분리했다.
- 예보 SNO, 최근 한 시간 적설관측, 현재 전체 적설의 시간창과 역할을 분리하고 현재 전체 적설을 시간당 값과 빼거나 더하지 않도록 했다.
- 비교문장은 예보와 관측의 종료시각·한 시간 구간이 같고, 관측지점이 같은 예보격자 안에 있으며, 양쪽 품질이 정상일 때만 만들도록 했다.
- 정확한 값은 `오후 5~6시 예보 0.8cm보다 관측된 양이 0.4cm 많아요`처럼 예보시간·예보값·차이를 모두 표시하고, 미만·이상·범위는 구간연산으로 범위 안·일부 겹침만 표현하도록 했다.
- 공식 관측사실은 `오후 6시 수원에서 최근 한 시간 동안 눈 1.2cm가 관측됐어요`, 현재 전체 적설은 `오후 6시 수원에서 현재 쌓인 눈은 4.6cm로 관측됐어요`로 정했다.
- 사용자 문장 뒤의 `(기상관측장비지점기준)`은 사용하지 않고 출처 상세에서 `기상청 적설관측 · 수원 관측지점 · 현재 위치에서 거리`를 분리해 보여주도록 했다.
- 관측지점이 다른 격자에 있거나 사용자 격자에 적설관측이 없으면 가장 가까운 값을 현재 위치의 실제 적설로 확정하지 않고 두 사실을 따로 표시하도록 했다.
- 레이더·관측분석자료는 현재 눈 가능성을 보조할 수 있지만 바닥 적설깊이를 직접 제공하지 않으므로 최근 한 시간 적설량이나 현재 전체 적설량으로 환산하지 않도록 했다.
- 기본순서는 최근 한 시간 공식 관측 → 같은 시간 예보와 차이 → 필요한 경우 현재 쌓인 눈이며, 3-8-5에서 직접행동 조건이 확인되면 이유가 포함된 행동을 가장 먼저 표시하도록 했다.
- 현재 프로젝트에는 적설관측 Provider와 예보격자·관측지점 공간연결 모델이 없어 실제 비교기능을 구현할 수 없고 단기예보 SNO만 표시 가능함을 기록했다.
- 3-8-4는 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-8-5 `시간당 새 적설의 영향·직접행동·대설 연결 제한`이다.

### 3-8-4 예보·관측 유사 허용차 반영

- 사용자가 비교문장은 `○cm가 관측됐어요` 뒤에 노출되는 것을 전제로 하고, 예보와 관측의 차이가 0.5cm 이내이면 `오후 5~6시 예보 내용과 유사하게 관측됐어요`로 표시하도록 요청했다.
- 정확한 값끼리는 절댓값 차이를, 미만·이상·명시적 예보범위는 관측값과 예보구간 사이의 거리를 사용하도록 3-8-4 권장안을 수정했다.
- 관측값이 예보범위 안에 있으면 구간거리는 0으로, 범위 밖이면 가장 가까운 경계까지의 거리로 계산한다. 이 거리가 0.5cm 이하이면 유사문구를 사용한다.
- 원자료 기준 차이가 정확히 0.5cm인 경우도 유사문구에 포함하고 0.5cm를 초과할 때만 `예보 ○cm보다 관측된 양이 ○cm 많아요·적어요`라고 차이를 표시하도록 했다.
- 0.5cm는 기상청 관측장비의 공식 오차나 예보정확도라고 표현하지 않고, 작은 차이를 과도하게 강조하지 않기 위한 앱 비교 허용차로 기록했다.
- 관측도 범위여서 예보범위와 일부만 겹치면 유사·많음·적음을 선택하지 않고 두 범위가 일부 겹친다는 사실만 표시하도록 했다.
- 3-8-4는 계속 사용자 미확정 권장안이다.

### 문구 기준 3-8-4 확정 및 3-8-5 권장안

- 사용자가 예보·최근 한 시간 관측·현재 쌓인 눈 비교와 0.5cm 유사 허용차를 포함한 3-8-4를 확정해 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-8-5 `시간당 적설량의 영향·직접행동·대설 연결 제한` 권장안을 추가했다.
- `0.1~3cm 미만`은 시간당 적설량만으로 피해·교통영향을 만들지 않고 3-8-3의 체감·적설사실까지만 표시하도록 했다.
- `3~5cm 미만`은 짧은 시간 동안 빠르게 쌓일 가능성을 표시하고, 사용자 이동·야외활동이 겹칠 때만 강설 전 경로정보 확인이나 활동 마감 행동을 앞에 제안하도록 했다.
- `5cm 이상` 예보는 이동이 어려워질 가능성과 조건부 일정조정을 안내할 수 있지만, 관측기준인 대설 안전안내문자 발송이나 대설특보를 확정하지 않도록 했다.
- 관측 최근 1시간 5cm 이상과 공식 교통사고 대응 안전안내문자를 분리했다. 공식 발송자료가 확인되면 발송사실과 직접행동을 우선하고, 수치만 충족하면 교통영향 가능성형 내부판정만 만들도록 했다.
- 시설물 붕괴 대응은 관측 최근 24시간 20cm 이상과 최근 1시간 3cm 이상 동시 충족에 따른 공식 문자 또는 누적 적설·현재 적설·눈 무게·취약시설의 복합근거를 요구하도록 했다. 최근 한 시간 3cm 하나만으로 시설물 피해를 만들지 않는다.
- 공식 시간당 `많은 눈`, 대설 발생가능성 정보·예비특보·주의보·경보, 교통사고·시설물 대응 대설 안전안내문자, 앱 내부 영향 가능성을 각각 다른 상태와 문구로 분리했다.
- 출력순서는 이유가 포함된 직접행동 → 내부 영향 가능성 또는 공식 위험정보 → 공식 적설관측·예보 → 필요한 예보·관측 비교로 정했다.
- 현재 서버의 `1cm 이상 또는 최근 3시간 하한합계 3cm → HEAVY_SNOW → 폭설 주의` 연결은 공식 분류·내부 영향·특보·안전안내문자를 혼합하므로 후속 구현에서 분해하고 `폭설 주의` 단일 추천명을 제거해야 함을 기록했다.
- 3-8-5는 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-8-6 `여덟 생활항목 영향·행동 연결`이다.

### 3-8-5 `5cm 이상` 예보 직접행동 문구 수정

- 사용자가 `5cm 이상` 예보에서 더 나은 이동시간이 있을 때의 직접행동을 `눈이 많이 내릴 수 있으니, 가능하다면 오후 5시 전에 이동을 마치세요`로 수정했다.
- 더 나은 이동시간이 확인되지 않을 때의 직접행동은 `눈이 많이 쌓일 수 있으니, 외출 전에 도로 통제와 대중교통 운행정보를 확인하세요`로 수정했다.
- 내부 영향 `오후 5~6시에는 눈이 많이 쌓여 도로 이동이 어려워질 수 있어요`와 공식 사실 `기상청은 수원에 오후 5~6시 눈이 5cm 이상 쌓일 것으로 예보했어요`는 유지했다.
- 3-8-5는 계속 사용자 미확정 권장안이다.

### 문구 기준 3-8-5 확정 및 3-8-6 권장안

- 사용자가 수정한 `5cm 이상` 예보 직접행동을 포함해 3-8-5를 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-8-6 `여덟 생활항목 영향·행동 연결` 권장안을 추가했다.
- 3-7-6의 눈 유무 기반 생활문구를 바탕으로 시간당 적설량이 행동강도와 알림 우선순위를 바꾸는 조건을 추가했다.
- `0.1~3cm 미만`은 체감·기본 생활준비, `3~5cm 미만`은 활동이 겹칠 때 경로정보 확인·야외활동 마감, `5cm 이상`은 실제 대체시간이 있을 때 이동·산책시간 조정 또는 통제·운행정보 확인을 우선하도록 했다.
- 강풍은 별도 풍속·돌풍정보, 블랙아이스(도로살얼음)는 같은 도로의 수분·노면온도, 자외선은 남은 적설면·공식 자외선지수, 수면환경은 외기온·실내온도 자료를 각각 요구하도록 했다. 시간당 적설량만으로 네 상태를 생성하지 않는다.
- 비와 우산 준비·빨래 회수·반려견 산책·출퇴근은 눈 시간과 사용자 활동이 겹칠 때만 생성하며, 이유가 포함된 직접행동을 내부 영향·공식 예보보다 먼저 표시하도록 했다.
- 강풍이 있으면 우산 대신 후드가 있는 방수 겉옷을, 빨래는 눈 시작 전에 안전하게 회수할 수 있을 때만, 산책시간 변경은 대체시간이 실제로 더 적합할 때만, 특정 우회는 공식 위험구간과 통행 가능한 대체경로가 함께 있을 때만 제안하도록 했다.
- `5cm 이상`과 출퇴근이 겹치면 이동안전 행동을 대표로 사용하고 우산·빨래·산책은 상세로 내리며, 하나의 적설예보로 여덟 개 푸시를 보내지 않도록 했다.
- 공식 통제·대설경보·대피명령, 대설 안전안내문자, 이동·야외활동, 시작 전 회수·변경, 출퇴근·방수, 눈 뒤 블랙아이스(도로살얼음)·자외선·발 세척, 수면환경 순으로 대표행동 우선순위를 정했다.
- 현재 프로젝트에는 여덟 항목의 사용자 일정·상태와 다수 공식·노면·실내 Provider가 없어 권장안을 완전하게 구현할 수 없고, `HEAVY_SNOW` 단일상태와 대표행동 미분리를 후속 구현과제로 기록했다.
- 3-8-6은 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-8-7 `자료상태·충돌·알림 우선순위와 3-9 누적 적설량 문구의 경계`다.

### 3-8-6 수면환경과 눈의 직접 연결 보완

- 사용자가 기존 수면환경 문구에 눈 관련 내용이 없다고 지적해 수면환경을 `눈과 저온에 따른 침실 냉감`과 `많은 눈에 따른 제설·차량 소음` 두 갈래로 수정했다.
- 취침시간과 눈이 겹치고 낮은 외기온·실내온도 자료가 함께 있으면 `밤사이 눈이 내리고 기온이 내려가면 침실이 평소보다 차갑게 느껴질 수 있어요`와 취침 전 난방조절 행동을 사용하도록 했다.
- 취침시간에 `5cm 이상`이 예상되고 공식 제설계획 또는 도로 인접·과거 소음노출이 확인되면 `밤사이 많은 눈으로 제설차량이나 차량 통행 소리가 들려 잠을 방해받을 수 있어요`와 창문·귀마개 준비행동을 사용하도록 했다.
- 시간당 적설량만으로 침실이 추워지거나 제설차량 소음이 발생한다고 판단하지 않고, 냉감에는 실내외 온도, 소음에는 공식 제설계획 또는 도로 인접·과거 소음기록을 추가로 요구한다.
- 3-8-6은 계속 사용자 미확정 권장안이다.

### 문구 기준 3-8-6 확정 및 3-8-7 권장안

- 사용자가 눈·저온 냉감과 많은 눈·제설/차량 소음을 포함해 수정한 3-8-6을 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 3-8의 마지막 결정항목 3-8-7 `자료상태·충돌·알림 우선순위와 3-9 누적 적설량 문구의 경계` 권장안을 추가했다.
- 기관의 적설없음, 앱 미수신, 품질오류, 이전 발표, 시간대 누락, 제품 미제공을 각각 다른 상태와 문구로 분리하고 어느 결측상태도 0cm·적설없음으로 바꾸지 않도록 했다.
- 변화 없는 공식 적설없음은 표시하지 않고, 이전 양의 적설예보가 같은 시간대 적설없음으로 실제 변경됐을 때만 `마지막으로 확인한 적설예보와는 달리 ...`라고 한 번 안내하도록 했다.
- 최근 한 시간 적설관측과 현재 쌓인 눈의 미수신·품질오류·이전 자료·격자 내 미제공을 분리하고, 다른 격자 관측값이나 예보합계로 현재 위치의 실제 적설을 채우지 않도록 했다.
- PTY 눈·SNO 적설없음, PTY 없음·SNO 양수, 앱 현재 적설판단·공식 적설없음, 이전·최신 예보 차이를 각각 두 문장 이상의 비교형식으로 정리했다.
- 예보·관측 차이는 3-8-4의 0.5cm 유사 허용차를 재사용하고, 이전·최신 예보는 정확한 값끼리만 증감량을 표시하며 범위변화에는 `범위가 높아졌어요·적은 범위로 바뀌었어요`를 사용하도록 했다.
- 알림 우선순위를 P0 공식 대피·시설물 안전문자·전면통제, P1 교통사고 안전문자·대설경보·블랙아이스 관측, P2 5cm 이상과 활동중첩, P3 3~5cm와 행동마감, P4 사실·체감·비교, P5 눈 뒤 생활영향, 자료상태로 정했다.
- 단계상승·행동마감 앞당김·강수형태 변화·새 공식경보·눈 뒤 새 행동은 다시 알리고, 같은 단계의 수치변화·0.5cm 이내 관측일치·예상된 시작·변화 없는 적설없음은 카드만 갱신하도록 했다.
- 3-8은 정시 한 시간 SNO·최근 한 시간 관측·쌓이는 속도를, 3-9는 겹치지 않는 여러 시간 범위합계·기관 제공 3/6/24시간 관측·누적영향을 담당하도록 분리했다.
- 현재 서버·앱은 적설범위와 자료상태를 축약하고 시간당·누적·현재 전체 적설과 공식위험을 단일 `HEAVY_SNOW/폭설 주의`로 혼합하며 의미기반 알림키가 없어 이번 권장안을 구현하지 못한다.
- 3-8-7은 사용자 미확정 권장안이다. 확정되면 3-8 전체를 완료하고 3-9 누적 적설량 문구의 첫 세부항목으로 진행한다.

### 문구 기준 3-8-7 확정 및 3-9-1 권장안

- 사용자가 3-8-7 `자료상태·충돌·알림 우선순위와 3-9 누적 적설량 문구의 경계`를 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 3-8의 일곱 세부항목을 모두 완료하고 상위 제목도 `채택 3-8. 시간당 적설량 문구`로 변경했다.
- 다음 항목 3-9 `누적 적설량 문구`를 일곱 세부항목으로 나누고, 첫 결정항목 3-9-1 `누적 적설 관련 네 값의 사용자 명칭과 문장 역할` 권장안을 추가했다.
- `누적 적설량`은 내부 분류명으로만 사용하고 사용자 화면에서는 `현재 쌓인 눈`, `최근 3/24시간 동안 쌓인 눈`, `앞으로 6시간/오늘 밤 동안 쌓일 눈`, `기상청 예상 적설`로 역할과 시간창을 드러내도록 했다.
- 현재 쌓인 눈과 최근 일정 시간 관측은 `관측됐어요`, 기상청 통보문은 `예보했어요`, 앱이 시간별 정량예보를 합산한 미래 누적은 `쌓일 수 있어요`로 분리했다.
- 사용자 문구에는 `신적설`을 쓰지 않고 제목에서 뜻이 드러나므로 본문에 `새로`를 반복하지 않도록 했다.
- 현재 쌓인 눈·최근 일정 시간 동안 쌓인 눈·앞으로 쌓일 눈·지역 예상 적설은 녹음·다져짐·제설, 시간창, 공간범위, 산출법이 달라 서로 바꾸거나 더하거나 평균내지 않도록 했다.
- 3-9-1은 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-9-2 `예상 누적 범위의 합산·미만·이상·누락 문구`다.

### 문구 기준 3-9-1 확정 및 3-9-2 권장안

- 사용자가 3-9-1 `누적 적설 관련 네 값의 사용자 명칭과 문장 역할`을 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-9-2 `예상 누적 범위의 합산·미만·이상·누락 문구` 권장안을 추가했다.
- 같은 발표본의 겹치지 않는 한 시간 정량예보가 전체 시간대에 모두 있을 때만 예상 누적량을 계산하고, 다른 발표본·관측값·현재 쌓인 눈·지역 통보문을 섞지 않도록 했다.
- 정확한 합계는 `가량`, 상한만 있는 값은 `미만`, 양쪽 경계는 `~`, 열린 상한은 `이상`으로 표시하고, `0.5cm 미만 + 1cm`는 `1cm 이상 1.5cm 미만`, `5cm 이상 + 1.2cm`는 `6.2cm 이상`으로 보존했다.
- 앱이 시간별 예보를 합산한 결과에는 `기상청은`을 붙이지 않고 `쌓일 수 있어요`로 표현하며, 공식 통보문이 기간합계를 직접 발표한 경우와 구분했다.
- 일부 시간 누락·전체 미수신·품질오류·최신 발표 일부 누락·숫자 없는 정성예보를 구분하고 어느 경우에도 누락을 0으로 채우거나 부분합을 전체 누적량처럼 표시하지 않도록 했다.
- 일반 사용자 문구에는 `상한이 열려 있어요` 대신 상세에서 `가장 많이 쌓일 양은 이번 예보에서 확인할 수 없어요`를 사용하도록 했다.
- 3-9-2는 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-9-3 `관측 누적·현재 쌓인 눈·예상 누적의 비교문구`다.

### 문구 기준 3-9 누적 예상문구의 `모두` 제거

- 사용자가 누적 적설 문장의 `모두`는 제외해도 된다고 판단해 3-8-7의 경계 예시와 3-9-1·3-9-2의 모든 사용자 예시에서 `눈이 모두 ○cm 쌓일 수 있어요`를 `눈이 ○cm 쌓일 수 있어요`로 수정했다.
- 시간범위와 합산된 수치가 이미 누적 의미를 전달하므로 문장 의미와 계산규칙은 달라지지 않는다.
- 3-9-2는 계속 사용자 미확정 권장안이다.

### 문구 기준 3-9-2 확정 및 3-9-3 권장안

- 사용자가 `모두`를 제거한 3-9-2 `예상 누적 범위의 합산·미만·이상·누락 문구`를 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-9-3 `관측 누적·현재 쌓인 눈·예상 누적의 비교문구` 권장안을 추가했다.
- 예상 누적과 관측 누적은 시작·종료시각, 공간대표성, 시간창 의미, 단위, 자료품질이 같고 예상량이 기간 시작 전에 완전한 정량자료로 계산된 경우에만 비교하도록 했다.
- 관측사실을 먼저 완성한 뒤 비교문장을 붙이며, 정확한 값은 0.5cm 이하, 범위값은 범위 내부 또는 가장 가까운 경계와 0.5cm 이하일 때 유사하게 관측됐다고 표시하도록 했다.
- 0.5cm를 초과하면 예상시간·예상값 또는 상하한·관측된 양의 차이를 모두 명시하고, 미만·이상의 제시되지 않은 경계를 만들지 않도록 했다.
- 현재 쌓인 눈은 같은 관측지점의 이전 현재값과만 비교해 `○cm 많아요·적어요·같아요`로 표시하고, 그 차이를 최근 강설량이나 녹은 양으로 해석하지 않도록 했다.
- 현재 쌓인 눈과 앞으로 쌓일 눈, 앱 격자별 예상 누적과 기상청 통보문의 지역 예상 적설은 각각 나란히 표시하되 합산·평균·수치차이 비교를 금지했다.
- 관측이 예상과 유사하거나 수치차이가 행동단계를 바꾸지 않으면 카드만 갱신하고, 실제 관측으로 누적 영향과 직접행동이 달라진 경우에만 새 대표알림을 허용했다.
- 3-9-3은 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-9-4 `누적량별 체감·영향 기준과 기준별 체감표현 3종`이다.

### 문구 기준 3-9-3 비교문구 간결화

- 사용자가 관측문장에 최근 3시간이 이미 명시되므로 뒤 비교문장의 `오후 3~6시`를 제거하고 `예상량 ○cm와 유사하게 관측됐어요`, `예상량 ○cm보다 관측된 양이 ○cm 많아요`로 수정했다.
- 범위 밖 관측은 `예상범위 상한·하한`을 직접 말하지 않고 `예상범위보다 관측된 양이 ○cm 많아요·적어요`로 수정했다. 차이는 내부적으로 가장 가까운 범위경계에서 계산한다.
- 현재 쌓인 눈의 이전 관측 비교는 `오후 3시 관측값 2.1cm보다`를 `오후 3시에 관측된 2.1cm보다`로 수정하고 감소·동일 문장에도 같은 구조를 적용했다.
- 3-9-3은 계속 사용자 미확정 권장안이다.

### 문구 기준 3-9-3 확정 및 3-9-4 권장안

- 사용자가 반복시간과 `상한·하한`을 제거한 3-9-3 비교문구를 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-9-4 `누적량별 체감·영향 기준과 기준별 체감표현 3종` 권장안을 추가했다.
- 2026년 8월 기준 기상청 대설특보 24시간 5·20cm, 도로교통법 시행규칙의 실제 도로 적설 20mm 전후 감속, 대설 재난문자 관측조건, 기상청 정책연구의 현재 적설 10·15·20cm와 빠른 적설 복합조건, 서울연구원의 도로 복합판단 필요성을 재확인했다.
- 국내 자료에서 누적 적설량별 보편적인 사람 체감 임계값은 확인되지 않아 `0.1~0.5·0.5~1.5·1.5~3·3~5·5~10·10cm 이상` 여섯 구간을 안전단계가 아닌 앱 편집용 체감단계로 제안했다.
- 각 체감단계에 `쌓일 수 있어요·느낌이 들 수 있어요·느낄 수도 있어요`를 자연스럽게 섞은 생활 체감표현 3종을 마련하고, `새로·모두`는 사용하지 않았다.
- 예상범위가 체감경계에 걸치면 하한단계를 사용하고 범위를 함께 표시하며, 열린 상한으로 확인되지 않은 최대단계 문구나 더 강한 행동을 만들지 않도록 했다.
- 누적량만으로 도로이동·미끄러짐·시설물손상·차량고립·대설단계를 만들지 않고 실제 도로상태, 공식 특보·재난문자, 현재 적설+적설속도+취약시설 등 추가조건을 요구했다.
- 공식·직접행동·내부영향·체감·예보/관측 순으로 노출하고, 체감단계 변화만으로 새 푸시를 보내지 않도록 했다.
- 3-9-4는 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-9-5 `누적 적설과 공식 대설특보·지역 예상 적설·안전정보 연결`이다.

### 전체 문구의 감각어미와 사건 가능성형 구분 수정

- 사용자가 `느껴질 수 있어요·느낄 수도 있어요`는 실제 의견·생각·감각에만 사용하고, 관찰 가능한 사건은 해당 동작의 `~할 수 있어요`로 쓰도록 공통 원칙을 수정했다.
- 공통 문구계약에 `눈이 쌓임·옷이 젖음·땀이 마름·발이 눈에 들어감` 같은 사건·상태변화는 `쌓일 수 있어요·젖을 수 있어요·마르지 않을 수 있어요·들어갈 수 있어요`로 쓰고, 온열감·냉감·시림·피부감·시각적 인상 같은 주관적 감각에만 감각어미를 사용한다고 명시했다.
- 기존 반려견·보호자의 `더위에 부담을 느낄 수 있어요`를 `더위가 …에게 부담이 될 수 있어요`로 모두 수정했다.
- 땀 건조 문구를 `땀이 잘 마르지 않을 수 있어요`, `평소보다 천천히 마를 수 있어요`, `피부에 오래 남아 있을 수 있어요`로 수정했다.
- 채택된 3-8 적설 체감문구에서 `쌓였다고 느낄 수 있어요·덮인 느낌이 들 수 있어요`를 제거하고 `쌓일 수 있어요·덮일 수 있어요·눈에 띌 수 있어요`처럼 실제 적설현상의 가능성으로 바꿨다.
- 미확정 3-9-4의 6단계 문구도 적설·바닥덮임·발 빠짐·보행부담은 동작 자체의 가능성형으로 바꾸고, `바닥의 색이 달라졌다고 느낄 수도 있어요`, `쌓인 눈의 두께를 느낄 수도 있어요`처럼 실제 시각·촉각 인상만 감각어미로 남겼다.
- 3-9-4는 계속 사용자 미확정 권장안이다.

### 문구 기준 3-9-4 확정 및 3-9-5 권장안

- 사용자가 감각어미를 실제 감각에만 사용하고 적설·발 빠짐·보행부담 같은 사건에는 해당 동작의 가능성형을 적용한 3-9-4를 확정했으며 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-9-5 `누적 적설과 공식 대설특보·지역 예상 적설·안전정보 연결` 권장안을 추가했다.
- 앱 예상누적, 기상청 지역 예상 적설, 대설 발생가능성, 예비특보, 주의보·경보 발표/발효/변경/해제, 대설 재난문자, 통제·대피 안전정보를 서로 다른 역할로 분리했다.
- 실제 수신된 공식정보만 `알렸어요·예보했어요·발표했어요·발효 중이에요·발송했어요`로 확정하고, 앱 누적량 5·20cm만으로 주의보·경보·재난문자를 생성하지 않도록 했다.
- 지역 통보문의 기간·지역·`많은 곳` 조건을 보존하고 앱 격자 예상량과 나란히 표시하되 차이계산·평균·대표값 통합을 금지했다.
- 발생가능성·예비특보·주의보·경보·교통사고 대응 문자·시설물 붕괴 대응 문자·공식 무거운 눈 정보에 대해 이유가 포함된 직접행동을 먼저 보여주는 예시를 마련했다.
- 변화 없는 공식 특보 없음은 표시하지 않고 공식 해제, 특보 미수신, 품질오류, 이전 자료, 지역 통보문 미수신을 서로 다른 자료상태로 구분했다.
- 공식 대피/시설문자/전면통제, 교통문자/경보, 주의보, 예비특보/발생가능성, 사실·체감 순의 우선순위를 두고 같은 눈 상황에서는 한 개의 대표알림만 보내도록 했다.
- 3-9-5는 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-9-6 `여덟 생활항목의 영향·직접행동 연결`이다.

### 문구 기준 3-9-5 확정 및 3-9-6 권장안

- 사용자가 3-9-5 `누적 적설과 공식 대설특보·지역 예상 적설·안전정보 연결`을 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-9-6 `여덟 생활항목의 영향·직접행동 연결` 권장안을 추가했다.
- 누적 적설은 여러 시간의 강설지속, 활동시간까지의 예상누적, 눈이 그친 뒤 남은 적설면을 생활항목에 연결하되 누적량 하나로 여덟 항목을 모두 만들지 않도록 했다.
- 강풍·블랙아이스(도로살얼음)·자외선·비와 우산 준비·빨래 회수·반려견 산책계획·출퇴근 경로·수면환경 각각에 생성조건, 이유가 포함된 직접행동, 내부 영향 가능성, 공식 사실·상세와 금지조건을 마련했다.
- 강풍에는 남은 건조 적설면과 풍속, 블랙아이스에는 같은 도로의 수분·노면온도, 자외선에는 남은 적설면·공식 자외선지수, 수면환경에는 실내외 온도 또는 제설계획·소음노출을 추가로 요구했다.
- 비와 우산은 실제 외출시간 강설, 빨래는 눈 시작 전 안전한 회수시간, 반려견은 개체·노면·제설제·더 나은 대체시간, 출퇴근은 실제 경로·통제·교통·운행정보가 있어야 생성하도록 했다.
- 실제로 더 적합한 시간·경로가 있을 때만 산책·이동 변경을 제안하고, 없으면 도로통제·대중교통 정보확인이나 산책 후 발·털 세척으로 바꾸도록 했다.
- 직접행동을 내부 영향·공식 사실보다 먼저 표시하고, 적설·발 빠짐·보행부담·수면방해 같은 실제 사건은 동작 자체의 가능성형으로, 침실 냉감 같은 실제 주관적 감각만 감각어미로 표시했다.
- 대표행동은 공식 긴급도와 실제 행동마감을 우선하며, 같은 단계 수치변화는 카드만 갱신하고 공식 강화·마감변경·새 대체안·눈 뒤 파생상태가 생길 때만 새 푸시를 허용했다.
- 3-9-6은 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-9-7 `자료상태·충돌·알림 우선순위와 3-10 대설·폭설 문구의 경계`다.

### 문구 기준 3-9-6 확정 및 3-9-7 권장안

- 사용자가 3-9-6 `여덟 생활항목의 영향·직접행동 연결`을 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 3-9의 마지막 결정항목 3-9-7 `자료상태·충돌·알림 우선순위와 3-10 대설·폭설 문구의 경계` 권장안을 추가했다.
- 앱 예상누적, 관측누적, 현재 쌓인 눈, 기상청 지역 예상 적설·특보에 대해 공식 0, 변화 없는 없음, 미수신, 품질오류, 이전 자료, 일부 시간 누락, 정성자료를 서로 다른 상태와 문구로 분리했다.
- 양의 예상량과 적설없음 간 실제 변경만 없음·재시작 문구로 알리고, 미수신·누락·오류는 어느 경우에도 0cm나 특보 없음으로 바꾸지 않도록 했다.
- 앱 예상누적과 지역 예상 적설은 시간·공간범위가 다르면 나란히 표시하고, 같은 범위에서 양수와 적설없음이 충돌할 때만 두 사실과 `앱의 예상 적설판단과 기상청 지역예보가 달라요`를 표시하도록 했다.
- 최근 관측누적과 현재 쌓인 눈은 서로 다른 값이므로 한쪽이 0이고 다른 쪽이 양수여도 모순으로 보지 않고, 녹음·다져짐·제설 또는 이전 적설 잔존 가능성을 별도 내부 설명으로 표시했다.
- 이전·최신 예상누적은 정확한 값끼리만 증감량을 표시하고, 범위는 `예상범위가 높아졌어요·낮아졌어요` 또는 두 범위를 그대로 나란히 표시하도록 했다.
- 공식 대피/시설문자/전면통제, 교통문자/경보/통제, 주의보/취약시설, 예비특보/행동마감, 사실·체감 순의 우선순위와 새 푸시·카드갱신 조건을 마련했다.
- 3-9는 누적 적설의 값·계산·비교·체감·생활연결을, 3-10은 공식 대설 단계와 취약시설 적설하중 대응을 담당하도록 경계를 정하고, 앱 누적량 5·20cm만으로 `대설주의보 수준·대설경보 가능성·폭설 단계`를 만들지 않도록 했다.
- 3-9-7은 사용자 미확정 권장안이다. 확정되면 3-9 전체를 완료하고 3-10 대설·폭설 문구의 첫 세부항목으로 진행한다.

### 문구 기준 3-9-7 자료상태·지역범위 문구 수정

- 사용자가 양의 적설예보에서 적설없음으로 실제 변경된 경우의 문구를 `마지막예보와는 달리 오늘 밤에는 쌓일 눈이 없는 것으로 예보됐어요`로 확정 후보에 반영했다.
- 일부 시간대 누락은 `일부 시간대 자료가 없어 오후 5~11시 전체 적설량을 계산하기 어려워요`, 이전 자료는 `마지막으로 확인한 적설예보는 오전 11시 발표자료예요 · 이후 예보에서 달라졌을 수 있어요`로 수정했다.
- 앱 예상과 기상청 지역예보의 `대상 범위가 다름`을 사용자 충돌 유형으로 표시하지 않는다. 앱 예상과 공식예보는 모두 사용자 지역에 실제로 적용되는 자료만 선택하고, 포함되지 않는 지역예보는 노출하지 않는다.
- 기상청이 넓은 공식 구역으로 발표한 자료를 사용할 때는 `수원이 포함된 경기남부`처럼 사용자 지역의 포함관계를 밝힌다. `많은 곳` 세부지역에 사용자 지역이 포함되지 않거나 포함 여부를 확인할 수 없으면 해당 수치와 조건은 문장에 넣지 않는다.
- 같은 사용자 지역에서 앱 예상과 공식예보가 다르면 `오늘 밤에는 눈이 4~7cm 쌓일 수 있다고 예상되나, 기상청은 수원에 쌓일 눈이 없는 것으로 예보했어요`와 `앱의 예상 적설판단과 기상청 지역예보가 달라요`를 표시한다.
- 최근 3시간 동안 2cm가 쌓였지만 현재 쌓인 눈은 없는 경우에는 두 관측사실을 차례로 표시한 뒤 `그동안 눈이 녹거나 다져지거나 치워졌을 수 있어요`를 내부 설명으로 사용한다.
- 3-9-7은 아직 사용자 미확정 권장안이다.

### 문구 기준 3-9-7 확정 및 3-10-1 권장안

- 사용자가 수정된 3-9-7 `자료상태·충돌·알림 우선순위와 3-10 대설·폭설 문구의 경계`를 확정했으며 3-9 전체와 3-9-7의 제목·상태를 채택으로 변경했다.
- 다음 항목 3-10 `대설·폭설 문구`를 시작하고 일곱 세부항목의 결정순서를 추가했다.
- 첫 결정항목 3-10-1은 공식 `대설` 명칭, `폭설` 사용범위와 앱 내부 상태명을 정한다.
- 2026년 6월 30일 시행 기상법 시행령 별표 1을 재확인해 공식 특보명과 대설주의보 24시간 5cm, 대설경보 20cm·산지 30cm 기준을 기록했다. 기준 수치만으로 앱이 공식 특보 또는 `대설 수준`을 생성하지 않도록 했다.
- 현재 서버의 `한 시간 1cm 이상 또는 최근 3시간 3cm 이상 → HEAVY_SNOW 심각도 95 → HEAVY_SNOW_CAUTION → 폭설 주의` 연결과 앱·설정화면의 같은 명칭을 현재 문제로 명시했다.
- 설정 토글은 `눈 대비 알림`으로 바꾸고 내부 추천에는 고정된 `폭설 주의` 단계명 대신 `출발 전 교통정보 확인·취약시설 사전점검`처럼 실제 대표행동을 표시하는 안을 제시했다.
- `대설주의보·대설경보`는 실제 공식 발표·발효 때만 사용하고, 기상청 지역예보는 공식 사실, 앱 예상누적과 내부 생활·취약시설 영향은 가능성으로 분리했다.
- `폭설`은 사용자 지역에 적용되는 공식 원문이 실제로 사용한 경우에만 출처와 함께 전달하고 `폭설주의보·폭설경보` 또는 내부 단계명으로 만들지 않도록 했다.
- 첫 노출은 직접행동을 공식 사실·예보·앱 예상보다 먼저 표시하도록 했다.
- 3-10-1은 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-10-2 `발생가능성·예비특보·주의보·경보의 발표·발효·변경·해제 문구`다.

### 문구 기준 3-10-1 확정 및 3-10-2 권장안

- 사용자가 3-10-1 `공식 대설 명칭, 폭설 사용범위와 앱 내부 상태명`을 확정했으며 문구 기준 문서의 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-10-2 `발생가능성·예비특보·주의보·경보의 발표·발효·변경·해제 문구` 권장안을 추가했다.
- 대설 발생가능성 정보는 `발생 가능성이 있다고 알렸어요`, 예비특보는 `대설특보 발표가 예상된다고 알렸어요`, 실제 특보는 `발표했어요·발효될 예정이에요·발효 중이에요`로 역할을 분리했다.
- 발표시각과 발효시각을 별도로 표시하고 발효시각이 지났어도 최신 공식상태를 확인하지 못하면 앱이 자동으로 `발효 중`을 만들지 않도록 했다.
- 주의보→경보와 경보→주의보는 이전·새 단계를 함께 밝히며, 하향변경을 `안전·피해종료`로 확대하지 않도록 했다.
- 공식 해제예고는 예상사실, 실제 해제는 확정사실로 분리하고 해제예고 시점 도달이나 눈이 그친 사실만으로 앱이 해제를 생성하지 않도록 했다.
- 변화 없는 공식 특보 없음은 표시하지 않고, 이전 발효상태에서 완전한 공식 전체조회가 명시적 없음으로 달라졌을 때만 변화문구를 허용했다. 실제 해제통보가 있으면 해제문구를 우선한다.
- 특보 미수신·품질오류·이전 자료·최신조회 실패와 마지막 발효상태를 구분하고 어느 경우에도 특보 없음·현재 발효 중으로 자동 변환하지 않도록 했다.
- 같은 사건의 발표 뒤 예정된 발효시각 도달만으로 직접행동이 달라지지 않으면 중복 푸시 없이 카드만 갱신하고, 신규 단계·공식 변경·실제 해제를 새 알림 후보로 두었다.
- 구현에는 공식제품·단계·사건유형·발표/발효/해제/해제예고 시각·공식구역·통보문 관계·요청상태를 별도로 저장하도록 했다.
- 3-10-2는 사용자 미확정 권장안이다. 확정 후 다음 항목은 3-10-3 `대설 안전안내문자와 공식 즉시행동 문구`다.

### 기상특보 사전단계 비노출 원칙 반영

- 사용자가 특보의 `발생가능성·예비특보·발효 예정`은 알리지 않고 실제 실행된 뒤에만 알리도록 정책을 변경했다.
- 이 원칙을 대설뿐 아니라 강풍·호우·폭염·한파 등 기상특보 공통 lifecycle에 적용했다.
- 발생가능성, 예비특보, 발표됐지만 아직 발효되지 않은 특보, 미래 단계·구역·발효시각 변경, 해제예고는 내부 저장·공식 재조회에만 사용하고 화면·푸시·공식상태 배지를 만들지 않는다.
- 사용자가 사전 알림을 원하더라도 발효 전 공식 특보 알림은 보내지 않으며, 발효 예정시각이 지나도 최신 공식자료에서 실제 발효를 확인하기 전에는 앱이 자동 발효하지 않는다.
- 사용자에게는 실제 발효가 확인된 주의보·경보, 새 단계가 실제 발효된 뒤의 변경, 실제 공식 해제, 실제 발송된 안전안내·재난문자만 표시한다. 해제예고는 실제 해제가 아니므로 숨긴다.
- 강수·기온·적설 등 일반 기상예보와 그에 근거한 우산 준비·빨래 회수·산책·이동 같은 생활행동은 계속 표시하되, 공식 특보의 사전단계를 행동 이유로 인용하지 않는다.
- 공통 lifecycle 표의 미래 발효시각 변경과 발효 전 재알림 예외를 제거하고, 폭염·한파·호우·대설 관련 설명·예시·검증조건을 같은 정책으로 정리했다.
- 3-10-2는 이 수정안을 반영한 미확정 권장안이다. 사용자가 확정하면 다음은 3-10-3 `대설 안전안내문자와 공식 즉시행동 문구`다.

### 문구 기준 3-10-2 확정 및 3-10-3 권장안

- 사용자가 발생가능성·예비특보·발효 전 발표·미래 변경·해제예고를 사용자에게 표시하지 않는 3-10-2 수정안을 확정했으며 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-10-3 `대설 안전안내문자와 공식 즉시행동 문구` 권장안을 추가했다.
- 기상청 공식자료에서 `대설 재난문자`와 휴대전화 전달유형 `대설 안전안내문자(CBS)`가 함께 쓰이는 점을 반영해 사용자 명칭은 `대설 안전안내문자`, 상세 출처는 `기상청 대설 재난문자 · 안전안내문자`로 제안했다.
- 실제 발송사건·문자종류·대상 시군구와 사용자 지역의 일치·발송기관/시각/식별자·최신 정정관계가 확인된 경우에만 화면·푸시를 만들고, 예보·앱 적설량·특보 발효만으로 문자를 생성하지 않도록 했다.
- 교통사고 대비 실제 문자에는 운전 중 감속·안전거리·급조작 회피를, 시설물 붕괴 대비 실제 문자에는 위험 시설 접근금지·위험징후 시 이탈과 신고를 행동 먼저 표시하도록 했다.
- 관측수치는 실제 문자 원문이나 같은 지역·시간의 공식 관측자료에서 확인된 경우에만 붙이고 메시지 종류만으로 종전 5cm/h 또는 20cm+3cm/h 기준을 역산하지 않도록 했다.
- 2026년 12월 전국 확대와 지역별 발송기준 차등 적용은 현재 계획이므로 시행 전 사용자에게 알리지 않고, 실제 서비스지역·기준버전·발송자료를 따르도록 했다.
- 같은 문자 재수신은 중복푸시 없이 갱신하고 실제 정정·취소문자만 확정 표시하며, 미수신·이전 자료·다른 대상지역·원문 미수신을 서로 다른 자료상태로 처리했다.
- 3-10-3은 사용자 미확정 권장안이다. 확정 후 다음은 3-10-4 `연구기반 취약시설 사전점검·접근제한·대피 가능성 문구`다.

### 문구 기준 3-10-3 확정 및 3-10-4 권장안

- 사용자가 실제 발송된 대설 안전안내문자와 공식 즉시행동을 구분한 3-10-3을 확정했으며 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-10-4 `연구기반 취약시설 안전확인·접근금지·이탈 문구` 권장안을 추가했다.
- 기상청 정책연구의 2014~2025년 구조물 피해 778건 분석과 `현재 쌓인 눈 10·15·20cm + 최근 1시간 3cm 또는 3시간 5cm` 복합조건을 구조물 적설하중 내부판단에만 사용했다. 기본조건의 피해사례 포착이 59.64%이므로 미충족을 안전으로 판정하지 않도록 했다.
- `10cm 이상`은 안전한 위치에서 시설 변형 확인, `15cm 이상`은 노후지붕·비닐하우스 접근금지, `20cm 이상`은 취약시설 안이나 가까이에 있을 때 즉시 이탈로 연결했다. 이 단계명과 수치는 첫 화면에 표시하지 않고 상세에 `연구기반 앱 분석`으로 둔다.
- 피해는 `손상될 수 있어요·변형되거나 무너질 수 있어요·무너질 위험이 있어요`의 가능성형으로만 표현하고, 공식 특보·대피령·붕괴발생으로 바꾸지 않도록 했다.
- 공식 `무거운 눈` 정보, 등록된 취약시설, 눈 시작 전 안전한 확인시간이 함께 있을 때만 사전 보강상태 확인을 허용하고, 눈이 이미 빠르게 쌓이거나 어둡거나 위험징후가 있으면 접근금지·이탈로 바꾸도록 했다.
- 기울어짐·갈라짐·이상음·지붕처짐·기둥변형은 적설수치보다 우선해 즉시 이탈·신고를 표시하고, 지붕에 올라가거나 밤에 혼자 제설하도록 권하지 않는다.
- 관측지점이 시설위치를 대표하지 못하거나 현재/최근 적설 중 하나가 누락되거나 시설 관련성이 없으면 개인화된 단계판정과 푸시를 만들지 않는다.
- 수치·근거 문서에 남아 있던 호우·강풍·열대야의 발생가능성·예비특보·발효 예정 사용자 예시도 제거하고 실제 발효 확인 뒤에만 특보를 노출하는 공통정책으로 정리했다.
- 3-10-4는 사용자 미확정 권장안이다. 확정 후 다음은 3-10-5 `공식 단계·내부 영향별 직접행동과 첫 노출순서`다.

### 문구 기준 3-10-4 취약시설 단계 문구 수정

- 사용자가 10·15·20cm 복합조건의 직접행동과 내부 피해 가능성을 더 간결한 시설 중심 표현으로 바꾸도록 요청했다.
- `낙후된 시설·건축물`은 시설의 구조적 노후를 정확히 뜻하지 않고 공식 행동요령도 `노후 시설`을 사용하므로 `노후 시설·노후 건축물·노후 건물`로 정리했다.
- `부셔질 수 있어요`는 표준어인 `부서질 수 있어요`로 반영했다.
- 10cm 단계는 이미 눈이 빠르게 쌓이는 관측조건이므로 시설로 접근하도록 오해하지 않게 `안전한 위치에서 노후 시설의 상태를 확인하세요`로 유지했다.
- 10cm 내부 영향은 모호한 `영향을 받을 수 있어요` 대신 `노후 시설이 손상될 수 있어요`, 15cm는 `노후 건축물 일부가 부서질 수 있어요`, 20cm는 `노후 건물이 무너질 위험이 있어요`로 수정했다.
- 3-10-4는 계속 사용자 미확정 권장안이다.

### 취약시설 표현 `노후된`으로 통일

- 사용자가 취약시설 관련 표현을 `노후 시설·노후 건축물·노후 건물`이 아니라 `노후된 시설·노후된 건축물·노후된 건물`로 모두 바꾸도록 요청했다.
- 3-10-4의 10·15·20cm 직접행동과 내부 피해 가능성 문구를 모두 `노후된` 형태로 수정했다.
- 문구 기준 문서의 앞선 대설 안전안내문자·눈 무게·취약시설 예시와 수치·근거 문서의 관련 예시도 `노후된 지붕·노후된 축사·노후된 시설물`로 일관되게 변경했다.
- 자료 신선도를 뜻하는 `노후화`, 시설특성 필드인 `노후도`처럼 다른 의미의 용어는 변경하지 않았다.
- 3-10-4는 계속 사용자 미확정 권장안이다.

### 문구 기준 3-10-4 확정 및 3-10-5 권장안

- 사용자가 `노후된 시설·노후된 건축물·노후된 건물` 표현으로 수정된 3-10-4를 확정했으며 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-10-5 `공식 상태·내부 영향별 직접행동과 첫 노출순서` 권장안을 추가했다.
- 문장역할을 직접행동, 보조행동, 내부 영향 가능성, 실행된 공식 사실, 예보·관측 근거, 자료상태로 분리하고 직접행동은 이유를 먼저 밝힌 명령형, 내부 영향은 가능성형, 실제 공식 시행사실은 확정형으로 고정했다.
- 실제 발효된 대설주의보·경보, 실제 발송된 교통사고/시설물 붕괴 대비 대설 안전안내문자, 실제 도로통제·운휴·대피명령별 직접행동과 공식 사실을 마련했다. 발생가능성·예비특보·발효 전 발표·발효 예정·해제예고는 사용자 상태에서 제외했다.
- 내부 영향은 더 나은 이동시간이 실제 확인된 경우의 이동완료, 대체시간이 없을 때의 통제·대중교통 확인, 3-10-4의 노후된 시설 안전확인·접근금지·즉시 이탈, 위험징후 이탈·신고로 연결했다.
- 첫 노출을 `직접행동 1개 → 필요한 보조행동 최대 1개 → 내부 영향 가능성 1개 → 실행된 공식 사실 → 예보·관측·출처`로 정하고, 공식 대피·전면통제·안전안내문자의 원문 즉시행동은 맨 앞에 두도록 했다.
- 특정 대체시간·우회경로는 실제 이용 가능성, 상대적으로 나은 적설·노면·통제·운행상태, 남은 행동마감, 새로운 위험구역 회피, 비교 가능한 자료가 모두 확인될 때만 제안하도록 했다.
- 공식 발효·발송·통제·대피, 직접행동 강화, 새 대체안·마감, 새 시설 위험징후가 생길 때만 새 푸시를 허용하고 같은 행동 안의 수치·체감 변화는 카드만 갱신하도록 했다.
- 3-10-5는 사용자 미확정 권장안이다. 확정 후 다음은 3-10-6 `여덟 생활항목의 영향·직접행동 연결`이다.

### 문구 기준 3-10-5 확정 및 3-10-6 권장안

- 사용자가 3-10-5 `공식 상태·내부 영향별 직접행동과 첫 노출순서`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-10-6 `여덟 생활항목의 대설 영향·직접행동 연결` 권장안을 추가했다.
- 대설 예보·내부 대설영향·실제 발효특보가 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경에 연결되는 조건과 대표 직접행동·내부 영향 가능성문구를 정리했다.
- 대설경보·안전안내문자·통제·대피가 실제 시행된 경우 일반 우산·빨래·산책 등 낮은 생활행동을 숨기고 해당 공식 즉시행동을 먼저 표시하도록 했다. 발생가능성·예비특보·발효 전 발표·발효 예정·해제예고는 제외했다.
- 눈이 이미 시작됐거나 실외위험이 커진 뒤에는 빨래 회수 등 새 실외행동을 권하지 않고, 산책 대체시간과 우회경로는 실제로 더 나은 대안이 확인될 때만 제안하도록 했다.
- 대표행동은 실제 대피·안전안내·전면통제부터 행동마감과 긴급도 순으로 하나만 푸시에 표시하고, 나머지는 상세카드에 보존하도록 했다.
- 수면환경에는 눈·외기온·실내온도를 함께 확인한 난방행동과 실제 제설작업·소음노출을 확인한 소음대비를 연결했으며, 주관적 냉감문구 3종을 추가했다.
- 3-10-6은 사용자 미확정 권장안이다. 확정 후 다음은 3-10-7 `자료상태·충돌·알림 우선순위와 3-11 블랙아이스(도로살얼음) 문구의 경계`다.

### 3-10-6 블랙아이스 직접행동 표현 수정

- 사용자가 3-10-6 여덟 생활항목 표의 대표 직접행동을 검토하고 블랙아이스(도로살얼음) 문구를 `눈이 밤사이 얼어 얼음이 생길 수 있으니, 출근 전에 도로 결빙정보를 확인하세요`로 수정했다.
- 3-10-6 항목별 대표문구 표와 같은 절의 첫 노출 예시에 동일한 문장을 반영했다.
- 다른 일곱 생활항목의 대표 직접행동은 사용자가 제시한 표대로 유지했다.
- 3-10-6은 아직 사용자 미확정 권장안이다.

### 문구 기준 3-10-6 확정 및 3-10-7 권장안

- 사용자가 수정된 여덟 생활항목 대표 직접행동을 포함한 3-10-6을 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-10-7 `자료상태·충돌·알림 우선순위와 3-11 도로 결빙 문구의 경계` 권장안을 추가했다.
- 변화 없는 대설특보 없음·쌓일 눈 없음은 표시하지 않고, 이전 양의 예보에서 적설없음으로 실제 변경됐을 때만 `마지막예보와는 달리...` 문구를 한 번 표시하도록 했다.
- 특보·안전안내문자·통제·적설자료의 미수신, 품질오류, 이전 자료를 공식 없음이나 해제로 바꾸지 않고 각각 확인하기 어려운 대상을 명시하도록 했다.
- 공식 발효·해제와 앱 내부 영향이 함께 있을 때 역할을 분리하고, 특보 없음과 앱 적설판단은 같은 단계가 아니므로 충돌문구를 만들지 않도록 했다.
- 알림 우선순위와 새 푸시/카드 갱신 조건을 정리하고, 공식 결빙관측·통제처럼 현재 경로의 구체적인 행동을 일반 대설 생활준비보다 우선하도록 했다.
- 3-11이 `도로 결빙`, 3-12가 `블랙아이스(도로살얼음)`임을 반영해 기존 다음항목 설명을 바로잡았다. 눈이 그치거나 대설특보가 해제돼도 노면수분·노면온도·공식 결빙관측을 별도로 평가하도록 이관조건을 마련했다.
- 3-10-7은 사용자 미확정 권장안이다. 확정하면 3-10의 일곱 세부항목이 완료되고 다음은 3-11-1 `도로 결빙의 공식 명칭과 앱 내부 상태명`이다.

### 문구 기준 3-10-7 확정 및 3-11-1 권장안

- 사용자가 3-10-7을 확정해 제목과 상태를 채택으로 변경했으며, 3-10 대설·폭설 문구의 일곱 세부항목을 완료했다.
- 새 진행항목 3-11 `도로 결빙 문구`의 일곱 결정순서와 3-11-1 `도로 결빙의 공식 명칭과 앱 내부 상태명` 권장안을 추가했다.
- 화면의 기본 항목명은 `도로 결빙`, 공식 노면센서 사실은 `노면 결빙·노면 서리·눈·얼음 상태`, 앱 계산은 `도로 결빙 가능성`, 도로자료가 없을 때는 `도로 상태 확인 필요·도로 결빙 판단 어려움`으로 분리했다.
- 공식 관측·통제·해제는 구간·방향·시각 범위에서 확정형으로, 앱 내부 결빙조건은 `도로가 얼 수 있어요` 가능성형으로 표시하도록 했다.
- 내부 근거강도가 달라도 사용자 제목은 `도로 결빙 가능성`으로 통일하고 앱이 공식처럼 보이는 `관심·주의·위험·결빙주의보·결빙경보`를 생성하지 않도록 했다.
- 밤사이 눈, 밤사이 비, 녹은 눈·제설수, 원인을 특정할 수 없는 공식 젖음관측별 원인 선행 문구를 마련했으며 수분 원인이 확인되지 않으면 임의로 원인을 붙이지 않도록 했다.
- `빙판길`은 실제 결빙·서리·눈/얼음 관측 또는 공식 빙판길 안내가 있을 때만, `블랙아이스(도로살얼음)`는 3-12의 별도 조건에서만 사용하도록 범위를 분리했다.
- 기존 `ICY_ROAD_RISK`, `COMMUTE_RISK`, `freezeRisk`, 수도관용 `FREEZE_CAUTION`의 혼합 문제와 `OFFICIAL_ROAD_*·ROAD_ICE_FORMATION_*·PIPE_FREEZE_*` 분리안을 문서화했다.
- 3-11-1은 사용자 미확정 권장안이다. 확정 후 다음은 3-11-2 `공식 노면관측·도로통제·해제 문구`다.

### 문구 기준 3-11-1 확정 및 3-11-2 권장안

- 사용자가 3-11-1 `도로 결빙의 공식 명칭과 앱 내부 상태명`을 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-11-2 `공식 노면관측·도로통제·해제 문구` 권장안을 추가했다.
- 공식 결빙·서리·적설·눈/얼음·젖음·마름·노면온도 관측을 구간·방향·시각 범위에서 확정형으로 표시하고, 다른 도로나 블랙아이스(도로살얼음) 관측으로 확대하지 않도록 했다.
- 실제 시행된 전면/방향/차로 통제, 차종제한, 가변속도, 제설제 살포, 제설작업 완료, 통제해제, 통행재개별 직접행동과 공식 사실을 마련했다.
- 통제 예정·제설 예정·해제예고·통행재개 예정은 사용자에게 표시하지 않고 실제 시행상태가 확인된 뒤에만 확정형으로 노출하도록 했다.
- 통제가 없고 공식 결빙관측만 있을 때 운전 중, 출발 전, 보행, 자전거·전동킥보드, 이동수단 미확인별 직접행동과 내부 영향 가능성문구를 분리했다.
- 결빙→젖음/마름, 젖음→결빙, 통제해제, 재통제 변화문구와 새 푸시/카드 갱신 조건을 정했으며 노면상태와 통제상태를 별개의 공식 사실로 유지하도록 했다.
- 3-11-2는 사용자 미확정 권장안이다. 확정 후 다음은 3-11-3 `노면수분·노면온도 기반 내부 가능성문구`다.

### 문구 기준 3-11-2 확정 및 3-11-3 권장안

- 사용자가 3-11-2 `공식 노면관측·도로통제·해제 문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-11-3 `노면수분·노면온도 기반 내부 가능성문구` 권장안을 추가했다.
- 기상청 표준 노면온도 센서 정확도 ±0.8℃ 등 제공기관의 불확도를 포함해 `Tlow·Thigh`를 계산하고, 같은 도로구간의 노면수분과 함께 있을 때만 내부 가능성을 만들도록 했다.
- 수분이 있고 온도 오차범위 전체가 0℃ 이하이면 `ROAD_ICE_FORMATION_CONDITIONS_CLEAR`, 오차범위가 0℃에 걸치면 `ROAD_ICE_FORMATION_POSSIBLE`로 분리하되 사용자 제목은 모두 `도로 결빙 가능성`, 문장은 가능성형으로 통일했다.
- 표준센서 기준 -1.1/-0.8/-0.2/0.8/1.0℃ 경계 예시와 두 내부상태별 문구 3종을 마련했다.
- 밤사이 눈, 비, 녹은 눈, 제설수, 원인 미확인 젖음관측별 원인 선행 문구를 정하고 실제 같은 구간에서 확인되지 않은 수분 원인은 붙이지 않도록 했다.
- 노면자료 없이 실제 기온 0℃ 이하와 최근 실제 비·눈만 있으면 `도로 상태 확인 필요`, 체감온도·강수확률만 있으면 내부상태 없음, 필수자료 누락은 `도로 결빙 판단 어려움`으로 분리했다.
- 시간·구간·방향·사용자 일정 연결, 취약구간·겨울/출근시간의 우선순위 보정, 내부상태 유지·종료 조건과 구현필드를 정리했다.
- 3-11-3은 사용자 미확정 권장안이다. 확정 후 다음은 3-11-4 `운전·보행·자전거·이동보조기기 영향문구`다.

### 3-11-3 결빙 가능성 표현 수정

- 사용자가 오차범위 전체가 0℃ 이하인 경우, 0℃를 걸치는 경우, 표준센서 -1.1/-0.8/-0.2/0.8/1.0℃ 예시와 문구 3종을 수정 제안했다.
- 기본 가능문구를 `오전 6~8시에는 젖은 도로가 얼게 될 가능성이 있어요`로 바꾸고, -0.2℃ 예시와 첫 번째 교대문구를 `노면의 물기가 있다면 얼게 될 가능성이 있어요`로 반영했다.
- -0.8℃ 예시는 `젖은 도로가 얼게 될 가능성이 있어요`, 0.8℃ 예시는 `노면의 물기가 있다면 얼 수도 있어요`로 반영했다.
- 사용자가 제안한 0.8℃의 `적은 확률로`는 센서 정확도 ±0.8℃가 확률분포를 제공하지 않아 가능성의 크기를 계산할 수 없으므로 사용하지 않았고, 이 제한을 본문에 명시했다.
- 3-11-1의 동일 내부상태 기본문구와 3-11-3의 판정표·경계예시·원인 미확인 문구·첫 노출 예시를 함께 맞췄다.
- 3-11-3은 계속 사용자 미확정 권장안이다.

### 3-11-3 0.8℃ 경계 표현 재수정

- 사용자가 0.8℃ 예시를 `노면의 물기가 있다면 적은 확률로 얼 수도 있어요`로 명시해 해당 문구를 그대로 반영했다.
- 앞서 작성한 `적은 확률로` 제외 규칙은 삭제하고, 0.8℃ 경계에서 단계 차이를 전달하는 정성표현으로만 사용하도록 제한했다.
- `적은 확률`을 숫자형 발생확률로 변환하거나 다른 센서 정확도·경계에 자동 적용하지 않는다.
- 3-11-3은 계속 사용자 미확정 권장안이다.

### 문구 기준 3-11-3 확정 및 3-11-4 권장안

- 사용자가 0.8℃의 `적은 확률로` 정성표현까지 반영된 3-11-3을 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-11-4 `운전·보행·자전거·이동보조기기 영향문구` 권장안을 추가했다.
- 공식 결빙관측은 확인된 구간·사용면의 사실만 확정하고 개인 영향은 가능성형, 앱 내부 결빙 가능성은 `도로가 얼면` 조건부 영향, 자료부족은 활동별 영향 미생성으로 분리했다.
- 운전, 보행, 자전거·전동킥보드, 휠체어, 지팡이·목발·보행기별 공식 관측용 영향 3종과 내부 가능성용 조건부 영향 3종을 각각 마련했다.
- 차도·보행로·자전거도로·경사로의 사용면, 구간·방향·시간, 이동수단이 실제 사용자 일정과 일치할 때만 문구를 만들고 차도 관측을 보행로 등으로 확대하지 않도록 했다.
- 결빙사고 통계는 알림 우선순위 근거로만 쓰고 개인 사고확률·확정사고·정확한 제동거리 배수로 바꾸지 않도록 했다.
- 미끄러짐·제동거리 증가·넘어짐·바퀴/보조기기 미끄러짐은 실제 사건 가능성이므로 감각어미 없이 `~할 수 있어요`로 표시하도록 했다.
- 실제 통제·공식 이동지시가 있으면 영향보다 공식 행동을 우선하고, 대체경로는 실제 통행 가능성과 무장애 이용 가능성이 확인될 때만 제안하도록 했다.
- 3-11-4는 사용자 미확정 권장안이다. 확정 후 다음은 3-11-5 `직접행동과 첫 노출순서`다.

### 문구 기준 3-11-4 확정 및 3-11-5 권장안

- 사용자가 3-11-4 `운전·보행·자전거·이동보조기기 영향문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-11-5 `직접행동과 첫 노출순서` 권장안을 추가했다.
- 실제 통제·공식 결빙관측·내부 조건 뚜렷/가능·자료부족별 직접행동 강도를 나누고 운전 중에는 정보검색이 아니라 감속·안전거리·급조작 금지 행동을 먼저 표시하도록 했다.
- 운전, 보행, 자전거·전동킥보드, 휠체어, 지팡이·보행기별 출발 전·이동 중 직접행동과 대체경로/대체교통이 있을 때와 없을 때의 문구를 마련했다.
- 첫 노출을 `직접행동 1개 → 필요한 보조행동 최대 1개 → 내부 영향 1개 → 공식 사실 → 내부판단 → 수치·출처`로 정하고 실제 전면통제·현장지시는 항상 맨 앞에 두도록 했다.
- 특정 시간·일반경로·무장애경로·대체교통은 실제 이용 가능성, 상대적으로 나은 노면상태, 이동수단 적합성을 확인한 경우에만 제안하도록 했다.
- 대표행동은 전면통제·현장지시부터 자료부족 확인행동까지 긴급도와 행동마감 순으로 하나만 고르고, 새 푸시/카드 갱신 조건을 분리했다.
- 3-11-5는 사용자 미확정 권장안이다. 확정 후 다음은 3-11-6 `여덟 생활항목의 영향·직접행동 연결`이다.

### 문구 기준 3-11-5 확정 및 3-11-6 권장안

- 사용자가 3-11-5 `직접행동과 첫 노출순서`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-11-6 `여덟 생활항목의 영향·직접행동 연결` 권장안을 추가했다.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경별 대표 직접행동·내부 영향과 생성조건을 마련했다.
- 도로 결빙과 직접 관련이 없는 강풍·자외선·비·제설작업·소음을 추정하지 않고 각 항목의 실제 추가자료가 있을 때만 문구를 생성하도록 했다.
- 일반 결빙만으로 블랙아이스 문구를 만들지 않고 3-12 공식 발생/관측 또는 별도 형성조건에서만 교체하도록 했다. 자외선도 실제 적설면과 공식 자외선지수가 있어야 한다.
- 결빙 시작 전에 안전한 회수시간이 확인된 경우에만 빨래 회수를 권하고, 이미 실외동선 결빙이 관측되면 밖으로 나가지 않도록 교체했다. 산책시간도 실제로 더 나은 조건이 있을 때만 제안했다.
- 수면환경은 거주지 인접도로에서 제설작업이 실제 진행 중이고 소음노출이 있을 때만 창문·귀마개 행동을 연결했다.
- 실제 통제·운전행동부터 생활행동 마감과 별도 시간대 파생상태까지 대표행동 선택순서를 정하고 새 푸시/카드 갱신 조건을 구분했다.
- 3-11-6은 사용자 미확정 권장안이다. 확정 후 다음은 3-11-7 `자료상태·충돌·알림 우선순위와 3-12 블랙아이스(도로살얼음) 문구의 경계`다.

### 문구 기준 3-11-6 확정 및 3-11-7 권장안

- 사용자가 3-11-6 `여덟 생활항목의 영향·직접행동 연결`을 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-11-7 `자료상태·충돌·알림 우선순위와 3-12 블랙아이스(도로살얼음) 문구의 경계` 권장안을 추가했다.
- 노면상태·노면온도·수분·센서정확도·방향·제공구간·통제자료의 미수신, 오류, 이전 자료를 각각 명시하고 마름·결빙없음·통행가능으로 바꾸지 않도록 했다.
- 공식 결빙관측, 젖음/마름관측, 실제 통제/해제, 앱 내부 가능성이 함께 있을 때의 표시순서와 역할을 분리하고 서로 다른 구간·방향·시각·사용면 자료를 평균내지 않도록 했다.
- 실제 통제부터 자료상태까지 알림 우선순위를 정하고 새 푸시와 카드 갱신 조건을 분리했다.
- 3-11 일반 결빙은 수분+노면온도를 최소조건으로, 3-12 블랙아이스(도로살얼음)는 공식 발생/관측·공식 도로살얼음 발생가능 정보 또는 일반 결빙조건+재결빙/어는 강수/안개·이슬·서리 형성경로가 있을 때만 이관하도록 했다.
- 일반 결빙관측·영하기온·체감온도·강수확률·취약도로구조·검증되지 않은 외관·과거 사고위치만으로는 블랙아이스 문구를 만들지 않도록 했다.
- 3-12 상태가 생성되면 같은 경로·시간·행동의 일반 결빙과 중복 푸시하지 않고 3-12 문구를 대표로, 3-11 자료를 상세근거로 보존하도록 했다.
- 실제 전면·방향 통제는 P0, 부분통제·차종제한·가변속도와 공식 블랙아이스 발생/관측·경로별 공식 위험정보는 P1, 공식 일반 결빙관측은 P2, 내부 가능성은 P3로 우선순위를 정리했다.
- 3-11-7은 사용자 미확정 권장안이다. 확정하면 3-11의 일곱 세부항목이 완료되고 다음은 3-12-1 `블랙아이스(도로살얼음)의 공식 명칭과 앱 내부 상태명`이다.

### 문구 기준 3-11-7 확정 및 3-12-1 권장안

- 사용자가 3-11-7을 확정해 제목과 상태를 채택으로 변경했으며, 3-11 도로 결빙 문구의 일곱 세부항목을 완료했다.
- 새 진행항목 3-12 `블랙아이스(도로살얼음) 문구`의 일곱 결정순서와 3-12-1 `공식 명칭과 앱 내부 상태명` 권장안을 추가했다.
- 앱 항목·설정·첫 카드 제목은 `블랙아이스(도로살얼음)`, 같은 맥락의 반복본문은 `블랙아이스`, 공식 출처 라벨은 `도로살얼음 발생가능 정보`로 정했다.
- 공식 실제 발생·관측은 `OFFICIAL_BLACK_ICE_OCCURRED/OBSERVED` 확정형, 공식 안전 0·관심 1·주의 2·위험 3은 `OFFICIAL_ROAD_ICE_LEVEL_*` 공식 가능성, 내부 상태는 `BLACK_ICE_FORMATION_RISK/POSSIBLE` 가능성형으로 분리했다.
- 일반 결빙관측은 `노면 결빙`으로 유지하고 공식기관이 블랙아이스·도로살얼음을 명시하지 않은 상태에서 명칭을 바꾸지 않도록 했다.
- 공식 발생가능 단계는 기관이 가능성을 안내했다는 사실만 확정하고 실제 발생·관측으로 바꾸지 않으며, 변화 없는 안전 0은 기본 노출·푸시하지 않도록 했다.
- 내부 형성경로 기본문구를 비·눈 뒤 재결빙, 어는 강수, 안개·이슬·서리로 나누고 형성경로가 없으면 3-11 일반 도로 결빙 가능성을 유지하도록 했다.
- 사용자 직접기록과 사진/CCTV 외관을 공식 블랙아이스 관측으로 바꾸지 않고 경험사실과 공식 사실을 구분했다.
- 기존 `ICY_ROAD_RISK`를 공식 발생/관측·공식 단계·내부 형성·일반 결빙으로 분해하는 상태명과 Provider 요구를 마련했다.
- 3-12-1은 사용자 미확정 권장안이다. 확정 후 다음은 3-12-2 `공식 발생·관측과 도로살얼음 발생가능 단계 문구`다.

### 문구 기준 3-12-1 확정 및 3-12-2 권장안

- 사용자가 3-12-1 `블랙아이스(도로살얼음)의 공식 명칭과 앱 내부 상태명`을 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-12-2 `공식 발생·관측과 도로살얼음 발생가능 단계 문구` 권장안을 추가했다.
- 공식 발생·관측·현장확인과 일반 노면 결빙관측을 분리하고 기관이 사용한 사실역할을 다른 역할로 바꾸지 않도록 했다.
- 기상청 안전 0·관심 1·주의 2·위험 3단계의 기준시각·대상시각·구간·방향을 포함한 공식 사실문구와 단계별 출발 전/운전 중 직접행동을 마련했다.
- 변화 없는 안전 0과 미관측은 숨기고 이전 관심 이상·실제 발생/관측에서 명시적으로 달라졌을 때만 한 번 표시하도록 했다.
- 같은 구간·방향·대상시각에서 관심→주의→위험 또는 반대방향 단계변화 문구를 정하고 서로 다른 대상은 높고 낮음으로 비교하지 않도록 했다.
- 실제 미관측, 해소 확인, 통제 해제를 별도 공식 사실로 유지하고 어느 하나로 다른 상태를 추정하지 않도록 했다.
- 공식정보 안의 우선순위를 실제 통제 → 발생/관측/확인 → 위험 3 → 주의 2 → 관심 1 → 안전 0으로 정하고 새 푸시/카드 갱신 조건을 구분했다.
- 3-12-2는 사용자 미확정 권장안이다. 확정 후 다음은 3-12-3 `재결빙·어는 강수·안개/이슬/서리 형성경로별 내부 가능성문구`다.

### 문구 기준 3-12-2 확정 및 3-12-3 권장안

- 사용자가 3-12-2 `공식 발생·관측과 도로살얼음 발생가능 단계 문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-12-3 `재결빙·어는 강수·안개/이슬/서리 형성경로별 내부 가능성문구` 권장안을 추가했다.
- 3-11과 같은 노면온도 측정오차 범위를 사용하고, 같은 구간의 실제 노면수분과 확인된 형성경로가 함께 있을 때만 내부 블랙아이스 상태를 만들도록 했다.
- 측정오차 전체가 0℃ 이하이면 `블랙아이스 형성 위험`, 오차범위가 0℃에 걸치면 `블랙아이스 형성 가능`으로 나누되 두 상태 모두 `생길 위험이 있어요·생길 수 있어요`라는 가능성 문장만 사용하도록 했다.
- 비·눈 뒤 재결빙, 어는 강수, 안개·이슬·서리별로 형성 위험 문구 3종과 형성 가능 문구 3종을 마련하고 실제 원인이 확인된 경우에만 원인표현을 붙이도록 했다.
- 일반 비·눈 예보와 강수확률을 어는 강수로, 상대습도를 노면수분으로, 일반 노면 결빙관측을 블랙아이스 관측으로 바꾸지 않도록 했다.
- 실제 기온·체감온도·강수확률만 있을 때는 내부상태를 만들지 않고, 노면자료가 없는 날씨 보조안내와 필수자료 오류·미수신을 각각 판단 어려움으로 분리했다.
- 직접행동을 첫 문장에 두고 내부 판단과 근거가 뒤따르는 재결빙·어는비·안개 경로별 첫 노출 예시를 추가했다. 실제 통제·공식 발생·관측·공식 위험 3단계는 이보다 우선한다.
- 3-12-3은 사용자 미확정 권장안이다. 확정 후 다음은 3-12-4 `운전·보행·자전거·이동보조기기 영향문구`다.

### 문구 기준 3-12-3 확정 및 3-12-4 권장안

- 사용자가 3-12-3 `재결빙·어는 강수·안개/이슬/서리 형성경로별 내부 가능성문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-12-4 `운전·보행·자전거·이동보조기기 영향문구` 권장안을 추가했다.
- 공식 블랙아이스 발생·관측은 확인된 구간의 사실만 확정하고 개인의 미끄러짐·낙상·사고는 가능성으로, 공식 발생가능 단계와 앱 내부 형성상태는 `블랙아이스가 생기면`을 붙인 조건부 영향으로 표현하도록 했다.
- 운전, 보행, 자전거·전동킥보드, 휠체어, 지팡이·목발·보행기별로 공식 발생·관측 기준 영향 3종과 공식/내부 가능성 기준 영향 3종을 각각 마련했다.
- 블랙아이스의 얇고 투명해 도로색과 비슷한 특성을 식별 어려움 문구 3종으로 정리했지만, 사용자가 육안으로 안전 여부를 판별하도록 안내하지 않도록 했다.
- 기상청 도로살얼음 정보의 차도 범위를 보행로·분리 자전거도로·경사로까지 확대하지 않고 실제 사용면·구간·방향·시간과 사용자 경로가 일치할 때만 개인 영향을 만들도록 했다.
- 일반 결빙관측만 있으면 3-11 문구를 유지하고, 날씨 보조안내·자료부족 상태에서는 개인 피해문구를 만들지 않도록 했다.
- 실제 사건 가능성에는 `느껴질 수 있어요`를 사용하지 않고 `미끄러질 수 있어요·넘어질 수 있어요·멈추기 어려울 수 있어요`로 표현했다.
- 3-12-4는 사용자 미확정 권장안이다. 확정 후 다음은 3-12-5 `직접행동과 첫 노출순서`다.

### 문구 기준 3-12-4 확정 및 3-12-5 권장안

- 사용자가 3-12-4 `운전·보행·자전거·이동보조기기 영향문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-12-5 `직접행동과 첫 노출순서` 권장안을 추가했다.
- 실제 통제·공식 블랙아이스 발생/관측·공식 위험/주의/관심 단계·앱 내부 형성 위험/가능·자료부족별로 이유의 사실수준과 직접행동 강도를 나눴다.
- 운전 중에는 감속·안전거리·급제동/급가속/급핸들 금지를 먼저 안내하고 정보검색을 요구하지 않으며, 출발 전에는 공식 통제·우회·최신 도로정보 확인을 안내하도록 했다.
- 보행, 자전거·전동킥보드, 휠체어, 지팡이·목발·보행기별 출발 전·이동 중 직접행동과 실제 사용면 확인조건을 마련했다.
- 특정 우회경로·대체시간·대체교통·무장애경로는 실제 이용 가능성, 상대적으로 더 나은 노면·통제상태, 자료 신선도, 사용자 접근성을 모두 확인한 경우에만 제안하도록 했다.
- 첫 노출을 `직접행동 1개 → 보조행동 최대 1개 → 활동영향 1개 → 공식 사실/단계 → 내부 형성판단 → 상세근거`로 정하고 실제 통제·현장지시는 맨 앞에 두도록 했다.
- 실제 통제·공식 관측·단계상승·형성 위험 강화·새 대체안·활동변경별 새 푸시 조건과 같은 행동의 수치·원인·교대표현만 바뀐 카드 갱신 조건을 구분했다.
- 3-12-5는 사용자 미확정 권장안이다. 확정 후 다음은 3-12-6 `여덟 생활항목의 영향·직접행동 연결`이다.

### 문구 기준 3-12-5 확정 및 3-12-6 권장안

- 사용자가 3-12-5 `직접행동과 첫 노출순서`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-12-6 `여덟 생활항목의 영향·직접행동 연결` 권장안을 추가했다.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경별 대표 직접행동·내부 영향과 생성조건을 마련했다.
- 블랙아이스만으로 강풍·자외선·현재 비·제설작업·소음을 추정하지 않고 각각 독립된 자료가 실제 경로·사용면·시간과 겹칠 때만 문구를 연결하도록 했다.
- 차도 블랙아이스 정보를 보행로·산책로·빨래 회수동선으로 확대하지 않고 해당 사용면 자료가 확인될 때만 생활행동을 생성하도록 했다.
- 빨래는 결빙 전 더 안전한 회수시간이 확인된 경우에만 회수를 권하고 이미 관측된 동선으로 나가게 하지 않으며, 산책은 더 나은 시간 확인 여부와 현재 산책상태에 따라 시간변경·실내활동·현재 이동행동을 나눴다.
- 반려견의 제설제 발 세척은 해당 산책로에 제설제가 실제 살포된 경우에만, 수면환경은 인접도로에서 실제 블랙아이스 제거작업이 진행되고 소음노출이 확인된 경우에만 생성하도록 했다.
- 실제 통제·현재 이동 중 행동부터 출발 전 경로행동, 생활행동 마감, 별도 날씨 준비, 실제 야간작업 수면대비 순으로 대표행동을 정하고 새 푸시·카드 갱신 조건을 구분했다.
- 3-12-6은 사용자 미확정 권장안이다. 확정 후 다음은 3-12-7 `자료상태·충돌·알림 우선순위와 3-13 서리·차량 성에 문구의 경계`다.

### 문구 기준 3-12-6 확정 및 3-12-7 권장안

- 사용자가 3-12-6 `여덟 생활항목의 영향·직접행동 연결`을 확정해 제목과 상태를 채택으로 변경했다.
- 마지막 결정항목 3-12-7 `자료상태·충돌·알림 우선순위와 3-13 서리·차량 성에 문구의 경계` 권장안을 추가했다.
- 공식 발생·관측, 도로살얼음 발생가능 단계, 노면온도·수분·형성경로, 방향·제공구간, 통제·대체경로별 미수신·품질오류·이전 자료 문구를 마련하고 안전·미발생·통행가능으로 바꾸지 않도록 했다.
- 공식 발생·관측·단계와 앱 내부 형성판단이 함께 있을 때 역할을 분리하고 실제 통제와 관측을 우선하되 어느 한쪽을 삭제하거나 단계·수치로 평균내지 않도록 했다.
- 같은 구간·방향·사용면·대상시각의 유효한 자료가 실제로 상반되고 공식 안전 0이 표시 대상일 때만 `앱 판단과 기상청 도로살얼음 발생가능 정보가 달라요` 같은 차이문구를 사용하도록 했다.
- 실제 통제부터 공식 관측, 공식 위험/주의 단계, 내부 형성상태, 관심단계·생활영향, 자료상태 순으로 알림 우선순위를 정하고 새 푸시와 카드 갱신 조건을 구분했다.
- 3-12의 도로 표면, 3-13의 지역 서리·차량 외부 성에·차량 내부 김서림/성에를 대상표면·공식사실·내부조건·행동별로 분리하고 공통 날씨조건만으로 서로의 상태를 생성하지 않도록 했다.
- 실제 차량 성에와 경로 블랙아이스가 함께 있을 때는 시야확보와 경로행동을 각각 표시하되 실제 도로통제가 있으면 통제행동을 최우선으로 두도록 했다.
- 3-12-7은 사용자 미확정 권장안이다. 확정하면 3-12의 일곱 세부항목을 완료하고 다음은 3-13-1 `서리·차량 성에의 공식 명칭과 앱 내부 상태명`이다.

### 문구 기준 3-12-7 확정 및 3-13-1 권장안

- 사용자가 3-12-7을 확정해 제목과 상태를 채택으로 변경했으며, 3-12 블랙아이스(도로살얼음) 문구의 일곱 세부항목을 완료했다.
- 새 진행항목 3-13 `서리·차량 성에 문구`의 일곱 결정순서와 3-13-1 `공식 명칭과 앱 내부 상태명` 권장안을 추가했다.
- 상위 항목은 `서리·차량 성에`, 개별 화면은 `지역 서리·차량 바깥 유리 성에·차량 안쪽 유리 김서림·차량 안쪽 유리 성에`로 나눠 대상표면과 액체/얼음 상태를 명확히 했다.
- 공식 지역 서리 관측·확률·예측, 차량 센서/사용자 직접확인, 차량 외부 성에 위험/가능, 지역 서리 기반 날씨 보조안내, 차량 내부 김서림/성에 가능, 자료부족 상태를 별도 상태명으로 분리했다.
- 기상청 5km 격자의 지역 서리 원 확률을 차량 성에·블랙아이스·농작물 피해확률로 바꾸지 않고, 야외주차와 차량계획이 확인된 경우에만 차량 보조안내를 만들도록 했다.
- 특정 차량의 성에·김서림이 실제 확인된 경우에는 확정형으로 표시할 수 있지만 차량자료와 사용자 직접기록을 구분하고 공식 기상관측으로 바꾸지 않도록 했다.
- 현재 단일 `VEHICLE_FROST_RISK`를 공식 지역, 차량 실제 확인, 외부 내부판정, 내부 김서림/성에, 날씨 보조안내, 자료상태로 분해하는 상태명과 Provider 요구를 마련했다.
- 3-13-1은 사용자 미확정 권장안이다. 확정 후 다음은 3-13-2 `공식 지역 서리 관측·발생가능 정보 문구`다.

### 문구 기준 3-13-1 확정 및 3-13-2 권장안

- 사용자가 3-13-1 `서리·차량 성에의 공식 명칭과 앱 내부 상태명`을 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-13-2 `공식 지역 서리 관측·발생가능 정보 문구` 권장안을 추가했다.
- 관측소의 실제 서리 관측은 관측일·관측소 이름과 `(기상청 서리관측자료)`, 공식 발생확률·발생예측은 대상시간·행정동과 `(기상청 5km 격자 기준)`을 문장 뒤에 표시하도록 했다.
- 관측자료에 시각이 없으면 임의의 시각을 만들지 않고 관측소 점 관측을 사용자 위치·행정구역 전체·차량 유리로 확대하지 않도록 했다.
- 공식 원 확률, 적용 임계값, 추천 임계값, 서리 발생예측 여부를 서로 다른 값으로 보존하고 지역 서리 확률을 차량 성에·블랙아이스·농작물 피해확률로 바꾸지 않도록 했다.
- 같은 격자·대상시간의 확률변화는 `%p`로 비교하고, 변화 없는 미관측·발생예측 없음은 숨기며 이전 공식정보와 실제로 달라졌을 때만 한 번 표시하도록 했다.
- 같은 관측소가 예측격자 안에 있고 관측시간과 대상시간이 일치하는 경우에만 실제 관측과 당시 발생예측 차이를 안내하며 낮은 확률과 실제 관측은 단순 충돌로 만들지 않도록 했다.
- 지역 서리정보만으로 차량 성에 푸시를 만들지 않고 차량 등록·야외주차·출발계획 또는 실제 생활행동이 있을 때만 보조행동으로 연결하도록 했다.
- 3-13-2는 사용자 미확정 권장안이다. 확정 후 다음은 3-13-3 `차량 외부 성에·내부 김서림/성에의 내부 가능성문구`다.

### 문구 기준 3-13-2 확정 및 3-13-3 권장안

- 사용자가 3-13-2 `공식 지역 서리 관측·발생가능 정보 문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-13-3 `차량 외부 성에·내부 김서림/성에의 내부 가능성문구` 권장안을 추가했다.
- 차량 바깥 유리는 표면온도 오차범위와 외부 서리점 또는 실제 수분막, 차량 안쪽 유리는 표면온도와 실내 노점/서리점으로 판단하고 대기기온·체감온도·외부 습도 하나로 대체하지 않도록 했다.
- 바깥 유리 성에는 오차범위 전체가 조건을 충족하는 형성 위험과 경계를 걸치는 형성 가능으로 나누고 각각 사용자 문구 3종을 마련했다.
- 공식 지역 서리정보만 있고 차량자료가 없을 때의 날씨 보조안내, 차량 안쪽 유리 김서림 가능, 안쪽 유리 성에 가능, 0℃ 경계에서 두 상태를 구분하기 어려운 경우에도 문구 3종씩을 마련했다.
- 맑음·약한 바람·장시간 야외주차·지붕 없음·유리 덮개는 보정자료로만 사용하고 유리 표면온도·서리점·수분이라는 필수조건을 대신하지 않도록 했다.
- 같은 차량·표면·대상시간 자료만 결합하고 미래 `내일 아침` 문구는 유리온도 예측과 실제 출발시간이 겹칠 때만 사용하도록 했다.
- 실제 사건 가능성은 `낄 수 있어요·붙을 가능성이 있어요·얼 수도 있어요`로 표현하고 감각어미는 사용하지 않도록 했다.
- 3-13-3은 사용자 미확정 권장안이다. 확정 후 다음은 3-13-4 `주차·출발준비·운전시야 영향문구`다.

### 문구 기준 3-13-3 확정 및 3-13-4 권장안

- 사용자가 3-13-3 `차량 외부 성에·내부 김서림/성에의 내부 가능성문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-13-4 `주차·출발준비·운전시야 영향문구` 권장안을 추가했다.
- 차량 바깥 유리 성에, 안쪽 유리 김서림, 안쪽 유리 성에별로 실제 확인 기준 영향 3종과 내부 가능성 기준 조건부 영향 3종을 각각 마련했다.
- 지역 서리정보만 있는 경우의 야외주차 차량 보조영향과 김서림·성에를 구분하기 어려운 경우의 공통 시야·준비영향도 각각 3종으로 정리했다.
- 앞유리·측면 창·거울의 실제 확인범위를 다른 유리로 확대하지 않고 주차·출발 전·운전 중 상황에 맞는 영향만 생성하도록 했다.
- 와이퍼 결빙과 와셔액 재결빙은 앞유리 성에나 낮은 기온만으로 추정하지 않고 실제 장치상태·와셔액 사양·유리온도 근거가 있을 때만 시야·장치영향을 만들도록 했다.
- 운전 중 현재 시야영향부터 출발 직전 실제 상태, 내부 가능성, 지역 서리 일반 준비영향 순으로 대표영향을 정하고 새 푸시·카드 갱신 조건을 구분했다.
- 실제 시야·출발준비 영향은 `확인하기 어려울 수 있어요·늦어질 수 있어요·시간이 걸릴 수 있어요`로 표현하고 사고·완전한 시야상실·정확한 지연시간을 확정하지 않도록 했다.
- 3-13-4는 사용자 미확정 권장안이다. 확정 후 다음은 3-13-5 `직접행동과 첫 노출순서`다.

### 문구 기준 3-13-4 확정 및 3-13-5 권장안

- 사용자가 3-13-4 `주차·출발준비·운전시야 영향문구`를 확정해 제목과 상태를 채택으로 변경했다.
- 다음 결정항목 3-13-5 `직접행동과 첫 노출순서` 권장안을 추가했다.
- 실제 성에·김서림, 내부 형성 위험/가능, 지역 서리 보조안내, 김서림/성에 구분불가, 와이퍼 결빙·와셔액 재결빙, 자료부족별 직접행동 강도를 나눴다.
- 출발 전에는 앞유리·측면 창·거울의 시야를 확보한 뒤 출발하고, 운전 중에는 김서림 제거 기능을 사용하며 시야가 충분하지 않으면 안전한 곳에 정차하도록 했다.
- 와이퍼가 실제 얼어붙었으면 강제로 작동하지 않고 먼저 녹이며, 와셔액은 차량 사양과 유리온도에서 재결빙 가능성이 확인된 경우에만 겨울용 제품·제조사 절차를 안내하도록 했다.
- 차량 제조사·차종·연식·기능·사용설명서가 확인될 때만 구체적인 기능명과 절차를 표시하고 온도·풍량·원격시동을 모든 차량에 공통 적용하지 않도록 했다.
- 특정 출발시간은 같은 차량·주차환경의 실제 조건과 다른 도로위험, 일정 가능성을 비교해 더 나은 시간이 확인된 경우에만 제안하도록 했다.
- 첫 노출을 `직접행동 1개 → 보조행동 최대 1개 → 시야/준비 영향 1개 → 차량 확인사실 → 공식 지역 서리정보 → 내부 가능성 → 상세근거`로 정했다.
- 3-13-5는 사용자 미확정 권장안이다. 확정 후 다음은 3-13-6 `여덟 생활항목의 영향·직접행동 연결`이다.

### 문구 기준 3-13-5 확정 및 전체 잔여범위 확인

- 사용자가 3-13-5 `직접행동과 첫 노출순서`를 확정해 제목과 상태를 채택으로 변경했다.
- 3-13 안에서는 3-13-6 `여덟 생활항목 연결`, 3-13-7 `자료상태·충돌·우선순위와 3-14 경계`의 두 결정항목이 남았다.
- 전체 표현정책 로드맵은 공통 13개, 기온·체감 5개, 강수·적설·노면 14개, 바람·습도 10개, 자외선·대기환경 14개, 생활행동 21개로 총 77개 주요항목이며 현재 3-13까지 완료 직전이다.
- 3-13을 완료한 뒤에도 3-14 동파 1개, 4장 10개, 5장 14개, 6장 21개로 총 46개 주요항목과 마지막 출력·운영 표현 전체 대조가 남는다. 주요항목 수 기준 현재 진행률은 약 40%다.
- 사용자가 처음 지정한 여덟 핵심항목만 우선할 경우 전체 46개를 순서대로 모두 검토하지 않고 강풍·습도/수면·자외선·우산/빨래·산책·출퇴근과 직접 관련된 항목만 골라 진행할 수 있다.
- 다음 작업은 사용자가 범위를 바꾸지 않으면 기존 순서대로 3-13-6 권장안을 제시한다.

### 사실문구 자동확정 및 체감기준별 3종 원칙 확정

- 사용자는 체감 관련 문구가 아닌 사실 안내문구는 권장안을 기본안으로 모두 확정하도록 진행방식을 변경했다.
- 공식 발표·발효·관측·예보, 검증 가능한 산술결과, 직접기록과 자료상태를 알리는 사실문구는 사용자가 별도로 수정하지 않는 한 권장안을 곧바로 채택하고 확인항목으로 반복 제시하지 않는다.
- 직접행동이나 내부 피해·활동 가능성은 사실문구가 아니므로 이번 자동확정 범위로 임의 확대하지 않는다.
- 체감기준은 기준 하나마다 같은 대상·강도·확실성을 유지하는 사용자 표현 3종을 마련한다는 기존 원칙을 재확인했다.
- 앞으로의 검토는 체감기준과 체감표현을 중심으로 진행하고 사실문구는 필요한 근거·범위·시각·출처를 갖춘 기본안으로 문서에 바로 반영한다.

### 사용자 확인항목 최소화 원칙 확정

- 사용자는 사실 안내문구의 권장안을 자동으로 적용하고, 체감기준별 표현 3종과 그 밖에 실제 사용자 의견이 필요한 사항만 질문하도록 요청했다.
- 진행방식을 수정해 체감기준별 표현 3종 또는 사용자 선호에 따라 결과가 달라지는 정책 판단만 `권장안`으로 제시하도록 했다.
- 공식 사실·직접기록·산술결과·자료상태·출처표기·기존 원칙을 그대로 적용한 문장구조는 별도 확인 없이 문서에 바로 채택한다.
- 행동 강도·알림 우선순위·개인화처럼 선택에 따라 제품정책이 실질적으로 달라질 때만 추가 의견을 요청한다.

### 문구 기준 3-13-6 자동채택

- 새 진행원칙에 따라 3-13-6 `서리·차량 성에와 여덟 생활항목의 영향·직접행동 연결`을 별도 사용자 확인 없이 채택했다.
- 지역 서리와 차량 성에를 강풍·블랙아이스(도로살얼음)·자외선·비·산책로 결빙·실내 저온의 근거로 확대하지 않고, 각 항목의 독립자료와 사용자 시간·장소가 일치할 때만 연결하도록 했다.
- 직접 연결은 지역 서리와 실외 빨래 회수, 차량 성에와 차량 출퇴근으로 한정하고 강풍·블랙아이스·비는 독립자료가 있을 때 조건부로, 자외선·산책·수면환경은 각 항목의 별도 기준으로만 생성하도록 했다.
- 차량 시야확보·실제 도로통제·경로 위험·차량 출발준비·빨래 회수 순으로 대표행동을 정하고 같은 일정의 중복 푸시는 병합하도록 했다.
- 새 주관적 체감기준은 만들지 않았다. 서리 부착·수분 결빙·시야저하·출발지연은 실제 사건 가능성이므로 감각어미나 체감문구 3종을 적용하지 않는다.
- 다음 항목은 3-13-7 `자료상태·충돌·알림 우선순위와 3-14 동파 문구의 경계`다.

### 자동채택 항목 생략 진행 및 4-7 체감문구 도달

- 사용자는 자동 채택항목을 진행상황으로 제시하지 말고 내부적으로 계속 처리한 뒤, 체감기준별 3종이나 실제 의견이 필요한 작업만 보여 달라고 요청했다.
- 3-13-7 자료상태·충돌·알림 우선순위와 3-14 동파 문구를 자동 채택했다. 두 항목에는 새 주관적 체감기준이 없으며 실제 상태·피해 가능성은 사건 가능성 어미로만 정리했다.
- 4-1 풍속, 4-2 강풍, 4-3 돌풍, 4-4 보행·자전거·운전 영향, 4-5 우산 사용 영향, 4-6 실내 습도 사실 문구를 자동 채택했다.
- 4-1의 기상청 풍속단계는 공식 정성명칭이지 사용자 체감기준이 아니므로 3종을 만들지 않았다. 4-2~4-5의 피해·활동 영향도 실제 사건 가능성이므로 감각어미를 사용하지 않았다.
- 4-6의 일반 습도범위 안이라는 이유로 `쾌적·무난` 체감을 생성하지 않고 측정사실과 일반 안내범위만 표시하도록 했다.
- 사용자 의견이 필요한 첫 작업은 4-7-2 고습 체감의 다섯 기준별 문구 3종이다. 기준은 약한 눅눅함, 따뜻하고 습한 후텁지근함, 피부 끈적임·땀 잔류감, 서늘하고 축축한 공기, 오래 이어지는 눅눅함이다.

### 4-7 고습 체감문구 1차 수정

- 사용자는 `따뜻하고 습한 후텁지근함`에서 `따뜻한`이 불쾌한 고습 체감과 맞지 않는다고 지적했다.
- 해당 기준의 수치가 실내 28℃ 이상, 실외 27℃ 이상 고습조건이므로 `뜨겁고 습한`처럼 과도한 표현 대신 `덥고 습한 후텁지근함`으로 기준명을 수정했다.
- 두 번째 표현을 `공기가 덥고 습한 느낌이 들 수 있어요`로 바꾸고, 세 표현 모두 덥고 습한 조건이 함께 확인될 때만 사용하도록 했다.
- 피부 끈적임·땀 잔류감의 두 번째 표현은 사용자 요청대로 `움직이면 땀이 끈적하고 잘 마르지 않는 느낌이 들 수 있어요`로 수정했다.
- 4-7-2 전체는 아직 사용자 최종 확정 전이다.

### 4-7 후텁지근함 문구 2차 수정

- 사용자는 `덥고 습한 후텁지근함`의 두 번째 표현을 `더운 공기와 습함이 느껴질 수 있어요`로 수정했다.
- 현재 세 문구는 `후텁지근하게 느껴질 수 있어요`, `더운 공기와 습함이 느껴질 수 있어요`, `덥고 습하다고 느낄 수도 있어요`다.
- 4-7-2 전체는 아직 사용자 최종 확정 전이다.

### 4-7 확정 및 4-8 저습·건조 체감문구 권장안

- 사용자가 수정된 4-7 고습 체감문구에서 다음 작업으로 진행해 4-7-2를 채택 상태로 변경했다.
- 4-8의 공식 건조특보·실효습도·실외 상대습도·실내 센서 측정과 자료상태 문구는 자동 채택했다.
- 저습 체감은 공기 메마름, 눈 뻑뻑함, 입술 마름, 코 안쪽 마름, 목 안쪽 마름, 피부 당김, 피부 거침의 7개 기준으로 분리했다. 신체부위와 감각이 다른 문구를 같은 3종 안에서 교대하지 않는다.
- 난방은 별도 체감기준이 아니라 확인된 경우 공기 메마름 문구 앞에 붙는 원인절로 처리한다.
- 정전기는 주관적 체감이 아니라 실제 사건 가능성 `정전기가 튈 수 있어요`로 자동 처리해 체감문구 3종에서 제외했다.
- 사용자 의견이 필요한 다음 작업은 4-8-2의 7개 기준별 문구 3종이다.

### 4-8 확정 및 자외선 직접 체감문구 권장안

- 사용자가 4-8 저습·건조 체감기준별 문구 3종을 확정해 4-8-2를 채택 상태로 변경했다.
- 4-9 제습과 4-10 가습은 4-7·4-8의 기존 체감문구를 재사용하고 방법의 적합성·기기효과·과습/과건조 가능성만 다루므로 자동 채택했다.
- 5-1 자외선지수의 공식 5단계와 예보·관측·위성·앱 참고값·자료상태 문구는 자동 채택했다.
- 자외선은 단계와 무관하게 몸으로 강도를 직접 느끼기 어렵고 뜨거움·끈적함·눈부심을 자외선지수 체감으로 사용하지 않는다는 기준을 채택했다.
- 사용자 의견이 필요한 다음 작업은 `자외선 강도의 직접 체감 어려움` 기준에 사용할 문구 3종이다.

### 5-1 자외선 직접 체감문구 수정

- 사용자는 세 번째 문구로 `덥게 느껴지는 정도와 자외선 강도는 차이가 날 수 있어요`와 `덥게 느껴지는 정도와 자외선 강도는 다를 수 있어요`를 비교했다.
- 더 자연스럽고 짧으며 수치 비교로 오해할 여지가 적은 `덥게 느껴지는 정도와 자외선 강도는 다를 수 있어요`를 선택해 반영했다.
- 5-1-3 전체는 아직 사용자 최종 확정 전이다.

### 5-1 확정 및 5-2 지연 피부감각 권장안

- 사용자가 수정된 5-1 자외선 직접 체감 어려움 문구 3종을 확정해 5-1-3을 채택 상태로 변경했다.
- 5-2의 공식 단계별 일반 피부화상 가능시간, 실제·계획 야외시간, 주변 누적노출 참고값, 자료상태와 피부 붉어짐·직접기록 문구는 자동 채택했다.
- 피부 붉어짐·물집은 실제 사건, 통증은 직접기록 또는 확인상태로 처리해 체감문구 3종에서 제외했다.
- 지연 피부감각은 화끈거림·따가움·예민함의 세 기준으로 분리하고 각각 문구 3종을 마련했다. 개인기록이 없으면 구체감각을 기본예측하지 않고 일반 피부반응 가능성만 표시한다.
- 사용자 의견이 필요한 다음 작업은 5-2-2의 세 기준별 문구 3종이다.

### 5-2 확정, 5-3 자동채택 및 5-4 체감문구 권장안

- 사용자가 5-2-2 자외선 노출 뒤 피부 화끈거림·따가움·예민함의 기준별 문구 3종을 확정해 채택 상태로 변경했다.
- 5-3 선크림 필요·사용 문구는 자외선지수와 실제·계획 야외활동을 연결하고, 일반 제품에 개인 안전시간이나 보호율을 계산하지 않는 정책으로 자동 채택했다.
- 선크림의 산뜻함·촉촉함·끈적임·무거움·번들거림·백탁·화장 밀림·눈시림·따가움은 날씨로 예측하지 않고 사용자 직접기록으로만 표시하므로 새 체감기준 3종을 만들지 않았다.
- 5-4 모자·양산의 공식 일반안내, 내부 도움 가능성, 직접행동, 제품별 공식 시험결과 제한, 강풍 시 4-5 우산 영향기준 재사용을 자동 채택했다.
- 모자·양산에서 앱이 예측할 주관적 체감은 실제 가림범위가 확인된 `양산 아래의 그늘감·어두움`과 `가려진 부위의 햇볕 열감 감소` 두 기준으로 한정했다.
- 사용자 의견이 필요한 다음 작업은 5-4-2의 두 체감기준별 문구 3종이다.

### 5-4 모자·양산 체감문구 긍정 표현 수정

- 사용자는 양산 아래의 변화를 `어두움` 중심의 부정적인 표현 대신 양산 사용의 긍정적인 도움과 체감으로 표현해 달라고 요청했다.
- `양산으로 그늘을 만들어 자외선을 피할 수 있어요`는 완전 회피로 오해되지 않도록 `양산으로 그늘을 만들면 직사광선과 자외선 노출을 줄이는 데 도움이 될 수 있어요`라는 도움 가능성 문구로 분리했다.
- 자외선 노출 감소, 눈부심 완화, 햇볕 열감 감소는 서로 다른 대상이므로 같은 체감기준의 문구 3종으로 섞지 않았다.
- 첫 체감기준은 `양산 사용 뒤 눈부심 완화`로 바꾸고 긍정적인 문구 3종을 마련했다.
- 열감 감소 기준의 세 번째 문구는 사용자가 제안한 `양산 아래가 좀 더 시원하다고 느낄 수도 있어요`로 옮겼다.
- 5-4-2는 수정된 상태로 사용자 확정 전이다.

### 5-4 눈부심 완화 문구 2차 수정

- 사용자가 `양산 사용 뒤 눈부심 완화` 기준의 문구 3종을 직접 수정했다.
- 현재 문구는 `양산을 쓰면 햇빛이 덜 눈부시게 느껴질 수 있어요`, `양산의 그늘로 눈부심이 줄어 한결 편안할 수 있어요`, `양산을 이용해 눈의 부담을 줄일 수도 있어요`다.
- 첫 문장은 주관적 체감, 두 번째와 세 번째는 실제 도움 가능성으로 구분하되 같은 눈부심·눈의 부담 감소 대상 안에서 교대한다.
- 5-4-2는 열감 감소 문구 3종과 함께 사용자 최종 확정 전이다.

### 5-4 확정 및 미세먼지 직접 체감문구 권장안

- 사용자가 5-4-2 양산 사용 뒤 눈부심 완화와 햇볕 열감 감소의 문구 3종을 확정해 채택 상태로 변경했다.
- 5-5 미세먼지(PM10)와 5-6 초미세먼지(PM2.5)의 공식 4등급, 측정·예보·활성 발령, 물질별 분리, 개인노출 불확실, 직접기록과 자료상태 문구는 자동 채택했다.
- 두 물질의 공식 등급을 `안전·주의·위험`으로 바꾸거나 농도를 합치지 않고, 하늘빛·냄새·몸의 느낌으로 수치와 등급을 역산하지 않도록 했다.
- 국내 연구에서 공식 등급경계와 일치하는 보편적 감각선이 확인되지 않아 농도별 예상증상표는 만들지 않는다.
- 사용자 의견이 필요한 다음 작업은 `감각만으로 미세먼지·초미세먼지 농도 판단 어려움` 기준의 문구 3종이다.

### 5-5·5-6 감각판단 문구 수정

- 사용자는 감각만으로 미세먼지·초미세먼지 농도를 판단하기 어렵다는 세 번째 문구를 냄새 기준에서 공기의 텁텁함 기준으로 변경했다.
- 세 번째 문구는 `공기가 텁텁하지 않아도 미세먼지나 초미세먼지 농도는 높을 수 있어요`다.
- 텁텁함이 없다는 사용자 느낌도 공식 농도가 낮다는 근거로 사용하지 않는다.
- 5-5-2·5-6-2는 사용자 최종 확정 전이다.

### 5-5·5-6 확정 및 5-7 민감군 활동부담 문구 권장안

- 사용자가 5-5-2·5-6-2 감각만으로 미세먼지·초미세먼지 농도를 판단하기 어려움 문구 3종을 확정해 채택 상태로 변경했다.
- 5-7의 공식 민감군 행동요령, 사용자·보호자 직접등록, 몸상태 확인질문, 직접기록, 보호자 관찰, 원인 불확실성과 자료상태 문구는 자동 채택했다.
- 공식 `보통`은 기록질문 진입조건으로만 사용하고, `나쁨·매우나쁨` 또는 활성 공식 경보와 등록된 민감군, 같은 시간의 야외활동이 함께 있을 때만 활동 부담 가능성을 만들도록 했다.
- 목·기침·쌕쌕거림·숨참·가슴·피부·눈·코의 구체 불편은 직접응답 또는 보호자 관찰항목으로 제공하고 농도만으로 자동 예측하지 않으므로 체감문구 3종 대상에서 제외했다.
- 사용자 의견이 필요한 다음 작업은 `민감군의 장시간 야외활동 부담` 체감기준 문구 3종이다.

### 5-7 확정 및 5-8 마스크 호흡부담 문구 권장안

- 사용자가 5-7-2 민감군의 장시간 야외활동 부담 체감문구 3종을 확정해 채택 상태로 변경했다.
- 5-8의 공식 마스크 행동요령, 정확한 식약처 보건용 마스크 허가·KF등급, 입자노출 감소 도움 가능성, 밀착·제품상태, 공식 착용중단 안내와 자료상태 문구는 자동 채택했다.
- KF 숫자를 개인 보호율로 바꾸지 않고 공기질 등급만으로 특정 KF등급을 고르거나 모든 사람에게 적합하다고 판단하지 않도록 했다.
- 마스크 착용 체감은 호흡 부담, 안쪽의 열·습기, 피부 마찰·압박으로 분리하며 같은 제품·활동의 직접기록 또는 반복기록이 있을 때만 가능성 문구를 만든다.
- 사용자 의견이 필요한 다음 작업은 5-8-2a `마스크 착용 중 호흡 부담` 체감기준의 문구 3종이다.

### 5-8 마스크 호흡부담 문구 수정

- 사용자는 5-8-2a의 첫 문장을 `마스크를 쓰고 움직이면 평소보다 숨쉬는 게 답답하게 느껴질 수 있어요`로 수정했다.
- 문장 표기는 의존명사 띄어쓰기를 적용해 `숨쉬는 게`로 반영했다.
- 두 번째와 세 번째 문구 및 생성조건은 유지했으며 5-8-2a는 사용자 최종 확정 전이다.

### 5-8 호흡부담 확정 및 열·습기 체감문구 권장안

- 사용자가 수정된 5-8-2a 마스크 착용 중 호흡 부담 체감문구 3종을 확정해 채택 상태로 변경했다.
- 마스크 안쪽의 열·습기는 후끈함·눅눅함·습기가 참·달라붙음의 직접기록 또는 같은 제품·활동의 반복기록이 있을 때만 가능성 문구를 만들도록 했다.
- 피부 마찰·귀 압박은 열·습기 체감과 섞지 않고 뒤의 별도 기준으로 유지한다.
- 사용자 의견이 필요한 다음 작업은 5-8-2b `마스크 안쪽의 열·습기` 체감기준 문구 3종이다.

### 5-8 열·습기 확정 및 마찰·쓸림 문구 권장안

- 사용자가 5-8-2b 마스크 안쪽의 열·습기 체감문구 3종을 확정해 채택 상태로 변경했다.
- 피부 접촉 불편을 얼굴 접촉부위의 마찰·쓸림, 귀끈 압박, 피부 가려움·따가움으로 분리했다.
- 마찰·쓸림은 같은 제품에서 콧등·볼·턱의 직접기록 또는 같은 부위의 반복기록이 있을 때만 가능성 문구를 만든다.
- 사용자 의견이 필요한 다음 작업은 5-8-2c `마스크 접촉부위의 마찰·쓸림` 문구 3종이다.

### 5-8 마찰·쓸림 확정 및 귀끈 압박 문구 권장안

- 사용자가 5-8-2c 마스크 접촉부위의 마찰·쓸림 문구 3종을 확정해 채택 상태로 변경했다.
- 다음 피부 접촉 체감은 귀끈의 당김·압박으로 분리하고 같은 제품에서 직접기록 또는 반복기록이 있을 때만 가능성 문구를 만든다.
- 귀끈 압박은 얼굴 접촉부위의 마찰과 피부 가려움·따가움으로 확대하지 않는다.
- 사용자 의견이 필요한 다음 작업은 5-8-2d `마스크 귀끈의 당김·압박` 체감문구 3종이다.

### 5-8 귀끈 압박 확정 및 피부 가려움 문구 권장안

- 사용자가 5-8-2d 마스크 귀끈의 당김·압박 체감문구 3종을 확정해 채택 상태로 변경했다.
- 마스크 접촉부위의 피부 반응은 가려움과 따가움으로 나눠 같은 감각 안에서 문구를 교대하도록 했다.
- 가려움은 같은 제품에서 가려움·간지러움의 직접기록 또는 같은 부위의 반복기록이 있을 때만 가능성 문구를 만든다.
- 사용자 의견이 필요한 다음 작업은 5-8-2e `마스크 접촉부위의 가려움` 체감문구 3종이다.

### 5-8 피부 가려움 확정 및 따가움 문구 권장안

- 사용자가 5-8-2e 마스크 접촉부위의 가려움 체감문구 3종을 확정해 채택 상태로 변경했다.
- 다음 기준은 가려움과 구분한 마스크 접촉부위의 따가움·따끔거림으로 정했다.
- 따가움은 같은 제품에서 직접기록 또는 같은 부위의 반복기록이 있을 때만 가능성 문구를 만들며 마찰·쓸림이나 피부질환으로 자동 확대하지 않는다.
- 사용자 의견이 필요한 다음 작업은 5-8-2f `마스크 접촉부위의 따가움` 체감문구 3종이다.

### 5-8 완료 및 오존 직접 체감문구 권장안

- 사용자가 5-8-2f 마스크 접촉부위의 따가움 체감문구 3종을 확정해 채택 상태로 변경했다.
- 5-9의 공식 오존 4등급, 예보·측정·활성 발령·해제, 개인노출 불확실, 직접기록, 원인 불확실성과 자료상태 문구는 자동 채택했다.
- 권역 예보·측정소 1시간 자료·오존 개별지수·통합대기환경지수·국내 대기환경기준·경보제도를 서로 바꾸어 쓰지 않도록 했다.
- 오존의 눈·코·목·호흡·가슴 불편은 농도만으로 자동 예측하지 않고 사용자의 직접기록으로 처리하며, 공통 농도별 체감표를 만들지 않는다.
- 사용자 의견이 필요한 다음 작업은 5-9-2 `감각만으로 오존 농도를 판단하기 어려움` 문구 3종이다.

### 5-9 오존 감각판단 문구 수정

- 사용자가 5-9-2 첫 문장에서 `바로`를 빼고 `오존 농도는 몸으로 느끼기 어려울 수 있어요`로 수정했다.
- 두 번째 문구는 공기의 톡 쏘는 인상 대신 `숨 쉴 때 답답하거나 아프지 않아도 오존 농도는 높을 수 있어요`로 변경했다.
- 세 번째 `눈이나 목이 불편하지 않아도 오존 농도는 높을 수 있어요`는 유지했다.
- 호흡·눈·목의 불편이 없다는 느낌도 낮은 오존 농도나 안전의 근거로 사용하지 않으며 5-9-2는 사용자 최종 확정 전이다.

### 5-9 확정 및 5-10 오존 야외활동 호흡부담 문구 권장안

- 사용자가 수정된 5-9-2 감각만으로 오존 농도를 판단하기 어려움 문구 3종을 확정해 채택 상태로 변경했다.
- 5-10의 공식 오존 예보·측정·활성 경보 행동요령, 활동 조정, 실제 가능한 실내 대안, 출발 전 재확인, 직접기록과 자료상태 문구는 자동 채택했다.
- 앱이 `장시간·무리한 활동`을 임의의 분·속도 기준으로 바꾸지 않고 좋음을 안전, 나쁨을 모든 야외활동 금지로 해석하지 않도록 했다.
- 눈·목·가슴 불편과 기침·쌕쌕거림은 직접기록으로만 표시한다. 호흡·활동 부담은 공식 나쁨 이상 또는 활성 경보, 같은 시간의 부담 있는 야외활동, 사용자 확인 민감군이나 같은 조건의 과거 직접반응이 함께 있을 때만 가능성 문구를 만든다.
- 사용자 의견이 필요한 다음 작업은 5-10-2 `오존 야외활동 중 호흡 부담` 체감문구 3종이다.

### 5-10 확정 및 5-11 대기정체 답답함 문구 권장안

- 사용자가 5-10-2 오존 야외활동 중 호흡 부담 체감문구 3종을 확정해 채택 상태로 변경했다.
- 5-11의 공식 대기정체지수·공식 원인분석, 내부 오염축적 가능성, 실제 시야 현상, 사용자 직접기록, 원인 불확실성과 자료상태 문구는 자동 채택했다.
- 정체지수만으로 오염농도·고농도·개인피해·환기 금지를 만들지 않고 공식 지수와 오염자료의 지역·시간이 일치할 때만 함께 판단하도록 했다.
- 뿌연 시야는 실제 현상 가능성, 냄새 잔류와 무풍 느낌은 직접기록, 끈적함·눅눅함은 습도 체감으로 처리한다.
- 사용자 의견이 필요한 다음 작업은 5-11-2 `공기가 갇힌 듯한 답답함` 체감문구 3종이다.

### 5-11 확정, 5-12 자동채택 및 5-13 꽃가루 감각문구 권장안

- 사용자가 5-11-2 대기 정체와 함께 나타나는 공기의 답답함 문구 3종을 확정해 채택 상태로 변경했다.
- 5-12 환기 가능 대기질은 외기 유입부담, 실내 공기교환 필요 맥락, 환기방법 적합성을 분리하고 공식 안내·직접기록·자료상태 문구를 자동 채택했다.
- 환기 전후의 퀴퀴함·답답함·냄새·산뜻함·찬바람·건조함·매캐함은 직접기록으로만 표시하므로 새 체감문구 3종을 만들지 않았다.
- 5-13의 기상청 꽃가루농도위험지수 수종군·공식 4단계·대응요령, 예측/달력/실측 분리, 감작 수종과 노출시간의 개인화, 직접기록과 원인 불확실성 문구를 자동 채택했다.
- 구체적인 코·눈·목·호흡·피부 불편은 직접기록으로 처리하고 감각으로 수종·농도·공식 단계를 역산하지 않도록 했다.
- 사용자 의견이 필요한 다음 작업은 5-13-2 `감각만으로 꽃가루 노출을 판단하기 어려움` 문구 3종이다.

### 5-13 꽃가루 감각판단 확정 및 코 간질거림 문구 권장안

- 사용자가 5-13-2 감각만으로 꽃가루 노출을 판단하기 어려움 문구 3종을 확정해 채택 상태로 변경했다.
- 일반 사용자에게 공식 꽃가루 단계만으로 코·눈·목·피부 증상을 자동 예측하지 않는 원칙은 유지했다.
- 확인된 감작 수종군, 공식 높음·매우높음, 같은 시간의 야외활동 또는 창문개방, 같은 조건의 반복 체감기록이 모두 있을 때만 구체적인 개인화 체감문구를 만들도록 했다.
- 사용자 의견이 필요한 다음 작업은 5-13-3a `코끝·콧속의 간질거림` 체감문구 3종이다.

### 5-13 코 간질거림 확정 및 눈 가려움 문구 권장안

- 사용자가 5-13-3a 꽃가루 노출 때 코끝·콧속의 간질거림 체감문구 3종을 확정해 채택 상태로 변경했다.
- 다음 개인화 체감은 코와 구분한 눈의 가려움으로 정하고 같은 감작·공식단계·노출·반복기록 조건을 적용했다.
- 현재 직접입력은 예측문구로 바꾸지 않고 기록사실로 표시한다.
- 사용자 의견이 필요한 다음 작업은 5-13-3b `눈의 가려움` 체감문구 3종이다.

### 5-13 눈 가려움 확정 및 목 간질거림 문구 권장안

- 사용자가 5-13-3b 꽃가루 노출 때 눈의 가려움 체감문구 3종을 확정해 채택 상태로 변경했다.
- 다음 개인화 체감은 코·눈과 구분한 목 안쪽의 간질거림으로 정하고 같은 감작·공식단계·노출·반복기록 조건을 적용했다.
- 입천장·귀의 가려움과 기침·호흡 불편은 목 간질거림 문구에 섞지 않고 직접기록으로 분리한다.
- 사용자 의견이 필요한 다음 작업은 5-13-3c `목 안쪽의 간질거림` 체감문구 3종이다.

### 5-13 목 간질거림 확정 및 피부 가려움 문구 권장안

- 사용자가 5-13-3c 꽃가루 노출 때 목 안쪽의 간질거림 체감문구 3종을 확정해 채택 상태로 변경했다.
- 다음 개인화 체감은 노출된 피부의 가려움으로 정하고 같은 감작·공식단계·노출·반복기록 조건을 적용했다.
- 피부 붉어짐·붓기는 주관적 느낌이 아닌 실제 현상으로 직접기록하며 가려움 문구에 섞지 않는다.
- 사용자 의견이 필요한 다음 작업은 5-13-3d `노출된 피부의 가려움` 체감문구 3종이다.

### 5-13 완료, 5-14·6-1~6-4 자동채택 및 수분상태 감각문구 권장안

- 사용자가 5-13-3d 꽃가루 노출 때 노출된 피부의 가려움 체감문구 3종을 확정해 채택 상태로 변경했다.
- 꽃가루의 붉어짐·붓기·호흡 불편은 실제 현상·직접기록과 개인 행동계획으로 처리해 추가 체감기준을 만들지 않았다.
- 5-14 호흡기질환자 행동은 5-7·5-10의 호흡·활동 부담 문구를 재사용하고 공식 환경정보·직접기록·보호자 관찰·개인계획 문구를 자동 채택했다.
- 6-1 우산, 6-2 양산, 6-3 선크림, 6-4 마스크 준비는 앞서 채택한 강수·바람·자외선·제품 체감문구를 재사용하도록 자동 채택했다.
- 6-5 물·수분 보충의 공식 건강수칙, 준비·접근 가능성, 직접 섭취기록, 개인 수분계획과 의식저하 응급행동을 자동 채택했다.
- 사용자 의견이 필요한 다음 작업은 6-5-2 `갈증·마름만으로 수분 상태 판단 어려움` 문구 3종이다.

### 6-5 확정, 6-6~6-19 자동채택 및 수면환경 끈적함 문구 권장안

- 사용자가 6-5-2 갈증·마름만으로 수분 상태를 판단하기 어려움 문구 3종을 확정해 채택 상태로 변경했다.
- 6-6 겉옷은 기존 한랭·바람 체감, 6-7~6-9 빨래는 강수·눈·바람·습도와 직접 마름기록, 6-10 우산 건조는 직접 젖음·마름기록을 재사용해 자동 채택했다.
- 6-11 환기와 6-12 창문 닫기는 기존 외기유입·실내공기·온습도·바람 체감을 재사용해 자동 채택했다.
- 6-13~6-19 외출·운동·반려견 산책·출퇴근·보행·운전·세차·행사는 공식정보와 실제 일정·경로·대안을 결합하고 영향은 사건 가능성으로 표시하므로 새 체감기준을 만들지 않았다.
- 6-20 수면환경의 공식 열대야·밤 날씨, 침실 측정, 실제 수면창, 냉난방·침구, 직접기록과 자료상태 문구를 자동 채택했다.
- 사용자 의견이 필요한 다음 작업은 6-20-2a `피부와 이불이 달라붙는 끈적함` 체감문구 3종이다.

### 6-20 침실 끈적함 확정 및 이불 속 열감 문구 권장안

- 사용자가 6-20-2a 덥고 습한 침실에서 피부와 이불이 달라붙는 끈적함 체감문구 3종을 확정해 채택 상태로 변경했다.
- 다음 체감은 침실 전체의 덥고 습함과 구분한 이불 속에 머무는 열로 인한 후끈함·답답함으로 정했다.
- 이불 속 측정 또는 두꺼운 침구·온돌·동침 맥락과 사용자의 평소기준·직접/반복기록이 있을 때만 가능성 문구를 만들며, 침실 평균온도만으로 이불 속 열감을 생성하지 않는다.
- 사용자 의견이 필요한 다음 작업은 6-20-2b `이불 속에 머무는 열로 인한 후끈함·답답함` 체감문구 3종이다.

### 6-20 이불 속 열감 확정 및 손발 냉감 문구 권장안

- 사용자가 6-20-2b 이불 속에 머무는 열로 인한 후끈함·답답함 체감문구 3종을 확정해 채택 상태로 변경했다.
- 다음 체감은 더운 침구와 구분한 잠자리에서 손발이 시린 냉감으로 정했다.
- 같은 수면시간의 낮은 침실온도 또는 몸에 직접 닿는 기류와 평소 손발시림·직접/반복기록 또는 얇은 침구 맥락이 있을 때만 가능성 문구를 만든다.
- 외기온만으로 침실 냉감이나 손발시림을 생성하지 않는다.
- 사용자 의견이 필요한 다음 작업은 6-20-2c `잠자리에서 손발이 시린 냉감` 체감문구 3종이다.

### 6-20 현재 앱의 침실자료 부재 확인

- 사용자가 자외선·미세먼지와 달리 이불 체감이 나온 이유와 실제 침실온도 확인방법을 질문했다.
- 현재 앱·서버에는 침실 온습도계, 스마트홈, 블루투스 또는 IoT 센서를 연동하는 기능이 확인되지 않았다.
- 현행 서버의 `SLEEP_DISCOMFORT_EXPECTED`는 침실 측정이 아니라 야간 외부 날씨 스냅샷에서 기온 `25℃ 이상`·습도 `75% 이상`이 3구간 이어질 때 생성되며, 템플릿은 이를 바탕으로 실내 온습도 조절과 이불 준비를 안내한다.
- 따라서 6-20-2a~2c의 이불·손발 체감은 현재 앱이 자동 생성할 근거가 없으며, 실내 센서 연동이나 사용자 직접입력 기능을 별도로 만들지 않는 한 현행 범위에서 제외하는 것이 권장된다.
- 현재 앱의 수면환경은 외부 밤 예보를 공식 사실로 표시하고 `잠들기 전에 침실 상태를 확인하고 필요하면 냉방이나 제습으로 조절하세요`처럼 확인행동을 안내하는 범위가 적절하다. 실내 체감이나 수면결과는 확정·예측하지 않는다.
- 다음 진행 전 6-20-2a~2c를 현행 정책에서 제외할지 사용자 결정을 받아야 한다.

## 2026-09-01 입력할 수 없는 생활상태 전수 정리

- 사용자가 6-20 이불·침실 체감뿐 아니라 앞서 정한 전 항목에서 현재 앱이 알 수 없는 상태를 찾아 삭제하도록 요청했다.
- 실제 앱 입력을 `선택 위치`, `알림 시각·종류 설정`, 위치·시간으로 조회 가능한 공식 기상·대기·재난·도로 자료로 한정했다.
- 현행 정책에서 다음 의존성을 삭제했다.
  - 침실·실내 온습도와 침구·냉난방·가습·제습 상태를 이용한 판정
  - 사용자 일정·출발시각·이용경로·활동장소·행동완료를 전제로 한 개인화
  - 창문·빨래·우산·마스크·차량·배관의 보유·사용·현재 상태를 안다고 가정한 문구
  - 질환·민감군·복용약·의료진 계획, 반려견의 품종·건강·행동기록을 이용한 개인판정
  - 마스크 착용감, 꽃가루 개인증상, 수분상태, 침실·이불·손발 냉감처럼 직접입력·센서·반복기록이 있어야 하는 체감기준
- `docs/항목별_문구_표현_기준.md`는 공통 데이터 경계를 명시하고, 삭제 대상이던 세부 개인화 정책을 공개자료 기반 공식 사실·내부 가능성·조건부 일반행동으로 정리했다. 수면환경에는 체감문구 3종을 두지 않는다.
- `docs/수치_기준_근거자료_선정_항목.md`도 같은 입력 제한을 적용하고, 개인 상태가 필요한 수치기준·상태코드·가중치·자동알림을 사용하지 않도록 정리했다.
- 생활행동은 `외출한다면`, `실외 빨래가 있다면`, `반려견과 산책할 계획이라면`처럼 확인되지 않은 상태를 문장 안에서 조건으로 밝힐 때만 허용한다.
- 앞서 확정했지만 문구 기준서에서 빠졌던 양산 사용 때의 눈부심 감소 체감문구 3종을 5-4-2에 복원했다. 양산을 실제 사용했다고 판단하지 않고 조건부 일반효과로만 사용한다.
- 검증 결과 두 기준서에서 `USER_PLAN`, `userPlanRef`, 직접·반복기록 기반 체감분기, 빈 표와 삭제된 침실·이불 체감문구가 남지 않았다. `git diff --check`는 줄바꿈 변환 경고 외 오류가 없다.
- 제품 코드는 이번 문구 정책 정리 범위에서 변경하지 않았다. 서버에는 아직 외부 야간 기온·습도로 `SLEEP_DISCOMFORT_EXPECTED`를 생성하고 `얇은 이불`을 안내하는 기존 구현이 남아 있다. 구현 반영 단계에서 `weather_care_server/src/rules/weatherRuleEngine.ts`, `weather_care_server/src/lifestyle/lifestyleBuilder.ts`, `weather_care_server/src/lifestyle/lifestyleTemplates.ts`, `weather_care_server/src/types.ts`와 관련 테스트를 함께 제거·정리해야 한다.

## 2026-09-01 확정 문구 정책 제품 반영 완료

- 입력으로 확인할 수 없는 침실·침구·차량·개인 일정·경로·행동 완료 상태를 전제로 한 서버 판정과 기본 생활 할 일을 제거했다.
- 생활 문구 응답을 `추천 행동 → 내부 영향 가능성/앱 계산 → 공식 사실 → 자료 상태` 역할 순서로 구조화했다. 앱 메인에서는 추천 행동을 먼저 보여주고 상세에서 같은 순서의 근거를 확인할 수 있게 했다.
- 공식 예보·측정값은 확정형으로 표시하고, 앱 내부 영향은 가능성형으로 표시한다. 사용자 화면에서 `TMP`, `AWS`, `신적설` 같은 원자료 용어와 앱이 만든 `안전·주의·위험` 단계를 제거했다.
- 시간당 비 `3·5·15·30·50mm/h` 구간과 시간당 적설 `0.5·1.5·3cm/h` 구간의 승인 생활영향 3종, 자외선·미세먼지 직접 감각판단 어려움 3종, 고온다습 체감 3종을 서버 선택 문구로 구현했다.
- 풍속은 `0·4·9·14m/s` 공식 표현, 자외선과 미세먼지는 기관 공식 등급을 앱에 표시한다. 비·눈의 `미만·범위·이상` 표기는 앱 모델과 직접 기상청 조회에서도 보존한다.
- 현재 기온처럼 보이던 단기예보값은 `오후 3시 예상기온` 형식으로 표시한다. 기상청 예보 입력을 사용한 체감온도는 앱 계산값으로 구분하고 계산조건이 맞지 않으면 실제 기온을 체감온도로 복사하지 않는다.
- 침실 상태나 수면결과는 판단하지 않는다. 밤 실외 기온 `25℃ 이상`과 습도 `75% 이상`이 3개 시간구간 연속 예보될 때만 취침 전 침실 상태를 직접 확인하라는 조건부 행동을 만든다.
- 같은 대상시각·자료 역할·공간·체감온도 산식을 검증할 수 없는 기존 어제·작년 비교는 화면에서 제거하고 서버 API도 `COMPARISON_PROVENANCE_UNAVAILABLE`로 비활성화했다. 단기예보값을 관측 이력처럼 저장하던 동작도 중단했다.
- 현재 Provider에 없는 노면온도·노면수분·도로살얼음 관측, 공식 도로통제·우회로, 실제 발효 특보는 자체 생성하지 않는다. 따라서 블랙아이스(도로살얼음) 발생과 특정 출퇴근 경로는 공식 자료가 연결될 때까지 사용자 사실로 표시하지 않는다.
- 커밋은 `bfbde04` 문구 정책 정리, `a014748` 근거 없는 생활상태 판정 제거, `6a74d0b` 서버 역할별 문구·기준, `f2cfe4f` 검증 불가 비교 차단, `35a53a6` 앱 행동 우선 표시, `accb666` 야간 확인조건 근거값 정합화, `af6ecd2` 앱의 검증 불가 비교 조회 제거 순으로 분리했다.
- 검증: 서버 `npx tsc --noEmit`, 서버 Vitest `9 files / 36 tests`, 앱 `flutter analyze`, 앱 `flutter test` `30 tests`가 모두 통과했다.
- 사용자 소유의 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-01 현재 위치 500m 강수 일치 판정 구현

- GPS 모드와 위치 권한이 모두 유효할 때 앱이 현재 위·경도를 Today API와 설치정보에 전달하도록 foreground 위치 조회를 연결했다. MANUAL 모드 또는 권한·위치서비스 미사용 때는 좌표를 보내지 않는다.
- 기상청 API허브의 고해상도 관측분석 `rn_ox`와 레이더 HSR를 같은 5분 기준시각으로 조회하는 Provider를 추가했다. WGS84 타원체 Lambert 정각원추도법으로 사용자 좌표를 공식 500m 레이더 셀에 매핑하며 기존 526개 관측지점 매핑과 전부 일치함을 확인했다.
- 관측분석과 레이더가 모두 강수를 나타낼 때만 `비가 내리고 있을 수 있어요` 상태와 `지금 외출한다면 우산을 챙기세요` 행동을 노출한다. 한 자료만 강수이거나 자료가 없으면 판정을 보류하고 출처 괄호는 본문에 붙이지 않는다.
- 설치별 현재 강수 상태를 D1에 저장해 같은 비가 계속되는 동안 푸시를 반복하지 않고, 두 자료가 모두 무강수로 바뀐 후 다시 일치 강수가 확인될 때 새 알림을 허용한다. 우산 또는 소나기·약한 비 알림이 꺼져 있으면 푸시하지 않는다.
- `0003_precise_precipitation_location.sql`을 로컬 D1에 적용했다. 운영 전 원격 D1 migration과 API허브 고해상도 격자자료·레이더 활용 권한이 있는 `KMA_APIHUB_KEY` 등록이 필요하다.
- 검증: 서버 TypeScript 검사, Vitest `14 files / 52 tests`, 앱 분석·테스트 `33 tests`, Android debug APK 빌드를 통과했다.
- 사용자 소유의 미추적 `scripts/*` 강수분석 파일과 `tmp/` 자료는 수정하거나 커밋하지 않았다.

## 2026-09-01 실제 발효 기상특보 연동 구현

- 기상청 API허브 특보현황을 발효시각 기준으로 조회하고, 공식 코드의 예비특보(`LVL=1`)·해제 명령·아직 발효되지 않은 자료는 화면과 알림에서 제외했다. 주의보(`LVL=2`)와 경보(`LVL=3`) 중 실제 발효된 자료만 사용한다.
- 수원은 특보구역 `L1011900`, 서울 기본 격자의 종로구는 서울서북권 `L1100400`에 연결했다. Today 응답의 `current.activeWarnings`와 생활문구에 현재 발효 특보를 포함한다.
- 특보 문구는 `직접행동 → 공식 발효 사실` 순서로 노출한다. 공식 사실은 `수원에는 호우경보가 발효 중이에요`처럼 확정형으로 표시한다.
- 설치별 특보 상태를 `installation_warning_state`에 저장하고, 신규 발효·주의보/경보 변경·해제 때만 FCM을 보낸다. 호우·대설·폭염·한파는 각 사용자 알림 설정을 적용하며, 발송 실패 때는 상태를 확정하지 않아 다음 Cron에서 다시 시도할 수 있다.
- `0004_official_warning_state.sql`을 추가했다. 운영 전 원격 D1 migration과 `KMA_APIHUB_KEY`에 기상특보 API 활용 권한이 필요하다.
- 검증: 서버 TypeScript 검사와 Vitest `16 files / 58 tests`를 통과했다. 예비특보·미발효·타 지역·해제행 제외, 발효시각 조회, 알 수 없는 응답에서 해제로 오판하지 않는 방어, 행동 우선 노출, 신규/변경/해제 중복 방지를 테스트했다.
- 사용자 소유의 미추적 `scripts/*` 강수분석 파일과 `tmp/` 자료는 수정하거나 커밋하지 않았다.

## 2026-09-01 블랙아이스(도로살얼음) 공식 단계 연동 구현

- 기상청 API허브 도로위험기상정보 ZIP에서 1km 도로살얼음 파일을 해제·검증하는 Provider를 추가했다. 현재 위치 3km 안의 지원 고속도로 구간 중 가장 높은 공식 단계를 선택한다.
- 최신 공식 파일 포맷에 따라 `B_ICE=0`을 안전이 아닌 `정보없음`으로 바로잡았다. 사용자에게는 `관심 1·주의 2·위험 3`만 표시하며, 공식 발생 가능 단계를 실제 발생·관측으로 표현하지 않는다.
- 앱에 `블랙아이스(도로살얼음)` 전용 생활항목과 아이콘을 추가했다. 행동을 먼저 보여주고 `기상청은 오전 10시 영동선 수원 인근 구간의 블랙아이스(도로살얼음) 발생 가능성을 주의 2단계로 안내했어요` 같은 공식 사실을 뒤에 표시한다.
- 표준노드링크 ID, 시작·종료 좌표, 생산시각, 분석/관측 플래그를 보존한다. 공식 파일에 방향명이 없으므로 사용자용 방향을 추정하지 않는다.
- 설치별 링크·단계를 D1에 저장해 같은 상태의 푸시를 반복하지 않는다. 단계·구간이 바뀌면 다시 알리고, 해당 범위에서 벗어나면 상태를 초기화한다.
- `0005_road_ice_state.sql`을 추가했다. 운영 전 원격 D1 migration과 `KMA_APIHUB_KEY`의 도로위험기상정보 활용 권한이 필요하다.
- 원자료 PDF는 읽기 전용으로 시스템 임시 디렉터리에서 확인했으며 저장소의 사용자 `tmp/`에는 쓰지 않았다. 노면상태·노면온도와 실제 도로통제는 별도 후속 Provider가 필요하다.
- 검증: 서버 TypeScript 검사, Vitest `18 files / 63 tests`, Worker 번들 dry-run, 앱 정적분석과 Flutter `34 tests`를 통과했다. `0005`는 로컬 D1에 적용했다.

## 2026-09-01 실제 도로 통제 출퇴근 경로 연동 구현

- 국가교통정보센터 `eventInfo` 돌발상황정보 Provider를 추가했다. GPS 반경 3km 안에서 발생시각이 지났고 종료되지 않았으며 차단 차로나 통제가 명시된 자료만 현재 공식 통제로 사용한다.
- 발효 전·종료 자료와 통제 근거가 없는 단순 사고·공사는 제외한다. Provider 오류는 통제 없음으로 바꾸지 않으며 정상 응답에서 통제가 사라졌을 때만 설치 상태를 초기화한다.
- `출퇴근 경로` 생활항목을 서버와 Flutter에 추가했다. 전면 통제는 `○○도로 전면 통제가 시행 중이니, 출발 전에 다른 경로와 대중교통 운행정보를 확인하세요`, 일부 차로 통제는 교통정보 확인 행동을 공식 사실보다 먼저 표시한다.
- 공식 API에는 우회도로 필드가 없으므로 특정 우회도로명을 추정하지 않는다. 사용자 경로도 저장하지 않으므로 해당 통제가 실제 출퇴근 경로에 있다고 표현하지 않는다.
- 설치별 사건키·전면/일부 상태를 D1에 저장해 같은 통제 푸시를 반복하지 않는다. `0006_road_control_state.sql`을 로컬 D1에 적용했다.
- 운영 전 국가교통정보센터 돌발상황정보 Open API 활용승인, Worker `ITS_API_KEY` secret 등록, 원격 D1 migration과 재배포가 필요하다. 활용신청이나 운영 배포는 수행하지 않았다.
- 검증: 서버 TypeScript 검사, Vitest `20 files / 69 tests`, Worker 번들 dry-run, 앱 정적분석과 Flutter `35 tests`를 통과했다.
- 확인에 사용한 공식 Open API 매뉴얼 임시 PDF는 삭제했다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-01 기준별 체감문구와 오존 생활안내 구현

- 확정된 온열감 3단계, 고온다습, 한랭감 5단계, 자외선 직접판단 한계, 양산의 눈부심·열감 감소, 미세먼지·초미세먼지 직접판단 한계, 오존 직접판단 한계를 중앙 체감문구 카탈로그로 옮겼다. 각 체감기준은 서로 다른 문구를 정확히 3종씩 보존한다.
- 현재 입력으로 근거가 있는 고온다습·자외선·양산·미세먼지·오존 문구만 자동 선택한다. 국내 사람 대상 수치 연결이 확정되지 않은 한국어 온열감·한랭감 단계는 카탈로그에 보존하되 기상청 체감온도 값만으로 자동 배정하지 않는다.
- 에어코리아 측정소의 오존 `나쁨·매우 나쁨` 등급 또는 `0.091ppm 이상`을 오존 생활안내에 연결했다. 화면에는 `직접행동 → 감각판단 어려움 → 측정시각·측정소·농도·등급의 공식 사실` 순으로 표시한다.
- 앱에 `오존` 생활항목과 전용 API 매핑·아이콘을 추가했다. 농도만으로 눈·목·호흡 증상이나 실제 야외활동 여부를 추정하지 않는다.
- 검증: 서버 TypeScript 검사, Vitest `20 files / 72 tests`, Worker 번들 dry-run, 앱 정적분석과 Flutter `36 tests`를 통과했다.
- 운영 배포나 원격 설정 변경은 수행하지 않았다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-01 운영 Worker Secret 등록

- Cloudflare 운영 Worker `weather-care-server`에 필요한 Secret 5종 `KMA_SERVICE_KEY`, `KMA_APIHUB_KEY`, `ITS_API_KEY`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`가 등록된 것을 이름 목록으로 확인했다.
- 기상청 API허브 인증키와 국가교통정보센터 인증키는 대화·명령 인자·저장소에 기록하지 않고 Wrangler의 Secret 입력으로 등록했다.
- Firebase 프로젝트 `weather-care-2aaa8`의 서비스 계정 JSON에서 `client_email`과 `private_key`만 메모리에서 읽어 운영 Secret으로 전달했으며 실제 값은 출력하지 않았다.
- 다운로드된 서비스 계정 JSON 원본은 사용자 승인 없이 삭제하거나 이동하지 않았다. 다음 운영 단계는 원격 D1 백업 후 `0002`~`0006` 마이그레이션 적용이다.

## 2026-09-01 운영 D1 마이그레이션 전 백업

- 원격 D1 `weather_care_db`를 변경하기 전에 Wrangler export로 SQL 백업을 생성했다.
- 백업 파일: `C:\Users\idp20\Documents\weather-care-backups\weather_care_db_20260901_153556.sql`
- 파일 크기: `6,873 bytes`
- SHA-256: `07EFDFEDBC48C74E87F7A6CE2A6A5527D0A86C702D07378E6990D4935FDA0AEA`
- 실제 레코드를 출력하지 않고 `CREATE TABLE` 7개와 `INSERT INTO` 6개가 포함된 것을 확인했다.
- 이번 단계에서는 원격 D1을 수정하지 않았다. 다음 운영 단계는 백업을 복구 기준점으로 삼아 `0002`~`0006` 마이그레이션을 원격 D1에 적용하는 것이다.

## 2026-09-01 운영 D1 마이그레이션 적용

- 사전 백업을 확인한 뒤 원격 D1 `weather_care_db`에 `0002_notification_preferences.sql`부터 `0006_road_control_state.sql`까지 5개 migration을 순서대로 적용했다.
- 적용 후 원격 migration 목록은 `0001`~`0006`까지 연속이며 대기 항목은 0개다.
- 원격 스키마에서 `installation_warning_state` 테이블, 알림 설정 열 4개, 현재 강수·도로살얼음·도로통제 상태 열 10개가 생성된 것을 읽기 전용 조회로 확인했다.
- 기존 레코드 내용은 조회하거나 변경하지 않았다. 적용 전 복구 기준점은 `C:\Users\idp20\Documents\weather-care-backups\weather_care_db_20260901_153556.sql`이다.
- 다음 운영 단계는 최신 Worker를 dry-run으로 검증한 뒤 운영 배포하는 것이다.

## 2026-09-01 최신 Worker 운영 배포

- 추적된 최신 서버 코드에서 `npx tsc --noEmit`, Vitest `20 files / 72 tests`, `npx wrangler deploy --dry-run`을 통과했다.
- 로컬 테스트에서는 운영 Secret 4종이 `.dev.vars`에 없다는 경고가 있었지만 테스트는 모두 통과했다. 운영 Worker에는 `KMA_SERVICE_KEY`, `KMA_APIHUB_KEY`, `ITS_API_KEY`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` 5종이 등록된 것을 이름 목록으로 재확인했다.
- Worker `weather-care-server`를 `https://weather-care-server.sy40222.workers.dev`에 배포했다. 활성 버전은 `c8f32083-d379-415e-92f8-5cf35701cd78`이며 100% 트래픽이 연결됐다.
- 배포된 Worker의 시작 시간은 16ms이며 D1 `weather_care_db`, `FCM_PROJECT_ID`, 10분 주기 `*/10 * * * *` Cron이 연결됐다.
- 배포 직후 `/`와 `/health`가 각각 HTTP 200을 반환했다. 전체 Today·설정·설치·알림 관련 운영 API 검증은 다음 단계에서 수행한다.

## 2026-09-01 운영 API 스모크 테스트

- 운영 Worker의 `/`, `/health`, 수원 Today, Weekly, 어제·작년 비교 API가 모두 HTTP 200을 반환했다. Today는 수원 48시간 예보와 판단·문구 버전을, Weekly는 기상청 단기예보 범위 4일을 반환했다. 검증 불가 비교는 `COMPARISON_PROVENANCE_UNAVAILABLE`로 비활성화됐다.
- 고유 임시 ID `codex-smoke-20260901-1620-a91f4c2e`로 설치 등록, 기본 알림설정 조회, 독립 알림설정 PUT, 설치 하위 알림설정 PUT, 설정 재조회, 설치 ID가 포함된 Today 호출을 검증했다. `fcm_token`은 `NULL`, 전체 알림은 비활성화해 푸시 가능성을 차단했다.
- 원격 D1에서 좌표·격자·위치모드와 확장 알림설정 값이 실제 저장된 것을 읽기 전용으로 확인했다. 테스트 뒤 해당 ID의 설치·알림설정 2행과 연결 가능 상태·이력만 삭제했으며 4개 대상 테이블의 잔여 건수는 모두 0이다. 기존 사용자 데이터는 변경하지 않았다.
- 설치 ID 누락, 위·경도 한쪽 누락, 잘못된 알림시각은 각각 HTTP 400과 계약된 오류코드를 반환했다.
- 자외선은 캐시 자료, 에어코리아 대기질은 최초 일시적 `UNAVAILABLE` 뒤 재조회에서 `CACHED`로 복구됐다. 도로살얼음은 Provider 오류 로그 없이 현재 해당 단계가 없는 상태로 응답했다.
- 좌표 포함 Today 요청의 운영 로그에서 `KMA_WARNING_STATUS`, `KMA_ANALYSIS_RADAR`, `ITS_EVENT_INFO` Provider 실패를 확인했다. Today는 보조자료 실패를 격리해 HTTP 200을 유지하지만 기상특보·현재 강수 일치판정·도로통제는 정상 연동된 것으로 볼 수 없다.
- 다음 작업은 Secret 값을 노출하지 않는 범위에서 세 Provider의 오류 사유를 식별할 수 있도록 진단정보를 보강하고, 활용승인·요청 형식·응답 파싱 중 실제 원인을 확인하는 것이다. 이 문제가 해결되기 전에는 전체 운영 스모크를 성공으로 확정하지 않는다.

## 2026-09-01 운영 Provider 진단 및 KMA 복구

- 외부 Provider 오류 로그를 Secret·요청 URL·좌표·원문 응답 없이 `failureReason`, `operation`, 허용 목록의 `detail`만 남기도록 보강했다. 임의 문자열은 세부 진단값으로 기록되지 않는다.
- 기상청 특보현황 파서가 공식 명령코드 `변경(6)`을 발효 상태로 처리하고 `변경해제(7)` 같은 해제성 명령은 제외하도록 수정했다. 선택 지역 행은 엄격히 검증하되 타 지역의 확장 열은 전체 조회 실패로 전파하지 않는다.
- HTTP 200 본문으로 전달되는 API허브 오류 봉투를 실제 자료행과 구분한다. 500m 관측분석 ASCII 행의 `=` 종료표시는 값에서 제외하고, 결측·비이진·문자 값을 고정 진단코드로 구분한다.
- 최종 운영 Worker 버전은 `dfbae6a9-47a5-476c-b360-57be306f8be5`이며 `https://weather-care-server.sy40222.workers.dev`에 100% 배포됐다. 시작 시간은 14ms이고 기존 D1·Secret·10분 Cron 연결을 유지했다.
- 수원 좌표 Today 운영 재검증에서 HTTP 200, 48시간 예보, 기상특보 Provider 정상 완료를 확인했다. 현재 발효된 수원 특보는 0건이었다.
- 같은 요청에서 현재 강수 관측은 정상 반환됐다. 관측시각 오후 4시 30분에 관측분석과 레이더가 일치하지 않아 상태는 `MISMATCH`였으며, 확정 정책에 따라 현재 비 알림은 노출하지 않았다.
- 국가교통정보센터 `https://openapi.its.go.kr:9443/eventInfo`는 한국 로컬 환경에서 공식 샘플 키로 HTTP 200과 정상 XML 응답을 반환했지만, 운영 Worker에서는 HTTP 응답 이전 네트워크 단계에서 `ROAD_CONTROL_FETCH_FAILED`가 반복됐다. Worker 호환 날짜 `2026-08-11`은 사용자 지정 포트를 지원하므로 요청 포트 설정 누락은 아니다.
- ITS 운영 실패는 파싱·인증 문제가 아니라 Worker 실행망에서 공식 9443 호스트로 나가는 연결 경로 문제다. 외부 프록시에 인증키를 전달하는 임시 우회는 적용하지 않았다. 다음 작업은 국가교통정보센터가 제공하는 표준 443 대체 API가 확인되면 교체하거나, 한국 리전의 신뢰 가능한 중계 실행환경을 별도로 마련하는 것이다.
- 검증: 서버 TypeScript 검사, Vitest `21 files / 83 tests`, Worker 번들 dry-run을 통과했다. 로컬 `.dev.vars`에 운영 전용 Secret 4종이 없다는 테스트 경고는 기존과 같고 운영 Secret 등록 상태와는 무관하다.
- 관련 커밋: `dd16f2f` 안전 진단 기반, `99a7875` 특보 명령·세부진단, `3d0b766` API허브 오류 구분, `3cf7020` 타 지역 특보행 격리, `9b9f870` 강수 ASCII 종료표시 제외.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다. 공식 ITS 매뉴얼 확인용 시스템 임시 파일은 확인 후 삭제했다.

## 2026-09-09 ITS 홈서버 중계 운영 연동 완료

- Cloudflare Worker에서 국가교통정보센터 `openapi.its.go.kr:9443`로 직접 연결하지 않고, 한국 가정망의 Ubuntu 서버를 거치는 전용 HTTPS 중계를 추가했다. 중계는 좌표 경계만 받으며 ITS 인증키는 Ubuntu에만 보관한다.
- 중계 서비스는 `weather_care_relay`에 별도 Node.js TypeScript 프로젝트로 구현했다. `GET /health`와 Bearer 인증이 필요한 `POST /v1/its/event-info`만 제공하고, 대한민국 범위·요청 크기·응답 크기·상류 시간제한을 검증한다.
- Ubuntu `soha-01`에는 검증한 Node.js `24.15.0`을 `/opt/node-v24.15.0-linux-x64`에 설치했다. 애플리케이션은 `/opt/weather-care-relay/dist`, 비밀환경은 `/etc/weather-care-relay.env`, systemd 단위는 `/etc/systemd/system/weather-care-relay.service`에 배치했다.
- `weather-care-relay` systemd 서비스는 `active`·`enabled` 상태이며, Tailscale Funnel `https://soha-01.tail82e8fe.ts.net`이 `127.0.0.1:8788`로 연결된다. 로컬 health와 Funnel을 통한 인증·ITS 전체 왕복이 HTTP 200으로 확인됐다.
- Worker에는 `ITS_RELAY_URL`, `ITS_RELAY_TOKEN`을 Secret으로 등록했다. 교통 Provider는 두 값이 모두 있으면 중계를 우선 사용하고, 기존 `ITS_API_KEY` 직접 연결은 선택적 비상 호환 경로로만 남겼다.
- Funnel 활성화 직후 Tailscale 공개 DNS 전파 전의 부정 응답이 Cloudflare에 남아 일시적인 연결 실패가 있었다. 전파 후 비밀값을 다시 맞추고 Worker를 재배포했다.
- 교통 Provider만 전역 `fetch`를 객체 메서드로 저장해 Cloudflare 런타임에서 잘못된 수신자로 호출하던 문제를 수정했다. 전역 래퍼를 사용하도록 바꾸고 호출 문맥 회귀 테스트를 추가했다.
- 최종 운영 Worker 버전은 `6c7be553-9180-4414-b59f-58e362734e64`이다. 수원 좌표 Today API가 HTTP 200으로 응답했고, 같은 실행의 운영 로그에 `road_control_provider_failed`가 없음을 확인했다. 현재 반경에는 통제정보가 없어 `currentRoadControl`이 생략되는 것이 정상이다.
- 검증: 중계 Vitest `5 tests`, Ubuntu 배포 스모크 테스트 `ITS_RELAY_OK`, 서버 TypeScript 검사, 서버 Vitest `21 files / 87 tests`, Worker 번들 dry-run, 공개 중계 왕복과 운영 Today 호출을 통과했다.
- 관련 커밋: `0efdc8c` 중계 서비스, `a230951` Worker 중계 경로, `806e46a` Ubuntu 실행·점검, `a207a54` Worker fetch 호출 문맥 수정.
- 임시 진단 Worker `weather-care-relay-probe`와 서버 설치용 `/tmp/weather-care-*` 파일은 확인 후 삭제했다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-09 전국 위치·ITS 운영 검증 및 호출량 절감

- 서울·인천·대전·대구·부산·광주·강릉·제주 좌표로 운영 Today API를 검증했다. 8개 요청 모두 HTTP 200과 48시간 예보를 반환했고, 중계 캐시 적용 후 동시 재검증에서도 `road_control_provider_failed`가 발생하지 않았다.
- 국가교통정보센터 전국 돌발상황 조회는 확인 시점에 336건·134,371바이트였다. 월 1,000회 한도를 보호하기 위해 Ubuntu 중계가 전국 자료를 한 번 조회해 기본 1시간 메모리 캐시로 보관하고, 각 Worker 요청에는 요청 좌표 경계의 자료만 필터링해 반환하도록 변경했다. 같은 시각의 동시 캐시 미스는 한 요청으로 합친다.
- Ubuntu `weather-care-relay`에 캐시 버전을 배포하고 systemd `active`·`enabled`, 로컬 health, Tailscale Funnel, ITS 스모크 테스트를 확인했다. 중계의 공식 오류 응답은 캐시하지 않는다.
- 서울 운영 요청에서 실제 `삼일대로` 일부 차로 통제를 현재 위치 1,767m 거리로 찾았다. 공식 사실에 시작 월·일을 포함하고 자정은 `오전 12시`가 아니라 `0시`로 표시하도록 고쳐 `국가교통정보센터는 6월 22일 0시부터 삼일대로 일부 차로 통제가 시행 중이라고 안내했어요`를 확인했다.
- Flutter 앱의 수원 고정 격자 `60,121`을 제거했다. GPS 모드에서는 실제 위·경도를 기상청 공식 5km Lambert 격자로 변환해 서버 조회·직접 기상청 대체조회·설치 알림 위치에 동일하게 사용한다. 수동 모드나 좌표를 얻지 못한 경우에는 기존 수원 기본값을 유지한다.
- GPS 좌표가 수원·서울 카탈로그 밖이면 응답 지역명을 `선택 지역` 대신 `현재 위치`로 표시한다. 공식 예보 문장에서는 사용 위치라는 전제를 반복하지 않도록 `현재 위치` 문구를 생략한다.
- 운영 Worker `https://weather-care-server.sy40222.workers.dev`의 최종 버전은 `3611b927-55f7-4755-ba79-e4e6944b81ab`이다. 서울의 실제 도로통제 문구와 부산 GPS 응답의 `region.name=현재 위치`, 48시간 예보를 배포 후 확인했다.
- 검증: 중계 Vitest `7 tests`, 앱 `flutter analyze`, Flutter `37 tests`, Android debug APK 빌드, 서버 TypeScript 검사, 서버 Vitest `22 files / 90 tests`, Worker dry-run과 운영 스모크 테스트를 통과했다.
- 관련 커밋: `f6c8b9a` 전국 ITS 캐시, `45d444f` 도로통제 날짜·자정 문구, `f3b8bcf` GPS 예보 격자, `e7cbc7b` 전국 GPS 표시, `bb02116` 알림 회귀시험 보정.
- 남은 전국화 범위: 자외선·에어코리아 측정소·기상특보 구역·도로살얼음 도로번호용 지역 메타데이터는 현재 수원·서울만 등록돼 있다. 전국 행정구역 메타데이터 또는 좌표 기반 공식 조회로 확장하기 전에는 이 보조자료를 전국 지원으로 간주하지 않는다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 전국 특보·대기질 운영 권한 승인 및 검증

- 기상청 API허브 `예특보 > 예·특보 구역정보 > AWS가 속한 특보구역 코드 조회` 활용신청을 완료했다. 별도 심의 없이 즉시 승인됐으며 기존 `KMA_APIHUB_KEY`로 전국 GPS 좌표의 특보구역 연결을 사용할 수 있다.
- 공공데이터포털의 `한국환경공단_에어코리아_측정소정보` 개발계정을 신청했다. 코드가 사용하는 `측정소 목록 조회` 기능만 선택했으며 자동 승인됐다. 승인기간은 2026-09-10부터 2028-09-10까지다.
- `한국환경공단_에어코리아_대기오염정보` 개발계정은 이미 승인 상태여서 중복 신청하지 않았다.
- 운영 Worker에서 부산 좌표는 `연산동`, 제주 좌표는 `이도동`, 인천 좌표는 `주안` 측정소를 선택해 PM10·PM2.5·오존을 반환했다. 제주와 인천의 대기질 출처 상태는 `AVAILABLE`, Today API는 HTTP 200이었다.
- 기상청 특보구역 매핑은 승인 직후 첫 제주 호출에서 10초 제한에 한 번 걸렸으나, 이어진 인천 호출에서는 `official_warning_provider_failed` 없이 정상 완료됐다. 권한 거부 응답은 재발하지 않았다.
- 검증 당시 제주·인천에 발효 중인 특보는 없어 `activeWarnings`는 빈 배열이었다. 이는 Provider 실패가 아니라 정상 조회 결과다.
- 이번 작업은 외부 API 권한과 운영 호출만 변경했으며 제품 코드는 수정하지 않았다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 알림 종류별 이동 대상 계약 구현

- FCM 데이터에 `notificationTarget`과 `notificationTopic`을 추가했다. 오전 브리핑은 앱 메인으로, 현재 강수·공식 특보·대설·도로살얼음·도로통제 알림은 실제 날씨 자료가 있는 상세 탭으로 연결한다.
- 강풍, 블랙아이스(도로살얼음), 자외선, 비와 우산 준비, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경을 포함한 항목 식별값을 앱과 서버의 공통 문자열 계약으로 마련했다. 기상특보 코드는 강풍·강수·기온·눈·대기질·더위·출퇴근·수면 관련 항목으로 구분한다.
- 앱에 허용된 대상과 항목만 해석하는 `NotificationDestination`을 추가했다. 서버가 새 필드를 보내지 않은 기존 알림은 `notificationKey`로 같은 목적지를 복원하고, 알 수 없는 값은 메인 화면으로 안전하게 돌린다.
- 추천별 임시 골격 화면에는 실제 자료가 없으므로 알림 목적지로 사용하지 않았다. 날씨 상황 알림은 현재 실제 Today 자료를 표시하는 상세 탭을 사용하며, 항목 식별값은 후속 화면 포커스 처리에 보존한다.
- 종료·백그라운드 상태의 알림 선택 이벤트와 전경 알림 표시는 아직 연결하지 않았다. 다음 작업은 앱 시작 전 수신 메시지와 백그라운드 알림 선택을 이 이동 대상 계약에 연결하는 것이다.
- 검증: 서버 TypeScript 검사, Vitest `24 files / 104 tests`, Worker 번들 dry-run, 앱 `flutter analyze`, Flutter `41 tests`를 통과했다. 운영 Worker는 앱 클릭 처리까지 완성되지 않은 중간 계약이므로 이번 단계에서 배포하지 않았다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 종료·백그라운드 알림 선택 이동 구현

- 앱이 완전히 종료된 상태에서 알림으로 시작되면 Firebase `getInitialMessage()`의 데이터를 시작 경로에 반영한다. 오전 브리핑은 메인 탭, 날씨 상황 알림은 상세 탭으로 바로 시작한다.
- 앱이 백그라운드에 있을 때 알림을 선택하면 `onMessageOpenedApp`을 수신해 종류별 이동 대상 계약을 적용한다. 기존 화면 스택을 정리하고 지정된 화면을 열어 이전 탭 상태 때문에 다른 화면이 보이지 않게 했다.
- Navigator가 아직 준비되지 않은 시작 구간에 선택 이벤트가 들어오면 목적지를 보관했다가 첫 프레임 뒤에 연다. 이동 시 `NotificationDestination`을 route arguments로 함께 전달해 관련 항목 식별값을 후속 포커스 처리에서 사용할 수 있게 했다.
- 초기 알림 확인 실패는 앱 시작 실패로 확대하지 않고 기본 메인 화면으로 시작한다. 전경 수신 알림의 화면 표시는 아직 구현하지 않았으며 다음 작업으로 남겼다.
- 검증: 앱 `flutter analyze`, Flutter `44 tests`, Android debug APK 빌드를 통과했다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 앱 전경 알림 표시 구현

- Firebase 공식 Flutter 수신 지침에 따라 `FirebaseMessaging.onMessage`를 전경 수신 경로로 연결했다. Android는 중요도 높은 `weather_care_alerts` 채널에서 로컬 알림을 표시하고, iOS는 Firebase 전경 alert·badge·sound 표시 옵션을 활성화한다.
- Android 전경 알림은 서버의 제목·본문을 그대로 사용한다. 본문이 길면 확장형 본문으로 표시하며, `notificationKey`를 안정적인 알림 ID로 변환해 같은 의미의 알림이 중복으로 쌓이지 않게 했다. 데이터 전용 메시지처럼 표시할 공식 제목·본문이 없으면 문구를 만들어내지 않는다.
- 전경 알림의 data payload를 JSON으로 보존한다. 실행 중·백그라운드에서 선택하면 기존 알림 이동 서비스로 전달하고, 전경 알림을 받은 뒤 앱이 종료된 경우에도 Android 로컬 알림 시작 payload를 읽어 메인·날씨 상세 목적지로 시작한다. 손상된 payload는 이동에 사용하지 않는다.
- Android 8 이상 채널을 FCM 기본 채널로도 지정하고 흰색 단색 소형 아이콘을 추가했다. `flutter_local_notifications 20.1.0` 요구사항에 맞춰 Java/Kotlin 17과 core library desugaring을 적용했으며, 현재 AGP 8.9.1·compileSdk 36은 패키지 최소조건을 충족한다.
- 알림 권한은 기존 `NotificationRegistrationService`가 요청하므로 새 표시 서비스에서 중복으로 요청하지 않는다. 다음 작업은 실제 기기에서 운영 FCM 발송 후 전경·백그라운드·종료 상태의 표시·선택 이동을 검증하는 것이다.
- 검증: 앱 `flutter analyze`, Flutter `48 tests`, Android debug APK 빌드를 통과했다. 운영 Worker나 외부 설정은 변경하지 않았다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Android 에뮬레이터 FCM 실수신 검증

- Google Play 지원 Android 17/API 37 `Medium_Phone` 에뮬레이터를 부팅하고 운영 서버 주소가 포함된 Debug APK를 설치했다. Android 알림·정밀 위치 권한과 Location Accuracy를 테스트 환경에서 허용했다.
- 앱에서 FCM 등록 토큰이 생성된 것을 확인했고 Firebase Console의 테스트 기기로 정상 인식됐다. 토큰 원문은 문서나 저장소에 기록하지 않았다.
- Firebase Console의 테스트 메시지를 세 번 발송해 다음 경로를 검증했다.
  - 전경: `weather_care_alerts` 고중요도 채널에 앱 로컬 알림이 게시되고 제목·본문·확장 본문·전용 소형 아이콘이 적용됐다.
  - 백그라운드: 홈 화면에 머문 상태에서 시스템 알림이 게시됐다. 알림 선택 후 앱이 다시 열리고 기본 `Main` 탭이 선택됐다.
  - 종료: Android의 강제 종료 상태는 만들지 않고 앱 UID로 프로세스만 종료해 `stopped=false`를 유지했다. 앱 프로세스가 없는 상태에서 알림이 수신됐고, 선택 후 앱 프로세스와 `MainActivity`가 시작됐다.
- 세 경로 모두 FCM 제목·본문이 일치했으며 앱의 치명적 예외나 알림 처리 실패 로그는 없었다.
- Firebase Console 테스트 메시지에는 앱의 `notificationTarget`·`notificationTopic` 데이터를 넣지 않았으므로 이번 실수신은 데이터가 없을 때의 안전한 `Main` 이동까지만 검증했다. 운영 Worker가 만든 실제 데이터 payload의 `Detail` 이동은 별도 종단 검증이 남아 있다.
- 종료 상태 시작 뒤 앱이 표시한 운영 서버 연결 경고는 FCM과 별개다. 호스트와 에뮬레이터의 Worker 연결·DNS는 정상이었지만 운영 Today API가 약 29.6초 걸려 앱 `ApiClient`의 6초 제한을 초과했다. 수원 모의 위치로 바꾼 뒤 재시도해도 같은 경고가 유지되어 서버 응답시간 또는 앱 제한시간 조정이 다음 진단 대상이다.
- Firebase Console에는 발송하지 않은 알림 작성 화면과 최근 테스트 기기 항목만 남아 있으며 전체 캠페인은 게시하지 않았다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today API 보조자료 대기시간 제한

- Today API가 핵심 기상청 단기예보·사용자 설정과 보조자료를 동시에 조회하되, 환경·현재 강수·특보·도로살얼음·도로통제 보조자료는 최대 3.5초까지만 응답 경로에서 기다리도록 변경했다. 늦은 작업은 `executionCtx.waitUntil()`으로 끝까지 처리해 캐시 갱신이 취소되지 않게 했다.
- 제한시간을 넘긴 보조자료는 값이 없는 정상 상태로 취급하지 않는다. 환경자료는 기존 미수신 안내를 사용하고, 강수·특보·블랙아이스(도로살얼음)·도로통제는 각각 어떤 자료를 확인하기 어려운지 `DATA_STATUS` 문구로 안내한다.
- 제한시간 초과 Provider 이름과 3,500ms 기준을 비밀값·요청 URL 없이 구조화 경고 로그로 남긴다. 자동 테스트에 제한시간 안의 결과, 제한시간 초과 대체값, 자료별 상태 문구를 추가했다.
- 변경 전 동일 수원 요청은 최대 약 29.6초가 걸렸다. 운영 배포 후 같은 요청 3회는 HTTP 200과 4.29초·4.19초·4.21초를 기록해 앱의 6초 제한 안에 응답했다. 강수 보조자료가 늦은 실행에서는 `자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요`가 반환됐다.
- 운영 Worker `https://weather-care-server.sy40222.workers.dev`의 활성 버전은 `f55d1b10-8ccc-46a1-8df1-940f85971317`이다. 에뮬레이터 모의 위치가 미국 기본 좌표로 돌아가 생긴 KMA 거절을 수원 좌표로 다시 지정한 뒤, 앱이 수원 GPS 격자 `61,120`의 Today·Weekly HTTP 200 응답을 받아 연결 경고 없이 메인 날씨 화면에 진입하는 것을 확인했다.
- 검증: 서버 TypeScript 검사, Vitest `24 files / 107 tests`, Worker 번들 dry-run, 운영 응답시간 3회 측정, Android 에뮬레이터 종단 확인을 통과했다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 운영 FCM 상세 이동 종단 검증

- 운영 자료에서 실제 `삼일대로` 일부 차로 통제가 확인되는 서울 좌표를 Android 에뮬레이터 설치정보에 잠시 등록하고 앱을 백그라운드에 뒀다. 별도 시험 발송 API나 임의 문구는 만들지 않았다.
- 정오 정규 Cron이 정상 완료됐고, 원격 D1 발송 이력에 `ROAD_CONTROL_c1f0519_PARTIAL`이 기록됐다. 설치 행에도 같은 통제의 `PARTIAL` 상태가 반영돼 운영 Worker 판단과 FCM 성공 기록을 확인했다.
- Android 알림함에는 `weather_care_alerts` 고중요도 채널로 제목 `출퇴근 경로`와 삼일대로 통제의 직접행동·공식 사실 본문이 도착했다. 알림 선택 후 앱이 열리고 `Detail` 탭이 선택됐으며, 화면의 첫 근거로 같은 통제의 직접행동과 국가교통정보센터 공식 정보가 표시됐다.
- 앱 선택 과정에서 Flutter·Android 치명적 예외는 없었다. 이로써 운영 Worker가 구성한 도로통제 알림의 `WEATHER_DETAILS`·`COMMUTE` 목적지 계약이 FCM과 Android 선택 경로를 거쳐 실제 상세 화면까지 이어지는 것을 확인했다.
- 검증 후 에뮬레이터와 설치정보를 수원 GPS 격자 `61,120`으로 복원했다. 이번 검증에서 생성된 발송 이력 1건과 도로통제 상태만 원격 D1에서 삭제·초기화했으며, 대상 이력이 0건이고 상태가 `NULL`인 것을 재확인했다. 제품 코드는 변경하지 않았다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 알림 항목별 상세 근거 자동 포커스

- 종료 상태 시작과 백그라운드 알림 선택 모두에서 `notificationTopic`을 상세 화면까지 보존하도록 앱 라우팅을 연결했다. 알림 이동 시 `Detail` 탭을 열고 해당 항목의 근거가 있으면 화면 안으로 자동 이동한다.
- 강풍, 블랙아이스(도로살얼음), 자외선, 강수, 빨래 회수, 반려견 산책계획, 출퇴근 경로, 수면환경, 눈, 대기질, 기온, 더위 알림 항목을 실제 생활판단 유형과 연결했다. 관련 근거가 원래 6번째 이후에 있어도 먼저 배치해 최대 5개 노출 제한에서 빠지지 않게 했다.
- 알림과 연결된 첫 근거에는 `알림에서 확인한 항목` 안내와 강조 테두리를 적용했다. 해당 근거가 없는 일반 기상특보 등은 무관한 내용을 강조하지 않고 `근거와 자료` 영역까지만 이동한다.
- 단위 테스트에서 백그라운드 route arguments, 종료 상태 초기 메시지, 항목별 매핑, 6번째 출퇴근 근거의 선배치·강조·화면 진입을 확인했다. 검증은 앱 `flutter analyze`, Flutter `50 tests`, Android debug APK 빌드를 통과했다.
- 변경 APK를 Android 에뮬레이터에 설치한 뒤 서울의 실제 `삼일대로` 일부 차로 통제에 대한 정규 Cron·운영 FCM을 다시 수신했다. 알림 선택 후 `Detail` 탭에서 같은 출퇴근 직접행동과 공식 사실 카드가 첫 근거로 강조되고 화면 안에 전부 표시됐으며 치명적 예외는 없었다.
- 운영 검증 후 에뮬레이터와 설치정보를 수원 GPS 격자 `61,120`으로 복원했다. 검증용 `ROAD_CONTROL_c1f0519_PARTIAL` 발송 이력은 0건, 설치 행의 도로통제 상태는 `NULL`임을 원격 D1에서 재확인했다.
- 실수로 앱 디렉터리에 생성된 Wrangler 계정 캐시 파일은 삭제했다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today 준비물과 Detail 근거 연결

- Today `Check List`의 정보 버튼이 준비물 종류를 버리지 않고 Detail 탭까지 전달하도록 연결했다. 우산은 강수, 양산·선크림은 자외선, 많은 눈 대비는 눈, 겉옷은 기온, 마스크는 대기질, 물은 더위 근거로 이동한다.
- 선택한 준비물과 관련된 생활근거를 최대 5개 목록의 앞쪽에 배치하고 해당 카드로 자동 스크롤한다. 알림에서 연 카드의 `알림에서 확인한 항목`과 구분해 Today에서 연 경우 `선택한 항목의 근거`로 표시한다.
- 같은 준비물을 다시 선택해도 사용자가 그사이 Detail 화면을 스크롤했는지와 관계없이 근거로 다시 이동하도록 포커스 요청 번호를 별도로 갱신한다. 앱 시작 알림 포커스는 기존 동작을 유지한다.
- `docs/앱_탭_구성_현황.md`에서 Today 정보 버튼과 Detail 근거 연결 상태를 완료로 갱신했다.
- 검증: Detail 대상 테스트 `5 tests`, 앱 `flutter analyze`, 전체 Flutter `52 tests`, Android debug APK 빌드를 통과했다. 최신 APK를 에뮬레이터에 설치해 운영 화면 진입을 확인했으나 확인 시점의 Today 추천 준비물은 0개여서 실제 버튼 선택은 위젯 테스트로 검증했다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Main 생활행동과 Detail 근거 연결

- Main `Check List`의 생활행동 카드를 누르면 Detail 탭에서 같은 생활항목을 우선 배치하고 자동으로 해당 근거까지 이동하도록 연결했다. 카드 오른쪽에는 이동 가능성을 알리는 화살표를 추가했다.
- 알림은 관련 주제의 여러 생활근거를 함께 찾지만, Main과 Today에서 사용자가 고른 항목은 정확한 `LifestyleMessageType`을 전달하도록 포커스를 분리했다. 예를 들어 `비가 잠시 그치는 시간`과 `우산 준비`가 함께 있어도 우산 준비를 누르면 우산 근거만 강조한다.
- Today의 우산·양산·많은 눈 대비·겉옷·마스크·물·선크림도 주제 단위가 아니라 대응하는 정확한 생활근거 유형으로 연결하도록 함께 보강했다. 앱 안에서 선택한 항목은 `선택한 항목의 근거`, 푸시알림에서 연 항목은 `알림에서 확인한 항목`으로 구분한다.
- `docs/앱_탭_구성_현황.md`에 Main 생활행동 카드의 Detail 이동·강조 동작과 완료 상태를 반영했다.
- 검증: 앱 `flutter analyze`, Flutter `52 tests`, Android debug APK 빌드를 통과했다. 최신 APK를 에뮬레이터에 설치하고 운영 수원 자료의 `시간대별 기온 차` 카드를 선택해 Detail 탭 전환, 같은 행동·발생 가능성·앱 계산 근거의 첫 카드 강조와 화면 진입을 확인했다. Flutter·Android 치명적 예외와 RenderFlex 오류는 없었다.
- 에뮬레이터 설치 공간 부족으로 시스템 앱 캐시를 정리한 뒤 APK를 기존 앱 데이터 유지 방식으로 다시 설치했다. 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today 타임라인 추천과 Detail 근거 연결

- Today `간단한 타임라인`의 추천 준비물 배지를 선택하면 Detail 탭에서 같은 준비물의 정확한 생활근거를 우선 배치하고 자동으로 이동하도록 연결했다. Check List와 동일한 추천 종류별 매핑을 사용하므로 같은 주제의 다른 근거가 잘못 강조되지 않는다.
- 추천 배지에 이동 화살표를 표시하고 스크린리더가 `준비물명 근거 보기` 버튼으로 읽도록 접근성 의미를 추가했다. 선택 동작을 안정적으로 검증할 수 있는 준비물·시간별 키도 부여했다.
- `docs/앱_탭_구성_현황.md`에 타임라인 추천 준비물의 Detail 이동·강조 동작과 완료 상태를 반영했다.
- 검증: 타임라인 대상 위젯 테스트, 앱 `flutter analyze`, 전체 Flutter `52 tests`, Android debug APK 빌드를 통과했다. 최신 APK를 에뮬레이터에 기존 데이터 유지 방식으로 설치하고 Today 타임라인 화면과 치명적 예외가 없음을 확인했다. 확인 시점에는 추천 준비물이 없어 실제 배지 선택은 위젯 테스트로 검증했다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today 준비물·시간대 역할 분리

- Today Check List는 `무엇을 챙길지`, 간단한 타임라인은 `언제 필요한지`를 담당하도록 안내 문구를 분리했다. 타임라인의 추천 배지에는 `이 시간에 필요해요`를 붙여 같은 준비물명이 시각 정보로 읽히게 했다.
- Check List에서 실제 예보 시각과 관계없이 표시되던 `오후부터 필요해요`, `아침저녁에 추천해요` 등의 준비물별 고정 문구를 모두 제거했다. 예보에 근거하지 않은 시간 표현이 타임라인의 실제 시각과 충돌하지 않는다.
- 정보가 줄어든 Check List 카드는 높이를 196px에서 164px로 줄였다. 준비물 선택·체크와 정보 버튼을 통한 Detail 근거 이동 동작은 유지했다.
- `docs/앱_탭_구성_현황.md`에 두 영역의 역할, 카드 높이, 실제 상태 제목 예시와 중복 정리 완료 상태를 반영했다.
- 검증: 관련 위젯 테스트 2개, 앱 `flutter analyze`, 전체 Flutter `52 tests`, Android debug APK 빌드를 통과했다. 최신 APK를 에뮬레이터에 설치해 운영 자료의 양산·선크림 카드가 고정 시점 문구 없이 표시되고 새 섹션 안내가 적용된 것을 확인했다. 치명적 예외와 RenderFlex 오류는 없었다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today 준비물 반응형·빈 상태 보정

- Today Check List가 카드 최소 너비 124px을 기준으로 1~3열을 계산하도록 변경했다. 360px급 좁은 휴대폰에서는 추천이 3개 이상이어도 2열로 배치하며, 충분히 넓은 화면에서만 최대 3열을 사용한다.
- 준비물 이름을 최대 2줄까지 표시해 `많은 눈 대비` 같은 긴 이름이 좁은 카드에서 잘리지 않게 했다. 7개 전체 추천을 넣은 360px 위젯 테스트에서 카드 너비, 행 전환, 긴 이름과 오버플로 부재를 확인했다.
- 추천이 없을 때는 `오늘은 특별히 챙길 준비물이 없어요` 빈 상태만 표시한다. 카드 조작법과 시간 확인 안내는 실제 추천이 있을 때만 노출해 빈 안내가 반복되지 않게 했다.
- `docs/앱_탭_구성_현황.md`에 반응형 열 기준과 빈 상태 동작, 다수·빈 추천 레이아웃 확인 완료를 반영했다.
- 검증: 앱 `flutter analyze`, 전체 Flutter `53 tests`, Android debug APK 빌드를 통과했다. 에뮬레이터 저장공간 부족으로 기존 앱 APK만 제거하고 데이터는 유지하는 `cmd package uninstall -k` 방식으로 최신 APK를 복구 설치했다. 운영 자료의 양산·선크림 2열 카드와 치명적 예외·RenderFlex 오류가 없음을 확인했다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today 중복 브리핑 카드 제거

- Today 상단의 별도 브리핑 카드를 제거했다. 같은 `today.brief`는 Main 상단에서 대표 행동으로 이미 노출되며, 준비물 개수와 빈 상태는 바로 아래 Check List가 직접 보여주므로 Today에서 반복하지 않는다.
- Today는 페이지 헤더 다음에 Check List, 간단한 타임라인 순서로 바로 이어진다. 운영 서버 미연결 상태도 두 섹션의 기존 미지원 카드가 각각 설명하므로 별도 중복 안내가 필요하지 않다.
- `docs/앱_탭_구성_현황.md`에서 브리핑 카드 항목을 삭제하고 화면 순서를 다시 번호 매겼으며, 중복 검토 항목을 완료로 표시했다.
- `today.brief`와 추천 개수 문구가 Today에 다시 나타나지 않고 Check List·타임라인이 노출되는 회귀 테스트를 추가했다.
- 검증: 앱 `flutter analyze`, 전체 Flutter `54 tests`, Android debug APK 빌드를 통과했다. 에뮬레이터에는 기존 앱 데이터 유지 방식으로 최신 APK를 설치했고, Today 헤더 직후 양산·선크림 Check List가 시작되며 기존 브리핑·추천 개수 카드가 없는 것을 확인했다. 치명적 예외와 RenderFlex 오류는 없었다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Today 준비물 체크 당일 저장

- `챙길게요/챙겼어요`를 기기 내 SharedPreferences에 날짜와 준비물 종류로 저장한다. 같은 날에는 앱 재실행·화면 이동·새로고침·지역 변경·추천의 일시적 제거 후에도 체크를 복원하며, 다시 눌러 해제한 상태도 저장한다.
- 한국시간 0시를 기준으로 새 날짜에는 체크를 초기화한다. 화면을 켜둔 상태에서는 자정 타이머로, 백그라운드에서 돌아오면 복귀 이벤트로 날짜를 확인한다. 기기의 시간대 설정과 무관하게 한국시간으로 계산한다.
- 체크는 준비 여부 표시만 담당하며 날씨 판단·추천·알림 설정에 영향을 주거나 앱 서버로 전송되지 않는다. 저장소는 가장 최근 날짜의 상태 한 건만 보관하며 지난 날짜 데이터는 복원하지 않는다.
- 초기 복원이 끝나기 전 체크 변경을 막고, 이전 날짜의 늦은 응답이 새 날짜 상태를 덮지 않게 했다. 저장·읽기는 순서대로 처리하며 저장 실패는 이전 상태로 복구·안내하고 읽기 실패는 재시도를 제공한다. 화면에 당일 유지·한국시간 자정 초기화 안내를 추가했다.
- 검증: 날짜 경계·재생성·지역 및 추천 변경·체크 해제·늦은 응답·자료 손상·저장 및 읽기 실패를 포함한 전체 Flutter `62 tests`, `flutter analyze`, Android debug APK 빌드를 통과했다.
- 에뮬레이터에는 `adb install -r`로 최신 APK를 설치했다. 운영 자료의 양산을 체크하고 앱 강제 종료·재실행 뒤 같은 체크가 복원되는 것을 확인했다. 검증 후 양산 체크를 해제해 원래 상태로 돌렸고 앱의 치명적 예외·RenderFlex 오류는 없었다.
- `docs/앱_탭_구성_현황.md`에 저장 정책과 실패 처리를 반영했다. Today 탭의 남은 체크 저장 항목도 완료됐다. 다음 검토 대상은 Detail 탭의 현재 지표와 결측 표시다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Detail 현재 지표와 결측 표시 정리

- Detail 현재 카드에 `체감 → 습도 → 풍속 → 자외선 → 초미세먼지(PM2.5) → 미세먼지(PM10)` 6개 지표를 고정 순서로 표시한다. 빠져 있던 풍속과 PM10을 추가하고 두 미세먼지 값을 서로 대체하지 않는다. 풍속은 `m/s`, 농도는 `㎍/㎥`까지 표시한다.
- 값이 없는 지표는 숨기거나 `미지원`이라고 하지 않고 `자료 없음`으로 표시한다. 팝업은 확인할 자료가 부족함을 설명하며, 미수신·품질오류 같은 원인을 임의로 단정하거나 결측값에 공식 정상 등급을 붙이지 않는다. 체감온도 계산조건 관련 기존 설명은 유지한다.
- 현재 기온 모델의 결측을 0으로 대체하던 처리를 제거하고 Main·Detail에서 결측과 실제 0을 구분한다. Main의 하늘 상태가 없거나 해석되지 않을 때 `맑음`으로 안내하던 처리도 제거했다.
- 예상기온 앞에 예보 대상 시각을 표시한다. Main과 Detail이 같은 한국시간 변환 함수를 사용하며, 시각이 없는 경우 임의로 현재 시각을 만들지 않고 `예상기온`만 표시한다.
- 지표는 화면 폭과 글자 크기에 따라 1~3열로 배치한다. 360px 기본 글씨에서는 2열, 2배 글씨에서는 1열로 표시한다. 기존 근거 선택 후 자동 이동 동작도 유지한다.
- 검증: 전체 Flutter `70 tests` 통과, Main 결측 보완 후 관련 `33 tests` 재검증, `flutter analyze`, Android debug APK 빌드 통과. 결측과 실제 0, PM10 독립 표시, 한국시간 변환, 360px·큰 글씨, 지표 팝업을 검증하는 테스트 8개를 추가했다.
- 에뮬레이터에 `adb install -r`로 데이터 유지 설치했다. 최초 운영 서버 연결 실패는 재시도 후 정상 복구됐다. 실제 운영 자료의 6개 지표·단위·예상기온 시각·PM10 팝업을 확인했고 치명적 예외·RenderFlex 오류는 없었다. 화면 검증 이미지는 Git 제외 경로 `weather_care_app/build/ui-qa/detail-metrics.png`에 있다.
- `docs/앱_탭_구성_현황.md`에 현재 카드의 완료 상태를 반영했다. 다음 항목은 Detail 시간별 예보의 결측 기본값·표시와 정보 밀도 검토이며, 이번 작업은 시간별 모델의 기존 0·맑음 기본값을 변경하지 않았다. 이후 근거와 자료 영역의 표시 개수·자료 상태 안내도 검토해야 한다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Detail 시간별 예보 결측·범위·표시 정리

- 앱의 `HourlyWeatherItem`에서 기온·강수확률·강수량·쌓일 눈·풍속·날씨 상태의 결측을 0이나 맑음으로 대체하지 않는다. 눈 예상도 명시된 false와 알 수 없는 상태를 구분한다. 숫자가 아닌 값과 비유한 값도 결측으로 유지하며 실제 0은 데이터에 보존한다.
- `forecastAt`/구형 `observedAt`의 시간대 정보를 한국시간 날짜·시각으로 변환해 UTC 날짜 경계에서도 오늘의 슬롯을 판별한다. 시각이 없으면 `--시` 대신 `시각 자료 없음`으로 표시한다.
- 직접 기상청 조회에서도 동일한 결측 원칙을 적용했다. TMP가 빠져도 다른 시간별 자료가 있으면 해당 슬롯은 유지한다. TMN/TMX 전용 슬롯은 제외하고 기온 결측은 체감 계산과 일 최저·최고 계산에 0으로 대입하지 않는다. PTY·SKY가 부족한데 날씨를 맑음으로 만들지 않는다.
- 직접 조회의 `미만` 강수·적설 구간은 상한을 정확한 양으로 사용하지 않고 원래 표시 범위를 유지한다. 서버의 미만·범위·이상·명시적 NONE도 구분해 표시한다. 강수량만 있거나 강수확률만 있을 때 다른 값을 0으로 보충하지 않는다.
- Detail 하단 제목을 `시간별 예보`로 바꾸고 행을 `시각·날씨 → 예상기온·예상 체감 → 지표 태그`로 나눴다. 기온·체감과 태그가 줄바꿈되도록 해 360px·2배 글씨에서도 내용이 잘리지 않는다.
- 강수확률·강수량은 별도 태그, 쌓일 눈은 양·범위 또는 눈 예상 안내로 표시한다. 누락된 강수확률·강수량·쌓일 눈·풍속은 행 아래 `자료 없음: …`으로 묶어 표시하며 실패·오류 원인을 추정하지 않는다. 명시된 무강수·무적설은 반복 노출하지 않아 강수확률이 20%여도 `강수량 0mm` 태그는 표시하지 않는다.
- 자외선·PM2.5·PM10은 자료가 있는 시간대에만 각각 표시하고, PM2.5와 PM10을 서로 대체하지 않는다. 기존 임의 위험색 미사용 정책을 유지한다. 빈 시간별 목록에는 안내만 표시하고 임시 0값 행을 만들지 않는다.
- 검증: 신규 테스트 14개 포함 전체 Flutter `84 tests` 통과. 에뮬레이터에서 발견한 0mm 반복 노출 보완 후 시간별 관련 `11 tests`와 `flutter analyze`·Android debug APK 빌드를 다시 통과했다. 기존 Detail 근거 자동 이동 회귀 테스트도 통과했다.
- 에뮬레이터의 최초 교체 설치는 저장공간 부족으로 실패했다. 대상 앱 APK만 `cmd package uninstall -k`로 제거하고 데이터를 유지한 채 새 APK를 설치했다. 마지막 보완 APK는 `adb install -r`로 교체했다. 실제 운영 자료의 시간별 기온·체감·풍속·자외선·두 미세먼지, 0mm 미노출, 화면 배치를 확인했고 치명적 예외·RenderFlex 오류는 없었다. 검증 이미지는 Git 제외 경로 `weather_care_app/build/ui-qa/detail-hourly.png`에 있다.
- `docs/앱_탭_구성_현황.md`의 시간별 예보 구성과 완료 체크를 갱신했다. 이번 변경은 앱 응답 파서·직접 조회·Detail 표시 범위이며 서버의 판단 로직·배포는 변경하지 않았다. 다음 항목은 Detail `근거와 자료` 영역의 표시 개수와 자료 상태 안내 정리다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Detail 전체 근거와 자료 상태 안내

- `근거와 자료`가 처음 5개 뒤의 생활 근거를 영구적으로 버리던 제한을 제거했다. 기본 5개와 `근거 N개 더 보기`로 전체를 확인하고 `기본 5개만 보기`로 접는다. 선택·알림 관련 근거를 앞에 배치하는 기존 정책과 나머지 서버 응답 순서는 유지한다.
- 별도로 받은 `dataStatusMessages`를 근거 뒤 `자료 상태` 영역에 모두 표시한다. 근거의 펼침 여부·개수와 무관하며, 미수신·품질오류·이전 자료·자료 차이 등의 원문을 임의로 요약하거나 정상 상태로 바꾸지 않는다. 빈 문장은 제외하고 상태 안내가 없으면 영역을 생략한다.
- 생활 근거가 비어 있으면 `현재 자료에 표시할 생활 안내 근거가 없어요`로 안내하며, 자료 상태만 있더라도 표시한다. 자료 부족과 준비물 불필요를 같은 의미로 안내하지 않는다. 직접 조회의 서버 미지원 카드 제목도 `근거와 자료`로 통일했다.
- 선택·알림의 근거가 최신 자료에 없으면 각각 `선택한 항목의 근거가 현재 자료에 없어요`, `이 알림과 연결된 근거가 현재 자료에 없어요`로 알린다. 다른 항목을 대신 강조하거나 위험 해소를 단정하지 않으며, 해당 부재 안내로 이동한다.
- 첫 설명을 무조건 `skip(1)` 하던 처리를 수정했다. 제목과 같은 첫 문장만 중복 제거하고 그 역할을 제목 위에 표시한다. 제목과 다른 첫 문장은 공식 정보·발생 가능성·앱 계산·자료 상태 등의 역할과 함께 보존한다.
- Detail 콘텐츠를 한 스크롤 안에서 구성해 큰 글씨로 상단 카드가 화면보다 길어져도 근거 위치를 찾을 수 있게 했다. 자동 이동은 항목 시작에 맞춘다. 전체 펼침은 같은 지역의 새 자료에서도 유지하고 지역 변경 시 초기화하며, 사용자가 접으면 근거 영역 시작으로 이동한다.
- 검증: 새 테스트 11개를 포함한 전체 Flutter `95 tests`, `flutter analyze`, Android debug APK 빌드를 통과했다. 전체 보기·접기, 상태만 있는 경우, 첫 근거 보존, 중복 제목 역할, 근거 부재와 이후 복구, 360px·2배 글씨 자동 이동, 지역 변경, 직접 조회를 검증했다.
- 에뮬레이터에는 `adb install -r`로 데이터를 유지하고 설치했다. 실제 Main의 생활 안내 선택 → Detail 해당 근거 강조·이동, 역할 라벨, 강수·기상특보 미수신 원문의 자료 상태 표시를 확인했다. 당시 근거는 3개여서 더 보기 조작은 위젯 테스트로 검증했다. 치명적 예외·RenderFlex·ParentData 오류는 없었다. 화면 검증 이미지는 Git 제외 경로 `weather_care_app/build/ui-qa/detail-evidence.png`에 있다.
- `docs/앱_탭_구성_현황.md`의 오래된 `챙길 이유/최대 3개` 설명을 실제 구현에 맞춰 갱신했고 Detail 확인 항목을 완료했다. 다음 항목은 Week 탭의 실제 제공 기간과 날짜·오늘 표시 정리다. 서버 판단·배포는 변경하지 않았다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Week 실제 제공 기간과 날짜·오늘 표시

- Week 페이지 제목을 `날짜별 날씨`, 요약 제목을 `제공된 예보 요약`으로 바꾸고 실제 날짜 범위·제공 일수를 표시한다. 하단 탐색의 `Week` 이름은 유지하며 툴팁을 `날짜별 날씨`로 변경했다. 7일 예보를 제공하는 것으로 안내하지 않는다.
- `/api/v1/weather/weekly` 응답의 기존 요일 `date`를 유지하면서 `forecastDate: YYYY-MM-DD`를 추가했다. 앱 모델과 기상청 직접 조회도 같은 날짜를 보존한다. 판단 기준·비밀값·바인딩·DB 스키마 변경은 없다.
- 날짜별 카드에는 월·일·요일을 표시하고 한국시간 날짜가 일치할 때만 `오늘`을 붙인다. 한국시간 자정과 앱 복귀 시 갱신한다. 체크리스트와 한국시간 날짜·자정 계산을 공통 유틸리티로 공유하며 체크 저장 정책은 변경하지 않았다.
- 요일만 있는 구버전 자료, 없는 날짜, 유효하지 않은 날짜는 임의로 추정하지 않고 `날짜 확인 어려움`으로 표시한다. 중간 날짜가 빠진 범위는 `기간 내 N일 자료`, 날짜 미확인 항목은 별도 개수로 안내한다. 빈 목록은 자료 없음으로 안내하고 0일·맑음·준비물 없음 요약을 만들지 않는다.
- 날짜·날씨·최저/최고 기온·준비물의 배치를 분리해 좁은 화면과 큰 글씨의 줄바꿈을 지원한다. 대표 준비물 최대 3개와 기존 준비물 지원 구분은 유지한다.
- 검증: 신규 앱 테스트 11개를 포함한 전체 Flutter `106 tests`, `flutter analyze`, Android debug APK 빌드 통과. 서버는 날짜 응답·기존 요일 호환·연도 경계 API 테스트 3개를 포함한 `24 files / 110 tests`, `tsc --noEmit`, Wrangler 배포 사전 검증을 통과했다. 로컬 모의 테스트에 필요 없는 운영 비밀값 미설정 경고는 기존 상태이며 테스트는 통과했다.
- 사용자가 운영 배포를 승인했다. 기존 변수 보존·원격 충돌 검사 옵션으로 배포했으며 버전은 `a9ed7155-b22e-4c78-afdd-aeb084195420`이다. 기존 10분 주기와 D1 바인딩을 유지했다. 운영 `/health`의 `ok`, `/api/v1/weather/weekly?nx=60&ny=121`의 2026-09-10~13 달력 날짜 및 기존 목·금·토·일 응답을 확인했다.
- 에뮬레이터 교체 설치는 저장공간 부족으로 실패해 대상 앱 APK만 `cmd package uninstall -k`로 제거하고 데이터를 유지한 채 설치했다. 실제 운영 자료로 9월 10~13일·4일 예보, 월·일·요일, 10일에만 오늘 표시를 확인했다. 치명적 예외·RenderFlex·ParentData 오류는 없었다. 검증 이미지는 Git 제외 경로 `weather_care_app/build/ui-qa/week-dates.png`에 있다.
- `docs/앱_탭_구성_현황.md`의 관련 체크를 완료했다. 다음 항목은 Week 상단 3개 요약 지표와 날짜별 날씨·기온 결측 집계 기준 정리이며, 이후 날짜별 추가 강수 정보 필요 여부를 검토한다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Week 요약 지표와 날짜별 결측 처리

- 상단 3개 지표를 `비/눈 예보 · 확인된 최고기온 · 준비물 추천`으로 유지하고 지표별 `N/M일 자료`를 표시한다. 부분 자료의 양성 결과는 `N일 확인`, 부분 자료에서 0건일 때는 `확인 어려움`, 전부 결측이면 `자료 없음`으로 구분한다. 실제 확인된 무강수와 빈 추천의 0일은 유지하되 준비물 필요 여부를 단정하지 않는다.
- 최고기온은 유효한 숫자만 비교해 `N/M일 자료 중 최고`로 표시한다. 서버와 직접 조회가 일 최저·최고 예보(`DAILY`)와 받은 시간대의 극값(`HOURLY`)을 구분하고, 후자는 `시간별 최저/최고` 및 받은 시간대만 비교한 값이라는 설명을 붙인다. 일 전체 최고기온으로 오해시키지 않는다.
- 날짜별 날씨·기온을 nullable 모델로 바꾸고 결측·빈 문자열·NaN/Infinity·역전된 최저/최고를 맑음·0으로 만들지 않는다. 실제 0과 영하기온을 보존한다. 알 수 없는 현상명은 `날씨 자료 없음`과 물음표 아이콘으로 표시하고 한쪽 기온만 없으면 해당 항목만 `자료 없음`으로 안내한다.
- 강수 집계에 빗방울·눈날림·혼합 강수를 포함한다. 일부 결측이어도 확인된 강수 현상은 집계하지만 불완전한 맑음·흐림을 무강수로 확정하지 않는다. 날짜 미확인과 중복 날짜는 요약에서 제외하고 내역을 알린다.
- 서버 응답에 `weatherDataComplete`, `minTemperatureSource`, `maxTemperatureSource`를 추가했다. 기존 날짜·요일·문자열 기온 필드는 유지한다. `weatherDataComplete`는 받은 첫~마지막 시간대 사이의 자료 완전성이지 24시간 전체 보장을 뜻하지 않는다. 구버전의 메타데이터 없는 무강수 판단은 보수적으로 미확인 처리한다.
- 서버 기상청 파서도 기온만 누락된 시간대를 보존한다. 기온이 없으면 체감을 계산하지 않으며 빠진/잘못된 PTY·SKY, 공백 숫자를 무강수·맑음·0으로 바꾸지 않는다. 시간대 누락을 완전한 자료로 처리하지 않는다. 임계값·추천 점수·알림 정책·비밀값·DB 스키마·바인딩은 변경하지 않았다.
- 준비물은 활성(`recommended: true`)·알려진 종류만 중복을 제거해 최대 3개 표시한다. 서버도 비활성 항목을 먼저 제외한 뒤 3개를 선택한다. `표시할 준비물 추천 없음`, `준비물 추천 자료 없음`, 운영 서버 미연결의 `미지원`을 구분하며 알 수 없는 종류를 우산으로 만들지 않는다. 일부 잘못된 추천이 있어도 유효한 추천은 보존하고 상태를 안내한다.
- 좁은 화면과 큰 글씨에서는 요약 지표를 1~3열로 배치한다. 신규 앱 테스트 15개를 포함한 전체 Flutter `121 tests`, `flutter analyze`, Android debug APK 빌드를 통과했다. 서버는 추가 테스트 10개를 포함한 `24 files / 120 tests`, `tsc --noEmit`, Wrangler 배포 사전 검증을 통과했다. 기존 로컬 운영 비밀값 미설정 경고는 모의 테스트 통과에 영향을 주지 않았다.
- 기존 설정 보존·원격 충돌 검사 옵션으로 운영 배포했다. 버전 `1c498d8f-0d41-4e01-a598-1e32f054968b`, 기존 10분 주기·D1 바인딩 유지. 운영 `/health`의 `ok`와 weekly 응답의 날짜별 자료 완전성·기온 출처 필드를 확인했다.
- 에뮬레이터에는 `adb install -r`로 데이터를 유지해 설치했다. 첫 연결 실패는 다시 시도해 복구됐다. 실제 마지막 날짜에 일부 날씨 자료가 없어 `확인 어려움 · 3/4일 자료`로 집계되고, 오늘의 `시간별 최저/최고`와 빈 추천 안내가 표시되는 것을 확인했다. 검증 이미지는 Git 제외 경로 `weather_care_app/build/ui-qa/week-summary.png`에 있다.
- `docs/앱_탭_구성_현황.md`의 요약·결측 항목을 완료했다. 다음 항목은 날짜별 강수확률·강수량 등 추가 정보의 필요 여부 및 표시다. 일 강수 누적량의 결측·범위 합산 등은 이번 변경 범위에 포함하지 않았다.
- 사용자 소유의 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Week 날짜별 강수확률·예상 누적량 표시

- 날짜별 카드에 `강수 예보`를 추가했다. 표시된 시간 구간의 시간대별 강수확률 최고값과 앱에서 합산한 예상 누적량을 구분한다. 최고 확률을 하루 전체 확률로 표현하지 않으며, 24시간 미만 자료에는 `하루 중 일부 시간`을 붙인다. 0%·0mm만 있을 때의 기본 안내는 생략하고, 양수 확률이 있어도 0mm 문구는 생략한다.
- 기상청 공식 시간 안내를 확인했다: https://www.kma.go.kr/w/iframe/dfs.do 의 예보 요소별 안내는 PCP·POP가 표기 시각의 이전 1시간임을 명시한다. 새 Week 강수 자료는 00시를 전날 23~24시로 배정한다. 월·연도 경계와 UTC/KST 변환을 테스트했다.
- `DailyWeatherForecast.precipitationDetail` / weekly 응답에 `kind`, `hours[{forecastAt, probability, amountText}]`, 연장 예보의 `extendedMaxProbability`를 추가했다. 기존 필드는 유지하고 기존 단순 강수량 합계를 새 화면에 노출하지 않는다. Today의 48슬롯 제한 전 전체 예보를 사용한다. 추가 기상청 호출·DB 변경·비밀값/바인딩/알림 임계값 변경은 없다.
- 앱의 공통 `PrecipitationAmount`는 원문의 미만·이상·범위 경계를 보존한다. 천분의 1mm 정수로 합산해 부동소수점 흔들림을 피한다. `1mm 미만` 두 개는 `2mm 미만`, `5mm + 1mm 미만`은 `5mm 이상 6mm 미만`이다. 공백·자료없음·음수·역전범위·타 단위·단위 없는 양수 코드는 0/mm로 대체하지 않는다.
- 시간대·항목 누락 시 확률과 강수량을 독립적으로 처리한다. 중간 구간이 없으면 부분합을 전체 누적량처럼 표시하지 않는다. 날짜 오류·중복·해당 날짜 밖 시간은 조용히 제외하지 않고 계산 불가를 안내한다. 구 API에도 결측으로 안전하게 동작한다.
- 연장 예보는 https://data.kma.go.kr/data/rmt/rmtList.do?code=420&pgmNo=572 의 설명을 따라 별도 처리한다. 02~14시 발표의 글피, 17~23시 발표의 그글피에는 3시간 간격·정성 정보가 있으므로 단계 코드를 mm로 합산하지 않는다. 확인된 시간대의 확률 최고값과 합계 미제공 안내를 표시한다.
- 직접 기상청 조회도 선택한 발표일·발표시각을 유지해 같은 날짜 구분과 공통 앱 계산을 사용한다. 서버/직접 조회 모두 자정·결측·연장 구간·48시간 이후 자료를 검증했다.
- 검증: 신규 Flutter 테스트 22개 포함 전체 `143 tests`, `flutter analyze`, Android debug APK 빌드 통과. 신규 서버 테스트 6개 포함 `25 files / 126 tests`, `tsc --noEmit`, Wrangler dry-run 통과. 모의 테스트에 불필요한 로컬 운영 비밀값 미설정 경고는 기존 상태이며 통과에 영향 없다.
- 운영 배포: `wrangler deploy --keep-vars --strict`, 버전 `8e44c66e-18cb-437d-9e59-0735adc831cc`. 기존 D1·변수·10분 cron 유지. `/health` ok. 실제 weekly 응답에서 오늘 10개 슬롯(15시~다음 날 00시), 내일·모레 각 24개, 글피 EXTENDED를 확인했다.
- 에뮬레이터 `adb install -r`로 데이터 보존 설치. 실제 Week에서 오늘 `14~24시 · 하루 중 일부 시간`, 내일·모레 `0~24시`, 글피 정성 강수량 합산 제외 안내를 확인했다. 수신자료의 강수량은 0이므로 기본 0mm 문구가 없고 확률 최고 20%만 표시된다. 양수/범위 누적량은 위젯 테스트로 확인했다. 치명적 예외·RenderFlex·ParentData 오류 없음. 이미지: Git 제외 `weather_care_app/build/ui-qa/week-precipitation.png`.
- Week 문서 체크를 완료했다. 다음 우선 점검은 이번에 확인한 PCP·POP의 이전 1시간 의미를 기존 Detail/Today 시간별 강수 표시·알림에서도 일관되게 쓰는지 확인하는 것이다. 기존 `WeatherSnapshot.validFrom/validTo` 및 시간별 UI는 이번에 일괄 변경하지 않았다. 단순히 모든 기상요소를 1시간 당기면 정시 기온·바람이 틀려지므로 요소별 구간을 분리해야 한다. 이후 Setting의 GPS 권한·위치 갱신/지역 선택 순서로 진행한다. Setting 문서의 ‘UI 데모·저장 미구현’은 현재 코드의 로컬 저장·서버 동기화·시간 선택과 다르므로 재구현 전 실제 상태부터 대조해야 한다.
- 사용자 소유 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 강수 적용 시간과 정시 지표 분리

- 기상청 시간 안내(https://www.kma.go.kr/w/iframe/dfs.do)의 강수량·강수확률·날씨는 이전 1시간, 기온·바람은 정시 기준임을 재확인했다. API허브의 1시간 신적설(SNO) 요소 정의도 참고해 같은 강수 슬롯에 연결했다. 새 `WeatherSnapshot.precipitationPeriod = {start, end}`는 종료 미포함이며, 일반 `forecastAt/validFrom/validTo`는 정시 지표용으로 유지했다. 연장 정성 예보는 null로 구분하고 1시간 양으로 판정하지 않는다. 기존 Provider의 필드 부재는 기존 시간 계약을 유지한다.
- 강수·눈 단일/시계열 판정과 근거 문구에 실제 강수 시작·종료를 사용한다. 인접한 정시의 다른 강수량이 근거로 선택되지 않도록 구간 겹침으로 찾는다. 여러 원인 중 강한 근거와 문구 유효시간도 일치시켰다. 강수 종료 시각이 지난 자료는 의사결정 복사본에서만 제외하며 원본 시간별 자료·기온·바람은 유지한다. 스케줄러는 조회 당시 시각이 아닌 실행 시각도 전달해 만료를 재확인한다. 판단 버전 `weather-rules-1.2.0`.
- 비가 그치는 시간은 ISO 유효시간과 사용자용 시간 문구를 분리했다. 빨래·창문 행동 마감은 강수 시작 전으로 계산하며 이미 지난 마감을 안내하지 않고 `지금`으로 바꾼다. 산책·외출은 정시부터 다음 한 시간에 해당하는 강수와 기온·바람을 맞춰 비교한다. 대응 강수 자료가 없거나 중복이면 무강수로 간주하지 않는다. 시계열 결측 구간을 연속 상태로 연결하지 않도록 보완했다.
- Main 브리핑·Today 타임라인·우산/폭설 알림에 강수 구간을 표시한다. 다른 날짜의 강수에는 월·일을, 자정 경계에는 다음 날 표현을 추가했다. 알림 판정 임계값·발송 시각/중복 정책·공식 관측/특보 알림은 변경하지 않았다. 모의 발송 테스트만 수행했으며 실제 테스트 푸시는 발송하지 않았다.
- Detail은 정시 기온·체감·바람 지표 아래 `15~16시 강수 예보`처럼 별도 구간을 표시한다. 다음 날 00시의 강수는 오늘 23~24시 마지막 행으로 유지하고 다음 날 기온·바람은 제외한다. 오늘 00시에 들어 있는 전날 강수도 제외한다. 새 응답의 잘못된/미지원 구간은 양을 표시하지 않으며, 구형 응답은 `강수 적용 구간 미확인` 안내와 기존 값을 유지한다. 앱 직접 조회도 같은 구간을 만든다. Week 준비물 집계도 강수 날짜와 정시 지표 날짜를 분리해 자정 강수를 다음 날에 잘못 배정하지 않는다.
- 검증: 신규 앱 테스트 9개 포함 전체 Flutter `152 tests`, `flutter analyze`, Android debug APK 빌드 통과. 신규 서버 테스트 17개 포함 `26 files / 143 tests`, `tsc --noEmit`, Wrangler dry-run 통과. 만료 경계·강한 과거/약한 미래 강수·근거 슬롯·정시 바람 유지·산책의 직전 시간 무강수 오용·자정/연도 경계·연장 자료·서버 실제 스케줄러 경로·UTC/KST·구형 응답·360px/2배 글씨를 검증했다. 모의 테스트의 기존 로컬 운영 비밀값 미설정 경고는 통과에 영향 없다.
- 운영 배포: `wrangler deploy --keep-vars --strict`, 버전 `5c1eaba2-4c91-4c6c-a11c-de8011fd2205`. 기존 D1·변수·비밀값·10분 cron 유지. 운영 `/health` ok, today 응답의 새 판단 버전과 강수 구간 및 타임라인 시간을 확인했다.
- 에뮬레이터는 `adb install -r`로 데이터를 보존해 설치했다. 실제 서버 자료의 `16시 정시 예보`/`15~16시 강수 예보`, Today 시간 문구, 마지막 `23~24시 강수 예보` 및 다음 날 기온 미표시를 확인했다. 치명적 예외·RenderFlex·ParentData 오류 없음. Git 제외 이미지: `weather_care_app/build/ui-qa/detail-precipitation-time.png`, `detail-precipitation-midnight.png`.
- `docs/앱_탭_구성_현황.md`에 시간 계약·표시·검증 항목을 갱신했다. 다음 항목은 Setting의 GPS 권한·위치 갱신 흐름을 현재 코드와 대조하고 필요한 부분만 구현하는 것이다. 이어서 지역 직접 선택/저장. 문서의 설정 ‘UI 데모·저장 미구현’은 실제 코드의 로컬 저장·서버 동기화·시간 선택과 다르므로 그대로 믿고 재구현하지 않는다.
- 사용자 소유 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Setting GPS 권한·위치 갱신 연결

- 위치 확인 결과를 준비/확인 중/정밀·대략적 위치/기기 위치 기능 꺼짐/권한 거부·영구 거부/시간 초과/오류/서비스 범위 밖으로 구분했다. Setting에 상태·한국시간 확인 시각·재확인·앱 권한 설정/기기 위치 설정 버튼을 추가했다. 위치 실패를 날씨 서비스 미지원으로 표시하지 않고 `기준 위치를 확인해주세요`로 안내한다.
- 시작·앱 복귀·새로고침은 기존 위치 권한만 확인한다. 명시적 확인 버튼 또는 GPS 모드 선택 시에만 권한을 요청한다. Android에서 일반 거부로 반환되는 영구 거부도 설정 화면에서 복구할 수 있게 일반 거부 상태에도 앱 설정 버튼을 제공한다. 백그라운드 연속 추적은 추가하지 않았다.
- GPS 실패나 수동 지역 미선택 시 수원 격자로 대체하던 처리를 제거했다. 날씨를 비워 이유를 안내하고 잘못된 지역으로 조회/등록하지 않는다. 수동 모드는 기존 저장 `nx_ny`가 유효할 때만 사용한다. 새 지역 선택 UI는 아직 미구현이다.
- 위치 요청은 8초 제한, 측정 자료는 과거 2분/미래 1분 허용 범위로 확인한다. 좌표는 서버와 같은 사각 지원 범위(위도 30~44, 경도 120~134)를 검사한다. 대한민국 행정 경계 검증은 아니다. 이 값들은 위치 자료 운영 기준이며 날씨 정확도·체감 기준으로 쓰지 않는다.
- 기기 정밀 위치 상태와 실제 정확도(0m 초과, 500m 이하)가 함께 확인되어야 강수·도로 정밀 분석용 좌표를 전송한다. 정확도 누락/불확실/대략적 권한이면 지역 격자만 사용하고 날씨 조회·설치 등록에는 위경도를 보내지 않는다. 500m 자료 정확도를 보장한다는 뜻이 아니다. 원시 위치를 새로 로컬 저장하거나 로그에 기록하지 않는다.
- 새로고침은 GPS를 다시 읽고, 기기 설정에서 복귀해도 갱신한다. 중복 요청을 합치고 위치 모드/지역 변경 중 늦게 도착한 이전 위치·날씨 응답을 버린다. 서버 설정 저장은 순서를 유지하되 지연/실패가 GPS·날씨 갱신을 막지 않도록 분리했다. 기존 알림 시간 선택·설정 저장을 유지했다.
- FCM 토큰 갱신이 앱 시작 당시 좌표를 계속 쓰던 문제를 수정했다. 최신 확인 위치를 등록하고 등록 HTTP 요청을 직렬화한다. 정밀→대략적/수동 전환은 서버 등록 위경도를 null로 갱신한다. 위치 확인 실패는 로컬 등록 대상을 무효화해 토큰 갱신으로 이전 좌표를 재전송하지 않는다.
- 한계: 실패 시 이미 서버에 등록된 마지막 지역/좌표를 지우거나 알림을 중단하지는 않는다. 화면에 `알림은 서버에 마지막으로 등록된 지역 기준이에요`를 안내한다. 서버 저장 결과·OS 알림 권한 표시와 등록 위치 유효기간은 후속 검토 대상이다. 이번에는 서버 코드·DB·배포·발송 정책을 변경하지 않았다.
- 검증: 신규 테스트 35개 포함 전체 Flutter `187 tests`, `flutter analyze`, Android debug APK 빌드 통과. 권한 분기·대략적 위치·측정 시각/정확도·설정 열기 실패·위치 오류·모드 전환 경쟁·지연된 날씨 응답·설정 저장 실패/순서·FCM 최신 지역/등록 순서·360px 2배 글씨를 검증했다. 실제 테스트 푸시는 발송하지 않았다. iOS 실기기/빌드는 Windows 환경에서 검증하지 못했다.
- 에뮬레이터에 `adb install -r`로 데이터 유지 설치했다. 대략적 위치 안내, 권한 거부 후 버튼으로만 권한 요청, 기기 위치 기능 꺼짐, 설정 화면 열기와 복귀 후 자동 복구를 확인했다. 위치 기능 비활성화 직후 진행 중이던 요청의 OS 위치 정확도 팝업은 거절했고 시간 초과 안내 후 재확인 시 꺼짐 안내를 확인했다. 테스트 후 위치 기능과 기존 정밀/대략 위치 권한을 허용 상태로 복구했다. Git 제외 화면: `weather_care_app/build/ui-qa/settings-location-approximate.png`, `settings-location-disabled.png`, `settings-location-denied.png`.
- `docs/앱_탭_구성_현황.md`의 수원 고정·설정 UI 데모·저장/시간 선택 미구현 등 오래된 설명을 실제 코드에 맞췄다. 다음 항목은 **지역 직접 선택 화면과 선택 지역 저장/조회 연결**이다. 기존 로컬 저장·서버 동기화·시간 선택을 새로 구현하지 않는다. 지역명은 현재 서버가 일반적으로 `선택 지역`을 반환하는 한계도 함께 검토한다.
- 사용자 소유 미추적 `scripts/*`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Setting 전국 지역 직접 선택·저장·조회 연결

- 기상청 날씨누리 공개 행정동 목록의 현행 이름·예보 격자 3,838행을 앱 자산 `assets/data/kma_regions.json`으로 포함했다. 시·도 16, 시·군·구 257, 하위 지역 3,565이며 2026-09-10T07:50:50Z 수집본이다. 과거 17개 시·도 명칭으로 임의 보정하지 않았다. 원본 URL·요청 계약·갱신 절차는 `assets/data/README.md`, 재생성은 신규 `scripts/update_region_catalog.ps1`에 기록했다. 스프레드시트 대신 기상청 웹의 공개 JSON 목록을 사용했고 인증키나 사용자 위치 없이 수집했다.
- 원본 코드 `2815555000`이 영종구 용유동(50,124)과 운서2동(52,125)에 중복 사용되는 것을 확인했다. 행을 삭제하거나 코드를 만들어내지 않고 `코드|이름|X|Y`를 앱 선택 키로 사용한다. 원본 이름·격자·상위 코드 전체를 보존하고 세종의 연속된 같은 지역명만 화면에서 한 번 표시한다.
- Setting의 `지역 직접 선택`에서 시·도 → 시·군·구 → 읍·면·동 계층 탐색과 전국 이름 검색을 제공한다. 다중 검색어, 부산시/경남/충북 등 약칭, 좌동/좌1동/좌제1동을 지원하고 동명 지역은 전체 상위 지역명으로 구분한다. 검색 결과는 SliverList로 보이는 행만 만든다. 자료 로딩 실패·재시도·빈 결과와 출처/목록 확인일을 안내하며 목록 검색에는 인터넷이 필요 없다.
- 새 지역은 확인 대화상자의 `이 지역 사용`을 눌러야 저장한다. 취소·뒤로가기는 기존 설정을 유지한다. 시·도/시·군·구 대표 지점도 선택 가능하지만 지역 전체의 동일한 날씨를 뜻하지 않는다고 설명한다. 수동 모드에서 `지역 선택·변경`을 제공하고 대표 지점을 사용자 정밀 위치로 사용하지 않는다.
- `AppSettings.manualRegionKey`와 기존 `currentRegion` 격자를 기기에 저장한다. 재시작 시 공식 목록의 키로 이름/격자를 복원하고 GPS 모드로 전환해도 마지막 수동 선택을 보존한다. 키가 없는 구버전 저장 격자는 기존대로 지원하지만 키가 있는 저장값이 새 목록에서 사라지거나 격자가 바뀌면 이전 격자로 대신 조회하지 않고 재선택을 요청한다.
- Home의 날씨 조회와 알림 설치 등록에 같은 선택 격자를 연결한다. 수동 모드는 GPS를 읽거나 위경도를 전송하지 않는다. 서버 설정에는 로컬 선택 키를 제외해 기존 `currentRegion: nx_ny` API 계약을 유지한다. 초기 설정/목록 로딩 중에는 설정 조작을 막아 임시 설치 ID로 저장하지 않는다.
- 날씨 응답 격자가 선택 격자와 일치할 때 Main·Today 등 앱 지역 표시를 선택한 전체 이름으로 바꾼다. 같은 격자의 다른 동 선택도 이름이 바뀐다. 다른 격자의 응답은 표시하지 않는다. 서버의 공식 근거 문장 원문은 치환하지 않으므로 해당 문장에는 기존 `선택 지역` 표현이 남을 수 있다. GPS 역지오코딩은 이번 범위가 아니다.
- 검증: 신규 19개 포함 전체 Flutter `206 tests`, `flutter analyze`, Android debug APK 빌드 통과. 전국 행/계층·섬 지역 격자·동명/중복 코드·약칭·확인/취소·재시도·360px 2배 글씨·지연 생성·저장/재시작·GPS 전환·같은 격자의 다른 동·잘못된 응답 격자·서버 API 키 제외를 검증했다. 이번 변경은 앱과 공개 목록 자산이며 서버 코드·DB·운영 배포는 변경하지 않았다. iOS 실기기/빌드는 미검증이다.
- 에뮬레이터에 `adb install -r`로 데이터를 유지한 채 설치했다. 전국 목록 → 부산 → 해운대구 → 좌제1동(100,76) 확인·선택, 실제 서버 예보와 전체 지역명, 앱 강제 종료/재실행 후 같은 선택 복원을 확인했다. 검증 후 GPS 모드로 복구했으며 마지막 수동 선택은 좌제1동으로 남아 있다. 직접 테스트 푸시는 보내지 않았다. Git 제외 화면: `build/ui-qa/region-list.png`, `region-selected.png`, `region-restored.png`.
- 전국 선택이 모든 환경자료의 전국 지원을 뜻하지는 않는다. 실제 부산 조회에서는 자외선·기온·풍속 등을 받았고 대기질은 기존 서버의 지역 미지원 안내가 표시됐다. 서버 공식 근거 원문 지역명 및 대기질 확장은 별도 작업이다. 또한 운영 Main에서 현재 시각보다 앞선 UV 행동 시간이 남는 것을 관찰했으며 이번 지역 선택 작업에서는 판단 시간 로직을 수정하지 않았다.
- `docs/앱_탭_구성_현황.md`의 지역 선택 항목을 완료했다. 다음 항목은 **Setting의 서버 저장 결과·OS 알림 권한 상태 안내**다. 이미 구현된 알림 시간 선택/저장과 전체 알림 하위 값 보존은 재구현하지 말고 실제 발송 계약과 함께 점검한다.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Setting 저장 결과·기기 알림 권한 연결

- 전체 알림 스위치 아래에 `저장·기기 알림 상태`를 추가했다. 확인 중/저장 중/기기 저장 실패/기기 저장 완료·서버 반영 미확인/양쪽 저장 완료를 구분한다. 실패 시 현재 최신 설정으로 다시 저장하는 버튼을 제공하고, 서버 반영 미확인에는 이전 설정으로 알림이 발송될 수 있다고 안내한다. 통신 시간 초과는 실제 서버 반영 여부를 단정할 수 없어 `서버 반영을 확인하지 못했어요`로 표현했다.
- 저장 큐를 별도 컨트롤러로 분리했다. 요청 순서를 유지하고 최신 변경 결과만 화면에 반영한다. SharedPreferences의 false 반환도 실패로 처리한다. 날씨 조회/서버 오류 대화상자를 저장 큐에서 분리해 다음 설정 변경을 막지 않는다. 시작·변경·명시적 재시도로 동기화하며 무한 자동 재시도는 하지 않는다.
- 실제 에뮬레이터 검증에서 기존 저장 API 계약 오류를 발견했다. 알림 설정 서버는 strict 스키마인데 앱은 installationId/locationMode/currentRegion/onboardingCompleted 등 로컬 설정까지 보내 저장에 실패하고 오류를 숨기고 있었다. 이제 `/notification-settings/:installationId`에는 전체 알림·시간·준비물 6종·기상/날씨 6종의 14필드만 전송한다. 위치는 기존 별도 `/installations/:installationId` 등록과 nx/ny 쿼리로 전달한다. 앞선 지역 선택 기록의 ‘알림 설정에도 currentRegion 전송’ 설명은 이번 수정으로 대체된다. 서버 코드·DB·배포는 변경하지 않았다.
- 기기 알림 상태는 확인 중/미요청/미허용/영구 차단/허용/조용한 알림만 허용/확인 실패를 구분한다. 설치 버전 firebase_messaging 16.6.0 및 플랫폼 인터페이스 4.10.0의 Android deniedPermanently를 처리한다. iOS 거부에는 앱 설정 경로도 제공한다. 근거: https://firebase.google.com/docs/cloud-messaging/flutter/receive 및 설치 패키지 소스/변경 기록.
- 자동 FCM 등록의 권한 요청을 제거했다. 권한 요청은 Setting의 명시적 버튼으로만 수행하며, 시작·새로고침·앱 복귀는 읽기만 한다. 수동 지역/위치 미확인에서도 권한 상태를 읽는다. 중복 요청을 합치고 조회 중 복귀하면 다시 읽어 이전 결과가 남지 않게 했다. 기기 앱 설정의 알림 메뉴를 열 수 있도록 일반 앱 설정 링크와 열기 실패 안내를 제공한다.
- 권한 변경 뒤 유효한 지역이 있으면 설치 등록을 갱신한다. 등록 큐 실행 시 권한을 읽어 대기 중인 토큰 갱신이 차단 후 토큰을 재등록하지 않게 했다. 앱 알림 스위치와 OS 권한은 별개이며, 전체 알림 끄기는 하위 값을 보존한다. 서버 반영 전/처리 중/이미 발송된 알림의 도착 가능성을 안내한다.
- 한계: 카드의 저장 성공은 알림 설정 API의 성공 응답이며 토큰 발급·설치 등록·실제 수신 성공이 아니다. 개별 Android 채널·집중 모드·소리 설정도 이 상태로 판별하지 않는다. 실제 테스트 푸시는 보내지 않았다. iOS 빌드/실기기는 Windows에서 미검증이다. 기존 위치 실패 시 서버 마지막 지역 유지 제한도 그대로다.
- 검증: 신규 28개 포함 전체 Flutter `234 tests`, `flutter analyze`, Android debug APK 빌드 통과. 저장 실패/재시도/순서 경쟁/날씨 요청과 분리, 14필드 API 계약과 끄기 값, 권한 상태별 분기/명시적 요청/수동 지역 복귀/조회 중 복귀/설정 열기 실패/토큰 대기 중 권한 변경, 360px 2배 글씨를 검증했다.
- 에뮬레이터에 앱 데이터를 유지해 설치했다. 기기 앱 설정 열기→알림 차단→복귀 시 미허용 안내, 명시적 요청→Android 허용 창→허용 복구를 확인했다. 실제 서버 저장 성공 후 운영 GET 조회의 알림 설정 14개가 기기 저장값과 일치함을 확인했다(설치 ID·토큰 출력 없음). 통신을 끄고 전체 알림 변경 시 서버 반영 미확인/재시도/하위 비활성화를 확인한 뒤 원래 전체 알림 켜짐 및 Wi-Fi·모바일 데이터·기기 알림 허용을 복구했다. 로컬 저장 실패는 모의 테스트로 검증했으며 실제 디스크 장애는 만들지 않았다. Git 제외 화면: `build/ui-qa/settings-notification-denied.png`, `settings-save-offline.png`, `settings-save-recovered.png`.
- `docs/앱_탭_구성_현황.md`를 실제 API 계약과 완료 범위에 맞게 갱신했다. 다음 항목은 **알림 종류별 스위치·표현 명칭과 서버 실제 발송 조건 대조 및 불일치 수정**이다. 기존 알림 시간 선택/전체 알림 하위 값 보존/권한 요청 UI를 재구현하지 않는다. 운영 Main의 지난 UV 행동 시간, 대기질 전국 지원 등은 별도 남은 항목이다.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Setting 알림 명칭·실제 발송 계약 대조

- 화면 스위치 → 14필드 설정 API → D1 → 추천/특보/현재 비/도로 발송 경로를 대조했다. 서버의 기존 필터가 동작함을 확인했으며 발송 정책·임계값·API 이름·저장값을 변경하지 않았다. 새 개별 스위치나 독립 푸시 종류도 추가하지 않았다.
- Setting 명칭을 실제 범위에 맞췄다. 많은 비 → `호우특보 안내`, 많은 눈 → `대설·많은 눈 안내`, 고온/저온 → `폭염특보 안내`/`한파특보 안내`, 소나기·약한 비 → `현재 비 안내`, 오늘 날씨 → `준비물 요약 알림`. 특보는 발효 상태 진입·단계 변경·해제이며, 대설 항목은 예보 기반 많은 눈 대비 별도 알림도 포함한다고 설명한다.
- 현재 비는 소나기 예보 알림이 아니라 관측분석·레이더 일치 조건이다. 우산과 현재 비 스위치가 함께 켜져야 하며 서버에 등록된 정밀 좌표가 필요함을 명시했다. 과거 필드명 `showerAndLightRainEnabled`는 그대로 유지한다. 우산 스위치에도 준비물 요약과 현재 비에 함께 쓰인다고 설명한다.
- 준비물 요약은 추천·알림 적격 항목이 있을 때만 하루 한 번 최대 3개를 보낸다. 준비물 요약 끄기는 특보·현재 비·많은 눈·도로 안내를 끄지 않는다. 개별 스위치가 없는 블랙아이스(도로살얼음)·도로통제·그 밖의 공식 특보는 전체 날씨 알림 설정을 따른다는 기존 동작을 화면에 명시했다. 원하는 경우 이를 개별 제어하도록 바꾸는 것은 별도 정책 변경이다.
- 알림 시간은 준비물 요약 전용으로 설명하고 `매일 아침`을 `설정 시각`으로 정정했다. 기존 서버의 10분 경계 올림을 표시용 헬퍼로 반영했다(07:35 → 07:40, 23:55 → 다음 날 00:00). 사용자 저장 시각을 변경하지 않고 실제 도착 지연 가능성을 안내한다. 요약이 꺼졌으면 다시 켜야 적용됨을 표시한다.
- 검증: 앱 신규 24개 포함 전체 Flutter `258 tests`, `flutter analyze`, Android debug APK 빌드 통과. 서버 신규 20개 포함 전체 `26 files / 163 tests`, `tsc --noEmit` 통과. 하위 12종이 자기 필드만 변경하는지, 시간 경계/자정/잘못된 저장값, 360px 2배 글씨, 준비물 6종·특보 4종의 시작/변경/해제·현재 비 4조합·전체 끄기·별도 알림 독립성·추천 없음/요약 최대 3개를 검증했다.
- 서버 테스트는 로컬 Workers API와 D1을 사용하고 발송 함수는 모의 구현으로 주입했다. 운영 발송·DB 변경·배포는 하지 않았다. 로컬 비밀값 미설정 경고는 이전과 같고 테스트 통과에 영향 없다. Cloudflare 스킬에 따라 런타임/바인딩 사용과 안전한 검증 범위를 확인했다.
- 에뮬레이터에 데이터를 유지해 설치하고 실제 설정 저장 성공, 새 명칭/조건 설명, 07:00 서버 확인 시각, 하단 추가 안내를 확인했다. 기존 전체 알림 켜짐·07:00·GPS·권한 값을 변경하지 않았다. 치명적 Flutter/AndroidRuntime 로그 없음. Git 제외 화면: `build/ui-qa/notification-schedule-contract.png`, `notification-types-contract.png`. iOS 빌드/실기기는 미검증이다.
- 신규 `docs/알림_설정_발송_계약.md`에 화면·API·발송 대응표, 종속 관계, 개별 스위치 없는 항목과 한계를 정리했다. `docs/앱_탭_구성_현황.md`의 해당 체크를 완료했다. 다음 항목은 **Setting의 데이터 출처·위치/알림 권한 안내 위치와 내용 정리**다. 법적 개인정보처리방침을 사업자/보유기간 확인 없이 임의 확정하지 않는다. 운영 Main의 지난 UV 행동 시간과 대기질 전국 지원은 별도 후속 항목이다.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Setting 데이터 출처·권한·정보 사용 안내

- Setting 하단의 9px 출처 문구를 `데이터·권한 안내` 카드로 교체했다. 데이터 출처 / 위치 권한 / 알림 권한 / 저장·전송 정보의 네 읽기 전용 화면을 추가하고, 기준 지역과 저장·기기 알림 상태 카드 옆에서도 해당 권한 설명을 열 수 있도록 했다. 전체 알림을 꺼도 접근하며 안내 진입은 설정 변경·권한 요청·테스트 발송을 하지 않는다.
- 예보·자외선·특보에 더해 관측분석/레이더·미세먼지/초미세먼지/오존·도로 결빙 가능정보·ITS 도로통제 출처를 실제 Provider와 대조했다. 예상기온은 예보값이며, 사용자 지점 실측과 격자/측정소 자료를 구분한다. 전국 선택이 개별 환경자료의 전국 지원을 뜻하지 않음과 자료 없음이 안전 보장이 아님을 명시했다. 수치·체감·발송 정책은 변경하지 않았다.
- 선택 권한, 수동 지역 대안, GPS 확인 시점, 정밀 위치 조건, 알림 수신 한계를 설명한다. 위치 권한 해제·알림 끄기가 서버 저장 정보 삭제를 뜻하지 않으며 마지막 등록 지역으로 알림이 올 수 있음을 명시했다. 실제 설치/조회 API·저장소 기준으로 설치 식별자·격자·조건부 좌표·토큰·설정·발송 상태/이력을 안내한다. 완전 익명·무저장·즉시 삭제를 약속하지 않았다.
- FCM 외에 포함된 Firebase Analytics와 초기화되는 Google Mobile Ads도 안내하고 제공업체 문서를 연결했다. 이 화면은 기능 안내이며 법적 개인정보처리방침이 아니다. 운영 주체/연락 경로/보유·삭제 조건/외부·국외 처리/콘솔의 실제 SDK 설정·공개 URL은 별도 확인이 필요하다. 이 조건을 임의 확정하거나 수집/삭제 기능을 변경하지 않았다.
- 공식 HTTPS 링크를 외부 브라우저로 여는 `url_launcher 6.3.2`를 추가했다(전이 의존성 7종, 기존 패키지 업그레이드 없음). false/예외는 선택 가능한 주소와 복사로 복구하고, 중복 누름·복사 실패·화면 종료 후 결과를 처리한다. 안내 본문은 오프라인으로 읽으며 외부 링크에는 사용자 위치·식별자·키를 넣지 않는다. 추가 OS 권한이나 사전 URL 조회용 manifest 설정 없음.
- 검증: 신규 18개 포함 전체 Flutter **276 tests**, `flutter analyze`, Android debug APK 빌드 통과. 안내 4종 진입/복귀·기존 설정 보존·권한 제어 옆 바로가기·360px/2배 글씨의 설정 카드와 모든 본문/링크·공식 HTTPS 주소·브라우저 성공/실패/예외·중복 실행·주소 복사/실패·닫힌 화면의 비동기 완료를 확인했다.
- 에뮬레이터 `adb install -r`로 데이터 유지 설치 후 안내 4종과 복귀를 확인했다. 기상청 링크는 Chrome `FirstRunActivity`로 외부 실행되는 것을 확인했고 브라우저 최초 설정에 동의하거나 본문 로딩 완료를 주장하지 않았다. 돌아오면 기존 안내 화면이 유지된다. GPS/07:00/기존 토글·권한 값은 변경하지 않았으며 실제 테스트 푸시를 보내지 않았다. Flutter/AndroidRuntime 치명 로그 없음. Git 제외 화면: `build/ui-qa/settings-guides.png`, `settings-data-sources.png`, `settings-data-use.png`. iOS 빌드·실기기는 미검증이다.
- 신규 `docs/설정_데이터_권한_안내.md`에 코드 근거·출처·비법적 안내의 범위와 남은 확인을 기록하고 탭 현황의 해당 체크를 완료했다. 이번 변경은 앱/문서만이며 서버 API·DB·운영 배포에는 변경 없음.
- 다음 코드 작업 권장: **Main에서 이미 지난 자외선 행동 시간이 노출되는 문제를 재현하고 시간 선택/만료 처리를 수정**한다. 대기질 전국 지원은 이후 별도 항목이다. 정식 개인정보처리방침은 위 운영 정보가 필요하므로 자동 채택하지 않는다.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 Main 행동 시간 선택·만료 및 자외선 날짜 수정

- 운영 재현: 18:15 KST의 수원 격자 응답이 `오전 9시` 양산 준비를 표시했다. 현재 UV는 0이었고 실제 해당 UV 6 예보는 다음 날 9월 11일 09시였다. 날짜가 빠져 이미 지난 오전처럼 보였다. 코드상으로도 가까운 정시 자료가 현재 시각보다 과거일 때 끝난/진행 중인 구간 구분 없이 원래 정시를 행동 시간으로 썼다.
- `weatherBrief.ts`에 명시적 `now`를 받아 시간순 후보를 확인하도록 했다. 진행 중인 시간대는 `지금`, 미래는 해당 시각, 날짜가 다르면 월·일을 붙인다. 종료·잘못된 시각/기한·24시간 이상 뒤 후보는 제외한다. 눈/비/대기질/자외선·더위/겉옷/바람의 기존 우선순위와 수치 기준은 보존한다. 유효한 조건이 없으면 기존 시간별 예보 확인 문구를 쓴다.
- 정시 자료는 최대 한 시간이며 더 이른 `validTo`가 있으면 그 경계부터 숨긴다. PCP/SNO는 이전 한 시간 구간을 따로 적용하고 종료된 강수는 재사용하지 않는다. 원시 `forecastAt`, 관측 시각, 수치·기간을 수정하지 않는다. `WEATHER_BRIEF_CATALOG_VERSION`은 `weather-brief-2026.09.3`이다.
- Today 응답에 선택적 `briefExpiresAt`을 추가했다. 미래 행동은 시작 시각, 현재 행동은 끝 시각부터 표시를 중단한다. `brief` 문자열은 유지하고 응답 생성 시각을 판단에 함께 사용한다. 별도 DB 스키마·설정·발송 정책 변경은 없다.
- 앱 `WeatherBriefText`가 기한 경계/최대 1분 간격/앱 복귀에 만료를 확인한다. 지난 행동 대신 `안내 시간이 지났어요. 화면을 아래로 당겨 최신 예보를 확인하세요.`를 표시하고 잘못된 기한은 확인 불가로 구분한다. 타이머 취소·새 응답·dispose·수동 지역명 변경 시 기한 보존을 처리했다. 자동 API/위치 요청은 추가하지 않았다. 기한이 없는 구버전·직접 기상청 응답은 기존 표시를 유지한다.
- 에뮬레이터에서 자외선 근거에도 다음 날 날짜가 빠져 있음을 확인해 양산/선크림의 공식 UV 근거에 조회일과 다른 예보일을 붙였다. 공식 근거의 수치·유효 시각과 사실 역할은 보존한다. 다른 현상의 날짜 표기나 전체 생활 카드/타임라인의 만료 정책은 이번 범위 밖이다.
- 검증: 신규 앱 14개 포함 전체 **290 tests**, `flutter analyze`, Android debug APK 빌드 통과. 서버 신규 21개 포함 전체 **27 files / 184 tests**, `tsc --noEmit` 통과. 정각 전/후·이미 종료·UTC/KST·다음 날·연말·잘못된 시간·강수 구간·API 직렬화·원시 예보 보존·앱 복귀/시계 변경/새 응답·실제 Main 연결을 검증했다. 로컬 비밀값 누락 경고는 기존과 같고 실제 테스트 푸시는 보내지 않았다.
- Cloudflare/Workers 모범 사례 스킬에 따라 최신 문서와 타입, 기존 바인딩을 확인하고 dry-run 후 운영 변수 보존 배포를 했다. 변경 전 운영 버전 `5c1eaba2-4c91-4c6c-a11c-de8011fd2205`. 1차 요약 수정 버전 `c9190f4a-9b25-4b00-acdf-9559076447e9` 뒤 UV 근거 날짜까지 포함한 **최종 운영 버전 `fe8b0f57-89ea-4fa6-b2fd-bcd836d32b44`**를 배포했다. 운영 URL: `https://weather-care-server.sy40222.workers.dev`. secret·DB 스키마·10분 스케줄 변경 없음.
- 운영 `/health` 정상, 수원 Today의 `9월 11일 오전 9시`와 `briefExpiresAt=2026-09-11T00:00:00Z`, UV 공식 근거의 `9월 11일 오전 10시`를 확인했다. 요약은 최초 해당 시간, 생활 근거는 기존 UV 판단 구간의 대표 시각을 사용하므로 시각이 동일할 필요는 없다. 에뮬레이터 현재 등록 지역에서는 요약·근거에 `9월 11일 오후 12시`가 함께 표시됨을 확인했다.
- 에뮬레이터에 `adb install -r`로 데이터 유지 설치 후 새로고침/표시를 확인했다. 사용자 지역·알림 토글·권한·기기 시계는 변경하지 않았다. 만료 시각까지 실시간 대기하지 않고 테스트의 고정 시계/타이머로 검증했다. 치명적 Flutter/AndroidRuntime 로그 없음. Git 제외 화면: `build/ui-qa/main-brief-date.png`. iOS 빌드·실기기는 미검증이다.
- `docs/Main_시간별_행동_안내.md`에 계약과 한계를 기록하고 `docs/앱_탭_구성_현황.md`의 오래된 감성 브리핑 설명을 실제 이유 우선 행동 요약으로 정정했다. 다음 항목은 **대기질 전국 지원: 현재 지역 매핑/측정소 선택의 제한을 확인하고 전국 조회 연결을 구현**하는 작업이다. 정식 개인정보처리방침은 운영 정보 확인이 필요한 별도 항목으로 유지한다.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 대기질 전국 격자 조회·측정소 캐시 연결

- 사용자 요청 `다음 항목 진행`에 따라 직전 인계의 대기질 전국 지원을 구현했다. 변경 전 정밀 좌표 없는 부산 `(100,76)` 조회가 `UNSUPPORTED_REGION`인 것을 운영에서 재현했다. 원인은 서울·수원 2개 정적 지역 매핑 의존이었다.
- 새 `kmaGridCoordinates.ts`로 전국 기상청 격자의 대표 좌표를 역변환한다. 기상청 `fn.js`의 `convertDfsGrid`를 독립 실행해 기준점·서울·수원·부산·제주·울릉·독도·서해 도서의 값과 비교했다. 정밀 GPS가 있으면 그대로 사용하고, 없으면 요청 격자 대표 지점을 사용한다. 다른 정적 지역 메타데이터가 요청 격자를 덮어쓰지 않도록 했다. 대표 지점은 실제 GPS 측정 위치로 취급하지 않는다.
- 에어코리아 측정소 전체 목록을 페이지 정보와 총건수로 검증해 받고 유효 좌표를 직선거리 순으로 정렬한다. 최대 5개 후보에서 실제 사용 가능한 한 측정소 자료를 선택하며 PM10/PM2.5/오존을 서로 다른 측정소 값으로 조합하지 않는다. 부정확한 관측 시각·음수 결측·요청과 다른 측정소 값은 사용하지 않는다. 공식 관측값을 바꾸거나 새 체감·수치 기준을 만들지 않았다.
- 전국 측정소 목록은 기존 D1 `weather_cache`의 `AIR_STATIONS_V1`에 24시간 공유한다. 정상 완료 목록만 캐시하며 페이지 누락/반복·최대 10페이지·응답당 2MiB 제한을 검사한다. 관측은 `AIR_STATION_V1_{측정소명}` 단위 30분 캐시로 바꿔 같은 격자의 서로 다른 GPS 위치 캐시가 섞이지 않도록 했다. 기존 격자별 AIR 캐시는 읽지 않고 삭제도 하지 않았다. 새 사용자 좌표 저장은 없으며 공개 측정소 좌표만 목록에 저장한다.
- 관측 캐시의 기존 3시간 stale fallback과 Provider의 과거 4시간/미래 1시간 관측 허용 범위는 유지하되, 캐시 재사용 때도 관측 시각을 확인한다. 목록 갱신 실패나 자료 결측이면 `UNAVAILABLE`, 유효하지 않은 격자면 미지원으로 구분한다. 전국 대기질 외부 요청은 공통 6초 제한이며 Today의 기존 선택 Provider 대기 예산/완료 후 캐시 흐름은 유지한다. Today와 스케줄러가 같은 environmental loader를 사용한다. 발송 조건·수치·설정·중복 방지 변경 없음.
- Flutter CurrentWeather가 기존 서버의 `airQualityStationName`/`airQualityObservedAt`을 읽는다. Detail 미세먼지/초미세먼지 팝업에 실제 측정소·한국 월일시분·사용자 지점 실측이 아님을 표시하고, 정보가 없으면 지역명/예보 시각으로 대신 만들지 않는다. 팝업은 큰 글씨에 스크롤 가능하다. Setting 데이터 출처 안내에 전국 GPS/격자 차이와 가까운 측정소 결측 시 다음 후보 확인을 설명했다.
- 검증: 전체 서버 **29 files / 212 tests**, `tsc --noEmit`; 전체 앱 **294 tests**, `flutter analyze`, Android debug APK 빌드 통과. 전국 격자/GPS 우선·측정소 캐시 분리·기존 캐시 무시·오래된 관측·페이지 처리·오류/결측/크기 제한·UTC/KST 표시·결측·360px/2배 글씨를 확인했다. 기존 로컬 비밀값 누락 경고 외 실패 없음. 실제 테스트 푸시는 발송하지 않았다.
- Cloudflare/Workers 스킬의 최신 문서·Workers 타입 `5.20260910.1`·로컬 Wrangler 스키마를 확인했다. 의존성/설정 변경 없이 `wrangler deploy --dry-run --keep-vars` 후 기존 승인 범위에서 운영 배포했다. 변경 전 `fe8b0f57-89ea-4fa6-b2fd-bcd836d32b44`, **현재 운영 버전 `be6a875e-55c3-4e21-837b-641ecd195f50`**. URL `https://weather-care-server.sy40222.workers.dev`. 비밀값·바인딩·DB 스키마·10분 cron 변경 없음. `/health` 정상.
- 18:37 KST에 좌표 없는 운영 실조회 9곳 모두 HTTP 200 / AIRKOREA AVAILABLE: 서울→종로, 부산→좌동, 대전→월평동, 광주→치평동, 대구→남산1동, 춘천→신사우동, 제주→연동, 울릉→울릉읍, 백령→백령도. 각 관측은 9월 10일 18시 자료였다. D1 읽기 전용 집계로 검증 목록 672개 및 중복 측정소명 없음 확인. 모든 전국 격자/매시각 제공을 검증한 것은 아니다. Windows에서의 API 직접 호출은 timeout이었으나 운영 Worker에서는 정상 조회됨을 확인했다.
- 에뮬레이터 `adb install -r` 데이터 유지 설치 후 Main의 PM2.5 수치와 Detail의 `인계동 측정소 · 9월 10일 18시 00분 관측` 표시를 확인했다. 지역·권한·알림 설정·시계를 바꾸지 않았다. Flutter/AndroidRuntime 오류 로그 없음. Git 제외 이미지 `weather_care_app/build/ui-qa/air-nationwide-main.png`, `air-station-source.png`. iOS·실기기는 미검증이다. 임시 운영 tail 세션은 종료했다.
- `docs/대기질_전국_조회.md`에 조회·캐시·한계·검증과 공식 근거를 기록하고 탭 현황/설정 출처 문서를 갱신했다. 전국 조회는 모든 지점의 실측이나 측정소 대표성/정확도를 보장하지 않는다. 가까운 측정소는 행정경계를 넘거나 멀 수 있고 API 점검/결측/호출 한도가 남는다. 호출 한도 자동 증설·계약 변경은 하지 않았다.
- 다음 확인 항목은 **정식 개인정보처리방침의 운영 주체·연락 경로·보유/삭제 조건·외부 처리·공개 URL 확인 후 연결**이다. 이는 사용자 확인이 필요한 별도 항목이며 기능 안내를 법적 방침으로 대체하지 않는다. 사용자 정보 없이 임의 확정하지 말 것. 이용자 확대 전 API 계정 호출 한도 점검도 별도 운영 확인으로 유지한다.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-10 개인정보처리방침 연결 준비·운영자 확인 대기

- `다음 항목 진행`에 따라 직전 인계의 정식 개인정보처리방침 연결을 시작했다. 기존 데이터·권한 안내, 앱 초기화/SDK 의존성, 등록 API·저장소·마이그레이션과 삭제 경로를 읽기 전용으로 확인했다. 서버 설치 식별자·토큰·격자·조건부 좌표·설정/발송 이력 저장은 확인되나, 사용자 정보 삭제 UI/API와 명시적으로 확정된 보유기간은 없다.
- 운영자/사업자명, 실제 개인정보 문의 이메일, 보유·삭제 기준과 공개 방침 URL은 확정된 자료가 없다. 패키지명이나 저장소/계정 이름으로 추정하지 않았다. 사용자에게 먼저 **공개할 운영자명(개인 운영/사업자 구분 포함)과 개인정보 문의 이메일**을 요청한다. 이 확인 없이는 정식 본문/공개 페이지 연결을 완료할 수 없다.
- `docs/개인정보처리방침_준비점검.md`에 코드로 확인한 사실, 사용자 결정 항목, 이후 보유·삭제→SDK/외부 처리→공개 URL/앱 연결 순서를 기록했다. 내부 점검표이며 공개 방침이나 법적 준수 완료가 아니다. 운영자명·이메일을 받더라도 다른 미확정 사항을 자동 확정하지 말 것.
- Google Play 사용자 데이터 정책의 방침/문의 경로/보관·삭제/공개 URL 요건을 확인했다. 개인정보 포털의 2026 작성지침 게시 사실은 검색 목록으로 확인했지만 첨부 전문은 읽지 않았으므로 준수 검토를 완료했다고 주장하지 않았다. 앱 내 회원가입과 설치 식별자를 혼동해 계정 삭제 정책 적용을 단정하지 않았다.
- 문서만 추가·기록했다. 앱/서버 코드·비밀값·SDK 수집/동의 설정·보유기간·DB 데이터 변경, 새 삭제 기능, 운영 배포, 테스트 푸시 없음. 문서 경로 및 diff를 검토하며 실행 코드가 바뀌지 않아 앱/서버 테스트를 재실행하지 않았다. 운영 버전은 `be6a875e-55c3-4e21-837b-641ecd195f50` 유지.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정하거나 커밋하지 않았다.

## 2026-09-11 개인정보처리방침 운영자 정보 확정

- 사용자가 운영 형태 `개인사업자`, 표기명 `코드소하(CODESOHA)`, 개인정보 문의 이메일 `sy40222@gmail.com`을 제공했다. `docs/개인정보처리방침_준비점검.md`에 확정 정보로 기록하고 운영자 확인 단계를 완료로 표시했다. 사업자등록 확인이나 별도의 책임자 개인 성명 확인을 한 것은 아니다.
- 공개 방침 작성/배포, 보유·삭제 기간, 외부 서비스 설정은 여전히 미확정이다. 사용자 답변을 그 항목들에 대한 승인으로 확대하지 않았다. Google Play 사용자 데이터 정책의 문의·보관/삭제 정책 항목을 다시 확인했으나 설치 식별자를 회원 계정으로 간주하지 않았다.
- 다음 결정으로 **Setting의 `내 정보 삭제`에서 대상·알림 중단 영향을 안내하고 재확인 후 해당 설치의 앱 서버 등록정보·좌표·토큰·설정·발송 상태/이력을 삭제하는 방향**을 제안한다. 아직 미확정이며 삭제 기능을 구현하거나 실제 정보를 삭제하지 않았다. 구현 시 설치 소유 검증, 발송/재등록 경합, 재시도·실패 처리를 먼저 설계해야 한다. 식별자만으로 삭제 권한을 부여하지 말 것.
- 일반 보유기간·장기 미사용 정리·백업/로그·Firebase/광고 정보 처리 범위는 별도로 결정해야 한다. 위 삭제 방향의 승인만으로 임의 기간을 확정하거나 외부 정보까지 즉시 영구 삭제된다고 안내하지 말 것.
- 문서 2개만 변경했다. 앱/서버 실행 코드·비밀값·운영 DB·수집/동의 설정·운영 배포·실제 푸시/메일 발송 변경 없음. 문서 diff를 검토했고 코드가 바뀌지 않아 테스트는 재실행하지 않았다. 사용자 소유 미추적 스크립트·`scripts/__pycache__/`·`tmp/`는 보존했다.

## 2026-09-11 서버 데이터 삭제 기능 명칭 확정

- 사용자가 기존 제안 `내 정보 삭제` 대신 **`서버 내 나의 데이터 삭제`**를 요청했다. 준비 점검표의 Setting 진입점 명칭에 그대로 반영했다. 이후 버튼·안내에서 이 확정 명칭을 사용한다.
- 이번 요청은 명칭 변경이며 삭제 기능의 구현·실행, 보유기간·외부 서비스 삭제 범위 확정으로 확대하지 않았다. 삭제 절차 및 나머지 개인정보처리방침 확인사항은 이전 상태를 유지한다.
- 준비 점검표와 인계 기록만 변경했다. 앱/서버 코드·운영 DB·배포 변경이나 실제 데이터 삭제는 없다. 문서 diff 검증만 수행하며 실행 테스트는 재실행하지 않았다. 사용자 소유 미추적 파일은 보존했다.

## 2026-09-11 서버 내 나의 데이터 삭제 실제 구현

- 사용자 `실제 기능구현하고 다음항목` 요청으로 Setting의 `서버 내 나의 데이터 삭제`를 구현했다. 범위·남는 데이터·알림 중단을 설명하는 확인창, 본인 확인, 진행/실패/재시도/완료, 별도 확인을 거치는 `서버 기능 다시 사용`을 연결했다. 기존 사용자의 실제 삭제 버튼은 누르지 않았다.
- 신규 설치는 서버 생성 ID와 기기 보안 저장소의 256비트 비밀값으로 인증한다. 서버에는 해시만 보관하며 ID만으로 삭제·설정 조회/변경·등록을 허용하지 않는다. 공개 날씨는 익명으로 사용 가능하고 인증된 개인화 응답은 no-store다. 새 인증 준비 요청은 Cloudflare 위치별/IP별 20회/분으로 완화한다.
- 기존 설치는 마이그레이션 시점의 저장된 FCM 경로로 비표시 일회용 증명을 받아 소유권을 확인한다. 임의 ID 선점이나 호출자가 바꾼 토큰에 증명 전달을 허용하지 않는다. 증명은 요청/설치/새 비밀값에 결합하며 5분 만료·1분 간격·성공 후 폐기한다. FCM data 메시지 TTL 60초. 토큰 없음/만료·수신 불가·비밀값 분실은 자동 우회하지 않고 코드소하 문의를 안내한다.
- `DELETE /api/v1/installations/:id`가 등록·좌표·FCM 토큰·설정·발송 이력·특보/강수/도로 상태·인증/전환 정보를 단일 D1 batch로 제거한다. SQL에도 소유자 조건을 두고 인증 행은 마지막에 삭제한다. 고아 데이터/재등록을 막는 트리거와 발송 직전 존재·토큰·설정 재확인을 추가했다. 이미 진행 중인 FCM 전송의 취소는 보장하지 않는다. 영구 삭제표식은 남기지 않으며 동일 ID 신규 생성 API가 없다.
- 앱은 삭제 시도부터 자동 등록과 설정 전송을 차단하고 이 상태를 보안 저장소에 먼저 기록한다. 네트워크 결과 불명/완료 마커 저장 실패 시 기존 인증으로 재시도한다. 앱 재실행/복귀·FCM 토큰 갱신·설정 변경이 재등록하지 않는다. 삭제 후 조회에는 ID/인증/정밀 좌표를 제거한다. 지역·하위 설정·준비물 체크는 보존하고 전체 알림만 끈다. 재사용 확인 후 새 서버 ID로 등록하되 알림을 자동으로 켜지 않는다.
- `flutter_secure_storage 10.3.2` 추가. 11.1.0은 현재 Dart 3.9.2/geolocator 의존성과 충돌하여 도입하지 않았다. Android 자동 백업 비활성화, iOS Keychain entitlement 추가. 기존 SDK의 수집·동의 설정은 변경하지 않았다. 자세한 계약과 한계: `docs/서버_내_나의_데이터_삭제.md`.
- 검증: 전체 앱 **311 tests**, `flutter analyze` 무문제, Android debug APK 및 x86_64 전용 debug APK 빌드 통과. 전체 서버 **30 files / 225 tests**, `tsc --noEmit`, Wrangler dry-run 통과. 소유권 거부, 단일 대상 삭제/롤백, 기존 설치 증명·만료·재생 거부, 삭제 직전/발송 중 경합, 늦은 저장 방지, 저장 실패·재시작·확인 취소·360px 2배 글씨·Home 복귀 후 전송 차단을 포함한다. 테스트의 운영 비밀값 미설정 경고는 기존 상태이며 모의 FCM을 사용했다.
- 운영 D1 `0007_installation_access.sql` 적용 및 Worker 배포 완료. 버전 **`f939d1df-d119-4227-84d9-47025c458c5b`**, URL `https://weather-care-server.sy40222.workers.dev`. API/DB 인증이 추가됐으므로 구형 앱의 인증 없는 등록·설정 API는 거부된다. 새 앱이 필요하다. 이전 무인증 Worker로 단순 롤백하지 말 것.
- `scripts/verify_server_data_deletion.mjs`로 운영에서 **이번에 새로 만든 합성 설치 하나만** 검증·삭제했다. 실제 FCM 토큰·GPS 없이 알림 끔으로 등록하고 다른 인증 거부/삭제/재시도/재등록 거부/기존 인증 폐기를 확인했다. 합성 설치 제거 후 기존 설치/설정/발송 이력은 각각 1행으로 유지됐다.
- 에뮬레이터 기본 APK 설치는 저장공간 부족으로 실패했다. 앱·데이터를 지우지 않고 x86_64 전용 APK를 빌드해 `adb install -r`로 성공했다. 자연스러운 앱 업데이트 과정에서 기존 설치의 비표시 소유 확인이 완료됐으며 인증 1행, 전환/증명 0행이다. 사용자의 알림 켜짐·07:00, 기존 설치/설정/발송 이력은 유지했고 OS 권한·기기 시계·지역 선택을 변경하지 않았다. 사용자에게 보이는 테스트 푸시나 이메일은 보내지 않았다.
- Setting 하단 진입·삭제 확인창 레이아웃을 실제로 확인한 뒤 **취소**했다. Git 제외 이미지 `weather_care_app/build/ui-qa/server-data-delete-confirmation.png`. Flutter/AndroidRuntime 치명 로그 없음. 마지막 에뮬레이터 화면은 Setting 하단 삭제 진입점이다. iOS 빌드·실기기 미검증.
- 다음 사용자 결정은 **일반 보유기간**: 장기 미사용 설치 정보와 발송 이력의 정리 시점. 로그·백업·외부 SDK 처리와 복원 시 삭제 반영, 수동 본인 확인 절차, 정식 개인정보처리방침 공개 URL은 별도 미확정이다. 기능 구현 승인으로 보유기간이나 법적 준수 전체를 자동 확정하지 말 것.
- 사용자 소유 미추적 `scripts/analyze_precip_sample.py`, `scripts/build_precip_grid_mapping.py`, `scripts/download_precip_sample.mjs`, `scripts/__pycache__/`, `tmp/`는 수정·스테이징하지 않는다.

## 2026-09-11 일반 데이터 1년 보유 확정·자동 정리

- 사용자 `1년으로 하자`로 직전 두 항목(장기 미사용 설치 정보·발송 이력)을 모두 1년으로 확정하고 구현했다. 설치는 마지막 인증된 앱 요청부터 1년 미사용, 이력은 각 `sent_at`부터 1년이다. 한국 시간 다음 해 같은 날짜·시각 기준이며 2월 29일은 다음 해 2월 28일로 계산한다. 직접 삭제는 기간을 기다리지 않는다. [계약](docs/서버_데이터_보유기간.md).
- 기존 `updated_at`은 서버 알림 작업도 갱신하므로 사용 시각으로 재활용하지 않았다. `0008_data_retention.sql`의 `installation_activity`에 기존 등록/설정/인증의 최초 기준을 마이그레이션 시각으로 기록했다. 이후 성공한 소유 확인에서만 활동을 갱신하며 잘못된 인증·서버 발송은 기간을 늘리지 않는다. 늦은 요청이 과거 시각으로 덮어쓰거나 삭제된 활동 행을 다시 만들지 못하도록 조건을 두었다.
- 기존 10분 Cron의 알림 처리 전에 최대 100개 설치 및 관련 데이터, 추가로 최대 1,000개 만료 발송 이력을 원자적으로 정리한다. 남으면 다음 실행에 이어 처리한다. 삭제 트리거 및 D1 batch로 실패 시 전체 롤백하고 재시도한다. **활동 행을 삭제하면 관련 설치 데이터까지 삭제되므로 이 테이블을 단순 로그처럼 비우지 말 것.** 공용 날씨·다른 설치·외부 서비스·백업/로그는 대상이 아니다.
- 발송 후보/직전 검사도 만료 설치를 제외한다. 지연된 Cron의 예보 대상 시각과 보유기간 판정의 실제 실행 시각을 분리했다. 작업 지연/적체 시 삭제 지연과 이미 전송 중인 알림 가능성을 안내한다. 인증 준비 15분/증명 5분 기술적 만료는 그대로 유지한다.
- 등록/설정 요청의 401 후 `GET /api/v1/installations/:id/status`로 부재를 확인하고 410 `INSTALLATION_GONE`일 때만 기기에 전송 중지를 기록한다. 서버 등록정보가 없다는 문구를 쓰고 만료 때문이라고 단정하지 않는다. 자동 재등록 없이 별도 `서버 기능 다시 사용` 확인 후 새 ID로 등록하며 전체 알림은 끈 채 시작한다. 단순 인증 실패·네트워크 오류를 삭제 완료로 처리하지 않는다.
- Setting 저장·전송 정보 안내에 보유기간/기준 시각/윤년/기존 데이터 전환/주기/외부 제외 범위를 추가했다. 보유기간 계약, 개인정보 준비 점검, 삭제 계약, 데이터·권한 안내 문서를 갱신했다. 다음 정책 항목은 **운영 로그·백업의 실제 보관/만료와 복원 시 삭제 반영**이다. 외부 SDK·수동 본인 확인·정식 방침 공개 URL은 여전히 별도 미확정이다.
- 검증: 전체 서버 **31 files / 240 tests**, `tsc --noEmit`, Wrangler dry-run 통과. 전체 앱 **314 tests**, 안내 회귀 18개 재검증, `flutter analyze` 무문제, Android x86_64 debug APK 빌드 성공. 기한 직전/경계·윤년/KST·시각 포맷, 갱신/삭제 경합·재생 방지, 롤백/배치 제한, 지연 Cron 발송 차단, 부재/401 구분, 기기 저장 실패/재시작을 검증했다. 테스트 DB 초기화 파서/격리 문제는 테스트 보완 후 해결했다.
- 운영 `0008_data_retention.sql` 7명령 적용, 최종 Worker **`9588e04b-ec80-46a5-a718-95fc19f84435`** 배포 완료 (`https://weather-care-server.sy40222.workers.dev`). 이전 Worker로 롤백 시 활동 갱신·자동 정리가 중단되므로 별도 검토가 필요하다. 운영 날짜 계산의 윤년 처리를 읽기 전용으로 확인했다.
- 기존 `verify_server_data_deletion.mjs`에 상태 확인을 추가하고 운영에서 새 합성 설치 하나만 생성·검증·삭제했다. 좌표/실제 FCM 없음, 알림 끔. 기존 사용자 설치·설정·이력은 각각 1행 유지, 인증 1행/활동 1행, 만료 대상 0행. 사용자의 실제 정보를 시험 삭제하지 않았다.
- 에뮬레이터 `adb install -r`로 앱 데이터 보존 업데이트, 보유기간 안내를 시각 확인했다. 캡처 `weather_care_app/build/ui-qa/server-data-retention.png`는 Git 제외다. 초기 저장 미확인 표시가 있어 설정값을 바꾸지 않고 기존 설정 저장을 재시도해 `기기에 설정을 저장하고 서버에 반영했어요`를 확인했다. 마지막 앱 활동 시각도 갱신됐다. OS 권한·시간·지역·알림 값 변경, 테스트 푸시/메일 없음. iOS 빌드/실기기 미검증.
- 사용자 소유 미추적 분석 스크립트·`scripts/__pycache__/`·`tmp/`를 수정/스테이징하지 않는다. Cloudflare/D1 스킬에 따라 타입·원자적 배치·운영 날짜 함수를 검증했고 한글 conventional commit으로 기록한다.

## 2026-09-11 운영 로그·백업 현재 상태와 권장안 검토

- 사용자 `다음항목`에 따라 다음 미확정 정책인 운영 로그·백업 보관과 복원 처리를 검토했다. **권장안 제시 단계이며 사용자 승인 전**이다. 직전 1년 확정은 설치 정보·발송 이력에만 적용하며 로그·백업에 확대하지 않는다.
- `docs/운영_로그_백업_검토.md`를 추가하고 개인정보 준비 점검에 연결했다. Worker Observability의 sampling 1 및 일부 오류 로그에 설치 ID·좌표 기반 locationKey가 포함될 수 있음을 코드에서 확인했다. 실제 운영 로그의 해당 기록 발생을 확인하거나 정보 유출을 판정한 것은 아니다.
- Cloudflare 스킬에 따라 최신 공식 문서를 확인했다. Workers Logs 보관은 무료 3일/유료 7일, D1 Time Travel 복구 범위는 무료 7일/유료 30일이며 자동 제공된다. 현재 계정 요금제, 콘솔의 추가 로그 전송/내보내기, 실제 Ubuntu journal·Proxmox 백업 설정은 미확인이다. 저장소 설정에 없다는 이유로 외부 사본이 없다고 단정하지 않는다.
- 권장안은 로그의 사용자 식별자·위치·토큰·비밀값/원본 URL 제외와 최대 7일 보관, D1 기본 복구 범위만 이용하고 별도 장기 개인 DB 백업을 추가하지 않는 것이다. 자동 호출 로그·추가 메타데이터도 점검해야 하며 invocation 로그 설정 하나만으로 완전 정제를 보장하지 않는다.
- 복원 시 삭제 데이터 재사용 방지를 위해 과거 사용자 데이터는 운영에 재투입하지 않는 방식을 제안한다. 전체 DB 복원 시 API/발송 중단·개인 데이터 제거 검증 후 재개 절차가 필요하고, 삭제하지 않았던 이용자도 명시적 서버 재등록이 필요할 수 있다는 불이익을 함께 설명한다. 영구 삭제 식별자 로그는 추가하지 않는다. **실제 복원/삭제 승인으로 해석하지 말 것.**
- 앱/서버 실행 코드·설정·DB·비밀값·SDK 변경, 운영 배포, 푸시/메일 발송 없음. 운영 버전은 `9588e04b-ec80-46a5-a718-95fc19f84435` 유지. 문서만 검토하므로 실행 테스트는 재실행하지 않고 diff와 문서 연결을 확인한다.
- 다음은 위 권장안 사용자 확정 후 실제 보관 설정 확인 및 최소 로그/복원 보호 구현이다. Firebase·광고 외부 처리와 수동 본인 확인, 공개 방침 URL은 별도 미확정이다. 사용자 소유 미추적 분석 스크립트·`scripts/__pycache__/`·`tmp/`는 수정/스테이징하지 않는다.

## 2026-09-11 무료 기준 선택·미니PC 확인 안내

- 사용자 `무료 요금제 기준으로 진행하고 미니 PC는 뭘 확인하면돼?`에 따라 Workers Logs 3일/D1 복구 이력 7일 기준을 문서에 확정했다. 계정 요금제를 실제 확인하거나 변경한 것은 아니다. 무료 기준이 미니PC에 자동 적용되거나 나머지 복원 정책까지 일괄 확정된 것으로 취급하지 않는다.
- 릴레이 systemd 파일을 다시 확인하고 미니PC 점검 순서를 문서에 추가했다. Ubuntu 로그 출력 경로·journal 보관 설정, Proxmox Ubuntu VM 백업 주기/보관 규칙/실제 백업과 스냅샷, 별도 사본 유무를 확인한다. 첫 단계로 비밀값이나 로그 원문을 출력하지 않는 읽기 전용 `systemctl show`/`systemd-analyze cat-config` 필터 명령을 안내한다. 네임스페이스가 있으면 별도 설정 확인이 필요하다.
- 문서·HANDOFF만 변경, diff 검사 후 한글 커밋. 실행 코드/운영 설정·DB·미니PC 접근/배포/삭제 없음. 실행 테스트는 문서 변경이라 재실행하지 않았다. 미추적 사용자 스크립트·캐시·tmp는 보존한다. 다음은 사용자 Ubuntu 설정 출력 확인이며 실제 로그 최소화 구현은 아직 남아 있다.

## 2026-09-11 미니PC journal 출력 해석

- 사용자 제공 결과: 릴레이 `StandardOutput=journal`, `StandardError=inherit`, 빈 `LogNamespace`로 기본 공용 journal 사용. 지정한 기간/용량/저장 항목의 활성 설정은 출력되지 않았다. 실제 만료기간이나 로그 부재·무기한 보관을 확정하지 않는다.
- `syslog.conf` drop-in 경로가 보여 기존 필터에 없던 ForwardToSyslog 및 rsyslog 실행 여부를 다음 읽기 전용 확인으로 안내한다. 파일명만으로 전달 활성화를 단정하지 않는다. 공용 journal 전역 정책은 다른 서비스에도 영향을 주므로 임의 변경/삭제하지 않는다.
- 검토 문서와 인계만 갱신·diff 검사·커밋. 원격 접속/실행 코드 수정/운영 변경/테스트 재실행 없음. 사용자 미추적 파일은 보존한다. Proxmox 백업·실제 저장/회전 방식 및 로그 최소화 구현은 여전히 후속 작업이다.

## 2026-09-11 syslog 전달 활성 확인

- 사용자 출력 `ForwardToSyslog=yes`, `rsyslog.service=active`를 확인했다. 특정 파일에 실제 릴레이 로그가 기록됐다고 단정하지 않는다. 다음은 `/etc/rsyslog.conf`와 `/etc/rsyslog.d/*.conf`의 활성 `/var/log/` 경로 줄, `/etc/logrotate.d/rsyslog`의 회전 규칙 확인이다. 실제 로그 원문이나 비밀값은 요청하지 않는다.
- journal 이외 파일 사본의 보관도 확인해야 한다. 전역 설정/기존 로그 삭제·서비스 재시작·원격 접속 없음. 문서만 갱신하고 diff 검사·한글 커밋하며 실행 테스트는 재실행하지 않는다. 사용자 미추적 파일은 보존한다.

## 2026-09-11 syslog 주간 회전·4개 보관 확인

- 사용자 출력으로 일반 로그의 `/var/log/syslog` 기록 규칙 및 rsyslog 로그 묶음의 `weekly/rotate 4/notifempty/compress/delaycompress`를 확인했다. 현재 파일+이전 4개 구조로 정확한 28일 만료가 아니다. 정상 회전 시 약 4~5주 기록이 남을 수 있으나 작업 중단·빈 파일 회전 생략 등으로 실제 기간은 달라진다. 실제 파일/작업 성공 여부는 미확인이다.
- 다른 시스템 로그까지 묶인 전역 규칙은 변경하지 않는다. 릴레이 전용 로그 분리와 보관 구현은 후속 검토. 다음 사용자 단계는 Proxmox Datacenter → Backup 예약 작업 목록 화면 확인이며, 이후 VM의 실제 Backup/Snapshots와 별도 사본 확인이 남는다.
- 검토 문서/HANDOFF만 수정·diff 검사·한글 커밋. 운영 설정 변경·삭제·배포·원격 접속·실행 테스트 없음. 사용자 미추적 파일은 보존한다.

## 2026-09-11 릴레이 설정 변경 요청·Proxmox 접속 안내

- 사용자가 설정 변경 및 Proxmox 관리 화면 접속 방법을 요청했다. 다른 서비스의 journal/syslog 전역 정책을 바꾸지 않고 릴레이 로그 분리 방향으로 진행하되, 미니PC의 실제 보관기간은 별도 확정이 필요하다. Cloudflare 무료 로그 3일과 D1 복구 7일 선택을 미니PC 기간으로 자동 확대하지 않는다. 사용자에게 릴레이 로그도 3일로 할지 확인한다. 실제 원격 설정 변경·기존 로그 삭제는 아직 하지 않았다.
- 저장소 릴레이/docs/scripts 검색에서 실제 Proxmox 관리 IP를 찾지 못했다. 공식 문서 기준 `https://Proxmox호스트IP:8006`, 기본 root/PAM 및 설치 때 정한 비밀번호로 접속 안내한다. Ubuntu VM IP와 호스트 IP를 혼동하지 않는다. 주소는 미니PC의 Proxmox 로컬 콘솔 또는 공유기 목록에서 확인한다. 포트 공개나 Funnel로 관리 화면을 노출하지 않는다.
- 이번 변경은 인계 기록뿐이며 실행 테스트/배포/계정 변경 없음. 후속은 미니PC 보관기간 확정 및 안전한 적용 경로 확인, Proxmox 예약/수동 백업 점검이다.

## 2026-09-11 외부에서 Proxmox 접근 경로 검토

- 사용자가 외부에 있어 집 LAN에 직접 접속할 수 없다고 알렸다. 현재 Tailscale로 접근 가능한 Ubuntu를 경유하는 SSH 로컬 포워딩을 우선 안내한다. Ubuntu→Proxmox 관리 IP:8006 접근 및 SSH 포워딩 허용이 전제다. localhost 바인딩으로 제한하고 인터넷 포트 공개/Funnel/전역 서브넷 라우팅은 추가하지 않는다.
- 실제 Proxmox IP가 아직 없어 사용자 Ubuntu에서 `ip -4 route`, `ip -4 neigh` 읽기 전용 결과를 먼저 요청한다. 기본 게이트웨이나 이웃 IP를 Proxmox라고 단정하지 않는다. 경로 파악 후 목적지 확인과 로컬 PC 터널 명령을 안내할 것. 현재 사용하는 PC의 Tailscale 연결도 필요하며 웹 SSH만으로 로컬 터널이 생기지 않는다.
- SSH 터널·원격 설정 변경은 아직 실행하지 않았다. 로그 변경 요청은 유지하되 미니PC 보관기간 답변 대기. 인계만 갱신·커밋하고 실행 테스트 없음.

## 2026-09-11 Proxmox 후보 IP 확인 준비

- 사용자 네트워크 출력: Ubuntu LAN `192.168.0.67/24`, 기본 게이트웨이 `192.168.0.1`, 이웃 `192.168.0.46 STALE`, `192.168.0.118 INCOMPLETE`. 어느 주소도 Proxmox로 확정하지 않는다. STALE은 곧 오프라인을 뜻하지 않으며 INCOMPLETE는 장비 부재의 확정 증거가 아니다.
- 우선 Ubuntu에서 `192.168.0.46:8006`의 로그인 전 페이지 제목을 짧은 제한시간의 curl로 확인하도록 안내한다. `-k`는 이 내부 후보의 인증정보 없는 진단 요청에만 한정하고 전역 TLS 검증을 변경하지 않는다. 제목/응답만으로 호스트 신원을 암호학적으로 검증했다고 취급하지 않는다. 인증키/비밀번호 전송, 광범위 스캔, 포트 공개는 하지 않는다.
- 터널과 로그 설정은 아직 변경하지 않았다. 인계 문서만 검사·커밋. 후보가 확인되면 로컬 PC Tailscale/SSH 경로 확인 후 localhost 한정 터널을 안내할 것.

## 2026-09-11 첫 Proxmox 후보 접속 실패

- 사용자가 Ubuntu에서 `192.168.0.46:8006`에 curl 접속 시 3ms 후 오류 7(연결 실패)을 받았다. Proxmox 여부나 장애 원인을 확정하지 않는다. TLS 이전 연결 실패이므로 인증서/비밀번호 변경으로 해결하려 하지 않는다.
- 다음은 기존 이웃 후보 `192.168.0.118:8006`의 제한시간 있는 로그인 전 조회 및 `getent ahostsv4 pve proxmox` 이름 조회를 안내한다. 후보 주소와 이름은 미확정이다. 기존 Proxmox 접속 주소/북마크도 대안이며 광범위 스캔이나 방화벽 해제는 하지 않는다.
- 인계만 수정·검사·커밋. 터널/원격 설정/로그 정책 실제 변경 없음. 미니PC 로그 보관기간 결정과 적용 요청은 여전히 남아 있다.

## 2026-09-11 두 번째 후보·이름 조회 실패

- 사용자 결과: `192.168.0.118:8006` curl 오류 7, 약 2780ms 뒤 연결 실패. `getent ahostsv4 pve proxmox` 출력 없음. 앞선 `.46` 실패와 함께 현재 후보로는 관리 주소를 식별하지 못했다. 호스트 종료·Proxmox 장애 또는 설치 여부를 단정하지 않는다.
- 다음은 Proxmox를 사용했던 브라우저 방문 기록/북마크에서 `8006` 또는 `Proxmox`를 검색해 주소만 확인하도록 요청한다. 전체 방문 기록·비밀번호는 요청하지 않는다. 기록이 없으면 기존 Ubuntu/Tailscale 경유로 공유기 장치 목록 확인을 검토하되 외부 공개·방화벽 해제·광범위 스캔은 하지 않는다.
- 로그 설정 변경 요청과 미니PC 기간 확인은 남아 있다. 이번에는 인계만 갱신·diff 검사·커밋하며 원격 설정/재시작/배포/실행 테스트는 수행하지 않았다.

## 2026-09-11 공유받은 Ubuntu 경유 공유기 접근 승인 확인

- 사용자는 Tailscale 관리자가 따로 있고 Ubuntu를 공유받았다고 설명했다. 공유기 소유/관리자 접근 허락 여부를 물었고 사용자가 `응`으로 확인했다. 범위는 공유기 연결 기기 목록 확인이며 임의 설정 변경·공개 노출·다른 장비 접근 권한으로 확대하지 않는다.
- 다음 사용자 Ubuntu 조회는 `tailscale ip -4`, `192.168.0.1` HTTP/HTTPS 루트의 인증정보 없는 상태 코드 확인이다. 요청은 직접 연결(--noproxy), 3초 연결/8초 전체 제한, 본문 폐기. HTTPS의 -k는 이 진단만 한정한다. 공유기 로그인 비밀번호/쿠키는 요청하지 않는다.
- 실제 Ubuntu Tailscale 주소와 응답 확인 후 현재 사용자 PC에서만 열리는 127.0.0.1 바인딩의 SSH 로컬 터널을 안내한다. 공유 노드의 짧은 이름이 해석된다고 가정하지 않는다. Tailscale/SSH 정책이 막으면 우회 설정 변경 대신 관리자 확인이 필요하다. 실제 터널·원격 변경·로그 변경은 아직 없음. 인계만 갱신·검사·커밋한다.

## 2026-09-11 공유기 응답 확인·로컬 HTTPS 터널 안내

- 사용자 출력으로 Ubuntu Tailscale IPv4 `100.105.212.26`, Ubuntu→`192.168.0.1` HTTP/HTTPS 각각 200 확인. HTTPS 진단은 -k였으므로 인증서/장비 신원 검증을 완료한 것은 아니다.
- 현재 사용자 PC(원격 Ubuntu 셸 아님)의 새 PowerShell에서 `ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18443:192.168.0.1:443 ubuntu@100.105.212.26` 후 같은 PC 브라우저 `https://127.0.0.1:18443` 안내. PC의 Tailscale 연결 필요. 인증 후 무출력 대기는 정상일 수 있으나 실제 페이지 접속으로 검증해야 한다. ExitOnForwardFailure는 목적지 연결 성공을 보장하지 않는다.
- 새/변경된 SSH 호스트키는 관리자 확인 없이 승인/삭제하지 않는다. 브라우저 인증서 경고·다른 주소 리다이렉트·권한 거절 시 그대로 확인하며 보안 검증을 전역 해제하지 않는다. 로그인 정보는 사용자 직접 입력·비공유. 목적은 연결 기기 목록 확인이며 설정 변경/재부팅은 하지 않는다. 터널 종료는 PowerShell Ctrl+C.
- 터널 성공/공유기 화면은 아직 미확인. 인계만 변경·diff 검사·커밋하고 원격 실행/로그 정책 변경/배포/테스트는 하지 않았다.

## 2026-09-11 공유기 HTTPS 비활성 화면·HTTP 터널 전환 안내

- 사용자 스크린샷 `https://127.0.0.1:18443/webpages/index.html`에 TP-Link 로고와 HTTPS 로컬 관리 비활성·HTTP 접근 안내가 표시됐다. 터널 경유 페이지 도달은 확인됐으나 로그인/기기 목록은 아직 아니다. 이전 HTTPS 200은 로그인 성공이나 관리 기능 활성의 증거가 아니다.
- 기존 터널 PowerShell Ctrl+C 후 `ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18080:192.168.0.1:80 ubuntu@100.105.212.26`로 전환, 브라우저 `http://127.0.0.1:18080`을 안내한다. 현재 PC→Ubuntu는 SSH로 암호화되지만 Ubuntu→공유기는 HTTP 구간이다. 공유기 보안 설정이나 외부 공개 설정을 변경하지 않는다.
- 인증정보는 사용자 직접 입력·비공유, 다음 확인은 로그인 후 연결 기기/DHCP 목록 화면이다. HTTP 터널 실행/로그인은 아직 미확인. 인계만 갱신·diff 검사·커밋하며 실제 원격 설정/로그 정책/배포 변경 없음.

## 2026-09-11 내부 브라우저 공유기 연결 기기 확인

- 사용자가 내부 브라우저 확인을 요청했다. CUA 최초 상태 조회 timeout 후 재시도 성공, 기존 인앱 탭 10의 TP-Link Archer AX73 네트워크 맵을 읽었다. 현재 연결된 클라이언트 23개가 표시되며 soha-01은 `192.168.0.67`, 앞선 `.46` 후보는 UI상 `Samsung`으로 표시된다. 현재 목록에서 Proxmox/pve라는 이름은 찾지 못했다. 이름 표시만으로 장비 실제 역할을 확정하지 않는다.
- 다른 서버형 이름들도 있지만 임의로 Proxmox 후보로 지정하거나 해당 장비를 조회하지 않았다. 연결 목록만으로 고정 IP 호스트/다른 관리 대역의 존재 여부를 배제할 수 없다. 다음은 관리자에게 Proxmox 실제 관리 IP 또는 URL과 허용된 계정/접속 방법 확인을 권장한다.
- 브라우저 읽기 전용으로 확인했으며 공유기 설정·차단·속도 제한·계정·인증서 설정 변경 없음. 관련 없는 기기 이름/MAC·로그인 URL 토큰은 인계에 복사하지 않는다. 인계만 갱신·diff 검사·커밋. 미니PC 로그 변경과 보관기간 확인 및 Proxmox 백업 점검은 미완료로 유지한다.

## 2026-09-11 조립 부품에서 네트워크 식별 단서 검토

- 사용자 구매 이미지 본체는 ASRock DeskMini X300/2.5G. 공식 제품 사양의 유선 LAN은 Dragon RTL8125BG, 무선은 별도 M.2 슬롯이며 X300W 변형은 키트가 다르다. 사용자 사진만으로 실제 장착 무선카드를 특정하지 않는다. 삼성 RAM/AMD CPU/SSD 브랜드는 공유기 장치 표시를 결정하는 근거가 아니므로 `.46 Samsung`과 RAM을 연결하지 않는다.
- 앞서 읽은 soha-01 MAC의 `BC:24:11` 접두사를 Proxmox 공식 pve-cluster `src/PVE/DataCenterConfig.pm`의 가상 게스트 기본 접두사와 대조했다. soha-01이 Proxmox 게스트라는 강한 단서이나 MAC은 변경 가능하며 호스트 관리 IP 또는 여러 게스트가 같은 물리 호스트에 있다는 보장은 아니다.
- 실제 관리 주소는 여전히 미확정. 사용자는 Wi-Fi 연결이라고 했으므로 미니PC의 실제 Wi-Fi 모듈/USB 무선랜 모델 또는 물리 어댑터 MAC이 추가 단서다. 사용자에게 무선랜 제품명을 확인한다. 다른 장비/무선 설정 변경·포트 검색 없음. 인계만 갱신·검사·커밋한다.
- 근거: https://www.asrock.com/nettop/AMD/DeskMini%20X3002.5G%20Series/index.asp 및 https://raw.githubusercontent.com/proxmox/pve-cluster/master/src/PVE/DataCenterConfig.pm . 구매 금액·주문 내역은 인계에 기록하지 않는다.

## 2026-09-11 유선 연결 정정·DHCP 예약 추가 확인

- 사용자가 미니PC는 Wi-Fi가 아닌 랜선 연결이라고 정정했다. 향후 유선 LAN 기준으로 판단하며 무선 모듈을 추가 요청하지 않는다.
- 기존 인앱 routerTab에서 메뉴→고급→네트워크→DHCP 서버로 이동하고 목록 새로고침을 눌러 조회했다. 최초 로딩 직후 0개는 확정하지 않았으며 최종 주소 예약 6개, DHCP 클라이언트 22개를 확인했다. DHCP 4페이지 모두 읽었다. soha-01의 `192.168.0.67` 예약 존재, 예약 6개는 Proxmox 기본 가상 게스트 MAC 접두사 항목들이며 호스트 관리 주소를 식별할 별도 항목은 찾지 못했다.
- DHCP 범위 `192.168.0.2~192.168.0.253`, 게이트웨이 `.1`, 임대시간 120분 표시. 범위 밖 주소를 호스트 IP로 추측하지 않는다. 호스트가 직접 고정 IP를 쓰면 DHCP 목록에 없을 수 있으나 현재 실제 설정을 확인한 것은 아니다. 물리 LAN MAC 또는 관리자가 지정한 관리 IP가 필요하다.
- UI의 읽기 전용 탐색/목록 갱신만 수행했다. 추가·편집·저장·삭제·차단·네트워크 변경 없음. 마지막 브라우저는 DHCP 목록 4페이지다. 인계만 갱신·diff 검사·커밋하며 원격 설정/로그 정책/배포 변경은 아직 없다.

## 2026-09-11 관리자 제공 Proxmox 주소 수신

- 사용자가 관리자에게 받은 Proxmox 관리 주소 `192.168.0.2:8006`을 제공했다. 앞선 공유기 네트워크 맵의 같은 IP는 Samsung-Washer로 표시됐으므로 표시 오류/오래된 정보/충돌 가능성을 구분해야 한다. 실제 충돌 또는 잘못된 관리자 안내라고 단정하지 않는다.
- 먼저 사용자 Ubuntu에서 해당 주소 HTTPS 로그인 전 페이지 제목을 제한시간 curl로 확인하도록 안내한다. 인증값 없는 진단에서만 -k 사용. Proxmox 제목 확인 시 현재 PC의 별도 PowerShell에서 `ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18443:192.168.0.2:8006 ubuntu@100.105.212.26` 연결 후 `https://127.0.0.1:18443`을 열도록 한다. 기존 18080 공유기 터널은 별개로 유지 가능하다. 이전 18443 터널이 남아 포트 충돌이면 해당 창 Ctrl+C 후 다시 수행한다.
- 제목은 암호학적 신원 검증이 아니며 브라우저 보안 경고/다른 제품 화면이면 로그인 전에 확인한다. 아직 Proxmox 응답·로그인·백업 설정은 확인하지 않았다. 실제 원격 변경/배포/로그 정책 적용 없음. 인계만 검사·커밋한다.

## 2026-09-11 Proxmox 예약 백업 없음 확인

- 사용자가 Proxmox 데이터센터 백업 화면을 제공하며 백업 설정 자체가 없다고 알렸다. 화면의 작업 목록이 비어 있어 예약 백업 없음으로 기록했다. 수동 VM 백업/스냅샷/외부 사본까지 없다고 확대하지 않는다. 새 백업 생성이나 기존 사본 삭제는 요청하지 않았다.
- 관리 접속 문제로 본래 로그 작업에서 오래 벗어났으므로 백업 점검은 확인된 범위만 기록하고 Ubuntu 릴레이 로그 분리·보관 설정 변경으로 돌아간다. 미니PC 로그 기간은 아직 사용자 확정 전이므로 Cloudflare 로그처럼 3일로 할지 확인한다. 일반 서버 데이터 1년/Cloudflare 로그 3일/D1 복구 7일은 기존 확정 유지.
- 검토 문서와 인계만 갱신·diff 검사·커밋. Proxmox/공유기/Ubuntu 운영 설정 변경·재시작·배포·실제 로그 삭제 없음. 화면 하단의 관련 없는 패키지 갱신 오류는 이번 범위에서 진단하지 않는다.

## 2026-09-11 릴레이 전용 로그 3일 설정 구현 (운영 미적용)

- 사용자가 릴레이만 분리해 3일 보관하는 권장안을 승인했다. 공용 journal/rsyslog 설정과 기존 로그는 보존한다.
- Ubuntu 100.105.212.26로 BatchMode/StrictHostKeyChecking SSH를 시도했으나 인증 거부. 서버 파일 변경·재시작·로그 삭제는 수행하지 않았다.
- deploy/logging에 전용 journal namespace drop-in, 3day/32M 보관 설정, 15분 주기 rotate/vacuum 타이머를 구현했다. 설치 스크립트는 systemd 245+, 기존 서비스 활성 여부, 기존 대상 파일 부재를 확인하며 오류 시 새 설정만 제거·서비스 재시작을 시도한다. 비밀 환경파일은 읽지 않는다.
- README에 scp 전달, sudo 설치, health/namespace/타이머/합성 설정 검증 및 복구 절차를 추가했다. 시간 기반 삭제는 파일 단위 회전/정리 지연이 있으며 기존 공용 로그는 별도 기존 정책이다. 다른 drop-in/외부 수집기 및 실제 systemd 동작은 운영 검증 필요.
- 검증: Vitest 11개 통과, TypeScript 빌드 통과, Git Bash -n 통과. 새 테스트 4개는 배포 파일 계약 검사이며 실제 Linux 통합 테스트가 아니다. deploy .gitattributes로 LF 유지. 기존 사용자 untracked scripts/tmp는 제외한다.
- 다음: 사용자 PC에서 README의 scp 명령으로 deploy를 Ubuntu에 전달하고 sudo 설치. 실제 적용 성공 및 health/전용 로그/정리 상태 확인 전 운영 완료로 표현하지 않는다.

## 2026-09-11 사용자 설치 실패 진단 대기

- 사용자가 설치 실행 후 rollback 안내 두 줄을 제공했다. 실패 명령/종료코드가 출력되지 않아 원인은 미확정이다. 설치 성공이나 복구 성공으로 단정하지 않는다.
- 재설치·재시작을 반복하지 않고 Ubuntu에서 서비스 상태, health HTTP 코드, systemd PID 1의 최근 릴레이 관련 메시지를 읽기 전용으로 요청한다. 환경파일/키/애플리케이션 로그 원문은 요청하지 않는다.
- 설치 스크립트의 ERR 처리에 실패 위치 출력이 없어 진단성이 부족하다. 실제 진단 결과 수신 후 수정 시 보완할 것. 이번에는 운영 변경이나 구현 변경 없이 인계만 갱신했다.

## 2026-09-11 로그 서비스 시작 경합 보완

- 사용자 결과: relay active/running, Result=success, LogNamespace 비어 있음, health HTTP 200. 기존 공용 로그 방식으로 복구된 현재 상태를 확인했다.
- PID 1 로그에서 relay 시작과 namespaced journald 시작 직후 같은 초에 rollback 재시작이 발생했다. 비동기 socket activation 직후 is-active 검사의 경합이 유력하나 이전 실패 줄이 없어 원인 확정은 아니다.
- 설치 스크립트에서 전용 journald를 먼저 명시적으로 restart해 시작 작업 완료를 기다린 후 relay를 재시작하도록 수정했다. 재시도 시 남아 있는 namespace 프로세스도 새 설정을 읽게 한다. ERR에 단계/줄/종료코드를 추가하고 재귀 trap을 해제한다. 비밀값 출력 없음.
- Vitest 12개, Bash 문법 및 diff 검사 통과. Linux 실기 검증은 대기. Windows PowerShell에서 수정된 스크립트 하나만 기존 Ubuntu 설치 폴더로 scp한 뒤 sudo 재실행하도록 안내한다. 운영 SSH 접근권한은 여전히 없고 직접 배포하지 않았다.

## 2026-09-11 사용자 실행으로 운영 로그 설정 확인

- 수정 스크립트 Installed 및 timer enable 성공 후 사용자 출력에서 health HTTP 200, ActiveState=active, LogNamespace=weather-care-relay 확인.
- 합성 journal 설정: persistent, MaxRetentionSec=3day, MaxFileSec=15min, SystemMaxUse=32M, RuntimeMaxUse=16M, Syslog/KMsg/Console/Wall 전달 모두 no. 타이머 LAST 04:04:36 UTC, NEXT 04:19:36 UTC 확인.
- 운영 설정 적용 확인으로 README/검토 최신 상태 갱신. timer LAST는 정리 oneshot 성공 증거는 아니므로 Result/ExecMainStatus 추가 확인 요청. 3일 경과 삭제 실증은 아직 없다. 기존 공용 로그 보존 및 지연 설명 유지.
- 코드/운영 추가 변경 없이 문서만 갱신·diff 검사·커밋. 사용자 untracked 파일은 보존.

## 2026-09-11 릴레이 정리 성공 보고 및 다음 로그 항목

- 사용자가 정리 서비스 상태 확인 후 성공했다고 보고했다. 원문 추가 수신은 아니며 사용자 확인으로 기록한다. 릴레이 설정·정리 실행 점검 완료, 3일 경과 삭제 실증과는 구분.
- 다음 Workers 로그 최소화 조사: scheduler logNotificationError가 context 전체(installationId/regionKey/locationKey/notificationKey)를 펼치고 weather.ts 로그에 nx/ny 포함. wrangler observability enabled=true, head_sampling_rate=1.
- Cloudflare 공식 Workers Logs 문서에서 invocation 로그의 요청 URL 포함 및 invocation_logs=false 옵션 확인. 코드 로그 정제만으로 플랫폼 전체 메타데이터 제거를 보장하지 않는다.
- 로그 저장 중단은 장애 진단 능력과 기존 3일 보관 방식에 영향을 주므로 사용자 선택 요청. 권장: 코드 개인정보 출력 제거와 Workers Logs 저장 중단 후 안전한 진단 방식 별도 마련. 아직 코드/설정 수정·테스트·배포 없음. 기존 공용 로그 소급 삭제 없음.

## 2026-09-11 Workers 로그 개인정보 최소화 구현

- 사용자가 Workers Logs 저장 중단 권장안을 승인. cloudflare/workers-best-practices/wrangler 스킬 및 공식 문서·로컬 스키마를 확인했다.
- observability/logs/traces 및 persist/invocation_logs 비활성. scheduler의 설치·지역·좌표·알림 키 로그 제거, weather 오류 격자 제거. 오류명은 고정 허용 목록만 출력한다. Hono 기본 raw error 로그를 고정 JSON으로 대체하고 cron은 원본 cause 없이 실패를 유지한다.
- 새 privacy 테스트: provider mutable name/cause 제거, scheduler 개인 context 제거, 날씨 오류 격자 제거, Hono 예외 정제, cron 예외 정제. 32파일/245테스트 통과, tsc 및 wrangler deploy --dry-run 통과. 초기 고정 커스텀 오류명 3개 회귀는 허용 목록으로 수정 후 전체 통과.
- 기존 운영 9588e04b-ec80-46a5-a718-95fc19f84435 100% 확인. 다음 운영 배포·health·버전/설정 확인. DB/키 변경 없음, 실제 알림 시험 발송 없음, 과거 로그 삭제 없음. untracked 사용자 scripts/tmp는 제외한다.

### 운영 배포·검증 완료

- 구현 커밋 f6453ee. wrangler deploy 성공, 버전 39500cac-48b5-48b9-8f25-e7b031d179bf 100%, health HTTP 200, 기존 10분 cron 유지.
- CLI 버전 조회에는 Observability 필드가 없어 공식 script-settings API를 읽기 전용 조회했다. Wrangler의 기존 인증을 메모리에서만 사용하고 출력하지 않았다. 결과 observability=null, logpush=false, tail_consumers=null. 배포 설정은 enabled/logs/traces/persist false이며 API는 비활성을 null로 반환. 신규 저장 중단 확인과 과거 로그 파기 증명은 구분한다.
- 테스트 245개/32파일, tsc, dry-run 통과. 운영 DB 수정·테스트 알림 발송·실제 이용자 로그 조회/삭제 없음. 문서 상태 갱신 후 커밋한다.
- 다음 항목: D1 복원 시 삭제된 사용자 정보가 재사용되지 않도록 할 복원 정책 확정/절차 구현. 복원으로 유효 사용자 등록도 사라질 수 있는 권장안은 별도 설명·확정 필요. 실제 운영 DB 시험 복원은 하지 않는다. 이후 Firebase/광고 SDK, 공개 개인정보처리방침 연결 순서.

## 2026-09-11 복원 정책 선택 대기

- 사용자 '다음진행'으로 복원 정책 검토 시작. 기존 권장안과 앱의 명시적 '서버 기능 다시 사용' 경로를 읽기 전용 확인했다.
- 권장: 과거 사용자 등록·인증·설정·발송 이력을 운영에 재사용하지 않고 필요한 공용 자료만 복구. 전체 복원이 불가피하면 API/발송 중단 중 개인 데이터 제거·검증 후 재개. 삭제하지 않은 사용자도 서버 기능 재등록 및 알림 재동의가 필요할 수 있다는 영향 때문에 명시 확정 요청.
- 현재 삭제 후 재사용 UI가 있다는 사실을 재해 복원 대응 구현 완료로 취급하지 않는다. 코드/운영 변경·DB 복원·개인 데이터 삭제 없이 정책 확정 대기. 이번에는 인계만 갱신.

## 2026-09-11 복원 정책 확정 및 안전장치 구현

- 사용자 확정: 복원된 개인 데이터 재사용 금지, 격리 중 정리·검증 후 재개, 기존 사용자도 명시적 재등록 및 알림 OFF 시작. 실제 사고별 운영 복원·삭제 승인은 별개다.
- D1 밖 RECOVERY_MODE 선택적 secret으로 모든 API 503 및 cron 차단. 미설정/정확한 off만 정상. 이번에는 복구 모드를 활성화하지 않는다.
- 수동 ops/recovery-reset.sql로 8개 개인 테이블과 active_regions 정리. 검증 SQL은 9개 건수·미검토 테이블·FK 오류 검사. 로컬 합성 DB에서 반복 실행/공용 데이터 보존 확인. D1 compound SELECT 제한을 피하도록 개별 쿼리로 구성.
- 앱은 OFF를 기기에 저장한 후 재등록 재개하고 로컬 저장 실패 시 중단. 서버는 설정 없는 설치에 알림 미발송. 발송 fixture도 명시적 동의를 생성하도록 변경.
- docs/DB_복원_운영절차.md 작성: 기존 실행 요청 종료 확인 필수(HTTP 무제한이므로 단순 대기로 보장 불가), 검증 전 재개 금지, 과거 사본 별도, 이미 전송한 FCM 회수 불가. 실제 운영 복원/삭제/복구 모드 시험 없음.
- 검증: 서버 33파일 254테스트, tsc, wrangler dry-run 성공. 앱 관련 23테스트 및 home_screen 분석 성공. 앱 실기 설치는 수행하지 않음. 다음 정상모드 서버 배포·health 확인 후 결과 기록. 사용자 untracked scripts/tmp 보존.

### 복원 안전장치 운영 배포 완료

- 구현 커밋 e4c9f7f. 서버 버전 69043d04-23e8-4ced-b604-f7b79e9dc941 100% 배포, health HTTP 200/ok, 기존 10분 cron 유지 확인.
- RECOVERY_MODE 활성화·운영 SQL·실제 복원·개인 데이터 삭제·시험 알림 발송 없음. 앱 변경은 코드/테스트까지이며 기기 설치는 미실행.
- 다음 항목은 Firebase/광고 SDK의 실제 수집·동의 설정 확인, 이후 공개 개인정보처리방침 연결. 복원 정책은 확정·구현했으나 실제 사고 대응 훈련 완료로 표현하지 않는다.

## 2026-09-11 Firebase·광고 SDK 읽기 전용 점검

- pubspec에 firebase_analytics/core/messaging 및 google_mobile_ads 포함. main에서 Firebase 초기화 및 MobileAds 즉시 초기화. lib 내 Analytics 명시적 이벤트/동의/수집 제어, UMP 흐름, 실제 광고 표시 호출은 검색되지 않았다.
- Android Manifest/iOS Info.plist에 Analytics 수집 중단과 FCM 자동 초기화 중단 설정 없음. Android 광고 앱 ID는 샘플 값. 실제 콘솔 연결·수집 기록·배포 바이너리의 최종 병합 설정·네트워크 전송은 미확인이다.
- notification_registration_service는 OS 알림 허용 시에만 getToken을 호출하지만, SDK 자동 초기화 자체를 막는 설정과는 별개다. 서버 데이터 삭제를 Firebase 전체 삭제라고 설명하면 안 된다.
- 공식 근거: https://firebase.google.com/docs/analytics/android/configure-data-collection , https://firebase.google.com/docs/cloud-messaging/flutter/get-started , https://developers.google.com/admob/flutter/privacy . Analytics 수집 제어와 FCM 자동 초기화 방지, 광고 요청 전 UMP 상태 확인 절차 확인.
- 첫 결정 권장: 현재 사용하지 않는 Analytics 수집 중단(이용 통계·분석 보고서 영향), 날씨/푸시 기능 유지. 이후 광고 SDK 및 FCM 활성화 정책 별도 결정. 이번에는 정책 선택 전 코드·콘솔·운영 변경 없이 확인 내용만 기록했다. 문서 diff 검사 후 커밋, 테스트/배포 없음.

## 2026-09-11 Analytics 선택 동의 구현

- 사용자는 Analytics 수집을 선택했고, 동의 후 시작·설정에서 철회·날씨와 알림 기능 분리에 동의했다. 앞선 수집 중단 권장안은 채택되지 않았다.
- Android/iOS 네이티브 수집 기본 OFF 및 Analytics/광고 consent 기본 거부 설정. 앱 시작 시 로컬 analytics_consent_v1을 적용하며 기존 동의 없는 이용자는 OFF. 동의 전환은 저장 후 SDK 활성화, 철회는 SDK 중단부터 시도. SDK/저장 실패는 오류와 재시도 표시. 완전한 기기 저장 실패나 SDK 실패를 성공으로 안내하지 않는다.
- 설정에 선택 스위치 및 동의/비동의 확인 추가. 광고 개인화 동의를 같이 허용하지 않음. FCM·서버 등록·광고 SDK 자체 초기화는 별개이며 이번 변경 대상 아님. 이미 수집된 데이터의 소급 삭제도 수행하지 않음.
- 공식 Firebase Android/iOS collection 설정 및 Google app consent 문서 확인. 커스텀 이벤트/좌표/설치 ID 전송 추가 없음. SDK 자동 수집만 동의로 제어한다.
- 분석 controller/확인 취소/철회/실패 테스트와 기존 설정 화면 회귀 실행. 네이티브 실기 네트워크 및 Firebase 콘솔 수집 확인, iOS 빌드, 공개 방침·외부 보관기간 검토는 아직 미수행. 앱 코드만 수정하며 서버 배포 없음.
- 검증 결과: 관련 테스트 31개 통과, 변경 Dart 5파일 analyze 통과, diff 검사 통과. 다음은 광고 SDK 동의·초기화 정책과 실제 콘솔 설정 확인. 사용자 untracked scripts/tmp 제외.

## 2026-09-11 광고 초기화 정책 선택 대기

- 다음항목 요청으로 main의 MobileAds 시작 시 초기화 및 실제 광고 표시/UMP 호출 부재를 재확인했다. Google 공식 Flutter quick-start/privacy 문서 확인.
- 권장: 광고 도입 계획은 유지하되 실제 광고와 동의 흐름 준비 전 자동 초기화 중단. 도입 시 UMP로 필요한 동의 절차 및 canRequestAds 확인, 광고 개인화 선택과 Analytics 동의 분리. 광고 수익화 포기로 해석하지 않는다.
- 사용자 확정 전 코드/콘솔 설정 변경이나 SDK 제거 없음. 이후 적용 여부 질문. 인계만 갱신.

## 2026-09-11 광고 UMP 동의 흐름 구현

- 사용자가 중단 대신 동의 절차 구현 요청. 매 앱 프로세스 첫 프레임 후 UMP update → 필요 화면 → canRequestAds 확인 → MobileAds 초기화(1회) 연결. 기존 main 무조건 초기화 제거. Analytics 선택과 별개 유지.
- 설정에 UMP가 요구하는 광고 개인정보 선택 진입점 추가, 오류 시 광고 차단 및 재시도. 중복 호출 방지와 선택 변경 후 자격 재확인. 실패 시 이전 동의 fallback은 사용하지 않는 보수적 처리. 동의 화면 표시 자체로 동의/개인화 허용이라고 판단하지 않음.
- SDK initialize 취소나 기존 전송 정보 삭제는 아님. 실제 광고 표시 기능은 없으며 앞으로 로드 경로에서 최신 컨트롤러 상태를 확인하고 선택 변경 시 기존 광고 폐기가 필요. docs/광고_동의_연결.md에 운영 전 확인사항 기록.
- Android 샘플 앱 ID/iOS 앱 ID 미설정 확인. 실제 ID 및 AdMob 개인정보 보호 및 메시지 게시, 대상 연령/지역, 공개 방침 URL, 실기 테스트가 필요하다. 임의 ID 추가·콘솔 게시·실제 광고 송출 없음.
- 변경 5파일 analyze 통과. UMP 가짜 의존성 순서/미허용/오류 재시도/중복/설정 진입점 테스트와 Analytics·설정 회귀 실행. 서버 변경·배포 없음. 사용자 untracked scripts/tmp 보존.
- 최종 결과: 관련 테스트 27개 통과, diff 검사 통과. 실기 설치/네이티브 UMP 화면 및 실제 전송 확인은 미수행.

## 2026-09-11 AdMob 운영 연결 시작

- 인앱 브라우저에서 https://apps.admob.com/ 열어 https://admob.google.com/v2/home 로그인된 계정 확인. 계정 가입은 필요하지 않은 상태이며 관련 없는 수익/세금 정보는 작업 범위에서 제외한다.
- 아직 날씨챙겨 앱 등록 여부나 운영 앱 ID는 확인하지 못했다. 홈의 실적 데이터 없음은 앱 미등록 증거가 아니다. 사용자가 메뉴 → 앱에서 날씨챙겨 등록 상태를 확인하도록 요청한다.
- 콘솔 생성/게시/설정 변경, 실제 앱 ID 교체, 서버 배포 없음. 공개 방침 URL·대상 연령 등 미확정 조건은 임의 입력하지 않는다.

## 2026-09-11 AdMob 양 플랫폼 등록 확인

- 사용자 Android/iOS 날씨챙겨 등록 완료 보고. 현재 인앱 탭 앱 목록에서 양 플랫폼 이름 확인, iOS 앱 개요는 검토 필요 및 첫 광고 단위 생성 안내 상태.
- 아직 실제 ca-app-pub 형식 앱 ID는 화면에 없음. 사용자가 각 앱의 앱 설정에서 앱 ID를 확인하도록 요청한다. URL의 숫자 식별자를 SDK 앱 ID로 사용하지 않는다. 코드·콘솔 변경 없음.

## 2026-09-11 AdMob 운영 앱 ID 연결

- 사용자 제공 Android ca-app-pub-6152243173470406~7636009442 / iOS ca-app-pub-6152243173470406~9535766125를 각각 Manifest와 Info.plist에 연결. Android 샘플 값 교체, iOS GADApplicationIdentifier 추가. Markdown 이스케이프 역슬래시는 값에 포함하지 않았다.
- XML 파싱 및 플랫폼별 ID 단일 항목/정확한 값 검증, diff 검사 통과. 설정만 변경했으며 앱 빌드/설치·실제 광고 요청·운영 콘솔 게시 없음. docs/광고_동의_연결.md 최신화.
- 다음: AdMob 개인정보 보호 및 메시지에서 양 앱 메시지 준비. 공개 개인정보처리방침 URL·대상 연령/지역 등이 미확정이므로 임의 값으로 게시하지 않는다. 사용자 untracked scripts/tmp 보존.

## 2026-09-11 메시지 종류 화면 확인

- 현재 AdMob 개인정보 보호 및 메시지 UI에서 유럽 규정(EEA/영국/스위스), 미국 주 규정, IDFA 설명 만들기 확인. 모든 한국 사용자용 일반 동의 팝업과 동일한 것으로 안내하지 않는다.
- 앱 출시 국가/이용 대상이 미확정이므로 한국만 배포할지 해외도 포함할지 먼저 질문한다. 전국 날씨 지원 요구를 앱 배포 국가 확정으로 해석하지 않는다. 메시지 생성/게시·계정 설정 변경 없음.

## 2026-09-11 한국 스토어 한정 출시 확정

- 사용자가 한국 스토어만 출시한다고 확정. 실제 Play/App Store 배포 국가 설정을 변경한 것은 아니다. 해외 접속 가능성과 지역별 정책 적용까지 없어지는 것으로 해석하지 않는다. UMP 유지.
- 다음 결정은 광고 개인화 방식. 권장: 초기에는 비개인화 광고 및 타사 앱/웹 간 추적 미사용. 비개인화도 광고 운영 데이터 처리가 있으며 개인정보 안내·필요 동의 검토를 대체하지 않음. Google AdMob 개인화/비개인화 안내와 Apple User Privacy 공식 문서 확인. 사용자 승인 전 IDFA 메시지 게시·광고 요청 정책 변경 없음.

## 2026-09-11 광고 메시지 즉시 생성 요청

- 사용자 메시지 생성 요청 및 다른 앱·웹사이트 활동 추적 미사용 확정. 추적 권한 요청용 IDFA 메시지는 생성하지 않는다.
- 저장소 준비 문서에 날씨챙겨 공개 개인정보처리방침 URL이 아직 미확정임을 확인. 기존 Google/Firebase 안내 링크를 앱 자체 방침으로 대체하지 않는다. 사용자에게 실제 공개 URL 요청, 없다면 방침 작성·게시부터 필요함을 설명한다.
- 메시지 종류/내용을 임의로 법적 준수 완료 처리하거나 가짜 주소로 게시하지 않음. 이번에는 콘솔 생성·게시 미실행.

## 2026-09-11 Cloudflare Pages 개인정보 페이지 작성·초안 배포

- 사용자가 개인정보처리방침 페이지 작성 및 Cloudflare Pages 사용 요청. Cloudflare/Wrangler 스킬, Pages reference 및 공식 Direct Upload/개인정보 관련 자료 확인. 기존 서버/API와 분리한 weather_care_privacy 정적 HTML/CSS 생성.
- 기존 Pages 2개와 충돌하지 않는 weather-care-privacy 프로젝트 생성(생산 branch master), review branch 배포. 주소 https://review.weather-care-privacy.pages.dev/ , 배포 https://d7fdb79a.weather-care-privacy.pages.dev . Functions/DB/비밀값/트래커 없음. _headers에 CSP·noindex·referrer 등 설정.
- 확정된 위치/설치/알림/분석/삭제/1년 보유/로그·복원 정책 반영. 외부 계약·국외 이전·Analytics 보관 설정·문의 보관기간·연령이 미확정이라 명확한 검토용 초안으로 게시, 아직 정식 방침이나 AdMob URL로 사용하지 않음. 사용자에게 초안 배포 구분 안내함.
- 사용자 문의 담당자 ‘코드소하(CODESOHA) 운영자’ 승인 반영. 만14세 미만 포함 여부는 비동기 질문 답변 대기. 사용자 미확정 성명·국외 처리 국가·기간 임의 기재하지 않음.
- Playwright/Chrome 360·1280px 레이아웃, 가로 넘침 없음, 목차, 초안 표시, script/form 없음 검증. 모바일/배포 데스크톱 스크린샷 검토. 배포 HTTP 200, CSS/CSP/noindex, 실제 script 0, 잘못된 경로 404 확인.
- 로컬 Wrangler 첫 실행이 sibling 서버 설정을 선택하고 구형 workerd 날짜 오류로 실패(원격 DB 변경 없음). 최종 Pages 배포에는 privacy 절대 --cwd를 명시해 분리, 정적 로컬 검증은 별도 HTTP 서버로 수행. PowerShell 초기 배포 TLS 확인 실패 후 Chrome 정상 HTTPS 확인. 인증 무시 옵션 사용 없음.
- 서버 배포/AdMob 게시/앱 최종 방침 연결 없음. 다음은 초안 08 항목 확인 후 최종 방침과 생산 배포·AdMob 연결. QA 산출물은 .gitignore, 사용자 scripts/tmp 보존.

## 2026-09-11 아동 포함 이용 대상 확정

- 사용자 ‘전체이용이라 가능’ 답변으로 만14세 미만 포함 이용 대상 의향 확인. 스토어 등급 확정/심사 완료로 해석하지 않는다.
- 현재 코드 검색상 연령 확인·법정대리인 동의·아동용 광고 설정 없음. 개인정보 보호법 제22조의2 공식 조문 확인: 법에 따른 동의가 필요한 만14세 미만 처리에는 법정대리인 동의 및 확인 필요. UMP/OS 권한만으로 대체하지 않는다.
- 권장안 질문: 만14세 미만의 분석·광고는 비활성, 동의가 필요한 개인정보 처리 기능은 보호자 동의 확인 후 제공. 단순 체크박스로 검증 완료 처리하지 않으며 구현·최종 방침 게시 전 방식 확정 필요. 이번에 코드·콘솔·Pages 변경 없음.

## 2026-09-11 아동 보호 설계 승인 및 작성

- 사용자 위 권장안 설계 승인. docs/아동_개인정보_보호_설계.md에 미확인/14세 이상/아동 미동의/검증/철회 상태별 기능, 네이티브 SDK 전 시작 경계, 서버 검증 및 구버전 전환, 보호자 관계·동의 확인 조건과 실기 검증 기준 작성.
- 코드 확인: main이 연령 확인 전에 Firebase/Analytics를 초기화, HomeScreen이 등록 준비, 첫프레임 UMP 시작. UI 추가만으로 보호할 수 없음. 현재 앱에 아동 차단을 적용했다고 주장하지 않는다.
- 보호자 확인 방식은 아직 미선정. 임의 체크박스·이메일·client bool로 완료 처리하지 않고, 실제 동의 수단/법정대리인 관계 확인/보관 범위 선택이 필요하므로 운영 구현 전 사용자 방향 요청. 외부 계약·결제·실제 데이터 수집 없음.
- 문서 작업만 수행, 코드/Pages/서버 배포 없음. diff 검사 후 한글 커밋. 기존 사용자 untracked scripts/tmp 보존.

## 2026-09-11 본인확인 서비스 없음 확인

- 사용자 별도 본인확인 서비스 미보유 확인. 공식 시행령 자료 제17조의2제1항제5호의 동의 내용 이메일 발송·법정대리인 동의 회신 방식을 조사하여 설계에 후보로 추가. 유료 인증 계약이나 가족관계 서류가 항상 필수인 것으로 해석하지 않도록 보완.
- 단순 이메일 입력/OTP와 명시적 동의 회신을 구분. 운영자 수동 확인·요청 연결·동의 증빙 및 철회 관리 필요. 사용자의 수동 승인 운영 수락과 보관기간은 아직 미확정.
- 아동 차단 기능 구현/이메일 발송/Pages·서버 배포 없음. 다음은 수동 이메일 동의 운영 여부 확인. 문서 diff 검사 및 한글 커밋, 사용자 untracked 보존.

## 2026-09-11 현재 처리 정보 설명

- 사용자 질문에 따라 DB 마이그레이션, 앱 등록 요청, Analytics 동의 코드 및 개인정보 초안 대조. 설치 식별자·인증정보, 선택 지역/격자·권한 사용 시 좌표, 허용 시 FCM 토큰, 알림 설정·발송 상태·활동 시각, 플랫폼 등을 설명.
- 이름/전화번호 회원가입과 보호자 정보 수집은 현재 미구현. 광고 표시도 아직 미연결이며 UMP 연결과 구분. 선택 Analytics는 자체 서버 DB와 별도. 실제 운영 DB의 개인별 값은 조회하지 않음.
- 기능 변경·배포 없음. 보호자 수동 승인 운영은 여전히 미확정이며 이번 질문을 승인으로 해석하지 않음.

## 2026-09-11 아동 동의 필요 범위 재설명

- 만14세 미만의 모든 앱 이용에 일률적으로 보호자 동의가 필요한 것은 아니라는 점을 구분. 개인정보 보호법 제22조의2는 이 법에 따른 동의를 받아야 하는 처리에 적용. 위치정보법 제25조의 개인위치정보 동의·확인 의무는 별도 확인.
- 현행 설치 식별자와 연결되는 좌표 처리 구조에서 광고·분석만 끈 것으로 동의 문제가 해결된다고 안내하지 않음. GPS·개인화 등록·푸시·분석·광고를 제외한 수동 지역 조회 방식은 대안 후보이나 IP/로그/SDK 및 처리 근거 검토 전 동의 불필요 확정 불가.
- 이메일 수동 승인은 유일한 의무 방식이 아닌 후보. 이전 설명의 과도한 일괄 차단 인상을 정정. 이번은 설명만, 설계 전환·구현·배포 승인으로 해석하지 않음.

## 2026-09-11 보호자 구현 보류 및 다음 작업

- 사용자 보호자 동의 구현 보류 의향 확인. 스토어 요청만을 법적 의무 발생 조건으로 보지 않으며 출시 전 재검토 항목으로 유지. 아동 사용 안전성 검증 완료나 정식 방침 게시 승인으로 해석하지 않는다.
- 다음 작업 안내: Firebase Analytics 실제 데이터 보관 설정과 삭제 처리 확인. 이후 외부 서비스 처리 조건·문의 기록 보관기간·광고 비추적 검증 및 최종 방침 연결. 이번에는 콘솔 설정 변경이나 배포 없음.

## 2026-09-11 Firebase 인앱 화면 확인

- 인앱 탭15에서 weather-care-2aaa8 프로젝트 Messaging 온보딩 화면과 Spark 무료 요금제 확인. 왼쪽 애널리틱스 메뉴는 접혀 있음. Analytics 연결 여부·보관기간은 아직 확인하지 못함.
- 현재 브라우저 도구에서 클릭 API 문서가 제공되지 않아 임의 메서드를 호출하지 않고 사용자에게 애널리틱스 메뉴 펼치기 안내. 콘솔 설정 변경 없음.

## 2026-09-11 Analytics 연결 및 보고서 확인

- Firebase 대시보드에서 GA 속성549443110 연결 및 화면 조회·세션·알림 이벤트 집계 확인. 집계만으로 현재 버전 동의 준수나 테스트 사용자 여부를 추정하지 않음. 보관기간은 아직 미확인.
- 화면에 제공된 Google 애널리틱스 링크를 인앱 새 탭16으로 열었음. ‘내 이메일 커뮤니케이션’ 팝업과 왼쪽 ‘관리’ 메뉴 확인. 이메일 선택은 변경하지 않았으며 사용자에게 팝업 처리 후 관리 진입 안내.

## 2026-09-11 메뉴 안내 오류 정정

- 사용자가 실제 Firebase Network Settings 화면에서 메뉴 안내 불일치 지적. 새 GA 탭과 Firebase 메뉴를 구분하지 않은 점 사과. 탭16은 현재 목록에 없음.
- GA 속성 데이터 보관 직접 경로를 탭17로 시도했지만 홈으로 전환되고 ‘내 이메일 커뮤니케이션’ 팝업이 표시됨. 데이터 보관 진입 성공으로 주장하지 않음. open_in_codex도 queued이므로 사용자 화면 노출 확정 불가.
- 도구 검색상 브라우저 클릭 기능 없음. 읽기/탭 열기만 가능한 한계를 안내하고 정확히 관측한 팝업 버튼을 안내. 설정·메일 구독 변경 없음, 보관기간 미확인.

## 2026-09-11 GA 팝업 닫힘 확인

- 사용자 완료 후 현재 탭 목록 재확인: GA는 탭18, 탭17은 없음. 탭18 홈에서 이메일 팝업이 사라진 상태와 왼쪽 ‘작업’ 아래 ‘관리’ 링크 확인. 실제로 보이는 해당 링크 클릭 안내, 보관 설정 변경 없음.

- 이어서 탭18 /admin 화면 확인. 본문 ‘데이터 수집 및 수정’ 영역에 ‘데이터 보관’ 링크가 실제 존재하며 ‘데이터 가져오기’ 아래, ‘데이터 필터’ 위임을 확인해 안내. 보관기간 값은 여전히 미확인.

## 2026-09-11 Analytics 보관 현재값 및 목표 안내

- 사용자 요청: 클릭마다 끊지 말고 목표와 전체 절차를 함께 안내. 앞으로 동일 방식 준수.
- 탭18 실제 /admin/datapolicies/dataretention 화면 확인: 이벤트2개월, 사용자14개월, 새 사용자 활동 발생 시 재설정ON. 저장 비활성 상태. 직접 설정 변경 없음.
- 개인정보 최소 보관 관점의 권장안은 이벤트/사용자 각2개월, 재설정OFF. 이는 법정 필수값이나 사용자 확정값이 아니며 2개월 초과 세부 탐색 제한과 표준 집계 보고서 예외, 24시간 적용·월별 삭제를 공식 Google 안내로 구분. 기존 서버1년 보관 정책과 별개.
- 다음: 사용자가 일괄 설정·저장하면 재확인 후 개인정보 문구 반영. 저장 확인 전 완료나 실제2개월 적용으로 기록하지 않음.

## 2026-09-11 Analytics 보관 설정 저장 확인 및 초안 반영

- 사용자 완료 후 GA 속성549443110 데이터 보관 화면 재확인: 이벤트2개월, 사용자2개월, 새 사용자 활동 재설정OFF, 저장 버튼 비활성. 저장 상태 확인이며 24시간 적용 완료나 과거 데이터 삭제 완료를 의미하지 않음.
- 로컬 개인정보 초안에 해당 설정과 24시간 적용·월별 삭제·표준 집계 보고서 예외 반영. FCM/광고와 앱 서버1년 기준을 분리하고 개별 Analytics 삭제 절차는 미확정 유지.
- 공개 review 페이지 재배포·정식 방침 게시·서버/앱 변경 없음. 로컬 문구 및 레이아웃 검사 후 한글 커밋. 최근 설명 단계의 HANDOFF 기록도 함께 보존.

## 2026-09-11 Analytics 추가 수집 화면 점검

- 탭18 데이터 수집 화면: Google 신호는 ‘사용 설정’ 버튼(미사용), 사용자 제공 데이터는 업종 선택 전 시작 화면, 세부 위치 및 기기 데이터 수집ON. 광고 개인 최적화 고급 설정/사용자 데이터 수집 확인은 접혀 있어 내부 상태 미확인. 앱 lib에서 setUserId/setUserProperty/setUserData 호출 미검출.
- 사용자 비추적 방침에 따라 신호/사용자 제공 데이터 활성화하지 않기, 세부 위치·기기OFF, 광고 개인 최적화는 패널 확장 후 전 지역OFF 적용 절차를 한 번에 안내. 후자는 공식 Google 도움말9626162 절차이며 실제 내부 값 확인 완료로 주장하지 않음.
- 이번에는 콘솔 변경·약관 확인·배포 없음. 사용자가 적용하면 화면 재확인 필요. Analytics 설정은 앱 GPS 및 AdMob 광고 요청 자체 제어와 별개라고 안내.

## 2026-09-11 사용자 데이터 수집 확인 오클릭 점검

- 사용자 나머지 설정 완료 및 ‘사용자 데이터 수집 확인’을 눌렀다고 보고. 탭18에서 ‘수신 확인됨’과 공개·사용자 권한 확보 확인 문구를 실제 확인. 이는 최종 사용자 동의를 대신하지 않는 운영자 확인임을 설명.
- 화면상 Google 신호 미사용, 사용자 제공 데이터 시작 전, 세부 위치·기기OFF 유지 확인. 광고 개인 최적화는 접혀 있어 전 지역OFF 여부 아직 미검증(사용자 완료 보고만 있음).
- 현재 패널에 취소/철회 버튼 없음. 취소 불가능 단정이나 속성 삭제 권고 없이 정정 필요 시 Google 지원 문의 안내. 공식 Admin API의 AcknowledgeUserDataCollection 설명으로 약관 확인 성격 확인. 개인정보 초안/아동 처리 미확정 사항이 있어 준수 완료라고 기록하지 않음. 설정 변경·배포 없음.

## 2026-09-11 광고 개인 최적화 전 지역 해제 확인

- 탭18 펼친 패널에서 ‘총307개 지역 중0개 지역에서 허용’ 직접 확인. Analytics 광고 개인 최적화 전 지역 해제 확인 완료. Google 신호 시작 전, 사용자 제공 데이터 시작 전, 세부 위치·기기OFF도 재확인.
- Analytics 콘솔 설정 확인 범위만 완료이며 AdMob 비개인화 광고·실기 네트워크 검증·개인정보 고지 및 동의 적정성 완료가 아님. 이번에는 코드/콘솔 수정·배포 없음.

## 2026-09-11 Analytics 철회·삭제 코드 점검

- 다음 진행 요청에 따라 약속한 코드 점검 수행. docs/Analytics_철회_삭제_점검.md 작성. 정상 철회 수집 중단 및 기본false 확인. 기존 analytics_consent_test 4개 통과(실기 네트워크 검증 아님).
- 미완료: Google Analytics 원격 삭제 API 연동 없음. 앱 서버 삭제는 별개. 철회 저장 실패 후 기존true가 남으면 재시작 시 재허용 가능한 코드 경로 발견, 우선 보완 대상으로 기록. 기능 수정 없이 진단만 수행.
- 다음 권장 작업: 철회 실패·재시작 안전성 수정과 회귀 테스트 → Analytics 원격 삭제 권한/ID/인증 설계 및 연결 → 실기 검증. resetAnalyticsData만으로 원격 삭제 완료 처리 금지. 이번에 외부 삭제/배포/보호자 구현 없음. 문서 및 누적 확인 기록 한글 커밋.

## 2026-09-11 Analytics 철회 저장 실패 재시작 방어 구현

- 사용자 진행 승인. AnalyticsConsentStore 추가: prefs analytics_consent_v1 및 secure analytics_consent_guard_v2가 모두 허용이어야 재허용. 기존 guard 없는 설치는 재동의 필요. 별도 패키지 추가 없음.
- SDK 중단이 실패해도 철회 영구 저장 시도, 두 저장소 중 하나 실패해도 다른 기록 계속, 변경 실패 시 거부 저장·SDK 중단 재시도. 초기화는 read 전에 apply(false). 허용 저장은 거부로 초기화 후 양쪽 기록, 중간 실패 롤백 시도.
- 기존+신규 관련 테스트11개 통과. 새로운 컨트롤러 생성으로 재시작 시뮬레이션: 각 저장소 실패, SDK 실패, legacy, read 오류, 허용 중간 실패, 전체 실패 후 재시도. 실기 프로세스/네트워크 검증과 원격 삭제는 미완료.
- 전체 영구 저장 실패 및 Firebase 네이티브가 Dart 전에 시작하는 경계는 보장하지 않음을 문서화. 운영 배포/앱 기기 설치/Google 데이터 삭제 없음. 다음은 네이티브 시작 경계 실기 검증과 원격 삭제 설계.

## 2026-09-11 Android Analytics 미동의 재시작 실행 검증

- 다음작업/이어서 진행 요청으로 Android17 에뮬레이터5554에서 debug build 성공, 데이터 유지 install -r -d 성공. 최초 -r은 기존 앱 versionCode2026085100 대비 빌드2026081100 낮아 실패했으며 그 직후 구버전 실행 결과는 제외. 설치 데이터 삭제 없음.
- 설치 후 COLD 시작 성공 및 manifest 수집disabled/analytics storage denied 로그, 홈 복귀 후 force-stop/COLD 재시작에서는 setAnalyticsCollectionEnabled(false)로 disabled 및 storage denied 확인.
- Android 실물/iOS 미연결. 미동의 상태 SDK로그 확인만 완료: 네트워크 패킷, 동의→철회 UI, 오류주입, FCM 백그라운드 시작/기존허용 업그레이드는 미검증. 토큰/식별자 출력 안 함. 기기 저장소 필터 조회는 값 미추출이라 증거 제외.
- 점검 문서에 결과/한계 기록. 커밋 스킬에 따라 한글 검증 기록 커밋. 운영 서버/Pages/스토어 배포 없음. 다음은 테스트 환경에서 동의·철회 및 백그라운드 경계 검증, 원격 삭제는 별도 미구현.

## 2026-09-11 Analytics 동의→철회→재시작 UI 검증

- emulator5554 원상태 비행기OFF/Wi-FiON 확인 후 비행기ON·Wi-FiOFF 전환. Active default network:none 확인 후 앱 UI로 Analytics false→동의창 승인→true→철회false 확인. force-stop/COLD 재시작 후 오프라인 서버오류에서 ‘단기예보만 보기’로 닫고 설정에서false 유지 확인.
- 이번 FA 로그 필터 결과 없음으로 로그 검증 추가 주장 안 함. UI 검증만 완료, 패킷 무전송/FCM/iOS/원격 삭제 미검증. 위치·알림 설정 및 서버데이터 삭제 조작 없음.
- 중요: 시험 대기 이벤트 유무가 미확인이라 에뮬레이터를 비행기ON·Wi-FiOFF 상태로 유지, 사용자에게 명시. 다음은 대기 이벤트 안전 처리 및 원래 네트워크 복구 검토. 전체 앱데이터 삭제 금지. 아직 네트워크 복구하지 않음. 검증 문서 한글 커밋, 운영 배포 없음.

## 2026-09-11 Analytics 로컬 대기열 검사·네트워크 복구

- 사용자 진행 요청. emulator5554 앱 force-stop 후 앱 전용 google_app_measurement_local.db를 ADB→Python 메모리 SQLite(query_only)로 검사: integrity ok, messages0건, journal0바이트. 디스크 사본 및 이벤트 내용 출력 없음.
- SDK measurement_enabled/from_api=false, 앱 prefs동의false 확인. 삭제 필요 없어 데이터 삭제/초기화 없음. 종료 상태에서 비행기OFF/Wi-FiON 원복(이전 오프라인 유지 지침 종료).
- 앱 로컬 범위만 검증. GMS 큐/Google원격/패킷/FCM/iOS 미검증 유지, 무전송이나 원격 삭제 완료 주장 안 함. 코드·운영 배포 없음. 다음 원격 Analytics 삭제 식별·권한 설계 및 테스트 환경 FCM/iOS 검증. 검증 기록 한글 커밋.

## 2026-09-11 Google Analytics 원격 삭제 요청 구현

- 앱 설정에 ‘전송된 이용 통계 삭제 요청’ 추가. 명시적 삭제 시 Firebase app_instance_id를 없애기 전에 기기 보안 저장소에서 확보하고, 이용 통계 수집을 먼저 중단한 뒤 설치별 인증으로 Worker에 요청한다. 일반 철회는 ID 확보 완료를 기다리지 않고 수집을 즉시 중단하며, 동의 중 이미 기기에만 보관된 ID가 있으면 이후 요청 가능. 과거 버전에서 이미 철회해 ID가 없는 경우는 삭제 접수를 성공으로 표시하지 않는다.
- Google 요청 성공 뒤에만 resetAnalyticsData로 기기 분석 데이터/ID 초기화. 요청 접수 상태를 먼저 보안 저장해 재시작 시 로컬 정리를 마치며, 원격 실패 시 수집OFF+ID 유지, 원격 접수 후 로컬 실패는 상태를 구분. UI는 실제 삭제 완료가 아니라 요청 접수라고 명시.
- Worker에 인증 라우트 POST /api/v1/installations/:id/analytics-deletion, 분당 설치별3회 제한, Analytics Admin API v1alpha submitUserDeletion 클라이언트와 공용 Google 서비스계정 JWT/OAuth 서명 추가. GA_PROPERTY_ID=549443110, 비밀값 GA_ADMIN_CLIENT_EMAIL/GA_ADMIN_PRIVATE_KEY는 Wrangler secret 전용. FCM도 공용 서명기로 전환.
- 설정 안내·개인정보처리방침 검토 초안·Analytics 점검 문서 갱신. 공식 조건: analytics.edit OAuth 범위, 속성 편집자 이상, 속성당 사용자 삭제 하루500건. 계정 전체가 아니라 속성에만 삭제 전용 서비스계정을 추가하도록 운영 순서 기록.
- 검증: 서버 전체35파일258테스트, tsc 통과. 앱 전체339테스트, flutter analyze 통과. 개인정보 페이지 verify는 모바일/데스크톱/앵커/초안/무스크립트·폼 PASS. 실제 자격증명, Admin API 활성화, 속성 권한, Worker/Pages 배포, Android/iOS 종단 요청은 아직 안 함.
- 다음: Google Cloud에서 삭제 전용 서비스계정과 키 생성 → Analytics 속성549443110에 해당 이메일 편집자 추가 → 두 Wrangler secret 등록 → Worker 배포 → 테스트 전용 ID로 1회 종단 검증. 실키 원문은 채팅·문서·명령행 인자에 출력하지 않는다.

## 2026-09-11 Analytics 원격 삭제 운영 연결 완료

- Google Cloud 프로젝트 weather-care-2aaa8에서 Google Analytics Admin API를 활성화했다. 삭제 전용 서비스 계정 analytics-deletion@weather-care-2aaa8.iam.gserviceaccount.com(고유 ID 108636071236543436167)을 만들고 Analytics 속성 549443110에만 편집자 권한을 부여했다. Google Cloud 프로젝트 IAM 역할과 Analytics 계정 수준 권한은 부여하지 않았다.
- 운영 키를 검증해 Cloudflare Worker secret GA_ADMIN_CLIENT_EMAIL/GA_ADMIN_PRIVATE_KEY로 등록했다. 키 원문은 출력·기록하지 않았다. analytics.edit OAuth 토큰 발급과 Analytics Admin API 속성 읽기가 각각 HTTP 200으로 성공했다.
- 서버 전체 35파일 259테스트, tsc, Wrangler dry-run 통과 후 Worker 버전 efd6c82f-ed3a-4696-95f5-0c0ae0119c14를 배포했다. /health 200과 올바른 형식의 미인증 삭제 요청 401을 확인했다.
- 다운로드한 운영 키 JSON은 계정과 키 ID를 확인한 뒤 로컬에서 삭제했다. 다운로드 재시도로 생성됐지만 사용하지 않은 키 0be8c1fbf42e0f77e79899bf23b61b23b22efb49와 bbfe96fb6af596f741bf0b91185c9a3cc3f57320도 사용자 확인 후 Google Cloud에서 삭제했다. 새 키 목록에서 운영 키 9a533a062f2084f19ccef0073bc2e930909c4810 하나만 Active로 남은 것을 확인했다.
- 실제 Analytics 삭제 요청은 실행하지 않았다. 테스트 전용 앱 인스턴스가 준비된 뒤 1회 종단 검증해야 하며, 실제 이용자 ID나 출처 불명 ID로 시험하지 않는다. 이번 작업으로 이용 통계 삭제나 앱의 로컬 Analytics 초기화는 발생하지 않았다.

## 2026-09-11 Analytics 삭제 요청 운영 종단 검증

- Android17/API37 emulator-5554만 테스트 인스턴스로 사용했다. 운영 Worker URL을 주입한 최신 앱을 기존 데이터 유지 방식으로 설치했다. 범용 debug APK는 저장공간 부족으로 거부됐고 cache trim도 공간을 늘리지 못해 81.7MiB x86_64 전용 APK로 설치했다. 앱 데이터 전체 삭제는 하지 않았다.
- 설정에서 기존 Analytics 미동의를 확인한 뒤 테스트 목적으로 명시적 동의했다. 앱 인스턴스 ID와 설치 인증값은 출력·기록하지 않고 앱 UI의 ‘수집 중단 및 삭제 요청’을 1회 실행했다.
- 운영 Worker 버전 efd6c82f-ed3a-4696-95f5-0c0ae0119c14에서 인증된 analytics-deletion POST가 HTTP202로 완료되고 예외가 없었다. 앱에는 Google Analytics 삭제 요청 접수와 기기 분석 데이터 초기화 성공 문구가 표시됐으며 스위치는 false로 바뀌었다.
- force-stop/COLD 재시작 뒤에도 이용 통계 false 유지, 일회성 성공 문구 소멸, 보안 저장소 analytics_deletion_record_v1 부재를 확인했다. 재제출 대기 상태는 남지 않았다.
- 이는 테스트 인스턴스의 Google 요청 접수·앱 수집 중단·로컬 초기화 검증이다. Google 서버의 실제 과거 자료 삭제 완료시각, Android 실물, iOS는 미검증이다. 앱/서버 소스 변경과 추가 Worker 배포는 없다.

## 2026-09-11 FCM 백그라운드 Analytics 비동의 경계 검증

- 사용자 진행 요청으로 Android17/API37 emulator-5554에서 운영 FCM 데이터 전용 메시지 1회 검증. 앱을 홈으로 이동하고 `am kill`해 프로세스 없음·패키지 `stopped=false`를 확인한 뒤 전송했다. force-stop 상태에서 수신되는 것으로 오인하지 않음.
- 운영 D1에서 최근 갱신 테스트 토큰 후보가 1개임을 값 비노출로 확인하고 임시 설치 ID `wc_bgprobe_20260911_0813` 생성. 기존 ownership-challenge 라우트가 HTTP200 `ok`를 반환했고, 1초 안에 새 앱 프로세스와 FlutterFirebaseMessagingBackgroundService 시작을 확인. 앱 Activity는 전경에 나타나지 않음.
- 동일 프로세스 FA 로그에서 `setAnalyticsCollectionEnabled(false)`에 의한 measurement disabled와 analytics storage consent denied 확인. 앱 전용 google_app_measurement_local.db를 ADB→Python 메모리 SQLite로 확인한 messages 대기열0건. 이벤트 내용·토큰·인증값·실제 설치ID 출력 없음.
- 이후 force-stop/COLD 시작 및 설정 화면에서 Analytics 선택 스위치 checked=false 유지 확인. 에뮬레이터 네트워크는 비행기OFF·Wi-FiON 상태이며 앱은 설정 화면에 남아 있음.
- 임시 activity 삭제 트리거 뒤 설치·설정·이력·특보·challenge·legacy·credential·activity 연결 행이 모두0임을 운영 D1에서 확인. 실제 설치 레코드와 사용자 데이터는 삭제하지 않음.
- 검증 문서 반영만 수행. 패킷 캡처/GMS 내부 큐/Android 실물/iOS/모든 백그라운드 경로 무전송은 미검증이며 에뮬레이터 1회 결과를 일반 보장으로 표현하지 않음. 앱·서버 소스 및 운영 배포 변경 없음.

## 2026-09-11 FCM 백그라운드 앱 UID 통신량 검증

- 연결된 실물 Android/iOS가 없어 동일 범위에서 가능한 에뮬레이터 네트워크 관측을 추가함. emulator-5554 앱 UID10229의 Android BPF 누적 rx/tx bytes·packets를 사용했으며 실제 이용자 토큰·설치ID·인증값은 출력하지 않음.
- 홈 이동 후 `am kill`, process 없음·stopped=false 확인. 앱 UID 네 수치가 3초 간격 기준선에서 동일한 것을 확인한 뒤 운영 ownership-challenge로 데이터 전용 FCM 1회 전송. HTTP200 ok, 1초 안에 백그라운드 서비스 시작, 앱 Activity 미노출 확인.
- 전송 후 1초·10초·30초 이상 시점까지 앱 UID의 rx/tx bytes·packets가 모두 기준선에서 증가하지 않음. 동일 프로세스에서 Analytics disabled/storage denied 로그, Analytics 로컬 messages 대기열0건 재확인.
- 임시 설치 ID `wc_netprobe_20260911_0830`의 8개 관련 테이블 행은 activity 정리 트리거 뒤 모두0 확인. 실제 설치/사용자 데이터 삭제 없음. 앱은 콜드 시작 뒤 설정 화면 Analytics 스위치false, 비행기OFF·Wi-FiON 상태로 복원.
- 이는 앱 UID의 짧은 구간 통신량 무증가 증거이며 패킷 목적지·내용, GMS UID, 지연 전송, Android 실물/iOS를 검증하지 않음. 소스·운영 배포 변경 없이 점검 문서만 갱신.

## 2026-09-14 다음 작업 우선순위 점검

- 최신 인계와 저장소 상태를 다시 확인했다. Analytics 원격 삭제 운영 연결·Android 에뮬레이터 종단 검증과 FCM 백그라운드 Analytics 비동의 경계 검증까지 완료된 상태다.
- 현재 `flutter devices`에는 Windows·Chrome·Edge만 표시되고 Android 실물/에뮬레이터와 iOS 기기는 연결되어 있지 않다. 따라서 남은 실물 Android·iOS 동의 경계 검증은 장치가 준비된 뒤 진행한다.
- 지금 바로 이어갈 권장 작업은 AdMob 광고 단위 준비와 실제 광고 표시 경로 구현이다. 모든 광고 로드는 기존 UMP 컨트롤러의 최신 `canRequestAds`·busy·error 상태를 확인하고, 광고 개인정보 선택 변경 시 기존 광고를 폐기해야 한다.
- 광고 실동작과 비추적 설정을 테스트 기기에서 확인한 뒤 공개 개인정보처리방침 문구를 현재 구현과 맞추고 production Pages 게시, 앱 설정·AdMob·스토어 URL 연결 순서로 진행한다.
- 만 14세 미만 처리 방식, 외부 서비스의 국외 처리 조건, 문의 기록 보관기간은 최종 공개 전 미확정 항목으로 유지한다. 이번 점검에서는 앱/서버 코드, 외부 콘솔, 배포를 변경하지 않았다.
- 기존 사용자 소유 미추적 `scripts/__pycache__/`, 강수 분석 스크립트 3개와 `tmp/`는 수정·삭제하지 않았다.

## 2026-09-14 AdMob 테스트 배너 표시 경로 구현

- `Week` 탭의 주간 요약과 날짜 카드 사이에 인라인 적응형 배너를 연결했다. 활성 탭에서만 생성하고 UMP의 최신 광고 요청 가능 상태가 false가 되거나 화면에서 제거되면 기존 광고를 폐기한다. 모든 요청은 비개인화 옵션을 지정하고 Mobile Ads 초기화 전에 콘텐츠 등급 상한을 `G`로 설정한다.
- Debug/Profile은 운영 ID가 입력돼도 Google 공식 테스트 배너 ID만 사용한다. UMP 콘솔 메시지가 없는 동안 위젯 렌더링만 검증할 수 있는 `ADMOB_TEST_BYPASS_UMP=true`를 추가했으며 Release에서는 무조건 무시한다. Release는 유효한 플랫폼별 배너 ID와 `ADMOB_RELEASE_ENABLED=true`가 모두 필요하고, 현재는 연령 확인 경계가 없어 `main.dart`에서 UMP 자체를 시작하지 않는다.
- Android 에뮬레이터의 일반 Debug 빌드에서는 실제 운영 앱 ID에 게시된 UMP 메시지가 없어 `Publisher misconfiguration: no form(s) configured`가 발생했고 광고 요청이 보수적으로 차단됐다. 우회 플래그를 넣은 x86_64 Debug 빌드에서는 `Week` 진입 후 앱의 배너 요청, Google SDK의 테스트 기기 인식, 배너 로드 완료를 로그로 확인했다. 이는 UMP 동의나 운영 광고 검증이 아니다.
- 전체 `flutter analyze` 이슈 없음, Flutter 348개 테스트 통과. Debug 분할 APK와 운영 플래그가 없는 Android x64 Release APK 빌드 성공. Release 설치 후 `Week` 진입 시 앱 PID에서 광고/UMP 로그가 없음을 확인했다. 에뮬레이터에는 마지막으로 Release APK가 기존 데이터 유지 방식으로 설치되어 있다.
- 사용자 확인 후 AdMob Android/iOS에 `날씨챙겨 Week 인라인 배너` 광고 단위를 각각 생성했다. Android ID는 `ca-app-pub-6152243173470406/8661897062`, iOS ID는 `ca-app-pub-6152243173470406/6134971926`이며 두 생성 완료 화면에서 앱 ID·이름·플랫폼을 확인했다. ID는 문서에만 기록했고 Release 빌드나 CI에 주입하지 않았다. 연령 경계·UMP 메시지·공개 방침·Android 실물/iOS 검증 전에는 Release 광고를 활성화하지 않는다.
- 개인정보처리방침 준비 점검과 광고 연결 문서를 실제 구현·검증 상태에 맞췄다. 사용자 소유 미추적 `scripts/__pycache__/`, 강수 분석 스크립트 3개와 `tmp/`는 수정·삭제하지 않았다.

## 2026-09-14 연령 확인 SDK 시작 경계 1단계 구현

- 앱이 Firebase 기반 온라인 기능보다 먼저 로컬 연령 확인 화면을 표시하도록 시작 순서를 분리했다. 생년월일 없이 `만 14세 이상`/`만 14세 미만` 두 중립 선택지를 제공한다.
- `AgeEligibilityStore`는 SharedPreferences와 FlutterSecureStorage 두 저장소가 같은 유효값일 때만 선택을 신뢰한다. 누락·불일치·손상·읽기/쓰기 실패·3초 시간 초과는 미확인으로 처리하고, 허용 기록 중간 실패는 양쪽 무효화를 시도한다.
- 미확인·오류·만 14세 미만에서는 HomeScreen, Firebase 앱, Analytics, UMP·Mobile Ads, 위치 요청, 알림 권한·FCM 토큰 등록과 날씨 서버 연결을 시작하지 않는다. 만 14세 미만에는 보호자 확인 미연결 안내만 표시한다.
- 백그라운드 FCM 핸들러도 저장된 만 14세 이상 상태를 확인하기 전에는 Firebase를 초기화하지 않는다. FCM 자동 초기화는 계속 false로 유지하며, 허용 뒤 기존 알림 등록 서비스가 명시적으로 토큰을 요청한다.
- Android Manifest에서 FCM·Analytics 기본값을 false로 두고 `FirebaseInitProvider`, `MobileAdsInitProvider`를 병합 제거했다. iOS Info.plist도 FCM·Analytics 자동 시작을 false로 설정했다. SDK/플러그인 코드는 바이너리에 남으며 Flutter 플러그인 등록 자체를 제거한 것은 아니다.
- 신규 연령 저장소·컨트롤러·UI·시작 경계·네이티브 기본값 테스트를 추가했다. 전체 Flutter 357개 테스트 통과, `flutter analyze` 이슈 없음. Android x64 Release APK 28.9MB 빌드 성공, Release 병합 매니페스트에서 두 자동 초기화 값 false와 Firebase/Mobile Ads 조기 초기화 provider 0개를 확인했다.
- Android17 x86_64 에뮬레이터에서 저장값 없는 최초 화면, 만 14세 미만 선택과 콜드 재시작 유지, 해당 상태의 Firebase 앱·광고·서버 시작 로그 부재를 확인했다. 이후 다시 선택해 만 14세 이상으로 바꾸면 Firebase 수동 초기화와 Debug UMP 우회 환경의 공식 테스트 배너 로드가 동작했다. 기존 에뮬레이터 FlutterSecureStorage 데이터의 `bad base-64` 오류는 fail-closed 뒤 복구됐으며 앱 데이터 전체 삭제는 하지 않았다.
- 미완료: 보호자 관계·동의 확인, 서버 증명과 철회, 만 14세 이상 이용 중 아동 사용으로 전환하는 앱 내 절차, 기존 설치/FCM 토큰 정리, Android 실물/iOS 런타임·패킷 검증. 서버 notification payload는 Dart 백그라운드 핸들러 없이 OS가 표시할 수 있으므로 다음 작업은 설치 등록과 알림 스케줄러를 연령 미검증 기본 차단으로 바꾸고 기존 등록의 재증명을 요구하는 것이다.
- Release 광고 플래그와 운영 광고 단위는 활성화하지 않았고 앱/서버/Pages/스토어 배포도 하지 않았다. 사용자 소유 미추적 `scripts/__pycache__/`, 강수 분석 스크립트 3개와 `tmp/`는 수정·삭제하지 않았다.

## 2026-09-14 만 14세 미만 이용 불가 정책 전환

- 사용자 결정으로 이용 대상을 `만 14세 이상`으로 변경했다. 2026-09-11의 만 14세 미만 포함·법정대리인 동의 연결 계획은 폐기했으며 보호자 확인, 이메일 동의, 제한 기능 제공 같은 예외 경로를 구현하지 않는다.
- 앱의 만 14세 미만 화면을 `날씨챙겨를 이용할 수 없어요`로 변경했다. 날씨·위치·알림·Analytics·광고를 포함한 앱 서비스 전체를 이용할 수 없고 온라인 서비스와 기기 권한 요청을 시작하지 않았다고 안내한다. 잘못 선택한 경우에만 연령대를 다시 선택할 수 있다.
- 앱 서버 요청에 현재 정책 자기확인값 `minimumAgeConfirmed=true`, `agePolicyVersion=1`을 추가했다. 신규 설치 자격 발급, 기존 설치 소유권 이전과 설치/FCM 등록 모두 같은 값을 보낸다. 이는 로컬 자기확인이지 정부 발급 신원·생년월일 검증은 아니다.
- 서버는 현재 정책 확인값이 누락·false·다른 버전인 설치 등록, 신규 설치 자격 발급, 기존 설치 소유권 이전 요청을 거부한다. D1 `0009_minimum_age_policy.sql`은 확인 시각과 정책 버전을 추가하며 기존 행은 확인 시각 없음·버전0으로 남긴다.
- 알림 스케줄러는 확인 시각이 있고 정책 버전1인 설치만 최초 조회하며 FCM 발송 직전에도 다시 검사한다. 마이그레이션 적용 즉시 모든 기존 설치 알림은 중단되고, 최신 앱에서 만 14세 이상 확인 뒤 재등록한 설치만 재개된다. 삭제·열람 경로는 기존 자료를 정리할 수 있도록 연령 확인으로 막지 않는다.
- 앱·서버 README, 광고 연결 문서, 개인정보처리방침 준비 점검, Analytics 점검 문서와 아동 설계 문서를 만 14세 이상 정책으로 갱신했다. 개인정보 검토 페이지에도 이용 대상, 생년월일 미수집, 보호자 동의 예외 없음, 서버에 저장하는 연령정책 확인 시각·버전을 반영했다.
- 검증: 앱 전체 357개 테스트 및 `flutter analyze` 통과, Android x64 Release APK 28.9MB 빌드 성공. 서버 전체 35파일 264개 테스트 및 `tsc --noEmit` 통과. 개인정보 페이지는 360/1280px Playwright 레이아웃·앵커·초안·무스크립트 검증과 정적 필수문구 검증 통과.
- Cloudflare/Workers 작업에는 `cloudflare`, `workers-best-practices` 지침을 적용했고 2026-09-14 최신 `@cloudflare/workers-types` 5.20260914.1 및 공식 문서를 확인했다. 기존 프로젝트의 로그 비저장 결정과 비밀값 관리 방식은 변경하지 않았다.
- 운영 D1 마이그레이션, Worker, 앱, Pages, 스토어와 AdMob 설정은 배포·변경하지 않았다. 실제 적용은 `D1 마이그레이션 → Worker → 최신 앱` 순서와 기존 알림 중단 영향을 사용자가 확인한 뒤 진행한다. Android 실물·iOS 런타임 및 자기확인 우회 방지는 미검증/미구현이다.
- 사용자 소유 미추적 `scripts/__pycache__/`, 강수 분석 스크립트 3개와 `tmp/`는 수정·삭제하지 않았다.
