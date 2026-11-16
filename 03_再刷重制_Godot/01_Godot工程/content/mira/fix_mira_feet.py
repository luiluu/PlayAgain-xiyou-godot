"""T122 deterministic boot-only patch. Requires Pillow; --source must be pre-T122 PNG."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
src = Image.open(a.source).convert('RGBA')
assert src.size == (576, 384)
out = src.copy()
# Use one existing planted stance consistently across the three breathing frames.
# Only warm brown boot pixels are transferred; cloak, belt, tail stay original.
def boot(c):
    r, g, b, alpha = c
    return alpha == 255 and r > g > b and g >= r * .48 and b < g * .86

for frame in range(3):
    x0 = frame * 64
    for y in range(51, 61):
        for x in range(17, 36):
            xy = (x0 + x, y)
            if boot(src.getpixel(xy)) or (y == 60 and 24 <= x <= 28):
                out.putpixel(xy, (0, 0, 0, 0))
            donor = src.getpixel((x, 64 + y))
            if boot(donor):
                out.putpixel(xy, donor)
    before = src.crop((x0, 0, x0 + 64, 64))
    after = out.crop((x0, 0, x0 + 64, 64))
    assert before.getbbox() == after.getbbox(), (frame, before.getbbox(), after.getbbox())
assert set(out.getdata()) <= set(src.getdata()), 'palette expanded'
assert set(out.getchannel('A').getdata()) == {0, 255}
a.output.parent.mkdir(parents=True, exist_ok=True)
out.save(a.output)
print('PASS: 576x384, unchanged frame bounds/sole, binary alpha, original palette')
