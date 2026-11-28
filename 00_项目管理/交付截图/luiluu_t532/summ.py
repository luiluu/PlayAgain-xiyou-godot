# T532（照抄 T533 summ.py，改读 <模板>_<层>_<on|off>.json）：逐种子对照＋胜率/回合中位；剔除事件中止场（三态判）
import json,sys,statistics,glob,os
S=sys.argv[1]
def cases(fn):
    d=json.load(open(fn));out=[]
    for tk,t in d['templates'].items():
        for fl,fd in t['floors'].items():
            cs=fd.get('cases') or [c for ln in fd.get('by_line',{}).values() for c in ln['cases']]
            for c in cs: out.append((tk,int(fl),c))
    return out
def state(c):
    if c['won']: return '胜'
    if c.get('timeout'): return '超时'
    if c.get('lost') or c.get('instant_loss'): return '败'
    return '中止'
key=lambda x:(x[0],x[1],x[2]['seed'],x[2]['team_idx'])
on=[];off=[]
for fn in sorted(glob.glob(f'{S}/*_on.json')): on+=cases(fn)
for fn in sorted(glob.glob(f'{S}/*_off.json')): off+=cases(fn)
offm={key(x):x[2] for x in off}
print('| 模板 | 层 | 种子 | 线 | 关（T451 原样）:结果/回合/倒地 | 开（防具合计 ≤20%）:结果/回合/倒地 |')
print('|---|---|---|---|---|---|')
agg={}
for x in sorted(on,key=key):
    c=x[2];o=offm[key(x)]
    print(f"| {x[0]} | {x[1]} | {c['seed']} | {c['line']} | {state(o)}/{o['turns']}/{o['falls_total']} | {state(c)}/{c['turns']}/{c['falls_total']} |")
    for side,cc in (('off',o),('on',c)): agg.setdefault((x[0],x[1],side),[]).append(cc)
print()
print('| 模板 | 层 | 关:胜率 / 回合中位（剔除中止） | 开:胜率 / 回合中位 | 中止场 |')
print('|---|---|---|---|---|')
for (t,f) in sorted(set((k[0],k[1]) for k in agg)):
    row=[];ab=0
    for sd in ('off','on'):
        cs=[c for c in agg[(t,f,sd)] if state(c)!='中止']; ab+=len(agg[(t,f,sd)])-len(cs)
        w=sum(1 for c in cs if c['won'])
        row.append(f"{w}/{len(cs)} / {statistics.median([c['turns'] for c in cs]) if cs else '—'}")
    print(f"| {t} | {f} | {row[0]} | {row[1]} | {ab} |")
