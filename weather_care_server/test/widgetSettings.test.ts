import { describe, expect, it } from 'vitest';
import { defaultNotificationSettings } from '../src/database/notificationSettingsRepository';
import { withWidgetSettings } from '../src/api/weather';

describe('widget settings', () => {
  it('인증키 없이 전달된 로컬 준비물 설정만 적용한다', () => {
    const settings = withWidgetSettings(
      defaultNotificationSettings('anonymous'),
      'u1p0s1o0m1w0c1',
    );

    expect(settings).toMatchObject({
      umbrellaEnabled: true,
      parasolEnabled: false,
      heavySnowEnabled: true,
      outerwearEnabled: false,
      maskEnabled: true,
      waterEnabled: false,
      sunscreenEnabled: true,
    });
  });

  it('잘못된 값은 기본 설정을 바꾸지 않는다', () => {
    const original = defaultNotificationSettings('anonymous');
    expect(withWidgetSettings(original, 'invalid')).toBe(original);
  });
});
