import {
  NotificationTarget,
  NotificationTopic,
} from './notificationDestination';
import { createGoogleAccessToken } from '../google/googleServiceAccount';

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

/** A silent, short-lived ownership proof; never a user-visible weather alert. */
export async function sendOwnershipChallenge(
  credentials: FcmCredentials,
  token: string,
  proof: { installationId: string; requestId: string; proof: string },
  dependencies: FcmClientDependencies = {},
): Promise<void> {
  validateCredentials(credentials);
  const fetcher = dependencies.fetcher ?? fetch;
  const accessToken = dependencies.accessTokenProvider
    ? await dependencies.accessTokenProvider()
    : await createGoogleAccessToken(credentials, FCM_SCOPE, fetcher,
        dependencies.now ?? Date.now);
  const response = await fetcher(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(credentials.projectId)}/messages:send`,
    {
      method: 'POST', signal: AbortSignal.timeout(10_000),
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: {
        token, data: { kind: 'installation_ownership', ...proof },
        android: { priority: 'normal', ttl: '60s' },
        apns: { headers: { 'apns-push-type': 'background', 'apns-priority': '5',
          'apns-expiration': `${Math.floor(Date.now() / 1000) + 60}` },
          payload: { aps: { 'content-available': 1 } } },
      } }),
    },
  );
  if (!response.ok) throw new Error('Ownership proof delivery failed');
  await response.body?.cancel();
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
    : await createGoogleAccessToken(credentials, FCM_SCOPE, fetcher,
        dependencies.now ?? Date.now);

  return Promise.all(
    payloads.map((payload) =>
      sendFcmMessage(fetcher, credentials.projectId, accessToken, payload),
    ),
  );
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
            body: sentenceLineBreaks(payload.body),
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

function sentenceLineBreaks(value: string): string {
  return value.replace(/([.!?])[\t ]+(?=\S)/g, '$1\n');
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
