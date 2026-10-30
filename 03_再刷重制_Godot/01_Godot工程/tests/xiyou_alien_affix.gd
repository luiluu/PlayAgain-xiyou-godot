extends Node
## 异化词条效果（XAlienBattle 文末「词条效果」，期一：逆骨、归墟）：逐例对照 mv_oracle/alien_affix_probe.cjs（generated/oracle/alien_affix.json）。
## - config：alienation.json 的 templates.inversebone／attack 长度与头尾照参照。
## - battle.*：角色 1（99 级）穿本体 1044 的异化武器（none 为不带标记的本体）＋角色 8，敌群 2（敌人生命加 1e12、攻击加 300），开战锁队；
##   每步比双方生命、法力、护盾、状态、增减益，以及战斗帧外角色 1 的物攻／物防。
## - frames：每步之后公式帧与行动帧都已弹空。
## - 期二① battle.pest／jail／insulation／sacrifice：合成技能（空白技能 13 照参照的 def 填 scope／hitType／效果）、set、
##   roundEnd（XAlienBattle.spread_pest）、expire（自然移除）逐步对照；对照时 O-106 关（照原版）。
## - o106.*：O-106 开时角色身上的减益也走囚厄接收、绝缘拒收（原版对角色失效）。
## - 期二② battle.hollow／lifelink／scapegoat：步骤另有 regen（turn_end_battler，照 onTurnEnd）、revive（去阵亡状态）；对照时 O-108 关。
## - 生命池补漏 battle.*.corrosion：tick 照 endTurn 包装结算腐蚀（行动外 gainHp）；*.event 照事件「增减生命」（MVEventCore 311）。
## - o108.*：O-108 开时连命复活把池回到 10%（两人都起来），嫁祸的保护者倒下时不能复活。
## - 第③批 battle.blessing／wish／prayer：行动道具投影；步骤带 view 的另比投影后的名字、scope、效果与原技能能不能用（不比 terminated，O-109）。
## - 第③批 battle.silence／glutton：MP 费用类；角色 1 另比生命／法力上限、缄默已锁比例、饕餮饥饿储备，view 比能不能用；
##   饕餮开战前身上的状态与增益照参照 pre 写定。对照时 O-113 关；o113.* 开时缄默技能沉默中可用；glutton.hang_up 挂机选技读储备。
## - 第③批 battle.mimic／faceless：借技能；角色 1 另比仿形记录、当前仿形、WATCH 里哪些在技能表、哪些能用（只看已添加技能类型的，
##   重制 can_use 另查技能类型），步骤另有 forget（来源队友忘掉技能）、choice（切换窗口选的仿形）。对照时 O-115 关；o115.* 开时按顺序轮换。
## - 第③批 battle.erosion：蚀术；角色 1 另比自己与各敌人身上的异化封印、ERODE_WATCH 里各自能用哪些；步骤另有 shield（直接写护盾）。
##   对照时 O-116 关；o116.* 开时敌人没有有效行动的回合也解封。
## - O-待定（o_prayer_counter）：对照时关（照原版：逆祷者的反击投影成治愈打在敌人身上）；开时打在敌人身上的治疗为 0。
## - 补漏：sethp（XResourceContext.set_resource，来源 src）；event 带 mp 照 312（增减 MP）、src 为来源；开战前 dead（已倒下）与 extra
##   （第三名队员也穿异化武器）比锁队检查卸下的 eject；view 带 repeats 另比 numRepeats。o106.jail_death_buff_kept：O-106 开时阵亡保留接收的减益。
## - 第④批 battle.swallow／offer：装备类；双方另比装备栏（本体编号）、八项能力值、命中／回避／暴击，背包里异化装备与供体件数；
##   步骤 end 照 end_battle（胜／逃／败）。gear.*：胜、逃、败结束后装备栏原样（同一实例）、背包不多不少、存读档往返不变；
##   战斗中供体不能穿、吞器者不能换装；供体不能在商店卖、挂机卖出跳过；一键出售按 O-118（关时照原版给钱不扣件）。
const ORACLE := "oracle/alien_affix.json"
var results := []
## 本次 _battle 每个行动步骤的 can_use（o113 用）
var _usable_log := []
## 同参照 WATCH（百相、无面另记的技能）
const WATCH := [160, 311, 502, 1924, 1926, 1928, 1930, 10197]
## 同参照 ERODE_WATCH（蚀术另记）
const ERODE_WATCH := [1, 1924, 1926, 1928]
## 本次 _battle 的异化装备、供体与开战前的装备栏、背包（gear.* 用）
var _gear_ctx := {}


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return snappedf(float(v), 1e-6)
	return v


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		get_tree().quit.call_deferred(1)
		return
	var t := XAlienation.templates()
	for k in ["inversebone", "attack"]:
		var list: Array = t.get(k, [])
		var got := {"size": list.size(), "head": list.slice(0, 5), "tail": list.slice(-5)}
		check("config." + k, _norm(got) == _norm(ref.config[k]), [got, ref.config[k]])
	XAlienBattle.o106_actor_debuffs = false
	XAlienBattle.o108_life_revive = false
	XAlienBattle.o113_silence_bypass = false
	XAlienBattle.o115_mimic_cycle = false
	XAlienBattle.o116_idle_release = false
	XAlienBattle.o_prayer_counter = false
	var by_id := {}
	for c in ref.cases:
		by_id[str(c.id)] = c
		if check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			_battle(c)
	XAlienBattle.o106_actor_debuffs = true
	XAlienBattle.o108_life_revive = true
	XAlienBattle.o113_silence_bypass = true
	XAlienBattle.o115_mimic_cycle = true
	XAlienBattle.o116_idle_release = true
	XAlienBattle.o_prayer_counter = true
	if by_id.has("battle.prayer.counter"):  # O-待定 开时逆祷者的反击不治疗敌人（敌人生命停在反击前）
		var rows := _battle(by_id["battle.prayer.counter"], false)
		check("o_prayer_counter.no_enemy_heal", rows[2].enemies[0].hp == rows[1].enemies[0].hp and rows[2].a.hp == rows[1].a.hp, [rows[1].enemies[0].hp, rows[2].enemies[0].hp])
	if by_id.has("battle.erosion"):
		_battle(by_id["battle.erosion"], false, _erosion_idle)
	if by_id.has("battle.mimic"):
		var rows := _battle(by_id["battle.mimic"], false)
		check("o115.mimic_cycle_third", int(rows[11].a.selected) == 1928 and int(rows[6].a.selected) == 1926, [rows[6].a, rows[11].a])
	if by_id.has("battle.silence"):
		var rows := _battle(by_id["battle.silence"], false)
		check("o113.silence_bypass", _usable_log[2] == true and _usable_log[3] == false, _usable_log)
		check("o113.silence_lock_same", is_equal_approx(float(rows[6].a.capLock), float(by_id["battle.silence"].observed.rows[6].a.capLock)), rows[6].a)
	if by_id.has("battle.glutton"):
		_battle(by_id["battle.glutton"], false, _glutton_hang_up)
	if by_id.has("battle.lifelink"):
		var rows := _battle(by_id["battle.lifelink"], false)
		var last: Dictionary = rows[rows.size() - 1]
		check("o108.lifelink_revive_pool", last.a.hp > 1.0 and last.b.hp > 0.0 and not (last.b.states as Array).has(1), [last.a, last.b])
	if by_id.has("battle.scapegoat"):
		var rows := _battle(by_id["battle.scapegoat"], false)
		check("o108.scapegoat_no_revive", (rows[rows.size() - 1].a.states as Array).has(1), rows[rows.size() - 1].a)
	if by_id.has("battle.jail"):
		var rows := _battle(by_id["battle.jail"], false)
		check("o106.jail_debuff_moved", rows[1].a.buffs[1] == -1 and rows[1].b.buffs[1] == 0, [rows[1].a.buffs, rows[1].b.buffs])
		check("o106.jail_debuff_kept", rows[3].a.buffs[1] == -1, rows[3].a.buffs)
	if by_id.has("battle.jail.death"):  # O-106 开时囚厄接收到角色的减益，阵亡（clearBuffs）也保留
		var rows := _battle(by_id["battle.jail.death"], false)
		check("o106.jail_death_buff_kept", rows[1].a.buffs[1] == -1 and rows[2].a.hp == 0.0 and rows[2].a.buffs[1] == -1 and rows[3].a.buffs[1] == -1, [rows[1].a, rows[2].a])
	if by_id.has("battle.insulation"):
		var rows := _battle(by_id["battle.insulation"], false)
		check("o106.insulation_debuff_blocked", rows[7].a.buffs[0] == 0, rows[7].a.buffs)
	for id in ["battle.swallow", "battle.offer"]:
		if by_id.has(id):
			for result in [0, 1, 2]:
				var c: Dictionary = by_id[id].duplicate(true)
				var rows: Array = c.observed.rows
				rows[rows.size() - 1].step.end = result
				_battle(c, false, _gear_after.bind("gear.%s.%d" % [id.substr(7), result]))
	if by_id.has("battle.swallow"):
		var c: Dictionary = by_id["battle.swallow"].duplicate(true)
		c.observed.rows = []
		_battle(c, false, _gear_swallow_guards)
	_gear_ctx = {}
	XAlienation.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


func _logic(s: XState, troop: int) -> XBattleLogic:
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(troop, s, rand)
	return logic


func _unit(x) -> Dictionary:
	var states: Array = x.state_ids.duplicate()  # Array(Array[int]) 可能与 state_ids 同一份，排序会改到战斗者
	states.sort()
	return {"hp": x.hp, "mp": x.mp, "shield": x.shield, "states": states, "buffs": Array(x.buffs).slice(2, 8)}


func _reading(enemies: Array, a, b) -> Dictionary:
	var ra := _unit(a)
	ra.atk = a.atk
	ra.def = a.def
	var d = XAlienBattle.locked(a)
	if d != null:
		ra.mhp = a.mhp
		ra.mmp = a.mmp
		ra.capLock = float(d.get("capLock", 0.0))
		ra.hunger = float(d.get("hunger", 0.0))
		if str(d.affix) in ["mimic", "faceless"]:
			ra.observed = (d.observed as Array).duplicate()
			ra.selected = int(d.selected)
			var ids: Array = a.skills().map(func(sk): return int(sk.id))
			ra.has = WATCH.filter(func(id): return ids.has(id))
			ra.usable = WATCH.filter(func(id): return _typed(a, id) and XAlienBattle.active_logic().can_use(a, XDB.rec("Skills", id)))
		elif str(d.affix) == "erosion":
			var logic = XAlienBattle.active_logic()
			ra.seals = _sealed(logic, a)
			ra.usable = ERODE_WATCH.filter(func(id): return _typed(a, id) and logic.can_use(a, XDB.rec("Skills", id)))
			ra.eseals = enemies.map(func(e): return _sealed(logic, e))
			ra.eusable = enemies.map(func(e): return ERODE_WATCH.filter(func(id): return logic.can_use(e, XDB.rec("Skills", id))))
	var out := {"enemies": enemies.map(func(e): return _unit(e)), "a": ra, "b": _unit(b)}
	if bool(_gear_ctx.get("on", false)):
		ra.gear = _gear_of(a)
		out.b.gear = _gear_of(b)
		var s: XState = XState.current
		out.bag = {"item": s.gear.filter(func(e): return is_same(e, _gear_ctx.item)).size(),
			"donors": (_gear_ctx.donors as Array).map(func(d): return s.gear.filter(func(e): return is_same(e, d)).size())}
	return out


static func _gear_of(x: XActor) -> Dictionary:
	return {"equips": Array(x.equips).map(func(e): return int(e.base) if e is Dictionary and not e.is_empty() else 0),
		"params": range(8).map(func(i): return x.param(i)), "xp": range(3).map(func(i): return x.xparam(i))}


static func _sealed(logic, b) -> Array:
	var st := XAlienBattle._store(logic)
	var ids: Array = (st.get("seals", {}).get(b, {}) as Dictionary).keys().map(func(id): return int(id))
	ids.sort()
	return ids


## 重制 can_use 另查技能类型已添加（原版 canUse 不查）：能不能用只比已添加类型的技能
static func _typed(a: XActor, id: int) -> bool:
	return a.traits_set(XBattler.TRAIT_STYPE_ADD).has(int(XDB.rec("Skills", id).get("stypeId", 0))) or int(XDB.rec("Skills", id).get("stypeId", 0)) == 0


## 只比参照有的键（帧外物攻／物防只在期一的用例里记）
func _same_reading(step: String, got: Dictionary, row: Dictionary, a: XActor = null) -> void:
	for k in ["a", "b"]:
		var mine := {}
		var want: Dictionary = (row[k] as Dictionary).duplicate()
		for key in row[k]:
			mine[key] = got[k].get(key)
		if want.has("usable") and a != null:
			want.usable = (want.usable as Array).filter(func(id): return _typed(a, int(id)))
		check(step + "." + k, _norm(mine) == _norm(want), [mine, want])
	for i in got.enemies.size():
		check(step + ".e%d" % i, _norm(got.enemies[i]) == _norm(row.enemies[i]), [got.enemies[i], row.enemies[i]])
	if row.has("bag"):
		check(step + ".bag", _norm(got.get("bag")) == _norm(row.bag), [got.get("bag"), row.bag])


## 参照 JSON 的数字是浮点：配置里的编号（含无面 pairs 里的）转成整数
static func _ints(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _ints(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _ints(x))
	return int(v) if v is float else v


## 合成技能：空白技能 13 填 def（同参照 synth）
static func _synth(def: Dictionary) -> Dictionary:
	var sk := XDB.rec("Skills", 13).duplicate(true)
	sk.scope = int(def.scope)
	sk.hitType = int(def.hitType)
	sk.effects = (def.effects as Array).map(func(e): return {"code": int(e[0]), "dataId": int(e[1]), "value1": float(e[2]), "value2": 0.0})
	return sk


## O-116：敌人 0 身上封着 1928（参照最后一次封印），没有有效行动的一回合（act 不带技能）——关时封印还在，开时解掉
func _erosion_idle(logic: XBattleLogic, _a: XActor) -> void:
	var e0: XBattler = logic.enemies[0]
	check("o116.sealed_before", _sealed(logic, e0) == [1928], _sealed(logic, e0))
	XAlienBattle.o116_idle_release = false
	logic.act(e0, null, null)
	check("o116.off_keeps_seal", _sealed(logic, e0) == [1928], _sealed(logic, e0))
	XAlienBattle.o116_idle_release = true
	logic.act(e0, null, null)
	check("o116.idle_releases", _sealed(logic, e0).is_empty(), _sealed(logic, e0))


## 吞器、献器结束后（end 步骤已走 end_battle）：装备栏同一实例原样、背包不多不少、没有重复实例，存读档往返不变
func _gear_after(logic: XBattleLogic, a: XActor, tag: String) -> void:
	var s: XState = logic.state
	for x in _gear_ctx.equips:
		var before: Array = _gear_ctx.equips[x]
		check(tag + ".equips_%d" % x.actor_id, range(before.size()).all(func(i): return is_same(x.equips[i], before[i])), [x.actor_id])
	var bag: Array = _gear_ctx.bag
	check(tag + ".bag", s.gear.size() == bag.size() and bag.all(func(e): return s.gear.any(func(g): return is_same(g, e))), [s.gear.size(), bag.size()])
	var ids := []
	for e in s.gear + a.equip_list() + s.actor(8).equip_list():
		ids.append(str(e.get("instanceId", "")))
	var uniq := {}
	for id in ids:
		uniq[id] = true
	check(tag + ".no_duplicate", uniq.size() == ids.size(), ids)
	check(tag + ".no_meta", not a.has_meta("xalien_ghosts") and not s.actor(8).has_meta("xalien_received"))
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var ids_of := func(st: XState, id: int) -> Array:
		return Array(st.actor(id).equips).map(func(e): return str(e.instanceId) if e is Dictionary and not e.is_empty() else "")
	check(tag + ".save_roundtrip", ids_of.call(back, 1) == ids_of.call(s, 1) and ids_of.call(back, 8) == ids_of.call(s, 8)
		and back.gear.map(func(e): return str(e.instanceId)) == s.gear.map(func(e): return str(e.instanceId))
		and _norm(XAlienation.mark(back.actor(1).equips[0]).get("config", {})) == _norm(XAlienation.mark(a.equips[0]).get("config", {})),
		[ids_of.call(back, 1), ids_of.call(s, 1)])


## 吞器战斗中：供体不能穿（Adv:87）、吞器者不能换装；结束后能换；供体不能在商店卖、挂机卖出跳过，一键出售按 O-118
func _gear_swallow_guards(logic: XBattleLogic, a: XActor) -> void:
	var s: XState = logic.state
	var donor: Dictionary = _gear_ctx.donors[0]
	var b := s.actor(8)
	check("gear.donor_unwearable", not XAlienation.can_change(s, b, 0, donor))
	check("gear.locked_in_battle", XAlienBattle.gear_locked(a) and not XAlienation.can_change(s, a, 0, null) and not XAlienBattle.gear_locked(b))
	logic.end_battle(1)
	check("gear.unlocked_after", not XAlienBattle.gear_locked(a) and XAlienation.can_change(s, a, 1, null))
	check("gear.donor_unsellable", not XItemMarks.can_sell(donor))
	var q := int(str(donor.get("meta", {}).get("quality", "0")).strip_edges())
	check("gear.hang_up_skips_donor", not XItemMarks.sellable_gear(s, [q]).has(donor))
	check("gear.onekey_skips_donor", not XItemMarks.sellable_gear(s, [q], true).has(donor))
	XAlienation.o_reserved_onekey = false
	var gold := s.gold
	check("gear.onekey_off_lists_donor", XItemMarks.sellable_gear(s, [q], true).has(donor))
	XItemMarks.sell(s, donor, 1)
	check("gear.onekey_off_keeps_donor", s.gear.has(donor) and s.gold == gold + XItemMarks.selling_price(donor), [s.gold - gold])
	XAlienation.o_reserved_onekey = true


## 饕餮挂机（Adv:138-142）：表里排了火球术（50 MP），实际 MP 0 也按储备够不够选；储备不够退回原生选技（普攻）
func _glutton_hang_up(logic: XBattleLogic, a: XActor) -> void:
	a.learn_skill(114)
	var orders := XHangUpAuto.data(logic.state, "ActSkill")
	orders[a.display_name() + XHangUpAuto.three(logic.turn)] = 114
	var d = XAlienBattle.locked(a)
	d.hunger = 60.0
	check("glutton.hang_up_hunger", int(logic.auto_battle_action(a)[0].id) == 114, logic.auto_battle_action(a))
	d.hunger = 10.0
	check("glutton.hang_up_short", int(logic.auto_battle_action(a)[0].id) != 114, logic.auto_battle_action(a))
	orders.erase(a.display_name() + XHangUpAuto.three(logic.turn))


func _battle(c: Dictionary, compare := true, hook := Callable()) -> Array:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(int(st.get("level", 99)))
	b.change_level_mv(30)
	for id in st.get("learn", []):
		a.learn_skill(int(id))
	for id in st.get("teach", []):
		b.learn_skill(int(id))
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	if st.has("extra"):
		s.add_actor(int(st.extra.actor))
	XAlienation.force_roll = 0.5
	if st.has("affix"):
		XGear.force_roll = 0.5  # 同参照 Math.random 0.5：属性浮动与词缀随机
		var item: Dictionary = XAlienation.create(s, "a" if st.has("armor") else "w", int(st.get("armor", st.weapon)), "boss", str(st.affix)).ok
		# 吞器供体（背包里的普通独立武器）、衣服栏的普通防具，同参照的建立顺序
		var donors: Array = st.get("donors", []).map(func(id):
			var d := XGear.create("weapon", int(id), s)
			s.register_gear(d)
			s.gear.append(d)
			return d)
		if bool(st.get("lockDonor", false)):
			donors[0].name = str(donors[0].name) + "【锁定】"
		var body := {}
		if st.has("body"):
			body = XGear.create("armor", int(st.body), s)
			s.register_gear(body)
		XGear.force_roll = -1.0
		_gear_ctx = {"on": bool(st.get("gear", false)), "item": item, "donors": donors}
		if st.has("config"):
			XAlienation.mark(item).config = (st.config as Dictionary).duplicate(true)
			item.alien.config = _ints(item.alien.config)
			if str(item.alien.config.get("donorId", "")).begins_with("d"):
				item.alien.config.donorId = str(donors[int(str(item.alien.config.donorId).substr(1))].instanceId)
		if not body.is_empty():
			a.equips[a.equip_slots().find(4)] = body
		if st.has("armor"):
			a.equips[0] = XGear.template("weapon", int(st.weapon))
			a.equips[a.equip_slots().find(int(item.etypeId))] = item
		else:
			a.equips[0] = item
		if st.has("extra"):  # 第三名队员也穿一件本体 1044 的异化武器（同参照，在 a 的之后建）
			XGear.force_roll = 0.5
			var more: Dictionary = XAlienation.create(s, "w", 1044, "boss", str(st.extra.affix)).ok
			XGear.force_roll = -1.0
			more.alien.config = _ints((st.extra.config as Dictionary).duplicate(true))
			s.actor(int(st.extra.actor)).equips[0] = more
			_gear_ctx.extra = more
	else:
		a.equips[0] = XGear.template("weapon", int(st.weapon))
		_gear_ctx = {}
	_gear_ctx.equips = {a: a.equips.duplicate(), b: b.equips.duplicate()}
	_gear_ctx.bag = s.gear.duplicate()
	var logic := _logic(s, int(st.troop))
	var enemies: Array = logic.enemies
	for e in enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += 300.0
		e.zq_ref = {"p": p, "k": 1.0}
	# setup 已锁过一次队；参照是回满后才 lockParty，先解锁（不然空壳的生命上限 1 会让回满只回到 1）
	XAlienBattle._store(logic).party = {}
	XAlienBattle._store(logic).status = false
	for x in [a, b] + enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	if st.has("pre"):  # 开战前身上的状态与增益（饕餮锁队时吞掉），回合直接写定
		for v in st.pre.get("states", []):
			a.add_state(int(v[0]))
			a.state_turns[int(v[0])] = int(v[1])
		for v in st.pre.get("buffs", []):
			a.buffs[int(v[0])] = int(v[1])
			a.buff_turns[int(v[0])] = int(v[2])
		a.param_mark_dirty()
		a.refresh_resources()
	for k in st.get("dead", []):  # 开战前已倒下的队员（锁队检查「已倒下」）
		(b if str(k) == "b" else a).add_state(1)
	XAlienBattle.open(logic)
	var tag := str(c.id)
	var locked := [a, b].map(func(x):
		var l = XAlienBattle.locked(x)
		return {"affix": l.affix} if l != null else null)
	if compare:
		check(tag + ".locked", _norm(locked) == _norm(o.locked), [locked, o.locked])
		_same_reading(tag + ".start", _reading(enemies, a, b), o.start, a)
		if o.has("eject"):  # 锁队检查卸下的：异化武器在背包几件、还穿着没有；第三名队员的同样
			var item: Dictionary = _gear_ctx.item
			var got_eject := {"item": s.gear.filter(func(e): return is_same(e, item)).size(), "worn": a.equips.any(func(e): return is_same(e, item)),
				"extra": null, "extraLocked": null}
			if _gear_ctx.has("extra"):
				got_eject.extra = s.gear.filter(func(e): return is_same(e, _gear_ctx.extra)).size()
				got_eject.extraLocked = XAlienBattle.locked(s.actor(int(st.extra.actor))) != null
			check(tag + ".eject", _norm(got_eject) == _norm(o.eject), [got_eject, o.eject])
	var who := func(k: String) -> XBattler:
		return b if k == "b" else enemies[int(k.substr(1))] if k.begins_with("e") else a
	var got := []
	_usable_log = []
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var sp: Dictionary = row.step
		var step := "%s.%d" % [tag, i]
		logic.turn = int(sp.get("round", 1))
		if sp.has("set"):
			for k in ["a", "b"]:
				var x: XBattler = who.call(k)
				if sp.set.has(k + "Hp"):
					x.hp = floorf(x.mhp * float(sp.set[k + "Hp"]))
				if sp.set.has(k + "Mp"):
					x.mp = floorf(x.mmp * float(sp.set[k + "Mp"]))
		elif sp.has("roundEnd"):
			logic.turn = int(sp.roundEnd)
			XAlienBattle.spread_pest(logic)
		elif sp.has("regen"):
			logic.turn_end_battler(who.call(str(sp.regen)), [])
		elif sp.has("tick"):
			logic.turn = int(sp.tick)
			for x in logic.actors + logic.enemies:
				XAlienBattle.tick_corrosion(logic, x, int(sp.tick), [])
		elif sp.has("event"):
			var src = who.call(str(sp.event.src)) if sp.event.has("src") else null
			if src != null:
				XAlienBattle.push_action(src, {})  # 参照的 BattleManager._subject
			MVEventCore.new()._change_resource(who.call(str(sp.event.who)), 312 if bool(sp.event.get("mp", false)) else 311, float(sp.event.value), bool(sp.event.get("death", false)))
			if src != null:
				XAlienBattle.pop_action()
		elif sp.has("sethp"):  # 行动外直接设生命（XResourceContext.set_resource，即 setHp）；来源 src（参照的 _subject），没有就是自己
			var x: XBattler = who.call(str(sp.sethp.who))
			var src = who.call(str(sp.sethp.src)) if sp.sethp.has("src") else null
			if src != null:
				XAlienBattle.push_action(src, {})
			var res := logic._operation_resources(x)
			res.set_resource(x, "hp", floorf(x.mhp * float(sp.sethp.value)))
			logic._finish_lifecycle_operation(res, x)
			if src != null:
				XAlienBattle.pop_action()
		elif sp.has("revive"):
			logic._state_remove(who.call(str(sp.revive)), 1)
		elif sp.has("end"):
			logic.end_battle(int(sp.end))
		elif sp.has("shield"):
			who.call(str(sp.shield.who)).shield = float(sp.shield.value)
		elif sp.has("forget"):
			who.call(str(sp.forget.who)).skill_ids.erase(int(sp.forget.id))
		elif sp.has("expire"):
			logic._state_remove(who.call(str(sp.expire.who)), int(sp.expire.id), true)
		else:
			var user: XBattler = who.call(str(sp.get("user", "a")))
			user.tp = 100.0
			user.mp = user.mmp
			var skill := _synth(sp.def) if sp.has("def") else XDB.rec("Skills", int(sp.skill))
			# 选目标按投影后的 scope（原版 setTarget 之后 makeTargets 读 item()）
			var view := XAlienBattle.project(user, skill)
			var friends := int(view.scope) in [7, 8, 9, 10, 11]
			var side: Array = logic.actors if (user is XActor) == friends else enemies
			var usable := logic.can_use(user, skill) if user is XActor else true
			_usable_log.append(usable)
			if sp.has("choice"):
				XAlienBattle.choose_mimic(user, int(sp.choice))
			logic.act(user, skill, side[int(sp.get("target", 0))])
			if compare and row.has("view"):
				var got_view := {"name": view.name, "scope": int(view.scope), "effects": (view.effects as Array).map(func(e): return [int(e.code), int(e.dataId), float(e.value1)]), "usable": usable}
				if row.view.has("repeats"):  # numRepeats：投影后不算普通攻击，攻击次数追加不加
					got_view.repeats = XBattleLogic.attack_repeats(user, view, int(view.get("repeats", 1)))
				var want: Dictionary = (row.view as Dictionary).duplicate()
				want.erase("terminated")  # O-109：原版投影丢了熟练度费用函数，付费时 terminate；重制不崩
				if tag.begins_with("battle.mimic") or tag.begins_with("battle.faceless") or tag.begins_with("battle.erosion"):
					if not _typed(a, int(sp.skill)):
						want.erase("usable")
						got_view.erase("usable")
				elif not (tag.begins_with("battle.prayer") or tag.begins_with("battle.silence") or tag.begins_with("battle.glutton")):
					want.erase("usable")  # 重制 can_use 另查技能类型已添加（界面用），原版 canUse 不查；只在逆祷用例里比
					got_view.erase("usable")
				check(step + ".view", _norm(got_view) == _norm(want), [got_view, want])
		var reading := _reading(enemies, a, b)
		got.append(reading)
		if compare:
			_same_reading(step, reading, row, a)
			check(step + ".frames", XAlienBattle._formula_frames.is_empty() and XAlienBattle._action_frames.is_empty(),
				[XAlienBattle._formula_frames.size(), XAlienBattle._action_frames.size()])
	if hook.is_valid():
		hook.call(logic, a)
	XAlienBattle.end(logic, -1)
	XState.current = null
	return got
