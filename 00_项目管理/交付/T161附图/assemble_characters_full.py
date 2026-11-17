"""T161 binary alpha, true blank bands, uniform nearest-neighbor scale per sheet."""
from PIL import Image
from pathlib import Path
import json,statistics
P=Path(__file__).resolve().parent

def rgba(p):
 im=Image.open(p).convert('RGBA');im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0));return im

def build(name,walk=False):
 raw=rgba(P/f'raw_{name}_{"walk" if walk else "full"}.png');cols,rows,cell=(3,4,48) if walk else (9,6,64)
 spans=[]
 for y in range(raw.height):
  if raw.getchannel('A').crop((0,y,raw.width,y+1)).getbbox():
   if not spans or y>spans[-1][1]+1:spans.append([y,y])
   else:spans[-1][1]=y
 spans=[(a,b) for a,b in spans if b-a>12];assert len(spans)==rows,spans
 bands=[0]+[(spans[i][1]+spans[i+1][0])//2 for i in range(rows-1)]+[raw.height]
 parts=[]
 for r in range(rows):
  strip=raw.crop((0,bands[r],raw.width,bands[r+1]))
  alpha=strip.getchannel('A');blank=[x for x in range(raw.width) if x>1 and x<raw.width-2 and not alpha.crop((x-1,0,x+2,strip.height)).getbbox()]
  cuts=[0]+[min((x for x in blank if abs(x-k*raw.width/cols)<raw.width/cols*0.3),key=lambda x:abs(x-k*raw.width/cols)) for k in range(1,cols)]+[raw.width]
  for c in range(cols):
   q=strip.crop((cuts[c],0,cuts[c+1],strip.height));bb=q.getbbox();assert bb
   assert bb[0]>0 and bb[1]>0 and bb[2]<q.width and bb[3]<q.height,(r,c,bb,'touches cell')
   parts.append(q.crop(bb))
 if walk:scale=(40 if name=="xuan" else 32)/statistics.median(q.height for q in parts)
 else:
  approved=rgba(P/('xuan_float_row0_64.png' if name=='xuan' else 'hajimi_greatsword_row0_64.png'))
  scale=statistics.median((approved.crop((c*64,0,(c+1)*64,64)).getbbox()[3]-approved.crop((c*64,0,(c+1)*64,64)).getbbox()[1])/parts[c].height for c in range(3))
 out=Image.new('RGBA',(cols*cell,rows*cell));records=[]
 for i,q in enumerate(parts):
  wh=(round(q.width*scale),round(q.height*scale));assert max(wh)<=cell-2,(i,wh)
  q=q.resize(wh,Image.Resampling.NEAREST);x=(cell-wh[0])//2;y=cell-wh[1]
  out.alpha_composite(q,((i%cols)*cell+x,(i//cols)*cell+y));records.append({'i':i,'size':wh,'pos':[x,y]})
 key='Walk' if walk else 'Battle';out.save(P/f'{name}_{key}_candidate.png')
 (P/f'{name}_{key}_alignment.json').write_text(json.dumps({'scale':scale,'frames':records},indent=2))
 bg=Image.new('RGBA',out.size,'#607080');bg.alpha_composite(out);bg.convert('RGB').save(P/f'{name}_{key}_native.png')
 print(name,key,len(parts),scale)
if __name__=='__main__':
 import sys
 build(sys.argv[1],len(sys.argv)>2 and sys.argv[2]=='walk')
