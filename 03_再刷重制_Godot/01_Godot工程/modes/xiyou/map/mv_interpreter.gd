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
## 只有地图宿主才处理的指令（场所移动、画面、声音、战斗、商店、脚本…）：核心发 command 请求，由 _host_command 执行
const HOST_CODES := [201, 205, 211, 212, 213, 214, 216, 217, 221, 222, 223, 224, 225, 230, 236, 241, 245, 249, 250, 283, 301, 302, 352, 354, 355]
## O-027：原版事件把玩家传到四个方向都不能通行的格子（正式引擎 isMapPassable 实测）时，改传到同图的正常落点。
## 键「来源地图:事件:目的地图:x:y」。七层、十二层辛德瑞（Map061 事件 9、Map065 事件 3）原版传回大厅 (12,18)，那里是钓鱼池水面，
## 传过去就走不动；其余各层的辛德瑞都传到 (14,23)。设为空字典 {} 恢复原版。
## O-062：大厅门（Map004 事件 36）在变量 20＝33 时传到三十三层 Map157 (24,12)，那一格上层是四面不通的图块（flags 0x60f，
## 正式引擎 isPassable 四个方向都为 false），进层就走不动、碰不到守层者；改落到下面一格 (24,13)。删掉这一条恢复原版。
const TRANSFER_FIX := {"61:9:4:12:18": Vector2i(14, 23), "65:3:4:12:18": Vector2i(14, 23), "4:36:157:24:12": Vector2i(24, 13)}


func _init(h: Node, map: int, event: int, commands: Array, depth := 0) -> void:
	host = h
	map_id = map
	event_id = event
	list = commands
	_depth = depth


func _notice(text: String) -> void:
	host.toast(text)


## 游标逐步推进；文字交给 host.show_message，宿主指令由发出请求的那一层（可能是公共事件子游标）执行
func run() -> void:
	index = 0
	if _depth == 0 and event_id > 0:
		var ch = host.character(event_id, event_id)
		if ch != null and str(ch.get("character_name")) == "BaoXiangGuai":
			receipt = {"rows": []}
	while await _step():
		pass
	if _depth == 0:
		if receipt != null and not receipt.rows.is_empty():
			host.toast("宝箱收获：<br>" + "<br>".join(PackedStringArray(receipt.rows.map(func(r): return "%s ×%d" % [str(r.name).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;"), int(r.amount)]))))
		XDungeon.event_finished(state())
	finished.emit()


## 推进到下一个请求并等它处理完；本列表执行完返回 false。
## 跨 await 不留指向游标的局部变量（Godot 4.7 宿主先释放时，带着它的挂起协程会让游标留在内存里，退出时报资源未释放）
func _step() -> bool:
	var r := advance()
	if r.kind == "message":
		var response = await host.show_message(r.msg)
		waiting_frame().resume(response)
		return true
	if r.kind == "command":
		var go = await waiting_frame()._host_command(r.command)
		waiting_frame().resume(go)
		return true
	return false


## 立即显示待显示的文字（MVScript 等在执行中途需要时用）
func flush_message() -> void:
	if pending_lines.is_empty():
		return
	var lines := pending_lines.duplicate()
	pending_lines.clear()
	await host.show_message({"face": "", "index": 0, "background": 0, "position": 2, "lines": lines})


# ---- 核心的环境钩子 ----

func _make_child(commands: Array) -> MVEventCore:
	return MVInterpreter.new(host, map_id, event_id, commands)


func _map_id() -> int:
	return map_id


func _event_id() -> int:
	return event_id


func _data_changed() -> void:
	host.refresh_events()


func _execute_env(c: Dictionary):
	if HOST_CODES.has(int(c.code)):
		return _request("command", "command", {"command": c})
	match int(c.code):
		202:
			# 设置载具位置（神魔战场门 Map116 EV5 把飞艇停到 Map186）：重制没有载具，只记不动
			return null
		339:
			# 强制战斗行动：MV iterateBattler 只在战斗内遍历战斗者，地图上空操作（CE2499 炭治郎-免疫负面）
			return null
	return super(c)


## 插件指令 EnemyBook open 要打开图鉴画面；PHWarehouse show <名字> 要打开仓库画面
func _host_plugin(line: String) -> bool:
	var args := line.split(" ", false)
	if args.size() >= 3 and args[0] == "PHWarehouse" and args[1] == "show":
		return host.has_method("open_warehouse")
	return args.size() >= 2 and args[0] == "EnemyBook" and args[1] == "open" and host.has_method("open_enemy_book")


## 角色朝向 [6, 角色, 方向]
func _condition_env(p: Array):
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
					await host.get_tree().physics_frame
		236:
			# 设置天气 [类型, 强度, 帧数, 等待]；战斗中无效（地图解释器不在战斗里）
			state().screen.change_weather(str(p[0]), int(p[1]), int(p[2]))
			if bool(p[3]):
				for i in range(int(p[2])):
					await host.get_tree().physics_frame
		224:
			# 画面闪烁 [颜色 r,g,b,强度, 帧数, 等待]（Game_Screen.startFlash）
			if host.has_method("flash_screen"):
				host.flash_screen(p[0], int(p[1]))
			if bool(p[2]):
				for i in range(int(p[1])):
					await host.get_tree().physics_frame
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
					await host.get_tree().process_frame
		230:
			for i in range(int(p[0])):
				await host.get_tree().process_frame
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
			var result: int = await host.start_battle(troop, bool(p[2]), bool(p[3]))
			XDungeon.battle_finished(troop, result, state().map_id)
			_branch[indent] = result
			if result == 2 and not bool(p[3]):
				host.game_over()
				return false
		302:
			var goods := [p]
			while index + 1 < list.size() and int(list[index + 1].code) == 605:
				index += 1
				goods.append(list[index].parameters)
			await host.open_shop(goods, bool(p[4]))
		205:
			# 设置移动路线 [角色, 路线]；路线勾选「等待完成」时等角色走完
			var ch = host.character(int(p[0]), event_id)
			if ch:
				ch.force_move_route(p[1])
				if bool(p[1].get("wait", false)):
					# 等待中若场所移动，旧地图的角色已释放
					while is_instance_valid(ch) and ch.is_route_forcing():
						await host.get_tree().physics_frame
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
				if bool(p[2]) and anim:
					await anim.done
		213:
			# 显示气泡 [角色, 气泡, 等待]
			var ch = host.character(int(p[0]), event_id)
			if ch:
				ch.start_balloon(int(p[1]))
				if bool(p[2]):
					while is_instance_valid(ch) and ch.is_balloon_playing():
						await host.get_tree().physics_frame
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
			while index + 1 < list.size() and int(list[index + 1].code) == 655:
				index += 1
				code += "\n" + str(list[index].parameters[0])
			for st in await MVScript.run(code, self):
				skipped.append({"code": 355, "text": str(st).left(80)})
		356:
			var line := str(p[0])
			if line.begins_with("PHWarehouse"):
				# 仓库（PH_Warehouse PHWarehouse show <名字>）：设为当前仓库并打开 Scene_Warehouse，关闭回地图；仓库不存在时不打开
				if XWarehouse.open(state(), " ".join(line.split(" ", false).slice(2))):
					await host.open_warehouse()
				return true
			# 怪物图鉴（AB_EnemyBook EnemyBook open；公共事件 2）：SceneManager.push(Scene_EnemyBook)，关闭回地图
			await host.open_enemy_book()
	return true
