class_name XRift
extends RefCounted
## 【cc·未经审查】大厅时空漩涡二阶段（Kyo 11-11 整包出，O-待定·漩涡二阶段；时空裂缝方案 v0.7、交付单 cc_rift2-canglong.md）。
## 第一阶在原版 v0.62.07 起的 Map004：EV75「时空漩涡_1」(14,19)、EV76「时空漩涡_字幕1」（rift1 过场，甩出流萤）、EV77「时空漩涡_流萤1」。
## 本文件在 XDB.map(4) 读入时就地改（同 XDeadContent.patch_map），不碰切片与转换器：
## - EV75：图换 !Codex_Rift_Stage2（1344×576，每格 112×72，约两格宽；素材在 content/rift/，来历见同目录 README），
##   旋转路线每步等 6 帧改 3 帧（转得更快），调查文字换成二阶段的，震屏弹回照旧。
## - EV201／202：漩涡左右 (13,19)／(15,19) 两个无图挡路事件，调查同 EV75。
## - EV203「时空漩涡_字幕2」（自动执行）：rift1 播过、rift2 没播、且不是刚播完 rift1 的同一次进大厅时播——
##   变暗 →「??????」一句 → 漩涡闪光震屏 → 苍龙破晓被甩出两格到 (14,21) → 一句台词 → 淡出往南 → 小字。
##   先记 rift2 再播；全存档只播一次（配置 codexWhisperSeen，同 rift1）。
## - EV204「时空漩涡_苍龙2」：过场用的人物，平时无图（行走图 TZX04 第 0 格，即角色 146 的行走图）。
## 新事件号从 201 起，避开原版以后在 Map004 追加事件时撞号；切片 keepEvents 不列它们，由 keep_event 放行。
## 开关 STAGE2＝false 后 clear_cache() 回第一阶。给大厅异化留的接口：stage()、canglong_drop_cell()；本文件只占 (13～15,19) 三格与 EV75～77、201～204。

static var STAGE2 := true

const MAP := 4
const VORTEX := 75
const RIFT1 := 76
const BLOCK_L := 201
const BLOCK_R := 202
const RIFT2 := 203
const CANGLONG_EV := 204
const NEW_EVENTS := [BLOCK_L, BLOCK_R, RIFT2, CANGLONG_EV]
const STAGE1_IMG := "!Codex_Rift_Stage1"
const STAGE2_IMG := "!Codex_Rift_Stage2"
const CELL := Vector2i(14, 19)
const DROP := Vector2i(14, 21)
const INVESTIGATE_TEXT := "转得比上次快了。贴近了，能听见很远的声音。"
## 「刚播完 rift1 的同一次进大厅」的虚拟键（XConfig.whisper_seen 转来问 this_visit_seen）
const THIS_VISIT_KEY := "rift1@thisvisit"
const RIFT2_CONDITION := "window.CodexWhisper&&CodexWhisper.seen('rift1')&&!CodexWhisper.seen('rift2')&&!CodexWhisper.seen('rift1@thisvisit')"

## 进图次数（map_scene.load_map 换图时加一）与 rift1 记下时的那一次
static var _visit := 0
static var _rift1_visit := -1


## 当前阶段：开关开着是 2，关了是 1
static func stage() -> int:
	return 2 if STAGE2 else 1


## 苍龙破晓被甩出的落点（漩涡正南两格）；大厅异化在这放青色鳞
static func canglong_drop_cell() -> Vector2i:
	return DROP


static func clear_cache() -> void:
	XDB._tables.erase("map:%d" % MAP)


static func on_map_setup(_map_id: int) -> void:
	_visit += 1


## XConfig.whisper_mark 记键时通知
static func on_mark(key: String) -> void:
	if key == "rift1":
		_rift1_visit = _visit


static func this_visit_seen(key: String) -> bool:
	return key == THIS_VISIT_KEY and _rift1_visit == _visit


## 切片 keepEvents 之外也要放进地图的事件（二阶段新加的）
static func keep_event(map_id: int, ev_id: int) -> bool:
	return STAGE2 and map_id == MAP and NEW_EVENTS.has(ev_id)


static func patch_map(map_id: int, data) -> void:
	if not STAGE2 or map_id != MAP or not (data is Dictionary):
		return
	var events: Array = data.get("events", [])
	if events.size() <= VORTEX or not (events[VORTEX] is Dictionary) or events.size() > BLOCK_L:
		return  # 来源里没有第一阶，或 201 起已被原版占用：不动
	var vortex: Dictionary = events[VORTEX]
	if not str(vortex.get("note", "")).contains("codex_rift_stage:1"):
		return
	_patch_vortex(vortex)
	while events.size() <= CANGLONG_EV:
		events.append(null)
	events[BLOCK_L] = _blocker(BLOCK_L, CELL.x - 1, vortex)
	events[BLOCK_R] = _blocker(BLOCK_R, CELL.x + 1, vortex)
	events[RIFT2] = _rift2_event()
	events[CANGLONG_EV] = _canglong_event()


static func _patch_vortex(ev: Dictionary) -> void:
	ev.note = "<codex_rift_stage:2>"
	for p in ev.pages:
		if str(p.image.characterName) == STAGE1_IMG:
			p.image.characterName = STAGE2_IMG
		for c in p.moveRoute.list:
			if int(c.code) == 41 and str(c.parameters[0]) == STAGE1_IMG:
				c.parameters[0] = STAGE2_IMG
			elif int(c.code) == 15 and int(c.parameters[0]) == 6:
				c.parameters[0] = 3
		for c in p.list:
			if int(c.code) == 401 and str(c.parameters[0]) == "一股强大的力量将你推了回来。":
				c.parameters[0] = INVESTIGATE_TEXT


static func _cond() -> Dictionary:
	return {"actorId": 1, "actorValid": false, "itemId": 1, "itemValid": false, "selfSwitchCh": "A", "selfSwitchValid": false,
		"switch1Id": 1, "switch1Valid": false, "switch2Id": 1, "switch2Valid": false, "variableId": 1, "variableValid": false, "variableValue": 0}


static func _page(list: Array, trigger: int, priority: int, through := false) -> Dictionary:
	return {"conditions": _cond(), "directionFix": false,
		"image": {"tileId": 0, "characterName": "", "direction": 2, "pattern": 1, "characterIndex": 0},
		"list": list, "moveFrequency": 3, "moveRoute": {"list": [{"code": 0, "parameters": []}], "repeat": true, "skippable": false, "wait": false},
		"moveSpeed": 3, "moveType": 0, "priorityType": priority, "stepAnime": false, "through": through, "trigger": trigger, "walkAnime": false}


static func _ev(id: int, name: String, note: String, x: int, y: int, pages: Array) -> Dictionary:
	return {"id": id, "name": name, "note": note, "x": x, "y": y, "pages": pages}


## 挡路：无图、与漩涡同层，调查同漩涡（震屏、弹回、一句话）
static func _blocker(id: int, x: int, vortex: Dictionary) -> Dictionary:
	var list: Array = (vortex.pages[0].list as Array).duplicate(true)
	return _ev(id, "时空漩涡_挡路%d" % (id - BLOCK_L + 1), "<codex_rift_block>", x, CELL.y, [_page(list, 0, 1)])


static func _c(code: int, params: Array, indent := 1) -> Dictionary:
	return {"code": code, "indent": indent, "parameters": params}


static func _route(cmds: Array) -> Dictionary:
	var list: Array = cmds.map(func(c): return {"code": c[0], "indent": null, "parameters": c.slice(1)})
	list.append({"code": 0, "parameters": []})
	return {"list": list, "repeat": false, "skippable": true, "wait": true}


static func _rift2_event() -> Dictionary:
	var dl := DROP - CELL
	var body := [
		_c(355, ["CodexWhisper.mark('rift2');"], 0),
		_c(223, [[-51, -51, -17, 51], 45, true]),
		_c(230, [20]),
		_c(101, ["", 0, 1, 1]),
		_c(401, ["\\n<??????>你在这里，刷了很久了吧。"]),
		_c(225, [5, 9, 30, false]),
		_c(224, [[200, 180, 255, 170], 30, false]),
		_c(212, [VORTEX, 136, false]),
		_c(230, [20]),
		_c(205, [CANGLONG_EV, _route([[41, "TZX04", 0], [19], [37], [14, dl.x, dl.y]])]),
		_c(230, [40]),
		_c(205, [CANGLONG_EV, _route([[38], [16]])]),
		_c(230, [20]),
		_c(101, ["Actor11", 4, 0, 2]),
		_c(401, ["\\n<苍龙破晓>此处……尚有人族的气息。"]),
		_c(230, [30]),
		_c(205, [CANGLONG_EV, _route([[29, 4], [42, 200], [1], [42, 150], [1], [42, 100], [1], [42, 50], [1], [42, 0]])]),
		_c(223, [[0, 0, 0, 0], 45, true]),
		_c(101, ["", 0, 2, 1]),
		_c(401, ["\\c[8]兑换大厅里，好像又多了点什么。\\c[0]"]),
		_c(123, ["A", 0], 0),
		_c(0, [], 0),
	]
	for c in body:
		c.indent = 0  # 过场整段在顶层（条件由第 1 页查过）
	# 第 1 页并行：每 30 帧看一次条件，满足就开 B 转第 2 页（自动执行播过场）；已播过（别的存档播的）直接开 A 停掉。
	# 不用自动执行页查条件：条件不满足时自动执行页会每帧重跑、卡住玩家。
	var watch := [
		_c(111, [12, "window.CodexWhisper&&CodexWhisper.seen('rift2')"], 0),
		_c(123, ["A", 0]),
		_c(0, []),
		_c(411, [], 0),
		_c(111, [12, RIFT2_CONDITION], 1),
		_c(123, ["B", 0], 2),
		_c(0, [], 2),
		_c(412, [], 1),
		_c(230, [30], 1),
		_c(0, [], 1),
		_c(412, [], 0),
		_c(0, [], 0),
	]
	var p1 := _page(watch, 4, 0)
	var p2 := _page(body, 3, 0)
	p2.conditions.selfSwitchValid = true
	p2.conditions.selfSwitchCh = "B"
	var p3 := _page([_c(0, [], 0)], 0, 0)
	p3.conditions.selfSwitchValid = true
	return _ev(RIFT2, "时空漩涡_字幕2", "<codex_rift_whisper:rift2>", 1, 31, [p1, p2, p3])


static func _canglong_event() -> Dictionary:
	return _ev(CANGLONG_EV, "时空漩涡_苍龙2", "<codex_rift_actor:146>", CELL.x, CELL.y, [_page([_c(0, [], 0)], 0, 2, true)])
