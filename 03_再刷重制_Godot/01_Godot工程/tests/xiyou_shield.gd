extends Node
## 护盾（ShieldSystem）与 mv_oracle shield_probe（generated/oracle/shield.json）逐例对照：
## grant 加盾公式（ShieldEffect 状态／装备、真气金身、已有护盾）、read 读 a.shield 的伤害公式、hit executeHpDamage（含吸取、护法）、
## gain gainHp（角色结果槽记原值、敌人记减免后）、regen 再生／流血经护盾与每回合衰减。夹具同探针：固定能力值，特性对象只有写明的状态与装备。
## 另查原版源码定下、参照不便测的：战斗结束清零、回合末倒下的也衰减、预览不写护盾、转换器把切片外的 8 条护盾公式都翻译了。

const ORACLE := "res://modes/xiyou/generated/oracle/shield.json"
const SUBJECT := [12000.0, 500.0, 321.0, 456.0, 210.0, 789.0, 100.0, 100.0]
const TARGET := [10000.0, 1000.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]

class ProbeActor extends XActor:
	var params: Array = []
	var extra: Array = []
	var hrg_fixture = null
	func param(i: int) -> float:
		return params[i] if not params.is_empty() else super.param(i)
	func trait_objects() -> Array:
		return states() + extra
	func xparam(i: int) -> float:
		return (float(hrg_fixture) if i == 7 else 0.0) if hrg_fixture != null else super.xparam(i)

class ProbeEnemy extends XEnemy:
	var params: Array = []
	var extra: Array = []
	var hrg_fixture = null
	func param(i: int) -> float:
		return params[i] if not params.is_empty() else super.param(i)
	func trait_objects() -> Array:
		return states() + extra
	func xparam(i: int) -> float:
		return (float(hrg_fixture) if i == 7 else 0.0) if hrg_fixture != null else super.xparam(i)

var checks := 0
var failures := []


func check(label: String, ok: bool, detail = null) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 12:
			print("FAIL ", label, " ", JSON.stringify(detail))
	return ok


func _fixture(b: XBattler, params: Array, hp: float, f: Dictionary) -> void:
	b.params = params
	b.state_ids.clear()
	b.state_turns.clear()
	b.hp = hp
	b.mp = 100.0
	b.tp = 55.0
	b.shield = 0.0
	b.extra = (f.get("armors", []) as Array).map(func(id): return XDB.rec("Armors", int(id)))
	for id in f.get("states", []):
		b.state_ids.append(int(id))
		b.state_turns[int(id)] = 3
	if b is XActor:
		var z = f.get("zhenqi")
		b.zhenqi = {} if z == null else {"qi": 0, "firsts": {}, "realm": int(z.realm), "pending": [], "spec": {}, "daofa": _daofa(z.daofa)}
	if f.has("hp"):
		b.hp = float(f.hp)
	if f.get("dead", false):
		b.hp = 0.0
		b.state_ids.append(1)
		b.state_turns[1] = 1
	if f.has("shield"):
		b.shield = float(f.shield)
	if f.has("hrg"):
		b.hrg_fixture = float(f.hrg)


static func _daofa(keys: Array) -> Dictionary:
	var out := {}
	for k in keys:
		out[str(k)] = 1
	return out


func _actor(id: int) -> ProbeActor:
	var a := ProbeActor.new()
	a.setup(id)
	return a


func _battlers(setup: Dictionary) -> Array:
	var enemy := ProbeEnemy.new()
	enemy.setup(int(XDB.rec("Troops", 157).members[0].enemyId), 3, 100.0)
	var a: XBattler = enemy if setup.pair == "enemy_actor" else _actor(1)
	var b: XBattler = a if setup.pair == "self" else (enemy if setup.pair == "actor_enemy" else _actor(8))
	_fixture(a, SUBJECT, 12000.0, setup.get("a", {}))
	if b != a:
		_fixture(b, TARGET, 10000.0, setup.get("b", {}))
	elif setup.has("b"):
		_fixture(b, SUBJECT, 12000.0, setup.b)
	return [a, b]


func _snap(b: XBattler, hp_damage: float) -> Dictionary:
	return {"hp": b.hp, "tp": b.tp, "shield": b.shield, "dead": b.is_dead(), "hpDamage": hp_damage, "bonus": b.shield_effect_bonus()}


func _want(o: Dictionary) -> Dictionary:
	return {"hp": o.hp, "tp": o.tp, "shield": o.shield, "dead": o.dead, "hpDamage": o.result.hpDamage, "bonus": o.bonus}


func _same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func _run_case(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var pair := _battlers(setup)
	var a: XBattler = pair[0]
	var b: XBattler = pair[1]
	var o: Dictionary = c.observed
	check(c.id + ".before", _same(_snap(b, 0.0).merged({"hpDamage": 0}), _want(o.before.b).merged({"hpDamage": 0})), [_snap(b, 0.0), o.before.b])
	var context := XResourceContext.new()
	var damage_a := 0.0
	var damage_b := 0.0
	match str(setup.kind):
		"grant", "read":
			var item := XDB.rec("Skills", int(setup.skill))
			var rows := [a.shield, b.shield]
			var preview := XFormulaExecution.run_item(item, a, b, [], {}, false, null, null)
			check(c.id + ".preview_no_write", [a.shield, b.shield] == rows and preview.available, preview)
			var out := XFormulaExecution.run_item(item, a, b, [], {}, true, XRandomStream.scripted([]), context)
			check(c.id + ".value", out.available and float(out.value) == float(o.value), [out.value, out.diagnostic, o.value])
			check(c.id + ".preview_value", float(preview.value) == float(o.value), preview.value)
		"hit":
			var logic := XBattleLogic.new()
			logic.troop_id = 157
			logic._action_resources = context
			logic.execute_hp_damage(a, b, float(setup.value), setup.get("drain", false))
		"gain":
			context.gain(b, "hp", float(setup.value))
		"regen":
			var logic := XBattleLogic.new()
			var logs := []
			if b.is_alive():
				logic._regenerate(b, logs)
			b.decay_shield()
			damage_b = float(logs[0].hp) if not logs.is_empty() else 0.0
	if str(setup.kind) != "regen":
		damage_b = float(context.result(b).hpDamage)
		damage_a = float(context.result(a).hpDamage) if a != b else damage_b
	check(c.id + ".b", _same(_snap(b, damage_b), _want(o.after.b)), [_snap(b, damage_b), _want(o.after.b)])
	if a != b:
		check(c.id + ".a", _same(_snap(a, damage_a).merged({"hpDamage": 0}), _want(o.after.a).merged({"hpDamage": 0})), [_snap(a, damage_a), _want(o.after.a)])


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("shield_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 100, ORACLE):
		check("plugin_params", _same(data.plugin, XDB.plugin("ShieldSystem")), data.plugin)
		var kinds := {}
		for c in data.cases:
			check(c.id + ".measured", c.errors.is_empty(), c.errors)
			kinds[c.setup.kind] = true
			_run_case(c)
		check("kinds", kinds.keys().size() == 5, kinds)
	_source_rules()
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit(0 if failures.is_empty() else 1)


## 参照不便测、按原版源码定下的几条
func _source_rules() -> void:
	# 转换器：切片外 107 钟离、131 椎名立希的 9 条护盾公式都翻译成程序（加盾的有写能力）
	for id in [5648, 5649, 5650, 5651, 5670, 5671, 5672, 5673, 5674]:
		var program: Dictionary = XDB.rec("Skills", id).damage.formulaProgram
		var effectful := [5648, 5651, 5671, 5672, 5674].has(id)
		check("program.%d" % id, program.status == ("effectful" if effectful else "pure")
			and (program.capabilities.has("write.shield") == effectful), program.get("diagnostic"))
	# Scene_Battle.terminate：全队（含后备）与敌群清零；BattleManager.endTurn：倒下的也衰减
	var state := XState.new_game(3, 1, [])
	XState.current = state
	var logic := XBattleLogic.new()
	logic.state = state
	logic.actors = state.battle_members()
	var enemy := XEnemy.new()
	enemy.setup(int(XDB.rec("Troops", 157).members[0].enemyId), 3, 100.0)
	logic.enemies = [enemy]
	for m in state.members():
		m.shield = 1000.0
	enemy.shield = 1000.0
	var fallen: XBattler = logic.actors[0]
	fallen.add_state(1)
	logic.end_turn()
	check("turn_end_decay_fallen", fallen.shield == 800.0 and enemy.shield == 800.0, [fallen.shield, enemy.shield])
	logic.end_battle()
	check("battle_end_clear", state.members().all(func(m): return m.shield == 0.0) and enemy.shield == 0.0)
	# addShield 非有限数按 0；负数直接扣、不吃加成、不低于 0
	var b := XBattler.new()
	b.add_shield(NAN)
	b.add_shield(-5.0)
	check("add_shield_guards", b.shield == 0.0)
	b.add_shield(10.5)
	b.add_shield(-3.0)
	check("add_shield_negative", b.shield == 7.5, b.shield)
