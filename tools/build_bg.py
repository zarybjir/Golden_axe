"""Zpracuje vygenerovaná pozadí do hrubého retro vzhledu (nízké rozlišení, omezená paleta).

Použití:  python3 tools/build_bg.py BIOME
Vstupy v art/source/grim_<biome>_sky.png, _mid.png (objekty na zeleném pozadí), _ground.png.
Výstup: art/bg/<biome>/sky.png, ground.png, obj_N.png a scripts/bg_data.gd (počty objektů).
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKY_H = 200      # výška oblohy ve hře (logické px)
GROUND_H = 150   # výška pásu země
OBJ_H = 130      # výška největšího objektu v prostřední vrstvě
COLORS = 40


def retro(im, size):
    """Zmenší na cílovou velikost a omezí paletu (bez rozmazání)."""
    im = im.convert("RGBA")
    small = im.resize(size, Image.BOX)
    rgb = small.convert("RGB").quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    a = np.asarray(small)[..., 3]
    a = np.where(a > 128, 255, 0).astype(np.uint8)
    return Image.fromarray(np.dstack([np.asarray(rgb), a]), "RGBA")


def seamless(arr, blend=200):
    w = arr.shape[1]
    out = arr[:, : w - blend].copy()
    t = np.linspace(0, 1, blend)[None, :, None]
    out[:, :blend] = arr[:, w - blend:] * (1 - t) + arr[:, :blend] * t
    return out


def main(biome):
    src = os.path.join(ROOT, "art/source")
    out = os.path.join(ROOT, "art/bg", biome)
    os.makedirs(out, exist_ok=True)
    # Obloha – bezešvá smyčka
    sky = np.asarray(Image.open(f"{src}/grim_{biome}_sky.png").convert("RGBA")).astype(float)
    sky = Image.fromarray(seamless(sky).astype(np.uint8), "RGBA")
    retro(sky, (round(sky.width * SKY_H / sky.height), SKY_H)).save(f"{out}/sky.png")
    # Zem – ořez horního okraje, bezešvá, měkký přechod nahoře
    g = Image.open(f"{src}/grim_{biome}_ground.png").convert("RGBA")
    g = g.crop((0, int(g.height * 0.08), g.width, g.height))
    ga = seamless(np.asarray(g).astype(float))
    gi = retro(Image.fromarray(ga.astype(np.uint8), "RGBA"), (round(ga.shape[1] * GROUND_H / ga.shape[0]), GROUND_H))
    a = np.asarray(gi).copy()
    rows = 14
    # zubatý přechod (dithering) místo rovné hrany
    for y in range(rows):
        keep = (np.indices(a.shape[:2])[1][y] * 7 + y * 3) % rows < y
        a[y, ~keep, 3] = 0
    Image.fromarray(a, "RGBA").save(f"{out}/ground.png")
    # Objekty na zeleném pozadí
    m = np.asarray(Image.open(f"{src}/grim_{biome}_mid.png").convert("RGB")).astype(int)
    green = (m[..., 1] > 140) & (m[..., 0] < 140) & (m[..., 2] < 140) & (m[..., 1] > m[..., 0] + 60)
    fg = ndimage.binary_opening(~green, iterations=2)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=6))
    objs = []
    for i in range(1, n + 1):
        mask = (lab == i) & fg
        if mask.sum() < 1500:
            continue
        ys, xs = np.nonzero(mask)
        objs.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, mask))
    tallest = max(o[3] - o[1] for o in objs)
    k = OBJ_H / tallest
    for f in os.listdir(out):
        if f.startswith("obj_"):
            os.remove(os.path.join(out, f))
    for idx, (x0, y0, x1, y1, mask) in enumerate(sorted(objs)):
        crop = np.dstack([m[y0:y1, x0:x1].astype(np.uint8), (mask[y0:y1, x0:x1] * 255).astype(np.uint8)])
        im = Image.fromarray(crop, "RGBA")
        retro(im, (max(1, round(im.width * k)), max(1, round(im.height * k)))).save(f"{out}/obj_{idx}.png")
    # Seznam objektů pro hru
    data_path = os.path.join(ROOT, "scripts/bg_data.gd")
    data = {}
    if os.path.exists(data_path):
        mm = re.search(r"const OBJS := (\{.*\})", open(data_path).read())
        if mm:
            data = json.loads(mm.group(1))
    data[biome] = len(objs)
    with open(data_path, "w") as f:
        f.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_bg.py – počet objektů v prostřední vrstvě.\n\n")
        f.write(f"const OBJS := {json.dumps(data)}\n")
    print(biome, "objektů:", len(objs))


if __name__ == "__main__":
    main(sys.argv[1])
