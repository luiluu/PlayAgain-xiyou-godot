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


def stop(proc):
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass
    # The group may still contain a child holding the log pipe after its parent exited.
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()


def run(log, command, idle=3600, poll=0.2):
    log = Path(log).resolve()
    log.parent.mkdir(parents=True, exist_ok=True)
    with Path(str(log) + '.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('同一日志已有任务运行', file=sys.stderr)
            return 2
        job = {'runId': uuid.uuid4().hex, 'status': 'running', 'exitCode': None, 'pid': os.getpid(),
               'startedAt': dt.datetime.now(dt.timezone.utc).isoformat(), 'command': command}
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
                last = Path(log).read_text().splitlines()[-1]
                marker = json.loads(last.removeprefix('TASK_RESULT='))
                if marker != state or code != state['exitCode']:
                    raise ValueError('任务结果不一致')
            except (OSError, ValueError, IndexError, KeyError):
                return 2
            print('TASK_RESULT=' + json.dumps(state, ensure_ascii=False))
            return code
        try:
            os.kill(int(state['pid']), 0)
        except ProcessLookupError:
            # A crashed wrapper cannot emit its own terminal marker. Take its released lock,
            # recheck the run ID, and leave an explicit abandoned/stuck result.
            with Path(str(log) + '.lock').open('a') as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    time.sleep(poll)
                    continue
                current = json.loads(status_path(Path(log)).read_text())
                if current.get('runId') != run_id or current.get('status') != 'running':
                    continue
                current.update(status='stuck', exitCode=124, reason='任务进程已消失',
                               finishedAt=dt.datetime.now(dt.timezone.utc).isoformat())
                with Path(log).open('a') as output:
                    output.write('\nTASK_RESULT=' + json.dumps(current, ensure_ascii=False) + '\n')
                atomic(Path(str(log) + '.exit'), '124\n')
                atomic(status_path(Path(log)), json.dumps(current, ensure_ascii=False) + '\n')
            continue
        except PermissionError:
            pass
        except (KeyError, ValueError, TypeError):
            return 2
        if timeout > 0 and time.monotonic() - start >= timeout:
            print('等待超时；任务状态仍为running', file=sys.stderr)
            return 124
        time.sleep(poll)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='mode', required=True)
    runner = sub.add_parser('run')
    runner.add_argument('log', type=Path)
    runner.add_argument('--idle-timeout', type=float, default=float(os.environ.get('TASK_IDLE_TIMEOUT', '3600')))
    waiter = sub.add_parser('wait')
    waiter.add_argument('log', type=Path)
    waiter.add_argument('--timeout', type=float, default=0)
    argv = sys.argv[1:]
    command = []
    if argv[:1] == ['run'] and '--' in argv:
        sep = argv.index('--')
        command, argv = argv[sep + 1:], argv[:sep]
    a = ap.parse_args(argv)
    if a.mode == 'wait':
        return wait(a.log, a.timeout)
    if not command:
        ap.error('缺少任务命令')
    return run(a.log, command, a.idle_timeout)


if __name__ == '__main__':
    sys.exit(main())
