#!/usr/bin/env python3
"""楼层／副本／剧情「事件、难度验收」盘点（cc 悟空 accept1，只读）。

按切片里每张地图列：事件页用例数（generated/oracle/events.json）、空绿用例数（事件空绿扫描）、有状态变体数
（event_presets.json）、点名这张图的专项（tests/*.gd 里的 MapNNN、mNNeXX、xiyou_floor_reachNNN 文件名）。
再按「层／副本／大厅城镇／其它」归类汇总，给进度核定用。
用法：验收盘点.py [--md 输出.md] [--json 输出.json]
"""
import argparse, json, re, sys
from collections import defaultdict, Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'
TESTS = HERE.parent / '01_Godot工程/tests'
sys.path.insert(0, str(HERE))


def load(p):
    return json.loads(Path(p).read_text())


def map_names():
    out = {}
    for m in load(GEN / 'db/MapInfos.json'):
        if m:
            out[m['id']] = m['name']
    return out


def category(name):
    if '层' in name:
        return '楼层'
    if any(k in name for k in ('副本', '洞', '塔', '渊', '试炼', '秘境', '遗迹', '地宫', '战场', '要塞', '城堡', '巢', '福地', '圣地')):
        return '副本／秘境'
    if any(k in name for k in ('大厅', '城', '村', '镇', '商', '店', '公会', '工坊', '作坊', '实验')):
        return '大厅／城镇／功能图'
    return '其它'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--md')
    ap.add_argument('--json')
    a = ap.parse_args()
    slice_maps = load(HERE / 'xiyou_slice.json')['maps']
    names = map_names()
    ev = load(GEN / 'oracle/events.json')['cases']
    cases = Counter(c['map'] for c in ev if c.get('kind') == 'map')
    ce_cases = sum(1 for c in ev if c.get('kind') != 'map')
    import subprocess
    scan = subprocess.run([sys.executable, str(HERE / '事件空绿扫描.py'), '--top', '0', '--out', '/dev/stdout'],
                          capture_output=True, text=True).stdout
    js = scan[scan.index('{"total"'):] if '{"total"' in scan else scan[scan.index('{'):]
    rows = json.JSONDecoder().raw_decode(js.lstrip())[0]['rows']
    empty = Counter(r['map'] for r in rows if r['id'].startswith('m'))
    empty_ce = sum(1 for r in rows if r['id'].startswith('ce'))
    pres = Counter(int(re.match(r'm(\d+)e', c['base']).group(1)) for c in load(HERE / 'event_presets.json')['cases'] if c['base'].startswith('m'))
    pres_ce = sum(1 for c in load(HERE / 'event_presets.json')['cases'] if c['base'].startswith('ce'))
    tmap = defaultdict(set)
    pats = [re.compile(r'Map0*(\d{1,3})(?!\d)'), re.compile(r'\bm(\d{1,3})e\d+'), re.compile(r'floor_reach(\d{3})')]
    for f in list(TESTS.glob('xiyou_*.gd')):
        txt = f.read_text(errors='ignore')
        ids = set()
        for p in pats[:2]:
            ids |= {int(x) for x in p.findall(txt)}
        ids |= {int(x) for x in pats[2].findall(f.stem)}
        for i in ids:
            tmap[i].add(f.stem)
    data = []
    for m in sorted(slice_maps):
        n = names.get(m, '')
        data.append(dict(map=m, name=n, cat=category(n), cases=cases.get(m, 0), empty=empty.get(m, 0), variants=pres.get(m, 0),
                         tests=sorted(tmap.get(m, []))))
    agg = defaultdict(lambda: Counter())
    for d in data:
        c = agg[d['cat']]
        c['maps'] += 1; c['cases'] += d['cases']; c['empty'] += d['empty']; c['variants'] += d['variants']
        c['no_test'] += 0 if d['tests'] else 1
    lines = ['# 事件／难度验收盘点（自动生成）', '',
             '切片地图 %d；地图事件页用例 %d（另公共事件 %d）；空绿 %d 地图页 + %d 公共事件；变体 %d 地图 + %d 公共事件。' % (
                 len(data), sum(cases.values()), ce_cases, sum(empty.values()), empty_ce, sum(pres.values()), pres_ce), '',
             '| 类别 | 地图 | 事件页用例 | 空绿 | 空绿占比 | 状态变体 | 没有任何专项点名的地图 |', '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    for k, c in agg.items():
        lines.append('| %s | %d | %d | %d | %.0f%% | %d | %d |' % (k, c['maps'], c['cases'], c['empty'], 100 * c['empty'] / max(1, c['cases']), c['variants'], c['no_test']))
    lines += ['', '## 逐图', '', '| 地图 | 名称 | 类别 | 事件页 | 空绿 | 变体 | 点名专项 |', '| ---: | --- | --- | ---: | ---: | ---: | --- |']
    for d in data:
        t = '、'.join(d['tests'][:4]) + ('…+%d' % (len(d['tests']) - 4) if len(d['tests']) > 4 else '')
        lines.append('| %d | %s | %s | %d | %d | %d | %s |' % (d['map'], d['name'], d['cat'], d['cases'], d['empty'], d['variants'], t or '无'))
    md = '\n'.join(lines) + '\n'
    if a.md:
        Path(a.md).write_text(md)
    if a.json:
        Path(a.json).write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(md if not a.md else '\n'.join(lines[:12]))


main()
