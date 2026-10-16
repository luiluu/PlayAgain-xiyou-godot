#!/bin/zsh
# 多会话并行：给一条车道新建 worktree，并补齐不入 Git 的运行文件（规则见 AGENTS.md「多会话并行」）。
# 用法：
#   新建工作树.sh <任务名> [claude|codex]   从 main 最新提交切出分支 <执行者>/<任务名>，建在主工作区的 .claude/worktrees/<任务名>（已信任的项目文件夹内，开车道会话不用再确认信任；该目录已被 .gitignore 忽略）
#   新建工作树.sh --补齐 <worktree 路径>      只补齐已有 worktree（如桌面 app 自己建的）
# 补齐内容：Godot 引擎链接、西游资料库链接、冻结正式源链接、mv_oracle/node_modules、转换产物 generated/、导入缓存 .godot/。
# node_modules、generated、.godot 用 APFS 克隆（cp -c）复制主工作区的，不另占空间；随后按本分支重跑转换器与 godot --import。
# 已有 generated 时，generated/oracle 里主工作区较新的文件会覆盖进来（本分支自己生成、主工作区没有或比主工作区新的保留）。
if [ -z "${ZSH_VERSION:-}" ]; then
  echo "✗ 本脚本是 zsh 脚本：请直接运行 $0，或用 zsh $0 …（不要用 bash/sh 调用）" >&2
  exit 64
fi
set -euo pipefail
ENV_DIR=${0:A:h}
SELF_ROOT=${ENV_DIR:h:h}
MAIN=${$(git -C "$SELF_ROOT" rev-parse --path-format=absolute --git-common-dir):h}
GODOT_SUB=03_再刷重制_Godot

usage() { print -u2 "用法：${0:t} <任务名> [claude|codex]   或   ${0:t} --补齐 <worktree 路径>"; exit 64; }

# 参照副本按时间戳刷新：主工作区有、本分支没有或比主工作区旧的文件，克隆主工作区的；其余不动。
# 合并 main 后若不刷新，worktree 会拿旧参照对新切片而误报。
refresh_oracle() {
  local src=$1 dst=$2 f n=0 kept=()
  [[ -d $src ]] || return 0
  mkdir -p "$dst"
  for f in "$src"/*(N.); do
    if [[ ! -e $dst/${f:t} || $f -nt $dst/${f:t} ]]; then
      cp -c -p "$f" "$dst/${f:t}"; (( n += 1 ))
    fi
  done
  for f in "$dst"/*(N.); do [[ -e $src/${f:t} ]] || kept+=(${f:t}); done
  print "== generated/oracle：从主工作区刷新 $n 个较新的文件${kept:+；保留本分支独有 ${(j:、:)kept}}"
}

prepare() {
  local wt=${1:A}
  [[ -e $wt/.git ]] || { print -u2 "✗ $wt 不是 git 工作区"; exit 1; }
  [[ $wt != $MAIN ]] || { print -u2 "✗ 这是主工作区，不需要补齐"; exit 1; }
  local env=$wt/$GODOT_SUB/07_开发环境 menv=$MAIN/$GODOT_SUB/07_开发环境
  local tools=$wt/$GODOT_SUB/03_转换工具 mtools=$MAIN/$GODOT_SUB/03_转换工具
  local proj=$wt/$GODOT_SUB/01_Godot工程 mproj=$MAIN/$GODOT_SUB/01_Godot工程
  local gen=$proj/modes/xiyou/generated mgen=$mproj/modes/xiyou/generated
  # 只读共用的外部文件：直接链接
  [[ -e $env/当前Godot.app ]] || ln -s "$menv/当前Godot.app" "$env/当前Godot.app"
  local lib=$wt/02_再刷西游/现有资料库
  [[ -e $lib || ! -L $MAIN/02_再刷西游/现有资料库 ]] || ln -s "$(readlink "$MAIN/02_再刷西游/现有资料库")" "$lib"
  # 冻结正式源（只读，不入 Git）：工具默认用主工作区的绝对路径；按相对路径找它（如 serve.py）时也能找到
  local frozen=$wt/$GODOT_SUB/02_内容与素材/冻结正式源/app.nw
  [[ -e $frozen || ! -d $MAIN/$GODOT_SUB/02_内容与素材/冻结正式源/app.nw ]] || ln -s "$MAIN/$GODOT_SUB/02_内容与素材/冻结正式源/app.nw" "$frozen"
  # 会被写或按路径解析的：克隆一份（链接到主工作区的目录会被 git 当成未跟踪文件，也会让 worktree 改到主工作区）
  [[ -e $tools/mv_oracle/node_modules ]] || cp -cR "$mtools/mv_oracle/node_modules" "$tools/mv_oracle/node_modules"
  if [[ -e $gen ]]; then
    refresh_oracle "$mgen/oracle" "$gen/oracle"
  else
    cp -cR "$mgen" "$gen"
  fi
  [[ -e $proj/.godot ]] || cp -cR "$mproj/.godot" "$proj/.godot"
  print "== 按本分支重跑转换器"
  python3 "$tools/xiyou_export.py" --out "$gen" | tail -1 | cut -c1-160
  print "== godot --import"
  local out rc=0
  out=$(perl -e 'alarm 300; exec @ARGV' "$env/godot" --headless --path "$proj" --import 2>&1) || rc=$?
  if (( rc != 0 )) || grep -qE 'SCRIPT ERROR|^ERROR:' <<< "$out"; then
    print -r -- "$out" | grep -E 'ERROR|FAIL' | head -8
    print -u2 "✗ 导入失败 (rc=$rc)"; exit 1
  fi
  print "✓ 已补齐 $wt"
  print "  分支 $(git -C "$wt" rev-parse --abbrev-ref HEAD)；检查：$GODOT_SUB/07_开发环境/检查.sh（worktree 里自动只并行 2 个测试）"
  print "  注：generated/oracle 来自主工作区（合并 main 后再跑一次 --补齐 即刷新较旧的）；本车道改了参照探针时，刷新后在本 worktree 跑 同步正式西游.py（自动不登记）"
}

(( $# >= 1 )) || usage
if [[ $1 == --补齐 ]]; then
  (( $# == 2 )) || usage
  prepare "$2"
  exit 0
fi
name=$1 who=${2:-claude}
[[ $who == claude || $who == codex ]] || usage
[[ $name != */* && $name != -* ]] || { print -u2 "✗ 任务名不能含 / 或以 - 开头"; exit 64; }
branch=$who/$name
dest=$MAIN/.claude/worktrees/$name
mkdir -p "${dest:h}"
[[ ! -e $dest ]] || { print -u2 "✗ $dest 已存在"; exit 1; }
if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$branch"; then
  print -u2 "✗ 分支 $branch 已存在（要接手已有分支：git worktree add <路径> $branch，再用 --补齐）"; exit 1
fi
git -C "$MAIN" worktree add -q -b "$branch" "$dest" main
print "== 已建 $dest（分支 $branch，自 main $(git -C "$MAIN" rev-parse --short main)）"
prepare "$dest"
