"""战斗消息/敌人变化参照的完整性；不代表 Godot 已实现这些指令。"""
import json

from common_oracle_contract import case_map, identity_issues


# 固定用例目录由 battle_event_probe.cjs 生成的契约确定，不能从待检数据自取。
CASE_IDS = frozenset({
    'scan.inventory',
    'troop165.real-turns1-4',
    'command334.revive-and-recover',
    'command334.living-and-hidden',
    'command336.no-queued-action',
    'command336.rebuild-queued-action',
    'troop824.variable1178-5-hidden',
    'troop824.variable1178-6-appear',
})


def validate_battle_events(data, manifest):
    name = 'battle_events.json'
    issues = []
    try:
        rows = case_map(data)
        if rows.keys() != CASE_IDS:
            issues.append(name + ' 用例集合不完整或出现未登记用例')
        if type(data.get('schemaVersion')) is not int or data['schemaVersion'] != 1:
            issues.append(name + ' 结构版本异常')
        if data.get('hostScope') != 'headless-rule-timing':
            issues.append(name + ' 缺少无画面规则/时机宿主范围')
        if any(row.get('errors') != [] for row in data['cases']):
            issues.append(name + ' 缺少明确的零错误记录')
        scan = data.get('scan', {})
        if not isinstance(scan, dict) or any(not isinstance(scan.get(k), list) for k in
                ['troops', 'maps', 'commonEvents', 'commonEventCallers', 'unresolvedBattles']):
            issues.append(name + ' 缺少完整的冻结源调用目录')
        else:
            troops = scan['troops']
            pages = [p for troop in troops for p in troop['pages']]
            if (len(troops) != 35 or len({troop['id'] for troop in troops}) != 35 or len(pages) != 47
                    or rows.get('scan.inventory') != {'troops': 35, 'pages': 47}):
                issues.append(name + ' 冻结源35敌群47页目录不完整')
        issues.extend(identity_issues(name, data.get('sourceIdentity'), manifest))
    except (KeyError, TypeError, ValueError, AttributeError) as error:
        issues.append(name + ' 参照结构异常：' + str(error))
    return issues


def verify_battle_events(directory, manifest):
    try:
        return validate_battle_events(json.loads((directory / 'battle_events.json').read_text()), manifest)
    except (OSError, ValueError) as error:
        return ['battle_events.json 缺少或不可读：' + str(error)]
