#!/usr/bin/env python3
"""按空绿扫描的建议批量补事件预设（cc 悟空 accept1；八戒 events4 交付单「可优化」建议的落地）。

在 `事件空绿扫描.py` 的建议（开关、变量、物品…）之外，把「$gameSystem.playtime() - $gameVariables.value(N) >= K」
这类计时门补成「变量 N ＝ -100000」（水栽培 Map187 的菜地全靠它，扫描建议里没有）。
同一张图里页面内容和建议完全相同的事件只留一个代表（dedupe），避免上千条等价变体。
用法：补预设批量.py --map 187 [--tag a1] [--dry-run] [--limit N]
      补预设批量.py --only-ce [--tag c1]   只吃公共事件（ceN）的空绿（cc 悟空 accept3）
"""
import argparse, functools, hashlib, json, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'
PRESETS = HERE / 'event_presets.json'
ACTOR_VAR_RE = re.compile(r'\$gameActors\.actor\(\s*\$gameVariables\.value\((\d+)\)\s*\)')
TIME_RE = re.compile(r'playtime\(\)\s*-\s*\$gameVariables\.value\((\d+)\)\s*>=?\s*\d+')


def scan_rows():
    out = subprocess.run([sys.executable, str(HERE / '事件空绿扫描.py'), '--top', '0', '--out', '/dev/stdout'], capture_output=True, text=True).stdout
    return json.JSONDecoder().raw_decode(out[out.index('{"total"'):] if '{"total"' in out else out[out.index('{'):])[0]['rows']


@functools.lru_cache(maxsize=None)
def _json(path):
    return json.loads(Path(path).read_text())


def page_of(rid):
    mc = re.match(r'ce(\d+)$', rid)
    if mc:
        ces = _json(str(GEN / 'db/CommonEvents.json'))
        return ces[int(mc[1])]
    m = re.match(r'm(\d+)e(\d+)p(\d+)$', rid)
    if not m:
        return None
    mp = _json(str(GEN / 'maps' / ('Map%03d.json' % int(m[1]))))
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
    based = {c['base'] for c in data['cases']}
    new = []
    # accept4：已有预设的「同图同页内容同预设」也算见过（换个 tag 重跑不再把 accept1 去重掉的等价事件重新加回来）
    seen = set()
    for c in data['cases']:
        pg = page_of(c['base'])
        if pg is not None:
            mp = 'ce' if c['base'].startswith('ce') else int(re.match(r'm(\d+)', c['base'])[1])
            seen.add((mp, hashlib.md5(json.dumps(pg['list'], sort_keys=True).encode()).hexdigest(), json.dumps(c['preset'], sort_keys=True)))
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
            # accept4：脚本按变量取角色（学习强者之心等「$gameActors.actor($gameVariables.value(857))」），变量为 0 时取不到角色、
            # 一条效果都走不到：设成开局队首角色 1（扫描建议不看脚本）
            if c['code'] in (355, 655) and not preset.get('variables'):
                for v in ACTOR_VAR_RE.findall(str(c['parameters'][0])):
                    preset.setdefault('variables', {})[v] = 1
            # accept4：指定角色「遗忘技能」（318 [0, 角色, 1, 技能]）在角色本来就没学时看不出变化：先让它学会
            # accept5：条件分歧「玩家朝向」（111 [6, -1, 方向]）：扫描只记 cond6 不给建议，预设玩家面朝第一条要的方向
            if c['code'] == 111 and c['parameters'][0] == 6 and c['parameters'][1] == -1 and 'playerDirection' not in preset:
                preset['playerDirection'] = c['parameters'][2]
            if c['code'] == 318 and c['parameters'][0] == 0 and c['parameters'][2] == 1 and not r['suggest']:
                ac = preset.setdefault('actors', {}).setdefault(str(c['parameters'][1]), {})
                ac.setdefault('skills', []).append(c['parameters'][3])
        if not preset:
            continue
        key = ('ce' if a.only_ce else r['map'], hashlib.md5(json.dumps(pg['list'], sort_keys=True).encode()).hexdigest(), json.dumps(preset, sort_keys=True))
        if key in seen or (r['id'], a.tag) in have or r['id'] in based:
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
