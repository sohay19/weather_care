import { describe, expect, it, vi } from 'vitest';
import { AnalyticsDeletionProviderError,
  submitAnalyticsUserDeletion } from '../src/analytics/analyticsDeletionClient';

const credentials = {
  propertyId: '549443110',
  clientEmail: 'analytics-delete@example.iam.gserviceaccount.com',
  privateKey: 'not-used-by-injected-token-provider',
};

describe('Google Analytics user deletion client', () => {
  it('submits only the Firebase app instance ID to the configured property', async () => {
    const requests: Request[] = [];
    const result = await submitAnalyticsUserDeletion(
      credentials,
      'analytics-instance-1',
      {
        accessTokenProvider: async () => 'access-token',
        fetcher: vi.fn(async (input, init) => {
          requests.push(new Request(input, init));
          return Response.json({ deletionRequestTime: '2026-09-11T01:02:03Z' });
        }) as typeof fetch,
      },
    );

    expect(requests).toHaveLength(1);
    expect(requests[0].url).toBe(
      'https://analyticsadmin.googleapis.com/v1alpha/properties/549443110:submitUserDeletion',
    );
    expect(requests[0].headers.get('Authorization')).toBe('Bearer access-token');
    expect(await requests[0].json()).toEqual({ appInstanceId: 'analytics-instance-1' });
    expect(result).toEqual({ deletionRequestTime: '2026-09-11T01:02:03Z' });
  });

  it('returns a typed provider failure without exposing its response body', async () => {
    const request = submitAnalyticsUserDeletion(credentials, 'analytics-instance-1', {
      accessTokenProvider: async () => 'access-token',
      fetcher: async () => Response.json({ error: { message: 'sensitive' } }, { status: 403 }),
    });
    await expect(request).rejects.toEqual(expect.objectContaining({
      constructor: AnalyticsDeletionProviderError,
      status: 403,
      message: 'Google Analytics deletion request failed',
    }));
  });
});
