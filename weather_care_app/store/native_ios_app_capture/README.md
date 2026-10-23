# 실제 iOS 앱 화면 촬영

Flutter 테스트용 예시 화면 대신, 전용 시뮬레이터에 설치한 제품 앱을 XCTest로 조작하고 전체 화면 PNG를 보관한다. 앱 UI·서버 응답·사용자 설정을 코드로 주입하지 않는다. 운영 서버의 날씨를 앱에서 조회하고 지역 선택·스크롤·테마·알림 설정은 화면을 통해 조작한다.

## 실행

앱 루트에서 Flutter 3.47.4로 시뮬레이터 앱을 빌드하고 지정한 촬영용 기기에 설치한다. 기존 사용자 기기에는 설치하지 않는다. Simulator 창을 직접 열지 않는다.

```sh
flutter build ios --simulator --debug --no-pub \
  --dart-define=SERVER_URL=https://weather-api.codesoha.com
xcrun simctl install <촬영 UUID> build/ios/iphonesimulator/Runner.app
ruby store/native_ios_app_capture/build_capture.rb
xcodebuild -project build/ios-live-store-20261023/project/AppCapture.xcodeproj \
  -scheme AppCapture -destination 'platform=iOS Simulator,id=<촬영 UUID>' \
  -derivedDataPath build/ios-live-store-20261023/derived test
```

`control.py --device <UUID> --command '<명령 JSON>' --output <보관 폴더>`로 준비된 XCTest에 명령을 보낸다. `dump`, `tap`, `type`, `swipe`, `press`, `home`, `activate`, `launch`, `finish`를 지원한다. 접근성 트리를 먼저 확인하고 실제 `label`이나 `identifier`를 사용한다. 좌표는 화면에 대한 비율 `x`·`y`이며 스와이프 끝점은 `dx`·`dy`다. 시스템 UI는 `system: true`로 지정한다. `name`에 원본 파일명을 지정하면 PNG·접근성 트리·명령 기록을 보관한다.

심화 날씨 촬영만 `--dart-define=SERVER_URL=https://weather-test-api.codesoha.com`으로 다시 빌드·설치한다. 테스트 인증은 기존 `config/kma.config.json`을 사용하며 키 값을 촬영 명령·문서·배포 ZIP에 복사하지 않는다. 최종 `build/ios/iphonesimulator/Runner.app`은 테스트 서버용이므로 후속 실행 시 서버 구성을 확인한다.

앱 촬영 이름은 `main`, `timeline`, `dark-main`, `advanced-values`, `week-detail`, `notification-settings`다. `export_capture.py --device <UUID> --raw <원본 폴더>`는 상태바 177px와 홈 표시 영역 102px만 제외하고 원본·크롭 해시를 기록한다. Week 날짜별 원본은 내보낼 때 `week.png`로 저장한다. 앱 탭 메뉴를 포함한 전체 화면을 유지하며 iPad 등록 규격에도 동일한 iPhone 원본을 사용한다. 화면 안의 숫자·글자·UI는 수정하지 않는다.

홈 위젯은 같은 제품 앱이 실제 날씨를 저장한 뒤 기존 `../native_ios_widget_capture/capture_session.py`에 `--real-app`을 전달해 촬영한다. iOS 17은 `--legacy`를 추가한다. 앱 촬영을 이어갈 때는 `--keep-session`을 추가한다. 해당 모드는 예시 자료를 저장하는 별도 호스트를 실행하지 않는다. 촬영 완료 후 테스트를 종료하고 이번 작업의 전용 시뮬레이터만 종료한다.
