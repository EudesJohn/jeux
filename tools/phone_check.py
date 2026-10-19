"""Analyse des captures d'écran du téléphone (vérification à distance).

Usage : python tools/phone_check.py export/shots/*.png

Imprime, pour chaque image : taille, couleur dominante, nombre de pixels or
(texte du jeu) et les bandes horizontales de « gris de bouton » (rectangles
des boutons du thème Godot par défaut). Sert à vérifier sans regarder l'écran
que l'écran attendu est bien affiché, et où taper.
"""

import sys
from collections import Counter

from PIL import Image


def gold_like(pixel) -> bool:
    r, g, b = pixel[:3]
    return r > 170 and 120 < g < 200 and b < 110


def button_like(pixel) -> bool:
    r, g, b = pixel[:3]
    return abs(r - g) < 14 and abs(g - b) < 14 and 40 < r < 110


def bands(image: Image.Image) -> list[tuple[int, int]]:
    """Bandes verticales contenant beaucoup de pixels « bouton »."""
    width, height = image.size
    pixels = image.load()
    step = 4
    rows = []
    for y in range(0, height, step):
        count = 0
        for x in range(0, width, step):
            if button_like(pixels[x, y]):
                count += 1
        rows.append((y, count))
    threshold = max(8, (width // step) // 8)
    out: list[tuple[int, int]] = []
    start = None
    for y, count in rows:
        if count >= threshold and start is None:
            start = y
        elif count < threshold and start is not None:
            out.append((start, y))
            start = None
    if start is not None:
        out.append((start, height))
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python tools/phone_check.py <capture.png> [...]")
        return 2
    for path in sys.argv[1:]:
        image = Image.open(path).convert("RGB")
        width, height = image.size
        pixels = image.load()
        sample = Counter(
            pixels[x, y]
            for y in range(0, height, 6)
            for x in range(0, width, 6)
        )
        gold = sum(1 for y in range(0, height, 3) for x in range(0, width, 3)
                   if gold_like(pixels[x, y]))
        print(f"== {path}  {width}x{height}")
        print(f"   couleurs dominantes : {sample.most_common(3)}")
        print(f"   pixels or (texte/UI) : {gold}")
        for index, (top, bottom) in enumerate(bands(image)):
            print(f"   bande {index} : y {top}-{bottom}  centre {height and (top + bottom) // 2}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
