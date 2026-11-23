#!/bin/zsh
# T406 量数复现：在 03_再刷重制_Godot 下跑。第 1 轮三档（--hp-pct=off／33:70／33:50）× 两链（r7 纯 4 弱、r6 普通）× 种子 1～3；
# 归因组（T406 改动前代码）：原样、--seg-alien=off、--focus=off，各只量纯 4 弱、每种子一个进程。
cd "${0:A:h}/../../../../../03_再刷重制_Godot"
R=04_验证/本地结果/t406; mkdir -p $R
W=$HOME/orca/vp-saves/t238/r7/saves; N=$HOME/orca/vp-saves/t238/r6/saves
run(){ local name=$1; shift; ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- --duel --events --turns=40 --lineups=4 --rng-seeds=1,2,3 --floors=33 --keep-trace "$@" --out=$PWD/$R/$name.json > $R/$name.log 2>&1; echo "$name exit=$? err=$(grep -c 'SCRIPT ERROR' $R/$name.log)"; }
for arm in off 70 50; do a="33:$arm"; [ $arm = off ] && a=off
  run r1_${arm}_weak --snapshots=$W --all-weak --hp-pct=$a &
  run r1_${arm}_norm --snapshots=$N --hp-pct=$a &
done; wait; echo RUN_DONE
