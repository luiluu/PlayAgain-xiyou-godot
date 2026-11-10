class_name XSideStatus
extends Control
## 右侧角色状态（Olivia_SideBattleUI Window_BattleSideStatus，正式版运行时读数）：
## - 窗口 (1280−200, 序号×121, 296, 121)，不透明度 0，内边距 0；内容是暗底：左 74px 由透明渐变到黑 0.6，其余黑 0.6。
## - 子窗口（缩放 0.6：字号 16、行高 22、文字边距 4）：名字 (0,6)；HP (8,28)、MP (16,50)、TP (24,72)，量条宽 160、高 6；
##   名字按 HP 颜色（濒危黄、死亡红）；HP/MP 为 YEP drawCurrentAndMax「当前/最大」，TP 只显示数值。
## - 护盾（ShieldSystem 钩 Window_BattleSideHP.refresh）：护盾大于 0 时，在 HP 条上按 max(生命上限, HP＋护盾) 折算，
##   从 HP 位置到 HP＋护盾位置叠一段蓝色 rgba(0,136,255,0.7)（高 6，贴行底）；HP 字样右侧 6px 写「盾＋数值」（12 号、#88ccff、描边黑 0.7，万／亿／兆…一位小数）。
##   画面对照（八戒_50，原版参照 battle_shield_side）：蓝段四种情形逐像素一致。
## - 谷雨（installNativeGuyuRuntime 489～510，参照 guyu_ui_probe）：护盾数值与蓝段按合计（其他来源＋花荫账本，XGuyu.total_shield）；
##   谷雨在队的战斗中名字行右侧写状态字（XGuyu.status_text：储备、归根／待绽／花期／生长）：名字宽收到 floor(200×0.38)＝76，
##   状态字 10 号（max(10, floor(16×0.68))）、#b7ead0，在 76～200 之间靠右。
## - 状态格（installEquipmentStatusRuntime）：(−36, 20) 36×36，有图标状态时每 1.4 秒轮换显示一个，否则深色方块里写「i」。
## - 状态格上叠一个透明按钮（同位置 32×32），悬停提示「名字：当前状态名（没有写「无图标状态」）；点击查看全部状态」，
##   点了发 cell_pressed，战斗打开状态详情（XPartyStatusPanel）。
## - 轮到输入或正在行动的角色左移 48，被选为目标时左移 24，每帧移动 4px。

const W := 296.0
const H := 121.0
const HOME_X := 1280.0 - 200.0
const MOVE_ACTIVE := 48.0
const MOVE_SELECTED := 24.0
const MOVE_SPEED := 4.0
const LH := 22.0
const FS := 16
const PAD := 4.0
const GAUGE_W := 160.0
const CYCLE_MS := 1400
const SHIELD_SEG := Color8(0, 136, 255, 179)
const SHIELD_COLOR := Color("#88ccff")
## ShieldSystem 设 outlineColor rgba(0,0,0,0.7)、outlineWidth 2；宽度被正式版封顶 0.75px（同通用细描边），颜色照设
const SHIELD_OUTLINE := Color(0, 0, 0, 0.7)
## 名字子窗口宽（Window_BattleSideStatus 宽 296 − 2×ActiveBattlerMove 48）
const NAME_W := 200.0
const GUYU_SPLIT := 76.0
const GUYU_FS := 10
const GUYU_COLOR := Color("#b7ead0")

signal cell_pressed(actor: XActor)

var actor: XActor
## 演出中的读数（XBattleScene.show_views 设、clear_views 清）；空时读实时状态
var view := {}
var active := false
var selected := false
var canvas: XMVCanvas
var cell_button: Button
var _cycle := 0
var _cycle_at := 0


func setup(a: XActor, index: int) -> void:
	actor = a
	position = Vector2(HOME_X, index * H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = XMVCanvas.new()
	canvas.position = Vector2(-36, 0)
	canvas.size = Vector2(W + 36, H)
	canvas.clip_contents = false
	canvas.painter = _paint
	add_child(canvas)
	cell_button = Button.new()
	cell_button.flat = true
	cell_button.focus_mode = Control.FOCUS_NONE
	cell_button.position = Vector2(-36, 20)
	cell_button.size = Vector2(32, 32)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell_button.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	cell_button.pressed.connect(func(): cell_pressed.emit(actor))
	cell_button.mouse_entered.connect(func(): cell_button.tooltip_text = cell_tip())
	add_child(cell_button)


func refresh() -> void:
	canvas.queue_redraw()


## 悬停提示（installEquipmentStatusRuntime updateIconButtons 的 title）：当前轮到的那个状态名
func cell_tip() -> String:
	if actor == null:
		return ""
	var rows := XPartyStatusPanel.rows_for(actor).filter(func(r): return int(r.icon) > 0) if CELL_FILTER else []
	var name := str(rows[_cycle % rows.size()].name) if not rows.is_empty() else "无图标状态"
	return actor.display_name() + "：" + name + "；点击查看全部状态"


func _physics_process(_delta: float) -> void:
	var target := HOME_X - (MOVE_ACTIVE if active else (MOVE_SELECTED if selected else 0.0))
	if position.x < target:
		position.x = minf(position.x + MOVE_SPEED, target)
	elif position.x > target:
		position.x = maxf(position.x - MOVE_SPEED, target)
	var now := Time.get_ticks_msec()
	if now > _cycle_at:
		_cycle_at = now + CYCLE_MS
		_cycle += 1
		refresh()


func _icons() -> Array:
	return _rows().map(func(r): return int(r.icon))


func _rows() -> Array:
	if not view.is_empty():
		return view.get("cell_rows", [])
	return cell_rows(actor)


## 状态格轮换的内容（installEquipmentStatusRuntime stateRows，再滤掉没图标的）：states() 去重，只留 visibleState——
## 有名字、不是「角色血量／蓝量／…」能力项、不是纯数字、不带「战斗形象／战斗换图／视觉辅助」，且有说明（<StateNote>、描述、
## 能写出说明的特性，或 1 号无法战斗、有行动限制）；之后接强弱化（buffIconIndex，层数＝等级绝对值）。层数 stateFloor（没有按 1）。
## rules-battle-pixel2 对照改：重制原来凡带图标的状态都轮换（共 275 个带图标状态原版不进状态格，如越战越勇、出血），也不轮强弱化、不画层数。
## 回退：CELL_FILTER = false 回到原来「带图标的状态全轮、不接强弱化、不画层数」（也不排序，按 states() 顺序）。
## 顺序（rules-passive-order1）：stateRows 最后 result.sort——先按类别「异常→增益→常驻」（stateKind），同类按名字
## localeCompare(…,'zh-Hans')（拼音序，XZhCollate），V8 稳定排序、同名同类保持 states() 顺序；强弱化行一起排。
## 原版读数（battle_pixel_ref 敌群 2）995 破阵——天道诅咒（名含「诅咒」→异常）→ 1691 难度适应 → 1631 普通难度·结算伤害（都常驻）。
## rules-battle-pixel2 当时记成「按被动来源顺序」是巧合，原版并不看来源。
static var CELL_FILTER := true
const KIND_ORDER := ["异常", "增益", "常驻"]
const PARAM_NAMES := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "敏捷", "幸运"]


static func cell_rows(b: XBattler) -> Array:
	var out := []
	var seen := {}
	for st in b.states():
		var id := int(st.get("id", 0))
		if seen.has(id):
			continue
		seen[id] = true
		var icon := int(st.get("iconIndex", 0))
		if icon <= 0:
			continue
		if not CELL_FILTER:
			out.append({"icon": icon, "stack": 1})
		elif _visible_cached(id, st):
			out.append({"icon": icon, "stack": maxi(1, b.state_floor(id)), "kind": _kind_cached(id, st, not b.state_ids.has(id)), "name": str(st.get("name", ""))})
	if not CELL_FILTER:
		return out
	for i in range(b.buffs.size()):
		var lv := int(b.buffs[i])
		if lv != 0:
			var icon := XEnemyStateIcon.buff_icon(lv, i)
			if icon > 0:
				var pname: String = PARAM_NAMES[i] if i < PARAM_NAMES.size() else ""
				out.append({"icon": icon, "stack": absi(lv), "kind": "增益" if lv > 0 else "异常", "name": pname + ("强化" if lv > 0 else "弱化")})
	out = XZhCollate.stable_sort(out, func(x, y):
		return (KIND_ORDER.find(x.kind) - KIND_ORDER.find(y.kind)) if x.kind != y.kind else XZhCollate.compare(x.name, y.name))
	return out.map(func(r): return {"icon": r.icon, "stack": r.stack})


static var _re_bufftype: RegEx
static var _re_bad_type: RegEx
static var _re_good_type: RegEx
static var _re_bad_name: RegEx
static var _re_permanent: RegEx

## installEquipmentStatusRuntime stateKind(s, passive)：passive＝不在 _states 里（重制：不在 state_ids，如套装状态）
static func state_kind(st: Dictionary, passive: bool) -> String:
	if passive:
		return "常驻"
	if _re_bufftype == null:
		_re_bufftype = RegEx.create_from_string("(?i)<BuffType:\\s*([^>]+)>")
		_re_bad_type = RegEx.create_from_string("(?i)减益|异常|削弱|持续伤害|debuff|诅咒|暗黑|沉默|混乱|魅惑|破甲|睡眠|麻痹|中毒|封印")
		_re_good_type = RegEx.create_from_string("(?i)增益|强化|加成|buff")
		_re_bad_name = RegEx.create_from_string("诅咒|中毒|剧毒|疾病|睡眠|失明|封印|沉默|眩晕|麻痹|破甲|灼伤|流血|虚弱|异界制约|压制|威压")
		_re_permanent = RegEx.create_from_string("(?i)<Permanent>")
	var note := str(st.get("note", ""))
	var m := _re_bufftype.search(note)
	if m != null and _re_bad_type.search(m.get_string(1)) != null:
		return "异常"
	if m != null and _re_good_type.search(m.get_string(1)) != null:
		return "增益"
	if int(st.get("restriction", 0)) > 0 or int(st.get("id", 0)) == 1 or _re_bad_name.search(str(st.get("name", ""))) != null:
		return "异常"
	for t in st.get("traits", []):
		var code := int(t.get("code", 0))
		var v := float(t.get("value", 0))
		if (code == 21 and v < 1.0) or (code == 22 and v < 0.0) or code == 42:
			return "异常"
	return "常驻" if _re_permanent.search(note) != null else "增益"


const _HIDDEN_NAME := "^角色(?:血量|蓝量|生命|魔法|物攻|魔攻|物防|魔防|敏捷|幸运)$"
static var _re_hidden: RegEx
static var _re_note: RegEx
static var _re_strip: RegEx


static var _visible_cache := {}
static var _kind_cache := {}


## state_kind 按（状态号、是否被动）缓存：被动恒为「常驻」，不进缓存；只缓存数据库原条（XDB.rec 同一个字典），
## states() 换过的视图（XZhenqi.pojia_state 改特性 21 的倍率，可能改变「异常」判定）每次现算（审查第 76 期）
static func _kind_cached(id: int, st: Dictionary, passive: bool) -> String:
	if passive:
		return "常驻"
	if not is_same(st, XDB.rec("States", id)):
		return state_kind(st, false)
	if not _kind_cache.has(id):
		_kind_cache[id] = state_kind(st, false)
	return _kind_cache[id]


## 状态数据不变（同号同一条），按号缓存；画面快照每条日志都要算
static func _visible_cached(id: int, st: Dictionary) -> bool:
	if not _visible_cache.has(id):
		_visible_cache[id] = visible_state(st)
	return _visible_cache[id]


## installEquipmentStatusRuntime visibleState
static func visible_state(st: Dictionary) -> bool:
	if _re_hidden == null:
		_re_hidden = RegEx.create_from_string(_HIDDEN_NAME)
		_re_note = RegEx.create_from_string("(?i)<(?:StateNote|STATE_HELP|ステートヘルプ)\\s*>([\\s\\S]*?)</(?:StateNote|STATE_HELP|ステートヘルプ)\\s*>")
		_re_strip = RegEx.create_from_string("(?i)\\\\[a-z]+\\[[^\\]]*\\]|<[^>]*>|\\\\[{}.!|><^]")
	var name := str(st.get("name", ""))
	if name == "" or _re_hidden.search(name) != null or name.is_valid_int() or name.contains("战斗形象") or name.contains("战斗换图") or name.contains("视觉辅助"):
		return false
	return has_description(st)


## stateDescription 不为空：<StateNote> 或描述（去掉转义码与标签后），否则能写出说明的特性，否则 1 号或有行动限制
static func has_description(st: Dictionary) -> bool:
	var m := _re_note.search(str(st.get("note", "")))
	var raw := m.get_string(1) if m != null else str(st.get("description", ""))
	if _re_strip.sub(raw, "", true).strip_edges() != "":
		return true
	for t in st.get("traits", []):
		var code := int(t.get("code", 0))
		var v := float(t.get("value", 0))
		if (code == 21 and v != 1.0) or (code == 22 and v != 0.0) or code in [23, 61, 33, 34, 11, 13, 14, 42, 43] \
				or (code == 62 and int(t.get("dataId", -1)) in [0, 1, 2, 3]):
			return true
	return int(st.get("id", 0)) == 1 or int(st.get("restriction", 0)) > 0


func _paint(c: XMVCanvas) -> void:
	if actor == null:
		return
	var ox := 36.0   # 画布向左多出状态格的 36px
	var dark := Color(0, 0, 0, 0.6)
	var w1 := ceilf(W / 4.0)
	c.gradient(Rect2(ox, 0, w1, H), Color(0, 0, 0, 0), dark)
	c.draw_rect(Rect2(ox + w1, 0, W - w1, H), dark)
	# 状态格
	var rows := _rows()
	if rows.is_empty():
		c.draw_rect(Rect2(ox - 36 + 1, 21, 30, 30), Color8(20, 35, 55, 230))
		c.text("i", ox - 36, 20, 32, "center", XUI.TEXT, 22, 36)
	else:
		var row: Dictionary = rows[_cycle % rows.size()]
		c.icon(int(row.icon), ox - 36, 20)
		if int(row.stack) > 1:  # drawText(层数, 0, 12, 30, 'right')，12 号
			c.text(str(row.stack), ox - 36, 20 + 12, 30, "right", XUI.TEXT, 12, 36)
	# 名字（谷雨状态字在右）
	var v := _v()
	var info := str(v.get("guyu_text", ""))
	c.text(actor.display_name(), ox + PAD, 6, GUYU_SPLIT if info != "" else NAME_W, "left", _hp_color(), FS, LH)
	if info != "":
		c.text(info, ox + GUYU_SPLIT, 6, NAME_W - GUYU_SPLIT, "right", GUYU_COLOR, GUYU_FS, LH)
	# HP / MP / TP
	_param(c, ox + 8 + PAD, 28, "HP", v.hp, v.mhp, XUI.GAUGES.hp, _hp_color(), true)
	_shield(c, ox + 8 + PAD, 28, v)
	_param(c, ox + 16 + PAD, 50, "MP", v.mp, v.mmp, XUI.GAUGES.mp, XUI.TEXT, true)
	_param(c, ox + 24 + PAD, 72, "TP", v.tp, v.mtp, XUI.GAUGES.tp, XUI.TEXT, false)


func _v() -> Dictionary:
	if not view.is_empty():
		return view
	return {"hp": actor.hp, "mhp": actor.mhp, "mp": actor.mp, "mmp": actor.mmp, "tp": actor.tp, "mtp": actor.max_tp(), "dead": actor.is_dead(),
		"shield": actor.shield, "guyu_shield": XGuyu.shield_of(actor), "guyu_text": XGuyu.status_text(actor)}


func _shield(c: XMVCanvas, x: float, y: float, v: Dictionary) -> void:
	var s := float(v.get("shield", 0.0)) + float(v.get("guyu_shield", 0.0))
	if s <= 0.0:
		return
	var seg := shield_segment(v.hp, v.mhp, s, x)
	if seg.y > seg.x:
		c.draw_rect(Rect2(seg.x, y + LH - 6.0, seg.y - seg.x, 6.0), SHIELD_SEG)
	var label := "盾" + shield_text(s)
	c.text(label, x + c.text_width("HP", FS) + 6.0, y, c.text_width(label, 12) + 4.0, "left", SHIELD_COLOR, 12, LH, 1.0, 1.0, Vector2.ZERO, SHIELD_OUTLINE)


## 蓝段的起止 x（HP 位置到 HP＋护盾位置，按 max(生命上限, HP＋护盾, 1) 折算，取整同原版 Math.floor）
static func shield_segment(hp: float, mhp: float, s: float, x: float) -> Vector2i:
	var mx := maxf(maxf(mhp, hp + s), 1.0)
	return Vector2i(int(floorf(x + GAUGE_W * minf(hp / mx, 1.0))), int(floorf(x + GAUGE_W * minf((hp + s) / mx, 1.0))))


## formatShieldText：一万起按 万／亿／兆／京／垓／秭／穰／沟／涧／正／载 取一位小数，以下取整
static func shield_text(value: float) -> String:
	const UNITS := [[1e44, "载"], [1e40, "正"], [1e36, "涧"], [1e32, "沟"], [1e28, "穰"], [1e24, "秭"], [1e20, "垓"],
		[1e16, "京"], [1e12, "兆"], [1e8, "亿"], [1e4, "万"]]
	for u in UNITS:
		if value >= u[0]:
			return "%.1f%s" % [value / u[0], u[1]]
	return str(int(floorf(value)))


func _param(c: XMVCanvas, x: float, y: float, label: String, cur: float, mx: float, colors: Array, color: Color, with_max: bool) -> void:
	c.gauge(x, y, GAUGE_W, cur / mx if mx > 0 else 0.0, colors[0], colors[1], LH)
	c.text(label, x, y, 44, "left", XUI.SYSTEM, FS, LH)
	if not with_max:
		c.text(XMenu._group(cur), x + GAUGE_W - 64, y, 64, "right", color, FS, LH)
		return
	# YEP drawCurrentAndMax
	var vw := c.text_width(XMenu._group(mx), FS)
	var sw := c.text_width("/", FS)
	var x1 := x + GAUGE_W - vw
	var x2 := x1 - sw
	var x3 := x2 - vw
	if x3 >= x + c.text_width("HP", FS):
		c.text(XMenu._group(cur), x3, y, vw, "right", color, FS, LH)
		c.text("/", x2, y, sw, "right", XUI.TEXT, FS, LH)
		c.text(XMenu._group(mx), x1, y, vw, "right", XUI.TEXT, FS, LH)
	else:
		c.text(XMenu._group(cur), x1, y, vw, "right", color, FS, LH)


func _hp_color() -> Color:
	var v := _v()
	if v.dead:
		return XUI.DEATH
	if v.hp < v.mhp / 4.0:
		return XUI.CRISIS
	return XUI.TEXT
