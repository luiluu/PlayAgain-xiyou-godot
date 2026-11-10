#!/usr/bin/env python3
"""战斗画面像素对照（rules-battle-pixel，八戒）：原版 battle_pixel_ref.cjs 的 bp_*.png 对 Godot
`godot --path 01_Godot工程 res://tests/xiyou_battle_pixel.tscn -- --out=<目录>`（非 headless）的同名截图。两边背景都涂黑。
按区域（Boss 血条框／头像／数字／名字、Boss 状态面板、右侧状态格、选敌名字、三个伤害数字）裁出来：
- 像素：RGB 最大通道差的平均与「差 >32 的像素占比」；
- 墨迹框：区域里「亮度 >48」的像素外接框（文字、数字这类前景），两边框的四边差——字形不同但位置、大小对得上时这个比像素差更说明问题；
- 每个区域出 <输出>/<图>_<区域>.png（上原版、下 Godot，放大 2 倍）方便看。
用法：python3 -I battle_pixel_compare.py <原版目录> <Godot 目录> <输出目录>。只读两个输入目录，只写输出目录。本机没装 PIL，用最小 PNG 编解码。
"""
import json
import struct
import sys
import zlib
from pathlib import Path

THRESH = 32
INK = 48
# (区域名, x, y, w, h)；坐标是 1280×720 画面坐标
REGIONS = {
    'bp_boss_input': [('boss_frame', 105, 45, 507, 78), ('boss_face', 55, 37, 85, 85), ('boss_number', 415, 85, 150, 32),
                      ('boss_name', 135, 104, 300, 26), ('boss_panel', 105, 131, 440, 96), ('side_1', 1044, 0, 236, 121),
                      ('side_2', 1044, 121, 236, 121), ('command', 852, 462, 220, 196)],
    'bp_states': [('boss_panel', 105, 131, 440, 96), ('state_cell_1', 1044, 20, 36, 36), ('side_1', 1080, 0, 200, 121)],
    'bp_enemy_select': [('enemy_name', 300, 440, 230, 70), ('boss_panel', 105, 131, 440, 96)],
    'bp_popup_f6': [('pop_boss', 300, 420, 200, 80), ('pop_a1', 740, 180, 160, 70), ('pop_a2', 660, 290, 300, 70)],
    'bp_popup_f20': [('pop_boss', 280, 380, 220, 120), ('pop_a1', 740, 140, 200, 110), ('pop_a2', 660, 250, 320, 110)],
    'bp_popup_f40': [('pop_boss', 260, 330, 240, 170), ('pop_a1', 740, 100, 240, 150), ('pop_a2', 660, 200, 340, 160)],
    # 二期（rules-battle-pixel2）
    'bp2_layout': [('enemies', 130, 250, 300, 230), ('actors', 770, 160, 110, 390), ('status', 990, 0, 290, 470), ('command', 850, 460, 225, 200)],
    'bp2_anim_f4': [('anim_enemy', 130, 150, 280, 270), ('anim_actor', 640, 40, 350, 330)],
    'bp2_anim_f12': [('anim_enemy', 130, 150, 280, 270), ('anim_actor', 640, 40, 350, 330)],
    'bp2_anim_f24': [('anim_enemy', 130, 150, 280, 270), ('anim_actor', 640, 40, 350, 330)],
    'bp2_victory_zoom_f60': [('field', 600, 0, 680, 720)],
    'bp2_victory_win_f40': [('title', 90, 90, 300, 80), ('rewards', 90, 175, 500, 85), ('rows', 100, 285, 490, 330), ('actors', 780, 0, 200, 560), ('hint', 830, 660, 360, 50)],
    'bp2_victory_win_f300': [('title', 90, 90, 300, 80), ('rewards', 90, 175, 500, 85), ('rows', 100, 285, 490, 330), ('actors', 780, 0, 200, 560), ('hint', 830, 660, 360, 50)],
    'bp2_defeat_f30': [('message', 0, 545, 1280, 175), ('actors', 770, 160, 110, 390)],
    'bp2_defeat_f90': [('message', 0, 545, 1280, 175), ('actors', 770, 160, 110, 390)],
}


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
    rows, prev = [], bytearray(stride)
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
        rows.append(bytes(line) if bpp == 3 else bytes(v for i, v in enumerate(line) if i % 4 != 3))
        prev = line
    return w, h, rows


def write_png(path, w, h, rows):
    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    def chunk(k, b):
        return struct.pack('>I', len(b)) + k + b + struct.pack('>I', zlib.crc32(k + b) & 0xffffffff)
    Path(path).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))


def crop(rows, x, y, w, h):
    return [r[x * 3:(x + w) * 3] for r in rows[y:y + h]]


def ink_box(c):
    xs, ys, n = [], [], 0
    for yy, r in enumerate(c):
        for xx in range(len(r) // 3):
            if max(r[xx * 3:xx * 3 + 3]) > INK:
                xs.append(xx); ys.append(yy); n += 1
    if not xs:
        return None, 0
    return [min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1], n


def main():
    ref, gd, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    for shot, regs in REGIONS.items():
        if not (ref / (shot + '.png')).exists() or not (gd / (shot + '.png')).exists():
            print('缺图', shot); continue
        _, _, a = read_png(ref / (shot + '.png'))
        _, _, b = read_png(gd / (shot + '.png'))
        for name, x, y, w, h in regs:
            ca, cb = crop(a, x, y, w, h), crop(b, x, y, w, h)
            tot = big = 0
            for ra, rb in zip(ca, cb):
                for i in range(0, len(ra), 3):
                    d = max(abs(ra[i] - rb[i]), abs(ra[i + 1] - rb[i + 1]), abs(ra[i + 2] - rb[i + 2]))
                    tot += d; big += d > THRESH
            n = w * h
            ba, na = ink_box(ca)
            bb, nb = ink_box(cb)
            edge = [bb[0] - ba[0], bb[1] - ba[1], bb[0] + bb[2] - ba[0] - ba[2], bb[1] + bb[3] - ba[1] - ba[3]] if ba and bb else None
            report[shot + '/' + name] = {'mean': round(tot / n, 1), 'big': round(big / n, 3), 'ink_ref': ba, 'ink_gd': bb,
                                         'ink_px': [na, nb], 'edge_dl_dt_dr_db': edge}
            # 上原版下 Godot，放大 2 倍
            rows = []
            for c in (ca, [bytes([255, 0, 255]) * w], cb):
                for r in c:
                    rr = bytearray()
                    for i in range(0, len(r), 3):
                        rr += r[i:i + 3] * 2
                    rows += [rr, rr]
            write_png(out / f'{shot}_{name}.png', w * 2, len(rows), rows)
    (out / 'battle_pixel_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=1))
    print(f"{'区域':<34}{'平均差':>6}{'差>32':>7}  墨迹框 原版 → Godot（四边差 左上右下）")
    for k, v in report.items():
        print(f"{k:<36}{v['mean']:>6}{v['big']:>7}  {v['ink_ref']} → {v['ink_gd']}  {v['edge_dl_dt_dr_db']}  墨迹像素 {v['ink_px']}")


if __name__ == '__main__':
    main()
