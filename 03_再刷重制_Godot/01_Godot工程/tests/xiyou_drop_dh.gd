extends Node
## 掉落图标 dh 动画（krz_iconsetimprove 的 SpriteEnemyTrP.createIcon：<dh:N> → startAnimation(动画 N)）对照正式版逐帧读数
## tests/fixtures/drop_dh_oracle.json（ui_reference ?battle_ref=1 的 __dhRef.run，A：三件都带 dh、intY 相同；
## B：混一件不带 dh、intY 各不相同）。逐帧比子节点顺序（绘制先后）、图标位置/缩放/不透明度、动画位置/剩余时长/帧序、
## 屏幕闪光不透明度。正式版首次载入动画图的等待（2～5 帧）用 wait 对齐。另比色相取样与 dh 动画用到的闪光种类。
## 窗口模式加 -- --out=<目录>：真实战斗里按读数 A 摆好并截图（对照 dh_drop_reference_A_f6），并实测着色器转色相像素。

var results := []
var out_dir := ""
var oracle: Dictionary


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_drop_dh"
	XConfig.path_override = XSave.dir().path_join("options.json")
	oracle = _load_oracle()
	check("oracle_present", oracle.has("A") and oracle.has("B"))
	if oracle.has("A"):
		_guard_flash_scopes()
		_mute_dh_se()
		_hue_samples()
		for k in ["A", "B"]:
			_replay(k, oracle[k])
		_sort_ties()
		if out_dir != "" and DisplayServer.get_name() != "headless":
			await _shader_pixels()
			await _battle_shot()
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	# 停掉整棵树里的播放器（含 XSound 挂在根节点下的系统音效）并清 stream，按真实时间等 0.5 秒（AGENTS.md 测试规则；
	# 原来只停本节点子树，满负载下偶发「resources still in use at exit」）
	var players: Array = get_tree().root.find_children("*", "AudioStreamPlayer", true, false)
	players.append_array(XSound._players)
	for sp in players:
		if is_instance_valid(sp):
			(sp as AudioStreamPlayer).stop()
			(sp as AudioStreamPlayer).stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _load_oracle() -> Dictionary:
	var f := FileAccess.open("res://tests/fixtures/drop_dh_oracle.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## 全部带 dh 的物品/武器/防具用到的动画只有 flashScope 0/2（1 目标闪光、3 隐藏目标没有实现）
func _guard_flash_scopes() -> void:
	var ids := _dh_anim_ids()
	var bad := []
	for id in ids:
		for tm in XDB.rec("Animations", id).get("timings", []):
			if int(tm.flashScope) not in [0, 2]:
				bad.append([id, tm.flashScope])
	check("dh_anims_found", ids.size() >= 8, ids.keys())
	check("dh_flash_scopes_0_2", bad.is_empty(), bad)


## 带 dh 的物品/武器/防具用到的动画 ID
func _dh_anim_ids() -> Dictionary:
	var ids := {}
	for t in ["Items", "Weapons", "Armors"]:
		for r in XDB.table(t):
			if r is Dictionary and r.get("meta", {}).has("dh"):
				ids[int(str(r.meta.dh))] = true
	return ids


## 本测试只比画面：开测前去掉 dh 动画时间点里的音效（改的是本进程的 XDB 缓存）。逐帧推进是同步的，几只音效会在同一瞬间开播，
## 随弹出节点 free() 后只能等音频线程回收；满负载时拖到退出，报「resources still in use」（2026-10-17 外部负载约 30 时连续出现）。
func _mute_dh_se() -> void:
	for id in _dh_anim_ids():
		for tm in XDB.rec("Animations", id).get("timings", []):
			tm.erase("se")


## 正式版 Bitmap.rotateHue 前后的像素（不透明度 ≥160）：Godot 的原图同一点相同，按同一算法转出来的也相同
func _hue_samples() -> void:
	var worst_raw := 0
	var worst_hue := 0
	var n := 0
	for s in oracle.A.samples:
		var img: Image = load(XDB.img_path("animations", str(s.name))).get_image()
		if img.is_compressed():
			img.decompress()
		for p in s.points:
			var raw := Color.html(str(p[2]))
			var want := Color.html(str(p[3]))
			var got := img.get_pixel(int(p[0]), int(p[1]))
			worst_raw = maxi(worst_raw, _diff(got, raw))
			var one := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			one.set_pixel(0, 0, Color(raw, 1.0))
			var rot := XMapTransfer.rotate_hue(one, int(s.hue)).get_pixel(0, 0)
			worst_hue = maxi(worst_hue, _diff(rot, want))
			n += 1
	check("hue_samples_source_pixels", n >= 100 and worst_raw <= 1, [n, worst_raw])
	check("hue_samples_rotate", worst_hue <= 1, worst_hue)


func _diff(a: Color, b: Color) -> int:
	return maxi(absi(a.r8 - b.r8), maxi(absi(a.g8 - b.g8), absi(a.b8 - b.b8)))


func _make(k: String, ref: Dictionary, host: Node2D) -> XDropPopup:
	XConfig.set_battle_speed(int(ref.battleAniSpeed))
	var p := XDropPopup.new()
	add_child(p)
	p.set_physics_process(false)
	host.position = Vector2(ref.enemy.x, ref.enemy.y)
	p.setup(host, float(ref.enemy.height), ref.drops.map(func(id): return XDB.rec("Armors", int(id))))
	_apply_oracle(p, ref)
	return p


## 正式版第 1 帧的 intY／横速（随机抽的）按物品对上后重排；正式版首次载入动画图的等待帧记进 wait
func _apply_oracle(p: XDropPopup, ref: Dictionary) -> void:
	var first: Array = ref.frames[0][2]
	for g in p.icons:
		for c in first:
			if c[0] == "i" and int(c[1]) == int(g.item.id):
				g.intY = float(c[8])
				g.vx = float(c[9])
				g.ry = XDropPopup.START_Y + g.intY
	p.arrange()
	for c in p.get_children():
		if c is XDropPopup.DhAnimation:
			var id := int(c.anim.id)
			for f in ref.frames:
				var row = f[2].filter(func(x): return x[0] == "a" and int(x[1]) == id)
				if not row.is_empty() and int(row[0][5]) < c.duration:
					c.wait = int(f[0]) - 1
					break


func _row(p: XDropPopup) -> Array:
	var out := []
	for c in p.get_children():
		if c is XDropPopup.DropIcon:
			var g: Dictionary = c.g
			out.append(["i", int(g.item.id), g.x, g.y, g.sx, g.sy, g.alpha, 1 if g.visible else 0])
		elif c is XDropPopup.DhAnimation:
			out.append(["a", int(c.anim.id), p.icons.find(c.icon), c.position.x, c.position.y, c.duration,
				c.frame_index() if c.playing() else null, c.flash_opacity(), 1 if c.flash.visible and c.flash_opacity() > 0.0 else 0])
	return out


func _same(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		var a: Array = got[i]
		var b: Array = want[i]
		if a[0] != b[0] or a[1] != int(b[1]):
			return false
		if a[0] == "i":
			for j in [2, 3, 4, 5]:
				if absf(float(a[j]) - float(b[j])) > 0.002:
					return false
			if a[6] != int(b[6]) or a[7] != int(b[7]):
				return false
		else:
			if a[2] != int(b[2]) or absf(a[3] - float(b[3])) > 0.002 or absf(a[4] - float(b[4])) > 0.002 or a[5] != int(b[5]):
				return false
			if (a[6] == null) != (b[6] == null) or (a[6] != null and a[6] != int(b[6])):
				return false
			if absf(a[7] - float(b[7])) > 0.01 or a[8] != (1 if int(b[8]) == 1 and float(b[7]) > 0.0 else 0):
				return false
	return true


func _replay(k: String, ref: Dictionary) -> void:
	var host := Node2D.new()
	add_child(host)
	var p := _make(k, ref, host)
	var bad := []
	var flash_frames := 0
	for f in ref.frames:
		p.step()
		var got := _row(p)
		if got.any(func(c): return c[0] == "a" and c[8] == 1):
			flash_frames += 1
		if not _same(got, f[2]):
			bad.append([f[0], got, f[2]])
			if bad.size() >= 2:
				break
	check("replay_%s_%d_frames" % [k, ref.frames.size()], bad.is_empty(), bad)
	check("replay_%s_flash_seen" % k, flash_frames > 30, flash_frames)
	check("replay_%s_done" % k, p.done(), _row(p))
	p.free()
	host.free()


## intY 相同的图标保持掉落原序（V8 排序稳定）；动画（没有 intY）与谁比都算「不小于」。期望值取自 Chrome 152 实跑
func _sort_ties() -> void:
	var key := func(x): return x.k
	var got := XDropPopup._mv_sort([{"n": 0, "k": 5.0}, {"n": 1, "k": NAN}, {"n": 2, "k": 5.0}, {"n": 3, "k": 9.0}, {"n": 4, "k": NAN}], key)
	check("mv_sort_stable_nan", got.map(func(x): return x.n) == [0, 1, 3, 2, 4], got.map(func(x): return x.n))


## 着色器实画：1×1 区域的格子按 hue 材质画出来，与正式版转色相后的像素一致（窗口模式）
func _shader_pixels() -> void:
	var s: Dictionary = oracle.A.samples[0]
	var tex: Texture2D = load(XDB.img_path("animations", str(s.name)))
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var pts: Array = s.points.slice(0, 16)
	for i in pts.size():
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(int(pts[i][0]), int(pts[i][1]), 1, 1)
		sp.position = Vector2(4 + i * 4, 4)
		sp.material = MVAnimation.cell_material(int(s.hue), false)
		layer.add_child(sp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(80, 12)
	bg.z_index = -1
	layer.add_child(bg)
	layer.move_child(bg, 0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var worst := 0
	for i in pts.size():
		var a := float(pts[i][4]) / 255.0
		var want := Color.html(str(pts[i][3]))
		var got := img.get_pixel(4 + i * 4, 4)
		var expect := Color(want.r * a, want.g * a, want.b * a)     # 黑底上按不透明度混合
		worst = maxi(worst, _diff(got, expect))
	check("shader_hue_pixels", worst <= 2, worst)
	layer.free()


## 真实战斗：第一只敌人倒下掉落读数 A 的三件防具，按读数 A 摆好、推进 6 帧（同参照 dh_drop_reference_A_f6，含读数里的加载等待）后截图
func _battle_shot() -> void:
	XMessageBox.auto = true
	XConfig.set_flag("MOG_TrPopUpBattle_Key", true)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 5
	s.x = 10
	s.y = 10
	var map := XMapScene.new()
	add_child(map)
	for i in 4:
		await get_tree().process_frame
	map._set_busy(true)
	map.start_battle(2, true, false)
	var b: XBattleScene = null
	for i in 600:
		var found := get_tree().root.find_children("*", "XBattleScene", true, false)
		if not found.is_empty() and (found[0] as XBattleScene).sprites.size() > 0:
			b = found[0]
			break
		await get_tree().physics_frame
	check("battle_started", b != null)
	if b == null:
		return
	for i in 90:
		await get_tree().physics_frame
	var e: XEnemy = b.logic.enemies[0]
	b.logic._treasure[e] = [{"kind": 3, "id": 108}, {"kind": 3, "id": 130}, {"kind": 3, "id": 57}]
	e.hp = 0.0
	b._enemy_collapsed(e)
	var p: XDropPopup = b.field.get_children().filter(func(c): return c is XDropPopup)[-1]
	get_tree().paused = true
	_apply_oracle(p, oracle.A)
	for i in 6:
		p.step()
	check("battle_popup_flash", _row(p).any(func(c): return c[0] == "a" and c[8] == 1), _row(p))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("dh_drop_godot_A_f6.png"))
	get_tree().paused = false
	map.queue_free()
