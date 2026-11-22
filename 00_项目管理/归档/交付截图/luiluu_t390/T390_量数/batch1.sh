#!/bin/zsh
# T390 第一批：存档链（r6、t298）×4 队×种子 1,2，40 回合，带敌群事件
cd "${0:A:h}/../../.."
R=04_验证/本地结果/t390
F=10,15,20,25,28,30,31,32,33
jobs_file=$R/batch1.jobs
: > $jobs_file
for chain in r6:$HOME/orca/vp-saves/t238/r6/saves t298:$HOME/orca/vp-saves/t298/full/saves; do
  c=${chain%%:*}; p=${chain#*:}
  echo "s4raw_all_$c --carve=all --snapshots=$p" >> $jobs_file
  echo "s5raw_none_$c --carve=none --snapshots=$p" >> $jobs_file
  echo "s4ripe_all_$c --carve=all --ripe --snapshots=$p" >> $jobs_file
  echo "d242_all_$c --carve=all --xcap=30,50,30 --snapshots=$p" >> $jobs_file
  echo "s5zd_all_$c --carve=all --difficulty=zhengdao --snapshots=$p" >> $jobs_file
  echo "s5zd_none_$c --carve=none --difficulty=zhengdao --snapshots=$p" >> $jobs_file
done
cat $jobs_file | xargs -P 4 -L 1 zsh -c 'name=$0; ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/brand_calib.tscn -- --floors='$F' --lineups=4 --rng-seeds=1,2 --turns=40 "$@" --out=$PWD/'$R'/$name.json > '$R'/$name.log 2>&1; echo "$name exit=$?"'
echo BATCH1_DONE
