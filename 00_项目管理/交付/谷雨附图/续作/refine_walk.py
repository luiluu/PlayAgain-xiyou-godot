"""Align the generated twelve poses independently; never copy/mirror frames."""
from pathlib import Path
from PIL import Image
import json
P=Path(__file__).resolve().parent
R=P.parent/'旧样板'
def spans(mask,axis,minimum):
 vals=[]; start=None
 for n in range(mask.size[axis]+1):
  box=(n,0,n+1,mask.height) if axis==0 else (0,n,mask.width,n+1)
  on=n<mask.size[axis] and mask.crop(box).getbbox() is not None
  if on and start is None:start=n
  if not on and start is not None:
   if n-start>=minimum:vals.append((start,n))
   start=None
 return vals
im=Image.open(P/'raw_walk_refine.png').convert('RGBA')
im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
ys=spans(im.getchannel('A'),1,20)
assert len(ys)==4,ys
ref=Image.open(R/'template_walk.png').convert('RGBA')
out=Image.new('RGBA',(144,192)); records=[]
for row,(a,b) in enumerate(ys):
 band=im.crop((0,a,im.width,b)); xs=spans(band.getchannel('A'),0,20)
 assert len(xs)==3,(row,xs)
 for col,(x0,x1) in enumerate(xs):
  c=band.crop((x0,0,x1,band.height)); c=c.crop(c.getbbox())
  rb=ref.crop((col*48,row*48,col*48+48,row*48+48)).getbbox()
  h=rb[3]-rb[1];w=round(c.width*h/c.height)
  assert w<=48,(row,col,w)
  c=c.resize((w,h),Image.Resampling.NEAREST)
  x=round((rb[0]+rb[2]-w)/2);y=rb[3]-h
  out.paste(c,(col*48+x,row*48+y));records.append(dict(row=row,col=col,bbox=[x,y,x+w,y+h]))
a=out.getchannel('A');out=out.convert('RGB').quantize(colors=32,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(a)
out.save(P/'Guyu_Walk_refined.png')
out.resize((432,576),Image.Resampling.NEAREST).save(P/'Guyu_Walk_refined_3x.png')
(P/'walk_refine_alignment.json').write_text(json.dumps(records,indent=2))
print('aligned 12 independently generated walking frames')
