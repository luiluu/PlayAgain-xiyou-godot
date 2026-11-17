from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
P=Path(__file__).resolve().parent;rs=json.loads((P/'reference_measurements.json').read_text());F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',18)
o=Image.new('RGB',(1180,1370),'#30343c');d=ImageDraw.Draw(o);d.text((15,10),'参考量表：头高/头宽/身高/肩宽/髻高（原生像素）',font=F,fill='white');d.text((15,42),'头宽排除饰物/侧辫/垂发/髻；遮挡肩点不量；髻高单列不比较',font=F,fill='#ffcc88')
for j,key in enumerate(['Guyu','Gojo','Yunxiao']):
 x=15+j*390;d.text((x,80),key,font=F,fill='white')
 for i,r in enumerate(r for r in rs if r['character']==key):
  vals='/'.join(('遮挡' if r[k] is None else str(r[k])) for k in ['head_height','head_width','height','shoulder_width','bun_height']);d.text((x,115+i*78),f"{r['direction']} #{r['frame']}: {vals}",font=F,fill='white')
o.save(P/'参考量表.png')

o=Image.new('RGB',(1230,2070),'#30343c');d=ImageDraw.Draw(o)
for col,(key,walk,wait) in enumerate([('Guyu','Guyu_Walk.png','Guyu_Battle.png'),('Gojo','Gojo_Walk.png','Gojo_wait.png'),('Yunxiao','template_walk.png','template_battle.png')]):
 d.text((col*410+10,5),key,font=F,fill='white')
 for row,n in enumerate(['down','left','right','up','wait']):
  r=next(r for r in rs if r['character']==key and r['direction']==n and r['frame']==1);size=48 if row<4 else 64
  im=Image.open(P/(walk if row<4 else wait)).convert('RGBA')
  if row<4:c=im.crop((48,row*48,96,row*48+48))
  elif key=='Gojo':c=im.crop((64,0,128,64))
  else:c=im.crop((64,64,128,128))
  x=col*410;y=40+row*400;c=c.resize((size*6,size*6),Image.Resampling.NEAREST);o.paste(c,(x,y),c)
  for yy,color in [(r['crown_y'],'yellow'),(r['chin_or_neck_y'],'red')]:
   if yy is not None:d.line((x,y+yy*6,x+size*6,y+yy*6),fill=color)
  hy=r['crown_y']+8;d.line((x+r['head_left']*6,y+hy*6,x+r['head_right']*6,y+hy*6),fill='#88ccff',width=2)
  if r['shoulder_segment']:
   a,b,c,e=r['shoulder_segment'];d.line((x+a*6,y+b*6,x+c*6,y+e*6),fill='cyan',width=2)
o.save(P/'参考标点.png')
