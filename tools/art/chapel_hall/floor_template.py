"""Floor layout: six by six 2 m slabs, two red processional lanes along the tile."""
import sys
from PIL import Image, ImageDraw
out = sys.argv[1]
size, slab = 1254, 1254 / 6
ochre, charcoal, red = (176, 142, 92), (66, 62, 58), (122, 36, 28)
im = Image.new('RGB', (size, size))
d = ImageDraw.Draw(im)
for row in range(6):
    for col in range(6):
        if col in (1, 4):
            c = red
        else:
            c = ochre if (row + col) % 2 == 0 else charcoal
        d.rectangle([col * slab, row * slab, (col + 1) * slab - 1, (row + 1) * slab - 1], fill=c)
        d.rectangle([col * slab, row * slab, (col + 1) * slab - 1, (row + 1) * slab - 1], outline=(26, 20, 16), width=9)
im.save(out)
