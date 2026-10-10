import type { GridObservationSnapshot } from '../src/providers/weather/kmaGridObservationProvider';

export function observationSnapshot(at: string, temperature = 20, humidity = 60, windSpeed = 2): GridObservationSnapshot {
  return {
    observedAt: at,
    fields: Object.fromEntries(Object.entries({ T1H: temperature, REH: humidity, WSD: windSpeed })
      .map(([key, value]) => [key, { width: 149, height: 253, values: Array(149 * 253).fill(value) }])),
    requestedVariables: ['T1H', 'REH', 'WSD'],
  };
}
