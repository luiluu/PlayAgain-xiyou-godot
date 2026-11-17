"""Align only fresh Guyu-template Tusu generations; never reads Yunxiao assets."""
from pathlib import Path
from collections import deque
from PIL import Image
import json
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
REF=ROOT/'03_再刷重制_Godot/01_Godot工程/content/guyu_v2'
def rgba(p):
 im=Image.open(p).convert('RGBA');im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0));return im
def subjects(im,count):
 # Prefer full alpha-column spans (preserves every generated pixel).
 spans=[];start=None
 for x in range(im.width+1):
  active=x<im.width and im.getchannel('A').crop((x,0,x+1,im.height)).getbbox() is not None
  if active and start is None:start=x
  if not active and start is not None:spans.append((start,x));start=None
 spans=[(a,b) for a,b in spans if b-a>20]
 if len(spans)==count:
  return [im.crop((a,0,b,im.height)).crop(im.crop((a,0,b,im.height)).getbbox()) for a,b in spans]
 # Long arms can overlap x projections without touching in 2D.
 a=bytearray(im.getchannel('A').tobytes());w,h=im.size;components=[]
 for i in range(len(a)):
  if not a[i]:continue
  a[i]=0;q=deque([i]);pts=[]
  while q:
   j=q.pop();x=j%w;y=j//w;pts.append((x,y))
   for k in ([j-1] if x else [])+([j+1] if x<w-1 else [])+([j-w] if y else [])+([j+w] if y<h-1 else []):
    if a[k]:a[k]=0;q.append(k)
  if len(pts)>500:components.append(pts)
 assert len(components)==count,[len(c) for c in components]
 components.sort(key=lambda c:min(x for x,y in c));out=[]
 for pts in components:
  xs=[x for x,y in pts];ys=[y for x,y in pts];x0=min(xs);y0=min(ys)
  q=Image.new('RGBA',(max(xs)-x0+1,max(ys)-y0+1));qp=q.load();ip=im.load()
  for x,y in pts:qp[x-x0,y-y0]=ip[x,y]
  out.append(q)
 return out
records=[];ref=rgba(REF/'Guyu_SV_v2.png');sheet=Image.new('RGBA',(576,384));rows=[]
for row in range(6):
 path=P/f'raw_tusu_guyu_row{row}.png'
 if not path.exists():continue
 out=Image.new('RGBA',(576,64))
 for c,q in enumerate(subjects(rgba(path),9)):
  bb=ref.crop((c*64,row*64,c*64+64,row*64+64)).getbbox();h=bb[3]-bb[1];w=round(q.width*h/q.height)
  assert w<=62,(row,c,w)
  q=q.resize((w,h),Image.Resampling.NEAREST);x=round((bb[0]+bb[2]-w)/2);y=bb[3]-h
  assert x>=0 and x+w<=64,(row,c,x,w)
  out.paste(q,(c*64+x,y),q);records.append(dict(row=row,col=c,reference=list(bb),output=[x,y,x+w,y+h]))
 out.save(P/f'tusu_guyu_row{row}_64.png');sheet.paste(out,(0,row*64));rows.append(row)
if len(rows)==6:sheet.save(P/'Tusu_Battle_candidate.png')
walkpath=P/'raw_tusu_guyu_walk.png'
if walkpath.exists():
 raw=rgba(walkpath);rw=rgba(REF/'$Guyu_v2.png');out=Image.new('RGBA',(144,192))
 for r in range(4):
  strip=raw.crop((0,round(r*raw.height/4),raw.width,round((r+1)*raw.height/4)))
  for c,q in enumerate(subjects(strip,3)):
   bb=rw.crop((c*48,r*48,c*48+48,r*48+48)).getbbox();h=bb[3]-bb[1];w=round(q.width*h/q.height)
   assert w<=46,(r,c,w)
   q=q.resize((w,h),Image.Resampling.NEAREST);x=round((bb[0]+bb[2]-w)/2);y=bb[3]-h
   assert x>=0 and x+w<=48,(r,c,x,w)
   out.paste(q,(c*48+x,r*48+y),q);records.append(dict(direction=r,col=c,reference=list(bb),output=[x,y,x+w,y+h]))
 out.save(P/'Tusu_Walk_candidate.png')
(P/'tusu_guyu_alignment.json').write_text(json.dumps(records,indent=2))
print('battle rows:',rows,'walk:',walkpath.exists(),'aligned cells:',len(records))
