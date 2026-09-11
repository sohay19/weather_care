import { describe, expect, it } from 'vitest';
import { providerErrorDiagnostic } from '../src/observability/providerErrorDiagnostics';

describe('provider error diagnostics', () => {
  it('does not trust mutable error names or nested cause fields', () => {
    const error = Object.assign(new Error('token-secret', { cause: 'location-secret' }), {
      name: 'https://example.invalid/?key=secret',
      stack: 'private-stack',
    });
    expect(providerErrorDiagnostic(error)).toEqual({ error: 'Error', failureReason: 'UNKNOWN' });
  });
  it('classifies safe HTTP and provider operation fields', () => {
    expect(
      providerErrorDiagnostic(
        new Error('KMA radar request failed with status 403'),
      ),
    ).toEqual({
      error: 'Error',
      failureReason: 'AUTHORIZATION_FAILED',
      httpStatus: 403,
      operation: 'RADAR',
    });
  });

  it('classifies network and invalid-response failures', () => {
    expect(providerErrorDiagnostic(new TypeError('fetch failed'))).toEqual({
      error: 'TypeError',
      failureReason: 'NETWORK_ERROR',
    });
    expect(
      providerErrorDiagnostic(
        new Error('KMA warning response has an unknown format'),
      ),
    ).toEqual({
      error: 'Error',
      failureReason: 'INVALID_RESPONSE',
      operation: 'WARNING',
    });
  });

  it('never copies an error message or secret into the diagnostic', () => {
    const secret = 'top-secret-api-key';
    const diagnostic = providerErrorDiagnostic(
      new Error(`authorization failed for ${secret}`),
    );
    const serialized = JSON.stringify(diagnostic);

    expect(diagnostic.failureReason).toBe('AUTHORIZATION_FAILED');
    expect(serialized).not.toContain(secret);
    expect(serialized).not.toContain('message');
  });

  it('allows only fixed provider detail codes', () => {
    const safe = Object.assign(new Error('safe'), {
      providerFailureDetail: 'ANALYSIS_TARGET_TIME_MISSING',
    });
    const unsafe = Object.assign(new Error('unsafe'), {
      providerFailureDetail: 'secret-value',
    });

    expect(providerErrorDiagnostic(safe).detail).toBe(
      'ANALYSIS_TARGET_TIME_MISSING',
    );
    expect(providerErrorDiagnostic(unsafe)).not.toHaveProperty('detail');
  });
});
