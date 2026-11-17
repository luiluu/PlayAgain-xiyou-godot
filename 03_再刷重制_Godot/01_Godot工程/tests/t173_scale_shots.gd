extends Node
## 【cc·天启篇】T173 战斗角色放大档位对照截图（临时，只出图给 Kyo 看，不进测试清单、不合并逻辑）。
## 两组队伍（各 4 人，同天启篇上场人数）：A 狗逍遥、里德、谷雨、云裳；B 屠苏、璇、哈基米、五条悟。
## 同一场敌人：37 号（英雄谷护卫×3＋【首领】首席法师，大小不一）；另加 88 号单首领（守护石巨人，首领战站位倍数不同）。
## 档位＝ACTOR_SCALE 设成 0.75／1.0／1.25／1.5／2.0：源码常量不动，开战后把我方每个精灵整体 rescale(档位 / 0.75)
## （旧式角色身体＝ACTOR_SCALE×站位倍数，正好等价；167 号起的归一档角色不读 ACTOR_SCALE，这里同比放大）。
## 站位照现有排位逻辑（新界面、两排阵型、T126 撑开），不另调。时刻：第一个指令窗出现后 0.6 秒。
## 用法：Godot --audio-driver Dummy --path . res://tests/t173_scale_shots.tscn -- --out=<目录>

const TIERS := [0.75, 1.0, 1.25, 1.5, 2.0]
const BASE := 0.75
const GROUPS := {"A": [1, 11, 175, 174], "B": [176, 177, 178, 180]}
const GROUP_NAMES := {"A": "狗逍遥 里德 谷雨 云裳", "B": "屠苏 璇 哈基米 五条悟"}
const TROOPS := {37: "护卫×3＋首领法师", 88: "单首领 守护石巨人"}

var out_dir := ""
var notes := []


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


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames(5)
	DirAccess.make_dir_recursive_absolute(out_dir)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XSave.dir_override = "user://test_t173_scale_shots"
	XConfig.path_override = ProjectSettings.globalize_path(XSave.dir().path_join("options.json"))
	XConfig._loaded_path = "<unloaded>"
	XConfig.set_party_formation(XPartyFormation.ROWS)
	XGojo.unlock_override = 1
	XEnemy.force_roll = 100.0
	for troop in TROOPS:
		for g in GROUPS:
			var shots := []
			for t in TIERS:
				var img: Image = await _one(troop, g, t)
				shots.append(img)
			await _board(shots, "t173_%d_%s_拼板" % [troop, g], "敌群 %d（%s）· %s组：%s" % [troop, TROOPS[troop], g, GROUP_NAMES[g]])
	var f := FileAccess.open(out_dir.path_join("t173_尺寸记录.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(notes, "  "))
	f.close()
	print("T173_DONE ", notes.size())
	get_tree().quit.call_deferred(0)


func _one(troop: int, g: String, tier: float) -> Image:
	seed(20261118)
	var party: Array = GROUPS[g]
	var s := XState.new_game(9, int(party[0]), party.slice(1))  # 难度 9 才放超强者（谷雨、云裳…）入队，建完改回 3
	s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)  # 改回难度 3 后也不被出战栏清出
	s.difficulty = 3
	# 五条悟只在天启篇能入队（XGojo.hidden）：截图直接放进队伍和出战栏，不走入队流程
	for id in party:
		if not s.party.has(int(id)):
			s.actor(int(id))
			s.party.append(int(id))
	for i in range(party.size()):
		s.set_battle_slot(i, int(party[i]))
	print("T173_PARTY ", g, " ", s.party, " ", s.battle_slots)
	for i in range(party.size()):
		s.set_battle_slot(i, int(party[i]))
	for a in s.members():
		a.change_level(99)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261118)
	var b := XBattleScene.new()
	b.setup(troop, true, false, {})
	add_child(b)
	# _ready 里已经摆好精灵（还在从右边走进来）：指令窗出现前按档位放大
	var f := tier / BASE
	for a in b.logic.actors:
		(b.sprites[a] as XBattlerSprite).rescale(f)
	await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	await _secs(0.6)
	var sizes := []
	for a in b.logic.actors:
		var sp: XBattlerSprite = b.sprites[a]
		if not sp.is_inside_tree():
			continue
		sizes.append({"id": a.actor_id, "name": a.display_name(), "w": roundf(sp.width()), "h": roundf(sp.height()), "home": [sp.home.x, sp.home.y], "body_scale": snappedf(sp.body_scale, 0.001)})
	var foes := []
	for e in b.logic.enemies:
		var es: XBattlerSprite = b.sprites[e]
		foes.append({"name": e.display_name(), "w": roundf(es.width()), "h": roundf(es.height()), "home": [es.home.x, es.home.y]})
	notes.append({"troop": troop, "group": g, "tier": tier, "actors": sizes, "enemies": foes, "party_count": b.logic.actors.size()})
	var tag := _label("档位 %s（现状 0.75 的 %s 倍）  %s组 · 敌群 %d" % [_t(tier), _t(f), g, troop])
	await _frames(10)
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("t173_%d_%s_%s.png" % [troop, g, _t(tier)]))
	tag.queue_free()
	b.bgm.stop()
	b.queue_free()
	await _frames(3)
	return img


func _t(x: float) -> String:
	return ("%.2f" % x).trim_suffix("0") if not is_equal_approx(x, roundf(x)) else "%.1f" % x


func _label(text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.position = Vector2(8, 8)
	var l := Label.new()
	l.theme = XUI.theme()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
	l.position = Vector2(18, 12)
	layer.add_child(bg)
	layer.add_child(l)
	add_child(layer)
	bg.size = Vector2(l.get_combined_minimum_size().x + 22, 44)
	return layer


## 五档缩到一半（640×360）排 3×2，第六格写说明（截图里左上角已有档位字）
func _board(shots: Array, name: String, title: String) -> void:
	var cw := 640
	var ch := 360
	var board := Image.create(cw * 3, ch * 2, false, Image.FORMAT_RGBA8)
	board.fill(Color(0.08, 0.08, 0.1))
	for i in range(shots.size()):
		var im: Image = (shots[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		board.blit_rect(im, Rect2i(0, 0, cw, ch), Vector2i((i % 3) * cw, (i / 3) * ch))
	board.save_png(out_dir.path_join(name + ".png"))
	# 说明文字另截：第六格的字在 Godot 里画到画面上再取
	var layer := CanvasLayer.new()
	layer.layer = 130
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.size = Vector2(cw, ch)
	var l := Label.new()
	l.theme = XUI.theme()
	l.text = "T173 放大档位对照\n%s\n\n五格依次：0.75（现状）、1.0、1.25、1.5、2.0\n倍数乘在我方全部角色上，站位不动\n每格缩到一半，看细节开单张" % title
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(cw - 40, ch - 40)
	l.position = Vector2(20, 20)
	l.add_theme_font_size_override("font_size", 24)
	layer.add_child(bg)
	layer.add_child(l)
	add_child(layer)
	await _frames(4)
	RenderingServer.force_draw(false)
	var cap := get_viewport().get_texture().get_image()
	cap.convert(Image.FORMAT_RGBA8)
	board.blit_rect(cap, Rect2i(0, 0, cw, ch), Vector2i(2 * cw, ch))
	board.save_png(out_dir.path_join(name + ".png"))
	layer.queue_free()
