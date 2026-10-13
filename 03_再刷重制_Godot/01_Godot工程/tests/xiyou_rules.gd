extends Node
## 西游战斗规则对照测试：用当前正式应用参照引擎的输出（generated/oracle/slice_d<N>.json，
## 由 03_转换工具/mv_oracle/slice_probe.cjs 生成）逐项比较 Godot 的能力值与伤害。
## 伤害比较的是结算后、取整前的值；正式版的成长修正 growth 首期未移植，按 oracle 值 ÷ growth 比较。
## 运行：godot --headless --path <工程> res://tests/xiyou_rules.tscn [-- --verbose]

const DIFFICULTIES := [1, 2, 3, 4, 5, 6]
var results: Array = []
var mismatches: Array = []
var verbose := false


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		mismatches.append({"name": name, "detail": detail})


func _close(a: float, b: float, rel := 1e-6) -> bool:
	return absf(a - b) <= maxf(1e-6, absf(b) * rel)


func _arr_close(a: Array, b: Array, rel := 1e-6) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not _close(float(a[i]), float(b[i]), rel):
			return false
	return true


func _snap(b: XBattler) -> Dictionary:
	return {"param": range(8).map(func(i): return b.param(i)),
		"xparam": range(10).map(func(i): return b.xparam(i)),
		"sparam": range(10).map(func(i): return b.sparam(i)),
		"elementRates": [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15].map(func(e): return b.element_rate(e))}


func _compare_snap(tag: String, mine: Dictionary, theirs: Dictionary) -> void:
	for k in ["param", "xparam", "sparam", "elementRates"]:
		_check("%s.%s" % [tag, k], _arr_close(mine[k], theirs[k], 1e-4), {"godot": mine[k], "mv": theirs[k]})


## 开局被动照对照基准：全体的 passives，开局可选的角色（starters）另加 starterPassives
func _make_actor(id: int, d: Dictionary, battle: bool) -> XActor:
	var a := XActor.new().setup(id)
	var list: Array = d.passives.duplicate()
	if d.get("starters", []).map(func(v): return int(v)).has(id):
		list.append_array(d.get("starterPassives", []))
	for s in list:
		a.learn_skill(int(s))
	if battle:
		for s in d.startStates:
			a.add_state(int(s))
	a.refresh_passive()
	return a


## 数据、规则脚本与版本必须同源；旧 oracle 即使数值碰巧相同也不能作为本轮对照。
func _reference_issues(manifest: Dictionary, reference: Dictionary) -> Array:
	var issues := []
	var identity: Dictionary = reference.get("sourceIdentity", {})
	if identity.get("releaseVersion") != manifest.get("releaseVersion"):
		issues.append("来源版本不一致")
	var runtime: Dictionary = manifest.get("runtimeInputs", {})
	if runtime.is_empty() or runtime != identity.get("runtimeInputs", {}):
		issues.append("运行脚本指纹不一致")
	var hashes: Dictionary = identity.get("inputs", {})
	for rel in manifest.get("inputs", {}):
		if rel.begins_with("data/") or rel in ["package.json", "js/plugins.js"]:
			var actual = identity.get("runtimeInputs", {}).get(rel) if rel == "js/plugins.js" else hashes.get(rel)
			if actual != manifest.inputs[rel]:
				issues.append("输入指纹不一致：" + rel)
	var expected_actors: Array = manifest.get("slice", {}).get("actors", [])
	var ids: Array = reference.get("actors", {}).keys().map(func(id): return int(id))
	expected_actors = expected_actors.map(func(id): return int(id))
	expected_actors.sort(); ids.sort()
	if ids != expected_actors:
		issues.append("队伍切片不一致")
	return issues


func _run() -> void:
	if not XDB.available():
		_check("generated_data_present", false, "先运行 03_转换工具/xiyou_export.py")
		return _finish()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + "manifest.json"))
	if not manifest is Dictionary:
		_check("conversion_manifest_present", false)
		return _finish()
	for diff in DIFFICULTIES:
		var path := "res://modes/xiyou/generated/oracle/slice_d%d.json" % diff
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not d is Dictionary:
			_check("oracle_d%d_present" % diff, false, "先运行 mv_oracle/slice_probe.cjs")
			continue
		var issues := _reference_issues(manifest, d)
		_check("d%d.source_identity" % diff, issues.is_empty(), issues)
		if not issues.is_empty():
			continue
		if diff == DIFFICULTIES[0]:
			var stale: Dictionary = d.duplicate(true)
			stale.sourceIdentity.inputs["data/Classes.json"] = "旧来源"
			_check("stale_oracle_rejected", not _reference_issues(manifest, stale).is_empty())
			stale = d.duplicate(true)
			stale.sourceIdentity.runtimeInputs["js/plugins.js"] = "旧脚本"
			_check("stale_runtime_rejected", not _reference_issues(manifest, stale).is_empty())
		var growth_seen := []
		# 能力值
		for id_s in d.actors:
			var id := int(id_s)
			var row: Dictionary = d.actors[id_s]
			_compare_snap("d%d.actor%d.lv1" % [diff, id], _snap(_make_actor(id, d, false)), row.lv1)
			var a := _make_actor(id, d, true)
			_compare_snap("d%d.actor%d.lv1Battle" % [diff, id], _snap(a), row.lv1Battle)
			a.change_level(10)
			_compare_snap("d%d.actor%d.lv10Battle" % [diff, id], _snap(a), row.lv10Battle)
		# 敌人
		var troops := {}
		for tid_s in d.enemies:
			var list := []
			for e in d.enemies[tid_s]:
				var en := XEnemy.new().setup(int(e.id), diff, 100.0)  # 参照数据取自非神话（Math.random=0.99）
				list.append(en)
				_compare_snap("d%d.troop%s.enemy%d" % [diff, tid_s, int(e.id)], _snap(en), e)
			troops[int(tid_s)] = list
		# 伤害
		var untranslated := []
		var zero_vars := []
		zero_vars.resize(5000)
		zero_vars.fill(0)
		for r in d.damage:
			var item := XDB.rec("Skills", int(r.skill))
			var user: XBattler
			var target: XBattler
			if r.get("actor") != null:
				user = _make_actor(int(r.actor), d, true)
				target = troops[int(r.troop)][0]
			else:
				user = troops[int(r.troop)][0]
				target = _make_actor(int(r.target), d, true)
			var res: Dictionary = XDamage.calculate(item, user, target, {"variance": false, "critical": false, "vars": zero_vars})
			var tag := "d%d.dmg.%s%s.skill%d" % [diff, "actor" if r.get("actor") != null else "enemy", str(r.get("actor", r.get("enemy"))), int(r.skill)]
			if int(r.type) == 3 or int(r.type) == 4:
				_check(tag, _close(res.value, float(r.value)), {"godot": res.value, "mv": r.value})
				continue
			var mv_row: Dictionary = r.breakdown.row
			var growth := float(mv_row.growth)
			growth_seen.append(growth)
			var expected := float(mv_row.value) / growth if growth != 0.0 else 0.0
			_check(tag, _close(res.settled, expected), {"skill": r.skillName, "godot": res.settled, "mv_div_growth": expected,
				"godot_row": res.breakdown.row, "mv_row": mv_row, "godot_base": res.breakdown.base, "mv_base": r.breakdown.base})
			# 状态脚本：用正式版的结算值套 Godot 的效果，应与正式版最终值一致
			var fin: float = XDamage.apply_state_effects(float(r.value), item, user, target, untranslated)
			_check(tag + ".stateEffects", _close(fin, float(r.final)), {"godot": fin, "mv": r.final})
		_check("d%d.no_untranslated_state_effects" % diff, untranslated.is_empty(), untranslated.slice(0, 5))
		if verbose:
			print("d%d growth range: %s..%s" % [diff, growth_seen.min(), growth_seen.max()])
	_finish()


func _finish() -> void:
	var passed := results.filter(func(r): return r["passed"]).size()
	if verbose or passed != results.size():
		for m in mismatches.slice(0, 12):
			print("MISMATCH ", m.name, " ", JSON.stringify(m.detail).left(900))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "failedSample": mismatches.slice(0, 3).map(func(m): return m.name)}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
