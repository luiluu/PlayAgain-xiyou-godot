extends Node
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
	var text := "\n".join(PackedStringArray(lines))
	for bad in ["累计", "满级", "等级上限", "当前等级", "（保留", "本层上限", "进化后加成翻倍"]:
		if text.contains(bad):
			return false
	return true


func _run() -> void:
	var was_state := XState.current
	var was := [XHelpCard.FABAO_BRIEF_T588, XHelpCard.FABAO_FEED_GRADE_T588]
	XHelpCard.FABAO_BRIEF_T588 = true
	XHelpCard.FABAO_FEED_GRADE_T588 = true
	_test_lines()
	_test_all_fabao()
	_test_feed_grade()
	_test_tianqi_and_rollback()
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
