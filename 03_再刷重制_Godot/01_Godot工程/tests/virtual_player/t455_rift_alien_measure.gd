extends Node
## 【cc·T455】漩涡三阶封顶蚀骨量数：西游档 21～30 层守层者，三组对照——off（异化关）、huaxing（封顶前：21～30 层化形）、shigu（封顶后：蚀骨）。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑（务必带 --audio-driver Dummy）：
##   03_再刷重制_Godot/07_开发环境/godot --headless --audio-driver Dummy --path 03_再刷重制_Godot/01_Godot工程 \
##     -s res://tests/test_main_loop.gd res://tests/virtual_player/t455_rift_alien_measure.tscn -- [--seeds=1,2,3] [--floors=21-30] [--max-turns=30] [--out=<json>]
## 基准队：西游档（不是天启篇），配队器最强队 TB.strongest("A", "jianxian")（D271 标尺是天启篇 31～36 层的，西游 21～30 层没有现成五档标尺队，这里是权宜口径，交付单写明）；
##   等级＝这一层的等级上限（baseline_dps.level_cap），装备＝每栏挑能穿的、非专属、主属性最高的一件（不限品质），法宝＝本层上限（专属优先，没有用破攻／尊魔）。
## 敌人：这一层守层者那场敌群（baseline_dps.GUARDIAN），真打到分胜负或 max_turns；守层者三阶几率 100%，异化种类由本场种子定（三组同种子同种类）。
## 组别：off＝XRiftAlien.ENABLED 关；huaxing＝STAGE_OVERRIDE 4（四阶表：守层者 21～30 层化形，几率同三阶 100%）；shigu＝STAGE_OVERRIDE 3（T455 新三阶表）。

const BD := preload("res://tests/virtual_player/baseline_dps.gd")
const TB := preload("res://tests/virtual_player/team_builder.gd")
const VPLogic := preload("res://tests/virtual_player/vp_battle_logic.gd")

var seeds: Array = [1, 2, 3]
var floors: Array = range(21, 31)
var max_turns := 30
var out_path := ""
static var _pool := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(x): return int(x))
		elif a.begins_with("--floors="):
			var v := a.substr(9).split("-")
			floors = range(int(v[0]), int(v[-1]) + 1)
		elif a.begins_with("--max-turns="):
			max_turns = int(a.substr(12))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	_run.call_deferred()


func _state(team: Array, f: int, sd: int) -> XState:
	var s := XState.new()
	for id in team:
		s.add_actor(int(id))
	for i in 5:
		s.set_battle_slot(i, int(team[i]) if i < team.size() else 0)
	s.map_id = 0
	s.set_variable(20, f + 1)
	s.random_master = XRandomStream.hex64(20261124 + sd * 100 + f)
	s.actor_max_level = BD.level_cap(f)
	XState.current = s
	for id in team:
		var a := s.actor(int(id))
		a.change_level_mv(BD.level_cap(f))
		_dress(a)
		var fid := BD.own_fabao(int(id))
		if fid == 0:
			fid = BD.GENERAL_ATK if a.param(2) >= a.param(4) else BD.GENERAL_MAT
		var item := XGear.template("armor", fid)
		item.level = float(mini(BD.fabao_cap(f), int(XMagicWeapon.max_level(item))))
		item.exp = 0.0
		var slot := a.equip_slots().find(int(item.etypeId))
		if slot >= 0:
			a.equips[slot] = item
		a.refresh_passive()
		a.recover_all()
	return s


func _dress(a: XActor) -> void:
	var slots := a.equip_slots()
	var physical := a.param(2) >= a.param(4)
	for i in slots.size():
		var et := int(slots[i])
		if et == 13:
			continue
		if not _pool.has(et):
			var out := []
			for rec in XDB.table("Weapons" if et == 1 else "Armors"):
				if not rec is Dictionary or str(rec.get("name", "")) == "" or (et != 1 and int(rec.get("etypeId", 0)) != et):
					continue
				var m: Dictionary = rec.get("meta", {})
				if m.has("Magic Weapon") or m.has("req_actors"):
					continue
				out.append(rec)
			_pool[et] = out
		var best := {}
		var best_score := -1.0
		for rec in _pool[et]:
			var item := XGear.template("weapon" if et == 1 else "armor", int(rec.id))
			if not a.can_equip(item):
				continue
			var p: Array = rec.params
			var score := float(p[2] if physical else p[4]) if et == 1 else float(p[2]) + float(p[3]) + float(p[4]) + float(p[5]) + float(p[0]) / 10.0
			if score > best_score:
				best_score = score
				best = item
		if not best.is_empty():
			a.equips[i] = best


func _fight(team: Array, f: int, sd: int, arm: String) -> Dictionary:
	XRiftAlien.ENABLED = arm != "off"
	XRiftAlien.STAGE_OVERRIDE = 4 if arm == "huaxing" else 3
	var s := _state(team, f, sd)
	seed(20261124 + sd * 100 + f)
	var logic: XBattleLogic = VPLogic.new()
	logic.setup(int(BD.GUARDIAN[f]), s, XBattleRandom.create(XRandomStream.hex64(7000 + sd * 100 + f), 1))
	logic.auto = true
	var alien := []
	for e in XRiftAlien.fight(logic).get("units", {}):
		var u: Dictionary = XRiftAlien.fight(logic).units[e]
		alien.append("%s·%s" % [str(u.tier), str(u.kind)])
	var turns := 0
	while not logic.is_over() and turns < max_turns:
		logic.run_turn({})
		turns += 1
	var r := {"floor": f, "seed": sd, "arm": arm, "turns": turns, "won": logic.is_won(), "lost": logic.is_lost(), "alien": alien,
		"alive": logic.actors.filter(func(x): return x.hp > 0).size()}
	logic.end_battle(0)
	return r


func _run() -> void:
	XMessageBox.auto = true
	XConfig.path_override = "user://t455_measure/options.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://t455_measure"))
	XConfig.whisper_mark("rift2")
	var team := TB.strongest("A", "jianxian")
	print("T455_TEAM=", team)
	var rows := []
	for f in floors:
		for sd in seeds:
			for arm in ["off", "huaxing", "shigu"]:
				var r := _fight(team, f, sd, arm)
				rows.append(r)
				print("T455_ROW=", JSON.stringify(r))
	XRiftAlien.ENABLED = true
	XRiftAlien.STAGE_OVERRIDE = 0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"team": team, "rows": rows}, "\t"))
	XConfig.path_override = ""
	print("TEST_RESULT=", JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit(0)
