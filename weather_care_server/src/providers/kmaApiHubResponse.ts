export function kmaApiHubErrorStatus(payload: string): number | undefined {
  return kmaApiHubError(payload)?.status;
}

export function kmaApiHubErrorReason(payload: string): string | undefined {
  const error = kmaApiHubError(payload);
  if (!error) return undefined;
  if (
    error.status === 429 ||
    /quota|rate\s*limit|limit(?:ed)?\s+exceed|일일\s*최대\s*호출|호출\s*용량\s*제한/i.test(
      error.message,
    )
  ) {
    return 'quota exceeded';
  }
  if (
    error.status === 401 ||
    /unauthori[sz]ed|forbidden|authorization|authentication|인증|권한/i.test(
      error.message,
    )
  ) {
    return 'authorization rejected';
  }
  return undefined;
}

function kmaApiHubError(
  payload: string,
): { status: number; message: string } | undefined {
  const trimmed = payload.trim();
  if (!trimmed.startsWith('{')) return undefined;

  try {
    const root = JSON.parse(trimmed) as unknown;
    if (root === null || typeof root !== 'object' || Array.isArray(root)) {
      return undefined;
    }
    const result = (root as Record<string, unknown>).result;
    if (result === null || typeof result !== 'object' || Array.isArray(result)) {
      return undefined;
    }
    const rawStatus = (result as Record<string, unknown>).status;
    const status = Number(rawStatus);
    if (!Number.isInteger(status) || status < 100 || status > 599) {
      return undefined;
    }
    const rawMessage = (result as Record<string, unknown>).message;
    return {
      status,
      message: typeof rawMessage === 'string' ? rawMessage : '',
    };
  } catch {
    return undefined;
  }
}
