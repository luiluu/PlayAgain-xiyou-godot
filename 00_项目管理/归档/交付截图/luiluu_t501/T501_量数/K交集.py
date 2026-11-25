import json,sys
K0=0.13
LINES={'超强者':(2520000,3480000),'强者':(1490000,2250000),'弱者':(750000,1250000)}
REP={'超强者':[95,122,163],'强者':[1,2,22],'弱者':[3,12,18]}
def peak(r): return r['peak_base'] if r['actor']==179 else r['peak']
def run(files, label):
  print('==',label)
  allk=[]
  for s,f in files:
    d=json.load(open(f)); assert abs(d['k']-K0)<1e-9 or True
    k0=d['k']
    for mode in ('rep','all'):
      lo,hi=0,9
      parts=[]
      for t,(a,b) in LINES.items():
        rs=[r for r in d['rows'] if r['tier']==t and (mode=='all' or r['actor'] in REP[t])]
        m=max(rs,key=peak); M=peak(m)
        l,h=a*k0/M,b*k0/M; lo=max(lo,l); hi=min(hi,h)
        parts.append(f"{t[0]} {M:,}({m['actor']}) [{l:.3f},{h:.3f}]")
      allk.append((s,mode,lo,hi))
      print(s,mode,'k=',k0,' | '.join(parts),f'=> [{lo:.3f},{hi:.3f}]')
  for mode in ('rep','all'):
    xs=[x for x in allk if x[1]==mode]
    print(mode,'common',max(x[2] for x in xs),min(x[3] for x in xs))
if __name__=='__main__':
  run([(i,f) for i,f in enumerate(sys.argv[1:],1)],'x')
