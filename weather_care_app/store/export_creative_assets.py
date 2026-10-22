"""스크린샷을 재생성하지 않고 그래픽·헤더·검색 결과 소재만 내보낸다."""
from pathlib import Path
import hashlib
import json
import sys
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image

ROOT = Path(__file__).resolve().parent
ASSETS = [
    ('google-play/source/feature-graphic.png', 'google-play/feature-graphic.png', (1024, 500)),
    ('app-store/source/header.png', 'app-store/header-3840x1646.png', (3840, 1646)),
    ('app-store/source/search-results.png', 'app-store/search-results-1920x1280.png', (1920, 1280)),
]
COPY = ['날씨챙겨', '날씨에 맞는 준비물로', '오늘 하루를 챙겨보세요',
        '주제별 날씨 요약과 심화 정보까지', '준비물 · 위젯 · 맞춤 알림']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pack(path, files):
    with ZipFile(path, 'w', ZIP_DEFLATED) as archive:
        for local, name in files:
            archive.write(ROOT / local, name)
    with ZipFile(path) as archive:
        assert archive.testzip() is None


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    screenshots = {p: digest(p) for p in (ROOT / 'screenshots').rglob('*.png')}
    records = []
    for source, target, size in ASSETS:
        with Image.open(ROOT / source) as image:
            original_size = image.size
            # 문구·그림은 imagegen에서 완성했다. 여기서는 RGB 및 크기만 정규화한다.
            image.convert('RGB').resize(size, Image.Resampling.LANCZOS).save(ROOT / target, optimize=True)
        with Image.open(ROOT / target) as image:
            assert image.size == size and image.mode == 'RGB' and image.format == 'PNG'
            image.verify()
        records.append({'파일': target, '크기': list(size), '원본크기': list(original_size),
                        'SHA256': digest(ROOT / target), '원본SHA256': digest(ROOT / source)})
    manifest = ROOT / 'creative-20261022-manifest.json'
    manifest.write_text(json.dumps({'제작일': '2026-10-22', '문구': COPY,
        '방식': 'imagegen 제작 후 크기·RGB 정규화, 스크린샷 재생성 없음',
        '파일': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    android_manifest = ROOT / 'screenshots/android-20261021-manifest.json'
    data = json.loads(android_manifest.read_text(encoding='utf-8'))
    for row in data['files']:
        if row['path'] == 'google-play/feature-graphic.png':
            row['sha256'] = digest(ROOT / row['path'])
            row['갱신일'] = '2026-10-22'
            row['제작방식'] = '준비물 캠페인 일러스트, 스크린샷 아님'
    android_manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    pack(ROOT / 'app-store/weather-care-app-store-creative-assets.zip', [
        (ASSETS[1][1], Path(ASSETS[1][1]).name), (ASSETS[2][1], Path(ASSETS[2][1]).name),
        ('app-store/README.md', '등록안내.md')])
    pack(ROOT / 'weather-care-creative-assets-20261022.zip', [
        *[(target, target) for _, target, _ in ASSETS],
        ('CREATIVE_20261022.md', '등록안내.md'),
        ('creative-20261022-manifest.json', 'creative-20261022-manifest.json')])
    # 기존 배포 묶음은 그래픽/해시 항목만 교체한다. 스크린샷 항목은 원본 바이트 유지.
    replacements = ['google-play/feature-graphic.png', 'screenshots/android-20261021-manifest.json',
                    'generate_android_store.py']
    for name in ['weather-care-store-assets.zip', 'weather-care-store-screenshots.zip',
                 'google-play/weather-care-android-store-20261021.zip']:
        path = ROOT / name
        temporary = path.with_suffix('.tmp.zip')
        with ZipFile(path) as old, ZipFile(temporary, 'w', ZIP_DEFLATED) as new:
            for entry in old.infolist():
                content = (ROOT / entry.filename).read_bytes() if entry.filename in replacements else old.read(entry.filename)
                new.writestr(entry, content)
        with ZipFile(temporary) as archive:
            assert archive.testzip() is None
        temporary.replace(path)
    assert screenshots == {p: digest(p) for p in (ROOT / 'screenshots').rglob('*.png')}
    print(f'홍보 PNG 3개·ZIP 5개 검증 완료, 기존 스크린샷 {len(screenshots)}개 SHA256 유지')


if __name__ == '__main__':
    main()
