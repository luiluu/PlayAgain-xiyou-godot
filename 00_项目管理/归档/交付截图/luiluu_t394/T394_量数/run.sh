#!/bin/zsh
# T394 量数：run.sh <标签> <额外参数…>；两条链（r7 4 弱、r6 普通）× 两段层（10～21、22～33），4 个进程并行
# 每队种子 1,2,3，4 队，40 回合，带敌群事件，真打（同 T244 / T363 d3 口径）
cd "${0:A:h}/../../../../../03_再刷重制_Godot"
tag=$1; shift
R=04_验证/本地结果/t394
mkdir -p $R
run() {  # 名 存档 层 额外…
  local name=$1 snap=$2 fl=$3; shift 3
  ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- \
    --snapshots=$snap --duel --events --turns=40 --lineups=4 --rng-seeds=1,2,3 --floors=$fl "$@" --out=$PWD/$R/$name.json > $R/$name.log 2>&1
  echo "$name exit=$? errors=$(grep -c 'SCRIPT ERROR' $R/$name.log)"
}
FA=${FLOORS_A:-10,11,12,13,14,15,16,17,18,19,20,21}
FB=${FLOORS_B:-22,23,24,25,26,27,28,29,30,31,32,33}
W=$HOME/orca/vp-saves/t238/r7/saves
N=$HOME/orca/vp-saves/t238/r6/saves
run ${tag}_weak_a $W $FA --all-weak "$@" &
run ${tag}_weak_b $W $FB --all-weak "$@" &
run ${tag}_norm_a $N $FA "$@" &
run ${tag}_norm_b $N $FB "$@" &
wait
echo "RUN_DONE $tag"
