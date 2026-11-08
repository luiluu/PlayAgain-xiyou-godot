#!/usr/bin/env python3
"""全量地图盘点（cc 悟空 floor5，只读）：事件在不在、能不能到。

对照原版正式源（默认冻结正式源 v0.62.12）的全部地图与重制切片（xiyou_slice.json 的 maps／keepEvents）和产物 generated/maps：
  A. 切片图上放了的事件／公共事件里，传送去不在切片的图（重制里提示「首期尚未开放」）；
  B. 传送坐标超出目标图范围；
  C. 切片图从开局图出发沿传送走不到（只算放了的事件、它们调用的公共事件、切片收的公共事件，脚本 reserveTransfer 也算）；
  D. keepEvents 列表型的图上原版有内容却没放的事件；
  E. 产物地图与原版的事件、页数不一致；
  F. 不在切片、有事件内容的原版地图，以及原版里有没有入口通向它（入口全在不放的地方＝原版就进不去）。
用法：地图盘点.py [--app 正式源 app.nw] [--md 输出.md] [--json 输出.json]
"""
import argparse, json, re
from collections import defaultdict, deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
GEN = ROOT / '01_Godot工程/modes/xiyou/generated'
APP = ROOT / '02_内容与素材/冻结正式源/app.nw'
START_MAPS = [1, 2, 221]
SCRIPT_TRANSFER = re.compile(r'reserveTransfer\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)')
SKIP_CODES = {0, 108, 408}


def load(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def transfers(lst):
    """一条指令表里的场所移动：[(目标图, x, y, 直接指定?)]，以及调用的公共事件"""
    out, ces, consts = [], set(), {}
    for c in lst or []:
        code, p = c['code'], c['parameters']
        if code == 122 and p[2] == 0 and p[3] == 0:  # 变量＝常量（顺序传播，不分分支：只为认出「变量指定」的传送目标）
            for v in range(p[0], p[1] + 1):
                consts[v] = p[4]
        elif code == 201 and p[0] == 1:
            if all(v in consts for v in p[1:4]):
                out.append((consts[p[1]], consts[p[2]], consts[p[3]], True))
        elif code == 201:
            out.append((p[1], p[2], p[3], p[0] == 0))
        elif code == 117:
            ces.add(p[0])
        elif code in (355, 655):
            for m in SCRIPT_TRANSFER.finditer(str(p[0])):
                out.append((int(m[1]), int(m[2]), int(m[3]), True))
    return out, ces


def page_cond(pg):
    """页条件（只记生效的项）：开关、变量≥、独立开关、物品、角色"""
    c, out = pg['conditions'], {}
    sw = [c[k] for k, v in (('switch1Id', 'switch1Valid'), ('switch2Id', 'switch2Valid')) if c.get(v)]
    if sw:
        out['switches'] = sw
    if c.get('variableValid'):
        out['variable'] = [c['variableId'], c['variableValue']]
    if c.get('selfSwitchValid'):
        out['self'] = c['selfSwitchCh']
    if c.get('itemValid'):
        out['item'] = c['itemId']
    if c.get('actorValid'):
        out['actor'] = c['actorId']
    return out


def has_content(ev):
    return any(c['code'] not in SKIP_CODES for p in ev['pages'] for c in p['list'])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--app', default=str(APP))
    ap.add_argument('--md')
    ap.add_argument('--json')
    a = ap.parse_args()
    data = Path(a.app) / 'data'
    cfg = load(HERE / 'xiyou_slice.json')
    slice_maps = {int(m) for m in cfg['maps']}
    keep = cfg.get('keepEvents', {})
    infos = {m['id']: m for m in load(data / 'MapInfos.json') if m}
    ces = load(data / 'CommonEvents.json')
    # 物品／技能效果调用的公共事件（如指路灯 411）与手填的 extraCommonEvents：玩家随处可用，出口算作处处可走
    slice_ces = {int(i) for i in cfg.get('extraCommonEvents', [])}
    for kind in ('Items', 'Skills'):
        for r in load(data / ('%s.json' % kind)):
            for ef in (r or {}).get('effects', []):
                if ef['code'] == 44:
                    slice_ces.add(ef['dataId'])
    maps = {}
    for mid in infos:
        f = data / ('Map%03d.json' % mid)
        if f.exists():
            maps[mid] = load(f)

    def kept(mid, eid):
        k = keep.get(str(mid), [])
        return True if not isinstance(k, list) else eid in k

    def size(mid):
        m = maps.get(mid)
        return (m['width'], m['height']) if m else None

    def name(mid):
        return infos.get(mid, {}).get('name', '?')

    # 公共事件的传送与互相调用
    ce_tr, ce_calls = {}, {}
    for ce in ces:
        if ce:
            ce_tr[ce['id']], ce_calls[ce['id']] = transfers(ce['list'])

    def ce_closure(start):
        seen, q = set(), deque(start)
        while q:
            i = q.popleft()
            if i in seen or i not in ce_tr:
                continue
            seen.add(i)
            q.extend(ce_calls[i])
        return seen

    # 每张图「放了的」出口与「原版全部」出口
    edges = defaultdict(list)      # mid → [(dest,x,y,来源)]
    all_edges = defaultdict(list)  # 原版全部（含不在切片／没放）
    find = {'A': [], 'B': [], 'D': [], 'E': []}
    for mid, m in maps.items():
        for ev in m['events']:
            if not ev:
                continue
            for pi, pg in enumerate(ev['pages']):
                tr, calls = transfers(pg['list'])
                for ci in ce_closure(calls):
                    tr += [t + () for t in ce_tr[ci]]
                for d, x, y, direct in tr:
                    if not direct:
                        continue
                    src = 'Map%03d EV%d p%d' % (mid, ev['id'], pi)
                    all_edges[mid].append((d, x, y, src))
                    if mid in slice_maps and kept(mid, ev['id']):
                        edges[mid].append((d, x, y, src))
            if mid in slice_maps and not kept(mid, ev['id']) and has_content(ev):
                find['D'].append({'map': mid, 'mapName': name(mid), 'event': ev['id'], 'name': ev['name'], 'x': ev['x'], 'y': ev['y']})
    # 切片收的公共事件（物品／技能效果、手填）里的传送：来源图记 0
    for ci in ce_closure(slice_ces):
        for d, x, y, direct in ce_tr[ci]:
            if direct:
                edges[0].append((d, x, y, 'CE%d' % ci))
    for mid, lst in edges.items():
        for d, x, y, src in lst:
            if d not in slice_maps:
                find['A'].append({'from': src, 'to': d, 'toName': name(d), 'xy': [x, y], 'exists': d in maps})
            else:
                w, h = size(d) or (0, 0)
                if not (0 <= x < w and 0 <= y < h):
                    find['B'].append({'from': src, 'to': d, 'xy': [x, y], 'size': [w, h]})
    # C：从开局图沿放了的出口 BFS（公共事件出口 0 视为处处可用）
    reach, q = set(), deque(START_MAPS)
    while q:
        mid = q.popleft()
        if mid in reach:
            continue
        reach.add(mid)
        for d, *_ in edges.get(mid, []) + edges.get(0, []):
            if d in slice_maps:
                q.append(d)
    find['C'] = [{'map': mid, 'name': name(mid),
                  'entries': sorted({s for src_m, l in all_edges.items() for d, _, _, s in l if d == mid})[:6]}
                 for mid in sorted(slice_maps - reach)]
    # E：产物与原版事件页数
    for mid in sorted(slice_maps):
        g = GEN / 'maps' / ('Map%03d.json' % mid)
        if not g.exists():
            find['E'].append({'map': mid, 'problem': '产物缺地图'})
            continue
        gm, om = load(g), maps.get(mid)
        if om is None:
            find['E'].append({'map': mid, 'problem': '原版没有这张图'})
            continue
        for ev in om['events']:
            if not ev:
                continue
            gev = gm['events'][ev['id']] if ev['id'] < len(gm['events']) else None
            if gev is None or len(gev['pages']) != len(ev['pages']):
                find['E'].append({'map': mid, 'event': ev['id'], 'problem': '页数 %s≠%d' % (len(gev['pages']) if gev else '无', len(ev['pages']))})
    # F：不在切片、有内容的图
    find['F'] = []
    for mid in sorted(set(maps) - slice_maps):
        m = maps[mid]
        evs = [e for e in m['events'] if e and has_content(e)]
        if not evs:
            continue
        ins = sorted({s for src_m, l in all_edges.items() for d, _, _, s in l if d == mid})
        ins_kept = [s for s in ins if any(s == e[3] for e in edges.get(int(s[3:6]) if s.startswith('Map') else 0, []))]
        find['F'].append({'map': mid, 'name': name(mid), 'events': len(evs), 'entries': ins[:6], 'entriesTotal': len(ins), 'entriesInSlice': ins_kept[:6]})
    # 传送落点与各图出口（给 xiyou_transfer_reach 端到端走）：落点＝放了的事件、切片公共事件里直接或常量变量指定的传送；
    # 出口＝放了的事件里任一页（含它调用的公共事件）有传送的事件，自动／并行触发的另记（不用走过去）；
    # pages 按页列出带页条件的传送页（floor7：专项按条件设状态、断言选中该页再走）
    landings = {}
    for mid, lst in edges.items():
        for d, x, y, src in lst:
            if d in slice_maps:
                landings.setdefault((d, x, y), []).append(src)
    oracle_f = GEN / 'oracle/events.json'
    oracle_pages = {c['id'] for c in load(oracle_f)['cases'] if c.get('kind') == 'map'} if oracle_f.exists() else set()
    exits = {}
    for mid in sorted(slice_maps):
        m = maps.get(mid)
        if not m:
            continue
        walk, auto, pages = [], [], []
        for ev in m['events']:
            if not ev or not kept(mid, ev['id']):
                continue
            hit = False
            for pi, pg in enumerate(ev['pages']):
                tr, calls = transfers(pg['list'])
                for ci in ce_closure(calls):
                    tr += ce_tr[ci]
                if not tr:
                    continue
                if not hit:
                    (auto if pg['trigger'] in (3, 4) else walk).append(ev['id'])
                    hit = True
                # 按页记：有页条件、或不是第 1 页（新开局可能选不到它）的传送页，参照逐页跑过（events.json 的 m图e事件p页）才收
                cond = page_cond(pg)
                if (cond or pi > 0) and ('m%de%dp%d' % (mid, ev['id'], pi)) in oracle_pages:
                    pages.append({'event': ev['id'], 'page': pi, 'trigger': pg['trigger'], 'cond': cond})
        exits[str(mid)] = {'walk': walk, 'auto': auto, 'pages': pages}
    fixture = {'说明': '地图盘点.py 生成：传送落点（目标图、坐标、来源）与各图出口事件；xiyou_transfer_reach 用',
               'landings': [{'map': d, 'xy': [x, y], 'from': sorted(set(v))[:3]} for (d, x, y), v in sorted(landings.items())],
               'exits': exits}
    (ROOT / '01_Godot工程/tests/fixtures/transfer_landings.json').write_text(json.dumps(fixture, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    summary = {k: len(v) for k, v in find.items()}
    if a.json:
        Path(a.json).write_text(json.dumps({'summary': summary, **find}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False))
    if a.md:
        L = ['# 全量地图盘点（自动生成，`03_转换工具/地图盘点.py`）', '',
             '对照原版正式源全部地图与重制切片：A 放了的事件传送去不在切片的图；B 传送坐标超出目标图；C 切片图从开局图沿放了的传送走不到；'
             'D keepEvents 列表型的图上原版有内容却没放的事件；E 产物与原版页数不一致；F 不在切片、有事件内容的原版地图（「切片里的入口」为空＝重制进不去）。', '',
             '| 项 | 数 |', '| --- | --- |'] + ['| %s | %d |' % kv for kv in summary.items()] + ['']
        for k in 'ABCDEF':
            L += ['## %s' % k, '']
            for r in find[k]:
                L.append('- ' + json.dumps(r, ensure_ascii=False))
            L.append('')
        Path(a.md).write_text('\n'.join(L), encoding='utf-8')


if __name__ == '__main__':
    main()
