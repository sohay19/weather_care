import { describe, expect, it } from 'vitest';
import { defaultCommuteSchedule, isCommuteNotificationTime, isValidCommuteSchedule } from '../src/notification/commuteSchedule';

describe('출퇴근 알림 시간 구간', () => {
  it.each([
    ['06:59', false], ['07:00', true], ['09:59', true], ['10:00', false],
    ['12:00', false], ['16:59', false], ['17:00', true], ['19:59', true],
    ['20:00', false], ['23:59', false], ['00:00', false],
  ])('기본 시간 %s의 발송 여부는 %s다', (time, expected) => {
    expect(isCommuteNotificationTime(time, {})).toBe(expected);
  });

  it('개인 시간과 자정을 넘는 구간의 양 끝을 적용한다', () => {
    const schedule = { ...defaultCommuteSchedule,
      commuteToWorkStart: '23:30', commuteToWorkEnd: '01:15',
      commuteFromWorkStart: '10:20', commuteFromWorkEnd: '11:10' };
    for (const time of ['23:30', '23:59', '00:00', '01:14', '10:20', '11:09']) {
      expect(isCommuteNotificationTime(time, schedule)).toBe(true);
    }
    for (const time of ['23:29', '01:15', '07:00', '11:10', '18:00']) {
      expect(isCommuteNotificationTime(time, schedule)).toBe(false);
    }
  });

  it('시작·종료가 같거나 형식이 잘못되면 하루 전체 허용으로 해석하지 않는다', () => {
    for (const commuteToWorkStart of ['10:00', '24:00', '07:60', '7:00', '']) {
      const schedule = { ...defaultCommuteSchedule, commuteToWorkStart };
      expect(isValidCommuteSchedule(schedule)).toBe(false);
      expect(isCommuteNotificationTime('08:00', schedule)).toBe(false);
    }
    expect(isCommuteNotificationTime('24:00', {})).toBe(false);
  });
});
