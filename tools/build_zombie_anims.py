"""Animace zombie z videí (snímky po odstranění pozadí, 12 fps).

Použití:  python3 tools/build_zombie_anims.py SLOZKA
SLOZKA obsahuje k_<video>/cut/r_NNN.png (viz tools/video_to_frames.py).
Výstup: art/enemy_anim/zombie/*.webp a scripts/zombie_anims.gd.
Kotva (střed chodidel) se bere z prvního snímku každého videa zvlášť,
protože zombie s rukou a bez ruky má jiný výchozí obrázek.
"""
import os
import sys

import numpy as np
from PIL import Image

H = 98.0   # výška zombie ve hře (logické px) podle prvního snímku chůze
# animace: (video, snímky, smyčka, snímek úderu)
ANIMS = {
    "walk": ("awalk", list(range(0, 60)), True, -1),
    "attack": ("aatk", list(range(0, 60)), False, 20),
    "walk2": ("bwalk", list(range(0, 60)), True, -1),
    "attack2": ("batk", list(range(0, 60)), False, 20),
}


def anchor(path):
    a = np.asarray(Image.open(path))[..., 3] > 128
    ys, xs = np.nonzero(a)
    bottom = ys.max()
    feet = xs[ys > bottom - 20]
    return float(feet.mean()), float(bottom), float(bottom - ys.min())


def main(src, anims=ANIMS):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "art/enemy_anim/zombie")
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        os.remove(os.path.join(out, f))
    _, _, h0 = anchor(f"{src}/k_{anims['walk'][0]}/cut/r_001.png")
    k = H / h0
    lines = ["extends RefCounted", "## VYGENEROVÁNO skriptem tools/build_zombie_anims.py – neupravovat ručně.", "",
             f"const K := {k:.4f}", "const ANIMS := {"]
    for name, (vid, frames, loop, impact) in anims.items():
        ax, ay, _ = anchor(f"{src}/k_{vid}/cut/r_001.png")
        paths, offs = [], []
        for n, idx in enumerate(frames):
            im = Image.open(f"{src}/k_{vid}/cut/r_{idx + 1:03d}.png").convert("RGBA")
            a = np.asarray(im).copy()
            al = a[..., 3]
            al[al < 24] = 0
            ys, xs = np.nonzero(al)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            fn = f"{name}_{n:02d}.webp"
            Image.fromarray(a, "RGBA").crop((x0, y0, x1, y1)).save(os.path.join(out, fn), quality=82, method=6)
            with open(os.path.join(out, fn + ".import"), "w") as g:
                g.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\n'
                        f'source_file="res://art/enemy_anim/zombie/{fn}"\n\n[params]\n\n'
                        'compress/mode=1\ncompress/lossy_quality=0.85\nmipmaps/generate=false\n')
            paths.append(f'"res://art/enemy_anim/zombie/{fn}"')
            offs.append(f"Vector2({x0 - ax:.1f}, {y0 - ay:.1f})")
        lines.append(f'\t"{name}": {{"loop": {str(loop).lower()}, "impact": {impact},')
        lines.append(f'\t\t"frames": [{", ".join(paths)}],')
        lines.append(f'\t\t"offsets": [{", ".join(offs)}]}},')
    lines += ["}", ""]
    open(os.path.join(root, "scripts/zombie_anims.gd"), "w").write("\n".join(lines))
    print("hotovo, k =", round(k, 4))


if __name__ == "__main__":
    main(sys.argv[1])
