#!/usr/bin/env python3
"""并行运行 Godot 测试场景（检查.sh 调用；也可单独用来跑几个专项）。

用法：并行测试.py <godot> <工程目录> [--jobs N] [场景名或前缀 ...]
- 每个测试一个独立的临时 HOME，因此 user://（存档、配置）互不干扰，也不会读写本机真实的用户数据目录。
- 导入（--import）由调用方先单独做一次；这里只读工程缓存。
- 每个测试最多 300 秒；脚本语法错误时场景不会自行退出，超时即判失败。
- 输出与原来逐个运行时相同（按场景名排序），失败时返回 1。
- 并行数：CHECK_JOBS 或 --jobs；都没给时主工作区用 CPU 核数一半（最多 6），worktree 里只用 2（多会话并行时给其他车道留余量）。
"""
import argparse
import concurrent.futures as cf
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TIMEOUT = 300


def run_one(godot: str, project: str, name: str) -> tuple:
    start = time.time()
    with tempfile.TemporaryDirectory(prefix='xiyou_test_home_') as home:
        env = dict(os.environ, HOME=home)
        try:
            p = subprocess.run([godot, '--headless', '--path', project, 'res://tests/' + name],
                               capture_output=True, text=True, timeout=TIMEOUT, env=env)
            out, rc = p.stdout + p.stderr, p.returncode
        except subprocess.TimeoutExpired as e:
            out = (e.stdout or b'').decode(errors='replace') if isinstance(e.stdout, bytes) else (e.stdout or '')
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
    ap.add_argument('--jobs', type=int, default=0)
    ap.add_argument('names', nargs='*')
    a = ap.parse_args()
    if a.jobs <= 0:
        a.jobs = int(os.environ.get('CHECK_JOBS', '0')) or (2 if in_linked_worktree(a.project) else max(1, min(6, (os.cpu_count() or 2) // 2)))
    scenes = sorted(p.name for p in (Path(a.project) / 'tests').glob('*.tscn'))
    if a.names:
        scenes = [s for s in scenes if any(s == n or s == n + '.tscn' or s.startswith(n) for n in a.names)]
    if not scenes:
        print('  ✗ tests/ 下没有匹配的测试场景')
        return 1
    fail = 0
    results = {}
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as pool:
        for name, rc, out, secs in pool.map(lambda n: run_one(a.godot, a.project, n), scenes):
            results[name] = (rc, out, secs)
    for name in scenes:
        rc, out, secs = results[name]
        line = next((l for l in out.splitlines() if l.startswith('TEST_RESULT=')), '')
        if rc == 0 and line and not re.search(r'SCRIPT ERROR|^ERROR:', out, re.M):
            print(('  ✓ %s %s' % (name, line[len('TEST_RESULT='):]))[:120])
        else:
            fail = 1
            print('  ✗ %s (rc=%d)' % (name, rc))
            for l in [l for l in out.splitlines() if re.search(r'ERROR|FAIL |passed|TEST_RESULT', l)][:8]:
                print('      ' + l)
    return fail


if __name__ == '__main__':
    sys.exit(main())
