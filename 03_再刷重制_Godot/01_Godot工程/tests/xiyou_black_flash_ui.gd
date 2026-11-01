extends Node
## 黑闪的画面（installNativeBlackFlashRuntime.js announce 62～74、Sprite_ItemHelp.setItem 包装 208～222；文字照源码，没加参照）：
## - 黑闪成功（命中记录 custom_popups）：出手者头上弹 customPopup「黑闪！」「黑闪·二连！」…（格式 2 伤害色，第 5 次起「黑闪·n连！」），
##   战斗日志加一行「名字打出了黑闪！」；没成功不弹。
## - 弹字：锚点 (0.5, 0.5)、原地不动、最后 10 次淡出；设置「战斗伤害显示」关掉时不弹，日志照加。
## - 说明卡：黑闪技能 10225 给有配置的当前角色加两行现况（当前：集中／连闪／概率，或尚未解锁（B.status 不 valid：倒下、没学）；觉醒：生效剩余回合，或未生效）；
##   别的技能、没有当前角色、不是甚尔／宿傩都不加。
## 队伍同 xiyou_sukuna_battle（宿傩 55 级、1 号；黑闪判定的随机数按例给）。只在内存，不写存档。
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func _ready() -> void:
	_run.call_deferred()


class FlashStream extends XRandomStream:
	var flash: Array = []
	func _take(kind: String, reason: String, _event_key: String):
		draws += 1
		if kind == "float" and reason == "black_flash" and not flash.is_empty():
			return float(flash.pop_front())
		return 0.5 if kind == "float" else 2147483648


func _battle(flash: Array) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [172, 1]:
		s.actor(id).change_level_mv(55)
	s.add_actor(172)
	s.add_actor(1)
	var a := s.actor(172)
	XSukuna.sync(a)
	for id in [172, 1]:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000172")
	rand.rule = FlashStream.new()
	rand.rule.flash = flash.duplicate()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	a.tp = 100.0
	logic.start_turn()
	return [logic, a]


func _popups(logs: Array) -> Array:
	var out := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit":
			for c in l.get("custom_popups", []):
				out.append([c.target, c.text, c.format, c.log])
	return out


func _run() -> void:
	# 连闪两次（判定取 0）、第三次不中（0.99）
	var r := _battle([0.0, 0.0, 0.99])
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var name := a.display_name()
	var atk := XDB.rec("Skills", 10238)
	var got := _popups(logic.act(a, atk, logic.enemies[0]))
	check("first", got == [[a, "黑闪！", 2, name + "打出了黑闪！"]], got)
	got = _popups(logic.act(a, atk, logic.enemies[0]))
	check("second", got == [[a, "黑闪·二连！", 2, name + "打出了黑闪·二连！"]], got)
	got = _popups(logic.act(a, atk, logic.enemies[0]))
	check("miss_no_popup", got.is_empty(), got)
	check("queue_drained", XBlackFlash.announced.is_empty())
	# 第 5 次起没有现成的字：黑闪·n连！
	var c := {"chain": 4}
	XBlackFlash._announce(a, c)
	c.chain = 1
	XBlackFlash._announce(a, c)
	var labels := XBlackFlash.take_announced().map(func(x): return x.text)
	check("labels", labels == ["黑闪·5连！", "黑闪·二连！"], labels)
	# 说明卡
	var skill := XDB.rec("Skills", XBlackFlash.SKILL)
	var st := XBlackFlash.status(a)
	var rows := XBlackFlash.help_rows(skill, a)
	check("help_rows", rows.size() == 2 and rows[0] == ["当前：集中%d层；连闪%d次；概率%d%%" % [st.focus, st.chain, roundi(st.probability * 100.0)], 18, "#ffffff", false, 0]
		and rows[1][0] == ("觉醒：生效；剩余%d个完整回合" % st.remaining if st.awake else "觉醒：未生效"), [rows, st])
	check("help_rows_other_skill", XBlackFlash.help_rows(atk, a).is_empty())
	check("help_rows_other_actor", XBlackFlash.help_rows(skill, logic.state.actor(1)).is_empty())
	check("help_rows_no_actor", XBlackFlash.help_rows(skill, null).is_empty())
	XHelpCard.scene_actor = a
	var texts := XHelpCard.content(skill, "skill").map(func(x): return str(x[0]))
	check("help_card_tail", texts.size() >= 2 and texts.slice(-2) == rows.map(func(x): return x[0]), texts.slice(-3))
	XHelpCard.scene_actor = null
	texts = XHelpCard.content(skill, "skill").map(func(x): return str(x[0]))
	check("help_card_plain", not texts.any(func(t): return t.begins_with("当前：") or t.begins_with("觉醒：")), texts.slice(-3))
	logic.end_battle(0)
	# B.status 不 valid（倒下）：当前：尚未解锁
	var s2 := XState.new_game(2, 1, [8])
	XState.current = s2
	var low := s2.actor(172)
	XSukuna.sync(low)
	low.hp = 0.0
	low.add_state(1)
	var lr := XBlackFlash.help_rows(skill, low)
	check("help_rows_locked", lr.size() == 2 and lr[0][0] == "当前：尚未解锁" and lr[1][0] == "觉醒：未生效", lr)
	# 弹字本身
	var p := XDamagePopup.new()
	add_child(p)
	p.setup_custom("黑闪！", 2)
	check("popup_kind", p.kind == "custom" and p.text == "黑闪！" and p.anchor_y() == 0.5 and p._scale == 1.0 and not p._heal_color)
	for i in 79:
		p._update()
	check("popup_still", p._x == 0.0 and p._y == 0.0 and p._alpha == 1.0, [p._x, p._y, p._alpha])
	p._update()
	p._update()
	check("popup_fade", p._alpha < 1.0, p._alpha)
	p.queue_free()
	var q := XDamagePopup.new()
	q.setup_custom("回", 1)
	check("popup_heal_color", q._heal_color)
	q.free()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_black_flash_ui", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
