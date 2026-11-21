#!/usr/bin/env python3
"""Muse 视频（纯绿底 mp4）→ 128 格 MV 侧视战斗图集（9×6，1152×768）。

T352 离线工具：只读输入，不改 content/。用法见同目录 README「Muse 视频转战斗精灵」。

做法（一个角色一套参数，所有动作共用）：
1. 定妆图抠绿→量人高 H_ref、脚底行、身体中轴；缩放 s = --height / H_ref，只算这一次。
2. 每段视频按「与定妆图同取景」换算：s_video = s × 定妆图宽 / 视频宽（不逐帧、不逐视频自适应）。
   视频首帧（--align frame0，默认）或定妆图（--align ref）的脚底与中轴对到格内基线／中线，
   这一偏移整段视频共用，动作位移因此保留。
3. 抠绿＋边缘去绿溢色＋按覆盖率二值透明；颜色按前景像素加权平均缩小。
4. 调色板锁定：从定妆图缩小后的像素取 --colors 色，所有帧就近映射。
5. 报告：每帧人高比、色板偏差、外接框、贴边；超阈值标红；4 倍最近邻拼图与动图。
"""
import argparse
import html
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ACTIONS = ['walk', 'wait', 'chant', 'guard', 'damage', 'evade', 'thrust', 'swing', 'missile',
           'skill', 'spell', 'item', 'escape', 'victory', 'dying', 'abnormal', 'sleep', 'dead']
COLS, ROWS = 9, 6
FONT = '/System/Library/Fonts/STHeiti Medium.ttc'

DEFAULTS = {
    'cell': 128,
    'height': 100,          # 定妆图人高在格内的像素（≈五条悟 64 格 ×2 的体量）
    'baseline': 127,        # 定妆图脚底（最低不透明行）落在格内第几行（零基）
    'axis': 64,             # 定妆图身体中轴落在格内第几列
    'key_threshold': 60,    # g - max(r,b) 大于此值算绿底
    'despill_band': 3,      # 前景边缘几像素内去绿溢色（源分辨率）
    'erode': 1,             # 抠出的前景先收缩几像素去绿边（源分辨率）
    'coverage': 0.5,        # 缩小后覆盖率≥此值算不透明
    'colors': 48,           # 定妆图色板色数
    'min_island': 2,        # 删掉面积≤此值的孤立不透明块（0=不删）
    'color_mode': 'vote',   # vote＝源像素先映射色板再按面积投票；mean＝先平均再映射
}
THRESHOLDS = {
    'video_height_ratio': [0.96, 1.04],   # 视频首帧人高 / 定妆图人高（取景是否一致）
    'frame_height_ratio': [0.80, 1.08],   # 每帧人高 / 定妆图人高（蹲伏、跳起会动，只作提醒）
    'palette_mean_dist': 14.0,            # 映射前后平均 RGB 距离
    'palette_far_ratio': 0.05,            # 距离 > palette_far_dist 的像素占比
    'palette_far_dist': 48.0,
    'baseline_shift': 2,                  # 脚底离基线超过几行标红（跳起类动作会正当触发，看图确认）
}


# ---------- 读取 ----------

def probe(video):
    out = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                          'stream=width,height,r_frame_rate,nb_frames', '-of', 'json', str(video)],
                         capture_output=True, text=True, check=True)
    st = json.loads(out.stdout)['streams'][0]
    num, den = st['r_frame_rate'].split('/')
    return int(st['width']), int(st['height']), float(num) / float(den)


def read_video(video):
    w, h, fps = probe(video)
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(video), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                         capture_output=True, check=True).stdout
    n = len(raw) // (w * h * 3)
    frames = np.frombuffer(raw[:n * w * h * 3], np.uint8).reshape(n, h, w, 3)
    return frames, fps


def load_ref(path, ref_time):
    path = Path(path)
    if path.suffix.lower() in ('.mp4', '.mov', '.webm', '.m4v'):
        frames, fps = read_video(path)
        idx = min(len(frames) - 1, max(0, round(ref_time * fps)))
        return frames[idx], None, f'{path.name}@{idx / fps:.3f}s'
    im = Image.open(path)
    if im.mode in ('RGBA', 'LA', 'P') and 'A' in im.convert('RGBA').getbands():
        rgba = np.asarray(im.convert('RGBA'))
        if rgba[..., 3].min() < 255:
            return rgba[..., :3], rgba[..., 3] >= 128, path.name
    return np.asarray(im.convert('RGB')), None, path.name


# ---------- 抠绿 ----------

def key_mask(rgb, cfg):
    f = rgb.astype(np.int16)
    keyness = f[..., 1] - np.maximum(f[..., 0], f[..., 2])
    fg = keyness <= cfg['key_threshold']
    if cfg['erode'] > 0:
        m = Image.fromarray((fg * 255).astype(np.uint8))
        for _ in range(cfg['erode']):
            m = m.filter(ImageFilter.MinFilter(3))
        fg = np.asarray(m) > 0
    return fg


def despill(rgb, fg, band):
    """只在前景靠近绿底的一圈去绿溢色：g 压到 max(r,b)。内部本来带绿的颜色不动。"""
    out = rgb.astype(np.float32).copy()
    if band <= 0:
        return out
    bg = Image.fromarray((~fg * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(band * 2 + 1))
    edge = fg & (np.asarray(bg) > 0)
    cap = np.maximum(out[..., 0], out[..., 2])
    g = out[..., 1]
    out[..., 1] = np.where(edge & (g > cap), cap, g)
    return out


def extent(fg):
    ys, xs = np.nonzero(fg)
    if len(ys) == 0:
        return None
    top, bottom = int(ys.min()), int(ys.max())
    h = bottom - top + 1
    # 中轴：人高 30%～95% 带内不透明像素 x 的中位数（避开头发、角；与首帧同法量，误差互相抵消）
    band = (ys >= top + 0.30 * h) & (ys <= top + 0.95 * h)
    axis = float(np.median(xs[band])) if band.any() else float(np.median(xs))
    return {'top': top, 'bottom': bottom, 'left': int(xs.min()), 'right': int(xs.max()), 'height': h, 'axis': axis}


# ---------- 缩小与上色 ----------

def _box(src_axis, src_foot, scale, cfg):
    cell = cfg['cell']
    x0 = src_axis + 0.5 - (cfg['axis'] + 0.5) / scale
    y0 = src_foot + 1 - (cfg['baseline'] + 1) / scale
    return (x0, y0, x0 + cell / scale, y0 + cell / scale), int(cell / scale) + 2


def resample_plane(plane, scale, src_axis, src_foot, cfg):
    """把源分辨率的一个平面按面积缩到 cell×cell：源 (src_axis, src_foot+1) 对到格 (axis+0.5, baseline+1)。"""
    cell = cfg['cell']
    box, pad = _box(src_axis, src_foot, scale, cfg)
    box = tuple(v + pad for v in box)
    im = Image.fromarray(np.pad(plane.astype(np.float32), pad), 'F')
    return np.asarray(im.resize((cell, cell), Image.BOX, box=box))


def resample(rgb_f, fg, scale, src_axis, src_foot, cfg):
    cov = resample_plane(fg, scale, src_axis, src_foot, cfg)
    alpha = cov >= cfg['coverage']
    if rgb_f is None:
        return None, alpha
    pm = np.stack([resample_plane(rgb_f[..., c] * fg, scale, src_axis, src_foot, cfg) for c in range(3)], -1)
    rgb = np.where(alpha[..., None], pm / np.maximum(cov, 1e-6)[..., None], 0)
    return np.clip(rgb, 0, 255), alpha


def build_palette(rgb, fg, colors):
    """定妆图源分辨率的前景像素取色板。

    直接按像素数中位切分时，大片暗色头发会吃掉大半色数、金甲这类少而亮的颜色分不到（样片实测 48 色里 30 多个是黑紫）。
    所以先按 RGB 各 4 位分桶，每桶取均色、权重取像素数开方，再中位切分，最后对各桶均色做 3 轮加权 k-means 收拢。
    """
    px = rgb[fg].round().clip(0, 255).astype(np.int32)
    key = (px[:, 0] >> 4) * 256 + (px[:, 1] >> 4) * 16 + (px[:, 2] >> 4)
    uk, inv, cnt = np.unique(key, return_inverse=True, return_counts=True)
    mean = np.stack([np.bincount(inv, px[:, c], len(uk)) / cnt for c in range(3)], -1)
    rep = np.ceil(np.sqrt(cnt)).astype(int)
    seed = np.repeat(mean, rep, 0).round().astype(np.uint8)
    q = Image.fromarray(seed.reshape(1, -1, 3), 'RGB').quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    pal = np.array(q.getpalette()[:colors * 3], np.float32).reshape(-1, 3)[np.unique(np.asarray(q))]
    # k-means 收拢（同样按桶开方加权）
    w = np.sqrt(cnt)
    for _ in range(3):
        j, _ = nearest(mean.astype(np.float32), pal)
        for k in range(len(pal)):
            m = j == k
            if m.any():
                pal[k] = (mean[m] * w[m, None]).sum(0) / w[m].sum()
    return pal


def nearest(px, pal, chunk=65536):
    idx = np.empty(len(px), np.int32)
    dist = np.empty(len(px), np.float32)
    for i in range(0, len(px), chunk):
        d = ((px[i:i + chunk, None, :] - pal[None, :, :]) ** 2).sum(-1)
        j = d.argmin(1)
        idx[i:i + chunk] = j
        dist[i:i + chunk] = np.sqrt(d[np.arange(len(j)), j])
    return idx, dist


def drop_islands(rgba, max_size):
    if max_size <= 0:
        return rgba, 0
    a = rgba[..., 3] > 0
    h, w = a.shape
    seen = np.zeros_like(a)
    removed = 0
    for y, x in zip(*np.nonzero(a)):
        if seen[y, x]:
            continue
        stack, comp = [(y, x)], []
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            comp.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and a[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        if len(comp) <= max_size:
            for cy, cx in comp:
                rgba[cy, cx] = 0
            removed += len(comp)
    return rgba, removed


def crop_check(fg, scale, src_axis, src_foot, cfg):
    """缩放前量前景超出采样框多深（按上下左右分开，单位＝格内像素）。

    缩小后的格子永远在 0..cell-1 内，被裁掉的脚、手、尾巴在输出里看不出来（脚被向下裁时 bottom 仍是 127），
    所以必须在源图上量。正常站在基线上的脚底行在框内（框下沿＝脚底行+1），不会报。
    返回 {方向: 深度}，只列有出格的方向；深度 ≥1 格内像素才标红（不到 1 像素是视频抖动级别，只记录）。
    """
    (x0, y0, x1, y1), _ = _box(src_axis, src_foot, scale, cfg)
    ys, xs = np.nonzero(fg)
    if len(ys) == 0:
        return {}
    depth = {'左': x0 - xs.min(), '右': xs.max() + 1 - x1, '上': y0 - ys.min(), '下': ys.max() + 1 - y1}
    return {k: round(float(v * scale), 2) for k, v in depth.items() if v > 0}


def to_sprite(rgb_u8, fg, scale, src_axis, src_foot, pal, cfg):
    """返回 (RGBA, 源像素到色板的距离, 删掉的孤点数, 色板)。

    vote（默认）：源前景像素先就近映射到色板，再按面积投票选每个目标像素的颜色——保住像素画的硬色块；
    mean：先按面积平均再映射（偏灰，留作对照）。两种都按覆盖率二值透明。
    """
    rgb_f = despill(rgb_u8, fg, cfg['despill_band'])
    if pal is None:
        pal = build_palette(rgb_f, fg, cfg['colors'])
    idx, dist = nearest(rgb_f[fg], pal)
    if cfg['color_mode'] == 'mean':
        rgb, alpha = resample(rgb_f, fg, scale, src_axis, src_foot, cfg)
        rgba = np.zeros(rgb.shape[:2] + (4,), np.uint8)
        j, _ = nearest(rgb[alpha], pal)
        rgba[alpha, :3] = pal[j].round().astype(np.uint8)
        rgba[alpha, 3] = 255
    else:
        _, alpha = resample(None, fg, scale, src_axis, src_foot, cfg)
        lab = np.full(fg.shape, -1, np.int32)
        lab[fg] = idx
        best = np.zeros(alpha.shape, np.float32)
        pick = np.zeros(alpha.shape, np.int32)
        for k in np.unique(idx):
            w = resample_plane(lab == k, scale, src_axis, src_foot, cfg)
            better = w > best
            best[better] = w[better]
            pick[better] = k
        rgba = np.zeros(alpha.shape + (4,), np.uint8)
        rgba[alpha, :3] = pal[pick[alpha]].round().astype(np.uint8)
        rgba[alpha, 3] = 255
    rgba, removed = drop_islands(rgba, cfg['min_island'])
    return rgba, dist, removed, pal


# ---------- 取帧 ----------

def mask_dist(a, b):
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return 1 - inter / union if union else 0


def auto_pick(masks):
    """起势／发力／收势：发力＝离首帧最远；起势＝发力前同时离首帧和发力最远；收势＝发力后同时离发力和末帧最远。"""
    n = len(masks)
    d0 = [mask_dist(masks[0], m) for m in masks]
    peak = int(np.argmax(d0))
    peak = min(max(peak, 2), n - 3) if n >= 5 else peak

    def best(rng, ref_a, ref_b):
        rng = list(rng)
        if not rng:
            return None
        sc = [min(mask_dist(masks[i], masks[ref_a]), mask_dist(masks[i], masks[ref_b])) for i in rng]
        return rng[int(np.argmax(sc))]
    start = best(range(1, peak), 0, peak) or max(0, peak - 1)
    end = best(range(peak + 1, n - 1), peak, n - 1) or min(n - 1, peak + 1)
    return [start, peak, end]


# ---------- 报告 ----------

def flag(v, lo=None, hi=None):
    return (lo is not None and v < lo) or (hi is not None and v > hi)


def frame_report(rgba, dist, removed, ref_h, cfg, th, cropped=None):
    a = rgba[..., 3] > 0
    ext = extent(a)
    cell = cfg['cell']
    r = {'island_removed': removed, 'crop_depth': cropped or {}}
    if ext is None:
        r.update(empty=True, red=['空帧'])
        return r
    r['bbox'] = [ext['left'], ext['top'], ext['right'] + 1, ext['bottom'] + 1]
    r['height_ratio'] = round(ext['height'] / ref_h, 3)
    r['palette_mean_dist'] = round(float(dist.mean()), 2) if len(dist) else 0
    r['palette_far_ratio'] = round(float((dist > th['palette_far_dist']).mean()), 4) if len(dist) else 0
    r['baseline_gap'] = cfg['baseline'] - ext['bottom']
    red = []
    lo, hi = th['frame_height_ratio']
    if flag(r['height_ratio'], lo, hi):
        red.append('人高比')
    if r['palette_mean_dist'] > th['palette_mean_dist']:
        red.append('色板平均偏差')
    if r['palette_far_ratio'] > th['palette_far_ratio']:
        red.append('色板外颜色')
    if any(v >= 1 for v in (cropped or {}).values()):
        red.append('出格被裁')
    elif ext['left'] == 0 or ext['right'] == cell - 1 or ext['top'] == 0:
        red.append('贴格边')
    if ext['bottom'] > cfg['baseline']:
        red.append('脚底低于基线')
    elif r['baseline_gap'] > th['baseline_shift']:
        red.append('脚离基线')
    r['red'] = red
    return r


def checker(w, h, s=8):
    yy, xx = np.mgrid[0:h, 0:w]
    v = np.where(((yy // s) + (xx // s)) % 2 == 0, 200, 170).astype(np.uint8)
    return Image.fromarray(np.stack([v, v, v], -1), 'RGB')


def on_bg(img, scale):
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    bg = checker(big.width, big.height, 4 * scale)
    bg.paste(big, (0, 0), big)
    return bg


def guides(im, cfg, scale):
    """每格画脚底基线（蓝，基线行下沿）和中轴（红）。"""
    d = ImageDraw.Draw(im)
    step = cfg['cell'] * scale
    y = min((cfg['baseline'] + 1) * scale, step - 1)
    for cx in range(0, im.width, step):
        x = cx + int((cfg['axis'] + 0.5) * scale)
        d.line([(cx, y), (cx + step - 1, y)], fill=(40, 120, 255), width=1)
        d.line([(x, 0), (x, im.height)], fill=(255, 60, 60), width=1)
    return im


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


# ---------- 主流程 ----------

def parse_clip(spec):
    """swing=path.mp4 或 swing=path.mp4@0.5,1.2,2.0（秒）"""
    if '=' not in spec:
        raise SystemExit(f'--clip 写成 动作名=视频[@秒,秒,秒]：{spec}')
    name, rest = spec.split('=', 1)
    if name not in ACTIONS:
        raise SystemExit(f'未知动作 {name}，可用：{" ".join(ACTIONS)}')
    times = None
    if '@' in rest:
        rest, t = rest.rsplit('@', 1)
        times = [float(x) for x in t.split(',')]
        if len(times) != 3:
            raise SystemExit(f'{name} 取帧时间要 3 个：{t}')
    return name, Path(rest).expanduser(), times


def run(args):
    cfg = dict(DEFAULTS)
    for k in DEFAULTS:
        v = getattr(args, k, None)
        if v is not None:
            cfg[k] = v
    th = dict(THRESHOLDS)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    cell = cfg['cell']

    ref_rgb, ref_alpha, ref_label = load_ref(args.ref, args.ref_time)
    if args.flip:
        ref_rgb = ref_rgb[:, ::-1]
        ref_alpha = None if ref_alpha is None else ref_alpha[:, ::-1]
    ref_fg = ref_alpha if ref_alpha is not None else key_mask(ref_rgb, cfg)
    ref_ext = extent(ref_fg)
    if ref_ext is None:
        raise SystemExit('定妆图抠不出人')
    scale = cfg['height'] / ref_ext['height']
    ref_w = ref_rgb.shape[1]
    ref_sprite, ref_dist, ref_removed, pal = to_sprite(ref_rgb, ref_fg, scale, ref_ext['axis'], ref_ext['bottom'], None, cfg)
    ref_h_cell = extent(ref_sprite[..., 3] > 0)['height']
    Image.fromarray(ref_sprite, 'RGBA').save(out / '定妆图_128.png')
    pal_img = Image.fromarray(pal.round().astype(np.uint8).reshape(1, -1, 3), 'RGB')
    pal_img.resize((pal_img.width * 16, 16), Image.NEAREST).save(out / '色板.png')

    report = {
        'tool': 'muse转精灵.py', 'cfg': cfg, 'thresholds': th,
        'ref': {'source': ref_label, 'src_height': ref_ext['height'], 'src_width': ref_w,
                'scale': round(scale, 5), 'cell_height': ref_h_cell, 'palette_colors': len(pal),
                'palette_mean_dist': round(float(ref_dist.mean()), 2), 'flip': bool(args.flip)},
        'actions': {}, 'missing': [],
    }
    atlas = np.zeros((ROWS * cell, COLS * cell, 4), np.uint8)
    clips = [parse_clip(c) for c in args.clip]
    done = set()
    for name, video, times in clips:
        frames, fps = read_video(video)
        if args.flip:
            frames = frames[:, :, ::-1]
        vw = frames.shape[2]
        s_video = scale * ref_w / vw
        masks = [key_mask(f, cfg) for f in frames]
        f0 = extent(masks[0])
        if f0 is None:
            raise SystemExit(f'{video.name} 首帧抠不出人')
        v_ratio = f0['height'] * (ref_w / vw) / ref_ext['height']
        if args.align == 'frame0':
            ax, foot = f0['axis'], f0['bottom']
        else:
            k = vw / ref_w
            ax, foot = ref_ext['axis'] * k, (ref_ext['bottom'] + 1) * k - 1
        if times is None:
            idx = auto_pick(masks)
            how = 'auto'
        else:
            idx = [min(len(frames) - 1, max(0, round(t * fps))) for t in times]
            how = 'manual'
        mi = ACTIONS.index(name)
        col0, row = (mi // ROWS) * 3, mi % ROWS
        frs = []
        sprites = []
        for k, i in enumerate(idx):
            sp, dist, removed, _ = to_sprite(frames[i], masks[i], s_video, ax, foot, pal, cfg)
            r = frame_report(sp, dist, removed, ref_h_cell, cfg, th, crop_check(masks[i], s_video, ax, foot, cfg))
            r.update(frame=int(i), time=round(i / fps, 3), role=['起势', '发力', '收势'][k])
            frs.append(r)
            sprites.append(sp)
            atlas[row * cell:(row + 1) * cell, (col0 + k) * cell:(col0 + k + 1) * cell] = sp
            Image.fromarray(sp, 'RGBA').save(out / f'{name}_{k}.png')
        vred = []
        lo, hi = th['video_height_ratio']
        if flag(v_ratio, lo, hi):
            vred.append('视频取景与定妆图人高不一致')
        report['actions'][name] = {
            'video': video.name, 'fps': fps, 'frames': len(frames), 'pick': how,
            'video_scale': round(s_video, 5), 'frame0_height_ratio': round(v_ratio, 3),
            'align': args.align, 'red': vred, 'frames_out': frs,
        }
        strip = Image.new('RGBA', (cell * 3, cell))
        for k, sp in enumerate(sprites):
            strip.paste(Image.fromarray(sp, 'RGBA'), (k * cell, 0))
        guides(on_bg(strip, 4), cfg, 4).save(out / f'{name}_x4.png')
        gif = [guides(on_bg(Image.fromarray(sp, 'RGBA'), 4), cfg, 4) for sp in sprites]
        gif[0].save(out / f'{name}.gif', save_all=True, append_images=gif[1:], duration=args.gif_ms, loop=0)
        # 源帧对照：取出的三帧原视频小图
        thumbs = [Image.fromarray(frames[i]).resize((240, 240), Image.BILINEAR) for i in idx]
        src = Image.new('RGB', (720, 240))
        for k, t in enumerate(thumbs):
            src.paste(t, (k * 240, 0))
        src.save(out / f'{name}_源帧.png')
        done.add(name)

    report['missing'] = [a for a in ACTIONS if a not in done]
    atlas_im = Image.fromarray(atlas, 'RGBA')
    atlas_im.save(out / '图集_SV_128.png')
    big = on_bg(atlas_im, 4)
    d = ImageDraw.Draw(big)
    f = font(28)
    for mi, a in enumerate(ACTIONS):
        x, y = (mi // ROWS) * 3 * cell * 4, (mi % ROWS) * cell * 4
        d.rectangle([x, y, x + 3 * cell * 4 - 1, y + cell * 4 - 1], outline=(90, 90, 90), width=2)
        d.text((x + 8, y + 4), a + ('' if a in done else '（缺）'), fill=(200, 0, 0) if a not in done else (30, 30, 30), font=f)
    big.save(out / '图集_x4.png')
    (out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1))
    write_html(out, report)
    red = sum(len(r.get('red', [])) for a in report['actions'].values() for r in a['frames_out']) + \
        sum(len(a['red']) for a in report['actions'].values())
    print(f'输出 {out}；动作 {len(done)}/18，缺 {len(report["missing"])}；标红 {red} 项')
    return 0


def write_html(out, rep):
    e = html.escape
    rows = []
    for name, a in rep['actions'].items():
        vr = '<b class=r>' + '、'.join(a['red']) + '</b>' if a['red'] else ''
        rows.append(f'<h2>{e(name)}</h2><p>视频 {e(a["video"])}，{a["frames"]} 帧 @ {a["fps"]:g}fps，取帧 {a["pick"]}；'
                    f'视频缩放 {a["video_scale"]}，首帧人高比 <span class="{"r" if a["red"] else ""}">{a["frame0_height_ratio"]}</span> {vr}</p>')
        rows.append(f'<img src="{e(name)}_x4.png"> <img src="{e(name)}.gif"><br><img src="{e(name)}_源帧.png" width=540>')
        rows.append('<table><tr><th>帧</th><th>时刻</th><th>序</th><th>人高比</th><th>色板平均偏差</th><th>色板外占比</th>'
                    '<th>外接框 x0,y0,x1,y1</th><th>出格被裁（源像素）</th><th>脚底离基线</th><th>删孤点</th><th>标红</th></tr>')
        for r in a['frames_out']:
            red = set(r.get('red', []))

            def c(key, v):
                return f'<td class=r>{v}</td>' if key in red else f'<td>{v}</td>'
            rows.append('<tr>' + f'<td>{r["frame"]}</td><td>{r["time"]}s</td><td>{r["role"]}</td>' +
                        c('人高比', r.get('height_ratio')) + c('色板平均偏差', r.get('palette_mean_dist')) +
                        c('色板外颜色', r.get('palette_far_ratio')) + c('贴格边', r.get('bbox')) +
                        c('出格被裁', '、'.join(f'{k}{v}' for k, v in r.get('crop_depth', {}).items()) or '—') +
                        c('脚底低于基线' if '脚底低于基线' in red else '脚离基线', r.get('baseline_gap')) + f'<td>{r["island_removed"]}</td>' +
                        f'<td class=r>{e("、".join(r.get("red", [])))}</td></tr>')
        rows.append('</table>')
    ref = rep['ref']
    th = rep['thresholds']
    page = f'''<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width">
<title>Muse 转精灵报告</title><style>body{{font:14px -apple-system,sans-serif;margin:16px;background:#fafafa}}
img{{image-rendering:pixelated;max-width:100%}}table{{border-collapse:collapse;margin:8px 0}}td,th{{border:1px solid #ccc;padding:3px 6px}}
.r{{color:#c00;font-weight:bold}}</style>
<h1>Muse 转精灵一致性报告</h1>
<p>定妆图 {e(ref["source"])}：源人高 {ref["src_height"]}px → 格内 {ref["cell_height"]}px（缩放 {ref["scale"]}），色板 {ref["palette_colors"]} 色（定妆图自身映射偏差 {ref["palette_mean_dist"]}）{"，已水平翻转" if ref["flip"] else ""}。</p>
<p><img src="定妆图_128.png" width=256> <img src="色板.png"></p>
<p>阈值：首帧人高比 {th["video_height_ratio"]}；每帧人高比 {th["frame_height_ratio"]}；色板平均偏差 ≤{th["palette_mean_dist"]}；色板外（距离&gt;{th["palette_far_dist"]}）占比 ≤{th["palette_far_ratio"]}。蓝线＝脚底基线，红线＝中轴。</p>
<p>缺的动作（留空）：<b class=r>{e("、".join(rep["missing"])) or "无"}</b></p>
{"".join(rows)}
<h2>图集（4 倍）</h2><img src="图集_x4.png">'''
    (out / 'report.html').write_text(page)


# ---------- 自测 ----------

def _figure(size=480, k=1.0, dx=0, dy=0, body=(200, 150, 40), arm=0.0):
    """绿底上的简笔人：头、身、腿、一条会伸出的手臂。脚底 y=420、中轴 x=200（k=1 时）。"""
    im = Image.new('RGB', (size, size), (1, 252, 8))
    d = ImageDraw.Draw(im)
    cx, foot = 200 + dx, 420 + dy

    def box(x0, y0, x1, y1, c):
        d.rectangle([cx + x0 * k, foot - y1 * k, cx + x1 * k - 1, foot - y0 * k - 1], fill=c)
    box(-20, 0, -4, 110, (40, 30, 50))         # 左腿
    box(4, 0, 20, 110, (40, 30, 50))           # 右腿
    box(-35, 110, 35, 230, body)               # 身
    box(-30, 230, 30, 300, (240, 200, 180))    # 头
    if arm > 0:
        box(-35 - 90 * arm, 180, -35, 200, (180, 40, 60))  # 手臂向左伸
    return np.asarray(im)


def _write_mp4(path, frames, fps=24):
    h, w = frames[0].shape[:2]
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{w}x{h}', '-r', str(fps),
                    '-i', '-', '-c:v', 'libx264', '-crf', '12', '-pix_fmt', 'yuv420p', str(path)],
                   input=b''.join(f.tobytes() for f in frames), check=True)


def selftest():
    import tempfile
    tmp = Path(tempfile.mkdtemp(prefix='muse_selftest_'))
    arms = [.1, .1, .2, .5, 1, 1, .7, .3, .1, .1, .1, .1]
    Image.fromarray(_figure(arm=.1)).save(tmp / 'ref.png')
    _write_mp4(tmp / 'base.mp4', [_figure(arm=a) for a in arms])
    _write_mp4(tmp / 'shift.mp4', [_figure(dx=60, dy=-30, arm=a) for a in arms])
    _write_mp4(tmp / 'zoom.mp4', [_figure(k=1.15, arm=a) for a in arms])
    _write_mp4(tmp / 'blue.mp4', [_figure(body=(40, 90, 230), arm=a) for a in arms])
    # 首帧站姿正常、后面整个人下移 30px（如镜头下坠）：脚被裁出格底，输出里 bottom 仍是 127
    _write_mp4(tmp / 'drop.mp4', [_figure(arm=a, dy=30 if i >= 4 else 0) for i, a in enumerate(arms)])
    fails = []

    def check(cond, msg):
        print(('  ok  ' if cond else '  FAIL ') + msg)
        if not cond:
            fails.append(msg)
    out = tmp / 'out'
    main(['--ref', str(tmp / 'ref.png'), '--out', str(out),
          '--clip', f'swing={tmp / "base.mp4"}', '--clip', f'thrust={tmp / "shift.mp4"}@0.125,0.167,0.292',
          '--clip', f'skill={tmp / "zoom.mp4"}', '--clip', f'spell={tmp / "blue.mp4"}', '--clip', f'evade={tmp / "drop.mp4"}@0.25,0.292,0.333',
          '--min-island', '0'])
    rep = json.loads((out / 'report.json').read_text())
    atlas = Image.open(out / '图集_SV_128.png')
    check(atlas.size == (1152, 768), f'图集 1152×768（实际 {atlas.size}）')
    check(set(np.unique(np.asarray(atlas)[..., 3])) <= {0, 255}, '二值透明')
    check(len(rep['missing']) == 13 and 'wait' in rep['missing'], f'缺 13 个动作（实际 {len(rep["missing"])}）')
    ref = np.asarray(Image.open(out / '定妆图_128.png'))[..., 3] > 0
    e = extent(ref)
    check(e['height'] == 100 and e['bottom'] == 127, f'定妆图人高 100、脚底 127（实际 {e["height"]}、{e["bottom"]}）')
    check(abs(e['axis'] - 64) <= 1, f'中轴≈64（实际 {e["axis"]}）')
    sw = rep['actions']['swing']
    pk = [f['frame'] for f in sw['frames_out']]
    check(pk[0] < pk[1] < pk[2] and arms[pk[1]] == 1, f'自动取帧 起势<发力<收势且发力在手臂伸满（实际 {pk}）')
    check(not sw['red'] and all(not f['red'] for f in sw['frames_out']), f'同取景同色不标红（{[f["red"] for f in sw["frames_out"]]}）')
    a0 = np.asarray(Image.open(out / 'swing_0.png'))[..., 3] > 0
    th0 = np.asarray(Image.open(out / 'thrust_0.png'))[..., 3] > 0
    check(extent(a0)['bottom'] == extent(th0)['bottom'] and abs(extent(a0)['axis'] - extent(th0)['axis']) <= 1,
          '平移过的视频按首帧对齐后脚底与中轴不变')
    sk = rep['actions']['skill']
    check('视频取景与定妆图人高不一致' in sk['red'], f'放大 1.15 倍的视频首帧人高比标红（{sk["frame0_height_ratio"]}）')
    check(abs(sk['video_scale'] - sw['video_scale']) < 1e-9, '缩放只按定妆图算一次（各视频相同）')
    sp = rep['actions']['spell']['frames_out']
    check(all('色板外颜色' in f['red'] for f in sp), f'换色的视频色板标红（{[f["palette_far_ratio"] for f in sp]}）')
    ev = rep['actions']['evade']['frames_out']
    check(all('出格被裁' in f['red'] and f['crop_depth'].get('下', 0) >= 1 for f in ev),
          f'下移裁脚的帧标红（{[f["crop_depth"] for f in ev]}）')
    check(all('出格被裁' not in f['red'] for f in sw['frames_out']), '正常站在 127 行的帧不报出格')
    print(f'自测 {"通过" if not fails else "失败 " + str(len(fails)) + " 项"}；临时目录 {tmp}')
    return 1 if fails else 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv == ['--selftest']:
        return selftest()
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--ref', required=True, help='定妆图（PNG，透明或绿底），也可给视频（配 --ref-time 取一帧）')
    p.add_argument('--ref-time', type=float, default=0.0)
    p.add_argument('--clip', action='append', default=[], required=True,
                   help='动作名=视频.mp4[@起势秒,发力秒,收势秒]；不写时间自动挑。可重复')
    p.add_argument('--out', required=True)
    p.add_argument('--align', choices=['frame0', 'ref'], default='frame0',
                   help='脚底／中轴对齐：frame0=每段视频首帧对到定妆图位置（默认）；ref=假定视频取景与定妆图完全一致')
    p.add_argument('--flip', action='store_true', help='水平翻转（MV 我方侧视图面朝左）')
    p.add_argument('--gif-ms', type=int, default=250)
    p.add_argument('--selftest', action='store_true', help='单独使用：合成绿底视频自测（需 ffmpeg）')
    for k, v in DEFAULTS.items():
        p.add_argument('--' + k.replace('_', '-'), dest=k, type=type(v), default=None, help=f'默认 {v}')
    return run(p.parse_args(argv))


if __name__ == '__main__':
    sys.exit(main())
