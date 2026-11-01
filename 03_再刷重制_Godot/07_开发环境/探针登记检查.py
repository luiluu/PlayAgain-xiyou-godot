#!/usr/bin/env python3
"""mv_oracle/*_probe.cjs 都要有去处（检查.sh 调用，tools31）。

探针有两种用法：登记进 同步正式西游.py 的 PROBES（每次同步重跑、产物进 generated/oracle），
或是冻结 v0.28 参照、结果存成 tests/fixtures/<名>_oracle.json 夹具（如 yunshang_probe）。
两边都没有的探针新加后没人跑，也没人察觉——这里把它拦下：既不在 PROBES 里、又没有同名夹具，也不在豁免表里，就判失败。
夹具名取探针名去掉 _probe 再加 _oracle.json；名字对不上的写进 探针登记豁免.json。
用法：探针登记检查.py [--root 工程根目录]
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REMAKE = HERE.parent


def check(remake: Path, exempt: dict) -> list[str]:
    oracle = remake / '03_转换工具/mv_oracle'
    sync = (remake / '03_转换工具/同步正式西游.py').read_text()
    registered = set(re.findall(r"'([\w]+_probe\.cjs)'", sync))
    fixtures = {p.name for p in (remake / '01_Godot工程/tests/fixtures').glob('*_oracle.json')}
    bad = []
    names = sorted(p.name for p in oracle.glob('*_probe.cjs'))
    for name in names:
        if name in registered or name in exempt or name[:-len('_probe.cjs')] + '_oracle.json' in fixtures:
            continue
        bad.append(f'{name} 没登记进 同步正式西游.py 的 PROBES，也没有夹具 tests/fixtures/{name[:-len("_probe.cjs")]}_oracle.json'
                   '（冻结参照的探针补夹具，名字对不上的写进 探针登记豁免.json）')
    for name in sorted(set(exempt) - set(names)):
        bad.append(f'探针登记豁免.json 里的 {name} 已不存在，删掉这一行')
    return bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, default=REMAKE)
    a = ap.parse_args()
    exempt_file = HERE / '探针登记豁免.json'
    exempt = json.loads(exempt_file.read_text()).get('exempt', {}) if exempt_file.exists() else {}
    bad = check(a.root, exempt)
    for b in bad:
        print('  ✗ ' + b)
    if not bad:
        print('  ✓ 探针登记：每个 mv_oracle 探针都在 PROBES 里或有夹具')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
