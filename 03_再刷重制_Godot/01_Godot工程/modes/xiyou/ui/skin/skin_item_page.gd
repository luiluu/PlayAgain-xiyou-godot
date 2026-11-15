class_name XSkinItemPage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】物品页新布局（界面风格提案 v0.7「物品」；套 XSkinTemplatePage 的手动用法）。
## 只管「怎么摆、怎么画」：状态机、物品使用、升级、宝珠、批量服用、藏宝图、检索这些全部还是 XItemScene 原来的代码
## （同一套 _mode／_cat／_index…），这一页每次 _refresh 后 sync() 按状态重画，按键和点击翻译成同样的状态变化。
## - 左：分类小环（五类，名字带数量；环心写当前类的件数）。
## - 中：两列直列表，一屏 10 行×2＝20 项、行高 48；名字品质色、右侧「×数量」（装备写序号或穿戴者），新物品左上角「新」角标；
##   列表底下「第 a / b 页」。升级、镶嵌时列表换成材料／宝珠（不能用的变暗）。
## - 右：详情牌——图标、名字、「类别 · 持有 n」、说明；药物写「效果」「用法」；对队友用的写「给谁用」四人量条和预估回多少；
##   装备、技能书等照说明卡的行（XHelpCard）列在牌里。确定后在牌底弹操作菜单（使用、升级、镶嵌孔、置顶、出售锁定）；
##   选人在「给谁用」里选（全体对象整队选中）。
## - 批量服用、藏宝图数量窗、检索面板、遗忘页沿用旧窗口（新皮肤下也换了黑面板），宽屏时数量窗水平居中。
## 新皮肤关着时 XItemScene 不建这一页，旧页一行不变。

var scene: XItemScene
var _syncing := false
var _list_key := []
var _count_key := []
var _counts: Array = []
## 分类环的占位图标（物品、消耗品、武器、护甲、重要物品；美术出了再换）
const CAT_ICONS := {"item": 116, "consumable": 1725, "weapon": 160, "armor": 9, "keyItem": 384}
const OCCASION_TEXT := ["战斗中和菜单里都能用", "只能在战斗中用", "只能在菜单里用", "不能使用"]


func _init(s: XItemScene) -> void:
	scene = s
	name = "SkinItemPage"
	title = "物品"
	group_key = "items"
	columns = 2
	row_height = XUiSkin.ROW_H_ITEMS
	auto_nav = false
	hint_list = [["确定", "选择"], ["取消", "返回"], ["X", "检索排序"]]


func _ready() -> void:
	super()
	ring.changed.connect(_on_ring_changed)
	ring.activated.connect(_on_ring_clicked)
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	menu.index_changed.connect(func(i):
		if not _syncing and scene._mode == "action":
			scene._act = i
			scene._refresh())
	menu.activated.connect(func(_i):
		if scene._mode == "action":
			scene._click_ok())
	targets.index_changed.connect(func(i):
		if not _syncing and scene._mode == "actor":
			scene._actor = i
			XSound.system(0)
			scene._refresh())
	targets.activated.connect(func(_i):
		if scene._mode == "actor":
			scene._click_ok())
	card.button_pressed.connect(_on_card_button)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS


## 旧窗口里还在用的（数量窗、藏宝图）在宽屏时往右挪的距离；点击坐标同样减回去
func legacy_offset() -> Vector2:
	return Vector2(roundf((layout.view_size().x - 1280.0) / 2.0), 0) if layout != null else Vector2.ZERO


# ---- 按状态重画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	var sc := scene
	for w in [sc.cat_win, sc.status_win, sc.list_win, sc.info_win, sc.actor_win]:
		w.visible = false
	if sc.gear_detail != null:
		sc.gear_detail.set_visible(false)
	if sc.toolbar != null:
		sc.toolbar.visible = false
	sc.help_card.visible = false
	var off := legacy_offset()
	sc.bulk_win.position = XItemScene.BULK_RECT.position + off
	sc.treasure_win.position = XItemScene.TREASURE_RECT.position + off
	visible = sc.power_page == null and sc.search_panel == null
	var mode := sc._mode
	_sync_categories()
	_sync_list(mode)
	_sync_card(mode)
	match mode:
		"category":
			set_focus("ring")
		"list", "upgrade", "augment":
			set_focus("list")
		"action":
			_sync_menu()
		"actor":
			set_focus("targets")
	if mode != "action":
		close_menu()
	match mode:
		"category":
			set_hint_list([["确定", "选择"], ["取消", "返回"], ["X", "检索排序"]])
		"list":
			set_hint_list([["确定", "选择"], ["取消", "回分类"], ["X", "检索排序"]])
		_:
			set_hint_list([["确定", "选择"], ["取消", "返回"]])
	_syncing = false


func _cat_counts() -> Array:
	var s := XState.current
	var key := [s.get_instance_id(), s.items.size(), s.items.hash(), s.gear.size(), s.party.duplicate(), XAlienHide.active()]
	if key == _count_key:
		return _counts
	_count_key = key
	_counts = []
	for c in XShop.CATEGORIES:
		var sym: String = c[1]
		var n := 0
		if sym in ["item", "consumable", "keyItem"]:
			for k in s.items:
				var rec := XDB.rec("Items", int(k))
				if rec.is_empty() or s.item_count(int(k)) <= 0:
					continue
				var itype := int(rec.get("itypeId", 1))
				if (sym == "item" and itype == 1) or (sym == "keyItem" and itype == 2) or (sym == "consumable" and bool(rec.get("consumable", false))):
					n += 1
		else:
			n = XItemScene.bag_gear(sym).size()
			var seen := []
			for a in s.members():
				for e in a.raw_equip_list():
					if e.kind == sym and not seen.any(func(x): return is_same(x, e)):
						seen.append(e)
						n += 1
		_counts.append(n)
	return _counts


func _sync_categories() -> void:
	var counts := _cat_counts()
	var cats := []
	for i in XShop.CATEGORIES.size():
		var sym: String = XShop.CATEGORIES[i][1]
		cats.append({"key": sym, "name": XShop.CATEGORIES[i][0], "icon": CAT_ICONS.get(sym, 0), "count": counts[i]})
	if ring.items.size() != cats.size() or ring.items.map(func(x): return x.name) != cats.map(func(c): return "%s %d" % [c.name, c.count]):
		set_categories(cats, scene._cat)
	elif ring.index != scene._cat:
		ring.select(scene._cat)
	var sym: String = XShop.CATEGORIES[scene._cat][1]
	ring_center = [str(counts[scene._cat]), "件" if sym in ["weapon", "armor"] else "种"]
	ring.queue_redraw()


func _sync_list(mode: String) -> void:
	var rows := []
	var idx := 0
	var sc := scene
	match mode:
		"upgrade":
			list_title = "升级材料"
			for d in sc.materials():
				var ok := XGearUpgrade.reason(sc._item, d.rec, int(d.count)) == ""
				rows.append(_row(d.rec, XItemRow.right_text(d), not ok))
			idx = sc._up_index
		"augment":
			list_title = "镶嵌宝珠"
			for d in sc.augments():
				if d.rec.is_empty():
					var t := str(XDB.plugin("YEP_X_AttachAugments").get("Remove Augment", "\\i[1348]取下镶嵌物"))
					rows.append({"text": _strip(t), "icon": _first_icon(t)})
				else:
					rows.append(_row(d.rec, XItemRow.right_text(d), not bool(d.enabled)))
			idx = sc._aug_index
		_:
			list_title = XShop.CATEGORIES[sc._cat][0] + ("（已筛选）" if not sc.gear_filter.is_empty() and XShop.CATEGORIES[sc._cat][1] in ["weapon", "armor"] else "")
			for d in sc.entries():
				rows.append(_row(d.rec, XItemRow.right_text(d), false))
			idx = sc._index
	var key := [mode, sc._cat, rows.map(func(r): return [r.text, r.get("right", ""), r.get("disabled", false), r.has("badge")])]
	if key != _list_key:
		_list_key = key
		set_items(rows, clampi(idx, 0, maxi(rows.size() - 1, 0)))
	elif list.index != idx and idx < rows.size():
		list.select(idx)
	list_panel.queue_redraw()


func _row(rec: Dictionary, right: String, disabled: bool) -> Dictionary:
	var r := {"text": XQuality.list_name(rec), "icon": int(rec.get("iconIndex", 0)), "color": XGear.color(rec), "right": right, "disabled": disabled}
	if XItemRow.shows_new(XState.current, rec) and not is_same(rec, scene._pending_seen):
		var tex := XItemRow.new_icon()
		if tex != null:
			r.badge = tex
	return r


static func _strip(t: String) -> String:
	return RegEx.create_from_string("(?i)(?:\\\\|\u001b)(?:[a-z]+\\[[^\\]]*\\]|[{}.|!><^$])").sub(XMVText.convert_escapes(t), "", true).strip_edges()


static func _first_icon(t: String) -> int:
	var m := RegEx.create_from_string("(?i)\\\\i\\[(\\d+)\\]").search(t)
	return int(m.get_string(1)) if m != null else 0


func _sync_menu() -> void:
	var rows := []
	for a in scene._actions:
		var t := str(a.text)
		rows.append({"text": _strip(t), "icon": _first_icon(t) if str(a.symbol) == "augment" else 0, "disabled": not bool(a.enabled)})
	if focus != "menu" or menu.items.size() != rows.size() or menu.items.map(func(r): return r.text) != rows.map(func(r): return r.text):
		open_menu(rows, scene._act)
	elif menu.index != scene._act:
		menu.select(scene._act)


# ---- 详情牌 ----

func _sync_card(mode: String) -> void:
	var sc := scene
	var rec := {}
	match mode:
		"list":
			rec = sc._current()
		"action", "actor":
			rec = sc._item
		"upgrade":
			rec = sc._material()
		"augment":
			rec = sc._augment_row().get("rec", {})
	if rec.is_empty() and mode == "augment" and not sc._augment_row().is_empty():
		# 停在「取下镶嵌物」那一行
		var t := str(XDB.plugin("YEP_X_AttachAugments").get("Remove Augment", "\\i[1348]取下镶嵌物"))
		set_card({"icon": XUiSkin.icon(_first_icon(t)), "title": _strip(t), "subtitle": _strip(XItemScene.augment_name(sc._item, sc._aug_slot))})   # 孔里现在镶的（空孔写「- 空 -」）
		show_targets([])
		return
	if rec.is_empty():
		var n: int = _cat_counts()[sc._cat]
		set_card({"title": XShop.CATEGORIES[sc._cat][0], "subtitle": "%d %s" % [n, ring_center[1]] if n > 0 else "", "desc": "" if n > 0 else list.empty_text})
		show_targets([])
		return
	var d := card_data(rec)
	# 用完的提示（notifyBag）：光标没离开那一行就一直写在牌上
	if not sc._notice.is_empty() and mode == "list" and sc._index == int(sc._notice.get("index", -1)):
		d.sections = [{"title": "", "rows": [{"text": str(sc._notice.text), "color": XUiSkin.GOLD_LIGHT}]}] + d.sections
	var usable := mode in ["list", "action", "actor"] and not XItemMarks.is_gear(rec) and sc._usable(rec)
	if mode == "list" and usable:
		d.buttons = [{"text": "使用", "primary": true}]
	set_card(d)
	var friend := mode in ["list", "actor"] and usable   # 操作菜单开着时牌底让给菜单 and int(rec.get("scope", 0)) in [7, 8, 9, 10, 11]
	if friend:
		show_targets(target_rows(rec), mode == "actor", mode == "actor" and int(rec.get("scope", 0)) in [8, 10], sc._actor if mode == "actor" else -1)
		targets.title = "给谁学" if _learns(rec) else "给谁用"
	else:
		show_targets([])


## 物品／装备 → 详情牌数据（静态：别的页、测试直接用）
static func card_data(rec: Dictionary) -> Dictionary:
	var s := XState.current
	var gear := XItemMarks.is_gear(rec)
	var kind := XHelpCard.kind_of(rec)
	var sub := []
	if gear:
		var q := XQuality.label(rec, kind) if XQuality.has_quality(rec) else ""
		if q != "":
			sub.append(q)
		var tname := _type_name(rec)
		if tname != "":
			sub.append(tname)
	else:
		var it := int(rec.get("itypeId", 1))
		sub.append("重要物品" if it == 2 else ("消耗品" if bool(rec.get("consumable", false)) else "物品"))
		if s != null and int(rec.get("id", 0)) > 0:
			sub.append("持有 %d" % s.item_count(int(rec.id)))
	var d := {"icon": XUiSkin.icon(int(rec.get("iconIndex", 0))), "title": XQuality.list_name(rec), "title_color": XGear.color(rec),
		"subtitle": " · ".join(sub), "desc": str(rec.get("description", "")).strip_edges(), "sections": []}
	if gear:
		d.desc = ""
		d.sections = [{"title": "", "rows": XSkinTemplatePage.help_rows(XHelpCard.detail_rows(rec, 300.0))}]
		XTianqiSkinShow.dress_card(rec, d)   # 天启篇七印装备（3A，#82）：印、类别、真印、成色
		return d
	var fx := effect_lines(rec)
	var lines := []
	if not fx.is_empty():
		lines.append({"left": "效果", "right_text": "、".join(fx)})
	var occ := int(rec.get("occasion", 0))
	if occ >= 0 and occ < OCCASION_TEXT.size() and int(rec.get("itypeId", 1)) != 2:
		lines.append({"left": "用法", "right_text": OCCASION_TEXT[occ]})
	if not lines.is_empty():
		d.sections.append({"title": "", "rows": lines.map(func(l): return {"text": "%s　%s" % [l.left, l.right_text], "color": XUiSkin.TEXT})})
	# 技能书：所学技能的说明（说明卡的附卡内容）
	for ef in rec.get("effects", []):
		if int(ef.get("code", 0)) == 43:
			var sk := XDB.rec("Skills", int(ef.get("dataId", 0)))
			if not sk.is_empty():
				d.sections.append({"title": "「%s」" % str(sk.get("name", "")), "rows": XSkinTemplatePage.help_rows(XHelpCard.content(sk, "skill", false, 300.0))})
	XTianqiSkinShow.dress_card(rec, d)   # 天启篇号卷（3A，#82）：效果、代价、获得、限制
	return d


static func _type_name(rec: Dictionary) -> String:
	var sys := XDB.system()
	if str(rec.get("kind", "")) == "weapon" or rec.has("wtypeId"):
		var arr: Array = sys.get("weaponTypes", [])
		var w := int(rec.get("wtypeId", 0))
		return str(arr[w]) if w > 0 and w < arr.size() else ""
	var arr2: Array = sys.get("armorTypes", [])
	var t := int(rec.get("atypeId", 0))
	return str(arr2[t]) if t > 0 and t < arr2.size() else ""


static func _learns(rec: Dictionary) -> bool:
	return rec.get("effects", []).any(func(e): return int(e.get("code", 0)) == 43)


## 效果一句话：回复生命 500、回复魔法 30%、学会技能「割裂」、附加／解除「状态」（别的效果不写，详情看说明）
static func effect_lines(rec: Dictionary) -> Array:
	var out := []
	for e in rec.get("effects", []):
		var v1 := float(e.get("value1", 0))
		var v2 := float(e.get("value2", 0))
		match int(e.get("code", 0)):
			11:
				out.append(_recover("生命", v1, v2))
			12:
				out.append(_recover("魔法", v1, v2))
			13:
				out.append("回复 TP %d" % int(v1))
			21:
				var st := XDB.rec("States", int(e.get("dataId", 0)))
				if int(e.get("dataId", 0)) > 0 and str(st.get("name", "")) != "":
					out.append("附加「%s」" % st.name)
			22:
				var st2 := XDB.rec("States", int(e.get("dataId", 0)))
				if str(st2.get("name", "")) != "":
					out.append("解除「%s」" % st2.name)
			43:
				var sk := XDB.rec("Skills", int(e.get("dataId", 0)))
				if str(sk.get("name", "")) != "":
					out.append("学会技能「%s」" % sk.name)
	return out


static func _recover(what: String, v1: float, v2: float) -> String:
	var parts := []
	if v1 != 0.0:
		parts.append("%s%%" % _trim_num(absf(v1) * 100.0))
	if v2 != 0.0:
		parts.append(_trim_num(absf(v2)))
	return ("回复" if v1 >= 0.0 and v2 >= 0.0 else "减少") + what + " " + " + ".join(parts)


static func _trim_num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)


## 「给谁用」每人一行：量条看物品回的是什么（只回魔法的看魔法、只加 TP 的看 TP，其余看生命），右侧预估「+n」或「满」
func target_rows(rec: Dictionary) -> Array:
	var s := XState.current
	var members := s.members()
	var kind := "hp"
	var codes: Array = rec.get("effects", []).map(func(e): return int(e.get("code", 0)))
	if codes.has(12) and not codes.has(11):
		kind = "mp"
	elif codes.has(13) and not codes.has(11) and not codes.has(12):
		kind = "tp"
	var user := _user(s)
	var out := []
	for a: XActor in members:
		var cur := a.hp if kind == "hp" else (a.mp if kind == "mp" else a.tp)
		var mx := a.mhp if kind == "hp" else (a.mmp if kind == "mp" else a.max_tp())
		var gain := preview_gain(rec, a, user, kind)
		var right := ""
		var rc := XUiSkin.TEXT_3
		var recovers: bool = codes.has(11) or codes.has(12) or codes.has(13)
		if recovers:
			if cur >= mx:
				right = "满"
			elif gain > 0:
				right = "+%d" % gain
				rc = XUiSkin.UP
		var row := {"name": a.display_name(), "face": XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0))),
			"kind": kind, "cur": cur, "max": mx, "right": right, "right_color": rc, "dim": not scene._effective_for(rec, a)}
		XTianqiSkinShow.dress_target(rec, a, row)   # 天启篇号卷（3A，#82）：已学几卷
		out.append(row)
	return out


## Scene_Item.user：可行动角色里药物知识 pha 最大的（同 XItemScene._use）
static func _user(s: XState) -> XActor:
	var logic := XBattleLogic.new()
	logic.state = s
	var best: XActor = null
	for a in s.members():
		if logic.can_move(a) and (best == null or a.pha > best.pha):
			best = a
	return best


## 预估回多少（只算效果 11／12／13 的直接回复：(上限×比例＋定值)×受恢复效果 rec×使用者药物知识 pha，夹到缺的那么多；显示用，不改数值）
static func preview_gain(rec: Dictionary, t: XActor, user: XActor, kind: String) -> int:
	var total := 0.0
	for e in rec.get("effects", []):
		var code := int(e.get("code", 0))
		var v1 := float(e.get("value1", 0))
		var v2 := float(e.get("value2", 0))
		if kind == "hp" and code == 11:
			total += (t.mhp * v1 + v2) * t.rec * (user.pha if user != null else 1.0)
		elif kind == "mp" and code == 12:
			total += (t.mmp * v1 + v2) * t.rec * (user.pha if user != null else 1.0)
		elif kind == "tp" and code == 13:
			total += v1
	var miss := (t.mhp - t.hp) if kind == "hp" else ((t.mmp - t.mp) if kind == "mp" else (t.max_tp() - t.tp))
	return int(clampf(floorf(total), 0.0, maxf(miss, 0.0)))


# ---- 点击 → 同样的状态变化 ----

func _on_ring_changed(i: int) -> void:
	if _syncing or i == scene._cat:
		return
	if not scene._mode in ["category", "list"]:   # 操作、选人、升级、镶嵌时点环不跨态（同旧页：分类窗那时点了没反应）
		ring.select(scene._cat, false)
		return
	scene._commit_seen()
	scene._cat = i
	scene._mode = "category"
	scene._top = 0
	XSound.system(0)
	scene._refresh()


func _on_ring_clicked(_i: int) -> void:
	if _syncing:
		return
	if scene._mode == "category":
		scene._click_ok()
	elif scene._mode == "list":
		scene._commit_seen()
		scene._mode = "category"
		XSound.system(0)
		scene._refresh()


func _on_list_index(i: int) -> void:
	if _syncing:
		return
	var sc := scene
	match sc._mode:
		"category", "list":
			sc._mode = "list"
			sc._index = i
		"upgrade":
			sc._up_index = i
		"augment":
			sc._aug_index = i
		_:
			return
	XSound.system(0)
	sc._refresh()


func _on_list_click(i: int) -> void:
	var sc := scene
	if sc._mode == "category":
		sc._mode = "list"
		sc._index = i
		sc._refresh()
		return
	var cur: int = sc._index if sc._mode == "list" else (sc._up_index if sc._mode == "upgrade" else sc._aug_index)
	if sc._mode in ["list", "upgrade", "augment"] and i == cur:
		sc._click_ok()


func _on_card_button(_i: int) -> void:
	# 「使用」＝确定（开操作）＋第一项「使用」
	if scene._mode == "list" and scene._usable(scene._current()):
		scene._ok()
		if scene._mode == "action":
			scene._act = 0
			scene._ok()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		scene._cancel()
		accept_event()


# ---- 按键：方向键按新布局走（两列、环），其余（确定、取消、翻页、批量窗……）交回旧代码 ----

## 用掉了返回 true
func input(event: InputEvent) -> bool:
	var sc := scene
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X and sc._mode in ["category", "list"]:
		sc.open_search()
		return true
	var dx := 0
	var dy := 0
	if event.is_action_pressed("ui_up", true):
		dy = -1
	elif event.is_action_pressed("ui_down", true):
		dy = 1
	elif event.is_action_pressed("ui_left", true):
		dx = -1
	elif event.is_action_pressed("ui_right", true):
		dx = 1
	if dx == 0 and dy == 0:
		return false
	var wrap := not event.is_echo()
	match sc._mode:
		"category":
			sc._move(dx + dy, wrap)
		"list", "upgrade", "augment":
			var before := sc._cursor_state()
			var n: int = sc.entries().size() if sc._mode == "list" else (sc.materials().size() if sc._mode == "upgrade" else sc.augments().size())
			var cur: int = sc._index if sc._mode == "list" else (sc._up_index if sc._mode == "upgrade" else sc._aug_index)
			var j := grid_move(cur, n, columns, dx, dy, wrap)
			match sc._mode:
				"list":
					sc._index = j
				"upgrade":
					sc._up_index = j
				"augment":
					sc._aug_index = j
			sc._cursor_se(before)
		"action", "actor":
			if dy == 0:
				return true
			sc._move(dy, wrap)
		_:
			return false
	sc._refresh()
	return true


## 两列网格里走一步（同 XSkillScene 两列：左右一格、行尾行首可换行；上下一行、首按到头循环）
static func grid_move(i: int, n: int, cols: int, dx: int, dy: int, wrap: bool) -> int:
	if n <= 0:
		return 0
	if dx != 0:
		if dx > 0 and (i < n - 1 or wrap):
			return (i + 1) % n
		if dx < 0 and (i > 0 or wrap):
			return (i - 1 + n) % n
		return i
	var j := i + dy * cols
	if j < 0 or j >= n:
		if not wrap:
			return i
		var rows := ceili(n / float(cols))
		j = (i % cols) + (0 if dy > 0 else (rows - 1) * cols)
		if j >= n:
			j -= cols
	return clampi(j, 0, n - 1)
