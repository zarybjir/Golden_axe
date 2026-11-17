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
    "throw": ("throw", [i for i in range(0, 60) if i not in (29, 30, 31)], False, 52),
}

if __name__ == "__main__":
    main(sys.argv[1], ANIMS, "golem", 150.0)
