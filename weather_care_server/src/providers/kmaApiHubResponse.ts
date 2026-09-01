export function kmaApiHubErrorStatus(payload: string): number | undefined {
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
    return Number.isInteger(status) && status >= 100 && status <= 599
      ? status
      : undefined;
  } catch {
    return undefined;
  }
}
