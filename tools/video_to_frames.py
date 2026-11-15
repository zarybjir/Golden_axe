"""Video ze Scenaria -> snímky bez pozadí.

Použití:  python3 tools/video_to_frames.py video.mp4 vystupni_slozka [fps]
Potřebuje ffmpeg a balíček rembg (pip install "rembg[cpu]").
Výsledné snímky r_001.png ... mají průhledné pozadí.
"""
import glob
import os
import subprocess
import sys

from PIL import Image
from rembg import new_session, remove


def main(video, out_dir, fps="12"):
    raw = os.path.join(out_dir, "raw")
    cut = os.path.join(out_dir, "cut")
    os.makedirs(raw, exist_ok=True)
    os.makedirs(cut, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, "-vf", f"fps={fps},scale=1280:-2",
                    os.path.join(raw, "r_%03d.png")], check=True)
    session = new_session("isnet-general-use")
    for f in sorted(glob.glob(os.path.join(raw, "r_*.png"))):
        out = os.path.join(cut, os.path.basename(f))
        if not os.path.exists(out):
            remove(Image.open(f), session=session).save(out)


if __name__ == "__main__":
    main(*sys.argv[1:])
