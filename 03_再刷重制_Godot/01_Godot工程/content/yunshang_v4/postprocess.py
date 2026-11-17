"""Alpha-column subject segmentation from T114 14d355606; fixed avatar palette.
Native neck cuts are human annotated guides, not automatic anatomical detection.
Only resize/remap/alignment; no frame copying, mirroring or pose synthesis.
"""
from pathlib import Path
from PIL import Image
import json
P=Path(__file__).resolve().parent
NAMES=['down','left','right','up','wait']
# Hand-selected target families; snap each to an actual visible portrait pixel.
TARGETS=['#f4f2fa','#d8d5e7','#aaa7c1','#77768d','#ffe4d1','#dba78c','#252849','#404975','#e5c574','#ad8647','#181925']
NECK_G=[27,27,27,27]; NECK_T=[33,32,32,32]
# fractions measured by viewing raw strips, crown through chin/neck.
SOURCE_NECK=[.53,.52,.52,.54,.54]
def spans(im):
 a=im.getchannel('A');res=[];start=None
 for x in range(im.width+1):
  active=x<im.width and a.crop((x,0,x+1,im.height)).getbbox() is not None
  if active and start is None:start=x
  if not active and start is not None:
   if x-start>=20:res.append((start,x))
   start=None
 if len(res)!=3:raise ValueError(f'expected 3 alpha subjects, got {res}')
 return res
def metrics(c,neck):
 bb=c.getbbox();head=c.crop((0,0,c.width,neck)).getbbox();body=c.crop((0,neck,c.width,c.height)).getbbox()
 return dict(bbox=bb,height=bb[3]-bb[1],neck_y=neck,head_height=neck-bb[1],head_width=head[2]-head[0],body_height=bb[3]-neck,body_width=body[2]-body[0])
def main():
 avatar=Image.open(P.parent/'yunshang_v2/Yunshang_Face_u1.png').convert('RGBA')
 colors=sorted({rgb[:3] for rgb in avatar.getdata() if rgb[3]>=128})
 def dist(a,b):return sum((a[i]-b[i])**2 for i in range(3))
 targets=[tuple(bytes.fromhex(h[1:])) for h in TARGETS]
 palette=[min(colors,key=lambda c:dist(c,t)) for t in targets]
 (P/'palette.json').write_text(json.dumps(dict(source='Yunshang_Face_u1.png alpha>=128 pixels',colors=['#'+bytes(c).hex() for c in palette]),indent=2))
 refs=[Image.open(P/'template_walk.png').convert('RGBA'),Image.open(P/'template_battle.png').convert('RGBA')];g=Image.open(P/'Guyu_Walk.png').convert('RGBA')
 walk=Image.new('RGBA',(144,192));idle=Image.new('RGBA',(192,64));records=[];cache={}
 for row,name in enumerate(NAMES):
  raw=Image.open(P/f'raw_{name}.png').convert('RGBA');raw.putalpha(raw.getchannel('A').point(lambda a:255 if a>=128 else 0))
  for col,(a,b) in enumerate(spans(raw)):
   c=raw.crop((a,0,b,raw.height));c=c.crop(c.getbbox());size=48 if row<4 else 64
   ref=refs[0].crop((col*48,row*48,col*48+48,row*48+48)) if row<4 else refs[1].crop((col*64,64,col*64+64,128));rb=ref.getbbox();h=rb[3]-rb[1];width=rb[2]-rb[0]
   record=dict(direction=name,frame=col,source_span=[a,b],source_bbox_size=c.size,template_bbox=rb)
   if row<4:
    gm=metrics(g.crop((col*48,row*48,col*48+48,row*48+48)),NECK_G[row]);tm=metrics(ref,NECK_T[row]);head_h=round(h*gm['head_height']/gm['height']);record.update(guyu=gm,yunxiao=tm,target_head_height=head_h); head_w=round(h*gm['head_width']/gm['height']);record['target_head_width']=head_w
   else:head_h=round(h*.52);head_w=width
   split=round(c.height*SOURCE_NECK[row]);upper=c.crop((0,0,c.width,split)).resize((head_w,head_h),Image.Resampling.NEAREST);lower=c.crop((0,split,c.width,c.height)).resize((width,h-head_h),Image.Resampling.NEAREST)
   cell=Image.new('RGBA',(size,size));cell.paste(upper,(round((rb[0]+rb[2]-head_w)/2),rb[1]));cell.paste(lower,(rb[0],rb[1]+head_h))
   pix=[]
   for r,gg,b,alpha in cell.getdata():
    if alpha==0:pix.append((0,0,0,0));continue
    key=(r,gg,b)
    if key not in cache:cache[key]=min(palette,key=lambda co:dist(co,key))
    pix.append((*cache[key],255))
   cell.putdata(pix);record.update(output_bbox=cell.getbbox(),output_head_split=rb[1]+head_h,baseline=rb[3]-1,palette_shared=True);records.append(record)
   if row<4:walk.paste(cell,(col*48,row*48))
   else:idle.paste(cell,(col*64,0))
 walk.save(P/'Yunshang_Walk.png');idle.save(P/'Yunshang_Wait.png');(P/'alignment.json').write_text(json.dumps(dict(reference_commit='14d355606',measurement='Human neck guides; head region includes hair, back view uses same neck guide (not face landmark). Source neck fractions annotated from raw image.',source_neck_fractions=SOURCE_NECK,frames=records),indent=2))
if __name__=='__main__':main()
