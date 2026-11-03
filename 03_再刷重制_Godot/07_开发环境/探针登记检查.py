#!/usr/bin/env python3
"""mv_oracle/*_probe.cjs 都要有去处（检查.sh 调用，tools31）。

探针有两种用法：登记进 同步正式西游.py 的 PROBES（每次同步重跑、产物进 generated/oracle），
或是冻结 v0.28 参照、结果存成 tests/fixtures/<名>_oracle.json 夹具（如 yunshang_probe）。
两边都没有的探针新加后没人跑，也没人察觉——这里把它拦下：既不在 PROBES 里、又没有同名夹具，也不在豁免表里，就判失败。
夹具名取探针名去掉 _probe 再加 _oracle.json；名字对不上的写进 探针登记豁免.json。

五乘区检查（tools49）：原版 CodexZones 会按角色成长改伤害，重制不移植（O-044），探针宿主默认却是开着的，
读伤害的探针不关它，参照数值就和重制对不上（云裳、奈叶 nanoha3 差 5.2 倍都是它）。
所以读伤害的探针（源码里出现 hpDamage／makeDamage／executeDamage／applyDamage／startAction／invokeAction）
必须在源码里提到 CodexZones（一般是 `w.eval('CodexZones.ENABLED=false;')`，guide_probe 那种换成 undefined 也算）。
没提到的：已有的存量记在 探针五乘区存量.json（尚未逐个确认受不受影响，确认后再改探针、从清单里删），新探针不许加入；
存量探针后来加了开关或删了文件，清单里的行要删掉。
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


DAMAGE_RE = re.compile(r'hpDamage|makeDamage|executeDamage|applyDamage|startAction|invokeAction|evalDamageFormula|\.result\(\)')
ZONES_FILE = HERE / '探针五乘区存量.json'


def zones_check(remake: Path, stock: dict) -> list[str]:
    """读伤害又没提 CodexZones 的探针，必须在存量清单里；清单里多余的行也报。"""
    oracle = remake / '03_转换工具/mv_oracle'
    unswitched = set()
    for p in oracle.glob('*_probe.cjs'):
        text = p.read_text(encoding='utf-8', errors='replace')
        if DAMAGE_RE.search(text) and 'CodexZones' not in text:
            unswitched.add(p.name)
    bad = []
    for name in sorted(unswitched - set(stock)):
        bad.append(f'{name} 读伤害却没关五乘区：在探针里加 w.eval(\'CodexZones.ENABLED=false;\')（原版 CodexZones 会按成长改伤害，重制不移植），'
                   '确实不受影响的才写进 探针五乘区存量.json 并说明理由')
    for name in sorted(set(stock) - unswitched):
        bad.append(f'探针五乘区存量.json 里的 {name} 已加开关或已不存在，删掉这一行')
    return bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, default=REMAKE)
    a = ap.parse_args()
    exempt_file = HERE / '探针登记豁免.json'
    exempt = json.loads(exempt_file.read_text()).get('exempt', {}) if exempt_file.exists() else {}
    bad = check(a.root, exempt)
    stock = json.loads(ZONES_FILE.read_text()).get('stock', {}) if ZONES_FILE.exists() else {}
    bad += zones_check(a.root, stock)
    for b in bad:
        print('  ✗ ' + b)
    if not bad:
        print('  ✓ 探针登记：每个 mv_oracle 探针都在 PROBES 里或有夹具；读伤害的探针都关了五乘区（存量 %d 个待确认）' % len(stock))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
