from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import json
P=Path(__file__).resolve().parent
w=Image.open(P/'Yunshang_Walk.png').convert('RGBA');g=Image.open(P/'Guyu_Walk.png').convert('RGBA')
F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',20)
def put(o,c,xy):
 c=c.resize((c.width*8,c.height*8),Image.Resampling.NEAREST);o.paste(c,xy,c)
o=Image.new('RGB',(820,860),'#30343c');d=ImageDraw.Draw(o)
d.text((15,10),'左向｜右向镜像 8倍（饰物侧别另置）',font=F,fill='white')
for j in range(3):
 put(o,w.crop((j*48,48,j*48+48,78)),(10,55+j*265))
 put(o,ImageOps.mirror(w.crop((j*48,96,j*48+48,126))),(420,55+j*265))
o.save(P/'左右头部8倍.png')
o=Image.new('RGB',(820,330),'#30343c');d=ImageDraw.Draw(o);d.text((15,10),'云裳｜谷雨 正面头部8倍（原尺寸，不拉齐）',font=F,fill='white')
put(o,w.crop((48,0,96,32)),(10,55));put(o,g.crop((48,0,96,32)),(420,55));o.save(P/'正面头部8倍.png')
o=Image.new('RGB',(1170,1120),'#30343c');d=ImageDraw.Draw(o)
for row,n in enumerate(['正面','左向','右向','背面']):
 d.text((10,row*280+5),n+' 三帧头部8倍',font=F,fill='white')
 for j in range(3):put(o,w.crop((j*48,row*48,j*48+48,row*48+30)),(j*390,row*280+35))
o.save(P/'十二帧头部8倍.png')
# Exact face rectangles omit ornament; pixel equality is evidence, not aesthetic approval.
stats={}
for row,n in [(0,'down'),(1,'left'),(2,'right')]:
 alignment=json.loads((P/'alignment.json').read_text())['frames']
 cut=next(r for r in alignment if r['direction']==('left' if n=='right' else n) and r['frame']==1)['output_landmarks']['neck_y']+1
 crops=[w.crop((j*48,row*48,j*48+48,row*48+cut)).tobytes() for j in range(3)]
 stats[n+'_three_heads_identical']=len(set(crops))==1
stats['side_face_mirror_identical']=all(w.crop((j*48+17,48+11,j*48+28,48+26)).tobytes()==ImageOps.mirror(w.crop((j*48+20,96+11,j*48+31,96+26))).tobytes() for j in range(3))
(P/'head_equality.json').write_text(json.dumps(stats,indent=2))
