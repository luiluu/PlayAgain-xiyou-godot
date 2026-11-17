"""Read-only source extraction; all output stays beside this file. Pillow required."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json, subprocess,io,hashlib,math
ROOT=Path(__file__).resolve().parents[4]; OUT=Path(__file__).resolve().parent
P=ROOT/'03_再刷重制_Godot/01_Godot工程'
SHARED=Path('/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/01_Godot工程')
BG=(35,40,48); FONT='/System/Library/Fonts/STHeiti Medium.ttc'
rows=json.loads((OUT.parent/'gpt_mira-feet/T123/idle_drift.json').read_text())['results']
names=['五条悟','米拉·人形','宿傩·人形','镜流','流萤','萨姆','伏黑甚尔','屠苏·本体登记','璇·本体登记','黄泉','云裳·旧版','饿狼·星空','饿狼·人类形态','谷雨','屠苏·书','屠苏·弓','屠苏·锤','屠苏·盾','屠苏·剑','屠苏·本体逐帧','璇·本体逐帧','饿狼·基础','宿傩·完全体','米拉·黑龙','云裳·u2待合']
manifest=[];groups=[];rawgroups=[]
def read(rel):
 p=P/rel
 if not p.exists():p=SHARED/rel
 b=p.read_bytes();return Image.open(io.BytesIO(b)).convert('RGBA'),hashlib.sha256(b).hexdigest()
def sheet(rel,row=0):
 im,sha=read(rel);c=im.width//9
 return [im.crop((k*c,row*c,(k+1)*c,(row+1)*c)) for k in range(3)],sha
def multi(rel,m=0,n=3):
 data=[read(f'{rel}/{Path(rel).name}{m}_{k}.png') for k in range(n)]
 return [x[0] for x in data],','.join(x[1] for x in data)
def tile(fs,k,size,label,sub):
 im=Image.new('RGB',size,BG);f=fs[k%len(fs)]; factor=min((size[0]-8)/f.width,(size[1]-45)/f.height)
 f=f.resize((int(f.width*factor),int(f.height*factor)),Image.Resampling.NEAREST)
 im.paste(f,((size[0]-f.width)//2,size[1]-f.height),f)
 d=ImageDraw.Draw(im);d.text((5,4),label,font=ImageFont.truetype(FONT,14),fill='white');d.text((5,23),sub,font=ImageFont.truetype(FONT,11),fill='#b9c6d4');return im
for i,r in enumerate(rows):
 rel=r['asset']; branch=None
 if i==24:
  rel='content/yunshang_v2/u2/Yunshang_SV_u2.png';branch='gpt/yunshang-v2'
  b=subprocess.check_output(['git','show',branch+':03_再刷重制_Godot/01_Godot工程/'+rel],cwd=ROOT);im=Image.open(io.BytesIO(b)).convert('RGBA');c=im.width//9
  raw=[im.crop((k*c,0,(k+1)*c,c)) for k in range(3)];sha=hashlib.sha256(b).hexdigest()
 elif rel.endswith('.png'):raw,sha=sheet(rel)
 else:raw,sha=multi(rel)
 rawgroups.append(raw)
 mode='walk';ms=100;seq=[0,1,2,1] if rel.endswith('.png') else [0,1,2];actual=raw
 if i in [7,8,19,20,13]:
  if i in [7,19]:rel='modes/xiyou/generated/img/sv_actors/sv/Codex_Tusu_v1'
  if i in [8,20]:rel='modes/xiyou/generated/img/sv_actors/sv/Codex_Xuan_v1'
  actual,sha=multi(rel,1,1);mode='wait';seq=[0];ms=100
 if i==10:
  rel='modes/xiyou/generated/img/sv_actors/sv/yunshang';actual,sha=multi(rel);seq=[0,1,2];ms=200
 if i in [11,12,21]:ms=200
 if i in [14,15,16,17,18]:ms=230 # SVspeed 14 /60, GIF rounds to centiseconds
 if i==23:
  actual,sha=multi(rel,0,4);seq=[0,1,2,3];ms=170
 groups.append([actual[k] for k in seq])
 sub='定帧·不会动' if len(seq)==1 else ('待合·取分支图' if i==24 else f'{mode} · {ms}ms')
 w,h=actual[0].size;frames=[]
 for k in seq:
  f=Image.new('RGB',(max(w*4,260),h*4+48),BG);d=ImageDraw.Draw(f);d.text((8,4),f'{i+1:02} {names[i]}',font=ImageFont.truetype(FONT,18),fill='white');d.text((8,27),sub,font=ImageFont.truetype(FONT,14),fill='#bbc9d9');z=actual[k].resize((w*4,h*4),Image.Resampling.NEAREST);f.paste(z,((f.width-z.width)//2,48),z);frames.append(f)
 filename=f'{i+1:02}.png' if len(seq)==1 else f'{i+1:02}.gif'
 if len(seq)==1:frames[0].save(OUT/filename,optimize=True)
 else:frames[0].save(OUT/filename,save_all=True,append_images=frames[1:],duration=ms,loop=0,optimize=True)
 manifest.append(dict(number=i+1,name=names[i],source=rel,branch=branch,sha256=sha,motion=mode,sequence=seq,duration_ms=ms,file=filename,native_cell=actual[0].size))
# 10ms clock preserves the different character cadences, common cycle 27.6s.
# A short 2.4s excerpt loops: per-character originals remain cadence-authoritative.
for rawview in [False,True]:
 gs=rawgroups if rawview else groups;frames=[]
 for t in range(0,2400,50):
  canvas=Image.new('RGB',(750,950),BG)
  for i,fs in enumerate(gs):
   m=manifest[i];k=(t//(100 if rawview else m['duration_ms']))%len(fs)
   sub='原素材三帧参考' if rawview else ('定帧·不会动' if len(fs)==1 else ('待合·取分支图' if i==24 else '运行时取帧'))
   canvas.paste(tile(fs,k,(150,190),f'{i+1:02} {names[i]}',sub),((i%5)*150,(i//5)*190))
  frames.append(canvas)
 # one shared palette avoids colour flicker
 pal=frames[0].quantize(colors=96)
 frames=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in frames]
 name='素材参考.gif' if rawview else '总览.gif'
 frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=True)
 if not rawview:
  # contact sheet includes three distinct source frames for human visual review
  contact=Image.new('RGB',(1200,25*150),BG)
  for i,fs in enumerate(gs):
   for k in range(min(4,len(fs))):contact.paste(tile(fs,k,(300,150),f'{i+1:02} {names[i]}',f'播放序列位置 {k}'),(k*300,i*150))
  contact.save(OUT/'取帧检查.jpg',quality=85)
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('generated',len(manifest),'groups; overview bytes',(OUT/'总览.gif').stat().st_size)
# Mobile derivative: sampled 10Hz excerpt; originals above preserve native 4x pixels.
im=Image.open(OUT/'总览.gif');mobile=[]
for k in range(0,im.n_frames,2):
 im.seek(k);mobile.append(im.convert('RGB').resize((400,506),Image.Resampling.NEAREST))
pal=mobile[0].quantize(colors=48);mobile=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in mobile]
mobile[0].save(OUT/'总览.gif',save_all=True,append_images=mobile[1:],duration=100,loop=0,optimize=True)
print('mobile overview bytes', (OUT/'总览.gif').stat().st_size)
# Draw labels at final mobile resolution so Chinese remains legible.
mobile=[]
short=['五条悟','米拉人形','宿傩人形','镜流','流萤','萨姆','甚尔','屠苏本体A','璇本体A','黄泉','云裳旧版','饿狼星空','饿狼人类','谷雨','屠苏书','屠苏弓','屠苏锤','屠苏盾','屠苏剑','屠苏本体B','璇本体B','饿狼基础','宿傩完全体','米拉黑龙','云裳u2']
for t in range(0,2400,150):
 c=Image.new('RGB',(400,550),BG)
 for i,fs in enumerate(groups):
  x,y=i%5*80,i//5*110;d=ImageDraw.Draw(c)
  d.text((x+2,y+2),f'{i+1:02} {short[i]}',font=ImageFont.truetype(FONT,9),fill='white')
  d.text((x+2,y+15),'定帧·不会动' if len(fs)==1 else '待合·取分支图' if i==24 else '待机',font=ImageFont.truetype(FONT,8),fill='#c1cfdf')
  f=fs[(t//manifest[i]['duration_ms'])%len(fs)];s=min(76/f.width,82/f.height);f=f.resize((int(f.width*s),int(f.height*s)),Image.Resampling.NEAREST);c.paste(f,(x+(80-f.width)//2,y+110-f.height),f)
 mobile.append(c)
pal=mobile[0].quantize(colors=48);mobile=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in mobile]
mobile[0].save(OUT/'总览.gif',save_all=True,append_images=mobile[1:],duration=150,loop=0,optimize=True)
print('final labelled mobile bytes',(OUT/'总览.gif').stat().st_size)
