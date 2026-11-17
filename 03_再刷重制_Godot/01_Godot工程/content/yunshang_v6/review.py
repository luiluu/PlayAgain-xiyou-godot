from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
P=Path(__file__).resolve().parent;F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',23)
def load(n):return Image.open(P/n).convert('RGBA')
def put(o,im,xy,s=1):
 im=im.resize((im.width*s,im.height*s),Image.Resampling.NEAREST);o.paste(im,xy,im)
g=load('Guyu_Walk.png');w=load('Yunshang_Walk.png');i=load('Yunshang_Wait.png');b=load('Guyu_Battle.png');t=load('template_walk.png')
o=Image.new('RGB',(1080,1580),'#30343c');d=ImageDraw.Draw(o);d.text((20,15),'云裳第四轮：共享48色 · 女性面容与侧向细节',font=F,fill='white')
a=Image.open(P.parent/'yunshang_v2/Yunshang_Face_u1.png').convert('RGBA').crop((0,0,144,144));put(o,a,(20,65),2)
d.text((355,65),'同原生尺寸：谷雨定稿｜云裳新稿',font=F,fill='white');put(o,g,(380,110));put(o,w,(650,110));put(o,i,(640,330));put(o,b.crop((0,64,192,128)),(370,330))
for row,(label,rr) in enumerate([('正面',0),('左向',1),('右向',2)]):
 y=470+row*320;d.text((20,y),label+' 4倍：谷雨｜云裳（均未拉齐身高）',font=F,fill='white')
 put(o,g.crop((48,rr*48,96,rr*48+48)),(100,y+50),4);put(o,w.crop((48,rr*48,96,rr*48+48)),(430,y+50),4)
d.text((20,1460),'待机原生三帧：',font=F,fill='white');put(o,i,(270,1450));d.text((20,1530),'WIP · 未接入；T156报告另附，形象由Kyo审',font=F,fill='#ffcc88');o.save(P/'手机首屏.png');o.save(P/'手机总览.png')
# Larger face comparison retains the same native pixels for detailed inspection.
o=Image.new('RGB',(900,1100),'#30343c');d=ImageDraw.Draw(o)
for row,(label,rr) in enumerate([('正面',0),('左向',1),('右向',2)]):
 y=row*360;d.text((15,y+5),label+' 谷雨｜云裳 4倍',font=F,fill='white');put(o,g.crop((48,rr*48,96,rr*48+48)),(60,y+50),4);put(o,w.crop((48,rr*48,96,rr*48+48)),(430,y+50),4)
o.save(P/'三向4倍对比.png')
for kind in ['walk','wait']:
 frames=[]
 for k in [0,1,2,1]:
  out=Image.new('RGB',(768,830 if kind=='walk' else 310),'#30343c');dd=ImageDraw.Draw(out)
  sets=[(t,'云霄模板'),(g,'谷雨定稿'),(w,'云裳')] if kind=='walk' else [(load('template_battle.png').crop((0,64,192,128)),'云霄wait'),(b.crop((0,64,192,128)),'谷雨wait'),(i,'云裳wait')]
  for col,(im,label) in enumerate(sets):
   dd.text((col*256+5,5),label,font=F,fill='white');size=48 if kind=='walk' else 64
   for row in range(4 if kind=='walk' else 1):put(out,im.crop((k*size,row*size,(k+1)*size,(row+1)*size)),(col*256,45+row*192),4)
  frames.append(out)
 frames[0].save(P/('四向对照.gif' if kind=='walk' else '待机对照.gif'),save_all=True,append_images=frames[1:],duration=200,loop=0)
