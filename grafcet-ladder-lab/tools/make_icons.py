"""Génère les icônes Android (ladder + étape GRAFCET) dans android/app/src/main/res."""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')
BG = (20, 32, 46)
FG = (255, 210, 63)
GREEN = (51, 224, 122)


def draw(size, full_bg=True, scale=1.0):
    img = Image.new('RGBA', (size, size), BG + (255,) if full_bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size / 100 * scale
    o = (size - 100 * s) / 2
    P = lambda x, y: (o + x * s, o + y * s)
    w = max(2, int(5 * s))
    # rails Ladder
    d.line([P(18, 22), P(18, 78)], fill=FG, width=w)
    d.line([P(82, 22), P(82, 78)], fill=FG, width=w)
    # ligne avec contact et bobine
    d.line([P(18, 38), P(34, 38)], fill=FG, width=w)
    d.line([P(34, 28), P(34, 48)], fill=FG, width=w)
    d.line([P(44, 28), P(44, 48)], fill=FG, width=w)
    d.line([P(44, 38), P(58, 38)], fill=FG, width=w)
    d.arc([P(56, 28), P(70, 48)], 100, 260, fill=GREEN, width=w)
    d.arc([P(62, 28), P(76, 48)], -80, 80, fill=GREEN, width=w)
    d.line([P(73, 38), P(82, 38)], fill=FG, width=w)
    # étape GRAFCET
    d.rectangle([P(38, 56), P(62, 76)], outline=(255, 255, 255), width=w)
    d.line([P(50, 76), P(50, 84)], fill=(255, 255, 255), width=w)
    d.line([P(43, 84), P(57, 84)], fill=(255, 255, 255), width=w + 2)
    return img


legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for dpi, px in legacy.items():
    folder = os.path.join(ROOT, f'mipmap-{dpi}')
    os.makedirs(folder, exist_ok=True)
    icon = draw(px)
    icon.save(os.path.join(folder, 'ic_launcher.png'))
    mask = Image.new('L', (px, px), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, px - 1, px - 1], fill=255)
    rnd = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    rnd.paste(icon, (0, 0), mask)
    rnd.save(os.path.join(folder, 'ic_launcher_round.png'))
    fg = draw(int(px * 108 / 48), full_bg=False, scale=0.62)
    fg.save(os.path.join(folder, 'ic_launcher_foreground.png'))

bgxml = os.path.join(ROOT, 'values', 'ic_launcher_background.xml')
with open(bgxml, 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#14202E</color>\n</resources>\n')
print('icônes générées')
