extends Node
## 【cc·哪吒·未经审查】角色能力末尾夹值：与 param_max_probe（tests/fixtures/param_max_oracle.json，正式引擎）逐例比对。
## 云裳 installNativeYunshangRuntime 的 Game_Actor.param 包装对所有角色最后 round(max(HP?1:0, min(paramMax, v)))，
## 装在专属模块之后、异化与种族之前：甚尔 99 级学暴君、加值 9e7 时 ×(1+等级×0.1) 乘过 99999999 被压回上限；饿狼上限 999999999999。
## 回退（XActor.FINAL_CLAMP = false）：不夹，甚尔的生命／物攻／速度超过上限。
const FIXTURE := "res://tests/fixtures/param_max_oracle.json"
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


## 探针 bare()＋changeLevel／learnSkill／各项加值
func _actor(setup: Dictionary) -> XActor:
	var s := XState.new_game_blank()
	XState.current = s
	s.actor_max_level = 99
	var id := int(setup.actor)
	var p := float(setup.plus)
	s.mv_param_plus[str(id)] = [p, p, p, p, p, p, p, p]
	var a := s.actor(id)
	a.equips.clear()
	a.skill_ids.clear()
	a.state_ids.clear()
	if int(setup.level) > 1:
		a.change_level_mv(int(setup.level))
	for sk in setup.learn:
		a.learn_skill(int(sk))
	a.param_mark_dirty()
	a.param_refresh()
	a.refresh_passive()
	a.hp = a.mhp
	return a


func _params(a: XActor) -> Array:
	var out := []
	for i in 8:
		out.append(a.param(i))
	return out


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not ref is Dictionary:
		print('TEST_RESULT={"passed":0,"total":1}')
		get_tree().quit(1)
		return
	var tyrant := {}
	for c in ref.cases:
		var o: Dictionary = c.observed
		var a := _actor(c.setup)
		var got := _params(a)
		check(c.id + ".param", got == o.param.map(func(v): return float(v)), [got, o.param])
		check(c.id + ".max", a.param_max(0) == float(o.max[0]), [a.param_max(0), o.max[0]])
		if c.id == "cap.toji_tyrant":
			tyrant = c.setup
	# 回退：不夹时甚尔暴君的生命、物攻、速度都超过 99999999（参照里正好是被压回上限的那三项）
	XActor.FINAL_CLAMP = false
	var raw := _params(_actor(tyrant))
	XActor.FINAL_CLAMP = true
	check("toji_tyrant_unclamped_original", [raw[0], raw[2], raw[6]].all(func(v): return v > XActor.PARAM_MAX), raw)
	check("cases", ref.cases.size() == 5, ref.cases.size())
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
