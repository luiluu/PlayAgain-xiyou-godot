import json,sys,collections
# T406：逐种子 胜/场汇总。用法：python3 汇总.py <目录> 标签=前缀…（读 <前缀>_weak.json、<前缀>_norm.json；归因组只有 _weak）
# 用法：sum.py 目录 标签=文件前缀...  逐种子 胜/场（秒＝≤3 回合输，单列）、第 2 回合内倒下人数、败场主杀招
D=sys.argv[1]
def load(fn):
    d=json.load(open(f'{D}/{fn}.json')); out=[]
    for r in d['rows']:
        for p in r['per']: out.append(p)
    return out
def deaths(p):
    tr=p.get('trace') or []; prev=None; ds=[]
    for (t,u,sk,tg,eh,ah) in tr:
        if prev is not None:
            for i,(a,b) in enumerate(zip(prev,ah)):
                if a>0 and b<=0: ds.append((t,sk if u.startswith('enemy') else 'self'))
        prev=ah
    return ds
for chain,flt in [('纯4弱',lambda p:p['allWeak']),('普通',lambda p:True)]:
    suf='weak' if chain=='纯4弱' else 'norm'
    print(f'\n### {chain}\n\n| 档 | s1 | s2 | s3 | 合计 | 第2回合内倒下/场 | 败场 |')
    print('|---|---|---|---|---|---|---|')
    for arg in sys.argv[2:]:
        lab,pre=arg.split('=')
        ps=[p for p in load(f'{pre}_{suf}') if flt(p)]
        cells=[];W=N=Q=0;early=[];lost=[]
        for s in (1,2,3):
            a=[p for p in ps if str(p['rng']).startswith(str(s))]
            q=[p for p in a if not p['won'] and p['turns']<=3]
            k=[p for p in a if p not in q]
            w=sum(1 for p in k if p['won']); W+=w;N+=len(k);Q+=len(q)
            cells.append(f"{w}/{len(k)}"+(f"（秒{len(q)}）" if q else ''))
            for p in a:
                ds=deaths(p); early.append(sum(1 for t,_ in ds if t<=1))
                if not p['won']:
                    c=collections.Counter(sk for _,sk in ds).most_common(2)
                    lost.append(f"s{s}{p['team']}:{p['alien'][0] if p['alien'] else '无'}:{p['turns']}回合{'超时' if p['turns']>=40 else ''}:杀{c}")
        tot=f"{W}/{N}"+(f"（秒{Q}）" if Q else '')+f" {round(100*W/max(1,N))}%"
        print(f"| {lab} | "+' | '.join(cells)+f" | {tot} | {sum(early)}/{len(early)} | {'；'.join(lost) or '－'} |")
