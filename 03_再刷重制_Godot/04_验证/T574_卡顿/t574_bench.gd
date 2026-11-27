extends Node
## T572 量数基准（只量不改；没有 .tscn，不进检查.sh）：只跑战斗逻辑（不开画面），同一存档同一敌群，自动选招＋结算若干次行动，
## 量选招、结算、画面快照的耗时。读探针写出的 .plain.json：
##   godot --headless --audio-driver Dummy --path . res://tests/<临时>.tscn -- --save=<存档.plain.json> --troop=454 --acts=40 [--set=…]
## 函数级剖析：同一命令加 `-d --profiling --ignore-error-breaks`，标准输入接 /dev/null，退出前打印每个函数的总耗时与调用次数。

var save_path := ""
var troop := 454
var acts := 30


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.substr(7)
		elif arg.begins_with("--troop="): troop = int(arg.substr(8))
		elif arg.begins_with("--acts="): acts = int(arg.substr(7))
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
	XSave.dir_override = "user://t572_bench"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	XSave._load_data(d, 1, JSON.stringify(d))
	var s := XState.current
	var logic := XBattleLogic.new()
	var t := Time.get_ticks_usec()
	logic.setup(troop, s)
	var setup_us := Time.get_ticks_usec() - t
	logic.auto = true
	var dec := 0
	var act := 0
	var turn := 0
	var n := 0
	var views_us := 0
	var worst := 0
	while n < acts and not logic.is_over():
		t = Time.get_ticks_usec()
		logic.start_turn()
		logic.take_turn_start_logs()
		turn += Time.get_ticks_usec() - t
		while n < acts and not logic.is_over():
			var u = logic.next_subject()
			if u == null:
				break
			t = Time.get_ticks_usec()
			var cmd: Array = logic.decide(u)
			var t1 := Time.get_ticks_usec()
			logic.act(u, cmd[0], cmd[1])
			var t2 := Time.get_ticks_usec()
			logic.views()
			var t3 := Time.get_ticks_usec()
			var _ids0 := XActor.skill_ids_builds
			print("ACT %d subj=%s cmd=%s act_ms=%.1f views_ms=%.1f idb=%d" % [n, (u.display_name() if u.has_method("display_name") else str(u)), str(cmd).left(60), (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, XActor.skill_ids_builds])
			dec += t1 - t
			act += t2 - t1
			views_us += t3 - t2
			worst = maxi(worst, t2 - t1)
			n += 1
		if logic.is_over():
			break
		t = Time.get_ticks_usec()
		logic.end_turn()
		turn += Time.get_ticks_usec() - t
	print("BENCH acts=%d setup_ms=%.1f decide_ms=%.1f act_ms=%.1f (per %.1f, worst %.1f) views_ms=%.1f turn_ms=%.1f" % [n, setup_us / 1000.0, dec / 1000.0, act / 1000.0, act / 1000.0 / maxi(n, 1), worst / 1000.0, views_us / 1000.0, turn / 1000.0])
	get_tree().quit(0)
