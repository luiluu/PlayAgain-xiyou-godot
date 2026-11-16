from PIL import Image,ImageDraw
from pathlib import Path
import math,json,collections
root=Path('03_再刷重制_Godot/01_Godot工程/content'); out=root/'tianqi/ring_style';out.mkdir(parents=True,exist_ok=True)
proof=Path('00_项目管理/交付/gpt_ring-art-sample_预览')
def palette(path,targets):
 im=Image.open(root/path).convert('RGBA'); colors=collections.Counter(tuple(round(p[i]*p[3]/255+24*(1-p[3]/255)) for i in range(3)) for p in im.getdata() if p[3]>20)
 return [min(colors,key=lambda c:sum((c[i]-t[i])**2 for i in range(3))) for t in targets]
hei=palette('tianqi/qiyin/circles/hei.png',[(112,80,40),(180,138,65),(244,209,124)])
mo=palette('tianqi/qiyin/circles/mo.png',[(95,77,113),(166,137,183)])
death=palette('tianqi/qiyin/badges_128/death.png',[(38,52,72),(83,112,145),(172,189,192)])
print('PALETTES',hei,mo,death)
for name,n in [('ring_band_hei',288),('ring_band_mo',288),('ring_center_death',96),('ring_orb_frame',56)]:
 im=Image.new('RGBA',(n,n)); p=im.load()
 for y in range(n):
  for x in range(n):
   dx=x+.5-n/2;dy=y+.5-n/2;r=math.hypot(dx,dy);a=math.atan2(dy,dx);c=None
   if name=='ring_band_hei':
    if 110.5<=r<=112.5:c=hei[1 if dy>0 else 2]
    if 118<=r<=119.5:c=hei[0]
    # Continuous shallow chevron ribbon: no separate ticks or dots.
    tri=abs(((a/math.tau*48)%1)*2-1)
    if 123<=r<=124.5 or 130<=r<=131.5:c=hei[1]
    if abs(r-(125+4*tri))<.7:c=hei[0]
   elif name=='ring_band_mo':
    if 111<=r<=112.3:c=mo[0 if dy>0 else 1]
   elif name=='ring_center_death':
    if 33<=r<=37.5:c=death[0]
    if 33<=r<=34 or 36<=r<=37:c=death[1 if dy>0 else 2]
    # Upright sword: the death badge's blade and crossguard silhouette.
    if dy<-35 and r<=46 and abs(math.degrees(math.atan2(dx,-dy)))<=15:
     if abs(dx)<=1.5 or (-40.5<=dy<=-38.5 and abs(dx)<=7):c=death[2]
     if abs(dx)<=.5 and dy<-37:c=death[1]
   else:
    if 21<=r<=24:c=(95,95,95)
    if 21<=r<=22 or 23<=r<=24:c=(190,190,190) if dy<0 else (126,126,126)
    if 23<=r<=28 and abs(abs(dx)-abs(dy))<2.2:c=(155,155,155) if abs(abs(dx)-abs(dy))<.8 else (72,72,72)
   if c:
    # Keep the entire pixel square inside the prescribed radial envelope.
    near=math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0));far=math.hypot(abs(dx)+.5,abs(dy)+.5)
    inner=100 if n==288 else (33 if n==96 else 21)
    outer=138 if n==288 else (38 if n==96 and dy>=-35 else 46 if n==96 else 24 if abs(abs(dx)-abs(dy))>=2.2 else 28)
    if near>=inner and far<=outer:p[x,y]=(*c,255)
 im.save(out/(name+'.png'))
# asset sheet enlarged with nearest neighbor only
sheet=Image.new('RGB',(1000,650),'#1d2028');d=ImageDraw.Draw(sheet)
for name,pos in [('ring_band_hei',(20,30)),('ring_band_mo',(350,30)),('ring_center_death',(700,40)),('ring_orb_frame',(740,330))]:
 im=Image.open(out/(name+'.png'));s=2 if im.width<100 else 1;im=im.resize((im.width*s,im.height*s),Image.Resampling.NEAREST);sheet.paste(im,pos,im);d.text((pos[0],pos[1]-18),name,fill='white')
sheet.save(proof/'assets_nearest.png')
(proof/'palette.json').write_text(json.dumps({'hei':hei,'mo':mo,'death':death},indent=2))
