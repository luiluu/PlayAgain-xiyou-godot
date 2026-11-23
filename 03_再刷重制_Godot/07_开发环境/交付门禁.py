#!/usr/bin/env python3
"""交付自检的内容门禁（T403，Kyo 11-22 事项 32 答「6 条全做」；依据 T400 返工复盘第二、三节）。被 交付自检.py 引用，不单独跑。

每项都只看「分支相对 main 分叉点」的改动和已提交的交付单，不改任何文件：
  ① 发行空壳 check（本工作树里才跑；改了 01_Godot工程 的 .gd 才查）：不过就要补 发行空壳特例.json
  ② 交付单要有云端 run 链接或「没跑云端」（改了工程 .gd 才要）；交付单里列的截图文件都在分支里；
     新增／改动的启动脚本（.sh/.py/.yml 里的 godot 命令行）要带 --audio-driver Dummy
  ③ 新增测试行里不准有 or true、assert(true) 一类恒真断言；文件名带 20x9／16x9 的截图核实际宽高比；同一目录里新增的截图 MD5 不能相同
  ④ 改了 core/、battle/、skin/ 下已有函数：列出调用方数量，提醒交付单写「调用方 N 处逐处结论」（只提醒，不拦）
误伤处理：不想让某一行被查，在那一行末尾写「门禁豁免」四个字（注释里写，要写理由）；整项都不适用就在交付单里写明原因。
"""
import hashlib
from pathlib import Path
import re
import struct
import subprocess

ENGINE = '03_再刷重制_Godot/01_Godot工程/'
SHEET_DIR = '00_项目管理/交付/'
EXEMPT = '门禁豁免'
IMG_EXT = ('.png', '.jpg', '.jpeg', '.gif')
LAUNCH_EXT = ('.sh', '.py', '.yml', '.yaml', '.command', '.bat', '.cmd')
RUN_LINK = re.compile(r'github\.com/[^\s)）]+/actions/runs/\d+|actions/runs/\d+|\bgh run\b.{0,20}\d{8,}|(?:run|运行)\s*(?:id|号)?\s*[#：: ]?\s*\d{8,}', re.I)
NO_CLOUD = re.compile(r'没跑云端|未跑云端|没有跑云端')
# 路径前必须是行首或分隔符（空白、反引号、引号、括号、冒号、逗号），路径里不含括号：「截图（a/b.png）」只取括号里的
IMG_REF = re.compile(r'(?:^|(?<=[\s`\'"(（\[【:：,，、]))([\w./\-一-龥]+\.(?:png|jpe?g|gif))', re.I | re.M)
SHOT_DIRS = ('00_项目管理/归档/交付截图/',)   # 同目录 MD5 只管交付截图目录；美术素材（01_Godot工程 下的精灵帧等）常有合法的同内容文件
TRUTHY = [(re.compile(r'\bor\s+true\b', re.I), 'or true'), (re.compile(r'\bassert\(\s*true\s*[,)]', re.I), 'assert(true)'),
          (re.compile(r'\bassertTrue\(\s*True\s*\)'), 'assertTrue(True)')]
RATIO_NAME = re.compile(r'(?<![\dx])(\d{1,2})[x×](\d{1,2})(?![\dx])', re.I)
LAUNCH_HINT = re.compile(r'--headless|--path\b|--script\b|--quit\b|--import\b|\s-s\s|res://')
CALLER_DIRS = ('/core/', '/battle/', '/skin/')
CALLER_NOTE = re.compile(r'调用方\s*\d+\s*处[^|\n]{0,16}逐处')   # 要真实数字：README 模板表头「调用方 N 处」不算
SKIP_FUNCS = {'_init', '_ready', '_process', '_physics_process', '_draw', '_input', '_unhandled_input', '_enter_tree', '_exit_tree', '_notification'}
FUNC_DEF = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\(')


def run(root, *args, binary=False):
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', *args], capture_output=True)
    out = p.stdout if binary else p.stdout.decode('utf-8', 'replace')
    return p.returncode, out if binary else out.strip('\n')


def changed(root, fork, target, filt='AM'):
    return [x for x in run(root, 'diff', '--name-only', '--diff-filter=' + filt, fork, target)[1].splitlines() if x]


def added_lines(root, fork, target, path):
    """新文件内容里被分支新增的 (行号, 文本)。"""
    out = run(root, 'diff', '-U0', fork, target, '--', path)[1]
    rows, no = [], 0
    for ln in out.splitlines():
        m = re.match(r'@@ -\S+ \+(\d+)', ln)
        if m:
            no = int(m.group(1))
        elif ln.startswith('+') and not ln.startswith('+++'):
            rows.append((no, ln[1:]))
            no += 1
    return rows


def file_text(root, ref, path):
    rc, out = run(root, 'show', '%s:%s' % (ref, path))
    return out if rc == 0 else ''


# ---------- ①② 交付单与启动脚本 ----------

def shell_check(root, wt):
    """发行空壳 check：在本工作树里跑，不过返回问题文字。"""
    script = Path(wt) / '03_再刷重制_Godot/07_开发环境/发行空壳.py'
    if not script.is_file():
        return None, '本工作树里没有 发行空壳.py，没跑发行空壳 check'
    p = subprocess.run(['python3', str(script), 'check'], capture_output=True, text=True, cwd=str(wt))
    if p.returncode == 0:
        return True, ''
    tail = '\n'.join((p.stdout + p.stderr).strip().splitlines()[-8:])
    return False, ('发行空壳 check 不过（退出码 %d）：西游代码用到了天启篇脚本里发行空壳没有的成员。补 03_再刷重制_Godot/07_开发环境/发行空壳特例.json'
                   '（只写天启篇关着时真脚本在西游存档上的结果，不写数值和文字；不确定就进「已确认放行」前先 ask）。输出末尾：\n%s' % (p.returncode, tail))


def sheet_checks(root, target, sheet_text, engine_gd, problems):
    if engine_gd and not (RUN_LINK.search(sheet_text) or NO_CLOUD.search(sheet_text)):
        problems.append('交付单没有云端选测 run 链接，也没写「没跑云端」：把 gh run 的链接（…/actions/runs/数字）贴进交付单，'
                        '真没跑就明写「没跑云端」和原因（改了工程脚本才要求）')
    seen = set()
    for m in IMG_REF.finditer(sheet_text):
        ref = m.group(1)
        if ref in seen or ref.startswith(('http', '/')):
            continue
        seen.add(ref)
        bare = ref.lstrip('./')
        cands = [ref, bare, '03_再刷重制_Godot/' + bare, ENGINE + bare]
        lead = re.sub(r'^[一-龥]+(?=[A-Za-z0-9_])', '', bare)      # 「如图00_项目管理/…」中文前缀直接连着路径
        if lead != bare:
            cands += [lead, '03_再刷重制_Godot/' + lead, ENGINE + lead]
        if not any(run(root, 'cat-file', '-e', '%s:%s' % (target, c))[0] == 0 for c in cands):
            # 只在交付单明显把它当仓内文件（带目录）时算数，纯文件名没法定位的不拦
            if '/' in ref:
                problems.append('交付单列的截图 %s 不在分支提交里（没 git add，或路径写错）' % ref)


def docstring_lines(lines):
    """Python 文件里落在三引号字符串里的行号（1 起，含开合引号所在行）。"""
    inside, out = None, set()
    for i, ln in enumerate(lines, 1):
        if inside:
            out.add(i)
        for m in re.finditer(r'"""|\'\'\'', ln):
            if inside is None:
                inside = m.group()
                out.add(i)
            elif m.group() == inside:
                inside = None
                out.add(i)
    return out


def launch_checks(root, fork, target, files, problems):
    for path in files:
        if not path.endswith(LAUNCH_EXT):
            continue
        new = {no for no, _ in added_lines(root, fork, target, path)}
        if not new:
            continue
        lines = file_text(root, target, path).splitlines()
        doc = docstring_lines(lines) if path.endswith('.py') else set()
        for no in sorted(new):
            ln = lines[no - 1] if no - 1 < len(lines) else ''
            head = ln.lstrip()
            if no in doc or head.startswith(('#', 'echo ', 'echo\t', 'print(', '//')):
                continue                              # 注释、文档串、日志输出不是启动命令
            if EXEMPT in ln or not re.search(r'godot', ln, re.I) or not LAUNCH_HINT.search(ln):
                continue
            window = '\n'.join(lines[max(0, no - 6):no + 5])
            if 'audio-driver' not in window.lower():
                problems.append('%s:%d 起 Godot 没带 --audio-driver Dummy（Kyo 11-17「测试不要开声音」）：命令行加上；确属例外在行尾写「%s」＋理由' % (path, no, EXEMPT))


# ---------- ③ 新增测试与截图 ----------

def is_test(path):
    name = Path(path).name
    return ('/tests/' in '/' + path or name.startswith(('test_', '测试')) or name.endswith(('_test.gd', '_test.py'))) and path.endswith(('.gd', '.py'))


def test_checks(root, fork, target, files, problems):
    for path in files:
        if not is_test(path):
            continue
        for no, ln in added_lines(root, fork, target, path):
            if EXEMPT in ln or ln.lstrip().startswith('#'):
                continue
            for rx, label in TRUTHY:
                if rx.search(ln):
                    problems.append('%s:%d 新增测试里有恒真断言（%s）：这样的测试什么都挡不住，改成真断言；确属例外在行尾写「%s」＋理由' % (path, no, label, EXEMPT))
                    break


def image_size(data):
    if data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) >= 24:
        return struct.unpack('>II', data[16:24])
    if data[:6] in (b'GIF87a', b'GIF89a') and len(data) >= 10:
        return struct.unpack('<HH', data[6:10])
    if data[:2] == b'\xff\xd8':
        i = 2
        while i + 9 < len(data):
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            seg = struct.unpack('>H', data[i + 2:i + 4])[0]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                h, w = struct.unpack('>HH', data[i + 5:i + 9])
                return w, h
            i += 2 + seg
    return None


def image_checks(root, fork, target, files, problems, sheet_text=''):
    exempt_names = {n for ln in sheet_text.splitlines() if EXEMPT in ln for n in re.findall(r'[\w.\-一-龥]+\.(?:png|jpe?g|gif)', ln, re.I)}
    groups = {}
    for path in files:
        if not path.lower().endswith(IMG_EXT):
            continue
        rc, data = run(root, 'show', '%s:%s' % (target, path), binary=True)
        if rc:
            continue
        m = RATIO_NAME.search(Path(path).stem)
        if m and int(m.group(2)) and int(m.group(1)) > int(m.group(2)):
            size = image_size(data)
            if size and size[1]:
                want, got = int(m.group(1)) / int(m.group(2)), size[0] / size[1]
                if abs(got - want) / want > 0.03:
                    problems.append('截图 %s 名字写 %sx%s（%.2f），实际 %dx%d（%.2f）：宽高比对不上，重截或改名'
                                    % (path, m.group(1), m.group(2), want, size[0], size[1], got))
        if path.startswith(SHOT_DIRS) and Path(path).name not in exempt_names:
            groups.setdefault(str(Path(path).parent), []).append((path, hashlib.md5(data).hexdigest()))
    for folder, rows in groups.items():
        by = {}
        for path, md5 in rows:
            by.setdefault(md5, []).append(path)
        for md5, paths in by.items():
            if len(paths) > 1:
                problems.append('交付截图目录里新增的截图内容完全相同（MD5 %s…）：%s。多半是同一张图存了几次，没截到不同的画面；确属例外在交付单写一行「门禁豁免：文件名＋理由」' % (md5[:8], '、'.join(Path(p).name for p in paths)))


# ---------- ④ 调用方提醒 ----------

def func_bodies(text):
    """{函数名: 函数体文本}：从 func 行到下一个顶格语句（顶格的 func／var／class 等）之前。"""
    out, cur, buf = {}, None, []
    for ln in text.splitlines():
        m = FUNC_DEF.match(ln) if not ln[:1].isspace() else None
        if m or (ln[:1] not in ('', ' ', '\t', '#') and not ln.startswith('@')):
            if cur:
                out[cur] = '\n'.join(buf).rstrip()
            cur, buf = (m.group(1) if m else None), [ln]
        elif cur:
            buf.append(ln)
    if cur:
        out[cur] = '\n'.join(buf).rstrip()
    return out


def changed_funcs(root, fork, target, path):
    """分叉点上就存在、分支里函数体或签名有变（含删除）的函数名。"""
    old, new = func_bodies(file_text(root, fork, path)), func_bodies(file_text(root, target, path))
    return sorted(n for n, body in old.items() if n not in SKIP_FUNCS and new.get(n) != body)


def caller_notes(root, fork, target, files, sheet_text):
    hits = {}
    for path in files:
        if not path.startswith(ENGINE) or not path.endswith('.gd') or not any(d in path for d in CALLER_DIRS):
            continue
        for fn in changed_funcs(root, fork, target, path):
            rc, out = run(root, 'grep', '-n', '-E', r'(^|[^[:alnum:]_])' + fn + r'[[:space:]]*\(', target, '--', ENGINE + '*.gd')
            n = 0
            for ln in out.splitlines() if rc == 0 else []:
                body = ln.split(':', 3)[-1]
                if not FUNC_DEF.match(body):
                    n += 1
            hits['%s:%s' % (Path(path).name, fn)] = n
    if not hits:
        return []
    top = sorted(hits.items(), key=lambda kv: -kv[1])[:12]
    note = ('改了 core/battle/skin 下 %d 个已有函数，按函数名粗数的调用处（同名的别的类也算，常见名会偏多，逐处核时以实际为准）：%s。交付单请写「调用方 N 处逐处结论」，逐处说清没被改坏'
            % (len(hits), '；'.join('%s %d 处' % kv for kv in top)))
    if CALLER_NOTE.search(sheet_text):
        return ['改了 core/battle/skin 下 %d 个已有函数，交付单已写调用方逐处结论' % len(hits)]
    return [note]


def gates(root, fork, target, sheet_text, wt=None):
    """返回 (问题列表, 提示列表)。wt 给了（本工作树）才跑发行空壳 check。"""
    problems, hints = [], []
    files = changed(root, fork, target)
    engine_gd = any(f.startswith(ENGINE) and f.endswith('.gd') for f in files)
    if engine_gd:
        if wt:
            ok, msg = shell_check(root, wt)
            if ok is False:
                problems.append(msg)
            elif ok is None:
                hints.append(msg)
        else:
            hints.append('不在本工作树里，没跑发行空壳 check；回执前请在车道工作树里跑一次')
    sheet_checks(root, target, sheet_text, engine_gd, problems)
    launch_checks(root, fork, target, files, problems)
    test_checks(root, fork, target, files, problems)
    image_checks(root, fork, target, files, problems, sheet_text)
    hints += caller_notes(root, fork, target, files, sheet_text)
    return problems, hints
