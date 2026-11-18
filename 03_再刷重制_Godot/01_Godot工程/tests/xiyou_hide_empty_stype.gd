extends "res://tests/xiyou_battle_actor_size.gd"
## 【cc·T215】战斗指令：某类技能一个都没有就不列（天启篇；Kyo 11-18「渡鸦为什么会有其他」→「所有角色统一」）。
## 核：渡鸦（167，写死 [魔法,战技,其他]）没有「其他」类技能时指令 6 项、给一个其他类技能后 7 项；开关关／西游档照旧 7 项；
##   普通角色（狗逍遥）有技能的类照旧列、与开关关逐项一样；T208 渡鸦神话 7 项紧凑指令环仍在（见 xiyou_big_form_menu）。
## 用法：Godot --audio-driver Dummy --path . res://tests/xiyou_hide_empty_stype.tscn

var _tianqi := true


func _prep(s: XState) -> void:
	s.switches[2494] = true
	s.actor_advance[XRaven.ACTOR] = 5  # 满进阶：魔法、战技类技能按真实门槛学全
	XRaven.sync(s.actor(XRaven.ACTOR))


func _texts(b: XBattleScene, a: XActor) -> Array:
	return b._command_entries(a).map(func(e): return str(e.text))


func _actor(b: XBattleScene, id: int) -> XActor:
	for a in b.logic.actors:
		if a.actor_id == id:
			return a
	return null


func _stypes(b: XBattleScene, a: XActor) -> Array:
	var out := []
	for e in b._command_entries(a):
		if str(e.get("key", "")).begins_with("stype:"):
			out.append(int(str(e.key).substr(6)))
	return out


func _run() -> void:
	XUiSkin.FORCE = true
	XSave.dir_override = "user://test_xiyou_hide_empty_stype"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XEnemy.force_roll = 100.0
	var b := await _battle(BOSS_TROOP, [167], _prep)
	if _tianqi:
		XState.current.flags["tianqi"] = {"rules": 1}  # 天启篇战斗不让渡鸦上场（锁定名单），建完战斗再打天启篇标记，只验指令过滤
	var raven := _actor(b, 167)
	_check("tianqi_active", XTianqi.active(XState.current))
	# 先量：渡鸦各类技能数（取一个其他类技能当后面的「给一个」）
	var have := {}
	for sk in b.logic.battle_skills(raven):
		have[int(sk.stypeId)] = int(have.get(int(sk.stypeId), 0)) + 1
	notes.append({"raven_stype_counts": have})
	var other: Array = raven.skills().filter(func(x): return int(x.stypeId) == 5)
	# 去掉渡鸦所有其他类技能（用 learn 表里删）
	var removed := []
	for sk in other:
		removed.append(int(sk.id))
	raven.learn_skill(_any_stype(1))  # 渡鸦本测试状态没有战技类：补一个，让指令是 魔法＋战技 两类
	_strip(raven, 5)
	_check("raven_no_other_skills", b.logic.battle_skills(raven).filter(func(x): return int(x.stypeId) == 5).is_empty(), removed)
	var t6 := _stypes(b, raven)
	_check("raven_no_other_hides", not t6.has(5), t6)
	var n6 := b._command_entries(raven).size()
	_check("raven_six_items", n6 == 6, _texts(b, raven))
	# 开关关：照旧列「其他」
	XBattleScene.HIDE_EMPTY_STYPE = false
	_check("switch_off_lists_other", _stypes(b, raven).has(5), _stypes(b, raven))
	_check("switch_off_count", b._command_entries(raven).size() == n6 + 1, [n6, b._command_entries(raven).size()])
	XBattleScene.HIDE_EMPTY_STYPE = true
	# 给一个其他类技能：7 项
	raven.learn_skill(int(_any_stype(5)))
	_check("raven_other_back", _stypes(b, raven).has(5) and b._command_entries(raven).size() == 7, [_stypes(b, raven), b._command_entries(raven).size()])
	# 次序保留 [2,1,5]
	var order := _stypes(b, raven)
	_check("raven_order_kept", order == order.duplicate() and _sorted_like(order, [2, 1, 5]), order)
	# 普通角色：有技能的类照旧（另开一场，天启篇战斗只上一个人）
	await _close(b)
	b = await _battle(BOSS_TROOP, [1], _prep)
	XState.current.flags["tianqi"] = {"rules": 1}
	var dog := _actor(b, 1)
	var dog_on := _texts(b, dog)
	XBattleScene.HIDE_EMPTY_STYPE = false
	var dog_off := _texts(b, dog)
	XBattleScene.HIDE_EMPTY_STYPE = true
	var dog_types := {}
	for sk in b.logic.battle_skills(dog):
		dog_types[int(sk.stypeId)] = true
	var stn: Array = XDB.system().skillTypes
	var gone := dog_off.filter(func(t): return not dog_on.has(t))
	var gone_empty := true
	for t in gone:
		if t in stn and dog_types.has(stn.find(t)):
			gone_empty = false
	_check("dog_only_empty_removed", gone_empty and dog_on.size() <= dog_off.size() and dog_on.filter(func(t): return dog_off.has(t)).size() == dog_on.size(), [dog_on, dog_off, dog_types.keys()])
	# 西游档（不是天启篇）：不过滤
	_check("dog_has_magic_or_skill", not _stypes(b, dog).is_empty(), _stypes(b, dog))
	await _close(b)
	_tianqi = false
	b = await _battle(BOSS_TROOP, [167], _prep)
	raven = _actor(b, 167)
	_strip(raven, 5)
	_check("xiyou_save_unfiltered", not XTianqi.active(XState.current) and _stypes(b, raven).has(5), _stypes(b, raven))
	await _close(b)
	XEnemy.force_roll = -1.0
	_finish()


func _sorted_like(got: Array, want: Array) -> bool:
	var i := 0
	for t in got:
		var j := want.find(t, i)
		if j < 0:
			return false
		i = j + 1
	return true


func _strip(a: XActor, stype: int) -> void:
	for sk in a.skills().filter(func(x): return int(x.stypeId) == stype):
		a.forget_skill(int(sk.id))


func _any_stype(st: int) -> int:
	for sk in XDB.table("Skills"):
		if sk != null and int(sk.get("stypeId", 0)) == st and int(sk.id) > XBattleLogic.GUARD_SKILL and not sk.get("meta", {}).has("Hide in Battle"):
			return int(sk.id)
	return 0
