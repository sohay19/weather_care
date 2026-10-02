import {
  providerErrorDiagnostic,
  safeErrorName,
} from './providerErrorDiagnostics';

interface ProviderRequestContext {
  endpoint: 'GRID_OBSERVATION' | 'AWS_MINUTE' | 'AWS_STATION';
  phase: 'WAIT_HEADERS' | 'READ_BODY';
  timeoutMs: number;
  elapsedMs: number;
  variable?: string;
  targetTime?: string;
  from?: string;
  to?: string;
  month?: string;
  httpStatus?: number;
}

export function logProviderRequestFailure(
  error: unknown,
  signal: AbortSignal,
  context: ProviderRequestContext,
): void {
  const timeoutReason = signal.aborted &&
    signal.reason instanceof Error &&
    providerErrorDiagnostic(signal.reason).failureReason === 'TIMEOUT'
      ? signal.reason : undefined;
  console.error(JSON.stringify({
    event: 'weather_provider_request_failed',
    ...context,
    ...providerErrorDiagnostic(timeoutReason ?? error),
    ...(timeoutReason && timeoutReason !== error
      ? { caughtError: safeErrorName(error) } : {}),
  }));
}
