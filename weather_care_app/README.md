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

앱은 외부 날씨 API를 직접 호출하지 않습니다. `config/kma.config.json`에는
운영 서버 주소만 저장하며 기상청 인증키는 앱 바이너리에 포함하지 않습니다.

```json
{
  "SERVER_URL": "https://weather-care-server.sy40222.workers.dev"
}
```

앱이 이 파일을 Flutter 자산으로 읽기 때문에 별도 실행 인자 없이 Debug와 Release에
모두 자동 적용됩니다. IntelliJ 실행 구성도 다시 수정할 필요가 없습니다.

첫 날씨 조회에서는 저장된 최근 위치를 먼저 확인하고, 운영 서버의 경량 Main 응답으로
상단 날씨 카드를 우선 표시합니다. Today 상세 자료와 Week 자료는 동시에 계속 조회해
도착하는 순서대로 화면을 갱신합니다.

운영 서버가 연결되지 않거나 중앙 수집 자료가 아직 준비되지 않으면
앱은 날씨를 임의로 대체하지 않고 재시도 안내를 표시합니다. 내장 고정 데이터나
외부 API 직접 조회는 런타임 폴백으로 사용하지 않습니다.

## 광고 개발 설정

- 소형 네이티브 광고 카드는 `Today`의 시간별 예보 바로 위와 `Main`의 콘텐츠 제일
  하단에 표시합니다. `Week`의 주간 요약과 첫 날짜 카드 사이에는 앱 색상·타이포를
  적용한 360px 중형 네이티브 카드를 표시합니다. 각 탭을 처음 실제로
  보았을 때 해당 위치의 광고만 로드하고, 다른 탭으로 이동해도 같은 인스턴스를
  유지합니다. 위치별 광고 단위를 분리해 요청·노출 성과를 따로 확인할 수 있습니다.
- 앱 오프닝 광고는 설치 후 최초 실행을 제외하고 두 번째 실행부터 준비합니다. UMP가
  광고 요청을 허용하면 날씨 로딩과 광고 로딩을 병렬로 진행합니다. 광고가 먼저
  준비되면 표시하지만 Main 콘텐츠가 먼저 준비되면 이번 콜드 스타트에서는 표시하지
  않고 다음 전경 진입 기회로 미룹니다. 닫은 뒤에는 다음 전경 진입용 광고를 미리
  로드하며, 4시간이 지난 캐시는 폐기합니다.
- UMP가 현재 요청에서 `canRequestAds=true`를 반환하기 전에는 Mobile Ads 초기화와
  광고 요청을 진행하지 않습니다. 선택 변경·오류·허용 철회 시 로드된 광고를 즉시
  화면에서 제거하고 폐기합니다.
- 모든 네이티브 광고 요청에 비개인화 광고 옵션을 명시하고 광고 콘텐츠 등급 상한은 `G`로
  설정합니다. 비개인화 광고도 IP 등 광고 전송·부정 사용 방지에 필요한 처리가 전혀
  없다는 뜻은 아닙니다.
- Debug/Profile은 Google 공식 Android/iOS 네이티브 테스트 광고 단위만 사용합니다. 운영 광고
  단위 ID를 넣어도 개발 빌드에서는 사용하지 않습니다.
- AdMob 앱에 UMP 메시지가 아직 게시되지 않은 개발 환경에서 광고 위젯 렌더링만
  확인할 때는 `--dart-define=ADMOB_TEST_BYPASS_UMP=true`를 명시할 수 있습니다. 이
  플래그는 Debug/Profile의 공식 테스트 광고에만 적용되고 Release에서는 항상
  무시됩니다. UMP 동의 흐름 검증 결과로 사용하지 않습니다.
- Release에서는 현재 플랫폼에 유효한 운영 광고 단위 ID가 하나라도 있으면 UMP를
  확인하고, UMP가 허용한 뒤 해당 ID의 광고를 요청합니다. ID가 없거나 형식이 잘못된
  위치는 광고를 요청하지 않습니다. Week는 기존
  `ADMOB_ANDROID_NATIVE_ID`/`ADMOB_IOS_NATIVE_ID`도 하위 호환하지만 새 빌드에서는
  아래 위치별 이름을 사용합니다.
  - `ADMOB_ANDROID_TODAY_NATIVE_ID`, `ADMOB_IOS_TODAY_NATIVE_ID`
  - `ADMOB_ANDROID_MAIN_NATIVE_ID`, `ADMOB_IOS_MAIN_NATIVE_ID`
  - `ADMOB_ANDROID_WEEK_NATIVE_ID`, `ADMOB_IOS_WEEK_NATIVE_ID`
  - `ADMOB_ANDROID_APP_OPEN_ID`, `ADMOB_IOS_APP_OPEN_ID`
- 기존 Android/iOS Week 배너 광고 단위는 2026-09-16 앱 코드에서 사용을 중단했습니다.
  운영 광고 단위는 다음과 같습니다. ID는 비밀값은 아니지만 소스에 하드코딩하지 않고
  Release 빌드 환경에서만 위 환경값으로 주입합니다.
  - Today 네이티브: Android `ca-app-pub-6152243173470406/2970868529`, iOS
    `ca-app-pub-6152243173470406/2609362710`
  - Main 네이티브: Android `ca-app-pub-6152243173470406/3701496264`, iOS
    `ca-app-pub-6152243173470406/8223195209`
  - Week 중형 네이티브: Android `ca-app-pub-6152243173470406/8770437222`, iOS
    `ca-app-pub-6152243173470406/8762698363` (AdMob 단위 이름:
    `날씨챙겨 Week 중형 네이티브`)
  - 앱 오프닝: Android `ca-app-pub-6152243173470406/2388414592`, iOS
    `ca-app-pub-6152243173470406/5946806649`

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
