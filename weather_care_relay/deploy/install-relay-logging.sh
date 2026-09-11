#!/usr/bin/env bash
# Fresh installation only. Never changes shared journal/syslog or removes log files.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/logging" && pwd)
service=weather-care-relay.service
timer=weather-care-relay-log-prune.timer
version=$(systemctl --version | awk 'NR==1 {print $2}')
[[ $version =~ ^[0-9]+$ && $version -ge 245 ]] || { echo 'systemd 245+ required.' >&2; exit 1; }
systemctl is-active --quiet "$service"
[[ -z $(systemctl show "$service" -p LogNamespace --value) ]] || { echo 'Existing namespace: inspect manually.' >&2; exit 1; }
sources=(30-relay-journal.conf journald@weather-care-relay.conf weather-care-relay-log-prune.service weather-care-relay-log-prune.timer)
targets=(/etc/systemd/system/weather-care-relay.service.d/30-relay-journal.conf /etc/systemd/journald@weather-care-relay.conf /etc/systemd/system/weather-care-relay-log-prune.service /etc/systemd/system/weather-care-relay-log-prune.timer)
for i in "${!targets[@]}"; do
  [[ -f "$source_dir/${sources[$i]}" ]]
  [[ ! -e ${targets[$i]} && ! -L ${targets[$i]} ]] || { echo "Existing target: ${targets[$i]}; stopped." >&2; exit 1; }
done
# Validate units before installation. No service/environment secrets are read.
systemd-analyze verify "$source_dir/weather-care-relay-log-prune.service" "$source_dir/weather-care-relay-log-prune.timer"
installed=()
rollback() {
  echo 'Installation failed; removing only the new configuration files.' >&2
  systemctl disable --now "$timer" 2>/dev/null || true
  for target in "${installed[@]}"; do rm -f -- "$target"; done
  systemctl daemon-reload
  systemctl restart "$service" || true
  echo 'Check relay health manually. Existing logs were not removed.' >&2
}
trap rollback ERR
for i in "${!targets[@]}"; do
  installed+=("${targets[$i]}")
  install -D -o root -g root -m 0644 "$source_dir/${sources[$i]}" "${targets[$i]}"
done
systemctl daemon-reload
systemctl restart "$service"
systemctl is-active --quiet "$service"
[[ $(systemctl show "$service" -p LogNamespace --value) == weather-care-relay ]]
systemctl is-active --quiet systemd-journald@weather-care-relay.service
systemctl enable --now "$timer"
systemctl is-active --quiet "$timer"
trap - ERR
echo 'Installed. Verify /health and the effective journal configuration; see README.'
echo 'Old shared logs remain under their existing retention rules.'
