extends Node
## T572 量数探针（只量不改；不是回归测试，没有 .tscn，不进检查.sh）：玩家存档载入后开真战斗场景，自动战斗、指定变速档，量每帧耗时。
## 跑法：复制进 01_Godot工程/tests/，临时建一个挂它的 .tscn，
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tests/<临时>.tscn -- --save=<存档> --speed=1 --troop=454 --frames=2400 [--set=res://…gd:开关=false]
## --speed：1＝四倍，4＝OFF（XConfig.battle_speed）。封存的导出存档要设环境变量 XIYOU_SAVE_KEY 指向发行密钥文件（私密设计仓），
## 解开后在同目录写一份 .plain.json（存档副本，放 scratchpad，不入库），之后直接读它（旧版本没有封存也能读）。量完删掉复制件。
## 每帧打一行「T572 frame 序号 时刻 帧耗微秒」，最后一行 RESULT 是汇总。

var save_path := ""
var speed := 1
var troop := 0
var frames := 1200
var summary_only := false
var per_segment := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.substr(7)
		elif arg.begins_with("--speed="): speed = int(arg.substr(8))
		elif arg.begins_with("--troop="): troop = int(arg.substr(8))
		elif arg.begins_with("--frames="): frames = int(arg.substr(9))
		elif arg == "--summary": summary_only = true
		elif arg == "--seg=0": per_segment = false
	_switch_args()
	_run.call_deferred()


## --set=脚本路径:静态变量=true|false（可多个）：量数时切回退开关；旧版本没有这个变量就报出来，不硬设
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


func _run() -> void:
	XSave.dir_override = "user://t572_probe"
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
			get_tree().quit(2)
			return
		d = r.data
		var f := FileAccess.open(save_path.get_basename() + ".plain.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
	XSave._load_data(d, 1, JSON.stringify(d))
	var s := XState.current
	print("SAVE map=%d party=%s tianqi=%s" % [s.map_id, str(s.party), str(XTianqi.active(s))])
	for a in s.battle_members():
		print("  actor %d %s lv=%d skills=%d states=%d" % [a.actor_id, a.display_name(), a.level, a.skills().size(), a.state_ids.size()])
	if summary_only:
		get_tree().quit(0)
		return
	XConfig.set_battle_speed(speed)
	XBattleStream.PER_SEGMENT = per_segment
	var scene := XBattleScene.new()
	scene.force_auto = true
	scene.setup(troop, true, true, {})
	add_child(scene)
	var times := []
	var actions := 0
	var cur_stream = null
	var last := Time.get_ticks_usec()
	var t0 := last
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(now - last)
		print("T572 frame %d %d %d" % [i, now, now - last])
		last = now
		if not is_instance_valid(scene) or scene.is_queued_for_deletion():
			break
		var st = scene.get("_stream")
		if st != null and not is_same(st, cur_stream):
			actions += 1
		cur_stream = st
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0
	for t in times: total += t
	var big := []
	for i in times.size():
		if times[i] > 50000:
			big.append([i, times[i] / 1000])
	print("RESULT speed=%d seg=%s frames=%d total_ms=%d mean_ms=%.2f p50=%.2f p95=%.2f max=%.2f over50ms=%d actions=%d" % [speed, per_segment, times.size(), total / 1000, total / 1000.0 / times.size(), sorted[sorted.size() / 2] / 1000.0, sorted[int(sorted.size() * 0.95)] / 1000.0, sorted[-1] / 1000.0, big.size(), actions])
	print("BIG ", JSON.stringify(big))
	get_tree().quit(0)
