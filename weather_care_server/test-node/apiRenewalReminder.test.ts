import Database from 'better-sqlite3';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildReminderMail, initializeReminderState, koreaDate, parseApiRenewalConfig,
  reminderDate, sendDueRenewalReminders, type ApiRenewalConfig } from '../src/node/apiRenewalReminder';

const databases: Database.Database[] = [];
afterEach(() => { for (const db of databases.splice(0)) db.close(); });
const supplied = () => parseApiRenewalConfig(JSON.parse(readFileSync(
  new URL('../ops/api-renewal/api-renewals.json', import.meta.url), 'utf8')));
function database() { const db = new Database(':memory:'); databases.push(db); return db; }
function run(config: ApiRenewalConfig, db: Database.Database, date: string, send = vi.fn(async () => {})) {
  return sendDueRenewalReminders({ config, db, now: new Date(date), send,
    messageId: (services) => `<test-${services.map((service) => service.id).join('-')}@example.com>` });
}

describe('API 활용기간 갱신 안내', () => {
  it('사용자가 제공한 15개 서비스와 네 날짜별 안내 수를 보존한다', () => {
    const config = supplied();
    expect(config.services).toHaveLength(15);
    expect(config.services.filter((service) => service.account === '운영')).toHaveLength(5);
    expect(Object.fromEntries([...new Set(config.services.map((service) => service.expiresOn))].map((expiresOn) => [
      reminderDate(expiresOn, config.leadDays), config.services.filter((service) => service.expiresOn === expiresOn).length,
    ]))).toEqual({ '2028-10-03': 3, '2028-10-06': 1, '2028-10-07': 9, '2028-10-13': 2 });
  });

  it('한국 날짜의 자정 경계 전에는 발송하지 않고 정확히 7일 전에 대상이 된다', async () => {
    const config = supplied(), db = database(), send = vi.fn(async () => {});
    expect(koreaDate(new Date('2028-10-02T15:00:00Z'))).toBe('2028-10-03');
    expect(await run(config, db, '2028-10-02T14:59:59Z', send)).toEqual({ messages: 0, services: 0 });
    expect(send).not.toHaveBeenCalled();
    expect(await run(config, db, '2028-10-02T15:00:00Z', send)).toEqual({ messages: 1, services: 3 });
    expect(send.mock.calls[0][0].text).toContain('등록된 만료 예정일: 2028-10-10');
  });

  it('전체 일정에서 날짜별 한 통씩 보내고 반복 실행에 중복하지 않는다', async () => {
    const config = supplied(), db = database(), send = vi.fn(async () => {});
    for (const [date, services] of [['2028-10-03', 3], ['2028-10-06', 1], ['2028-10-07', 9], ['2028-10-13', 2]] as const) {
      expect(await run(config, db, `${date}T00:00:00Z`, send)).toEqual({ messages: 1, services });
      expect(await run(config, db, `${date}T01:00:00Z`, send)).toEqual({ messages: 0, services: 0 });
    }
    expect(db.prepare('SELECT COUNT(*) AS count FROM renewal_email_sent').get()).toEqual({ count: 15 });
    expect(send).toHaveBeenCalledTimes(4);
  });

  it('실제 SQLite 파일을 닫고 새 프로세스처럼 다시 열어도 발송 이력을 보존한다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-api-renewal-'));
    const path = join(directory, 'state.sqlite');
    let db = new Database(path);
    try {
      await run(supplied(), db, '2028-10-03T00:00:00Z');
      db.close();
      db = new Database(path);
      const send = vi.fn(async () => {});
      expect(await run(supplied(), db, '2028-10-03T01:00:00Z', send)).toEqual({ messages: 0, services: 0 });
      expect(send).not.toHaveBeenCalled();
    } finally { db.close(); rmSync(directory, { recursive: true, force: true }); }
  });

  it('서버 중지로 안내일을 놓치면 다음 실행에 보내며 만료 경과를 정확히 표시한다', async () => {
    const send = vi.fn(async () => {});
    expect(await run(supplied(), database(), '2028-10-21T00:00:00Z', send)).toEqual({ messages: 4, services: 15 });
    expect(send.mock.calls.every(([mail]) => mail.subject.includes('만료 예정일 경과'))).toBe(true);
  });

  it('발송 실패는 성공으로 기록하지 않아 다음 실행에 다시 시도한다', async () => {
    const config = supplied(), db = database(), failure = vi.fn(async () => { throw new Error('SMTP failed'); });
    await expect(run(config, db, '2028-10-03T00:00:00Z', failure)).rejects.toThrow('SMTP failed');
    expect(db.prepare('SELECT COUNT(*) AS count FROM renewal_email_sent').get()).toEqual({ count: 0 });
    expect(await run(config, db, '2028-10-03T01:00:00Z')).toEqual({ messages: 1, services: 3 });
  });

  it('이전 묶음 성공 후 다음 묶음이 실패해도 성공 기록을 보존한다', async () => {
    const config = supplied(), db = database();
    const send = vi.fn().mockResolvedValueOnce(undefined).mockRejectedValueOnce(new Error('SMTP failed'));
    await expect(run(config, db, '2028-10-07T00:00:00Z', send)).rejects.toThrow('SMTP failed');
    expect(db.prepare('SELECT COUNT(*) AS count FROM renewal_email_sent').get()).toEqual({ count: 3 });
    expect(await run(config, db, '2028-10-07T01:00:00Z')).toEqual({ messages: 2, services: 10 });
  });

  it('실제 갱신된 만료일을 변경하면 같은 서비스도 새 기간의 안내를 다시 보낸다', async () => {
    const config = supplied(), db = database();
    config.services = [config.services[0]];
    await run(config, db, '2028-10-03T00:00:00Z');
    config.services[0].expiresOn = '2030-10-10';
    expect(await run(config, db, '2028-10-03T00:00:00Z')).toEqual({ messages: 0, services: 0 });
    expect(await run(config, db, '2030-10-03T00:00:00Z')).toEqual({ messages: 1, services: 1 });
  });

  it('잘못된 날짜·중복 ID·뒤집힌 기간·수신자 헤더 삽입을 거부한다', () => {
    for (const mutate of [
      (config: ApiRenewalConfig) => { config.services[0].expiresOn = '2028-02-30'; },
      (config: ApiRenewalConfig) => { config.services.push(config.services[0]); },
      (config: ApiRenewalConfig) => { config.services[0].expiresOn = '2020-10-10'; },
      (config: ApiRenewalConfig) => { config.recipient = 'test@example.com\r\nBcc: other@example.com'; },
    ]) {
      const config = supplied(); mutate(config);
      expect(() => parseApiRenewalConfig(config)).toThrow('API_RENEWAL_CONFIG_INVALID');
    }
  });

  it('UTF-8 한글 본문은 서비스·계정·날짜와 갱신 절차를 담고 인증키를 요구하지 않는다', () => {
    const config = supplied();
    const mail = buildReminderMail(config, [config.services[0]], new Date('2028-10-10T00:00:00Z'), '<test@example.com>');
    expect(mail.subject).toContain('오늘 만료 예정');
    expect(mail.text).toContain('기상청_중기예보 조회서비스 / 운영계정');
    expect(mail.text).toContain('자동으로 2년 연장하거나 갱신 완료로 처리하지 않습니다');
    expect(Buffer.from(mail.text, 'utf8').toString('utf8')).toBe(mail.text);
  });

  it('기존 상태 테이블의 초기화가 기존 발송 이력을 지우지 않는다', async () => {
    const db = database();
    await run(supplied(), db, '2028-10-03T00:00:00Z');
    initializeReminderState(db);
    expect(await run(supplied(), db, '2028-10-03T00:00:00Z')).toEqual({ messages: 0, services: 0 });
  });
});
