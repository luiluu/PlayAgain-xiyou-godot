extends Node
## 宿傩领域法阵成对截图的 Godot 一侧（八戒 visual2）：XBattleIndicators.DomainCircle 推进 30 帧，黑底 256×128、圆心 (128,64)。
## 带 -- --out=<目录> 且不是 headless 时写 domain_circle_godot.png，交给 03_转换工具/ui_reference/domain_circle_ref.py 和原版 PIXI 画的比像素。
## 无 --out 时只走状态断言（30 帧后的透明度与转角、压扁比例）。
const TICK := 30
var results := []
var out_dir := ""


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 128)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(256, 128)
	vp.add_child(bg)
	var c := XBattleIndicators.DomainCircle.new()
	c.position = Vector2(128, 64)
	vp.add_child(c)
	for i in TICK:
		c.step()
	check("tick", c.tick == TICK)
	check("alpha", is_equal_approx(c.modulate.a, 0.82 + cos(TICK * 0.04) * 0.08), c.modulate.a)
	check("rotation", is_equal_approx(c.drawing.rotation, 0.003 * TICK), c.drawing.rotation)
	check("squash", is_equal_approx(c.scale.y, 0.34) and c.scale.x == 1.0)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		for i in 4:
			await get_tree().process_frame
		RenderingServer.force_draw(false)
		DirAccess.make_dir_recursive_absolute(out_dir)
		vp.get_texture().get_image().save_png(out_dir.path_join("domain_circle_godot.png"))
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_indicator_shot", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
