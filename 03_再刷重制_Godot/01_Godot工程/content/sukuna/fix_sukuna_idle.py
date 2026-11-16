"""T123: preserve first pose head/hands/feet; move only interior chest pixels 1px."""
import argparse
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args()
src=Image.open(a.source).convert('RGBA')
assert src.size==(576,384)
base=src.crop((0,0,64,64))
assert base.getbbox()==(10,3,49,61)
out=src.copy()
for i in range(3):
    frame=base.copy()
    if i==1:
        # An interior chest/abdomen tile: no outline, arms, head, or trousers.
        # Translate its rows upward one pixel, keeping the original bottom row.
        for y in range(39,44):
            for x in range(24,31):
                frame.putpixel((x,y),base.getpixel((x,y+1)))
    assert frame.getbbox()==base.getbbox()
    out.paste(frame,(i*64,0))
assert out.crop((0,64,576,384)).tobytes()==src.crop((0,64,576,384)).tobytes()
assert out.crop((192,0,576,64)).tobytes()==src.crop((192,0,576,64)).tobytes()
assert set(out.getdata())<=set(src.getdata())
assert set(out.getchannel('A').getdata())=={0,255}
# Invariants across all three new frames, including literal RGBA pixels.
for i in (1,2):
    f=out.crop((i*64,0,i*64+64,64))
    for y in range(64):
        for x in range(64):
            if not (i==1 and 24<=x<31 and 39<=y<44):
                assert f.getpixel((x,y))==base.getpixel((x,y))
a.output.parent.mkdir(parents=True,exist_ok=True)
out.save(a.output)
print('PASS: frame0 base, all bounds (10,3,49,61), sole y60, head/hands/feet fixed; other51 cells exact; binary alpha and original palette')
