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

--accept-changes <接受单.json>（可多次）：人工核过的单条既有用例测量改变（如有意修正探针）。接受单逐条写 file、collection、
key、fields、oldDigest、newDigest、reason，须与本轮实际变化逐项相同且每条都用上，否则整轮拒收；可接受的变化列在
同步报告 changeCandidates。接受单放 04_验证/测量接受/ 入 Git，成功后在 本地结果/测量接受记录.jsonl 追加审计行。

--accept-withdrawal <地图号>（可多次，如 41 或 Map041）：切片撤出地图后显式接受。须恰好等于本轮切片少掉的地图；
旧参照里新参照已没有的条目（按稳定键整组、地图键、敌人／角色键）从比较基线去掉，其余照常比较（既有用例改变仍拒收、
新增仍须 --accept-additions）；来源指纹只放过撤出地图的 data/MapNNN.json 与不再用到的素材。撤掉的条目逐份列在
同步报告 withdrawal。不加它时工作树的同步基线一直含撤出地图的用例，同步永远退出码 2。

--from-worktree <车道工作树>（总装合并时用，提速提案 P3）：车道在自己的工作树跑过同步、且合并后 main 的转换工具文件与车道
同步时完全相同，则不再重跑转换器与探针，直接克隆车道的产物，核对产物摘要后照常比较测量、核对来源、登记。
任一条件不满足退出码 3（未改动 main 的产物），调用方改跑完整同步。
只读正式应用；不读写任何玩家存档。
"""
import argparse
import contextlib
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from xiyou_export import DEFAULT_APP, DEFAULT_OUT  # noqa: E402
from incremental_sync import SHARDS, ProbeCache
from oracle_additions import (compare_directories, payload, source_preserved, has_error, retained_errors_unchanged,  # noqa: E402
                              load_acceptances, apply_acceptances, change_candidates, KEYS, groups)

ORACLE_DIR = HERE / 'mv_oracle'
SANDBOX = ORACLE_DIR / '.sandbox'
STAMP = 'sync_stamp.json'
TOOLS_REL = HERE.relative_to(ROOT).as_posix()   # 03_再刷重制_Godot/03_转换工具
# 只读的检查工具不影响产物，不算进转换工具指纹
READ_ONLY_TOOLS = {'内容覆盖检查.py', '事件指令统计.py', '共性参照验收.py', '验证西游来源.py', '角色模板预检.py'}
GODOT = ROOT / '03_再刷重制_Godot/07_开发环境/godot'
PROJECT = ROOT / '03_再刷重制_Godot/01_Godot工程'
# 探针 → 产物（相对 .sandbox）；切片在调度时拆成六条命令，共用同一并发上限
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
    (['dual_wield_probe.cjs'], ['dual_wield.json']),
    (['magic_weapon_probe.cjs'], ['magic_weapon.json']),
    (['custom_params_probe.cjs'], ['custom_params.json']),
    (['shop_buy_probe.cjs'], ['shop_buy.json']),
    (['settlement_probe.cjs'], ['settlement.json']),
    (['item_marks_probe.cjs'], ['item_marks.json']),
    (['orb_probe.cjs'], ['orbs.json']),
    (['module_hooks_probe.cjs'], ['module_hooks.json']),
    (['orb_shop_probe.cjs'], ['orb_shop.json']),
    (['race_menu_probe.cjs'], ['race_menu.json']),
    (['training_probe.cjs'], ['training.json']),
    (['gold_probe.cjs'], ['gold.json']),
    (['alien_workshop_probe.cjs'], ['alien_workshop.json']),
    (['alien_config_probe.cjs'], ['alien_config.json']),
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
    (['actor_passive_probe.cjs'], ['actor_passive.json']),
    (['achievement_probe.cjs'], ['achievements.json']),
    (['achievement_badge_probe.cjs'], ['achievement_badges.json']),
    (['shield_probe.cjs'], ['shield.json']),
    (['imported_balance_probe.cjs'], ['imported_balance.json']),
    (['state_effects_probe.cjs'], ['state_effects.json']),
    (['state_js_probe.cjs'], ['state_js.json']),
    (['review135_probe.cjs'], ['review135.json']),
    (['stage50_review_probe.cjs'], ['stage50_review.json']),
    (['attack_element_probe.cjs'], ['attack_elements.json']),
    (['qiyu_probe.cjs'], ['qiyu.json']),
    (['cat_probe.cjs'], ['cat.json']),
    (['race_battle_probe.cjs'], ['race_battle.json']),
    (['alien_battle_probe.cjs'], ['alien_battle.json']),
    (['attack_query_probe.cjs'], ['attack_query.json']),
    (['weapon_unleash_probe.cjs'], ['weapon_unleash.json']),
    (['enemy_book_defeat_probe.cjs'], ['enemy_book_defeat.json']),
    (['lobby_shop_probe.cjs'], ['lobby_shops.json']),
    (['common_script_probe.cjs'], ['common_scripts.json']),
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
        with heavy_slot('godot --import'):  # Godot 导入也是重进程，走同一个共用池
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


def comparison_baseline(gen: Path) -> Path:
    """首次写产物前原子保存接受边界；拒绝或中断后仍比较同一份数据。"""
    key = hashlib.sha256(str(gen.resolve()).encode()).hexdigest()
    parent = ROOT / '03_再刷重制_Godot/04_验证/本地结果/同步基线'
    parent.mkdir(parents=True, exist_ok=True)
    baseline = parent / key
    if not baseline.exists():
        staging = Path(tempfile.mkdtemp(prefix=key + '.pending-', dir=parent))
        try:
            shutil.copy2(gen / 'manifest.json', staging / 'manifest.json')
            shutil.copytree(gen / 'oracle', staging / 'oracle')
            (staging / 'identity.json').write_text(json.dumps({'schema': 1, 'generated': str(gen.resolve())}))
            staging.rename(baseline)
        finally:
            if staging.exists():
                shutil.rmtree(staging)
    try:
        identity = json.loads((baseline / 'identity.json').read_text())
        manifest = json.loads((baseline / 'manifest.json').read_text())
        valid = (identity == {'schema': 1, 'generated': str(gen.resolve())}
                 and isinstance(manifest, dict) and (baseline / 'oracle').is_dir())
    except (OSError, ValueError):
        valid = False
    if not valid:
        raise RuntimeError('已接受测量基线损坏，保留现场且停止同步：' + str(baseline))
    return baseline


def withdraw_baseline(old_dir: Path, new_dir: Path, out_dir: Path) -> dict:
    """撤出切片：把旧参照里新参照已没有的条目去掉后写到 out_dir，返回 {文件: 撤掉的键}。
    还在的条目原样保留，交给 compare_directories 照常比较；整份参照被删、未知结构不动（仍是问题）。"""
    out_dir.mkdir(parents=True, exist_ok=True)
    removed = {}
    for old in sorted(old_dir.glob('*.json')):
        data = json.loads(old.read_text())
        new = new_dir / old.name
        a, b = payload(data), (payload(json.loads(new.read_text())) if new.exists() else None)
        gone = []
        if isinstance(a, dict) and isinstance(b, dict):
            if old.name == 'maps.json':
                gone = sorted(k for k in a if k not in b)
                for k in gone:
                    del data[k]
            keys = dict(KEYS.get(old.name, {}))
            if old.name.startswith('slice_d'):
                keys['damage'] = lambda row: (('troop', 'actor', 'skill') if 'actor' in row else ('troop', 'enemy', 'target', 'skill'))
            for field in (a.keys() & b.keys()) if old.name != 'maps.json' else ():
                x, y = a[field], b[field]
                if isinstance(x, dict) and isinstance(y, dict) and (old.name.startswith('slice_d') and field in ('enemies', 'actors')
                                                                    or old.name == 'formula_programs.json' and field == 'contexts'):
                    drop = sorted(k for k in x if k not in y)
                    data[field] = {k: v for k, v in x.items() if k in y}
                    gone += ['%s:%s' % (field, k) for k in drop]
                elif field in keys and isinstance(x, list) and isinstance(y, list):
                    try:
                        have = set(groups(y, keys[field]))
                        rows = [(next(iter(groups([row], keys[field]))), row) for row in x]
                    except ValueError:
                        continue   # 缺稳定键：不动，交给照常比较报问题
                    gone += sorted({'%s:%s' % (field, k) for k, _ in rows if k not in have})
                    data[field] = [row for k, row in rows if k in have]
        if gone:
            removed[old.name] = gone
        (out_dir / old.name).write_text(json.dumps(data, ensure_ascii=False))
    return removed


def withdrawn_source_preserved(old: dict, new: dict, maps: set) -> bool:
    """同 source_preserved，但撤出地图的 data/MapNNN.json 与不再用到的素材（非 data/、非 js/）可以从输入里消失。"""
    allowed = {'data/Map%03d.json' % m for m in maps}
    inputs = {k: v for k, v in old.get('inputs', {}).items()
              if not (k not in new.get('inputs', {}) and (k in allowed or not k.startswith(('data/', 'js/', 'package.json'))))}
    return source_preserved(dict(old, inputs=inputs), new)


def finish_comparison(baseline: Path) -> None:
    # 整轮成功后先原子移出活动位置；清理中断也不留下半份活动基线。
    retired = baseline.with_name(baseline.name + '.accepted-' + uuid.uuid4().hex)
    baseline.rename(retired)
    shutil.rmtree(retired, ignore_errors=True)


MANUAL_STALE_HOURS = 12


def prune_manual_copies(sandbox: Path, hours: float = MANUAL_STALE_HOURS) -> list:
    """手动跑探针时 manual_sandbox.cjs 每次复制一份种子到 .sandbox/manual/probe-XXXXXX（约 9 MB），自己从不清理
    （主工作区攒到上百 MB）。同步时顺带删掉 hours 小时没动过的旧副本：刚跑完的留着备查，仍在跑的不删。
    只删该命名的普通目录，不跟随符号链接。清理放在这里而不放进 manual_sandbox.cjs：mv_oracle 下的辅助 .cjs 是
    每个探针缓存键的一部分，改它会让所有探针整轮重跑。"""
    manual = sandbox / 'manual'
    if not manual.is_dir() or manual.is_symlink():
        return []
    cutoff = time.time() - hours * 3600
    removed = []
    for d in sorted(manual.iterdir()):
        if re.fullmatch(r'probe-[A-Za-z0-9]{6}', d.name) and d.is_dir() and not d.is_symlink() and d.stat().st_mtime < cutoff:
            shutil.rmtree(d)
            removed.append(d.name)
    return removed


def prune_backups(root: Path, keep: int = KEEP_BACKUPS) -> list:
    """同步备份只留最近 keep 份（用户 2026-10-18 定，含本次新建的这份）；只删「日期_时间_…」命名的备份目录。"""
    dirs = sorted((d for d in root.iterdir() if d.is_dir() and re.match(r'^\d{8}_\d{6}', d.name)),
                  key=lambda d: (d.name[:15], d.stat().st_mtime))
    removed = []
    for d in dirs[:-keep] if keep > 0 else dirs:
        shutil.rmtree(d)
        removed.append(d.name)
    return removed


RUNNER = Path(__file__).resolve().parent.parent / '07_开发环境' / '并行测试.py'  # 共用槽位代码（测试替换 HERE 时也用真文件）
_runner = None
_runner_lock = threading.Lock()


# 特别吃内存的探针多占几槽（2026-10-25 哪吒）：event_probe 一个进程连跑全部事件页，常驻 4.5GB、堆上限放到 10GB，
# 本机 16GB／8 核；按 1 槽算时四个槽可能同时塞进两个这种进程加两场 Godot 测试，压到换页、负载 40 以上。没列的占 1 槽。
# XIYOU_PROBE_WEIGHTS='{"x_probe.cjs": 2}' 可临时覆盖（超过共用上限按上限算）。
PROBE_WEIGHTS = {'event_probe.cjs': 3}

# event_probe 按地图分几个进程并行（唐僧 2026-10-25）：整轮 4318 例单进程是同步的长杆。按用例数把单元（m<地图>、ce<公共事件>）
# 均分成几组（单元不拆开），各组一个进程、各占 1 槽、各用自己的存档目录，跑完按原顺序拼回 .sandbox/events.json（与单进程逐字相同）。
# EVENT_PROBE_SHARDS=1 退回单进程。各段的存档目录不带头顶／云裳成长记录：每例新开局都要整份复制重写这两份记录，
# 种子里已累积到 7 MB／4 MB，空记录的输出相同（117 例实测）。
EVENT_LEDGERS = ('crown_progress_v1.json', 'yunshang_orders_v1.json')
EVENT_MERGE_JS = r'''
const fs = require('fs'), [out, order, ...parts] = process.argv.slice(1);
const docs = parts.map(p => JSON.parse(fs.readFileSync(p, 'utf8')));
for (const d of docs) if (JSON.stringify([d.sourceIdentity, d.setup]) !== JSON.stringify([docs[0].sourceIdentity, docs[0].setup])) throw new Error('分段的来源或设置不一致');
// 每个单元整段落在一个分段里：按单元原顺序稳定排序即还原单进程顺序
const rank = new Map(JSON.parse(order).map((u, i) => [u, i])), unit = c => c.kind === 'common' ? 'ce' + c.common : 'm' + c.map;
const cases = [].concat(...docs.map(d => d.cases)).map((c, i) => [c, i]).sort((a, b) => rank.get(unit(a[0])) - rank.get(unit(b[0])) || a[1] - b[1]).map(x => x[0]);
fs.writeFileSync(out, JSON.stringify({sourceIdentity: docs[0].sourceIdentity, setup: docs[0].setup, cases}));
console.log(JSON.stringify({version: docs[0].sourceIdentity.releaseVersion, cases: cases.length, shards: parts.length,
  unfinished: cases.filter(x => !x.finished).map(x => x.id), errors: cases.filter(x => x.errors).map(x => x.id)}));
'''


def event_units(env):
    """与 event_probe.cjs 的用例顺序相同：切片地图依次，再切片公共事件；附各单元用例数（公共事件按 1 算）。"""
    gen = Path(env['XIYOU_GENERATED'])
    slice_ = json.loads((HERE / 'xiyou_slice.json').read_text(encoding='utf-8'))
    manifest = json.loads((gen / 'manifest.json').read_text(encoding='utf-8'))
    out = []
    for mid in slice_['maps']:
        data = json.loads((gen / 'maps' / ('Map%03d.json' % mid)).read_text(encoding='utf-8'))
        n = sum(1 for ev in data.get('events') or [] if ev for pg in ev['pages']
                if any(c.get('code') != 0 for c in pg.get('list') or []))
        out.append(('m%d' % mid, n))
    return out + [('ce%d' % ce, 1) for ce in manifest['slice']['commonEvents']]


def split_balanced(weighted, n):
    """按用例数把单元分成至多 n 组（大单元先放进当前最轻的组）；组内保持原顺序，拼回时按单元原顺序排。"""
    groups = [[0, []] for _ in range(n)]
    for unit, w in sorted(weighted, key=lambda x: -x[1]):
        g = min(groups, key=lambda g: g[0])
        g[0] += w
        g[1].append(unit)
    pos = {u: i for i, (u, _) in enumerate(weighted)}
    return [sorted(g[1], key=pos.get) for g in groups if g[1]]


def run_event_sharded(cmd, env, box, only=None):
    """event_probe 分段并行；结果写 .sandbox/events.json，返回与 run_node 同形的结果。"""
    import concurrent.futures
    shards = max(1, int(os.environ.get('EVENT_PROBE_SHARDS', '4')))
    try:
        weighted = [u for u in event_units(env) if only is None or u[0] in set(only)]
    except (OSError, KeyError, ValueError):   # 读不到切片／产物（如测试夹具）：照旧单进程，由探针自己报错
        return run_node(cmd, env)
    groups = split_balanced(weighted, shards) if shards > 1 else []
    if len(groups) < 2:
        return run_node(cmd, env)

    def part(i):
        sub = box / ('shard-%d' % i)
        sub.mkdir()
        for name in ['save', 'macport']:
            if (box / name).is_dir():
                shutil.copytree(box / name, sub / name)
        e = dict(env, XIYOU_ORACLE_SANDBOX=str(sub), XIYOU_PROBE_UNITS=json.dumps(groups[i]),
                 XIYOU_EVENT_OUT=str(sub / 'events.json'))
        return run_node(cmd, e, weight=1)
    with concurrent.futures.ThreadPoolExecutor(len(groups)) as pool:
        done = list(pool.map(part, range(len(groups))))
    text = ''.join('（第 %d 段 %d 个单元）\n%s%s' % (i + 1, len(groups[i]), p.stdout, p.stderr) for i, p in enumerate(done))
    bad = [p for p in done if p.returncode]
    if bad:
        return subprocess.CompletedProcess(cmd, bad[0].returncode, text, '')
    m = subprocess.run(['node', '-e', EVENT_MERGE_JS, str(SANDBOX / 'events.json'), json.dumps([u for u, _ in weighted])] +
                       [str(box / ('shard-%d' % i) / 'events.json') for i in range(len(groups))],
                       cwd=ORACLE_DIR, capture_output=True, text=True)
    return subprocess.CompletedProcess(cmd, m.returncode, text + m.stdout, m.stderr)


def runner():
    global _runner
    with _runner_lock:  # 几个探针线程同时首次调用：模块执行完才公开，别的线程不会拿到半载入的模块
        if _runner is None:
            import importlib.util
            spec = importlib.util.spec_from_file_location('xiyou_parallel_tests', RUNNER)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            _runner = module
    return _runner


def probe_weight(name):
    try:
        extra = json.loads(os.environ.get('XIYOU_PROBE_WEIGHTS') or '{}')
    except ValueError:
        extra = {}
    return int(extra.get(name, PROBE_WEIGHTS.get(name, 1)))


@contextlib.contextmanager
def heavy_slot(label, weight=1):
    """占共用槽再跑重进程（node 探针、Godot 导入）。排队时每 60 秒打一行「等槽」到标准输出：
    长任务.py 的看门狗按输出判断有没有进展，排队不再被误判卡死（XIYOU_SLOT_HEARTBEAT 调间隔）。"""
    r = runner()

    def waiting(seconds):
        print('等槽：%s 已等 %d 秒（占 %d 槽，共用上限 %d）' % (label, seconds, min(weight, r.global_limit()), r.global_limit()),
              flush=True)
    with r.global_slot(r.state_dir(str(ROOT)), r.global_limit(), weight, waiting,
                       float(os.environ.get('XIYOU_SLOT_HEARTBEAT', '60'))):
        yield


def run_node(cmd, env, weight=None):
    """跑一个 node 探针：先在 并行测试.py 的跨工作树共用槽（CHECK_GLOBAL_JOBS，状态目录同测试）占位再跑，
    几条车道同时同步、跑测试时合起来不超上限（唐僧 2026-10-21：两条车道同步加测试曾把 8 核负载冲到 21）。
    吃内存的探针按 PROBE_WEIGHTS 多占几槽。SYNC_JOBS 只决定本次同步最多同时排几个探针。"""
    with heavy_slot(' '.join(cmd), probe_weight(cmd[0]) if weight is None else weight):
        # event_probe 在一个进程里连跑全部事件页，内存随事件数涨；切片事件过千页后撞 node 默认 4GB 堆上限（悟空_55 簇 8／13 同步 OOM），放宽到 10GB
        # 环境里已有 NODE_OPTIONS（如云端容器的 --use-openssl-ca）时 setdefault 不生效、仍是默认堆，event_probe 会 OOM：没写堆上限就追加
        env = dict(env)
        if '--max-old-space-size' not in env.get('NODE_OPTIONS', ''):
            env['NODE_OPTIONS'] = (env.get('NODE_OPTIONS', '') + ' --max-old-space-size=10240').strip()
        return subprocess.run(['node'] + cmd, cwd=ORACLE_DIR, env=env, capture_output=True, text=True)


def run(cmd, cwd, log):
    log.write('$ ' + ' '.join(cmd) + '\n')
    log.flush()
    p = subprocess.run(cmd, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise RuntimeError('命令失败（%d）：%s' % (p.returncode, ' '.join(cmd)))


def run_probes(log, cache=None):
    """互不依赖的探针并行跑（AGENTS.md「省额度约定」同步提速）。每个探针一个独立存档目录
    .sandbox/run/<探针>（开跑前复制 .sandbox 现有的 save／macport，各探针看到同样的起始状态），
    产物照旧写 .sandbox/*.json；日志按 PROBES 顺序写回，并记每个探针的耗时。SYNC_JOBS=1 退回串行。
    每个探针运行时另占跨工作树共用槽（run_node），排队等槽的时间算在该探针耗时里。"""
    import concurrent.futures
    import time
    jobs = max(1, int(os.environ.get('SYNC_JOBS', '4')))
    plan, reused, keys, units, partial, misses = [], [], {}, {}, {}, {}
    for command, outputs in PROBES:
        key = cache.key(command) if cache else None
        keys[command[0]] = key
        units[command[0]] = cache.units(command) if cache else None
        todo = cache.plan(command, outputs, key, units[command[0]]) if cache else None
        issue = getattr(cache, 'shard_issues', {}).get(command[0]) if cache else None
        if issue:
            line = 'SHARD_OFF ' + json.dumps(dict(issue, probe=command[0], hint='读取面与审过的不同，本轮不按单元增量；'
                                                 '核对它仍只读允许的产物后把 incremental_sync.GENERATED_SHARD_AUDITS 改成 reads:<上面的值>'),
                                            ensure_ascii=False)
            log.write(line + '\n')
            print(line, flush=True)
        if todo == []:
            reused.append(command[0])
            cache.record(command, outputs, key, units[command[0]])
            log.write('CACHE_HIT ' + command[0] + '\n')
        else:
            if cache:
                misses[command[0]] = cache.misses[command[0]]
                log.write('CACHE_MISS ' + json.dumps({'probe': command[0], 'reasons': misses[command[0]]}, ensure_ascii=False) + '\n')
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
        return {'executed': [], 'partial': {}, 'reused': reused, 'seconds': {}, 'missReasons': misses}
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

    running = {}  # 正在跑的探针命令 → 开始时间（含等槽），心跳用
    running_lock = threading.Lock()

    def one(work):
        logical, cmd, outputs = work
        with running_lock:
            running[' '.join(cmd)] = time.time()
        try:
            return one_inner(work)
        finally:
            with running_lock:
                running.pop(' '.join(cmd), None)

    def one_inner(work):
        logical, cmd, outputs = work
        for rel in outputs:
            (SANDBOX / rel).unlink(missing_ok=True)
        # 同一个切片探针的不同难度各有独立种子副本，不共享写入目录。
        box = runs / (Path(cmd[0]).stem + ('-d' + cmd[1] if cmd[0] == 'slice_probe.cjs' and len(cmd) == 2 else ''))
        box.mkdir(parents=True)
        event = cmd[0] == 'event_probe.cjs'
        for name in ['save', 'macport']:
            if (SANDBOX / name).is_dir():
                shutil.copytree(SANDBOX / name, box / name, ignore=shutil.ignore_patterns(*EVENT_LEDGERS) if event else None)
        env = dict(os.environ, XIYOU_ORACLE_SANDBOX=str(box))
        node = (lambda c, e, only=None: run_event_sharded(c, e, box, only)) if event else (lambda c, e, only=None: run_node(c, e))
        t = time.time()
        part = partial.get(logical)
        if part is None:
            p = node(cmd, env)
            return cmd, p.returncode, p.stdout + p.stderr, time.time() - t
        text = ''
        if part:
            env['XIYOU_PROBE_UNITS'] = json.dumps(part)
            p = node(cmd, env, part)
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

    work = []
    for cmd, outputs in plan:
        if cmd[0] == 'slice_probe.cjs' and cmd[1:] == [str(d) for d in range(1, 7)]:
            expected = ['slice/slice_d%d.json' % d for d in range(1, 7)]
            if outputs != expected:
                raise RuntimeError('切片难度分命令的产物声明不匹配')
            work.extend((cmd[0], [cmd[0], str(d)], [expected[d - 1]]) for d in range(1, 7))
        else:
            work.append((cmd[0], cmd, outputs))
    slow = ['slice_probe.cjs', 'smart_ai_probe.cjs', 'event_probe.cjs', 'zhenqi_probe.cjs', 'dungeon_probe.cjs', 'sequence_probe.cjs']
    order = sorted(range(len(work)), key=lambda i: slow.index(work[i][0]) if work[i][0] in slow else len(slow))
    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        futures = {i: pool.submit(one, work[i]) for i in order}
        results = [None] * len(work)
        # 探针心跳（2026-10-26 哪吒）：event_probe 整轮约 100 分钟一行不出，长任务.py 的无输出看门狗（默认 3600 秒）会把正常进行的
        # 同步判成卡死。等探针时每 XIYOU_PROBE_HEARTBEAT 秒（默认 60，0 关闭）为每个在跑的探针打一行 PROBE_RUNNING。
        beat = float(os.environ.get('XIYOU_PROBE_HEARTBEAT', '60'))
        waiting = {f: i for i, f in futures.items()}
        while waiting:
            done, _ = concurrent.futures.wait(waiting, timeout=beat if beat > 0 else None,
                                              return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                i = waiting.pop(future)
                results[i] = future.result()
                print('PROBE_DONE=' + json.dumps({'probe': results[i][0][0], 'seconds': round(results[i][3], 3),
                                                 'command': results[i][0],
                                                 'exitCode': results[i][1]}), flush=True)
            if not done:
                now = time.time()
                with running_lock:
                    alive = sorted(running.items(), key=lambda x: x[1])
                for label, t in alive:
                    print('PROBE_RUNNING=' + json.dumps({'probe': label.split()[0], 'command': label.split(),
                                                        'seconds': round(now - t)}), flush=True)
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
            'missReasons': misses,
            # 多命令探针的合计为子进程用时之和；墙钟由同步报告 start/end 记录。
            'seconds': {name: round(sum(r[3] for r in results if r[0][0] == name), 3) for name, _, _ in work},
            'commands': [{'command': cmd, 'seconds': round(sec, 3), 'exitCode': code} for cmd, code, _, sec in results]}


def _main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--app', type=Path, default=DEFAULT_APP)
    ap.add_argument('--generated', type=Path, default=DEFAULT_OUT)
    ap.add_argument('--no-register', action='store_true', help='只同步与比较，不改来源登记/当前状态')
    ap.add_argument('--accept-additions', action='store_true',
                    help='同源且旧用例逐条相同、只增已知结构新用例时自动接受；不接受规则变化/删除/新用例错误')
    ap.add_argument('--accept-changes', type=Path, action='append', default=[], metavar='接受单.json',
                    help='显式接受接受单逐条列出的既有用例改变（须写理由、摘要逐项对上，每条都要用上）')
    ap.add_argument('--accept-withdrawal', action='append', default=[], metavar='地图号',
                    help='切片撤出地图后显式接受（可多次，如 41 或 Map041）：须恰好等于本轮少掉的地图，去掉旧基线里已没有的条目再比较')
    ap.add_argument('--from-worktree', type=Path, help='合并时用车道已同步的产物（按指纹核对），不满足条件退出码 3')
    ap.add_argument('--full', '--full-probes', dest='full', action='store_true', help='忽略探针缓存，强制全量转换与全部探针（--full-probes 同义）')
    ap.add_argument('--no-import', action='store_true', help='结束时不跑 godot --import')
    a = ap.parse_args()
    try:
        withdraw = {int(re.sub(r'^(?i:map)', '', str(m))) for m in a.accept_withdrawal}
    except ValueError:
        ap.error('--accept-withdrawal 写地图号，如 41 或 Map041')
    if a.full and a.from_worktree:
        ap.error('--full 与 --from-worktree 不能一起使用')
    # 多会话并行（AGENTS.md）：来源登记／当前状态只由总装在主工作区改，worktree 里自动不登记
    git = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'],
                         capture_output=True, text=True).stdout.split('\n')
    if not a.no_register and len(git) > 1 and git[0] != git[1]:
        a.no_register = True
        print('在 worktree 里运行：只同步与比较，不写来源登记／当前状态（由总装在主工作区登记）')
    app, gen = a.app.resolve(), a.generated.resolve()
    # 接受单先读：格式不对时在写任何产物之前停下
    acceptances, acceptance_sources = load_acceptances(a.accept_changes) if a.accept_changes else ([], [])
    lane = None
    if a.from_worktree:
        lane, why = clone_from_worktree(a.from_worktree.resolve(), gen)
        if lane is None:
            print('不用车道产物：' + why + '；请改跑完整同步')
            return 3
    # clone预检失败不写任何产物；此处必须在滚动备份淘汰、转换或clone覆盖gen之前。
    baseline = comparison_baseline(gen)
    old_manifest = json.loads((baseline / 'manifest.json').read_text())
    old_version = old_manifest.get('releaseVersion')
    new_version = json.loads((app / 'package.json').read_text()).get('releaseVersion')
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    backup = ROOT / '03_再刷重制_Godot/04_验证/本地结果/自动同步' / ('%s_%s-%s' % (stamp, old_version, new_version))
    backup.mkdir(parents=True)
    report_pruned = prune_backups(backup.parent)
    pruned_manual = prune_manual_copies(SANDBOX)
    for name in ['oracle', 'db', 'maps', 'manifest.json', 'slice.json']:
        src = gen / name
        if src.is_dir():
            shutil.copytree(src, backup / name)
        elif src.exists():
            shutil.copy2(src, backup / name)
    report = {'from': old_version, 'to': new_version, 'backup': str(backup.relative_to(ROOT)), 'generated': str(gen),
              'prunedBackups': report_pruned, 'prunedManualCopies': len(pruned_manual), 'comparisonBaseline': str(baseline.relative_to(ROOT))}
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
    # 撤出切片（--accept-withdrawal）：参数须恰好等于本轮少掉的地图，旧基线去掉新参照已没有的条目后再比较
    old_oracle, withdrawn_ok = baseline / 'oracle', True
    if withdraw:
        gone_maps = set(old_manifest.get('slice', {}).get('maps', [])) - set(new_manifest.get('slice', {}).get('maps', []))
        trimmed = Path(tempfile.mkdtemp(prefix='withdrawal-', dir=backup))
        report['withdrawal'] = {'maps': sorted(withdraw), 'sliceRemovedMaps': sorted(gone_maps)}
        if withdraw != gone_maps:
            withdrawn_ok = False
            report['withdrawal']['problem'] = '--accept-withdrawal 与本轮切片少掉的地图不符'
        else:
            report['withdrawal']['removed'] = {k: {'count': len(v), 'keys': v[:50]}
                                               for k, v in withdraw_baseline(old_oracle, gen / 'oracle', trimmed).items()}
            old_oracle = trimmed
    # 测量比较
    measure = {}
    for name in sorted({f.name for d in [gen / 'oracle', old_oracle] for f in d.glob('*.json')}):
        f = gen / 'oracle' / name
        old = old_oracle / f.name
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
    report['additionCheck'] = compare_directories(old_oracle, gen / 'oracle', probe_outputs())
    report['sameExistingSource'] = withdrawn_ok and (withdrawn_source_preserved(old_manifest, new_manifest, withdraw) if withdraw
                                                     else source_preserved(old_manifest, new_manifest))
    v = subprocess.run([sys.executable, str(HERE / '验证西游来源.py'), '--app', str(app), '--generated', str(gen)], capture_output=True, text=True)
    report['verify'] = (v.stdout.strip().splitlines() or [''])[-1]
    report['verifyOk'] = v.returncode == 0
    check = report['additionCheck']
    report['changeCandidates'] = change_candidates(check)
    resolved = apply_acceptances(check, acceptances)
    if acceptances:
        report['acceptChanges'] = {'sources': acceptance_sources, 'accepted': resolved['accepted'], 'unused': resolved['unused'],
                                   'remainingProblems': resolved['problems']}
    additions = bool(check['additions'])
    # 新增与显式接受都处理完后不能剩任何问题；接受单每条都要用上；新增仍须 --accept-additions
    clean = (not resolved['problems'] and not resolved['unused'] and (additions or bool(resolved['accepted'])))
    accepted = bool(clean and (a.accept_additions or not additions)
                    and report['sameExistingSource'] and report['verifyOk'])
    ok = report['verifyOk'] and not resolved['unused'] and (not measure or accepted) and withdrawn_ok
    report['acceptedAdditions'] = accepted and additions
    report['acceptedChanges'] = resolved['accepted'] if accepted else []
    if accepted:
        what = '、'.join(x for x in ['新增用例' if additions else '', '显式接受 %d 条既有用例改变' % len(resolved['accepted'])
                                      if resolved['accepted'] else ''] if x)
        report['result'] = what + '，已接受' + ('并登记' if not a.no_register else '（不登记）')
    elif resolved['unused']:
        report['result'] = '接受单有 %d 条对不上本轮变化，整轮拒收' % len(resolved['unused'])
    elif clean and report['sameExistingSource'] and report['verifyOk']:
        report['result'] = '只增新用例；加 --accept-additions 可自动接受'
    else:
        report['result'] = '测量不变，已登记' if ok and not a.no_register else ('测量不变' if ok else '有变化，请人工查看')
    if withdraw and withdrawn_ok and ok:
        report['result'] = '撤出 %s 已接受；%s' % ('、'.join('Map%03d' % m for m in sorted(withdraw)), report['result'])
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
    usable = (not report.get('cacheError') and not report.get('importError') and report['verifyOk'] and report['sameExistingSource']
              and (not measure or (clean and not resolved['unused'])))
    if usable and lane is None:
        write_stamp(gen, report)
    elif not usable:
        (gen / STAMP).unlink(missing_ok=True)
    # 缓存只描述测量与输入，不能充当接受记录。登记、导入、缓存与指纹均成功才推进接受边界。
    if ok:
        if report['acceptedChanges']:
            audit = ROOT / '03_再刷重制_Godot/04_验证/本地结果/测量接受记录.jsonl'
            with audit.open('a') as f:
                f.write(json.dumps({'time': dt.datetime.now().isoformat(timespec='seconds'), 'generated': str(gen),
                                    'backup': report['backup'], 'sources': acceptance_sources,
                                    'accepted': report['acceptedChanges']}, ensure_ascii=False) + '\n')
        finish_comparison(baseline)
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
    conclusion = ('显式接受 %d 条既有用例改变（见同步报告 acceptedChanges）' % len(report['acceptedChanges'])
                  if report.get('acceptedChanges') else
                  '既有用例逐条不变，只增新用例' if report.get('acceptedAdditions') else '全部参照去来源身份后测量不变')
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
