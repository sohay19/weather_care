# 날씨챙겨 Flutter App

이 프로젝트는 내부 개발 명세(앱 버전)를 기반으로 한 초기 스캐폴딩입니다.

## 구조

- `lib/main.dart`: 앱 진입점
- `lib/app.dart`: 라우팅/테마 설정
- `lib/models/*`: Recommendation/Lifestyle/Weather/Settings 모델
- `lib/services/*`: API 클라이언트 및 서비스
- `lib/features/home/home_screen.dart`: Today - Detail - Main - Week - Setting 5탭 Shell
- `lib/features/home/tabs/*`: 한 화면 Main(당겨서 새로고침용 스크롤 표면), 오늘 준비, 시간별 상세, 주간 화면
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
앱은 최초 실행 시 기기별 설치 ID를 생성해 보관하고, 알림 권한이 허용되면 FCM
토큰을 설치 위치와 함께 서버에 등록합니다. Firebase가 토큰을 갱신할 때도 같은
설치 ID로 서버 등록값을 자동 갱신합니다.
알림 설정과 알림 시간은 기기에 영구 저장한 뒤 설치 ID별 서버 설정으로 순서대로
동기화합니다. 서버 연결이 끊기면 로컬 설정을 유지하고 다음 실행이나 설정 변경 때
다시 동기화합니다.
운영 응답에서는 서버가 기상청 단기예보에 생활기상지수 자외선과 에어코리아 PM10·PM2.5를 병합합니다. 앱은 `current.uvIndex`, `current.pm10`, `current.pm25`를 파싱하고, 결측시 `--`를 표시합니다.

운영 서버 장애 시 앱이 기상청 단기예보를 직접 조회하게 하려면
`config/kma.config.json`에 공공데이터포털 일반 인증키를 입력합니다.

```json
{
  "SERVER_URL": "https://weather-care-server.sy40222.workers.dev",
  "KMA_SERVICE_KEY": "발급받은_일반인증키"
}
```

앱이 이 파일을 Flutter 자산으로 읽기 때문에 별도 실행 인자 없이 Debug와 Release에
모두 자동 적용됩니다. IntelliJ 실행 구성도 다시 수정할 필요가 없습니다.

파일이 없는 새 개발 환경에서는 예제 파일을 복사한 뒤 키를 입력합니다.

```powershell
Copy-Item config/kma.config.example.json config/kma.config.json
```

실제 `config/kma.config.json`은 Git에서 제외됩니다. `--dart-define`을 별도로 지정하면
해당 값이 설정 파일보다 우선하므로 로컬 서버나 CI 설정도 계속 사용할 수 있습니다.

키가 설정된 상태에서 운영 서버만 실패하면 기상청 원시 예보를 직접 표시합니다.
추천·생활 날씨·준비물·타임라인·체감온도 등 서버 연산 항목은 `미지원`으로 표시하며,
인터넷 연결도 없으면 날씨 화면 전체를 `인터넷 연결 불가로 미지원`으로 표시합니다.
내장 고정 데이터 파일은 제거되어 런타임 폴백으로 사용되지 않습니다.

주의: 설정 파일은 Debug/Release 앱 바이너리에 자산으로 포함되므로 완전한 Secret으로
보호되지 않습니다. 직접 조회 기능을 운영할 경우 호출량 제한과 키 교체 정책을 함께
관리해야 합니다.

## 다음 단계

- GPS 권한 수집 및 지역 선택 플로우 구현
- 알림 선택 시 상세 화면으로 이동하는 딥링크 매핑
- Setting의 지역 선택과 서버 환경 Provider 지역 카탈로그 연결
