from PIL import Image,ImageDraw
from pathlib import Path
import math,json,shutil
p=Path('00_项目管理/交付/gpt_ring-art-sample_预览');a=Path('03_再刷重制_Godot/01_Godot工程/content/tianqi/ring_style')
def paste(im,asset,cx,cy,scale=1):
 asset=asset.resize((round(asset.width*scale),round(asset.height*scale)),Image.Resampling.NEAREST);im.paste(asset,(round(cx-asset.width/2),round(cy-asset.height/2)),asset)
def disk_asset(im,cx,cy,r):
 box=im.crop((round(cx-r),round(cy-r),round(cx+r),round(cy+r))).convert('RGBA');pix=box.load()
 for y in range(box.height):
  for x in range(box.width):
   if math.hypot(x+.5-r,y+.5-r)>r:pix[x,y]=(0,0,0,0)
 return box
for m in ('16','20'):
 for kind in ('clean','bare'):shutil.copyfile(f'/tmp/ring_{m}_{kind}.png',p/f'{kind}_{m}x9.png')
 meta=json.load(open(p/f'layout_{m}.json'));cx,cy=meta['center'];ox,oy=meta['off'];base=Image.open(p/f'clean_{m}x9.png').convert('RGBA');bare=Image.open(p/f'bare_{m}x9.png').convert('RGBA');default=Image.open(p/f'base_{m}x9.png').convert('RGBA');results=[]
 for style in ('hei','mo'):
  im=bare.copy();paste(im,Image.open(a/f'ring_band_{style}.png'),cx,cy)
  # Restore balls and focus halo exactly from clean engine view, above the band.
  for it in meta['items']:
   x,y=it['pos'];x+=ox;y+=oy;r=36 if it['name']=='武器' else 27
   paste(im,disk_asset(base,x,y,r),x,y)
  paste(im,disk_asset(base,cx,cy,41),cx,cy,33/41)
  paste(im,Image.open(a/'ring_center_death.png'),cx,cy)
  for it in meta['items']:
   if it['name'] in ('武器','副手'):
    x,y=it['pos'];paste(im,Image.open(a/'ring_orb_frame.png'),x+ox,y+oy,it['scale'])
  # Label layer is restored last (engine rectangles, same as T029 ordering).
  for it in meta['items']:
   x,y,w,h=it['rect'];box=(math.floor(x+ox),math.floor(y+oy),math.ceil(x+w+ox),math.ceil(y+h+oy));im.paste(base.crop(box),box[:2])
  results.append(im)
 sheet=Image.new('RGB',(base.width*2,base.height+26),'#161419');d=ImageDraw.Draw(sheet)
 for j,(s,im) in enumerate(zip(('HEI / binary pixel sample','MO / binary pixel sample'),results)):
  sheet.paste(im,(j*base.width,26));d.text((j*base.width+12,7),s,fill='white')
 sheet.save(p/f'composite_{m}x9.png')
 # Identical 400x440 crops at native scale; no rescaling tricks.
 compare=Image.new('RGB',(1200,466),'#161419');d=ImageDraw.Draw(compare)
 for j,(s,im) in enumerate(zip(('DEFAULT','HEI','MO'),[default,*results])):
  compare.paste(im.crop((int(cx-200),int(cy-220),int(cx+200),int(cy+220))),(j*400,26));d.text((j*400+12,7),f'{s} / {m}:9 / 1x',fill='white')
 compare.save(p/f'default_vs_new_{m}x9.png')
death=Image.open(a/'ring_center_death.png');dim=death.copy();dim.putdata([(*(round(v*.6) for v in c[:3]),c[3]) for c in death.getdata()]);sheet=Image.new('RGBA',(440,230),'#232021');d=ImageDraw.Draw(sheet)
for x,s,im in [(20,'INTACT',death),(230,'BROKEN x0.6',dim)]:paste(sheet,im,x+96,125,2);d.text((x,12),s,fill='white')
sheet.convert('RGB').save(p/'death_intact_broken_x2.png')

for m in ('16','20'):
 meta=json.load(open(p/f'layout_{m}.json'));cx,cy=meta['center'];ox,oy=meta['off'];clean=Image.open(p/f'clean_{m}x9.png').convert('RGB');default=Image.open(p/f'base_{m}x9.png').convert('RGB');sheet=Image.open(p/f'composite_{m}x9.png').convert('RGB')
 imgs=[default,sheet.crop((0,26,clean.width,clean.height+26)),sheet.crop((clean.width,26,clean.width*2,clean.height+26))];sums=[0,0,0];counts=[0,0,0]
 for y in range(int(cy-138),int(cy+139)):
  for x in range(int(cx-138),int(cx+139)):
   if not 100<=math.hypot(x+.5-cx,y+.5-cy)<=138:continue
   if any(math.hypot(x-(it['pos'][0]+ox),y-(it['pos'][1]+oy))<(36 if it['name']=='武器' else 27) for it in meta['items']):continue
   if any(it['rect'][0]+ox-1<=x<=it['rect'][0]+ox+it['rect'][2]+1 and it['rect'][1]+oy-1<=y<=it['rect'][1]+oy+it['rect'][3]+1 for it in meta['items']):continue
   for i,im in enumerate(imgs):
    delta=sum(w*(im.getpixel((x,y))[k]-clean.getpixel((x,y))[k]) for k,w in enumerate((.2126,.7152,.0722)))
    sums[i]+=max(delta,0);counts[i]+=delta>20
 print(f'{m}:9 visible annulus DEFAULT/HEI/MO: positive luma sum={list(map(round,sums))}; pixels delta>20={counts}')
