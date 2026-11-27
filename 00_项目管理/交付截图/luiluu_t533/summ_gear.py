#!/usr/bin/env python3
"""T533 真实配装对照：读 gear_raw.txt（t533_pass_bench.gd --t533-list 的 T533_GEAR 行），按 角色×招 汇总（取各场中位），出 markdown。"""
import sys, re, statistics as st
from pathlib import Path
R={}
for ln in Path(sys.argv[1]).read_text(encoding='utf-8').splitlines():
    p=ln.split('|')
    if len(p)<19: continue
    _,tpl,f,sd,aid,name,sid,sname,mode,stats,edef,emdf,bef,pa,pb,atk,mat,va,vb=p[:19]
    k=(int(aid),name,int(sid),sname,mode,stats)
    R.setdefault(k,[]).append((tpl,int(f),float(bef),float(pa),float(pb),float(atk),float(mat),float(va),float(vb),float(edef),float(emdf)))
def keys(s): return re.findall(r'"(\w+)"',s)+(['max_of'] if 'max_of' in s else [])
def single(k):
    ks=keys(k[5]); return len(ks)==1 and ((ks[0]=='atk' and k[4]=='physical') or (ks[0]=='mat' and k[4]=='magical'))
tot=len(R); sing=[k for k in R if single(k)]
zero=all(abs(v[2]-v[3])<1e-9 for k in sing for v in R[k])
print(f"角色×招 {tot} 组（{sum(len(v) for v in R.values())} 行，三档×31/33 层×3 种子里出战的人）；纯物攻物理招／纯魔攻魔法招 {len(sing)} 组改前改后{'全部相同' if zero else '有不同！'}。\n")
print("通过率取这一组各场的中位数；「变化」＝改后÷改前−1；**⚑**＝超过 ±20%。\n")
rest=[k for k in R if not single(k)]
big=[];multi=[]
for sec,cond in (('### 单属性（非本侧攻击）的招',lambda k:len(keys(k[5]))<=1 and 'max_of' not in k[5]),('### 多属性招（含 max_of）：A＝加权平均（产品），B＝取最大项（只对照）',lambda k:len(keys(k[5]))>1 or 'max_of' in k[5])):
  print('\n'+sec+'\n')
  print("| 角色 | 招 | mode | 卡上属性 | 场数 | 模板 | 改前 | 改后(A) | 变化 | B | A−B(百分点) |")
  print("|---|---|---|---|---|---|---|---|---|---|---|")
  for k in sorted([k for k in rest if cond(k)]):
      v=R[k]; b=st.median(x[2] for x in v); a=st.median(x[3] for x in v); bb=st.median(x[4] for x in v)
      rel=(a/b-1)*100 if b>0 else 0
      fl=' **⚑**' if abs(rel)>20 else ''
      if fl: big.append((k,rel))
      if len(keys(k[5]))>1 or 'max_of' in k[5]: multi.append((k,a-bb))
      tpls=''.join(sorted(set(x[0] for x in v)))
      print(f"| {k[0]} {k[1]} | {k[2]} {k[3]} | {k[4]} | {k[5]} | {len(v)} | {tpls} | {b*100:.1f}% | {a*100:.1f}% | {rel:+.0f}%{fl} | {bb*100:.1f}% | {(a-bb)*100:+.1f} |")
print(f"\n超过 ±20% 共 {len(big)} 组：" + ("、".join(f"{k[1]} {k[2]} {k[3]}（{r:+.0f}%）" for k,r in big) if big else "无"))
print(f"\n多属性招（含 max_of）{len(multi)} 组；|A−B| 超过 5 个百分点：" + ("、".join(f"{k[1]} {k[2]} {k[3]}（{d*100:+.1f}）" for k,d in multi if abs(d)>0.05) or "无"))
up=sum(1 for k in rest if st.median(x[3] for x in R[k])>st.median(x[2] for x in R[k])+1e-9)
dn=sum(1 for k in rest if st.median(x[3] for x in R[k])<st.median(x[2] for x in R[k])-1e-9)
print(f"\n方向：变高 {up} 组，变低 {dn} 组，不变 {len(rest)-up-dn} 组。")
