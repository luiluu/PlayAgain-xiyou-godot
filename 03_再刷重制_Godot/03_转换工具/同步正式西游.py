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
   只差测量接受（来源核验通过、导入成功、探针缓存发布成功，退出码 2）时也写，标 pendingAcceptance：产物是按这组输入如实测出的，
   接不接受由合并时 main 用自己的基线重新比较决定，接受规则不变（2026-11-07 同步提速，XIYOU_REUSE_PENDING_STAMP=0 回退）。
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
import itertools
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
from incremental_sync import SHARDS, ProbeCache, atomic_json, carry_probe_deps
from oracle_additions import (compare_directories, current_digest, payload, source_preserved, has_error, retained_errors_unchanged,  # noqa: E402
                              load_acceptances, apply_acceptances, change_candidates, field_keys, groups)

ORACLE_DIR = HERE / 'mv_oracle'
SANDBOX = ORACLE_DIR / '.sandbox'
STAMP = 'sync_stamp.json'
TOOLS_REL = HERE.relative_to(ROOT).as_posix()   # 03_再刷重制_Godot/03_转换工具
PRESETS_REL = TOOLS_REL + '/event_presets.json'
# 只读的检查工具不影响产物，不算进转换工具指纹。oracle_additions.py 只决定测量变化接不接受（产物原样发布或整轮拒收），
# 不改产物内容；列进来免得改比较规则让各车道的同步指纹失效（2026-10-28 哪吒_5，唐僧同意）。
READ_ONLY_TOOLS = {'内容覆盖检查.py', '事件指令统计.py', '共性参照验收.py', '验证西游来源.py', '角色模板预检.py', 'oracle_additions.py'}
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
    (['map132_shop_probe.cjs'], ['map132_shops.json']),
    (['yomi_battle_probe.cjs'], ['yomi_battle.json']),
    (['sukuna_battle_probe.cjs'], ['sukuna_battle.json']),
    (['toji_probe.cjs'], ['toji.json']),
    (['toji_battle_probe.cjs'], ['toji_battle.json']),
    (['guyu_probe.cjs'], ['guyu.json']),
    (['guyu_battle_probe.cjs'], ['guyu_battle.json']),
    (['three_growth_probe.cjs'], ['three_growth.json']),
    (['xuan_chart_probe.cjs'], ['xuan_chart.json']),
    (['guyu_ui_probe.cjs'], ['guyu_ui.json']),
    (['mira_battle_probe.cjs'], ['mira_battle.json']),
    (['raven_soul_probe.cjs'], ['raven_soul.json']),
    (['raven_artifact_probe.cjs'], ['raven_artifact.json']),
    (['battle_drop_probe.cjs'], ['battle_drop.json']),
    (['difficulty_enemy_probe.cjs'], ['difficulty_enemy.json']),
    (['difficulty_actor_probe.cjs'], ['difficulty_actor.json']),
    (['difficulty_troop_probe.cjs'], ['difficulty_troop.json']),
    (['actor1_damage_probe.cjs'], ['actor1_damage.json']),
    (['toji_eva_probe.cjs'], ['toji_eva.json']),
    (['mira_raven_hit_probe.cjs'], ['mira_raven_hit.json']),
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
    (['alien_hide_probe.cjs'], ['alien_hide.json']),
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
    (['star_warehouse_probe.cjs'], ['star_warehouse.json']),
    (['actor_passive_probe.cjs'], ['actor_passive.json']),
    (['achievement_probe.cjs'], ['achievements.json']),
    (['achievement_badge_probe.cjs'], ['achievement_badges.json']),
    (['weak_challenge_probe.cjs'], ['weak_challenge.json']),
    (['raven_visual_probe.cjs'], ['raven_visual.json']),
    (['shield_probe.cjs'], ['shield.json']),
    (['imported_balance_probe.cjs'], ['imported_balance.json']),
    (['state_effects_probe.cjs'], ['state_effects.json']),
    (['state_js_probe.cjs'], ['state_js.json']),
    (['dot_probe.cjs'], ['dot.json']),
    (['barrier_probe.cjs'], ['barrier.json']),
    (['sve_probe.cjs'], ['sve.json']),
    (['svpng_probe.cjs'], ['svpng.json']),
    (['vsfx_probe.cjs'], ['vsfx.json']),
    (['collapse_probe.cjs'], ['collapse.json']),
    (['passive_probe.cjs'], ['passive.json']),
    (['scan2_probe.cjs'], ['scan2.json']),
    (['review135_probe.cjs'], ['review135.json']),
    (['stage50_review_probe.cjs'], ['stage50_review.json']),
    (['attack_element_probe.cjs'], ['attack_elements.json']),
    (['multi_element_probe.cjs'], ['multi_element.json']),
    (['qiyu_probe.cjs'], ['qiyu.json']),
    (['cat_probe.cjs'], ['cat.json']),
    (['race_battle_probe.cjs'], ['race_battle.json']),
    (['alien_battle_probe.cjs'], ['alien_battle.json']),
    (['alien_affix_probe.cjs'], ['alien_affix.json']),
    (['attack_query_probe.cjs'], ['attack_query.json']),
    (['weapon_unleash_probe.cjs'], ['weapon_unleash.json']),
    (['skill_change_to_probe.cjs'], ['skill_change_to.json']),
    (['enemy_book_defeat_probe.cjs'], ['enemy_book_defeat.json']),
    (['script_gaps_probe.cjs'], ['script_gaps.json']),
    (['lobby_shop_probe.cjs'], ['lobby_shops.json']),
    (['param_cache_probe.cjs'], ['param_cache.json']),
    (['common_script_probe.cjs'], ['common_scripts.json']),
    (['event_probe.cjs'], ['events.json']),       # 需要本次转换的 generated/maps，放在转换器之后
    (['event_state_probe.cjs'], ['event_states.json']),   # 有状态变体（mv_oracle/event_presets.json），同样读 generated/maps
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


def tools_digest(root: Path = None, skip=()) -> str:
    """决定转换产物的本库文件：03_转换工具 下受 Git 跟踪的文件（ui_reference、.md 与只读检查工具除外），按路径与内容摘要。"""
    root = root or ROOT
    tools = TOOLS_REL
    out = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', 'ls-files', '-z', '--', tools],
                         capture_output=True, text=True).stdout
    h = hashlib.sha256()
    for rel in sorted(x for x in out.split('\0') if x.startswith(tools + '/')):
        if ('/ui_reference/' in rel or rel.endswith('.md') or Path(rel).name in READ_ONLY_TOOLS
                or rel in skip or not (root / rel).is_file()):
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


PRESETS_REL = TOOLS_REL + '/event_presets.json'
# 事件状态探针的结果是「每个预设变体一条」，互相独立（BO 分段并行也靠这点）。车道只改了 event_presets.json、合并时 main 又多了别的车道的预设行，
# 车道产物里缺那几行的结果；这里把车道结果和 main 现有产物里的对应结果按合并后预设文件的顺序拼起来，逐字等于整份重跑的输出（tools73）。
PRESETS_MERGE_JS = r'''
const fs = require('fs'), [out, order, laneFile, mainFile, presets] = process.argv.slice(1);
const lane = JSON.parse(fs.readFileSync(laneFile, 'utf8')), main = JSON.parse(fs.readFileSync(mainFile, 'utf8'));
const head = d => JSON.stringify([d.sourceIdentity, d.setup]);
if (head(lane) !== head(main)) { console.error('来源或设置不同'); process.exit(3); }
const rows = Object.fromEntries(JSON.parse(fs.readFileSync(presets, 'utf8')).cases.map(p => [p.base + '#' + p.tag, p]));
const pick = (doc, id) => doc.cases.find(c => c.id === id);
const cases = [], skipped = [], version = lane.sourceIdentity.releaseVersion;
for (const id of JSON.parse(order)) {
  // goneIn：这一版基础用例已没了的预设，探针跳过并记进 skippedPresets（同 event_state_probe.cjs）
  if ((rows[id].goneIn || []).includes(version)) { skipped.push(id); continue; }
  const want = JSON.stringify(rows[id].preset), base = rows[id].base;
  const hit = [lane, main].map(d => pick(d, id)).find(c => c && JSON.stringify(c.preset) === want && c.base === base);
  if (!hit) { console.error('没有可用结果：' + id); process.exit(3); }
  cases.push(hit);
}
fs.writeFileSync(out, JSON.stringify(Object.assign({sourceIdentity: lane.sourceIdentity, setup: lane.setup, cases}, skipped.length ? {skippedPresets: skipped} : {})));
console.log(JSON.stringify({cases: cases.length}));
'''


def presets_merge_plan(worktree: Path, gen: Path, lane_gen: Path):
    """车道与合并后 main 的转换工具只差 event_presets.json 时的拼接方案：先在临时文件里拼好并核对（此时不动任何产物）；
    认不出（任何一处拿不准）返回 (None, 原因)，调用方照旧完整同步。"""
    try:
        if tools_digest(skip={PRESETS_REL}) != tools_digest(worktree, skip={PRESETS_REL}):
            return None, '转换工具除预设外也不同'
        main_cases = json.loads((ROOT / PRESETS_REL).read_text())['cases']
        order = [c['base'] + '#' + c['tag'] for c in main_cases]
        if len(set(order)) != len(order):
            return None, '预设行的 base#tag 不唯一'
        lane_file, main_file = lane_gen / 'oracle/event_states.json', gen / 'oracle/event_states.json'
        if not lane_file.is_file() or not main_file.is_file():
            return None, '车道或 main 缺 event_states.json'
        merged = Path(tempfile.mkdtemp(prefix='xiyou_presets_merge_')) / 'event_states.json'
        p = subprocess.run(['node', '-e', PRESETS_MERGE_JS, str(merged), json.dumps(order), str(lane_file), str(main_file),
                            str(ROOT / PRESETS_REL)], capture_output=True, text=True)
        if p.returncode:
            return None, (p.stderr.strip() or p.stdout.strip() or '拼接被拒')[:120]
        return {'merged': str(merged)}, None
    except (OSError, ValueError, KeyError, TypeError):
        return None, '预设方案读取失败'


def reuse_pending_stamp() -> bool:
    """只差测量接受的车道同步也写／认可复用指纹（11-07 换源合并 main 整轮重跑 3.5 小时）。XIYOU_REUSE_PENDING_STAMP=0 回到旧行为。"""
    return os.environ.get('XIYOU_REUSE_PENDING_STAMP', '1') != '0'


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
    if stamp.get('pendingAcceptance') and not reuse_pending_stamp():
        return None, '车道指纹是待接受的（XIYOU_REUSE_PENDING_STAMP=0 不复用）'
    if stamp.get('toolsDigest') != tools_digest(worktree):
        return None, '车道同步后又改了转换工具文件'
    if outputs_digest(lane_gen) != stamp.get('outputsDigest'):
        return None, '车道产物在同步后被改动'
    if stamp.get('toolsDigest') != tools_digest():
        # main 合并后的转换工具与车道同步时不同：只差 event_presets.json（多了别的车道已合进来的预设行）时拼接复用，否则完整同步（tools73）
        plan, why = presets_merge_plan(worktree, gen, lane_gen)
        if plan is None:
            return None, '合并后 main 的转换工具文件与车道同步时不同（' + why + '）'
        return (lane_gen, dict(stamp, presetsMerge=plan)), None
    return (lane_gen, stamp), None


def write_stamp(gen: Path, report: dict, pending: bool = False) -> None:
    stamp = {'toolsDigest': tools_digest(), 'outputsDigest': outputs_digest(gen), 'releaseVersion': report.get('to'),
             'result': report.get('result'), 'time': dt.datetime.now().isoformat(timespec='seconds'), 'backup': report.get('backup')}
    if pending:
        # 产物如实，但本树的测量变化还没接受：合并时 main 照样用自己的基线比较、要接受单（--from-worktree 不放松任何接受规则）
        stamp['pendingAcceptance'] = True
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


def keyed_diff(a, b, fields, path, out, limit):
    """按稳定键对齐的列表差异：新增键、删除键、同键内容改变（插在中间、重排不再报成一串下标改动，tools23）。键不全时返回 False。"""
    try:
        ga, gb = groups(a, fields), groups(b, fields)
    except ValueError:
        return False
    def label(key):
        return '[' + ','.join('%s=%s' % (k, v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)) for k, v in json.loads(key)) + ']'
    for key in sorted(ga.keys() | gb.keys()):
        if len(out) >= limit:
            break
        if key not in gb:
            out.append(path + label(key) + ' 删除')
        elif key not in ga:
            out.append(path + label(key) + ' 新增')
        elif ga[key] != gb[key]:
            if sum(ga[key].values()) == 1 and sum(gb[key].values()) == 1:
                diff_paths(json.loads(next(iter(ga[key]))), json.loads(next(iter(gb[key]))), path + label(key), out, limit)
            else:
                out.append(path + label(key) + ' 同键 %d→%d 条' % (sum(ga[key].values()), sum(gb[key].values())))
    return True


def diff_paths(a, b, path='', out=None, limit=20, name=None):
    """给人看的测量差异路径。name（参照文件名）给出时，顶层带稳定键的列表（oracle_additions 的 KEYS 与自动认的 cases）按键对齐；
    其余列表照旧按下标。是否放行由 compare_directories 判，这里只是报告。"""
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if type(a) is not type(b):
        out.append(path or '/')
    elif isinstance(a, dict):
        for k in sorted(set(a) | set(b), key=str):
            if k not in a or k not in b:
                out.append(path + '/' + str(k))
            elif (name and not path and isinstance(a[k], list) and isinstance(b[k], list) and a[k] != b[k]
                  and (fields := field_keys(name, k, a[k], b[k])) and keyed_diff(a[k], b[k], fields, '/' + str(k), out, limit)):
                continue
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


def main_generated(gen: Path):
    """车道工作树里返回主工作区对应的 generated 目录（同一相对路径）；主工作区或不在工作树里时返回 None。"""
    out = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'],
                         capture_output=True, text=True).stdout.split('\n')
    if len(out) < 2 or not out[1] or out[0] == out[1]:
        return None
    try:
        rel = gen.resolve().relative_to(ROOT.resolve())
    except ValueError:
        return None
    other = Path(out[1]).parent / rel
    return other if (other / 'oracle').is_dir() else None


def lane_drift(gen: Path, main_gen: Path) -> list:
    """车道 generated/oracle 里与主工作区内容不同的参照文件名（本车道先前同步接受的新增，或手动拷进来的探针输出）。"""
    return sorted(p.name for p in (gen / 'oracle').glob('*.json')
                  if (main_gen / 'oracle' / p.name).is_file() and file_digest(p) != file_digest(main_gen / 'oracle' / p.name))


def main_baseline_files(gen: Path, main_gen: Path, drift: list) -> list:
    """drift 里能放心改用主工作区版本当基线的参照：补齐记批次时（参照批次.py）记下了主工作区该文件的摘要，而主工作区现在还是那一版
    （main 没前进），本树的版本却不同＝补齐之后被改过（手动拷的探针输出）。main 已前进的拿不准（车道缺 main 的新用例会被误判成删除），不动。"""
    try:
        recorded = json.loads((gen / 'oracle_batch.json').read_text()).get('mainOracle')
    except (OSError, ValueError):
        return []
    if not isinstance(recorded, dict):
        return []
    return [n for n in drift if recorded.get(n) and recorded[n] == hashlib.sha256((main_gen / 'oracle' / n).read_bytes()).hexdigest()
            and recorded[n] != hashlib.sha256((gen / 'oracle' / n).read_bytes()).hexdigest()]


def merged_main(main_gen: Path):
    """车道已合进主工作区当前 main（主工作区在 main 上、不在合并中，其提交是本树 HEAD 的祖先）时返回该提交号，否则 None。
    这时主工作区 generated/oracle 就是本树所含 main 的已接受测量，可整份当比较基线（tools23）。"""
    def git(*args, cwd=main_gen):
        p = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True)
        return p.stdout.strip() if p.returncode == 0 else None
    common = git('rev-parse', '--path-format=absolute', '--git-common-dir')
    head = git('rev-parse', 'HEAD')
    if not common or not head or git('symbolic-ref', '--short', '-q', 'HEAD') != 'main' or (Path(common) / 'lane-merge/state.json').exists():
        return None
    return head if git('merge-base', '--is-ancestor', head, 'HEAD', cwd=ROOT) is not None else None


def comparison_baseline(gen: Path, main_gen: Path = None) -> Path:
    """首次写产物前原子保存接受边界；拒绝或中断后仍比较同一份数据。
    车道工作树新取基线时（main_gen 给出主工作区 generated），与主工作区不同的参照逐个提示：基线取的是车道自己的，
    手动拷进 generated/oracle 的探针输出会被当成基线、测量改变看不出来（八戒 dev.208 hostScope）。不改用主工作区当基线：
    main 前进后车道没合 main 时，车道产物缺 main 的新用例，会被误判成删除。
    折中（哪吒_10）：补齐记批次时记了主工作区各参照的摘要，其中主工作区至今没变、本树却改过的（补齐后手拷的探针输出），
    基线改用主工作区的版本，手拷的改动才会显示成测量改变；main 已前进的拿不准，仍取车道自己的并提示。
    车道已合进当前 main 时（merged_main，tools23）：主工作区有的参照整份取主工作区的当基线，车道相对 main 的新增与改变照常显示，
    不用再手拷主工作区 generated/oracle（悟空交接：合 main 后 --补齐 按修改时间刷新，车道同步过的文件更新、不被刷新，
    main 期间接受的改变就被当成车道的改变）。拒收后留下的基线是按旧的 main 取的、main 又前进并已合进来时，按新 main 重取。"""
    key = hashlib.sha256(str(gen.resolve()).encode()).hexdigest()
    parent = ROOT / '03_再刷重制_Godot/04_验证/本地结果/同步基线'
    parent.mkdir(parents=True, exist_ok=True)
    baseline = parent / key
    use_main = []
    head = merged_main(main_gen) if main_gen is not None else None
    if head and baseline.exists():
        try:
            old_head = json.loads((baseline / 'main.json').read_text()).get('head')
        except (OSError, ValueError, AttributeError):
            old_head = None
        if old_head != head:
            print('提示：上次留下的比较基线取自%s，车道已合进当前 main（%s），按它的已接受测量重取基线'
                  % ('另一版 main（%s）' % old_head[:9] if old_head else '车道自己的产物', head[:9]), flush=True)
            finish_comparison(baseline)
    if not baseline.exists() and head:
        use_main = sorted(p.name for p in (main_gen / 'oracle').glob('*.json') if (gen / 'oracle' / p.name).is_file())
        drift = [n for n in lane_drift(gen, main_gen) if n in use_main]
        print('提示：车道已合进当前 main（%s），比较基线取主工作区 generated/oracle（%d 个参照，其中 %d 个与本树不同%s）；'
              '车道相对 main 的新增与改变照常显示，不用手拷' % (head[:9], len(use_main), len(drift),
                                                    '：' + '、'.join(drift[:8]) + ('等' if len(drift) > 8 else '') if drift else ''), flush=True)
    elif not baseline.exists() and main_gen is not None:
        drift = lane_drift(gen, main_gen)
        use_main = main_baseline_files(gen, main_gen, drift)
        if use_main:
            print('提示：%d 个参照在补齐之后被改过、而主工作区没变（%s），本次比较基线改用主工作区的版本，这些改动会显示成测量改变'
                  % (len(use_main), '、'.join(use_main[:8]) + ('等' if len(use_main) > 8 else '')), flush=True)
        drift = [n for n in drift if n not in use_main]
        if drift:
            print('提示：本次比较基线取车道自己的 generated/oracle，其中 %d 个与主工作区不同（%s）；'
                  '本树还没合进当前 main：先 git merge main 再同步，基线就整份取主工作区的（不用手拷）；不合 main 时手拷进去的探针输出改动看不出来'
                  % (len(drift), '、'.join(drift[:8]) + ('等' if len(drift) > 8 else '')), flush=True)
    if not baseline.exists():
        staging = Path(tempfile.mkdtemp(prefix=key + '.pending-', dir=parent))
        try:
            shutil.copy2(gen / 'manifest.json', staging / 'manifest.json')
            shutil.copytree(gen / 'oracle', staging / 'oracle')
            for n in use_main:
                shutil.copy2(main_gen / 'oracle' / n, staging / 'oracle' / n)
            (staging / 'identity.json').write_text(json.dumps({'schema': 1, 'generated': str(gen.resolve())}))
            if head:
                (staging / 'main.json').write_text(json.dumps({'head': head}))
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


SLICE_LISTS = ('maps', 'troops', 'enemies', 'actors', 'commonEvents', 'skills', 'animations')
# 参照条目里指向切片各类编号的字段名（小写比较）；撤图归因时用：条目指向「本轮从切片里少掉的」编号才算撤图带走的
REF_FIELDS = {'maps': ('map', 'mapid', 'map_id'), 'troops': ('troop', 'troopid', 'troop_id'), 'enemies': ('enemy', 'enemyid', 'enemy_id'),
              'actors': ('actor', 'actorid', 'actor_id'), 'commonEvents': ('commonevent', 'commoneventid', 'ce', 'ceid'),
              'skills': ('skill', 'skillid', 'skill_id'), 'animations': ('animation', 'animationid')}


def dropped_slice(old_manifest: dict, new_manifest: dict) -> dict:
    """本轮从切片里少掉的各类编号 {类: 集合}（只含非空的类）。"""
    out = {}
    for name in SLICE_LISTS:
        gone = set(old_manifest.get('slice', {}).get(name, [])) - set(new_manifest.get('slice', {}).get(name, []))
        if gone:
            out[name] = gone
    return out


def attributable(row, dropped: dict) -> bool:
    """被基线裁掉的条目能否归因到撤出的切片内容（沙僧第十六期 P2：原来只核对撤的地图集合，新参照多缺了别的无关条目也一并接受）。
    条目（或字典键）里出现被撤编号才算：事件用例号 m<地图>e…、MapNNN、字段 map/troop/enemy/… 的值落在 dropped 里。认不出的不归因。"""
    maps = dropped.get('maps', set())
    if isinstance(row, str):
        m = re.fullmatch(r'(?:Map)?0*(\d+)|m(\d+)(?:e\d+.*)?', row)
        num = int(next(g for g in m.groups() if g)) if m else None
        return num is not None and any(num in v for v in dropped.values())
    if isinstance(row, dict):
        text = json.dumps(row, ensure_ascii=False)
        if any(re.search(r'(?<![A-Za-z0-9])m%d(?:e\d+|[^0-9]|$)' % n, text) or re.search(r'Map0*%d(?!\d)' % n, text) for n in maps):
            return True
        for kind, fields in REF_FIELDS.items():
            ids = dropped.get(kind, set())
            for key, value in row.items():
                if key.lower() in fields and isinstance(value, int) and value in ids:
                    return True
    return False


def withdraw_baseline(old_dir: Path, new_dir: Path, out_dir: Path, dropped: dict = None, unattributed: list = None) -> dict:
    """撤出切片：把旧参照里新参照已没有的条目去掉后写到 out_dir，返回 {文件: 撤掉的键}。
    还在的条目原样保留，交给 compare_directories 照常比较；整份参照被删、未知结构不动（仍是问题）。
    给了 dropped（本轮少掉的切片编号，dropped_slice）时，每个被裁掉的条目要能归因到它们；归不了因的追加到 unattributed。"""
    out_dir.mkdir(parents=True, exist_ok=True)
    removed = {}
    def blame(file, what, subject):
        if dropped is not None and unattributed is not None and not attributable(subject, dropped):
            unattributed.append('%s %s' % (file, what))
    for old in sorted(old_dir.glob('*.json')):
        data = json.loads(old.read_text())
        new = new_dir / old.name
        a, b = payload(data), (payload(json.loads(new.read_text())) if new.exists() else None)
        gone = []
        if isinstance(a, dict) and isinstance(b, dict):
            if old.name == 'maps.json':
                gone = sorted(k for k in a if k not in b)
                for k in gone:
                    blame(old.name, k, k)
                    del data[k]
            for field in (a.keys() & b.keys()) if old.name != 'maps.json' else ():
                x, y = a[field], b[field]
                if isinstance(x, dict) and isinstance(y, dict) and (old.name.startswith('slice_d') and field in ('enemies', 'actors')
                                                                    or old.name == 'formula_programs.json' and field == 'contexts'):
                    drop = sorted(k for k in x if k not in y)
                    for k in drop:
                        # 字典键是敌人／角色／上下文编号：属于被撤的敌人／角色集合才算（上下文键认不出就看条目内容）
                        ok = dropped is None or (str(k).isdigit() and int(k) in dropped.get('enemies' if field == 'enemies' else 'actors', set())) \
                            or attributable(x[k], dropped)
                        if not ok and unattributed is not None:
                            unattributed.append('%s %s:%s' % (old.name, field, k))
                    data[field] = {k: v for k, v in x.items() if k in y}
                    gone += ['%s:%s' % (field, k) for k in drop]
                elif isinstance(x, list) and isinstance(y, list) and (fields := field_keys(old.name, field, x, y)):
                    try:
                        have = set(groups(y, fields))
                        rows = [(next(iter(groups([row], fields))), row) for row in x]
                    except ValueError:
                        continue   # 缺稳定键：不动，交给照常比较报问题
                    for k, row in rows:
                        if k not in have:
                            blame(old.name, '%s:%s' % (field, k), row)
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


def clone_or_copy(src: Path, dst: Path) -> None:
    """备份用 APFS 克隆（cp -c，同卷不另占空间，原文件之后被改写时才分叉）；克隆不成（别的文件系统、跨卷）退回普通复制。
    每份备份原来占 1.1 GB（oracle），三份加上各工作树的同步备份是磁盘告急的来源之一（Kyo 2026-10-30，哪吒_10）。"""
    if sys.platform == 'darwin' and subprocess.run(['cp', '-cRp', str(src), str(dst)], capture_output=True).returncode == 0:
        return
    if dst.exists():
        shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
    if src.is_dir():
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)


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


# troop_event_probe 分段并行（GC，派单第十六批，总装同意）：约 900 例单进程约 45 分钟，是同步的长杆。每例都从新局起跑（run() 开头 setupNewGame、
# 随机数固定），互不依赖，所以按全局用例序号轮转分 n 段（XIYOU_PROBE_SHARD=i/n），各段一个 node 进程、各占 1 槽、各用自己的存档目录，
# 跑完按序号交错拼回 .sandbox/troop_events.json，与单进程逐字相同（测试事件探针分段.py 的拼回用例；实测对比见交付单）。
# 默认单进程（总装 11-08：实测 2 段 1047 秒比单进程 893 秒还慢，4 段没量过）；TROOP_PROBE_SHARDS=n 开 n 段并行。XIYOU_COVER=1 的覆盖记录下标是全局的，自动退回单进程。
TROOP_MERGE_JS = r'''
const fs = require('fs'), [out, ...parts] = process.argv.slice(1);
const docs = parts.map(p => JSON.parse(fs.readFileSync(p, 'utf8')));
const head = d => JSON.stringify(Object.assign({}, d, {cases: null}));
for (const d of docs) if (head(d) !== head(docs[0])) throw new Error('分段的来源或设置不一致');
const n = docs.length, total = docs.reduce((a, d) => a + d.cases.length, 0), cases = [];
// 序号 % n 轮转分段：第 i 段必有 ceil((total-i)/n) 例，多了少了都说明某段没按序号跑完
docs.forEach((d, i) => { if (d.cases.length !== Math.ceil((total - i) / n)) throw new Error('分段的用例数对不上（第 ' + i + ' 段 ' + d.cases.length + ' 例）'); });
for (let k = 0; k < total; k++) {
  const c = docs[k % n].cases[Math.floor(k / n)];
  if (!c) throw new Error('分段的用例数对不上（第 ' + k + ' 个）');
  cases.push(c);
}
fs.writeFileSync(out, JSON.stringify(Object.assign({}, docs[0], {cases}), null, 1));
console.log(JSON.stringify(cases.map(c => ({troop: c.troop, actions: c.actions.length, invokes: c.invokes.length, errors: c.errors.length, turn: c.turnCount, phase: c.phase}))));
'''


# troop 探针按用例增量（tools-probe-deps2）：用例清单在 mv_oracle/troop_event_cases.cjs，探针本体在 troop_event_probe.cjs。缓存键没命中进到这里后，
# 上次的结果用已发布的 generated/oracle/troop_events.json，它的用例键表从账（.sandbox/troop_event_keys.json，按结果文件 SHA-256 认领）取；
# 公共指纹 core ＝ 缓存键里去掉用例清单文件那份（来源、本体、helper 按影响面声明折算，一个都不能变）。core 相同时探针只跑新增或描述变了的用例，
# 取回的每 100 个抽 1 个重跑比对（TROOP_INCREMENTAL_MISMATCH 则整份重跑）。每日审计：距上次整份重跑超过 XIYOU_TROOP_AUDIT_HOURS（默认 24）小时，
# 这一次整份重跑并把「键相同的用例」逐个与上次结果比对，有不同就失败（TROOP_AUDIT_FAIL，指纹漏依赖）。XIYOU_TROOP_INCREMENTAL=0 回到整份重跑。
TROOP_KEYS = SANDBOX / 'troop_event_keys.json'
TROOP_CASES_REL = 'mv_oracle/troop_event_cases.cjs'


def troop_core(cache, cmd):
    """troop 探针的公共指纹；没有缓存对象（不用缓存的同步）返回 None，探针退回自己算本地指纹。"""
    return cache.key(cmd, exclude={TROOP_CASES_REL}, store=False) if cache else None


def troop_audit_due(doc, now=None):
    hours = float(os.environ.get('XIYOU_TROOP_AUDIT_HOURS', '24'))
    if hours <= 0:
        return False
    at = doc.get('auditedAt')
    return not isinstance(at, (int, float)) or (now if now is not None else time.time()) - at > hours * 3600


def state_audit_due(doc, now=None):
    """事件状态探针的每日审计是否到期。账上条目没有 auditedAt（本功能推出前的旧条目）不算到期，保存时从第一次见到起算。"""
    hours = float(os.environ.get('XIYOU_STATE_AUDIT_HOURS', '24'))
    if hours <= 0 or not doc or not isinstance(doc.get('auditedAt'), (int, float)):
        return False
    return (now if now is not None else time.time()) - doc['auditedAt'] > hours * 3600


# 审查 95 P2-2（O-待定·审计先于命中）：外层缓存整份命中（todo == []）和暂存命中原来都在进执行器之前，两个探针的到期审计要进了执行器才判，
# 输入一直没变时审计永远轮不到，漏依赖的旧产物会一直被放过。现在 run_probes 在用缓存／暂存之前先问一遍「审计到没到期」，
# 到期的照常进执行器（执行器再判一次、带上审计环境变量）。XIYOU_AUDIT_BEFORE_HIT=0 回到原来的「先命中、不管到期」。
def audit_before_hit_on():
    return os.environ.get('XIYOU_AUDIT_BEFORE_HIT', '1') != '0'


def audit_due_before_hit(command, now=None):
    """命中缓存前，这个探针的每日审计是否到期（只看 troop 与事件状态两个探针；账上认不出已发布结果的不算，跑了也只是整份重量、没有可比的）。"""
    import event_state_shards as ess
    name = command[0]
    gen = os.environ.get('XIYOU_GENERATED')
    if not gen or not audit_before_hit_on():
        return False
    if name == 'troop_event_probe.cjs':
        if os.environ.get('XIYOU_TROOP_INCREMENTAL', '1') == '0' or os.environ.get('XIYOU_COVER') == '1':
            return False
        prev = Path(gen) / 'oracle/troop_events.json'
        doc = ess.KeyHistory(TROOP_KEYS, 1).find(prev) if prev.is_file() else None
        return bool(doc) and troop_audit_due(doc, now)
    if name == 'event_state_probe.cjs':
        prev = Path(gen) / 'oracle/event_states.json'
        doc = ess.KeyHistory(STATE_KEYS).find(prev) if prev.is_file() else None
        return bool(doc) and state_audit_due(doc, now)
    return False


def run_troop_sharded(cmd, env, box, core=None):
    import concurrent.futures
    import event_state_shards as ess
    shards = max(1, int(os.environ.get('TROOP_PROBE_SHARDS', '1')))
    cover = env.get('XIYOU_COVER') == '1'
    incremental = os.environ.get('XIYOU_TROOP_INCREMENTAL', '1') != '0' and not cover
    env, work = dict(env), box / 'troop'
    work.mkdir(parents=True, exist_ok=True)
    history = ess.KeyHistory(TROOP_KEYS, 1)
    notes, prev_doc = [], None
    if core:
        env['XIYOU_TROOP_CORE'] = core
    prev = Path(env['XIYOU_GENERATED']) / 'oracle/troop_events.json'
    if incremental and core and prev.is_file():
        prev_doc = history.find(prev)
        if prev_doc is None:
            notes.append('账上认不出已发布的 troop_events.json，整份重跑')
        elif prev_doc.get('core') != core:
            notes.append('公共指纹变了（来源、探针本体或 helper 改了），整份重跑')
            prev_doc = None
        else:
            doc_file = work / 'prev.keys.json'
            doc_file.write_text(json.dumps(prev_doc))
            env['XIYOU_TROOP_PREV'], env['XIYOU_TROOP_PREV_KEYS'] = str(prev), str(doc_file)
            if troop_audit_due(prev_doc):
                env['XIYOU_TROOP_AUDIT'] = '1'
                notes.append('距上次整份重跑已超 %s 小时：本轮整份重跑并审计键相同的用例' % os.environ.get('XIYOU_TROOP_AUDIT_HOURS', '24'))
            else:
                notes.append('按用例增量：键对得上的用例取回上次结果')
    keys_out = work / 'troop_events.keys.json'
    if shards < 2 or cover:
        p = run_node(cmd, dict(env, XIYOU_TROOP_KEYS_OUT=str(keys_out)))
        doc_path = keys_out
    else:
        def part(i):
            sub = box / ('shard-%d' % i)
            sub.mkdir()
            for name in ['save', 'macport']:
                if (box / name).is_dir():
                    shutil.copytree(box / name, sub / name)
            e = dict(env, XIYOU_ORACLE_SANDBOX=str(sub), XIYOU_PROBE_SHARD='%d/%d' % (i, shards), XIYOU_TROOP_OUT=str(sub / 'troop_events.json'),
                     XIYOU_TROOP_KEYS_OUT=str(sub / 'troop_events.keys.json'))
            return run_node(cmd, e, weight=1)
        with concurrent.futures.ThreadPoolExecutor(shards) as pool:
            done = list(pool.map(part, range(shards)))
        text = ''.join('（第 %d 段）\n%s%s' % (i + 1, p.stdout[-300:], p.stderr) for i, p in enumerate(done))
        bad = [p for p in done if p.returncode]
        if bad:
            return subprocess.CompletedProcess(cmd, bad[0].returncode, text, '')
        m = subprocess.run(['node', '-e', TROOP_MERGE_JS, str(SANDBOX / 'troop_events.json')] +
                           [str(box / ('shard-%d' % i) / 'troop_events.json') for i in range(shards)],
                           cwd=ORACLE_DIR, capture_output=True, text=True)
        p = subprocess.CompletedProcess(cmd, m.returncode, text + '（troop_event_probe：%d 段并行）\n' % shards + m.stdout[-200:], m.stderr)
        doc_path = box / 'shard-0' / 'troop_events.keys.json'
    if p.returncode == 0:
        # 把这次的键表（探针写的，分段时取第 0 段）连结果文件摘要记进账；整份重跑（没取回任何用例）算一次审计
        try:
            doc = json.loads(Path(doc_path).read_text())
            doc['fileSha'] = ess.file_sha(SANDBOX / 'troop_events.json')
            if shards >= 2 and not cover:
                docs = [json.loads((box / ('shard-%d' % i) / 'troop_events.keys.json').read_text()) for i in range(shards)]
                doc['reused'] = sum(d.get('reused', 0) for d in docs)
            fresh = not doc.get('reused')
            doc['auditedAt'] = time.time() if fresh or not prev_doc else prev_doc.get('auditedAt')
            Path(doc_path).write_text(json.dumps(doc))
            history.add(doc_path)
            notes.append('用例 %d 个，取回 %d 个，抽查 %d 个' % (len(doc.get('keys') or []), doc.get('reused', 0), doc.get('checked', 0)))
        except (OSError, ValueError, KeyError) as error:
            notes.append('键表没记进账（%s）' % str(error)[:80])
    return subprocess.CompletedProcess(p.args, p.returncode, '（troop 探针：%s）\n' % '；'.join(notes) + (p.stdout or ''), p.stderr or '')


# event_state_probe（1 万多个有状态变体）原来在同步里单进程整份重量：开跑前删了 .sandbox 里的上次产物，探针自带的增量从没生效，
# 整轮两小时以上，是同步的长杆（tools81）。现在同 补跑事件状态探针.py：按变体序号分 XIYOU_STATE_SHARDS 段（默认 4）并行，
# 每段各占 1 槽；上次的结果用已发布的 generated/oracle/event_states.json，摘要从摘要账（.sandbox/event_state_keys.json，
# 按结果文件 SHA-256 认领）取，摘要按「冻结源除地图外的部分＋本例读到的地图」算，换源只改了几张地图时只重跑那几张图上的变体。
STATE_KEYS = SANDBOX / 'event_state_keys.json'
# 合并时车道产物不能整份克隆（--from-worktree 退出码 3）而改跑完整同步时，合并车道.py 传 --state-prev-from <车道工作树>：
# 车道已跑完的 event_states.json（车道账上认得的那份）也当「上次结果」交给探针，与 main 自己的上次结果按用例号拼成一份
# （两边都有的用例按摘要和预设条目挑，见 combine_prev）。取不取回仍由探针逐例按摘要（含探针代码、来源、预设、读到的地图）判断、再抽 1% 重跑自检，
# 所以只会省时间、不会把对不上的结果带进来。11-09 seg-a3 合并：车道改了探针，main 的上次结果整份作废，两次各 90 分钟整份重量，
# 车道树里同一份代码的结果却就在那儿（tools-merge-probe）。XIYOU_STATE_PREV_FROM=0 回到只用 main 自己的上次结果。
STATE_PREV_FROM = None


def lane_state_prev(worktree, gen):
    """车道工作树里账上认得的事件状态结果：(结果文件, 摘要文档)；没有或拿不准返回 None。"""
    import event_state_shards as ess
    try:
        lane_gen = Path(worktree) / Path(gen).resolve().relative_to(ROOT.resolve())
        lane_keys = Path(worktree) / (SANDBOX / 'event_state_keys.json').resolve().relative_to(ROOT.resolve())
    except ValueError:
        return None
    result = lane_gen / 'oracle/event_states.json'
    if not result.is_file() or result.resolve() == (Path(gen) / 'oracle/event_states.json').resolve():
        return None
    doc = ess.KeyHistory(lane_keys).find(result)
    return (result, doc) if doc else None


def preset_entries(path):
    """event_presets.json 里每个变体（基础用例#标签）的预设条目，序列化成可比较的字符串；读不了就是空表。"""
    try:
        cases = json.loads(Path(path).read_text()).get('cases') or []
    except (OSError, ValueError, AttributeError):
        return {}
    return {'%s#%s' % (p.get('base'), p.get('tag')): json.dumps(p, sort_keys=True) for p in cases if isinstance(p, dict)}


def combine_prev(work, lane, main_prev, lane_presets=None, merged_presets=None):
    """车道结果与 main 上次结果拼成一份上次结果和摘要，写在 work 下；返回 (结果, 摘要, 车道条数, main 条数)。
    只有一边有的用例照收；两边都有时（审查 72 P3-1：原来一律取车道的，main 那份对得上也被丢，白多跑）：
    摘要相同的任取一份（取 main 已有的）；摘要不同时，探针只认「和合并后现状对得上」的那份，拼的一方看不到现状，只能推断——
    两边探针公共指纹（coreFingerprint）不同，说明车道改了探针／来源，合并后现状随车道，取车道的；
    公共指纹相同时，看这个变体的预设条目：车道树里的条目和合并后一致（车道改的或没人改），取车道的；
    不一致（合并前 main 又改了它），取 main 的。推断错了也只是多跑，取不取回仍由探针逐例按摘要决定。
    lane_presets／merged_presets 是两处 event_presets.json 的路径，不给就退回「车道优先」。"""
    import event_state_shards as ess
    lane_file, lane_doc = lane
    data = json.loads(Path(lane_file).read_text())
    lane_cases = list(data.get('cases') or [])
    lane_keys, lane_maps = dict(lane_doc.get('keys') or {}), dict(lane_doc.get('maps') or {})
    cases, keys, maps = [], {}, {}
    for c in lane_cases:
        cases.append(c)
        keys[c.get('id')], maps[c.get('id')] = lane_keys.get(c.get('id')), lane_maps.get(c.get('id'))
    index = {c.get('id'): i for i, c in enumerate(cases)}
    from_main = 0
    if main_prev:
        main_file, main_keys = main_prev
        try:
            other, other_doc = json.loads(Path(main_file).read_text()), json.loads(Path(main_keys).read_text())
        except (OSError, ValueError):
            other = other_doc = None
        # 开局设定不同的那份探针整份不认，拼进来也没用
        if other and other_doc and json.dumps(other.get('setup'), sort_keys=True) == json.dumps(data.get('setup'), sort_keys=True):
            same_core = other_doc.get('coreFingerprint') == lane_doc.get('coreFingerprint')
            lane_p = preset_entries(lane_presets) if same_core and lane_presets and merged_presets else {}
            merged_p = preset_entries(merged_presets) if lane_p else {}
            for c in other.get('cases') or []:
                cid = c.get('id')
                if cid not in (other_doc.get('keys') or {}) or cid not in (other_doc.get('maps') or {}):
                    continue
                if cid in index:
                    if keys.get(cid) == other_doc['keys'][cid]:
                        take_main = True          # 摘要一样：结果等价，用 main 已有的
                    elif not same_core or not lane_p:
                        take_main = False
                    else:
                        take_main = lane_p.get(cid) != merged_p.get(cid)   # 合并前 main 又改了这个预设
                    if not take_main:
                        continue
                    cases[index[cid]] = c
                else:
                    index[cid] = len(cases)
                    cases.append(c)
                    from_main += 1
                keys[cid], maps[cid] = other_doc['keys'][cid], other_doc['maps'][cid]
    out, out_keys = Path(work) / 'prev-combined.json', Path(work) / 'prev-combined.keys.json'
    out.write_text(json.dumps(dict(data, cases=cases)))
    out_keys.write_text(json.dumps({'version': 2, 'coreFingerprint': lane_doc.get('coreFingerprint'),
                                    'keys': keys, 'maps': maps, 'fileSha': ess.file_sha(out)}))
    return out, out_keys, len(cases) - from_main, from_main


def run_state_sharded(cmd, env, box):
    import event_state_shards as ess
    shards = max(1, int(os.environ.get('XIYOU_STATE_SHARDS', '4')))
    env, work = dict(env), box / 'state'
    work.mkdir(parents=True, exist_ok=True)
    history = ess.KeyHistory(STATE_KEYS)
    incremental = ess.prepare_prev(env, history, Path(env['XIYOU_GENERATED']) / 'oracle/event_states.json', work)
    note_lane = ''
    if STATE_PREV_FROM and os.environ.get('XIYOU_STATE_PREV_FROM', '1') != '0':
        lane = lane_state_prev(STATE_PREV_FROM, env['XIYOU_GENERATED'])
        if lane is None:
            note_lane = '车道 %s 没有账上认得的事件状态结果，不用；' % STATE_PREV_FROM
        else:
            try:
                prev, prev_keys, n_lane, n_main = combine_prev(
                    work, lane, (env['XIYOU_STATE_PREV'], env['XIYOU_STATE_PREV_KEYS']) if incremental else None,
                    Path(STATE_PREV_FROM) / PRESETS_REL, ROOT / PRESETS_REL)
                env['XIYOU_STATE_PREV'], env['XIYOU_STATE_PREV_KEYS'] = str(prev), str(prev_keys)
                incremental = True
                note_lane = '上次结果并入车道 %s 的（车道 %d 例、main 补 %d 例）；' % (STATE_PREV_FROM, n_lane, n_main)
            except (OSError, ValueError, KeyError, TypeError) as error:
                note_lane = '车道事件状态结果读取失败（%s），不用；' % str(error)[:80]
    # 每日审计（tools-probe-deps2）：距上次整份重跑超过 XIYOU_STATE_AUDIT_HOURS（默认 24，0＝不审计）小时，本轮整份重跑，并把指纹相同的变体
    # 逐个与上次结果比对，有不同就失败（STATE_AUDIT_FAIL）。账上旧条目没有 auditedAt 的从第一次见到起算（不为推出这个功能白跑一轮 90 分钟）。
    prev_doc = history.find(Path(env['XIYOU_GENERATED']) / 'oracle/event_states.json') if incremental else None
    audited = prev_doc.get('auditedAt') if prev_doc else None
    audit_note = ''
    if incremental and state_audit_due(prev_doc):
        env['XIYOU_STATE_AUDIT'] = '1'
        audit_note = '距上次整份重跑已超 %s 小时：本轮整份重跑并审计指纹相同的变体；' % os.environ.get('XIYOU_STATE_AUDIT_HOURS', '24')
    keys = work / 'event_states.keys.json'
    p = ess.run_sharded(env, ORACLE_DIR, work, SANDBOX / 'event_states.json', keys, shards,
                        lambda e, label: run_node(cmd, e, weight=1))
    if p.returncode == 0 and keys.is_file():
        try:   # 整份重跑（没取回任何变体）算一次审计；取回过的沿用上次的时刻，账上没有的从现在起算
            doc = json.loads(keys.read_text())
            doc['auditedAt'] = time.time() if not doc.get('reused') else (audited or time.time())
            keys.write_text(json.dumps(doc))
        except (OSError, ValueError):
            pass
        history.add(keys)
    note = '（事件状态探针：%d 段；%s%s%s）\n' % (shards, audit_note, note_lane, '上次结果的摘要在账上，按摘要取回没变的变体' if incremental
                                            else '账上没有上次结果的摘要，整份重量')
    return subprocess.CompletedProcess(p.args, p.returncode, note + (p.stdout or ''), p.stderr or '')


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


# 同步内的占槽次序（tools-probe-deps ③，XIYOU_SYNC_SLOT_ORDER=0 退回各线程各抢）：本同步里同时等槽的探针在进程内排队，
# 一次只让排第一的去抢共用槽。次序：① 已有一段占到过槽的探针的其余段（事件状态探针、event_probe 分段）先走，
# 免得 3 段跑完、最后一段排在一个刚起的长探针后面再等两小时（11-09：smart_ai 占槽 2.5 小时，事件状态探针一段被饿到 230 分钟以上）；
# ② 再按估计耗时从长到短（上次同步记下的 .sandbox/probe_durations.json，没有记录按 SLOW_PROBES 的先后），长的先起、收尾短；③ 先来先得。
# 不抢别人已占着的槽，也不改跨工作树的排队（总装优先等照旧）。
SLOW_PROBES = ['slice_probe.cjs', 'smart_ai_probe.cjs', 'event_probe.cjs', 'troop_event_probe.cjs', 'event_state_probe.cjs',
               'zhenqi_probe.cjs', 'dungeon_probe.cjs', 'sequence_probe.cjs']
DURATIONS_NAME = 'probe_durations.json'  # 在 SANDBOX 下
_slot_cv = threading.Condition()
_slot_wait = {}
_slot_holder = []  # 正在抢共用槽的那一个（最多一个）
_slot_started = set()
_slot_seq = itertools.count()


def slot_order_on():
    return os.environ.get('XIYOU_SYNC_SLOT_ORDER', '1') != '0'


def load_durations():
    try:
        data = json.loads((SANDBOX / DURATIONS_NAME).read_text())
        return {k: float(v) for k, v in data.items() if isinstance(v, (int, float))} if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


_durations = None


def probe_estimate(group):
    global _durations
    if _durations is None:
        _durations = load_durations()
    if group in _durations:
        return _durations[group]
    return 60.0 * (len(SLOW_PROBES) - SLOW_PROBES.index(group)) if group in SLOW_PROBES else 0.0


def note_duration(group, seconds):
    """记下探针耗时供下次排序：取本次与旧值的八成中较大的（只跑几个单元的增量轮不会把估计一下拉低）。"""
    global _durations
    if _durations is None:
        _durations = load_durations()
    _durations[group] = round(max(float(seconds), 0.8 * _durations.get(group, 0.0)), 1)


def save_durations():
    if _durations is not None:
        with contextlib.suppress(OSError):
            atomic_json(SANDBOX / DURATIONS_NAME, _durations)


def slot_rank(group, seq):
    return (0 if group in _slot_started else 1, -probe_estimate(group), seq)


@contextlib.contextmanager
def local_turn(group):
    """进程内轮到自己才去抢共用槽；占到后（或抢槽出错）把机会交给下一个。"""
    if not slot_order_on():
        yield
        return
    token = object()
    with _slot_cv:
        _slot_wait[token] = (group, next(_slot_seq))
        while _slot_holder or min(_slot_wait, key=lambda k: slot_rank(*_slot_wait[k])) is not token:
            _slot_cv.wait(5)
        _slot_holder.append(token)
    try:
        yield
    finally:
        with _slot_cv:
            _slot_wait.pop(token, None)
            if token in _slot_holder:
                _slot_holder.remove(token)
            if group:
                _slot_started.add(group)
            _slot_cv.notify_all()


@contextlib.contextmanager
def heavy_slot(label, weight=1, group=None):
    """占共用槽再跑重进程（node 探针、Godot 导入）。排队时每 60 秒打一行「等槽」到标准输出：
    长任务.py 的看门狗按输出判断有没有进展，排队不再被误判卡死（XIYOU_SLOT_HEARTBEAT 调间隔）。"""
    r = runner()

    def waiting(seconds):
        print('等槽：%s 已等 %d 秒（占 %d 槽，共用上限 %d）' % (label, seconds, min(weight, r.global_limit()), r.global_limit()),
              flush=True)
    with contextlib.ExitStack() as stack:
        with local_turn(group):
            stack.enter_context(r.global_slot(r.state_dir(str(ROOT)), r.global_limit(), weight, waiting,
                                              float(os.environ.get('XIYOU_SLOT_HEARTBEAT', '60')), priority=r.slot_priority(str(ROOT))))
        yield


def run_node(cmd, env, weight=None):
    """跑一个 node 探针：先在 并行测试.py 的跨工作树共用槽（CHECK_GLOBAL_JOBS，状态目录同测试）占位再跑，
    几条车道同时同步、跑测试时合起来不超上限（唐僧 2026-10-21：两条车道同步加测试曾把 8 核负载冲到 21）。
    吃内存的探针按 PROBE_WEIGHTS 多占几槽。SYNC_JOBS 只决定本次同步最多同时排几个探针。"""
    with heavy_slot(' '.join(cmd), probe_weight(cmd[0]) if weight is None else weight, group=Path(cmd[0]).name):
        # event_probe 在一个进程里连跑全部事件页，内存随事件数涨；切片事件过千页后撞 node 默认 4GB 堆上限（悟空_55 簇 8／13 同步 OOM），放宽到 10GB
        # 环境里已有 NODE_OPTIONS（如云端容器的 --use-openssl-ca）时 setdefault 不生效、仍是默认堆，event_probe 会 OOM：没写堆上限就追加
        env = dict(env)
        if '--max-old-space-size' not in env.get('NODE_OPTIONS', ''):
            env['NODE_OPTIONS'] = (env.get('NODE_OPTIONS', '') + ' --max-old-space-size=10240').strip()
        return subprocess.run(['node'] + cmd, cwd=ORACLE_DIR, env=with_dep_recorder(env, cmd), capture_output=True, text=True)


def with_dep_recorder(env, cmd):
    """给探针进程预加载运行时依赖记录（probe_dep_recorder.cjs，tools-probe-deps；XIYOU_PROBE_HELPER_DEPS=0 不加）。"""
    if os.environ.get('XIYOU_PROBE_HELPER_DEPS', '1') == '0' or not cmd or not str(cmd[0]).endswith('.cjs'):
        return env
    recorder = (HERE / 'probe_dep_recorder.cjs').resolve()
    if not recorder.is_file():
        return env
    env = dict(env)
    env['NODE_OPTIONS'] = (env.get('NODE_OPTIONS', '') + ' --require "%s"' % recorder).strip()
    env['XIYOU_PROBE_DEPS_NAME'] = Path(cmd[0]).name
    env['XIYOU_PROBE_DEPS_ROOT'] = str(Path(ORACLE_DIR).resolve())
    return env


def run(cmd, cwd, log):
    log.write('$ ' + ' '.join(cmd) + '\n')
    log.flush()
    p = subprocess.run(cmd, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        raise RuntimeError('命令失败（%d）：%s' % (p.returncode, ' '.join(cmd)))


def stash_dir():
    return SANDBOX / 'probe-stash'


def file_sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_stash():
    """探针暂存（tools79）：某轮有探针失败时，同轮已成功、产物核验通过的探针把产物与缓存键存在 .sandbox/probe-stash/，
    下一轮键没变就不重跑、直接拿暂存产物走核验与发布；generated 照旧不动、增量缓存照旧不发布（失败时不把半轮当新结果）。"""
    try:
        data = json.loads((stash_dir() / 'index.json').read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_stash(index):
    d = stash_dir()
    d.mkdir(parents=True, exist_ok=True)
    (d / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=1))


def stash_usable(entry, command, outputs, key):
    if not entry or entry.get('key') != key or entry.get('command') != command or entry.get('outputs') != outputs:
        return False
    try:
        return all(file_sha(stash_dir() / rel) == entry['sha'][rel] for rel in outputs)
    except (OSError, KeyError, TypeError):
        return False


def output_acceptable(rel):
    """与发布前的核验同口径：产物在、能读、没有新增或变化的错误。"""
    output = SANDBOX / rel
    if not output.is_file():
        return False
    try:
        data = json.loads(output.read_text())
    except ValueError:
        return False
    if has_error(data):
        previous = Path(os.environ['XIYOU_GENERATED']) / 'oracle' / Path(rel).name
        return previous.is_file() and retained_errors_unchanged(previous.name, json.loads(previous.read_text()), data)
    return True


def run_probes(log, cache=None):
    """互不依赖的探针并行跑（AGENTS.md「省额度约定」同步提速）。每个探针一个独立存档目录
    .sandbox/run/<探针>（开跑前复制 .sandbox 现有的 save／macport，各探针看到同样的起始状态），
    产物照旧写 .sandbox/*.json；日志按 PROBES 顺序写回，并记每个探针的耗时。SYNC_JOBS=1 退回串行。
    每个探针运行时另占跨工作树共用槽（run_node），排队等槽的时间算在该探针耗时里。"""
    global _durations
    _durations = None  # 按本次的 SANDBOX 重读耗时估计
    import concurrent.futures
    import time
    jobs = max(1, int(os.environ.get('SYNC_JOBS', '4')))
    plan, reused, keys, units, partial, misses, audit_due = [], [], {}, {}, {}, {}, []
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
        if todo == [] and audit_due_before_hit(command):
            audit_due.append(command[0])
            todo = None
            log.write('AUDIT_DUE %s（输入没变、整份命中，但每日审计已到期：不用缓存和暂存，进执行器整份重跑并审计）\n' % command[0])
            if cache:
                cache.misses.setdefault(command[0], []).append({'kind': 'audit-due'})
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
    stash = load_stash() if cache and not cache.force else {}
    stashed = {command[0] for command, outputs in plan
               if command[0] not in partial and command[0] not in audit_due and stash_usable(stash.get(command[0]), command, outputs, keys[command[0]])}
    for name in sorted(stashed):
        log.write('STASH_HIT ' + name + '（上轮别的探针失败时已成功，输入没变，用暂存产物）\n')
    log.flush()
    print('PROBE_PLAN=' + json.dumps({'executed': len(plan) - len(partial) - len(stashed), 'partial': {k: len(v) for k, v in partial.items()},
                                      'reused': len(reused), 'stashed': len(stashed), 'auditDue': audit_due}), flush=True)
    if not plan:
        return {'executed': [], 'partial': {}, 'reused': reused, 'stashed': [], 'seconds': {}, 'missReasons': misses, 'auditDue': audit_due}
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
    for command, outputs in plan:
        if command[0] in stashed:
            for rel in outputs:
                (SANDBOX / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(stash_dir() / rel, SANDBOX / rel)

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
        node = ((lambda c, e, only=None: run_event_sharded(c, e, box, only)) if event else
                (lambda c, e, only=None: run_state_sharded(c, e, box)) if cmd[0] == 'event_state_probe.cjs' else
                (lambda c, e, only=None: run_troop_sharded(c, e, box, troop_core(cache, c))) if cmd[0] == 'troop_event_probe.cjs' else
                (lambda c, e, only=None: run_node(c, e)))
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
            # 只合并不跑探针时（新工作树首次同步）.sandbox/slice/ 等子目录可能还没有，合并脚本写入会 ENOENT（哪吒_8）
            (SANDBOX / rel).parent.mkdir(parents=True, exist_ok=True)
            spec['files'].append({'old': str(previous / rel), 'fresh': str(fresh) if part else None, 'out': str(SANDBOX / rel),
                                  'indent': None if cmd[0] == 'event_probe.cjs' else 1})
        (box / 'merge.json').write_text(json.dumps(spec, ensure_ascii=False))
        p = subprocess.run(['node', str(HERE / 'oracle_shard_merge.cjs'), str(box / 'merge.json')], capture_output=True, text=True)
        text += '（增量：只跑 %d 个单元，其余取上次产物合并）\n' % len(part) + p.stdout + p.stderr
        return cmd, p.returncode, text, time.time() - t

    work = []
    for cmd, outputs in plan:
        if cmd[0] in stashed:
            continue
        if cmd[0] == 'slice_probe.cjs' and cmd[1:] == [str(d) for d in range(1, 7)]:
            expected = ['slice/slice_d%d.json' % d for d in range(1, 7)]
            if outputs != expected:
                raise RuntimeError('切片难度分命令的产物声明不匹配')
            work.extend((cmd[0], [cmd[0], str(d)], [expected[d - 1]]) for d in range(1, 7))
        else:
            work.append((cmd[0], cmd, outputs))
    slow = SLOW_PROBES
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
                if results[i][1] == 0:
                    note_duration(results[i][0][0], results[i][3])
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
    save_durations()
    failed = []
    for cmd, code, out, sec in results:
        log.write('$ node %s（%.0f 秒）\n' % (' '.join(cmd), sec))
        log.write(out)
        if code != 0:
            failed.append(' '.join(cmd))
    log.flush()
    if failed:
        # 同轮已成功的整探针（分片增量的不算）存进暂存，下一轮输入没变就不用重跑（tools79）
        bad = {cmd[0] for cmd, code, _, _ in results if code != 0}
        index = load_stash()
        kept = []
        for command, outputs in plan:
            name = command[0]
            if name in bad or name in partial or not keys.get(name) or not all(output_acceptable(rel) for rel in outputs):
                index.pop(name, None)
                continue
            for rel in outputs:
                (stash_dir() / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(SANDBOX / rel, stash_dir() / rel)
            index[name] = {'key': keys[name], 'command': command, 'outputs': outputs, 'sha': {rel: file_sha(stash_dir() / rel) for rel in outputs}}
            kept.append(name)
        save_stash(index)
        if kept:
            log.write('STASH_SAVED ' + ' '.join(kept) + '\n')
            print('PROBE_STASHED=' + json.dumps(kept), flush=True)
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
    index = load_stash()
    if any(command[0] in index for command, _ in plan):   # 已发布进 generated、记进缓存：暂存用不着了
        for command, outputs in plan:
            if index.pop(command[0], None):
                for rel in outputs:
                    (stash_dir() / rel).unlink(missing_ok=True)
        save_stash(index)
    gaps = getattr(cache, 'read_gaps', None) if cache else None
    if gaps:
        line = 'PROBE_READ_UNREGISTERED ' + json.dumps(gaps, ensure_ascii=False)
        log.write(line + '\n')
        print(line, flush=True)
    return {'executed': [cmd[0] for cmd, _ in plan if cmd[0] not in partial and cmd[0] not in stashed], 'readGaps': gaps or {},
            'partial': {k: v for k, v in partial.items()}, 'reused': reused, 'stashed': sorted(stashed),
            'missReasons': misses, 'auditDue': audit_due,
            # 多命令探针的合计为子进程用时之和；墙钟由同步报告 start/end 记录。
            'seconds': {name: round(sum(r[3] for r in results if r[0][0] == name), 3) for name, _, _ in work},
            'commands': [{'command': cmd, 'seconds': round(sec, 3), 'exitCode': code} for cmd, code, _, sec in results]}


def build_parser() -> argparse.ArgumentParser:
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
    ap.add_argument('--accept-source-switch', metavar='版本',
                    help='换源：允许正式版本从基线换到这个版本（如 v0.62.12），仍须接受单逐条接受全部测量变化；没有稳定键的整字段列表改变也只在这时可接受')
    ap.add_argument('--from-worktree', type=Path, help='合并时用车道已同步的产物（按指纹核对），不满足条件退出码 3')
    ap.add_argument('--state-prev-from', type=Path, metavar='车道工作树',
                    help='完整同步时把车道已跑完的事件状态探针结果也当上次结果（探针逐例按摘要取回）；合并车道.py 在 --from-worktree 退出码 3 后传')
    ap.add_argument('--full', '--full-probes', dest='full', action='store_true', help='忽略探针缓存，强制全量转换与全部探针（--full-probes 同义）')
    ap.add_argument('--no-import', action='store_true', help='结束时不跑 godot --import')
    return ap


def _main() -> int:
    ap = build_parser()
    a = ap.parse_args()
    try:
        withdraw = {int(re.sub(r'^(?i:map)', '', str(m))) for m in a.accept_withdrawal}
    except ValueError:
        ap.error('--accept-withdrawal 写地图号，如 41 或 Map041')
    if a.full and a.from_worktree:
        ap.error('--full 与 --from-worktree 不能一起使用')
    global STATE_PREV_FROM
    STATE_PREV_FROM = a.state_prev_from.resolve() if a.state_prev_from and not a.full else None
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
    baseline = comparison_baseline(gen, main_generated(gen) if a.no_register else None)
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
        if src.exists():
            clone_or_copy(src, backup / name)
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
            if stamp.get('presetsMerge'):
                # 只差预设行：event_states.json 用方案阶段在临时文件里拼好的那份（克隆前已核对）；其余产物与车道指纹一致
                shutil.copyfile(stamp['presetsMerge']['merged'], gen / 'oracle/event_states.json')
                log.write('只差预设行：event_states.json 由车道结果与 main 现有结果按预设顺序拼成\n')
            elif outputs_digest(gen) != stamp.get('outputsDigest'):
                raise RuntimeError('克隆后的产物与车道指纹不一致')
            report['fromWorktree'] = str(a.from_worktree)
            # 车道跑探针时记下的运行时依赖（.sandbox/probe_deps/）：本工作区缺的补上，已有的不动（tools-probe-deps）
            try:
                lane_sandbox = a.from_worktree.resolve() / SANDBOX.resolve().relative_to(ROOT.resolve())
            except ValueError:
                lane_sandbox = None  # 参照目录不在仓库里（测试夹具）：不补
            deps = carry_probe_deps(lane_sandbox, SANDBOX) if lane_sandbox else []
            if deps:
                report['fromWorktreeProbeDeps'] = deps
                log.write('从车道补来探针依赖记录：%s\n' % '、'.join(deps))
            # 车道的 troop 用例键账与事件状态摘要账：克隆来的结果文件在本工作区账上也要认得（按文件摘要认领，并进来不会冒充），
            # 否则合并后下一次探针改动在 main 上整份重跑（tools-probe-deps2）
            if lane_sandbox:
                import event_state_shards as ess
                got = {name: ess.KeyHistory(SANDBOX / name, version).absorb(lane_sandbox / name)
                       for name, version in (('troop_event_keys.json', 1), ('event_state_keys.json', 2)) if (lane_sandbox / name).is_file()}
                got = {k: v for k, v in got.items() if v}
                if got:
                    report['fromWorktreeKeyBooks'] = got
                    log.write('从车道并入摘要账：%s\n' % json.dumps(got, ensure_ascii=False))
            if stamp.get('pendingAcceptance'):
                report['fromWorktreePending'] = True
                log.write('车道同步只差测量接受（待接受指纹）：产物照用，测量照样按本工作区基线比较\n')
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
            unattributed = []
            report['withdrawal']['removed'] = {k: {'count': len(v), 'keys': v[:50]}
                                               for k, v in withdraw_baseline(old_oracle, gen / 'oracle', trimmed,
                                                                             dropped_slice(old_manifest, new_manifest), unattributed).items()}
            if unattributed:
                withdrawn_ok = False
                report['withdrawal']['problem'] = ('新参照还缺了 %d 条与撤出的切片内容无关（或认不出归属）的条目，不一并接受：%s'
                                                   % (len(unattributed), '；'.join(unattributed[:10])))
                report['withdrawal']['unattributed'] = unattributed[:50]
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
        d = diff_paths(strip(json.loads(old.read_text())), strip(json.loads(f.read_text())), name=f.name)
        if d:
            measure[f.name] = d
    report['measurementChanges'] = measure
    report['additionCheck'] = compare_directories(old_oracle, gen / 'oracle', probe_outputs())
    report['sameExistingSource'] = withdrawn_ok and (withdrawn_source_preserved(old_manifest, new_manifest, withdraw) if withdraw
                                                     else source_preserved(old_manifest, new_manifest))
    # 换源（BM 11-06）：显式给出新版本号、且本轮确实从别的版本换到它时，不要求旧输入原样存在；测量变化照旧逐条接受
    switch = bool(a.accept_source_switch and not withdraw and new_version == a.accept_source_switch
                  and old_version != new_version)
    if a.accept_source_switch:
        report['sourceSwitch'] = {'from': old_version, 'to': new_version, 'requested': a.accept_source_switch, 'allowed': switch}
        if not switch:
            print('--accept-source-switch %s 不生效：本轮 %s → %s' % (a.accept_source_switch, old_version, new_version), flush=True)
    if switch:
        report['sameExistingSource'] = True
    v = subprocess.run([sys.executable, str(HERE / '验证西游来源.py'), '--app', str(app), '--generated', str(gen)], capture_output=True, text=True)
    report['verify'] = (v.stdout.strip().splitlines() or [''])[-1]
    report['verifyOk'] = v.returncode == 0
    check = report['additionCheck']
    report['changeCandidates'] = change_candidates(check)
    def current(entry):
        f = gen / 'oracle' / entry['file']
        try:
            return current_digest(entry['file'], json.loads(f.read_text()), entry['collection'], entry['key'])
        except (OSError, ValueError):
            return None
    resolved = apply_acceptances(check, acceptances, current, source_switch=switch)
    if acceptances:
        report['acceptChanges'] = {'sources': acceptance_sources, 'accepted': resolved['accepted'], 'unused': resolved['unused'],
                                   'alreadyInBaseline': resolved['alreadyInBaseline'], 'remainingProblems': resolved['problems']}
        for row in resolved['alreadyInBaseline']:
            print('提示：接受单条目 %s %s %s 本轮没有对应变化，现值已是它要接受的值（基线早已接受），跳过不拒收'
                  % (row['file'], row['collection'], row['key'][:80]), flush=True)
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
    # 只差测量接受：来源核验、导入、缓存发布都成功，产物是按这组输入如实测出的，照样可供 main 复用（main 重新比较、要接受单）
    pending = (not usable and reuse_pending_stamp() and not report.get('cacheError') and not report.get('importError')
               and report['verifyOk'])
    if (usable or pending) and lane is None:
        write_stamp(gen, report, pending=pending)
        if pending:
            print('已写待接受指纹：总装合并可直接用本树产物，main 仍按自己的基线比较、照样要接受单', flush=True)
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
    # 先解析参数：--help 和参数写错直接在这里退出，不经长任务包装、不先打印 TASK_LOG 路径（哪吒_10）
    build_parser().parse_args()
    if os.environ.get('XIYOU_LONG_TASK_MANAGED') != '1':
        wrapper = ROOT / '03_再刷重制_Godot/07_开发环境/长任务.py'
        task_log = os.environ.get('XIYOU_TASK_LOG') or str(ROOT / '03_再刷重制_Godot/04_验证/本地结果/任务' /
                    ('sync-' + dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f') + '.log'))
        os.execv(sys.executable, [sys.executable, str(wrapper), 'run', task_log, '--', sys.executable, __file__, *sys.argv[1:]])
    sys.exit(main())
