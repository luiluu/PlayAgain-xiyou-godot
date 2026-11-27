# T534 照抄 T533 的 summ.py：读 <目录>/{模板}_{on,off}.json 出逐种子对照表
import json,sys,statistics,os
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
print('| 模板 | 层 | 种子 | 线 | 关:结果/回合/倒地 | 开:结果/回合/倒地 |')
print('|---|---|---|---|---|---|')
agg={}
for tpl in sys.argv[2:]:
    on=cases(f'{S}/{tpl}_on.json');off=cases(f'{S}/{tpl}_off.json')
    key=lambda x:(x[0],x[1],x[2]['seed'],x[2]['team_idx'])
    offm={key(x):x[2] for x in off}
    for x in sorted(on,key=key):
        c=x[2];o=offm.get(key(x))
        print(f"| {x[0]} | {x[1]} | {c['seed']} | {c['line']} | {state(o)}/{o['turns']}/{o['falls_total']} | {state(c)}/{c['turns']}/{c['falls_total']} |")
        for side,cc in (('off',o),('on',c)):
            a=agg.setdefault((x[0],x[1],side),[]);a.append(cc)
print()
print('| 模板 | 层 | 关:胜率/回合中位(只计非中止) | 开:胜率/回合中位 |')
print('|---|---|---|---|')
for (t,f,side) in sorted(set((k[0],k[1],'x') for k in agg)):
    row=[]
    for sd in ('off','on'):
        cs=[c for c in agg[(t,f,sd)] if state(c)!='中止']
        w=sum(1 for c in cs if c['won'])
        row.append(f"{w}/{len(cs)} / {statistics.median([c['turns'] for c in cs])}")
    print(f"| {t} | {f} | {row[0]} | {row[1]} |")
