from PIL import Image,ImageDraw
from pathlib import Path
import json
p=Path(__file__).parent
base=Path('03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon')
ref=Image.open(base/'UserSV_MiraDragon1_0.png').convert('RGBA')
names=['14_0','15_0','7_2'];board=Image.new('RGB',(1020,960),(30,32,38));d=ImageDraw.Draw(board)
heads=Image.new('RGB',(240,390),(30,32,38));hd=ImageDraw.Draw(heads)
boxes={'14_0':(65,105,175,205),'15_0':(60,115,170,215),'7_2':(55,105,165,205)}
paws=Image.new('RGB',(240,240),(30,32,38));pd=ImageDraw.Draw(paws)
for row,n in enumerate(names):
 new=Image.open(p/(n+'-native.png')).convert('RGBA');orig=Image.open(base/('UserSV_MiraDragon'+n+'.png')).convert('RGBA');bb=new.getbbox()
 for x,label,im in [(0,n+' original',orig),(340,n+' candidate',new),(680,'1_0 identity',ref)]:
  board.paste(im,(x,row*320+30),im);d.text((x+5,row*320+5),label,fill='white')
 d.text((345,row*320+305),f'340x280  bbox={bb}  bottom=217',fill='white')
 hb=Image.new('RGB',(240,130),(30,32,38));hbd=ImageDraw.Draw(hb)
 for x,label,im,box in [(0,n,new,boxes[n]),(120,'1_0',ref,(60,50,170,150))]:
  crop=im.crop(box);hb.paste(crop,(x,25),crop);hbd.text((x+3,4),label+' head 1:1',fill='white')
 heads.paste(hb,(0,row*130));hb.save(p/(n+'-heads-native.png'))
 # Whole forepaw regions, unscaled, so posture and finger orientation stay visible.
 for x,label,im,box in [(0,n,new,(80,182,170,232)),(120,'1_0',ref,(60,182,150,232))]:
  crop=im.crop(box);paws.paste(crop,(x,row*80+22),crop);pd.text((x+3,row*80+2),label+' forepaws 1:1',fill='white')
board.save(p/'samples-native.png');heads.save(p/'heads-native.png');paws.save(p/'forepaws-native.png')
