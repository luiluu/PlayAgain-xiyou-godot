from pathlib import Path
from PIL import Image
import json,shutil
P=Path(__file__).parent;GAME=P.parents[4]/'03_再刷重制_Godot/01_Godot工程/content/yunshang_v2/u2';R=Path('/Users/kyo/.codex/generated_images/01a1e678-5c12-79f3-9540-014e18747978')
for dst,src in [('battle0','a3e7e8c5-0116-4445-9773-c789572290df'),('battle1','1dffec05-52d8-4366-aee3-66061b77dd77'),('battle2','89e5d995-25c6-4a6a-be5c-881dbce9e1e5'),('walk','76e1e075-8769-4484-8ec5-3538d3c9b4ef')]:
 if not (P/f'{dst}_raw.png').exists():shutil.copyfile(R/f'exec-{src}.png',P/f'{dst}_raw.png')
def cut(name,cols,rows,cuts=None):
 a=Image.open(P/f'{name}_raw.png').convert('RGBA');w,h=a.size;out=[]
 for r in range(rows):
  for c in range(cols):
   ys=cuts or [h*i//rows for i in range(rows+1)];im=a.crop((c*w//cols,ys[r],(c+1)*w//cols,ys[r+1]));im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0))
   # Remove tiny disconnected generated speckles, retaining the entire main figure.
   pix=im.load();seen=set();components=[]
   for y in range(im.height):
    for x in range(im.width):
     if (x,y) in seen or not pix[x,y][3]:continue
     q=[(x,y)];seen.add((x,y));comp=[]
     while q:
      xx,yy=q.pop();comp.append((xx,yy))
      for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
       if 0<=nx<im.width and 0<=ny<im.height and (nx,ny) not in seen and pix[nx,ny][3]:seen.add((nx,ny));q.append((nx,ny))
     components.append(comp)
   biggest=max(map(len,components))
   for comp in components:
    if len(comp)<biggest*.001:
     for x,y in comp:pix[x,y]=(0,0,0,0)
   b=im.getbbox();out.append(im.crop(b))
 return out
frames=[]
for g in range(3):frames+=cut(f'battle{g}',6,3)
# One factor for ALL 54 frames. No group-specific attack shrink.
scale=min(60/frames[4].height,62/max(f.width for f in frames),62/max(f.height for f in frames))
report={'sv_shared_scale':scale,'sv':[]};sheet=Image.new('RGBA',(576,384));preview=Image.new('RGBA',(384,576))
rendered=[]
def resize(im,s):
 w,h=round(im.width*s),round(im.height*s);im=im.resize((w*4,h*4),Image.Resampling.BOX).resize((w,h),Image.Resampling.BOX);im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0));return im
for g in range(3):
 for k in range(18):
  idx=g*18+k;m=g*6+(k//6)*2+(k%6)//3;f=k%3;im=resize(frames[idx],scale);tile=Image.new('RGBA',(64,64));tile.alpha_composite(im,((64-im.width)//2,62-im.height));sheet.alpha_composite(tile,((m//6*3+f)*64,m%6*64));preview.alpha_composite(tile,((k%6)*64,(g*3+k//6)*64));report['sv'].append({'motion':m,'frame':f,'bounds':tile.getbbox()});rendered.append(tile)
sheet.save(GAME/'Yunshang_SV_u2.png');preview.resize((1536,2304),Image.Resampling.NEAREST).save(P/'SV_all_4x.png')
a=Image.open(P/'walk_raw.png');walk=cut('walk',3,4,[0,350,700,1050,a.height]);s=46/walk[1].height;out=Image.new('RGBA',(144,192))
for i,im in enumerate(walk):
 im=resize(im,s);out.alpha_composite(im,((i%3)*48+(48-im.width)//2,(i//3)*48+48-im.height))
out.save(GAME/'$Yunshang_u2.png');out.resize((576,768),Image.Resampling.NEAREST).save(P/'walk_4x.png')
report['walk_scale']=s;report['idle_height']=report['sv'][4]['bounds'][3]-report['sv'][4]['bounds'][1];(P/'validation.json').write_text(json.dumps(report,indent=2));print('SV scale',scale,'idle height',report['idle_height'],'max width',max(x['bounds'][2]-x['bounds'][0] for x in report['sv']))
