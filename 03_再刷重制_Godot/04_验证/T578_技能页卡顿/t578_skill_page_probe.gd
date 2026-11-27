extends Node
## T578 量数探针（只量不改；不是回归测试，没有 .tscn，不进检查.sh）：玩家存档载入后开主菜单技能页（旧界面），
## 逐个出战角色量：打开（_ready＋首帧）、类型窗逐个切（含被动）、进被动列表、往下移动、翻页、滚轮、切角色，每步「操作＋下一帧」。
## 跑法：复制进 01_Godot工程/tests/，临时建一个挂它的 .tscn，
##   godot --headless --audio-driver Dummy --path . res://tests/<临时>.tscn -- --save=<存档> [--release] [--reps=3] [--set=res://…gd:开关=false]
## 封存的导出存档要设环境变量 XIYOU_SAVE_KEY 指向发行密钥文件；解开后在同目录写 .plain.json（放 scratchpad，不入库）。
## 每步一行 STEP，最后 SUMMARY 是各类操作的均值／最大（毫秒）。

var save_path := ""
var reps := 3
var moves := 16
var _actor_script = load("res://modes/xiyou/core/actor.gd")
var agg := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.substr(7)
		elif arg.begins_with("--reps="): reps = int(arg.substr(7))
		elif arg.begins_with("--moves="): moves = int(arg.substr(8))
		elif arg == "--release": ReleaseEntry.simulate_release = true
	_switch_args()
	_run.call_deferred()


func _switch_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--set="):
			continue
		var spec := arg.substr(6)
		var path := spec.get_slice(":", 0) + ":" + spec.get_slice(":", 1) if spec.begins_with("res:") else spec.get_slice(":", 0)
		var rest := spec.substr(path.length() + 1)
		var name := rest.get_slice("=", 0)
		var val := rest.get_slice("=", 1) == "true"
		var sc = load(path)
		var before = sc.get(name)
		if before == null:
			print("SWITCH_MISSING ", spec)
			continue
		sc.set(name, val)
		print("SWITCH %s.%s %s -> %s" % [path.get_file(), name, str(before), str(sc.get(name))])


func _ids_builds() -> int:
	var v = _actor_script.get("skill_ids_builds")
	return int(v) if v != null else -1


func _skills_builds() -> int:
	var v = _actor_script.get("skills_builds")
	return int(v) if v != null else -1


func _frame() -> float:
	var t := Time.get_ticks_usec()
	await get_tree().process_frame
	return (Time.get_ticks_usec() - t) / 1000.0


## 一步：f（同步操作）＋下一帧；记总耗时
func step(kind: String, label: String, f: Callable) -> void:
	var b0 := _ids_builds()
	var t := Time.get_ticks_usec()
	f.call()
	var op := (Time.get_ticks_usec() - t) / 1000.0
	var fr: float = await _frame()
	var total := op + fr
	print("STEP %s %s op=%.1f frame=%.1f total=%.1f idb=%d" % [kind, label, op, fr, total, _ids_builds() - b0 if b0 >= 0 else -1])
	if not agg.has(kind):
		agg[kind] = []
	agg[kind].append(total)


func _load_save() -> bool:
	XSave.dir_override = "user://t578_probe"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir())
	var d: Dictionary
	if save_path.ends_with(".plain.json"):
		d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	else:
		var sealer = load("res://modes/xiyou/core/save_seal.gd")
		sealer.key_file_override = OS.get_environment("XIYOU_SAVE_KEY")
		sealer.reload_keys()
		var r: Dictionary = XSaveTransfer.read_import(save_path)
		if r.has("error"):
			print("IMPORT_ERROR ", r.error)
			return false
		d = r.data
		var f := FileAccess.open(save_path.get_basename() + ".plain.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
	XSave._load_data(d, 1, JSON.stringify(d))
	return true


func _run() -> void:
	if not _load_save():
		get_tree().quit(2)
		return
	var s := XState.current
	print("SAVE release=%s map=%d party=%s tianqi=%s skin=%s" % [str(ReleaseEntry.simulate_release), s.map_id, str(s.party), str(XTianqi.active(s)), str(XUiSkin.on())])
	for aid in s.party:
		var a := s.actor(aid)
		var by_type := {}
		for sk in a.skills():
			var st := int(sk.get("stypeId", 0))
			by_type[st] = int(by_type.get(st, 0)) + 1
		print("  actor %d %s lv=%d skills=%d by_stype=%s states=%d" % [a.actor_id, a.display_name(), a.level, a.skills().size(), str(by_type), a.state_ids.size()])
	var idle := 0.0
	for i in 10:
		idle += await _frame()
	print("IDLE_FRAME_MS=%.3f" % (idle / 10.0))
	for rep in reps:
		var page := XSkillScene.new()
		page.actor_index = 0
		var t0 := Time.get_ticks_usec()
		add_child(page)
		var op := (Time.get_ticks_usec() - t0) / 1000.0
		var fr: float = await _frame()
		print("STEP open r%d op=%.1f frame=%.1f total=%.1f" % [rep, op, fr, op + fr])
		if not agg.has("open"):
			agg["open"] = []
		agg["open"].append(op + fr)
		await _frame()
		for ai in s.party.size():
			var a := page.actor()
			var types := page.types()
			var label := "a%d" % a.actor_id
			# 类型窗逐个往下（每切一格，状态窗、列表预览都重画）
			for ti in range(1, types.size()):
				await step("type_move", "%s t%d" % [label, types[ti]], func(): page._move(1, false, false))
			# 回到被动（stypeId 4）那一格，进列表
			var pi := types.find(4)
			if pi < 0:
				pi = types.size() - 1
			await step("type_jump", "%s to%d" % [label, types[pi]], func():
				page.type_index = pi
				page._refresh())
			await step("enter_list", "%s n=%d" % [label, page.entries().size()], func():
				page.mode = "list"
				page.index = 0
				page.top = 0
				page._refresh())
			for i in moves:
				await step("list_move", "%s i%d" % [label, page.index], func(): page._move(1, false, false))
			for i in 3:
				await step("list_page", label, func(): page._page(1))
			for i in 3:
				await step("list_wheel", label, func(): page._wheel(1))
			await step("back_type", label, func():
				page.mode = "type"
				page._refresh())
			await step("change_actor", label, func(): page.change_actor(1))
		page.queue_free()
		await _frame()
		await _frame()
	var keys := agg.keys()
	keys.sort()
	for k in keys:
		var arr: Array = agg[k]
		var sum := 0.0
		var mx := 0.0
		for v in arr:
			sum += v
			mx = maxf(mx, v)
		print("SUMMARY %s n=%d mean=%.1f max=%.1f" % [k, arr.size(), sum / arr.size(), mx])
	print("MISMATCH %d" % (_actor_script.get("read_mismatches") as Array).size())
	get_tree().quit(0)
