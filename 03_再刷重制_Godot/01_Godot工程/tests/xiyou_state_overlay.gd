extends Node
## 战斗者状态 overlay（ui11）：Sprite_StateOverlay＋YEP_X_VisualStateFX＋ActSeqPack2 updateStateSprites。
## 原版读数 tests/fixtures/state_overlay_oracle.json；回退开关 XBattlerSprite.STATE_OVERLAY。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _sprite(b: XBattler, sc: float) -> XBattlerSprite:
	var s := XBattlerSprite.new()
	add_child(s)
	s.setup(b, sc)
	return s


func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/state_overlay_oracle.json"))
	check("wait_4", XBattlerSprite.overlay_wait() == float(ref.ssep.wait), XBattlerSprite.overlay_wait())
	var n := 0
	for st in XDB.table("States"):
		if st is Dictionary and int(st.get("overlay", 0)) > 0:
			n += 1
	check("overlay_states_84", n == int(ref.overlay_state_count), n)
	# 敌人 1（单图高 60）：睡眠 10（overlay 7）＋中毒 4（overlay 1）→ 取睡眠
	var e := XEnemy.new().setup(int(ref.enemy.enemy_id), 1)
	e.add_state(4)
	e.add_state(10)
	var s := _sprite(e, 1.0)
	check("enemy_index_7", XBattlerSprite.overlay_index_of(e) == int(ref.enemy.overlay_index), XBattlerSprite.overlay_index_of(e))
	check("above_body", s.overlay != null and s.overlay.get_index() == s.sprite.get_index() + 1, null)
	check("hidden_before_first_change", not s.overlay.visible, null)
	# 逐帧：每 4 帧换一格，格 x＝pattern×96、y＝(7−1)×96＝576；y＝4
	var seq := []
	for i in range(36):
		s.motion_tick()
		seq.append([s._ov_pattern, s._ov_count, int(s.overlay.region_rect.position.x), int(s.overlay.region_rect.position.y), s.overlay.position.y, s.overlay.visible])
	check("first_change_tick4", seq[2][5] == false and seq[3][5] == true and seq[3][0] == 1, seq.slice(0, 5))
	var runs_ok := true
	for i in range(3, 36):
		var want_pat := (1 + (i - 3) / 4) % 8
		if seq[i][0] != want_pat or seq[i][2] != want_pat * 96 or seq[i][3] != 576 or seq[i][4] != float(ref.enemy.y):
			runs_ok = false
	check("frames_every_4_like_oracle", runs_ok, seq)
	# 原版读数本身也是每 4 帧一格、计数 0～3
	var of: Array = ref.enemy.frames
	var oracle_ok := true
	for f in of:
		if int(f[3]) != int(f[0]) * 96 or int(f[4]) != (int(f[2]) - 1) * 96 or int(f[1]) > 3 or int(f[5]) != int(ref.enemy.y):
			oracle_ok = false
	check("oracle_shape", oracle_ok, of)
	check("enemy_y4_anchor", s.overlay.offset == Vector2(0, -48) and s.overlay.centered and s.overlay.position.y == 4.0, [s.overlay.offset, s.overlay.position])
	# 呼吸：父精灵缩放跟着进 overlay（scale 与 y×scale.y）
	s.sprite.scale = Vector2(0.9990778, 0.9815568)
	s.motion_tick()
	# 原版读数：父缩放 (0.99908, 0.98156) 时本地 y 仍是 4（y 在呼吸缩放之前算），画面 331＋4×0.98156≈334.9
	check("breathing_scales_overlay", is_equal_approx(s.overlay.scale.y, 0.9815568) and absf(331.0 + s.overlay.position.y - (331.0 + 4.0 * 0.9815568)) < 0.001 and floorf(331.0 + s.overlay.position.y) == float(ref.enemy.world_y), [s.overlay.scale, s.overlay.position.y])
	# 浮空：再减 ceil(浮空率×图高)
	s.sprite.scale = Vector2.ONE
	s.float_height = 0.5
	s.motion_tick()
	check("float_lifts", s.overlay.position.y == 4.0 - 30.0, s.overlay.position.y)
	s.float_height = 0.0
	# 解除状态：下一次换格才消失（换格时才重读 overlay 号）
	while s._ov_count != 1:
		s.motion_tick()
	e.remove_state(10)
	e.remove_state(4)
	s.motion_tick()
	var still := s.overlay.visible
	s.motion_tick()
	s.motion_tick()
	check("clears_on_next_change", still and not s.overlay.visible, [still, s.overlay.visible])
	# 精英 1.8：overlay 跟着缩 1.8，y＝−(60−64×1.8)×1.8
	var el := XEnemy.new().setup(int(ref.enemy.enemy_id), 1)
	el.add_state(4)
	var se := _sprite(el, 1.8)
	for i in range(4):
		se.motion_tick()
	check("elite_scale", is_equal_approx(se.overlay.scale.x, 1.8) and is_equal_approx(se.overlay.position.y, -(60.0 - 64.0 * 1.8) * 1.8) and int(se.overlay.region_rect.position.y) == 0, [se.overlay.scale, se.overlay.position])
	# 角色：Sprite_Actor 本身不缩，y＝−(64−64)＝0，overlay 恒 1 倍
	var a := XActor.new().setup(int(ref.actor.actor_id))
	a.add_state(int(ref.actor.state))
	var sa := _sprite(a, 0.75)
	for i in range(4):
		sa.motion_tick()
	check("actor_y0_scale1", sa.overlay.visible and sa.overlay.scale == Vector2.ONE and sa.overlay.position.y == float(ref.actor.y) and int(sa.overlay.region_rect.position.y) == int(ref.actor.frame_y), [sa.overlay.visible, sa.overlay.scale, sa.overlay.position, sa.overlay.region_rect])
	# SV 敌人：参数 Show State Overlay true、全部敌人都没有隐藏备注 → 显示
	var sv_id := 0
	for r in XDB.table("Enemies"):
		if r is Dictionary and XSvEnemy.is_sv(XEnemy.new().setup(int(r.id), 1)):
			sv_id = int(r.id)
			break
	var sve := XEnemy.new().setup(sv_id, 1)
	check("sv_param_true", XSvEnemy.state_overlay(sve), sv_id)
	sve.add_state(4)
	var ss := _sprite(sve, 1.0)
	for i in range(4):
		ss.motion_tick()
	check("sv_enemy_shown", ss.overlay.visible, sv_id)
	# 回退开关
	XBattlerSprite.STATE_OVERLAY = false
	ss.motion_tick()
	check("rollback_hidden", not ss.overlay.visible, null)
	XBattlerSprite.STATE_OVERLAY = true
	ss.motion_tick()
	check("rollback_restore", ss.overlay.visible, null)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
