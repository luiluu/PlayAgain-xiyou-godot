class_name XRift
extends RefCounted
## 【cc·未经审查】大厅时空漩涡二阶段（Kyo 11-11 整包出，O-312；时空裂缝方案 v0.7、交付单 cc_rift2-canglong.md）。
## 第一阶在原版 v0.62.07 起的 Map004：EV75「时空漩涡_1」(14,19)、EV76「时空漩涡_字幕1」（rift1 过场，甩出流萤）、EV77「时空漩涡_流萤1」。
## 本文件在 XDB.map(4) 读入时就地改（同 XDeadContent.patch_map），不碰切片与转换器：
## - EV75：图换 !Codex_Rift_Stage2（1344×576，每格 112×72，约两格宽；素材在 content/rift/，来历见同目录 README），
##   旋转路线每步等 6 帧改 3 帧（转得更快），调查文字换成二阶段的，震屏弹回照旧。
## - EV201／202：漩涡左右 (13,19)／(15,19) 两个无图挡路事件，调查同 EV75。
## - EV203「时空漩涡_字幕2」（自动执行）：rift1 播过、rift2 没播、且不是刚播完 rift1 的同一次进大厅时播——
##   （CHAIN_AFTER_RIFT1 开着时不等下一次：rift1 放完接着播）
##   变暗 →「??????」一句 → 漩涡闪光震屏 → 苍龙破晓被甩出两格到 (14,21) → 一句台词 → 淡出往南 → 小字。
##   先记 rift2 再播；全存档只播一次（配置 codexWhisperSeen，同 rift1）。
## - EV204「时空漩涡_苍龙2」：过场用的人物，平时无图（行走图 TZX04 第 0 格，即角色 146 的行走图）。
## 新事件号从 201 起，避开原版以后在 Map004 追加事件时撞号；切片 keepEvents 不列它们，由 keep_event 放行。
## 开关 STAGE2＝false 后 clear_cache() 回第一阶。给大厅异化留的接口：stage()、canglong_drop_cell()；本文件只占 (13～15,19) 三格与 EV75～77、201～207。
##
## 【cc·未经审查】三阶段（T412，Kyo 11-23 事项34→D262「先做漩涡三阶段，再开放」、事项35「看完二阶后下一次进大厅就播」「不再做甩出来，徐凤年从天而降」）：
## - EV205「时空漩涡_字幕3」：rift2 播过、rift3 没播、且不是刚播完 rift2 的同一次进大厅时播（不跟 CHAIN_AFTER_RIFT1 走，总要隔一次进图）——
##   变暗 →「??????」一句 → 漩涡闪光震屏 → 一只异化怪物从天上摔到 (14,22) → 白光，徐凤年追下来落到 (14,21) →
##   斩击动画＋重震屏＋白闪、怪物淡掉 → 徐凤年三句（隐世强者察觉天地变化／暗示四阶化形／决定跟随）→ 淡出往南 → 小字。
##   先记 rift3 再播；全存档只播一次（配置 codexWhisperSeen）。
## - EV206「时空漩涡_徐凤年3」、EV207「时空漩涡_异化怪3」：过场用的人物，平时无图、起点在漩涡正上方 FALL_FROM 格
##   （徐凤年用行走图 7mobu7 第 2 格＝角色 152 的行走图；怪物用原版 Monster 第 6 格，大厅异化层按备注染幽紫）。
## - stage()：rift3 播过（且 STAGE3 开着）返回 3，给 T411 徐凤年招募／号角门槛用（它读 XConfig.whisper_seen("rift3") 或 stage() >= 3）。
##   三阶怪物异化（蚀骨）这单不开：XRiftAlien.STAGE3_ALIEN 默认关，XRift 给 3 时怪物端仍按二阶。
## 开关 STAGE3＝false 后 clear_cache()：不加 205／206、stage() 不到 3（二阶的东西不变）。

static var STAGE2 := true
## O-339：原设计 rift2 要等「下一次进大厅」才播，玩家第一次进大厅看完流萤后苍龙不出，
## 要出去再进来（玩家反馈 v0.01「流萤和苍龙的解锁动画冲突，退出重新切图才刷出苍龙」）。开着时 rift1 放完（地图不忙了）
## 自动执行页紧接着播 rift2，两段不会同时跑（自动执行只在没有别的事件时启动）。false 回到「下一次进大厅」。
static var CHAIN_AFTER_RIFT1 := true
## T412：漩涡三阶段（rift3 过场、stage()==3）。false 回到只有二阶段
static var STAGE3 := true
## T430（O-651）：三阶过场整段替换为 26 秒漫画动画（XRift3Anim，分镜 v0.5）。
## true＝资源就绪走漫画替换支，缺资源自动走 411 Else 支回退原像素过场；false＝回退 T412 原像素过场（clear_cache() 生效）
static var RIFT3_ANIM := true
## T486（O-663，Kyo 11-25 事项60「悄悄补记，直接进三阶看徐凤年」）：存档里 EV76／EV203 自开关 A 开着（这个档真看过流萤／苍龙），
## 配置 codexWhisperSeen 却缺 rift1／rift2（重装／换机导回存档、配置坏了）时，进大厅先补记这两项、不播过场，
## 同一次进大厅就按原逻辑播 rift3、进三阶。只管西游档（天启篇不动）；不改存档。false 回到不补记（旧档永久卡二阶）。
static var BACKFILL_FROM_SAVE := true

const MAP := 4
const VORTEX := 75
const RIFT1 := 76
const BLOCK_L := 201
const BLOCK_R := 202
const RIFT2 := 203
const CANGLONG_EV := 204
const NEW_EVENTS := [BLOCK_L, BLOCK_R, RIFT2, CANGLONG_EV]
const RIFT3 := 205
const XUFENG_EV := 206
const MOB_EV := 207
const STAGE3_EVENTS := [RIFT3, XUFENG_EV, MOB_EV]
const XUFENG_ACTOR := 152
## 徐凤年起落：从漩涡正上方 FALL_FROM 落到 XUFENG_DROP（同苍龙落点，苍龙早已离场）
const FALL_FROM := Vector2i(14, 12)
const XUFENG_DROP := Vector2i(14, 21)
## 被追杀的异化怪物落点（徐凤年落点南边一格）
const MOB_DROP := Vector2i(14, 22)
const STAGE1_IMG := "!Codex_Rift_Stage1"
const STAGE2_IMG := "!Codex_Rift_Stage2"
const CELL := Vector2i(14, 19)
const DROP := Vector2i(14, 21)
const INVESTIGATE_TEXT := "转得比上次快了。贴近了，能听见很远的声音。"
## 「刚播完 rift1 的同一次进大厅」的虚拟键（XConfig.whisper_seen 转来问 this_visit_seen）
const THIS_VISIT_KEY := "rift1@thisvisit"
const RIFT2_CONDITION := "window.CodexWhisper&&CodexWhisper.seen('rift1')&&!CodexWhisper.seen('rift2')&&!CodexWhisper.seen('rift1@thisvisit')"
## 「刚播完 rift2 的同一次进大厅」的虚拟键（三阶段要等下一次进大厅）
const RIFT2_VISIT_KEY := "rift2@thisvisit"
const RIFT3_CONDITION := "window.CodexWhisper&&CodexWhisper.seen('rift2')&&!CodexWhisper.seen('rift3')&&!CodexWhisper.seen('rift2@thisvisit')"

## 进图次数（map_scene.load_map 换图时加一）与各键记下时的那一次（键 → 第几次进图；不写盘）
static var _visit := 0
static var _mark_visit := {}


## 当前阶段：STAGE2 关了是 1；开着是 2，rift3 播过（STAGE3 开着）是 3
static func stage() -> int:
	if not STAGE2:
		return 1
	if STAGE3 and XConfig.whisper_seen("rift3"):
		return 3
	return 2


## 苍龙破晓被甩出的落点（漩涡正南两格）；大厅异化在这放青色鳞
static func canglong_drop_cell() -> Vector2i:
	return DROP


static func clear_cache() -> void:
	XDB._tables.erase("map:%d" % MAP)


static func on_map_setup(_map_id: int) -> void:
	_visit += 1


## T486：进大厅时按存档自开关补记 rift1／rift2（只记配置、不播过场、不算「这一次进大厅才记的」）。
## 在 map_scene 建本图事件之前调；返回补记了哪些键（测试用）。
static func backfill_from_save(s: XState, map_id: int) -> Array:
	var added := []
	if not BACKFILL_FROM_SAVE or not STAGE2 or map_id != MAP or s == null or XTianqi.active(s):
		return added
	var r1_done := s.self_switch(MAP, RIFT1, "A")
	var r2_done := s.self_switch(MAP, RIFT2, "A")
	if (r1_done or r2_done) and not XConfig.whisper_seen("rift1"):
		added.append("rift1")
	if r2_done and not XConfig.whisper_seen("rift2"):
		added.append("rift2")
	for key in added:
		XConfig.whisper_mark(key)
		_mark_visit.erase(key)  # 补记不是这一次进大厅播的：rift3 同一次就能播
	return added


## XConfig.whisper_mark 记键时通知
static func on_mark(key: String) -> void:
	_mark_visit[key] = _visit


## 是不是「同一次进大厅」的虚拟键（XConfig.whisper_seen 转来问 this_visit_seen）
static func is_visit_key(key: String) -> bool:
	return key == THIS_VISIT_KEY or key == RIFT2_VISIT_KEY


static func this_visit_seen(key: String) -> bool:
	if key == THIS_VISIT_KEY:
		return int(_mark_visit.get("rift1", -1)) == _visit and not CHAIN_AFTER_RIFT1
	if key == RIFT2_VISIT_KEY:
		return int(_mark_visit.get("rift2", -1)) == _visit
	return false


## 切片 keepEvents 之外也要放进地图的事件（二、三阶段新加的）
static func keep_event(map_id: int, ev_id: int) -> bool:
	if not STAGE2 or map_id != MAP:
		return false
	return NEW_EVENTS.has(ev_id) or (STAGE3 and STAGE3_EVENTS.has(ev_id))


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
	if STAGE3:
		while events.size() <= MOB_EV:
			events.append(null)
		events[RIFT3] = _rift3_event()
		events[XUFENG_EV] = _xufeng_event()
		events[MOB_EV] = _mob_event()


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


## 自动执行过场的三页：第 1 页并行查条件（满足开 B、已播过开 A），第 2 页（B）自动执行播 body，第 3 页（A）停。
## body 保留调用方显式缩进（支持 111／411／412 条件分支）
static func _whisper_pages(seen_key: String, condition: String, body: Array) -> Array:
	var watch := [
		_c(111, [12, "window.CodexWhisper&&CodexWhisper.seen('%s')" % seen_key], 0),
		_c(123, ["A", 0]),
		_c(0, []),
		_c(411, [], 0),
		_c(111, [12, condition], 1),
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
	return [p1, p2, p3]


## 三阶段过场（T412）。设定（Kyo 11-23）：徐凤年是隐世强者，察觉天地变化，追杀一只异化怪物时从天而降落进大厅，斩掉它后决定跟随玩家；
## 台词点到一点四阶段（化形）。不新画：异化怪物用原版行走图 Monster 第 6 格，大厅异化层（XLobbyCorruption）按备注染漩涡幽紫；
## 没有专门的落地、斩击美术，用白光＋震屏＋原版斩击动画代替。台词已过小A 文字审（XRift.RIFT3_LINES）。
const RIFT3_LINES := {
	"whisper": "\\n<??????>……又有东西，从那头漏过来了。",
	"sense": "\\n<徐凤年>山里清静了这些年，天地气机一乱，还是追着这东西出了山。",
	"hint": "\\n<徐凤年>刚才那只，不过是染了层异色。再往后……怕是连模样都要换了。",
	"follow": "\\n<徐凤年>你身上沾着漩涡的气息，想来前头热闹还多。这一程，我跟你走。",
	"after": "\\c[8]兑换大厅里，好像又来了一个人。\\c[0]",
}
const MOB_IMG := "Monster"
const MOB_INDEX := 6
const MOB_NOTE := "<codex_rift_alien_mob>"
## 斩击动画（原版 Animations 23「斩击/必杀技 1」）
const SLASH_ANIM := 23


static func _fall_route(img: String, idx: int, to_y: int) -> Dictionary:
	var cmds := [[41, img, idx], [35], [32], [34], [37], [29, 6], [42, 255]]
	for i in to_y - FALL_FROM.y:
		cmds.append([1])
	return _route(cmds)


## T412 原像素过场指令体（RIFT3_ANIM=false 顶层 indent=0；RIFT3_ANIM=true 放进 411 Else 支 indent=1 作缺资源运行时回退）
static func _rift3_pixel_body(indent := 0) -> Array:
	var a := XDB.rec("Actors", XUFENG_ACTOR)
	var img := str(a.get("characterName", "7mobu7"))
	var idx := int(a.get("characterIndex", 2))
	var face := [str(a.get("faceName", "")), int(a.get("faceIndex", 0)), 0, 2]
	return [
		_c(223, [[-51, -51, -17, 51], 45, true], indent),
		_c(230, [20], indent),
		_c(101, ["", 0, 1, 1], indent),
		_c(401, [RIFT3_LINES.whisper], indent),
		_c(225, [5, 9, 30, false], indent),
		_c(224, [[200, 180, 255, 170], 30, false], indent),
		_c(212, [VORTEX, 136, false], indent),
		_c(230, [20], indent),
		# 异化怪物先从天上摔下来，落在落点南边一格，抬头望天
		_c(205, [MOB_EV, _fall_route(MOB_IMG, MOB_INDEX, MOB_DROP.y)], indent),
		_c(225, [5, 9, 12, false], indent),
		_c(230, [10], indent),
		_c(205, [MOB_EV, _route([[36], [19], [35]])], indent),
		_c(230, [20], indent),
		# 天上一道白光：徐凤年追下来，正落在它头顶一格
		_c(224, [[255, 255, 255, 200], 20, true], indent),
		_c(205, [XUFENG_EV, _fall_route(img, idx, XUFENG_DROP.y)], indent),
		# 一刀斩下：斩击动画＋重震＋白闪，怪物淡掉
		_c(212, [MOB_EV, SLASH_ANIM, false], indent),
		_c(225, [9, 9, 24, false], indent),
		_c(224, [[255, 255, 255, 255], 12, false], indent),
		_c(205, [XUFENG_EV, _route([[14, 0, 0]])], indent),
		_c(230, [30], indent),
		_c(205, [MOB_EV, _route([[42, 180], [15, 6], [42, 110], [15, 6], [42, 50], [15, 6], [42, 0]])], indent),
		_c(230, [30], indent),
		_c(205, [XUFENG_EV, _route([[36], [38], [16]])], indent),
		_c(230, [20], indent),
		_c(101, face, indent),
		_c(401, [RIFT3_LINES.sense], indent),
		_c(101, face, indent),
		_c(401, [RIFT3_LINES.hint], indent),
		_c(101, face, indent),
		_c(401, [RIFT3_LINES.follow], indent),
		_c(230, [30], indent),
		_c(205, [XUFENG_EV, _route([[31], [29, 4], [42, 200], [1], [42, 150], [1], [42, 100], [1], [42, 50], [1], [42, 0]])], indent),
		_c(223, [[0, 0, 0, 0], 45, true], indent),
		_c(101, ["", 0, 2, 1], indent),
		_c(401, [RIFT3_LINES.after], indent),
	]


static func _rift3_event() -> Dictionary:
	# 1) 两支共用：首条落盘防重
	var body: Array = [_c(355, ["CodexWhisper.mark('rift3');"], 0)]
	if not RIFT3_ANIM:
		# 开关关闭：生成与 T412 原版逐条一致的像素过场
		body.append_array(_rift3_pixel_body(0))
	else:
		# 2) 运行时条件分支：动画可用走整段替换支，缺资源走 411 Else 支自动回退原像素过场
		body.append(_c(111, [12, "CodexRift3.available()"], 0))
		# 成立支（完整替换）：不含 MOB_EV/XUFENG_EV 移动、不含 SLASH_ANIM 23、不含静态 401 对话
		body.append(_c(355, ["CodexRift3.play();"], 1))
		body.append(_c(355, ["CodexRift3.replayMissed();"], 1))
		body.append(_c(0, [], 1))
		body.append(_c(411, [], 0))
		# Else 支（运行时缺资源自动回退）：完整原版像素过场（indent=1）
		body.append_array(_rift3_pixel_body(1))
		body.append(_c(0, [], 1))
		body.append(_c(412, [], 0))
	# 3) 两支合流收尾
	body.append(_c(123, ["A", 0], 0))
	body.append(_c(0, [], 0))
	return _ev(RIFT3, "时空漩涡_字幕3", "<codex_rift_whisper:rift3>", 2, 31, _whisper_pages("rift3", RIFT3_CONDITION, body))


## 过场人物：平时无图、穿透、在人物之上，起点在漩涡正上方
static func _actor_event(id: int, name: String, note: String) -> Dictionary:
	var p := _page([_c(0, [], 0)], 0, 2, true)
	return _ev(id, name, note, FALL_FROM.x, FALL_FROM.y, [p])


static func _xufeng_event() -> Dictionary:
	return _actor_event(XUFENG_EV, "时空漩涡_徐凤年3", "<codex_rift_actor:%d>" % XUFENG_ACTOR)


static func _mob_event() -> Dictionary:
	return _actor_event(MOB_EV, "时空漩涡_异化怪3", MOB_NOTE)
