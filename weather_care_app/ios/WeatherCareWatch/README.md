# 날씨챙겨 Apple Watch 앱

watchOS 10 이상, iPhone 동반 앱이다. 기존 Flutter의 `HomeWidgetService.publish`가 만든 날씨 스냅샷과 `buildWearWeatherDetails`를 WatchConnectivity로 전달한다. 서버 키·설치 인증 정보·정밀 위치는 워치로 보내지 않는다.

- SwiftUI 앱: 현재 날씨 → 준비물 → 타임라인 → 기상·생활. 기존 날씨 PNG와 SUITE를 사용한다. WidgetKit에는 같은 날씨 PNG를 64px로 축소한 `_accessory` 자산을 사용한다. 원본 512px를 그대로 쓰면 작은 위젯의 이미지 아카이브 크기 제한을 넘는다.
- 준비물 체크는 지역·한국 날짜·종류별 워치 로컬 기록이다. 행 본문은 상세, 오른쪽 체크는 상태 변경이다.
- 상세에는 설명 아래 지역명과 해당 자료의 기준시각을 따로 표시한다. ‘목록으로’와 시스템 뒤로 가기를 제공한다.
- `WeatherCareWatchWidgets`: 스마트 스택과 사각/원형 컴플리케이션. 사각형은 지역(왼쪽)/기준시각(오른쪽), 아이콘·기온·체감, 최저·최고의 세 줄이다.
- 워치와 워치 위젯은 `group.com.codesoha.weathercare.watch` 저장소를 공유한다. iPhone의 앱 그룹과는 별개다.
- 자료가 3시간을 넘기거나 시각이 비정상이면 오래된 추천·예보·생활값을 숨긴다. 추천의 유효기간도 별도로 확인한다. 삭제 표식과 revision으로 이전 자료의 복구를 막는다.

## 빌드와 실행

기존 `ios/Runner.xcworkspace`에 앱/WidgetKit 타깃과 공유 `WeatherCareWatch` scheme이 들어 있다. 타깃 설정을 재생성할 때만 앱 루트에서 `ruby tools/configure_watch_targets.rb`를 실행한다. 이 도구는 Runner의 버전/빌드 번호를 워치 타깃에도 맞춘다. 릴리스 번호를 바꾸면 함께 갱신한다.

Flutter 3.47.4를 사용한다. 워치 동반 앱 추가 후에는 simulator device ID가 필수다.

```sh
/Users/soha/flutter_3.47.4/bin/flutter build ios --simulator --debug -d <iPhone-UUID>
xcrun simctl install <iPhone-UUID> build/ios/iphonesimulator/Runner.app
xcrun simctl install <Watch-UUID> build/ios/iphonesimulator/Runner.app/Watch/WeatherCareWatch.app
xcrun simctl launch <iPhone-UUID> com.codesoha.weathercare
xcrun simctl launch <Watch-UUID> com.codesoha.weathercare.watchkitapp
```

iPhone과 Watch는 먼저 `simctl pair`로 호환 OS 기기끼리 연결한다. iPhone에서 위치 권한 없이도 수동 구역을 선택할 수 있다. 날씨가 정상 조회되면 워치로 보낸다. 워치 ‘새로고침’은 도달 가능한 iPhone에 기존 날씨 재조회 경로를 요청하며, 도달할 수 없으면 마지막 자료와 연결 안내를 유지한다. OS가 백그라운드 전송 시점을 결정하므로 분 단위 갱신을 보장하지 않는다.

시뮬레이터에서도 앱 그룹 접근을 확인하려면 서명된 빌드 결과를 설치해야 한다. `CODE_SIGNING_ALLOWED=NO`로 만든 단독 워치 앱은 공유 그룹이 등록되지 않을 수 있다. 실제 기기 배포 시에는 watch 앱/위젯 bundle ID와 앱 그룹의 개발팀 provisioning도 준비해야 한다.

## 검증

```sh
cd ios/WatchShared
swift test --scratch-path ../../build/watch-model-tests
```

삭제 후 이전 revision 무시, 오래됨·미래 시각 경계, 준비물 유효기간, 실제 0과 결측, 지역/날짜별 체크 키를 검증한다. Flutter 회귀 검사는 `wear_weather_details_test`, `home_location_test`, `server_data_access_test`를 사용한다.

2026-11-03 전용 기기:
- iPhone 16 Pro / iOS 18.6: `4EBFF416-CCE9-4F79-9C88-2C272BF821A7`
- Apple Watch Series 10 42mm / watchOS 11.5: `565FCA1F-E64D-4F95-AE9E-F2AEC188EE0D`
- Pair: `1BA74C80-9DA5-4A1C-A765-758956443E56`

기존 사용자 시뮬레이터와 분리했다. 사용자 화면에 영향을 주지 않도록 후반 검증은 창 전환 없이 simctl/XCTest로 수행한다. 원본 화면·로그는 제외 경로 `build/watch-verification`, 모델 검사 로그는 `build/watch-model-tests.log`에 둔다.

실제 날씨로 4화면, 준비물 체크/상세/복귀, 습도 상세, 워치 새로고침, 앱 재설치 후 체크 보존, 스마트 스택 추가와 탭 후 현재 화면 진입을 확인했다. 최종 iPhone/Watch 캐시 revision은 `1793680438878`로 같았다. 실제 캡처·수치·해시는 저장소 `docs/design/apple-watch-20261103/native`에 보존한다. 실제 워치 기기, 컴플리케이션의 페이스 배치와 장시간 백그라운드 전달은 별도 검증이 필요하다.

앱 아이콘은 [Apple의 단일 1024px 자산 안내](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)에 맞춰 watchOS용으로 등록한다. 기존 앱 아이콘 원본을 재사용한다.
