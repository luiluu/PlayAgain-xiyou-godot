#!/usr/bin/env python3
"""裁字：把新界面的三款字体裁成只含游戏用到的字（ui-skin-p0，界面风格提案 v0.7 第四节「字体」）。

字从哪来（只读）：
  正文（思源黑体 Medium）：游戏数据 generated/db 与 generated/maps 里的全部字符串、工程 .gd 里的字符串字面量（不收注释）、
                          modes／content 下的 .json 文本、天启篇数据；再加常用标点、全角符号、ASCII。
  标题（思源宋体 Heavy）：只收「名字」类：.gd 字符串字面量＋数据库里的 name／nickname／profile 以外的名字字段（name、nickname）、
                          天启篇数据的名字；页名、牌上的名字用它，说明文字不用。
  数字（窄体数字字 Barlow Condensed Medium）：ASCII 可见字符＋常用数字符号（×÷±·、千分位、%）。
缺字时游戏里自动落回原字体（XUiSkin.font 的 fallbacks），所以新数据里出现没收进来的字也不会变方块，只是那个字换成原字体。

用法：
  python3 裁字.py --list                        只统计字数（不需要 fontTools）
  python3 裁字.py --hei 源.otf --song 源.otf --num 源.ttf   裁好写到 content/ui_skin/fonts/（同时写字表 charset_*.txt）
源字体不入库（太大），下载地址见 content/ui_skin/README.md。需要 fontTools：没装时照提示建个 venv 装（pip install fonttools）。
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
OUT = PROJECT / 'content' / 'ui_skin' / 'fonts'
GEN = PROJECT / 'modes' / 'xiyou' / 'generated'
## 不收的文件：拼音排序表（全部汉字都在里面，不是显示用的）、插件参数（不显示）
SKIP = ('zh_collate_data.gd', 'zh_collation.json', 'Plugins.json')
## 输出文件名与字体内部名。思源的授权（SIL OFL 1.1）保留了字名「Source」，裁过的算改版，不能再用这个名，所以改名；
## Barlow 没有保留字名，也一并改成同一套叫法。授权文本随字体放在 content/ui_skin/fonts/（OFL 要求随附）。
NAMES = {'hei': 'TianqiUiSans-Medium.otf', 'song': 'TianqiUiSerif-Heavy.otf', 'num': 'TianqiUiNum-Medium.ttf'}
FAMILY = {'hei': ('Tianqi UI Sans', 'Medium'), 'song': ('Tianqi UI Serif', 'Heavy'), 'num': ('Tianqi UI Num', 'Medium')}

STR_LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'')
ASCII = ''.join(chr(c) for c in range(0x20, 0x7f))
PUNCT = '，。、；：？！…—～·「」『』（）【】《》〈〉“”‘’％＋－×÷±≤≥→←↑↓▲▼◆◇○●☆★、　０１２３４５６７８９'
NUM_EXTRA = '×÷±·%‰+-−.,:/ ()[]'


def gd_literals(path):
    out = []
    for line in path.read_text(encoding='utf-8', errors='ignore').splitlines():
        code = line.split('#', 1)[0] if '"' not in line and "'" not in line else _strip_comment(line)
        for m in STR_LIT.finditer(code):
            out.append(m.group(1) or m.group(2) or '')
    return out


def _strip_comment(line):
    """去掉行尾注释（引号里的 # 不算）"""
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == '\\':
                continue
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
        elif ch == '#':
            return line[:i]
    return line


def walk_json(v, out, name_only=False, key=''):
    if isinstance(v, str):
        if not name_only or key in ('name', 'nickname', 'title', 'label'):
            out.append(v)
    elif isinstance(v, list):
        for x in v:
            walk_json(x, out, name_only, key)
    elif isinstance(v, dict):
        for k, x in v.items():
            walk_json(x, out, name_only, k)


def load_json(p):
    try:
        return json.loads(p.read_text(encoding='utf-8'))
    except Exception:
        return None


def collect():
    body, title = [], []
    for p in sorted((PROJECT / 'modes').rglob('*.gd')) + sorted((PROJECT / 'core').rglob('*.gd')) + sorted((PROJECT / 'scenes').rglob('*.gd')):
        if '/generated/' in str(p) or p.name in SKIP:
            continue
        lits = gd_literals(p)
        body += lits
        title += lits
    jsons = [p for p in (PROJECT / 'modes').rglob('*.json') if '/generated/' not in str(p)] + list((PROJECT / 'content').rglob('*.json'))
    for d in ('db', 'maps'):
        jsons += sorted((GEN / d).glob('*.json'))
    for p in jsons:
        if p.name in SKIP:
            continue
        data = load_json(p)
        if data is None:
            continue
        walk_json(data, body)
        walk_json(data, title, name_only=True)
    chars = lambda xs: set(''.join(xs))
    b = chars(body) | set(ASCII) | set(PUNCT)
    t = chars(title) | set(ASCII) | set(PUNCT)
    n = set(ASCII) | set(NUM_EXTRA)
    clean = lambda s: sorted(c for c in s if c.isprintable() or c == '　')
    return clean(b), clean(t), clean(n)


def rename(font, family, style):
    """改字体内部名（家族、全名、PostScript 名、唯一标识），去掉保留字名"""
    ps = family.replace(' ', '') + '-' + style
    names = {1: family, 2: 'Regular', 3: ps + ';subset', 4: family + ' ' + style, 6: ps, 16: family, 17: style}
    table = font['name']
    for rec in list(table.names):
        if rec.nameID in names:
            table.removeNames(nameID=rec.nameID)
    for nid, val in names.items():
        table.setName(val, nid, 3, 1, 0x409)
        table.setName(val, nid, 1, 0, 0)
    if 'CFF ' in font:
        cff = font['CFF '].cff
        cff.fontNames = [ps]
        top = cff.topDictIndex[0]
        for attr in ('FullName', 'FamilyName'):
            if hasattr(top, attr):
                setattr(top, attr, family + (' ' + style if attr == 'FullName' else ''))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--hei')
    ap.add_argument('--song')
    ap.add_argument('--num')
    a = ap.parse_args()
    if not GEN.joinpath('db').is_dir():
        print('✗ 没有 generated/db：先在工作树跑 新建工作树.sh --补齐', file=sys.stderr)
        return 2
    body, title, num = collect()
    print(f'正文 {len(body)} 字，标题 {len(title)} 字，数字 {len(num)} 字')
    if a.list:
        return 0
    try:
        from fontTools import subset
    except ImportError:
        print('✗ 需要 fontTools：python3 -m venv <目录> && <目录>/bin/pip install fonttools，再用 <目录>/bin/python 跑本脚本', file=sys.stderr)
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    for key, src, chars in (('hei', a.hei, body), ('song', a.song, title), ('num', a.num, num)):
        if not src:
            continue
        (OUT / f'charset_{key}.txt').write_text(''.join(chars), encoding='utf-8')
        opts = subset.Options()
        opts.layout_features = ['kern', 'liga', 'palt', 'vert', 'tnum', 'lnum']
        opts.name_IDs = ['*']
        opts.name_languages = ['*']
        opts.notdef_outline = True
        opts.hinting = False
        opts.desubroutinize = False
        font = subset.load_font(src, opts)
        sub = subset.Subsetter(opts)
        sub.populate(text=''.join(chars))
        sub.subset(font)
        dst = OUT / NAMES[key]
        rename(font, *FAMILY[key])
        subset.save_font(font, str(dst), opts)
        print(f'✓ {dst.relative_to(PROJECT)}  {dst.stat().st_size // 1024} KB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
