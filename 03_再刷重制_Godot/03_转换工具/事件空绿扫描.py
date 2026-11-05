#!/usr/bin/env python3
"""事件对照「空绿」扫描（cc 八戒 events2，只读）。

事件对照（tests/xiyou_event_compare）每个用例都从同一个新游戏出发：队伍 1/8/10/9、难度 3、开关变量全空。
有些用例在这个初始状态下根本走不到有效果的分支（条件分歧把效果全挡住），参照与重制都「什么也没做」，
对照一致＝空绿，重制做没做都绿。本工具扫 generated/oracle/events.json 的每个用例，加上 generated/maps、
CommonEvents 里的指令列表，找出这些用例，按「玩家可达＋影响」排序。

分类（status）：
- 全空：trace 与 delta 都空，但指令里有效果指令（切走了全部效果）。
- 挡住：delta 空、trace 只有文字，效果指令全在条件分歧里面（初始状态没满足）。
- 半空：delta 非空，但仍有效果指令藏在没走到的条件分歧里（只计数，不进排序表）。
纯对话（没有任何效果指令）不算空绿。

排序（score 越大越靠前）：可达档（页面出现条件为空→3；条件都是「会被某个事件打开」的开关→2；否则→1）
× 楼层地图（地图名含「层」）×3 × 难度相关（指令里出现难度）×2 × 被挡住的效果指令数（封顶 20）。
每个用例附「建议初始状态」：从挡住它的条件分歧里直接读出（开关开、变量比较、持有物品、金钱、角色在队），
供写参照预设（03_转换工具/event_presets.json）时抄。

用法：事件空绿扫描.py [--top N] [--out 报告.json] [--check] [--update-baseline]
  --check            与 事件空绿基线.json 比：空绿用例新增（基线外）→ 退出 1；已补上的提示更新基线
  --update-baseline  用本次结果重写基线（只存用例号与分类）
预设里补过的用例（event_presets.json 里有 base）算已补，不进空绿清单；同图里指令列表逐条相同的页跟着代表页算已补（events7b）。
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'
BASELINE = HERE / '事件空绿基线.json'
PRESETS = HERE / 'event_presets.json'

# 效果指令：改状态或改世界（对照的 delta／trace 能看见的那类）
EFFECT = {121, 122, 123, 125, 126, 127, 128, 129, 134, 135, 136, 137, 201, 223, 236, 301, 302, 303, 311, 312, 313, 314, 315, 316, 317,
          318, 319, 320, 321, 324, 325, 355, 356, 117, 352, 353, 354}
SKIP = {0, 401, 402, 403, 404, 408, 411, 412, 413, 505, 601, 602, 603, 604, 605, 655, 108}
DIFF_RE = re.compile(r'[Dd]ifficult|难度')


def cond_text(p):
    """111 条件分歧的参数 → (可读文字, 建议初始状态片段 dict 或 None)。"""
    t = p[0]
    if t == 0:  # 开关
        return 'switch %d %s' % (p[1], 'ON' if p[2] == 0 else 'OFF'), ({'switches': {str(p[1]): True}} if p[2] == 0 else None)
    if t == 1:  # 变量
        ops = ['==', '>=', '<=', '>', '<', '!=']
        rhs = ('var %d' % p[3]) if p[2] == 1 else str(p[3])
        text = 'var %d %s %s' % (p[1], ops[p[4]], rhs)
        if p[2] == 0:
            v = p[3]
            want = {0: v, 1: v, 2: v, 3: v + 1, 4: v - 1, 5: v + 1}[p[4]]
            return text, {'variables': {str(p[1]): want}}
        return text, None
    if t == 2:
        return 'selfSwitch %s' % p[1], None
    if t == 4:  # 角色
        kinds = ['在队', '名字', '职业', '技能', '武器', '防具', '状态']
        text = 'actor %d %s %s' % (p[1], kinds[p[2]], p[3] if len(p) > 3 else '')
        if p[2] == 0:
            return text, {'party': [p[1]]}
        if p[2] == 3:
            return text, {'party': [p[1]], 'actors': {str(p[1]): {'skills': [p[3]]}}}
        return text, None
    if t == 7:
        text = 'gold %s %d' % (['>=', '<=', '<'][p[2]], p[1])
        return text, ({'gold': p[1] if p[2] != 2 else max(p[1] - 1, 0)} if p[2] != 1 else None)
    if t == 8:
        return 'item %d' % p[1], {'items': {str(p[1]): 1}}
    if t == 9:
        return 'weapon %d' % p[1], {'weapons': {str(p[1]): 1}}
    if t == 10:
        return 'armor %d' % p[1], {'armors': {str(p[1]): 1}}
    if t == 12:
        return 'script %s' % str(p[1])[:50], None
    return 'cond%d' % t, None


def analyze(lst):
    """返回 eff（效果指令数）、eff_free（不在条件分歧里的）、eff_guarded、guards（挡住效果的条件链）、diff（出现难度）、calls（117）。"""
    eff = eff_free = eff_guarded = 0
    guards = []
    stack = []  # [indent, 条件文字, 建议, 是否 else 支]
    diff = False
    calls = []
    for c in lst:
        code, ind, p = c['code'], c['indent'], c.get('parameters', [])
        if code == 411:
            if stack and stack[-1][0] == ind:
                stack[-1][3] = True
            continue
        if code == 412:
            while stack and stack[-1][0] >= ind:
                stack.pop()
            continue
        if code == 111:
            txt, sug = cond_text(p)
            stack.append([ind, txt, sug, False])
            if p[0] == 12 and DIFF_RE.search(str(p[1])):
                diff = True
            continue
        if code in (355, 655, 356) and DIFF_RE.search(str(p[0] if p else '')):
            diff = True
        if code in SKIP:
            continue
        if code in EFFECT:
            eff += 1
            if code == 117:
                calls.append(p[0])
            if stack:
                eff_guarded += 1
                guards.append(tuple((s[1], s[2], s[3]) for s in stack))
            else:
                eff_free += 1
    return dict(eff=eff, eff_free=eff_free, eff_guarded=eff_guarded, guards=guards, diff=diff, calls=calls)


def load():
    oracle = json.load(open(GEN / 'oracle/events.json'))['cases']
    manifest = json.load(open(GEN / 'manifest.json'))
    lists, conds, names = {}, {}, {}
    for m in manifest['slice']['maps']:
        mp = json.load(open(GEN / ('maps/Map%03d.json' % m)))
        names[m] = mp.get('displayName') or ''
        for ev in mp['events']:
            if not ev:
                continue
            for pi, pg in enumerate(ev['pages']):
                cid = 'm%de%dp%d' % (m, ev['id'], pi)
                lists[cid] = pg['list']
                conds[cid] = (pg['conditions'], pg['trigger'])
    ces = json.load(open(GEN / 'db/CommonEvents.json'))
    for ce in manifest['slice']['commonEvents']:
        rec = ces[ce] if isinstance(ces, list) else ces[str(ce)]
        lists['ce%d' % ce] = rec['list']
    return oracle, lists, conds, names


def settable_switches(lists):
    s = set()
    for lst in lists.values():
        for c in lst:
            if c['code'] == 121:
                s.update(range(c['parameters'][0], c['parameters'][1] + 1))
    return s


def reach(cond, settable):
    """页面出现条件 → 可达档：3 无条件；2 条件只依赖会被打开的开关／其它；1 要永远不会被打开的开关。"""
    if cond is None:
        return 3
    cd, _ = cond
    if not (cd['switch1Valid'] or cd['switch2Valid'] or cd['variableValid'] or cd['selfSwitchValid'] or cd['itemValid'] or cd['actorValid']):
        return 3
    for k in ('switch1', 'switch2'):
        if cd[k + 'Valid'] and cd[k + 'Id'] not in settable:
            return 1
    return 2


def scan():
    oracle, lists, conds, names = load()
    settable = settable_switches(lists)
    presets = json.load(open(PRESETS))['cases'] if PRESETS.exists() else []
    # 只有「变体真的量到东西」的基础用例才算已补；变体仍无 delta 也无非文字 trace 的（观察面不够）继续留在空绿清单（审查 41 P3-5）
    quiet_ids = set(check_variants()[2])
    covered = {p['base'] for p in presets if '%s#%s' % (p['base'], p['tag']) not in quiet_ids}
    # 同一张图里指令列表逐条相同的页（黑作坊 Map217～219 每台机器 6 种晶石共用一页计时门）：代表页的预设量到东西，其余几页同样算补上
    # （补预设批量.py 按同样的口径只给代表页写预设）。公共事件各自独立，不参与。events7b
    def same_page(cid):
        m = re.match(r'm(\d+)e\d+p\d+$', cid)
        return (m[1], json.dumps(lists[cid], sort_keys=True)) if m and cid in lists else None
    covered_pages = {same_page(b) for b in covered} - {None}
    rows = []
    half = 0
    for c in oracle:
        cid = c['id']
        lst = lists.get(cid)
        if lst is None:
            continue
        a = analyze(lst)
        if a['eff'] == 0:
            continue
        only_msg = all(t.get('t') == 'msg' for t in c['trace'])
        if c['delta']:
            if a['eff_guarded']:
                half += 1
            continue
        if not c['trace']:
            status = '全空'
        elif only_msg and a['eff_free'] == 0:
            status = '挡住'
        else:
            continue  # delta 空但 trace 里有场所移动／战斗／商店等可观察效果，不算空
        if cid in covered or same_page(cid) in covered_pages:
            continue
        mapname = names.get(c.get('map'), '') if c['kind'] == 'map' else ''
        r = reach(conds.get(cid), settable)
        floor = '层' in mapname
        # 建议初始状态：取第一条（不含 else 支的）条件链里能直接读出的片段
        sug = {}
        for g in a['guards']:
            if any(x[2] for x in g):  # else 支：新游戏会走，跳过
                continue
            for _, s, _ in g:
                if s:
                    for k, v in s.items():
                        if isinstance(v, dict):
                            sug.setdefault(k, {}).update(v)
                        elif isinstance(v, list):
                            sug.setdefault(k, []).extend(x for x in v if x not in sug.get(k, []))
                        else:
                            sug[k] = v
            break
        guard_txt = sorted({x[0] for g in a['guards'] for x in g})[:6]
        score = r * (3 if floor else 1) * (2 if a['diff'] else 1) * min(max(a['eff_guarded'], 1), 20)
        rows.append(dict(id=cid, status=status, map=c.get('map'), mapName=mapname, reach=r, floor=floor, difficulty=a['diff'],
                         hiddenEffects=a['eff_guarded'], calls=a['calls'], guards=guard_txt, suggest=sug, score=score))
    rows.sort(key=lambda r: (-r['score'], r['id']))
    return rows, half, len(oracle)


def check_variants():
    """预设 ↔ 量出来的 event_states.json 要对得上；变体不能比基础用例还浅（一条效果指令都没走到＝预设没生效）。"""
    presets = json.load(open(PRESETS))['cases'] if PRESETS.exists() else []
    f = GEN / 'oracle/event_states.json'
    got = {c['id']: c for c in json.load(open(f))['cases']} if f.exists() else {}
    problems = []
    for p in presets:
        vid = '%s#%s' % (p['base'], p['tag'])
        c = got.get(vid)
        if c is None:
            problems.append('%s 在预设里但 event_states.json 没量（先跑 event_state_probe.cjs／同步）' % vid)
        elif c.get('reached', [0, 0])[0] == 0 and c.get('reached', [0, 0])[1] > 0:
            problems.append('%s 一条效果指令都没走到（预设没挡住的那层条件）' % vid)
    for vid in got:
        if vid not in {'%s#%s' % (p['base'], p['tag']) for p in presets}:
            problems.append('%s 在 event_states.json 里但预设已删（产物过期）' % vid)
    quiet = [v for v, c in got.items() if not c['delta'] and all(t.get('t') == 'msg' for t in c['trace'])]
    return problems, len(got), quiet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--top', type=int, default=40)
    ap.add_argument('--out')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--update-baseline', action='store_true')
    args = ap.parse_args()
    rows, half, total = scan()
    by = Counter(r['status'] for r in rows)
    print('用例 %d：空绿 %d（全空 %d、挡住 %d），半空（有效果但另有分支没走到）%d' % (total, len(rows), by['全空'], by['挡住'], half))
    print('按可达档：' + '、'.join('%d档 %d' % (k, v) for k, v in sorted(Counter(r['reach'] for r in rows).items(), reverse=True)),
          '；楼层地图 %d；难度相关 %d' % (sum(r['floor'] for r in rows), sum(r['difficulty'] for r in rows)))
    if not args.check:
        for r in rows[:args.top]:
            print('%-12s %-2s 档%d %s%s 藏%2d 分 %3d  %s  建议 %s' % (r['id'], r['status'], r['reach'], '层' if r['floor'] else '　',
                  '难' if r['difficulty'] else '　', r['hiddenEffects'], r['score'], r['mapName'], json.dumps(r['suggest'], ensure_ascii=False)))
    if args.out:
        Path(args.out).write_text(json.dumps(dict(total=total, empty=len(rows), half=half, rows=rows), ensure_ascii=False, indent=1))
    problems, nvar, quiet = check_variants()
    print('有状态变体 %d 个；仍无 delta 也无非文字 trace（观察面不够）%d 个：%s' % (nvar, len(quiet), ', '.join(quiet[:12])))
    cur = {r['id']: r['status'] for r in rows}
    if args.update_baseline:
        BASELINE.write_text(json.dumps(dict(note='事件空绿扫描的基线：空绿用例（参照在新游戏里走不到效果分支）。补过预设的从这里删掉；新增用例或退回空绿使检查失败。',
                                            total=total, empty=len(cur), cases=cur), ensure_ascii=False, indent=1, sort_keys=True))
        print('已写基线 %d 例' % len(cur))
    if args.check:
        for p in problems:
            print('✗', p)
        if problems:
            return 1
        base = json.load(open(BASELINE))['cases'] if BASELINE.exists() else {}
        new = sorted(set(cur) - set(base))
        gone = sorted(set(base) - set(cur))
        if gone:
            print('已补上，可更新基线（--update-baseline）：%d 例，如 %s' % (len(gone), ', '.join(gone[:5])))
        if new:
            print('✗ 新增空绿 %d 例（基线外）：%s' % (len(new), ', '.join(new[:20])))
            return 1
        print('空绿 %d 例，均在基线内' % len(cur))
    return 0


if __name__ == '__main__':
    sys.exit(main())
