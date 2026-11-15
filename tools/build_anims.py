"""Z vyříznutých snímků videa (tools/video_to_frames.py) poskládá animace hrdiny
do art/hero_anim/ a vygeneruje scripts/hero_anims.gd.

Použití:  python3 tools/build_anims.py slozka_se_snimky
(ve složce jsou podsložky pojmenované podle videí, každá s podsložkou cut/)
"""
import os
import sys

import numpy as np
from PIL import Image

HERO_HEIGHT = 88.0      # výška hrdiny ve hře (logické pixely)
TEX_HEIGHT = 330.0      # výška hrdiny v texturách (px)

# Zdrojová videa (snímky po tools/video_to_frames.py při 12 fps):
#   složka (relativně k argumentu skriptu), kotva = místo mezi chodidly na zemi, výška hrdiny ve videu
SOURCES = {
    "v2": ("video_hero_moves", (553.0, 690.0), 660.0),
    "v3": ("video_hero_moves2", (621.0, 718.0), 701.0),
}

# název: (zdroj, snímky, fps, smyčka, index snímku úderu nebo -1, kotva "ground"/"feet")
ANIMS = {
    "idle": ("v2", list(range(46, 86, 2)), 6.0, True, -1, "ground"),
    "walk": ("v2", list(range(9, 25)), 12.0, True, -1, "ground"),
    "atk1": ("v3", [55, 56, 57, 58, 59, 60, 61], 12.0, False, 3, "ground"),
    "atk2": ("v3", [61, 62, 63, 64, 65, 66], 12.0, False, 2, "ground"),
    "atk3": ("v3", list(range(71, 82)), 12.0, False, 6, "ground"),
    "jump": ("v3", [111, 101, 102, 103, 104, 112], 12.0, False, -1, "feet"),
    "magic": ("v3", list(range(140, 165)), 12.0, False, 12, "ground"),
    "down": ("v3", list(range(83, 100)), 12.0, False, -1, "ground"),
    "getup": ("v3", list(range(100, 114)), 12.0, False, -1, "ground"),
    "dodge": ("v3", [101, 102, 103, 104, 112, 113], 12.0, False, -1, "ground"),
}


def main(frames_root):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "art/hero_anim")
    os.makedirs(out_dir, exist_ok=True)
    k = HERO_HEIGHT / TEX_HEIGHT
    lines = [
        "extends RefCounted",
        "## VYGENEROVÁNO skriptem tools/build_anims.py – neupravovat ručně.",
        "## Animace hrdiny z videa: snímky, posun vůči chodidlům, rychlost a snímek úderu.",
        "",
        f"const K := {k:.4f}  # logické pixely hry na 1 pixel textury",
        "const ANIMS := {",
    ]
    for name, (src, frames, fps, loop, impact, anchor) in ANIMS.items():
        folder, anc, vid_h = SOURCES[src]
        scale = TEX_HEIGHT / vid_h
        paths, offs = [], []
        for n, idx in enumerate(frames):
            im = Image.open(os.path.join(frames_root, folder, "cut", f"r_{idx + 1:03d}.png")).convert("RGBA")
            im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
            a = np.asarray(im)[..., 3]
            ys, xs = np.nonzero(a > 8)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            crop = im.crop((x0, y0, x1, y1))
            fname = f"{name}_{n:02d}.webp"
            crop.save(os.path.join(out_dir, fname), quality=88, method=6)
            ax = anc[0] * scale
            ay = anc[1] * scale if anchor == "ground" else float(y1)
            paths.append(f'"res://art/hero_anim/{fname}"')
            offs.append(f"Vector2({x0 - ax:.1f}, {y0 - ay:.1f})")
        lines.append(f'\t"{name}": {{"fps": {fps}, "loop": {str(loop).lower()}, "impact": {impact},')
        lines.append(f'\t\t"frames": [{", ".join(paths)}],')
        lines.append(f'\t\t"offsets": [{", ".join(offs)}]}},')
    lines.append("}")
    lines.append("")
    with open(os.path.join(root, "scripts/hero_anims.gd"), "w") as f:
        f.write("\n".join(lines))
    print(f"K={k:.4f}, hotovo")


if __name__ == "__main__":
    main(sys.argv[1])
