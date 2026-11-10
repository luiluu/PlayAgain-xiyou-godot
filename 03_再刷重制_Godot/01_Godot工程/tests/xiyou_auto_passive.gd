extends Node
## 【cc·八戒·未经审查】YEP_AutoPassiveStates 与套装状态排序：与 mv_oracle/auto_passive_probe.cjs（tests/fixtures/auto_passive_oracle.json，正式引擎）逐例比。
## ①原版 plugins.js 里 YEP_AutoPassiveStates 停用：<Passive State: n> 标签不生效。护摩之杖 79、般若 49／3834 装上，终级平A 7769 学会，
##   states() 里都没有 1640／2498／1347；重制同样不加。数据里带这个标签的对象清单也逐个比（换源后多出标签会在这里报出来）。
## ②GT_EquipSuitCore.states() 接上套装状态后整表按优先级降序稳定再排：套装 8 缝合小刀（防具 487，状态 38 优先级 50）
##   与普通状态 170（0）／11（50）／27（90）一起时的先后与原版一致。
const FIXTURE := "res://tests/fixtures/auto_passive_oracle.json"
const TABLES := {"actors": "Actors", "classes": "Classes", "weapons": "Weapons", "armors": "Armors",
	"skills": "Skills", "items": "Items", "enemies": "Enemies", "states": "States"}
var passed := 0
var total := 0

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _actor(id: int) -> XActor:
	var s := XState.new_game(2, 1, [])
	XState.current = s
	var a: XActor = s.actor(id)
	a.state_ids.clear()
	a.state_turns.clear()
	return a

func _wear(a: XActor, kind: String, id: int) -> int:
	var e := XGear.template(kind, id)
	var slot := a.equip_slots().find(int(e.etypeId))
	a.equips[slot] = e
	a.refresh_passive()
	return slot

func _ids(a: XActor) -> Array:
	return a.states().map(func(st): return int(st.id))

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var cases := {}
	for c in ref.cases:
		check("oracle_" + str(c.id), c.errors.is_empty(), c.errors)
		cases[c.id] = c
	var plugin: Dictionary = cases.plugin.observed
	check("oracle_plugin_disabled", plugin.status == false and plugin.imported == false and plugin.passiveStatesFn == "undefined", plugin)
	# 带标签的对象清单（原版 passiveStates 字段都没解析出来）
	var want: Array = cases.census.observed.map(func(r): return "%s:%d" % [r.table, int(r.id)])
	check("oracle_census_unparsed", cases.census.observed.all(func(r): return r.parsed == null), cases.census.observed)
	var mine := []
	var re := RegEx.create_from_string("(?i)<passive states?:")
	for t in TABLES:
		for o in XDB.table(TABLES[t]):
			if o is Dictionary and re.search(str(o.get("note", ""))):
				mine.append("%s:%d" % [t, int(o.id)])
	check("census", mine == want, [mine, want])
	# 装备与技能：拿到手 states() 里没有被动状态
	for key in ["weapon79", "armor49", "armor3834"]:
		var c: Dictionary = cases[key]
		var a := _actor(int(c.observed.actorId))
		var slot := _wear(a, c.setup.kind, int(c.setup.itemId))
		check(key + "_slot", slot == int(c.observed.slot), [slot, c.observed.slot])
		check(key + "_states", _ids(a) == c.observed.states.map(func(v): return int(v)), [_ids(a), c.observed.states])
		check(key + "_affected", a.is_state_affected(int(c.setup.state)) == c.observed.affected)
	var sk: Dictionary = cases.skill7769
	var b := _actor(1)
	b.learn_skill(7769)
	check("skill7769_has", b.skills().any(func(s): return int(s.id) == 7769) == sk.observed.hasSkill)
	check("skill7769_states", _ids(b) == sk.observed.states.map(func(v): return int(v)), [_ids(b), sk.observed.states])
	check("skill7769_affected", b.is_state_affected(1347) == sk.observed.affected)
	# 套装状态按优先级再排
	for key in ["suit.lower", "suit.same", "suit.none", "suit.mixed"]:
		var c: Dictionary = cases[key]
		var a := _actor(int(c.observed.actorId))
		_wear(a, "armor", int(c.setup.armorId))
		check(key + "_suit", XEquipSuits.ids(a, "states") == c.observed.suitStates.map(func(v): return int(v)), [XEquipSuits.ids(a, "states"), c.observed.suitStates])
		for n in c.setup.normal:
			a.add_state(int(n))
		var got: Array = a.states().map(func(st): return [int(st.id), int(st.get("priority", 0))])
		var exp: Array = c.observed.states.map(func(r): return [int(r[0]), int(r[1])])
		check(key + "_order", got == exp, [got, exp])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
