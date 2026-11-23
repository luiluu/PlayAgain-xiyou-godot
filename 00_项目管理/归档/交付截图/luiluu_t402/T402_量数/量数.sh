#!/bin/zsh
# 用法：zsh 量数.sh [前缀，默认 on/off 两组] ——第 2 轮（22 层 hp_base 139 万）跑 zsh 量数.sh r2，只跑毒开、输出 r2_*
# T402：22 层真打（T392 band 量法）：存档链 r6、t298 × 寻常／艰险（--force-difficulty）× 4 队（原队＋3 随机）× 种子 1,2,3，＋奶妈队单列；
# 40 回合、带敌群事件；dot_pct 开（本单）／关（--dot-pct=off，回到 T080 的 65%／58%）各一遍做前后对照。仓库根下：zsh <本文件>
R=${0:A:h}
cd "$R/../../../../../03_再刷重制_Godot"
jobs_file=$R/jobs.txt
: > $jobs_file   # 跑完可删
for chain in r6:$HOME/orca/vp-saves/t238/r6/saves t298:$HOME/orca/vp-saves/t298/full/saves; do
  c=${chain%%:*}; p=${chain#*:}
  for d in xunchang jianxian; do
    if [[ -n "$1" ]]; then
      echo "$1_${d}_$c --force-difficulty=$d --snapshots=$p" >> $jobs_file
    else
      echo "on_${d}_$c --force-difficulty=$d --snapshots=$p" >> $jobs_file
      echo "off_${d}_$c --force-difficulty=$d --dot-pct=off --snapshots=$p" >> $jobs_file
    fi
  done
done
cat $jobs_file | xargs -P 4 -L 1 zsh -c 'name=$0; ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- --duel --events --floors=22 --lineups=4 --rng-seeds=1,2,3 --add-healer --turns=40 "$@" --out='$R'/$name.json > '$R'/$name.log 2>&1; echo "$name exit=$?"'
echo BATCH_DONE
