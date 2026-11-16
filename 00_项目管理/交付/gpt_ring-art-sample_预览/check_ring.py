from PIL import Image
from pathlib import Path
import math,json
root=Path('03_再刷重制_Godot/01_Godot工程/content/tianqi/ring_style');proof=Path('00_项目管理/交付/gpt_ring-art-sample_预览')
for f in sorted(root.glob('*.png')):
 im=Image.open(f).convert('RGBA');rs=[];near=[];far=[];red=soft=0;body=[];tip=[]
 for y in range(im.height):
  for x in range(im.width):
   R,G,B,A=im.getpixel((x,y));soft+=A not in (0,255)
   if not A:continue
   dx=x+.5-im.width/2;dy=y+.5-im.height/2;r=math.hypot(dx,dy);rs.append(r);near.append(math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0)));far.append(math.hypot(abs(dx)+.5,abs(dy)+.5));red+=R>=120 and R>1.6*G and R>1.6*B
   if im.width==96:(tip if r>38 else body).append(r)
 print(f'{f.name}: {im.size}; center radius {min(rs):.3f}..{max(rs):.3f}; full pixel square envelope {min(near):.3f}..{max(far):.3f}; red={red}; soft_alpha={soft}; alpha=0/255')
 assert red==soft==0
for mode in ['16','20']:
 meta=json.load(open(proof/f'layout_{mode}.json'));cx,cy=meta['center'];ox,oy=meta['off'];rects=[(it['name'],[it['rect'][0]+ox,it['rect'][1]+oy,*it['rect'][2:]]) for it in meta['items']]
 def overlaps(im,cx,cy,scale,skip=''):
  im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST);left=round(cx-im.width/2);top=round(cy-im.height/2);count=0
  for y in range(im.height):
   for x in range(im.width):
    if not im.getpixel((x,y))[3]:continue
    for name,(rx,ry,w,h) in rects:
     if name!=skip and x+left+1>rx and x+left<rx+w and y+top+1>ry and y+top<ry+h:count+=1
  return count
 center=overlaps(Image.open(root/'ring_center_death.png'),cx,cy,1);others=0;own=0
 for it in meta['items']:
  if it['name'] in ['武器','副手']:
   x,y=it['pos'];others+=overlaps(Image.open(root/'ring_orb_frame.png'),x+ox,y+oy,it['scale'],it['name'])
 print(f'{mode}x9: center vs all 13 label rectangles={center}; orb vs other label rectangles={others}; own orb labels rendered above frame per spec')
 assert center==others==0
# Round 2 hard envelope assertions and corner brightness, not just a printed range.
for name,n in [('ring_band_hei',288),('ring_band_mo',288),('ring_center_death',96),('ring_orb_frame',56)]:
 im=Image.open(root/(name+'.png'));assert im.size==(n,n)
 corners=[0]*4
 for y in range(n):
  for x in range(n):
   R,G,B,A=im.getpixel((x,y))
   if not A:continue
   dx=x+.5-n/2;dy=y+.5-n/2;r=math.hypot(dx,dy);near=math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0));far=math.hypot(abs(dx)+.5,abs(dy)+.5)
   if n==288:assert near>=100 and far<=138
   if n==96:
    assert near>=33 and far<=46
    if far>38:assert dy<0 and abs(math.degrees(math.atan2(dx,-dy)))<=15
   if n==56:
    assert near>=21 and far<=28
    if far>24:assert abs(abs(dx)-abs(dy))<=2.6
    if r>24 and R>=180:corners[(dx>0)+2*(dy>0)]+=1
 if n==56:print('Corner bright pixels beyond r24:',corners);assert min(corners)>=10
print('Round 2: dimensions, full-square envelopes, 12h angular limit and bright corner counts PASS')
