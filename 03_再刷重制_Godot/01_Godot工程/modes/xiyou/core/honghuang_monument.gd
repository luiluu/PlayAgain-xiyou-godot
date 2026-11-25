class_name XHonghuangMonument
extends RefCounted
## 【小A·未经审查】T460：西游大厅洪荒碑＋进西游档一次性首通播报（Kyo 11-24 / 11-25 拍板）。
##
## 两部分（均只在西游档生效，天启篇存档完全不受影响；回退开关 ENABLED 置 false 即整套无痕关闭）：
## 1. 大厅洪荒碑：方桌大厅 Map004 东侧红毯外空处 (18, 14)，新增事件 EV82（避开原版 1～77、庆典 78～81、漩涡 201～207），
##    视觉绘制由 XHonghuangMonumentView 挂入角色层按 y 排序；可调查，名字从 honghuang_first_clear.json 读取，留空时不显示名字。
## 2. 进西游档一次性播报：标题进入西游档（读档／自动继续／西游新开局）或游戏内读档后，在正式游戏地图空闲时弹出一次消息框，
##    宣告首位洪荒证道者；每个存档只弹一次（已弹标记记在 s.flags[FLAG_KEY]["broadcast_seen"]，老存档读入也只弹一次；
##    配置留空或回退开关关闭时不弹、不写已弹标记）。

## T460 回退开关：false＝关闭大厅洪荒碑与进游一次性播报，恢复改动前原样
static var ENABLED := true

const MAP_ID := 4
const EVENT_ID := 82
const CELL := Vector2i(18, 14)
const CONFIG_PATH := "res://modes/xiyou/honghuang_first_clear.json"
const FLAG_KEY := "honghuang_first_clear"
## 西游新开局三连过场图（Map001 选档选难度 → Map002 开局剧情 → Map221 教派选择）：不打断开局过场，进大厅后再弹播报
const OPENING_MAPS := [1, 2, 221]

## 测试覆盖用：非 null 时当作配置中的首位洪荒证道者名（允许设 "" 测留空分支）
static var NAME_OVERRIDE = null
static var _cached_name = null
static var _cache_stamp := ""
## 从标题／读档进入游戏时由入口置 true，进地图检查后消费；避免无关单测直接 new XMapScene 时误弹阻塞消息框
static var _entry_armed := false


# ============ 配置与状态判断 ============

## 是否西游档（天启篇存档返回 false，完全不受影响）
static func is_xiyou_save(s) -> bool:
	return s != null and not XTianqi.active(s)


## 当前存档是否应显示并启用大厅洪荒碑
static func monument_active(s = null) -> bool:
	var st = s if s != null else XState.current
	return ENABLED and is_xiyou_save(st)


## 读取配置中的首位洪荒证道者名；文件缺失、解析失败或留空时返回 ""
static func winner_name() -> String:
	if NAME_OVERRIDE != null:
		return str(NAME_OVERRIDE).strip_edges()
	if _cached_name == null:
		_cached_name = _load_config_name()
	return str(_cached_name)


static func reload_config() -> void:
	_cached_name = null


static func _load_config_name() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		return ""
	var raw := FileAccess.get_file_as_string(CONFIG_PATH)
	if raw == "":
		return ""
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return ""
	return str(parsed.get("first_clear_player", "")).strip_edges()


# ============ 玩家可见文案（大白话、短；待文字审）============

## 大厅洪荒碑调查文字：有名字时显「首位洪荒证道者：<名>」，留空时不显示名字
static func monument_lines() -> Array[String]:
	var who := winner_name()
	if who == "":
		return [
			"【洪荒碑】",
			"石碑上暂时还没有刻下名字。",
		]
	return [
		"【洪荒碑】",
		"首位洪荒证道者：%s" % who,
	]


## 进西游档一次性播报文字：留空时返回空数组（不弹）
static func broadcast_lines() -> Array[String]:
	var who := winner_name()
	if who == "":
		return []
	return [
		"【洪荒首通播报】",
		"恭喜「%s」成为首位通关洪荒难度的玩家！" % who,
		"他的名字已经刻在大厅的洪荒碑上，有空可以去看看。",
	]


# ============ 一次性播报（存档标记＋进游入口）============

static func arm_entry() -> void:
	_entry_armed = true


static func disarm_entry() -> void:
	_entry_armed = false


static func is_entry_armed() -> bool:
	return _entry_armed


static func broadcast_seen(s) -> bool:
	if s == null or not (s.flags is Dictionary):
		return false
	var rec = s.flags.get(FLAG_KEY)
	return rec is Dictionary and bool(rec.get("broadcast_seen", false))


static func mark_broadcast_seen(s) -> void:
	if not is_xiyou_save(s):
		return
	if not (s.flags.get(FLAG_KEY) is Dictionary):
		s.flags[FLAG_KEY] = {}
	(s.flags[FLAG_KEY] as Dictionary)["broadcast_seen"] = true


## 在地图空闲时判断是否应弹播报（纯查询，不改状态）
static func should_broadcast(s, map_id: int) -> bool:
	if not _entry_armed or not ENABLED or not is_xiyou_save(s):
		return false
	if winner_name() == "" or broadcast_seen(s):
		return false
	if OPENING_MAPS.has(map_id):
		return false
	return true


## 在地图空闲时消费一次进游播报：需要弹时标记已弹并返回文案，否则返回空数组
static func consume_broadcast(s, map_id: int) -> Array[String]:
	if not _entry_armed:
		return []
	# 西游新开局过场图期间保留武装，等进到正式地图（如方桌大厅）再弹
	if ENABLED and is_xiyou_save(s) and winner_name() != "" and not broadcast_seen(s) and OPENING_MAPS.has(map_id):
		return []
	_entry_armed = false
	if not ENABLED or not is_xiyou_save(s) or broadcast_seen(s):
		return []
	var lines := broadcast_lines()
	if lines.is_empty():
		return []
	mark_broadcast_seen(s)
	return lines


# ============ 地图补丁与事件隐藏 ============

static func reload_map() -> void:
	XDB._tables.erase("map:%d" % MAP_ID)


## Map004 缓存失效检测：回退开关切换时作废重读
static func cache_stale() -> bool:
	var stamp := str(ENABLED)
	if stamp == _cache_stamp:
		return false
	_cache_stamp = stamp
	return true


static func _make_event() -> Dictionary:
	var cond := {
		"actorId": 1, "actorValid": false,
		"itemId": 1, "itemValid": false,
		"selfSwitchCh": "A", "selfSwitchValid": false,
		"switch1Id": 1, "switch1Valid": false,
		"switch2Id": 1, "switch2Valid": false,
		"variableId": 1, "variableValid": false,
		"variableValue": 0,
	}
	var page := {
		"conditions": cond,
		"directionFix": true,
		"image": {"tileId": 0, "characterName": "", "direction": 2, "pattern": 1, "characterIndex": 0},
		"list": [
			{"code": 355, "indent": 0, "parameters": ["CodexHonghuang.inspect();"]},
			{"code": 0, "indent": 0, "parameters": []},
		],
		"moveFrequency": 3,
		"moveRoute": {"list": [{"code": 0, "parameters": []}], "repeat": true, "skippable": false, "wait": false},
		"moveSpeed": 3,
		"moveType": 0,
		"priorityType": 1,
		"stepAnime": false,
		"through": false,
		"trigger": 0,
		"walkAnime": false,
	}
	return {"id": EVENT_ID, "name": "洪荒碑", "note": "<CodexHonghuang>", "pages": [page], "x": CELL.x, "y": CELL.y}


## XDB.map 读 Map004 时追加 EV82；开关关闭或编号被占时不改原数据
static func patch_map(map_id: int, data) -> void:
	if map_id != MAP_ID or not ENABLED or not (data is Dictionary):
		return
	var events: Array = data.get("events", [])
	if EVENT_ID < events.size() and events[EVENT_ID] != null:
		return
	while events.size() <= EVENT_ID:
		events.append(null)
	events[EVENT_ID] = _make_event()


## 切片 keepEvents 放行 EV82（由 MVEvent._is_hidden_event 按当前存档再裁天启档与回退开关）
static func keep_event(map_id: int, ev_id: int) -> bool:
	return map_id == MAP_ID and ev_id == EVENT_ID and ENABLED


## MVEvent._is_hidden_event：天启档或回退开关关闭时隐藏洪荒碑（空页、透明、可穿过、不触发）
static func hides(map_id: int, ev_id: int) -> bool:
	return map_id == MAP_ID and ev_id == EVENT_ID and not monument_active(XState.current)


# ============ 355 脚本入口（MVScript 转交）============

static func run_script(js: String, interp) -> void:
	var m := RegEx.create_from_string("^CodexHonghuang\\.(\\w+)\\(\\);?$").search(js.strip_edges())
	if m == null or interp == null or not interp.host_alive():
		return
	if m.get_string(1) == "inspect":
		await inspect(interp)


static func inspect(interp) -> void:
	if not monument_active(XState.current) or interp == null or not interp.host_alive():
		return
	await interp.host.show_message({
		"face": "", "index": 0, "background": 0, "position": 2,
		"lines": monument_lines(),
	})
