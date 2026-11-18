from PIL import Image,ImageDraw
from pathlib import Path
import json,shutil
out=Path(__file__).parent
root=Path('03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon')
src=Path('/Users/kyo/Library/Application Support/orca/codex-accounts/0e61034f-e344-4383-9253-d8fef01a2091/home/generated_images/01a1ef1e-c455-7a80-89e5-43ee9aa509a0/exec-80090661-d468-482a-9f42-7e6ff5ec9eef.png')
shutil.copy2(src,out/'generated-raw.png')
a=Image.open(root/'UserSV_MiraDragon14_0.png').convert('RGBA'); ref=Image.open(root/'UserSV_MiraDragon1_0.png').convert('RGBA'); g=Image.open(src).convert('RGBA')
g.putalpha(g.getchannel('A').point(lambda x:255 if x>=128 else 0)); box=g.getbbox(); factor=199/(box[2]-box[0]); crop=g.crop(box); crop=crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.NEAREST)
n=Image.new('RGBA',a.size); n.paste(crop,(61,217-crop.height))
# Nearest color in the complete reference palette; no per-frame quantization.
colors=list(set((r,g,b) for r,g,b,aa in ref.getdata() if aa))
def tree(cs,depth=0):
 if not cs:return None
 axis=depth%3;cs.sort(key=lambda c:c[axis]);i=len(cs)//2
 return cs[i],axis,tree(cs[:i],depth+1),tree(cs[i+1:],depth+1)
t=tree(colors)
def nearest(q,node,best=(10**9,None)):
 if not node:return best
 c,k,l,r=node;d=sum((q[i]-c[i])**2 for i in range(3))
 if d<best[0]:best=(d,c)
 delta=q[k]-c[k];first,other=(l,r) if delta<0 else (r,l)
 best=nearest(q,first,best)
 if delta*delta<best[0]:best=nearest(q,other,best)
 return best
cache={};data=[]
for r,g,b,aa in n.getdata():
 if not aa:data.append((0,0,0,0));continue
 c=(r,g,b)
 if c not in cache:cache[c]=nearest(c,t)[1]
 data.append((*cache[c],255))
n.putdata(data);n.save(out/'trial-14_0.png')
board=Image.new('RGB',(1020,310),(39,39,48));d=ImageDraw.Draw(board)
for i,(im,label) in enumerate([(a,'Original 14_0'),(n,'C trial 14_0'),(ref,'Reference 1_0')]):board.paste(im,(i*340,25),im);d.text((i*340+10,6),label,fill='white')
board.save(out/'comparison-native.png')
print(json.dumps({'raw_size':Image.open(src).size,'raw_bbox':box,'uniform_scale':factor,'original_bbox':a.getbbox(),'trial_bbox':n.getbbox(),'reference_palette_colors':len(colors)},indent=2))
