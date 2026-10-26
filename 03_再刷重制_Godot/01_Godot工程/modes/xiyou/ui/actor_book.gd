class_name XActorBook
extends Control
## 人物图鉴（Star_ActorsBook 的 Scene_ActorBook＋Codex_ActorBookSkillDetails；主菜单「人物图鉴」＝公共事件 3 SceneManager.push）。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/actor_book_oracle.json，新局队伍 1/8/9/10）：
## - 目录窗 (0,0,320,720)：$dataActors 每个槽一行（0 号与空槽「？？？」），行高 36、可见 19 行，文字 (6, 宽 280)。
##   Codex 补丁打开即全解锁（ActorBookLite 收进全部有名角色），所以不需要存档字段。
## - 状态窗 (320,0,960,720)：内容宽 932，column2x = 932/2+7 = 473。SV 侧视图待机（行走动作，0-1-2-1 每 12 帧）以
##   窗口内 (93.2, 71.69) 为中心；名字、职业 1 级八项初值（标签 systemColor，值在「标签＋8 空格」后）、品质七档色、
##   人物属性（18 号，CodexElements.drawAttributes）、最大进阶次数（Star_ActorAdvanced 表里本角色、当前次数 0 的 AdvancedActNumMaX）；
##   y 144 起「主动／被动／其他」三列技能（drawItemName，宽 1280）；y 504 起武器／防具掌握（每项间隔 9 个空格宽）与 <ActorNote> 备注
##   （每 32 字一行，原版循环多画一行空串）。渡鸦 167、173 特殊：技能行高 32、20 号、列宽 298，掌握放到「其他」列、四项一行用「、」连。
## - 目录确定进技能详情（空槽蜂鸣）：抬头窗 (0,0,537,100)「名字 · 技能详情」居中 systemColor＋18 号操作提示；
##   列表窗 (0,100,537,620) 每行「【类型】」(战技等 textColor 3、被动 14、其他 6)＋drawItemName，特殊角色未学会的技能右端灰字「未解锁」；
##   说明卡 Sprite_ItemHelp 宽 1280−537−16 = 727，固定在 (545, 8)，去掉备注里的 <HelpWidth:N>；传的是技能浅拷贝，
##   所以不插「伤害属性」行（XHelpCard.skill_copy）。描述字号沿用说明卡的最小字号优化（O-007）。取消回目录。
## - 技能来源（CodexActorBookSkills）：角色与职业特性 43、职业学习表；排除 stypeId 3、系统技能（5968～5973、5980、6216、6235、
##   公共事件 1442 里 learnSkill 的）、<CodexRetired> 与难度／轮回类名字；详情页另补特殊角色 167～174 的专属技能段。
## 与原版不同（O-084）：原版进过技能详情再返回，说明卡的品质边框（4 层 Window_ItemHelp）留在状态页上；这里返回时整张卡隐藏。
## 切片外角色（108、143～145、157、169～171）没导出 SV 图，状态页不画立绘（补图要扩切片）；
## 168、173～177 的多帧图未移植，也不画（sprite_path）。

signal closed

const INDEX_RECT := Rect2(0, 0, 320, 720)
const STATUS_RECT := Rect2(320, 0, 960, 720)
const LEFT_W := 537.0                      # floor(1280 × 0.42)
const HEADER_RECT := Rect2(0, 0, 537, 100)  # 高 = 行高 × 2 + 内边距 × 2
const LIST_RECT := Rect2(0, 100, 537, 620)
const HELP_POS := Vector2(545, 8)
const HELP_WIDTH := 727.0
const LH := 36.0
const INDEX_ROWS := 19                     # floor((720 − 28) / 36)
const LIST_ROWS := 16                      # floor((620 − 28) / 36)
const BOX_W := 1280.0
const CONTENT_W := 932.0                   # 状态窗内容宽
const SPRITE_CENTER := Vector2(93.2, 932.0 / 13.0)   # 窗口坐标（精灵是窗口子节点，不含内边距）
const PARAM_LABELS := ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"]
## installUnifiedQualityRuntime actorGrades：人物原生品质 → 七档（12 按 10 处理，未列出的为 0）
const ACTOR_GRADES := {0: 0, 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 4, 8: 5, 9: 5, 10: 6, 12: 6}
const SYSTEM_BOOK_SKILLS := [5968, 5969, 5970, 5971, 5972, 5973, 5980, 6216, 6235]
const EXTERNAL_NAME := "^(?:轮回模式(?:·|$)|灭世挑战|(?:宝宝|简单|普通|困难|地狱|天灾)难度$|难度适应$|天道诅咒$)"
const RAVEN_SKILLS := [10122, 10123, 10124, 10125, 10126, 10127, 10129, 10130, 10131, 10132, 10133, 10134,
	10136, 10137, 10138, 10139, 10170]
const TOJI_SKILLS := [10203, 10205, 10206, 10207, 10208, 10209, 10210, 10211, 10212, 10213, 10214, 10215, 10216,
	10217, 10218, 10219, 10225, 10226]
const PREVIEW_ACTORS := [167, 168, 169, 170, 172, 173, 174]
## installNativeRavenRuntime 的 [等级, 进阶] 解锁表里要进阶的技能：新建的渡鸦（进阶 0）没有学会
const RAVEN_ADVANCE_GATED := [10123, 10124, 10125, 10126, 10127, 10133, 10136, 10139, 10170]
const ATTR_INK := Color("c1c9d5")
## 优化 O-084：返回目录时整张说明卡隐藏；false 照原版只藏卡本体、把 4 层品质边框留在状态页上（矩形 [535,-2,747,卡高+20]）
static var HIDE_HELP_ON_RETURN := true

var index := 0
var top := 0
var mode := "index"          # index / skills
var skill_index := -1
var skill_top := 0
var skill_list: Array = []    # 技能详情页的技能记录
var index_win: XMVWindow
var status_win: XMVWindow
var header_win: XMVWindow
var list_win: XMVWindow
var help_card: XHelpCard
var _frame := 0
var _sprite_tex: Texture2D
var _status_ops: Array = []
static var _external: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	index_win = XMVWindow.make(self, INDEX_RECT, XUI.MENU_WINDOW_OPACITY, _paint_index)
	status_win = XMVWindow.make(self, STATUS_RECT, XUI.MENU_WINDOW_OPACITY, _paint_status)
	header_win = XMVWindow.make(self, HEADER_RECT, XUI.MENU_WINDOW_OPACITY, _paint_header)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	index_win.canvas.blink = true
	list_win.canvas.blink = true
	help_card = XHelpCard.new()
	help_card.card_width = HELP_WIDTH
	help_card.skill_copy = true
	add_child(help_card)
	_show_skills(false)
	_select_actor()


func _process(_delta: float) -> void:
	# Window_ActorBookStatus.update：每 12 帧换一格（0-1-2-1）
	_frame += 1
	if _sprite_tex != null and _frame % 12 == 0 and mode == "index":
		status_win.canvas.queue_redraw()


# ---- 数据 ----
static func actor_count() -> int:
	return (XDB.table("Actors") as Array).size()


static func named(id: int) -> bool:
	return str(XDB.rec("Actors", id).get("name", "")) != ""


## 图鉴里用的角色：已建出的用存档里的（职业、改名、已学技能），否则按数据库新建时的样子
static func _live(id: int) -> XActor:
	var s := XState.current
	return s.actors.get(id) if s != null and s.actors.has(id) else null


static func actor_name(id: int) -> String:
	var a := _live(id)
	return a.display_name() if a != null else str(XDB.rec("Actors", id).get("name", ""))


## Window_ActorBookIndex.refresh：有名角色写名字，否则「？？？」
static func index_names() -> Array:
	var out := []
	for i in actor_count():
		out.append(actor_name(i) if named(i) else "？？？")
	return out


static func class_id(id: int) -> int:
	var a := _live(id)
	return a.class_id if a != null else int(XDB.rec("Actors", id).get("classId", 0))


static func quality_grade(raw: int) -> int:
	return int(ACTOR_GRADES.get(raw, 0))


## Star_ActorAdvanced 进阶表：本角色当前进阶次数（XAdvance.rank）那一行的 AdvancedActNumMaX；没有行（已满）显示当前次数
static func advance_max(id: int) -> String:
	# installNativeRavenRuntime 运行时补登渡鸦 0～4 阶五条（AdvancedActNumMaX 5；XAdvance 不含，渡鸦不在切片），满后显示次数
	var n := XAdvance.rank(XState.current, id)
	if id == 167:
		return str(5 if n < 5 else n)
	return str(XAdvance.max_text(XState.current, id))


static func _external_skill(skill: Dictionary) -> bool:
	if _external.is_empty():
		for id in SYSTEM_BOOK_SKILLS:
			_external[id] = true
		var ev := XDB.rec("CommonEvents", 1442)
		var re := RegEx.create_from_string("\\.learnSkill\\((\\d+)\\)")
		for cmd in ev.get("list", []):
			if int(cmd.code) == 355 or int(cmd.code) == 655:
				for m in re.search_all(str(cmd.parameters[0])):
					_external[int(m.get_string(1))] = true
	if _external.has(int(skill.id)) or skill.get("meta", {}).has("CodexRetired"):
		return true
	return RegEx.create_from_string(EXTERNAL_NAME).search(str(skill.get("name", ""))) != null


## CodexActorBookSkills(actor, baseOnly)：主动（stypeId 1～3）、被动（4）、其他（5）依次排
static func book_skills(id: int, base_only: bool) -> Array:
	var active := []
	var passive := []
	var other := []
	var seen := {}
	var add := func(sid: int) -> void:
		var s := XDB.rec("Skills", sid)
		if s.is_empty() or str(s.get("name", "")) == "" or seen.has(sid) or int(s.stypeId) == 3 or _external_skill(s):
			return
		seen[sid] = true
		var t := int(s.stypeId)
		if t >= 1 and t <= 3:
			active.append(s)
		elif t == 4:
			passive.append(s)
		elif t == 5:
			other.append(s)
	var add_traits := func(d: Dictionary) -> void:
		for t in d.get("traits", []):
			if int(t.code) == 43:
				add.call(int(t.dataId))
	var actor_data := XDB.rec("Actors", id)
	var class_data := XDB.rec("Classes", class_id(id))
	var raven := id == 167
	add_traits.call(actor_data)
	if not raven or base_only:
		add_traits.call(class_data)
		for l in class_data.get("learnings", []):
			add.call(int(l.skillId))
	if not base_only:
		if raven:
			for sid in RAVEN_SKILLS:
				add.call(sid)
		elif id == 168 and str(actor_data.get("name", "")) != "":
			for sid in range(10140, 10168):
				if sid != 10147 and sid != 10153:
					add.call(sid)
		elif id == 169 or id == 170:
			var first := 10171 if id == 169 else 10187
			for sid in range(first, first + 16):
				add.call(sid)
		elif id == 172:
			for sid in range(10229, 10250):
				if not sid in [10236, 10237, 10238]:
					add.call(sid)
			add.call(10225)
		elif id == 173:
			for sid in range(10250, 10270):
				if sid != 10258 and sid != 10264:
					add.call(sid)
		elif id == 171:
			for sid in TOJI_SKILLS:
				add.call(sid)
		if id == 174:
			for sid in range(10270, 10282):
				add.call(sid)
			add.call(10287)
	return active + passive + other


## 已学技能（「未解锁」判断）：已建出的角色用 skills()，否则按 Game_Actor.setup 新建时学会的
static func known_skill_ids(id: int) -> Array:
	var a := _live(id)
	if a != null:
		return a.skills().map(func(s): return int(s.id))
	var d := XDB.rec("Actors", id)
	var out := []
	for l in XDB.rec("Classes", int(d.get("classId", 0))).get("learnings", []):
		if int(l.level) <= int(d.get("initialLevel", 1)):
			out.append(int(l.skillId))
	if id >= 141 and id <= 172:  # fixStrongClassification
		out.erase(6235)
		out.append(6216)
		if out.has(5970):
			out.erase(5970)
			out.append(5971)
	for src in [d, XDB.rec("Classes", int(d.get("classId", 0)))]:
		for t in src.get("traits", []):
			if int(t.code) == 43:
				out.append(int(t.dataId))
	if id == 167:
		out = out.filter(func(x): return not x in RAVEN_ADVANCE_GATED)
	return out


static func _skill_color(s: Dictionary) -> Color:
	return XQuality.list_color(s)


## 文字操作 ["t", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色]；图标 ["i", 图标号, x, y]（与参照 JSON 同形）
static func _t(text: String, x: float, y: float, w: float, color: Color, size := XUI.FONT_SIZE, align := "left", h := LH) -> Array:
	return ["t", text, x, y, w, h, align, size, color]


## Window_Base.drawItemName：图标 (x+2, y+2)，名字 (x+36, 宽 −36)
static func _item_name(ops: Array, s: Dictionary, x: float, y: float, w: float, size := XUI.FONT_SIZE) -> void:
	if int(s.get("iconIndex", 0)) > 0:
		ops.append(["i", int(s.iconIndex), x + 2, y + 2])
	ops.append(_t(str(s.name), x + 36, y, w - 36, _skill_color(s), size))


## Window_ActorBookStatus.drawAllContents 的全部绘制（measure：字宽函数 (文字, 字号) → 宽）
static func status_ops(id: int, measure: Callable) -> Array:
	var ops := []
	if id <= 0 or not named(id):
		return ops
	var d := XDB.rec("Actors", id)
	var params: Array = XDB.rec("Classes", class_id(id)).get("params", [])
	var pv := func(k: int) -> String:
		return str(int(params[k][1])) if k < params.size() and params[k].size() > 1 else "0"
	var tw := func(s: String, size := XUI.FONT_SIZE) -> float:
		return measure.call(s, size)
	var c2 := CONTENT_W / 2.0 + XMVWindow.PADDING / 2.0
	var cw := CONTENT_W / 2.0 - XMVWindow.PADDING
	var sp7: float = tw.call("       ")
	var cols := [c2 / 3.0 * 2.0, c2 / 10.0 * 11.0, c2 / 10.0 * 15.0]
	var y := 0.0
	ops.append(_t(actor_name(id), c2 / 3.0, y, cw, XUI.TEXT))
	# 标签：[参数, 列, 行]
	var grid := [[0, 0, 0], [1, 1, 0], [2, 0, 1], [3, 1, 1], [6, 2, 1], [4, 0, 2], [5, 1, 2], [7, 2, 2]]
	for g in grid:
		ops.append(_t(PARAM_LABELS[g[0]], cols[g[1]] + sp7, y + LH * g[2], cw, XUI.SYSTEM))
	for g in grid:
		ops.append(_t(pv.call(g[0]), cols[g[1]] + tw.call(PARAM_LABELS[g[0]] + "        "), y + LH * g[2], cw, XUI.TEXT))
		if g[0] == 1:
			ops.append(_t("初始值", cols[2] + sp7, y, cw, XUI.TEXT))
	y += LH
	ops.append(_t("品质 ", c2 / 3.0, y, cw, XUI.SYSTEM))
	var q = d.get("meta", {}).get("Actorquality", 0)
	var raw := int(float(str(q).strip_edges())) if str(q).strip_edges().is_valid_float() else 0  # Number(meta.Actorquality) || 0（值带前导空格）
	if raw == 12:
		raw = 10
	var g := quality_grade(raw)
	var label := str(XQuality.config().names[g]) if raw != 0 else "无"
	ops.append(_t(label, c2 / 3.0 + tw.call("品质:"), y, cw, XQuality.parse_rgba(str(XQuality.config().colors[g]))))
	y += LH
	# CodexElements.drawAttributes：各段宽 = 字宽 + 1，接着画；总宽超过列宽时字号按比例缩
	var probe := XActor.new()  # XDamage.affinity 只看角色 ID
	probe.actor_id = id
	var parts := XPowerStrip.attribute_parts(probe)
	parts[0][1] = XUI.TEXT
	for i in range(1, parts.size()):
		if parts[i][0] == "／":
			parts[i][1] = XUI.TEXT
	var total := 0.0
	for p in parts:
		total += tw.call(p[0], 18)
	var fs := 18 if total <= cw else int(roundf(18.0 * cw / total))
	var ax := c2 / 3.0
	for p in parts:
		var w: float = tw.call(p[0], fs)
		ops.append(_t(p[0], ax, y, w + 1, p[1], fs))
		ax += w
	y += LH
	ops.append(_t("最大进阶次数 ", c2 / 3.0, y, cw, XUI.SYSTEM))
	ops.append(_t(advance_max(id), c2 / 3.0 + tw.call("最大进阶次数:"), y, cw, XUI.TEXT))
	y += LH
	var raven := id == 167 or id == 173
	var skill_lh := 32.0 if raven else LH
	var note_y := y + LH * 10
	var initial_y := y + LH
	var raven_w := floorf(CONTENT_W / 3.0) - 12
	ops.append(_t("主动", 0, y, BOX_W, XUI.SYSTEM))
	ops.append(_t("被动", c2 * 2.0 / 3.0, y, BOX_W, XUI.SYSTEM))
	ops.append(_t("其他", c2 * 4.0 / 3.0, y, BOX_W, XUI.SYSTEM))
	var offsets := [0.0, c2 * 2.0 / 3.0, c2 * 4.0 / 3.0 - tw.call(" ")]
	var skills := book_skills(id, true)
	for col in 3:
		var ry := initial_y
		for s in skills:
			var t := int(s.stypeId)
			if (col == 0 and t >= 1 and t <= 3) or (col == 1 and t == 4) or (col == 2 and t == 5):
				if raven:
					_item_name(ops, s, offsets[col], ry, raven_w, 20)
				else:
					_item_name(ops, s, offsets[col], ry, BOX_W)
				ry += skill_lh
	y = initial_y if raven else note_y
	var mx: float = offsets[2] if raven else 0.0
	var mw: float = CONTENT_W - mx - 4 if raven else BOX_W
	var sys: Dictionary = XDB.system()
	var traits: Array = XDB.rec("Classes", class_id(id)).get("traits", [])
	for kind in [[51, "武器掌握", "weaponTypes"], [52, "防具掌握", "armorTypes"]]:
		ops.append(_t(kind[1], mx, y, mw, XUI.SYSTEM))
		y += LH
		var ids := []
		for t in traits:
			if int(t.code) == kind[0]:
				ids.append(int(t.dataId))
		ids.sort()
		# 类型表里没有的 ID（174 的武器类型 13 起）原版 drawText(undefined) 不画，但仍占位
		var names: Array = ids.map(func(i): return str(sys[kind[2]][i]) if i < sys[kind[2]].size() else "")
		if raven:
			var r := 0
			while r < names.size():
				ops.append(_t("、".join(names.slice(r, r + 4).filter(func(n): return n != "")), mx, y, mw, XUI.TEXT, 18))
				if r + 4 < names.size():
					y += skill_lh
				r += 4
		else:
			var gap: float = tw.call("         ")
			for i in names.size():
				if names[i] != "":
					ops.append(_t(names[i], gap * i, y, BOX_W, XUI.TEXT))
		y += LH
	# <ActorNote>…</ActorNote>：每 32 字一行，0..ceil(长/32) 共多画一行
	var showing := false
	for line in RegEx.create_from_string("[\\r\\n]+").sub(str(d.get("note", "")), "\n", true).split("\n"):
		if line == "<ActorNote>" or showing:
			showing = true
			if line == "</ActorNote>":
				showing = false
			elif line != "<ActorNote>":
				for a in range(int(ceilf(line.length() / 32.0)) + 1):
					ops.append(_t(line.substr(a * 32, 32), 0, y, BOX_W, XUI.TEXT))
					y += LH
	return ops


## 技能详情抬头（Window_ActorBookSkillHeader.refresh，内容宽 509）
static func header_ops(id: int) -> Array:
	var w := HEADER_RECT.size.x - XMVWindow.PADDING * 2
	return [_t(actor_name(id) + " · 技能详情", 0, 0, w, XUI.SYSTEM, XUI.FONT_SIZE, "center"),
		_t("上下选择技能，取消返回人物图鉴", 0, LH, w, XUI.TEXT, 18, "center")]


## Window_ActorBookSkillList.drawItem（rect：x 6、宽 内容宽 − 12）
static func list_row_ops(id: int, s: Dictionary, y: float, measure: Callable) -> Array:
	var ops := []
	var w := LIST_RECT.size.x - XMVWindow.PADDING * 2 - 12
	var mira := id == 168
	var sid := int(s.id)
	var dragon := mira and ((sid >= 10148 and sid <= 10154) or (sid >= 10161 and sid <= 10164) or sid == 10167)
	var t := int(s.stypeId)
	var type_name := "被动" if t == 4 else str(XDB.system().skillTypes[t]) if t < XDB.system().skillTypes.size() and str(XDB.system().skillTypes[t]) != "" else "其他"
	var label := "【" + ("黑龙·" if dragon else "") + type_name + "】"
	var color := XUI.text_color(14) if t == 4 else XUI.text_color(3) if t >= 1 and t <= 3 else XUI.text_color(6)
	var lw: float = measure.call(label, XUI.FONT_SIZE)
	ops.append(_t(label, 6, y, lw + 8, color))
	var preview := id in PREVIEW_ACTORS and not known_skill_ids(id).has(sid)
	var pw: float = measure.call("未解锁", XUI.FONT_SIZE) + 8 if preview else 0.0
	_item_name(ops, s, 6 + lw + 4, y, w - lw - 4 - pw)
	if preview:
		ops.append(_t("未解锁", 6 + w - pw, y, pw, XUI.text_color(7)))
	return ops


# ---- 绘制 ----
static func paint_ops(c: XMVCanvas, ops: Array) -> void:
	for o in ops:
		if o[0] == "i":
			c.icon(int(o[1]), o[2], o[3])
		else:
			c.text(o[1], o[2], o[3], o[4], o[6], o[8], o[7], o[5])


func _measure(s: String, size: int) -> float:
	return js_width(s, size)


## 浏览器 measureText 的小数字宽：GameFont 关了子像素、按整数字宽排，空格 7 而原版 7.21，九个空格一格的掌握行累计会差十几像素；
## 按 100 倍字号量再除回去（与参照读数一致到 0.01）
static func js_width(s: String, size: int) -> float:
	return XUI.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * 100).x / 100.0


func _paint_index(c: XMVCanvas) -> void:
	var names := index_names()
	if index >= top and index < top + INDEX_ROWS:
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "index")
	for i in range(top, mini(top + INDEX_ROWS, names.size())):
		c.text(names[i], 6, (i - top) * LH, c.size.x - 12)


func _paint_status(c: XMVCanvas) -> void:
	if _sprite_tex != null:
		var cw := _sprite_tex.get_width() / 9.0
		var ch := _sprite_tex.get_height() / 6.0
		var pattern: int = [0, 1, 2, 1][floori(_frame / 12.0) % 4]
		var center := SPRITE_CENTER - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		c.draw_texture_rect_region(_sprite_tex, Rect2(center - Vector2(cw, ch) / 2.0, Vector2(cw, ch)), Rect2(pattern * cw, 0, cw, ch))
	paint_ops(c, _status_ops)


func _paint_header(c: XMVCanvas) -> void:
	paint_ops(c, header_ops(index))


func _paint_list(c: XMVCanvas) -> void:
	if skill_index >= skill_top and skill_index < skill_top + LIST_ROWS:
		c.cursor(Rect2(0, (skill_index - skill_top) * LH, c.size.x, LH), mode == "skills")
	for i in range(skill_top, mini(skill_top + LIST_ROWS, skill_list.size())):
		paint_ops(c, list_row_ops(index, skill_list[i], (i - skill_top) * LH, _measure))


# ---- 操作 ----
## Scene_ActorBook.update：目录选中项变了就刷新状态窗（空槽清空）
func _select_actor() -> void:
	_status_ops = status_ops(index, _measure)
	_sprite_tex = null
	var p := sprite_path(index)
	_sprite_tex = load(p) if p != "" else null
	_refresh()


## 状态页立绘：数据库 battlerName 的 9×6 侧视图；没导出、没登记的不画。
## 米拉 168、饿狼 173、云裳 174、谷雨 175、屠苏 176、璇 177 在原版由运行模块（Codex_MiraRavenMultiFrame、installNativeGarouRuntime 等）
## 换成多帧图（参照画 UserSV_MiraHuman1_0、Codex_Garou_QHuman1_0、yunshang1_0…），重制还没移植多帧图，先不画（画数据库那张会与原版不同）。
const MULTI_FRAME_SV := [168, 173, 174, 175, 176, 177]


static func sprite_path(id: int) -> String:
	if id <= 0 or not named(id) or id in MULTI_FRAME_SV:
		return ""
	return XDB.img_path("sv_actors", str(XDB.rec("Actors", id).get("battlerName", "")))


func _refresh() -> void:
	index_win.up_arrow = top > 0
	index_win.down_arrow = top + INDEX_ROWS < actor_count()
	list_win.up_arrow = skill_top > 0
	list_win.down_arrow = skill_top + LIST_ROWS < skill_list.size()
	for w in [index_win, status_win, header_win, list_win]:
		w.refresh()


func _show_skills(on: bool) -> void:
	index_win.visible = not on
	status_win.visible = not on
	header_win.visible = on
	list_win.visible = on
	if not on:
		if HIDE_HELP_ON_RETURN or not help_card.visible:
			help_card.show_for({})
		else:
			help_card.canvas.visible = false


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	top = XMenu._scroll_to(index, top, INDEX_ROWS)
	_select_actor()


func select_skill(i: int) -> void:
	if i == skill_index:
		return
	skill_index = i
	XSound.system(0)
	skill_top = XMenu._scroll_to(skill_index, skill_top, LIST_ROWS)
	_update_help()
	_refresh()


## Window_ActorBookSkillList.updateHelp：说明卡固定在 (545, 8)
func _update_help() -> void:
	if skill_index < 0 or skill_index >= skill_list.size():
		help_card.show_for({})
		return
	var s: Dictionary = skill_list[skill_index].duplicate()
	s.note = RegEx.create_from_string("(?i)<HelpWidth:\\s*\\d+>").sub(str(s.get("note", "")), "", true)
	help_card.show_for(s, "skill", false)
	help_card.position = HELP_POS


## openActorSkillDetails：空槽蜂鸣；否则进详情（选第 0 项）
func ok() -> void:
	if mode != "index":
		return
	if index <= 0 or not named(index):
		XSound.system(3)
		return
	XSound.system(1)
	mode = "skills"
	skill_list = book_skills(index, false)
	skill_top = 0
	skill_index = 0 if not skill_list.is_empty() else -1
	_show_skills(true)
	_update_help()
	_refresh()


func cancel() -> void:
	XSound.system(2)
	if mode == "skills":
		mode = "index"
		_show_skills(false)
		_refresh()
	else:
		closed.emit()


func _move(d: int, wrap: bool) -> void:
	if mode == "index":
		select(XMenu._move(index, d, actor_count(), wrap))
	elif not skill_list.is_empty():
		select_skill(XMenu._move(skill_index, d, skill_list.size(), wrap))


## Window_Selectable.cursorPagedown/up
func _page(d: int) -> void:
	var n := actor_count() if mode == "index" else skill_list.size()
	var rows := INDEX_ROWS if mode == "index" else LIST_ROWS
	var cur := index if mode == "index" else skill_index
	var t := top if mode == "index" else skill_top
	var max_top := maxi(0, n - rows)
	if d > 0 and t + rows < n:
		t = mini(t + rows, max_top)
		cur = mini(cur + rows, n - 1)
	elif d < 0 and t > 0:
		t = maxi(t - rows, 0)
		cur = maxi(cur - rows, 0)
	else:
		return
	if mode == "index":
		top = t
		select(cur)
	else:
		skill_top = t
		select_skill(cur)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	var rect := INDEX_RECT if mode == "index" else LIST_RECT
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if rect.has_point(p):
				var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
				if mode == "index":
					top = clampi(top + d, 0, maxi(0, actor_count() - INDEX_ROWS))
				else:
					skill_top = clampi(skill_top + d, 0, maxi(0, skill_list.size() - LIST_ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			if not rect.has_point(p):
				return
			var row := floori((p.y - rect.position.y - XMVWindow.PADDING) / LH)
			if mode == "index":
				var i := top + row
				if row >= 0 and row < INDEX_ROWS and i < actor_count():
					if i == index:
						ok()
					else:
						select(i)
			else:
				var i := skill_top + row
				if row >= 0 and row < LIST_ROWS and i < skill_list.size():
					select_skill(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		get_viewport().set_input_as_handled()
		_page(1 if event.is_action_pressed("ui_page_down") else -1)
