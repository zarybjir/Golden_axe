"""Animace démonického kamzíka z videí (stejný postup jako tools/build_zombie_anims.py).

Použití:  python3 tools/build_chamois_anims.py SLOZKA
Výstup: art/enemy_anim/chamois/*.webp a scripts/chamois_anims.gd.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_zombie_anims import main  # noqa: E402

# video "atk": vzepětí (3–21), náraz se skloněnými rohy (24–39), návrat do postoje (40–51)
ANIMS = {
    "walk": ("run", [0] + list(range(9, 60)), True, -1),
    "rear": ("atk", list(range(3, 22)), False, -1),
    "ram": ("atk", list(range(24, 40)), False, -1),
    "back": ("atk", list(range(40, 52)), False, -1),
}

if __name__ == "__main__":
    main(sys.argv[1], ANIMS, "chamois", 76.0)
