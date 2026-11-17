from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
P=Path(__file__).resolve().parent
F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',22)
w=Image.open(P/'Yunshang_Walk.png').convert('RGBA');g=Image.open(P/'Guyu_Walk.png').convert('RGBA')
def put(o,c,xy,s=8):
 c=c.resize((c.width*s,c.height*s),Image.Resampling.NEAREST);o.paste(c,xy,c)
o=Image.new('RGB',(1182,880),'#30343c');d=ImageDraw.Draw(o)
d.text((15,10),'正面三帧动作8倍：上谷雨｜下云裳（原生，不拉齐）',font=F,fill='white')
for j in range(3):
 put(o,g.crop((j*48,0,j*48+48,48)),(j*394,60))
 put(o,w.crop((j*48,0,j*48+48,48)),(j*394,475))
o.save(P/'正面三帧动作8倍.png')
o=Image.new('RGB',(810,860),'#30343c');d=ImageDraw.Draw(o);d.text((10,10),'左向｜右向镜像 头部8倍',font=F,fill='white')
for j in range(3):
 put(o,w.crop((j*48,48,j*48+48,78)),(5,55+j*265))
 put(o,ImageOps.mirror(w.crop((j*48,96,j*48+48,126))),(410,55+j*265))
o.save(P/'左右头部8倍.png')
