class_name XFestLobby
extends Node2D
## 【cc·未经审查】冠军庆典·大厅庆典叠加层＋庆典使者／报名处／奖杯（Kyo 11-15；方案 重制设定/冠军庆典活动_v0.2.md 2.1、2.2、2.6、2.7 节；O-466）。
##
## 两部分，都只在活动期间才存在（XFest.active()／visible()，开关 ENABLED 或 XFest.ENABLED 关掉＝整个不存在、没有任何痕迹）：
## 1. 叠加层（本类的实例，只在方桌大厅 Map004 建，换图释放）：横幅、彩旗、奖杯贴图、彩带与烟花粒子。不改地图图块与通行。
##    横幅、奖杯用 content/fest/ 里 co 画的正式图（Fest_Banner.png、Fest_Trophy.png、Fest_Confetti_01～04.png），
##    没有图（或测试置空）照旧程序画。彩带烟花跟「画面特效」开关和省电模式走，关了就不放。
## 2. 地图补丁（XDB.map 读 Map004 时追加 4 个事件，编号 78～81）：庆典使者（活动中和收尾期）、报名处与奖杯两格（只在活动中）。
##    事件指令是一行 355 脚本「CodexFest.xxx();」，由 MVScript 转交本类的 run_script。
##    活动期间大厅 BGM 也在补丁里换成现成曲子（BGM），不引入新音乐文件。
##
## 位置（Map004，格）：全在漩涡中心 (14,19) 的 6 格圈外（方案 2.1，不压异化层的地盘）：东侧一排，报名处 (20,17)、奖杯占 (21,17)(22,17)、使者 (23,17)。
## 横幅挂在大厅南段（行 23～24，x 264～1032 像素），进大厅第一眼就看到；彩旗挂在横幅上沿。
## 和大厅异化层（XLobbyCorruption）不冲突：两层各有各的开关，浮砖等随机选格避开有事件的格。

## O-466：大厅庆典整套（叠加层＋NPC＋BGM）；false＝大厅回到没有活动时的样子
static var ENABLED := true
const MAP_ID := 4
const TS := 48

## 新增事件编号（Map004 原有 1～77）
const FIRST_EV := 78
const ENVOY_EV := 78
const ENROLL_EV := 79
const TROPHY_EVS := [80, 81]
const ENVOY_CELL := Vector2i(23, 17)
const ENROLL_CELL := Vector2i(20, 17)
const TROPHY_CELLS := [Vector2i(21, 17), Vector2i(22, 17)]
## 使者、报名处的行走图（现成的：文件名、第几个角色，朝下）
const ENVOY_SPRITE := ["People14", 2]
const ENROLL_SPRITE := ["People13", 5]

## 活动期间大厅 BGM（现成的，slice 里有；"" 不换）。备选：Number One、MVre_Town1、Town_real2_mvt（Kyo 听过再定）
static var BGM := "MZre_Town1"

## 美术（co 11-15 交，content/fest/）：有图用图；测试置空走程序画
static var ART_DIR := "res://content/fest/"
const BANNER_FILE := "Fest_Banner.png"
const TROPHY_FILE := "Fest_Trophy.png"
const CONFETTI_FILES := ["Fest_Confetti_01.png", "Fest_Confetti_02.png", "Fest_Confetti_03.png", "Fest_Confetti_04.png"]
## 横幅（768×96）左上角的像素位置与奖杯脚底中心（96×144，脚底 (48,142)）
const BANNER_SIZE := Vector2(768, 96)
const BANNER_POS := Vector2(264, 23 * TS)
## co 给的字的安全区（图内像素）：x1, y1, x2, y2
const BANNER_TEXT_RECT := Rect2(110, 20, 548, 38)
const TROPHY_FOOT := Vector2(22 * TS, 18 * TS)   # 奖杯脚底中心（占 21、22 两列、行 17 的下沿）
const TROPHY_ANCHOR := Vector2(48, 142)

const MAX_CONFETTI := 46
const FIREWORK_GAP_MIN := 5.0
const FIREWORK_GAP_MAX := 9.0
const BUNTING_COLORS := [Color(0.86, 0.14, 0.17), Color(0.98, 0.78, 0.2), Color(0.96, 0.96, 0.96), Color(0.2, 0.45, 0.85)]
const GOLD := Color(0.98, 0.78, 0.2)
const RED := Color(0.72, 0.08, 0.12)

## 庆典使者菜单的附加项：第 2 天的签到、兑换往这里加，不改本文件。每项 {"label": 文字, "call": Callable(interp) 协程}
static var EXTRA_MENU: Array = []
## 报名处的入口（甲车道的冠军之路）：全局类 XFestRoad 有静态方法 enter(interp) 时调它；没有就放占位对话
static var ROAD_CLASS := "XFestRoad"
const ROAD_METHOD := "enter"

## 贺礼（v0.3.1 2.4，发放在 XFestReward.gift；这里只留总数给说明和测试看）：庆典币、精魂；另有副本挑战符文 ×2、肝帝积分抽奖券 ×10
const GIFT := {"coins": XFestReward.GIFT_COINS, "gold": XFestReward.GIFT_GOLD}

var host: XMapScene
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _banner_node: Node2D
var _bunting_node: Node2D
var _trophy_node: Node2D
var _fx_node: Node2D
var _banner_tex: Texture2D
var _trophy_tex: Texture2D
var _confetti_tex: Array = []
var _confetti: Array = []     # {p, v, rot, spin, tex(index), col, life}
var _rockets: Array = []      # 升空中 {p, v, life}
var _sparks: Array = []       # 迸发的火花 {p, v, a, col, life}
var _next_firework := 3.0


# ============ 开关与日期 ============

## 叠加层、使者等要不要存在（开关＋日期都在 XFest 里）
static func wanted() -> bool:
	return ENABLED and XFest.visible()


## 大厅装饰（横幅、彩旗、奖杯、粒子、BGM、报名处）：只在活动进行中
static func decor() -> bool:
	return ENABLED and XFest.active()


## 地图缓存里的 Map004 是读图时按当时的开关做的补丁；测试或开关变了要清缓存才重读
static func reload_map() -> void:
	XDB._tables.erase("map:%d" % MAP_ID)


static var _cache_stamp := ""


## 地图缓存里的 Map004 是读图时按当时的开关与日期做的补丁；状态变了（跨过活动起止日、开关切换）要作废重读。XDB.map 每次读大厅都问一下
static func cache_stale() -> bool:
	var stamp := "%s|%s|%s" % [wanted(), decor(), BGM]
	if stamp == _cache_stamp:
		return false
	_cache_stamp = stamp
	return true


static func fx_on() -> bool:
	return XGraphics.fx_on()  # 「画面特效」开着且没开省电模式


# ============ 地图补丁（XDB.map 调）============

static func _event(id: int, name: String, cell: Vector2i, image: Array, script: String) -> Dictionary:
	var cond := {"actorId": 1, "actorValid": false, "itemId": 1, "itemValid": false, "selfSwitchCh": "A", "selfSwitchValid": false,
		"switch1Id": 1, "switch1Valid": false, "switch2Id": 1, "switch2Valid": false, "variableId": 1, "variableValid": false, "variableValue": 0}
	var page := {"conditions": cond, "directionFix": false,
		"image": {"tileId": 0, "characterName": str(image[0]), "direction": 2, "pattern": 1, "characterIndex": int(image[1])},
		"list": [{"code": 355, "indent": 0, "parameters": [script]}, {"code": 0, "indent": 0, "parameters": []}],
		"moveFrequency": 3, "moveRoute": {"list": [{"code": 0, "parameters": []}], "repeat": true, "skippable": false, "wait": false},
		"moveSpeed": 3, "moveType": 0, "priorityType": 1, "stepAnime": false, "through": false, "trigger": 0, "walkAnime": true}
	return {"id": id, "name": name, "note": "<CodexFest>", "pages": [page], "x": cell.x, "y": cell.y}


## XDB.map 读 Map004 时：追加使者（活动中和收尾期）、报名处和奖杯两格（只活动中），活动中换大厅 BGM；开关关了或不在日期内一个字节都不改
static func patch_map(map_id: int, data) -> void:
	if map_id != MAP_ID or not wanted() or not (data is Dictionary):
		return
	var events: Array = data.get("events", [])
	if events.size() > FIRST_EV:
		return  # 编号被占了（来源变了）：不动
	while events.size() < FIRST_EV:
		events.append(null)
	events.append(_event(ENVOY_EV, XFestText.ENVOY_NAME, ENVOY_CELL, ENVOY_SPRITE, "CodexFest.envoy();"))
	if decor():
		events.append(_event(ENROLL_EV, XFestText.ENROLL_NAME, ENROLL_CELL, ENROLL_SPRITE, "CodexFest.enroll();"))
		for i in TROPHY_EVS.size():
			events.append(_event(TROPHY_EVS[i], "庆典奖杯", TROPHY_CELLS[i], ["", 0], "CodexFest.trophy();"))
		if BGM != "" and XDB.audio_path("bgm", BGM) != "":
			var bgm: Dictionary = data.get("bgm", {}).duplicate() if data.get("bgm") is Dictionary else {}
			bgm["name"] = BGM
			if not bgm.has("volume"):
				bgm["volume"] = 90
			data["bgm"] = bgm
			data["autoplayBgm"] = true


## 切片 keepEvents 之外也要放进地图的事件（map_scene 载入事件时问）
static func keep_event(map_id: int, ev_id: int) -> bool:
	if map_id != MAP_ID or not wanted():
		return false
	if ev_id == ENVOY_EV:
		return true
	return decor() and (ev_id == ENROLL_EV or TROPHY_EVS.has(ev_id))


# ============ 脚本入口（MVScript 转交）============

## 355 脚本「CodexFest.envoy();」「CodexFest.enroll();」「CodexFest.trophy();」
static func run_script(js: String, interp) -> void:
	var m := RegEx.create_from_string("^CodexFest\\.(\\w+)\\(\\);?$").search(js.strip_edges())
	if m == null or not interp.host_alive():
		return
	match m.get_string(1):
		"envoy":
			await envoy(interp)
		"enroll":
			await enroll(interp)
		"trophy":
			await trophy(interp)


## 一段台词 [[说话人, 文字], …] 逐条放出
static func say(interp, lines: Array) -> void:
	for row in lines:
		if not interp.host_alive():
			return
		var rows := str(row[1]).split("\n")
		var shown: Array = []
		for i in rows.size():
			shown.append(("\\n<%s>%s" % [row[0], rows[i]]) if i == 0 and str(row[0]) != "" else rows[i])
		await interp.host.show_message({"face": "", "index": 0, "background": 0, "position": 2, "lines": shown})


## 选项窗口：返回选中序号，取消 -1
static func choose(interp, options: Array) -> int:
	if not interp.host_alive():
		return -1
	return await interp.host.show_message({"face": "", "index": 0, "background": 0, "position": 2, "lines": [], "choices": options, "cancel": options.size() - 1, "default": 0, "choice_position": 2, "choice_background": 0})


static func team_lines() -> Array:
	var out: Array = []
	for t in XFestText.TEAMS:
		out.append(["", "【%s】%s\n%s" % [t.name, t.tag, t.intro]])
	return out


static func trophy(interp) -> void:
	var s := XState.current
	var d := XFest.data(s)
	var n := int(d.get("trophy_looks", 0))
	d["trophy_looks"] = n + 1
	await say(interp, [XFestText.TROPHY_TEXTS[n % XFestText.TROPHY_TEXTS.size()]])


## 庆典使者：第一次＝贺词＋贺礼＋介绍；之后出菜单（签到、兑换店由 XFestReward.menu 加）；收尾期只说收尾话、留兑换。
## 天启篇存档（v0.3.1 第 4 节）：只送纪念称号「冠军观赛团」和成就「我在现场」，不开签到、兑换店
static func envoy(interp) -> void:
	var s := XState.current
	if s == null:
		return
	var d := XFest.data(s)
	if XFestReward.tianqi(s):
		d["envoy_met"] = true
		if bool(d.get("envoy_gift", false)):
			await say(interp, XFestText.ENVOY_TIANQI_AGAIN)
			return
		await say(interp, XFestText.ENVOY_TIANQI)
		interp.host.toast(XFestReward.tianqi_gift(s))
		return
	if XFest.in_grace():
		var has_menu := not EXTRA_MENU.is_empty() or not XFestReward.menu(s).is_empty()
		await say(interp, XFestText.ENVOY_GRACE if has_menu else XFestText.ENVOY_GRACE_NONE)
		if has_menu:
			await _menu(interp, false)
		return
	d["envoy_met"] = true
	XFestReward.achieve(s, "scene")   # 成就「我在现场」
	if not bool(d.get("envoy_gift", false)):
		await say(interp, XFestText.ENVOY_FIRST)
		var toast := give_gift(s)
		interp.host.toast(toast)
		await say(interp, XFestText.ENVOY_INTRO if road_ready() else XFestText.ENVOY_INTRO_SOON)
		return
	await say(interp, XFestText.ENVOY_AGAIN)
	await _menu(interp, true)


static func _menu(interp, with_info: bool) -> void:
	while interp.host_alive():
		var options: Array = []
		var acts: Array = []
		if with_info:
			options.append(XFestText.ENVOY_MENU_ROAD)
			acts.append("road")
			options.append(XFestText.ENVOY_MENU_TEAMS)
			acts.append("teams")
		for e in XFestReward.menu(XState.current):
			options.append(str(e.label))
			acts.append(e)
		for e in EXTRA_MENU:
			options.append(str(e.label))
			acts.append(e)
		options.append(XFestText.ENVOY_MENU_BYE)
		var r := await choose(interp, options)
		if r < 0 or r >= acts.size():
			if with_info:
				await say(interp, XFestText.ENVOY_BYE)
			return
		var act = acts[r]
		if act is String and act == "road":
			await say(interp, XFestText.ENVOY_ROAD_INFO if road_ready() else XFestText.ENVOY_ROAD_INFO_SOON)
		elif act is String and act == "teams":
			await say(interp, team_lines())
		elif act is Dictionary and act.has("act"):
			await XFestReward.run_menu(interp, str(act.act))
		else:
			await (act.call as Callable).call(interp)


## 贺礼：每个存档一次；返回提示条文字（XFestReward.gift；天启篇存档改发纪念品）
static func give_gift(s: XState) -> String:
	return XFestReward.tianqi_gift(s) if XFestReward.tianqi(s) else XFestReward.gift(s)


## 报名处：问候 → 报名（进甲车道的冠军之路）／看战队／再想想
static func enroll(interp) -> void:
	if _road() == null:
		await say(interp, XFestText.ENROLL_SOON)   # 冠军之路还没开放：只说敬请期待，不放占位战斗
		return
	await say(interp, XFestText.ENROLL_GREET)
	while interp.host_alive():
		var r := await choose(interp, [XFestText.ENROLL_MENU_GO, XFestText.ENROLL_MENU_TEAMS, XFestText.ENROLL_MENU_BYE])
		if r == 0:
			var road = _road()
			if road != null:
				await road.call(ROAD_METHOD, interp)
			else:
				await say(interp, XFestText.ENROLL_SOON)
			return
		if r == 1:
			await say(interp, team_lines())
			continue
		await say(interp, XFestText.ENROLL_BYE)
		return


## 冠军之路开放了没有（入口类在、有 enter 方法、没把自己的 ENABLED 关掉）
static func road_ready() -> bool:
	return _road() != null


## 甲车道的入口类；没合进来（没有 enter 方法、或 ENABLED 关着）返回 null。按全局类表动态取，两边谁先合进来都能编译
static func _road() -> Variant:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == ROAD_CLASS:
			var scr = load(str(c.path))
			if scr != null and scr.get_script_method_list().any(func(m): return m.name == ROAD_METHOD):
				var on = scr.get("ENABLED")   # 入口类自己的开关（静态变量；没有这个变量就当开着）
				if on != null and not bool(on):
					return null
				return scr
			return null
	return null


# ============ 叠加层（实例）============

static func tex_of(file: String) -> Texture2D:
	if ART_DIR == "" or file == "":
		return null
	var p := ART_DIR + file
	return load(p) if ResourceLoader.exists(p) else null


func setup(map: XMapScene) -> void:
	host = map
	name = "FestLobby"
	z_index = 20   # 粒子在上层图块之上
	rng.randomize()
	_banner_tex = tex_of(BANNER_FILE)
	_trophy_tex = tex_of(TROPHY_FILE)
	for f in CONFETTI_FILES:
		var t := tex_of(f)
		if t != null:
			_confetti_tex.append(t)
	# 横幅、彩旗、奖杯放进角色层（按 y 排序）：横幅与彩旗以上沿排序，人走过时踩在上面；奖杯以脚底排序，人走到后面被挡住
	_banner_node = _deco(Vector2(0, BANNER_POS.y), _draw_banner)
	_bunting_node = _deco(Vector2(0, BANNER_POS.y - 1), _draw_bunting)
	_trophy_node = _deco(Vector2(0, TROPHY_FOOT.y), _draw_trophy)
	_fx_node = Node2D.new()
	_fx_node.draw.connect(_draw_fx)
	add_child(_fx_node)
	_seed_confetti()


func _deco(pos: Vector2, cb: Callable) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.draw.connect(cb.bind(n))
	host.chars.add_child(n)
	return n


func _exit_tree() -> void:
	for n in [_banner_node, _bunting_node, _trophy_node]:
		if is_instance_valid(n):
			n.queue_free()


## ---- 横幅：底图＋字 ----

func _draw_banner(n: Node2D) -> void:
	var r := Rect2(BANNER_POS.x, 0, BANNER_SIZE.x, BANNER_SIZE.y)
	if _banner_tex != null:
		n.draw_texture(_banner_tex, r.position)
	else:
		# 程序画的占位：红底金边、两头垂尾
		n.draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(r.size.x, r.size.y - 18)), RED)
		n.draw_rect(Rect2(r.position + Vector2(0, 0), Vector2(r.size.x, r.size.y - 18)), GOLD, false, 4.0)
		for sx in [r.position.x + 24.0, r.end.x - 24.0 - 34.0]:
			n.draw_colored_polygon(PackedVector2Array([Vector2(sx, r.size.y - 18), Vector2(sx + 34, r.size.y - 18), Vector2(sx + 34, r.size.y), Vector2(sx + 17, r.size.y - 8), Vector2(sx, r.size.y)]), RED)
	var rect := Rect2(r.position + BANNER_TEXT_RECT.position, BANNER_TEXT_RECT.size)
	var font := XUI.font()
	var text := XFestText.BANNER
	var size := 26
	while size > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
		size -= 1
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(rect.position.x + (rect.size.x - w) / 2.0, rect.position.y + rect.size.y / 2.0 + size * 0.36)
	n.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.35, 0.02, 0.05))
	n.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.9, 0.55))


## ---- 彩旗：横幅上沿一条下垂的线，挂三角小旗 ----

func _draw_bunting(n: Node2D) -> void:
	var x0 := BANNER_POS.x
	var x1 := BANNER_POS.x + BANNER_SIZE.x
	var y0 := -8.0   # 横幅上沿再往上一点（节点在上沿 −1）
	var sag := 9.0
	var step := 32.0
	var count := int((x1 - x0) / step)
	var prev := Vector2(x0, y0)
	for i in range(1, count + 1):
		var x := x0 + i * step
		var k := float(i) / count
		var y := y0 + sag * 4.0 * k * (1.0 - k)
		var cur := Vector2(x, y)
		n.draw_line(prev, cur, Color(0.3, 0.22, 0.12), 1.5)
		var mid := (prev + cur) / 2.0
		var col: Color = BUNTING_COLORS[i % BUNTING_COLORS.size()]
		var sway := sin(_t * 2.0 + i) * 1.5
		n.draw_colored_polygon(PackedVector2Array([mid + Vector2(-9, 0), mid + Vector2(9, 0), mid + Vector2(sway, 17)]), col)
		prev = cur


## ---- 奖杯 ----

func _draw_trophy(n: Node2D) -> void:
	if _trophy_tex != null:
		var top_left := Vector2(TROPHY_FOOT.x, 0) - TROPHY_ANCHOR
		# 节点在脚底行，向上画
		n.draw_texture(_trophy_tex, Vector2(top_left.x, -TROPHY_ANCHOR.y))
		return
	# 占位：金色杯身＋木底座
	var cx := TROPHY_FOOT.x
	n.draw_rect(Rect2(cx - 40, -22, 80, 22), Color(0.42, 0.26, 0.12))
	n.draw_rect(Rect2(cx - 40, -22, 80, 22), Color(0.2, 0.12, 0.05), false, 2.0)
	n.draw_rect(Rect2(cx - 8, -60, 16, 38), GOLD.darkened(0.15))
	n.draw_colored_polygon(PackedVector2Array([Vector2(cx - 34, -128), Vector2(cx + 34, -128), Vector2(cx + 22, -66), Vector2(cx - 22, -66)]), GOLD)
	n.draw_arc(Vector2(cx - 36, -104), 12, PI * 0.5, PI * 1.5, 12, GOLD.darkened(0.2), 4.0)
	n.draw_arc(Vector2(cx + 36, -104), 12, -PI * 0.5, PI * 0.5, 12, GOLD.darkened(0.2), 4.0)


## 奖杯在不在用图（测试看）
func trophy_textured() -> bool:
	return _trophy_tex != null


func banner_textured() -> bool:
	return _banner_tex != null


# ---- 彩带 ----

func _spawn_confetti(top := false) -> Dictionary:
	# 彩带从大厅上空飘下来：只在奖杯与横幅一带的上空，落到地面前淡掉
	var cx := rng.randf_range(TROPHY_FOOT.x - 400.0, TROPHY_FOOT.x + 480.0)
	var y0 := rng.randf_range(TROPHY_FOOT.y - 360.0, TROPHY_FOOT.y - 120.0) if not top else TROPHY_FOOT.y - 420.0
	return {"p": Vector2(cx, y0), "v": Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(22.0, 44.0)), "rot": rng.randf() * TAU,
		"spin": rng.randf_range(-3.0, 3.0), "tex": rng.randi_range(0, 3), "phase": rng.randf() * TAU, "life": rng.randf_range(5.0, 9.0), "age": 0.0}


func _seed_confetti() -> void:
	_confetti.clear()
	for i in MAX_CONFETTI:
		var c := _spawn_confetti()
		c.age = rng.randf_range(0.0, c.life)
		_confetti.append(c)


func _update_confetti(dt: float) -> void:
	for i in _confetti.size():
		var c: Dictionary = _confetti[i]
		c.age += dt
		c.p += Vector2(c.v.x + sin(_t * 1.6 + c.phase) * 14.0, c.v.y) * dt
		c.rot += c.spin * dt
		if c.age >= c.life:
			_confetti[i] = _spawn_confetti(true)


# ---- 烟花：升空 → 迸发 → 火花下落 ----

func _launch() -> void:
	var x := rng.randf_range(TROPHY_FOOT.x - 380.0, TROPHY_FOOT.x + 420.0)
	_rockets.append({"p": Vector2(x, TROPHY_FOOT.y - 70.0), "v": Vector2(rng.randf_range(-6.0, 6.0), -rng.randf_range(150.0, 190.0)), "life": rng.randf_range(0.9, 1.3),
		"col": BUNTING_COLORS[rng.randi_range(0, 2)].lerp(Color.WHITE, 0.15)})


func _burst(p: Vector2, col: Color) -> void:
	var n := 28
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.05, 0.05)
		var sp := rng.randf_range(55.0, 88.0)
		_sparks.append({"p": p, "v": Vector2.from_angle(a) * sp, "a": 1.0, "col": col, "life": rng.randf_range(0.9, 1.4)})


func _update_fireworks(dt: float) -> void:
	_next_firework -= dt
	if _next_firework <= 0.0:
		_next_firework = rng.randf_range(FIREWORK_GAP_MIN, FIREWORK_GAP_MAX)
		_launch()
	for i in range(_rockets.size() - 1, -1, -1):
		var r: Dictionary = _rockets[i]
		r.p += r.v * dt
		r.life -= dt
		if r.life <= 0.0:
			_burst(r.p, r.col)
			_rockets.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.v = Vector2(s.v.x * (1.0 - dt * 0.8), s.v.y * (1.0 - dt * 0.8) + 40.0 * dt)
		s.p += s.v * dt
		s.life -= dt
		s.a = clampf(s.life * 1.2, 0.0, 1.0)
		if s.life <= 0.0:
			_sparks.remove_at(i)


func _draw_fx() -> void:
	if not fx_on():
		return
	for c in _confetti:
		var fade := clampf(minf(c.age, c.life - c.age) * 1.2, 0.0, 1.0)
		var tex: Texture2D = null
		if not _confetti_tex.is_empty():
			tex = _confetti_tex[int(c.tex) % _confetti_tex.size()]
		_fx_node.draw_set_transform(c.p, c.rot, Vector2.ONE)
		if tex != null:
			_fx_node.draw_texture(tex, -tex.get_size() / 2.0, Color(1, 1, 1, fade))
		else:
			var col: Color = BUNTING_COLORS[int(c.tex) % BUNTING_COLORS.size()]
			_fx_node.draw_rect(Rect2(-4, -2, 8, 4), Color(col, fade))
	_fx_node.draw_set_transform(Vector2.ZERO)
	for r in _rockets:
		_fx_node.draw_circle(r.p, 2.2, Color(1, 0.95, 0.7, 0.95))
		_fx_node.draw_circle(r.p + Vector2(0, 6), 1.4, Color(1, 0.8, 0.4, 0.5))
	for s in _sparks:
		_fx_node.draw_circle(s.p, 3.0, Color(s.col, s.a * 0.25))
		_fx_node.draw_circle(s.p, 1.6, Color(s.col, s.a))


## 测试看：粒子个数
func confetti_count() -> int:
	return _confetti.size() if fx_on() else 0


func spark_count() -> int:
	return _rockets.size() + _sparks.size()


func _process(dt: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	_t += dt
	if _bunting_node != null:
		_bunting_node.queue_redraw()   # 彩旗摇摆
	if fx_on():
		_update_confetti(dt)
		_update_fireworks(dt)
	elif not _sparks.is_empty() or not _rockets.is_empty():
		_sparks.clear()
		_rockets.clear()
	_fx_node.queue_redraw()
