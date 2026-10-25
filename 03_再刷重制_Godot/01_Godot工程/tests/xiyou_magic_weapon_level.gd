extends Node
## 法宝等级与经验（XMagicWeapon：CP_MagicWeapon 1.10+、CP_X_MagicWeaponLearnSkill）对照冻结 v0.28 参照
## tests/fixtures/magic_weapon_level_oracle.json（mv_oracle/magic_weapon_level_probe.cjs）：
## 全部法宝载入后的等级／经验／上限／下一级所需／升级特性／学技能表；下一级所需公式；逐次得经验升级与满级；
## 法宝经验丹公共事件 1190 与 MagicWeaponAllGainExp／MagicWeaponLevelUp；战斗胜利结算（含隐藏成员、后备减半）；
## 麒麟对剑升级特性按等级叠加；烽舞按等级学技能。另有不靠参照的：<Cannot Gain Exp After Victory>、存档往返。

const FIXTURE := "res://tests/fixtures/magic_weapon_level_oracle.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


static func _f(v) -> float:
	return float(v) if v != null else -1.0


func _case(data: Dictionary, id: String) -> Dictionary:
	for c in data.cases:
		if c.id == id:
			return c.observed if c.observed is Dictionary else {}
	return {}


static func _wear(a: XActor, kind: String, base: int) -> int:
	var item := XGear.template(kind, base)
	var slot := 0 if kind == "weapon" else a.equip_slots().find(int(item.etypeId))
	a.equips[slot] = item
	a.refresh_passive()
	return slot


static func _equip_rows(a: XActor) -> Array:
	var out := []
	for i in range(a.equips.size()):
		var e = a.equips[i]
		if XMagicWeapon.is_magic(e):
			out.append({"slot": float(i), "kind": str(e.kind), "base": float(e.base), "level": XMagicWeapon.level_of(e), "exp": XMagicWeapon.exp_of(e)})
	return out


static func _party_rows(s: XState) -> Array:
	return s.members().map(func(a): return {"actor": float(a.actor_id), "equips": _equip_rows(a)})


func _state(party: Array) -> XState:
	var s := XState.new_game_blank()
	s.gear.clear()
	s.party.clear()
	s.battle_slots = []
	for id in party:
		s.add_actor(int(id))
	return s


func _run_list(list: Array) -> void:
	var frame := MVEventCore.new()
	frame.list = list
	for i in range(50):
		if frame.advance().kind == "done":
			break


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	if not check("oracle_loaded", data is Dictionary and data.get("cases", []).size() == 7 and data.cases.all(func(c): return c.errors.is_empty()), FIXTURE):
		_finish()
		return
	_catalog(_case(data, "catalog"))
	_formula(_case(data, "formula"))
	_gain(_case(data, "gain"))
	_commands(_case(data, "commands"))
	_victory(_case(data, "victory"))
	_traits(_case(data, "traits"))
	_learn(_case(data, "learn"))
	_synthetic()
	_finish()


## ① 全部法宝：初始等级／经验／上限／下一级所需／升级特性／学技能表／不得经验标记／升级效果脚本
func _catalog(o: Dictionary) -> void:
	var p := XDB.plugin(XMagicWeapon.PARAMS)
	check("params_formula", str(p.get("Init Exp Formula", "")) == str(o.params.EXP_FORMULA), [p.get("Init Exp Formula"), o.params.EXP_FORMULA])
	check("params_numbers", [XMagicWeapon._param("Max Level", 15), XMagicWeapon._param("Enemy Min Exp", 0), XMagicWeapon.js_number(p.get("Exp Rate Not Battler", 0))]
		== [_f(o.params.MAX_LEVEL), _f(o.params.ENEMY_MIN_EXP), _f(o.params.EXP_RATE_NOT_BATTLER)], o.params)
	var bad := []
	var seen := 0
	for r in o.rows:
		var item := XGear.template(str(r.kind), int(r.base))
		var got := {"level": XMagicWeapon.level_of(item), "exp": XMagicWeapon.exp_of(item), "maxLevel": XMagicWeapon.max_level(item),
			"next": XMagicWeapon.next_level_exp(item), "useExp": XMagicWeapon.use_exp(item),
			"cannot": item.meta.has("Cannot Gain Exp After Victory"), "effect": str(item.note).contains("<Magic Weapon LevelUp Effect>")}
		var want := {"level": _f(r.level), "exp": _f(r.exp), "maxLevel": _f(r.maxLevel), "next": _f(r.next), "useExp": _f(r.useExp),
			"cannot": bool(r.cannotGainAfterVictory), "effect": bool(r.hasLevelUpEffect)}
		var t := XMagicWeapon.level_up_trait_object(item)
		got["traits"] = t.get("traits", []).size() if not t.is_empty() else null
		want["traits"] = int(r.traitObjectTraits) if r.traitObjectTraits != null else null
		if not t.is_empty():
			got["traitId"] = int(t.id)
			want["traitId"] = int(r.levelUpTraits.id)
		got["learn"] = XMagicWeapon.learn_data(item).map(func(d): return [int(d.id), int(d.min), int(d.max), bool(d.all)])
		want["learn"] = r.learn.map(func(d): return [int(d.id), int(d.min), int(d.max), bool(d.isAll)])
		if got != want:
			bad.append({"base": [r.kind, r.base], "got": got, "want": want})
		seen += 1
	check("catalog_all_magic", bad.is_empty(), bad.slice(0, 5))
	var godot_count := 0
	for table in ["Weapons", "Armors"]:
		for rec in XDB.table(table):
			if rec is Dictionary and rec.get("meta", {}).has("Magic Weapon"):
				godot_count += 1
	check("catalog_count", seen == godot_count and seen > 100, [seen, godot_count])
	check("catalog_covers_traits_learn", o.rows.any(func(r): return r.traitObjectTraits != null) and o.rows.any(func(r): return not r.learn.is_empty()), null)


## ② 下一级所需
func _formula(o: Dictionary) -> void:
	var bad := []
	for r in o.rows:
		var item := XGear.template(str(r.kind), int(r.base))
		item.level = float(r.level)
		var got := XMagicWeapon.next_level_exp(item)
		if got != _f(r.next):
			bad.append([r.kind, r.base, r.level, got, r.next])
	check("formula_next_level_exp", bad.is_empty() and o.rows.size() >= 20, bad)


## ③ 逐次得经验；满级后不得经验，levelUp 只把经验设成所需
func _gain(o: Dictionary) -> void:
	var item := XGear.template("armor", 13)
	for r in o.rows:
		var step = r.step
		if step is String and step == "levelUp_at_max":
			XMagicWeapon.level_up(item)
		elif not (step is String):
			XMagicWeapon.gain_exp(item, float(step))
		var got := [XMagicWeapon.level_of(item), XMagicWeapon.exp_of(item), XMagicWeapon.next_level_exp(item)]
		check("gain_%s" % str(step), got == [_f(r.level), _f(r.exp), _f(r.next)], [got, r])
	check("gain_reaches_max", o.rows.any(func(r): return _f(r.level) == XMagicWeapon.max_level(XGear.template("armor", 13))), null)


## ④ 法宝经验丹（公共事件 1190）与插件指令
func _commands(o: Dictionary) -> void:
	var s := _state([1, 8, 9, 10])
	for w in o.wearing:
		_wear(s.actor(int(w[0])), str(w[1]), int(w[2]))
	var ce = XDB.rec("CommonEvents", 1190).get("list", [])
	check("ce1190_command", ce.size() > 0 and ce[0].code == 356 and str(ce[0].parameters[0]) == str(o.ce1190[0][1][0]), [ce.slice(0, 2), o.ce1190])
	var lists := {"ce1190": [{"code": 117, "indent": 0, "parameters": [1190]}],
		"all5000": [{"code": 356, "indent": 0, "parameters": ["MagicWeaponAllGainExp 5000"]}],
		"levelUp1x3": [{"code": 356, "indent": 0, "parameters": ["MagicWeaponLevelUp 1 %d 3" % int(o.slot)]}],
		"levelUpEmptyOrPlain": [{"code": 356, "indent": 0, "parameters": ["MagicWeaponLevelUp 8 0 2"]}]}
	for r in o.rows:
		if lists.has(r.label):
			_run_list(lists[r.label])
		check("commands_" + str(r.label), _party_rows(s) == r.actors, [_party_rows(s), r.actors])


## ⑤ 战斗胜利：敌群全体（含隐藏）各给 <Magic Weapon Exp>（缺省最小经验），后备 ×后援经验比率四舍五入
func _victory(o: Dictionary) -> void:
	var s := _state(o.all)
	s.battle_slots = o.battle.map(func(v): return int(v))
	for w in o.wearing:
		_wear(s.actor(int(w[0])), str(w[1]), int(w[2]))
	check("victory_before", _party_rows(s) == o.before, [_party_rows(s), o.before])
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(int(o.troopId), s)
	check("victory_battle_members", logic.actors.map(func(a): return float(a.actor_id)) == o.battle, [logic.actors.map(func(a): return a.actor_id), o.battle])
	var troop := logic.enemies
	var total := 0.0
	for e in troop:
		total += XMagicWeapon.enemy_exp(e.data())
	check("victory_troop_total", troop.size() == o.members.size() and total == _f(o.total), [troop.size(), total, o.members.size(), o.total])
	logic.grant({"exp": 0, "gold": 0, "drops": []})
	check("victory_after", _party_rows(s) == o.after, [_party_rows(s), o.after])
	logic.end_battle()


## ⑥ 升级特性对象按等级重复（麒麟对剑 → 防具 4409 的特性）
func _traits(o: Dictionary) -> void:
	var s := _state([142])
	var a := s.actor(142)
	for r in o.rows:
		var slot := int(r.slot)
		var item := XGear.template("weapon", 73)
		item.params = (r.equip.params as Array).duplicate()
		item.traits = (r.equip.traits as Array).duplicate(true)
		item.level = float(r.level)
		a.equips[slot] = item
		a.refresh_passive()
		var obj := XDB.rec("Armors", 4409)
		var n := a.trait_objects().filter(func(t): return t == obj).size()
		check("traits_objects_lv%d" % int(r.level), n == int(r.levelUpObjects), [n, r.levelUpObjects])
		var xs := range(10).map(func(i): return snappedf(a.xparam(i), 0.000001))
		check("traits_xparam_lv%d" % int(r.level), xs == r.xparams.map(func(v): return float(v)), [xs, r.xparams])


## ⑦ 按等级学技能（烽舞 7510～7513）；经 gain_exp 升级后技能马上更新
func _learn(o: Dictionary) -> void:
	var s := _state([104])
	var a := s.actor(104)
	var slot := _wear(a, "armor", 3550)
	check("learn_slot", slot == int(o.slot), [slot, o.slot])
	var pick := func(): return a.skills().map(func(sk): return float(sk.id)).filter(func(id): return id >= 7510 and id <= 7513)
	var item: Dictionary = a.equips[slot]
	for r in o.rows:
		if r.set:
			item.level = float(r.level)
			check("learn_lv%d" % int(r.level), pick.call() == r.skills, [pick.call(), r.skills])
		else:
			item.level = 1.0
			item.exp = 0.0
			XMagicWeapon.gain_exp(item, 2000.0, a)
			check("learn_gain", [XMagicWeapon.level_of(item), XMagicWeapon.exp_of(item), pick.call()] == [_f(r.level), _f(r.exp), r.skills],
				[XMagicWeapon.level_of(item), XMagicWeapon.exp_of(item), pick.call(), r])


## 不靠参照：<Cannot Gain Exp After Victory> 不得战斗经验（经验丹照得）；等级与经验随存档往返；没装备的格不出错
func _synthetic() -> void:
	var s := _state([1])
	var a := s.actor(1)
	var slot := _wear(a, "armor", 121)
	var item: Dictionary = a.equips[slot]
	item.meta["Cannot Gain Exp After Victory"] = true
	XMagicWeapon.gain_victory_exp(s.members(), [a], [])
	XMagicWeapon.gain_victory_exp(s.members(), [a], s.members().map(func(_x): return XEnemy.new().setup(1, s.difficulty, 100.0)))
	check("cannot_gain_after_victory", XMagicWeapon.exp_of(item) == 0.0 and XMagicWeapon.level_of(item) == 1.0, [item.get("level"), item.get("exp")])
	XMagicWeapon.party_gain_exp(s, 300.0)
	check("cannot_flag_pills_still_gain", XMagicWeapon.level_of(item) > 1.0, item.get("level"))
	item.meta.erase("Cannot Gain Exp After Victory")
	var lv := XMagicWeapon.level_of(item)
	var ex := XMagicWeapon.exp_of(item)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var e2: Dictionary = back.actor(1).equips[slot]
	check("save_roundtrip", XMagicWeapon.level_of(e2) == lv and XMagicWeapon.exp_of(e2) == ex, [XMagicWeapon.level_of(e2), lv, XMagicWeapon.exp_of(e2), ex])
	XState._become_current(s)
	check("param_plus_follows_level", is_equal_approx(XActor.magic_param(item, 0), lv * float(XPower.magic_growth(XDB.rec("Armors", 121))[0])), [XActor.magic_param(item, 0), lv])
	check("no_unsupported_effects", XMagicWeapon.unsupported_effects.is_empty(), XMagicWeapon.unsupported_effects)


func _finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
