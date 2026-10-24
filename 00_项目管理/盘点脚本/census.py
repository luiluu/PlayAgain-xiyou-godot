"""未接地图盘点：只读冻结正式源与 xiyou_slice.json，写 00_项目管理/盘点_未接地图_20261023.md。python3 00_项目管理/盘点脚本/census.py"""
import json,glob,re,collections,sys
import pathlib
REPO=pathlib.Path(__file__).resolve().parents[2]
ROOT=str(REPO/'03_再刷重制_Godot')+'/'
OUT=REPO/'00_项目管理'/'盘点_未接地图_20261023.md'
R=ROOT+'02_内容与素材/冻结正式源/app.nw/data/'
S=json.load(open(ROOT+'03_转换工具/xiyou_slice.json'))
slice_maps=set(S['maps']); slice_troops=set(S['troops'])
keep=S['keepEvents']
info=json.load(open(R+'MapInfos.json'))
names={i['id']:i['name'] for i in info if i}
CE=json.load(open(R+'CommonEvents.json'))
maps={}
for f in glob.glob(R+'Map[0-9][0-9][0-9].json'):
    m=int(re.search(r'Map(\d+)',f).group(1)); maps[m]=json.load(open(f))
def kept(m,eid):
    k=keep.get(str(m),'*') if m in slice_maps else None
    if k is None: return False
    return k=='*' or eid in k
# reachable CE closure from slice
def walk_ce(lst,acc):
    for c in lst:
        if c['code']==117 and c['parameters'][0] not in acc:
            acc.add(c['parameters'][0]); walk_ce(CE[c['parameters'][0]]['list'],acc)
slice_ce=set()
for m in slice_maps:
    for e in maps[m]['events']:
        if e and kept(m,e['id']):
            for p in e['pages']: walk_ce(p['list'],slice_ce)
slice_ce|=set(S.get('extraCommonEvents',[]))
# 间接调用公共事件：物品／技能效果44、切片敌群战斗页的117、自动／并行触发的公共事件（只要有一条可能就算可达，宁宽勿窄）
def _load(n): return json.load(open(R+n))
indirect_ce=set()
for fn in ('Items.json','Skills.json'):
    for it in _load(fn):
        for ef in (it or {}).get('effects',[]): 
            if ef.get('code')==44: indirect_ce.add(ef['dataId'])
for tr in _load('Troops.json'):
    if tr and tr['id'] in slice_troops:
        for pg in tr['pages']: walk_ce(pg['list'],indirect_ce)
for n,c in enumerate(CE):
    if c and c.get('trigger',0)>0: indirect_ce.add(n)
for ce in list(indirect_ce): 
    if ce not in slice_ce: slice_ce.add(ce); walk_ce(CE[ce]['list'],slice_ce)
INDIRECT_N=len(indirect_ce)
# transfers: (src_kind, src_map, ev, target map)
incoming=collections.defaultdict(list)
def scan(lst,src):
    for c in lst:
        if c['code']==201 and c['parameters'][0]==0: incoming[c['parameters'][1]].append(src+((c['parameters'][2],c['parameters'][3]),))
        elif c['code']==201: incoming[-1].append(src)
for m,d in maps.items():
    for e in d['events']:
        if not e: continue
        for i,p in enumerate(e['pages']): scan(p['list'],('map',m,e['id'],i))
for n,c in enumerate(CE):
    if c: scan(c['list'],('ce',n,0,0))
# also map-start (new game transfer) from System.json
sysd=json.load(open(R+'System.json'))
incoming[sysd['startMapId']].append(('system',0,0,0,(sysd['startX'],sysd['startY'])))
T=json.load(open(R+'Troops.json'))
def info_map(m):
    d=maps[m]
    troops=set(); codes=collections.Counter(); plug=set(); ces=set(); nev=0; npages=0
    for e in d['events']:
        if not e: continue
        nev+=1
        for p in e['pages']:
            npages+=1
            for c in p['list']:
                codes[c['code']]+=1
                if c['code']==301 and c['parameters'][0]==0: troops.add(c['parameters'][1])
                if c['code']==117: ces.add(c['parameters'][0])
                if c['code']==356: plug.add(c['parameters'][0].split()[0])
    for en in d['encounterList']: troops.add(en['troopId'])
    return dict(nev=nev,npages=npages,troops=sorted(troops),ces=sorted(ces),plug=sorted(plug),codes=codes,w=d['width'],h=d['height'],disp=d.get('displayName',''))
rows=[]
for m in sorted(maps):
    if m in slice_maps: continue
    im=info_map(m)
    inc=incoming.get(m,[])
    # reachable from slice: source map in slice with kept event, or CE in slice_ce
    live=[]; dead_src=[]
    for src in inc:
        if src[0]=='map':
            (live if kept(src[1],src[2]) else dead_src).append(src)
        elif src[0]=='ce':
            (live if src[1] in slice_ce else dead_src).append(src)
        elif src[0]=='system': live.append(src)
    rows.append(dict(map=m,name=names.get(m,''),inc_total=len(inc),live=live,dead=dead_src,**im))
if False: json.dump({'slice_n':len(slice_maps),'total':len(maps),'rows':rows,'slice_ce_n':len(slice_ce)},open('/dev/null','w'),ensure_ascii=False,default=lambda o:dict(o))
print(len(maps),len(slice_maps),len(rows))

# ---------- 第二部分：传递闭包分层、依赖、markdown ----------
def handled_codes(text):
    codes=set()
    for line in text.splitlines():
        m=re.match(r'^\t\t(\d+(?:, \d+)*):',line)
        if m: codes.update(int(x) for x in m.group(1).split(', '))
    return codes
interp=''.join(open(ROOT+'01_Godot工程/modes/xiyou/'+f,encoding='utf-8').read() for f in ('core/mv_event_core.gd','map/mv_interpreter.gd'))
handled=handled_codes(interp)|{0,108,401,402,403,404,408,411,412,413,505,601,602,603,604,605,655}
HOST=set(int(x) for x in re.search(r'HOST_CODES := \[([^\]]*)\]',interp).group(1).split(','))
handled|=HOST
STRUCT=set()
def plug_names(text):
    body=text.split('func _plugin_command',1)[1].split('\nfunc ',1)[0] if 'func _plugin_command' in text else ''
    names=set()
    for line in body.splitlines():
        if re.match(r'^\t\t"',line): names.update(re.findall(r'"([^"]+)"',line.split(':',1)[0]))
    return names
plugs=plug_names(interp)
# 插件传送菜单（MapTransferPlugin 的 Map Settings）：canTransfer 且（未隐藏或被 UnlockMapTransfer 解锁）的地图玩家可直接传送
_pl=open(R+'../js/plugins.js',encoding='utf-8').read()
_pl=json.loads(_pl[_pl.index('['):_pl.rindex(']')+1])
_mt=[x for x in _pl if x['name']=='MapTransferPlugin'][0]['parameters']
plugin_menu={}
for _s in json.loads(_mt['Map Settings']):
    _s=json.loads(_s)
    if _s.get('canTransfer')!='false': plugin_menu[int(_s.get('transmitid') or _s['id'])]=_s.get('hidden')=='true'
# 脚本里的 reserveTransfer
scr_inc=collections.defaultdict(list)
for m,d in maps.items():
    for e in d['events']:
        if not e: continue
        for p in e['pages']:
            for c in p['list']:
                if c['code'] in(355,655):
                    for mm in re.finditer(r'reserveTransfer\((\d+)',c['parameters'][0]): scr_inc[int(mm.group(1))].append(('script',m,e['id']))
by={r['map']:r for r in rows}
reached=set(slice_maps); layers=[]
pending=set(by)
while True:
    new=[]
    for m in sorted(pending):
        r=by[m]
        for src in r['live']+r['dead']:
            if src[0]=='map' and src[1] in reached and src[1]!=m and (kept(src[1],src[2]) or src[1] not in slice_maps): new.append(m);break
            if src[0]=='ce' and src[1] in slice_ce: new.append(m);break
            if src[0]=='system': new.append(m);break
    if not new: break
    layers.append(new); reached|=set(new); pending-=set(new)
orphans=sorted(pending)
def unsupported(r):
    d=maps[r['map']];miss=collections.Counter();pm=set()
    for e in d['events']:
        if not e: continue
        for p in e['pages']:
            for c in p['list']:
                if c['code'] not in handled: miss[c['code']]+=1
                if c['code']==356:
                    n=c['parameters'][0]
                    if not any(n.startswith(x) for x in plugs): pm.add(n.split()[0])
    return miss,sorted(pm)
def classify(r):
    n=r['name']+r['disp']
    if re.search(r'测试|test|备份|副本\d|demo|DEMO',n): return '疑似测试／备份'
    if r['nev']==0: return '空图（无事件）'
    return '正常内容'
out=[]
P=out.append
P('# 未接地图盘点（2026-10-23，悟空_45）\n')
P('由 `00_项目管理/盘点脚本/census.py`（只读冻结正式源与 xiyou_slice.json）生成，可重跑。\n')
P('## 结论\n')
P('> **2026-10-24 修订（悟空_51，答沙僧核查 P3-C3）**：原稿写“余下 100 张在原版里没有任何可达来源”超出了静态算法能证明的范围，已改为“静态扫描没找到可达来源”并列出未覆盖的来源类型；同时补了公共事件的间接调用（物品／技能效果、切片敌群战斗页、自动／并行触发）与 MapTransferPlugin 传送菜单两类来源。数字随之变动：旧版“第 1 层 4 张、可达 10 张”只算直接 201 传送，口径更窄，不可与本版直接比较。上一版里已接入的 17 张（Map024～028、111、029、023、035、036 等）见变更记录。\n')
P(f'- 冻结正式源共 **{len(maps)}** 张地图数据（Map*.json），切片已接 **{len(slice_maps)}** 张（{len(slice_maps)*100/len(maps):.1f}%），未接 **{len(rows)}** 张。')
P(f'- 其中静态扫描**可能**从切片里的事件走到的（公共事件间接调用按宽口径计，是候选而非已证可达） **{len(layers[0]) if layers else 0}** 张（第 1 层），再往里一层层展开共 {sum(len(l) for l in layers)} 张；其余 {len(orphans)} 张**静态扫描没找到可达来源**（不等于原版里不可达，见下「扫描范围」）：')
P(f'  - 只被未接地图／公共事件指向：{len([m for m in orphans if by[m]["dead"]])}；完全没有传送指向：{len([m for m in orphans if not by[m]["dead"]])}。')
P(f'  - 其中在地图传送插件菜单（MapTransferPlugin）里有条目的：{len([m for m in orphans if m in plugin_menu])} 张（可传送且隐藏需解锁 {len([m for m in orphans if plugin_menu.get(m)])}），这些玩家可能通过传送菜单到达，不能算死图。')
P('- **扫描范围**：')
P('  - 已算作来源：固定地图的 201 传送（地图事件页、公共事件）、新游戏起点、公共事件调用链（117，含物品／技能效果 44、切片敌群战斗页、自动／并行触发的公共事件，一律按“可能调用”宽算，共 '+str(INDIRECT_N)+' 个）；脚本 355/655 里的 reserveTransfer（冻结源中 0 处）。')
P('  - **没覆盖**：变量指定的 201（冻结源中 0 处，若有则目标未解析）；脚本传送的其它写法（setupTransfer 等）与变量拼出的地图号；插件传送（MapTransferPlugin 菜单只按配置做了“有无条目”判断，未核解锁条件与传送道具；其它插件如死亡回城、NGP 起点等未逐个分析）；敌群战斗页以外的事件（如状态／技能里的脚本）；事件页条件与开关使其永不触发的情形（本脚本不看条件，所以对“可达”偏宽，对“未发现来源”偏窄）。')
P('  - 因此“未发现来源”只是一条线索，不据此排除内容、认定死图或扣减总工作量；“缺指令”只按指令码分支是否存在判断，未证 355 脚本与各插件参数均可翻译。')
P('- **真实可达性（带条件的不动点，见文末「真实可达性逐图结论」）**：上面“静态扫描没找到来源”的口径偏宽也偏窄；按开关／变量／独立开关能否被写入重算后，原版里的传送途径只有固定 201 与传送菜单（菜单不产生新入口），结论以文末那一节为准。')
cls=collections.Counter(classify(by[m]) for m in by)
P('- 按名称／事件分类：'+'、'.join(f'{k} {v}' for k,v in cls.items())+'。')
P('- 进度账「楼层、副本与剧情内容」的分母若按全部地图数 231 计，当前实际 '+f'{len(slice_maps)}/{len(maps)}；若扣除疑似测试／备份与空图（{sum(1 for m in by if classify(by[m])!="正常内容")} 张）后为 {len(slice_maps)}/{len(maps)-sum(1 for m in by if classify(by[m])!="正常内容")}。\n')
P(f'- 对进度账：「楼层、副本与剧情内容」行写的 68/231 是 dev.0xx 时的数，实际切片现为 **{len(slice_maps)}/{len(maps)}**（MapInfos 登记 {len([i for i in info if i])} 张，Map*.json 共 {len(maps)} 张，二者差的是没登记的数据文件）。\n')
P('## 接入顺序（按层展开，层内按规模小、依赖少排）\n')
P('排序键：解释器缺指令数＋缺插件数（越少越靠前），其次事件数、敌群数。「缺指令」指事件里出现解释器没有分支的指令码（含出现次数）；敌群列出的是尚未进切片的敌群数。\n')
def key(m):
    r=by[m];miss,pm=unsupported(r)
    return (len(miss)+len(pm),r['nev'],len([t for t in r['troops'] if t not in slice_troops]))
for li,l in enumerate(layers):
    P(f'### 第 {li+1} 层（{len(l)} 张）\n')
    P('| 图 | 名称 | 尺寸 | 事件／页 | 未入切片敌群 | 来源（谁传到这里） | 缺指令／插件 | 分类 |')
    P('|---|---|---|---|---|---|---|---|')
    for m in sorted(l,key=key):
        r=by[m];miss,pm=unsupported(r)
        src=[]
        for x in (r['live']+r['dead'])[:3]:
            src.append('Map%d EV%d'%(x[1],x[2]) if x[0]=='map' else ('CE%d'%x[1] if x[0]=='ce' else '新游戏起点'))
        src=sorted(set(src))
        nt=len([t for t in r['troops'] if t not in slice_troops])
        mi='、'.join(f'{k}×{v}' for k,v in sorted(miss.items()))+(' 插件:'+','.join(pm) if pm else '')
        P(f'| {m} | {r["name"] or r["disp"]} | {r["w"]}×{r["h"]} | {r["nev"]}／{r["npages"]} | {nt} | {"、".join(src)} | {mi or "—"} | {classify(r)} |')
    P('')
P('## 静态扫描没找到可达来源的地图\n')
P('| 图 | 名称 | 尺寸 | 事件／页 | 指向它的来源（均不可达） | 传送菜单 | 分类 |')
P('|---|---|---|---|---|---|---|')
for m in orphans:
    r=by[m]
    src=sorted(set(('Map%d EV%d'%(x[1],x[2]) if x[0]=='map' else 'CE%d'%x[1]) for x in r['dead']+scr_inc.get(m,[]) if x[0] in('map','ce') ) | set('脚本 Map%d EV%d'%(x[1],x[2]) for x in scr_inc.get(m,[])))
    P(f'| {m} | {r["name"] or r["disp"]} | {r["w"]}×{r["h"]} | {r["nev"]}／{r["npages"]} | {"、".join(src[:4]) or "无"} | {("需解锁" if plugin_menu[m] else "有条目") if m in plugin_menu else "—"} | {classify(r)} |')
open(OUT,'w',encoding='utf-8').write('\n'.join(out)+'\n')
print('layers',[len(l) for l in layers],'orphans',len(orphans))

# ---------- 第三部分：来源事件在切片图里但没放 ----------
cand=collections.defaultdict(list)
for m,r in by.items():
    for src in r['dead']:
        if src[0]=='map' and src[1] in slice_maps and not kept(src[1],src[2]):
            cand[m].append(src)
P2=[]
P2.append('\n## 来源事件就在已接地图里、只是没放进 keepEvents 的未接地图\n')
P2.append('这些图的入口门在切片地图上被 keepEvents 挡掉了（或属于原版条件页）。放开对应事件即可「玩家能到达」，是最便宜的接入点。\n')
P2.append('| 目标图 | 名称 | 来源（已接地图 事件） | 事件名 | 事件／页 | 未入切片敌群 | 缺指令／插件 |')
P2.append('|---|---|---|---|---|---|---|')
for m in sorted(cand,key=key):
    r=by[m];miss,pm=unsupported(r)
    srcs=sorted(set((x[1],x[2]) for x in cand[m]))
    names_=[]
    for sm,se in srcs[:3]:
        ev=[e for e in maps[sm]['events'] if e and e['id']==se][0]
        names_.append(ev['name'])
    nt=len([t for t in r['troops'] if t not in slice_troops])
    mi='、'.join(f'{k}×{v}' for k,v in sorted(miss.items()))+(' 插件:'+','.join(pm) if pm else '')
    P2.append(f'| {m} | {r["name"] or r["disp"]} | {"、".join("Map%d EV%d"%x for x in srcs[:4])} | {"、".join(names_)} | {r["nev"]}／{r["npages"]} | {nt} | {mi or "—"} |')
open(OUT,'a',encoding='utf-8').write('\n'.join(P2)+'\n')
print('cand maps',len(cand))

# ---------- 第四部分：带条件的真实可达性（reach.py）----------
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
import reach
R_reached,R_parent,R_lc,R_lt=reach.fixpoint()
targets=sorted(set(orphans)|set(cand))
def evname(m,ev):
    e=[x for x in maps[m]['events'] if x and x['id']==ev]
    return e[0]['name'] if e else ''
def src_txt(s):
    if s.kind=='ce': return 'CE%d'%s.m
    return 'Map%d EV%d「%s」第%d页'%(s.m,s.ev,evname(s.m,s.ev),s.pg+1)
verdict={}
for m in targets:
    r=by[m]; cl=classify(r)
    if m in R_reached:
        ch=reach.route(m,R_parent,slice_maps)
        notes=[n for _,ns in ch for n in ns]
        root=ch[0][0]
        verdict[m]=('条件可达' if notes else '可达',ch,notes,root)
    else:
        bl=reach.blockers(m,R_reached,R_lc,R_lt)
        kind='测试或备份图' if cl=='疑似测试／备份' else ('确认不可达（空图）' if cl=='空图（无事件）' else '确认不可达')
        verdict[m]=(kind,None,bl,None)
cnt_v=collections.Counter(v[0] for v in verdict.values())
Q=[]
Q.append('\n## 真实可达性逐图结论（悟空_52，2026-10-24）\n')
Q.append('由 `00_项目管理/盘点脚本/reach.py` 对冻结正式源做带条件的不动点（见该文件开头说明），覆盖上面「静态扫描没找到可达来源」与「来源在已接地图、没放进 keepEvents」两张表的并集 '+f'{len(targets)} 张。\n')
Q.append('**玩家能把角色传到另一张地图的途径，冻结源里只有两条**：地图事件与公共事件里的固定地图 201（变量指定的 201、敌群页里的 201 均为 0 处；脚本传送只有 MapTransferPlugin 自己的 reserveTransfer；NGP_Final_Complete 未启用，My_FastTravel 不在 plugins.js 里），以及 MapTransferPlugin 传送菜单。菜单的条目 canTransfer 为 true 才能传，hidden 的条目进入过一次会自动解锁（performTransfer 钩子），所以菜单只是已进过地图的快捷方式，**不会带来新入口**；也没有任何事件用 UnlockMapTransfer 直接解锁。\n')
Q.append('口径：从新游戏起点出发，一条 201 可走当且仅当它所在地图可达、事件页条件与外层条件分支“可能满足”（开关要 ON 需有处写入，变量比较在初值 0 不成立需有处写入，独立开关需同事件置 ON；持有物品／角色等不核实际能否拿到，列为条件）。写入处只认可达地图／公共事件里的。其它限定见「扫描范围」，特别是：未核事件页之间的先后与具体数值、变量值可能来自旧存档或 MV 版插件之外的路径。\n')
Q.append('统计：'+'、'.join(f'{k} {v}' for k,v in sorted(cnt_v.items()))+f'（整体：全部 {len(maps)} 张里原版可达 {len(R_reached)} 张）。\n')
bad_slice=sorted(slice_maps-R_reached)
if bad_slice:
    Q.append('**切片已接但原版算不可达**：'+'、'.join(f'{m} {names.get(m,"")}' for m in bad_slice)+'。这是本模型的发现而非接入问题：十二层冰封洞穴(23)只能从 Map34 EV15 的 BOSS 页在变量152「12层随机」=1 时进入，而该变量在冻结源里只有读取、没有任何写入（含插件），公共事件 94（12层冰封洞窟）也无物品／技能／状态／菜单调用——原版里玩家永远走 65 十二层:苍白雪岭这条线。同类的七层科维努斯镇(11)与 7 层猪猪农场(61) 同理（公共事件 45 无人调用，Map142／143 入口在不可达图里）。若变量由旧存档带入则另当别论，需用户确认是否保留 23。\n')
Q.append('| 图 | 名称 | 结论 | 入口（由外向里）与条件 / 卡住的原因 | 事件／页 | 未入切片敌群 | 缺指令／插件 |')
Q.append('|---|---|---|---|---|---|---|')
for m in targets:
    r=by[m]; miss,pm=unsupported(r)
    v,ch,notes,root=verdict[m]
    nt=len([t for t in r['troops'] if t not in slice_troops])
    mi='、'.join(f'{k}×{n}' for k,n in sorted(miss.items()))+(' 插件:'+','.join(pm) if pm else '')
    if ch is not None:
        ent=' → '.join(src_txt(s) for s,_ in ch)
        detail=ent+('；条件：'+'；'.join(sorted(set(notes))) if notes else '')
        if root.kind=='map' and not kept(root.m,root.ev) and root.m in slice_maps: detail+='（入口事件现被 keepEvents 挡掉）'
    else:
        detail=('；'.join(notes) if notes else '无任何 201 指向')
        if r['nev']==0: detail+='；空图'
    nm=r['name'] or r['disp'] or '（未登记）'
    Q.append(f'| {m} | {nm} | {v} | {detail} | {r["nev"]}／{r["npages"]} | {nt} | {mi or "—"} |')
# 入口簇：同一个“要放开的入口”下面带出哪些图
clusters=collections.defaultdict(list)
for m in targets:
    v,ch,notes,root=verdict[m]
    if ch is not None: clusters[(root.kind,root.m,root.ev)].append(m)
Q.append('\n### 建议接入顺序（按“要放开的入口”分簇，成本低、价值高在前）\n')
Q.append('一个簇 = 放开同一个入口事件后能带出的图（含入口之后一层层的地图）。成本 = 缺指令／插件种数、敌群数、事件数；价值 = 簇内正常内容图数。只列真实可达的簇；确认不可达与测试图不列。\n')
Q.append('| 序 | 入口（已接地图事件） | 带出的图 | 正常内容图 | 事件合计 | 未入切片敌群 | 缺指令／插件 | 入口条件 |')
Q.append('|---|---|---|---|---|---|---|---|')
def cluster_cost(item):
    (k,mm,ev),ms=item
    miss=collections.Counter();pms=set();troops=set();nev=0
    for m in ms:
        a,b=unsupported(by[m]); miss.update(a); pms|=set(b)
        troops|={t for t in by[m]['troops'] if t not in slice_troops}; nev+=by[m]['nev']
    return (len(miss)+len(pms),len(troops),nev),miss,pms,troops,nev
ordered=sorted(clusters.items(),key=lambda it:(cluster_cost(it)[0],-len(it[1])))
for i,((k,mm,ev),ms) in enumerate(ordered,1):
    c,miss,pms,troops,nev=cluster_cost(((k,mm,ev),ms))
    good=[m for m in ms if classify(by[m])=='正常内容']
    ent=('CE%d'%mm) if k=='ce' else 'Map%d EV%d「%s」'%(mm,ev,evname(mm,ev))
    mi='、'.join(f'{a}×{b}' for a,b in sorted(miss.items()))+(' 插件:'+','.join(sorted(pms)) if pms else '')
    cond=sorted(set(n for m in ms for n in verdict[m][2]))
    Q.append(f'| {i} | {ent} | {"、".join(f"{m} {by[m]["name"] or by[m]["disp"]}" for m in ms)} | {len(good)} | {nev} | {len(troops)} | {mi or "—"} | {"；".join(cond[:4]) or "无"} |')
open(OUT,'a',encoding='utf-8').write('\n'.join(Q)+'\n')
print('reach',dict(cnt_v),'clusters',len(clusters))
