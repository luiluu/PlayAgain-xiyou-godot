#!/bin/zsh
# T432 复现脚本：新跑 3 条艰险虚拟玩家存档链（种子 3/4/5，D265 合并前基线）并按 T406 同口径量 10～30 层与 33 层普通阵容胜率。
# 用法：在仓库根目录或本脚本目录执行；所有 Godot 调用均带 --audio-driver Dummy。
set -euo pipefail
cd "${0:A:h}/../../../../../03_再刷重制_Godot"
OUT_BASE="$HOME/orca/vp-saves/t432"
mkdir -p "$OUT_BASE/dps"

# 1) 跑 3 条艰险虚拟玩家链至 34 层（种子 3、4、5，并行 3 进程）
for S in 3 4 5; do
  mkdir -p "$OUT_BASE/s$S"
  ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 \
    -s res://tests/test_main_loop.gd res://tests/xiyou_virtual_player.tscn -- \
    --vp-mode=climb --vp-ff --vp-pass-after=5 --vp-difficulty=jianxian \
    --vp-floors=34 --vp-seed=$S --vp-tag=t432_s$S --vp-minutes=240 \
    --vp-snapshot-dir="$OUT_BASE/s$S/saves" \
    --vp-out="$OUT_BASE/s$S/out" \
    > "$OUT_BASE/s$S/run.log" 2>&1 &
done
wait

# 2) 按 T406 同口径量 33 层（含 trace）与 10～30 层普通阵容胜率
for S in 3 4 5; do
  ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 \
    -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- \
    --duel --events --turns=40 --lineups=4 --rng-seeds=1,2,3 --floors=33 --keep-trace \
    --snapshots="$OUT_BASE/s$S/saves" \
    --out="$OUT_BASE/dps/s${S}_f33.json" \
    > "$OUT_BASE/dps/s${S}_f33.log" 2>&1 &
  ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 \
    -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- \
    --duel --events --turns=40 --lineups=4 --rng-seeds=1,2,3 --floors=10-30 \
    --snapshots="$OUT_BASE/s$S/saves" \
    --out="$OUT_BASE/dps/s${S}_f10_30.json" \
    > "$OUT_BASE/dps/s${S}_f10_30.log" 2>&1 &
done
wait

# 3) 汇总装备品质分布与胜率对比
python3 01_Godot工程/tests/virtual_player/t432_gear_stats.py \
  --floors 10,20,30,33 \
  r6="$HOME/orca/vp-saves/t238/r6/saves" \
  t298="$HOME/orca/vp-saves/t298/full/saves" \
  s3="$OUT_BASE/s3/saves" \
  s4="$OUT_BASE/s4/saves" \
  s5="$OUT_BASE/s5/saves"

python3 01_Godot工程/tests/virtual_player/t432_winrate_stats.py \
  --f33 r6="$OUT_BASE/dps/r6_f33.json" \
  --f33 s3="$OUT_BASE/dps/s3_f33.json" \
  --f33 s4="$OUT_BASE/dps/s4_f33.json" \
  --f33 s5="$OUT_BASE/dps/s5_f33.json" \
  --f1030 s3="$OUT_BASE/dps/s3_f10_30.json" \
  --f1030 s4="$OUT_BASE/dps/s4_f10_30.json" \
  --f1030 s5="$OUT_BASE/dps/s5_f10_30.json"
