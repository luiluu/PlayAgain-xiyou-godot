#!/usr/bin/env python3
"""总装合并：默认准备合并；手改交接板/进度账后 --finish 检查、提交、清理。失败保留现场。

几条车道同时可合时（用户 2026-10-20 同意）：前几条 --finish --batch，照常登记、提交收尾，但不跑检查、
不清理工作树、不推送，记进本批清单；最后一条不加 --batch 的 --finish 跑一次 检查.sh --oracle，
通过后提交、清理本批全部工作树并推送。最后的检查失败时 main 上已有的本批收尾提交不推送、工作树都保留。"""
import argparse
import hashlib
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
COMMON = {str(p) for p in [BOARD, LOG, Path('00_项目管理/交接板归档.md'), Path('00_项目管理/重制步骤清单.md'),
          Path('00_项目管理/当前状态.json'), Path('00_项目管理/来源登记.json'),
          SUB / '开发编号.json', PROJECT / 'project.godot', PROJECT / 'content/build_info.json']}
VERSION_MARKER = 'dev.' + '待定'
VERSION_EXEMPT = {'AGENTS.md', '00_项目管理/交付/README.md'}
PLACEHOLDER = re.compile(r'^\s*(?:[-*]\s*)?[（(<]?待写[）)>]?[。.]?\s*$', re.M)


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


def porcelain(root):
    raw = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '-z']).decode()
    return raw.rstrip('\0').split('\0') if raw else []


def merge_head(root):
    head = Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'MERGE_HEAD'
    return head.read_text().strip() if head.exists() else None


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
    """取所有「…变更记录草稿」节。变更记录条目标题都带【执行者】；节止于下一个不带【的二级标题
    （如「## 交接板（由唐僧并入）」），不把交接板／进度账等节当成变更记录贴进去。"""
    if not re.search(r'^(?:[-*]\s*)?状态[：:]\s*\**可合并\**(?:\s|[（(。，；：—]|$)', text, re.M):
        raise RuntimeError('交付单尚未标为可合并')
    heads = list(re.finditer(r'^## (?!.*【).*$', text, re.M))
    parts = [text[h.end():heads[i + 1].start() if i + 1 < len(heads) else len(text)].strip()
             for i, h in enumerate(heads) if '变更记录草稿' in h[0]]
    # 只认整行占位（「待写」「（待写）」「- 待写」），正文里提到这两个字不算未完成。
    if not parts or not all(parts) or any(PLACEHOLDER.search(p) for p in parts):
        raise RuntimeError('交付单缺少完整变更记录草稿')
    return '\n\n'.join(parts)


def relink(body, root):
    """草稿里按交付目录口径写的相对链接，改成变更记录（00_项目管理/）口径；两处都不存在的原样保留，由检查.sh 报失效。"""
    log_dir, sheet_dir = (root / LOG).parent, root / '00_项目管理/交付'

    def fix(m):
        ref = m.group(2)
        path, _, anchor = ref.partition('#')
        if not path or '://' in path or path.startswith(('/', '~')) or (log_dir / path).exists():
            return m.group(0)
        target = (sheet_dir / path).resolve()
        if not target.exists():
            return m.group(0)
        return m.group(1) + os.path.relpath(target, log_dir.resolve()) + ('#' + anchor if anchor else '') + ')'
    return re.sub(r'(\]\()([^)\s<>]+)\)', fix, body)


def sheets(state):
    return [state['delivery'], *state.get('extraDeliveries', [])]


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
    # 同一分支带来的其它交付单（如接手者另写的一张）：标了可合并的一并归并删除；没标的提示唐僧处理。
    extra = []
    for p in sorted(changed):
        if (p.startswith('00_项目管理/交付/') and p.endswith('.md') and p not in (str(delivery), '00_项目管理/交付/README.md')
                and (wt / p).is_file()):
            try:
                draft((wt / p).read_text())
                extra.append(p)
            except RuntimeError:
                print('提示：另有交付单 ' + p + ' 未标可合并或草稿不完整，未并入；不要它就在 main 删掉，--finish 时加 --also ' + p,
                      file=sys.stderr, flush=True)
    refresh = any(p in [str(TOOLS / 'xiyou_slice.json'), str(TOOLS / 'xiyou_export.py')]
                  or (p.startswith(str(TOOLS / 'mv_oracle') + '/') and p.endswith('.cjs')) for p in changed)
    game = any(p.startswith(str(PROJECT) + '/') and not p.startswith(str(PROJECT / 'tests') + '/')
               and p != str(PROJECT / 'content/build_info.json') for p in changed)
    # 只替换目标车道带来的编号占位，不扫描、暂存主工作区的其它文件。
    version_paths = [p for p in changed if p != str(delivery) and p not in extra and p not in VERSION_EXEMPT
                     and Path(p).suffix in {'.md', '.json', '.gd', '.py', '.sh'}
                     and (wt / p).is_file() and not (wt / p).is_symlink()
                     and VERSION_MARKER in (wt / p).read_text()]
    return dict(task=task, branch=lane['branch'], worktree=str(wt), base=base, target=target,
                delivery=str(delivery), extraDeliveries=extra, refresh=refresh, gameplay=game, phase='planned', head=base,
                versionPaths=version_paths,
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


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace_versions(root, state, state_file):
    if 'versionEdits' not in state:
        edits = {}
        for rel in state.get('versionPaths', []):
            path = root / rel
            if path.is_symlink() or not path.is_file():
                raise RuntimeError('编号占位文件已改变类型：' + rel)
            before = path.read_bytes()
            after = before.decode().replace(VERSION_MARKER, state['version']).encode()
            if before != after:
                edits[rel] = {'before': digest(before), 'after': digest(after)}
        # 先保存计划再写文件；中断时只接受原内容或已经替换完的内容。
        state['versionEdits'] = edits
        save(state_file, state)
    for rel, hashes in state['versionEdits'].items():
        path = root / rel
        if path.is_symlink() or not path.is_file():
            raise RuntimeError('编号占位文件已改变类型：' + rel)
        current = path.read_bytes()
        if digest(current) == hashes['after']:
            continue
        if digest(current) != hashes['before']:
            raise RuntimeError('编号替换过程中出现额外改动，保留现场：' + rel)
        after = current.decode().replace(VERSION_MARKER, state['version']).encode()
        if digest(after) != hashes['after']:
            raise RuntimeError('编号替换结果与计划不一致：' + rel)
        path.write_bytes(after)


def validate_version_edits(root, state):
    for rel, hashes in state.get('versionEdits', {}).items():
        if rel in COMMON:
            continue  # 共用登记允许唐僧在暂停点继续编辑。
        path = root / rel
        if path.is_symlink() or not path.is_file() or digest(path.read_bytes()) != hashes['after']:
            raise RuntimeError('编号替换文件还有其它改动，保留现场：' + rel)


def prepare(root, state, state_file, executor):
    if state['phase'] != 'planned' and git(root, 'rev-parse', 'HEAD') != state['head']:
        raise RuntimeError('准备过程中 main HEAD 已改变，先人工核对')
    if state['phase'] == 'planned':
        actor = 'Claude（唐僧）' if executor == 'Claude' else 'Codex（沙僧）'
        reviewer = 'Codex' if executor == 'Claude' else 'Claude'
        message = ['-m', '合并 ' + state['branch'], '-m', '执行者: ' + actor + '\n核查: 待' + reviewer]
        if merge_head(root) == state['target']:
            # 上次合并停在冲突：唐僧解决并 git add 后重跑本工具，由它照规范提交合并，再往下接续。
            unmerged = git(root, 'diff', '--name-only', '--diff-filter=U')
            if unmerged:
                raise RuntimeError('冲突尚未解决：' + '、'.join(unmerged.splitlines()))
            if git(root, 'diff', '--name-only') or any(x.startswith('?') for x in porcelain(root)):
                raise RuntimeError('冲突已解决但还有未暂存或未跟踪的改动，先 git add 或移走')
            run(root, ['git', 'commit', *message])
        if dirty(root):
            raise RuntimeError('尚有冲突或未提交现场，须先人工处理；未自动回退')
        if git(root, 'rev-parse', 'HEAD') == state['base']:
            try:
                run(root, ['git', 'merge', '--no-ff', state['target'], *message])
            except subprocess.CalledProcessError:
                raise RuntimeError('合并有冲突，现场保留：解决后 git add，再运行同一命令接续（工具会提交合并）；'
                                   '放弃就 git merge --abort，让车道 git merge main 后重新交付，再运行即按新提交重排')
        elif subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode:
            raise RuntimeError('main 已改变且尚未包含目标车道；请人工核对状态文件')
        state.update(phase='merged', head=git(root, 'rev-parse', 'HEAD'))
        save(state_file, state)
    if state['phase'] == 'merged':
        if state['refresh']:
            # 提速提案 P3：车道已在同一套转换工具上同步过时直接用其产物（按指纹核对）；退出码 3＝条件不满足，改跑完整同步。
            # 同步脚本结束时自己跑 godot --import。
            sync = [sys.executable, TOOLS / '同步正式西游.py', '--accept-additions']
            cmd = list(map(str, sync + ['--from-worktree', state['worktree']]))
            print('== ' + ' '.join(cmd), flush=True)
            rc = subprocess.run(cmd, cwd=root).returncode
            if rc == 3:
                run(root, sync)
            elif rc:
                raise RuntimeError('同步未通过（退出码 %d），保留现场' % rc)
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
        replace_versions(root, state, state_file)
        marker = '<!-- lane-merge:' + state['target'] + ' -->'
        log = (root / LOG).read_text()
        if marker not in log:
            if any(not (root / s).exists() for s in sheets(state)):
                raise RuntimeError('交付单已不存在且变更记录无本批标记，先人工核对')
            body = '\n\n'.join(relink(draft((root / s).read_text()), root) for s in sheets(state))
            body = body.replace(VERSION_MARKER, state['version'])
            (root / LOG).write_text(log.rstrip() + '\n\n' + body + '\n\n' + marker + '\n')
        for s in sheets(state):
            (root / s).unlink(missing_ok=True)
        # 归并记录并删除交付单后若进程中断，凭本批标记安全接续，不重复追加或编号。
        state['phase'] = 'prepared'
        save(state_file, state)
    print('已准备合并。请唐僧手改交接板（移除活动车道、加入待核查）与进度账，保持改动未提交；然后运行 --finish。', flush=True)


def load_batch(folder):
    path = folder / 'batch.json'
    return json.loads(path.read_text()) if path.exists() else []


def finish(root, state, state_file, executor, batch=False):
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
        allowed = COMMON | set(sheets(state)) | set(state.get('versionEdits', {})) | set(state.get('also', []))
        if changed - allowed:
            raise RuntimeError('不自动暂存预期外文件：' + '、'.join(sorted(changed - allowed)))
        validate_version_edits(root, state)
        run(root, [sys.executable, ENV / '进度账.py', '--check'])
        # 检查.sh 按 git ls-files 枚举交付单；仅删除工作区文件仍会被它列出。
        # 先核对全部改动范围，再只暂存本批交付单的删除，不提前暂存其它内容。
        for s in sheets(state):
            if (root / s).exists():
                raise RuntimeError('交付单重新出现，先人工核对：' + s)
            if git(root, 'ls-files', '--', s):
                run(root, ['git', 'add', '--', s])
        if batch:
            print('本批延后检查：等最后一条不加 --batch 的 --finish 统一跑 检查.sh --oracle', flush=True)
        else:
            run(root, [ENV / '检查.sh', '--oracle'])
        # 检查可能生成 .uid 等文件，仍须重新核对，不能顺带提交。
        changed = dirty(root)
        if changed - allowed:
            raise RuntimeError('检查后出现预期外改动，先人工处理：' + '、'.join(sorted(changed - allowed)))
        validate_version_edits(root, state)
        if any((root / s).exists() for s in sheets(state)):
            raise RuntimeError('检查后交付单重新出现，先人工核对')
        run(root, ['git', 'diff', '--check'])
        # 已暂存删除的路径已不在索引里，重复 git add 会报 pathspec 不存在。
        remaining = changed - set(sheets(state))
        if remaining:
            run(root, ['git', 'add', '--', *sorted(remaining)])
        actor = 'Claude（唐僧）' if executor == 'Claude' else 'Codex（沙僧）'
        reviewer = 'Codex' if executor == 'Claude' else 'Claude'
        run(root, ['git', 'commit', '-m', '合并 ' + state['branch'] + '（' + state['version'] + '）收尾',
                   '-m', '执行者: ' + actor + '\n核查: 待' + reviewer])
        state.update(phase='committed', head=git(root, 'rev-parse', 'HEAD'), batch=batch)
        save(state_file, state)
    folder = state_file.parent
    pending = load_batch(folder)
    if state.get('batch'):
        # 只登记，工作树与推送等本批最后一条通过检查后再做；中断后重跑同一命令不会重复登记。
        if all(x['task'] != state['task'] for x in pending):
            pending.append({k: state[k] for k in ['task', 'branch', 'worktree', 'target', 'head']})
            save(folder / 'batch.json', pending)
        state_file.unlink()
        print('已收尾并记入本批（共 %d 条，未检查、未推送）；接着合下一条，最后一条不加 --batch 运行 --finish。' % len(pending), flush=True)
        return
    for lane in pending:
        wt = Path(lane['worktree'])
        if wt.exists():
            if git(wt, 'rev-parse', 'HEAD') != lane['target'] or dirty(wt):
                raise RuntimeError('本批车道交付后又发生改动，不清理其工作树：' + lane['worktree'])
            run(root, [ENV / '清理工作树.sh', lane['worktree']])
    run(root, [ENV / '清理工作树.sh', state['worktree']])
    (folder / 'batch.json').unlink(missing_ok=True)
    state_file.unlink()
    print('合并、检查、提交与工作树清理全部完成%s。' % ('（本批共 %d 条）' % (len(pending) + 1) if pending else ''), flush=True)
    push_github(root)


def push_github(root, remote='github'):
    """用户 2026-10-18：每次合并后把 main 推到 GitHub。失败只警告，下次合并补推；GitHub 有本地没有的提交时不推。"""
    def remote_git(*args):
        env = dict(os.environ, GIT_TERMINAL_PROMPT='0')
        p = subprocess.run(['git', '-C', str(root), *args], capture_output=True, text=True, env=env, timeout=120)
        if p.returncode:
            raise RuntimeError(p.stderr.strip() or p.stdout.strip())
        return p.stdout.strip()
    try:
        if remote not in git(root, 'remote').split():
            print('无 ' + remote + ' 远端，跳过推送。', flush=True)
            return
        if remote_git('ls-remote', '--heads', remote, 'main'):
            remote_git('fetch', '--no-tags', remote, '+refs/heads/main:refs/remotes/' + remote + '/main')
            ahead = git(root, 'log', '--oneline', 'main..refs/remotes/' + remote + '/main')
            if ahead:
                print('警告：GitHub main 有本地 main 没有的提交，未推送（不强推，请人工核对）：\n' + ahead, flush=True)
                return
        remote_git('push', remote, 'refs/heads/main:refs/heads/main')
        print('已推送 main 到 ' + remote + '。', flush=True)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print('警告：推送 ' + remote + ' 失败，合并不受影响，下次合并会补推：' + ' '.join(str(error).split()), flush=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('task')
    ap.add_argument('--root', type=Path, help='主工作区；默认从当前工具所属资料库定位')
    modes = ap.add_mutually_exclusive_group()
    modes.add_argument('--dry-run', action='store_true')
    modes.add_argument('--finish', action='store_true')
    ap.add_argument('--executor', choices=['Claude', 'Codex'], default='Claude')
    ap.add_argument('--batch', action='store_true',
                    help='--finish 时本条先不跑检查、不清理、不推送，记入本批；最后一条不加它统一检查')
    ap.add_argument('--also', action='append', default=[], metavar='路径',
                    help='--finish 时一并提交的额外改动（如要删的另一张交付单、顺带改的规则），可重复')
    a = ap.parse_args(argv)
    root = a.root or Path(git(Path(__file__).parent, 'rev-parse', '--path-format=absolute', '--git-common-dir')).parent
    root = root.resolve()
    lock = None
    try:
        if git(root, 'branch', '--show-current') != 'main':
            raise RuntimeError('只能操作 main 主工作区')
        folder = Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'lane-merge'
        state_file = folder / 'state.json'
        if a.batch and not a.finish:
            raise RuntimeError('--batch 只和 --finish 一起用')
        if a.dry_run:
            print(json.dumps(plan(root, a.task), ensure_ascii=False, indent=2)); return 0
        folder.mkdir(exist_ok=True)
        lock = folder / 'running.lock'
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
        state = json.loads(state_file.read_text()) if state_file.exists() else None
        if state and state['task'] != a.task:
            raise RuntimeError('另一条车道尚未收尾：' + state['task'])
        if (state and state['phase'] == 'planned' and merge_head(root) is None
                and subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode):
            # 还没合进来（放弃了冲突合并、车道重新交付，或 main 又前进）：按车道与 main 的现状重新计划。
            executor = state.get('executor', a.executor)
            state = plan(root, a.task)
            state['executor'] = executor
            save(state_file, state)
        if state is None:
            if a.finish:
                raise RuntimeError('没有准备中的合并')
            state = plan(root, a.task)
            state['executor'] = a.executor
            save(state_file, state)
        elif state.get('executor', a.executor) != a.executor:
            raise RuntimeError('接续执行者不同，请先核对原执行者登记')
        if a.finish:
            if a.also:
                state['also'] = sorted(set(state.get('also', [])) | set(a.also))
                save(state_file, state)
            finish(root, state, state_file, a.executor, a.batch)
        else:
            pending = load_batch(folder)
            if pending and not any(x['task'] == a.task for x in pending):
                print('提示：本批已有 %d 条收尾未检查（%s）；这条可 --finish --batch 继续攒，或直接 --finish 统一检查。'
                      % (len(pending), '、'.join(x['task'] for x in pending)), flush=True)
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
