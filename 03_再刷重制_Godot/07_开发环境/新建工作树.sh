#!/bin/zsh
# 多会话并行：给一条车道新建 worktree，并补齐不入 Git 的运行文件（规则见 AGENTS.md「多会话并行」）。
# 用法：
#   新建工作树.sh <任务名> [cc|codex]   从 main 最新提交切出分支 <执行者>/<任务名>，建在主工作区的 .claude/worktrees/<任务名>（已信任的项目文件夹内，开车道会话不用再确认信任；该目录已被 .gitignore 忽略）
#   新建工作树.sh --补齐 <worktree 路径>      只补齐已有 worktree（如桌面 app 自己建的）
#   新建工作树.sh --补齐 <worktree 路径> --branch <新分支名> [--from <提交或分支>]
#                                           车道开工用这条：app 给的工作树在 cc/<随机名> 上，先在该工作树里从 --from（默认 main）
#                                           切出派单的分支（如 cc/nezha-tools22）再补齐；工作树须无已跟踪改动，新分支不能已存在。
#                                           交付后总装照派单的任务名合并；分支名与任务名对不上时 合并车道.py --branch <分支> 指定。
# 补齐内容：Godot 引擎链接、西游资料库链接、冻结正式源链接、mv_oracle/node_modules、转换产物 generated/、导入缓存 .godot/。
# node_modules、generated、.godot 用 APFS 克隆（cp -c）复制主工作区的，不另占空间；随后按本分支重跑转换器与 godot --import。
# 已有 generated 时，generated/oracle 里主工作区较新的文件会覆盖进来（本分支自己生成、主工作区没有或比主工作区新的保留）。
# 复制了主工作区的参照就记批次（generated/oracle_batch.json，参照批次.py）；转换器跑完、以及 检查.sh 都比对本分支切片，不同批时提示。
if [ -z "${ZSH_VERSION:-}" ]; then
  echo "✗ 本脚本是 zsh 脚本：请直接运行 $0，或用 zsh $0 …（不要用 bash/sh 调用）" >&2
  exit 64
fi
set -euo pipefail
ENV_DIR=${0:A:h}
SELF_ROOT=${ENV_DIR:h:h}
MAIN=${$(git -C "$SELF_ROOT" rev-parse --path-format=absolute --git-common-dir):h}
GODOT_SUB=03_再刷重制_Godot

usage() { print -u2 "用法：${0:t} <任务名> [cc|codex]   或   ${0:t} --补齐 <worktree 路径> [--branch <新分支名> [--from <提交或分支>]]"; exit 64; }

# 参照副本按内容刷新（tools64：原来只比 mtime，车道文件时间比主工作区新就永远不刷新）：见 参照批次.py refresh。
ORACLE_COPIED=0
refresh_oracle() {
  local rc=0
  python3 "$ENV_DIR/参照批次.py" refresh "$1" "$2" "${2:h}" || rc=$?
  (( rc == 10 )) && ORACLE_COPIED=1
  (( rc == 0 || rc == 10 )) || { print -u2 "✗ 参照刷新失败（参照批次.py refresh 退出 $rc）"; exit 1; }
  return 0
}

prepare() {
  local wt=${1:A}
  # 主工作区 main 提交守卫（车道误在主工作区提交的防线，幂等；别人写的同名 hook 不覆盖，只提示）。
  # 用主工作区那份装：车道分支里改了守卫时，合进 main 前不会先装上（新守卫可能要 main 上的合并工具配套，tools22）
  zsh "$MAIN/$GODOT_SUB/07_开发环境/装提交守卫.sh" || print -u2 "⚠ 提交守卫没装好（见上），不影响补齐"
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
  # 起始种子与缓存必须配套携带；已有车道现场不覆盖。缓存仍逐文件核对 oracle 的 SHA。
  python3 "$tools/incremental_sync.py" --carry-cache "$mtools/mv_oracle/.sandbox" "$tools/mv_oracle/.sandbox"
  local flux_rc=0
  python3 "$ENV_DIR/参照批次.py" flux "$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)" || flux_rc=$?
  if [[ -e $gen ]]; then
    # 总装正在合并（主工作区 generated/ 带着未定稿的参照）：不刷新，免得拷走新 oracle 挡住车道同步（tools59）
    if (( flux_rc == 4 )); then
      python3 "$ENV_DIR/参照批次.py" pending "$gen" set   # 留标记：之后 compare／云端选测会照旧比对参照，不把本树的同步戳当「自己同步过」
    else
      refresh_oracle "$mgen/oracle" "$gen/oracle"; python3 "$ENV_DIR/参照批次.py" pending "$gen" clear
    fi
  else
    cp -cR "$mgen" "$gen"; ORACLE_COPIED=1
    (( flux_rc != 4 )) || python3 "$ENV_DIR/参照批次.py" pending "$gen" set
  fi
  (( ORACLE_COPIED == 0 )) || python3 "$ENV_DIR/参照批次.py" record "$gen" "$mgen"
  [[ -e $proj/.godot ]] || cp -cR "$mproj/.godot" "$proj/.godot"
  # 分支落后 main 且 main 改了切片／转换器／探针：此时按本分支转换会把 main 新增的角色等当成「删除」，同步白跑一轮（悟空 tools33 提）
  if ! git -C "$wt" merge-base --is-ancestor main HEAD 2>/dev/null; then
    local behind
    behind=$(git -C "$wt" diff --name-only "$(git -C "$wt" merge-base HEAD main)" main -- "$GODOT_SUB/03_转换工具" 2>/dev/null | wc -l | tr -d ' ')
    if (( behind > 0 )); then
      print -u2 "⚠ 本分支落后 main，且 main 改了 $behind 个切片／转换器／探针文件：先在工作树里 git merge main，再重跑一次 --补齐（否则同步会把 main 新增的内容报成「删除」）"
    fi
  fi
  print "== 按本分支重跑转换器"
  python3 "$tools/xiyou_export.py" --out "$gen" | tail -1 | cut -c1-160
  python3 "$ENV_DIR/参照批次.py" check "$gen" || true
  print "== godot --import"
  local out rc=0
  out=$(python3 "$ENV_DIR/占槽.py" --label "godot --import" --notice-fd 3 -- perl -e 'alarm 300; exec @ARGV' "$env/godot" --headless --path "$proj" --import 3>&2 2>&1) || rc=$?
  if (( rc != 0 )) || grep -qE 'SCRIPT ERROR|^ERROR:' <<< "$out"; then
    print -r -- "$out" | grep -E 'ERROR|FAIL' | head -8
    print -u2 "✗ 导入失败 (rc=$rc)"; exit 1
  fi
  print "✓ 已补齐 $wt"
  print "  分支 $(git -C "$wt" rev-parse --abbrev-ref HEAD)；检查：$GODOT_SUB/07_开发环境/检查.sh（worktree 里自动只并行 2 个测试）"
  print "  注：generated/oracle 来自主工作区（合并 main 后再跑一次 --补齐 即刷新较旧的）；本车道改了参照探针时，刷新后在本 worktree 跑 同步正式西游.py（自动不登记）"
}

(( $# >= 1 )) || usage
# 在已有工作树里切出新分支：只在没有已跟踪改动时切（未跟踪文件随工作树留着），原分支不删
switch_branch() {
  local wt=${1:A} branch=$2 from=$3 old
  [[ -e $wt/.git ]] || { print -u2 "✗ $wt 不是 git 工作区"; exit 1; }
  [[ $wt != $MAIN ]] || { print -u2 "✗ 这是主工作区，不在这里切车道分支"; exit 1; }
  git check-ref-format --branch "$branch" >/dev/null 2>&1 && [[ $branch != -* ]] || { print -u2 "✗ 分支名不合法：$branch"; exit 64; }
  git -C "$wt" rev-parse -q --verify "$from^{commit}" >/dev/null || { print -u2 "✗ --from 找不到：$from"; exit 1; }
  if git -C "$wt" show-ref --verify --quiet "refs/heads/$branch"; then
    print -u2 "✗ 分支 $branch 已存在（接手已有分支：在工作树里 git switch $branch，再只用 --补齐）"; exit 1
  fi
  [[ -z $(git -C "$wt" status --porcelain --untracked-files=no) ]] || {
    print -u2 "✗ $wt 有未提交的已跟踪改动，先提交（可 WIP:）或处理掉再切分支"; git -C "$wt" status --short --untracked-files=no | head -8 >&2; exit 1; }
  old=$(git -C "$wt" symbolic-ref --short -q HEAD || git -C "$wt" rev-parse --short HEAD)
  git -C "$wt" switch -q -c "$branch" "$from"
  print "== 已在 $wt 从 $from（$(git -C "$wt" rev-parse --short HEAD)）切出 $branch（原来在 $old，没删）"
  # app 每开一个会话起一个 cc/<随机名>：原分支没有自己的提交（都已在 main 里）时提示可删，免得越攒越多（只提示不删，tools23）
  if [[ $old != main ]] && git -C "$wt" show-ref --verify --quiet "refs/heads/$old" \
      && git -C "$wt" merge-base --is-ancestor "refs/heads/$old" main 2>/dev/null; then
    print "  提示：原分支 $old 没有自己的提交（都已在 main 里），用不着可删：git branch -d $old（只提示，没删）"
  fi
}

if [[ $1 == --补齐 ]]; then
  (( $# >= 2 )) || usage
  wt=$2 branch='' from=''
  shift 2
  while (( $# )); do
    case $1 in
      --branch) (( $# >= 2 )) || usage; branch=$2; shift 2 ;;
      --from) (( $# >= 2 )) || usage; from=$2; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ -n $branch || -z $from ]] || { print -u2 "✗ --from 要和 --branch 一起给（切出的新分支名）"; exit 64; }
  [[ -z $branch ]] || switch_branch "$wt" "$branch" "${from:-main}"
  prepare "$wt"
  exit 0
fi
name=$1 who=${2:-cc}   # Kyo 10-31 起前缀叫 cc；claude 是旧写法，仍可显式给
[[ $who == cc || $who == claude || $who == codex ]] || usage
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
