import importlib.util
import base64
import gzip
import io
import json
import urllib.request
import zipfile
from pathlib import Path

import pyproj
import shapefile
from shapely.geometry import mapping, shape
from shapely.geometry.polygon import orient
from shapely.ops import transform

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('grid', ROOT / 'weather_care_server/tools/build_administrative_boundaries.py')
grid = importlib.util.module_from_spec(spec)
spec.loader.exec_module(grid)
source = json.loads((ROOT / 'docs/원본결측_지역대조_20261009.json').read_text(encoding='utf-8'))


def clockwise(geom):
    if geom.geom_type == 'Polygon':
        return orient(geom, sign=-1)
    from shapely.geometry import MultiPolygon
    return MultiPolygon([orient(p, sign=-1) for p in geom.geoms])


features = []
labels = []
with zipfile.ZipFile(r'C:\Users\SOHA\Downloads\bnd_all_00_2025_2Q.zip') as outer:
    with zipfile.ZipFile(io.BytesIO(outer.read('bnd_sido_00_2025_2Q.zip'))) as z:
        base = 'bnd_sido_00_2025_2Q'
        crs = pyproj.CRS.from_wkt(z.read(base + '.prj').decode())
        to_lonlat = pyproj.Transformer.from_crs(crs, 4326, always_xy=True)
        reader = shapefile.Reader(shp=io.BytesIO(z.read(base+'.shp')), dbf=io.BytesIO(z.read(base+'.dbf')), encoding='utf-8')
        for row in reader.iterShapeRecords():
            original = shape(row.shape.__geo_interface__)
            geom = clockwise(transform(to_lonlat.transform, original.simplify(350, preserve_topology=True)))
            features.append({'type':'Feature','properties':{'name':row.record['SIDO_NM']},'geometry':mapping(geom)})
            if row.record['SIDO_CD'] in ('11','32','33','35','36','37','38','39'):
                center = to_lonlat.transform(*original.representative_point().coords[0])
                name = {'11':'서울','32':'강원','33':'충북','35':'전북','36':'전남','37':'경북','38':'경남','39':'제주'}[row.record['SIDO_CD']]
                labels.append({'name':name,'coordinates':center})

grids = []
for g in source['grids']:
    nx,ny = g['nx'],g['ny']
    # Clockwise spherical winding for d3-geo, with the exact DFS cell corners.
    corners = [grid.grid_point(nx-.5,ny-.5),grid.grid_point(nx-.5,ny+.5),grid.grid_point(nx+.5,ny+.5),grid.grid_point(nx+.5,ny-.5)]
    grids.append({'id':f'{nx},{ny}','nx':nx,'ny':ny,'lon':g['gridCenter']['longitude'],'lat':g['gridCenter']['latitude'],'areas':g['intersectedAreas'],'landFraction':g['landFraction'],'geometry':{'type':'Polygon','coordinates':[corners+[corners[0]]]}})


def round_numbers(x):
    if isinstance(x,float): return round(x,6)
    if isinstance(x,(list,tuple)): return [round_numbers(v) for v in x]
    if isinstance(x,dict): return {k:round_numbers(v) for k,v in x.items()}
    return x


data = round_numbers({'land':{'type':'FeatureCollection','features':features},'grids':grids,'labels':labels})
assert len(grids) == len({g['id'] for g in grids}) == 302
library = OUT / 'd3-7.9.0.min.js'
if not library.exists():
    library.write_bytes(urllib.request.urlopen('https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js',timeout=30).read())
template = (OUT / 'missing-observation-grids.template.html').read_text(encoding='utf-8')
packed = base64.b64encode(gzip.compress(json.dumps(data,ensure_ascii=False,separators=(',',':')).encode('utf-8'),mtime=0)).decode('ascii')
html = template.replace('__MAP_DATA__',packed).replace('__D3_LIBRARY__',library.read_text(encoding='utf-8').replace('</script','<\\/script'))
target = OUT / 'missing-observation-grids.html'
target.write_text(html,encoding='utf-8')
assert target.stat().st_size < 1_000_000
print(json.dumps({'grids':len(grids),'provinces':len(features),'bytes':target.stat().st_size},ensure_ascii=False))
