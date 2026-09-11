// Kept outside D1: restoring an old database must not reopen the service.
export function recoveryActive(mode: string | undefined): boolean {
  return mode !== undefined && mode !== 'off';
}

export function recoveryResponse(): Response {
  return Response.json({ error: 'SERVICE_RECOVERY', message: '서버 복구 작업 중이에요. 잠시 후 다시 시도해주세요.' }, {
    status: 503,
    headers: { 'Cache-Control': 'no-store', 'Retry-After': '300' },
  });
}
