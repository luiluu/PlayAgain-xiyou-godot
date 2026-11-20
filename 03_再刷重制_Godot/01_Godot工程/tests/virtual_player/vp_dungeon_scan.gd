extends Node
## 【cc·T272】副本入口／首领扫描探针（不进检查.sh）：对每张楼层图跑快进的 find_entry／find_boss，打印找到什么、找不到卡在哪。
## godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/vp_dungeon_scan.tscn -- --maps=6:3,17:10,155:26

const FastForward := preload("res://tests/virtual_player/vp_fastforward.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			maps = Array(a.substr(7).split(","))
		elif a.begins_with("--snap="):   # 读一份存档当前局（页的开关条件按它判）
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(a.substr(7)))
			if parsed is Dictionary:
				XState._become_current(XState.from_dict(parsed))
				print("SCAN 副本变量 5=%d 6=%d 21=%d 450=%d VAR_SEALED=%d" % [int(XState.current.variable(5)), int(XState.current.variable(6)), int(XState.current.variable(21)), int(XState.current.variable(450)), int(XState.current.variable(XDungeon.VAR_SEALED))])
				print("SCAN 烙印开着 %s；真气 %s" % [str(XTianqiBrand.on(XState.current)), str(XState.current.members().map(func(a): return int(XZhenqi.data(a).qi)))])
	for item in maps:
		var m := int(str(item).get_slice(":", 0))
		var fl := int(str(item).get_slice(":", 1))
		var ent := FastForward.find_entry(m)
		if ent.is_empty():
			print("SCAN 层%d 图%d：没有副本入口" % [fl, m])
			continue
		var boss := FastForward.find_boss(int(ent[0]), ent[1])
		var pg := FastForward.page_of(int(ent[0]), ent[1])
		var spec := XDungeon.entry_spec(pg.get("list", []))
		print("SCAN 层%d 图%d：入口 图%d 事件%d；首领 %s；当前页是入口 %s 页%d" % [fl, m, int(ent[0]), int(ent[1].id), str(boss.slice(0, 1) + boss.slice(2) if not boss.is_empty() else "找不到"), str(not spec.is_empty()), FastForward.page_index_of(int(ent[0]), ent[1])])
	get_tree().quit.call_deferred(0)
