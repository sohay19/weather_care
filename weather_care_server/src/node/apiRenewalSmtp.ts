import nodemailer from 'nodemailer';
import { createHash } from 'node:crypto';
import { z } from 'zod';
import type { ApiRenewalService, ReminderMail } from './apiRenewalReminder';

export function createReminderSmtp(environment: NodeJS.ProcessEnv) {
  const schema = z.object({
    host: z.string().min(1).max(253).regex(/^[a-zA-Z0-9.-]+$/),
    port: z.coerce.number().int().min(1).max(65535),
    user: z.string().min(1).regex(/^[^\r\n]+$/),
    password: z.string().min(1),
    from: z.string().email(),
  });
  const parsed = schema.safeParse({
    host: environment.API_RENEWAL_SMTP_HOST,
    port: environment.API_RENEWAL_SMTP_PORT ?? '465',
    user: environment.API_RENEWAL_SMTP_USER,
    password: environment.API_RENEWAL_SMTP_PASSWORD,
    from: environment.API_RENEWAL_SMTP_FROM,
  });
  if (!parsed.success) throw new Error('API_RENEWAL_SMTP_NOT_CONFIGURED');
  const settings = parsed.data;
  const transport = nodemailer.createTransport({
    host: settings.host,
    port: settings.port,
    secure: settings.port === 465,
    requireTLS: true,
    auth: { user: settings.user, pass: settings.password },
    connectionTimeout: 15_000,
    greetingTimeout: 15_000,
    socketTimeout: 30_000,
    disableFileAccess: true,
    disableUrlAccess: true,
    logger: false,
    debug: false,
  });
  return {
    async verify(): Promise<void> { await transport.verify(); },
    async send(mail: ReminderMail): Promise<void> {
      const info = await transport.sendMail({ from: { name: '날씨챙겨 운영 알림', address: settings.from }, ...mail });
      if (info.rejected?.length || !info.accepted?.length) throw new Error('API_RENEWAL_RECIPIENT_REJECTED');
    },
    messageId(services: ApiRenewalService[], recipient: string): string {
      const hash = createHash('sha256').update(JSON.stringify({
        recipient, services: services.map((service) => `${service.id}:${service.expiresOn}`).sort(),
      })).digest('hex');
      return `<api-renewal-${hash}@${settings.from.split('@')[1]}>`;
    },
    close(): void { transport.close(); },
  };
}

export function reminderFailureCode(error: unknown): string {
  const message = error instanceof Error ? error.message : '';
  if (/^API_RENEWAL_[A-Z_]+$/.test(message)) return message;
  const code = error && typeof error === 'object' ? (error as { code?: unknown }).code : undefined;
  return typeof code === 'string' && ['EAUTH', 'ETIMEDOUT', 'ECONNECTION', 'ESOCKET', 'EENVELOPE',
    'EMESSAGE', 'EDNS', 'ETLS', 'SQLITE_BUSY', 'EACCES', 'ENOENT'].includes(code)
    ? code : 'API_RENEWAL_FAILED';
}
