#!/bin/zsh
# T527：等基础探针三种子跑完，再跑「换伤支全选」三种子（t527_trade_probe --trade=all，其余同 T501 探针命令）
O="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$O/../../../../.." && pwd)/03_再刷重制_Godot"
cd "$ROOT"
until [ $(cat "$O"/探针/s*.log 2>/dev/null | grep -c '^exit ') -ge 3 ]; do sleep 10; done
mkdir -p "$O/探针_换伤全选"
for s in 1 2 3; do
  ( env HOME="$(mktemp -d)" ./07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/t527_trade_probe.tscn -- --tier=all --actors=167,168,163,173,172,180,152,175,108,95,171,176,177,122,169,107,179,1,22,2,18,3,12 --book-build=lianyu --noisy --seed=$s --trade=all --out="$O/探针_换伤全选/s$s.json" > "$O/探针_换伤全选/s$s.log" 2>&1; echo "exit $?" >> "$O/探针_换伤全选/s$s.log" ) &
done
wait
echo TRADE_DONE
