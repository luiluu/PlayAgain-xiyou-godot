from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
SRC=ROOT/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img'
def rgba(p):
    im=Image.open(p).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
    return im
def fit(im,h):
    im=im.crop(im.getbbox())
    return im.resize((round(im.width*h/im.height),h),Image.Resampling.NEAREST)
raw=rgba(P/'raw_xuan_row0.png')
spans=[]; start=None
for x in range(raw.width+1):
    active=x<raw.width and raw.getchannel('A').crop((x,0,x+1,raw.height)).getbbox() is not None
    if active and start is None:start=x
    if not active and start is not None:spans.append((start,x));start=None
spans=[(a,b) for a,b in spans if b-a>30]
assert len(spans)==9,spans
template=rgba(P/'template_row0_reference.png').resize((576,64),Image.Resampling.NEAREST)
human=Image.new('RGBA',(576,64))
for col,(a,b) in enumerate(spans):
    bb=template.crop((col*64,0,col*64+64,64)).getbbox()
    im=fit(raw.crop((a,0,b,raw.height)),bb[3]-bb[1])
    human.paste(im,(col*64+round((bb[0]+bb[2]-im.width)/2),bb[3]-im.height),im)
human.save(P/'xuan_row0_64.png')
old=Image.new('RGBA',(576,384))
for row in range(6):
    for col in range(9):
        motion=row+(col//3)*6
        im=rgba(SRC/f'sv_actors/sv/Codex_Xuan_v1/Codex_Xuan_v1{motion}_{col%3}.png')
        if im.getbbox():
            im=fit(im,48)
            old.paste(im,(col*64+(64-im.width)//2,row*64+60-im.height),im)
old.save(P/'xuan_original_motion_overview.png')
board=Image.new('RGB',(1560,1100),'#252b38');d=ImageDraw.Draw(board)
def text(x,y,s,size=23,c='#e8e7e1'):d.text((x,y),s,font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',size),fill=c)
def paste(im,x,y,scale=2):
    im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST);board.paste(im,(x,y),im)
text(30,20,'T161 璇 · 首行优化审稿',32)
text(30,72,'ActorNote：寄命星灵｜主动保护、寄星共宿。',23)
text(30,108,'前期每回合选择治疗、护盾或攻击；列星连接同伴，星影随等级扩展至60级。',22)
text(30,144,'50级第三阶可在星谱开启自动，整场锁定。',22)
paste(rgba(P/'Codex_Xuan_Face_reference.png'),1260,25,1)
text(1230,180,'头像：身份参考',19)
text(30,220,'原版首行 · 仅动作对照',23);paste(old.crop((0,0,576,64)),300,250)
text(30,405,'新首行 · 64格对位预览',23);paste(human,300,440)
text(30,610,'原版完整动作总览',24);paste(old,30,660,1)
text(660,660,'造型依据',25)
text(660,710,'黑发＋冰蓝侧发、蓝眼、星饰、深蓝金边高领衣装。',22)
text(660,750,'浅色披肩保留头像识别点，统一为清晰像素轮廓。',22)
text(660,810,'风格仅参考：谷雨 v2 成品、五条悟定稿。',22)
text(660,850,'动作模板：原版云霄首行；旧璇图仅作动作对照。',22)
text(660,910,'首行9格：待机／突刺／逃跑；原生64格后最近邻放大。',21)
text(660,950,'未压11色；造型与披肩走向待 Kyo 审。',22)
text(660,990,'尚未做整套，未接入游戏，未完成专项／实机验收。',21)
board.save(P/'璇_首行对照板.png')
board.thumbnail((1100,1100));board.save(P/'璇_首行缩略.png')
print('wrote Xuan 9-cell preview and comparison board; no runtime changes')
