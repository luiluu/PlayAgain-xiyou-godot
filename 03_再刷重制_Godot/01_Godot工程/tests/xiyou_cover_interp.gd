extends Node
## xiyou_event_compare --coverage 的下标记录（BK）：101 把紧跟的 401／102／103 一起消费，这些续行下标也要记为执行到。
var total := 0
var passed := 0
func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))
func _cmd(code: int, params: Array, indent := 0) -> Dictionary:
	return {"code": code, "indent": indent, "parameters": params}
func _run(list: Array) -> Array:
	var cover := {}
	var ci = preload("res://tests/xiyou_event_compare.gd").CoverInterp.new(null, 1, 1, list)
	ci.cover = cover
	ci.cover_label = "m1e1p1"
	ci._execute(list[0])
	var keys := cover.keys()
	keys.sort()
	return keys
func _ready() -> void:
	XState.current = XState.new_game_blank()
	# 101＋401＋401＋103：下标 0..3 都算执行到
	check("message_number", _run([_cmd(101, ["", 0, 0, 2]), _cmd(401, ["a"]), _cmd(401, ["b"]), _cmd(103, [5, 3]), _cmd(108, ["x"])]) == ["m1e1p1:0", "m1e1p1:1", "m1e1p1:2", "m1e1p1:3"])
	# 101＋401＋102（选项合成一条）：0..2；102 的分支行 402 不算
	check("message_choice", _run([_cmd(101, ["", 0, 0, 2]), _cmd(401, ["a"]), _cmd(102, [["是", "否"], 1, 0, 2, 0]), _cmd(402, [0], 1), _cmd(0, [], 2)]).slice(0, 3) == ["m1e1p1:0", "m1e1p1:1", "m1e1p1:2"])
	# 单独一条指令只记自己
	check("single", _run([_cmd(108, ["注释"]), _cmd(108, ["注释"])]) == ["m1e1p1:0"])
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
