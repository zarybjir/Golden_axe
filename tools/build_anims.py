"""Z vyříznutých snímků videa (tools/video_to_frames.py) poskládá animace hrdiny
do art/hero_anim/ a vygeneruje scripts/hero_anims.gd.

Použití:  python3 tools/build_anims.py slozka_s_cut_snimky
Čísla snímků níže odpovídají videu art/source/video_hero_moves.mp4 při 12 fps.
"""
import os
import sys

import numpy as np
from PIL import Image

SCALE = 0.5            # zmenšení snímků (video 1280×720 -> textury)
HERO_HEIGHT = 88.0      # výška hrdiny ve hře (logické pixely)
VIDEO_HEIGHT = 660.0    # výška hrdiny ve videu (px při 1280×720)
ANCHOR = (553.0, 690.0)  # místo mezi chodidly na zemi (px ve videu)

# název: (snímky, fps, smyčka, index snímku úderu nebo -1, kotva "ground"/"feet")
ANIMS = {
    "idle": (list(range(46, 86, 2)), 6.0, True, -1, "ground"),
    "walk": (list(range(9, 25)), 12.0, True, -1, "ground"),
    "atk1": ([88, 89, 90, 91, 92, 93, 93, 92, 89], 12.0, False, 5, "ground"),
    "atk2": (list(range(93, 101)), 12.0, False, 1, "ground"),
    "atk3": (list(range(100, 126)), 12.0, False, 10, "ground"),
    "jump": (list(range(126, 134)), 12.0, False, -1, "feet"),
    "magic": (list(range(146, 161)), 12.0, False, 8, "ground"),
    "getup": (list(range(118, 126)), 12.0, False, -1, "ground"),
    "down": ([112, 113, 114], 6.0, True, -1, "ground"),
    "dodge": ([109, 110], 12.0, False, -1, "ground"),
}


def main(cut_dir):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "art/hero_anim")
    os.makedirs(out_dir, exist_ok=True)
    k = HERO_HEIGHT / (VIDEO_HEIGHT * SCALE)
    lines = [
        "extends RefCounted",
        "## VYGENEROVÁNO skriptem tools/build_anims.py – neupravovat ručně.",
        "## Animace hrdiny z videa: snímky, posun vůči chodidlům, rychlost a snímek úderu.",
        "",
        f"const K := {k:.4f}  # logické pixely hry na 1 pixel textury",
        "const ANIMS := {",
    ]
    for name, (frames, fps, loop, impact, anchor) in ANIMS.items():
        paths, offs = [], []
        for n, idx in enumerate(frames):
            im = Image.open(os.path.join(cut_dir, f"r_{idx + 1:03d}.png")).convert("RGBA")
            im = im.resize((round(im.width * SCALE), round(im.height * SCALE)), Image.LANCZOS)
            a = np.asarray(im)[..., 3]
            ys, xs = np.nonzero(a > 8)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            crop = im.crop((x0, y0, x1, y1))
            fname = f"{name}_{n:02d}.webp"
            crop.save(os.path.join(out_dir, fname), quality=88, method=6)
            ax = ANCHOR[0] * SCALE
            ay = ANCHOR[1] * SCALE if anchor == "ground" else float(y1)
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
