"""T160: approved walk immutable; new frames x0.09; approved wait raw x0.072.
No head replacement, local stretch or frame-specific fitting. Safe transparent cuts
keep thrust's extended hand intact. Nearest palette mapping shares approved v8.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json, shutil, hashlib
ROOT=Path(__file__).resolve().parents[5]
P=Path(__file__).resolve().parent
C=ROOT/'03_再刷重制_Godot/01_Godot工程/content'
V=C/'yunshang_v8'; OUT=C/'yunshang_v9'
OUT.mkdir(exist_ok=True)
SCALE=.09
motions=json.loads((P/'motions.json').read_text())
ref=Image.open(C/'guyu_v2/Guyu_SV_v2.png').convert('RGBA')
WAIT_SCALE=.072  # coordinator: match new action head size, no local/head fitting
palette=json.loads((V/'palette.json').read_text())['colors']
pal=Image.new('P',(1,1));rgb=[tuple(bytes.fromhex(x[1:])) for x in palette];flat=[v for c in rgb for v in c];pal.putpalette(flat+flat[:3]*(256-len(rgb)))
sheet=Image.new('RGBA',(576,384));review=Image.new('RGB',(256,18*80),(43,46,55));draw=ImageDraw.Draw(review);records=[]
for i,m in enumerate(motions):
 raw=Image.open(V/'raw_wait.png' if m=='wait' else P/f'raw_{m}.png').convert('RGBA');raw.putalpha(raw.getchannel('A').point(lambda a:255 if a>=128 else 0))
 empty=[x for x in range(raw.width) if not raw.getchannel('A').crop((x,0,x+1,raw.height)).getbbox()]
 cuts=[0]+[min(empty,key=lambda x:abs(x-raw.width*j/3)) for j in (1,2)]+[raw.width]
 for j in range(3):
  target=((i//6)*192+j*64,(i%6)*64)
  part=raw.crop((cuts[j],0,cuts[j+1],raw.height));bb=part.getbbox();part=part.crop(bb)
  scale=WAIT_SCALE if m=='wait' else SCALE
  size=(round(part.width*scale),round(part.height*scale));part=part.resize(size,Image.Resampling.NEAREST)
  alpha=part.getchannel('A');part=part.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');part.putalpha(alpha)
  anchor=ref.crop((target[0],target[1],target[0]+64,target[1]+64)).getbbox()
  x=round((anchor[0]+anchor[2]-size[0])/2);y=anchor[3]-size[1]
  # Translation only, keep whole silhouette inside cell when bun exceeds reference.
  x=max(0,min(64-size[0],x));y=max(0,min(64-size[1],y))
  assert size[0]<=64 and size[1]<=64,(m,j,size)
  cell=Image.new('RGBA',(64,64));cell.paste(part,(x,y))
  record={'motion':m,'frame':j,'source_bbox':[cuts[j]+bb[0],bb[1],cuts[j]+bb[2],bb[3]],'scale':scale,'translation':[x,y],'reference_bbox':anchor,'output_bbox':cell.getbbox()}
  sheet.paste(cell,target);review.paste(cell,(64+j*64,i*80+16),cell);records.append(record)
 draw.text((2,i*80+34),m,fill='white')
sheet.save(OUT/'Yunshang_SV_v9.png');shutil.copyfile(V/'Yunshang_Walk.png',OUT/'$Yunshang_v9.png')
review.save(P/'assembled_native.png');review.resize((768,4320),Image.Resampling.NEAREST).save(P/'assembled_3x.png')
(P/'assembly.json').write_text(json.dumps({'scale':SCALE,'wait_scale':WAIT_SCALE,'wait_reason':'Approved raw uniformly reduced to match new-action head size; content unchanged, no head composite','frames':records,'frozen_walk_sha256':hashlib.sha256((V/'Yunshang_Walk.png').read_bytes()).hexdigest()},indent=2))
