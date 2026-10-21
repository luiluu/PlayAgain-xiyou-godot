extends Node
## 导入角色平衡（XImportedBalance）：逐例对照 mv_oracle/imported_balance_probe.cjs（generated/oracle/imported_balance.json）。
## 参照在战斗者实例上记下每次最外层结算调用的缩放前原值；这里按同一顺序把原值重放进 Godot 对应入口，
## 比每次的弹字与最后的 HP／MP／护盾：
## - executeHpDamage → execute_hp_damage（类型 5 为吸血；魔法反射回自己时 _reflecting）
## - executeMpDamage → execute_mp_damage（类型 6 为吸取）
## - 序列 gainHp／gainMp → sequence_gain（序列用例带行动者，无上下文用例不带）
## - regenerateHp → _regenerate（敌人带由行动者附加的中毒 4；*.rec.* 例另按 setup.states 加 REC／HRG 测试状态与混合来源）
## 伤害公式与能力值不在此比（各角色的伤害行由 rules／custom_damage 管）；禁用角色另跑真实 apply／execute 确认对目标无效。
var results := []
## caps.a<行动者> 用例：夹具开战后各战斗者的生命／魔法上限
var caps := {}


## 参照把双方生命加到很大；生命／魔法上限照参照读数（caps），免得 Godot 自己的上限截掉重放的值
class BigEnemy extends XEnemy:
	var caps := [1.0e15, 1.0e15]
	func param(i: int) -> float:
		return caps[i] if i < 2 else super(i)


class BigActor extends XActor:
	var caps := [1.0e15, 1.0e15]
	func param(i: int) -> float:
		return caps[i] if i < 2 else super(i)


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _logic() -> XBattleLogic:
	var logic := XBattleLogic.new()
	logic.troop_id = 0  # 不经真气减伤（参照角色没有道法）
	logic._action_resources = XResourceContext.new()
	logic._action_resources.random = XRandomStream.create("123456789abcdef0", "rule")
	return logic


func _battler(k: String) -> XBattler:
	if k.begins_with("a"):
		return BigActor.new().setup(int(k.substr(1)))
	return BigEnemy.new().setup(int(XDB.rec("Troops", 2).members[0].enemyId), 3, 100.0)


## 参照 setup.fake 的测试状态（只有给定特性）在 Godot 建一份同形的，同名复用
var fakes := {}
func _fake_state(name: String, fake: Dictionary) -> int:
	if not fakes.has(name):
		var t: Array = XDB.table("States")
		fakes[name] = t.size()
		t.append({"id": t.size(), "name": "测试·" + name, "traits": fake[name].traits, "note": "", "meta": {}, "iconIndex": 0,
			"restriction": 0, "priority": 50, "autoRemovalTiming": 0, "minTurns": 1, "maxTurns": 1, "removeAtBattleEnd": false})
	return fakes[name]


func _replay(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var logic := _logic()
	var bs := {}
	for row in o.log:
		for k in [row.target, row.get("subject")]:
			if k != null and not bs.has(str(k)):
				bs[str(k)] = _battler(str(k))
	for row in o.log:  # 每个战斗者按第一次出现时的读数起步
		var b: XBattler = bs[str(row.target)]
		if not b.has_meta("seeded"):
			b.set_meta("seeded", true)
			var cap: Dictionary = caps.get(int(c.setup.get("actor", 141)), {}).get(str(row.target), {})
			if not cap.is_empty():
				b.caps = [float(cap.mhp), float(cap.mmp)]
			b.hp = float(row.before.hp)
			b.mp = float(row.before.mp)
			b.shield = float(row.before.shield)
	var subject: XBattler = bs.get("a%d" % int(c.setup.actor)) if c.setup.has("actor") else null
	if subject == null and c.setup.has("actor"):
		subject = _battler("a%d" % int(c.setup.actor))
	var type := int(c.setup.get("type", 1))
	var i := 0
	for row in o.log:
		if int(row.depth) != 0:
			continue
		var t: XBattler = bs[str(row.target)]
		var name := "%s.%d.%s" % [c.id, i, row.fn]
		i += 1
		match str(row.fn):
			"executeHpDamage":
				var u: XBattler = bs[str(row.subject)]
				logic._reflecting = str(c.id).begins_with("reflect.") and row.subject == row.target
				logic._action_resources.slots.erase(t)
				logic.execute_hp_damage(u, t, float(row.args[0]), type == 5)
				logic._reflecting = false
				check(name + ".popup", logic._action_resources.result(t).hpDamage == float(row.popup.hp), [logic._action_resources.result(t), row.popup])
			"executeMpDamage":
				var u: XBattler = bs[str(row.subject)]
				logic._action_resources.slots.erase(t)
				logic.execute_mp_damage(u, t, float(row.args[0]), type == 6)
				check(name + ".popup", logic._action_resources.result(t).mpDamage == float(row.popup.mp), [logic._action_resources.result(t), row.popup])
			"gainHp", "gainMp":
				var seq := subject if str(c.id).begins_with("sequence.") else null
				var shown := logic.sequence_gain(t, "HP" if row.fn == "gainHp" else "MP", float(row.args[0]), seq)
				check(name + ".popup", -shown == float(row.popup.hp if row.fn == "gainHp" else row.popup.mp), [shown, row.popup])
			"regenerateHp":
				if c.setup.has("states"):
					# REC≠1 例：依次按附加者加状态（null＝无来源），fake 名换成同形的 Godot 测试状态
					for pair in c.setup.states:
						var src = pair[1]
						var by: XBattler = null
						if src != null:
							by = subject if str(src) == "a%d" % int(c.setup.actor) else bs.get(str(src))
							if by == null:
								by = _battler(str(src))
						XImportedBalance.set_acting(by)
						t.add_state(_fake_state(str(pair[0]), c.setup.fake) if pair[0] is String else int(pair[0]))
					XImportedBalance.set_acting(null)
					check(name + ".rec", is_equal_approx(t.rec, float(o.rec)), [t.rec, o.rec])
				else:
					XImportedBalance.set_acting(subject)
					t.add_state(int(c.setup.state))
					XImportedBalance.set_acting(null)
				check(name + ".hrg", is_equal_approx(t.hrg, float(o.hrg)), [t.hrg, o.hrg])
				logic._regenerate(t, [])
			_:
				check(name + ".known", false, row.fn)
	for s in o.after:
		if bs.has(str(s.key)) and bs[str(s.key)].has_meta("seeded"):
			var b: XBattler = bs[str(s.key)]
			check("%s.%s.after" % [c.id, s.key], b.hp == float(s.hp) and b.mp == float(s.mp) and b.shield == float(s.shield),
				[[b.hp, b.mp, b.shield], s])


## 禁用角色：参照里对目标没有任何结算；Godot 真实 apply 与 execute（含行动序列）都不动目标
func _disabled(c: Dictionary) -> void:
	# 参照里禁用角色的行动不产生结算（DOT 例的 regenerateHp 是用例自己调的，没有状态、HP 不变）
	check(c.id + ".mv_no_change", c.observed.log.all(func(r): return r.fn == "regenerateHp" and r.before.hp == r.after.hp), c.observed.log)
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(141)
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var a := XActor.new().setup(int(c.setup.actor))
	var e: XEnemy = logic.enemies[0]
	var hp := e.hp
	var skill := XDB.rec("Skills", int(c.setup.get("skill", 1)))
	check(c.id + ".blocks", XImportedBalance.blocks(a, skill))
	logic.apply(a, skill, e)
	logic.execute(a, skill, e, true)
	check(c.id + ".untouched", e.hp == hp and e.state_ids == logic.enemies[0].state_ids, [e.hp, hp])


func _run() -> void:
	var ref = XDB.load_json("oracle/imported_balance.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	for c in ref.cases:
		if str(c.id).begins_with("caps.") and c.errors.is_empty():
			var m := {}
			for x in c.observed.caps:
				m[str(x.key)] = x
			caps[int(c.setup.actor)] = m
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if str(c.id).begins_with("caps."):
			continue
		if not c.errors.is_empty():
			continue
		if c.id == "module.rates":
			var ids: Array = c.setup.actors
			check("rates", ids.map(func(id): return XImportedBalance.outgoing_rate(int(id))) == c.observed.rates.map(func(x): return float(x)),
				[ids.map(func(id): return XImportedBalance.outgoing_rate(int(id))), c.observed.rates])
			check("disabled", ids.map(func(id): return XImportedBalance.is_disabled_actor(int(id))) == c.observed.disabled, c.observed.disabled)
			check("horns", XImportedBalance.DISABLED_HORNS == c.setup.horns.map(func(x): return int(x)), c.setup.horns)
		elif int(c.setup.get("actor", 0)) == 143:
			_disabled(c)
		else:
			_replay(c)
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
