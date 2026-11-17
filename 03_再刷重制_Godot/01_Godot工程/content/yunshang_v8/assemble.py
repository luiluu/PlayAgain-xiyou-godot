"""Round6: only NEW raw sprites, allowed Guyu reference images.
Uniform whole-person resize; one global48 palette. No old Yunshang pixels/marks.
"""
from pathlib import Path
from PIL import Image,ImageOps
import json
P=Path(__file__).resolve().parent
walk=Image.new('RGBA',(144,192));idle=Image.new('RGBA',(192,64));records=[]
g=Image.open(P/'Guyu_Walk.png').convert('RGBA');b=Image.open(P/'Guyu_Battle.png').convert('RGBA')
# Guyu alone supplies frame bounds and feet anchors.
for row,n in [(0,'down'),(1,'left'),(3,'up'),(4,'wait')]:
 raw=Image.open(P/f'raw_{n}.png').convert('RGBA')
 raw.putalpha(raw.getchannel('A').point(lambda v:255 if v>=128 else 0))
 size=48 if row<4 else 64
 for j in range(3):
  unit=raw.width//3;c=raw.crop((j*unit,0,(j+1)*unit,raw.height));bb=c.getbbox();c=c.crop(bb)
  ref=(g.crop((j*48,row*48,j*48+48,row*48+48)) if row<4 else b.crop((j*64,64,j*64+64,128))).getbbox()
  anchor=ref
  # Tiny bun is separate from Guyu's normal crown-to-foot height.
  h=min(ref[3]-ref[1]+3,anchor[3]);scale=h/c.height;w=round(c.width*scale)
  if w>size-2:raise ValueError(('too wide',n,j,w))
  c=c.resize((w,h),Image.Resampling.NEAREST);x=round((anchor[0]+anchor[2]-w)/2);y=anchor[3]-h
  cell=Image.new('RGBA',(size,size));cell.paste(c,(x,y))
  if row<4:walk.paste(cell,(j*48,row*48))
  else:idle.paste(cell,(j*64,0))
  records.append(dict(direction=n,frame=j,source_bbox=[j*unit+bb[0],bb[1],j*unit+bb[2],bb[3]],uniform_scale=scale,output_bbox=cell.getbbox()))
# Explicitly authorized: this round's new left-facing base mirrored into right.
for j in range(3):walk.paste(ImageOps.mirror(walk.crop((j*48,48,j*48+48,96))),(j*48,96))
# Whole 15-frame batch learns one shared palette, never per-frame quantization.
pixels=[v[:3] for im in [walk,idle] for v in im.getdata() if v[3]]
sample=Image.new('RGB',(len(pixels),1));sample.putdata(pixels)
entries=sample.quantize(colors=48,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).getpalette()[:144]
pal=Image.new('P',(1,1));pal.putpalette(entries+entries[:3]*208)
for im,name in [(walk,'Yunshang_Walk.png'),(idle,'Yunshang_Wait.png')]:
 alpha=im.getchannel('A');im=im.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(alpha);im.save(P/name)
(P/'assembly.json').write_text(json.dumps(records,indent=2))
(P/'palette.json').write_text(json.dumps({'colors':['#'+bytes(entries[i:i+3]).hex() for i in range(0,144,3)]},indent=2))
