"""Whole-subject uniform scale only. No split body warps or frame synthesis.
Landmarks are manually marked on source pixels; uncertainty is recorded.
"""
from PIL import Image
from pathlib import Path
import json
P=Path(__file__).resolve().parent
NAMES=['down','left','right','up','wait']
COLOR_COUNT=48

def spans(im):
 a=im.getchannel('A');res=[];st=None
 for x in range(im.width+1):
  on=x<im.width and a.crop((x,0,x+1,im.height)).getbbox() is not None
  if on and st is None:st=x
  if not on and st is not None:
   if x-st>=20:res.append((st,x))
   st=None
 if len(res)!=3:raise ValueError(res)
 return res

def main():
 refs=json.loads((P/'reference_measurements.json').read_text());marks=json.loads((P/'source_landmarks.json').read_text());template=Image.open(P/'template_walk.png').convert('RGBA');battle=Image.open(P/'template_battle.png').convert('RGBA')
 walk=Image.new('RGBA',(144,192));wait=Image.new('RGBA',(192,64));records=[]
 for row,n in enumerate(NAMES):
  raw=Image.open(P/f'raw_{n}.png').convert('RGBA');raw.putalpha(raw.getchannel('A').point(lambda a:255 if a>=128 else 0))
  for col,(a,b) in enumerate(spans(raw)):
   crop=raw.crop((a,0,b,raw.height));bb=crop.getbbox();c=crop.crop(bb);m=marks[n][col];size=48 if row<4 else 64
   rb=(template.crop((col*48,row*48,col*48+48,row*48+48)) if row<4 else battle.crop((col*64,64,col*64+64,128))).getbbox()
   target=next(r for r in refs if r['character']=='Guyu' and r['direction']==n and r['frame']==col) if row<5 else None
   # Select ONE scale by total height; all anatomy retains identical uniform scale.
   desired=target['height'] if target else rb[3]-rb[1]
   if target:
    # Minimax fit of ONE whole-subject scale to the four anatomical guide metrics.
    measurements={'head_height':None if m['neck_y'] is None else m['neck_y']-m['crown_y'],'head_width':m['head_right']-m['head_left'],'height':bb[3]-m['crown_y'],'shoulder_width':None if m['shoulder_left'] is None else m['shoulder_right']-m['shoulder_left']}
    valid=[k for k in measurements if measurements[k] is not None and target[k] is not None]
    source=[measurements[k] for k in valid];target_values=[target[k] for k in valid]
    def error(hh):
     sc=hh/c.height
     native_crown=rb[3]-hh+round((m['crown_y']-bb[1])*sc)
     exact={'height':rb[3]-native_crown,'head_width':round((m['head_right']-a)*sc)-round((m['head_left']-a)*sc),'head_height':None if m['neck_y'] is None else round((m['neck_y']-bb[1])*sc)-round((m['crown_y']-bb[1])*sc),'shoulder_width':None if m['shoulder_left'] is None else round((m['shoulder_right']-a)*sc)-round((m['shoulder_left']-a)*sc)}
     ds=[abs(exact[k]-target[k]) for k in valid]
     return (max(ds),sum(ds),abs(exact['height']-desired))
    h=min(range(32,rb[3]+1),key=error)
   else:h=desired
   scale=h/c.height;w=round(c.width*scale)
   if w>size-2:raise ValueError((n,col,w))
   c=c.resize((w,h),Image.Resampling.NEAREST);x=round((rb[0]+rb[2]-w)/2);y=rb[3]-h
   if x<0 or y<0 or x+w>size:raise ValueError(('overflow',n,col,x,y,w,h))
   cell=Image.new('RGBA',(size,size));cell.paste(c,(x,y))
   def sy(v):return None if v is None else y+round((v-bb[1])*scale)
   def sx(v):return None if v is None else x+round((v-a)*scale)
   crown=sy(m['crown_y']);neck=sy(m['neck_y']);head_left=sx(m['head_left']);head_right=sx(m['head_right']);sl=sx(m['shoulder_left']);sr=sx(m['shoulder_right'])
   measured=dict(head_height=None if neck is None else neck-crown,head_width=head_right-head_left,height=rb[3]-crown,shoulder_width=None if sl is None else sr-sl,bun_height=crown-y)
   delta={k:measured[k]-target[k] for k in measured if k!='bun_height' and measured[k] is not None and target[k] is not None} if target else {};warnings={k:v for k,v in delta.items() if abs(v)>1}
   rec=dict(direction=n,frame=col,source_span=[a,b],source_bbox=[a,bb[1],b,bb[3]],source_marks=m,uniform_scale=scale,output_bbox=cell.getbbox(),output_landmarks=dict(crown_y=crown,neck_y=neck,head_left=head_left,head_right=head_right,shoulder_left=sl,shoulder_right=sr,shoulder_y=sy(m['shoulder_y'])),measured=measured,guyu_target=target,delta_vs_guyu=delta,difference_over_1px=warnings)
   records.append(rec)
   if row<4:walk.paste(cell,(col*48,row*48))
   else:wait.paste(cell,(col*64,0))
 # One palette learned from ALL 15 frames' opaque native pixels, then shared.
 opaque=[px[:3] for sheet in [walk,wait] for px in sheet.getdata() if px[3]]
 sample=Image.new('RGB',(len(opaque),1));sample.putdata(opaque)
 learned=sample.quantize(colors=COLOR_COUNT,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
 entries=learned.getpalette()[:COLOR_COUNT*3]
 shared=Image.new('P',(1,1));shared.putpalette(entries+entries[:3]*(256-COLOR_COUNT))
 def mapped(sheet):
  alpha=sheet.getchannel('A');out=sheet.convert('RGB').quantize(palette=shared,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(alpha);return out
 walk=mapped(walk);wait=mapped(wait)
 walk.save(P/'Yunshang_Walk.png');wait.save(P/'Yunshang_Wait.png')
 (P/'palette.json').write_text(json.dumps(dict(method='global median-cut from all15 native frames; one shared48color palette; no per-frame quantization',colors=['#'+bytes(entries[i:i+3]).hex() for i in range(0,len(entries),3)]),indent=2))
 (P/'alignment.json').write_text(json.dumps(dict(method='single uniform whole-subject nearest-neighbor scale; global48color quantization AFTER all15 frames assembled',uncertainty='Normal cranial hair excludes ornaments/braids/hanging locks/bun; hidden shoulders and rear neck null, not inferred. Bun separate, not compared.',frames=records),indent=2))
if __name__=='__main__':main()
