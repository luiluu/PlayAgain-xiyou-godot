#!/usr/bin/env python3
"""T213 骨骼工程自检：失败退出码 1。
1. 部件图按层序叠回 == 1_0（逐像素）
2. rest 姿势烘焙 == 1_0（逐像素，验证取样器在不动时无损）
3. 每个姿势成品：340×280、alpha 只 0/255、底锚 bbox 下沿 217（与 1_0 相同，PIL 下沿为开区间）、无孤立点、小透明洞不多于原图
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from bake import load_rig, export_parts, bake, bake_final, stats

R, src = load_rig(HERE / 'rig.json')
fail = 0
def ok(cond, msg):
    global fail
    print(('通过 ' if cond else '失败 ') + msg); fail |= not cond

tmp = HERE / 'parts'
names = export_parts(R, src, tmp)
comp = np.zeros_like(src)
for n in names:
    a = np.array(Image.open(tmp / n).convert('RGBA')); m = a[..., 3] > 0; comp[m] = a[m]
d = int((comp != src).any(-1).sum()); ok(d == 0, f'部件拼回 1_0：差 {d} 像素')
d = int((bake(R, src, R['poses']['rest']) != src).any(-1).sum()); ok(d == 0, f'rest 烘焙 1_0：差 {d} 像素')
W, H = R['canvas']['size']; foot = R['canvas']['foot_y']
for name in R['poses']:
    if name == 'rest': continue
    out, info = bake_final(R, src, name)
    al = set(np.unique(out[..., 3]).tolist())
    ok(out.shape[:2] == (H, W), f'{name} 尺寸 {out.shape[1]}×{out.shape[0]}')
    ok(al <= {0, 255}, f'{name} alpha 只 0/255：{sorted(al)}')
    ok(info['bbox'][3] == foot == Image.fromarray(src).getbbox()[3], f'{name} 底锚 bbox 下沿 {info["bbox"][3]}（1_0 同为 {foot}）')
    c = info['清理后']; s0 = info['原图1_0']
    ok(c['孤立点'] == 0, f'{name} 孤立点 {c["孤立点"]}')
    ok(c['小透明洞(≤4像素)'] <= s0['小透明洞(≤4像素)'], f'{name} 小透明洞 {c["小透明洞(≤4像素)"]}（1_0 本身 {s0["小透明洞(≤4像素)"]}）')
sys.exit(1 if fail else 0)
