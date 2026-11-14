#!/bin/zsh
# 清理已并入 main 的本地分支与远程分支（默认仅 dry-run 预览，不修改仓库）。
# 用法：
#   清理已合并分支.sh                  # 默认 dry-run：列出可安全删除的本地已合并分支与远程已合并分支
#   清理已合并分支.sh --apply-local    # 实际执行 git branch -d 删除无工作树占用的本地已合并分支
#   清理已合并分支.sh --print-remote-cmd # 输出批量删除 github 已并入 main 远程分支的命令（供人工确认后执行）
set -eu

ENV_DIR=${0:A:h}
SELF_ROOT=${ENV_DIR:h:h}
MAIN=${$(git -C "$SELF_ROOT" rev-parse --path-format=absolute --git-common-dir):h}

MODE="dry-run"
if (( $# >= 1 )); then
  case "$1" in
    --apply-local) MODE="apply-local" ;;
    --print-remote-cmd) MODE="print-remote-cmd" ;;
    -h|--help)
      print "用法：${0:t} [--apply-local | --print-remote-cmd]"
      print "  默认（无参数）：dry-run 预览可删的本地已合并分支与远程已合并分支数量"
      print "  --apply-local：执行 git branch -d 删除已并入 main 且未被 worktree 占用的本地分支"
      print "  --print-remote-cmd：打印删除 github 远程已合并分支的命令（不自动推送删除）"
      exit 0
      ;;
    *)
      print -u2 "未知参数：$1"
      exit 64
      ;;
  esac
fi

# 收集当前被 worktree 占用的本地分支
typeset -A wt_branches
while IFS= read -r line; do
  if [[ $line == branch\ refs/heads/* ]]; then
    b=${line#branch refs/heads/}
    wt_branches[$b]=1
  fi
done < <(git -C "$MAIN" worktree list --porcelain)

# 1. 本地已并入 main 的分支（排除 main、当前分支及有 worktree 占用的分支）
local_candidates=()
while IFS= read -r b; do
  [[ -z $b || $b == "main" ]] && continue
  [[ -n ${wt_branches[$b]:-} ]] && continue
  local_candidates+=("$b")
done < <(git -C "$MAIN" branch --merged main | sed 's/^[*+[:space:]]*//')

print "=== 本地已并入 main 且无 worktree 占用的分支（${#local_candidates[@]} 个）==="
if (( ${#local_candidates[@]} == 0 )); then
  print "  （无）"
else
  for b in "${local_candidates[@]}"; do
    if [[ $MODE == "apply-local" ]]; then
      git -C "$MAIN" branch -d "$b"
    else
      print "  [dry-run] git -C \"$MAIN\" branch -d $b"
    fi
  done
fi

# 2. 远程 github 已并入 github/main 的分支（排除 github/main 与 github/HEAD）
remote_candidates=()
while IFS= read -r r; do
  [[ -z $r || $r == *"->"* || $r == "github/main" ]] && continue
  if [[ $r == github/* ]]; then
    remote_candidates+=("${r#github/}")
  fi
done < <(git -C "$MAIN" branch -r --merged github/main 2>/dev/null | sed 's/^[[:space:]]*//' || true)

print ""
print "=== github 远程已并入 github/main 的分支（${#remote_candidates[@]} 个）==="
if (( ${#remote_candidates[@]} == 0 )); then
  print "  （无）"
elif [[ $MODE == "print-remote-cmd" ]]; then
  print "请人工复核后分批执行："
  print "git -C \"$MAIN\" push github --delete \\"
  for b in "${remote_candidates[@]}"; do
    print "  \"$b\" \\"
  done
else
  print "  [dry-run] 共有 ${#remote_candidates[@]} 个远程分支已并入 github/main（可用 --print-remote-cmd 生成删除命令）"
fi
