export type ScheduledJobName = 'core' | 'radar' | 'road-ice';

export function dueScheduledJobs(date: Date): ScheduledJobName[] {
  const minute = date.getUTCMinutes();
  const due: ScheduledJobName[] = [];
  if (minute % 10 === 0) due.push('core');
  if ((minute - 2 + 60) % 15 === 0) due.push('radar');
  if ((minute - 7 + 60) % 30 === 0) due.push('road-ice');
  return due;
}

export function scheduledMinute(date: Date): Date {
  return new Date(Math.floor(date.getTime() / 60_000) * 60_000);
}
