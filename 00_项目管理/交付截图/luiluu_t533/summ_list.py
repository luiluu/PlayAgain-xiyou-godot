#!/usr/bin/env python3
"""T533 全名单对照汇总：读 pass_list_raw.txt（t533_pass_list.gd 输出），出 markdown 表。"""
import sys, re
from pathlib import Path
rows=[]
for ln in Path(sys.argv[1]).read_text(encoding='utf-8').splitlines():
    p=ln.split('|')
    if len(p)<14: continue
    _,aid,name,tier,sid,sname,mode,stats,bef,pa,pb,oa,va,vb=p[:14]
    rows.append(dict(aid=int(aid),name=name,tier=tier,sid=int(sid),sname=sname,mode=mode,stats=stats,bef=float(bef),pa=float(pa),pb=float(pb),oa=float(oa),va=float(va),vb=float(vb)))
def keys(st): return re.findall(r'"(\w+)"',st)+(['max_of'] if 'max_of' in st else [])
def single_attack(r):
    k=keys(r['stats'])
    return len(k)==1 and ((k[0]=='atk' and r['mode']=='physical') or (k[0]=='mat' and r['mode']=='magical'))
changed=[r for r in rows if not single_attack(r)]
same=len(rows)-len(changed)
zero_ok=all(abs(r['bef']-r['pa'])<1e-9 for r in rows if single_attack(r))
print(f"总行数 {len(rows)}（角色×招，含同招多人）；纯物攻物理招／纯魔攻魔法招 {same} 行，改前改后{'全部相同' if zero_ok else '有不同！'}；其余 {len(changed)} 行见下。\n")
big=[]
for sec,cond in (('### 单属性（非本侧攻击）的招',lambda r:len(keys(r['stats']))<=1 and 'max_of' not in r['stats']),('### 多属性招（含 max_of）：A＝加权平均（产品），B＝取最大项（只对照）',lambda r:len(keys(r['stats']))>1 or 'max_of' in r['stats'])):
  print('\n'+sec+'\n')
  print("| 角色 | 梯队 | 招 | mode | 卡上属性 | 改前 | 改后(A) | 变化 | B | A−B |")
  print("|---|---|---|---|---|---|---|---|---|---|")
  for r in sorted([r for r in changed if cond(r)],key=lambda r:(r['aid'],r['sid'])):
      rel=(r['pa']/r['bef']-1)*100 if r['bef']>0 else 0
      flag=' **⚑**' if abs(rel)>20 else ''
      if flag: big.append(r)
      print(f"| {r['aid']} {r['name']} | {r['tier']} | {r['sid']} {r['sname']} | {r['mode']} | {r['stats'].replace('|','/')} | {r['bef']*100:.1f}% | {r['pa']*100:.1f}% | {rel:+.0f}%{flag} | {r['pb']*100:.1f}% | {(r['pa']-r['pb'])*100:+.1f} |")
multi=[r for r in changed if len(keys(r['stats']))>1 or 'max_of' in r['stats']]
print(f"\n变化超过 ±20%（相对）共 {len(big)} 行；多属性招 {len(multi)} 行（A 与 B 差见上表最后一列），其中 |A−B|>5 个百分点 {sum(1 for r in multi if abs(r['pa']-r['pb'])>0.05)} 行。")
ups=sum(1 for r in changed if r['pa']>r['bef']+1e-9); downs=sum(1 for r in changed if r['pa']<r['bef']-1e-9)
print(f"方向：变高 {ups} 行，变低 {downs} 行，不变 {len(changed)-ups-downs} 行。")

# T533 R2（小o P1-1）：逐人覆盖核对——每位候选池角色有几行、普攻在不在；不走卡公式的伤害招另列（noncard 文件，可选第二参数）
cnt={}; atk1=set()
for r in rows:
    cnt.setdefault((r['aid'],r['name']),0); cnt[(r['aid'],r['name'])]+=1
    if r['sid']==1: atk1.add(r['aid'])
print(f"\n### 逐人覆盖（{len(cnt)} 人，五档候选池并集＋五条悟；每人至少 1 行）\n")
print("| 角色 | 行数 | 含 1 号普攻（T553） |")
print("|---|---|---|")
for (aid,name),n in sorted(cnt.items()):
    print(f"| {aid} {name} | {n} | {'是' if aid in atk1 else '否（普攻被替换或不走 T553）'} |")
if len(sys.argv)>2 and Path(sys.argv[2]).exists():
    nc=[l.split('|') for l in Path(sys.argv[2]).read_text(encoding='utf-8').splitlines() if l.startswith('T533_NONCARD')]
    print(f"\n### 不走角色卡公式的伤害招（本卡不改，通过率照旧物攻／魔攻）：{len(nc)} 行、{len(set(x[1] for x in nc))} 人\n")
    print("| 角色 | 招 | mode | 公式来源 | 公式（前 60 字） |")
    print("|---|---|---|---|---|")
    for x in nc:
        print(f"| {x[1]} {x[2]} | {x[3]} {x[4]} | {x[5]} | {x[6]} | `{x[7]}` |")
