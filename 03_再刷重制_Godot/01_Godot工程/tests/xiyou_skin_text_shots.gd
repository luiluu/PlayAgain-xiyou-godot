extends Node
## 【cc·T338·未经审查】界面细节 D2 验收截图 1、2（要窗口、带 --out）：
## 1. 装备长说明卡（XSkinCard 展开前后，100% 与 130% 字号各一张，左＝改前 DETAIL_V1=false，右＝改后）：长词条段落无末行孤字、行首无标点、多色属性上色无错位；
## 2. Boss 状态详情卡（XSkinBossStatus 选中一条的说明页，改前｜改后）：原手写硬切的行首逗号、百分比腰斩消失。
##   godot --audio-driver Dummy --path <工程> res://tests/xiyou_skin_text_shots.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SHOT := Vector2i(1280, 720)
const NO_START := XSkinText.NO_START

var results: Array = []
var out_dir := ""

const DESC_A := ["每当持有者发动攻击时，有一定几率触发「饮血」", "攻击时有一定几率触发「饮血」", "每当持有者发动攻击，有较高几率触发「饮血」效果", "每次攻击命中目标时，都有几率触发「饮血」", "发动攻击时，有较高几率触发「饮血」"]
const DESC_B := ["额外造成相当于攻击力的伤害", "额外造成相当于攻击力 120% 的伤害", "额外造成相当于攻击力一半的伤害", "额外造成一次伤害"]
const DESC_C := ["，并为自己回复少量生命", "，并回复生命，同时获得护盾", "，并为全队回复少量生命值", "，同时回复自身生命"]
const DESC_EX := ["", "，且无视部分防御", "，并有 8% 几率再次触发", "，同时使目标陷入「流血」", "，并提升自身暴击率", "，伤害提升 5%", "，伤害提升 12%", "，伤害提升 18%", "，伤害提升 25%", "，伤害提升 30%", "，伤害提升 45%", "，攻击力 +15%，暴击 +8%", "，攻击力 +120%", "，生命上限 +4,567"]
const DESC_TAILS := ["，持续三回合。若目标处于异常状态，则效果翻倍，冷却时间缩短 20%，最多叠加 5 层。", "，持续三回合；目标处于异常状态时效果翻倍，冷却缩短 20%，最多叠加 5 层，不可驱散。", "，持续 3 回合。该效果可与「暴击」叠加，触发后冷却 2 回合，每场最多 5 次。"]
const ROWS := [
	{"text": "自带：暴击率 +15%，暴击伤害 +40%，穿透 8%，吸血 3.5%。", "spans": [["自带：", Color("f2d08a")], ["暴击率 +15%，暴击伤害 +40%，", Color("98e598")], ["穿透 8%，吸血 3.5%。", Color("84aaff")]]},
	{"text": "词条：攻击时有 18% 几率造成 120% 暴击，冷却 2 回合，每场最多触发 5 次。"},
]
const BOSS_A := ["被施加的目标每回合损失当前生命", "该状态使目标每回合损失当前生命，并陷入灼烧", "目标每回合都会损失一部分当前生命", "被施加的目标每回合损失 5% 当前生命，持续 3 回合"]
const BOSS_EX := ["", "，每层额外 +3%", "，并降低其防御", "，且无法被净化", "，并附带「虚弱」", "，持续 4 回合"]
const BOSS_B := ["，若目标同时处于「灼烧」", "；若目标同时处于「灼烧」状态", "，目标若同时处于「灼烧」"]
const BOSS_TAIL := "，则伤害提升 +120%，并使其行动条延后 20%；层数上限 5 层，不可驱散。"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _grab() -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _run() -> void:
	TestEnv.isolate("xiyou_skin_text_shots")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin._clock_ms = 100000
	if out_dir != "" and DisplayServer.get_name() != "headless":
		get_window().size = SHOT
		get_viewport().gui_disable_input = true
		DirAccess.make_dir_recursive_absolute(out_dir)
		for pct in [100, 130]:
			XFontScale.set_value("global", pct)
			await _card_shot(pct, false)
			await _card_shot(pct, true)
			await _boss_shot(pct)
			await _hang_check(pct)
	else:
		check("needs_window", true)
	XUiSkin.FORCE = false
	XUiSkin.DETAIL_V1 = true
	XUiSkin.motion_override = -1
	XUiSkin._clock_ms = -1
	XFontScale.set_value("global", 100)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _col(x: float, caption: String) -> Control:
	var col := Control.new()
	col.position = Vector2(x, 0)
	col.size = Vector2(640, SHOT.y)
	col.clip_contents = true
	var bg := ColorRect.new()
	bg.color = Color("090808")
	bg.size = col.size
	col.add_child(bg)
	var lb := Label.new()
	lb.text = caption
	lb.position = Vector2(16, 10)
	lb.add_theme_font_size_override("font_size", 20)
	col.add_child(lb)
	return col


func _card(after: bool, expand: bool, col: Control, desc: String, card_w: float) -> XSkinCard:
	XUiSkin.DETAIL_V1 = after
	var card := XSkinCard.new()
	card.position = Vector2(60 if not expand else 270, 60)
	card.size = Vector2(card_w, 560) if expand else Vector2(card_w, 420)
	col.add_child(card)
	card.setup({"title": "饮血长刀", "title_color": XUiSkin.quality_color(4), "subtitle": "武器 · 传说", "fold": true,
		"desc": desc, "notice": "仅限天启篇使用，装备后不可交易。",
		"sections": [{"title": "属性词条", "rows": ROWS}], "expand_bounds": Vector2(40, 680)})
	return card


func _card_shot(pct: int, expand: bool) -> void:
	var fs := XUiSkin.FS_AUX_MAX
	var card_w := 500.0
	var cands := []
	for a in DESC_A:
		for b in DESC_B:
			for c in DESC_C:
				for tl in DESC_TAILS:
					for ex in DESC_EX:
						cands.append(a + "，" + b + c + ex + tl)
	var desc := ""
	var best := -1
	for cw in range(480, 561, 4):   # 牌宽也扫一扫：展开态正文宽＝2×牌宽，总能挑到旧折行有毛病的一组
		var ww := (cw * 2.0 if expand else float(cw)) - XUiSkin.PAD_LG * 2.0
		var got := _pick(cands, fs, ww, false)
		if int(got[1]) > best:
			best = int(got[1])
			desc = got[0]
			card_w = float(cw)
		if best >= 2:
			break
	check("card_shot_has_legacy_defect_%s_%d" % ["expanded" if expand else "folded", pct], best > 0, [best, card_w])
	var imgs := []
	for after in [false, true]:
		XUiSkin.DETAIL_V1 = after
		var root := Control.new()
		root.size = Vector2(SHOT)
		var col := _col(0.0, "改后（XSkinText）" if after else "改前（DETAIL_V1=false）")
		col.size = Vector2(SHOT)
		(col.get_child(0) as ColorRect).size = Vector2(SHOT)
		root.add_child(col)
		var card := _card(after, expand, col, desc, card_w)
		add_child(root)
		await frames(3)
		if expand:
			card.set_expanded(true)
		for c in _canvas(root):
			c.queue_redraw()
		imgs.append(await _grab())
		root.queue_free()
		await frames(2)
	if expand:   # 展开牌两倍宽，前后各一张
		imgs[0].save_png(out_dir.path_join("card_expanded_%d_before.png" % pct))
		imgs[1].save_png(out_dir.path_join("card_expanded_%d_after.png" % pct))
	else:
		var img := Image.create(SHOT.x, SHOT.y, false, imgs[0].get_format())
		img.blit_rect(imgs[0], Rect2i(0, 0, 640, SHOT.y), Vector2i(0, 0))
		img.blit_rect(imgs[1], Rect2i(0, 0, 640, SHOT.y), Vector2i(640, 0))
		img.save_png(out_dir.path_join("card_folded_%d.png" % pct))


## 候选句里：旧折行毛病分最高、新折行零毛病的一句（行首标点 2 分，末行孤字／英文数字腰斩各 1 分）
func _pick(cands: Array, fs: int, w: float, warn := true) -> Array:
	var f := XUiSkin.font("body")
	var best := ""
	var best_score := -1
	for t in cands:
		XUiSkin.DETAIL_V1 = false
		var old := XSkinText.wrap_ranges(t, f, fs, w)
		XUiSkin.DETAIL_V1 = true
		var cur := XSkinText.wrap_ranges(t, f, fs, w)
		if _score(t, cur) == 0 and _score(t, old) > best_score:
			best = t
			best_score = _score(t, old)
	if warn:
		check("pick_has_legacy_defect_%d_%s" % [int(w), str(best_score)], best_score > 0, [w, fs])
	return [best if best != "" else str(cands[0]), best_score]


func _score(t: String, rs: Array) -> int:
	var sc := 0
	for i in rs.size():
		var line := t.substr(rs[i].x, rs[i].y - rs[i].x).strip_edges()
		if line != "" and NO_START.contains(line[0]):
			sc += 2
		if i == rs.size() - 1 and i > 0 and line.length() <= 2:
			sc += 1
		if i > 0:
			var a := t.substr(rs[i - 1].x, rs[i - 1].y - rs[i - 1].x)
			if a != "" and a[a.length() - 1].unicode_at(0) < 128 and a[a.length() - 1] != " " and line != "" and line.unicode_at(0) < 128 and line[0] != " ":
				sc += 1
	return sc


func _canvas(n: Node) -> Array:
	var out := []
	if n is CanvasItem:
		out.append(n)
	for c in n.get_children():
		out.append_array(_canvas(c))
	return out


func _boss_shot(pct: int) -> void:
	var p := XSkinBossStatus.new()
	var bc := []
	for a in BOSS_A:
		for b in BOSS_B:
			for ex in BOSS_EX:
				bc.append(a + ex + b + BOSS_TAIL)
	var boss_desc: String = _pick(bc, 16, XSkinBossStatus.DETAIL_W - 44.0)[0]
	var row := {"id": "1", "name": "烈焰灼烧", "icon": 100, "kind": "Debuff", "stack": "3 层", "turns": "4回合", "description": boss_desc}
	var imgs := []
	for after in [false, true]:
		XUiSkin.DETAIL_V1 = after
		var root := Control.new()
		root.size = Vector2(SHOT)
		var bg := ColorRect.new()
		bg.color = Color("090808")
		bg.size = Vector2(SHOT)
		root.add_child(bg)
		var cv := XMVCanvas.new()
		cv.size = Vector2(XSkinBossStatus.DETAIL_W, XSkinBossStatus.DETAIL_H)
		cv.position = Vector2(400, 150)
		cv.painter = func(c: XMVCanvas) -> void:
			XUiSkin.draw_panel(c.get_canvas_item(), Rect2(0, 0, XSkinBossStatus.DETAIL_W, XSkinBossStatus.DETAIL_H))
			p._paint_selected(c, row)
		root.add_child(cv)
		add_child(root)
		var img := await _grab()
		imgs.append(img.get_region(Rect2i(400, 150, 480, 400)))
		root.queue_free()
		await frames(2)
	var out := Image.create(980, 400, false, imgs[0].get_format())
	out.fill(Color("090808"))
	out.blit_rect(imgs[0], Rect2i(0, 0, 480, 400), Vector2i(0, 0))
	out.blit_rect(imgs[1], Rect2i(0, 0, 480, 400), Vector2i(500, 0))
	out.save_png(out_dir.path_join("boss_detail_%d.png" % pct))
	# 改后：每行行首无避头标点（读 wrap_lines）
	XUiSkin.DETAIL_V1 = true
	var f := XUiSkin.font("body")
	var bad := false
	for ln in XSkinBossStatus.wrap_lines(f, boss_desc, XSkinBossStatus.DETAIL_W - 44.0, 16):
		if str(ln) != "" and NO_START.contains(str(ln)[0]):
			bad = true
	check("boss_desc_no_head_punct_%d" % pct, not bad)


## 挂出的行尾标点不能被画法裁掉：找一句在折叠牌正文宽度下有「挂出」行的话，真画出来，看 w 右边 0.35 字号里有墨迹
func _hang_check(pct: int) -> void:
	XUiSkin.DETAIL_V1 = true
	var f := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX_MAX
	var w := 500.0 - XUiSkin.PAD_LG * 2.0
	var text := ""
	var hang_w := 0.0
	var gw := f.get_string_size("。", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for a in range(4, 40):
		for b in range(0, 9):
			if text != "":
				break
			var t := "魔".repeat(a) + "5".repeat(b) + "。"
			var rs := XSkinText.wrap_ranges(t, f, fs, w)
			var lw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if rs.size() == 1 and lw > w + 1.0:
				text = t
				hang_w = lw
	if not check("hang_sample_found_%d" % pct, text != ""):
		return
	var root := Control.new()
	root.size = Vector2(SHOT)
	var bg := ColorRect.new()
	bg.color = Color("090808")
	bg.size = Vector2(SHOT)
	root.add_child(bg)
	var card := XSkinCard.new()
	card.position = Vector2(60, 60)
	card.size = Vector2(500, 420)
	root.add_child(card)
	card.setup({"title": "测试", "desc": text})
	add_child(root)
	var img := await _grab()
	var x0 := int(card.position.x + card.pad)
	var ink := 0
	for y in range(100, 480):
		for x in range(x0 + int(hang_w - gw) + 1, x0 + int(hang_w - gw * 0.4)):
			if img.get_pixel(x, y).get_luminance() > 0.25:
				ink += 1
	check("card_hang_punct_not_clipped_%d" % pct, ink > 0, [ink, w, hang_w])
	root.queue_free()
	await frames(2)
