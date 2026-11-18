from PIL import Image,ImageDraw
from pathlib import Path
import io,subprocess,json,math
P=Path('03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon');O=Path('归档/交付截图/luiluu_t207/R4');O.mkdir(exist_ok=True)
def orig(n):return Image.open(io.BytesIO(subprocess.check_output(['git','show','main:'+str(P/f'UserSV_MiraDragon{n}.png')]))).convert('RGBA')
ref=orig('1_0');poly=[(104,111),(107,100),(109,91),(111,85),(119,80),(127,74),(130,69),(131,65),(129,61),(131,60),(134,64),(136,70),(135,75),(131,80),(125,84),(119,88),(118,92),(128,86),(136,80),(140,74),(142,69),(142,65),(140,60),(140,58),(143,60),(147,65),(148,71),(147,77),(143,83),(137,88),(130,93),(123,99),(117,106),(110,112)]
hm=Image.new('L',ref.size);ImageDraw.Draw(hm).polygon(poly,fill=255);horn=ref.copy();horn.putalpha(Image.composite(ref.getchannel('A'),Image.new('L',ref.size),hm));horn=horn.crop((100,55,152,115))
# root in crop is (10,53); coordinate conversion by affine inverse around this root.
settings={'14_0':((75,180),(81,173),35,1.0),'15_0':((72,164),(79,157),25,1.0),'7_2':((96,141),(103,134),-22,0.88),'13_0':((122,85),(129,78),-38,0.80)}
board=Image.new('RGB',(1020,1160),'#414955');bd=ImageDraw.Draw(board);report=[]
for i,(n,(eye,root,ang,scale)) in enumerate(settings.items()):
 old=orig(n);new=old.copy();mask=Image.new('L',old.size)
 if n in ['14_0','15_0']:
  erases={'14_0':[(61,178),(61,118),(78,118),(87,113),(100,108),(100,113),(91,125),(83,149),(77,178)],'15_0':[(61,166),(61,83),(116,83),(116,107),(105,119),(91,141),(78,166)]}
  ImageDraw.Draw(mask).polygon(erases[n],fill=255);ImageDraw.Draw(new).polygon(erases[n],fill=(0,0,0,0))
 if n=='13_0':
  erase=[(124,81),(133,70),(157,58),(185,58),(185,73),(161,79),(143,83)]
  ImageDraw.Draw(mask).polygon(erase,fill=255);ImageDraw.Draw(new).polygon(erase,fill=(0,0,0,0))
 if n=='7_2':
  cut=Image.new('L',old.size);ImageDraw.Draw(cut).polygon([(103,136),(109,129),(120,124),(136,123),(143,117),(147,116),(150,120),(151,128),(146,136),(132,141),(114,141)],fill=255)
  for yy in range(116,142):
   for xx in range(103,152):
    if cut.getpixel((xx,yy)):
     sample=old.getpixel((xx,yy-10));new.putpixel((xx,yy),sample);mask.putpixel((xx,yy),255)
 a=math.radians(ang);c=math.cos(a);s=math.sin(a)
 # PIL positive rotation is counterclockwise on screen; output inverse
 A=c/scale;B=-s/scale;D=s/scale;E=c/scale
 C=10-A*root[0]-B*root[1];F=53-D*root[0]-E*root[1]
 layer=horn.transform(old.size,Image.Transform.AFFINE,(A,B,C,D,E,F),Image.Resampling.NEAREST)
 new.alpha_composite(layer)
 # editing authorization is exact added horn silhouette plus explicit old-horn removal
 mask=Image.composite(Image.new('L',old.size,255),mask,layer.getchannel('A'))
 diff=Image.new('RGB',old.size);cnt=0;outside=0
 for y in range(280):
  for x in range(340):
   if new.getpixel((x,y))!=old.getpixel((x,y)):
    cnt+=1;outside+=mask.getpixel((x,y))==0;diff.putpixel((x,y),(255,75,75))
 new.save(P/f'UserSV_MiraDragon{n}.png');mask.save(O/f'mask_{n}.png');diff.save(O/f'diff_{n}.png')
 for j,im in enumerate([old,new,ref]):board.paste(im,(j*340,i*290+10),im)
 bd.text((5,i*290),n+' ORIGINAL | NEW | 1_0')
 # Native 140x160 head crop, separate annotated copy with point labels
 box=(55,55,195,215);crop=new.crop(box);crop.save(O/f'head_native_{n}.png');mark=Image.new('RGB',crop.size,'#414955');mark.paste(crop,(0,0),crop);d=ImageDraw.Draw(mark)
 root_b=(round(root[0]+scale*(5*c-4*s)),round(root[1]+scale*(-5*s-4*c)))
 for pt,col,txt in [(eye,'#00ffdd','eye'),(root,'#ffff00','root A'),(root_b,'#ff99ff','root B')]:
  x,y=pt[0]-55,pt[1]-55;d.line((x-2,y,x+2,y),fill=col);d.line((x,y-2,x,y+2),fill=col);d.line((x,y,x+15,y+10),fill=col);d.text((x+15,y+8),txt,fill=col)
 mark.save(O/f'head_marked_{n}.png');report.append({'frame':n,'eye':eye,'root':root,'root_b':root_b,'rotation':ang,'scale':scale,'changed':cnt,'outside_mask':outside,'bbox':new.getbbox(),'alpha':sorted(set(new.getchannel('A').getdata()))})
board.save(O/'comparison-native.png');(O/'pixel-check.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
