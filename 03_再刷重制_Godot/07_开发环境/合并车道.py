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
加 --cloud（与 --affected 同用，--close-batch 同理）则选中的 Godot 场景交给 云端选测.py 在 GitHub Actions 上跑，非 Godot 检查仍在本机；云端不可用时明确失败，不静默改本机（GitHub 因账单／额度没启动任务时 检查.sh 明说原因并改本机跑，tools29）。
推送 GitHub 成功后，main 顶上的收尾提交带「验证: 选测／全量」尾注（--close-batch 收口的没有）、且没有「手补:」或另带「手补已验:」时，
自动 云端选测.py trust <收尾提交> --reason 合并推送后自动 立云端锚点，选测基准跟上 main；立失败只警告，不影响推送（tools77）。
--close-batch 收口推送成功后，给收口刚检查通过的提交立锚点（--reason 收口推送后自动；收口前工作区干净、手补都已提交，检查测的就是它，tools78）。
总装一步合一条：--lane <任务> --who <执行者> --desc <内容> [--branch <分支>]＝准备→查工程／设计文档里新冒出来的 O-待定→交接板移走「正在进行」里
本车道的行、补新优化号的「需要用户决定」行与待核查首行→--finish --batch；--queue a,b=分支,c 按序逐条 --lane，全过再自动 --close-batch
（可加 --affected、--cloud；--who／--desc 给一个全队同用或每条一个）。哪步停下都留现场，修好后重跑同一命令接着做（tools78）。

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

sys.path.insert(0, str(Path(__file__).resolve().parent))
from 推送重试 import retry_push  # noqa: E402

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
OPT_REGISTRY = SUB / '00_设计/优化登记.md'
VERSION_MARKER = 'dev.' + '待定'
# 优化登记号占位：车道文档里写 O-待定（同一份里要区分几项就写 O-待定-1、O-待定-2），合并时按已登记的最大 O-NNN 顺延换号
# （总装手换漏过一处注释，唐僧 10-30）。占位字面量拆开写，免得本文件自己被换号。
# 只有交付单优化登记草稿表行首格的占位发号；代码注释照换，文档（.md）行要带本批草稿的识别键才换，其余原样留着、准备阶段提示（tools42）。
# 工具源码（开发环境、转换工具）里提到占位的注释与文档串不是车道登记的优化项，不换号（唐僧 10-30 合 tools13 时被误换）。
OPT_SKIP = (str(ENV) + '/', str(TOOLS) + '/')
OPT_TOKEN = re.compile('O-' + '待定' + r'(?:-\d+)?')
OPT_NUMBERED = re.compile(r'O-(\d{3})(?!\d)')
# 换号只认本条交付单里的占位，和别的文件里车道自己新增的行（按 diff 新增行判）；登记文件（交接板、归档、变更记录）永远不扫：
# 它们的车道表、说明里常原样写着占位字样（唐僧 10-30 合白龙期一时被整片换成 O-122）。
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


# 主工作区 main 有提交守卫（装提交守卫.sh）：本工具自己的提交与合并带这个变量放行；
# 合并在进行（state.json 在）时守卫只认 XIYOU_LANE_MERGE，总装手动带 XIYOU_MAIN_COMMIT=1 的提交也拦（tools22）
MAIN_COMMIT_ENV = dict(os.environ, XIYOU_MAIN_COMMIT='1', XIYOU_LANE_MERGE='1')


def run(root, args, env=None):
    print('== ' + ' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=root, check=True, env=env)


def tool_gate(root):
    """选测收尾（--affected）在开云端选测／本机选测之前先跑 工具回归.py（几十秒的工具快速回归：替身名单、插件备注、状态 js 翻译等），
    失败就早停，省云端额度和一轮本机检查（tools65：这类回归过去要到本机收尾才挂，三次各白耗一轮云端＋10 分钟）。
    XIYOU_TOOL_GATE=0 关；脚本不存在（夹具仓库）时跳过。失败抛 CalledProcessError，调用处和检查失败一样走 report_batch。"""
    script = root / ENV / '工具回归.py'
    if os.environ.get('XIYOU_TOOL_GATE', '1') == '0':
        return
    if not script.is_file():
        print('提示：没有 工具回归.py，跳过工具快速回归', flush=True)
        return
    try:
        run(root, [sys.executable, script])
    except subprocess.CalledProcessError:
        print('工具快速回归没过：先修工具（上面 ✗ 项），云端选测与本机检查都没有开始；修好后重跑同一条 --finish。', flush=True)
        raise


def release_only_path(path):
    """版本号、登记、文档类文件（与 云端选测.py 的 release_only 同口径）：收尾提交里只有这些改动不算手补代码。"""
    p = str(path)
    return p in {str(SUB / '开发编号.json'), str(PROJECT / 'project.godot'), str(PROJECT / 'content/build_info.json')} \
        or p.endswith('.uid') or (p.startswith(('00_项目管理/', str(SUB / '00_设计') + '/')) and p.endswith(('.md', '.json')))


def cloud_env(*lanes):
    """--cloud 时给 检查.sh 的环境：本批各条都没带切片／参照刷新（refresh）时，转换产物与 GitHub 上 main 的快照一致，云端不必重传。"""
    env = dict(os.environ)
    if not any(lane.get('refresh') for lane in lanes):
        env['CHECK_CLOUD_NO_UPLOAD'] = '1'
    return env


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


APP_SESSION_GUARD = True  # tools27：工作树属于没归档的 app 会话就不删；设 False（或 XIYOU_APP_SESSION_GUARD=0）回到只看 lsof／锁／交接板
APP_SESSIONS = Path.home() / 'Library/Application Support/Claude/claude-code-sessions'


def app_session(path):
    """桌面 app 里用这个工作树、还没归档的会话（claude-code-sessions/*/*/local_*.json 的 worktreePath／cwd 与 isArchived），
    返回会话标题；没有返回 None。会话空闲时没有进程的 cwd 在里面，lsof 认不出（总装七 10-31：审查会话的
    affectionate-taussig-9508e5 被 --finish 清理删掉）。只读这些 json；目录不在（云端、没装 app）或读不了的文件跳过。"""
    if not APP_SESSION_GUARD or os.environ.get('XIYOU_APP_SESSION_GUARD') == '0':
        return None
    folder = Path(os.environ.get('XIYOU_APP_SESSIONS', str(APP_SESSIONS)))
    base = os.path.realpath(path)
    for f in folder.glob('*/*/local_*.json'):
        try:
            d = json.loads(f.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            continue
        if not isinstance(d, dict) or d.get('isArchived'):
            continue
        used = [d.get('worktreePath'), d.get('cwd')]
        if any(isinstance(u, str) and u and os.path.realpath(u) == base for u in used):
            return str(d.get('title') or d.get('sessionId') or f.stem)
    return None


def lane_protected(root, lane):
    """清理车道工作树前的保护：返回不删的原因，没有就返回空串。"""
    wt = Path(lane['worktree'])
    procs = active_cwds(wt)
    if procs is None:
        return '无法确认有无活动会话（lsof 不可用、超时或失败），保守不删'
    if procs:
        return '有活动会话（进程 %s 的当前目录在其中）' % '、'.join('%s %s' % p for p in procs[:3])
    owner = app_session(wt)
    if owner:
        return '属于桌面 app 里没归档的会话「%s」（会话空闲时 lsof 认不出；归档该会话后再清理）' % owner
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


AWAIT_TERNARY_OK = '# await-ternary-ok'   # 写在该句（首行）末尾：确认三元式两边都不是异步函数


def _gd_logical_lines(text):
    """去掉字符串与注释后按逻辑行拼起来：括号没合上或行尾反斜杠续行的并成一句。返回 [(起始行号, 首行原文, 去掉字符串注释后的句子)]。"""
    out, buf, start, depth, triple = [], '', 0, 0, None
    lines = text.splitlines()
    for no, line in enumerate(lines, 1):
        clean, i = [], 0
        while i < len(line):
            if triple:
                end = line.find(triple, i)
                if end < 0:
                    break
                i, triple = end + 3, None
                clean.append('""')
                continue
            c = line[i]
            if c == '#':
                break
            if line[i:i + 3] in ('"' * 3, "'" * 3):
                triple, i = line[i:i + 3], i + 3
                continue
            if c in '"\'':
                j = i + 1
                while j < len(line) and line[j] != c:
                    j += 2 if line[j] == '\\' else 1
                clean.append('""')
                i = j + 1
                continue
            depth += (c in '([{') - (c in ')]}')
            clean.append(c)
            i += 1
        if not buf:
            start = no
        body = ''.join(clean).rstrip()
        cont = body.endswith('\\')
        buf += ' ' + body.rstrip('\\')
        if depth <= 0 and not cont and not triple:
            out.append((start, lines[start - 1], buf.strip()))
            buf, depth = '', 0
    return out


def _group_end(s, i):
    """s[i] 是开括号：返回配对的闭括号之后的位置（没配上返回 len(s)）。"""
    depth = 0
    for j in range(i, len(s)):
        depth += (s[j] in '([{') - (s[j] in ')]}')
        if depth == 0:
            return j + 1
    return len(s)


def _await_operand_end(s, i):
    """s[i:] 是 await 的操作数：取一个基本式加后缀（.名、(…)、[…]）的结束位置（await 的优先级高于三元式与二元运算）。"""
    m = re.match(r'\s*', s[i:])
    i += m.end()
    if i < len(s) and s[i] in '([{':
        i = _group_end(s, i)
    else:
        m = re.match(r'[\w$@^&"]+', s[i:])
        i += m.end() if m else 0
    while True:
        m = re.match(r'\s*(\.\s*\w+|[(\[])', s[i:])
        if not m:
            return i
        if m.group(1) in '([':
            i = _group_end(s, i + m.end() - 1)
        else:
            i += m.end()


def _top_level(s, i):
    """从 s[i] 起到本层结束（逗号、闭括号或句尾）的片段，括号里的内容换成空格，只留本层。"""
    out, depth = [], 0
    for c in s[i:]:
        if c in ')]}' and depth == 0 or c == ',' and depth == 0:
            break
        depth -= c in ')]}'
        out.append(c if depth == 0 else ' ')   # 括号本身留着（认得出调用），里面的内容换成空格
        depth += c in '([{'
    return ''.join(out)


TERNARY = re.compile(r'\S.*?\bif\b.+?\belse\b')
CALL = re.compile(r'[\w)\]]\s*\(')


def await_ternaries(text):
    """await 碰上三元式、有异步调用会被跳过的句子 [(行号, 首行原文)]。GDScript 里 await 的优先级高于三元式：
    ①`await (a() if c else b())`：括号里的三元式两边的调用都不算被 await（两边都没调用、只是挑信号的不报）；
    ②`await a() if c else b()`＝`(await a()) if c else b()`：else 那边有调用时它没被 await。
    Godot 只报「Trying to call an async function without await」不中断，结果被静默跳过（11-07 八戒 mapev1：主事件文字全被跳过）。
    三元式只在实参里（`await f(x if c else y)`）、或 else 那边没有调用（`await f() if c else null`）的不报。
    该句首行末尾写 # await-ternary-ok 的不报（确认两边都不是异步函数）。"""
    found = []
    for no, raw, stmt in _gd_logical_lines(text):
        if AWAIT_TERNARY_OK in raw:
            continue
        for m in re.finditer(r'\bawait\b', stmt):
            op = m.end() + len(re.match(r'\s*', stmt[m.end():]).group())
            end = _await_operand_end(stmt, m.end())
            inner = _top_level(stmt, op + 1) if stmt[op:op + 1] == '(' and end == _group_end(stmt, op) else ''
            bad = bool(TERNARY.search(inner) and CALL.search(inner))   # 只是挑信号（await (a if c else b)）不报
            if not bad:
                rest = re.match(r'\s*if\b(.*?)\belse\b(.*)', _top_level(stmt, end))
                bad = bool(rest and CALL.search(rest.group(2)))
            if bad:
                found.append((no, raw.strip()))
                break
    return found


def gd_await_ternary_problems(project):
    """工程里全部 .gd（.godot 缓存除外）的 await 三元式问题（纯文本扫描，不要 godot）。"""
    problems = []
    for f in sorted(project.rglob('*.gd')):
        rel = f.relative_to(project)
        if '.godot' in rel.parts:
            continue
        for no, line in await_ternaries(f.read_text(errors='replace')):
            problems.append('res://%s:%d：await 与三元式写在同一句，异步调用会被跳过，拆成 if/else 各自 await'
                            '（确认两边都不是异步函数可在句末写 %s）：%s' % (rel.as_posix(), no, AWAIT_TERNARY_OK, line[:120]))
    return problems


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
    """合并后、同步与检查前的快速解析检查（1 分钟内）：①本次合并改动的 .gd 有没有同名 func，工程全部 .gd 有没有 await 三元式；②godot --import 刷新类缓存后
    用外置脚本逐个 load 工程里全部 .gd，日志里有算数的 SCRIPT ERROR 就列出。没有 godot 或工程时只做①。返回问题列表。"""
    problems = []
    for rel in git(root, 'diff', '--name-only', '--diff-filter=AM', base, 'HEAD', '--', '*.gd').splitlines():
        f = root / rel
        if f.is_file():
            for name, lines in duplicate_funcs(f.read_text(errors='replace')):
                problems.append('%s：func %s 重复定义（第 %s 行）' % (rel, name, '、'.join(map(str, lines))))
    godot, project = root / ENV / 'godot', root / PROJECT
    if project.is_dir():
        problems += gd_await_ternary_problems(project)
    if not (os.access(godot, os.X_OK) and (project / 'project.godot').is_file()):
        print('提示：没有 godot 或工程，解析检查只扫了同名 func 与 await 三元式', flush=True)
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
    who = 'Codex·沙僧' if branch.startswith('codex/') else ('cc·未经审查' if branch.startswith('cc/') else 'Claude·未经Codex检验')
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


def lane_branches(task, branch=None):
    """这个任务可能对应的分支：给了 --branch 就只认它（任务名仍是交付单名）；否则 cc/、claude/、codex/ 加任务名。"""
    return [branch] if branch else ['cc/' + task, 'claude/' + task, 'codex/' + task]


def branch_hint(root, task):
    """找不到 <前缀>/<任务> 时的线索：交付单名是 <前缀>_<任务>.md 的分支（app 自建工作树常把车道建在 cc/<随机名> 上）。"""
    try:
        refs = git(root, 'for-each-ref', '--sort=-committerdate', '--count=60', '--format=%(refname:short)', 'refs/heads').splitlines()
    except RuntimeError:
        return ''
    found = []
    for ref in refs:
        try:
            names = git(root, 'ls-tree', '--name-only', ref, '00_项目管理/交付/').splitlines()
        except RuntimeError:
            continue
        if any(re.fullmatch(r'00_项目管理/交付/(?:cc|claude|codex)_' + re.escape(task) + r'\.md', n) for n in names):
            found.append(ref)
    return '；交付单名对得上的分支有：%s（用 --branch <分支> 指定）' % '、'.join(found) if found else ''


PRESETS = TOOLS / 'event_presets.json'
STATE_BASELINE = PROJECT / 'modes/xiyou/generated/oracle/event_states.json'


def deleted_reference_presets(root, fork, base, target):
    """车道删掉的、main 基线里还有的事件状态预设行（base#tag）。同步不收删除既有参照用例（oracle_additions 记成 switchOnly，
    只在换源时可接受），这种车道合到同步那步必被拒、白跑一轮整份探针（11-09 seg-a3 删 ce1442 w8_* 70 个，同步 90 分钟后才拒）。
    三方比：分叉点与合并前 main 都有、车道上没了的行才算车道删的（main 后来自己删的、车道后加又删的都不算）；
    main 已发布的 event_states.json 在时再只留基线里真有的用例（goneIn 跳过的不算）。读不准就返回空（照旧交给同步把关）。
    换源合并（XIYOU_ACCEPT_SOURCE_SWITCH）不查；XIYOU_LANE_DELETE_CHECK=0 关掉本检查（tools-merge-probe）。"""
    if os.environ.get('XIYOU_LANE_DELETE_CHECK', '1') == '0' or os.environ.get('XIYOU_ACCEPT_SOURCE_SWITCH'):
        return []
    rel = str(PRESETS)
    try:
        if rel not in git(root, 'diff', '--name-only', fork, target, '--', rel).splitlines():
            return []

        def rows(rev):
            return {c['base'] + '#' + c['tag'] for c in json.loads(git(root, 'show', rev + ':' + rel))['cases']}
        gone = (rows(fork) & rows(base)) - rows(target)
    except (RuntimeError, ValueError, KeyError, TypeError):
        return []
    baseline = root / STATE_BASELINE
    if gone and baseline.is_file():
        try:
            gone &= {c.get('id') for c in json.loads(baseline.read_text()).get('cases') or []}
        except (OSError, ValueError, AttributeError):
            pass
    return sorted(gone)


def plan(root, task, branch=None):
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
    lanes = [w for w in worktrees(root) if w.get('branch') in lane_branches(task, branch)]
    if len(lanes) > 1:
        raise RuntimeError('须有且只有一个对应任务的已登记车道工作树（%s 都有工作树，用 --branch <分支> 指定）'
                           % '、'.join(w['branch'] for w in lanes))
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
        refs = [b for b in lane_branches(task, branch)
                if subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '-q', 'refs/heads/' + b],
                                  capture_output=True).returncode == 0]
        if len(refs) != 1:
            raise RuntimeError('须有且只有一个对应任务的车道工作树或车道分支' + (
                branch_hint(root, task) if not refs else '（%s 都在，用 --branch <分支> 指定）' % '、'.join(refs)))
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
    # 交付单：按分支名（/ 换成 _），再按任务名找 cc_／claude_／codex_<任务>.md。分支与交付单前缀常对不上：
    # --branch 指定的 app 随机名分支；10-31 八戒分支 cc/bajie-blackflash 交付单却叫 claude_bajie-blackflash.md（tools22）
    own = Path('00_项目管理/交付') / (branch.replace('/', '_') + '.md')
    names = dict.fromkeys([own] + [Path('00_项目管理/交付') / ('%s_%s.md' % (p, task)) for p in ('cc', 'claude', 'codex')])
    found = {d: s for d, s in ((d, read(d)) for d in names) if s is not None}
    if not found:
        raise RuntimeError('车道分支缺少交付单：' + '、'.join(map(str, names)) + ' 都没有')
    if len(found) > 1:
        # 车道没合 main 时树里可能还留着本任务早先已归并、main 已删的那份：不算
        found = {d: s for d, s in found.items()
                 if (root / d).exists() or not git(root, 'log', '--diff-filter=D', '--format=%H', '-1', base, '--', str(d))} or found
    if len(found) > 1:
        raise RuntimeError('车道分支上有 %d 份交付单（%s），须只留一份：车道删掉多的那份再交' % (len(found), '、'.join(map(str, found))))
    (delivery, text), = found.items()
    draft(text)
    registry = '\n'.join(x for x in [(root / OPT_REGISTRY).read_text() if (root / OPT_REGISTRY).is_file() else '', read(OPT_REGISTRY) or ''] if x)
    check_opt_drafts(text, str(delivery), registry)
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
    extra, gone = [], []
    for p in sorted(changed):
        if (p.startswith('00_项目管理/交付/') and p.endswith('.md') and p not in (str(delivery), '00_项目管理/交付/README.md')
                and read(p) is not None):
            removed = git(root, 'log', '--diff-filter=D', '--format=%H', '-1', base, '--', p)
            if removed and not (root / p).exists():
                before = subprocess.run(['git', '-C', str(root), 'rev-parse', '-q', '--verify', removed + '^:' + p],
                                        capture_output=True, text=True).stdout.strip()
                if git(root, 'rev-parse', target + ':' + p) != before:
                    print('提示：%s 已在 main 删除（%s 归并过），车道上的版本与删前不同；不再并入，车道补写的内容请写进本期交付单'
                          '（合并时这处 modify/delete 冲突按删除处理）' % (p, removed[:9]), file=sys.stderr, flush=True)
                    # 11-06 shop1 改了已归并的 keys3 交付单：没剔掉就进了 versionPaths（交付单都带开发编号占位），
                    # 冲突按删除解决后报「编号占位文件已改变类型」，总装手改 state 才过（tools76）
                    gone.append(p)
                continue
            try:
                draft(read(p))
            except RuntimeError:
                print('提示：另有交付单 ' + p + ' 未标可合并或草稿不完整，未并入；不要它就在 main 删掉，--finish 时加 --also ' + p,
                      file=sys.stderr, flush=True)
                continue
            check_opt_drafts(read(p), p, registry)        # 接续交付单的优化草稿照本期的查（tools39）
            extra.append(p)
    changed = [p for p in changed if p not in gone]
    removed_cases = deleted_reference_presets(root, fork, base, target)
    if removed_cases:
        raise RuntimeError('车道删了 main 基线里的 %d 个事件状态参照用例（%s%s）：同步不收删除既有参照用例（只换源时可接受），'
                           '合并到同步那步一定被拒、白跑整份探针。还没合并，main 没动。请车道恢复这些预设行（冗余也保留，换源时再删）、'
                           '本树增量补跑探针后再交付；确要照旧交给同步判就设 XIYOU_LANE_DELETE_CHECK=0'
                           % (len(removed_cases), '、'.join(removed_cases[:6]), ' 等' if len(removed_cases) > 6 else ''))
    refresh = any(p in [str(TOOLS / 'xiyou_slice.json'), str(TOOLS / 'xiyou_export.py')]
                  or (p.startswith(str(TOOLS / 'mv_oracle') + '/') and p.endswith('.cjs')) for p in changed)
    # 车道带来的测量接受单（同步正式西游.py --accept-changes）：main 的同步对自己的旧基线同样逐条核对
    accept = [p for p in sorted(changed) if p.startswith(str(ACCEPT) + '/') and p.endswith('.json') and read(p) is not None]
    refresh = refresh or bool(accept)
    game = any(p.startswith(str(PROJECT) + '/') and not p.startswith(str(PROJECT / 'tests') + '/')
               and p != str(PROJECT / 'content/build_info.json') for p in changed)
    # 只替换目标车道带来的编号占位，不扫描、暂存主工作区的其它文件。
    def opt_lines(p):
        if p.startswith(OPT_SKIP) or is_register(p):
            return []
        added = git(root, 'diff', '-U0', '--no-color', fork, target, '--', p).splitlines()
        return [x[1:] for x in added if x.startswith('+') and not x.startswith('+++') and OPT_TOKEN.search(x)]
    version_paths, opt_added = [], {}
    for p in changed:
        if p == str(delivery) or p in extra or p in VERSION_EXEMPT or Path(p).suffix not in {'.md', '.json', '.gd', '.py', '.sh'}:
            continue
        lines = opt_lines(p) if OPT_TOKEN.search(read(p) or '') else []
        if VERSION_MARKER in (read(p) or '') or lines:
            version_paths.append(p)
            if lines:
                opt_added[p] = lines
    check_orphan_placeholders([dict(token=tok, row=row, keys=sorted(ks)) for tok, row, ks in opt_row_entries([text] + [read(p) for p in extra])],
                              {p: (read(p) or '', lines) for p, lines in opt_added.items()})
    return dict(task=task, branch=branch, worktree=str(wt) if wt else '', base=base, target=target,
                delivery=str(delivery), extraDeliveries=extra, refresh=refresh, acceptChanges=accept, gameplay=game, phase='planned', head=base,
                versionPaths=version_paths, optAdded=opt_added, evidenceFiles=evidence, goneSheets=gone,
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


OPT_DRAFT_HEAD = re.compile(r'^## (?!.*【).*优化登记草稿.*$', re.M)
OPT_NONE = re.compile(r'^(?:[-*]\s*)?优化登记草稿[：:]\s*无\s*$', re.M)


def opt_draft_rows(text):
    """交付单「## 优化登记草稿」节里的表行（首格是占位或编号的行）；表头与分隔行不算。
    没有这个标题时，认正文里首格是占位的 8 列表行（11-01 guyu4 把表写在「## 发现的原版问题」下，工具读不到，两条同号、没登记，tools39）。"""
    m = OPT_DRAFT_HEAD.search(text)
    if not m:
        return [x.strip() for x in text.splitlines()
                if re.match(r'^\|\s*O-', x) and len(x.strip().split('|')) == 10 and OPT_TOKEN.fullmatch(x.split('|')[1].strip())]
    rest = text[m.end():]
    nxt = re.search(r'^## ', rest, re.M)
    block = rest[:nxt.start()] if nxt else rest
    return [x.strip() for x in block.splitlines() if re.match(r'^\|\s*O-', x)]


def opt_draft_list_items(text):
    """交付单「## 优化登记草稿」节里写成列表（「- O-待定 …」）的条目：登记表是 8 列，列表凑不出各列，合并工具不认。"""
    m = OPT_DRAFT_HEAD.search(text)
    if not m:
        return []
    rest = text[m.end():]
    nxt = re.search(r'^## ', rest, re.M)
    block = rest[:nxt.start()] if nxt else rest
    return [x.strip() for x in block.splitlines() if re.match(r'^\s*[-*]\s+.*' + OPT_TOKEN.pattern, x)]


OPT_NAMED = re.compile(OPT_TOKEN.pattern + r'·([^\s|｜，,。、；;：:（）()\[\]【】「」`*"\']+)')


def opt_section_none(text):
    """「## 优化登记草稿」标题下第一段非空内容只写「无」（或「- 无」「（无）」）：同「优化登记草稿：无」（11-07 拦了四条，tools-merge-args3）。"""
    m = OPT_DRAFT_HEAD.search(text)
    if not m:
        return False
    first = next((x.strip() for x in text[m.end():].splitlines() if x.strip()), '')
    return bool(re.fullmatch(r'(?:[-*]\s*)?[（(]?无[）)]?[。.]?(?:\s*[（(].*[）)])?', first))


def registered_named(registry):
    """优化登记里首格是「O-待定·名字」的行的整个首格（名字可带空格，如「O-待定·SvPngFd 先清再解析」），长的在前。"""
    rows = set(re.findall(r'^\|\s*(' + OPT_TOKEN.pattern + r'·[^|]+?)\s*\|', registry or '', re.M))
    return sorted(rows, key=len, reverse=True)


def unregistered_named(text, registry):
    """正文里每个 O-待定 占位：不带名字的记成「O-待定」，带名字但登记里没有逐字同名首格的记成它在正文里的样子；都对上返回空。
    名字按登记首格逐字比（含空格），不再按字符截断（审查 60 P3-2：「SvPngFd 先清再解析」只认出「SvPngFd」）。"""
    rows, bad = registered_named(registry), []
    for m in OPT_TOKEN.finditer(text):
        if not text.startswith('·', m.end()):
            bad.append(m.group(0))
        elif not any(text.startswith(r, m.start()) for r in rows):
            n = OPT_NAMED.match(text, m.start())
            bad.append(n.group(0) if n else m.group(0) + '·')
    return bad


def opt_tokens_registered(text, registry):
    """正文里的优化号占位都写成「O-待定·名字」、且优化登记里已有「| O-待定·名字 |」行（车道直接写进登记表的）：登记有人写了，不用草稿表。"""
    return bool(registry) and bool(OPT_TOKEN.search(text)) and not unregistered_named(text, registry)


def number_named(root, base, state=None, state_file=None):
    """--lane 时给本次合并新登记的具名占位发正式号（审查 60 P3-1）：优化登记首格「O-待定·名字」、合并前的 main 登记里没有的，
    按已用的最大号（opt_top_number）顺延，首格与工程、设计文档、交接板、变更记录里的同名占位一起换（replace_named）。工具源码照旧不换。
    返回 ([(编号, 项目)], [可能改过的文件])；早先就在登记里、还没发号的只列出来，不动；总装想顺带一次清掉旧的，这条合并设
    XIYOU_NUMBER_NAMED=all（旧的按登记表顺序一起发号）。XIYOU_NUMBER_NAMED=0 关掉。
    给了 state 时：先把发号计划（namedNumbers、namedRows、namedFiles）存进合并状态再写文件，重跑同一条 --lane 照计划接着换（幂等）；
    换过的文件若在 versionEdits 里（同一文件也有 dev.406，准备阶段已记下替换后的摘要），把那份摘要更新成发号之后的，
    免得 --finish 的 validate_version_edits 报「编号替换文件还有其它改动」（审查 63 P2-1）。"""
    reg = root / OPT_REGISTRY
    plan = state.get('namedNumbers') if state is not None else None
    if plan is None:
        if os.environ.get('XIYOU_NUMBER_NAMED', '1') == '0' or not reg.is_file():
            return [], []
        text = reg.read_text()
        old = subprocess.run(['git', '-C', str(root), 'show', '%s:%s' % (base, OPT_REGISTRY)], capture_output=True, text=True).stdout
        before = set(registered_named(old))
        rows = [r for r in re.findall(r'^\|\s*(' + OPT_TOKEN.pattern + r'·[^|]+?)\s*\|', text, re.M)]
        mode = os.environ.get('XIYOU_NUMBER_NAMED', '1')
        todo = [r for r in rows if r in before and mode != 'all']
        if todo:
            print('提示：优化登记里还有 %d 行早先登记、没发号的具名占位（%s）；要一并发号，这条合并设 XIYOU_NUMBER_NAMED=all'
                  % (len(todo), '、'.join(t.split('·', 1)[1] for t in todo[:12])), flush=True)
        fresh = list(dict.fromkeys(r for r in rows if r not in before or mode == 'all'))
        if not fresh:
            return [], []
        nxt = opt_top_number(root) + 1
        plan = {}
        for tok in fresh:
            plan[tok] = 'O-%03d' % nxt
            nxt += 1
        all_rows = registered_named(text)
        out = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', 'grep', '-l', '-F', '-e', 'O-' + '待定·', '--',
                              str(PROJECT), str(SUB / '00_设计'), str(BOARD), '00_项目管理/变更记录*.md'],
                             capture_output=True, text=True).stdout.splitlines()
        files = [rel for rel in dict.fromkeys(out + [str(OPT_REGISTRY)]) if (root / rel).is_file() and not rel.startswith(OPT_SKIP)]
        names = {}
        for tok in plan:
            row = next((l for l in text.split('\n') if re.match(r'^\|\s*' + re.escape(tok) + r'\s*\|', l)), '')
            names[tok] = row.split('|')[2].strip() if row else tok.split('·', 1)[1]
        if state is not None:
            state.update(namedNumbers=plan, namedRows=all_rows, namedFiles=files, namedNames=names)
            state['optAppended'] = state.get('optAppended', []) + [[plan[t], names[t]] for t in plan]
            save(state_file, state)
    else:
        all_rows, files, names = state['namedRows'], state['namedFiles'], state['namedNames']
    for rel in files:
        f = root / rel
        if not f.is_file():
            continue
        old_text = f.read_text()
        new_text = replace_named(old_text, plan, all_rows)
        if new_text != old_text:
            f.write_text(new_text)
        if state is not None and rel in state.get('versionEdits', {}):
            state['versionEdits'][rel]['after'] = digest(f.read_bytes())
    if state is not None:
        save(state_file, state)
    added = []
    for tok, num in plan.items():
        added.append((num, names[tok]))
        print('具名占位发号：%s → %s' % (tok, num), flush=True)
    return added, list(files)


def check_opt_drafts(text, name, registry=''):
    """正文提到 O-待定 却没有草稿表：登记没人写（总装只能手补），拦下让车道补表；确无新优化可写「优化登记草稿：无」
    （或标题下单写「无」）；提到的都是「O-待定·名字」且优化登记里已有同名行也放行（registry：优化登记.md 的文字）。
    草稿写成列表（「- O-待定 …」）也拦下：登记表要 8 列，列表对不上，不静默丢掉。"""
    items = opt_draft_list_items(text)
    if items:
        raise RuntimeError('交付单 %s 的「## 优化登记草稿」是列表不是表格（%s…）：改成表格行（表头照优化登记.md，8 列，首格写占位），合并工具只认表行'
                           % (name, items[0][:40]))
    if (OPT_TOKEN.search(text) and not opt_draft_rows(text) and not OPT_NONE.search(text) and not opt_section_none(text)
            and not opt_tokens_registered(text, registry)):
        raise RuntimeError('交付单 %s 提到优化号占位却没有「## 优化登记草稿」表行：车道补一张表（表头照优化登记.md，首格写占位），'
                           '确无新优化就写一行「优化登记草稿：无」（或标题下单写「无」）；已直接写进优化登记表的，正文写成「O-待定·名字」与登记行同名' % name)


def opt_row_keys(row):
    """草稿表行的识别键：项目／位置列和恢复方法列里的标识符（含开关名去掉类名的后半）与三字以上的中文词。
    代码注释、文档里的占位靠这些键对上是哪一条草稿（同一份交付单里有几条不同优化时）。"""
    cells = row.split('|')
    text = ' '.join(cells[2:3] + cells[6:7])
    keys = set()
    for ident in re.findall(r'[A-Za-z_][A-Za-z0-9_.]{3,}', text):
        keys.add(ident)
        last = ident.split('.')[-1]
        if len(last) >= 4:
            keys.add(last)
    keys.update(re.findall(r'[\u4e00-\u9fff]{3,}', cells[2] if len(cells) > 2 else ''))
    return keys


def opt_row_entries(texts):
    """各交付单草稿表行里首格是占位的条目，按出现顺序：[(占位, 行, 识别键)]。"""
    out = []
    for t in texts:
        for row in opt_draft_rows(t):
            m = OPT_TOKEN.fullmatch(row.split('|')[1].strip())
            if m:
                out.append((m.group(0), row, opt_row_keys(row)))
    return out


def opt_row_paths(row):
    """草稿表行「位置」列里写的文件（`battle/boss_hp_bar.gd` 这类，可以是工程内的相对后半段）。"""
    cells = row.split('|')
    return re.findall(r'[\w./-]*\w\.(?:gd|py|json|sh|tscn|cjs)\b', cells[2] if len(cells) > 2 else '')


def comment_context(lines, i):
    """第 i 行注释管到的下文：接着的注释行，加注释块后第一条非空代码行（开关声明）；遇空行就停（那段注释不注哪条声明）。"""
    out = []
    for x in lines[i + 1:i + 12]:
        if not x.strip():
            break
        out.append(x)
        if not x.lstrip().startswith('#'):
            break
    return '\n'.join(out)


def pick_by_location(line, rel, rows, after=''):
    """车道代码注释里的占位和草稿表行对不上号（11-06 ui16：草稿 O-待定-1～3、注释都写 O-待定）：按草稿行「位置」列的文件认；
    同一文件有几条时再看本行和它注的声明里有没有哪条独有的识别键（开关名等）。返回 (那条, 该文件的候选)；分不出时第一项是 None。"""
    cand = [r for r in rows if any(rel == f or rel.endswith('/' + f) for f in opt_row_paths(r['row']))]
    if len(cand) <= 1:
        return (cand[0] if cand else None), cand
    ctx = line + '\n' + after
    hit = [r for r in cand if any(k in ctx for k in r['keys'] if sum(k in o['keys'] for o in cand) == 1)]
    return (hit[0] if len(hit) == 1 else None), cand


def orphan_problem(rel, n, line, tok, cand, rows):
    each = 'O-' + '待定' + '-N'
    if not cand:
        return ('%s:%d 注释写 %s，本批草稿（%s）的「位置」列都没写这个文件：%s——草稿表行的「位置」写上文件，或注释改成对应草稿首格的写法'
                % (rel, n, tok, '、'.join(r['token'] for r in rows), line.strip()[:60]))
    return ('%s:%d 注释写 %s，「位置」列写这个文件的草稿有 %d 条（%s），这一行分不出是哪条：%s'
            '——同一文件有几条时，车道把注释写成对应的 %s（与草稿表首格一致）'
            % (rel, n, tok, len(cand), '、'.join(r['token'] for r in cand), line.strip()[:60], each))


def orphan_tokens(line, known):
    # 「O-待定·名字」是直接写进优化登记表的那种，不按草稿表换号（--lane 按登记表放行，tools-merge-args4）
    return [m.group(0) for m in OPT_TOKEN.finditer(line) if m.group(0) not in known and not line.startswith('·', m.end())]


def check_orphan_placeholders(rows, files):
    """plan 阶段：车道新增代码行里和草稿首格对不上的占位，都要能按「位置」认出唯一一条；认不出的一次列全、停下（tools76）。
    files：{相对路径: (全文, 新增行)}。没有草稿表行时不查（照旧提示未换号）。"""
    if not rows:
        return
    known = {r['token'] for r in rows}
    problems = []
    for rel, (text, added) in files.items():
        if rel.endswith('.md'):
            continue
        lines = text.split('\n')
        added = set(added)
        for i, line in enumerate(lines):
            if line not in added:
                continue
            for tok in orphan_tokens(line, known):
                hit, cand = pick_by_location(line, rel, rows, comment_context(lines, i))
                if hit is None:
                    problems.append(orphan_problem(rel, i + 1, line, tok, cand, rows))
    if problems:
        raise RuntimeError('代码注释里的优化号占位对不上草稿表（合并后会原样留着、收尾 opt_audit 才拦）：\n  ' + '\n  '.join(problems))


def substitute_ambiguous(line, state, after=''):
    """同一个占位在本批有几条不同草稿时，按行对号：行里出现哪条草稿独有的识别键就换哪条的号；本行没有就看紧跟的两行
    （after：代码注释写在开关声明上一行，「## 优化 O-待定：…」下一行才是 static var FIT_ROWS，tools39）；对不上或对上几条就停下，让总装手改。"""
    for tok, entries in state.get('optEntries', {}).items():
        pat = re.compile(re.escape(tok) + r'(?!-?\d|·)')
        if not pat.search(line):
            continue
        hit = [e for e in entries if line.strip() == e['row']]
        if not hit:
            hit = [e for e in entries if any(k in line for k in e['keys'])]
        if not hit and after:
            hit = [e for e in entries if any(k in after for k in e['keys'])]
        if len(hit) != 1:
            raise RuntimeError('占位 %s 在本批对应 %d 条优化草稿（%s），这一行对不上是哪条（%s）：总装手改成对应的编号，再重跑'
                               % (tok, len(entries), '、'.join(e['number'] for e in entries), line.strip()[:80]))
        line = pat.sub(hit[0]['number'], line)
    return line


def append_opt_registry(root, state):
    """把各交付单草稿表里的占位行（换好号）追加到优化登记末行之后，返回 [(编号, 项目)] 供提示总装补交接板「需要用户决定」。"""
    reg = root / OPT_REGISTRY
    text = reg.read_text() if reg.is_file() else ''
    lines = text.split('\n')
    have = set(OPT_NUMBERED.findall(text))
    added, rows, batch = [], [], set()
    for s in sheets(state):
        for row in opt_draft_rows((root / s).read_text()):
            row = substitute(row, state)
            number = re.match(r'^\|\s*O-(\d{3})(?!\d)', row)
            if not number or OPT_TOKEN.search(row):
                continue
            if number.group(1) in batch:
                raise RuntimeError('同批优化登记草稿出现重号 O-%s（%s）：每条优化要自己的号，总装手改成不同的号再重跑' % (number.group(1), row.split('|')[2].strip()[:40]))
            batch.add(number.group(1))
            if number.group(1) in have:
                continue          # 登记里已有（中断后接续）
            have.add(number.group(1))
            rows.append(row)
            added.append(('O-' + number.group(1), row.split('|')[2].strip()))
    if rows:
        last = max((i for i, x in enumerate(lines) if re.match(r'^\|\s*O-\d{3}', x)), default=None)
        if last is None:
            raise RuntimeError('优化登记.md 里找不到登记表行，无法追加草稿行')
        lines[last + 1:last + 1] = rows
        reg.write_text('\n'.join(lines))
    return added


def opt_audit(root):
    """收尾自检（tools40）：工程代码（不含 tests）里回退开关 `static var X := true/false` 上方紧挨的注释块里第一个 O-NNN，
    在优化登记里要有行、该行要写到开关名 X（同号指两个开关、登记行写的是别的优化都报）；代码注释里别处提到的 O-NNN 也要登记过。
    返回问题列表。11-01 第七批：O-140 同时标在 FIT_ROWS、TRANSFER_HELP_NEAR 上，登记行却是云裳针眼。"""
    reg = root / OPT_REGISTRY
    rows = {m.group(1): m.group(0) for m in re.finditer(r'^\|\s*O-(\d{3})(?!\d).*$', reg.read_text() if reg.is_file() else '', re.M)}
    problems = []
    for rel in git(root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', str(PROJECT) + '/*.gd').split('\0'):
        f = root / rel
        if not rel or rel.startswith(str(PROJECT / 'tests') + '/') or not f.is_file():
            continue
        lines = f.read_text(errors='replace').split('\n')
        for i, line in enumerate(lines):
            if '#' in line:
                for n in OPT_NUMBERED.findall(line[line.index('#'):]):
                    if n not in rows:
                        problems.append('%s:%d 注释写 O-%s，优化登记没有这一行' % (rel, i + 1, n))
            m = re.match(r'\s*static var (\w+)\s*(?::\s*bool\s*)?:?=\s*(?:true|false)\b', line)
            if not m:
                continue
            j = i
            while j > 0 and lines[j - 1].lstrip().startswith('#'):
                j -= 1
            nums = OPT_NUMBERED.findall('\n'.join(lines[j:i]))
            if nums and nums[0] in rows and m.group(1) not in rows[nums[0]]:
                problems.append('%s:%d 开关 %s 标的是 O-%s，优化登记 O-%s 那行没写这个开关（%s）'
                                % (rel, i + 1, m.group(1), nums[0], nums[0], rows[nums[0]].split('|')[2].strip()[:40]))
    return problems


def is_register(rel):
    return rel in OPT_REGISTERS or bool(re.fullmatch(r'00_项目管理/变更记录[^/]*\.md', rel))


def opt_top_number(root, texts=()):
    """已用的最大优化号：登记文件（交接板、归档、变更记录及其分卷、优化登记）、texts（本条交付单等）、全树 HEAD 里的 O-NNN
    （上一条写进代码注释却没登记的号，下一条不能再发，11-01 云裳又拿到 O-140，tools39；工具源码里的举例不算）。
    assign_opt_numbers 与 number_named 共用（审查 62 P3-1：具名发号原来只看优化登记，会撞号）。"""
    regs = [root / r for r in OPT_REGISTERS] + [root / OPT_REGISTRY] + sorted((root / '00_项目管理').glob('变更记录*.md'))
    top = 0
    for f in regs:
        if f.is_file():
            top = max([top] + [int(n) for n in OPT_NUMBERED.findall(f.read_text(errors='replace'))])
    for t in texts:
        top = max([top] + [int(n) for n in OPT_NUMBERED.findall(t)])
    used = subprocess.run(['git', '-C', str(root), 'grep', '-I', '-h', '-o', '-E', r'O-[0-9]{3,}', 'HEAD', '--', '.',
                           *(':!' + d for d in OPT_SKIP)], capture_output=True, text=True).stdout
    return max([top] + [int(x[2:]) for x in used.split() if len(x) == 5])


NAME_END = set('|｜，,。、；;：:（）()[]【】「」`*"\'')


def replace_named(text, numbers, rows):
    """把 text 里的具名占位按 numbers 换号：每处取从这里起最长的登记首格（rows），它在 numbers 里、且后面紧跟的是
    句末、空白或标点（名字边界）才换。名字互为前缀（「O-待定·A」「O-待定·AB」）、或正文写成「O-待定·A的说明」时不误换（审查 62 P3-2）。"""
    out, i = [], 0
    for m in OPT_TOKEN.finditer(text):
        if m.start() < i or not text.startswith('·', m.end()):
            continue
        hit = next((r for r in rows if text.startswith(r, m.start())), None)
        end = m.start() + len(hit) if hit else None
        if hit in numbers and (end == len(text) or text[end].isspace() or text[end] in NAME_END):
            out.append(text[i:m.start()] + numbers[hit])
            i = end
    return ''.join(out) + text[i:]


def assign_opt_numbers(root, state):
    """本条合并带来的 O-待定[-n] 各换成顺延的 O-NNN：起点＝登记文件（交接板、归档、变更记录及其分卷）与本条文件里已有的最大号 +1，
    同一个占位全合并里换成同一个号，按第一次出现的顺序编号。无占位时返回空表。"""
    texts, tokens = [], []
    for rel in sheets(state):
        f = root / rel
        if f.is_file() and not f.is_symlink():
            texts.append(f.read_text(errors='replace'))
    lane = ['\n'.join(lines) for lines in state.get('optAdded', {}).values()]
    # 交付单正文里讲占位写法本身的字样不是优化（11-01 tools32 一句「都写 O-待定 时」并入变更记录被换成 O-139，tools40）：
    # 只给草稿表行首格的占位发号；车道代码／文档新增行里的占位没有草稿表行就不发号、原样留着，准备阶段提示
    # （合 review-21 时报告正文「建议登记一条 O-待定」被换成 O-143，登记里没有那行、号空了，审查第 23 期 P3-1，tools42）
    real = {m.group(0) for t in texts for row in opt_draft_rows(t) for m in [OPT_TOKEN.fullmatch(row.split('|')[1].strip())] if m}
    texts += lane
    for t in texts:
        for m in OPT_TOKEN.finditer(t):
            if m.group(0) in real and m.group(0) not in tokens:
                tokens.append(m.group(0))
    if not tokens:
        return {}
    # 同一占位在草稿表里对应几条不同优化：每条一个号，不再并成同一个
    rows = {}
    sheet_texts = [(root / rel).read_text(errors='replace') for rel in sheets(state) if (root / rel).is_file()]
    for tok, row, keys in opt_row_entries(sheet_texts):
        rows.setdefault(tok, []).append((row, keys))
    top = opt_top_number(root, texts)
    numbers, ambiguous, keys, n = {}, {}, {}, top
    for tok in tokens:
        if len(rows.get(tok, [])) >= 2:
            entries = [{'number': 'O-%03d' % (n + i + 1), 'row': row, 'keys': keys} for i, (row, keys) in enumerate(rows[tok])]
            n += len(entries)
            # 各条共有的键分不出是哪条，丢掉
            for e in entries:
                e['keys'] = sorted(k for k in e['keys'] if sum(k in o['keys'] for o in entries) == 1)
            ambiguous[tok] = entries
        else:
            n += 1
            numbers[tok] = 'O-%03d' % n
            keys[tok] = sorted(rows[tok][0][1]) if tok in rows else []
    state['optEntries'] = ambiguous
    state['optKeys'] = keys
    # 每条草稿行和它发到的号：代码注释的占位写法和草稿首格对不上时按「位置」列认（tools76）
    state['optRows'] = [dict(token=tok, row=e['row'], keys=sorted(opt_row_keys(e['row'])), number=e['number'])
                        for tok, es in ambiguous.items() for e in es]
    state['optRows'] += [dict(token=tok, row=row, keys=sorted(ks), number=numbers[tok])
                         for tok, lst in rows.items() if tok in numbers for row, ks in lst]
    return numbers


def substitute(text, state, rel=''):
    text = text.replace(VERSION_MARKER, state['version'])
    if rel:
        added = set(state.get('optAdded', {}).get(rel, []))
        if not added:
            return text
        lines = text.split('\n')
        keys = draft_keys(state) if rel.endswith('.md') else None
        out = []
        for i, line in enumerate(lines):
            after = '\n'.join(lines[i + 1:i + 3])
            if line not in added:
                out.append(line)
            elif keys is not None and not keyed(line, keys):
                # 文档（报告、设计说明）新增行讲到占位却不带本批草稿的识别键：多半是「建议登记一条」之类的字样，不换（审查第 23 期 P3-1）
                out.append(substitute_opt(line, unkeyed_state(state)))
            else:
                done = substitute_opt(line, state, after)
                if keys is None and state.get('optRows'):
                    done = substitute_orphans(done, rel, state, comment_context(lines, i), i + 1)
                out.append(done)
        return '\n'.join(out)
    return substitute_opt(text, state)


def substitute_orphans(line, rel, state, after, n):
    """代码行换完号还留着的占位（草稿首格里没有这个写法）：按「位置」列认出唯一那条换成它的号，认不出就停（plan 已先查过）。"""
    rows = state['optRows']
    for tok in orphan_tokens(line, set()):
        hit, cand = pick_by_location(line, rel, rows, after)
        if hit is None:
            raise RuntimeError(orphan_problem(rel, n, line, tok, cand, rows))
        line = re.sub(re.escape(tok) + r'(?!-?\d|·)', hit['number'], line)
    return line


def draft_keys(state):
    return set().union(*(e['keys'] for es in state.get('optEntries', {}).values() for e in es),
                       *state.get('optKeys', {}).values())


def keyed(line, keys):
    return line.lstrip().startswith('|') or any(k in line for k in keys)


def unkeyed_state(state):
    """草稿表来源的占位一个不换（只换版本占位）。"""
    return dict(state, optEntries={}, optNumbers={})


def leftover_opt_hints(root, state):
    """换号后车道新增行里还留着的占位：没有草稿表行或文档行不带识别键，不发号、原样留着。只提示总装，不挡合并。"""
    out = []
    for rel, lines in state.get('optAdded', {}).items():
        f = root / rel
        text = f.read_text(errors='replace') if f.is_file() else ''
        for i, line in enumerate(text.split('\n')):
            if OPT_TOKEN.search(line) and any(OPT_TOKEN.sub('', line) == OPT_TOKEN.sub('', x) for x in lines):
                out.append('%s:%d %s' % (rel, i + 1, line.strip()[:60]))
    return out


def substitute_opt(text, state, after=''):
    if state.get('optEntries'):
        lines = text.split('\n')
        tail = lambda i: '\n'.join(lines[i + 1:i + 3]) if i + 1 < len(lines) else after
        text = '\n'.join(substitute_ambiguous(x, state, tail(i)) for i, x in enumerate(lines))
    for tok, num in state.get('optNumbers', {}).items():
        # 只换整个占位：没发号的 O-待定-1 不能被 O-待定 的号换掉前半
        text = re.sub(re.escape(tok) + r'(?!-?\d|·)', num, text)
    return text


def substitute_body(text, state, sheet_texts):
    """变更记录正文（交付单「变更记录草稿」节）换号：版本占位整段换；优化占位只换表行和带本批草稿识别键的行，
    讲占位写法的字样（「几条都写 O-待定 时」）原样留着（审查第 21 期 P3②，哪吒_42）。只有草稿表行的占位才发号（tools42）。
    正文里引用草稿表占位的行写不出识别键（项目／恢复方法里的标识符或三字以上中文词）就不会被换，准备阶段打印「未换号」提示。"""
    text = text.replace(VERSION_MARKER, state['version'])
    keys = set()
    for _tok, _row, ks in opt_row_entries(sheet_texts):
        keys |= ks
    rest = unkeyed_state(state)
    return '\n'.join(substitute_opt(x, state) if keyed(x, keys) else substitute_opt(x, rest) for x in text.split('\n'))


def gone_sheet(root, state, rel):
    """rel 是不是「main 已归并删除的旧交付单」：plan 记过的，或交付目录下、合并前的 main 上已删掉的（不是本期交付单）。"""
    if rel in state.get('goneSheets', []):
        return True
    if not (rel.startswith('00_项目管理/交付/') and rel.endswith('.md')) or rel in sheets(state):
        return False
    return bool(git(root, 'log', '--diff-filter=D', '--format=%H', '-1', state['base'], '--', rel))


def replace_versions(root, state, state_file):
    if 'versionEdits' not in state:
        state['optNumbers'] = assign_opt_numbers(root, state)
        edits = {}
        for rel in list(state.get('versionPaths', [])):
            path = root / rel
            if not path.exists() and not path.is_symlink() and gone_sheet(root, state, rel):
                # 旧状态文件（tools76 之前 plan 的）或总装手解冲突按删除处理的旧交付单：从 versionPaths 去掉，提示一句
                state['versionPaths'].remove(rel)
                state.get('optAdded', {}).pop(rel, None)
                print('提示：%s 已按删除处理（main 归并过、车道又改），不再替换编号占位' % rel, flush=True)
                continue
            if path.is_symlink() or not path.is_file():
                raise RuntimeError('编号占位文件已改变类型：' + rel)
            before = path.read_bytes()
            after = substitute(before.decode(), state, rel).encode()
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
        after = substitute(current.decode(), state, rel).encode()
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
    if state['branch'].startswith(('claude/review-', 'cc/review-')):
        return '无'
    try:
        sheet = git(root, 'show', state['target'] + ':' + state['delivery'])
    except RuntimeError:
        sheet = ''
    # 只认交付单头部（第一个二级标题之前）的执行者行，正文里引用这句话不算
    head = re.split(r'^## ', sheet, maxsplit=1, flags=re.M)[0]
    if re.search(r'^\W*执行者[:：]\s*(?:Claude|cc)[（(]审查[）)]', head, re.M):
        return '无'
    return '待审查'


## 合并进行中修文件只有一条路：改好留成未提交，重跑同一命令加 --also（准备阶段由工具并进合并提交，准备之后随收尾提交）
FIX_HINT = '在 main 改好后留成未提交改动，重跑同一命令并点名改过的文件：合并车道.sh %s --also <路径>（可重复），工具把它们并进合并提交（合并进行中守卫不收手动 commit／amend）'


def fold_into_merge(root, state, changed, also):
    """准备阶段停下后总装的修正：只收 --also 点名的文件，并进本次的合并提交（父提交不变）。"""
    extra = sorted(changed - set(also))
    if extra:
        raise RuntimeError('合并提交之后有未提交改动：' + '、'.join(extra[:8]) + '；要并进合并提交就' + FIX_HINT % state['task']
                           + '；不是本次修正的先移走')
    parents = git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').split()[1:]
    if parents != [state['base'], state['target']]:
        raise RuntimeError('HEAD 不是本次的合并提交（%s），不改它；先人工核对' % git(root, 'log', '-1', '--format=%h %s'))
    run(root, ['git', 'add', '-A', '--', *sorted(changed)])
    run(root, ['git', 'commit', '--amend', '--no-edit'], env=MAIN_COMMIT_ENV)
    print('已把修正并进合并提交：' + '、'.join(sorted(changed)), flush=True)


def resolve_gone_sheets(root, state):
    """合并冲突只是车道改了 main 已归并删除的旧交付单（modify/delete，plan 记在 goneSheets）：按删除处理、git rm，返回 True 让合并照常提交；
    还有别的冲突返回 False，现场留给总装。"""
    gone = set(state.get('goneSheets', []))
    unmerged = set(git(root, 'diff', '--name-only', '--diff-filter=U').splitlines())
    if not gone or not unmerged or not unmerged <= gone:
        return False
    for p in sorted(unmerged):
        git(root, 'rm', '-q', '--', p)
        print('提示：%s 在 main 已归并删除、车道又改过（modify/delete 冲突），按删除处理；车道补写的内容没并入' % p, flush=True)
    return True


def prepare(root, state, state_file, executor, also=()):
    if state['phase'] != 'planned' and git(root, 'rev-parse', 'HEAD') != state['head']:
        raise RuntimeError('准备过程中 main HEAD 已改变，先人工核对')
    if state['phase'] == 'planned':
        actor = 'cc（唐僧）' if executor == 'cc' else 'Codex（沙僧）'
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
            run(root, ['git', 'commit', *message], env=MAIN_COMMIT_ENV)
        changed = dirty(root)
        committed = git(root, 'rev-parse', 'HEAD') != state['base'] and not subprocess.run(
            ['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode
        if changed and not committed:
            raise RuntimeError('尚有冲突或未提交现场，须先人工处理；未自动回退')
        if changed:
            # 合并已提交、停在冲突标记或解析检查：修正留成未提交改动，重跑时 --also 点名，由工具并进合并提交
            # （合并进行中 main 守卫不收手动 commit／amend，tools29）
            fold_into_merge(root, state, changed, also)
        if git(root, 'rev-parse', 'HEAD') == state['base']:
            try:
                run(root, ['git', 'merge', '--no-ff', state['target'], *message], env=MAIN_COMMIT_ENV)
            except subprocess.CalledProcessError:
                if resolve_gone_sheets(root, state):
                    run(root, ['git', 'commit', *message], env=MAIN_COMMIT_ENV)
                else:
                    raise RuntimeError('合并有冲突，现场保留：解决后 git add，再运行同一命令接续（工具会提交合并）；'
                                       '放弃就 git merge --abort，让车道 git merge main 后重新交付，再运行即按新提交重排')
        elif subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode:
            raise RuntimeError('main 已改变且尚未包含目标车道；请人工核对状态文件')
        else:
            # 唐僧解冲突后自己 git commit 了合并：同样不放行带标记的合并提交
            marked = conflict_markers(root, state['base'] + '..HEAD')
            if marked:
                raise RuntimeError('合并提交里有冲突标记：' + '、'.join(marked) + '；' + FIX_HINT % state['task'])
        if not state.get('noParseCheck'):
            problems = parse_check(root, state['base'])
            if problems:
                shown = problems[:12] + (['……另 %d 条（多是连带错误）' % (len(problems) - 12)] if len(problems) > 12 else [])
                raise RuntimeError('合并后解析检查不通过（还没同步、没跑检查）：\n  ' + '\n  '.join(shown)
                                   + '\n' + FIX_HINT % state['task'] + '；放弃就 合并车道.sh %s --abort' % state['task'])
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
            if os.environ.get('XIYOU_ACCEPT_SOURCE_SWITCH'):  # 换源合并（总装三十 11-07）：同步带 --accept-source-switch <版本>，接受单用 生成接受单.py --grouped 出
                sync += ['--accept-source-switch', os.environ['XIYOU_ACCEPT_SOURCE_SWITCH']]
            cmd = list(map(str, sync + ['--from-worktree', state['worktree']]))
            if state['worktree']:
                print('== ' + ' '.join(cmd), flush=True)
            rc = subprocess.run(cmd, cwd=root).returncode if state['worktree'] else 3  # 无车道工作树：直接完整同步
            if rc == 3:
                # 整份克隆不成时，车道已跑完的事件状态探针结果仍可逐例取回（tools-merge-probe，11-09 seg-a3 两次各 90 分钟整份重量）；
                # XIYOU_STATE_PREV_FROM=0 不传
                if state['worktree'] and os.environ.get('XIYOU_STATE_PREV_FROM', '1') != '0':
                    sync = sync + ['--state-prev-from', state['worktree']]
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
            body = substitute_body(body, state, [(root / x).read_text() for x in sheets(state) if (root / x).is_file()])
            added = append_opt_registry(root, state)
            (root / LOG).write_text(log.rstrip() + '\n\n' + body + '\n\n' + marker + '\n')
            state['optAppended'] = added
            state['optLeftover'] = leftover_opt_hints(root, state) + ['变更记录正文 ' + x.strip()[:60] for x in body.split('\n') if OPT_TOKEN.search(x)]
            save(state_file, state)
        for s in sheets(state):
            (root / s).unlink(missing_ok=True)
        # 归并记录并删除交付单后若进程中断，凭本批标记安全接续，不重复追加或编号。
        state['phase'] = 'prepared'
        save(state_file, state)
    for x in state.get('optLeftover', []):
        print('提示：未换号的优化占位（没有草稿表行，或文档行不带草稿识别键），原样留着：' + x, flush=True)
    for number, name in state.get('optAppended', []):
        print('新优化 %s 已写进优化登记.md；请在交接板「需要用户决定」加一行：- %s %s（默认保留，重制完成后由用户逐条决定）' % (number, number, name), flush=True)
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


def pushed_since(root, base, *commits):
    """GitHub 跟踪分支上有没有 base 之后、又在 commits 任一条历史里的提交（＝本次合并已推上去）。
    不靠 state 里的 mergeCommit：解析检查不过时停在 planned、没记 mergeCommit；推上去后又 amend 的，HEAD 不在远端
    但旧的那版在，所以把 HEAD 和记下的合并提交都拿来比（沙僧第七期 T2）。没有跟踪分支时当没推送。"""
    tracking = 'refs/remotes/github/main'
    if subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', '-q', tracking], capture_output=True).returncode:
        return False
    remote = set(git(root, 'rev-list', tracking, '^' + base).split())
    for c in filter(None, commits):
        if subprocess.run(['git', '-C', str(root), 'cat-file', '-e', c + '^{commit}'], capture_output=True).returncode:
            continue
        if remote & set(git(root, 'rev-list', c, '^' + base).split()):
            return True
    return False


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
    marks = [x.get('mergeCommit') or x.get('head') for x in pending] + [state and state.get('mergeCommit')]
    if pushed_since(root, base, 'HEAD', *marks):
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
    if pushed_since(root, base, 'HEAD', state.get('mergeCommit')):
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


def reuse_note(root):
    """检查.sh 选测时 沿用车道.py 写的「沿用了哪次车道结果」（tools43），收尾提交写成「沿用:」尾注。"""
    return Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'xiyou_reuse_note.txt'


def snapshot_note(root):
    """检查.sh --cloud 把未提交改动做成快照提交时写下的提交号（BK2）；收尾提交后把云端结果过户给收尾提交。"""
    return Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'xiyou_cloud_snapshot'


def adopt_cloud_result(root, snapshot):
    """收尾提交的树与快照一致（或只差版本号、文档）时，快照的云端通过结果过户给它，下一轮选测基准就是它，不再退回很早的云端通过点。失败只提示。"""
    try:
        run(root, [sys.executable, os.environ.get('XIYOU_CLOUD_SCRIPT') or ENV / '云端选测.py', 'adopt', snapshot, 'HEAD'])
    except subprocess.CalledProcessError:
        print('⚠ 云端结果没能过户给收尾提交（不影响收尾）；下一轮选测基准会退到更早的云端通过点', flush=True)
    snapshot_note(root).unlink(missing_ok=True)


def finish(root, state, state_file, executor, batch=False, affected=False, cloud=False):
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
            extra = git(root, 'log', '--format=%h %s（%an，%ad）', '--date=format:%H:%M', state['head'] + '..' + head)
            raise RuntimeError('准备后 main HEAD 已改变（%s → %s）；多出的提交（不是本工具做的）：\n%s\n保留现场。准备之后不要另起提交：总装修测试或别的文件留成未提交改动，'
                               '--finish 时用 --also <路径> 一并带入（00_项目管理/ 下的 .md 用 --accept-doc-edits），修合并带进来的代码也一样；'
                               '已另起提交的，'
                               'git reset --soft %s 退回成未提交改动再 --finish' % (state['head'][:9], head[:9], extra, state['head'][:9]))
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
        allowed = COMMON | {str(OPT_REGISTRY)} | set(sheets(state)) | set(state.get('versionEdits', {})) | set(state.get('also', [])) | uids
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
            env = None
            if cloud:
                check.append('--cloud')
                env = cloud_env(state, *load_batch(state_file.parent))
            reuse_note(root).unlink(missing_ok=True)  # 检查.sh 里 沿用车道.py 会重写；没调到它时不能拿上次的
            try:
                if affected:
                    tool_gate(root)
                run(root, check, env=env)
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
        audit = opt_audit(root)
        if audit:
            raise RuntimeError('优化号自检不通过（代码注释里的 O 号与优化登记对不上），未提交：\n  ' + '\n  '.join(audit[:12])
                               + '\n改好注释或登记后留成未提交，重跑 --finish 加 --also <改过的文件>')
        # 已暂存删除的路径已不在索引里，重复 git add 会报 pathspec 不存在：本批交付单之外，总装 git rm 后 --also 点名的
        # （如分支带来、未标可合并的另一张交付单）也一样（tools39）
        tracked = set(git(root, 'ls-files', '-z').split('\0'))
        remaining = {p for p in changed - set(sheets(state)) if (root / p).exists() or p in tracked}
        if remaining:
            run(root, ['git', 'add', '--', *sorted(remaining)])
        actor = 'cc（唐僧）' if executor == 'cc' else 'Codex（沙僧）'
        trailer = '执行者: ' + actor + '\n核查: ' + review_status(root, state)
        if affected and not batch:
            trailer += '\n验证: 选测（基准 %s，当天全量前算选测已验）' % check[-1 - ('--cloud' in check)][:9]
            note = reuse_note(root)
            reused = note.read_text().strip().splitlines() if note.is_file() else []
            trailer += ''.join('\n沿用: ' + line for line in reused)
        elif not batch:
            trailer += '\n验证: 全量' + ('（云端）' if cloud else '')  # 不加 --affected 的 --finish 跑的是整轮（--cloud 时整轮在云端，tools73）；云端选测.py 的 local_verified_base 认它（tools60，审查 37 P3）
        snapshot = None
        if cloud and not batch:
            note = snapshot_note(root)
            if note.is_file():
                snapshot = note.read_text().strip() or None
        if not batch:
            hand = sorted(p for p in changed if not release_only_path(p))
            if hand:  # 收尾提交里手补的代码：云端选测.py 不把这样的收尾提交当基准，退回合并提交（tools60，审查 37 P2-3）
                trailer += '\n手补: ' + '、'.join(hand)
                if snapshot:   # 手补的代码随快照提交在云端测过：云端选测.py 的基准链可以认这个收尾提交（BK2）
                    trailer += '\n手补已验: 快照 ' + snapshot[:9]
        run(root, ['git', 'commit', '-m', '合并 ' + state['branch'] + '（' + state['version'] + '）收尾', '-m', trailer], env=MAIN_COMMIT_ENV)
        state.update(phase='committed', head=git(root, 'rev-parse', 'HEAD'), batch=batch)
        save(state_file, state)
        if snapshot:
            adopt_cloud_result(root, snapshot)
    folder = state_file.parent
    pending = load_batch(folder)
    if state.get('batch'):
        # 只登记，工作树与推送等本批最后一条通过检查后再做；中断后重跑同一命令不会重复登记。
        if all(x['task'] != state['task'] for x in pending):
            pending.append({k: state.get(k) for k in ['task', 'branch', 'worktree', 'target', 'head', 'base', 'mergeCommit', 'refresh']})
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


def close_batch(root, folder, affected=False, cloud=False):
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
    check = [ENV / '检查.sh', '--oracle'] + (['--affected', pending[0]['base']] if affected else []) + (['--cloud'] if cloud else [])
    try:
        if affected:
            tool_gate(root)
        run(root, check, env=cloud_env(*pending) if cloud else None)
    except subprocess.CalledProcessError:
        report_batch(root, pending[:-1], pending[-1])
        raise
    if dirty(root):
        raise RuntimeError('检查后 main 出现未提交改动，先人工处理：' + '、'.join(sorted(dirty(root))))
    checked = git(root, 'rev-parse', 'HEAD')
    for lane in pending:
        cleanup_lane(root, lane)
    (folder / 'batch.json').unlink()
    print('本批 %d 条收口：检查通过（%s）、工作树已清理。' % (len(pending), '选测' if affected else '全量'), flush=True)
    push_github(root, verified=checked)


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


ANCHOR_REASON = '合并推送后自动'
CLOSE_ANCHOR_REASON = '收口推送后自动'


def anchor_target(root):
    """推送成功后可立云端锚点的收尾提交（tools77）：main 顶上的提交带「验证: 选测／全量」尾注才算（--batch 攒着的、
    --close-batch 收口的没有这行，不立）；手补了代码而没有「手补已验」的不立（tools60：测的是合并提交＋手补，提交本身不当基准）。
    返回 (提交, '')，不立返回 (None, 原因)。"""
    body = git(root, 'log', '-1', '--format=%B', 'refs/heads/main')
    if not re.search(r'^验证: (选测|全量)', body, re.M):
        return None, '收尾提交没有「验证: 选测／全量」尾注'
    if re.search(r'^手补: ', body, re.M) and not re.search(r'^手补已验: ', body, re.M):
        return None, '收尾提交手补了代码、没有「手补已验」'
    return git(root, 'rev-parse', 'refs/heads/main'), ''


def anchor_after_push(root, verified=None):
    """推送成功后给收尾提交立云端锚点（云端选测.py trust <提交> --reason 合并推送后自动），选测基准跟着 main 走，
    不再一直停在很早的云端通过点、每次退成整轮。立失败只警告，不影响推送。
    verified：--close-batch 收口刚检查通过的提交（tools78）。收口前工作区必须干净，手补也都已提交，检查测的就是这个提交本身，
    不看尾注、不排除手补（tools60 防的是 --finish 时手补未提交、云端只测了合并提交）；main 已不是它就不立。"""
    reason = ANCHOR_REASON
    if verified:
        sha, why, reason = verified, '', CLOSE_ANCHOR_REASON
        if git(root, 'rev-parse', 'refs/heads/main') != sha:
            sha, why = None, '收口检查后 main 又有新提交'
    else:
        sha, why = anchor_target(root)
    if not sha:
        print('未立云端锚点：' + why + '。', flush=True)
        return
    script = os.environ.get('XIYOU_CLOUD_SCRIPT') or str(root / ENV / '云端选测.py')
    cmd = [sys.executable, script, 'trust', sha, '--reason', reason]
    try:
        p = subprocess.run(cmd, cwd=root, capture_output=True, text=True, timeout=180,
                           env=dict(os.environ, GIT_TERMINAL_PROMPT='0'))
        error = (p.stderr.strip() or p.stdout.strip() or '退出码 %d' % p.returncode) if p.returncode else ''
    except (OSError, subprocess.TimeoutExpired) as e:
        error = str(e)
    if error:
        print('警告：给收尾提交 %s 立云端锚点失败（推送不受影响；下次选测基准照旧）：%s' % (sha[:9], ' '.join(error.split())[-300:]), flush=True)
    else:
        print('已给收尾提交 %s 立云端锚点（%s）。' % (sha[:9], reason), flush=True)


def push_github(root, remote='github', verified=None):
    """用户 2026-10-18：每次合并后把 main 推到 GitHub。失败只警告，下次合并补推；GitHub 有本地没有的提交时不推。
    推送成功后给够格的收尾提交立云端锚点（anchor_after_push，tools77；verified 见那里，tools78）；没推出去不立。"""
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
        retry_push(lambda: remote_git('push', remote, 'refs/heads/main:refs/heads/main'), label='推 main', out=sys.stdout)
        print('已推送 main 到 ' + remote + '。', flush=True)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print('警告：推送 ' + remote + ' 失败，合并不受影响，下次合并会补推：' + ' '.join(str(error).split()), flush=True)
        return
    anchor_after_push(root, verified)


REVIEW_HEAD = '| 提交 | 执行者 | 内容 | 核查者 |\n| --- | --- | --- | --- |\n'
OPT_ROW_RE = re.compile(r'^- O-\d+ ', re.M)


def new_placeholders(root, base):
    """工程与设计文档里本条合并后新冒出来的 O-待定（与合并前的 main 比，按行内容计数；旧有的原样留着不算）。"""
    paths = [str(PROJECT), str(SUB / '00_设计')]
    def lines(*rev):
        p = subprocess.run(['git', '-C', str(root), 'grep', *([] if rev else ['--untracked']), '-h', '-F', '-e', 'O-待定', *rev, '--', *paths], capture_output=True, text=True)
        return p.stdout.splitlines() if p.returncode == 0 else []
    before = {}
    for x in lines(base):
        before[x] = before.get(x, 0) + 1
    out = []
    for x in lines():
        if before.get(x):
            before[x] -= 1
        else:
            out.append(x.strip())
    return out


def board_add(root, state, who, desc):
    """总装每条都手补的交接板（原 .git/tangseng/lane.sh＋addrow.py，tools78）：「正在进行」表里本车道的行移走；新优化号的「需要用户决定」行
    插到最后一条「- O-NNN 」行后；待核查表首行插「| 分支 | 执行者 | 内容 | 待审查 |」。已有就不重插（重跑同一命令不重复）。"""
    path = root / BOARD
    text = path.read_text()
    lines = text.split('\n')
    # 「正在进行」表里本车道那行（--finish 要求先移走）：表格行提到交付分支或工作树路径就删
    names = [state['branch']] + ([state['worktree']] if state.get('worktree') else [])
    inside, kept = False, []
    for l in lines:
        if l.startswith('## '):
            inside = l.startswith('## 正在进行')
        if inside and l.startswith('|') and any(mentions(l, n) for n in names):
            print('正在进行移走一行：' + l[:80], flush=True)
            continue
        kept.append(l)
    lines = kept
    for number, name in state.get('optAppended', []):
        row = '- %s %s（默认保留，重制完成后由用户逐条决定）' % (number, name)
        if any(l.startswith('- %s ' % number) for l in lines):
            continue
        spots = [i for i, l in enumerate(lines) if OPT_ROW_RE.match(l)]
        if not spots:
            raise RuntimeError('交接板没有「- O-NNN 」行，%s 的「需要用户决定」行不知道插哪，先手补' % number)
        lines.insert(spots[-1] + 1, row)
        print('交接板加一行：' + row, flush=True)
    text = '\n'.join(lines)
    if REVIEW_HEAD not in text:
        raise RuntimeError('交接板找不到待核查表头「| 提交 | 执行者 | 内容 | 核查者 |」，先手补')
    if not re.search(r'^\| %s \|' % re.escape(state['branch']), text, re.M):
        text = text.replace(REVIEW_HEAD, REVIEW_HEAD + '| %s | %s | %s | 待审查 |\n' % (state['branch'], who, desc), 1)
        print('待核查加一行：' + state['branch'], flush=True)
    path.write_text(text)


def lane_one(root, task, branch, who, desc, executor, prep_extra=(), finish_extra=()):
    """--lane：准备→查新冒出来的 O-待定→补交接板（board_add）→--finish --batch，一步做完；哪步停下就停在那，修好后重跑同一命令接着做。
    prep_extra／finish_extra：转给准备／收尾那一步的参数（--also、--accept-changes、--no-parse-check／--also、--accept-doc-edits）。"""
    if '|' in who + desc or '\n' in who + desc:
        raise RuntimeError('--who／--desc 里不能有「|」或换行（会弄坏交接板的表）')
    base_args = [task, '--root', str(root), '--executor', executor] + (['--branch', branch] if branch else [])
    folder = Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'lane-merge'
    state_file = folder / 'state.json'
    state = json.loads(state_file.read_text()) if state_file.exists() else None
    if not (state and state.get('task') == task and state.get('phase') == 'prepared'):
        if main(base_args + list(prep_extra)):
            raise RuntimeError('%s 准备没过（见上），修好后重跑同一条 --lane' % task)
        state = json.loads(state_file.read_text())
    if state.get('phase') != 'prepared':
        raise RuntimeError('%s 没走到「已准备合并」（阶段 %s）' % (task, state.get('phase')))
    # 只拦工程与设计文档里新冒出来的（总装原 lane.sh 的 git grep）；optLeftover 里变更记录正文讲占位写法的字样可以原样留（准备时已打提示）
    left = new_placeholders(root, state['base'])
    # 写成「O-待定·名字」、优化登记里已有同名行的（车道直接写进登记表的）放行，与交付单检查（opt_tokens_registered）同一规则；
    # 11-07 八戒「O-待定·升级文字」在代码与对照基线说明里被拦，总装手编 O-236（tools-merge-args4）
    reg = root / OPT_REGISTRY
    registry = reg.read_text() if reg.is_file() else ''
    passed = [x for x in left if opt_tokens_registered(x, registry)]
    for x in passed:
        print('放行（优化登记已有同名行）：' + x[:80], flush=True)
    left = [x for x in left if x not in passed]
    if left:
        named = sorted({t for x in left for t in unregistered_named(x, registry) if '·' in t})
        if named:
            left.append('（带名字的占位要与优化登记首格逐字相同、含空格才放行，没对上的：%s）' % '、'.join(named[:8]))
        raise RuntimeError('%s 留了没换号的 O-待定，先手改再重跑：\n  ' % task + '\n  '.join(left[:12]))
    added, changed = number_named(root, state['base'], state, state_file)   # 发号计划存进 state，重跑照计划接着换（不重复记 optAppended）
    if added:
        finish_extra = list(finish_extra) + sum((['--also', x] for x in changed if x not in state.get('versionEdits', {})), [])
    board_add(root, state, who, desc)
    if main(base_args + ['--finish', '--batch'] + list(finish_extra)):
        raise RuntimeError('%s --finish --batch 没过（见上），修好后重跑同一条 --lane' % task)


def queue_items(spec, branches, whos, descs):
    """--queue a,b,c：每条的 --who／--desc（各给一个＝全队同用，或按顺序每条一个）；分支写成「任务=分支」，不写照 --branch（只一条时）或默认。"""
    tasks = [x.strip() for x in spec.split(',') if x.strip()]
    if not tasks:
        raise RuntimeError('--queue 没给任务')
    def spread(values, name, sep):
        if len(values) == 1 and len(tasks) > 1 and sep in values[0]:
            # 三十一 11-07：--who "a,b,c,d" 被当成一条，四行待核查都写成同一串。--who 按英文逗号拆；--desc 正文常带英文逗号，
            # 按「｜」拆（审查 57 P3-1：全队同用的 --desc 逗号数碰巧等于条数−1 时会被悄悄拆开）。段数要等于条数
            parts = [x.strip() for x in values[0].split(sep)]
            if len(parts) != len(tasks) or not all(parts):
                raise RuntimeError('%s 「%s」按「%s」拆成 %d 段，与 --queue 的 %d 条对不上；要每条一个就按条数用「%s」分隔（或重复写 %s），'
                                   '全队同用的不要带「%s」' % (name, values[0], sep, len(parts), len(tasks), sep, name, sep))
            print('%s 按「%s」拆成每条一个：%s' % (name, sep, ' / '.join(parts)), flush=True)
            return parts
        if len(values) == 1:
            return values * len(tasks)
        if len(values) != len(tasks):
            raise RuntimeError('%s 要给 1 个或 %d 个（与 --queue 条数相同），现在 %d 个' % (name, len(tasks), len(values)))
        return values
    out = []
    for t, w, d in zip(tasks, spread(whos, '--who', ','), spread(descs, '--desc', '｜')):
        task, _, br = t.partition('=')
        out.append((task, br or None, w, d))
    if branches:
        raise RuntimeError('--queue 时分支写成「任务=分支」，不用 --branch')
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('task', nargs='?')
    ap.add_argument('--lane', metavar='任务',
                    help='一步合一条（tools78，原总装 lane.sh）：准备→查新冒出来的 O-待定→交接板补「需要用户决定」O 行与待核查行→--finish --batch；'
                         '配 --who（执行者，如 cc（哪吒））、--desc（待核查表「内容」），可加 --branch')
    ap.add_argument('--queue', metavar='a,b,c',
                    help='按顺序逐条 --lane，全部过了再自动 --close-batch（可加 --affected、--cloud、--no-parse-check）；分支写「任务=分支」；'
                         '--who／--desc 给一个全队同用，或按顺序每条一个；本批已有攒着的也一并收口。--also、--accept-changes、--accept-doc-edits 只对一条：'
                         '停在哪条就用 --lane <那条> 带上它们修好合完，再重跑同一条 --queue（已攒进本批的跳过）')
    ap.add_argument('--who', action='append', default=[],
                    help='--lane／--queue：待核查表的执行者。--queue 时给一个全队同用，或每条一个：重复写 --who，或一个值里用英文逗号「,」分隔（段数＝条数）')
    ap.add_argument('--desc', action='append', default=[],
                    help='--lane／--queue：待核查表的内容。--queue 时给一个全队同用，或每条一个：重复写 --desc，或一个值里用「｜」分隔（段数＝条数；英文逗号不拆）')
    ap.add_argument('--root', type=Path, help='主工作区；默认从当前工具所属资料库定位')
    modes = ap.add_mutually_exclusive_group()
    modes.add_argument('--dry-run', action='store_true')
    modes.add_argument('--finish', action='store_true')
    ap.add_argument('--executor', choices=['cc', 'Claude', 'Codex'], default='cc',
                    help='执行者；Claude 是 cc 的旧写法（Kyo 10-31 改叫 cc），两者等价，写进提交尾注的都是 cc')
    modes.add_argument('--close-batch', action='store_true',
                       help='本批都 --finish --batch 收尾后、没有新车道要合时：统一跑 检查.sh --oracle（可加 --affected），通过后清理本批工作树、推送')
    modes.add_argument('--abort', action='store_true',
                       help='单条合并要撤出 main 时：存备份后退回本条合并前的 main，撤掉本次同步写出的产物与同步基线，删 state.json；车道工作树保留')
    modes.add_argument('--abort-batch', action='store_true',
                       help='本批最后的检查失败、要撤出某条车道时：存备份后退回本批开始前的 main，车道工作树都保留')
    ap.add_argument('--batch', action='store_true',
                    help='--finish 时本条先不跑检查、不清理、不推送，记入本批；最后一条不加它统一检查')
    ap.add_argument('--branch', help='车道分支（任务名仍写交付单名）：app 自建的工作树常把车道建在 cc/<随机名> 上，名字与派单的 <前缀>/<任务> 对不上时用')
    ap.add_argument('--cloud', action='store_true',
                    help='--finish 或 --close-batch 时：Godot 场景交给 GitHub Actions 云端跑（云端选测.py run＋wait）；加 --affected 跑选中的场景，'
                         '不加则跑整轮（run --full，尾注「验证: 全量（云端）」，tools73）；非 Godot 检查仍在本机；云端不可用时明确失败，不静默改本机（账单／额度没启动任务时 检查.sh 改本机跑）')
    ap.add_argument('--affected', action='store_true',
                    help='--finish 时只跑选测（检查.sh --oracle --affected <本次合并前的 main>），通过后照常提交、清理、推送；不和 --batch 同用')
    ap.add_argument('--accept-changes', action='append', default=[], metavar='接受单',
                    help='同步因测量改变被拒后：把接受单记进本次合并状态再接着同步（不用手改 state.json），可重复')
    ap.add_argument('--accept-doc-edits', action='store_true',
                    help='--finish 时把总装在 main 手修的文档（只限 00_项目管理/ 下的 .md，交付单除外）一并暂存；默认拒收')
    ap.add_argument('--no-parse-check', action='store_true',
                    help='准备阶段跳过合并后的快速解析检查（只管本次运行；检查卡住或误报、确认无误时用）')
    ap.add_argument('--also', action='append', default=[], metavar='路径',
                    help='--finish 时一并提交的额外改动（如要删的另一张交付单、顺带改的规则、修好的代码）；准备阶段停在冲突标记或解析检查时，'
                         '重跑同一命令加它点名修正的文件，工具并进合并提交。可重复')
    a = ap.parse_args(argv)
    a.executor = 'cc' if a.executor == 'Claude' else a.executor
    root = a.root or Path(git(Path(__file__).parent, 'rev-parse', '--path-format=absolute', '--git-common-dir')).parent
    root = root.resolve()
    lock = None
    try:
        if git(root, 'branch', '--show-current') != 'main':
            raise RuntimeError('只能操作 main 主工作区')
        folder = Path(git(root, 'rev-parse', '--path-format=absolute', '--git-dir')) / 'lane-merge'
        state_file = folder / 'state.json'
        if a.lane or a.queue:
            if a.task or a.finish or a.batch or a.close_batch or a.dry_run or a.abort or a.abort_batch or (a.lane and a.queue):
                raise RuntimeError('--lane／--queue 不带任务名，不和 --finish、--batch、--close-batch、--dry-run、--abort 同用，两者也不同用')
            prep_extra = sum((['--also', x] for x in a.also), []) + sum((['--accept-changes', x] for x in a.accept_changes), []) \
                + (['--no-parse-check'] if a.no_parse_check else [])
            finish_extra = sum((['--also', x] for x in a.also), []) + (['--accept-doc-edits'] if a.accept_doc_edits else [])
            if a.lane:
                if len(a.who) != 1 or len(a.desc) != 1:
                    raise RuntimeError('--lane 要各给一个 --who、--desc')
                if a.affected or a.cloud:
                    raise RuntimeError('--lane 只攒进本批（--finish --batch）；--affected、--cloud 给收口用（--queue 或 --close-batch）')
                lane_one(root, a.lane, a.branch, a.who[0], a.desc[0], a.executor, prep_extra, finish_extra)
                print('%s 已合并并攒进本批；没有别的要合时运行 --close-batch。' % a.lane, flush=True)
                return 0
            if a.also or a.accept_changes or a.accept_doc_edits:
                # 原来 --queue 收了 --also 不报错也不转，修好的文件没提交、下一步照样停（三十一 11-07）
                raise RuntimeError('--also、--accept-changes、--accept-doc-edits 只对一条：停在哪条就用 --lane <那条> 带上它们修好合完，'
                                   '再重跑同一条 --queue（已攒进本批的跳过）')
            items = queue_items(a.queue, [a.branch] if a.branch else [], a.who, a.desc)
            done = {x['task'] for x in load_batch(folder)}
            for task, branch, who, desc in items:
                if task in done:   # 上次 --queue 中途停下：已攒进本批的那几条不再合（重跑同一条命令接着做）
                    print('== %s 已在本批，跳过' % task, flush=True)
                    continue
                print('== 串合 %s' % task, flush=True)
                lane_one(root, task, branch, who, desc, a.executor, ['--no-parse-check'] if a.no_parse_check else [])
            lock = take_lock(folder)
            close_batch(root, folder, a.affected, a.cloud)
            return 0
        if a.who or a.desc:
            raise RuntimeError('--who、--desc 只配 --lane／--queue')
        if a.close_batch:
            if a.task or a.batch:
                raise RuntimeError('--close-batch 不带任务名、不配 --batch')
            lock = take_lock(folder)
            close_batch(root, folder, a.affected, a.cloud)
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
        if a.cloud and not (a.finish or a.close_batch):
            raise RuntimeError('--cloud 只和 --finish 或 --close-batch 一起用')
        if a.cloud and a.batch:
            raise RuntimeError('--cloud 不配 --batch（--batch 本条不跑检查；批末那条再加 --cloud）')
        if a.accept_doc_edits and not a.finish:
            raise RuntimeError('--accept-doc-edits 只和 --finish 一起用')
        if a.accept_changes and (a.finish or a.dry_run):
            raise RuntimeError('--accept-changes 只用于准备阶段接着同步（不配 --finish、--dry-run）')
        if a.dry_run:
            print(json.dumps(plan(root, a.task, a.branch), ensure_ascii=False, indent=2)); return 0
        lock = take_lock(folder)
        state = json.loads(state_file.read_text()) if state_file.exists() else None
        if state and state['task'] != a.task:
            raise RuntimeError('另一条车道尚未收尾：' + state['task'])
        if (state and state['phase'] == 'planned' and merge_head(root) is None
                and subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', state['target'], 'HEAD']).returncode):
            # 还没合进来（放弃了冲突合并、车道重新交付，或 main 又前进）：按车道与 main 的现状重新计划。
            executor = 'cc' if state.get('executor', a.executor) == 'Claude' else state.get('executor', a.executor)
            state = plan(root, a.task, a.branch)
            state['executor'] = executor
            save(state_file, state)
        if state is None:
            if a.finish or a.accept_changes:
                raise RuntimeError('没有准备中的合并')
            state = plan(root, a.task, a.branch)
            state['executor'] = a.executor
            save(state_file, state)
        elif ('cc' if state.get('executor', a.executor) == 'Claude' else state.get('executor', a.executor)) != a.executor:
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
            finish(root, state, state_file, a.executor, a.batch, a.affected, a.cloud)
        else:
            pending = load_batch(folder)
            if pending and not any(x['task'] == a.task for x in pending):
                print('提示：本批已有 %d 条收尾未检查（%s）；这条可 --finish --batch 继续攒，或直接 --finish 统一检查。'
                      % (len(pending), '、'.join(x['task'] for x in pending)), flush=True)
            prepare(root, state, state_file, a.executor, a.also)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, KeyError, IndexError) as error:
        print('合并已停止，现场保留：' + str(error), file=sys.stderr)
        return 1
    finally:
        if lock is not None:  # 只删自己拿到的锁（拿锁失败时 lock 仍是 None）
            lock.unlink(missing_ok=True)


if __name__ == '__main__':
    raise SystemExit(main())
