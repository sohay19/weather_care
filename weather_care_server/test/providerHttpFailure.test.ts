import { describe, expect, it } from 'vitest';
import { providerHttpFailureMessage } from '../src/providers/providerHttpFailure';

describe('provider HTTP failure handling', () => {
  it('consumes a quota error response and emits only a fixed diagnostic detail', async () => {
    const response = new Response(JSON.stringify({
      result: {
        status: 403,
        message: '일일 최대 호출 용량 제한으로 사용할 수 없습니다.',
      },
    }), { status: 403 });

    await expect(
      providerHttpFailureMessage(response, 'KMA request'),
    ).resolves.toBe('KMA request failed with status 403: quota exceeded');
    expect(response.bodyUsed).toBe(true);
  });
});
