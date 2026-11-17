from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
SRC=ROOT/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img/sv_actors/sv'
def rgba(p):
 im=Image.open(p).convert('RGBA');im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0));return im
raw=rgba(P/'raw_weapons_gold_fresh.png');bands=[0,193,413,609,raw.height]
board=Image.new('RGB',(1560,1480),'#252b38');d=ImageDraw.Draw(board)
def text(x,y,s,size=23):d.text((x,y),s,font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',size),fill='#e8e7e1')
def paste(im,x,y):
 im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST);board.paste(im,(x,y),im)
text(30,20,'T161 屠苏四武具 · 原版尺寸＋橙金光审稿',32)
text(30,80,'Kyo：四武具缩回原版外框，加回橙金光；化武状态须一眼可辨。',23)
text(30,120,'改提示词从头生成；只用头像＋谷雨 v2／五条悟参考，未引用首稿武具。',22)
text(30,160,'下方原版与新图均为原版128格缩为64格后放大2倍；逐格外框尺寸相同。',22)
records=[]
for r,(name,cn) in enumerate(zip(['book','hammer','shield','sword'],['书','锤','盾','剑'])):
 old=Image.new('RGBA',(576,64));new=Image.new('RGBA',(576,64))
 for c in range(9):
  m=[0,6,12][c//3];ref=rgba(SRC/f'Codex_Tusu_{name}_v1/Codex_Tusu_{name}_v1{m}_{c%3}.png').resize((64,64),Image.Resampling.NEAREST)
  old.paste(ref,(c*64,0),ref);bb=ref.getbbox()
  q=raw.crop((round(c*raw.width/9),bands[r],round((c+1)*raw.width/9),bands[r+1]));q=q.crop(q.getbbox())
  q=q.resize((bb[2]-bb[0],bb[3]-bb[1]),Image.Resampling.NEAREST)
  new.paste(q,(c*64+bb[0],bb[1]),q);records.append((name,c,bb))
 new.save(P/(name+'_gold_row0_64.png'))
 y=225+r*285;text(30,y,cn+' · 原版',23);paste(old,300,y)
 text(30,y+135,cn+' · 改后',23);paste(new,300,y+135)
text(30,1380,'四件均为悬浮武具；弓本单保留旧图。当前仅首行审稿，非整套验收。',22)
text(30,1420,'外框按原版对位，光效包含在框内；未改游戏代码、未接入运行资源。',22)
board.save(P/'屠苏四武具_改后对照板.png');board.thumbnail((1100,1100));board.save(P/'屠苏四武具_改后缩略.png')
import json
(P/'weapons_gold_alignment.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
print('36 weapon cells aligned to exact original bounding boxes')
