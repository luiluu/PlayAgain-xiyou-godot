extends "res://tests/virtual_player/k_calibrate.gd"
## T445：沿用 K 探针的养成与木桩，显式装书；--t444 重跑第二批之前的狗逍遥核算。
## godot --headless --audio-driver Dummy --path <工程> res://tests/virtual_player/t445_book_probe.tscn --
##   --tier=all --actors=95,122,163,167,1,2,22,3,12,18 --book-build=normal --noisy --seed=1
## --book-build=normal|empty|balanced|extreme|lianyu|zhengdao；T444 单段重量用 --t444 --single --actors=1。
## lianyu：D281，T438 炼狱 C 模板的单人输出配法，只装有效秘籍格内的书（D282 8/6/5）。
## zhengdao：T488，T438 证道 D 模板满配（Lv81、100% 熟练度/烙印、3 槽极品词条、D282 9/7/6 秘籍格、0 抽奖书），与 lianyu 同口径。
## --t488-proposal：T488 开关式试改（默认关闭，仅内存覆写，不改正式数据表；供 Kyo 拍板前量数验证）。
## --noisy --seed=101/202/303 为随机样本；不带 --noisy 跑确定值。JSON 输出可加 --out=<路径>。

const D271 := preload("res://tests/virtual_player/t438_d271_benchmark.gd")
const LIANYU := "lianyu"
const ZHENGDAO := "zhengdao"
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
const ZHENGDAO_SLOTS := {XTier.SUPER: 6, XTier.STRONG: 7, XTier.WEAK: 9}
# D282：先装本角色主系、通用增伤，再以体能和资源类补足。每本都经运行时占格校验。
# T488（修 T471 R2 P2-4）：对齐 5 名角色主系元素秘籍（122 巨龙物理、167 黑龙黑暗、
# 2 绿司机因 2476 风龙原表误写 passiveELUP05 雷电，改用自然秘籍 2780 《御风决·真》、
# 3 艾坤恶龙大地、18 雪清寒九头龙寒冰；12 斯盖主系物理前置）。
const LIANYU_SECRETS := {
	95: [2471, 2480, 6139, 6159, 488], 122: [2471, 2480, 6139, 6159, 489],
	163: [2471, 2480, 6139, 6159, 488], 167: [2479, 2480, 6139, 6159, 489],
	1: [2471, 2480, 6139, 6159, 488, 489], 2: [2780, 2480, 6139, 6159, 488, 489],
	22: [2471, 2480, 6139, 6159, 488, 489],
	# T496：其余 14 名超强者按自然体质（actor_nature.json）配主系书，无属性者走 2471 物理（与 95/163 同口径）；
	# 奥术 2477 原表误标雷电，奈叶改用 2782 《虚空经·真》（与绿司机 2780 同类）。
	168: [2472, 2480, 6139, 6159, 488], 173: [2471, 2480, 6139, 6159, 488],
	172: [2471, 2480, 6139, 6159, 488], 11: [2471, 2480, 6139, 6159, 488],
	180: [2471, 2480, 6139, 6159, 489], 152: [2471, 2480, 6139, 6159, 488],
	175: [2780, 2480, 6139, 6159, 489], 108: [2782, 2480, 6139, 6159, 489],
	171: [2471, 2480, 6139, 6159, 488], 176: [2471, 2480, 6139, 6159, 488],
	177: [2471, 2480, 6139, 6159, 489], 169: [2475, 2480, 6139, 6159, 488],
	107: [2471, 2480, 6139, 6159, 488], 179: [2472, 2480, 6139, 6159, 488],
	3: [2474, 2480, 6139, 6159, 488, 489, 490, 2471],
	12: [2471, 2480, 6139, 6159, 488, 489, 490, 2472],
	18: [2473, 2480, 6139, 6159, 488, 489, 490, 2471],
}
# D282 证道比炼狱三档各多 1 格（6/7/9），追加通用增伤秘籍 2756 苍天在上（爆伤+7%、终伤+7%）。
const ZHENGDAO_EXTRA_SECRET := 2756
# 依角色主招要求或招牌武器选类。无武器要求的纯法系走法杖。
const LIANYU_WEAPONS := {
	95: "katana", 122: "katana", 163: "fist", 167: "staff",
	1: "sword", 2: "staff", 22: "fist", 3: "staff", 12: "sword", 18: "sword",
	# T496：其余超强者；里德招式限斧/矛、黄泉限太刀、流萤限剑，其余按主属性（魔攻走法杖）。
	168: "sword", 173: "fist", 172: "katana", 11: "axe", 180: "staff", 152: "sword", 175: "sword",
	108: "staff", 171: "sword", 176: "sword", 177: "staff", 169: "katana", 107: "spear", 179: "sword",
}
# 同一木桩下强制量这些核查点，只用于定位；正常样本通过出招菜单触发变招。
const VARIANT_DIAGNOSTICS := {1: [4749], 2: [4759, 4760], 22: [3776]}
# T488 方案 A（维持 Kyo 原定档位倍率 1.0/1.5/2.5，收拢三档主招总系数范围与同档离群；全整数系数）。
# 仅在显式传入 --t488-proposal 时于内存覆写，不写入正式表，待 Kyo 拍板后再另开实现卡。
const T488_PROPOSAL_SKILLS := {
	# 超强者（等效总系数收拢至 8～11，含血量折算与常态余响；D209 次序：渡鸦第 1 > 拳一第 3 > 三笠第 11 > 狂刀第 15）
	9938: {"damage": {"stats": {"atk": 2, "mhp": 0.01}, "coef": 1}},
	9939: {"seq": [{"op": "keep_effects", "n": 4}]},
	10731: {"damage": {"stats": {"atk": 2, "mat": 1, "mhp": 0.01}, "coef": 1}},
	10729: {"damage": {"stats": {"atk": 1}, "coef": 2}},
	6026: {"damage": {"stats": {"atk": 4, "mhp": 0}, "coef": 1}},
	6027: {"damage": {"stats": {"atk": 1}, "coef": 5}},
	10125: {"damage": {"stats": {"mat": 1, "mhp": 0.01}, "coef": 1}, "seq": [{"op": "split_effects", "n": 4}]},
	# 强者（输出 9～12、辅助 8～9；维利九段拆每段 1，绿司机升档去小数 0.63，狗逍遥破魂对齐 12）
	4749: {"damage": {"stats": {"atk": 1}, "coef": 6}},
	3768: {"damage": {"stats": {"atk": 1}, "coef": 10}},
	3769: {"damage": {"stats": {"atk": 1}, "coef": 5}},
	3770: {"damage": {"stats": {"atk": 1}, "coef": 3}},
	3771: {"damage": {"stats": {"atk": 1}, "coef": 2}},
	3772: {"damage": {"stats": {"atk": 1}, "coef": 2}},
	3773: {"damage": {"stats": {"atk": 1}, "coef": 2}},
	3774: {"damage": {"stats": {"atk": 1}, "coef": 1}},
	3775: {"damage": {"stats": {"atk": 1}, "coef": 1}},
	3776: {"damage": {"stats": {"atk": 1}, "coef": 1}},
	3777: {"damage": {"stats": {"atk": 1}, "coef": 1}},
	504: {"damage": {"stats": {"mat": 1}, "coef": 9}},
	4755: {"damage": {"stats": {"mat": 1}, "coef": 9}},
	4757: {"damage": {"stats": {"mat": 1}, "coef": 9}},
	4759: {"damage": {"stats": {"mat": 1}, "coef": 9}},
	4756: {"damage": {"stats": {"mat": 1, "mmp": 0}, "coef": 1}},
	4758: {"damage": {"stats": {"mat": 1}, "coef": 1}},
	4760: {"damage": {"stats": {"mat": 1}, "coef": 1}},
	# 弱者（8～10：艾坤大灌篮 3×2=6 → 3×3=9 拉齐同档）
	506: {"damage": {"stats": {"mat": 1}, "coef": 3}},
}

var book_build := "normal"
var historical := false
var t488_proposal := false
var _t488_applied := false
var invalid := false
var _prime_forced := false
var k_scan := false  # T496：--k-scan 炼狱/证道配装不变，改用 K 探针 _measure_in（D209 量法：公式条件全中＋整次施放段数比）对照


func _is_d271_build() -> bool:
	return book_build in [LIANYU, ZHENGDAO]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--book-build="):
			book_build = arg.trim_prefix("--book-build=")
		elif arg == "--t444":
			historical = true
		elif arg == "--t488-proposal":
			t488_proposal = true
		elif arg == "--k-scan":
			k_scan = true
		elif arg == "--no-d287":  # T496：关掉 D287 收拢覆盖层（改前对照）；k_calibrate 也会读到同一开关
			XTianqiBase.TUNE_D287 = false
			XTianqiSkills.reload_table()
	if book_build not in ["normal", "empty", "balanced", "extreme", LIANYU, ZHENGDAO]:
		push_error("未知量数配法：" + book_build)
		get_tree().quit(2)
		return
	if _is_d271_build() and (historical or not OS.get_cmdline_user_args().has("--noisy") or OS.get_cmdline_user_args().has("--single")):
		push_error("炼狱/证道实战档使用 --noisy 实测整次施放")
		get_tree().quit(2)
		return
	super._ready()


func _ensure_t488_proposal() -> void:
	if not t488_proposal or _t488_applied:
		return
	var data := XTianqiSkills.data()
	var skills_map: Dictionary = data.get("skills", {})
	for sid in T488_PROPOSAL_SKILLS:
		var k := str(sid)
		var cur = XTianqiSkills._skills.get(int(sid), {})
		var merged := XTianqiSkills.tune_merge(cur if cur is Dictionary else {}, T488_PROPOSAL_SKILLS[sid])
		XTianqiSkills._skills[int(sid)] = merged
		skills_map[k] = merged
	XTianqiSkills._recs.clear()
	_t488_applied = true


func _run() -> void:
	XTianqiLedger.violations.clear()
	_t488_applied = false
	if _is_d271_build():
		level = D271.floor_level_cap(LIANYU_FLOOR)
		gear_level = level - 1
		fabao_level = FABAO
		brand_pct = 100.0 if book_build == ZHENGDAO else 75.0
		if only.is_empty():
			only = NORMAL_SECRETS.keys()
			tier_arg = "all"
	if historical:
		XTianqiGeneralBooks.data()
		for sid in XTianqiGeneralBooks.data().get("groups", {}).get("remaining_books", []):
			XTianqiGeneralBooks._skills.erase(int(sid))
	super._run()
	report["t488_proposal"] = t488_proposal
	print("BOOK_PROBE " + JSON.stringify({"build": book_build, "historical": historical, "t488_proposal": t488_proposal,
		"violations": XTianqiLedger.violations.size(), "invalid": invalid, "rows": report.rows.size()}))
	if invalid or not XTianqiLedger.violations.is_empty() or (not only.is_empty() and report.rows.size() != only.size()):
		get_tree().quit.call_deferred(1)


func _secret_loadout(actor_id: int) -> Array:
	if book_build == LIANYU:
		return LIANYU_SECRETS.get(actor_id, []).duplicate()
	if book_build == ZHENGDAO:
		var list: Array = LIANYU_SECRETS.get(actor_id, []).duplicate()
		list.append(ZHENGDAO_EXTRA_SECRET)
		return list
	return NORMAL_SECRETS.get(actor_id, []).duplicate()


func _secrets(a: XActor) -> void:
	if historical:
		super._secrets(a)
		return
	var loadout := _secret_loadout(a.actor_id)
	for sid in loadout:
		a.learn_skill(int(sid))
	var slots := XTianqiSecrets.active_ids(a)
	var limit := XTianqiSecrets.limit(a)
	if slots.size() != loadout.size() or slots.size() > limit or not loadout.all(func(sid): return slots.has(sid)):
		invalid = true
		push_error("实战配置秘籍异常：%d %s / %s，上限 %d" % [a.actor_id, slots, loadout, limit])
	a.set_meta("k_secrets", slots)


func _lianyu_state(id: int) -> XState:
	var diff := ZHENGDAO if book_build == ZHENGDAO else LIANYU
	var tpl := "D" if book_build == ZHENGDAO else "C"
	var s := XState.new_game(XTianqi.legacy_of(diff), id, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": diff, "lineup": [id]}
	var battle_seed := 20261117 + id + seed_off
	s.random_master = XRandomStream.hex64(battle_seed)
	seed(battle_seed)
	s.set_variable(20, LIANYU_FLOOR)
	# T488 R2（修 P2-4）：按 skill_rework.json tiers.growth["95"]（锻炼 var 1490=10 且 4 阶进阶完成 → 超强者），
	# 炼狱 80% / 证道满配统一按已完成自身超强者成长态测算（与 --t488-proposal 无关，基线与改后同口径）。
	if id == 95:
		s.set_variable(1490, 10)
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
	D271._apply_advance(s, a, tpl)
	var rng := RandomNumberGenerator.new()
	rng.seed = battle_seed + 31337
	var qstream := XRandomStream.create(XRandomStream.hex64(battle_seed + 99991), "rule")
	var preset := D271.new()
	var weapon_type := _weapon_for(a)
	var gear := preset._equip_actor(s, a, tpl, diff, DAMAGE_ROLE, LIANYU_FLOOR, level, rng, qstream, weapon_type)
	preset._equip_fabao_mount_artifact(s, a, tpl, DAMAGE_ROLE, 0, false, rng)
	_secrets(a)
	preset._apply_growth(s, a, tpl, DAMAGE_ROLE, false)
	preset.free()
	if gear.is_empty() or not gear.all(func(it): return it.req_level >= 70 and it.req_level <= level and it.grade >= 5):
		invalid = true
		push_error("炼狱/证道档常规装备不符合毕业要求：%d %s" % [id, gear])
	var weapon := XTianqiQiyinGear.weapon_of_type(weapon_type)
	var true_weapons := 0
	for eq in a.equip_list():
		var mark := XTianqiQiyinEffects.mark_of(eq)
		if mark.get("kind") == "weapon" and bool(mark.get("true_seal", false)):
			true_weapons += 1
		if D271._changes_dummy_defense(eq) or (mark.get("kind") == "weapon" and mark.get("key") != weapon.get("key")):
			invalid = true
			push_error("炼狱/证道档装备不符合木桩配置：%d %s" % [id, eq.get("name", "")])
	if weapon.is_empty() or true_weapons != 1:
		invalid = true
		push_error("炼狱/证道档应恰有一件合法的真印武器：%d %s" % [id, weapon_type])
	a.set_meta("lianyu_gear", gear)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


## T496：首选 LIANYU_WEAPONS；角色装不了这类（职业 51 号特性）时，按主属性取第一种能装的（魔攻高走法杖／书）。
func _weapon_for(a: XActor) -> String:
	var want := str(LIANYU_WEAPONS.get(int(a.actor_id), ""))
	var wtypes := a.traits_set(51)
	var keys := []
	for t in XTianqiQiyinGear.weapon_types():
		if wtypes.has(int(t.get("wtype_id", -1))):
			keys.append(str(t.get("key", "")))
	if want == "" or keys.has(want) or keys.is_empty():
		return want
	var magic := a.param(4) > a.param(2)
	for k in keys:
		if magic == (k in ["staff", "book"]):
			return k
	return str(keys[0])


func _lianyu_battle(s: XState, a: XActor, sample_seed: int) -> XBattleLogic:
	seed(sample_seed)
	var logic := XBattleLogic.new()
	logic.setup(_troop(s), s, XBattleRandom.create(XRandomStream.hex64(sample_seed)))
	var e = logic.alive(logic.enemies)[0]
	logic.enemies = [e]
	e.add_param(0, 1.0e9)
	e.param_mark_dirty()
	_pin_def(e)
	# T488 R2（修 P2-2）：对称屏蔽全部武器流派效果（mark:/true:/unique:，涵盖红印连击递增与追段、
	# 黑印单动+50%与无视防御、震印落星/陨月、灰印斩杀等），只保留武器白字面板与词条，确保四类武器单次木桩同起跑线。
	var qfx := XTianqiQiyinEffects.effects(logic, a)
	for k in qfx.keys():
		var fx = qfx[k]
		var src := str(fx.get("src", "")) if fx is Dictionary else ""
		if src.begins_with("mark:") or src.begins_with("true:") or src.begins_with("unique:"):
			qfx.erase(k)
	# T488 R2（修 P2-5）：单人木桩无队友导致 122 狂刀 6040 孤世独行（开战状态 1834）必然触发，
	# 而 4 人实战基本不触发；改在探针里移除状态 1834（基线与方案 A 同口径），不动正式表被动。
	if a.state_ids.has(1834):
		a.remove_state(1834)
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
		if forced and _prime_forced:
			# T496：超强者改写招强制量＝条件全中（五条悟苍赫印满 3 对；宿傩看破三层转终式），与 K 探针 _prime 同口径
			_prime(logic, a, e, sk)
			if XMira.own(a) and int(sk.get("id", 0)) >= 10148 and int(sk.get("id", 0)) <= 10152 and not a.state_ids.has(2592):
				a.add_state(2592)  # 米拉黑龙技要黑龙形态（XMira：重制以状态 2592 代替）
			if XSukuna.own(a) and XSukuna.PRIMARY.has(int(sk.get("id", 0))):
				XSukuna._layers(logic, e, 3)
		var stats := {"atk": a.atk, "mat": a.mat, "mhp": a.mhp}
		XStateEffects.force_critical = true
		var logs := logic.execute(a, sk, e, true)
		XStateEffects.force_critical = false
		XSukuna.cast = {}
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
	var base := {}  # T496：每个落地招「段数最少的那几次」里的最大值＝不含随机再放（如流萤天火 10% 再放）的一次施放（T488 预算口径不含随机再放）
	for n in hits:
		var row := _sample_lianyu(snapshot, id, sk, battle_seed + n, forced)
		if row.is_empty():
			continue
		var landing: int = row.skill
		if not peaks.has(landing) or row.peak > peaks[landing].peak:
			peaks[landing] = row
		var nseg: int = (row.segments as Array).size()
		if not base.has(landing) or nseg < int(base[landing].n) or (nseg == int(base[landing].n) and int(row.peak) > int(base[landing].peak)):
			base[landing] = {"n": nseg, "peak": int(row.peak)}
	for landing in peaks:
		peaks[landing]["peak_base"] = int(base[landing].peak)
		peaks[landing]["segs_base"] = int(base[landing].n)
	return peaks


func _measure_lianyu(s: XState, a: XActor, tier: String) -> Dictionary:
	var id := int(a.actor_id)
	var active := XTianqiSecrets.active_ids(a, s)
	var limit := XTianqiSecrets.limit(a, s)
	var learned := a.skill_ids.filter(func(sid): return XTianqiSecrets.occupies_slot(int(sid)))
	var expected_slots: Dictionary = ZHENGDAO_SLOTS if book_build == ZHENGDAO else LIANYU_SLOTS
	if limit != expected_slots[tier] or active.size() != limit or active.size() != learned.size():
		invalid = true
		push_error("D282 %s 秘籍格不符：%d %s，生效 %d，已学 %d，上限 %d" % [book_build, id, tier, active.size(), learned.size(), limit])
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
	# T496：超强者另把本角色全部改写伤害招（含屠苏武器招、五条悟茈）强制各量一遍（条件全中），量「主招」在炼狱 80% 的峰值，
	# 补上单人木桩开场放不出来的形态／资源招；记 forced_main，与自然出招的 best 取大作为该角色峰值。谷雨走储备终结（K 探针同口径）。
	var forced_main := []
	if tier == XTier.SUPER:
		if XGuyu.own(a):
			var gs := XState.from_dict(snapshot.duplicate(true))
			XState._become_current(gs)
			var ga := gs.actor(id)
			var glogic := _lianyu_battle(gs, ga, battle_seed)
			var g := _measure_guyu(gs, ga, glogic, glogic.enemies[0])
			glogic.end_battle()
			if not g.is_empty():
				var grow := {"actor": id, "input_skill": int(g.skill), "input_name": "储备终结", "skill": int(g.skill),
					"skill_name": "储备终结", "segments": [g.peak], "peak": int(g.peak), "peak_single": int(g.peak), "variance": 0,
					"atk": ga.atk, "mat": ga.mat, "mhp": ga.mhp, "forced": true}
				forced_main.append(grow)
		var natural := actual_peaks.map(func(x): return int(x.input_skill))  # 自然出招量到了的才跳过（放不出来的照样强制量）
		var ids := []
		for k in XTianqiSkills.data().get("skills", {}):
			var rec = XTianqiSkills.data().skills[k]
			if rec is Dictionary and int(rec.get("actor", -1)) == id and (rec.has("damage") or rec.has("gojo_pairs")) and not rec.has("heal"):
				ids.append(int(k))
		if XTusu.is_tusu(a):
			for w in XTusu.ARM_OF:
				for k in XTusu.ARM_OF[w]:
					var tsid := XTusu.skill_id(str(k))
					if tsid > 0 and not ids.has(tsid):
						ids.append(tsid)
		_prime_forced = true
		for sid in ids:
			if natural.has(sid) and not (XSukuna.own(a) and XSukuna.PRIMARY.has(sid)):  # 宿傩主招另挂看破三层再量一遍（终式）
				continue
			var rec := XDB.rec("Skills", sid)
			if rec.is_empty() or not XSmartAI.for_opponent(rec):
				print("T496_FORCED_SKIP %d %d empty=%s" % [id, sid, rec.is_empty()])
				continue
			var fpeaks := _lianyu_cast_peaks(snapshot, id, rec, battle_seed, true)
			if fpeaks.is_empty():
				print("T496_FORCED_NOHIT %d %d" % [id, sid])
			for prow in fpeaks.values():
				prow["forced"] = true
				forced_main.append(prow)
		_prime_forced = false
		for prow in forced_main:
			if best.is_empty() or int(prow.peak) > int(best.peak):
				best = prow
	if best.is_empty():
		return best
	var diagnostic := []
	for sid in VARIANT_DIAGNOSTICS.get(id, []):
		diagnostic.append_array(_lianyu_cast_peaks(snapshot, id, XDB.rec("Skills", sid), battle_seed, true).values())
	XState._become_current(s)
	var row := best.duplicate()
	row["build"] = _build_desc(a)
	row["brand_mult"] = XTianqiBrand.mult(a, s)
	row["battle_tier"] = XTianqiSkills.battle_tier(a, s)
	var mastery := XSkillMastery.level(a, int(row.input_skill))
	mastery_seen = maxi(mastery_seen, mastery)
	row["lianyu"] = {"gear": a.get_meta("lianyu_gear"), "race_rank": int(XRace.data(s, a).rank),
		"mastery": mastery, "mastery_cap": XSkillMastery.max_level(int(row.input_skill)),
		"skill_learned": a.skill_ids.has(int(row.input_skill)), "secret_limit": limit,
		"cast_peaks": actual_peaks, "forced_diagnostics": diagnostic, "forced_main": forced_main}
	return row


func _measure(id: int, tier: String) -> Dictionary:
	_ensure_t488_proposal()
	var d271 := _is_d271_build()
	var s := _lianyu_state(id) if d271 else _state(id)
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
	var row := {}
	if d271 and k_scan:
		var ka := s.actor(int(actor.actor_id))
		ka.hp = ka.mhp
		row = _measure_in(s, ka, tier, false)
		if not row.is_empty():
			row["k_scan"] = true
	else:
		row = _measure_lianyu(s, actor, tier) if d271 else _measure_in(s, actor, tier, true)
	if row.is_empty():
		return row
	row["lottery_count"] = lottery.size()
	row["ledger_violations"] = XTianqiLedger.violations.size()
	return row
