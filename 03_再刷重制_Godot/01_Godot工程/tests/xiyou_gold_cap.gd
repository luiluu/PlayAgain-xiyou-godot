extends Node
## 精魂上下限（XState.gain_gold）：按正式 gold_probe.cjs（Game_Party.gainGold／maxGold、Yanfly.Util.toGroup、JsonEx）逐项比对——
## 上限 9999 亿、超 9.99 亿收支、千位分组、存读档往返（大于 2^31）；下限照 O-085（GOLD_FLOOR_ZERO 开着时为 0，关掉照原版 -99999999）。
## 修炼：小萝莉第三页每级 15 亿的「命脉强化」用 gain_gold 收进的 50 亿可连买三级。
## 显示对照冻结 v0.28 浏览器读数（新局、精魂 999999999999，包住 drawCurrencyValue／Bitmap.drawText）：主菜单与商店金钱窗的文字、
## 右缘与字号；YEP Gold Overlap：金额宽过（金额区宽 − 图标 32）时整段换成「A lotta」，9999 亿在这些窗里都不超宽。

const ORACLE := "res://modes/xiyou/generated/oracle/gold.json"
## 正式版读数：[窗口, 画布宽（contents）, 文字, 文字右缘 x＋maxWidth, y]；文字宽 161.25（字号 20）
const UI_REF := {
	"menu": [212.0, "999,999,999,999", 170.0, 0.0],   # Scene_Menu Window_Gold (0,656,240,64)：drawText(6,0,164,'right')
	"crafting": [212.0, "999,999,999,999", 170.0, 0.0],   # hc.js Window_Gold 内容层按初始宽 240 建（同主菜单）
	"shop": [484.0, "999,999,999,999", 442.0, 0.0],   # Scene_Shop Window_Gold (768,656,512,64)：drawText(6,0,436,'right')
}
const MAX_TEXT_W := 161.25

var results := []


class RecCanvas extends XMVCanvas:
	var log := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		log.append(["text", s, x + max_w, y, size, align])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["icon", index, x, y])


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("gold_oracle_loaded", d is Dictionary and d.has("seqs"), ORACLE):
		check("max_gold", XState.GOLD_MAX == int(d.maxGold), [XState.GOLD_MAX, d.maxGold])
		check("gold_font", XShop.GOLD_FONT == int(d.goldFontSize) and XMenu.GOLD_OVERLAP == str(d.goldOverlap) and XMenu.GOLD_ICON == int(d.goldIcon))
		for sq in d.seqs:
			var s := XState.new_game_blank()
			s.gold = int(sq.start)
			var got := []
			var want := []
			var prev := int(sq.start)
			for step in sq.steps:
				s.gain_gold(int(step))
				got.append(s.gold)
				prev = clampi(prev + int(step), 0, XState.GOLD_MAX)
				want.append(prev)
			# 原版没扣成负数的段逐步相同；扣成负数的段在 O-085 开着时按下限 0 逐步夹取
			var neg: bool = sq.after.any(func(v): return int(v) < 0)
			var ref: Array = want if neg and XState.GOLD_FLOOR_ZERO else sq.after.map(func(v): return int(v))
			check("seq_" + str(sq.name), got == ref, [got, ref, sq.after])
		for g in d.groups:
			check("group_%s" % str(g[0]), XMenu._group(float(g[0])) == str(g[1]), [XMenu._group(float(g[0])), g[1]])
		for sv in d.saves:
			var s := XState.new_game_blank()
			s.gold = int(sv[0])
			var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
			check("save_%s" % str(sv[0]), back.gold == int(sv[1]), [back.gold, sv[1]])
	_check_training()
	await _check_ui()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _check_training() -> void:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9]:
		s.add_actor(id)
	s.gold = 0
	s.gain_gold(5000000000)
	XState.current = s
	XTraining.xiulian = [49, 50, 51, 52, 53, 54, 55, 56]
	var tips := []
	for i in 4:
		tips.append(XTraining.confirm(s, 1, 49))
	check("training_15e8", s.gold == 500000000 and XTraining.level(s, 1, 49) == 3 and tips == ["修炼成功", "修炼成功", "修炼成功", "等级已满"], [s.gold, tips])
	s.gold = 1499999999
	check("training_15e8_poor", XTraining.confirm(s, 1, 50) == str(XDB.system().get("currencyUnit", "")) + "不足" and s.gold == 1499999999, s.gold)


func _paint(key: String, painter: Callable) -> Array:
	var rc := RecCanvas.new()
	rc.size = Vector2(UI_REF[key][0], 36)
	rc.painter = painter
	add_child(rc)
	for _i in 2:
		await get_tree().process_frame
	var out: Array = rc.log.filter(func(e): return e[0] == "text")
	rc.queue_free()
	return out


func _check_ui() -> void:
	var s := XState.new_game_blank()
	s.gold = XState.GOLD_MAX
	XState.current = s
	var rc := RecCanvas.new()
	add_child(rc)
	check("text_width_max", absf(rc.text_width("999,999,999,999", 20) - MAX_TEXT_W) <= 3.0, rc.text_width("999,999,999,999", 20))
	# A lotta：金额区 168（主菜单）放得下 9999 亿；宽度不够时整段换掉，字符串照原样判断
	check("overlap_fits", XMenu.currency_text(rc, XState.GOLD_MAX, 168.0) == "999,999,999,999")
	check("overlap_lotta", XMenu.currency_text(rc, XState.GOLD_MAX, 120.0) == "A lotta" and XMenu.currency_text(rc, "-1,500,000,000", 100.0) == "A lotta")
	rc.queue_free()
	var menu := XMenu.new()
	var craft := XCraftingScene.new()
	var shop := XShop.new()
	for pair in [["menu", menu._paint_gold], ["crafting", craft._paint_gold], ["shop", shop._paint_gold]]:
		var got: Array = await _paint(pair[0], pair[1])
		var w: Array = UI_REF[pair[0]]
		var ok := got.size() == 1 and got[0][1] == w[1] and absf(float(got[0][2]) - w[2]) <= 1.0 and float(got[0][3]) == w[3] and int(got[0][4]) == 20 and got[0][5] == "right"
		check("ui_" + pair[0], ok, [got, w])
	menu.free()
	craft.free()
	shop.free()
