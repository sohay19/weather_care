from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE_DIR = ROOT / "screenshots" / "source"
TABLET_SOURCE_DIR = ROOT / "screenshots" / "source-tablet"
OUTPUT_DIR = ROOT / "screenshots"
GOOGLE_PLAY_DIR = ROOT / "google-play"
FONT_DIR = ROOT.parent / "assets" / "fonts"

BACKGROUND = "#4C77A4"
HEADLINE_COLOR = "#FFFFFF"
LABEL_COLOR = "#FFD06A"

SCREENS = [
    ("01-main", "main.png", "MAIN", "오늘 챙길 것만\n한눈에"),
    ("02-today", "today.png", "TODAY", "시간대별 날씨를\n하루 흐름으로"),
    ("03-detail", "detail.png", "DETAIL", "판단 근거까지\n자세히"),
    ("04-week", "week.png", "WEEK", "일주일 계획을\n미리 가볍게"),
    ("05-setting", "setting.png", "SETTING", "내 위치와 알림을\n내 생활에 맞게"),
]

FORMATS = {
    "android": {
        "size": (1080, 1920),
        "label_y": 90,
        "label_size": 30,
        "headline_y": 140,
        "headline_size": 72,
        "headline_spacing": 2,
        "screen_y": 335,
        "screen_width": 700,
        "radius": 24,
        "shadow_blur": 26,
        "shadow_offset": 18,
    },
    "ios": {
        "size": (1320, 2868),
        "label_y": 118,
        "label_size": 38,
        "headline_y": 182,
        "headline_size": 94,
        "headline_spacing": 4,
        "screen_y": 510,
        "screen_width": 1020,
        "radius": 34,
        "shadow_blur": 38,
        "shadow_offset": 24,
    },
}

TABLET_FORMATS = {
    "android-tablet": {
        "size": (1440, 2560),
        "label_y": 94,
        "label_size": 36,
        "headline_y": 152,
        "headline_size": 86,
        "headline_spacing": 2,
        "screen_y": 560,
        "screen_width": 1010,
        "radius": 30,
        "shadow_blur": 34,
        "shadow_offset": 22,
    },
    "ipad": {
        "size": (2064, 2752),
        "label_y": 92,
        "label_size": 42,
        "headline_y": 158,
        "headline_size": 98,
        "headline_spacing": 2,
        "screen_y": 480,
        "screen_width": 1240,
        "radius": 34,
        "shadow_blur": 42,
        "shadow_offset": 26,
    },
}


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size=size)


def rounded_screen(source: Image.Image, width: int, radius: int) -> Image.Image:
    height = round(source.height * width / source.width)
    resized = source.resize((width, height), Image.Resampling.LANCZOS).convert("RGB")
    mask = Image.new("L", resized.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, resized.width - 1, resized.height - 1),
        radius=radius,
        fill=255,
    )
    result = Image.new("RGBA", resized.size, (255, 255, 255, 0))
    result.paste(resized, (0, 0), mask)
    return result


def compose(source_path: Path, destination: Path, label: str, headline: str, spec: dict) -> None:
    canvas_width, canvas_height = spec["size"]
    canvas = Image.new("RGB", (canvas_width, canvas_height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    label_font = font("SUITE-Bold.ttf", spec["label_size"])
    headline_font = font("SUITE-Heavy.ttf", spec["headline_size"])

    label_box = draw.textbbox((0, 0), label, font=label_font)
    label_width = label_box[2] - label_box[0]
    draw.text(
        ((canvas_width - label_width) / 2, spec["label_y"]),
        label,
        font=label_font,
        fill=LABEL_COLOR,
    )

    headline_box = draw.multiline_textbbox(
        (0, 0),
        headline,
        font=headline_font,
        spacing=spec["headline_spacing"],
        align="center",
    )
    headline_width = headline_box[2] - headline_box[0]
    draw.multiline_text(
        ((canvas_width - headline_width) / 2, spec["headline_y"]),
        headline,
        font=headline_font,
        fill=HEADLINE_COLOR,
        spacing=spec["headline_spacing"],
        align="center",
    )

    with Image.open(source_path) as source:
        screen = rounded_screen(source, spec["screen_width"], spec["radius"])

    screen_x = (canvas_width - screen.width) // 2
    screen_y = spec["screen_y"]
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (
            screen_x,
            screen_y + spec["shadow_offset"],
            screen_x + screen.width,
            screen_y + screen.height + spec["shadow_offset"],
        ),
        radius=spec["radius"],
        fill=(20, 40, 55, 92),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(spec["shadow_blur"]))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.alpha_composite(screen, (screen_x, screen_y))

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)


def contact_sheet(platform: str) -> None:
    source_paths = [OUTPUT_DIR / platform / f"{stem}.png" for stem, *_ in SCREENS]
    with Image.open(source_paths[0]) as first:
        thumb_height = 820
        thumb_width = round(first.width * thumb_height / first.height)
    gap = 36
    margin = 54
    sheet_width = margin * 2 + thumb_width * len(source_paths) + gap * (len(source_paths) - 1)
    sheet_height = thumb_height + margin * 2
    sheet = Image.new("RGB", (sheet_width, sheet_height), "#E9EEF2")
    x = margin
    for source_path in source_paths:
        with Image.open(source_path) as source:
            thumb = source.resize((thumb_width, thumb_height), Image.Resampling.LANCZOS).convert("RGB")
        sheet.paste(thumb, (x, margin))
        x += thumb_width + gap
    sheet.save(OUTPUT_DIR / f"preview-{platform}.png", format="PNG", optimize=True)


def create_google_play_feature_graphic() -> None:
    width, height = 1024, 500
    canvas = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    # 가장자리의 날씨 장식은 배경 역할만 하며, 핵심 문구와 UI는 중앙
    # 안전영역에 배치한다.
    draw.ellipse((846, -92, 1058, 120), fill="#FFC247")
    draw.ellipse((-54, 392, 74, 520), fill="#6FAAF0")
    draw.ellipse((42, 438, 116, 512), fill="#8CC2FF")

    app_name_font = font("SUITE-Bold.ttf", 30)
    headline_font = font("SUITE-Heavy.ttf", 58)
    supporting_font = font("SUITE-Medium.ttf", 23)

    draw.text((102, 106), "날씨챙겨", font=app_name_font, fill=LABEL_COLOR)
    draw.multiline_text(
        (98, 154),
        "오늘 필요한 날씨,\n미리 챙겨요",
        font=headline_font,
        fill=HEADLINE_COLOR,
        spacing=-2,
    )
    draw.text(
        (102, 335),
        "생활에 필요한 날씨만 한눈에",
        font=supporting_font,
        fill="#E6F0F7",
    )

    with Image.open(SOURCE_DIR / "main.png") as source:
        # 기기 프레임 대신 실제 Main 화면의 위치·브리핑 영역만 사용한다.
        crop = source.crop((34, 76, 1046, 1180)).convert("RGB")
        crop.thumbnail((390, 430), Image.Resampling.LANCZOS)

    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, crop.width - 1, crop.height - 1),
        radius=26,
        fill=255,
    )
    ui_card = Image.new("RGBA", crop.size, (255, 255, 255, 0))
    ui_card.paste(crop, (0, 0), mask)

    card_x = 574
    card_y = (height - ui_card.height) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (card_x, card_y + 12, card_x + ui_card.width, card_y + ui_card.height + 12),
        radius=26,
        fill=(22, 42, 58, 88),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.alpha_composite(ui_card, (card_x, card_y))

    GOOGLE_PLAY_DIR.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(
        GOOGLE_PLAY_DIR / "feature-graphic.png",
        format="PNG",
        optimize=True,
    )


def create_google_play_app_icon() -> None:
    with Image.open(ROOT / "appIcon.png") as source:
        icon = source.convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS)
    GOOGLE_PLAY_DIR.mkdir(parents=True, exist_ok=True)
    icon.save(GOOGLE_PLAY_DIR / "app-icon-512.png", format="PNG", optimize=True)


def main() -> None:
    for platform, spec in FORMATS.items():
        for stem, source_name, label, headline in SCREENS:
            compose(
                SOURCE_DIR / source_name,
                OUTPUT_DIR / platform / f"{stem}.png",
                label,
                headline,
                spec,
            )
        contact_sheet(platform)
    for platform, spec in TABLET_FORMATS.items():
        for stem, source_name, label, headline in SCREENS:
            compose(
                TABLET_SOURCE_DIR / source_name,
                OUTPUT_DIR / platform / f"{stem}.png",
                label,
                headline,
                spec,
            )
        contact_sheet(platform)
    create_google_play_feature_graphic()
    create_google_play_app_icon()


if __name__ == "__main__":
    main()
