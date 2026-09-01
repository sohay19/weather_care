export type ProviderFailureReason =
  | 'NOT_CONFIGURED'
  | 'AUTHORIZATION_FAILED'
  | 'RATE_LIMITED'
  | 'UPSTREAM_CLIENT_ERROR'
  | 'UPSTREAM_SERVER_ERROR'
  | 'UPSTREAM_REJECTED'
  | 'TIMEOUT'
  | 'NETWORK_ERROR'
  | 'INVALID_JSON'
  | 'INVALID_RESPONSE'
  | 'NO_USABLE_DATA'
  | 'UNKNOWN';

export type ProviderOperation =
  | 'ANALYSIS'
  | 'RADAR'
  | 'WARNING'
  | 'ROAD_CONTROL';

export type ProviderFailureDetail =
  | 'ANALYSIS_NO_DATA_ROWS'
  | 'ANALYSIS_TIMESTAMP_MISSING'
  | 'ANALYSIS_TARGET_TIME_MISSING'
  | 'ANALYSIS_RAIN_FLAG_MISSING'
  | 'ANALYSIS_MISSING_VALUE'
  | 'ANALYSIS_NON_BINARY_VALUE'
  | 'ANALYSIS_TEXT_VALUE'
  | 'WARNING_SELECTED_REGION_ROW_INVALID'
  | 'WARNING_UNSUPPORTED_ROWS'
  | 'WARNING_JSON_RESPONSE'
  | 'WARNING_HTML_RESPONSE'
  | 'WARNING_ROWS_WITHOUT_TIMESTAMPS'
  | 'WARNING_COLUMN_FORMAT_CHANGED'
  | 'ROAD_CONTROL_FETCH_FAILED';

export interface ProviderErrorDiagnostic {
  error: string;
  failureReason: ProviderFailureReason;
  httpStatus?: number;
  operation?: ProviderOperation;
  detail?: ProviderFailureDetail;
}

export function providerErrorDiagnostic(
  error: unknown,
): ProviderErrorDiagnostic {
  const errorName = error instanceof Error ? error.name : 'UnknownError';
  const message = error instanceof Error ? error.message : '';
  const httpStatus = statusFromMessage(message);
  const operation = operationFromMessage(message);
  const detail = failureDetailFromError(error);

  return {
    error: errorName,
    failureReason: failureReason(errorName, message, httpStatus),
    ...(httpStatus === undefined ? {} : { httpStatus }),
    ...(operation === undefined ? {} : { operation }),
    ...(detail === undefined ? {} : { detail }),
  };
}

function failureReason(
  errorName: string,
  message: string,
  httpStatus: number | undefined,
): ProviderFailureReason {
  if (
    errorName === 'TimeoutError' ||
    /\btime(?:d)?\s*out\b|\btimeout\b/i.test(message)
  ) {
    return 'TIMEOUT';
  }
  if (errorName === 'TypeError') return 'NETWORK_ERROR';
  if (/\bnetwork\b/i.test(message)) return 'NETWORK_ERROR';
  if (/not configured/i.test(message)) return 'NOT_CONFIGURED';
  if (httpStatus === 401 || httpStatus === 403) {
    return 'AUTHORIZATION_FAILED';
  }
  if (httpStatus === 429) return 'RATE_LIMITED';
  if (httpStatus !== undefined && httpStatus >= 500) {
    return 'UPSTREAM_SERVER_ERROR';
  }
  if (httpStatus !== undefined && httpStatus >= 400) {
    return 'UPSTREAM_CLIENT_ERROR';
  }
  if (/authorization|\bauth\b|인증/i.test(message)) {
    return 'AUTHORIZATION_FAILED';
  }
  if (/response contains an error|provider error|returned [^:]+:/i.test(message)) {
    return 'UPSTREAM_REJECTED';
  }
  if (/not json/i.test(message)) return 'INVALID_JSON';
  if (
    /unknown format|schema is invalid|response .*invalid|no valid|too short|outside the valid/i.test(
      message,
    )
  ) {
    return 'INVALID_RESPONSE';
  }
  if (/no body|no items|no numeric|no usable|not available/i.test(message)) {
    return 'NO_USABLE_DATA';
  }
  return 'UNKNOWN';
}

const PROVIDER_FAILURE_DETAILS = new Set<ProviderFailureDetail>([
  'ANALYSIS_NO_DATA_ROWS',
  'ANALYSIS_TIMESTAMP_MISSING',
  'ANALYSIS_TARGET_TIME_MISSING',
  'ANALYSIS_RAIN_FLAG_MISSING',
  'ANALYSIS_MISSING_VALUE',
  'ANALYSIS_NON_BINARY_VALUE',
  'ANALYSIS_TEXT_VALUE',
  'WARNING_SELECTED_REGION_ROW_INVALID',
  'WARNING_UNSUPPORTED_ROWS',
  'WARNING_JSON_RESPONSE',
  'WARNING_HTML_RESPONSE',
  'WARNING_ROWS_WITHOUT_TIMESTAMPS',
  'WARNING_COLUMN_FORMAT_CHANGED',
  'ROAD_CONTROL_FETCH_FAILED',
]);

function failureDetailFromError(
  error: unknown,
): ProviderFailureDetail | undefined {
  if (error === null || typeof error !== 'object') return undefined;
  const value = (error as { providerFailureDetail?: unknown })
    .providerFailureDetail;
  return typeof value === 'string' &&
    PROVIDER_FAILURE_DETAILS.has(value as ProviderFailureDetail)
    ? (value as ProviderFailureDetail)
    : undefined;
}

function statusFromMessage(message: string): number | undefined {
  const match = /\bstatus(?:\s+code)?\s*[:=]?\s*(\d{3})\b/i.exec(message);
  if (!match) return undefined;
  const status = Number(match[1]);
  return status >= 100 && status <= 599 ? status : undefined;
}

function operationFromMessage(message: string): ProviderOperation | undefined {
  if (/\banalysis\b/i.test(message)) return 'ANALYSIS';
  if (/\bradar\b/i.test(message)) return 'RADAR';
  if (/\bwarning\b/i.test(message)) return 'WARNING';
  if (/\broad control\b/i.test(message)) return 'ROAD_CONTROL';
  return undefined;
}
