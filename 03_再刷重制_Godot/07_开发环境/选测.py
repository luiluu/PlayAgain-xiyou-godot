#!/usr/bin/env python3
"""选测（三级检查②，用户 2026-10-24）：按 git diff <基准> 的改动文件，查 选测对照.json 选出要跑的 Godot 场景与非 Godot 检查。

用法：选测.py <基准提交> [--root 资料库] [--head 提交] [--shell | --list]
- 改动 = 基准到工作区（已提交＋未提交）的差异，加上未跟踪文件；每个文件按对照表第一条匹配的规则归组，各组取并集。
- 引用查找（refs）：在 tests/*.gd、*.tscn 里找改动文件的文件名（如 orbs.gd、orb_probe.cjs）与它声明的 class_name；
  找到的是辅助脚本时换成用它的场景（如 xiyou_rules.gd → xiyou_rules*.tscn 全部段）。删除的文件从基准里读 class_name。
- 加载者（loaders，手写数据 json 用）：另把 modes/ 下按文件名加载它的 .gd 的 class_name 也当引用词（如 alienation.json → XAlienation）。
- 切片细分（sliceSections，用户 2026-10-26）：xiyou_slice.json 不按整组 converter，而是比较基准与新版两份 JSON 哪些顶层键变了，
  每个键按对照表 sliceSections.keys 归组（地图／事件、战斗数值、图像音频），另加引用了该键名（"maps" 等）的测试；
  键不认识、JSON 解析失败、文件新增或删除时退回整组 converter。对照表 sliceSections.enabled 设 false 即完全回到整组。
  其中 maps／keepEvents（slice_map）再按图号收窄楼层专项（sliceSections.narrowFloorsByMap，哪吒_3）：只留引用了增删改图号的
  xiyou_floor*／xiyou_map* 场景，遍历全部楼层的与认不出图号的照旧选；子开关 enabled 设 false 回到楼层专项全选。
  认出的图号不保证完整（沙僧第八期 F1：MAPS 出口表、HUB 常量、_wait_map(变量)），所以脚本（连同 preload 的 tests/ 脚本）里
  出现改动图号的整数字面量、或与 always 场景共用脚本的也保留（anyLiteral，tools24；设 false 回到只按认出的图号求交集）。
- 分叉点（mergeBase，2026-10-26）：基准不是 HEAD 的祖先时（车道跑 --affected main 而 main 已前进），改用 merge-base(基准, HEAD)，
  只算本分支自己的改动；基准是祖先时（总装批首）两者相同。对照表 mergeBase 设 false 即按基准本身比。
- 工具引用（toolRefs，测试夹具用）：没有 Godot 测试引用、但 07_开发环境／03_转换工具 的脚本按文件名读它时，跑工具回归、不整轮
  （如 state_js_translation.json 只被 测试状态js翻译.py 读；2026-10-26 哪吒）。
- --head 回放时测试场景与脚本也从 head 读（head 里新增的测试要找得到）。
- 默认打印人读的选择理由；--shell 另在标准输出给 检查.sh 用的 SEL_FULL／SEL_SCENES／SEL_CHECKS（理由改到标准错误）。
- --list（车道手写选测前用，tools35）：只在标准输出逐行打场景名（不带 .tscn，可直接接到 并行测试.py 后面），理由与结论改到标准错误；
  整轮时不打场景名、退出 0 并在标准错误说明。车道交付的手写选测名单至少含这里列出的场景（至少战斗核心类），不跑要在交付单说明为什么。
- 抽样（sample，用户 2026-11-02 同意，tools43）：选测（不是整轮）选到 xiyou_rules*／xiyou_smart_ai* 时，每组按名字排序、每 chunk 段
  （rules 每个难度 4 段、smart_ai 每 4 段）只留 1 段，留哪段按 --head 或 HEAD 沿第一父的合并提交数取余轮换（主线连续 4 次合并轮完一组；tools46 起只数合并提交，因为一次合并在主线上占「合并＋收尾」两个第一父提交，数全部提交会隔 2 取一）。改了测试本身（exemptGroups 里的组）
  选上的段照跑、并算作该组已有代表。段数不是 chunk 的整数倍时这一族不抽样。全量（不加 --affected、选测结论整轮）照跑全套。
  回退：对照表 sample.enabled 设 false，或环境变量 XIYOU_SAMPLE=0。
- 钩子行收窄（hookLines，tools54，Kyo 2026-11-03 同意）：车道常在 battle_logic／actor／xstate／resource_context 这几个核心文件里只加「调用某个角色专属模块」的钩子
  （如 XXuanBattle.take_logs()），按文件判会几乎全选（dev.294～296 一批选了 337／383 个场景）。对照表 hookLines.files 里的文件，若每个改动块（hunk）都含
  角色专属模块（hookLines.roleModules 白名单，新模块默认不算钩子）的独立调用，且整块是纯新增（tools57，审查 35 P2：只认 XMod.fn(...)、var x := XMod.fn(...) 加 if not x.is_empty(): return x、
  if XMod.fn(...): 加一行调用或 return；有运算／赋值／分号／删改行／无条件 return 都退回），就改归 battle_hooks 组：
  冒烟场景（determinism、battle、combat、rules 抽样、存档类）＋引用了这些模块名的测试；有一块认不出就退回原组。回退：hookLines.enabled 设 false，或环境变量 XIYOU_HOOKS=0（O-153）。
- 基准不存在、对照表无效时退出 2。
"""
import argparse
import fnmatch
import json
import os
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
# 楼层／地图专项里「引用地图编号」的写法（2026-10-26 哪吒_3 查 tests/ 实际写法）：注释与说明里的 Map033、
# MAP := 33／FLOOR_MAP 之类常量、_start(33, …)、_wait_map(33)、map_id == 33、_goto(从, x, y, 事件, 到, …) 的起止图
MAP_REF_PATTERNS = [
    r'\bMap(\d{3})\b',
    r'\b[A-Z_]*MAP[A-Z_]*\s*:?=\s*(\d+)\b',
    r'\b_start\(\s*(\d+)\s*,',
    r'\b_wait_map\(\s*(\d+)\s*\)',
    r'\bmap_id\s*==\s*(\d+)\b',
    r'\b_goto\(\s*(\d+)\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*(\d+)\s*,',
]


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
    hook = table.get('hookLines') or {}
    if hook and hook.get('group') not in groups:
        raise ValueError('hookLines.group 指向不存在的组：%s' % hook.get('group'))
    for name, g in groups.items():
        if g.get('onlyLinesElse', 'full') not in groups or 'onlyLines' in groups[g.get('onlyLinesElse', 'full')]:
            raise ValueError('组 %s 的 onlyLinesElse 须指向没有 onlyLines 的已有组' % name)
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


def load_sample(path=TABLE):
    """抽样设置；关着（对照表 enabled false 或 XIYOU_SAMPLE=0）返回 None。"""
    if os.environ.get('XIYOU_SAMPLE', '') == '0':
        return None
    sample = json.loads(Path(path).read_text()).get('sample') or {}
    return sample if sample.get('enabled') else None


def sample_chunks(all_scenes, sample):
    """[(族名, [段…]), …]：每族按名字排序、每 chunk 个一组；段数不是 chunk 整数倍的族不抽样（不出现在结果里）。"""
    out = []
    for fam in (sample or {}).get('families', []):
        members = sorted(s for s in all_scenes if fnmatch.fnmatchcase(s, fam['scenes']))
        n = int(fam.get('chunk', 4))
        if n > 1 and members and len(members) % n == 0:
            out += [(fam['name'], members[i:i + n]) for i in range(0, len(members), n)]
    return out


def sample_seed(root, head=None):
    """抽样种子：HEAD（或 --head）沿第一父的合并提交数。一次合并在主线上占「合并＋收尾」两个第一父提交，被测提交常差 2，
    数全部提交一组只在两段间来回（审查 27 P3-1）；只数合并提交，每次合并加 1，连续 4 次合并正好轮完一组，
    合并和它的收尾提交种子相同（同一次合并里不换段）。不用共用状态目录里的计数器：免得依赖本机状态、云端和本机算出不同。"""
    return int(git(root, 'rev-list', '--first-parent', '--merges', '--count', head or 'HEAD').strip())


def apply_sample(scenes, pinned, all_scenes, sample, seed):
    """每组选中的段里只留 1 段：组里有 pinned 的就留 pinned（全留），否则按 seed 轮换。返回 (留下的场景, [(族, 组, 留, 省)…])。"""
    keep, info = set(scenes), []
    for i, (fam, chunk) in enumerate(sample_chunks(all_scenes, sample)):
        chosen = [s for s in chunk if s in keep]
        if len(chosen) < 2:
            continue
        fixed = [s for s in chosen if s in pinned]
        if fixed:
            stay = fixed
        else:
            start = (seed + i) % len(chunk)
            stay = [next(chunk[(start + k) % len(chunk)] for k in range(len(chunk)) if chunk[(start + k) % len(chunk)] in chosen)]
        dropped = [s for s in chosen if s not in stay]
        keep -= set(dropped)
        if dropped:
            info.append((fam, chunk, stay, dropped))
    return sorted(keep), info


def effective_base(root, base, head=None):
    """merge-base(基准, HEAD 或 --head)；没有共同祖先时用基准本身。"""
    try:
        return git(root, 'merge-base', base, head or 'HEAD').strip() or base
    except RuntimeError:
        return base


def slice_keys(root, base, path, head=None):
    """基准与新版切片 JSON 顶层键的差异：返回 (变了的键表, 改动图号或 None)，或 (None, 原因) 表示要退回整组。"""
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
    keys = sorted(k for k in set(old) | set(new) if old.get(k, missing) != new.get(k, missing))
    return keys, changed_maps(old, new)


def changed_maps(old, new):
    """maps 列表增删的图号，加 keepEvents 里内容有增删改的图号；结构认不出时返回 None（不收窄）。"""
    try:
        before, after = set(map(int, old.get('maps') or [])), set(map(int, new.get('maps') or []))
        ka, kb = old.get('keepEvents') or {}, new.get('keepEvents') or {}
        if not isinstance(ka, dict) or not isinstance(kb, dict):
            return None
        kept = {int(k) for k in set(ka) | set(kb) if not k.endswith('说明') and ka.get(k) != kb.get(k)}
    except (TypeError, ValueError, AttributeError):
        return None
    return (before ^ after) | kept


def classify(path, rules):
    key = path[:-4] if path.endswith('.uid') else path
    return next(r['group'] for r in rules if fnmatch.fnmatchcase(key, r['match']))


def only_lines(root, base, path, pattern, head=None):
    """该文件的改动行（增删）是否都匹配 pattern。"""
    diff = git(root, 'diff', '-U0', base, *([head] if head else []), '--', path).splitlines()
    lines = [l[1:] for l in diff if l[:1] in '+-' and not l.startswith(('+++', '---'))]
    return bool(lines) and all(re.search(pattern, l) for l in lines)


def load_hooks(path=TABLE):
    """钩子行收窄设置；关着（对照表 enabled false 或 XIYOU_HOOKS=0）返回 None。"""
    if os.environ.get('XIYOU_HOOKS', '') == '0':
        return None
    cfg = json.loads(Path(path).read_text()).get('hookLines') or {}
    return cfg if cfg.get('enabled') else None


def code_part(line):
    """去掉行尾注释（引号里的 # 不算）。"""
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q and line[i - 1] != '\\':
                q = None
        elif ch in '"\'':
            q = ch
        elif ch == '#':
            return line[:i]
    return line


def whole_call(text):
    """text 是否「一个 XMod.fn(...) 调用占满整句」：第一个左括号的配对右括号正好是末尾。返回 (模块名) 或 None。"""
    m = re.match(r'(X[A-Z]\w*)\.\w+\(', text)
    if not m:
        return None
    depth, q = 0, None
    for i in range(m.end() - 1, len(text)):
        ch = text[i]
        if q:
            if ch == q and text[i - 1] != '\\':
                q = None
        elif ch in '"\'':
            q = ch
        elif ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
            if depth == 0:
                return m.group(1) if text[i + 1:].strip() == '' else None
    return None


RETURN_LITERAL = re.compile(r'return( (false|true|null|\{\}|\[\]|-?\d+(\.\d+)?))?')


def hook_block(lines, i, roles):
    """lines[i:] 开头是不是一个完整的钩子块（缩进已量好的 (缩进, 代码) 列表）：是返回 (模块名, 用掉几行)，否返回 None。
    只认三种（O-153 审查 35 P2-1，tools57）：
    ① 独立调用 `XMod.fn(...)`；
    ② `var x := XMod.fn(...)` 后紧跟同一层的 `if not x.is_empty():` 和更深一层的 `return x`；
    ③ `if XMod.fn(...):` 后紧跟更深一层的一行：独立调用、`return`、`return 字面量` 或 `return XMod.fn(...)`。
    赋值、运算、分号、无条件 return 都不是钩子。"""
    ind, code = lines[i]
    var = re.match(r'var (\w+)\s*:?=\s*(.*)$', code)
    if var:
        mod = whole_call(var.group(2).strip())
        if mod in roles and i + 2 < len(lines):
            (i1, c1), (i2, c2) = lines[i + 1], lines[i + 2]
            if i1 == ind and c1 == 'if not %s.is_empty():' % var.group(1) and i2 > i1 and c2 == 'return ' + var.group(1):
                return mod, 3
        return None
    mod = whole_call(code)
    if mod in roles:
        return mod, 1
    cond = re.match(r'if (.*):$', code)
    if cond:
        mod = whole_call(cond.group(1).strip())
        if mod in roles and i + 1 < len(lines):
            i1, c1 = lines[i + 1]
            if i1 > ind and (whole_call(c1) in roles or RETURN_LITERAL.fullmatch(c1)
                             or (c1.startswith('return ') and whole_call(c1[7:].strip()) in roles)):
                return mod, 2
    return None


def hook_modules(root, base, path, cfg, head=None):
    """该文件改动是否只是「调用角色专属模块」的钩子：是返回模块名集合，否（或没改动）返回 None。
    逐个 hunk 看（tools57，审查 35 P2）：只放行纯新增块（删行或改行里有代码就退回）；新增的代码行必须依次拼成 hook_block 认得的钩子块，
    每块的模块必须在 cfg.roleModules 白名单（角色专属模块；新模块默认不算钩子）里；注释行、空行随便。有一块认不出就整个文件退回。"""
    roles = set(cfg.get('roleModules', []))
    diff = git(root, 'diff', '-U0', base, *([head] if head else []), '--', path).splitlines()
    hunks, cur = [], None
    for l in diff:
        if l.startswith('@@'):
            cur = ([], [])
            hunks.append(cur)
        elif cur is not None and l[:1] in '+-' and not l.startswith(('+++', '---')):
            cur[l[:1] == '+'].append(l[1:])
    mods = set()
    for removed, added in hunks:
        if any(code_part(l).strip() for l in removed):
            return None
        lines = []
        for l in added:
            code = code_part(l).rstrip()
            if code.strip():
                if ';' in code:
                    return None
                lines.append((len(code) - len(code.lstrip()), code.strip()))
        i, found = 0, False
        while i < len(lines):
            hit = hook_block(lines, i, roles)
            if not hit:
                return None
            mods.add(hit[0])
            i += hit[1]
            found = True
        if not found:
            return None
    return mods or None


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

    def scripts(self, scene):
        """场景挂的 tests/ 脚本，连同这些脚本再 preload／extends 的 tests/ 脚本（xiyou_reach_check.gd、xiyou_map186.gd 等，tools24）。"""
        seen, todo = [], re.findall(r'res://tests/([\w.]+\.gd)"', self.text.get(scene, ''))
        while todo:
            name = todo.pop(0)
            if name not in seen:
                seen.append(name)
                todo += re.findall(r'res://tests/([\w.]+\.gd)"', self.text.get(name, ''))
        return seen

    def mentions(self, scene, ids):
        """场景的脚本里有没有等于 ids 中某个图号的整数字面量（MAPS 出口表、HUB 常量、坐标表里的图号都算；tools24）。
        只看 .gd，不看 .tscn 头里的 load_steps／format 之类。宁可多选：坐标、次数碰上同一个数也保留。"""
        return any(int(m) in ids for n in self.scripts(scene)
                   for m in re.findall(r'(?<![\w.])(\d+)(?![\w.])', self.text.get(n, '')))

    def map_ids(self, scene):
        """场景（连同它挂的、再 preload 的 tests/ 脚本）按 MAP_REF_PATTERNS 认出的地图编号；一个也认不出时返回 None（按判不出处理）。
        认出的不保证完整（沙僧第八期 F1）：收窄时另用 mentions 兜底。"""
        texts = [self.text.get(scene, '')] + [self.text.get(n, '') for n in self.scripts(scene)]
        ids = set()
        for text in texts:
            for pattern in MAP_REF_PATTERNS:
                for m in re.finditer(pattern, text):
                    ids.update(int(g) for g in m.groups() if g)
        return ids or None

    def refs(self, terms, exclude=()):
        hits = set()
        for name, text in self.text.items():
            if name in exclude:
                continue
            if any(re.search(r'(?<![\w.])' + re.escape(t) + r'(?![\w])', text) for t in terms):
                hits.update(self.users(name))
        return hits


def stale_notice(root, base, head=None):
    """工作树分叉点比基准旧、且分叉之后基准改过 .gd 时返回一行提示，否则空串（tools53：xuan2、xuan3 被 300 多个场景的名单坑过）。"""
    try:
        base_sha = git(root, 'rev-parse', base + '^{commit}').strip()
        fork = git(root, 'merge-base', base, head or 'HEAD').strip()
        if not fork or fork == base_sha:
            return ''
        moved = [x for x in git(root, 'diff', '--name-only', '-z', fork, base_sha, '--').split('\0') if x.endswith('.gd')]
    except RuntimeError:
        return ''
    if not moved:
        return ''
    return '⚠ 本分支比 %s 旧（分叉点 %s 之后 %s 改了 %d 个 .gd）：先 git merge %s 再选测，否则名单会混进 %s 的改动' % (
        base, fork[:10], base, len(moved), base, base)


def set_files(cfg, files):
    return {f for f in files if any(fnmatch.fnmatchcase(f, pat) for pat in cfg.get('files', []))}


def select(root, base, table=TABLE, head=None, sample=True):
    """sample=False：不抽样（合并沿用车道结果时算「哪些场景被差异波及」用）。"""
    root = Path(root)
    git(root, 'rev-parse', '--verify', '-q', base + '^{commit}')
    groups, rules = load_table(table)
    sections, merge_base = load_options(table)
    shown_base, ref_base = base, base
    if merge_base:
        base = effective_base(root, base, head)
        if git(root, 'rev-parse', shown_base + '^{commit}').strip() != base:
            shown_base = '%s（分叉点 %s）' % (shown_base, base[:10])
    files = changed_files(root, base, head)
    tests = Tests(root, head)
    full, scenes, checks, reasons = False, set(), set(), []
    pinned = set()  # 改了测试本身选上的场景：抽样时照跑
    sample_cfg = load_sample(table) if sample else None

    narrow = sections.get('narrowFloorsByMap') or {}
    hooks = load_hooks(table)

    def take(path, group, why, terms_extra=(), map_ids=None):
        nonlocal full
        g = groups[group]
        if hooks and path in set_files(hooks, files):
            mods = hook_modules(root, base, path, hooks, head)
            if mods:
                group, g = hooks['group'], groups[hooks['group']]
                terms_extra = list(terms_extra) + sorted(mods)
                why = '%s（只加钩子调用：%s）' % (group, '、'.join(sorted(mods)))
        if 'onlyLines' in g and not only_lines(root, base, path, g['onlyLines'], head):
            # onlyLinesElse：改动行不全匹配时退回的组（缺省整轮）；xstate.gd 只加字段与存读档键时只跑存档类专项（哪吒_8）
            other = g.get('onlyLinesElse', 'full')
            group, g, why = other, groups[other], group + ' 但改了 onlyLines 以外的内容，按 ' + other
        picked = set()
        for pattern in g.get('scenes', []):
            picked.update(tests.glob(pattern))
        if map_ids is not None and narrow.get('enabled') and group in narrow.get('groups', []):
            floors = {s for p in narrow.get('scenes', []) for s in tests.glob(p)}
            always = {s for p in narrow.get('always', []) for s in tests.glob(p)}
            # anyLiteral（tools24，沙僧第八期 F1／P2）：认出的图号不全时（MAPS 出口表、HUB 常量、_wait_map(变量)），脚本里只要出现
            # 改动图号的字面量、或与 always 场景共用脚本（按内容数据遍历），就保留；设 false 回到只按认出的图号求交集
            guard = narrow.get('anyLiteral', True)
            shared = {n for s in always for n in tests.scripts(s)}
            keep = {s for s in floors & picked
                    if s in always or tests.map_ids(s) is None or tests.map_ids(s) & map_ids
                    or guard and (tests.mentions(s, map_ids) or shared & set(tests.scripts(s)))}
            dropped = (floors & picked) - keep
            picked -= dropped
            why += '，楼层专项按图号 %s 收窄（留 %d、省 %d）' % ('、'.join(map(str, sorted(map_ids))) or '无',
                                                         len(keep), len(dropped))
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
            tools = [] if refs or gone or not g.get('toolRefs') else tool_users(root, name, head)
            if not refs and gone:
                why += '，已删除且没有测试再引用它'
            elif tools:
                checks.update({'guards', 'tools'})
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
        scenes.update(picked)
        if sample_cfg and group in sample_cfg.get('exemptGroups', []):
            pinned.update(picked)
        checks.update(g.get('checks', []))
        reasons.append((path, why, g.get('说明', ''), sorted(picked), g.get('full', False)))

    for path in files:
        if path.endswith('.uid') and path[:-4] in files:
            continue  # 和源文件同组，不重复列
        group = classify(path, rules)
        if sections.get('enabled') and path == sections.get('file'):
            keys, extra = slice_keys(root, base, path, head)
            problem = extra if keys is None else ''
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
                take(path, sub, '%s（切片键 %s）' % (sub, '、'.join(ks)), [] if sub == 'docs' else ['"%s"' % k for k in ks], extra)
            continue
        take(path, group, group)
    if not full and tests.scenes and scenes >= set(tests.scenes):
        full = True  # 选中了全部场景：按整轮跑，才能沿用上轮通过结果
        reasons.append(('（全部场景）', '选中了全部 %d 个场景，按整轮跑' % len(tests.scenes), '', [], True))
    sampled = []
    if sample_cfg and not full:
        seed = sample_seed(root, head)
        scenes, sampled = apply_sample(scenes, pinned, tests.scenes, sample_cfg, seed)
    return dict(base=shown_base, files=files, full=full, scenes=sorted(scenes), checks=sorted(checks), reasons=reasons,
                sampled=sampled, notice=stale_notice(root, ref_base, head))


def report(sel, out):
    print('== 选测（基准 %s，%d 个改动文件）' % (sel['base'], len(sel['files'])), file=out)
    if sel.get('notice'):
        print(sel['notice'], file=out)
    for path, why, note, picked, full in sel['reasons']:
        extra = '整轮' if full else ('%d 个场景' % len(picked) if picked else '无场景')
        shown = '、'.join(picked[:6]) + ('……' if len(picked) > 6 else '')
        print('  %s → %s（%s）：%s%s' % (path, why, note, extra, '：' + shown if shown and not full else ''), file=out)
    if sel.get('sampled'):
        fams = {}
        for fam, _, stay, dropped in sel['sampled']:
            f = fams.setdefault(fam, [[], 0])
            f[0] += [x[:-5] for x in stay]
            f[1] += len(dropped)
        for fam, (stay, n) in fams.items():
            print('  抽样（XIYOU_SAMPLE=0 关）：%s 每组留 1 段，跑 %s，省 %d 个' % (fam, ' '.join(stay), n), file=out)
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
    ap.add_argument('--list', action='store_true', help='标准输出只打场景名，一行一个')
    a = ap.parse_args(argv)
    try:
        sel = select(a.root, a.base, a.table, a.head)
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        print('选测失败：' + str(error), file=sys.stderr)
        return 2
    report(sel, sys.stderr if a.shell or a.list else sys.stdout)
    if a.list:
        if sel['full']:
            print('选测结论是整轮（有拿不准的改动）：没有可列的场景名，按整轮跑或问总装', file=sys.stderr)
        else:
            for x in sel['scenes']:
                print(x[:-len('.tscn')] if x.endswith('.tscn') else x)
        return 0
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
