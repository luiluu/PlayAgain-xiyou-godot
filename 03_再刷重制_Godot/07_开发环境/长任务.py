#!/usr/bin/env python3
"""Run an owned process group, tee its log, and publish an unambiguous terminal result."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import shutil
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


def run(log, command, idle=3600, poll=0.2, start_token=None):
    log = Path(log).resolve()
    attach = os.environ.pop('XIYOU_LONG_TASK_ERR', None)
    if attach:   # launchd 起的：把 stderr 从临时落点接回 <日志>.start.err，再删掉临时文件（tools82）
        try:
            with open(attach, 'ab') as f:
                os.dup2(f.fileno(), 2)
            label = os.environ.get('XIYOU_LONG_TASK_LABEL')
            if label:
                launchd_err_path(label).unlink(missing_ok=True)
        except OSError:
            pass
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
        if start_token:
            job['startToken'] = start_token
        label = os.environ.get('XIYOU_LONG_TASK_LABEL')
        if label:
            job['launchdLabel'] = label
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
                env.pop('XIYOU_LONG_TASK_LABEL', None)  # 任务里再嵌套 run 时不要认成自己的作业
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
                orphaned = False
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
                        orphaned = True
                if not orphaned:  # 不在 finally 里 return（SyntaxWarning）；失联时跳过收尾，出 finally 后返回 2
                    job.update(status=state, exitCode=code, finishedAt=dt.datetime.now(dt.timezone.utc).isoformat())
                    marker = 'TASK_RESULT=' + json.dumps(job, ensure_ascii=False) + '\n'
                    output.write(b'\n' + marker.encode())
                    output.flush()
                    # The terminal status is published last, after the marker and exit code.
                    atomic(Path(str(log) + '.exit'), str(code) + '\n')
                    atomic(status_path(log), json.dumps(job, ensure_ascii=False) + '\n')
                    print(marker, end='', flush=True)
            if orphaned:
                return 2
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
            cleanup_finished_launchd(state.get('launchdLabel'))
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


LAUNCHD_PREFIX = 'xiyou.longtask.'


def launchd_enabled():
    """macOS 上默认用 launchd 起任务（XIYOU_LONG_TASK_LAUNCHD=0 退回旧做法）。"""
    return (sys.platform == 'darwin' and os.environ.get('XIYOU_LONG_TASK_LAUNCHD', '1') != '0'
            and shutil.which('launchctl') is not None)


def launchd_jobs():
    """launchctl list 里本工具的作业：{label: 运行中的 pid 或 None}。"""
    try:
        out = subprocess.run(['launchctl', 'list'], capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    jobs = {}
    for line in out.splitlines():
        parts = line.split('\t')
        if len(parts) == 3 and parts[2].startswith(LAUNCHD_PREFIX):
            jobs[parts[2]] = int(parts[0]) if parts[0].strip().isdigit() else None
    return jobs


def launchd_bootout(label):
    subprocess.run(['launchctl', 'bootout', 'gui/%d/%s' % (os.getuid(), label)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)


def sweep_launchd(min_age=120):
    """卸掉已结束的旧作业（作业不保活，结束后只剩一条登记）。只动 label 里时间戳超过 min_age 秒的，
    免得把别的会话刚登记、还没起来的作业卸掉。"""
    now = time.time()
    for label, pid in launchd_jobs().items():
        try:
            stamp = int(label[len(LAUNCHD_PREFIX):].split('.')[0])
        except ValueError:
            continue
        if pid is None and now - stamp > min_age:
            try:
                launchd_bootout(label)
                launchd_err_path(label).unlink(missing_ok=True)
            except (OSError, subprocess.SubprocessError):
                pass


def launchd_err_path(label):
    """launchd 作业的 stderr 落点：放在每用户临时目录，不放日志旁边（tools82：日志在 ~/Documents 下时，launchd 打不开那里
    已存在的文件——受「文件与文件夹」隐私保护，作业以 EX_CONFIG 起不来；run 起来后自己把 stderr 接回 <日志>.start.err）。"""
    return Path(tempfile.gettempdir()) / (label + '.err')


def submit_launchd(label, argv, err):
    """把 run 交给 launchd 起（gui 域，不保活）。这样任务的父进程是 launchd、macOS「责任进程」是它自己，
    发起它的 claude 会话被关时 app 按责任进程连带清理也清不到它（哪吒 tools81：原来 start_new_session
    只换了会话和父进程，责任进程仍是 claude，换源同步两次被 143 掐断）。
    环境变量与工作目录照搬当前进程；plist 只在登记那一刻存在（0600），登记完即删。
    不设 LaunchOnlyOnce：起不来时作业留着，start 能读到 last exit code 再卸掉（tools82）。"""
    import plistlib
    import resource
    env = {k: v for k, v in os.environ.items() if k != '__CF_USER_TEXT_ENCODING'}
    env['XIYOU_LONG_TASK_LABEL'] = label
    env['XIYOU_LONG_TASK_ERR'] = str(err)
    limits = {}
    for key, which in (('NumberOfFiles', resource.RLIMIT_NOFILE), ('NumberOfProcesses', resource.RLIMIT_NPROC)):
        soft = resource.getrlimit(which)[0]
        if soft != resource.RLIM_INFINITY:
            limits[key] = soft
    job = {'Label': label, 'ProgramArguments': argv, 'WorkingDirectory': os.getcwd(), 'EnvironmentVariables': env,
           'RunAtLoad': True, 'KeepAlive': False, 'AbandonProcessGroup': True,
           'ProcessType': 'Standard', 'StandardInPath': os.devnull, 'StandardOutPath': os.devnull,
           'StandardErrorPath': str(launchd_err_path(label)), 'Umask': os.umask(0o022)}
    os.umask(job['Umask'])
    if limits:
        job['SoftResourceLimits'] = limits
    err.write_bytes(b'')
    fd, plist = tempfile.mkstemp(prefix=label + '.', suffix='.plist')
    try:
        with os.fdopen(fd, 'wb') as f:
            plistlib.dump(job, f)
        p = subprocess.run(['launchctl', 'bootstrap', 'gui/%d' % os.getuid(), plist],
                           capture_output=True, text=True, timeout=30)
    finally:
        Path(plist).unlink(missing_ok=True)
    if p.returncode:
        raise OSError('launchctl bootstrap 失败（%d）：%s' % (p.returncode, (p.stderr or p.stdout).strip()))


def launchd_failure(label):
    """作业没写出状态就结束时的原因：last exit code 与它的 stderr（读完即删）。"""
    why = []
    try:
        out = subprocess.run(['launchctl', 'print', 'gui/%d/%s' % (os.getuid(), label)],
                             capture_output=True, text=True, timeout=10).stdout
        why += [l.strip() for l in out.splitlines() if l.strip().startswith('last exit code')][:1]
    except (OSError, subprocess.SubprocessError):
        pass
    path = launchd_err_path(label)
    try:
        text = path.read_text(errors='replace').strip()
        if text:
            why.append(text[-500:])
        path.unlink()
    except OSError:
        pass
    if any('78' in w and 'EX_CONFIG' in w for w in why):
        why.append('launchd 打不开作业的标准输出／错误路径或工作目录（常见于 ~/Documents 等受隐私保护的目录）')
    return '；'.join(why) or '作业已结束，没有留下原因'


def cleanup_finished_launchd(label):
    """wait 看到终态后卸掉那条已结束的 launchd 登记；还在跑（包装器正在退出）就留给下次 start 的清扫。"""
    if not label or not str(label).startswith(LAUNCHD_PREFIX) or not launchd_enabled():
        return
    try:
        if label in launchd_jobs() and launchd_jobs().get(label) is None:
            launchd_bootout(label)
    except (OSError, subprocess.SubprocessError):
        pass


def start(log, command, idle=3600):
    """脱离发起它的会话启动 run 后立即返回：会话被关（Remote Control 空闲、app 关掉会话）时任务不随之停止。
    macOS 上交给 launchd 起（见 submit_launchd）；没有 launchctl 或 XIYOU_LONG_TASK_LAUNCHD=0 时退回
    start_new_session 子进程。等状态文件出现本轮启动令牌才打印 TASK_LOG，之后照常用 wait。
    run 自己的报错写在 <日志>.start.err。"""
    log = Path(log).resolve()
    log.parent.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    err = Path(str(log) + '.start.err')
    argv = [sys.executable, str(Path(__file__).resolve()), 'run', str(log), '--idle-timeout', str(idle),
            '--start-token', token, '--', *command]
    proc, label = None, None
    if launchd_enabled():
        sweep_launchd()
        label = '%s%d.%s' % (LAUNCHD_PREFIX, int(time.time()), token[:12])
        try:
            submit_launchd(label, argv, err)
        except (OSError, subprocess.SubprocessError) as error:
            print('launchd 启动失败，退回子进程方式：%s' % error, file=sys.stderr)
            label = None
    if label is None:
        with open(os.devnull, 'rb') as null_in, open(os.devnull, 'wb') as null_out, err.open('wb') as err_out:
            proc = subprocess.Popen(argv, stdin=null_in, stdout=null_out, stderr=err_out, start_new_session=True)
    deadline, seen_running, idle_since = time.monotonic() + 30, False, time.monotonic()
    while time.monotonic() < deadline:
        try:
            state = json.loads(status_path(log).read_text())
        except (OSError, ValueError):
            state = {}
        if state.get('startToken') == token:
            print('TASK_LOG=' + str(log), flush=True)
            return 0
        if proc is not None and proc.poll() is not None:
            print('任务未能启动（退出码 %d）：%s' % (proc.returncode, err.read_text(errors='replace').strip()), file=sys.stderr)
            return proc.returncode or 2
        if label is not None:
            pid = launchd_jobs().get(label, 'gone')
            if isinstance(pid, int):
                seen_running = True
            elif pid == 'gone' or seen_running or time.monotonic() > idle_since + 5:
                # 作业已结束（或登记 5 秒仍没起来）却没写出本轮状态：退回子进程方式再起一次（tools82）。
                # run 自己起来后报的错（如同一日志已有任务在跑）退回后照样会报出来
                time.sleep(.2)
                try:
                    if json.loads(status_path(log).read_text()).get('startToken') == token:
                        continue
                except (OSError, ValueError):
                    pass
                why = launchd_failure(label)
                launchd_bootout(label)
                print('launchd 作业没写出状态就结束（%s），退回子进程方式' % why, file=sys.stderr)
                label = None
                with open(os.devnull, 'rb') as null_in, open(os.devnull, 'wb') as null_out, err.open('wb') as err_out:
                    proc = subprocess.Popen(argv, stdin=null_in, stdout=null_out, stderr=err_out, start_new_session=True)
                deadline = time.monotonic() + 30
                continue
        time.sleep(.05 if label is None else .2)
    print('任务启动后 30 秒仍未写出状态：' + str(log), file=sys.stderr)
    return 2


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='mode', required=True)
    runner = sub.add_parser('run')
    runner.add_argument('log', type=Path)
    runner.add_argument('--idle-timeout', type=float, default=float(os.environ.get('TASK_IDLE_TIMEOUT', '3600')))
    runner.add_argument('--start-token', help=argparse.SUPPRESS)
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
    return run(a.log, command, a.idle_timeout, start_token=a.start_token)


if __name__ == '__main__':
    sys.exit(main())
