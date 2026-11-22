#!/bin/zsh
cd "/Users/kyo/orca/workspaces/再刷项目资料库/t390/03_再刷重制_Godot"
./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/brand_calib.tscn -- --floors=31,32,33 --snapshots=$HOME/orca/vp-saves/t238/r6/saves --lineups=4 --rng-seeds=1,2 --turns=40 --carve=all "--brand-set=sear.per_hit.终焉=13" --out=/Users/kyo/orca/workspaces/再刷项目资料库/t390/03_再刷重制_Godot/04_验证/本地结果/t390/c2_fin13_all_r6.json > /Users/kyo/orca/workspaces/再刷项目资料库/t390/03_再刷重制_Godot/04_验证/本地结果/t390/c2_fin13_all_r6.log 2>&1
echo "c2 exit=$?"
