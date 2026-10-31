"""Generated paintings to game images: key colour to alpha, banner cloth cropped
to its image, transparent texels filled so mip levels keep no key colour.

    python prepare.py <paintings dir> <game/assets/art/chapel-hall>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

SOURCE, TARGET = sys.argv[1], sys.argv[2]
os.makedirs(TARGET, exist_ok=True)
# name in the game, painting, keyed
PAINTINGS = [
    ('bay-a', 'bay', False),
    ('bay-b', 'bay_b', False),
    ('bay-c', 'bay_c', False),
    ('door-wall', 'door_wall', True),
    ('strip', 'strip', False),
    ('south', 'south', False),
    ('chancel', 'chancel', True),
    ('apse-side', 'apse_side', True),
    ('rear', 'rear', True),
    ('far-ruins', 'far_ruins', True),
    ('banner-a', 'banner', True),
    ('banner-b', 'banner_b', True),
    ('floor', 'floor', False),
    ('drum', 'column', False),
    ('ashlar', 'ashlar', False),
    ('iron', 'iron', False),
    ('rubble', 'rubble', False),
    ('sanctuary', 'sanctuary', False),
    ('crypt', 'crypt', False),
    ('narthex', 'narthex', False),
    ('ceiling', 'ceiling', False),
    ('tomb', 'tomb', False),
    ('clay', 'clay', False),
    ('wood', 'wood', False),
    ('zenith', 'zenith', False),
    ('inferno-sky', 'inferno_sky', False),
    ('storm-a', 'storm_a', False),
    ('storm-b', 'storm_b', False),
    ('storm-c', 'storm_c', False),
    ('nave-a', 'nave_a', False),
    ('nave-b', 'nave_b', False),
    ('nave-c', 'nave_c', False),
    ('nave-door', 'nave_door', True),
    ('nave-end', 'nave_end', True),
    ('nave-chancel', 'nave_chancel', True),
    ('nave-south', 'nave_south', True),
]


def key_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mask = (r - g > 70) & (b - g > 60) & (r > 120) & (b > 110)
    grown = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return np.asarray(grown) > 127


def fill(rgb, keep):
    """Colour of the transparent texels: the nearby painted colour."""
    weight = Image.fromarray((keep * 255).astype(np.uint8))
    total = np.asarray(weight.filter(ImageFilter.GaussianBlur(28))).astype(np.float32) + 1e-3
    out = rgb.astype(np.float32).copy()
    for c in range(3):
        channel = (rgb[..., c].astype(np.float32) * keep).clip(0, 255).astype(np.uint8)
        blurred = np.asarray(Image.fromarray(channel).filter(ImageFilter.GaussianBlur(28)))
        out[..., c][~keep] = (blurred.astype(np.float32) / total * 255).clip(0, 255)[~keep]
    return out.astype(np.uint8)


for name, painting, keyed in PAINTINGS:
    a = np.asarray(Image.open(os.path.join(SOURCE, painting + '.png')).convert('RGB'))
    alpha = np.full(a.shape[:2], 255, np.uint8)
    if keyed:
        mask = key_mask(a)
        alpha[mask] = 0
        a = fill(a, ~mask)
    rgba = np.dstack([a, alpha])
    if name.startswith('banner'):
        ys, xs = np.nonzero(alpha)
        rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    out = Image.fromarray(rgba, 'RGBA')
    if keyed:
        out.save(os.path.join(TARGET, name + '.png'), compress_level=9)
    else:
        out.convert('RGB').save(os.path.join(TARGET, name + '.jpg'), quality=94, subsampling=0)
    print(name, out.size)
