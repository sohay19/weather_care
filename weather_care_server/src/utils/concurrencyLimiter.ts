export type AsyncLimiter = <T>(task: () => Promise<T>) => Promise<T>;

export function createAsyncLimiter(maxConcurrency: number): AsyncLimiter {
  if (!Number.isInteger(maxConcurrency) || maxConcurrency < 1) {
    throw new RangeError('maxConcurrency must be a positive integer');
  }
  let active = 0;
  const queue: Array<() => void> = [];

  const drain = () => {
    while (active < maxConcurrency) {
      const start = queue.shift();
      if (!start) return;
      active += 1;
      start();
    }
  };

  return <T>(task: () => Promise<T>) =>
    new Promise<T>((resolve, reject) => {
      queue.push(() => {
        void Promise.resolve()
          .then(task)
          .then(resolve, reject)
          .finally(() => {
            active -= 1;
            drain();
          });
      });
      drain();
    });
}

export async function mapWithConcurrency<T, R>(
  values: readonly T[],
  maxConcurrency: number,
  mapper: (value: T, index: number) => Promise<R>,
): Promise<R[]> {
  const limit = createAsyncLimiter(maxConcurrency);
  return Promise.all(values.map((value, index) =>
    limit(() => mapper(value, index)),
  ));
}
