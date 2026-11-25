#!/usr/bin/env python3
"""天启篇我方角色「自然体质」表生成器（T484 A2 卡，设计稿 元素独特效果 v0.3 第 4.4 节；D285④）。

  python3 03_再刷重制_Godot/03_转换工具/天启篇我方体质表生成.py --out-dir <差异表目录> [--write-table]

- 只读 generated/db（Actors／Skills）、core/imported_balance.gd（DISABLED_ACTORS 与解放名单）、tianqi_data/skill_rework.json、elements_table.json；
  西游档数据零改动。`--write-table` 才写 tianqi_data/actor_nature.json。
- 可用角色＝有名字、不在 skill_rework.tiers「不开放」、不是停用角色（imported_balance 的 DISABLED_ACTORS，苍龙破晓 146、徐凤年 152 已解放算可用；五条悟 180 算可用，解锁前不进候选池但有体质）。
- 原生元素：该角色在天启篇技能卡（skill_rework.skills 里 actor＝角色号）的**自带攻击招**（有效伤害类型是 HP 伤害／吸血，不含被动、心法、治疗、功能），
  每招的元素集按天启篇运行时口径（XTianqiElements._patch_skill）：基础记录 elementId＋Multiple Elements，再套技能卡 element 覆盖、
  skill_shifts（改水／风）、physical_shifts（物理改成 无属性＋水／风），物理（1）按无属性（0）。
  每招给它的每个元素各记一票（多元素招每系一票，无属性算一类）；得票最多的类就是原生；并列时取并列类里「技能号最小的攻击招」所带的那一类（并列取第一个主攻招）。
- 原生是无属性或高等三系（虚空／混沌／空间）→ 没有体质；没有任何攻击招 → 没有体质。转换书、转属、装备附伤不改体质（转换技能不属于任何角色，本来就不进票）。
- 手工覆盖写在 MANUAL（暂空，人核差异报告里列出要人看的）；改规则直接改本文件。
"""
import argparse
import importlib.util
import json
import re
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
XY = HERE.parent / '01_Godot工程' / 'modes' / 'xiyou'
DB = XY / 'generated' / 'db'
OUT_TABLE = XY / 'tianqi_data' / 'actor_nature.json'

_spec = importlib.util.spec_from_file_location('enemy_nature_gen', HERE / '天启篇体质表生成.py')
_en = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_en)
NAMES, ALLN = _en.NAMES, _en.ALLN
HIGHER = {11, 12, 13}
GOJO = 180
NEUTRAL = 0  # 无属性（含原物理 1，天启篇物理按无属性）
ATTACK_TYPES = {1, 5}  # RMMV damage.type：1 HP 伤害、5 HP 吸收
NOT_ATTACK_KINDS = {'被动', '心法', '功能', '领袖', '领袖说明', '光环', '进阶', '复活', '复活全体', '全体治疗', '治疗', '单体治疗', '护盾', '全体增益'}

# 人核覆盖：id→(体质元素号或 None, 理由)；src 记 manual，verdict 必填。暂无，差异报告里列出的才需要人看。
MANUAL = {}


def parse_disabled():
    t = (XY / 'core' / 'imported_balance.gd').read_text(encoding='utf-8')
    m = re.search(r'^const DISABLED_ACTORS\s*:?=\s*(\[[^\]]*\])', t, re.M)
    dis = set(json.loads(m.group(1)))
    rel = {int(x) for x in re.findall(r'^const (?:CANGLONG|XUFENG)\s*:?=\s*(\d+)', t, re.M)}
    return dis - rel, rel  # 解放的两位算可用


def load():
    actors = {x['id']: x for x in json.load(open(DB / 'Actors.json')) if x}
    classes = {x['id']: x for x in json.load(open(DB / 'Classes.json')) if x}
    skills = {x['id']: x for x in json.load(open(DB / 'Skills.json')) if x}
    rework = json.load(open(XY / 'tianqi_data' / 'skill_rework.json'))
    table = json.load(open(XY / 'tianqi_data' / 'elements_table.json'))
    return actors, skills, rework, table, classes


def usable_ids(actors, rework, disabled):
    closed = set(rework['tiers'].get('不开放', []))
    return sorted(i for i, a in actors.items() if str(a.get('name', '')).strip() and i not in closed and i not in disabled)


def multi_elements(note):
    m = re.search(r'(?i)<Multiple Elements:\s*([\d,\s]+)>', note or '')
    return [int(x) for x in re.findall(r'\d+', m.group(1))] if m else []


def skill_elements(sid, base, sp, table):
    """天启篇运行时的这招元素集（顺序＝主元素在前），同 XTianqiElements._patch_skill + map_element_id。"""
    eid = int(base['damage']['elementId'])
    multi = multi_elements(base.get('note', ''))
    if 'element' in sp:
        eid = int(sp['element'])
    s_key = str(sid)
    if s_key in table['skill_shifts'] and table['skill_shifts'][s_key].get('elements'):
        el = [int(x) for x in table['skill_shifts'][s_key]['elements']]
        eid, multi = el[0], el[1:]
    elif s_key in table['physical_shifts']:
        eid, multi = 0, [int(table['physical_shifts'][s_key]['element'])]
    out = []
    for e in [eid] + multi:
        e = NEUTRAL if e in (1, -1, 10) else e  # 10 治疗不是伤害元素，按无属性
        if e not in out:
            out.append(e)
    return out


def effective_type(base, sp):
    return int(sp['dmg_type']) if 'dmg_type' in sp else int(base['damage'].get('type', 0))


def build():
    actors, skills, rework, table, classes = load()
    disabled, released = parse_disabled()
    ids = usable_ids(actors, rework, disabled)
    sk = rework['skills']
    new_from = {int(k): int(v['from']) for k, v in rework.get('new_skills', {}).items()}
    owned = {}
    missing = []
    for k, sp in sk.items():
        if 'actor' not in sp:
            continue
        sid = int(k)
        base = skills.get(sid) or skills.get(new_from.get(sid, -1))
        if not base and int(sp['actor']) == GOJO:  # 五条悟的技能由 core/gojo.gd 运行时造：elementId 0，攻击招伤害类型 1
            base = {'damage': {'elementId': 0, 'type': 1}, 'note': '', 'name': sp.get('name', '')}
        if not base:
            missing.append(sid)
            continue
        owned.setdefault(int(sp['actor']), []).append((sid, sp, base))
    # 技能卡还没做的角色（146、175 等）：退回原版自带技能（角色特性 43＋职业技能表），basis＝original
    for i in ids:
        if not owned.get(i):
            a = actors[i]
            sids = [t['dataId'] for t in a['traits'] if t['code'] == 43] + [l['skillId'] for l in classes[a['classId']]['learnings']]
            for sid in dict.fromkeys(sids):
                if sid in skills:
                    owned.setdefault(i, []).append((sid, {}, skills[sid]))
    rows = {}
    for i in ids:
        votes, first_of = Counter(), {}
        used = []
        for sid, sp, base in sorted(owned.get(i, []), key=lambda t: t[0]):
            if sp.get('kind') in NOT_ATTACK_KINDS or effective_type(base, sp) not in ATTACK_TYPES:
                continue
            els = skill_elements(sid, base, sp, table)
            used.append((sid, sp.get('name', base.get('name', '')), els))
            for e in els:
                votes[e] += 1
                first_of.setdefault(e, sid)
        row = dict(id=i, name=actors[i]['name'], basis='card' if any(str(s) in sk for s, _, _ in owned.get(i, [])) else 'original', votes=dict(votes), n_attack=len(used), used=used)
        if not used:
            row.update(natures=[], src='no_attack', tie=[], winner=None)
        else:
            top = max(votes.values())
            tied = [e for e in votes if votes[e] == top]
            winner = min(tied, key=lambda e: first_of[e]) if len(tied) > 1 else tied[0]
            src = 'tie_first' if len(tied) > 1 else 'majority'
            if winner in NAMES:
                row.update(natures=[winner], src=src)
            else:
                row.update(natures=[], src='higher' if winner in HIGHER else 'neutral')
            row.update(tie=tied if len(tied) > 1 else [], winner=winner)
        if i in MANUAL:
            e, why = MANUAL[i]
            row.update(natures=[e] if e else [], src='manual', verdict=why)
        rows[i] = row
    return actors, rows, disabled, released, rework, missing


def fnat(l):
    return '、'.join(ALLN.get(x, '无属性' if x == NEUTRAL else str(x)) for x in l) or '—'


def fvotes(v):
    return ' '.join('%s%d' % (ALLN.get(e, '无属性' if e == NEUTRAL else str(e)), n) for e, n in sorted(v.items(), key=lambda t: -t[1]))


def report(outdir, actors, rows, disabled, released, rework, missing):
    cnt = Counter(r['src'] for r in rows.values())
    by = Counter(r['natures'][0] for r in rows.values() if r['natures'])
    md = ['# T484 A2 卡：天启篇我方体质表差异报告', '',
          '可用角色 %d 名（有名字、不在不开放名单、不是停用角色；解放的 %s 算可用，五条悟 180 算可用）；有体质 %d 名。' % (
              len(rows), '、'.join(map(str, sorted(released))), sum(1 for r in rows.values() if r['natures'])), '',
          '来源统计：' + '，'.join('%s %d' % (k, v) for k, v in sorted(cnt.items())), '',
          '体质分布：' + '，'.join('%s %d' % (NAMES[e], by[e]) for e in sorted(by)), '']
    if missing:
        md += ['技能卡里找不到基础记录的技能号（未计票）：%s' % '、'.join(map(str, sorted(missing))), '']
    def sect(title, pred, note):
        sel = [r for r in rows.values() if pred(r)]
        out = ['## %s（%d 名）' % (title, len(sel)), '', note, '', '| 号 | 名 | 攻击招数 | 得票 | 结果 | 来源 |', '|---|---|---|---|---|---|']
        for r in sel:
            out.append('| %d | %s | %d | %s | %s | %s%s |' % (r['id'], r['name'], r['n_attack'], fvotes(r['votes']) or '—', fnat(r['natures']), r['src'], ('（并列：' + fnat(r['tie']) + '）') if r['tie'] else ''))
        return out + ['']
    md += sect('一、多元素并列', lambda r: bool(r['tie']), '得票并列最高，取并列类里技能号最小的攻击招所带的那一类。人核看这个顺序是不是合理。')
    md += sect('二、原生是高等三系（无体质）', lambda r: r['src'] == 'higher', '虚空／混沌／空间得票最多，按 4.4 没有体质。')
    md += sect('三、原生无属性（无体质）', lambda r: r['src'] == 'neutral', '无属性（含原物理）得票最多。其中同时带基础十系招的列在得票里，人核看要不要给体质。')
    md += sect('三之二、技能卡还没做、退回原版自带技能的角色', lambda r: r['basis'] == 'original', '这些角色没有天启篇技能卡，按原版角色特性／职业技能表里的攻击招算；技能卡做出来后重跑本脚本。')
    md += sect('四、没有攻击招（无体质）', lambda r: r['src'] == 'no_attack', '技能卡里没有自带攻击招（纯辅助）。')
    mix = [r for r in rows.values() if r['src'] == 'neutral' and any(e in NAMES for e in r['votes'])]
    md += ['## 五、无属性压过元素招的角色（%d 名，三之子集）' % len(mix), '', '| 号 | 名 | 得票 |', '|---|---|---|']
    md += ['| %d | %s | %s |' % (r['id'], r['name'], fvotes(r['votes'])) for r in mix] + ['']
    md += ['## 六、全部可用角色', '', '| 号 | 名 | 体质 | 来源 | 得票 |', '|---|---|---|---|---|']
    md += ['| %d | %s | %s | %s | %s |' % (r['id'], r['name'], fnat(r['natures']), r['src'], fvotes(r['votes']) or '—') for r in rows.values()]
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / '我方差异报告.md').write_text('\n'.join(md) + '\n', encoding='utf-8')


def table_json(rows):
    out = {'version': 1,
           '_doc': '天启篇我方角色自然体质（T484，设计稿 元素独特效果 v0.3 4.4，D285④）。actors 键＝角色号，每个可用角色都有一行；natures 0 或 1 个、基础十系元素号。'
                   'basis：card＝按天启篇技能卡、original＝技能卡还没做的角色退回原版自带技能。src：majority 单类得票最多、tie_first 并列取技能号最小的攻击招、neutral 原生无属性、higher 原生高等三系、no_attack 没有攻击招、manual 人核（要有 verdict）。'
                   'votes 是各元素得票（0＝无属性），tie 是并列最高的元素；只看原生，转换书／转属／装备不改。改规则后重跑 03_转换工具/天启篇我方体质表生成.py。',
           'actors': {}}
    for r in sorted(rows.values(), key=lambda r: r['id']):
        e = {'name': r['name'], 'natures': r['natures'], 'src': r['src'], 'n_attack': r['n_attack'], 'basis': r['basis'],
             'votes': {str(k): v for k, v in sorted(r['votes'].items())}, 'tie': r['tie']}
        if r['src'] == 'manual':
            e['verdict'] = r['verdict']
        out['actors'][str(r['id'])] = e
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--write-table', action='store_true')
    a = ap.parse_args()
    actors, rows, disabled, released, rework, missing = build()
    report(Path(a.out_dir), actors, rows, disabled, released, rework, missing)
    print('可用角色', len(rows), '有体质', sum(1 for r in rows.values() if r['natures']), Counter(r['src'] for r in rows.values()), '缺基础记录', missing)
    if a.write_table:
        OUT_TABLE.write_text(json.dumps(table_json(rows), ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        print('已写', OUT_TABLE.relative_to(HERE.parent))
