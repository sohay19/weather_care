import {
  CORE_COLLECTION_CRON,
  CURRENT_OBSERVATION_CRON,
  RADAR_COLLECTION_CRON,
  ROAD_ICE_COLLECTION_CRON,
  runScheduledJobs,
} from '../cron/jobs';
import { safeErrorName } from '../observability/providerErrorDiagnostics';
import { prewarmNationwideInRuntime } from './prewarmNationwide';
import { assertNodeEnvironment, createNodeRuntime } from './runtime';
import { dueScheduledJobs, scheduledMinute, type ScheduledJobName } from './schedule';

const cronByJob: Record<ScheduledJobName, string> = {
  core: CORE_COLLECTION_CRON,
  observation: CURRENT_OBSERVATION_CRON,
  radar: RADAR_COLLECTION_CRON,
  'road-ice': ROAD_ICE_COLLECTION_CRON,
};

assertNodeEnvironment();
const runtime = createNodeRuntime();
const delivered = new Set<string>();
const running = new Set<Promise<void>>();
const runningJobs = new Set<ScheduledJobName>();
let timer: ReturnType<typeof setInterval> | undefined;
let closing = false;

function runDueJobs(now = new Date()): void {
  const scheduledAt = scheduledMinute(now);
  for (const job of dueScheduledJobs(scheduledAt)) {
    const deliveryKey = `${job}:${scheduledAt.toISOString()}`;
    if (delivered.has(deliveryKey)) continue;
    delivered.add(deliveryKey);
    if (runningJobs.has(job)) {
      console.warn(JSON.stringify({
        event: 'node_scheduled_job_skipped_overlap',
        job,
        scheduledAt: scheduledAt.toISOString(),
      }));
      continue;
    }
    runningJobs.add(job);
    const promise = runScheduledJobs(
      runtime.env,
      cronByJob[job],
      scheduledAt.getTime(),
    ).then(() => {
      console.log(JSON.stringify({
        event: 'node_scheduled_job_completed', job, scheduledAt: scheduledAt.toISOString(),
      }));
    }).catch((error) => {
      console.error(JSON.stringify({
        event: 'node_scheduled_job_failed', job, error: safeErrorName(error),
      }));
    }).finally(() => {
      running.delete(promise);
      runningJobs.delete(job);
    });
    running.add(promise);
  }

  if (delivered.size > 1_000) {
    const oldestAllowed = now.getTime() - 24 * 60 * 60 * 1000;
    for (const key of delivered) {
      const timestamp = key.slice(key.indexOf(':') + 1);
      if (Date.parse(timestamp) < oldestAllowed) delivered.delete(key);
    }
  }
}

async function startScheduler(): Promise<void> {
  const summary = await prewarmNationwideInRuntime(runtime);
  console.log(JSON.stringify({
    event: 'node_operational_prewarm_finished',
    ...summary,
  }));
  if (closing) return;
  runDueJobs();
  timer = setInterval(runDueJobs, 15_000);
  console.log(JSON.stringify({ event: 'node_scheduler_started' }));
}

const startup = startScheduler().catch((error) => {
  closing = true;
  console.error(JSON.stringify({
    event: 'node_operational_prewarm_failed',
    error: safeErrorName(error),
  }));
  process.exitCode = 1;
});
running.add(startup);
void startup.finally(() => {
  running.delete(startup);
  if (process.exitCode) runtime.close();
});

async function shutdown(signal: string): Promise<void> {
  if (closing) return;
  closing = true;
  if (timer !== undefined) clearInterval(timer);
  await Promise.allSettled([...running]);
  runtime.close();
  console.log(JSON.stringify({ event: 'node_scheduler_stopped', signal }));
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
