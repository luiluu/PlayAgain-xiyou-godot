extends Node
## 淬元丹（正式版插件 Codex_PercentPills.js，XPercentPills）：玩家反馈 v0.01.09「淬元丹无法使用」。
## 原版：<CodexPill: mhp…agi> 的六颗（2882～2887）在菜单对一名队友使用，该种计数 +1（上限 20），能力值 ×(1＋2%×颗数)，
## 取整、夹 paramMax；满 20 颗 hasItemAnyValidEffects 为假（蜂鸣、不消耗）；计数存在角色上随存档。
## 重制原来只移植了商店追加，效果栏为空 → testApply 判无效，「使用」只蜂鸣。

const PILLS := {2882: 0, 2883: 2, 2884: 3, 2885: 4, 2886: 5, 2887: 6}

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _state() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
		s.actor(id).change_level(99)  # 一级时敏捷等只有个位数，×1.02 取整不变；升满好看出 2%
		s.actor(id).recover_all()
	XState.current = s
	return s


func _run() -> void:
	# 数据：六颗都认得出、都只在菜单用（occasion 2）、对一名队友（scope 7）
	var found := {}
	for x in XDB.table("Items"):
		if x is Dictionary and XPercentPills.param_of(x) >= 0:
			found[int(x.id)] = XPercentPills.param_of(x)
	check("pill_ids", found == PILLS, found)
	for id in PILLS:
		var r := XDB.rec("Items", id)
		check("pill_menu_friend_%d" % id, int(r.occasion) == 2 and int(r.scope) == 7 and r.effects.is_empty(), [r.occasion, r.scope, r.effects])
	check("not_pill", XPercentPills.param_of(XDB.rec("Items", 1693)) == -1)
	for id in PILLS:
		await _use_pill(id, int(PILLS[id]))
	await _cap()
	_save_roundtrip()
	# 发行模式（天启篇关着、发行隐藏生效）同样能吃：淬元丹是本体内容，不受发行隐藏影响
	ReleaseEntry.simulate_release = true
	var n0 := results.size()
	await _use_pill(2882, 0)
	for i in range(n0, results.size()):
		results[i].name = "release_" + results[i].name
	ReleaseEntry.simulate_release = false
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 物品页选中这颗 →「使用」→ 选第 1 位：消耗 1，计数 1，能力值 ×1.02，弹提示
func _use_pill(id: int, pid: int) -> void:
	var s := _state()
	s.gain_item(id, 2)
	# 挑这项能力最高的队员（有的角色某项能力恒 0，0×1.02 还是 0）
	var idx := 0
	for i in range(s.members().size()):
		if s.members()[i].param(pid) > s.members()[idx].param(pid):
			idx = i
	var a: XActor = s.members()[idx]
	var other: XActor = s.members()[(idx + 1) % s.members().size()]
	var before := a.param(pid)
	check("base_big_%d" % id, before >= 100.0, before)
	XToast.shown.clear()
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._item = XDB.rec("Items", id)
	page._make_actions()
	page._mode = "action"
	page._act = 0
	check("use_enabled_%d" % id, bool(page._actions[0].enabled))
	page._ok()
	check("opens_actor_%d" % id, page._mode == "actor", page._mode)
	page._actor = idx
	page._ok()
	var after := a.param(pid)
	var want := roundf(before * 1.02)
	# 外层还有运行时包装（取整、夹值），按整数比允许 ±1
	check("used_%d" % id, s.item_count(id) == 1 and XPercentPills.count(a, pid) == 1 and absf(after - want) <= 1.0 and after > before,
		[s.item_count(id), XPercentPills.count(a, pid), before, after, want])
	var msg := "%s %s +2%%（1/20）" % [a.display_name(), XItemStatusPainter.param_name(pid)]
	check("toast_%d" % id, XToast.shown.has(msg), [msg, XToast.shown])
	check("other_actor_untouched_%d" % id, XPercentPills.count(other, pid) == 0)
	page.queue_free()
	await frames()


## 满 20 颗：判无效、蜂鸣、不消耗；第 20 颗时 +40%
func _cap() -> void:
	var s := _state()
	s.gain_item(2883, 3)
	var a := s.actor(1)
	var base := a.param(2)
	a.state_data[XPercentPills.FIELD] = {"2": 19}
	a.param_mark_dirty()
	check("rate_19", absf(a.param(2) - roundf(base * 1.38)) <= 1.0, [base, a.param(2)])
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._item = XDB.rec("Items", 2883)
	page._make_actions()
	page._mode = "action"
	page._act = 0
	page._ok()
	page._actor = 0
	page._ok()
	check("twentieth", XPercentPills.count(a, 2) == 20 and s.item_count(2883) == 2 and absf(a.param(2) - roundf(base * 1.4)) <= 1.0,
		[XPercentPills.count(a, 2), s.item_count(2883), base, a.param(2)])
	check("full_invalid", not page._effective(a) and XPercentPills.valid(page._item, a) == 0)
	page._mode = "action"
	page._act = 0
	page._ok()
	page._actor = 0
	page._ok()
	check("full_not_consumed", XPercentPills.count(a, 2) == 20 and s.item_count(2883) == 2, [XPercentPills.count(a, 2), s.item_count(2883)])
	# 另一种没满的照样能吃
	page._item = XDB.rec("Items", 2884)
	check("other_kind_valid", page._effective(a))
	page.queue_free()
	await frames()


## 计数随存档：走 XSave 真实写盘读档（测试目录 user://test_xiyou_percent_pills），计数与能力值都在；
## 老存档（没有 _codexPills 键）读进来计数为 0、能力值不加成。
func _save_roundtrip() -> void:
	var old_dir := XSave.dir_override
	XSave.dir_override = "user://test_xiyou_percent_pills"
	var s := _state()
	var a := s.actor(1)
	var base := a.param(4)
	XPercentPills.apply(XDB.rec("Items", 2885), a)
	XPercentPills.apply(XDB.rec("Items", 2885), a)
	var mat := a.param(4)
	check("save_write", XSave.save(1) and FileAccess.file_exists(XSave.path(1)))
	check("save_on_disk", FileAccess.get_file_as_string(XSave.path(1)).contains("_codexPills"))
	XState.current = null
	check("save_load", XSave.load_slot(1))
	var b := XState.current.actor(1)
	check("save_count", XPercentPills.count(b, 4) == 2, b.state_data)
	check("save_param", b.param(4) == mat and mat > base, [base, mat, b.param(4)])
	# 老存档：把文件里的 _codexPills 键整个删掉再读
	var d = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(1)))
	var removed := _strip_key(d, "_codexPills")
	var f := FileAccess.open(XSave.path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check("old_save_key_removed", removed > 0 and not FileAccess.get_file_as_string(XSave.path(1)).contains("_codexPills"), removed)
	XState.current = null
	check("old_save_load", XSave.load_slot(1))
	var c := XState.current.actor(1)
	check("old_save_count_zero", XPercentPills.count(c, 4) == 0, c.state_data)
	check("old_save_param_base", c.param(4) == base, [base, c.param(4)])
	check("old_save_can_eat", XPercentPills.valid(XDB.rec("Items", 2885), c) != 0)
	DirAccess.remove_absolute(XSave.path(1))
	DirAccess.remove_absolute(XSave.path(1) + ".bak")
	DirAccess.remove_absolute(XSave.dir())
	XSave.dir_override = old_dir


func _strip_key(v, key: String) -> int:
	var n := 0
	if v is Dictionary:
		if v.has(key):
			v.erase(key)
			n += 1
		for k in v:
			n += _strip_key(v[k], key)
	elif v is Array:
		for x in v:
			n += _strip_key(x, key)
	return n
