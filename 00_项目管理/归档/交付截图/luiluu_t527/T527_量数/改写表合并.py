# T527 返修：照 core/tianqi_skills.gd data() 的顺序把 skill_rework.json 的 tune 六层（D189→D200→D198→D208→D209→D287，开关默认全开）
# 合到 skills／actors／gear 上，返回游戏运行时真正用的改写表。峰值汇总.py、读生命扫描.py 共用。
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '../../../../..'))
DB = os.path.join(ROOT, '03_再刷重制_Godot/01_Godot工程/modes/xiyou')
ORDER = ["D189", "D200", "D198", "D208", "D209", "D287"]  # 同 tianqi_skills.gd:80

def tune_merge(base, patch):  # 同 tianqi_skills.gd tune_merge：字典逐层合并，其余整段换，_ 开头的说明键不进
    out = json.loads(json.dumps(base))
    for k, v in patch.items():
        if str(k).startswith('_'):
            continue
        out[k] = tune_merge(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out

def merged():
    d = json.load(open(os.path.join(DB, 'tianqi_data/skill_rework.json')))
    touched = {}
    for key in ORDER:
        t = d.get('tune', {}).get(key, {})
        for sec in ('skills', 'actors', 'gear'):
            for k, v in t.get(sec, {}).items():
                if str(k).startswith('_'):
                    continue
                cur = d.setdefault(sec, {}).get(k)
                d[sec][k] = tune_merge(cur if isinstance(cur, dict) else {}, v)
                if sec == 'skills':
                    touched.setdefault(k, []).append(key)
    d['_touched'] = touched  # 每招被哪几层 tune 改过
    return d
