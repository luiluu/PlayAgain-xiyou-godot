from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
SRC=ROOT/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img'
def rgba(p):
 im=Image.open(p).convert('RGBA');im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0));return im
def spans(im):
 out=[];start=None
 for x in range(im.width+1):
  active=x<im.width and im.getchannel('A').crop((x,0,x+1,im.height)).getbbox() is not None
  if active and start is None:start=x
  if not active and start is not None:out.append((start,x));start=None
 out=[(a,b) for a,b in out if b-a>30]
 assert len(out)==9,out
 return out
def align(im,template):
 out=Image.new('RGBA',(576,64))
 for c,(a,b) in enumerate(spans(im)):
  q=im.crop((a,0,b,im.height));q=q.crop(q.getbbox());bb=template.crop((c*64,0,c*64+64,64)).getbbox()
  h=bb[3]-bb[1];w=round(q.width*h/q.height)
  assert w<=64,(c,w)
  q=q.resize((w,h),Image.Resampling.NEAREST);out.paste(q,(c*64+round((bb[0]+bb[2]-w)/2),bb[3]-h),q)
 return out
def board(name,old,new,portrait,notes):
 out=Image.new('RGB',(1560,720),'#252b38');d=ImageDraw.Draw(out)
 def txt(x,y,s,size=23):d.text((x,y),s,font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',size),fill='#e8e7e1')
 def paste(im,x,y,scale=2):
  im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST);out.paste(im,(x,y),im)
 txt(30,20,'T161 '+name+' · 按 Kyo 意见重出首行',32)
 paste(rgba(P/portrait),1290,25,1)
 for i,n in enumerate(notes):txt(30,85+i*36,n,22)
 txt(30,235,'原版首行',23);paste(old,300,260)
 txt(30,415,'改后首行',23);paste(new,300,440)
 txt(30,615,'首行审稿；运行资源尚未接入，未标整套完成。',22)
 txt(30,655,'64格最近邻预览；原始生成图、提示词、对位脚本均留存。',21)
 out.save(P/(name+'_改后首行对照板.png'));out.thumbnail((1100,1100));out.save(P/(name+'_改后首行缩略.png'))
xold=rgba(P/'xuan_original_row0_source.png').resize((576,64),Image.Resampling.NEAREST)
xnew=align(rgba(P/'raw_xuan_float_row0.png'),xold);xnew.save(P/'xuan_float_row0_64.png')
board('璇',xold,xnew,'Codex_Xuan_Face_reference.png',[
 'Kyo：在原版基础上优化；待机悬浮是定稿，保留冰蓝飘带、亮蓝衣摆及原配色。',
 '只清晰化脸与线条、星饰和披肩；保留悬浮腿姿，不改成落地站立。',
 '生成参考：Kyo 指定原版璇＋头像＋谷雨 v2／五条悟；未用作废首稿。'])
hold=rgba(SRC/'sv_actors/CatSwordSaint_SV_v3.png').resize((576,384),Image.Resampling.NEAREST).crop((0,0,576,64))
hraw=rgba(P/'raw_hajimi_guyu_greatsword.png');hnew=Image.new('RGBA',(576,64))
# Adjacent subjects project into overlapping x ranges. Identify independent
# complete 2D silhouettes instead of clipping them at equal columns.
from collections import deque
a=bytearray(hraw.getchannel('A').tobytes());w,ht=hraw.size;components=[]
for i in range(len(a)):
 if not a[i]:continue
 a[i]=0;stack=deque([i]);pixels=[]
 while stack:
  j=stack.pop();x=j%w;y=j//w;pixels.append((x,y))
  for k in ([j-1] if x else [])+([j+1] if x<w-1 else [])+([j-w] if y else [])+([j+w] if y<ht-1 else []):
   if a[k]:a[k]=0;stack.append(k)
 if len(pixels)>1000:components.append(pixels)
assert len(components)==9,[len(c) for c in components]
components.sort(key=lambda c:min(x for x,y in c))
gref=rgba(ROOT/'03_再刷重制_Godot/01_Godot工程/content/guyu_v2/Guyu_SV_v2.png')
# In this selected raw row each blade stays below the ears and above the boots.
# Thus these y extrema measure the cat, not the sword. One scale for all nine.
body_heights=[max(y for x,y in c)-min(y for x,y in c)+1 for c in components]
uniform_scale=40/max(body_heights)
measurements=[]
for c,pixels in enumerate(components):
 xs=[x for x,y in pixels];ys=[y for x,y in pixels];x0=min(xs);y0=min(ys)
 q=Image.new('RGBA',(max(xs)-x0+1,max(ys)-y0+1));qp=q.load();hp=hraw.load()
 for x,y in pixels:qp[x-x0,y-y0]=hp[x,y]
 h=round(q.height*uniform_scale);w=round(q.width*uniform_scale)
 assert w<=62 and h<=60,(c,w,h)
 q=q.resize((w,h),Image.Resampling.NEAREST);hnew.paste(q,(c*64+(64-w)//2,60-h),q)
 bb=q.getbbox();measurements.append({'frame':c,'source_cat_height':body_heights[c],'scale':uniform_scale,'native_cat_height':bb[3]-bb[1],'native_width_with_sword':w,'baseline':60})
# Head width: longest solid alpha run in the upper 90 source pixels. This
# band includes the widest skull/cheeks but excludes the sword and shoulders.
head_widths=[]
for pixels in components:
 top=min(y for x,y in pixels); rows={}
 for x,y in pixels:
  if y<top+90:rows.setdefault(y,[]).append(x)
 best=0
 for xs in rows.values():
  xs.sort();run=1
  for a,b in zip(xs,xs[1:]):
   run=run+1 if b==a+1 else 1;best=max(best,run)
 head_widths.append(best)
# Manually read ear tip and bottom of chin on the unscaled 64px result.
# End coordinates are inclusive; chin excludes collar, paws, sword and scarf.
# These landmarks are an explicit visual annotation, not an alpha body bbox.
head_y=[(20,40),(21,41),(21,41),(22,42),(23,42),(23,42),(21,40),(20,40),(21,41)]
for i,m in enumerate(measurements):
 m.update(source_head_width=head_widths[i],
          native_head_width=round(head_widths[i]*uniform_scale),
          native_head_top=head_y[i][0],native_chin_bottom=head_y[i][1],
          native_head_height=head_y[i][1]-head_y[i][0]+1,
          height_method='manual ear-tip to chin; excludes collar')
import json
(P/'hajimi_uniform_measurements.json').write_text(json.dumps(measurements,indent=2))
# Historical failed candidate remains untouched; new accepted-metric result below.
for key in ('native_head_width','native_head_height'):
 assert max(r[key] for r in measurements)-min(r[key] for r in measurements)<=1,(key,measurements)
hnew.save(P/'hajimi_greatsword_row0_64.png')
board('哈基米',hold,hnew,'CatSwordSaint_Face_crop.png',[
 'Kyo：小猫双爪共握一把大剑；剑比身体有分量，猫与整剑都留在64格内。',
 '保留橘虎斑、粉耳结、银甲白披风与猫尾；一把剑，双爪共握同一柄。',
 '九格同一倍率；头宽／耳顶至下巴高度差≤1px，蹲姿允许身体变矮；待 Kyo 原尺寸确认。'])
print('revised floating Xuan and single-greatsword Hajimi boards written')

# Keep the approval view at exactly one source pixel per display pixel.
out=Image.new('RGB',(620,190),'#252b38');out.paste(hnew,(22,28),hnew)
d=ImageDraw.Draw(out);font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',12)
d.text((10,5),'哈基米首行 · 原尺寸 1:1 · 同一缩放倍率 40/222',font=font,fill='white')
for i,m in enumerate(measurements):
 x=22+i*64
 d.line((x+59,28+m['native_head_top'],x+59,28+m['native_chin_bottom']),fill='#33ccff')
 d.text((x,100),str(i+1)+': '+str(m['native_head_width'])+'×'+str(m['native_head_height']),font=font,fill='white')
d.text((10,130),'宽：源图头部上90px最长连续alpha段 × 统一倍率；高：原尺寸耳顶至下巴人工标点。',font=font,fill='white')
d.text((10,155),'头宽21–22px／头高20–21px；身体蹲低不再当作缩放失败。待Kyo确认。',font=font,fill='white')
out.save(P/'哈基米_统一倍率原尺寸头部对照.png')
