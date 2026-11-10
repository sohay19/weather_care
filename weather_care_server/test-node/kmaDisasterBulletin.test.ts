import { describe, expect, it, vi } from 'vitest';
import {
  disasterBulletinMatchesRegion,
  fetchKmaDisasterBulletin,
  parseKmaDisasterBulletin,
} from '../src/providers/warnings/kmaDisasterBulletin';

const issuedAt = '202611100910';
const now = new Date('2026-11-10T09:20:00+09:00');
const sample = '<h3 class="tit">[기상청 속보]2026년 11월 10일 09시 10분</h3>' +
  '<div class="paragraph"><p class="tit"><안개 현황과 전망><br />' +
  '○ (현황) 경기동부와 강원 내륙에 안개가 낀 곳이 있음<br />' +
  '- 수도권: 장호원(이천) 90 포천 150<br />- 강원도: 고성 320<br />' +
  '○ (전망) 전북, 전남권내륙에는 안개가 끼는 곳이 있겠음<br />' +
  '○ (전망) 서울을 제외한 수도권에 안개가 끼는 곳이 있겠음</p></div>';

describe('날씨누리 방재속보', () => {
  it('명시한 시군과 도만 뽑고 관측표에서 같은 이름의 시군을 관할 권역으로 구분한다', () => {
    const bulletin = parseKmaDisasterBulletin(sample, issuedAt);
    expect(bulletin).toEqual({
      issuedAt, title: '안개 현황과 전망',
      regionCodes: ['4150000000', '4165000000', '5182000000', '5200000000'],
    });
    expect(disasterBulletinMatchesRegion(bulletin.regionCodes, '4150032000')).toBe(true);
    expect(disasterBulletinMatchesRegion(bulletin.regionCodes, '5211357500')).toBe(true);
    expect(disasterBulletinMatchesRegion(bulletin.regionCodes, '4882000000')).toBe(false);
    expect(disasterBulletinMatchesRegion(bulletin.regionCodes, '4111369000')).toBe(false);
    expect(disasterBulletinMatchesRegion(['4111000000'], '4111369000')).toBe(true);
    expect(disasterBulletinMatchesRegion(['S1311100'], 'S1311200')).toBe(false);
  });

  it('게시 중인 새 속보만 본문을 요청하고 동일 발표와 지난 속보의 재호출을 막는다', async () => {
    const fetcher = vi.fn<typeof fetch>()
      .mockImplementationOnce(async () => Response.json({ bangjaeExists: true, lastTmFc: issuedAt }))
      .mockImplementationOnce(async () => new Response(sample))
      .mockImplementation(async () => Response.json({ bangjaeExists: true, lastTmFc: issuedAt }));
    const first = await fetchKmaDisasterBulletin(now, null, fetcher);
    expect(first?.issuedAt).toBe(issuedAt);
    expect(await fetchKmaDisasterBulletin(now, first, fetcher)).toBe(first);
    expect(await fetchKmaDisasterBulletin(new Date('2026-11-10T10:00:00+09:00'), null, fetcher)).toBeNull();
    expect(fetcher).toHaveBeenCalledTimes(4);
    expect(fetcher.mock.calls.filter(([url]) => String(url).includes('bang-xml.do'))).toHaveLength(1);
  });

  it('목록 시각과 다른 본문은 발송 자료로 받아들이지 않는다', () => {
    expect(() => parseKmaDisasterBulletin(sample, '202611100920')).toThrow('KMA_DISASTER_BULLETIN_FORMAT_CHANGED');
  });
});
