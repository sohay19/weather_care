"""공식 행정 경계와 면적 1㎡ 이상 겹치는 전국 DFS 격자 목록을 만든다.

지역 참고 격자와 달리 중심이 바다인 해안 격자도 포함한다. 수집 시 GIS는 불필요하다.
"""
import argparse, io, json, zipfile
from pathlib import Path
import pyproj, shapefile
from shapely.geometry import Polygon, shape
from shapely.strtree import STRtree
from build_administrative_boundaries import grid_point, sha

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--boundaries', type=Path, required=True)
    parser.add_argument('--audit', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.audit.read_text(encoding='utf8'))['manifest']
    source_hash = sha(args.boundaries)
    if source_hash != manifest['sourceSha256']['boundaries']:
        raise ValueError('LAND_GRID_SOURCE_MISMATCH')
    with zipfile.ZipFile(args.boundaries) as outer:
        archive = next(name for name in outer.namelist() if Path(name).name.startswith('bnd_dong_') and name.endswith('.zip'))
        with zipfile.ZipFile(io.BytesIO(outer.read(archive))) as z:
            base = next(name[:-4] for name in z.namelist() if name.endswith('.shp'))
            crs = pyproj.CRS.from_wkt(z.read(base+'.prj').decode())
            transform = pyproj.Transformer.from_crs(4326, crs, always_xy=True)
            reader = shapefile.Reader(shp=io.BytesIO(z.read(base+'.shp')), dbf=io.BytesIO(z.read(base+'.dbf')), encoding='utf8')
            features = [shape(item.__geo_interface__) for item in reader.iterShapes()]
    tree = STRtree(features)
    grids = []
    for ny in range(1, 254):
        for nx in range(1, 150):
            edge = []
            for side in range(4):
                for i in range(16):
                    t = i/16
                    x,y = [(nx-.5+t,ny-.5),(nx+.5,ny-.5+t),(nx+.5-t,ny+.5),(nx-.5,ny+.5-t)][side]
                    edge.append(transform.transform(*grid_point(x,y)))
            cell = Polygon(edge)
            if any(features[int(index)].intersection(cell).area > 1 for index in tree.query(cell)):
                grids.append({'nx':nx, 'ny':ny})
    value = {'boundaryVersion':manifest['version'], 'sourceSha256':source_hash,
             'basis':'행정 경계와 DFS 격자의 교차 면적 1㎡ 초과', 'count':len(grids), 'grids':grids}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    staging = args.output.with_suffix('.tmp')
    staging.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf8')
    staging.replace(args.output)
    print(json.dumps({'event':'national_land_grids_built','count':len(grids)}))

if __name__ == '__main__':
    main()
