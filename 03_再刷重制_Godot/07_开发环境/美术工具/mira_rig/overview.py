# 21 张原尺寸总览（原稿｜新），每格左原稿右新烘焙；1_0 两边都是待机原图。用法：python overview.py <输出.png> [--from-dir 已烘焙目录]
import sys, re
sys.path.insert(0, '.')
from pathlib import Path
from PIL import Image, ImageDraw
from bake import load_rig, bake_final
R, src = load_rig('rig.json')
names = ['1_0'] + sorted([n for n in R['poses'] if n not in ('rest',)], key=lambda s: tuple(map(int, s.split('_'))))
c = (0, 40, 300, 222); cw, ch = c[2] - c[0], c[3] - c[1]
cells = []
for n in names:
    o = Image.open(f"{R['_dir']}/{R['fx_dir']}/UserSV_MiraDragon{n}.png").convert('RGBA')
    new = Image.fromarray(src) if n == '1_0' else Image.fromarray(bake_final(R, src, n)[0])
    W = Image.new('RGBA', (cw * 2 + 6, ch + 14), (46, 42, 52, 255))
    W.alpha_composite(o.crop(c), (0, 14)); W.alpha_composite(new.crop(c), (cw + 6, 14))
    d = ImageDraw.Draw(W); d.text((2, 1), f'{n} orig', fill=(230, 230, 230, 255)); d.text((cw + 8, 1), f'{n} new', fill=(230, 230, 230, 255))
    cells.append(W)
cols = 3; rows = (len(cells) + cols - 1) // cols
S = Image.new('RGBA', (cols * (cells[0].width + 10), rows * (cells[0].height + 6)), (30, 28, 34, 255))
for i, w in enumerate(cells): S.paste(w, ((i % cols) * (w.width + 10), (i // cols) * (w.height + 6)))
S.save(sys.argv[1]); print(len(cells), S.size)
