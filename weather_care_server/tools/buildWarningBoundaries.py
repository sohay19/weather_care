"""기상청 공식 특보 지도·행정구역 설명을 UTF-8 런타임 자료로 고정한다."""
import argparse, base64, datetime, gzip, hashlib, json, math, re, struct
from pathlib import Path

URL = 'https://www.weather.go.kr/wgis-nuri/js/info/wrnArea.geojson'
PAGE = 'https://www.weather.go.kr/w/forecast/guide/wrn-area.do'

def normal(name):
    return re.sub(r'제(?=\d+(?:[.·]\d+)*동)', '', name).replace('ㆍ', '.').replace('·', '.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('descriptions', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    document = json.loads(raw)
    assert document['crs']['properties']['name'] == 'urn:ogc:def:crs:OGC:1.3:CRS84'
    features = [f for f in document['features'] if re.fullmatch(r'L\d{7}', f['properties']['regId'])]
    assert len(features) >= 250 and len({f['properties']['regId'] for f in features}) == len(features)
    zones = []
    for feature in features:
        assert feature['geometry']['type'] == 'MultiPolygon'
        rings = [ring for polygon in feature['geometry']['coordinates'] for ring in polygon]
        data = bytearray(struct.pack('<I', len(rings)))
        points = []
        for ring in rings:
            assert len(ring) >= 4 and ring[0] == ring[-1]
            data.extend(struct.pack('<I', len(ring)))
            for x, y in ring:
                assert math.isfinite(x) and math.isfinite(y) and 120 <= x <= 135 and 30 <= y <= 44
                points.append((x, y))
                data.extend(struct.pack('<dd', x, y))
        zones.append({'id': feature['properties']['regId'], 'name': feature['properties']['regKo'],
            'bounds': [min(p[0] for p in points), min(p[1] for p in points), max(p[0] for p in points), max(p[1] for p in points)],
            'geometry': base64.b64encode(gzip.compress(data, mtime=0)).decode()})

    server = Path(__file__).resolve().parent.parent
    catalog = [json.loads(line.strip().rstrip(',')) for line in (server/'src/regions/kmaAdministrativeAreas.ts').read_text(encoding='utf-8').splitlines() if line.strip().startswith('["')]
    description_source = args.descriptions.read_bytes()
    descriptions = json.loads(description_source)
    provinces = {109: ['서울특별시', '인천광역시', '경기도'], 159: ['부산광역시', '울산광역시', '경상남도'],
        143: ['대구광역시', '경상북도'], 156: ['전남광주통합특별시'], 146: ['전북특별자치도'],
        133: ['대전광역시', '세종특별자치시', '충청남도'], 131: ['충청북도'], 105: ['강원특별자치도'], 184: ['제주특별자치도']}
    # 설명에 명시한 행정단위만 연결한다. 고도·법정리·부분 구역 등은 추정하지 않는다.
    mappings = {}
    for feature in features:
        properties = feature['properties']
        aliases = {normal(properties[k]).replace(' ', '') for k in ['regko', 'regKo', 'regko_fullname']}
        rows = [row for row in descriptions if normal(row['name']).replace(' ', '') in aliases]
        for row in rows:
            description = normal(row['area'])
            if re.search(r'제외|산지 지역|중산간|미만|이상|일부|도서|동지역|동 지역|행정동|여서리|어청도리', description): continue
            candidates = [area for area in catalog if any(area[1].startswith(p + ' ') or area[1] == p for p in provinces[row['stn']])]
            # 동명 읍면동은 특보 이름의 시군 계층으로 구분한다.
            scope = []
            for area in candidates:
                if not area[0].endswith('00000'): continue
                short = re.sub(r'(특별자치도|특별자치시|광역시|특별시|시|군)$', '', area[1].split(' ')[-1])
                if len(short) >= 2 and properties['regKo'].startswith(short): scope.append(area[1])
            if scope:
                longest = max(map(len, scope))
                scope = [name for name in scope if len(name) == longest]
                candidates = [area for area in candidates if any(area[1] == name or area[1].startswith(name + ' ') for name in scope)]
            tokens = re.findall(r'[가-힣0-9]+', description)
            units = [t for t in tokens if t.endswith(('읍','면','동','구','시','군','도'))]
            if not units: continue
            rank = lambda t: 3 if t.endswith(('읍','면','동')) else 2 if t.endswith('구') else 1 if t.endswith(('시','군')) else 0
            level = max(map(rank, units))
            units = [unit for unit in units if rank(unit) == level]
            for unit in units:
                matches = [area for area in candidates if unit in normal(area[1]).split(' ')]
                # 상위 계층 없이 같은 읍면동 이름이 여러 시군에 있으면 제외한다.
                if not scope and len({area[1].split(' ')[1] for area in matches if ' ' in area[1]}) > 1 and level >= 2: continue
                for area in matches:
                    mappings.setdefault(area[0], set()).add(properties['regId'])
    result = {'source': URL, 'administrativeSource': PAGE,
        'sourceSha256': hashlib.sha256(raw).hexdigest(),
        'administrativeSourceSha256': hashlib.sha256(description_source).hexdigest(),
        'retrievedDate': datetime.date.today().isoformat(),
        'zones': zones, 'administrativeRegions': {code: sorted(ids) for code, ids in sorted(mappings.items())}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')
    print(json.dumps({'zones':len(zones),'administrativeRegions':len(mappings),'bytes':args.output.stat().st_size}))

if __name__ == '__main__': main()
