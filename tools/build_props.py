"""Sudy podle prostředí a namalovaný drak (průhledné pozadí).

Použití:  python3 tools/build_props.py
Vstupy:  art/source/grim_barrels.png (4 nádoby zleva: bažina, hřbitov, džungle, hory),
         art/source/grim_dragon.png (2 pózy téhož draka: klid, řev),
         art/source/grim_rocks.png (padající kameny v horách).
Výstup:  art/props/barrel_<biome>.png, art/enemy_sprite/drak_{idle,roar}.png, scripts/dragon_data.gd
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_bg import grade, RES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BARREL_H = 34      # výška sudu ve hře (logické px)
DRAGON_H = 136
CHAMOIS_H = 76     # výška démonického kamzíka (stoj)
GOLEM_H = 150      # výška kamenného obra (stoj) ve hře
ZOMBIE_H = 98       # výška zombie (chůze) ve hře     # výška draka v klidu (logické px)


def parts(path, n, rows=False):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)
    fg = ndimage.binary_opening(a[..., 3] > 100, iterations=2)
    lab, k = ndimage.label(ndimage.binary_dilation(fg, iterations=6))
    sizes = ndimage.sum(fg, lab, range(k + 1))
    ids = sorted(range(1, k + 1), key=lambda i: -sizes[i])[:n]
    out = []
    for i in ids:
        m = ndimage.binary_dilation((lab == i) & (a[..., 3] > 0), iterations=1) & (a[..., 3] > 0)
        ys, xs = np.nonzero(m)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        c = a[y0:y1, x0:x1].copy()
        c[..., 3] = np.where(m[y0:y1, x0:x1], c[..., 3], 0)
        out.append(((y0 + y1) / 2 > a.shape[0] / 2 if rows else 0, x0, c))
    return [o[2] for o in sorted(out, key=lambda o: (o[0], o[1]))]


def grid(path, cols, rows):
    """Póza v každé buňce mřížky (zleva doprava, shora dolů); bere se největší tvar v buňce."""
    a = np.asarray(Image.open(path).convert("RGBA"))
    H, W = a.shape[:2]
    out = []
    for r in range(rows):
        for c in range(cols):
            cell = a[r * H // rows:(r + 1) * H // rows, c * W // cols:(c + 1) * W // cols]
            fg = cell[..., 3] > 100
            lab, k = ndimage.label(ndimage.binary_dilation(fg, iterations=4))
            sizes = ndimage.sum(fg, lab, range(k + 1))
            i = int(np.argmax(sizes[1:])) + 1
            m = (lab == i) & (cell[..., 3] > 0)
            ys, xs = np.nonzero(m)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            cc = cell[y0:y1, x0:x1].copy()
            cc[..., 3] = np.where(m[y0:y1, x0:x1], cc[..., 3], 0)
            out.append(cc)
    return out


def save(arr, k, path):
    im = Image.fromarray(arr, "RGBA")
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    big = np.asarray(im.resize((w, h), Image.LANCZOS))
    Image.fromarray(np.dstack([grade(big[..., :3]), big[..., 3]]), "RGBA").save(path)
    return w, h


def main():
    os.makedirs(f"{ROOT}/art/props", exist_ok=True)
    for biome, c in zip(["swamp", "graveyard", "jungle", "mountain"], parts(f"{ROOT}/art/source/grim_barrels.png", 4)):
        save(c, BARREL_H * RES / c.shape[0], f"{ROOT}/art/props/barrel_{biome}.png")
    rpath = f"{ROOT}/art/source/grim_rocks.png"
    if os.path.exists(rpath):
        for i, c in enumerate(parts(rpath, 5)):
            hgt = [26, 34, 22, 30, 38][i]
            save(c, hgt * RES / c.shape[0], f"{ROOT}/art/props/rock_{i}.png")
    dpath = f"{ROOT}/art/source/grim_dirt.png"
    if os.path.exists(dpath):
        for i, c in enumerate(parts(dpath, 4)):
            save(c, 58 * RES / c.shape[1], f"{ROOT}/art/props/dirt_{i}.png")
    zpath = f"{ROOT}/art/source/grim_zombie.png"
    if os.path.exists(zpath):
        zp = parts(zpath, 6, rows=True)
        names = ["walk", "reach", "onearm", "club_up", "club_hit", "arm"]
        kz = ZOMBIE_H * RES / zp[0].shape[0]
        zmeta = {}
        for name, c in zip(names, zp):
            w, h = save(c, kz, f"{ROOT}/art/enemy_sprite/zombie_{name}.png")
            al = c[..., 3] > 100
            ys, xs = np.nonzero(al[int(al.shape[0] * 0.88):])
            zmeta[name] = [round(w / RES, 1), round(h / RES, 1), round(float(xs.mean()) * kz / RES, 1)]
        with open(f"{ROOT}/scripts/zombie_data.gd", "w") as fo:
            fo.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_props.py\n")
            fo.write("## póza: [šířka, výška, kotva x (střed nohou)] v logických px\n\nconst POSE := {\n")
            for n_, v in zmeta.items():
                fo.write(f'\t"{n_}": [{", ".join(str(x) for x in v)}],\n')
            fo.write("}\n")
        print(zmeta)
    gpath = f"{ROOT}/art/source/grim_golem.png"
    if os.path.exists(gpath):
        gp = grid(gpath, 3, 2)
        names = ["idle", "walk", "wind", "punch", "tear", "hold"]
        kg = GOLEM_H * RES / gp[0].shape[0]
        gmeta = {}
        for name, c in zip(names, gp):
            w, h = save(c, kg, f"{ROOT}/art/enemy_sprite/golem_{name}.png")
            al = c[..., 3] > 100
            ys, xs = np.nonzero(al[int(al.shape[0] * 0.9):])
            gmeta[name] = [round(w / RES, 1), round(h / RES, 1), round(float(xs.mean()) * kg / RES, 1)]
        with open(f"{ROOT}/scripts/golem_data.gd", "w") as fo:
            fo.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_props.py\n")
            fo.write("## póza: [šířka, výška, kotva x (střed nohou)] v logických px\n\nconst POSE := {\n")
            for n_, v in gmeta.items():
                fo.write(f'\t"{n_}": [{", ".join(str(x) for x in v)}],\n')
            fo.write("}\n")
        print(gmeta)
    cpath = f"{ROOT}/art/source/grim_chamois.png"
    if os.path.exists(cpath):
        cp_ = grid(cpath, 3, 2)
        names = ["idle", "run1", "run2", "rear", "charge", "down"]
        kc = CHAMOIS_H * RES / cp_[0].shape[0]
        cmeta = {}
        for name, c in zip(names, cp_):
            w, h = save(c, kc, f"{ROOT}/art/enemy_sprite/kamzik_{name}.png")
            cmeta[name] = [round(w / RES, 1), round(h / RES, 1), round(w / RES * 0.5, 1)]
        with open(f"{ROOT}/scripts/chamois_data.gd", "w") as fo:
            fo.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_props.py\n")
            fo.write("## póza: [šířka, výška, kotva x] v logických px\n\nconst POSE := {\n")
            for n_, v in cmeta.items():
                fo.write(f'\t"{n_}": [{", ".join(str(x) for x in v)}],\n')
            fo.write("}\n")
        print(cmeta)
    idle, roar = parts(f"{ROOT}/art/source/grim_dragon.png", 2)
    k = DRAGON_H * RES / idle.shape[0]   # obě pózy ve stejném měřítku
    meta = {}
    for name, c in (("idle", idle), ("roar", roar)):
        w, h = save(c, k, f"{ROOT}/art/enemy_sprite/drak_{name}.png")
        al = c[..., 3] > 100
        hh, ww = al.shape
        # kotva: střed nohou (spodních 12 % výšky)
        ys, xs = np.nonzero(al[int(hh * 0.88):])
        ax = xs.mean()
        # tlama: nejpravější bod hlavy (u řevu v pásu 45–75 % výšky, v klidu 15–45 %)
        r0, r1 = (0.45, 0.75) if name == "roar" else (0.15, 0.45)
        ys, xs = np.nonzero(al[int(hh * r0):int(hh * r1)])
        j = xs.argmax()
        mx, my = xs[j], ys[j] + int(hh * r0)
        f = k / RES
        meta[name] = [round(w / RES, 1), round(h / RES, 1), round(ax * f, 1), round((mx - ax) * f, 1), round((my - hh) * f, 1)]
    with open(f"{ROOT}/scripts/dragon_data.gd", "w") as fo:
        fo.write("extends RefCounted\n## VYGENEROVÁNO skriptem tools/build_props.py\n")
        fo.write("## póza: [šířka, výška, kotva x (střed nohou), tlama x od kotvy, tlama y od země] v logických px\n\n")
        fo.write("const POSE := {\n")
        for n, v in meta.items():
            fo.write(f'\t"{n}": [{", ".join(str(x) for x in v)}],\n')
        fo.write("}\nconst RES := %d.0\n" % RES)
    print(meta)


if __name__ == "__main__":
    main()
