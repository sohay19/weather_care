"""실제 iOS 앱·홈 위젯 촬영본으로 스토어 스크린샷을 만든다."""
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
SOURCE = ROOT / 'screenshots/source-ios-20261029'
SETTINGS_SOURCE = ROOT / 'screenshots/source-ios-20261030'
NATIVE = ROOT / 'screenshots/native-ios-20261028'
# Android 제작 설정과 독립적으로 iOS 소개 순서를 관리한다.
TOPICS = [
    ('01-main', '오늘의 날씨 요약', '나가기 전 필요한 정보,\n한눈에 챙겨요', '지금 날씨 · 오늘 최저·최고 · 어제와 비교', 'main'),
    ('02-region-notifications', '지역별 알림', '관심 있는 지역의\n날씨 알림을 골라요', '여러 지역 저장 · 지역마다 알림 ON/OFF', 'region-notifications'),
    ('03-widget', '홈 화면 위젯', '앱을 열지 않아도\n날씨가 보여요', '작게, 넓게, 자세하게 · 세 가지 크기', None),
    ('04-dark-mode', '편안한 다크모드', '앱도 위젯도\n눈이 편안하게', '라이트 · 다크 · 시스템 설정에 맞춰', 'dark-main'),
    ('05-notifications', '다양한 날씨 알림', '챙겨야 할 날씨,\n알림으로 알려드려요', '준비물 요약 · 현재 비 · 기상특보 · 낙뢰 · 자외선', None),
    ('06-advanced', '심화 날씨 정보', '바다와 하천까지\n더 깊이 살펴요', '만조·간조/조위 · 수온 · 수위·유량 · 댐·보', 'advanced-values'),
    ('07-week', '일주일 예보', '한 주의 흐름을 보고\n하루를 계획해요', '주간 요약 · 날짜별 예보 · 시간별 날씨', 'week'),
    ('08-notification-settings', '원하는 알림만', '받고 싶은 알림만\n켜고 끌 수 있어요', '준비물부터 기상·생활 알림까지, 하나씩 선택', 'notification-settings'),
]
SIZES = {'ios': (1320, 2868), 'ipad': (2064, 2752)}
BACKUP = ROOT.parent / 'build/ios-last-screenshot-20261030/before'


def backup(path):
    destination = BACKUP / path.relative_to(ROOT)
    if path.exists() and not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)


def widget(family, platform, dark=False):
    """실제 WidgetKit 홈 위젯의 촬영 원본만 사용한다."""
    device = 'phone'  # 두 등록 규격에 같은 실제 iPhone 위젯 촬영본 사용
    path = NATIVE / device / f'{"dark" if dark else "light"}-{family}.png'
    records = json.loads((NATIVE / device / 'capture-manifest.json').read_text(encoding='utf-8'))
    record = next(row for row in records if row['path'] == f'{device}/{path.name}')
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
    with Image.open(path) as image:
        return image.convert('RGBA')


def app_screen(name):
    """시스템 바만 제외한 실제 전체 화면 촬영본의 해시·크롭 범위를 확인한다."""
    directory = SETTINGS_SOURCE if name == 'notification-settings' else SOURCE
    path = directory / 'phone' / f'{name}.png'
    records = json.loads((directory / 'phone/capture-manifest.json').read_text(encoding='utf-8'))['files']
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
    stem, _eyebrow, headline, _caption, source = topic
    width, height = SIZES[platform]
    scale = width / 1080
    margin = round(72 * scale)
    content_width = width - margin * 2
    canvas = Image.new('RGBA', (width, height), common.BG)
    draw = ImageDraw.Draw(canvas)
    title_font = common.font(round(60 * scale), 'Heavy')
    spacing = round(16 * scale)
    title_box = draw.multiline_textbbox((0, 0), headline, font=title_font, spacing=spacing)
    assert title_box[2] - title_box[0] <= content_width
    common.text(draw, (width / 2, margin), headline, round(60 * scale),
                common.WHITE, 'Heavy', center=True, spacing=spacing)
    title_bottom = margin + title_box[3] - title_box[1]
    content_top = title_bottom + margin
    content_height = height - margin - content_top
    if source:
        with app_screen(source) as im:
            screen_width = min(content_width, round(content_height * im.width / im.height))
            bounds = common.card(canvas, im, ((width - screen_width) // 2, content_top), screen_width, 0)
        if stem == '04-dark-mode':
            overlay_width = min(round(460 * scale), round(screen_width * .8))
            overlay = widget('large', platform, True)
            overlay_height = round(overlay.height * overlay_width / overlay.width)
            overlay_y = min(round(bounds[1] + (bounds[3] - bounds[1]) * .56), height - margin - overlay_height)
            native_card(canvas, overlay, (width - margin - overlay_width, overlay_y), overlay_width)
    elif stem == '03-widget':
        widgets = [(round(sw * scale), widget(family, platform)) for family, sw in
                   [('small', 400), ('medium', 936), ('large', 900)]]
        original_height = sum(round(im.height * sw / im.width) for sw, im in widgets)
        factor = min(1, (content_height - round(72 * scale)) / original_height)
        widgets = [(round(sw * factor), im) for sw, im in widgets]
        total_height = sum(round(im.height * sw / im.width) for sw, im in widgets)
        gap = (content_height - total_height) / 2
        y = content_top
        for index, (sw, im) in enumerate(widgets):
            if index == 2:
                y = height - margin - round(im.height * sw / im.width)
            bounds = native_card(canvas, im, ((width - sw) / 2, y), sw)
            y = bounds[3] + gap
        assert bounds[3] == height - margin
    else:
        alerts = common.notification_cards([
            ('자외선', '낮 자외선이 강해요',
             '낮 동안 자외선이 높을 것으로 보여요.\n외출한다면 선크림이나 양산을 챙기세요.'),
        ])
        alerts_width = min(content_width, round(content_height * alerts.width / alerts.height))
        alerts = alerts.resize((alerts_width, round(alerts.height * alerts_width / alerts.width)),
                               Image.Resampling.LANCZOS)
        canvas.alpha_composite(alerts, ((width - alerts.width) // 2, content_top))
    # Android와 같은 바깥 여백·제목 간격에 그림자가 침범하지 않게 한다.
    draw = ImageDraw.Draw(canvas)
    for box in [(0, 0, width - 1, margin - 1), (0, height - margin, width - 1, height - 1),
                (0, 0, margin - 1, height - 1), (width - margin, 0, width - 1, height - 1),
                (0, title_bottom, width - 1, content_top - 1)]:
        draw.rectangle(box, fill=common.BG)
    destination = ROOT / 'screenshots' / platform / f'{stem}.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(destination, optimize=True)
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
        old_timeline = ROOT / 'screenshots' / platform / '02-timeline.png'
        if old_timeline.exists():
            backup(old_timeline)
            old_timeline.unlink()
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
    report = ROOT / 'screenshots/ios-20261030-manifest.json'
    report.write_text(json.dumps({'기준일': '2026-10-30', '화면': '실제 iPhone 앱 전체 화면 촬영, iPad 등록 규격에도 동일 원본 사용',
        '배치': '8번은 pull 받은 Android 2026-10-30 마지막 장 참고: 큰 두 줄 제목, 줄간격 16px, 바깥 최소 여백과 제목·이미지 간격 72px(1080px 너비 기준). 분류명·부연 설명·위젯 크기 라벨 생략. 원본 비율 유지.',
        '데이터': '제품 앱의 실제 서버 응답과 촬영용 설정. 8번 알림 설정은 2026-10-30 재촬영, 1~7번은 2026-10-29 등록 이미지 유지.', '위젯': '3·4번은 기존 등록 이미지 유지. 사용 원본은 2026-10-28 실제 WidgetKit 촬영본이며 두 등록 규격에 같은 원본 사용.',
        '알림': '5번은 지원 알림 종류의 예시 카드 5개, 2번은 실제 지역별 알림 설정 화면', 'files': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    docs = [ROOT / 'screenshots/IOS_20261030.md', ROOT / 'screenshots/README.md', report]
    files = images + previews + docs
    for name in ['app-store/weather-care-ios-screenshots.zip', 'app-store/weather-care-ios-screenshots-20261030.zip']:
        package(ROOT / name, files)
    print(json.dumps({'검증완료': len(records), '플랫폼': list(SIZES),
                     '묶음': 'app-store/weather-care-ios-screenshots-20261030.zip'}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--topics', help='예: 02-region-notifications,03-widget,04-dark-mode')
    args = parser.parse_args()
    main(args.topics.split(',') if args.topics else None)
