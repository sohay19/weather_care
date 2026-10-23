# 공용 날씨 DB와 환경별 사용자 DB 전환

2026-10-23 테스트·운영 서버의 실제 전환을 완료했다. [배포·자료 보존·공개 API 검증 기록](../../../docs/공용날씨_DB_실서버_전환_검증_20261023.json)을 참고한다. 아래는 재적용 및 복구 시 사용할 절차다.

## 저장 범위

| DB | 기본 운영 경로 | 저장 자료 |
| --- | --- | --- |
| 공용 날씨 | `/var/lib/weather-care/weather-care-weather.sqlite` | 관측·예보·특보·대기질·자외선·바다·하천·행정경계, 수집 상태·잠금·API 사용량 |
| 운영 사용자 | `/var/lib/weather-care/weather-care-users-production.sqlite` | 설치·인증·선택 위치·활동 시각·알림 설정·발송 이력·특보/강수/낙뢰 알림 상태 |
| 시험 사용자 | `/var/lib/weather-care/weather-care-users-test.sqlite` | 시험 환경의 동일 사용자 항목 |

Node는 두 DB를 각각 연결한다. 날씨 조회·수집·보관 기간 정리는 공용 연결을 사용하고 알림 대상·설정·중복 방지·발송 결과는 각 환경의 사용자 연결을 사용한다. 사용자 삭제는 공용 날씨를 삭제하지 않는다. 공용 DB에는 사용자 테이블을 만들지 않는다.

`node-migrations/users`, `node-migrations/weather`가 Node의 독립된 마이그레이션이다. `migrations/`는 기존 통합 DB·Worker 호환용으로 유지한다. 공용 스키마나 캐시 형식 변경은 운영·시험 양쪽 코드가 함께 읽을 수 있게 배포해야 한다. 시험용 합성 자료는 공용 DB에 넣지 않는다.

## 기존 자료 전환

1. 변경 전 소스·환경 파일·서비스 설정과 두 통합 DB를 백업한다. DB는 SQLite 온라인 백업을 사용한다. 아래 명령은 서버 프로젝트 폴더에서 실행한다.
2. 두 환경의 API·스케줄러·백업과 모든 관련 타이머를 중지하고 실행 중인 단발 작업도 끝난 것을 확인한다. 시험 캐시 동기화·날씨 갱신·자외선·낙뢰·스토어 업데이트와 운영 선수집 작업도 포함한다. 중지 중 요청·설정 변경·알림 발송이 발생하지 않아야 한다.
3. `weather-care` 사용자로 아래 명령을 실행한다. 출력 파일은 모두 새 경로여야 하고 상위 폴더는 준비되어 있어야 한다.

```bash
npm run node:db:split -- \
  /var/lib/weather-care/weather-care-release.sqlite \
  /var/lib/weather-care/weather-care-test.sqlite \
  /var/lib/weather-care/weather-care-weather.sqlite \
  /var/lib/weather-care/weather-care-users-production.sqlite \
  /var/lib/weather-care/weather-care-users-test.sqlite
```

원본은 읽기 전용으로 열며 수정하거나 삭제하지 않는다. 새 파일은 소유자만 읽을 수 있는 권한으로 생성한다. 각 환경의 인증·설정·이력을 그대로 복사한다. 날씨는 두 DB의 자료를 합치며 동일 키는 갱신 시각이 더 최신인 행을 선택한다. 날짜가 키이고 갱신 시각이 없는 과거 일별 자료는 운영 값을 우선하고 시험 자료로 빈 키를 채운다. 행정경계는 최신 수입 시각의 데이터셋 전체를 선택한다.

기존 API 사용량은 두 환경 카운터의 합을 가져온다. 이전 복제로 중복된 양이 포함될 수 있으나 전환 직후 외부 호출 한도를 과소 계산하지 않기 위한 보수적 처리다. 이후에는 공용 카운터 하나에 기록한다. `KMA_LIGHTNING_TEST` 합성 행은 공용 DB로 복사하지 않고 원본에 보존한다.

검증을 통과한 파일만 최종 이름으로 옮긴다. 중간 실패 시 남은 `.splitting` 파일과 오류를 조사하고 새 출력 경로로 재시도한다. 원본·기존 출력은 덮어쓰지 않는다. 원본에 새 스키마에 없는 열이 있으면 누락을 막기 위해 중단한다.

## 환경 설정

운영 환경 파일 `/etc/weather-care/weather-care.env`에 다음을 적용한다. 나머지 인증키는 기존 값을 유지한다.

```dotenv
NODE_DATABASE_PATH=/var/lib/weather-care/weather-care-users-production.sqlite
NODE_WEATHER_DATABASE_PATH=/var/lib/weather-care/weather-care-weather.sqlite
WEATHER_COLLECTION_ENABLED=true
NODE_BACKUP_COMPRESS_WEATHER=true
NODE_COLLECTION_USER_DATABASE_PATHS='["/var/lib/weather-care/weather-care-users-test.sqlite"]'
```

시험 환경 파일 `/etc/weather-care/weather-care-test.env`에는 아래 항목을 설정한다. 공통 환경 파일에서 상속한 수집 대상 목록도 반드시 빈 배열로 덮어쓴다.

```dotenv
NODE_DATABASE_PATH=/var/lib/weather-care/weather-care-users-test.sqlite
NODE_WEATHER_DATABASE_PATH=/var/lib/weather-care/weather-care-weather.sqlite
WEATHER_COLLECTION_ENABLED=false
NODE_COLLECTION_USER_DATABASE_PATHS=[]
NODE_BACKUP_DIR=/var/backups/weather-care/test
NODE_BACKUP_WEATHER_ENABLED=false
```

운영 중앙 수집기는 시험 DB를 읽기 전용으로 추가 연결해 두 환경의 등록 지역을 수집 대상에 반영한다. 다른 환경의 사용자 DB를 수정하지 않는다. 시험 API와 낙뢰 알림은 공용 자료만 읽고 자체 환경에 발송 결과를 기록한다. 두 사용자 DB와 공용 DB에 동일 경로·심볼릭 링크·하드 링크를 지정하면 시작을 거부한다. 통합 DB를 새 사용자 경로로 지정해도 시작을 거부하므로 먼저 분리해야 한다.

신규 설치는 다른 환경 DB 목록을 우선 `[]`로 두고 두 환경에서 `npm run node:db:migrate`를 수행한 다음 운영 수집기 목록에 시험 DB를 추가한다. 로컬 기본 경로는 `data/weather-care-users.sqlite`, `data/weather-care-weather.sqlite`다.

## 서비스 전환과 확인

- 두 환경에 새 소스와 `node-migrations/`를 함께 배포한다. 스토어 업데이트 실행기도 `npm run build:store-update`로 다시 묶어 배포한다. 스토어 알림의 설치 조회 경로는 새 시험 사용자 DB이며 기존 `store-update-test.sqlite` 발송 상태는 그대로 유지한다.
- 기존 시험 캐시 동기화·시험 자외선 타이머를 비활성화한다. 시험 날씨 갱신 서비스는 공통 환경 파일만 읽는 공용 보완 수집으로 바꾸고 기존 30분 타이머를 유지한다. `weather-care-test-cache-sync.service`에도 공용 DB가 있으면 실행하지 않는 조건을 추가했다. 기존 복제 도구는 이전 구조 복구용으로만 보존한다.
- 운영 중앙 수집 스케줄러는 유지하고 `weather-care-shared-uv.service/.timer`를 설치해 자외선 실측을 기존과 같은 매 10분 정각 30초 뒤에 한 번 수집한다. 자외선·보완 수집은 기존 운영 코드에 없는 모듈을 지원하기 위해 시험 릴리스의 수집 코드를 사용하되 운영 공통 환경으로 공용 DB에만 저장한다.
- 시험 낙뢰 타이머는 유지한다. 기존 운영 릴리스에 낙뢰 수집기가 없으므로 먼저 알림 없는 collectSharedLightning.ts를 명시적으로 실행해 공용 관측을 수집하고, 이어서 수집 비활성 설정의 시험 알림 작업이 공용 자료로 시험 사용자만 판단한다. 추후 운영 스케줄러에 낙뢰 수집을 포함한 전체 버전을 적용하면 이 보조 수집 단계를 제거해 수집 주체를 하나로 유지한다.
- 운영 API·시험 API·운영 스케줄러와 기존에 사용하던 알림 작업만 재시작한다. 이 변경을 위해 새로운 종류의 알림을 활성화할 필요는 없다.
- 양쪽 날씨 API가 같은 관측 시각·수치를 반환하고 사용자·알림 설정 조회는 각 환경의 기존 값을 반환하는지 확인한다. 공용 DB에 사용자 테이블이 없고 사용자 DB에 날씨 테이블이 없는지, 기존 설치·설정·이력 건수가 보존됐는지 확인한다. 알림 발송 검증은 시험 기기에 한정한다.

백업 명령은 기본적으로 현재 환경 사용자 DB와 공용 DB를 모두 백업한다. 실제 운영은 NODE_BACKUP_COMPRESS_WEATHER=true로 공용 백업을 .sqlite.gz로 압축하고 시험은 NODE_BACKUP_WEATHER_ENABLED=false로 사용자 DB만 백업해 공용 자료를 중복 보관하지 않는다. 운영·시험 사용자 DB를 모두 보관하려면 각각 해당 환경으로 백업 작업을 실행한다. 시험 백업 폴더를 별도로 준비하고 `weather-care-test-backup.service/.timer`를 설치할 수 있다. 서로 다른 폴더의 DB라도 파일명이 같으면 백업 이름 충돌을 막기 위해 실행을 거부한다. 압축된 공용 백업은 gzip -dc 명령으로 별도 새 SQLite 파일에 풀고 quick_check 후 복원한다. 스토어 업데이트 별도 상태 DB 백업 정책은 기존 절차를 유지한다.

전환 전 설정·소스·원본 DB는 검증이 끝날 때까지 보존한다. 롤백은 서비스들을 중지한 뒤 이전 소스·DB 경로·타이머 설정을 함께 복구한다. 새 DB 사용 이후 생성된 사용자 변경·발송 이력은 이전 원본에 없으므로 이미 서비스를 재개한 뒤에는 새 사용자 DB의 변경을 보존하는 별도 복구 절차가 필요하다.

## 전환 시 서비스 계정·준비 상태 검증

DB를 관리자 계정으로 검사했다면 .sqlite 본체뿐 아니라 -wal·-shm 파일도 weather-care 소유이며 0600인지 확인한다. 관리자 읽기 전용 검사에서도 보조 파일이 생성될 수 있다. 최종 API 검증은 실제 weather-care 계정으로 수행한다.

Type=simple 서비스의 시작 명령 성공은 HTTP 포트 준비 완료를 뜻하지 않는다. 유지보수 상태에서 양쪽 HTTP가 503을 응답할 때까지 기다리고 내부 캐시 조회를 검증한 뒤 RECOVERY_MODE를 해제한다. 사용자 요청을 다시 받기 전 실패는 원본 설정·DB·릴리스로 복구한다.
