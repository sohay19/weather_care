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

운영 서버 장애 시 앱이 기상청 단기예보를 직접 조회하게 하려면 공공데이터포털에서
발급받은 일반 인증키를 추가합니다.

```bash
flutter run -d emulator-5554 --dart-define=KMA_SERVICE_KEY=발급받은_일반인증키
```

IntelliJ에서는 `main.dart` 실행 구성의 `Additional run args`에 같은 인자를
입력합니다. 운영 서버 URL은 기본값이므로 `SERVER_URL` 인자가 없어도 됩니다.

```text
--dart-define=KMA_SERVICE_KEY=발급받은_일반인증키
```

키가 설정된 상태에서 운영 서버만 실패하면 기상청 원시 예보를 직접 표시합니다.
추천·생활 날씨·준비물·타임라인·체감온도 등 서버 연산 항목은 `미지원`으로 표시하며,
인터넷 연결도 없으면 날씨 화면 전체를 `인터넷 연결 불가로 미지원`으로 표시합니다.
샘플 데이터는 런타임 폴백으로 사용하지 않습니다.

주의: `--dart-define` 값은 앱 바이너리에 포함되므로 배포 앱에서 완전한 Secret으로
보호되지 않습니다. 직접 조회 기능을 운영할 경우 호출량 제한과 키 교체 정책을 함께
관리해야 합니다.

## 다음 단계

- GPS 권한 수집 및 지역 선택 플로우 구현
- 앱 시작 시 서버와의 설치/FCM 토큰 동기화
- 실제 푸시/딥링크 매핑 구현
- 미세먼지·자외선 공식 Provider와 서버 판단 근거 연결
