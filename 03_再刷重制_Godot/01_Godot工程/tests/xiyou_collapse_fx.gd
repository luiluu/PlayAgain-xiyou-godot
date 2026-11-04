extends Node
## MOG_CollapseEffects 默认死亡效果 0（粉碎）守卫（bailong-visual2）。参照 oracle/collapse.json（mv_oracle/collapse_probe.cjs 量冻结正式源）：
## 碎块边长 floor((宽+高)/40)、每行 32 列、y≤0 的行满列、第一条 y>0 的行只放 1 块；速度 sx∈[1,1.5)、淡出 op∈[2.5,4.5)；最久 101～102 帧。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_collapse_fx"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var ref = XDB.load_json("oracle/collapse.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	var par: Dictionary = cases.params.observed
	check("params", int(par.def) == 0 and par.dir == "Left" and int(par.tagged) == 0 and int(par.tagCount) == 0, par)
	check("params.ours_left", XCollapseFx.shatter_left())
	# 网格：与真实插件逐个尺寸对上（块数、边长、首块／末块位置与取图框、行数、每行块数）
	for r in cases.shatter.observed:
		var w := int(r.bw)
		var h := int(r.bh)
		var g := XCollapseFx.grid(w, h)
		var frag := floori((w + h) / 40.0)
		var tag := "grid.%dx%d" % [w, h]
		check(tag + ".frag", frag == int(r.fragSize), [frag, r.fragSize])
		check(tag + ".count", g.size() == int(r.count), [g.size(), r.count])
		var first: Dictionary = g[0]
		var last: Dictionary = g[g.size() - 1]
		# 参照量的是第一次 update 之后的坐标（已减过一次 sx），所以比较的是取图框与行；位置另用起点公式
		check(tag + ".first_frame", first.x == int(r.first.fx) and first.y == int(r.first.fy), [first, r.first])
		check(tag + ".last_frame", last.x == int(r.last.fx) and last.y == int(r.last.fy), [last, r.last])
		var rows := {}
		for q in g:
			rows[q.y] = int(rows.get(q.y, 0)) + 1
		var want := {}
		for rc in r.rowCounts:
			want[int(rc[0])] = int(rc[1])
		check(tag + ".rows", rows == want, [rows, want])
		# 起点：xi＝floor(−w/2)＋floor(frag/2)，yi＝−h＋frag（参照里的 x+sx、y+sx 是未动的起点）
		var xi := floori(-w / 2.0) + floori(frag / 2.0)
		check(tag + ".origin", first.px == xi and first.py == -h + frag and first.px == int(round(r.first.x)) and first.py == int(round(r.first.y)), [first, r.first])
		check(tag + ".sx_range", float(r.sxMin) >= 1.0 and float(r.sxMax) < 1.5 and float(r.opMin) >= 2.5 and float(r.opMax) < 4.5, r)
		check(tag + ".frames_le_102", int(r.framesUntilDone) <= 102 and int(r.framesUntilDone) >= 100, r.framesUntilDone)
	# 节点：用一张 100×120 的图，播完正好在 ≤102 帧内结束，碎块向左上、逐块透明
	var img := Image.create(100, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var host := Node2D.new()
	add_child(host)
	var body := Sprite2D.new()
	body.texture = tex
	host.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fx := XCollapseFx.start(host, body, rng, true)
	check("node.started", fx != null and fx.get_child_count() == 24 * 20 + 0, fx.get_child_count() if fx else -1)  # 24 行满列里只有 20 列在图内；末尾 1 块在图外被丢
	check("node.frames", fx != null and fx.frames >= 100 and fx.frames <= 102, fx.frames if fx else -1)
	var s0: Sprite2D = fx.get_child(0)
	var p0 := s0.position
	fx.step()
	check("node.moves_up_left", s0.position.x < p0.x and s0.position.y < p0.y, [p0, s0.position])
	check("node.fading", s0.modulate.a < 1.0)
	var n := 1
	var total_frames := fx.frames
	while not fx.is_done() and n < 300:
		fx.step()
		n += 1
	check("node.done_in_frames", fx.is_done() and n == total_frames, [n, total_frames])
	# 镜像（SV 敌人整体翻转）：向右上飘
	body.flip_h = true
	var fx2 := XCollapseFx.start(host, body, rng, true)
	check("node.mirror_scale", fx2.scale.x < 0.0, fx2.scale)
	fx2.clear()
	# 方向 Right
	body.flip_h = false
	var fx3 := XCollapseFx.start(host, body, rng, false)
	var q0: Vector2 = (fx3.get_child(0) as Sprite2D).position
	fx3.step()
	check("node.right", (fx3.get_child(0) as Sprite2D).position.x > q0.x)
	fx3.clear()
	# 战斗者节点：倒下后身体透明、碎块在、复活时碎块收掉
	var e := XEnemy.new().setup(1, 1)
	var bs := XBattlerSprite.new()
	add_child(bs)
	bs.setup(e, 1.0)
	e.hp = 0
	e.refresh_resources()
	var finished := [false]
	var run := func():
		await bs.collapse()
		finished[0] = true
	run.call()
	check("sprite.hidden_body", bs.sprite.modulate.a == 0.0 and bs._collapse_fx != null and bs.effect_left >= 100, [bs.sprite.modulate, bs.effect_left])
	for i in 60:
		await get_tree().process_frame
	check("sprite.await_returns", finished[0])
	bs.revive_visual()
	await get_tree().process_frame
	check("sprite.revive_clears", bs._collapse_fx == null and bs.sprite.modulate == Color.WHITE)
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
