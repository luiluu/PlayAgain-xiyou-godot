#!/usr/bin/env python3
"""交付自检：车道交付前，只读地预演总装合并「准备阶段」会查的东西，问题在车道里就改掉，不留到合并时才停。

为什么有它（Kyo 2026-11-11，合并瓶颈提案）：11-09～11-10 两条合并队列各重起 5 次，全是格式问题——交付单缺「状态：可合并」行或
「## 变更记录草稿」节、优化登记草稿写成列表、具名 O 号占位没发号、车道工作树有未跟踪文件、缺接受单或接受单条数不够。
每次失败都要等总装或哨兵下一轮回来才有人修，一条格式问题卡全队半小时到几小时。这些检查总装的 合并车道.py 都有，
只是只能在干净的 main 上跑（--dry-run 也是），车道用不了。

做法：在临时目录建一个借用本库对象的空库（等同 `git clone --shared`：只读本库的对象，不往本库写引用、不动任何工作树），检出 main，
①照搬 合并车道.py 的 plan()（交付单有且只有一份、状态行、变更记录草稿、优化登记草稿表、占位对号、删基线参照用例……与合并用的是同一份代码）；
②真的 `git merge --no-ff --no-commit` 一次看有没有冲突；③合并后的 .gd 查同名 func、await 三元式、冲突标记（纯文本，不要 godot）；
④在自己的工作树里跑时再查：有没有未提交改动；慢车道（改了切片、转换器、参照探针或带接受单）的同步指纹还在不在、
本树同步留下的测量变化有没有对应的接受单、条目够不够。
自检和合并一样只看**已提交**的内容：先提交，再跑；有问题改完提交后重跑。

用法（在车道自己的工作树里，写好交付单、提交之后）：
  python3 03_再刷重制_Godot/07_开发环境/交付自检.py              查当前分支
  python3 …/交付自检.py --branch cc/别的车道 [--task 交付单名]   查别的分支（不查工作树；总装、看板用）
  python3 …/交付自检.py --main github/main                      指定拿哪个 main 比（默认见 pick_main）
  python3 …/交付自检.py --json                                   机器读
退出码：0 可以交付；1 有问题（逐条列出，改完重跑）；2 用法或环境问题。
分道：输出里写明本车道是快车道（合并不用同步）还是慢车道（合并要同步），总装按 多会话并行.md「排队顺序」排队。
回退：不想用就不跑，它不改任何文件；合并工具不依赖它。"""
import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


merge = load('lane_merge_for_precheck', HERE / '合并车道.py')
git = merge.git
SHEET_DIR = '00_项目管理/交付/'
SHEET_NAME = re.compile(r'(?:cc|claude|codex)_(.+)\.md')
GENERATED = merge.PROJECT / 'modes/xiyou/generated'
# 沙盒里没有工作树停在车道分支上，plan() 每次都打这句，对车道没有信息量
NOISE = ('没有工作树停在',)
SIM_ENV = dict(os.environ, GIT_AUTHOR_NAME='precheck', GIT_AUTHOR_EMAIL='precheck@example.invalid',
               GIT_COMMITTER_NAME='precheck', GIT_COMMITTER_EMAIL='precheck@example.invalid')


def quiet(root, *args):
    """git 命令的 (退出码, 标准输出)；不抛错。"""
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', *args], capture_output=True, text=True, env=SIM_ENV)
    return p.returncode, p.stdout.strip()


def resolve(root, ref):
    rc, out = quiet(root, 'rev-parse', '--verify', '-q', ref + '^{commit}')
    return out if rc == 0 else ''


def remotes(root):
    return quiet(root, 'remote')[1].split()


def pick_main(root, prefer=None):
    """拿哪个 main 比：给了 --main 就用它；否则在本地 main、github/main、origin/main 里挑「别的都是它祖先」的那个
    （Mac 上本地 main 是原件，云端克隆里本地 main 常是旧的、origin/main 才新）；互不包含时用本地 main（没有就第一个）。"""
    if prefer:
        sha = resolve(root, prefer)
        if not sha:
            raise RuntimeError('找不到 --main 指的提交：' + prefer)
        return prefer, sha
    found = [(r, resolve(root, r)) for r in ['main'] + [x + '/main' for x in ('github', 'origin')]]
    found = [(r, s) for r, s in found if s]
    if not found:
        raise RuntimeError('本库没有 main、github/main、origin/main，用 --main <提交> 指定')
    for ref, sha in found:
        if all(quiet(root, 'merge-base', '--is-ancestor', other, sha)[0] == 0 for _, other in found):
            return ref, sha
    return found[0]


def local_name(root, ref):
    """分支短名：refs/heads/x、<远端>/x、refs/remotes/<远端>/x 都还原成 x（合并工具按本地分支名找交付单）。"""
    name = re.sub(r'^refs/(?:heads|remotes)/', '', ref)
    if resolve(root, 'refs/heads/' + name):
        return name
    for r in remotes(root):
        if name.startswith(r + '/'):
            return name[len(r) + 1:]
    return name


def lane_sheets(root, main_sha, target):
    """车道分支上有、main 上没有的交付单 {相对路径: 正文}。main 已归并删除、车道上仍是删前原样的旧单不算
    （车道没合 main 时树里会留着早先几期的）。"""
    rc, out = quiet(root, 'ls-tree', '--name-only', target, SHEET_DIR)
    names = [n for n in out.splitlines() if n.endswith('.md') and not n.endswith('/README.md')]
    found = {}
    for n in names:
        if quiet(root, 'cat-file', '-e', main_sha + ':' + n)[0] == 0:
            continue
        removed = quiet(root, 'log', '--diff-filter=D', '--format=%H', '-1', main_sha, '--', n)[1]
        if removed and quiet(root, 'rev-parse', removed + '^:' + n)[1] == quiet(root, 'rev-parse', target + ':' + n)[1]:
            continue
        found[n] = quiet(root, 'show', target + ':' + n)[1]
    return found


def sheet_status(text):
    """交付单状态：'ready'（可合并、草稿齐）、'draft'（标了可合并但草稿节有问题，附原因）、'wip'（没标可合并）。"""
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            merge.draft(text)
        return 'ready', ''
    except RuntimeError as e:
        return ('wip', '') if '尚未标为可合并' in str(e) else ('draft', str(e))


def guess_task(name, sheets):
    """任务名（＝交付单名去掉 cc_／claude_／codex_ 前缀）：交付单按分支名找得到就用分支名的后半；
    否则分支上只带一份新交付单时用它的名字（app 自建工作树的随机名分支）。"""
    own = SHEET_DIR + name.replace('/', '_') + '.md'
    tail = name.split('/', 1)[-1]
    if own in sheets or not sheets:
        return tail
    tasks = {m.group(1) for m in (SHEET_NAME.fullmatch(Path(n).name) for n in sheets) if m}
    if tail in tasks or len(tasks) != 1:
        return tail
    return tasks.pop()


class Sandbox:
    """临时库：对象走本库的 alternates（等同 `git clone --shared`），引用、暂存区、工作树都在临时目录里，本库一个字节都不写。"""

    def __init__(self, root):
        self.root = Path(root)
        self.tmp = tempfile.mkdtemp(prefix='xiyou_precheck_')
        self.repo = Path(self.tmp) / 'repo'
        try:
            # 不用 git clone --shared：源库是浅克隆（云端容器）时它会退成真拷贝、还只拷本地分支，远端分支的对象就没了。
            # 自己建空库、把 alternates 指到本库的对象目录，浅克隆的边界文件也带上；本库只被读。
            common = Path(git(self.root, 'rev-parse', '--path-format=absolute', '--git-common-dir'))
            git(self.tmp, 'init', '-q', '-b', 'main', str(self.repo))
            info = self.repo / '.git/objects/info'
            info.mkdir(parents=True, exist_ok=True)
            (info / 'alternates').write_text(str(common / 'objects') + '\n')
            if (common / 'shallow').is_file():
                shutil.copy2(common / 'shallow', self.repo / '.git/shallow')
        except (RuntimeError, OSError) as e:
            shutil.rmtree(self.tmp, ignore_errors=True)
            raise RuntimeError('建临时库失败：%s' % e)
        self.main = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def reset(self, main_sha):
        """把沙盒的 main 放到这个提交、检出、清干净。"""
        quiet(self.repo, 'merge', '--abort')
        rc, _ = quiet(self.repo, 'checkout', '-q', '-f', '-B', 'main', main_sha)
        if rc:
            raise RuntimeError('沙盒检出 main（%s）失败' % main_sha[:9])
        quiet(self.repo, 'clean', '-fdq')
        self.main = main_sha
        self._baseline()

    def _baseline(self):
        """主工作区已发布的事件状态参照（不入 Git）拷一份进沙盒：plan() 查「车道删了基线参照用例」时凭它只留基线里真有的，
        没有它会多报。找不到主工作区或文件就算了。"""
        try:
            first = merge.worktrees(self.root)[0]['path']
        except (subprocess.CalledProcessError, IndexError, KeyError):
            return
        src = Path(first) / merge.STATE_BASELINE
        if src.is_file():
            dst = self.repo / merge.STATE_BASELINE
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            info = self.repo / '.git/info/exclude'
            info.parent.mkdir(parents=True, exist_ok=True)
            line = '/' + str(merge.STATE_BASELINE)
            if not info.exists() or line not in info.read_text():
                with info.open('a') as f:
                    f.write(line + '\n')

    def branch(self, name, sha):
        quiet(self.repo, 'update-ref', 'refs/heads/' + name, sha)

    def try_merge(self, target, gone=(), keep=False):
        """在沙盒当前 main 上试合并：返回 (冲突文件, 合并后的静态问题)。keep=True 且没冲突时提交在沙盒里（看板按顺序往上叠），
        否则退回原样。只是 main 已归并删除的旧交付单 modify/delete 冲突时按删除处理（合并工具同口径）。"""
        before = quiet(self.repo, 'rev-parse', 'HEAD')[1]
        rc, _ = quiet(self.repo, 'merge', '--no-ff', '--no-commit', target)
        conflicts = quiet(self.repo, 'diff', '--name-only', '--diff-filter=U')[1].splitlines()
        if conflicts and set(conflicts) <= set(gone):
            for p in conflicts:
                quiet(self.repo, 'rm', '-q', '--', p)
            conflicts = []
        problems = []
        if not conflicts:
            if rc and not quiet(self.repo, 'rev-parse', '-q', '--verify', 'MERGE_HEAD')[1]:
                conflicts = ['（git merge 失败，没有列出冲突文件）']
            else:
                problems = self._static(before)
        if conflicts or not keep:
            quiet(self.repo, 'merge', '--abort')
            quiet(self.repo, 'reset', '-q', '--hard', before)
            quiet(self.repo, 'clean', '-fdq')
        else:
            quiet(self.repo, 'commit', '-q', '--no-verify', '-m', 'precheck sim')
        return conflicts, problems

    def _static(self, before):
        """合并后（暂存区）相对合并前的静态问题：同名 func、await 三元式、冲突标记。"""
        problems = []
        rc, out = quiet(self.repo, 'diff', '--cached', '--name-only', '--diff-filter=AM', before, '--', '*.gd')
        for rel in out.splitlines():
            f = self.repo / rel
            if f.is_file():
                for name, lines in merge.duplicate_funcs(f.read_text(errors='replace')):
                    problems.append('合并后 %s：func %s 重复定义（第 %s 行；你和 main 各加了一个，git 不报冲突但工程整个 Parse Error）'
                                    % (rel, name, '、'.join(map(str, lines))))
        project = self.repo / merge.PROJECT
        if project.is_dir():
            problems += merge.gd_await_ternary_problems(project)
        try:
            marked = merge.conflict_markers(self.repo, '--cached', before)
        except RuntimeError:
            marked = []
        if marked:
            problems.append('提交里带冲突标记（<<<<<<< / >>>>>>>）：' + '、'.join(marked))
        return problems


def slow_reasons(root, fork, target):
    """哪些改动让合并要跑同步（与 plan() 的 refresh 同口径），给人看。"""
    rc, out = quiet(root, 'diff', '--name-only', fork, target)
    tools = str(merge.TOOLS)
    why = []
    for p in out.splitlines():
        if p in (tools + '/xiyou_slice.json', tools + '/xiyou_export.py'):
            why.append(Path(p).name)
        elif p.startswith(tools + '/mv_oracle/') and p.endswith('.cjs'):
            why.append('mv_oracle/' + Path(p).name)
        elif p.startswith(str(merge.ACCEPT) + '/') and p.endswith('.json'):
            why.append('接受单 ' + Path(p).name)
    return why


def local_checks(wt, state, result):
    """在车道自己的工作树里才查得到的：未提交改动、慢车道的同步指纹与接受单。"""
    try:
        evidence = merge.untracked_evidence(wt)
        changed = [] if evidence else sorted(merge.dirty(wt))
    except (RuntimeError, subprocess.CalledProcessError) as e:
        result['problems'].append('工作树状态读不了：%s' % e)
        return
    if changed:
        result['problems'].append('工作树有未提交或未跟踪的改动（%s%s）：自检和合并都只看已提交的内容，合并工具见到不干净的车道工作树会停下。'
                                  '提交它们；本地输出放 %s 下（那里不拦）' % ('、'.join(changed[:6]), ' 等 %d 个' % len(changed) if len(changed) > 6 else '',
                                                               merge.EVIDENCE_DIRS[1]))
    if not state or not state.get('refresh'):
        return
    gen = wt / GENERATED
    if not gen.is_dir():
        result['hints'].append('本机没有转换产物（云端车道）：总装合并时要在 main 上完整同步，按慢车道排队')
        return
    stamp_file = gen / 'sync_stamp.json'
    try:
        stamp = json.loads(stamp_file.read_text())
    except (OSError, ValueError):
        stamp = None
    if not isinstance(stamp, dict):
        result['problems'].append('慢车道没有同步指纹（%s）：交付前在本树跑一次 同步正式西游.py --accept-additions，总装合并才能直接用本树产物，'
                                  '否则 main 上整份重跑、堵住全队' % (GENERATED / 'sync_stamp.json'))
        return
    try:
        sync = load('sync_for_precheck', wt / merge.TOOLS / '同步正式西游.py')
        stale = stamp.get('toolsDigest') != sync.tools_digest(wt)
    except Exception as e:  # noqa: BLE001 同步脚本读不了不该让自检崩
        result['hints'].append('同步指纹没核对成（%s）' % str(e)[:80])
        stale = False
    if stale:
        result['problems'].append('同步之后又改了转换工具文件，指纹失效：重新跑一次 同步正式西游.py --accept-additions 再交付')
        return
    if not stamp.get('pendingAcceptance'):
        return
    # 本树同步留着没接受的测量变化：main 合并时同样拒收，接受单要随分支带上，条目要盖住全部变化
    need = pending_candidates(wt)
    have = accepted_keys(wt, state.get('acceptChanges') or [])
    sheet = merge.ACCEPT / (state['branch'].replace('/', '_') + '.json')
    make = 'python3 %s --out %s --reason-from %s' % (merge.TOOLS / '生成接受单.py', sheet, state['delivery'])
    if not state.get('acceptChanges'):
        result['problems'].append('本树同步有待接受的测量变化，分支里却没有接受单（%s 下）：合并到同步那步会被拒。核对变化无误后 %s，'
                                  '逐条补理由（至少 4 字）并提交' % (merge.ACCEPT, make))
    elif need is not None:
        missing = [k for k in need if k not in have]
        if missing:
            result['problems'].append('接受单少 %d 条（最新同步报告有 %d 处变化，如 %s）：重跑 %s 补齐（只追加没有的条目），核对后提交'
                                      % (len(missing), len(need), ' / '.join(map(str, missing[0])), make))


def pending_candidates(wt):
    """本树最新一份带 changeCandidates 的同步报告里的变化键 [(file, collection, key)]；读不到返回 None。"""
    folder = wt / merge.SUB / '04_验证/本地结果/自动同步'
    for d in sorted((p for p in folder.glob('*') if p.is_dir()), reverse=True):
        try:
            cands = json.loads((d / '同步报告.json').read_text()).get('changeCandidates')
        except (OSError, ValueError, AttributeError):
            continue
        if cands:
            return [entry_key(c) for c in cands if isinstance(c, dict)]
    return None


def entry_key(c):
    key = c.get('key')
    return (c.get('file'), c.get('collection'), json.dumps(key, ensure_ascii=False, sort_keys=True))


def accepted_keys(wt, paths):
    keys = set()
    for p in paths:
        try:
            for c in json.loads((wt / p).read_text()).get('accept') or []:
                if isinstance(c, dict):
                    keys.add(entry_key(c))
                    if c.get('key') == '*':     # 换源的整组条目盖住这个（文件, 集合）的全部
                        keys.add((c.get('file'), c.get('collection'), None))
        except (OSError, ValueError, AttributeError):
            continue
    return _Covering(keys)


class _Covering(set):
    def __contains__(self, k):
        return set.__contains__(self, k) or set.__contains__(self, (k[0], k[1], None))


def check(root, ref, task=None, main=None, sandbox=None, local=None):
    """查一条车道。返回 dict：branch、task、target、main、status（merged／ready／draft／wip／nosheet）、problems、hints、
    conflicts、slow、slowWhy、gameplay、delivery、changed；status 另有 unrelated（和 main 没有共同历史）。sandbox 给了就用它（调用方负责 reset 之外的生命周期）。"""
    root = Path(root)
    main_ref, main_sha = main if isinstance(main, tuple) else pick_main(root, main)
    target = resolve(root, ref)
    if not target:
        raise RuntimeError('找不到分支或提交：' + ref)
    name = local_name(root, ref)
    result = dict(branch=name, ref=ref, target=target, main=main_sha, mainRef=main_ref, problems=[], hints=[], conflicts=[],
                  slow=False, slowWhy=[], gameplay=False, delivery='', task=task or '', status='ready', changed=[], goneSheets=[])
    if quiet(root, 'merge-base', '--is-ancestor', target, main_sha)[0] == 0:
        result['status'] = 'merged'
        result['hints'].append('这个分支的提交都已经在 %s 里了，没有要合并的' % main_ref)
        return result
    sheets = lane_sheets(root, main_sha, target)
    task = task or guess_task(name, sheets)
    result['task'] = task
    fork = quiet(root, 'merge-base', main_sha, target)[1]
    if not fork:
        result['status'] = 'unrelated'
        result['problems'].append('和 %s 没有共同历史，没法试合并（浅克隆里的旧分支常这样：在 Mac 主仓库跑，或先 git fetch --unshallow）' % main_ref)
        return result
    result['changed'] = quiet(root, 'diff', '--name-only', fork, target)[1].splitlines()
    if not sheets:
        result['status'] = 'nosheet'
    elif all(sheet_status(t)[0] == 'wip' for t in sheets.values()):
        result['status'] = 'wip'
    own = sandbox is None
    box = sandbox or Sandbox(root)
    state = None
    try:
        box.reset(main_sha)
        box.branch(name, target)
        err = io.StringIO()
        try:
            with contextlib.redirect_stderr(err), contextlib.redirect_stdout(err):
                state = merge.plan(box.repo, task, name)
        except RuntimeError as e:
            result['problems'].append(str(e))
            if result['status'] == 'ready':
                result['status'] = 'draft'
        except subprocess.CalledProcessError as e:
            result['problems'].append('git 命令失败：%s' % e)
        for line in err.getvalue().splitlines():
            line = line.strip()
            if line.startswith('提示：') and not any(n in line for n in NOISE):
                result['hints'].append(line[3:])
        gone = state.get('goneSheets', []) if state else []
        conflicts, static = box.try_merge(target, gone)
        if conflicts:
            result['conflicts'] = conflicts
            if all(c.startswith(SHEET_DIR) for c in conflicts):
                # 交付单在 main 已归并删除、车道没合 main 又改了它（modify/delete）：多半是上一期合并后在旧单上补写，不是新的交付
                result['problems'].append('交付单 %s 在 %s 已随上一期归并删除，车道之后又改了它（没先合 main）：要交付新的一期，先 git merge main，'
                                          '再重写交付单（只写本期内容）' % ('、'.join(conflicts), main_ref))
            else:
                result['problems'].append('和 %s 合并有冲突（%s%s）：在车道里 git merge main 解掉、重跑相关专项后再交付'
                                          % (main_ref, '、'.join(conflicts[:6]), ' 等 %d 个' % len(conflicts) if len(conflicts) > 6 else ''))
        result['problems'] += static
    finally:
        if own:
            box.__exit__()
    if state:
        result.update(slow=bool(state['refresh']), gameplay=bool(state['gameplay']), delivery=state['delivery'], goneSheets=gone,
                      slowWhy=slow_reasons(root, fork, target) if state['refresh'] else [])
        if state.get('mainAdvancedAfterDelivery') and not result['conflicts']:
            result['hints'].append('交付后 main 又前进了，但没有冲突：按「验收只做一轮」不用再合 main')
    if local is None:
        rc, top = quiet(root, 'rev-parse', '--show-toplevel')
        local = rc == 0 and quiet(root, 'branch', '--show-current')[1] == name and quiet(root, 'rev-parse', 'HEAD')[1] == target
    if local:
        fake = state or dict(refresh=False)
        local_checks(Path(quiet(root, 'rev-parse', '--show-toplevel')[1]), fake, result)
    return result


def lane_class(result):
    if result['slow']:
        return '慢车道（改了 %s；合并要跑同步，排队尾或夜里）' % '、'.join(result['slowWhy'][:5] or ['切片／转换器／探针'])
    return '快车道（不动切片、转换器、参照探针，合并不用同步，先合先推）'


def render(result, out=sys.stdout):
    w = lambda s='': print(s, file=out)  # noqa: E731
    w('交付自检 %s（任务 %s，提交 %s；对 %s %s）' % (result['branch'], result['task'], result['target'][:9], result['mainRef'], result['main'][:9]))
    if result['status'] == 'merged':
        w('  ' + result['hints'][0])
        return
    if result['problems']:
        w('✗ 问题 %d 个：' % len(result['problems']))
        for i, p in enumerate(result['problems'], 1):
            w('  %d. %s' % (i, p.replace('\n', '\n     ')))
    else:
        w('✓ 合并准备阶段的检查全过（交付单、草稿、优化登记草稿、占位、试合并）')
    for h in result['hints']:
        w('  提示：' + h)
    if result['delivery']:
        w('  分道：' + lane_class(result))
        w('  开发编号：' + ('合并时递增（改了游戏内容）' if result['gameplay'] else '不递增（只改文档、工具或测试）'))
    w('结论：' + ('先改完上面的问题、提交后重跑本工具，再报可合并' if result['problems'] else '可以交付'))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default='.', help='在哪个工作树里跑（默认当前目录）')
    ap.add_argument('--branch', help='查哪个分支（默认当前分支）；给了且不是当前分支时不查工作树')
    ap.add_argument('--task', help='交付单名（去掉 cc_／claude_／codex_ 前缀）；默认按分支名或分支上唯一的新交付单认')
    ap.add_argument('--main', help='拿哪个 main 比（默认本地 main、github/main、origin/main 里最新的）')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    try:
        root = Path(git(a.root, 'rev-parse', '--show-toplevel'))
        ref = a.branch or git(root, 'branch', '--show-current')
        if not ref:
            raise RuntimeError('当前不在任何分支上（游离 HEAD）：用 --branch 指定')
        if local_name(root, ref) == 'main':
            raise RuntimeError('main 不是车道分支；在车道工作树里跑，或用 --branch 指定')
        result = check(root, ref, task=a.task, main=a.main)
    except (RuntimeError, subprocess.CalledProcessError) as e:
        print('交付自检没跑成：%s' % e, file=sys.stderr)
        return 2
    if a.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        render(result)
    return 1 if result['problems'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
