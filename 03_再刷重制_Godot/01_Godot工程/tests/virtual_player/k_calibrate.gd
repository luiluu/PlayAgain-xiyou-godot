extends Node
## 【cc·T082】期四实机标定 K（基础数值重构 v0.4 第九节第 1～3 步）：总开关开着，每人单独对木桩打自己「条件全中后最大的一段」，取暴击里最大的一个伤害数字。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/k_calibrate.tscn -- \
##     [--tier=super|strong|weak|all] [--k=<K，缺省读表>] [--hits=20] [--out=<json>] [--actors=1,2]
##
## 口径（稿第三节第 3 条，能做到的）：
## - 81 级；每栏从原版装备里挑主属性最高的一件（不限品质、不要专属），实例改成 80 级神话（meta req_level 80、quality 14）→ 新底子按表算；
##   本人专属法宝（没有就破攻／尊魔）99 级；技能熟练度拿满（MASTERY 开）；喝天平酒、助力位空、只上这一个人。
## - 木桩：这一场第一个敌人，物防魔防都改成 8200，每下之前回满；强制暴击（XStateEffects.force_critical）。
## - 「这一下」：卡上每个伤害技能各打 hits 次，取最大的一个数；条件全中靠换算——同一下里卡面公式值 v0（XTianqiSkills.formula，含当下的条件）
##   和条件全中的值 v_full（卡面系数×Σ权重×各条件最大倍率，封到档位上限，口径同 天启篇数据校验.py single_hit_effective）都是线性乘在后面所有乘区前面的，
##   所以 峰值 ＝ 量到的数 × v_full ÷ v0。
## - 没做到的（报告里列着，交付单写差多少）：词条掷满挑最大、黑印满配攒五层、真印无视防御、秘籍格、号卷——这几样都进伤害池；烙印 100% 按 ×(1＋max_bonus) 乘在结果上（XTianqiBrand 开关现在关着）。
## 输出：每人一行（技能、量到的最大数、v0、v_full、峰值），再按档位取最大、中位。

const LEVEL := 81
const FABAO := 99
const GENERAL_ATK := 3557
const GENERAL_MAT := 3556
const TROOP := 4  # 缺省敌群；_measure 里会往后找第一个「不是守层者、不是首领」的敌人（天启篇元素牌对它恒中性）
const DEF := 8200.0
const MYTH_QUALITY := "14"

var tier_arg := "super"
var k_arg := -1.0
var hits := 20
var out_path := ""
var only: Array = []
var debug := false
var mastery_seen := 0
var no_mastery := false
var no_fabao := false
var report := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier_arg = a.substr(7)
		elif a.begins_with("--k="):
			k_arg = float(a.substr(4))
		elif a.begins_with("--hits="):
			hits = int(a.substr(7))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--no-fabao":
			no_fabao = true
		elif a == "--no-mastery":
			no_mastery = true
		elif a == "--debug":
			debug = true
		elif a.begins_with("--actors="):
			only = Array(a.substr(9).split(",")).map(func(x): return int(x))
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiSkills.reload()
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	var rules: Dictionary = XTianqiBalance.data().get("combat_rules", {})
	if k_arg > 0.0:
		rules["base_damage"] = k_arg
	report = {"k": float(rules.get("base_damage", 1.0)), "hits": hits, "def": DEF, "rows": [], "tiers": {},
		"brand_max_bonus": float(XTianqiBrand.data().get("power", {}).get("max_bonus", 0.5)),
		"caps": XTianqiSkills.data().get("rules", {}).get("single_hit_cap", {}),
		"missing": ["词条掷满挑最大", "黑印满配攒五层", "真印无视防御", "秘籍格", "号卷", "烙印（按 ×(1＋max_bonus) 乘在结果上）"]}
	var tiers := [XTier.SUPER, XTier.STRONG, XTier.WEAK] if tier_arg == "all" else [{"super": XTier.SUPER, "strong": XTier.STRONG, "weak": XTier.WEAK}[tier_arg]]
	for tier in tiers:
		var peaks := []
		for id in XTianqiSkills.ids(tier, true):
			if not only.is_empty() and not only.has(int(id)):
				continue
			if XImportedBalance.is_disabled_actor(int(id)):
				continue
			var row := _measure(int(id), tier)
			if row.is_empty():
				continue
			row["tier"] = tier
			report.rows.append(row)
			peaks.append(float(row.peak))
			print("K_ROW %s" % JSON.stringify(row))
		peaks.sort()
		if not peaks.is_empty():
			report.tiers[tier] = {"n": peaks.size(), "max": peaks[-1], "median": peaks[peaks.size() / 2],
				"max_brand": peaks[-1] * (1.0 + float(report.brand_max_bonus))}
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	report["mastery_max_level_seen"] = mastery_seen
	print("K_REPORT " + JSON.stringify(report.tiers) + " mastery=" + str(mastery_seen))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " "))
	get_tree().quit.call_deferred(0)


## 条件「成立到最大」的倍率（同 天启篇数据校验.py cond_max）
static func cond_max(c: Dictionary) -> float:
	var i := str(c.get("if", ""))
	if i == "self_mp_frac":
		return minf(1.0, float(c.get("cap", 1.0)))
	var m := 1.0
	if c.has("steps"):
		for st in c.steps:
			m = maxf(m, float(st[1]))
	elif c.has("mult"):
		m = float(c.mult)
	elif c.has("cap"):
		var cap := float(c.cap)
		for v in c.get("cap_with", {}).values():
			cap = maxf(cap, float(v))
		m = 1.0 + cap
	return maxf(1.0, m)


## 条件全中的单段有效系数（不封）
static func eff_full(actor_id: int, sid: int) -> float:
	var d: Dictionary = XTianqiSkills.spec(sid).get("damage", {})
	var m := 1.0
	for c in d.get("conds", []):
		m *= cond_max(c)
	for c in XTianqiSkills.data().get("actors", {}).get(str(actor_id), {}).get("conds", []):
		if c.has("skills") and not (c.skills as Array).any(func(x): return int(x) == sid):
			continue
		m *= cond_max(c)
	return float(d.get("coef", 0.0)) * XTianqiSkills.hit_weight(d) * m


func _state(id: int) -> XState:
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), id, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [id]}
	s.random_master = XRandomStream.hex64(20261117 + id)
	seed(20261117 + id)
	s.set_variable(20, 36)
	s.actor_max_level = LEVEL
	XTianqiSkills.MASTERY = true  # 翻开关后熟练度和总开关一起开（稿第七节第 2 条）；开局流程会把它拨回默认值，这里再置一次
	XState.current = s  # 熟练度上限（XTianqiSkills.mastery_on）、装备读表都看当前存档
	if not s.party.has(id):
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	for i in 5:
		s.set_battle_slot(i, id if i == 0 else 0)
	var a := s.actor(id)
	a.change_level_mv(LEVEL)
	_dress(a)
	var fid := _own_fabao(id)
	if fid == 0:
		fid = GENERAL_ATK if a.param(2) >= a.param(4) else GENERAL_MAT
	var item := XGear.template("armor", fid)
	item.level = float(mini(FABAO, int(XMagicWeapon.max_level(item))))
	var slot := a.equip_slots().find(int(item.etypeId))
	if slot >= 0 and not no_fabao:
		a.equips[slot] = item
	for sid in (a.skill_ids if not no_mastery else []):
		XSkillMastery.set_level(a, int(sid), XSkillMastery.max_level(int(sid)))
	if debug:
		print("K_DEBUG mastery_on=%s M=%s on=%s active=%s max=%d" % [XTianqiSkills.mastery_on(), XTianqiSkills.MASTERY, XTianqiSkills.on(), XTianqi.active(s), XSkillMastery.max_level(5703)])
	if debug:
		for q in a.equips.size():
			var it = a.equips[q]
			if it is Dictionary and not it.is_empty():
				print("K_DEBUG equip %d %s %s lv=%s q=%s eff=%s" % [q, it.get("id"), it.get("name"), it.get("level", ""), it.get("meta", {}).get("quality", ""), XTianqiGear.effective_params(it) if XTianqiGear.applies(it) else it.get("params")])
		a.param_mark_dirty()
		print("K_DEBUG layers native=%s rate=%s buff=%s plus=%s before_alien=%s gear_in=%s" % [a.param_native(4), a.param_rate(4), a.param_buff_rate(4), a.param_plus(4), a.param_before_alien(4), XActorModules.param(a, 4, XPercentPills.param(a, 4, a.param_native(4)))])
		for o in a.trait_objects():
			for t in (o.get("traits", []) if o is Dictionary else []):
				if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 4 and float(t.get("value", 1.0)) != 1.0:
					print("K_DEBUG mat-rate %s %s %s" % [o.get("id"), o.get("name"), t.value])
		print("K_DEBUG params %s base=%s" % [[a.param(0), a.param(2), a.param(4)], [a.param_base(2) if a.has_method("param_base") else "", a.param_base(4) if a.has_method("param_base") else ""]])
	mastery_seen = maxi(mastery_seen, XSkillMastery.max_level(int(a.skill_ids[0])) if not a.skill_ids.is_empty() else 0)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	XState.current = s
	return s


static var _own := {}
static func _own_fabao(actor_id: int) -> int:
	if _own.is_empty():
		for r in XDB.table("Armors"):
			if r is Dictionary and r.get("meta", {}).has("Magic Weapon") and r.meta.has("req_actors"):
				for x in str(r.meta.req_actors).split(","):
					if str(x).strip_edges().is_valid_int() and not _own.has(int(str(x).strip_edges())):
						_own[int(str(x).strip_edges())] = int(r.id)
		_own[-1] = 0
	return int(_own.get(actor_id, 0))


## 每栏挑原版主属性最高的一件（不限品质、不要专属、不要法宝），改成 80 级神话
static var _pool := {}
static func _dress(a: XActor) -> void:
	var slots := a.equip_slots()
	var physical := a.param(2) >= a.param(4)
	for i in slots.size():
		var et := int(slots[i])
		if et == 13 or not XTianqiGear.open_type(et):
			continue
		if not _pool.has(et):
			var list := []
			for rec in XDB.table("Weapons" if et == 1 else "Armors"):
				if not rec is Dictionary or str(rec.get("name", "")) == "" or (et != 1 and int(rec.get("etypeId", 0)) != et):
					continue
				var m: Dictionary = rec.get("meta", {})
				if m.has("Magic Weapon") or m.has("req_actors") or not str(m.get("quality", "")).strip_edges().is_valid_int():
					continue
				list.append(rec)
			_pool[et] = list
		var best := {}
		var best_score := -1.0
		for rec in _pool[et]:
			var item := XGear.template("weapon" if et == 1 else "armor", int(rec.id))
			item.meta = (item.get("meta", {}) as Dictionary).duplicate()
			item.meta["req_level"] = "80"
			item.meta["quality"] = MYTH_QUALITY
			if not a.can_equip(item) or not XTianqiGear.applies(item):
				continue
			var p := XTianqiGear.effective_params(item)
			var score := float(p[2] if physical else p[4]) + float(p[0]) / 100.0
			if score > best_score:
				best_score = score
				best = item
		if not best.is_empty():
			best["instanceId"] = "k_%d_%d" % [int(a.actor_id), i]
			a.equips[i] = best


func _measure(id: int, tier: String) -> Dictionary:
	var s := _state(id)
	var a := s.actor(id)
	var cap := float(XTianqiSkills.data().get("rules", {}).get("single_hit_cap", {}).get(tier, 0.0))
	var logic := XBattleLogic.new()
	logic.setup(_troop(s), s, XBattleRandom.create(str(s.random_master)))
	var foes: Array = logic.alive(logic.enemies)
	if foes.is_empty():
		return {}
	var e = foes[0]
	e.add_param(0, 1.0e9)
	e.param_mark_dirty()
	if XTianqiElements.enemy_profile(e, logic, s).get("source", "") != "":
		push_error("K 木桩 %d 不是元素中性（%s）" % [int(e.enemy_id), XTianqiElements.enemy_profile(e, logic, s)])
	var best := {}
	for sid in a.skill_ids:
		var sp := XTianqiSkills.spec(int(sid))
		if not sp.has("damage") or sp.has("heal"):
			continue
		var sk := XDB.rec("Skills", int(sid))
		if sk.is_empty() or not XSmartAI.for_opponent(sk):
			continue
		var full := minf(eff_full(id, int(sid)), cap) if cap > 0.0 else eff_full(id, int(sid))
		var d: Dictionary = sp.damage
		var w := XTianqiSkills.hit_weight(d)
		for n in hits:
			_pin_def(e)
			e.hp = e.mhp
			a.hp = a.mhp
			a.mp = a.mmp
			a.tp = a.max_tp()
			XStateEffects.force_critical = true
			var v0 := absf(XTianqiSkills.formula(a, e, sk))
			if debug and n == 0:
				print("K_DEBUG foe def=%s mdf=%s pdr=%s mdr=%s el=%s" % [e.def, e.mdf, e.pdr, e.mdr, [e.element_rate(1), e.element_rate(2), e.element_rate(3), e.element_rate(4)]])
				var calc: Dictionary = logic._calculate_damage(a, sk, e, true)
				print("K_DEBUG %d %s" % [int(sid), JSON.stringify({"value": calc.get("value"), "row": calc.get("breakdown", {}).get("row", {})})])
				var bs: Dictionary = a.passive_cache().get("bySource", {})
				for o in a.stat_equips() + a.skills() + a.states():
					var sc := XActor._note_scans(str(o.get("note", "")))
					if not (sc[4] as Array).is_empty() or not (sc[5] as Array).is_empty():
						print("K_DEBUG obj %s %s fin=%s crit=%s bucket=%s new=%s" % [o.get("id"), o.get("name"), sc[4], sc[5], XTianqiLedger.bucket_of(o, a), o.get("_tianqi_new")])
				print("K_DEBUG passive crit=%s fin=%s bySource crit=%s fin=%s" % [a.passive_cache().get("critHarmRi"), a.passive_cache().get("globalHarmRi"), bs.get("critHarmRi"), bs.get("globalHarmRi")])
				for t in calc.get("moduleTrace", []):
					var ops := (t.get("ops", []) as Array).filter(func(o): return o is Dictionary and str(o.get("field", "")) in ["criticalAdd", "finalAdd", "normalAdd", "finalMultiplier", "skillMultiplier"])
					if not ops.is_empty():
						print("K_DEBUG trace %s %s" % [t.get("module", t.get("id", "?")), JSON.stringify(ops)])
			var r: Dictionary = logic.apply(a, sk, e)
			var dealt := float(r.get("shown", {}).get("hp", r.get("hp", 0.0)))  # 跳出来的那一个数（木桩生命有上限，不能用掉血量）
			XStateEffects.force_critical = false
			if v0 <= 0.0 or dealt <= 0.0:
				continue
			# v_full：同一个基数（Σ属性×权重 × 等级缩放）乘「条件全中、封到上限」的系数 full÷w
			var base_lv := v0 / maxf(1e-9, _coef_now(a, e, d, int(sid)))
			var v_full := base_lv * full / maxf(1e-9, w)
			var peak := dealt * v_full / v0
			if best.is_empty() or peak > float(best.peak):
				best = {"actor": id, "skill": int(sid), "dealt": dealt, "v0": v0, "v_full": v_full, "eff_full": eff_full(id, int(sid)),
					"cap": cap, "peak": roundf(peak), "formula": str(sk.get("damage", {}).get("formula", "")).left(60), "repeats": int(sk.get("repeats", 1)), "atk": a.param(2), "mat": a.param(4), "mhp": a.mhp}
	logic.end_battle(0)
	return best


## 木桩物防魔防钉到 DEF：敌人的防御要乘难度、首领、天启篇楼层等倍率（还会在第一下时才挂上开战状态），
## 所以每一下之前按「当前值÷加值前」反推加值，迭代到差 <1。v1 只在开场加一次差值：第一招打的是防御 46，后面是 1.2～1.5 万（T082 v1 的 153、163 两例）。
static func _pin_def(e) -> void:
	for i in [3, 5]:
		for _n in 6:
			e.param_mark_dirty()
			e.param_refresh()  # 战斗中读的是能力值缓存格，标脏后要 refresh 才清
			var cur := float(e.param(i))
			if absf(cur - DEF) < 1.0:
				break
			var plus := float(e.added_params.get(i, 0.0))
			var raw := float(e.param_base_unscaled(i)) + plus
			var f := cur / raw if raw > 0.0 and cur > 0.0 else 1.0
			e.add_param(i, (DEF - cur) / maxf(1e-6, f))
	e.param_mark_dirty()
	e.param_refresh()


## 木桩敌群：从 TROOP 往后找第一个首个敌人不是守层者、不是首领的（元素牌对它恒中性，稿第九节第 1 条「元素中性」）
static var _troop_id := 0
static func _troop(s) -> int:
	if _troop_id > 0:
		return _troop_id
	for t in range(TROOP, TROOP + 400):
		var tr := XDB.rec("Troops", t)
		if tr.is_empty() or (tr.get("members", []) as Array).is_empty():
			continue
		var eid := int(tr.members[0].get("enemyId", 0))
		if eid <= 0 or XGuardianRework.floor_of(eid) > 0 or XEnemy.boss_id(eid):
			continue
		_troop_id = t
		return t
	return TROOP


## 这一下卡面系数×当下条件（不含属性基数和等级缩放）：formula 的 v0 ÷ 它 ＝ 基数×等级缩放
func _coef_now(a, e, d: Dictionary, sid: int) -> float:
	var m := float(d.get("coef", 0.0))
	XTianqiSkills._cur_skill = sid
	for c in d.get("conds", []):
		m *= XTianqiSkills._cond(c, a, e)
	for c in XTianqiSkills.data().get("actors", {}).get(str(int(a.actor_id)), {}).get("conds", []):
		m *= XTianqiSkills._cond(c, a, e)
	var cap := XTianqiBase.single_hit_cap(a)
	var w := XTianqiSkills.hit_weight(d)
	if cap > 0.0 and m * w > cap:
		m = cap / w
	return m
