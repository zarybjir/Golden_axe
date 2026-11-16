"""Animace nepřátel z videí (snímky po odstranění pozadí, 12 fps, 960×540).

Použití:  python3 tools/build_enemy_anims.py SLOZKA
SLOZKA obsahuje pro každý druh podsložku (viz "src") s k_<video>/cut/r_NNN.png.
Výstup: art/enemy_anim/<druh>/*.webp a scripts/enemy_anims.gd.
"""
import os
import sys

import numpy as np
from PIL import Image

# druh: {"src": podsložka se snímky, "h": výška ve hře (logické px), "anchor": video pro kotvu,
#        "anims": {animace: (video, snímky, smyčka, snímek úderu)}}
# Vynechané snímky mají chyby z videa (zdvojený nebo rozmazaný kyj).
SETS = {
    "ogre": {"src": "en2", "h": 180.0, "anchor": "idle", "anims": {
        "idle": ("idle", list(range(0, 61, 2)), True, -1),
        "walk": ("walk", list(range(0, 31)), True, -1),
        "run": ("run", list(range(8, 48)), True, -1),
        "attack": ("attack", [i for i in range(9, 43) if i != 28], False, 18),
        "block": ("block", [i for i in range(6, 37) if i != 10], False, -1),
        "fall": ("fall", [i for i in range(9, 37) if i != 19], False, -1),
    }},
    "skeleton": {"src": "sk", "h": 96.0, "anchor": "v1", "anims": {
        "idle": ("v1", list(range(0, 21)) + list(range(19, 0, -1)), True, -1),
        "walk": ("v3", list(range(0, 31)), True, -1),
        "attack": ("v1", list(range(22, 51)), False, 14),
        "block": ("v2", list(range(4, 14)), False, -1),
        "fall": ("v2", [41, 42] + list(range(44, 56)), False, -1),
    }},
}


def main(src):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lines = ["extends RefCounted", "## VYGENEROVÁNO skriptem tools/build_enemy_anims.py – neupravovat ručně.", "", "const SETS := {"]
    for kind, cfg in SETS.items():
        anims = cfg["anims"]
        base = os.path.join(src, cfg["src"])
        out = os.path.join(root, "art/enemy_anim", kind)
        os.makedirs(out, exist_ok=True)
        for f in os.listdir(out):
            os.remove(os.path.join(out, f))
        # Kotva: střed chodidel v prvním snímku stání (kamera je statická)
        a0 = np.asarray(Image.open(f"{base}/k_{cfg['anchor']}/cut/r_001.png"))[..., 3] > 128
        ys, xs = np.nonzero(a0)
        bottom = ys.max()
        feet = xs[ys > bottom - 20]
        ax, ay = float(feet.mean()), float(bottom)
        k = cfg["h"] / float(bottom - ys.min())
        lines.append(f'\t"{kind}": {{"k": {k:.4f}, "anims": {{')
        for name, (vid, frames, loop, impact) in anims.items():
            paths, offs = [], []
            for n, idx in enumerate(frames):
                im = Image.open(f"{base}/k_{vid}/cut/r_{idx + 1:03d}.png").convert("RGBA")
                a = np.asarray(im).copy()
                al = a[..., 3]
                al[al < 24] = 0
                ys2, xs2 = np.nonzero(al)
                x0, x1, y0, y1 = xs2.min(), xs2.max() + 1, ys2.min(), ys2.max() + 1
                crop = Image.fromarray(a, "RGBA").crop((x0, y0, x1, y1))
                fn = f"{name}_{n:02d}.webp"
                crop.save(os.path.join(out, fn), quality=82, method=6)
                with open(os.path.join(out, fn + ".import"), "w") as g:
                    g.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\n'
                            f'source_file="res://art/enemy_anim/{kind}/{fn}"\n\n[params]\n\n'
                            'compress/mode=1\ncompress/lossy_quality=0.85\nmipmaps/generate=false\n')
                paths.append(f'"res://art/enemy_anim/{kind}/{fn}"')
                offs.append(f"Vector2({x0 - ax:.1f}, {y0 - ay:.1f})")
            lines.append(f'\t\t"{name}": {{"loop": {str(loop).lower()}, "impact": {impact},')
            lines.append(f'\t\t\t"frames": [{", ".join(paths)}],')
            lines.append(f'\t\t\t"offsets": [{", ".join(offs)}]}},')
        lines.append("\t}},")
    lines.append("}")
    lines.append("")
    open(os.path.join(root, "scripts/enemy_anims.gd"), "w").write("\n".join(lines))
    print("hotovo")


if __name__ == "__main__":
    main(sys.argv[1])
