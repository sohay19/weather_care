export type ProviderFailureReason =
  | 'NOT_CONFIGURED'
  | 'AUTHORIZATION_FAILED'
  | 'QUOTA_EXCEEDED'
  | 'BUDGET_EXHAUSTED'
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
  | 'WARNING_REGION_MAPPING_INVALID'
  | 'ROAD_CONTROL_FETCH_FAILED';

export interface ProviderErrorDiagnostic {
  error: string;
  failureReason: ProviderFailureReason;
  httpStatus?: number;
  operation?: ProviderOperation;
  detail?: ProviderFailureDetail;
  networkCode?: string;
}

export function providerErrorDiagnostic(
  error: unknown,
): ProviderErrorDiagnostic {
  const errorName = safeErrorName(error);
  const message = error instanceof Error ? error.message : '';
  const httpStatus = statusFromMessage(message);
  const operation = operationFromMessage(message);
  const detail = failureDetailFromError(error);
  const networkCode = networkCodeFromError(error);

  return {
    error: errorName,
    failureReason: networkCode ? (/TIMEDOUT|TIMEOUT/.test(networkCode) ? 'TIMEOUT' : 'NETWORK_ERROR')
      : failureReason(errorName, message, httpStatus),
    ...(httpStatus === undefined ? {} : { httpStatus }),
    ...(operation === undefined ? {} : { operation }),
    ...(detail === undefined ? {} : { detail }),
    ...(networkCode === undefined ? {} : { networkCode }),
  };
}

// 오류 원문·URL·임의 code를 기록하지 않고 알려진 연결 오류 코드만 남긴다.
function networkCodeFromError(error: unknown): string | undefined {
  const allowed = new Set(['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED', 'ENOTFOUND',
    'EAI_AGAIN', 'EHOSTUNREACH', 'ENETUNREACH', 'UND_ERR_CONNECT_TIMEOUT',
    'UND_ERR_HEADERS_TIMEOUT', 'UND_ERR_BODY_TIMEOUT', 'UND_ERR_SOCKET',
    'ERR_TLS_CERT_ALTNAME_INVALID', 'CERT_HAS_EXPIRED']);
  let current = error;
  for (let depth = 0; depth < 3 && current !== null && typeof current === 'object'; depth++) {
    const value = current as { code?: unknown; cause?: unknown };
    if (typeof value.code === 'string' && allowed.has(value.code)) return value.code;
    current = value.cause;
  }
  return undefined;
}

// Error.name is mutable and may itself contain a URL, token, or user input.
export function safeErrorName(error: unknown): string {
  if (!(error instanceof Error)) return 'UnknownError';
  const allowed = ['Error', 'TypeError', 'RangeError', 'SyntaxError',
    'ReferenceError', 'URIError', 'EvalError', 'AggregateError', 'TimeoutError', 'AbortError',
    'ItsRoadControlProviderError', 'KmaRoadIceProviderError', 'KmaWarningProviderError',
    'KmaPrecipitationObservationProviderError', 'KmaUvProviderError', 'KmaWeatherProviderError',
    'AirKoreaAirQualityProviderError', 'KmaDailyObservationProviderError',
    'KmaHourlyObservationProviderError', 'KmaMidTermProviderError', 'KmaGridObservationProviderError'];
  return allowed.includes(error.name) ? error.name : 'Error';
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
  if (/(?:APIHUB|MID_TERM)_BUDGET_EXHAUSTED/.test(message)) return 'BUDGET_EXHAUSTED';
  if (/quota\s+exceeded|일일\s*최대\s*호출|호출\s*용량\s*제한/i.test(message)) {
    return 'QUOTA_EXCEEDED';
  }
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
  'WARNING_REGION_MAPPING_INVALID',
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
