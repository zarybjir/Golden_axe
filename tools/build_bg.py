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
GROUND_CROP = {"swamp": (0.0, 0.32, 1.0, 1.0), "jungle": (0.0, 0.08, 1.0, 1.0)}
SPLIT_COMPONENTS = {"jungle"}
SKY_CROP = {"jungle": (0.0, 0.58)}  # z obrázku jen horní část (bez podlahy)


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


RES = 3  # textury mají 3× víc pixelů než logická velikost ve hře (ostré, ale ne kostičkované)


def grade(rgb):
    """Ponuré barevné ladění bez rastru: menší sytost, tmavší, lehce do zelena."""
    a = rgb.astype(float)
    lum = a.mean(axis=2, keepdims=True)
    a = lum + (a - lum) * 0.72
    a = a * 0.9
    a[..., 1] *= 1.03
    a[..., 2] *= 0.93
    return np.clip(a, 0, 255).astype(np.uint8)


def retro(im, size):
    """Zmenší na logickou velikost × RES a barevně doladí (plynulé, bez kostiček)."""
    im = im.convert("RGBA")
    big = im.resize((size[0] * RES, size[1] * RES), Image.LANCZOS)
    arr = np.asarray(big)
    return Image.fromarray(np.dstack([grade(arr[..., :3]), arr[..., 3]]), "RGBA")


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
    sky_im = Image.open(f"{src}/grim_{biome}_sky.png").convert("RGBA")
    sc = SKY_CROP.get(biome)
    if sc:
        sky_im = sky_im.crop((0, int(sky_im.height * sc[0]), sky_im.width, int(sky_im.height * sc[1])))
    sky = np.asarray(sky_im).astype(float)
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
    rows = 14 * RES
    a[:rows, :, 3] = (a[:rows, :, 3] * np.linspace(0, 1, rows)[:, None]).astype(np.uint8)
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
        # Objekty se často dotýkají u země – dělíme podle svislých mezer
        # v horních 80 % jejich výšky (kde se nedotýkají).
        objs = []
        if biome in SPLIT_COMPONENTS:
            # objekty z průhledného pozadí: každý souvislý tvar zvlášť
            lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=2))
            for i in range(1, n + 1):
                keep = (lab == i) & fg
                if keep.sum() < 3000:
                    continue
                yy, xx = np.nonzero(keep)
                objs.append((xx.min(), yy.min(), xx.max() + 1, yy.max() + 1, keep))
            fg = np.zeros_like(fg)
        ys_all = np.nonzero(fg.any(axis=1))[0] if fg.any() else np.array([0, 1])
        cut_y = int(ys_all.min() + (ys_all.max() - ys_all.min()) * 0.8)
        cols = fg[:cut_y].any(axis=0)
        x = 0
        W = fg.shape[1]
        while x < W:
            if not cols[x]:
                x += 1
                continue
            x0 = x
            while x < W and cols[x]:
                x += 1
            x1 = x
            mask = np.zeros_like(fg)
            mask[:, x0:x1] = fg[:, x0:x1]
            lab, n = ndimage.label(mask)
            if n == 0:
                continue
            sizes = ndimage.sum(mask, lab, range(n + 1))
            keep = np.isin(lab, np.nonzero(sizes > 300)[0][np.nonzero(sizes > 300)[0] > 0])
            if keep.sum() < 1500:
                continue
            yy, xx = np.nonzero(keep)
            objs.append((xx.min(), yy.min(), xx.max() + 1, yy.max() + 1, keep))
        tallest = max(o[3] - o[1] for o in objs)
        k = OBJ_H * rel / tallest
        # odstranit zelený lem z klíčování (zelená nesmí přesáhnout ostatní kanály)
        m = m.copy()
        m[..., 1] = np.minimum(m[..., 1], np.maximum(m[..., 0], m[..., 2]) + 8)
        for (x0, y0, x1, y1, mask) in sorted(objs, key=lambda o: o[0]):
            mask = ndimage.binary_erosion(mask, iterations=1)
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
        mag = (m[..., 0] > 110) & (m[..., 2] > 100) & (m[..., 1] < 0.72 * np.minimum(m[..., 0], m[..., 2]))
        mag = ndimage.binary_dilation(mag, iterations=2)
        # zbytky purpurové barvy na okrajích ztlumit
        m = m.copy()
        tint = (m[..., 0] + m[..., 2]) / 2 > m[..., 1] * 1.15
        m[tint, 0] = m[tint, 1]
        m[tint, 2] = m[tint, 1]
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
            w = 78 + 16 * (water_n % 3)
            wim = retro(im, (w, max(8, round(im.height * w / im.width * 0.62))))
            wa = np.asarray(wim).copy()
            # rozpitý okraj: plynulé zeslábnutí 5 px
            solid = wa[..., 3] > 0
            dist = ndimage.distance_transform_edt(solid)
            wa[..., 3] = (wa[..., 3] * np.clip(dist / (5 * RES), 0, 1)).astype(np.uint8)
            Image.fromarray(wa, "RGBA").save(f"{out}/water_{water_n}.png")
            water_n += 1
    # Vzdálená bažina: pás s tůněmi a rákosím (bez oblohy), měkké boční okraje
    mpath = f"{src}/grim_{biome}_marsh.png"
    if os.path.exists(mpath):
        mm = Image.open(mpath).convert("RGBA")
        mm = mm.crop((0, int(mm.height * 0.42), mm.width, mm.height))
        ma = np.asarray(mm).astype(float)
        ma[..., :3] *= 0.85
        marsh = retro(Image.fromarray(ma.astype(np.uint8), "RGBA"), (round(ma.shape[1] * 40 / ma.shape[0]), 40))
        a = np.asarray(marsh).copy().astype(float)
        hh, ww = a.shape[:2]
        top = np.clip(np.arange(hh) / (hh * 0.55), 0, 1)[:, None] ** 1.5
        xx = np.arange(ww)
        side = np.clip(np.minimum(xx, ww - 1 - xx) / (ww * 0.3), 0, 1)[None, :] ** 1.5
        a[..., 3] *= top * side
        a = a.astype(np.uint8)
        Image.fromarray(a, "RGBA").save(f"{out}/marsh.png")
    # Rozkládající se ostatky na cestu (zelené pozadí) -> corpse_N.png
    for f in os.listdir(out):
        if f.startswith("corpse_"):
            os.remove(os.path.join(out, f))
    corpse_n = 0
    for sheet in ("corpse", "corpse2"):
        path = f"{src}/grim_{biome}_{sheet}.png"
        if not os.path.exists(path):
            continue
        m = np.asarray(Image.open(path).convert("RGB")).astype(int)
        green = (m[..., 1] > 140) & (m[..., 0] < 150) & (m[..., 2] < 140) & (m[..., 1] > m[..., 0] + 60)
        fg = ndimage.binary_opening(~green, iterations=2)
        lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=8))
        m = m.copy()
        m[..., 1] = np.minimum(m[..., 1], np.maximum(m[..., 0], m[..., 2]) + 8)
        for i in range(1, n + 1):
            mask = (lab == i) & fg
            if mask.sum() < 3000:
                continue
            mask = ndimage.binary_erosion(mask, iterations=1)
            ys, xs = np.nonzero(mask)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            crop = np.dstack([m[y0:y1, x0:x1].astype(np.uint8), (mask[y0:y1, x0:x1] * 255).astype(np.uint8)])
            im = Image.fromarray(crop, "RGBA")
            w = 56
            ci = retro(im, (w, max(6, round(im.height * w / im.width * 0.75))))
            ca = np.asarray(ci).copy()
            dist = ndimage.distance_transform_edt(ca[..., 3] > 0)
            ca[..., 3] = (ca[..., 3] * np.clip(dist / (2 * RES), 0, 1)).astype(np.uint8)
            Image.fromarray(ca, "RGBA").save(f"{out}/corpse_{corpse_n}.png")
            corpse_n += 1
    # Překážky: klády (logs) a nášlapné pasti (plates) na zeleném pozadí
    extra = {}
    for sheet, prefix, width in (("logs", "log", 150), ("plates", "plate", 46)):
        for f in os.listdir(out):
            if f.startswith(prefix + "_"):
                os.remove(os.path.join(out, f))
        path = f"{src}/grim_{biome}_{sheet}.png"
        n_out = 0
        if os.path.exists(path):
            m = np.asarray(Image.open(path).convert("RGB")).astype(int)
            green = (m[..., 1] > 140) & (m[..., 0] < 160) & (m[..., 2] < 140) & (m[..., 1] > m[..., 0] + 50)
            fg = ndimage.binary_opening(~green, iterations=2)
            lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=4))
            m = m.copy()
            m[..., 1] = np.minimum(m[..., 1], np.maximum(m[..., 0], m[..., 2]) + 8)
            sizes = ndimage.sum(fg, lab, range(n + 1))
            for i in sorted(range(1, n + 1), key=lambda k: -sizes[k])[:2]:
                if sizes[i] < 5000:
                    continue
                mask = ndimage.binary_erosion((lab == i) & fg, iterations=1)
                ys, xs = np.nonzero(mask)
                x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
                crop = np.dstack([m[y0:y1, x0:x1].astype(np.uint8), (mask[y0:y1, x0:x1] * 255).astype(np.uint8)])
                im = Image.fromarray(crop, "RGBA")
                retro(im, (width, max(4, round(im.height * width / im.width)))).save(f"{out}/{prefix}_{n_out}.png")
                n_out += 1
        extra[f"{biome}_{prefix}"] = n_out
    # Seznam objektů pro hru
    data_path = os.path.join(ROOT, "scripts/bg_data.gd")
    data = {}
    if os.path.exists(data_path):
        mm = re.search(r"const OBJS := (\{.*?\})\n", open(data_path).read())
        if mm:
            data = json.loads(mm.group(1))
    data[biome] = objs_total
    data[biome + "_water"] = water_n
    data[biome + "_corpse"] = corpse_n
    data.update(extra)
    with open(data_path, "w") as f:
        f.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_bg.py – počet objektů v prostřední vrstvě.\n\n")
        f.write(f"const OBJS := {json.dumps(data)}\n")
        f.write(f"const RES := {RES}.0  # pixelů textury na 1 logický pixel\n")
    print(biome, "objektů:", objs_total)


if __name__ == "__main__":
    main(sys.argv[1])
