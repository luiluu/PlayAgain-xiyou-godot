from PIL import Image, ImageDraw
from pathlib import Path
import subprocess,json
P=Path('03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon');O=Path('归档/交付截图/luiluu_t207')
ns=['14_0','15_0','7_2','13_0']
polys=[[(73,170),(61,164),(61,118),(82,104),(105,90),(145,90),(157,113),(153,127),(131,127),(112,132),(94,144),(78,169)],[(73,165),(61,159),(61,116),(78,83),(117,83),(129,108),(146,113),(148,125),(120,130),(100,143),(78,165)],[(90,145),(104,130),(115,121),(146,108),(155,114),(155,134),(144,142),(120,147),(104,148)],[(111,88),(122,72),(140,58),(183,58),(185,70),(177,83),(151,89),(128,91)]]
gen=Image.open(O/'head-patches-generated.png').convert('RGBA').crop((0,125,2170,605)).resize((550,120),Image.Resampling.NEAREST)
board=Image.new('RGB',(1020,1160),'#414955');d=ImageDraw.Draw(board);rep=[]
ref=Image.open(P/'UserSV_MiraDragon1_0.png').convert('RGBA')
for i,n in enumerate(ns):
 path=P/f'UserSV_MiraDragon{n}.png';orig=Image.open(__import__('io').BytesIO(subprocess.check_output(['git','show','main:'+str(path)]))).convert('RGBA');patch=gen.crop(((i+1)*110,0,(i+2)*110,120));layer=Image.new('RGBA',orig.size);layer.paste(patch,(75,55));mask=Image.new('L',orig.size);ImageDraw.Draw(mask).polygon(polys[i],fill=255)
 for y in range(280):
  for x in range(340):
   r,g,b,a=orig.getpixel((x,y))
   if n=='15_0' and (x>110 or y>170) and b>r*1.17 and r>100 and b>120:
    for yy in range(max(0,y-1),min(280,y+2)):
     for xx in range(max(0,x-1),min(340,x+2)):mask.putpixel((xx,yy),0)
 for y in range(280):
  for x in range(340):
   r,g,b,a=layer.getpixel((x,y));layer.putpixel((x,y),(r,g,b,255) if a>=128 else (0,0,0,0))
 new=Image.composite(layer,orig,mask);new.save(path);orig.save(O/f'original_{n}.png');mask.save(O/f'mask_{n}.png');diff=Image.new('RGB',orig.size);count=outside=0
 for y in range(280):
  for x in range(340):
   if new.getpixel((x,y))!=orig.getpixel((x,y)):
    count+=1;outside+=mask.getpixel((x,y))==0;diff.putpixel((x,y),(255,80,80))
 diff.save(O/f'diff_{n}.png');rep.append({'frame':n,'changed_pixels':count,'outside_mask':outside,'alpha':sorted(set(new.getchannel('A').getdata())),'bbox':new.getbbox()})
 for j,im in enumerate([orig,new,ref]):board.paste(im,(340*j,290*i+10),im)
 d.text((5,290*i),n+' ORIGINAL | NEW | 1_0')
board.save(O/'comparison-native.png');(O/'pixel-check.json').write_text(json.dumps(rep,indent=2));print(json.dumps(rep,indent=2))
