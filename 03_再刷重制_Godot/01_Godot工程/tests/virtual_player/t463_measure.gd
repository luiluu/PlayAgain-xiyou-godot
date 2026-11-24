extends Node
## T463 + T465 西游档量数工具（非顶层专项）：
## --mode=dummy [--lv=35|55|80]
## --mode=tower [--team=strong|super|feitian|kotori] [--route=normal|doom|primordial|all] [--floors=13,21,33] [--gmode=off|split|combined] [--turns=15] [--seeds=3]

const GUARDIANS := {13: 111, 21: 457, 33: 469}
const LV_BY_F := {13: 35, 21: 55, 33: 80}
const ART_LV_BY_F := {13: 48, 21: 72, 33: 99}
const MASTERY_BY_F := {13: 15, 21: 24, 33: 32}

const ZQ_TABLE := {
	"normal": {13: [2, 2500], 21: [4, 18000], 33: [13, 500000]},
	"doom": {13: [2, 18000], 21: [4, 66000], 33: [13, 500000]},
	"primordial": {13: [2, 36000], 21: [4, 111000], 33: [13, 500000]},
}

var mode := "dummy"
var lv_arg := 80
var team_arg := "strong"
var route_arg := "all"
var floors_arg := [13, 21, 33]
var gmode := "on"
var nerf_on := true
var max_turns := 15
var seed_count := 1
var _best_armors := {}
var _best_weapons := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--lv="):
			lv_arg = int(a.substr(5))
		elif a.begins_with("--team="):
			team_arg = a.substr(7)
		elif a.begins_with("--route="):
			route_arg = a.substr(8)
		elif a.begins_with("--floors="):
			floors_arg = Array(a.substr(9).split(",")).map(func(x): return int(x))
		elif a.begins_with("--gmode="):
			gmode = a.substr(8)
		elif a == "--nerf=off":
			nerf_on = false
		elif a.begins_with("--turns="):
			max_turns = int(a.substr(8))
		elif a.begins_with("--seeds="):
			seed_count = int(a.substr(8))
	_run.call_deferred()


func _fmt(v: float) -> String:
	if v >= 1e18:
		return "%.2fE" % (v / 1e18)
	if v >= 1e15:
		return "%.2fQ" % (v / 1e15)
	if v >= 1e12:
		return "%.2fT" % (v / 1e12)
	if v >= 1e9:
		return "%.2fB" % (v / 1e9)
	if v >= 1e6:
		return "%.2fM" % (v / 1e6)
	if v >= 1e3:
		return "%.2fK" % (v / 1e3)
	return "%.0f" % v


func _equip_in_slot(a: XActor, item: Dictionary) -> void:
	var slots := a.equip_slots()
	for i in slots.size():
		if int(slots[i]) == int(item.etypeId):
			a.equips[i] = item
			return


func _req_lv(rec: Dictionary) -> int:
	var m := RegEx.create_from_string("(?i)<req_level\\s*:\\s*(\\d+)>").search(str(rec.get("note", "")))
	return int(m.get_string(1)) if m else 1


func _is_excl(rec: Dictionary) -> bool:
	var n := str(rec.get("note", ""))
	return n.contains("req_actors") or n.contains("专属:") or n.contains("专属：") or n.contains("能够装备")


func _best_gear_for(lv: int) -> void:
	if _best_armors.has(lv):
		return
	var arm_by_et := {}
	for r in XDB.table("Armors"):
		if not r is Dictionary or str(r.get("name", "")) == "":
			continue
		if _is_excl(r) or _req_lv(r) > lv:
			continue
		var et := int(r.get("etypeId", 0))
		if et <= 1 or et == 13:
			continue
		# 排除带负面或奇怪状态的特殊测试装
		var nm := str(r.get("name", ""))
		if nm.begins_with("\"") or nm.contains("测试"):
			continue
		var p: Array = r.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
		var score := float(p[2]) + float(p[4]) + float(p[0]) * 0.02 + float(p[6]) * 0.5
		if not arm_by_et.has(et) or score > float(arm_by_et[et][0]):
			arm_by_et[et] = [score, int(r.id)]
	_best_armors[lv] = arm_by_et
	var wpn_by_wt := {}
	for r in XDB.table("Weapons"):
		if not r is Dictionary or str(r.get("name", "")) == "":
			continue
		if _is_excl(r) or _req_lv(r) > lv:
			continue
		var nm := str(r.get("name", ""))
		if nm.begins_with("\"") or nm.contains("测试"):
			continue
		var wt := int(r.get("wtypeId", 0))
		var p: Array = r.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
		var score := float(p[2]) + float(p[4])
		if not wpn_by_wt.has(wt) or score > float(wpn_by_wt[wt][0]):
			wpn_by_wt[wt] = [score, int(r.id)]
	_best_weapons[lv] = wpn_by_wt


func _run_dummy() -> void:
	XZhenqi.APPLY_TO_DAMAGE = false
	XXiyouNerf.ENABLED = nerf_on
	XXiyouNerf.clear_cache()
	XStateEffects.force_critical = true
	var use_wpn := lv_arg >= 75
	var art_lv := 48 if lv_arg <= 35 else (72 if lv_arg <= 55 else 99)
	var mastery := 10 if lv_arg <= 35 else (20 if lv_arg <= 55 else 32)
	# [aid, label, fabao, wpn, off, fb_wpn, extra_skills, tag]
	var actors := [
		[1, "狗逍遥(强)", 4512, 0, 0, 2, [], ""],
		[47, "酒剑仙(强)", 3570, 0, 4146, 2, [], ""],
		[50, "劲夫(强)", 3812, 0, 0, 0, [], ""],
		[122, "狂刀(超)", 4575, 2019, 0, 2, [], ""],
		[152, "徐凤年(超)", 143, 76, 129, 2, [], ""],
		[164, "贝吉特(超)", 125, 91, 0, 0, [], ""],
		[163, "拳一(超)", 124, 90, 0, 0, [], ""],
		[162, "诛仙(超)", 123, 89, 0, 2, [], ""],
		[147, "非天-10072满剑", 136, 4003, 0, 2, [], "ft10"],
		[147, "非天-10485(4段)", 136, 4003, 0, 2, [10481, 10482, 10483, 10484, 10485, 10486, 10487, 10488, 10489], "ft10_10485"],
		[147, "非天-10485(13段)", 136, 4003, 0, 2, [7143, 7144, 7145, 10481, 10482, 10483, 10484, 10485, 10486, 10487, 10488, 10489], "ft10_10485"],
		[147, "非天-10485(13段无专)", 136, 0, 0, 2, [7143, 7144, 7145, 10481, 10482, 10483, 10484, 10485, 10486, 10487, 10488, 10489], "ft10_10485"],
		[159, "琴里-炮(专武)", 120, 87, 0, 10, [10055, 10560], "kt_gun"],
		[159, "琴里-炮(无专武)", 120, 0, 0, 10, [10055, 10560], "kt_gun"],
		[159, "琴里-斧(专武)", 120, 87, 0, 4, [10058, 10621], "kt_axe"],
	]
	print("=== DUMMY lv=%d art=%d m=%d use_wpn=%s ===" % [lv_arg, art_lv, mastery, str(use_wpn)])
	var kd_val := 0.0
	var rows := []
	for row in actors:
		var aid: int = row[0]
		var label: String = row[1]
		var art_id: int = row[2]
		var wpn_id: int = row[3] if use_wpn else 0
		var off_id: int = row[4] if use_wpn else 0
		var fb_wpn: int = row[5]
		var extra: Array = row[6]
		var tag: String = row[7]
		var s := XState.new_game_blank()
		s.random_master = XRandomStream.hex64(1000003 + aid * 7919 + 1)
		s.set_switch(2494, true)
		XState.current = s
		if tag.begins_with("ft10"):
			for vid in range(1580, 1590):
				s.set_variable(vid, 1)
		s.add_actor(aid)
		for i in 5:
			s.set_battle_slot(i, aid if i == 0 else 0)
		var a := s.actor(aid)
		a.change_level(lv_arg)
		for sid in extra:
			a.learn_skill(int(sid))
		if art_id > 0:
			var art := a.make_equip("armor", art_id)
			art["level"] = art_lv
			_equip_in_slot(a, art)
		var w_use := wpn_id if wpn_id > 0 else fb_wpn
		if w_use > 0:
			a.equips[0] = a.make_equip("weapon", w_use)
		if off_id > 0:
			_equip_in_slot(a, a.make_equip("armor", off_id))
		a.param_mark_dirty()
		a.refresh_passive()
		for sid in a.skill_ids:
			a.mastery_levels[sid] = mastery
		a.recover_all()

		var logic := XBattleLogic.new()
		var rng := XBattleRandom.create(str(s.random_master))
		logic.setup(70, s, rng)
		if tag == "kt_gun":
			logic._state_add(a, 2767)
		elif tag == "kt_axe":
			logic._state_add(a, 2768)
		var foe: XEnemy = logic.enemies[0]
		foe.param_refresh()
		foe.recover_all()

		var total_dmg := 0.0
		var used := {}
		for _t in 5:
			logic.start_turn()
			var n_act := 1
			for p in a.action_plus_set():
				if rng.rule_now().next_float("action_plus") < float(p):
					n_act += 1
			for _k in n_act:
				if not logic.can_move(a):
					continue
				a.mp = a.mmp
				a.tp = 100.0
				var sk = null
				if aid == 122:
					for cand in [6039, 6028, 6026, 6025, 6024]:
						if a.skill_ids.has(cand) and logic.can_use(a, XDB.rec("Skills", cand)):
							sk = XDB.rec("Skills", cand)
							break
				elif tag == "ft10_10485":
					sk = XDB.rec("Skills", 10485)
				elif tag == "kt_gun":
					if s.variable(1510) >= 500:
						a.learn_skill(10056)
						logic._state_add(a, 2769)
						sk = XDB.rec("Skills", 10056)
					else:
						sk = XDB.rec("Skills", 10055)
				elif tag == "kt_axe":
					if s.variable(1510) >= 500:
						a.learn_skill(10057)
						logic._state_add(a, 2765)
						sk = XDB.rec("Skills", 10057)
					else:
						sk = XDB.rec("Skills", 10058)
				else:
					sk = XSmartAI.choose(logic, a).get("skill")
				if sk == null:
					continue
				used[str(sk.id) + ":" + str(sk.name)] = int(used.get(str(sk.id) + ":" + str(sk.name), 0)) + 1
				var logs: Array = logic.act(a, sk, foe)
				for e in logs:
					if e is Dictionary and str(e.get("type", "")) == "hit" and is_same(e.get("target"), foe):
						total_dmg += maxf(0.0, float(e.get("hp", 0.0)))
				foe.hp = foe.mhp
			logic.end_turn()
		logic.end_battle(0)
		if aid == 122:
			kd_val = total_dmg
		rows.append([label, total_dmg, JSON.stringify(used)])
	for r in rows:
		print("  %-20s | dmg=%10s | vs_KD=%9.2fx | %s" % [r[0], _fmt(r[1]), float(r[1]) / maxf(1.0, kd_val), r[2]])
	XStateEffects.force_critical = false


func _setup_tower_actor(s: XState, a: XActor, floor_n: int, route_key: String, fabao_id: int, wpn_ov: int, off_ov: int, extra: Array) -> void:
	var lv: int = LV_BY_F[floor_n]
	var art_lv: int = ART_LV_BY_F[floor_n]
	var mastery: int = MASTERY_BY_F[floor_n]
	_best_gear_for(lv)
	a.change_level(lv)
	# 1. 进阶满（照 full_clear_max.gd）
	for _n in range(100):
		var row = XAdvance.row(s, a.actor_id)
		if row == null:
			break
		s.gain_gold(XState.GOLD_MAX)
		for p in row.items:
			var need := int(p[1]) - s.item_count(int(p[0]))
			if need > 0:
				s.gain_item(int(p[0]), need)
		if not XAdvance.advance(s, a):
			break
	# 2. 种族祝福（13F→3阶，21F→5阶，33F→7阶）
	var target_race_rank := 3 if floor_n <= 13 else (5 if floor_n <= 21 else 7)
	var stones: Array = XRace.config().get("stones", [])
	var rd := XRace.data(s, a)
	if int(rd.race) < 0:
		s.gain_item(int(XRace.config().water), 1)
		XRace.change(s, a, 0)
	for rk_i in range(int(rd.rank) + 1, target_race_rank + 1):
		if rk_i - 2 >= 0 and rk_i - 2 < stones.size():
			s.gain_item(int(stones[rk_i - 2]), 1)
		if not XRace.upgrade(s, a, rk_i).ok:
			break
	# 3. 修炼（13F→40%，21F→75%，33F→100%）
	var tr_ratio := 0.4 if floor_n <= 13 else (0.75 if floor_n <= 21 else 1.0)
	for tid in XTraining.table():
		var e := XTraining.entry(int(tid))
		var target_lv := int(roundf(float(e.max) * tr_ratio))
		for _k in range(target_lv):
			s.gain_gold(XState.GOLD_MAX)
			if XTraining.confirm(s, a.actor_id, int(tid)) != "修炼成功":
				break

	for sid in extra:
		a.learn_skill(int(sid))
	if route_key == "normal":
		a.learn_skill(5548)
		a.learn_skill(6216)
	else:
		a.learn_skill(5564)
		a.learn_skill(6216)
		a.learn_skill(6250)
		a.learn_skill(6251)
		if floor_n >= 21:
			a.learn_skill(6252)
		if floor_n >= 33:
			a.learn_skill(6253)
	# 4. 秘境被动书＋通用顶级被动＋洪荒权能（按楼层阶段的真实西游满养成）
	var mijing := [6305, 6306, 6309, 6310, 6313, 6314, 6321, 6325, 6326, 6526, 6527, 7137]
	if floor_n >= 21:
		mijing.append_array([6307, 6311, 6315, 6322, 6323, 6327, 6528, 6529, 7135, 7138, 7143, 7144, 7145])
	if floor_n >= 33:
		mijing.append_array([6308, 6312, 6316, 6324, 6328, 6530, 7139, 7168, 7179, 7187, 9976])
	if route_key == "primordial":
		if floor_n >= 13:
			mijing.append_array([7239, 7240, 7241])
		if floor_n >= 21:
			mijing.append_array([7238, 7242, 7243])
		if floor_n >= 33:
			mijing.append_array([7244, 7245, 7246, 7247])
	for sid in mijing:
		a.learn_skill(sid)
	# 5. 真气＋境界＋道法＋突破奖励
	var zq_cfg: Array = ZQ_TABLE[route_key][floor_n]
	var realm: int = zq_cfg[0]
	var qi: int = zq_cfg[1]
	var daofa := {"lianji": 1, "pojia": 1}
	if floor_n >= 21:
		daofa["fenshen"] = 1
		daofa["hufa"] = 1
	if floor_n >= 33:
		daofa["jinshen"] = 1
		daofa["lingtai"] = 1
		daofa["huichun"] = 1
	a.zhenqi = XZhenqi.from_save({"qi": qi, "realm": realm, "daofa": daofa})
	for r_i in range(1, realm + 1):
		XZhenqi.grant_fixed(a, r_i)
		XZhenqi.learn_key(a, ("attr:atk:%d" if r_i <= 4 else "attr:all:%d") % r_i)
	for dfk in daofa:
		XZhenqi.learn_key(a, "daofa:" + str(dfk))
	# 6. 19 栏满养成装备＋鹰眼/锋刃宝珠镶嵌
	var arm_map: Dictionary = _best_armors[lv]
	var orb_eye := XDB.rec("Items", 3019 if floor_n <= 13 else (3020 if floor_n <= 21 else 3021))
	var orb_edge := XDB.rec("Items", 2949 if floor_n <= 13 else (2950 if floor_n <= 21 else 2951))
	for et in arm_map:
		var it := a.make_equip("armor", int(arm_map[et][1]))
		if not it.is_empty():
			XOrbs.ensure(it)
			var sc := XOrbs.slots(it).size()
			for si in range(sc):
				var g := orb_eye if (si == 0 and not orb_eye.is_empty()) else orb_edge
				if not g.is_empty() and XOrbs.can_attach(it, g, si):
					XOrbs.install_to_slot(it, g, si)
			_equip_in_slot(a, it)
	if fabao_id > 0:
		var art := a.make_equip("armor", fabao_id)
		art["level"] = art_lv
		_equip_in_slot(a, art)
	if off_ov > 0:
		_equip_in_slot(a, a.make_equip("armor", off_ov))
	if wpn_ov > 0:
		a.equips[0] = a.make_equip("weapon", wpn_ov)
	else:
		var wmap: Dictionary = _best_weapons[lv]
		var best_s := -1.0
		var best_wid := 0
		for wt in wmap:
			var cand_id := int(wmap[wt][1])
			var cand_w := a.make_equip("weapon", cand_id)
			if not cand_w.is_empty() and a.can_equip(cand_w) and float(wmap[wt][0]) > best_s:
				best_s = float(wmap[wt][0])
				best_wid = cand_id
		if best_wid > 0:
			var w := a.make_equip("weapon", best_wid)
			XOrbs.ensure(w)
			for si in range(XOrbs.slots(w).size()):
				if not orb_eye.is_empty() and XOrbs.can_attach(w, orb_eye, si):
					XOrbs.install_to_slot(w, orb_eye, si)
			a.equips[0] = w
	a.param_mark_dirty()
	a.refresh_passive()
	for sid in a.skill_ids:
		a.mastery_levels[sid] = mastery
	a.recover_all()


func _run_tower() -> void:
	XZhenqi.APPLY_TO_DAMAGE = (gmode != "off")
	XXiyouNerf.ENABLED = nerf_on
	XXiyouNerf.clear_cache()

	var teams := {
		"strong": [
			[1, 4512, 0, 0, []],
			[47, 3570, 0, 4146, []],
			[50, 3812, 0, 0, []],
			[85, 0, 2222, 0, []],
		],
		"super": [
			[122, 4575, 2019, 0, []],
			[152, 143, 76, 129, []],
			[164, 125, 91, 0, []],
			[179, 4582, 4004, 0, []],
		],
		"feitian": [
			[147, 136, 4003, 0, [10481, 10482, 10483, 10484, 10485, 10486, 10487, 10488, 10489]],
		],
		"kotori": [
			[159, 120, 87, 0, [10055, 10560]],
		],
	}
	var spec: Array = teams[team_arg]
	var routes := ["normal", "doom", "primordial"] if route_arg == "all" else [route_arg]
	print("=== TOWER team=%s gmode=%s ===" % [team_arg, gmode])
	for rk in routes:
		for fl in floors_arg:
			var wins := 0
			var sum_turns := 0.0
			var sum_dpt := 0.0
			var last_hp0 := 0.0
			var last_g := 1.0
			var last_cri := 0.0
			for sd in range(1, seed_count + 1):
				var diff_id := 3 if rk == "normal" else (7 if rk == "doom" else 8)
				var s := XState.new_game_blank()
				s.difficulty = diff_id
				s.random_master = XRandomStream.hex64(20261124 + fl * 100 + diff_id * 10 + sd)
				s.set_variable(20, fl + 1)
				s.set_switch(2494, true)
				if rk == "doom":
					s.set_switch(2487, true)
				elif rk == "primordial":
					s.set_switch(2487, true)
					s.set_switch(2483, true)
				XState.current = s
				for vid in range(1580, 1590):
					s.set_variable(vid, 1)
				for i in spec.size():
					var row: Array = spec[i]
					var aid: int = row[0]
					var wpn_ov: int = row[2] if fl >= 33 else (10 if aid == 159 else 0)
					var off_ov: int = row[3] if fl >= 33 else 0
					s.add_actor(aid)
					s.set_battle_slot(i, aid)
					_setup_tower_actor(s, s.actor(aid), fl, rk, row[1], wpn_ov, off_ov, row[4])
				for i in range(spec.size(), 5):
					s.set_battle_slot(i, 0)
				var logic := XBattleLogic.new()
				var rng := XBattleRandom.create(str(s.random_master))
				logic.setup(GUARDIANS[fl], s, rng)
				logic.auto = true
				for m in s.battle_members():
					if m.actor_id == 159:
						logic._state_add(m, 2767)
				var a0: XActor = s.battle_members()[0]
				last_g = XZhenqi.damage_mult(a0, logic.enemies[0])
				last_cri = a0.cri
				var hp0 := 0.0
				for e in logic.enemies:
					hp0 += float(e.mhp)
				last_hp0 = hp0
				var dealt := 0.0
				var turns := 0
				while turns < max_turns and not logic.is_over():
					turns += 1
					logic.start_turn()
					logic.take_turn_start_logs()
					var cnt := 0
					while cnt < 80:
						var u := logic.next_subject()
						if u == null:
							break
						cnt += 1
						if u is XActor:
							u.mp = u.mmp
							u.tp = 100.0
						var cmd := logic.decide(u)
						if u is XActor and u.actor_id == 147 and u.skill_ids.has(10485):
							cmd = [XDB.rec("Skills", 10485), logic.enemies[0]]
						elif u is XActor and u.actor_id == 159:
							if s.variable(1510) >= 500:
								u.learn_skill(10056)
								logic._state_add(u, 2769)
								cmd = [XDB.rec("Skills", 10056), logic.enemies[0]]
							else:
								cmd = [XDB.rec("Skills", 10055), logic.enemies[0]]
						var b_hp := 0.0
						for e in logic.enemies:
							if e.is_alive(): b_hp += float(e.hp)
						logic.act(u, cmd[0], cmd[1])
						var a_hp := 0.0
						for e in logic.enemies:
							if e.is_alive(): a_hp += float(e.hp)
						if u is XActor:
							dealt += maxf(0.0, b_hp - a_hp)
						if logic.is_over():
							break
					if not logic.is_over():
						logic.end_turn()
				if logic.is_won():
					wins += 1
				sum_turns += float(turns)
				sum_dpt += dealt / maxf(1.0, float(turns))
				logic.end_battle(0 if logic.is_won() else 2)
			var avg_dpt := sum_dpt / float(seed_count)
			print("  %-10s F%2d | g=%6.2fx | cri=%5.1f | HP=%9s | dpt=%9s | win=%d/%d | avgT=%4.1f | ttk=%8.1f" % [
				rk, fl, last_g, last_cri, _fmt(last_hp0), _fmt(avg_dpt), wins, seed_count, sum_turns / float(seed_count), last_hp0 / maxf(1.0, avg_dpt)
			])


func _run() -> void:
	if mode == "dummy":
		_run_dummy()
	else:
		_run_tower()
	get_tree().quit(0)
