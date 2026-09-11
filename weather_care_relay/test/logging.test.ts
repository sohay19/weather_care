import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (name: string) => readFileSync(new URL(`../deploy/${name}`, import.meta.url), 'utf8');

describe('relay-only logging deployment contracts', () => {
  it('routes both output streams into the relay namespace', () => {
    const config = read('logging/30-relay-journal.conf');
    for (const line of ['LogNamespace=weather-care-relay', 'StandardOutput=journal', 'StandardError=journal']) {
      expect(config).toContain(line);
    }
  });
  it('limits retention and disables journal forwarding', () => {
    const config = read('logging/journald@weather-care-relay.conf');
    expect(config).toContain('MaxRetentionSec=3day');
    expect(config).toContain('SystemMaxUse=32M');
    for (const destination of ['Syslog', 'KMsg', 'Console', 'Wall']) {
      expect(config).toContain(`ForwardTo${destination}=no`);
    }
  });
  it('rotates and vacuums only the named namespace', () => {
    const service = read('logging/weather-care-relay-log-prune.service');
    expect(service).toContain('ExecStart=/usr/bin/journalctl --namespace=weather-care-relay --rotate --vacuum-time=3d');
    expect(read('logging/weather-care-relay-log-prune.timer')).toContain('OnUnitActiveSec=15min');
  });
  it('preflights existing targets and rolls back new files only', () => {
    const script = read('install-relay-logging.sh');
    expect(script).toContain('Existing target:');
    expect(script).toContain('trap \'rollback "$LINENO"\' ERR');
    expect(script).toContain('Failed phase=$phase line=$line exit=$status');
    expect(script).toContain('"${installed[@]}"');
    expect(script).not.toMatch(/rm[^\n]*\/var\/log/);
    expect(script).not.toContain('/etc/rsyslog');
    expect(script).not.toContain('/etc/systemd/journald.conf');
  });
  it('waits for namespace startup before restarting the relay', () => {
    const script = read('install-relay-logging.sh');
    const start = script.indexOf('systemctl restart systemd-journald@weather-care-relay.service');
    const relay = script.indexOf('phase=restart-relay');
    expect(start).toBeGreaterThan(0);
    expect(relay).toBeGreaterThan(start);
    expect(script.slice(start, relay)).toContain('systemctl is-active --quiet systemd-journald@weather-care-relay.service');
  });
});
