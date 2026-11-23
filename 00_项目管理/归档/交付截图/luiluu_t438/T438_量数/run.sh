#!/usr/bin/env bash
# T438 按 D271 标尺实测 31～36 层五档毕业胜率与成长神器对照 一键复现脚本
# 所有 Godot 调用均带 --audio-driver Dummy
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
GODOT="$ROOT/03_再刷重制_Godot/07_开发环境/godot"
PROJ="$ROOT/03_再刷重制_Godot/01_Godot工程"
OUT="$ROOT/00_项目管理/归档/交付截图/luiluu_t438/T438_量数"
SCENE="res://tests/virtual_player/t438_d271_benchmark.tscn"

# 1. 主矩阵（A/B/C/D 无成长神器基线，3 阵容 × 2 种子 × 31～36 层 × 4 线）
for tpl in A B C D; do
  mt=25
  [ "$tpl" = "A" ] && mt=35
  "$GODOT" --headless --audio-driver Dummy --path "$PROJ" -s res://tests/test_main_loop.gd "$SCENE" -- \
    --templates="$tpl" --floors=31-36 --lines=war,famine,death,plague --teams=3 --seeds=1,2 \
    --artifact=none --max-turns="$mt" --out="$OUT/main_${tpl}.json"
done

# 2. 成长神器中度刷高与满上限对照（B/C/D 同阵容配对）
for mode in mid cap; do
  "$GODOT" --headless --audio-driver Dummy --path "$PROJ" -s res://tests/test_main_loop.gd "$SCENE" -- \
    --templates=B,C,D --floors=31-36 --lines=war,famine,death,plague --teams=2 --seeds=1 \
    --artifact="$mode" --max-turns=25 --out="$OUT/art_${mode}_BCD.json"
done

# 3. 三神器拆解对照（仅无我/利维坦 10 阶 vs 全员头顶 +300%）
for mode in hh_cap crown_cap; do
  "$GODOT" --headless --audio-driver Dummy --path "$PROJ" -s res://tests/test_main_loop.gd "$SCENE" -- \
    --templates=C,D --floors=33,35,36 --lines=war,famine,death,plague --teams=2 --seeds=1 \
    --artifact="$mode" --max-turns=25 --out="$OUT/split_${mode}_CD.json"
done

# 4. 跨档边界对照
for mode in none mid cap; do
  "$GODOT" --headless --audio-driver Dummy --path "$PROJ" -s res://tests/test_main_loop.gd "$SCENE" -- \
    --templates=C --force-diff=zhengdao --floors=35,36 --lines=war,famine,death,plague --teams=2 --seeds=1 \
    --artifact="$mode" --max-turns=25 --out="$OUT/cross_C_zd_${mode}.json"
done
"$GODOT" --headless --audio-driver Dummy --path "$PROJ" -s res://tests/test_main_loop.gd "$SCENE" -- \
  --templates=A --force-diff=xunchang --floors=33,35,36 --lines=war,famine,death,plague --teams=2 --seeds=1 \
  --artifact=none --max-turns=25 --out="$OUT/cross_A_xc.json"
"$GODOT" --headless --audio-driver Dummy --path "$PROJ" -s res://tests/test_main_loop.gd "$SCENE" -- \
  --templates=B --force-diff=lianyu --floors=33,35,36 --lines=war,famine,death,plague --teams=2 --seeds=1 \
  --artifact=none --max-turns=25 --out="$OUT/cross_B_ly.json"

python3 "$OUT/build_report.py"
