"""Animace liche z videí (stejný postup jako tools/build_zombie_anims.py).

Použití:  python3 tools/build_lich_anims.py SLOZKA
Výstup: art/enemy_anim/lich/*.webp a scripts/lich_anims.gd.
Ve videu kouzlení vylétá z hole bílý blesk (snímky 29–37) – ty se vynechají,
zelenou střelu kreslí hra sama.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_zombie_anims import main  # noqa: E402

ANIMS = {
    "walk": ("walk", list(range(0, 30)), True, -1),
    "cast": ("cast", list(range(0, 29)) + list(range(38, 60)), False, 28),
}

if __name__ == "__main__":
    main(sys.argv[1], ANIMS, "lich", 104.0)
