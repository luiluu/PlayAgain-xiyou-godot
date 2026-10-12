class_name XBattleScene
extends Control
## 侧视战斗画面。规则在 XBattleLogic；这里负责选指令、播放行动记录（动作、动画、伤害数字）、结算界面。
## 结束时发出 finished(0 胜利 / 1 逃跑 / 2 战败)。

signal finished(result: int)
signal _picked(value)

var logic := XBattleLogic.new()
var map_data: Dictionary
var troop_id := 0
var can_lose := false
var sprites := {}                 # XBattler -> XBattlerSprite
var field: Node2D
var fx: Node2D
var status_box: HBoxContainer
var command_box: VBoxContainer
var list_panel: PanelContainer
var banner: Label
var auto_btn: Button
var speed_btn: Button
var bgm: AudioStreamPlayer
var se: AudioStreamPlayer
var _target_mode := ""            # "enemy" / "ally" / ""
var _fast := false
## 自动测试用：强制自动战斗，胜利界面自动关闭。
static var force_auto := false


func setup(troop: int, escape: bool, lose: bool, map: Dictionary) -> void:
	troop_id = troop
	can_lose = lose
	map_data = map
	logic.can_escape = escape
	logic.setup(troop, XState.current)
	logic.auto = force_auto


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport_rect().size
	_build_background(vs)
	field = Node2D.new()
	add_child(field)
	fx = Node2D.new()
	add_child(fx)
	_place_battlers(vs)
	_build_ui()
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	se = AudioStreamPlayer.new()
	add_child(se)
	var music: Dictionary = XDB.system().battleBgm
	var p := XDB.audio_path("bgm", str(music.name))
	if p != "":
		bgm.stream = load(p)
		bgm.volume_db = linear_to_db(float(music.volume) / 100.0)
		bgm.play()
	_main.call_deferred()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---- 布局 ----
func _build_background(vs: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var names := [str(map_data.get("battleback1Name", "")), str(map_data.get("battleback2Name", ""))]
	if names[0] == "":
		names = [str(XDB.system().battleback1Name), str(XDB.system().battleback2Name)]
	for i in range(2):
		var p := XDB.img_path("battlebacks%d" % (i + 1), names[i]) if names[i] != "" else ""
		if p == "":
			continue
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(t)


func _place_battlers(vs: Vector2) -> void:
	var field_h := vs.y - 210.0
	for e in logic.enemies:
		var s := XBattlerSprite.new()
		field.add_child(s)
		var tex_h := 60.0
		s.setup(e, 1.0)
		tex_h = s.height()
		s.scale = Vector2.ONE * clampf(150.0 / maxf(tex_h, 1.0), 1.0, 2.6)
		s.home = Vector2(float(e.get_meta("x")) / 1280.0 * vs.x * 0.62 + 40.0, float(e.get_meta("y")) / 720.0 * field_h * 0.9 + 70.0)
		s.position = s.home
		sprites[e] = s
	for i in range(logic.actors.size()):
		var a: XActor = logic.actors[i]
		var s := XBattlerSprite.new()
		field.add_child(s)
		s.setup(a, 1.75)
		s.home = Vector2(vs.x - 330.0 + i * 36.0, 170.0 + i * (field_h - 120.0) / 4.0)
		s.position = s.home + Vector2(300, 0)
		sprites[a] = s
		var t := create_tween()
		t.tween_property(s, "position", s.home, 0.4).set_delay(0.05 * i)


func _build_ui() -> void:
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", XUI.panel())
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -190
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -12
	add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bottom.add_child(row)
	command_box = VBoxContainer.new()
	command_box.custom_minimum_size.x = 210
	command_box.add_theme_constant_override("separation", 6)
	row.add_child(command_box)
	status_box = HBoxContainer.new()
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_theme_constant_override("separation", 14)
	row.add_child(status_box)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	auto_btn = XUI.button("自动：关", 48)
	auto_btn.pressed.connect(func():
		logic.auto = not logic.auto
		_refresh_auto()
		if logic.auto:
			_picked.emit("auto"))
	side.add_child(auto_btn)
	speed_btn = XUI.button("速度 ×1", 48)
	speed_btn.pressed.connect(func():
		_fast = not _fast
		Engine.time_scale = 2.0 if _fast else 1.0
		speed_btn.text = "速度 ×2" if _fast else "速度 ×1")
	side.add_child(speed_btn)
	banner = XUI.label("", 26, XUI.TEXT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 22
	banner.offset_left = -300
	banner.offset_right = 300
	banner.add_theme_constant_override("outline_size", 6)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(banner)
	list_panel = PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", XUI.panel(true))
	list_panel.set_anchors_preset(Control.PRESET_CENTER)
	list_panel.visible = false
	add_child(list_panel)
	_refresh_status()
	_refresh_auto()


func _refresh_auto() -> void:
	auto_btn.text = "自动：开" if logic.auto else "自动：关"


func _refresh_status(current: XActor = null) -> void:
	for c in status_box.get_children():
		c.queue_free()
	for a in logic.actors:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 170
		col.add_theme_constant_override("separation", 3)
		var name := XUI.label(a.display_name() + "  Lv" + str(a.level), 19, XUI.GOLD if a == current else (XUI.DIM if a.is_dead() else XUI.TEXT))
		col.add_child(name)
		col.add_child(XUI.label("HP %d / %d" % [a.hp, a.mhp], 16))
		col.add_child(XUI.gauge(a.hp, a.mhp, XUI.HP, 170, 7))
		col.add_child(XUI.label("MP %d / %d" % [a.mp, a.mmp], 16))
		col.add_child(XUI.gauge(a.mp, a.mmp, XUI.MP, 170, 7))
		status_box.add_child(col)
	for s in sprites.values():
		s.refresh_idle()


# ---- 主循环 ----
func _main() -> void:
	await _say("%s 出现了！" % "、".join(logic.enemies.map(func(e): return e.display_name())), 0.9)
	while true:
		if logic.is_won():
			await _victory()
			finished.emit(0)
			return
		if logic.is_lost():
			await _say("全军覆没……", 1.2)
			logic.end_battle()
			finished.emit(2)
			return
		var cmds = {} if logic.auto else await _input_commands()
		if cmds is String and cmds == "escape":
			_clear_commands()
			if logic.try_escape():
				await _say("成功逃跑了。", 0.8)
				logic.end_battle()
				finished.emit(1)
				return
			await _say("没能逃掉！", 0.8)
			cmds = {}
			for a in logic.actors:
				cmds[a] = [null, null]
		_clear_commands()
		var logs := logic.run_turn(cmds if cmds is Dictionary else {})
		await _play(logs)
		_refresh_status()


func _clear_commands() -> void:
	for c in command_box.get_children():
		c.queue_free()
	list_panel.visible = false


## 依次为每位能行动的角色选指令；返回 {actor: [skill, target]}，或 "escape"。
func _input_commands():
	var cmds := {}
	var members := logic.alive(logic.actors).filter(func(a): return not logic._restricted(a))
	var i := 0
	while i < members.size():
		var a: XActor = members[i]
		_refresh_status(a)
		var r = await _command_for(a)
		if logic.auto:
			return {}
		if r is String and r == "escape":
			return "escape"
		if r is String and r == "back":
			i = maxi(0, i - 1)
			continue
		cmds[a] = r
		i += 1
	_refresh_status()
	return cmds


func _command_for(a: XActor):
	while true:
		_clear_commands()
		var opts := [["攻击", "attack"], ["技能", "skill"], ["防御", "guard"]]
		if logic.can_escape:
			opts.append(["逃跑", "escape"])
		for o in opts:
			var b := XUI.button(o[0], 40)
			var key: String = o[1]
			b.pressed.connect(func(): _picked.emit(key))
			command_box.add_child(b)
		(command_box.get_child(0) as Button).grab_focus.call_deferred()
		var pick = await _picked
		if pick == "auto":
			return "auto"
		match pick:
			"attack":
				var t = await _pick_target(XDB.rec("Skills", XBattleLogic.ATTACK_SKILL), a)
				if t != null:
					return [XDB.rec("Skills", XBattleLogic.ATTACK_SKILL), t]
			"guard":
				return [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), null]
			"escape":
				return "escape"
			"skill":
				var s = await _pick_skill(a)
				if s is Dictionary:
					var t = await _pick_target(s, a)
					if t != null:
						return [s, t]
			"back":
				return "back"
	return null


func _pick_skill(a: XActor):
	for c in list_panel.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 360)
	list_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var skills := logic.usable_skills(a)
	if skills.is_empty():
		col.add_child(XUI.label("没有可用的技能", 20, XUI.DIM))
	for s in skills:
		var b := XUI.button("%s    MP %d" % [s.name, logic.skill_cost(a, s).mp], 48)
		b.icon = XUI.icon_texture(int(s.iconIndex))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = XText.plain(str(s.description))
		b.pressed.connect(func(): _picked.emit(s))
		col.add_child(b)
	var back := XUI.button("返回", 44)
	back.pressed.connect(func(): _picked.emit("cancel"))
	col.add_child(back)
	list_panel.visible = true
	list_panel.position = (get_viewport_rect().size - list_panel.get_combined_minimum_size()) / 2.0
	var r = await _picked
	list_panel.visible = false
	return r if r is Dictionary else null


## 单体技能：点敌人（或我方）选目标；全体/自身直接返回占位目标。
func _pick_target(skill: Dictionary, a: XActor):
	var scope := int(skill.get("scope", 1))
	if not [1, 7, 9].has(scope):
		return a
	var pool := logic.alive(logic.enemies) if scope == 1 else (logic.alive(logic.actors) if scope == 7 else logic.actors.filter(func(x): return x.is_dead()))
	if pool.size() == 1:
		return pool[0]
	_target_mode = "enemy" if scope == 1 else "ally"
	banner.text = "选择目标（点按）"
	for b in pool:
		sprites[b].flash(Color(1, 0.9, 0.5))
	var r = await _picked
	_target_mode = ""
	banner.text = ""
	if r is XBattler and pool.has(r):
		return r
	return null


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_picked.emit("cancel" if _target_mode != "" or list_panel.visible else "back")
			return
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF or _target_mode == "":
		return
	var best = null
	var best_d := 1e9
	for b in sprites:
		var s: XBattlerSprite = sprites[b]
		var c := s.position + Vector2(0, -s.height() / 2.0)
		var d := c.distance_to(pos)
		if d < best_d and d < maxf(90.0, s.height()):
			best_d = d
			best = b
	if best != null:
		_picked.emit(best)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_picked.emit("cancel" if _target_mode != "" or list_panel.visible else "back")


# ---- 播放行动记录 ----
func _play(logs: Array) -> void:
	for l in logs:
		match l.type:
			"action":
				var s: XBattlerSprite = sprites[l.user]
				var name := str(l.skill.name)
				if int(l.skill.id) > XBattleLogic.GUARD_SKILL:
					banner.text = name
				if l.user is XActor:
					await s.step(true)
					s.set_motion("swing" if int(l.skill.id) == XBattleLogic.ATTACK_SKILL else ("spell" if XDamage.is_magical(l.skill) else "skill"))
				else:
					s.flash(Color(1, 0.6, 0.6))
				await get_tree().create_timer(0.18).timeout
			"hit":
				await _show_hit(l)
			"guard":
				sprites[l.user].set_motion("guard")
			"regen":
				if float(l.hp) != 0.0:
					_popup(l.target, -float(l.hp), false)
			"skip":
				pass
		if l.type == "hit" and l.user is XActor and not _next_is_same_action(logs, l):
			await sprites[l.user].step(false)
			banner.text = ""
		_refresh_status()
	banner.text = ""
	for s in sprites.values():
		s.position = s.home


func _next_is_same_action(logs: Array, l: Dictionary) -> bool:
	var i := logs.find(l)
	return i + 1 < logs.size() and logs[i + 1].type == "hit" and logs[i + 1].user == l.user


func _show_hit(l: Dictionary) -> void:
	var t: XBattler = l.target
	var ts: XBattlerSprite = sprites[t]
	var anim_id := int(l.skill.animationId)
	if anim_id < 0:
		anim_id = _attack_animation(l.user)
	var center := ts.position + Vector2(0, -ts.height() / 2.0)
	if anim_id > 0:
		var a := MVAnimation.play(fx, anim_id, center, false)
		if a:
			await get_tree().create_timer(0.25).timeout
	if l.missed or l.evaded:
		_popup(t, 0, false, "未命中" if l.missed else "闪避")
		ts.set_motion("evade")
	else:
		if float(l.hp) != 0.0:
			_popup(t, float(l.hp), l.critical)
			if float(l.hp) > 0.0:
				ts.flash(Color(1, 0.5, 0.5))
				ts.set_motion("damage")
		if float(l.mp) != 0.0:
			_popup(t, float(l.mp), false, "", true)
	if l.died:
		await ts.collapse()
	await get_tree().create_timer(0.22).timeout


func _attack_animation(u: XBattler) -> int:
	if u is XActor:
		for e in (u as XActor).equip_list():
			if e.kind == "weapon":
				return int(e.animationId)
		return 1
	return 1


func _popup(b: XBattler, value: float, critical: bool, text := "", is_mp := false) -> void:
	var s: XBattlerSprite = sprites[b]
	var l := Label.new()
	l.text = text if text != "" else str(absi(int(value)))
	var heal := value < 0.0
	l.add_theme_font_size_override("font_size", 40 if critical else 32)
	l.add_theme_color_override("font_color", Color("7fe08a") if heal else (Color("7fb6ff") if is_mp else (Color("ffd36b") if critical else Color.WHITE)))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.position = s.position + Vector2(-40, -s.height() - 10)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 50, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func _say(text: String, seconds: float) -> void:
	banner.text = text
	await get_tree().create_timer(seconds).timeout
	banner.text = ""


func _victory() -> void:
	for a in logic.alive(logic.actors):
		sprites[a].set_motion("victory")
	var r := logic.rewards()
	var ups := logic.grant(r)
	logic.end_battle()
	var me: Dictionary = XDB.system().get("victoryMe", {})
	var p := XDB.audio_path("me", str(me.get("name", "")))
	bgm.stop()
	if p != "":
		bgm.stream = load(p)
		bgm.play()
	_clear_commands()
	for c in list_panel.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 520
	col.add_theme_constant_override("separation", 8)
	list_panel.add_child(col)
	col.add_child(XUI.label("战斗胜利", 30, XUI.GOLD))
	col.add_child(XUI.label("经验  +%d" % r.exp, 22))
	col.add_child(XUI.label("%s  +%d" % [XDB.system().currencyUnit, r.gold], 22))
	for d in r.drops:
		var table: String = {1: "Items", 2: "Weapons", 3: "Armors"}[int(d.kind)]
		col.add_child(XUI.label("获得  " + str(XDB.rec(table, int(d.id)).get("name", "?")), 20, XUI.TEXT))
	for u in ups:
		col.add_child(XUI.label("%s 升到 %d 级！" % [u.actor.display_name(), u.actor.level], 22, Color("7fe08a")))
	var ok := XUI.button("继续", 48)
	ok.pressed.connect(func(): _picked.emit("ok"))
	col.add_child(ok)
	list_panel.visible = true
	list_panel.position = (get_viewport_rect().size - list_panel.get_combined_minimum_size()) / 2.0
	ok.grab_focus.call_deferred()
	if logic.auto:
		await get_tree().create_timer(1.2).timeout
	else:
		while (await _picked) != "ok":
			pass
	Engine.time_scale = 1.0
