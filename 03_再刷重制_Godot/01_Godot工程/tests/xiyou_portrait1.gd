extends Node
## 【cc·rules·未经审查】portrait1：进阶页的云裳立绘（installNativeYunshangRuntime 第 582 行 Window_ActorAdvancedStatus.update 包装：
## 原 update 之后按 CodexSV.profiles.Yunshang 缩放，scaleFor＝min(72／可见高 132, 129／可见宽 124)≈0.545）；别的角色照原生（格宽不超内容宽一半就 1 倍）。
var passed := 0
var total := 0


func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	for id in [1, XYunshang.ACTOR]:
		s.add_actor(id)
	var page := XActorAdvancedScene.new()
	add_child(page)
	for i in 4:
		await get_tree().physics_frame
	check("first_is_1", page.current_actor() != null and page.current_actor().actor_id == 1, page.current_actor())
	check("actor1_native_scale", page.sprite.scale == Vector2.ONE, page.sprite.scale)
	var want := minf(72.0 / 132.0, 129.0 / 124.0)
	check("yunshang_scale_value", is_equal_approx(XActorAdvancedScene.yunshang_scale(), want), XActorAdvancedScene.yunshang_scale())
	page.index = page.members.find(s.actor(XYunshang.ACTOR))
	page._draw_status()
	for i in 4:
		await get_tree().physics_frame
	check("yunshang_shown", page.shown_actor == s.actor(XYunshang.ACTOR) and page.sprite.texture != null, page.shown_actor)
	check("yunshang_scale", page.sprite.scale.is_equal_approx(Vector2(want, want)), page.sprite.scale)
	page.queue_free()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total and total > 0 else 1)
