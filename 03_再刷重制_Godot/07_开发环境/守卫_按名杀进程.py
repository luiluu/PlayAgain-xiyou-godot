#!/usr/bin/env python3
"""Claude Code PreToolUse 钩子（T108）：拦下按名字杀检查／测试进程的 Bash 命令。

11-16 本机检查三次被 SIGTERM（09:05、18:06、21:24 UTC），都是某条车道想重起自己的检查，跑了
`pkill -f 检查.sh`、`pkill -f 并行测试.py`、`pkill -f Godot`：按名字匹配，全机别的车道和总装的检查一起被杀。
停自己的检查用 `07_开发环境/停止任务.sh <日志>`（不给日志＝停当前工作树登记在跑的全部任务）。

拦的条件：命令里有 pkill／killall，匹配目标涉及 检查.sh、并行测试、长任务、云端选测、占槽、godot、node、python，
且这一段里没写出当前工作树的路径或目录名（写了自己工作树路径的 `pkill -f "godot.*--path.*<我的工作树>"` 放行）。
注册（在 ~/.claude/settings.json 或项目 .claude/settings.json 的 hooks.PreToolUse，matcher 写 Bash）：
  {"type": "command", "command": "python3 <资料库>/03_再刷重制_Godot/07_开发环境/守卫_按名杀进程.py"}
退出码 2＝拦下（理由写 stderr 给模型看），0＝放行；读不懂输入一律放行，不挡正常工作。"""
import json
import re
import subprocess
import sys
from pathlib import Path

KILLERS = re.compile(r'\b(?:pkill|killall)\b[^;&|\n]*')
TARGETS = re.compile(r'检查\.sh|并行测试|长任务|云端选测|占槽|godot|\bnode\b|python', re.I)


def worktree(cwd):
    try:
        out = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=cwd, capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else ''
    except (OSError, subprocess.SubprocessError):
        return ''


def verdict(command, cwd):
    """返回拦下的理由；放行返回 None。"""
    tree = worktree(cwd) if cwd else ''
    marks = [m for m in (tree, Path(tree).name if tree else '') if m and len(m) >= 4]
    for seg in KILLERS.findall(command or ''):
        if TARGETS.search(seg) and not any(m in seg for m in marks):
            return ('按名字杀进程会把别的车道和总装的检查一起杀掉（T108，11-16 三次）：「%s」。'
                    '停自己的检查用 03_再刷重制_Godot/07_开发环境/停止任务.sh <日志>（不给日志＝停本工作树在跑的任务）；'
                    '真要按名字清残留，匹配串里写上本工作树路径。' % seg.strip())
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    if data.get('tool_name') != 'Bash':
        return 0
    why = verdict((data.get('tool_input') or {}).get('command', ''), data.get('cwd'))
    if why:
        print(why, file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
