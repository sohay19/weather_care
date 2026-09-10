import {
  NotificationTarget,
  NotificationTopic,
} from './notificationDestination';

const GOOGLE_OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

export interface FcmPayload {
  token: string;
  title: string;
  body: string;
  notificationKey: string;
  notificationTarget: NotificationTarget;
  notificationTopic: NotificationTopic;
}

export interface FcmCredentials {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export interface FcmSendResult {
  token: string;
  notificationKey: string;
  success: boolean;
  unregistered: boolean;
  status: number;
}

interface FcmClientDependencies {
  fetcher?: typeof fetch;
  now?: () => number;
  accessTokenProvider?: () => Promise<string>;
}

interface GoogleAccessTokenResponse {
  access_token?: unknown;
}

export async function sendPush(
  credentials: FcmCredentials,
  payload: FcmPayload,
  dependencies: FcmClientDependencies = {},
): Promise<FcmSendResult> {
  const [result] = await sendBatch(credentials, [payload], dependencies);
  if (!result) {
    throw new Error('FCM send returned no result');
  }
  return result;
}

export async function sendBatch(
  credentials: FcmCredentials,
  payloads: FcmPayload[],
  dependencies: FcmClientDependencies = {},
): Promise<FcmSendResult[]> {
  if (payloads.length === 0) return [];
  validateCredentials(credentials);

  const fetcher = dependencies.fetcher ?? fetch;
  const accessToken = dependencies.accessTokenProvider
    ? await dependencies.accessTokenProvider()
    : await createGoogleAccessToken(
        credentials,
        fetcher,
        dependencies.now ?? Date.now,
      );

  return Promise.all(
    payloads.map((payload) =>
      sendFcmMessage(fetcher, credentials.projectId, accessToken, payload),
    ),
  );
}

async function createGoogleAccessToken(
  credentials: FcmCredentials,
  fetcher: typeof fetch,
  now: () => number,
): Promise<string> {
  const assertion = await createServiceAccountJwt(credentials, now());
  const response = await fetcher(GOOGLE_OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const body = await response.json<GoogleAccessTokenResponse>();
  if (!response.ok || typeof body.access_token !== 'string') {
    throw new Error(`FCM OAuth token request failed (${response.status})`);
  }
  return body.access_token;
}

export async function createServiceAccountJwt(
  credentials: FcmCredentials,
  nowMs: number,
): Promise<string> {
  const issuedAt = Math.floor(nowMs / 1000);
  const header = encodeJson({ alg: 'RS256', typ: 'JWT' });
  const claims = encodeJson({
    iss: credentials.clientEmail,
    scope: FCM_SCOPE,
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

async function sendFcmMessage(
  fetcher: typeof fetch,
  projectId: string,
  accessToken: string,
  payload: FcmPayload,
): Promise<FcmSendResult> {
  const response = await fetcher(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: payload.token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: {
            notificationKey: payload.notificationKey,
            notificationTarget: payload.notificationTarget,
            notificationTopic: payload.notificationTopic,
          },
          android: {
            priority: 'high',
          },
          apns: {
            payload: {
              aps: { sound: 'default' },
            },
          },
        },
      }),
    },
  );
  const errorCode = response.ok ? undefined : await fcmErrorCode(response);
  return {
    token: payload.token,
    notificationKey: payload.notificationKey,
    success: response.ok,
    unregistered:
      response.status === 404 || errorCode === 'UNREGISTERED',
    status: response.status,
  };
}

async function fcmErrorCode(response: Response): Promise<string | undefined> {
  try {
    const body: unknown = await response.json();
    if (!isRecord(body) || !isRecord(body.error)) return undefined;
    const details = body.error.details;
    if (!Array.isArray(details)) return undefined;
    for (const detail of details) {
      if (isRecord(detail) && typeof detail.errorCode === 'string') {
        return detail.errorCode;
      }
    }
  } catch {
    return undefined;
  }
  return undefined;
}

function validateCredentials(credentials: FcmCredentials): void {
  if (
    credentials.projectId.trim().length === 0 ||
    credentials.clientEmail.trim().length === 0 ||
    credentials.privateKey.trim().length === 0
  ) {
    throw new Error('FCM credentials are not configured');
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
