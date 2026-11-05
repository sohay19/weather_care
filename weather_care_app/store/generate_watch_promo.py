"""실제 워치 앱 캡처를 앱 스토어 이미지와 같은 스타일의 홍보 카드로 배치한다."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageOps

import generate_android_store as common
from generate_ios_store import watch_screen as apple_screen

ROOT = Path(__file__).resolve().parent / 'screenshots'
SIZE = (1080, 1350)
TOPICS = (
    ('current', '현재 날씨', '손목에서 바로 보는\n지금 날씨'),
    ('prep', '오늘의 준비물', '나가기 전에\n오늘의 준비물을 챙겨요'),
    ('timeline', '타임라인', '시간대별 날씨와\n비 올 확률을 살펴봐요'),
    ('life', '기상·생활', '습도부터 자외선까지\n생활에 필요한 날씨'),
    ('widget', '워치 위젯', '앱을 열지 않고\n손목에서 날씨를 확인해요'),
)


def compose(screen, platform, topic, headline, round_watch):
    canvas_size = (1080, 1080) if round_watch else SIZE
    canvas = Image.new('RGBA', canvas_size, common.BG)
    draw = ImageDraw.Draw(canvas)
    common.text(draw, (540, 48 if round_watch else 67), platform, 36, common.YELLOW, center=True)
    common.text(draw, (540, 105 if round_watch else 132), headline, 66 if round_watch else 74, weight='Heavy', center=True, spacing=12)

    width = 508 if round_watch else 568
    height = round(width * screen.height / screen.width)
    x = (SIZE[0] - width) // 2
    y = (615 if round_watch else 759) - height // 2
    radius = width // 2 if round_watch else 108

    # 밴드와 케이스는 원본 앱 화면 바깥에 배치한다.
    draw.rounded_rectangle((386, y - 75, 694, y + height + 80), radius=43, fill='#27435F')
    draw.rounded_rectangle((407, y - 75, 673, y + height + 80), radius=36, fill='#344F6D')
    button_x = x + width - 25 if round_watch else x + width + 11
    draw.rounded_rectangle((button_x, y + 129, button_x + 31, y + 207),
                           radius=12, fill='#283544')
    if round_watch:
        draw.rounded_rectangle((x + width + 9, y + 225, x + width + 37, y + 274),
                               radius=10, fill='#283544')
    bezel = (x - 24, y - 24, x + width + 23, y + height + 23)
    draw.rounded_rectangle(bezel, radius=radius + 24, fill='#111B29',
                           outline='#A4BDD6', width=4)
    mask = Image.new('L', (width, height))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    fitted = ImageOps.contain(screen.convert('RGB'), (width, height), Image.Resampling.LANCZOS)
    canvas.paste(fitted, (x, y), mask.crop((0, 0, fitted.width, fitted.height)))

    label_y = 958 if round_watch else 1212
    draw.rounded_rectangle((367, label_y, 713, label_y + 72), radius=36, fill='#315781')
    common.text(draw, (540, label_y + 15), topic, 36, center=True)
    output_size = (438, 438) if round_watch else (416, 496)
    canvas = ImageOps.fit(canvas, output_size, Image.Resampling.LANCZOS)
    return canvas.convert('RGB')


def main():
    for folder, platform in (('watchos-promo', 'Apple Watch'), ('wear-os-promo', 'Galaxy Watch · Wear OS')):
        round_watch = folder == 'wear-os-promo'
        output = ROOT / folder
        output.mkdir(exist_ok=True)
        with ZipFile(ROOT / f'{folder}-20261104.zip', 'w', ZIP_DEFLATED) as archive:
            for index, (name, topic, headline) in enumerate(TOPICS, start=1):
                filename = f'{index:02}-{name}.png'
                if round_watch:
                    source_name = 'tile' if name == 'widget' else name
                    with Image.open(ROOT / 'source-wear-20261104' / f'{source_name}.png') as screen:
                        card = compose(screen, platform, topic, headline, round_watch)
                else:
                    source_name = 'smart-stack' if name == 'widget' else name
                    card = compose(apple_screen(source_name), platform, topic, headline, round_watch)
                card.save(output / filename)
                archive.write(output / filename, filename)


if __name__ == '__main__':
    main()
