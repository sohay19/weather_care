"""SGIS 원본을 손실 없는 WGS84 링과 검증된 기상청 코드로 변환한다.

출처: 통계청 SGIS 센서스용 행정구역경계·행정구역 코드집(2025년 2분기).
경계 단순화/근접 동 배정 없음. 런타임은 Python/GIS 라이브러리를 사용하지 않는다.
"""
import argparse
import base64
from collections import Counter
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import re
import struct
import zipfile

import numpy as np
import pyproj
import shapefile
from shapely.geometry import Point, Polygon, shape
from shapely.ops import unary_union
from shapely.strtree import STRtree
import xlrd

REVISION = 1
SOURCES = [
    'https://sgis.mods.go.kr/view/pss/dataProvdIntrcn',
    'https://isel.seo.incheon.kr/open_content/main/open_info/boundary/faq.jsp',
    'https://www.hscity.go.kr/office/intro.jsp',
]


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def norm(name):
    name = re.sub(r'^(광주광역시|전라남도|전남)(?=\s|$)', '전남광주통합특별시', name)
    name = re.sub(r'세종(특별자치시|시)', '세종', name)
    name = re.sub(r'특별자치도|특별자치시|특별시|광역시', '', name)
    for a, b in [('경기도', '경기'), ('강원도', '강원'), ('충청남도', '충남'),
                 ('충청북도', '충북'), ('전라남도', '전남'), ('전라북도', '전북'),
                 ('경상남도', '경남'), ('경상북도', '경북')]:
        name = name.replace(a, b)
    name = re.sub(r'제(\d+[.·ㆍ\d]*동)', lambda m: m[0] if re.search(r'(거|홍)$', name[:m.start()]) else m[1], name)
    return re.sub(r'[\s,.·ㆍ]', '', name)


def revised_name(name):
    # 2026 개편: 공식 구별 구성 동 안내와 현재 기상청 목록을 함께 대조한다.
    if name.startswith('인천광역시 '):
        _, city, dong = name.split(' ', 2)
        if city == '동구':
            city = '제물포구'
        elif city == '중구':
            city = '영종구' if dong in ('영종동', '영종1동', '영종2동', '운서동', '운서1동', '운서2동', '용유동', '운남동') else '제물포구'
        elif city == '서구':
            south = {'검암경서동', '연희동', '청라1동', '청라2동', '청라3동', '가정1동', '가정2동', '가정3동',
                     '신현원창동', '석남1동', '석남2동', '석남3동', '가좌1동', '가좌2동', '가좌3동', '가좌4동'}
            north = {'검단동', '불로대곡동', '오류왕길동', '당하동', '마전동', '원당동', '아라동', '아라1동', '아라2동'}
            if dong in south:
                city = '서해구'
            elif dong in north:
                city = '검단구'
        return f'인천광역시 {city} {dong}'
    if name.startswith('경기도 화성시 '):
        dong = name.split(' ', 2)[2]
        districts = {
            '만세구': {'우정읍', '향남읍', '남양읍', '마도면', '송산면', '서신면', '팔탄면', '장안면', '양감면', '새솔동'},
            '효행구': {'봉담읍', '매송면', '비봉면', '정남면', '기배동'},
            '병점구': {'진안동', '병점1동', '병점2동', '반월동', '화산동'},
            '동탄구': {f'동탄{i}동' for i in range(1, 10)},
        }
        for district, members in districts.items():
            if dong in members:
                return f'경기도 화성시 {district} {dong}'
    return name


def grid_point(nx, ny):
    r = math.pi / 180
    radius = 6371.00877 / 5
    a, b = 30 * r, 60 * r
    sn = math.log(math.cos(a) / math.cos(b)) / math.log(math.tan(math.pi / 4 + b / 2) / math.tan(math.pi / 4 + a / 2))
    sf = math.tan(math.pi / 4 + a / 2) ** sn * math.cos(a) / sn
    ro = radius * sf / math.tan(math.pi / 4 + 38 * r / 2) ** sn
    x, y = nx - 43, ro - ny + 136
    latitude = (2 * math.atan((radius * sf / math.hypot(x, y)) ** (1 / sn)) - math.pi / 2) / r
    longitude = math.atan2(x, y) / sn / r + 126
    return longitude, latitude


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--boundaries', required=True, type=Path)
    parser.add_argument('--codebook', required=True, type=Path)
    parser.add_argument('--catalog', type=Path, default=Path(__file__).resolve().parents[1] / 'src/regions/kmaAdministrativeAreas.ts')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    areas = json.loads(re.sub(r',\s*]', ']', '[' + args.catalog.read_text('utf-8').split('= [', 1)[1].rsplit('];', 1)[0] + ']'))
    # Git의 CRLF/LF 차이가 배포 시 코드표 검증을 깨지 않도록 내용 자체를 해시한다.
    catalog_hash = hashlib.sha256(json.dumps(areas, ensure_ascii=False, separators=(',', ':')).encode('utf-8')).hexdigest()
    source_hashes = {'boundaries': sha(args.boundaries), 'codebook': sha(args.codebook), 'catalog': catalog_hash}
    version = hashlib.sha256(json.dumps([REVISION, source_hashes], sort_keys=True).encode()).hexdigest()
    names = {}
    for area in areas:
        names.setdefault(norm(area[1]), []).append(area)

    def find_area(full_name):
        parts = revised_name(full_name).split()
        while parts:
            matches = names.get(norm(' '.join(parts)), [])
            if len(matches) == 1:
                return matches[0]
            top = [a for a in matches if a[0].endswith('00000000')]
            if len(top) == 1:
                return top[0]
            parts.pop()
        return None

    with zipfile.ZipFile(args.codebook) as book_zip:
        workbook = xlrd.open_workbook(file_contents=book_zip.read(next(n for n in book_zip.namelist() if '(adm_code).xls' in n)))
        sheet = workbook.sheet_by_index(0)
        if sheet.name != '2025년 6월':
            raise ValueError('CODEBOOK_VERSION_MISMATCH')
        code_names = {}
        for cells in list(sheet.get_rows())[2:]:
            values = [c.value for c in cells]
            code = ''.join(str(int(v)).zfill(n) if isinstance(v, (float, int)) else v.zfill(n)
                           for v, n in [(values[0], 2), (values[2], 3), (values[4], 3)])
            if code in code_names:
                raise ValueError('CODEBOOK_DUPLICATE')
            code_names[code] = ' '.join([values[1], values[3], values[5]])

    features, discrepancies = [], []
    with zipfile.ZipFile(args.boundaries) as outer:
        with zipfile.ZipFile(io.BytesIO(outer.read('bnd_dong_00_2025_2Q.zip'))) as data:
            base = 'bnd_dong_00_2025_2Q'
            crs = pyproj.CRS.from_wkt(data.read(base + '.prj').decode())
            if crs.to_epsg() != 5179 or data.read(base + '.cpg').decode().strip().upper() != 'UTF-8':
                raise ValueError('BOUNDARY_CRS_OR_ENCODING_MISMATCH')
            to_gps = pyproj.Transformer.from_crs(crs, 4326, always_xy=True)
            to_source = pyproj.Transformer.from_crs(4326, crs, always_xy=True)
            reader = shapefile.Reader(shp=io.BytesIO(data.read(base + '.shp')), dbf=io.BytesIO(data.read(base + '.dbf')), encoding='utf-8')
            if len(reader) != 3559:
                raise ValueError('BOUNDARY_COUNT_MISMATCH')
            for record in reader.iterShapeRecords():
                code, dong = record.record['ADM_CD'], record.record['ADM_NM']
                if record.record['BASE_DATE'] != '20250630' or not re.fullmatch(r'\d{8}', code):
                    raise ValueError('BOUNDARY_VERSION_OR_CODE_MISMATCH')
                source_name = code_names.get(code)
                if not source_name or norm(source_name.split()[-1]) != norm(dong):
                    parents = {' '.join(v.split()[:-1]) for k, v in code_names.items() if k[:5] == code[:5]}
                    if len(parents) != 1:
                        raise ValueError('CODEBOOK_PARENT_MISMATCH')
                    source_name = next(iter(parents)) + ' ' + dong
                    discrepancies.append({'sgisCode': code, 'sourceName': source_name})
                geom = shape(record.shape.__geo_interface__)
                if not geom.is_valid or geom.is_empty or geom.geom_type not in ('Polygon', 'MultiPolygon'):
                    raise ValueError('BOUNDARY_INVALID')
                area = find_area(source_name)
                precision = 'DONG' if area and not area[0].endswith('00000') else 'PARENT' if area else 'UNMAPPED'
                xy = np.asarray(record.shape.points, dtype=np.float64)
                lon, lat = to_gps.transform(xy[:, 0], xy[:, 1])
                xy = np.column_stack((lon, lat)).astype('<f8')
                cuts = list(record.shape.parts) + [len(xy)]
                raw = bytearray(struct.pack('<I', len(cuts) - 1))
                for start, end in zip(cuts, cuts[1:]):
                    ring = xy[start:end]
                    if len(ring) < 4 or not np.array_equal(ring[0], ring[-1]):
                        raise ValueError('BOUNDARY_RING_NOT_CLOSED')
                    raw.extend(struct.pack('<I', len(ring)))
                    raw.extend(ring.tobytes())
                entry = {'type': 'feature', 'sgisCode': code, 'sourceName': source_name, 'kmaCode': area[0] if area else None,
                         'precision': precision, 'bbox': [float(lon.min()), float(lat.min()), float(lon.max()), float(lat.max())],
                         'geometry': base64.b64encode(gzip.compress(raw, compresslevel=6, mtime=0)).decode('ascii')}
                point = geom.representative_point()
                gps = to_gps.transform(point.x, point.y)
                features.append({'entry': entry, 'geom': geom, 'area': area, 'areaName': norm(area[1]) if area else '', 'sample': {'longitude': gps[0], 'latitude': gps[1]}})

    tree = STRtree([f['geom'] for f in features])

    def at_point(lon, lat):
        p = Point(*to_source.transform(lon, lat))
        return [features[int(i)] for i in tree.query(p) if features[int(i)]['geom'].covers(p)]

    parents = sorted([(a, norm(a[1])) for a in areas if a[0].endswith('00000')], key=lambda a: len(a[1]), reverse=True)

    def common_parent(found):
        if not found or any(not f['area'] for f in found):
            return None
        return next((a for a, name in parents if all(f['areaName'].startswith(name) for f in found)), None)

    grids, unresolved = {}, []
    for area in areas:
        grids.setdefault((area[2], area[3]), []).append(area)
    for key, members in grids.items():
        if len([a for a in members if not a[0].endswith('00000')]) != 1:
            unresolved.append(key)
    grid_rows, land_samples = [], []
    # 격자 전체를 경계가 덮을 때만 상위 참고지역 저장. 경계·해안은 중심점으로 추정하지 않는다.
    for ny in range(1, 254):
        for nx in range(1, 150):
            center = Point(*to_source.transform(*grid_point(nx, ny)))
            if not len(tree.query(center)) and (nx, ny) not in unresolved:
                continue
            edge = []
            for start, end in [((-0.5, -0.5), (0.5, -0.5)), ((0.5, -0.5), (0.5, 0.5)), ((0.5, 0.5), (-0.5, 0.5)), ((-0.5, 0.5), (-0.5, -0.5))]:
                for i in range(16):
                    x = nx + start[0] + (end[0] - start[0]) * i / 16
                    y = ny + start[1] + (end[1] - start[1]) * i / 16
                    edge.append(to_source.transform(*grid_point(x, y)))
            # 곡선 변환의 근사 오차보다 큰 1m 여유로 보수적으로 포함을 검사한다.
            cell = Polygon(edge).buffer(1)
            found = [features[int(i)] for i in tree.query(cell) if features[int(i)]['geom'].intersects(cell)]
            if (nx, ny) in unresolved:
                # 중심이 바다인 격자도 실제 육지 부분의 GPS를 별도로 검증한다.
                for f in found:
                    intersection = f['geom'].intersection(Polygon(edge))
                    if not intersection.is_empty and intersection.area > 1:
                        sample = intersection.representative_point()
                        lon, lat = to_gps.transform(sample.x, sample.y)
                        land_samples.append({'nx': nx, 'ny': ny, 'sgisCode': f['entry']['sgisCode'], 'kmaCode': f['entry']['kmaCode'],
                                             'precision': f['entry']['precision'], 'sample': {'longitude': lon, 'latitude': lat}})
            parent = common_parent(found)
            if parent and unary_union([f['geom'] for f in found]).covers(cell):
                grid_rows.append({'type': 'grid', 'nx': nx, 'ny': ny, 'kmaCode': parent[0]})

    center_results = []
    for nx, ny in unresolved:
        lon, lat = grid_point(nx, ny)
        found = at_point(lon, lat)
        precision = 'OUTSIDE' if not found else 'UNMAPPED' if any(not f['area'] for f in found) else 'DONG' if len(found) == 1 and found[0]['entry']['precision'] == 'DONG' else 'PARENT'
        center_results.append({'nx': nx, 'ny': ny, 'precision': precision, 'codes': [f['entry']['kmaCode'] for f in found]})
    counts = Counter(f['entry']['precision'] for f in features)
    manifest = {'type': 'manifest', 'format': 1, 'builderRevision': REVISION, 'version': version, 'sourceDate': '2025-06-30',
                'source': '통계청 SGIS 센서스용 행정구역경계(2025년 2분기)·행정구역 코드집', 'sources': SOURCES,
                'sourceSha256': source_hashes, 'catalogSha256': catalog_hash, 'featureCount': len(features), 'gridCount': len(grid_rows),
                'precisionCounts': {key: counts[key] for key in ['DONG', 'PARENT', 'UNMAPPED']}, 'codebookDiscrepancies': discrepancies}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    staging = args.output.with_suffix(args.output.suffix + '.tmp')
    digest = hashlib.sha256()
    with gzip.open(staging, 'wt', encoding='utf-8', newline='\n') as target:
        target.write(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n')
        for entry in [f['entry'] for f in features] + grid_rows:
            line = json.dumps(entry, ensure_ascii=False, separators=(',', ':')) + '\n'
            digest.update(line.encode('utf-8'))
            target.write(line)
        target.write(json.dumps({'type': 'complete', 'sha256': digest.hexdigest()}) + '\n')
    staging.replace(args.output)
    audit = {'manifest': manifest, 'artifactSha256': sha(args.output), 'artifactBytes': args.output.stat().st_size,
             'centerSummary': dict(Counter(r['precision'] for r in center_results)), 'centers': center_results,
             'features': [{'sgisCode': f['entry']['sgisCode'], 'kmaCode': f['entry']['kmaCode'], 'precision': f['entry']['precision'],
                           'sourceName': f['entry']['sourceName'], 'sample': f['sample']} for f in features],
             'points': {name: [{'sgisCode': f['entry']['sgisCode'], 'kmaCode': f['entry']['kmaCode'], 'precision': f['entry']['precision'], 'name': f['area'][1] if f['area'] else None}
                               for f in at_point(lon, lat)] for name, lon, lat in [('travel', 127.660949, 37.697249), ('bank', 126.803, 37.434)]},
             'unresolvedGridReferences': [r for r in grid_rows if (r['nx'], r['ny']) in unresolved]}
    audit['landSamples'] = land_samples
    args.output.with_suffix('.audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2), 'utf-8')
    print(json.dumps({k: audit[k] for k in ['artifactBytes', 'centerSummary', 'points']}, ensure_ascii=True), flush=True)
    print(json.dumps(manifest, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    main()
