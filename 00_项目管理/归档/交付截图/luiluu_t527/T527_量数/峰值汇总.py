# T527：T445 炼狱探针（T501 口径）JSON → 每人峰值（显示／等效）、D148 三档、超÷弱、循环里最大一类招与最大一个系的占比。
# 用法：python3 峰值汇总.py <目录> [<对照目录>]   目录里放 s1.json s2.json s3.json
# 返修（核查 P1-2／P2-3）：招类、系读合并 tune 六层后的改写表（改写表合并.py，同 tianqi_skills.gd:80）；
# 循环招＝cast_peaks（自然态）＋lianyu.forced_main（形态／资源／编组强制放的主力招）＋峰值招兜底，去重口径见 cycle_moves()；
# 179 流萤峰值与循环伤都取 peak_base（不含随机再放，同 T501 K交集.py）。
import json, sys, os, re, statistics, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '../../../../..'))
DB = os.path.join(ROOT, '03_再刷重制_Godot/01_Godot工程/modes/xiyou')
HP = 0.4  # enemy_hp_pct 40%：等效＝显示÷0.4（T501 R2）
D148 = {'超强者': (2520000, 3480000), '强者': (1490000, 2250000), '弱者': (750000, 1250000)}
SK = {x['id']: x for x in json.load(open(os.path.join(DB, 'generated/db/Skills.json'))) if x}
_spec = importlib.util.spec_from_file_location('rwm', os.path.join(HERE, '改写表合并.py')); _rwm = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_rwm)
RW = _rwm.merged()['skills']  # 合 tune 后的（裸表 175 储备终结 10292 没有 kind，D209 补成大招全体）
ELEM = json.load(open(os.path.join(DB, 'generated/db/System.json')))['elements']

def peak(r, actor=None):  # 同 T501 K交集.py：179 流萤取不含随机再放（循环里每招也一样取）
    return r['peak_base'] if (actor or r.get('actor')) == 179 else r['peak']

VARIANT = re.compile(r'\s*\d+%$')  # 多档耗蓝变体：名字末尾「 30%／60%／90%」

def cycle_moves(r1):
    """一个角色一轮循环里的招（去重后），返回 [(技能号, 名字, 峰值, 来源)]。去重口径：
    ① 同一技能号在 cast_peaks 和 forced_main 各量了一次（如 172 解／捌：自然态 vs 领域里）→ 取峰值高的那次；
    ② 同名多档耗蓝变体（108 凰霞风暴 A.C.S 30/60/90%、厄临星爆 30/60/90%）和同名不同号（173 怪害神杀拳 10253／10255）
       一回合只会放其中一档 → 只留峰值最高的一档；
    ③ 名字不同的派生／追加招（171 武器库·X、172 追斩·斩击、176 弓剑书锤各相的招）照独立招算。"""
    a = r1['actor']; lz = r1.get('lianyu', {})
    cand = [(c['skill'], c.get('skill_name') or c.get('input_name', ''), peak(c, a), '自然') for c in lz.get('cast_peaks', [])]
    cand += [(f['skill'], f.get('input_name') or f.get('skill_name', ''), peak(f, a), '强制') for f in lz.get('forced_main', [])]
    if r1.get('skill') and not any(c[0] == r1['skill'] for c in cand):  # 峰值来自变招／编组探针时补进
        cand.append((r1['skill'], r1.get('skill_name', ''), peak(r1), '峰值招'))
    best = {}
    for sid, nm, pk, src in cand:
        g = VARIANT.sub('', str(nm)) or str(sid)
        if g not in best or pk > best[g][2]:
            best[g] = (sid, nm, pk, src)
    return list(best.values())

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

LINE = 53.4  # 2K 符文之语：最大一类招占循环 ≥53.4% 吃 ×1.15（预算稿 v0.16 附表一 2J／2K）

def shares(r1):
    cp = cycle_moves(r1)
    cyc = sum(c[2] for c in cp)
    byk, bye = {}, {}
    for sid, _, pk, _ in cp:
        byk[kind(sid)] = byk.get(kind(sid), 0) + pk
        bye[elem(sid)] = bye.get(elem(sid), 0) + pk
    kk = max(byk.items(), key=lambda x: x[1]) if byk else ('—', 0)
    ee = max(bye.items(), key=lambda x: x[1]) if bye else ('—', 0)
    return dict(n_cast=len(cp), cycle=cyc, kind=kk[0], kind_pct=100*kk[1]/cyc if cyc else None, elem=ee[0], elem_pct=100*ee[1]/cyc if cyc else None,
                kinds=byk, elems=bye, moves=cp)

def per_actor(runs):
    ids = sorted({r['actor'] for j in runs.values() for r in j['rows']}, key=lambda a: [r for r in runs[1]['rows'] if r['actor']==a][0]['tier'] if 1 in runs else '')
    out = []
    for a in ids:
        rows = {s: next(r for r in j['rows'] if r['actor'] == a) for s, j in runs.items() if any(r['actor']==a for r in j['rows'])}
        r1 = next(iter(rows.values()))
        sh = {s: shares(rows[s]) for s in sorted(rows)}
        x = dict(actor=a, tier=r1['tier'], peaks=[peak(rows[s]) for s in sorted(rows)], skill=r1.get('skill_name'), brand=r1.get('brand_mult'), seeds=sh)
        x.update(sh[min(sh)])
        out.append(x)
    return out

def pct(v):
    return f"{v:.1f}%" if v is not None else '—'

if __name__ == '__main__':
    runs = summarize(sys.argv[1], '本轮')
    rows = per_actor(runs)
    print('\n循环口径：cast_peaks＋forced_main＋峰值招，去重见 cycle_moves()；招类、系读合并 tune 后的改写表；179 取 peak_base。')
    print('「*」＝循环只有一招，占比恒 100%，53.4% 线对它没意义。53.4% 线按三种子中位判。\n')
    print('| 角色 | 档 | 峰值招 | 显示峰值 s1／s2／s3 | 等效中位 | 烙印倍率 | 循环招数(s1) | 循环伤害(s1) | 最大一类招(s1) | 占比 s1／s2／s3 | 53.4% 线 | 最大一个系(s1) | 占比 s1／s2／s3 |')
    print('|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    for x in rows:
        kps = [v['kind_pct'] for v in x['seeds'].values()]
        eps = [v['elem_pct'] for v in x['seeds'].values()]
        one = x['n_cast'] <= 1
        med = statistics.median([v for v in kps if v is not None]) if any(v is not None for v in kps) else None
        verdict = '无意义*' if one else ('过线' if med is not None and med >= LINE else '不过')
        kinds = {v['kind'] for v in x['seeds'].values()}
        kname = x['kind'] + ('' if len(kinds) == 1 else '（种子间不同：' + '／'.join(v['kind'] for v in x['seeds'].values()) + '）')
        print(f"| {x['actor']} | {x['tier']} | {x['skill']} | {'／'.join(f'{p:,}' for p in x['peaks'])} | {statistics.median(x['peaks'])/HP:,.0f} | {x['brand']} | {x['n_cast']}{'*' if one else ''} | {x['cycle']:,} | {kname} | {'／'.join(pct(v) for v in kps)} | {verdict} | {x['elem']} | {'／'.join(pct(v) for v in eps)} |")
    print('\n### 每人循环里的招（种子 1，去重后）\n')
    print('| 角色 | 招（技能号 名字 招类 峰值 来源） |')
    print('|---|---|')
    for x in rows:
        print(f"| {x['actor']} | " + '；'.join(f"{sid} {nm} {kind(sid)} {pk:,} {src}" for sid, nm, pk, src in sorted(x['moves'], key=lambda m: -m[2])) + ' |')
    if len(sys.argv) > 2:
        base = load(sys.argv[2])
        print('\n| 角色 | 档 | 对照 s1／s2／s3 | 本轮 s1／s2／s3 | 本轮÷对照（中位） |')
        print('|---|---|---|---|---|')
        for x in rows:
            bp = [peak(next(r for r in j['rows'] if r['actor'] == x['actor'])) for s, j in sorted(base.items()) if any(r['actor']==x['actor'] for r in j['rows'])]
            if bp:
                print(f"| {x['actor']} | {x['tier']} | {'／'.join(f'{p:,}' for p in bp)} | {'／'.join(f'{p:,}' for p in x['peaks'])} | {statistics.median(x['peaks'])/statistics.median(bp):.3f} |")
