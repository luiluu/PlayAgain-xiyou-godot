from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
P=Path(__file__).resolve().parent;F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',19)
def load(n):return Image.open(P/n).convert('RGBA')
def put(o,im,xy,s=1):
 im=im.resize((im.width*s,im.height*s),Image.Resampling.NEAREST);o.paste(im,xy,im)
w=load('Yunshang_Walk.png');wait=load('Yunshang_Wait.png');g=load('Guyu_Walk.png');j=load('Gojo_Walk.png');t=load('template_walk.png');b=load('template_battle.png');records=json.loads((P/'alignment.json').read_text())['frames']
o=Image.new('RGB',(1080,1400),'#30343c');d=ImageDraw.Draw(o)
d.text((15,10),'第三轮首段：仅指定头像参考；比例差值见量表',font=F,fill='white')
a=Image.open(P.parent/'yunshang_v2/Yunshang_Face_u1.png').crop((0,0,144,144)).convert('RGBA');put(o,a,(15,45),2)
d.text((330,50),'谷雨定稿｜五条悟｜云裳新稿｜云霄',font=F,fill='white')
for x,im in [(330,g),(510,j),(690,w),(870,t)]:put(o,im,(x,90))
d.text((15,355),'同原生尺寸并排（不按显示高度拉齐）',font=F,fill='white')
for x,im,label in [(15,g,'谷雨'),(265,j,'五条悟'),(515,w,'云裳'),(765,t,'云霄')]:put(o,im,(x,390),1);d.text((x,590),label,font=F,fill='white')
d.text((15,635),'四倍单帧：谷雨定稿｜五条悟｜云裳新稿｜云霄模板',font=F,fill='white')
for x,im in [(15,g),(280,j),(545,w),(810,t)]:put(o,im.crop((48,0,96,48)),(x,680),4)
d.text((15,900),'云裳四向2倍＋待机原生',font=F,fill='white');put(o,w,(15,935),2);put(o,wait,(350,940));put(o,b.crop((0,64,192,128)),(350,1050))
d.text((15,1350),'WIP：不接入；自动检查不能代替比例与美术验收',font=F,fill='#ffcc88');o.save(P/'手机总览.png');o.crop((0,635,1080,890)).save(P/'单帧4倍对比.png')
keys=['head_height','head_width','height','shoulder_width','bun_height'];o=Image.new('RGB',(1300,1130),'#30343c');d=ImageDraw.Draw(o);d.text((15,10),'新稿量表：头高/头宽/全身高/肩宽/髻高；括号内为相对谷雨差值',font=F,fill='white');d.text((15,42),'髻高另算，头高不含髻；红色为差值超过1px；颈线肩点含人工推定',font=F,fill='#ffcc88')
for idx,r in enumerate(records):
 y=85+idx*65;vals='/'.join(str(r['measured'][k]) for k in keys);diff='/'.join(f"{r['delta_vs_guyu'].get(k,0):+}" for k in keys) if r['guyu_target'] else '战斗暂无谷雨对应量测'
 d.text((15,y),f"{r['direction']} #{r['frame']}  {vals}   ({diff})",font=F,fill='#ff9999' if r['difference_over_1px'] else 'white')
 if r['difference_over_1px']:d.text((700,y),str(r['difference_over_1px']),font=F,fill='#ff9999')
o.save(P/'新稿量表.png')
# Native landmarks overlaid at 6x, the same actual resized image coordinates.
o=Image.new('RGB',(900,1300),'#30343c');d=ImageDraw.Draw(o)
for row in range(4):
 for col in range(3):
  r=records[row*3+col];m=r['output_landmarks'];x=col*300;y=row*320;put(o,w.crop((col*48,row*48,col*48+48,row*48+48)),(x,y),6)
  for yy,co in [(m['crown_y'],'yellow'),(m['neck_y'],'red')]:d.line((x,y+yy*6,x+288,y+yy*6),fill=co,width=1)
  d.line((x+m['shoulder_left']*6,y+m['shoulder_y']*6,x+m['shoulder_right']*6,y+m['shoulder_y']*6),fill='cyan',width=2)
o.save(P/'新稿标点.png')
for kind in ['walk','wait']:
 frames=[]
 for k in [0,1,2,1]:
  o=Image.new('RGB',(768,830 if kind=='walk' else 300),'#30343c');d=ImageDraw.Draw(o)
  for col,(im,label) in enumerate([(t if kind=='walk' else b.crop((0,64,192,128)),'云霄'),(w if kind=='walk' else wait,'云裳'),(g if kind=='walk' else j,'谷雨' if kind=='walk' else '仅看云霄云裳')]):
   if kind=='wait' and col==2:continue
   d.text((col*256+10,5),label,font=F,fill='white');size=48 if kind=='walk' else 64
   for row in range(4 if kind=='walk' else 1):put(o,im.crop((k*size,row*size,(k+1)*size,(row+1)*size)),(col*256,35+row*192),4)
  frames.append(o)
 frames[0].save(P/('四向对照.gif' if kind=='walk' else '待机对照.gif'),save_all=True,append_images=frames[1:],duration=200,loop=0)

# Keep a readable first screen and a complete phone sheet with both measurement tables.
first=Image.open(P/'手机总览.png');first.save(P/'手机首屏.png')
ref=Image.open(P/'参考量表.png');tab=Image.open(P/'新稿量表.png')
ref=ref.resize((1080,round(ref.height*1080/ref.width)),Image.Resampling.LANCZOS)
tab=tab.resize((1080,round(tab.height*1080/tab.width)),Image.Resampling.LANCZOS)
page=Image.new('RGB',(1080,first.height+ref.height+tab.height),'#30343c');page.paste(first,(0,0));page.paste(ref,(0,first.height));page.paste(tab,(0,first.height+ref.height));page.save(P/'手机总览.png')
