#!/usr/bin/env python3
"""并行运行 Godot 测试场景（检查.sh 调用；也可单独用来跑几个专项）。

用法：并行测试.py <godot> <工程目录> [--jobs N] [--full] [--names-file 文件] [场景全名或「前缀*」 ...]（不带 * 的名字只按全名选，XIYOU_BARE_PREFIX=1 回到按前缀）
- 每个测试一个独立的临时 HOME，因此 user://（存档、配置）互不干扰，也不会读写本机真实的用户数据目录。
- 导入（--import）由调用方先单独做一次；这里只读工程缓存。例外：工程里有 class_name 不在导入缓存里（车道新加脚本后直接跑）时先导入一次。
- 每个测试用 -s 挂 tests/test_main_loop.gd（哪吒_10）：场景加载前把神秘生物刷新的真实时钟固定到窗口外，免得整点／半点偶发。
- 每个测试最多 600 秒；脚本语法错误时场景不会自行退出，超时即判失败。用时超过一半（300 秒）时提示拆场景。
- 并行时只有少数（≤3）测试失败的，逐个单独重跑一次：单跑通过记为「偶发」，仍算通过但打印 ⚠，写进交付单；单跑仍失败才判失败。
  首次与重跑的输出、退出码、耗时分别保留（日志 <场景>.log 与 <场景>.rerun1.log、test_timings.json 的 attempts），
  每次偶发另追加到共用状态目录的 flaky.jsonl，多次偶发可对账。
- 输出与原来逐个运行时相同（按场景名排序），失败时返回 1。
- test_timings.json 每个场景记墙钟秒数与子进程 user／sys CPU 秒（os.wait4 的 rusage，哪吒_9）：墙钟高、CPU 低是在等机器，CPU 也高才是场景本身慢。
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
- 单槽排队（2026-10-28 哪吒_5）：单槽申请前先看 slots/queue/ 里有没有别的进程更早登记、还活着的等候者，有就让一轮；
  自己第一次没占到才登记（文件名＝开始纳秒_pid_线程，等待中每轮刷新，超过 QUEUE_STALE 秒没刷新或 pid 已不在的作废）。
  同一进程的线程之间不排队；多槽进程照 heavy.lock 规则不参加。XIYOU_SLOT_QUEUE=0 回到旧行为。
- 总装优先（2026-10-30 哪吒_9）：主工作区（或 XIYOU_SLOT_PRIORITY=1）的占槽请求排进 slots/priority/，
  别的工作树的单槽申请只要看到还活着的优先等候者就让（不论谁先来）；车道的多槽进程在拿 heavy.lock 前也先等优先等候者走完。
  已占到槽在跑的不打断。XIYOU_SLOT_PRIORITY=0 让主工作区也按普通排队。
- 快车道（tools30，白龙：单个专项直接跑 8 秒、排槽要 7 分钟）：这一次只跑 ≤EXPRESS_SCENES 个场景、且每个上次实测都不超过
  EXPRESS_SECONDS 秒时，先试 slots/express.lock（全机只有一把，非阻塞 flock）：拿到就不排共用槽直接跑，最多比共用上限多一个进程；
  拿不到（别人在用快车道）照常排队。没有实测记录的不走快车道。XIYOU_SLOT_EXPRESS=0 回到一律排队。
- 心跳：批测与排槽期间每 XIYOU_TEST_HEARTBEAT 秒（默认 300，0 关闭）打印一行进度（完成数、等槽数、在跑的场景），
  免得长任务.py 的无输出看门狗（默认 3600 秒）把仍在推进的批测判成卡住；不放宽看门狗、不改并发。
- 日志：--log-dir（或 CHECK_LOG_DIR）没给时写到 <工程上一级>/04_验证/本地结果/并行测试/<时间戳>/（只留最近 LOGS_KEEP 份），
  每个场景一份 <场景>.log，结尾打印目录；失败的场景另打印它的完整日志路径（八戒期二、期三：明细只在屏幕上 8 行，
  管道给 tail 时看不全，曾多花一轮 50 分钟重跑）；最后两类行是「✗ 失败场景 N 个」与逐个「场景 → 日志」，
  设了 CHECK_FAILED_FILE 时同样写进该文件（每行「场景<Tab>日志」，全过时清空），检查.sh 据此在收尾汇总里带上日志路径。--quiet：不打通过行，只打失败、偶发、提示、心跳与汇总（心跳照打，长任务里加 --quiet 也不会被无输出看门狗杀掉，八戒 dev.206）。
- 共用状态目录：XIYOU_TEST_STATE_DIR，否则 <git-common-dir>/xiyou_test_state（主工作区与各 worktree 共用），不在 Git 里时用系统临时目录。
"""
import argparse
import concurrent.futures as cf
import contextlib
import datetime
import fcntl
import functools
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
NO_RERUN_PARSE_ERROR = True  # 解析错误不当偶发重跑（tools27）；设 False 回到照常重跑
FLAKY_RERUN_MAX = 3  # 并行负载下偶发失败（floor16、floor_run_c 等）最多单独重跑这么多个
RESULTS_KEEP = 20  # 共用状态目录里最多保留这么多份整轮结果（按指纹）
RULES_FILTER_ENV = ('RULES_ONLY_TROOPS', 'RULES_ONLY_ACTORS')  # xiyou_rules 的编号过滤，结果不完整
EXPRESS_SCENES = 2  # 快车道：一次最多几个场景
EXPRESS_SECONDS = 60  # 快车道：每个场景上次实测不超过几秒
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


QUEUE_STALE = 30.0  # 排队文件超过这么多秒没刷新就当作死进程留下的，删掉


def queue_enabled() -> bool:
    """单槽先来先得排队（2026-10-28 哪吒_5）；XIYOU_SLOT_QUEUE=0 回到旧行为（谁轮询先谁拿）。"""
    return os.environ.get('XIYOU_SLOT_QUEUE', '1') != '0'


def slot_priority(path: str) -> bool:
    """占槽优先：XIYOU_SLOT_PRIORITY 设了 1/0 就照它，否则主工作区（总装合并检查、同步）优先、worktree（车道）不优先。"""
    env = os.environ.get('XIYOU_SLOT_PRIORITY', '')
    if env != '':
        return env != '0'
    return not _linked_cached(str(Path(path).resolve()))


@functools.lru_cache(maxsize=None)
def _linked_cached(path: str) -> bool:
    return in_linked_worktree(path)


def earlier_waiter(qdir: Path, me: str, anytime: bool = False) -> bool:
    """别的进程有没有比 me（排队文件名「开始纳秒_pid_线程」；None＝还没登记，按现在算）更早登记、还活着的单槽等候者。
    anytime：不比先后，有活着的就算（普通申请看优先队列用）。
    同一进程的线程之间不排队（各自的批测里照旧）；超时没刷新或 pid 已不在的排队文件顺手删掉。"""
    mine = float('inf') if anytime else int(me.split('_')[0]) if me else time.time_ns()
    now = time.time()
    for f in qdir.glob('*_*_*'):
        try:
            start, pid, _ = f.name.split('_', 2)
            start, pid = int(start), int(pid)
        except ValueError:
            continue
        if pid == os.getpid():
            continue
        try:
            stale = now - f.stat().st_mtime > QUEUE_STALE
            if not stale:
                os.kill(pid, 0)
        except ProcessLookupError:
            stale = True
        except (FileNotFoundError, PermissionError):
            continue
        if stale:
            f.unlink(missing_ok=True)
        elif start < mine:
            return True
    return False


@contextlib.contextmanager
def global_slot(sdir: Path, limit: int, weight: int = 1, on_wait=None, wait_interval: float = 60.0, priority: bool = False):
    """所有工作树共用的并发槽位：slots/<i>.lock 上的非阻塞 flock，占到哪个用哪个；进程退出时系统自动释放。
    weight：一个进程占几槽（特别吃内存的探针如 event_probe 单进程约 4.5GB，按实际占用多占几槽），超过上限按上限算。
    多槽的先独占 heavy.lock（同一时间只有一个多槽进程在攒槽，免得两个各攒一半互相等死），再一槽一槽攒齐，攒到的不放；
    单槽的每次占槽前先对 heavy.lock 取共享锁，有多槽进程正在攒槽（独占锁在）就让路等着，所以空出来的槽一定归多槽进程，
    它不会被源源不断的单槽测试永远插队（2026-10-26 哪吒：原来单槽照旧抢，空槽归谁看轮询先后，回归偶发失败）。
    on_wait(已等秒数)：排队期间每 wait_interval 秒调一次（同步用它打印「等槽」心跳，长任务看门狗据此算作有进展）。
    priority：总装优先（见文件头），由调用方用 slot_priority(工程目录) 算好传进来。"""
    slots = sdir / 'slots'
    slots.mkdir(exist_ok=True)
    weight = max(1, min(int(weight), limit))
    held, heavy, gate = [], None, None
    t0 = last = time.monotonic()
    # 单槽先来先得（多槽照 heavy.lock 规则，不参加排队，免得与闸门互等）：主工作区批测占满上限时，它的线程放槽后同一瞬间
    # 就重抢，别的工作树每 0.5 秒轮询一次几乎抢不到（10-28 哪吒排 1 小时、八戒排 1.5 小时）。
    queued = queue_enabled()
    pdir = slots / 'priority' if queued else None  # 总装优先的等候者（单槽、多槽都在这里登记）
    if pdir:
        pdir.mkdir(exist_ok=True)
    qdir = (pdir if priority else slots / 'queue') if weight == 1 and queued else None
    ticket = None  # 自己的排队文件；第一次没占到才登记
    if qdir:
        qdir.mkdir(exist_ok=True)

    def ahead() -> bool:
        """有没有该让的：普通申请让任何活着的优先等候者，再按先来先得；优先申请只在优先队列里比先后。"""
        if pdir and not priority and earlier_waiter(pdir, None, anytime=True):
            return True
        return bool(qdir) and earlier_waiter(qdir, ticket.name if ticket else None)

    def enqueue():
        nonlocal ticket
        if ticket is None and (qdir or (pdir and priority)):
            ticket = (qdir or pdir) / ('%d_%d_%d' % (time.time_ns(), os.getpid(), threading.get_ident()))
            ticket.touch()

    def tick():
        nonlocal last
        now = time.monotonic()
        if on_wait and now - last >= wait_interval:
            last = now
            on_wait(now - t0)

    try:
        if weight > 1:
            # 车道的多槽进程先等总装的优先等候者走完再攒槽（攒槽时会挡住所有单槽，含总装）；优先的多槽进程登记进优先队列
            if priority:
                enqueue()
            while pdir and not priority and earlier_waiter(pdir, None, anytime=True):
                tick()
                time.sleep(0.5)
            heavy = open(slots / 'heavy.lock', 'a')
            while True:
                if ticket:
                    with contextlib.suppress(OSError):
                        os.utime(ticket)
                try:
                    fcntl.flock(heavy, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except OSError:
                    tick()
                    time.sleep(0.5)
        gate = open(slots / 'heavy.lock', 'a') if weight == 1 else None
        while len(held) < weight:
            if ticket:
                with contextlib.suppress(OSError):
                    os.utime(ticket)  # 刷新：别人据此认我还活着
            if weight == 1 and ahead():
                enqueue()
                tick()
                time.sleep(0.5)
                continue
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
                enqueue()
                tick()
                time.sleep(0.5)
        if ticket:
            ticket.unlink(missing_ok=True)
            ticket = None
        if gate is not None:
            gate.close()
            gate = None
        if heavy:
            fcntl.flock(heavy, fcntl.LOCK_UN)
            heavy.close()
            heavy = None
        yield held[0][0] if weight == 1 else [n for n, _ in held]
    finally:
        if ticket:
            ticket.unlink(missing_ok=True)
        for _, f in held:
            fcntl.flock(f, fcntl.LOCK_UN)
            f.close()
        if heavy:
            heavy.close()
        if gate is not None:
            gate.close()


## 测试公共启动：场景加载前固定神秘生物真实时钟等（见该文件头）。工程里没有它（旧工程、测试夹具）时不挂
MAIN_LOOP = 'res://tests/test_main_loop.gd'


@contextlib.contextmanager
def express_slot(sdir: Path):
    """快车道（见文件头）：拿到 slots/express.lock 就 yield True（不再占共用槽），拿不到 yield False。"""
    slots = sdir / 'slots'
    slots.mkdir(exist_ok=True)
    f = open(slots / 'express.lock', 'a')
    try:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            yield False
            return
        yield True
    finally:
        f.close()


def express_eligible(todo: list, timings: dict) -> bool:
    """这一次够不够走快车道：场景少、每个都有不超过 EXPRESS_SECONDS 的实测。"""
    if os.environ.get('XIYOU_SLOT_EXPRESS', '1') == '0' or not 0 < len(todo) <= EXPRESS_SCENES:
        return False
    return all(n in timings and float(timings[n]) <= EXPRESS_SECONDS for n in todo)


@contextlib.contextmanager
def test_slot(sdir: Path, limit: int, project: str, express: bool):
    """快车道拿得到就用它，否则排共用槽。"""
    if express:
        with express_slot(sdir) as got:
            if got:
                yield 'express'
                return
    with global_slot(sdir, limit, priority=slot_priority(project)) as n:
        yield n


def run_one(godot: str, project: str, name: str, sdir: Path, limit: int, progress: Progress = None, express: bool = False) -> tuple:
    if progress:
        with progress.lock:
            progress.waiting.add(name)
    with test_slot(sdir, limit, project, express):
        if progress:
            with progress.lock:
                progress.waiting.discard(name)
                progress.running.add(name)
        start = time.time()
        with tempfile.TemporaryDirectory(prefix='xiyou_test_home_') as home:
            env = dict(os.environ, HOME=home)
            loop = ['-s', MAIN_LOOP] if (Path(project) / MAIN_LOOP[len('res://'):]).is_file() else []
            rc, out, cpu = run_with_rusage([godot, '--headless', '--path', project] + loop + ['res://tests/' + name], env, TIMEOUT, FATAL_LOAD)
        if progress:
            with progress.lock:
                progress.running.discard(name)
                progress.done += 1
        return name, rc, out, time.time() - start, cpu


# 脚本解析失败（加载不了测试场景或它依赖的脚本）：Godot 不退出，一直等到单场景超时（600 秒）才被杀。出现这些行就没必要再等了。
# 只认 Godot 自己的这两种报错行；测试正文里打印的 "Parse Error"（如 JSON 解析失败的断言信息）不匹配。
FATAL_LOAD = re.compile(r'^SCRIPT ERROR: Parse Error: |^ERROR: Failed to load script "[^"]*" with error "Parse error"', re.M)


def run_with_rusage(cmd: list, env: dict, timeout: float, fatal=None) -> tuple:
    """跑一个子进程，返回 (退出码, 标准输出＋标准错误, {user, sys} CPU 秒)。超时杀掉、退出码记 142、输出保留已有部分。
    CPU 用 os.wait4 取本子进程（含它等过的孙进程）的 rusage：批测各线程并行，RUSAGE_CHILDREN 的差值会混进别的场景
    （八戒 dev.206：墙钟受负载影响大，单看秒数分不清是场景慢还是机器满）。"""
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    bufs = [[], []]
    def drain(f, b):   # 边读边存：出现致命报错行时能在进程还活着的时候发现
        for chunk in iter(lambda: f.read1(65536), b''):
            b.append(chunk)
    readers = [threading.Thread(target=drain, args=(f, b), daemon=True) for f, b in zip((p.stdout, p.stderr), bufs)]
    for t in readers:
        t.start()
    deadline = time.monotonic() + timeout
    timed_out = early = False
    scanned = [0, 0]
    while True:
        pid, status, usage = os.wait4(p.pid, os.WNOHANG)
        if pid:
            break
        if fatal and any(len(b) != n for b, n in zip(bufs, scanned)):
            scanned = [len(b) for b in bufs]
            if fatal.search(''.join(b''.join(b).decode(errors='replace') for b in bufs)):
                early = True
                p.kill()
                pid, status, usage = os.wait4(p.pid, 0)
                break
        if time.monotonic() > deadline:
            timed_out = True
            p.kill()
            pid, status, usage = os.wait4(p.pid, 0)
            break
        time.sleep(0.05)
    p.returncode = os.waitstatus_to_exitcode(status)  # 已由 wait4 收尸，告诉 Popen 别再等
    for t in readers:
        t.join(2 if (early or timed_out) else None)   # 被杀后孙进程可能还攥着管道，最多再等 2 秒收尾巴
    if not any(t.is_alive() for t in readers):   # 孙进程还攥着管道时 close 会等到它退出，留给守护线程自生自灭
        p.stdout.close()
        p.stderr.close()
    out = ''.join(b''.join(b).decode(errors='replace') for b in bufs)
    if early:
        out += '\n提前终止：出现脚本解析错误，不等超时（并行测试.py FATAL_LOAD）\n'
        p.returncode = 143
    return 142 if timed_out else p.returncode, out, {'user': round(usage.ru_utime, 3), 'sys': round(usage.ru_stime, 3)}


def missing_classes(project: str) -> list:
    """工程里声明了 class_name、导入缓存（.godot/global_script_class_cache.cfg）里却没有的类名。
    车道新加带 class_name 的脚本后直接跑并行测试（不经 检查.sh 的导入），新类名解析不到、整批报错（八戒 10-29 期 C）。"""
    root = Path(project)
    cache = root / '.godot/global_script_class_cache.cfg'
    known = set(re.findall(r'"class":\s*&"(\w+)"', cache.read_text(errors='replace'))) if cache.is_file() else set()
    declared = set()
    for f in root.rglob('*.gd'):
        if '.godot' in f.relative_to(root).parts:
            continue
        m = re.search(r'^class_name\s+(\w+)', f.read_text(errors='replace'), re.M)
        if m:
            declared.add(m.group(1))
    return sorted(declared - known)


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


def stale_generated(project: str):
    """linked worktree 里 generated/ 落后主工作区时返回提示文字，否则 None（哪吒_41，参照批次.py compare）。
    回退：--skip-generated-check 或 XIYOU_SKIP_GENERATED_CHECK=1。"""
    if not in_linked_worktree(project):
        return None
    try:
        out = subprocess.run(['git', '-C', project, 'rev-parse', '--path-format=absolute', '--show-toplevel', '--git-common-dir'],
                             capture_output=True, text=True, check=True).stdout.split('\n')
        main_root = Path(out[1]).parent
        rel = Path(project).resolve().relative_to(Path(out[0]).resolve())
    except (OSError, subprocess.CalledProcessError, IndexError, ValueError):
        return None
    gen, main_gen = Path(project).resolve() / 'modes/xiyou/generated', main_root / rel / 'modes/xiyou/generated'
    tool = Path(__file__).resolve().parent / '参照批次.py'
    if not gen.is_dir() or not main_gen.is_dir() or not tool.is_file():
        return None
    p = subprocess.run([sys.executable, str(tool), 'compare', str(gen), str(main_gen)], capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 3 else None


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


PREFIX_HINT = int(os.environ.get('XIYOU_PREFIX_HINT', '20'))  # 一个名字前缀匹配超过这么多场景时提示
PREFIX_STOP = int(os.environ.get('XIYOU_PREFIX_STOP', '40'))  # 不带 * 的前缀扩出超过这么多场景就停下（白龙_8，tools27）；0 不停


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('godot')
    ap.add_argument('project')
    ap.add_argument('--jobs', type=int, default=None)
    ap.add_argument('--full', action='store_true', help='不沿用上轮结果，整轮重跑（也可 CHECK_FULL=1）')
    ap.add_argument('--reuse', action='store_true', help='指定场景时也按工程指纹沿用上轮通过结果（检查.sh 选测用）')
    ap.add_argument('--log-dir', type=Path, default=Path(os.environ['CHECK_LOG_DIR']) if os.environ.get('CHECK_LOG_DIR') else None,
                    help='每个场景的完整输出写到这里；不给时用 04_验证/本地结果/并行测试/<时间戳>/')
    ap.add_argument('--quiet', action='store_true', help='不打通过行，只打失败、偶发、提示、心跳与汇总')
    ap.add_argument('--names-file', type=Path, action='append', default=[], metavar='文件',
                    help='场景名或前缀每行一个（# 起为注释），与命令行名字合并；选测清单、复跑失败项用（哪吒_8）')
    ap.add_argument('--skip-generated-check', action='store_true', help='worktree 里不比对 generated/ 与主工作区（也可 XIYOU_SKIP_GENERATED_CHECK=1）')
    ap.add_argument('--wide', action='store_true', help='允许不带 * 的短前缀扩出超过 XIYOU_PREFIX_STOP（默认 40）个场景')
    ap.add_argument('names', nargs='*')
    a = ap.parse_intermixed_args()
    for f in a.names_file:
        a.names += [l.split('#', 1)[0].strip() for l in f.read_text().splitlines() if l.split('#', 1)[0].strip()]
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
        # 名字默认只按全名匹配（tools38，白龙_8：xiyou_battle、xiyou_rules 这类短名按前缀会一下排进 9／23 个场景）；
        # 要前缀就显式写「前缀*」。回退：XIYOU_BARE_PREFIX=1 回到不带 * 也按前缀（再按下面的 PREFIX_STOP 把关）。
        bare_prefix = os.environ.get('XIYOU_BARE_PREFIX', '') not in ('', '0')
        wanted = [n[:-1] if n.endswith('*') else n for n in a.names]
        wide, notes = [], []
        for raw, n in zip(a.names, wanted):
            starred = raw.endswith('*')
            hit = [s for s in scenes if s.startswith(n) and s not in (n, n + '.tscn')]
            if starred or bare_prefix:
                # 前缀一次带出很多场景时提示一行（如误写 xiyou_ 选中两百多个），免得以为只跑了几个（哪吒_8）
                if len(hit) > PREFIX_HINT:
                    print('  · 前缀 %s 匹配 %d 个场景（%s 等）；要精确选就写全名' % (n, len(hit), '、'.join(hit[:3])))
                if PREFIX_STOP and not starred and len(hit) > PREFIX_STOP:
                    wide.append((n, len(hit)))
            elif hit and any(sc == n or sc == n + '.tscn' for sc in scenes):
                notes.append('%s 只按全名选 1 个；另有 %d 个同前缀场景没选（%s 等），要它们写成「%s*」' % (n, len(hit), '、'.join(hit[:2]), n))
        if bare_prefix:
            selected = [s for s in scenes if any(s == n or s == n + '.tscn' or s.startswith(n) for n in wanted)]
        else:
            selected = [s for s in scenes if any(s == n or s == n + '.tscn' or (r.endswith('*') and s.startswith(n))
                                                for r, n in zip(a.names, wanted))]
        for note in notes:
            print('  · ' + note)
        for raw, n in zip(a.names, wanted):
            if not raw.endswith('*') and not bare_prefix and not any(s == n or s == n + '.tscn' for s in scenes):
                print('  ⚠ %s 不是场景全名，没选到%s' % (raw, '（前缀要写成「%s*」，能匹配 %d 个）' % (n, len([sc for sc in scenes if sc.startswith(n)])) if any(sc.startswith(n) for sc in scenes) else ''))
        if wide and not a.wide and len(selected) > PREFIX_STOP:
            print('  ✗ 前缀扩出的场景太多，先停下：%s。要的就是这些就把名字写成「前缀*」或加 --wide；'
                  '只想跑一个就写全名（XIYOU_PREFIX_STOP=0 关掉这道检查）' % '、'.join('%s → %d 个' % w for w in wide))
            return 2
        scenes = selected
    if not scenes:
        print('  ✗ tests/ 下没有匹配的测试场景')
        return 1
    if not a.skip_generated_check and os.environ.get('XIYOU_SKIP_GENERATED_CHECK', '') in ('', '0'):
        stale = stale_generated(a.project)
        if stale:
            print(stale)
            return 2
    sdir = state_dir(a.project)
    missing = missing_classes(a.project)
    if missing:
        # 只在缓存缺类名时导入一次（占一个共用槽，与 检查.sh 的导入相同，最多 300 秒）；导入失败照常往下跑，由测试报错
        print('  · 导入缓存缺 %d 个类名（%s 等），先 godot --import 一次' % (len(missing), '、'.join(missing[:3])), flush=True)
        with global_slot(sdir, limit, priority=slot_priority(a.project)):
            try:
                p = subprocess.run([a.godot, '--headless', '--path', a.project, '--import'], capture_output=True, text=True, timeout=300)
                if p.returncode:
                    print('  ⚠ godot --import 退出码 %d' % p.returncode, flush=True)
            except subprocess.TimeoutExpired:
                print('  ⚠ godot --import 超过 300 秒，未完成', flush=True)
    whole = not a.names
    # RULES_ONLY_* 过滤时 xiyou_rules 非 part0 只记 1 项成功，指纹又不含过滤值：过滤运行不读写沿用记录（沙僧第四期 T1）
    # 原始值非空就算过滤（沙僧第五期 C2：原来 .strip() 把纯制表符当没设，xiyou_rules 却把它解析成编号 0、非 part0 只报 1 项，
    # 写进普通沿用账后清环境仍沿用）
    filtered = [k for k in RULES_FILTER_ENV if os.environ.get(k, '') != '']
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
    attempts = {}  # 场景 → [(rc, out, secs, cpu), …]：首次在前，重跑依次追加，不覆盖
    started = time.monotonic()
    progress = Progress(len(todo))
    express = express_eligible(todo, timings)
    if express:
        print('  （快车道：%d 个短场景，先试不排共用槽）' % len(todo), flush=True)
    flaky = []
    # --quiet 也打心跳：长任务里加 --quiet 时整段没输出，被一小时无输出看门狗杀掉（八戒 dev.206）；心跳 5 分钟一行，管道给 tail 时看不到
    with heartbeat(progress, float(os.environ.get('XIYOU_TEST_HEARTBEAT', HEARTBEAT))):
        with cf.ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for name, rc, out, secs, cpu in pool.map(lambda n: run_one(a.godot, a.project, n, sdir, limit, progress, express), todo):
                attempts[name] = [(rc, out, secs, cpu)]
        failed = [n for n in todo if not result_ok(*attempts[n][0][:2])]
        if NO_RERUN_PARSE_ERROR:
            # 脚本解析错误（FATAL_LOAD 提前终止，rc 143）是确定的，重跑只会再等一次槽、再报一次（白龙 garou3）
            failed = [n for n in failed if not (attempts[n][0][0] == 143 and FATAL_LOAD.search(attempts[n][0][1]))]
        if a.jobs > 1 and len(todo) > 1 and 0 < len(failed) <= FLAKY_RERUN_MAX:
            progress.total += len(failed)
            for name in failed:
                again = run_one(a.godot, a.project, name, sdir, limit, progress)[1:]
                attempts[name].append(again)
                if result_ok(again[0], again[1]):
                    flaky.append(name)
    final = {n: result_ok(*attempts[n][-1][:2]) for n in todo}
    fail = 0
    failed_logs = {}  # 失败场景 → 最后一次的日志，收尾单列
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
            for i, (_, out, _, _) in enumerate(tries):
                (a.log_dir / (Path(name).stem + ('.rerun%d' % i if i else '') + '.log')).write_text(out)
        rc, out, secs, _ = tries[-1]
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
            if rc == 143 and FATAL_LOAD.search(out):
                print('      脚本解析错误：改好后可先跑 07_开发环境/语法检查.py（只载工程、不跑场景、不等测试槽）确认')
            failed_logs[name] = a.log_dir / (Path(name).stem + ('.rerun%d' % (len(tries) - 1) if len(tries) > 1 else '') + '.log')
            print('      完整输出：' + str(failed_logs[name]))
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
            'fingerprint': fingerprint, 'reused': sorted(reused), 'failed': sorted(failed_logs),
            'scenes': [{'name': n, 'seconds': round(attempts[n][0][2], 3), 'passed': final[n],
                        'userCpuSeconds': attempts[n][0][3]['user'],
                        'attempts': [{'rc': t[0], 'seconds': round(t[2], 3), 'userCpuSeconds': t[3]['user'], 'sysCpuSeconds': t[3]['sys'],
                                      'passed': result_ok(t[0], t[1])} for t in attempts[n]]}
                       for n in sorted(todo, key=lambda n: attempts[n][0][2], reverse=True)]
        }, ensure_ascii=False, indent=2) + '\n')
        print('  · 日志：' + str(a.log_dir))
    # 收尾单列失败场景与日志（哪吒_7 t4）：长任务日志里逐场景明细夹在几百行进度中间，曾因找不到失败项整轮重跑；
    # CHECK_FAILED_FILE 给 检查.sh 收尾汇总用（每行「场景\t日志」，通过时清空）
    if failed_logs:
        print('  ✗ 失败场景 %d 个：' % len(failed_logs))
        for n, path in failed_logs.items():
            print('      %s → %s' % (n, path))
    if os.environ.get('CHECK_FAILED_FILE'):
        Path(os.environ['CHECK_FAILED_FILE']).write_text(''.join('%s\t%s\n' % kv for kv in failed_logs.items()))
    return fail


if __name__ == '__main__':
    sys.exit(main())
