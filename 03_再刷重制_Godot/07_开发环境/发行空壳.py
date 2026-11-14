#!/usr/bin/env python3
"""发行空壳（cc 2026-11-13，漩涡异化设计稿外泄后加）：发行包里的天启篇脚本换成同名空壳，逻辑、文字、数值都不进包。

西游代码里四百多处直接按类名调天启篇（XTianqi*、XRiftAlien），删掉脚本就编译不过；西游代码一行不改，
出发行包时在工程的克隆里把这些脚本换成空壳：类名、继承、西游代码用到的函数和常量照留，函数体换成
「天启篇没开放时」的结果（发行构建里天启篇都关着，真脚本在西游存档上走的也是这条路）。开发版、测试、Kyo 本地照旧用真脚本。

  python3 发行空壳.py tree <输出目录>      克隆工程（APFS cp -c，含 .godot 缓存）并换上空壳，打印目录；发行出包.py、发布补丁.py 从这里导出
  python3 发行空壳.py check                 只生成空壳、不落盘：查西游代码用到的每个成员都有，没有就报（检查.sh 用）
  python3 发行空壳.py show <类名>           打印某个类的空壳（核对用）

空壳函数体的来历，按顺序：
  1. 特例表 发行空壳特例.json（"类.成员": "一行 GDScript 表达式" 或 "pass"）；
  2. 真脚本第一句是 `if …: return <参数名或字面量>`：照搬那个返回值（关着时原样返回、返回 1.0／false 之类）；
  3. 按返回类型给空值：bool→false、int→0、float→0.0、String→""、Array→[]、Dictionary→{}、Color→透明、其余→null。
常量和 static var：数字、布尔照留（不透露设计），字符串→""，数组→[]，字典→{}，其余表达式→特例表或 null。
验收：发行模式（ReleaseEntry.simulate_release）下真脚本和空壳各跑一遍西游测试，结果一致（见 发行空壳验收.py）。
新加天启篇脚本被西游代码引用：check 会列出缺的成员，照真脚本发行时的行为加进特例表或确认默认值对。
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
OVERRIDES = HERE / '发行空壳特例.json'
CLASS_RE = re.compile(r'^class_name (\w+)\b', re.M)
PREFIX_RE = re.compile(r'^X(?:Tianqi\w*|RiftAlien)$')  # 天启篇模块按惯例的类名
# 类名不带天启篇前缀、但整份只在天启篇用的脚本（显式名单；cc 11-14 release-stub-gojo：XGojo 曾漏在名单外）
EXTRA = {
    'XGojo',            # 五条悟 180（只在天启篇，modes/xiyou/core/gojo.gd）
    'XGuardianRework',  # 守层者按新成长重算（只管天启篇存档）
}
KEEP = {'XTianqiTitle'}  # 发行包要用的真脚本（标题画面）：不换
SCAN_DIRS = ('modes', 'core', 'scenes', 'addons')
MARK = '## 发行空壳'
# 编进包里也认得出的空壳标记（注释导出时会去掉，字符串常量不会）：发行内容审计.py 解开包里的 .gdc 找它
STUB_TAG = 'xiyou-release-stub-v1'
STUB_TAG_LINE = f'const _RELEASE_STUB := "{STUB_TAG}"'
# 天启篇专属的迹象（suspects 用）：文件名、头注释里的说法
SUSPECT_NAME = re.compile(r'tianqi|gojo|qiyin|horsem', re.I)
SUSPECT_HEAD = re.compile(r'只在天启篇|只管天启篇|只进天启篇|天启篇专属|只用于天启篇')
# 有迹象、但确认是西游也要用的真脚本（路径 → 理由）；加这里要写清为什么能带真脚本进包
MIXED_OK = {
    'modes/xiyou/ui/tianqi_title.gd': '标题画面，发行包要用（KEEP）',
    'modes/xiyou/core/xdb.gd': '数据库总表；只有 content/gojo 贴图路径一行，图在 DENY 里不进包',
}
HAND = HERE / '发行空壳手写'  # 手写空壳：<类名>.gd，整份照用（要保留部分发行功能的，如漩涡二阶画面）
NUMERIC = set()  # 返回 int／float 的成员（check 要求它们不靠按类型空值）


def _strip_comment(line: str) -> str:
    out, q = [], None
    for i, ch in enumerate(line):
        if q:
            out.append(ch)
            if ch == q and line[i - 1] != '\\':
                q = None
        elif ch in '"\'':
            q = ch
            out.append(ch)
        elif ch == '#':
            break
        else:
            out.append(ch)
    return ''.join(out)


def targets(root: Path = PROJECT) -> dict:
    """要换成空壳的脚本：类名 → 路径（相对 root）。"""
    out = {}
    for d in ('modes',):
        for p in sorted((root / d).rglob('*.gd')):
            m = CLASS_RE.search(p.read_text(encoding='utf-8'))
            if m and (PREFIX_RE.match(m.group(1)) or m.group(1) in EXTRA) and m.group(1) not in KEEP:
                out[m.group(1)] = p.relative_to(root)
    return out


def external_refs(root: Path, tg: dict) -> dict:
    """西游代码（不算 tests、不算被换掉的脚本自己）用到的成员：类名 → {成员名}。"""
    names = sorted(tg, key=len, reverse=True)
    pat = re.compile(r'\b(' + '|'.join(names) + r')\b(?:\.(\w+))?')
    skip = {root / p for p in tg.values()}
    refs = {c: set() for c in tg}
    for d in SCAN_DIRS:
        base = root / d
        if not base.exists():
            continue
        for p in base.rglob('*'):
            if p.suffix not in ('.gd', '.tscn', '.tres') or p in skip:
                continue
            for line in p.read_text(encoding='utf-8', errors='replace').splitlines():
                if line.lstrip().startswith('#'):
                    continue
                for m in pat.finditer(_strip_comment(line)):
                    if m.group(2):
                        refs[m.group(1)].add(m.group(2))
    return refs


# ---- 读真脚本的顶层声明 ----

def _balance(s: str) -> int:
    s = re.sub(r'"(\\.|[^"\\])*"|\'(\\.|[^\'\\])*\'', '', _strip_comment(s))
    return sum(s.count(c) for c in '([{') - sum(s.count(c) for c in ')]}')


def parse(src: str) -> dict:
    """顶层：class_name、extends、signal、const／var、func（签名＋函数体前几行）。内部类整块跳过。"""
    lines = src.split('\n')
    info = {'class_name': '', 'extends': 'RefCounted', 'signals': [], 'vars': {}, 'funcs': {}}
    i = 0
    while i < len(lines):
        ln = lines[i]
        if not ln or ln[0] in ' \t#':
            i += 1
            continue
        if ln.startswith('class_name '):
            info['class_name'] = ln.split()[1]
        elif ln.startswith('extends '):
            info['extends'] = ln.split()[1].rstrip(':')
        elif ln.startswith('signal '):
            info['signals'].append(_strip_comment(ln).strip())
        elif ln.startswith('class '):
            i += 1
            while i < len(lines) and (not lines[i] or lines[i][0] in ' \t'):
                i += 1
            continue
        else:
            m = re.match(r'^(?:@\w+(?:\([^)]*\))?\s+)*(static\s+)?(const|var)\s+(\w+)\s*(?::(?!=)\s*([\w\[\]., ]+?))?\s*(:?=|$)\s*(.*)$', _strip_comment(ln).rstrip())
            f = re.match(r'^(static\s+)?func\s+(\w+)\s*\((.*)\)\s*(?:->\s*([\w\[\]., ]+))?\s*:', _strip_comment(ln))
            if m:
                expr = m.group(6) or ''
                bal = _balance(expr)
                j = i
                while bal > 0 and j + 1 < len(lines):
                    j += 1
                    expr += '\n' + lines[j]
                    bal += _balance(lines[j])
                info['vars'][m.group(3)] = {'static': bool(m.group(1)) or m.group(2) == 'const', 'kind': m.group(2),
                                            'type': (m.group(4) or '').strip(), 'expr': _strip_comment(expr).strip()}
                i = j + 1
                continue
            if f:
                body = []
                j = i + 1
                while j < len(lines) and (not lines[j] or lines[j][0] in ' \t'):
                    if lines[j].strip() and not lines[j].strip().startswith('#'):
                        body.append(lines[j].strip())
                    j += 1
                info['funcs'][f.group(2)] = {'static': bool(f.group(1)), 'params': f.group(3), 'ret': (f.group(4) or '').strip(),
                                             'sig': f"{'static ' if f.group(1) else ''}func {f.group(2)}({f.group(3)})" + (f' -> {f.group(4).strip()}' if f.group(4) else '') + ':',
                                             'body': body or [_strip_comment(ln).split(':', 1 + (1 if f.group(4) else 0))[-1].strip()]}
                i = j
                continue
        i += 1
    return info


def _param_names(params: str) -> list:
    out, depth, cur = [], 0, ''
    for ch in params:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [re.match(r'\s*(\w+)', p).group(1) for p in out if re.match(r'\s*(\w+)', p)]


EMPTY = {'bool': 'false', 'int': '0', 'float': '0.0', 'String': '""', 'StringName': '&""', 'Array': '[]', 'Dictionary': '{}',
         'Color': 'Color(0, 0, 0, 0)', 'Vector2': 'Vector2.ZERO', 'Vector2i': 'Vector2i.ZERO', 'Rect2': 'Rect2()', 'Callable': 'Callable()'}


def _empty_of(t: str) -> str:
    if t.startswith('Array['):
        return '[]'
    if t.startswith('Dictionary['):
        return '{}'
    return EMPTY.get(t, 'null')


LITERAL = re.compile(r'^(-?\d+(\.\d+)?|true|false|null|\[\]|\{\}|""|-?INF)$')


def func_body(cls: str, name: str, f: dict, over: dict) -> tuple:
    """返回 (函数体一行, 来历)。"""
    key = f'{cls}.{name}'
    if key in over:
        v = over[key]
        if v.startswith('BODY:'):
            return v[len('BODY:'):].strip().replace('\n', '\n\t'), '特例'
        return ('pass' if v == 'pass' else ('return ' + v if f['ret'] != 'void' else v)), '特例'
    if f['ret'] == 'void' or name == '_init':
        return 'pass', '无返回'
    params = _param_names(f['params'])
    # 真脚本里第一句「if …: return 简单值」（简单值＝参数、字面量、它们拼的数组）：天启篇关着时走的就是这条
    for k, line in enumerate(f['body'][:8]):
        m = re.match(r'^if (.*):\s*return (.+)$', line)
        v = m.group(2).strip() if m else (f['body'][k + 1][len('return'):].strip() if line.startswith('if ') and line.endswith(':')
                                           and k + 1 < len(f['body']) and f['body'][k + 1].startswith('return') else None)
        if v is not None:
            v = _strip_comment(v).strip()
            if _simple(v, params):
                return 'return ' + v, '照搬关着时的返回'
            break
    return 'return ' + _empty_of(f['ret']), '按类型空值'


def _simple(v: str, params: list) -> bool:
    v = _strip_comment(v).strip()
    if LITERAL.match(v) or v in params:
        return True
    if v.startswith('[') and v.endswith(']'):
        return all(_simple(x, params) for x in v[1:-1].split(',')) if v[1:-1].strip() else True
    return False


def var_value(cls: str, name: str, v: dict, over: dict) -> str:
    key = f'{cls}.{name}'
    if key in over:
        return over[key]
    e = v['expr']
    if re.fullmatch(r'-?\d+(\.\d+)?|true|false', e):
        return e
    if v['type']:
        return _empty_of(v['type'])
    if e.startswith('['):
        return '[]'
    if e.startswith('{'):
        return '{}'
    if e.startswith('"') or e.startswith("'"):
        return e if e.isascii() else '""'  # 英文键名（比对用）照留，中文说明文字不进包
    if re.fullmatch(r'-?\d+(\.\d+)?\s*[-+*/]\s*-?\d+(\.\d+)?', e):
        return e
    return 'null'


def stub(cls: str, path: Path, need: set, over: dict, root: Path = PROJECT) -> tuple:
    """返回 (空壳源码, 缺的成员, 每个函数的来历)。"""
    info = parse((root / path).read_text(encoding='utf-8'))
    out = [f'class_name {cls}', f'extends {info["extends"]}', f'{MARK}：发行包里天启篇没开放，这里只留西游代码用到的名字（07_开发环境/发行空壳.py 生成）。', STUB_TAG_LINE, '']
    node = info['extends'] not in ('RefCounted', 'Object', 'Resource')
    out += info['signals']
    missing, how = [], {}
    want = set(need)
    if node:  # 界面类：西游代码可能按实例调，公开函数都留
        want |= {n for n in info['funcs'] if not n.startswith('_')} | {n for n, v in info['vars'].items() if not n.startswith('_') and v['kind'] == 'var'}
    if '_init' in info['funcs']:
        want.add('_init')
    for n in sorted(want):
        if n in info['vars']:
            v = info['vars'][n]
            kw = ('static var' if v['kind'] == 'var' and v['static'] else v['kind'])
            t = f': {v["type"]}' if v['type'] else ''
            val = var_value(cls, n, v, over)
            if not t and val == 'null':
                out.append(f'{kw} {n} = null')
            else:
                out.append(f'{kw} {n}{t} {"=" if t else ":="} {val}' if val != 'null' or t else f'{kw} {n} = null')
        elif n in info['funcs']:
            f = info['funcs'][n]
            body, src = func_body(cls, n, f, over)
            how[n] = src
            sig = f['sig']
            if f['params'] and body != 'pass' or True:
                # 参数没用到会报警告（发行包不在意），参数名前加下划线会改签名，所以照留
                pass
            out += ['', sig, '\t' + body]
        elif n in ('new', 'get_script', 'free'):
            continue
        else:
            missing.append(n)
    return '\n'.join(out) + '\n', missing, how


def load_overrides() -> dict:
    if not OVERRIDES.is_file():
        return {}
    d = json.loads(OVERRIDES.read_text(encoding='utf-8'))
    return {k: v for k, v in d.items() if not k.startswith('_')}


def build_all(root: Path = PROJECT) -> tuple:
    NUMERIC.clear()
    tg = targets(root)
    refs = external_refs(root, tg)
    over = load_overrides()
    stubs, missing, how = {}, [], {}
    for c, p in tg.items():
        if (HAND / f'{c}.gd').is_file():  # 手写空壳：只核西游用到的成员都在
            s = (HAND / f'{c}.gd').read_text(encoding='utf-8')
            info = parse(s)
            stubs[p] = s
            missing += [f'{c}.{m}' for m in refs[c] if m not in info['funcs'] and m not in info['vars'] and m not in ('new',)]
            if STUB_TAG not in s:
                missing.append(f'{c}.{STUB_TAG_LINE}（手写空壳要带这行，发行内容审计靠它认空壳）')
            how.update({f'{c}.{k}': '手写' for k in info['funcs']})
            continue
        s, miss, h = stub(c, p, refs[c], over, root)
        stubs[p] = s
        missing += [f'{c}.{m}' for m in miss]
        how.update({f'{c}.{k}': v for k, v in h.items()})
        info = parse((root / p).read_text(encoding='utf-8'))
        NUMERIC.update(f'{c}.{k}' for k in h if info['funcs'][k]['ret'] in ('int', 'float'))
    return stubs, missing, how


def _literal_paths(src: str) -> list:
    """代码（不算注释）里的 res:// 路径字面量。"""
    out = []
    for line in src.splitlines():
        if line.lstrip().startswith('#'):
            continue
        out += re.findall(r'"res://([^"%]+)', _strip_comment(line))
    return out


def suspects(root: Path = PROJECT, tg: dict = None) -> list:
    """看着是天启篇专属、却既不换空壳也不在 MIXED_OK 的脚本：[(路径, 理由)]。空＝都归了类。
    迹象：文件名带 tianqi／gojo／qiyin／horsem；头注释（第一段代码前）说只在／只管／只进天启篇；
    代码里有指向没发行内容（发行内容审计.DENY）的 res:// 路径。"""
    tg = targets(root) if tg is None else tg
    done = {str(p) for p in tg.values()}
    try:
        import importlib.util
        sp = importlib.util.spec_from_file_location('发行内容审计', HERE / '发行内容审计.py')
        audit = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(audit)
        denied = audit.denied
    except Exception:  # noqa: BLE001
        denied = lambda _p: False  # noqa: E731
    out = []
    for d in SCAN_DIRS:
        base = root / d
        if not base.exists():
            continue
        for p in sorted(base.rglob('*.gd')):
            rel = str(p.relative_to(root))
            if rel in done or rel in MIXED_OK or rel.startswith(('tests/', '.godot/')):
                continue
            src = p.read_text(encoding='utf-8', errors='replace')
            head = []
            for ln in src.splitlines():
                if ln.startswith('#') or ln.startswith('class_name') or ln.startswith('extends') or not ln.strip():
                    head.append(ln)
                    continue
                break
            why = []
            if SUSPECT_NAME.search(p.name):
                why.append('文件名')
            if SUSPECT_HEAD.search('\n'.join(head)):
                why.append('头注释说只在天启篇')
            bad = [x for x in _literal_paths(src) if denied(x)]
            if bad:
                why.append('引用没发行内容 ' + bad[0])
            if why:
                out.append((rel, '、'.join(why)))
    return out


def check_errors(missing: list, how: dict, sus: list = None) -> list:
    errs = []
    if sus:
        errs.append('发行空壳：这些脚本像是天启篇专属，却既不换空壳也没登记成西游要用（发行空壳.py 的 EXTRA 或 MIXED_OK 二选一）：'
                    + '；'.join(f'{p}（{w}）' for p, w in sus))
    if missing:
        errs.append('发行空壳缺成员：' + '、'.join(missing))
    # 返回数字的函数按类型给 0 多半不对（倍率该是 1、次数该原样返回）：要在特例表里明确写
    guess = [k for k, v in how.items() if v == '按类型空值' and k in NUMERIC]
    if guess:
        errs.append('发行空壳：这些返回数字的函数没有明确的发行值，照真脚本发行时的行为写进 发行空壳特例.json：' + '、'.join(sorted(guess)))
    return errs


def make_tree(out: Path) -> Path:
    """克隆工程到 out 并换上空壳。out 不能已存在。"""
    if out.exists():
        raise SystemExit(f'{out} 已存在')
    stubs, missing, how = build_all(PROJECT)
    errs = check_errors(missing, how, suspects(PROJECT))
    if errs:
        raise SystemExit('\n'.join(errs))
    out.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(['cp', '-cR', str(PROJECT), str(out)])
    if r.returncode:
        shutil.copytree(PROJECT, out, symlinks=True)
    for p, s in stubs.items():
        (out / p).write_text(s, encoding='utf-8')
    return out


def is_stub_tree(root: Path) -> list:
    """root 里还没换成空壳的天启篇脚本（空＝都换了）：要有头注释 MARK 和编进包的 STUB_TAG。"""
    out = []
    for c, p in targets(root).items():
        s = (root / p).read_text(encoding='utf-8')
        if MARK not in s or STUB_TAG not in s:
            out.append(str(p))
    return out


def main(argv) -> int:
    if not argv or argv[0] not in ('tree', 'check', 'show', 'report'):
        print(__doc__)
        return 2
    if argv[0] == 'tree':
        print(make_tree(Path(argv[1]).resolve()))
        return 0
    stubs, missing, how = build_all()
    if argv[0] == 'show':
        tg = targets()
        print(stubs[tg[argv[1]]])
        return 0
    if argv[0] == 'report':
        for k in sorted(how):
            print(f'{k}\t{how[k]}')
        return 0
    errs = check_errors(missing, how, suspects())
    if errs:
        print('\n'.join(errs))
        return 1
    print(f'发行空壳：{len(stubs)} 个脚本，{len(how)} 个函数都有')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
