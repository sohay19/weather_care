import { describe, expect, it } from 'vitest';
import { buildActiveWarningMessages } from '../src/presentation/officialWarningMessages';
import { OfficialWeatherWarning } from '../src/providers/warnings/kmaWarningProvider';

describe('official warning messages', () => {
  it('shows the direct action before the official fact', () => {
    const messages = buildActiveWarningMessages([warning('W', '강풍', '2')], '수원');

    expect(messages[0].parts).toEqual([
      expect.objectContaining({
        role: 'APP_SUGGESTION',
        text: '강풍특보가 발효 중이니, 야외활동을 줄이고 간판·수목·유리창·공사장 주변을 피하세요',
      }),
      expect.objectContaining({
        role: 'OFFICIAL_FACT',
        text: '수원에는 강풍주의보가 발효 중이에요',
      }),
    ]);
  });
});

function warning(
  typeCode: OfficialWeatherWarning['typeCode'],
  type: string,
  levelCode: OfficialWeatherWarning['levelCode'],
): OfficialWeatherWarning {
  return {
    typeCode,
    type,
    levelCode,
    level: levelCode === '2' ? '주의보' : '경보',
    commandCode: '1',
    regionId: 'L1011900',
    regionName: '수원',
    announcedAt: '2026-09-01T09:00:00+09:00',
    validFrom: '2026-09-01T10:00:00+09:00',
    provider: '기상청 특보현황',
  };
}
