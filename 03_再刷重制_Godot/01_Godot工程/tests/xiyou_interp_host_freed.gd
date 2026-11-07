extends Node
## 【cc·八戒 DJ】地图（解释器宿主）释放后，挂在 await 上的事件不再往下跑（empress_draw、skill_menu_events、casino_batch、
## save_events、transfer、party 退出时的 SCRIPT ERROR：get_tree／show_message／character on previously freed）。
## - 帧等待（223 带等待）中途释放宿主：解释器停下、发 finished，后面的文字不再显示；
## - 230 等待中途释放宿主：等完不再取下一条（原来接着调 host.get_tree／host.show_message）；
## - 宿主暂时不在树上（打开存档等界面时）：等帧照常走完、接着显示下一句（原来 host.get_tree() 是 null 报错）。
## 旧代码上前两例 finished 永远不发（协程报错中断），第三例报 null 实例。

class FakeHost extends Node:
	var log: Array
	var msg_frames := 0
	func show_message(msg: Dictionary):
		log.append("msg:" + str(msg.get("lines", [])))
		for i in msg_frames:
			await Engine.get_main_loop().process_frame
		return null
	func toast(_t: String) -> void:
		log.append("toast")
	func refresh_events() -> void:
		pass
	func character(_id: int, _ev: int):
		return null


var results: Array = []


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _cmd(code: int, params: Array) -> Dictionary:
	return {"code": code, "indent": 0, "parameters": params}


static func _text(line: String) -> Array:
	return [_cmd(101, ["", 0, 0, 2]), _cmd(401, [line])]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 跑 list，在第 free_after 帧释放（或摘下）宿主；返回 {done, log, frames}
func _case(list: Array, free_after: int, detach := false, msg_frames := 0) -> Dictionary:
	var log := []
	var host := FakeHost.new()
	host.log = log
	host.msg_frames = msg_frames
	add_child(host)
	var it := MVInterpreter.new(host, 0, 0, list)
	var st := {"done": false}
	it.finished.connect(func(): st.done = true)
	it.run()
	await _frames(free_after)
	if detach:
		remove_child(host)
	else:
		host.free()
	var n := 0
	while not st.done and n < 120:
		await _frames(1)
		n += 1
	if detach and is_instance_valid(host):
		host.free()
	return {"done": st.done, "log": log, "frames": n}


func _run() -> void:
	XState.current = XState.new_game_blank()
	XMessageBox.auto = true
	# ① 223 色调等待 30 帧中途释放
	var r := await _case([_cmd(223, [[0, 0, 0, 0], 30, true])] + _text("后面那句") + [_cmd(0, [])], 3)
	_check("tint_wait.stops", r.done and r.frames < 10, r)
	_check("tint_wait.no_msg", r.log.is_empty(), r.log)
	# ② 第一句之后 230 等 20 帧，中途释放；第二句不再显示
	r = await _case(_text("第一句") + [_cmd(230, [20])] + _text("第二句") + [_cmd(0, [])], 4)
	_check("msg.stops", r.done and r.frames < 20, r)
	_check("msg.only_first", r.log == ["msg:[\"第一句\"]"], r.log)
	# ③ 宿主摘下树但没释放：230 等待照常走完，第二句照常显示
	r = await _case([_cmd(230, [10])] + _text("第二句") + [_cmd(0, [])], 2, true)
	_check("detached.continues", r.done and r.log == ["msg:[\"第二句\"]"], r)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
