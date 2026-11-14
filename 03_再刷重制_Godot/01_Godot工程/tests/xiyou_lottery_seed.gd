extends Node
## 抽奖首抽读档重掷修复专项（XLotteryRework.SEED_FROM_ORB，西游本体与天启篇共用）：从没抽过的档，存档里没有抽奖流，
## 首次抽时种子由存档种子 orb_seed 派生。走真实写盘读档（XSave.save → XSave.load_slot）、真实事件抽奖取数（MVEventCore，事件 1432）：
##   从没抽过就存档→抽→读档→再抽，整串相同；存档里去掉 orbSeed 的老档也一样；建了流没抽就存的档从种子开头接着；
##   不同存档（orb_seed 不同）首抽不同；开关关掉回到 fresh_seed（两次读档不同）；已有流的档照旧用存档里的种子与进度。

const CONFIG := "user://xiyou_lottery_seed_config.json"
const SLOT := 1
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _rolls(s: XState, n: int) -> Array:
	var core := MVEventCore.new()
	core.lottery_id = 1432
	var out := []
	for i in n:
		out.append(core._variable_random(1, 1000000))
	return out


func _load() -> XState:
	return XState.current if XSave.load_slot(SLOT) else null


func _strip_file(fn: Callable) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	fn.call(d)
	XSave._write(XSave.path(SLOT), d)


func _run_after_load(n: int) -> Array:
	var s := _load()
	return _rolls(s, n) if s != null else []


func _run() -> void:
	XMessageBox.auto = true
	XSave.dir_override = "user://test_xiyou_lottery_seed"
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	XConfig._loaded_path = "<unloaded>"
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	_check("never_drawn", s.lottery_random.is_empty())
	_check("saved", XSave.save(SLOT))
	var raw = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	_check("file_no_stream", (raw.get("lotteryRandom", {}) as Dictionary).is_empty())
	var a := _run_after_load(10)
	var b := _run_after_load(10)
	_check("first_draws_same", a.size() == 10 and a == b, [a, b])
	_check("draws_vary", a.any(func(x): return x != a[0]), a)
	# 抽过之后存档：接着抽也一样（原有的 O-389 行为）
	_load()
	_rolls(XState.current, 3)
	XSave.save(SLOT)
	var c := _run_after_load(5)
	_check("continue_same", c == a.slice(3, 8), [c, a])
	# 老档：没有 orbSeed（由存档内容算），也没有抽奖流
	_strip_file(func(d): d.erase("orbSeed"); d.erase("lotteryRandom"))
	var o1 := _run_after_load(6)
	var o2 := _run_after_load(6)
	_check("no_orb_same", o1.size() == 6 and o1 == o2, [o1, o2])
	# 建了流还没抽就存了（存档里有种子、没进度）：从种子开头，两次一样
	_load()
	XLotteryRework.stream(XState.current)
	XSave.save(SLOT)
	raw = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(SLOT)))
	_check("seed_only_saved", (raw.lotteryRandom as Dictionary).has("seed") and not (raw.lotteryRandom as Dictionary).has("state"), raw.lotteryRandom)
	_check("seed_only_same", _run_after_load(6) == _run_after_load(6))
	# 存档里的种子（旧版现开的、不是 orb_seed 派生的）没有进度：照用这颗种子
	_strip_file(func(d): d["lotteryRandom"] = {"seed": "0123456789abcdef", "draws": 0})
	var want := RandomNumberGenerator.new()
	want.seed = XRandomStream.parse64("0123456789abcdef")
	var w := []
	for i in 6:
		w.append(want.randi_range(1, 1000000))
	_check("old_seed_kept", _run_after_load(6) == w, w)
	# 不同存档（orb_seed 不同）首抽不同
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s2
	var other := _rolls(s2, 10)
	var s3 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s3
	s3.orb_seed = s2.orb_seed
	_check("orb_decides", _rolls(s3, 10) == other and other != a, [other, a])
	# 开关关掉：没有流的档每次读档现开（fresh_seed），两次不同
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	XSave.save(SLOT)
	XLotteryRework.SEED_FROM_ORB = false
	var f1 := _run_after_load(10)
	var f2 := _run_after_load(10)
	XLotteryRework.SEED_FROM_ORB = true
	_check("off_fresh", f1 != f2, [f1, f2])
	XSave.remove(SLOT)
	XSave.dir_override = ""
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
