import Database from 'better-sqlite3';
import { readFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { createHash } from 'node:crypto';
import { koreaDate, parseApiRenewalConfig, reminderDate, sendDueRenewalReminders } from './apiRenewalReminder';
import { createReminderSmtp, reminderFailureCode } from './apiRenewalSmtp';

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const mode = args[0];
  if (args.length > 1 || (mode && !['--preview', '--verify-smtp', '--test-email'].includes(mode))) {
    throw new Error('API_RENEWAL_ARGUMENT_INVALID');
  }
  const configPath = process.env.API_RENEWAL_CONFIG_PATH ?? '/etc/weather-care/api-renewals.json';
  const config = parseApiRenewalConfig(JSON.parse(readFileSync(configPath, 'utf8')));
  const now = new Date();
  if (mode === '--preview') {
    console.log(JSON.stringify({ event: 'api_renewal_preview', today: koreaDate(now), recipient: config.recipient,
      services: config.services.map((service) => ({ ...service,
        reminderOn: reminderDate(service.expiresOn, config.leadDays) })) }));
    return;
  }
  const smtp = createReminderSmtp(process.env);
  try {
    if (mode === '--verify-smtp') {
      await smtp.verify();
      console.log(JSON.stringify({ event: 'api_renewal_smtp_verified' }));
    } else if (mode === '--test-email') {
      const schedule = new Map<string, number>();
      for (const service of config.services) {
        const date = reminderDate(service.expiresOn, config.leadDays);
        schedule.set(date, (schedule.get(date) ?? 0) + 1);
      }
      await smtp.send({
        to: config.recipient,
        subject: '[날씨챙겨] API 갱신 안내 메일 설정 확인',
        messageId: `<api-renewal-test-${createHash('sha256').update(now.toISOString()).digest('hex')}@weather-care.local>`,
        text: ['날씨챙겨 API 갱신 안내 메일의 발송 설정을 확인합니다.', '',
          `등록된 서비스: ${config.services.length}개`,
          `매일 오전 9시(한국시간) 확인하여 만료 ${config.leadDays}일 전에 안내합니다.`, '',
          ...[...schedule].sort().map(([date, count]) => `${date}: ${count}개 서비스 갱신 안내 예정`), '',
          '이 메일은 설정 확인용입니다. API가 만료되었다는 뜻이 아닙니다.',
          '메일 서버의 접수와 받은편지함 도착은 다르므로 수신함과 스팸함에서 확인해 주세요.',
        ].join('\n'),
      });
      console.log(JSON.stringify({ event: 'api_renewal_test_email_accepted' }));
    } else {
      const statePath = process.env.API_RENEWAL_STATE_PATH ?? '/var/lib/weather-care-api-renewal/state.sqlite';
      mkdirSync(dirname(statePath), { recursive: true, mode: 0o700 });
      const db = new Database(statePath);
      try {
        const result = await sendDueRenewalReminders({ config, db, now,
          send: (mail) => smtp.send(mail), messageId: (services) => smtp.messageId(services, config.recipient) });
        console.log(JSON.stringify({ event: 'api_renewal_check_completed', ...result }));
      } finally { db.close(); }
    }
  } finally { smtp.close(); }
}

void main().catch((error) => {
  console.error(JSON.stringify({ event: 'api_renewal_check_failed', code: reminderFailureCode(error) }));
  process.exitCode = 1;
});
