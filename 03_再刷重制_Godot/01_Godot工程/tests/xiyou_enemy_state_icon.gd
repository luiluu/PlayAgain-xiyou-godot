extends Node
## 选敌名字旁的状态图标（ui12）：Olivia_WeaknessDisplay＋YEP_BuffsStatesCore 回合数＋CP_StateFloor 层数。
## 原版读数 tests/fixtures/enemy_state_icon_oracle.json；回退开关 XEnemyStateIcon.SHOW、FLOOR_TEXT。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/enemy_state_icon_oracle.json"))
	var cs: Dictionary = ref.case_states
	check("wait_20", XEnemyStateIcon.wait() == float(ref.wait), XEnemyStateIcon.wait())
	var p := XDB.plugin("Olivia_WeaknessDisplay")
	check("olivia_params", str(p.get("Weakness Show States", "")) == "true" and str(p.get("Weakness Show HP Gauge", "")) == "false" and str(p.get("Name Font Size", "")) == "18", p)
	# 弱点图标：Element Icons 全 0、Unknown Weakness Icon 0，原版弱点那一行画的是第 0 格（选敌截图上名字下面什么也没有）；
	# 重制第 0 格不画，所以弱点行不用另做
	var el := str(p.get("Element Icons", ""))
	check("weak_icons_all_zero", Array(el.replace("\"", "").replace("[", "").replace("]", "").split(",")).all(func(x): return x.strip_edges() == "0") and str(p.get("Unknown Weakness Icon", "")) == "0" and XUI.icon_texture(0) == null, el)
	# 位置：名字宽 108（18 号 6 个全角字）→ (392, 16)
	check("icon_center", XEnemyStateIcon.icon_center(108.0) == Vector2(float(ref.icon_sprite.x), float(ref.icon_sprite.y)), XEnemyStateIcon.icon_center(108.0))
	var cv := XMVCanvas.new()
	add_child(cv)
	var nw := cv.text_width(str(ref.enemy.name), XEnemyStateIcon.NAME_SIZE)
	check("name_width_close", absf(nw - 108.0) <= 2.0, nw)
	# 睡眠 10＋中毒 4＋强化 2（5 回合）：图标 [942, 916, 34]；中毒不画回合数，睡眠画；强化绿色 24
	var e := XEnemy.new().setup(int(ref.enemy.enemy_id), 1)
	e.add_state(4)
	e.add_state(10)
	e.state_turns[10] = 4
	e.buffs[2] = 1
	e.buff_turns[2] = 5
	var g := XEnemyStateIcon.group(e)
	var icons := g.map(func(r): return int(r.icon))
	check("icons_order", icons == [942, 916, 34], icons)
	check("turns_text", g.size() == 3 and g[0].turns == "4" and g[1].turns == "" and g[2].turns == "5" and int(g[2].color) == 24 and int(g[0].color) == 0, g)
	check("turn_colors_match_oracle", XUI.text_color(24).to_html(false) == "80ff80" and XUI.text_color(0).to_html(false) == "ffffff", [XUI.text_color(24).to_html(false), XUI.text_color(0).to_html(false)])
	# 轮换：每 20 帧一格，0 → 1 → 2 → 0（原版读数同序）
	var st := {}
	var seq := []
	for i in 80:
		if XEnemyStateIcon.tick(st, e, 1.0):
			seq.append([int(st.index), int(st.cur.icon)])
	check("cycle_like_oracle", seq == [[1, 916], [2, 34], [0, 942], [1, 916]], seq)
	check("buff_icon_formula", XEnemyStateIcon.buff_icon(1, 2) == 34 and XEnemyStateIcon.buff_icon(3, 2) == 42 and XEnemyStateIcon.buff_icon(-1, 0) == 48 and XEnemyStateIcon.buff_icon(-2, 7) == 63, null)
	# 死了不画
	var dead := XEnemy.new().setup(int(ref.enemy.enemy_id), 1)
	dead.add_state(10)
	dead.hp = 0
	dead.add_state(1)
	check("dead_no_icons", XEnemyStateIcon.group(dead).is_empty(), XEnemyStateIcon.group(dead))
	# 层数 1323：原版字样画不出来（宽度写错）；O-待定 开着画「1层」，关了回原版
	var f := XEnemy.new().setup(int(ref.enemy.enemy_id), 1)
	f.add_state(int(ref.case_floor.state))
	var fg := XEnemyStateIcon.group(f)
	check("floor_row", fg.size() == 1 and int(fg[0].icon) == int(ref.case_floor.icon) and fg[0].floor == "1层", fg)
	check("floor_on_draws", XEnemyStateIcon.floor_text(fg[0]) == "1层")
	XEnemyStateIcon.FLOOR_TEXT = false
	check("floor_rollback_none", XEnemyStateIcon.floor_text(fg[0]) == "")
	XEnemyStateIcon.FLOOR_TEXT = true
	# 整块回退
	XEnemyStateIcon.SHOW = false
	check("show_rollback_none", XEnemyStateIcon.shown(st).is_empty())
	XEnemyStateIcon.SHOW = true
	check("show_on", not XEnemyStateIcon.shown(st).is_empty())
	# 名字窗不透明度（Window_WeaknessDisplay.updateOpacity）：显示中 255；到点后每帧 −16，16 帧后为 0；死了即使选中也淡出
	var a := XBattleScene.name_alpha_step(0.0, false, true, 1.0)
	var fades := []
	for i in 17:
		a = XBattleScene.name_alpha_step(a, false, false, 1.0)
		fades.append(a)
	check("name_fade_16_per_frame", fades[0] == 239.0 and fades[14] == 15.0 and fades[15] == 0.0 and fades[16] == 0.0, fades)
	check("name_dead_fades_even_selected", XBattleScene.name_alpha_step(255.0, true, true, 1.0) == 239.0)
	check("name_fade_switch_default", XBattleScene.NAME_FADE)
	# 画在画布上不出错（走画布自己的 _draw）
	cv.painter = func(c): XEnemyStateIcon.paint(c, st, nw)
	cv.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	cv.queue_free()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
