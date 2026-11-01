extends Node
## 【cc·悟空·未经审查】渡鸦 167 专属法宝冥河断罪镰 4001（XRaven.param_plus，第四期）：
## 与 mv_oracle/raven_artifact_probe.cjs 的冻结 v0.28 参照（generated/oracle/raven_artifact.json）逐例比。
## - module：每级成长、上限 888 照备注（与 installNativeRavenRuntime 的 ARTIFACT_LEVEL_GROWTH／artifactMaxLevel 一致）、固定加成表；
## - params.*：渡鸦（等级、进阶、灵魂）不装与装上法宝（法宝等级 1～888）时 paramPlus(0..7) 与 param(0..7)，另核魔攻／生命的灵魂加成。
## 反向：不装法宝时 XRaven.param_plus 不加；别的角色不加。
const ORACLE := "oracle/raven_artifact.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _nums(v: Array) -> Array:
	return v.map(func(x): return float(x))


## 同参照 setup()：新局、挑战开关、队伍 [1, 167]（招募）、等级／进阶／灵魂；招募给的法宝
func _setup(level: int, rank: int, soul: float) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	XRaven.recruit(s)
	s.actor_advance[XRaven.ACTOR] = rank
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(level)
	s.raven["soul"] = soul
	var item = null
	for e in s.gear:
		if e.kind == "armor" and int(e.base) == XRaven.ARTIFACT:
			item = e
	return [s, a, item]


func _read(a: XActor) -> Dictionary:
	a.param_mark_dirty()
	a.refresh_passive()
	var plus := []
	var param := []
	for i in 8:
		plus.append(a.param_plus(i))
		param.append(a.param(i))
	return {"plus": plus, "param": param}


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not check("oracle", d is Dictionary and d.cases.size() >= 6 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		if c.id == "module":
			_module(c.observed)
		else:
			_params(c)
	_reverse()
	XState.current = null
	finish()


func _module(o: Dictionary) -> void:
	var rec := XDB.rec("Armors", XRaven.ARTIFACT)
	check("module.growth", XPower.magic_growth(rec) == _nums(o.growth) and _nums(o.proto.paramPlusPerLevel) == _nums(o.growth), [XPower.magic_growth(rec), o.growth])
	check("module.max_level", XMagicWeapon.max_level(rec) == int(o.maxLevel) and int(o.instance.maxLevel) == int(o.maxLevel), [XMagicWeapon.max_level(rec), o.maxLevel])
	check("module.base", _nums(XRaven.ARTIFACT_BASE_BONUS) == _nums(o.base), o.base)


func _params(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var o: Dictionary = c.observed
	var r := _setup(int(st.level), int(st.rank), float(st.soul))
	var s: XState = r[0]
	var a: XActor = r[1]
	check(c.id + ".item", r[2] != null)
	if r[2] == null:
		return
	var bare := _read(a)
	check(c.id + ".bare", bare.plus == _nums(o.bare.plus) and bare.param == _nums(o.bare.param), [bare, o.bare])
	var slot := a.equip_slots().find(13)
	check(c.id + ".slot", slot == int(o.slot), [slot, o.slot])
	r[2].level = float(o.itemLevel)
	check(c.id + ".equip", XEquipment.change(s, a, slot, r[2]))
	var worn := _read(a)
	check(c.id + ".worn_plus", worn.plus == _nums(o.worn.plus), [worn.plus, o.worn.plus])
	check(c.id + ".worn_param", worn.param == _nums(o.worn.param), [worn.param, o.worn.param])
	check(c.id + ".bonus", XRaven.artifact_mat_bonus(a) == float(o.matBonus) and XRaven.artifact_hp_bonus(a) == float(o.hpBonus),
		[XRaven.artifact_mat_bonus(a), XRaven.artifact_hp_bonus(a), o.matBonus, o.hpBonus])


## 反向：不装法宝不加；别的角色（孙悟空 1）原样
func _reverse() -> void:
	var r := _setup(60, 3, 123457.0)
	var a: XActor = r[1]
	check("reverse.unequipped", XRaven.param_plus(a, 4, 7.0) == 7.0 and XRaven.artifact_hp_bonus(a) == 0.0)
	var other: XActor = (r[0] as XState).actor(1)
	check("reverse.other", XRaven.param_plus(other, 0, 5.0) == 5.0)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
