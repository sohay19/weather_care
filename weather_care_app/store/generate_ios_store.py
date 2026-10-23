"""2026-10-23 실제 iOS 앱·홈 위젯 촬영본으로 스토어 스크린샷을 만든다."""
from __future__ import annotations

import hashlib
import argparse
import json
import shutil
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
import generate_android_store as common

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'screenshots/source-ios-20261023'
NATIVE = ROOT / 'screenshots/native-ios-20261023'
TOPICS = common.TOPICS
SIZES = {'ios': (1320, 2868), 'ipad': (2064, 2752)}
BACKUP = ROOT.parent / 'build/ios-live-store-20261023/before'


def backup(path):
    destination = BACKUP / path.relative_to(ROOT)
    if path.exists() and not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)


def widget(family, platform, dark=False):
    """실제 WidgetKit 홈 위젯의 촬영 원본만 사용한다."""
    device = 'tablet' if platform == 'ipad' else 'phone'
    path = NATIVE / device / f'{"dark" if dark else "light"}-{family}.png'
    records = json.loads((NATIVE / device / 'capture-manifest.json').read_text(encoding='utf-8'))
    record = next(row for row in records if row['path'] == f'{device}/{path.name}')
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
    with Image.open(path) as image:
        return image.convert('RGBA')


def app_screen(name):
    """시스템 바만 제외한 실제 전체 화면 촬영본의 해시·크롭 범위를 확인한다."""
    path = SOURCE / 'phone' / f'{name}.png'
    records = json.loads((SOURCE / 'phone/capture-manifest.json').read_text(encoding='utf-8'))['files']
    record = next(row for row in records if row['name'] == name)
    assert record['source_size'] == [1290, 2796] and record['crop'] == [0, 177, 1290, 2694]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
    with Image.open(path) as image:
        assert image.size == (1290, 2517), path
        return image.convert('RGB')


def native_card(canvas, image, xy, width):
    image = image.resize((width, round(image.height * width / image.width)), Image.Resampling.LANCZOS)
    x, y = map(round, xy)
    shadow = Image.new('RGBA', canvas.size)
    shade = Image.new('RGBA', image.size, (17, 37, 57, 0))
    shade.putalpha(image.getchannel('A').point(lambda alpha: round(alpha * .37)))
    shadow.alpha_composite(shade, (x, y + 12))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)))
    canvas.alpha_composite(image, (x, y))
    return x, y, x + image.width, y + image.height


def compose(topic, platform):
    stem, eyebrow, headline, caption, source = topic
    tablet = platform == 'ipad'
    height = 1440 if tablet else round(2868 * 1080 / 1320)
    canvas = Image.new('RGBA', (1080, height))
    draw = ImageDraw.Draw(canvas)
    common.text(draw, (540, 60), eyebrow, 30, common.YELLOW, center=True)
    common.text(draw, (540, 120), headline, 65, common.WHITE, 'Heavy', center=True, spacing=11)
    common.text(draw, (540, 293), caption, 25, '#E6F0F7', 'Medium', center=True)
    if source:
        width, y = (500, 380) if tablet else (820, 410)
        with app_screen(source) as im:
            x = 80 if stem == '04-dark-mode' else (1080 - width) // 2
            bounds = common.card(canvas, im, (x, y), width, 24)
            assert bounds[3] < height, (platform, stem, bounds)
        if stem == '04-dark-mode':
            native_card(canvas, widget('large', platform, True),
                        (555, 860) if tablet else (510, 1490), 460 if tablet else 510)
    elif stem == '03-widget':
        y = 365 if tablet else 430
        widths = [180, 500, 420] if tablet else [300, 740, 660]
        for family, label, width in zip(['small', 'medium', 'large'],
                                        ['작은 위젯', '중간 위젯', '큰 위젯'], widths):
            common.text(draw, (540, y), label, 20 if tablet else 25, '#E6F0F7', center=True)
            y += 30 if tablet else 43
            bounds = native_card(canvas, widget(family, platform), ((1080 - width) / 2, y), width)
            y = bounds[3] + (22 if tablet else 40)
        assert y < height, (platform, y, height)
    else:
        alerts = common.notification_cards([
            ('자외선', '낮 자외선이 강해요',
             '낮 동안 자외선이 높을 것으로 보여요.\n외출한다면 선크림이나 양산을 챙기세요.'),
        ])
        width = 580 if tablet else 950
        alerts = alerts.resize((width, round(alerts.height * width / alerts.width)),
                               Image.Resampling.LANCZOS)
        y = 365 if tablet else 510
        assert y + alerts.height + 75 < height, (platform, alerts.height, height)
        canvas.alpha_composite(alerts, ((1080 - alerts.width) // 2, y))
    # 제목·앱 화면·위젯을 한 묶음으로 세로 중앙에 맞춘다.
    bounds = canvas.getchannel('A').getbbox()
    offset = (height - (bounds[3] - bounds[1])) // 2 - bounds[1]
    centered = Image.new('RGBA', canvas.size, common.BG)
    centered.alpha_composite(canvas, (0, offset))
    destination = ROOT / 'screenshots' / platform / f'{stem}.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    centered.convert('RGB').resize(SIZES[platform], Image.Resampling.LANCZOS).save(destination, optimize=True)
    return destination


def preview(paths, platform):
    cell_w, cell_h = (340, 510) if platform == 'ipad' else (300, 680)
    sheet = Image.new('RGB', (cell_w * 4, cell_h * 2), '#E9EEF3')
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        with Image.open(path) as im:
            im.thumbnail((cell_w - 14, cell_h - 42), Image.Resampling.LANCZOS)
            sheet.paste(im, (i % 4 * cell_w + (cell_w - im.width) // 2, i // 4 * cell_h))
        common.text(draw, (i % 4 * cell_w + cell_w / 2, (i // 4 + 1) * cell_h - 30),
                    f'{i + 1:02d}  {TOPICS[i][1]}', 17, '#29343D', center=True)
    destination = ROOT / f'screenshots/preview-{platform}.png'
    sheet.save(destination, optimize=True)
    return destination


def package(path, files, preserve=False):
    backup(path)
    temporary = path.with_suffix('.tmp.zip')
    names = {p.relative_to(ROOT).as_posix() for p in files}
    retained = {}
    with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as out:
        if preserve and path.exists():
            with zipfile.ZipFile(path) as old:
                for entry in old.infolist():
                    if entry.filename in names or entry.filename.startswith(('screenshots/ios/', 'screenshots/ipad/')):
                        continue
                    data = old.read(entry.filename)
                    retained[entry.filename] = hashlib.sha256(data).hexdigest()
                    out.writestr(entry, data)
        for file in files:
            out.write(file, file.relative_to(ROOT))
    with zipfile.ZipFile(temporary) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(set(archive.namelist()))
        for name, digest in retained.items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == digest
        for file in files:
            assert archive.read(file.relative_to(ROOT).as_posix()) == file.read_bytes()
    temporary.replace(path)


def main(topics=None):
    if topics and not set(topics) <= {topic[0] for topic in TOPICS}:
        raise ValueError('지원하지 않는 스크린샷 번호입니다.')
    images, previews = [], []
    for platform in SIZES:
        backup(ROOT / f'screenshots/preview-{platform}.png')
        paths = []
        for topic in TOPICS:
            path = ROOT / 'screenshots' / platform / f'{topic[0]}.png'
            if not topics or topic[0] in topics:
                backup(path)
                path = compose(topic, platform)
            assert path.is_file(), path
            paths.append(path)
        images.extend(paths)
        previews.append(preview(paths, platform))
    records = []
    for path in images:
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            assert im.size == SIZES[path.parent.name] and im.mode == 'RGB' and im.format == 'PNG'
            records.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(im.size),
                            'mode': im.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    report = ROOT / 'screenshots/ios-20261023-manifest.json'
    report.write_text(json.dumps({'기준일': '2026-10-23', '화면': '실제 iPhone 앱 전체 화면 촬영, iPad 등록 규격에도 동일 원본 사용',
        '배치': '제목·앱 화면·위젯·알림 예시 전체 묶음을 이미지의 세로 중앙에 정렬',
        '데이터': '운영 서버 실자료, 심화 날씨는 테스트 서버 실관측, 실제 촬영용 기기 설정', '위젯': '제품 앱 자료를 표시한 실제 WidgetKit 홈 위젯 촬영본',
        '알림': '지원 알림 종류의 예시 카드 5개(자외선 예시 2026-10-23 추가)', 'files': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    docs = [ROOT / 'screenshots/IOS_20261023.md', ROOT / 'screenshots/README.md', report]
    files = images + previews + docs
    for name in ['app-store/weather-care-ios-screenshots.zip', 'app-store/weather-care-ios-screenshots-20261023.zip']:
        package(ROOT / name, files)
    sources = list(SOURCE.rglob('*')) + list(NATIVE.rglob('*'))
    sources = [path for path in sources if path.is_file()]
    for folder in ['native_ios_widget_capture', 'native_ios_app_capture']:
        sources += [path for path in (ROOT / folder).iterdir() if path.is_file()]
    for name in ['weather-care-store-assets.zip', 'weather-care-store-screenshots.zip']:
        package(ROOT / name, files + sources + [Path(__file__).resolve(),
                ROOT / 'capture_ios_test.dart', ROOT / 'capture_android_test.dart',
                ROOT / 'generate_store_screenshots.py', ROOT / 'generate_android_store.py'], preserve=True)
    print(json.dumps({'검증완료': len(records), '플랫폼': list(SIZES),
                     '묶음': 'app-store/weather-care-ios-screenshots-20261023.zip'}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--topics', help='예: 02-timeline,03-widget,04-dark-mode')
    args = parser.parse_args()
    main(args.topics.split(',') if args.topics else None)
