extends Node
## 【cc·T328】复活名单（不进检查.sh）：从技能、道具数据里找复活效果（目标倒下的队友＋解除战斗不能／生命回复，同 vp_battle_logic.revives），
## 列出各档全角色 81 级会的复活技能、全部复活道具；给了 --snap 再列这份存档出战的人会不会、背包里有几个复活道具。
## godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/revive_scan.tscn -- \
##   [--difficulty=jianxian] [--snap=<floor_10_2.json>,…]
const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")
const TB := preload("res://tests/virtual_player/team_builder.gd")

var difficulty := "jianxian"
var snaps: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--snap="):
			snaps = Array(a.substr(7).split(","))
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	XConfig.path_override = "user://test_revive_scan/options.json"
	XConfig._loaded_path = ""
	XConfig.ensure_loaded()
	print("SCAN 复活道具：")
	for id in VPLogic.revive_items_all():
		var it := XDB.rec("Items", id)
		print("SCAN   道具 %d %s 范围 %d 价格 %d" % [id, str(it.get("name", "")), int(it.get("scope", 0)), int(it.get("price", 0))])
	print("SCAN 本档（%s）候选里 81 级会复活技能的：" % difficulty)
	var cand := TB.candidates(difficulty)
	for role in TB.ROLE_ORDER:
		for id in cand[role]:
			var names := TB.revive_skill_names(int(id))
			print("SCAN   %s %d %s %s %s" % [role, int(id), XTianqiSkills.tier_of(int(id), true), _name(int(id)), ("复活：" + ",".join(names)) if not names.is_empty() else "－"])
	for path in snaps:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
		if not parsed is Dictionary:
			print("SCAN 读不到 %s" % path)
			continue
		var st := XState.from_dict(parsed)
		XState._become_current(st)
		print("SCAN 存档 %s 层 %d" % [str(path).get_file(), int(st.variable(20))])
		for a in st.battle_members():
			var rs := VPLogic.revive_skills(a).map(func(s): return "%d %s" % [int(s.id), str(s.get("name", ""))])
			print("SCAN   出战 %d %s %s 等级 %d %s" % [a.actor_id, a.display_name(), TB.role_of(a.actor_id), a.level, ("复活：" + ",".join(rs)) if not rs.is_empty() else "－"])
		var bag := []
		for id in VPLogic.revive_items_all():
			if int(st.items.get(id, 0)) > 0:
				bag.append("%d×%d" % [id, int(st.items[id])])
		print("SCAN   背包复活道具 %s" % (",".join(bag) if not bag.is_empty() else "无"))
	get_tree().quit.call_deferred(0)


func _name(id: int) -> String:
	return str(XDB.rec("Actors", id).get("name", ""))
