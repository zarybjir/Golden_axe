"""Rozřeže list dílů (postava rozkreslená na bílém pozadí) na samostatné PNG s průhledností.

Použití:  python3 tools/cut_parts.py vstup.png vystupni_slozka
Vypíše nalezené díly (index, obdélník, plocha) a uloží je jako part_<i>.png.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def main(src, out_dir):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    whiteish = (a.min(axis=2) > 228) & ((a.max(axis=2) - a.min(axis=2)) < 22)
    lab, n = ndimage.label(whiteish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    fg = ~bg
    fg = ndimage.binary_opening(fg, iterations=1)
    fg = ndimage.binary_fill_holes(fg)
    # Měkký okraj: 1 px dovnitř poloprůhledně, aby nebyl vidět bílý lem.
    inner = ndimage.binary_erosion(fg, iterations=1)
    alpha = np.where(inner, 255, np.where(fg, 110, 0)).astype(np.uint8)
    groups, m = ndimage.label(ndimage.binary_dilation(fg, iterations=5))
    rgba = np.dstack([np.asarray(im), alpha])
    parts = []
    for i in range(1, m + 1):
        mask = (groups == i) & fg
        area = int(mask.sum())
        if area < 400:
            continue
        ys, xs = np.nonzero(mask)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        crop = rgba[y0:y1, x0:x1].copy()
        crop[..., 3] = np.where(mask[y0:y1, x0:x1], crop[..., 3], 0)
        parts.append(((x0, y0, x1, y1), area, crop))
    for k, (box, area, crop) in enumerate(parts):
        Image.fromarray(crop, "RGBA").save(f"{out_dir}/part_{k}.png")
        print(k, box, area)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
