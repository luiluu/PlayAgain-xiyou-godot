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
