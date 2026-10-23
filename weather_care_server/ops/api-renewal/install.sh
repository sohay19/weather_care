#!/bin/bash
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo 'sudo로 실행해 주세요.' >&2
  exit 1
fi
source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
for path in /opt/weather-care-api-renewal /etc/weather-care/api-renewals.json \
  /etc/weather-care/api-renewal.env /etc/systemd/system/weather-care-api-renewal.service \
  /etc/systemd/system/weather-care-api-renewal.timer; do
  if [ -e "$path" ]; then
    echo '기존 API 갱신 안내 설치가 있어 자동으로 덮어쓰지 않습니다.' >&2
    exit 1
  fi
done
test -f "$source_dir/reminder.cjs"
test -x /usr/local/bin/node
getent passwd weather-care >/dev/null
install -d -o root -g root -m 0755 /opt/weather-care-api-renewal
install -o root -g root -m 0644 "$source_dir/reminder.cjs" /opt/weather-care-api-renewal/reminder.cjs
install -o root -g root -m 0755 "$source_dir/configure-gmail.py" /opt/weather-care-api-renewal/configure-gmail.py
install -o root -g weather-care -m 0640 "$source_dir/api-renewals.json" /etc/weather-care/api-renewals.json
install -o root -g weather-care -m 0640 "$source_dir/api-renewal.env.example" /etc/weather-care/api-renewal.env
install -o root -g root -m 0644 "$source_dir/weather-care-api-renewal.service" /etc/systemd/system/weather-care-api-renewal.service
install -o root -g root -m 0644 "$source_dir/weather-care-api-renewal.timer" /etc/systemd/system/weather-care-api-renewal.timer
install -d -o weather-care -g weather-care -m 0700 /var/lib/weather-care-api-renewal
systemd-analyze verify /etc/systemd/system/weather-care-api-renewal.service /etc/systemd/system/weather-care-api-renewal.timer
systemctl daemon-reload
echo '설치를 완료했습니다. Gmail 앱 비밀번호 입력과 발송 검증 후 타이머가 활성화됩니다.'
