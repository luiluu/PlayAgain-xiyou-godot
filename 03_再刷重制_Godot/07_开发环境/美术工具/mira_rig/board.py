#!/usr/bin/env python3
"""出对比板：原稿同号帧｜新烘焙｜1_0 原尺寸并排，另出头部 1:1 并排；各附一张 ×3 放大辅助看。
用法：python board.py 14_0      （读 out/UserSV_MiraDragon14_0.png，写 out/对比板_14_0*.png）"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from bake import load_rig, world

BG = (46, 42, 52, 255)  # 偏暗的战斗底色
name = sys.argv[1]
R, src = load_rig(HERE / 'rig.json')
sv = (HERE / R['source']).resolve().parent
orig = Image.open(Path(R['_dir']) / R['fx_dir'] / f'UserSV_MiraDragon{name}.png').convert('RGBA')  # 原稿取旧图备份（工程图已替换）
new = Image.open(HERE / 'out' / f'UserSV_MiraDragon{name}.png').convert('RGBA')
idle = Image.fromarray(src)

def row(ims, labels, pad=8):
    w = sum(i.width for i in ims) + pad * (len(ims) + 1); h = max(i.height for i in ims) + 22
    b = Image.new('RGBA', (w, h), BG); d = ImageDraw.Draw(b); x = pad
    for im, t in zip(ims, labels):
        b.alpha_composite(im, (x, 18)); d.text((x, 3), t, fill=(230, 230, 230, 255)); x += im.width + pad
    return b

full = row([orig, new, idle], [f'orig {name} (pose ref only)', f'new {name} (rig bake)', 'idle 1_0 (source)'])
full.save(HERE / 'out' / f'对比板_{name}.png')
full.resize((full.width * 3, full.height * 3), Image.NEAREST).save(HERE / 'out' / f'对比板_{name}_x3.png')

# 头部：rest 下头的框（含角）经 head 骨骼映射到新图
x0, y0, x1, y1 = 84, 52, 162, 142
M = world(R, R['poses'][name])['head']
pts = np.array([[x, y, 1] for x in (x0, x1) for y in (y0, y1)]) @ M.T
bx0, by0 = np.floor(pts[:, :2].min(0)).astype(int) - 6; bx1, by1 = np.ceil(pts[:, :2].max(0)).astype(int) + 6
head = row([idle.crop((x0, y0, x1, y1)), new.crop((max(bx0, 0), max(by0, 0), bx1, by1))], ['idle head', f'new {name} head'])
head.save(HERE / 'out' / f'头部_{name}.png')
head.resize((head.width * 3, head.height * 3), Image.NEAREST).save(HERE / 'out' / f'头部_{name}_x3.png')
print('ok')
