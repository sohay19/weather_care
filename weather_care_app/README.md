# 날씨챙겨 Flutter App

이 프로젝트는 내부 개발 명세(앱 버전)를 기반으로 한 초기 스캐폴딩입니다.

## 구조

- `lib/main.dart`: 앱 진입점
- `lib/app.dart`: 라우팅/테마 설정
- `lib/models/*`: Recommendation/Lifestyle/Weather/Settings 모델
- `lib/services/*`: API 클라이언트 및 서비스
- `lib/features/home/home_screen.dart`: Today - Detail - Main - Week - Setting 5탭 Shell
- `lib/features/home/tabs/*`: 비스크롤 Main, 오늘 준비, 시간별 상세, 주간 화면
- `lib/features/settings/*`: 설치/알림 토글 중심의 설정 화면
- `../weather_care_server`: 별도 Cloudflare Workers API 서버

## 실행

```bash
cd weather_care_app
flutter pub get
flutter run
```

## 환경 변수

별도 실행 인자 없이 Cloudflare 운영 서버를 기본으로 사용합니다.

```text
https://weather-care-server.sy40222.workers.dev
```

로컬 서버나 다른 환경을 사용할 때만 `--dart-define`으로 덮어쓸 수 있습니다.

```bash
# Windows/macOS/Linux 데스크톱
flutter run --dart-define=SERVER_URL=http://localhost:8787

# Android 에뮬레이터
flutter run -d emulator-5554 --dart-define=SERVER_URL=http://10.0.2.2:8787
```

별도 값을 지정하지 않으면 모든 플랫폼에서 위 Cloudflare 운영 서버를 사용합니다.
운영 응답을 사용하면 홈 배지에 서버가 내려준 `기상청 단기예보` 출처가 표시됩니다.

## 다음 단계

- GPS 권한 수집 및 지역 선택 플로우 구현
- 앱 시작 시 서버와의 설치/FCM 토큰 동기화
- 실제 푸시/딥링크 매핑 구현
- 미세먼지·자외선 공식 Provider와 서버 판단 근거 연결
