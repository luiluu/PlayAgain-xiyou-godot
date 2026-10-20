#!/usr/bin/env python3
"""并行运行 Godot 测试场景（检查.sh 调用；也可单独用来跑几个专项）。

用法：并行测试.py <godot> <工程目录> [--jobs N] [场景名或前缀 ...]
- 每个测试一个独立的临时 HOME，因此 user://（存档、配置）互不干扰，也不会读写本机真实的用户数据目录。
- 导入（--import）由调用方先单独做一次；这里只读工程缓存。
- 每个测试最多 600 秒；脚本语法错误时场景不会自行退出，超时即判失败。用时超过一半（300 秒）时提示拆场景。
- 并行时只有少数（≤3）测试失败的，逐个单独重跑一次：单跑通过记为「偶发」，仍算通过但打印 ⚠，写进交付单；单跑仍失败才判失败。
- 输出与原来逐个运行时相同（按场景名排序），失败时返回 1。
- 并行数：CHECK_JOBS 或 --jobs；都没给时主工作区用 CPU 核数一半（最多 6），worktree 里只用 2（多会话并行时给其他车道留余量）。
"""
import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TIMEOUT = 600  # xiyou_rules 角色 P0 后单跑约 200 秒，满负载并行时超过 300
SLOW = TIMEOUT // 2  # 超过就提示按场景拆分（xiyou_rules 已拆 a／b）
FLAKY_RERUN_MAX = 3  # 并行负载下偶发失败（floor16、floor_run_c 等）最多单独重跑这么多个


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


def run_one(godot: str, project: str, name: str) -> tuple:
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
    return name, rc, out, time.time() - start


def in_linked_worktree(path: str) -> bool:
    """是否在 git worktree（而不是主工作区）里：git-dir 与 git-common-dir 不同。"""
    try:
        out = subprocess.run(['git', '-C', path, 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'],
                             capture_output=True, text=True, check=True).stdout.split('\n')
        return out[0] != out[1]
    except (OSError, subprocess.CalledProcessError, IndexError):
        return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('godot')
    ap.add_argument('project')
    ap.add_argument('--jobs', type=int, default=None)
    ap.add_argument('--log-dir', type=Path, default=Path(os.environ['CHECK_LOG_DIR']) if os.environ.get('CHECK_LOG_DIR') else None)
    ap.add_argument('names', nargs='*')
    a = ap.parse_intermixed_args()
    if a.jobs is None:
        a.jobs = int(os.environ.get('CHECK_JOBS', '0')) or (2 if in_linked_worktree(a.project) else max(1, min(6, (os.cpu_count() or 2) // 2)))
    if a.jobs < 1:
        ap.error('--jobs 必须大于 0')
    scenes = sorted(p.name for p in (Path(a.project) / 'tests').glob('*.tscn'))
    if a.names:
        scenes = [s for s in scenes if any(s == n or s == n + '.tscn' or s.startswith(n) for n in a.names)]
    if not scenes:
        print('  ✗ tests/ 下没有匹配的测试场景')
        return 1
    fail = 0
    results = {}
    started = time.monotonic()
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as pool:
        for name, rc, out, secs in pool.map(lambda n: run_one(a.godot, a.project, n), scenes):
            results[name] = (rc, out, secs)
    failed = [n for n in scenes if not result_ok(*results[n][:2])]
    flaky = []
    if a.jobs > 1 and len(scenes) > 1 and 0 < len(failed) <= FLAKY_RERUN_MAX:
        for name in failed:
            again = run_one(a.godot, a.project, name)
            if result_ok(again[1], again[2]):
                flaky.append(name)
                results[name] = again[1:]
    for name in scenes:
        rc, out, secs = results[name]
        if a.log_dir:
            a.log_dir.mkdir(parents=True, exist_ok=True)
            (a.log_dir / (Path(name).stem + '.log')).write_text(out)
        line = next((l for l in out.splitlines() if l.startswith('TEST_RESULT=')), '')
        if result_ok(rc, out):
            print(('  ✓ %s %s' % (name, line[len('TEST_RESULT='):]))[:120])
            if name in flaky:
                print('  ⚠ %s 并行时失败、单独重跑通过（偶发，写进交付单）' % name)
            if secs > SLOW:
                print('  ⚠ %s 用时 %d 秒，超过上限 %d 秒的一半，请按场景拆分' % (name, secs, TIMEOUT))
        else:
            fail = 1
            print('  ✗ %s (rc=%d)' % (name, rc))
            for l in [l for l in out.splitlines() if re.search(r'ERROR|FAIL |passed|TEST_RESULT', l)][:8]:
                print('      ' + l)
    if a.log_dir:
        (a.log_dir / 'test_timings.json').write_text(json.dumps({
            'jobs': a.jobs, 'wallSeconds': round(time.monotonic() - started, 3), 'flakyRerunPassed': flaky,
            'scenes': [{'name': name, 'seconds': round(results[name][2], 3),
                        'passed': result_ok(results[name][0], results[name][1])}
                       for name in sorted(scenes, key=lambda n: results[n][2], reverse=True)]
        }, ensure_ascii=False, indent=2) + '\n')
    return fail


if __name__ == '__main__':
    sys.exit(main())
