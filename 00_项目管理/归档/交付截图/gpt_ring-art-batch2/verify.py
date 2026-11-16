from PIL import Image
from pathlib import Path
import math,json,hashlib,subprocess
P=Path('00_项目管理/交付/gpt_ring-art-batch2_预览');S=P.parent/'gpt_ring-art-sample_预览';A=Path('03_再刷重制_Godot/01_Godot工程/content/tianqi/ring_style')
keys=['band_bai','band_hong','band_hui','band_xun','band_zhen','center_war','center_plague','center_famine','center_qiyin'];meta=json.load(open(S/'layout_20.json'));cx,cy=meta['center'];ox,oy=meta['off']
for key in keys:
 f=A/f'ring_{key}.png';im=Image.open(f).convert('RGBA');n=288 if key.startswith('band') else 96;assert im.size==(n,n);rs=[];red=soft=overlap=0
 for y in range(n):
  for x in range(n):
   R,G,B,a=im.getpixel((x,y));soft+=a not in (0,255)
   if not a:continue
   red+=R>=120 and R>1.6*G and R>1.6*B
   dx=x+.5-n/2;dy=y+.5-n/2;near=math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0));far=math.hypot(abs(dx)+.5,abs(dy)+.5);rs.append((near,far))
   if n==288:assert near>=100 and far<=138
   else:
    assert near>=33 and far<=46
    if far>38:assert dy<0 and abs(math.degrees(math.atan2(dx,-dy)))<=15
    xx=x+round(cx-48);yy=y+round(cy-48)
    for it in meta['items']:
     rx,ry,w,h=it['rect'];rx+=ox;ry+=oy
     overlap+=xx+1>rx and xx<rx+w and yy+1>ry and yy<ry+h
 assert red==soft==overlap==0
 print(f'{f.name}: {n}x{n}; full-square radius={min(v[0] for v in rs):.3f}..{max(v[1] for v in rs):.3f}; red={red}; soft_alpha={soft}; center_label_overlap={overlap if n==96 else "N/A band drawn below labels"}')
for key in ['band_hei','band_mo','center_death','orb_frame']:
 f=A/f'ring_{key}.png';before=subprocess.check_output(['git','show',f'a2294d4a3:{f}']);assert before==f.read_bytes()
print('PASS: 9 dimensions / full pixel envelopes / red threshold / binary alpha / 4 center label intersections; 4 approved samples byte-identical.')
# Carbon P1/P2 revision evidence, independent of the generator's matrix parser.
for key in ['war','plague','famine','qiyin']:
 im=Image.open(A/f'ring_center_{key}.png');mismatches=0
 for y in range(4,12):
  for x in range(40,56):assert im.getpixel((x,y))==im.getpixel((95-x,y))
 for y in range(12,96):
  for x in range(96):
   dx=x+.5-48;dy=y+.5-48;r=math.hypot(dx,dy);near=math.hypot(max(abs(dx)-.5,0),max(abs(dy)-.5,0));far=math.hypot(abs(dx)+.5,abs(dy)+.5)
   # Whole circular body must retain the original ring shading, without emblem overpaint.
   if near>=33 and far<=38:
    colors={'war':[(52,26,20),(138,88,60),(222,168,84)],'plague':[(34,38,26),(108,128,52),(196,210,96)],'famine':[(42,40,34),(132,124,98),(206,198,166)],'qiyin':[(46,32,18),(168,126,52),(242,206,118)]}[key]
    expected=colors[0] if r>36.8 else colors[1]
    if r<=34.4 or 35.6<=r<=36.6:expected=colors[2] if dy<0 else colors[1]
    mismatches+=im.getpixel((x,y))!=(*expected,255)
 assert mismatches==0
 print(f'P1-1 {key}: symmetric crown PASS; circular body y>=12 overpaint={mismatches}')
for key in ['hong','xun','hui']:
 im=Image.open(A/f'ring_band_{key}.png');old=Image.open(__import__('io').BytesIO(subprocess.check_output(['git','show',f'58a5d888d:{A}/ring_band_{key}.png'])));count=bright=old_count=0
 for y in range(288):
  for x in range(288):
   r=math.hypot(x+.5-144,y+.5-144)
   if 123<=r<=138:
    R,G,B,a=im.getpixel((x,y));count+=a>0;old_count+=old.getpixel((x,y))[3]>0
    bright+=a>0 and .2126*R+.7152*G+.0722*B>=150
 if key=='hong':assert bright>0
 else:assert count<old_count
 print(f'{key} outer r123..138: opaque={count} (before {old_count}); luma>=150 pixels={bright}')
for a,b,ca,cb in [('war','famine',(138,88,60),(132,124,98)),('war','qiyin',(138,88,60),(168,126,52)),('famine','qiyin',(132,124,98),(168,126,52))]:
 dist=math.dist(ca,cb);assert dist>25;print(f'P1-1 mid-color distance {a}/{b}={dist:.2f}')
print('Revision evidence PASS; final aesthetic approval remains with coordinator/Kyo.')
