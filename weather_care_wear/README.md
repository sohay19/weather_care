# 날씨챙겨 워치 앱

최신 디자인 시안 0.8을 바탕으로 만든 Android 네이티브 Wear OS 모듈이다. 폰 앱과 같은 `com.codesoha.weathercare` 패키지와 서명을 사용한다. 기존 Flutter 폰 앱과 서버의 알림·지역 정책은 유지한다.

## 구현

- 챙겨요 → 현재 날씨 → 타임라인 → 기상/생활을 가로로 이동한다. 목록은 세로 스크롤·회전 입력을 지원한다.
- 준비물 오른쪽 체크박스는 설명 탭과 분리하며 지역·한국 날짜·품목별로 저장한다. 자료가 갱신돼도 같은 날 체크를 유지한다.
- 현재 날씨는 기온·아이콘 세로 중앙, 어제 기온과 체감 비교를 표시한다. 비교 응답이 없으면 자료 없음으로 표시한다.
- 기상/생활은 Today와 같은 10개 지표를 2열로 보여주며 항목을 누르면 값·기준 시각·설명을 확인한다.
- 현재 제공 방식은 ‘날씨챙겨’라는 이름의 독립 전체 화면 타일이다. 위쪽 앱 이름/지역·기준시각, 중앙 날씨아이콘·기온/브리핑, 아래 최저·최고를 표시하고 누르면 현재날씨로 이동한다.
- 삼성 묶음 기본 제목이 ‘도구’로 생성되는 것을 피하도록 소형·대형 위젯 서비스는 Manifest에서 비활성화했다. 이전 위젯 구현/자산은 보존하지만 현재 추가 목록에는 전체 화면 타일1개만 제공한다.
- 기온 SHORT_TEXT/날씨 SMALL_IMAGE 컴플리케이션 제공자를 별도로 등록했다. 자체 워치페이스는 만들지 않는다. 실제 슬롯은 워치페이스가 결정한다.
- 폰 위젯의 `WidgetIconRenderer.java`, 나눔스퀘어 네오 글꼴, 준비물 자산을 빌드 때 원본에서 가져온다.

## 자료 흐름

페어링된 기기는 폰에서 채택한 위젯 스냅샷과 Today 상세 → Data Layer `/weather-care/v1/snapshot` → 워치 로컬 캐시 → 앱·타일·컴플리케이션으로 전달한다. 비밀키·설치 인증정보·정밀 좌표는 보내지 않는다. 별도 워치 위치 권한이나 FCM을 추가하지 않았다.

폰의 메인 화면 저장뿐 아니라 기존 백그라운드 위치/위젯 갱신이 성공한 경로에서도 발행한다. 상세 조회는 폰 위젯 갱신을 지연하지 않는 직렬 작업으로 처리하고, 조회 전 구역이 바뀌었으면 결과를 버린다. 폰에 페어링된 워치가 없으면 추가 Today 조회를 생략한다.

계약 버전은 1이며 순서값과 발행시각으로 늦은 응답을 거절한다. 전송 실패 자료는 폰에 남겨 재연결/워치 요청 때 재전송한다. 같은 Data Layer 경로만 사용하며 워치에 공개된 디버그 자료 주입 API는 없다. 시험 자료는 androidTest에만 포함된다.

워치는 앱 진입/수동 요청, 30분 목표의 WorkManager, 브리핑 경계/만료 작업으로 갱신을 요청한다. 요청은 60초 간격으로 제한한다. OS·절전·연결 상태에 따라 실행이 지연될 수 있다. 3시간 이상 오래된 날씨 또는 유효 브리핑 구간 밖의 준비물은 현재 권고로 사용하지 않는다. 휴대전화 삭제/지역 해제도 빈 자료 계약으로 전달한다.

## 빌드

Android SDK API 37(`platforms;android-37.0`), JDK 17 이상과 프로젝트의 Gradle 9.3.1을 사용한다. 로컬 SDK 경로는 git에서 제외한 `local.properties`의 `sdk.dir`에 설정한다. 이 환경은 Android Studio의 JBR 25로 빌드했다. API 37의 새 위젯은 AndroidX alpha SDK를 사용하므로 출시 전 OEM/렌더러 조합 확인이 필요하다.

```powershell
./gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:assembleDebugAndroidTest
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -r -e class com.codesoha.weathercare.WatchDeviceTest com.codesoha.weathercare.test/androidx.test.runner.AndroidJUnitRunner
```

`WatchWidgetHostTest`는 이전 소형·대형 제공 방식의 검증 도구로 현재 비활성화된 서비스에는 적용하지 않는다. 폰 Debug APK도 새로 설치해야 실제 동기화가 가능하다. 출시 빌드는 폰/워치의 배포 서명을 일치시켜야 한다. 현재 Debug 두 APK의 인증서 SHA-256 일치를 확인했다.

선택기 PNG는 `tools/generate_previews.cjs`로 공식 Rectangular 프로필/320dpi의 합성 시안에서 생성한다. Native SDK 실행 화면과 구분한다. 실제 서비스는 Remote Compose로 렌더링한다.

## 실기기 검증과 남은 범위

2026-11-02, 연결된 Samsung SM-L340 / API37 / 438×438px / density340에서 앱 UI와 실제 삼성 위젯 호스트를 검사했다. 실제 소형 콘텐츠145.88235×56.470585dp, 대형149.64706×104.941185dp를 서비스 콜백으로 확인했다.

시험 자료로 체크·상세·화면 이동·연속3회 구역 변경/이전 응답 거절·만료 준비물 제거를 검사했고, 앱 Activity를 열지 않은 채 채택한 새 자료가 소형/대형에 반영되는 것과 카드 탭의 현재날씨 진입을 확인했다. `app/build/device-test/`의 로그·스크린샷은 합성 시험 자료다. 기상 관측을 실제로 이동해 받은 결과로 설명하면 안 된다.

실기기에서 자동 동기화를 시험할 때는 휴대전화와 워치를 페어링하고 양쪽에 동일한 패키지 이름과 서명으로 빌드한 앱을 설치한다.

공식 참고: [Wear Widgets 시작](https://developer.android.com/training/wearables/widgets/get_started), [타일 호환](https://developer.android.com/training/wearables/widgets/migration), [Data Layer 패키지·서명](https://developer.android.com/training/wearables/data/overview).

## 새 타일 묶음의 기본 이름 검증

앱·서비스·위젯 제공자 이름은 ‘날씨챙겨’다. SM-L340 재연결 후 소형·대형 컨테이너에도 같은 이름을 명시한 시험본을 설치하고 삼성의 일반 타일 추가 화면에서 새 소형 위젯을 추가했다. 선택 목록의 이름은 ‘날씨챙겨’였지만 새 묶음의 기본 제목은 영어 UI에서 ‘Tools’(한국어 ‘도구’)였다. 크기별 label로 묶음 제목을 바꿀 수 없음을 확인하고 시험 변경은 되돌렸다. 공개 메타데이터에서 삼성 묶음의 기본 제목을 직접 지정하는 항목은 확인하지 못했다. XML `group`은 기존 타일과 위젯 서비스의 논리적 연결 식별자이며 표시 제목으로 변경하지 않는다. 수동 제목 편집은 요청한 자동 기본값의 해결로 간주하지 않는다.

증거는 `output/watch-default-name-20261102/added-experimental.png`와 `.xml`이다. 이번에 추가한 시험 위젯/빈 묶음만 정리하고 기본 타일3개 상태와 복원 APK 설치를 확인했다. 현재 세션은 다시 예약된 기본 상태였고 이전 시험 날씨·워치페이스·두 위젯은 남아 있지 않았다. 이 결과를 앱에서 기본 제목 자동 지정에 성공한 것으로 설명하면 안 된다.

기존 전체 화면 `WeatherTileService`만 제공하는 시험본은 같은 SM-L340에서 ‘날씨챙겨’ 이름의 독립 타일로 추가됐다. `Tools` 묶음은 생기지 않았고 시스템 접근성 이름도 ‘날씨챙겨, Tile, 4 of 4’였다. 증거는 `output/watch-legacy-name-20261102/added.png`, `added.xml`, `edit.png`, `edit.xml`이다. 해당 비교 검사에서는 원래 구성으로 복원했으며, 이후 사용자가 정식 전환을 요청해 소형·대형 서비스를 비활성화하고 기존 전체 화면 타일을 기본 제공하도록 변경했다. 삼성 묶음 제목을 수동으로 수정하는 처리는 추가하지 않았다.

## 폰 없이 UI만 둘러보기

사용자가 리모트랩에서 UI만 보겠다고 요청한 후속 확인용으로 `WatchPreviewTest.prepareUiPreviewForUser`를 추가했다. androidTest APK에만 포함되며 일반 앱/출시 APK에는 시험 자료 생성 기능을 넣지 않았다.

시험 APK를 설치한 뒤 아래 명령을 실행하면 ‘UI 시험 자료’ 지역의 준비물3개·시간별3개·생활지표10개와 어제 비교 예시가 로컬 캐시 및 타일에 반영된다. 사용자가 직접 둘러보도록 이 도구는 시험 자료를 남긴다. 실제 서버 날씨/위치 이동의 검사가 아니다. 준비물은 약1시간 유효하며 필요하면 다시 실행한다.

```powershell
adb shell am instrument -w -r -e class com.codesoha.weathercare.WatchPreviewTest com.codesoha.weathercare.test/androidx.test.runner.AndroidJUnitRunner
adb shell am start -W -n com.codesoha.weathercare/.WatchActivity
```

좌우 스와이프로4화면을 이동하고 세로 스크롤·체크박스·항목 상세를 확인한다. 현재 날씨/위젯의 지역명과 지표 기준 설명은 시험 자료임을 표시한다. 실제 폰 자료를 수신하면 정상 동기화 자료로 교체된다.

2026-11-02 최종 타일 전환본을 SM-L340에 설치하고, 일반 추가 목록의 ‘날씨챙겨’1개 선택→독립 타일 추가→기본 이름/시험 자료 표시→탭의 현재날씨 진입을 검사했다. 최종 타일은 삭제하지 않고 열어 두었다. 화면은 `output/watch-legacy-applied-20261102/applied.png`이며 지역명은 ‘UI 시험 자료’다. 새 위젯 서비스 비활성화는 제품 구성에 유지한다.
