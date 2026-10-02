import {
  CORE_COLLECTION_CRON,
  CURRENT_OBSERVATION_CRON,
  RADAR_COLLECTION_CRON,
  ROAD_ICE_COLLECTION_CRON,
  runScheduledJobs,
} from '../cron/jobs';
import { pathToFileURL } from 'node:url';
import { safeErrorName } from '../observability/providerErrorDiagnostics';
import { assertNodeEnvironment, createNodeRuntime } from './runtime';
import type { ScheduledJobName } from './schedule';

const cronByJob: Record<ScheduledJobName, string> = {
  core: CORE_COLLECTION_CRON,
  observation: CURRENT_OBSERVATION_CRON,
  radar: RADAR_COLLECTION_CRON,
  'road-ice': ROAD_ICE_COLLECTION_CRON,
};

export async function runNodeJob(
  job: ScheduledJobName,
  scheduledAt = new Date(),
  runtime = createNodeRuntime(),
): Promise<void> {
  try {
    await runScheduledJobs(runtime.env, cronByJob[job], scheduledAt.getTime());
  } finally {
    runtime.close();
  }
}

async function main(): Promise<void> {
  const job = process.argv[2] as ScheduledJobName | undefined;
  if (!job || !(job in cronByJob)) {
    console.error(JSON.stringify({ event: 'node_job_invalid', allowed: Object.keys(cronByJob) }));
    process.exitCode = 2;
    return;
  }
  try {
    assertNodeEnvironment();
    const scheduledAt = process.argv[3] === undefined ? new Date() : new Date(process.argv[3]);
    if (Number.isNaN(scheduledAt.getTime())) throw new Error('SCHEDULED_TIME_INVALID');
    await runNodeJob(job, scheduledAt);
    console.log(JSON.stringify({ event: 'node_job_completed', job, scheduledAt: scheduledAt.toISOString() }));
  } catch (error) {
    console.error(JSON.stringify({ event: 'node_job_failed', job, error: safeErrorName(error) }));
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) void main();
