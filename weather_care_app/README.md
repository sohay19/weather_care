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

첫 날씨 조회에서는 저장된 최근 위치를 먼저 확인하고, 운영 서버의 경량 Main 응답으로
상단 날씨 카드를 우선 표시합니다. Today 상세 자료와 Week 자료는 동시에 계속 조회해
도착하는 순서대로 화면을 갱신합니다.

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

## 광고 개발 설정

- 광고는 `Week` 탭을 실제로 보고 있을 때만 주간 요약과 날짜 카드 사이에 인라인
  적응형 배너로 로드합니다. Main·Today·Detail·Setting에는 표시하지 않습니다.
- UMP가 현재 요청에서 `canRequestAds=true`를 반환하기 전에는 Mobile Ads 초기화와
  광고 요청을 진행하지 않습니다. 선택 변경·오류·허용 철회 시 로드된 광고를 즉시
  화면에서 제거하고 폐기합니다.
- 모든 배너 요청에 비개인화 광고 옵션을 명시하고 광고 콘텐츠 등급 상한은 `G`로
  설정합니다. 비개인화 광고도 IP 등 광고 전송·부정 사용 방지에 필요한 처리가 전혀
  없다는 뜻은 아닙니다.
- Debug/Profile은 Google 공식 Android/iOS 테스트 광고 단위만 사용합니다. 운영 광고
  단위 ID를 넣어도 개발 빌드에서는 사용하지 않습니다.
- AdMob 앱에 UMP 메시지가 아직 게시되지 않은 개발 환경에서 광고 위젯 렌더링만
  확인할 때는 `--dart-define=ADMOB_TEST_BYPASS_UMP=true`를 명시할 수 있습니다. 이
  플래그는 Debug/Profile의 공식 테스트 광고에만 적용되고 Release에서는 항상
  무시됩니다. UMP 동의 흐름 검증 결과로 사용하지 않습니다.
- Release 광고는 기본 차단됩니다.
  `ADMOB_ANDROID_BANNER_ID`, `ADMOB_IOS_BANNER_ID`, `ADMOB_RELEASE_ENABLED=true`가 모두
  있어야 UMP와 광고 경로를 시작합니다. 현재 운영 빌드 환경에는 이 값을 주입하지
  않았으므로 Release 광고는 계속 꺼져 있습니다.
- 2026-09-14 생성한 운영 배너 광고 단위 ID는 Android
  `ca-app-pub-6152243173470406/8661897062`, iOS
  `ca-app-pub-6152243173470406/6134971926`입니다. 비밀값은 아니지만 소스에는
  하드코딩하지 않고, 위 선행 조건을 마친 Release 빌드 환경에서만 주입합니다.

운영 광고 송출은 UMP 메시지, 공개 방침, 스토어 연령 설정과 실기 검증이 끝날 때까지
완료 상태로 간주하지 않습니다.

## 앱 시작 경계

- 앱은 별도의 연령 확인 화면 없이 온라인 날씨 기능을 바로 준비합니다.
- Android에서는 FCM·Analytics 자동 시작을 기본 OFF로 두고 Firebase·Mobile Ads의
  조기 초기화 provider를 병합 매니페스트에서 제거했습니다. iOS도 FCM·Analytics 자동
  시작을 기본 OFF로 설정했습니다. SDK 코드는 앱에 포함되며 플러그인 등록 자체까지
  제거한 것은 아닙니다.
- 설치 등록·소유권 이전 요청의 기존 서버 계약 필드는 운영 Worker와의 하위 호환을 위해
  유지합니다. 사용자에게 연령을 질문하거나 답을 로컬에 저장하지 않습니다.

## 다음 단계

- 운영 D1 `0009`와 Worker 배포는 2026-09-14 완료
- 앱스토어·Play Console·AdMob의 대상 연령 설정 재검토
- Android 실물/iOS에서 UMP 동의·거부·변경 및 광고 미요청 경계 검증
- [x] 운영 개인정보처리방침 확정·Pages 게시용 본문과 앱 내 URL 연결
- Play Console·App Store에 `https://weather-care-privacy.pages.dev/` 등록
