from PIL import Image, ImageDraw
from pathlib import Path
import importlib.util,json,sys
root=Path(__file__).resolve().parents[4]
p=Path(__file__).parent
spec=importlib.util.spec_from_file_location('sprite_check',root/'03_再刷重制_Godot/07_开发环境/精灵自检.py');sc=importlib.util.module_from_spec(spec);spec.loader.exec_module(sc)
base=root/'03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/sv/UserSV_MiraDragon'
name=sys.argv[1]
im=Image.open(p/(name+'-raw.png')).convert('RGBA')
# All generated frames use one fixed scale from 1382-wide generation canvas.
scale=340/1382
im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
bb=im.getbbox();target_left=min(61,339-(bb[2]-bb[0]));dx=target_left-bb[0];dy=217-bb[3]
if target_left<0:raise ValueError('Generated subject wider than canvas at shared scale')
out=Image.new('RGBA',(340,280));out.paste(im,(dx,dy));out.save(p/(name+'-native.png'))
m=sc.opaque(out); hs=sc.holes(m,340,280,1,340*280);cc=sc.components(m)
metrics={'frame':name,'fixed_scale':scale,'bbox':out.getbbox(),'alpha_levels':sorted(set(out.getchannel('A').getdata())),'components':sorted([len(c) for c in cc],reverse=True),'enclosed_holes_sizes':sorted([h[1] for h in hs]),'translation':[dx,dy]}
(p/(name+'-metrics.json')).write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics))
board=Image.new('RGB',(1020,310),(30,32,38));d=ImageDraw.Draw(board)
for x,n,src in [(0,'original',Image.open(base/('UserSV_MiraDragon'+name+'.png')).convert('RGBA')),(340,'new',out),(680,'idle 1_0',Image.open(base/'UserSV_MiraDragon1_0.png').convert('RGBA'))]:
 board.paste(src,(x,24),src);d.text((x+8,5),n,fill='white')
board.save(p/(name+'-comparison-native.png'))
