/** 소수 첫째 자리까지 표시하되 작은 값의 첫 유효숫자는 유지한다. */
export function formatWeatherNumber(value: number, keepDecimal = false): string {
  if (!Number.isFinite(value)) return '자료 없음';
  if (value === 0) return keepDecimal ? '0.0' : '0';
  let digits = 1;
  let scaled = Math.abs(value) * 10;
  while (scaled > 0 && scaled < 1 && digits < 20) {
    scaled *= 10;
    digits++;
  }
  const text = value.toFixed(digits);
  return !keepDecimal && text.includes('.') && !text.includes('e')
    ? text.replace(/0+$/, '').replace(/\.$/, '') : text;
}
