extends Node
## T293 战斗提速专项：天启篇三个伤害钩子（七印、词条、号卷）的 is_attack 用到才问（各自 LAZY_ATTACK），
## 角色普攻号在只读窗口里按角色记一次（XBattler.ATTACK_ID_MEMO）。
## 一、钩子逐项一致：每一印（全套＋武器）、带技能伤／首击／元素伤词条、学了一号号卷，各角色 × 各敌人 × 各伤害技＋普攻（双向），
##    窗口里、窗口外，开关开／关的 damage_ops 逐项相同。
## 二、普攻号记忆：替换普攻的武器（1109→1004）、状态（66→562）、五条悟角色备注，窗口里与即时查相同、第二次命中记忆；
##    窗口没关时加状态／去状态／换武器当场换代，读到新值；开关关掉不记。
## 三、整场同种子逐位一致：天启篇（穿七印＋词条＋号卷、替换普攻武器、中途挂替换普攻状态）与西游档各跑几回合，
##    开关全开与全关的每回合日志、HP／MP／TP、状态、随机流逐位相同；全开重跑一次也相同。
## 四、性能（只打印，交付单抄）：窗口里三个钩子、capture 单次，4v5 一次智能选招，开关开／关各量一次。
## 五（T296 补 T293 核查 P3-1）：词条钩子不带「技能伤害」时不问 is_attack 那一支、七印封技普攻（失魄封技＋默印真印）那一支开关前后一致；
##    五条悟普攻号显式是 10634；命运编织者 94 穿命运骰子（4521）的天启篇整场开关全开／全关逐位一致。
##    性能另量 XAlienBattle.FRAME_TOUCH_LAZY（T296：公式帧进出只在改得了读法时作废只读窗口）开／关的 calculate 与 4v5 选招。
const BIG_HP := 1e12
var results := []


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261120)
	XTianqiSkills.reload_table()
	_check("defaults_on", XBattler.ATTACK_ID_MEMO and XTianqiQiyinEffects.LAZY_ATTACK and XTianqiAffixBattle.LAZY_ATTACK and XTianqiTrumpet.LAZY_ATTACK)
	_hooks_same()
	_memo()
	_whole_battle()
	_skip_and_silenced()
	_whole_battle_fate()
	_perf()
	_switches(true)
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(_plain(r.detail)).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _switches(on: bool) -> void:
	if on:
		XBattler.ATTACK_ID_MEMO = true
		XTianqiQiyinEffects.LAZY_ATTACK = true
		XTianqiAffixBattle.LAZY_ATTACK = true
		XTianqiTrumpet.LAZY_ATTACK = true
	else:
		XBattler.ATTACK_ID_MEMO = false
		XTianqiQiyinEffects.LAZY_ATTACK = false
		XTianqiAffixBattle.LAZY_ATTACK = false
		XTianqiTrumpet.LAZY_ATTACK = false


# ---- 夹具 ----

## 天启篇存档 4 人（学全部重构技），可选穿七印＋词条、学号卷；返回 XBattleLogic
func _setup(group: Array, troop := 394, seals := [], learn := [], big_hp := true, rand_seed := "0000000000000293", no_skill_dmg := false) -> XBattleLogic:
	var s := XTianqi.start_new_game(3, "lianyu", group.slice(0, 3))
	XTianqi.take_pending()
	for id in group:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in group:
		var a: XActor = s.actor(id)
		a.change_level(60)
		for sid in XTianqiSkills.data().skills:
			if int(XTianqiSkills.spec(int(sid)).get("actor", 0)) == id:
				a.learn_skill(int(sid))
	s.battle_slots = group.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	for i in group.size():
		var a: XActor = s.actor(group[i])
		if i < seals.size() and str(seals[i]) != "":
			_wear(a, i, str(seals[i]), no_skill_dmg)
		for n in learn:
			if (int(n) + i) % 2 == 0 or learn.size() == 1:
				var id := int(XTianqiTrumpet.scroll(int(n)).skill)
				if not a.skill_ids.has(id):
					a.skill_ids.append(id)
		a.refresh_passive()
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create(rand_seed))
	if big_hp:
		for e in logic.enemies:
			var p: Array = (e.data().params as Array).map(func(v): return float(v))
			p[0] += BIG_HP
			e.zq_ref = {"p": p, "k": 1.0}
			e.param_mark_dirty()
			e.param_refresh()
			e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return logic


const AFFIXES := [{"key": "final_damage", "grade": "perfect", "extra": {}}, {"key": "skill_damage", "grade": "normal", "extra": {}},
	{"key": "element_damage", "grade": "normal", "extra": {"element": "fire"}}, {"key": "last_stand", "grade": "normal", "extra": {}},
	{"key": "first_strike", "grade": "normal", "extra": {}}, {"key": "damage_reduction", "grade": "normal", "extra": {}},
	{"key": "bulwark", "grade": "normal", "extra": {}}, {"key": "headhunter", "grade": "normal", "extra": {}}]


## 七印全套 5 件＋武器（各带两三条词条）
## no_skill_dmg：所有词条都不带「技能伤害」（词条钩子 LAZY_ATTACK 不问 is_attack 那一支，T296 补 P3-1）
func _wear(a: XActor, i: int, seal: String, no_skill_dmg := false) -> void:
	a.keep_unequippable = true
	var parts := ["head", "body", "hands", "waist", "legs"]
	var st: XState = XState.current
	var pool: Array = AFFIXES.filter(func(x): return str(x.key) != "skill_damage") if no_skill_dmg else AFFIXES
	var w := XGear.create("weapon", 1, st)
	XTianqiQiyinEffects.mark(w, {"kind": "weapon", "seal": seal, "wtype": "sword", "true_seal": true})
	w.qiyin["affixes"] = [pool[i % pool.size()], pool[(i + 1) % pool.size()], pool[1]]
	a.equips[0] = w
	for k in 5:
		var inst := XGear.create("armor", 1, st)
		XTianqiQiyinEffects.mark(inst, {"kind": "set", "seal": seal, "part": parts[k], "true_seal": false})
		inst.qiyin["affixes"] = [pool[(i + k + 2) % pool.size()]]
		if k + 1 < a.equips.size():
			a.equips[k + 1] = inst
		else:
			a.equips.append(inst)
	a.param_mark_dirty()
	a.param_refresh()


## 对象换成名字，好比较、好打印
func _plain(v):
	if v is Object:
		if v is XActor:
			return "A%d" % int(v.actor_id)
		if v is XEnemy:
			return "E%d#%d" % [int(v.enemy_id), int(v.get("index")) if "index" in v else 0]
		return "obj"
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k))] = _plain(v[k])
		return out
	if v is Array:
		return (v as Array).map(_plain)
	if v is float:
		return var_to_str(v)  # 逐位：17 位有效数字
	return v


func _dmg_items(a: XBattler) -> Array:
	var out := []
	if a is XActor:
		for s in (a as XActor).skills():
			if int(s.get("damage", {}).get("type", 0)) in [1, 3, 5]:
				out.append(s)
	var atk := a.attack_skill()
	if not atk.is_empty():
		out.append(atk)
	return out


func _hook_ops(logic: XBattleLogic, window: bool) -> String:
	var rows := []
	if window:
		XActor.read_begin()
	for a in logic.actors:
		for item in _dmg_items(a):
			for e in logic.enemies:
				rows.append([XTianqiQiyinEffects.damage_ops(item, a, e), XTianqiAffixBattle.damage_ops(item, a, e), XTianqiTrumpet.damage_ops(item, a, e)])
		for e in logic.enemies:
			var atk: Dictionary = e.attack_skill()
			rows.append([XTianqiQiyinEffects.damage_ops(atk, e, a), XTianqiAffixBattle.damage_ops(atk, e, a), XTianqiTrumpet.damage_ops(atk, e, a)])
	if window:
		XActor.read_end()
	return JSON.stringify(_plain(rows))


# ---- 一、钩子逐项一致 ----

func _hooks_same() -> void:
	var seals := XTianqiQiyinGear.seal_keys()
	_check("seal_keys", seals.size() >= 7, seals)
	var kinds := {}
	var i := 0
	while i < seals.size():
		var four := [seals[i % seals.size()], seals[(i + 1) % seals.size()], seals[(i + 2) % seals.size()], seals[(i + 3) % seals.size()]]
		var logic := _setup([1, 100, 131, 107], 394, four, [1, 2, 4, 5, 6])
		for a in logic.actors:
			for code in ["aoe_skill_dmg_pct", "skill_dmg_pct", "silenced_normal_attack_dmg_pct"]:
				if XTianqiQiyinEffects._has(logic, a, code):
					kinds[code] = true
		var got := {}
		for on in [true, false]:
			_switches(on)
			got[on] = [_hook_ops(logic, true), _hook_ops(logic, false)]
		_switches(true)
		_check("hooks_same_window:%s" % str(four), got[true][0] == got[false][0], [got[true][0].sha256_text(), got[false][0].sha256_text()])
		_check("hooks_same_nowindow:%s" % str(four), got[true][1] == got[false][1])
		_check("hooks_window_eq_nowindow:%s" % str(four), got[true][0] == got[true][1])
		_check("hooks_nonempty:%s" % str(four), got[true][0].contains("finalAdd") or got[true][0].contains("finalMultiplier"), got[true][0].left(200))
		logic.end_battle(0)
		i += 4
	# 三条跟普攻有关的七印效果至少有一条被覆盖到（need_kind 为真那一支）
	_check("hooks_kind_branch_covered", not kinds.is_empty(), kinds)


# ---- 二、普攻号记忆 ----

func _memo() -> void:
	var logic := _setup([1, 100, 131, 107], 394, [], [], true)
	var a: XActor = logic.actors[0]
	var b: XActor = logic.actors[1]
	a.keep_unequippable = true
	a.equips[0] = XGear.template("weapon", 1109)  # 火精灵文书 <Replace Attack: 1004>
	a.refresh_passive()
	XActor.read_begin()
	var first := a.attack_skill_id()
	var key := "ra1" if a._cat_bare else "ra0"
	var memo_has := a._read_memo().has(key)
	var second := a.attack_skill_id()
	_check("memo_weapon_1004", first == 1004 and second == 1004, [first, second])
	_check("memo_stored", memo_has)
	_check("memo_eq_fresh_weapon", a.attack_skill_id() == a._attack_skill_id_now())
	_check("memo_b_plain", b.attack_skill_id() == b._attack_skill_id_now(), [b.attack_skill_id(), b._attack_skill_id_now()])
	# 窗口没关时加状态：换代，读到新值
	b.add_state(66)  # 佛陀真身 <Replace Attack: 562>
	_check("memo_state_add_gen", b.attack_skill_id() == 562, b.attack_skill_id())
	b.remove_state(66)
	_check("memo_state_remove_gen", b.attack_skill_id() == b._attack_skill_id_now() and b.attack_skill_id() != 562, b.attack_skill_id())
	# 换武器：先热一次（记忆里是 1004），再走正式 XEquipment.preview（read_touch 换代）：本体的记忆作废、预览克隆读到新值
	# （XEquipment.change 不能在窗口里调：它先换装备、后读特性，中间没换代，原有的特性表窗口记忆会读到旧值，见交付单）
	_check("memo_equip_warm", a.attack_skill_id() == 1004 and a._read_memo().has(key), a.attack_skill_id())
	var plain := {}
	for wid in range(1, 400):  # 找一把这名角色正式能穿、不换普攻的武器
		var w := XGear.template("weapon", wid)
		if not w.is_empty() and XEquipment.fits(a, 0, w) and XBattler.replace_attack_of(w) == 0:
			plain = w
			break
	_check("memo_equip_found_weapon", not plain.is_empty())
	var pv := XEquipment.preview(a, 0, plain)
	_check("memo_equip_preview_gen", not a._read_memo().has(key), a._read_memo().keys())
	_check("memo_equip_preview_new", pv.attack_skill_id() == pv._attack_skill_id_now() and pv.attack_skill_id() != 1004, [pv.attack_skill_id(), pv._attack_skill_id_now()])
	_check("memo_equip_self_after", a.attack_skill_id() == 1004 and a._attack_skill_id_now() == 1004, a.attack_skill_id())
	XActor.read_end()
	# 开关关掉不记
	XBattler.ATTACK_ID_MEMO = false
	XActor.read_begin()
	a.attack_skill_id()
	_check("memo_off_not_stored", not a._read_memo().has(key))
	XActor.read_end()
	XBattler.ATTACK_ID_MEMO = true
	logic.end_battle(0)
	# 五条悟：角色备注 <Replace Attack: 10634>
	XGojo.unlock_override = 1
	var lg := _setup([180, 1, 100], 394, [], [], true)
	var g: XActor = null
	for x in lg.actors:
		if int(x.actor_id) == 180:
			g = x
	if g != null:
		XActor.read_begin()
		var v1 := g.attack_skill_id()
		var v2 := g.attack_skill_id()
		XActor.read_end()
		_check("memo_gojo", v1 == v2 and v1 == g.attack_skill_id(), [v1, v2, g.attack_skill_id()])
		_check("memo_gojo_10634", v1 == 10634 and g._attack_skill_id_now() == 10634, [v1, g._attack_skill_id_now()])  # 角色备注 <Replace Attack: 10634>
	else:
		_check("memo_gojo_in_party", false, lg.actors.map(func(x): return x.actor_id))
	XGojo.unlock_override = -1
	lg.end_battle(0)


# ---- 三、整场同种子逐位一致 ----

func _fp(logic: XBattleLogic) -> Array:
	var rows := []
	for b in logic.actors + logic.enemies:
		rows.append([var_to_str(b.hp), var_to_str(b.mp), var_to_str(b.tp), b.state_ids.duplicate(), var_to_str(b.shield) if "shield" in b else ""])
	return [logic.turn, rows, logic.random.snapshot()]


func _battle_tianqi(turns: int) -> String:
	seed(20261120)
	var logic := _setup([1, 100, 131, 107], 394, ["bai", "hui", "hei", "tian"], [1, 2, 4], false, "00000000000002a3")
	var a: XActor = logic.actors[3]
	a.keep_unequippable = true
	a.equips[0] = XGear.template("weapon", 1109)  # 替换普攻的武器
	a.refresh_passive()
	var out := []
	for t in turns:
		if logic.is_over():
			break
		if t == 1:
			logic.actors[1].add_state(66)  # 中途挂替换普攻的状态
		var logs := logic.run_turn({})
		out.append([_plain(logs), _fp(logic)])
	out.append(["over", logic.is_over(), logic.turn])
	logic.end_battle(0)
	return JSON.stringify(out)


func _battle_xiyou(turns: int) -> String:
	seed(20261120)
	var s := XState.new_game(3, 1, [])
	s.random_master = XRandomStream.hex64(20261120)
	XState.current = s
	var actor := s.actor(1)
	actor.change_level_mv(30)
	actor.keep_unequippable = true
	actor.equips[0] = XGear.template("weapon", 1109)
	actor.refresh_passive()
	actor.recover_all()
	var logic := XBattleLogic.new()
	logic.setup(2, s, XBattleRandom.create("00000000000002a4"))
	var out := []
	for t in turns:
		if logic.is_over():
			break
		if t == 1 and not logic.actors.is_empty():
			logic.actors[0].add_state(66)
		out.append([_plain(logic.run_turn({})), _fp(logic)])
	out.append(["over", logic.is_over(), logic.turn])
	logic.end_battle(0)
	return JSON.stringify(out)


func _whole_battle() -> void:
	_switches(true)
	var on1 := _battle_tianqi(5)
	var on2 := _battle_tianqi(5)
	_switches(false)
	var off := _battle_tianqi(5)
	_switches(true)
	_check("tianqi_battle_ran", on1.length() > 2000, on1.length())
	_check("tianqi_battle_repeat", on1 == on2, [on1.sha256_text(), on2.sha256_text()])
	_check("tianqi_battle_on_eq_off", on1 == off, [on1.sha256_text(), off.sha256_text(), _diff_at(on1, off)])
	var x_on := _battle_xiyou(4)
	_switches(false)
	var x_off := _battle_xiyou(4)
	_switches(true)
	_check("xiyou_battle_ran", x_on.length() > 500, x_on.length())
	_check("xiyou_battle_on_eq_off", x_on == x_off, [x_on.sha256_text(), x_off.sha256_text(), _diff_at(x_on, x_off)])
	print("T293 battle fingerprints: tianqi=%s (%d B) xiyou=%s (%d B)" % [on1.sha256_text().left(12), on1.length(), x_on.sha256_text().left(12), x_on.length()])


func _diff_at(x: String, y: String) -> String:
	for i in mini(x.length(), y.length()):
		if x[i] != y[i]:
			return "@%d: %s | %s" % [i, x.substr(maxi(0, i - 80), 160), y.substr(maxi(0, i - 80), 160)]
	return "len %d vs %d" % [x.length(), y.length()]


# ---- 五、T296 补 T293 核查 P3-1 ----

## 词条钩子「没有技能伤害词条就不问 is_attack」那一支、七印「封技时普攻增伤」那一支：开关全开／全关逐项相同
func _skip_and_silenced() -> void:
	var logic := _setup([1, 100, 131, 107], 394, ["mo", "mo", "mo", "mo"], [1, 2, 4], true, "0000000000000293", true)
	var no_sd := true
	for a in logic.actors:
		for e in a.equip_list():
			if e is Dictionary and e.has("qiyin"):
				for x in e.qiyin.get("affixes", []):
					if str(x.key) == "skill_damage":
						no_sd = false
	_check("p31_affix_no_skill_damage", no_sd)
	var got := {}
	for on in [true, false]:
		_switches(on)
		got[on] = [_hook_ops(logic, true), _hook_ops(logic, false)]
	_switches(true)
	_check("p31_affix_skip_same", got[true][0] == got[false][0] and got[true][1] == got[false][1], [got[true][0].sha256_text(), got[false][0].sha256_text()])
	# 封技：失魄（状态 64，封技能类型 1、2）挂上后，默印真印的「封技普攻增伤」进普攻的七印钩子
	var a: XActor = logic.actors[0]
	var e: XEnemy = logic.enemies[0]
	var atk := a.attack_skill()
	var before := JSON.stringify(_plain(XTianqiQiyinEffects.damage_ops(atk, a, e)))
	a.add_state(64)
	_check("p31_sealed_trait", not a.traits_set(XBattler.TRAIT_STYPE_SEAL).is_empty(), a.state_ids)
	_check("p31_silenced_code", XTianqiQiyinEffects._has(logic, a, "silenced_normal_attack_dmg_pct"))
	var row := {}
	for on in [true, false]:
		_switches(on)
		row[on] = [JSON.stringify(_plain(XTianqiQiyinEffects.damage_ops(atk, a, e))), _hook_ops(logic, true), _hook_ops(logic, false)]
	_switches(true)
	_check("p31_silenced_branch_hit", row[true][0] != before, [before.left(200), row[true][0].left(200)])
	_check("p31_silenced_same", row[true] == row[false], [row[true][0].left(200), row[false][0].left(200)])
	a.remove_state(64)
	logic.end_battle(0)


## 命运编织者 94 穿命运骰子（4521，FATE_REROLL 那一支）：天启篇整场开关全开／全关逐位一致，且这几回合里真放过命运之手
func _battle_fate(turns: int) -> String:
	seed(20261120)
	var lineup := [94, 1, 100]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	s.random_master = XRandomStream.hex64(20261119)
	for id in lineup:
		s.actor(id).change_level(60)
	var a: XActor = s.actor(94)
	a.change_level(99)
	a.learn_skill(6861)
	var slots := a.equip_slots()
	for i in slots.size():
		if int(slots[i]) == 13:
			a.equips[i] = XActor.make_equip("armor", 4521)
			break
	a.refresh_passive()
	for x in lineup:
		s.actor(x).recover_all()
	s.set_switch(2261, true)  # 火已集过：抽到火就重掷（同 xiyou_tianqi_fate_copy 四）
	s.set_variable(1281, 3)
	var logic := XBattleLogic.new()
	logic.setup(2, s, XBattleRandom.create("00000000000002a5"))
	for e in logic.enemies:
		if e.mhp < 900000000:
			e.add_param(0, 999999999)
		e.recover_all()
	var out := []
	for t in turns:
		if logic.is_over():
			break
		out.append([_plain(logic.run_turn({})), _fp(logic)])
	out.append(["over", logic.is_over(), logic.turn, s.variable(1281), logic.has_meta("xtq_fate_reroll")])
	logic.end_battle(0)
	return JSON.stringify(out)


func _whole_battle_fate() -> void:
	_switches(true)
	var on1 := _battle_fate(6)
	_switches(false)
	var off := _battle_fate(6)
	_switches(true)
	_check("fate_battle_cast", on1.contains("6861") or on1.contains("命运"), on1.length())
	_check("fate_battle_on_eq_off", on1 == off, [on1.sha256_text(), off.sha256_text(), _diff_at(on1, off)])
	print("T296 fate battle fingerprint: %s (%d B)" % [on1.sha256_text().left(12), on1.length()])


# ---- 四、性能（打印） ----

func _us(f: Callable, n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		f.call()
	return float(Time.get_ticks_usec() - t0) / n


func _perf() -> void:
	var logic := _setup([1, 100, 131, 107], 394, ["bai", "hui", "hei", "tian"], [1, 2, 4])
	var a: XActor = logic.actors[0]
	var b: XEnemy = logic.enemies[0]
	var sk: Dictionary = {}
	for s in a.skills():
		if int(s.get("damage", {}).get("type", 0)) == 1:
			sk = s
			break
	var V: Array = logic.vars()
	var row := {}
	for on in [false, true]:
		_switches(on)
		XActor.read_begin()
		var q := _us(func(): XTianqiQiyinEffects.damage_ops(sk, a, b), 200)
		var f := _us(func(): XTianqiAffixBattle.damage_ops(sk, a, b), 200)
		var t := _us(func(): XTianqiTrumpet.damage_ops(sk, a, b), 200)
		var cap := _us(func(): XActorDamageHooks.capture(sk, a, b), 100)
		var calc := _us(func(): XDamage.calculate(sk, a, b, {"vars": V, "rawValue": 1000.0}), 50)
		XActor.read_end()
		var cold := _us(func(): XDamage.calculate(sk, a, b, {"vars": V, "rawValue": 1000.0}), 50)
		XSmartAI.choose(logic, a)  # 预热
		var tot := 0
		var mx := 0
		for r in 3:
			for act in logic.actors:
				var t0 := Time.get_ticks_usec()
				XSmartAI.choose(logic, act)
				var dt := Time.get_ticks_usec() - t0
				tot += dt
				mx = maxi(mx, dt)
		row[on] = {"qiyin": q, "affix": f, "trumpet": t, "capture": cap, "calc_warm": calc, "calc_cold": cold, "choose_avg_ms": tot / 12000.0, "choose_max_ms": mx / 1000.0}
		print("PERF T293 switches=%s qiyin=%.1fus affix=%.1fus trumpet=%.1fus capture=%.1fus calc(同窗口)=%.1fus calc(每次新窗口)=%.1fus choose4v5 avg=%.1fms max=%.1fms" % [
			"on" if on else "off", q, f, t, cap, calc, cold, tot / 12000.0, mx / 1000.0])
	_switches(true)
	# T296：公式帧进出只在改得了读法时作废只读窗口（XAlienBattle.FRAME_TOUCH_LAZY），T293 开关全开时开／关各量一次
	var frow := {}
	for lazy in [false, true]:
		XAlienBattle.FRAME_TOUCH_LAZY = lazy
		XActor.read_begin()
		var calc := _us(func(): XDamage.calculate(sk, a, b, {"vars": V, "rawValue": 1000.0}), 50)
		var ev := _us(func(): XDamage.eval_formula(sk, a, b, V), 50)
		XActor.read_end()
		var cold := _us(func(): XDamage.calculate(sk, a, b, {"vars": V, "rawValue": 1000.0}), 50)
		XSmartAI.choose(logic, a)
		var tot := 0
		var mx := 0
		for r in 3:
			for act in logic.actors:
				var t0 := Time.get_ticks_usec()
				XSmartAI.choose(logic, act)
				var dt := Time.get_ticks_usec() - t0
				tot += dt
				mx = maxi(mx, dt)
		frow[lazy] = {"calc_warm": calc, "eval_warm": ev, "calc_cold": cold, "choose_avg_ms": tot / 12000.0, "choose_max_ms": mx / 1000.0}
		print("PERF T296 frame_lazy=%s calc(同窗口)=%.1fus eval_formula(同窗口)=%.1fus calc(每次新窗口)=%.1fus choose4v5 avg=%.1fms max=%.1fms" % [
			"on" if lazy else "off", calc, ev, cold, tot / 12000.0, mx / 1000.0])
	XAlienBattle.FRAME_TOUCH_LAZY = true
	# 粗上限：开着时同窗口 calculate 不比关着慢（实测快一半以上，这里只防退化）
	_check("perf_frame_lazy_not_slower", frow[true].calc_warm <= frow[false].calc_warm * 1.2, frow)
	# 粗上限防退化：开着时三个钩子合计不比关着慢
	_check("perf_hooks_not_slower", row[true].qiyin + row[true].affix + row[true].trumpet <= (row[false].qiyin + row[false].affix + row[false].trumpet) * 1.2, row)
	logic.end_battle(0)
