"""Run from repo root with Pillow. Native binary pixels, no antialiasing."""
from PIL import Image,ImageDraw
from pathlib import Path
import math,json,colorsys
P=Path('00_项目管理/交付/gpt_ring-art-batch2_预览');S=Path('00_项目管理/交付/gpt_ring-art-sample_预览');A=Path('03_再刷重制_Godot/01_Godot工程/content/tianqi/ring_style');Q=A.parent/'qiyin'
targets={'bai':('circles/bai.png',[(52,48,35),(158,150,110),(220,214,174)]),'hong':('frames/hong.png',[(51,30,26),(108,62,46),(170,133,67)]),'hui':('circles/hui.png',[(29,43,41),(100,126,111),(172,189,168)]),'xun':('circles/xun.png',[(54,45,40),(171,162,146),(229,221,203)]),'zhen':('circles/zhen.png',[(28,32,62),(80,95,151),(152,169,210)]),'war':('badges_128/war.png',[(55,36,22),(142,101,44),(216,171,71)]),'plague':('badges_128/plague.png',[(37,34,30),(102,114,47),(176,184,92)]),'famine':('badges_128/famine.png',[(48,36,24),(137,106,51),(216,177,96)]),'qiyin':('circles/hei.png',[(49,35,22),(144,107,53),(221,180,100)])}
pal={};sources={}
for key,(path,ts) in targets.items():
 src=Image.open(Q/path).convert('RGBA');choices=[]
 for y in range(src.height):
  for x in range(src.width):
   r,g,b,a=src.getpixel((x,y))
   if a<240 or (r>=120 and r>1.6*g and r>1.6*b):continue
   choices.append(((r,g,b),(x,y)))
 pal[key]=[];sources[key]=[]
 for target in ts:
  rgb,xy=min(choices,key=lambda v:sum((v[0][i]-target[i])**2 for i in range(3)))
  # Derived palette: source hue/material, luminance adjusted to sample's readable levels.
  h,s,v=colorsys.rgb_to_hsv(*(c/255 for c in rgb));th,ss,vv=colorsys.rgb_to_hsv(*(c/255 for c in target))
  out=tuple(round(c*255) for c in colorsys.hsv_to_rgb(th,ss,vv))
  pal[key].append(out);sources[key].append({'source':str(path),'xy':xy,'source_rgb':rgb,'output_rgb':out,'method':'source material reference; muted hue and luminance matched to approved sample'})
def bounds(dx,dy):return math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0)),math.hypot(abs(dx)+.5,abs(dy)+.5)
for k in targets:
 n=288 if k in ['bai','hong','hui','xun','zhen'] else 96;im=Image.new('RGBA',(n,n));px=im.load();dark,mid,light=pal[k]
 for y in range(n):
  for x in range(n):
   dx=x+.5-n/2;dy=y+.5-n/2;r=math.hypot(dx,dy);a=math.atan2(dy,dx);near,far=bounds(dx,dy);c=None
   if n==288:
    if 109.5<=r<=114:c=dark if r<110.5 or r>113 else light if dy<0 else mid
    if k=='bai':
     if 119<=r<=121:c=mid
     wave=(1-abs((a/math.tau*40)%1*2-1));outer=127+5*wave
     if 123<=r<=outer:c=dark if r<124 or r>outer-1.2 else light if dy<0 else mid
    if k=='hong':
     outer=125+7*((a/math.tau*48)%1)
     if 120<=r<=outer:c=dark if r<121 or r>outer-1.2 else mid
     if 121.2<=r<=122.5:c=light
    if k=='hui':
     # Continuous braided bone chain, two crossing strands with connected dark bed.
     w=math.sin(a*24);r1=126+3*w;r2=126-3*w
     if 120<=r<=132:c=dark
     if min(abs(r-r1),abs(r-r2))<=1.5:c=light if dy<0 else mid
     if abs(w)>.87 and 123<=r<=129:c=mid
    if k=='xun':
     outer=125+7*max(0,math.sin(a*36))**3
     if 120<=r<=outer:c=dark if r<121 or r>outer-1 else mid
     if 121.5<=r<=123:c=light
     if outer>129 and outer-2.8<=r<=outer-1:c=light
    if k=='zhen':
     # Staggered cracks, two tracks bridge each other's interruptions.
     phase=(a/math.tau*13)%1
     if phase<.82:
      rr=124+2*math.sin(a*13)
      if abs(r-rr)<2.3:c=dark if abs(r-rr)>1.2 else light if dy<0 else mid
     if phase>.65 or phase<.1:
      if 128<=r<=130:c=mid
     if .78<phase<.86 and 122<=r<=130:c=mid
     if .42<phase<.50 and 109<=r<=115:c=None
    if not (near>=100 and far<=138):c=None
   else:
    if near>=33 and far<=38:
     c=dark if r>36.8 else mid
     if r<=34.4 or 35.6<=r<=36.6:c=light if dy<0 else mid
   if c:px[x,y]=(*c,255)
 if n==96:
  d=ImageDraw.Draw(im)
  # Shared taper reaches y3; connected to the frame at y11..14.
  d.polygon([(47,3),(48,3),(50,8),(52,11),(51,14),(44,14),(43,11),(45,8)],fill=(*dark,255))
  if k=='war':
   d.line([(45,6),(50,12)],fill=(*light,255),width=2);d.line([(50,6),(45,12)],fill=(*mid,255),width=2);d.line([(44,10),(47,8)],fill=(*light,255))
  elif k=='plague':
   d.line([(47,5),(47,11),(44,9),(45,7),(49,11),(51,9),(49,7),(45,11)],fill=(*light,255),width=1)
  elif k=='famine':
   d.line([(44,9),(51,9),(49,12),(46,12),(44,9)],fill=(*light,255),width=1);d.line([(47,5),(47,7),(49,7)],fill=(*mid,255))
  else:
   d.rectangle((45,7,50,12),outline=(*light,255));d.line([(47,4),(47,10),(49,10)],fill=(*mid,255));d.point((47,12),fill=(*light,255))
  for y in range(n):
   for x in range(n):
    if not px[x,y][3]:continue
    dx=x+.5-48;dy=y+.5-48;near,far=bounds(dx,dy)
    if near<33 or far>46 or (far>38 and (dy>=0 or abs(math.degrees(math.atan2(dx,-dy)))>15)):px[x,y]=(0,0,0,0)
 im.save(A/f'ring_{"band" if n==288 else "center"}_{k}.png')
(P/'palette_sources.json').write_text(json.dumps(sources,indent=2))
# Overviews: native size, no image smoothing.
for name,keys,kind,w,h in [('bands',['bai','hong','hei','hui','xun','zhen','mo'],'band',304,320),('centers',['war','plague','famine','death','qiyin'],'center',150,145)]:
 sheet=Image.new('RGB',(w*len(keys),h),'#25232a');d=ImageDraw.Draw(sheet)
 for i,k in enumerate(keys):
  im=Image.open(A/f'ring_{kind}_{k}.png');sheet.paste(im,(i*w+(w-im.width)//2,30),im);d.text((i*w+12,10),k,fill='white')
 sheet.save(P/f'overview_{name}.png')
# Same approved 20:9 touch 130% engine base and layer order.
meta=json.load(open(S/'layout_20.json'));cx,cy=meta['center'];ox,oy=meta['off'];base=Image.open(S/'clean_20x9.png').convert('RGBA');bare=Image.open(S/'bare_20x9.png').convert('RGBA')
def paste(im,asset,x,y):im.paste(asset,(round(x-asset.width/2),round(y-asset.height/2)),asset)
def disk(im,x,y,r):
 box=im.crop((round(x-r),round(y-r),round(x+r),round(y+r))).convert('RGBA');p=box.load()
 for yy in range(box.height):
  for xx in range(box.width):
   if math.hypot(xx+.5-r,yy+.5-r)>r:p[xx,yy]=(0,0,0,0)
 return box
for k,center in zip(['bai','hong','hei','hui','xun','zhen','mo'],['war','war','famine','death','plague','qiyin','qiyin']):
 im=bare.copy();paste(im,Image.open(A/f'ring_band_{k}.png'),cx,cy)
 for it in meta['items']:
  x,y=it['pos'];paste(im,disk(base,x+ox,y+oy,36 if it['name']=='武器' else 27),x+ox,y+oy)
 avatar=disk(base,cx,cy,41).resize((66,66),Image.Resampling.NEAREST);paste(im,avatar,cx,cy);paste(im,Image.open(A/f'ring_center_{center}.png'),cx,cy)
 for it in meta['items']:
  if it['name'] in ('武器','副手'):
   x,y=it['pos'];orb=Image.open(A/'ring_orb_frame.png');orb=orb.resize((round(56*it['scale']),)*2,Image.Resampling.NEAREST);paste(im,orb,x+ox,y+oy)
 for it in meta['items']:
  x,y,w,h=it['rect'];box=(math.floor(x+ox),math.floor(y+oy),math.ceil(x+w+ox),math.ceil(y+h+oy));im.paste(base.crop(box),box[:2])
 im.save(P/f'composite_{k}_20x9_touch130.png');d=ImageDraw.Draw(im)
 for it in meta['items']:
  x,y,w,h=it['rect'];d.rectangle((x+ox,y+oy,x+w+ox,y+h+oy),outline='#70cdb1')
 d.text((10,10),f'{k} / {center} | 20:9 touch 130% | native size | label rectangles',fill='white');im.save(P/f'annotated_{k}_20x9_touch130.png')
