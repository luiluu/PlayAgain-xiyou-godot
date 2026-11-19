extends Node
## T258 无限成长③验收 6：「一场」口径实测（cc，Sonnet）。不是专项（不在 tests/ 顶层，检查.sh 不跑）。单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/growth_scene_probe.tscn -- \
##     [--focals=167,108,179] [--n=20] [--classes=random,abyss,gandi] [--difficulty=lianyu] [--seed=1] [--max-turns=40] [--out=<json>] [--debug]
##
## 做什么：每个焦点角色（渡鸦 167、奈叶 108、流萤 179）各配一支「真装备阵容」——焦点＋配队器（team_builder 模板 A 最强队）里的非焦点三人，
## 4 人都按 K 探针甲档口径穿（81 级、进阶满、每栏 80 级神话最高主属性件、本人法宝、七印黑印整套、秘籍、号卷、熟练度满；词条不挑），
## 打自动战斗（我方每回合回满血蓝，打到敌人死光或 max-turns 回合）。T257 的真计数接线一路走：渡鸦灵魂走 XRaven.on_enemy_death 的 growth_gain、
## 奈叶适应走 XNanoha.adapt（自己打倒 1、队友打倒 0.5，超出基础段才过 floor_ok）、流萤胜场走 battle_logic 的 gain_rewards。
## 每场开始把三人的计数调到基础段末（灵魂 20 万、适应 2000 次、流萤 300 胜），所以量到的增量全是「基础段以外、要过 floor_ok」的那部分；
## 进度变量放在主塔 29 层（变量 20＝30），24～27 层随机遇敌、24～29 层深渊、24 层肝帝之地都过 floor_ok（开战前断言，过不了的场记 counted:false）。
## 敌群来源：random＝24～27 层各张「N层」地图的遇敌表（按权重抽）；abyss＝层号 24～29 的深渊地图里的固定战斗（每个敌群等概率）；
## gandi＝特殊秘境「肝帝之地」（地图 185）遇敌表。副本（王者档）的敌群在事件里按副本号拼，没量（报告里写明）。
## 奈叶自己击杀占比 p＝(2×适应增量−敌人数)÷敌人数（打赢且全部敌人都是她或队友打倒、每个计一次时成立；两个条件都不满足的场不入统计）。

const K := preload("res://tests/virtual_player/k_calibrate.gd")
const TB := preload("res://tests/virtual_player/team_builder.gd")
const RAVEN := 167
const NANOHA := 108
const LIUYING := 179
const PROGRESS_VAR := 30   # 变量 20＝30 → 主塔 29 层

var focals: Array = [167, 108, 179]
var n_per := 20
var classes: Array = ["random", "abyss", "gandi"]
var difficulty := "lianyu"
var seed_v := 1
var max_turns := 12  # 深渊首领打 12 回合还没赢就记没赢（40 回合也没赢过）
var out_path := ""
var debug := false
var k = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--focals="):
			focals = Array(a.substr(9).split(",")).map(func(x): return int(x))
		elif a.begins_with("--n="):
			n_per = int(a.substr(4))
		elif a.begins_with("--classes="):
			classes = Array(a.substr(10).split(","))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--max-turns="):
			max_turns = int(a.substr(12))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--debug":
			debug = true
	_run.call_deferred()


## [[地图号, 敌群号, 权重]]
func _pool(cls: String) -> Array:
	var out := []
	match cls:
		"random":
			for info in XDB.table("MapInfos"):
				if not info is Dictionary or info.is_empty():
					continue
				var id := int(info.get("id", 0))
				var f := XDungeon.map_floor(id)
				if id <= 0 or f < 24 or f > 27 or not RegEx.create_from_string("^\\d+层").search(str(info.get("name", ""))):
					continue
				for en in XDB.map(id).get("encounterList", []):
					if int(en.get("troopId", 0)) > 0:
						out.append([id, int(en.troopId), maxi(1, int(en.get("weight", 1)))])
		"gandi":
			for en in XDB.map(185).get("encounterList", []):
				if int(en.get("troopId", 0)) > 0:
					out.append([185, int(en.troopId), maxi(1, int(en.get("weight", 1)))])
		"abyss":
			for info in XDB.table("MapInfos"):
				if not info is Dictionary or info.is_empty():
					continue
				var id := int(info.get("id", 0))
				var f := XDungeon.map_floor(id)
				if not str(info.get("name", "")).begins_with("深渊") or f < 24 or f > 29:
					continue
				var seen := {}
				for ev in XDB.map(id).get("events", []):
					if not ev is Dictionary:
						continue
					for pg in ev.get("pages", []):
						for c in pg.get("list", []):
							if int(c.get("code", 0)) == 301 and int(c.parameters[0]) == 0:
								var t := int(c.parameters[1])
								if t > 0 and t != 661 and t != 767 and not seen.has(t):  # 661、767 是各深渊都放的公共战（守层者类）
									seen[t] = true
									out.append([id, t, 1])
	return out


func _team(focal: int) -> Array:
	var base: Array = TB.strongest("A", difficulty)
	var mates := base.filter(func(x): return int(x) != focal)
	var team := [focal]
	for m in mates:
		if team.size() < 4:
			team.append(int(m))
	if not TB.legal(team, difficulty):
		# 配队器最强队里没有弱者时（炼狱要求场上至少 1 名弱者）：把最后一位换成同职责里最强的弱者；超强者超上限的换成同职责最强的非超强者
		var cand: Dictionary = TB.candidates(difficulty)
		for pass_i in 3:
			if TB.legal(team, difficulty):
				break
			var need_weak := team.filter(func(x): return XTianqiSkills.is_weak(int(x), true)).size() < TB.min_weak_field(difficulty)
			var idx := team.size() - 1
			var role: String = TB.role_of(int(team[idx]))
			var list: Array = (cand[role] as Array).duplicate()
			list.sort_custom(func(x, y): return TB.rank_score(int(x), role) > TB.rank_score(int(y), role))
			for c in list:
				if team.has(int(c)):
					continue
				if (need_weak and XTianqiSkills.is_weak(int(c), true)) or (not need_weak and not XTianqiSkills.is_super(int(c), true)):
					team[idx] = int(c)
					break
	return team


func _state(team: Array, tag: int) -> XState:
	var s := XState.new_game(XTianqi.legacy_of(difficulty), int(team[0]), team.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": difficulty, "lineup": team.duplicate()}
	s.random_master = XRandomStream.hex64(seed_v * 7919 + int(team[0]) + tag)
	seed(seed_v * 7919 + int(team[0]) + tag)
	s.set_variable(20, PROGRESS_VAR)
	s.actor_max_level = K.LEVEL
	XTianqiSkills.MASTERY = true
	XState.current = s
	for id in team:
		if not s.party.has(int(id)):
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	for i in 5:
		s.set_battle_slot(i, int(team[i]) if i < team.size() else 0)
	for id in team:
		var a := s.actor(int(id))
		a.change_level_mv(K.LEVEL)
		K._advance_max(s, a)
		K._dress(a)
		var fid := K._own_fabao(int(id))
		if fid == 0:
			var mw := K.main_weights(a)
			fid = K.GENERAL_ATK if float(mw.get("atk", 0.0)) >= float(mw.get("mat", 0.0)) else K.GENERAL_MAT
		var item := XGear.template("armor", fid)
		item.level = float(mini(K.FABAO, int(XMagicWeapon.max_level(item))))
		var slot := a.equip_slots().find(int(item.etypeId))
		if slot >= 0:
			a.equips[slot] = item
		k._qiyin(a)
		k._trumpet(a)
		k._secrets(a)
		for sid in a.skill_ids:
			XSkillMastery.set_level(a, int(sid), XSkillMastery.max_level(int(sid)))
		a.param_mark_dirty()
		a.refresh_passive()
		a.recover_all()
	var n := s.actor(NANOHA)
	if n != null:
		for sk in [XNanoha.SHARED, XNanoha.ADAPT]:
			if not n.skill_ids.has(sk):
				n.learn_skill(sk)
		n.refresh_passive()
	XState.current = s
	return s


## 三人的计数放到基础段末
func _reset_counts(s: XState) -> void:
	var G := XTianqiGrowth
	if s.actors.has(RAVEN):
		s.raven["soul"] = float(G.actor_row(G.RAVEN).base)
	if s.actors.has(NANOHA):
		s.flags[G.NANOHA_FLAG] = {str(NANOHA): float(G.actor_row(G.NANOHA).base)}
	if s.actors.has(LIUYING):
		s.actor(LIUYING).state_data[G.LIUYING_WINS] = float(G.actor_row(G.LIUYING).base)
		s.actor(LIUYING).state_data["_codexLbEmber"] = float(G.actor_row(G.LIUYING).ember_cap)


func _fight(s: XState, map_id: int, troop: int, focal: int) -> Dictionary:
	XState.current = s
	s.map_id = map_id
	_reset_counts(s)
	var G := XTianqiGrowth
	var soul0 := XRaven.soul(s.actor(RAVEN)) if s.actors.has(RAVEN) else 0.0
	var ad0 := float(s.flags.get(G.NANOHA_FLAG, {}).get(str(NANOHA), 0.0))
	var w0 := float(s.actor(LIUYING).state_data.get(G.LIUYING_WINS, 0.0)) if s.actors.has(LIUYING) else 0.0
	for m in s.members():  # 上一场打完有人倒着，开战前全队回满（不然开场就判输）
		m.recover_all()
	var logic := XBattleLogic.new()
	logic.setup(troop, s, null)
	logic.auto = true
	var foes := logic.enemies.size()
	var counted := G.floor_ok(s, logic)
	var turns := 0
	while turns < max_turns and not logic.is_over():
		for a in logic.actors:
			a.recover_all()
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		while count < 80:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			if logic.is_over():
				break
		if not logic.is_over():
			logic.end_turn()
		turns += 1
	var won := logic.is_won()
	var in_field := logic.actors.any(func(a): return int(a.actor_id) == focal)
	var static_soul := 0
	if not won:
		for e in logic.enemies:  # 打不赢（深渊首领战）：灵魂按「赢了每个敌人都死」的数据算，适应、胜场留给汇总按 p 补
			static_soul += XRaven.soul_gain(e)
	if won:
		logic.grant(logic.rewards())  # 战斗场景里胜利后先 rewards() 再 grant()：流萤胜场（gain_rewards）走这一步
	logic.end_battle(0 if won else 2)
	var res := {"static_soul": static_soul, "focal": focal, "map": map_id, "troop": troop, "foes": foes, "turns": turns, "won": won, "counted": counted, "focal_in": in_field,
		"soul": XRaven.soul(s.actor(RAVEN)) - soul0 if s.actors.has(RAVEN) else 0.0,
		"adapt": float(s.flags.get(G.NANOHA_FLAG, {}).get(str(NANOHA), 0.0)) - ad0,
		"wins": (float(s.actor(LIUYING).state_data.get(G.LIUYING_WINS, 0.0)) - w0) if s.actors.has(LIUYING) else 0.0}
	return res


func _run() -> void:
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	k = K.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rows := []
	var pools := {}
	for c in classes:
		pools[c] = _pool(c)
		print("GSC_POOL %s %d 个敌群" % [c, (pools[c] as Array).size()])
	for focal in focals:
		var team := _team(int(focal))
		print("GSC_TEAM focal=%d team=%s legal=%s rule=%s tiers=%s" % [int(focal), team, TB.legal(team, difficulty), TB.rule(difficulty), team.map(func(x): return [int(x), XTianqiSkills.is_super(int(x), true), XTianqiSkills.is_weak(int(x), true)])])
		var s := _state(team, 0)
		for c in classes:
			var pool: Array = pools[c]
			if pool.is_empty():
				continue
			var total := 0
			for p in pool:
				total += int(p[2])
			for i in (pool.size() if c == "abyss" else n_per):  # 深渊每个敌群打一遍
				var pick: Array = pool[0]
				if c == "abyss":
					pick = pool[i % pool.size()]  # 固定战斗：每个敌群轮流各打一遍
				else:
					var r := rng.randi_range(0, total - 1)
					for p in pool:
						r -= int(p[2])
						if r < 0:
							pick = p
							break
				var t0 := Time.get_ticks_msec()
				var row := _fight(s, int(pick[0]), int(pick[1]), int(focal))
				row["class"] = c
				row["ms"] = Time.get_ticks_msec() - t0
				rows.append(row)
				print("GSC_ROW ", JSON.stringify(row))
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"focals": focals, "n": n_per, "classes": classes, "difficulty": difficulty, "seed": seed_v, "rows": rows}, "\t"))
	print("GSC_DONE rows=", rows.size())
	get_tree().quit(0)
