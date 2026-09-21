from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "docs" / "icon-previews"
FONT_REGULAR = ROOT / "weather_care_app" / "assets" / "fonts" / "SUITE-Regular.ttf"
FONT_BOLD = ROOT / "weather_care_app" / "assets" / "fonts" / "SUITE-Bold.ttf"

PNG_SIZE = 512
RENDER_SCALE = 4
RENDER_SIZE = PNG_SIZE * RENDER_SCALE

INK = (37, 55, 78, 255)
SUN = (246, 183, 55, 255)
CLOUD = (249, 252, 255, 255)
CLOUD_BLUE = (118, 151, 180, 255)
CLOUD_DARK = (84, 112, 139, 255)
RAIN = (73, 143, 203, 255)
QUESTION = (118, 133, 151, 255)
PREPARATION_CIRCLE = (226, 239, 248, 255)
WIDGET_BACKGROUND = (234, 244, 251, 255)
PAGE_BACKGROUND = (246, 247, 248, 255)
TEXT = (41, 52, 61, 255)


PREPARATION_ITEMS = [
    ("umbrella", "우산"),
    ("parasol", "양산"),
    ("heavy_snow_caution", "많은 눈 대비"),
    ("outerwear", "겉옷"),
    ("mask", "마스크"),
    ("water", "물"),
    ("sunscreen", "선크림"),
]

WEATHER_ITEMS = [
    ("clear", "맑음"),
    ("partly_cloudy", "구름 많음"),
    ("overcast", "흐림"),
    ("drizzle", "빗방울"),
    ("rain", "비"),
    ("shower", "소나기"),
    ("light_wintry_mix", "빗방울·눈날림"),
    ("wintry_mix", "비·눈"),
    ("snow_flurry", "눈날림"),
    ("snow", "눈"),
    ("unknown", "정보 없음"),
]


def _point(rect: tuple[float, float, float, float], x: float, y: float) -> tuple[float, float]:
    left, top, right, bottom = rect
    return (left + (right - left) * x / 100, top + (bottom - top) * y / 100)


def _rect(
    rect: tuple[float, float, float, float],
    left: float,
    top: float,
    right: float,
    bottom: float,
) -> tuple[float, float, float, float]:
    x1, y1 = _point(rect, left, top)
    x2, y2 = _point(rect, right, bottom)
    return x1, y1, x2, y2


def _sample_cubic(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int = 40,
) -> list[tuple[float, float]]:
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        points.append(
            (
                u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
            )
        )
    return points


def _sample_quadratic(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    steps: int = 28,
) -> list[tuple[float, float]]:
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        points.append(
            (
                u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
            )
        )
    return points


def _line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    draw.line(points, fill=color, width=width, joint="curve")
    radius = width / 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def _downsample(image: Image.Image) -> Image.Image:
    return image.resize((PNG_SIZE, PNG_SIZE), Image.Resampling.LANCZOS)


def _draw_snowflake(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    for index in range(3):
        angle = math.pi * index / 3
        dx = math.cos(angle) * radius
        dy = math.sin(angle) * radius
        _line(draw, [(center[0] - dx, center[1] - dy), (center[0] + dx, center[1] + dy)], color, width)


def render_preparation(kind: str) -> Image.Image:
    image = Image.new("RGBA", (RENDER_SIZE, RENDER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    center = RENDER_SIZE / 2
    draw.ellipse(
        (
            center - RENDER_SIZE * 0.48,
            center - RENDER_SIZE * 0.48,
            center + RENDER_SIZE * 0.48,
            center + RENDER_SIZE * 0.48,
        ),
        fill=PREPARATION_CIRCLE,
    )

    inset = RENDER_SIZE * 0.18
    rect = (inset, inset, RENDER_SIZE - inset, RENDER_SIZE - inset)
    side = rect[2] - rect[0]
    width = max(1, round(side * 0.075))

    if kind in {"umbrella", "parasol"}:
        draw.arc(_rect(rect, 13, 20, 87, 74), start=190, end=350, fill=INK, width=width)
        handle = [_point(rect, 50, 47), _point(rect, 50, 77)]
        handle += _sample_cubic(
            _point(rect, 50, 77),
            _point(rect, 50, 88),
            _point(rect, 68, 88),
            _point(rect, 68, 77),
        )[1:]
        _line(draw, handle, INK, width)
        if kind == "parasol":
            sun_center = _point(rect, 77, 19)
            sun_radius = side * 0.07
            draw.ellipse(
                (
                    sun_center[0] - sun_radius,
                    sun_center[1] - sun_radius,
                    sun_center[0] + sun_radius,
                    sun_center[1] + sun_radius,
                ),
                outline=INK,
                width=width,
            )
            for index in range(4):
                angle = math.pi * index / 2
                direction = (math.cos(angle), math.sin(angle))
                _line(
                    draw,
                    [
                        (sun_center[0] + direction[0] * side * 0.10, sun_center[1] + direction[1] * side * 0.10),
                        (sun_center[0] + direction[0] * side * 0.14, sun_center[1] + direction[1] * side * 0.14),
                    ],
                    INK,
                    width,
                )
    elif kind == "heavy_snow_caution":
        _draw_snowflake(draw, _point(rect, 50, 50), side * 0.34, INK, width)
    elif kind == "outerwear":
        points = [
            _point(rect, 38, 20),
            _point(rect, 20, 36),
            _point(rect, 27, 55),
            _point(rect, 36, 50),
            _point(rect, 33, 86),
            _point(rect, 67, 86),
            _point(rect, 64, 50),
            _point(rect, 73, 55),
            _point(rect, 80, 36),
            _point(rect, 62, 20),
            _point(rect, 50, 34),
            _point(rect, 38, 20),
        ]
        _line(draw, points, INK, width)
        _line(draw, [_point(rect, 50, 34), _point(rect, 50, 85)], INK, width)
    elif kind == "mask":
        mask_rect = _rect(rect, 20, 30, 80, 72)
        draw.rounded_rectangle(mask_rect, radius=side * 0.11, outline=INK, width=width)
        draw.arc(_rect(rect, 5, 32, 29, 73), start=90, end=270, fill=INK, width=width)
        draw.arc(_rect(rect, 71, 32, 95, 73), start=-90, end=90, fill=INK, width=width)
        _line(draw, [_point(rect, 30, 46), _point(rect, 70, 46)], INK, width)
        _line(draw, [_point(rect, 30, 58), _point(rect, 70, 58)], INK, width)
    elif kind in {"water", "sunscreen"}:
        body_rect = _rect(rect, 31, 31, 69, 88)
        draw.rounded_rectangle(body_rect, radius=side * 0.08, outline=INK, width=width)
        draw.rectangle(_rect(rect, 40, 17, 60, 31), outline=INK, width=width)
        if kind == "sunscreen":
            sun_center = _point(rect, 50, 58)
            sun_radius = side * 0.09
            draw.ellipse(
                (
                    sun_center[0] - sun_radius,
                    sun_center[1] - sun_radius,
                    sun_center[0] + sun_radius,
                    sun_center[1] + sun_radius,
                ),
                outline=INK,
                width=width,
            )
            for index in range(4):
                angle = math.pi * index / 2
                direction = (math.cos(angle), math.sin(angle))
                _line(
                    draw,
                    [
                        (sun_center[0] + direction[0] * side * 0.115, sun_center[1] + direction[1] * side * 0.115),
                        (sun_center[0] + direction[0] * side * 0.14, sun_center[1] + direction[1] * side * 0.14),
                    ],
                    INK,
                    width,
                )
        else:
            p0 = _point(rect, 50, 46)
            p1 = _point(rect, 38, 63)
            p2 = _point(rect, 50, 70)
            p3 = _point(rect, 62, 63)
            points = _sample_quadratic(p0, p1, p2)
            points += _sample_quadratic(p2, p3, p0)[1:]
            _line(draw, points, INK, width)

    return _downsample(image)


def _weather_point(x: float, y: float) -> tuple[float, float]:
    return RENDER_SIZE * x, RENDER_SIZE * y


def _draw_sun(
    draw: ImageDraw.ImageDraw,
    x: float,
    y: float,
    radius: float,
    color: tuple[int, int, int, int],
) -> None:
    width = max(2, round(radius * 0.12))
    for index in range(8):
        angle = math.pi * index / 4
        _line(
            draw,
            [
                (x + math.cos(angle) * radius * 1.35, y + math.sin(angle) * radius * 1.35),
                (x + math.cos(angle) * radius * 1.72, y + math.sin(angle) * radius * 1.72),
            ],
            color,
            width,
        )
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def _draw_cloud(
    draw: ImageDraw.ImageDraw,
    x: float,
    y: float,
    width: float,
    height: float,
    color: tuple[int, int, int, int],
) -> None:
    left = x - width / 2
    top = y - height / 2
    draw.rounded_rectangle(
        (left, top + height * 0.42, left + width, top + height),
        radius=height * 0.28,
        fill=color,
    )
    for cx, cy, radius in [
        (left + width * 0.31, top + height * 0.48, height * 0.29),
        (left + width * 0.53, top + height * 0.32, height * 0.38),
        (left + width * 0.75, top + height * 0.53, height * 0.25),
    ]:
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)


def _draw_drop(
    draw: ImageDraw.ImageDraw,
    x: float,
    y: float,
    radius: float,
    color: tuple[int, int, int, int],
) -> None:
    p0 = (x, y - radius * 1.55)
    left = _sample_cubic(
        p0,
        (x - radius * 0.45, y - radius * 0.65),
        (x - radius, y),
        (x - radius, y + radius * 0.45),
    )
    bottom = _sample_cubic(
        left[-1],
        (x - radius, y + radius * 1.1),
        (x + radius, y + radius * 1.1),
        (x + radius, y + radius * 0.45),
    )[1:]
    right = _sample_cubic(
        bottom[-1],
        (x + radius, y),
        (x + radius * 0.45, y - radius * 0.65),
        p0,
    )[1:]
    draw.polygon(left + bottom + right, fill=color)


def render_weather(kind: str, monochrome: bool) -> Image.Image:
    image = Image.new("RGBA", (RENDER_SIZE, RENDER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    cloud = INK if monochrome else CLOUD
    accent = INK if monochrome else RAIN
    snow = INK if monochrome else (255, 255, 255, 255)
    s = RENDER_SIZE

    if kind == "clear":
        _draw_sun(draw, s * 0.5, s * 0.5, s * 0.23, INK if monochrome else SUN)
    elif kind == "partly_cloudy":
        _draw_sun(draw, s * 0.63, s * 0.33, s * 0.17, INK if monochrome else SUN)
        _draw_cloud(draw, s * 0.48, s * 0.49, s * 0.76, s * 0.39, cloud)
    elif kind == "overcast":
        _draw_cloud(draw, s * 0.61, s * 0.39, s * 0.62, s * 0.33, INK if monochrome else CLOUD_BLUE)
        _draw_cloud(draw, s * 0.42, s * 0.57, s * 0.72, s * 0.38, INK if monochrome else CLOUD_DARK)
    elif kind == "drizzle":
        _draw_cloud(draw, s * 0.5, s * 0.39, s * 0.78, s * 0.4, cloud)
        for x, y in [(0.42, 0.69), (0.58, 0.69), (0.5, 0.84)]:
            _draw_drop(draw, s * x, s * y, s * 0.026, accent)
    elif kind in {"rain", "shower"}:
        rain_cloud = INK if monochrome else CLOUD_DARK if kind == "shower" else CLOUD
        _draw_cloud(draw, s * 0.5, s * 0.36, s * 0.78, s * 0.4, rain_cloud)
        for x in [0.32, 0.5, 0.68]:
            _draw_drop(draw, s * x, s * 0.75, s * 0.058, accent)
    elif kind == "light_wintry_mix":
        _draw_cloud(draw, s * 0.5, s * 0.35, s * 0.8, s * 0.4, cloud)
        for x, y in [(0.24, 0.69), (0.4, 0.69), (0.32, 0.84)]:
            _draw_drop(draw, s * x, s * y, s * 0.026, accent)
        for x, y in [(0.6, 0.69), (0.76, 0.69), (0.68, 0.84)]:
            _draw_snowflake(draw, (s * x, s * y), s * 0.026, snow, max(2, round(s * 0.005)))
    elif kind == "wintry_mix":
        _draw_cloud(draw, s * 0.5, s * 0.35, s * 0.8, s * 0.4, cloud)
        _draw_drop(draw, s * 0.36, s * 0.76, s * 0.06, accent)
        _draw_snowflake(draw, (s * 0.65, s * 0.77), s * 0.12, snow, max(2, round(s * 0.023)))
    elif kind == "snow_flurry":
        _draw_cloud(draw, s * 0.5, s * 0.35, s * 0.8, s * 0.4, cloud)
        for x, y in [(0.42, 0.69), (0.58, 0.69), (0.5, 0.84)]:
            _draw_snowflake(draw, (s * x, s * y), s * 0.026, snow, max(2, round(s * 0.005)))
    elif kind == "snow":
        _draw_cloud(draw, s * 0.5, s * 0.35, s * 0.8, s * 0.4, cloud)
        _draw_snowflake(draw, (s * 0.5, s * 0.77), s * 0.13, snow, max(2, round(s * 0.025)))
    else:
        _draw_cloud(draw, s * 0.5, s * 0.5, s * 0.8, s * 0.42, cloud)
        font = ImageFont.truetype(str(FONT_BOLD), round(s * 0.30))
        question_color = INK if monochrome else QUESTION
        draw.text((s * 0.52, s * 0.53), "?", font=font, fill=question_color, anchor="mm")

    return _downsample(image)


def create_sheet(
    title: str,
    items: list[tuple[str, str]],
    source_dir: Path,
    output_path: Path,
    columns: int = 4,
) -> None:
    cell_width = 286
    cell_height = 292
    gap = 24
    margin = 42
    title_height = 105
    rows = math.ceil(len(items) / columns)
    width = margin * 2 + columns * cell_width + (columns - 1) * gap
    height = title_height + margin + rows * cell_height + (rows - 1) * gap + margin
    sheet = Image.new("RGBA", (width, height), PAGE_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.truetype(str(FONT_BOLD), 38)
    label_font = ImageFont.truetype(str(FONT_BOLD), 24)
    code_font = ImageFont.truetype(str(FONT_REGULAR), 15)
    draw.text((margin, 45), title, fill=TEXT, font=title_font, anchor="lm")

    for index, (key, label) in enumerate(items):
        row = index // columns
        column = index % columns
        left = margin + column * (cell_width + gap)
        top = title_height + margin + row * (cell_height + gap)
        card = (left, top, left + cell_width, top + cell_height)
        draw.rounded_rectangle(card, radius=30, fill=WIDGET_BACKGROUND, outline=(216, 229, 238, 255), width=2)
        icon = Image.open(source_dir / f"{key}.png").convert("RGBA").resize((176, 176), Image.Resampling.LANCZOS)
        sheet.alpha_composite(icon, (left + (cell_width - 176) // 2, top + 22))
        draw.text((left + cell_width / 2, top + 222), label, fill=TEXT, font=label_font, anchor="mm")
        draw.text((left + cell_width / 2, top + 259), key, fill=(115, 128, 138, 255), font=code_font, anchor="mm")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output_path, quality=95)


def main() -> None:
    prep_dir = OUTPUT_ROOT / "preparation"
    color_dir = OUTPUT_ROOT / "weather-color"
    mono_dir = OUTPUT_ROOT / "weather-monochrome"
    for directory in (prep_dir, color_dir, mono_dir):
        directory.mkdir(parents=True, exist_ok=True)

    for key, _label in PREPARATION_ITEMS:
        render_preparation(key).save(prep_dir / f"{key}.png")

    for key, _label in WEATHER_ITEMS:
        render_weather(key, monochrome=False).save(color_dir / f"{key}.png")
        render_weather(key, monochrome=True).save(mono_dir / f"{key}.png")

    prep_sheet = OUTPUT_ROOT / "preparation-icons.png"
    color_sheet = OUTPUT_ROOT / "weather-color-icons.png"
    mono_sheet = OUTPUT_ROOT / "weather-monochrome-icons.png"
    create_sheet("준비물 아이콘 7종", PREPARATION_ITEMS, prep_dir, prep_sheet)
    create_sheet("날씨 컬러 아이콘 11종", WEATHER_ITEMS, color_dir, color_sheet)
    create_sheet("날씨 단색 아이콘 11종", WEATHER_ITEMS, mono_dir, mono_sheet)

    sheets = [Image.open(path).convert("RGB") for path in (prep_sheet, color_sheet, mono_sheet)]
    width = max(sheet.width for sheet in sheets)
    gap = 28
    combined = Image.new("RGB", (width, sum(sheet.height for sheet in sheets) + gap * 2), PAGE_BACKGROUND[:3])
    y = 0
    for sheet in sheets:
        combined.paste(sheet, ((width - sheet.width) // 2, y))
        y += sheet.height + gap
    combined.save(OUTPUT_ROOT / "all-icon-previews.png", quality=95)

    print(f"Generated 29 PNG icons in {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
