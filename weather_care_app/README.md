# 날씨챙겨 Flutter App

이 프로젝트는 내부 개발 명세(앱 버전)를 기반으로 한 초기 스캐폴딩입니다.

## 구조

- `lib/main.dart`: 앱 진입점
- `lib/app.dart`: 라우팅/테마 설정
- `lib/models/*`: Recommendation/Lifestyle/Weather/Settings 모델
- `lib/services/*`: API 클라이언트 및 서비스
- `lib/features/home/*`: 홈(파악형) UI
- `lib/features/settings/*`: 설치/알림 토글 중심의 설정 화면
- `server`: `/server` 경로에서 별도 구축된 API 서버로 호출

## 실행

```bash
cd app
flutter pub get
flutter run
```

## 환경 변수

서버 URL은 앱 실행 시 `--dart-define`로 주입 가능:

```bash
flutter run --dart-define=SERVER_URL=http://localhost:8787
```

## 다음 단계

- GPS 권한 수집 및 지역 선택 플로우 구현
- 앱 시작 시 서버와의 설치/FCM 토큰 동기화
- 실제 푸시/딥링크 매핑 구현

