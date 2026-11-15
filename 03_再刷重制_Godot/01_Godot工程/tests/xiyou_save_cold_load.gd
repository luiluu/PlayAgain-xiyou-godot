extends Node
## 玩家反馈 v0.01.10（安卓）：强退后重进读档，流萤二阶进阶的主动、被动技能没了，云裳装备没了。
## 冷启动读档＝进程刚起、XState.current 还是 null（或是另一局）时读档。真写盘、走 XSave 的读档入口（存档页 load_slot、标题「继续」load_auto）。

var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _skills(a: XActor) -> Array:
	var ids: Array = Array(a.skill_ids).duplicate()
	ids.sort()
	return ids


static func _equips(a: XActor) -> Array:
	return a.equips.map(func(e): return int(e.base) if e is Dictionary else 0)


func _build() -> XState:
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	XLiuying.recruit(s)
	XYunshang.recruit(s)
	var ly: XActor = s.actor(XLiuying.ACTOR)
	ly.change_level_mv(65)
	s.actor_advance[XLiuying.ACTOR] = 2
	XLiuying.sync(ly)
	var ys: XActor = s.actor(XYunshang.ACTOR)
	ys.change_level_mv(55)
	s.actor_advance[XYunshang.ACTOR] = 2
	XYunshang.sync(ys)
	for base in [XYunshang.RELIC, XYunshang.ROBE_FIRST]:
		var e := XGear.template("armor", base)
		s.register_gear(e)
		s.gear.append(e)
		XEquipment.change(s, ys, ys.equip_slots().find(int(e.etypeId)), e)
	_fill(s, ys)
	return s


## 其余空栏各挑数据库里第一件穿得上的（真实玩家的云裳一身都是装备）
static func _fill(s: XState, a: XActor) -> void:
	for kind in ["weapon", "armor"]:
		var table: Array = XDB.table("Weapons" if kind == "weapon" else "Armors")
		for rec in table:
			if not rec is Dictionary or str(rec.get("name", "")) == "":
				continue
			var empty := range(a.equips.size()).filter(func(i): return a.equips[i] == null)
			if empty.is_empty():
				return
			var e := XGear.template(kind, int(rec.id))
			for i in empty:
				if XEquipment.fits(a, i, e):
					s.register_gear(e)
					s.gear.append(e)
					if XEquipment.change(s, a, i, e):
						break


func _run() -> void:
	XSave.dir_override = OS.get_user_data_dir().path_join("test_save_cold_load_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	XYunshangOrders.path_override = XSave.dir_override.path_join(XYunshangOrders.FILE)
	var s := _build()
	var ly: XActor = s.actor(XLiuying.ACTOR)
	var ys: XActor = s.actor(XYunshang.ACTOR)
	var want_ly := _skills(ly)
	var want_ys := _skills(ys)
	var want_eq := _equips(ys)
	check("setup.liuying_rank2_skills", want_ly.has(XLiuying.RANSHAO) and want_ly.has(XLiuying.XING_HE) and want_ly.has(XLiuying.FEI_YING), want_ly)
	check("setup.yunshang_equipped", want_eq.has(XYunshang.RELIC), want_eq)
	check("save_slot", XSave.save(1))
	check("save_auto", XSave.save_auto())
	check("setup.yunshang_full", want_eq.filter(func(b): return b > 0).size() >= 10, want_eq)
	var saved_release := ReleaseEntry.simulate_release
	for how in ["slot", "auto", "release_slot", "release_auto"]:
		ReleaseEntry.simulate_release = how.begins_with("release")  # 发行模拟：天启篇关着、异化隐藏（XAlienHide）
		XState.current = null  # 冷启动：进程刚起，还没有当前局
		var ok := XSave.load_slot(1) if how.ends_with("slot") else XSave.load_auto()
		check(how + ".loaded", ok)
		if not ok:
			continue
		var l2: XActor = XState.current.actor(XLiuying.ACTOR)
		var y2: XActor = XState.current.actor(XYunshang.ACTOR)
		check(how + ".liuying_rank", XAdvance.rank(XState.current, XLiuying.ACTOR) == 2)
		check(how + ".liuying_skills", _skills(l2) == want_ly, [_skills(l2), want_ly])
		check(how + ".yunshang_skills", _skills(y2) == want_ys, [_skills(y2), want_ys])
		check(how + ".yunshang_equips", _equips(y2) == want_eq, [_equips(y2), want_eq])
	ReleaseEntry.simulate_release = saved_release
	# 局中读另一个进阶次数不同的档：读档同步看的是新档，不是读档前那一局
	var other := _build()
	other.actor_advance[XLiuying.ACTOR] = 0
	XState.current = other
	check("other_then_load", XSave.load_slot(1) and _skills(XState.current.actor(XLiuying.ACTOR)) == want_ly, _skills(XState.current.actor(XLiuying.ACTOR)))
	# 没打补丁的版本的补救（给玩家的说明）：进游戏后在存档页再读一次同一格——这时当前局就是这一档，进阶次数对得上，技能学回来
	XState.current = null
	XSave.load_slot(1)
	check("reload_in_game", XSave.load_slot(1) and _skills(XState.current.actor(XLiuying.ACTOR)) == want_ly, _skills(XState.current.actor(XLiuying.ACTOR)))
	XSave.remove_auto()
	for i in range(1, XSave.SLOTS + 1):
		XSave.remove(i)
	for fname in DirAccess.get_files_at(XSave.dir_override):
		DirAccess.remove_absolute(XSave.dir_override.path_join(fname))
	DirAccess.remove_absolute(XSave.dir_override)
	XSave.dir_override = ""
	XYunshangOrders.path_override = ""
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
