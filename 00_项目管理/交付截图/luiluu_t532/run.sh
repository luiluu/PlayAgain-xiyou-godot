#!/bin/zsh
# T532（照搬 T533 run.sh 思路）：防具元素合计上限 开／关 对照；B/C/D × 31、33 层 × 种子 1～3 × 1 阵容，成长神器 none；用法：run.sh <目录名>
set -u
TAG=$1
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="$(cd "$(dirname "$0")" && pwd)/$TAG"
mkdir -p $OUT
jobs=()
for sw in on off; do for t in B C D; do for f in 31 33; do jobs+=("$t $f $sw"); done; done; done
printf '%s\n' "${jobs[@]}" | xargs -P 3 -L 1 zsh -c '
t=$0; f=$1; sw=$2
H=$(mktemp -d)
env HOME=$H '$ROOT'/03_再刷重制_Godot/07_开发环境/godot --headless --audio-driver Dummy --path '$ROOT'/03_再刷重制_Godot/01_Godot工程 \
 -s res://tests/test_main_loop.gd res://tests/virtual_player/t532_elem_bench.tscn -- --t532=$sw \
 --templates=$t --floors=$f --lines=war,famine,death,plague --teams=1 --seeds=1,2,3 --artifact=none --max-turns=50 \
 --out='$OUT'/${t}_${f}_$sw.json > '$OUT'/${t}_${f}_$sw.log 2>&1
echo "DONE $t $f $sw exit=$? err=$(grep -c SCRIPT\ ERROR '$OUT'/${t}_${f}_$sw.log)"
'
echo ALL_DONE
