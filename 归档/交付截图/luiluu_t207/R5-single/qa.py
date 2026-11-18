from PIL import Image,ImageDraw
from pathlib import Path
from collections import deque
import json
p=Path(__file__).parent; base=Path('03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon'); a=Image.open(base/'UserSV_MiraDragon14_0.png').convert('RGBA'); n=Image.open(p/'trial-14_0.png').convert('RGBA')
def holes(im):
 w,h=im.size; alpha=im.getchannel('A'); unseen={(x,y) for y in range(h) for x in range(w) if alpha.getpixel((x,y))==0}; enclosed=[]
 while unseen:
  first=unseen.pop();q=[first];comp=[];edge=False
  while q:
   x,y=q.pop();comp.append((x,y));edge|=x==0 or y==0 or x==w-1 or y==h-1
   for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    if (xx,yy) in unseen:unseen.remove((xx,yy));q.append((xx,yy))
  if not edge:enclosed.append({'pixels':len(comp),'box':[min(x for x,y in comp),min(y for x,y in comp),max(x for x,y in comp)+1,max(y for x,y in comp)+1]})
 return sorted(enclosed,key=lambda c:-c['pixels'])
metrics={'original_bbox':a.getbbox(),'trial_bbox':n.getbbox(),'bbox_width_change_percent':0,'bbox_height_change_percent':0,'scale':199/789,'alpha_values':sorted(set(n.getchannel('A').getdata())),'head_measurement':'manual anatomical bounding boxes excluding horns; approximate, not segmentation ground truth','head_original_box':[68,155,109,205],'head_trial_box':[61,151,114,204],'head_width_original':41,'head_width_trial':53,'head_width_change_percent':(53/41-1)*100,'torso_measurement':'manual shoulder-to-ventral torso landmarks, excluding wings/feet','torso_original_y':[144,193],'torso_trial_y':[145,193],'torso_height_change_percent':(48/49-1)*100,'holes_original':holes(a),'holes_trial':holes(n)}
(p/'metrics.json').write_text(json.dumps(metrics,indent=2))
board=Image.new('RGB',(800,420),(40,40,48));d=ImageDraw.Draw(board)
for i,(im,eye,roots,label) in enumerate([(a,(79,181),[(77,172),(86,161)],'Original'),(n,(76,179),[(77,165),(88,157)],'Trial')]):
 crop=im.crop((55,115,155,215)).resize((400,400),Image.Resampling.NEAREST);board.paste(crop,(i*400,20),crop)
 d.text((i*400+8,3),label+' cyan:eye yellow:horn roots',fill='white')
 for point,col in [(eye,'cyan')]+[(r,'yellow') for r in roots]:
  x=(point[0]-55)*4+i*400;y=(point[1]-115)*4+20;d.ellipse((x-6,y-6,x+6,y+6),outline=col,width=2)
board.save(p/'head-annotated.png')
print(json.dumps(metrics,indent=2))
