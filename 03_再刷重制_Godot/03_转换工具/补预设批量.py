#!/usr/bin/env python3
"""按空绿扫描的建议批量补事件预设（cc 悟空 accept1；八戒 events4 交付单「可优化」建议的落地）。

在 `事件空绿扫描.py` 的建议（开关、变量、物品…）之外，把「$gameSystem.playtime() - $gameVariables.value(N) >= K」
这类计时门补成「变量 N ＝ -100000」（水栽培 Map187 的菜地全靠它，扫描建议里没有）。
同一张图里页面内容和建议完全相同的事件只留一个代表（dedupe），避免上千条等价变体。
用法：补预设批量.py --map 187 [--tag a1] [--dry-run] [--limit N]
      补预设批量.py --only-ce [--tag c1]   只吃公共事件（ceN）的空绿（cc 悟空 accept3）
"""
import argparse, hashlib, json, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'
PRESETS = HERE / 'event_presets.json'
TIME_RE = re.compile(r'playtime\(\)\s*-\s*\$gameVariables\.value\((\d+)\)\s*>=?\s*\d+')


def scan_rows():
    out = subprocess.run([sys.executable, str(HERE / '事件空绿扫描.py'), '--top', '0', '--out', '/dev/stdout'], capture_output=True, text=True).stdout
    return json.JSONDecoder().raw_decode(out[out.index('{"total"'):] if '{"total"' in out else out[out.index('{'):])[0]['rows']


def page_of(rid):
    mc = re.match(r'ce(\d+)$', rid)
    if mc:
        ces = json.loads((GEN / 'db/CommonEvents.json').read_text())
        return ces[int(mc[1])]
    m = re.match(r'm(\d+)e(\d+)p(\d+)$', rid)
    if not m:
        return None
    mp = json.loads((GEN / 'maps' / ('Map%03d.json' % int(m[1]))).read_text())
    ev = next(e for e in mp['events'] if e and e['id'] == int(m[2]))
    return ev['pages'][int(m[3])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--map', type=int, action='append')
    ap.add_argument('--tag', default='a1')
    ap.add_argument('--limit', type=int, default=10 ** 9)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--only-ce', action='store_true', help='只补公共事件空绿（不看 --map）')
    a = ap.parse_args()
    data = json.loads(PRESETS.read_text())
    have = {(c['base'], c['tag']) for c in data['cases']}
    new = []
    seen = set()
    for r in scan_rows():
        if a.only_ce:
            if not r['id'].startswith('ce'):
                continue
        elif a.map and r['map'] not in a.map or not r['id'].startswith('m'):
            continue
        pg = page_of(r['id'])
        preset = json.loads(json.dumps(r['suggest']))
        for c in pg['list']:
            if c['code'] == 111 and c['parameters'][0] == 12:
                for v in TIME_RE.findall(c['parameters'][1]):
                    preset.setdefault('variables', {})[v] = -100000
        if not preset:
            continue
        key = ('ce' if a.only_ce else r['map'], hashlib.md5(json.dumps(pg['list'], sort_keys=True).encode()).hexdigest(), json.dumps(preset, sort_keys=True))
        if key in seen or (r['id'], a.tag) in have:
            continue
        seen.add(key)
        new.append(dict(base=r['id'], tag=a.tag, preset=preset))
        if len(new) >= a.limit:
            break
    print('新增 %d 条预设' % len(new))
    if not a.dry_run:
        data['cases'].extend(new)
        PRESETS.write_text(json.dumps(data, ensure_ascii=False, indent=1))


main()
