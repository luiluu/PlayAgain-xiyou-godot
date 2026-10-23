#!/usr/bin/env python3
"""冻结正式源 data/Recipes.txt（hc.js Recipe Crafting 配方表）→ Godot 工程 modes/xiyou/recipes.json。

照 hc.js DataManager.createRecipes／createRecipeStruct／Recipe.initialize 读：
- 配方数＝<recipeN> 标记数 / 2，第 i 条取 <recipe i>（[^.]+）<recipe i>；
- result:{type, id, amount}、<materials> 里每行一个 {type, id, amount, cons}；
- goldCost／success／successGain／level／category／xp／xpDeprac／craftLevel／pxp／craftMultiple／known 各取第一处，缺省同 Recipe.initialize。
- 材料的 cons:false 原版不认（Material 读的是 consumed），一律消耗；这里照原样留 cons 字段，运行时不用。
正式源冻结在 v0.28，产物入 Git；用 --check 核对产物与源一致（xiyou_crafting 专项不依赖本脚本）。
用法：python3 配方转换.py [--check]
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / '02_内容与素材/冻结正式源/app.nw/data/Recipes.txt'
OUT = ROOT / '01_Godot工程/modes/xiyou/recipes.json'
CATEGORIES = ["炼金术", "打造", "加工", "珠宝"]   # hc.js 读 PluginManager.parameters('RecipeCrafting')，插件名是 hc，取不到参数，用缺省


def obj(text):
    """JS 对象字面量 {type:"weapon", id:392, amount:1, cons:false} → dict"""
    out = {}
    for k, v in re.findall(r'(\w+)\s*:\s*("[^"]*"|[^,}]+)', text):
        v = v.strip()
        if v.startswith('"'):
            out[k] = v[1:-1]
        elif v in ('true', 'false'):
            out[k] = v == 'true'
        else:
            out[k] = float(v) if '.' in v else int(v)
    return out


def first(body, key):
    m = re.search(key + r':(.+)', body)
    return m.group(1).strip() if m else None


def num(v, default):
    return default if v is None else (float(v) if '.' in v else int(v))


def convert():
    text = SRC.read_text(encoding='utf-8')
    n = len(re.findall(r'<recipe(\d+)>', text)) // 2
    recipes = []
    for i in range(1, n + 1):
        m = re.search(r'<recipe%d>([^.]+)<recipe%d>' % (i, i), text)
        if not m:
            raise SystemExit('配方 %d 读不到' % i)
        body = m.group(1)
        mats = re.search(r'<materials>([^.]+)<materials>', body)
        cat = first(body, 'category')
        recipes.append({
            'id': i,
            'result': obj(first(body, 'result')),
            'materials': [obj(x) for x in re.findall(r'\{[^}]*\}', mats.group(1))],
            'goldCost': num(first(body, 'goldCost'), 0),
            'success': num(first(body, 'success'), 100),
            'successGain': num(first(body, 'successGain'), 0),
            'level': num(first(body, 'level'), 0),
            'category': cat if cat is not None else CATEGORIES[0],
            'xp': num(first(body, 'xp'), 100),
            'xpDeprac': num(first(body, 'xpDeprac'), 0),
            'craftLevel': num(first(body, 'craftLevel'), 1),
            'pxp': num(first(body, 'pxp'), 0),
            'craftMultiple': (first(body, 'craftMultiple') or 'true').lower() == 'true',
            'known': (first(body, 'known') or 'true').lower() == 'true',
        })
    return {'说明': '由 03_转换工具/配方转换.py 从冻结正式源 data/Recipes.txt 生成（hc.js Recipe Crafting），勿手改',
            'categories': CATEGORIES, 'recipes': recipes}


if __name__ == '__main__':
    data = json.dumps(convert(), ensure_ascii=False, indent=0, separators=(',', ':')) + '\n'
    if '--check' in sys.argv:
        ok = OUT.exists() and OUT.read_text(encoding='utf-8') == data
        print('配方产物' + ('一致' if ok else '与源不一致，重跑本脚本'))
        sys.exit(0 if ok else 1)
    OUT.write_text(data, encoding='utf-8')
    print('写入 %s：%d 条配方' % (OUT, len(json.loads(data)['recipes'])))
