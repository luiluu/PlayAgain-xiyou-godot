extends Node
## 【cc·未经审查】魔冠「头顶」成长账本压缩专项（XDemonCrown.COMPACT，Kyo 2026-11-14 存档与缓存清理 ②）。
## - 同一套剧本（连胜、倒下减半、失败、掉落战斗、读旧档重打、战斗外倒下）关着开关（原版写法）跑一遍、开着跑一遍：
##   每一步之后的成长、遭遇序号、头顶件数完全一样——已得的成长不丢，读旧档重打同一场照样不涨、倒下过的不再减半、不重掷掉落。
## - 开着：已结算的场次折进水位，账本里只剩最近一场和有人倒下过的；每场只写一次账本（关着两次）。
## - 老账本（原版写法攒下的几百场）开着开关打一场就折完，成长不变；折完读旧档重打照样不涨。
## - 折过的账本再关掉开关：水位照认，不能重刷。
## - 开战后被杀进程：没人倒下＝这一场没打过（账本没动）；有人倒下＝减半和那一行已经落盘，回来同一场照原版结算。
const PARTY := [1, 8, 9, 10]
var results := []
var s: XState


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))


func _fresh() -> void:
	DirAccess.remove_absolute(XDemonCrown.path_override)
	DirAccess.remove_absolute(XDemonCrown.path_override + ".bak")
	XDemonCrown.forget_ledger()
	XDemonCrown.storage_error = ""
	s = XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	s.battle_slots = PARTY.duplicate()
	s.map_id = 4
	for id in PARTY:
		var a: XActor = s.actor(id)
		a._lv = 60  # 头顶有等级要求
		a.refresh_passive()
		a.recover_all()


func _encode() -> String:
	XDemonCrown.before_save(s)
	return JSON.stringify(s.to_dict())


func _restore(text: String) -> void:
	XState.from_dict(JSON.parse_string(text))
	s = XState.current
	XDemonCrown.after_load(s, XDemonCrown.identity(text))


func _wear() -> void:
	s.gain_gear("armor", XDemonCrown.ARMOR, 1)
	var it: Dictionary = s.gear.filter(XDemonCrown.is_gear).back()
	var a: XActor = s.actor(1)
	XEquipment.change(s, a, a.equip_slots().find(17), it)
	a.refresh_passive()


func _fight(result: int, o := {}) -> void:
	s.map_id = int(o.get("map", 4))
	if o.has("origin"):
		s.flags[XYunshangOrders.ORIGIN_FLAG] = o.origin
	else:
		s.flags.erase(XYunshangOrders.ORIGIN_FLAG)
	var roll: float = o.get("roll", 0.5)
	XDemonCrown.begin(s, int(o.get("troop", 3)), func(): return roll)
	if o.has("during"):
		(o.during as Callable).call()
	XDemonCrown.finish(s, result)


func _die_once() -> void:
	var a: XActor = s.actor(1)
	a.add_state(1)
	a.remove_state(1)
	a.hp = 1.0


func _now() -> Array:
	var p = XDemonCrown.record(s)
	var bonus: Array = (p.items as Dictionary).values().map(func(r): return [snappedf(float(r.bonus), 1e-9), bool(r.removed)]) if p != null else []
	bonus.sort()
	var g := XDemonCrown.gear(s.actor(1))
	return [int(s.flags.get(XDemonCrown.SEQ_FLAG, 0)), int(s.flags.get(XDemonCrown.WORLD_FLAG, 0)), bonus, XDemonCrown.owned(s).size(),
		snappedf(XDemonCrown.bonus(g), 1e-9) if not g.is_empty() else null, XDemonCrown.storage_error]


func _rows() -> Dictionary:
	return XDemonCrown.record(s).battles


func _revision() -> int:
	return int(XDemonCrown.record(s).revision)


## 一套剧本，每一步之后记一次 _now
func _script(compact: bool) -> Array:
	XDemonCrown.COMPACT = compact
	_fresh()
	_wear()
	var log := []
	var save0 := _encode()
	for i in 3:
		_fight(0)
		log.append(_now())
	var save3 := _encode()
	_fight(0, {"during": _die_once})  # 第 3 场：倒下一次，减半；倒下的人照原版仍算赢
	log.append(_now())
	_fight(1)  # 第 4 场：输
	log.append(_now())
	_fight(0, {"troop": 539, "roll": 0.01, "map": 162, "origin": 57})  # 第 5 场：掉落战斗，掷中
	log.append(_now())
	_fight(0, {"troop": 539, "roll": 0.9, "map": 162, "origin": 57})  # 第 6 场：没掷中
	log.append(_now())
	s.map_id = 4
	_die_once()  # 战斗外倒下
	log.append(_now())
	for i in 2:
		_fight(0)
		log.append(_now())
	var save_end := _encode()
	# 读第 3 场前的旧档重打：第 3～8 场都是打过的，不涨；第 3 场再倒下一次不再减半、倒下第二次才减；掉落战斗掷中也不再发
	_restore(save3)
	log.append(_now())
	_fight(0, {"during": _die_once})
	log.append(_now())
	_fight(0, {"during": func():
		_die_once()
		_die_once()})  # 第 4 场原来没人倒下：这回倒下两次，各减半一次
	log.append(_now())
	_fight(0, {"troop": 539, "roll": 0.01, "map": 162, "origin": 57})
	log.append(_now())
	for i in 3:
		_fight(0)
		log.append(_now())
	_fight(0)  # 第 9 场：新的，涨
	log.append(_now())
	# 再读最早的档从头重打三场：都不涨
	_restore(save0)
	for i in 3:
		_fight(0)
		log.append(_now())
	_restore(save_end)
	log.append(_now())
	return log


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	var dir := OS.get_user_data_dir().path_join("test_xiyou_demon_crown_compact_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	XSave.dir_override = dir
	XDemonCrown.path_override = dir.path_join("crown_progress_test.json")

	# ---- 同一套剧本两种写法结果一样 ----
	var plain := _script(false)
	var plain_rows := _rows().size()
	var plain_bytes := FileAccess.get_file_as_bytes(XDemonCrown.path_override).size()
	var compact := _script(true)
	# 步号：0～2 连胜，3 倒下一次，4 输，5 掉落掷中，6 没掷中，7 战斗外倒下，8～9 胜；10 读旧档，11 重打第 3 场（同一次倒下），
	# 12 重打第 4 场（倒下两次），13 重打掉落战斗，14～16 重打，17 新的一场；18～20 读最早的档重打，21 读回最后的档
	check("script_ran", plain.size() == 22 and float(plain[2][4]) > 2.9 and float(plain[3][4]) < float(plain[2][4]) and plain[4][4] == plain[3][4], plain.slice(0, 5))
	check("script_drop_granted", int(plain[5][3]) == int(plain[4][3]) + 1 and int(plain[6][3]) == int(plain[5][3]), [plain[4], plain[5], plain[6]])
	check("script_world_death", float(plain[7][4]) < float(plain[6][4]) and float(plain[9][4]) > float(plain[7][4]), plain.slice(6, 10))
	check("script_replay_no_growth", plain[11][4] == plain[10][4] and plain[10][4] == plain[9][4] and float(plain[12][4]) < float(plain[11][4]) \
		and int(plain[13][3]) == int(plain[12][3]) and plain[16][4] == plain[12][4] and float(plain[17][4]) > float(plain[16][4]), plain.slice(9, 18))
	check("script_replay_from_start", plain[20][4] == plain[17][4] and int(plain[20][0]) == 3, plain.slice(17, 22))
	for i in plain.size():
		check("same_step_%d" % i, JSON.stringify(plain[i]) == JSON.stringify(compact[i]), [plain[i], compact[i]])
	var p = XDemonCrown.record(s)
	check("compact_rows_few", (p.battles as Dictionary).size() <= 4 and plain_rows >= 10, [(p.battles as Dictionary).keys(), plain_rows])
	check("compact_watermark", int(p.get(XDemonCrown.DONE, 0)) >= 9, p.get(XDemonCrown.DONE))
	check("compact_death_rows_min", (p.battles as Dictionary).has("b:3") and (p.battles["b:3"] as Dictionary).keys().size() == 2 \
		and (p.battles["b:3"].deaths as Dictionary).size() == 1 and (p.battles["b:4"] as Dictionary).keys().size() == 2 and (p.battles["b:4"].deaths as Dictionary).size() == 2, p.battles)
	check("compact_smaller", FileAccess.get_file_as_bytes(XDemonCrown.path_override).size() < plain_bytes, [plain_bytes, FileAccess.get_file_as_bytes(XDemonCrown.path_override).size()])

	# ---- 每场只写一次（关着两次） ----
	XDemonCrown.COMPACT = false
	_fresh()
	_wear()
	_fight(0)
	var r0 := _revision()
	_fight(0)
	check("plain_two_writes", _revision() - r0 == 2, _revision() - r0)
	XDemonCrown.COMPACT = true
	_fresh()
	_wear()
	_fight(0)
	r0 = _revision()
	_fight(0)
	check("compact_one_write", _revision() - r0 == 1, _revision() - r0)
	XDemonCrown.begin(s, 3, func(): return 0.5)
	check("begin_no_write", _revision() - r0 == 1 and XDemonCrown.battle != null and XDemonCrown.battle.row != null)
	XDemonCrown.finish(s, 1)
	check("lost_still_settled", _revision() - r0 == 2 and int(s.flags[XDemonCrown.SEQ_FLAG]) == 3)

	# ---- 老账本：原版写法攒 300 场，开着开关打一场就折完；成长不变；读旧档重打不涨 ----
	XDemonCrown.COMPACT = false
	_fresh()
	_wear()
	_fight(0)
	var early := _encode()
	for i in 299:
		_fight(0 if i % 7 != 3 else 1)
	var big_bytes := FileAccess.get_file_as_bytes(XDemonCrown.path_override).size()
	var big_bonus = _now()[4]
	var late := _encode()
	check("legacy_built", _rows().size() == 300 and big_bytes > 30000, [_rows().size(), big_bytes])
	XDemonCrown.COMPACT = true
	XDemonCrown.forget_ledger()
	_restore(late)
	check("legacy_load_keeps_bonus", _now()[4] == big_bonus and _rows().size() == 300)
	_fight(1)  # 输一场：不涨，只为触发一次写账本
	check("legacy_folded", _rows().size() == 1 and int(XDemonCrown.record(s).get(XDemonCrown.DONE, 0)) == 300 and _now()[4] == big_bonus, [_rows().keys(), XDemonCrown.record(s).get(XDemonCrown.DONE)])
	var small_bytes := FileAccess.get_file_as_bytes(XDemonCrown.path_override).size()
	check("legacy_file_small", small_bytes < big_bytes / 5, [big_bytes, small_bytes])
	_restore(early)
	var early_bonus = _now()[4]
	for i in 5:
		_fight(0)
	check("legacy_replay_no_growth", _now()[4] == early_bonus and early_bonus == big_bonus and int(s.flags[XDemonCrown.SEQ_FLAG]) == 6, [_now(), big_bonus])
	# 折过的账本关掉开关：水位照认，不能重刷；新打的场次照原版一行一行记
	XDemonCrown.COMPACT = false
	XDemonCrown.forget_ledger()
	_restore(early)
	for i in 5:
		_fight(0)
	check("off_after_fold_no_growth", _now()[4] == big_bonus and _rows().size() == 1, [_now(), _rows().keys()])
	_restore(late)
	_fight(1)  # 第 300 场已在
	_fight(0)
	_fight(0)
	check("off_after_fold_plain_rows", _rows().size() == 3 and float(_now()[4]) > float(big_bonus), _rows().keys())
	check("off_keeps_watermark", int(XDemonCrown.record(s).get(XDemonCrown.DONE, 0)) == 300)

	# ---- 开战后被杀进程 ----
	XDemonCrown.COMPACT = true
	_fresh()
	_wear()
	_fight(0)
	_fight(0)
	var mid := _encode()
	var rev := _revision()
	var b2 = _now()[4]
	XDemonCrown.begin(s, 3, func(): return 0.5)
	_restore(mid)  # 没人倒下就被杀：账本没动，回来这一场照常算
	check("crash_clean_no_write", _revision() == rev and not _rows().has("b:2"))
	_fight(0)
	check("crash_clean_next_grows", float(_now()[4]) > float(b2) and int(s.flags[XDemonCrown.SEQ_FLAG]) == 3)
	var mid2 := _encode()
	var b3 = _now()[4]
	XDemonCrown.begin(s, 3, func(): return 0.5)
	_die_once()  # 有人倒下：减半和这一行当场落盘
	check("crash_death_written", _rows().has("b:3") and not bool(_rows()["b:3"].settled) and is_equal_approx(float(_now()[2][0][0]), float(b3) * 0.5), _rows())
	_restore(mid2)
	check("crash_death_kept_after_reload", is_equal_approx(float(_now()[4]), float(b3) * 0.5))
	_fight(0, {"during": _die_once})  # 回来同一场：那次倒下不再减半，赢了照涨，这一行结算
	check("crash_death_refight", float(_now()[4]) > float(b3) * 0.5 and float(_now()[4]) < float(b3) and bool(_rows()["b:3"].settled), [_now(), b3])

	XDemonCrown.COMPACT = true
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	XSave.dir_override = ""
	XDemonCrown.path_override = ""
	XDemonCrown.forget_ledger()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
