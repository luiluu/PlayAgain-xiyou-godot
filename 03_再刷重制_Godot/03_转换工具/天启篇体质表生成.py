#!/usr/bin/env python3
"""天启篇敌人「自然体质」表生成器（T479 A 卡，设计稿 元素独特效果 v0.3 第 4.1 节；Opus 小样裁定 T479_小样裁定.md）。

  python3 03_再刷重制_Godot/03_转换工具/天启篇体质表生成.py --out-dir <差异表目录> [--write-table]

- 只读 generated/db、slice、maps、core/zhenqi.gd（GUARDIANS）、core/guardian_rework.gd（TROOPS）、tianqi_data/elements_table.json；
  西游档数据零改动。`--write-table` 才写 tianqi_data/enemy_nature.json。
- 范围：天启篇打得到的敌人＝随机遭遇（encounterList）＋切片地图事件里直接开的战斗（301）＋守层者；其余不写条目（缺省＝无体质）。
- 来源顺序（4.1，去重取前 2）：1 守层者本层体质（XGuardianRework.guardian_floor 口径：TROOPS 里名字含「守层者」的成员）
  2 鸿钧（special.hongjun，按身份取）3 名字关键字 4 植物族→自然。骑士硬留空。
- 西游旧体质、吸收标签只当证据，不采纳；外神全元素吸收留空；关键字改动直接改本文件上面的表，不在代码里散写例外。
- 遮蔽锋芒首领线偏高待 Kyo 定：开关 GUARDIAN_TAKE（2＝照甲，守层者取前 2 个体质；1＝乙，只取第 1 个），写进表的 guardian_take 字段。
"""
import argparse
import ast
import collections
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
XY = HERE.parent / '01_Godot工程' / 'modes' / 'xiyou'
DB = XY / 'generated' / 'db'
OUT_TABLE = XY / 'tianqi_data' / 'enemy_nature.json'

GUARDIAN_TAKE = 2
NAMES = {2: '火', 3: '冰', 4: '地', 5: '雷', 6: '自然', 7: '奥', 8: '圣', 9: '暗', 14: '水', 15: '风'}
ALLN = {1: '物理', 10: '治疗', 11: '虚空', 12: '混沌', 13: '空间', **NAMES}
RACES = {1: '野兽', 2: '亡灵', 3: '人形', 4: '龙族', 5: '元素', 6: '恶魔', 7: '巨人', 8: '灵魂', 9: '植物', 10: '妖精', 11: '机械', 12: '外神', 15: '空名'}

# 关键字表（Opus 裁定 11-25）；同词命中两系按此处写的顺序；位置先后在 derive 里排
KEYWORDS = [
    ('熔岩', [2, 4]), ('岩浆', [2, 4]), ('火', [2]), ('炎', [2]), ('焰', [2]), ('炽', [2]), ('焚', [2]), ('烬', [2]),
    ('冰', [3]), ('霜', [3]), ('寒', [3]), ('雪', [3]),
    ('岩', [4]), ('土', [4]), ('泥', [4]), ('矿', [4]), ('石', [4]), ('沙漠', [4]), ('流沙', [4]), ('沙虫', [4]),
    ('地底', [4]), ('雕像', [4]), ('山神', [4]),
    ('雷', [5]), ('电', [5]), ('霹', [5]),
    ('草', [6]), ('树', [6]), ('藤', [6]), ('花', [6]), ('菇', [6]),
    ('水母', [14]), ('章鱼', [14]), ('水', [14]), ('海', [14]), ('鱼', [14]), ('蟹', [14]), ('龟', [14]), ('蛙', [14]),
    ('浪', [14]), ('河', [14]), ('鳄', [14]), ('亚特兰蒂斯', [14]),
    ('风', [15]), ('翼', [15]), ('羽', [15]), ('蝠', [15]), ('鹰', [15]), ('云', [15]),
    ('奥术', [7]), ('魔晶', [7, 14]),
    ('天使', [8]), ('辉', [8]), ('神圣', [8]), ('圣光', [8]), ('圣骑', [8]), ('光明', [8]),
    ('暗', [9]), ('幽', [9]), ('冥', [9]),
]
# 排除短语：把这些片段从名字里抹掉再找词（不是体质的常见写法）
EXCLUDE_PHRASES = ['发火', '采石', '寻石', '碎石', '研究鱼人的']
LOW_TRUST = {'鹰', '龟', '云'}           # 命中进人核
NAME_EXCLUDE = ('木桩',)                 # 训练木桩不给体质
PREFIX = re.compile(r'^(【[^】]*】)+')
QUOTED = re.compile(r'["“「][^"”」]*["”」]')


def load():
    enemies = {x['id']: x for x in json.load(open(DB / 'Enemies.json')) if x}
    troops = {x['id']: x for x in json.load(open(DB / 'Troops.json')) if x}
    aff = json.load(open(DB / 'CodexDamageElements.json'))['affinities']['enemies']
    table = json.load(open(XY / 'tianqi_data' / 'elements_table.json'))
    return enemies, troops, aff, table


def parse_const(path: Path, name: str):
    """解析 .gd 里的 const NAME := {…}（可跨行）为 Python 字典，不手抄。"""
    text = path.read_text(encoding='utf-8')
    m = re.search(r'^const %s\s*:?=\s*(\{.*?\})\s*$' % name, text, re.S | re.M)
    if not m:
        raise SystemExit('读不到 %s 的 %s' % (path.name, name))
    return ast.literal_eval(re.sub(r'#.*', '', m.group(1)))


def guardian_floors(enemies, troops):
    """守层者敌人号→本层。先按 XGuardianRework.TROOPS（每层一场）取，再把 zhenqi.GUARDIANS 里别的敌群（如 5 层第二场 245、地图 062 EV004）也遍历，
    双向核对：TROOPS 的每一场都在 GUARDIANS 里且层号一致；GUARDIANS 里多出的敌群记在 extra_troops 报告（guardian_rework.floor_of 只认 TROOPS，漏认这几场，不改游戏代码，见交付单）。"""
    tr = parse_const(XY / 'core' / 'guardian_rework.gd', 'TROOPS')
    gd = parse_const(XY / 'core' / 'zhenqi.gd', 'GUARDIANS')
    for f, tid in tr.items():
        assert gd.get(tid) == f, 'TROOPS 的 %s 层敌群 %s 与 GUARDIANS 层号对不上' % (f, tid)
    extra = {tid: f for tid, f in gd.items() if tid not in set(tr.values())}
    out = {}
    for tid, f in sorted(gd.items(), key=lambda kv: (kv[1], kv[0] not in set(tr.values()), kv[0])):  # 同层先 TROOPS 的那场
        for m in troops[tid]['members']:
            e = enemies.get(m['enemyId'])
            if e and '守层者' in e['name'] and m['enemyId'] not in out:
                out[m['enemyId']] = int(f)
    global EXTRA_TROOPS
    EXTRA_TROOPS = extra
    return out, tr


EXTRA_TROOPS = {}


def encounter_weights(troops):
    """每张图内 encounterList 按权重归一，队伍成员均分，再按有遭遇的图取平均。另扫地图事件里直接开的战斗（301）。"""
    sl = json.load(open(XY / 'generated' / 'slice.json'))
    maps = sl['maps'] if isinstance(sl['maps'], list) else ast.literal_eval(sl['maps'])
    per = collections.Counter()
    n_maps = 0
    event_enemies = set()
    for mid in maps:
        p = XY / 'generated' / 'maps' / ('Map%03d.json' % mid)
        if not p.exists():
            continue
        data = json.load(open(p))
        for ev in data.get('events') or []:
            for pg in (ev or {}).get('pages', []):
                for c in pg.get('list', []):
                    if c['code'] == 301 and c['parameters'][0] == 0:
                        t = troops.get(c['parameters'][1])
                        if t:
                            event_enemies |= {m['enemyId'] for m in t['members']}
        enc = data.get('encounterList') or []
        tot = sum(e['weight'] for e in enc)
        if not tot:
            continue
        n_maps += 1
        for e in enc:
            t = troops.get(e['troopId'])
            if not t or not t['members']:
                continue
            share = e['weight'] / tot / len(t['members'])
            for mem in t['members']:
                per[mem['enemyId']] += share
    return {k: v / n_maps for k, v in per.items()}, n_maps, event_enemies


def info(x):
    note = x['note']
    races = [int(n) for r in re.findall(r'<EnemyRace:\s*([\d, ]+)>', note) for n in r.split(',')]
    absorb = [int(n) for r in re.findall(r'<Element Absorb:\s*([\d, ]+)>', note) for n in r.split(',')]
    return races, absorb


def keyword_hits(name):
    """返回 [(位置, 词, 元素列表, 是否只在引号里)]，按位置先后、同位置按表序。"""
    clean = PREFIX.sub('', name)
    for ph in EXCLUDE_PHRASES:
        clean = clean.replace(ph, '·' * len(ph))
    quoted = [(m.start(), m.end()) for m in QUOTED.finditer(clean)]
    hits = []
    for order, (kw, els) in enumerate(KEYWORDS):
        pos = clean.find(kw)
        if pos >= 0:
            hits.append((pos, order, kw, els, any(a <= pos < b for a, b in quoted)))
    hits.sort(key=lambda h: (h[0], h[1]))
    return hits


def derive(x, floor=0, constits=None):
    """返回 dict(natures, src, hit, flags)。守层者本层体质先到先得，不够再接关键字、种族；外神全元素吸收留空。"""
    races, absorb = info(x)
    nat, srcs, kws, flags = [], [], [], []
    if any(k in x['name'] for k in NAME_EXCLUDE):
        return dict(natures=[], src='none', hit='', flags=['排除'])
    if 12 in races and len(set(absorb) & set(NAMES)) >= 3:
        return dict(natures=[], src='none', hit='', flags=['外神全元素吸收留空'])
    if floor:
        g = (constits or {}).get(str(floor), [])
        for e in g[:GUARDIAN_TAKE]:
            if e in NAMES and e not in nat:
                nat.append(e)
                srcs.append('guardian')
        if nat:  # 本层有体质条目就以它为准，不再接关键字（Opus 裁定：照本层前 N 个）；本层没有条目才往下走
            return dict(natures=nat[:2], src='guardian', hit='', flags=[])
    hits = keyword_hits(x['name'])
    for pos, order, kw, els, inq in hits:
        for e in els:
            if e not in nat and len(nat) < 2:
                nat.append(e)
                srcs.append('keyword')
                kws.append(kw)
        if inq:
            flags.append('引号绰号:' + kw)
        if kw in LOW_TRUST:
            flags.append('低信:' + kw)
    if not nat and 9 in races:
        nat, srcs, kws = [6], ['race'], ['植物族']
    src = srcs[0] if len(set(srcs)) == 1 else ('+'.join(dict.fromkeys(srcs)) if srcs else 'none')
    return dict(natures=nat[:2], src=src, hit='、'.join(kws[:2]), flags=flags)


# 4.2 矩阵：效果行 → 体质免疫列表／种族免疫（敌方受者）
BLOCK = {'火·灼烧': {2, 4, 14}, '冰·迟缓': {2, 3}, '地·碎甲': {4}, '雷·麻痹': {4, 5}, '自然·寄生': {6},
         '水·浸湿': {14}, '风·乱流': {15}, '奥·魔蚀': {7}, '黑暗·遮蔽锋芒': {8, 9}}
RACE_BLOCK = {'自然·寄生': {2, 11}, '风·乱流': {7}}

# 人核覆盖（人判名字有没有这个元素意象，不看西游体质值）：id→(体质列表, 理由)；src 记 manual，verdict 必填
_NO = {276: '陆龟意象', 277: '陆龟意象', 282: '陆龟意象', 318: '「巨龟」绰号无法判是水龟', 363: '旋龟种类不明',
       381: '「黄金鹰」是人名绰号', 442: '「盗火者」是神话称号不是火身', 492: '云锦是人名', 561: '夜云是人名',
       549: '龟儿种类不明', 550: '龟父种类不明'}
# 引号外的音译人名／真人名撞字（T479 返修 R2 P2-1）：名字里的「雷／海／风／羽」不是元素意象，逐条手工覆盖为空
_NAME_CLASH = {98: '普雷西是音译人名，「雷」不是雷', 100: '格雷果是音译人名，「雷」不是雷', 331: '葛雷果是音译人名，「雷」不是雷',
               54: '范海辛是人名（吸血鬼猎人），「海」不是水', 430: '巴风特是音译名，「风」不是风', 434: '巴风特是音译名，「风」不是风',
               880: '关羽是人名，「羽」不是风', 924: '海拉是北欧死亡女神的音译，「海」不是水，没有独立的水意象',
               174: '海拉的幻影随海拉，「海」不是水', 175: '海拉的幻影随海拉，「海」不是水'}
MANUAL = {i: ([], '不采纳：' + why) for i, why in {**_NO, **_NAME_CLASH}.items()}
# 人核清单里没覆盖的就是采纳（名字有元素意象）：烈焰、冰霜、人鱼公主、魔晶龟、火皮、死亡之风、邪鳄、刃羽鹰、熔岩巨龟、龟丞相
REVIEW_OK = {34, 35, 141, 280, 321, 342, 357, 378, 379, 438, 439, 604}


def build():
    enemies, troops, aff, table = load()
    w, n_maps, ev_en = encounter_weights(troops)
    gfloor, tr = guardian_floors(enemies, troops)
    constits = table['guardian_constitutions']
    scope = set(w) | ev_en | set(gfloor)
    rows = {}
    for i in sorted(scope):
        x = enemies.get(i)
        if not x:
            continue
        races, absorb = info(x)
        d = derive(x, gfloor.get(i, 0), constits)
        if i in MANUAL:
            d = dict(natures=MANUAL[i][0], src='manual', hit='', flags=d['flags'])
        rows[i] = dict(id=i, name=x['name'], races=races, absorb=absorb, aff=[a for a in aff.get(str(i), []) if a in NAMES],
                       w=w.get(i, 0.0), floor=gfloor.get(i, 0), **d)
    return enemies, rows, n_maps, ev_en, gfloor, tr, table


def blocked(nat, races, eff):
    return bool(set(nat) & BLOCK[eff]) or bool(set(races) & RACE_BLOCK.get(eff, set()))


def fnat(l, m=None):
    return '、'.join((m or ALLN).get(x, str(x)) for x in l) or '—'


def report(outdir: Path, enemies, rows, n_maps, ev_en, gfloor, tr, table):
    enc = [r for r in rows.values() if r['w'] > 0]
    total = sum(r['w'] for r in enc)
    md = ['# T479 A 卡：天启篇敌人体质表差异报告', '',
          '范围：随机遭遇敌人 %d 只（%d 张有遭遇的地图 encounterList 权重，队伍成员均分）；另有切片事件直接开的战斗里的敌人 %d 只，守层者 %d 只（含无遭遇者）；表内敌人共 %d 只，其中有体质的 %d 只。西游旧体质、吸收标签只当证据，不采纳。' % (
              len(enc), n_maps, len(ev_en), len(gfloor), len(rows), sum(1 for r in rows.values() if r['natures'])), '',
          '## 一、覆盖口径（5.4，每系 ≤ 20%，两条线分开报）', '',
          '- **普通线**：随机遭遇敌人（含各种稀有度前缀），按遭遇权重。',
          '- **首领线**：33 层守层者＋鸿钧每层 1 份（共 34 份，身份口径同 4.3 `effect_boss`），守层者取本层前 %d 个体质（开关 `guardian_take`）；骑士体质留空不计入被挡；七印副本首领体质为空，只报不判线。' % GUARDIAN_TAKE, '']
    hong = table['fixed_entries']['hongjun']['constitutions']
    boss = [r['natures'] for r in rows.values() if r['floor']]
    # 每层 1 份：同层多个号只取该层第一个号
    seen, per_floor = set(), []
    for r in sorted((r for r in rows.values() if r['floor']), key=lambda r: (r['floor'], r['id'])):
        if r['floor'] not in seen:
            seen.add(r['floor'])
            per_floor.append(r)
    md += ['| 效果 | 普通线 | 首领线（34 份） | 普通≤20% | 首领≤20% |', '|---|---|---|---|---|']
    for eff in BLOCK:
        a = sum(r['w'] for r in enc if blocked(r['natures'], r['races'], eff)) / total
        n_b = sum(1 for r in per_floor if blocked(r['natures'], r['races'], eff)) + (1 if blocked(hong, [], eff) else 0)
        b = n_b / (len(per_floor) + 1)
        md.append('| %s | %.1f%% | %.1f%% | %s | %s |' % (eff, a * 100, b * 100, '✓' if a <= .2 else '✗', '✓' if b <= .2 else '✗（守层者体质决定，不调关键字；交数值线）'))
    md += ['', '首领线每层 1 份，守层者共 %d 层有记录，鸿钧体质 %s。' % (len(per_floor), fnat(hong)), '']
    md += ['`zhenqi.GUARDIANS` 里不在 `guardian_rework.TROOPS` 的守层者敌群（生成器已遍历，`guardian_rework.floor_of` 漏认，B 接线须对齐）：%s。' % (
        '、'.join('敌群 %d＝%d 层' % kv for kv in sorted(EXTRA_TROOPS.items())) or '无'), '']
    # 旧体质归类
    cls = collections.Counter()
    for r in enc:
        n, a = set(r['natures']), set(r['aff'])
        k = ('两边都空' if not n and not a else '只有西游' if not n else '只有新表' if not a else '新旧一致' if n == a else '部分重合' if n & a else '完全不同')
        cls[k] += 1
    md += ['## 二、与西游旧体质的归类（普通线 %d 只）' % len(enc), '', '| 类 | 只数 | 处理 |', '|---|---|---|']
    how = {'新旧一致': '照新表', '两边都空': '留空', '只有新表': '新表说了算，引号绰号／低信词进人核', '部分重合': '同上', '完全不同': '同上', '只有西游': '不采纳，留空'}
    for k in how:
        md.append('| %s | %d | %s |' % (k, cls[k], how[k]))
    # 词命中表
    kwhit = collections.defaultdict(list)
    for r in rows.values():
        for pos, order, kw, els, inq in keyword_hits(r['name']):
            kwhit[kw].append(r['name'])
    md += ['', '## 三、词命中表（词只算「命中」，是否进体质看位置与前 2 名额）', '', '| 词 | 命中数 | 名单（前 6） |', '|---|---|---|']
    for kw, _ in KEYWORDS:
        if kwhit.get(kw):
            names = list(dict.fromkeys(kwhit[kw]))
            md.append('| %s | %d | %s |' % (kw, len(kwhit[kw]), '、'.join(names[:6])))
    # 人核清单
    review = [r for r in rows.values() if r['flags'] and any(f.startswith(('引号', '低信')) for f in r['flags'])]
    md += ['', '## 四、人核清单（引号绰号命中／低信词命中，共 %d 只；人判名字有无元素意象，不看西游体质）' % len(review), '',
           '| 号 | 名 | 现体质 | 触发 | 人判 |', '|---|---|---|---|---|']
    for r in review:
        md.append('| %d | %s | %s | %s | %s |' % (r['id'], r['name'], fnat(r['natures']) if r['src'] != 'manual' else '— （原 ' + fnat(derive(enemies[r['id']])['natures']) + '）', '、'.join(r['flags']), '采纳' if r['id'] in REVIEW_OK else MANUAL.get(r['id'], ([], '待人判'))[1]))
    md += ['', '## 五、手工覆盖（src: manual，共 %d 条）' % len(MANUAL), '', '| 号 | 名 | 体质 | 理由 |', '|---|---|---|---|']
    for i, (nat, why) in MANUAL.items():
        md.append('| %d | %s | %s | %s |' % (i, enemies[i]['name'], fnat(nat), why))
    md += ['', '## 六、有体质的条目（表内全部，按权重降序）', '', '| 号 | 名 | 权重‰ | 层 | 体质（来源／词） |', '|---|---|---|---|---|']
    for r in sorted(rows.values(), key=lambda r: -r['w']):
        if r['natures']:
            md.append('| %d | %s | %.2f | %s | %s（%s%s） |' % (r['id'], r['name'], r['w'] * 1000, r['floor'] or '', fnat(r['natures']), r['src'], '／' + r['hit'] if r['hit'] else ''))
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / '差异报告.md').write_text('\n'.join(md) + '\n', encoding='utf-8')
    return review


def table_json(rows, enemies, table):
    out = {'version': 1,
           '_doc': '天启篇敌人自然体质（T479，设计稿 元素独特效果 v0.3 4.1）。enemies 键＝敌人号；缺省＝无体质；natures 0～2 个、基础十系元素号。'
                   '守层者条目 src=guardian 带 floor；鸿钧、骑士走 special（按战斗身份取，不按敌人号）。xiyou_affinity／absorb 只是证据，代码不读。'
                   '遮蔽锋芒首领线偏高待 Kyo 定：guardian_take 2＝守层者取前 2 个体质，1＝只取第 1 个，改它后重跑生成器。',
           'guardian_take': GUARDIAN_TAKE,
           'special': {'hongjun': {'natures': table['fixed_entries']['hongjun']['constitutions'], 'src': 'hongjun'},
                       'knight': {'natures': [], 'src': 'none'}},
           'enemies': {}}
    for r in sorted(rows.values(), key=lambda r: r['id']):
        if not r['natures']:
            continue
        e = {'natures': r['natures'], 'src': r['src'], 'hit': r['hit'], 'xiyou_affinity': r['aff'], 'absorb': [a for a in r['absorb']]}
        if r['floor']:
            e['floor'] = r['floor']
        if r['src'] == 'manual':
            e['verdict'] = MANUAL[r['id']][1]
        out['enemies'][str(r['id'])] = e
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--write-table', action='store_true')
    a = ap.parse_args()
    enemies, rows, n_maps, ev_en, gfloor, tr, table = build()
    review = report(Path(a.out_dir), enemies, rows, n_maps, ev_en, gfloor, tr, table)
    print('表内敌人', len(rows), '有体质', sum(1 for r in rows.values() if r['natures']), '人核', len(review))
    if a.write_table:
        OUT_TABLE.write_text(json.dumps(table_json(rows, enemies, table), ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        print('已写', OUT_TABLE.relative_to(HERE.parent))
