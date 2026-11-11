#!/usr/bin/env python3
"""状态备注触发的战斗公共事件补查（cc 车道 cc/ge9-state-notes，2026-11-11；只读，不改游戏数据与代码）。

盘点.py 的名单（同 ../bonly.py）不扫状态备注。这里补上：状态备注 <Custom … Effect> 里 $gameTemp.reserveCommonEvent(N)
且 N 不在 盘点.py 名单里的公共事件，逐个给出
  触发状态与时机（原版备注）、转换产物里这段有没有翻成预约（phase_call reserve／reserve_common_event）、
  谁加这个状态（盘点.py state_reach 的粗口径）、Godot 实跑（整跑＋逐条单跑）有没有跳过的指令、
  测试／夹具／探针点名、没对照过的写法。
人工核过的结论写在同目录 状态备注补查_结论.json（事件 id → {category, reachable, evidence, note}），本脚本只负责合表。

用法：状态备注补查.py [--generated 目录] [--run run.json] [--out-dir 目录]   （缺 run 时经 占槽.py 跑一次 Godot，约 1 分钟）
产物：out-dir/状态备注补查.json、状态备注补查.md、状态备注补查_run.json
"""
import argparse
import importlib.util
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('pandian', HERE / '盘点.py')
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

TAG = re.compile(r'<(Custom [A-Za-z ]+ Effect)>(.*?)</\1>', re.S)
RES = re.compile(r'reserveCommonEvent\(\s*(\d+)\s*\)')


def reserves_in(effects):
    """转换产物状态 effects 里预约的公共事件：{phase: [id…]}"""
    out = {}

    def walk(v, phase):
        if isinstance(v, dict):
            if v.get('op') == 'phase_call' and v.get('name') == 'reserve':
                out.setdefault(phase, []).append(int(v['args'][0]['value']))
            for x in v.values():
                walk(x, phase)
        elif isinstance(v, list):
            for x in v:
                walk(x, phase)
    for e in effects or []:
        if e.get('op') == 'reserve_common_event':
            out.setdefault(e['phase'], []).append(int(e['id']))
        walk(e.get('program'), e.get('phase'))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--generated', type=Path, default=P.DEFAULT_GEN)
    ap.add_argument('--run', type=Path)
    ap.add_argument('--out-dir', type=Path, default=P.DEFAULT_OUT)
    a = ap.parse_args()
    d = P.Data(a.generated)
    listed, _ = P.battle_only(d)
    src_states = json.load(open(Path(d.manifest['source']) / 'data/States.json'))
    found = {}   # ce → [(状态, 标签, 这段里预约的全部编号)]
    for st in src_states:
        if st and st.get('note'):
            for m in TAG.finditer(st['note']):
                ids = [int(x) for x in RES.findall(m.group(2))]
                for i in ids:
                    if i not in listed:
                        found.setdefault(i, []).append((st['id'], m.group(1), ids))
    ids = sorted(found)
    run_path = a.run or (a.out_dir / '状态备注补查_run.json')
    if not run_path.exists():
        P.run_godot(ids, run_path)
    run = json.load(open(run_path))
    why_state = P.state_reach(d)
    ce_hits, _, case_troops = P.coverage_index()
    ec, map_keys = P.pattern_tools()
    battle_keys = set()
    for i, files in ce_hits.items():
        if any(not f.startswith('代码 ') for f in files) and 0 < i < len(d.ce) and d.ce[i]:
            battle_keys |= P.keys_of(ec, d.ce[i]['list'])
    for t in case_troops:
        if 0 < t < len(d.troops) and d.troops[t]:
            for pg in d.troops[t]['pages']:
                battle_keys |= P.keys_of(ec, pg['list'])
    verdict_path = HERE / '状态备注补查_结论.json'
    verdict = json.load(open(verdict_path)) if verdict_path.exists() else {}
    rows = []
    for i in ids:
        c = d.ce[i]
        r = run.get(str(i), {})
        skips = sorted({str(x['code']) for x in r.get('iso', [])} | {s.split(' ')[0] for s in r.get('full', [])})
        trig = []
        for sid, tag, all_ids in found[i]:
            gen = reserves_in(d.states[sid].get('effects'))
            got = sorted({x for v in gen.values() for x in v})
            shadow = all_ids[-1] != i   # 同一段里后面还有预约：$gameTemp 单槽，被后一个盖掉
            trig.append({'state': sid, 'state_name': d.name('states', sid), 'tag': tag,
                         'translated': i in got, 'overwritten_by': all_ids[-1] if shadow else None,
                         'adders': why_state.get(sid, [])})
        miss = sorted(k for k in P.keys_of(ec, c['list']) if k not in battle_keys and (P.battle_semantic(k) or k not in map_keys))
        v = verdict.get(str(i), {})
        rows.append({'id': i, 'name': c['name'], 'triggers': trig, 'commands': len(P.effective(c['list'])),
                     'skipped': skips, 'named_in': sorted(ce_hits.get(i, [])), 'unmatched_patterns': miss,
                     'category': v.get('category', '未定'), 'reachable': v.get('reachable', ''),
                     'evidence': v.get('evidence', ''), 'note': v.get('note', '')})
    a.out_dir.mkdir(parents=True, exist_ok=True)
    (a.out_dir / '状态备注补查.json').write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    (a.out_dir / '状态备注补查.md').write_text(render(rows))
    from collections import Counter
    print(json.dumps({'total': len(rows), 'by_category': Counter(x['category'] for x in rows)}, ensure_ascii=False))


def render(rows):
    def esc(t):
        return str(t).replace('|', '\\|').replace('\n', ' ')
    from collections import Counter
    cnt = Counter(x['category'] for x in rows)
    out = ['# 状态备注触发的战斗公共事件补查', '',
           '由 `03_转换工具/事件预设脚本/战斗公共事件盘点/状态备注补查.py` 生成，不手改；人工结论在同目录 `状态备注补查_结论.json`。',
           '补的是 [盘点表](盘点表.md) 的盲区：只靠状态备注 `$gameTemp.reserveCommonEvent(N)` 叫起、不在 258 个名单里的公共事件。', '',
           f'共 {len(rows)} 个：' + '、'.join(f'{k} {v}' for k, v in cnt.most_common()) + '。', '',
           '列的意思：「预约已翻」＝转换产物里这个状态这段效果确实翻成了预约本事件；「实跑跳过」＝Godot 战斗事件执行器整跑＋逐条单跑时跳过的指令码（空＝没有）。', '',
           '| 事件 | 名称 | 类别 | 触发状态·时机 | 预约已翻 | 谁加这个状态 | 原版可达 | 指令数 | 实跑跳过 | 覆盖证据 | 备注 |',
           '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for x in rows:
        t = x['triggers']
        trig = '；'.join(f'{y["state"]} {y["state_name"]}·{y["tag"].replace("Custom ", "").replace(" Effect", "")}' for y in t)
        tr = '；'.join(('是' if y['translated'] else (f'否（同段后面的 {y["overwritten_by"]} 盖掉，原版也跑不到）' if y['overwritten_by'] else '否')) for y in t)
        add = '；'.join('、'.join(str(z) for z in y['adders']) or '没找到' for y in t)
        out.append('| ' + ' | '.join(esc(v) for v in (x['id'], x['name'] or '（无名）', x['category'], trig, tr, add, x['reachable'], x['commands'],
                                                     '/'.join(x['skipped']), x['evidence'], x['note'])) + ' |')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    main()
