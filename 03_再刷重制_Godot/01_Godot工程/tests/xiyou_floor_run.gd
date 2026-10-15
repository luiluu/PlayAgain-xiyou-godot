extends Node
## 自动流程测试（代替最低限度的试玩）：从新开局走到方桌大厅，再逐层打到当前最高层的守层者。
## 每层：大厅传送门「进入该层」→ 走到守层者「挑战」→ 胜利（变量 20 加一）→ 存档（公共事件 1）→ 读档（XSave.load_slot ＋重建地图场景，
## 同标题画面「读取存档」）→ 核对状态与位置一致 → 在读回的地图上走到辛德瑞「传送」回大厅 → 下一层。
## 三项检查：不卡流程（每一步都有帧数超时）；不报错（SCRIPT ERROR／ERROR: 由 并行测试.py 判失败，本测试另核对事件跳过的指令只记录不判失败）；
## 存读档后状态与位置一致、能接着打下一层。
##
## 楼层表从内容数据推出：大厅传送门（Map004 事件 36）里「变量 20 ＝ N → 场所移动到 Map M」的分支，取切片里有的地图；
## 守层者＝该图上「胜利后变量 20 加一」的事件；回大厅＝该图上场所移动到 Map004 的事件。悟空扩楼层后自动覆盖新层。
##
## 用到的测试辅助（都只为速度或稳定，不改变流程本身）：
## - XMessageBox.auto：文字立即结束，选项按 auto_answers 依次应答（选项下标也从事件数据里按选项文字取）。
## - XBattleScene.force_auto：战斗全自动；XEnemy.force_roll=100：不出神话敌人（神话另由 xiyou_combat 测）。
## - 固定随机种子 seed()、Engine.time_scale=6。
## - 队伍增强：出战成员第一件装备的能力值加到很大并回满。开局等级打不过守层者（一层里德 500 万生命，xiyou_flow 验证必败），
##   本测试查的是流程而不是数值；增强写在装备实例里，随存档一起存读，也顺带验证了装备实例的存读。
## - 移动：按地图通行度（MVTilemap.is_passable、事件碰撞）广度优先寻路，再逐格按方向键行走（玩家输入路径：计步、遇敌、自动战斗）；
##   到事件前一格面向事件后按「确定」（XMapScene._on_action），走的是玩家调查事件的同一入口。寻路避开所有事件格，不误触。
## - 不逛商店、不和其他 NPC 对话。
## 新开局到大厅（Map001 → Map002 → Map221 → Map004）的细节核对见 xiyou_flow；这里只核对到达。
## 窗口模式加 -- --out=<目录> 会在每层守层者战后截图。
##
## 拆场景（并行测试.py 单个测试 300 秒上限）：SEGMENTS 按层指定各场景「完整走」的连续段（寻路行走、遇敌、存读档），
## 之前各层「快速通过」（直接执行传送门、守层者、辛德瑞事件，不走路、不存读档；事件本身照常执行）。part＝第几段（1 起）；
## 最后一段到楼层表末尾，新加的层自动落进最后一段。快速通过每层约 6 秒，所以越靠后的段前缀越长：后段少放几层。
## 单个场景过了约 170 秒就在 SEGMENTS 末尾再切一段并新增场景（xiyou_floor_run、_b、_c、_d、_e、_f、_g…，场景只设 part）。
## 实测（time_scale 6，dev.048 后）：第 4 段（13～14 层）163 秒（14 层绕循环边缘、遇敌多，单层约 69 秒）；第 5 段（15～17 层）146 秒，前缀快速通过 14 层约 90 秒。dev.054：18～19 层合一段 181 秒（前缀 17 层约 115 秒，19 层约 46 秒），拆成第 6 段（18 层）132 秒、第 7 段（19 层）173 秒（前缀快速通过 18 层约 125 秒；单层不能再切，后面再加层时前缀要改成更快的通过方式或另想办法）。

const ENTRY := "res://modes/xiyou/entry.tscn"
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const HUB := 4
const HUB_DOOR := 36
## 进地图／事件结束／走路的帧数上限（time_scale 6 下实际很快；超时即判卡流程）
const WAIT_MAP := 3000
const WAIT_EVENT := 6000
const WAIT_STEP := 600
const DIR_ACTIONS := {2: "ui_down", 4: "ui_left", 6: "ui_right", 8: "ui_up"}

## 要越过循环地图边缘才走得到的守层者（「地图:事件」）：完整模式检查路上确实绕过了边缘。
## 十四层 Map030 横向循环（scrollType 2），克力之爷 (44,23) 与入口 (18,30) 只在绕过 x=0／59 时相连（正式引擎 canPass 实测）
const WRAP_BOSS := ["30:8"]
## 各段完整走的起始层（第 part 段从 SEGMENTS[part−1] 走到下一段起始层的前一层；最后一段走到楼层表末尾）
const SEGMENTS := [1, 5, 9, 13, 15, 18, 19]
@export var part := 1
## 本次走路越过循环地图边缘的步数
var wrapped_steps := 0

var results: Array = []
var out_dir := ""
var log_lines: Array = []
var battles := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（读档重建地图）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set("part", part)
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int, timeout := WAIT_MAP) -> bool:
	for i in range(timeout):
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and not s.busy and not s._menu_open:
			return true
		await get_tree().process_frame
	return false


func _wait_idle(map: XMapScene, timeout := WAIT_EVENT) -> bool:
	for i in range(timeout):
		if not is_instance_valid(map):
			return false
		if not map.busy and not map._menu_open and not map.player.is_moving():
			return true
		await get_tree().process_frame
	return false


## 数遇敌与守层者战斗（XBattleScene 加到地图 ui 层）
func _watch(map: XMapScene) -> void:
	if not map.has_meta("floor_run_watch"):
		map.set_meta("floor_run_watch", true)
		map.ui.child_entered_tree.connect(func(n): if n is XBattleScene: battles += 1)


func _event(scene: XMapScene, id: int) -> MVEvent:
	for e in scene.events:
		if e.event_id == id:
			return e
	return null


# ---- 楼层表（从内容数据推出） ----

## 大厅传送门第 0 页：条件分歧「变量 20 ＝ N」（111 [1, 20, 0, N, 0]）下的场所移动 201 [0, M, x, y, d, f]
static func floor_table() -> Array:
	var maps: Array = XMapScene.slice().get("maps", []).map(func(v): return int(v))
	var door := _raw_event(HUB, HUB_DOOR)
	var out := []
	if door.is_empty():
		return out
	var floor_n := -1
	var cond_indent := -1
	for c in door.pages[0].list:
		var p: Array = c.parameters
		if int(c.code) == 111 and p.size() >= 5 and int(p[0]) == 1 and int(p[1]) == 20 and int(p[2]) == 0 and int(p[4]) == 0:
			floor_n = int(p[3])
			cond_indent = int(c.indent)
		elif int(c.code) == 201 and floor_n > 0 and int(c.indent) == cond_indent + 1 and int(p[0]) == 0:
			if maps.has(int(p[1])):
				out.append({"floor": floor_n, "map": int(p[1]), "x": int(p[2]), "y": int(p[3])})
			floor_n = -1
	out.sort_custom(func(a, b): return a.floor < b.floor)
	# 只取从一层起连续的楼层（中间缺一层就到此为止）
	var cont := []
	for f in out:
		if f.floor != cont.size() + 1:
			break
		cont.append(f)
	return cont


static func _raw_event(map_id: int, ev_id: int) -> Dictionary:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == ev_id:
			return ev
	return {}


## 地图上放了哪些事件（keepEvents，"*" 为全部）
static func _kept(map_id: int, ev_id: int) -> bool:
	var cfg = XMapScene.slice().get("keepEvents", {}).get(str(map_id), [])
	if not cfg is Array:
		return true
	return cfg.map(func(v): return int(v)).has(ev_id)


## 在第 0 页找含某指令的事件，返回 {id, choice}：choice 为包含该指令的选项分支下标（402 [i, 文字]）
static func find_event(map_id: int, pred: Callable) -> Dictionary:
	for ev in XDB.map(map_id).get("events", []):
		if ev == null or not _kept(map_id, int(ev.id)) or ev.pages.is_empty():
			continue
		var branch := -1
		for c in ev.pages[0].list:
			if int(c.code) == 402:
				branch = int(c.parameters[0])
			if pred.call(c):
				return {"id": int(ev.id), "choice": branch, "x": int(ev.x), "y": int(ev.y), "name": str(ev.name)}
	return {}


static func boss_of(map_id: int) -> Dictionary:
	return find_event(map_id, func(c): return int(c.code) == 122 and c.parameters.slice(0, 5) == [20.0, 20.0, 1.0, 0.0, 1.0])


static func return_of(map_id: int) -> Dictionary:
	return find_event(map_id, func(c): return int(c.code) == 201 and int(c.parameters[0]) == 0 and int(c.parameters[1]) == HUB)


# ---- 移动 ----

## 广度优先：从玩家位置走到 goal 相邻且能朝 goal 调查的格；避开所有事件格（不误触）
func _path_to(map: XMapScene, goal: Vector2i) -> Array:
	var tm: MVTilemap = map.lower
	var occupied := {}
	for e in map.events:
		if not e.page.is_empty() and e.grid != goal:
			occupied[e.grid] = true
	var start: Vector2i = map.player.grid
	var prev := {start: null}
	var queue := [start]
	var dirs := [2, 4, 6, 8]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var nxt: Vector2i = tm.round_cell(cur + MVCharacter.dir_offset(d))
			if nxt == goal:
				# 到达：回溯成方向序列，最后一项是面向事件的方向（不移动）
				var path := [d]
				var c = cur
				while prev[c] != null:
					path.push_front(prev[c][1])
					c = prev[c][0]
				return path
			if prev.has(nxt) or occupied.has(nxt):
				continue
			if not tm.is_passable(cur.x, cur.y, d) or not tm.is_passable(nxt.x, nxt.y, MVCharacter.reverse_dir(d)):
				continue
			prev[nxt] = [cur, d]
			queue.append(nxt)
	return []


## 走到事件前并按确定。answers 为选项应答。返回事件是否被触发（之后由调用方等待结果）。
func _walk_and_talk(map: XMapScene, ev_id: int, answers: Array, tag: String) -> bool:
	var e := _event(map, ev_id)
	if not _check(tag + "_event_present", e != null, ev_id):
		return false
	var path := _path_to(map, e.grid)
	if not _check(tag + "_path", not path.is_empty(), [map.map_id, map.player.grid, e.grid]):
		return false
	var steps := 0
	var map_id := map.map_id
	for i in range(path.size() - 1):
		if not await _wait_idle(map):
			return _check(tag + "_walk_idle", false, [map.map_id, map.player.grid])
		if map.map_id != map_id:
			return _check(tag + "_walk_left_map", false, map.map_id)
		var before: Vector2i = map.player.grid
		# 按住方向键直到起步（格子已变）就松开：走的是 MVPlayer.update_character 的键盘输入路径（计步、遇敌、接触事件）
		var action: String = DIR_ACTIONS[path[i]]
		Input.action_press(action)
		var started := false
		for f in range(WAIT_STEP):
			await get_tree().physics_frame
			if map.player.grid != before or map.busy:
				started = true
				break
		Input.action_release(action)
		var expect: Vector2i = map.lower.round_cell(before + MVCharacter.dir_offset(path[i]))
		if not started or map.player.grid != expect:
			return _check(tag + "_walk_step", false, [before, map.player.grid, path[i]])
		if expect != before + MVCharacter.dir_offset(path[i]):
			wrapped_steps += 1
		steps += 1
	if not await _wait_idle(map):
		return _check(tag + "_walk_idle", false, [map.map_id, map.player.grid])
	map.player.set_direction(path[-1])
	XMessageBox.auto_answers = answers.duplicate()
	log_lines.append("%s：走 %d 步到 %s 调查事件 %d（累计步数 %d，遇敌计数 %d）" % [tag, steps, map.player.grid, ev_id, XState.current.steps, map.encounter_count])
	map._on_action()
	await _frames(2)
	return true


# ---- 测试辅助：队伍增强 ----

func _boost_party(s: XState) -> void:
	for a in s.members():
		var eq: Array = a.equip_list()
		var item: Dictionary
		if not eq.is_empty():
			item = eq[0]
		else:
			for id in range(1, 200):
				var rec := XDB.rec("Weapons", id)
				if rec.is_empty():
					continue
				var inst := XGear.create("weapon", id)
				if not inst.is_empty() and a.can_equip(inst):
					s.register_gear(inst)
					a.equips[0] = inst
					item = inst
					break
		if item.is_empty():
			continue
		# 生命、魔法、攻击、防御、魔攻、魔防、敏捷、幸运
		# 攻击、魔攻 5e11：十三层守层者（敌群 111）生命约 7e10 且带减伤状态 1103（5e7 时打不完）；
		# 十六层海王子（敌群 172）生命 1.5e12、每回合回复约 20%，5e9 时一回合只打掉 0.4%
		item.params = [5.0e8, 1.0e6, 5.0e11, 5.0e6, 5.0e11, 5.0e6, 1.0e5, 1.0e3]
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _state_json(s: XState) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(s.to_dict())))


func _first_diff(a: String, b: String) -> Array:
	for i in range(mini(a.length(), b.length())):
		if a[i] != b[i]:
			return [a.substr(maxi(0, i - 60), 140), b.substr(maxi(0, i - 60), 140)]
	return [] if a.length() == b.length() else ["长度不同", a.length(), b.length()]


# ---- 主流程 ----

func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XSave.dir_override = "user://test_xiyou_floor_run"
	XConfig.path_override = XSave.dir().path_join("options.json")
	Engine.time_scale = 6.0
	seed(20261015)
	var t0 := Time.get_ticks_msec()
	var floors := floor_table()
	_check("floor_table", floors.size() >= 1 and floors[0].map == 5, floors)
	var full_from: int = SEGMENTS[part - 1] if part >= 1 and part <= SEGMENTS.size() else floors.size() + 1
	var full_to: int = SEGMENTS[part] - 1 if part < SEGMENTS.size() else floors.size()
	print("楼层表：", JSON.stringify(floors), "；本场景完整走第 %d～%d 层" % [full_from, full_to])
	_check("part_has_floors", full_from <= full_to and full_to <= floors.size(), [part, SEGMENTS, floors.size()])
	await _opening()
	var last_floor := 0
	for f in floors:
		if f.floor > full_to:
			break
		var full: bool = f.floor >= full_from
		var b0 := battles
		if not await _floor(f, full):
			break
		last_floor = f.floor
		print("第 %d 层%s通过（Map%03d），战斗 %d 场，累计 %.1f 秒" % [f.floor, "" if full else "快速", f.map, battles - b0, (Time.get_ticks_msec() - t0) / 1000.0])
	_check("floors_cleared", last_floor == full_to and floors.size() > 0, [last_floor, full_to])
	# 收尾：清理测试存档
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for l in log_lines:
		print(l)
	print("用时 %.1f 秒，到第 %d 层守层者（共 %d 层），战斗 %d 场" % [(Time.get_ticks_msec() - t0) / 1000.0, last_floor, floors.size(), battles])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "floors": [full_from, last_floor]}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 新开局 → 方桌大厅（同 xiyou_flow 的应答：存档位 1、名字、普通难度、狗逍遥、求道者雕像）
func _opening() -> void:
	_check("enter_xiyou", GameApp.enter_mode("xiyou"))
	await _frames(3)
	var entry = _scene()
	_check("xiyou_title", entry.scene_file_path == ENTRY and XDB.available())
	XMessageBox.auto_answers = [0, 0, 0, "流程测试", 0, 2, 0, 0]
	entry._new_game()
	_check("opening_map221", await _wait_map(221, 9000))
	var map: XMapScene = _scene()
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 2))
	var ok := await _wait_map(HUB, WAIT_MAP)
	var s := XState.current
	for i in range(WAIT_MAP):
		if s.self_switch(HUB, 20, "A") and not _scene().busy:
			break
		await get_tree().process_frame
	_check("hub_reached", ok and s.self_switch(HUB, 20, "A") and s.variable(20) == 1, [ok, s.variable(20)])
	_check("hub_saved_slot", XSave.exists(s.fixed_save_slot()), s.fixed_save_slot())
	_boost_party(s)
	log_lines.append("开局到大厅：存档位 %d，队伍 %s" % [s.fixed_save_slot(), s.party])


## 快速通过：直接执行事件（不走路）。完整走：寻路走到事件前按确定。
func _talk(map: XMapScene, ev_id: int, answers: Array, tag: String, full: bool) -> bool:
	if full:
		return await _walk_and_talk(map, ev_id, answers, tag)
	var e := _event(map, ev_id)
	if not _check(tag + "_event_present", e != null, ev_id):
		return false
	XMessageBox.auto_answers = answers.duplicate()
	map.run_event(e)
	await _frames(2)
	return true


func _floor(f: Dictionary, full: bool) -> bool:
	var n: int = f.floor
	var tag := "f%d" % n
	var map: XMapScene = _scene()
	_watch(map)
	var s := XState.current
	if not _check(tag + "_at_hub", map.map_id == HUB and s.variable(20) == n, [map.map_id, s.variable(20)]):
		return false
	# 1. 大厅传送门「进入该层」
	if not await _talk(map, HUB_DOOR, [0], tag + "_door", full):
		return false
	if not _check(tag + "_entered", await _wait_map(f.map) and _scene().player.grid == Vector2i(f.x, f.y), [_scene().map_id, _scene().player.grid if _scene() is XMapScene else null]):
		return false
	map = _scene()
	# 2. 守层者「挑战」
	var boss := boss_of(f.map)
	if not _check(tag + "_boss_found", not boss.is_empty() and boss.choice >= 0, boss):
		return false
	wrapped_steps = 0
	if not await _talk(map, boss.id, [boss.choice], tag + "_boss", full):
		return false
	if full and WRAP_BOSS.has("%d:%d" % [f.map, boss.id]):
		_check(tag + "_boss_wrapped", wrapped_steps > 0, wrapped_steps)
	var idle := await _wait_idle(map, WAIT_EVENT * 3)
	var won := s.variable(20) == n + 1 and s.self_switch(f.map, boss.id, "A")
	if not _check(tag + "_boss_won", idle and won and map.map_id == f.map, [idle, s.variable(20), map.map_id, boss]):
		return false
	_check(tag + "_clear_toast", map.toasts.any(func(t): return str(t).begins_with("通关神魔之塔第")), map.toasts.slice(-4))
	await _shot("%02d_守层者战后.png" % n)
	if not full:
		return await _return_hub(map, f, tag, false)
	# 3. 存档（公共事件 1：存到开局选的固定存档位）
	var slot := s.fixed_save_slot()
	var toasts_before := map.toasts.size()
	await map.run_common_event(1)
	_check(tag + "_saved", map.toasts.slice(toasts_before).has("存档成功，储存到了%d号存档！" % slot), map.toasts.slice(toasts_before))
	var before := _state_json(s)
	var pos: Vector2i = map.player.grid
	var dir: int = map.player.direction
	# 4. 读档：同标题画面「读取存档」——XSave.load_slot 后重建地图场景
	if not _check(tag + "_load", XSave.load_slot(slot)):
		return false
	_check(tag + "_load_state_same", _state_json(XState.current) == before, _first_diff(before, _state_json(XState.current)))
	get_tree().change_scene_to_file(MAP_SCENE)
	await _frames(2)
	if not _check(tag + "_reloaded", await _wait_map(f.map), _scene().get_class()):
		return false
	map = _scene()
	_watch(map)
	s = XState.current
	_check(tag + "_reload_pos", map.player.grid == pos and map.player.direction == dir, [pos, dir, map.player.grid, map.player.direction])
	_check(tag + "_reload_boss_beaten", s.self_switch(f.map, boss.id, "A") and s.variable(20) == n + 1 and s.members().all(func(a): return a.hp > 0))
	# 5. 在读回的地图上走到辛德瑞「传送」回大厅（能接着打）
	return await _return_hub(map, f, tag, true)


func _return_hub(map: XMapScene, f: Dictionary, tag: String, full: bool) -> bool:
	var back := return_of(f.map)
	if not _check(tag + "_return_found", not back.is_empty() and back.choice >= 0, back):
		return false
	if not await _talk(map, back.id, [back.choice], tag + "_return", full):
		return false
	# 回到的格子照该事件的场所移动指令，再按 MVInterpreter.TRANSFER_FIX（O-027：七层辛德瑞原版传到大厅水面 (12,18)，改到 (14,23)）
	var dest := Vector2i(-1, -1)
	for c in _raw_event(f.map, back.id).pages[0].list:
		if int(c.code) == 201 and int(c.parameters[0]) == 0 and int(c.parameters[1]) == HUB:
			dest = Vector2i(int(c.parameters[2]), int(c.parameters[3]))
			dest = MVInterpreter.TRANSFER_FIX.get("%d:%d:%d:%d:%d" % [f.map, back.id, HUB, dest.x, dest.y], dest)
			break
	return _check(tag + "_back_hub", await _wait_map(HUB) and _scene().player.grid == dest, [_scene().map_id, _scene().player.grid, dest])
