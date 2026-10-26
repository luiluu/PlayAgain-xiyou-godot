#!/usr/bin/env python3
"""选测（三级检查②，用户 2026-10-24）：按 git diff <基准> 的改动文件，查 选测对照.json 选出要跑的 Godot 场景与非 Godot 检查。

用法：选测.py <基准提交> [--root 资料库] [--head 提交] [--shell]
- 改动 = 基准到工作区（已提交＋未提交）的差异，加上未跟踪文件；每个文件按对照表第一条匹配的规则归组，各组取并集。
- 引用查找（refs）：在 tests/*.gd、*.tscn 里找改动文件的文件名（如 orbs.gd、orb_probe.cjs）与它声明的 class_name；
  找到的是辅助脚本时换成用它的场景（如 xiyou_rules.gd → xiyou_rules*.tscn 全部段）。删除的文件从基准里读 class_name。
- 加载者（loaders，手写数据 json 用）：另把 modes/ 下按文件名加载它的 .gd 的 class_name 也当引用词（如 alienation.json → XAlienation）。
- 工具引用（toolRefs，测试夹具用）：没有 Godot 测试引用、但 07_开发环境／03_转换工具 的脚本按文件名读它时，跑工具回归、不整轮
  （如 state_js_translation.json 只被 测试状态js翻译.py 读；2026-10-26 哪吒）。
- --head 回放时测试场景与脚本也从 head 读（head 里新增的测试要找得到）。
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
TOOL_DIRS = ['03_再刷重制_Godot/07_开发环境', '03_再刷重制_Godot/03_转换工具']
TOOL_SUFFIXES = ('.py', '.cjs', '.js', '.mjs', '.sh')
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
    if not rules or rules[-1]['match'] != '*':
        raise ValueError('对照表最后一条须是 * （拿不准的路径归全量）')
    return groups, rules


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


def tool_users(root, name, head=None):
    """07_开发环境／03_转换工具 下按文件名提到 name 的脚本（不含 tests/ 自身）。"""
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', 'grep', '-l',
                        *([] if head else ['--untracked']), '-F', name, *([head] if head else []), '--', *TOOL_DIRS],
                       capture_output=True, text=True)
    paths = [l.split(':', 1)[1] if head else l for l in p.stdout.splitlines()]
    return [x for x in paths if x.endswith(TOOL_SUFFIXES)]


class Tests:
    """tests/ 下的场景与脚本文本，以及脚本 → 用它的场景。head 给了就从该提交读。"""
    def __init__(self, root, head=None):
        if head:
            names = git(root, 'ls-tree', '-z', '--name-only', head, str(TESTS) + '/').split('\0')
            names = sorted(Path(n).name for n in names if n.endswith(('.gd', '.tscn')))
            self.text = {n: git(root, 'show', '%s:%s/%s' % (head, TESTS, n)) for n in names}
            self.scenes = [n for n in names if n.endswith('.tscn')]
            return
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
    files = changed_files(root, base, head)
    tests = Tests(root, head)
    full, scenes, checks, reasons = False, set(), set(), []
    for path in files:
        if path.endswith('.uid') and path[:-4] in files:
            continue  # 和源文件同组，不重复列
        group = classify(path, rules)
        g = groups[group]
        why = group
        if 'onlyLines' in g and not only_lines(root, base, path, g['onlyLines'], head):
            group, g, why = 'full', groups['full'], group + ' 但改了版本行以外的内容'
        picked = set()
        for pattern in g.get('scenes', []):
            picked.update(tests.glob(pattern))
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
            tools = [] if refs or gone or not g.get('toolRefs') else tool_users(root, name, head)
            if not refs and gone:
                why += '，已删除且没有测试再引用它'
            elif tools:
                checks |= {'guards', 'tools'}
                why += '，只有工具脚本用它（%s），跑工具回归' % '、'.join(Path(t).name for t in tools[:3])
            elif not refs and g.get('fallback'):
                if 'FULL' in g['fallback']:
                    full, why = True, why + '，找不到用它的测试，整轮'
                else:
                    refs = {s for p in g['fallback'] for s in tests.glob(p)}
                    why += '，找不到引用它的测试，改跑 ' + '、'.join(g['fallback'])
            picked |= refs
        if g.get('full'):
            full = True
        scenes |= picked
        checks |= set(g.get('checks', []))
        reasons.append((path, why, g.get('说明', ''), sorted(picked), g.get('full', False)))
    if not full and tests.scenes and scenes >= set(tests.scenes):
        full = True  # 选中了全部场景：按整轮跑，才能沿用上轮通过结果
        reasons.append(('（全部场景）', '选中了全部 %d 个场景，按整轮跑' % len(tests.scenes), '', [], True))
    return dict(base=base, files=files, full=full, scenes=sorted(scenes), checks=sorted(checks), reasons=reasons)


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
