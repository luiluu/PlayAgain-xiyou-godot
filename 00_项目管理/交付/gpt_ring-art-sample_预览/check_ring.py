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
