#!/usr/bin/env python3
"""天启篇敌人「自然体质」表生成器（T479 A 卡，设计稿 元素独特效果 v0.3 第 4.1 节）。

  python3 03_再刷重制_Godot/03_转换工具/天启篇体质表生成.py --sample <输出目录>

本版只出**小样**：算出全部随机遭遇敌人的候选体质（名字关键字→种族默认），
按 4.1 的四类各挑 15 只写成 小样.json／小样差异表.md，并按遭遇权重算每系被挡比例（5.4 口径）。
只读 generated/db 与 slice；西游档数据零改动。守层者／鸿钧固定条目（来源 1、2）要按敌人号对表，铺全表时再接。
"""
import argparse
import collections
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
XY = HERE.parent / '01_Godot工程' / 'modes' / 'xiyou'
DB = XY / 'generated' / 'db'

NAMES = {2: '火', 3: '冰', 4: '地', 5: '雷', 6: '自然', 7: '奥', 8: '圣', 9: '暗', 14: '水', 15: '风'}
RACES = {1: '野兽', 2: '亡灵', 3: '人形', 4: '龙族', 5: '元素', 6: '恶魔', 7: '巨人', 8: '灵魂', 9: '植物', 10: '妖精', 11: '机械', 12: '外神', 15: '空名'}
# 关键字表（草稿，顺序即同词命中两系的先后）；人核可判不采纳
KEYWORDS = [
    ('熔岩', [2, 4]), ('岩浆', [2, 4]), ('火', [2]), ('炎', [2]), ('焰', [2]), ('烈', [2]), ('炽', [2]), ('焚', [2]), ('烬', [2]),
    ('冰', [3]), ('霜', [3]), ('寒', [3]), ('雪', [3]),
    ('岩', [4]), ('石', [4]), ('土', [4]), ('沙', [4]), ('泥', [4]), ('矿', [4]),
    ('雷', [5]), ('电', [5]), ('霹', [5]),
    ('草', [6]), ('树', [6]), ('藤', [6]), ('花', [6]), ('菇', [6]), ('林', [6]),
    ('水', [14]), ('海', [14]), ('鱼', [14]), ('蟹', [14]), ('龟', [14]), ('蛙', [14]), ('浪', [14]), ('河', [14]), ('章鱼', [14]), ('水母', [14]),
    ('风', [15]), ('鹰', [15]), ('翼', [15]), ('羽', [15]), ('云', [15]), ('蝠', [15]),
    ('奥', [7]), ('法师', [7]), ('魔法', [7]), ('符', [7]),
    ('圣', [8]), ('光', [8]), ('天使', [8]), ('辉', [8]),
    ('暗', [9]), ('夜', [9]), ('影', [9]), ('幽', [9]), ('冥', [9]), ('血', [9]),
]
NAME_EXCLUDE = ('木桩',)  # 训练木桩不给体质
PREFIX = re.compile(r'^(【[^】]*】)+')


def load():
    enemies = {x['id']: x for x in json.load(open(DB / 'Enemies.json')) if x}
    troops = {x['id']: x for x in json.load(open(DB / 'Troops.json')) if x}
    aff = json.load(open(DB / 'CodexDamageElements.json'))['affinities']['enemies']
    return enemies, troops, aff


def encounter_weights(troops):
    """每张图内按 troop 权重归一，再按图平均：遭遇权重＝某敌人出现在随机遭遇里的份额。"""
    sl = json.load(open(XY / 'generated' / 'slice.json'))
    maps = sl['maps'] if isinstance(sl['maps'], list) else eval(sl['maps'])
    per = collections.Counter()
    n_maps = 0
    for m in maps:
        p = XY / 'generated' / 'maps' / ('Map%03d.json' % m)
        if not p.exists():
            continue
        enc = json.load(open(p)).get('encounterList') or []
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
    return {k: v / n_maps for k, v in per.items()}, n_maps


def info(x):
    note = x['note']
    races = [int(n) for r in re.findall(r'<EnemyRace:\s*([\d, ]+)>', note) for n in r.split(',')]
    absorb = [int(n) for r in re.findall(r'<Element Absorb:\s*([\d, ]+)>', note) for n in r.split(',')]
    return races, absorb


def derive(x):
    """4.1 来源 3、4（来源 1、2 按敌人号对守层者／鸿钧表，铺全表时接）。返回 (体质列表, 来源, 命中词)。"""
    races, _ = info(x)
    name = PREFIX.sub('', x['name'])
    if any(k in x['name'] for k in NAME_EXCLUDE):
        return [], '排除', ''
    hits = []
    for kw, els in KEYWORDS:
        pos = name.find(kw)
        if pos >= 0:
            hits.append((pos, len(hits), kw, els))
    hits.sort()
    out, kws = [], []
    for _, _, kw, els in hits:
        for e in els:
            if e not in out:
                out.append(e)
                kws.append(kw)
        if len(out) >= 2:
            break
    if out:
        return out[:2], '关键字', '、'.join(kws[:2])
    if 9 in races:
        return [6], '种族', '植物族'
    return [], '无', ''


# 4.2 矩阵：效果行 → 体质免疫列表／种族免疫（敌方受者）
BLOCK = {'火·灼烧': {2, 4, 14}, '冰·迟缓': {2, 3}, '地·碎甲': {4}, '雷·麻痹': {4, 5}, '自然·寄生': {6},
         '水·浸湿': {14}, '风·乱流': {15}, '奥·魔蚀': {7}, '黑暗·遮蔽锋芒': {8, 9}}
RACE_BLOCK = {'自然·寄生': {2, 11}, '风·乱流': {7}}


def write_sample(outdir: Path):
    enemies, troops, aff = load()
    w, n_maps = encounter_weights(troops)
    rows = {}
    for i, x in enemies.items():
        races, absorb = info(x)
        nat, src, kw = derive(x)
        rows[i] = dict(id=i, name=x['name'], races=races, absorb=absorb, aff=[a for a in aff.get(str(i), []) if a in NAMES],
                       nat=nat, src=src, kw=kw, w=w.get(i, 0.0))
    enc = [r for r in rows.values() if r['w'] > 0]
    total = sum(r['w'] for r in enc)
    # 被挡比例（首领单列：名字带【首领】等的；随机遭遇里本来很少）
    def is_boss(n):
        return any(t in n for t in ('【首领', '【守层者', '【精英', '【被封印者', '【宗师', '【前所未见', '【亘古未有'))
    cov = {}
    for eff, bl in BLOCK.items():
        for grp, sel in (('普通', lambda r: not is_boss(r['name'])), ('首领等', lambda r: is_boss(r['name']))):
            part = [r for r in enc if sel(r)]
            ptot = sum(r['w'] for r in part) or 1
            hit = sum(r['w'] for r in part if (set(r['nat']) & bl) or (set(r['races']) & RACE_BLOCK.get(eff, set())))
            cov[(eff, grp)] = hit / ptot
    picks = {}
    by_w = sorted(rows.values(), key=lambda r: -r['w'])
    pool = [r for r in by_w if r['w'] > 0 or True]
    def take(cond, n=15):
        out, seen = [], set()
        for r in by_w:
            if cond(r) and r['name'] not in seen:
                seen.add(r['name'])
                out.append(r)
            if len(out) >= n:
                break
        return out
    picks['1 西游体质含水／风／地'] = take(lambda r: r['w'] > 0 and set(r['aff']) & {14, 15, 4})
    picks['2 吸收与西游体质冲突'] = take(lambda r: r['w'] > 0 and r['absorb'] and set(r['absorb']) != set(r['aff']))
    cnt = collections.Counter(r['name'] for r in rows.values())
    dup = [n for n in dict.fromkeys(r['name'] for r in by_w if r['w'] > 0 and cnt[r['name']] > 1)][:6]
    picks['3 同名多记录（含无遭遇的同名号）'] = [r for r in sorted(rows.values(), key=lambda r: (dup.index(r['name']) if r['name'] in dup else 99, r['id'])) if r['name'] in dup]
    picks['4 都没命中（留空）'] = take(lambda r: r['w'] > 0 and not r['nat'])
    outdir.mkdir(parents=True, exist_ok=True)
    sample = {'version': 0, '_doc': '小样，格式见 小样差异表.md「字段约定」；enemies 键＝敌人号字符串',
              'enemies': {}}
    md = ['# T479 A 卡小样：天启篇敌人体质', '',
          '遭遇权重口径：切片内每张地图的 `encounterList` 按权重归一→队伍里每只成员均分→全部 %d 张有遭遇的地图取平均。有遭遇权重的敌人 %d 只（共 %d 条敌人记录）。' % (n_maps, len(enc), len(rows)), '']
    ALLN = {1: '物理', 10: '治疗', 11: '虚空', 12: '混沌', 13: '空间', **NAMES}
    def f(l, m=None):
        m = m or ALLN
        return '、'.join(m.get(x, str(x)) for x in l) or '—'
    for title, lst in picks.items():
        md += ['## 类 ' + title, '', '| 号 | 名 | 权重‰ | 种族 | 西游体质 | 吸收 | 新体质（来源／词） | 人核建议 |', '|---|---|---|---|---|---|---|---|']
        for r in lst:
            sug = ''
            if r['nat'] and r['aff'] and set(r['nat']) == set(r['aff']):
                sug = '一致'
            elif r['nat'] and set(r['nat']) & set(r['aff']):
                sug = '部分重合'
            elif r['nat']:
                sug = '待核：与西游体质不同'
            elif r['aff']:
                sug = '待核：西游有体质、新表空'
            else:
                sug = '留空合理' if not r['absorb'] else '待核：有吸收标签'
            md.append('| %d | %s | %.2f | %s | %s | %s | %s | %s |' % (
                r['id'], r['name'], r['w'] * 1000, f(r['races'], RACES), f(r['aff']), f(r['absorb']),
                (f(r['nat']) + '（' + r['src'] + ('／' + r['kw'] if r['kw'] else '') + '）') if r['nat'] else '— (' + r['src'] + ')', sug))
            sample['enemies'][str(r['id'])] = {'natures': r['nat'], 'src': {'关键字': 'keyword', '种族': 'race'}.get(r['src'], 'none'),
                                               'hit': r['kw'], 'xiyou_affinity': r['aff'], 'absorb': r['absorb'], 'verdict': ''}
        md.append('')
    md += ['## 覆盖口径预览（5.4：每系 ≤ 20%）', '',
           '被挡比例＝遭遇权重里「体质（或敌方种族，4.2）使该效果免疫」的占比；首领等（名字带【首领】【守层者】等，随机遭遇里本来就少）单列。全表未铺，下列是**仅关键字＋植物族**的预览，守层者／鸿钧条目未接。', '',
           '| 效果 | 普通遭遇 | 首领等 | ≤20%？ |', '|---|---|---|---|']
    for eff in BLOCK:
        a, b = cov[(eff, '普通')], cov[(eff, '首领等')]
        md.append('| %s | %.1f%% | %.1f%% | %s |' % (eff, a * 100, b * 100, '✓' if a <= 0.2 else '✗'))
    md.append('')
    (outdir / '小样.json').write_text(json.dumps(sample, ensure_ascii=False, indent=1), encoding='utf-8')
    (outdir / '小样差异表.md').write_text('\n'.join(md), encoding='utf-8')
    print('有遭遇权重的敌人', len(enc), '地图', n_maps, '小样条数', len(sample['enemies']))
    for eff in BLOCK:
        print(eff, '%.1f%%' % (cov[(eff, '普通')] * 100), '%.1f%%' % (cov[(eff, '首领等')] * 100))
    return sum(1 for r in enc if r['nat']), len(enc)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--sample', required=True, help='小样输出目录')
    a = ap.parse_args()
    print(write_sample(Path(a.sample)))
