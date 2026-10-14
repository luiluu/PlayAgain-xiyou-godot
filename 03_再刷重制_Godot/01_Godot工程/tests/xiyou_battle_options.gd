extends Node
## 三项战斗设置：正式探针对照、配置重读、真实战斗播放、物理帧计时与地图隔离。
var results := []
var out_dir := ""

class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("shot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)

func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_options"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.remove_absolute(XConfig.path())
	XConfig._loaded_path = "<unloaded>"
	var ref = XDB.load_json("oracle/options.json")
	if not ref is Dictionary or not ref.has("timing"):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	for key in ["CombatDamageShow", "CombatSkillAnimation"]:
		check("default_" + key, XConfig.flag(key) == ref.defaults[key])
	check("default_speed", XConfig.battle_speed() == int(ref.defaults.battleAniSpeed))
	XState.new_game(3, 1, [8, 9, 10])
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	for row in ref.flags:
		XConfig.set_flag(row.symbol, row.initial)
		opt.index = opt.symbols().find(row.symbol)
		match row.op:
			"processOk": opt.ok()
			"cursorLeft": opt._side(false)
			"cursorRight": opt._side(true)
		check("flag_%s_%s_%s" % [row.symbol, str(row.initial), row.op], XConfig.flag(row.symbol) == row.value and opt.status_text(opt.index) == row.status)
	for row in ref.speed:
		XConfig.set_battle_speed(int(row.initial))
		opt.index = opt.symbols().find("battleAniSpeed")
		match row.op:
			"processOk": opt.ok()
			"cursorLeft": opt._side(false)
			"cursorRight": opt._side(true)
		check("speed_%d_%s" % [int(row.initial), row.op], XConfig.battle_speed() == int(row.value) and opt.status_text(opt.index) == row.status)
	XConfig.set_flag("CombatDamageShow", true)
	XConfig.set_flag("CombatSkillAnimation", true)
	XConfig.set_battle_speed(2)
	XConfig._loaded_path = "<unloaded>"
	check("preferences_reread", XConfig.flag("CombatDamageShow") and XConfig.flag("CombatSkillAnimation") and XConfig.battle_speed() == 2)
	opt._select(opt.symbols().find("CombatSkillAnimation"))
	await shot("设置显示开关")
	opt._select(opt.symbols().find("battleAniSpeed"))
	await shot("设置战斗变速")
	opt.queue_free()
	await frames()
	# 原有配置没有这三个键时补正式默认值；数值配置按范围收敛。
	var file := FileAccess.open(XConfig.path(), FileAccess.WRITE)
	file.store_string('{"MapXy":true,"bgmVolume":80}')
	file.close()
	XConfig._loaded_path = "<unloaded>"
	check("old_config_defaults", XConfig.map_xy() and XConfig.volume("bgmVolume") == 80 and XConfig.flag("CombatDamageShow") and not XConfig.flag("CombatSkillAnimation") and XConfig.battle_speed() == 4)
	check("speed_not_boolean", not XConfig.set_flag("battleAniSpeed", true) and XConfig.battle_speed() == 4)
	for value in [-9, 0, 9, 100]:
		file = FileAccess.open(XConfig.path(), FileAccess.WRITE)
		file.store_string(JSON.stringify({"battleAniSpeed":value}))
		file.close()
		XConfig._loaded_path = "<unloaded>"
		check("clamp_saved_%d" % value, XConfig.battle_speed() == clampi(value, 1, 4))
	# 测量计时与播放循环：delta 值和渲染帧率不会改变格数/总耗时。
	for row in ref.timing:
		XConfig.set_battle_speed(int(row.value))
		check("wait_%d" % int(row.value), XBattleTiming.wait_frames(13) == int(row.wait))
		check("move_%d" % int(row.value), XBattleTiming.move_frames(30) == int(row.movement))
		check("animation_wait_%d" % int(row.value), XBattleTiming.animation_wait(13) == int(row.animationWait))
		var anim := MVAnimation.new()
		anim.anim = {"frames":[[],[],[],[],[]], "timings":[]}
		anim.rate = XConfig.battle_speed()
		add_child(anim)
		anim.set_physics_process(false)
		var done := {"value":false}
		anim.done.connect(func(): done.value = true)
		var count := 0
		while not done.value and count < 100:
			anim._physics_process(0.001 if count % 2 else 0.05)
			count += 1
		check("animation_duration_%d" % int(row.value), count == int(row.animationDuration5) and anim.frame == 4, [count,anim.frame])
		await frames()
	XConfig.set_battle_speed(4)
	XEnemy.force_roll = 100.0
	var b := QuietBattle.new()
	b.setup(2, true, false, {})
	add_child(b)
	await frames()
	check("button_initial", b.speed_btn.text == "变速 OFF")
	b.speed_btn.pressed.emit()
	check("button_shared_config", XConfig.battle_speed() == 1 and b.speed_btn.text == "变速 四倍" and Engine.time_scale == 1.0)
	# 所有弹出种类受同一开关控制，实战计数单独验证。
	var enemy: XEnemy = b.logic.enemies[0]
	for row in ref.display:
		XConfig.set_flag("CombatDamageShow", row.enabled)
		XConfig.set_flag("CombatSkillAnimation", row.enabled)
		if row.has("result"):
			var before := b.fx.get_child_count()
			var result: Dictionary = row.result
			b._popup(enemy, float(result.get("hpDamage", result.get("mpDamage", 0))), false, "miss" if result.get("missed", false) else "", result.has("mpDamage"))
			check("popup_%s_%s" % [str(row.enabled), JSON.stringify(result)], b.fx.get_child_count() - before == int(row.popups))
		else:
			var animation := b._start_animation(1, enemy)
			check("animation_gate_%s" % str(row.enabled), int(animation != null) == int(row.animationRequests))
			if animation:
				check("animation_rate_current", animation.rate == XConfig.battle_speed())
				# 冻结短动画的第一个可见格，避免 Mac 截图调度晚于动画结束。
				animation.set_physics_process(false)
				animation._physics_process(1.0 / 60)
				animation._physics_process(1.0 / 60)
				check("animation_sprite_visible", animation._sprites.any(func(sprite): return sprite.visible and sprite.texture != null))
				await shot("战斗技能动画")
				if is_instance_valid(animation):
					animation.queue_free()
	# 打中敌人的连击与受伤闪烁，在关闭伤害数字时仍发生。
	XConfig.set_flag("CombatDamageShow", false)
	XConfig.set_flag("CombatSkillAnimation", false)
	for child in b.fx.get_children():
		child.queue_free()
	await frames()
	var user: XActor = b.logic.actors[0]
	var hit := {"type":"hit", "user":user,"target":enemy,"skill":XDB.rec("Skills",1),"hp":12.0,"mp":0.0,"missed":false,"evaded":false,"critical":false,"died":false}
	b.combo.action_started()
	await b._show_hit(hit)
	check("hidden_popup_keeps_combo", b.fx.get_child_count() == 0 and b.combo.hits == 1 and b.combo.total == 12.0)
	# 同一行动不同显示/变速配置结算相同：包括开启动画后完整播放。
	var baseline := []
	var baseline_frames := 0
	for speed in [4, 1, 2, 3]:
		XConfig.set_battle_speed(speed)
		XConfig.set_flag("CombatDamageShow", speed != 1)
		XConfig.set_flag("CombatSkillAnimation", speed == 2)
		seed(20261014)
		var s := XState.new_game(3, 1, [8, 9, 10])
		var live := QuietBattle.new()
		live.setup(2, true, false, {})
		add_child(live)
		b.hide()
		seed(20261014)
		var target: XEnemy = live.logic.enemies[0]
		var logs := live.logic.act(s.actor(1), XDB.rec("Skills", 1), target)
		var outcome := [target.hp, s.actor(1).hp, s.actor(1).mp, s.actor(1).tp]
		if speed == 4:
			baseline = outcome
		check("settlement_speed_%d" % speed, outcome == baseline, [outcome, baseline])
		var started := Engine.get_physics_frames()
		await live._play(logs)
		var elapsed := Engine.get_physics_frames() - started
		if speed == 4:
			baseline_frames = elapsed
		elif speed in [1, 3]:
			check("fixed_stages_preserved_%d" % speed, elapsed == baseline_frames, [elapsed,baseline_frames])
		check("play_finishes_%d" % speed, not live.combo.acting and live._log_lines.is_empty() and Engine.get_physics_frames() > started)
		check("play_preserves_settlement_%d" % speed, outcome == [target.hp, s.actor(1).hp, s.actor(1).mp, s.actor(1).tp])
		if speed == 1:
			check("real_action_no_popups", live.fx.get_child_count() == 0)
		if speed == 2:
			check("real_animation_finished", not live.fx.get_children().any(func(c): return c is MVAnimation))
			live._popup(target, 12345, true)
			await frames(3)
			await shot("战斗伤害数字")
		live.logic.end_battle()
		live.queue_free()
		await frames()
	b.queue_free()
	await frames()
	check("no_global_speed_leak", Engine.time_scale == 1.0)
	# 地图播放仍 4 帧一格，即使战斗设四倍、关闭技能动画。
	XConfig.set_battle_speed(1)
	XConfig.set_flag("CombatSkillAnimation", false)
	var map_animation := MVAnimation.play(self, 1, Vector2(640,360))
	check("map_animation_independent", map_animation != null and map_animation.rate == 4)
	if map_animation:
		map_animation.queue_free()
	DirAccess.remove_absolute(XConfig.path())
	finish()

func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed,"total":results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
