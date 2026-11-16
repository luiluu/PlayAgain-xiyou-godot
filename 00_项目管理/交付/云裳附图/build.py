"""Offline sample processing; run with Pillow. Does not touch runtime assets."""
from PIL import Image, ImageFilter, ImageDraw
from pathlib import Path
import json, shutil
P=Path(__file__).parent
ENGINE=P.parents[2]/'03_再刷重制_Godot/01_Godot工程'
S=ENGINE/'modes/xiyou/generated/img'
G=ENGINE/'content'
RAW=Path('/Users/kyo/.codex/generated_images/01a1e678-5c12-79f3-9540-014e18747978')
(P/'raw').mkdir(exist_ok=True)
for name,src in [('battle','exec-3f532907-0206-45ed-97a6-8d5223e192fd.png'),('walk','exec-63c36f16-04ae-4828-9ac6-04d76eb02770.png'),('face','exec-b4dde7c5-e0fb-45f5-a0d8-2a08fb3ae1d3.png')]:
 if not (P/'raw'/f'{name}.png').exists():shutil.copyfile(RAW/src,P/'raw'/f'{name}.png')
report={}
def binary(a):
 a=a.convert('RGBA');a.putalpha(a.getchannel('A').point(lambda v:255 if v>=128 else 0));return a
def sheet(kind,cols,rows,cell,height):
 a=Image.open(P/'raw'/f'{kind}.png').convert('RGBA');w,h=a.size;frames=[]
 for r in range(rows):
  for c in range(cols):
   cuts=[0,350,700,1050,h] if kind=='walk' else [0,h//2,h]
   im=a.crop((c*w//cols,cuts[r],(c+1)*w//cols,cuts[r+1]));b=binary(im).getbbox();assert b
   assert b[0]>0 and b[1]>0 and b[2]<im.width and b[3]<im.height
   frames.append(im.crop(b))
 scale=height/frames[1].height
 # One shared factor, including wide attack poses, no clipped pixels.
 scale=min(scale,(cell-2)/max(f.width for f in frames))
 out=Image.new('RGBA',(cols*cell,rows*cell));result=[]
 for i,im in enumerate(frames):
  frame_scale=(60/frames[1].height if kind=='battle' and i<3 else scale)
  size=(round(im.width*frame_scale),round(im.height*frame_scale));im=im.resize((size[0]*4,size[1]*4),Image.Resampling.BOX).resize(size,Image.Resampling.BOX);im=binary(im)
  # Exact four-neighbour isolated-color cleanup, preserve shape.
  cp=im.copy()
  for y in range(1,im.height-1):
   for x in range(1,im.width-1):
    n=[im.getpixel(pt) for pt in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]]
    if n.count(n[0])==4 and im.getpixel((x,y))!=n[0]:cp.putpixel((x,y),n[0])
  im=cp;f=Image.new('RGBA',(cell,cell));f.alpha_composite(im,((cell-im.width)//2,cell-2-im.height));result.append(f);out.alpha_composite(f,((i%cols)*cell,(i//cols)*cell))
 report[kind]={'shared_scale':scale,'bounds':[f.getbbox() for f in result],'alpha':sorted(set(out.getchannel('A').getdata()))}

 if kind=='battle':report[kind]['idle_target_height']=60;report[kind]['note']='Idle group normalized to 60px; attack group uses shared_scale to fit shuttle; see README deviation.'
 out.save(P/f'{kind}_sample.png');out.resize((out.width*4,out.height*4),Image.Resampling.NEAREST).save(P/f'{kind}_sample_4x.png');return result
walk=sheet('walk',3,4,48,46);battle=sheet('battle',3,2,64,60)
sv=Image.new('RGBA',(576,384))
# MV wait motion 1 => row1 columns0..2; thrust motion6 => row0 columns3..5.
for i in range(3):sv.alpha_composite(battle[i],(i*64,64));sv.alpha_composite(battle[i+3],((i+3)*64,0))
sv.save(P/'Yunshang_SV_sample_u1.png')
shutil.copyfile(P/'walk_sample.png',P/'$Yunshang_u1.png')
f=Image.open(P/'raw/face.png').convert('RGBA').resize((144,144),Image.Resampling.BOX).filter(ImageFilter.UnsharpMask(radius=.5,percent=100,threshold=3));f.save(P/'face_144.png');fs=Image.new('RGBA',(576,288));fs.alpha_composite(f,(0,0));fs.save(P/'Yunshang_Face_u1.png')
# Comparison is a composed battle-stage preview, explicitly not a game screenshot.
a=Image.open(G/'mira/img/sv_actors/Codex_Mira_SV_u2.png').convert('RGBA');mira=a.crop((0,0,64,64))
a=Image.open(G/'gojo/Codex_Gojo_SV.png').convert('RGBA');gojo=a.crop((0,0,64,64))
originals=[]
for name in ['Actor1_1.png','Actor1_2.png']:
 a=Image.open(S/'sv_actors'/name).convert('RGBA');originals.append(a.crop((0,0,a.width//9,a.height//6)))
canvas=Image.new('RGBA',(640,300),(26,35,49,255));d=ImageDraw.Draw(canvas)
d.rectangle((0,155,640,239),fill=(55,65,69));d.line((0,224,640,224),fill=(109,128,140));d.text((18,15),'YUNSHANG / ART SAMPLE - COMPOSED BATTLE PREVIEW',fill='white');d.text((18,36),'Native pixels, same 1x display scale; no engine normalization',fill=(163,188,209))
for i,(im,label) in enumerate(zip([battle[1],mira,gojo]+originals,['Yunshang u1','Mira u2','Gojo v2','Actor1_1','Actor1_2'])):
 b=im.getbbox();im=im.crop(b);x=64+i*126;canvas.alpha_composite(im,(x-im.width//2,224-im.height));d.text((x-35,237),label,fill='white')
d.text((18,279),'Review sample only / 6 SV frames / no game integration',fill=(163,188,209));canvas.convert('RGB').save(P/'battle_comparison.png');canvas.resize((1280,600),Image.Resampling.NEAREST).save(P/'battle_comparison_2x.png')
# Animated sprite inspection.
for name,frames in [('idle',battle[:3]),('attack',battle[3:]),('walk_down',walk[:3])]:
 ims=[]
 for im in frames:
  bg=Image.new('RGBA',im.size,(34,46,60,255));bg.alpha_composite(im);ims.append(bg.resize((im.width*4,im.height*4),Image.Resampling.NEAREST).convert('RGB'))
 ims[0].save(P/f'{name}.gif',save_all=True,append_images=ims[1:],duration=180,loop=0)
(P/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
