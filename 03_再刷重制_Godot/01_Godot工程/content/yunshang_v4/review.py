from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
P=Path(__file__).resolve().parent
F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',22)
def load(p):return Image.open(p).convert('RGBA')
def put(o,im,xy,s=1):
 im=im.resize((im.width*s,im.height*s),Image.Resampling.NEAREST);o.paste(im,xy,im)
w=load(P/'Yunshang_Walk.png');i=load(P/'Yunshang_Wait.png');t=load(P/'template_walk.png');b=load(P/'template_battle.png');g=load(P.parent/'gojo/$Codex_Gojo_Walk.png');v=load(P/'Guyu_Walk.png')
o=Image.new('RGB',(1080,1260),'#30343c');d=ImageDraw.Draw(o)
for x,label in [(12,'参考：头像＋现行u2'),(370,'模板：原版云霄'),(730,'新试作：原生＋2倍')]:d.text((x,15),label,font=F,fill='white')
put(o,load(P.parent/'yunshang_v2/Yunshang_Face_u1.png').crop((0,0,144,144)),(20,55),2)
put(o,load(P.parent/'yunshang_v2/u2/$Yunshang_u2.png'),(20,370),2)
put(o,t,(390,55),2);put(o,b.crop((0,64,192,128)),(370,480))
put(o,w,(740,55));put(o,i,(740,260));put(o,w,(740,360),2);put(o,i,(730,760))
d.text((20,855),'同原生尺寸并排：谷雨定稿｜云裳新稿｜云霄模板',font=F,fill='white')
for x,im,label in [(20,v,'谷雨定稿'),(230,w,'云裳新稿'),(440,t,'云霄模板')]:put(o,im,(x,905));d.text((x,1105),label,font=F,fill='white')
d.text((20,1160),'第一段 WIP：待形象审样；未接入，未启动Godot',font=F,fill='#ffcc88');d.text((20,1200),'自动结果见 check 报告；通过不等于人工美术验收',font=F,fill='white');o.save(P/'手机总览.png')
for kind in ['walk','wait']:
 frames=[]
 for k in [0,1,2,1]:
  o=Image.new('RGB',(768,830 if kind=='walk' else 300),'#30343c');d=ImageDraw.Draw(o)
  for col,(im,label) in enumerate([(t if kind=='walk' else b.crop((0,64,192,128)),'模板'),(w if kind=='walk' else i,'云裳'),(g if kind=='walk' else load(P.parent/'gojo/Codex_Gojo_SV.png').crop((0,64,192,128)),'五条悟')]):
   d.text((col*256+10,5),label,font=F,fill='white');size=48 if kind=='walk' else 64
   for row in range(4 if kind=='walk' else 1):put(o,im.crop((k*size,row*size,(k+1)*size,(row+1)*size)),(col*256,35+row*192),4)
  frames.append(o)
 frames[0].save(P/('四向对照.gif' if kind=='walk' else '待机对照.gif'),save_all=True,append_images=frames[1:],duration=200,loop=0)

o=Image.new('RGB',(800,300),'#30343c');d=ImageDraw.Draw(o)
for x,im,label in [(10,v,'谷雨定稿'),(270,w,'云裳新稿'),(530,t,'云霄模板')]:
 d.text((x,10),label,font=F,fill='white');put(o,im.crop((48,0,96,48)),(x,50),4)
o.save(P/'单帧4倍对比.png')
