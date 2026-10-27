extends Node
## Star_Warehouse 难度怪物属性（$gameParty.DCultyL1～5 → 敌人 param／xparam／sparam 乘 DCL1～5）：
## 逐例对冻结 v0.28 参照 enemy_warehouse_oracle.json（难度 3～6 × 标志组合 × 敌人 1／6／193／214）。
var checks := 0
var failures: Array = []

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 40:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(400))

func near(a, b) -> bool:
	return absf(float(a) - float(b)) <= 1e-5 * maxf(1.0, absf(float(b)))

func run_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var s := XState.new_game(int(spec.difficulty), 1, [])
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = spec.flags.any(func(f): return int(f) == i)  # JSON 数字是浮点，Array.has(int) 对不上
	var e := XEnemy.new().setup(int(spec.enemy), int(spec.difficulty), 100.0)
	var o: Dictionary = c.observed
	for i in 8:
		check(c.id + ".param%d" % i, near(e.param(i), o.param[i]), [e.param(i), o.param[i]])
	for i in 10:
		check(c.id + ".xparam%d" % i, near(e.xparam(i), o.xparam[i]), [e.xparam(i), o.xparam[i]])
		check(c.id + ".sparam%d" % i, near(e.sparam(i), o.sparam[i]), [e.sparam(i), o.sparam[i]])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/enemy_warehouse_oracle.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
