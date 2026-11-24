#!/usr/bin/env python3
"""T405：按 T392 波及清单（14 层：7、16、19、22～24、27～34）重跑 T244 4 弱者量数后的对比汇总脚本。
只算纯 4 弱场次（allWeak == True），剔出含强者 128 的原队单列。
同时给出：
1. 14 个波及层：T244 旧表（2 种子） vs 本单重跑前 2 种子（同口径对比） vs 本单 3 种子完整版（含直伤/回合末占比与逐种子分布）；
2. 14 个波及层的四档补偿与段异化关对照；
3. 拼回未波及 20 层后的全 1～34 层分段合计对比（2 种子同口径），明确 T244 各条结论变没变。"""
import json
import statistics as st
from pathlib import Path

HERE = Path(__file__).resolve().parent
T244_DIR = HERE.parent.parent / 'luiluu_t244' / 'T244_量数'
AFFECTED = [7, 16, 19, 22, 23, 24, 27, 28, 29, 30, 31, 32, 33, 34]
NO_ALIEN_FLOORS = [24, 29, 31, 32, 33, 34]


def load_rows(*paths):
    rows = {}
    for p in paths:
        if not Path(p).exists():
            continue
        for r in json.load(open(p))['rows']:
            rows[int(r['floor'])] = r
    return rows


def seed_of(p):
    return int(p['rng']) // 100000


def pure_weak(per, seeds=None):
    out = [x for x in per if x.get('allWeak', True)]
    if seeds is not None:
        out = [x for x in out if seed_of(x) in seeds]
    return out


def mixed(per, seeds=None):
    out = [x for x in per if not x.get('allWeak', True)]
    if seeds is not None:
        out = [x for x in out if seed_of(x) in seeds]
    return out


def wn(per):
    return sum(1 for x in per if x['won']), len(per)


def wan(v):
    v = float(v)
    return f'{v/1e4:.1f}万' if v >= 1e5 else f'{int(round(v))}'


def pct_dir(x):
    return float(x['dmg']) * int(x['turns']) / max(1.0, float(x['enemyHp'])) * 100.0


def pct_end(x):
    return float(x.get('endTurnDmg', 0.0)) * int(x['turns']) / max(1.0, float(x['enemyHp'])) * 100.0


def main():
    old_now = load_rows(T244_DIR / '现行_1-33.json', T244_DIR / '现行_34.json')
    old_33 = load_rows(T244_DIR / '补偿33_22.json')
    old_66 = load_rows(T244_DIR / '补偿66_33.json')
    old_111 = load_rows(T244_DIR / '补偿111_66.json')
    old_na = load_rows(T244_DIR / '现行_段异化关.json')

    new_now = load_rows(HERE / 't244_now.json')
    new_33 = load_rows(HERE / 't244_33_22.json')
    new_66 = load_rows(HERE / 't244_66_33.json')
    new_111 = load_rows(HERE / 't244_111_66.json')
    new_na = load_rows(HERE / 't244_no_alien.json')

    print('# T405 按 T392 波及清单（14 层）重跑 T244 4 弱者量数对比\n')
    print('## 一、14 个波及层逐层对比（纯 4 弱，艰险，现行协力 +12%/−8%）\n')
    print('| 层 | 守层者血（旧→新） | T244 旧（2种） | 新表同口径（种1~2） | **新表全量（3种）** | 新表赢均回合（>3） | 新表秒杀（≤3） | 新表直伤/回合末占比（赢场） | 逐种子胜/场（种1/种2/种3） |')
    print('|---|---|---|---|---|---|---|---|---|')
    for f in AFFECTED:
        orow = old_now[f]
        nrow = new_now[f]
        op = pure_weak(orow['per'])
        np2 = pure_weak(nrow['per'], {1, 2})
        np3 = pure_weak(nrow['per'], {1, 2, 3})
        ow, on = wn(op)
        nw2, nn2 = wn(np2)
        nw3, nn3 = wn(np3)
        wins_gt3 = [x for x in np3 if x['won'] and int(x['turns']) > 3]
        fast = [x for x in np3 if int(x['turns']) <= 3]
        wt = f'{st.mean(x["turns"] for x in wins_gt3):.1f}' if wins_gt3 else '－'
        fast_s = f'{len(fast)}场(赢{sum(1 for x in fast if x["won"])}/输{sum(1 for x in fast if not x["won"])})' if fast else '无'
        all_wins = [x for x in np3 if x['won']]
        ratio_s = (f'{st.mean(pct_dir(x) for x in all_wins):.0f}% / {st.mean(pct_end(x) for x in all_wins):.0f}%') if all_wins else '－'
        by_sd = []
        for sd in (1, 2, 3):
            sp = pure_weak(nrow['per'], {sd})
            sw, sn = wn(sp)
            by_sd.append(f'{sw}/{sn}')
        print(f'| {f} | {wan(orow["enemyHp"])} → {wan(nrow["enemyHp"])} | {ow}/{on} | {nw2}/{nn2} | **{nw3}/{nn3}** | {wt} | {fast_s} | {ratio_s} | {" / ".join(by_sd)} |')

    # 波及 14 层小计（2种 vs 3种）
    ow_s = sum(wn(pure_weak(old_now[f]['per']))[0] for f in AFFECTED)
    on_s = sum(wn(pure_weak(old_now[f]['per']))[1] for f in AFFECTED)
    nw2_s = sum(wn(pure_weak(new_now[f]['per'], {1, 2}))[0] for f in AFFECTED)
    nn2_s = sum(wn(pure_weak(new_now[f]['per'], {1, 2}))[1] for f in AFFECTED)
    nw3_s = sum(wn(pure_weak(new_now[f]['per'], {1, 2, 3}))[0] for f in AFFECTED)
    nn3_s = sum(wn(pure_weak(new_now[f]['per'], {1, 2, 3}))[1] for f in AFFECTED)
    print(f'\n- **14 个波及层现行合计**：T244 旧（2 种子）**{ow_s}/{on_s}（{ow_s/on_s*100:.1f}%）** → 新表同口径（前 2 种子）**{nw2_s}/{nn2_s}（{nw2_s/nn2_s*100:.1f}%，{nw2_s-ow_s:+d}）**；新表 3 种子完整版 **{nw3_s}/{nn3_s}（{nw3_s/nn3_s*100:.1f}%）**。\n')

    # 二、14 层补偿四档 + 段异化关对比（3 种子 + 2 种子同口径）
    print('## 二、14 个波及层补偿四档与段异化关（纯 4 弱）\n')
    print('| 方案 | T244 旧（14层，2种） | 新表同口径（14层，种1~2） | 新表完整（14层，3种） | 3种比现行多赢 / 挽回败局 | 3种按种子（种1/种2/种3） |')
    print('|---|---|---|---|---|---|')
    combos = [
        ('现行 +12%/−8%', old_now, new_now, AFFECTED),
        ('+33%/−22%（九死档）', old_33, new_33, AFFECTED),
        ('+66%/−33%（炼狱档）', old_66, new_66, AFFECTED),
        ('+111%/−66%（证道档）', old_111, new_111, AFFECTED),
        ('现行·段异化关（6层）', old_na, new_na, NO_ALIEN_FLOORS),
    ]
    for lab, od, nd, fls in combos:
        ow = sum(wn(pure_weak(od[f]['per']))[0] for f in fls if f in od)
        on = sum(wn(pure_weak(od[f]['per']))[1] for f in fls if f in od)
        nw2 = sum(wn(pure_weak(nd[f]['per'], {1, 2}))[0] for f in fls if f in nd)
        nn2 = sum(wn(pure_weak(nd[f]['per'], {1, 2}))[1] for f in fls if f in nd)
        nw3 = sum(wn(pure_weak(nd[f]['per'], {1, 2, 3}))[0] for f in fls if f in nd)
        nn3 = sum(wn(pure_weak(nd[f]['per'], {1, 2, 3}))[1] for f in fls if f in nd)
        bw3 = sum(wn(pure_weak(new_now[f]['per'], {1, 2, 3}))[0] for f in fls)
        bn3 = sum(wn(pure_weak(new_now[f]['per'], {1, 2, 3}))[1] for f in fls)
        if lab.startswith('现行 +'):
            diff_s = '－'
        else:
            gain = nw3 - bw3
            losses = bn3 - bw3
            diff_s = f'{gain:+d}（{gain}/{losses}＝{gain/max(1,losses)*100:.0f}%）'
        sds = []
        for sd in (1, 2, 3):
            sw = sum(wn(pure_weak(nd[f]['per'], {sd}))[0] for f in fls if f in nd)
            sn = sum(wn(pure_weak(nd[f]['per'], {sd}))[1] for f in fls if f in nd)
            sds.append(f'{sw}/{sn}')
        print(f'| {lab} | {ow}/{on}（{ow/max(1,on)*100:.1f}%） | {nw2}/{nn2}（{nw2/max(1,nn2)*100:.1f}%） | {nw3}/{nn3}（{nw3/max(1,nn3)*100:.1f}%） | {diff_s} | {" / ".join(sds)} |')

    # 三、拼回未波及 20 层后的全 1~34 层分段合计（2 种子同口径）
    merged = dict(old_now)
    for f in AFFECTED:
        merged[f] = {'floor': f, 'enemyHp': new_now[f]['enemyHp'], 'per': [x for x in new_now[f]['per'] if seed_of(x) in {1, 2}]}
    print('\n## 三、拼回未波及 20 层后的全 1～34 层分段合计（2 种子同口径，纯 4 弱）\n')
    print('| 段 | T244 旧（T363 表） | 合并波及 14 层后（新表＋D273） | 变化 |')
    print('|---|---|---|---|')
    for a, b in ((1, 34), (1, 25), (17, 34), (26, 34), (31, 34)):
        ow = sum(wn(pure_weak(old_now[f]['per']))[0] for f in range(a, b + 1))
        on = sum(wn(pure_weak(old_now[f]['per']))[1] for f in range(a, b + 1))
        nw = sum(wn(pure_weak(merged[f]['per']))[0] for f in range(a, b + 1))
        nn = sum(wn(pure_weak(merged[f]['per']))[1] for f in range(a, b + 1))
        print(f'| {a}～{b} 层 | {ow}/{on}（{ow/on*100:.1f}%） | {nw}/{nn}（{nw/nn*100:.1f}%） | {nw-ow:+d}（{(nw/nn-ow/on)*100:+.1f}pp） |')

    # 四、31~34 层逐层四档补偿详情（3 种子）
    print('\n## 四、14 个波及层逐层补偿与段异化关（3 种子，纯 4 弱）\n')
    print('| 层 | 现行 +12%/−8% | +33%/−22% | +66%/−33% | +111%/−66% | 现行·段异化关 |')
    print('|---|---|---|---|---|---|')
    for f in AFFECTED:
        cells = [str(f)]
        for nd in (new_now, new_33, new_66, new_111):
            w, n = wn(pure_weak(nd[f]['per'], {1, 2, 3}))
            cells.append(f'{w}/{n}')
        if f in new_na:
            w, n = wn(pure_weak(new_na[f]['per'], {1, 2, 3}))
            cells.append(f'{w}/{n}')
        else:
            cells.append('－')
        print('| ' + ' | '.join(cells) + ' |')

    # 五、剔出主表的含强者原队（allWeak=false）单列
    print('\n## 五、剔出主表的场次（上场含强者 128，allWeak=false，3 种子）\n')
    print('| 数据 | 场数 | 胜 | 层 |')
    print('|---|---|---|---|')
    for lab, nd, fls in [('现行', new_now, AFFECTED), ('+33%/−22%', new_33, AFFECTED), ('+66%/−33%', new_66, AFFECTED), ('+111%/−66%', new_111, AFFECTED), ('段异化关', new_na, NO_ALIEN_FLOORS)]:
        ms = [x for f in fls if f in nd for x in mixed(nd[f]['per'], {1, 2, 3})]
        if ms:
            print(f'| {lab} | {len(ms)} | {sum(1 for x in ms if x["won"])} | {min(f for f in fls if mixed(nd[f]["per"]))}～{max(f for f in fls if mixed(nd[f]["per"]))} |')


if __name__ == '__main__':
    main()
