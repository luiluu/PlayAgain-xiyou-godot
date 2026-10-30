#!/bin/zsh
# 给主仓库装 main 提交守卫（git-hooks/main-guard.sh → <共用 .git>/hooks/pre-commit、pre-merge-commit）。
# 所有 worktree 共用这套 hooks，守卫只在「工作树根＝主工作区且当前分支是 main」时拦；没设 XIYOU_MAIN_COMMIT=1 就拒绝提交。
# 用法：装提交守卫.sh [--check]    幂等；--check 只看装没装（没装返回 1）。新建工作树.sh 每次都会顺手装。
# 已有别人写的同名 hook（不带守卫标记）不覆盖，打印提示并返回 2。
set -u
ENV_DIR=${0:A:h}
SRC=$ENV_DIR/git-hooks/main-guard.sh
HOOKS=$(git -C "$ENV_DIR" rev-parse --path-format=absolute --git-common-dir)/hooks
MARK=xiyou-main-commit-guard
rc=0
for name in pre-commit pre-merge-commit; do
  dst=$HOOKS/$name
  if [[ -e $dst ]] && ! grep -q "$MARK" "$dst"; then
    print -u2 "✗ $dst 已有别的 hook，没覆盖；把 $SRC 的内容并进去"; rc=2; continue
  fi
  if [[ ${1:-} == --check ]]; then
    [[ -x $dst ]] && cmp -s "$SRC" "$dst" || { print "未装或不是最新：$dst"; (( rc )) || rc=1; }
    continue
  fi
  mkdir -p "$HOOKS"
  cmp -s "$SRC" "$dst" 2>/dev/null || { cp "$SRC" "$dst"; print "已装提交守卫：$dst"; }
  chmod +x "$dst"
done
exit $rc
