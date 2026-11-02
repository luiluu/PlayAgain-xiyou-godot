#!/usr/bin/env python3
"""宿傩领域法阵成对截图（八戒 visual2）：原版 PIXI 画法与 Godot XBattleIndicators.DomainCircle 同一帧比像素。

原版：用冻结正式源的 js/libs/pixi.js（v4.5.4）照 installNativeCharacterVisualRuntime.js 的 domainCircle 逐行画
（root 压扁 0.34、图形转 tick×0.003、透明度 0.82+cos(tick×0.04)×0.08），黑底 256×128、圆心 (128,64)，
本机 Google Chrome 无头 --screenshot 截图（静音、临时用户目录）。只读冻结源，只写输出目录。
Godot：tests/xiyou_indicator_shot -- --out=<目录> 写 domain_circle_godot.png（同底色、同圆心、同 tick）。

用法：python3 -I domain_circle_ref.py <app.nw> <输出目录> [Godot 截图目录]
有 Godot 截图时打印并写 domain_circle_compare.json：逐像素平均差、红色掩码（R>40）的交并比、两边掩码像素数。
"""
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
import zlib

TICK = 30
W, H = 256, 128
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

PAGE = """<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;background:#000;overflow:hidden}canvas{display:block}</style>
<script src="%(pixi)s"></script></head><body><script>
var renderer = PIXI.autoDetectRenderer(%(w)d, %(h)d, {backgroundColor: 0x000000, antialias: false, preserveDrawingBuffer: true});
document.body.appendChild(renderer.view);
var stage = new PIXI.Container();
// —— 以下照 domainCircle(owner) 原文（Sprite 换成 PIXI.Container，其余不变）——
var root = new PIXI.Container(), drawing = new PIXI.Graphics(), red = 0xf32b40;
root.addChild(drawing);
root.scale.y = 0.34;
drawing.beginFill(red, 0.07);
drawing.drawCircle(0, 0, 88);
drawing.endFill();
drawing.lineStyle(7, 0x24030b, 0.8);
drawing.drawCircle(0, 0, 88);
drawing.drawCircle(0, 0, 73);
drawing.lineStyle(2.5, red, 0.95);
drawing.drawCircle(0, 0, 88);
drawing.lineStyle(1.5, red, 0.85);
drawing.drawCircle(0, 0, 73);
drawing.drawCircle(0, 0, 49);
for (var triangle = 0; triangle < 2; triangle++) {
    for (var point = 0; point <= 3; point++) {
        var angle = -Math.PI / 2 + triangle * Math.PI + point * Math.PI * 2 / 3;
        var x = Math.cos(angle) * 59, y = Math.sin(angle) * 59;
        if (!point) drawing.moveTo(x, y); else drawing.lineTo(x, y);
    }
}
for (var glyph = 0; glyph < 12; glyph++) {
    var a = glyph * Math.PI / 6, cos = Math.cos(a), sin = Math.sin(a);
    drawing.moveTo(cos * 77 - sin * 3, sin * 77 + cos * 3);
    drawing.lineTo(cos * 84 - sin * 3, sin * 84 + cos * 3);
    drawing.lineTo(cos * 84 + sin * 3, sin * 84 - cos * 3);
    drawing.moveTo(cos * 80 - sin * 5, sin * 80 + cos * 5);
    drawing.lineTo(cos * 80 + sin * 5, sin * 80 - cos * 5);
}
// —— updateIndicators 推进 %(tick)d 帧 ——
for (var t = 1; t <= %(tick)d; t++) { root.alpha = 0.82 + Math.cos(t * 0.04) * 0.08; drawing.rotation += 0.003; }
root.x = %(cx)d; root.y = %(cy)d;
stage.addChild(root);
renderer.render(stage);
</script></body></html>
"""


def _read_png(path):
    """最小 PNG 解码（8 位 RGB／RGBA、不隔行；本机没装 PIL）：返回 (宽, 高, 每像素 RGB 元组的行列表)"""
    data = pathlib.Path(path).read_bytes()
    pos, idat, w = 8, b'', 0
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b'IHDR':
            w, h, depth, color = struct.unpack('>IIBB', body[:10])
            assert depth == 8 and color in (2, 6), (depth, color)
            bpp = 3 if color == 2 else 4
        elif kind == b'IDAT':
            idat += body
        pos += 12 + n
    raw, stride, rows, prev = zlib.decompress(idat), w * bpp, [], bytearray(w * bpp)
    for y in range(h):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b, c = prev[i], prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[x * bpp:x * bpp + 3]) for x in range(w)])
        prev = line
    return w, h, rows


def _mask_stats(a, b):
    _, _, pa = _read_png(a)
    _, _, pb = _read_png(b)
    diff = inter = union = na = nb = 0
    for y in range(H):
        for x in range(W):
            ra, rb = pa[y][x], pb[y][x]
            diff += sum(abs(ra[i] - rb[i]) for i in range(3))
            ma, mb = ra[0] > 40, rb[0] > 40
            na += ma
            nb += mb
            inter += ma and mb
            union += ma or mb
    return {'mean_abs_diff': round(diff / (W * H * 3), 3), 'mask_iou': round(inter / max(union, 1), 4), 'mask_ref': na, 'mask_godot': nb}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 64
    app = pathlib.Path(sys.argv[1]).resolve()
    out = pathlib.Path(sys.argv[2]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    pixi = app / 'js' / 'libs' / 'pixi.js'
    html = out / 'domain_circle_ref.html'
    html.write_text(PAGE % {'pixi': pixi.as_uri(), 'w': W, 'h': H, 'cx': W // 2, 'cy': H // 2, 'tick': TICK}, encoding='utf-8')
    shot = out / 'domain_circle_ref.png'
    with tempfile.TemporaryDirectory() as profile:
        subprocess.run([CHROME, '--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
                        '--allow-file-access-from-files', '--hide-scrollbars', '--force-device-scale-factor=1',
                        f'--user-data-dir={profile}', f'--window-size={W},{H}', f'--screenshot={shot}', html.as_uri()],
                       check=True, capture_output=True, timeout=120)
    print('原版参照：', shot)
    if len(sys.argv) > 3:
        godot = pathlib.Path(sys.argv[3]).resolve() / 'domain_circle_godot.png'
        stats = _mask_stats(shot, godot)
        (out / 'domain_circle_compare.json').write_text(json.dumps(stats, ensure_ascii=False, indent=1), encoding='utf-8')
        print('对比：', json.dumps(stats, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
