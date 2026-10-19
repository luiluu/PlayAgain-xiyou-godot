#!/usr/bin/env python3
"""正式西游更新后的一键重同步（用户 2026-10-14 同意的效率方案）。

做法与历次手工同步相同，全部自动：
1. 备份 generated/ 的 oracle、db、maps、manifest.json、slice.json 到 04_验证/本地结果/自动同步/<时间>_<旧版>-<新版>/，备份只留最近 3 份；
2. 重跑转换器 xiyou_export.py；
3. 按输入与产物SHA复用未变化探针（切片按字段；慢探针按敌群／地图分片只跑变了的单元；--full强制全部重跑），运行需要更新的参照探针（mv_oracle，只写 .sandbox/），复制到 generated/oracle/；
4. 去掉来源身份（sourceIdentity、releaseVersion 等）后逐份比较测量；列出改动的数据文件、记录编号、地图与运行脚本；
5. 运行 验证西游来源.py；
6. 测量全部不变且核对 0 问题：写来源清单，更新 来源登记.json 与 当前状态.json（--no-register 或在 worktree 里运行时不写），退出码 0；
   有测量变化：不改登记，退出码 2，报告写在备份目录 同步报告.json，交给人看（变化可能就是正式版的规则改动，要跟进）。
7. 同步正常结束（核对 0 问题、测量不变或只增）时在 generated/ 写产物指纹 sync_stamp.json：本库决定产物的转换工具文件摘要
   （03_转换工具 下受 Git 跟踪的文件，ui_reference 与 .md 除外）与全部产物摘要（不含 Godot 的 .import）。
8. 最后 godot --import（--no-import 跳过），免得紧接着跑的专项测试读不到新图。

--from-worktree <车道工作树>（总装合并时用，提速提案 P3）：车道在自己的工作树跑过同步、且合并后 main 的转换工具文件与车道
同步时完全相同，则不再重跑转换器与探针，直接克隆车道的产物，核对产物摘要后照常比较测量、核对来源、登记。
任一条件不满足退出码 3（未改动 main 的产物），调用方改跑完整同步。
只读正式应用；不读写任何玩家存档。
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from xiyou_export import DEFAULT_APP, DEFAULT_OUT  # noqa: E402
from incremental_sync import SHARDS, ProbeCache
from oracle_additions import compare_directories, payload, source_preserved, has_error, retained_errors_unchanged  # noqa: E402

ORACLE_DIR = HERE / 'mv_oracle'
SANDBOX = ORACLE_DIR / '.sandbox'
STAMP = 'sync_stamp.json'
TOOLS_REL = HERE.relative_to(ROOT).as_posix()   # 03_再刷重制_Godot/03_转换工具
# 只读的检查工具不影响产物，不算进转换工具指纹
READ_ONLY_TOOLS = {'内容覆盖检查.py', '事件指令统计.py', '共性参照验收.py', '验证西游来源.py', '角色模板预检.py'}
GODOT = ROOT / '03_再刷重制_Godot/07_开发环境/godot'
PROJECT = ROOT / '03_再刷重制_Godot/01_Godot工程'
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
    (['battle_event_probe.cjs'], ['battle_events.json']),
    (['drop_record_probe.cjs'], ['drop_record.json']),
    (['sell_reward_probe.cjs'], ['sell_rewards.json']),
    (['power_probe.cjs'], ['power.json']),
    (['wtype_probe.cjs'], ['wtype.json']),
    (['shop_buy_probe.cjs'], ['shop_buy.json']),
    (['settlement_probe.cjs'], ['settlement.json']),
    (['item_marks_probe.cjs'], ['item_marks.json']),
    (['orb_probe.cjs'], ['orbs.json']),
    (['orb_shop_probe.cjs'], ['orb_shop.json']),
    (['dungeon_probe.cjs'], ['dungeon.json']),
    (['shared_system_probe.cjs'], ['shop_stock.json', 'battle_messages.json', 'challenge_passives.json']),
    (['zhenqi_probe.cjs'], ['zhenqi.json']),
    (['guide_probe.cjs'], ['guide.json']),
    (['custom_damage_probe.cjs'], ['custom_damage.json']),
    (['formula_program_probe.cjs'], ['formula_programs.json']),
    (['formula_effect_probe.cjs'], ['formula_effects.json']),
    (['formula_equipment_probe.cjs'], ['formula_equipment.json']),
    (['formula_action_probe.cjs'], ['formula_actions.json']),
    (['review_fix_probe.cjs'], ['review_fix.json']),
    (['global_vars_probe.cjs'], ['global_vars.json']),
    (['event_probe.cjs'], ['events.json']),       # 需要本次转换的 generated/maps，放在转换器之后
]


def strip(x):
    return payload(x)


def probe_outputs():
    return {Path(rel).name for _, outs in PROBES for rel in outs}


def file_digest(path: Path) -> bytes:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.digest()


def tools_digest(root: Path = None) -> str:
    """决定转换产物的本库文件：03_转换工具 下受 Git 跟踪的文件（ui_reference、.md 与只读检查工具除外），按路径与内容摘要。"""
    root = root or ROOT
    tools = TOOLS_REL
    out = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', 'ls-files', '-z', '--', tools],
                         capture_output=True, text=True).stdout
    h = hashlib.sha256()
    for rel in sorted(x for x in out.split('\0') if x.startswith(tools + '/')):
        if ('/ui_reference/' in rel or rel.endswith('.md') or Path(rel).name in READ_ONLY_TOOLS
                or not (root / rel).is_file()):
            continue
        h.update(rel.encode() + b'\0' + file_digest(root / rel))
    return h.hexdigest()


def outputs_digest(gen: Path) -> str:
    """全部转换产物（不含 Godot 导入时写的 .import 与本指纹文件）按相对路径与内容摘要。"""
    h = hashlib.sha256()
    for p in sorted(gen.rglob('*')):
        if p.is_file() and p.name != STAMP and p.suffix != '.import':
            h.update(p.relative_to(gen).as_posix().encode() + b'\0' + file_digest(p))
    return h.hexdigest()


def clone_from_worktree(worktree: Path, gen: Path):
    """车道产物可用时克隆到本工作区 generated；不可用返回原因（此时不动本工作区）。"""
    lane_gen = worktree / gen.relative_to(ROOT.resolve())
    if lane_gen.resolve() == gen.resolve() or lane_gen.resolve() in gen.resolve().parents or gen.resolve() in lane_gen.resolve().parents:
        return None, '车道与当前产物目录相同或互相包含'
    stamp_file = lane_gen / STAMP
    if not stamp_file.is_file():
        return None, '车道产物没有同步指纹（车道未用新版同步脚本跑过同步）'
    try:
        stamp = json.loads(stamp_file.read_text())
    except (ValueError, OSError):
        return None, '车道同步指纹无法读取'
    if not isinstance(stamp, dict):
        return None, '车道同步指纹格式无效'
    if stamp.get('toolsDigest') != tools_digest():
        return None, '合并后 main 的转换工具文件与车道同步时不同'
    if stamp.get('toolsDigest') != tools_digest(worktree):
        return None, '车道同步后又改了转换工具文件'
    if outputs_digest(lane_gen) != stamp.get('outputsDigest'):
        return None, '车道产物在同步后被改动'
    return (lane_gen, stamp), None


def write_stamp(gen: Path, report: dict) -> None:
    stamp = {'toolsDigest': tools_digest(), 'outputsDigest': outputs_digest(gen), 'releaseVersion': report.get('to'),
             'result': report.get('result'), 'time': dt.datetime.now().isoformat(timespec='seconds'), 'backup': report.get('backup')}
    (gen / STAMP).write_text(json.dumps(stamp, ensure_ascii=False, indent=2) + '\n')


def godot_import(log=None) -> None:
    if GODOT.exists() and PROJECT.is_dir():
        p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), '--import'],
                           capture_output=True, text=True, timeout=300)
        out = (p.stdout or '') + (p.stderr or '')
        if log:
            log.write(out)
        if p.returncode or re.search(r'SCRIPT ERROR|^ERROR:', out, re.M):
            raise RuntimeError('Godot 导入失败（退出码 %d），见同步.log' % p.returncode)
    else:
        raise RuntimeError('Godot 引擎或工程目录缺失，无法确认导入')


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


KEEP_BACKUPS = 3


def prune_backups(root: Path, keep: int = KEEP_BACKUPS) -> list:
    """同步备份只留最近 keep 份（用户 2026-10-18 定，含本次新建的这份）；只删「日期_时间_…」命名的备份目录。"""
    dirs = sorted((d for d in root.iterdir() if d.is_dir() and re.match(r'^\d{8}_\d{6}', d.name)),
                  key=lambda d: (d.name[:15], d.stat().st_mtime))
    removed = []
    for d in dirs[:-keep] if keep > 0 else dirs:
        shutil.rmtree(d)
        removed.append(d.name)
    return removed


def run(cmd, cwd, log):
    log.write('$ ' + ' '.join(cmd) + '\n')
    log.flush()
    p = subprocess.run(cmd, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise RuntimeError('命令失败（%d）：%s' % (p.returncode, ' '.join(cmd)))


def run_probes(log, cache=None):
    """互不依赖的探针并行跑（AGENTS.md「省额度约定」同步提速）。每个探针一个独立存档目录
    .sandbox/run/<探针>（开跑前复制 .sandbox 现有的 save／macport，各探针看到同样的起始状态），
    产物照旧写 .sandbox/*.json；日志按 PROBES 顺序写回，并记每个探针的耗时。SYNC_JOBS=1 退回串行。"""
    import concurrent.futures
    import time
    jobs = max(1, int(os.environ.get('SYNC_JOBS', '4')))
    plan, reused, keys, units, partial = [], [], {}, {}, {}
    for command, outputs in PROBES:
        key = cache.key(command) if cache else None
        keys[command[0]] = key
        units[command[0]] = cache.units(command) if cache else None
        todo = cache.plan(command, outputs, key, units[command[0]]) if cache else None
        if todo == []:
            reused.append(command[0])
            cache.record(command, outputs, key, units[command[0]])
            log.write('CACHE_HIT ' + command[0] + '\n')
        else:
            if todo is not None:
                # 分片探针：只跑变了的单元（[''] 表示只删了单元或换了顺序，不跑探针只合并）
                partial[command[0]] = [u for u in todo if u]
                log.write('CACHE_PARTIAL %s %d/%d %s\n' % (command[0], len(partial[command[0]]), len(units[command[0]]),
                                                         ' '.join(partial[command[0]][:20])))
            plan.append((command, outputs))
    log.flush()
    print('PROBE_PLAN=' + json.dumps({'executed': len(plan) - len(partial), 'partial': {k: len(v) for k, v in partial.items()},
                                      'reused': len(reused)}), flush=True)
    if not plan:
        return {'executed': [], 'partial': {}, 'reused': reused, 'seconds': {}}
    gen_oracle = Path(os.environ['XIYOU_GENERATED']) / 'oracle'
    # 合并要用上次产物：作废缓存前先存一份（作废后 generated/oracle 仍是上次产物，失败时也不会被当作新结果发布）
    previous = SANDBOX / 'run-previous'
    shutil.rmtree(previous, ignore_errors=True)
    for name in partial:
        for rel in next(outs for cmd, outs in plan if cmd[0] == name):
            (previous / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(gen_oracle / Path(rel).name, previous / rel)
    if cache:
        cache.invalidate([command for command, _ in plan])
    runs = SANDBOX / 'run'
    shutil.rmtree(runs, ignore_errors=True)

    def one(cmd):
        outputs = next(outputs for command, outputs in plan if command == cmd)
        for rel in outputs:
            (SANDBOX / rel).unlink(missing_ok=True)
        box = runs / Path(cmd[0]).stem
        box.mkdir(parents=True)
        for name in ['save', 'macport']:
            if (SANDBOX / name).is_dir():
                shutil.copytree(SANDBOX / name, box / name)
        env = dict(os.environ, XIYOU_ORACLE_SANDBOX=str(box))
        t = time.time()
        part = partial.get(cmd[0])
        if part is None:
            p = subprocess.run(['node'] + cmd, cwd=ORACLE_DIR, env=env, capture_output=True, text=True)
            return cmd, p.returncode, p.stdout + p.stderr, time.time() - t
        text = ''
        if part:
            env['XIYOU_PROBE_UNITS'] = json.dumps(part)
            p = subprocess.run(['node'] + cmd, cwd=ORACLE_DIR, env=env, capture_output=True, text=True)
            text = p.stdout + p.stderr
            if p.returncode:
                return cmd, p.returncode, text, time.time() - t
        spec = {'kind': SHARDS[cmd[0]]['kind'], 'order': list(units[cmd[0]]), 'ran': part, 'files': []}
        for rel in outputs:
            fresh = box / ('fresh-' + Path(rel).name)
            if part:
                if not (SANDBOX / rel).is_file():
                    return cmd, 1, text + '探针产物缺失：' + rel + '\n', time.time() - t
                shutil.move(SANDBOX / rel, fresh)
            spec['files'].append({'old': str(previous / rel), 'fresh': str(fresh) if part else None, 'out': str(SANDBOX / rel),
                                  'indent': None if cmd[0] == 'event_probe.cjs' else 1})
        (box / 'merge.json').write_text(json.dumps(spec, ensure_ascii=False))
        p = subprocess.run(['node', str(HERE / 'oracle_shard_merge.cjs'), str(box / 'merge.json')], capture_output=True, text=True)
        text += '（增量：只跑 %d 个单元，其余取上次产物合并）\n' % len(part) + p.stdout + p.stderr
        return cmd, p.returncode, text, time.time() - t

    slow = ['smart_ai_probe.cjs', 'event_probe.cjs', 'zhenqi_probe.cjs', 'dungeon_probe.cjs', 'sequence_probe.cjs']   # 最慢的先开跑
    order = sorted(range(len(plan)), key=lambda i: slow.index(plan[i][0][0]) if plan[i][0][0] in slow else len(slow))
    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        futures = {i: pool.submit(one, plan[i][0]) for i in order}
        results = [None] * len(plan)
        for future in concurrent.futures.as_completed({f: i for i, f in futures.items()}):
            i = next(i for i, f in futures.items() if f is future)
            results[i] = future.result()
            print('PROBE_DONE=' + json.dumps({'probe': results[i][0][0], 'seconds': round(results[i][3], 3),
                                             'exitCode': results[i][1]}), flush=True)
    failed = []
    for cmd, code, out, sec in results:
        log.write('$ node %s（%.0f 秒）\n' % (' '.join(cmd), sec))
        log.write(out)
        if code != 0:
            failed.append(' '.join(cmd))
    log.flush()
    if failed:
        raise RuntimeError('探针失败：' + '；'.join(failed))
    # Validate every new output before publishing any group. Exit 0 alone is insufficient.
    for command, outputs in plan:
        for rel in outputs:
            output = SANDBOX / rel
            if not output.is_file():
                raise RuntimeError('探针产物缺失：' + rel)
            data = json.loads(output.read_text())
            if has_error(data):
                previous = Path(os.environ['XIYOU_GENERATED']) / 'oracle' / Path(rel).name
                # Frozen event baselines contain explicitly retained, unresolved source cases.
                # Preserve identical old failures, but never accept a new or changed failing case.
                if not previous.is_file() or not retained_errors_unchanged(previous.name, json.loads(previous.read_text()), data):
                    raise RuntimeError('探针产物有新增或变化的错误：' + rel)
    for command, outputs in plan:
        for rel in outputs:
            shutil.copy2(SANDBOX / rel, Path(os.environ['XIYOU_GENERATED']) / 'oracle' / Path(rel).name)
        if cache:
            cache.record(command, outputs, keys[command[0]], units[command[0]])
    shutil.rmtree(previous, ignore_errors=True)
    return {'executed': [cmd[0] for cmd, _ in plan if cmd[0] not in partial],
            'partial': {k: v for k, v in partial.items()}, 'reused': reused,
            'seconds': {cmd[0]: round(sec, 3) for cmd, _, _, sec in results}}


def _main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--app', type=Path, default=DEFAULT_APP)
    ap.add_argument('--generated', type=Path, default=DEFAULT_OUT)
    ap.add_argument('--no-register', action='store_true', help='只同步与比较，不改来源登记/当前状态')
    ap.add_argument('--accept-additions', action='store_true',
                    help='同源且旧用例逐条相同、只增已知结构新用例时自动接受；不接受规则变化/删除/新用例错误')
    ap.add_argument('--from-worktree', type=Path, help='合并时用车道已同步的产物（按指纹核对），不满足条件退出码 3')
    ap.add_argument('--full', action='store_true', help='忽略探针缓存，强制全量转换与全部探针')
    ap.add_argument('--no-import', action='store_true', help='结束时不跑 godot --import')
    a = ap.parse_args()
    if a.full and a.from_worktree:
        ap.error('--full 与 --from-worktree 不能一起使用')
    # 多会话并行（AGENTS.md）：来源登记／当前状态只由总装在主工作区改，worktree 里自动不登记
    git = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'],
                         capture_output=True, text=True).stdout.split('\n')
    if not a.no_register and len(git) > 1 and git[0] != git[1]:
        a.no_register = True
        print('在 worktree 里运行：只同步与比较，不写来源登记／当前状态（由总装在主工作区登记）')
    app, gen = a.app.resolve(), a.generated.resolve()
    lane = None
    if a.from_worktree:
        lane, why = clone_from_worktree(a.from_worktree.resolve(), gen)
        if lane is None:
            print('不用车道产物：' + why + '；请改跑完整同步')
            return 3
    old_manifest = json.loads((gen / 'manifest.json').read_text())
    old_version = old_manifest.get('releaseVersion')
    new_version = json.loads((app / 'package.json').read_text()).get('releaseVersion')
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    backup = ROOT / '03_再刷重制_Godot/04_验证/本地结果/自动同步' / ('%s_%s-%s' % (stamp, old_version, new_version))
    backup.mkdir(parents=True)
    report_pruned = prune_backups(backup.parent)
    for name in ['oracle', 'db', 'maps', 'manifest.json', 'slice.json']:
        src = gen / name
        if src.is_dir():
            shutil.copytree(src, backup / name)
        elif src.exists():
            shutil.copy2(src, backup / name)
    report = {'from': old_version, 'to': new_version, 'backup': str(backup.relative_to(ROOT)), 'generated': str(gen),
              'prunedBackups': report_pruned}
    # 探针按环境变量取正式源（XIYOU_APP）与转换产物（XIYOU_GENERATED，event_probe 读地图），与 --app/--generated 一致
    os.environ['XIYOU_APP'] = str(app)
    os.environ['XIYOU_GENERATED'] = str(gen)
    with open(backup / '同步.log', 'w') as log:
        if lane is not None:
            lane_gen, stamp = lane
            log.write('用车道产物 %s（指纹 %s，%s）\n' % (lane_gen, stamp.get('outputsDigest'), stamp.get('time')))
            shutil.rmtree(gen)
            # APFS 克隆（cp -c）不占空间；不可用时退回普通复制
            if subprocess.run(['cp', '-c', '-R', str(lane_gen), str(gen)]).returncode or not (gen / 'manifest.json').exists():
                shutil.rmtree(gen, ignore_errors=True)
                shutil.copytree(lane_gen, gen)
            if outputs_digest(gen) != stamp.get('outputsDigest'):
                raise RuntimeError('克隆后的产物与车道指纹不一致')
            report['fromWorktree'] = str(a.from_worktree)
        else:
            (gen / STAMP).unlink(missing_ok=True)
            run([sys.executable, str(HERE / 'xiyou_export.py'), '--app', str(app), '--out', str(gen)], HERE, log)
            cache = ProbeCache(HERE, app, gen, force=a.full) if PROBES else None
            report['probes'] = run_probes(log, cache)
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
    for name in sorted({f.name for d in [gen / 'oracle', backup / 'oracle'] for f in d.glob('*.json')}):
        f = gen / 'oracle' / name
        old = backup / 'oracle' / f.name
        if not f.exists():
            measure[name] = ['参照已删除']
            continue
        if not old.exists():
            measure[f.name] = ['新增参照']
            continue
        d = diff_paths(strip(json.loads(old.read_text())), strip(json.loads(f.read_text())))
        if d:
            measure[f.name] = d
    report['measurementChanges'] = measure
    report['additionCheck'] = compare_directories(backup / 'oracle', gen / 'oracle', probe_outputs())
    report['sameExistingSource'] = source_preserved(old_manifest, new_manifest)
    v = subprocess.run([sys.executable, str(HERE / '验证西游来源.py'), '--app', str(app), '--generated', str(gen)], capture_output=True, text=True)
    report['verify'] = (v.stdout.strip().splitlines() or [''])[-1]
    report['verifyOk'] = v.returncode == 0
    accepted = bool(a.accept_additions and report['additionCheck']['onlyAdditions']
                    and report['sameExistingSource'] and report['verifyOk'])
    ok = report['verifyOk'] and (not measure or accepted)
    report['acceptedAdditions'] = accepted
    if accepted:
        report['result'] = '只增新用例，已接受' + ('并登记' if not a.no_register else '（不登记）')
    elif report['additionCheck']['onlyAdditions'] and report['sameExistingSource'] and report['verifyOk']:
        report['result'] = '只增新用例；加 --accept-additions 可自动接受'
    else:
        report['result'] = '测量不变，已登记' if ok and not a.no_register else ('测量不变' if ok else '有变化，请人工查看')
    fingerprint = backup / '当前西游来源清单.json'
    fingerprint.write_text(json.dumps({'releaseVersion': new_version, 'inputs': new_manifest['inputs'],
                                       'runtimeInputs': new_manifest.get('runtimeInputs', {})}, ensure_ascii=False, indent=2))
    if not a.no_import:
        try:
            with open(backup / '同步.log', 'a') as log:
                godot_import(log)
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            ok = False
            report['importError'] = str(error)
            report['result'] = 'Godot 导入失败，未登记'
    (backup / '同步报告.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    # 探针都跑成功、来源核验通过就发布缓存：产物是按这组输入如实测出的，测量变化接不接受（退出码 2）
    # 与缓存无关；否则加楼层后的每次重跑都退回全量。导入失败也不影响探针产物。
    if report['verifyOk'] and lane is None and cache is not None:
        try:
            cache.commit()
        except RuntimeError as error:
            ok = False
            report['cacheError'] = str(error)
            report['result'] = '输入或产物在同步中改变，未登记'
            (backup / '同步报告.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    if ok and not a.no_register:
        register(new_version, fingerprint, report)
    usable = not report.get('cacheError') and not report.get('importError') and report['verifyOk'] and report['sameExistingSource'] and (not measure or report['additionCheck']['onlyAdditions'])
    if usable and lane is None:
        write_stamp(gen, report)
    elif not usable:
        (gen / STAMP).unlink(missing_ok=True)
    print(json.dumps({k: report[k] for k in ['from', 'to', 'result', 'changedInputs', 'changedMaps', 'measurementChanges', 'verify', 'backup']},
                     ensure_ascii=False))
    return 0 if ok else 2


def register(version: str, fingerprint: Path, report: dict) -> None:
    rel = str(fingerprint.relative_to(ROOT))
    changed = '、'.join(report['changedInputs'] + report['changedRuntime'])[:300] or '来源文件不变'
    p = ROOT / '00_项目管理/来源登记.json'
    data = json.loads(p.read_text())
    src = next(s for s in data['sources'] if s['id'] == 'legacy_xiyou_mod_kyo')
    for k in ['confirmedReleaseVersion', 'lastConvertedContentReleaseVersion', 'oracleReleaseVersion']:
        src[k] = version
    src['fingerprint'] = rel
    conclusion = '既有用例逐条不变，只增新用例' if report.get('acceptedAdditions') else '全部参照去来源身份后测量不变'
    src['note'] = src.get('note', '') + ' %s（%s 自动同步）：改动 %s；%s。' % (version, dt.date.today().isoformat(), changed, conclusion)
    data['review'] = '%s 由自动同步核对同源，待交叉核查' % version
    p.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
    p = ROOT / '00_项目管理/当前状态.json'
    state = json.loads(p.read_text())
    rs = state['remakeSource']
    for k in ['releaseVersion', 'convertedContentReleaseVersion', 'oracleReleaseVersion']:
        rs[k] = version
    rs['fingerprint'] = rel
    manifest = json.loads((Path(report['generated']) / 'manifest.json').read_text())
    rs['fingerprintedFiles'] = len(manifest['inputs'])
    rs['runtimeFingerprintCount'] = len(manifest.get('runtimeInputs', {}))
    rs['converterVersion'] = manifest.get('toolVersion', rs.get('converterVersion'))
    p.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')


def main() -> int:
    import fcntl
    lock_path = ROOT / '03_再刷重制_Godot/04_验证/本地结果/sync.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('同一工作树已有同步任务在运行')
        return _main()


if __name__ == '__main__':
    if os.environ.get('XIYOU_LONG_TASK_MANAGED') != '1':
        wrapper = ROOT / '03_再刷重制_Godot/07_开发环境/长任务.py'
        task_log = os.environ.get('XIYOU_TASK_LOG') or str(ROOT / '03_再刷重制_Godot/04_验证/本地结果/任务' /
                    ('sync-' + dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f') + '.log'))
        os.execv(sys.executable, [sys.executable, str(wrapper), 'run', task_log, '--', sys.executable, __file__, *sys.argv[1:]])
    sys.exit(main())
