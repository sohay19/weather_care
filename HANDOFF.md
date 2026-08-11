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
