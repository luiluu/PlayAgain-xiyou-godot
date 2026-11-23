#!/bin/zsh
# T402：22 层真打（T392 band 量法）：存档链 r6、t298 × 寻常／艰险（--force-difficulty）× 4 队（原队＋3 随机）× 种子 1,2,3，＋奶妈队单列；
# 40 回合、带敌群事件；dot_pct 开（本单）／关（--dot-pct=off，回到 T080 的 65%／58%）各一遍做前后对照。仓库根下：zsh <本文件>
cd "${0:A:h}/../../../../../03_再刷重制_Godot"
R=${0:A:h}
jobs_file=$R/jobs.txt
: > $jobs_file
for chain in r6:$HOME/orca/vp-saves/t238/r6/saves t298:$HOME/orca/vp-saves/t298/full/saves; do
  c=${chain%%:*}; p=${chain#*:}
  for d in xunchang jianxian; do
    echo "on_${d}_$c --force-difficulty=$d --snapshots=$p" >> $jobs_file
    echo "off_${d}_$c --force-difficulty=$d --dot-pct=off --snapshots=$p" >> $jobs_file
  done
done
cat $jobs_file | xargs -P 4 -L 1 zsh -c 'name=$0; ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- --duel --events --floors=22 --lineups=4 --rng-seeds=1,2,3 --add-healer --turns=40 "$@" --out='$R'/$name.json > '$R'/$name.log 2>&1; echo "$name exit=$?"'
echo BATCH_DONE
