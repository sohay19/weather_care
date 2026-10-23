import { afterEach, describe, expect, it, vi } from 'vitest';
const { factory, sendMail, verify, close } = vi.hoisted(() => {
  const sendMail = vi.fn(), verify = vi.fn(), close = vi.fn();
  return { sendMail, verify, close, factory: vi.fn(() => ({ sendMail, verify, close })) };
});
vi.mock('nodemailer', () => ({ default: { createTransport: factory } }));
import { createReminderSmtp, reminderFailureCode } from '../src/node/apiRenewalSmtp';

const environment = () => ({ API_RENEWAL_SMTP_HOST: 'smtp.example.com', API_RENEWAL_SMTP_PORT: '465',
  API_RENEWAL_SMTP_USER: 'test@example.com', API_RENEWAL_SMTP_FROM: 'test@example.com',
  API_RENEWAL_SMTP_PASSWORD: 'synthetic-password' });
afterEach(() => vi.clearAllMocks());
describe('갱신 안내 SMTP', () => {
  it('465는 TLS 연결, 587은 필수 STARTTLS와 제한된 대기시간으로 발송한다', () => {
    createReminderSmtp(environment());
    expect(factory.mock.calls[0][0]).toMatchObject({ secure: true, requireTLS: true, logger: false,
      debug: false, disableFileAccess: true, disableUrlAccess: true, socketTimeout: 30000 });
    createReminderSmtp({ ...environment(), API_RENEWAL_SMTP_PORT: '587' });
    expect(factory.mock.calls[1][0]).toMatchObject({ secure: false, requireTLS: true });
  });
  it('인증정보 누락·잘못된 포트·발신자 삽입은 연결 전에 거부한다', () => {
    for (const env of [{}, { ...environment(), API_RENEWAL_SMTP_PORT: '0' },
      { ...environment(), API_RENEWAL_SMTP_FROM: 'test@example.com\r\nBcc: other@example.com' }]) {
      expect(() => createReminderSmtp(env)).toThrow('API_RENEWAL_SMTP_NOT_CONFIGURED');
    }
    expect(factory).not.toHaveBeenCalled();
  });
  it('수신자 거부는 성공으로 처리하지 않고 SMTP 오류 원문을 진단에 노출하지 않는다', async () => {
    const smtp = createReminderSmtp(environment());
    sendMail.mockResolvedValue({ accepted: [], rejected: ['test@example.com'] });
    await expect(smtp.send({ to: 'test@example.com', subject: '한글 제목', text: '한글 본문',
      messageId: '<test@example.com>' })).rejects.toThrow('API_RENEWAL_RECIPIENT_REJECTED');
    expect(reminderFailureCode(Object.assign(new Error('secret-password https://url/?key=secret'), { code: 'EAUTH' }))).toBe('EAUTH');
    expect(reminderFailureCode(new Error('secret-password'))).toBe('API_RENEWAL_FAILED');
  });
  it('같은 서비스·만료일·수신자는 안정된 Message-ID를 사용하고 갱신 후에는 바뀐다', () => {
    const smtp = createReminderSmtp(environment());
    const service = { id: 'test', name: '테스트', account: '개발' as const, requestedOn: '2026-10-14', expiresOn: '2028-10-14' };
    const first = smtp.messageId([service], 'test@example.com');
    expect(smtp.messageId([service], 'test@example.com')).toBe(first);
    expect(smtp.messageId([{ ...service, expiresOn: '2030-10-14' }], 'test@example.com')).not.toBe(first);
    expect(first).not.toContain('test@example.com');
  });
});
