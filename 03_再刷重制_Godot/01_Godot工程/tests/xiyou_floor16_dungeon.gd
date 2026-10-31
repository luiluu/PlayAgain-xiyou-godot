extends Node
## 十六层副本亚特兰蒂斯秘境整段流程：十六层入口（Map033 EV1，特级符文 171）→ Map044 四守卫（敌群 169／170／167／168）
## → 首领「海拉的幻影」（敌群 165）真战斗：第 4 回合战斗内 101 对话、334 完全回复、336 变身 174→175 全部在 XBattleScene 里跑完
## → 战斗胜利 → 宝箱发奖并传回十六层、副本重置。
## 队伍生命攻击都很大（只查流程）；首领战中队伍在变身之前一直眩晕，保证撑到第 4 回合出现对话，变身为 175 之后解除，打完整场。事件走地图场景的 run_event（同玩家调查事件的入口，快速通过不走路）。
## 数值与规则对照由 xiyou_battle_events（8 例）和 xiyou_dungeon（d16.* 参照剧本）承担，这里查流程是否跑得通。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FLOOR_MAP := 33
const DUNGEON_MAP := 44
const RUNE := 171
const BOSS_TROOP := 165
const GUARDS := [3, 4, 5, 6]   # 敌群 169／170／167／168
const BOSS_EVENT := 2
const BOSS_LINE := "很久没有打的这么尽兴了"
const STUN := 29   # 眩晕（行动限制 4：不能行动）
## 各段等待上限（墙钟）。原 90 秒在多车道满负载并行时不够（单跑全程约 51 秒，首领战占一半），放宽到 300 秒，仍在单场 600 秒上限内
const TIMEOUT_MS := 300000
## 眩晕的剩余回合直接拉满：它本是回合末自动解除（1 回合），测试按渲染帧补；战斗主循环按物理帧推进，负载高时一渲染帧可跑多达 8 个物理帧，
## 回合末解除后到下回合角色出手之间可能来不及补，队伍提前打死首领、到不了第 4 回合。拉满后不再依赖补的时机。
const STUN_TURNS := 999999

var results: Array = []
var battles: Array = []   # 每场：{troop, result, turn}


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（传送）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and not s.busy:
			return true
		await get_tree().process_frame
	return false


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 队伍参数：生命极大、攻击魔攻 5e13（一回合打完）；首领战变身之前靠眩晕状态拖到第 4 回合（见 _run_event）
func _party() -> void:
	for a in XState.current.members():
		var eq: Array = a.equip_list()
		var item: Dictionary
		if not eq.is_empty():
			item = eq[0]
		else:
			for id in range(1, 200):
				if XDB.rec("Weapons", id).is_empty():
					continue
				var inst := XGear.create("weapon", id)
				if not inst.is_empty() and a.can_equip(inst):
					XState.current.register_gear(inst)
					a.equips[0] = inst
					item = inst
					break
		if item.is_empty():
			continue
		item.params = [1.0e14, 1.0e6, 5.0e13, 5.0e6, 5.0e13, 5.0e6, 1.0e5, 1.0e3]
		XActor.test_param_max = 1.0e30  # 队伍属性堆过原版上限 99999999（XActor.PARAM_MAX），只在测试里放开
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束。首领战时盯着敌人：第一次变成 175 后把队伍提回很强（返回此刻的信息）
func _run_event(map: XMapScene, id: int, answers: Array, watch_boss := false) -> Dictionary:
	var info := {"done": false, "seen_dialogue_turn": -1, "form_at_transform": 0, "hp_before": 0.0, "turn_at_transform": -1}
	var e := _event(map, id)
	if not _check("event%d_present" % id, e != null):
		return info
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r, "turn": n.logic.turn}), CONNECT_ONE_SHOT))
	XMessageBox.auto_answers = answers.duplicate()
	(func():
		await map.run_event(e)
		info.done = true).call()
	var boosted := false
	var t0 := Time.get_ticks_msec()
	while not info.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		if watch_boss:
			var b := _battle_of(map)
			if b != null and not b.logic.enemies.is_empty():
				var en: XEnemy = b.logic.enemies[0]
				if int(en.enemy_id) == 175:
					if not boosted:
						boosted = true
						info.form_at_transform = int(en.enemy_id)
						info.turn_at_transform = b.logic.turn
						info.hp_before = en.hp
						for a in b.logic.actors:
							a.remove_state(STUN)
				elif not boosted:
					# 变身之前队伍一直眩晕不能行动（剩余回合拉满，回合末不会解除），保证打到第 4 回合
					for a in b.logic.actors:
						if a.is_alive() and not a.is_state_affected(STUN):
							a.add_state(STUN)
						if a.is_state_affected(STUN):
							a.state_turns[STUN] = STUN_TURNS
		await get_tree().process_frame
	return info


func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	# 各工作树共用同一 user://（工程名相同），按进程分目录，免得同时跑的另一份删掉本份的存档／设置
	XSave.dir_override = "user://test_xiyou_floor16_dungeon_%d" % OS.get_process_id()
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261019)
	var s := XState.new_game(3, 1, [8, 9, 10])
	# dev.099 起战斗用本场规则流（主种子只在运行时生成），全局 seed() 管不到；固定主种子才能复现
	s.random_master = XRandomStream.hex64(20261019)
	XState.current = s
	s.gain_item(RUNE, 1)
	s.set_switch(1621, true)   # 副本初始化（CE822）开第一档页
	s.map_id = FLOOR_MAP
	s.x = 20
	s.y = 20
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	_check("floor16_loaded", await _wait_map(FLOOR_MAP))
	var map: XMapScene = _scene()
	# 入口：EV1「挑战副本」
	await _run_event(map, 1, [0])
	if not _check("entered_map44", await _wait_map(DUNGEON_MAP), [_scene().name, battles]):
		_finish()
		return
	map = _scene()
	_check("entered_rune_consumed", s.item_count(RUNE) == 0, s.item_count(RUNE))
	_check("entered_dungeon_vars", int(s.variable(5)) == 1 and int(s.variable(6)) == 11, [s.variable(5), s.variable(6)])
	# 首领在四守卫打完前不出现（变量 113＜4：EV2 没有符合条件的页）
	var locked := _event(map, BOSS_EVENT)
	_check("boss_locked_before_guards", locked == null or locked.command_list().is_empty() or int(s.variable(113)) < 4, s.variable(113))
	# 四守卫
	for g in GUARDS:
		var before := battles.size()
		await _run_event(map, g, [])
		_check("guard%d_battle_won" % g, battles.size() == before + 1 and battles[-1].result == 0, battles.slice(before))
	_check("guards_counted", int(s.variable(113)) == 4, s.variable(113))
	map = _scene()
	# 首领：海拉的幻影（敌群 165）
	_party()
	XMessageBox.transcript.clear()
	var before := battles.size()
	var info := await _run_event(map, BOSS_EVENT, [], true)
	print("战斗：", JSON.stringify(battles), " 对话：", JSON.stringify(XMessageBox.transcript))
	_check("boss_event_finished", info.done)
	_check("boss_battle_won", battles.size() == before + 1 and battles[-1].troop == BOSS_TROOP and battles[-1].result == 0, battles.slice(before))
	_check("boss_transformed_to_175", info.form_at_transform == 175 and info.turn_at_transform >= 4, info)
	var said: Array = XMessageBox.transcript.filter(func(t): return str(t).contains(BOSS_LINE))
	_check("boss_dialogue_once", said.size() == 1, XMessageBox.transcript)
	# 宝箱：再调查首领位，发奖、传回十六层、副本重置。
	# 没有邀请函 179 时变量 106 取随机 1～3，为 1 就出「深渊之门」选项（默认「进入此门」会去 Map050／051）；
	# 出现时选「离开这是非之地」，同样传回十六层并重置副本，结果不随世界随机流变
	map = _scene()
	await _run_event(map, BOSS_EVENT, [1])
	_check("returned_floor16", await _wait_map(FLOOR_MAP))
	_check("dungeon_reset", int(s.variable(5)) == 0 and int(s.variable(450)) == 0 and int(s.variable(113)) == 0, [s.variable(5), s.variable(450), s.variable(113)])
	# 守护者海拉（敌群 796，开关 2303／2307 且变量 20≥31 时首领位的页）：第 3 页在敌人生命≤20% 时出 101 对话。
	# 直接开战（地图场景的 start_battle，同事件里的战斗指令）；开战后把敌人生命压到 15%，等对话出现、队伍打完
	map = _scene()
	XMessageBox.transcript.clear()
	var before_g := battles.size()
	var gdone := {"v": false, "cut": false}
	(func():
		await map.start_battle(796, false, false)
		gdone.v = true).call()
	var gt0 := Time.get_ticks_msec()
	while not gdone.v and Time.get_ticks_msec() - gt0 < TIMEOUT_MS:
		var gb := _battle_of(map)
		if gb != null and not gdone.cut and not gb.logic.enemies.is_empty():
			gdone.cut = true
			gb.logic.enemies[0].hp = maxf(1.0, gb.logic.enemies[0].mhp * 0.15)
		# 对话出现后守护者身上的领域状态很难打穿，直接把它击倒收尾（只查对话跑得完、战斗能正常结束）
		if gb != null and gdone.cut and XMessageBox.transcript.size() > 0 and not gb.logic.enemies.is_empty():
			gdone["kill"] = true
			gb.logic.enemies[0].hp = 0.0
			gb.logic.enemies[0].add_state(1)
		await get_tree().process_frame
	if not gdone.v:
		var gb2 := _battle_of(map)
		if gb2 != null:
			var e0: XEnemy = gb2.logic.enemies[0]
			print("守护者未结束：回合 ", gb2.logic.turn, " 敌人 hp ", e0.hp, "/", e0.mhp, " 死亡 ", e0.is_dead(), " 状态 ", e0.states, " 等待事件 ", gb2.logic.is_event_waiting(), " 队伍 ", gb2.logic.actors.map(func(a): return [a.hp, a.states]))
	_check("guardian_battle_finished", gdone.v and gdone.cut, gdone)
	var gsaid: Array = XMessageBox.transcript.filter(func(t): return str(t).contains("接下来我可要使出全力"))
	_check("guardian_dialogue_once", gsaid.size() == 1, XMessageBox.transcript)
	_finish()


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
