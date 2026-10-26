#!/usr/bin/env python3
"""选测（三级检查②，用户 2026-10-24）：按 git diff <基准> 的改动文件，查 选测对照.json 选出要跑的 Godot 场景与非 Godot 检查。

用法：选测.py <基准提交> [--root 资料库] [--head 提交] [--shell]
- 改动 = 基准到工作区（已提交＋未提交）的差异，加上未跟踪文件；每个文件按对照表第一条匹配的规则归组，各组取并集。
- 引用查找（refs）：在 tests/*.gd、*.tscn 里找改动文件的文件名（如 orbs.gd、orb_probe.cjs）与它声明的 class_name；
  找到的是辅助脚本时换成用它的场景（如 xiyou_rules.gd → xiyou_rules*.tscn 全部段）。删除的文件从基准里读 class_name。
- 加载者（loaders，手写数据 json 用）：另把 modes/ 下按文件名加载它的 .gd 的 class_name 也当引用词（如 alienation.json → XAlienation）。
- 切片细分（sliceSections，用户 2026-10-26）：xiyou_slice.json 不按整组 converter，而是比较基准与新版两份 JSON 哪些顶层键变了，
  每个键按对照表 sliceSections.keys 归组（地图／事件、战斗数值、图像音频），另加引用了该键名（"maps" 等）的测试；
  键不认识、JSON 解析失败、文件新增或删除时退回整组 converter。对照表 sliceSections.enabled 设 false 即完全回到整组。
- 分叉点（mergeBase，2026-10-26）：基准不是 HEAD 的祖先时（车道跑 --affected main 而 main 已前进），改用 merge-base(基准, HEAD)，
  只算本分支自己的改动；基准是祖先时（总装批首）两者相同。对照表 mergeBase 设 false 即按基准本身比。
- 默认打印人读的选择理由；--shell 另在标准输出给 检查.sh 用的 SEL_FULL／SEL_SCENES／SEL_CHECKS（理由改到标准错误）。
- 基准不存在、对照表无效时退出 2。
"""
import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLE = HERE / '选测对照.json'
TESTS = Path('03_再刷重制_Godot/01_Godot工程/tests')
MODES = Path('03_再刷重制_Godot/01_Godot工程/modes')
CHECKS = {'guards', 'tools', 'content', 'same_source'}


def git(root, *args):
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', *args], capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip())
    return p.stdout


def changed_files(root, base, head=None):
    if head:
        return sorted(p for p in git(root, 'diff', '--name-only', '-z', base, head, '--').split('\0') if p)
    tracked = git(root, 'diff', '--name-only', '-z', base, '--').split('\0')
    untracked = git(root, 'ls-files', '--others', '--exclude-standard', '-z').split('\0')
    return sorted({p for p in tracked + untracked if p})


def load_table(path=TABLE):
    table = json.loads(Path(path).read_text())
    groups, rules = table['groups'], table['rules']
    for rule in rules:
        if rule['group'] not in groups:
            raise ValueError('对照表规则指向不存在的组：' + rule['group'])
    for name, g in groups.items():
        bad = set(g.get('checks', [])) - CHECKS
        if bad:
            raise ValueError('组 %s 有未知检查：%s' % (name, '、'.join(sorted(bad))))
    sections = table.get('sliceSections') or {}
    bad = {g for g in (sections.get('keys') or {}).values() if g not in groups}
    if bad:
        raise ValueError('切片细分指向不存在的组：' + '、'.join(sorted(bad)))
    if not rules or rules[-1]['match'] != '*':
        raise ValueError('对照表最后一条须是 * （拿不准的路径归全量）')
    return groups, rules


def load_options(path=TABLE):
    table = json.loads(Path(path).read_text())
    return table.get('sliceSections') or {}, table.get('mergeBase', False)


def effective_base(root, base, head=None):
    """merge-base(基准, HEAD 或 --head)；没有共同祖先时用基准本身。"""
    try:
        return git(root, 'merge-base', base, head or 'HEAD').strip() or base
    except RuntimeError:
        return base


def slice_keys(root, base, path, head=None):
    """基准与新版切片 JSON 顶层键的差异：返回变了的键表，或 (None, 原因) 表示要退回整组。"""
    if not exists(root, path, head):
        return None, '切片文件被删除'
    try:
        old = json.loads(git(root, 'show', base + ':' + path))
    except RuntimeError:
        return None, '基准里没有切片文件'
    except ValueError:
        return None, '基准版 JSON 解析失败'
    try:
        new = json.loads(read_any(root, base, path, head) if head else (root / path).read_text())
    except ValueError:
        return None, '新版 JSON 解析失败'
    if not isinstance(old, dict) or not isinstance(new, dict):
        return None, '切片顶层不是对象'
    missing = object()
    return sorted(k for k in set(old) | set(new) if old.get(k, missing) != new.get(k, missing)), ''


def classify(path, rules):
    key = path[:-4] if path.endswith('.uid') else path
    return next(r['group'] for r in rules if fnmatch.fnmatchcase(key, r['match']))


def only_lines(root, base, path, pattern, head=None):
    """该文件的改动行（增删）是否都匹配 pattern。"""
    diff = git(root, 'diff', '-U0', base, *([head] if head else []), '--', path).splitlines()
    lines = [l[1:] for l in diff if l[:1] in '+-' and not l.startswith(('+++', '---'))]
    return bool(lines) and all(re.search(pattern, l) for l in lines)


def read_any(root, base, path, head=None):
    p = root / path
    if not head and p.is_file():
        return p.read_text(errors='ignore')
    for rev in [head, base] if head else [base]:
        try:
            return git(root, 'show', rev + ':' + path)
        except RuntimeError:
            pass
    return ''


def exists(root, path, head=None):
    if not head:
        return (root / path).exists()
    return subprocess.run(['git', '-C', str(root), 'cat-file', '-e', head + ':' + path], capture_output=True).returncode == 0


def loaders(root, name, head=None):
    """modes/ 下（generated 除外）以 "name" 字样加载该文件的 .gd 声明的 class_name。"""
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', 'grep', '-l', '-F', '"%s"' % name,
                        *([head] if head else []), '--', str(MODES / '*.gd'), ':!' + str(MODES / '*/generated/*')],
                       capture_output=True, text=True)
    names = []
    for line in p.stdout.splitlines():
        path = line.split(':', 1)[1] if head else line
        names += re.findall(r'^class_name\s+(\w+)', read_any(root, head or 'HEAD', path, head), re.M)
    return names


class Tests:
    """tests/ 下的场景与脚本文本，以及脚本 → 用它的场景。"""
    def __init__(self, root):
        d = root / TESTS
        self.scenes = sorted(p.name for p in d.glob('*.tscn'))
        self.text = {p.name: p.read_text(errors='ignore') for p in sorted(d.glob('*.gd')) + sorted(d.glob('*.tscn'))}

    def glob(self, pattern):
        return [s for s in self.scenes if fnmatch.fnmatchcase(s, pattern)]

    def users(self, name):
        """名为 name 的测试文件对应的场景：场景本身；脚本就找挂它的场景。"""
        if name.endswith('.tscn'):
            return [name] if name in self.scenes else []
        return [s for s in self.scenes if re.search(r'res://tests/' + re.escape(name) + r'"', self.text.get(s, ''))]

    def refs(self, terms, exclude=()):
        hits = set()
        for name, text in self.text.items():
            if name in exclude:
                continue
            if any(re.search(r'(?<![\w.])' + re.escape(t) + r'(?![\w])', text) for t in terms):
                hits.update(self.users(name))
        return hits


def select(root, base, table=TABLE, head=None):
    root = Path(root)
    git(root, 'rev-parse', '--verify', '-q', base + '^{commit}')
    groups, rules = load_table(table)
    sections, merge_base = load_options(table)
    shown_base = base
    if merge_base:
        base = effective_base(root, base, head)
        if git(root, 'rev-parse', shown_base + '^{commit}').strip() != base:
            shown_base = '%s（分叉点 %s）' % (shown_base, base[:10])
    files = changed_files(root, base, head)
    tests = Tests(root)
    full, scenes, checks, reasons = False, set(), set(), []

    def take(path, group, why, terms_extra=()):
        nonlocal full
        g = groups[group]
        if 'onlyLines' in g and not only_lines(root, base, path, g['onlyLines'], head):
            group, g, why = 'full', groups['full'], group + ' 但改了版本行以外的内容'
        picked = set()
        for pattern in g.get('scenes', []):
            picked.update(tests.glob(pattern))
        if terms_extra:
            picked |= tests.refs(list(terms_extra))
        if g.get('refs'):
            key = path[:-4] if path.endswith('.uid') else path
            name = Path(key).name
            terms = [name]
            if key.endswith('.gd'):
                terms += re.findall(r'^class_name\s+(\w+)', read_any(root, base, key, head), re.M)
            if g.get('loaders'):
                terms += loaders(root, name, head)
            own = tests.users(name) if g.get('self') else []
            refs = tests.refs(terms, exclude={name}) | set(own)
            gone = not exists(root, key, head)
            if not refs and gone:
                why += '，已删除且没有测试再引用它'
            elif not refs and g.get('fallback'):
                if 'FULL' in g['fallback']:
                    full, why = True, why + '，找不到用它的测试，整轮'
                else:
                    refs = {s for p in g['fallback'] for s in tests.glob(p)}
                    why += '，找不到引用它的测试，改跑 ' + '、'.join(g['fallback'])
            picked |= refs
        if g.get('full'):
            full = True
        scenes.update(picked)
        checks.update(g.get('checks', []))
        reasons.append((path, why, g.get('说明', ''), sorted(picked), g.get('full', False)))

    for path in files:
        if path.endswith('.uid') and path[:-4] in files:
            continue  # 和源文件同组，不重复列
        group = classify(path, rules)
        if sections.get('enabled') and path == sections.get('file'):
            keys, problem = slice_keys(root, base, path, head)
            unknown = [k for k in keys or [] if sections['keys'].get(k) not in groups]
            if keys is None or unknown:
                take(path, group, group + '（切片细分退回整组：%s）' % (problem or '未知键 ' + '、'.join(unknown)))
                continue
            by_group = {}
            for k in keys:
                by_group.setdefault(sections['keys'][k], []).append(k)
            if not by_group:
                reasons.append((path, '切片只改了格式，顶层键都没变', '', [], False))
            for sub, ks in sorted(by_group.items()):
                take(path, sub, '%s（切片键 %s）' % (sub, '、'.join(ks)), [] if sub == 'docs' else ['"%s"' % k for k in ks])
            continue
        take(path, group, group)
    if not full and tests.scenes and scenes >= set(tests.scenes):
        full = True  # 选中了全部场景：按整轮跑，才能沿用上轮通过结果
        reasons.append(('（全部场景）', '选中了全部 %d 个场景，按整轮跑' % len(tests.scenes), '', [], True))
    return dict(base=shown_base, files=files, full=full, scenes=sorted(scenes), checks=sorted(checks), reasons=reasons)


def report(sel, out):
    print('== 选测（基准 %s，%d 个改动文件）' % (sel['base'], len(sel['files'])), file=out)
    for path, why, note, picked, full in sel['reasons']:
        extra = '整轮' if full else ('%d 个场景' % len(picked) if picked else '无场景')
        shown = '、'.join(picked[:6]) + ('……' if len(picked) > 6 else '')
        print('  %s → %s（%s）：%s%s' % (path, why, note, extra, '：' + shown if shown and not full else ''), file=out)
    if sel['full']:
        print('  结论：整轮（有拿不准的改动），等同不加 --affected', file=out)
    else:
        print('  结论：Godot 场景 %d 个%s；非 Godot 检查：%s；文档与登记检查照常' % (
            len(sel['scenes']), '（' + ' '.join(sel['scenes']) + '）' if sel['scenes'] else '', '、'.join(sel['checks']) or '无'), file=out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('base')
    ap.add_argument('--root', type=Path, default=HERE.parent.parent)
    ap.add_argument('--table', type=Path, default=TABLE)
    ap.add_argument('--head', help='只看 基准..这个提交 的差异（不含工作区），用来回看某次合并会选什么')
    ap.add_argument('--shell', action='store_true')
    a = ap.parse_args(argv)
    try:
        sel = select(a.root, a.base, a.table, a.head)
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        print('选测失败：' + str(error), file=sys.stderr)
        return 2
    report(sel, sys.stderr if a.shell else sys.stdout)
    if a.shell:
        safe = re.compile(r'^[A-Za-z0-9_.-]+$')
        assert all(safe.match(x) for x in sel['scenes'] + sel['checks'])
        print('SEL_FULL=%d' % sel['full'])
        # 整轮时不给场景表：检查.sh 把场景表原样传给 并行测试.py，给了就只跑这些（2026-10-26 木吒：整轮漏跑 6 个场景）
        print('SEL_SCENES=(%s)' % ' '.join([] if sel['full'] else sel['scenes']))
        print('SEL_CHECKS=(%s)' % ' '.join(sel['checks']))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
