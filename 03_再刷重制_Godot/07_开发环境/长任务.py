#!/usr/bin/env python3
"""Run an owned process group, tee its log, and publish an unambiguous terminal result."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid


def atomic(path, text):
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=path.name + '.')
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(text)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def status_path(log):
    return Path(str(log) + '.status.json')


def process_table():
    """Read only process identities, never command arguments or environment values."""
    result = subprocess.run(['ps', '-axo', 'pid=,pgid=,stat=,lstart='],
                            capture_output=True, text=True, check=True, env=dict(os.environ, LC_ALL='C'))
    rows = {}
    for line in result.stdout.splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4:
            pid, group = int(parts[0]), int(parts[1])
            rows[pid] = {'pid': pid, 'pgid': group, 'startedAt': parts[3], 'zombie': parts[2].startswith('Z')}
    return rows


def identity(row):
    return {k: row[k] for k in ('pid', 'pgid', 'startedAt')} if row else None


def recover_abandoned(log, job):
    """Caller owns the released wrapper lock. Never signal an unverified process group."""
    group, expected = job.get('childPGID'), job.get('childIdentity')
    rows = process_table()
    if type(group) is not int or group <= 1:
        reason = '任务包装器已失联；旧状态缺少子进程身份，无法确认任务已结束'
    else:
        members = [r for r in rows.values() if r['pgid'] == group and not r['zombie']]
        leader = rows.get(group)
        if members and (not expected or expected.get('pid') != group or identity(leader) != expected):
            reason = '任务包装器已失联；进程组身份无法核实，未终止未知进程，不能确认任务已结束'
        else:
            if members:
                # The same leader is still present, authenticating this run's group.
                # Recheck immediately before signalling to reject a reused PID/PGID.
                if identity(process_table().get(group)) != expected:
                    reason = '进程组身份已改变，不能确认旧任务已结束'
                else:
                    signal_group(group, signal.SIGTERM)
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline:
                        if not any(r['pgid'] == group and not r['zombie'] for r in process_table().values()):
                            break
                        time.sleep(.05)
                    else:
                        signal_group(group, signal.SIGKILL)
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline and any(
                            r['pgid'] == group and not r['zombie'] for r in process_table().values()):
                        time.sleep(.05)
                    reason = ('旧进程组仍未退出，不能确认任务已结束' if any(
                        r['pgid'] == group and not r['zombie'] for r in process_table().values()) else None)
            else:
                reason = None
            if reason is None:
                job.update(status='stuck', exitCode=124, reason='任务包装器失联；已确认旧任务进程组退出',
                           finishedAt=dt.datetime.now(dt.timezone.utc).isoformat())
                with Path(log).open('a') as output:
                    output.write('\nTASK_RESULT=' + json.dumps(job, ensure_ascii=False) + '\n')
                atomic(Path(str(log) + '.exit'), '124\n')
                atomic(status_path(Path(log)), json.dumps(job, ensure_ascii=False) + '\n')
                return 124
    job.update(status='orphaned', exitCode=None, reason=reason)
    job.pop('finishedAt', None)
    Path(str(log) + '.exit').unlink(missing_ok=True)
    atomic(status_path(Path(log)), json.dumps(job, ensure_ascii=False) + '\n')
    print(reason, file=sys.stderr)
    return 2


def signal_group(group, sig):
    """给本任务自己的进程组发信号。macOS 上组里有不能发信号的成员（或刚退出的僵尸）时 killpg 抛 PermissionError：
    退一步逐个给进程表里属于该组的 pid 发，发不到的跳过（2026-10-26 哪吒：悟空 sync11 包装器因此崩掉，状态停在 running）。
    返回 False 表示组已不存在。"""
    try:
        os.killpg(group, sig)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    try:
        members = [r['pid'] for r in process_table().values() if r['pgid'] == group and not r['zombie']]
    except (OSError, subprocess.SubprocessError):
        members = [group]
    for pid in members:
        try:
            os.kill(pid, sig)
        except (ProcessLookupError, PermissionError):
            pass
    return bool(members)


def stop(proc):
    """尽力停掉任务进程组；不抛异常，调用方随后照常写终态（status 与 .exit）。"""
    try:
        if not signal_group(proc.pid, signal.SIGTERM):
            return
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            pass
        # The group may still contain a child holding the log pipe after its parent exited.
        signal_group(proc.pid, signal.SIGKILL)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
    except Exception as error:  # 停不干净也要让包装器活着写终态
        print('停止任务进程组时出错：%s' % error, file=sys.stderr)


def run(log, command, idle=3600, poll=0.2):
    log = Path(log).resolve()
    log.parent.mkdir(parents=True, exist_ok=True)
    with Path(str(log) + '.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('同一日志已有任务运行', file=sys.stderr)
            return 2
        try:
            previous = json.loads(status_path(log).read_text())
        except (OSError, ValueError):
            previous = {}
        if previous.get('status') in ('running', 'orphaned'):
            if recover_abandoned(log, previous) == 2:
                return 2
        job = {'runId': uuid.uuid4().hex, 'status': 'running', 'exitCode': None, 'pid': os.getpid(),
               'startedAt': dt.datetime.now(dt.timezone.utc).isoformat(), 'command': command,
               'childPGID': None, 'childIdentity': None}
        Path(str(log) + '.exit').unlink(missing_ok=True)
        atomic(status_path(log), json.dumps(job) + '\n')
        print('TASK_LOG=' + str(log), flush=True)
        proc, reader = None, None
        code, state = 1, 'failed'
        with log.open('wb') as output:
            last = [time.monotonic()]
            def forward():
                while True:
                    chunk = proc.stdout.read1(4096)
                    if not chunk:
                        break
                    output.write(chunk)
                    output.flush()
                    last[0] = time.monotonic()
                    try:
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                    except BrokenPipeError:
                        pass
            interrupted_code = [130]
            old_term = signal.getsignal(signal.SIGTERM)
            def interrupted(_signum, _frame):
                interrupted_code[0] = 128 + _signum
                raise KeyboardInterrupt
            signal.signal(signal.SIGTERM, interrupted)
            try:
                env = dict(os.environ, XIYOU_LONG_TASK_MANAGED='1', PYTHONUNBUFFERED='1')
                proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        env=env, start_new_session=True)
                job.update(childPGID=proc.pid, childIdentity=identity(process_table().get(proc.pid)))
                atomic(status_path(log), json.dumps(job) + '\n')
                reader = threading.Thread(target=forward, daemon=True)
                reader.start()
                while proc.poll() is None:
                    if idle > 0 and time.monotonic() - last[0] > idle:
                        state, code = 'stuck', 124
                        stop(proc)
                        break
                    time.sleep(poll)
                else:
                    code = proc.returncode if proc.returncode >= 0 else 128 - proc.returncode
                    state = 'done' if code == 0 else 'failed'
                reader.join(timeout=3)
                if reader.is_alive():
                    stop(proc)
                    reader.join(timeout=3)
                    state, code = 'failed', 1
            except KeyboardInterrupt:
                if proc:
                    stop(proc)
                state, code = 'failed', interrupted_code[0]
            except Exception as error:
                output.write((str(error) + '\n').encode())
            finally:
                signal.signal(signal.SIGTERM, old_term)
                if reader and reader.is_alive():
                    reader.join(timeout=3)
                # A command may exit after spawning descendants which closed stdout.
                # A quiet pipe alone does not prove the owned process group has ended.
                if proc and any(r['pgid'] == proc.pid and not r['zombie'] for r in process_table().values()):
                    stop(proc)
                    state, code = 'failed', 1
                    deadline = time.monotonic() + 3
                    while time.monotonic() < deadline and any(
                            r['pgid'] == proc.pid and not r['zombie'] for r in process_table().values()):
                        time.sleep(.05)
                    if any(r['pgid'] == proc.pid and not r['zombie'] for r in process_table().values()):
                        job.update(status='orphaned', exitCode=None, reason='旧任务进程组未退出，不能确认任务已结束')
                        atomic(status_path(log), json.dumps(job, ensure_ascii=False) + '\n')
                        print(job['reason'], file=sys.stderr)
                        return 2
                job.update(status=state, exitCode=code, finishedAt=dt.datetime.now(dt.timezone.utc).isoformat())
                marker = 'TASK_RESULT=' + json.dumps(job, ensure_ascii=False) + '\n'
                output.write(b'\n' + marker.encode())
                output.flush()
                # The terminal status is published last, after the marker and exit code.
                atomic(Path(str(log) + '.exit'), str(code) + '\n')
                atomic(status_path(log), json.dumps(job, ensure_ascii=False) + '\n')
                print(marker, end='', flush=True)
        return code


def wait(log, timeout=0, poll=0.2):
    start, run_id = time.monotonic(), None
    while True:
        try:
            state = json.loads(status_path(Path(log)).read_text())
        except (OSError, ValueError):
            print('没有有效的任务状态：' + str(log), file=sys.stderr)
            return 2
        if run_id is None:
            run_id = state.get('runId')
        if not run_id or run_id != state.get('runId'):
            print('日志已被另一轮任务替换', file=sys.stderr)
            return 2
        if state.get('status') in ('done', 'failed', 'stuck'):
            try:
                code = int(Path(str(log) + '.exit').read_text())
                last = Path(log).read_bytes().splitlines()[-1].decode('utf-8')
                if not last.startswith('TASK_RESULT='):
                    raise ValueError('缺少任务结果标记')
                marker = json.loads(last.removeprefix('TASK_RESULT='))
                if marker != state or code != state['exitCode']:
                    raise ValueError('任务结果不一致')
            except (OSError, ValueError, IndexError, KeyError):
                return 2
            print('TASK_RESULT=' + json.dumps(state, ensure_ascii=False))
            return code
        if state.get('status') == 'orphaned':
            print(state.get('reason', '旧任务失联，不能确认已结束'), file=sys.stderr)
            return 2
        # A held lock identifies the live wrapper. PID existence alone can point to
        # an unrelated process after PID reuse or a reboot.
        with Path(str(log) + '.lock').open('a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                pass
            else:
                current = json.loads(status_path(Path(log)).read_text())
                if current.get('runId') != run_id or current.get('status') != 'running':
                    continue
                code = recover_abandoned(log, current)
                if code == 2:
                    return code
                continue
        if timeout > 0 and time.monotonic() - start >= timeout:
            print('等待超时；任务状态仍为running', file=sys.stderr)
            return 124
        time.sleep(poll)


def start(log, command, idle=3600):
    """在新会话里启动 run 后立即返回：启动它的会话被停（如 Remote Control 空闲）时任务不随之停止。
    等状态文件出现本轮 runId 才打印 TASK_LOG，之后照常用 wait。run 自己的报错写在 <日志>.start.err。"""
    log = Path(log).resolve()
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        before = json.loads(status_path(log).read_text()).get('runId')
    except (OSError, ValueError):
        before = None
    err = Path(str(log) + '.start.err')
    with open(os.devnull, 'rb') as null_in, open(os.devnull, 'wb') as null_out, err.open('wb') as err_out:
        proc = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'run', str(log), '--idle-timeout', str(idle),
                                 '--', *command], stdin=null_in, stdout=null_out, stderr=err_out, start_new_session=True)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        try:
            state = json.loads(status_path(log).read_text())
        except (OSError, ValueError):
            state = {}
        if state.get('runId') not in (None, before) and state.get('pid') == proc.pid:
            print('TASK_LOG=' + str(log), flush=True)
            return 0
        if proc.poll() is not None:
            print('任务未能启动（退出码 %d）：%s' % (proc.returncode, err.read_text(errors='replace').strip()), file=sys.stderr)
            return proc.returncode or 2
        time.sleep(.05)
    print('任务启动后 30 秒仍未写出状态：' + str(log), file=sys.stderr)
    return 2


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='mode', required=True)
    runner = sub.add_parser('run')
    runner.add_argument('log', type=Path)
    runner.add_argument('--idle-timeout', type=float, default=float(os.environ.get('TASK_IDLE_TIMEOUT', '3600')))
    starter = sub.add_parser('start')
    starter.add_argument('log', type=Path)
    starter.add_argument('--idle-timeout', type=float, default=float(os.environ.get('TASK_IDLE_TIMEOUT', '3600')))
    waiter = sub.add_parser('wait')
    waiter.add_argument('log', type=Path)
    waiter.add_argument('--timeout', type=float, default=0)
    argv = sys.argv[1:]
    command = []
    if argv[:1] in (['run'], ['start']) and '--' in argv:
        sep = argv.index('--')
        command, argv = argv[sep + 1:], argv[:sep]
    a = ap.parse_args(argv)
    if a.mode == 'wait':
        return wait(a.log, a.timeout)
    if not command:
        ap.error('缺少任务命令')
    if a.mode == 'start':
        return start(a.log, command, a.idle_timeout)
    return run(a.log, command, a.idle_timeout)


if __name__ == '__main__':
    sys.exit(main())
