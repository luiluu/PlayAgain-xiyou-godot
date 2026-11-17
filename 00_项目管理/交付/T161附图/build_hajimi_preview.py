from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
SRC=ROOT/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img'
def rgba(p):
    im=Image.open(p).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
    return im
raw=rgba(P/'raw_hajimi_row0.png');spans=[];start=None
for x in range(raw.width+1):
    active=x<raw.width and raw.getchannel('A').crop((x,0,x+1,raw.height)).getbbox() is not None
    if active and start is None:start=x
    if not active and start is not None:spans.append((start,x));start=None
spans=[(a,b) for a,b in spans if b-a>30]
assert len(spans)==9,spans
human=Image.new('RGBA',(576,64))
for col,(a,b) in enumerate(spans):
    im=raw.crop((a,0,b,raw.height));im=im.crop(im.getbbox())
    im=im.resize((round(im.width*42/im.height),42),Image.Resampling.NEAREST)
    assert im.width<=62,(col,im.width)
    human.paste(im,(col*64+(64-im.width)//2,60-im.height),im)
human.save(P/'hajimi_row0_64.png')
old=rgba(SRC/'sv_actors/CatSwordSaint_SV_v3.png').resize((576,384),Image.Resampling.NEAREST)
board=Image.new('RGB',(1560,1100),'#252b38');d=ImageDraw.Draw(board)
def text(x,y,s,size=23,c='#e8e7e1'):d.text((x,y),s,font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',size),fill=c)
def paste(im,x,y,scale=2):
    im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST);board.paste(im,(x,y),im)
text(30,20,'T161 哈基米 · 双剑小猫首行审稿',32)
text(30,72,'ActorNote：双爪持剑，轻盈连携，凝聚至圣喵心。',23)
text(30,108,'35级以小猫进阶石进阶，额外获得一次行动。',22)
text(30,144,'在被动页挑战守誓巨龙，独自完成进阶试炼。',22)
paste(rgba(P/'CatSwordSaint_Face_crop.png'),1260,25,1);text(1230,180,'头像：身份参考',19)
text(30,220,'原版首行 · 仅动作对照',23);paste(old.crop((0,0,576,64)),300,250)
text(30,405,'新首行 · 64格预览',23);paste(human,300,440)
text(30,610,'原版完整动作总览',24);paste(old,30,660,1)
text(660,660,'造型依据',25)
text(660,710,'橘色虎斑、圆猫脸、粉色耳结、银甲与白披风。',22)
text(660,750,'双爪各持一剑，保留猫耳、短爪与尾巴。',22)
text(660,810,'风格仅参考：谷雨 v2 成品、五条悟定稿。',22)
text(660,850,'原版云霄动作模板转猫体态；旧战斗图只作对照。',22)
text(660,910,'九格待机／突刺／逃跑；64格内主体高42像素预览。',21)
text(660,950,'最近邻缩放、未压11色；双剑辨识与猫体态待审。',21)
text(660,990,'尚未做整套，未接入游戏，未完成专项／实机验收。',21)
board.save(P/'哈基米_首行对照板.png')
board.thumbnail((1100,1100));board.save(P/'哈基米_首行缩略.png')
print('wrote Hajimi nine-cell preview and board; no runtime changes')
