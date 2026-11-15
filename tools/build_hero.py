"""Z listu dílů hrdiny (art/source/hero_parts_sheet.png) vyrobí díly loutky
do art/hero/*.png a soubor scripts/hero_rig.gd s klouby (body otáčení).

Spuštění:  python3 tools/build_hero.py
Souřadnice kloubů níže jsou v pixelech vyříznutého dílu (po otočení do základní polohy:
končetiny visí dolů, kladivo míří nahoru).
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import cut_parts  # noqa: E402

SCALE = 0.35          # zmenšení dílů (ostré i na 1920×1200)
HERO_HEIGHT = 88.0    # výška hrdiny ve hře (logické pixely)

# index dílu z cut_parts -> (název, otočení ve stupních)
PARTS = {0: ("head", 0), 1: ("torso", 0), 2: ("uarm", 0), 3: ("farm", -90),
         4: ("hammer", 90), 5: ("shin", 0), 6: ("thigh", 0)}

# Klouby (v pixelech dílu před zmenšením)
J = {
    "head_pivot": (100, 232),
    "torso_pivot": (185, 430),
    "neck": (210, 22),
    "shoulder_f": (88, 95),
    "shoulder_b": (225, 85),
    "hip_f": (215, 430),
    "hip_b": (160, 430),
    "uarm_pivot": (98, 35), "uarm_end": (75, 188),
    "farm_pivot": (61, 25), "farm_end": (62, 222),
    "thigh_pivot": (126, 40), "thigh_end": (73, 225),
    "shin_pivot": (87, 35), "shin_end": (100, 345),
    "hammer_grip": (226, 700),
}


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    tmp = "/tmp/hero_parts"
    os.makedirs(tmp, exist_ok=True)
    cut_parts.main(os.path.join(root, "art/source/hero_parts_sheet.png"), tmp)
    out_dir = os.path.join(root, "art/hero")
    os.makedirs(out_dir, exist_ok=True)
    for idx, (name, rot) in PARTS.items():
        im = Image.open(f"{tmp}/part_{idx}.png")
        if rot:
            im = im.rotate(rot, expand=True)
        w, h = im.size
        im = im.resize((max(1, round(w * SCALE)), max(1, round(h * SCALE))), Image.LANCZOS)
        im.save(os.path.join(out_dir, f"{name}.png"))

    s = lambda k: (J[k][0] * SCALE, J[k][1] * SCALE)  # noqa: E731

    def rel(a, b):
        return (s(a)[0] - s(b)[0], s(a)[1] - s(b)[1])

    def ang0(p, e):
        dx, dy = s(e)[0] - s(p)[0], s(e)[1] - s(p)[1]
        return math.atan2(-dx, dy), math.hypot(dx, dy)

    a_uarm, _ = ang0("uarm_pivot", "uarm_end")
    a_farm, _ = ang0("farm_pivot", "farm_end")
    a_thigh, l_thigh = ang0("thigh_pivot", "thigh_end")
    a_shin, l_shin = ang0("shin_pivot", "shin_end")
    leg_len = l_thigh + l_shin
    neck = rel("neck", "torso_pivot")
    total = leg_len - neck[1] + s("head_pivot")[1]
    k = HERO_HEIGHT / total

    v = lambda t: f"Vector2({t[0]:.1f}, {t[1]:.1f})"  # noqa: E731
    lines = [
        "extends RefCounted",
        "## VYGENEROVÁNO skriptem tools/build_hero.py – neupravovat ručně.",
        "## Loutka hrdiny: díly, body otáčení a délky končetin (v pixelech textur).",
        "",
        f"const K := {k:.4f}  # logické pixely hry na 1 pixel textury",
        f"const LEG_LEN := {leg_len:.1f}",
        f"const TORSO_PIVOT := {v(s('torso_pivot'))}",
        f"const NECK := {v(neck)}",
        f"const SHOULDER_F := {v(rel('shoulder_f', 'torso_pivot'))}",
        f"const SHOULDER_B := {v(rel('shoulder_b', 'torso_pivot'))}",
        f"const HIP_F := {v(rel('hip_f', 'torso_pivot'))}",
        f"const HIP_B := {v(rel('hip_b', 'torso_pivot'))}",
        f"const HEAD_PIVOT := {v(s('head_pivot'))}",
        f"const UARM_PIVOT := {v(s('uarm_pivot'))}",
        f"const UARM_END := {v(rel('uarm_end', 'uarm_pivot'))}",
        f"const UARM_A0 := {a_uarm:.4f}",
        f"const FARM_PIVOT := {v(s('farm_pivot'))}",
        f"const FARM_END := {v(rel('farm_end', 'farm_pivot'))}",
        f"const FARM_A0 := {a_farm:.4f}",
        f"const THIGH_PIVOT := {v(s('thigh_pivot'))}",
        f"const THIGH_END := {v(rel('thigh_end', 'thigh_pivot'))}",
        f"const THIGH_A0 := {a_thigh:.4f}",
        f"const SHIN_PIVOT := {v(s('shin_pivot'))}",
        f"const SHIN_END := {v(rel('shin_end', 'shin_pivot'))}",
        f"const SHIN_A0 := {a_shin:.4f}",
        f"const HAMMER_GRIP := {v(s('hammer_grip'))}",
        "",
    ]
    with open(os.path.join(root, "scripts/hero_rig.gd"), "w") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
