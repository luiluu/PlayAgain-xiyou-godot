#!/usr/bin/env python3
"""随机守卫（cc/save-rng-facade R1，方案第 2.6 节）：天启篇脚本里不许用全局随机，读档后不该变的随机一律走 XTianqiRandom。

范围：发行空壳认的天启篇脚本全集（发行空壳.targets()：类名 XTianqi*／XRiftAlien、XGojo、XGuardianRework，含两个门面文件）
     ＋ EXTRA_FILES（不带天启篇类名、但天启篇存档的随机走它的：法宝喂养、抽奖重做）。
报错的写法（去掉注释和字符串后查）：
  - 前面不带「.」的全局 randf( randi( randf_range( randi_range( randfn( randomize( seed(
  - 任何 .randomize()、XRandomStream.fresh_seed(、.pick_random(、.shuffle(（后两个用全局发生器）
  - RandomNumberGenerator.new() 之后 3 行内没有 .seed =
放行：行尾注「# 表现」（纯表现：抖动、裂纹、相位）或「# 随机守卫：<理由>」（如「开关关时的旧路」「种子由存档派生」）。
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
SEED_SET = re.compile(r'\.seed\s*=')
FUNC_DEF = re.compile(r'^\s*(static\s+)?func\s')


def _code(line: str) -> str:
    """去掉注释和字符串内容（字符串留成空引号，免得字符串里的 randf( 误报）。"""
    out, q = [], None
    i = 0
    while i < len(line):
        ch = line[i]
        if q:
            if ch == '\\':
                i += 2
                continue
            if ch == q:
                out.append(ch)
                q = None
        elif ch in '"\'':
            q = ch
            out.append(ch)
        elif ch == '#':
            break
        else:
            out.append(ch)
        i += 1
    return ''.join(out)


def files(root: Path = PROJECT) -> list:
    out = {str(p) for p in 发行空壳.targets(root).values()}
    for f in EXTRA_FILES:
        if (root / f).exists():
            out.add(f)
    return sorted(out)


def check_text(text: str, rel: str = '<文本>') -> list:
    errs = []
    lines = text.splitlines()
    for i, raw in enumerate(lines):
        if ALLOW.search(raw):
            continue
        code = _code(raw)
        if FUNC_DEF.match(code):
            continue  # 函数定义（如 static func seed(…)）不算调用
        m = GLOBAL_CALL.search(code) or ANY_CALL.search(code)
        if m:
            errs.append(f'{rel}:{i + 1}: 全局随机 {m.group(0).strip()}…（改走 XTianqiRandom；纯表现行尾注「# 表现」，确需的注「# 随机守卫：理由」）')
            continue
        if RNG_NEW.search(code):
            window = [_code(x) for x in lines[i:i + 4]]
            if not any(SEED_SET.search(x) for x in window):
                errs.append(f'{rel}:{i + 1}: RandomNumberGenerator.new() 之后 3 行内没有 .seed =（种子由存档派生；表现用的注「# 表现」）')
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
