class_name MVEvent
extends MVCharacter
## 地图事件：按 MV Game_Event.findProperPageIndex 从最后一页往前找第一页满足条件的页。
## 触发：0 确定键 1 玩家接触 2 事件接触 3 自动执行 4 并行（独立解释器，见 XMapScene.start_parallel）。
## 自主移动（Game_Event.updateSelfMovement，外面包着 YEP_EventChasePlayer）：类型 1 随机、2 接近玩家、3 自定义路线；
## 强制路线（指令 205）走着时、事件被确定键／接触启动执行着时（locked）停下，强制路线走完从原来的位置接着走。
## 频率只管自主移动：停着的帧数超过 30×(5－频率) 才走下一步；强制路线每停一帧就走下一条，不看频率。

var map_id := 0
var event_id := 0
var data: Dictionary
var page_index := -1
var page: Dictionary = {}
var erased := false
var _move_wait := 0
var _wander_rng := RandomNumberGenerator.new()
## Game_Event._locked：确定键／接触启动的事件执行期间为真（XMapScene.run_event），自主移动停下、停步计数清零；强制路线照走
var locked := false
## 并行页（触发 4）当前的解释器（Game_Event._interpreter）；跑完置空，下一帧再从头跑
var parallel_interp: MVInterpreter = null
## 上一个并行解释器结束时的物理帧号：原版解释器在第 N 帧跑完，第 N＋1 帧才重新 setup，同一帧不重起
var parallel_done_frame := -1
## YEP_EventChasePlayer 每页的逃离／追逐设定与计时（clearChaseSettings）
var _ecp := {}
static var _ecp_params = null

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
	# 换页（含消除、出现条件都不满足）：Game_Event.setupPageSettings／clearPageSettings 换掉 _interpreter，旧页的并行解释器不再更新
	stop_parallel()
	if page.is_empty():
		set_image("", 0)
		priority_type = 0
		through = true
		_clear_chase()
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
	# setupPageSettings 的 setMoveRoute：新页的自定义路线从头走，正在走的强制路线取消
	set_move_route(page.get("moveRoute", {}))
	_clear_chase()
	_sync_position()


func _find_page() -> int:
	var merchant29 := str(data.get("note", "")).contains("<CodexMerchant29>")
	for i in range(data.pages.size() - 1, -1, -1):
		if merchant29 and i == 1 and not merchant29_present():
			continue
		if _meets(data.pages[i].conditions):
			return i
	return -1


## 深渊／不朽商人（v0.30 起 installAbyssMerchantRuntime，XAbyssMerchant）：备注带 <CodexMerchant29> 的事件，第 2 页（下标 1）只在
## CodexAbyssMerchant.hasMerchant()（本副本已领战利品点且商人出现）时成立，不看页面条件。MERCHANT29_PAGE_GATE 设 false 回到只看页面条件。
static var MERCHANT29_PAGE_GATE := true
## O-待定·深渊商人（Kyo 11-06 定修）：v0.62.12 原版 CE1439 的 complete 与商人页的 openCurrent 那 33 条 355 把 parameters 存成字符串，
## 原版只 eval 第一个字符（`i`／`C`），商人从不出现（bajie-newsrc1 实测；v0.62.13 正式 MOD 已修）。true（默认）按修好的整段执行
## （MVInterpreter 355 取转换器留下的 mvStringParameters）；false 回到 v0.62.12 原版：只执行第一个字符，商人永不出现
static var MERCHANT29_FIX := true


static func merchant29_present() -> bool:
	if not MERCHANT29_PAGE_GATE:
		return true
	return MERCHANT29_FIX and XAbyssMerchant.has_merchant(XState.current)


## O-待定·天之上入口（悟空 floor5 地图盘点）：天之上 Map069 六个副本入口（毒蛇沼泽、猛虎岭、洛水河畔、猴山、鹿吴山、火焰之河）
## 第 2 页条件是开关 21「海岸洞窟 捕猎者」，开着时传到 Map102 旅馆 (29,22)；旅馆只有 29×18、没有事件，人落在图外动不了。
## 开关 21 在四层海岸洞窟进副本、打完、逃离、重置时都会打开，之后没有地方关（Map008 EV2 只在洞窟里），做过海岸洞窟的玩家全会撞上。
## 重制让这几处页条件里的开关 21 不算数，照第 1 页进副本。键「地图:事件」→ 不算数的开关号；设为空字典 {} 恢复原版。
static var page_switch_ignore := {"69:47": [21], "69:52": [21], "69:53": [21], "69:55": [21], "69:56": [21], "69:70": [21]}


func _switch_on(s: XState, id: int) -> bool:
	if not page_switch_ignore.is_empty():
		var ign = page_switch_ignore.get("%d:%d" % [map_id, event_id])
		if ign is Array and ign.has(id):
			return false
	return s.switch(id)


func _meets(c: Dictionary) -> bool:
	var s := XState.current
	if s == null:
		return false
	if c.switch1Valid and not _switch_on(s, int(c.switch1Id)):
		return false
	if c.switch2Valid and not _switch_on(s, int(c.switch2Id)):
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


## Game_Event.update：角色更新（停着时 updateStop → 强制路线／自主移动）→ 并行页（updateParallel）→ YEP 警觉与回位计时
func update_character() -> void:
	super.update_character()
	_update_parallel()
	_update_alert()
	if not _ecp.is_empty() and _ecp.return_phase:
		_ecp.return_frames -= 1


func _exit_tree() -> void:
	stop_parallel()


## 终止并行解释器（换页、消除、换图释放事件时）：在它下一个等待点安全结束，不再往下执行
func stop_parallel() -> void:
	if parallel_interp != null:
		parallel_interp.cancel()
		parallel_interp = null


## Game_Event.updateParallel：并行页没有在跑的解释器就从头起一个（交给地图场景，地图不更新时它不起）
func _update_parallel() -> void:
	if trigger() != 4 or parallel_interp != null or erased or Engine.get_physics_frames() == parallel_done_frame:
		return
	var scene = _map_scene()
	if scene != null and scene.has_method("start_parallel"):
		scene.start_parallel(self)


## Game_Event.updateStop：被锁住时停步计数清零；强制路线（基类）；没有强制路线才自主移动
func _update_stop() -> void:
	if locked:
		_idle_count = 0
	super._update_stop()
	if not _route_forcing:
		_update_self_movement()


## YEP_EventChasePlayer 包装的 updateSelfMovement：先按距离进出逃离状态；逃离中每停一帧就走（不看频率、不看锁），
## 逃离结束后过一段时间往原位走；都不是时才走原本的自主移动
func _update_self_movement() -> void:
	if page.is_empty():
		return
	_update_flee_distance()
	if int(_ecp.stagger) > 0:
		_ecp.stagger -= 1
		return
	if _idle_count > 0 and _ecp.flee_player:
		var target := _player_ref()
		if target != null:
			if _roll(6) <= 4:
				move_away_from_character(target)
			else:
				move_random()
	elif _ecp.return_phase:
		_update_move_return()
	else:
		_update_self_movement_base()


## Game_Event.updateSelfMovement（原版）：没被锁住、在画面附近、停够了 30×(5－频率) 帧才动
func _update_self_movement_base() -> void:
	if locked or not _near_screen():
		return
	match int(page.get("moveType", 0)):
		1:
			# 随机移动沿用重制原有节奏（每次等 (5－频率)×30＋0～60 帧随机走一格）
			_move_wait -= 1
			if _move_wait <= 0:
				_move_wait = (5 - move_frequency) * 30 + _wander_roll(0, 60)
				move_straight([2, 4, 6, 8][_wander_roll(0, 3)])
		2:
			if _idle_count > 30 * (5 - move_frequency):
				_move_type_toward_player()
		3:
			if _idle_count > 30 * (5 - move_frequency):
				_update_route()


## Game_Event.moveTypeTowardPlayer：离玩家（横竖格数和）不到 20 格时 4/6 接近、1/6 随机、1/6 往前；远了就随机
func _move_type_toward_player() -> void:
	var target := _player_ref()
	if target == null:
		return
	var dlt := _delta_from(target.grid)
	if absi(dlt.x) + absi(dlt.y) < 20:
		var r := _roll(6)
		if r <= 3:
			move_toward_character(target)
		elif r == 4:
			move_random()
		else:
			move_straight(direction)
	else:
		move_random()


## Game_CharacterBase.isNearTheScreen：交给地图场景按镜头判断；没有场景时算在画面附近
func _near_screen() -> bool:
	var scene = _map_scene()
	if scene != null and scene.has_method("near_screen"):
		return scene.near_screen(self)
	return true


# ---- YEP_EventChasePlayer（正式版启用：Sight Lock 300、See Player、Alert Timer 120、Alert Balloon 1、Return After、Return Wait 180）----
## 只做到逃离（全游戏只有 Map088 四团鬼火的路线脚本「this._fleeRange = 5」）；追逐要 findDirectionTo 寻路，用到时再补
static func _chase_param(key: String, fallback: String) -> String:
	if _ecp_params == null:
		_ecp_params = XDB.plugin("YEP_EventChasePlayer")
	return str((_ecp_params as Dictionary).get(key, fallback))


## clearChaseSettings（Game_Event.setupPage 之后）
func _clear_chase() -> void:
	_ecp = {"alert_balloon": int(_chase_param("Alert Balloon", "1")), "alert_lock": 0, "alert_player": false, "alert_timer": 0,
		"flee_player": false, "flee_range": 0, "flee_speed": move_speed, "default_speed": move_speed,
		"see_player": _chase_param("See Player", "true") == "true", "sight_lock": int(_chase_param("Sight Lock", "300")),
		"return_after": _chase_param("Return After", "true") == "true", "return_wait": int(_chase_param("Return Wait", "180")),
		"return_phase": false, "return_frames": 0, "stagger": 0, "start": grid, "start_dir": direction}


## 路线脚本（指令 45）：YEP 的「this._fleeRange = 5」之类设定
func _route_script(text: String) -> void:
	var re := RegEx.create_from_string("^\\s*this\\._(\\w+)\\s*=\\s*([^;]+?)\\s*;?\\s*$")
	var m := re.search(text)
	var keys := {"fleeRange": "flee_range", "fleeSpeed": "flee_speed", "sightLock": "sight_lock", "returnWait": "return_wait",
		"seePlayer": "see_player", "returnAfter": "return_after", "alertBalloon": "alert_balloon"}
	if m == null or not keys.has(m.get_string(1)) or _ecp.is_empty():
		super._route_script(text)
		return
	var v := m.get_string(2).strip_edges()
	var key: String = keys[m.get_string(1)]
	_ecp[key] = (v == "true") if key in ["see_player", "return_after"] else int(v)


## canSeePlayer：玩家在面朝的方向上（横竖哪边差得多看哪边）；看见就锁定 sight_lock 帧
func _can_see_player(target: MVCharacter) -> bool:
	if not _ecp.see_player:
		return false
	var dlt := _delta_from(target.grid)
	var d := (4 if dlt.x > 0 else 6) if absi(dlt.x) > absi(dlt.y) else (8 if dlt.y > 0 else 2)
	if d == direction:
		_ecp.alert_lock = _ecp.sight_lock
		return true
	return false


## updateFleeDistance／fleeConditions／startEventFlee／endEventFlee
func _update_flee_distance() -> void:
	if erased or int(_ecp.flee_range) <= 0:
		return
	var target := _player_ref()
	if target == null:
		return
	var dlt := _delta_from(target.grid)
	var dis := absi(dlt.x) + absi(dlt.y)
	var flee := false
	if int(_ecp.alert_lock) > 0:
		flee = true
	elif dis <= int(_ecp.flee_range) and _can_see_player(target):
		flee = true
	elif dis <= int(_ecp.flee_range) and not _ecp.see_player:
		_ecp.alert_lock = _ecp.sight_lock
		flee = true
	if flee:
		_ecp.flee_player = true
		move_speed = int(_ecp.flee_speed)
	elif _ecp.flee_player:
		_ecp.flee_player = false
		move_speed = int(_ecp.default_speed)
		if int(_ecp.alert_timer) <= 0:
			_ecp.alert_player = false
		if _ecp.return_after:
			_ecp.return_phase = true
			_ecp.return_frames = _ecp.return_wait


## updateAlert：每帧锁定减一；刚进入逃离时冒气泡、开始警觉计时
func _update_alert() -> void:
	if erased or _ecp.is_empty():
		return
	_ecp.alert_lock -= 1
	if _ecp.flee_player and not _ecp.alert_player:
		if int(_ecp.alert_balloon) >= 0:
			start_balloon(int(_ecp.alert_balloon))
		_ecp.alert_player = true
		_ecp.alert_timer = int(_chase_param("Alert Timer", "120"))
	if _ecp.alert_player:
		_ecp.alert_timer -= 1


## updateMoveReturnAfter：回位等待数完后每停一帧往原位走一步（5/6 走直线、1/6 随机），到了恢复原朝向
func _update_move_return() -> void:
	if int(_ecp.return_frames) > 0:
		return
	var dlt := _delta_from(_ecp.start)
	if absi(dlt.x) > absi(dlt.y):
		if _roll(6) <= 4:
			if not move_straight(4 if dlt.x > 0 else 6) and dlt.y != 0:
				move_straight(8 if dlt.y > 0 else 2)
		else:
			move_random()
	elif dlt.y != 0:
		if _roll(6) <= 4:
			if not move_straight(8 if dlt.y > 0 else 2) and dlt.x != 0:
				move_straight(4 if dlt.x > 0 else 6)
		else:
			move_random()
	if dlt == Vector2i.ZERO:
		_ecp.return_phase = false
		_ecp.return_frames = 0
		direction = int(_ecp.start_dir)   # 原版直接改 _direction（不清停步计数）
		queue_redraw()


## 存档：原版 $gameMap 整个进存档、同版本读档不重设地图（参照 tests/fixtures/save_events_oracle.json）。
## 这里只存玩家看得到的运行时状态：位置（含走到一半的小数位置）、朝向、移动路线改过的图像／不透明度／穿透等，以及强制路线与索引；
## 还有移动生命周期计数：跳跃峰高／剩余帧（_jumpPeak／_jumpCount，跳到一半存档读档后接着在空中走完）、停步与动画计数、随机移动等待（沙僧第六期 S1／P2）。
## 临时消除另存在 XState.erased_events，自开关在 XState.self_switches。
func save_state() -> Dictionary:
	var out := {"page": page_index, "x": grid.x, "y": grid.y, "real": [real.x, real.y], "direction": direction, "pattern": pattern,
		"characterName": character_name, "characterIndex": character_index, "tileId": tile_id, "opacity": opacity,
		"through": through, "transparent": transparent, "directionFix": direction_fix, "walkAnime": walk_anime,
		"stepAnime": step_anime, "moveSpeed": move_speed, "moveFrequency": move_frequency, "priorityType": priority_type,
		"jumpPeak": _jump_peak, "jumpCount": _jump_count, "stopCount": _stop_count, "animeCount": _anime_count, "moveWait": _move_wait}
	if _route_forcing:
		out.forcedRoute = {"route": _route, "index": _route_index, "wait": _route_wait}
	# 自定义路线（移动类型 3）走到哪一条：强制中存记下的原序号
	if int(page.get("moveType", 0)) == 3:
		out.customRoute = {"index": _orig_index if _route_forcing and _has_orig else _route_index, "wait": 0 if _route_forcing else _route_wait}
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
	var custom = d.get("customRoute")
	if custom is Dictionary and int(page.get("moveType", 0)) == 3:
		_route_index = int(custom.get("index", 0))
		_route_wait = int(custom.get("wait", 0))
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
