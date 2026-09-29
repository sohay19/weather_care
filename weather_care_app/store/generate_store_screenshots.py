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

APP_SCREENS = [
    ("01-main", "main.png", "MAIN", "오늘 챙길 것만\n한눈에"),
    ("02-today", "today.png", "TODAY", "시간대별 날씨를\n하루 흐름으로"),
    ("03-detail", "detail.png", "DETAIL", "판단 근거까지\n자세히"),
    ("05-setting", "setting.png", "SETTING", "내 위치와 알림을\n내 생활에 맞게"),
    ("06-week", "week.png", "WEEK", "일주일 계획을\n미리 가볍게"),
    ("07-notification", "notification.png", "NOTIFICATION", "원하는 알림만\n필요한 시간에"),
    ("08-push-notification", "push-notification.png", "PUSH ALERT", "필요한 날씨를\n알림으로 바로"),
]
WIDGET_SCREEN = ("04-widget", "WIDGET", "홈 화면에서도\n날씨를 바로 확인")
SCREEN_STEMS = sorted([stem for stem, *_ in APP_SCREENS] + [WIDGET_SCREEN[0]])
IOS_PUSH_SOURCE = SOURCE_DIR / "push-notification-ios.png"
IPAD_PUSH_SOURCE = TABLET_SOURCE_DIR / "push-notification-ios.png"
PUSH_NOTIFICATIONS = [
    ("낮 자외선이 강해요", "낮 동안 자외선이 높을 것으로 보여요.\n외출한다면 선크림이나 양산을 챙기세요."),
    ("미세먼지가 나빠요", "외출한다면 보건용 마스크를 챙기고\n오래 머무르지 마세요."),
    ("현재 강수 안내", "비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요."),
    ("오늘 준비할 내용", "아침에는 선선하고 낮에는 따뜻해요.\n얇은 겉옷을 챙기세요."),
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


def create_ios_push_source(destination: Path, size: tuple[int, int], tablet: bool) -> None:
    width, height = size
    canvas = Image.new("RGBA", size, "#667C9F")
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / max(1, height - 1)
        color = (
            round(29 + 42 * ratio),
            round(48 + 46 * ratio),
            round(83 + 55 * ratio),
            255,
        )
        draw.line((0, y, width, y), fill=color)

    wallpaper = Image.new("RGBA", size, (0, 0, 0, 0))
    wallpaper_draw = ImageDraw.Draw(wallpaper)
    wallpaper_draw.ellipse(
        (-round(width * 0.45), round(height * 0.03), round(width * 0.77), round(height * 0.54)),
        fill=(82, 166, 224, 188),
    )
    wallpaper_draw.ellipse(
        (round(width * 0.40), round(height * 0.08), round(width * 1.30), round(height * 0.50)),
        fill=(175, 111, 192, 132),
    )
    wallpaper_draw.ellipse(
        (-round(width * 0.34), round(height * 0.50), round(width * 0.65), round(height * 1.02)),
        fill=(21, 68, 118, 178),
    )
    wallpaper_draw.ellipse(
        (round(width * 0.44), round(height * 0.58), round(width * 1.30), round(height * 1.08)),
        fill=(27, 36, 75, 190),
    )
    wallpaper = wallpaper.filter(ImageFilter.GaussianBlur(round(width * 0.16)))
    canvas = Image.alpha_composite(canvas, wallpaper)
    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    shade_draw = ImageDraw.Draw(shade)
    for y in range(height):
        alpha = round(8 + 72 * (y / max(1, height - 1)))
        shade_draw.line((0, y, width, y), fill=(4, 10, 26, alpha))
    canvas = Image.alpha_composite(canvas, shade)
    draw = ImageDraw.Draw(canvas)

    if not tablet:
        island_width = round(width * 0.30)
        island_height = round(width * 0.080)
        island_x = (width - island_width) // 2
        draw.rounded_rectangle(
            (island_x, round(height * 0.012), island_x + island_width, round(height * 0.012) + island_height),
            radius=island_height // 2,
            fill="#050507",
        )

    status_y = round(height * 0.027)
    signal_x = round(width * 0.805)
    bar_width = max(3, round(width * 0.006))
    bar_gap = round(width * 0.004)
    for index, bar_height in enumerate((0.010, 0.015, 0.020, 0.025)):
        x = signal_x + index * (bar_width + bar_gap)
        draw.rounded_rectangle(
            (x, status_y + round(height * (0.025 - bar_height)), x + bar_width, status_y + round(height * 0.025)),
            radius=bar_width // 2,
            fill="#FFFFFF",
        )

    wifi_x = round(width * 0.875)
    wifi_y = status_y + round(width * 0.019)
    for inset in (0, round(width * 0.011)):
        draw.arc(
            (wifi_x - round(width * 0.030) + inset, wifi_y - round(width * 0.025) + inset,
             wifi_x + round(width * 0.030) - inset, wifi_y + round(width * 0.025) - inset),
            start=205,
            end=335,
            fill="#FFFFFF",
            width=max(3, round(width * 0.005)),
        )
    draw.ellipse(
        (wifi_x - round(width * 0.004), wifi_y + round(width * 0.010),
         wifi_x + round(width * 0.004), wifi_y + round(width * 0.018)),
        fill="#FFFFFF",
    )

    battery_x = round(width * 0.918)
    battery_y = status_y + round(width * 0.002)
    battery_w = round(width * 0.064)
    battery_h = round(width * 0.030)
    draw.rounded_rectangle(
        (battery_x, battery_y, battery_x + battery_w, battery_y + battery_h),
        radius=round(width * 0.009),
        outline="#FFFFFF",
        width=max(2, round(width * 0.003)),
    )
    draw.rounded_rectangle(
        (battery_x + round(width * 0.005), battery_y + round(width * 0.005),
         battery_x + battery_w - round(width * 0.008), battery_y + battery_h - round(width * 0.005)),
        radius=round(width * 0.005),
        fill="#FFFFFF",
    )
    draw.rounded_rectangle(
        (battery_x + battery_w + round(width * 0.004), battery_y + round(width * 0.009),
         battery_x + battery_w + round(width * 0.008), battery_y + battery_h - round(width * 0.009)),
        radius=round(width * 0.002),
        fill="#FFFFFF",
    )

    lock_center_x = width // 2
    lock_y = round(height * (0.075 if tablet else 0.073))
    lock_w = round(width * 0.025)
    lock_h = round(width * 0.020)
    draw.arc(
        (lock_center_x - lock_w // 2, lock_y - lock_h,
         lock_center_x + lock_w // 2, lock_y + lock_h),
        start=180,
        end=360,
        fill="#FFFFFF",
        width=max(3, round(width * 0.004)),
    )
    draw.rounded_rectangle(
        (lock_center_x - round(lock_w * 0.62), lock_y,
         lock_center_x + round(lock_w * 0.62), lock_y + round(lock_h * 0.90)),
        radius=round(width * 0.004),
        fill="#FFFFFF",
    )

    date_font = font("SUITE-Medium.ttf", round(width * (0.037 if tablet else 0.043)))
    time_font = font("SUITE-Light.ttf", round(width * (0.15 if tablet else 0.205)))
    date_text = "9월 29일 화요일"
    date_width, _ = text_size(draw, date_text, date_font)
    time_width, _ = text_size(draw, "1:49", time_font)
    date_y = round(height * (0.115 if tablet else 0.115))
    time_y = round(height * (0.150 if tablet else 0.150))
    draw_text_top(draw, ((width - date_width) / 2, date_y), date_text, date_font, "#FFFFFF")
    draw_text_top(draw, ((width - time_width) / 2, time_y), "1:49", time_font, "#FFFFFF")

    card_width = round(width * (0.82 if tablet else 0.94))
    card_height = round(height * (0.110 if tablet else 0.108))
    card_x = (width - card_width) // 2
    card_y = round(height * (0.350 if tablet else 0.382))
    card_gap = round(width * (0.011 if tablet else 0.012))
    card_radius = round(width * (0.035 if tablet else 0.044))
    icon_size = round(width * (0.044 if tablet else 0.054))
    with Image.open(ROOT / "appIcon.png") as source:
        icon = source.convert("RGBA").resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(icon_mask).rounded_rectangle(
        (0, 0, icon_size - 1, icon_size - 1),
        radius=round(icon_size * 0.22),
        fill=255,
    )
    header_font = font("SUITE-SemiBold.ttf", round(width * (0.023 if tablet else 0.030)))
    meta_font = font("SUITE-Regular.ttf", round(width * (0.021 if tablet else 0.027)))
    title_font = font("SUITE-SemiBold.ttf", round(width * (0.026 if tablet else 0.034)))
    body_font = font("SUITE-Regular.ttf", round(width * (0.021 if tablet else 0.028)))
    app_width, _ = text_size(draw, "날씨챙겨", header_font)
    frosted_wallpaper = canvas.filter(ImageFilter.GaussianBlur(round(width * 0.022)))

    for index, (title, body) in enumerate(PUSH_NOTIFICATIONS):
        current_y = card_y + index * (card_height + card_gap)
        shadow = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (
                card_x,
                current_y + round(width * 0.008),
                card_x + card_width,
                current_y + card_height + round(width * 0.008),
            ),
            radius=card_radius,
            fill=(6, 12, 28, 92),
        )
        canvas = Image.alpha_composite(
            canvas,
            shadow.filter(ImageFilter.GaussianBlur(round(width * 0.018))),
        )
        card_mask = Image.new("L", size, 0)
        ImageDraw.Draw(card_mask).rounded_rectangle(
            (card_x, current_y, card_x + card_width, current_y + card_height),
            radius=card_radius,
            fill=255,
        )
        canvas.paste(frosted_wallpaper, (0, 0), card_mask)
        panel = Image.new("RGBA", size, (0, 0, 0, 0))
        panel_draw = ImageDraw.Draw(panel)
        panel_draw.rounded_rectangle(
            (card_x, current_y, card_x + card_width, current_y + card_height),
            radius=card_radius,
            fill=(235, 239, 246, 202),
            outline=(255, 255, 255, 112),
            width=max(2, round(width * 0.002)),
        )
        canvas = Image.alpha_composite(canvas, panel)

        icon_x = card_x + round(width * (0.020 if tablet else 0.021))
        icon_y = current_y + round(width * (0.017 if tablet else 0.019))
        canvas.paste(icon, (icon_x, icon_y), icon_mask)
        draw = ImageDraw.Draw(canvas)
        header_x = icon_x + icon_size + round(width * 0.012)
        header_y = icon_y + round(icon_size * 0.06)
        draw_text_top(draw, (header_x, header_y), "날씨챙겨", header_font, "#11151C")
        draw_text_top(
            draw,
            (header_x + app_width + round(width * 0.014), header_y),
            "지금",
            meta_font,
            "#59616D",
        )
        text_x = icon_x
        draw_text_top(
            draw,
            (text_x, current_y + round(card_height * 0.36)),
            title,
            title_font,
            "#11151C",
        )
        draw.multiline_text(
            (text_x, current_y + round(card_height * 0.59)),
            body,
            font=body_font,
            fill="#252B34",
            spacing=round(width * 0.006),
        )

    if not tablet:
        control_y = round(height * 0.944)
        control_radius = round(width * 0.058)
        for control_x in (round(width * 0.12), round(width * 0.88)):
            draw.ellipse(
                (control_x - control_radius, control_y - control_radius,
                 control_x + control_radius, control_y + control_radius),
                fill=(12, 18, 30, 158),
                outline=(255, 255, 255, 42),
                width=max(2, round(width * 0.002)),
            )

        flashlight_x = round(width * 0.12)
        flash_top = control_y - round(width * 0.024)
        draw.rounded_rectangle(
            (flashlight_x - round(width * 0.013), flash_top,
             flashlight_x + round(width * 0.013), flash_top + round(width * 0.018)),
            radius=round(width * 0.004),
            fill="#FFFFFF",
        )
        draw.polygon(
            ((flashlight_x - round(width * 0.018), flash_top + round(width * 0.018)),
             (flashlight_x + round(width * 0.018), flash_top + round(width * 0.018)),
             (flashlight_x + round(width * 0.011), flash_top + round(width * 0.030)),
             (flashlight_x - round(width * 0.011), flash_top + round(width * 0.030))),
            fill="#FFFFFF",
        )
        draw.rounded_rectangle(
            (flashlight_x - round(width * 0.010), flash_top + round(width * 0.030),
             flashlight_x + round(width * 0.010), flash_top + round(width * 0.048)),
            radius=round(width * 0.005),
            fill="#FFFFFF",
        )

        camera_x = round(width * 0.88)
        camera_y = control_y
        camera_w = round(width * 0.046)
        camera_h = round(width * 0.034)
        draw.rounded_rectangle(
            (camera_x - camera_w // 2, camera_y - camera_h // 2,
             camera_x + camera_w // 2, camera_y + camera_h // 2),
            radius=round(width * 0.007),
            outline="#FFFFFF",
            width=max(3, round(width * 0.004)),
        )
        draw.rounded_rectangle(
            (camera_x - round(width * 0.012), camera_y - camera_h // 2 - round(width * 0.007),
             camera_x + round(width * 0.012), camera_y - camera_h // 2 + round(width * 0.002)),
            radius=round(width * 0.004),
            fill="#FFFFFF",
        )
        draw.ellipse(
            (camera_x - round(width * 0.010), camera_y - round(width * 0.010),
             camera_x + round(width * 0.010), camera_y + round(width * 0.010)),
            outline="#FFFFFF",
            width=max(3, round(width * 0.004)),
        )
        home_y = round(height * 0.988)
        draw.rounded_rectangle(
            (round(width * 0.37), home_y, round(width * 0.63), home_y + round(width * 0.012)),
            radius=round(width * 0.006),
            fill=(255, 255, 255, 218),
        )

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)


def app_source_path(platform: str, source_name: str, tablet: bool) -> Path:
    if source_name == "push-notification.png":
        if platform == "ios":
            return IOS_PUSH_SOURCE
        if platform == "ipad":
            return IPAD_PUSH_SOURCE
    return (TABLET_SOURCE_DIR if tablet else SOURCE_DIR) / source_name


def fitted_font(name: str, text: str, max_size: int, max_width: int, min_size: int = 8) -> ImageFont.FreeTypeFont:
    for size in range(max_size, min_size - 1, -1):
        candidate = font(name, size)
        box = candidate.getbbox(text)
        if box[2] - box[0] <= max_width:
            return candidate
    return font(name, min_size)


IOS_WIDGET_POINTS = {
    "small": (158, 158),
    "medium": (338, 158),
    "large": (338, 354),
}
IPAD_WIDGET_POINTS = {
    "small": (170, 170),
    "medium": (378.5, 170),
    "large": (378.5, 378.5),
}
WIDGET_DATA = {
    "region": "시흥시 은행동",
    "refresh": "오전 8:20 기준",
    "current": "18°",
    "apparent": "18°",
    "minimum": "12°",
    "maximum": "20°",
    "short": "두꺼운 겉옷을 챙기세요",
    "brief": "오전에는 선선하고 오후에는 포근해요. 얇은 겉옷을 챙기면 좋아요.",
    "next_time": "오전 9시",
    "next_temperature": "19°",
}
WIDGET_INK = "#25374E"
WIDGET_SECONDARY = "#60758A"
WIDGET_SURFACE = "#EAF4FB"
WIDGET_PANEL = "#F9FCFE"


def text_size(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=text_font)
    return box[2] - box[0], box[3] - box[1]


def draw_text_top(
    draw: ImageDraw.ImageDraw,
    position: tuple[float, float],
    text: str,
    text_font: ImageFont.FreeTypeFont,
    fill: str,
) -> None:
    box = draw.textbbox((0, 0), text, font=text_font)
    draw.text((position[0] - box[0], position[1] - box[1]), text, font=text_font, fill=fill)


def draw_text_centered(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    text: str,
    text_font: ImageFont.FreeTypeFont,
    fill: str,
) -> None:
    text_width, text_height = text_size(draw, text, text_font)
    draw_text_top(
        draw,
        ((box[0] + box[2] - text_width) / 2, (box[1] + box[3] - text_height) / 2),
        text,
        text_font,
        fill,
    )


def draw_weather_icon(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    condition: str = "partlyCloudy",
    monochrome: bool = False,
) -> None:
    left, top, right, bottom = box
    side = min(right - left, bottom - top)
    origin_x = left + ((right - left) - side) / 2
    origin_y = top + ((bottom - top) - side) / 2
    sun_color = WIDGET_INK if monochrome else "#F6B737"
    cloud_color = WIDGET_INK if monochrome else "#F9FCFF"

    def point(x: float, y: float) -> tuple[float, float]:
        return origin_x + side * x, origin_y + side * y

    def sun(center: tuple[float, float], radius: float) -> None:
        directions = ((0, -1), (.707, -.707), (1, 0), (.707, .707), (0, 1), (-.707, .707), (-1, 0), (-.707, -.707))
        for dx, dy in directions:
            draw.line(
                (
                    center[0] + dx * radius * 1.35,
                    center[1] + dy * radius * 1.35,
                    center[0] + dx * radius * 1.72,
                    center[1] + dy * radius * 1.72,
                ),
                fill=sun_color,
                width=max(1, round(radius * 0.12)),
            )
        draw.ellipse(
            (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
            fill=sun_color,
        )

    if condition == "clear":
        sun(point(.5, .5), side * .23)
        return

    sun(point(.63, .33), side * .17)
    center_x, center_y = point(.48, .49)
    cloud_width = side * .76
    cloud_height = side * .39
    cloud_left = center_x - cloud_width / 2
    cloud_top = center_y - cloud_height / 2
    draw.rounded_rectangle(
        (
            cloud_left,
            cloud_top + cloud_height * .42,
            cloud_left + cloud_width,
            cloud_top + cloud_height,
        ),
        radius=round(cloud_height * .28),
        fill=cloud_color,
    )
    for center_ratio, radius_ratio in (((.31, .48), .29), ((.53, .32), .38), ((.75, .53), .25)):
        cx = cloud_left + cloud_width * center_ratio[0]
        cy = cloud_top + cloud_height * center_ratio[1]
        radius = cloud_height * radius_ratio
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=cloud_color)


def paste_preparation_icon(
    image: Image.Image,
    asset_name: str | None,
    box: tuple[int, int, int, int],
) -> None:
    left, top, right, bottom = box
    side = min(right - left, bottom - top)
    draw = ImageDraw.Draw(image)
    draw.ellipse((left, top, left + side, top + side), fill="#E2EFF8")
    if asset_name:
        asset_path = ROOT.parent / "assets" / "icons" / asset_name
        with Image.open(asset_path) as source:
            icon = source.convert("RGBA")
            icon.thumbnail((round(side * .68), round(side * .68)), Image.Resampling.LANCZOS)
        image.alpha_composite(
            icon,
            (round(left + (side - icon.width) / 2), round(top + (side - icon.height) / 2)),
        )
        return

    stroke = max(1, round(side * .045))
    icon_left = left + side * .25
    icon_top = top + side * .32
    icon_right = left + side * .75
    icon_bottom = top + side * .68
    draw.rounded_rectangle(
        (icon_left, icon_top, icon_right, icon_bottom),
        radius=round(side * .09),
        outline=WIDGET_INK,
        width=stroke,
    )
    draw.arc((left + side * .08, top + side * .34, left + side * .34, top + side * .70), 95, 265, fill=WIDGET_INK, width=stroke)
    draw.arc((left + side * .66, top + side * .34, left + side * .92, top + side * .70), -85, 85, fill=WIDGET_INK, width=stroke)
    for ratio in (.45, .56):
        draw.line((left + side * .32, top + side * ratio, left + side * .68, top + side * ratio), fill=WIDGET_INK, width=stroke)


def widget_panel(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=WIDGET_PANEL)


def draw_min_max_row(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    point_size: float,
    scale: float,
) -> None:
    parts = (
        ("최저 ", "SUITE-Regular.ttf"),
        (WIDGET_DATA["minimum"], "SUITE-ExtraBold.ttf"),
        ("   최고 ", "SUITE-Regular.ttf"),
        (WIDGET_DATA["maximum"], "SUITE-ExtraBold.ttf"),
    )
    fonts = [font(name, max(8, round(point_size * scale))) for _, name in parts]
    widths = [text_size(draw, text, text_font)[0] for (text, _), text_font in zip(parts, fonts)]
    heights = [text_size(draw, text, text_font)[1] for (text, _), text_font in zip(parts, fonts)]
    cursor_x = (box[0] + box[2] - sum(widths)) / 2
    center_y = (box[1] + box[3]) / 2
    for (text, _), text_font, part_width, part_height in zip(parts, fonts, widths, heights):
        draw_text_top(draw, (cursor_x, center_y - part_height / 2), text, text_font, "#475A70")
        cursor_x += part_width


def draw_temperature_row(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    scale: float,
    icon_size: float,
    temperature_size: float,
    label_size: float,
    spacing: float,
    divider_height: float,
    apparent: bool,
) -> None:
    icon_pixels = round(icon_size * scale)
    spacing_pixels = round(spacing * scale)
    value_font = font("SUITE-Heavy.ttf", max(10, round(temperature_size * scale)))
    label_font = font("SUITE-Regular.ttf", max(8, round(label_size * scale))) if apparent else None
    current_width, current_height = text_size(draw, WIDGET_DATA["current"], value_font)
    if apparent and label_font:
        label_width, label_height = text_size(draw, "현재", label_font)
        current_width = max(current_width, label_width)
        apparent_value_width, apparent_value_height = text_size(draw, WIDGET_DATA["apparent"], value_font)
        apparent_label_width, _ = text_size(draw, "체감", label_font)
        apparent_width = max(apparent_value_width, apparent_label_width)
        divider_pixels = max(1, round(scale))
        total_width = icon_pixels + current_width + apparent_width + spacing_pixels * 3 + divider_pixels
    else:
        total_width = icon_pixels + spacing_pixels + current_width
    left = (box[0] + box[2] - total_width) / 2
    center_y = (box[1] + box[3]) / 2
    icon_top = round(center_y - icon_pixels / 2)
    draw_weather_icon(draw, (round(left), icon_top, round(left) + icon_pixels, icon_top + icon_pixels))
    cursor_x = left + icon_pixels + spacing_pixels

    if not apparent or not label_font:
        draw_text_top(draw, (cursor_x, center_y - current_height / 2), WIDGET_DATA["current"], value_font, WIDGET_INK)
        return

    label_height = text_size(draw, "현재", label_font)[1]
    value_height = text_size(draw, WIDGET_DATA["current"], value_font)[1]
    column_height = label_height + value_height - scale
    column_top = center_y - column_height / 2
    current_label_width = text_size(draw, "현재", label_font)[0]
    draw_text_top(draw, (cursor_x + (current_width - current_label_width) / 2, column_top), "현재", label_font, WIDGET_SECONDARY)
    actual_current_width = text_size(draw, WIDGET_DATA["current"], value_font)[0]
    draw_text_top(
        draw,
        (cursor_x + (current_width - actual_current_width) / 2, column_top + label_height - scale),
        WIDGET_DATA["current"],
        value_font,
        WIDGET_INK,
    )
    cursor_x += current_width + spacing_pixels
    divider_pixels = max(1, round(scale))
    divider_top = center_y - divider_height * scale / 2
    draw.rectangle(
        (round(cursor_x), round(divider_top), round(cursor_x) + divider_pixels - 1, round(divider_top + divider_height * scale)),
        fill="#ABC3D6",
    )
    cursor_x += divider_pixels + spacing_pixels
    apparent_label_width = text_size(draw, "체감", label_font)[0]
    draw_text_top(draw, (cursor_x + (apparent_width - apparent_label_width) / 2, column_top), "체감", label_font, WIDGET_SECONDARY)
    actual_apparent_width = text_size(draw, WIDGET_DATA["apparent"], value_font)[0]
    draw_text_top(
        draw,
        (cursor_x + (apparent_width - actual_apparent_width) / 2, column_top + label_height - scale),
        WIDGET_DATA["apparent"],
        value_font,
        WIDGET_INK,
    )


def widget_margins(family: str, platform: str) -> tuple[float, float, float, float]:
    if platform in {"ios", "ipad"}:
        margin = 14.25 if family == "large" else 13.5
        return margin, margin, margin, margin
    if family == "small":
        return 14, 12, 14, 10
    if family == "medium":
        return 16, 11, 16, 10
    return 18, 14, 18, 12


def widget_points(platform: str) -> dict[str, tuple[float, float]]:
    return IPAD_WIDGET_POINTS if platform == "ipad" else IOS_WIDGET_POINTS


def draw_widget_card(size: tuple[int, int], family: str, platform: str) -> Image.Image:
    width, height = size
    logical_width, logical_height = widget_points(platform)[family]
    scale = min(width / logical_width, height / logical_height)
    card = Image.new("RGBA", size, WIDGET_SURFACE)
    draw = ImageDraw.Draw(card)
    leading, top, trailing, bottom = widget_margins(family, platform)
    left = round(leading * scale)
    right = width - round(trailing * scale)
    top_px = round(top * scale)
    bottom_px = height - round(bottom * scale)

    region_size = {"small": 12, "medium": 13, "large": 14}[family]
    time_size = {"small": 9, "medium": 10, "large": 11}[family]
    region_font = font("SUITE-ExtraBold.ttf", max(8, round(region_size * scale)))
    time_font = font("SUITE-Regular.ttf", max(8, round(time_size * scale)))
    region = WIDGET_DATA["region"]
    refresh = WIDGET_DATA["refresh"]
    region_width_limit = {"small": 78, "medium": 210, "large": 220}[family] * scale
    refresh_width_limit = {"small": 78, "medium": 90, "large": 100}[family] * scale
    region_font = fitted_font("SUITE-ExtraBold.ttf", region, region_font.size, round(region_width_limit), max(8, round(region_font.size * .72)))
    time_font = fitted_font("SUITE-Regular.ttf", refresh, time_font.size, round(refresh_width_limit), max(8, round(time_font.size * .72)))
    region_width, region_height = text_size(draw, region, region_font)
    refresh_width, refresh_height = text_size(draw, refresh, time_font)
    header_height = max(region_height, refresh_height)
    draw_text_top(draw, (left, top_px + (header_height - region_height) / 2), region, region_font, WIDGET_INK)
    draw_text_top(draw, (right - refresh_width, top_px + (header_height - refresh_height) / 2), refresh, time_font, WIDGET_SECONDARY)
    header_bottom = top_px + header_height

    panel_height = round((27 if family != "medium" else 28) * scale)
    panel_top = bottom_px - panel_height
    widget_panel(draw, (left, panel_top, right, bottom_px), max(4, round(10 * scale)))

    if family == "small":
        draw_temperature_row(
            draw,
            (left, header_bottom + round(4 * scale), right, panel_top - round(4 * scale)),
            scale,
            64,
            38,
            0,
            8,
            0,
            False,
        )
        draw_min_max_row(draw, (left, panel_top, right, bottom_px), 13, scale)
        return card

    if family == "medium":
        draw_temperature_row(
            draw,
            (left, header_bottom + round(3 * scale), right, panel_top - round(3 * scale)),
            scale,
            58,
            34,
            10,
            12,
            36,
            True,
        )
        message_font = font("SUITE-ExtraBold.ttf", max(8, round(13 * scale)))
        message = WIDGET_DATA["short"]
        message_font = fitted_font("SUITE-ExtraBold.ttf", message, message_font.size, round((right - left) * .54), max(8, round(message_font.size * .8)))
        message_width, message_height = text_size(draw, message, message_font)
        draw_text_top(draw, (left + round(12 * scale), panel_top + (panel_height - message_height) / 2), message, message_font, WIDGET_INK)
        minmax_left = left + round(12 * scale) + message_width + round(8 * scale)
        draw_min_max_row(draw, (minmax_left, panel_top, right - round(12 * scale), bottom_px), 12, scale)
        return card

    next_height = round(32 * scale)
    next_top = panel_top - round(5 * scale) - next_height
    content_top = header_bottom + round(5 * scale)
    content_bottom = next_top - round(5 * scale)
    prep_height = round(48 * scale)
    brief_font = font("SUITE-ExtraBold.ttf", max(8, round(14 * scale)))
    brief_lines = ["오전에는 선선하고 오후에는 포근해요.", "얇은 겉옷을 챙기면 좋아요."]
    brief_line_height = max(text_size(draw, line, brief_font)[1] for line in brief_lines)
    brief_height = brief_line_height * len(brief_lines) + round(2 * scale)
    group_height = round(72 * scale) + round(20 * scale) + brief_height + round(20 * scale) + prep_height
    group_top = content_top + max(0, (content_bottom - content_top - group_height) / 2)
    temperature_bottom = group_top + round(72 * scale)
    draw_temperature_row(
        draw,
        (left, round(group_top), right, round(temperature_bottom)),
        scale,
        72,
        38,
        11,
        12,
        40,
        True,
    )

    brief_top = temperature_bottom + round(20 * scale)
    brief_left = left + round(18 * scale)
    for index, line in enumerate(brief_lines):
        line_font = fitted_font(
            "SUITE-ExtraBold.ttf",
            line,
            brief_font.size,
            right - brief_left - round(18 * scale),
            max(8, round(brief_font.size * .8)),
        )
        draw_text_top(draw, (brief_left, brief_top + index * (brief_line_height + round(2 * scale))), line, line_font, WIDGET_INK)

    prep_top = round(brief_top + brief_height + 20 * scale)
    prep_gap = round(6 * scale)
    prep_width = (right - left - prep_gap * 2) / 3
    preparations = (
        ("prep_umbrella.png", "우산"),
        ("prep_outerwear.png", "두꺼운 겉옷"),
        (None, "마스크"),
    )
    for index, (asset, label) in enumerate(preparations):
        prep_left = round(left + index * (prep_width + prep_gap))
        prep_right = round(prep_left + prep_width)
        widget_panel(draw, (prep_left, prep_top, prep_right, prep_top + prep_height), max(4, round(10 * scale)))
        icon_side = round(36 * scale)
        icon_left = prep_left + round(10 * scale)
        icon_top = prep_top + (prep_height - icon_side) // 2
        paste_preparation_icon(card, asset, (icon_left, icon_top, icon_left + icon_side, icon_top + icon_side))
        label_left = icon_left + icon_side + round(4 * scale)
        label_font = fitted_font(
            "SUITE-ExtraBold.ttf",
            label,
            max(8, round(12 * scale)),
            max(1, prep_right - round(8 * scale) - label_left),
            max(8, round(9.6 * scale)),
        )
        _, label_height = text_size(draw, label, label_font)
        draw_text_top(draw, (label_left, prep_top + (prep_height - label_height) / 2), label, label_font, WIDGET_INK)

    title_font = font("SUITE-ExtraBold.ttf", max(8, round(12 * scale)))
    time_font = font("SUITE-Regular.ttf", max(8, round(12 * scale)))
    next_temp_font = font("SUITE-Heavy.ttf", max(8, round(17 * scale)))
    next_center_y = next_top + next_height / 2
    title = "다음 시간 예보"
    title_width, title_height = text_size(draw, title, title_font)
    draw_text_top(draw, (left + round(12 * scale), next_center_y - title_height / 2), title, title_font, WIDGET_INK)
    icon_side = round(32 * scale)
    icon_right = right - round(10 * scale)
    icon_left = icon_right - icon_side
    draw_weather_icon(
        draw,
        (icon_left, round(next_center_y - icon_side / 2), icon_right, round(next_center_y + icon_side / 2)),
        condition="clear",
        monochrome=True,
    )
    next_temperature = WIDGET_DATA["next_temperature"]
    next_temp_width, next_temp_height = text_size(draw, next_temperature, next_temp_font)
    next_temp_left = icon_left - round(3 * scale) - next_temp_width
    draw_text_top(draw, (next_temp_left, next_center_y - next_temp_height / 2), next_temperature, next_temp_font, WIDGET_INK)
    next_time = WIDGET_DATA["next_time"]
    next_time_width, next_time_height = text_size(draw, next_time, time_font)
    time_area_left = left + round(12 * scale) + title_width + round(10 * scale)
    time_area_right = next_temp_left - round(8 * scale)
    draw_text_top(draw, ((time_area_left + time_area_right - next_time_width) / 2, next_center_y - next_time_height / 2), next_time, time_font, WIDGET_INK)
    draw_min_max_row(draw, (left, panel_top, right, bottom_px), 13, scale)
    return card


def compose_widget_showcase(
    destination: Path,
    label: str,
    headline: str,
    spec: dict,
    platform: str,
) -> None:
    canvas_width, canvas_height = spec["size"]
    canvas = Image.new("RGB", (canvas_width, canvas_height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    label_font = font("SUITE-Bold.ttf", spec["label_size"])
    headline_font = font("SUITE-Heavy.ttf", spec["headline_size"])
    label_box = draw.textbbox((0, 0), label, font=label_font)
    draw.text(((canvas_width - (label_box[2] - label_box[0])) / 2, spec["label_y"]), label, font=label_font, fill=LABEL_COLOR)
    headline_box = draw.multiline_textbbox(
        (0, 0), headline, font=headline_font, spacing=spec["headline_spacing"], align="center"
    )
    draw.multiline_text(
        ((canvas_width - (headline_box[2] - headline_box[0])) / 2, spec["headline_y"]),
        headline,
        font=headline_font,
        fill=HEADLINE_COLOR,
        spacing=spec["headline_spacing"],
        align="center",
    )

    board_top = spec["screen_y"]
    available_height = canvas_height - board_top - round(canvas_height * 0.045)
    board_width = round(canvas_width * 0.86)
    board_height = available_height
    board = Image.new("RGBA", (board_width, board_height), "#DDEBF5")
    board_draw = ImageDraw.Draw(board)
    board_draw.ellipse((-round(board_width * 0.08), round(board_height * 0.74), round(board_width * 0.23), round(board_height * 1.03)), fill="#D3E5F2")
    board_draw.ellipse((round(board_width * 0.75), -round(board_height * 0.07), round(board_width * 1.05), round(board_height * 0.20)), fill="#E9F3F9")

    family_points = widget_points(platform)
    horizontal_margin = round(board_width * 0.055)
    vertical_margin = round(board_height * 0.035)
    gap = round(board_height * 0.018)
    inner_width = board_width - horizontal_margin * 2
    inner_height = board_height - vertical_margin * 2
    families = ("small", "medium", "large")
    scale = min(
        inner_width / max(family_points[family][0] for family in families),
        (inner_height - gap * 2) / sum(family_points[family][1] for family in families),
    )
    card_sizes = {
        family: (
            round(family_points[family][0] * scale),
            round(family_points[family][1] * scale),
        )
        for family in families
    }
    stack_height = sum(card_sizes[family][1] for family in families) + gap * 2
    card_top = vertical_margin + (inner_height - stack_height) // 2
    cards = []
    for family in families:
        card_width, card_height = card_sizes[family]
        card_left = (board_width - card_width) // 2
        cards.append(
            (
                draw_widget_card((card_width, card_height), family, platform),
                card_left,
                card_top,
                family,
            )
        )
        card_top += card_height + gap
    shadow = Image.new("RGBA", board.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    for card, x, y, family in cards:
        corner_points = 22 if platform in {"ios", "ipad"} else 24
        radius = max(12, round(card.height * corner_points / family_points[family][1]))
        shadow_draw.rounded_rectangle(
            (x, y + round(board_width * 0.012), x + card.width, y + card.height + round(board_width * 0.012)),
            radius=radius,
            fill=(35, 60, 78, 70),
        )
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(board_width * 0.018)))
    board = Image.alpha_composite(board, shadow)
    for card, x, y, family in cards:
        corner_points = 22 if platform in {"ios", "ipad"} else 24
        mask = Image.new("L", card.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, card.width - 1, card.height - 1),
            radius=max(12, round(card.height * corner_points / family_points[family][1])),
            fill=255,
        )
        board.paste(card, (x, y), mask)

    board_x = (canvas_width - board_width) // 2
    shadow_canvas = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow_canvas).rounded_rectangle(
        (board_x, board_top + spec["shadow_offset"], board_x + board_width, board_top + board_height + spec["shadow_offset"]),
        radius=spec["radius"],
        fill=(20, 40, 55, 88),
    )
    shadow_canvas = shadow_canvas.filter(ImageFilter.GaussianBlur(spec["shadow_blur"]))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow_canvas)
    board_mask = Image.new("L", board.size, 0)
    ImageDraw.Draw(board_mask).rounded_rectangle(
        (0, 0, board.width - 1, board.height - 1),
        radius=spec["radius"],
        fill=255,
    )
    canvas.paste(board, (board_x, board_top), board_mask)

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)


def contact_sheet(platform: str) -> None:
    source_paths = [OUTPUT_DIR / platform / f"{stem}.png" for stem in SCREEN_STEMS]
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
    create_ios_push_source(IPAD_PUSH_SOURCE, (1440, 2560), tablet=True)
    for platform, spec in FORMATS.items():
        for stem, source_name, label, headline in APP_SCREENS:
            compose(
                app_source_path(platform, source_name, tablet=False),
                OUTPUT_DIR / platform / f"{stem}.png",
                label,
                headline,
                spec,
            )
        compose_widget_showcase(
            OUTPUT_DIR / platform / f"{WIDGET_SCREEN[0]}.png",
            WIDGET_SCREEN[1],
            WIDGET_SCREEN[2],
            spec,
            platform,
        )
        contact_sheet(platform)
    for platform, spec in TABLET_FORMATS.items():
        for stem, source_name, label, headline in APP_SCREENS:
            compose(
                app_source_path(platform, source_name, tablet=True),
                OUTPUT_DIR / platform / f"{stem}.png",
                label,
                headline,
                spec,
            )
        compose_widget_showcase(
            OUTPUT_DIR / platform / f"{WIDGET_SCREEN[0]}.png",
            WIDGET_SCREEN[1],
            WIDGET_SCREEN[2],
            spec,
            platform,
        )
        contact_sheet(platform)
    create_google_play_feature_graphic()
    create_google_play_app_icon()


if __name__ == "__main__":
    main()
