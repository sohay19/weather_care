import type { NotificationSettings } from '../types';

export type CommuteSchedule = Pick<NotificationSettings,
  'commuteToWorkStart' | 'commuteToWorkEnd' |
  'commuteFromWorkStart' | 'commuteFromWorkEnd'>;

export const defaultCommuteSchedule = {
  commuteToWorkStart: '07:00',
  commuteToWorkEnd: '10:00',
  commuteFromWorkStart: '17:00',
  commuteFromWorkEnd: '20:00',
};

export function isValidCommuteSchedule(schedule: CommuteSchedule): boolean {
  const times = commuteTimes(schedule);
  return Object.values(times).every((time) => /^([01]\d|2[0-3]):[0-5]\d$/.test(time)) &&
    times.commuteToWorkStart !== times.commuteToWorkEnd &&
    times.commuteFromWorkStart !== times.commuteFromWorkEnd;
}

export function isCommuteNotificationTime(time: string, schedule: CommuteSchedule): boolean {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(time) || !isValidCommuteSchedule(schedule)) return false;
  const times = commuteTimes(schedule);
  // 시작 시각은 포함하고 종료 시각은 제외한다. 시작 > 종료는 자정을 넘는 구간이다.
  const within = (start: string, end: string) => start < end
    ? time >= start && time < end
    : time >= start || time < end;
  return within(times.commuteToWorkStart, times.commuteToWorkEnd) ||
    within(times.commuteFromWorkStart, times.commuteFromWorkEnd);
}

function commuteTimes(schedule: CommuteSchedule) {
  return {
    commuteToWorkStart: schedule.commuteToWorkStart ?? defaultCommuteSchedule.commuteToWorkStart,
    commuteToWorkEnd: schedule.commuteToWorkEnd ?? defaultCommuteSchedule.commuteToWorkEnd,
    commuteFromWorkStart: schedule.commuteFromWorkStart ?? defaultCommuteSchedule.commuteFromWorkStart,
    commuteFromWorkEnd: schedule.commuteFromWorkEnd ?? defaultCommuteSchedule.commuteFromWorkEnd,
  };
}
