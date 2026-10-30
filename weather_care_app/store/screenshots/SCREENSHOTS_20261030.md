# Android 마지막 스크린샷 최신 알림 설정 UI 교체 · 2026-10-30

Android 등록 이미지의 마지막 **8번 알림 설정**만 최신 제품 화면으로 교체했다. 1~7번은 10월 29일 등록 이미지와 파일 해시가 같다.

- 휴대전화: `android/08-notification-settings.png` · 1080×2160 RGB PNG
- 태블릿: `android-tablet/08-notification-settings.png` · 1440×2880 RGB PNG
- 등록용 묶음: `../weather-care-android-screenshots-20261030.zip` · 규격별 8장
- 전체 미리보기: `preview-android.png`, `preview-android-tablet.png`
- 파일 규격·해시: `screenshots-20261030-manifest.json`

## 촬영·편집 기준

연결된 SM-S948U에서 현재 로컬 제품 소스를 별도 Debug 촬영 패키지 `com.codesoha.weathercare.storecapture`로 실행했다. 최신 Setting → 알림의 챙겨요 전체 알림과 원인별 8항목이 모두 보이는 위치를 실제 ADB 스크린샷으로 촬영했다. 운영 서버 재시도 팝업이 없는 상태에서 촬영했으며, 촬영용 초기 설정을 사용한다. 실제 알림 수신 검증은 아니다.

원본 PNG와 시스템 바 영역 및 APK 해시는 `source-android-20261030/capture-manifest.json`에 기록했다. 원본에서 시스템 상태바·내비게이션바만 제외하고 비율을 유지했다. 제목·색상·72px 여백 및 태블릿의 96px 여백은 기존 배치를 따른다. 태블릿 등록 이미지도 같은 휴대전화 촬영본으로 구성하며 실제 태블릿 촬영본은 아니다.

기존 Android 1~7번, iOS·iPad 이미지, Google Play 그래픽, 이전 날짜 ZIP은 유지했다. 앱 제품 코드와 실제 사용 앱의 설정은 이번 촬영 작업에서 변경하지 않았다.

## 재생성

앱 폴더에서 다음 명령으로 마지막 장과 미리보기·최신 ZIP을 갱신한다.

```powershell
python store/generate_android_store.py --screenshots-only --topics 08-notification-settings
```
