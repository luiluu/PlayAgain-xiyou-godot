#!/bin/zsh
# T501：31～36 层胜率（T438 D271 标尺，C 三阵容、A/B/D 各一阵容，种子 1～3）；用法：run.sh <目录名>，K 取表里的值
set -u
TAG=$1
ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
OUT="$(cd "$(dirname "$0")" && pwd)/$TAG"
mkdir -p $OUT
jobs=()
for f in 31 32 33 34 35 36; do jobs+=("C 3 $f"); done
for t in A B D; do for f in 31 32 33 34 35 36; do jobs+=("$t 1 $f"); done; done
printf '%s\n' "${jobs[@]}" | xargs -P 3 -L 1 zsh -c '
t=$0; n=$1; f=$2; mt=25; [ "$t" = A ] && mt=35
H=$(mktemp -d)
env HOME=$H '$ROOT'/03_再刷重制_Godot/07_开发环境/godot --headless --audio-driver Dummy --path '$ROOT'/03_再刷重制_Godot/01_Godot工程 \
 -s res://tests/test_main_loop.gd res://tests/virtual_player/t438_d271_benchmark.tscn -- \
 --templates=$t --floors=$f --lines=war,famine,death,plague --teams=$n --seeds=1,2,3 --artifact=none --max-turns=$mt \
 --out='$OUT'/${t}_$f.json > '$OUT'/${t}_$f.log 2>&1
echo "DONE $t $f exit=$? $(grep -c SCRIPT\ ERROR '$OUT'/${t}_$f.log)"
'
echo ALL_DONE
