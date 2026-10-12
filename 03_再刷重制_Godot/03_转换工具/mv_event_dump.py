#!/usr/bin/env python3
"""把 MV 事件指令列表打印成可读文本（只读正式西游 data/）。

用法：
  mv_event_dump.py map 1            Map001 全部事件
  mv_event_dump.py map 1 1          Map001 的 1 号事件
  mv_event_dump.py common 12        12 号公共事件
  mv_event_dump.py troop 5          5 号敌群的战斗事件
环境变量 XIYOU_DATA 可改数据目录。
"""
import json
import os
import sys
from pathlib import Path

DATA = Path(os.environ.get('XIYOU_DATA', '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw/data'))
_cache = {}


def table(name):
    if name not in _cache:
        _cache[name] = json.loads((DATA / f'{name}.json').read_text())
    return _cache[name]


def nm(tbl, i):
    try:
        x = table(tbl)[i]
        return f'{i}:{x["name"]}' if x else f'{i}:?'
    except (IndexError, KeyError, TypeError):
        return f'{i}:?'


NAMES = {
    101: '显示文字', 401: '  文', 102: '选项', 402: '  选项分支', 403: '  取消分支', 404: '选项结束', 103: '数值输入', 104: '物品选择',
    105: '滚动文字', 405: '  滚动文', 108: '注释', 408: '  注释', 111: '条件分支', 411: '否则', 412: '分支结束', 112: '循环', 413: '循环结束',
    113: '跳出循环', 115: '中止事件', 117: '公共事件', 118: '标签', 119: '跳转标签', 121: '开关', 122: '变量', 123: '独立开关', 124: '计时器',
    125: '金钱', 126: '物品', 127: '武器', 128: '防具', 129: '队员', 132: '战斗BGM', 133: '胜利ME', 134: '禁止存档', 135: '禁止菜单',
    136: '禁止遇敌', 137: '禁止整队', 138: '窗口颜色', 139: '战败ME', 140: '载具BGM', 201: '场所移动', 202: '载具位置', 203: '事件位置',
    204: '滚动地图', 205: '移动路线', 505: '  路线', 206: '载具乘降', 211: '透明', 212: '显示动画', 213: '显示气泡', 214: '暂时消除',
    216: '跟随', 217: '集合', 221: '淡出', 222: '淡入', 223: '画面色调', 224: '画面闪烁', 225: '画面震动', 230: '等待', 231: '显示图片',
    232: '移动图片', 233: '旋转图片', 234: '图片色调', 235: '消除图片', 236: '天气', 241: 'BGM', 242: 'BGM淡出', 243: '保存BGM', 244: '恢复BGM',
    245: 'BGS', 246: 'BGS淡出', 249: 'ME', 250: 'SE', 251: '停止SE', 261: '影片', 281: '地图名显示', 282: '图块组', 283: '战斗背景',
    284: '远景', 285: '取得位置信息', 301: '战斗', 601: '  胜利', 602: '  逃跑', 603: '  战败', 604: '战斗结束', 302: '商店', 605: '  商品',
    303: '名字输入', 311: 'HP', 312: 'MP', 326: 'TP', 313: '状态', 314: '完全恢复', 315: '经验', 316: '等级', 317: '能力值', 318: '技能',
    319: '装备', 320: '改名', 321: '职业', 322: '角色图像', 323: '载具图像', 324: '昵称', 325: '简介', 331: '敌HP', 332: '敌MP', 342: '敌TP',
    333: '敌状态', 334: '敌完全恢复', 335: '敌出现', 336: '敌变身', 337: '战斗动画', 339: '强制行动', 340: '中止战斗', 351: '菜单', 352: '存档画面',
    353: '游戏结束', 354: '回标题', 355: '脚本', 655: '  脚本', 356: '插件指令', 0: '',
}


def describe(c):
    code, p = c['code'], c['parameters']
    n = NAMES.get(code, f'#{code}')
    if code in (401, 405, 408, 655, 108, 355, 356):
        return f'{n} {p[0]}'
    if code == 101:
        return f'{n} [{p[0]}#{p[1]}]'
    if code == 102:
        return f'{n} {p[0]}'
    if code == 402:
        return f'{n} 「{p[1]}」'
    if code == 117:
        return f'{n} {nm("CommonEvents", p[0])}'
    if code == 129:
        return f'{n} {"加入" if p[1] == 0 else "离开"} {nm("Actors", p[0])}'
    if code == 126:
        return f'{n} {nm("Items", p[0])} {"+" if p[1] == 0 else "-"}{p[3] if p[2] == 0 else "变量" + str(p[3])}'
    if code in (127, 128):
        return f'{n} {nm("Weapons" if code == 127 else "Armors", p[0])} {"+" if p[1] == 0 else "-"}{p[3] if p[2] == 0 else "变量" + str(p[3])}'
    if code == 201:
        return f'{n} 地图{p[1]} ({p[2]},{p[3]})' if p[0] == 0 else f'{n} 变量指定 {p[1:4]}'
    if code == 301:
        return f'{n} {nm("Troops", p[1]) if p[0] == 0 else p}'
    if code == 121:
        return f'{n} {p[0]}..{p[1]} = {"ON" if p[2] == 0 else "OFF"}'
    if code == 302:
        return f'{n} {p}'
    return f'{n} {json.dumps(p, ensure_ascii=False)[:160]}'


def dump(lst, indent0=''):
    for c in lst:
        if c['code'] == 0:
            continue
        print(indent0 + '  ' * c['indent'] + describe(c))


def main(a):
    if not a:
        print(__doc__); return 2
    kind, ident = a[0], int(a[1])
    if kind == 'map':
        m = json.loads((DATA / f'Map{ident:03d}.json').read_text())
        for e in m['events']:
            if not e or (len(a) > 2 and e['id'] != int(a[2])):
                continue
            for i, pg in enumerate(e['pages']):
                print(f'== 事件{e["id"]} {e["name"]} ({e["x"]},{e["y"]}) 页{i + 1} 触发{pg["trigger"]} 图{pg["image"]["characterName"]} 条件{ {k: v for k, v in pg["conditions"].items() if k.endswith("Valid") and v} }')
                dump(pg['list'])
    elif kind == 'common':
        e = table('CommonEvents')[ident]
        print(f'== 公共事件{ident} {e["name"]} 触发{e["trigger"]}')
        dump(e['list'])
    elif kind == 'troop':
        t = table('Troops')[ident]
        print(f'== 敌群{ident} {t["name"]} 成员{[nm("Enemies", m["enemyId"]) for m in t["members"]]}')
        for i, pg in enumerate(t['pages']):
            print(f'-- 页{i + 1}')
            dump(pg['list'])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
