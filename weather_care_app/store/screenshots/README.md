# 스토어 스크린샷

## 2026-10-22 Android 스크린샷 갱신

현재 UI 기준으로 Android 휴대전화·태블릿 각8장을 다시 만들었다. 최신 등록 순서·제작 기준·재생성 방법은 [Android 스크린샷 최신 안내](SCREENSHOTS_20261022.md)를 따른다. 스크린샷 전용 묶음은 `../weather-care-screenshots-20261022.zip`이다. 그래픽·iOS 헤더/검색 결과·iOS/iPad 스크린샷은 유지했다. 아래는 이전 제작 이력이다.

추가로 Android 3번·4번의 위젯을 실제 Android Provider와 AppWidgetHost로 촬영한 화면으로 교체했다. 준비물 아이콘은 왼쪽, 이름은 남은 영역 중앙에 배치하고 큰 위젯의 두 줄 브리핑만 중앙 정렬했다. 나머지 브리핑은 기존 왼쪽 정렬이다. 최저·최고 표시는 실제 위젯의 글꼴·간격 그대로 사용한다. 원본과 제작 기준은 최신 안내를 따른다.

## 2026-10-21 Android 최신 이미지

Android 휴대전화·태블릿은 현재 앱 기준으로 각각 8장과 그래픽 이미지를 새로 제작했다. 구성·원본·재생성 방법은 [Android 최신 안내](ANDROID_20261021.md)를 따른다. 배포 묶음은 `../google-play/weather-care-android-store-20261021.zip`이다. 아래 내용은 이전 제작 이력이며 iOS·iPad는 기존 이미지를 유지한다. Android에는 아래의 옛 9장 순서를 사용하지 않는다.

## 결과물

- iOS: `ios/` — 1320×2868 px, RGB PNG, 9장
- Android: `android/` — 1080×1920 px, RGB PNG, 9장(등록 후보)
- iPad 13형: `ipad/` — 2064×2752 px, RGB PNG, 9장
- Android 태블릿: `android-tablet/` — 1440×2560 px, RGB PNG, 9장(등록 후보)
- 미리보기: `preview-ios.png`, `preview-android.png`, `preview-ipad.png`, `preview-android-tablet.png`
- 실제 앱 캡처 원본: 휴대전화 `source/`, 태블릿 `source-tablet/`
- Google Play 그래픽 이미지: `../google-play/feature-graphic.png` — 1024×500 px, RGB PNG
- Google Play 스토어 아이콘: `../google-play/app-icon-512.png` — 512×512 px, RGBA PNG

노출 순서는 핵심 화면을 먼저 보여주도록 `Main → Today → Detail → Widget → Setting → Week → Notification → Push Alert`로 구성했다.

9번 `09-dark-mode.png`는 앱과 위젯의 다크모드를 소개하는 별도 추가 이미지다. Google Play는 기기별 최대 8장을 허용하므로, 등록할 때 기존 5번 설정 이미지 대신 9번을 선택하는 구성을 권장한다. iOS·iPad는 기존 8장에 9번을 추가해 모두 사용할 수 있다. 권장 순서는 `Main → Today → Detail → Widget → Dark Mode → Setting → Week → Notification → Push Alert`다. [Google Play 공식 안내](https://support.google.com/googleplay/android-developer/answer/9866151), [Apple 공식 안내](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

## 홍보 문구

1. Main — `오늘 챙길 것만 / 한눈에` (체크리스트 준비물이 보이는 화면)
2. Today — `시간대별 날씨를 / 하루 흐름으로` (아래로 스크롤한 시간별 예보 화면)
3. Detail — `판단 근거까지 / 자세히`
4. Widget — `홈 화면에서도 / 날씨를 바로 확인`
5. Setting — `내 위치와 알림을 / 내 생활에 맞게`
6. Week — `일주일 계획을 / 미리 가볍게`
7. Notification — `원하는 알림만 / 필요한 시간에`
8. Push Alert — `필요한 날씨를 / 알림으로 바로`
9. Dark Mode — `앱과 위젯 모두 / 다크 모드로 편안하게`

## 제작 기준

- 배경은 앱 아이콘 계열의 단색 `#4C77A4`를 사용했다.
- 앱 화면은 Android 에뮬레이터에서 현재 UI를 직접 캡처했다. 태블릿 원본은 823dp 폭의 반응형 레이아웃으로 별도 캡처했다.
- 스토어 이미지에는 네이티브·앱 오프닝 광고와 광고 제거 구매 배너를 노출하지 않았다.
- 1~3번과 5~7번은 생성형 이미지로 UI나 한글을 재현하지 않고 실제 화면을 그대로 사용했다.
- 4번은 iPhone·iPadOS의 WidgetKit 규격과 Android 위젯 XML의 여백을 각각 적용하고, 네이티브 구현의 배치·placeholder 문구·색상·SUITE 폰트·준비물 자산을 기준으로 재현했다. iOS는 보이는 22pt 원형과 44pt 터치 영역, 소형의 위치 아래 기준시간, 중형·대형의 새로고침 버튼 왼쪽 기준시간, 조정된 상·하 여백을 반영했고 Android는 실제 24dp 새로고침 버튼을 반영했다.
- 8번은 앱이 발송하는 형식의 알림 4개를 사용했다. Android는 앱의 실제 알림 채널로 표시한 네 알림에 앱 아이콘·제목·본문이 각각 보이도록 시스템 알림 패널을 직접 캡처했다. iPhone은 iOS 18.6 시뮬레이터에 네 알림을 실제로 전달한 뒤 알림 센터를 직접 캡처했다. iPad는 동일한 네 제목·본문과 잠금화면 상태 요소, 반투명 블러 재질을 적용해 iPadOS 알림 목록 형태로 재현했다.
- 작은·중간·큰 위젯은 한 장 안에서 위부터 세로로 하나씩 나열하며 최종 이미지의 세로 길이는 다른 스토어 스크린샷과 동일하게 유지한다.
- PNG는 투명도 없는 RGB로 저장했다.
- 9번은 2026-10-11에 실제 Android 에뮬레이터에서 캡처한 하남시 감북동 앱 Main과 대형 홈 위젯을 함께 배치했다. 현재 날씨 아이콘의 원래 컬러와 새로고침 버튼 옆 기준시간 배치를 반영했다. 원본은 `source/dark-main.png`, `source/dark-widget.png`에 보존했다. 시스템 바·홈 화면의 다른 앱 아이콘을 제외한 크롭과 비율 유지 확대만 적용했으며 UI 색상·문구·날씨 수치를 변경하지 않았다. 태블릿 규격 이미지도 같은 휴대전화 캡처를 사용한 소개 이미지이며, 태블릿에서 새로 촬영한 화면은 아니다.
- iOS·iPad 9번은 2026-10-11 iOS 27.0의 iPhone 18 Pro 시뮬레이터에서 앱 Main과 WidgetKit 대형 홈 위젯을 직접 캡처했다. 앱의 지역 선택 화면에서 경기도 이천시 호법면을 선택해 실제 서버 자료를 표시했다. 현재 26.3℃·체감 28.1℃·오후 4:57 기준이 앱과 위젯에 일치한다. 원본은 `source/dark-main-ios.png`, `source/dark-widget-ios.png`(각 1206×2622)에 보존했다. 생성형 UI·재색칠·날씨 수치 변경 없이 시스템 바와 다른 위젯·아이콘만 크롭하고 비율을 유지해 배치했다. iPad용 9번도 같은 iPhone 캡처를 활용한 소개 이미지이며 iPad에서 직접 촬영한 화면은 아니다. 기존 1~8번의 원본·이미지는 유지했다. 버튼 외곽 44pt 영역의 거의 투명한 배경과 수정된 기준시간 배치를 반영한 최신 iOS 빌드를 설치한 뒤 재촬영했다. 세 크기의 실제 홈 위젯 캡처와 새로고침 검증 기록은 `verification-ios/`에 별도로 보존했다.
- Google Play 그래픽 이미지는 앱 아이콘을 크게 반복하지 않고 실제 Main 브리핑 카드를 사용했다. 캡처의 날짜·시각 영역은 제외했다.

Google Play 대체 텍스트 권장안: `날씨에 맞춰 오늘을 챙겨요 문구와 현재 날씨·자외선·대기질을 보여주는 날씨챙겨 브리핑 카드`

다시 생성하려면 `python store/generate_store_screenshots.py`를 실행한다.

최신 Android 이미지는 `python store/generate_android_store.py`로 생성한다. 이전 `python store/generate_store_screenshots.py --dark-mode-only` 옵션도 현재 Android 8장 구성과 묶음을 재생성한다.

iPhone·iPad 다크모드 이미지와 미리보기만 생성하려면 `python store/generate_store_screenshots.py --ios-dark-mode-only`를 실행한다.

`../app-store/weather-care-ios-screenshots.zip`에는 iPhone·iPad 등록 이미지 각 9장과 미리보기, 이 안내를 담았다. 기존 통합 스크린샷·스토어 에셋 ZIP도 갱신했다. 등록 이미지의 크기·RGB·투명도 없음·PNG 및 ZIP 무결성을 로컬에서 확인했으며 App Store Connect 등록은 수행하지 않았다. [Apple 스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
