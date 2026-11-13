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
const KEYS := {"accept": KEY_ENTER, "cancel": KEY_ESCAPE, "up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "f": KEY_F,
	"g": KEY_G, "tilde": KEY_QUOTELEFT, "one": KEY_1, "e": KEY_E}
const DIR_KEY := {2: "down", 4: "left", 6: "right", 8: "up"}
const INTENT_WORDS := {"enter": ["进入该层", "进入"], "challenge": ["挑战"], "heal": ["治愈"]}
const LOBBY := 4                   # 方桌大厅
const FLOOR_VAR := 20              # 变量 20＝神魔之塔当前层数（守层者打赢后加一，大厅的门按它送人）

## ---- 参数（开跑前设） ----
var rng_seed := 20261113
var max_ticks := 3000              # 一步＝观察一次＋做一个动作
var stuck_ticks := 120             # 画面签名这么多步不变算卡住一次
var stuck_frames := 1800           # 同时还要过这么多帧（战斗里乘 4）
var max_stuck := 3                 # 连续卡住这么多次就放弃（报告里记 aborted）
var battle_manual_actions := 60    # 一场战斗手动按这么多步还没完，就打开自动战斗（报告里记 assist）
var overlay_monkey_max := 10       # 每次进菜单／子页先随手按最多这么多下再退出
var battle_give_up_frames := 90000 # 一场战斗最多这么多帧（按 60 帧一秒是 25 分钟）；血量和回合一直不动另有看门狗管
var settle_ticks := 800            # 目标达到／步数用完后，最多再走这么多步把手头的画面收完
var mode := "explore"              # explore 随便逛（原型）／climb 爬塔：进塔门 → 打守层者 → 回大厅 → 下一层
var max_msec := 0                  # 墙钟上限（毫秒）；0＝不限。云端按时间跑用它
var climb_manual_actions := 12     # 爬塔时每场战斗先手动按这么多步，再点战斗里的「自动」按钮
var climb_max_defeats := 5         # 同一层守层者输这么多次就收工，报告写「打不过」
var climb_grind_base := 6          # 第一次输了之后挂机练这么多场再来，之后每输一次翻倍
var equip_enabled := true          # 爬塔时在大厅打开菜单 → 装备，把背包里更好的装备穿上
var climb_explore_ticks := 400     # 这一层地图上没看到守层者时，最多逛这么多步找路
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
var floor_log: Array = []          # 爬塔：每到新的一层记一条 {floor, tick, frames, msec, defeats, grind_battles, levels}
var climb_stop := ""               # 爬塔收工的原因（空＝步数或时间用完）
var defeats := 0
var _floor := -1
var _floor_entry: Dictionary = {}
var _need_grind := 0
var _grind_goal := -1
var _grind_total := 0
var _save_stamp = null
var _heal_tries := 0
var _intent := ""
var _explore_here := 0
var _lost_guardian := 0
var _t0 := 0
var equip_changes := 0             # 一共换上了多少件装备
var equip_passes := 0
var _equip_job = null              # 正在进行的换装：{actor, row, started, want, changes, ticks, done, tries}
var _equip_sig = null
var _last_over_tick := -1
var settled := false

var _rng := RandomNumberGenerator.new()
var _last_screen := ""
var _sig = null
var _sig_tick := 0
var _sig_frame := 0
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
## none 场景切换中／boot 开场还没到标题／title 标题／load_page 标题下的读档页／form 标题下的按钮页（选存档位、难度、阵容）／
## battle 战斗／transfer 地图传送页／game_over 结束画面／choice 选项／number 数字输入／message 对话／overlay 地图上盖着菜单或子页／
## map_busy 地图在跑事件／map 地图空闲／other 别的场景
func observe() -> Dictionary:
	var s := _scene()
	if s == null:
		return {"screen": "none"}
	if s.scene_file_path == ENTRY:
		var lp := s.find_child("LoadPage", true, false)
		if lp != null and not lp.is_queued_for_deletion():
			return {"screen": "load_page", "entry": s, "page": lp}
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
		"load_page":
			sig.append([str(obs.page._phase), int(obs.page.index)])
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
				if obs.screen == "overlay":
					var menu := _find_ui(obs.map, XMenu)
					if menu != null:
						sig.append([str(menu._mode), int(menu._cmd_index)])
						var eq := _equip_scene(menu)
						if eq != null:
							sig.append([str(eq._mode), int(eq._slot), int(eq._item_index), int(eq.actor_index)])
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
	_t0 = Time.get_ticks_msec()
	while ticks < max_ticks and aborted == "" and climb_stop == "":
		if max_msec > 0 and Time.get_ticks_msec() - _t0 > max_msec:
			climb_stop = "时间用完"
			break
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
	_battle["frames"] = Engine.get_process_frames() - int(_battle.get("frame0", Engine.get_process_frames()))
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
	var frame := Engine.get_process_frames()
	if sig != _sig:
		_sig = sig
		_sig_tick = ticks
		_sig_frame = frame
		_stuck_streak = 0
		return false
	# 步数和帧数都过了才算卡住：自动战斗、挂机时机器人一步只等几帧，一个回合的演出比 stuck_ticks 步长得多
	var need_frames := stuck_frames * (4 if obs.screen == "battle" else 1)
	if ticks - _sig_tick < stuck_ticks or frame - _sig_frame < need_frames:
		return false
	_sig_tick = ticks
	_sig_frame = frame
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
		"load_page":
			await _act_load_page(obs)
		"battle":
			await _act_battle(obs)
		"game_over":
			if _last_over_tick < 0 or ticks - _last_over_tick > 50:
				_on_defeat()
			_last_over_tick = ticks
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
			if _equip_job != null:
				await _act_equip(obs)
				return
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
			if mode == "climb":
				await _act_climb(obs)
			else:
				await _act_map(obs)


# ---------------------------------------------------------------- 标题与开局

func _act_title(obs: Dictionary) -> void:
	var entry = obs.entry
	var want := -1
	var sel := 0
	# 爬塔时有存档就读档接着爬（全灭回标题之后）；没有存档才开新局
	var key := "new_game"
	if mode == "climb":
		for i in range(1, XSave.SLOTS + 1):
			if XSave.exists(i):
				key = "load"
	var tq = entry.get("_tq_title")
	if tq != null and is_instance_valid(tq) and tq.is_title_page():
		if tq.state().entering:
			await _tap("accept")     # 进场动画：任意键跳到最终画面
			return
		sel = tq.selected()
		for i in tq.item_count():
			if str(tq.item(i).key) == key:
				want = i
	else:
		sel = int(entry._sel)
		want = 1 if key == "load" else 0   # 原版标题：新的游戏、旧的回忆
	if want < 0:
		aborted = "标题上找不到「新的游戏」"
		return
	if sel == want:
		_mark("new_game_pressed" if key == "new_game" else "load_pressed")
		await _tap("accept")
		await _frames(4)
	else:
		await _tap("down" if want > sel else "up")


## 读档页：光标挪到第一个有存档的格 → 确定（出操作窗，默认「读取」）→ 确定 → 确认框确定
func _act_load_page(obs: Dictionary) -> void:
	var page = obs.page
	if str(page._phase) == "list":
		var want := -1
		for i in XSave.SLOTS:
			if XSave.exists(i + 1):
				want = i
				break
		if want < 0:
			await _tap("cancel")
			return
		if int(page.index) != want:
			await _tap("down" if want > int(page.index) else "up")
			return
	await _tap("accept")
	await _frames(4)


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
	# 爬塔时带着意图去的事件（进门、挑战守层者、治疗）：选项里有对应的字就选它
	for kw in INTENT_WORDS.get(_intent, []):
		var hit := -1
		for i in n:
			if hit < 0 and str(obs.message._choices[i]).contains(kw):
				hit = i
		if hit >= 0:
			want = hit
			break
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
## 逛图模式：手动步数用完时看敌人血量，掉了一半以上就开自动战斗打完（报告记 assist）；几乎没掉（打不动的对手）就像玩家一样去选「逃跑」。
## 爬塔模式：先手动按 climb_manual_actions 步，再用鼠标点战斗左上的「自动」按钮（玩家也能点），交给游戏自己的自动战斗。
## 逃不掉也打不完，超过 battle_give_up_frames 帧就收工（报告记 aborted）。挂机中的战斗本来就是自动，只等着。
func _act_battle(obs: Dictionary) -> void:
	var b = obs.battle
	var hp := 0.0
	for e in b.logic.enemies:
		hp += float(e.hp)
	if _battle != null:
		_battle.actions += 1
		if not _battle.has("hp0"):
			_battle["hp0"] = hp
		if not _battle.has("frame0"):
			_battle["frame0"] = Engine.get_process_frames()
		if Engine.get_process_frames() - int(_battle.frame0) > battle_give_up_frames:
			aborted = "一场战斗 %d 帧还没打完也逃不掉（地图 %d）" % [battle_give_up_frames, _battle.map]
			return
	if b.logic.auto:
		# 自动战斗里也有要按键才走的消息（「被击败了」、逃跑、战斗事件的对话）
		var bm = b.get("message")
		if bm != null and is_instance_valid(bm) and bm.is_busy():
			await _tap("accept")
		else:
			await _frames(6)
		return
	if mode == "climb" and _battle != null and _battle.actions > climb_manual_actions:
		var btn = b.get("auto_btn")
		var clicks := int(_battle.get("auto_clicks", 0))
		if btn != null and is_instance_valid(btn) and btn.is_visible_in_tree() and clicks < 3:
			_battle["auto_clicks"] = clicks + 1
			await _click(btn.get_global_rect().get_center())
			await _frames(3)
			return
		_battle.assist = true            # 按钮点不到：直接开自动（报告里看得出来）
		b.logic.auto = true
		return
	if mode != "climb" and _battle != null and _battle.actions == battle_manual_actions + 1:
		if hp <= float(_battle.hp0) * 0.5:
			_battle.assist = true
			b.logic.auto = true
			_log("战斗超过手动步数，敌人血量过半已掉，打开自动")
			return
		_battle["escaping"] = true
		_mark("escape_tried")
		_log("战斗超过手动步数，敌人血量几乎没掉，改选逃跑")
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


# ---------------------------------------------------------------- 爬塔

## 全灭（出了结束画面）：这一层记一次失败，下次先挂机练级；输太多次就收工
func _on_defeat() -> void:
	defeats += 1
	var row := _floor_row()
	row["defeats"] = int(row.get("defeats", 0)) + 1
	_need_grind = climb_grind_base * int(pow(2, int(row.defeats) - 1))
	_log("全灭：第 %d 层第 %d 次，下次先练 %d 场" % [_floor, row.defeats, _need_grind])
	if int(row.defeats) >= climb_max_defeats:
		climb_stop = "第 %d 层守层者打不过：输了 %d 次，中间挂机练了 %d 场，队伍等级 %s" % [_floor, row.defeats, int(row.get("grind_battles", 0)), str(_levels())]


func _levels() -> Array:
	var st := XState.current
	return st.members().map(func(a): return int(a.level)) if st != null else []


func _floor_row() -> Dictionary:
	if floor_log.is_empty() or int(floor_log[-1].floor) != _floor:
		floor_log.append({"floor": _floor, "tick": ticks, "frames": Engine.get_process_frames(),
			"msec": Time.get_ticks_msec() - _t0, "defeats": 0, "grind_battles": 0, "levels": _levels()})
	return floor_log[-1]


## 事件当前页的指令里有没有某个选项字样（102 的选项文字）
func _has_choice(e: MVEvent, word: String) -> bool:
	for c in e.command_list():
		if int(c.get("code", 0)) == 102:
			for t in c.parameters[0]:
				if str(t).contains(word):
					return true
	return false


## 守层者：当前页会给「当前层数」加一的事件（打赢才走到那一句）
func _is_guardian(e: MVEvent) -> bool:
	if e.erased or e.page.is_empty() or e.trigger() != 0:
		return false
	var fight := false
	var advance := false
	for c in e.command_list():
		var code := int(c.get("code", 0))
		if code == 301:
			fight = true
		elif code == 122 and int(c.parameters[0]) == FLOOR_VAR and int(c.parameters[1]) == FLOOR_VAR and int(c.parameters[2]) == 1:
			advance = true
	return fight and advance


func _find_event(map: XMapScene, test: Callable) -> MVEvent:
	for e in map.events:
		if not e.erased and not e.page.is_empty() and test.call(e):
			return e
	return null


## 把某个事件设成目标（站哪一格、朝哪边）；走不到返回 false
func _aim(map: XMapScene, e: MVEvent, intent: String) -> bool:
	var p: MVPlayer = map.player
	var tm = p.tilemap
	var dist: Dictionary = _bfs(p).dist
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
		stand = e.grid
	if stand.x < 0:
		return false
	var key := "%d:%d" % [map.map_id, e.event_id]
	if _target.get("key") != key:
		_visit(key)
		_log("爬塔目标 %s（%s）站 %s 朝 %d" % [key, intent, str(stand), face])
	_target = {"key": key, "event_id": e.event_id, "cell": stand, "face": face, "map": map.map_id}
	_intent = intent
	return true


## 爬塔时地图空闲这一步做什么。大厅：选族 → 治疗 → 存档 → 进塔门；塔里：要练级就挂机，否则去挑战守层者；
## 打完（层数变了）或这张图上没有守层者就按 1 回大厅。认不出局面时退回随便逛，靠看门狗兜底。
func _act_climb(obs: Dictionary) -> void:
	var map: XMapScene = obs.map
	var st := XState.current
	var floor := int(st.variable(FLOOR_VAR))
	if floor != _floor:
		if _floor >= 0 and floor > _floor:
			_mark("floor_%d_cleared" % _floor)
			_log("通过第 %d 层" % _floor)
		_floor = floor
		_need_grind = 0
		_lost_guardian = 0
		_floor_row()
	if not _floor_entry.has(map.map_id):
		_floor_entry[map.map_id] = floor
		_explore_here = 0
	# 挂机练级中：练够了、或有人倒下（游戏自己会停）就按 G 停
	if XHangUp.is_active(st):
		if battles.size() >= _grind_goal or st.members().any(func(a): return a.hp <= 0):
			await _tap("g", 3)
			await _frames(4)
		else:
			await _frames(8)
		return
	if _grind_goal >= 0:
		var row := _floor_row()
		row["grind_battles"] = int(row.get("grind_battles", 0)) + maxi(0, battles.size() - _grind_start)
		_grind_total += maxi(0, battles.size() - _grind_start)
		_grind_goal = -1
		_need_grind = 0
		_log("挂机练级结束，回大厅存档")
		await _hotkey_lobby(map)
		return
	if map.player.is_moving():
		await _frames(1)
		return
	if _equip_job != null:
		# 回到地图了：换装做完就收尾；菜单没开起来就再按几次，还不行就算了
		_equip_job.tries += 1
		if _equip_job.done or _equip_job.tries > 5:
			equip_passes += 1
			equip_changes += int(_equip_job.changes)
			_log("换装结束：换上 %d 件" % int(_equip_job.changes))
			if int(_equip_job.changes) > 0:
				_mark("equipped")
			_equip_job = null
			_equip_sig = _gear_sig(st)
		else:
			await _tap("cancel", 3)
			await _frames(6)
		return
	if map.map_id == LOBBY:
		_floor_entry = {LOBBY: floor}
		await _climb_lobby(map, st)
	else:
		await _climb_floor(map, st, floor)


func _hotkey_lobby(map: XMapScene) -> void:
	_target = {}
	_floor_entry.erase(map.map_id)
	await _tap("one", 3)
	await _frames(6)


func _climb_lobby(map: XMapScene, st: XState) -> void:
	var e: MVEvent = null
	if not XRace.guide_chosen(st):
		e = _find_event(map, func(x): return str(x.data.get("note", "")) == "<CodexRaceGuide>")
		if e != null and _aim(map, e, "race"):
			await _goto_target(map)
			return
	var hurt: bool = st.members().any(func(a): return a.hp < a.mhp * 0.95)
	if hurt and _heal_tries < 2:
		e = _find_event(map, func(x): return _has_choice(x, "治愈"))
		if e != null and _aim(map, e, "heal"):
			if _arrived(map.player):
				_heal_tries += 1
			await _goto_target(map)
			return
	# 背包里的装备变了（打到新的）：打开菜单去装备页，把更好的穿上
	if equip_enabled:
		var gsig := _gear_sig(st)
		if gsig != _equip_sig:
			_equip_sig = gsig
			_equip_job = {"actor": 0, "row": 0, "started": false, "want": -1, "changes": 0, "ticks": 0, "done": false, "tries": 0}
			_log("去装备页看看有没有更好的装备")
			await _tap("cancel", 3)
			await _frames(6)
			return
	# 进门前存档（快捷键 ~）：全灭回标题后从这里接着来
	var stamp := [int(st.variable(FLOOR_VAR)), battles.size()]
	if stamp != _save_stamp:
		_save_stamp = stamp
		_heal_tries = 0
		var before := map.toasts.size()
		await _tap("tilde", 3)
		await _frames(10)
		if is_instance_valid(map) and map.toasts.size() > before:
			_mark("saved")
		return
	e = _find_event(map, func(x): return _has_choice(x, "进入该层"))
	if e != null and _aim(map, e, "enter"):
		await _goto_target(map)
		return
	# 门走不到或认不出：退回随便逛
	_intent = ""
	await _act_map({"map": map})


func _gear_sig(st: XState) -> Array:
	return [XItemScene.bag_gear("weapon").size(), XItemScene.bag_gear("armor").size(), st.party.duplicate()]


func _equip_scene(menu: Node) -> XEquipScene:
	for c in menu.get_children():
		if c is XEquipScene and not c.is_queued_for_deletion():
			return c
	return null


## 候选里哪一件最值得换上：看装备页「属性对比」会显示的那组数（装上后的八项能力对比现在的），加权算涨幅。
## 返回候选序号；都不比身上的好返回 -1。
func _best_candidate(eq: XEquipScene) -> int:
	var a := eq.actor()
	var cands: Array = eq.candidates()
	var best := -1
	var best_score := 0.02
	for i in cands.size():
		var rec: Dictionary = cands[i].rec
		if rec.is_empty() or XEquipment.dual_blocked(a, eq._slot, rec):
			continue
		var t := XEquipment.preview(a, eq._slot, rec)
		if t == null:
			continue
		var score := 0.0
		var now := [a.mhp, a.mmp, a.atk, a.def, a.mat, a.mdf, a.agi, a.luk]
		var then := [t.mhp, t.mmp, t.atk, t.def, t.mat, t.mdf, t.agi, t.luk]
		var weight := [1.0, 0.3, 1.5, 1.0, 1.5, 1.0, 0.5, 0.2]
		for k in 8:
			score += weight[k] * (float(then[k]) - float(now[k])) / maxf(absf(float(now[k])), 1.0)
		if score > best_score:
			best_score = score
			best = i
	return best


## 换装（菜单已经开着）：主菜单选「装备」→ 选人 → 装备页里逐个槽位看候选，有更好的就换上 → E 换下一个人 → 全队看完退出来。
## 全程只按键：上下挪光标、确定、取消、E。
func _act_equip(obs: Dictionary) -> void:
	var job: Dictionary = _equip_job
	job.ticks += 1
	var menu := _find_ui(obs.map, XMenu)
	if menu == null or job.ticks > 4000:
		job.done = true
		await _tap("cancel")
		await _frames(3)
		return
	var eq := _equip_scene(menu)
	if eq == null:
		if job.done:
			await _tap("cancel")
			await _frames(3)
			return
		match str(menu._mode):
			"command":
				var want: int = menu.command_names().find("装备")
				if want < 0:
					job.done = true
				elif int(menu._cmd_index) != want:
					await _tap("down" if want > int(menu._cmd_index) else "up")
				else:
					await _tap("accept")
					await _frames(3)
			"actor":
				await _tap("accept")
				await _frames(4)
			_:
				await _tap("cancel")
		return
	var party_n: int = XState.current.party.size()
	match str(eq._mode):
		"command":
			if job.started:
				job.started = false
				job.actor += 1
				job.row = 0
			if job.done or int(job.actor) >= party_n:
				job.done = true
				await _tap("cancel")
				await _frames(3)
			elif int(job.actor) > 0 and int(job.get("switched", 0)) < int(job.actor):
				job["switched"] = int(job.actor)
				await _tap("e")                 # 下一个人
				await _frames(2)
			elif int(eq._cmd) != 0:
				await _tap("up")
			else:
				job.started = true
				await _tap("accept")
		"slot":
			var view: Array = eq.slot_view()
			if int(job.row) >= view.size():
				await _tap("cancel")
				return
			var row: int = eq._slot_row()
			if row != int(job.row):
				await _tap("down" if int(job.row) > row else "up")
				return
			var best := _best_candidate(eq) if XEquipment.can_change(eq.actor(), eq._slot) else -1
			if best < 0:
				job.row += 1
				return
			job.want = best
			await _tap("accept")
		"item":
			var n: int = eq.candidates().size()
			var cur := int(eq._item_index)
			var want := int(job.want)
			if want < 0 or want >= n:
				await _tap("cancel")
				job.row += 1
			elif cur != want:
				# 列表首尾相接：走近的那一边
				var down := posmod(want - cur, n)
				await _tap("down" if down <= n - down else "up")
			else:
				await _tap("accept")
				await _frames(2)
				job.changes += 1
				job.row += 1
				job.want = -1


var _grind_start := 0

func _climb_floor(map: XMapScene, st: XState, floor: int) -> void:
	# 进来之后层数变了＝这层打完了：回大厅去下一层
	if int(_floor_entry.get(map.map_id, floor)) != floor:
		await _hotkey_lobby(map)
		return
	var g := _find_event(map, _is_guardian)
	if g == null:
		# 这张图上没有守层者（支线地图、城镇，或守层者在别的图）：逛一阵找路，找不到就回大厅
		_explore_here += 1
		if _explore_here > climb_explore_ticks:
			_lost_guardian += 1
			_mark("guardian_not_found_floor_%d" % floor)
			if _lost_guardian >= 3:
				climb_stop = "第 %d 层找不到守层者（地图 %d 一带逛了三轮）" % [floor, map.map_id]
				return
			await _hotkey_lobby(map)
			return
		_intent = ""
		await _act_map({"map": map})
		return
	if _need_grind > 0:
		if map.map_data.get("encounterList", []).is_empty():
			_need_grind = 0          # 这张图没有遇敌，练不了：直接再挑战
			return
		_grind_start = battles.size()
		_grind_goal = battles.size() + _need_grind
		_mark("grind_started")
		_log("挂机练级 %d 场" % _need_grind)
		await _tap("g", 3)
		await _frames(6)
		if not XHangUp.is_active(st):
			_grind_goal = -1         # 没开起来（弹了提示）：下一步对话会被按掉，再挑战
			_need_grind = 0
		return
	if _aim(map, g, "challenge"):
		if _arrived(map.player):
			_floor_row()["challenges"] = int(_floor_row().get("challenges", 0)) + 1
			_mark("guardian_challenged")
		await _goto_target(map)
		return
	_intent = ""
	await _act_map({"map": map})


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
	await _goto_target(map)


## 朝 _target 走一步；到了就互动
func _goto_target(map: XMapScene) -> void:
	var p: MVPlayer = map.player
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
		"aborted": aborted, "settled": settled, "mode": mode, "floor": _floor, "floor_log": floor_log, "climb_stop": climb_stop,
		"defeats": defeats, "grind_battles": _grind_total, "equip_changes": equip_changes, "equip_passes": equip_passes, "levels": _levels(), "msec": Time.get_ticks_msec() - _t0,
		"milestones": milestones, "maps": maps_seen, "event_visits": event_visits,
		"events_tried": event_visits.size(), "battles": battles, "stuck": stuck_log, "violations": violations,
		"timeline": timeline, "messages": messages_seen, "transcript": transcript,
		"final": {"screen": _last_screen, "map": _last_map, "gold": int(st.gold) if st != null else 0,
			"party": st.party.duplicate() if st != null else [], "steps": int(st.steps) if st != null else 0},
	}
