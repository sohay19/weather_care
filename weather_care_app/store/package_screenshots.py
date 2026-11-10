"""최신 등록본·홈 위젯을 검증하고 미리보기와 플랫폼별·전체 ZIP을 만든다."""
import argparse
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

from PIL import Image, ImageDraw
import generate_android_store as common

ROOT = Path(__file__).resolve().parent
SCREENSHOTS = ROOT / 'screenshots'
DATE = '20261104'
ANDROID_REFRESH_DATE = '20261110'
WATCH_NAMES = ['현재 날씨', '오늘의 준비물', '타임라인', '기상·생활', '워치 위젯']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package(path, files, base=ROOT):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in files:
            archive.write(file, file.relative_to(base))
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(files) == len(set(archive.namelist()))
        for file in files:
            assert archive.read(file.relative_to(base).as_posix()) == file.read_bytes()


def refresh_android():
    baseline = ROOT / f'weather-care-all-screenshots-{DATE}.zip'
    with zipfile.ZipFile(baseline) as archive:
        files = [ROOT / name for name in archive.namelist()]
    old_report = SCREENSHOTS / f'screenshots-all-{DATE}-manifest.json'
    report = SCREENSHOTS / f'screenshots-all-{ANDROID_REFRESH_DATE}-manifest.json'
    data = json.loads(old_report.read_text(encoding='utf-8'))
    data['Android 알림 설정 편집일'] = '2026-11-10'
    for row in data['files']:
        path = ROOT / row['path']
        if path.parent.name in {'android', 'android-tablet'} and path.name == '08-notification-settings.png':
            with Image.open(path) as image:
                image.load()
                assert list(image.size) == row['size'] and image.mode == row['mode'] and image.format == 'PNG'
            row['sha256'] = digest(path)
        else:
            assert digest(path) == row['sha256'], path
    report.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    files[files.index(old_report)] = report
    files.append(common.SETTINGS_SOURCE / 'capture-manifest.json')
    package(ROOT / 'weather-care-store-screenshots.zip', files)


def preview(paths, destination, labels, cell=(250, 330)):
    canvas = Image.new('RGB', (cell[0] * len(paths), cell[1]), '#DDE5EF')
    draw = ImageDraw.Draw(canvas)
    for index, (path, label) in enumerate(zip(paths, labels, strict=True)):
        with Image.open(path) as image:
            image.thumbnail((cell[0] - 18, cell[1] - 55), Image.Resampling.LANCZOS)
            canvas.paste(image, (index * cell[0] + (cell[0] - image.width) // 2, 12))
        common.text(draw, (index * cell[0] + cell[0] / 2, cell[1] - 30),
                    label, 17, '#29343D', center=True)
    canvas.save(destination, optimize=True)
    return destination


def main():
    records, images, previews = [], [], []
    for folder, size, count in [
        ('ios', (1320, 2868), 8), ('ipad', (2064, 2752), 8),
        ('android', (1080, 2160), 8), ('android-tablet', (1440, 2880), 8),
        ('watchos', (416, 496), 5), ('wear-os', (438, 438), 5),
        ('watchos-promo', (416, 496), 5), ('wear-os-promo', (438, 438), 5),
    ]:
        paths = sorted((SCREENSHOTS / folder).glob('*.png'))
        assert len(paths) == count, folder
        for path in paths:
            with Image.open(path) as image:
                image.load()
                assert image.size == size and image.mode == 'RGB' and image.format == 'PNG', path
            records.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(size),
                            'mode': 'RGB', 'sha256': digest(path)})
        images.extend(paths)
        if folder in ['ios', 'ipad', 'android', 'android-tablet']:
            previews.append(SCREENSHOTS / f'preview-{folder}.png')
        else:
            name = 'wear' if folder == 'wear-os' else folder
            previews.append(preview(paths, SCREENSHOTS / f'preview-{name}-{DATE}.png', WATCH_NAMES))
            package(SCREENSHOTS / f'{folder}{"-screenshots" if "promo" not in folder else ""}-{DATE}.zip',
                    paths, SCREENSHOTS / folder)

    widget_previews = []
    for platform in ['ios', 'android']:
        folder = ROOT / f'screenshot-inputs/native-{platform}-{DATE}'
        folder = folder / 'phone' if platform == 'ios' else folder
        manifest = folder / 'capture-manifest.json'
        data = json.loads(manifest.read_text(encoding='utf-8'))
        rows = data if isinstance(data, list) else data['files']
        paths, labels = [], []
        for theme, theme_label in [('light', '라이트'), ('dark', '다크')]:
            for family, family_label in [('small', '소형'), ('medium', '중형'), ('large', '대형')]:
                path = folder / f'{theme}-{family}.png'
                row = next(row for row in rows if Path(row['path']).name == path.name)
                assert digest(path) == row['sha256'], path
                with Image.open(path) as image:
                    image.load()
                    size = list(image.size)
                    mode = image.mode
                records.append({'path': path.relative_to(ROOT).as_posix(), 'size': size,
                                'mode': mode, 'sha256': digest(path)})
                paths.append(path)
                labels.append(f'{family_label} · {theme_label}')
        images.extend(paths)
        widget_previews.append(preview(paths, SCREENSHOTS / f'preview-{platform}-widgets-{DATE}.png', labels,
                                       cell=(210, 300)))
    with Image.open(widget_previews[0]) as top, Image.open(widget_previews[1]) as bottom:
        canvas = Image.new('RGB', (top.width, top.height + bottom.height + 70), '#DDE5EF')
        canvas.paste(top, (0, 35))
        canvas.paste(bottom, (0, top.height + 70))
        draw = ImageDraw.Draw(canvas)
        common.text(draw, (20, 8), '아이폰 홈 위젯', 20, '#29343D')
        common.text(draw, (20, top.height + 43), '안드로이드 홈 위젯', 20, '#29343D')
        path = SCREENSHOTS / f'preview-widgets-{DATE}.png'
        canvas.save(path, optimize=True)
        previews.append(path)
    previews.extend(widget_previews)

    # 촬영 원본과 등록 파일을 별도로 검증한다.
    sources = []
    for directory in ['source-ios-20261104/phone', 'source-android-20261104',
                      'source-watchos-20261104', 'source-wear-20261104']:
        path = SCREENSHOTS / directory / 'capture-manifest.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        for row in data['files']:
            file = path.parent / Path(row.get('path', row.get('name', '') + '.png')).name
            assert file.exists() and digest(file) == row['sha256'], file
        sources.append(path)
    assert len(images) == 64
    report = SCREENSHOTS / f'screenshots-all-{DATE}-manifest.json'
    report.write_text(json.dumps({
        '기준일': '2026-11-04', '글꼴': '나눔스퀘어 네오',
        '구성': '휴대전화·태블릿 등록 32장, 워치 앱·위젯 등록 10장, 워치 홍보 10장, 홈 위젯 원본 12장',
        '검증': 'PNG 규격·모드·SHA-256, 촬영 원본 해시, ZIP 무결성과 개별 파일 일치',
        'files': records,
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    docs = [SCREENSHOTS / 'README.md', SCREENSHOTS / f'SCREENSHOTS_{DATE}.md', report]
    ios_files = [path for path in images if path.parent.name in ['ios', 'ipad']]
    android_files = [path for path in images if path.parent.name in ['android', 'android-tablet']]
    for name in [f'app-store/weather-care-ios-screenshots-{DATE}.zip', 'app-store/weather-care-ios-screenshots.zip']:
        package(ROOT / name, ios_files + previews[:2] + docs + [SCREENSHOTS / f'ios-{DATE}-manifest.json'])
    package(ROOT / f'weather-care-android-screenshots-{DATE}.zip',
            android_files + previews[2:4] + docs + [SCREENSHOTS / f'screenshots-{DATE}-manifest.json'])
    widget_manifests = [ROOT / f'screenshot-inputs/native-ios-{DATE}/phone/capture-manifest.json',
                        ROOT / f'screenshot-inputs/native-android-{DATE}/capture-manifest.json']
    full = ROOT / f'weather-care-all-screenshots-{DATE}.zip'
    package(full, images + previews + docs + sources + widget_manifests)
    shutil.copy2(full, ROOT / 'weather-care-store-screenshots.zip')
    assert digest(full) == digest(ROOT / 'weather-care-store-screenshots.zip')
    # 같은 날짜의 기존 Android 전용 경로도 현재 등록본과 일치시킨다.
    phone_folder = SCREENSHOTS / f'phone-{DATE}'
    for file in android_files:
        target = phone_folder / file.parent.name / file.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)
    for name in ['preview-android.png', 'preview-android-tablet.png']:
        shutil.copy2(SCREENSHOTS / name, phone_folder / name)
    report_path = phone_folder / 'capture-manifest.json'
    phone_report = json.loads(report_path.read_text(encoding='utf-8'))
    phone_report['files'] = [row for row in records if row['path'].startswith(
        ('screenshots/android/', 'screenshots/android-tablet/'))]
    report_path.write_text(json.dumps(phone_report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    android_zip = ROOT / f'weather-care-android-screenshots-{DATE}.zip'
    phone_zip = ROOT / f'weather-care-android-phone-screenshots-{DATE}.zip'
    shutil.copy2(android_zip, phone_zip)
    assert digest(android_zip) == digest(phone_zip)
    print(json.dumps({'검증한_PNG': len(images), '미리보기': len(previews),
                      '전체_ZIP': str(full), 'ZIP_SHA256': digest(full)}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--android-refresh', action='store_true', help='Android 8번 교체분을 현재 전체 ZIP에 반영')
    args = parser.parse_args()
    if args.android_refresh:
        refresh_android()
    else:
        main()
