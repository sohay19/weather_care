# 스토어 스크린샷

## 결과물

- iOS: `ios/` — 1320×2868 px, RGB PNG, 8장
- Android: `android/` — 1080×1920 px, RGB PNG, 8장
- iPad 13형: `ipad/` — 2064×2752 px, RGB PNG, 8장
- Android 태블릿: `android-tablet/` — 1440×2560 px, RGB PNG, 8장
- 미리보기: `preview-ios.png`, `preview-android.png`, `preview-ipad.png`, `preview-android-tablet.png`
- 실제 앱 캡처 원본: 휴대전화 `source/`, 태블릿 `source-tablet/`
- Google Play 그래픽 이미지: `../google-play/feature-graphic.png` — 1024×500 px, RGB PNG
- Google Play 스토어 아이콘: `../google-play/app-icon-512.png` — 512×512 px, RGBA PNG

노출 순서는 핵심 화면을 먼저 보여주도록 `Main → Today → Detail → Widget → Setting → Week → Notification → Push Alert`로 구성했다.

## 홍보 문구

1. Main — `오늘 챙길 것만 / 한눈에` (체크리스트 준비물이 보이는 화면)
2. Today — `시간대별 날씨를 / 하루 흐름으로` (아래로 스크롤한 시간별 예보 화면)
3. Detail — `판단 근거까지 / 자세히`
4. Widget — `홈 화면에서도 / 날씨를 바로 확인`
5. Setting — `내 위치와 알림을 / 내 생활에 맞게`
6. Week — `일주일 계획을 / 미리 가볍게`
7. Notification — `원하는 알림만 / 필요한 시간에`
8. Push Alert — `필요한 날씨를 / 알림으로 바로`

## 제작 기준

- 배경은 앱 아이콘 계열의 단색 `#4C77A4`를 사용했다.
- 앱 화면은 Android 에뮬레이터에서 현재 UI를 직접 캡처했다. 태블릿 원본은 823dp 폭의 반응형 레이아웃으로 별도 캡처했다.
- 스토어 이미지에는 네이티브·앱 오프닝 광고와 광고 제거 구매 배너를 노출하지 않았다.
- 1~3번과 5~7번은 생성형 이미지로 UI나 한글을 재현하지 않고 실제 화면을 그대로 사용했다.
- 4번은 iPhone·iPadOS의 WidgetKit 규격과 Android 위젯 XML의 여백을 각각 적용하고, 네이티브 구현의 배치·placeholder 문구·색상·SUITE 폰트·준비물 자산을 기준으로 재현했다. iOS는 보이는 22pt 원형과 44pt 터치 영역, 소형의 위치 아래 기준시간, 조정된 상·하 여백을 반영했고 Android는 실제 24dp 새로고침 버튼을 반영했다.
- 8번은 앱이 발송하는 형식의 알림 4개를 사용했다. Android는 앱의 실제 알림 채널로 표시한 네 알림에 앱 아이콘·제목·본문이 각각 보이도록 시스템 알림 패널을 직접 캡처했다. iPhone은 iOS 18.6 시뮬레이터에 네 알림을 실제로 전달한 뒤 알림 센터를 직접 캡처했다. iPad는 동일한 네 제목·본문과 잠금화면 상태 요소, 반투명 블러 재질을 적용해 iPadOS 알림 목록 형태로 재현했다.
- 작은·중간·큰 위젯은 한 장 안에서 위부터 세로로 하나씩 나열하며 최종 이미지의 세로 길이는 다른 스토어 스크린샷과 동일하게 유지한다.
- PNG는 투명도 없는 RGB로 저장했다.
- Google Play 그래픽 이미지는 앱 아이콘을 크게 반복하지 않고 실제 Main 브리핑 카드를 사용했다. 캡처의 날짜·시각 영역은 제외했다.

Google Play 대체 텍스트 권장안: `날씨에 맞춰 오늘을 챙겨요 문구와 현재 날씨·자외선·대기질을 보여주는 날씨챙겨 브리핑 카드`

다시 생성하려면 `python store/generate_store_screenshots.py`를 실행한다.
