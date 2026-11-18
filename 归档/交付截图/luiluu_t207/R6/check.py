from PIL import Image,ImageDraw
from pathlib import Path
import json
out=Path(__file__).parent
src=Path('03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon')
a=Image.open(src/'UserSV_MiraDragon14_0.png').convert('RGBA'); ref=Image.open(src/'UserSV_MiraDragon1_0.png').convert('RGBA'); raw=Image.open(out/'generated-raw.png').convert('RGBA')
raw.putalpha(raw.getchannel('A').point(lambda v:255 if v>=128 else 0))
bbox=raw.getbbox(); cut=raw.crop(bbox); scale=199/cut.width
cut=cut.resize((199,round(cut.height*scale)),Image.Resampling.NEAREST)
b=Image.new('RGBA',a.size); b.alpha_composite(cut,(61,217-cut.height)); b.save(out/'trial-14_0.png')
board=Image.new('RGB',(1020,300),(40,43,49)); d=ImageDraw.Draw(board)
for i,(im,s) in enumerate(((a,'Original 14_0'),(b,'R6 trial'),(ref,'Reference 1_0'))): board.paste(im,(i*340,20),im); d.text((i*340+5,3),s,fill='white')
board.save(out/'comparison-native.png')
heads=Image.new('RGB',(240,130),(40,43,49)); d=ImageDraw.Draw(heads)
for i,im in enumerate((a,b)):
 c=im.crop((50,105,130,220)); heads.paste(c,(i*120,15),c); d.text((i*120,0),'Original' if i==0 else 'R6',fill='white')
heads.save(out/'heads-native.png'); heads.resize((960,520),Image.Resampling.NEAREST).save(out/'heads-inspection.png')
metrics={'original_bbox':a.getbbox(),'generated_binary_bbox':bbox,'uniform_scale':scale,'trial_bbox':b.getbbox(),'bottom_anchor_original':216,'bottom_anchor_trial':216,'bbox_pass':False,'note':'Uniform width alignment gives height 132 vs original 128, exceeds 2px tolerance. No silhouette warping or filling performed.'}
(out/'metrics.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps(metrics))
