#!/usr/bin/env python3
"""正式西游更新后的一键重同步（用户 2026-10-14 同意的效率方案）。

做法与历次手工同步相同，全部自动：
1. 备份 generated/ 的 oracle、db、maps、manifest.json、slice.json 到 04_验证/本地结果/自动同步/<时间>_<旧版>-<新版>/；
2. 重跑转换器 xiyou_export.py；
3. 重跑全部参照探针（mv_oracle，只写 .sandbox/），复制到 generated/oracle/；
4. 去掉来源身份（sourceIdentity、releaseVersion 等）后逐份比较测量；列出改动的数据文件、记录编号、地图与运行脚本；
5. 运行 验证西游来源.py；
6. 测量全部不变且核对 0 问题：写来源清单，更新 来源登记.json 与 当前状态.json（--no-register 或在 worktree 里运行时不写），退出码 0；
   有测量变化：不改登记，退出码 2，报告写在备份目录 同步报告.json，交给人看（变化可能就是正式版的规则改动，要跟进）。
只读正式应用；不读写任何玩家存档。
"""
import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from xiyou_export import DEFAULT_APP, DEFAULT_OUT  # noqa: E402

ORACLE_DIR = HERE / 'mv_oracle'
SANDBOX = ORACLE_DIR / '.sandbox'
# 探针 → 产物（相对 .sandbox）；slice_probe 一次跑 6 个难度
PROBES = [
    (['slice_probe.cjs', '1', '2', '3', '4', '5', '6'], ['slice/slice_d%d.json' % d for d in range(1, 7)]),
    (['equipment_probe.cjs'], ['equipment.json']),
    (['map_probe.cjs'], ['maps.json', 'maps_source.json']),
    (['help_probe.cjs'], ['help_cards.json']),
    (['hang_up_probe.cjs'], ['hang_up.json']),
    (['smart_ai_probe.cjs'], ['smart_ai.json']),
    (['options_probe.cjs'], ['options.json']),
    (['sequence_probe.cjs'], ['sequences.json']),
    (['party_probe.cjs'], ['party.json']),
    (['troop_event_probe.cjs'], ['troop_events.json']),
    (['drop_record_probe.cjs'], ['drop_record.json']),
    (['sell_reward_probe.cjs'], ['sell_rewards.json']),
    (['power_probe.cjs'], ['power.json']),
    (['wtype_probe.cjs'], ['wtype.json']),
    (['shop_buy_probe.cjs'], ['shop_buy.json']),
    (['settlement_probe.cjs'], ['settlement.json']),
    (['item_marks_probe.cjs'], ['item_marks.json']),
    (['shared_system_probe.cjs'], ['shop_stock.json', 'battle_messages.json', 'challenge_passives.json']),
    (['event_probe.cjs'], ['events.json']),       # 需要本次转换的 generated/maps，放在转换器之后
]
IDENTITY_KEYS = {'sourceIdentity', 'identity', 'releaseVersion', 'source'}


def strip(x):
    if isinstance(x, dict):
        return {k: strip(v) for k, v in x.items() if k not in IDENTITY_KEYS}
    if isinstance(x, list):
        return [strip(v) for v in x]
    return x


def diff_paths(a, b, path='', out=None, limit=20):
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if type(a) is not type(b):
        out.append(path or '/')
    elif isinstance(a, dict):
        for k in sorted(set(a) | set(b), key=str):
            if k not in a or k not in b:
                out.append(path + '/' + str(k))
            else:
                diff_paths(a[k], b[k], path + '/' + str(k), out, limit)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append(path + ' 长度 %d→%d' % (len(a), len(b)))
        for i, (x, y) in enumerate(zip(a, b)):
            diff_paths(x, y, '%s[%d]' % (path, i), out, limit)
    elif a != b:
        out.append(path)
    return out


def record_changes(old_file: Path, new_file: Path):
    """数据库表按记录编号列出改动（新增/删除/修改）。"""
    try:
        a, b = json.loads(old_file.read_text()), json.loads(new_file.read_text())
    except Exception:
        return ['无法解析']
    if isinstance(a, list) and isinstance(b, list):
        ids = []
        for i in range(max(len(a), len(b))):
            x = a[i] if i < len(a) else None
            y = b[i] if i < len(b) else None
            if x != y:
                ids.append(i)
        return ids
    return ['整体改动'] if a != b else []


def run(cmd, cwd, log):
    log.write('$ ' + ' '.join(cmd) + '\n')
    log.flush()
    p = subprocess.run(cmd, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise RuntimeError('命令失败（%d）：%s' % (p.returncode, ' '.join(cmd)))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--app', type=Path, default=DEFAULT_APP)
    ap.add_argument('--generated', type=Path, default=DEFAULT_OUT)
    ap.add_argument('--no-register', action='store_true', help='只同步与比较，不改来源登记/当前状态')
    a = ap.parse_args()
    # 多会话并行（AGENTS.md）：来源登记／当前状态只由总装在主工作区改，worktree 里自动不登记
    git = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'],
                         capture_output=True, text=True).stdout.split('\n')
    if not a.no_register and len(git) > 1 and git[0] != git[1]:
        a.no_register = True
        print('在 worktree 里运行：只同步与比较，不写来源登记／当前状态（由总装在主工作区登记）')
    app, gen = a.app.resolve(), a.generated.resolve()
    old_manifest = json.loads((gen / 'manifest.json').read_text())
    old_version = old_manifest.get('releaseVersion')
    new_version = json.loads((app / 'package.json').read_text()).get('releaseVersion')
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S')
    backup = ROOT / '03_再刷重制_Godot/04_验证/本地结果/自动同步' / ('%s_%s-%s' % (stamp, old_version, new_version))
    backup.mkdir(parents=True)
    for name in ['oracle', 'db', 'maps', 'manifest.json', 'slice.json']:
        src = gen / name
        if src.is_dir():
            shutil.copytree(src, backup / name)
        elif src.exists():
            shutil.copy2(src, backup / name)
    report = {'from': old_version, 'to': new_version, 'backup': str(backup.relative_to(ROOT)), 'generated': str(gen)}
    # 探针按环境变量取正式源（XIYOU_APP）与转换产物（XIYOU_GENERATED，event_probe 读地图），与 --app/--generated 一致
    os.environ['XIYOU_APP'] = str(app)
    os.environ['XIYOU_GENERATED'] = str(gen)
    with open(backup / '同步.log', 'w') as log:
        run([sys.executable, str(HERE / 'xiyou_export.py'), '--app', str(app), '--out', str(gen)], HERE, log)
        for cmd, outs in PROBES:
            run(['node'] + cmd, ORACLE_DIR, log)
            for rel in outs:
                shutil.copy2(SANDBOX / rel, gen / 'oracle' / Path(rel).name)
    new_manifest = json.loads((gen / 'manifest.json').read_text())
    # 改动的来源文件
    report['changedInputs'] = sorted(k for k in set(old_manifest.get('inputs', {})) | set(new_manifest.get('inputs', {}))
                                     if old_manifest.get('inputs', {}).get(k) != new_manifest.get('inputs', {}).get(k))
    report['changedRuntime'] = sorted(k for k in set(old_manifest.get('runtimeInputs', {})) | set(new_manifest.get('runtimeInputs', {}))
                                      if old_manifest.get('runtimeInputs', {}).get(k) != new_manifest.get('runtimeInputs', {}).get(k))
    # 产物里改动的数据记录与地图
    records = {}
    for f in sorted((gen / 'db').glob('*.json')):
        old = backup / 'db' / f.name
        if not old.exists():
            records[f.name] = ['新文件']
        elif old.read_bytes() != f.read_bytes():
            records[f.name] = record_changes(old, f)[:50]
    report['changedRecords'] = records
    report['changedMaps'] = sorted(f.name for f in (gen / 'maps').glob('*.json')
                                   if not (backup / 'maps' / f.name).exists() or (backup / 'maps' / f.name).read_bytes() != f.read_bytes())
    report['sliceChanged'] = (backup / 'slice.json').read_bytes() != (gen / 'slice.json').read_bytes() if (backup / 'slice.json').exists() else True
    # 测量比较
    measure = {}
    for f in sorted((gen / 'oracle').glob('*.json')):
        old = backup / 'oracle' / f.name
        if not old.exists():
            measure[f.name] = ['新增参照']
            continue
        d = diff_paths(strip(json.loads(old.read_text())), strip(json.loads(f.read_text())))
        if d:
            measure[f.name] = d
    report['measurementChanges'] = measure
    v = subprocess.run([sys.executable, str(HERE / '验证西游来源.py'), '--app', str(app), '--generated', str(gen)], capture_output=True, text=True)
    report['verify'] = (v.stdout.strip().splitlines() or [''])[-1]
    report['verifyOk'] = v.returncode == 0
    ok = report['verifyOk'] and not measure
    report['result'] = '测量不变，已登记' if ok and not a.no_register else ('测量不变' if ok else '有变化，请人工查看')
    fingerprint = backup / '当前西游来源清单.json'
    fingerprint.write_text(json.dumps({'releaseVersion': new_version, 'inputs': new_manifest['inputs'],
                                       'runtimeInputs': new_manifest.get('runtimeInputs', {})}, ensure_ascii=False, indent=2))
    (backup / '同步报告.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    if ok and not a.no_register:
        register(new_version, fingerprint, report)
    print(json.dumps({k: report[k] for k in ['from', 'to', 'result', 'changedInputs', 'changedMaps', 'measurementChanges', 'verify', 'backup']},
                     ensure_ascii=False))
    return 0 if ok else 2


def register(version: str, fingerprint: Path, report: dict) -> None:
    rel = str(fingerprint.relative_to(ROOT))
    changed = '、'.join(report['changedInputs'] + report['changedRuntime'])[:300] or '只有 package.json'
    p = ROOT / '00_项目管理/来源登记.json'
    data = json.loads(p.read_text())
    src = next(s for s in data['sources'] if s['id'] == 'legacy_xiyou_mod_kyo')
    for k in ['confirmedReleaseVersion', 'lastConvertedContentReleaseVersion', 'oracleReleaseVersion']:
        src[k] = version
    src['fingerprint'] = rel
    src['note'] = src.get('note', '') + ' %s（%s 自动同步）：改动 %s；全部参照去来源身份后测量不变。' % (version, dt.date.today().isoformat(), changed)
    data['review'] = '%s 由自动同步核对同源，待交叉核查' % version
    p.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    p = ROOT / '00_项目管理/当前状态.json'
    state = json.loads(p.read_text())
    rs = state['remakeSource']
    for k in ['releaseVersion', 'convertedContentReleaseVersion', 'oracleReleaseVersion']:
        rs[k] = version
    rs['fingerprint'] = rel
    p.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    sys.exit(main())
