"""Visuels du store : fond d'icône adaptative et bannière Play.

Usage : python tools/make_store_assets.py

Produit
    assets/ui/store/icon_adaptive_background_432.png   432×432 (fond Android)
    export/store/feature_graphic_1024x500.png          1024×500 (fiche Play)

L'icône 512 et le calque avant sont rasterisés depuis les SVG par
`godot --headless --path . --script res://tools/make_store_assets.gd`.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "assets" / "ui" / "store"
EXPORT = ROOT / "export" / "store"
FONTS = Path("C:/Windows/Fonts")

INDIGO = (27, 35, 71)
INDIGO_DARK = (12, 18, 42)
GOLD = (227, 169, 43)
CREAM = (245, 233, 208)
RED = (179, 38, 30)


def vertical_gradient(size, top, bottom):
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(1, height - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (width, y)], fill=color)
    return image


def radial_glow(size, center, radius, color, strength=90):
    layer = Image.new("L", size, 0)
    draw = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps, 0, -1):
        r = radius * i / steps
        alpha = int(strength * (1 - i / steps) ** 1.6)
        draw.ellipse(
            [center[0] - r, center[1] - r, center[0] + r, center[1] + r],
            fill=alpha,
        )
    layer = layer.filter(ImageFilter.GaussianBlur(radius / 8))
    glow = Image.new("RGB", size, color)
    return glow, layer


def adaptive_background() -> Path:
    size = (432, 432)
    base = vertical_gradient(size, INDIGO, INDIGO_DARK).convert("RGBA")
    glow_rgb, glow_mask = radial_glow(size, (216, 200), 300, (46, 62, 120), 120)
    base.paste(glow_rgb, (0, 0), glow_mask)

    draw = ImageDraw.Draw(base, "RGBA")
    # Cercles concentriques discrets, rappel des appliques du Dahomey.
    for radius in (150, 178, 206):
        draw.ellipse(
            [216 - radius, 216 - radius, 216 + radius, 216 + radius],
            outline=(227, 169, 43, 22),
            width=3,
        )
    # Chevrons d'angle.
    for x, y, dx, dy in ((30, 30, 1, 1), (402, 30, -1, 1), (30, 402, 1, -1), (402, 402, -1, -1)):
        draw.line([(x, y), (x + 54 * dx, y)], fill=(227, 169, 43, 45), width=4)
        draw.line([(x, y), (x, y + 54 * dy)], fill=(227, 169, 43, 45), width=4)

    out = STORE / "icon_adaptive_background_432.png"
    base.convert("RGB").save(out)
    return out


def feature_graphic() -> Path:
    size = (1024, 500)
    image = vertical_gradient(size, (34, 44, 86), INDIGO_DARK).convert("RGBA")
    glow_rgb, glow_mask = radial_glow(size, (250, 250), 380, (60, 76, 136), 100)
    image.paste(glow_rgb, (0, 0), glow_mask)

    icon = Image.open(STORE / "icon_512.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
    image.alpha_composite(icon, (64, 100))

    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(FONTS / "georgiab.ttf"), 66)
    tag_font = ImageFont.truetype(str(FONTS / "calibri.ttf"), 29)
    kick_font = ImageFont.truetype(str(FONTS / "calibrib.ttf"), 18)
    studio_font = ImageFont.truetype(str(FONTS / "calibri.ttf"), 19)

    x = 410
    draw.text((x, 108), "ABOMEY", font=title_font, fill=GOLD)
    draw.text((x, 178), "WARRIORS", font=title_font, fill=GOLD)

    draw.line([(x + 2, 262), (x + 150, 262)], fill=(227, 169, 43, 120), width=3)
    draw.text((x, 284), "Sabre au poing,", font=tag_font, fill=CREAM)
    draw.text((x, 320), "libérez le royaume.", font=tag_font, fill=CREAM)

    kicker = " ".join("ACTION-AVENTURE 3D · HORS LIGNE")
    draw.text((x, 70), kicker, font=kick_font, fill=(227, 169, 43, 190))
    draw.text((x, 400), "JOHNSON STUDIO · BÉNIN", font=studio_font, fill=(200, 190, 170, 170))

    EXPORT.mkdir(parents=True, exist_ok=True)
    out = EXPORT / "feature_graphic_1024x500.png"
    image.convert("RGB").save(out, optimize=True)
    return out


if __name__ == "__main__":
    for path in (adaptive_background(), feature_graphic()):
        with Image.open(path) as im:
            print(f"[store] {path.relative_to(ROOT)} {im.size} {im.mode}")
