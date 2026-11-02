"""Google Maven의 고정 SDK 소스에서 표준 Wear Widget 프리뷰 규격을 읽는다."""
from pathlib import Path
import hashlib
import io
import json
import re
import urllib.request
import zipfile

HERE = Path(__file__).resolve().parent
VERSION = '1.0.0-alpha21'
URL = f'https://dl.google.com/dl/android/maven2/androidx/glance/wear/wear-tooling-preview/{VERSION}/wear-tooling-preview-{VERSION}-sources.jar'
raw = urllib.request.urlopen(URL, timeout=30).read()
with zipfile.ZipFile(io.BytesIO(raw)) as archive:
    source = archive.read('androidx/glance/wear/tooling/preview/WidgetPreviewParams.kt').decode('utf-8')
    preview = archive.read('androidx/glance/wear/tooling/preview/WearWidgetPreview.kt').decode('utf-8')
assert '.width((params.widthDp + 2f * params.horizontalPaddingDp).dp)' in preview
assert '.height((params.heightDp + 2f * params.verticalPaddingDp).dp)' in preview
profiles = []
for family, kind, body in re.findall(r'private val (SQUIRCLE|ROUND|RECTANGULAR)_(SMALL|LARGE)_PARAMS\s*=\s*sequenceOf\((.*?)(?=\nprivate val |\Z)', source, re.S):
    for i, item in enumerate(re.findall(r'WearWidgetParams\((.*?)\n        \)', body, re.S)):
        values = {key: float(value) for key, value in re.findall(r'(widthDp|heightDp|horizontalPaddingDp|verticalPaddingDp) = ([\d.]+)f', item)}
        assert len(values) == 4
        corner = re.search(r'cornerRadiusDp = ([\d.]+)f', item)
        values['cornerRadiusDp'] = float(corner[1]) if corner else (999 if family == 'ROUND' else 0)
        values['outerWidthDp'] = values['widthDp'] + 2*values['horizontalPaddingDp']
        values['outerHeightDp'] = values['heightDp'] + 2*values['verticalPaddingDp']
        profiles.append({'id': f'{family.lower()}-{kind.lower()}-{i+1}', 'family': family, 'kind': kind.lower(), **values})
assert len(profiles) == 10
assert next(p for p in profiles if p['id']=='squircle-small-1')['heightDp'] == 60
assert next(p for p in profiles if p['id']=='squircle-large-1')['heightDp'] == 96
result = {'sdk': 'androidx.glance.wear:wear-tooling-preview:'+VERSION, 'sourceUrl': URL,
          'sourceJarSha256': hashlib.sha256(raw).hexdigest(), 'checkedAt': '2026-11-02',
          'meaning': 'widthDp/heightDp는 콘텐츠 영역; 외곽 프리뷰는 양쪽 호스트 패딩을 더한 크기',
          'deviceMeasured': False, 'profiles': profiles}
(HERE / 'widget-specs.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print('공식 SDK 소스에서 표준 프리뷰10규격 확인')
