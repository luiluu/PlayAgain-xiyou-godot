import json,glob,sys,os
from collections import defaultdict
def load(tag):
    agg={}
    for f in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)),tag,'*.json'))):
        d=json.load(open(f))
        for t,x in d['templates'].items():
            for fl,v in x['floors'].items():
                groups=[v['cases']] if 'cases' in v else [g['cases'] for g in v['by_line'].values()]
                for cs in groups:
                  for c in cs:
                    key=(t,int(fl),c['line'] if int(fl)>=35 else 'ALL')
                    agg.setdefault(key,[]).append(c)
    return agg
def cell(cs):
    n=len(cs); w=sum(c['won'] for c in cs)
    by=defaultdict(lambda:[0,0])
    for c in cs: by[c['seed']][0]+=c['won']; by[c['seed']][1]+=1
    seeds=' '.join(f"{by[s][0]}/{by[s][1]}" for s in sorted(by))
    return dict(n=n,w=w,pct=100*w/n,seeds=seeds,turns=sum(c['turns'] for c in cs)/n,
                to=sum(c['timeout'] for c in cs),dead=sum(c['deaths'] for c in cs)/n,
                left=100*sum(c['enemy_hp_left_pct'] for c in cs)/n)
if __name__=='__main__':
    tags=sys.argv[1:]
    data=[load(t) for t in tags]
    keys=sorted(set().union(*[d.keys() for d in data]))
    print('| 模板 | 层 | 线 | '+' | '.join(f'{t} 胜(逐种子) | {t} 回合／超时／剩血' for t in tags)+' |')
    print('|'+'---|'*(3+2*len(tags)))
    for k in keys:
        row=[k[0],str(k[1]),k[2]]
        for d in data:
            if k in d:
                c=cell(d[k]); row+= [f"{c['w']}/{c['n']} {c['pct']:.0f}%（{c['seeds']}）", f"{c['turns']:.1f}／{c['to']}／{c['left']:.0f}%"]
            else: row+=['—','—']
        print('| '+' | '.join(row)+' |')
    # 汇总
    for t,d in zip(tags,data):
        tot=defaultdict(lambda:[0,0])
        for k,cs in d.items():
            tot[k[0]][0]+=sum(c['won'] for c in cs); tot[k[0]][1]+=len(cs)
        print(t, {k:f"{a}/{b} {100*a/b:.1f}%" for k,(a,b) in sorted(tot.items())})
