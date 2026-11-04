#!/usr/bin/env python3
"""推送重试.py：给 git push 加 GitHub 服务端临时故障的自动重试（tools61，审查 38 之外 11-04 上午 GitHub 连回 500）。

云端选测.py（产物快照、基准、沿用、ci 分支）和 合并车道.py（收尾推 main）共用 `retry_push`。
只重试「服务端暂时故障」：输出含 5xx／Internal Server Error／commit_refs／RPC failed／HTTP 408／unexpected disconnect
等。认证失败、non-fast-forward、权限不足等原样报错、不重试。每次重试前打印一行。
退避默认 10、30、60 秒（最多 3 次重试）；回退：环境变量 XIYOU_PUSH_RETRY=0 不重试；XIYOU_PUSH_RETRY_DELAYS=1,2,3 改间隔（测试用）。
"""
import os
import re
import sys
import time

DELAYS = (10, 30, 60)
TRANSIENT = re.compile(
    r'internal server error|commit_refs|rpc failed|http (?:code )?(?:408|5\d\d)|returned error: (?:408|5\d\d)|'
    r'\b50[0-9]\b.*(?:error|gateway|unavailable)|bad gateway|service unavailable|gateway time-?out|'
    r'unexpected disconnect|the remote end hung up unexpectedly|connection reset|timed out',
    re.I)


def transient(text):
    """输出像不像服务端临时故障。"""
    return bool(TRANSIENT.search(text or ''))


def delays():
    if os.environ.get('XIYOU_PUSH_RETRY') == '0':
        return ()
    raw = os.environ.get('XIYOU_PUSH_RETRY_DELAYS')
    if raw:
        return tuple(float(x) for x in raw.split(',') if x.strip())
    return DELAYS


def retry_push(run, label='git push', sleep=time.sleep, out=None):
    """run() 执行一次推送：成功返回，失败抛 RuntimeError（消息里带 git 的错误输出）。
    临时故障退避重试；其它错误或重试用完，重新抛出原异常。"""
    out = out or sys.stderr
    waits = list(delays())
    attempt = 0
    while True:
        try:
            return run()
        except RuntimeError as error:
            if not waits or not transient(str(error)):
                raise
            wait = waits.pop(0)
            attempt += 1
            print('[推送重试] %s 遇到服务端临时故障，%g 秒后重试（第 %d 次）：%s' % (label, wait, attempt, ' '.join(str(error).split())[-160:]),
                  file=out, flush=True)
            sleep(wait)
