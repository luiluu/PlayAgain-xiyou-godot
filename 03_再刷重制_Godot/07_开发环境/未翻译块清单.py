#!/usr/bin/env python3
"""未翻译状态块 × 切片可达清单（哪吒 tools55，给八戒排后续规则期用；只读，不改任何数据）。

用法：未翻译块清单.py [--json] [--detail] [--generated 目录]
- 读 modes/xiyou/generated/db/States.json 里每个 `op: js` 块（`xiyou_state_effects_tp` 的 inventory.merged_315 锁的就是它们），
  给出：状态号、状态名、phase、族、可达性三档、从哪条路径加上。
- 族（按原文模板归类，顺序即优先级）：换装、护盾、复活、regenerate、reserveCommonEvent、伤害 react／confirm、回合／行动钩子、改属性／变量、其它。
- 切片口径：manifest.json 的 `slice`（xiyou_export.collect_slice 的结果：actors／eventActors、enemies、skills、troops、commonEvents）与 slice.json 的 maps，
  不另发明。道具／武器／防具 manifest 里没有列表，这里按「切片角色初始装备、切片敌人掉落、切片地图／公共事件／敌群里 126～128 给的东西与 302／605 商店」估算，
  估算口径写在输出里。切片技能另并上切片角色（及其职业）特性 43 加的技能、切片事件 318 与脚本 `learnSkill(n)` 教的技能、CE1442 洪荒诅咒自选教的 7201～7215。
- 可达性三档：切片可达（切片技能／道具／装备／敌人／敌群／公共事件／地图事件能加上）／全游戏可达（只有切片外的记录能加上）／不可达（数据里没有谁加）。
- 加状态的路径（口径照 rules1b 盘点）：效果 code 21、特性 14（攻击附带状态）、备注与状态 js 里的 addState(n)、备注「状态 n」（弱匹配，单独标 ✱）、
  `<Passive State: …>`、插件备注标签 `…PushState0123: 100%`（PushState／StartPushState／StartWTPushState／StartAEPushState／RecPushState／PushsubState 等，补零的状态号）、装备套装 states、指令 313／333 与脚本指令里的 addState(n)；状态再加状态沿着链往下传（取最近的一档）。
  插件里硬编码加状态的路径不在数据里，查不到；`addState(` 的参数不是整数字面量的算「未解析」，单独列出。
"""
import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / '01_Godot工程/modes/xiyou/generated'

SLICE, ALL, NONE = 0, 1, 2
TIER_NAMES = {SLICE: '切片可达', ALL: '全游戏可达', NONE: '不可达'}
FAMILIES = ['换装', '护盾', '复活', 'regenerate', 'reserveCommonEvent', '伤害 react／confirm', '回合／行动钩子', '改属性／变量', '其它']

ADD_STATE_RE = re.compile(r'addState\(\s*(\d+)\s*\)')
ADD_STATE_ANY_RE = re.compile(r'addState\(\s*([^)]*?)\s*\)')
LEARN_RE = re.compile(r'learnSkill\(\s*(\d+)\s*\)')
WEAK_RE = re.compile(r'状态\s*(\d+)')
# 插件备注标签：PushState／StartPushState／StartWTPushState／StartAEPushState／RecPushState／PushsubState／StartRom…PushState + 状态号（4 位补零）
PUSH_RE = re.compile(r'<\w*Push(?:sub)?State\s*0*(\d+)\s*:', re.I)
PASSIVE_RE = re.compile(r'<Passive State[s]?\s*:\s*([^>]*)>', re.I)


def family(effect):
    """按原文模板把一个 js 块归族；顺序即优先级。"""
    phase, src = effect['phase'], effect.get('source', '')
    if 'setBattlerImage' in src:
        return '换装'
    if '_bubbleWrapCooldown' in src or (phase == 'react' and 'getItemElements' in src and 'removeState' in src):
        return '护盾'
    if phase == 'deselect' and ('gainHp' in src or 'setHp' in src):
        return '复活'
    if phase == 'regenerate':
        return 'regenerate'
    if 'reserveCommonEvent' in src:
        return 'reserveCommonEvent'
    if phase in ('react', 'confirm', 'respond', 'establish', 'crit') and ('isHpEffect' in src or 'gainHp' in src or 'gainMp' in src):
        return '伤害 react／confirm'
    if phase in ('turn_start', 'turn_end', 'action_start', 'action_end'):
        return '回合／行动钩子'
    if '$gameVariables' in src or '_tp' in src or 'this._' in src or 'paramPlus' in src:
        return '改属性／变量'
    return '其它'


def passive_ids(text):
    """`<Passive State: 1, 3 to 5>` → [1, 3, 4, 5]"""
    out = []
    for m in PASSIVE_RE.finditer(text or ''):
        for part in m.group(1).split(','):
            r = re.fullmatch(r'\s*(\d+)\s*(?:to|-|~)\s*(\d+)\s*', part, re.I)
            if r:
                out += range(int(r.group(1)), int(r.group(2)) + 1)
            elif part.strip().isdigit():
                out.append(int(part))
    return out


def text_states(text):
    """文本里加的状态：([整数字面量], [弱匹配「状态 n」], 未解析 addState 参数个数)"""
    strong = [int(x) for x in ADD_STATE_RE.findall(text or '')]
    unresolved = sum(1 for x in ADD_STATE_ANY_RE.findall(text or '') if not x.isdigit())
    weak = [int(x) for x in WEAK_RE.findall(text or '')]
    return strong, weak, unresolved


def command_texts(commands):
    """脚本指令 355 + 后续 655 拼成整段文本。"""
    out, cur = [], None
    for c in commands or []:
        if c['code'] == 355:
            cur = [c['parameters'][0]]
            out.append(cur)
        elif c['code'] == 655 and cur is not None:
            cur.append(c['parameters'][0])
        else:
            cur = None
    return ['\n'.join(x) for x in out]


class Graph:
    """state -> [(tier, 路径, 弱?)]；另记未解析的 addState 来源。"""

    def __init__(self):
        self.src = defaultdict(list)
        self.unresolved = Counter()
        self.seen = set()

    def add(self, state, tier, label, weak=False):
        if isinstance(state, int) and state > 0 and (state, tier, label, weak) not in self.seen:
            self.seen.add((state, tier, label, weak))
            self.src[state].append((tier, label, weak))

    def add_text(self, text, tier, label, notes=False):
        strong, weak, unresolved = text_states(text)
        for s in strong:
            self.add(s, tier, label)
        if notes:
            for s in weak:
                self.add(s, tier, label + '（备注「状态 n」）', weak=True)
        if unresolved:
            self.unresolved[label] += unresolved

    def add_record(self, rec, tier, label, notes=True):
        """技能／道具／装备／敌人／角色／职业／状态记录本身（效果、特性、备注）。"""
        for e in rec.get('effects') or []:
            if e.get('code') == 21 and e.get('dataId'):
                self.add(e['dataId'], tier, label)
            if e.get('op') == 'js':
                self.add_text(e.get('source', ''), tier, label)
        for t in rec.get('traits') or []:
            if t.get('code') == 14 and t.get('dataId'):
                self.add(t['dataId'], tier, label)
        note = rec.get('note') or ''
        self.add_text(note, tier, label, notes=notes)
        for s in passive_ids(note):
            self.add(s, tier, label + '（被动状态）')
        for s in PUSH_RE.findall(note):
            self.add(int(s), tier, label + '（备注 PushState）')

    def add_commands(self, commands, tier, label):
        for c in commands or []:
            p = c.get('parameters') or []
            if c['code'] == 313 and len(p) >= 4 and p[2] == 0:
                self.add(p[3], tier, label)
            elif c['code'] == 333 and len(p) >= 3 and p[1] == 0:
                self.add(p[2], tier, label)
        for text in command_texts(commands):
            self.add_text(text, tier, label)


def load(generated):
    db = {}
    for name in ('Actors', 'Classes', 'Skills', 'Items', 'Weapons', 'Armors', 'Enemies', 'Troops', 'States', 'CommonEvents', 'EquipSuits'):
        db[name] = json.loads((generated / 'db' / f'{name}.json').read_text())
    manifest = json.loads((generated / 'manifest.json').read_text())['slice']
    slice_cfg = json.loads((generated / 'slice.json').read_text())
    maps = {}
    for mid in slice_cfg.get('maps', []):
        f = generated / 'maps' / f'Map{mid:03d}.json'
        if f.exists():
            maps[mid] = json.loads(f.read_text())
    return db, manifest, maps


def recs(table):
    return [r for r in table if isinstance(r, dict)]


def slice_sets(db, manifest, maps):
    """切片集合：skills、enemies、troops、commonEvents、actors 取 manifest；items／weapons／armors 估算。"""
    s = {k: set(manifest.get(k, [])) for k in ('actors', 'enemies', 'skills', 'troops', 'commonEvents')}
    s['actors'] |= set(manifest.get('eventActors', []))
    gear = {'Items': set(), 'Weapons': set(), 'Armors': set()}
    kinds = {0: 'Items', 1: 'Weapons', 2: 'Armors'}
    # 切片角色初始装备（MV equips 里 slot 0 是武器，其余是防具）
    for aid in s['actors']:
        a = db['Actors'][aid]
        for i, eid in enumerate(a.get('equips') or []):
            if isinstance(eid, int) and eid > 0:
                gear['Weapons' if i == 0 else 'Armors'].add(eid)
    # 切片敌人掉落（数据库掉落＋YEP_ExtraEnemyDrops 备注）
    for eid in s['enemies']:
        e = db['Enemies'][eid]
        for d in e.get('dropItems') or []:
            if d.get('kind', 0) > 0:
                gear[kinds[d['kind'] - 1]].add(d['dataId'])
        for kind, did in re.findall(r'(Item|Weapon|Armor)\s+(\d+)\s*:', e.get('note') or '', re.I):
            gear[{'item': 'Items', 'weapon': 'Weapons', 'armor': 'Armors'}[kind.lower()]].add(int(did))
    # 切片事件／公共事件／敌群里给的东西与商店；318 教的技能
    for lst in slice_command_lists(db, s, maps):
        for c in lst[2]:
            p = c.get('parameters') or []
            if c['code'] in (126, 127, 128) and p and isinstance(p[0], int):
                gear[{126: 'Items', 127: 'Weapons', 128: 'Armors'}[c['code']]].add(p[0])
            elif c['code'] in (302, 605) and len(p) >= 2 and p[0] in kinds and isinstance(p[1], int):
                gear[kinds[p[0]]].add(p[1])
            elif c['code'] == 318 and len(p) >= 3 and p[1] == 0 and isinstance(p[2], int):
                s['skills'].add(p[2])
        for text in command_texts(lst[2]):
            s['skills'] |= {int(x) for x in LEARN_RE.findall(text)}
    if 1442 in s['commonEvents']:  # 洪荒诅咒自选（CE1442）后半按变量 learnSkill(7200+N)，N 是 1～15，写死
        s['skills'] |= set(range(7201, 7216))
    # 切片角色及其职业特性 43 加的技能
    for aid in s['actors']:
        a = db['Actors'][aid]
        for holder in (a, db['Classes'][a['classId']]):
            for t in holder.get('traits') or []:
                if t.get('code') == 43:
                    s['skills'].add(t['dataId'])
    s.update({k: v for k, v in gear.items()})
    return s


def slice_command_lists(db, s, maps):
    """切片里所有事件指令列表：[(tier标签, 路径, 指令列表)]"""
    out = []
    for ce in sorted(s['commonEvents']):
        if 0 < ce < len(db['CommonEvents']) and db['CommonEvents'][ce]:
            out.append((SLICE, f'公共事件 {ce}', db['CommonEvents'][ce]['list']))
    for tid in sorted(s['troops']):
        if 0 < tid < len(db['Troops']) and db['Troops'][tid]:
            for i, pg in enumerate(db['Troops'][tid]['pages']):
                out.append((SLICE, f'敌群 {tid}', pg['list']))
    for mid, m in maps.items():
        for ev in m.get('events') or []:
            if ev:
                for pg in ev['pages']:
                    out.append((SLICE, f'地图 {mid} 事件 {ev["id"]}', pg['list']))
    return out


def build_graph(db, manifest, maps):
    s = slice_sets(db, manifest, maps)
    g = Graph()

    def tier_of(slice_set, rid):
        return SLICE if rid in slice_set else ALL

    # 技能、道具、武器、防具、敌人
    for table, key, label in (('Skills', 'skills', '技能'), ('Items', 'Items', '道具'), ('Weapons', 'Weapons', '武器'), ('Armors', 'Armors', '防具'), ('Enemies', 'enemies', '敌人')):
        for rec in recs(db[table]):
            g.add_record(rec, tier_of(s[key], rec['id']), f'{label} {rec["id"]}')
    # 角色、职业（备注与特性；切片角色算切片）
    for rec in recs(db['Actors']):
        g.add_record(rec, tier_of(s['actors'], rec['id']), f'角色 {rec["id"]}')
    slice_classes = {db['Actors'][a]['classId'] for a in s['actors']}
    for rec in recs(db['Classes']):
        g.add_record(rec, tier_of(slice_classes, rec['id']), f'职业 {rec["id"]}')
    # 装备套装
    for rec in recs(db['EquipSuits']):
        for b in rec.get('bonuses') or []:
            for st in b.get('states') or []:
                g.add(st, ALL, f'套装 {rec["id"]}')
    # 公共事件、敌群（切片的算切片；其余算全游戏），地图事件（只有切片地图）
    for ce in recs(db['CommonEvents']):
        g.add_commands(ce.get('list'), tier_of(s['commonEvents'], ce['id']), f'公共事件 {ce["id"]}')
    for tr in recs(db['Troops']):
        for pg in tr.get('pages') or []:
            g.add_commands(pg.get('list'), tier_of(s['troops'], tr['id']), f'敌群 {tr["id"]}')
    for mid, m in maps.items():
        for ev in m.get('events') or []:
            if ev:
                for pg in ev['pages']:
                    g.add_commands(pg['list'], SLICE, f'地图 {mid} 事件 {ev["id"]}')
    # 状态加状态：沿链往下传，取最近的一档
    states = {st['id']: st for st in recs(db['States'])}
    base = defaultdict(list)  # 状态 -> 它自己加的状态
    tmp = Graph()
    for sid, st in states.items():
        tmp.add_record(st, SLICE, f'状态 {sid}')
    for target, items in tmp.src.items():
        for tier, label, weak in items:
            base[int(label.split()[1].split('（')[0])].append((target, label, weak))
    g.unresolved.update(tmp.unresolved)
    changed = True
    while changed:
        changed = False
        for owner, adds in base.items():
            tiers = [t for t, _, w in g.src.get(owner, []) if not w] or [t for t, _, _ in g.src.get(owner, [])]
            if not tiers:
                continue
            best = min(tiers)
            for target, label, weak in adds:
                before = len(g.seen)
                g.add(target, best, label, weak)
                changed |= len(g.seen) != before
    return g, s


def reach(g, state):
    items = g.src.get(state, [])
    if not items:
        return NONE, []
    best = min(t for t, _, _ in items)
    paths = []
    for t, label, weak in sorted(items, key=lambda x: (x[0], x[2], x[1])):
        if t == best:
            paths.append(label + (' ✱' if weak else ''))
    return best, paths


def blocks(db, g):
    rows = []
    for st in recs(db['States']):
        for e in st.get('effects') or []:
            if e.get('op') == 'js':
                tier, paths = reach(g, st['id'])
                rows.append({'state': st['id'], 'name': st.get('name', ''), 'phase': e['phase'], 'family': family(e), 'tier': TIER_NAMES[tier], 'paths': paths})
    return rows


def render(rows, g, s, detail):
    out = []
    out.append(f'未翻译 `op: js` 块共 {len(rows)} 块，分布在 {len({r["state"] for r in rows})} 个状态。\n')
    out.append('### 按族汇总（块数）\n')
    out.append('| 族 | 切片可达 | 全游戏可达 | 不可达 | 合计 |')
    out.append('| --- | ---: | ---: | ---: | ---: |')
    tot = Counter()
    for fam in FAMILIES:
        c = Counter(r['tier'] for r in rows if r['family'] == fam)
        out.append(f'| {fam} | {c["切片可达"]} | {c["全游戏可达"]} | {c["不可达"]} | {sum(c.values())} |')
        tot.update(c)
    out.append(f'| **合计** | {tot["切片可达"]} | {tot["全游戏可达"]} | {tot["不可达"]} | {sum(tot.values())} |\n')
    if detail:
        out.append('### 切片可达明细（换装已不用翻，另列在汇总里）\n')
        out.append('| 状态 | 名称 | phase | 族 | 路径（最多 3 条） |')
        out.append('| ---: | --- | --- | --- | --- |')
        for r in sorted((r for r in rows if r['tier'] == '切片可达' and r['family'] != '换装'), key=lambda r: (FAMILIES.index(r['family']), r['state'], r['phase'])):
            paths = r['paths'][:3] + (['…共 %d 条' % len(r['paths'])] if len(r['paths']) > 3 else [])
            out.append(f'| {r["state"]} | {r["name"]} | {r["phase"]} | {r["family"]} | {"；".join(paths)} |')
        out.append('')
    out.append(f'未解析的 `addState(非整数字面量)`：{sum(g.unresolved.values())} 处（来源 {len(g.unresolved)} 个），例：' +
               '、'.join(f'{k}×{v}' for k, v in list(g.unresolved.most_common(8))) + '。\n')
    weak_only = sorted({r['state'] for r in rows if r['paths'] and all(p.endswith('✱') for p in r['paths'])})
    out.append(f'只靠弱匹配（备注「状态 n」✱）判可达的状态 {len(weak_only)} 个：{weak_only}。\n')
    out.append('切片集合：' + '，'.join(f'{k} {len(v)}' for k, v in s.items()) + '（道具／武器／防具为估算）。')
    return '\n'.join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--json', action='store_true', help='输出每块一行的 JSON')
    ap.add_argument('--detail', action='store_true', help='附切片可达明细表')
    ap.add_argument('--generated', type=Path, default=GENERATED)
    args = ap.parse_args(argv)
    db, manifest, maps = load(args.generated)
    g, s = build_graph(db, manifest, maps)
    rows = blocks(db, g)
    if args.json:
        json.dump(rows, sys.stdout, ensure_ascii=False, indent=1)
        print()
    else:
        print(render(rows, g, s, args.detail))
    return 0


if __name__ == '__main__':
    sys.exit(main())
