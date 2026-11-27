extends "res://tests/virtual_player/t438_d271_benchmark.gd"
## 【cc·T530】总账改造核心 开／关 对照量数：在 T438 D271 脚手架上跑，多一个参数 --t530=on|off。
## off＝T530 新加的六个回退开关全关（XTianqiLedger.SPLIT_CAPS／REBUILD_SOURCES／ELEM_RESIST_CAP／NO_ENEMY_FLAT_MIT，
## XTianqiAffixBattle.CAPS_V16／RESIST_PER_ELEMENT），on＝全开（默认）。其余参数同 t438_d271_benchmark.gd。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑务必带 --audio-driver Dummy、临时 HOME。


func _ready() -> void:
	var on := true
	for a in OS.get_cmdline_user_args():
		if a == "--t530=off":
			on = false
	XTianqiLedger.SPLIT_CAPS = on
	XTianqiLedger.REBUILD_SOURCES = on
	XTianqiLedger.ELEM_RESIST_CAP = on
	XTianqiLedger.NO_ENEMY_FLAT_MIT = on
	XTianqiAffixBattle.CAPS_V16 = on
	XTianqiAffixBattle.RESIST_PER_ELEMENT = on
	print("T530_BENCH|switches=%s" % ("on" if on else "off"))
	super._ready()
