import { describe, expect, it } from 'vitest';
import { assessPipeFreeze, pipeFreezeMessage } from '../src/services/pipeFreezeAdvice';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';

const now = new Date('2026-12-01T07:00:00+09:00');
function forecast(temperatures: number[]): WeatherForecast {
  const hourly = temperatures.map((temperature, hour) => ({
    observedAt: new Date(now.getTime() + hour * 3_600_000).toISOString(),
    forecastAt: new Date(now.getTime() + hour * 3_600_000).toISOString(),
    issuedAt: '2026-12-01T05:00:00+09:00', temperature, apparentTemperature: -50,
  }));
  return { current: hourly[0], hourly, daily: [], baseDate: '20261201', baseTime: '0500', dataSource: '기상청' };
}

describe('수도관 동파 대비 참고 판단', () => {
  it.each([[-5, 'CHECK'], [-5.1, 'CAUTION'], [-10, 'CAUTION'], [-10.1, 'WARNING'],
    [-15, 'WARNING'], [-15.1, 'DANGER']] as const)('최저 %s℃ 경계와 48시간 자료를 적용한다', (temperature, level) => {
    const result = assessPipeFreeze(forecast(Array(48).fill(temperature)), now);
    expect(result).toMatchObject({ status: 'AVAILABLE', level, minimumTemperature: temperature, availableHours: 48 });
    expect(Date.parse(result.validUntil)).toBe(now.getTime() + 3_600_000);
  });

  it('양쪽 24시간 최저를 확인하고 단 하루의 강추위를 이틀로 만들지 않는다', () => {
    const temperatures = Array(48).fill(5);
    temperatures[1] = -20;
    expect(assessPipeFreeze(forecast(temperatures), now).level).toBe('CAUTION');
    temperatures[26] = -20;
    const result = assessPipeFreeze(forecast(temperatures), now);
    expect(result.level).toBe('DANGER');
    expect(result.freezingHours).toBe(1);
    const message = pipeFreezeMessage(result, '시험 지역', now);
    expect(message.title).toContain('심각');
    expect(message.parts.some((part) => part.text.includes('공식 동파 예보·발생 확률이 아니며'))).toBe(true);
    expect(message.parts.some((part) => part.text.includes('시험 지역'))).toBe(true);
  });

  it('결측·부분 예보는 낮은 위험으로 채우거나 연속 기간으로 잇지 않는다', () => {
    const input = forecast(Array(48).fill(-20));
    input.hourly.splice(24, 1);
    const result = assessPipeFreeze(input, now);
    expect(result).toMatchObject({ status: 'PARTIAL', availableHours: 47, freezingHours: 24 });
    expect(result.level).toBeUndefined();
    expect(pipeFreezeMessage(result, '지역', now).parts.some((part) => part.role === 'DATA_STATUS')).toBe(true);
    expect(assessPipeFreeze(forecast(Array(24).fill(-20)), now).level).toBeUndefined();
  });

  it('오래된·미래 발표와 관측·잘못된 기온을 예보 자료로 사용하지 않는다', () => {
    for (const issuedAt of ['2026-11-30T23:00:00+09:00', '2026-12-01T08:00:00+09:00', 'invalid']) {
      const input = forecast(Array(48).fill(-20));
      input.hourly.forEach((item) => { item.issuedAt = issuedAt; });
      expect(assessPipeFreeze(input, now)).toMatchObject({ status: 'UNAVAILABLE', availableHours: 0 });
    }
    const input = forecast(Array(48).fill(-20));
    input.hourly[0].dataRole = 'OBSERVATION';
    input.hourly[1].temperature = NaN;
    input.hourly[2].temperature = -999;
    input.hourly.push(input.hourly[3]);
    expect(assessPipeFreeze(input, now).availableHours).toBe(45);
  });

  it('체감온도를 사용하지 않고 기온이 회복된 새 예보는 단계도 해제한다', () => {
    expect(assessPipeFreeze(forecast(Array(48).fill(-20)), now).level).toBe('DANGER');
    const result = assessPipeFreeze(forecast(Array(48).fill(10)), now);
    expect(result.level).toBe('CHECK');
    expect(result.freezingHours).toBe(0);
    expect(result.minimumTemperature).toBe(10);
  });

  it('정각 30분 뒤 잘린 현재 시각은 당일 타임라인의 유효한 예보로 보완한다', () => {
    const input = forecast(Array(48).fill(-12));
    input.timelineHourly = [input.hourly.shift()!];
    const result = assessPipeFreeze(input, new Date(now.getTime() + 40 * 60_000));
    expect(result).toMatchObject({status:'AVAILABLE', availableHours:48,level:'WARNING'});
  });
});
