class_name XEnemyBookPage
extends Control
## 怪物图鉴（AB_EnemyBook 的 Scene_EnemyBook，Star 改版；主菜单「怪物图鉴」＝公共事件 2 插件指令 EnemyBook open）。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/enemy_book_oracle.json，新局队伍 1/8/9/10、难度 2）：
## - 目录窗 (0,0,426,720)：图鉴里的全部敌人（有名字、无 <book:no>），行高 36、可见 19 行；「序号」(6, 宽 40)＋名字 (46, 宽 346)，
##   没登记的写「？？？？？？」。左右键翻一页。上次的光标位置在本次运行内保留（Window_EnemyBookIndex.lastIndex）。
##   达成率窗 (0,80,426,64) 原版压在目录窗下面看不见，这里不画。
## - 状态窗 (426,0,854,720)，内容宽 826：左栏名字、种族（y 36）、「出没于：」(y 64) 起每个地图名下移 26（字号），没有写「无记录」；
##   SV 图以窗口内 (213.5, 249.5) 为中心（宽超过 413 时按比例缩小；<Sideview Battler> 走角色侧视图待机 0-1-2-1 每 12 帧）；
##   右栏 x 420、半宽 185.5：击败数（y 36）、y 78 起八项能力（TP 不显示）、命中、回避、暴击、暴击闪避、魔法闪避、魔法反射、反击，
##   再接 <EnemyNote> 备注（每 15 字一行，原版循环多画一行空串）；左栏 y 258「弱化属性」、y 336「抗性属性」各一行图标
##   （每个图标上 16 号写百分比，图标多时宽度均分），y 414 起行动表前 10 条按技能品质从低到高「技能名   条件  权重:N」。
##   没登记的敌人状态窗全空。所有文字照 EnemyNameColorByDifficulty：与数据库敌人原名相同的文字改画成难度色。
## - 目录确定：已登记的打开掉落列表（盖在状态窗上，按品质从高到低、品质 0 不列，「名字   掉率%」或「【绝对掉落】」），
##   说明卡（宽 400）跟在选中行右下（Window_EnemyBookItemList.updateHelp）；确定或取消都回目录。没登记的提示「未解锁」。
## - 战斗内「怪物信息」（Scene_Battle.battleEnemyBook）：角色指令窗、技能列表、物品列表打开时按 Shift（AB_EnemyBook ShortCutButtonName）。
##   目录只列本场活着的敌人（同一 ID 一项，不写序号，名字 (6, 宽 386)）；状态窗高 1066（calcStatusWindowHeight，超出画面），
##   没登记的也画，但能力、命中等、属性、技能都写「？？？」；目录确定不做事，取消回到原来的窗口。窗口不透明度照战斗窗口。
##   队伍指令窗里的「怪物信息」「图鉴」两项：Olivia OTB 不开队伍指令窗，原版玩家点不到，不做。
## 与原版不同（O-078）：原版本想在图鉴里关掉神话（Morpho_EliteEnemy_Switch），但该参数读成 NaN 没关上，每次打开都按 50% 随机
## 把敌人显示成「【神话】」（能力 ×3.5、掉率 ×5）；这里固定按普通敌人显示，BOOK_FIXED_NORMAL 设 false 恢复原版的随机。

signal closed

## O-078：图鉴固定按普通（非神话）敌人显示；false 恢复原版随机神话
const BOOK_FIXED_NORMAL := true
const INDEX_RECT := Rect2(0, 0, 426, 720)
const STATUS_RECT := Rect2(426, 0, 854, 720)
const LH := 36.0
const ROWS := 19
const INDEX_NAME_W := 346.0                 # 内容宽 398 − 内边距 12 − 序号 40
const CW := 826.0                           # 状态窗内容宽
const COL2 := CW / 2.0 + 7.0                # 420
const COLW := CW / 2.0 - 14.0               # 399
const HALF := COLW / 2.0 - 14.0             # 185.5
const SPRITE_CENTER := Vector2(854.0 / 4.0, 854.0 / 4.0 + 36.0)
const UNKNOWN_ENEMY := "？？？？？？"
const UNKNOWN_DATA := "？？？"
const XPARAM_ROWS := [["命中率", 0], ["回避率", 1], ["暴击率", 2], ["暴击闪避率", 3], ["魔法闪避率", 4], ["魔法反射率", 5], ["反击率", 6]]

## Window_EnemyBookIndex.lastIndex：本次运行内记住上次的光标
static var last_index := 0
## 战斗内「怪物信息」的状态窗（高 = calcStatusWindowHeight）
const BATTLE_STATUS_RECT := Rect2(426, 0, 854, 1066)
## MV Bitmap.drawText 不给宽时按 0xffffffff
const NO_WIDTH := 4294967295.0

## 战斗内：只列本场敌人、不写序号、没登记也画（isAllEnemies 为假）
var in_battle := false

var ids: Array = []
var index := 0
var top := 0
var mode := "index"          # index / drops
var drop_index := -1
var drop_top := 0
var drop_list: Array = []
var index_win: XMVWindow
var status_win: XMVWindow
var drop_win: XMVWindow
var help_card: XHelpCard
var _enemies := {}
var _status_ops: Array = []
var _sprite_tex: Texture2D
var _sprite_sv := false
var _frame := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var opacity := 255 if in_battle else XUI.MENU_WINDOW_OPACITY
	if not in_battle:
		XUI.menu_background(self)
		ids = XEnemyBook.ids()
	index_win = XMVWindow.make(self, INDEX_RECT, opacity, _paint_index)
	status_win = XMVWindow.make(self, BATTLE_STATUS_RECT if in_battle else STATUS_RECT, opacity, _paint_status)
	drop_win = XMVWindow.make(self, STATUS_RECT, opacity, _paint_drops)
	index_win.canvas.blink = true
	drop_win.canvas.blink = true
	help_card = XHelpCard.new()
	help_card.show_frame = false
	add_child(help_card)
	index = 0 if in_battle else clampi(last_index, 0, maxi(0, ids.size() - 1))
	top = XMenu._scroll_to(index, 0, ROWS)
	_show_drops(false)
	_select_enemy()


func _process(_delta: float) -> void:
	# Window_EnemyBookStatus.update：侧视图每 12 帧换一格（0-1-2-1）
	_frame += 1
	if _sprite_tex != null and _sprite_sv and _frame % 12 == 0 and mode == "index":
		status_win.canvas.queue_redraw()


# ---- 数据 ----
## 战斗内「怪物信息」：Window_EnemyBookIndex.refresh 的 !isAllEnemies 分支（本场活着的敌人，按 ID 去重，<book:no> 不列）。
## 在 add_child 之前调用
func setup_battle(enemies: Array) -> void:
	in_battle = true
	ids = []
	for e in enemies:
		if e.is_alive() and str(e.data().get("meta", {}).get("book", "")) != "no" and not ids.has(e.enemy_id):
			ids.append(e.enemy_id)


## 目录用的 Game_Enemy(i, 0, 0)：本次打开内建一次
func enemy(id: int) -> XEnemy:
	if not _enemies.has(id):
		_enemies[id] = new_enemy(id)
	return _enemies[id]


static func new_enemy(id: int) -> XEnemy:
	var s := XState.current
	return XEnemy.new().setup(id, s.difficulty if s != null else 2, 100.0 if BOOK_FIXED_NORMAL else -1.0)


static func _difficulty() -> int:
	return XState.current.difficulty if XState.current != null else 2


## Window_EnemyBookIndex.drawItem：登记过的写名字（Game_Enemy.name，神话带前缀）
func index_name(i: int) -> String:
	var id: int = ids[i]
	return enemy(id).display_name() if in_battle or XEnemyBook.registered(XState.current, id) else UNKNOWN_ENEMY


## JS Number.prototype.toString（最短往返小数，整数不带小数点）
static func js_num(v: float) -> String:
	if is_nan(v):
		return "NaN"
	if v == floorf(v) and absf(v) < 1.0e21:
		return "%d" % int(v) if absf(v) < 9.0e18 else "%.0f" % v
	for d in range(1, 18):
		var t := String.num(v, d)
		if t.to_float() == v:
			return t
	return str(v)


## 文字操作 ["t", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色]；图标 ["i", 图标号, x, y]（与参照 JSON 同形）。
## EnemyNameColorByDifficulty 改的是 Bitmap.drawText：任何与敌人原名相同的文字都换成难度色
static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT, align := "left", size: float = XUI.FONT_SIZE) -> Array:
	return ["t", text, x, y, w, LH, align, size, XEnemy.name_color(text, _difficulty(), color)]


## YEP notetags：备注按换行切（连续换行算一个）
static func notetags(note: String) -> PackedStringArray:
	return RegEx.create_from_string("[\\r\\n]+").sub(note, "\n", true).split("\n")


static func race_name(n: int) -> String:
	var names = JSON.parse_string(str(XDB.plugin("Star_EnemyRace").get("EnemyRaceName", "[]")))
	return str(names[n - 1]) if names is Array and n >= 1 and n - 1 < names.size() else "undefined"


## AB_EnemyBook 参数 ElementIcons（前面补 0，按属性 ID 取）
static func element_icon(e: int) -> int:
	var icons := ("0 " + str(XDB.plugin("AB_EnemyBook").get("ElementIcons", ""))).split(" ", false)
	return int(icons[e]) if e < icons.size() else 0


## 行动条件文字（Star 改的 drawAllContents）
static func action_text(a: Dictionary) -> String:
	var p1 := float(a.get("conditionParam1", 0))
	var p2 := float(a.get("conditionParam2", 0))
	var text := ""
	match int(a.get("conditionType", 0)):
		0: text = "平时"
		1: text = "回合:" + js_num(p1) + (("~回合:" + js_num(p2) + "* N") if p2 > 0 else "")
		2: text = "HP比例:" + js_num(p1 * 100) + "%~" + js_num(p2 * 100) + "%"
		3: text = "MP比例:" + js_num(p1 * 100) + "%~" + js_num(p2 * 100) + "%"
		4: text = "状态: " + str(XDB.rec("States", int(p1)).get("name", ""))
		5: text = "玩家队伍最高等级达到:" + js_num(p1)
		6:
			var sw: Array = XDB.system().get("switches", [])
			text = "开关: " + (str(sw[int(p1)]) if int(p1) < sw.size() else "undefined") + "  开启"
	return text + "  权重:" + js_num(float(a.get("rating", 0)))


## 弱化（rate > 1）／抗性（rate < 1）属性一行：标题 systemColor，下一行图标，图标上 dx/2 号字写百分比
static func _element_row(ops: Array, e: XEnemy, y: float, weak: bool, hide := false) -> void:
	var icons := []
	var n: int = (XDB.system().get("elements", []) as Array).size()
	for i in range(1, n):
		var rate := e.element_rate(i)
		if (rate > 1.0 if weak else rate < 1.0):
			var icon := element_icon(i)
			if icon > 0:
				icons.append([icon, rate])
	ops.append(_t("弱化属性" if weak else "抗性属性", 0, y, COLW, XUI.SYSTEM))
	if hide:
		ops.append(_t(UNKNOWN_DATA, 0, y + LH, NO_WIDTH))
		return
	var dx := 32.0
	if 32.0 * icons.size() > COLW:
		dx = floorf(COLW / icons.size())
	var x := 0.0
	for ic in icons:
		ops.append(["i", ic[0], x, y + LH])
		var pct: float = ic[1] * 100.0 - 100.0 if weak else 100.0 - ic[1] * 100.0
		ops.append(_t(js_num(pct) + "%", x, y + LH, dx, XUI.TEXT, "left", dx / 2.0))
		x += dx


## Window_EnemyBookStatus.drawAllContents 的全部绘制（没登记的不画）
## all：图鉴（isAllEnemies）——没登记的整窗不画；战斗内「怪物信息」为假——照画，数值写「？？？」（isHideStatus）
static func status_ops(e: XEnemy, all := true) -> Array:
	var ops := []
	var s := XState.current
	if e == null or (all and not XEnemyBook.registered(s, e.enemy_id)):
		return ops
	var hide := not XEnemyBook.registered(s, e.enemy_id)
	var d := e.data()
	ops.append(_t(e.display_name(), 0, 0, COLW))
	var y11 := 64.0
	ops.append(_t("出没于：", 0, y11, COLW))
	var maps := XEnemyBook.record_maps(s, e.enemy_id)
	if maps.is_empty():
		y11 += XUI.FONT_SIZE
		ops.append(_t("无记录", 0, y11, COLW))
	for m in maps:
		if str(m) != "":
			y11 += XUI.FONT_SIZE
			ops.append(_t(str(m), 0, y11, COLW))
	var tags := notetags(str(d.get("note", "")))
	var race_re := RegEx.create_from_string("(?i)<ENEMYRACE: (\\d+)>")
	for line in tags:
		var m := race_re.search(line)
		if m != null:
			ops.append(_t("种族: " + race_name(int(m.get_string(1))), 0, LH, COLW))
	# 右栏：等级（不显示，只占一行）、击败数、能力
	var x := COL2
	var y := LH
	ops.append(_t("击败数", x, y, HALF))
	ops.append(_t(str(XEnemyBook.defeat_number(s, e.enemy_id)), x + HALF, y, HALF, XUI.TEXT, "right"))
	y += LH + 6.0
	var terms: Array = XDB.system().get("terms", {}).get("params", [])
	for i in 8:
		ops.append(_t(str(terms[i]) if i < terms.size() else "", x, y, HALF, XUI.SYSTEM))
		ops.append(_t(UNKNOWN_DATA if hide else js_num(e.param(i)), x + HALF, y, HALF, XUI.TEXT, "right"))
		y += LH
	for r in XPARAM_ROWS:
		ops.append(_t(r[0], x, y, HALF, XUI.SYSTEM))
		ops.append(_t(UNKNOWN_DATA if hide else js_num(floorf(e.xparam(r[1]) * 100.0)) + "%", x + HALF, y, HALF, XUI.TEXT, "right"))
		y += LH
	var in_note := false
	for line in tags:
		if line == "<EnemyNote>" or in_note:
			in_note = true
			if line == "</EnemyNote>":
				in_note = false
			elif line != "<EnemyNote>":
				for a in range(0, ceili(line.length() / 15.0) + 1):
					ops.append(_t(line.substr(a * 15, 15) if a * 15 < line.length() else "", x, y, COLW))
					y += LH
	# 左栏：属性、技能
	y = LH * 7 + 6.0
	_element_row(ops, e, y, true, hide)
	y += LH * 2 + 6.0
	_element_row(ops, e, y, false, hide)
	y += LH * 2 + 6.0
	var buckets := []
	buckets.resize(14)
	for b in 14:
		buckets[b] = []
	var actions: Array = d.get("actions", [])
	for i in mini(10, actions.size()):
		var sk := XDB.rec("Skills", int(actions[i].skillId))
		var q := int(str(sk.get("meta", {}).get("quality", "0"))) if str(sk.get("meta", {}).get("quality", "")).is_valid_int() else 0
		buckets[clampi(q, 0, 13)].append([sk, action_text(actions[i])])
	for b in buckets:
		for pair in b:
			var sk: Dictionary = pair[0]
			if hide:
				ops.append(_t(UNKNOWN_DATA, 0, y, COLW))
				y += LH
				continue
			# Window_Base.drawItemName 不论图标号都画（0 号是空格）
			ops.append(["i", int(sk.get("iconIndex", 0)), 2.0, y + 2])
			ops.append(_t(str(sk.get("name", "")) + "   " + pair[1], 36, y, COLW - 36, XQuality.list_color(sk)))
			y += LH
	return ops


## Window_EnemyBookItemList.makeItemList：品质从高到低（品质 0 不列），名字后接掉率
static func drop_rows(e: XEnemy) -> Array:
	var out := []
	var s := XState.current
	# Game_Enemy.dropItemRate：双倍掉落 ? 1 : 0.2，× 神话掉率 × 全队掉率（同地图传送预览，见 XMapTransfer）
	var base := (1.0 if XMapTransfer.has_drop_item_double(s) else 0.2) * e.drop_rate_bonus() * XMapTransfer.team_drop_factor(s)
	for r in XMapTransfer.drops(s, e.data(), base):
		var q := XMapTransfer.quality(r.item)
		if q <= 0 or q > 13:
			continue
		var pct := float(r.rate)
		var item: Dictionary = r.item.duplicate()
		item.name = str(item.get("name", "")) + "   " + ("【绝对掉落】" if pct >= 100 else js_num(pct) + "%")
		out.append({"kind": r.type.to_lower(), "id": r.id, "item": item, "base": r.item})
	return out


static func drop_row_ops(row: Dictionary, y: float) -> Array:
	var ops := []
	var it: Dictionary = row.item
	ops.append(["i", int(it.get("iconIndex", 0)), 2.0, y + 2])
	var w := CW - 6.0 - XActorBook.js_width("000", XUI.FONT_SIZE)
	ops.append(_t(str(it.name), 36, y, w - 36, XQuality.list_color(row.base)))
	# CP_MagicWeapon drawItemName：法宝在图标上写等级（drawLevelOnIcon：x+2+16−2、y+2−8，宽 textWidth("00")，靠右）
	var lv = XEquipmentView.level(row.base)
	if lv is float and lv >= 0.0:
		var p := XDB.plugin("CP_MagicWeapon")
		var size := float(str(p.get("Level Font Size", "16")))
		ops.append(_t(js_num(lv), 16, y - 6, XActorBook.js_width("00", int(size)), XUI.text_color(int(str(p.get("Level Font Color", "12")))), "right", size))
	return ops


# ---- 绘制 ----
func _paint_index(c: XMVCanvas) -> void:
	if index >= top and index < top + ROWS:
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "index")
	for i in range(top, mini(top + ROWS, ids.size())):
		var y := (i - top) * LH
		if in_battle:
			XActorBook.paint_ops(c, [_t(index_name(i), 6, y, INDEX_NAME_W + 40)])
		else:
			XActorBook.paint_ops(c, [_t(str(i + 1), 6, y, 40), _t(index_name(i), 46, y, INDEX_NAME_W)])


func _paint_status(c: XMVCanvas) -> void:
	if _sprite_tex != null:
		var center := SPRITE_CENTER - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		var src := Rect2(Vector2.ZERO, _sprite_tex.get_size())
		if _sprite_sv:
			var cw := _sprite_tex.get_width() / 9.0
			var ch := _sprite_tex.get_height() / 6.0
			var pattern: int = [0, 1, 2, 1][floori(_frame / 12.0) % 4]
			src = Rect2(pattern * cw, 0, cw, ch)
		var scale := 1.0
		if src.size.x > CW / 2.0:
			scale = CW / src.size.x / 2.0
		var sz := src.size * scale
		c.draw_texture_rect_region(_sprite_tex, Rect2(center - sz / 2.0, sz), src)
	XActorBook.paint_ops(c, _status_ops)


func _paint_drops(c: XMVCanvas) -> void:
	var rows := floori((STATUS_RECT.size.y - XMVWindow.PADDING * 2) / LH)
	if drop_index >= drop_top and drop_index < drop_top + rows:
		c.cursor(Rect2(0, (drop_index - drop_top) * LH, c.size.x, LH), mode == "drops")
	for i in range(drop_top, mini(drop_top + rows, drop_list.size())):
		XActorBook.paint_ops(c, drop_row_ops(drop_list[i], (i - drop_top) * LH))


# ---- 操作 ----
## 目录选中项变了就刷新状态窗（Window_EnemyBookIndex.updateStatus）
func _select_enemy() -> void:
	_sprite_tex = null
	_sprite_sv = false
	if ids.is_empty():
		_status_ops = []
		_refresh()
		return
	var e := enemy(ids[index])
	_status_ops = status_ops(e, not in_battle)
	if not _status_ops.is_empty():
		var side := str(e.data().get("meta", {}).get("Sideview Battler", "")).strip_edges()
		if side != "":
			var p := XDB.img_path("sv_actors", side)
			_sprite_tex = load(p) if p != "" else null
			_sprite_sv = _sprite_tex != null
		else:
			_sprite_tex = XMapTransfer.enemy_texture(e.data())
	_refresh()


func _refresh() -> void:
	index_win.up_arrow = top > 0
	index_win.down_arrow = top + ROWS < ids.size()
	for w in [index_win, status_win, drop_win]:
		w.refresh()


## MV WindowLayer 会把后建的窗口范围从前面的窗口里挖掉：掉落列表打开时状态窗整片被盖住
func _show_drops(on: bool) -> void:
	drop_win.visible = on
	status_win.visible = not on
	if not on:
		help_card.show_for({})


func select(i: int) -> void:
	if i == index or ids.is_empty():
		return
	index = i
	XSound.system(0)
	top = XMenu._scroll_to(index, top, ROWS)
	_select_enemy()


func select_drop(i: int) -> void:
	if i == drop_index:
		return
	drop_index = i
	XSound.system(0)
	drop_top = XMenu._scroll_to(drop_index, drop_top, floori((STATUS_RECT.size.y - XMVWindow.PADDING * 2) / LH))
	_update_help()
	_refresh()


## Window_EnemyBookItemList.updateHelp：说明卡放在选中行右下，超出画面就靠右／靠下；
## 末尾 HEw.hide() 再 visible=true，品质外框与技能书附卡都被移除，只留卡本体
func _update_help() -> void:
	if drop_index < 0 or drop_index >= drop_list.size():
		help_card.show_for({})
		return
	var row: Dictionary = drop_list[drop_index]
	help_card.show_for(row.base, row.kind, false)
	var ry := (drop_index - drop_top) * LH
	var sx := STATUS_RECT.position.x + CW - 4.0
	var sy := STATUS_RECT.position.y + ry + LH - 4.0
	if sx + help_card.size.x > 1280:
		sx = 1280 - help_card.size.x
	if sy + help_card.size.y > 720:
		sy = 720 - help_card.size.y - 4
	help_card.position = Vector2(sx, sy)


## Scene_EnemyBook.onRangeOk：登记过的打开掉落列表，否则提示「未解锁」
func ok() -> void:
	if in_battle:
		return
	if mode == "drops":
		_close_drops()
		return
	if ids.is_empty():
		return
	if not XEnemyBook.registered(XState.current, ids[index]):
		XToast.show_text("未解锁", true)
		return
	XSound.system(1)
	mode = "drops"
	drop_list = drop_rows(enemy(ids[index]))
	drop_top = 0
	drop_index = 0 if not drop_list.is_empty() else -1
	_show_drops(true)
	_update_help()
	_refresh()


## onEqListCancel：关掉列表回目录
func _close_drops() -> void:
	mode = "index"
	drop_index = -1
	_show_drops(false)
	_refresh()


func cancel() -> void:
	XSound.system(2)
	if mode == "drops":
		_close_drops()
	else:
		if not in_battle:
			last_index = index
		closed.emit()


func _move(d: int, wrap: bool) -> void:
	if mode == "index":
		select(XMenu._move(index, d, ids.size(), wrap))
	elif not drop_list.is_empty():
		select_drop(XMenu._move(drop_index, d, drop_list.size(), wrap))


## Window_EnemyBookIndex.cursorRight／Left：跳一页（不回绕）
func _page_jump(d: int) -> void:
	if mode != "index" or ids.is_empty():
		return
	select(clampi(index + d * ROWS, 0, ids.size() - 1))


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	var rect := INDEX_RECT if mode == "index" else STATUS_RECT
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "index" and rect.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, ids.size() - ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			if not rect.has_point(p):
				return
			var row := floori((p.y - rect.position.y - XMVWindow.PADDING) / LH)
			if mode == "index":
				var i := top + row
				if row >= 0 and row < ROWS and i < ids.size():
					if i == index:
						ok()
					else:
						select(i)
			else:
				var i := drop_top + row
				if row >= 0 and i < drop_list.size():
					if i == drop_index:
						ok()
					else:
						select_drop(i)


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
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_page_jump(1 if event.is_action_pressed("ui_right", true) else -1)
