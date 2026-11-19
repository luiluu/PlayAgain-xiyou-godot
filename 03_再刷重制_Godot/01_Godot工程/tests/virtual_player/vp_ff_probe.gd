extends Node
## 【cc·T238】快进探针（不进检查.sh）：读虚拟玩家某层的存档，打印队伍（人、等级、装备、生命／物攻／魔攻），
## 对指定敌群用无画面自动战斗真打 N 场（同 vp_fastforward.sample），每场写敌人开打血、剩的血、打掉几成、我方倒几人、回合数。
## godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/vp_ff_probe.tscn -- \
##   --snap=<floor_1_1.json> --troops=422,2 [--n=3] [--turns=40] [--floor=1]
## 收益对照（验收 1）：--compare=<场数> 每个敌群各 N 场「实打（无画面自动打到赢）→ rewards()」与「快进（不打）→ rewards()」，
##   比平均经验、金钱、掉落件数（挂机开着，同 vp_fastforward.grind；--no-hang 关）

var snap := ""
var troops: Array = []
var n := 3
var turns := 40
var floor_override := -1
var trace := 0
var smart := -1
var compare := 0
var hang := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--snap="):
			snap = a.substr(7)
		elif a.begins_with("--troops="):
			troops = Array(a.substr(9).split(",")).map(func(x): return int(x))
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--turns="):
			turns = int(a.substr(8))
		elif a.begins_with("--compare="):
			compare = int(a.substr(10))
		elif a == "--no-hang":
			hang = false
		elif a.begins_with("--smart="):
			smart = int(a.substr(8))
		elif a.begins_with("--trace="):
			trace = int(a.substr(8))
		elif a.begins_with("--floor="):
			floor_override = int(a.substr(8))
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	# 设置不读真实 options.json：用一个不存在的测试路径（＝默认设置，同虚拟玩家），只在内存里改
	XConfig.path_override = "user://test_vp_ff_probe/options.json"
	XConfig._loaded_path = ""
	XConfig.ensure_loaded()
	if smart >= 0:
		XConfig._values.codexSmartAI = smart == 1
	print("PROBE 智能AI %s" % str(XConfig.smart_ai()))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(snap))
	if not parsed is Dictionary:
		print("PROBE 读不到存档 " + snap)
		get_tree().quit.call_deferred(1)
		return
	var st := XState.from_dict(parsed)
	if floor_override > 0:
		st.set_variable(20, floor_override)
	XState._become_current(st)
	print("PROBE 层 %d 难度变量 金币 %d" % [int(st.variable(20)), int(st.gold)])
	for a in st.battle_members():
		a.recover_all()
		var eq := []
		for e in a.equips:
			if e is Dictionary and not e.is_empty():
				eq.append(str(e.get("name", e.get("id", ""))))
		print("PROBE 队员 %d %s 等级 %d/%d 生命 %d 物攻 %d 魔攻 %d 防 %d 速 %d 技能 %d 个 装备 %s" % [a.actor_id, a.display_name(), a.level, a.max_level(),
			int(a.param(0)), int(a.param(2)), int(a.param(4)), int(a.param(3)), int(a.param(6)), a.skills().size() if a.has_method("skills") else -1, ",".join(eq)])
	if compare > 0:
		_compare(st)
		get_tree().quit.call_deferred(0)
		return
	for troop in troops:
		for k in n:
			var copy := XState.from_dict(st.to_dict())
			XState._become_current(copy)
			for a in copy.members():
				a.recover_all()
			var logic := XBattleLogic.new()
			logic.setup(int(troop), copy)
			logic.auto = true
			var hp0 := 0.0
			var names := []
			for e in logic.enemies:
				hp0 += e.mhp if "mhp" in e else e.param(0)
				names.append("%s(%d)" % [e.display_name(), int(e.param(0))])
			_drain(logic, logic.troop_events())
			if k == 0:
				for e in logic.enemies:
					print("PROBE 敌人 %s 防 %d 魔防 %d 回血率 %s 状态 %s" % [e.display_name(), int(e.param(3)), int(e.param(5)), str(e.xparam(7)), str(e.state_ids)])
				var w := []
				for a in logic.actors:
					w.append("%s:%s" % [a.display_name(), ",".join(a.skills().map(func(sk): return "%s(%d)" % [str(sk.get("name", "")), int(sk.get("id", 0))]))])
				print("PROBE 技能 " + " / ".join(w))
			var r := 0
			while r < turns and not logic.is_over():
				r += 1
				logic.start_turn()
				logic.take_turn_start_logs()
				var count := 0
				var first := true
				while count < 120:
					var u := logic.next_subject()
					_drain(logic, logic.troop_events(u if first else null))
					first = false
					if u == null or logic.is_over():
						break
					count += 1
					var cmd := logic.decide(u)
					var lg := logic.act(u, cmd[0], cmd[1])
					if r <= trace:
						print("TRACE 回合 %d %s 用 %s → %s" % [r, u.display_name(), str(cmd[0].get("name", cmd[0]) if cmd[0] is Dictionary else cmd[0]), _brief(lg)])
					if logic.is_over():
						break
				if logic.is_over():
					break
				var before_end := 0.0
				for e in logic.enemies:
					before_end += e.hp
				logic.end_turn()
				_drain(logic, logic.troop_events(null, true))
				if r <= trace:
					var after_end := 0.0
					for e in logic.enemies:
						after_end += e.hp
					print("TRACE 回合 %d 回合末敌血 %d → %d" % [r, int(before_end), int(after_end)])
			var left := 0.0
			for e in logic.enemies:
				left += maxf(0.0, e.hp)
			var dead := logic.actors.filter(func(a): return a.is_dead()).size()
			print("PROBE 敌群 %d 第 %d 场：%s 回合 %d 敌血 %d→%d 打掉 %d%% 我方倒 %d/%d 敌人 %s" % [int(troop), k + 1,
				"赢" if logic.is_won() else ("输" if logic.is_lost() else "僵"), r, int(hp0), int(left), int(100.0 * (1.0 - left / maxf(1.0, hp0))),
				dead, logic.actors.size(), ",".join(names)])
			logic.end_battle(2)
	get_tree().quit.call_deferred(0)


static func _drain(logic: XBattleLogic, logs: Array) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		var last: Dictionary = logs[-1] if not logs.is_empty() and logs[-1] is Dictionary else {}
		logs = logic.resume_event(int(last.get("token", 0)), 0)


static func _brief(lg: Array) -> String:
	var out := []
	for e in lg:
		if not e is Dictionary:
			continue
		var d: Dictionary = e.duplicate()
		d.erase("skill")
		d.erase("user")
		for k in d.keys():
			if d[k] is Object:
				d[k] = str(d[k].display_name()) if d[k].has_method("display_name") else "obj"
			elif d[k] is Array:
				d[k] = str(d[k]).substr(0, 300)
		out.append(JSON.stringify(d).substr(0, 500))
	return " | ".join(out)


## 收益对照：同一份存档、同一敌群，实打赢了再结算 vs 不打直接结算（vp_fastforward.settle 的做法），各 compare 场
func _compare(st: XState) -> void:
	for troop in troops:
		var acc := {"real": {"n": 0, "exp": 0.0, "gold": 0.0, "drops": 0.0, "lost": 0, "kinds": {}}, "ff": {"n": 0, "exp": 0.0, "gold": 0.0, "drops": 0.0, "lost": 0, "kinds": {}}}
		var pair := {}
		var same := 0
		var paired := 0
		for k in compare:
			for mode in ["real", "ff"]:
				var copy := XState.from_dict(st.to_dict())
				XState._become_current(copy)
				for a in copy.members():
					a.recover_all()
				# 每场换一个战斗键（天启篇按「敌群号|第几次」钉随机）：第 k 场实打和快进用同一个键，场与场之间独立
				var rng = copy.flags.get("tianqi", {}).get("rng")
				if rng is Dictionary:
					rng["battle|%d" % int(troop)] = int(rng.get("battle|%d" % int(troop), 0)) + k
				copy.hang_up_active = hang
				if hang and copy.hang_up_origin.x < 0:
					copy.hang_up_origin = Vector2i(copy.x, copy.y)
				var logic := XBattleLogic.new()
				logic.setup(int(troop), copy)
				logic.auto = true
				if mode == "real":
					_drain(logic, logic.troop_events())
					_fight(logic, turns)
					if not (logic.is_won() and not logic.is_lost()):
						acc[mode].lost += 1
						logic.end_battle(2)
						continue
				var r := logic.rewards()
				var sig := JSON.stringify((r.drops as Array).map(func(d): return [int(d.get("id", 0)), str(d.get("kind", ""))] if d is Dictionary else d))
				if mode == "real":
					pair[k] = sig
				elif pair.has(k):
					same += 1 if pair[k] == sig else 0
					paired += 1
				var a: Dictionary = acc[mode]
				a.n += 1
				a.exp += float(r.exp)
				a.gold += float(r.gold)
				a.drops += float((r.drops as Array).size())
				for d in r.drops:
					var key := str(d.get("kind", d.get("type", "?"))) if d is Dictionary else "?"
					a.kinds[key] = int(a.kinds.get(key, 0)) + 1
				logic.end_battle(0)
		var line := []
		for mode in ["real", "ff"]:
			var a: Dictionary = acc[mode]
			var m := maxf(1.0, float(a.n))
			line.append("%s 赢 %d 输 %d 经验 %.1f 金钱 %.1f 掉落 %.3f 件 %s" % ["实打" if mode == "real" else "快进", a.n, a.lost, a.exp / m, a.gold / m, a.drops / m, JSON.stringify(a.kinds)])
		print("COMPARE 敌群 %d：%s ｜ 同一战斗键掉落完全相同 %d/%d" % [int(troop), " ｜ ".join(line), same, paired])
	XState._become_current(st)


func _fight(logic: XBattleLogic, max_turns: int) -> int:
	var r := 0
	while r < max_turns and not logic.is_over():
		r += 1
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var first := true
		while count < 120:
			var u := logic.next_subject()
			_drain(logic, logic.troop_events(u if first else null))
			first = false
			if u == null or logic.is_over():
				break
			count += 1
			var cmd := logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			if logic.is_over():
				break
		if logic.is_over():
			break
		logic.end_turn()
		_drain(logic, logic.troop_events(null, true))
	return r
