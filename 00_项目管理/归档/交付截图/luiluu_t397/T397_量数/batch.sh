#!/bin/zsh
# T397：D242 封顶关（--xcap=-1,-1,-1）／开（表默认，艰险 35／55／35）配对；两条存档链×4 队×种子 1,2,3，40 回合，带敌群事件
# 守层者 10～33 层（同 T390）；小怪战 10／20／25 层遇敌敌群；骑士战 36 层四线本体（读 33／32 层存档）
cd "${0:A:h}/../../../../../03_再刷重制_Godot"
R=04_验证/本地结果/t397
mkdir -p $R
F=10,15,20,25,28,30,31,32,33
M=10:17:63,20:116:476,25:147:501
J=$R/batch.jobs
: > $J
for chain in r6:$HOME/orca/vp-saves/t238/r6/saves:33 t298:$HOME/orca/vp-saves/t298/full/saves:32; do
  c=${chain%%:*}; rest=${chain#*:}; p=${rest%:*}; sf=${rest##*:}
  for cfg in off:--xcap=-1,-1,-1 on:--xcap-default; do
    k=${cfg%%:*}; x=${cfg#*:}; [[ $x == --xcap-default ]] && x=""
    echo "g_${k}_$c --floors=$F --snapshots=$p $x" >> $J
    echo "m_${k}_$c --floors=10,20,25 --minion=$M --snapshots=$p $x" >> $J
    for l in war death famine plague; do
      echo "k_${k}_${c}_$l --floors=36 --snap-floor=$sf --line=$l --snapshots=$p $x" >> $J
    done
  done
done
cat $J | xargs -P 3 -L 1 zsh -c 'name=$0; ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/brand_calib.tscn -- --lineups=4 --rng-seeds=1,2,3 --turns=40 --carve=all "$@" --out=$PWD/'$R'/$name.json > '$R'/$name.log 2>&1; echo "$name exit=$?"'
echo BATCH_DONE
