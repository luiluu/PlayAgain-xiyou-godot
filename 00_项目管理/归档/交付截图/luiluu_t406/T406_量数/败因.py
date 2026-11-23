import json,sys,collections
# T406：逐场按 trace（--keep-trace）列我方倒下时刻、按敌方招统计我方掉血、守层者自己回血。用法：python3 败因.py <json> --weak
d=json.load(open(sys.argv[1]))
only_weak='--weak' in sys.argv
for r in d['rows']:
  for p in r['per']:
    if only_weak and not p['allWeak']: continue
    tr=p.get('trace') or []
    loss=collections.Counter(); uses=collections.Counter(); deaths=[]
    prevA=None; prevE=None; heal=collections.Counter()
    for (t,u,sk,tg,eh,ah) in tr:
        if prevA is not None and u.startswith('enemy'):
            l=sum(max(0,a-b) for a,b in zip(prevA,ah)); loss[sk]+=l; uses[sk]+=1
            for i,(a,b) in enumerate(zip(prevA,ah)):
                if a>0 and b<=0: deaths.append((t,i,sk))
            if prevE is not None and eh[0]>prevE[0]: heal[sk]+=eh[0]-prevE[0]
        prevA=ah; prevE=eh
    print(r['floor'],p['team'],p['members'],p['alien'],'WON' if p['won'] else 'LOST',p['turns'],'mhp',p['partyHp'])
    print('   deaths(t,slot,skill)',deaths[:8])
    print('   loss by skill',{k:(v,uses[k]) for k,v in loss.most_common(8)})
    print('   enemy self-heal by skill',dict(heal.most_common(6)))
