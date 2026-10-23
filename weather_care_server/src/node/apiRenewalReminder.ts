import Database from 'better-sqlite3';
import { z } from 'zod';

const DAY_MS = 86_400_000;
const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((value) => {
  const timestamp = Date.parse(`${value}T00:00:00Z`);
  return Number.isFinite(timestamp) && new Date(timestamp).toISOString().slice(0, 10) === value;
});
const serviceSchema = z.object({
  id: z.string().regex(/^[a-z0-9-]{1,80}$/),
  name: z.string().min(1).max(200).regex(/^[^\r\n]+$/),
  account: z.enum(['개발', '운영']),
  requestedOn: dateSchema,
  expiresOn: dateSchema,
}).strict().refine((service) => service.requestedOn < service.expiresOn);
const configSchema = z.object({
  version: z.literal(1),
  recipient: z.string().email(),
  leadDays: z.number().int().min(1).max(365),
  services: z.array(serviceSchema).min(1).max(200),
}).strict().refine((config) => new Set(config.services.map((service) => service.id)).size === config.services.length);

export type ApiRenewalConfig = z.infer<typeof configSchema>;
export type ApiRenewalService = ApiRenewalConfig['services'][number];
export interface ReminderMail {
  to: string;
  subject: string;
  text: string;
  messageId: string;
}

export function parseApiRenewalConfig(value: unknown): ApiRenewalConfig {
  const parsed = configSchema.safeParse(value);
  if (!parsed.success) throw new Error('API_RENEWAL_CONFIG_INVALID');
  return parsed.data;
}

export function koreaDate(now: Date): string {
  return new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
}

export function reminderDate(expiresOn: string, leadDays: number): string {
  return new Date(Date.parse(`${expiresOn}T00:00:00Z`) - leadDays * DAY_MS).toISOString().slice(0, 10);
}

export function initializeReminderState(db: Database.Database): void {
  db.pragma('busy_timeout = 5000');
  db.exec(`CREATE TABLE IF NOT EXISTS renewal_email_sent (
    service_id TEXT NOT NULL,
    expires_on TEXT NOT NULL,
    recipient TEXT NOT NULL,
    sent_at TEXT NOT NULL,
    PRIMARY KEY (service_id, expires_on, recipient)
  )`);
}

export function buildReminderMail(
  config: ApiRenewalConfig,
  services: ApiRenewalService[],
  now: Date,
  messageId: string,
): ReminderMail {
  const today = koreaDate(now);
  const expiresOn = services[0].expiresOn;
  const remaining = Math.round((Date.parse(`${expiresOn}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / DAY_MS);
  const timing = remaining > 0 ? `만료 ${remaining}일 전` : remaining === 0 ? '오늘 만료 예정' : '만료 예정일 경과';
  return {
    to: config.recipient,
    subject: `[날씨챙겨] 공공데이터 API ${timing} — ${services.length}개 서비스`,
    messageId,
    text: [
      '날씨챙겨 API 활용기간 갱신 안내', '',
      `확인일: ${today} (한국시간)`,
      `등록된 만료 예정일: ${expiresOn}`,
      `안내 기준일: ${reminderDate(expiresOn, config.leadDays)} (만료 ${config.leadDays}일 전)`, '',
      ...services.map((service) => `- ${service.name} / ${service.account}계정 / 신청일 ${service.requestedOn}`), '',
      '공공데이터포털에 로그인하여 마이페이지의 활용신청 현황에서 각 서비스의 기간 연장·변경 가능 여부를 확인하고 갱신해 주세요.',
      'https://www.data.go.kr/', '',
      '갱신 후 서버의 /etc/weather-care/api-renewals.json에서 해당 서비스의 expiresOn을 실제 새 만료일로 변경해 주세요.',
      '새 종료일을 자동으로 2년 연장하거나 갱신 완료로 처리하지 않습니다.',
      '이 메일은 등록된 날짜 기준의 안내이며 제공기관 계정의 현재 승인·만료 상태를 실시간 조회한 결과가 아닙니다.',
      '같은 날 만료되는 서비스는 한 통으로 안내합니다. 서버가 안내일에 중지되어 있었다면 재가동 후 처음 확인할 때 보냅니다.',
      'API 인증키는 이 메일에 포함하지 않습니다.',
    ].join('\n'),
  };
}

// A dedicated database lock also prevents simultaneous manual and timer sends.
// SMTP acceptance and SQLite commit cannot be made atomic; see the operations guide.
export async function sendDueRenewalReminders(options: {
  config: ApiRenewalConfig;
  db: Database.Database;
  now: Date;
  send: (mail: ReminderMail) => Promise<void>;
  messageId: (services: ApiRenewalService[]) => string;
}): Promise<{ messages: number; services: number }> {
  const { config, db, now } = options;
  initializeReminderState(db);
  const groups = new Map<string, ApiRenewalService[]>();
  for (const service of config.services) {
    if (koreaDate(now) < reminderDate(service.expiresOn, config.leadDays)) continue;
    const group = groups.get(service.expiresOn) ?? [];
    group.push(service);
    groups.set(service.expiresOn, group);
  }
  const result = { messages: 0, services: 0 };
  for (const [, group] of [...groups].sort(([left], [right]) => left.localeCompare(right))) {
    db.exec('BEGIN IMMEDIATE');
    try {
      const pending = group.filter((service) => !db.prepare(`SELECT 1 FROM renewal_email_sent
        WHERE service_id = ? AND expires_on = ? AND recipient = ?`)
        .get(service.id, service.expiresOn, config.recipient));
      if (pending.length) {
        await options.send(buildReminderMail(config, pending, now, options.messageId(pending)));
        const insert = db.prepare(`INSERT INTO renewal_email_sent (service_id, expires_on, recipient, sent_at)
          VALUES (?, ?, ?, ?)`);
        for (const service of pending) insert.run(service.id, service.expiresOn, config.recipient, now.toISOString());
        result.messages++;
        result.services += pending.length;
      }
      db.exec('COMMIT');
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
  }
  return result;
}
