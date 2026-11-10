#!/usr/bin/env python3
"""界面逐页像素／矩形对照（白龙 ui-pixel1）。

原版：review_system_pages.py ＋ `node review_system_pages.cjs <原版目录> px_menu px_item px_equip px_status px_shop`；
Godot：`godot --path 01_Godot工程 res://tests/xiyou_ui_pixel.tscn -- --out=<Godot目录>`（非 headless）。
然后 `python3 -I ui_pixel_compare.py <原版目录> <Godot目录> <输出目录> [图名通配…]`（默认 px_*；养成页如 pet_* training_* inlay_*）：
- 矩形：两边可见、开着的窗口各自去重，完全相同的配成一对；再按 KNOWN（已查清原因的差）认定；剩下的各列出来，并给出对方最近的矩形与四边差。
- 像素：整页逐像素差（RGB 最大通道差），出 <名>_heat.png（原版灰度底＋差值越大越红）、整页与每个原版窗口内的平均差和「差 >32 的像素占比」。
写 <输出目录>/ui_pixel_report.json 并在终端打表。本机没装 PIL，PNG 用标准库读写（8 位 RGB／RGBA、不隔行）。
只读两个输入目录，只写输出目录。"""
import json
import struct
import sys
import zlib
from pathlib import Path

THRESH = 32

# 已认定的矩形差（白龙 ui-pixel2）：完全相同配不上、但原因已查清的，按「原版窗口类型、Godot 类型、四边差」认定成对，
# 报表里单列「已认定」并写原因；差值或类型对不上的照旧列为没配上（新的真差不会被吞掉）。
KNOWN = [
    ('Sprite_ItemHelp', 'XHelpCard', (-6, 0, 0, 2), '说明卡本体：O-008 贴行放（x−6）、O-007 最小字号（高＋2）'),
    ('Window_ItemHelp', 'XHelpCardFrame', (-6, 0, 0, 2), '说明卡品质框（本体外扩 10）：随本体 O-008／O-007'),
    ('JAH_Window_Status_Params', 'XMVWindow', (0, -36, 0, 36), '状态页参数窗：战力先藏（Kyo 11-08），战力条 36 像素让出；开战力时 (0,108,1280,612) 与原版同'),
]


def read_png(path):
    data = Path(path).read_bytes()
    pos, idat = 8, []
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b'IHDR':
            w, h, depth, color, _, _, inter = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and color in (2, 6) and inter == 0, (depth, color, inter)
            bpp = 3 if color == 2 else 4
        elif kind == b'IDAT':
            idat.append(body)
        pos += 12 + n
    raw, stride = zlib.decompress(b''.join(idat)), w * bpp
    out, prev = bytearray(w * h * 3), bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif f == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b, c = prev[i], prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        if bpp == 3:
            out[y * w * 3:(y + 1) * w * 3] = line
        else:
            row = out[y * w * 3:(y + 1) * w * 3]
            row[0::3], row[1::3], row[2::3] = line[0::4], line[1::4], line[2::4]
            out[y * w * 3:(y + 1) * w * 3] = row
        prev = line
    return w, h, out


def write_png(path, w, h, rgb):
    raw = b''.join(b'\x00' + bytes(rgb[y * w * 3:(y + 1) * w * 3]) for y in range(h))
    def chunk(k, b):
        return struct.pack('>I', len(b)) + k + b + struct.pack('>I', zlib.crc32(k + b) & 0xffffffff)
    Path(path).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))


def windows(path, godot):
    d = json.loads(Path(path).read_text())
    seen, out = set(), []
    for win in d['windows']:
        if not godot and (not win.get('visible') or (win.get('openness') is not None and win['openness'] <= 0)):
            continue
        r = tuple(round(v) for v in win['rect'])
        if r in seen or r[2] <= 0 or r[3] <= 0:
            continue
        seen.add(r)
        name = str(win.get('name') or '')
        out.append({'type': (name if name and not name.startswith('@') else win['type']) if godot else win['type'], 'rect': list(r)})
    return out


def match(orig, god):
    gr = {tuple(g['rect']): g for g in god}
    pairs, o_left = [], []
    for o in orig:
        g = gr.pop(tuple(o['rect']), None)
        (pairs.append([o['type'], g['type'], o['rect']]) if g else o_left.append(o))
    known = []
    for o in list(o_left):
        for ot, gt, delta, why in KNOWN:
            if o['type'] != ot:
                continue
            want = tuple(a + d for a, d in zip(o['rect'], delta))
            g = gr.get(want)
            if g and g['type'] == gt:
                gr.pop(want)
                o_left.remove(o)
                known.append([o['type'], g['type'], o['rect'], g['rect'], why])
                break
    def near(r, pool):
        if not pool:
            return None
        best = min(pool, key=lambda q: sum(abs(a - b) for a, b in zip(r, q['rect'])))
        return {'type': best['type'], 'rect': best['rect'], 'delta': [b - a for a, b in zip(r, best['rect'])]}
    g_left = list(gr.values())
    return pairs, known, [dict(o, nearest_godot=near(o['rect'], g_left)) for o in o_left], \
        [dict(g, nearest_orig=near(g['rect'], o_left)) for g in g_left]


def pixel(o_png, g_png, heat_path, rects):
    w, h, a = read_png(o_png)
    w2, h2, b = read_png(g_png)
    assert (w, h) == (w2, h2), ((w, h), (w2, h2))
    diff = bytearray(w * h)
    for i in range(w * h):
        j = i * 3
        diff[i] = max(abs(a[j] - b[j]), abs(a[j + 1] - b[j + 1]), abs(a[j + 2] - b[j + 2]))
    heat = bytearray(w * h * 3)
    for i in range(w * h):
        j, g, d = i * 3, (a[i * 3] * 3 + a[i * 3 + 1] * 6 + a[i * 3 + 2]) // 30, diff[i]
        heat[j], heat[j + 1], heat[j + 2] = min(255, g + d * 2), max(0, g - d), max(0, g - d)
    write_png(heat_path, w, h, heat)
    def stat(x0, y0, rw, rh):
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(w, x0 + rw), min(h, y0 + rh)
        n = max(1, (x1 - x0) * (y1 - y0))
        tot = big = 0
        for y in range(y0, y1):
            seg = diff[y * w + x0:y * w + x1]
            tot += sum(seg)
            big += sum(1 for v in seg if v > THRESH)
        return {'mean': round(tot / n, 2), 'over32': round(big / n, 4)}
    return stat(0, 0, w, h), [dict(r, **stat(*r['rect'])) for r in rects]


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    od, gd, out = (Path(p) for p in sys.argv[1:4])
    globs = sys.argv[4:] or ['px_*']
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    for oj in sorted({q for g in globs for q in od.glob(g + '.json')}):
        name, gj = oj.stem, gd / (oj.stem + '.json')
        if not gj.exists():
            report[name] = {'missing_godot': True}
            continue
        orig, god = windows(oj, False), windows(gj, True)
        pairs, known, o_left, g_left = match(orig, god)
        whole, per = pixel(od / (name + '.png'), gd / (name + '.png'), out / (name + '_heat.png'), orig)
        report[name] = {'matched': pairs, 'known': known, 'orig_only': o_left, 'godot_only': g_left, 'pixel': whole, 'per_window': per}
        print(f"{name}: 矩形配上 {len(pairs)}，已认定 {len(known)}，原版多 {len(o_left)}，Godot 多 {len(g_left)}；整页平均差 {whole['mean']}、差>32 占 {whole['over32']:.1%}")
        for k in known:
            print(f"   已认定 {k[0]} {k[2]} ↔ {k[1]} {k[3]}：{k[4]}")
        for o in o_left:
            n = o['nearest_godot']
            print(f"   原版 {o['type']} {o['rect']} → 最近 Godot {n and n['type']} {n and n['rect']} 差 {n and n['delta']}")
        for g in g_left:
            print(f"   Godot {g['type']} {g['rect']} 原版无同矩形")
        for p in per:
            print(f"   窗 {p['type']:<28} {str(p['rect']):<22} 平均 {p['mean']:>6}  >32 {p['over32']:.1%}")
    (out / 'ui_pixel_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1) + '\n')


if __name__ == '__main__':
    main()
