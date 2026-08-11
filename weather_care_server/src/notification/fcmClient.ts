import { BuiltNotification } from './notificationBuilder';

export interface FcmPayload {
  token: string;
  title: string;
  body: string;
}

export async function sendPush(_token: string, _payload: BuiltNotification): Promise<void> {
  // TODO: FCM HTTP v1 연동
  return;
}

export async function sendBatch(_payloads: { token: string; title: string; body: string }[]): Promise<void> {
  // TODO: 실제 전송 API 호출
  return;
}

