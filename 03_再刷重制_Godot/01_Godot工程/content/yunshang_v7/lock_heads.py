"""Kyo round5: reuse one head per direction; mirror the standard side face.
Explicit requested sprite compositing, no eye repainting or threshold changes.
"""
from PIL import Image,ImageOps
from pathlib import Path
import json
P=Path(__file__).resolve().parent
w=Image.open(P/'Yunshang_Walk.png').convert('RGBA')
a=json.loads((P/'alignment.json').read_text())
for row,n in [(0,'down'),(1,'left')]:
    mid=next(r for r in a['frames'] if r['direction']==n and r['frame']==1)
    cut=mid['output_landmarks']['neck_y']+1
    head=w.crop((48,row*48,96,row*48+cut))
    for col in range(3):
        w.paste((0,0,0,0),(col*48,row*48,(col+1)*48,row*48+cut))
        w.paste(head,(col*48,row*48))
# Right-side anatomy and eyes are exact mirrored LEFT pixels.
for col in range(3):
    c=w.crop((col*48,48,(col+1)*48,96))
    w.paste(ImageOps.mirror(c),(col*48,96))
# Ornament comes solely from the allowed portrait; separate alpha layer.
portrait=Image.open(P.parent/'yunshang_v2/Yunshang_Face_u1.png').convert('RGBA')
orn=portrait.crop((92,10,130,72))
pixels=[]
for r,g,b,alpha in orn.getdata():
    gold=r>g> b and r-b>30
    navy=b>r and b>g and max(r,g,b)<135
    pixels.append((r,g,b,alpha if gold or navy else 0))
orn.putdata(pixels);orn=orn.resize((6,10),Image.Resampling.NEAREST)
# Anatomical left hairpin: visible on right-facing view; far-side pin tip on left.
for col in range(3):
    w.alpha_composite(orn,(col*48+10,98))
    tip=orn.crop((0,0,6,3));w.alpha_composite(tip,(col*48+28,50))
# Map overlay back into the SAME existing shared palette; no new per-frame palette.
colors=json.loads((P/'palette.json').read_text())['colors'];entries=[]
for color in colors:entries.extend(bytes.fromhex(color[1:]))
pal=Image.new('P',(1,1));pal.putpalette(entries+entries[:3]*(256-len(colors)))
alpha=w.getchannel('A').point(lambda v:255 if v>=128 else 0)
w=w.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');w.putalpha(alpha)
w.save(P/'Yunshang_Walk.png')
(P/'head_policy.json').write_text(json.dumps({'standard_head':'middle frame per down/left direction copied verbatim across 3 frames','right':'exact mirrored left body and face, then separate portrait ornament layer','up_wait':'round4 pixels retained; no visible rear face','warning':'alignment.json records pre-composite source fitting; final head copies/mirroring are explicitly recorded here'},indent=2))
