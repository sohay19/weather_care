export interface RelayConfig {
  host: string;
  port: number;
  itsApiKey: string;
  relayToken: string;
  upstreamTimeoutMs: number;
  itsCacheTtlMs: number;
}

export function loadRelayConfig(
  environment: NodeJS.ProcessEnv = process.env,
): RelayConfig {
  const itsApiKey = required(environment.ITS_API_KEY, 'ITS_API_KEY');
  const relayToken = required(environment.RELAY_TOKEN, 'RELAY_TOKEN');
  if (relayToken.length < 32) {
    throw new Error('RELAY_TOKEN must contain at least 32 characters');
  }

  return {
    host: environment.HOST?.trim() || '127.0.0.1',
    port: positiveInteger(environment.PORT, 8788, 'PORT'),
    itsApiKey,
    relayToken,
    upstreamTimeoutMs: positiveInteger(
      environment.UPSTREAM_TIMEOUT_MS,
      10_000,
      'UPSTREAM_TIMEOUT_MS',
    ),
    itsCacheTtlMs: durationMilliseconds(
      environment.ITS_CACHE_TTL_MS,
      3_600_000,
      'ITS_CACHE_TTL_MS',
    ),
  };
}

function required(value: string | undefined, name: string): string {
  const normalized = value?.trim();
  if (!normalized) throw new Error(`${name} is required`);
  return normalized;
}

function positiveInteger(
  value: string | undefined,
  fallback: number,
  name: string,
): number {
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0 || parsed > 65_535) {
    throw new Error(`${name} must be a positive integer no greater than 65535`);
  }
  return parsed;
}

function durationMilliseconds(
  value: string | undefined,
  fallback: number,
  name: string,
): number {
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0 || parsed > 86_400_000) {
    throw new Error(`${name} must be between 1 and 86400000 milliseconds`);
  }
  return parsed;
}
