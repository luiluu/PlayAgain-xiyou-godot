from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
P=Path(__file__).resolve().parent;E=P.parents[3]/'03_再刷重制_Godot/01_Godot工程'
F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',23)
def load(p):return Image.open(p).convert('RGBA')
def paste(out,im,xy,scale=1):
 im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST);out.paste(im,xy,im)
w=load(P/'Guyu_Walk.png');i=load(P/'Guyu_Wait.png');t=load(P/'template_walk.png');s=load(P/'template_battle.png');g=load(E/'content/gojo/$Codex_Gojo_Walk.png')
out=Image.new('RGB',(1080,1220),'#30343c');d=ImageDraw.Draw(out)
for x,title in [(12,'参考：头像＋旧图'),(370,'原版模板：云霄'),(730,'试作：原生＋2倍')]:d.text((x,15),title,font=F,fill='white')
paste(out,load(E/'modes/xiyou/generated/img/faces/Guyu_Face.png'),(20,60),2)
paste(out,load(E/'modes/xiyou/generated/img/characters/$Guyu.png'),(20,365),2)
paste(out,t,(390,65),2);paste(out,s.crop((0,64,192,128)),(370,485))
paste(out,w,(740,60));paste(out,i,(740,265));paste(out,w,(740,370),2);paste(out,i,(730,780))
d.text((20,850),'同原生尺寸比较（未按显示高度拉齐）',font=F,fill='white')
paste(out,g,(30,895));paste(out,w,(225,895));paste(out,t,(420,895))
d.text((30,1100),'五条悟',font=F,fill='white');d.text((225,1100),'谷雨试作',font=F,fill='white');d.text((420,1100),'云霄',font=F,fill='white')
d.text((20,1155),'未通过：左向腿区重复 0.962；未接入游戏',font=F,fill='#ffb080')
out.save(P/'手机总览.png')
frames=[]
for k in [0,1,2,1]:
 a=Image.new('RGB',(720,820),'#30343c');dd=ImageDraw.Draw(a)
 for col,(sheet,label) in enumerate([(t,'模板'),(w,'谷雨试作'),(g,'五条悟')]):
  dd.text((col*240+15,5),label,font=F,fill='white')
  for row in range(4):paste(a,sheet.crop((k*48,row*48,k*48+48,row*48+48)),(col*240+20,40+row*192),4)
 frames.append(a)
frames[0].save(P/'四向对照.gif',save_all=True,append_images=frames[1:],duration=200,loop=0)
frames=[]
for k in [0,1,2,1]:
 a=Image.new('RGB',(512,290),'#30343c');dd=ImageDraw.Draw(a)
 dd.text((10,0),'模板 wait',font=F,fill='white');dd.text((266,0),'谷雨 wait',font=F,fill='white')
 paste(a,s.crop((k*64,64,k*64+64,128)),(0,30),4);paste(a,i.crop((k*64,0,k*64+64,64)),(256,30),4);frames.append(a)
frames[0].save(P/'待机对照.gif',save_all=True,append_images=frames[1:],duration=250,loop=0)
