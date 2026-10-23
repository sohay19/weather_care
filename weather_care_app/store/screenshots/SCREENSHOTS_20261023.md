# Android 스토어 스크린샷 · 2026-10-23

Main·Week 수정 UI를 반영하고, 5번 알림 예시를 제외한 앱 화면과 위젯을 현재 켜져 있는 SM-S948U에서 실제 촬영한 이미지로 교체했다.

## 결과물

- `android/`: 1080×1920 RGB PNG 8장
- `android-tablet/`: 1440×2560 RGB PNG 8장
- `preview-android.png`, `preview-android-tablet.png`: 전체 미리보기
- `../weather-care-screenshots-20261023.zip`: 등록 이미지 16장·미리보기·안내·해시 명세
- 앱 원본: `source-android-20261023/`의 Android `screencap` PNG·UI XML·촬영 명세
- 위젯 원본: `native-android-20261023/`의 라이트·다크 소형·중형·대형 및 촬영 명세
- 최종 해시: `screenshots-20261023-manifest.json`

기존 이름 `weather-care-screenshots-20261022.zip`과 통합 ZIP의 Android 항목도 최신 결과로 맞췄다. iOS·iPad 이미지와 Google Play 그래픽은 유지했다. 2026-10-22 안내의 비표시 예시 렌더링 설명은 과거 제작 이력이다.

## 촬영 기준

- SM-S948U, Android 16/API 36, 1440×3120 원본이다. 기존 physical density 600/override 560과 시스템 글자 배율 1.0을 유지했다. 앱은 기존 제한에 따라 1.1배다.
- Main·Week·타임라인·위젯은 부산광역시 남구 감만1동의 운영 서버 실자료다. 촬영 시각 차이로 수치와 기준시간이 일부 다를 수 있다.
- 심화탭은 사용자 지시에 따라 테스트 DB에 10월 23일 바다·하천 제공처 실자료를 단발 수집한 뒤 테스트 서버 연결 APK로 다시 촬영했다. 부산 조위는 13:00 관측 45cm, 만조 18:38·간조 12:09, 예측 최저 32.9cm·최고 113.7cm 및 실제 시간별 관측·예측 그래프를 표시한다. 운영 서버에는 해당 심화 API가 없어 촬영용으로만 연결을 바꿨다. 날짜·수치를 합성하거나 결측을 임의로 채우지 않았다. 테스트 접근 키는 이미지·명세·문서에 포함하지 않았다.
- 앱은 실제 실행 중인 화면을 ADB `exec-out screencap -p`로 저장했다. 화면을 Python이나 Flutter 테스트로 재현하지 않았다. 위젯은 현재 앱에 저장된 실자료를 그대로 사용해 실제 Provider를 AppWidgetHost에 바인딩하고 실제 View를 촬영했다. 홈 런처 전체 캡처는 아니다.
- 앱 화면 1·2·4·6·7·8번은 상단 시스템 상태바140px와 하단 Android 시스템 내비게이션바168px를 제외하고 앱 탭 메뉴를 포함한 앱 전체 캡처를 사용한다. WindowManager Insets의 `statusBars`는 [0,0][1440,140]이며, 보존한 UI XML과 Insets의 하단 경계는 [0,2952][1440,3120]이다. 나머지 앱 화면을 자르거나 다시 그리지 않고 비율 유지 축소했다. 전체 PNG 원본은 변경하지 않았다.
- 1·2·4·7번은 SM-S948U에서 각각 Main 날씨·타임라인·다크 Main·Week 날짜별 카드가 잘 보이도록 스크롤한 뒤 촬영했다. 6번은 오늘 조위 수치가 보이는 전체 원본, 8번은 기존 알림 설정 전체 원본을 사용한다. 후속 요청으로 4번에는 실제 AppWidgetHost의 다크 대형 위젯을 다시 함께 배치했다. 앱은 시스템바를 제외한 전체 화면을 유지하고 위젯을 하단 우측에 겹친다. Week 카드를 따로 잘라 붙이지 않으며 3번 위젯·5번 알림 구성은 유지한다.
- 태블릿 파일은 같은 휴대전화 촬영본을 태블릿 등록 규격에 비율 유지해 배치한 소개 이미지다. 실제 태블릿에서 촬영한 것으로 설명하지 않는다.
- 5번은 알림 예시 5개로 구성한다. 후속 요청으로 하단 예시 안내 문구를 삭제하고 자외선 알림을 하나 추가했다. 8번 알림 설정은 실제 앱 설정 화면으로 교체했으며 스위치를 임의로 켜지 않았다.
- 촬영 후 운영 서버용 APK·기존 다크 테마로 복원했다. 서버 배포·실제 푸시 발송·스토어 업로드는 수행하지 않았다.

## 등록 순서

1. Main 지금 날씨·오늘 최저/최고·어제 비교
2. 시간별 타임라인
3. 실제 홈 화면 위젯 3종
4. 실제 앱 다크모드 전체 화면·다크 대형 위젯
5. 날씨 알림 예시 5개(자외선 추가·하단 안내 삭제)
6. 심화 날씨 정보(테스트 서버 실제 표시 상태)
7. Week 날짜별 기온·생활 날씨 전체 화면
8. 실제 알림 설정

## 다시 만들기

보존한 실제 촬영 원본으로 최종 등록 이미지만 재생성하려면 앱 루트에서 실행한다.

```powershell
python store/generate_android_store.py --screenshots-only
```

앱 화면을 갱신하려면 `adb devices -l`로 현재 대상 연결을 확인하고, 실제 앱에서 해당 부분이 잘 보이도록 스크롤한 뒤 `adb -s <연결ID> exec-out screencap -p`의 바이너리 출력을 파일로 저장한다. PowerShell의 텍스트 리다이렉션으로 PNG를 저장하지 않는다. 원본·UI XML과 촬영 명세의 SHA256을 함께 갱신한다. 최종 이미지에서는 실제 시스템 경계로 확인한 `system_status_bar`와 `system_navigation_bar`만 제외한다. 예시 데이터를 주입하는 `capture_android_test.dart`는 이번 실제 촬영 원본 생성에 사용하지 않는다.

심화탭용 APK는 다음 명령으로 빌드하며 Debug 설정의 시험 서버와 인증 정보를 사용한다. 촬영 후 운영 서버용 Release APK를 업데이트 설치해 복원한다.

```powershell
& D:\flutter_3.47.4\bin\flutter.bat build apk --debug
```

실자료 위젯을 다시 촬영하려면 최신 APK가 설치된 대상과 그 APK 경로를 지정한다. 앱에서 날씨 조회를 완료한 뒤 실행해야 한다. 촬영 도구는 별도 화면 창 없이 실행되며 시스템 테마와 위젯 저장값은 종료 시 복원한다.

```powershell
python store/capture_native_widgets.py --real-weather --skip-app-install --serial <연결ID> --apk <설치된APK> --output store/screenshots/native-android-20261023
```

`--real-weather`를 생략하면 과거 정렬 검증용 예시 날씨 모드가 실행되므로 최신 원본을 갱신할 때 반드시 지정한다.
