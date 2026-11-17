#!/usr/bin/env python3
"""精灵出图自检（T156）：小o 交样前必跑，退出码 0 才能交。只读，不改任何图。

只依赖 Pillow。阈值全在同目录 精灵自检阈值.json，改阈值要在交付单里写理由。
用法见 00_设计/角色精灵美术规范.md「交样前必跑精灵自检」。

输入格式（与 T141 一致）：
  --walk  行走图集：3 列×4 行，每格 48×48，行序 下/左/右/上（$X_Walk.png 同款）
  --idle  待机条：3 列×1 行，每格 64×64，左向，战斗常态
  --ref-battle / --ref-walk  原版战斗图（9×6）/ 行走图，用来出对照拼图和高度比
  --profile  biped（人形）或 quadruped（四足半人马）
自检只量能量化的东西；通过不等于美术通过，美术仍要人眼和核查方审。
"""
import argparse
import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
DIRS = ['down', 'left', 'right', 'up']
SIDE = ('left', 'right')
N8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
N4 = [(0, -1), (-1, 0), (1, 0), (0, 1)]


# ---------------------------------------------------------------- 读图与基本几何
def opaque(f, thr=128):
    a = f.getchannel('A')
    w, h = f.size
    return {(x, y) for y in range(h) for x in range(w) if a.getpixel((x, y)) >= thr}


def bbox_of(pts):
    if not pts:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def components(pts, nbrs=N8):
    left = set(pts)
    out = []
    while left:
        seed = left.pop()
        comp = [seed]
        q = deque([seed])
        while q:
            x, y = q.popleft()
            for dx, dy in nbrs:
                v = (x + dx, y + dy)
                if v in left:
                    left.remove(v)
                    comp.append(v)
                    q.append(v)
        out.append(comp)
    return out


def split_grid(im, cols, rows):
    if im.width % cols or im.height % rows:
        raise ValueError(f'尺寸 {im.size} 不能按 {cols}×{rows} 等分')
    w, h = im.width // cols, im.height // rows
    return [[im.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)).convert('RGBA') for c in range(cols)] for r in range(rows)]


def ref_battle_frames(path, motion):
    im = Image.open(path).convert('RGBA')
    w, h = im.width // 9, im.height // 6
    x, y = motion // 6 * 3 * w, motion % 6 * h
    return [im.crop((x + k * w, y, x + (k + 1) * w, y + h)) for k in range(3)]


def ref_walk_frames(path, index):
    im = Image.open(path).convert('RGBA')
    cols, rows = (3, 4) if index < 0 else (12, 8)
    w, h = im.width // cols, im.height // rows
    out = []
    for r in range(4):
        bx = 0 if index < 0 else index % 4 * 3 * w
        by = r * h if index < 0 else (index // 4 * 4 + r) * h
        out.append([im.crop((bx + k * w, by, bx + (k + 1) * w, by + h)) for k in range(3)])
    return out


# ---------------------------------------------------------------- 单项度量
def leg_cut(masks, frac):
    """腿区起始行：同方向三帧共用的包围盒高度按 frac 切。"""
    ys = [y for m in masks for _, y in m]
    top, bot = min(ys), max(ys) + 1
    return top + int((bot - top) * frac)


def leg_iou_max(masks, frac):
    cut = leg_cut(masks, frac)
    legs = [{p for p in m if p[1] >= cut} for m in masks]
    best = 0.0
    for a, b in ((0, 1), (0, 2), (1, 2)):
        u = len(legs[a] | legs[b])
        best = max(best, len(legs[a] & legs[b]) / u if u else 1.0)
    return round(best, 3)


def sole_band(m, rows):
    bot = max(y for _, y in m)
    return {p for p in m if p[1] > bot - rows}


def stride_span(masks, rows):
    """脚底带（最低 rows 行）横向质心，三帧间最大差。步态没动就接近 0。"""
    cs = []
    for m in masks:
        sb = sole_band(m, rows)
        cs.append(sum(x for x, _ in sb) / len(sb))
    return round(max(cs) - min(cs), 2)


def foot_components(m, rows, min_gap_px=1):
    """脚底带内的 8 连通域个数。内蹄粘连会让个数比应有的少。"""
    return len(components(sole_band(m, rows)))


def waist_metrics(m, cfg):
    """腰部：返回 (最细行占比, 上下半身横向偏移, 躯干连通域数)。"""
    box = bbox_of(m)
    x0, y0, x1, y1 = box
    h = y1 - y0
    top_cut = y0 + int(h * cfg['upper_frac'])
    mid_lo = y0 + int(h * cfg['waist_band'][0])
    mid_hi = y0 + int(h * cfg['waist_band'][1])
    rows = {}
    for x, y in m:
        rows[y] = rows.get(y, 0) + 1
    body = [rows[y] for y in range(y0, y1) if y in rows]
    body.sort()
    median = body[len(body) // 2]
    band = [rows.get(y, 0) for y in range(mid_lo, mid_hi)]
    pinch = (min(band) / median) if band and median else 1.0
    upper = [p for p in m if p[1] < top_cut]
    lower = [p for p in m if p[1] >= mid_lo]
    ux = sum(x for x, _ in upper) / len(upper)
    lx = sum(x for x, _ in lower) / len(lower)
    comps = [c for c in components(m) if len(c) >= cfg['min_part_px']]
    return round(pinch, 3), round(lx - ux, 2), len(comps)


def isolated_px(m, max_size):
    return sorted(c[0] for c in components(m) if len(c) <= max_size)


def holes(m, w, h, min_size, max_size):
    """体内被不透明像素 4 邻域完全围住的透明区（从格子边界漫灌不到的透明像素）。"""
    reach = set()
    q = deque()
    for x in range(-1, w + 1):
        for y in (-1, h):
            q.append((x, y))
            reach.add((x, y))
    for y in range(-1, h + 1):
        for x in (-1, w):
            q.append((x, y))
            reach.add((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in N4:
            v = (x + dx, y + dy)
            if -1 <= v[0] <= w and -1 <= v[1] <= h and v not in reach and v not in m:
                reach.add(v)
                q.append(v)
    inner = {(x, y) for x in range(w) for y in range(h) if (x, y) not in m and (x, y) not in reach}
    out = []
    for c in components(inner, N4):
        if min_size <= len(c) <= max_size:
            out.append((min(c), len(c)))
    return out


# ---------------------------------------------------------------- 检查主体
class Report:
    def __init__(self):
        self.items = []

    skip = ()

    def add(self, cid, level, ok, msg, value=None):
        """level：fail 或 warn。ok 为 False 时按 level 计；--skip 指定的检查项只记 skip 不计失败。"""
        if cid in self.skip and not ok:
            level, msg = 'warn', '[已 --skip，不计失败] ' + msg
            ok = True
        self.items.append({'id': cid, 'level': level, 'ok': ok, 'msg': msg, 'value': value})

    @property
    def fails(self):
        return [i for i in self.items if not i['ok'] and i['level'] == 'fail']

    @property
    def warns(self):
        return [i for i in self.items if not i['ok'] and i['level'] == 'warn']


def severity(cfg, cid):
    return cfg['severity'].get(cid, 'fail')


def check_walk(rep, cfg, prof, walk_im, name):
    ok_size = walk_im.size == tuple(cfg['walk_sheet_size'])
    rep.add('native_size', severity(cfg, 'native_size'), ok_size,
            f'行走图集尺寸 {walk_im.size}，应为 {tuple(cfg["walk_sheet_size"])}（3×4 格，每格 48×48）')
    if not ok_size:
        return None
    grid = split_grid(walk_im, 3, 4)
    alphas = {v for _, v in walk_im.getchannel('A').getcolors(256)}
    rep.add('binary_alpha', severity(cfg, 'binary_alpha'), alphas <= {0, 255},
            f'行走图集透明度只能 0/255，实际含 {sorted(alphas - {0, 255})[:6]}…' if alphas - {0, 255} else '行走图集二值透明')
    pc = cfg['profiles'][prof]
    masks = [[opaque(f) for f in row] for row in grid]
    cw, ch = grid[0][0].size
    for r, d in enumerate(DIRS):
        ms = masks[r]
        tag = f'行走-{d}'
        if not all(ms):
            rep.add('walk_empty', 'fail', False, f'{tag} 有空帧')
            continue
        boxes = [bbox_of(m) for m in ms]
        edge = [p for m in ms for p in m if p[0] in (0, cw - 1)]
        rep.add('edge_margin', severity(cfg, 'edge_margin'), not edge,
                f'{tag} 格边（左右列）有像素 {sorted(edge)[:4]}，会被裁断' if edge else f'{tag} 格边留空')
        bots = [b[3] for b in boxes]
        span = max(bots) - min(bots)
        rep.add('walk_sole_span', severity(cfg, 'walk_sole_span'), span <= cfg['walk_sole_span_max'],
                f'{tag} 三帧脚底行 {bots}，浮动 {span}px（上限 {cfg["walk_sole_span_max"]}）')
        # 步态重复：腿区 IoU
        iou = leg_iou_max(ms, pc['leg_frac'])
        lim = cfg['gait_iou'][ 'side' if d in SIDE else 'frontback']
        rep.add('gait_repeat', severity(cfg, 'gait_repeat'), iou < lim,
                f'{tag} 腿区两两最大 IoU {iou}，≥{lim} 视为步态重复（几乎没换腿）')
        # 迈步幅度：脚底带质心位移（只对侧向有意义）
        if d in SIDE:
            st = stride_span(ms, cfg['sole_rows'])
            mn = pc['stride_min_side']
            rep.add('stride', severity(cfg, 'stride'), st >= mn,
                    f'{tag} 脚底带横向位移 {st}px，低于 {mn}px 说明腿几乎没迈开')
        # 蹄/脚粘连
        want = pc['foot_components_min'][d if d in SIDE else ('front' if d == 'down' else 'back')]
        got = min(foot_components(m, cfg['sole_rows']) for m in ms)
        rep.add('foot_merge', severity(cfg, 'foot_merge'), got >= want,
                f'{tag} 脚底带最少只有 {got} 个独立落点，应 ≥{want}（{"蹄" if prof == "quadruped" else "脚"}粘连）')
        # 腰部断裂
        for k, m in enumerate(ms):
            pinch, off, ncomp = waist_metrics(m, pc['waist'])
            rep.add('waist_break', severity(cfg, 'waist_break'), pinch >= pc['waist']['pinch_min'] and ncomp <= 1,
                    f'{tag}#{k} 腰带最细行仅为躯干中位宽的 {pinch}（≥{pc["waist"]["pinch_min"]}），独立大块 {ncomp} 个，疑似上下半身断开')
        offs = [waist_metrics(m, pc['waist'])[1] for m in ms]
        spread = round(max(offs) - min(offs), 2)
        rep.add('waist_shift', severity(cfg, 'waist_shift'), spread <= pc['waist']['shift_span_max'],
                f'{tag} 上下半身水平偏移三帧 {offs}，浮动 {spread}px（上限 {pc["waist"]["shift_span_max"]}），疑似下半身按固定步距采样而错位')
        # 孤点与孔洞
        for k, m in enumerate(ms):
            iso = isolated_px(m, cfg['isolated_max_size'])
            rep.add('isolated_px', severity(cfg, 'isolated_px'), not iso,
                    f'{tag}#{k} 孤立/悬空小块 {len(iso)} 处，位置 {iso[:4]}')
            hs = holes(m, cw, ch, cfg['hole_min_size'], cfg['hole_max_size'])
            rep.add('hole', severity(cfg, 'hole'), not hs,
                    f'{tag}#{k} 体内透明孔洞 {len(hs)} 处（≥{cfg["hole_min_size"]}px，原版本身最大 4px），位置 {[h[0] for h in hs[:4]]}')
    return masks


def check_idle(rep, cfg, prof, idle_im):
    ok_size = idle_im.size == tuple(cfg['idle_sheet_size'])
    rep.add('native_size', severity(cfg, 'native_size'), ok_size,
            f'待机条尺寸 {idle_im.size}，应为 {tuple(cfg["idle_sheet_size"])}（3 帧，每帧 64×64）')
    if not ok_size:
        return
    fr = split_grid(idle_im, 3, 1)[0]
    alphas = {v for _, v in idle_im.getchannel('A').getcolors(256)}
    rep.add('binary_alpha', severity(cfg, 'binary_alpha'), alphas <= {0, 255}, '待机条二值透明' if alphas <= {0, 255} else '待机条透明度含半透明')
    ms = [opaque(f) for f in fr]
    if not all(ms):
        rep.add('idle_empty', 'fail', False, '待机有空帧')
        return
    boxes = [bbox_of(m) for m in ms]
    bots = [b[3] for b in boxes]
    exp, tol = cfg['idle_baseline']['bottom'], cfg['idle_baseline']['tolerance']
    rep.add('idle_baseline', severity(cfg, 'idle_baseline'), all(abs(b - exp) <= tol for b in bots),
            f'待机脚底（包围盒下沿）{bots}，对齐五条悟/狗逍遥/里德应为 {exp}±{tol}')
    # 锚点漂移：脚底带（最低几行）横向质心三帧间位移
    drift = stride_span(ms, cfg['sole_rows'])
    rep.add('idle_anchor_drift', severity(cfg, 'idle_anchor_drift'), drift <= cfg['idle_anchor_span_max'],
            f'待机脚底带横向位移 {drift}px（上限 {cfg["idle_anchor_span_max"]}），脚/蹄锚点在漂')
    sole_span = max(bots) - min(bots)
    rep.add('idle_sole_span', severity(cfg, 'idle_anchor_drift'), sole_span == 0, f'待机脚底行浮动 {sole_span}px，应为 0')
    static = len({tuple(sorted(m)) for m in ms}) == 1
    rep.add('idle_static', severity(cfg, 'idle_static'), not static, '待机三帧完全相同，没有任何呼吸变化' if static else '待机有帧间变化')
    for k, m in enumerate(ms):
        iso = isolated_px(m, cfg['isolated_max_size'])
        rep.add('isolated_px', severity(cfg, 'isolated_px'), not iso, f'待机#{k} 孤立小块 {len(iso)} 处 {iso[:4]}')
        hs = holes(m, *fr[0].size, cfg['hole_min_size'], cfg['hole_max_size'])
        rep.add('hole', severity(cfg, 'hole'), not hs, f'待机#{k} 体内透明孔洞 {len(hs)} 处 {[h[0] for h in hs[:4]]}')
    return ms


def check_height(rep, cfg, masks, ref_walk):
    if not masks or not ref_walk:
        return
    def med(mm):
        hs = sorted(bbox_of(m)[3] - bbox_of(m)[1] for row in mm for m in row if m)
        return hs[len(hs) // 2]
    mine = med(masks)
    ref = med([[opaque(f) for f in row] for row in ref_walk])
    ratio = round(mine / ref, 2)
    lo, hi = cfg['height_ratio']
    rep.add('height_ratio', severity(cfg, 'height_ratio'), lo <= ratio <= hi,
            f'行走可见高度 {mine}px / 参照 {ref}px = {ratio}，范围 {lo}～{hi}')


# ---------------------------------------------------------------- 拼图
def montage(path, name, walk_im, idle_im, ref_battle, ref_walk, rep, scale):
    """行对行：第 0 行 左=原版战斗图第一帧 右=新待机；后四行 左=原版行走第一帧 右=新行走（原生 1× 三帧＋放大 scale×）。"""
    pad, lab = 8, 14
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', 12)
    except Exception:
        font = ImageFont.load_default()
    walk = split_grid(walk_im, 3, 4) if walk_im and walk_im.size == (144, 192) else None
    idle = split_grid(idle_im, 3, 1)[0] if idle_im and idle_im.size == (192, 64) else None
    rows = [(('orig battle (wait) f0', ref_battle[0] if ref_battle else None), ('new idle f0..2', idle))]
    for i, d in enumerate(DIRS):
        rows.append(((f'ref walk {d} f0', ref_walk[i][0] if ref_walk else None), (f'new walk {d} f0..2', walk[i] if walk else None)))
    cell_h = 70 * scale + lab
    lw = max([f.width * scale for (_, f), _ in rows if f] + [48 * scale]) + pad * 2
    rcols = max([sum(f.width for f in fr) + 4 * len(fr) + sum(f.width * scale + 4 for f in fr) + 12 for _, (_, fr) in rows if fr] + [1])
    canvas = Image.new('RGB', (lw + rcols + pad, len(rows) * cell_h + lab + pad), (34, 39, 53))
    dr = ImageDraw.Draw(canvas)
    dr.text((pad, 0), f'{name}  [{"FAIL" if rep.fails else "PASS"}]  left=original  right=new (native, then x{scale})', fill='white', font=font)
    for r, ((ll, lf), (rl, rf)) in enumerate(rows):
        y = lab + r * cell_h
        dr.text((pad, y), ll, fill='#9fb4ff', font=font)
        dr.text((lw, y), rl, fill='#9fb4ff', font=font)
        if lf:
            big = lf.resize((lf.width * scale, lf.height * scale), Image.Resampling.NEAREST)
            canvas.paste(big, (pad, y + lab), big)
        if rf:
            x = lw
            for f in rf:
                canvas.paste(f, (x, y + lab), f)
                x += f.width + 4
            x += 12
            for f in rf:
                big = f.resize((f.width * scale, f.height * scale), Image.Resampling.NEAREST)
                canvas.paste(big, (x, y + lab), big)
                x += big.width + 4
    canvas.save(path)


# ---------------------------------------------------------------- 入口
def load_walk(path, index):
    """index=-1 单人图集原样；0..7 从标准 12×8 行走图里切出第 index 人，拼成 3×4。"""
    im = Image.open(path).convert('RGBA')
    if index < 0:
        return im
    rows = ref_walk_frames(path, index)
    w, h = rows[0][0].size
    out = Image.new('RGBA', (3 * w, 4 * h))
    for r, row in enumerate(rows):
        for k, f in enumerate(row):
            out.paste(f, (k * w, r * h))
    return out


def load_idle(args):
    if args.idle:
        return Image.open(args.idle).convert('RGBA')
    fr = ref_battle_frames(args.idle_sv, args.idle_motion)
    out = Image.new('RGBA', (3 * fr[0].width, fr[0].height))
    for k, f in enumerate(fr):
        out.paste(f, (k * f.width, 0))
    return out


def load_cfg(path):
    cfg = json.loads(Path(path).read_text(encoding='utf-8'))
    return cfg


def run(args):
    cfg = load_cfg(args.config)
    rep = Report()
    rep.skip = tuple(args.skip)
    walk_im = load_walk(args.walk, args.walk_index) if args.walk else None
    idle_im = load_idle(args) if (args.idle or args.idle_sv) else None
    if not walk_im and not idle_im:
        raise SystemExit('至少给 --walk 或 --idle 之一')
    masks = check_walk(rep, cfg, args.profile, walk_im, args.name) if walk_im else None
    if idle_im:
        check_idle(rep, cfg, args.profile, idle_im)
    rw = ref_walk_frames(args.ref_walk, args.ref_walk_index) if args.ref_walk else None
    rb = ref_battle_frames(args.ref_battle, args.ref_battle_motion) if args.ref_battle else None
    check_height(rep, cfg, masks, rw)
    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        montage(out / f'{args.name}_自检拼图.png', args.name, walk_im, idle_im, rb, rw, rep, args.scale)
        (out / f'{args.name}_自检报告.json').write_text(json.dumps({'name': args.name, 'profile': args.profile, 'pass': not rep.fails, 'items': rep.items}, ensure_ascii=False, indent=2), encoding='utf-8')
    return rep


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--name', required=True)
    p.add_argument('--walk', type=Path)
    p.add_argument('--idle', type=Path)
    p.add_argument('--walk-index', type=int, default=-1, help='行走图是标准 12×8 大图时，第几人（0..7）；单人图集用 -1')
    p.add_argument('--idle-sv', type=Path, help='从 9×6 战斗图取待机（量参照图用），与 --idle 二选一')
    p.add_argument('--idle-motion', type=int, default=1)
    p.add_argument('--skip', action='append', default=[], help='跳过某检查项 id（量遗留参照图时用，如 binary_alpha）；交样时不许用')
    p.add_argument('--strict', action='store_true', help='警告也算失败')
    p.add_argument('--profile', choices=['biped', 'quadruped'], default='biped')
    p.add_argument('--ref-battle', type=Path)
    p.add_argument('--ref-battle-motion', type=int, default=1, help='原版战斗图动作序号，默认 1=wait')
    p.add_argument('--ref-walk', type=Path)
    p.add_argument('--ref-walk-index', type=int, default=-1, help='-1 单人图集，0..7 标准 12×8 行走图第几人')
    p.add_argument('--out', type=Path, help='输出目录：拼图 PNG＋报告 JSON')
    p.add_argument('--scale', type=int, default=3)
    p.add_argument('--config', type=Path, default=HERE / '精灵自检阈值.json')
    p.add_argument('--show-passed', action='store_true')
    a = p.parse_args(argv)
    rep = run(a)
    for i in rep.items:
        if i['ok'] and not a.show_passed:
            continue
        tag = 'ok  ' if i['ok'] else ('FAIL' if i['level'] == 'fail' else 'warn')
        print(f'[{tag}] {i["id"]}: {i["msg"]}')
    nf, nw = len(rep.fails), len(rep.warns)
    print(f'{a.name}: {"通过" if not nf else "不通过"}（失败 {nf} 项，警告 {nw} 项，共 {len(rep.items)} 项检查）')
    return 1 if (nf or (a.strict and nw)) else 0


if __name__ == '__main__':
    sys.exit(main())
