"""T030 round 2: native binary pixels; radii/colors follow Carbon review."""
from PIL import Image, ImageDraw
from pathlib import Path
import math,json
root=Path('03_再刷重制_Godot/01_Godot工程/content/tianqi/ring_style')
proof=Path('00_项目管理/交付/gpt_ring-art-sample_预览')
pal={'hei':[(34,24,15),(140,102,48),(180,139,65),(245,209,124),(196,154,76),(205,164,84)],'mo':[(38,28,48),(206,178,218),(170,135,179),(142,110,156)],'death':[(46,52,68),(96,114,152),(192,196,198),(136,150,178)]}
def bounds(dx,dy):
 return math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0)),math.hypot(abs(dx)+.5,abs(dy)+.5)
for name,n in [('ring_band_hei',288),('ring_band_mo',288),('ring_center_death',96),('ring_orb_frame',56)]:
 im=Image.new('RGBA',(n,n));p=im.load();S=set()
 if n==56:
  S={(x,y) for y in range(n) for x in range(n) if (lambda b:b[0]>=21 and b[1]<=24)(bounds(x+.5-n/2,y+.5-n/2))}
 for y in range(n):
  for x in range(n):
   dx=x+.5-n/2;dy=y+.5-n/2;r=math.hypot(dx,dy);a=math.atan2(dy,dx);near,far=bounds(dx,dy);c=None
   if name=='ring_band_mo' and 109.5<=r<=114.5:
    c=pal['mo'][0]
    if 110.6<=r<=113.4:c=pal['mo'][1 if dy < -25 else 2 if dy<75 else 3]
   elif name=='ring_band_hei':
    if 109.5<=r<=114:
     c=pal['hei'][0]
     if 110.5<=r<=113:c=pal['hei'][3 if dy<0 else 4]
    if 120.5<=r<=131.5:
     c=pal['hei'][0]
     if r<=122.2:c=pal['hei'][2]
     if r>=129.8:c=pal['hei'][3 if dy<0 else 2]
     k=round(a/math.tau*60);delta=abs(a-k*math.tau/60)
     if delta*r<=.85 and 122.2<=r<=129.8:
      if k%5==0:c=pal['hei'][3 if dy<0 else 5]
      elif r>=126:c=pal['hei'][1]
   elif name=='ring_center_death':
    if near>=33 and far<=38:
     c=pal['death'][0] if r>36.8 else pal['death'][1]
     if r<=34.4 or 35.6<=r<=36.6:c=pal['death'][2 if dy<0 else 3]
    widths={3:2,4:2,5:4,6:4,7:4,8:6,9:6,10:10,11:10}
    if y in widths and abs(dx)<widths[y]/2:
     w=widths[y];edge=abs(dx)>w/2-1
     c=(42,48,64) if edge and y in (5,10,11) else (181,182,180) if edge else (98,118,158)
     if y in (6,7):c=(205,208,210) if edge else (120,140,178)
     if y==3:c=(222,226,228)
     if y==4:c=(181,182,180)
   elif n==56:
    if (x,y) in S:
     outside=inside=False
     for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
      bn,bf=bounds(xx+.5-28,yy+.5-28);outside|=bf>24;inside|=bn<21
     v=(215 if dy<0 else 145) if outside else (165 if dy<0 else 115) if inside else 95;c=(v,)*3
    if abs(abs(dx)-abs(dy))<=2.6 and r>=23 and far<=28:
     # One-pixel silhouette border, bright wings and diagonal spine.
     v=56 if abs(abs(dx)-abs(dy))>1.6 and r>26 else 235 if abs(abs(dx)-abs(dy))<.6 else 185
     c=(v,)*3
   if c:p[x,y]=(*c,255)
 im.save(root/(name+'.png'))
sheet=Image.new('RGB',(1000,650),'#1d2028');d=ImageDraw.Draw(sheet)
for name,pos in [('ring_band_hei',(20,30)),('ring_band_mo',(350,30)),('ring_center_death',(700,40)),('ring_orb_frame',(740,330))]:
 im=Image.open(root/(name+'.png'));s=2 if im.width<100 else 1;im=im.resize((im.width*s,im.height*s),Image.Resampling.NEAREST);sheet.paste(im,pos,im);d.text((pos[0],pos[1]-18),name,fill='white')
sheet.save(proof/'assets_nearest.png');(proof/'palette.json').write_text(json.dumps(pal,indent=2))
