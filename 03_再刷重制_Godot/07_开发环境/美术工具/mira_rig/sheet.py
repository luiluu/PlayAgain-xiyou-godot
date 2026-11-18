# 批量出 原稿｜新 并排（调姿势用）：在本目录运行 python sheet.py <输出.png> 0_1 0_2 ...  （姿势读 rig.json，原稿读 fx_dir 里的旧图备份）
import sys,json
sys.path.insert(0,'.')
from PIL import Image, ImageDraw
import numpy as np
from bake import load_rig, bake_final
R,src=load_rig('rig.json')
rows=[]
for n in sys.argv[2:]:
    o=Image.open(f"{R['_dir']}/{R['fx_dir']}/UserSV_MiraDragon{n}.png").convert('RGBA')
    a,info=bake_final(R,src,n); new=Image.fromarray(a)
    print(n,info['清理后'],info['bbox'])
    c=(0,40,300,222); W=Image.new('RGBA',(610,190),(46,42,52,255)); W.alpha_composite(o.crop(c),(0,8)); W.alpha_composite(new.crop(c),(305,8))
    ImageDraw.Draw(W).text((2,0),n,fill=(255,255,255,255)); rows.append(W)
k=2 if len(rows)<=3 else 1
S=Image.new('RGBA',(610*k,190*len(rows)*k))
for i,r in enumerate(rows): S.paste(r.resize((610*k,190*k),Image.NEAREST),(0,190*k*i))
S.save(sys.argv[1])
