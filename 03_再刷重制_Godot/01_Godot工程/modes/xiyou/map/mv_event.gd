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
			_move_wait = (5 - move_frequency) * 30 + randi_range(0, 60)
			move_straight([2, 4, 6, 8][randi_range(0, 3)])
