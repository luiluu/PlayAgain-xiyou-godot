from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
SRC=ROOT/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img'
FONT='/System/Library/Fonts/Hiragino Sans GB.ttc'
def rgba(p):
    im=Image.open(p).convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
    return im
def fit(im,h):
    im=im.crop(im.getbbox())
    return im.resize((round(im.width*h/im.height),h),Image.Resampling.NEAREST)
def strip_old(name):
    out=Image.new('RGBA',(576,64))
    for col in range(9):
        motion=[0,6,12][col//3]
        im=rgba(SRC/f'sv_actors/sv/Codex_Tusu_{name}/Codex_Tusu_{name}{motion}_{col%3}.png')
        im=fit(im,48)
        out.paste(im,(col*64+(64-im.width)//2,60-im.height),im)
    return out
raw=rgba(P/'raw_tusu_row0.png')
spans=[];start=None
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
human.save(P/'tusu_row0_64.png')
weapons=rgba(P/'raw_weapons_row0.png'); news=[]
# Measured whitespace bands; equal quarters would clip the sword tips.
bands=[0,210,420,625,weapons.height]
for row,h in enumerate([32,48,44,50]):
    out=Image.new('RGBA',(576,64))
    for col in range(9):
        im=weapons.crop((round(col*weapons.width/9),bands[row],round((col+1)*weapons.width/9),bands[row+1]))
        im=fit(im,h)
        out.paste(im,(col*64+(64-im.width)//2,60-h),im)
    out.save(P/(['book','hammer','shield','sword'][row]+'_row0_64.png'));news.append(out)
board=Image.new('RGB',(1560,1520),'#252b38');d=ImageDraw.Draw(board)
def text(x,y,s,size=23,c='#e8e7e1'):d.text((x,y),s,font=ImageFont.truetype(FONT,size),fill=c)
def paste(im,x,y,scale=2):
    im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST);board.paste(im,(x,y),im)
text(30,20,'T161 屠苏 · 人形／四武具首行联合审稿',32)
text(30,72,'ActorNote：最终兵器｜五种形态、兵势支援；化武交给同伴，行动转为兵势。',22)
text(30,106,'技能先耗自身魔法；不足由持有者按3倍支付；双方不足变回人形。',22)
text(30,140,'本单：人形＋书／锤／盾／剑；弓保留旧图。先审造型，获准后制作整套。',22)
paste(rgba(P/'Codex_Tusu_Face_reference.png'),1230,25,1)
text(1200,180,'头像：身份参考',19)
text(30,200,'原版人形首行（仅动作对照）',22)
paste(strip_old('v1'),300,225)
text(30,360,'新：银灰长发／黑白衣装',22);paste(human,300,380)
for r,(name,cn) in enumerate(zip(['book','hammer','shield','sword'],['书','锤','盾','剑'])):
    y=530+r*205
    text(30,y,cn+' · 原版动作',22);paste(strip_old(name+'_v1'),300,y-8,1)
    text(30,y+68,cn+' · 新首行',22);paste(news[r],300,y+60,2)
bow=rgba(SRC/'sv_actors/sv/Codex_Tusu_bow_v1/Codex_Tusu_bow_v10_0.png')
paste(bow,1250,1310,1);text(1220,1450,'旧弓：未重绘',22)
text(30,1390,'新图风格：谷雨 v2＋五条悟定稿；旧战斗图不作风格参考。',21)
text(30,1426,'按64格缩略审稿，最近邻缩放；未压11色。武具为悬浮形态，无人物行走要求。',21)
text(30,1462,'待审：银发长度、黑白衣装比例、武具统一装饰；尚未接入游戏或通过专项验收。',21)
board.save(P/'屠苏_联合首行对照板.png')
print('wrote board and 45 preview cells; no runtime assets changed')
