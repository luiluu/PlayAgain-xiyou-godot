#!/usr/bin/env python3
"""当前正式西游 → Godot 数据与素材转换（只读正式应用）。

用法：xiyou_export.py [--app <app.nw>] [--out <输出目录>] [--slice xiyou_slice.json]

输出（默认 01_Godot工程/modes/xiyou/generated/，不入 Git，可随时重生成）：
  db/<表>.json     全部数据库表；每条记录附 meta（与 MV DataManager.extractMetadata 相同规则）
                   技能/物品附 formulaGd（翻译成 Godot Expression 的伤害公式，翻译不了为 null）
  maps/MapNNN.json 切片涉及的地图
  db/MapPreview.json MapTransferPlugin 各配置地图的遇敌敌群 ID（地图传送页预览用；切片外地图不导出本体）
  img/…、audio/…   切片实际引用到的素材（原样复制）
  fonts/…          界面字体与授权文件（原样复制）
  manifest.json    输入/输出 SHA-256、未能处理项
"""
import argparse
import ast
import equipment_rules
from formula_program import compile_formula
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import struct
import tempfile
import zlib
from pathlib import Path

TOOL_VERSION = 20
HERE = Path(__file__).resolve().parent
# 用户 2026-10-15：重制期间冻结在 v0.28 的只读副本（不入 Git，见 02_内容与素材/冻结正式源/README.md），重制完成后再统一同步正式版
DEFAULT_APP = Path('/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw')
DEFAULT_OUT = HERE.parent / '01_Godot工程/modes/xiyou/generated'
TABLES = ['Actors', 'Classes', 'Skills', 'Items', 'Weapons', 'Armors', 'Enemies', 'Troops', 'States',
          'Animations', 'CommonEvents', 'Tilesets', 'MapInfos', 'System',
          'CodexDamageElements', 'CodexOrbs', 'CodexRaces']  # 后三张是西游自定义表：伤害元素/克制、法珠、种族
META_RE = re.compile(r'<([^<>:]+)(:?)([^>]*)>')


def normalize_png(data):
    """sips 转出的 PNG 里 iCCP 的 ICC 头带转码时的日期、另有 tIME／eXIf／文本块：源图不变输出也会变，破坏增量同步与指纹。
    只留解码与颜色需要的块（IHDR PLTE tRNS IDAT IEND sRGB gAMA cHRM iCCP），iCCP 的 ICC 头日期（24..36）清零并
    用固定压缩参数重压，CRC 重算；像素数据（IDAT）不动。"""
    keep = {b'IHDR', b'PLTE', b'tRNS', b'IDAT', b'IEND', b'sRGB', b'gAMA', b'cHRM', b'iCCP'}
    out, i = [data[:8]], 8
    while i + 12 <= len(data):
        n, kind = struct.unpack('>I4s', data[i:i + 8])
        body = data[i + 8:i + 8 + n]
        i += 12 + n
        if kind not in keep:
            continue
        if kind == b'iCCP':
            z = body.index(b'\0')
            profile = bytearray(zlib.decompress(body[z + 2:]))
            profile[24:36] = bytes(12)
            body = body[:z + 2] + zlib.compress(bytes(profile), 9)
        out.append(struct.pack('>I4s', len(body), kind) + body + struct.pack('>I', zlib.crc32(kind + body)))
    return b''.join(out)


def sha(b):
    return hashlib.sha256(b).hexdigest()


def extract_meta(note):
    """MV DataManager.extractMetadata：<key:value> → 字符串，<key> → true。"""
    meta = {}
    for m in META_RE.finditer(note or ''):
        meta[m.group(1)] = m.group(3) if m.group(2) == ':' else True
    return meta


# ---- 伤害公式翻译：JS 表达式 → Godot Expression ----
JS_FUNCS = {'Math.max': 'max', 'Math.min': 'min', 'Math.floor': 'floor', 'Math.ceil': 'ceil', 'Math.round': 'round',
            'Math.abs': 'abs', 'Math.pow': 'pow', 'Math.sqrt': 'sqrt', 'Math.random()': 'randf()', '.elementRate(': '.element_rate('}
UNSUPPORTED = re.compile(r'[;{}?]|\bif\b|\bvar\b|\blet\b|\$game|\$data|=>|===|!==|\bfunction\b|\.length|\[\s*\]|\bthis\b')


def _top_ternary(js):
    """括号外恰好一个 ? 与其后一个 : 时返回 [条件, 真值, 假值]，否则 None。"""
    depth, q, c = 0, [], []
    for i, ch in enumerate(js):
        if ch in '([':
            depth += 1
        elif ch in ')]':
            depth -= 1
        elif depth == 0 and ch == '?':
            q.append(i)
        elif depth == 0 and ch == ':' and q:
            c.append(i)
    if len(q) != 1 or len(c) != 1:
        return None
    return [js[:q[0]].strip(), js[q[0] + 1:c[0]].strip(), js[c[0] + 1:].strip()]


def translate_formula(js, item_id=0):
    js = (js or '').strip()
    # MV 公式里 user/target 与 a/b 同义；item.id 在转换时就能确定
    js = re.sub(r'\buser\.', 'a.', js)
    js = re.sub(r'\btarget\.', 'b.', js)
    js = re.sub(r'\bitem\.id\b', str(item_id), js)
    if not js:
        return '0', None
    # 顶层的一个三元式 c ? x : y：Godot Expression 不认 if/else（解析通过但总取前一支），改成按条件下标取值的数组。
    # 不用 x*float(c)+y*float(not c)：条件为数字（如 5）时会乘成 5x，未取的一支为 NaN／无穷时整式变 NaN。
    # bool() 照 JS 真值（非零数为真）；两支仍都会求值，含 randf() 时比正式版多耗一次全局随机数（Godot 战斗随机数不与 MV 同种子，取值分布不变）。
    split = _top_ternary(js)
    if split:
        parts = [translate_formula(x, item_id) for x in split]
        if all(gd is not None for gd, _ in parts):
            c, x, y = (gd for gd, _ in parts)
            return f'[({y}), ({x})][int(bool({c}))]', None
        return None, next(why for gd, why in parts if gd is None)
    if UNSUPPORTED.search(js):
        return None, 'js_statement_or_game_state'
    gd = js
    for k, v in JS_FUNCS.items():
        gd = gd.replace(k, v)
    if 'Math.' in gd:
        return None, 'unknown_math_function'
    # JS 一元加号（Godot Expression 不支持）：开头、运算符或左括号、逗号之后的 + 对数值不起作用，去掉。
    # 如技能 1065「霸道之刃」750 +  + a.atk * 38.5
    gd = re.sub(r'(^|[+\-*/%(,<>=!&|])(\s*)\+(?!\+)', r'\1\2', gd)
    gd = gd.replace('&&', ' and ').replace('||', ' or ')
    gd = re.sub(r'!(?!=)', ' not ', gd)
    # 允许的标识符：a、b、v[…]、数字、属性访问、运算符、上面翻译过的函数
    if re.search(r'[^\w\s\.\+\-\*/%\(\)\[\],<>=!]', gd):
        return None, 'unexpected_character'
    for ident in re.findall(r'(?<![\.\w])([A-Za-z_]\w*)', gd):
        if ident not in ('a', 'b', 'v', 'max', 'min', 'floor', 'ceil', 'round', 'abs', 'pow', 'sqrt', 'randf', 'and', 'or', 'not', 'true', 'false'):
            return None, f'unknown_identifier:{ident}'
    return gd, None


def yep_damage_block(note):
    """YEP_DamageCore processDMGNotetags：备注里 <Damage Formula>…</Damage Formula> 的各行（按 /[\r\n]+/ 拆，每行加 \n）
    替换数据库的公式，并标 damage.custom（没有这一块时 custom 一律为 false）。返回块文字或 None。"""
    out, mode = None, False
    for line in re.split(r'[\r\n]+', note or ''):
        if re.search(r'<(?:DAMAGE FORMULA)>', line, re.I):
            mode, out = True, ''
        elif re.search(r'</(?:DAMAGE FORMULA)>', line, re.I):
            mode = False
        elif mode:
            out += line + '\n'
    return out


def translate_custom_block(block, item_id=0):
    """自定义公式块（eval 后取 value，默认 0）：只认「var/let/const 名 = 式」与「value = 式」两种语句，按顺序把变量代入，
    得到一个式子再按普通公式翻译；有其他语句（加减 HP/MP/TP、条件、数组等副作用或流程）一律算未翻译。"""
    names, value = {}, '0'
    sub = lambda e: re.sub(r'(?<![\.\w])([A-Za-z_]\w*)', lambda m: names.get(m.group(1), m.group(1)), e)
    for stmt in re.split(r'[;\n]', strip_js_comments(block)):
        stmt = stmt.strip()
        if not stmt:
            continue
        m = re.match(r'^(?:var|let|const)\s+([A-Za-z_]\w*)\s*=\s*(.+)$', stmt)
        if m and m.group(1) != 'value':
            names[m.group(1)] = '(' + sub(m.group(2)) + ')'
            continue
        m = re.match(r'^value\s*=\s*(.+)$', stmt)
        if m and '=' not in m.group(1).replace('==', '').replace('<=', '').replace('>=', '').replace('!=', ''):
            value = '(' + sub(m.group(1)) + ')'
            names['value'] = value
            continue
        return None, 'js_statement_or_game_state'
    return translate_formula(value, item_id)


# ---- 状态脚本（YEP BuffsStatesCore <Custom X Effect>）→ 结构化效果 ----
EFFECT_RE = re.compile(r'<Custom ([A-Za-z]+(?: [A-Za-z]+)*) Effect>([\s\S]*?)</Custom \1 Effect>')
SIMPLE_MUL = re.compile(r'^if\s*\((?:this\.isHpEffect\(\)\s*&&\s*)?value\s*(!==|>|>=)\s*0(?:\s*&&\s*this\.isHpEffect\(\))?\)\s*\{\s*'
                        r'value\s*=\s*Math\.(ceil|floor|round)\(\s*value\s*\*\s*([\d.]+)\s*\)\s*;?\s*\}$')
SIMPLE_MINUS = re.compile(r'^if\s*\(value\s*(>|>=)\s*0\s*&&\s*this\.isHpEffect\(\)\s*\)\s*\{\s*value\s*\*=\s*1\s*-\s*([\d.]+)\s*;\s*'
                          r'value\s*=\s*Math\.(floor|ceil|round)\(value\)\s*;?\s*\}$')


def strip_js_comments(js):
    js = re.sub(r'/\*[\s\S]*?\*/', '', js)
    return re.sub(r'//[^\n]*', '', js)


PARAM_HIT = re.compile(r'if \(user\.(atk|mat|def|mdf|agi|luk) > 0\) \{ target\.gainHp\(-user\.(\w+)\); target\.startDamagePopup\(\); \}\s*')


def constant_bonus_effect(code):
    """Only four complete, native-measured shapes; never accept a known prefix."""
    number = r'(-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?)'
    def pattern(text):
        # Preserve token boundaries: deleting all whitespace would accept e.g. "val ue".
        return r'\s*'.join(number if token == 'NUMBER' else r'var\s+' if token == 'var'
                            else re.escape(token) for token in text.split())
    gate = 'if ( this . isHpEffect ( ) && value > 0 ) { '
    local = re.fullmatch(pattern(gate + 'var bonus = Math . ceil ( value * NUMBER ) ; value += bonus ; }'), code)
    final = re.fullmatch(pattern(gate + 'var finalRate = NUMBER ; value += Math . ceil ( value * finalRate ) ; }'), code)
    critical = re.fullmatch(pattern(gate + 'var finalRate = NUMBER ; var bonusRate = NUMBER ; '
                                    'value += Math . ceil ( value * finalRate ) ; if ( target . result ( ) . critical ) { '
                                    'value += Math . ceil ( value * bonusRate ) ; } }') +
                            r'(?:\s*' + pattern(gate + 'value = Math . floor ( value * NUMBER ) ; }') + r')?', code)
    if not (local or final or critical):
        return None
    rates = critical.groups() if critical else (local or final).groups()
    steps = [{'kind': 'add', 'k': float(rates[0]), 'round': 'ceil'}]
    if critical:
        steps.append({'kind': 'add', 'k': float(rates[1]), 'round': 'ceil', 'criticalOnly': True})
    groups = [{'cond': 'positive', 'hpOnly': True, 'steps': steps}]
    if critical and rates[2] is not None:
        # This is an independent if: retest the already updated value.
        groups.append({'cond': 'positive', 'hpOnly': True,
                       'steps': [{'kind': 'mul', 'k': float(rates[2]), 'round': 'floor'}]})
    return {'op': 'value_steps', 'groups': groups}



# Whole token signatures of the native-measured phase-2c blocks; no runtime source lookup.
MEASURED_VALUE_BLOCKS = frozenset([
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value * $gameVariables . value ( 965 ) * 0.1 ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value * $gameVariables . value ( 967 ) * 0.1 ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value * ( 1 + $gameVariables . value ( 966 ) * 0.1 ) ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value + value * ( Math . random ( ) * 2 - 1 ) ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value + value * target . states ( ) . length * 0.01 ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value + value * target . states ( ) . length * 0.025 ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . floor ( value - ( value * user . level * 0.01 ) ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = value * Math . min ( 1 + $gameVariables . value ( 1181 ) * 0.0001 , 1.1 ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { value = value * Math . min ( 1 + $gameVariables . value ( 1184 ) * 0.01 , 1.05 ) ; }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { var actorLevel = user . level ; var levelDecay = ( actorLevel > 30 ) ? Math . min ( 0.90 , 0.04 * ( actorLevel - 30 ) ) : 0 ; var finalRate = 1 - levelDecay ; value = Math . ceil ( value * finalRate ) ; if ( target . result ( ) . critical ) { var bonusRate = 0 ; value + = Math . ceil ( value * bonusRate ) ; } }'),
    ('confirm', 'if ( this . isHpEffect ( ) && value > 0 ) { var allin = Math . floor ( $gameVariables . value ( 206 ) / 1000 ) ; if ( allin > 50 ) { allin = 50 ; } if ( allin < - 50 ) { allin = - 50 ; } value = value * Math . floor ( allin * 0.01 ) ; }'),
    ('confirm', 'if ( this . isMagical ( ) && value !== 0 ) { value = Math . ceil ( value * 1.50 ) ; }'),
    ('confirm', 'if ( this . isPhysical ( ) && this . isHpEffect ( ) && value > 0 ) { if ( target . hp > target . mhp * 0.7 ) { var xs = Math . min ( ( target . mhp * 0.00001 / user . mhp * 10000 ) , 1.3 ) ; value = Math . ceil ( value * xs * 0.1 ) ; } }'),
    ('confirm', 'if ( value > 0 !== this . isMagical ( ) || this . isPhysical ( ) ) { if ( Math . random ( ) > 0.5 ) { value = 0 ; } else { value = Math . ceil ( value * 0.1 ) ; } } else if ( value > 0 && this . isMagical ( ) || this . isPhysical ( ) ) { value = Math . ceil ( value * 2 ) ; }'),
    ('confirm', 'if ( value > 0 !== this . isMagical ( ) || this . isPhysical ( ) ) { if ( Math . random ( ) > 0.8 ) { value = 0 ; } else { value = Math . ceil ( value * 0.01 ) ; } }'),
    ('confirm', 'if ( value > 0 !== this . isMagical ( ) || this . isPhysical ( ) ) { value = Math . floor ( value * 1.2 ) ; }'),
    ('confirm', 'if ( value > 0 && Math . random ( ) > 0.5 ) { value = 0 ; }'),
    ('confirm', 'if ( value > 0 && this . isHpEffect ( ) && target . hpRate ( ) > 0.4 ) { var bonusRate = target . hpRate ( ) - 0.4 ; value = Math . floor ( value * ( 1 + bonusRate ) ) ; }'),
    ('confirm', 'if ( value > 0 ) { value = Math . ceil ( value * Math . pow ( 0.8 , Math . max ( 0 , Math . min ( $gameVariables . value ( 20 ) , 30 ) - 16 ) ) ) ; }'),
    ('confirm', 'if ( value > 0 ) { value = Math . ceil ( value * Math . pow ( 0.8 , Math . max ( 0 , Math . min ( $gameVariables . value ( 20 ) , 30 ) - 7 ) ) ) ; }'),
    ('confirm', 'if ( value > 0 ) { value = Math . ceil ( value * Math . pow ( 0.9 , Math . max ( 0 , Math . min ( $gameVariables . value ( 20 ) , 26 ) - 11 ) ) ) ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { value = 0 ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { value = 1 ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { value = Math . ceil ( value / Math . max ( target . def * 0.9 , 1 ) ) ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var bonus = Math . ceil ( value * 0.1 ) ; value - = bonus ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var bonus = Math . ceil ( value * 0.10 ) ; value - = bonus ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var bonus = Math . ceil ( value * 0.2 ) ; value - = bonus ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var bonus = Math . ceil ( value * 0.30 ) ; value - = bonus ; }'),
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var bonus = Math . ceil ( value * 0.4 ) ; value - = bonus ; }'),
    ('react', 'if ( value > 0 && this . isHpEffect ( ) ) { value * = 1 + 1 ; value = Math . floor ( value ) ; }'),
    ('react', 'if ( value > target . hp ) { value = target . hp - 1 }'),
    ('react', 'value = Math . floor ( value * 0.05 ) ;'),
    ('react', 'value = Math . floor ( value * 0.9 ) ;'),
    ('react', 'value = Math . floor ( value * 0.91 ) ;'),
])


def pure_state_value_effect(code, phase):
    """Only the complete 35 native-measured blocks. Adapt bounded input tokens,
    then reuse the pure formula IR; never reinterpret an unmatched JS fragment.
    The phase VM supplies current signed value and leaves damage-formula output alone.
    """
    from formula_program import Parser, Unsupported
    try:
        tokens = [row[0] for row in Parser(code).tokens[:-1]]
    except Unsupported:
        return None
    if (phase, ' '.join(tokens)) not in MEASURED_VALUE_BLOCKS:
        return None
    aliases = [
        (['this', '.', 'isHpEffect', '(', ')'], ['se_hp']),
        (['this', '.', 'isMagical', '(', ')'], ['se_magic']),
        (['this', '.', 'isPhysical', '(', ')'], ['se_physical']),
        (['target', '.', 'result', '(', ')', '.', 'critical'], ['se_critical']),
    ]
    adapted, i = [], 0
    while i < len(tokens):
        for native, replacement in aliases:
            if tokens[i:i + len(native)] == native:
                adapted.extend(replacement)
                i += len(native)
                break
        else:
            if tokens[i:i + 4] == ['$gameVariables', '.', 'value', '(']:
                # Every accepted native call has one constant index and closing ')'.
                adapted.extend(['v', '[', tokens[i + 4], ']'])
                i += 6
            else:
                adapted.append(tokens[i])
                i += 1
    # The shared parser accepts simple assignments only. These measured compound
    # assignments all have a semicolon and write local value, without side effects.
    tokens, adapted, i = adapted, [], 0
    while i < len(tokens):
        if tokens[i] == 'value' and tokens[i + 1:i + 3] in (['+', '='], ['-', '='], ['*', '=']):
            end = tokens.index(';', i + 3)
            adapted.extend(['value', '=', 'value', tokens[i + 1], '('] + tokens[i + 3:end] + [')', ';'])
            i = end + 1
        else:
            adapted.append(tokens[i])
            i += 1
    source = 'var se_hp; var se_magic; var se_physical; var se_critical;\n' + ' '.join(adapted)
    program = compile_formula(source, custom=True, table='States')
    if program['status'] != 'pure' or not set(program['capabilities']) <= {'read.battler', 'read.variables', 'random.rule'}:
        return None
    return {'op': 'value_program', 'program': program}

# Complete native-measured phase-2d query signatures. Weapons await attack replacement.
MEASURED_QUERY_BLOCKS = {
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var elements = this . getItemElements ( ) ; var lightningElementId = 1 ; if ( elements . contains ( lightningElementId ) ) { value = 0 ; } }'): {'query': 'element_contains', 'element': 1, 'present': True},
    ('react', 'if ( this . isHpEffect ( ) && value > 0 ) { var elements = this . getItemElements ( ) ; var lightningElementId = 1 ; if ( ! elements . contains ( lightningElementId ) ) { value = 0 ; } }'): {'query': 'element_contains', 'element': 1, 'present': False},
    ('confirm', 'if ( value > 0 && this . isHpEffect ( ) && $gameParty . aliveMembers ( ) . length === 1 ) { value = Math . floor ( value * 1.5 ) ; }'): {'query': 'party_alive'},
    ('confirm', 'if ( value > 0 && defender && defender . isEnemy && defender . isEnemy ( ) && defender . hpRate ( ) < 0.2 ) { value = Math . ceil ( value * 2 ) ; }'): {'query': 'defender_hp'},
}


def query_state_value_effect(code, phase):
    from formula_program import Parser, Unsupported
    try:
        signature = ' '.join(row[0] for row in Parser(code).tokens[:-1])
    except Unsupported:
        return None
    query = MEASURED_QUERY_BLOCKS.get((phase, signature))
    return {'op': 'value_query', **query} if query else None


def parse_state_effects(note):
    """返回 [{phase, op, cond, k, round} 或 {phase, op:'js', source}]；op=js 表示尚未翻译。"""
    out = []
    for m in EFFECT_RE.finditer(note or ''):
        phase, body = m.group(1).lower().replace(' ', '_'), m.group(2)
        code = re.sub(r'\s+', ' ', strip_js_comments(body)).strip()
        mm = SIMPLE_MUL.match(code)
        if mm:
            out.append({'phase': phase, 'op': 'mul', 'cond': {'!==': 'nonzero', '>': 'positive', '>=': 'nonnegative'}[mm.group(1)],
                        'hpOnly': 'isHpEffect' in code, 'k': float(mm.group(3)), 'round': mm.group(2)})
            continue
        mm = SIMPLE_MINUS.match(code)
        if mm:
            out.append({'phase': phase, 'op': 'mul', 'cond': {'>': 'positive', '>=': 'nonnegative'}[mm.group(1)],
                        'hpOnly': True, 'k': 1 - float(mm.group(2)), 'round': mm.group(3)})
            continue
        # 轮回困难 1460/1461（Establish）：行动者每个正的 atk/mat 各对目标附加一次 gainHp(-值) 并弹字
        blocks = PARAM_HIT.findall(code)
        if blocks and PARAM_HIT.sub('', code).strip() == '' and all(a == b for a, b in blocks):
            out.append({'phase': phase, 'op': 'user_param_damage', 'params': [a for a, _ in blocks]})
            continue
        bonus = constant_bonus_effect(code) if phase in ('confirm', 'react') else None
        if bonus:
            out.append({'phase': phase, **bonus})
            continue
        query = query_state_value_effect(code, phase)
        if query:
            out.append({'phase': phase, **query})
            continue
        value_program = pure_state_value_effect(code, phase)
        if value_program:
            out.append({'phase': phase, **value_program})
            continue
        out.append({'phase': phase, 'op': 'js', 'source': body.strip()})
    return out


# ---- YEP_ElementCore / YEP_X_CriticalControl 备注标签 → 结构化字段（按行匹配，与原插件一致）----
YEP_C1 = re.compile(r'<(?:ELEMENT AMPLIFY) (\d+): ([+\-]\d+(?:\.\d+)?)([%％])>', re.I)
YEP_C2 = re.compile(r'<(?:ELEMENT AMPLIFY) (.*): ([+\-]\d+(?:\.\d+)?)([%％])>', re.I)
YEP_CN1 = re.compile(r'<(?:ELEMENT AMPLIFY) (\d+): ([+\-]\d+(?:\.\d+)?)>', re.I)
YEP_CN2 = re.compile(r'<(?:ELEMENT AMPLIFY) (.*): ([+\-]\d+(?:\.\d+)?)>', re.I)
YEP_C3 = re.compile(r'<(?:ELEMENT MAGNIFY) (\d+): ([+\-]\d+(?:\.\d+)?)([%％])>', re.I)
YEP_C4 = re.compile(r'<(?:ELEMENT MAGNIFY) (.*): ([+\-]\d+(?:\.\d+)?)([%％])>', re.I)
YEP_CRIT = re.compile(r'<(?:CRITICAL MULTIPLIER): ([+\-]\d+)([%％])>', re.I)
YEP_MULTI1 = re.compile(r'<MULTIPLE ELEMENTS:[ ]*(\d+(?:\s*,\s*\d+)*)>', re.I)
YEP_MULTI2 = re.compile(r'<MULTIPLE ELEMENTS: (\d+) (?:THROUGH|to) (\d+)>', re.I)


CORE_ENEMY_STATS = {'HP': 0, 'MAXHP': 0, 'MAX HP': 0, 'MP': 1, 'MAXMP': 1, 'MAX MP': 1, 'SP': 1, 'MAXSP': 1, 'MAX SP': 1,
                    'ATK': 2, 'STR': 2, 'DEF': 3, 'MAT': 4, 'INT': 4, 'SPI': 4, 'MDF': 5, 'RES': 5, 'AGI': 6, 'SPD': 6, 'LUK': 7}


def core_enemy_notetags(rec):
    """YEP_CoreEngine DataManager.processCORENotetags2（读库时改写敌人）：每行 <GOLD: n>、<能力: n>、<EXP: n> 覆盖原值。"""
    for line in re.split(r'[\r\n]+', rec.get('note') or ''):
        m = re.search(r'<(?:GOLD):[ ](\d+)>', line, re.I)
        if m:
            rec['gold'] = int(m.group(1))
            continue
        m = re.search(r'<(.*):[ ](\d+)>', line, re.I)
        if not m:
            continue
        stat, value = m.group(1).upper(), int(m.group(2))
        if stat in CORE_ENEMY_STATS:
            rec['params'][CORE_ENEMY_STATS[stat]] = value
        elif stat in ('EXP', 'XP'):
            rec['exp'] = value


def parse_yep(note, element_ids):
    amp, ampn, mag, crit, multi = {}, {}, {}, 0.0, []
    for line in re.split(r'[\r\n]+', note or ''):
        def eid(name):
            return element_ids.get(name.upper().strip())
        if m := YEP_C1.search(line):
            amp[m.group(1)] = amp.get(m.group(1), 0) + float(m.group(2)) * 0.01
        elif (m := YEP_C2.search(line)) and eid(m.group(1)):
            k = str(eid(m.group(1))); amp[k] = amp.get(k, 0) + float(m.group(2)) * 0.01
        elif m := YEP_CN1.search(line):
            ampn[m.group(1)] = ampn.get(m.group(1), 0) + float(m.group(2))
        elif (m := YEP_CN2.search(line)) and eid(m.group(1)):
            k = str(eid(m.group(1))); ampn[k] = ampn.get(k, 0) + float(m.group(2))
        elif m := YEP_C3.search(line):
            mag[m.group(1)] = float(m.group(2)) * 0.01
        elif (m := YEP_C4.search(line)) and eid(m.group(1)):
            mag[str(eid(m.group(1)))] = float(m.group(2)) * 0.01
        if m := YEP_CRIT.search(line):
            crit = float(m.group(1)) * 0.01
        if m := YEP_MULTI2.search(line):
            multi += list(range(int(m.group(1)), int(m.group(2)) + 1))
        elif m := YEP_MULTI1.search(line):
            multi += [int(x) for x in re.findall(r'\d+', m.group(1))]
    out = {}
    if amp: out['elementAmplify'] = amp
    if ampn: out['elementAmplifyN'] = ampn
    if mag: out['elementMagnify'] = mag
    if crit: out['critMultBonus'] = crit
    if multi: out['multipleElements'] = multi
    return out


def load_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def yep_action_effects(obj, animations):
    """YEP_BattleEngineCore 解析后 whole＋target 行动序列里「ACTION EFFECT」的条数（Codex_SmartBattleAI.sequenceHits）。
    默认序列按 isWholeAction 放在 whole 或 target，含 max(1, repeats) 条（addActionEffects 之后 repeats 被改成 1）；
    备注里的 <whole action>/<target action> 块整段替换。YEP 把 if 行存成整行名字，AI 的 IF/ELSE/END 判断从不成立，所以全部计数。"""
    anim_id = obj.get('animationId', 0) or 0
    whole = False
    if anim_id > 0 and anim_id < len(animations) and animations[anim_id]:
        whole = animations[anim_id].get('position') == 3 or obj.get('scope') in (2, 8, 10)
    default = max(1, int(obj.get('repeats', 1) or 1))
    counts = {'whole': default if whole else 0, 'target': 0 if whole else default}
    kind = None
    for line in re.split(r'[\r\n]+', obj.get('note', '') or ''):
        if re.search(r'<(?:SETUP ACTION|setup)>', line, re.I):
            kind = 'setup'
        elif re.search(r'<(?:WHOLE ACTION|whole)>', line, re.I):
            kind = 'whole'; counts['whole'] = 0
        elif re.search(r'<(?:TARGET ACTION|target)>', line, re.I):
            kind = 'target'; counts['target'] = 0
        elif re.search(r'<(?:FOLLOW ACTION|follow)>', line, re.I):
            kind = 'follow'
        elif re.search(r'<(?:FINISH ACTION|finish)>', line, re.I):
            kind = 'finish'
        elif re.search(r'</(?:SETUP ACTION|setup|WHOLE ACTION|whole|TARGET ACTION|target|FOLLOW ACTION|follow|FINISH ACTION|finish)>', line, re.I):
            kind = None
        elif kind in ('whole', 'target'):
            m = re.match(r'[ ]*(.*):[ ](.*)', line)
            name = (m.group(1) if m else line).strip()
            if name.upper() == 'ACTION EFFECT':
                counts[kind] += 1
    return max(1, counts['whole'] + counts['target'])


YEP_DEFAULT_SETUP = [['CLEAR BATTLE LOG'], ['DISPLAY ACTION'], ['IMMORTAL', ['TARGETS', 'TRUE']], ['PERFORM START'],
                     ['WAIT FOR MOVEMENT'], ['CAST ANIMATION'], ['WAIT FOR ANIMATION']]
YEP_DEFAULT_FINISH = [['IMMORTAL', ['TARGETS', 'FALSE']], ['WAIT FOR NEW LINE'], ['CLEAR BATTLE LOG'], ['PERFORM FINISH'],
                      ['WAIT FOR MOVEMENT'], ['WAIT FOR EFFECT'], ['ACTION COMMON EVENT']]
YEP_PHASES = ['setup', 'whole', 'target', 'follow', 'finish']


def yep_sequences(obj, animations, motion_wait=True):
    """YEP_BattleEngineCore.processMELODYNotetags 的 Python 移植：返回五段行动序列 {setup, whole, target, follow, finish}，
    每条为 [名字, 参数表]（与运行时 $dataSkills[i].xxxActions 相同；默认序列的单名条目没有参数表）。
    setDefaultActions 对每个对象都执行，所以运行时 repeats 一律变成 1、默认段里展开为 repeats 次 ACTION EFFECT。"""
    anim_id = obj.get('animationId', 0) or 0
    whole = False
    if anim_id > 0 and anim_id < len(animations) and animations[anim_id]:
        whole = animations[anim_id].get('position') == 3 or obj.get('scope') in (2, 8, 10)
    base = [['PERFORM ACTION'], ['MOTION WAIT', ['USER']] if motion_wait else ['WAIT', [10]], ['ACTION ANIMATION'], ['WAIT FOR ANIMATION']]
    effects = []
    repeats = int(obj.get('repeats', 1) or 1)
    while True:
        effects += [['ACTION EFFECT'], ['DEATH BREAK']]
        repeats -= 1
        if repeats <= 0:
            break
        effects.append(['WAIT', [8]])
    seq = {'setup': [list(x) for x in YEP_DEFAULT_SETUP], 'whole': base + effects if whole else [],
           'target': [] if whole else base + effects, 'follow': [], 'finish': [list(x) for x in YEP_DEFAULT_FINISH]}
    kind = None
    tags = [('setup', r'SETUP ACTION|setup'), ('whole', r'WHOLE ACTION|whole'), ('target', r'TARGET ACTION|target'),
            ('follow', r'FOLLOW ACTION|follow'), ('finish', r'FINISH ACTION|finish')]
    for line in re.split(r'[\r\n]+', obj.get('note', '') or ''):
        hit = False
        for name, pat in tags:
            if re.search(r'<(?:' + pat + r')>', line, re.I):
                kind = name; seq[name] = []; hit = True; break
            if re.search(r'</(?:' + pat + r')>', line, re.I):
                kind = None; hit = True; break
        if hit or kind is None:
            continue
        m = re.match(r'[ ]*(.*):[ ](.*)', line)
        if m:
            seq[kind].append([m.group(1).strip(), [a.strip() for a in m.group(2).split(',')]])
        else:
            seq[kind].append([line.strip(), []])
    return seq


def yep_action_copy(group, skills, items):
    """processBECNotetags2 的 <Action Copy: x: y>：按编号顺序把目标对象当时的五段序列复制过来。"""
    pat = re.compile(r'<(?:ACTION COPY):[ ](.*):[ ]*(\d+)>', re.I)
    for obj in group:
        if not isinstance(obj, dict):
            continue
        for line in re.split(r'[\r\n]+', obj.get('note', '') or ''):
            m = pat.search(line)
            if not m:
                continue
            text, tid = m.group(1).upper(), int(m.group(2))
            src = items if text in ('I', 'ITEM') else skills if text in ('S', 'SKILL') else None
            target = src[tid] if src is not None and 0 <= tid < len(src) else None
            if isinstance(target, dict) and 'yepSeq' in target:
                obj['yepSeq'] = {k: [list(x) for x in target['yepSeq'][k]] for k in YEP_PHASES}


def boot_database_records(plugins):
    """专属角色模块在 DataManager.isDatabaseLoaded 里对开机数据库的改动（参照取开机后的数据库，这里照做）。
    167 渡鸦（installNativeRavenRuntime finishRavenDatabaseCompatibility）：原版角色进阶表里没有渡鸦第 rank 次的行时，
    在表尾补一行（id＝当时表长；表由插件参数「Advanced 1～1000」建成，表长＝最大编号＋1），写法同插件参数（字符串）。"""
    adv = plugins.get('Star_ActorAdvanced')
    if adv is None:
        return
    rows = {}
    for key, raw in adv.items():
        if key.startswith('Advanced ') and str(raw).strip():
            try:
                rows[int(key[9:])] = json.loads(raw)
            except ValueError:
                continue
    levels = [15, 25, 35, 45, 45]
    skills = [[10131], [10132], [10133], [10134], [10127, 10170]]
    for rank in range(5):
        if any(str(r.get('AdvancedActId')) == '167' and str(r.get('AdvancedActNum')) == str(rank) for r in rows.values()):
            continue
        nid = max(rows, default=0) + 1
        rows[nid] = row = {'AdvancedName': '渡鸦·冥羽进阶', 'AdvancedActNum': str(rank), 'AdvancedActNumMaX': '5',
                           'AdvancedActId': '167', 'AdvancedActLevel': str(levels[rank]), 'AdvancedGold': '0',
                           'AdvancedItem': '[[2901, 1]]', 'AdvancedSkiId': json.dumps(skills[rank]), 'AdvancedForId': '[]'}
        adv['Advanced %d' % nid] = json.dumps(row, ensure_ascii=False)


class Exporter:
    def __init__(self, app, out, slice_cfg):
        self.app, self.out, self.cfg = app.resolve(), out.resolve(), slice_cfg
        if self.out.is_relative_to(self.app) or self.app.is_relative_to(self.out):
            raise ValueError('输出目录不能与正式应用重叠')
        self.inputs, self.outputs, self.issues = {}, {}, []
        self.img, self.audio = set(), set()
        self.db = {}
        self.pending_json = {}
        self.written = self.unchanged = self.deleted = 0

    def read(self, rel):
        p = self.app / rel
        b = p.read_bytes()
        self.inputs[rel] = sha(b)
        return json.loads(b.decode('utf-8'))

    def write_json(self, rel, data):
        b = (json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')
        # 部分表先补行动序列、再补装备字段：只落盘最终版本，避免无改动时仍写中间表。
        self.pending_json[rel] = b
        self.outputs[rel] = sha(b)

    def write_changed(self, rel, data, source=None):
        """按字节比较；临时文件与目标同目录，关闭后原子替换，保留未变文件的导入旁文件。"""
        p = self.out / rel
        parent = p.parent.resolve()
        if parent != p.parent or not parent.is_relative_to(self.out):
            raise ValueError('输出父目录不能含符号链接或离开输出目录：' + rel)
        if p.is_file() and not p.is_symlink() and p.read_bytes() == data:
            self.unchanged += 1
            return
        p.parent.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(dir=p.parent, prefix='.xiyou-export-', suffix='.tmp')
        temp = Path(name)
        try:
            with os.fdopen(fd, 'wb') as output:
                output.write(data)
            if source is not None:
                shutil.copystat(source, temp)
            else:
                temp.chmod((p.stat().st_mode & 0o777) if p.is_file() and not p.is_symlink() else 0o644)
            os.replace(temp, p)
            self.written += 1
        finally:
            temp.unlink(missing_ok=True)

    def remove_stale(self):
        """成功生成后清理五个自有子树；只给仍产出的文件保留 .import，oracle／同步指纹不动。"""
        for sub in ('db', 'maps', 'img', 'audio', 'fonts'):
            directory = self.out / sub
            if directory.is_symlink():
                raise ValueError('产物子目录不能是符号链接：' + sub)
            for p in sorted(directory.rglob('*'), reverse=True):
                if p.is_symlink() or p.is_file():
                    rel = p.relative_to(self.out).as_posix()
                    if rel in self.outputs or (rel.endswith('.import') and rel[:-7] in self.outputs):
                        continue
                    p.unlink()
                    self.deleted += 1
                elif p.is_dir() and not any(p.iterdir()):
                    p.rmdir()
            if directory.is_dir() and not any(directory.iterdir()):
                directory.rmdir()
        # SIGKILL 时 finally 无法运行，根目录的 manifest 临时文件也在下一次成功时清除。
        for p in self.out.glob('.xiyou-export-*.tmp'):
            p.unlink()
            self.deleted += 1

    # ---- 数据库 ----
    def export_db(self):
        system = self.read('data/System.json')
        element_ids = {n.upper().strip(): i for i, n in enumerate(system['elements']) if n}
        for name in TABLES:
            data = self.read(f'data/{name}.json')
            if isinstance(data, list):
                for rec in data:
                    if isinstance(rec, dict) and 'note' in rec:
                        rec['meta'] = extract_meta(rec['note'])
                    if isinstance(rec, dict) and 'note' in rec:
                        yep = parse_yep(rec['note'], element_ids)
                        if yep:
                            rec['yep'] = yep
                    if name == 'States' and isinstance(rec, dict):
                        rec['effects'] = parse_state_effects(rec['note'])
                    if name == 'Enemies' and isinstance(rec, dict):
                        core_enemy_notetags(rec)
                    if isinstance(rec, dict) and isinstance(rec.get('damage'), dict):
                        block = yep_damage_block(rec.get('note'))
                        rec['damage']['custom'] = block is not None
                        if block is not None:
                            rec['damage']['formula'] = block
                            gd, why = translate_custom_block(block, rec.get('id', 0))
                        else:
                            gd, why = translate_formula(rec['damage'].get('formula'), rec.get('id', 0))
                        rec['damage']['formulaGd'] = gd
                        rec['damage']['formulaProgram'] = compile_formula(rec['damage'].get('formula'), rec.get('id', 0), block is not None, name)
                        if why and rec['damage'].get('type'):
                            rec['damage']['formulaIssue'] = why
            self.db[name] = data
            self.write_json(f'db/{name}.json', data)
        animations = self.db.get('Animations') or self.read('data/Animations.json')
        plugins_text = (self.app / 'js/plugins.js').read_text()
        plugin_list = json.loads(plugins_text[plugins_text.index('['):plugins_text.rindex(']') + 1])
        bec = next((p.get('parameters', {}) for p in plugin_list if p.get('name') == 'YEP_BattleEngineCore' and p.get('status')), {})
        motion_wait = str(bec.get('Motion Waiting', 'false')).strip().lower() == 'true'
        for name in ['Skills', 'Items']:
            for rec in self.db[name]:
                if isinstance(rec, dict):
                    rec['yepEffects'] = yep_action_effects(rec, animations)
                    rec['yepSeq'] = yep_sequences(rec, animations, motion_wait)
        yep_action_copy(self.db['Skills'], self.db['Skills'], self.db['Items'])
        yep_action_copy(self.db['Items'], self.db['Skills'], self.db['Items'])
        for name in ['Skills', 'Items']:
            self.write_json(f'db/{name}.json', self.db[name])

    def export_plugins(self):
        """启用插件的参数（难度倍率表等）。plugins.js 是 JS，取出其中的 JSON 数组。"""
        rel = 'js/plugins.js'
        b = (self.app / rel).read_bytes()
        self.inputs[rel] = sha(b)
        text = b.decode('utf-8')
        plugins = json.loads(text[text.index('['):text.rindex(']') + 1])
        enabled = {p['name']: p['parameters'] for p in plugins if p.get('status')}
        # 正式版 v0.15+ 在运行时覆盖 ItemQuality 参数，plugins.js 里的旧 16 档已不是实际显示。
        module = 'js/codex/runtime/installUnifiedQualityRuntime.js'
        modules_file = self.app / 'js/codex/modules.json'
        if modules_file.exists() and module in self.read('js/codex/modules.json').get('modules', []):
            source = (self.app / module).read_text()
            def array(name):
                match = re.search(r'\b' + name + r':\s*(\[[^\]]*\])', source)
                if not match:
                    raise ValueError('七档品质字段无法解析：' + name)
                return ast.literal_eval(match[1])
            names, colors, windows, grades = [array(k) for k in ('names', 'colors', 'windows', 'itemGrades')]
            if len(grades) != 16 or any(not 0 <= g < len(names) or g >= len(colors) or g >= len(windows) for g in grades):
                raise ValueError('七档品质映射无效')
            tags = re.search(r'gearTags:\s*\{([^}]*)\}', source)
            if not tags:
                raise ValueError('七档品质装备标签无法解析')
            # v0.17 起神话档装备另有星级（旧12/14/15）；更早的版本没有该字段
            stars = re.search(r'starMarks:\s*\{([^}]*)\}', source)
            self.write_json('db/UnifiedQuality.json', {
                'names': names, 'colors': colors, 'windows': windows, 'itemGrades': grades,
                'gearTags': dict(re.findall(r"(\d+):\s*'([^']*)'", tags[1])),
                'starMarks': dict(re.findall(r"(\d+):\s*'([^']*)'", stars[1])) if stars else {},
            })
        boot_database_records(enabled)
        self.plugins = enabled
        self.write_json('db/Plugins.json', enabled)
        self.write_json('db/EquipSuits.json', equipment_rules.suits(enabled))
        self.write_json('db/Runewords.json', equipment_rules.runewords(enabled))
        issues=[]
        for table in ['Weapons','Armors','Items']:
            for rec in self.db[table]:
                if not rec: continue
                if table != 'Items':
                    rec['equipment'] = equipment_rules.definition(rec, enabled['YEP_X_ItemUpgradeSlots'])
                    custom = equipment_rules.custom_params(rec)
                    if custom:
                        rec['customParams'] = custom
                        if 'unsupported' in custom:
                            issues.append({'table':table,'id':rec['id'],'customParams':custom['unsupported']})
                if table == 'Items':
                    rule = equipment_rules.upgrade(rec)
                    if rule['weapon'] or rule['armor'] or rule['issues']:
                        rec['upgrade'] = rule
                        issues += [{'table':table,'id':rec['id'],'line':line} for line in rule['issues']]
            self.write_json('db/%s.json' % table,self.db[table])
        self.issues += [{'unsupportedCustomParams' if 'customParams' in r else 'unsupportedUpgrade':r} for r in issues]

    # ---- 切片引用收集 ----
    def ref_img(self, folder, name):
        if name:
            self.img.add(f'{folder}/{name}')

    def ref_super_sv(self, meta):
        """Mx_SuperSV：<sv:名> 与 <SVzs动作:帧数> 的逐帧图 sv_actors/sv/名/名动作_帧（XAppearance 读取）。"""
        name = str(meta.get('sv', '')).strip() if isinstance(meta.get('sv'), str) else ''
        if not name or re.search(r'[\\/:\x00-\x1f]', name) or name in ('.', '..'):
            return
        for i in range(18):
            n = str(meta.get(f'SVzs{i}', '')).strip()
            if n.isdigit() and 0 < int(n) <= 4096:
                for f in range(int(n)):
                    self.ref_img('sv_actors', f'sv/{name}/{name}{i}_{f}')

    def ref_audio(self, folder, obj):
        if isinstance(obj, dict) and obj.get('name'):
            self.audio.add(f'{folder}/{obj["name"]}')

    def walk_commands(self, lst, troops):
        for c in lst:
            code, p = c['code'], c['parameters']
            if code == 101 and p[0]:
                self.ref_img('faces', p[0])
            elif code == 301 and p[0] == 0:
                troops.add(p[1])
            elif code == 322:
                self.ref_img('characters', p[1]); self.ref_img('faces', p[3]); self.ref_img('sv_actors', p[5])
            elif code in (241, 245, 249, 250, 132, 133, 139):
                self.ref_audio({241: 'bgm', 132: 'bgm', 245: 'bgs', 249: 'me', 133: 'me', 139: 'me', 250: 'se'}[code], p[0])
            elif code == 231:
                self.ref_img('pictures', p[1])
            elif code == 117:
                self.common_events.add(p[0])
            elif code == 129 and p[1] == 0:
                self.event_actors.add(p[0])
            elif code == 212:
                self.event_animations.add(p[1])
            elif code == 205:
                for m in p[1].get('list', []):
                    if m.get('code') == 44 and m.get('parameters'):
                        self.ref_audio('se', m['parameters'][0])
                    elif m.get('code') == 41 and m.get('parameters'):
                        self.ref_img('characters', m['parameters'][0])
            elif code == 283:
                self.ref_img('battlebacks1', p[0]); self.ref_img('battlebacks2', p[1])

    def collect_slice(self):
        cfg, db = self.cfg, self.db
        # extraCommonEvents：只经物品／技能效果（code 44）调用、地图事件不会 117 到的公共事件（如物品 1653 洪荒技能书随机抽奖 → CE1441）
        troops, self.common_events = set(cfg.get('troops', [])), set(cfg.get('extraCommonEvents', []))
        self.event_actors, self.event_animations = set(), set()
        actors = set(cfg['actors'])
        for mid in cfg['maps']:
            rel = f'data/Map{mid:03d}.json'
            m = self.read(rel)
            m['meta'] = extract_meta(m.get('note'))
            self.write_json(f'maps/Map{mid:03d}.json', m)
            ts = db['Tilesets'][m['tilesetId']]
            for n in ts['tilesetNames']:
                self.ref_img('tilesets', n)
            self.ref_audio('bgm', m.get('bgm')); self.ref_audio('bgs', m.get('bgs'))
            self.ref_img('parallaxes', m.get('parallaxName'))
            self.ref_img('battlebacks1', m.get('battleback1Name')); self.ref_img('battlebacks2', m.get('battleback2Name'))
            for enc in m['encounterList']:
                troops.add(enc['troopId'])
            for ev in m['events']:
                if not ev:
                    continue
                for pg in ev['pages']:
                    self.ref_img('characters', pg['image']['characterName'])
                    self.walk_commands(pg['list'], troops)
        seen = set()
        while self.common_events - seen:
            ce = (self.common_events - seen).pop()
            seen.add(ce)
            if 0 < ce < len(db['CommonEvents']) and db['CommonEvents'][ce]:
                self.walk_commands(db['CommonEvents'][ce]['list'], troops)
        self.slice_troops = sorted(troops)
        # 事件里入队的角色（开局的孙悟空 52、里德 11 等）也要带上素材；对照用的 actors 仍以切片配置为准
        event_actors = {a for a in self.event_actors if 0 < a < len(db['Actors']) and db['Actors'][a]} - actors
        actors = actors | event_actors
        for aid in actors:
            a = db['Actors'][aid]
            self.ref_img('faces', a['faceName']); self.ref_img('characters', a['characterName']); self.ref_img('sv_actors', a['battlerName'])
            self.ref_super_sv(a['meta'])
        enemies = set()
        for tid in troops:
            t = db['Troops'][tid]
            for mem in t['members']:
                enemies.add(mem['enemyId'])
            for pg in t['pages']:
                self.walk_commands(pg['list'], set())
                # 336 敌人变身的新形态（三十层玉皇大帝 534→538）：战斗图、技能与动画同敌群成员一起带上
                enemies |= {c['parameters'][1] for c in pg['list'] if c['code'] == 336}
        skills = set(cfg.get('extraSkills', [1, 2]))
        for aid in actors:
            cls = db['Classes'][db['Actors'][aid]['classId']]
            skills |= {l['skillId'] for l in cls['learnings'] if l['level'] <= cfg.get('maxLevel', 30)}
        for eid in enemies:
            e = db['Enemies'][eid]
            side = e['meta'].get('Sideview Battler')
            if side:
                self.ref_img('sv_actors', side.strip())
                self.ref_super_sv(e['meta'])
            else:
                self.ref_img('sv_enemies' if db['System']['optSideView'] else 'enemies', e['battlerName'])
            skills |= {a['skillId'] for a in e['actions']}
        anims = {db['Skills'][s]['animationId'] for s in skills if 0 < s < len(db['Skills']) and db['Skills'][s]}
        anims |= {int(x) for x in cfg.get('extraAnimations', [])} | self.event_animations
        # MOG_TrPopUpBattle：掉落图标上播放物品备注 <dh:N> 的动画（数据库掉落与 YEP_ExtraEnemyDrops 追加掉落）
        tables = {1: 'Items', 2: 'Weapons', 3: 'Armors'}
        for eid in enemies:
            e = db['Enemies'][eid]
            drops = [(d['kind'], d['dataId']) for d in e.get('dropItems', []) if d.get('kind', 0) > 0]
            block = re.search(r'<Enemy Drops>(.*?)</Enemy Drops>', e.get('note', ''), re.I | re.S)
            if block:
                for kind, did in re.findall(r'(Item|Weapon|Armor)\s+(\d+)\s*:', block.group(1), re.I):
                    drops.append(({'item': 1, 'weapon': 2, 'armor': 3}[kind.lower()], int(did)))
            for kind, did in drops:
                rows = db[tables[kind]]
                rec = rows[did] if 0 < did < len(rows) else None
                dh = str((rec or {}).get('meta', {}).get('dh', '')).strip()
                if dh.isdigit():
                    anims.add(int(dh))
        for wid in range(1, min(len(db['Weapons']), cfg.get('weaponScan', 200))):
            w = db['Weapons'][wid]
            if w:
                anims.add(w['animationId'])
        for aid in anims:
            if 0 < aid < len(db['Animations']) and db['Animations'][aid]:
                an = db['Animations'][aid]
                self.ref_img('animations', an['animation1Name']); self.ref_img('animations', an['animation2Name'])
                for t in an['timings']:
                    self.ref_audio('se', t.get('se'))
        sysd = db['System']
        for k in ('battleBgm', 'victoryMe', 'defeatMe', 'gameoverMe', 'titleBgm'):
            folder = 'bgm' if k.endswith('Bgm') else 'me'
            self.ref_audio(folder, sysd.get(k))
        for s in sysd['sounds']:
            self.ref_audio('se', s)
        for name in cfg.get('systemImages', []):
            self.ref_img('system', name)
        # 武器挥动图（MV Sprite_Weapon：第 n 张 = Weapons{(n-1)//12+1}）：系统攻击动作与 YEP_WeaponAnimation <Weapon Image: n>
        weapon_images = {m['weaponImageId'] for m in sysd.get('attackMotions', []) if m and m.get('weaponImageId', 0) > 0}
        for w in db['Weapons']:
            if w:
                found = re.search(r'<Weapon Image:\s*(\d+)>', w.get('note', ''), re.I)
                if found:
                    weapon_images.add(int(found.group(1)))
        for page in sorted({(i - 1) // 12 + 1 for i in weapon_images}):
            self.ref_img('system', 'Weapons%d' % page)
        # 更衣换装表（Star_ChangeClothes「ChangeClothes 1～150」）的行走图：衣橱名单与形象展示、替换后的玩家行走图（XChangeClothes）
        for i in range(1, 151):
            raw = self.plugins.get('Star_ChangeClothes', {}).get(f'ChangeClothes {i}') or ''
            if raw.strip():
                self.ref_img('characters', json.loads(raw).get('characterName'))
        # 界面用图（标题、菜单底图等），写成「文件夹/文件名」
        for rel in cfg.get('extraImages', []):
            self.img.add(rel)
        for rel in cfg.get('extraAudio', []):
            self.audio.add(rel)
        self.collect_transfer_preview()
        self.slice_info = {'maps': cfg['maps'], 'actors': sorted(actors - event_actors), 'eventActors': sorted(event_actors), 'troops': self.slice_troops,
                           'enemies': sorted(enemies), 'skills': sorted(skills), 'animations': sorted(a for a in anims if a > 0),
                           'commonEvents': sorted(seen), 'transferPreviewEnemies': len(self.transfer_enemies)}

    def collect_transfer_preview(self):
        """MapTransferPlugin 的敌人预览：每张配置地图只取 encounterList 的敌群（地图本体不导出），
        连同额外怪物的战斗图一起带上（sv_enemies，或 <Sideview Battler> 指定的 sv_actors）。"""
        db = self.db
        raw = self.plugins.get('MapTransferPlugin', {}).get('Map Settings') or '[]'
        preview, enemies = {}, set()
        for setting in (json.loads(x) for x in json.loads(raw)):
            mid = int(setting['id'])
            rel = f'data/Map{mid:03d}.json'
            if not (self.app / rel).exists():
                self.issues.append({'missingTransferMap': rel})
                continue
            troops = [int(e['troopId']) for e in self.read(rel).get('encounterList', [])]
            preview[str(mid)] = troops
            for tid in troops:
                if 0 < tid < len(db['Troops']) and db['Troops'][tid]:
                    enemies |= {m['enemyId'] for m in db['Troops'][tid]['members'] if m['enemyId'] > 0}
            enemies |= {int(x) for x in (setting.get('extraEnemies') or '').split(',') if x.strip().isdigit()}
        for eid in sorted(enemies):
            e = db['Enemies'][eid] if 0 < eid < len(db['Enemies']) else None
            if not e:
                continue
            side = e['meta'].get('Sideview Battler')
            if side:
                self.ref_img('sv_actors', side.strip())
            else:
                self.ref_img('sv_enemies', e['battlerName'])
        self.write_json('db/MapPreview.json', preview)
        self.transfer_enemies = sorted(enemies)

    def copy_assets(self):
        def as_png(src, data):
            # 原版有扩展名是 .png、内容是 JPEG／WebP 的图（如 162 诛仙的 小诛仙、guanxi7_1），NW.js 按内容解码，
            # Godot 按扩展名导入会报 Not a PNG file；这类图用 sips 转成真 PNG 再 normalize_png（输出逐字节稳定），其余原样
            if not (data.startswith(b'\xff\xd8\xff') or (data[:4] == b'RIFF' and data[8:12] == b'WEBP')):
                return data
            with tempfile.TemporaryDirectory(prefix='xiyou-png-') as tmp:
                out = Path(tmp) / 'out.png'
                subprocess.run(['sips', '-s', 'format', 'png', str(src), '--out', str(out)], check=True, capture_output=True)
                return normalize_png(out.read_bytes())

        def find(base, rel, exts):
            for ext in exts:
                p = self.app / base / (rel + ext)
                if p.exists():
                    return p, ext
            return None, None
        for kind, refs, exts in (('img', self.img, ['.png', '.jpg']), ('audio', self.audio, ['.ogg', '.m4a'])):
            for rel in sorted(refs):
                src, ext = find(kind, rel, exts)
                if not src:
                    self.issues.append({'missingAsset': f'{kind}/{rel}'})
                    continue
                data = src.read_bytes()
                out = as_png(src, data) if kind == 'img' and ext == '.png' else data
                self.write_changed(f'{kind}/{rel}{ext}', out, source=src)
                self.inputs[f'{kind}/{rel}{ext}'] = sha(data)
                self.outputs[f'{kind}/{rel}{ext}'] = sha(out)
        # 界面字体（原版 fonts/gamefont.css 指向的 GameFont）连同授权文件原样复制
        for name in self.cfg.get('fonts', []):
            src = self.app / 'fonts' / name
            if not src.exists():
                self.issues.append({'missingAsset': f'fonts/{name}'})
                continue
            data = src.read_bytes()
            self.write_changed(f'fonts/{name}', data, source=src)
            digest = sha(data)
            self.inputs[f'fonts/{name}'] = digest
            self.outputs[f'fonts/{name}'] = digest

    def run(self):
        self.out.mkdir(parents=True, exist_ok=True)
        pkg = self.read('package.json')
        # 脚本是运行规则来源；与数据库同时取指纹，便于阻止旧 oracle 混用。
        runtime_inputs = {str(p.relative_to(self.app)): sha(p.read_bytes())
                          for p in sorted((self.app / 'js').rglob('*.js'))}
        self.export_db()
        self.export_plugins()
        self.collect_slice()
        self.copy_assets()
        untranslated = []
        for sid in self.slice_info['skills']:
            s = self.db['Skills'][sid]
            if s and s['damage']['type'] and s['damage']['formulaProgram']['status'] == 'unsupported':
                untranslated.append({'skill': sid, 'name': s['name'], 'formula': s['damage']['formula'], 'why': s['damage']['formulaProgram'].get('diagnostic')})
        all_bad = sum(1 for s in self.db['Skills'] if s and s['damage']['type'] and s['damage']['formulaProgram']['status'] == 'unsupported')
        program_stats = {}
        for table in ['Skills', 'Items']:
            counts = {'pureSupported': 0, 'effectfulSupported': 0, 'moduleSupported': 0, 'unsupportedActiveDamage': 0, 'unsupportedNoDamage': 0}
            for rec in self.db[table]:
                if not rec or 'damage' not in rec:
                    continue
                status = rec['damage']['formulaProgram']['status']
                key = 'pureSupported' if status == 'pure' else 'effectfulSupported' if status == 'effectful' else 'moduleSupported' if status == 'module' else 'unsupportedActiveDamage' if rec['damage']['type'] else 'unsupportedNoDamage'
                counts[key] += 1
            reachable = set(self.slice_info.get('skills' if table == 'Skills' else 'items', []))
            counts['reachableSupported'] = sum(1 for rec in self.db[table] if isinstance(rec, dict) and rec.get('id') in reachable and 'damage' in rec and rec['damage']['formulaProgram']['status'] in ('pure', 'effectful', 'module'))
            counts['reachablePending'] = sum(1 for rec in self.db[table] if isinstance(rec, dict) and rec.get('id') in reachable and 'damage' in rec and rec['damage']['formulaProgram']['status'] == 'unsupported')
            counts['reachabilityUnknown'] = sum(1 for rec in self.db[table] if isinstance(rec, dict) and rec.get('id') not in reachable and 'damage' in rec)
            program_stats[table] = counts
        manifest = {'tool': 'xiyou_export.py', 'toolVersion': TOOL_VERSION, 'source': str(self.app),
                    'releaseVersion': pkg.get('releaseVersion'), 'slice': self.slice_info,
                    'runtimeInputs': runtime_inputs,
                    'sliceConfigSHA256': sha(json.dumps(self.cfg, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()),
                    'formulaUntranslatedInSlice': untranslated, 'formulaUntranslatedAllSkills': all_bad,
                    'formulaPrograms': {'version': 1, 'execution': 'explicit-runtime', 'tables': program_stats},
                    'issues': self.issues, 'inputs': self.inputs, 'outputs': self.outputs}
        # 生成期间源若发生变化，候选不可用；不将混合来源登记成成功结果。
        changed = [rel for hashes in [self.inputs, runtime_inputs] for rel, digest in hashes.items()
                   if sha((self.app / rel).read_bytes()) != digest]
        if changed:
            raise RuntimeError('生成期间来源改变：' + ', '.join(changed[:10]))
        self.write_json('slice.json', self.cfg)
        for rel, data in self.pending_json.items():
            self.write_changed(rel, data)
        self.remove_stale()
        self.write_changed('manifest.json', (json.dumps(manifest, ensure_ascii=False, indent=1) + '\n').encode('utf-8'))
        size = sum(p.stat().st_size for p in self.out.rglob('*') if p.is_file())
        print(json.dumps({'releaseVersion': manifest['releaseVersion'], 'outputs': len(self.outputs), 'bytes': size,
                          'img': len(self.img), 'audio': len(self.audio), 'issues': len(self.issues),
                          'untranslatedInSlice': len(untranslated), 'untranslatedAll': all_bad,
                          'written': self.written, 'unchanged': self.unchanged, 'deleted': self.deleted,
                          'slice': {k: (len(v) if isinstance(v, list) else v) for k, v in self.slice_info.items()}}, ensure_ascii=False))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--app', type=Path, default=DEFAULT_APP)
    ap.add_argument('--out', type=Path, default=DEFAULT_OUT)
    ap.add_argument('--slice', type=Path, default=HERE / 'xiyou_slice.json')
    a = ap.parse_args()
    Exporter(a.app.resolve(), a.out.resolve(), load_json(a.slice)).run()


if __name__ == '__main__':
    sys.exit(main())
