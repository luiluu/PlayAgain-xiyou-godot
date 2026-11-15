class_name XSkinSkillPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】技能页新布局（套 XSkinTemplatePage 的手动用法；状态机、用技能、Q/E 换人、吸取页都还是 XSkillScene 原来的代码）。
## - 左：技能类型小环（环心是当前角色的圆头像），环下是这个角色的紧凑条（名字、Lv、职业、血蓝 TP）。
## - 中：两列技能，图标、名字（品质色）、熟练度等级小字、右侧消耗（TP 青、MP 蓝、冷却／预热橙）；不能用的变暗。
## - 右：详情牌——图标、名字、「类型 · 消耗」、说明卡的内容（XHelpCard 的行，去掉转义码）；对队友的技能选人时牌下半截是「给谁用」。
## 新皮肤关着时 XSkillScene 不建这一页。

var scene: XSkillScene
var party: XSkinPartyStrip
var _syncing := false
var _list_key := []
var _type_key := []


func _init(s: XSkillScene) -> void:
	scene = s
	name = "SkinSkillPage"
	title = "技能"
	group_key = "actor"
	columns = 2
	row_height = XUiSkin.ROW_H
	auto_nav = false
	hint_list = [["确定", "选择"], ["取消", "返回"], ["Q / E", "换人"]]


func _ready() -> void:
	super()
	party = XSkinPartyStrip.new()
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.left.add_child(party)
	ring.draw.connect(_draw_face)
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(func(_i):
		if not _syncing and scene.mode == "type":
			scene.ok())
	list.index_changed.connect(func(i):
		if _syncing:
			return
		scene.mode = "list"
		scene.index = i
		XSound.system(0)
		scene._refresh())
	list.activated.connect(func(i):
		if scene.mode == "list" and i == scene.index:
			scene.ok())
	targets.index_changed.connect(func(i):
		if not _syncing and scene.mode == "actor":
			scene.actor_pick = i
			XSound.system(0)
			scene._refresh())
	targets.activated.connect(func(_i):
		if scene.mode == "actor":
			scene.ok())
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			scene.cancel()
			accept_event())
	mouse_filter = Control.MOUSE_FILTER_PASS
	relayout()


func relayout() -> void:
	super()
	if party == null:
		return
	var lb := layout.left.size
	party.size = Vector2(lb.x, XUiSkin.MEMBER_H + 12)
	party.position = Vector2(0, lb.y - party.size.y)
	ring.position.y = maxf((lb.y - party.size.y - ring.size.y) / 2.0, 0.0)


func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.type_win, sc.status_win, sc.list_win, sc.actor_win]:
		w.visible = false
	sc.help_card.visible = false
	for c in sc.help_card.extras:
		c.visible = false
	visible = sc.absorb_page == null
	var a := sc.actor()
	party.set_members([XSkinPartyStrip.from_actor(a)])
	# 类型环
	var types := sc.types()
	var tkey := [a.actor_id, types]
	if tkey != _type_key:
		_type_key = tkey
		set_categories(types.map(func(t): return {"key": str(t), "name": sc.type_name(t), "icon": _type_icon(a, t)}), sc.type_index)
	elif ring.index != sc.type_index and sc.type_index < ring.items.size():
		ring.select(sc.type_index)
	# 列表
	var rows := []
	for sk in sc.entries():
		rows.append(_row(a, sk))
	list_title = sc.type_name(types[clampi(sc.type_index, 0, types.size() - 1)]) if not types.is_empty() else ""
	var key := [a.actor_id, sc.type_index, rows.map(func(r): return [r.text, r.get("right", ""), r.disabled, r.get("sub", "")])]
	if key != _list_key:
		_list_key = key
		set_items(rows, clampi(sc.index, 0, maxi(rows.size() - 1, 0)))
	elif list.index != sc.index and sc.index < rows.size():
		list.select(sc.index)
	_sync_card(a)
	match sc.mode:
		"type":
			set_focus("ring")
		"list":
			set_focus("list")
		"actor":
			set_focus("targets")
	ring.queue_redraw()
	list_panel.queue_redraw()
	_syncing = false


## 类型的占位图标：取这一类第一个技能的图标（美术出了分类图标再换）
func _type_icon(a: XActor, t: int) -> int:
	for sk in a.skills():
		if int(sk.get("stypeId", 0)) == t and int(sk.get("iconIndex", 0)) > 0:
			return int(sk.iconIndex)
	return 0


func _row(a: XActor, sk: Dictionary) -> Dictionary:
	var r := {"text": str(sk.get("name", "")), "icon": int(sk.get("iconIndex", 0)), "color": XQuality.list_color(sk), "disabled": not scene.usable(sk)}
	var costs := scene._costs(a, sk)
	if not costs.is_empty():
		var c: Dictionary = costs[costs.size() - 1] if costs.size() > 1 else costs[0]
		var t := str(c.text)
		r.right = t
		r.right_color = XUiSkin.DOWN if t.ends_with("CD") or t.ends_with("WU") else (XUiSkin.TP if t.ends_with("TP") else (XUiSkin.MP if t.ends_with("MP") else (XUiSkin.HP if t.ends_with("HP") else XUiSkin.TEXT_2)))
	var lv := a.skillMasteryLevelOf(int(sk.get("id", 0))) if int(sk.get("id", 0)) > 0 else 0
	if lv > 0:
		r.sub = str(XDB.plugin("YEP_SkillMasteryLevels").get("Text Format", "LV.%1")).replace("%1", XSkillScene.mastery_level_text(lv))
	return r


func _sync_card(a: XActor) -> void:
	var sc := scene
	var sk := sc.current() if sc.mode in ["list", "actor"] else {}
	if sk.is_empty():
		var types := sc.types()
		var n := sc.entries().size()
		set_card({"title": a.display_name(), "subtitle": (sc.type_name(types[clampi(sc.type_index, 0, types.size() - 1)]) + " · %d 个" % n) if not types.is_empty() else "",
			"desc": "" if n > 0 else list.empty_text})
		show_targets([])
		return
	XHelpCard.scene_actor = a
	var view := XGrowthHelp.skill_view(sk, a)
	var sub := [sc.type_name(int(sk.get("stypeId", 0)))]
	for c in sc._costs(a, sk):
		sub.append(str(c.text))
	var soul := XRaven.ledger_help(a, sk)
	var rows: Array = soul.map(func(t): return {"text": str(t), "color": XUiSkin.TEXT_2}) if not soul.is_empty() else XSkinTemplatePage.help_rows(XHelpCard.content(view, "skill", bool(view.get("skill_copy", false)), 300.0))
	set_card({"icon": XUiSkin.icon(int(sk.get("iconIndex", 0))), "title": str(sk.get("name", "")), "title_color": XQuality.list_color(sk),
		"subtitle": " · ".join(sub.filter(func(x): return str(x) != "")), "sections": [{"title": "", "rows": rows}]})
	var scope := int(sk.get("scope", 0))
	if sc.mode == "actor":
		var tr := []
		for m: XActor in XState.current.members():
			tr.append({"name": m.display_name(), "face": XUiSkin.face(str(m.data().get("faceName", "")), int(m.data().get("faceIndex", 0))),
				"kind": "hp", "cur": m.hp, "max": m.mhp, "dim": m.is_dead() != (scope in [9, 10])})
		show_targets(tr, true, scope in [8, 10], sc.actor_pick)
		targets.title = "给谁用"
	else:
		show_targets([])


func _on_ring_changed(i: int) -> void:
	if _syncing or i == scene.type_index:
		return
	scene.mode = "type"
	scene.type_index = i
	scene.index = 0
	scene.top = 0
	XSound.system(0)
	scene._refresh()


## 环心：当前角色圆头像
func _draw_face() -> void:
	var a := scene.actor()
	var face := XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	if face == null:
		return
	var c := ring.center()
	var r := ring.radius - ring.orb_radius - 26.0
	ring.draw_circle(c, r + 3, XUiSkin.ORB_LOW)
	XSkinPartyStrip.draw_round_texture(ring, face, c, r)
	ring.draw_circle(c, r + 1, Color(XUiSkin.GOLD, 0.6), false, 1.5, true)


## 类型环上左右也能换类型（旧页只认上下）；其余按键交回旧代码
func input(event: InputEvent) -> bool:
	if scene.mode != "type":
		return false
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		scene._move(-1 if event.is_action("ui_left") else 1, false, not event.is_echo())
		return true
	return false
