#!/usr/bin/env python3
"""T390 第 3 步后半、第 10 步：照 XTianqiBrand.settle／gain 的公式逐场算（只算首通／再打给的数，不算印纹灼满 sear 那份；
刻了印、一直出战 ×1、到节点当场打心魔）。不是虚拟玩家实打。用法：python3 s3_s10_formula.py <brand.json>"""
import json, sys
d = json.load(open(sys.argv[1])); g = d['gain']; S = int(d.get('store_scale', 100))
rp = g['replay']; nodes = sorted(int(x) for x in g['layer_line'].values())
def first_amount(f):
    fl = g['first_clear'].get('floors', {})
    if str(f) in fl: return float(fl[str(f)])
    for s in g['first_clear']['segments']:
        if s['from'] <= f <= s['to']: return float(s['each'])
    return 0.0
def line_at(f): return round(sum(first_amount(i) for i in range(1, min(f, 36) + 1)) * S)
def replay(before, floor_now, coef):
    gap = max(0.0, (line_at(floor_now) - before) / S)
    return round(max(gap * rp['ratio'], rp['floor'] * coef) * S)
for diff in ['xunchang', 'jianxian', 'zhengdao']:
    coef = rp['difficulty'][diff]
    # 第 3 步：首通 1～36（到节点就立境，所以不被节点卡），36 层后刷再打，cap＝100
    v = line_at(36)
    n = 0
    while v < 100 * S and n < 1000:
        v = min(100 * S, v + replay(v, 36, coef)); n += 1
    print(f'S3 {diff}: 36 层首通完 {line_at(36)/S:.2f}%，再打 {n} 场到 100%（100 轮后 {"100%" if n <= 100 else "不到"}）')
    # 第 10 步：卡在某节点没打心魔，再爬 k 层（首通给的数被节点吞掉），回头立境后靠再打追平层线
    for node_floor, k in [(25, 1), (25, 5), (10, 1), (10, 5)]:
        before = line_at(node_floor); fl = node_floor + k
        target = line_at(fl); m = 0; v = before
        while v < target and m < 1000:
            v = v + replay(v, fl, coef); m += 1
        print(f'S10 {diff}: {node_floor} 层节点漏打心魔再爬 {k} 层：差 {(target-before)/S:.0f} 点，再打 {m} 场追平')
