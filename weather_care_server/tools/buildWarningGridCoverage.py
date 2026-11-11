"""기상청 육상 특보구역에 면적의 65% 이상이 포함된 DFS 격자를 계산한다. Shapely 2.1과 NumPy가 필요하다."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from shapely import STRtree, box, make_valid, transform
from shapely.geometry import Polygon, shape


MINIMUM_COVERAGE = 0.65
FIRST, SECOND = map(math.radians, (30, 60))
RADIUS = 6371.00877 / 5
CONE = math.log(math.cos(FIRST) / math.cos(SECOND)) / math.log(
    math.tan(math.pi / 4 + SECOND / 2) / math.tan(math.pi / 4 + FIRST / 2))
SCALE = math.tan(math.pi / 4 + FIRST / 2) ** CONE * math.cos(FIRST) / CONE
ORIGIN = RADIUS * SCALE / math.tan(math.pi / 4 + math.radians(38) / 2) ** CONE


def inverse_grid(nx, ny):
    x, y = nx - 43, ORIGIN - ny + 136
    longitude = math.degrees(math.atan2(x, y) / CONE) + 126
    latitude = math.degrees(2 * math.atan((RADIUS * SCALE / math.hypot(x, y)) ** (1 / CONE)) - math.pi / 2)
    return longitude, latitude


def grid_bounds(nx, ny):
    columns = [nx - 0.5, nx + 0.5]
    if nx == 43:
        columns.append(nx)
    points = [inverse_grid(x, y) for x in columns for y in [ny - 0.5, ny + 0.5]]
    longitudes, latitudes = zip(*points)
    return box(min(longitudes), min(latitudes), max(longitudes), max(latitudes))


def grid_polygon(nx, ny, steps=64):
    corners = [(nx-.5, ny-.5), (nx+.5, ny-.5), (nx+.5, ny+.5), (nx-.5, ny+.5)]
    return Polygon([inverse_grid(x + (end_x-x)*step/steps, y + (end_y-y)*step/steps)
                    for (x, y), (end_x, end_y) in zip(corners, corners[1:] + corners[:1])
                    for step in range(steps)])


def equal_area(longitude, latitude):
    # 구면 램버트 정적방위 투영. 교차 면적과 격자 면적에 같은 투영을 사용한다.
    phi = np.radians(latitude)
    delta = np.radians(longitude - 126)
    sin_origin, cos_origin = math.sin(math.radians(38)), math.cos(math.radians(38))
    sin_phi, cos_phi = np.sin(phi), np.cos(phi)
    factor = np.sqrt(2 / (1 + sin_origin*sin_phi + cos_origin*cos_phi*np.cos(delta)))
    return factor*cos_phi*np.sin(delta), factor*(cos_origin*sin_phi - sin_origin*cos_phi*np.cos(delta))


def area(geometry):
    return transform(geometry, equal_area, interleaved=False).area


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    data = json.loads(raw)
    assert data['crs']['properties']['name'] == 'urn:ogc:def:crs:OGC:1.3:CRS84'
    features = [item for item in data['features'] if item['properties']['regId'].startswith('L')]
    ids = [item['properties']['regId'] for item in features]
    assert len(ids) >= 250 and len(set(ids)) == len(ids)
    geometries = [make_valid(shape(item['geometry'])) for item in features]
    index = STRtree(geometries)
    sizes = [(east - west) * (north - south) for west, south, east, north in (g.bounds for g in geometries)]
    grids = {}
    for nx in range(1, 150):
        for ny in range(1, 254):
            bounds = grid_bounds(nx, ny)
            candidates = index.query(bounds, predicate='intersects')
            if len(candidates) == 0:
                continue
            matched = []
            footprint = None
            for i in candidates:
                zone = geometries[i]
                if zone.covers(bounds):
                    matched.append(i)
                    continue
                if footprint is None:
                    footprint = grid_polygon(nx, ny)
                    footprint_area = area(footprint)
                coverage = area(zone.intersection(footprint)) / footprint_area
                if abs(coverage - MINIMUM_COVERAGE) < 0.0001:
                    refined = grid_polygon(nx, ny, steps=256)
                    coverage = area(zone.intersection(refined)) / area(refined)
                if coverage >= MINIMUM_COVERAGE:
                    matched.append(i)
            if matched:
                grids[f'{nx}:{ny}'] = [ids[i] for i in sorted(matched, key=lambda i: (sizes[i], i))]
    output = {'sourceSha256': hashlib.sha256(raw).hexdigest(),
              'minimumCoverage': MINIMUM_COVERAGE, 'regionsByGrid': grids}
    args.output.write_text(json.dumps(output, separators=(',', ':')) + '\n', encoding='utf-8')
    print(f'{len(grids)} grids, {sum(map(len, grids.values()))} zone matches')


if __name__ == '__main__':
    main()
