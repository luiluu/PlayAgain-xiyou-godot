extends Node
## T574 同进程交替 A/B：同一存档同一敌群、固定随机流，每个变体轮流跑 reps 遍，取最小值；附整场日志摘要（两态应相同）
## --v=标签=res://…gd:变量=true|false;res://…:变量=false   （标签 base 不带设置＝全开）
var save_path := ""
var troop := 454
var acts := 40
var reps := 3
var variants := []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.substr(7)
		elif arg.begins_with("--troop="): troop = int(arg.substr(8))
		elif arg.begins_with("--acts="): acts = int(arg.substr(7))
		elif arg.begins_with("--reps="): reps = int(arg.substr(7))
		elif arg == "--release": ReleaseEntry.simulate_release = true
		elif arg.begins_with("--v="):
			var body := arg.substr(4)
			var label := body.get_slice("=", 0)
			var sets := []
			var rest := body.substr(label.length() + 1)
			if rest != "":
				for spec in rest.split(";"):
					var at := spec.rfind(":")
					sets.append([spec.substr(0, at), spec.substr(at + 1).get_slice("=", 0), spec.substr(at + 1).get_slice("=", 1) == "true"])
			variants.append([label, sets])
	_run.call_deferred()

var _defaults := {}
func _apply(sets: Array) -> void:
	for k in _defaults:
		load(k[0]).set(k[1], _defaults[k])
	for s in sets:
		var sc = load(s[0])
		var key := [s[0], s[1]]
		if not _defaults.has(key):
			_defaults[key] = sc.get(s[1])
		sc.set(s[1], s[2])
	XActor.skills_touch()

func _plain(v, logic: XBattleLogic):
	if v is XBattler: return logic.stable_id(v)
	if v is Dictionary:
		var out := {}
		for k in v: out[str(_plain(k, logic))] = _plain(v[k], logic)
		return out
	if v is Array: return v.map(func(x): return _plain(x, logic))
	if v is Object: return "<%s>" % v.get_class()
	if v is Callable: return "<callable>"
	return v

func _once(d: Dictionary) -> Dictionary:
	XSave._load_data(d.duplicate(true), 1, "")
	var s := XState.current
	seed(20261127)
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create("0000000000574574"))
	logic.auto = true
	var journal := []
	var act_us := 0
	var dec_us := 0
	var view_us := 0
	var worst := 0
	var per := []
	var n := 0
	var b0 := XActor.skill_ids_builds
	while n < acts and not logic.is_over():
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		while n < acts and not logic.is_over():
			var u = logic.next_subject()
			if u == null: break
			var t := Time.get_ticks_usec()
			var cmd: Array = logic.decide(u)
			var t1 := Time.get_ticks_usec()
			var logs = logic.act(u, cmd[0], cmd[1])
			var t2 := Time.get_ticks_usec()
			var v = logic.views()
			var t3 := Time.get_ticks_usec()
			dec_us += t1 - t; act_us += t2 - t1; view_us += t3 - t2
			worst = maxi(worst, t2 - t1)
			per.append([int(cmd[0].id) if cmd[0] != null else 0, t2 - t1])
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logs, logic), _plain(v, logic)])
			n += 1
		if logic.is_over(): break
		journal.append(_plain(logic.end_turn(), logic))
	journal.append(logic.random.snapshot())
	var text := JSON.stringify(journal)
	return {"act": act_us, "dec": dec_us, "view": view_us, "worst": worst, "n": n, "sig": text.sha256_text().left(12), "per": per, "idb": XActor.skill_ids_builds - b0}

func _run() -> void:
	XSave.dir_override = "user://t574_ab"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var best := {}
	var sigs := {}
	var idbs := {}
	_apply([]); _once(d)  # 预热（载表、建缓存）
	for r in reps:
		for v in variants:
			_apply(v[1])
			var res := _once(d)
			var lab: String = v[0]
			sigs[lab] = sigs.get(lab, []) + [res.sig]
			idbs[lab] = res.idb
			print("AB r%d %-10s act_ms=%.1f per=%.1f worst=%.1f dec_ms=%.1f views_ms=%.1f n=%d sig=%s idb=%d" % [r, lab, res.act / 1000.0, res.act / 1000.0 / maxi(res.n, 1), res.worst / 1000.0, res.dec / 1000.0, res.view / 1000.0, res.n, res.sig, res.idb])
			if not best.has(lab) or res.act < best[lab].act:
				best[lab] = res
	_apply([])
	for v in variants:
		var b: Dictionary = best[v[0]]
		print("ABMIN %-10s act_ms=%.1f per=%.1f worst=%.1f dec_ms=%.1f views_ms=%.1f sigs=%s" % [v[0], b.act / 1000.0, b.act / 1000.0 / maxi(b.n, 1), b.worst / 1000.0, b.dec / 1000.0, b.view / 1000.0, str(sigs[v[0]])])
	get_tree().quit(0)
