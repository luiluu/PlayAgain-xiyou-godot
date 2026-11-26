# T527：T445 炼狱探针（T501 口径）JSON → 每人峰值（显示／等效）、D148 三档、超÷弱、循环里最大一类招与最大一个系的占比。
# 用法：python3 峰值汇总.py <目录> [<对照目录>]   目录里放 s1.json s2.json s3.json
import json, sys, os, re, statistics
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '../../../../..'))
DB = os.path.join(ROOT, '03_再刷重制_Godot/01_Godot工程/modes/xiyou')
HP = 0.4  # enemy_hp_pct 40%：等效＝显示÷0.4（T501 R2）
D148 = {'超强者': (2520000, 3480000), '强者': (1490000, 2250000), '弱者': (750000, 1250000)}
SK = {x['id']: x for x in json.load(open(os.path.join(DB, 'generated/db/Skills.json'))) if x}
RW = json.load(open(os.path.join(DB, 'tianqi_data/skill_rework.json')))['skills']
ELEM = json.load(open(os.path.join(DB, 'generated/db/System.json')))['elements']

def peak(r):  # 同 T501 K交集.py：179 流萤取不含随机再放
    return r['peak_base'] if r['actor'] == 179 else r['peak']

def kind(sid):
    k = str(RW.get(str(sid), {}).get('kind', '')) or '（未进改写表）'
    return re.sub(r'(全体|随机)$', '', k)

def elem(sid):
    rw = RW.get(str(sid), {})
    e = rw.get('element', SK.get(sid, {}).get('damage', {}).get('elementId', 0))
    if isinstance(e, list): e = e[0] if e else 0
    e = int(e)
    return '普攻属性' if e == -1 else (ELEM[e] if 0 <= e < len(ELEM) and ELEM[e] else '无属性（0 号）')

def load(d):
    return {s: json.load(open(os.path.join(d, f's{s}.json'))) for s in (1, 2, 3) if os.path.exists(os.path.join(d, f's{s}.json'))}

def summarize(d, label):
    runs = load(d)
    print(f'## {label}（{d}）')
    for s, j in runs.items():
        print(f"种子 {s}：k={j['k']} rows={len(j['rows'])} missing={j.get('missing')} 违规={sum(r.get('ledger_violations',0) for r in j['rows'])}")
        tops = {}
        for t, (lo, hi) in D148.items():
            rs = [r for r in j['rows'] if r['tier'] == t]
            m = max(rs, key=peak); M = peak(m); E = M / HP
            tops[t] = E
            ok = '过' if lo <= E <= hi else ('低' if E < lo else '高')
            print(f"  {t} 顶 {m['actor']} {m.get('skill_name','')} 显示 {M:,} 等效 {E:,.0f} D148[{lo:,}~{hi:,}] {ok}")
        print(f"  超÷弱 {tops['超强者']/tops['弱者']:.2f}×（硬线 3.5）")
    return runs

def per_actor(runs):
    ids = sorted({r['actor'] for j in runs.values() for r in j['rows']}, key=lambda a: [r for r in runs[1]['rows'] if r['actor']==a][0]['tier'] if 1 in runs else '')
    out = []
    for a in ids:
        rows = {s: next(r for r in j['rows'] if r['actor'] == a) for s, j in runs.items() if any(r['actor']==a for r in j['rows'])}
        r1 = next(iter(rows.values()))
        cp = list(r1.get('lianyu', {}).get('cast_peaks', []))
        if r1.get('skill') and not any(c['skill'] == r1['skill'] for c in cp):  # 峰值来自变招／编组探针时，峰值招不在 cast_peaks 里，补进循环
            cp.append({'skill': r1['skill'], 'peak': r1['peak']})
        cyc = sum(c['peak'] for c in cp)
        byk, bye = {}, {}
        for c in cp:
            byk[kind(c['skill'])] = byk.get(kind(c['skill']), 0) + c['peak']
            bye[elem(c['skill'])] = bye.get(elem(c['skill']), 0) + c['peak']
        kk = max(byk.items(), key=lambda x: x[1]) if byk else ('—', 0)
        ee = max(bye.items(), key=lambda x: x[1]) if bye else ('—', 0)
        out.append(dict(actor=a, tier=r1['tier'], peaks=[peak(rows[s]) for s in sorted(rows)], skill=r1.get('skill_name'), brand=r1.get('brand_mult'),
                        n_cast=len(cp), cycle=cyc, kind=kk[0], kind_pct=100*kk[1]/cyc if cyc else None, elem=ee[0], elem_pct=100*ee[1]/cyc if cyc else None,
                        kinds=byk, elems=bye))
    return out

if __name__ == '__main__':
    runs = summarize(sys.argv[1], '本轮')
    rows = per_actor(runs)
    print('\n| 角色 | 档 | 峰值招 | 显示峰值 s1／s2／s3 | 等效中位 | 烙印倍率 | 循环招数 | 循环伤害(种子1) | 最大一类招 | 占比 | 最大一个系 | 占比 |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|')
    for x in rows:
        kp = f"{x['kind_pct']:.0f}%" if x['kind_pct'] is not None else '—'
        ep = f"{x['elem_pct']:.0f}%" if x['elem_pct'] is not None else '—'
        print(f"| {x['actor']} | {x['tier']} | {x['skill']} | {'／'.join(f'{p:,}' for p in x['peaks'])} | {statistics.median(x['peaks'])/HP:,.0f} | {x['brand']} | {x['n_cast']} | {x['cycle']:,} | {x['kind']} | {kp} | {x['elem']} | {ep} |")
    if len(sys.argv) > 2:
        base = load(sys.argv[2])
        print('\n| 角色 | 档 | 对照 s1／s2／s3 | 本轮 s1／s2／s3 | 本轮÷对照（中位） |')
        print('|---|---|---|---|---|')
        for x in rows:
            bp = [peak(next(r for r in j['rows'] if r['actor'] == x['actor'])) for s, j in sorted(base.items()) if any(r['actor']==x['actor'] for r in j['rows'])]
            if bp:
                print(f"| {x['actor']} | {x['tier']} | {'／'.join(f'{p:,}' for p in bp)} | {'／'.join(f'{p:,}' for p in x['peaks'])} | {statistics.median(x['peaks'])/statistics.median(bp):.3f} |")
