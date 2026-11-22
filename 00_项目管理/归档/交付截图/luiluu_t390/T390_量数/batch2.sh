#!/bin/zsh
# T390 第二批（缩减）：t298 链 20/25/30/32 层四组；证道 r6 链 10/20/25/30 层全刻／全不刻
cd "${0:A:h}/../../.."
R=04_验证/本地结果/t390
T=$HOME/orca/vp-saves/t298/full/saves; S=$HOME/orca/vp-saves/t238/r6/saves
{
echo "b2_s4raw_all_t298 --floors=20,25,30,32 --carve=all --snapshots=$T"
echo "b2_s5raw_none_t298 --floors=20,25,30,32 --carve=none --snapshots=$T"
echo "b2_s4ripe_all_t298 --floors=20,25,30,32 --carve=all --ripe --snapshots=$T"
echo "b2_d242_all_t298 --floors=20,25,30,32 --carve=all --xcap=30,50,30 --snapshots=$T"
echo "b2_s5zd_all_r6 --floors=10,20,25,30 --carve=all --difficulty=zhengdao --snapshots=$S"
echo "b2_s5zd_none_r6 --floors=10,20,25,30 --carve=none --difficulty=zhengdao --snapshots=$S"
} > $R/batch2.jobs
cat $R/batch2.jobs | xargs -P 3 -L 1 zsh -c 'name=$0; ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/brand_calib.tscn -- --lineups=4 --rng-seeds=1,2 --turns=40 "$@" --out=$PWD/'$R'/$name.json > '$R'/$name.log 2>&1; echo "$name exit=$?"'
echo BATCH2_DONE
