#!/usr/bin/env python3
"""Claude Code PreToolUse 钩子（T108）：拦下按名字杀检查／测试进程的 Bash 命令。

11-16 本机检查三次被 SIGTERM（09:05、18:06、21:24 UTC），都是某条车道想重起自己的检查，跑了
`pkill -f 检查.sh`、`pkill -f 并行测试.py`、`pkill -f Godot`：按名字匹配，全机别的车道和总装的检查一起被杀。
停自己的检查用 `07_开发环境/停止任务.sh <日志>`（不给日志＝停当前工作树登记在跑的全部任务）。

拦的条件：命令里有 pkill／killall，匹配目标涉及 检查.sh、并行测试、长任务、云端选测、占槽、godot、node、python，
且这一段里没写出当前工作树的**完整路径**（写了自己工作树完整路径的 `pkill -f "godot.*--path.*<完整路径>"` 放行）。
不认目录名：目录名可能很泛（名叫 main 的工作树会让 `pkill -f "检查.sh --affected main"` 溜过去），完整路径才不会撞别的车道；
路径后面不能紧跟字母数字._-（防 /a/wt 放行 /a/wt-2）。命令按引号外的 ; & | 换行切段，引号里的管道符不截断。
注册（在 ~/.claude/settings.json 或项目 .claude/settings.json 的 hooks.PreToolUse，matcher 写 Bash）：
  {"type": "command", "command": "python3 <资料库>/03_再刷重制_Godot/07_开发环境/守卫_按名杀进程.py"}
退出码 2＝拦下（理由写 stderr 给模型看），0＝放行；读不懂输入一律放行，不挡正常工作。"""
import json
import re
import subprocess
import sys

KILLER = re.compile(r'\b(?:pkill|killall)\b')
TARGETS = re.compile(r'检查\.sh|并行测试|长任务|云端选测|占槽|godot|\bnode\b|python', re.I)


def worktree(cwd):
    try:
        out = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=cwd, capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else ''
    except (OSError, subprocess.SubprocessError):
        return ''


def segments(command):
    """按引号外的 ; & | 换行切段（引号里的分隔符不切；引号没闭合就当到末尾）。"""
    segs, cur, quote, i = [], [], None, 0
    while i < len(command):
        c = command[i]
        if quote:
            cur.append(c)
            if c == '\\' and quote == '"' and i + 1 < len(command):
                i += 1
                cur.append(command[i])
            elif c == quote:
                quote = None
        elif c in '"\'':
            quote = c
            cur.append(c)
        elif c == '\\' and i + 1 < len(command):
            cur.append(c)
            i += 1
            cur.append(command[i])
        elif c in ';&|\n':
            segs.append(''.join(cur))
            cur = []
        else:
            cur.append(c)
        i += 1
    segs.append(''.join(cur))
    return segs


def names_tree(seg, tree):
    return bool(tree) and re.search(re.escape(tree) + r'(?![\w.\-])', seg) is not None


def verdict(command, cwd):
    """返回拦下的理由；放行返回 None。"""
    tree = worktree(cwd) if cwd else ''
    for seg in segments(command or ''):
        m = KILLER.search(seg)
        seg = seg[m.start():] if m else ''
        if seg and TARGETS.search(seg) and not names_tree(seg, tree):
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
