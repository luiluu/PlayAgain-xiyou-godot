extends Node
const TestEnv = preload("res://tests/xiyou_test_env.gd")
## 【cc·未经审查】T588 西游档法宝说明卡文字（Kyo 11-28）：
## 1) 两行累计绿字换成一行「法宝等级：当前/本层上限」；不写满级值、等级上限、已满级、保留级；
## 2) 同一项属性只出现一次（织神天梭顶部八项已含成长，不另写加成行）；
## 3) 吞噬升级最低装备品级＝喂入判定 XFabaoFeed.min_grade 的当前一级，品级名与颜色照七档品质，到本层上限不写；
## 4) 天启篇的卡面开关开、关逐行相同；两个开关关掉回到原写法。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(900))


func _ready() -> void:
	_run.call_deferred()


func _state(floor_no: int, tianqi := false) -> XState:
	var s := XState.new_game_blank()
	if tianqi:
		s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [1]}
	s.set_variable(20, floor_no)
	XState.current = s
	return s


func _gear(kind: String, id: int, lv: int) -> Dictionary:
	var item := XGear.template(kind, id)
	item["level"] = lv
	return item


func _plain(rows: Array) -> Array:
	return rows.map(func(r): return XHelpCard.plain(str(r[0])).replace("\\lock[1]", ""))


## 两种卡面都看：说明卡 content 与右侧详情 detail_rows
func _views(item: Dictionary) -> Array:
	return [XHelpCard.content(item), XHelpCard.detail_rows(item, 380.0)]


func _count(lines: Array, part: String) -> int:
	return lines.filter(func(x): return str(x).contains(part)).size()


func _no_full_info(lines: Array) -> bool:
	var text := "\n".join(PackedStringArray(lines)).replace(XHelpCard.FABAO_OVER_CAP_HINT, "")
	for bad in ["累计", "满级", "等级上限", "当前等级", "（保留", "本层上限", "进化后加成翻倍"]:
		if text.contains(bad):
			return false
	return true


func _run() -> void:
	TestEnv.isolate("xiyou_fabao_card_t588")
	var was_state := XState.current
	var was := [XHelpCard.FABAO_BRIEF_T588, XHelpCard.FABAO_FEED_GRADE_T588]
	XHelpCard.FABAO_BRIEF_T588 = true
	XHelpCard.FABAO_FEED_GRADE_T588 = true
	_test_lines()
	_test_all_fabao()
	_test_feed_grade()
	_test_tianqi_and_rollback()
	_test_reinforced_once()
	_test_evolve_and_over_cap()
	_test_detail_key()
	await _test_feed_layout()
	XHelpCard.FABAO_BRIEF_T588 = was[0]
	XHelpCard.FABAO_FEED_GRADE_T588 = was[1]
	XState.current = was_state
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _test_lines() -> void:
	var s := _state(1)
	var zx := _gear("armor", 123, 5)
	var note := str(zx.note)
	var bonus := "法宝加成：全属性+%d" % int(XActor.magic_param(zx, 0))
	for rows in _views(zx):
		var lines := _plain(rows)
		var at := lines.find("法宝等级：5/12")
		check("zx.level_once", at >= 0 and _count(lines, "法宝等级：") == 1, lines)
		check("zx.bonus_once_after_level", at >= 0 and lines.find(bonus) == at + 1 and _count(lines, "全属性+") == 1, lines)
		check("zx.no_full_info", _no_full_info(lines), lines)
		var green: Array = rows.filter(func(r): return XHelpCard.plain(str(r[0])).contains("法宝等级："))
		check("zx.level_green", green.size() == 1 and str(green[0][2]) == XHelpCard.FABAO_LEVEL_COLOR, green)
	check("zx.note_untouched", str(zx.note) == note)

	# 超本层上限：a 按生效值；换层后 b 跟着变
	zx["level"] = 37
	check("zx.capped", _plain(XHelpCard.content(zx)).has("法宝等级：12/12"), _plain(XHelpCard.content(zx)))
	s.set_variable(20, 10)
	check("zx.floor10", _plain(XHelpCard.content(zx)).has("法宝等级：37/39"), _plain(XHelpCard.content(zx)))
	s.set_variable(20, 30)
	zx["level"] = 99
	var top := _plain(XHelpCard.content(zx))
	check("zx.level99", top.has("法宝等级：99/99") and top.has("法宝加成：全属性+15984") and _no_full_info(top), top)

	# 织神天梭：顶部八项之外不另写加成；原「当前等级」行换成同一写法
	s.set_variable(20, 1)
	var ys := _gear("armor", XYunshang.RELIC, 5)
	for rows in _views(ys):
		var lines := _plain(rows)
		check("yunshang.once", _count(lines, "法宝等级：5/12") == 1 and _count(lines, "法宝等级：") == 1 and _count(lines, "法宝加成：") == 0 and _no_full_info(lines), lines)
		check("yunshang.exp_kept", _count(lines, "法宝经验：") == 1, lines)
	s.set_variable(20, 30)
	ys["level"] = 99
	var ys99 := _plain(XHelpCard.content(ys))
	check("yunshang.level99", ys99.has("法宝等级：99/99") and _no_full_info(ys99), ys99)

	# 破限之心：等级、经验、加成连着写，各一次
	s.set_variable(20, 1)
	var gr := _gear("armor", 7904, 5)
	for rows in _views(gr):
		var lines := _plain(rows)
		var at := lines.find("法宝等级：5/12")
		check("garou.order", at >= 0 and at + 2 < lines.size() and str(lines[at + 1]).begins_with("经验：") and str(lines[at + 2]).begins_with("法宝加成：")
			and _count(lines, "法宝等级：") == 1 and _count(lines, "法宝加成：") == 1 and _no_full_info(lines), lines)


## 全库法宝：1 级、本层中段、99 级三种，等级行最多一行、不剩满级字样
func _test_all_fabao() -> void:
	var s := _state(30)
	var bad := []
	var seen := 0
	for table in ["Armors", "Weapons"]:
		for rec in XDB.table(table):
			if not (rec is Dictionary) or not XMagicWeapon.is_magic(rec) or not XMagicWeapon.scale_active(rec):
				continue
			var per := XActor.magic_per_level(rec)
			if per.all(func(v): return float(v) == 0.0):
				continue
			seen += 1
			for lv in [1, 50, 99]:
				var item := _gear("weapon" if table == "Weapons" else "armor", int(rec.id), lv)
				var lines := _plain(XHelpCard.content(item))
				var text := "\n".join(PackedStringArray(lines))
				if _count(lines, "法宝等级：%d/99" % lv) != 1 or _count(lines, "法宝加成：") > 1 or text.contains("累计") or text.contains("满级（") or text.contains("法宝满级") or text.contains("已满级") or _count(lines, "当前等级：") > 0:
					bad.append([int(rec.id), lv, lines])
	check("all.seen", seen > 100, seen)
	check("all.clean", bad.is_empty(), bad.slice(0, 2))
	check("all.state_kept", XState.current == s)


func _test_feed_grade() -> void:
	var s := _state(30)
	var zx := _gear("armor", 123, 1)
	var cfg := XQuality.config()
	for lv in [1, 24, 25, 44, 45, 64, 65, 84, 85, 98]:
		zx["level"] = lv
		var g := XFabaoFeed.min_grade(float(lv))
		for rows in _views(zx):
			var hit: Array = rows.filter(func(r): return XHelpCard.plain(str(r[0])).contains("吞噬升级最低装备品级："))
			check("feed.lv%d" % lv, hit.size() == 1 and XHelpCard.plain(str(hit[0][0])).ends_with("品级：" + str(cfg.names[g])) and str(hit[0][2]) == str(cfg.colors[g]), hit)
	check("feed.names_same", XFabaoFeed.GRADE_NAMES == Array(cfg.names), [XFabaoFeed.GRADE_NAMES, cfg.names])
	# 操作菜单开着时信息窗底部的两行：法宝等级、最低品级
	zx["level"] = 30
	var menu := _plain(XHelpCard.fabao_feed_lines(zx))
	check("feed.menu_lines", menu == ["法宝等级：30/99", "吞噬升级最低装备品级：" + str(cfg.names[XFabaoFeed.min_grade(30.0)])], menu)
	check("feed.menu_other_gear", XHelpCard.fabao_feed_lines(XGear.template("weapon", 1)).is_empty())
	zx["level"] = 99
	check("feed.menu_hidden_at_cap", XHelpCard.fabao_feed_lines(zx).is_empty())
	check("feed.hidden_at_cap99", _count(_plain(XHelpCard.content(zx)), "吞噬升级") == 0)
	s.set_variable(20, 1)
	zx["level"] = 12
	check("feed.hidden_at_floor_cap", _count(_plain(XHelpCard.content(zx)), "吞噬升级") == 0)
	zx["level"] = 11
	check("feed.shown_below_floor_cap", _count(_plain(XHelpCard.content(zx)), "吞噬升级") == 1)
	var was := XFabaoFeed.ENABLED
	XFabaoFeed.ENABLED = false
	check("feed.hidden_when_feed_off", _count(_plain(XHelpCard.content(zx)), "吞噬升级") == 0)
	XFabaoFeed.ENABLED = was


func _test_tianqi_and_rollback() -> void:
	_state(30, true)
	for pair in [["armor", 123], ["armor", XYunshang.RELIC], ["armor", 7904], ["armor", 7912], ["weapon", 73]]:
		var item := _gear(pair[0], pair[1], 50)
		XHelpCard.FABAO_BRIEF_T588 = true
		XHelpCard.FABAO_FEED_GRADE_T588 = true
		var on := var_to_str(_views(item))
		XHelpCard.FABAO_BRIEF_T588 = false
		XHelpCard.FABAO_FEED_GRADE_T588 = false
		var off := var_to_str(_views(item))
		XHelpCard.FABAO_FEED_GRADE_T588 = true
		check("tianqi.menu_lines.%d" % pair[1], XHelpCard.fabao_feed_lines(item).is_empty())
		check("tianqi.unchanged.%d" % pair[1], on == off and not on.contains("吞噬升级最低装备品级"), on.left(600))
	_state(1)
	XHelpCard.FABAO_BRIEF_T588 = false
	XHelpCard.FABAO_FEED_GRADE_T588 = false
	var old := _plain(XHelpCard.content(_gear("armor", 123, 5)))
	check("rollback.old_text", _count(old, "累计") == 2 and _count(old, "法宝等级：") == 0 and _count(old, "吞噬升级") == 0, old)
	var old_ys := _plain(XHelpCard.content(_gear("armor", XYunshang.RELIC, 5)))
	check("rollback.old_yunshang", old_ys.has("当前等级：5 / 12"), old_ys)
	XHelpCard.FABAO_BRIEF_T588 = true
	XHelpCard.FABAO_FEED_GRADE_T588 = true


## 用正常强化规则装补天石（随机数固定取高值）
func _reinforce(item: Dictionary, count: int) -> void:
	item["upgradeSlots"] = count
	item["originalUpgradeSlots"] = count
	var was: Callable = XGear.roll_fn
	XGear.roll_fn = func(): return 0.99
	for i in count:
		XGearUpgrade.apply_effects(item, XDB.rec("Items", 1828), true)
	XGear.roll_fn = was


## 卡面上以「属性名：」开头的格子数（两项一行时按 \col 分开数）
func _stat_cells(lines: Array, stat: String) -> int:
	var n := 0
	var col := RegEx.create_from_string("\\\\col\\[\\d+\\]")
	var rgb := RegEx.create_from_string("\\\\rgb\\[\\d+\\]")
	for line in lines:
		for cell in col.sub(rgb.sub(str(line), "", true), "\n", true).split("\n"):
			var t := str(cell).strip_edges()
			if t.begins_with(stat + "：") or t.begins_with(stat + ":"):
				n += 1
	return n


## 核查 P2-1：补天石的平加和法宝成长同一项只出现一次，数值＝平加＋成长
func _test_reinforced_once() -> void:
	_state(10)
	var zx := _gear("armor", 123, 30)
	_reinforce(zx, 3)
	var names: Array = XDB.system().terms.params
	var flat: Array = (zx.params as Array).duplicate()
	check("reinforced.has_flat", flat.any(func(v): return float(v) != 0.0), flat)
	for rows in _views(zx):
		var lines := _plain(rows)
		check("reinforced.no_bonus_row", _count(lines, "法宝加成") == 0 and _count(lines, "全属性+") == 0 and _count(lines, "法宝等级：30/39") == 1, lines)
		for i in 8:
			var sum := float(flat[i]) + roundf(XActor.magic_param(zx, i))
			var value := "%s：%d" % [str(names[i]), int(sum)]
			check("reinforced.once.%d" % i, _stat_cells(lines, str(names[i])) == 1 and _count(lines, value) == 1, [value, lines])
	check("reinforced.params_untouched", zx.params == flat, [zx.params, flat])
	# 全库法宝各给一项平加：不再另写加成行
	var bad := []
	for table in ["Armors", "Weapons"]:
		for rec in XDB.table(table):
			if not (rec is Dictionary) or not XMagicWeapon.is_magic(rec) or not XMagicWeapon.scale_active(rec):
				continue
			if XActor.magic_per_level(rec).all(func(v): return float(v) == 0.0):
				continue
			var item := _gear("weapon" if table == "Weapons" else "armor", int(rec.id), 20)
			item.params = (item.params as Array).duplicate()
			item.params[2] = float(item.params[2]) + 11.0
			var lines := _plain(XHelpCard.content(item))
			if _count(lines, "法宝加成：") != 0 or _stat_cells(lines, str(names[2])) > 1:
				bad.append([int(rec.id), lines])
	check("reinforced.all_once", bad.is_empty(), bad.slice(0, 2))


## 核查 P3-1、P3-2：进化行写明每级成长翻倍；被本层上限压住的写恢复提示
func _test_evolve_and_over_cap() -> void:
	var s := _state(1)
	for id in XThreeGrowth.SPECS:
		var spec: Dictionary = XThreeGrowth.SPECS[id]
		var item := _gear("armor", int(id), 5)
		var want := "进化：%s60级时进化为%s，每级成长翻倍，并%s" % [spec.who, spec.name, spec.hint]
		for rows in _views(item):
			var lines := _plain(rows)
			check("evolve.%d" % id, _count(lines, want) == 1 and _count(lines, "每级成长翻倍") == 1, lines)
		check("evolve.note_untouched.%d" % id, not str(item.note).contains("每级成长翻倍"))
	var hint := XHelpCard.FABAO_OVER_CAP_HINT
	for pair in [123, XYunshang.RELIC, 7904]:
		s.set_variable(20, 1)
		var item := _gear("armor", pair, 37)
		for rows in _views(item):
			var lines := _plain(rows)
			var at := lines.find("法宝等级：12/12")
			check("over_cap.shown.%d" % pair, at >= 0 and _count(lines, hint) == 1 and lines.find(hint) > at, lines)
		item["level"] = 12
		check("over_cap.at_cap.%d" % pair, _count(_plain(XHelpCard.content(item)), hint) == 0)
		item["level"] = 37
		s.set_variable(20, 10)
		check("over_cap.recovered.%d" % pair, _count(_plain(XHelpCard.content(item)), hint) == 0)
		s.set_variable(20, 30)
		item["level"] = 150
		check("over_cap.data_top.%d" % pair, _count(_plain(XHelpCard.content(item)), hint) == 0)


## 核查 P2-2：详情缓存只在非天启篇看等级、经验
func _test_detail_key() -> void:
	var host := Control.new()
	add_child(host)
	for tianqi in [true, false]:
		_state(10, tianqi)
		var view := XGearDetail.new(host, Rect2(640, 172, 640, 548), 255)
		var item := _gear("armor", XYunshang.RELIC, 5)
		item["exp"] = 2.0
		view.set_item(item)
		var before := view.key
		item["exp"] = 3.0
		view.set_item(item)
		check("detail_key.tianqi_%s" % tianqi, (view.key == before) == tianqi, [before.right(60), view.key.right(60)])
	host.queue_free()


## 核查 P2-3：操作菜单开着、强化记录多时，正文底边不压到底部两行提示
func _test_feed_layout() -> void:
	for count in [0, 3, 9, 10, 11, 12]:
		var s := _state_full()
		var item := _gear("armor", 123, 30)
		if count > 0:
			_reinforce(item, count)
		s.register_gear(item)
		s.gear.append(item)
		var page := XItemScene.new()
		add_child(page)
		await _frames(6)
		for i in XShop.CATEGORIES.size():
			if str(XShop.CATEGORIES[i][1]) == "armor":
				page._cat = i
		page._ok()
		await _frames(3)
		for i in page.entries().size():
			if page.entries()[i].rec.has("instanceId") and int(page.entries()[i].rec.get("base", 0)) == 123:
				page._index = i
				break
		page._refresh()
		page._ok()
		page.info_win.refresh()
		await _frames(6)
		var limit: float = page.info_win.canvas.size.y - page.info_reserve
		check("layout.menu_open.%d" % count, page._mode == "action" and page.info_reserve == XItemScene.LH * 2, [page._mode, page.info_reserve])
		check("layout.no_overlap.%d" % count, page.info_bottom > 0.0 and page.info_bottom <= limit, [page.info_bottom, limit])
		check("layout.columns.%d" % count, XItemScene.history_columns(item, 0.0, page.info_win.canvas.size.y) == 1
			and (count >= 9 or XItemScene.history_columns(item, page.info_reserve, page.info_win.canvas.size.y) == 1))
		page.queue_free()
		await _frames(2)


func _state_full() -> XState:
	var s := XState.new_game(2, 1, [8, 9, 10])
	s.set_variable(20, 10)
	XState.current = s
	return s


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
