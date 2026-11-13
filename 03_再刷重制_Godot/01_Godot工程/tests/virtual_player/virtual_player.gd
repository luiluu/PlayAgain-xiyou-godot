extends Node
## 虚拟玩家（原型，cc 2026-11-13）：一个只靠「按键」玩游戏的机器人，用来把标题 → 开局 → 大厅 → 地图 → 战斗这条流程自动走一遍。
## 和 xiyou_flow 的区别：xiyou_flow 是写死的剧本，直接调场景的私有函数（entry._new_game、map.run_event、m._ok）；
## 这里对游戏只做两件事：读状态（只读，判断现在是哪种画面）、发按键（Input.parse_input_event，和真按键同一条路）。
## 所以它走到的地方就是玩家按键能走到的地方，卡住、按键没反应、界面关不掉这类问题会被它撞上。
##
## 结构：observe()（认画面）→ 各画面的策略（_act_*）→ _tap()（按键）；看门狗盯「画面签名」长时间不变；
## 每一步查不变量（生命不越界、金币不为负）；跑完 report() 给出时间线、到过的地图、触发过的事件、战斗、卡住记录。
## 用法见 tests/xiyou_virtual_player.gd（专项）与 07_开发环境/虚拟玩家.py（单独长跑）。
## 不写 class_name：只给测试用，不进全局类表。

const ENTRY := "res://modes/xiyou/entry.tscn"
const KEYS := {"accept": KEY_ENTER, "cancel": KEY_ESCAPE, "up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "f": KEY_F}
const DIR_KEY := {2: "down", 4: "left", 6: "right", 8: "up"}

## ---- 参数（开跑前设） ----
var rng_seed := 20261113
var max_ticks := 3000              # 一步＝观察一次＋做一个动作
var stuck_ticks := 120             # 画面签名这么多步不变算卡住一次
var max_stuck := 3                 # 连续卡住这么多次就放弃（报告里记 aborted）
var battle_manual_actions := 60    # 一场战斗手动按这么多步还没完，就打开自动战斗（报告里记 assist）
var overlay_monkey_max := 10       # 每次进菜单／子页先随手按最多这么多下再退出
var battle_give_up := 1500         # 一场战斗最多这么多步
var settle_ticks := 800            # 目标达到／步数用完后，最多再走这么多步把手头的画面收完
var goals: Array = []              # 里程碑名字，全部达到就提前收工；空＝跑满 max_ticks
var out_dir := ""                  # 给了就在画面切换时截图（无头模式不截）
var verbose := false

## ---- 结果 ----
var ticks := 0
var timeline: Array = []           # [{tick, frame, screen, detail}]：只在画面种类变了的时候记
var milestones: Dictionary = {}    # 名字 → 第几步达到
var maps_seen: Dictionary = {}     # 地图号 → 进去的次数
var event_visits: Dictionary = {}  # "地图:事件" → 试着触发的次数
var battles: Array = []            # [{map, start, end, actions, assist, result}]
var stuck_log: Array = []          # [{tick, screen, signature}]
var violations: Array = []         # 不变量不成立的记录
var key_count := 0
var choice_counts: Dictionary = {} # "地图|选项们" → 每个选项选过几次
var messages_seen := 0
var transcript: Array = []         # 最近 300 条对话与选项（截短）
var _msg_hash := 0
var _violation_seen := {}
var _unreach_logged := {}
var aborted := ""
var settled := false

var _rng := RandomNumberGenerator.new()
var _last_screen := ""
var _sig = null
var _sig_tick := 0
var _stuck_streak := 0
var _block_count := 0
var _target := {}                  # {key, event_id, cell, face}
var _battle = null                 # 当前战斗的记录
var _shots := 0
var _busy_ticks := 0
var _overlay_budget := 0


func _log(msg: String) -> void:
	if verbose:
		print("[vp %d] %s" % [ticks, msg])


func _mark(name: String) -> void:
	if not milestones.has(name):
		milestones[name] = ticks
		_log("里程碑 " + name)


# ---------------------------------------------------------------- 按键

func _event(name: String, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEYS[name]
	e.physical_keycode = KEYS[name]
	e.pressed = pressed
	return e


## 按一下：按下，跨过几个物理帧和画面帧再松开（同一帧按下又松开时轮询 is_action_just_pressed 的地方会漏）
func _tap(name: String, hold := 2) -> void:
	key_count += 1
	Input.parse_input_event(_event(name, true))
	for i in hold:
		await get_tree().physics_frame
		await get_tree().process_frame
	Input.parse_input_event(_event(name, false))
	await get_tree().process_frame


## 鼠标左键点一下（1280×720 画面坐标）。只用在没有键盘入口的地方，比如地图上的传送按钮。
func _click(pos: Vector2) -> void:
	key_count += 1
	pos = get_tree().root.get_final_transform() * pos   # 画面坐标 → 窗口坐标（窗口缩放、无头模式 64×64 窗口都对得上）
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ---------------------------------------------------------------- 观察（只读）

func _scene() -> Node:
	return get_tree().current_scene


func _find_ui(map: Node, cls) -> Node:
	for c in map.ui.get_children():
		if is_instance_of(c, cls) and not c.is_queued_for_deletion():
			return c
	return null


## 现在是哪种画面。返回 {screen, …}；screen 取：
## none 场景切换中／boot 开场还没到标题／title 标题／form 标题下的按钮页（选存档位、难度、阵容）／
## battle 战斗／transfer 地图传送页／game_over 结束画面／choice 选项／number 数字输入／message 对话／overlay 地图上盖着菜单或子页／
## map_busy 地图在跑事件／map 地图空闲／other 别的场景
func observe() -> Dictionary:
	var s := _scene()
	if s == null:
		return {"screen": "none"}
	if s.scene_file_path == ENTRY:
		if s.has_method("is_title_page") and s.is_title_page():
			return {"screen": "title", "entry": s}
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and s.is_ancestor_of(f):
			return {"screen": "form", "entry": s, "focus": f}
		return {"screen": "boot", "entry": s}
	if s is XMapScene:
		if s.player == null:
			return {"screen": "none"}
		var b := _find_ui(s, XBattleScene)
		if b != null:
			return {"screen": "battle", "map": s, "battle": b}
		var go := _find_ui(s, XGameOverScreen)
		if go != null:
			return {"screen": "game_over", "map": s}
		var m: XMessageBox = s.message
		if m != null and m.is_busy():
			var mode := str(m._input_mode)
			if mode == "choice":
				return {"screen": "choice", "map": s, "message": m, "count": m._choices.size(), "index": int(m._choice_index)}
			return {"screen": "number" if mode == "number" else "message", "map": s, "message": m}
		if s.transfer_page != null and is_instance_valid(s.transfer_page):
			return {"screen": "transfer", "map": s, "page": s.transfer_page}
		if s._menu_open or not s._scene_pages.is_empty() or _find_ui(s, XShop) != null:
			return {"screen": "overlay", "map": s}
		if s.busy:
			return {"screen": "map_busy", "map": s}
		return {"screen": "map", "map": s}
	return {"screen": "other"}


## 画面签名：这一串不变＝游戏没在往前走。看门狗用。
func _signature(obs: Dictionary) -> Array:
	var sig := [obs.screen, messages_seen, XToast.shown.size()]
	if obs.has("message"):
		sig.append(obs.message._page_glyphs.size())
	match obs.screen:
		"title", "boot", "form":
			var f := get_viewport().gui_get_focus_owner()
			sig.append(str(f.name) if f != null else "")
			sig.append(obs.entry._layer.get_instance_id() if obs.entry.get("_layer") != null else 0)
		"battle":
			var lg = obs.battle.logic
			sig.append(int(lg.turn))
			var hp := 0
			for e in lg.enemies:
				hp += int(e.hp)
			for a in lg.actors:
				hp += int(a.hp)
			sig.append(hp)
		_:
			if obs.has("map"):
				sig.append(obs.map.map_id)
				sig.append(obs.map.player.grid)
				sig.append(obs.map.running_event_id)
				if obs.has("index"):
					sig.append(obs.index)
				if obs.has("page"):
					sig.append([obs.page.mode, obs.page.index])
	return sig


func _check_invariants() -> void:
	var st := XState.current
	if st == null:
		return
	if int(st.gold) < 0:
		_violate("金币为负", 0, st.gold, true)
	for a in st.members():
		var id: int = a.actor_id if a.get("actor_id") != null else 0
		if a.hp < 0:
			_violate("生命为负", id, [a.hp, a.mhp], true)
		elif a.hp > a.mhp:
			_violate("生命高于上限", id, [a.hp, a.mhp], false)   # 存疑：可能是战斗里上限被压低的瞬间，要人看


## 同一种问题、同一个角色只记第一次。hard＝一定是错；否则是「存疑」，报告里列出来给人看
func _violate(what: String, actor: int, value, hard: bool) -> void:
	var key := "%s#%d" % [what, actor]
	if _violation_seen.has(key):
		return
	_violation_seen[key] = true
	violations.append({"tick": ticks, "what": what, "actor": actor, "value": value, "hard": hard, "screen": _last_screen, "map": _last_map})


# ---------------------------------------------------------------- 主循环

func run() -> Dictionary:
	_rng.seed = rng_seed
	while ticks < max_ticks and aborted == "":
		var obs := observe()
		_note_screen(obs)
		_check_invariants()
		_note_message(obs)
		if _watchdog(obs):
			await _recover(obs)
		else:
			await _act(obs)
		ticks += 1
		if not goals.is_empty() and goals.all(func(g): return milestones.has(g)):
			break
	await _settle()
	_close_battle(observe(), "未结束")
	return report()


## 收工前把手头的画面走完（对话、过场、战斗、子页），停在地图空闲或标题上：
## 事件跑到一半就退出，悬着的协程会让引擎报资源没释放（并行测试把它算失败）
func _settle() -> void:
	var extra := 0
	while extra < settle_ticks and aborted == "":
		var obs := observe()
		_note_screen(obs)
		_note_message(obs)
		if obs.screen == "title" or (obs.screen == "map" and not obs.map.player.is_moving()):
			break
		if obs.screen == "map":
			await _frames(1)
		elif _watchdog(obs):
			await _recover(obs)
		else:
			await _act(obs)
		ticks += 1
		extra += 1
	settled = extra < settle_ticks and aborted == ""


## 机器人自己记对话（XMessageBox.transcript 只在自动应答模式下才记）：消息内容换了就算新的一条
func _note_message(obs: Dictionary) -> void:
	if not obs.has("message"):
		return
	var h := hash(obs.message._msg)
	if h == _msg_hash:
		return
	_msg_hash = h
	messages_seen += 1
	var lines: Array = obs.message._msg.get("lines", [])
	var text := XMVText.plain(" ".join(lines)).left(80)
	if obs.message._msg.has("choices"):
		text += " 〔选项：%s〕" % " / ".join(obs.message._msg.choices).left(80)
	transcript.append(text)
	if transcript.size() > 300:
		transcript.pop_front()


func _note_screen(obs: Dictionary) -> void:
	var screen: String = obs.screen
	if screen == "battle":
		if _battle == null:
			_battle = {"map": obs.map.map_id, "start": ticks, "actions": 0, "assist": false, "enemies": obs.battle.logic.enemies.size()}
			_mark("battle_started")
	elif screen != "none":
		_close_battle(obs, "结束")
	if obs.has("map"):
		var id: int = obs.map.map_id
		if _last_map != id:
			_last_map = id
			maps_seen[id] = int(maps_seen.get(id, 0)) + 1
			_target = {}
			_mark("map_%d" % id)
			if maps_seen.size() == 1:
				_mark("in_game")
			elif maps_seen.size() == 2:
				_mark("second_map")
	if screen == _last_screen:
		return
	if screen == "overlay" and _last_screen != "message" and _last_screen != "choice":
		_overlay_budget = _rng.randi_range(0, overlay_monkey_max)
	_last_screen = screen
	var row := {"tick": ticks, "frame": Engine.get_process_frames(), "screen": screen}
	if obs.has("map"):
		row["map"] = obs.map.map_id
		row["at"] = [obs.map.player.grid.x, obs.map.player.grid.y]
	timeline.append(row)
	_log("画面 → %s" % JSON.stringify(row))
	if screen == "title":
		_mark("title")
	_shot(screen)

var _last_map := -1


func _close_battle(obs: Dictionary, how: String) -> void:
	if _battle == null:
		return
	_battle["end"] = ticks
	var res := how
	if obs.has("map"):
		if obs.screen == "game_over" or obs.map.last_battle_game_over:
			res = "全灭"
		elif obs.map.last_battle_escaped:
			res = "逃跑"
		elif how == "结束":
			res = "胜利"
	_battle["result"] = res
	battles.append(_battle)
	_battle = null
	if how == "结束":
		_mark("battle_finished")
		if res == "胜利":
			_mark("battle_won")


func _shot(tag: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless" or _shots >= 200:
		return
	_shots += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%03d_%s.png" % [_shots, tag]))


func _watchdog(obs: Dictionary) -> bool:
	var sig := _signature(obs)
	if sig != _sig:
		_sig = sig
		_sig_tick = ticks
		_stuck_streak = 0
		return false
	if ticks - _sig_tick < stuck_ticks:
		return false
	_sig_tick = ticks
	_stuck_streak += 1
	stuck_log.append({"tick": ticks, "screen": obs.screen, "signature": str(sig)})
	_log("卡住 %d：%s" % [_stuck_streak, str(sig)])
	if _stuck_streak >= max_stuck:
		aborted = "卡在 %s：%s" % [obs.screen, str(sig)]
	return true


## 卡住时换个按法：取消、确定、随便一个方向
func _recover(_obs: Dictionary) -> void:
	_target = {}
	await _tap("cancel")
	await _frames(3)
	await _tap(["up", "down", "left", "right"][_rng.randi_range(0, 3)], 6)
	await _tap("accept")


func _act(obs: Dictionary) -> void:
	match obs.screen:
		"none", "other":
			await _frames(2)
		"boot":
			await _tap("accept")      # 开场动画、声明屏：按键跳过
			await _frames(3)
		"title":
			await _act_title(obs)
		"form":
			await _act_form(obs)
		"battle":
			await _act_battle(obs)
		"game_over":
			_mark("game_over")
			await _tap("accept")
			await _frames(5)
		"choice":
			await _act_choice(obs)
		"number", "message":
			await _tap("accept")
		"transfer":
			await _act_transfer(obs)
		"overlay":
			# 菜单、商店、子页（种族祝福、衣橱……）：先随手按几下（确定为主，夹着方向键），再按取消一路退出来
			_mark("overlay_seen")
			if _overlay_budget > 0:
				_overlay_budget -= 1
				var r := _rng.randf()
				await _tap("accept" if r < 0.5 else "down" if r < 0.75 else "right" if r < 0.9 else "up")
			else:
				await _tap("cancel")
			await _frames(3)
		"map_busy":
			# 事件在跑（过场、移动路线、等待）：等着；等得久了按一下确定（有的演出要按键）
			_busy_ticks += 1
			if _busy_ticks % 20 == 0:
				await _tap("accept")
			else:
				await _frames(4)
		"map":
			_busy_ticks = 0
			await _act_map(obs)


# ---------------------------------------------------------------- 标题与开局

func _act_title(obs: Dictionary) -> void:
	var entry = obs.entry
	var want := -1
	var sel := 0
	var tq = entry.get("_tq_title")
	if tq != null and is_instance_valid(tq) and tq.is_title_page():
		if tq.state().entering:
			await _tap("accept")     # 进场动画：任意键跳到最终画面
			return
		sel = tq.selected()
		for i in tq.item_count():
			if str(tq.item(i).key) == "new_game":
				want = i
	else:
		sel = int(entry._sel)
		want = 0                      # 原版标题第一项「新的游戏」
	if want < 0:
		aborted = "标题上找不到「新的游戏」"
		return
	if sel == want:
		_mark("new_game_pressed")
		await _tap("accept")
		await _frames(4)
	else:
		await _tap("down" if want > sel else "up")


## 标题下的按钮页：按名字挑要按的按钮（空存档位 → 第一档没锁的难度 → 确认阵容），用方向键把焦点挪过去再按确定。
## 认不出的页面就按当前焦点。
func _act_form(obs: Dictionary) -> void:
	var entry = obs.entry
	var focus: Button = obs.focus
	var buttons: Array = entry.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE)
	var want: Button = null
	for b in buttons:
		if str(b.name) == "TianqiConfirm":
			want = b
			break
	if want == null:
		for b in buttons:
			if str(b.name).begins_with("TianqiDifficulty_"):
				want = b
				break
	if want == null:
		for b in buttons:
			var n := str(b.name)
			if n.begins_with("TianqiSlot") and not XSave.exists(int(n.substr(10))):
				want = b
				break
	if want == null or want == focus:
		_mark("form_pressed")
		await _tap("accept")
		await _frames(4)
		return
	# 焦点按 Godot 的邻居规则走：目标在下方／右方就按下／右，否则反向；到不了时看门狗接手
	var d: Vector2 = want.global_position - focus.global_position
	var key := ("down" if d.y > 0 else "up") if absf(d.y) > 4.0 else ("right" if d.x > 0 else "left")
	await _tap(key)


# ---------------------------------------------------------------- 对话选项

func _act_choice(obs: Dictionary) -> void:
	var n: int = obs.count
	if n <= 0:
		await _tap("accept")
		return
	# 同一组选项里优先选没选过的（次数最少的，同次数随机），这样门、向导这类多分支的事件会被逐个试到
	var ckey := "%d|%s" % [obs.map.map_id, "/".join(obs.message._choices.map(func(c): return str(c)))]
	var counts: Array = choice_counts.get(ckey, [])
	while counts.size() < n:
		counts.append(0)
	var want := 0
	var low := INF
	for i in n:
		var sc: float = int(counts[i]) + _rng.randf() * 0.5
		if sc < low:
			low = sc
			want = i
	counts[want] = int(counts[want]) + 1
	choice_counts[ckey] = counts
	var cur: int = obs.index
	var guard := 0
	while cur != want and guard < n + 2:
		await _tap("down" if want > cur else "up")
		await _frames(1)
		var again := observe()
		if again.screen != "choice":
			return
		cur = again.index
		guard += 1
	_mark("choice_made")
	await _tap("accept")


# ---------------------------------------------------------------- 地图传送页

## 传送页：在列表里找一张能传、去得最少的地图，方向键挪过去 → 确定（进掉落选择）→ F（传送）→ 确定。
func _act_transfer(obs: Dictionary) -> void:
	var page = obs.page
	match str(page.mode):
		"list":
			var list: Array = XMapTransfer.maps()
			var want := -1
			var best := INF
			for i in list.size():
				var m: Dictionary = list[i]
				if not XMapTransfer.can_transfer(XState.current, m):
					continue
				var target: int = XMapTransfer.target_map(m)
				if target == obs.map.map_id:
					continue
				var score := int(maps_seen.get(target, 0)) * 100.0 + i
				if score < best:
					best = score
					want = i
			if verbose:
				_log("传送列表：" + str(list.slice(0, 14).map(func(m): return [int(m.id), str(m.get("name", "")), XMapTransfer.can_transfer(XState.current, m), XMapTransfer.is_locked(XState.current, m), bool(m.canTransfer)])))
			if want < 0:
				_mark("transfer_nothing")
				await _tap("cancel")
			elif int(page.index) == want:
				await _tap("accept")
			else:
				await _tap("down" if want > int(page.index) else "up")
		"drops":
			_mark("transfer_used")
			await _tap("f")
			await _frames(2)
			if is_instance_valid(page) and str(page.mode) == "drops":
				await _tap("cancel")     # 这张图传不了：回列表（看门狗兜底）
		"confirm":
			await _tap("accept")
			await _frames(4)
		_:
			await _tap("accept")


# ---------------------------------------------------------------- 战斗

## 手动打：指令窗第一项（攻击）→ 目标确定，一路按确定。
## 手动步数用完时看敌人血量：掉了一半以上就开自动战斗打完（报告记 assist）；几乎没掉（打不动的对手）就像玩家一样去选「逃跑」；
## 逃不掉也打不完，到 battle_give_up 步就收工（报告记 aborted）。
func _act_battle(obs: Dictionary) -> void:
	var b = obs.battle
	var hp := 0.0
	for e in b.logic.enemies:
		hp += float(e.hp)
	if _battle != null:
		_battle.actions += 1
		if not _battle.has("hp0"):
			_battle["hp0"] = hp
		if _battle.actions > battle_give_up:
			aborted = "战斗 %d 步没打完也逃不掉（地图 %d）" % [_battle.actions, _battle.map]
			return
		if _battle.actions == battle_manual_actions + 1:
			if hp <= float(_battle.hp0) * 0.5:
				_battle.assist = true
				b.logic.auto = true
				_log("战斗超过手动步数，敌人血量过半已掉，打开自动")
			else:
				_battle["escaping"] = true
				_mark("escape_tried")
				_log("战斗超过手动步数，敌人血量几乎没掉，改选逃跑")
	if b.logic.auto:
		await _frames(6)
		return
	var cmd = b.cmd_win
	if _battle != null and _battle.get("escaping", false) and cmd != null and is_instance_valid(cmd) and cmd.active and cmd.is_visible_in_tree() and str(b._target_mode) == "":
		var list = b.list_win
		if list != null and is_instance_valid(list) and list.active and list.is_visible_in_tree():
			await _tap("cancel")
			return
		var want := -1
		for i in cmd.entries.size():
			if str(cmd.entries[i].get("text", "")).contains("逃跑") and bool(cmd.entries[i].get("enabled", true)):
				want = i
		if want < 0:
			_battle.escaping = false     # 这场不能逃：只好自动打
			_battle.assist = true
			b.logic.auto = true
			return
		if int(cmd.index) != want:
			await _tap("down" if want > int(cmd.index) else "up")
			return
	await _tap("accept")
	await _frames(3)


# ---------------------------------------------------------------- 地图探索

## 地图空闲：挑一个最少去过、走得到的事件，走过去按确定（接触类事件走上去）。没有目标就随便走一步。
func _act_map(obs: Dictionary) -> void:
	var map: XMapScene = obs.map
	var p: MVPlayer = map.player
	if p.is_moving():
		await _frames(1)
		return
	if _target.is_empty() or _target.get("map") != map.map_id:
		_plan(map)
		if _target.is_empty():
			await _tap(DIR_KEY[[2, 4, 6, 8][_rng.randi_range(0, 3)]], 6)
			return
	if _arrived(p):
		await _interact(map)
		return
	# 每一步都从现在的位置重新找路（按住方向键可能多走一格、路上的人会动），不照着一条算好的路硬走
	var d := _dir_toward(p, _target.cell)
	if d == 0:
		_target = {}
		return
	var from := p.grid
	Input.parse_input_event(_event(DIR_KEY[d], true))
	key_count += 1
	for i in 40:
		await get_tree().process_frame   # 按键要到画面帧才送达
		if p.grid != from or not is_instance_valid(map) or map.busy:
			break
	Input.parse_input_event(_event(DIR_KEY[d], false))
	await get_tree().process_frame
	if is_instance_valid(p) and p.grid == from:
		_block_count += 1
		if _block_count >= 3:        # 连着三次没走动（被挡）：换目标
			_block_count = 0
			_target = {}
	else:
		_block_count = 0


## 从玩家脚下广搜（和玩家同一套通行判定）。返回 {dist: 格 → 步数, prev: 格 → [上一格, 方向]}
func _bfs(p: MVPlayer) -> Dictionary:
	var tm = p.tilemap
	var dist := {p.grid: 0}
	var prev := {}
	var queue := [p.grid]
	var head := 0
	while head < queue.size() and queue.size() < 20000:
		var c: Vector2i = queue[head]
		head += 1
		for d in [2, 4, 6, 8]:
			if not p.can_pass_at(c, d):
				continue
			var to: Vector2i = tm.round_cell(c + MVCharacter.dir_offset(d))
			if dist.has(to):
				continue
			dist[to] = dist[c] + 1
			prev[to] = [c, d]
			queue.append(to)
	return {"dist": dist, "prev": prev}


## 去 cell 的第一步方向；走不到返回 0
func _dir_toward(p: MVPlayer, cell: Vector2i) -> int:
	var prev: Dictionary = _bfs(p).prev
	if not prev.has(cell):
		return 0
	var c := cell
	var d := 0
	while prev.has(c):
		d = prev[c][1]
		c = prev[c][0]
	return d


func _arrived(p: MVPlayer) -> bool:
	return p.grid == _target.cell


func _visit(key: String) -> void:
	event_visits[key] = int(event_visits.get(key, 0)) + 1


func _interact(map: XMapScene) -> void:
	var p: MVPlayer = map.player
	var face: int = _target.get("face", 0)
	if _target.has("click"):
		var pos: Vector2 = _target.click
		_target = {}
		await _click(pos)
		await _frames(4)
		return
	_mark("event_tried")
	if face != 0 and p.direction != face:
		await _tap(DIR_KEY[face], 3)   # 朝向事件（被挡着走不动，只转身；接触类事件这一下就触发）
		if observe().screen != "map":
			_target = {}
			return
	await _tap("accept", 3)
	await _frames(2)
	if verbose and is_instance_valid(map):
		_log("互动 %s 后：画面 %s 朝向 %d 位置 %s" % [str(_target.get("key")), observe().screen, map.player.direction, str(map.player.grid)])
	_target = {}


## 从玩家脚下广搜（和玩家同一套通行判定），给每个可触发事件算「站哪一格、朝哪边」，按去过的次数和距离挑一个
func _plan(map: XMapScene) -> void:
	var p: MVPlayer = map.player
	var tm = p.tilemap
	var dist: Dictionary = _bfs(p).dist
	if verbose and not _unreach_logged.has("grid%d" % map.map_id):
		_unreach_logged["grid%d" % map.map_id] = true
		for y in tm.height:
			var row := ""
			for x in tm.width:
				var ch := "#" if dist.has(Vector2i(x, y)) else "."
				for e in map.events:
					if e.grid == Vector2i(x, y) and not e.page.is_empty():
						ch = "E" if e.is_normal_priority() else "e"
				if p.grid == Vector2i(x, y):
					ch = "@"
				row += ch
			print(row)
	var best := {}
	var best_score := INF
	for e in map.events:
		if e.erased or e.page.is_empty() or not [0, 1, 2].has(e.trigger()) or e.command_list().size() <= 1:
			continue
		var key := "%d:%d" % [map.map_id, e.event_id]
		var stand := Vector2i(-1, -1)
		var face := 0
		var steps := INF
		if e.is_normal_priority():
			for d in [2, 4, 6, 8]:
				var c: Vector2i = tm.round_cell(e.grid - MVCharacter.dir_offset(d))
				if dist.has(c) and dist[c] < steps:
					steps = dist[c]
					stand = c
					face = d
		elif dist.has(e.grid):
			steps = dist[e.grid]
			stand = e.grid
		if stand.x < 0:
			if verbose and not _unreach_logged.has(key):
				_unreach_logged[key] = true
				_log("走不到 事件 %s 在 %s 优先级 %d 触发 %d（广搜到 %d 格）" % [key, str(e.grid), e.priority_type, e.trigger(), dist.size()])
			continue
		# 会换地图（201）或开战（301）的事件更值得再去：重访的代价减半
		var weight := 30.0 if e.command_list().any(func(c): return int(c.get("code", 0)) in [201, 301]) else 60.0
		var score: float = int(event_visits.get(key, 0)) * weight + steps + _rng.randf() * 3.0
		if score < best_score:
			best_score = score
			best = {"key": key, "event_id": e.event_id, "cell": stand, "face": face, "map": map.map_id}
	# 地图传送按钮（只能鼠标点）：和事件一样按去过的次数排队
	var hud = map.map_hud
	if hud != null and hud.transfer_button.is_visible_in_tree():
		var tkey := "%d:传送按钮" % map.map_id
		var tscore: float = int(event_visits.get(tkey, 0)) * 60.0 + 8.0 + _rng.randf() * 3.0
		if tscore < best_score:
			best = {"key": tkey, "event_id": 0, "cell": p.grid, "face": 0, "map": map.map_id, "click": hud.transfer_button.get_global_rect().get_center()}
	_target = best
	if best.is_empty():
		return
	_visit(best.key)                 # 选中就记一次（接触类事件、传送门走上去就触发，等不到按确定那一步）
	_log("目标 %s 站 %s 朝 %d，%d 步" % [best.key, str(best.cell), best.face, int(dist.get(best.cell, 0))])


# ---------------------------------------------------------------- 报告

func report() -> Dictionary:
	var st := XState.current
	return {
		"seed": rng_seed, "ticks": ticks, "frames": Engine.get_process_frames(), "keys": key_count,
		"aborted": aborted, "settled": settled, "milestones": milestones, "maps": maps_seen, "event_visits": event_visits,
		"events_tried": event_visits.size(), "battles": battles, "stuck": stuck_log, "violations": violations,
		"timeline": timeline, "messages": messages_seen, "transcript": transcript,
		"final": {"screen": _last_screen, "map": _last_map, "gold": int(st.gold) if st != null else 0,
			"party": st.party.duplicate() if st != null else [], "steps": int(st.steps) if st != null else 0},
	}
