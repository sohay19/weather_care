# Android 스토어 스크린샷 · 2026-11-03

- 2번은 리모트랩 Galaxy S26 Ultra(SM-S948U_KR2)의 촬영용 앱에서 예시 저장 구역을 열어 촬영한 편집 화면이다.
- 5번은 Fold8과 서버로 연결된 리모트랩 Galaxy Watch9(SM-L340)의 앱 네 탭을 촬영해 원형으로 배치했다.
- 휴대전화용은 1080×2160, 태블릿용은 1440×2880 RGB PNG다. 양쪽 규격에 같은 기기 원본을 사용했다.
- 등록용 묶음은 [Android ZIP](../weather-care-android-screenshots-20261103.zip)이다.

## iOS 워치 UI 참고

원본은 리모트랩 Galaxy Watch9에서 상단 시계를 숨긴 촬영용 빌드로 캡처한 438×438 PNG다. 챙겨요는 스크롤하기 전 첫 화면이고, 현재 날씨는 하단의 날씨 기준 시각이 잘 보이도록 살짝 스크롤했다.

| 탭 | 캡처 | UI |
| --- | --- | --- |
| 챙겨요 | [prep.png](source-wear-20261103/prep.png) | 목록 위에 ‘오늘의 준비물’을 현재 날씨 지역명과 같은 13sp, 보통 굵기, 강조색으로 표시한다. |
| 현재 날씨 | [current.png](source-wear-20261103/current.png) | 지역명, 기온, 체감온도, 최저·최고, 어제 비교, 기준 시각을 표시한다. |
| 타임라인 | [timeline.png](source-wear-20261103/timeline.png) | 목록 위에 ‘시간별 예보 · 강수확률’을 10sp, 보통 굵기, 보조색으로 표시한다. |
| 기상·생활 | [life.png](source-wear-20261103/life.png) | 목록 위에 ‘항목을 눌러 자세한 내용을 확인’을 타임라인 안내와 같은 스타일로 표시한다. |

## 재생성

앱 폴더에서 실행한다.

```powershell
python store/generate_android_store.py --screenshots-only --topics 02-region-notifications,05-watch
```
