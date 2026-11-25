extends "res://tests/virtual_player/k_calibrate.gd"
## T445：沿用 K 探针的养成与木桩，显式装书；--t444 重跑第二批之前的狗逍遥核算。
## godot --headless --audio-driver Dummy --path <工程> res://tests/virtual_player/t445_book_probe.tscn --
##   --tier=all --actors=95,122,163,167,1,2,22,3,12,18 --book-build=normal --noisy --seed=1
## --book-build=normal|empty|balanced|extreme|lianyu；T444 单段重量用 --t444 --single --actors=1。
## lianyu：D281，T438 炼狱 C 模板的单人输出配法，只装有效秘籍格内的书。
## --noisy --seed=101/202/303 为随机样本；不带 --noisy 跑确定值。JSON 输出可加 --out=<路径>。

const D271 := preload("res://tests/virtual_player/t438_d271_benchmark.gd")
const LIANYU := "lianyu"
const LIANYU_FLOOR := 36
const DAMAGE_ROLE := "输出"

const EXTREME := [6308, 6328, 6530, 6652, 6307, 6327, 6529, 6660, 6316, 6315, 6528, 6616, 6661,
	6312, 6653, 6662, 6610, 6311, 6658, 6672, 10436, 6651, 6606, 6618, 6509]
const BALANCED_UTILITY := [6504, 6613, 6625, 10432, 6508, 6304, 6563, 6336, 6332, 6664]
# T445 的固定清单，供旧探针对照。
const NORMAL_SECRETS := {
	95: [2471, 2480, 488, 6159], 122: [2472, 2480, 489], 163: [2471, 2480, 488], 167: [2478, 2480, 489],
	1: [2471, 2480, 6159, 488], 2: [2471, 2480, 489, 6159, 488, 6139], 22: [2471, 2480, 488, 6139, 489, 6159],
	3: [2471, 2480, 488, 489, 6139, 6159],
	12: [2472, 2480, 488, 489, 6139, 6159],
	18: [2472, 2480, 488, 489, 6139, 6159],
}
const LIANYU_SLOTS := {XTier.SUPER: 5, XTier.STRONG: 6, XTier.WEAK: 8}
# D282：先装本角色主系、通用增伤，再以体能和资源类补足。每本都经运行时占格校验。
const LIANYU_SECRETS := {
	95: [2471, 2480, 6139, 6159, 488], 122: [2472, 2480, 6139, 6159, 489],
	163: [2471, 2480, 6139, 6159, 488], 167: [2478, 2480, 6139, 6159, 489],
	1: [2471, 2480, 6139, 6159, 488, 489], 2: [2471, 2480, 6139, 6159, 488, 489],
	22: [2471, 2480, 6139, 6159, 488, 489],
	3: [2471, 2480, 6139, 6159, 488, 489, 490, 2472],
	12: [2472, 2480, 6139, 6159, 488, 489, 490, 2471],
	18: [2472, 2480, 6139, 6159, 488, 489, 490, 2471],
}
# 依角色主招要求或招牌武器选类。无武器要求的纯法系走法杖。
const LIANYU_WEAPONS := {
	95: "katana", 122: "katana", 163: "fist", 167: "staff",
	1: "sword", 2: "staff", 22: "fist", 3: "staff", 12: "sword", 18: "sword",
}
# 同一木桩下强制量这些核查点，只用于定位；正常样本通过出招菜单触发变招。
const VARIANT_DIAGNOSTICS := {1: [4749], 2: [4759, 4760], 22: [3776]}

var book_build := "normal"
var historical := false
var invalid := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--book-build="):
			book_build = arg.trim_prefix("--book-build=")
		elif arg == "--t444":
			historical = true
	if book_build not in ["normal", "empty", "balanced", "extreme", LIANYU]:
		push_error("未知量数配法：" + book_build)
		get_tree().quit(2)
		return
	if book_build == LIANYU and (historical or not OS.get_cmdline_user_args().has("--noisy") or OS.get_cmdline_user_args().has("--single")):
		push_error("炼狱档使用 --noisy 实测整次施放")
		get_tree().quit(2)
		return
	super._ready()


func _run() -> void:
	XTianqiLedger.violations.clear()
	if book_build == LIANYU:
		level = D271.floor_level_cap(LIANYU_FLOOR)
		gear_level = level - 1
		fabao_level = FABAO
		brand_pct = 75.0
		if only.is_empty():
			only = NORMAL_SECRETS.keys()
			tier_arg = "all"
	if historical:
		XTianqiGeneralBooks.data()
		for sid in XTianqiGeneralBooks.data().get("groups", {}).get("remaining_books", []):
			XTianqiGeneralBooks._skills.erase(int(sid))
	super._run()
	print("BOOK_PROBE " + JSON.stringify({"build": book_build, "historical": historical,
		"violations": XTianqiLedger.violations.size(), "invalid": invalid, "rows": report.rows.size()}))
	if invalid or not XTianqiLedger.violations.is_empty() or (not only.is_empty() and report.rows.size() != only.size()):
		get_tree().quit.call_deferred(1)


func _secrets(a: XActor) -> void:
	if historical:
		super._secrets(a)
		return
	var loadout: Array = (LIANYU_SECRETS if book_build == LIANYU else NORMAL_SECRETS).get(a.actor_id, [])
	for sid in loadout:
		a.learn_skill(int(sid))
	var slots := XTianqiSecrets.active_ids(a)
	var limit := XTianqiSecrets.limit(a)
	if slots.size() != loadout.size() or slots.size() > limit or not loadout.all(func(sid): return slots.has(sid)):
		invalid = true
		push_error("实战配置秘籍异常：%d %s / %s，上限 %d" % [a.actor_id, slots, loadout, limit])
	a.set_meta("k_secrets", slots)


func _lianyu_state(id: int) -> XState:
	var s := XState.new_game(XTianqi.legacy_of(LIANYU), id, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": LIANYU, "lineup": [id]}
	var battle_seed := 20261117 + id + seed_off
	s.random_master = XRandomStream.hex64(battle_seed)
	seed(battle_seed)
	s.set_variable(20, LIANYU_FLOOR)
	s.actor_max_level = level
	XState._become_current(s)
	XTianqiSkills.MASTERY = true
	if not s.party.has(id):
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	for i in 5:
		s.set_battle_slot(i, id if i == 0 else 0)
	var a := s.actor(id)
	a.change_level_mv(level)
	D271._apply_advance(s, a, "C")
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed + 31337
	var qstream := XRandomStream.create(XRandomStream.hex64(battle_seed + 99991), "rule")
	var preset := D271.new()
	var weapon_type := str(LIANYU_WEAPONS.get(id, ""))
	var gear := preset._equip_actor(s, a, "C", LIANYU, DAMAGE_ROLE, LIANYU_FLOOR, level, rng, qstream, weapon_type)
	preset._equip_fabao_mount_artifact(s, a, "C", DAMAGE_ROLE, 0, false, rng)
	_secrets(a)
	preset._apply_growth(s, a, "C", DAMAGE_ROLE, false)
	preset.free()
	if gear.is_empty() or not gear.all(func(it): return it.req_level >= 70 and it.req_level <= level and it.grade >= 5):
		invalid = true
		push_error("炼狱档常规装备不符合毕业要求：%d %s" % [id, gear])
	var weapon := XTianqiQiyinGear.weapon_of_type(weapon_type)
	var true_weapons := 0
	for eq in a.equip_list():
		var mark := XTianqiQiyinEffects.mark_of(eq)
		if mark.get("kind") == "weapon" and bool(mark.get("true_seal", false)):
			true_weapons += 1
		if D271._changes_dummy_defense(eq) or (mark.get("kind") == "weapon" and mark.get("key") != weapon.get("key")):
			invalid = true
			push_error("炼狱档装备不符合木桩配置：%d %s" % [id, eq.get("name", "")])
	if weapon.is_empty() or true_weapons != 1:
		invalid = true
		push_error("炼狱档应恰有一件合法的真印武器：%d %s" % [id, weapon_type])
	a.set_meta("lianyu_gear", gear)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _lianyu_battle(s: XState, a: XActor, sample_seed: int) -> XBattleLogic:
	seed(sample_seed)
	var logic := XBattleLogic.new()
	logic.setup(_troop(s), s, XBattleRandom.create(XRandomStream.hex64(sample_seed)))
	var e = logic.alive(logic.enemies)[0]
	logic.enemies = [e]
	e.add_param(0, 1.0e9)
	e.param_mark_dirty()
	_pin_def(e)
	# 只屏蔽会重复整套连段的红印效果；不预置黑印层数或上一回合防御。
	XTianqiQiyinEffects.effects(logic, a).erase("extra_hits")
	a.hp = a.mhp
	a.mp = a.mmp
	a.tp = a.max_tp()
	return logic


func _sample_lianyu(snapshot: Dictionary, id: int, sk: Dictionary, sample_seed: int, forced: bool) -> Dictionary:
	# 每次采样都从战前快照还原角色，木桩、状态、熟练度、冷却和战斗随机流逐次隔离。
	var s := XState.from_dict(snapshot.duplicate(true))
	XState._become_current(s)
	var a := s.actor(id)
	var logic := _lianyu_battle(s, a, sample_seed)
	var e = logic.enemies[0]
	var row := {}
	if forced or logic.can_use(a, sk):
		e.hp = e.mhp * _target_hp_rate(a, sk)
		var stats := {"atk": a.atk, "mat": a.mat, "mhp": a.mhp}
		XStateEffects.force_critical = true
		var logs := logic.execute(a, sk, e, true)
		XStateEffects.force_critical = false
		var segs := []
		_collect_hits(logs, e, segs)
		if not segs.is_empty():
			var action_skill: Dictionary = sk
			for log in logs:
				if log is Dictionary and log.get("type") == "action" and is_same(log.get("user"), a):
					action_skill = log.skill
					break
			var total := 0.0
			for damage in segs:
				total += float(damage)
			row = {"actor": id, "input_skill": int(sk.id), "input_name": str(sk.name),
				"skill": int(action_skill.id), "skill_name": str(action_skill.name),
				"segments": segs, "peak": roundi(total), "peak_single": roundi(float(segs.max())),
				"variance": int(action_skill.get("damage", {}).get("variance", 0)),
				"atk": stats.atk, "mat": stats.mat, "mhp": stats.mhp}
	logic.end_battle()
	return row


func _lianyu_cast_peaks(snapshot: Dictionary, id: int, sk: Dictionary, battle_seed: int, forced: bool) -> Dictionary:
	var peaks := {}
	for n in hits:
		var row := _sample_lianyu(snapshot, id, sk, battle_seed + n, forced)
		if row.is_empty():
			continue
		var landing: int = row.skill
		if not peaks.has(landing) or row.peak > peaks[landing].peak:
			peaks[landing] = row
	return peaks


func _measure_lianyu(s: XState, a: XActor, tier: String) -> Dictionary:
	var id := int(a.actor_id)
	var active := XTianqiSecrets.active_ids(a, s)
	var limit := XTianqiSecrets.limit(a, s)
	var learned := a.skill_ids.filter(func(sid): return XTianqiSecrets.occupies_slot(int(sid)))
	if limit != LIANYU_SLOTS[tier] or active.size() != limit or active.size() != learned.size():
		invalid = true
		push_error("D282 炼狱秘籍格不符：%d %s，生效 %d，已学 %d，上限 %d" % [id, tier, active.size(), learned.size(), limit])
	var snapshot := s.to_dict().duplicate(true)
	var battle_seed := 20261117 + id + seed_off
	var logic := _lianyu_battle(s, a, battle_seed)
	var skills := logic.battle_skills(a)
	logic.end_battle()
	var best := {}
	var actual_peaks := []
	for sk in skills:
		var spec := XTianqiSkills.spec(int(sk.id))
		if not XSmartAI.for_opponent(sk) or (not spec.has("damage") and not spec.has("variants")) or spec.has("heal"):
			continue
		var peaks := _lianyu_cast_peaks(snapshot, id, sk, battle_seed, false)
		for row in peaks.values():
			actual_peaks.append(row)
			if best.is_empty() or int(row.peak) > int(best.peak):
				best = row
	if best.is_empty():
		return best
	var diagnostic := []
	for sid in VARIANT_DIAGNOSTICS.get(id, []):
		diagnostic.append_array(_lianyu_cast_peaks(snapshot, id, XDB.rec("Skills", sid), battle_seed, true).values())
	XState._become_current(s)
	var row := best.duplicate()
	row["build"] = _build_desc(a)
	row["brand_mult"] = XTianqiBrand.mult(a, s)
	var mastery := XSkillMastery.level(a, int(row.input_skill))
	mastery_seen = maxi(mastery_seen, mastery)
	row["lianyu"] = {"gear": a.get_meta("lianyu_gear"), "race_rank": int(XRace.data(s, a).rank),
		"mastery": mastery, "mastery_cap": XSkillMastery.max_level(int(row.input_skill)),
		"skill_learned": a.skill_ids.has(int(row.input_skill)), "secret_limit": limit,
		"cast_peaks": actual_peaks, "forced_diagnostics": diagnostic}
	return row


func _measure(id: int, tier: String) -> Dictionary:
	var lianyu := book_build == LIANYU
	var s := _lianyu_state(id) if lianyu else _state(id)
	var actor := s.actor(id)
	var lottery: Array = []
	if book_build in ["normal", "balanced"]:
		lottery = EXTREME.slice(0, 15) + BALANCED_UTILITY
	elif book_build == "extreme":
		lottery = EXTREME
	for sid in lottery:
		actor.learn_skill(int(sid))
	if not lottery.all(func(sid): return actor.skill_ids.has(sid)):
		invalid = true
		push_error("抽奖被动未全部学会：%d" % id)
	actor.param_mark_dirty()
	actor.refresh_passive()
	var row := _measure_lianyu(s, actor, tier) if lianyu else _measure_in(s, actor, tier, true)
	if row.is_empty():
		return row
	row["lottery_count"] = lottery.size()
	row["ledger_violations"] = XTianqiLedger.violations.size()
	return row
