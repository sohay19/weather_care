# Android 스토어 스크린샷 · 2026-11-03

- 2번은 리모트랩 Galaxy S26 Ultra(SM-S948U_KR2)의 촬영용 앱에서 촬영한 지역별 알림 ON/OFF 화면이다. 기본 상태에서 편집 버튼과 각 구역의 알림 스위치가 보인다.
- 5번은 리모트랩 Galaxy Watch9(SM-L340)의 앱 네 탭 촬영본을 현재 날씨, 오늘의 준비물, 타임라인, 기상·생활 순서로 원형 배치했다.
- 휴대전화용은 1080×2160, 태블릿용은 1440×2880 RGB PNG다. 양쪽 규격에 같은 기기 원본을 사용했다.
- 등록용 묶음은 [Android ZIP](../weather-care-android-screenshots-20261103.zip)이다.

## iOS 워치 UI 참고

네 탭 원본은 리모트랩 Galaxy Watch9에서 상단 시계를 숨긴 촬영용 빌드로 캡처한 438×438 PNG다. 준비물은 스크롤하기 전 첫 화면이고, 현재 날씨는 하단의 날씨 기준 시각이 잘 보이도록 살짝 스크롤했다. 탭 순서 변경은 아래 순서와 5번 소개 이미지에 반영했다.

| 탭 | 캡처 | UI |
| --- | --- | --- |
| 현재 날씨 | [current.png](source-wear-20261103/current.png) | 지역명, 기온, 체감온도, 최저·최고, 어제 비교, 기준 시각을 표시한다. |
| 오늘의 준비물 | [prep.png](source-wear-20261103/prep.png) | 목록 위에 ‘오늘의 준비물’을 현재 날씨 지역명과 같은 13sp, 보통 굵기, 강조색으로 표시한다. |
| 타임라인 | [timeline.png](source-wear-20261103/timeline.png) | 목록 위에 ‘시간별 예보 · 강수확률’을 10sp, 보통 굵기, 보조색으로 표시한다. |
| 기상·생활 | [life.png](source-wear-20261103/life.png) | 목록 위에 ‘항목을 눌러 자세한 내용을 확인’을 타임라인 안내와 같은 스타일로 표시한다. |

상세 참고 화면은 수정한 앱을 438×438 로컬 Android 에뮬레이터에서 실행해 촬영했다. 준비물과 기상·생활 항목 모두 설명 아래에 지역명과 기준시간을 별도 줄로 표시한다. 에뮬레이터의 상태 표시줄과 탐색 막대가 포함되어 있다.

| 상세 화면 | 캡처 |
| --- | --- |
| 준비물 | [prep-detail.png](source-wear-20261103/prep-detail.png) |
| 기상·생활 | [life-detail.png](source-wear-20261103/life-detail.png) |

## 재생성

앱 폴더에서 실행한다.

```powershell
python store/generate_android_store.py --screenshots-only --topics 02-region-notifications,05-watch
```
