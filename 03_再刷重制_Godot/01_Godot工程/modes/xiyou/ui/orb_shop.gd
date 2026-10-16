class_name XOrbShop
extends Control
## 宝珠坊（主菜单「宝珠坊」→ CodexOrbs.open → Scene_CodexBindMenu；正式 installNativeOrbRuntime 的 home／identifyMenu／
## identifyDetail／buyMenu／dismantleMenu／dismantleDetail／guide／setGuide／returnsMenu／resultPage），每页一个 XChoiceWindow。
## 行文逐字照搬（参照 orb_shop_probe.cjs 的 pages，测试 tests/xiyou_orb_shop_ui）；说明按 48 个半角宽换行（全角算 2）。
## 规则在 XOrbs。打开时先领神秘珠暂存箱与暂存宝珠（领到暂存宝珠时提示）。

signal closed

var choice: XChoiceWindow
## 测试用：每次打开的页 {info, rows}
var log: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	choice = XChoiceWindow.new()
	add_child(choice)
	home()


func s() -> XState:
	return XState.current


func cfg() -> Dictionary:
	return XOrbs.config()


func notify(text: String) -> void:
	XToast.show_text(text, true)


func count(id: int) -> int:
	return s().item_count(id)


func name_of(id: int) -> String:
	return XOrbs.item_name(id)


static func pct(v: float) -> String:
	return str(roundi(v * 100.0)) + "%"


static func tier_text(to: int) -> String:
	return "顶" if to == 99 else str(to)


## choose：说明按 48 个半角宽换行后交给选择窗
func choose(rows: Array, ok: Callable, cancel: Callable, lines := []) -> void:
	var wrapped := wrap_info(lines)
	log.append({"info": wrapped, "rows": rows.map(func(r): return {"label": str(r.label), "enabled": r.get("enabled", true) != false})})
	choice.open(rows, ok, cancel, wrapped)


static func wrap_info(lines: Array) -> Array:
	var out := []
	for t in lines:
		var line := ""
		var width := 0
		for ch in str(t):
			var units := 2 if ch.unicode_at(0) > 255 else 1
			if width + units > 48:
				out.append(line)
				line = ""
				width = 0
			line += ch
			width += units
		if line != "":
			out.append(line)
	return out


func close() -> void:
	closed.emit()


## amounts：1／5／10／最多，去重、不超过最多
static func amounts(mx: int) -> Array:
	var out := []
	for n in [1, 5, 10, mx]:
		if n > 0 and n <= mx and not out.any(func(r): return r.quantity == n):
			out.append({"quantity": n, "label": str(n)})
	return out


func desc(id: int) -> Array:
	var sp := XOrbs.spec(id)
	if not sp.is_empty():
		var f: Dictionary = cfg().families[int(sp.family)]
		var sets: Array = f.sets.map(func(i): return str(cfg().sets[int(i)].name))
		var out := ["定位：" + str(f.role) + "（镶" + str(f.get("slot", "武器宝珠")) + "孔）"]
		out.append_array(XDB.table("CodexOrbs").items[str(id)].effects)
		if not sets.is_empty():
			out.append("套装组件：" + "、".join(sets))
		out.append("同一件装备同类新宝珠最多1颗")
		return out
	var out := []
	for t in str(XDB.rec("Items", id).get("note", "")).split("\n"):
		var m := RegEx.create_from_string("<pos=APs text=(.*?) size=").search(t)
		if m:
			out.append(RegEx.create_from_string("\\\\c\\[\\d+\\]").sub(m.get_string(1), "", true))
	return out.slice(0, 5)


func inventory() -> Array:
	var ids: Array = s().items.keys().map(func(k): return int(k)).filter(func(id): return count(id) > 0 and XOrbs.refund(id) > 0)
	ids.sort_custom(func(a, b):
		var sa := int(not XOrbs.spec(a).is_empty())
		var sb := int(not XOrbs.spec(b).is_empty())
		return sa > sb or (sa == sb and a < b))
	return ids


func result_page(result: Dictionary, back: Callable) -> void:
	if not result.ok:
		choose([{"label": "返回"}], func(_r): back.call(), func(): back.call(), ["操作未完成", result.reason])
		return
	var title := "鉴定完成：%d枚神秘珠" % int(result.quantity) if result.kind == "identify" else ("兑换完成" if result.kind == "buy" else "分解完成")
	var rows: Array = result.outputs.map(func(x): return {"id": int(x.id), "label": name_of(int(x.id)) + " ×" + str(int(x.quantity))})
	rows.append({"label": "返回", "back": true})
	choose(rows, func(row):
		if row.get("back", false):
			back.call()
			return
		var lines := [name_of(int(row.id))]
		lines.append_array(desc(int(row.id)) if not XOrbs.spec(int(row.id)).is_empty() else ["可在原有核心宝珠商店兑换使用"])
		choose([{"label": "返回结果"}], func(_r): result_page(result, back), func(): result_page(result, back), lines),
		back, [title])


func identify_menu() -> void:
	var rows := []
	for b in cfg().bands:
		if count(int(b.itemId)) > 0:
			rows.append({"id": int(b.itemId), "label": name_of(int(b.itemId)) + " ×" + str(count(int(b.itemId)))})
	if rows.is_empty():
		rows.append({"label": "尚无未鉴定神秘珠", "empty": true})
	choose(rows, func(row):
		if row.get("empty", false):
			home()
		else:
			identify_detail(int(row.id)),
		home, ["鉴定神秘珠", "副本Boss每场胜利" + pct(float(cfg().dropRate)) + "掉落；一半鉴定为原作宝珠，一半为新宝珠（楼层决定阶位）"])


func identify_detail(id: int) -> void:
	var q := XOrbs.max_identify(s(), id)
	var rows := amounts(q).map(func(r): r.label = "鉴定 %d 枚" % int(r.quantity); return r)
	if rows.is_empty():
		rows.append({"label": "背包空间不足，请先分解宝珠", "enabled": false})
	rows.append({"label": "返回", "back": true})
	var b := XOrbs.seal(id)
	var info := [name_of(id), "持有 %d 枚" % count(id),
		"原作宝珠 %s%%（%s档 %d种等概率）" % [_num(XOrbs.legacy_share()), XOrbs.LEGACY_TIER_NAME.get(str(b.get("legacy", "")), ""), XOrbs.legacy_pool(b).size()],
		"新宝珠 %s%%（16类等概率），阶位：" % _num(100.0 - XOrbs.legacy_share())]
	info.append_array(XOrbs.probabilities(id))
	choose(rows, func(row):
		if row.get("back", false):
			identify_menu()
			return
		var check := XOrbs.quote_identify(s(), id, int(row.quantity))
		if not check.ok:
			result_page(check, identify_menu)
			return
		var lines := [name_of(id), "消耗神秘珠，随机获得等量宝珠；不另收鉴定费用"]
		lines.append_array(XOrbs.probabilities(id))
		choose([{"label": "确认鉴定 %d 枚" % int(row.quantity), "confirm": true}, {"label": "取消"}], func(r):
			if r.get("confirm", false):
				result_page(XOrbs.identify(s(), id, int(row.quantity)), identify_menu)
			else:
				identify_detail(id),
			func(): identify_detail(id), lines),
		identify_menu, info)


## JS 数字转字符串（整数不带小数点）
static func _num(v: float) -> String:
	return str(int(v)) if floorf(v) == v else str(v)


func buy_menu() -> void:
	var b := XOrbs.progress_band(s())
	var p := XOrbs.pearl_price(b) if not b.is_empty() else 0
	var have := count(int(cfg().fragment))
	var mx := mini(floori(float(have) / p), XOrbs.free_space(s(), int(b.itemId)) if not b.is_empty() else 0) if p > 0 else 0
	var rows := amounts(mx).map(func(r): r.label = "兑换 %d 枚（%d 残片）" % [int(r.quantity), int(r.quantity) * p]; return r)
	if rows.is_empty():
		rows.append({"label": "残片不足（每枚 %d）" % p, "empty": true})
	rows.append({"label": "返回", "back": true})
	var where := ("%d～%s层" % [int(b.from), tier_text(int(b.to))]) if not b.is_empty() else "—"
	choose(rows, func(row):
		if row.get("back", false) or row.get("empty", false):
			home()
			return
		choose([{"label": "确认兑换 %d 枚" % int(row.quantity), "confirm": true}, {"label": "取消"}], func(r):
			if r.get("confirm", false):
				result_page(XOrbs.buy_pearl(s(), int(row.quantity)), buy_menu)
			else:
				buy_menu(),
			buy_menu, [name_of(int(b.itemId)), "消耗 %d 宝珠残片" % (int(row.quantity) * p)]),
		home, ["残片换神秘珠", "按当前进度（" + where + "）：" + (name_of(int(b.itemId)) if not b.is_empty() else "—") + " 每枚 %d 残片" % p,
			"持有 %d 残片；残片来自副本Boss奖励与分解宝珠" % have])


func dismantle_menu() -> void:
	var rows: Array = inventory().map(func(id): return {"id": id, "label": name_of(id) + " ×" + str(count(id))})
	if rows.is_empty():
		rows.append({"label": "尚无可分解的背包宝珠", "empty": true})
	choose(rows, func(row):
		if row.get("empty", false):
			home()
		else:
			dismantle_detail(int(row.id)),
		home, ["分解宝珠", "只处理背包宝珠；镶嵌中的宝珠请先卸下"])


func dismantle_detail(id: int) -> void:
	var n := XOrbs.refund(id)
	var mx := mini(count(id), floori(float(XOrbs.free_space(s(), int(cfg().fragment))) / n))
	var rows := amounts(mx).map(func(r): r.label = "分解 %d 颗 → %d 残片" % [int(r.quantity), int(r.quantity) * n]; return r)
	rows.append({"label": "返回", "back": true})
	var info := [name_of(id)]
	info.append_array(desc(id))
	info.append("每颗分解得 %d 宝珠残片" % n)
	choose(rows, func(row):
		if row.get("back", false):
			dismantle_menu()
			return
		choose([{"label": "确认分解 %d 颗" % int(row.quantity), "confirm": true}, {"label": "取消"}], func(r):
			if r.get("confirm", false):
				result_page(XOrbs.dismantle(s(), id, int(row.quantity)), dismantle_menu)
			else:
				dismantle_detail(id),
			func(): dismantle_detail(id), [name_of(id), "分解后宝珠消失，获得 %d 宝珠残片" % (n * int(row.quantity))]),
		dismantle_menu, info)


func guide() -> void:
	var rows: Array = cfg().bands.map(func(b): return {"id": int(b.itemId), "label": "%d～%s层：%s" % [int(b.from), tier_text(int(b.to)), name_of(int(b.itemId))]})
	choose(rows, func(row):
		var b := XOrbs.seal(int(row.id))
		var lines := [name_of(int(row.id)), "新宝珠阶位："]
		lines.append_array(XOrbs.probabilities(int(row.id)))
		lines.append_array(["新宝珠16类等概率；另有%s%%鉴定为原作宝珠（%s档 %d种）" % [_num(XOrbs.legacy_share()), XOrbs.LEGACY_TIER_NAME.get(str(b.get("legacy", "")), ""), XOrbs.legacy_pool(b).size()],
			"原作宝珠：1～12层弱档，13～18层中档，19层起强档"])
		choose([{"label": "返回分布表"}], func(_r): guide(), guide, lines),
		home, ["神秘珠掉落与鉴定", "副本Boss胜利后每场独立" + pct(float(cfg().dropRate)) + "，最多1枚", "不受掉率、熟练度或洪荒诅咒倍率影响", "高层封印保留到鉴定时；未鉴定不能镶嵌"])


func set_guide() -> void:
	var fams: Array = cfg().families
	var rows := []
	for i in range(cfg().sets.size()):
		var st: Dictionary = cfg().sets[i]
		rows.append({"index": i, "label": str(st.name) + "：" + "／".join(st.families.map(func(f): return str(fams[int(f)].name)))})
	choose(rows, func(row):
		var st: Dictionary = cfg().sets[int(row.index)]
		var g: Dictionary = cfg().general
		choose([{"label": "查看当前队伍此套装", "key": "party"}, {"label": "返回套装列表", "key": "back"}], func(r):
			if r.key == "back":
				set_guide()
				return
			var lines := [str(st.name) + " · 当前配装"]
			var members := s().members()
			for m in members.slice(0, 10):
				var hit := {}
				for x in XOrbs.active_sets(m.equips):
					if int(x.index) == int(row.index):
						hit = x
						break
				lines.append(m.display_name() + "：" + ("%d件 %s，全部伤害×%.2f" % [int(hit.pieces), cfg().tiers[int(hit.rank) - 1], 1.0 + float(hit.general) / 100.0] if not hit.is_empty() else "未生效"))
			choose([{"label": "返回套装列表"}], func(_r): set_guide(), set_guide, lines),
			set_guide, ["宝珠套装：" + str(st.name), "组件：" + "／".join(st.families.map(func(f): return str(fams[int(f)].name))),
				"全身装备（武器＋防具）集齐任意2种／全部3种组件触发，按最低阶位", "数值依次对应凝砂／蕴灵／通玄／化境／归真",
				"2件：全部伤害 ×(1＋" + "／".join(g.two.map(func(v): return _num(float(v)))) + "%)",
				"3件：全部伤害 ×(1＋" + "／".join(g.three.map(func(v): return _num(float(v)))) + "%)", "多个套装只取最高一套", "普通加成照常生效"]),
		home, ["套装图谱", "全部伤害加成，镶嵌后实时生效"])


func returns_menu() -> void:
	var gained := XOrbs.claim_returns(s())
	var box: Dictionary = s().orb_state.returns
	var rows := [{"label": "再次领取", "key": "claim"}]
	for k in box:
		var id := XOrbs._return_id(str(k))
		rows.append({"label": (name_of(id) if id > 0 else "待领取宝珠") + " ×" + str(int(box[k])), "key": "gem", "token": str(k)})
	rows.append({"label": "返回宝珠坊", "key": "back"})
	var status := "已领取 %d 颗" % gained if gained else ("背包仍满时，宝珠继续保留" if XOrbs.pending_returns(s()) else "已全部领取")
	choose(rows, func(row):
		if row.key == "back":
			home()
			return
		if row.key == "claim":
			returns_menu()
			return
		var id := XOrbs._return_id(str(row.token))
		var room := XOrbs.free_space(s(), id) if id > 0 else 0
		choose([{"label": "领取这一种", "claim": true}, {"label": "返回暂存列表"}], func(r):
			if r.get("claim", false):
				var n := XOrbs.claim_return(s(), str(row.token))
				notify("已领取 %d 颗" % n if n else "背包仍满，宝珠继续保留")
			returns_menu(),
			returns_menu, [name_of(id) if id > 0 else "待领取宝珠", "暂存 %d 颗；可入背包 %d 颗" % [int(box.get(row.token, 0)), room]]),
		home, ["暂存宝珠", status, "腾出对应宝珠的背包空间后，再次领取；暂存记录随存档保存"])


func home() -> void:
	XOrbs.claim_drops(s())
	var gained := XOrbs.claim_returns(s())
	var pending := XOrbs.pending_returns(s())
	if gained:
		notify("暂存宝珠已领取 %d 颗" % gained)
	var rows := [{"label": "鉴定神秘珠", "key": "identify"}, {"label": "残片换神秘珠", "key": "buy"}, {"label": "分解宝珠", "key": "dismantle"}]
	if pending:
		rows.append({"label": "领取暂存宝珠（%d颗）" % pending, "key": "returns"})
	rows.append_array([{"label": "楼层与品质分布", "key": "guide"}, {"label": "套装图谱与当前配装", "key": "sets"}, {"label": "返回", "key": "back"}])
	var sealed := 0
	for b in cfg().bands:
		sealed += count(int(b.itemId))
	choose(rows, _home_pick, close, ["宝珠坊", "未鉴定 %d 枚　宝珠残片 %d" % [sealed, count(int(cfg().fragment))],
			"武器、副手、神武为武器孔（0～3），其余防具孔（0～2）", "玄甲、长生、藏气、流风镶防具孔；全身同类只算最高3颗"])


func _home_pick(row: Dictionary) -> void:
	match str(row.key):
		"identify": identify_menu()
		"buy": buy_menu()
		"dismantle": dismantle_menu()
		"guide": guide()
		"sets": set_guide()
		"returns": returns_menu()
		_: close()
