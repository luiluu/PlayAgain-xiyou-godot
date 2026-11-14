#!/usr/bin/env python3
"""随机守卫（cc/save-rng-facade R1，方案第 2.6 节）：天启篇脚本里不许用全局随机，读档后不该变的随机一律走 XTianqiRandom。

范围：发行空壳认的天启篇脚本全集（发行空壳.targets()：类名 XTianqi*／XRiftAlien、XGojo、XGuardianRework，含两个门面文件）
     ＋ EXTRA_FILES（不带天启篇类名、但天启篇存档的随机走它的：法宝喂养、抽奖重做）。
报错的写法（去掉注释和字符串后查）：
  - 前面不带「.」的全局 randf( randi( randf_range( randi_range( randfn( randomize( seed(
  - 任何 .randomize()、XRandomStream.fresh_seed(、.pick_random(、.shuffle(（后两个用全局发生器）
  - RandomNumberGenerator.new() 后紧跟的一句没有定种子（.seed =，或注了放行的 randomize）；是 if 链就要有 else、每个分支都定种子；
    是 for／while 就看循环体
放行：真正的行尾注释（字符串之外的 #）写「# 表现」（纯表现：抖动、裂纹、相位）或「# 随机守卫：<理由>」（如「开关关时的旧路」）。
字符串（含三引号多行字符串）里的内容不查。
用法：
  python3 随机守卫.py          检查，违规逐条打出 文件:行，退出码 1
  python3 随机守卫.py --list   打印检查范围
为什么：seed-fix 那轮靠手工「漏网清单」找全局 randf，读档能重掷的口子一个个返修；这个检查让新代码一写就被挡下。
身份规则见 modes/xiyou/core/tianqi_random.gd 头注释。"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import 发行空壳  # noqa: E402

PROJECT = HERE.parent / '01_Godot工程'
EXTRA_FILES = (
    'modes/xiyou/core/fabao_feed.gd',
    'modes/xiyou/core/lottery_rework.gd',
)
ALLOW = re.compile(r'#\s*(表现|随机守卫[:：])')
GLOBAL_CALL = re.compile(r'(?<![\w.])(randf|randi|randf_range|randi_range|randfn|randomize|seed)\s*\(')
ANY_CALL = re.compile(r'\.randomize\s*\(|\bXRandomStream\.fresh_seed\s*\(|\.pick_random\s*\(|\.shuffle\s*\(')
RNG_NEW = re.compile(r'\bRandomNumberGenerator\.new\s*\(')
FUNC_DEF = re.compile(r'^\s*(static\s+)?func\s')


def _scan(line: str, state):
    """把一行拆成（代码, 行尾注释, 下一行开头的状态）。代码里字符串内容去掉、只留空引号（免得字符串里的 randf( 误报）；
    注释只认在字符串之外的 #（字符串里的「# 表现」不算放行）。state＝None 或跨行未闭合的三引号（\"\"\" / \'\'\'）。"""
    out, q = [], state
    i = 0
    while i < len(line):
        if q:
            if line[i] == '\\':
                i += 2
                continue
            if line.startswith(q, i):
                out.append(q[0])
                i += len(q)
                q = None
                continue
            i += 1
            continue
        ch = line[i]
        if line.startswith('"""', i) or line.startswith("\'\'\'", i):
            q = line[i:i + 3]
            out.append(ch)
            i += 3
            continue
        if ch in '"\'':
            q = ch
            out.append(ch)
        elif ch == '#':
            return ''.join(out), line[i:], None
        else:
            out.append(ch)
        i += 1
    return ''.join(out), '', (q if q and len(q) == 3 else None)  # 单引号字符串不跨行


def _code(line: str) -> str:
    return _scan(line, None)[0]


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip('\t '))


def _seeded(code: str, comment: str) -> bool:
    """这一句定了种子：.seed =（不是 ==），或注了放行（如 rng.randomize()  # 表现）。"""
    return bool(re.search(r'\.seed\s*=(?!=)', code)) or bool(ALLOW.search(comment))


def _rng_seeded(rows: list, i: int) -> bool:
    """RandomNumberGenerator.new() 在第 i 行：之后第一句碰到它的（同层）必须定种子；是 if 链就要有 else 且每个分支都定了种子；
    是 for／while 就看循环体里有没有定种子。rows＝[(缩进, 代码, 注释)]，空行和整行注释已标成 None。"""
    base = rows[i][0]
    m = re.search(r'(\w+)\s*:?=\s*RandomNumberGenerator\.new', rows[i][1])
    name = re.compile(r'\b%s\b' % re.escape(m.group(1))) if m else None
    j = i + 1
    # 同层、不碰这个发生器、也不是块头的句子（如先取存档字段）跳过
    while j < len(rows) and (rows[j] is None or (name and rows[j][0] == base and not name.search(rows[j][1])
                                                  and not rows[j][1].rstrip().endswith(':'))):
        j += 1
    if j >= len(rows) or rows[j][0] < base:
        return False
    ind, code, comment = rows[j]

    def body(k):  # 第 k 行头下面缩进更深的各行，返回 (这些行, 下一个同层行号)
        out = []
        k += 1
        while k < len(rows) and (rows[k] is None or rows[k][0] > ind):
            if rows[k] is not None:
                out.append(rows[k])
            k += 1
        return out, k

    head = code.strip()
    if re.match(r'(for|while)\b', head):
        lines, _ = body(j)
        return any(_seeded(c, m) for _, c, m in lines)
    if re.match(r'if\b', head):
        k, has_else = j, False
        while True:
            lines, nxt = body(k)
            if not any(_seeded(c, m) for _, c, m in lines):
                return False
            if nxt < len(rows) and rows[nxt][0] == ind and re.match(r'(elif\b|else\s*:)', rows[nxt][1].strip()):
                has_else = has_else or rows[nxt][1].strip().startswith('else')
                k = nxt
                continue
            return has_else
    return _seeded(code, comment)


def files(root: Path = PROJECT) -> list:
    out = {str(p) for p in 发行空壳.targets(root).values()}
    for f in EXTRA_FILES:
        if (root / f).exists():
            out.add(f)
    return sorted(out)


def check_text(text: str, rel: str = '<文本>') -> list:
    errs = []
    rows, state = [], None
    for raw in text.splitlines():
        code, comment, state = _scan(raw, state)
        rows.append((_indent(raw), code, comment) if code.strip() else None)  # 空行、整行注释、整行在三引号字符串里的记 None
    for i, row in enumerate(rows):
        if row is None:
            continue
        _, code, comment = row
        if ALLOW.search(comment):
            continue
        if FUNC_DEF.match(code):
            continue  # 函数定义（如 static func seed(…)）不算调用
        m = GLOBAL_CALL.search(code) or ANY_CALL.search(code)
        if m:
            errs.append(f'{rel}:{i + 1}: 全局随机 {m.group(0).strip()}…（改走 XTianqiRandom；纯表现行尾注「# 表现」，确需的注「# 随机守卫：理由」）')
            continue
        if RNG_NEW.search(code) and not _rng_seeded(rows, i):
            errs.append(f'{rel}:{i + 1}: RandomNumberGenerator.new() 后紧跟的一句（各分支）没有定种子 .seed =（种子由存档派生；表现用的注「# 表现」）')
    return errs


def check(root: Path = PROJECT) -> list:
    errs = []
    for rel in files(root):
        errs += check_text((root / rel).read_text(encoding='utf-8'), rel)
    return errs


def main(argv) -> int:
    ap = argparse.ArgumentParser(description='天启篇脚本禁用全局随机')
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args(argv)
    if a.list:
        for f in files():
            print(f)
        return 0
    errs = check()
    if errs:
        print('✗ 随机守卫：天启篇脚本里有全局随机（%d 处）' % len(errs))
        for e in errs:
            print('  ' + e)
        return 1
    print('✓ 随机守卫：%d 个天启篇脚本没有未注明的全局随机' % len(files()))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
