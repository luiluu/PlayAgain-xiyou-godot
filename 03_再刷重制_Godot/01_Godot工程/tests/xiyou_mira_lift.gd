extends Node
## 【cc·未经审查】米拉升空变身演出 u7（XMiraLiftFx，开关 XMira.LIFT_ART，素材 content/mira/fx/lift_u7/）：
## - asset.*：8 张过渡姿势 340×280、4 张火屑 256×256 都在；人形取 Codex_Mira_SV_u2 第 1 行第 1 列格；Final 就是黑龙待机图。
## - timeline.*：起点在最终脚点右 56、落地回到脚点；姿势 1800ms 落到黑龙、龙化前 120ms／1210ms 起 60ms 交叉淡化；火屑区间外隐藏、地面层贴地。
## - speed.*：战斗动画 1×／2×／4×（battleAniSpeed 4／3／1）按 60 帧走完的帧数＝2320／倍速；中途变速照走；树暂停时不走。
## - finish.*：放完钳到 2320、层清掉、本体显示原样黑龙、身体缩放回到黑龙的、完成回调只调一次。
## - off.*：「显示技能动画」关着（默认）不建层、直接是黑龙、完成回调立即调；中途关掉立即收尾；状态与能力值与开着时一样（只是画面）。
## - cancel.*：取消、外观换回人形、阵亡、精灵释放都清干净（无层、本体可见、回调一次）。
## - rollback.*：XMira.LIFT_ART = false 不放演出（旧表现：直接换黑龙）。
## 窗口模式加 -- --out=<目录> 时存 6 张变身过程截图（240／600／900／1300／1600／2000ms，2 倍）。
var results := []
var out_dir := ""
var _done_calls := 0
const OPTS := "user://test_xiyou_mira_lift_options.json"
const FRAME_MS := 1000.0 / 60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	XConfig.path_override = OPTS
	XAppearance.overrides = {}
	XMira.ART = true
	XMira.DRAGON_ART = true
	XMira.LIFT_ART = true
	_assets()
	_timeline()
	_off()
	_speeds()
	await _pause()
	_finish_once()
	_cancel()
	_rollback()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _capture_shots()
	XMira.LIFT_ART = true
	XConfig.set_flag("CombatSkillAnimation", false)
	XConfig.set_battle_speed(4)
	XAppearance.overrides = null
	XState.current = null
	DirAccess.remove_absolute(OPTS)
	XConfig.path_override = ""
	finish()


func _game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	return s


## 进阶 3、学了 10161 的人形米拉
func _mira() -> XActor:
	var s := _game()
	s.actor_advance[XMira.ACTOR] = 3
	var a := s.actor(XMira.ACTOR)
	a.change_level_mv(55)
	a.learn_skill(10161)
	return a


func _on_done() -> void:
	_done_calls += 1


## 人形精灵，加上 2592 后让它自己发现外观变了（_process 里 swap_look）；返回 [精灵, 角色]
func _lift_sprite(anim := true) -> Array:
	XConfig.set_flag("CombatSkillAnimation", anim)
	var a := _mira()
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 0.75)
	sp.set_physics_process(false)
	sp._process(0.0)
	a.state_ids.append(XMira.DRAGON)
	return [sp, a]


func _trigger(sp: XBattlerSprite) -> XMiraLiftFx:
	sp._process(0.0)
	var l := XMiraLiftFx.layer_of(sp)
	if l != null:
		l.set_process(false)  # 测试手动推进
		l._on_done = _on_done
	return l


func _assets() -> void:
	var bad := []
	for n in ["MiraLift", "MiraHover", "MiraWingHuman", "MiraHybrid", "MiraAir", "MiraDescend", "MiraTouchdown", "MiraSettle"]:
		var t := XMiraLiftFx._tex(n)
		if t == null or t.get_size() != Vector2(340, 280):
			bad.append(n)
	for f in XMiraLiftFx.FLAMES:
		var t := XMiraLiftFx._tex(f[0])
		if t == null or t.get_size() != Vector2(256, 256):
			bad.append(f[0])
	check("asset.12_files", bad.is_empty(), bad)
	var h := XMiraLiftFx._tex("human") as AtlasTexture
	check("asset.human_u2_cell", h != null and h.region == Rect2(64, 64, 64, 64) and str(h.atlas.resource_path).ends_with("Codex_Mira_SV_u2.png"))
	var d := XMiraLiftFx._tex("dragon")
	check("asset.dragon_final", d != null and d.get_size() == Vector2(340, 280) and d.resource_path == XMiraLiftFx.DRAGON_TEX)
	var mip := []
	for n in ["MiraAir", "MiraEmberArc"]:
		var t := XMiraLiftFx._tex(n)
		if t != null and t.get_image() != null and t.get_image().has_mipmaps():
			mip.append(n)
	check("asset.no_mipmaps", mip.is_empty(), mip)


func _timeline() -> void:
	check("timeline.start_right_56", XMiraLiftFx.body_point(0) == Vector2(56, 0), XMiraLiftFx.body_point(0))
	check("timeline.land_at_foot", XMiraLiftFx.body_point(1530) == Vector2.ZERO and XMiraLiftFx.body_point(2320) == Vector2.ZERO)
	check("timeline.peak", XMiraLiftFx.body_point(920) == Vector2(40, -116), XMiraLiftFx.body_point(920))
	check("timeline.pose_human", XMiraLiftFx.pose_at(0) == ["human", "", 0.0] and XMiraLiftFx.pose_at(19)[1] == "")
	var p := XMiraLiftFx.pose_at(80)  # MiraLift 在 140，前 120ms 起淡化
	check("timeline.fade120", p[0] == "human" and p[1] == "MiraLift" and absf(float(p[2]) - 0.5) < 0.01, p)
	var q := XMiraLiftFx.pose_at(1180)  # MiraDescend 在 1210：60ms 淡化，1150 起
	check("timeline.fade60", q[0] == "MiraAir" and q[1] == "MiraDescend" and absf(float(q[2]) - 0.5) < 0.01, q)
	check("timeline.fade60_not_before", XMiraLiftFx.pose_at(1149)[1] == "")
	check("timeline.final_at_1800", XMiraLiftFx.pose_at(1800) == ["dragon", "", 0.0] and XMiraLiftFx.pose_at(2319)[0] == "dragon")
	check("timeline.flame_hidden_outside", not XMiraLiftFx.flame_at(0, 134)[0] and XMiraLiftFx.flame_at(0, 135)[0] and not XMiraLiftFx.flame_at(3, 1941)[0])
	var g := XMiraLiftFx.flame_at(3, 1570)
	check("timeline.landing_on_ground", g[0] and is_equal_approx((g[3] as Vector2).y, 4.0) and absf(float(g[1]) - 0.874) < 0.001, g)
	var b := XMiraLiftFx.flame_at(1, 815)
	check("timeline.arc_follows_body", b[0] and (b[3] as Vector2) == XMiraLiftFx.body_point(815) + Vector2(11.5, -64), b)


func _off() -> void:
	var r := _lift_sprite(false)
	var sp: XBattlerSprite = r[0]
	var a: XActor = r[1]
	var l := _trigger(sp)
	check("off.no_layer", l == null and sp._look_key.contains("|form:MiraDragon"))
	check("off.body_dragon_visible", sp.sprite.visible and str((sp.sprite as Sprite2D).texture.resource_path).contains("UserSV_MiraDragon"))
	_done_calls = 0
	XMiraLiftFx.begin(sp, 1.0, _on_done)
	check("off.callback_immediate", _done_calls == 1 and XMiraLiftFx.layer_of(sp) == null, _done_calls)
	var off_params := range(8).map(func(i): return a.param(i))
	var off_states := a.state_ids.duplicate()
	sp.queue_free()
	var r2 := _lift_sprite(true)
	var sp2: XBattlerSprite = r2[0]
	var a2: XActor = r2[1]
	var l2 := _trigger(sp2)
	check("off.on_has_layer", l2 != null and not sp2.sprite.visible)
	check("off.same_settlement", range(8).map(func(i): return a2.param(i)) == off_params and a2.state_ids == off_states and XMira.dragon(a2),
		[off_params, off_states, a2.state_ids])
	# 中途关掉「显示技能动画」：下一拍立即收尾
	if l2 != null:
		_done_calls = 0
		l2.tick(500.0)
		XConfig.set_flag("CombatSkillAnimation", false)
		l2.tick(FRAME_MS)
		check("off.midway_finish", l2.done and _done_calls == 1 and sp2.sprite.visible and XMiraLiftFx.layer_of(sp2) == null)
	sp2.queue_free()


## 按 60 帧推进到放完，返回帧数
func _frames_to_end(l: XMiraLiftFx, limit := 400) -> int:
	var n := 0
	while not l.done and n < limit:
		l._process(1.0 / 60.0)
		n += 1
	return n


func _speeds() -> void:
	var want := {4: 1, 3: 2, 1: 4}
	var got := {}
	for setting in want:
		XConfig.set_battle_speed(setting)
		var r := _lift_sprite(true)
		var l := _trigger(r[0])
		got[want[setting]] = [_frames_to_end(l), XMiraLiftFx.speed_mult()] if l != null else null
		r[0].queue_free()
	# 2320ms ÷ 倍速 ÷ 16.67ms
	check("speed.1x", got[1] != null and got[1][0] == ceili(2320.0 / FRAME_MS) and got[1][1] == 1.0, got)
	check("speed.2x", got[2] != null and got[2][0] == ceili(1160.0 / FRAME_MS) and got[2][1] == 2.0, got)
	check("speed.4x", got[4] != null and got[4][0] == ceili(580.0 / FRAME_MS) and got[4][1] == 4.0, got)
	# 中途变速：1× 走 60 帧（1000ms），换 4× 剩 1320ms ＝ 20 帧
	XConfig.set_battle_speed(4)
	var r := _lift_sprite(true)
	var l := _trigger(r[0])
	if l != null:
		for i in 60:
			l._process(1.0 / 60.0)
		var mid := l.elapsed
		XConfig.set_battle_speed(1)
		var rest := _frames_to_end(l)
		check("speed.change_midway", absf(mid - 1000.0) < 0.01 and rest == ceili(1320.0 / 4.0 / FRAME_MS), [mid, rest])
	r[0].queue_free()
	XConfig.set_battle_speed(4)


func _pause() -> void:
	var r := _lift_sprite(true)
	var sp: XBattlerSprite = r[0]
	var l := _trigger(sp)
	if l == null:
		check("pause.layer", false)
		return
	sp.process_mode = Node.PROCESS_MODE_PAUSABLE  # 测试节点自己 ALWAYS（暂停时还要等帧）；战斗画面里精灵照常继承可暂停
	l.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := l.elapsed
	get_tree().paused = true
	for i in 5:
		await get_tree().process_frame
	var t1 := l.elapsed
	get_tree().paused = false
	for i in 3:
		await get_tree().process_frame
	check("pause.runs_before", t0 > 0.0, t0)
	check("pause.stops", is_equal_approx(t0, t1), [t0, t1])
	check("pause.resumes", l.elapsed > t1, [t1, l.elapsed])
	sp.queue_free()
	await get_tree().process_frame


func _finish_once() -> void:
	var r := _lift_sprite(true)
	var sp: XBattlerSprite = r[0]
	var l := _trigger(sp)
	if l == null:
		check("finish.layer", false)
		return
	_done_calls = 0
	l.tick(900.0)
	check("finish.body_hidden_midway", not sp.sprite.visible and l._a.visible)
	check("finish.fx_behind_body", l.get_index() < sp.sprite.get_index())
	check("finish.scale_bigger_in_air", l.scale.x > sp.body_scale, [l.scale.x, sp.body_scale])
	l.tick(900.0)  # 1800：姿势已是 Final
	check("finish.final_scale_matches_body", is_equal_approx(l.scale.x, sp.body_scale) and sp.sprite.visible and not l._a.visible, [l.scale.x, sp.body_scale])
	check("finish.not_yet_done", not l.done and _done_calls == 0)
	l.tick(10000.0)
	check("finish.clamped", l.done and is_equal_approx(l.elapsed, XMiraLiftFx.DURATION), l.elapsed)
	l.tick(100.0)
	l.finish()
	check("finish.callback_once", _done_calls == 1, _done_calls)
	var hidden := l.get_children().all(func(c): return not c.visible)
	check("finish.layer_cleared", hidden and XMiraLiftFx.layer_of(sp) == null and l.is_queued_for_deletion())
	check("finish.body_final", sp.sprite.visible and str((sp.sprite as Sprite2D).texture.resource_path).begins_with("res://content/mira/img/sv_actors/sv/UserSV_MiraDragon/"))
	sp.queue_free()


func _cancel() -> void:
	# 跳过／取消
	var r := _lift_sprite(true)
	var sp: XBattlerSprite = r[0]
	var l := _trigger(sp)
	_done_calls = 0
	l.tick(700.0)
	XMiraLiftFx.cancel(sp)
	check("cancel.skip", l.done and _done_calls == 1 and sp.sprite.visible and XMiraLiftFx.layer_of(sp) == null)
	sp.queue_free()
	# 外观换回人形
	r = _lift_sprite(true)
	sp = r[0]
	l = _trigger(sp)
	_done_calls = 0
	l.tick(700.0)
	(r[1] as XActor).state_ids.erase(XMira.DRAGON)
	sp._process(0.0)
	check("cancel.back_to_human", l.done and _done_calls == 1 and sp.sprite.visible and XMiraLiftFx.layer_of(sp) == null)
	sp.queue_free()
	# 阵亡
	r = _lift_sprite(true)
	sp = r[0]
	l = _trigger(sp)
	_done_calls = 0
	l.tick(700.0)
	(r[1] as XActor).hp = 0
	(r[1] as XActor).state_ids.append(1)
	l.tick(FRAME_MS)
	check("cancel.dead", l.done and _done_calls == 1 and sp.sprite.visible, [l.done, _done_calls])
	sp.queue_free()
	# 精灵被释放
	r = _lift_sprite(true)
	sp = r[0]
	l = _trigger(sp)
	_done_calls = 0
	l.tick(700.0)
	var wr: WeakRef = weakref(l)
	sp.free()
	check("cancel.freed", _done_calls == 1 and wr.get_ref() == null, _done_calls)


func _rollback() -> void:
	XMira.LIFT_ART = false
	var r := _lift_sprite(true)
	var l := _trigger(r[0])
	check("rollback.no_layer", l == null and (r[0] as XBattlerSprite).sprite.visible and (r[0] as XBattlerSprite)._look_key.contains("|form:MiraDragon"))
	r[0].queue_free()
	XMira.LIFT_ART = true


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## 变身过程截图：灰底、2 倍，6 个时刻
func _capture_shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	for ms in [240, 600, 900, 1300, 1600, 2000]:
		var root := Node2D.new()
		add_child(root)
		var bg := ColorRect.new()
		bg.color = Color(0.22, 0.24, 0.3)
		bg.size = Vector2(640, 480)
		root.add_child(bg)
		var ground := ColorRect.new()
		ground.color = Color(0.35, 0.37, 0.44)
		ground.position = Vector2(0, 400)
		ground.size = Vector2(640, 2)
		root.add_child(ground)
		var r := _lift_sprite(true)
		var sp: XBattlerSprite = r[0]
		var l := _trigger(sp)
		sp.reparent(root)
		sp.scale = Vector2(2, 2)
		sp.position = Vector2(300, 400)
		sp.set_process(false)
		if l != null:
			l.tick(float(ms))
		var lab := Label.new()
		lab.text = "米拉升空变身 u7  %dms / 2320ms（游戏内缩放，画面 2 倍）" % ms
		lab.position = Vector2(16, 12)
		lab.add_theme_font_size_override("font_size", 20)
		root.add_child(lab)
		await _frames(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 640, 480)).save_png(out_dir.path_join("mira_lift_%04dms.png" % ms))
		root.queue_free()
		await _frames(2)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
