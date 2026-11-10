# 스토어 스크린샷

2026년 11월 4일 **나눔스퀘어 네오**를 반영해 iPhone·Android 앱과 홈 위젯, Apple Watch·Galaxy Watch 앱 및 워치 위젯·타일을 모두 갱신했다. 실제 앱·시스템 위젯 호스트의 화면을 사용한다.

2026년 11월 10일 Android 휴대전화·태블릿의 8번 알림 설정에 새 속보·특보 메뉴를 반영했다. 두 규격에 같은 Android 촬영 원본을 사용한다.

같은 날 iOS 1.2.2(26111000)의 알림 설정도 전용 iPhone 시뮬레이터에서 다시 촬영해 iPhone·iPad 8번에 반영했다. 이번 iOS 갱신에서 Android 등록본은 변경하지 않았다.

- [전체 스크린샷 ZIP](../weather-care-store-screenshots.zip)
- [촬영·제작·검증 안내](SCREENSHOTS_20261104.md) · [전체 파일 명세](screenshots-all-20261110-manifest.json) · [Android 8번 촬영 기록](source-android-20261110/capture-manifest.json) · [iOS 8번 촬영 기록](source-ios-20261110/phone/capture-manifest.json)

| 대상 | 개별 PNG | 최신 ZIP | 미리보기 |
|---|---|---|---|
| iPhone·iPad 등록용 각 8장 | `ios/`, `ipad/` | [iOS ZIP](../app-store/weather-care-ios-screenshots-20261110.zip) | [iPhone](preview-ios.png) · [iPad](preview-ipad.png) |
| Android 휴대전화·태블릿 등록용 각 8장 | `android/`, `android-tablet/` | [Android ZIP](../weather-care-android-screenshots-20261110.zip) | [휴대전화](preview-android.png) · [태블릿](preview-android-tablet.png) |
| Apple Watch 앱·스마트 스택 5장 | `watchos/` | [Apple Watch ZIP](watchos-screenshots-20261104.zip) | [미리보기](preview-watchos-20261104.png) |
| Wear OS 앱·전체 화면 타일 5장 | `wear-os/` | [Wear OS ZIP](wear-os-screenshots-20261104.zip) | [미리보기](preview-wear-20261104.png) |
| Apple Watch 홍보 카드 5장 | `watchos-promo/` | [홍보 ZIP](watchos-promo-20261104.zip) | [미리보기](preview-watchos-promo-20261104.png) |
| Galaxy Watch 홍보 카드 5장 | `wear-os-promo/` | [홍보 ZIP](wear-os-promo-20261104.zip) | [미리보기](preview-wear-os-promo-20261104.png) |

[홈 위젯 12종 미리보기](preview-widgets-20261104.png): iPhone·Android 각각 소형·중형·대형 × 라이트·다크다. 원본은 `../screenshot-inputs/native-ios-20261104/phone/`과 `../screenshot-inputs/native-android-20261104/`에 있다.

Apple Watch는 416×496, Wear OS는 438×438 RGB PNG다. 워치 등록용·홍보용의 5번은 각각 실제 스마트 스택과 현재 공개된 전체 화면 타일이다. Wear OS 소형·대형 서비스는 제품에서 비활성화되어 있다. 태블릿 등록 규격에는 기존 제작 방식대로 휴대전화 원본을 비율 유지해 배치했다.

앱·워치 원본과 촬영 환경·SHA-256은 `source-ios-20261104/`, `source-android-20261104/`, `source-watchos-20261104/`, `source-wear-20261104/`의 매니페스트에 기록한다. Galaxy Watch 앱 네 화면은 11월 4일 실기기 촬영본이며, 새 전체 화면 타일은 Wear OS 7 전용 에뮬레이터의 실제 시스템 호스트에서 촬영했다.

Android 8번과 관련 미리보기·ZIP을 다시 만들려면 앱 루트에서 실행한다.

```sh
python3 store/generate_android_store.py --screenshots-only --topics 08-notification-settings
python3 store/package_screenshots.py --android-refresh
```

iOS 8번과 관련 미리보기·ZIP만 다시 만들려면 다음을 실행한다. 이전 날짜의 iOS ZIP과 Android·워치 이미지는 보존한다.

```sh
python3 store/generate_ios_store.py --topics 08-notification-settings
```

## 2026년 11월 3일 등록본

이전 폰트의 제작 이력이다. 새 등록에는 위의 최신 묶음을 사용한다.

| 등록 대상 | 개별 PNG | 다운로드 |
|---|---|---|
| iPhone·iPad | `ios/`, `ipad/` | [ZIP](../app-store/weather-care-ios-screenshots-20261103.zip) |
| Android 휴대전화·태블릿 | `android/`, `android-tablet/` | [ZIP](../weather-care-android-screenshots-20261103.zip) |
| Apple Watch | `watchos/` | [ZIP](watchos-screenshots-20261103.zip) |
| Wear OS | `wear-os/` | [ZIP](wear-os-screenshots-20261103.zip) |

- [iOS 촬영 및 제작 안내](IOS_20261103.md)
- [Android 및 Wear OS 촬영 안내](SCREENSHOTS_20261103.md)
- 이전 촬영분 중 생성 스크립트에 필요한 입력은 `../screenshot-inputs/`에 있다. 이전 제작 기록은 Git 이력에서 확인할 수 있다.


## 이전 워치 홍보 카드

- [Apple Watch 홍보 카드 ZIP](watchos-promo-20261103.zip)
- [Galaxy Watch 홍보 카드 ZIP](wear-os-promo-20261103.zip)

앱 등록 이미지와 같은 파란 배경과 SUITE 글꼴을 사용했다. 실제 캡처를 워치 프레임 안에 배치하고 화면별 소개 문구를 더했다. Apple Watch는 App Store Connect가 지원하는 416×496 RGB PNG 4장이다. Galaxy Watch 홍보 카드는 438×438 RGB PNG 4장이며, Google Play의 Wear OS 등록 슬롯에는 위 표의 전용 ZIP을 사용한다.
