#!/bin/zsh
# 多会话并行：车道合并回 main 后删除其 worktree 与分支（规则见 AGENTS.md「多会话并行」）。
# 用法：清理工作树.sh <任务名或 worktree 路径>
# 只删除干净且已并入 main 的 worktree；未并入的分支不删，请先合并或自行处理。
# worktree 里 04_验证/本地结果/ 的证据先移到主工作区 04_验证/本地结果/worktree_<目录名>/ 再删除。
set -eu
ENV_DIR=${0:A:h}
SELF_ROOT=${ENV_DIR:h:h}
MAIN=${$(git -C "$SELF_ROOT" rev-parse --path-format=absolute --git-common-dir):h}
GODOT_SUB=03_再刷重制_Godot

(( $# == 1 )) || { print -u2 "用法：${0:t} <任务名或 worktree 路径>"; exit 64; }
wt=$1
[[ -d $wt ]] || wt=${MAIN:h}/${MAIN:t}-wt-$1
wt=${wt:A}
[[ -d $wt && -e $wt/.git ]] || { print -u2 "✗ 找不到 worktree：$1"; exit 1; }
[[ $wt != $MAIN ]] || { print -u2 "✗ 不能删除主工作区"; exit 1; }
[[ $SELF_ROOT != $wt ]] || { print -u2 "✗ 请在主工作区运行（当前脚本就在要删除的 worktree 里）"; exit 1; }
branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD)
if [[ -n $(git -C "$wt" status --porcelain) ]]; then
  print -u2 "✗ $wt 有未提交改动或未跟踪文件，先提交或处理："; git -C "$wt" status --short | head -10; exit 1
fi
if ! git -C "$MAIN" merge-base --is-ancestor "$(git -C "$wt" rev-parse HEAD)" main; then
  print -u2 "✗ 工作区 HEAD（$branch）还没有并入 main，不删除"; exit 1
fi
evidence=$wt/$GODOT_SUB/04_验证/本地结果
if [[ -d $evidence ]] && [[ -n $(ls -A "$evidence") ]]; then
  keep=$MAIN/$GODOT_SUB/04_验证/本地结果/worktree_${wt:t}
  mkdir -p "$keep"
  mv "$evidence"/*(D) "$keep"/
  print "  证据已移到 $keep"
fi
# 剩下的都是 .gitignore 里的再生成文件（generated、.godot、node_modules、链接），git 不阻止删除
git -C "$MAIN" worktree remove "$wt"
[[ $branch == HEAD ]] || git -C "$MAIN" branch -d "$branch"
print "✓ 已删除 $wt${branch:+（分支 $branch）}"
