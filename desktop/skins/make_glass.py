#!/usr/bin/env python3
"""Regenerates the PNG art of the 'glass' sample skin (bitmap skins)."""
import os
from PIL import Image, ImageDraw

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "glass")
SS = 8  # supersampling


def bar(active):
    w, h = 24, 34
    top, bot = ((214, 232, 255), (150, 190, 245)) if active else ((236, 238, 242), (214, 218, 226))
    edge = (70, 110, 180, 255) if active else (160, 166, 178, 255)
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    px = im.load()
    for y in range(h * SS):
        t = y / (h * SS - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w * SS):
            px[x, y] = c
    # Gloss: a lighter band over the top half.
    gloss = Image.new("RGBA", im.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.rectangle([0, 0, w * SS, h * SS // 2], fill=(255, 255, 255, 70 if active else 40))
    im = Image.alpha_composite(im, gloss)
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * SS - 1, h * SS + 60], radius=9 * SS, fill=255)
    im.putalpha(mask)
    ImageDraw.Draw(im).rounded_rectangle([0, 0, w * SS - 1, h * SS + 60], radius=9 * SS,
                                         outline=edge, width=SS)
    return im.resize((w, h), Image.LANCZOS)


def orb(fill, state):
    s = 16
    shade = {"normal": 1.0, "hover": 1.15, "pressed": 0.8, "inactive": 1.0}[state]
    if state == "inactive":
        fill = (190, 194, 202)
    c = tuple(min(255, int(v * shade)) for v in fill)
    im = Image.new("RGBA", (s * SS, s * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([1 * SS, 1 * SS, 15 * SS - 1, 15 * SS - 1], fill=c + (255,),
              outline=tuple(int(v * 0.6) for v in c) + (255,), width=SS)
    d.ellipse([3.5 * SS, 2 * SS, 12.5 * SS, 7.5 * SS], fill=(255, 255, 255, 110))
    return im.resize((s, s), Image.LANCZOS)


def main():
    os.makedirs(HERE, exist_ok=True)
    bar(True).save(os.path.join(HERE, "bar_active.png"))
    bar(False).save(os.path.join(HERE, "bar_inactive.png"))
    colors = {"close": (232, 80, 72), "minimize": (240, 190, 60), "maximize": (70, 190, 90),
              "shade": (240, 190, 60), "menu": (100, 150, 230)}
    for name, col in colors.items():
        for state in ("normal", "hover", "pressed", "inactive"):
            orb(col, state).save(os.path.join(HERE, f"{name}_{state}.png"))


if __name__ == "__main__":
    main()
