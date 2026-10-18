#!/usr/bin/env python3
"""变更记录分卷：把较早的条目整段移进只读分卷，当前卷只留近期条目。

用法（在资料库任意位置运行）：
  变更记录分卷.py                     只读：显示当前卷大小、条目数与已有分卷
  变更记录分卷.py split [--keep-days N | --before YYYY-MM-DD] [--dry-run]
                                      把日期早于界限的开头连续条目移进新分卷（默认保留最近 2 个日期）
  变更记录分卷.py --check             检查.sh 调用：分卷＋当前卷连起来的历史只追加（对比 HEAD）

分卷放在 00_项目管理/变更记录卷/，文件名 变更记录_<首日>至<末日>.md；条目原文不改，
只把相对链接改写成从分卷目录出发、指向同一目标。只由总装在 main 上合并时运行（变更记录是共用文件）。
"""
import argparse
import datetime as dt
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LOG = PurePosixPath('00_项目管理/变更记录.md')
VOLUMES = PurePosixPath('00_项目管理/变更记录卷')
ENTRY = re.compile(r'^## (\d{4}-\d{2}-\d{2})\b', re.M)
LINK = re.compile(r'\]\((<[^>]+>|[^)\s]+)\)')
INDEX = '更早的记录（只读分卷）：'


def entries(text):
    """切成（日期, 原文）列表；非日期标题（如条目内的「## 交接板」）算前一条的续文。"""
    starts = [m.start() for m in ENTRY.finditer(text)]
    head = text[:starts[0]] if starts else text
    body = [(ENTRY.match(text, s).group(1), text[s:e].rstrip('\n') + '\n')
            for s, e in zip(starts, starts[1:] + [len(text)])]
    return head, body


def is_relative(ref):
    ref = ref.strip('<>')
    return bool(ref) and not ref.startswith(('/', '#', '~')) and '://' not in ref and not ref.startswith('mailto:')


def resolve_links(text, rel_dir):
    """把相对链接换成资料库根目录起算的路径，用来比较搬动前后的正文是否一致。"""
    def sub(m):
        ref = m.group(1)
        if not is_relative(ref):
            return m.group(0)
        raw = ref.strip('<>')
        path, sep, anchor = raw.partition('#')
        return '](' + os.path.normpath(os.path.join(rel_dir, path)) + sep + anchor + ')'
    return LINK.sub(sub, text)


def relink(text, src_dir, dst_dir):
    """条目从 src_dir 移到 dst_dir 后，相对链接仍指向原目标。"""
    def sub(m):
        ref = m.group(1)
        if not is_relative(ref):
            return m.group(0)
        wrapped = ref.startswith('<')
        raw = ref.strip('<>')
        path, sep, anchor = raw.partition('#')
        new = os.path.relpath(os.path.normpath(os.path.join(src_dir, path)), dst_dir) + sep + anchor
        return '](' + ('<' + new + '>' if wrapped else new) + ')'
    return LINK.sub(sub, text)


def history(read, names):
    """分卷（按文件名排序）＋当前卷的条目正文，链接统一成根目录路径。read(rel) 返回文本或 None。"""
    parts = []
    for name in sorted(names):
        text = read(str(VOLUMES / name))
        if text is not None:
            parts += [resolve_links(e, str(VOLUMES)) for _, e in entries(text)[1]]
    current = read(str(LOG))
    if current is not None:
        parts += [resolve_links(e, str(LOG.parent)) for _, e in entries(current)[1]]
    return parts


def volume_names(root):
    d = root / VOLUMES
    return [p.name for p in d.glob('变更记录_*.md')] if d.is_dir() else []


def head_volume_names(root):
    out = subprocess.run(['git', '-c', 'core.quotePath=false', 'ls-tree', '--name-only', 'HEAD', str(VOLUMES) + '/'],
                         cwd=root, capture_output=True, text=True).stdout.split()
    return [PurePosixPath(p).name for p in out if PurePosixPath(p).name.startswith('变更记录_')]


def git_show(root, rel):
    p = subprocess.run(['git', 'show', 'HEAD:' + rel], cwd=root, capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


def check(root):
    """历史只追加：HEAD 的全部条目必须原样排在现在的分卷＋当前卷开头（只允许在末尾追加，或整条移进分卷）。"""
    before = history(lambda rel: git_show(root, rel), head_volume_names(root))
    if not before:
        return []
    after = history(lambda rel: (root / rel).read_text() if (root / rel).is_file() else None, volume_names(root))
    norm = lambda e: e.rstrip()
    for i, old in enumerate(before):
        last = i == len(before) - 1  # 最后一条允许在末尾续写
        if i >= len(after) or not (after[i].rstrip().startswith(norm(old)) if last else norm(after[i]) == norm(old)):
            date = ENTRY.match(old).group(1)
            title = old.split('\n', 1)[0][14:60]
            return [f'变更记录的既有正文被改写或删除（第 {i + 1} 条，{date} {title}…）；请恢复历史后只追加本轮记录']
    return []


def index_line(names):
    links = []
    for name in sorted(names):
        label = name.removeprefix('变更记录_').removesuffix('.md')
        links.append(f'[{label}](变更记录卷/{name})')
    return INDEX + '、'.join(links) + '。'


def split(root, before, dry_run=False):
    path = root / LOG
    text = path.read_text()
    head, body = entries(text)
    k = 0
    while k < len(body) and body[k][0] < before:
        k += 1
    if k == 0:
        print(f'没有早于 {before} 的开头条目，不分卷')
        return None
    moved, kept = body[:k], body[k:]
    first, last = min(d for d, _ in moved), max(d for d, _ in moved)
    names = volume_names(root)
    name, n = f'变更记录_{first}至{last}.md', 2
    while name in names:
        name, n = f'变更记录_{first}至{last}_{n}.md', n + 1
    vol_text = (f'# 变更记录分卷 {first} 至 {last}\n\n只读分卷，由 `变更记录分卷.py split` 从[当前卷](../变更记录.md)移来；'
                '条目原文不改，只调整相对链接。\n\n'
                + '\n'.join(relink(e, str(LOG.parent), str(VOLUMES)) for _, e in moved))
    head_lines = [l for l in head.rstrip('\n').split('\n') if not l.startswith(INDEX)]
    while head_lines and not head_lines[-1].strip():
        head_lines.pop()
    new_head = '\n'.join(head_lines) + '\n\n' + index_line(names + [name]) + '\n\n'
    new_text = new_head + '\n'.join(e for _, e in kept)
    size = lambda s: f'{len(s.encode()) / 1024:.0f} KB'
    print(f'移出 {k} 条（{first}～{last}，{size(vol_text)}）到 {VOLUMES / name}；当前卷留 {len(kept)} 条，{size(text)} → {size(new_text)}')
    if dry_run:
        return name
    (root / VOLUMES).mkdir(parents=True, exist_ok=True)
    (root / VOLUMES / name).write_text(vol_text)
    path.write_text(new_text)
    problems = check(root)
    if problems:
        raise RuntimeError('分卷后历史对不上，请检查：' + problems[0])
    return name


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('command', nargs='?', choices=['split'])
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--keep-days', type=int, default=2, help='当前卷保留最近几个日期的条目（默认 2）')
    ap.add_argument('--before', help='移出日期早于此日（YYYY-MM-DD）的开头条目；给了就不看 --keep-days')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--root', type=Path, default=ROOT)
    a = ap.parse_args(argv)
    if a.check:
        problems = check(a.root)
        for p in problems:
            print('  ✗ ' + p)
        return 1 if problems else 0
    text = (a.root / LOG).read_text()
    _, body = entries(text)
    if a.command == 'split':
        if a.before:
            dt.date.fromisoformat(a.before)
            before = a.before
        else:
            dates = sorted({d for d, _ in body})
            if len(dates) <= a.keep_days:
                print(f'当前卷只有 {len(dates)} 个日期，不分卷')
                return 0
            before = dates[-a.keep_days]
        split(a.root, before, a.dry_run)
        return 0
    print(f'当前卷 {LOG}：{len(text.encode()) / 1024:.0f} KB，{len(body)} 条，'
          f'{body[0][0] if body else "-"}～{body[-1][0] if body else "-"}')
    for name in sorted(volume_names(a.root)):
        print(f'  分卷 {name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
