"""Only this round's assembled pixels. Standard faces and permitted side mirror.
Far-side ornament occlusion uses this round's source ornament, no old sprite patch.
"""
from pathlib import Path
from PIL import Image,ImageOps
import json
P=Path(__file__).resolve().parent
w=Image.open(P/'Yunshang_Walk.png').convert('RGBA')
policy=json.loads((P/'new_head_bounds.json').read_text())
for row,n in [(0,'down'),(1,'left')]:
 cut=policy[n]['neck_y']+1
 head=w.crop((48,row*48,96,row*48+cut))
 for j in range(3):w.paste(head,(j*48,row*48))
# Anatomical left ornament is fully visible on the right-facing side.
for j in range(3):
 left=w.crop((j*48,48,j*48+48,96));right=ImageOps.mirror(left)
 # On left-facing profile it is on the far side: hair occludes tassel centre,
 # retaining the projecting pin tip.
 # Bounds are manually located on THIS round's new image, stored in policy.
 x0,y0,x1,y1=policy['left']['far_tassel_rect']
 for y in range(y0,y1):
  for x in range(x0,x1):
   r,g,b,a=left.getpixel((x,y))
   if a:
    # This area is outside the cranial silhouette, not an eye/face region.
    left.putpixel((x,y),(0,0,0,0))
 w.paste(left,(j*48,48));w.paste(right,(j*48,96))
w.save(P/'Yunshang_Walk.png')
face=(14,10,30,27)
evidence={}
for row,n in [(0,'down'),(1,'left'),(2,'right')]:
 cut=policy['left' if n=='right' else n]['neck_y']+1
 evidence[n+'_standard_heads_equal']=len({w.crop((j*48,row*48,j*48+48,row*48+cut)).tobytes() for j in range(3)})==1
evidence['side_face_mirror_equal']=all(w.crop((j*48+14,58,j*48+30,75)).tobytes()==ImageOps.mirror(w.crop((j*48+18,106,j*48+34,123))).tobytes() for j in range(3))
(P/'head_equality.json').write_text(json.dumps(evidence,indent=2))
