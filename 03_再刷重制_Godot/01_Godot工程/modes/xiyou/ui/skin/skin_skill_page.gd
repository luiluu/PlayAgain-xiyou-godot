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
var _sprite_layer: Control
var _sprite_step := 0
var confirm_dlg: XSkinConfirm
var _card_actions: Array = []


func _init(s: XSkillScene) -> void:
	scene = s
	name = "SkinSkillPage"
	title = "技能"
	group_key = "actor"
	columns = 2
	row_height = XUiSkin.ROW_H
	auto_nav = false
	if XSkinRingNav.INNER_V2:
		currencies = []   # R21：这页不花钱，右上不放精魂（同装备页）
	hint_list = [["确定", "选择"], ["取消", "返回"], ["Q / E", "换人"]]


func _ready() -> void:
	super()
	party = XSkinPartyStrip.new()
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.left.add_child(party)
	ring.draw.connect(_draw_face)
	_ensure_sprite_layer()
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
	card_button.connect(_on_card_button)
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


## 整段包只读窗口（XSkillScene.read_only，T545）：每按一下都重建本类全部行，每行读好几次能力值
func sync() -> void:
	XSkillScene.read_only(_sync_now)


func _sync_now() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.type_win, sc.status_win, sc.list_win, sc.actor_win, sc.secret_win]:
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
		_put_glyphs(types)
	elif ring.index != sc.type_index and sc.type_index < ring.items.size():
		ring.select(sc.type_index)
	# 列表
	var st: int = int(types[clampi(sc.type_index, 0, types.size() - 1)]) if not types.is_empty() else 0
	var rows := []
	for sk in sc.entries():
		rows.append(_row(a, sk))
	list_title = XTianqiSecrets.ui_list_title(sc.type_name(st), a, st) if not types.is_empty() else ""
	if XSkinRingNav.INNER_V2:
		currencies = XTianqiSecrets.ui_gold_currency(XState.current) if XTianqiSecrets.is_secret_stype(st) else []
		if top_layer != null:
			top_layer.queue_redraw()
	var key := [a.actor_id, sc.type_index, list_title, rows.map(func(r): return [r.text, r.get("right", ""), r.disabled, r.get("sub", ""), r.get("reason", "")])]
	if key != _list_key:
		_list_key = key
		set_items(rows, clampi(sc.index, 0, maxi(rows.size() - 1, 0)))
	elif list.index != sc.index and sc.index < rows.size():
		list.select(sc.index)
	_sync_card(a)
	_sync_secret_confirm()
	match sc.mode:
		"type":
			set_focus("ring")
		"list", "secret_confirm":
			set_focus("list")
		"actor":
			set_focus("targets")
	ring.queue_redraw()
	list_panel.queue_redraw()
	match sc.mode:
		"type":
			set_hint_list([["确定", "选择"], ["取消", "返回"], ["Q / E", "换人"]])
		"list":
			var acc := XTianqiSecrets.ui_accept_hint(a, sc.current())
			set_hint_list([["确定", acc if not acc.is_empty() else "选择"], ["取消", "回类型"], ["Q / E", "翻页"]])   # 列表里 Q/E 是翻页（同旧页）
		_:
			set_hint_list([["确定", "选择"], ["取消", "返回"]])   # 选人时 Q/E 不换人
	_syncing = false


## 类型的占位图标：取这一类第一个技能的图标（美术出了分类图标再换）
func _type_icon(a: XActor, t: int) -> int:
	for sk in a.skills():
		if int(sk.get("stypeId", 0)) == t and int(sk.get("iconIndex", 0)) > 0:
			return int(sk.iconIndex)
	return 0


## R6：类型球里写一个字（战技→战、魔法→魔、功法→功、被动→被、其他→他；呼吸法类→呼、伊莉雅被动→专、光环→环；待小A审）。
## 映射表里没有的类型名取第一个字；同一个环上撞字时（如同时有「呼吸法」「鬼灭呼吸法」）后来的从名字第 2 字起顺找没用过的字（鬼灭呼吸法→灭）
const TYPE_GLYPH := {"战技": "战", "魔法": "魔", "功法": "功", "被动": "被", "其他": "他", "呼吸法": "呼", "鬼灭呼吸法": "呼", "伊莉雅被动": "专", "光环": "环"}


func _put_glyphs(types: Array) -> void:
	if not XSkinRingNav.INNER_V2:
		return
	var used := []
	for k in mini(ring.items.size(), types.size()):
		var g := glyph_of(scene.type_name(int(types[k])), used)
		used.append(g)
		ring.items[k]["glyph"] = g
	ring.queue_redraw()


static func glyph_of(type_name: String, used := []) -> String:
	if type_name == "":
		return "他"
	var g := "专" if type_name == XTextFix.actor_name(124, "伊莉雅") + "被动" else str(TYPE_GLYPH.get(type_name, type_name.substr(0, 1)))
	if used.has(g):   # 撞字：从第 2 字起找没用过的
		for i in range(1, type_name.length()):
			if not used.has(type_name.substr(i, 1)):
				return type_name.substr(i, 1)
	return g


## R13：技能名颜色走皮肤的品质色（「优秀」已调柔）；没有品质标记的照旧
static func name_color(sk: Dictionary) -> Color:
	if XSkinRingNav.INNER_V2 and XQuality.has_quality(sk):
		return XUiSkin.quality_color(clampi(XQuality.show_grade(sk), 0, 6))
	return XQuality.list_color(sk)


func _row(a: XActor, sk: Dictionary) -> Dictionary:
	var sm := XTianqiSecrets.ui_row_meta(a, sk)
	var sealed := bool(sm.get("sealed", false))
	var r := {"text": str(sk.get("name", "")), "icon": int(sk.get("iconIndex", 0)), "color": name_color(sk), "disabled": sealed or not scene.usable(sk)}
	if r.disabled and XSkinList.T366_V1 and sm.is_empty():   # T366 R12：非秘籍用不了的行，行尾写原因；秘籍操作改放底栏提示，避免 16:9 挤坏技能名
		r.reason = skill_reason(a, sk)
	var costs := scene._costs(a, sk)
	if not costs.is_empty():
		var c: Dictionary = costs[costs.size() - 1] if costs.size() > 1 else costs[0]
		var t := str(c.text)
		r.right = t
		r.right_color = XUiSkin.DOWN if t.ends_with("CD") or t.ends_with("WU") else (XUiSkin.TP if t.ends_with("TP") else (XUiSkin.MP if t.ends_with("MP") else (XUiSkin.HP if t.ends_with("HP") else XUiSkin.TEXT_2)))
	elif sm.has("badge"):
		r.right = str(sm.badge)
		r.right_color = XUiSkin.DOWN if sealed else XUiSkin.GOLD
	var lv := a.skillMasteryLevelOf(int(sk.get("id", 0))) if int(sk.get("id", 0)) > 0 else 0
	if lv > 0:
		r.sub = str(XDB.plugin("YEP_SkillMasteryLevels").get("Text Format", "LV.%1")).replace("%1", XSkillScene.mastery_level_text(lv))
	return r


## T366 R12：菜单里用不了的原因一句话（战斗专用、不能用走固定句；其余沿用战斗里的禁放原因 XSkinBattle.reason：TP／MP 不够、被封印、冷却……）
func skill_reason(a: XActor, sk: Dictionary) -> String:
	var occ := int(sk.get("occasion", 0))
	if occ == 1:
		return "战斗专用"
	if occ not in [0, 2]:
		return "不可用"
	var q := sk
	if occ == 2:   # 菜单专用：同 skill_scene 改成 0 再问原因，别被吞成「当前条件不满足」
		q = sk.duplicate()
		q["occasion"] = 0
	return XSkinBattle.reason(scene.logic, a, q, false)


func _sync_card(a: XActor) -> void:
	var sc := scene
	var sk := sc.current() if sc.mode in ["list", "actor", "secret_confirm"] else {}
	if sk.is_empty():
		var types := sc.types()
		var n := sc.entries().size()
		_card_actions = []
		var sub0 := (sc.type_name(types[clampi(sc.type_index, 0, types.size() - 1)]) + " · %d 个" % n) if not types.is_empty() else ""
		var st0: int = int(types[clampi(sc.type_index, 0, types.size() - 1)]) if not types.is_empty() else 0
		var slot0 := XTianqiSecrets.ui_slot_text(a) if XTianqiSecrets.is_secret_stype(st0) else ""
		if not slot0.is_empty():
			sub0 = "%s · %s" % [sub0, slot0] if not sub0.is_empty() else slot0
		set_card({"title": a.display_name(), "subtitle": sub0,
			"desc": "" if n > 0 else list.empty_text})
		show_targets([])
		return
	XHelpCard.scene_actor = a
	var view := XGrowthHelp.skill_view(sk, a)
	var sub := [sc.type_name(int(sk.get("stypeId", 0)))]
	for c in sc._costs(a, sk):
		sub.append(str(c.text))
	var sec_act := XTianqiSecrets.ui_card_actions(XState.current, a, sk)
	_card_actions = sec_act.get("buttons", []) if not sec_act.is_empty() else []
	if sec_act.has("tag") and str(sec_act.tag) != "":
		sub.append(str(sec_act.tag))
	var soul := XRaven.ledger_help(a, sk)
	var help := XHelpCard.content(view, "skill", bool(view.get("skill_copy", false)), 300.0) if soul.is_empty() else []
	var rows: Array = soul.map(func(t): return {"text": str(t), "color": XUiSkin.TEXT_2}) if not soul.is_empty() else XSkinTemplatePage.help_rows(help)
	# T288 卡 S：长说明卡分节（XHelpCard.SECTIONS 关＝照旧一节无标题）；牌头小字仍用本页的「类型 · 消耗」
	var split := XHelpCard.SECTIONS and soul.is_empty()
	var sd := XHelpCard.skin_card_data(help, view) if split else {}
	card.fold = split
	set_card({"icon": XUiSkin.icon(int(sk.get("iconIndex", 0))), "title": str(sk.get("name", "")), "title_color": name_color(sk),
		"subtitle": " · ".join(sub.filter(func(x): return str(x) != "")), "desc": sd.get("desc", ""), "sections": sd.sections if split else [{"title": "", "rows": rows}],
		"buttons": _card_actions})
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
	if not scene.mode in ["type", "list"]:   # 选人时点环不跨态（同旧页：选人窗盖住类型窗）
		ring.select(scene.type_index, false)
		return
	scene.mode = "type"
	scene.type_index = i
	scene.index = 0
	scene.top = 0
	XSound.system(0)
	scene._refresh()


## 环心：R6 像素小人（同主菜单，XUiSkin.CENTER_STYLE；没有侧视图时回头像）；回退时旧的圆头像
func _use_sprite(a: XActor) -> bool:
	return XSkinRingNav.INNER_V2 and XUiSkin.CENTER_STYLE != XUiSkin.CenterStyle.FACE and XSkinMainMenu.sv_frame(a) != null


func _ensure_sprite_layer() -> void:
	if _sprite_layer != null or ring == null:
		return
	_sprite_layer = Control.new()
	_sprite_layer.name = "SvSprite"
	_sprite_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite_layer.draw.connect(_draw_sprite)
	ring.add_child(_sprite_layer)
	var t := Timer.new()   # 待机动作每格 0.2 秒，同主菜单；动效「全部」档才动
	t.wait_time = 0.2
	t.autostart = true
	t.timeout.connect(func():
		if XUiSkin.breathing() and _sprite_layer.visible:
			_sprite_step += 1
			_sprite_layer.queue_redraw())
	_sprite_layer.add_child(t)


## 像素小人（摆法同 XSkinMainMenu._draw_sprite：整数倍最多 3 倍、人按不透明范围居中、脚下黑椭圆影＋淡金受光）
func _draw_sprite() -> void:
	var a := scene.actor()
	if not _use_sprite(a):
		return
	var fr := XSkinMainMenu.sv_frame(a, _sprite_step if XUiSkin.breathing() else 1)
	if fr == null:
		return
	var used: Rect2 = XSkinMainMenu._sv_info(a, XAppearance.look_key(a)).used
	var c := ring.center()
	var rad := ring.radius - ring.orb_radius - 26.0
	var k := clampi(floori(rad * 2.0 * 0.9 / maxf(used.size.x, used.size.y)), 1, 3)
	var origin := (c - (used.position + used.size / 2.0) * k).round()
	var feet := Vector2(c.x, origin.y + used.end.y * k - 6.0)
	var shadow := PackedVector2Array()
	for i in 24:
		shadow.append(feet + Vector2(cos(TAU * i / 24.0) * 48.0, sin(TAU * i / 24.0) * 12.0))
	_sprite_layer.draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
	_sprite_layer.draw_arc(feet, 52.0, 0, TAU, 32, Color(XUiSkin.GOLD, 0.25), 1.5, true)
	_sprite_layer.draw_texture_rect(fr, Rect2(origin, fr.get_size() * k), false)


func _draw_face() -> void:
	var a := scene.actor()
	if _sprite_layer != null:
		_sprite_layer.visible = _use_sprite(a)
		_sprite_layer.queue_redraw()
	if _use_sprite(a):
		return
	var face := XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
	if face == null:
		return
	var c := ring.center()
	var r := ring.radius - ring.orb_radius - 26.0
	ring.draw_circle(c, r + 3, XUiSkin.ORB_LOW)
	XSkinPartyStrip.draw_round_texture(ring, face, c, r)
	ring.draw_circle(c, r + 1, Color(XUiSkin.GOLD, 0.6), false, 1.5, true)


func _on_card_button(i: int) -> void:
	if i < 0 or i >= _card_actions.size():
		return
	var act := str(_card_actions[i].get("action", ""))
	if act == "finish_free":
		if XTianqiSecrets.ui_exec_action(XState.current, scene.actor(), "finish_free", 0):
			scene._free_pick_touched.erase(scene.actor().actor_id)
			scene._refresh()
		return
	if act in ["seal", "unseal"]:
		scene.open_secret_confirm()


func _sync_secret_confirm() -> void:
	if scene.mode != "secret_confirm" or scene.secret_spec.is_empty():
		if confirm_dlg != null:
			confirm_dlg.close()
			confirm_dlg = null
		return
	var d := {
		"title": str(scene.secret_spec.get("title", "")),
		"body": str(scene.secret_spec.get("body", "")),
		"danger": bool(scene.secret_spec.get("danger", false)),
		"buttons": scene.secret_spec.get("buttons", []),
		"index": scene.secret_pick,
	}
	if confirm_dlg == null:
		confirm_dlg = XSkinConfirm.open(self, d)
		confirm_dlg.index_changed.connect(func(i):
			scene.secret_pick = i
			XSound.system(0))
		confirm_dlg.chosen.connect(func(i):
			scene.confirm_secret_choice(i))
		confirm_dlg.cancelled.connect(func():
			XSound.system(2)
			scene.close_secret_confirm())
	else:
		confirm_dlg.setup(d)


## 类型环上左右也能换类型（旧页只认上下）；确认弹窗开着时拦截全部按键；其余按键交回旧代码
func input(event: InputEvent) -> bool:
	if confirm_dlg != null:
		return confirm_dlg.handle_input(event)
	if scene.mode != "type":
		return false
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		scene._move(-1 if event.is_action("ui_left") else 1, false, not event.is_echo())
		return true
	return false
