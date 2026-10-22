# Android 스토어 스크린샷 · 2026-10-22

현재 작업 디렉터리의 Flutter UI를 다시 렌더링해 안드로이드 휴대전화·태블릿 스크린샷만 갱신했다. 그래픽 이미지, iOS 헤더·검색결과 이미지, iOS·iPad 스크린샷은 변경하지 않았다.

## 등록 파일

- `android/`: 1080×1920, RGB PNG 8장
- `android-tablet/`: 1440×2560, RGB PNG 8장
- 전체 미리보기: `preview-android.png`, `preview-android-tablet.png`
- 스크린샷 전용 ZIP: `../weather-care-screenshots-20261022.zip` — 최종16장·미리보기2장·안내·해시 명세만 포함
- 원본: `source-20261022/phone`, `source-20261022/tablet` 각9개

## 소개 순서

1. 메인: 준비물 체크리스트·지금 날씨·어제 비교
2. 시간별 타임라인
3. 홈 화면 위젯
4. 앱·위젯 다크모드
5. 다양한 알림
6. 심화 날씨 정보
7. 한주 날씨
8. 항목별 알림 켜기·끄기

현재 준비물 카드의 중앙 정보 버튼·내용에 따른 높이·하단 버튼 정렬, 메인 상단 여백, 시간축 글자와 그래프 높이, 만조·간조/범위 박스의 테마 배경과 현재 시간 강조를 반영했다. 원본의 설정 목록·알림 화면도 최신 코드로 렌더링했다. 기존 홍보 문구·8장 소개 순서는 유지한다.

추가 수정으로 큰 위젯의 준비물 아이콘을 왼쪽에 두고 준비물명을 남은 영역에서 중앙 정렬했으며, 큰 위젯의 두 줄 브리핑만 중앙 정렬했다. 나머지 브리핑은 기존 왼쪽 정렬을 유지한다. Android 휴대전화·태블릿의 3번 위젯과 4번 다크모드 이미지를 다시 만들고 전체 미리보기·해시·ZIP을 갱신했다. 나머지 번호와 iOS·iPad 이미지는 유지했다.

타임라인 기온 수치가 체감온도 선·수치와 겹치는 경우 기온은 두 선 위로, 체감온도는 두 선 아래로 배치하도록 수정했다. 수치 폭에 들어오는 인접 선분도 검사하며 날씨 아이콘은 기온 수치 위에 간격을 둔다. 이 변경을 반영해 Android 휴대전화·태블릿의 2번 타임라인만 다시 렌더링하고 미리보기·해시·ZIP을 갱신했다.

새로고침 버튼은 Android의 보이는 원을 24→20dp, 아이콘을 약 13→11dp로 줄였으며 클릭 가능한 24×24dp 영역과 위치는 유지했다. 일반·로딩·라이트·다크 상태에 같은 크기를 적용했다. iOS도 보이는 원 22→18pt·아이콘 8.8→7.2pt로 줄이고 기존 44×44pt 터치 영역을 유지했다. Android 3·4번을 SM S948U의 실제 위젯으로 다시 촬영했으며, 원본 촬영 명세에 터치 영역 좌표도 기록한다. iOS 스크린샷은 변경하지 않았다.

앱 화면은 현재 실제 Flutter 위젯의 비표시 렌더링이며 실기기·에뮬레이터 촬영이 아니다. 휴대전화412×1000dp를3배, 태블릿800×1280dp를2배로 렌더링했다. 날씨·관측소·알림 스위치는 재현 가능한 촬영용 예시다. 사용자 설정·서버·권한·위치를 변경하지 않았다. 준비물 PNG를 사전 디코딩하고 한글 대체 글꼴이 없는 테스트 엔진에서 미지정 글꼴에 SUITE를 적용했다.

3·4번의 위젯은 사용자가 지정한 SM S948U(Android 16/API 36)에서 실제 앱의 `WeatherCareWidgetProvider`를 `AppWidgetHost`에 바인딩해 촬영한 네이티브 화면이다. 별도 화면 창 없이 호스트의 실제 View를 렌더링했다. XML·실제 텍스트/아이콘 렌더러·주야간 색상을 그대로 사용했으며, 최저/최고의 일반 제목·굵은 온도와 공백도 실제 구현 그대로다. 위젯을 Python으로 다시 그리던 이전 재현 코드는 제거했다. 원본은 `native-20261022/`의 라이트·다크 3종 각 1개와 촬영 명세에 보관한다. 준비물 1·2·3개 및 긴 이름의 배치도 실제 호스트에서 검증한다. 촬영용 예시 날씨를 사용하며, 홈 런처 전체나 현재 실측 자료를 촬영했다고 주장하지 않는다. 휴대전화·태블릿 홍보 이미지에는 같은 네이티브 위젯 촬영본을 비율 유지해 배치했다. 4번 앱 본문은 앞서 만든 Flutter 다크모드 렌더링 원본을 사용한다.

알림 카드는 현재 지원 종류를 소개하는 예시이며 실제 푸시 발송·알림 패널 촬영이 아니다.

기존 최종 이미지·작업 범위 확인용 해시는 ignored `build/screenshots-backup-20261022/`에 보관했다. 모든 PNG의 크기·RGB·디코딩·SHA256과 ZIP 무결성을 확인한다. 기존 통합 묶음과 Android 묶음의 스크린샷 항목도 최신 파일로 맞추며 그래픽 원본 바이트는 유지한다. 최신 파일 해시는 `screenshots-20261022-manifest.json`을 따른다.

## 다시 만들기

앱 루트에서 실행한다.

```powershell
& D:\flutter_3.47.4\bin\flutter.bat test --no-pub store/capture_android_test.dart
python store/generate_android_store.py --screenshots-only
```

네이티브 원본을 갱신하려면 대상 CPU에 맞춰 최신 APK를 디버그 키로 서명한 뒤 사용자가 지정한 촬영 대상에서 실행한다. 이 명령은 지정한 대상에 앱/촬영 도구를 설치하고 예시 날씨를 표시한다. 기존 위젯 설정과 시스템 테마는 종료 시 복원한다. 연결 ID는 `adb devices`에서 확인한다.

```powershell
python store/capture_native_widgets.py --serial localhost:59976 --apk build/app/outputs/apk/profile/app-arm64-v8a-profile.apk
python store/generate_android_store.py --screenshots-only --topics 03-widget,04-dark-mode
```

`--topics`를 지정하면 해당 번호만 다시 만들며, 미리보기·해시·ZIP에도 변경된 화면이 반영된다.

Android 2번 원본과 최종본만 다시 만들려면 다음 명령을 실행한다.

```powershell
& D:\flutter_3.47.4\bin\flutter.bat test --no-pub --dart-define=STORE_CAPTURE_SCREEN=timeline store/capture_android_test.dart
python store/generate_android_store.py --screenshots-only --topics 02-timeline
```

사용자가 지정한 SM S948U에 촬영용 앱과 위젯 호스트를 설치·실행했다. 서버 배포·스토어 업로드는 수행하지 않았다.
