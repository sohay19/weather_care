import { describe, expect, it } from 'vitest';
import { createGoogleAccessToken } from '../src/google/googleServiceAccount';

describe('Google service account OAuth', () => {
  it('signs a short-lived JWT for the requested scope', async () => {
    const keyPair = await crypto.subtle.generateKey(
      { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
      true,
      ['sign', 'verify'],
    );
    const privateBytes = new Uint8Array(
      await crypto.subtle.exportKey('pkcs8', keyPair.privateKey),
    );
    const privateKey = `-----BEGIN PRIVATE KEY-----\n${toBase64(privateBytes)}\n-----END PRIVATE KEY-----`;
    const assertions: string[] = [];
    const token = await createGoogleAccessToken(
      { clientEmail: 'analytics-delete@example.iam.gserviceaccount.com', privateKey },
      'https://www.googleapis.com/auth/analytics.edit',
      async (input, init) => {
        const request = new Request(input, init);
        const form = await request.formData();
        assertions.push(String(form.get('assertion') ?? ''));
        return Response.json({ access_token: 'synthetic-access-token' });
      },
      () => Date.parse('2026-09-11T00:00:00Z'),
    );

    expect(token).toBe('synthetic-access-token');
    const parts = assertions[0].split('.');
    expect(parts).toHaveLength(3);
    const claims = JSON.parse(fromBase64Url(parts[1])) as Record<string, unknown>;
    expect(claims).toMatchObject({
      iss: 'analytics-delete@example.iam.gserviceaccount.com',
      scope: 'https://www.googleapis.com/auth/analytics.edit',
      aud: 'https://oauth2.googleapis.com/token',
      iat: 1789084800,
      exp: 1789088400,
    });
  });
});

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64Url(value: string): string {
  const base64 = value.replaceAll('-', '+').replaceAll('_', '/');
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
  return atob(padded);
}
