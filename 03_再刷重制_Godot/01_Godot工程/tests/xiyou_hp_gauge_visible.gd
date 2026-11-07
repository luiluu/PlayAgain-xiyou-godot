extends Node
## 敌人血条显隐（YEP_X_VisualHpGauge Game_Enemy.hpGaugeVisible，插件参数 Defeat First=false、Always Visible=false）：
## 隐藏成员 → 不显示；备注 <HIDE HP GAUGE> → 不显示（与 <SHOW HP GAUGE> 同写时 HIDE 先判）；
## <SHOW HP GAUGE> 与什么都不写在默认参数下等价。正式数据：HIDE 566 个敌人、SHOW 278 个、两个都写 2 个（v0.62.12；v0.28 时 546／277）。
## 画面：HIDE 的敌人受伤／被选中时血条（12px 粗条、gradient）不画，名字（Olivia 窗口）照画。
## 参照：mv_oracle/hp_gauge_probe.cjs 在真实原版里逐个敌人读 hpGaugeVisible()（夹具 tests/fixtures/hp_gauge_oracle.json），不再用「自己的正则比自己」。
class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

## 记录 gradient（血条填充）与 text（名字、数字）调用
class RecCanvas extends XMVCanvas:
	var gradients := 0
	var texts := 0
	func gradient(r: Rect2, c1: Color, c2: Color) -> void:
		gradients += 1
		super(r, c1, c2)
	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		texts += 1
		super(s, x, y, max_w, align, color, size, lh, alpha, zoom, pivot, outline)

var results := []
var out_dir := ""   # 窗口模式加 -- --out=<目录>：存「有血条／HIDE 无血条」两张对照截图


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	XSave.dir_override = "user://test_xiyou_hp_gauge_visible"
	XConfig.path_override = XSave.dir().path_join("options.json")
	# 参照：tests/fixtures/hp_gauge_oracle.json（mv_oracle/hp_gauge_probe.cjs 在真实原版里逐个 new Game_Enemy 读 hpGaugeVisible()，审查 40 P3-8）
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hp_gauge_oracle.json"))
	check("oracle_present", ref is Dictionary and ref.cases is Array and ref.cases[0].errors.is_empty())
	var rows: Array = ref.cases[0].observed.rows
	check("oracle_params_default", ref.cases[0].observed.params.defeatFirst == "false", ref.cases[0].observed.params)
	var hide_n := 0
	var show_n := 0
	var both_n := 0
	var wrong := []
	var wrong_hidden := []
	var missing := []
	var sample_hide := 0
	var sample_show := 0
	var sample_none := 0
	for row in rows:
		var h: bool = row.hideFlag
		var s: bool = row.showFlag
		hide_n += int(h)
		show_n += int(s)
		both_n += int(h and s)
		if not XDB.rec("Enemies", int(row.id)) is Dictionary or XDB.rec("Enemies", int(row.id)).is_empty():
			missing.append(row.id)
			continue
		var e := XEnemy.new()
		e.enemy_id = int(row.id)
		# 最终的小血条（战斗画面用的 XBossHpBar.small_gauge_visible）：新源 v0.37 起真气首领血条范围里的神兵之仙
		# （984～990、2005～2009 等）原版 hpGaugeVisible 也返回 false
		if XBossHpBar.small_gauge_visible(e) != bool(row.visible):
			wrong.append(row.id)
		e.hidden = true
		if XBossHpBar.small_gauge_visible(e) != bool(row.hiddenVisible):
			wrong_hidden.append(row.id)
		if h and sample_hide == 0:
			sample_hide = int(row.id)
		elif s and not h and sample_show == 0:
			sample_show = int(row.id)
		elif not h and not s and sample_none == 0:
			sample_none = int(row.id)
	check("counts_hide_566", hide_n == 566, hide_n)
	check("counts_show_278", show_n == 278, show_n)
	check("counts_both_2", both_n == 2, both_n)
	check("oracle_enemies_all_in_remake", missing.is_empty(), missing.slice(0, 8))
	check("visible_matches_original_for_all_enemies", wrong.is_empty(), wrong.slice(0, 8))
	check("hidden_matches_original_for_all_enemies", wrong_hidden.is_empty(), wrong_hidden.slice(0, 8))
	var e2 := XEnemy.new()
	e2.enemy_id = sample_none
	e2.hidden = true
	check("hidden_member_no_gauge", not e2.hp_gauge_visible())
	e2.hidden = false
	check("plain_enemy_gauge", e2.hp_gauge_visible())
	e2.enemy_id = sample_show
	check("show_tag_same_as_default", e2.hp_gauge_visible())
	e2.enemy_id = sample_hide
	check("hide_tag_no_gauge", not e2.hp_gauge_visible())
	# 画面
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = XRandomStream.hex64(20261104)
	var scene := QuietBattle.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	var e: XEnemy = scene.logic.enemies[0]
	var rec := RecCanvas.new()
	rec.size = Vector2(640, 100)
	scene.field.add_child(rec)
	var g: Dictionary = scene.gauges[e]
	g.box.queue_free()
	g.box = rec
	rec.painter = func(canvas): scene._paint_enemy(canvas, e)
	for case in [["plain", sample_none, true], ["show", sample_show, true], ["hide", sample_hide, false]]:
		e.enemy_id = case[1]
		e.hidden = false
		rec.gradients = 0
		rec.texts = 0
		e.hp = maxf(1.0, e.hp)  # 活着：HP 为 0 时画面不画血条，会让下面的比较在 HIDE 之外也过
		g.timer = 5.0   # 受伤后血条显示中
		g.name_timer = 5.0
		rec.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		check("paint_%s_gauge" % case[0], (rec.gradients > 0) == case[2], [rec.gradients, e.hp])
		if out_dir != "" and DisplayServer.get_name() != "headless" and case[0] != "show":
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("gauge_%s.png" % case[0]))
		check("paint_%s_name_still_drawn" % case[0], rec.texts >= 1, rec.texts)
	scene.queue_free()
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
