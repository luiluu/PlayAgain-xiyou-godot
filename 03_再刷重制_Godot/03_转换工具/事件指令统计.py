#!/usr/bin/env python3
"""统计正式西游全部地图事件与公共事件用到的事件指令，按出现次数排序，并标出 Godot 解释器（MVInterpreter._execute）
已处理与未处理的指令；插件指令（356）与脚本（355/655）按开头写法归类。只读正式应用，输出 JSON 报告。

用法：事件指令统计.py [--app 正式 app.nw] [--out 报告.json]
用来决定「先翻译哪些指令能覆盖最多内容」。"""
import argparse
import collections
import json
import re
from pathlib import Path

from xiyou_export import DEFAULT_APP

HERE = Path(__file__).resolve().parent
INTERP = HERE.parent / '01_Godot工程/modes/xiyou/map/mv_interpreter.gd'
NAMES = {101: '显示文字', 401: '文字行', 102: '显示选项', 402: '选项分支', 403: '取消分支', 404: '选项结束', 103: '数值输入', 104: '选择物品',
         105: '滚动文字', 108: '注释', 408: '注释行', 111: '条件分歧', 411: '否则', 412: '分歧结束', 112: '循环', 413: '循环结束', 113: '跳出循环',
         115: '中止事件', 117: '公共事件', 118: '标签', 119: '跳转标签', 121: '开关', 122: '变量', 123: '独立开关', 124: '计时器', 125: '金钱',
         126: '物品', 127: '武器', 128: '防具', 129: '队伍成员', 132: '战斗BGM', 133: '胜利ME', 134: '禁止存档', 135: '禁止菜单', 136: '禁止遇敌',
         137: '禁止整队', 138: '窗口色调', 139: '战败ME', 140: '载具BGM', 201: '场所移动', 202: '载具位置', 203: '事件位置', 204: '地图滚动',
         205: '移动路线', 505: '移动路线行', 206: '乘降载具', 211: '透明', 212: '显示动画', 213: '显示气泡', 214: '暂时消除', 216: '队伍跟随',
         217: '集合', 221: '淡出', 222: '淡入', 223: '画面色调', 224: '画面闪烁', 225: '画面震动', 230: '等待', 231: '显示图片', 232: '移动图片',
         233: '旋转图片', 234: '图片色调', 235: '消除图片', 236: '天气', 241: 'BGM', 242: 'BGM淡出', 243: '保存BGM', 244: '恢复BGM', 245: 'BGS',
         246: 'BGS淡出', 249: 'ME', 250: 'SE', 251: '停止SE', 261: '影片', 281: '地图名显示', 282: '图块组', 283: '战斗背景', 284: '远景',
         285: '获取位置信息', 301: '战斗处理', 601: '胜利分支', 602: '逃跑分支', 603: '战败分支', 604: '战斗分支结束', 302: '商店', 605: '商品行',
         303: '名字输入', 311: 'HP', 312: 'MP', 326: 'TP', 313: '状态', 314: '完全恢复', 315: '经验', 316: '等级', 317: '能力值', 318: '技能',
         319: '装备', 320: '名字', 321: '职业', 322: '角色图像', 323: '载具图像', 324: '昵称', 325: '简介', 331: '敌人HP', 332: '敌人MP',
         342: '敌人TP', 333: '敌人状态', 334: '敌人完全恢复', 335: '敌人出现', 336: '敌人变身', 337: '战斗动画', 339: '强制行动', 340: '中止战斗',
         351: '打开菜单', 352: '打开存档', 353: '游戏结束', 354: '返回标题', 355: '脚本', 655: '脚本行', 356: '插件指令', 0: '结束'}
# 不需要单独翻译的续行/结构码
STRUCT = {0, 401, 402, 403, 404, 408, 411, 412, 413, 505, 601, 602, 603, 604, 605, 655}


def handled_codes() -> set:
    codes = set()
    for line in INTERP.read_text().splitlines():
        m = re.match(r'^\t\t(\d+(?:, \d+)*):', line)
        if m:
            codes.update(int(x) for x in m.group(1).split(', '))
    return codes


def walk(lists, counts, plugins, scripts, places, where):
    for cmds in lists:
        i = 0
        while i < len(cmds):
            c = cmds[i]
            code = c.get('code', 0)
            counts[code] += 1
            places[code].add(where)
            if code == 356:
                plugins[str(c['parameters'][0]).split(' ')[0]] += 1
            elif code == 355:
                text = str(c['parameters'][0])
                j = i + 1
                while j < len(cmds) and cmds[j].get('code') == 655:
                    text += '\n' + str(cmds[j]['parameters'][0])
                    j += 1
                head = re.sub(r'\d+', 'N', text.strip().split('\n')[0])[:60]
                scripts[head] += 1
            i += 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--app', type=Path, default=DEFAULT_APP)
    ap.add_argument('--out', type=Path)
    a = ap.parse_args()
    data = a.app / 'data'
    counts, plugins, scripts = collections.Counter(), collections.Counter(), collections.Counter()
    places = collections.defaultdict(set)
    maps = sorted(data.glob('Map[0-9][0-9][0-9].json'))
    for f in maps:
        m = json.loads(f.read_text())
        lists = [p['list'] for e in m.get('events', []) if e for p in e.get('pages', [])]
        walk(lists, counts, plugins, scripts, places, f.stem)
    for ce in json.loads((data / 'CommonEvents.json').read_text()):
        if ce:
            walk([ce['list']], counts, plugins, scripts, places, 'CE%d' % ce['id'])
    for tr in json.loads((data / 'Troops.json').read_text()):
        if tr:
            walk([p['list'] for p in tr.get('pages', [])], counts, plugins, scripts, places, 'Troop%d' % tr['id'])
    done = handled_codes()
    rows = []
    for code, n in counts.most_common():
        if code in STRUCT:
            continue
        rows.append({'code': code, 'name': NAMES.get(code, '?'), 'count': n, 'places': len(places[code]), 'handled': code in done})
    total = sum(r['count'] for r in rows)
    covered = sum(r['count'] for r in rows if r['handled'])
    report = {'maps': len(maps), 'commands': total, 'handledShare': round(covered / max(total, 1), 4),
              'codes': rows, 'plugins': plugins.most_common(60), 'scripts': scripts.most_common(80)}
    text = json.dumps(report, ensure_ascii=False, indent=1)
    if a.out:
        a.out.write_text(text)
    print(json.dumps({'maps': report['maps'], 'commands': total, 'handledShare': report['handledShare'],
                      'topUnhandled': [(r['code'], r['name'], r['count'], r['places']) for r in rows if not r['handled']][:25]}, ensure_ascii=False))


if __name__ == '__main__':
    main()
