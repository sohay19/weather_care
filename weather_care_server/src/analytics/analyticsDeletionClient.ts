import { createGoogleAccessToken } from '../google/googleServiceAccount';

const ANALYTICS_EDIT_SCOPE = 'https://www.googleapis.com/auth/analytics.edit';

export interface AnalyticsDeletionCredentials {
  propertyId: string;
  clientEmail: string;
  privateKey: string;
}

export interface AnalyticsDeletionResult {
  deletionRequestTime: string;
}

interface AnalyticsDeletionDependencies {
  fetcher?: typeof fetch;
  accessTokenProvider?: () => Promise<string>;
}

export class AnalyticsDeletionProviderError extends Error {
  constructor(readonly status: number) {
    super('Google Analytics deletion request failed');
  }
}

export async function submitAnalyticsUserDeletion(
  credentials: AnalyticsDeletionCredentials,
  appInstanceId: string,
  dependencies: AnalyticsDeletionDependencies = {},
): Promise<AnalyticsDeletionResult> {
  if (!/^\d{1,20}$/.test(credentials.propertyId)) {
    throw new Error('Google Analytics property is not configured');
  }
  if (appInstanceId.length === 0 || appInstanceId.length > 256) {
    throw new Error('Invalid Firebase app instance ID');
  }
  const fetcher = dependencies.fetcher ?? fetch;
  const accessToken = dependencies.accessTokenProvider
    ? await dependencies.accessTokenProvider()
    : await createGoogleAccessToken(
        credentials,
        ANALYTICS_EDIT_SCOPE,
        fetcher,
      );
  const response = await fetcher(
    `https://analyticsadmin.googleapis.com/v1alpha/properties/${encodeURIComponent(credentials.propertyId)}:submitUserDeletion`,
    {
      method: 'POST',
      signal: AbortSignal.timeout(10_000),
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ appInstanceId }),
    },
  );
  const body: unknown = await response.json().catch(() => null);
  if (!response.ok) throw new AnalyticsDeletionProviderError(response.status);
  if (!isRecord(body) || !isRfc3339(body.deletionRequestTime)) {
    throw new AnalyticsDeletionProviderError(502);
  }
  return { deletionRequestTime: body.deletionRequestTime };
}

function isRfc3339(value: unknown): value is string {
  return typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(value) &&
    !Number.isNaN(Date.parse(value));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
