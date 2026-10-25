extends Node
## 读进阶次数（XAdvance.rank）的三处：逐例对照冻结 v0.28 参照 tests/fixtures/advance_reads_oracle.json
## （mv_oracle/advance_reads_probe.cjs，新游戏、Math.random 0.5）。
## - cat.*：178 哈基米 10 个等级 × 进阶 0～2 次 × 是否学会 10444：XCat.advanced、进阶后成长曲线 growth、三条「进阶后…」说明文字。
## - stones.*：甚尔（进阶 0～2、已有 0～1 枚）、宿傩（进阶 0～4、已有 0～3 枚）× 随机数 0／0.5：是否得石、背包数。
## - book.*：进阶表里每个角色（另加渡鸦 167、角色 1）次数 0～最大＋1，角色图鉴「最大进阶次数」的文字。
const FIXTURE := "res://tests/fixtures/advance_reads_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(700))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (ref is Dictionary and ref.has("cases")):
		check("fixture_present", false)
		return finish()
	var cases := {}
	for c in ref.cases:
		check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors)
		cases[str(c.id)] = c.observed
	_cat(cases.cat.rows)
	_stones(cases.stones.rows)
	_book(cases.book.rows)
	finish()


const TEXTS := [[10442, "条件：进阶后额外获得1次行动"], [10443, "条件：进阶后专属剑技结算伤害+100%"],
	[10443, "条件：进阶后终技消费剑心，追加同层数神圣剑段；满层冷却减1"]]


func _cat(rows: Array) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	var a := XActor.new().setup(XCat.ACTOR)
	var bad := []
	for r in rows:
		a.change_level(int(r.level))
		s.actor_advance[XCat.ACTOR] = int(r.rank)
		if r.learned:
			a.learn_skill(XCat.SKILL_ADVANCED)
		else:
			a.forget_skill(XCat.SKILL_ADVANCED)
		var help := TEXTS.map(func(t): return XCat.help_text(t[1], XDB.rec("Skills", t[0]), a))
		var mine := {"advanced": XCat.advanced(a), "growth": snappedf(XCat.growth(a), 1e-6), "help": help}
		if int(a.level) != int(r.level) or mine.advanced != r.advanced or absf(mine.growth - float(r.growth)) > 1e-6 or help != r.help:
			bad.append([r, mine])
	check("cat.rows%d" % rows.size(), bad.is_empty() and rows.size() == 60, bad.slice(0, 3))
	check("cat.has_advanced", rows.any(func(r): return r.advanced) and rows.any(func(r): return not r.advanced and r.rank >= 1))


func _stones(rows: Array) -> void:
	var bad := []
	for r in rows:
		var s := XState.new_game_blank()
		var who: Dictionary = XDungeon.TOJI if r.who == "toji" else XDungeon.SUKUNA
		s.actor_advance[int(who.actor)] = int(r.rank)
		s.gain_item(int(who.stone), int(r.have))
		MVEventCore.fixed_random = float(r.random)
		var got := XDungeon.roll_advance_stone(s, who) != ""
		MVEventCore.fixed_random = -1.0
		if got != r.got or s.item_count(int(who.stone)) != int(r.count):
			bad.append([r, got, s.item_count(int(who.stone))])
	check("stones.rows%d" % rows.size(), bad.is_empty() and rows.size() == 52, bad.slice(0, 3))
	check("stones.both_outcomes", rows.any(func(r): return r.got) and rows.any(func(r): return not r.got and r.random == 0))


func _book(rows: Array) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	var bad := []
	for r in rows:
		s.actor_advance[int(r.actor)] = int(r.rank)
		var t := XActorBook.advance_max(int(r.actor))
		if t != str(r.text):
			bad.append([r, t])
	check("book.rows%d" % rows.size(), bad.is_empty() and rows.size() > 100, bad.slice(0, 3))


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
