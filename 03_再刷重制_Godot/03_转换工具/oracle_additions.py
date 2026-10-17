"""保守识别扩切片的新增测量；既有用例必须逐条相同，未知结构不自动接受。"""
import collections
import json
from pathlib import Path


def payload(data):
    # 只移除顶层来源身份；用例中的 source/identity 等字段仍是测量内容。
    if isinstance(data, dict):
        return {k: v for k, v in data.items() if k not in {'sourceIdentity', 'identity', 'releaseVersion'}}
    return data


KEYS = {
    'events.json': {'cases': ('id',)},
    'dungeon.json': {'cases': ('id',)},
    'shop_stock.json': {'cases': ('id',)},
    'battle_messages.json': {'cases': ('id',)},
    'challenge_passives.json': {'cases': ('id',)},
    'troop_events.json': {'cases': ('troop', 'paid')},
    'smart_ai.json': {'cases': ('troop', 'scene', 'actor', 'state'),
                      'damage': ('troop', 'actor', 'skill', 'target')},
    'shop_buy.json': {'shops': ('map', 'event', 'raw'), 'goods': ('goods',),
                      'cases': ('goods', 'state')},
    'help_cards.json': {k: ('id',) for k in ['skills', 'items', 'weapons', 'armors']},
}


def canonical(x):
    return json.dumps(x, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def groups(rows, fields):
    out = collections.defaultdict(collections.Counter)
    for row in rows:
        selected = fields(row) if callable(fields) and isinstance(row, dict) else fields
        if not isinstance(row, dict) or callable(selected) or any(k not in row for k in selected):
            raise ValueError('用例缺少稳定键：' + str(selected))
        key = canonical([[k, row[k]] for k in selected])
        out[key][canonical(row)] += 1
    return out


def has_error(x):
    if isinstance(x, dict):
        if x.get('error') or x.get('errors') or x.get('finished') is False:
            return True
        return any(has_error(v) for v in x.values())
    return isinstance(x, list) and any(has_error(v) for v in x)


def compare_file(name, old, new):
    """返回新增集合与问题。数组按稳定键分组，重复键的组内按多重集逐条精确比较。"""
    old, new = payload(old), payload(new)
    additions, problems = [], []
    if old == new:
        return additions, problems
    if not isinstance(old, dict) or not isinstance(new, dict):
        return [], ['未知根结构发生变化']
    if name == 'maps.json':
        for key, value in old.items():
            if key not in new or new[key] != value:
                problems.append('既有地图改变或删除：' + key)
        for key in new.keys() - old.keys():
            row = new[key]
            valid = (isinstance(row, dict) and type(row.get('width')) is int and row['width'] > 0
                     and type(row.get('height')) is int and row['height'] > 0
                     and isinstance(row.get('passable'), list) and len(row['passable']) == row['height']
                     and all(isinstance(line, str) and len(line) == row['width']
                             and all(ch in '0123456789abcdef' for ch in line) for line in row['passable']))
            if not key.isdecimal() or not valid or has_error(row):
                problems.append('新增地图结构异常：' + key)
            else:
                additions.append({'collection': 'maps', 'key': key, 'count': 1})
        return additions, problems
    keys = dict(KEYS.get(name, {}))
    if name.startswith('slice_d') and name.endswith('.json'):
        keys['damage'] = lambda row: (('troop', 'actor', 'skill') if 'actor' in row
                                     else ('troop', 'enemy', 'target', 'skill'))
    if set(old) != set(new):
        problems.append('顶层字段集合变化')
    for field in old.keys() & new.keys():
        a, b = old[field], new[field]
        if a == b:
            continue
        if name.startswith('slice_d') and field == 'enemies' and isinstance(a, dict) and isinstance(b, dict):
            for key, value in a.items():
                if key not in b or b[key] != value:
                    problems.append('既有敌人改变或删除：' + key)
            for key in b.keys() - a.keys():
                if has_error(b[key]):
                    problems.append('新增敌人有错误：' + key)
                else:
                    additions.append({'collection': field, 'key': key, 'count': 1})
        elif field in keys and isinstance(a, list) and isinstance(b, list):
            try:
                ga, gb = groups(a, keys[field]), groups(b, keys[field])
            except ValueError as error:
                problems.append(str(error)); continue
            for key, value in ga.items():
                if gb.get(key) != value:
                    problems.append(field + ' 既有用例改变、删除或同键追加：' + key[:160])
            for key in gb.keys() - ga.keys():
                if any(has_error(json.loads(row)) for row in gb[key]):
                    problems.append(field + ' 新用例有错误：' + key[:160])
                else:
                    additions.append({'collection': field, 'key': key, 'count': sum(gb[key].values())})
        else:
            problems.append('非新增用例字段改变：' + field)
    return additions, problems


def case_count(data):
    """整份新参照的用例数：取顶层各列表长度之和；没有列表时按 1 份计。"""
    data = payload(data)
    if isinstance(data, list):
        return len(data)
    if isinstance(data, dict):
        return sum(len(v) for v in data.values() if isinstance(v, list)) or 1
    return 1


def compare_directories(old_dir: Path, new_dir: Path, new_references=frozenset()):
    """new_references：同步脚本 PROBES 登记的产物文件名。本批新增探针第一次生成的整份参照只要没有错误就算新增；
    不在登记里的新文件、任何参照被删除，仍须人工核查。"""
    files = sorted({p.name for d in [old_dir, new_dir] for p in d.glob('*.json')})
    additions, problems = {}, {}
    for name in files:
        old, new = old_dir / name, new_dir / name
        if not old.exists() and new.exists() and name in new_references:
            try:
                data = json.loads(new.read_text())
            except (ValueError, OSError) as error:
                problems[name] = ['无法读取参照：' + str(error)]; continue
            if not data or has_error(payload(data)):
                problems[name] = ['新增参照为空或有错误']
            else:
                additions[name] = [{'collection': '*', 'key': '整份新参照', 'count': case_count(data)}]
            continue
        if not old.exists() or not new.exists():
            problems[name] = ['参照文件新增或删除，须人工核查']; continue
        try:
            added, bad = compare_file(name, json.loads(old.read_text()), json.loads(new.read_text()))
        except (ValueError, OSError) as error:
            added, bad = [], ['无法读取参照：' + str(error)]
        if added:
            additions[name] = added
        if bad:
            problems[name] = bad
    return {'onlyAdditions': bool(additions) and not problems, 'additions': additions, 'problems': problems}


def source_preserved(old, new):
    """只允许同一正式版本与运行脚本，旧输入必须原样存在；扩切片可增加输入。"""
    return (old.get('releaseVersion') == new.get('releaseVersion')
            and bool(old.get('runtimeInputs')) and old.get('runtimeInputs') == new.get('runtimeInputs')
            and bool(old.get('inputs'))
            and all(new.get('inputs', {}).get(k) == v for k, v in old['inputs'].items()))
