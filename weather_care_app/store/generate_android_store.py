"""실제 Android 기기의 앱·위젯 캡처로 스토어 이미지를 구성한다."""
from __future__ import annotations

import hashlib
import argparse
import json
import shutil
import sys
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import generate_store_screenshots as previous

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'screenshots/source-android-20261023'
NATIVE = ROOT / 'screenshots/native-android-20261023'
BG, WHITE, YELLOW = '#4C77A4', '#FFFFFF', '#FFD06A'
FONT = ROOT.parent / 'assets/fonts'
TOPICS = [
    ('01-main', '오늘의 날씨 요약', '나가기 전 필요한 정보,\n한눈에 챙겨요', '지금 날씨 · 오늘 최저·최고 · 어제와 비교', 'main'),
    ('02-timeline', '시간별 타임라인', '오늘의 날씨를\n시간 따라 확인해요', '기온 · 강수 · 습도 · 자외선 · 바람 · 강설', 'timeline'),
    ('03-widget', '홈 화면 위젯', '앱을 열지 않아도\n날씨가 보여요', '작게, 넓게, 자세하게 · 세 가지 크기', None),
    ('04-dark-mode', '편안한 다크모드', '앱도 위젯도\n눈이 편안하게', '라이트 · 다크 · 시스템 설정에 맞춰', 'dark-main'),
    ('05-notifications', '다양한 날씨 알림', '챙겨야 할 날씨,\n알림으로 알려드려요', '준비물 요약 · 현재 비 · 기상특보 · 낙뢰 · 자외선', None),
    ('06-advanced', '심화 날씨 정보', '바다와 하천까지\n더 깊이 살펴요', '만조·간조/조위 · 수온 · 수위·유량 · 댐·보', 'advanced-values'),
    ('07-week', '한주 날씨', '한 주의 흐름을 보고\n하루를 계획해요', '주간 요약 · 날짜별 예보 · 시간별 날씨', 'week'),
    ('08-notification-settings', '원하는 알림만', '받고 싶은 알림만\n켜고 끌 수 있어요', '준비물부터 기상·생활 알림까지, 하나씩 선택', 'notification-settings'),
]


def font(size: int, weight: str = 'Bold'):
    return ImageFont.truetype(str(FONT / f'SUITE-{weight}.ttf'), size)


def text(draw, xy, value, size, fill=WHITE, weight='Bold', center=False, spacing=9):
    f = font(size, weight)
    box = draw.multiline_textbbox((0, 0), value, font=f, spacing=spacing, align='center' if center else 'left')
    x, y = xy
    if center:
        x -= (box[2] - box[0]) / 2
    draw.multiline_text((x, y - box[1]), value, font=f, fill=fill, spacing=spacing,
                        align='center' if center else 'left')
    return box[3] - box[1]


def rounded(im, width, radius=24):
    im = im.convert('RGBA').resize((width, round(im.height * width / im.width)), Image.Resampling.LANCZOS)
    mask = Image.new('L', im.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius, fill=255)
    result = Image.new('RGBA', im.size)
    result.paste(im, (0, 0), mask)
    return result


def card(canvas, im, xy, width, radius=24):
    im = rounded(im, width, radius)
    x, y = map(round, xy)
    shadow = Image.new('RGBA', canvas.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 12, x + im.width, y + im.height + 12), radius, fill=(17, 37, 57, 95))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)))
    canvas.alpha_composite(im, (x, y))
    return (x, y, x + im.width, y + im.height)


def widget(family, dark=False):
    """실제 Android Provider를 AppWidgetHost에 연결해 촬영한 원본만 사용한다."""
    path = NATIVE / f'{"dark" if dark else "light"}-{family}.png'
    if not path.exists():
        raise FileNotFoundError(f'실제 네이티브 위젯 원본이 필요합니다: {path}')
    with Image.open(path) as source:
        return source.convert('RGBA')


def app_screen(name):
    """실제 앱 전체 화면에서 상단 상태바와 하단 시스템 내비게이션바를 제외한다."""
    manifest = json.loads((SOURCE / 'capture-manifest.json').read_text(encoding='utf-8'))
    row = next(row for row in manifest['files'] if row['path'] == f'{name}.png')
    path = SOURCE / row['path']
    if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
        raise ValueError(f'촬영 원본 해시가 다릅니다: {path}')
    with Image.open(path) as source:
        left, top, right, bottom = row['system_navigation_bar']
        if (left, right, bottom) != (0, source.width, source.height) or not 0 < top < bottom:
            raise ValueError(f'시스템 내비게이션바 영역을 확인할 수 없습니다: {path}')
        status_left, status_top, status_right, status_bottom = row['system_status_bar']
        if (status_left, status_top, status_right) != (0, 0, source.width) or not 0 < status_bottom < top:
            raise ValueError(f'상단 시스템 상태바 영역을 확인할 수 없습니다: {path}')
        return source.crop((0, status_bottom, source.width, top)).convert('RGB')


def notification_cards(extra_examples=()):
    """실제 지원하는 발송 종류를 소개하는 홍보용 예시 카드. OS 캡처가 아니다."""
    im = Image.new('RGBA', (880, 1210 + 293 * len(extra_examples)))
    d = ImageDraw.Draw(im)
    examples = [
        ('준비물 요약', '오늘 준비할 내용', '저녁에는 비가 예상돼요.\n우산과 얇은 겉옷을 챙기세요.'),
        ('현재 비', '현재 강수 안내', '비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요.'),
        ('기상특보', '호우특보 안내', '발효된 호우특보의 시작과\n단계 변경·해제를 알려드려요.'),
        ('낙뢰', '서울시 중구 낙뢰 관측', '등록 위치로부터 약 2.4km에서 낙뢰가 관측됐어요.\n안전한 건물이나 자동차 안으로 이동하세요.'),
    ]
    examples.extend(extra_examples)
    for i, (kind, title, body) in enumerate(examples):
        x, y, w = (0 if i % 2 == 0 else 44), i * 293, 836
        d.rounded_rectangle((x, y, x + w, y + 264), radius=34, fill='#F6F8FB')
        d.ellipse((x + 28, y + 27, x + 66, y + 65), fill='#E5EDF5')
        previous.draw_weather_icon(d, (x + 32, y + 31, x + 62, y + 61), 'clear', True)
        text(d, (x + 80, y + 32), f'날씨챙겨  ·  {kind}', 24, '#63707A')
        text(d, (x + 32, y + 89), title, 35, '#29343D', 'ExtraBold')
        text(d, (x + 32, y + 153), body, 25, '#526374', 'Medium', spacing=12)
    return im


def compose(topic, platform):
    stem, eyebrow, headline, caption, source = topic
    tablet = platform == 'android-tablet'
    width, height = (1440, 2560) if tablet else (1080, 1920)
    # 두 등록 규격에 같은 실기기 촬영본을 비율 유지해 배치한다.
    canvas = Image.new('RGBA', (1080, 1920), BG)
    d = ImageDraw.Draw(canvas)
    text(d, (540, 72), eyebrow, 30, YELLOW, center=True)
    text(d, (540, 134), headline, 65, WHITE, 'Heavy', center=True, spacing=11)
    text(d, (540, 307), caption, 25, '#E6F0F7', 'Medium', center=True)
    if source:
        im = app_screen(source)
        card(canvas, im, (215, 397), 650, 0)
        if stem == '04-dark-mode':
            card(canvas, widget('large', True), (530, 1350), 480, 32)
    elif stem == '03-widget':
        y = 409
        for kind, label, sw in [('small', '작은 위젯', 260), ('medium', '중간 위젯', 660), ('large', '큰 위젯', 570)]:
            text(d, (540, y), label, 24, '#E6F0F7', center=True)
            y += 43
            wim = widget(kind)
            box = card(canvas, wim, ((1080 - sw) / 2, y), sw, 28)
            y = box[3] + 39
        # 세 크기는 모두 비율 유지. 위젯 합계가 1920px를 넘지 않도록 축소 배치.
    else:
        alerts = notification_cards([
            ('자외선', '낮 자외선이 강해요',
             '낮 동안 자외선이 높을 것으로 보여요.\n외출한다면 선크림이나 양산을 챙기세요.'),
        ])
        alerts = alerts.resize((800, round(alerts.height * 800 / alerts.width)), Image.Resampling.LANCZOS)
        canvas.alpha_composite(alerts, (140, 440))
    canvas = canvas.convert('RGB')
    if tablet:
        canvas = canvas.resize((width, height), Image.Resampling.LANCZOS)
    destination = ROOT / 'screenshots' / platform / f'{stem}.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix('.tmp.png')
    canvas.save(temporary, optimize=True)
    temporary.replace(destination)
    return destination


def feature_graphic():
    # 2026-10-22 확정한 준비물 캠페인 원본. 스크린샷과 독립적으로 내보낸다.
    target = ROOT / 'google-play/feature-graphic.png'
    with Image.open(ROOT / 'google-play/source/feature-graphic.png') as source:
        source.convert('RGB').resize((1024, 500), Image.Resampling.LANCZOS).save(target, optimize=True)
    return target


def preview(paths, target):
    sheet = Image.new('RGB', (4 * 270, 2 * 500), '#E9EEF3')
    d = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        with Image.open(path) as im:
            im.thumbnail((258, 459), Image.Resampling.LANCZOS)
            x, y = (i % 4) * 270 + (270 - im.width) // 2, (i // 4) * 500
            sheet.paste(im, (x, y))
        text(d, ((i % 4) * 270 + 135, (i // 4) * 500 + 470), f'{i + 1:02d}  {TOPICS[i][1]}', 16, '#29343D', center=True)
    temporary = target.with_suffix('.tmp.png')
    sheet.save(temporary, optimize=True)
    temporary.replace(target)


def main(screenshots_only=False, platforms=None, topics=None):
    sys.stdout.reconfigure(encoding='utf-8')
    # 이전 최종본만 백업 후 정리한다. 원본/iOS 파일은 건드리지 않는다.
    legacy_names = ['02-today.png', '03-detail.png', '04-widget.png', '05-setting.png',
                    '06-week.png', '07-notification.png', '08-push-notification.png', '09-dark-mode.png']
    platforms = platforms or ['android', 'android-tablet']
    assert set(platforms) <= {'android', 'android-tablet'}
    if topics and not set(topics) <= {topic[0] for topic in TOPICS}:
        raise ValueError('지원하지 않는 스크린샷 번호입니다.')
    backup = ROOT.parent / 'build/screenshots-backup-20261022'
    for platform in platforms:
        for name in legacy_names:
            old = ROOT / 'screenshots' / platform / name
            assert old.resolve().is_relative_to(ROOT.resolve())
            if old.exists():
                saved = backup / 'screenshots' / platform / name
                saved.parent.mkdir(parents=True, exist_ok=True)
                if not saved.exists():
                    shutil.copy2(old, saved)
                old.unlink()
    generated = []
    for platform in platforms:
        paths = [compose(topic, platform) if (not topics or topic[0] in topics)
                 and (topic[0] != '05-notifications' or topics is not None)
                 else ROOT / 'screenshots' / platform / f'{topic[0]}.png'
                 for topic in TOPICS]
        generated.extend(paths)
        preview(paths, ROOT / f'screenshots/preview-{platform}.png')
    if not screenshots_only:
        generated.append(feature_graphic())
    records = []
    for path in generated:
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            assert im.mode == 'RGB' and im.format == 'PNG'
            expected = (1024, 500) if path.name == 'feature-graphic.png' else {
                'android': (1080, 1920), 'android-tablet': (1440, 2560),
                'ios': (1320, 2868), 'ipad': (2064, 2752)}[path.parent.name]
            assert im.size == expected, (path, im.size)
            records.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(im.size),
                            'mode': im.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    report = ROOT / 'screenshots/screenshots-20261023-manifest.json'
    report.write_text(json.dumps({'기준일': '2026-10-23', '화면': 'SM-S948U 실제 앱 screencap 및 Android AppWidgetHost 촬영',
        '데이터': 'Main·Week·타임라인·위젯은 운영 서버, 심화 정보는 테스트 서버에 수집한 2026-10-23 실제 관측·예측. 5번은 알림 예시 5개.',
        '태블릿': '같은 휴대전화 촬영본을 태블릿 등록 규격에 비율 유지해 배치',
        '구성': '앱 1·2·4·6·7·8번은 상단 상태바·하단 시스템 내비게이션바를 제외한 앱 전체 화면을 사용. 앱 탭 메뉴는 유지하며 4번은 실제 다크 위젯도 함께 배치. 3번 위젯과 5번 알림 소개는 기존 구성.',
        'files': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    preview_paths = [ROOT / f'screenshots/preview-{platform}.png' for platform in platforms]
    guide = ROOT / 'screenshots/SCREENSHOTS_20261023.md'
    package = ROOT / 'weather-care-screenshots-20261023.zip'
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in generated + preview_paths + [guide, report]:
            archive.write(path, path.relative_to(ROOT))
    with zipfile.ZipFile(package) as archive:
        assert archive.testzip() is None
    shutil.copy2(package, ROOT / 'weather-care-screenshots-20261022.zip')
    shutil.copy2(report, ROOT / 'screenshots/screenshots-20261022-manifest.json')
    # 이전 통합 묶음도 같은 최종본으로 맞추고 iOS/iPad 항목은 그대로 보존한다.
    legacy_report = ROOT / 'screenshots/android-20261021-manifest.json'
    legacy_data = json.loads(legacy_report.read_text(encoding='utf-8'))
    by_path = {row['path']: row for row in records}
    for row in legacy_data['files']:
        if row['path'] in by_path:
            row.update(by_path[row['path']], 갱신일='2026-10-23')
    legacy_report.write_text(json.dumps(legacy_data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    updated = generated + preview_paths + [
        ROOT / 'screenshots/README.md', guide, legacy_report, report,
        ROOT / 'screenshots/screenshots-20261022-manifest.json',
        ROOT / 'generate_android_store.py', ROOT / 'capture_android_test.dart', ROOT / 'generate_store_screenshots.py',
        ROOT / 'capture_native_widgets.py', *sorted((ROOT / 'native_widget_capture').glob('*')),
        *sorted(NATIVE.glob('*')), *sorted(SOURCE.glob('*'))]
    names = {p.relative_to(ROOT).as_posix() for p in updated}
    for filename in ['weather-care-store-assets.zip', 'weather-care-store-screenshots.zip',
                     'google-play/weather-care-android-store-20261021.zip']:
        archive_path = ROOT / filename
        if not archive_path.exists():
            continue
        temporary = archive_path.with_suffix('.tmp.zip')
        with zipfile.ZipFile(archive_path) as old, zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as new:
            for entry in old.infolist():
                if entry.filename in names or entry.filename.startswith(tuple(f'screenshots/{p}/' for p in platforms)):
                    continue
                new.writestr(entry, old.read(entry.filename))
            for path in updated:
                new.write(path, path.relative_to(ROOT))
        with zipfile.ZipFile(temporary) as archive:
            assert archive.testzip() is None
        temporary.replace(archive_path)
    print(json.dumps({'검증완료': len(records), '압축파일': str(package)}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='현재 UI 스토어 스크린샷 생성')
    parser.add_argument('--screenshots-only', action='store_true', help='그래픽·헤더·검색 결과를 변경하지 않고 스크린샷만 생성')
    parser.add_argument('--platforms', help='android,android-tablet 중 쉼표로 구분')
    parser.add_argument('--topics', help='다시 만들 화면 이름을 쉼표로 구분 (예: 03-widget)')
    args = parser.parse_args()
    selected = args.platforms.split(',') if args.platforms else None
    main(screenshots_only=args.screenshots_only, platforms=selected,
         topics=args.topics.split(',') if args.topics else None)
