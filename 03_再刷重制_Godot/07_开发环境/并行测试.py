#!/usr/bin/env python3
"""并行运行 Godot 测试场景（检查.sh 调用；也可单独用来跑几个专项）。

用法：并行测试.py <godot> <工程目录> [--jobs N] [--full] [场景名或前缀 ...]
- 每个测试一个独立的临时 HOME，因此 user://（存档、配置）互不干扰，也不会读写本机真实的用户数据目录。
- 导入（--import）由调用方先单独做一次；这里只读工程缓存。
- 每个测试最多 600 秒；脚本语法错误时场景不会自行退出，超时即判失败。用时超过一半（300 秒）时提示拆场景。
- 并行时只有少数（≤3）测试失败的，逐个单独重跑一次：单跑通过记为「偶发」，仍算通过但打印 ⚠，写进交付单；单跑仍失败才判失败。
  首次与重跑的输出、退出码、耗时分别保留（日志 <场景>.log 与 <场景>.rerun1.log、test_timings.json 的 attempts），
  每次偶发另追加到共用状态目录的 flaky.jsonl，多次偶发可对账。
- 输出与原来逐个运行时相同（按场景名排序），失败时返回 1。
- 并行数：CHECK_JOBS 或 --jobs；都没给时主工作区用 CPU 核数一半（最多 6），worktree 里只用 2（多会话并行时给其他车道留余量）。
- 派发顺序：按上次实测耗时从慢到快（没有记录的排最前，当作最慢），免得最慢的场景压到队尾。
- 所有工作树共用一个并发上限（CHECK_GLOBAL_JOBS，默认 CPU 核数一半、最多 6）：每个测试先在共用状态目录里占一个槽位
  （flock，进程退出即释放），几条车道同时跑检查也不会把机器压到超时。同步正式西游.py 的 node 探针占同一组槽位。等槽位的时间不计入 600 秒。
- 沿用上轮结果（不指定场景的整轮运行，或指定场景时加 --reuse，检查.sh 选测用）：工程指纹与上次记录相同时，
  上次通过的场景沿用、只重跑上次失败的和没跑过的。同一指纹的记录跨整轮与选测合并（选测后再整轮只补跑没跑过的）。
  指纹 = 工程目录下除 .godot/ 外每个文件的路径与内容 SHA-256（跟随软链接，含未入 Git 的 generated/ 转换与参照数据）
  ＋ Godot 可执行文件的真实路径、大小、修改时间与 --version ＋ 本脚本内容 ＋ 超时上限。任何一项变了就整轮重跑；
  读不到、解析不了上次记录也整轮重跑。--full 或 CHECK_FULL=1 强制整轮。
  环境里设了 RULES_ONLY_TROOPS／RULES_ONLY_ACTORS（xiyou_rules 编号过滤，非 part0 只记 1 项）时不读也不写沿用记录，
  免得过滤结果在清环境后被普通沿用当作整份通过。
  沿用前逐条严格校验（reusable_results）：记录须是对象、场景都在当前场景表里、每条只含布尔 passed 与字符串 line；
  passed 为真的那条 line 还要用 result_ok 复核（passed＝total＞0）。任一条结构不对或自相矛盾，整份当作没有记录、整轮重跑。
- 心跳：批测与排槽期间每 XIYOU_TEST_HEARTBEAT 秒（默认 300，0 关闭）打印一行进度（完成数、等槽数、在跑的场景），
  免得长任务.py 的无输出看门狗（默认 3600 秒）把仍在推进的批测判成卡住；不放宽看门狗、不改并发。
- 日志：--log-dir（或 CHECK_LOG_DIR）没给时写到 <工程上一级>/04_验证/本地结果/并行测试/<时间戳>/（只留最近 LOGS_KEEP 份），
  每个场景一份 <场景>.log，结尾打印目录；失败的场景另打印它的完整日志路径（八戒期二、期三：明细只在屏幕上 8 行，
  管道给 tail 时看不全，曾多花一轮 50 分钟重跑）。--quiet：不打心跳与通过行，只打失败、偶发、提示与汇总。
- 共用状态目录：XIYOU_TEST_STATE_DIR，否则 <git-common-dir>/xiyou_test_state（主工作区与各 worktree 共用），不在 Git 里时用系统临时目录。
"""
import argparse
import concurrent.futures as cf
import contextlib
import datetime
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

TIMEOUT = 600  # xiyou_rules 角色 P0 后单跑约 200 秒，满负载并行时超过 300
SLOW = TIMEOUT // 2  # 超过就提示按场景拆分（xiyou_rules、smart_ai 已拆成约 100 秒一份）
FLAKY_RERUN_MAX = 3  # 并行负载下偶发失败（floor16、floor_run_c 等）最多单独重跑这么多个
RESULTS_KEEP = 20  # 共用状态目录里最多保留这么多份整轮结果（按指纹）
RULES_FILTER_ENV = ('RULES_ONLY_TROOPS', 'RULES_ONLY_ACTORS')  # xiyou_rules 的编号过滤，结果不完整
HEARTBEAT = 300  # 默认心跳间隔（秒），远小于长任务.py 的 3600 秒无输出上限
LOGS_KEEP = 10  # 默认日志目录（本地结果/并行测试/）最多保留这么多份


def result_ok(rc: int, out: str) -> bool:
    """退出码与结构化结果都通过才算成功，防止场景漏设非零退出码时假通过。"""
    lines = [l[len('TEST_RESULT='):] for l in out.splitlines() if l.startswith('TEST_RESULT=')]
    if rc != 0 or len(lines) != 1 or re.search(r'SCRIPT ERROR|^ERROR:|^FAIL(?:\s|$)', out, re.M):
        return False
    try:
        result = json.loads(lines[0])
    except ValueError:
        return False
    return (isinstance(result, dict) and type(result.get('total')) is int and result['total'] > 0
            and type(result.get('passed')) is int and result['passed'] == result['total'])


def valid_rows(prev, fingerprint: str, scenes: list) -> dict:
    """同一指纹的上轮记录（场景 → {passed, line}）。记录结构不对或任一条自相矛盾时整份作废（返回空，全部重跑）。
    指纹含 tests/ 下全部文件，场景表相同；记录可以只有部分场景（选测留下的），但不许有当前没有的场景。"""
    if not isinstance(prev, dict) or prev.get('fingerprint') != fingerprint:
        return {}
    rows = prev.get('scenes')
    if not isinstance(rows, dict) or not rows or not set(rows) <= set(scenes):
        return {}
    for row in rows.values():
        if not isinstance(row, dict) or set(row) != {'passed', 'line'} or type(row['passed']) is not bool \
                or not isinstance(row['line'], str):
            return {}
        if row['passed'] and not result_ok(0, 'TEST_RESULT=' + row['line']):
            return {}
    return rows


def reusable_results(prev, fingerprint: str, scenes: list) -> dict:
    """上轮记录里可沿用（通过）的场景 → TEST_RESULT 行；只看本次要跑的 scenes。"""
    rows = valid_rows(prev, fingerprint, scenes)
    out = {}
    for name, row in rows.items():
        if row['passed']:
            out[name] = row['line']
    return out


class Progress:
    """心跳用的进度：等槽、在跑、完成。"""
    def __init__(self, total: int):
        self.lock = threading.Lock()
        self.total, self.done = total, 0
        self.waiting, self.running = set(), set()

    def line(self) -> str:
        with self.lock:
            return '  · 进行中：完成 %d/%d，等槽 %d，在跑 %s' % (
                self.done, self.total, len(self.waiting), '、'.join(sorted(self.running)) or '无')


@contextlib.contextmanager
def heartbeat(progress: Progress, interval: float):
    stop = threading.Event()

    def beat():
        while not stop.wait(interval):
            print(progress.line(), flush=True)
    t = threading.Thread(target=beat, daemon=True)
    if interval > 0:
        t.start()
    try:
        yield
    finally:
        stop.set()
        if interval > 0:
            t.join()


def state_dir(project: str) -> Path:
    if os.environ.get('XIYOU_TEST_STATE_DIR'):
        d = Path(os.environ['XIYOU_TEST_STATE_DIR'])
    else:
        try:
            common = subprocess.run(['git', '-C', project, 'rev-parse', '--path-format=absolute', '--git-common-dir'],
                                    capture_output=True, text=True, check=True).stdout.strip()
            if not Path(common).is_absolute():  # 只信绝对路径，免得在当前目录建出相对的状态目录
                raise ValueError(common)
            d = Path(common) / 'xiyou_test_state'
        except (OSError, ValueError, subprocess.CalledProcessError):
            d = Path(tempfile.gettempdir()) / 'xiyou_test_state'
    d.mkdir(parents=True, exist_ok=True)
    return d


@contextlib.contextmanager
def file_lock(path: Path):
    with open(path, 'a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def write_json(path: Path, data) -> None:
    tmp = path.with_name(path.name + '.%d.tmp' % os.getpid())
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    os.replace(tmp, path)


def global_limit() -> int:
    """跨工作树共用并发上限：CHECK_GLOBAL_JOBS，默认 CPU 核数一半、最多 6（同步探针也用它，见 同步正式西游.py）。"""
    return int(os.environ.get('CHECK_GLOBAL_JOBS', '0')) or max(1, min(6, (os.cpu_count() or 2) // 2))


@contextlib.contextmanager
def global_slot(sdir: Path, limit: int, weight: int = 1, on_wait=None, wait_interval: float = 60.0):
    """所有工作树共用的并发槽位：slots/<i>.lock 上的非阻塞 flock，占到哪个用哪个；进程退出时系统自动释放。
    weight：一个进程占几槽（特别吃内存的探针如 event_probe 单进程约 4.5GB，按实际占用多占几槽），超过上限按上限算。
    多槽的先独占 heavy.lock（同一时间只有一个多槽进程在攒槽，免得两个各攒一半互相等死），再一槽一槽攒齐，攒到的不放；
    单槽的每次占槽前先对 heavy.lock 取共享锁，有多槽进程正在攒槽（独占锁在）就让路等着，所以空出来的槽一定归多槽进程，
    它不会被源源不断的单槽测试永远插队（2026-10-26 哪吒：原来单槽照旧抢，空槽归谁看轮询先后，回归偶发失败）。
    on_wait(已等秒数)：排队期间每 wait_interval 秒调一次（同步用它打印「等槽」心跳，长任务看门狗据此算作有进展）。"""
    slots = sdir / 'slots'
    slots.mkdir(exist_ok=True)
    weight = max(1, min(int(weight), limit))
    held, heavy, gate = [], None, None
    t0 = last = time.monotonic()

    def tick():
        nonlocal last
        now = time.monotonic()
        if on_wait and now - last >= wait_interval:
            last = now
            on_wait(now - t0)

    try:
        if weight > 1:
            heavy = open(slots / 'heavy.lock', 'a')
            while True:
                try:
                    fcntl.flock(heavy, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except OSError:
                    tick()
                    time.sleep(0.5)
        gate = open(slots / 'heavy.lock', 'a') if weight == 1 else None
        while len(held) < weight:
            if gate is not None:
                try:
                    fcntl.flock(gate, fcntl.LOCK_SH | fcntl.LOCK_NB)  # 有多槽进程在攒槽：让路
                except OSError:
                    tick()
                    time.sleep(0.5)
                    continue
            for i in range(limit):
                if len(held) == weight or any(n == i for n, _ in held):
                    continue
                f = open(slots / ('%d.lock' % i), 'a')
                try:
                    fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except OSError:
                    f.close()
                    continue
                held.append((i, f))
            if gate is not None:
                fcntl.flock(gate, fcntl.LOCK_UN)
            if len(held) < weight:
                tick()
                time.sleep(0.5)
        if gate is not None:
            gate.close()
            gate = None
        if heavy:
            fcntl.flock(heavy, fcntl.LOCK_UN)
            heavy.close()
            heavy = None
        yield held[0][0] if weight == 1 else [n for n, _ in held]
    finally:
        for _, f in held:
            fcntl.flock(f, fcntl.LOCK_UN)
            f.close()
        if heavy:
            heavy.close()
        if gate is not None:
            gate.close()


def run_one(godot: str, project: str, name: str, sdir: Path, limit: int, progress: Progress = None) -> tuple:
    if progress:
        with progress.lock:
            progress.waiting.add(name)
    with global_slot(sdir, limit):
        if progress:
            with progress.lock:
                progress.waiting.discard(name)
                progress.running.add(name)
        start = time.time()
        with tempfile.TemporaryDirectory(prefix='xiyou_test_home_') as home:
            env = dict(os.environ, HOME=home)
            try:
                p = subprocess.run([godot, '--headless', '--path', project, 'res://tests/' + name],
                                   capture_output=True, text=True, timeout=TIMEOUT, env=env)
                out, rc = p.stdout + p.stderr, p.returncode
            except subprocess.TimeoutExpired as e:
                out = ''.join(x.decode(errors='replace') if isinstance(x, bytes) else (x or '')
                              for x in (e.stdout, e.stderr))
                rc = 142
        if progress:
            with progress.lock:
                progress.running.discard(name)
                progress.done += 1
        return name, rc, out, time.time() - start


def in_linked_worktree(path: str) -> bool:
    """是否在 git worktree（而不是主工作区）里：git-dir 与 git-common-dir 不同。"""
    try:
        out = subprocess.run(['git', '-C', path, 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'],
                             capture_output=True, text=True, check=True).stdout.split('\n')
        return out[0] != out[1]
    except (OSError, subprocess.CalledProcessError, IndexError):
        return False


def project_fingerprint(godot: str, project: str, sdir: Path) -> str:
    """工程指纹（见文件头）。文件内容哈希按 (大小, 修改时间, inode) 记在 filememo 里，没变的文件不重读。"""
    root = Path(project).resolve()
    memo_path = sdir / 'filememo' / (hashlib.sha1(str(root).encode()).hexdigest() + '.json')
    memo_path.parent.mkdir(exist_ok=True)
    memo = read_json(memo_path, {})
    fresh = {}
    h = hashlib.sha256()
    for dirpath, dirnames, filenames in os.walk(root, followlinks=True):
        if Path(dirpath) == root:
            dirnames[:] = [d for d in dirnames if d != '.godot']
        dirnames.sort()
        for fn in sorted(filenames):
            p = Path(dirpath) / fn
            rel = p.relative_to(root).as_posix()
            st = p.stat()
            key = [st.st_size, st.st_mtime_ns, st.st_ino]
            old = memo.get(rel)
            if old and old[:3] == key:
                digest = old[3]
            else:
                fh = hashlib.sha256()
                with open(p, 'rb') as f:
                    for chunk in iter(lambda: f.read(1 << 20), b''):
                        fh.update(chunk)
                digest = fh.hexdigest()
            fresh[rel] = key + [digest]
            h.update(('%s\0%s\n' % (rel, digest)).encode())
    write_json(memo_path, fresh)
    exe = Path(subprocess.run(['/bin/sh', '-c', 'command -v "$1"', '-', godot], capture_output=True, text=True).stdout.strip() or godot).resolve()
    st = exe.stat()
    version = subprocess.run([godot, '--version'], capture_output=True, text=True, timeout=60).stdout.strip()
    h.update(('godot\0%s\0%d\0%d\0%s\n' % (exe, st.st_size, st.st_mtime_ns, version)).encode())
    h.update(hashlib.sha256(Path(__file__).read_bytes()).hexdigest().encode())
    h.update(('timeout\0%d\n' % TIMEOUT).encode())
    return h.hexdigest()


def default_log_dir(project: str) -> Path:
    """<工程上一级>/04_验证/本地结果/并行测试/<时间戳>；旧的只留最近 LOGS_KEEP 份（只删本工具起名的目录）。"""
    parent = Path(project).resolve().parent / '04_验证/本地结果/并行测试'
    parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    d = Path(tempfile.mkdtemp(prefix=stamp + '_', dir=parent))
    for old in sorted(p for p in parent.iterdir() if p.is_dir() and not p.is_symlink() and re.match(r'\d{8}_\d{6}_', p.name))[:-LOGS_KEEP]:
        shutil.rmtree(old, ignore_errors=True)
    return d


def git_head(project: str) -> str:
    try:
        return subprocess.run(['git', '-C', project, 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ''


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('godot')
    ap.add_argument('project')
    ap.add_argument('--jobs', type=int, default=None)
    ap.add_argument('--full', action='store_true', help='不沿用上轮结果，整轮重跑（也可 CHECK_FULL=1）')
    ap.add_argument('--reuse', action='store_true', help='指定场景时也按工程指纹沿用上轮通过结果（检查.sh 选测用）')
    ap.add_argument('--log-dir', type=Path, default=Path(os.environ['CHECK_LOG_DIR']) if os.environ.get('CHECK_LOG_DIR') else None,
                    help='每个场景的完整输出写到这里；不给时用 04_验证/本地结果/并行测试/<时间戳>/')
    ap.add_argument('--quiet', action='store_true', help='不打心跳与通过行，只打失败、偶发、提示与汇总')
    ap.add_argument('names', nargs='*')
    a = ap.parse_intermixed_args()
    if a.log_dir is None:
        a.log_dir = default_log_dir(a.project)
    a.full = a.full or os.environ.get('CHECK_FULL', '') not in ('', '0')
    cpu_half = max(1, min(6, (os.cpu_count() or 2) // 2))
    if a.jobs is None:
        a.jobs = int(os.environ.get('CHECK_JOBS', '0')) or (2 if in_linked_worktree(a.project) else cpu_half)
    if a.jobs < 1:
        ap.error('--jobs 必须大于 0')
    limit = global_limit()
    scenes = sorted(p.name for p in (Path(a.project) / 'tests').glob('*.tscn'))
    if a.names:
        scenes = [s for s in scenes if any(s == n or s == n + '.tscn' or s.startswith(n) for n in a.names)]
    if not scenes:
        print('  ✗ tests/ 下没有匹配的测试场景')
        return 1
    sdir = state_dir(a.project)
    whole = not a.names
    # RULES_ONLY_* 过滤时 xiyou_rules 非 part0 只记 1 项成功，指纹又不含过滤值：过滤运行不读写沿用记录（沙僧第四期 T1）
    filtered = [k for k in RULES_FILTER_ENV if os.environ.get(k, '').strip()]
    keyed = (whole or a.reuse) and not filtered  # 按指纹读写记录
    if filtered and (whole or a.reuse):
        print('  · 设了 %s（编号过滤）：选中的场景全部实跑，不读写沿用记录' % '／'.join(filtered))
    all_scenes = sorted(p.name for p in (Path(a.project) / 'tests').glob('*.tscn'))
    fingerprint = project_fingerprint(a.godot, a.project, sdir) if keyed else ''
    reused = {}  # 场景 → 上轮通过时的 TEST_RESULT 行
    if keyed and not a.full:
        prev = reusable_results(read_json(sdir / 'results' / (fingerprint + '.json'), {}), fingerprint, all_scenes)
        reused = {n: prev[n] for n in scenes if n in prev}
    timings = read_json(sdir / 'timings.json', {})
    todo = sorted((n for n in scenes if n not in reused), key=lambda n: (-float(timings.get(n, 1e9)), n))
    attempts = {}  # 场景 → [(rc, out, secs), …]：首次在前，重跑依次追加，不覆盖
    started = time.monotonic()
    progress = Progress(len(todo))
    flaky = []
    with heartbeat(progress, 0 if a.quiet else float(os.environ.get('XIYOU_TEST_HEARTBEAT', HEARTBEAT))):
        with cf.ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for name, rc, out, secs in pool.map(lambda n: run_one(a.godot, a.project, n, sdir, limit, progress), todo):
                attempts[name] = [(rc, out, secs)]
        failed = [n for n in todo if not result_ok(*attempts[n][0][:2])]
        if a.jobs > 1 and len(todo) > 1 and 0 < len(failed) <= FLAKY_RERUN_MAX:
            progress.total += len(failed)
            for name in failed:
                again = run_one(a.godot, a.project, name, sdir, limit, progress)[1:]
                attempts[name].append(again)
                if result_ok(again[0], again[1]):
                    flaky.append(name)
    final = {n: result_ok(*attempts[n][-1][:2]) for n in todo}
    fail = 0
    for name in scenes:
        if name in reused:
            if a.log_dir:
                a.log_dir.mkdir(parents=True, exist_ok=True)
                (a.log_dir / (Path(name).stem + '.log')).write_text('沿用上轮通过结果（工程指纹 %s 未变）\nTEST_RESULT=%s\n' % (fingerprint[:12], reused[name]))
            if not a.quiet:
                print(('  ✓ %s %s（沿用）' % (name, reused[name]))[:120])
            continue
        tries = attempts[name]
        if a.log_dir:
            a.log_dir.mkdir(parents=True, exist_ok=True)
            for i, (_, out, _) in enumerate(tries):
                (a.log_dir / (Path(name).stem + ('.rerun%d' % i if i else '') + '.log')).write_text(out)
        rc, out, secs = tries[-1]
        line = next((l for l in out.splitlines() if l.startswith('TEST_RESULT=')), '')
        if final[name]:
            if not a.quiet:
                print(('  ✓ %s %s' % (name, line[len('TEST_RESULT='):]))[:120])
            if name in flaky:
                print('  ⚠ %s 并行时失败（rc=%d，%d 秒）、单独重跑通过（%d 秒）（偶发，写进交付单）' % (name, tries[0][0], tries[0][2], secs))
            if max(t[2] for t in tries) > SLOW:
                print('  ⚠ %s 用时 %d 秒，超过上限 %d 秒的一半，请按场景拆分' % (name, max(t[2] for t in tries), TIMEOUT))
        else:
            fail = 1
            print('  ✗ %s (rc=%d)' % (name, rc))
            for l in [l for l in out.splitlines() if re.search(r'ERROR|FAIL |passed|TEST_RESULT', l)][:8]:
                print('      ' + l)
            print('      完整输出：' + str(a.log_dir / (Path(name).stem + ('.rerun%d' % (len(tries) - 1) if len(tries) > 1 else '') + '.log')))
    wall = time.monotonic() - started
    if reused:
        print('  · 工程未变：沿用上轮通过 %d 个，实际运行 %d 个（--full 或 CHECK_FULL=1 强制整轮）' % (len(reused), len(todo)))
    print('  · 测试用时 %d 秒（并行 %d，共用上限 %d）%s' % (wall, a.jobs, limit, '' if not a.quiet else '；%d 个场景，%s' % (
        len(scenes), '全部通过' if not fail else '有失败')))
    now = datetime.datetime.now().isoformat(timespec='seconds')
    with file_lock(sdir / 'state.lock'):
        timings = read_json(sdir / 'timings.json', {})
        timings.update({n: round(attempts[n][0][2], 3) for n in todo})
        write_json(sdir / 'timings.json', timings)
        if flaky:
            with open(sdir / 'flaky.jsonl', 'a') as f:
                for n in flaky:
                    f.write(json.dumps({'time': now, 'project': str(Path(a.project).resolve()), 'head': git_head(a.project), 'scene': n,
                                        'attempts': [{'rc': t[0], 'seconds': round(t[2], 3), 'passed': result_ok(t[0], t[1])} for t in attempts[n]]},
                                       ensure_ascii=False) + '\n')
        if keyed:
            rdir = sdir / 'results'
            rdir.mkdir(exist_ok=True)
            # 同一指纹的旧记录合并进来（选测与整轮互补）；--full 也只是不沿用，本次结果照样覆盖旧行
            rows = dict(valid_rows(read_json(rdir / (fingerprint + '.json'), {}), fingerprint, all_scenes))
            rows.update({n: {'passed': True, 'line': reused[n]} for n in reused})
            for n in todo:
                last = attempts[n][-1]
                rows[n] = {'passed': final[n], 'line': next((l[len('TEST_RESULT='):] for l in last[1].splitlines() if l.startswith('TEST_RESULT=')), '')}
            write_json(rdir / (fingerprint + '.json'), {'fingerprint': fingerprint, 'time': now, 'scenes': rows})
            for old in sorted(rdir.glob('*.json'), key=lambda p: p.stat().st_mtime)[:-RESULTS_KEEP]:
                old.unlink()
    if flaky:
        history = [json.loads(l) for l in (sdir / 'flaky.jsonl').read_text().splitlines() if l.strip()]
        for n in flaky:
            print('  ⚠ %s 累计偶发 %d 次（记录见 %s）' % (n, sum(1 for r in history if r.get('scene') == n), sdir / 'flaky.jsonl'))
    if a.log_dir:
        (a.log_dir / 'test_timings.json').write_text(json.dumps({
            'jobs': a.jobs, 'globalJobs': limit, 'wallSeconds': round(wall, 3), 'flakyRerunPassed': flaky,
            'fingerprint': fingerprint, 'reused': sorted(reused),
            'scenes': [{'name': n, 'seconds': round(attempts[n][0][2], 3), 'passed': final[n],
                        'attempts': [{'rc': t[0], 'seconds': round(t[2], 3), 'passed': result_ok(t[0], t[1])} for t in attempts[n]]}
                       for n in sorted(todo, key=lambda n: attempts[n][0][2], reverse=True)]
        }, ensure_ascii=False, indent=2) + '\n')
        print('  · 日志：' + str(a.log_dir))
    return fail


if __name__ == '__main__':
    sys.exit(main())
