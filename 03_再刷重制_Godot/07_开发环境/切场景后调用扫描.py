#!/usr/bin/env python3
"""切场景后还调视口／场景树的写法扫描（platform-crash1，cc 2026-11-06）。

发行模板的 GDScript 对 null 调方法不查空，直接 SIGSEGV（调试版只报「Cannot call method … on a null value」，测试抓不到）。
11-06 天启篇按空格/J 闪退就是这一类：标题 `_unhandled_input` 里 `change_scene_to_file` 把自己摘下树，
同一函数下一行 `get_viewport().set_input_as_handled()` 拿到 null。

  python3 切场景后调用扫描.py            打印清单（文件:行、触发路径）
  python3 切场景后调用扫描.py --json     机器可读
  python3 切场景后调用扫描.py --check    有命中就退出 1（检查.sh tools 组用；确认安全的行在行尾写注释 `# 离树后安全：理由` 豁免）

怎么判：
  1. 「离树」写法：同步 `change_scene_to_file/packed/node(`、`reload_current_scene(`、`remove_child(self)`、`GameApp.enter_mode(`、`GameApp.return_to_menu(`
     （`.call_deferred` 的切场景要到帧末才摘，不算）。`queue_free()` 也不算：帧末才摘下树。
  2. 「离树函数」：本文件里含离树写法、或调用了本文件离树函数的函数；`信号.connect(离树函数／含离树写法的 lambda)` 记成「离树信号」，
     发出该信号的函数（全工程按信号名配，`x.emit(`／`emit_signal("x"`）也算离树函数。不动点迭代。
  3. 在离树写法、离树函数调用、离树信号发出之后，同一函数里还能走到的行若有 `get_viewport()`、`get_tree()`、`get_window()`、
     `get_parent()`、`create_tween()`（不在树上返回 null）、`get_node("/root…")`（只认对自己调用，`x.get_tree()` 不算），就是命中。同一块里先 `return` 的不算；
     `elif/else` 与 `match` 别的分支不算；同一行或外层 if 有 `is_inside_tree()`／`is_instance_valid(` 的不算。
档：直接（离树写法本身之后）／经调用（调了离树函数之后）／经回调（本文件把离树函数当 Callable 存起来，之后 `.call(` 它）／经信号（发了离树信号之后，信号按名字配，可能有同名误配）。
只扫 tests/ 以外；GameApp（autoload，自己不离树）里的命中跳过。已知漏：跨文件直接调别的类的方法（非信号）、await 之后的恢复（那条归 mv_interpreter 的 host_alive）。
"""
import argparse
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
SKIP_FILES = {'core/game_app.gd'}

LEAVE = re.compile(r'(?:\bchange_scene_to_(?:file|packed|node)\s*\(|\breload_current_scene\s*\(|\bremove_child\(\s*self\s*\)'
                   r'|\bGameApp\.(?:enter_mode|return_to_menu)\s*\()')
USE = re.compile(r'(?<![\w.\])])(?:self\.)?(get_viewport|get_tree|get_window|get_parent|create_tween)\s*\(\s*\)'
                 r'|(?<![\w.\])])get_node(?:_or_null)?\(\s*["\']/root|(?<![\w.\])])\$"?/root')
EXEMPT = '离树后安全'
GUARD = re.compile(r'is_inside_tree\(\)|is_instance_valid\(')
LAMBDA = re.compile(r'(?<![\w.])func\s*\(')
FUNC = re.compile(r'^(\s*)(?:static\s+)?func\s+(\w+)\s*\(')
CONNECT = re.compile(r'\b(\w+)\.connect\(\s*(?:self\.)?(\w+)')
CONNECT_LAMBDA = re.compile(r'\b(\w+)\.connect\(\s*func\b')
EMIT = re.compile(r'\b(\w+)\.emit\(|emit_signal\(\s*["\'](\w+)["\']')
CALL = re.compile(r'(?<![\w.])(?:self\.)?(\w+)\s*\(')
DYN_CALL = re.compile(r'\.callv?\(')
REF = re.compile(r'(?<![\w.])(?:self\.)?(\w+)\b(?!\s*\()')
GAMEAPP_REF = re.compile(r'\bGameApp\.(?:enter_mode|return_to_menu)\b(?!\s*\()')
BRANCH_KW = ('elif ', 'elif(', 'else:', 'else ')
HEADER_KW = ('if ', 'if(', 'for ', 'while ', 'func ', 'match ', 'static ', 'elif', 'else', 'class ', 'var ', 'const ')


def indent(s: str) -> int:
    return len(s) - len(s.lstrip('\t ').replace('\t', ' '))  # 只比较同一文件里的相对缩进


def strip_comment(s: str) -> str:
    out, q = [], None
    for ch in s:
        if q:
            out.append(ch)
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
            out.append(ch)
        elif ch == '#':
            break
        else:
            out.append(ch)
    return ''.join(out).rstrip()


def functions(path: Path):
    """按顶层 func 切分；每行另给一份「同步执行的部分」：去掉 lambda 体（inline 的 `func(...)` 起到行尾，多行 lambda 的整段）。"""
    lines = [strip_comment(l) for l in path.read_text(encoding='utf-8').splitlines()]
    funcs, cur, lam = [], None, None
    for i, l in enumerate(lines):
        m = FUNC.match(l)
        if m and indent(l) == 0:
            cur = {'name': m.group(2), 'start': i, 'lines': [], 'sync': {}}
            funcs.append(cur)
            lam = None
            continue
        if cur is None:
            continue
        if l.strip() and indent(l) == 0:
            cur = None
            continue
        cur['lines'].append((i, l))
        if lam is not None and l.strip() and indent(l) > lam:
            cur['sync'][i] = ''
            continue
        lam = None
        k = LAMBDA.search(l)
        if k:
            cur['sync'][i] = l[:k.start()]
            if l.rstrip().endswith(':'):
                lam = indent(l)
        else:
            cur['sync'][i] = l
    return funcs


def reachable_after(body, k):
    """body[k] 之后、同一函数里从 body[k] 那条路还能走到的行。"""
    _, start = body[k]
    d = indent(start)
    out, skip_below = [], None
    block = d
    for i, l in body[k + 1:]:
        if not l.strip():
            continue
        ind = indent(l)
        s = l.strip()
        if skip_below is not None:
            if ind > skip_below:
                continue
            skip_below = None
        if ind < block:
            block = ind
            # 离开当前块：同级的 elif/else、match 的别的分支走不到
            if s.startswith(BRANCH_KW) or (s.endswith(':') and not s.startswith(HEADER_KW)):
                skip_below = ind
                continue
        if ind == block and s in ('return', 'break', 'continue') or (ind == block and s.startswith('return ')):
            out.append((i, l))
            # 这一块到此为止；外层还可能接着走（return 例外：整个函数结束）
            if s.startswith('return'):
                break
            skip_below = ind - 1 if ind > 0 else None
            continue
        out.append((i, l))
    return out


def guarded(body, k_line, l):
    if GUARD.search(l):
        return True
    ind = indent(l)
    for i, ol in reversed(body):
        if i >= k_line:
            continue
        if ol.strip() and indent(ol) < ind:
            ind = indent(ol)
            if ol.strip().startswith(('if ', 'elif ', 'while ')) and GUARD.search(ol):
                return True
            if ind == 0:
                break
    return False


def scan(root: Path = PROJECT):
    files, raw = {}, {}
    for p in sorted(root.rglob('*.gd')):
        rel = p.relative_to(root).as_posix()
        if rel.startswith('tests/') or rel.startswith('.godot/'):
            continue
        files[rel] = functions(p)
        raw[rel] = p.read_text(encoding='utf-8').splitlines()
    leaving = {rel: set() for rel in files}      # 离树函数名
    leave_signals = {}                           # 信号名 -> 说明
    leave_refs = {}                              # 文件 -> 被当 Callable 存起来的离树函数（该文件里的 .call( 也算离树）

    def trigger(rel, f, sync):
        """这一行（只看同步执行的部分）会不会让节点离树：返回 (档, 说明, 离树写法结束位置) 或 None。"""
        lm = LEAVE.search(sync)
        if lm:
            return '直接', lm.group(0).rstrip('(').strip(), lm.end()
        calls = [n for n in CALL.findall(sync) if n in leaving[rel] and n != f['name']]
        if calls:
            return '经调用', calls[0] + '()', 0
        if rel in leave_refs and DYN_CALL.search(sync):
            return '经回调', '.call()（本文件把 ' + leave_refs[rel] + ' 当 Callable 存起来）', 0
        emits = [g for m in EMIT.findall(sync) for g in m if g and g in leave_signals]
        if emits:
            return '经信号', emits[0] + '.emit（接到 ' + leave_signals[emits[0]] + '）', 0
        return None

    changed = True
    while changed:
        changed = False
        for rel, funcs in files.items():
            for f in funcs:
                for i, l in f['lines']:
                    sync = f['sync'].get(i, l)
                    if f['name'] not in leaving[rel] and trigger(rel, f, sync):
                        leaving[rel].add(f['name'])
                        changed = True
                    refs = [n for n in REF.findall(l) if n in leaving[rel]]
                    g = GAMEAPP_REF.search(l)
                    if g:
                        refs.append(g.group(0))
                    if refs and rel not in leave_refs:
                        leave_refs[rel] = refs[0]
                        changed = True
                    for sig, target in CONNECT.findall(l):
                        if target in leaving[rel] and sig not in leave_signals:
                            leave_signals[sig] = f'{rel} {target}'
                            changed = True
                    m = CONNECT_LAMBDA.search(l)
                    if m and LEAVE.search(l[m.end():]) and m.group(1) not in leave_signals:
                        leave_signals[m.group(1)] = f'{rel} lambda'
                        changed = True
    hits = []
    for rel, funcs in files.items():
        if rel in SKIP_FILES:
            continue
        for f in funcs:
            body = [(i, f['sync'].get(i, l)) for i, l in f['lines']]
            for k, (i, sync) in enumerate(body):
                t = trigger(rel, f, sync)
                if not t:
                    continue
                kind, why, end = t
                tail = sync[end:]
                cand = ([(i, tail)] if ';' in tail else []) + reachable_after(body, k)
                for j, ul in cand:
                    um = USE.search(ul)
                    if um and not guarded(body, j, ul) and EXEMPT not in raw[rel][j]:
                        hits.append({'file': rel, 'line': j + 1, 'func': f['name'], 'kind': kind,
                                     'trigger': f'{why}（第 {i + 1} 行）', 'use': um.group(0), 'code': ul.strip()})
    return hits


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--root', default=str(PROJECT))
    a = ap.parse_args()
    hits = scan(Path(a.root))
    if a.json:
        print(json.dumps(hits, ensure_ascii=False, indent=1))
    else:
        for h in hits:
            print(f"[{h['kind']}] {h['file']}:{h['line']}  {h['func']}()  {h['trigger']} 之后 {h['use']}\n      {h['code']}")
        print(f'共 {len(hits)} 处（直接 {sum(h["kind"] == "直接" for h in hits)}）')
    return 1 if a.check and hits else 0


if __name__ == '__main__':
    sys.exit(main())
