import { describe, expect, it, vi } from 'vitest';
import { sendBatch } from '../src/notification/fcmClient';

const credentials = {
  projectId: 'weather-care-2aaa8',
  clientEmail: 'worker@example.iam.gserviceaccount.com',
  privateKey: 'test-private-key',
};

describe('FCM HTTP v1 client', () => {
  it('sends notification payloads with one acquired access token', async () => {
    const requests: Request[] = [];
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      requests.push(new Request(input, init));
      return Response.json({ name: 'projects/test/messages/1' });
    }) as typeof fetch;
    const accessTokenProvider = vi.fn(async () => 'access-token');

    const results = await sendBatch(
      credentials,
      [
        {
          token: 'device-token',
          title: '오늘 준비할 내용',
          body: '우산을 챙기세요',
          notificationKey: 'MORNING_BRIEF',
          notificationTarget: 'MAIN',
          notificationTopic: 'OVERVIEW',
        },
      ],
      { fetcher, accessTokenProvider },
    );

    expect(accessTokenProvider).toHaveBeenCalledTimes(1);
    expect(requests).toHaveLength(1);
    expect(requests[0].headers.get('Authorization')).toBe(
      'Bearer access-token',
    );
    expect(await requests[0].json()).toMatchObject({
      message: {
        token: 'device-token',
        notification: {
          title: '오늘 준비할 내용',
          body: '우산을 챙기세요',
        },
        data: {
          notificationKey: 'MORNING_BRIEF',
          notificationTarget: 'MAIN',
          notificationTopic: 'OVERVIEW',
        },
      },
    });
    expect(results).toEqual([
      {
        token: 'device-token',
        notificationKey: 'MORNING_BRIEF',
        success: true,
        unregistered: false,
        status: 200,
      },
    ]);
  });

  it('marks an expired device token as unregistered', async () => {
    const fetcher = vi.fn(async () =>
      Response.json(
        {
          error: {
            details: [{ errorCode: 'UNREGISTERED' }],
          },
        },
        { status: 400 },
      ),
    ) as typeof fetch;

    const [result] = await sendBatch(
      credentials,
      [
        {
          token: 'expired-token',
          title: '제목',
          body: '본문',
          notificationKey: 'MORNING_BRIEF',
          notificationTarget: 'MAIN',
          notificationTopic: 'OVERVIEW',
        },
      ],
      { fetcher, accessTokenProvider: async () => 'access-token' },
    );

    expect(result).toMatchObject({
      success: false,
      unregistered: true,
      status: 400,
    });
  });
});
