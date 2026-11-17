"""Manual visible head-band landmarks in final native cells, not source fitting.
Bounds are visual estimates (+/-2px), not proof of the <=1px aesthetic criterion.
Gold/navy ornament and pixels below the chin are excluded; loose side hair may
remain in the band. All outliers remain unchanged for coordinator judgment.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json
P=Path(__file__).resolve().parent;R=P.parents[4];C=R/'03_再刷重制_Godot/01_Godot工程/content';im=Image.open(C/'yunshang_v9/Yunshang_SV_v9.png').convert('RGBA')
M=json.loads((P/'motions.json').read_text());A=json.loads((P/'assembly.json').read_text())['frames']
# Crown-to-chin landmarks relative to full silhouette's top, read from final
# nearest-neighbour review. Inclined/reclining poses measured in screen axes.
landmarks={'walk':[(5,29)]*3,'wait':[(6,36)]*3,'chant':[(5,29)]*3,'guard':[(5,29)]*3,'damage':[(5,26),(3,26),(5,28)],'evade':[(5,28),(3,26),(5,28)],'thrust':[(5,28)]*3,'swing':[(5,28)]*3,'missile':[(5,29)]*3,'skill':[(5,29)]*3,'spell':[(5,29)]*3,'item':[(5,28)]*3,'escape':[(5,27)]*3,'victory':[(5,29)]*3,'dying':[(5,28),(5,28),(5,27)],'abnormal':[(5,29)]*3,'sleep':[(5,26)]*3,'dead':[(5,26)]*3}
review=Image.open(P/'assembled_native.png').convert('RGB');d=ImageDraw.Draw(review);out=[]
for i,m in enumerate(M):
 for j in range(3):
  x=(i//6)*192+j*64;y=(i%6)*64;c=im.crop((x,y,x+64,y+64));bb=c.getbbox();t,b=landmarks[m][j];y0=bb[1]+t;y1=min(64,bb[1]+b)
  pts=[]
  for yy in range(y0,y1):
   for xx in range(64):
    r,g,bl,a=c.getpixel((xx,yy))
    if a and min(r,g,bl)>110 and abs(r-bl)<65:pts.append((xx,yy))
  x0=min(p[0] for p in pts);x1=max(p[0] for p in pts)+1
  out.append({'motion':m,'frame':j,'head_band_box':[x0,y0,x1,y1],'width':x1-x0,'height':y1-y0,'uncertainty_px':2})
  d.rectangle((64+j*64+x0,i*80+16+y0,64+j*64+x1-1,i*80+16+y1-1),outline=(255,170,40))
ref=out[3]
for r in out:r['delta_from_wait0']=[r['width']-ref['width'],r['height']-ref['height']];r['over_1px']=any(abs(v)>1 for v in r['delta_from_wait0'])
(P/'head_measurements.json').write_text(json.dumps({'method':__doc__,'frames':out},indent=2))
(P/'head_measurements.tsv').write_text('motion\tframe\twidth\theight\tdelta_wait0\testimated_uncertainty\n'+''.join(f"{r['motion']}\t{r['frame']}\t{r['width']}\t{r['height']}\t{r['delta_from_wait0']}\t2\n" for r in out))
review.save(P/'head_boxes_native.png')
