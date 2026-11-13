extends Node
## 【cc·未经审查】宿傩特效包接线（XSukunaFx，content/sukuna/art_optional/）：
## - icon.*：开表后 2636～2642 的 iconIndex 是新图标号，XUI.icon_texture 取到 32×32 新图；FX＝false 时 patch_states 不改。
## - open.*：XSukuna.open 的「发动了神灶：开！」行带 sukuna_fx＝flame（文字不变）。
## - shrine.*：宿傩放 10231 的行动认得出，别人／别的技能不认。
## - scene.*：真战斗画面（敌群 2、地图 5）：领域开着时放展开动画（AnimatedSprite2D、15 帧），放完铺背景；领域没了背景淡出；
##   神灶：开在敌群放、火矢翻转；「显示技能动画」关着时不放动画、背景照铺。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(func(): print("FAIL watchdog"); get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	XConfig.path_override = OS.get_temp_dir().path_join("xiyou_sukuna_fx_options_%d.json" % OS.get_process_id())  # 不读本机设置
	XSukunaFx.FX = true
	_icons()
	_shrine_detect()
	await _scene()
	XSukunaFx.FX = true
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _icons() -> void:
	var t: Array = XDB.table("States")
	var bad := []
	for id in XSukunaFx.STATE_ICONS:
		var idx := int(t[id].iconIndex)
		var tex := XUI.icon_texture(idx)
		if idx != XSukunaFx.ICON_BASE + int(XSukunaFx.STATE_ICONS[id]) or tex == null or tex.get_size() != Vector2(32, 32):
			bad.append([id, idx])
	check("icon.states", bad.is_empty(), bad)
	check("icon.read_shared", int(t[2640].iconIndex) == int(t[2642].iconIndex))
	check("icon.others_kept", int(t[2643].iconIndex) == 0 and int(t[2635].iconIndex) == 657, [t[2643].iconIndex, t[2635].iconIndex])
	var copy := [null]
	for id in range(1, 2643):
		copy.append({"id": id, "iconIndex": 7})
	XSukunaFx.FX = false
	XSukunaFx.patch_states(copy)
	check("icon.rollback", int(copy[2636].iconIndex) == 7 and int(copy[2640].iconIndex) == 7)
	XSukunaFx.FX = true
	XSukunaFx.patch_states(copy)
	check("icon.on", int(copy[2636].iconIndex) == XSukunaFx.ICON_BASE + 1)


func _shrine_detect() -> void:
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.add_actor(XSukuna.ACTOR)
	var su := s.actor(XSukuna.ACTOR)
	var other := s.actor(8)
	check("shrine.sukuna_10231", XSukunaFx.shrine_action({"user": su, "skill": XDB.rec("Skills", 10231)}))
	check("shrine.other_skill", not XSukunaFx.shrine_action({"user": su, "skill": XDB.rec("Skills", 10229)}))
	check("shrine.other_actor", not XSukunaFx.shrine_action({"user": other, "skill": XDB.rec("Skills", 10231)}))
	XSukunaFx.FX = false
	check("shrine.rollback", not XSukunaFx.shrine_action({"user": su, "skill": XDB.rec("Skills", 10231)}))
	XSukunaFx.FX = true


func _until(done: Array) -> void:
	for i in 600:
		if done[0]:
			return
		await frames(1)
	check("scene.fx_finishes", false)


func _anims(b: XBattleScene) -> Array:
	return b.fx.get_children().filter(func(n): return n is AnimatedSprite2D)


func _scene() -> void:
	# 同 xiyou_sukuna_battle：开 2494（超强角色可出战），队伍 [172, 1]
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_max_level = 99
	s.actor_advance[XSukuna.ACTOR] = 3
	s.actor(XSukuna.ACTOR).change_level_mv(55)
	s.add_actor(XSukuna.ACTOR)
	s.add_actor(1)
	XSukuna.sync(s.actor(XSukuna.ACTOR))
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	var su: XActor = null
	for a in b.logic.actors:
		if XSukuna.own(a):
			su = a
	check("scene.sukuna_in_battle", su != null)
	check("scene.knows_open", su != null and XSukuna.knows(su, 10233))
	if su == null:
		return
	check("scene.bg_built", b._sukuna_domain != null and not b._sukuna_domain.visible)
	# 神灶：开 记录
	XSukuna.start_battle(b.logic)
	XSukuna.temp(su).domain = 4
	XSukuna.temp(su).prep = 2
	b.logic._state_add(su, XSukuna.DOMAIN)
	check("scene.domain_active", XSukunaFx.domain_active(b.logic))
	# 展开：放动画，放完铺背景
	var hold := XConfig.battle_speed()
	XConfig.set_flag("CombatSkillAnimation", true)  # 默认关；配置写在临时文件里
	var anim_on := XConfig.flag("CombatSkillAnimation")
	check("scene.anim_setting_on", anim_on)
	var shrine := [false]
	(func(): await b._sukuna_fx("shrine"); shrine[0] = true).call()
	await frames(2)
	var nodes := _anims(b)
	if anim_on:
		var sp: AnimatedSprite2D = nodes[0] if not nodes.is_empty() else null
		check("scene.shrine_anim", sp != null and sp.sprite_frames.get_frame_count("cast") == 15 and sp.is_playing(), nodes.size())
		check("scene.shrine_no_bg_yet", not b._sukuna_domain_on)
	await _until(shrine)
	check("scene.bg_on_after_shrine", b._sukuna_domain_on)
	await frames(40)
	check("scene.bg_visible", b._sukuna_domain.visible and b._sukuna_domain.modulate.a > 0.9, b._sukuna_domain.modulate.a)
	# 神灶：开
	var logs := XSukuna.open(b.logic, su)
	check("open.flag", not logs.is_empty() and str(logs[0].get("sukuna_fx", "")) == "flame" and str(logs[0].text).ends_with("发动了神灶：开！"),
		logs[0] if not logs.is_empty() else null)
	var flame := [false]
	(func(): await b._sukuna_fx("flame"); flame[0] = true).call()
	await frames(2)
	if anim_on:
		var fl := _anims(b).filter(func(n): return n.flip_h)
		check("scene.flame_anim", fl.size() == 1 and fl[0].sprite_frames.get_frame_count("cast") == 15, fl.size())
	await _until(flame)
	# open 收了领域：背景淡出
	check("scene.domain_ended", not XSukunaFx.domain_active(b.logic))
	await frames(60)
	check("scene.bg_off", not b._sukuna_domain_on and not b._sukuna_domain.visible, b._sukuna_domain.modulate.a)
	await frames(hold * 15 + 5)
	check("scene.anims_freed", _anims(b).is_empty(), _anims(b).size())
	# 「显示技能动画」关：不放动画，背景照铺（配置写在临时文件里）
	XConfig.set_flag("CombatSkillAnimation", false)
	XSukuna.temp(su).domain = 4
	b.logic._state_add(su, XSukuna.DOMAIN)
	var quiet := [false]
	(func(): await b._sukuna_fx("shrine"); quiet[0] = true).call()
	check("scene.no_anim_when_off", quiet[0] and _anims(b).is_empty() and b._sukuna_domain_on, [quiet[0], _anims(b).size()])
	XConfig.set_flag("CombatSkillAnimation", true)
	b.queue_free()
