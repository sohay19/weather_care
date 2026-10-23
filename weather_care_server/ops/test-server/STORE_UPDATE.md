# 스토어 업데이트 푸시 — 시험 서버

한국시간 매일 오전 9시에 iOS App Store 한국 공개 버전과 Android Google Play
production 트랙의 전체 공개 버전을 확인한다. 운영 서버의 사용자 DB에는 접근하지 않는다.

- 제목: `날씨챙겨 새 버전이 나왔어요`
- 내용: `최신버전 업데이트가 준비됐어요. 새로운 버전을 다운받아보세요.`
- iOS만 갱신되면 iOS 설치본에, Android만 갱신되면 Android 설치본에 발송한다.
- FCM 토큰이 있고 전체 알림이 켜진 시험 설치본만 대상이다. 버전을 보고한 설치본은
  공개 버전보다 낮을 때만 대상이다. Android는 `버전명+빌드번호`의 빌드 번호를 우선한다.
- 1.0.0·1.0.1 등 버전을 보고하지 않는 기존 설치본은 버전 미상으로 포함한다.
  그 기기가 실제로 업데이트했더라도 새 앱에서 버전을 보고하기 전에는 알 수 없다.
- OS별 최초 성공 조회는 기준만 저장하고 발송하지 않는다. 이후 더 높은 공개 버전부터
  기기별 한 번 발송한다. 놓친 대상과 확실한 실패 응답은 다음 점검에 다시 확인한다.
  이전 버전으로 롤백된 경우 기준을 낮추거나 이전 알림을 재발송하지 않는다.
- 설치 ID와 토큰 해시로 중복을 막고 발송 직전 버전·전체 알림·토큰을 재확인한다.
  전송 전 접수중 기록을 남기므로 응답 유실·프로세스 중단의 접수 불명 상태는
  자동 재전송하지 않는다. 이 경우 중복은 막지만 알림을 놓칠 수 있어 이력 확인이 필요하다.
- FCM 접수 성공은 기기 알림 표시·사용자 수신 확인과 다르다. 알림 만료는 24시간이다.
  서버가 중지됐다면 systemd의 Persistent 설정으로 재가동 뒤 지난 점검을 보충한다.

## 앱 동작과 구버전 한계

새 앱은 등록/동기화할 때 설치 버전명과 빌드 번호를 기존 `appVersion` 필드로 보낸다.
기존 홈 화면의 앱 실행·복귀·토큰 갱신 등록 흐름을 사용한다. 버전 조회 실패는
위치·FCM 등록을 막지 않는다. 갱신 후 실행하지 않은 기기는 마지막 보고 기준이다.

푸시 데이터의 `notificationTarget=STORE_UPDATE`, `notificationTopic=APP_UPDATE`,
`storeUrl`을 처리한다. Android 전경 알림·백그라운드 클릭·종료 상태 진입에서
자기 OS의 HTTPS 스토어 상세 페이지를 외부로 연다. 실패하면 재시도/앱 복귀를 제공한다.
기존 날씨 알림의 이동은 유지한다.

스토어 이동 처리가 없는 기존 1.0.0·1.0.1 설치본은 푸시를 받아도 앱 메인 화면을 연다.
시험 서버 배포만으로 이미 설치된 앱의 클릭 처리를 바꿀 수 없다. 자동 스토어 이동과
버전 보고는 이번 앱 소스를 포함한 버전을 배포·설치한 뒤에 동작한다.

## 배치와 확인

- 번들: `/opt/weather-care/store-update-test/notifier.cjs`
- 의존성: 기존 시험 릴리스의 `node_modules`를 링크한다.
- 설치 DB: `/var/lib/weather-care/weather-care-test.sqlite` (읽기 전용)
- 상태 DB: `/var/lib/weather-care/store-update-test.sqlite` (운영/시험 날씨 DB와 별개)
- 서비스: `weather-care-test-store-update.service`
- 타이머: `weather-care-test-store-update.timer`
- 환경: 기존 `/etc/weather-care/weather-care.env` 다음 `weather-care-test.env`를 읽는다.
  필요하면 `/etc/weather-care/store-update-test.env`에서 `PLAY_CLIENT_EMAIL`,
  `PLAY_PRIVATE_KEY`를 지정한다. 미지정 시 기존 FCM 서비스 계정을 사용한다.
- `TEST_ACCESS_KEY`와 고정 시험 DB 실제 경로가 일치하지 않으면 실행을 거부한다.
- 서비스는 flock으로 동시 실행을 막는다. 운영 API·시험 API의 교체/재시작과
  날씨 수집기 재실행은 필요 없다.

```bash
systemctl status weather-care-test-store-update.timer
journalctl -u weather-care-test-store-update.service -n 30 --no-pager
```

`npm run build:store-update`로 번들을 만든다. 실행기의 `--initialize`는 최초 기준만
등록하고 푸시를 보내지 않으며, `--preview`는 조회 결과와 대상 수만 출력한다.
모든 실행은 환경 파일을 읽는 서비스 계정으로 수행한다. 비밀 값을 명령행에 넣지 않는다.

## Android 연결에 필요한 설정

2026-10-23 최초 응답은 HTTP 403 / `SERVICE_DISABLED`였다. 사용자가 Google Cloud
API 사용 설정을 완료한 뒤 재조회해 `SERVICE_DISABLED`가 사라진 것을 확인했다.
이후 사용자가 Play Console 앱 정보 보기(읽기 전용)를 부여해 정상 조회와
Android 최초 기준 등록까지 완료했다. 아래는 최초 연결 또는 재설정 절차다.

1. [Google Cloud API 설정](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=753467123768)에서
   프로젝트 `753467123768`의 Google Play Android Developer API를 사용 설정한다.
2. [Google Play Console 사용자 및 권한](https://play.google.com/console/)에서 조회에 사용하는
   서비스 계정 `firebase-adminsdk-fbsvc@weather-care-2aaa8.iam.gserviceaccount.com`에
   날씨챙겨 앱 정보 조회에 필요한 접근을 부여한다. 별도 계정을 사용하면
   위 전용 환경 파일에 설정한다. 결제·주문·출시 변경 권한은 이 기능에 필요하지 않다.
3. `--initialize`를 다시 실행해 실제 production 조회와 기준 등록을 확인한다.
   API 사용 설정 뒤에도 HTTP 403이 이어지면 Play Console 접근을 추가 확인한다.

Android 조회는 공식 API로 조회용 임시 edit를 생성해 production 트랙을 읽고 바로
폐기한다. 트랙 수정·commit·출시 변경은 호출하지 않는다. 단계적 배포/초안/중지된
릴리스는 발송 기준에 넣지 않는다. iOS는 한국 스토어 기준이며 기기별 스토어 국가·OS
호환성까지 서버가 확인하는 것은 아니다.

## 2026-10-23 시험 배치 상태

실제 미니 PC에 번들·서비스·타이머를 배치했다. 타이머는 enabled/active이며 다음
점검은 **2026-10-24 오전 9시 한국시간**이다. iOS 최초 기준은 실제 한국 스토어의
`1.0.1`로 등록했다. 수동 서비스 실행에서 iOS 점검 정상·발송 0을 확인했다.
최초 Android 조회는 권한 설정 전 `PLAY_EDIT_HTTP_403`이었으나, 사용자 설정 뒤
10:06 한국시간에 Android 조회·기준 등록·서비스 재실행이 모두 성공했다.
Android 공개 버전은 `1.0.1`, 빌드 번호는 `26101200`이다. Play 릴리스 이름은
`26101200 (1.0.1)`로 반환됐다. 현재 서비스 Result=success/ExecMainStatus=0이다.
iOS와 Android 모두 최초 기준이므로 아직 발송하지 않는다. OS별 오류를 분리해
한 스토어 조회 실패가 다른 스토어 점검을 막지 않도록 한다.

번들 SHA256은 `2a52bca0d0985c54d7a9f6db6b80001b4d3b40d51b779eb3a0e61b29ec11e6e0`이다.
시험 서버 기존 설치 16개는 모두 Android이며 버전 미보고 상태다. 이번 작업에서
실제 FCM 푸시는 보내지 않았다. 운영 API/스케줄러·시험 API·터널의 기존 프로세스는
유지했다. 앱 소스의 이동·버전 보고는 테스트했으며 새 APK/IPA 배포는 하지 않았다.

공식 근거: [Apple Lookup](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html),
[Google Play 인증](https://developers.google.com/android-publisher/getting_started),
[production 트랙 조회](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks/get),
[릴리스 상태](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.tracks),
[Firebase Flutter 알림 클릭](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
