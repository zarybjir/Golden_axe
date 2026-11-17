"""Animace kamenného obra z videí (stejný postup jako tools/build_zombie_anims.py).

Použití:  python3 tools/build_golem_anims.py SLOZKA
Výstup: art/enemy_anim/golem/*.webp a scripts/golem_anims.gd.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_zombie_anims import main  # noqa: E402

# animace: (video, snímky, smyčka, snímek úderu / odhození balvanu)
# Ve videu hodu jsou snímky 30–32 vadné (chybí spodní půlka těla).
ANIMS = {
    "walk": ("walk", list(range(0, 26)), True, -1),
    "punch": ("punch", list(range(4, 58)), False, 30),
    "throw": ("throw", [i for i in range(0, 60) if i not in (29, 30, 31)], False, 50),
}

def strip_boulder():
    """Po odhození (od snímku úderu dál) nechá jen obra – balvan z videa se smaže,
    ve hře letí vlastní balvan."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    vid, frames, loop, impact = ANIMS["throw"]
    for n in range(impact, len(frames)):
        path = os.path.join(root, f"art/enemy_anim/golem/throw_{n:02d}.webp")
        im = Image.open(path).convert("RGBA")
        a = np.asarray(im).copy()
        fg = a[..., 3] > 120
        lab, k = ndimage.label(ndimage.binary_dilation(fg, iterations=1))
        if k < 2:
            continue
        sizes = ndimage.sum(fg, lab, range(k + 1))
        keep = ndimage.binary_dilation(lab == int(np.argmax(sizes[1:])) + 1, iterations=2)
        a[..., 3] = np.where(keep, a[..., 3], 0)
        Image.fromarray(a, "RGBA").save(path, quality=82, method=6)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1], ANIMS, "golem", 150.0)
    strip_boulder()
