#!/usr/bin/env python3
"""总装合并：默认准备合并；手改交接板/进度账后 --finish 检查、提交、清理。失败保留现场。"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

SUB = Path('03_再刷重制_Godot')
ENV = SUB / '07_开发环境'
TOOLS = SUB / '03_转换工具'
PROJECT = SUB / '01_Godot工程'
BOARD = Path('00_项目管理/交接板.md')
LOG = Path('00_项目管理/变更记录.md')
COMMON = {str(p) for p in [BOARD, LOG, Path('00_项目管理/重制步骤清单.md'),
          Path('00_项目管理/当前状态.json'), Path('00_项目管理/来源登记.json'),
          SUB / '开发编号.json', PROJECT / 'project.godot', PROJECT / 'content/build_info.json']}
VERSION_MARKER = 'dev.' + '待定'


def git(root, *args):
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', *args], capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip())
    return p.stdout.strip()


def run(root, args):
    print('== ' + ' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=root, check=True)


def dirty(root):
    raw = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '-z']).decode()
    records = raw.rstrip('\0').split('\0') if raw else []
    if any(len(x) < 3 or 'R' in x[:2] or 'C' in x[:2] for x in records):
        raise RuntimeError('工作区含改名/复制记录，先人工处理')
    return {x[3:] for x in records}


def worktrees(root):
    raw = subprocess.check_output(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z']).decode()
    records, current = [], {}
    for token in raw.split('\0'):
        if token.startswith('worktree '):
            if current:
                records.append(current)
            current = {'path': token[9:]}
        elif token.startswith('branch '):
            current['branch'] = token[7:].removeprefix('refs/heads/')
    if current:
        records.append(current)
    return records


def draft(text):
    match = re.search(r'^## 变更记录草稿\s*\n(.*?)(?=^## 交接板\s*$|\Z)', text, re.M | re.S)
    if not re.search(r'^- 状态：可合并(?:\s|[（(]|$)', text, re.M):
        raise RuntimeError('交付单尚未标为可合并')
    if not match or not match[1].strip() or '待写' in match[1]:
        raise RuntimeError('交付单缺少完整变更记录草稿')
    return match[1].strip()


def plan(root, task):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', task):
        raise RuntimeError('任务名只允许字母、数字、点、下划线和短横线')
    if git(root, 'branch', '--show-current') != 'main' or dirty(root):
        raise RuntimeError('main 必须干净，包含未跟踪文件；本工具不自动保存或覆盖现场')
    lanes = [w for w in worktrees(root) if w.get('branch') in ['claude/' + task, 'codex/' + task]]
    if len(lanes) != 1:
        raise RuntimeError('须有且只有一个对应任务的已登记车道工作树')
    lane = lanes[0]
    wt = Path(lane['path'])
    if dirty(wt):
        raise RuntimeError('车道工作树不干净，先由车道提交')
    base, target = git(root, 'rev-parse', 'HEAD'), git(wt, 'rev-parse', 'HEAD')
    if base == target or not git(root, 'rev-list', base + '..' + target):
        raise RuntimeError('车道没有待合并提交')
    fork = git(root, 'merge-base', base, target)
    delivery = Path('00_项目管理/交付') / (lane['branch'].replace('/', '_') + '.md')
    text = (wt / delivery).read_text()
    draft(text)
    changed = git(root, 'diff', '--name-only', fork, target).splitlines()
    refresh = any(p in [str(TOOLS / 'xiyou_slice.json'), str(TOOLS / 'xiyou_export.py')]
                  or (p.startswith(str(TOOLS / 'mv_oracle') + '/') and p.endswith('.cjs')) for p in changed)
    game = any(p.startswith(str(PROJECT) + '/') and not p.startswith(str(PROJECT / 'tests') + '/')
               and p != str(PROJECT / 'content/build_info.json') for p in changed)
    return dict(task=task, branch=lane['branch'], worktree=str(wt), base=base, target=target,
                delivery=str(delivery), refresh=refresh, gameplay=game, phase='planned', head=base,
                mainAdvancedAfterDelivery=fork != base)


def save(path, state):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(path)


def update_version(root):
    version = json.loads((root / SUB / '开发编号.json').read_text())['current']
    for rel, indent in [('00_项目管理/当前状态.json', 2), ('00_项目管理/来源登记.json', 1)]:
        p = root / rel
        data = json.loads(p.read_text())
        if rel.endswith('当前状态.json'):
            data['godot']['developmentVersion'] = version
        else:
            next(s for s in data['sources'] if s['id'] == 'new_godot_remake')['developmentVersion'] = version
        p.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + '\n')
    return version


def prepare(root, state, state_file, executor):
    if state['phase'] != 'planned' and git(root, 'rev-parse', 'HEAD') != state['head']:
        raise RuntimeError('准备过程中 main HEAD 已改变，先人工核对')
    if state['phase'] == 'planned':
        if dirty(root):
            raise RuntimeError('尚有冲突或未提交现场，须先人工处理；未自动回退')
        if git(root, 'rev-parse', 'HEAD') == state['base']:
            actor = 'Claude（唐僧）' if executor == 'Claude' else 'Codex（沙僧）'
            reviewer = 'Codex' if executor == 'Claude' else 'Claude'
            run(root, ['git', 'merge', '--no-ff', state['target'], '-m', '合并 ' + state['branch'],
                       '-m', '执行者: ' + actor + '\n核查: 待' + reviewer])
        elif subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode:
            raise RuntimeError('main 已改变且尚未包含目标车道；请人工核对状态文件')
        state.update(phase='merged', head=git(root, 'rev-parse', 'HEAD'))
        save(state_file, state)
    if state['phase'] == 'merged':
        if state['refresh']:
            run(root, [sys.executable, TOOLS / '同步正式西游.py', '--accept-additions'])
            run(root, [ENV / 'godot', '--headless', '--path', PROJECT, '--import'])
        state['phase'] = 'synced'
        save(state_file, state)
    if state['phase'] == 'synced':
        if state['gameplay']:
            registry = json.loads((root / SUB / '开发编号.json').read_text())
            state['beforeVersion'] = registry['current']
            state['plannedVersion'] = registry['next']
            state['phase'] = 'numbering'
            save(state_file, state)
        else:
            state['version'] = json.loads((root / SUB / '开发编号.json').read_text())['current']
            state['phase'] = 'versioned'
            save(state_file, state)
    if state['phase'] == 'numbering':
        current = json.loads((root / SUB / '开发编号.json').read_text())['current']
        if current == state['beforeVersion']:
            run(root, [sys.executable, ENV / '开发编号.py', 'bump', state['task']])
        elif current != state['plannedVersion']:
            raise RuntimeError('开发编号发生预期外变化，未再次递增')
        state['version'] = update_version(root)
        state['phase'] = 'versioned'
        save(state_file, state)
    if state['phase'] == 'versioned':
        receipt = root / state['delivery']
        marker = '<!-- lane-merge:' + state['target'] + ' -->'
        log = (root / LOG).read_text()
        if receipt.exists():
            body = draft(receipt.read_text()).replace(VERSION_MARKER, state['version'])
            if marker not in log:
                (root / LOG).write_text(log.rstrip() + '\n\n' + body + '\n\n' + marker + '\n')
            receipt.unlink()
        elif marker not in log:
            raise RuntimeError('交付单已不存在且变更记录无本批标记，先人工核对')
        # 归并记录并删除交付单后若进程中断，凭本批标记安全接续，不重复追加或编号。
        state['phase'] = 'prepared'
        save(state_file, state)
    print('已准备合并。请唐僧手改交接板（移除活动车道、加入待核查）与进度账，保持改动未提交；然后运行 --finish。', flush=True)


def finish(root, state, state_file, executor):
    if state['phase'] not in ['prepared', 'committed']:
        raise RuntimeError('先运行准备合并，再手工登记，最后 --finish')
    if git(root, 'rev-parse', 'HEAD') != state['head']:
        raise RuntimeError('准备后 main HEAD 已改变；保留现场，先人工核对')
    if git(Path(state['worktree']), 'rev-parse', 'HEAD') != state['target'] or dirty(Path(state['worktree'])):
        raise RuntimeError('车道交付后又发生改动，不清理其工作树')
    if state['phase'] == 'prepared':
        board = (root / BOARD).read_text()
        active = board.split('## 正在进行', 1)[1].split('\n## ', 1)[0]
        pending = board.split('## 待交叉核查', 1)[1].split('\n## ', 1)[0]
        if state['branch'] in active or state['worktree'] in active:
            raise RuntimeError('交接板仍将该车道列为正在进行，请唐僧更新')
        if state['branch'] not in pending and state['target'][:7] not in pending and state['head'][:7] not in pending:
            raise RuntimeError('待交叉核查尚未登记本车道分支或提交号')
        changed = dirty(root)
        allowed = COMMON | {state['delivery']}
        if changed - allowed:
            raise RuntimeError('不自动暂存预期外文件：' + '、'.join(sorted(changed - allowed)))
        run(root, [sys.executable, ENV / '进度账.py', '--check'])
        run(root, [ENV / '检查.sh', '--oracle'])
        # 检查可能生成 .uid 等文件，仍须重新核对，不能顺带提交。
        changed = dirty(root)
        if changed - allowed:
            raise RuntimeError('检查后出现预期外改动，先人工处理：' + '、'.join(sorted(changed - allowed)))
        run(root, ['git', 'diff', '--check'])
        run(root, ['git', 'add', '--', *sorted(changed)])
        actor = 'Claude（唐僧）' if executor == 'Claude' else 'Codex（沙僧）'
        reviewer = 'Codex' if executor == 'Claude' else 'Claude'
        run(root, ['git', 'commit', '-m', '合并 ' + state['branch'] + '（' + state['version'] + '）收尾',
                   '-m', '执行者: ' + actor + '\n核查: 待' + reviewer])
        state.update(phase='committed', head=git(root, 'rev-parse', 'HEAD'))
        save(state_file, state)
    run(root, [ENV / '清理工作树.sh', state['worktree']])
    state_file.unlink()
    print('合并、检查、提交与工作树清理全部完成。', flush=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('task')
    ap.add_argument('--root', type=Path, help='主工作区；默认从当前工具所属资料库定位')
    modes = ap.add_mutually_exclusive_group()
    modes.add_argument('--dry-run', action='store_true')
    modes.add_argument('--finish', action='store_true')
    ap.add_argument('--executor', choices=['Claude', 'Codex'], default='Claude')
    a = ap.parse_args(argv)
    root = a.root or Path(git(Path(__file__).parent, 'rev-parse', '--path-format=absolute', '--git-common-dir')).parent
    root = root.resolve()
    lock = None
    try:
        if git(root, 'branch', '--show-current') != 'main':
            raise RuntimeError('只能操作 main 主工作区')
        folder = Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'lane-merge'
        state_file = folder / 'state.json'
        if a.dry_run:
            print(json.dumps(plan(root, a.task), ensure_ascii=False, indent=2)); return 0
        folder.mkdir(exist_ok=True)
        lock = folder / 'running.lock'
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
        state = json.loads(state_file.read_text()) if state_file.exists() else None
        if state and state['task'] != a.task:
            raise RuntimeError('另一条车道尚未收尾：' + state['task'])
        if state is None:
            if a.finish:
                raise RuntimeError('没有准备中的合并')
            state = plan(root, a.task)
            state['executor'] = a.executor
            save(state_file, state)
        elif state.get('executor', a.executor) != a.executor:
            raise RuntimeError('接续执行者不同，请先核对原执行者登记')
        if a.finish:
            finish(root, state, state_file, a.executor)
        else:
            prepare(root, state, state_file, a.executor)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, KeyError, IndexError) as error:
        print('合并已停止，现场保留：' + str(error), file=sys.stderr)
        return 1
    finally:
        if lock is not None and 'fd' in locals():
            lock.unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main())
