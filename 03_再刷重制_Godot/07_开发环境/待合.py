#!/usr/bin/env python3
"""待合看板：一张表列出所有「交了还没进 main」的车道分支——等了多久、自检过没过、快车道还是慢车道、和谁冲突、建议先合谁。

为什么有它（Kyo 2026-11-11，合并瓶颈提案）：待合队列原来只记在总装的接续笔记里，不在派单里的车道没人知道
（开场声明屏 claude/objective-mayer-333ac4 11-08 交付、11-10 才合，等了两天）；云端线程的分支只在 github 上，总装要逐个 fetch 才看得到；
一条重探针的慢车道排在队头，后面几条十几秒就能合的全陪着等（11-10 凌晨五条各等 4～5 小时）。

只读：不改任何文件、不动任何工作树、不往本库写引用（试合并在 交付自检.py 的临时克隆里做）。只有加 --fetch 才联网更新远端分支。

  python3 03_再刷重制_Godot/07_开发环境/待合.py            看板（本地分支＋已 fetch 的远端分支）
  python3 …/待合.py --fetch                                 先 git fetch --prune 各远端（云端线程的分支只在远端）
  python3 …/待合.py --all                                   「没交付」的旧分支也全列（默认只列最近 3 天有提交的）
  python3 …/待合.py --json                                  机器读（哨兵、协调用）
  python3 …/待合.py --check [--stale-hours 4]               有「可合并」车道等过这么多小时就退出 1（给定时巡检）

排法（规则在 00_项目管理/规则/多会话并行.md「排队顺序」）：
  1. 自检没过的不排，退回车道（问题逐条列在下面）。
  2. 快车道（合并不用同步）在前，按交付时间先到先合；慢车道（改了切片、转换器、参照探针或带接受单）在后，单独一批。
  3. 按这个顺序在临时克隆里一条条往上叠着试合并：和前面已排的车道冲突的那条退回车道（先让前面的合完，车道 git merge main 再交付）。
表下打印可直接用的 --queue 写法。回退：不用就不跑；合并工具不依赖它。"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


pre = load('lane_precheck', HERE / '交付自检.py')
quiet, git = pre.quiet, pre.git
# 车道分支只有这三种前缀（合并车道.py lane_branches）；ci/、ci-full/、ci-export/（云端测试与导出用的推送分支）、backup/ 等都不是车道
LANE = re.compile(r'^(?:cc|gpt|xa|claude|codex)/')
WORKER = re.compile(r'^\s*[-*]\s*车道[／/]工作者[：:]\s*(.+?)\s*$', re.M)


def candidates(root, main_sha):
    """还没进 main 的分支 {短名: dict(ref, sha, time, where)}。本地和远端同名时：一样就记一条；不一样时取包含对方的那个
    （谁新用谁），互不包含取本地并标出来。"""
    remotes = pre.remotes(root)
    rc, out = quiet(root, 'for-each-ref', '--no-merged', main_sha, '--format=%(refname)%09%(objectname)%09%(committerdate:unix)',
                    'refs/heads', 'refs/remotes')
    found = {}
    for line in out.splitlines():
        ref, sha, when = line.split('\t')
        if ref.startswith('refs/heads/'):
            name, where = ref[len('refs/heads/'):], '本地'
        else:
            rest = ref[len('refs/remotes/'):]
            remote = next((r for r in sorted(remotes, key=len, reverse=True) if rest.startswith(r + '/')), None)
            if not remote:
                continue
            name, where = rest[len(remote) + 1:], remote
        if not LANE.match(name):
            continue
        cur = dict(ref=ref, sha=sha, time=int(when), where=where, note='')
        old = found.get(name)
        if not old or old['sha'] == sha:
            if old:
                old['where'] += '＋' + where
            else:
                found[name] = cur
            continue
        if quiet(root, 'merge-base', '--is-ancestor', old['sha'], sha)[0] == 0:
            cur['note'] = '%s 的比 %s 的新，按 %s 的算' % (where, old['where'], where)
            found[name] = cur
        elif quiet(root, 'merge-base', '--is-ancestor', sha, old['sha'])[0] == 0:
            old['note'] = '%s 的比 %s 的新，按 %s 的算' % (old['where'], where, old['where'])
        else:
            keep = old if old['where'].startswith('本地') else cur
            keep['note'] = '本地与远端分叉了，按%s的算，先核对' % keep['where']
            found[name] = keep
    return found


def describe(root, main_sha, name, info):
    """一条分支的交付单状态（不建沙盒，便宜）：status＝ready／draft／wip／nosheet，worker、sheet。
    认哪张：按分支名对得上的那张（合并工具先找它）；没有时分支上只带一张新交付单就认它；
    带了好几张又没有自己名字的（从集成分支切出来的）取状态最靠前的一张，合不合得了由自检说。"""
    sheets = pre.lane_sheets(root, main_sha, info['sha'])
    own = pre.SHEET_DIR + name.replace('/', '_') + '.md'
    order = {'ready': 0, 'draft': 1, 'wip': 2}
    status, worker, sheet, why = 'nosheet', '', '', ''
    for path, text in ([(own, sheets[own])] if own in sheets else sorted(sheets.items())):
        st, reason = pre.sheet_status(text)
        if not sheet or order[st] < order[status]:
            status, sheet, why = st, path, reason
            m = WORKER.search(text)
            worker = m.group(1) if m else ''
    return dict(info, branch=name, status=status, sheet=sheet, worker=worker, why=why, task=pre.guess_task(name, sheets))


def span(seconds):
    seconds = max(0, int(seconds))
    if seconds >= 2 * 86400:
        return '%d 天' % (seconds // 86400)
    if seconds >= 3600:
        return '%d 小时 %02d 分' % (seconds // 3600, seconds % 3600 // 60)
    return '%d 分' % (seconds // 60)


def shallow(root):
    return quiet(root, 'rev-parse', '--is-shallow-repository')[1] == 'true'


def board(root, main=None, now=None, recent_days=3, show_all=False, old_days=14):
    """算出整张看板：dict(main, mainRef, now, ready=[…按建议顺序], blocked=[…自检没过或冲突], pending=[…没交付], hidden=N,
    old=[交付超过 old_days 天还没合的分支名，默认不查], unrelated=[和 main 没有共同历史的分支名], shallow)。"""
    root = Path(root)
    now = now or time.time()
    main_ref, main_sha = pre.pick_main(root, main)
    lanes = [describe(root, main_sha, n, i) for n, i in sorted(candidates(root, main_sha).items())]
    delivered = [x for x in lanes if x['status'] in ('ready', 'draft')]
    pending = [x for x in lanes if x['status'] in ('wip', 'nosheet')]
    for x in lanes:
        x['waited'] = now - x['time']
    hidden = 0
    if not show_all:
        keep = [x for x in pending if x['waited'] <= recent_days * 86400]
        hidden, pending = len(pending) - len(keep), keep
    pending.sort(key=lambda x: x['time'], reverse=True)
    ready, blocked, old, unrelated = [], [], [], []
    if not show_all:
        # 交付很久没合的多半是弃用或改走别的分支了：只列名字，不逐条试合并（--all 照查）
        old = [x['branch'] for x in delivered if x['waited'] > old_days * 86400]
        delivered = [x for x in delivered if x['waited'] <= old_days * 86400]
    if delivered:
        with pre.Sandbox(root) as box:
            for x in delivered:
                r = pre.check(root, x['ref'], task=x['task'], main=(main_ref, main_sha), sandbox=box, local=False)
                if r['status'] == 'unrelated':
                    unrelated.append(x['branch'])
                    continue
                x.update(problems=r['problems'], hints=r['hints'], slow=r['slow'], slowWhy=r['slowWhy'], conflicts=r['conflicts'],
                         changed=r['changed'], gameplay=r['gameplay'], goneSheets=r['goneSheets'])
                (blocked if r['problems'] else ready).append(x)
            # 快车道先、慢车道后，各按交付时间先到先合；再按这个顺序往上叠着试合并，找车道之间的冲突
            ready.sort(key=lambda x: (x['slow'], x['time']))
            box.reset(main_sha)
            stacked = []
            for x in list(ready):
                conflicts, static = box.try_merge(x['sha'], x['goneSheets'], keep=True)
                if conflicts or static:
                    files = [c for c in conflicts if not c.startswith('（')]
                    rivals = [y['branch'] for y in stacked if set(y['changed']) & set(files)] or [y['branch'] for y in stacked]
                    if conflicts:
                        x['problems'].append('单独合 main 没冲突，但排在它前面的 %s 合进去之后有冲突（%s）：先合前面的，本车道 git merge main 解掉再交付'
                                             % ('、'.join(rivals), '、'.join(conflicts[:5])))
                    x['problems'] += ['叠在前面的车道之上：' + s for s in static]
                    x['conflicts'] = conflicts
                    ready.remove(x)
                    blocked.append(x)
                else:
                    stacked.append(x)
    blocked.sort(key=lambda x: x['time'], reverse=True)       # 刚交的排前面：最可能有人等着改
    return dict(main=main_sha, mainRef=main_ref, now=now, ready=ready, blocked=blocked, pending=pending, hidden=hidden,
                old=old, unrelated=unrelated, shallow=shallow(root))


def queue_spec(lanes):
    """--queue 的写法：一律「任务=分支」，cc/ 与 claude/ 同名分支都在时也不会认错。"""
    return ','.join('%s=%s' % (x['task'], x['branch']) for x in lanes)


def brief(worker, limit=24):
    """表格里的工作者一栏只留前一段（交付单这一行常带一长串说明）；--json 里是全文。"""
    return worker if len(worker) <= limit else worker[:limit - 1] + '…'


def render(b, stale_hours=4, out=sys.stdout):
    w = lambda s='': print(s, file=out)  # noqa: E731
    w('待合看板（%s %s，%s）：可合并 %d 条，退回车道 %d 条，没交付 %d 条'
      % (b['mainRef'], b['main'][:9], time.strftime('%m-%d %H:%M', time.localtime(b['now'])), len(b['ready']), len(b['blocked']), len(b['pending'])))
    if b['ready']:
        w()
        w('## 可合并（建议顺序）')
        w()
        w('| 序 | 分支 | 工作者 | 等了 | 分道 | 在哪 | 备注 |')
        w('| --- | --- | --- | --- | --- | --- | --- |')
        for i, x in enumerate(b['ready'], 1):
            note = []
            if x['waited'] > stale_hours * 3600:
                note.append('⚠ 等过 %d 小时' % stale_hours)
            if x['slow']:
                note.append('改了 ' + '、'.join(x['slowWhy'][:3] or ['切片／转换器／探针']))
            if not x['where'].startswith('本地'):
                note.append('只在远端：先 git fetch %s %s:%s' % (x['where'].split('＋')[0], x['branch'], x['branch']))
            if x['note']:
                note.append(x['note'])
            w('| %d | %s | %s | %s | %s | %s | %s |' % (i, x['branch'], brief(x['worker']) or '—', span(x['waited']), '慢' if x['slow'] else '快',
                                                    x['where'], '；'.join(note)))
        fast = [x for x in b['ready'] if not x['slow']]
        slow = [x for x in b['ready'] if x['slow']]
        w()
        tail = ' --affected --cloud --who <执行者…> --desc <内容…>'
        if fast:
            w('快车道先合先推：合并车道.py --queue %s%s' % (queue_spec(fast), tail))
        if slow:
            w('慢车道另起一批（队尾或夜里，合并要同步）：合并车道.py --queue %s%s' % (queue_spec(slow), tail))
    if b['blocked']:
        w()
        w('## 退回车道（交了但现在合不了）')
        for x in b['blocked']:
            w()
            w('- %s（%s，等了 %s，交付单 %s）' % (x['branch'], x['worker'] or '工作者未写', span(x['waited']), x['sheet'] or '无'))
            for p in x['problems']:
                w('  - ' + p.replace('\n', ' '))
    if b['pending']:
        w()
        w('## 没交付（有新提交，交付单没标可合并或没有交付单）')
        w()
        w('| 分支 | 最后提交 | 交付单 | 在哪 |')
        w('| --- | --- | --- | --- |')
        for x in b['pending']:
            w('| %s | %s 前 | %s | %s |' % (x['branch'], span(x['waited']), '进行中' if x['status'] == 'wip' else '无', x['where']))
    if b['hidden']:
        w()
        w('另有 %d 条更早的没交付分支没列（--all 全列）' % b['hidden'])
    if b['old']:
        w()
        w('交付超过 14 天还没合的 %d 条没查（多半已弃用；--all 照查）：%s%s' % (len(b['old']), '、'.join(b['old'][:8]), ' 等' if len(b['old']) > 8 else ''))
    if b['unrelated']:
        w()
        w('和 main 没有共同历史、没法试合并的 %d 条：%s%s' % (len(b['unrelated']), '、'.join(b['unrelated'][:8]), ' 等' if len(b['unrelated']) > 8 else ''))
    if b['shallow']:
        w()
        w('注意：本库是浅克隆（云端容器），早先合并过的分支会被当成没合并；要准的看板在 Mac 主仓库跑。')
    if not (b['ready'] or b['blocked'] or b['pending']):
        w('没有待合的车道。')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default='.', help='资料库里任一工作树（默认当前目录）')
    ap.add_argument('--main', help='拿哪个 main 比（默认本地 main、github/main、origin/main 里最新的）')
    ap.add_argument('--fetch', action='store_true', help='先 git fetch --prune 各远端（联网；云端线程的分支只在远端）')
    ap.add_argument('--all', action='store_true', help='没交付的旧分支也全列')
    ap.add_argument('--days', type=int, default=3, help='没交付的分支只列最近这么多天有提交的（默认 3）')
    ap.add_argument('--stale-hours', type=float, default=4, help='可合并车道等过这么多小时标 ⚠（默认 4）')
    ap.add_argument('--check', action='store_true', help='有可合并车道等过 --stale-hours 就退出 1')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    try:
        root = Path(git(a.root, 'rev-parse', '--show-toplevel'))
        if a.fetch:
            for r in pre.remotes(root):
                p = subprocess.run(['git', '-C', str(root), 'fetch', '--prune', '-q', r], capture_output=True, text=True, timeout=300)
                if p.returncode:
                    print('提示：git fetch %s 没成功（%s），按已有的远端分支算' % (r, (p.stderr.strip().splitlines() or ['?'])[-1]), file=sys.stderr)
        b = board(root, a.main, recent_days=a.days, show_all=a.all)
    except (RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        print('待合看板没跑成：%s' % e, file=sys.stderr)
        return 2
    if a.json:
        slim = lambda x: {k: v for k, v in x.items() if k not in ('changed', 'goneSheets')}  # noqa: E731
        print(json.dumps(dict(b, ready=[slim(x) for x in b['ready']], blocked=[slim(x) for x in b['blocked']], pending=b['pending']),
                         ensure_ascii=False, indent=2))
    else:
        render(b, a.stale_hours)
    if a.check and any(x['waited'] > a.stale_hours * 3600 for x in b['ready'] + b['blocked']):
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
