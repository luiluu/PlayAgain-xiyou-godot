#!/usr/bin/env python3
"""只读扫描：从 s.flags（存档走 JSON 读回）取出的数组／字典，被整数当参数 find／has／count／erase 的可疑处。

背景：存档 JSON 读回后，数组里的整数变成浮点（[8] → [8.0]，[8.0].find(8) 为 -1），字典的整数键变成字符串（{8: 1} → {"8": 1}，
has(8) 为假）。xuan-fix1 修过一处（xuan_chart 的 roster）；审查 32 提了要全工程扫一遍（tools53）。

做法（静态、粗筛，宁多勿漏，结果要人看）：每个函数里，
1. 来源：直接含 `flags` 的赋值，或调用「返回值含 flags」的函数（如 XXuanChart.chart(s)）；
2. 向下传：右边含来源变量的赋值，左边变量也算（`.size()`／`int(`／`str(`／`bool(` 包住的不传）；
3. 在同函数里找 `<这些变量或 flags 表达式>.find(／rfind(／has(／count(／erase(／bsearch(` 与 `X in <变量>`，
   参数是字符串字面量、`str(`／`int(` 包住、带 `%`、`.hash()` 的算「已归一」，不报；其余报出，标参数种类。
只读 .gd，不改任何文件；结果按文件、行号排序，同一输入输出相同。

用法：python3 扫描_flags整数查找.py [--root 工程目录] [--all]（--all 连同已归一的也打出来）
"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
CALLS = r'(?:find|rfind|has|count|erase|bsearch|find_custom)'
FUNC = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\(')
ASSIGN = re.compile(r'^\s*(?:var|const)?\s*(\w+)\s*(?::\s*[\w\[\]]+\s*)?(?::=|=)\s*(.+)$')
NORMAL = re.compile(r'^\s*(?:"[^"]*"|\'[^\']*\'|&"[^"]*"|(?:str|int|String|StringName)\s*\(.*\)|.*%.*|.*\.hash\(\).*)\s*$')


def call_arg(text, start):
    """text[start] 是 '(' 之后一位，返回括号匹配的实参文本。"""
    depth, i = 1, start
    while i < len(text) and depth:
        c = text[i]
        depth += (c in '([{') - (c in ')]}')
        i += 1
    return text[start:i - 1] if depth == 0 else text[start:]


def functions(lines):
    """[(名, 起始行号, [(行号, 文本)...])]；顶格非注释行结束函数体。"""
    out, cur = [], None
    for n, line in enumerate(lines, 1):
        m = FUNC.match(line)
        if m:
            cur = (m.group(1), n, [])
            out.append(cur)
        elif cur is not None:
            if line.strip() and not line.startswith(('\t', ' ', '#')):
                cur = None
            else:
                cur[2].append((n, line))
    return out


def source_functions(files):
    """返回值含 flags 的函数名（粗：函数体里 return 那行含 flags）。"""
    names = set()
    for lines in files.values():
        for name, _, body in functions(lines):
            if any(re.search(r'\breturn\b.*\bflags\b', t) for _, t in body):
                names.add(name)
    return names


def scan_function(body, sources, show_all):
    tainted, hits = set(), []
    src_call = re.compile(r'\b(?:%s)\s*\(' % '|'.join(sorted(sources))) if sources else None

    def tainted_expr(expr):
        if re.search(r'\bflags\b', expr) or (src_call and src_call.search(expr)):
            return True
        return any(re.search(r'\b%s\b' % re.escape(v), expr) for v in tainted)

    for n, raw in body:
        code = raw.split('#', 1)[0]
        m = ASSIGN.match(code)
        if m and tainted_expr(m.group(2)) and not re.search(r'\.size\(\)|\bint\(|\bstr\(|\bbool\(', m.group(2)):
            tainted.add(m.group(1))
        for cm in re.finditer(r'([\w\.\[\]"\'()]*?)\.(%s)\(' % CALLS, code):
            recv, call = cm.group(1), cm.group(2)
            arg = call_arg(code, cm.end()).strip()
            if not (tainted_expr(recv) or re.search(r'\bflags\b', code[max(0, cm.start() - 40):cm.end()])):
                continue
            norm = bool(NORMAL.match(arg))
            if re.fullmatch(r'-?\d+', arg):
                kind = '数字字面量'
            elif norm:
                kind = '已归一'
            elif re.fullmatch(r'\w+', arg):
                kind = '变量'
            else:
                kind = '表达式'
            if norm and not show_all:
                continue
            hits.append((n, kind, call, arg, raw.strip()))
        for im in re.finditer(r'(?<![\w.])([^\s()]+(?:\([^)]*\))?)\s+in\s+(\w+)\b', code):
            if im.group(2) in tainted and not NORMAL.match(im.group(1)):
                hits.append((n, '变量' if re.fullmatch(r'\w+', im.group(1)) else '表达式', 'in', im.group(1), raw.strip()))
    return hits


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', type=Path, default=PROJECT)
    ap.add_argument('--all', action='store_true')
    a = ap.parse_args(argv)
    paths = sorted((a.root / 'modes').rglob('*.gd'))
    files = {p: p.read_text(encoding='utf-8').splitlines() for p in paths}
    sources = source_functions(files)
    total = 0
    for p, lines in files.items():
        for name, _, body in functions(lines):
            for n, kind, call, arg, text in scan_function(body, sources, a.all):
                total += 1
                print('%s:%d [%s] %s(%s) 在 %s()：%s' % (p.relative_to(a.root), n, kind, call, arg, name, text))
    print('== 共 %d 处（返回值含 flags 的函数 %d 个：%s）' % (total, len(sources), ' '.join(sorted(sources))), file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
