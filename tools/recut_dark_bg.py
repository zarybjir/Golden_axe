"""Pro videa s černým pozadím: doplní do masky z rembg kov sekery a bílé stopy úderů.
Spouští se ve složce videa (raw/, cut/ -> cut2/):  python3 recut_dark_bg.py od do
"""
import sys, numpy as np
from PIL import Image
from scipy import ndimage
# Doplní do masky z rembg světlé šedé/bílé části (kov sekery, stopy úderu) na černém pozadí.
for i in range(int(sys.argv[1]), int(sys.argv[2])+1):
    raw=np.asarray(Image.open(f'raw/r_{i+1:03d}.png').convert('RGB')).astype(float)
    cut=np.asarray(Image.open(f'cut/r_{i+1:03d}.png').convert('RGBA'))
    mx=raw.max(axis=2); mn=raw.min(axis=2)
    sat=(mx-mn)/np.maximum(mx,1)
    metal=(mx>70)&(sat<0.28)
    a_extra=np.clip((mx-55)*2.2,0,255)*metal
    # násada: hnědá v okolí kovu
    near=ndimage.binary_dilation(metal|(cut[...,3]>128),iterations=3)
    brown=(raw[...,0]>60)&(raw[...,0]>raw[...,2]*1.3)&(sat>0.3)&(sat<0.75)&(mx<200)&near&(raw[...,1]<raw[...,0]*0.8)
    a=np.maximum(cut[...,3].astype(float),a_extra)
    a=np.maximum(a, brown*0)  # násada zůstává z rembg
    rgb=raw.copy()
    out=np.dstack([rgb,a]).astype(np.uint8)
    # odstranit drobný šum
    lab,n=ndimage.label(a>40); sizes=ndimage.sum(a>40,lab,range(n+1)); small=np.isin(lab,np.nonzero(sizes<60)[0])
    out[...,3][small]=0
    Image.fromarray(out,'RGBA').save(f'cut2/r_{i+1:03d}.png')
