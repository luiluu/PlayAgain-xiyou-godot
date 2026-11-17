from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
P=Path(__file__).resolve().parent;rs=json.loads((P/'reference_measurements.json').read_text());F=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',18)
o=Image.new('RGB',(1180,1370),'#30343c');d=ImageDraw.Draw(o);d.text((15,10),'参考量表：头高/头宽/身高/肩宽/髻高（原生像素）',font=F,fill='white');d.text((15,42),'头宽含可见头发轮廓；肩点手标；背向颈线推定，非解剖自动识别',font=F,fill='#ffcc88')
for j,key in enumerate(['Guyu','Gojo','Yunxiao']):
 x=15+j*390;d.text((x,80),key,font=F,fill='white')
 for i,r in enumerate(r for r in rs if r['character']==key):
  vals='/'.join(str(r[k]) for k in ['head_height','head_width','height','shoulder_width','bun_height']);d.text((x,115+i*78),f"{r['direction']} #{r['frame']}: {vals}",font=F,fill='white')
o.save(P/'参考量表.png')
