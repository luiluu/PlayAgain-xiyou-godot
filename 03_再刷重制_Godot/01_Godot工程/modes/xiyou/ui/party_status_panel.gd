class_name XPartyStatusPanel
extends XWebPanel
## 战斗中的状态详情（正式西游 installEquipmentStatusRuntime renderStatus／renderStatusCards，网页覆盖层＋installGamePanelTheme 外观）。
## 入口：右侧角色状态格（Window_BattleSideStates 上叠的网页按钮，悬停提示「名字：状态名；点击查看全部状态」）。
## 正式版里 StateHelp 的队伍指令「状态」也会开它，但 OTB 不显示队伍指令窗、呼出键参数为空，所以只剩点状态格这一个入口。
## - 标题「<名字> · 状态详情」，说明「查看时暂停战斗，关闭后继续。」；
## - 详情框（可滚动）：胶囊「HP 当前 / 最大」「MP 当前 / 最大」「TP 值」；「人物属性：」与各元素承伤（同战力面板 CodexElements）；
##   页签「异常 N」「增益 N」「常驻 N」「全部 N」（打开时在「全部」）；搜索框「搜索状态名称 / 效果」（按 alias 后的名字＋说明包含）；
##   每个状态一张卡：名字（粗体）、「类别 · 时长（· N层）」、说明；异常卡左边线红（--gp-bad）。没有时写「没有X状态符合当前条件。」
## - 底部栏左「显示实际效果、剩余回合和层数。」、右「返回战斗」；Esc／关闭／返回战斗都关掉。
## 行内容 rows()＝stateRows：states() 去重、只留 visibleState（XSideStatus.visible_state），接强弱化，按「异常→增益→常驻」再拼音序排。
## 重制只在等指令时能点开（演出中战斗靠协程推进，没法像 BattleManager.update 那样整体停住），见 XBattleScene._open_status。

const DETAIL := Rect2(40, 116.59, 1200, 517.22)
const WIDTH := 1164.0
const TABS := ["异常", "增益", "常驻", "全部"]
const XPARAMS := ["命中率", "闪避率", "暴击率", "暴击闪避", "魔法闪避", "魔法反射", "反击率", "生命再生", "魔法再生", "怒气再生"]
const SPARAM23 := ["受击概率", "防御效果", "治疗效果", "药品效果", "魔法消耗", "怒气获得", "物理承伤", "魔法承伤", "地形承伤", "经验获得"]
const FLAG62 := ["自动战斗", "防御姿态：按当前防御效果减轻伤害", "代替濒死队友承受攻击", "保留怒气"]
const RESTRICT := ["", "只能攻击敌方", "不分敌我攻击", "会攻击队友", "无法行动"]
const BAD := Color("ff8f86")

var members: Array = []
var index := 0
var tab := "全部"
var query := ""
var _search: LineEdit
var _cards: Control
var _detail_scroll: ScrollContainer
var _top: Control


## members：战斗中的队员（$gameParty.battleMembers）；who：点开的那位（没有就第一位）
static func open(parent: Control, list: Array, who: XBattler) -> XPartyStatusPanel:
	var p := XPartyStatusPanel.new()
	p.members = list
	p.index = maxi(0, list.find(who))
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	render()


func _draw() -> void:
	draw_frame()


func actor() -> XBattler:
	return members[mini(index, members.size() - 1)] if not members.is_empty() else null


func render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var a := actor()
	if a == null:
		close.call_deferred()
		return
	head(a.display_name() + " · 状态详情", "查看时暂停战斗，关闭后继续。")
	_detail_scroll = _panel_scroll(DETAIL, 13)
	var old := _detail_scroll.get_child(0)
	_detail_scroll.remove_child(old)
	old.queue_free()
	var w := WIDTH
	var rows := rows_for(a)
	var blocks := []
	var pill_items := []
	for t in ["HP %d / %d" % [int(a.hp), int(a.mhp)], "MP %d / %d" % [int(a.mp), int(a.mmp)], "TP %d" % int(a.tp)]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.3), Color(1, 211 / 255.0, 115 / 255.0, 0.45), 6, 1, Vector2(7, 3)))
		p.add_child(_fixed(_label(t, 13, GOLD), 20.8))
		p.set_meta("pill", true)
		pill_items.append(p)
	blocks.append(spaced(flow(pill_items, w, 7, 7, 28.8), 8, 8, w))
	if a is XActor:
		blocks.append(_spans(XPowerPanel.attribute_parts(a), 0))
		blocks.append(_spans(XPowerPanel.resistance_parts(a), 12))
	# 页签 .cq-tabs：间距 6、下距 8
	var tab_items := []
	for t in TABS:
		var n := rows.size() if t == "全部" else rows.filter(func(r): return r.kind == t).size()
		var b := _button("%s %d" % [t, n], _pick_tab.bind(t))
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("tab", t)
		if t == tab:
			for k in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(k, _box(CURSOR, CURSOR_EDGE))
		tab_items.append(b)
	blocks.append(spaced(flow(tab_items, w, 6, 6, 41.2), 0, 8, w))
	# 搜索框：宽 100%、下距 8
	_search = LineEdit.new()
	_search.placeholder_text = "搜索状态名称 / 效果"
	_search.text = query
	_search.add_theme_font_override("font", XUI.font())
	_search.add_theme_font_size_override("font_size", 17)
	_search.add_theme_color_override("font_color", TEXT)
	_search.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.5))
	_search.add_theme_stylebox_override("normal", _box(FIELD_BG, BUTTON_EDGE))
	_search.add_theme_stylebox_override("focus", _box(FIELD_BG, CURSOR_EDGE, 6, 2))
	_search.custom_minimum_size = Vector2(0, 41.2)
	_search.text_changed.connect(func(v: String):
		query = v
		_render_cards())
	blocks.append(spaced(_search, 0, 8, w))
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocks.append(_cards)
	_top = stack(blocks, w)
	_detail_scroll.add_child(_top)
	_render_cards()
	footer("显示实际效果、剩余回合和层数。", "返回战斗", close)
	queue_redraw()


func _pick_tab(t: String) -> void:
	tab = t
	render()


## renderStatusCards：按页签和搜索词过滤
func filtered() -> Array:
	var a := actor()
	if a == null:
		return []
	var q := XGearQuery.alias(query)
	return rows_for(a).filter(func(r): return (tab == "全部" or r.kind == tab) and (q == "" or XGearQuery.alias(r.name + " " + r.description).contains(q)))  # Godot 的 contains("") 是假


func _render_cards() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var w := WIDTH
	var blocks := []
	var list := filtered()
	if list.is_empty():
		blocks.append(spaced(text_block("没有%s状态符合当前条件。" % ("" if tab == "全部" else tab), 15, MUTED, 24.0, w - 40), 20, 20, w))
	for r in list:
		var meta: String = "%s · %s" % [r.kind, r.duration] + (" · %d层" % r.stack if int(r.stack) > 1 else "")
		var card := card_block([[str(r.name), 15, TEXT, 24.0, true], [meta, 13, MUTED, 20.8], [str(r.description), 15, TEXT, 24.0]], w)
		card.set_meta("state", r.id)
		if r.kind == "异常":
			var bg := card.get_child(0) as Panel
			var st := (bg.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
			st.border_color = BAD
			bg.add_theme_stylebox_override("panel", st)
		blocks.append(card)
	var inner := stack(blocks, w)
	_cards.add_child(inner)
	_cards.custom_minimum_size = Vector2(0, inner.custom_minimum_size.y)
	# 卡片区高度变了，重排整个详情块
	if _top != null:
		var y := 0.0
		for c in _top.get_children():
			c.position.y = y
			c.size = Vector2(w, c.custom_minimum_size.y)
			y += c.custom_minimum_size.y
		_top.custom_minimum_size.y = y


func _spans(parts: Array, gap: int) -> Control:
	var items := []
	for p in parts:
		var l := _fixed(_label(p[0], 13, p[1]), 20.8)
		items.append(l)
	return flow(items, WIDTH, gap, 6, 20.8)


# ---- stateRows ----
## installEquipmentStatusRuntime stateRows(actor)：[{id, name, icon, kind, stack, duration, description}]
static func rows_for(b: XBattler) -> Array:
	var out := []
	var seen := {}
	for st in b.states():
		var id := int(st.get("id", 0))
		if seen.has(id) or not XSideStatus.visible_state(st):
			continue
		seen[id] = true
		var passive := not b.state_ids.has(id)
		var turns = b.state_turns.get(id)
		var duration := ""
		if id == XAlienBattle.corrosion_id():
			duration = "%d回合" % maxi(1, ceili(float(turns) if turns != null else 0.0))
		elif passive:
			duration = "被动常驻"
		elif str(st.get("note", "")).to_lower().contains("<permanent>"):
			duration = "常驻"
		elif int(st.get("autoRemovalTiming", 0)) > 0:
			duration = ("%d回合" % ceili(float(turns))) if turns != null and float(turns) > 0 else "本回合"
		else:
			duration = "本场战斗" if bool(st.get("removeAtBattleEnd", false)) else "持续生效"
		out.append({"id": id, "name": str(st.get("name", "")), "icon": int(st.get("iconIndex", 0)),
			"kind": XSideStatus.state_kind(st, passive), "stack": maxi(1, b.state_floor(id)), "duration": duration,
			"description": description(st)})
	for i in range(b.buffs.size()):
		var lv := int(b.buffs[i])
		if lv == 0:
			continue
		var pname: String = XSideStatus.PARAM_NAMES[i]
		out.append({"id": "buff%d" % i, "name": pname + ("强化" if lv > 0 else "弱化"), "icon": XEnemyStateIcon.buff_icon(lv, i),
			"kind": "增益" if lv > 0 else "异常", "stack": absi(lv), "duration": "%d回合" % maxi(0, int(b.buff_turns[i])),
			"description": pname + pct(b.param_buff_rate(i) - 1.0)})
	return XZhCollate.stable_sort(out, func(x, y):
		return (XSideStatus.KIND_ORDER.find(x.kind) - XSideStatus.KIND_ORDER.find(y.kind)) if x.kind != y.kind else XZhCollate.compare(x.name, y.name))


static var _re_note: RegEx


## stateDescription：<StateNote> 或描述（text 清理），否则特性说明，否则 1 号／行动限制
static func description(st: Dictionary) -> String:
	if _re_note == null:
		_re_note = RegEx.create_from_string("(?i)<(?:StateNote|STATE_HELP|ステートヘルプ)\\s*>([\\s\\S]*?)</(?:StateNote|STATE_HELP|ステートヘルプ)\\s*>")
	var m := _re_note.search(str(st.get("note", "")))
	var t := XGearQuery.text(m.get_string(1) if m != null else str(st.get("description", "")))
	if t != "":
		return t
	t = trait_description(st)
	if t != "":
		return t
	if int(st.get("id", 0)) == 1:
		return "HP归零，无法行动；复活后解除。"
	var r := int(st.get("restriction", 0))
	if r > 0:
		return RESTRICT[r] if r < RESTRICT.size() and RESTRICT[r] != "" else "行动受到限制"
	return ""


## JS pct：(n>0?'+':'')+(Math.round(n*1000)/10)+'%'
static func pct(n: float) -> String:
	var v := XPower.js_round(n * 1000.0) / 10.0
	var s := str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
	return ("+" if n > 0 else "") + s + "%"


static func _name_of(list, i: int, fallback: String) -> String:
	if list is Array and i >= 0 and i < list.size() and str(list[i]) != "":
		return str(list[i])
	return fallback


static func trait_description(st: Dictionary) -> String:
	var sys := XDB.system()
	var parts := []
	for t in st.get("traits", []):
		var code := int(t.get("code", 0))
		var d := int(t.get("dataId", 0))
		var v := float(t.get("value", 0))
		var s := ""
		match code:
			21:
				if v != 1.0:
					s = _name_of(XSideStatus.PARAM_NAMES, d, "undefined") + pct(v - 1.0)
			22:
				if v != 0.0:
					s = _name_of(XPARAMS, d, "undefined") + pct(v)
			23:
				s = _name_of(SPARAM23, d, "undefined") + "倍率 %d%%" % int(XPower.js_round(v * 100))
			62:
				s = FLAG62[d] if d >= 0 and d < FLAG62.size() else ""
			61:
				s = "额外行动概率 %d%%" % int(XPower.js_round(v * 100))
			33:
				s = "攻击速度 " + _js_num(v)
			34:
				s = "额外攻击次数 " + _js_num(v)
			11:
				s = _name_of(sys.get("elements", []), d, "元素") + "承伤倍率 %d%%" % int(XPower.js_round(v * 100))
			13:
				s = str(XDB.rec("States", d).get("name", "")) if str(XDB.rec("States", d).get("name", "")) != "" else "状态"
				s += "施加倍率 %d%%" % int(XPower.js_round(v * 100))
			14:
				var n := str(XDB.rec("States", d).get("name", ""))
				s = "免疫 " + (n if n != "" else "状态")
			42:
				s = "封印 " + _name_of(sys.get("skillTypes", []), d, "技能类型")
			43:
				var n := str(XDB.rec("Skills", d).get("name", ""))
				s = "获得 " + (n if n != "" else "技能")
		if s != "":
			parts.append(s)
	return "；".join(parts)


static func _js_num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
