#!/usr/bin/env python3
"""事件探针「增量跑 vs 整轮跑」真实数据比对（期四，2026-10-25 哪吒）。

拿当前 generated/oracle/events.json（上一轮同步整轮或增量后发布的完整产物）当整轮结果，挑几个单元
（地图 m<编号>、公共事件 ce<编号>）用 XIYOU_PROBE_UNITS 单独重跑 event_probe.cjs，再用同步用的
oracle_shard_merge.cjs 把它们拼回上次产物，要求与整轮产物逐字节一致。比的就是同步增量那条路：
只跑变了的地图、其余取上次产物合并，结果必须和整轮跑完全一样。

用法：python3 03_再刷重制_Godot/03_转换工具/事件增量比对.py [--units m171,m225] [--count 3] [--trust-current]
- 默认挑切片里第一张、中间一张、最后一张地图。
- 先核对探针缓存：events.json 须是当前输入（正式源、探针、转换产物）下发布的产物，否则退出 3（先跑一次同步）；
  --trust-current 跳过这项核对（只在确知产物是当前输入跑出来的时候用）。
- 只写 mv_oracle/.sandbox/compare-events-*/ 与 .sandbox/events.json（探针固定输出处；本工作树有同步在跑时拒绝运行），
  不碰 generated；结束删掉自己的临时目录。逐字节一致退出 0，不一致退出 1 并给出第一处不同。
"""
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from incremental_sync import ProbeCache  # noqa: E402

spec = importlib.util.spec_from_file_location('xiyou_sync', HERE / '同步正式西游.py')
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)
CMD, OUTS = ['event_probe.cjs'], ['events.json']


def first_diff(a: bytes, b: bytes):
    n = next((i for i in range(min(len(a), len(b))) if a[i] != b[i]), min(len(a), len(b)))
    return {'offset': n, 'full': a[max(0, n - 120):n + 120].decode(errors='replace'),
            'merged': b[max(0, n - 120):n + 120].decode(errors='replace'), 'sizes': [len(a), len(b)]}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--units', help='逗号分隔的单元，如 m171,m225,ce12')
    ap.add_argument('--count', type=int, default=3)
    ap.add_argument('--app', type=Path, default=sync.DEFAULT_APP)
    ap.add_argument('--generated', type=Path, default=sync.DEFAULT_OUT)
    ap.add_argument('--trust-current', action='store_true')
    a = ap.parse_args(argv)
    app, gen = a.app.resolve(), a.generated.resolve()
    # 与同步用同一把锁：本工作树有同步在跑时不动 .sandbox
    import fcntl
    lock_path = sync.ROOT / '03_再刷重制_Godot/04_验证/本地结果/sync.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock = lock_path.open('a')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print('本工作树有同步在跑，先等它结束', file=sys.stderr)
        return 2
    cache = ProbeCache(HERE, app, gen)
    key, units = cache.key(CMD), cache.units(CMD)
    if units is None:
        print('event_probe.cjs 当前不能按单元分片（读取面审计未过），比对无意义；见同步日志 SHARD_OFF', file=sys.stderr)
        return 3
    if not a.trust_current and cache.plan(CMD, OUTS, key, units) != []:
        print('events.json 不是当前输入下发布的产物（缓存未命中：%s），先跑一次同步再比' %
              json.dumps(cache.misses.get(CMD[0]), ensure_ascii=False)[:600], file=sys.stderr)
        return 3
    maps = [u for u in units if u.startswith('m')]
    chosen = a.units.split(',') if a.units else sorted({maps[0], maps[len(maps) // 2], maps[-1]}, key=maps.index)[:a.count]
    unknown = [u for u in chosen if u not in units]
    if unknown:
        print('不在当前单元里：' + '、'.join(unknown), file=sys.stderr)
        return 2
    full = gen / 'oracle/events.json'
    box = sync.SANDBOX / ('compare-events-%d' % os.getpid())
    shutil.rmtree(box, ignore_errors=True)
    box.mkdir(parents=True)
    try:
        shutil.copy2(full, box / 'full.json')
        for name in ['save', 'macport']:
            if (sync.SANDBOX / name).is_dir():
                shutil.copytree(sync.SANDBOX / name, box / name)
        env = dict(os.environ, XIYOU_APP=str(app), XIYOU_GENERATED=str(gen), XIYOU_ORACLE_SANDBOX=str(box),
                   XIYOU_PROBE_UNITS=json.dumps(chosen))
        out = sync.SANDBOX / 'events.json'
        out.unlink(missing_ok=True)
        p = sync.run_node(CMD, env)
        if p.returncode or not out.is_file():
            print('探针失败（%d）：%s' % (p.returncode, (p.stdout + p.stderr)[-1500:]), file=sys.stderr)
            return 1
        shutil.move(out, box / 'fresh.json')
        merge = {'kind': 'events', 'order': list(units), 'ran': chosen,
                 'files': [{'old': str(box / 'full.json'), 'fresh': str(box / 'fresh.json'), 'out': str(box / 'merged.json'), 'indent': None}]}
        (box / 'merge.json').write_text(json.dumps(merge, ensure_ascii=False))
        m = subprocess.run(['node', str(HERE / 'oracle_shard_merge.cjs'), str(box / 'merge.json')], capture_output=True, text=True)
        if m.returncode:
            print('合并失败：' + (m.stdout + m.stderr)[-1500:], file=sys.stderr)
            return 1
        fresh_cases = len(json.loads((box / 'fresh.json').read_text()).get('cases', []))
        a_bytes, b_bytes = full.read_bytes(), (box / 'merged.json').read_bytes()
        result = {'units': chosen, 'freshCases': fresh_cases, 'totalUnits': len(units), 'identical': a_bytes == b_bytes}
        if not result['identical']:
            result['firstDiff'] = first_diff(a_bytes, b_bytes)
        print('EVENT_INCREMENTAL_COMPARE=' + json.dumps(result, ensure_ascii=False))
        return 0 if result['identical'] else 1
    finally:
        shutil.rmtree(box, ignore_errors=True)


if __name__ == '__main__':
    raise SystemExit(main())
