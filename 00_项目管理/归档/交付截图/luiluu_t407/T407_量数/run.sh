#!/bin/zsh
# T407 量数：run.sh <标签> <额外参数…>；两条链（r7 4 弱、r6 普通）× 31～34 层，2 个进程并行
# 口径同 T394（D259／D260）：每队种子 1,2,3，4 队，40 回合，带敌群事件，真打；34 层借 33 层存档（baseline_dps 自带）
cd "${0:A:h}/../../../../../03_再刷重制_Godot"
tag=$1; shift
R=04_验证/本地结果/t407
mkdir -p $R
run() {  # 名 存档 层 额外…
  local name=$1 snap=$2 fl=$3; shift 3
  ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- \
    --snapshots=$snap --duel --events --turns=40 --lineups=4 --rng-seeds=1,2,3 --floors=$fl "$@" --out=$PWD/$R/$name.json > $R/$name.log 2>&1
  echo "$name exit=$? errors=$(grep -c 'SCRIPT ERROR' $R/$name.log)"
}
F=${FLOORS:-31,32,33,34}
W=$HOME/orca/vp-saves/t238/r7/saves
N=$HOME/orca/vp-saves/t238/r6/saves
run ${tag}_weak_a $W $F --all-weak "$@" &
run ${tag}_norm_a $N $F "$@" &
wait
echo "RUN_DONE $tag"
