class_name MVEvent
extends MVCharacter
## 地图事件：按 MV Game_Event.findProperPageIndex 从最后一页往前找第一页满足条件的页。
## 触发：0 确定键 1 玩家接触 2 事件接触 3 自动执行 4 并行。首期只做固定/随机移动。

var map_id := 0
var event_id := 0
var data: Dictionary
var page_index := -1
var page: Dictionary = {}
var erased := false
var _move_wait := 0
var _wander_rng := RandomNumberGenerator.new()

func _init() -> void:
	_wander_rng.randomize()

func _wander_roll(lo: int, hi: int) -> int:
	return _wander_rng.randi_range(lo, hi)


func setup_event(map: int, ev: Dictionary) -> void:
	map_id = map
	event_id = int(ev.id)
	data = ev
	name = "Event%d" % event_id
	locate(int(ev.x), int(ev.y))
	refresh()


func refresh() -> void:
	var idx := -1 if erased else _find_page()
	if idx == page_index:
		return
	page_index = idx
	page = data.pages[idx] if idx >= 0 else {}
	if page.is_empty():
		set_image("", 0)
		priority_type = 0
		through = true
		return
	var img: Dictionary = page.image
	if int(img.tileId) > 0:
		set_tile_image(int(img.tileId))
	else:
		set_image(str(img.characterName), int(img.characterIndex))
	direction = int(img.direction) if int(img.direction) > 0 else 2
	pattern = int(img.pattern)
	move_speed = int(page.moveSpeed)
	move_frequency = int(page.moveFrequency)
	walk_anime = bool(page.walkAnime)
	step_anime = bool(page.stepAnime)
	direction_fix = bool(page.directionFix)
	through = bool(page.through)
	priority_type = int(page.priorityType)
	_sync_position()


func _find_page() -> int:
	for i in range(data.pages.size() - 1, -1, -1):
		if _meets(data.pages[i].conditions):
			return i
	return -1


func _meets(c: Dictionary) -> bool:
	var s := XState.current
	if s == null:
		return false
	if c.switch1Valid and not s.switch(int(c.switch1Id)):
		return false
	if c.switch2Valid and not s.switch(int(c.switch2Id)):
		return false
	if c.variableValid and s.variable(int(c.variableId)) < float(c.variableValue):
		return false
	if c.selfSwitchValid and not s.self_switch(map_id, event_id, str(c.selfSwitchCh)):
		return false
	if c.itemValid and s.item_count(int(c.itemId)) <= 0:
		return false
	if c.actorValid and not s.party.has(int(c.actorId)):
		return false
	return true


func trigger() -> int:
	return int(page.get("trigger", -1)) if not page.is_empty() else -1

func command_list() -> Array:
	return page.get("list", [])

func is_normal_priority() -> bool:
	return priority_type == 1


func update_character() -> void:
	super.update_character()
	if page.is_empty() or is_moving():
		return
	if int(page.get("moveType", 0)) == 1:
		_move_wait -= 1
		if _move_wait <= 0:
			_move_wait = (5 - move_frequency) * 30 + _wander_roll(0, 60)
			move_straight([2, 4, 6, 8][_wander_roll(0, 3)])


## 存档：原版 $gameMap 整个进存档、同版本读档不重设地图（参照 tests/fixtures/save_events_oracle.json）。
## 这里只存玩家看得到的运行时状态：位置（含走到一半的小数位置）、朝向、移动路线改过的图像／不透明度／穿透等，以及强制路线与索引；
## 还有移动生命周期计数：跳跃峰高／剩余帧（_jumpPeak／_jumpCount，跳到一半存档读档后接着在空中走完）、停步与动画计数、随机移动等待（O-114）。
## 临时消除另存在 XState.erased_events，自开关在 XState.self_switches。
func save_state() -> Dictionary:
	var out := {"page": page_index, "x": grid.x, "y": grid.y, "real": [real.x, real.y], "direction": direction, "pattern": pattern,
		"characterName": character_name, "characterIndex": character_index, "tileId": tile_id, "opacity": opacity,
		"through": through, "transparent": transparent, "directionFix": direction_fix, "walkAnime": walk_anime,
		"stepAnime": step_anime, "moveSpeed": move_speed, "moveFrequency": move_frequency, "priorityType": priority_type,
		"jumpPeak": _jump_peak, "jumpCount": _jump_count, "stopCount": _stop_count, "animeCount": _anime_count, "moveWait": _move_wait}
	if _route_forcing:
		out.forcedRoute = {"route": _route, "index": _route_index, "wait": _route_wait}
	return out


## 读档后套回 save_state 的结果；页与存档时不同（地图数据改过）就不套，留在初始状态
func restore_state(d: Dictionary) -> void:
	if int(d.get("page", -99)) != page_index:
		return
	if int(d.get("tileId", 0)) > 0:
		set_tile_image(int(d.tileId))
	else:
		set_image(str(d.get("characterName", "")), int(d.get("characterIndex", 0)))
	grid = Vector2i(int(d.x), int(d.y))
	var r: Array = d.get("real", [d.x, d.y])
	real = Vector2(float(r[0]), float(r[1]))
	direction = int(d.direction)
	pattern = int(d.get("pattern", pattern))
	opacity = int(d.get("opacity", opacity))
	through = bool(d.get("through", through))
	transparent = bool(d.get("transparent", transparent))
	direction_fix = bool(d.get("directionFix", direction_fix))
	walk_anime = bool(d.get("walkAnime", walk_anime))
	step_anime = bool(d.get("stepAnime", step_anime))
	move_speed = int(d.get("moveSpeed", move_speed))
	move_frequency = int(d.get("moveFrequency", move_frequency))
	priority_type = int(d.get("priorityType", priority_type))
	var forced = d.get("forcedRoute")
	if forced is Dictionary and forced.get("route") is Dictionary:
		force_move_route(forced.route)
		_route_index = int(forced.get("index", 0))
		_route_wait = int(forced.get("wait", 0))
	# 旧档没有这些字段：不在跳跃、计数从 0 起
	_jump_peak = int(d.get("jumpPeak", 0))
	_jump_count = int(d.get("jumpCount", 0))
	_stop_count = int(d.get("stopCount", 0))
	_anime_count = float(d.get("animeCount", 0.0))
	_move_wait = int(d.get("moveWait", _move_wait))
	_sync_position()
	queue_redraw()
