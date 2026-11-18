#!/usr/bin/env python3
"""米拉黑龙骨骼烘焙（T213 试做）。只依赖 Pillow＋numpy；离线工具，不进 Godot 工程。

做法：待机图 1_0 按 rig.json 的多边形切成部件（labels）→ 每层按骨骼蒙皮（rigid／radial／chain）
→ 对每个目标像素反解回原图坐标（牛顿迭代）→ 在 Scale2x×3（8 倍）放大后的部件图上取最近像素。
只取原图已有的颜色，alpha 只 0/255，不糊（RotSprite 同类做法）。

用法：
  python bake.py rig.json 14_0 out/14_0.png        # 烘焙一个姿势（含清理与自查数字）
  python bake.py rig.json --parts parts/           # 导出部件图（含补画）
  python check.py                                  # 断言：部件拼回＝1_0、rest 烘焙＝1_0、成品格式
"""
import json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
K = 8  # Scale2x 三次 = 8 倍

def load_rig(path):
    R = json.load(open(path, encoding='utf-8')); R['_dir'] = str(Path(path).resolve().parent)
    src = Image.open((Path(path).parent / R['source']).resolve()).convert('RGBA')
    return R, np.array(src)

def label_map(R, src):
    h, w = src.shape[:2]
    L = np.full((h, w), 'body', dtype=object)
    for n, poly in R['labels'][::-1]:
        m = Image.new('L', (w, h), 0)
        ImageDraw.Draw(m).polygon([tuple(p) for p in poly], fill=1)
        L[np.array(m) > 0] = n
    for rule in R.get('relabel', []):
        L = relabel(L, src, rule)
    return L

def relabel(L, src, rule):
    """把 from 部件里、颜色落在 rgb 范围内、且与 to 部件 4 连通的像素改归 to（翼膜从脖子边上剥出来）。"""
    lo = np.array(rule['rgb_min']); hi = np.array(rule['rgb_max'])
    c = src[..., :3].astype(int)
    cand = (L == rule['from']) & (src[..., 3] > 0) & np.all((c >= lo) & (c <= hi), -1)
    grow = (L == rule['to']) & (src[..., 3] > 0)
    h, w = L.shape
    stack = list(zip(*np.nonzero(grow)))
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            Y, X = y + dy, x + dx
            if 0 <= Y < h and 0 <= X < w and cand[Y, X]:
                cand[Y, X] = False; L[Y, X] = rule['to']; stack.append((Y, X))
    return L

def scale2x(a):
    """EPX/Scale2x，按整像素 RGBA 比较。"""
    h, w = a.shape[:2]
    k = np.ascontiguousarray(a).view(np.uint32).reshape(h, w)
    P = np.pad(k, 1, mode='edge')
    A = P[:-2, 1:-1]; B = P[1:-1, 2:]; C = P[1:-1, :-2]; D = P[2:, 1:-1]; E = k
    o1 = np.where((C == A) & (C != D) & (A != B), A, E)
    o2 = np.where((A == B) & (A != C) & (B != D), B, E)
    o3 = np.where((D == C) & (D != B) & (C != A), C, E)
    o4 = np.where((B == D) & (B != A) & (D != C), D, E)
    out = np.empty((h * 2, w * 2), np.uint32)
    out[0::2, 0::2] = o1; out[0::2, 1::2] = o2; out[1::2, 0::2] = o3; out[1::2, 1::2] = o4
    return out.view(np.uint8).reshape(h * 2, w * 2, 4)

def upscale(a, k=K):
    while k > 1:
        a = scale2x(a); k //= 2
    return a

# ---------------------------------------------------------------- 骨骼
def mat(rot_deg, pivot, offset=(0, 0)):
    c, s = math.cos(math.radians(rot_deg)), math.sin(math.radians(rot_deg))
    px, py = pivot; ox, oy = offset
    # p' = R (p - pivot) + pivot + offset   （y 向下，正角＝屏幕顺时针）
    return np.array([[c, -s, px + ox - c * px + s * py], [s, c, py + oy - s * px - c * py], [0, 0, 1.0]])

def world(R, pose):
    """各骨骼的世界矩阵。姿势可写 rot／offset／scale；scale 只压本骨骼自己，
    子骨骼不继承压扁，只跟着挂点（pivot）被压后的位置走。"""
    B = R['bones']; full = {}; rigid = {}
    def get(n):
        if n in full: return full[n], rigid[n]
        b = B[n]; p = pose.get(n, {})
        M = mat(p.get('rot', 0), b['pivot'], p.get('offset', (0, 0)))
        sx, sy = p.get('scale', (1, 1))
        px, py = b['pivot']
        S = np.array([[sx, 0, px - sx * px], [0, sy, py - sy * py], [0, 0, 1.0]])
        if b.get('parent'):
            PF, PR = get(b['parent'])
            q = np.array([px, py, 1.0]); d = PF @ q - PR @ q  # 挂点被父骨压扁后的位移
            T = np.array([[1, 0, d[0]], [0, 1, d[1]], [0, 0, 1.0]])
            Rm = T @ PR @ M
        else:
            Rm = M
        full[n] = Rm @ S; rigid[n] = Rm
        return full[n], rigid[n]
    for n in B: get(n)
    out = {n: full[n] for n in B}
    out['_local'] = {n: mat(pose.get(n, {}).get('rot', 0), B[n]['pivot']) for n in B}  # 只含本骨骼自身转角
    out['_cut'] = R.get('head_cut') if pose.get('_head_rigid') else None  # T213 R1：整颗头刚性挂 head 骨
    return out

def smooth(t):
    t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

def weights(layer, px, py, cut=None):
    """返回 {bone: 权重数组}，px/py 为原图连续坐标。
    cut（rig.json 的 head_cut，姿势写 _head_rigid 才启用）：切线以上整颗头（吻、下颚、腮、角）权重全给 head，
    切线以下 blend 像素内渐变回链式权重。原链式权重的分界横穿脸部（吻部一半挂 n3），头一相对脖子转，脸就被折成钩。"""
    kind = layer['skin']
    if kind == 'rigid':
        return {layer['bone']: np.ones_like(px)}
    if kind == 'radial':
        d = np.hypot(px - layer['center'][0], py - layer['center'][1])
        w = smooth((d - layer['r0']) / (layer['r1'] - layer['r0']))
        return {layer['bone']: w, layer['parent']: 1 - w}
    if kind == 'chain':
        J = np.array(layer['joints'], float); bones = layer['bones']; b = layer['blend']
        # 折线弧长参数 t
        best_d = np.full(px.shape, np.inf); best_t = np.zeros(px.shape)
        seglen = np.hypot(*(J[1:] - J[:-1]).T); acc = np.concatenate([[0], np.cumsum(seglen)])
        n = len(J) - 1
        for i in range(n):
            a, c = J[i], J[i + 1]; v = c - a; L2 = v @ v
            u = ((px - a[0]) * v[0] + (py - a[1]) * v[1]) / L2
            lo = -np.inf if i == 0 else 0; hi = np.inf if i == n - 1 else 1
            uc = np.clip(u, lo, hi)
            d = np.hypot(px - (a[0] + uc * v[0]), py - (a[1] + uc * v[1]))
            sel = d < best_d; best_d[sel] = d[sel]; best_t[sel] = acc[i] + uc[sel] * seglen[i]
        # bones[0] 在 joint0 之前，bones[k] 在 joint k-1..k 之间，最后一根延伸到底
        W = {}
        S = [smooth((best_t - (jt - b)) / (2 * b)) for jt in acc]
        for k in range(len(bones)):
            lo = S[k - 1] if k >= 1 else np.ones(px.shape)
            hi = S[k] if k < len(S) else np.zeros(px.shape)
            W[bones[k]] = W.get(bones[k], 0) + lo - hi
        if cut and 'head' in W:
            xs, ys = np.array(cut['line'], float).T
            yb = np.interp(px, xs, ys)
            s = smooth((yb + cut['blend'] - py) / cut['blend'])
            wh = np.maximum(W['head'], s); rest = 1 - W['head']
            f = np.where(rest > 1e-9, (1 - wh) / np.where(rest > 1e-9, rest, 1), 0)
            for k in W:
                W[k] = wh if k == 'head' else W[k] * f
        return W
    raise ValueError(kind)

def forward(layer, Mw, px, py):
    W = weights(layer, px, py, Mw.get('_cut'))
    if layer.get('local'):  # 先绕自身铰点转（如下颚开合），再按 rest 位置的链式权重跟脖子/头走，和头部像素严丝合缝
        Lm = Mw['_local'][layer['local']]
        px, py = Lm[0, 0] * px + Lm[0, 1] * py + Lm[0, 2], Lm[1, 0] * px + Lm[1, 1] * py + Lm[1, 2]
    X = np.zeros_like(px); Y = np.zeros_like(py)
    for n, w in W.items():
        M = Mw[n]; X += w * (M[0, 0] * px + M[0, 1] * py + M[0, 2]); Y += w * (M[1, 0] * px + M[1, 1] * py + M[1, 2])
    return X, Y

def render_layer(layer, up, Mw, shape, iters=15):
    h, w = shape[:2]
    qy, qx = np.mgrid[0:h, 0:w].astype(float); qx += 0.5; qy += 0.5
    out = np.zeros((h, w, 4), np.uint8); done = np.zeros((h, w), bool)
    bones = list(weights(layer, np.zeros(1), np.zeros(1)).keys())
    for n in bones[::-1]:
        Mi = np.linalg.inv(Mw[n] @ Mw['_local'][layer['local']]) if layer.get('local') else np.linalg.inv(Mw[n])
        px = Mi[0, 0] * qx + Mi[0, 1] * qy + Mi[0, 2]; py = Mi[1, 0] * qx + Mi[1, 1] * qy + Mi[1, 2]
        for _ in range(iters):  # 牛顿迭代解 F(p)=q
            fx, fy = forward(layer, Mw, px, py)
            ax, ay = forward(layer, Mw, px + 1e-3, py); bx, by = forward(layer, Mw, px, py + 1e-3)
            j11 = (ax - fx) / 1e-3; j21 = (ay - fy) / 1e-3; j12 = (bx - fx) / 1e-3; j22 = (by - fy) / 1e-3
            det = j11 * j22 - j12 * j21; det = np.where(np.abs(det) < 1e-6, 1e-6, det)
            rx = qx - fx; ry = qy - fy
            dx = (j22 * rx - j12 * ry) / det; dy = (-j21 * rx + j11 * ry) / det
            st = np.hypot(dx, dy); f = np.minimum(1, 4 / np.maximum(st, 1e-9))
            px += dx * f; py += dy * f
        fx, fy = forward(layer, Mw, px, py)
        ok = (np.hypot(fx - qx, fy - qy) < 0.02) & ~done
        ix = np.floor(px * K).astype(int); iy = np.floor(py * K).astype(int)
        inb = ok & (ix >= 0) & (iy >= 0) & (ix < w * K) & (iy < h * K)
        s = up[np.clip(iy, 0, h * K - 1), np.clip(ix, 0, w * K - 1)]
        hit = inb & (s[..., 3] > 0)
        out[hit] = s[hit]; done |= hit
    return out

def layer_src(src, L, parts, fill=None):
    a = src.copy(); a[~np.isin(L, parts)] = 0
    if fill is not None:  # 补画：只补原来透明（被挡/切走）的位置
        m = (a[..., 3] == 0) & (fill[..., 3] > 0); a[m] = fill[m]
    a[a[..., 3] == 0] = 0
    return a

def comp(dst, s):
    m = s[..., 3] > 0; dst[m] = s[m]; return dst

def make_fill(src, L, layer):
    """补画被挡区：多边形内、本层原本没有像素的位置，从 offsets 指向的同层纹理平移复制；
    rim=顶边描一道轮廓色＋亮边（颜色取自 rim_sample 处的顶边）。"""
    f = layer.get('fill')
    if not f: return None
    h, w = src.shape[:2]
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).polygon([tuple(p) for p in f['poly']], fill=1)
    m = (np.array(m) > 0) & (src[..., 3] > 0)  # 只补原图被别的部件盖住的位置，静止拼回不变
    own = np.isin(L, f.get('texture_parts', layer['parts'])) & (src[..., 3] > 0)
    out = np.zeros_like(src); todo = m & ~(np.isin(L, layer['parts']) & (src[..., 3] > 0))
    ys, xs = np.nonzero(todo)
    for y, x in zip(ys, xs):
        for dx, dy in f.get('offsets', []):
            X, Y = x + dx, y + dy
            if 0 <= X < w and 0 <= Y < h and own[Y, X]:
                out[y, x] = src[Y, X]; break
    if f.get('mouth'):  # 口腔：按到上颚线（line）的距离分层上色；颜色全取自 1_0 色板
        mo = f['mouth']; (ax, ay), (bx, by) = mo['line']; L2 = math.hypot(bx - ax, by - ay)
        nx, ny = -(by - ay) / L2, (bx - ax) / L2  # 线的下侧法向（y 向下）
        if ny < 0: nx, ny = -nx, -ny
        mm = todo & np.isin(L, mo.get('over_parts', ['jaw']))  # 只补被下颚盖住的位置（翼膜等别层的像素不碰）
        for y, x in zip(*np.nonzero(mm)):
            d = (x + 0.5 - ax) * nx + (y + 0.5 - ay) * ny
            d = max(d, 0)  # 线以上（下颚轮廓压进上颚的那一两行）按口腔最深色补
            fang = {fx: fl for fx, fl in mo.get('fangs', [])}  # 上獠牙：列 x（rest 坐标）→ 长度
            edge = any(not (0 <= y + dy < h and 0 <= x + dx < w and mm[y + dy, x + dx]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge and x < mo.get('outline_x', 0):  # 吻端一侧外缘描轮廓，张嘴时口腔不会直接漏到外面
                c = mo.get('outline', [0, 0, 0])
            elif x in fang and d < fang[x]:
                c = mo['teeth']
            else:
                band = mo['bands']; c = band[min(int(d / mo.get('band_w', 2)), len(band) - 1)]
            out[y, x] = list(c) + [255]
    if f.get('rim'):
        sx, sy = f['rim']['sample']  # 顶边取色点：从 sy 往下找第一个不透明像素
        col = [src[y, sx] for y in range(sy, h) if src[y, sx, 3] > 0][:f['rim'].get('n', 2)]
        filled = m | (np.isin(L, layer['parts']) & (src[..., 3] > 0))
        top = filled & ~np.roll(filled, 1, 0)
        for y, x in zip(*np.nonzero(top & m)):
            for i, c in enumerate(col):
                if y + i < h and m[y + i, x]: out[y + i, x] = c
    return out

def fx_overlay(R, pose, shape):
    """从原稿同号帧抠特效（多边形内、颜色在范围内的像素），叠在最上层。"""
    out = np.zeros(shape, np.uint8)
    for fx in pose.get('_fx', []):
        im = np.array(Image.open(Path(R['_dir']) / R['fx_dir'] / fx['from']).convert('RGBA'))
        h, w = shape[:2]
        m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).polygon([tuple(p) for p in fx['poly']], fill=1)
        m = (np.array(m) > 0) & (im[..., 3] > 0)
        if 'rgb_min' in fx:
            c = im[..., :3].astype(int)
            m &= np.all((c >= fx['rgb_min']) & (c <= fx['rgb_max']), -1)
        dx, dy = fx.get('offset', (0, 0))  # 特效整体平移，对到新姿势的嘴／爪
        ys, xs = np.nonzero(m); Y = ys + dy; X = xs + dx
        ok = (Y >= 0) & (Y < h) & (X >= 0) & (X < w)
        out[Y[ok], X[ok]] = im[ys[ok], xs[ok]]
    return out

def mouth_transplant(R, src, mo, shape):
    """张嘴（T213 R1 第 2 轮，Kyo「这个嘴有问题」后改用派单第 3 条）：从原稿同号帧只抠嘴（上獠牙、口腔、舌头、
    下颚连下牙，不含吻部上沿、角和头顶），颜色换成 1_0 色板里最近的色，按两点对齐（原稿上颚线→1_0 上颚线，
    只转不缩放，原稿和 1_0 是同一比例）贴到 rest 坐标；只留 1_0 上颚线以下的像素，吻部本身不动。"""
    h, w = shape[:2]; a = np.zeros(shape, np.uint8)
    o = np.array(Image.open(Path(R['_dir']) / R['fx_dir'] / mo['from']).convert('RGBA'))
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).polygon([tuple(p) for p in mo['poly']], fill=1); om = (np.array(m) > 0) & (o[..., 3] > 0)
    (sx0, sy0), (sx1, sy1) = mo['src_line']; (dx0, dy0), (dx1, dy1) = mo['dst_line']
    th = math.atan2(dy1 - dy0, dx1 - dx0) - math.atan2(sy1 - sy0, sx1 - sx0); c, s_ = math.cos(th), math.sin(th)
    pal = np.unique(src[src[..., 3] > 0][:, :3], axis=0).astype(int)
    ex, ey = dx1 - dx0, dy1 - dy0
    for y in range(h):
        for x in range(w):
            px, py = x + 0.5 - dx0, y + 0.5 - dy0
            if ex * py - ey * px <= 0: continue  # 1_0 上颚线以上（吻部）不贴
            X = int(math.floor(c * px + s_ * py + sx0)); Y = int(math.floor(-s_ * px + c * py + sy0))  # 反解回原稿
            if 0 <= X < w and 0 <= Y < h and om[Y, X]:
                col = o[Y, X, :3].astype(int); k = int(((pal - col) ** 2).sum(1).argmin())
                a[y, x, :3] = pal[k]; a[y, x, 3] = 255
    return a

def jaw_open_rig(R, src, L, pose):
    """张嘴帧：原 jaw 多边形把吻尖也切了进去，归还头颈链；jaw_open.poly（吻部下面的暗下巴）拿掉，由原稿的嘴补上。
    不张嘴的帧不走这里，烘焙结果不变。"""
    jo = R.get('jaw_open')
    if not jo or not pose.get('_mouth'): return R, L
    h, w = src.shape[:2]; L = L.copy()
    L[L == 'jaw'] = 'chain'
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).polygon([tuple(p) for p in jo['poly']], fill=1)
    L[(np.array(m) > 0) & (L == 'chain')] = '_cut'
    return R, L

def bake(R, src, pose, fills=None):
    L = label_map(R, src); R, L = jaw_open_rig(R, src, L, pose); Mw = world(R, pose)
    out = np.zeros_like(src)
    for layer in R['layers']:
        if 'wedge' in layer:  # 张嘴（T213 R1）：原稿的嘴贴在头颈链上面，跟头走
            if not pose.get('_mouth'): continue
            a = mouth_transplant(R, src, pose['_mouth'], src.shape)
            out = comp(out, render_layer(layer, upscale(a), Mw, src.shape)); continue
        if layer['name'] == 'jaw' and pose.get('_mouth'): continue  # 张嘴帧不用旧下颚
        if 'pixels' in layer:  # 补画小件（如下牙）：只在 when 骨骼转动时画，rest 姿势不出现
            if not pose.get(layer['when'], {}).get('rot'): continue
            a = np.zeros_like(src)
            for x, y, c in layer['pixels']: a[y, x] = list(c) + [255]
            out = comp(out, render_layer(layer, upscale(a), Mw, src.shape)); continue
        fl = (fills or {}).get(layer['name'])
        mo = layer.get('fill', {}).get('mouth')
        if mo and pose.get(mo.get('off_when', '')):  # 贴原稿嘴的帧（_mouth）不再整块补红
            fl = make_fill(src, L, {**layer, 'fill': {k: v for k, v in layer['fill'].items() if k != 'mouth'}})
        if fl is None: fl = make_fill(src, L, layer)
        a = layer_src(src, L, layer['parts'], fl)
        up = upscale(a)
        out = comp(out, render_layer(layer, up, Mw, src.shape))
    return comp(out, fx_overlay(R, pose, src.shape))

N8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
N4 = [(0, -1), (-1, 0), (1, 0), (0, 1)]

def _nb(op, offs):
    P = np.pad(op, 1); h, w = op.shape
    return sum(P[1 + dy:1 + dy + h, 1 + dx:1 + dx + w].astype(int) for dx, dy in offs)

def small_holes(op, maxsize=4):
    """被不透明像素四面围住、面积 ≤maxsize 的透明连通块（不连到画布外的空白）。"""
    from collections import deque
    h, w = op.shape; seen = np.zeros_like(op); out = []
    for y0, x0 in zip(*np.nonzero(~op)):
        if seen[y0, x0]: continue
        q = deque([(y0, x0)]); seen[y0, x0] = True; comp = []; edge = False
        while q:
            y, x = q.popleft(); comp.append((y, x))
            if y in (0, h - 1) or x in (0, w - 1): edge = True
            for dx, dy in N4:
                Y, X = y + dy, x + dx
                if 0 <= Y < h and 0 <= X < w and not op[Y, X] and not seen[Y, X]:
                    seen[Y, X] = True; q.append((Y, X))
        if not edge and len(comp) <= maxsize: out.append(comp)
    return out

def stats(a):
    op = a[..., 3] > 0
    return {'孤立点': int((op & (_nb(op, N8) == 0)).sum()),
            '小透明洞(≤4像素)': len(small_holes(op)),
            '半透明像素': int(((a[..., 3] > 0) & (a[..., 3] < 255)).sum())}

def cleanup(a, ref_holes=()):
    """去孤立点；补烘焙新出的小透明洞（原图本来就有的洞保留）。颜色取四邻里最多的。"""
    a = a.copy(); op = a[..., 3] > 0
    a[op & (_nb(op, N8) == 0)] = 0
    op = a[..., 3] > 0
    keep = {frozenset(c) for c in ref_holes}
    for comp in small_holes(op):
        if frozenset(comp) in keep: continue
        for y, x in comp:
            cols = [tuple(a[y + dy, x + dx]) for dx, dy in N4 if a[y + dy, x + dx, 3] > 0]
            if cols: a[y, x] = max(set(cols), key=cols.count)
    return a

def export_parts(R, src, outdir):
    L = label_map(R, src); outdir = Path(outdir); outdir.mkdir(parents=True, exist_ok=True)
    names = []
    for layer in [l for l in R['layers'] if 'pixels' not in l and 'wedge' not in l]:  # 补画小件（下牙、口腔楔形）不属于 1_0 拆件
        i = len(names)
        a = layer_src(src, L, layer['parts'], make_fill(src, L, layer))
        fn = f"{i}_{layer['name']}.png"; Image.fromarray(a).save(outdir / fn); names.append(fn)
    return names

def bake_final(R, src, pose_name):
    """烘焙＋清理（去孤立点、补烘焙新出的小洞），返回 (图, 自查数字)。"""
    raw = bake(R, src, R['poses'][pose_name])
    out = cleanup(raw, small_holes(src[..., 3] > 0))
    info = {'原图1_0': stats(src), '烘焙原样': stats(raw), '清理后': stats(out),
            'bbox': Image.fromarray(out).getbbox()}
    return out, info

if __name__ == '__main__':
    R, src = load_rig(sys.argv[1])
    if sys.argv[2] == '--parts':
        print(export_parts(R, src, sys.argv[3])); sys.exit(0)
    out, info = bake_final(R, src, sys.argv[2])
    Path(sys.argv[3]).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out).save(sys.argv[3])
    for k, v in info.items(): print(k, v)
