# Android 스토어 스크린샷 · 2026-10-28

최신 작업 트리의 제품 화면을 연결된 SM-S948U에서 다시 촬영했다. 2번은 시간별 타임라인 대신 **지역별 알림**을 소개한다. iOS·iPad와 과거 ZIP, Google Play 그래픽은 변경하지 않는다.

## 결과물

- `android/`: 1080×1920 RGB PNG 8장
- `android-tablet/`: 1440×2560 RGB PNG 8장
- `preview-android.png`, `preview-android-tablet.png`: 전체 미리보기
- `../weather-care-android-screenshots-20261028.zip`: Android 등록 이미지 16장, 미리보기, 안내, 해시 명세
- `source-android-20261028/`: 실제 앱 원본 PNG, UI XML, 촬영 명세
- `native-android-20261028/`: 실제 Android 위젯 라이트·다크 3종 및 촬영 명세
- `screenshots-20261028-manifest.json`: 최종 이미지 크기·SHA256

## 등록 순서

1. 오늘의 날씨 요약
2. 지역별 알림 — 저장 지역과 각 지역의 알림 ON/OFF
3. 홈 화면 위젯 — 소형·중형·대형
4. 다크모드 — 실제 앱과 대형 위젯
5. 날씨 알림 — 지원 기능을 소개하는 예시 5개
6. 심화 날씨 정보 — 부산 조위의 실제 관측·예측
7. 일주일 예보 — 날짜 양옆 이동 버튼을 포함한 최신 화면
8. 알림 설정 — 출퇴근 알림 시간 설정을 포함한 최신 화면

## 촬영 기준

- SM-S948U, Android API 36, 1080×2340. 기존 화면 크기·밀도·글자 배율을 사용했다.
- 사용자 제품 앱과 분리된 `com.codesoha.weathercare.storecapture` Debug 패키지에서 실제 `WeatherCareApp`·`HomeScreen`을 실행했다. `store/capture_device.dart`는 촬영용 초기 설정만 준비하며 제품 화면·날씨 모델·서버 응답을 대체하지 않는다. 스토어 확인과 제품 시작 권한 요청을 거치지 않는 전용 진입점이다.
- 촬영용 설정은 부산 남구 감만1동·서울 종로구·경기 시흥 정왕1동이며 앞의 두 지역 알림을 선택했다. 현재 위치 알림은 끔, 백그라운드 위치는 끔이다. Firebase Messaging 자동 초기화를 끄고 제품 시작 등록 흐름을 실행하지 않았다. 실제 푸시 수신 검증이 아니다.
- 모든 날씨·위젯 수치는 `https://weather-api.codesoha.com`의 실제 자료다. 촬영 시각·제공처 갱신 시각 차이를 그대로 보존했다. 날짜·수치를 합성하거나 결측을 채우지 않았다.
- 앱 PNG는 ADB `exec-out screencap -p`의 바이너리 원본이다. 최종 이미지에서는 WindowManager Insets로 확인한 상태바 `[0,0,1080,105]`, 시스템 내비게이션바 `[0,2295,1080,2340]`만 제외하고 나머지는 비율을 유지했다. 앱의 탭 메뉴·뒤로가기·메뉴 배경을 보존했다.
- 위젯은 최신 APK의 실제 Provider를 AppWidgetHost에 연결해 실제 View를 촬영했다. 런처 전체 화면은 아니다. 촬영 도구는 위젯 저장값·시스템 테마를 복원한다.
- 5번은 기존 구성과 같은 홍보용 알림 예시다. 운영 서버 발송 또는 OS 알림 수신 캡처로 설명하지 않는다.
- 태블릿 규격은 같은 휴대전화 촬영본을 비율 유지 배치한 소개 이미지다. 실제 Android 태블릿 촬영본은 아니다.
- 사용자의 제품 앱 데이터·권한을 수정하거나 실제 푸시를 발송하지 않았다. 서버·스토어 배포는 수행하지 않았다.

## 등록 이미지 재생성

앱 루트에서 보존한 최신 촬영 원본으로 생성한다.

```powershell
python -X utf8 store/generate_android_store.py --screenshots-only
```

새 묶음은 Android 전용이며 과거 통합 묶음을 덮어쓰지 않는다. 2번의 과거 `02-timeline.png`는 앱의 ignored `build/screenshots-backup-20261028/`에 보관하고 등록 폴더에서 제외했다.

실자료 위젯 재촬영은 최신 APK에 날씨가 저장된 뒤 실행한다.

```powershell
python -X utf8 store/capture_native_widgets.py --real-weather --skip-app-install --serial <연결ID> --package com.codesoha.weathercare.storecapture --apk <최신촬영APK> --capture-date 2026-10-28 --output store/screenshots/native-android-20261028
```

촬영용 앱은 Gradle 초기화 스크립트로 `applicationId`를 분리하고 Google Services 재처리만 생략했다. 제품 네이티브 구현과 Flutter 코드는 그대로 사용한다. 빌드 명령·로그·APK는 `build/store-device-20261028/`에 보존한다.
