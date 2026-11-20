class_name XRaceMenu
extends Control
## 种族祝福（主菜单「种族祝福」、种族向导与进阶石公共事件 → CodexRaces.openMenu → Scene_CodexBindMenu；正式 installNativeRaceRuntime 的
## defaults／members／actorPage／racePage 与两种确认页），每页一个 XChoiceWindow。行文逐字照搬（参照 race_menu_probe.cjs 的 pages，
## 测试 tests/xiyou_race_menu）；说明按 48 个半角宽换行。规则在 XRace。打开时先补全队数据、领种族补给暂存箱。
## rank：进阶石公共事件 openMenu({rank:N}) 的目标阶，只在从队员页进角色页那一次用（原版之后回到角色页都不带它）。
## T299 卡 K：天启篇新界面（XUiSkin.on() 且 XSkinMenuTreePage.ENABLED）时换成版型四层级菜单页（XSkinMenuTreePage）：不画环，左块画选中队员的
## 像素小人（3 倍）；队员页列表行尾写种族和阶位、能进阶的加「可进阶」金色小标，右牌写当前加成和下一阶；两种确认页（开局默认、换族）和进阶确认
## 走统一确认弹窗。每页的 {info, rows}（log）和回调一行不变；关着时 tree 为 null，旧页一行不变。

signal closed

var choice: XChoiceWindow
## T299 新界面（版型四）；关着时为 null
var tree: XSkinMenuTreePage
## 新界面左块画谁（角色页、种族页、确认页＝那名角色；队员页跟光标）
var _actor: XActor
var rank := 0
## 测试用：每次打开的页 {info, rows}
var log: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	choice = XChoiceWindow.new()
	add_child(choice)
	if XUiSkin.on() and XSkinMenuTreePage.ENABLED:
		tree = XSkinMenuTreePage.new("种族祝福")
		# 从主菜单「角色」进才画页签条；进阶石（rank>0）、地图上的种族向导不是从主菜单进，不画（T254 3.0；小A核 P2-4）
		tree.group_key = "actor" if get_parent() is XMenu and rank <= 0 else ""
		tree.left_draw = _draw_left
		add_child(tree)
	XRace.migrate(s())
	XRace.claim_inbox(s())
	if XRace.default_race(s()) < 0:
		defaults()
	else:
		members()


func s() -> XState:
	return XState.current


func notify(text: String) -> void:
	XToast.show_text(text, true, "race")


## o：新界面的摆法（XSkinMenuTreePage.open：crumb、confirm、row_view、card_for）
func choose(rows: Array, ok: Callable, cancel: Callable, lines := [], o := {}) -> void:
	var wrapped := XOrbShop.wrap_info(lines)
	log.append({"info": wrapped, "rows": rows.map(func(r): return {"label": str(r.label), "enabled": r.get("enabled", true) != false})})
	if tree != null:
		tree.open(rows, ok, cancel, lines, o)
		return
	choice.open(rows, ok, cancel, wrapped)


# ---- 新界面（T299）----

static func crumb(parts := []) -> Dictionary:
	return {"crumb": ["种族祝福"] + parts}


## 能不能进下一阶：选了种族、没到顶、有下一阶的进阶石（同 XRace.upgrade 的判定）
func can_rank_up(a: XActor) -> bool:
	var d := XRace.data(s(), a)
	if int(d.race) < 0 or int(d.rank) >= 7:
		return false
	return s().item_count(int(XRace.config().stones[int(d.rank) - 1])) >= 1


## 队员页一行：名字｜行尾种族和阶位；能进阶的加「可进阶」金色小标（字和旧页一样，只是「 · 」后半挪到行尾）
func member_row(row: Dictionary) -> Dictionary:
	var a: XActor = row.actor
	var r := {"text": a.display_name(), "right": XRace.label(s(), a), "right_color": XUiSkin.TEXT_2}
	if can_rank_up(a):
		r.tags = [{"text": "可进阶", "color": XUiSkin.GOLD}]
	return r


## 队员页右牌：当前加成＋下一阶
func member_card(row: Dictionary) -> Dictionary:
	var a: XActor = row.actor
	var d := XRace.data(s(), a)
	var secs := []
	if int(d.race) < 0:
		secs.append({"title": "当前加成", "rows": [{"text": "旧档多族请先选择一种；最高阶位已保留", "color": XUiSkin.TEXT_2}]})
	else:
		secs.append({"title": "当前加成", "rows": XRace.effects(int(d.race), int(d.rank)).map(func(t): return {"text": str(t), "color": XUiSkin.TEXT})})
		if int(d.rank) < 7:
			var stone := str(XDB.rec("Items", int(XRace.config().stones[int(d.rank) - 1])).get("name", ""))
			var nxt := XRace.effects(int(d.race), int(d.rank) + 1).map(func(t): return {"text": str(t), "color": XUiSkin.TEXT_2})
			nxt.append({"text": "消耗" + stone + "×1", "color": XUiSkin.GOLD_LIGHT if can_rank_up(a) else XUiSkin.DOWN})
			secs.append({"title": "下一阶（第%d阶）" % (int(d.rank) + 1), "rows": nxt})
	return {"title": a.display_name(), "subtitle": XRace.label(s(), a), "sections": secs, "buttons": []}


## 选种族那一页的右牌：这一族在这一阶的加成（开局默认看第 1 阶）
func race_card(r: int, rank: int, sub := "") -> Dictionary:
	return {"title": XRace.race_name(r) + "族", "subtitle": sub, "sections": [{"title": "第%d阶加成" % rank,
		"rows": XRace.effects(r, rank).map(func(t): return {"text": str(t), "color": XUiSkin.TEXT})}], "buttons": []}


## 左块：选中队员的像素小人（3 倍，摆法同技能页环心：人按不透明范围居中、脚下黑椭圆影＋淡金受光）＋名字
func _draw_left(c: Control, row: Dictionary) -> void:
	var a: XActor = row.get("actor", _actor) if row.get("actor", null) is XActor else _actor
	if a == null:
		return
	var lb := c.size
	var center := Vector2(lb.x / 2.0, lb.y / 2.0 - 40.0)
	var fr := XSkinMainMenu.sv_frame(a, 1)
	if fr != null:
		var used: Rect2 = XSkinMainMenu._sv_info(a, XAppearance.look_key(a)).used
		var k := 3
		var origin := (center - (used.position + used.size / 2.0) * k).round()
		var feet := Vector2(center.x, origin.y + used.end.y * k - 6.0)
		var shadow := PackedVector2Array()
		for i in 24:
			shadow.append(feet + Vector2(cos(TAU * i / 24.0) * 48.0, sin(TAU * i / 24.0) * 12.0))
		c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
		c.draw_arc(feet, 52.0, 0, TAU, 32, Color(XUiSkin.GOLD, 0.25), 1.5, true)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.draw_texture_rect(fr, Rect2(origin, fr.get_size() * k), false)
	var f := XUiSkin.font("title")
	var fs := XUiSkin.fs(XUiSkin.FS_CARD)
	var fit := XSkinList.fit_text(f, a.display_name(), lb.x - 16.0, fs, 17)
	var tw := f.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
	XUiSkin.ds(c, f, Vector2((lb.x - tw) / 2.0, center.y + 120.0), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.GOLD)
	var body := XUiSkin.font("body")
	var lab := XRace.label(s(), a)
	var lw := body.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.fs(XUiSkin.FS_AUX)).x
	XUiSkin.ds(c, body, Vector2((lb.x - lw) / 2.0, center.y + 150.0), lab, HORIZONTAL_ALIGNMENT_LEFT, lb.x - 16.0, XUiSkin.fs(XUiSkin.FS_AUX), XUiSkin.TEXT_2)


func close() -> void:
	closed.emit()


func members() -> void:
	var rows := s().members().map(func(a): return {"label": a.display_name() + " · " + XRace.label(s(), a), "actor": a})
	_actor = null
	choose(rows, func(row): actor_page(row.actor, rank), close, ["调整角色祝福；换族保留阶位", "进阶材料七族通用；每名角色首次调整免费"],
		crumb().merged({"row_view": member_row, "card_for": member_card}))


func defaults() -> void:
	var rows := []
	for r in 7:
		rows.append({"label": XRace.race_name(r) + "族", "race": r})
	_actor = null
	choose(rows, _default_confirm, close, ["选择开局默认祝福"], crumb(["开局默认"]).merged({"card_for": func(row): return race_card(int(row.race), 1)}))


func _default_confirm(row: Dictionary) -> void:
	choose([{"label": "确定开局默认"}, {"label": "返回"}], _default_answer.bind(int(row.race)), close,
		XRace.effects(int(row.race), 1) + ["新招募角色默认继承该族，可逐人调整"], crumb(["开局默认"]).merged({"confirm": {"title": "将开局默认设为%s族？" % XRace.race_name(int(row.race))}}))


func _default_answer(answer: Dictionary, r: int) -> void:
	if answer.label == "返回":
		defaults()
		return
	XRace.set_default(s(), r, true)
	members()


func race_page(a: XActor) -> void:
	var d := XRace.data(s(), a)
	var rows := []
	for r in 7:
		rows.append({"label": XRace.race_name(r) + "族" + ("（当前）" if int(d.race) == r else ""), "race": r})
	_actor = a
	choose(rows, _race_confirm.bind(a), members, [a.display_name() + " 当前：" + XRace.label(s(), a)],
		crumb([a.display_name(), "调整种族"]).merged({"card_for": func(row): return race_card(int(row.race), maxi(1, int(d.rank)), "保留当前阶位")}))


func _race_confirm(row: Dictionary, a: XActor) -> void:
	var d := XRace.data(s(), a)
	var lines := XRace.effects(int(row.race), int(d.rank)) + ["保留当前阶位；" + ("本次调整免费" if bool(d.free) else "消耗忘情水×1")]
	choose([{"label": "确定选择"}, {"label": "返回"}], _race_answer.bind(a, int(row.race)), race_page.bind(a), lines,
		crumb([a.display_name(), "调整种族"]).merged({"confirm": {"title": "改为%s族？" % XRace.race_name(int(row.race))}}))


func _race_answer(answer: Dictionary, a: XActor, r: int) -> void:
	if answer.label == "返回":
		race_page(a)
		return
	var result := XRace.change(s(), a, r)
	notify(a.display_name() + "：" + XRace.label(s(), a) if result.ok else str(result.reason))
	actor_page(a)


func actor_page(a: XActor, requested := 0) -> void:
	var d := XRace.data(s(), a)
	var rows := [{"label": "调整种族", "key": "race"}]
	if int(d.race) >= 0 and int(d.rank) < 7:
		rows.append({"label": "进阶至第%d阶" % (requested if requested > 0 else int(d.rank) + 1), "key": "rank"})
	if int(d.race) == 3:
		rows.append({"label": "血契：" + ("开启" if bool(d.blood) else "关闭"), "key": "blood"})
	var info := [a.display_name() + "：" + XRace.label(s(), a)]
	info += XRace.effects(int(d.race), int(d.rank)) if int(d.race) >= 0 else ["旧档多族请先选择一种；最高阶位已保留"]
	_actor = a
	choose(rows, _actor_row.bind(a, requested), members, info, crumb([a.display_name()]))


func _actor_row(row: Dictionary, a: XActor, requested: int) -> void:
	var d := XRace.data(s(), a)
	match str(row.key):
		"race":
			race_page(a)
		"blood":
			d.blood = not bool(d.blood)
			actor_page(a)
		_:
			var to := requested if requested > 0 else int(d.rank) + 1
			var stone := int(XRace.config().stones[to - 2])
			choose([{"label": "确定进阶"}, {"label": "返回"}], _rank_answer.bind(a, to), actor_page.bind(a, 0),
				["消耗" + str(XDB.rec("Items", stone).get("name", "")) + "×1"] + XRace.effects(int(d.race), to),
				crumb([a.display_name()]).merged({"confirm": {"title": "进阶至第%d阶？" % to}}))


func _rank_answer(answer: Dictionary, a: XActor, to: int) -> void:
	if answer.label == "确定进阶":
		var result := XRace.upgrade(s(), a, to)
		notify(a.display_name() + "：" + XRace.label(s(), a) if result.ok else str(result.reason))
	actor_page(a)
