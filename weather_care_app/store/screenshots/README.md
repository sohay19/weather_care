# 스토어 스크린샷

## 결과물

- iOS: `ios/` — 1320×2868 px, RGB PNG, 5장
- Android: `android/` — 1080×1920 px, RGB PNG, 5장
- iPad 13형: `ipad/` — 2064×2752 px, RGB PNG, 5장
- Android 태블릿: `android-tablet/` — 1440×2560 px, RGB PNG, 5장
- 미리보기: `preview-ios.png`, `preview-android.png`, `preview-ipad.png`, `preview-android-tablet.png`
- 실제 앱 캡처 원본: 휴대전화 `source/`, 태블릿 `source-tablet/`
- Google Play 그래픽 이미지: `../google-play/feature-graphic.png` — 1024×500 px, RGB PNG
- Google Play 스토어 아이콘: `../google-play/app-icon-512.png` — 512×512 px, RGBA PNG

노출 순서는 핵심 화면을 먼저 보여주도록 `Main → Today → Detail → Week → Setting`으로 구성했다.

## 홍보 문구

1. Main — `오늘 챙길 것만 / 한눈에`
2. Today — `시간대별 날씨를 / 하루 흐름으로`
3. Detail — `판단 근거까지 / 자세히`
4. Week — `일주일 계획을 / 미리 가볍게`
5. Setting — `내 위치와 알림을 / 내 생활에 맞게`

## 제작 기준

- 배경은 앱 아이콘 계열의 단색 `#4C77A4`를 사용했다.
- 앱 화면은 Android 에뮬레이터에서 현재 UI를 직접 캡처했다. 태블릿 원본은 823dp 폭의 반응형 레이아웃으로 별도 캡처했다.
- 스토어 이미지에는 네이티브·앱 오프닝 광고와 광고 제거 구매 배너를 노출하지 않았다.
- 생성형 이미지로 UI나 한글을 재현하지 않고 실제 화면을 그대로 사용했다.
- PNG는 투명도 없는 RGB로 저장했다.
- Google Play 그래픽 이미지는 앱 아이콘을 크게 반복하지 않고 실제 Main 브리핑 영역을 사용했다.

Google Play 대체 텍스트 권장안: `오늘 필요한 날씨를 미리 챙겨요 문구와 날씨챙겨 앱의 오늘 날씨 브리핑 화면`

다시 생성하려면 `python store/generate_store_screenshots.py`를 실행한다.
