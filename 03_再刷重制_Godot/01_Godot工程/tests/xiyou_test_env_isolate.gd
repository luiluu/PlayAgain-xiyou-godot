extends Node
## T591：测试夹具（TestEnv.isolate、tests/lib/tq_save_kit）要把测试模式隔离掉。
## 起因：本机开发用户目录开着测试模式时，夹具不隔离，用过的技能结算后直接升满（西游档 Lv0→Lv100000，木桩每下掉约 27%），
## 本机截图、量数和云端结果对不上。这里先造一个「本机开着测试模式」（解锁文件＋状态 1），再调夹具，核：
## ① 夹具之前测试模式是开的（造的环境生效）；② isolate／Kit 之后关了；③ 西游档角色放一招结算后熟练度不跳到上限；
## ④ 对照：不隔离时同一招确实升到上限（证明 ③ 不是因为别的原因没升）；⑤ Kit.teardown 还原 override。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const Kit := preload("res://tests/lib/tq_save_kit.gd")
const FAKE := "user://test_xiyou_test_env_isolate_fake_local"
const ACTOR := 152

var results := []


func check(name: String, ok: bool, detail := "") -> void:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok:
		printerr("FAIL ", name, " ", detail)


func _ready() -> void:
	_run.call_deferred()


## 造「本机开着测试模式」：解锁文件＋状态 1，overrides 指过去
func _fake_local_on() -> void:
	DirAccess.make_dir_recursive_absolute(FAKE)
	var f := FileAccess.open(FAKE.path_join("unlock"), FileAccess.WRITE)
	f.store_string("")
	f.close()
	f = FileAccess.open(FAKE.path_join("state"), FileAccess.WRITE)
	f.store_string("1")
	f.close()
	XTestMode.unlock_override = FAKE.path_join("unlock")
	XTestMode.state_override = FAKE.path_join("state")
	XTestMode._on_loaded_from = "<unloaded>"


## 新局西游档角色放一次第一个技能，onAllActionsEnd 结算后的熟练度等级；同时返回上限
func _cast_once() -> Array:
	var s := XState.new_game_blank()
	XState.current = s
	s.add_actor(ACTOR)
	var a: XActor = s.actor(ACTOR)
	var sid := 0
	for k in a.skills():
		sid = int(k.id) if k is Dictionary else int(k)
		if sid > 0:
			break
	a.action_mastery.append(sid)
	XSkillMastery.all_actions_end(a)
	return [sid, XSkillMastery.level(a, sid), XSkillMastery.max_level(sid)]


func _run() -> void:
	# ④ 对照：没隔离时，造的「本机开着」会让一招升满
	_fake_local_on()
	check("fake_local_on", XTestMode.enabled())
	var r := _cast_once()
	check("control_without_isolate_maxes", int(r[1]) == int(r[2]) and int(r[2]) > 1, "skill=%d lv=%d max=%d" % r)

	# ①②③ TestEnv.isolate
	_fake_local_on()
	TestEnv.isolate("xiyou_test_env_isolate")
	check("isolate_turns_test_mode_off", not XTestMode.enabled())
	r = _cast_once()
	check("isolate_mastery_not_maxed", int(r[1]) < int(r[2]) and int(r[1]) <= 1, "skill=%d lv=%d max=%d" % r)

	# Kit
	_fake_local_on()
	var kit := Kit.new("xiyou_test_env_isolate_kit")
	check("kit_turns_test_mode_off", not XTestMode.enabled())
	r = _cast_once()
	check("kit_mastery_not_maxed", int(r[1]) < int(r[2]) and int(r[1]) <= 1, "skill=%d lv=%d max=%d" % r)
	kit.teardown()
	check("kit_teardown_restores", XTestMode.unlock_override == "" and XTestMode.state_override == "")

	for p in ["unlock", "state"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FAKE.path_join(p)))
	XTestMode.unlock_override = ""
	XTestMode.state_override = ""
	XTestMode._on_loaded_from = "<unloaded>"
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit(0 if passed == results.size() else 1)
