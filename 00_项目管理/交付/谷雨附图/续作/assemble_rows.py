"""Split alpha column spans, reject count mismatch, align bbox to template.
Partial preview only; never publishes incomplete sheet to content.
Run with Python+Pillow from any working directory.
"""
from pathlib import Path
import json
from PIL import Image
P=Path(__file__).resolve().parent
ROOT=P.parents[3]
T=P.parent/'旧样板/template_battle.png'
ref=Image.open(T).convert('RGBA')
records=[]
for row in range(6):
 path=P/f'raw_row{row}.png'
 if not path.exists(): continue
 im=Image.open(path).convert('RGBA')
 im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
 spans=[];start=None
 for x in range(im.width+1):
  active=x<im.width and im.getchannel('A').crop((x,0,x+1,im.height)).getbbox() is not None
  if active and start is None: start=x
  if not active and start is not None: spans.append((start,x));start=None
 # Ignore isolated horizontal noise only; preserve every character pixel.
 spans=[(a,b) for a,b in spans if b-a>=20]
 if len(spans)!=9: raise ValueError(f'row{row}: expected 9 separate silhouettes, got {spans}')
 out=Image.new('RGBA',(576,64))
 for col,(a,b) in enumerate(spans):
  c=im.crop((a,0,b,im.height)); c=c.crop(c.getbbox())
  rb=ref.crop((col*64,row*64,col*64+64,row*64+64)).getbbox()
  h=rb[3]-rb[1];w=round(c.width*h/c.height)
  if w>62: raise ValueError(f'row{row} col{col}: width {w}')
  c=c.resize((w,h),Image.Resampling.NEAREST)
  x=round((rb[0]+rb[2]-w)/2);y=rb[3]-h
  out.paste(c,(col*64+x,y))
  records.append(dict(row=row,col=col,source_span=[a,b],template_bbox=rb,output_bbox=[x,y,x+w,y+h]))
 alpha=out.getchannel('A');out=out.convert('RGB').quantize(colors=32,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(alpha)
 out.save(P/f'preview_row{row}.png')
 out.resize((1728,192),Image.Resampling.NEAREST).save(P/f'preview_row{row}_3x.png')
(P/'alignment_partial.json').write_text(json.dumps(records,indent=2))
print(f'partial preview: {len(records)} cells, not a complete battle sheet')
