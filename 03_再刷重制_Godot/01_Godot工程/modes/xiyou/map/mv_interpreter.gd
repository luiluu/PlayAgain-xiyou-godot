class_name MVInterpreter
extends MVEventCore
## 地图事件解释器：指令语义在共用核心 MVEventCore（同战斗的 XBattleEventRunner），这里在外面包一层 await，
## 并处理只有地图才有的宿主指令。
## host 提供画面服务（文字、选项、场所移动、战斗、商店、淡入淡出、移动路线、动画、气泡、提示、输入名字、存档），见 map_scene.gd。
## 脚本(355/655) 由 MVScript 按已知写法翻译；插件指令(356) 见 MVEventCore._plugin_command；
## 副本相关（Difficulty SetID、挂机开关、顶层事件结束、事件战斗结束）交给 XDungeon；214 暂时消除交给宿主 erase_event；
## 认不出的脚本语句、插件指令与未支持的指令跳过并记进 skipped，便于之后逐条补齐。

signal finished

var host: Node
var map_id := 0
var event_id := 0
## 并行事件（触发 4）的解释器：不占宿主的 busy，等待按地图更新的帧算（菜单、战斗、各种画面开着时停住）；
## token 由同一次执行的父子游标共用，cancel() 后在下一个等待点结束（换页、消除、换图时由 MVEvent／地图场景调）
var parallel := false
var token := {"cancelled": false}
## 只有地图宿主才处理的指令（场所移动、画面、声音、战斗、商店、脚本…）：核心发 command 请求，由 _host_command 执行
const HOST_CODES := [201, 205, 211, 212, 213, 214, 216, 217, 221, 222, 223, 224, 225, 230, 236, 241, 245, 249, 250, 283, 301, 302, 352, 354, 355]
## O-027：原版事件把玩家传到四个方向都不能通行的格子（正式引擎 isMapPassable 实测）时，改传到同图的正常落点。
## 键「来源地图:事件:目的地图:x:y」。七层、十二层辛德瑞（Map061 事件 9、Map065 事件 3）原版传回大厅 (12,18)，那里是钓鱼池水面，
## 传过去就走不动；其余各层的辛德瑞都传到 (14,23)。设为空字典 {} 恢复原版。
## O-062：大厅门（Map004 事件 36）在变量 20＝33 时传到三十三层 Map157 (24,12)，那一格上层是四面不通的图块（flags 0x60f，
## 正式引擎 isPassable 四个方向都为 false），进层就走不动、碰不到守层者；改落到下面一格 (24,13)。删掉这一条恢复原版。
const TRANSFER_FIX := {"61:9:4:12:18": Vector2i(14, 23), "65:3:4:12:18": Vector2i(14, 23), "4:36:157:24:12": Vector2i(24, 13)}
## O-120：副本门「请重置副本！」的判定。全工程 363 处副本门都写「变量 5（副本未重置）＝1」；厄运城堡两扇门（Map078 事件 2 厄运王座、
## 事件 5 厄运监狱）写成「变量 5＝副本号」（17／16），正常玩不会成立，拦截失效：有副本没重置时照样扣符文进门，变量 5 叠成 2，
## 门口「重置副本」（要变量 5＝1）从此不认，出副本后变量 5 停在 1，别的副本门全部「请重置副本！」又重置不了（正式引擎实跑确认）。
## 同样写法的还有 6 扇（一并修）：Map023 事件 2（7）、Map029 事件 2（8）、Map069 事件 65 贪婪宫殿（20）、Map156 事件 2、157 事件 2、158 事件 1（14）。
## 键「地图:事件」→ 原版比较的值；命中时改按变量 5＝1 判定。设为空字典 {} 恢复原版（专项要两边都跑，所以是 static var）。
static var seal_check_fix := {"78:2": 17, "78:5": 16, "23:2": 7, "29:2": 8, "69:65": 20, "156:2": 14, "157:2": 14, "158:1": 14}
## O-120（B2）：厄运王座宝箱（Map080 事件 13 第 3、4 页）出「深渊之门」时选「进入此门」，随机变量 107 不是 1 的那支在正式版
## 只有一句 CodexMapRemoval.notice(108)（Map108 已移除），不传送也不重置：人留在王座里、开关 127 仍开，宝箱还能再开、再领一次
## 奖励（变量 94／140 不重掷，同一件），持邀请函进的还被吞掉不退（正式引擎实跑确认）。重制在这句提示之后改走同一选项的
## 「离开这是非之地」分支（回厄运城堡、重置副本、退邀请函）。键「地图:事件」→ 改走的选项序号；设为空字典 {} 恢复原版。
static var removed_gate_fix := {"80:13": 1}


func _init(h: Node, map: int, event: int, commands: Array, depth := 0) -> void:
	host = h
	map_id = map
	event_id = event
	list = commands
	_depth = depth


## headless 测试里「等待 N 帧」照旧按渲染帧（headless 渲染帧不限速、物理帧按真实时间走，几百个事件测试按物理帧要慢十几倍，
## 云端 event_compare 超时）；xiyou_speed_gear 置 false 量真实节奏。带窗口时一律按物理帧
static var HEADLESS_RENDER_WAIT := true


func _wait_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree  # 宿主暂时摘下时 host.get_tree() 为 null（DJ）
	if HEADLESS_RENDER_WAIT and DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		await tree.physics_frame


func _notice(text: String) -> void:
	if host_alive():
		host.toast(text)


## 【cc·八戒 DJ】宿主（地图画面）还在：地图／场景释放后，挂在 await 上的事件醒来时不再往下跑（原来接着调已释放的 host，
## 报 get_tree／show_message／character on previously freed）。只看释放，不看在不在树上：打开存档等界面时地图可能暂时摘下，事件要照常接着跑。
func host_alive() -> bool:
	return is_instance_valid(host) and not host.is_queued_for_deletion()


## 等 n 帧（physics＝物理帧，否则空闲帧）。用主循环的 SceneTree：宿主暂时不在树上时 host.get_tree() 是 null；宿主释放了就不再等
func _frames(n: int, physics := true) -> void:
	for i in range(n):
		if not host_alive():
			return
		var tree := Engine.get_main_loop() as SceneTree
		if physics:
			await tree.physics_frame
		else:
			await tree.process_frame


## 游标逐步推进；文字交给 host.show_message，宿主指令由发出请求的那一层（可能是公共事件子游标）执行
func cancel() -> void:
	token.cancelled = true


## 取消了，或宿主（地图画面）已释放（合 DJ host_alive：释放后醒来的协程不再往下跑）
func is_cancelled() -> bool:
	return bool(token.cancelled) or not host_alive()


## 等一帧（指令 230）。并行解释器等宿主的 parallel_frame（地图每个物理帧、且 Scene_Map 在更新地图时才发，菜单／战斗／各种画面开着时不数）；
## 等的是宿主自己的信号，地图释放时挂起的协程随之丢弃，不会留到退出时报资源未释放
func _frame() -> void:
	if not parallel:
		await host.get_tree().process_frame
		return
	await _tick()


## 等一个物理帧（205 等路线、213 等气泡、223 等色调）：并行解释器同样等宿主的 parallel_frame
func _tick() -> void:
	if parallel and host.has_signal("parallel_frame"):
		await host.parallel_frame
	else:
		await (Engine.get_main_loop() as SceneTree).physics_frame  # 宿主暂时摘下时 host.get_tree() 为 null（DJ）


func run() -> void:
	index = 0
	if _depth == 0 and event_id > 0:
		var ch = host.character(event_id, event_id)
		if ch != null and str(ch.get("character_name")) == "BaoXiangGuai":
			receipt = {"rows": []}
	while not is_cancelled() and await _step():
		pass
	if is_cancelled():
		finished.emit()
		return
	if _depth == 0 and not parallel:
		if receipt != null and not receipt.rows.is_empty():
			host.toast("宝箱收获：<br>" + "<br>".join(PackedStringArray(receipt.rows.map(func(r): return "%s ×%d" % [str(r.name).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;"), int(r.amount)]))))
		XDungeon.event_finished(state())
	finished.emit()


## 推进到下一个请求并等它处理完；本列表执行完返回 false。
## 跨 await 不留指向游标的局部变量（Godot 4.7 宿主先释放时，带着它的挂起协程会让游标留在内存里，退出时报资源未释放）
## 宿主释放了（地图关掉）就停：不再取下一条，也不把等到的结果交回核心
func _step() -> bool:
	if not host_alive():
		return false
	var r := advance()
	if r.kind == "message":
		var response
		if parallel and host.has_method("show_parallel_message"):
			response = await host.show_parallel_message(r.msg)
		else:
			response = await host.show_message(r.msg)
		if is_cancelled():
			return false
		waiting_frame().resume(response)
		return true
	if r.kind == "command":
		var go = await waiting_frame()._host_command(r.command)
		if is_cancelled():
			return false
		waiting_frame().resume(go)
		return true
	return false


## 立即显示待显示的文字（MVScript 等在执行中途需要时用）
func flush_message() -> void:
	if pending_lines.is_empty() or not host_alive():
		return
	var lines := pending_lines.map(func(t): return MVEventCore.message_text(str(t)))
	pending_lines.clear()
	await host.show_message({"face": "", "index": 0, "background": 0, "position": 2, "lines": lines})


# ---- 核心的环境钩子 ----

func _make_child(commands: Array) -> MVEventCore:
	var sub := MVInterpreter.new(host, map_id, event_id, commands)
	sub.parallel = parallel
	sub.token = token
	return sub


func _map_id() -> int:
	return map_id


func _event_id() -> int:
	return event_id


func _data_changed() -> void:
	if host_alive():
		host.refresh_events()


## 播放电影：宿主放完再接着执行（_host_command 261）
func _play_movie(_name: String):
	return _request("command", "command", {"command": list[index]})


func _execute_env(c: Dictionary):
	if HOST_CODES.has(int(c.code)):
		return _request("command", "command", {"command": c})
	match int(c.code):
		339:
			# 强制战斗行动：MV iterateBattler 只在战斗内遍历战斗者，地图上空操作（CE2499 炭治郎-免疫负面）
			return null
		331:
			# 更改敌人 HP：MV iterateEnemyIndex 遍历 $gameTroop.members()，战斗外只剩上一场的敌人（下场开战 setup 重建），
			# 改了也没有可见结果，地图上空操作（CE1401「敌人恢复所有血量」，强者／霸者／大道／天道领域 6067～6071 场合随时）
			return null
	return super(c)


## 插件指令 EnemyBook open 要打开图鉴画面；PHWarehouse show <名字> 要打开仓库画面
func _host_plugin(line: String) -> bool:
	var args := line.split(" ", false)
	if args.size() >= 1 and args[0].to_lower() == "pingbizhuangbei":
		return host.has_method("open_pingbi")
	if args.size() >= 3 and args[0] == "PHWarehouse" and args[1] == "show":
		return host.has_method("open_warehouse")
	return args.size() >= 2 and args[0] == "EnemyBook" and args[1] == "open" and host.has_method("open_enemy_book")


## seal_check_fix：[1, 5, 0, 副本号, 0] 改成 [1, 5, 0, 1, 0]
func _condition(p: Array) -> bool:
	if int(p[0]) == 1 and int(p[1]) == XDungeon.VAR_SEALED and int(p[2]) == 0 and int(p[4]) == 0 \
			and seal_check_fix.get("%d:%d" % [map_id, event_id], -1) == int(p[3]):
		return super([1, XDungeon.VAR_SEALED, 0, 1, 0])
	return super(p)


## removed_gate_fix：跳到本指令外层选项的第 choice 个分支（402）；之后 resume 前进一格，从分支里第一条指令接着跑
func _jump_to_choice(choice: int, indent: int) -> void:
	for j in range(index + 1, list.size()):
		var c: Dictionary = list[j]
		if int(c.indent) < indent and int(c.code) == 402 and int(c.parameters[0]) == choice:
			_branch[int(c.indent)] = choice
			index = j
			return


## 敌人 [5, 序号, 0 出现／1 状态, 状态]：地图上 $gameTroop 是上一场战斗的敌群（XState.last_troop，没打过或读档后为空 → false）；
## 出现＝isAlive（战斗结束后都已出现，即没死）。战斗里由 XBattleEventRunner 读当场敌人。
## 角色朝向 [6, 角色, 方向]
func _condition_env(p: Array):
	if int(p[0]) == 5:
		var troop: Array = state().last_troop
		var i := int(p[1])
		if i < 0 or i >= troop.size():
			return false
		return not bool(troop[i].dead) if int(p[2]) == 0 else Array(troop[i].states).has(int(p[3]))
	if int(p[0]) == 6:
		var ch = host.character(int(p[1]), event_id)
		return ch != null and int(ch.direction) == int(p[2])
	return null


## 游戏数据 5：角色（事件）的坐标、朝向
func _game_data(type: int, p1: int, p2: int):
	if type == 5:
		var ch = host.character(p1, event_id)
		if ch == null:
			return null
		match p2:
			0: return ch.grid.x
			1: return ch.grid.y
			2: return ch.direction
		return null
	return super(type, p1, p2)


## MOG_TreasurePopup：数量为正、本事件（按 ID）在当前地图上时浮出获得提示
func _treasure_popup(rec: Dictionary, amount: int) -> void:
	if amount > 0 and event_id > 0 and host.has_method("treasure_popup"):
		host.treasure_popup(rec, amount, event_id)


## 宿主指令（HOST_CODES）；返回 false 结束本列表
func _host_command(c: Dictionary):
	var p: Array = c.parameters
	var indent := int(c.indent)
	match int(c.code):
		261:
			# 播放电影（Graphics.playVideo）：地图画面上盖一层放片子，放完接着执行
			if host.has_method("play_movie"):
				await host.play_movie(str(p[0]))
		283:
			# 更改战斗背景 [背景1, 背景2]
			if host.has_method("change_battleback"):
				host.change_battleback(str(p[0]), str(p[1]))
		201:
			if int(p[0]) == 0:
				var to: Vector2i = TRANSFER_FIX.get("%d:%d:%d:%d:%d" % [map_id, event_id, int(p[1]), int(p[2]), int(p[3])], Vector2i(int(p[2]), int(p[3])))
				await host.transfer(int(p[1]), to.x, to.y, int(p[4]))
			else:
				var s := state()
				await host.transfer(int(s.variable(int(p[1]))), int(s.variable(int(p[2]))), int(s.variable(int(p[3]))), int(p[4]))
		221:
			await host.fade(true)
		222:
			await host.fade(false)
		223:
			# 更改画面色调 [色调, 帧数, 等待]
			state().screen.start_tint(p[0], int(p[1]))
			if bool(p[2]):
				for i in range(int(p[1])):
					if is_cancelled():
						break
					await _tick()
		236:
			# 设置天气 [类型, 强度, 帧数, 等待]；战斗中无效（地图解释器不在战斗里）
			state().screen.change_weather(str(p[0]), int(p[1]), int(p[2]))
			if bool(p[3]):
				for i in range(int(p[2])):
					if is_cancelled():
						break
					await _tick()
		224:
			# 画面闪烁 [颜色 r,g,b,强度, 帧数, 等待]（Game_Screen.startFlash）
			if host.has_method("flash_screen"):
				host.flash_screen(p[0], int(p[1]))
			if bool(p[2]):
				for i in range(int(p[1])):
					if is_cancelled():
						break
					await _tick()
		352:
			# 打开存档画面（SceneManager.push(Scene_Save)；公共事件 9「炉石」），关闭后回到地图接着执行
			if host.has_method("open_save"):
				await host.open_save()
		225:
			# 画面震动 [强度, 速度, 时间, 等待]
			if host.has_method("shake_screen"):
				host.shake_screen(int(p[0]), int(p[1]), int(p[2]))
			if bool(p[3]):
				for i in range(int(p[2])):
					await _wait_frame()  # 震屏在地图 _physics_process 里逐帧走，按物理帧等
		230:
			# 等待 N 帧＝N 个物理帧（MV updateMain 的帧；变速齿轮 1.6 时物理帧 96／秒，60 帧约 0.625 秒）。
			# 原来按渲染帧等，帧率不跟齿轮走（60 Hz 屏上 60 帧要 1 秒，120 Hz 屏上只要半秒；battlefix2 实测）
			for i in range(int(p[0])):
				if is_cancelled():
					break
				if parallel:
					await _tick()
				else:
					await _wait_frame()
		241:
			host.play_bgm(p[0])
		245:
			host.play_bgs(p[0])
		249:
			host.play_me(p[0])
		250:
			host.play_se(p[0])
		301:
			var troop := int(p[1]) if int(p[0]) == 0 else int(state().variable(int(p[1])))
			if host is XMapScene:
				XAutoSave.battle_checkpoint(host, true)  # 开战前检查点（O-221；事件里开的战斗）
			var result: int = await host.start_battle(troop, bool(p[2]), bool(p[3]))
			XDungeon.battle_finished(troop, result, state().map_id)
			_branch[indent] = result
			# 战斗里的 353 游戏结束不看可不可输（XMapScene.last_battle_game_over）
			if result == 2 and (not bool(p[3]) or host.get("last_battle_game_over") == true):
				await host.game_over()   # 要等结束画面走完：不 await 的话事件收尾 busy=false，画面盖着时人还能走（O-244 补）
				return false
		302:
			var goods := [p]
			while index + 1 < list.size() and int(list[index + 1].code) == 605:
				index += 1
				goods.append(list[index].parameters)
			XShopStock.set_context(map_id, event_id)   # installBalanceShopV041Runtime 包 command302：当铺／大厅 EV54 的商店规则
			await host.open_shop(goods, bool(p[4]))
			XShopStock.shop_context = {}
		205:
			# 设置移动路线 [角色, 路线]；路线勾选「等待完成」时等角色走完
			var ch = host.character(int(p[0]), event_id)
			if ch:
				ch.force_move_route(p[1])
				if bool(p[1].get("wait", false)):
					# 等待中若场所移动，旧地图的角色已释放
					while not is_cancelled() and is_instance_valid(ch) and ch.is_route_forcing():
						await _tick()
		211:
			host.player.transparent = int(p[0]) == 0
			host.player.queue_redraw()
		214:
			# 暂时消除事件（Game_Map.eraseEvent）：换地图重建事件后复原。
			# 同 isOnCurrentMap：先 201 换了图再 214 时不动新图的同号事件
			if event_id > 0 and map_id == state().map_id and host.has_method("erase_event"):
				host.erase_event(event_id)
		212:
			# 显示动画 [角色, 动画, 等待]
			var ch = host.character(int(p[0]), event_id)
			if ch:
				var anim = host.show_animation(ch, int(p[1]))
				if bool(p[2]) and anim and not is_cancelled():
					await anim.done
		213:
			# 显示气泡 [角色, 气泡, 等待]
			var ch = host.character(int(p[0]), event_id)
			if ch:
				ch.start_balloon(int(p[1]))
				if bool(p[2]):
					while not is_cancelled() and is_instance_valid(ch) and ch.is_balloon_playing():
						await _tick()
		216:
			# 更改队伍跟随 [0 显示 1 隐藏]
			host.set_followers_visible(int(p[0]) == 0)
		217:
			await host.gather_followers()
		354:
			host.return_to_title()
			return false
		355:
			var code := str(p[0])
			if MVEvent.MERCHANT29_FIX and list[index].has("mvStringParameters"):
				code = str(list[index].mvStringParameters)  # O-待定·深渊商人：字符串参数按整段执行（v0.62.13 修法）
			while index + 1 < list.size() and int(list[index + 1].code) == 655:
				index += 1
				code += "\n" + str(list[index].parameters[0])
			for st in await MVScript.run(code, self):
				skipped.append({"code": 355, "text": str(st).left(80)})
			var leave := int(removed_gate_fix.get("%d:%d" % [map_id, event_id], -1))
			if leave >= 0 and code.begins_with("CodexMapRemoval.notice("):
				_jump_to_choice(leave, indent)
		356:
			var line := str(p[0])
			if line.split(" ", false)[0].to_lower() == "pingbizhuangbei":
				await host.open_pingbi()  # SiShiTan-PingBi：屏蔽掉落页（公共事件 486），关闭回地图
				return true
			if line.begins_with("PHWarehouse"):
				# 仓库（PH_Warehouse PHWarehouse show <名字>）：设为当前仓库并打开 Scene_Warehouse，关闭回地图；仓库不存在时不打开
				if XWarehouse.open(state(), " ".join(line.split(" ", false).slice(2))):
					await host.open_warehouse()
				return true
			# 怪物图鉴（AB_EnemyBook EnemyBook open；公共事件 2）：SceneManager.push(Scene_EnemyBook)，关闭回地图
			await host.open_enemy_book()
	return true
