#!/bin/sh
# xiyou-main-commit-guard：主工作区 main 的提交守卫（由 装提交守卫.sh 装成 pre-commit 与 pre-merge-commit）。
# 车道会话误在主工作区目录里 git commit（cwd 跑偏、git -C 指错）会把总装未提交的改动提交成别人的提交；
# 守卫只在「工作树根＝主工作区、当前分支是 main」时拦，车道自己的 worktree 与其它分支不受影响。
# 总装工具（合并车道.py）自带 XIYOU_MAIN_COMMIT=1；总装手动提交时自己加：XIYOU_MAIN_COMMIT=1 git commit …
# 合并在准备／收尾中（.git/lane-merge/state.json 在）时只放行合并工具自己的提交（它另带 XIYOU_LANE_MERGE=1）：
# 10-31 总装收尾跑检查时另一位总装在 main 提交了交接板，收尾对不上 head 被卡（总装六，tools22）。
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$(basename "$common")" = .git ] || exit 0
main_root=$(cd "$(dirname "$common")" 2>/dev/null && pwd -P) || exit 0
top=$(cd "$top" 2>/dev/null && pwd -P) || exit 0
[ "$top" = "$main_root" ] || exit 0
[ "$(git symbolic-ref --short -q HEAD)" = main ] || exit 0
state=$common/lane-merge/state.json
if [ -f "$state" ] && [ "${XIYOU_LANE_MERGE:-}" != 1 ]; then
  field() { sed -n "s/^  \"$1\": \"\\(.*\\)\",\\{0,1\\}\$/\\1/p" "$state" | head -n 1; }
  task=$(field task); phase=$(field phase)
  case $phase in
    planned|merged|synced|numbering|versioned) stage="准备中（${phase}）" ;;
    prepared) stage="待收尾（prepared）" ;;
    committed) stage="收尾中（committed）" ;;
    *) stage=${phase:-未知} ;;
  esac
  echo "✗ 有合并在进行（任务 ${task:-未知}，阶段 ${stage}），main 现在不收工具以外的提交（XIYOU_MAIN_COMMIT=1 也不放行）。" >&2
  echo "  把改动留成未提交，等收尾用 合并车道.py --finish --also <文件>／--accept-doc-edits 带入；或先 合并车道.py --abort 撤出这条合并。" >&2
  echo "  现场：${state}" >&2
  exit 1
fi
[ "${XIYOU_MAIN_COMMIT:-}" = 1 ] && exit 0
echo "✗ 这是主工作区 main，车道请回自己的工作树提交（先 git rev-parse --show-toplevel 确认位置）。" >&2
echo "  总装确要在这里提交：XIYOU_MAIN_COMMIT=1 git commit …（合并车道.py 已自带）。" >&2
exit 1
