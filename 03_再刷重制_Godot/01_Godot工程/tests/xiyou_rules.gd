extends Node
## 西游战斗规则对照测试：用当前正式应用参照引擎的输出（generated/oracle/slice_d<N>.json，
## 由 03_转换工具/mv_oracle/slice_probe.cjs 生成）逐项比较 Godot 的能力值与伤害。
## 伤害比较的是结算后、取整前的值；正式版的成长修正 growth 首期未移植，按 oracle 值 ÷ growth 比较。
## 运行：godot --headless --path <工程> res://tests/xiyou_rules.tscn [-- --verbose]

## 六个难度、每个难度的角色／敌群／伤害行再按序号轮流分 parts 份，一个场景管一份（xiyou_rules 是难度 1 第 0 份，
## xiyou_rules_d1b／_d1c／_d1d 是难度 1 第 1～3 份，xiyou_rules_d2／_d2b……同理），免得单场景随切片扩大逼近 600 秒超时线；并行测试按耗时慢的先派
## （2026-10-22 由每难度两份改为四份：满负载并行时单份约 395 秒，超过上限一半）
@export var difficulties: Array = [1]
@export var part := 0
@export var parts := 4
## 过期参照必须被拒的两项自检：拆分前 1～3、4～6 两份各做一次，现在由难度 1 与难度 4 的第 0 份各做一次，断言总数不变
@export var stale_checks := true
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


## 参照行的 value 与 growth 在探针里都按 6 位小数取整，value/growth 的绝对误差可达 1e-6 量级；
## 极小的伤害值（<1，如打满减伤的敌人）要放宽绝对误差，否则会误报
## growth 本身很小时（如劲夫 0.104），6 位取整的相对误差放大成 5e-7/growth，相对容差随之放宽
func _close_r6(a: float, b: float, growth := 1.0) -> bool:
	var rel := maxf(1e-6, 6e-7 / maxf(absf(growth), 1e-9))
	return absf(a - b) <= maxf(1e-5, absf(b) * rel)


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
			a.add_state(int(s))  # 加状态内部的 Game_Actor.refresh 卸下难度适应 1691 封印的装备（104 的布丁）
		a.refresh_resources()
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
	for diff in difficulties:
		var path := "res://modes/xiyou/generated/oracle/slice_d%d.json" % diff
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not d is Dictionary:
			_check("oracle_d%d_present" % diff, false, "先运行 mv_oracle/slice_probe.cjs")
			continue
		var issues := _reference_issues(manifest, d)
		if part == 0 or not issues.is_empty():  # 同 no_untranslated：其他份只在不同源时补一项失败
			_check("d%d.source_identity" % diff, issues.is_empty(), issues)
		if not issues.is_empty():
			continue
		if stale_checks and part == 0 and diff == difficulties[0]:
			var stale: Dictionary = d.duplicate(true)
			stale.sourceIdentity.inputs["data/Classes.json"] = "旧来源"
			_check("stale_oracle_rejected", not _reference_issues(manifest, stale).is_empty())
			stale = d.duplicate(true)
			stale.sourceIdentity.runtimeInputs["js/plugins.js"] = "旧脚本"
			_check("stale_runtime_rejected", not _reference_issues(manifest, stale).is_empty())
		var growth_seen := []
		# 能力值
		var actor_keys: Array = d.actors.keys()
		for k in range(part, actor_keys.size(), parts):
			var id_s = actor_keys[k]
			var id := int(id_s)
			var row: Dictionary = d.actors[id_s]
			_compare_snap("d%d.actor%d.lv1" % [diff, id], _snap(_make_actor(id, d, false)), row.lv1)
			var a := _make_actor(id, d, true)
			_compare_snap("d%d.actor%d.lv1Battle" % [diff, id], _snap(a), row.lv1Battle)
			a.change_level(10)
			a.refresh_resources()  # 参照升级后调 Game_Actor.refresh()
			_compare_snap("d%d.actor%d.lv10Battle" % [diff, id], _snap(a), row.lv10Battle)
			# 角色模板 P0：等级采样 35／65／99（升序，同一实例连续升级；参照由 slice_probe 的 levelSamples 给出）
			var samples: Dictionary = row.get("levelSamples", {})
			var lvs := samples.keys().map(func(k): return int(k))
			lvs.sort()
			for lv in lvs:
				a.change_level(lv)
				a.refresh_resources()
				a.hp = a.mhp  # 参照取样时满血（HP 低于 60% 才生效的被动不应混进能力采样）；不用 recover_all——它会清掉战斗开始状态
				_compare_snap("d%d.actor%d.lv%dBattle" % [diff, id, lv], _snap(a), samples[str(lv)])
		# 敌人
		var troops := {}  # 每份都要建全部敌群（伤害行用），能力值只比本份的
		var troop_keys: Array = d.enemies.keys()
		for t in range(troop_keys.size()):
			var tid_s = troop_keys[t]
			var mine := t % parts == part
			var list := []
			for e in d.enemies[tid_s]:
				var en := XEnemy.new().setup(int(e.id), diff, 100.0)  # 参照数据取自非神话（Math.random=0.99）
				en.setup_level(1, 0.99)  # 参照：出战成员 1 级、Math.random=0.99 → 等级 3
				list.append(en)
				if not mine:
					continue
				_compare_snap("d%d.troop%s.enemy%d" % [diff, tid_s, int(e.id)], _snap(en), e)
				_check("d%d.troop%s.enemy%d.level" % [diff, tid_s, int(e.id)], e.has("level") and en.level == int(e.level), [en.level, e.get("level")])
			troops[int(tid_s)] = list
		# 伤害
		var untranslated := []
		var battle_actors := {}  # 伤害行里同一个角色反复出场：每难度只建一次（XDamage.calculate 不改角色），否则 22 个新角色把本测试拖过超时线
		var zero_vars := []
		zero_vars.resize(5000)
		zero_vars.fill(0)
		for k in range(part, d.damage.size(), parts):
			var r: Dictionary = d.damage[k]
			var item := XDB.rec("Skills", int(r.skill))
			var user: XBattler
			var target: XBattler
			if r.get("actor") != null:
				if not battle_actors.has(int(r.actor)):
					battle_actors[int(r.actor)] = _make_actor(int(r.actor), d, true)
				user = battle_actors[int(r.actor)]
				target = troops[int(r.troop)][0]
			else:
				user = troops[int(r.troop)][0]
				if not battle_actors.has(int(r.target)):
					battle_actors[int(r.target)] = _make_actor(int(r.target), d, true)
				target = battle_actors[int(r.target)]
			var res: Dictionary = XDamage.calculate(item, user, target, {"variance": false, "critical": false, "vars": zero_vars})
			var tag := "d%d.dmg.%s%s.skill%d" % [diff, "actor" if r.get("actor") != null else "enemy", str(r.get("actor", r.get("enemy"))), int(r.skill)]
			if int(r.type) == 3 or int(r.type) == 4:
				_check(tag, _close(res.value, float(r.value)), {"godot": res.value, "mv": r.value})
				continue
			var mv_row: Dictionary = r.breakdown.row
			var growth := float(mv_row.growth)
			growth_seen.append(growth)
			var expected := float(mv_row.value) / growth if growth != 0.0 else 0.0
			_check(tag, _close_r6(res.settled, expected, growth), {"skill": r.skillName, "godot": res.settled, "mv_div_growth": expected,
				"godot_row": res.breakdown.row, "mv_row": mv_row, "godot_base": res.breakdown.base, "mv_base": r.breakdown.base})
			# slice_probe 的 final 是 onPreDamageStateEffects（Confirm＋固定减伤），不含目标 React。
			# 完整结算顺序另由 xiyou_settlement 对照真正的 onReactStateEffects。
			# 与 XDamage.finish 同：HP 伤害／吸取被元素吸收（值为负）时跳过攻击方 Confirm（installDamageElementRuntime）
			var absorbed: bool = float(r.value) < 0.0 and int(item.damage.type) in [1, 5]
			var confirmed: float = float(r.value) if absorbed else XDamage.apply_state_effects(float(r.value), item, user, target, untranslated, "confirm")
			var fin: float = XDamage.apply_fixed_mitigation(confirmed, res)
			_check(tag + ".stateEffects", _close(fin, float(r.final)), {"godot": fin, "mv": r.final})
		# 第 0 份照旧记一项；其他份只在查出未翻译时补一项失败（通过时断言总数与拆分前相同，失败也不漏）
		if part == 0 or not untranslated.is_empty():
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
