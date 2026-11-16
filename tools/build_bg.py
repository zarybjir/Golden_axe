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
GROUND_DARK = 0.68  # ztmavení země
OBJ_H = 78       # výška největšího objektu v prostřední vrstvě (malé = daleko)
COLORS = 40
# Ponurá paleta: bláto, popel, špinavá oliva, zaschlá krev, kost
GRIM = ["14100e", "1e1814", "29211b", "352a22", "42352a", "514133", "62503f", "75624f",
        "8a7660", "222620", "30352c", "40463a", "55594f", "6b6e60", "36181a", "4e201c",
        "642a22", "7e3a2a", "8c7f68", "a89a7e", "4a4a52", "686470",
        "1f2a1c", "2c3a26", "3c4c30", "4e5e3a", "62704a", "7a845a"]  # tlumené zelené (voda, rákos)
# výřez země z obrázku (zlomky šířky/výšky), aby nebyly vidět kořeny na okrajích
GROUND_CROP = {"swamp": (0.30, 0.18, 0.74, 1.0)}


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def grim(rgb):
    """Převede na ponurou paletu s hrubým rastrem."""
    pal = np.array([[int(c[i:i + 2], 16) for i in (0, 2, 4)] for c in GRIM], float)
    a = rgb.astype(float)
    # ztlumit sytost a jas
    lum = a.mean(axis=2, keepdims=True)
    a = lum + (a - lum) * 0.72
    a *= 0.97
    h, w = a.shape[:2]
    a += BAYER[np.arange(h)[:, None] % 4, np.arange(w)[None, :] % 4][..., None] * 22.0
    d = ((a[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(axis=3)
    return pal[d.argmin(axis=2)].astype(np.uint8)


def retro(im, size):
    """Zmenší na cílovou velikost a převede na ponurou paletu (bez rozmazání)."""
    im = im.convert("RGBA")
    small = im.resize(size, Image.BOX)
    rgb = Image.fromarray(grim(np.asarray(small.convert("RGB"))))
    a = np.asarray(small)[..., 3]
    a = np.where(a > 128, 255, 0).astype(np.uint8)
    return Image.fromarray(np.dstack([np.asarray(rgb), a]), "RGBA")


def seamless(arr, blend=120):
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
    c = GROUND_CROP.get(biome, (0.0, 0.08, 1.0, 1.0))
    g = g.crop((int(g.width * c[0]), int(g.height * c[1]), int(g.width * c[2]), int(g.height * c[3])))
    ga = seamless(np.asarray(g).astype(float))
    ga[..., :3] *= GROUND_DARK
    gi = retro(Image.fromarray(ga.astype(np.uint8), "RGBA"), (round(ga.shape[1] * GROUND_H / ga.shape[0]), GROUND_H))
    a = np.asarray(gi).copy()
    rows = 14
    # zubatý přechod (dithering) místo rovné hrany
    for y in range(rows):
        keep = (np.indices(a.shape[:2])[1][y] * 7 + y * 3) % rows < y
        a[y, ~keep, 3] = 0
    Image.fromarray(a, "RGBA").save(f"{out}/ground.png")
    # Objekty na zeleném pozadí (může jich být víc listů: _mid, _mid2, _mid3 ...)
    for f in os.listdir(out):
        if f.startswith("obj_"):
            os.remove(os.path.join(out, f))
    objs_total = 0
    for sheet, rel in (("mid", 1.0), ("mid2", 0.9), ("mid3", 0.55)):
        path = f"{src}/grim_{biome}_{sheet}.png"
        if not os.path.exists(path):
            continue
        m = np.asarray(Image.open(path).convert("RGB")).astype(int)
        green = (m[..., 1] > 140) & (m[..., 0] < 150) & (m[..., 2] < 140) & (m[..., 1] > m[..., 0] + 60)
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
        k = OBJ_H * rel / tallest
        for (x0, y0, x1, y1, mask) in sorted(objs, key=lambda o: o[0]):
            crop = np.dstack([m[y0:y1, x0:x1].astype(np.uint8), (mask[y0:y1, x0:x1] * 255).astype(np.uint8)])
            im = Image.fromarray(crop, "RGBA")
            retro(im, (max(1, round(im.width * k)), max(1, round(im.height * k)))).save(f"{out}/obj_{objs_total}.png")
            objs_total += 1
    # Voda: kaluže a brody na purpurovém pozadí -> water_N.png (zploštělé do perspektivy)
    for f in os.listdir(out):
        if f.startswith("water_"):
            os.remove(os.path.join(out, f))
    water_n = 0
    wpath = f"{src}/grim_{biome}_water.png"
    if os.path.exists(wpath):
        m = np.asarray(Image.open(wpath).convert("RGB")).astype(int)
        mag = (m[..., 0] > 160) & (m[..., 2] > 160) & (m[..., 1] < 120)
        fg = ndimage.binary_opening(~mag, iterations=2)
        lab, n = ndimage.label(fg)
        sizes = ndimage.sum(fg, lab, range(n + 1))
        for i in np.argsort(-sizes)[:8]:
            if i == 0 or sizes[i] < 4000:
                continue
            ys, xs = np.nonzero(lab == i)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            mask = (lab[y0:y1, x0:x1] == i)
            crop = np.dstack([m[y0:y1, x0:x1].astype(np.uint8), (mask * 255).astype(np.uint8)])
            im = Image.fromarray(crop, "RGBA")
            w = 120 + 60 * (water_n % 3)
            retro(im, (w, max(8, round(im.height * w / im.width * 0.42)))).save(f"{out}/water_{water_n}.png")
            water_n += 1
    # Vzdálená bažina: pás s tůněmi a rákosím (bez oblohy), měkké boční okraje
    mpath = f"{src}/grim_{biome}_marsh.png"
    if os.path.exists(mpath):
        mm = Image.open(mpath).convert("RGBA")
        mm = mm.crop((0, int(mm.height * 0.36), mm.width, mm.height))
        ma = seamless(np.asarray(mm).astype(float))
        marsh = retro(Image.fromarray(ma.astype(np.uint8), "RGBA"), (round(ma.shape[1] * 40 / ma.shape[0]), 40))
        a = np.asarray(marsh).copy()
        rows = 6
        for y in range(rows):
            keep = (np.arange(a.shape[1]) * 7 + y * 3) % rows < y
            a[y, ~keep, 3] = 0
        Image.fromarray(a, "RGBA").save(f"{out}/marsh.png")
    # Seznam objektů pro hru
    data_path = os.path.join(ROOT, "scripts/bg_data.gd")
    data = {}
    if os.path.exists(data_path):
        mm = re.search(r"const OBJS := (\{.*\})", open(data_path).read())
        if mm:
            data = json.loads(mm.group(1))
    data[biome] = objs_total
    data[biome + "_water"] = water_n
    with open(data_path, "w") as f:
        f.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_bg.py – počet objektů v prostřední vrstvě.\n\n")
        f.write(f"const OBJS := {json.dumps(data)}\n")
    print(biome, "objektů:", objs_total)


if __name__ == "__main__":
    main(sys.argv[1])
