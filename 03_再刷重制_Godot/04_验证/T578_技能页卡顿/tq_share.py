import re,sys,collections
shell=set("res://"+l.strip() for l in open(sys.argv[2]) if l.strip())
L=open(sys.argv[1],encoding="utf-8",errors="replace").read().split("\n")
skip_first = sys.argv[3]=="skipfirst"
frames=0; frame_script=0.0
agg=collections.defaultdict(lambda:[0.0,0.0,0])
use=False
for i,l in enumerate(L):
    m=re.match(r"FRAME: total: ([\d.]+) script: ([\d.]+)",l)
    if m:
        frames+=1; use = not (skip_first and frames==1)
        if use: frame_script+=float(m.group(2))
        continue
    m=re.match(r"^\d+:(res://\S+?)::(\d+)::(\S+)$",l)
    if m and use and i+1<len(L):
        s=re.search(r"total: ([\d.]+)/\d+ % \tself: ([\d.]+)/\d+ % tcalls: (\d+)",L[i+1])
        if s:
            a=agg[(m.group(1),m.group(3))]; a[0]+=float(s.group(1)); a[1]+=float(s.group(2)); a[2]+=int(s.group(3))
tot_self=sum(v[1] for v in agg.values())
stub=[(k,v) for k,v in agg.items() if k[0] in shell]
stub_self=sum(v[1] for k,v in stub); stub_calls=sum(v[2] for k,v in stub)
print(f"frames_used={frames-(1 if skip_first else 0)} script_total={frame_script:.3f}s sum_self={tot_self:.3f}s")
print(f"stub_self={stub_self:.3f}s ({100*stub_self/tot_self:.1f}% of self) stub_calls={stub_calls}")
for k,v in sorted(stub,key=lambda x:-x[1][1])[:12]:
    print(f"  {v[1]*1000:8.1f}ms self {v[2]:8d} calls {k[1]}")
for name in ["XDB.rec","XDB._rec_fast","XTianqi.active"]:
    for k,v in agg.items():
        if k[1]==name: print(f"  [{name}] self={v[1]*1000:.1f}ms total={v[0]*1000:.1f}ms calls={v[2]}")
