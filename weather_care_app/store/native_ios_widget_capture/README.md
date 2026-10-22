# iOS 실제 위젯 촬영 도구

현재 WidgetKit 확장 소스와 폰트·아이콘을 그대로 컴파일해 전용 시뮬레이터의 SpringBoard 홈 화면에서 촬영한다. Flutter 앱·사용자의 실제 iPhone·운영 서버와 분리된 촬영용 호스트를 사용한다. 호스트는 서울시 중구 18°/체감17°/최저12°/최고22°와 우산·겉옷의 예시 자료를 App Group에 저장한다. 실제 위젯 확장을 재구현하지 않는다.

## 구성

- `build_capture.rb`: xcodeproj Ruby 라이브러리로 ignored 빌드 폴더에 독립 앱·위젯 확장·XCTest UI 타깃 생성
- `Host.swift`: 촬영용 예시 자료 저장 및 WidgetCenter 갱신
- `CaptureTests.swift`: SpringBoard 접근성 트리 조회·터치·원본 화면 촬영
- `control.py`: 실행 중인 XCTest에 명령을 전달하고 원본/트리를 보관
- `capture_session.py`: 실제 접근성 상태에 따라 추가·크기 변경·촬영을 순서대로 수행
- `export_capture.py`: 접근성 트리의 실제 위젯 프레임으로 크롭하고 내부 픽셀 보존 검사

## 실행

앱 루트에서 실행한다. Xcode, iOS 시뮬레이터 런타임, Ruby xcodeproj, Pillow가 필요하다. 실제 사용자 기기 대신 촬영용 시뮬레이터 UUID를 지정한다. Simulator 앱 창을 열지 않는다.

```sh
ruby store/native_ios_widget_capture/build_capture.rb
xcodebuild -project build/ios-native-widget-20261022/project/WidgetCapture.xcodeproj \
  -scheme Capture -configuration Debug -destination 'platform=iOS Simulator,id=<촬영용 UUID>' \
  -derivedDataPath build/ios-native-widget-20261022/derived test
```

테스트가 실행되면 별도 터미널에서 명령을 전달한다. `state.txt`의 실제 라벨과 프레임을 보고 다음 명령을 정한다. iOS의 편집 상태·화면 크기에 따라 홈 화면 편집→편집→위젯 추가→날씨챙겨 촬영→‘ 위젯 추가’ 순서로 연다. 필요하면 ‘위젯 검색’에 ‘날씨’를 입력한다. 홈 위젯을 길게 누르면 ‘작은 위젯’, ‘중간 크기 위젯’, ‘큰 위젯’으로 변경할 수 있다.

```sh
python3 store/native_ios_widget_capture/control.py --device <촬영용 UUID> \
  --command '{"action":"dump","name":"phone-light-small-home"}'
```

명령은 `dump`, `home`, `tap`, `press`, `type`, `swipe`, `capture`, `finish`를 지원한다. 라벨은 `label`, 좌표는 화면 전체에 대한 비율 `x`/`y`, 이동 끝점은 `dx`/`dy`, 입력 문자는 `text`, 촬영 파일명은 `name`에 지정한다. 시스템 모드는 `xcrun simctl ui <UUID> appearance light` 또는 `dark`로 변경한다. 각 모드·크기를 실제 홈 화면에서 확인한 뒤 `phone-light-small-home` 형식으로 소형·중형·대형 6개를 촬영한다. iPad는 `tablet-...` 형식을 사용한다.

자동 촬영은 `capture_session.py --device <UUID> --kind phone --output <원본 폴더>`로 실행한다. iOS 17은 `--legacy`를 추가해 크기별로 추가·촬영·제거하며, iOS 18 이후는 홈 위젯의 크기 변경 메뉴를 사용한다. 이번 iPhone 최종 촬영은 iOS 17.5, iPad는 iOS 18.6을 사용했다. 별도로 시도한 iPhone 18.6·26.3.1의 홈 전환 오류 결과는 최종 이미지에 사용하지 않았다.

```sh
python3 store/native_ios_widget_capture/control.py --device <촬영용 UUID> \
  --command '{"action":"finish"}' --output build/ios-native-widget-20261022/raw/phone
python3 store/native_ios_widget_capture/export_capture.py --kind phone \
  --raw build/ios-native-widget-20261022/raw/phone
```

실제 위젯 바탕색이 시작하는 경계 밖의 홈 배경만 투명하게 제거하며 불투명한 위젯 내부 픽셀은 그대로 유지한다. 전체 화면 원본의 SHA256·크롭 좌표·논리 크기·배율과 결과 해시를 기록한다. PNG의 수치나 한글·색상을 합성하지 않는다. 촬영 후 테스트를 완료하고 전용 시뮬레이터를 종료한다.
