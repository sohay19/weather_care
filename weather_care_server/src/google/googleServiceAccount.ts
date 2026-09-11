const GOOGLE_OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';

export interface GoogleServiceAccountCredentials {
  clientEmail: string;
  privateKey: string;
}

interface GoogleAccessTokenResponse {
  access_token?: unknown;
}

export async function createGoogleAccessToken(
  credentials: GoogleServiceAccountCredentials,
  scope: string,
  fetcher: typeof fetch = fetch,
  now: () => number = Date.now,
): Promise<string> {
  validateCredentials(credentials);
  const assertion = await createServiceAccountJwt(credentials, scope, now());
  const response = await fetcher(GOOGLE_OAUTH_TOKEN_URL, {
    method: 'POST',
    signal: AbortSignal.timeout(10_000),
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const body: unknown = await response.json().catch(() => null);
  if (!response.ok || !isRecord(body) || typeof body.access_token !== 'string') {
    throw new Error(`Google OAuth token request failed (${response.status})`);
  }
  return body.access_token;
}

async function createServiceAccountJwt(
  credentials: GoogleServiceAccountCredentials,
  scope: string,
  nowMs: number,
): Promise<string> {
  const issuedAt = Math.floor(nowMs / 1000);
  const header = encodeJson({ alg: 'RS256', typ: 'JWT' });
  const claims = encodeJson({
    iss: credentials.clientEmail,
    scope,
    aud: GOOGLE_OAUTH_TOKEN_URL,
    iat: issuedAt,
    exp: issuedAt + 3600,
  });
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(credentials.privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64Url(new Uint8Array(signature))}`;
}

function validateCredentials(credentials: GoogleServiceAccountCredentials): void {
  if (
    credentials.clientEmail.trim().length === 0 ||
    credentials.privateKey.trim().length === 0
  ) {
    throw new Error('Google service account credentials are not configured');
  }
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem.replaceAll('\\n', '\n');
  const base64 = normalized
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function encodeJson(value: Record<string, string | number>): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/g, '');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
