export type ScheduledJobName = 'core' | 'observation' | 'radar' | 'road-ice'
  | 'grid-hourly' | 'grid-lightning' | 'grid-river-flow';

export function dueScheduledJobs(date: Date): ScheduledJobName[] {
  const minute = date.getUTCMinutes();
  const due: ScheduledJobName[] = [];
  if (minute % 10 === 0) due.push('core');
  if (minute % 2 === 0 && minute % 10 !== 0) due.push('observation');
  if ((minute - 2 + 60) % 15 === 0) due.push('radar');
  if ((minute - 7 + 60) % 30 === 0) due.push('road-ice');
  if (minute === 6) due.push('grid-hourly');
  if (minute % 10 === 5) due.push('grid-lightning');
  if (minute === 19) due.push('grid-river-flow');
  return due;
}

export function scheduledMinute(date: Date): Date {
  return new Date(Math.floor(date.getTime() / 60_000) * 60_000);
}
