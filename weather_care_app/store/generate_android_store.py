"""2026-10-21 Android 전용 스토어 이미지. 앱 코드를 바꾸지 않고 합성한다."""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import generate_store_screenshots as previous

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'screenshots/source-android-20261021'
BG, WHITE, YELLOW = '#4C77A4', '#FFFFFF', '#FFD06A'
FONT = ROOT.parent / 'assets/fonts'
TOPICS = [
    ('01-main', '오늘의 날씨 요약', '나가기 전 필요한 정보,\n한눈에 챙겨요', '준비물 체크리스트 · 지금 날씨 · 어제와 비교', 'main'),
    ('02-timeline', '시간별 타임라인', '오늘의 날씨를\n시간 따라 확인해요', '기온 · 강수 · 습도 · 자외선 · 바람 · 강설', 'timeline'),
    ('03-widget', '홈 화면 위젯', '앱을 열지 않아도\n날씨가 보여요', '작게, 넓게, 자세하게 · 세 가지 크기', None),
    ('04-dark-mode', '편안한 다크모드', '앱도 위젯도\n눈이 편안하게', '라이트 · 다크 · 시스템 설정에 맞춰', 'dark-main'),
    ('05-notifications', '다양한 날씨 알림', '챙겨야 할 날씨,\n알림으로 알려드려요', '준비물 요약 · 현재 비 · 기상특보 · 낙뢰', None),
    ('06-advanced', '심화 날씨 정보', '바다와 하천까지\n더 깊이 살펴요', '만조·간조/조위 · 수온 · 수위·유량 · 댐·보', 'advanced'),
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
    im = im.convert('RGB').resize((width, round(im.height * width / im.width)), Image.Resampling.LANCZOS)
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


def palette(dark=False):
    filename = 'values-night/colors.xml' if dark else 'values/colors.xml'
    tree = ET.parse(ROOT.parent / 'android/app/src/main/res' / filename)
    return {item.attrib['name'].removeprefix('weather_widget_'): item.text for item in tree.getroot() if item.tag == 'color'}


def widget(family, dark=False):
    """현재 네이티브 XML의 위젯 구성/색/폰트와 공유 준비물 자산으로 재현."""
    c = palette(dark)
    previous.WIDGET_SURFACE = c['background']
    previous.WIDGET_PANEL = c['panel']
    previous.WIDGET_INK = c['text_primary']
    previous.WIDGET_SECONDARY = c['text_secondary']
    previous.WIDGET_REFRESH = c['refresh_surface']
    previous.WIDGET_DATA.update(region='서울시 중구', refresh='오전 8:00 기준', current='18°', apparent='17°',
                                minimum='12°', maximum='22°', short='우산을 챙기세요', next_time='오전 9시', next_temperature='19°')
    sizes = {'small': (170, 170), 'medium': (338, 158), 'large': (338, 354)}
    w, h = sizes[family]
    scale = 3
    im = Image.new('RGBA', (w * scale, h * scale), c['background'])
    d = ImageDraw.Draw(im)
    def label(x, y, s, size, color=None, weight='Bold'):
        text(d, (x * scale, y * scale), s, round(size * scale), color or c['text_primary'], weight)
    def panel(box):
        d.rounded_rectangle(tuple(round(v * scale) for v in box), radius=10 * scale, fill=c['panel'])
    pad = {'small': 14, 'medium': 16, 'large': 18}[family]
    label(pad, 13, '서울시 중구', 12 if family == 'small' else 13)
    if family == 'small':
        label(pad, 32, '오전 8:00 기준', 9, c['text_secondary'], 'Regular')
    else:
        label(w - pad - 107, 15, '오전 8:00 기준', 10, c['text_secondary'], 'Regular')
    x = (w - pad - 24) * scale
    y = 11 * scale
    d.ellipse((x, y, x + 24 * scale, y + 24 * scale), fill=c['refresh_surface'])
    d.arc((x + 6 * scale, y + 6 * scale, x + 18 * scale, y + 18 * scale), 35, 310, fill=c['refresh_ink'], width=2 * scale)
    d.polygon([(x + 17 * scale, y + 4 * scale), (x + 20 * scale, y + 10 * scale), (x + 14 * scale, y + 9 * scale)], fill=c['refresh_ink'])
    if family == 'small':
        previous.draw_weather_icon(d, (pad * scale, 64 * scale, (pad + 58) * scale, 122 * scale), 'partlyCloudy', False)
        label(79, 72, '18°', 38, c['text_accent'], 'Heavy')
        panel((pad, h - 39, w - pad, h - 12))
        label(pad + 12, h - 31, '최저 12°  ·  최고 22°', 10)
        return im
    content_y = 49 if family == 'medium' else 67
    icon_side = 58 if family == 'medium' else 72
    previous.draw_weather_icon(d, (31 * scale, content_y * scale, (31 + icon_side) * scale, (content_y + icon_side) * scale), 'partlyCloudy', False)
    label(112, content_y + 2, '현재', 10, c['text_secondary'], 'Regular')
    label(108, content_y + 20, '18°', 34 if family == 'medium' else 38, c['text_accent'], 'Heavy')
    d.line((200 * scale, (content_y + 10) * scale, 200 * scale, (content_y + 48) * scale), fill=c['divider'], width=scale)
    label(224, content_y + 2, '체감', 10, c['text_secondary'], 'Regular')
    label(218, content_y + 20, '17°', 34 if family == 'medium' else 38, c['text_accent'], 'Heavy')
    if family == 'medium':
        panel((pad, h - 39, w - pad, h - 11))
        label(pad + 9, h - 31, '우산을 챙기세요', 11)
        label(186, h - 31, '최저 12° · 최고 22°', 10)
        return im
    label(pad + 8, 160, '아침에는 선선하고 저녁에는 비가 내려요.', 12)
    label(pad + 8, 180, '우산과 겉옷을 챙기세요.', 12)
    for i, (asset, name) in enumerate([('prep_umbrella.png', '우산'), ('prep_outerwear.png', '겉옷')]):
        left = pad + i * 154
        panel((left, 217, left + 148, 265))
        d.ellipse(((left + 10) * scale, 223 * scale, (left + 46) * scale, 259 * scale), fill=c['preparation_surface'])
        with Image.open(ROOT.parent / 'assets/icons' / asset) as src:
            icon = Image.new('RGBA', src.size, c['text_accent'])
            icon.putalpha(src.convert('RGBA').getchannel('A'))
            icon.thumbnail((25 * scale, 25 * scale), Image.Resampling.LANCZOS)
        im.alpha_composite(icon, (round((left + 15.5) * scale), round(228.5 * scale)))
        label(left + 54, 234, name, 12)
    label(pad + 10, 286, '다음 시간 예보', 11)
    label(158, 286, '오전 9시', 11, weight='Regular')
    label(258, 282, '19°', 18, c['text_accent'], 'Heavy')
    previous.draw_weather_icon(d, (293 * scale, 278 * scale, 320 * scale, 305 * scale), 'clear', True)
    panel((pad, h - 39, w - pad, h - 12))
    label(pad + 63, h - 31, '최저 12°    ·    최고 22°', 12)
    return im


def notification_cards():
    """실제 지원하는 발송 종류를 소개하는 홍보용 예시 카드. OS 캡처가 아니다."""
    im = Image.new('RGBA', (880, 1210))
    d = ImageDraw.Draw(im)
    examples = [
        ('준비물 요약', '오늘 준비할 내용', '저녁에는 비가 예상돼요.\n우산과 얇은 겉옷을 챙기세요.'),
        ('현재 비', '현재 강수 안내', '비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요.'),
        ('기상특보', '호우특보 안내', '발효된 호우특보의 시작과\n단계 변경·해제를 알려드려요.'),
        ('낙뢰', '서울시 중구 낙뢰 관측', '등록 위치로부터 약 2.4km에서 낙뢰가 관측됐어요.\n안전한 건물이나 자동차 안으로 이동하세요.'),
    ]
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
    # 동일한 1080×1920 디자인 좌표를 사용하며 태블릿 화면 자체는 별도 렌더링한다.
    canvas = Image.new('RGBA', (1080, 1920), BG)
    d = ImageDraw.Draw(canvas)
    text(d, (540, 72), eyebrow, 30, YELLOW, center=True)
    text(d, (540, 134), headline, 65, WHITE, 'Heavy', center=True, spacing=11)
    text(d, (540, 307), caption, 25, '#E6F0F7', 'Medium', center=True)
    family = 'tablet' if tablet else 'phone'
    if source:
        with Image.open(SOURCE / family / f'{source}.png') as im:
            sw = 860 if tablet else 610
            sh = round(im.height * sw / im.width)
            card(canvas, im, ((1080 - sw) / 2, 397 if not tablet else 420), sw, 22)
        if stem == '04-dark-mode':
            card(canvas, widget('large', True), (480, 1110), 530, 32)
        elif stem == '06-advanced':
            with Image.open(SOURCE / family / 'advanced-chart.png') as chart:
                # 그래프는 별도 스크롤 위치의 실제 렌더링 원본에서 크롭한다.
                crop = chart.crop((round(chart.width * .04), round(chart.height * .27), round(chart.width * .96), round(chart.height * .91)))
                card(canvas, crop, (540, 1055), 480, 25)
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
        alerts = notification_cards()
        canvas.alpha_composite(alerts, (100, 440))
        text(ImageDraw.Draw(canvas), (540, 1740), '이해를 돕기 위한 알림 예시예요', 23, '#E6F0F7', 'Regular', center=True)
    canvas = canvas.convert('RGB')
    if tablet:
        canvas = canvas.resize((width, height), Image.Resampling.LANCZOS)
    destination = ROOT / 'screenshots' / platform / f'{stem}.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)
    return destination


def feature_graphic():
    im = Image.new('RGBA', (1024, 500), BG)
    d = ImageDraw.Draw(im)
    text(d, (65, 80), '날씨챙겨', 30, YELLOW, 'ExtraBold')
    text(d, (62, 145), '날씨를 알고,\n하루를 챙겨요', 56, WHITE, 'Heavy', spacing=12)
    text(d, (65, 320), '준비물부터 바다·하천 정보까지', 22, '#E6F0F7', 'Medium')
    text(d, (65, 365), '날씨 요약  ·  위젯  ·  맞춤 알림', 21, '#E6F0F7', 'Medium')
    with Image.open(SOURCE / 'phone/main.png') as source:
        # Checklist와 현재 날씨/어제 비교는 실제 원본 두 영역으로 분리 배치한다.
        check = source.crop((48, 450, 1188, 1335))
        summary = source.crop((48, 1380, 1188, 2715))
    card(im, summary, (705, 78), 242, 16)
    card(im, check, (520, 177), 245, 16)
    target = ROOT / 'google-play/feature-graphic.png'
    im.convert('RGB').save(target, optimize=True)
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
    sheet.save(target, optimize=True)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    # 이전 최종본만 백업 후 정리한다. 원본/iOS 파일은 건드리지 않는다.
    legacy_names = ['02-today.png', '03-detail.png', '04-widget.png', '05-setting.png',
                    '06-week.png', '07-notification.png', '08-push-notification.png', '09-dark-mode.png']
    backup = ROOT.parent / 'build/store-backup-20261021'
    for platform in ['android', 'android-tablet']:
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
    for platform in ['android', 'android-tablet']:
        paths = [compose(topic, platform) for topic in TOPICS]
        generated.extend(paths)
        preview(paths, ROOT / f'screenshots/preview-{platform}.png')
    generated.append(feature_graphic())
    records = []
    for path in generated:
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            assert im.mode == 'RGB' and im.format == 'PNG'
            expected = (1024, 500) if path.name == 'feature-graphic.png' else (1440, 2560) if path.parent.name == 'android-tablet' else (1080, 1920)
            assert im.size == expected, (path, im.size)
            records.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(im.size),
                            'mode': im.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    report = ROOT / 'screenshots/android-20261021-manifest.json'
    report.write_text(json.dumps({'기준일': '2026-10-21', '화면': '현재 Flutter 코드의 비표시 렌더링',
        '데이터': '촬영용 예시 날씨와 알림, 실제 현재 관측 아님', 'files': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    package = ROOT / 'google-play/weather-care-android-store-20261021.zip'
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in generated + [ROOT / 'screenshots/preview-android.png', ROOT / 'screenshots/preview-android-tablet.png',
                                 ROOT / 'screenshots/ANDROID_20261021.md', report]:
            archive.write(path, path.relative_to(ROOT))
    with zipfile.ZipFile(package) as archive:
        assert archive.testzip() is None
    # 이전 통합 묶음도 같은 최종본으로 맞추고 iOS/iPad 항목은 그대로 보존한다.
    updated = generated + [ROOT / 'screenshots/preview-android.png', ROOT / 'screenshots/preview-android-tablet.png',
        ROOT / 'screenshots/README.md', ROOT / 'screenshots/ANDROID_20261021.md', report,
        ROOT / 'generate_android_store.py', ROOT / 'capture_android_test.dart', ROOT / 'generate_store_screenshots.py']
    names = {p.relative_to(ROOT).as_posix() for p in updated}
    for filename in ['weather-care-store-assets.zip', 'weather-care-store-screenshots.zip']:
        archive_path = ROOT / filename
        if not archive_path.exists():
            continue
        temporary = archive_path.with_suffix('.tmp.zip')
        with zipfile.ZipFile(archive_path) as old, zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as new:
            for entry in old.infolist():
                if entry.filename in names or entry.filename.startswith(('screenshots/android/', 'screenshots/android-tablet/')):
                    continue
                new.writestr(entry, old.read(entry.filename))
            for path in updated:
                new.write(path, path.relative_to(ROOT))
        with zipfile.ZipFile(temporary) as archive:
            assert archive.testzip() is None
        temporary.replace(archive_path)
    print(json.dumps({'검증완료': len(records), '압축파일': str(package)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
