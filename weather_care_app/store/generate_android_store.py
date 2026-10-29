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
SOURCE = ROOT / 'screenshots/source-android-20261028'
NATIVE = ROOT / 'screenshots/native-android-20261028'
BG, WHITE, YELLOW = '#4C77A4', '#FFFFFF', '#FFD06A'
FONT = ROOT.parent / 'assets/fonts'
TOPICS = [
    ('01-main', '오늘의 날씨 요약', '나가기 전 필요한 정보,\n한눈에 챙겨요', '지금 날씨 · 오늘 최저·최고 · 어제와 비교', 'main'),
    ('02-region-notifications', '지역별 알림', '관심 있는 지역의\n날씨 알림을 골라요', '여러 지역 저장 · 지역마다 알림 ON/OFF', 'region-notifications'),
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
    examples = [
        ('준비물 요약', '오늘 준비할 내용', '저녁에는 비가 예상돼요.\n우산과 얇은 겉옷을 챙기세요.'),
        ('현재 비', '현재 강수 안내', '비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요.'),
        ('기상특보', '호우특보 안내', '발효된 호우특보의 시작과\n단계 변경·해제를 알려드려요.'),
        ('낙뢰', '서울시 중구 낙뢰 관측', '등록 위치로부터 약 2.4km에서 낙뢰가 관측됐어요.\n안전한 건물이나 자동차 안으로 이동하세요.'),
    ]
    examples.extend(extra_examples)
    im = Image.new('RGBA', (880, len(examples) * 360 - 30))
    d = ImageDraw.Draw(im)
    for i, (kind, title, body) in enumerate(examples):
        x, y, w = (0 if i % 2 == 0 else 44), i * 360, 836
        d.rounded_rectangle((x, y, x + w, y + 330), radius=34, fill='#F6F8FB')
        d.ellipse((x + 28, y + 27, x + 66, y + 65), fill='#E5EDF5')
        previous.draw_weather_icon(d, (x + 32, y + 31, x + 62, y + 61), 'clear', True)
        text(d, (x + 80, y + 32), f'날씨챙겨  ·  {kind}', 28, '#63707A')
        text(d, (x + 32, y + 89), title, 40, '#29343D', 'ExtraBold')
        lines = []
        for paragraph in body.split('\n'):
            line = ''
            for character in paragraph:
                if d.textlength(line + character, font=font(32, 'Medium')) > w - 64:
                    lines.append(line.rstrip())
                    line = character.lstrip()
                else:
                    line += character
            lines.append(line)
        text(d, (x + 32, y + 157), '\n'.join(lines), 32, '#526374', 'Medium', spacing=12)
    return im


def compose(topic, platform):
    stem, _eyebrow, headline, _caption, source = topic
    tablet = platform == 'android-tablet'
    width, height = (1440, 2880) if tablet else (1080, 2160)
    # 두 등록 규격에 같은 실기기 촬영본을 비율 유지해 배치한다.
    canvas = Image.new('RGBA', (1080, 2160), BG)
    d = ImageDraw.Draw(canvas)
    margin, content_width = 72, 936
    title_spacing = 16
    title_box = d.multiline_textbbox((0, 0), headline, font=font(60, 'Heavy'), spacing=title_spacing)
    assert title_box[2] - title_box[0] <= content_width and title_box[3] - title_box[1] <= 140
    text(d, (540, margin), headline, 60, WHITE, 'Heavy', center=True, spacing=title_spacing)
    title_bottom = margin + title_box[3] - title_box[1]
    content_top = title_bottom + margin
    content_height = canvas.height - margin - content_top
    if source:
        im = app_screen(source)
        screen_width = round(content_height * im.width / im.height)
        assert screen_width <= content_width
        im = im.resize((screen_width, content_height), Image.Resampling.LANCZOS)
        card(canvas, im, ((canvas.width - screen_width) // 2, content_top), screen_width, 0)
        if stem == '04-dark-mode':
            card(canvas, widget('large', True), (548, 1310), 460, 32)
    elif stem == '03-widget':
        y = content_top
        widgets = [(sw, widget(kind)) for kind, sw in [
            ('small', 400), ('medium', 936), ('large', 900)]]
        total_height = sum(round(im.height * sw / im.width) for sw, im in widgets)
        gap = (canvas.height - margin - y - total_height) / 2
        for index, (sw, wim) in enumerate(widgets):
            if index == len(widgets) - 1:
                y = canvas.height - margin - round(wim.height * sw / wim.width)
            box = card(canvas, wim, ((1080 - sw) / 2, y), sw, 28)
            y = box[3] + gap
        assert box[3] == canvas.height - margin, '위젯 아래 여백이 다릅니다.'
    else:
        alerts = notification_cards([
            ('자외선', '낮 자외선이 강해요',
             '낮 동안 자외선이 높을 것으로 보여요.\n외출한다면 선크림이나 양산을 챙기세요.'),
        ])
        alerts_width = round(content_height * alerts.width / alerts.height)
        assert alerts_width <= content_width
        alerts = alerts.resize((alerts_width, content_height), Image.Resampling.LANCZOS)
        canvas.alpha_composite(alerts, ((canvas.width - alerts_width) // 2, content_top))
    canvas = canvas.convert('RGB')
    if tablet:
        canvas = canvas.resize((width, height), Image.Resampling.LANCZOS)
    # 그림자와 리사이즈 보간도 바깥 여백을 침범하지 않게 한다.
    outer_margin = round(margin * width / 1080)
    d = ImageDraw.Draw(canvas)
    d.rectangle((0, 0, width - 1, outer_margin - 1), fill=BG)
    d.rectangle((0, height - outer_margin, width - 1, height - 1), fill=BG)
    d.rectangle((0, 0, outer_margin - 1, height - 1), fill=BG)
    d.rectangle((width - outer_margin, 0, width - 1, height - 1), fill=BG)
    # 제목과 본문 사이도 그림자 없는 동일한 72px(태블릿 96px) 간격을 확보한다.
    gap_top = round(title_bottom * width / 1080)
    gap_bottom = round(content_top * width / 1080)
    d.rectangle((0, gap_top, width - 1, gap_bottom - 1), fill=BG)
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
    sheet = Image.new('RGB', (4 * 270, 2 * 562), '#E9EEF3')
    d = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        with Image.open(path) as im:
            im.thumbnail((258, 516), Image.Resampling.LANCZOS)
            x, y = (i % 4) * 270 + (270 - im.width) // 2, (i // 4) * 562
            sheet.paste(im, (x, y))
        text(d, ((i % 4) * 270 + 135, (i // 4) * 562 + 531), f'{i + 1:02d}  {TOPICS[i][1]}', 16, '#29343D', center=True)
    temporary = target.with_suffix('.tmp.png')
    sheet.save(temporary, optimize=True)
    temporary.replace(target)


def main(screenshots_only=False, platforms=None, topics=None):
    sys.stdout.reconfigure(encoding='utf-8')
    platforms = platforms or ['android', 'android-tablet']
    if not set(platforms) <= {'android', 'android-tablet'}:
        raise ValueError('Android 등록 규격만 지원합니다.')
    if topics and not set(topics) <= {topic[0] for topic in TOPICS}:
        raise ValueError('지원하지 않는 스크린샷 번호입니다.')
    generated = []
    for platform in platforms:
        old = ROOT / 'screenshots' / platform / '02-timeline.png'
        if old.exists():
            backup = ROOT.parent / 'build/screenshots-backup-20261028' / platform
            backup.mkdir(parents=True, exist_ok=True)
            shutil.copy2(old, backup / old.name)
            old.unlink()
        paths = [compose(topic, platform) if not topics or topic[0] in topics
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
            expected = (1024, 500) if path.name == 'feature-graphic.png' else {
                'android': (1080, 2160), 'android-tablet': (1440, 2880)}[path.parent.name]
            assert im.mode == 'RGB' and im.format == 'PNG' and im.size == expected
            records.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(im.size),
                            'mode': im.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    report = ROOT / 'screenshots/screenshots-20261029-manifest.json'
    report.write_text(json.dumps({
        '기준일': '2026-10-28',
        '편집일': '2026-10-29',
        '배치': '상단 제목 60px 두 줄, 줄간격 16px. 바깥 사방 및 제목·본문 사이 간격 모두 72px(태블릿 96px). 이미지는 남은 높이에 비율 유지 배치. 작은 분류명·부연 설명·위젯 크기 라벨 생략.',
        '화면': '연결 SM-S948U에서 최신 제품 화면을 실행한 별도 Debug 촬영 패키지의 ADB screencap 및 실제 Android AppWidgetHost',
        '데이터': '실제 운영 서버 자료. 지역 저장 및 알림 선택 상태는 촬영용 별도 설정. 5번은 지원 기능 소개용 알림 예시.',
        '태블릿': '같은 휴대전화 촬영본을 태블릿 등록 규격에 비율 유지해 배치. 실제 태블릿 촬영 아님.',
        '구성': '2번을 지역별 알림으로 교체. 앱 화면은 시스템 상태바·내비게이션바만 제외. 4번은 실제 다크 대형 위젯을 함께 배치.',
        'files': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    preview_paths = [ROOT / f'screenshots/preview-{platform}.png' for platform in platforms]
    guide = ROOT / 'screenshots/SCREENSHOTS_20261029.md'
    package = ROOT / 'weather-care-android-screenshots-20261029.zip'
    # Android 전용 새 묶음만 작성한다. 과거 묶음과 iOS 자료는 보존한다.
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in generated + preview_paths + [guide, report]:
            archive.write(path, path.relative_to(ROOT))
    with zipfile.ZipFile(package) as archive:
        assert archive.testzip() is None
        assert len([name for name in archive.namelist() if name.startswith('screenshots/android')]) == len(generated)
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
