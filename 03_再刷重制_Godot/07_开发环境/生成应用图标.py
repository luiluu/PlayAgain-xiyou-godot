#!/usr/bin/env python3
"""应用图标一键生成（BI 正式入口，cc 2026-11-05）：一张原图 → Mac icns、Windows ico、安卓自适应图标。

  python3 生成应用图标.py <原图>            原图可以是 png／jpg；先按原样当正方形素材用
  python3 生成应用图标.py <原图> --trim     原图带白色外边或圆角时用：把贴边的亮色外边灌成暗底再裁掉
  python3 生成应用图标.py <原图> --android-scale 0.8   安卓前景里画面占多大（默认 0.85；越小越不容易被圆形遮罩切到）

输出（全部覆盖写到 01_Godot工程/content/app_icon/，该目录有 .gdignore，不进游戏包，只给导出预设读）：
  icon_source_1024.png      整理后的 1024 方图（以后都从它生成）
  icon.icns                 macOS（16～1024 各档，照系统规格：画面 824 居中、圆角外透明，iconutil 生成）
  icon.ico                  Windows（16、32、48、64、128、256，PNG 内嵌）
  icon_256.png              窗口／通用
  android_main_192.png、android_foreground_432.png、android_background_432.png   安卓
  来源.json                 原图路径、SHA-256、参数、生成时间
换图：把新图丢进来重跑这一条命令，再照常导出；预设已经指向这些文件，不用改预设。
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = ROOT / '01_Godot工程' / 'content' / 'app_icon'
GODOT = HERE / 'godot'
ICO_SIZES = [16, 32, 48, 64, 128, 256]
ICNS = [(16, 'icon_16x16'), (32, 'icon_16x16@2x'), (32, 'icon_32x32'), (64, 'icon_32x32@2x'),
        (128, 'icon_128x128'), (256, 'icon_128x128@2x'), (256, 'icon_256x256'), (512, 'icon_256x256@2x'),
        (512, 'icon_512x512'), (1024, 'icon_512x512@2x')]


def png_size(data: bytes):
    return struct.unpack('>II', data[16:24])


def write_ico(pngs, path: Path):
    """ICO 容器，每档直接内嵌 PNG（Windows Vista 起支持）。256 档宽高字段写 0。"""
    head = struct.pack('<HHH', 0, 1, len(pngs))
    offset = 6 + 16 * len(pngs)
    entries, blobs = b'', b''
    for data in pngs:
        w, h = png_size(data)
        entries += struct.pack('<BBBBHHII', w % 256, h % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
        blobs += data
    path.write_bytes(head + entries + blobs)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('source')
    ap.add_argument('--trim', action='store_true')
    ap.add_argument('--android-scale', type=float, default=0.85)
    ap.add_argument('--out', default=str(OUT))
    a = ap.parse_args()
    src = Path(a.source).expanduser().resolve()
    if not src.is_file():
        print(f'找不到原图：{src}', file=sys.stderr)
        return 2
    out = Path(a.out)
    with tempfile.TemporaryDirectory(prefix='app_icon_') as tmp:
        tmp = Path(tmp)
        cmd = [str(GODOT), '--headless', '--script', str(HERE / '生成应用图标.gd'), '--',
               f'--in={src}', f'--out={tmp}', f'--android-scale={a.android_scale}'] + (['--trim'] if a.trim else [])
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', timeout=300)
        if p.returncode != 0 or 'ICON_OK' not in p.stdout:
            print(p.stdout[-3000:], file=sys.stderr)
            print('Godot 处理图片失败', file=sys.stderr)
            return 1
        bg = p.stdout.split('ICON_OK bg=')[-1].split()[0]
        iconset = tmp / 'icon.iconset'
        iconset.mkdir()
        for n, name in ICNS:
            shutil.copy(tmp / f'icon_mac_{n}.png', iconset / f'{name}.png')
        subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(tmp / 'icon.icns')], check=True)
        write_ico([(tmp / f'icon_{n}.png').read_bytes() for n in ICO_SIZES], tmp / 'icon.ico')
        out.mkdir(parents=True, exist_ok=True)
        (out / '.gdignore').write_text('', encoding='utf-8')
        for name in ['icon_source_1024.png', 'icon.icns', 'icon.ico', 'android_main_192.png',
                     'android_foreground_432.png', 'android_background_432.png']:
            shutil.copy(tmp / name, out / name)
        shutil.copy(tmp / 'icon_256.png', out / 'icon_256.png')
    info = {'source': src.name, 'sha256': hashlib.sha256(src.read_bytes()).hexdigest(), 'trim': a.trim,
            'androidScale': a.android_scale, 'background': '#' + bg,
            'generated': datetime.datetime.now().astimezone().isoformat(timespec='seconds')}
    (out / '来源.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'已生成到 {out}（暗底 #{bg}）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
