#!/usr/bin/env python3
"""战斗画面淡出淡入／闪烁截图对照（rules-gaps11）：原版 battle_screen_fx_ref.cjs 的 gb9_*.png 对 Godot
xiyou_battle_ui 窗口模式（-- --out=目录）的 battle_40_input／battle_60*.png。两边战斗背景、敌我数据不同，
不逐像素比整图，而是各自拿输入阶段截图当底，在战斗画面区（0,100)-(840,440) 拟合
淡出：截图 = 底 × 亮度/255，闪烁：截图 = 底 ×(1-α) + 红 × α，比两边拟合出的亮度／闪烁强度（同一帧应差 1 以内）。
淡出到黑后的消息截图另比消息窗区 (0,274)-(1280,446) 的平均色。本机没装 PIL，用最小 PNG 解码。
用法：python3 -I battle_screen_fx_compare.py <原版截图目录> <Godot 截图目录>
"""
import sys, struct, zlib, pathlib, json
def rd(path):
    data = pathlib.Path(path).read_bytes(); pos, idat = 8, b''
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos+8]); body = data[pos+8:pos+8+n]
        if kind == b'IHDR':
            w, h, depth, color = struct.unpack('>IIBB', body[:10]); bpp = 3 if color == 2 else 4
        elif kind == b'IDAT': idat += body
        pos += 12 + n
    raw, stride, rows, prev = zlib.decompress(idat), w*bpp, [], bytearray(w*bpp)
    for y in range(h):
        f, line = raw[y*(stride+1)], bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        for i in range(stride):
            a = line[i-bpp] if i >= bpp else 0; b = prev[i]; c = prev[i-bpp] if i >= bpp else 0
            if f == 1: line[i] = (line[i]+a) & 255
            elif f == 2: line[i] = (line[i]+b) & 255
            elif f == 3: line[i] = (line[i]+(a+b)//2) & 255
            elif f == 4:
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                line[i] = (line[i]+(a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line); prev = line
    return w, h, bpp, rows
def mean(path, box):
    w, h, bpp, rows = rd(path); x0, y0, x1, y1 = box; s = [0, 0, 0]; n = 0
    for y in range(y0, y1, 2):
        for x in range(x0, x1, 2):
            for k in range(3): s[k] += rows[y][x*bpp+k]
            n += 1
    return [round(v/n, 2) for v in s]
BOX = (0, 100, 840, 440)
def px(path):
    w, h, bpp, rows = rd(path); x0, y0, x1, y1 = BOX
    return [(rows[y][x*bpp], rows[y][x*bpp+1], rows[y][x*bpp+2]) for y in range(y0, y1, 3) for x in range(x0, x1, 3)]
def fit_fade(inp, shot):   # shot = inp * t  → t 最小二乘
    num = sum(a*b for p, q in zip(inp, shot) for a, b in zip(p, q)); den = sum(a*a for p in inp for a in p)
    t = num/den; err = sum(abs(b - a*t) for p, q in zip(inp, shot) for a, b in zip(p, q)) / (len(inp)*3)
    return round(t*255, 2), round(err, 2)
def fit_flash(inp, shot, col=(255, 0, 0)):   # shot = inp*(1-a) + col*a
    num = den = 0
    for p, q in zip(inp, shot):
        for k in range(3):
            d = col[k] - p[k]; num += (q[k] - p[k]) * d; den += d*d
    a = num/den; err = sum(abs(q[k] - (p[k]*(1-a) + col[k]*a)) for p, q in zip(inp, shot) for k in range(3)) / (len(inp)*3)
    return round(a*255, 2), round(err, 2)
ref, gd = sys.argv[1], sys.argv[2]
ri, gi = px(f'{ref}/gb9_input.png'), px(f'{gd}/battle_40_input.png')
out = {}
for a, b in [('gb9_fade_f12', 'battle_60_fade_f12'), ('gb9_fade_f24', 'battle_60b_fade_f24')]:
    out[a] = {'原版 亮度,误差': fit_fade(ri, px(f'{ref}/{a}.png')), 'Godot 亮度,误差': fit_fade(gi, px(f'{gd}/{b}.png'))}
out['gb9_flash_f5'] = {'原版 闪烁强度,误差': fit_flash(ri, px(f'{ref}/gb9_flash_f5.png')), 'Godot 闪烁强度,误差': fit_flash(gi, px(f'{gd}/battle_60d_flash_f5.png'))}
out['消息窗区平均色'] = {'原版': mean(f'{ref}/gb9_fade_message.png', (0, 274, 1280, 446)), 'Godot': mean(f'{gd}/battle_60c_fade_message.png', (0, 274, 1280, 446))}
print(json.dumps(out, ensure_ascii=False, indent=1))
