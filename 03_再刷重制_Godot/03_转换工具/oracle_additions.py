"""保守识别扩切片的新增测量；既有用例必须逐条相同，未知结构不自动接受。"""
import collections
import hashlib
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
    'battle_events.json': {'cases': ('id',)},
    'challenge_passives.json': {'cases': ('id',)},
    'zhenqi.json': {'cases': ('id',)},
    'guide.json': {'cases': ('id',)},
    'custom_damage.json': {'cases': ('id',)},
    'formula_programs.json': {'cases': ('id',)},
    'formula_effects.json': {'cases': ('id',)},
    'formula_equipment.json': {'cases': ('id',)},
    'formula_actions.json': {'cases': ('id',)},
    'review_fix.json': {'cases': ('id',)},
    'imported_balance.json': {'cases': ('id',)},
    'state_effects.json': {'cases': ('id',)},
    # turnPreset 例（回合计数预置）与同敌群的开局例分开成组，新增这类例才算「新键」而非同键追加
    'troop_events.json': {'cases': lambda row: ('troop', 'paid', 'turnPreset') if 'turnPreset' in row else ('troop', 'paid')},
    'smart_ai.json': {'cases': ('troop', 'scene', 'actor', 'state'),
                      'damage': ('troop', 'actor', 'skill', 'target')},
    'shop_buy.json': {'shops': ('map', 'event', 'raw'), 'goods': ('goods',),
                      'cases': ('goods', 'state')},
    'power.json': {'actors': ('id', 'level', 'asked'), 'gear': ('kind', 'id', 'why')},
    'actor_passive.json': {'cases': ('setup',)},
    'wtype.json': {'cases': ('actor', 'variant', 'weapon', 'skill')},
    'dual_wield.json': {'flows': ('name',), 'inits': ('actor', 'ids'), 'setups': ('actor',)},
    'magic_weapon.json': {'cases': ('name',)},
    'custom_params.json': {'cases': ('name',)},
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


def digest(row):
    return hashlib.sha256(canonical(row).encode()).hexdigest()[:16]


def changed_fields(old, new):
    if not isinstance(old, dict) or not isinstance(new, dict):
        return ['*']
    return sorted(k for k in old.keys() | new.keys() if k not in old or k not in new or old[k] != new[k])


def augmented(old_rows, new_rows):
    """旧组每条行都对上一条「原字段逐项相同、只多字段」的新行，条数相同：返回多出的字段名；否则 None。"""
    old = [json.loads(r) for r, n in old_rows.items() for _ in range(n)]
    new = [json.loads(r) for r, n in new_rows.items() for _ in range(n)]
    if len(old) != len(new) or not all(isinstance(r, dict) for r in old + new):
        return None
    extra, used = set(), [False] * len(new)
    # 字段多的旧行先配，避免子集行抢走别人的对应行
    for row in sorted(old, key=len, reverse=True):
        for i, cand in enumerate(new):
            if not used[i] and all(k in cand and cand[k] == v for k, v in row.items()):
                used[i] = True
                extra |= cand.keys() - row.keys()
                break
        else:
            return None
    return sorted(extra) if extra else None


def has_error(x):
    if isinstance(x, dict):
        if x.get('error') or x.get('errors') or x.get('finished') is False:
            return True
        return any(has_error(v) for v in x.values())
    return isinstance(x, list) and any(has_error(v) for v in x)



def retained_errors_unchanged(name, old, new):
    """Only permit already recorded failing rows, never a new/changed failure.

    Healthy measurement changes belong to the normal report/comparison stage.
    For unknown collections or errors outside keyed rows, require the entire
    failing value to match. Repeated rows are counted, so duplicating a known
    failure cannot make it through this guard.
    """
    old, new = payload(old), payload(new)
    if not has_error(new):
        return True
    if old == new:
        return True
    if not isinstance(old, dict) or not isinstance(new, dict):
        return False
    if new.get('error') or new.get('errors') or new.get('finished') is False:
        return False  # Root failures have no stable case boundary; exact match was checked above.
    for field, value in new.items():
        if not has_error(value):
            continue
        fields = KEYS.get(name, {}).get(field)
        previous = old.get(field)
        if fields and isinstance(value, list) and isinstance(previous, list):
            try:
                groups([row for row in value if has_error(row)], fields)
            except ValueError:
                return False
            known = collections.Counter(canonical(row) for row in previous if has_error(row))
            current = collections.Counter(canonical(row) for row in value if has_error(row))
            if current - known:
                return False
        elif value != previous:
            return False
    return True


def valid_level_samples(samples):
    import math
    if not isinstance(samples, dict) or set(samples) != {'35', '65', '99'}:
        return False
    expected = {'param', 'xparam', 'sparam', 'elementRates', 'level', 'hp', 'mhp'}
    def finite(x):
        return type(x) in (int, float) and math.isfinite(x)
    for level, row in samples.items():
        if not isinstance(row, dict) or set(row) != expected or row['level'] != int(level):
            return False
        for field, size in [('param', 8), ('xparam', 10), ('sparam', 10), ('elementRates', None)]:
            values = row[field]
            if (not isinstance(values, list) or not values or (size is not None and len(values) != size)
                    or not all(finite(x) for x in values)):
                return False
        if not finite(row['hp']) or not finite(row['mhp']):
            return False
    return True


def compare_file(name, old, new, changes=None):
    """返回新增集合与问题。数组按稳定键分组，重复键的组内按多重集逐条精确比较。
    changes：传入列表时，把可经 --accept-changes 显式接受的单条既有用例改变追加进去（各带对应的问题文字）。"""
    old, new = payload(old), payload(new)
    changes = [] if changes is None else changes

    def change(collection, key, a, b, problem):
        if not has_error(b):
            changes.append({'collection': collection, 'key': key, 'fields': changed_fields(a, b),
                            'oldDigest': digest(a), 'newDigest': digest(b), 'problem': problem})
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
        if name == 'formula_programs.json' and field == 'contexts' and isinstance(a, dict) and isinstance(b, dict):
            for key, value in a.items():
                if b.get(key) != value:
                    problems.append('既有公式上下文改变或删除：' + key)
            allowed = {'enemy_actor.full', 'enemy_actor.edge', 'actor_enemy.full', 'actor_enemy.edge'}
            for key in b.keys() - a.keys():
                row = b[key]
                if key not in allowed or not isinstance(row, dict) or set(row) != {'a', 'b', 'v', 's'} or has_error(row):
                    problems.append('新增公式上下文未登记或结构异常：' + key)
                else:
                    additions.append({'collection': field, 'key': key, 'count': 1})
        elif name.startswith('slice_d') and field in ('enemies', 'actors') and isinstance(a, dict) and isinstance(b, dict):
            for key, value in a.items():
                # 角色行允许新增采样字段（如 levelSamples），原有字段必须逐项相同
                if field == 'actors' and key in b and isinstance(value, dict) and isinstance(b[key], dict):
                    if any(k not in b[key] or b[key][k] != v for k, v in value.items()):
                        problems.append('既有角色改变或删除：' + key)
                        change(field, key, value, b[key], problems[-1])
                    elif set(b[key]) - set(value):
                        extra = {k: b[key][k] for k in set(b[key]) - set(value)}
                        samples = extra.get('levelSamples')
                        if (set(extra) != {'levelSamples'} or not valid_level_samples(samples)
                                or has_error(extra)):
                            problems.append('新增角色采样字段无效或有错误：' + key)
                        else:
                            additions.append({'collection': 'actors.fields', 'key': key, 'count': 1})
                    continue
                if key not in b or b[key] != value:
                    problems.append('既有' + ('敌人' if field == 'enemies' else '角色') + '改变或删除：' + key)
                    if key in b:
                        change(field, key, value, b[key], problems[-1])
            for key in b.keys() - a.keys():
                if has_error(b[key]):
                    problems.append('新增' + ('敌人' if field == 'enemies' else '角色') + '有错误：' + key)
                else:
                    additions.append({'collection': field, 'key': key, 'count': 1})
        elif field in keys and isinstance(a, list) and isinstance(b, list):
            try:
                ga, gb = groups(a, keys[field]), groups(b, keys[field])
            except ValueError as error:
                problems.append(str(error)); continue
            for key, value in ga.items():
                if gb.get(key) == value:
                    continue
                extra = augmented(value, gb[key]) if key in gb else None
                if extra and not any(has_error(json.loads(row)) for row in gb[key]):
                    additions.append({'collection': field + '.fields', 'key': key, 'count': sum(gb[key].values()),
                                      'fields': extra})
                    continue
                problems.append(field + ' 既有用例改变、删除或同键追加：' + key[:160])
                if key in gb and sum(value.values()) == 1 and sum(gb[key].values()) == 1:
                    change(field, key, json.loads(next(iter(value))), json.loads(next(iter(gb[key]))), problems[-1])
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
    additions, problems, changes = {}, {}, {}
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
        found = []
        try:
            added, bad = compare_file(name, json.loads(old.read_text()), json.loads(new.read_text()), found)
        except (ValueError, OSError) as error:
            added, bad, found = [], ['无法读取参照：' + str(error)], []
        if added:
            additions[name] = added
        if bad:
            problems[name] = bad
        if found:
            changes[name] = found
    return {'onlyAdditions': bool(additions) and not problems, 'additions': additions, 'problems': problems,
            'changes': changes}


ACCEPT_FIELDS = ('file', 'collection', 'key', 'fields', 'oldDigest', 'newDigest', 'reason')


def load_acceptances(paths):
    """读接受单；格式不对直接报错（不当作空单）。返回 (条目列表, 接受单摘要)。"""
    entries, sources = [], []
    for path in paths:
        raw = Path(path).read_bytes()
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get('schema') != 1 or not isinstance(data.get('accept'), list) or not data['accept']:
            raise ValueError('接受单须为 {"schema": 1, "accept": [...]}，且至少一条：' + str(path))
        for row in data['accept']:
            if (not isinstance(row, dict) or set(row) != set(ACCEPT_FIELDS)
                    or not all(isinstance(row[k], str) and row[k] for k in ACCEPT_FIELDS if k != 'fields')
                    or not isinstance(row['fields'], list) or not row['fields']
                    or not all(isinstance(f, str) and f for f in row['fields'])
                    or len(row['reason'].strip()) < 4):
                raise ValueError('接受单条目须恰有 %s 七项、fields 非空、理由至少 4 字：%s' % ('／'.join(ACCEPT_FIELDS), path))
            entries.append(dict(row, fields=sorted(row['fields']), source=str(path)))
        sources.append({'path': str(path), 'sha256': hashlib.sha256(raw).hexdigest()})
    seen = collections.Counter((e['file'], e['collection'], e['key']) for e in entries)
    dup = [k for k, n in seen.items() if n > 1]
    if dup:
        raise ValueError('接受单有重复条目：' + str(dup[0]))
    return entries, sources


def apply_acceptances(check, entries):
    """逐条对上 changes 里的单条既有用例改变，被接受的从问题里去掉；对不上的条目留在 unused。"""
    problems = {k: list(v) for k, v in check['problems'].items()}
    accepted, unused = [], []
    for e in entries:
        hit = next((c for c in check.get('changes', {}).get(e['file'], [])
                    if c['collection'] == e['collection'] and c['key'] == e['key'] and c['fields'] == e['fields']
                    and c['oldDigest'] == e['oldDigest'] and c['newDigest'] == e['newDigest']
                    and c['problem'] in problems.get(e['file'], [])), None)
        if hit is None:
            unused.append({k: e[k] for k in ACCEPT_FIELDS[:6]})
            continue
        problems[e['file']].remove(hit['problem'])
        if not problems[e['file']]:
            del problems[e['file']]
        accepted.append({k: e[k] for k in ACCEPT_FIELDS + ('source',)})
    return {'problems': problems, 'accepted': accepted, 'unused': unused}


def change_candidates(check):
    """报告里给人看的可接受变化（不含理由）；只列出，不自动生成接受单。"""
    return [{'file': name, **{k: c[k] for k in ACCEPT_FIELDS[1:6]}}
            for name, rows in sorted(check.get('changes', {}).items()) for c in rows]


def source_preserved(old, new):
    """只允许同一正式版本与运行脚本，旧输入必须原样存在；扩切片可增加输入。"""
    return (old.get('releaseVersion') == new.get('releaseVersion')
            and bool(old.get('runtimeInputs')) and old.get('runtimeInputs') == new.get('runtimeInputs')
            and bool(old.get('inputs'))
            and all(new.get('inputs', {}).get(k) == v for k, v in old['inputs'].items()))
