extends Node
## 【cc·T190】新界面指令环 7 项（含「换人」）不重叠专项：6 项及以下布局与旧算法逐项相同；7 项相邻项竖向间距 ≥ MIN_GAP_B；
## SEVEN_FIX=false 回退到旧排法。窗口模式加 -- --out=<目录> 截图 ring_6 / ring_7（纯色底，原尺寸 1280×720）。

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _list(n: int) -> Array:
	var names := ["攻击", "技能", "物品", "防御", "换人", "逃跑", "宠物", "法宝"]
	var out := []
	for i in n:
		out.append({"text": names[i], "key": str(i)})
	return out


func _min_dy(r: XSkinBattleRing) -> float:
	var m := INF
	for i in range(1, r.entries.size()):
		m = minf(m, absf(r.orb_pos(i).y - r.orb_pos(i - 1).y))
	return m


func _run() -> void:
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.2, 0.15)
	bg.size = host.size
	host.add_child(bg)
	# 6 项及以下：新旧排法逐项一致
	for n in [2, 3, 4, 5, 6]:
		XSkinBattleRing.SEVEN_FIX = true
		var a := XSkinBattleRing.create_ring(host, _list(n), "测试")
		XSkinBattleRing.SEVEN_FIX = false
		var b := XSkinBattleRing.create_ring(host, _list(n), "测试")
		var same := is_equal_approx(a.radius, b.radius) and a.size == b.size
		for i in n:
			same = same and a.orb_pos(i).is_equal_approx(b.orb_pos(i))
		_check("ring_%d_unchanged" % n, same)
		a.queue_free()
		b.queue_free()
	XSkinBattleRing.SEVEN_FIX = true
	# 7、8 项：竖向间距够（文字行高 ≤ 26 号放大，≥ MIN_GAP_B）
	for n in [7]:   # 指令环最多 7 项（换人）
		var r := XSkinBattleRing.create_ring(host, _list(n), "测试")
		_check("ring_%d_gap" % n, _min_dy(r) >= XSkinBattleRing.MIN_GAP_B - 0.5, _min_dy(r))
		var inside := Rect2(Vector2.ZERO, r.size).encloses(r.drawn_rect())
		_check("ring_%d_inside_box" % n, inside, [r.size, r.drawn_rect()])
		r.queue_free()
	# 回退：关掉后 7 项回到旧排法（末两项竖向间距小，证明开关有效）
	XSkinBattleRing.SEVEN_FIX = false
	var old := XSkinBattleRing.create_ring(host, _list(7), "测试")
	_check("ring_7_rollback_old_layout", _min_dy(old) < XSkinBattleRing.MIN_GAP_B, _min_dy(old))
	old.queue_free()
	XSkinBattleRing.SEVEN_FIX = true
	if out_dir != "" and DisplayServer.get_name() != "headless":
		for n in [6, 7]:
			var r := XSkinBattleRing.create_ring(host, _list(n), "芙芙")
			r.position = Vector2(500, 150)
			r.select(4 if n == 7 else 3)
			for k in 12:
				await get_tree().process_frame
			RenderingServer.force_draw(false)
			_check("shot_%d" % n, get_viewport().get_texture().get_image().save_png(out_dir.path_join("ring_%d.png" % n)) == OK)
			r.queue_free()
			await get_tree().process_frame
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
