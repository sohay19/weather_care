const MAX_ERROR_BODY_LENGTH = 32_768;

export async function providerHttpFailureMessage(
  response: Response,
  label: string,
  body?: string,
): Promise<string> {
  const errorBody = body ?? await readErrorBody(response);
  const detail = normalizedFailureDetail(errorBody, response.status);
  return `${label} failed with status ${response.status}${
    detail === undefined ? '' : `: ${detail}`
  }`;
}

async function readErrorBody(response: Response): Promise<string> {
  try {
    const contentLength = Number(response.headers.get('content-length'));
    if (Number.isFinite(contentLength) && contentLength > MAX_ERROR_BODY_LENGTH) {
      await response.body?.cancel();
      return '';
    }
    const body = await response.text();
    return body.slice(0, MAX_ERROR_BODY_LENGTH);
  } catch {
    try {
      await response.body?.cancel();
    } catch {
      // The response may already be closed. The original HTTP status remains useful.
    }
    return '';
  }
}

function normalizedFailureDetail(
  body: string,
  status: number,
): string | undefined {
  if (/quota|일일\s*최대\s*호출|호출\s*용량\s*제한/i.test(body)) {
    return 'quota exceeded';
  }
  if (status === 429 || /rate\s*limit|limit(?:ed)?\s+exceed/i.test(body)) {
    return 'rate limited';
  }
  if (
    status === 401 ||
    /unauthori[sz]ed|forbidden|authorization|authentication|인증|권한/i.test(body)
  ) {
    return 'authorization rejected';
  }
  return undefined;
}
