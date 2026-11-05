# 나눔스퀘어 네오 적용 스크린샷 · 2026-11-04

앱·홈 위젯·워치 앱·워치 위젯의 최신 글꼴을 반영한 촬영 자료다. 등록 이미지의 파란 배경과 SUITE 제목 디자인은 유지하며 앱 내부 화면에는 나눔스퀘어 네오를 사용한다.

- iPhone 앱: 전용 iPhone 15 Pro Max / iOS 17.5에서 최신 제품 앱과 운영 날씨를 촬영했다. 전체 1290×2796 원본에서 상태바 177px와 홈 표시 영역 102px만 제외한다.
- iPhone 홈 위젯: 실제 WidgetKit 홈 화면의 소형·중형·대형, 라이트·다크 6종을 촬영했다. 실제 위젯 내부의 글자·수치·색상 픽셀은 보존한다.
- iPad 등록 규격: 기존 제작 방식대로 같은 iPhone 원본을 비율 유지해 2064×2752로 배치한다. 별도 iPad 앱 실행 캡처는 아니다.
- Android 앱·홈 위젯: 11월 4일 전용 Android 에뮬레이터의 새 폰트 촬영 원본을 사용한다. 휴대전화 1080×2160, 태블릿 1440×2880에 동일 원본을 배치한다.
- Apple Watch: Series 10 42mm / watchOS 11.5에서 최신 앱 네 화면과 실제 WidgetKit 스마트 스택을 촬영했다. 연결된 전용 iPhone의 운영 날씨를 사용하고 자료를 주입하지 않았다. 등록용 앱 이미지는 416×496 RGB다. 스마트 스택 상단 시스템 날짜는 시뮬레이터가 표시한 11월 3일을 보존했으며 내부 날씨는 11월 4일 운영 자료다.
- Galaxy Watch: 11월 4일 Galaxy Watch9 실기기의 최신 앱 네 화면을 사용한다. 폰 제품 앱이 생성한 운영 Wear 자료를 촬영 도구로 전달했고, 촬영 빌드의 시각 보정·상단 시계 숨김 조건은 해당 원본 매니페스트에 기록되어 있다.

- Wear OS 워치 위젯: 최신 제품 타일을 Wear OS 7 / API 37 원형 에뮬레이터의 실제 시스템 위젯 캐러셀에 추가해 454×454 전체 화면을 촬영했다. iPhone 제품 앱이 생성한 운영 Wear 자료를 전용 에뮬레이터에 전달했다. 등록용 이미지는 438×438로 비율 유지 변환했다. 비활성 소형·대형 서비스를 활성화하지 않았다.
- 워치 등록·홍보 묶음은 앱 네 화면과 위젯 한 화면으로 각각 5장이다.

촬영은 Simulator 창을 열지 않고 전용 시뮬레이터·에뮬레이터에서 진행했다. 사용자 기기의 데이터와 설정은 변경하지 않는다. 광고 SDK의 개발용 검사 배너만 촬영용 iPhone 설치본의 `Info.plist`에서 비활성화했다. 제품 소스·날씨 응답·앱 화면은 변경하지 않았다. 설정 근거는 [Google의 Native Validator 안내](https://developers.google.com/admob/ios/native/validator)다.

원본의 `capture-manifest.json`은 촬영 환경, 크기, 원본 및 크롭 SHA-256을 기록한다. 등록용 PNG·ZIP의 무결성과 파일 일치를 검증한 뒤 전달한다. 전체 촬영 명령·접근성 트리·빌드 로그는 Git 제외 경로 `build/screenshot-refresh-20261104/`에 보관한다.

## 재생성

앱 루트에서 Pillow가 있는 Python으로 실행한다.

```sh
python3 store/generate_android_store.py --screenshots-only
python3 store/generate_ios_store.py
python3 store/generate_watch_promo.py
python3 store/package_screenshots.py
```

두 생성기는 11월 4일의 앱·위젯·워치 원본을 사용한다. 이전 날짜 ZIP과 촬영 기록은 과거 제작 이력이다.
