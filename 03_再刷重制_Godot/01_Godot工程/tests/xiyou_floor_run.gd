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
## - 固定随机种子 seed()；时钟加快（去掉 headless 每帧睡眠、物理帧 600／秒、time_scale 30，见 _fast_clock）。
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
## 最后一段到楼层表末尾，新加的层自动落进最后一段。单个场景过了约 120 秒就在 SEGMENTS 末尾再切一段并新增场景
## （xiyou_floor_run、_b…，场景只设 part）。
## 实测（时钟加快后，并行 2 个）：开局约 2 秒；快速通过每层约 0.9 秒；完整走每层约 2～6 秒，十四层（绕循环边缘、遇敌多）约 23 秒。
## 加快前（time_scale 6、物理 60 帧，dev.054）分七段，第 7 段 173 秒（前缀快速通过 18 层约 125 秒），七段合计约 830 秒；
## 加快后同样七段合计约 160 秒、各段项数不变，于是合成两段（1～12、13～）。
## 二十层（大厅门「进入该层」→ 天才灵魂「干他」打敌群 453 → 交见面礼挑战石日天）加进第 2 段后：1～12 层 37 秒／236 项，13～20 层 61 秒／283 项。
## 二十一层（二十层通关后门第 3 页先关开关 686，O-036 接着出楼层菜单 → 交见面礼挑战六道魔君 457）加进第 2 段后：单跑 13～21 层 59 秒／326 项。
## 二十二层（交见面礼挑战三眼娃 458）加进第 2 段；队伍攻击、魔攻提到 5e13 后（见 _boost_party），本机 7 个并行负载下 13～22 层约 86 秒／348 项，6 个种子全过。

const ENTRY := "res://modes/xiyou/entry.tscn"
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const HUB := 4
const HUB_DOOR := 36
## 进地图／事件结束的帧数上限（按原来每帧约 7 毫秒折成墙钟，见 _within）、走路每步的物理帧上限；超时即判卡流程
const WAIT_MAP := 3000
const WAIT_EVENT := 6000
const WAIT_STEP := 600
## 加快时钟时的 time_scale 与每秒物理帧数（见 _fast_clock）
const FAST_SCALE := 30.0
const FAST_TICKS := 600
const DIR_ACTIONS := {2: "ui_down", 4: "ui_left", 6: "ui_right", 8: "ui_up"}

## 要越过循环地图边缘才走得到的守层者（「地图:事件」）：完整模式检查路上确实绕过了边缘。
## 十四层 Map030 横向循环（scrollType 2），克力之爷 (44,23) 与入口 (18,30) 只在绕过 x=0／59 时相连（正式引擎 canPass 实测）
const WRAP_BOSS := ["30:8"]
## 先交见面礼再挑战的层（地图号）：二十层石日天不交礼时开场公共事件 1399「天道领域」给全队加状态 698 天道*终焉
## （命中 −100%、攻击魔攻 ×0.4、属性伤害 −75%），普通攻击全落空，增强队伍也要打约 2 分钟（正式版同样，交礼是原版的出路）。
## 这些层先给够两种见面礼（物品 182 不朽残渣、变量 206 肝帝积分；公共事件随机要其中一种），再按「缴纳见面礼 → 给」应答，
## 走交礼分支（变量 842＝1 → 1400 天道领域*伪）。十三至十九层不交礼也打得过，照旧走不交礼分支。
## 二十一层六道魔君（457）、二十二层三眼娃（458）开场同 456，二十三层哪吒（459）、二十四层黑熊精（460）不交礼时开场另加强制 6105／6107。值为该层「没交礼物胜后」才置 1 的索礼变量（二十层 868、二十一层 869、二十二层 870、二十三层 871、二十四层 872、二十五层 873、二十六层 874、二十七层 875、二十八层 876），交礼后应仍为 0。
## 二十六层金角银角（462，两名守层者）、二十七层多宝（463）、二十八层镇元子（464）同 459。
const PAY_GIFT := {116: 868, 117: 869, 119: 870, 118: 871, 120: 872, 147: 873, 155: 874, 182: 875, 145: 876}
## 开关 686「前往20层」：二十层过路关后打开，大厅门第 3 页在变量 20＝21 时关掉（O-036：关掉后直接出楼层菜单）
const GATE_SWITCH := 686
## 门里困难／地狱／天灾分支给全员学的挑战技能（六、十一、十六、二十一、二十六层…），普通难度不应学到
const CHALLENGE_SKILLS := [2873, 2874, 2875, 2876, 2877, 2879, 2880, 2881, 2882, 2883, 2892, 2893, 2894, 2895, 2896]
## 各段完整走的起始层（第 part 段从 SEGMENTS[part−1] 走到下一段起始层的前一层；最后一段走到楼层表末尾）
const SEGMENTS := [1, 13]
@export var part := 1
## 本次走路越过循环地图边缘的步数
var wrapped_steps := 0

var results: Array = []
var out_dir := ""
var log_lines: Array = []
var battles := 0
## 战斗时地图上有随机走动事件的场数；战斗期间地图角色位置／朝向／帧变了的战斗
var battles_with_movers := 0
var moved_in_battle := []
## 固定随机种子（-- --seed=N 可换，用来复现）
var seed_value := 20261015


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
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


## 帧数上限是否还没到：时钟加快后每帧不睡、空闲帧快很多，改按墙钟（每帧按原来的约 7 毫秒算），给的实际时间不比原来少
func _within(i: int, timeout: int, t0: int) -> bool:
	if OS.low_processor_usage_mode_sleep_usec == 0:
		return Time.get_ticks_msec() - t0 < timeout * 7
	return i < timeout


func _wait_map(map_id: int, timeout := WAIT_MAP) -> bool:
	var t0 := Time.get_ticks_msec()
	var i := 0
	while _within(i, timeout, t0):
		i += 1
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and not s.busy and not s._menu_open:
			return true
		await get_tree().process_frame
	return false


func _wait_idle(map: XMapScene, timeout := WAIT_EVENT) -> bool:
	var t0 := Time.get_ticks_msec()
	var i := 0
	while _within(i, timeout, t0):
		i += 1
		if not is_instance_valid(map):
			return false
		if not map.busy and not map._menu_open and not map.player.is_moving():
			return true
		await get_tree().process_frame
	return false


## 数遇敌与守层者战斗（XBattleScene 加到地图 ui 层）；核对战斗期间地图角色不动（Scene_Map 战斗时不更新）
func _watch(map: XMapScene) -> void:
	if not map.has_meta("floor_run_watch"):
		map.set_meta("floor_run_watch", true)
		map.ui.child_entered_tree.connect(func(n): if n is XBattleScene: _on_battle(map, n))


func _on_battle(map: XMapScene, battle: XBattleScene) -> void:
	battles += 1
	var before := _char_positions(map)
	var movers := map.events.filter(func(e): return int(e.page.get("moveType", 0)) == 1).size()
	battle.finished.connect(func(_r):
		log_lines.append("战斗统计：Map%03d 敌群%d 回合%d 结果%d" % [map.map_id, battle.logic.troop_id, battle.logic.turn, _r])
		if movers > 0:
			battles_with_movers += 1
		if _char_positions(map) != before:
			moved_in_battle.append([map.map_id, battles]), CONNECT_ONE_SHOT)


func _char_positions(map: XMapScene) -> Array:
	return map.chars.get_children().filter(func(c): return c is MVCharacter).map(func(c): return [c.grid, c.real, c.direction, c.pattern])


func _event(scene: XMapScene, id: int) -> MVEvent:
	for e in scene.events:
		if e.event_id == id:
			return e
	return null


# ---- 楼层表（从内容数据推出） ----

## 大厅传送门第 0 页：条件分歧「变量 20 ＝ N」（111 [1, 20, 0, N, 0]）下的场所移动 201 [0, M, x, y, d, f]。
## 场所移动可能套在选项里（二十层「天才灵魂」过路关：交 99 灵魂结晶或「干他」打敌群 453 后才传送）：取该分支里第一个
## 只套在选项（402）里、不套其他条件的场所移动，answers 为门的应答（先「进入该层」0，再依次是各层选项的下标）。
static func floor_table() -> Array:
	var maps: Array = XMapScene.slice().get("maps", []).map(func(v): return int(v))
	var door := _raw_event(HUB, HUB_DOOR)
	var out := []
	if door.is_empty():
		return out
	var floor_n := -1
	var cond_indent := -1
	## 分支内各缩进最近一条开块指令（111／402／411…）
	var opener := {}
	for c in door.pages[0].list:
		var p: Array = c.parameters
		var code := int(c.code)
		var indent := int(c.indent)
		if code == 111 and p.size() >= 5 and int(p[0]) == 1 and int(p[1]) == 20 and int(p[2]) == 0 and int(p[4]) == 0:
			floor_n = int(p[3])
			cond_indent = indent
			opener = {}
			continue
		if floor_n < 0:
			continue
		if indent <= cond_indent:
			floor_n = -1
			continue
		if code in [111, 402, 411, 403]:
			opener[indent] = c
		elif code == 201 and int(p[0]) == 0 and maps.has(int(p[1])):
			var answers := [0]
			var plain := true
			# 缩进 lv 上最近的开块指令包着缩进 lv+1 的内容
			for lv in range(cond_indent + 1, indent):
				var o = opener.get(lv)
				if o != null and int(o.code) == 402:
					answers.append(int(o.parameters[0]))
				else:
					plain = false
			if plain:
				out.append({"floor": floor_n, "map": int(p[1]), "x": int(p[2]), "y": int(p[3]), "answers": answers})
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


## 守层者第 0 页「缴纳见面礼」的选项下标，再加见面礼对话里「给」的下标
static func _gift_answers(map_id: int, ev_id: int) -> Array:
	var out := []
	for c in _raw_event(map_id, ev_id).pages[0].list:
		if int(c.code) == 102:
			var opts: Array = c.parameters[0]
			if out.is_empty() and opts.has("缴纳见面礼"):
				out.append(opts.find("缴纳见面礼"))
			elif out.size() == 1 and opts.has("给"):
				out.append(opts.find("给"))
	return out


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
		# 攻击、魔攻 5e13：十三层守层者（敌群 111）生命约 7e10 且带减伤状态 1103（5e7 时打不完）；
		# 十六层海王子（敌群 172）生命 1.5e12、每回合回复约 20%，5e9 时一回合只打掉 0.4%。
		# 二十层起守层者（456～458）生命 5e13～1.8e14、每回合回复约 15%，交礼后队伍仍约一半攻击落空：5e11 时每回合伤害与回复相当，
		# 胜负看命中与暴击的随机数，几十到上百回合打不完；而负载下帧序不同（地图事件在战斗中照常随机走动、取随机数），
		# 同一种子在并行全量检查里会走到打不完的分支，按墙钟等待超时（f21_boss_won）。5e13 时无界面模拟 20 个种子都一回合打完。
		# 二十八层镇元子（敌群 464）生命约 6e15、有圣裁之雷（3% 即死，四人同被击倒时全队一回合没）等技能，5e13 时四回合内全队阵亡（f28_boss_won）；
		# 攻击、魔攻提到 3e15（普通攻击 ×4 一击过敌群 464 生命）
		item.params = [5.0e8, 1.0e6, 3.0e15, 5.0e6, 3.0e15, 5.0e6, 1.0e5, 1.0e3]
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
	XGuide.MILESTONE_ENABLED = false   # 区段里程碑会在走路时插进对话（tests/xiyou_guide 另测）
	XSave.dir_override = "user://test_xiyou_floor_run"
	XConfig.path_override = XSave.dir().path_join("options.json")
	_fast_clock(true)
	seed(seed_value)
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
	_check("map_frozen_in_battle", moved_in_battle.is_empty(), moved_in_battle)
	print("战斗中地图有随机走动事件的场数：%d" % battles_with_movers)
	# 收尾：清理测试存档
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	_fast_clock(false)
	var passed := results.filter(func(r): return r.passed).size()
	for l in log_lines:
		print(l)
	print("用时 %.1f 秒，到第 %d 层守层者（共 %d 层），战斗 %d 场" % [(Time.get_ticks_msec() - t0) / 1000.0, last_floor, floors.size(), battles])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "floors": [full_from, last_floor]}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 加快时钟。原来（time_scale 6）快速通过每层约 5.5 秒、完整走每层十几到几十秒，几乎都在等：headless 每帧默认睡 6.9 毫秒
## （OS.low_processor_usage_mode_sleep_usec，约 145 帧／秒，CPU 约 20%）；Godot 4 的 time_scale 只放大 delta 与计时器，
## 不加快物理帧，而地图移动、显示动画（如辛德瑞传送的动画 117 约 2.5 秒）、战斗的 MV 帧都按物理帧走，固定 60 帧／秒。
## 所以去掉每帧睡眠、物理帧提到 FAST_TICKS、time_scale 提到 FAST_SCALE：事件、行走与战斗仍逐帧照常执行（各处 _physics_process
## 都不用 delta，只按帧计数；遇敌按步数），只是跑得快。
func _fast_clock(on: bool) -> void:
	if not has_meta("clock"):
		set_meta("clock", [OS.low_processor_usage_mode_sleep_usec, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])
	var orig: Array = get_meta("clock")
	OS.low_processor_usage_mode_sleep_usec = 0 if on else orig[0]
	Engine.physics_ticks_per_second = FAST_TICKS if on else orig[1]
	Engine.max_physics_steps_per_frame = 64 if on else orig[2]
	Engine.time_scale = FAST_SCALE if on else 1.0


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
	var gate_on := s.switch(GATE_SWITCH)
	var skill_cap := s.variable(8)
	if not await _talk(map, HUB_DOOR, f.answers, tag + "_door", full):
		return false
	if not _check(tag + "_entered", await _wait_map(f.map) and _scene().player.grid == Vector2i(f.x, f.y), [_scene().map_id, _scene().player.grid if _scene() is XMapScene else null]):
		return false
	# 普通难度不走门里困难／地狱／天灾的分支（开关 2500／2494／2489：全员学挑战技能、改技能等级上限变量 8）
	_check(tag + "_normal_difficulty_path", s.variable(8) == skill_cap and s.members().all(func(a): return not CHALLENGE_SKILLS.any(func(k): return a.skill_ids.has(k))), [skill_cap, s.variable(8)])
	# 二十层通关后开关 686 仍开：门第 3 页先关 686，O-036 接着出楼层菜单（一次按门就进二十一层）
	if gate_on and f.floor != 20:
		_check(tag + "_gate_switch_off", not s.switch(GATE_SWITCH))
	map = _scene()
	# 2. 守层者「挑战」
	var boss := boss_of(f.map)
	if not _check(tag + "_boss_found", not boss.is_empty() and boss.choice >= 0, boss):
		return false
	wrapped_steps = 0
	var boss_answers := [boss.choice]
	if PAY_GIFT.has(f.map):
		boss_answers = _gift_answers(f.map, boss.id)
		_check(tag + "_gift_choice", boss_answers.size() == 2, boss_answers)
		s.gain_item(182, 999)
		s.set_variable(206, 99999)
	if not await _talk(map, boss.id, boss_answers, tag + "_boss", full):
		return false
	if full and WRAP_BOSS.has("%d:%d" % [f.map, boss.id]):
		_check(tag + "_boss_wrapped", wrapped_steps > 0, wrapped_steps)
	var idle := await _wait_idle(map, WAIT_EVENT * 3)
	var won := s.variable(20) == n + 1 and s.self_switch(f.map, boss.id, "A")
	if not _check(tag + "_boss_won", idle and won and map.map_id == f.map, [idle, s.variable(20), map.map_id, boss, _boss_debug(map, s)]):
		return false
	if PAY_GIFT.has(f.map):
		_check(tag + "_gift_paid", s.variable(842) == 0 and s.variable(PAY_GIFT[f.map]) == 0, [s.variable(842), s.variable(PAY_GIFT[f.map])])
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


## 守层者战没按时结束时的现场：见面礼变量（842 交了礼、841 随机要哪种）、是否还在战斗、回合与双方生命比例和状态
func _boss_debug(map: XMapScene, s: XState) -> Dictionary:
	var out := {"v842": s.variable(842), "v841": s.variable(841), "busy": map.busy, "in_battle": map._in_battle,
		"msg": map.message.visible, "battles": battles}
	for n in map.ui.get_children():
		if n is XBattleScene:
			var lg: XBattleLogic = n.logic
			out.turn = lg.turn
			out.actors = lg.actors.map(func(a): return [snappedf(a.hp / maxf(a.mhp, 1.0), 0.001), a.state_ids])
			out.enemies = lg.enemies.map(func(e): return [snappedf(e.hp / maxf(e.mhp, 1.0), 0.001), e.state_ids])
	return out


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
