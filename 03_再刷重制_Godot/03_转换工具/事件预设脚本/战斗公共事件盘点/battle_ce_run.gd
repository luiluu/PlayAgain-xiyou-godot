extends Node
## 战斗公共事件盘点（cc 盘点车道 cc/battle-ce-inventory，只读）：对 BATTLE_CE_IDS（环境变量，逗号分隔）里每个公共事件
## 1) 整条在战斗里预约跑一遍（同 tests/xiyou_battle_common_events _inventory），记 common_event_skipped；
## 2) 逐条指令单独跑（跳过控制流、文字、117），记 XBattleEventRunner.skipped——补上整跑时没走到的分支。
## 结果写到环境变量 BATTLE_CE_OUT。由 战斗公共事件盘点.py 复制进工程临时目录后运行，不进 tests/。

const CONTROL := [0, 101, 102, 103, 104, 401, 402, 403, 404, 405, 411, 412, 413, 112, 113, 115, 117, 118, 119, 108, 408, 655]


func battle() -> XBattleLogic:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	for e in l.enemies:
		e.capture = false
	l.message_responder = func(_m): return null
	return l


## 步数上限防死循环（静态，整跑与逐条各自归零）
func _reset() -> void:
	MVEventCore.max_steps = 20000
	MVEventCore.steps = 0
	MVEventCore.aborted = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ids := Array(OS.get_environment("BATTLE_CE_IDS").split(",", false)).map(func(x): return int(x))
	var out := {}
	for id in ids:
		var ce := XDB.rec("CommonEvents", id)
		var rec := {"full": [], "iso": []}
		if ce.is_empty():
			rec["missing"] = true
			out[str(id)] = rec
			continue
		_reset()
		var l := battle()
		XBattleCommonEvent.reserve(l, id)
		l.common_event_skipped.clear()
		l.run_events()
		rec.full = l.common_event_skipped.duplicate()
		var list: Array = ce.get("list", [])
		var l2 := battle()
		for i in list.size():
			var c: Dictionary = list[i]
			if CONTROL.has(int(c.code)):
				continue
			var cmds := [c]
			var j := i + 1
			while j < list.size() and int(list[j].code) == 655:
				cmds.append(list[j])
				j += 1
			cmds.append({"code": 0, "indent": int(c.get("indent", 0)), "parameters": []})
			var r := XBattleEventRunner.new(l2, cmds)
			r.set_meta("common_event", id)
			_reset()
			for _k in 20:
				var res := r.advance()
				if res.kind == "done":
					break
				if r.is_waiting():
					r.waiting_frame().resume(null)
			for sk in r.skipped:
				rec.iso.append({"index": i, "code": int(sk.code), "text": str(sk.text)})
			l2.pending_force = {}
		out[str(id)] = rec
	var f := FileAccess.open(OS.get_environment("BATTLE_CE_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("BATTLE_CE_INVENTORY_DONE ", ids.size())
	get_tree().quit.call_deferred(0)
