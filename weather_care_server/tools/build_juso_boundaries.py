"""2026년 월전체분 '구역의 도형' 행정동을 서버 경계 자료로 변환한다.

입력은 시·도별 ZIP 16개다. 원본 링은 단순화하지 않고 보존한다.
자료에는 PRJ가 없으므로 EPSG:5179를 사용하며 알려진 국내 좌표와 범위를 검증한다.
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
from shapely import make_valid
from shapely.geometry import Point, Polygon, shape
from shapely.ops import unary_union
from shapely.strtree import STRtree

from build_administrative_boundaries import grid_point, norm, sha

REVISION = 2
SOURCE_MONTH = '2026-09'
EXPECTED_ARCHIVES = 16
EXPECTED_FEATURES = 3564
EXPECTED_FIELDS = ['EMD_CD', 'EMD_KOR_NM', 'EMD_ENG_NM']


def source_hash(archives):
    hashes = {path.name: sha(path) for path in archives}
    return hashlib.sha256(json.dumps(hashes, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode('utf-8')).hexdigest(), hashes


def source_shapes(directory):
    archives = sorted(directory.glob('구역의도형_전체분_*.zip'))
    if len(archives) != EXPECTED_ARCHIVES:
        raise ValueError('JUSO_ARCHIVE_COUNT_MISMATCH')
    for archive in archives:
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip():
                raise ValueError('JUSO_ARCHIVE_CRC_MISMATCH')
            bases = [name[:-4] for name in bundle.namelist() if name.endswith('/TL_SCCO_GEMD.shp')]
            if len(bases) != 1:
                raise ValueError('JUSO_GEMD_MISSING')
            base = bases[0]
            if not all(base + ext in bundle.namelist() for ext in ('.shp', '.shx', '.dbf')):
                raise ValueError('JUSO_GEMD_PART_MISSING')
            reader = shapefile.Reader(shp=io.BytesIO(bundle.read(base + '.shp')),
                                      shx=io.BytesIO(bundle.read(base + '.shx')),
                                      dbf=io.BytesIO(bundle.read(base + '.dbf')), encoding='cp949')
            if [field[0] for field in reader.fields[1:]] != EXPECTED_FIELDS:
                raise ValueError('JUSO_GEMD_FIELDS_CHANGED')
            for record in reader.iterShapeRecords():
                code = record.record['EMD_CD'].strip()
                name = record.record['EMD_KOR_NM'].strip()
                if not re.fullmatch(r'\d{10}', code) or not name or code[:2] != base[:2]:
                    raise ValueError('JUSO_GEMD_CODE_INVALID')
                yield code, name, record.shape


def valid_polygon(raw):
    geometry = shape(raw.__geo_interface__)
    if geometry.is_empty:
        raise ValueError('JUSO_GEOMETRY_EMPTY')
    if geometry.is_valid:
        return geometry, False
    repaired = make_valid(geometry)
    polygons = [part for part in (repaired.geoms if hasattr(repaired, 'geoms') else [repaired])
                if part.geom_type in ('Polygon', 'MultiPolygon')]
    if not polygons:
        raise ValueError('JUSO_GEOMETRY_UNREPAIRABLE')
    result = unary_union(polygons)
    if result.is_empty or not result.is_valid or abs(result.area - geometry.area) > 1:
        raise ValueError('JUSO_GEOMETRY_REPAIR_CHANGED_AREA')
    return result, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--boundaries-dir', type=Path, required=True)
    parser.add_argument('--catalog', type=Path, default=Path(__file__).resolve().parents[1] / 'src/regions/kmaAdministrativeAreas.ts')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    archives = sorted(args.boundaries_dir.glob('구역의도형_전체분_*.zip'))
    boundaries_hash, archive_hashes = source_hash(archives)
    areas = json.loads(re.sub(r',\s*]', ']', '[' + args.catalog.read_text('utf-8').split('= [', 1)[1].rsplit('];', 1)[0] + ']'))
    catalog_hash = hashlib.sha256(json.dumps(areas, ensure_ascii=False, separators=(',', ':')).encode('utf-8')).hexdigest()
    area_by_code = {area[0]: area for area in areas}
    source_hashes = {'boundaries': boundaries_hash, 'catalog': catalog_hash}
    version = hashlib.sha256(json.dumps([REVISION, source_hashes], sort_keys=True).encode()).hexdigest()
    to_gps = pyproj.Transformer.from_crs(5179, 4326, always_xy=True)
    to_source = pyproj.Transformer.from_crs(4326, 5179, always_xy=True)
    features, unmapped, renamed = [], [], []
    seen = set()
    repaired_count = 0

    for code, name, raw_shape in source_shapes(args.boundaries_dir):
        if code in seen:
            raise ValueError('JUSO_GEMD_DUPLICATE')
        seen.add(code)
        geometry, repaired = valid_polygon(raw_shape)
        repaired_count += repaired
        area = area_by_code.get(code)
        if not area:
            area = area_by_code.get(code[:5] + '00000')
            if not area:
                unmapped.append({'code': code, 'name': name})
        elif norm(name) != norm(area[1].split()[-1]):
            renamed.append({'code': code, 'sourceName': name, 'catalogName': area[1]})
        precision = 'DONG' if area and area[0] == code else 'PARENT' if area else 'UNMAPPED'
        source_name = f'{area[1].rsplit(" ", 1)[0]} {name}' if precision == 'DONG' else f'{area[1]} {name}' if area else name
        points = np.asarray(raw_shape.points, dtype=np.float64)
        lon, lat = to_gps.transform(points[:, 0], points[:, 1])
        if not np.isfinite(lon).all() or not np.isfinite(lat).all() or lon.min() < 124 or lon.max() > 132 or lat.min() < 32 or lat.max() > 40:
            raise ValueError('JUSO_CRS_OR_COORDINATES_INVALID')
        xy = np.column_stack((lon, lat)).astype('<f8')
        cuts = list(raw_shape.parts) + [len(xy)]
        encoded = bytearray(struct.pack('<I', len(cuts) - 1))
        for start, end in zip(cuts, cuts[1:]):
            ring = xy[start:end]
            if len(ring) < 4 or not np.array_equal(ring[0], ring[-1]):
                raise ValueError('JUSO_RING_NOT_CLOSED')
            encoded.extend(struct.pack('<I', len(ring)))
            encoded.extend(ring.tobytes())
        entry = {'type': 'feature', 'sgisCode': code, 'sourceName': source_name,
                 'kmaCode': area[0] if area else None, 'precision': precision,
                 'bbox': [float(lon.min()), float(lat.min()), float(lon.max()), float(lat.max())],
                 'geometry': base64.b64encode(gzip.compress(encoded, compresslevel=6, mtime=0)).decode('ascii')}
        sample = geometry.representative_point()
        sample_lon, sample_lat = to_gps.transform(sample.x, sample.y)
        features.append({'entry': entry, 'geom': geometry, 'area': area,
                         'areaName': norm(area[1]) if area else '',
                         'sample': {'longitude': sample_lon, 'latitude': sample_lat}})

    if len(features) != EXPECTED_FEATURES or unmapped:
        raise ValueError(f'JUSO_FEATURES_OR_CODES_CHANGED: {len(features)} / {len(unmapped)}')
    # EPSG:5179 확인: 시흥시 은행동의 알려진 GPS 점이 해당 원본 도형 안에 있어야 한다.
    bank = next(feature for feature in features if feature['entry']['sgisCode'] == '4139054000')
    if not bank['geom'].covers(Point(*to_source.transform(126.803, 37.434))):
        raise ValueError('JUSO_CRS_CONTROL_POINT_FAILED')

    tree = STRtree([feature['geom'] for feature in features])
    parents = sorted([(area, norm(area[1])) for area in areas if area[0].endswith('00000')],
                     key=lambda item: len(item[1]), reverse=True)

    def at_point(lon, lat):
        point = Point(*to_source.transform(lon, lat))
        return [features[int(index)] for index in tree.query(point) if features[int(index)]['geom'].covers(point)]

    def common_parent(found):
        if not found or any(not feature['area'] for feature in found):
            return None
        return next((area for area, normalized in parents
                     if all(feature['areaName'].startswith(normalized) for feature in found)), None)

    grid_members = {}
    for area in areas:
        grid_members.setdefault((area[2], area[3]), []).append(area)
    unresolved = {key for key, members in grid_members.items()
                  if len([area for area in members if not area[0].endswith('00000')]) != 1}
    grid_rows, land_samples = [], []
    for ny in range(1, 254):
        for nx in range(1, 150):
            center = Point(*to_source.transform(*grid_point(nx, ny)))
            if not len(tree.query(center)) and (nx, ny) not in unresolved:
                continue
            edge = []
            for start, end in [((-0.5, -0.5), (0.5, -0.5)), ((0.5, -0.5), (0.5, 0.5)),
                               ((0.5, 0.5), (-0.5, 0.5)), ((-0.5, 0.5), (-0.5, -0.5))]:
                for index in range(16):
                    x = nx + start[0] + (end[0] - start[0]) * index / 16
                    y = ny + start[1] + (end[1] - start[1]) * index / 16
                    edge.append(to_source.transform(*grid_point(x, y)))
            cell = Polygon(edge)
            found = [features[int(index)] for index in tree.query(cell.buffer(1))
                     if features[int(index)]['geom'].intersects(cell.buffer(1))]
            if (nx, ny) in unresolved:
                for feature in found:
                    intersection = feature['geom'].intersection(cell)
                    if not intersection.is_empty and intersection.area > 1:
                        point = intersection.representative_point()
                        lon, lat = to_gps.transform(point.x, point.y)
                        land_samples.append({'nx': nx, 'ny': ny, 'sgisCode': feature['entry']['sgisCode'],
                                             'kmaCode': feature['entry']['kmaCode'],
                                             'precision': feature['entry']['precision'],
                                             'sample': {'longitude': lon, 'latitude': lat}})
            parent = common_parent(found)
            # 원본 폴리곤 경계의 미세한 접합 오차(최대 1cm)만 허용한다.
            # 바다나 실제 빈 영역은 1cm 확장으로 덮이지 않는다.
            if parent and unary_union([feature['geom'] for feature in found]).buffer(0.01).covers(cell.buffer(1)):
                grid_rows.append({'type': 'grid', 'nx': nx, 'ny': ny, 'kmaCode': parent[0]})

    center_results = []
    for nx, ny in sorted(unresolved):
        found = at_point(*grid_point(nx, ny))
        precision = 'OUTSIDE' if not found else 'UNMAPPED' if any(not feature['area'] for feature in found) else \
                    'DONG' if len(found) == 1 and found[0]['entry']['precision'] == 'DONG' else 'PARENT'
        center_results.append({'nx': nx, 'ny': ny, 'precision': precision,
                               'codes': [feature['entry']['kmaCode'] for feature in found]})
    counts = Counter(feature['entry']['precision'] for feature in features)
    manifest = {'type': 'manifest', 'format': 1, 'builderRevision': REVISION, 'version': version,
                'sourceMonth': SOURCE_MONTH, 'source': '행정안전부 주소기반산업지원서비스 구역의 도형 월전체분 행정동',
                'sources': ['https://business.juso.go.kr/jst/jstAddressDetailsSearch'],
                'sourceSha256': source_hashes, 'catalogSha256': catalog_hash,
                'featureCount': len(features), 'gridCount': len(grid_rows),
                'precisionCounts': {key: counts[key] for key in ['DONG', 'PARENT', 'UNMAPPED']},
                'sourceEncoding': 'CP949', 'sourceCrs': 'EPSG:5179'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    staging = args.output.with_suffix(args.output.suffix + '.tmp')
    digest = hashlib.sha256()
    with gzip.open(staging, 'wt', encoding='utf-8', newline='\n') as target:
        target.write(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n')
        for entry in [feature['entry'] for feature in features] + grid_rows:
            line = json.dumps(entry, ensure_ascii=False, separators=(',', ':')) + '\n'
            digest.update(line.encode('utf-8'))
            target.write(line)
        target.write(json.dumps({'type': 'complete', 'sha256': digest.hexdigest()}) + '\n')
    staging.replace(args.output)
    audit = {'manifest': manifest, 'archiveSha256': archive_hashes, 'artifactSha256': sha(args.output),
             'artifactBytes': args.output.stat().st_size, 'geometryRepairsForGridOnly': repaired_count,
             'catalogNameDifferences': renamed, 'unmappedCodes': unmapped,
             'centerSummary': dict(Counter(row['precision'] for row in center_results)), 'centers': center_results,
             'features': [{'sgisCode': feature['entry']['sgisCode'], 'kmaCode': feature['entry']['kmaCode'],
                           'precision': feature['entry']['precision'], 'sourceName': feature['entry']['sourceName'],
                           'sample': feature['sample']} for feature in features],
             'landSamples': land_samples,
             'points': {name: [{'sgisCode': feature['entry']['sgisCode'], 'kmaCode': feature['entry']['kmaCode'],
                               'precision': feature['entry']['precision']} for feature in at_point(lon, lat)]
                        for name, lon, lat in [('travel', 127.660949, 37.697249), ('bank', 126.803, 37.434)]},
             'unresolvedGridReferences': [row for row in grid_rows if (row['nx'], row['ny']) in unresolved]}
    args.output.with_suffix('.audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2), 'utf-8')
    print(json.dumps({'features': len(features), 'precisionCounts': manifest['precisionCounts'],
                      'gridCount': len(grid_rows), 'landSamples': len(land_samples),
                      'repairedForGridOnly': repaired_count, 'nameDifferences': renamed,
                      'artifactBytes': audit['artifactBytes']}, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    main()
