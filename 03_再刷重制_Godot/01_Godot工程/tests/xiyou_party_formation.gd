extends Node
## 战斗站位（XPartyFormation，O-待定，Kyo 11-15）专项：
## ① 默认两排错开；三种阵型 1～5 人的点位都在可用区内（新阵型：右侧状态栏、底部行动顺序条、顶部按 ×1.35 大体型留空）、互相分得开；
## ② 编队第 k 位站阵型第 k 个点（两排：1 前上 2 前下 3 后上 4 后下；菱形：1 前尖 2 上角 3 下角 4 后尖）；
## ③ 设置页「战斗站位」确定循环、左右夹住、存配置重读、坏值回默认；切换后下一场战斗生效，绘制次序靠下的在上；
## ④ 指令窗锚点不越过原版竖排的锚点；⑤ 回退 ENABLED＝false：设置页不列、站位照原版竖排。
## 配置写 user://test_xiyou_party_formation（不读 Kyo 真实 options.json）。
## 窗口模式加 -- --out=<目录> 截三种阵型的 4 人战斗图（敌群 693，渡鸦神话／五条悟／米拉黑龙／宿傩）。
var results := []
var out_dir := ""

const USABLE_RIGHT := 1080.0   # 右侧状态栏左边
const LINE_X := 819.0          # 阵型最右不过原版竖排那条线（指令窗贴在它右边）
const USABLE_BOTTOM := 600.0   # 脚底最低（底部行动顺序条约在 610）
const USABLE_LEFT := 480.0     # 半身最左（敌人一侧，敌群成员 x 九成五在 406 以内）
const BIG_W := 180.0           # ×1.35 大体型可视宽
const BIG_H := 215.0           # ×1.35 大体型可视高
const TOP_MIN := 60.0          # 大体型头顶最高（顶部 Boss 信息框）

class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_party_formation", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _fresh_config() -> void:
	XSave.dir_override = "user://test_xiyou_party_formation"
	DirAccess.make_dir_recursive_absolute(XSave.dir())
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.remove_absolute(XConfig.path())
	XConfig._loaded_path = "<unloaded>"


func _reload() -> void:
	XConfig._loaded_path = "<unloaded>"
	XConfig.ensure_loaded()


func _run() -> void:
	_fresh_config()
	check("default_rows", XConfig.party_formation() == XPartyFormation.ROWS and XPartyFormation.current() == XPartyFormation.ROWS and XPartyFormation.text() == "两排错开")
	_points()
	_order()
	await _options()
	await _scene()
	_anchor()
	await _rollback()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _shots()
	XState.current = null
	finish()


## ① 点位：数量、可用区、互相分得开
func _points() -> void:
	for kind in [XPartyFormation.ROWS, XPartyFormation.DIAMOND, XPartyFormation.COLUMN]:
		for n in range(1, 6):
			var pts := XPartyFormation.points(kind, n)
			var tag := "%s.%d" % [XPartyFormation.NAMES[kind], n]
			check("count." + tag, pts.size() == n, pts)
			if kind == XPartyFormation.COLUMN:
				check("column_same." + tag, pts == XBattleScene.party_layout(n), pts)
				continue
			var bad := []
			for p in pts:
				if p.x > LINE_X or p.x + BIG_W / 2.0 > USABLE_RIGHT or p.x - BIG_W / 2.0 < USABLE_LEFT or p.y > USABLE_BOTTOM or p.y - BIG_H < TOP_MIN:
					bad.append(p)
			check("usable." + tag, bad.is_empty(), bad)
			var close := []
			for i in range(n):
				for j in range(i + 1, n):
					var d: Vector2 = (pts[i] - pts[j]).abs()
					if d.x < 120.0 and d.y < 150.0:
						close.append([i + 1, j + 1, pts[i], pts[j]])
			check("apart." + tag, close.is_empty(), close)
	check("over5_column", XPartyFormation.points(XPartyFormation.ROWS, 6) == XBattleScene.party_layout(6))
	check("zero_empty", XPartyFormation.points(XPartyFormation.DIAMOND, 0).is_empty())


## ② 编队第 k 位对应的点（「前」＝离敌人近＝x 小）
func _order() -> void:
	var r := XPartyFormation.points(XPartyFormation.ROWS, 4)
	check("rows4.front_back", r[0].x == r[1].x and r[2].x == r[3].x and r[0].x < r[2].x, r)
	check("rows4.stagger", r[0].y < r[2].y and r[2].y < r[1].y and r[1].y < r[3].y and is_equal_approx(r[2].y - r[0].y, (r[1].y - r[0].y) / 2.0), r)
	var d := XPartyFormation.points(XPartyFormation.DIAMOND, 4)
	check("diamond4.tips", d[0].x < d[1].x and d[3].x > d[1].x and d[0].y == d[3].y and d[1].x == d[2].x, d)
	check("diamond4.corners", d[1].y < d[0].y and d[2].y > d[0].y and is_equal_approx(d[0].y - d[1].y, d[2].y - d[0].y), d)
	var r5 := XPartyFormation.points(XPartyFormation.ROWS, 5)
	check("rows5.keeps_1_4", r5[0].x == r[0].x and r5[1].x == r[1].x and r5[2].x == r[2].x and r5[3].x == r[3].x and r5[0].y < r5[4].y and r5[4].y < r5[1].y and r5[4].x == r[0].x, r5)
	var d5 := XPartyFormation.points(XPartyFormation.DIAMOND, 5)
	check("diamond5.keeps_1_4", d5.slice(0, 4) == d and d5[4] == Vector2(XPartyFormation.DIA_CX, XPartyFormation.DIA_CY), d5)
	check("slot_names", XPartyFormation.SLOT_NAMES[XPartyFormation.ROWS].slice(0, 4) == ["前上", "前下", "后上", "后下"] and XPartyFormation.SLOT_NAMES[XPartyFormation.DIAMOND].slice(0, 4) == ["前尖", "上角", "下角", "后尖"])


## ③ 设置页：确定循环、左右夹住、存配置
func _options() -> void:
	XState.new_game(3, 1, [8, 9, 10])
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	var i := opt.symbols().find(XPartyFormation.KEY)
	check("option_listed", i >= 0 and opt._list[i][0] == "战斗站位", opt.symbols())
	check("option_after_auto", not XBattleScene.AUTO_DEFAULT or i == opt.symbols().find("codexBattleAutoDefault") + 1, opt.symbols())
	opt.index = i
	check("option_text_default", opt.status_text(i) == "两排错开")
	var seen := []
	for k in 3:
		opt.ok()
		seen.append(opt.status_text(i))
	check("option_ok_cycle", seen == ["菱形", "原版竖排", "两排错开"], seen)
	opt._side(false)
	check("option_left_clamp", XConfig.party_formation() == XPartyFormation.ROWS)
	opt._side(true)
	check("option_right", XConfig.party_formation() == XPartyFormation.DIAMOND and opt.status_text(i) == "菱形")
	opt._side(true)
	opt._side(true)
	check("option_right_clamp", XConfig.party_formation() == XPartyFormation.COLUMN)
	opt._side(false)
	_reload()
	check("option_saved", XConfig.party_formation() == XPartyFormation.DIAMOND)
	opt.queue_free()
	await frames()
	# 坏值回默认
	var f := FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({XPartyFormation.KEY: "菱形"}))
	f.close()
	_reload()
	check("sanitize_bad", XConfig.party_formation() == XPartyFormation.DEFAULT)
	f = FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({XPartyFormation.KEY: 9}))
	f.close()
	_reload()
	check("sanitize_clamp", XConfig.party_formation() == XPartyFormation.COLUMN)


func _battle_homes(b: XBattleScene) -> Array:
	return b.logic.actors.map(func(a): return b.sprites[a].home)


## 按脚底 y 自上而下的绘制次序（子节点顺序）
func _drawn_sorted(b: XBattleScene) -> bool:
	var sp: Array = b.logic.actors.map(func(a): return b.sprites[a])
	sp.sort_custom(func(x, y): return x.get_index() < y.get_index())
	for k in range(sp.size() - 1):
		if sp[k].home.y > sp[k + 1].home.y:
			return false
	return true


## ③ 切换后下一场生效
func _scene() -> void:
	XState.new_game(3, 1, [8, 9, 10])
	for kind in [XPartyFormation.DIAMOND, XPartyFormation.ROWS, XPartyFormation.COLUMN]:
		XConfig.set_party_formation(kind)
		var b := QuietBattle.new()
		b.setup(2, true, false, {})
		add_child(b)
		await frames()
		var n: int = b.logic.actors.size()
		var tag: String = XPartyFormation.NAMES[kind]
		check("scene_homes." + tag, n == 4 and _battle_homes(b) == XPartyFormation.points(kind, n), _battle_homes(b))
		check("scene_draw_order." + tag, _drawn_sorted(b))
		b.queue_free()
		await frames()


## ④ 指令窗锚点
func _anchor() -> void:
	XConfig.set_party_formation(XPartyFormation.ROWS)
	var back: Vector2 = XPartyFormation.points(XPartyFormation.ROWS, 4)[3] + Vector2(32, -64)
	check("anchor_low_capped", XPartyFormation.window_anchor(back) == Vector2(851, 462), XPartyFormation.window_anchor(back))
	var front: Vector2 = XPartyFormation.points(XPartyFormation.ROWS, 4)[0] + Vector2(32, -64)
	check("anchor_front_right_of_formation", XPartyFormation.window_anchor(front) == Vector2(851, front.y), XPartyFormation.window_anchor(front))
	XConfig.set_party_formation(XPartyFormation.COLUMN)
	check("anchor_column_untouched", XPartyFormation.window_anchor(Vector2(982, 516)) == Vector2(982, 516))


## ⑤ 回退
func _rollback() -> void:
	XConfig.set_party_formation(XPartyFormation.DIAMOND)
	XPartyFormation.ENABLED = false
	check("rollback_current", XPartyFormation.current() == XPartyFormation.COLUMN)
	check("rollback_points", XPartyFormation.points(XPartyFormation.DIAMOND, 4) == XBattleScene.party_layout(4))
	check("rollback_anchor", XPartyFormation.window_anchor(Vector2(982, 516)) == Vector2(982, 516))
	XState.new_game(3, 1, [8, 9, 10])
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	check("rollback_option_hidden", not opt.symbols().has(XPartyFormation.KEY))
	opt.queue_free()
	var b := QuietBattle.new()
	b.setup(2, true, false, {})
	add_child(b)
	await frames()
	check("rollback_scene_column", _battle_homes(b) == XBattleScene.party_layout(4), _battle_homes(b))
	b.queue_free()
	await frames()
	XPartyFormation.ENABLED = true


## 截图：敌群 693，渡鸦神话／五条悟／米拉黑龙／宿傩
func _shots() -> void:
	const LINEUP := [167, 180, 168, 172]
	# 天启篇一场只上 3 人，截图要 4 人：用普通档，五条悟（只在天启篇）直接放进队伍与出战栏，只为看站位
	var s := XState.new_game_blank()
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [167, 168, 172]:
		s.add_actor(id)
	s.party.assign(LINEUP.duplicate())
	s.battle_slots.assign(LINEUP.duplicate() + [0])
	s.actor_advance[XMira.ACTOR] = 3
	for id in LINEUP:
		s.actor(id).change_level(99)
	var mira := s.actor(XMira.ACTOR)
	mira.learn_skill(10161)
	mira.state_ids.append(XMira.DRAGON)
	s.raven["myth"] = 3
	for id in LINEUP:
		s.actor(id).recover_all()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for kind in [XPartyFormation.ROWS, XPartyFormation.DIAMOND, XPartyFormation.COLUMN]:
		XConfig.set_party_formation(kind)
		var b := XBattleScene.new()
		b.setup(693, true, false, XDB.map(5))
		add_child(b)
		for k in 600:
			await frames(1)
			if b.cmd_win != null:
				break
		var m: XActor = s.actor(XMira.ACTOR)
		if not m.state_ids.has(XMira.DRAGON):  # 开战清掉了的话，在战斗里再挂上黑龙形态
			m.add_new_state(XMira.DRAGON)
		await frames(20)
		await RenderingServer.frame_post_draw
		var name: String = ["rows", "diamond", "column"][kind]
		check("shot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join("party_%s.png" % name)) == OK)
		print("SHOT ", name, " party=", b.logic.actors.map(func(a): return a.actor_id), " homes=", _battle_homes(b), " looks=", b.logic.actors.map(func(a): return b.sprites[a]._look_key))
		b.queue_free()
		await frames(4)
