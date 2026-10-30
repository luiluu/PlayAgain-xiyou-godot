#!/usr/bin/env python3
"""总装合并：默认准备合并；手改交接板/进度账后 --finish 检查、提交、清理。失败保留现场。

几条车道同时可合时（用户 2026-10-20 同意）：前几条 --finish --batch，照常登记、提交收尾，但不跑检查、
不清理工作树、不推送，记进本批清单；最后一条不加 --batch 的 --finish 跑一次 检查.sh --oracle，
通过后提交、清理本批全部工作树并推送。最后的检查失败时 main 上已有的本批收尾提交不推送、工作树都保留，
并列出本批每条车道的合并提交与改动文件，便于对照失败项定位；要撤出某条就 --abort-batch：先把当前 main
（含未提交的登记改动）存成 refs/lane-merge/aborted-* 备份，再退回本批开始前的 main，各车道工作树不动，
之后把没问题的车道重新合（可再攒一批），出问题的那条在自己的工作树修好再交付。

白天合并可用 --finish --affected 只跑选测（三级检查②，基准为本次（或本批第一条）合并前的 main），通过后照常提交、清理、推送；
收尾提交带「验证: 选测」尾注，当天全量前算选测已验；全量仍是不加 --affected 的 --finish。

车道交付后在同一工作树接着做（换新分支、新提交或未提交改动）不拦合并：只跳过该工作树的清理，交付分支不再是当前分支就照删。
清理前还要过两道（哪吒 2026-10-27，曾误清另一账号会话的干净工作树）：有进程的当前目录在该工作树里（活动会话）或工作树被
git worktree lock 锁住，或合并前 main 的交接板「正在进行」表里没有提到该工作树／交付分支的行、或那行写了「不要删」，都只提示不删。
车道工作树只有未跟踪文件且都在 00_项目管理/核查范围/ 或 04_验证/本地结果/ 下（沙僧的原版证据、本地输出）时也收：
按分支引用合并，不清理该工作树。"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

SUB = Path('03_再刷重制_Godot')
ENV = SUB / '07_开发环境'
TOOLS = SUB / '03_转换工具'
PROJECT = SUB / '01_Godot工程'
ACCEPT = SUB / '04_验证/测量接受'
BOARD = Path('00_项目管理/交接板.md')
LOG = Path('00_项目管理/变更记录.md')
COMMON = {str(p) for p in [BOARD, LOG, Path('00_项目管理/交接板归档.md'), Path('00_项目管理/重制步骤清单.md'),
          Path('00_项目管理/当前状态.json'), Path('00_项目管理/来源登记.json'),
          SUB / '开发编号.json', PROJECT / 'project.godot', PROJECT / 'content/build_info.json']}
VERSION_MARKER = 'dev.' + '待定'
# 优化登记号占位：车道文档里写 O-待定（同一份里要区分几项就写 O-待定-1、O-待定-2），合并时按已登记的最大 O-NNN 顺延换号
# （总装手换漏过一处注释，唐僧 10-30）。占位字面量拆开写，免得本文件自己被换号。
OPT_TOKEN = re.compile('O-' + '待定' + r'(?:-\d+)?')
OPT_NUMBERED = re.compile(r'O-(\d{3})(?!\d)')
OPT_REGISTERS = ['00_项目管理/交接板.md', '00_项目管理/交接板归档.md', '00_项目管理/变更记录.md']
VERSION_EXEMPT = {'AGENTS.md', '00_项目管理/交付/README.md'}
# 车道工作树里只有这些目录下的未跟踪文件时仍可合并（按分支引用，不清理工作树）
EVIDENCE_DIRS = ('00_项目管理/核查范围/', str(SUB / '04_验证/本地结果') + '/')
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
    # -uall：未跟踪目录逐个列文件，免得新目录里的一个允许文件（如新写的接受单）被当成整个目录拦下
    raw = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '-z', '-uall']).decode()
    records = raw.rstrip('\0').split('\0') if raw else []
    if any(len(x) < 3 or 'R' in x[:2] or 'C' in x[:2] for x in records):
        raise RuntimeError('工作区含改名/复制记录，先人工处理')
    return {x[3:] for x in records}


def porcelain(root):
    raw = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '-z']).decode()
    return raw.rstrip('\0').split('\0') if raw else []


def untracked_evidence(root):
    """工作树只有未跟踪文件、且都在 EVIDENCE_DIRS 下时返回这些路径；否则返回空列表（干净或有别的改动）。"""
    raw = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '-z', '-uall']).decode()
    records = raw.rstrip('\0').split('\0') if raw else []
    if records and all(x.startswith('?? ') and x[3:].startswith(EVIDENCE_DIRS) for x in records):
        return sorted(x[3:] for x in records)
    return []


def active_cwds(path):
    """当前目录在 path 里的进程（lsof 列各进程 cwd），返回 [(pid, 命令)]；本进程除外。
    lsof 不可用、超时、或失败且没有输出（正常机器上总有进程有 cwd）时返回 None＝无法确认，调用方要保守按「可能有活动会话」处理
    （沙僧第十六期 P2：原来这些情形返回空，清理会放行）。"""
    try:
        r = subprocess.run(['lsof', '-a', '-d', 'cwd', '-F', 'pcn'], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    out = r.stdout
    if r.returncode != 0 and not out.strip():
        return None
    base, found, pid, cmd = os.path.realpath(path), [], None, ''
    for line in out.splitlines():
        if line.startswith('p'):
            pid, cmd = line[1:], ''
        elif line.startswith('c'):
            cmd = line[1:]
        elif line.startswith('n') and pid and pid != str(os.getpid()):
            cwd = os.path.realpath(line[1:])
            if cwd == base or cwd.startswith(base + os.sep):
                found.append((pid, cmd))
    return found


def lane_protected(root, lane):
    """清理车道工作树前的保护：返回不删的原因，没有就返回空串。"""
    wt = Path(lane['worktree'])
    procs = active_cwds(wt)
    if procs is None:
        return '无法确认有无活动会话（lsof 不可用、超时或失败），保守不删'
    if procs:
        return '有活动会话（进程 %s 的当前目录在其中）' % '、'.join('%s %s' % p for p in procs[:3])
    meta = Path(git(wt, 'rev-parse', '--path-format=absolute', '--git-dir'))
    if (meta / 'locked').exists():
        return '被 git worktree lock 锁住'
    try:
        board = git(root, 'show', lane['base'] + ':' + str(BOARD))
    except RuntimeError:
        return '读不到合并前 main 的交接板'
    active = board.split('## 正在进行', 1)[1].split('\n## ', 1)[0] if '## 正在进行' in board else ''
    named = re.compile(r'(?<![\w-])(?:%s|%s)(?![\w-])' % (re.escape(wt.name), re.escape(lane['branch'])))
    rows = [l for l in active.splitlines() if l.startswith('|') and named.search(l)]
    # 交接板没提到它不再算保留理由（Kyo 2026-10-30「worktree 合并以后要随手删掉」，磁盘只剩 36G）：交付已并入 main、
    # 工作树干净、没有活动会话、没被锁，就删；车道会话复用时 新建工作树.sh <任务名> 原路径重建。只有写了「不要删」的才留
    if any('不要删' in l for l in rows):
        return '交接板写明清理时不要删'
    return ''


CONFLICT_MARK = re.compile(r'^\+(?:<{7}|>{7}|\|{7})(?: |$)', re.M)


def conflict_markers(root, *spec):
    """spec（如 --cached 或 base..HEAD）里新增行带冲突标记（<<<<<<<、>>>>>>>、|||||||）的文件。不认单独的 =======，
    Markdown 的标题下划线也是它。10-28 唐僧：解冲突后 git add 接续，带标记的文件被直接提交进合并。"""
    found, current = [], None
    for line in git(root, 'diff', '--no-color', '--no-ext-diff', '-U0', *spec).splitlines():
        if line.startswith('+++ '):
            current = line[6:] if line.startswith('+++ b/') else None
        elif current and current not in found and CONFLICT_MARK.match(line):
            found.append(current)
    return found


FUNC_DEF = re.compile(r'^(\s*)(?:static\s+)?func\s+(\w+)')
CLASS_DEF = re.compile(r'^(\s*)class\s+(\w+)')


def duplicate_funcs(text):
    """GDScript 里同一作用域（脚本顶层或同一内部类）重复定义的 func 名：[(名, 行号…)]。
    10-28：wukong-challenge4 与 main 各加了一个 is_super_strong，git 自动合并不报冲突，工程整个 Parse Error。"""
    seen, stack = {}, []  # stack：[(缩进, 内部类名)]
    for no, line in enumerate(text.splitlines(), 1):
        body = line.strip()
        if not body or body.startswith('#'):
            continue
        indent = len(line) - len(line.lstrip())
        while stack and indent <= stack[-1][0]:
            stack.pop()
        m = CLASS_DEF.match(line)
        if m:
            stack.append((indent, m.group(2)))
            continue
        m = FUNC_DEF.match(line)
        if m:
            seen.setdefault((tuple(c for _, c in stack), m.group(2)), []).append(no)
    return [('.'.join(scope + (name,)), lines) for (scope, name), lines in seen.items() if len(lines) > 1]


PARSE_CHECK_GD = """extends SceneTree
func _init() -> void:
	for p in OS.get_environment("XIYOU_PARSE_CHECK_FILES").split("\\n", false):
		load(p)
	print("PARSE_CHECK_DONE")
	quit(0)
"""
PARSE_TIMEOUT = 180


def parse_errors(log, autoloads):
    """godot 日志里算数的脚本错误 [(错误, 文件)]。连带的「Failed to compile depended scripts」不算（根因另有一行）；
    --script 方式不加载 autoload，「Identifier not found: <autoload 名>」也不算。"""
    lines, found = log.splitlines(), []
    for i, line in enumerate(lines):
        if 'SCRIPT ERROR:' not in line or 'Failed to compile depended scripts' in line:
            continue
        if any(line.rstrip().endswith('Identifier not found: ' + a) for a in autoloads):
            continue
        at = re.search(r'\((res://[^:)]+)', lines[i + 1]) if i + 1 < len(lines) else None
        found.append((line.split('SCRIPT ERROR:', 1)[1].strip(), at.group(1) if at else '?'))
    return found


def parse_check(root, base):
    """合并后、同步与检查前的快速解析检查（1 分钟内）：①本次合并改动的 .gd 有没有同名 func；②godot --import 刷新类缓存后
    用外置脚本逐个 load 工程里全部 .gd，日志里有算数的 SCRIPT ERROR 就列出。没有 godot 或工程时只做①。返回问题列表。"""
    problems = []
    for rel in git(root, 'diff', '--name-only', '--diff-filter=AM', base, 'HEAD', '--', '*.gd').splitlines():
        f = root / rel
        if f.is_file():
            for name, lines in duplicate_funcs(f.read_text(errors='replace')):
                problems.append('%s：func %s 重复定义（第 %s 行）' % (rel, name, '、'.join(map(str, lines))))
    godot, project = root / ENV / 'godot', root / PROJECT
    if not (os.access(godot, os.X_OK) and (project / 'project.godot').is_file()):
        print('提示：没有 godot 或工程，解析检查只扫了同名 func', flush=True)
        return problems
    text = (project / 'project.godot').read_text(errors='replace')
    section = text.split('[autoload]', 1)[1].split('\n[', 1)[0] if '[autoload]' in text else ''
    autoloads = re.findall(r'^(\w+)=', section, re.M)
    files = sorted('res://' + p.relative_to(project).as_posix() for p in project.rglob('*.gd')
                   if '.godot' not in p.relative_to(project).parts)
    with tempfile.TemporaryDirectory(prefix='xiyou_parse_check_') as tmp:
        script = Path(tmp) / 'parse_check.gd'
        script.write_text(PARSE_CHECK_GD)
        env = dict(os.environ, XIYOU_PARSE_CHECK_FILES='\n'.join(files), HOME=tmp)
        t0 = time.monotonic()
        try:
            for args in (['--import'], ['--script', str(script)]):
                p = subprocess.run([str(godot), '--headless', '--path', str(project), *args], capture_output=True, text=True,
                                   env=env, timeout=max(10, PARSE_TIMEOUT - (time.monotonic() - t0)))
                log = p.stdout + p.stderr
                if args[0] == '--script' and 'PARSE_CHECK_DONE' not in log:
                    problems.append('解析检查脚本没跑完（退出码 %d）：%s' % (p.returncode, ' '.join(log.split()[-30:])))
                elif p.returncode != 0:
                    problems.append('godot %s 退出码 %d：%s' % (args[0], p.returncode, ' '.join(log.split()[-30:])))
                if args[0] == '--import':
                    # 导入报错（健康工程的导入日志没有 ERROR: 行；新建工作树.sh 同口径）：导入或缓存没准备好，后面的加载检查不可信
                    bad = [l.strip() for l in log.splitlines() if l.startswith('ERROR:')]
                    if bad:
                        problems.append('godot --import 报错 %d 条：%s' % (len(bad), '；'.join(bad[:3])))
                problems += ['%s：%s' % (f, e) for e, f in parse_errors(log, autoloads)]
        except subprocess.TimeoutExpired:
            problems.append('解析检查超过 %d 秒没结束（机器太忙可重跑；确认无误可加 --no-parse-check 跳过本次）' % PARSE_TIMEOUT)
    problems = list(dict.fromkeys(problems))
    print('== 解析检查：%d 个 .gd，%d 个问题（%d 秒）' % (len(files), len(problems), time.monotonic() - t0), flush=True)
    # 连带错误（依赖的类解析失败、因此推不出类型）排后面，根因（如重复定义）排前面
    knock_on = ('because of a parser error', 'Cannot infer the type', 'Failed to load script')
    return sorted(problems, key=lambda p: any(k in p for k in knock_on))


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
    """取所有「…变更记录草稿」节（沙僧写作「待总装并入变更记录的核查条目」也认）。变更记录条目标题都带【执行者】；节止于下一个不带【的二级标题
    （如「## 交接板（由唐僧并入）」），不把交接板／进度账等节当成变更记录贴进去。"""
    # 状态可在行首，也可跟在同一列表项「…；」之后（沙僧写作「- 核查／沙僧（Codex）；状态：可合并」，唐僧 10-29）。
    if not re.search(r'^(?:[-*]\s*)?(?:[^\n；;]*[；;]\s*)?状态[：:]\s*\**可合并\**(?:\s|[（(。，；：—]|$)', text, re.M):
        raise RuntimeError('交付单尚未标为可合并')
    heads = list(re.finditer(r'^## (?!.*【).*$', text, re.M))
    parts = [text[h.end():heads[i + 1].start() if i + 1 < len(heads) else len(text)].strip()
             for i, h in enumerate(heads) if '变更记录草稿' in h[0] or '并入变更记录' in h[0]]
    if not parts:
        return problem_entry(text, heads)
    # 只认整行占位（「待写」「（待写）」「- 待写」），正文里提到这两个字不算未完成。
    if not all(parts) or any(PLACEHOLDER.search(p) for p in parts):
        raise RuntimeError('交付单的变更记录草稿节为空或仍是「待写」，补完「## 变更记录草稿」节')
    return '\n\n'.join(parts)


def problem_entry(text, heads):
    """沙僧只交问题清单的期次没有草稿节：用标题带「问题」的节生成一条最简变更记录（哪吒_8，10-29 两次因此手补草稿）。
    条目正文就是该节原文，总装 --finish 前可在变更记录里改写；连「问题」节也没有才拒合，并说清要补哪一节。"""
    parts = [text[h.end():heads[i + 1].start() if i + 1 < len(heads) else len(text)].strip()
             for i, h in enumerate(heads) if '问题' in h[0]]
    parts = [p for p in parts if p and not PLACEHOLDER.search(p)]
    if not parts:
        raise RuntimeError('交付单缺少「## 变更记录草稿」节（沙僧写作「## 待总装并入变更记录的核查条目」也认）；'
                           '只交问题的期次至少要有标题带「问题」的节（如「## 本期问题交总装」），据此生成最简条目')
    name = re.search(r'^# 交付[：:]\s*(\S+)', text, re.M)
    branch = name.group(1) if name else '（未写分支）'
    who = 'Codex·沙僧' if branch.startswith('codex/') else 'Claude·未经Codex检验'
    print('提示：交付单 %s 没有变更记录草稿，按「问题」节生成最简条目；--finish 前可在变更记录里改写' % branch,
          file=sys.stderr, flush=True)
    return '## %s 【%s】%s（仅交问题，不销账）\n\n%s' % (time.strftime('%Y-%m-%d'), who, branch, '\n\n'.join(parts))


def relink(body, root):
    """草稿里的相对链接按交付目录口径解释（与交付单 README、检查.sh 一致），改成变更记录（00_项目管理/）口径。
    歧义规则（沙僧_19 P3）：交付目录口径的目标存在就以它为准，即使变更记录目录下也有同名的另一个文件（此时提示一行）；
    只有交付目录口径不存在、变更记录口径存在时原样保留（旧写法）；两处都不存在的原样保留，由检查.sh 报失效。"""
    log_dir, sheet_dir = (root / LOG).parent, root / '00_项目管理/交付'

    def fix(m):
        ref = m.group(2)
        path, _, anchor = ref.partition('#')
        if not path or '://' in path or path.startswith(('/', '~')):
            return m.group(0)
        target = (sheet_dir / path).resolve()
        if not target.exists():
            return m.group(0)
        other = (log_dir / path).resolve()
        if other.exists() and other != target:
            print('提示：链接 %s 在交付目录与变更记录目录各指一个文件，按交付目录口径改写' % ref, file=sys.stderr, flush=True)
        return m.group(1) + os.path.relpath(target, log_dir.resolve()) + ('#' + anchor if anchor else '') + ')'
    return re.sub(r'(\]\()([^)\s<>]+)\)', fix, body)


def sheets(state):
    return [state['delivery'], *state.get('extraDeliveries', [])]


def plan(root, task):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', task):
        raise RuntimeError('任务名只允许字母、数字、点、下划线和短横线')
    if git(root, 'branch', '--show-current') != 'main':
        raise RuntimeError('只能在 main 上合并')
    changed = dirty(root)
    if changed:
        untracked = sorted(x[3:] for x in porcelain(root) if x.startswith('??'))
        hint = ('；其中未跟踪的（%s）若是本机临时文件（如通知、草稿），可把路径写进本地 .git/info/exclude（不入 Git），'
                '不必删' % '、'.join(untracked[:5])) if untracked else ''
        raise RuntimeError('main 必须干净，包含未跟踪文件；本工具不自动保存或覆盖现场：' + '、'.join(sorted(changed)[:8]) + hint)
    lanes = [w for w in worktrees(root) if w.get('branch') in ['claude/' + task, 'codex/' + task]]
    if len(lanes) > 1:
        raise RuntimeError('须有且只有一个对应任务的已登记车道工作树')
    evidence = []
    if lanes:
        branch, wt = lanes[0]['branch'], Path(lanes[0]['path'])
        evidence = untracked_evidence(wt)
        if evidence:
            # 沙僧工作树常驻未入 Git 的原版证据：按分支引用合并（只读提交里的文件），收尾不清理这个工作树
            print('提示：车道工作树只有 %d 个未跟踪证据／本地输出（%s 等），按分支引用合并，不清理该工作树'
                  % (len(evidence), evidence[0]), file=sys.stderr, flush=True)
            lanes = []
        elif dirty(wt):
            raise RuntimeError('车道工作树不干净，先由车道提交')
    if lanes:
        target = git(wt, 'rev-parse', 'HEAD')

        def read(rel):
            f = wt / rel
            return f.read_text() if f.is_file() and not f.is_symlink() else None
    else:
        # 车道交付后已在同一工作树换新分支接着做：没有工作树停在交付分支上，按分支引用合并，文件从交付提交里读
        refs = [b for b in ['claude/' + task, 'codex/' + task]
                if subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '-q', 'refs/heads/' + b],
                                  capture_output=True).returncode == 0]
        if len(refs) != 1:
            raise RuntimeError('须有且只有一个对应任务的车道工作树或车道分支')
        branch, wt = refs[0], None
        target = git(root, 'rev-parse', 'refs/heads/' + branch)
        if not evidence:
            print('提示：没有工作树停在 %s 上（车道已换分支继续），按分支引用 %s 合并' % (branch, target[:9]), file=sys.stderr, flush=True)

        def read(rel):
            entry = git(root, 'ls-tree', target, '--', str(rel))
            return git(root, 'show', target + ':' + str(rel)) + '\n' if entry.split(' ')[:2] in (['100644', 'blob'], ['100755', 'blob']) else None
    base = git(root, 'rev-parse', 'HEAD')
    if base == target or not git(root, 'rev-list', base + '..' + target):
        raise RuntimeError('车道没有待合并提交')
    fork = git(root, 'merge-base', base, target)
    delivery = Path('00_项目管理/交付') / (branch.replace('/', '_') + '.md')
    text = read(delivery)
    if text is None:
        raise RuntimeError('车道分支缺少交付单：' + str(delivery))
    draft(text)
    # 只认相对本次合并前 main 真有改动的文件：交叉合并时 merge-base 可能取到旧基点，基点 diff 会把 main 早就有的
    # 文件（如别期的测量接受单）当成本期带来，gameplay 误判为真、文档期白递增开发编号（哪吒_8，10-29 八戒 attack-query2）
    real = set(git(root, 'diff', '--name-only', base, target).splitlines())
    changed = [p for p in git(root, 'diff', '--name-only', fork, target).splitlines() if p in real]

    def main_deleted(p):
        # main 已删、车道上仍是删前原样的文件（10-30 八戒 alien-equip：已归并删除的 claude_wukong-airship1.md 被记进
        # versionPaths，报「编号占位文件已改变类型」）：合并时 main 的删除生效，不算车道带来的改动
        if (root / p).exists():
            return False
        removed = git(root, 'log', '--diff-filter=D', '--format=%H', '-1', base, '--', p)
        if not removed:
            return False
        before = subprocess.run(['git', '-C', str(root), 'rev-parse', '-q', '--verify', removed + '^:' + p],
                                capture_output=True, text=True).stdout.strip()
        return bool(before) and git(root, 'rev-parse', target + ':' + p) == before
    changed = [p for p in changed if not main_deleted(p)]
    # 同一分支带来的其它交付单（如接手者另写的一张）：标了可合并的一并归并删除；没标的提示唐僧处理。
    # 已随前几批并入、在 main 删掉的旧交付单不算：车道从上一期交付点切出又合过 main 时与 main 有两个合并基点（交叉合并），
    # merge-base 可能取到旧的那个，diff 会带出期一等交付单，到归并时报「交付单已不存在」停下（哪吒_7 t4，八戒 attack-query2）
    extra = []
    for p in sorted(changed):
        if (p.startswith('00_项目管理/交付/') and p.endswith('.md') and p not in (str(delivery), '00_项目管理/交付/README.md')
                and read(p) is not None):
            removed = git(root, 'log', '--diff-filter=D', '--format=%H', '-1', base, '--', p)
            if removed and not (root / p).exists():
                before = subprocess.run(['git', '-C', str(root), 'rev-parse', '-q', '--verify', removed + '^:' + p],
                                        capture_output=True, text=True).stdout.strip()
                if git(root, 'rev-parse', target + ':' + p) != before:
                    print('提示：%s 已在 main 删除（%s 归并过），车道上的版本与删前不同；不再并入，车道补写的内容请写进本期交付单'
                          % (p, removed[:9]), file=sys.stderr, flush=True)
                continue
            try:
                draft(read(p))
                extra.append(p)
            except RuntimeError:
                print('提示：另有交付单 ' + p + ' 未标可合并或草稿不完整，未并入；不要它就在 main 删掉，--finish 时加 --also ' + p,
                      file=sys.stderr, flush=True)
    refresh = any(p in [str(TOOLS / 'xiyou_slice.json'), str(TOOLS / 'xiyou_export.py')]
                  or (p.startswith(str(TOOLS / 'mv_oracle') + '/') and p.endswith('.cjs')) for p in changed)
    # 车道带来的测量接受单（同步正式西游.py --accept-changes）：main 的同步对自己的旧基线同样逐条核对
    accept = [p for p in sorted(changed) if p.startswith(str(ACCEPT) + '/') and p.endswith('.json') and read(p) is not None]
    refresh = refresh or bool(accept)
    game = any(p.startswith(str(PROJECT) + '/') and not p.startswith(str(PROJECT / 'tests') + '/')
               and p != str(PROJECT / 'content/build_info.json') for p in changed)
    # 只替换目标车道带来的编号占位，不扫描、暂存主工作区的其它文件。
    version_paths = [p for p in changed if p != str(delivery) and p not in extra and p not in VERSION_EXEMPT
                     and Path(p).suffix in {'.md', '.json', '.gd', '.py', '.sh'}
                     and (VERSION_MARKER in (read(p) or '') or OPT_TOKEN.search(read(p) or ''))]
    return dict(task=task, branch=branch, worktree=str(wt) if wt else '', base=base, target=target,
                delivery=str(delivery), extraDeliveries=extra, refresh=refresh, acceptChanges=accept, gameplay=game, phase='planned', head=base,
                versionPaths=version_paths, evidenceFiles=evidence,
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


def assign_opt_numbers(root, state):
    """本条合并带来的 O-待定[-n] 各换成顺延的 O-NNN：起点＝登记文件（交接板、归档、变更记录及其分卷）与本条文件里已有的最大号 +1，
    同一个占位全合并里换成同一个号，按第一次出现的顺序编号。无占位时返回空表。"""
    texts, tokens = [], []
    for rel in list(state.get('versionPaths', [])) + sheets(state):
        f = root / rel
        if f.is_file() and not f.is_symlink():
            texts.append(f.read_text(errors='replace'))
    for t in texts:
        for m in OPT_TOKEN.finditer(t):
            if m.group(0) not in tokens:
                tokens.append(m.group(0))
    if not tokens:
        return {}
    regs = [root / r for r in OPT_REGISTERS] + sorted((root / '00_项目管理').glob('变更记录*.md'))
    top = 0
    for f in regs:
        if f.is_file():
            top = max([top] + [int(n) for n in OPT_NUMBERED.findall(f.read_text(errors='replace'))])
    for t in texts:
        top = max([top] + [int(n) for n in OPT_NUMBERED.findall(t)])
    return {tok: 'O-%03d' % (top + i + 1) for i, tok in enumerate(tokens)}


def substitute(text, state):
    text = text.replace(VERSION_MARKER, state['version'])
    for tok, num in sorted(state.get('optNumbers', {}).items(), key=lambda kv: -len(kv[0])):
        text = text.replace(tok, num)
    return text


def replace_versions(root, state, state_file):
    if 'versionEdits' not in state:
        state['optNumbers'] = assign_opt_numbers(root, state)
        edits = {}
        for rel in state.get('versionPaths', []):
            path = root / rel
            if path.is_symlink() or not path.is_file():
                raise RuntimeError('编号占位文件已改变类型：' + rel)
            before = path.read_bytes()
            after = substitute(before.decode(), state).encode()
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
        after = substitute(current.decode(), state).encode()
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


def review_status(root, state):
    """合并提交的核查尾注（Kyo 2026-10-30：Codex 停用核查，改审查线程）：审查线程自己的分支不再被核，写「无」；其余写「待审查」。"""
    if state['branch'].startswith('claude/review-'):
        return '无'
    try:
        sheet = git(root, 'show', state['target'] + ':' + state['delivery'])
    except RuntimeError:
        sheet = ''
    if re.search(r'执行者[:：]\s*Claude[（(]审查[）)]', sheet):
        return '无'
    return '待审查'


def prepare(root, state, state_file, executor):
    if state['phase'] != 'planned' and git(root, 'rev-parse', 'HEAD') != state['head']:
        raise RuntimeError('准备过程中 main HEAD 已改变，先人工核对')
    if state['phase'] == 'planned':
        actor = 'Claude（唐僧）' if executor == 'Claude' else 'Codex（沙僧）'
        message = ['-m', '合并 ' + state['branch'], '-m', '执行者: ' + actor + '\n核查: ' + review_status(root, state)]
        if merge_head(root) == state['target']:
            # 上次合并停在冲突：唐僧解决并 git add 后重跑本工具，由它照规范提交合并，再往下接续。
            unmerged = git(root, 'diff', '--name-only', '--diff-filter=U')
            if unmerged:
                raise RuntimeError('冲突尚未解决：' + '、'.join(unmerged.splitlines()))
            if git(root, 'diff', '--name-only') or any(x.startswith('?') for x in porcelain(root)):
                raise RuntimeError('冲突已解决但还有未暂存或未跟踪的改动，先 git add 或移走')
            marked = conflict_markers(root, '--cached')
            if marked:
                raise RuntimeError('已暂存的文件里还有冲突标记（<<<<<<< / >>>>>>>），未提交合并：' + '、'.join(marked)
                                   + '；删掉标记后重新 git add，再运行同一命令')
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
        else:
            # 唐僧解冲突后自己 git commit 了合并：同样不放行带标记的合并提交
            marked = conflict_markers(root, state['base'] + '..HEAD')
            if marked:
                raise RuntimeError('合并提交里有冲突标记：' + '、'.join(marked) + '；先修好（git commit --amend）再运行同一命令')
        if not state.get('noParseCheck'):
            problems = parse_check(root, state['base'])
            if problems:
                shown = problems[:12] + (['……另 %d 条（多是连带错误）' % (len(problems) - 12)] if len(problems) > 12 else [])
                raise RuntimeError('合并后解析检查不通过（还没同步、没跑检查）：\n  ' + '\n  '.join(shown)
                                   + '\n在 main 改好后 git commit --amend（或另提交），再运行同一命令接续；放弃就 合并车道.sh %s --abort'
                                   % state['task'])
        head = git(root, 'rev-parse', 'HEAD')
        state.update(phase='merged', head=head, mergeCommit=head)
        save(state_file, state)
    if state['phase'] == 'merged':
        if state['refresh']:
            if 'syncSince' not in state:
                # --abort 凭它找本次合并第一轮同步前的产物备份（同步脚本备份目录名同样以时间戳开头）
                state['syncSince'] = time.strftime('%Y%m%d_%H%M%S')
                # 固定本条合并同步前的产物：同步脚本的滚动备份只留三份，同一合并多轮同步会把首轮前的备份轮换掉（沙僧第七期 T1）
                state['preSync'] = pin_generated(root, state_file.parent / 'pre-sync' / state['task'])
                save(state_file, state)
            # 提速提案 P3：车道已在同一套转换工具上同步过时直接用其产物（按指纹核对）；退出码 3＝条件不满足，改跑完整同步。
            # 同步脚本结束时自己跑 godot --import。
            sync = [sys.executable, TOOLS / '同步正式西游.py', '--accept-additions']
            for spec in state.get('acceptChanges', []):
                sync += ['--accept-changes', spec]
            cmd = list(map(str, sync + ['--from-worktree', state['worktree']]))
            if state['worktree']:
                print('== ' + ' '.join(cmd), flush=True)
            rc = subprocess.run(cmd, cwd=root).returncode if state['worktree'] else 3  # 无车道工作树：直接完整同步
            if rc == 3:
                print('== ' + ' '.join(map(str, sync)), flush=True)
                rc = subprocess.run(list(map(str, sync)), cwd=root).returncode
            if rc:
                if rc == 2:
                    sheet = ACCEPT / (state['branch'].replace('/', '_') + '.json')
                    print('同步拒收（测量有改变）。核对报告里的变化无误后：\n'
                          '  python3 %s --out %s --reason-from %s\n'
                          '  （或 --reason "理由"；打开生成的接受单逐条核对、补理由）\n'
                          '  然后 合并车道.sh %s --accept-changes %s 接着同步' % (
                              TOOLS / '生成接受单.py', sheet, state['delivery'], state['task'], sheet), file=sys.stderr, flush=True)
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
            body = substitute(body, state)
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


def report_batch(root, pending, state):
    """本批最后的检查失败时：列出每条车道的合并提交和带进来的文件，对照检查输出里失败的场景／文件定位是哪条。"""
    if not pending:
        return
    print('\n== 本批最后的检查未通过。各条车道带进来的改动（对照上面失败的场景或文件）：', flush=True)
    for lane in pending + [state]:
        mc = lane.get('mergeCommit')
        files = git(root, 'diff', '--name-only', mc + '^1', mc).splitlines() if mc else []
        print('- %s（%s）合并提交 %s，%d 个文件：%s%s' % (
            lane['task'], lane['branch'], (mc or '未知')[:9], len(files), '、'.join(files[:12]), '……' if len(files) > 12 else ''), flush=True)
    print('定位：在嫌疑车道自己的工作树单独跑失败的场景（并行测试.py <godot> <工程> <场景名>），能复现就是它；'
          '都不复现说明是几条合在一起才出的问题。\n'
          '撤出：确定要撤哪条后运行 合并车道.py --abort-batch，退回本批开始前的 main（当前状态先存备份），'
          '再把没问题的车道重新合；只是检查本身的问题（偶发、环境）修好后重跑同一条 --finish 即可。', flush=True)


def abort_batch(root, folder):
    """退回本批开始前的 main：先存备份引用，不删任何车道工作树；已推送到 GitHub 的批不能退。"""
    pending = load_batch(folder)
    state_file = folder / 'state.json'
    state = json.loads(state_file.read_text()) if state_file.exists() else None
    if not pending:
        raise RuntimeError('没有攒着的本批合并（batch.json），不需要撤')
    base = pending[0].get('base')
    if not base or subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', base, 'HEAD']).returncode:
        raise RuntimeError('本批起点不在当前 main 历史里，先人工核对')
    if merge_head(root):
        raise RuntimeError('有进行中的合并冲突，先 git merge --abort 或解决')
    if any(x.startswith('??') for x in porcelain(root)):
        raise RuntimeError('有未跟踪文件，先移走或提交，免得退回时丢失')
    tracking = 'refs/remotes/github/main'
    first = pending[0].get('mergeCommit') or pending[0]['head']
    if (subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '-q', tracking], capture_output=True).returncode == 0
            and subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', first, tracking]).returncode == 0):
        raise RuntimeError('本批已推送到 GitHub，不能退回；改用新提交修复')
    stamp = time.strftime('%Y%m%d_%H%M%S')
    backup = 'refs/lane-merge/aborted-' + stamp
    git(root, 'update-ref', backup, 'HEAD')
    wip = git(root, 'stash', 'create')  # 只生成提交对象，不动共用的 stash 栈
    if wip:
        git(root, 'update-ref', backup + '-wip', wip)
    git(root, 'reset', '--hard', base)
    (folder / 'batch.json').unlink()
    state_file.unlink(missing_ok=True)
    lanes = pending + ([state] if state and all(x['task'] != state['task'] for x in pending) else [])
    print('已退回本批开始前的 main（%s）。备份：%s%s。' % (base[:9], backup, '（未提交改动在 ' + backup + '-wip）' if wip else ''), flush=True)
    for lane in lanes:
        print('- %s：工作树保留在 %s' % (lane['task'], lane['worktree']), flush=True)
    print('接着把没问题的车道重新合（可再 --finish --batch 攒一批）；撤出的那条在自己的工作树修好、git merge main 后再交付。', flush=True)


GENERATED = PROJECT / 'modes/xiyou/generated'
SYNC_BACKUPS = SUB / '04_验证/本地结果/自动同步'
SYNC_BASELINES = SUB / '04_验证/本地结果/同步基线'
SYNC_BACKED_UP = ['oracle', 'db', 'maps', 'manifest.json', 'slice.json']  # 同步脚本开头备份的产物（同步正式西游.py）


def clone_tree(src, dst):
    """APFS 克隆（cp -c，同卷不另占空间）；克隆不成退回普通复制。"""
    if sys.platform == 'darwin' and subprocess.run(['cp', '-cRp', str(src), str(dst)], capture_output=True).returncode == 0:
        return
    if dst.exists():
        shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
    (shutil.copytree if src.is_dir() else shutil.copy2)(src, dst)


def pin_generated(root, dest):
    """首轮同步前把产物（SYNC_BACKED_UP 各项）固定到 dest，并记下哪些项原本不存在；失败返回 None（撤回时就拒绝声称还原）。"""
    gen = root / GENERATED
    try:
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir(parents=True)
        present = [n for n in SYNC_BACKED_UP if (gen / n).exists()]
        for n in present:
            clone_tree(gen / n, dest / n)
        return {'dir': str(dest), 'present': present, 'absent': [n for n in SYNC_BACKED_UP if n not in present]}
    except OSError as error:
        print('提示：没能固定同步前的产物（%s）；之后撤回同步时无法保证还原' % error, flush=True)
        return None


def drop_pin(state):
    pin = state.get('preSync')
    if pin and pin.get('dir'):
        shutil.rmtree(pin['dir'], ignore_errors=True)


def undo_sync(root, state):
    """撤掉本次合并的同步：产物从第一轮同步开头的备份还原，删产物指纹与本产物目录的同步基线
    （基线目录名＝产物目录绝对路径的 sha256，见同步正式西游.py comparison_baseline），下一次同步按还原后的产物重建基线。"""
    if 'syncSince' not in state:
        return '本次合并还没同步过，产物不用退'
    gen = root / GENERATED
    if 'preSync' in state:
        pin = state['preSync']
        if not pin or not Path(pin['dir']).is_dir() or any(not (Path(pin['dir']) / n).exists() for n in pin['present']):
            return '没有本条合并同步前固定的产物（或已损坏），无法确定原状态，产物与同步基线保留现场、没有还原；请人工核对 generated/'
        for name in SYNC_BACKED_UP:
            dst = gen / name
            if dst.is_dir() and not dst.is_symlink():
                shutil.rmtree(dst)
            elif dst.exists() or dst.is_symlink():
                dst.unlink()
            if name in pin['present']:
                clone_tree(Path(pin['dir']) / name, dst)
        (gen / 'sync_stamp.json').unlink(missing_ok=True)
        notes = ['产物（%s）按本条合并同步前固定的快照还原；原本没有的（%s）已删' % ('、'.join(pin['present']), '、'.join(pin['absent']) or '无')]
        key = hashlib.sha256(str(gen.resolve()).encode()).hexdigest()
        for p in (root / SYNC_BASELINES).glob(key + '*'):
            shutil.rmtree(p) if p.is_dir() else p.unlink()
            notes.append('删同步基线 ' + p.name[:12] + '…')
        return '；'.join(notes)
    backups = sorted(p for p in (root / SYNC_BACKUPS).glob('*') if p.is_dir() and p.name[:15] >= state['syncSince'])
    notes = []
    if backups and (backups[0] / 'manifest.json').is_file():
        for name in SYNC_BACKED_UP:
            src, dst = backups[0] / name, gen / name
            if not src.exists():
                continue
            if dst.is_dir() and not dst.is_symlink():
                shutil.rmtree(dst)
            elif dst.exists() or dst.is_symlink():
                dst.unlink()
            (shutil.copytree if src.is_dir() else shutil.copy2)(src, dst)
        (gen / 'sync_stamp.json').unlink(missing_ok=True)
        notes.append('产物（%s）按同步前备份 %s 还原' % ('、'.join(SYNC_BACKED_UP), backups[0].name))
    else:
        notes.append('没找到本次同步开头的产物备份（同步没走到备份就停了），产物未动')
    key = hashlib.sha256(str(gen.resolve()).encode()).hexdigest()
    for p in (root / SYNC_BASELINES).glob(key + '*'):
        shutil.rmtree(p) if p.is_dir() else p.unlink()
        notes.append('删同步基线 ' + p.name[:12] + '…')
    return '；'.join(notes)


def process_start(pid):
    """进程启动时间（ps lstart，C 区域格式）；进程不在时 None。只读身份，不读命令行。"""
    out = subprocess.run(['ps', '-o', 'lstart=', '-p', str(pid)], capture_output=True, text=True,
                         env=dict(os.environ, LC_ALL='C')).stdout.strip()
    return out or None


def boot_time():
    """本次开机时刻（epoch 秒）；读不到时 None。"""
    out = subprocess.run(['sysctl', '-n', 'kern.boottime'], capture_output=True, text=True).stdout
    m = re.search(r'sec = (\d+)', out)
    return int(m.group(1)) if m else None


def mentions(text, name):
    """text 里提到 name 本身（后面不紧跟分支名字符）；车道接着做的 claude/x-1 不算提到 claude/x（唐僧 10-29）。"""
    return re.search(re.escape(name) + r'(?![\w./-])', text) is not None


def take_lock(folder):
    """running.lock：写入持锁进程的 pid 与启动时间。已有锁时：持有者还在（pid 在且启动时间对得上）照旧拒绝；
    已不在、或 pid 被别的进程复用（启动时间对不上）就作废重拿并提示；旧版留下的空锁或认不出的内容，
    早于本次开机的作废（重启打断 --finish 的现场，哪吒_7 t4），否则认不出持有者，照旧拒绝。
    判定与替换在 lock.guard 的 flock 里做，两个进程不会同时作废同一把锁。"""
    folder.mkdir(exist_ok=True)
    lock = folder / 'running.lock'
    me = json.dumps({'pid': os.getpid(), 'startedAt': process_start(os.getpid())})
    with open(folder / 'lock.guard', 'a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX)
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            try:
                text, mtime = lock.read_text(), lock.stat().st_mtime
            except FileNotFoundError:
                text, mtime = None, 0
            stale = None
            try:
                owner = json.loads(text) if text else None
            except ValueError:
                owner = None
            if text is None:
                stale = '锁已被别人删掉'
            elif isinstance(owner, dict) and type(owner.get('pid')) is int:
                started = process_start(owner['pid'])
                if started is None:
                    stale = '持锁进程 pid %d 已不在' % owner['pid']
                elif started != owner.get('startedAt'):
                    stale = 'pid %d 已被别的进程复用（启动时间 %s，锁里记的是 %s）' % (owner['pid'], started, owner.get('startedAt'))
                else:
                    raise RuntimeError('另一个合并正在运行（pid %d，%s 启动），等它结束再来' % (owner['pid'], started))
            else:
                booted = boot_time()
                if booted is None or mtime >= booted:
                    raise RuntimeError('%s 已存在但认不出持有者（旧版空锁，且在本次开机之后留下）：确认没有合并进程'
                                       '（pgrep -fl 合并车道）后删掉它再来' % lock)
                stale = '旧版空锁早于本次开机（%s）' % time.strftime('%m-%d %H:%M', time.localtime(mtime))
            print('提示：上次合并留下的 running.lock 作废（%s），重新拿锁；state.json 等现场照旧接续' % stale, flush=True)
            lock.unlink(missing_ok=True)
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(fd, 'w') as f:
            f.write(me)
    return lock


def abort_one(root, folder, task):
    """单条合并要撤出 main：退回本条合并前的 main（先存备份引用），撤掉本次同步写出的产物与同步基线，删 state.json。
    本批已攒着的前几条（batch.json）不动；已推送到 GitHub 的不能退。"""
    state_file = folder / 'state.json'
    if not state_file.exists():
        raise RuntimeError('没有准备中的合并（state.json），不需要撤')
    state = json.loads(state_file.read_text())
    if state['task'] != task:
        raise RuntimeError('准备中的是另一条车道：' + state['task'])
    base = state['base']
    if subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', base, 'HEAD']).returncode:
        raise RuntimeError('本条合并前的 main（%s）不在当前 main 历史里，先人工核对' % base[:9])
    if any(x.startswith('??') for x in porcelain(root)):
        raise RuntimeError('有未跟踪文件，先移走或提交，免得退回时丢失')
    tracking = 'refs/remotes/github/main'
    mc = state.get('mergeCommit')
    if (mc and subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '-q', tracking], capture_output=True).returncode == 0
            and subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', mc, tracking]).returncode == 0):
        raise RuntimeError('本条已推送到 GitHub，不能退回；改用新提交修复')
    stamp = time.strftime('%Y%m%d_%H%M%S')
    backup = 'refs/lane-merge/aborted-' + stamp
    git(root, 'update-ref', backup, 'HEAD')
    wip = None
    if merge_head(root):
        run(root, ['git', 'merge', '--abort'])  # 冲突现场没有可留的提交；stash create 遇未合并路径会失败
    else:
        wip = git(root, 'stash', 'create')  # 只生成提交对象，不动共用的 stash 栈
        if wip:
            git(root, 'update-ref', backup + '-wip', wip)
    git(root, 'reset', '--hard', base)
    note = undo_sync(root, state)
    drop_pin(state)
    state_file.unlink()
    print('已退回本条合并前的 main（%s）。备份：%s%s。%s。' % (
        base[:9], backup, '（未提交改动在 ' + backup + '-wip）' if wip else '', note), flush=True)
    if state.get('worktree'):
        print('- %s：工作树保留在 %s；修好、git merge main 后再交付' % (state['task'], state['worktree']), flush=True)
    if load_batch(folder):
        print('本批已攒着的 %d 条不动（batch.json 保留）' % len(load_batch(folder)), flush=True)


def doc_edits(changed):
    """总装收尾前在 main 手修的文档：只限 00_项目管理/ 下的 .md（交付单除外，别的交付单用 --also）。"""
    return {p for p in changed if p.startswith('00_项目管理/') and p.endswith('.md') and not p.startswith('00_项目管理/交付/')}


def amended_merge(root, state, head):
    """准备阶段停着的合并提交被 --amend 修过：还在 prepared 阶段、原 HEAD 就是合并提交，新 HEAD 父提交与它完全相同。"""
    if state['phase'] != 'prepared' or state.get('mergeCommit') != state['head']:
        return False
    parents = lambda c: git(root, 'rev-list', '--parents', '-n', '1', c).split()[1:]
    try:
        return len(parents(head)) == 2 and parents(head) == parents(state['head'])
    except RuntimeError:
        return False


def lane_uids(root, state):
    """交付分支新增的 .gd 对应、分支和 main 都没跟踪的 .gd.uid：Godot 导入时生成，车道常漏交（10-29 飞艇甲一要手加 --also），
    收尾时自动带入。只认分支新加的脚本，别的 .uid 仍按预期外文件拦下。"""
    added = git(root, 'diff', '--name-only', '--diff-filter=A', state['base'], state['target'], '--', '*.gd').splitlines()
    return {p + '.uid' for p in added if not git(root, 'ls-files', '--', p + '.uid')}


def finish(root, state, state_file, executor, batch=False, affected=False):
    if state['phase'] not in ['prepared', 'committed']:
        raise RuntimeError('先运行准备合并，再手工登记，最后 --finish')
    head = git(root, 'rev-parse', 'HEAD')
    if head != state['head']:
        if amended_merge(root, state, head):
            # 总装 git commit --amend 修了合并提交（父提交相同）：认它，状态跟着改
            print('提示：合并提交已修正（%s → %s，父提交相同），按修正后的提交接续' % (state['head'][:9], head[:9]), flush=True)
            state.update(head=head, mergeCommit=head)
            save(state_file, state)
        else:
            raise RuntimeError('准备后 main HEAD 已改变（%s → %s）；保留现场。准备之后不要另起提交：总装修测试或别的文件留成未提交改动，'
                               '--finish 时用 --also <路径> 一并带入（00_项目管理/ 下的 .md 用 --accept-doc-edits）；'
                               '要修合并提交本身就 git commit --amend（父提交不变，工具会自动认）。已另起提交的，'
                               'git reset --soft %s 退回成未提交改动再 --finish' % (state['head'][:9], head[:9], state['head'][:9]))
    if subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode:
        raise RuntimeError('交付提交不在 main 历史里，先人工核对')
    moved = lane_moved(state)
    if moved:
        print('提示：车道工作树%s，收尾时跳过清理该工作树' % moved, flush=True)
    if state['phase'] == 'prepared':
        board = (root / BOARD).read_text()
        active = board.split('## 正在进行', 1)[1].split('\n## ', 1)[0]
        pending = board.split('## 待交叉核查', 1)[1].split('\n## ', 1)[0]
        if mentions(active, state['branch']) or (state['worktree'] and mentions(active, state['worktree'])):
            raise RuntimeError('交接板仍将该车道列为正在进行，请唐僧更新')
        if state['branch'] not in pending and state['target'][:7] not in pending and state['head'][:7] not in pending:
            raise RuntimeError('待交叉核查尚未登记本车道分支或提交号')
        changed = dirty(root)
        uids = lane_uids(root, state)
        allowed = COMMON | set(sheets(state)) | set(state.get('versionEdits', {})) | set(state.get('also', [])) | uids
        docs = doc_edits(changed - allowed)
        if state.get('acceptDocEdits') and docs:
            print('一并暂存总装手修的文档：' + '、'.join(sorted(docs)), flush=True)
            allowed |= docs
        if changed - allowed:
            hint = '（只是 00_项目管理/ 下手修的文档可加 --accept-doc-edits 一并暂存）' if doc_edits(changed - allowed) else ''
            raise RuntimeError('不自动暂存预期外文件：' + '、'.join(sorted(changed - allowed)) + hint)
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
            check = [ENV / '检查.sh', '--oracle']
            if affected:
                # 选测（三级检查②）：基准取本批第一条合并前的 main，攒着的几条一并覆盖
                pending_batch = load_batch(state_file.parent)
                check += ['--affected', (pending_batch[0] if pending_batch else state)['base']]
            try:
                run(root, check)
            except subprocess.CalledProcessError:
                report_batch(root, load_batch(state_file.parent), state)
                raise
        # 检查可能生成 .uid 等文件，仍须重新核对，不能顺带提交。
        changed = dirty(root)
        if changed - allowed:
            raise RuntimeError('检查后出现预期外改动，先人工处理：' + '、'.join(sorted(changed - allowed)))
        validate_version_edits(root, state)
        if any((root / s).exists() for s in sheets(state)):
            raise RuntimeError('检查后交付单重新出现，先人工核对')
        if changed & uids:
            print('一并提交车道新加脚本的 Godot .uid（车道漏交）：' + '、'.join(sorted(changed & uids)), flush=True)
        run(root, ['git', 'diff', '--check'])
        # 已暂存删除的路径已不在索引里，重复 git add 会报 pathspec 不存在。
        remaining = changed - set(sheets(state))
        if remaining:
            run(root, ['git', 'add', '--', *sorted(remaining)])
        actor = 'Claude（唐僧）' if executor == 'Claude' else 'Codex（沙僧）'
        trailer = '执行者: ' + actor + '\n核查: ' + review_status(root, state)
        if affected and not batch:
            trailer += '\n验证: 选测（基准 %s，当天全量前算选测已验）' % check[-1][:9]
        run(root, ['git', 'commit', '-m', '合并 ' + state['branch'] + '（' + state['version'] + '）收尾', '-m', trailer])
        state.update(phase='committed', head=git(root, 'rev-parse', 'HEAD'), batch=batch)
        save(state_file, state)
    folder = state_file.parent
    pending = load_batch(folder)
    if state.get('batch'):
        # 只登记，工作树与推送等本批最后一条通过检查后再做；中断后重跑同一命令不会重复登记。
        if all(x['task'] != state['task'] for x in pending):
            pending.append({k: state.get(k) for k in ['task', 'branch', 'worktree', 'target', 'head', 'base', 'mergeCommit']})
            save(folder / 'batch.json', pending)
        drop_pin(state)
        state_file.unlink()
        print('已收尾并记入本批（共 %d 条，未检查、未推送）；接着合下一条，最后一条不加 --batch 运行 --finish。' % len(pending), flush=True)
        return
    for lane in pending + [state]:
        cleanup_lane(root, lane)
    (folder / 'batch.json').unlink(missing_ok=True)
    drop_pin(state)
    state_file.unlink()
    print('合并、检查、提交与工作树清理全部完成%s。' % ('（本批共 %d 条）' % (len(pending) + 1) if pending else ''), flush=True)
    push_github(root)


def add_acceptances(root, state, paths):
    """把接受单记进合并状态（acceptChanges），同步拒收后接着跑不用手改 state.json。只在还没同步完时有效；
    接受单是在 main 上新写的（不是车道带来的）就记进 also，收尾时一并提交。"""
    if state['phase'] not in ('planned', 'merged'):
        raise RuntimeError('本次合并已同步过（阶段 %s），--accept-changes 用不上；要改测量请另走流程' % state['phase'])
    for raw in paths:
        p = Path(raw)
        p = (p if p.is_absolute() else Path.cwd() / p).resolve()
        if not p.is_file():
            raise RuntimeError('接受单不存在：' + raw)
        try:
            rel = str(p.relative_to(root))
        except ValueError:
            raise RuntimeError('接受单须在主工作区里（要提交入 Git）：' + raw)
        if not rel.startswith(str(ACCEPT) + '/') or not rel.endswith('.json'):
            raise RuntimeError('接受单须放在 %s/ 下：%s' % (ACCEPT, rel))
        state['acceptChanges'] = sorted(set(state.get('acceptChanges', [])) | {rel})
        state['refresh'] = True
        if git(root, 'status', '--porcelain', '--', rel):
            state['also'] = sorted(set(state.get('also', [])) | {rel})
        print('已记入接受单 ' + rel + '，接着同步', flush=True)


def close_batch(root, folder, affected=False):
    """本批都 --finish --batch 收尾、没有新车道要合时统一收口：跑一次 检查.sh --oracle（--affected 时以本批第一条合并前的 main 为基准），
    通过后清理本批工作树、删 batch.json、推送；失败照 report_batch 列出各条车道带进来的改动，什么都不清理、不推送。"""
    pending = load_batch(folder)
    if not pending:
        raise RuntimeError('没有攒着的本批合并（batch.json），不需要收口')
    if (folder / 'state.json').exists():
        raise RuntimeError('还有一条车道在合并中（state.json），先把它 --finish（可 --batch）再收口')
    if git(root, 'rev-parse', 'HEAD') != pending[-1]['head']:
        print('提示：本批最后一条收尾后 main 又有提交（%s），一并检查' % git(root, 'log', '--oneline', pending[-1]['head'] + '..HEAD').replace('\n', '；'),
              flush=True)
    if dirty(root):
        raise RuntimeError('main 有未提交改动，先提交或移走再收口')
    check = [ENV / '检查.sh', '--oracle'] + (['--affected', pending[0]['base']] if affected else [])
    try:
        run(root, check)
    except subprocess.CalledProcessError:
        report_batch(root, pending[:-1], pending[-1])
        raise
    if dirty(root):
        raise RuntimeError('检查后 main 出现未提交改动，先人工处理：' + '、'.join(sorted(dirty(root))))
    for lane in pending:
        cleanup_lane(root, lane)
    (folder / 'batch.json').unlink()
    print('本批 %d 条收口：检查通过（%s）、工作树已清理。' % (len(pending), '选测' if affected else '全量'), flush=True)
    push_github(root)


def lane_moved(lane):
    """车道交付后若在同一工作树接着做（会话绑在这个路径上，常换新分支继续），返回原因；没动返回空串。"""
    if not lane['worktree']:
        return '合并时就没有工作树停在交付分支上'
    wt = Path(lane['worktree'])
    if not wt.exists():
        return '已不存在'
    reasons = []
    if git(wt, 'branch', '--show-current') != lane['branch']:
        reasons.append('已换到分支 ' + (git(wt, 'branch', '--show-current') or '（游离 HEAD）'))
    elif git(wt, 'rev-parse', 'HEAD') != lane['target']:
        reasons.append('交付后又有新提交')
    if porcelain(wt):
        reasons.append('有未提交改动')
    return '，'.join(reasons)


def cleanup_lane(root, lane):
    """交付提交已并入 main 后清理车道。工作树仍停在交付提交、干净且在交付分支上才删工作树；
    车道已在同一工作树继续工作（换了分支、有新提交或未提交改动）时只跳过工作树，交付分支不再是当前分支就照删。"""
    if subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', lane['target'], 'HEAD']).returncode:
        raise RuntimeError('交付提交不在 main 历史里，不清理：' + lane['worktree'])
    if lane.get('evidenceFiles'):
        print('提示：%s 的工作树有未跟踪证据，按分支引用合并，不清理工作树与交付分支' % lane['task'], flush=True)
        return
    moved = lane_moved(lane)
    if not moved:
        moved = lane_protected(root, lane)
        if moved:
            print('提示：%s 的工作树%s，只提示不删：%s' % (lane['task'], moved, lane['worktree']), flush=True)
            return
        run(root, [ENV / '清理工作树.sh', lane['worktree']])
        return
    print('提示：%s 的工作树%s，跳过清理：%s' % (lane['task'], moved, lane['worktree']), flush=True)
    wt = Path(lane['worktree']) if lane['worktree'] else None
    current = git(wt, 'branch', '--show-current') if wt and wt.exists() else None
    exists = subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '-q', 'refs/heads/' + lane['branch']],
                            capture_output=True).returncode == 0
    if not exists:
        return
    if current == lane['branch']:
        print('提示：交付分支 %s 仍是该工作树的当前分支，保留' % lane['branch'], flush=True)
        return
    # -d 只删已并入 main 的分支；交付后在这条分支上又有提交（再换走）时 Git 会拒绝，保留并提示。
    p = subprocess.run(['git', '-C', str(root), 'branch', '-d', lane['branch']], capture_output=True, text=True)
    print(('已删交付分支 ' + lane['branch']) if p.returncode == 0 else
          ('提示：交付分支 %s 有未并入 main 的提交，保留：%s' % (lane['branch'], p.stderr.strip())), flush=True)


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
    ap.add_argument('task', nargs='?')
    ap.add_argument('--root', type=Path, help='主工作区；默认从当前工具所属资料库定位')
    modes = ap.add_mutually_exclusive_group()
    modes.add_argument('--dry-run', action='store_true')
    modes.add_argument('--finish', action='store_true')
    ap.add_argument('--executor', choices=['Claude', 'Codex'], default='Claude')
    modes.add_argument('--close-batch', action='store_true',
                       help='本批都 --finish --batch 收尾后、没有新车道要合时：统一跑 检查.sh --oracle（可加 --affected），通过后清理本批工作树、推送')
    modes.add_argument('--abort', action='store_true',
                       help='单条合并要撤出 main 时：存备份后退回本条合并前的 main，撤掉本次同步写出的产物与同步基线，删 state.json；车道工作树保留')
    modes.add_argument('--abort-batch', action='store_true',
                       help='本批最后的检查失败、要撤出某条车道时：存备份后退回本批开始前的 main，车道工作树都保留')
    ap.add_argument('--batch', action='store_true',
                    help='--finish 时本条先不跑检查、不清理、不推送，记入本批；最后一条不加它统一检查')
    ap.add_argument('--affected', action='store_true',
                    help='--finish 时只跑选测（检查.sh --oracle --affected <本次合并前的 main>），通过后照常提交、清理、推送；不和 --batch 同用')
    ap.add_argument('--accept-changes', action='append', default=[], metavar='接受单',
                    help='同步因测量改变被拒后：把接受单记进本次合并状态再接着同步（不用手改 state.json），可重复')
    ap.add_argument('--accept-doc-edits', action='store_true',
                    help='--finish 时把总装在 main 手修的文档（只限 00_项目管理/ 下的 .md，交付单除外）一并暂存；默认拒收')
    ap.add_argument('--no-parse-check', action='store_true',
                    help='准备阶段跳过合并后的快速解析检查（只管本次运行；检查卡住或误报、确认无误时用）')
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
        if a.close_batch:
            if a.task or a.batch:
                raise RuntimeError('--close-batch 不带任务名、不配 --batch')
            lock = take_lock(folder)
            close_batch(root, folder, a.affected)
            return 0
        if a.abort_batch:
            lock = take_lock(folder)
            abort_batch(root, folder)
            return 0
        if not a.task:
            raise RuntimeError('要给任务名（只有 --abort-batch、--close-batch 不用）')
        if a.abort:
            lock = take_lock(folder)
            abort_one(root, folder, a.task)
            return 0
        if a.batch and not a.finish:
            raise RuntimeError('--batch 只和 --finish 一起用')
        if a.affected and (not a.finish or a.batch):
            raise RuntimeError('--affected 只和 --finish 或 --close-batch 一起用，不配 --batch（批末那条不加 --batch 时加 --affected，覆盖整批）')
        if a.accept_doc_edits and not a.finish:
            raise RuntimeError('--accept-doc-edits 只和 --finish 一起用')
        if a.accept_changes and (a.finish or a.dry_run):
            raise RuntimeError('--accept-changes 只用于准备阶段接着同步（不配 --finish、--dry-run）')
        if a.dry_run:
            print(json.dumps(plan(root, a.task), ensure_ascii=False, indent=2)); return 0
        lock = take_lock(folder)
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
            if a.finish or a.accept_changes:
                raise RuntimeError('没有准备中的合并')
            state = plan(root, a.task)
            state['executor'] = a.executor
            save(state_file, state)
        elif state.get('executor', a.executor) != a.executor:
            raise RuntimeError('接续执行者不同，请先核对原执行者登记')
        if a.accept_changes:
            add_acceptances(root, state, a.accept_changes)
            save(state_file, state)
        state['noParseCheck'] = a.no_parse_check  # 只管本次运行
        save(state_file, state)
        if a.finish:
            if a.also:
                state['also'] = sorted(set(state.get('also', [])) | set(a.also))
                save(state_file, state)
            state['acceptDocEdits'] = a.accept_doc_edits  # 只管本次运行：上次加过、这次没加仍拒
            save(state_file, state)
            finish(root, state, state_file, a.executor, a.batch, a.affected)
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
        if lock is not None:  # 只删自己拿到的锁（拿锁失败时 lock 仍是 None）
            lock.unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main())
