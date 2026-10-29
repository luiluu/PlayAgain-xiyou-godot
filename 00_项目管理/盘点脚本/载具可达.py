"""载具盘点（悟空_67，2026-10-29）：只读冻结 v0.28。用法：python3 -I 载具可达.py <载具与宽口径.md> <不动点.md> [<岛块.md> [<专项对照.json>]]
1) 全数据里的载具指令（202/206/323、条件 111 类型 13、脚本里的 vehicle/airship）。
2) 切片内每张图：按图块通行（MV checkPassage，四向、双向都查）从所有进入落点做 BFS，
   列出切片里有内容的事件中，哪些格子（本格或相邻格）都不在可达块里。
   进入落点 = 新游戏起点 + 所有 201 固定传送的目标（宽口径：不看条件、不看来源是否可达）。
"""
import json, glob, re, collections, sys, pathlib
REPO = pathlib.Path(__file__).resolve().parents[2]
SRC = REPO/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw'
D = SRC/'data'
SLICE = json.load(open(REPO/'03_再刷重制_Godot/03_转换工具/xiyou_slice.json'))
SMAPS = set(SLICE['maps'])
INFO = {i['id']: i['name'] for i in json.load(open(D/'MapInfos.json')) if i}
TS = json.load(open(D/'Tilesets.json'))
CE = json.load(open(D/'CommonEvents.json'))
SYS = json.load(open(D/'System.json'))
maps = {}
for f in glob.glob(str(D/'Map[0-9][0-9][0-9].json')):
    maps[int(re.search(r'Map(\d+)', f).group(1))] = json.load(open(f))

out = []
P = out.append

# ---------- 1. 载具指令 ----------
VEH = {0: '小船', 1: '大船', 2: '飞艇'}
hits = collections.defaultdict(list)
def scan_list(lst, where):
    for c in lst:
        k = c['code']; p = c['parameters']
        if k == 206: hits['206 上下载具'].append(where)
        elif k == 202:
            # [载具, 指定方式(0 直接/1 变量), 地图, x, y]
            hits['202 设置载具位置'].append(f"{where} {VEH.get(p[0],p[0])}→" + (f"Map{p[2]:03d}({p[3]},{p[4]})" if p[1]==0 else f"变量{p[2]},{p[3]},{p[4]}"))
        elif k == 323: hits['323 更改载具图像'].append(f"{where} {VEH.get(p[0],p[0])} {p[1]}#{p[2]}")
        elif k == 140: hits['140 更改载具BGM'].append(where)
        elif k == 111 and p[0] == 13: hits['111 条件：乘坐载具'].append(f"{where} {VEH.get(p[1],p[1])}")
        elif k in (355, 655, 111) and isinstance(p[0] if k!=111 else (p[1] if p[0]==12 else ''), str):
            s = p[0] if k != 111 else (p[1] if p[0]==12 else '')
            if re.search(r'vehicle|airship|isInVehicle|getOnOff|_vehicle', str(s), re.I):
                hits['脚本含 vehicle/airship'].append(f"{where}: {str(s)[:80]}")
        elif k == 356 and re.search(r'vehicle|airship|飞艇', p[0], re.I):
            hits['插件指令含 vehicle/飞艇'].append(f"{where}: {p[0][:80]}")
for m, mp in maps.items():
    for e in mp['events']:
        if not e: continue
        for pi, pg in enumerate(e['pages']):
            scan_list(pg['list'], f"Map{m:03d}{'*' if m in SMAPS else ''} EV{e['id']}p{pi+1}")
for c in CE:
    if c: scan_list(c['list'], f"CE{c['id']}{'*' if c['id'] in SLICE['extraCommonEvents'] else ''}")
P('# 载具指令（* = 已在切片）')
for k, v in hits.items():
    P(f'## {k}：{len(v)} 处')
    for x in v[:60]: P('  - ' + x)
P(f"System 起始位置：小船 Map{SYS['boat']['startMapId']}，大船 Map{SYS['ship']['startMapId']}，飞艇 Map{SYS['airship']['startMapId']} ({SYS['airship']['startX']},{SYS['airship']['startY']})")

# 插件里的载具相关
pl = open(SRC/'js/plugins.js', encoding='utf-8').read()
pl = json.loads(pl[pl.index('['):pl.rindex(']')+1])
P('# 启用插件里提到 vehicle/airship/飞艇 的')
for p in pl:
    if not p.get('status'): continue
    f = SRC/'js/plugins'/(p['name']+'.js')
    try: t = f.read_text(encoding='utf-8', errors='ignore')
    except Exception: continue
    n = len(re.findall(r'vehicle|airship|isInVehicle|Game_Vehicle|isInAirship', t, re.I))
    if n: P(f"  - {p['name']}：{n} 处")

# ---------- 2. 可达 ----------
def flags_of(m): return TS[maps[m]['tilesetId']]['flags']
def tile(mp, x, y, z): return mp['data'][(z*mp['height'] + y)*mp['width'] + x]
def check(mp, fl, x, y, bit):
    for z in (3, 2, 1, 0):
        t = tile(mp, x, y, z); f = (fl[t] or 0) if 0 <= t < len(fl) else 0
        if f & 0x10: continue
        if f & bit == 0: return True
        if f & bit == bit: return False
    return False
DIRS = {2: (0, 1), 4: (-1, 0), 6: (1, 0), 8: (0, -1)}
REV = {2: 8, 8: 2, 4: 6, 6: 4}
def passable(mp, fl, x, y, d):
    return check(mp, fl, x, y, (1 << (d//2 - 1)) & 0x0f)
def bfs(m, seeds):
    mp = maps[m]; fl = flags_of(m); W, H = mp['width'], mp['height']
    seen = set(); q = collections.deque()
    for s in seeds:
        if 0 <= s[0] < W and 0 <= s[1] < H and s not in seen: seen.add(s); q.append(s)
    while q:
        x, y = q.popleft()
        for d, (dx, dy) in DIRS.items():
            nx, ny = x+dx, y+dy
            if not (0 <= nx < W and 0 <= ny < H) or (nx, ny) in seen: continue
            if passable(mp, fl, x, y, d) and passable(mp, fl, nx, ny, REV[d]):
                seen.add((nx, ny)); q.append((nx, ny))
    return seen
def components(m):
    mp = maps[m]; fl = flags_of(m); W, H = mp['width'], mp['height']
    comp = {}; n = 0
    for y in range(H):
        for x in range(W):
            if (x, y) in comp: continue
            # 只给至少一个方向能走的格子编块
            if not any(passable(mp, fl, x, y, d) for d in DIRS): continue
            n += 1
            for c in bfs(m, [(x, y)]): comp[c] = n
    return comp, n

seeds = collections.defaultdict(set)
seeds[SYS['startMapId']].add((SYS['startX'], SYS['startY']))
edges = []  # (src, dst, x, y)
def collect(lst, src):
    for c in lst:
        if c['code'] == 201 and c['parameters'][0] == 0:
            _, mid, x, y = c['parameters'][:4]
            seeds[mid].add((x, y)); edges.append((src, mid, x, y))
for m, mp in maps.items():
    for e in mp['events']:
        if not e: continue
        for pi, pg in enumerate(e['pages']): collect(pg['list'], (m, e['id']))
for c in CE:
    if c: collect(c['list'], ('CE', c['id']))
# 地图传送插件菜单的落点
for p in pl:
    if p.get('status') and 'MapTransfer' in p['name']:
        P(f"# 插件 {p['name']} 参数键：{list(p['parameters'].keys())[:10]}")

def content(pg):
    codes = {c['code'] for c in pg['list']}
    tags = []
    if 201 in codes: tags.append('传送')
    if 302 in codes: tags.append('商店')
    if 301 in codes: tags.append('战斗')
    if 101 in codes: tags.append('对话')
    if 117 in codes: tags.append('CE')
    if codes & {121, 122, 123}: tags.append('开关/变量')
    if codes & {125, 126, 127, 128}: tags.append('给物品')
    return tags

P('\n# 切片内各图：按图块从落点 BFS 走不到的有内容事件')
summary = []
for m in sorted(SMAPS):
    if m not in maps: continue
    mp = maps[m]
    reach = bfs(m, seeds[m])
    comp, ncomp = components(m)
    unreached = []
    for e in mp['events']:
        if not e: continue
        tags = sorted({t for pg in e['pages'] for t in content(pg)})
        if not tags: continue
        x, y = e['x'], e['y']
        near = [(x, y)] + [(x+dx, y+dy) for dx, dy in DIRS.values()] + [(x+2*dx, y+2*dy) for dx, dy in DIRS.values()]
        if not any(c in reach for c in near):
            unreached.append((e['id'], e['name'], x, y, tags, comp.get((x, y))))
    if unreached:
        summary.append((m, len(unreached), ncomp, len(reach)))
        P(f"\n## Map{m:03d} {INFO.get(m,'')}（{mp['width']}×{mp['height']}，可走块 {ncomp}，落点 {len(seeds[m])} 个，可达 {len(reach)} 格）")
        for u in unreached:
            P(f"  - EV{u[0]} {u[1]} ({u[2]},{u[3]}) 块{u[5]} [{'、'.join(u[4])}]")
P('\n# 汇总：图, 走不到的有内容事件数, 可走块数, 可达格')
for s in summary: P(f"  Map{s[0]:03d} {INFO.get(s[0],'')}: {s[1]} 个, 块 {s[2]}, 可达 {s[3]}")
open(sys.argv[1], 'w').write('\n'.join(out))


# ---------- 3. 不动点：只有能走到的事件里的 201 才给落点 ----------
def ev_reachable(m, e, reach):
    if all(pg['trigger'] in (3, 4) for pg in e['pages']): return 'auto'
    x, y = e['x'], e['y']
    near = [(x, y)] + [(x+dx, y+dy) for dx, dy in DIRS.values()] + [(x+2*dx, y+2*dy) for dx, dy in DIRS.values()]
    if any(c in reach for c in near): return 'walk'
    if any(pg['moveType'] != 0 for pg in e['pages']): return 'move?'
    return None
fseeds = collections.defaultdict(set)
fseeds[SYS['startMapId']].add((SYS['startX'], SYS['startY']))
ce_dst = []
for c in CE:
    if not c: continue
    for k in c['list']:
        if k['code'] == 201 and k['parameters'][0] == 0:
            _, mid, x, y = k['parameters'][:4]
            if mid in SMAPS: fseeds[mid].add((x, y)); ce_dst.append((c['id'], mid, x, y))
why = collections.defaultdict(dict)
changed = True
REACH = {}
while changed:
    changed = False
    for m in SMAPS:
        if m not in maps or not fseeds[m]: continue
        r = bfs(m, fseeds[m]); REACH[m] = r
        for e in maps[m]['events']:
            if not e: continue
            if not ev_reachable(m, e, r): continue
            for pg in e['pages']:
                for k in pg['list']:
                    if k['code'] == 201 and k['parameters'][0] == 0:
                        _, mid, x, y = k['parameters'][:4]
                        if mid in SMAPS and (x, y) not in fseeds[mid]:
                            fseeds[mid].add((x, y)); why[mid][(x, y)] = (m, e['id']); changed = True
Q = []
Q.append('# 不动点（落点只来自能走到的事件／公共事件）')
Q.append('公共事件里进切片图的 201：' + '；'.join(f'CE{a}→Map{b:03d}({c},{d})' for a, b, c, d in ce_dst))
for m in sorted(SMAPS):
    if m not in maps: continue
    r = REACH.get(m, set())
    bad = []
    for e in maps[m]['events']:
        if not e: continue
        tags = sorted({t for pg in e['pages'] for t in content(pg)})
        if not tags: continue
        st = ev_reachable(m, e, r)
        if st in ('walk', 'auto'): continue
        bad.append(f"  - EV{e['id']} {e['name']} ({e['x']},{e['y']}) {'会移动' if st else ''} [{'、'.join(tags)}]")
    if bad:
        Q.append(f"\n## Map{m:03d} {INFO.get(m,'')}（可达 {len(r)} 格，落点 {sorted(fseeds[m])[:12]}）")
        Q += bad
unseeded = [m for m in SMAPS if m in maps and not fseeds[m]]
Q.append('\n切片里完全没有可达落点的图：' + '、'.join(f'Map{m:03d}{INFO.get(m,"")}' for m in sorted(unseeded)))
open(sys.argv[2], 'w').write('\n'.join(Q))

# ---------- 4. 天之上／神魔战场岛块：每块的事件、可降落格 ----------
I = []
def landok(mp, fl, x, y): return check(mp, fl, x, y, 0x0800) and check(mp, fl, x, y, 0x0f)
for m in (69, 186):
    mp = maps[m]; fl = flags_of(m); comp, n = components(m)
    r = REACH[m]
    evs = collections.defaultdict(list)
    evpos = set()
    for e in mp['events']:
        if not e: continue
        evpos.add((e['x'], e['y']))
        tags = sorted({t for pg in e['pages'] for t in content(pg)})
        if not tags: continue
        x, y = e['x'], e['y']
        near = [(x, y)] + [(x+dx, y+dy) for dx, dy in DIRS.values()] + [(x+2*dx, y+2*dy) for dx, dy in DIRS.values()]
        cs = sorted({comp[c] for c in near if c in comp})
        dst = [f"→Map{k['parameters'][1]:03d}{INFO.get(k['parameters'][1],'')}" for pg in e['pages'] for k in pg['list'] if k['code']==201 and k['parameters'][0]==0]
        evs[cs[0] if cs else None].append(f"EV{e['id']}({x},{y})[{'、'.join(tags)}]{''.join(sorted(set(dst)))}")
    cells = collections.defaultdict(list)
    for c, i in comp.items(): cells[i].append(c)
    I.append(f"\n# Map{m:03d} {INFO[m]} 块 {n}；落点 {sorted(fseeds[m])}；来源 { {k:v for k,v in why[m].items()} }")
    I.append(f"飞艇着陆格总数 {sum(1 for y in range(mp['height']) for x in range(mp['width']) if landok(mp,fl,x,y))}")
    for i in sorted(evs, key=lambda k: (k is None, k or 0)):
        cl = cells.get(i, [])
        lk = [c for c in cl if landok(mp, fl, *c) and c not in evpos]
        inreach = any(c in r for c in cl)
        I.append(f"块{i}: {len(cl)} 格, 可降落 {len(lk)} 格{(' 例'+str(sorted(lk)[len(lk)//2])) if lk else ''} {'【走得到】' if inreach else ''}")
        for s in evs[i]: I.append('    ' + s)
if len(sys.argv) > 3: open(sys.argv[3], 'w').write('\n'.join(I))
# 第 4 个输出（悟空_69，甲二）：专项 xiyou_airship_fly 的静态对照表（JSON）：69／186 全图可降落格（isAirshipLandOk 且原位置没有事件）、
# 各格所在块、各事件所在块（本格或相邻、隔一格算，同上）、走得到的块
if len(sys.argv) > 4:
    J = {}
    for m in (69, 186):
        mp = maps[m]; fl = flags_of(m); comp, n = components(m)
        evpos = {(e['x'], e['y']) for e in mp['events'] if e}
        land = sorted([x, y] for y in range(mp['height']) for x in range(mp['width']) if landok(mp, fl, x, y) and (x, y) not in evpos)
        evb = {}
        for e in mp['events']:
            if not e: continue
            x, y = e['x'], e['y']
            near = [(x, y)] + [(x+dx, y+dy) for dx, dy in DIRS.values()] + [(x+2*dx, y+2*dy) for dx, dy in DIRS.values()]
            cs = sorted({comp[c] for c in near if c in comp})
            if cs: evb[str(e['id'])] = cs[0]
        J[str(m)] = {'block': {f"{x},{y}": comp[(x, y)] for x, y in land if (x, y) in comp},
                     'eventBlock': evb, 'reach': sorted({comp[c] for c in REACH[m] if c in comp})}
    json.dump(J, open(sys.argv[4], 'w'), ensure_ascii=False, separators=(',', ':'))

# ---------- 5. 软锁检查：只在走不到处写入、却在走得到处读取的开关／变量／物品（结果追加到不动点文件末尾）----------
SYSN = SYS['switches']; VN = SYS['variables']
ITN = {i['id']: i['name'] for i in json.load(open(D/'Items.json')) if i}
def lists(e): 
    for pg in e['pages']: yield pg
dead_w = collections.defaultdict(set); live_w = collections.defaultdict(set)
reads = collections.defaultdict(set)
for m in SMAPS:
    if m not in maps: continue
    r = REACH.get(m, set())
    for e in maps[m]['events']:
        if not e: continue
        ok = bool(fseeds[m]) and ev_reachable(m, e, r) in ('walk', 'auto')
        tgt = live_w if ok else dead_w
        for pg in e['pages']:
            c = pg['conditions']
            if ok:
                if c['switch1Valid']: reads[('s', c['switch1Id'])].add(f'Map{m:03d}EV{e["id"]}')
                if c['switch2Valid']: reads[('s', c['switch2Id'])].add(f'Map{m:03d}EV{e["id"]}')
                if c['variableValid']: reads[('v', c['variableId'])].add(f'Map{m:03d}EV{e["id"]}')
                if c['itemValid']: reads[('i', c['itemId'])].add(f'Map{m:03d}EV{e["id"]}')
            for k in pg['list']:
                p = k['parameters']
                if k['code'] == 121 and p[2] == 0:
                    for s in range(p[0], p[1]+1): tgt[('s', s)].add(f'Map{m:03d}EV{e["id"]}')
                elif k['code'] == 122:
                    for s in range(p[0], p[1]+1): tgt[('v', s)].add(f'Map{m:03d}EV{e["id"]}')
                elif k['code'] == 126 and p[1] == 0:
                    tgt[('i', p[0])].add(f'Map{m:03d}EV{e["id"]}')
                elif k['code'] == 111 and ok:
                    if p[0] == 0: reads[('s', p[1])].add(f'Map{m:03d}EV{e["id"]}')
                    elif p[0] == 1: reads[('v', p[1])].add(f'Map{m:03d}EV{e["id"]}')
                    elif p[0] == 8: reads[('i', p[1])].add(f'Map{m:03d}EV{e["id"]}')
# CE 写入也算活的（宽口径）
for c in CE:
    if not c: continue
    for k in c['list']:
        p = k['parameters']
        if k['code'] == 121 and p[2] == 0:
            for s in range(p[0], p[1]+1): live_w[('s', s)].add(f'CE{c["id"]}')
        elif k['code'] == 122:
            for s in range(p[0], p[1]+1): live_w[('v', s)].add(f'CE{c["id"]}')
        elif k['code'] == 126 and p[1] == 0: live_w[('i', p[0])].add(f'CE{c["id"]}')
G = ['\n# 只在走不到的地方写入、却被走得到的地方读的（开关 s／变量 v／物品 i）']
for key in sorted(dead_w):
    if key in live_w or key not in reads: continue
    nm = SYSN[key[1]] if key[0]=='s' else VN[key[1]] if key[0]=='v' else ITN.get(key[1], '')
    G.append(f"{key[0]}{key[1]} {nm}: 写于 {sorted(dead_w[key])[:4]} ；读于 {sorted(reads[key])[:6]}")
open(sys.argv[2], 'a').write('\n'.join(G) + ('\n（无）' if len(G) == 1 else ''))
