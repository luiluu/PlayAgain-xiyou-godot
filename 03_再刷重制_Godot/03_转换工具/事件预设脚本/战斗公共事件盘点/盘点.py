#!/usr/bin/env python3
"""战斗专用公共事件盘点（cc 盘点车道 cc/battle-ce-inventory，2026-11-11；只读，不改游戏数据与代码）。

用法：
  盘点.py [--generated 目录] [--run run.json] [--out-dir 目录]
    --generated  转换产物（默认本工作树 01_Godot工程/modes/xiyou/generated）
    --run        battle_ce_run.gd 的实跑结果（缺省时自动经 占槽.py 跑一次 Godot，写到 out-dir/run.json）
    --out-dir    产物目录（默认 04_验证/战斗公共事件盘点/）：盘点表.json、盘点表.csv、盘点表.md、run.json

口径
- 名单：同 ../bonly.py（调用方全是 occasion＝战斗的技能／物品效果 44、敌群页 117、或只在战斗里跑的公共事件 117）。
- 调用方可达（原版）：
  技能：可用角色（manifest 切片 actors＋eventActors＋事件 129 入队）的职业 learnings（不限等级）、特性 43（角色／职业／武器／防具／状态），
        可达敌群里敌人的 actions，事件 318 学会、339 强制行动，物品效果 43，备注 <ShareLearnSkill/ShareSkill/Replace Attack:N>、
        敌人 <PetPushSkill> 段（a-b 范围）、<ULevelS> 段（LvX:技能:几率），脚本里的 learnSkill(N)／setSkill(N)／forceSkill／$dataSkills[N]，
        已可达技能备注里的 setSkill／forceAction／FORCE ACTION（不动点）。
  敌群：manifest 切片 troops、任一地图 encounterList、任一事件 301 指定敌群、脚本 setup(N)；
  物品：事件 126 给、商店 302/605、可达敌人掉落（dropItems 与 <Enemy Drops>）、脚本 gainItem($dataItems[N])、备注 kms_shop_stock 存在（商店）。
  公共事件：调用它的战斗专用公共事件本身可达（不动点）。
- 归类（每个事件一类，不留「未定」）：
  原版无效    调用方全都不可达，或事件体没有有效指令（只有注释／空行）
  没翻译      到得了，且 Godot 实跑（整跑＋逐条单跑）有跳过的指令
  重制已覆盖  到得了、没跳过，且有专项证据：测试／参照夹具／探针里点名这个事件、调用它的技能，或调用它的敌群在 troop_event_cases 里
  到得了未覆盖 到得了、没跳过，但只有 xiyou_battle_common_events 的 _inventory 通跑（只统计跳过、不比原版）或连通跑也没有（敌群／子事件调用）
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GODOT_ROOT = HERE.parents[2]           # 03_再刷重制_Godot
REPO = GODOT_ROOT.parent
PROJ = GODOT_ROOT / '01_Godot工程'
DEFAULT_GEN = PROJ / 'modes/xiyou/generated'
DEFAULT_OUT = GODOT_ROOT / '04_验证/战斗公共事件盘点'

REF = re.compile(r'(?:reserveCommonEvent|CommonEvent|commonEvent)\D{0,4}(\d+)')
SCRIPT_CODES = (355, 655, 356, 108, 408)
PLUGIN_SKILL_KEYS = re.compile(r'^(?:AdvancedSkiId|AddSkills|LeadSkiId|JiBanSkiId)$')


def load(gen, name):
    return json.load(open(gen / f'db/{name}.json'))


def iter_lists(gen):
    """(来源, 指令列表)：地图事件页、敌群页、公共事件"""
    for f in sorted((gen / 'maps').glob('Map*.json')):
        d = json.load(open(f))
        for ev in d.get('events') or []:
            if ev:
                for i, p in enumerate(ev['pages']):
                    yield ('map', f'{f.stem} EV{ev["id"]} p{i + 1}'), p['list']
    for t in load(gen, 'Troops'):
        if t:
            for i, p in enumerate(t['pages']):
                yield ('troop', t['id'], i + 1), p['list']
    for c in load(gen, 'CommonEvents'):
        if c:
            yield ('ce', c['id']), c['list']


def script_text(lst):
    out = []
    for c in lst or []:
        if c['code'] in (355, 655):
            out.append(str(c['parameters'][0]))
        if c['code'] in (111,) and c['parameters'][0] == 12:
            out.append(str(c['parameters'][1]))
        if c['code'] == 122 and len(c['parameters']) > 4 and c['parameters'][3] == 4:
            out.append(str(c['parameters'][4]))
    return '\n'.join(out)


class Data:
    def __init__(self, gen):
        self.gen = gen
        self.ce = load(gen, 'CommonEvents')
        self.skills = load(gen, 'Skills')
        self.items = load(gen, 'Items')
        self.weapons = load(gen, 'Weapons')
        self.armors = load(gen, 'Armors')
        self.states = load(gen, 'States')
        self.actors = load(gen, 'Actors')
        self.classes = load(gen, 'Classes')
        self.enemies = load(gen, 'Enemies')
        self.troops = load(gen, 'Troops')
        self.manifest = json.load(open(gen / 'manifest.json'))
        self.plugins = load(gen, 'Plugins')
        self.lists = list(iter_lists(gen))

    def name(self, table, i):
        t = getattr(self, table)
        return (t[i] or {}).get('name', '') if 0 < i < len(t) else ''


# ---------- 战斗专用名单与调用方（同 bonly.py，另记调用方明细） ----------
def battle_only(d):
    callers = defaultdict(set)
    detail = defaultdict(list)

    def scan(lst, who, det):
        for c in lst or []:
            if c['code'] == 117:
                callers[c['parameters'][0]].add(who)
                detail[c['parameters'][0]].append(det)
            if c['code'] in SCRIPT_CODES:
                for m in REF.finditer(str(c['parameters'][0])):
                    callers[int(m.group(1))].add(who)
                    detail[int(m.group(1))].append(det + ('脚本',))

    for tab, rows in (('skills', d.skills), ('items', d.items)):
        for x in rows:
            if not x:
                continue
            for e in x.get('effects', []):
                if e['code'] == 44:
                    callers[e['dataId']].add('battle' if x['occasion'] == 1 else 'map')
                    detail[e['dataId']].append((tab, x['id'], x['occasion']))
            for m in REF.finditer(x.get('note', '')):
                callers[int(m.group(1))].add('map')
                detail[int(m.group(1))].append((tab + '_note', x['id']))
    for t in d.troops:
        if t:
            for i, p in enumerate(t['pages']):
                scan(p['list'], 'battle', ('troop', t['id'], i + 1))
    for f in sorted((d.gen / 'maps').glob('Map*.json')):
        m = json.load(open(f))
        for ev in m.get('events') or []:
            if ev:
                for p in ev['pages']:
                    scan(p['list'], 'map', ('map', f'{f.stem} EV{ev["id"]}'))
    for c in d.ce:
        if not c:
            continue
        if c['trigger'] in (1, 2):
            callers[c['id']].add('map')
        scan(c['list'], ('ce', c['id']), ('ce', c['id']))
    mapr = {k for k, v in callers.items() if 'map' in v}
    ch = True
    while ch:
        ch = False
        for k, v in callers.items():
            if k not in mapr and any(isinstance(w, tuple) and w[1] in mapr for w in v):
                mapr.add(k)
                ch = True
    ids = sorted(k for k, v in callers.items() if k not in mapr and v)
    return ids, detail


# ---------- 原版可达性 ----------
def reachability(d):
    why_skill = defaultdict(list)
    why_troop = defaultdict(list)
    why_item = defaultdict(list)
    sl = d.manifest['slice']
    actors = set(sl['actors']) | set(sl.get('eventActors', []))
    for src, lst in d.lists:
        for c in lst:
            if c['code'] == 129 and c['parameters'][1] == 0:
                actors.add(c['parameters'][0])
        for m in re.finditer(r'addActor\((\d+)\)', script_text(lst)):
            actors.add(int(m.group(1)))
    actors = {a for a in actors if 0 < a < len(d.actors) and d.actors[a]}

    def add(w, k, reason):
        if len(w[k]) < 4:
            w[k].append(reason)

    # 敌群
    for t in sl['troops']:
        add(why_troop, t, '切片敌群')
    for f in sorted((d.gen / 'maps').glob('Map*.json')):
        m = json.load(open(f))
        for enc in m.get('encounterList', []):
            add(why_troop, enc['troopId'], f'{f.stem} 遇敌')
    for src, lst in d.lists:
        for c in lst:
            if c['code'] == 301 and c['parameters'][0] == 0:
                add(why_troop, c['parameters'][1], f'{src} 301')
        for m in re.finditer(r'(?:BattleManager|\$gameTroop)\.setup\(\s*(\d+)', script_text(lst)):
            add(why_troop, int(m.group(1)), f'{src} 脚本 setup')
    troops = set(why_troop)
    enemies = set()
    for t in troops:
        if 0 < t < len(d.troops) and d.troops[t]:
            for mem in d.troops[t]['members']:
                enemies.add(mem['enemyId'])
            for p in d.troops[t]['pages']:
                for c in p['list']:
                    if c['code'] == 336:
                        enemies.add(c['parameters'][1])

    # 技能
    for a in actors:
        cls = d.classes[d.actors[a]['classId']]
        for l in cls['learnings']:
            add(why_skill, l['skillId'], f'角色{a}{d.actors[a]["name"]} 职业{cls["id"]} Lv{l["level"]}')
        for tr in d.actors[a].get('traits', []) + cls.get('traits', []):
            if tr['code'] == 43:
                add(why_skill, tr['dataId'], f'角色{a}／职业特性43')
    # PKD_SimpleSkillsTree 技能树（原版启用；树文件在正式源 data/PKD_SimpleSkillsTree/Generated/skillTree_<职业>.json，转换产物里没有）
    tree_dir = Path(d.manifest.get('source', '')) / 'data/PKD_SimpleSkillsTree/Generated'
    for a in actors:
        f = tree_dir / f'skillTree_{d.actors[a]["classId"]}.json'
        if f.exists():
            for n in re.findall(r'"skillId"\s*:\s*"?(\d+)', f.read_text()):
                add(why_skill, int(n), f'角色{a} 技能树 {f.name}')
    for tab, rows in (('武器', d.weapons), ('防具', d.armors), ('状态', d.states)):
        for x in rows:
            if x and x.get('name'):
                for tr in x.get('traits', []):
                    if tr['code'] == 43:
                        add(why_skill, tr['dataId'], f'{tab}{x["id"]}{x["name"]} 特性43')
    for e in enemies:
        if 0 < e < len(d.enemies) and d.enemies[e]:
            for a in d.enemies[e]['actions']:
                add(why_skill, a['skillId'], f'敌人{e}{d.enemies[e]["name"]} 行动')
    for x in d.items:
        if x and x.get('name'):
            for ef in x.get('effects', []):
                if ef['code'] == 43:
                    add(why_skill, ef['dataId'], f'物品{x["id"]}{x["name"]} 学会')
    for src, lst in d.lists:
        for c in lst:
            if c['code'] == 318 and c['parameters'][2] == 0:
                add(why_skill, c['parameters'][3], f'{src} 318')
            if c['code'] == 339:
                add(why_skill, c['parameters'][2], f'{src} 339')
        for m in re.finditer(r'(?:learnSkill|setSkill|forceSkill)\(\s*(\d+)|\$dataSkills\[\s*(\d+)\s*\]', script_text(lst)):
            add(why_skill, int(m.group(1) or m.group(2)), f'{src} 脚本')
    note_pat = re.compile(r'<\s*(?:ShareLearnSkill|ShareSkill|Replace Attack|Replace Guard)\s*:\s*(\d+)\s*>', re.I)
    for tab, rows in (('武器', d.weapons), ('防具', d.armors), ('状态', d.states), ('物品', d.items), ('技能', d.skills), ('敌人', d.enemies)):
        for x in rows:
            if not x or not x.get('note'):
                continue
            for m in note_pat.finditer(x['note']):
                add(why_skill, int(m.group(1)), f'{tab}{x["id"]}{x.get("name", "")} 备注')
            for m in re.finditer(r'(?:learnSkill|setSkill|forceSkill)\(\s*(\d+)|\$dataSkills\[\s*(\d+)\s*\]', x['note']):
                add(why_skill, int(m.group(1) or m.group(2)), f'{tab}{x["id"]} 备注脚本')
    for e in enemies:
        if not (0 < e < len(d.enemies) and d.enemies[e]):
            continue
        note = d.enemies[e].get('note', '')
        for blk in re.findall(r'<PetPushSkill>(.*?)</PetPushSkill>', note, re.S):
            for a, b in re.findall(r'(\d+)\s*-\s*(\d+)\s*:', blk):
                for s in range(int(a), int(b) + 1):
                    add(why_skill, s, f'敌人{e} 宠物 PetPushSkill')
            for a in re.findall(r'(?m)^\s*(\d+)\s*:', blk):
                add(why_skill, int(a), f'敌人{e} 宠物 PetPushSkill')
        for blk in re.findall(r'<ULevelS>(.*?)</ULevelS>', note, re.S):
            for a in re.findall(r'Lv\d+\s*:\s*(\d+)\s*:', blk):
                add(why_skill, int(a), f'敌人{e} 宠物 ULevelS')
    # 插件参数里的技能表：Star_ActorAdvanced 角色进阶 AdvancedSkiId、AddSkills、LeadSkiId、JiBanSkiId（参数是层层嵌套的 JSON 字符串）
    def walk(v, plugin, key=''):
        if isinstance(v, str):
            s = v.strip()
            if s[:1] in '{[':
                try:
                    return walk(json.loads(s), plugin, key)
                except ValueError:
                    pass
            if PLUGIN_SKILL_KEYS.search(key):
                for n in re.findall(r'\d+', s):
                    add(why_skill, int(n), f'插件 {plugin}.{key}')
        elif isinstance(v, dict):
            for k, x in v.items():
                walk(x, plugin, k)
        elif isinstance(v, list):
            for x in v:
                walk(x, plugin, key)
        elif isinstance(v, int) and PLUGIN_SKILL_KEYS.search(key):
            add(why_skill, v, f'插件 {plugin}.{key}')
    for name, params in (d.plugins or {}).items():
        walk(params, name)
    # 已可达技能的动作序列里的 FORCE ACTION、技能替换 <ChangeTo[N]: …>（不动点，几轮就收敛）
    for _ in range(6):
        for s in list(why_skill):
            if 0 < s < len(d.skills) and d.skills[s]:
                note = d.skills[s].get('note', '')
                for m in re.finditer(r'(?i)(?:force action|force skill)\D{0,12}(\d+)', note):
                    add(why_skill, int(m.group(1)), f'技能{s} 备注 force')
                for m in re.finditer(r'<ChangeTo\[(\d+)\]', note):
                    add(why_skill, int(m.group(1)), f'技能{s}{d.skills[s]["name"]} 技能替换 ChangeTo')

    # 物品
    for src, lst in d.lists:
        for c in lst:
            if c['code'] == 126 and c['parameters'][2] == 0:
                add(why_item, c['parameters'][0], f'{src} 126')
            if c['code'] in (302, 605) and c['parameters'][0] == 0:
                add(why_item, c['parameters'][1], f'{src} 商店')
        for m in re.finditer(r'gainItem\(\s*\$dataItems\[\s*(\d+)', script_text(lst)):
            add(why_item, int(m.group(1)), f'{src} 脚本')
    for e in enemies:
        if 0 < e < len(d.enemies) and d.enemies[e]:
            for dr in d.enemies[e].get('dropItems', []):
                if dr.get('kind') == 1:
                    add(why_item, dr['dataId'], f'敌人{e} 掉落')
            for blk in re.findall(r'<Enemy Drops>(.*?)</Enemy Drops>', d.enemies[e].get('note', ''), re.S | re.I):
                for m in re.finditer(r'Item\s+(\d+)', blk, re.I):
                    add(why_item, int(m.group(1)), f'敌人{e} 追加掉落')
    for x in d.items:
        if x and 'kms_shop_stock' in x.get('note', ''):
            add(why_item, x['id'], '商店备注 kms_shop_stock')
    return why_skill, why_troop, why_item, actors


# ---------- 重制覆盖证据 ----------
def coverage_index():
    """测试、夹具、参照探针里点名的公共事件、技能、敌群"""
    files = list((PROJ / 'tests').glob('*.gd')) + list((PROJ / 'tests/fixtures').glob('*.json'))
    files += list((GODOT_ROOT / '03_转换工具/mv_oracle').glob('*.cjs'))
    ce_hits, skill_hits = defaultdict(set), defaultdict(set)
    ce_pat = re.compile(r'(?:\bCE|\bce|公共事件\s*|CommonEvents"\s*,\s*|reserve\(\s*l\s*,\s*|"dataId"\s*:\s*|commonEvent\s*:\s*)(\d{1,4})\b')
    sk_pat = re.compile(r'(?:技能\s*|learn_skill\(|skill\s*[:=]\s*|"skill"\s*:\s*|setSkill\(|Skills"\s*,\s*)(\d{1,5})\b')
    for f in files:
        try:
            t = f.read_text(errors='ignore')
        except OSError:
            continue
        for m in ce_pat.finditer(t):
            ce_hits[int(m.group(1))].add(f.name)
        for m in sk_pat.finditer(t):
            skill_hits[int(m.group(1))].add(f.name)
    # 重制代码里的专属处理（battle_event_runner 的脚本识别、battle_logic 开战预约等）：只认「公共事件 N／CEN」这种点名
    code_pat = re.compile(r'(?:\bCE|公共事件\s*|common_event\D{0,3})(\d{2,4})\b')
    for f in (PROJ / 'modes').rglob('*.gd'):
        for m in code_pat.finditer(f.read_text(errors='ignore')):
            ce_hits[int(m.group(1))].add('代码 ' + f.name)
    troops = set()
    tc = GODOT_ROOT / '03_转换工具/mv_oracle/troop_event_cases.cjs'
    if tc.exists():
        m = re.search(r'const TROOPS = \[(.*?)\]', tc.read_text(), re.S)
        if m:
            troops = {int(x) for x in re.findall(r'\d+', re.sub(r'//[^\n]*', '', m.group(1)))}
    return ce_hits, skill_hits, troops


def pattern_tools():
    """事件写法覆盖.py 的写法键，和 04_验证/事件写法覆盖.md「有对照例」表（地图对照 xiyou_event_compare 真执行到的写法）"""
    import importlib.util
    spec = importlib.util.spec_from_file_location('event_cover', GODOT_ROOT / '03_转换工具/事件写法覆盖.py')
    ec = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ec)
    md = (GODOT_ROOT / '04_验证/事件写法覆盖.md').read_text()
    part = md.split('## 有对照例', 1)[1] if '## 有对照例' in md else ''
    mapped = set(re.findall(r'^\| `(.+?)` \|', part, re.M))
    return ec, mapped


# 地图上空跑、只有在战斗里才有实际语义的写法：地图对照执行到不算数，要战斗专项真跑过
BATTLE_CODES = ('339', '331', '332', '333', '334', '335', '336', '337', '340', '342')
BATTLE_SCRIPT = re.compile(r'BattleManager|forceAction|\$gameTroop|battleMembers|_actions|Game_Action|isDeathStateAffected|_subject')


def battle_semantic(key):
    return key.split(' ')[0].split('（')[0] in BATTLE_CODES or (key.startswith(('355', '111 条件·脚本', '122 变量·脚本')) and bool(BATTLE_SCRIPT.search(key)))


def keys_of(ec, lst):
    return {ec.key_of(lst, i) for i in range(len(lst)) if int(lst[i]['code']) not in ec.SKIP}


def js_reserved(d):
    """正式源 js/ 下写死的 reserveCommonEvent(N)（rpg_managers 开战预约 1320、战斗结束 1308 等）→ {N: 文件名}"""
    out = {}
    root = Path(d.manifest.get('source', '')) / 'js'
    for f in list(root.glob('*.js')) + list(root.glob('plugins/*.js')):
        for m in re.finditer(r'reserveCommonEvent\(\s*(\d+)\s*\)', f.read_text(errors='ignore')):
            out[int(m.group(1))] = f.name
    return out


def state_reach(d):
    """有谁加这个状态（粗口径：效果 21、特性 14、313／333、脚本与备注 addState(N)、<…PushState N:>、<Passive State: N>）"""
    why = defaultdict(list)

    def add(k, r):
        if len(why[k]) < 3:
            why[k].append(r)
    for tab, rows in (('技能', d.skills), ('物品', d.items), ('武器', d.weapons), ('防具', d.armors), ('状态', d.states), ('敌人', d.enemies), ('角色', d.actors), ('职业', d.classes)):
        for x in rows:
            if not x:
                continue
            for e in x.get('effects', []):
                if e.get('code') == 21 and e.get('dataId', 0) > 0:
                    add(e['dataId'], f'{tab}{x["id"]} 效果21')
            for t in x.get('traits', []):
                if t.get('code') == 14:
                    add(t['dataId'], f'{tab}{x["id"]} 特性14')
            note = x.get('note', '')
            for m in re.finditer(r'addState\(\s*(\d+)|<\w*Push(?:sub)?State\s*0*(\d+)\s*:', note, re.I):
                add(int(m.group(1) or m.group(2)), f'{tab}{x["id"]} 备注')
            for m in re.finditer(r'<Passive States?\s*:\s*([^>]*)>', note, re.I):
                for n in re.findall(r'\d+', m.group(1)):
                    add(int(n), f'{tab}{x["id"]} 被动')
    for src, lst in d.lists:
        for c in lst:
            if c['code'] in (313, 333) and c['parameters'][-2] == 0:
                add(c['parameters'][-1], f'{src} {c["code"]}')
        for m in re.finditer(r'addState\(\s*(\d+)', script_text(lst)):
            add(int(m.group(1)), f'{src} 脚本')
    return why


def effective(lst):
    return [c for c in lst or [] if c['code'] not in (0, 108, 408)]


def run_godot(ids, out):
    tmp = PROJ / '_tmp_battle_ce'
    tmp.mkdir(exist_ok=True)
    (tmp / 'battle_ce_run.gd').write_text((HERE / 'battle_ce_run.gd').read_text())
    (tmp / 'run.tscn').write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://_tmp_battle_ce/battle_ce_run.gd" id="1"]\n\n'
                                  '[node name="Run" type="Node"]\nscript = ExtResource("1")\n')
    env = dict(os.environ, BATTLE_CE_IDS=','.join(map(str, ids)), BATTLE_CE_OUT=str(out))
    try:
        subprocess.run([sys.executable, str(GODOT_ROOT / '07_开发环境/占槽.py'), '--label', 'battle-ce-inventory', '--',
                        str(GODOT_ROOT / '07_开发环境/godot'), '--headless', '--path', str(PROJ), '-s', 'tests/test_main_loop.gd',
                        'res://_tmp_battle_ce/run.tscn'], env=env, check=True)
    finally:
        for f in tmp.iterdir():
            f.unlink()
        tmp.rmdir()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--generated', type=Path, default=DEFAULT_GEN)
    ap.add_argument('--run', type=Path)
    ap.add_argument('--out-dir', type=Path, default=DEFAULT_OUT)
    a = ap.parse_args()
    d = Data(a.generated)
    ids, detail = battle_only(d)
    a.out_dir.mkdir(parents=True, exist_ok=True)
    run_path = a.run or (a.out_dir / 'run.json')
    if not run_path.exists():
        run_godot(ids, run_path)
    run = json.load(open(run_path))
    why_skill, why_troop, why_item, _ = reachability(d)
    ce_hits, skill_hits, case_troops = coverage_index()
    bset = set(ids)
    all_called = set(detail) | {c['id'] for c in d.ce if c and c['trigger'] in (1, 2)}
    js_roots = js_reserved(d)
    why_state = state_reach(d)
    # 状态备注里的 reserveCommonEvent（bonly.py 不扫状态备注；这里只补证据，不改名单）
    for st in d.states:
        if st and st.get('note'):
            for m in REF.finditer(st['note']):
                if int(m.group(1)) in bset:
                    detail[int(m.group(1))].append(('state', st['id']))

    # 先算调用方可达（公共事件调用方要不动点）
    reach = {}
    for _ in range(10):
        for i in ids:
            ok, ev = False, []
            for c in detail[i]:
                if c[0] == 'skills' and c[2] == 1:
                    w = why_skill.get(c[1])
                    ev.append(f'技能{c[1]}{d.name("skills", c[1])}：' + ('；'.join(w[:2]) if w else '无人学会／使用'))
                    ok |= bool(w)
                elif c[0] == 'items' and c[2] == 1:
                    w = why_item.get(c[1])
                    ev.append(f'物品{c[1]}{d.name("items", c[1])}：' + ('；'.join(w[:2]) if w else '拿不到'))
                    ok |= bool(w)
                elif c[0] == 'troop':
                    w = why_troop.get(c[1])
                    ev.append(f'敌群{c[1]}{d.name("troops", c[1])}第{c[2]}页：' + ('；'.join(w[:2]) if w else '没有地图／事件开这场战斗'))
                    ok |= bool(w)
                elif c[0] == 'ce' and c[1] in bset:
                    r = reach.get(c[1], (False,))[0]
                    ev.append(f'公共事件{c[1]}{d.name("ce", c[1])}：' + ('可达' if r else '不可达'))
                    ok |= r
                elif c[0] == 'ce' and c[1] in js_roots:
                    ev.append(f'公共事件{c[1]}{d.name("ce", c[1])}：引擎脚本 {js_roots[c[1]]} 写死预约')
                    ok = True
                elif c[0] == 'ce':
                    ev.append(f'公共事件{c[1]}{d.name("ce", c[1])}：' + ('本身没有任何调用方（孤立）' if c[1] not in all_called else '（另见）'))
                elif c[0] == 'state':
                    w = why_state.get(c[1])
                    ev.append(f'状态{c[1]}{d.name("states", c[1])}备注 reserveCommonEvent：' + ('；'.join(w[:2]) if w else '没有谁加这个状态'))
                    ok |= bool(w)
            reach[i] = (ok, ev)

    ec, map_keys = pattern_tools()
    battle_keys = set()   # 战斗专项真跑过的写法：点名的公共事件与 troop_event_cases 里敌群的页
    for i, files in ce_hits.items():
        if any(not f.startswith('代码 ') for f in files) and 0 < i < len(d.ce) and d.ce[i]:
            battle_keys |= keys_of(ec, d.ce[i]['list'])
    for t in case_troops:
        if 0 < t < len(d.troops) and d.troops[t]:
            for pg in d.troops[t]['pages']:
                battle_keys |= keys_of(ec, pg['list'])

    rows = []
    for i in ids:
        c = d.ce[i]
        ok, ev = reach[i]
        r = run.get(str(i), {})
        skips = sorted({f'{x["code"]}' for x in r.get('iso', [])} | {s.split(' ')[0] for s in r.get('full', [])})
        callers_sk = [x[1] for x in detail[i] if x[0] == 'skills']
        callers_tr = [x[1] for x in detail[i] if x[0] == 'troop']
        cov = []
        if ce_hits.get(i):
            cov.append(f'点名本事件：{"、".join(sorted(ce_hits[i]))}')
        for s in callers_sk:
            if skill_hits.get(s):
                cov.append(f'点名技能{s}：{"、".join(sorted(skill_hits[s])[:4])}')
        for t in callers_tr:
            if t in case_troops:
                cov.append(f'敌群{t}在 troop_event_cases（xiyou_troop_events）')
        generic = any(x[0] in ('skills', 'items') and x[2] in (0, 1) for x in detail[i])
        if not effective(c['list']):
            cat, note = '原版无效', '事件体没有有效指令'
        elif not ok:
            cat, note = '原版无效', '调用方都不可达' + (f'（另：Godot 实跑有跳过 {"/".join(skips)}，因走不到不用补）' if skips else '')
        elif skips:
            cat, note = '没翻译', f'跳过指令 {"/".join(skips)}（{len(r.get("iso", []))} 条）'
        elif cov:
            cat, note = '重制已覆盖', '专项／专属模块点名'
        else:
            ks = keys_of(ec, c['list'])
            miss = sorted(k for k in ks if k not in battle_keys and (battle_semantic(k) or k not in map_keys))
            if not miss:
                cat, note = '重制已覆盖', '同写法：战斗语义的写法（339／331～337／340／342、碰 BattleManager／$gameTroop／Game_Action 的脚本）在战斗专项里真跑过，其余写法在地图对照（04_验证/事件写法覆盖.md 有对照例）或战斗专项里真跑过'
                cov.append('同写法有对照')
            else:
                cat = '到得了未覆盖'
                note = ('只有 _inventory 通跑（不比原版）；' if generic else '没有测试跑到；') + '没对照过的写法：' + '；'.join(miss)
        rows.append({'id': i, 'name': c['name'], 'category': cat, 'reachable': ok, 'callers': '｜'.join(ev),
                     'coverage': '｜'.join(cov) + (('｜' if cov else '') + '_inventory 通跑无跳过' if generic and not skips else ''),
                     'skipped': skips, 'commands': len(effective(c['list'])), 'note': note})
    (a.out_dir / '盘点表.json').write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    with open(a.out_dir / '盘点表.csv', 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['事件id', '名称', '类别', '原版可达', '触发来源', '覆盖证据', '有效指令数', '备注'])
        for x in rows:
            w.writerow([x['id'], x['name'], x['category'], '是' if x['reachable'] else '否', x['callers'], x['coverage'], x['commands'], x['note']])
    from collections import Counter
    cnt = Counter(x['category'] for x in rows)
    (a.out_dir / '盘点表.md').write_text(render_md(rows, cnt))
    print(json.dumps({'total': len(rows), 'by_category': cnt}, ensure_ascii=False))


def render_md(rows, cnt):
    def esc(t):
        return str(t).replace('|', '／').replace('\n', ' ')
    out = ['# 战斗专用公共事件盘点表', '',
           '由 `03_转换工具/事件预设脚本/战斗公共事件盘点/盘点.py` 生成（口径见脚本文件头），别手改；复跑：`python3 03_转换工具/事件预设脚本/战斗公共事件盘点/盘点.py`。', '',
           f'共 {len(rows)} 个：' + '、'.join(f'{k} {cnt.get(k, 0)}' for k in ('重制已覆盖', '到得了未覆盖', '没翻译', '原版无效')) + '。', '']
    gaps = [x for x in rows if x['reachable'] and x['category'] in ('到得了未覆盖', '没翻译')]
    out += ['## 真缺口（到得了又没覆盖／没翻译）', '']
    if gaps:
        out += ['| 事件 | 名称 | 类别 | 触发来源 | 说明 |', '| --- | --- | --- | --- | --- |']
        out += [f'| {x["id"]} | {esc(x["name"])} | {x["category"]} | {esc(x["callers"])} | {esc(x["note"])} |' for x in gaps]
    else:
        out += ['无。']
    for cat in ('没翻译', '原版无效', '重制已覆盖'):
        sel = [x for x in rows if x['category'] == cat and not (cat == '没翻译' and x['reachable'])]
        out += ['', f'## {cat}（{len(sel)}）', '', '| 事件 | 名称 | 触发来源 | 覆盖证据 | 备注 |', '| --- | --- | --- | --- | --- |']
        out += [f'| {x["id"]} | {esc(x["name"])} | {esc(x["callers"][:300])} | {esc(x["coverage"][:200])} | {esc(x["note"][:200])} |' for x in sel]
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    main()
