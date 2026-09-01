import { AmountRange, WeatherSnapshot } from '../types';

const MAX_SLOT_GAP_MS = 90 * 60 * 1000;

export function snapshotTime(snapshot: WeatherSnapshot): string {
  return snapshot.forecastAt ?? snapshot.validFrom ?? snapshot.observedAt;
}

export function snapshotEnd(snapshot: WeatherSnapshot): string {
  if (snapshot.validTo) return snapshot.validTo;
  const end = new Date(Date.parse(snapshotTime(snapshot)) + 60 * 60 * 1000 - 1);
  return end.toISOString();
}

export function sortSnapshots(
  snapshots: WeatherSnapshot[],
): WeatherSnapshot[] {
  return [...snapshots].sort((left, right) =>
    snapshotTime(left).localeCompare(snapshotTime(right)),
  );
}

export function localHour(snapshot: WeatherSnapshot): number {
  return Number(snapshotTime(snapshot).slice(11, 13));
}

export function isDayWindow(snapshot: WeatherSnapshot): boolean {
  const hour = localHour(snapshot);
  return hour >= 10 && hour <= 16;
}

export function findRuns(
  snapshots: WeatherSnapshot[],
  predicate: (snapshot: WeatherSnapshot, index: number) => boolean,
  minimumLength: number,
): WeatherSnapshot[][] {
  const runs: WeatherSnapshot[][] = [];
  let current: WeatherSnapshot[] = [];

  snapshots.forEach((snapshot, index) => {
    const previous = current.at(-1);
    const adjacent =
      previous === undefined ||
      Date.parse(snapshotTime(snapshot)) - Date.parse(snapshotTime(previous)) <=
        MAX_SLOT_GAP_MS;
    if (predicate(snapshot, index) && adjacent) {
      current.push(snapshot);
      return;
    }
    if (current.length >= minimumLength) runs.push(current);
    current = predicate(snapshot, index) ? [snapshot] : [];
  });

  if (current.length >= minimumLength) runs.push(current);
  return runs;
}

export function findHysteresisRuns(
  snapshots: WeatherSnapshot[],
  trigger: (snapshot: WeatherSnapshot, index: number) => boolean,
  release: (snapshot: WeatherSnapshot, index: number) => boolean,
  minimumTriggerLength: number,
  releaseLength = 2,
): WeatherSnapshot[][] {
  const runs: WeatherSnapshot[][] = [];
  let pending: WeatherSnapshot[] = [];
  let active: WeatherSnapshot[] | undefined;
  let releaseCount = 0;

  snapshots.forEach((snapshot, index) => {
    if (!active) {
      if (trigger(snapshot, index)) {
        const previous = pending.at(-1);
        const adjacent =
          previous === undefined ||
          Date.parse(snapshotTime(snapshot)) -
              Date.parse(snapshotTime(previous)) <=
            MAX_SLOT_GAP_MS;
        pending = adjacent ? [...pending, snapshot] : [snapshot];
        if (pending.length >= minimumTriggerLength) {
          active = [...pending];
          pending = [];
        }
      } else {
        pending = [];
      }
      return;
    }

    if (trigger(snapshot, index)) {
      active.push(snapshot);
      releaseCount = 0;
      return;
    }
    if (release(snapshot, index)) {
      releaseCount += 1;
      if (releaseCount >= releaseLength) {
        runs.push(active);
        active = undefined;
        releaseCount = 0;
      }
      return;
    }
    releaseCount = 0;
  });

  if (active) runs.push(active);
  return runs;
}

export function amountMinimum(range?: AmountRange, legacy?: number): number {
  return range?.min ?? legacy ?? 0;
}

export function amountMaximum(range?: AmountRange, legacy?: number): number {
  return range?.max ?? range?.min ?? legacy ?? 0;
}

export function isKnownNoAmount(
  range?: AmountRange,
  legacy?: number,
): boolean {
  if (range) return range.type === 'NONE';
  return legacy === 0;
}

export function isWetSnapshot(snapshot: WeatherSnapshot): boolean {
  return (
    snapshot.precipitationType !== undefined &&
    snapshot.precipitationType !== 'NONE'
  ) || amountMinimum(
    snapshot.precipitationAmountRange,
    snapshot.precipitationAmount,
  ) > 0 || (snapshot.precipitationProbability ?? 0) >= 40;
}
