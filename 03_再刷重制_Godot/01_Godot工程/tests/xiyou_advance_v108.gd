extends Node
## 【cc·悟空·未经审查】v0.62 Codex_MiraRavenMultiFrame v1.08：进阶界面（Window_ActorAdvancedStatus）里格宽大于 64 的 9×6 归一图
## 按图鉴同尺寸显示（归一缩放×bookScale，只缩小）：流萤 179（Codex_Liuying_SV 128px 格）缩放 72/116×0.8、左上锚点、平滑，
## 中线 w/10+32、脚底 w/10+64；老角色（64px 格）不动。开关 XActorAdvancedScene.ADV_V108（O-300）开、关各一组。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _measure(page) -> Dictionary:
	var sp: Sprite2D = page.sprite
	return {"scale": sp.scale.x, "centered": sp.centered, "pos": sp.position, "linear": sp.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"tex": sp.texture.resource_path if sp.texture else ""}


func _run() -> void:
	XMessageBox.auto = true
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true  # 流萤是超强者，地狱以下要开挑战开关才招得进
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 179]:
		s.add_actor(id)
	check("party", s.party.has(179) and s.party.has(1), s.party)
	for on in [true, false]:
		if on:
			XActorAdvancedScene.ADV_V108 = true
		else:
			XActorAdvancedScene.ADV_V108 = false  # 回退支
		var page = XActorAdvancedScene.new()
		add_child(page)
		await frames(3)
		var tag := "on" if on else "off"
		var rows := {}
		for i in page.members.size():
			page._select(i)
			await frames(3)
			rows[int(page.members[i].actor_id)] = _measure(page)
		var w: float = page.status_win.canvas.size.x
		var ly: Dictionary = rows.get(179, {})
		var old: Dictionary = rows.get(1, {})
		check(tag + ".179_tex", str(ly.get("tex", "")).ends_with("Codex_Liuying_SV.png"), ly)
		if on:
			var sc := 72.0 / 116.0 * 0.8
			check("on.179_scale", is_equal_approx(ly.scale, sc), ly)
			check("on.179_anchor_smooth", ly.centered == false and ly.linear == true, ly)
			# 中线（图上 (19+111)/2＝65）落在 w/10+32、脚底（图上 128）落在 w/10+64
			check("on.179_mid_foot", absf(ly.pos.x + 65.0 * sc - (w / 10.0 + 32.0)) < 0.01 and absf(ly.pos.y + 128.0 * sc - (w / 10.0 + 64.0)) < 0.01, [ly.pos, w])
		else:
			check("off.179_native", ly.centered == true and ly.linear == false and ly.pos == Vector2(w / 10.0, w / 10.0) and ly.scale >= 0.99 * minf(1.0, w / 2.0 / 128.0), ly)
		check(tag + ".1_untouched", old.centered == true and old.linear == false and is_equal_approx(old.scale, 1.0), old)
		page.queue_free()
		await frames(2)
	XActorAdvancedScene.ADV_V108 = true
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
