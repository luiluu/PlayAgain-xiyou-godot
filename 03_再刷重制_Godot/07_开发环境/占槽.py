#!/usr/bin/env python3
"""在跨工作树共用槽（并行测试.py 的 global_slot，测试与同步探针共用）里跑一条重命令，给 shell 脚本用。

用法：占槽.py [--weight N] [--label 名字] [--notice-fd FD] -- 命令 参数…
- 先占 N 槽（默认 1），占到后跑命令，退出码原样返回；命令结束或本进程被杀时槽自动释放。
- 排队期间每 XIYOU_SLOT_HEARTBEAT 秒（默认 60）打一行「等槽：…」，默认写标准错误；
  --notice-fd 指定别的文件描述符（检查.sh 捕获导入输出时用它把心跳送回日志，长任务看门狗据此算作有进展）。
- 主工作区（或 XIYOU_SLOT_PRIORITY=1）的请求总装优先，见 并行测试.py 文件头。
"""
import argparse
import importlib.util
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('xiyou_parallel_tests', HERE / '并行测试.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if '--' not in argv:
        print('用法：占槽.py [--weight N] [--label 名字] [--notice-fd FD] -- 命令…', file=sys.stderr)
        return 64
    i = argv.index('--')
    ap = argparse.ArgumentParser()
    ap.add_argument('--weight', type=int, default=1)
    ap.add_argument('--label')
    ap.add_argument('--notice-fd', type=int)
    a = ap.parse_args(argv[:i])
    cmd = argv[i + 1:]
    if not cmd:
        return 64
    out = os.fdopen(a.notice_fd, 'w', buffering=1, closefd=False) if a.notice_fd else sys.stderr
    label = a.label or Path(cmd[0]).name
    limit = runner.global_limit()

    def waiting(seconds):
        print('等槽：%s 已等 %d 秒（占 %d 槽，共用上限 %d）' % (label, seconds, min(a.weight, limit), limit), file=out, flush=True)
    with runner.global_slot(runner.state_dir(str(HERE)), limit, a.weight, waiting,
                            float(os.environ.get('XIYOU_SLOT_HEARTBEAT', '60')), priority=runner.slot_priority(str(HERE))):
        return subprocess.run(cmd).returncode


if __name__ == '__main__':
    raise SystemExit(main())
