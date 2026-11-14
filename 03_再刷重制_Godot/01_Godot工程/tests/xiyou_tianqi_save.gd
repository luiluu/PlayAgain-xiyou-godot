extends Node
## 天启篇存档门面专项（XTianqiSave，cc/save-rng-facade S1）：分区懒建与版本、老档缺字段初始化、读档后入口幂等、
## 打样分区 drop／qiyin／gojo 的迁移与关开关、装备复制去键、西游档不受影响。存读全部走共用夹具的真实写盘读档
## （tests/lib/tq_save_kit.gd：XSave.save → XSave.load_slot）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _drop_seed(s: XState) -> int:
	return XOrbs.hash32("tianqi-drop|%d" % int(s.orb_seed))


func _qiyin_seed(s: XState) -> String:
	return XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "qiyin")


func _tq_json(s: XState) -> String:
	return JSON.stringify(s.flags.get("tianqi", {}), "", true)


# ---- 登记表与懒建 ----

func _registry() -> void:
	_check("wired_registered", XTianqiSave.WIRED.all(func(n): return XTianqiSave.SECTIONS.has(n)))
	_check("vkey_sections", str(XTianqiSave.SECTIONS.gojo.vkey) == XTianqiGojoTrial.MIGRATE_KEY and str(XTianqiSave.SECTIONS.no_diff_passive.vkey) == XTianqiNoDiffPassive.MARK)
	var s := Kit.new_game()
	_check("new_lazy", XTianqiSave.peek(s, "drop") == null and XTianqiSave.peek(s, "qiyin") == null, s.flags.tianqi.keys())
	var vs := XTianqiSave.versions(s)
	_check("new_versions", int(vs.get("gojo", 0)) == XTianqiGojoTrial.TABLE_VERSION and not vs.has("drop") and not vs.has("qiyin"), vs)
	var d := XTianqiDrop.store(s)
	_check("drop_made", int(d.seed) == _drop_seed(s) and d.pity is Dictionary and d.pity.is_empty() and XTianqiSave.version(s, "drop") == 1, d)
	_check("drop_same_dict", is_same(XTianqiDrop.store(s), s.flags.tianqi.drop))
	var q := XTianqiQiyin.progress(s)
	_check("qiyin_made", str(q.seed) == _qiyin_seed(s) and int(q.keys) == 0 and int(q.rng_n) == 0 and q.bag is Array and q.drop is Dictionary
		and XTianqiSave.version(s, "qiyin") == 1, q.keys())
	# 老写法逐键对照：残缺的七印区补出来的就是老 progress() 会补的那些
	s.flags.tianqi["qiyin"] = {"keys": 3, "bag": "坏", "seed": ""}
	q = XTianqiQiyin.progress(s)
	_check("qiyin_fill_like_old", int(q.keys) == 3 and int(q.shards) == 0 and int(q.field_keys) == 0 and int(q.artifact_miss) == 0
		and q.bag == [] and q.artifacts == [] and str(q.seed) == _qiyin_seed(s) and q.drop == XTianqiQiyinDrop.new_state(), q)
	# 招牌掉落「必掉也不新建账」：peek 判断不建区
	var s2 := Kit.new_game()
	XTianqiDrop.roll_signature(s2, "1:2:3", 1.0)
	_check("sure_no_new_acct", XTianqiSave.peek(s2, "drop") == null)
	_check("fails_no_acct", XTianqiDrop.signature_fails(s2, "1:2:3") == 0 and XTianqiSave.peek(s2, "drop") == null)
	XTianqiDrop.store(s2).pity["1:2:3"] = [4, 9]
	XTianqiDrop.roll_signature(s2, "1:2:3", 1.0)
	_check("sure_resets_existing", s2.flags.tianqi.drop.pity["1:2:3"] == [0, 10], s2.flags.tianqi.drop.pity)


# ---- 真实写盘读档 ----

func _disk() -> void:
	var s := Kit.new_game()
	XTianqiDrop.store(s).pity["9:2:9"] = [2, 7]
	XTianqiQiyin.progress(s)["keys"] = 5
	var seed0 := int(s.flags.tianqi.drop.seed)
	var qseed0 := str(s.flags.tianqi.qiyin.seed)
	var b := kit.roundtrip()
	_check("rt_loaded", b != null)
	if b == null:
		return
	_check("rt_drop", int(XTianqiDrop.store(b).seed) == seed0 and Array(XTianqiDrop.store(b).pity["9:2:9"]).map(func(v): return int(v)) == [2, 7])
	_check("rt_qiyin", int(XTianqiQiyin.progress(b).keys) == 5 and str(XTianqiQiyin.progress(b).seed) == qseed0)
	_check("rt_versions", XTianqiSave.version(b, "drop") == 1 and XTianqiSave.version(b, "qiyin") == 1 and XTianqiSave.version(b, "gojo") == XTianqiGojoTrial.TABLE_VERSION,
		XTianqiSave.versions(b))
	# 幂等：再存读两次，天启篇区一字不差
	var j1 := _tq_json(kit.roundtrip())
	var j2 := _tq_json(kit.roundtrip())
	_check("rt_idempotent", j1 == j2)
	# 老档：整个掉落账、版本区都没有 → 读档不建账（懒建），第一次用时种子与新档公式一致
	kit.legacy(["drop", "v"])
	var l1 := kit.reload()
	_check("legacy_drop_lazy", l1 != null and XTianqiSave.peek(l1, "drop") == null and XTianqiSave.version(l1, "qiyin") == 1, XTianqiSave.versions(l1))
	_check("legacy_drop_seed", int(XTianqiDrop.store(l1).seed) == seed0 and XTianqiSave.version(l1, "drop") == 1)
	# 老档：掉落账在、缺 pity 和版本 → 读档就补上并记版本，种子不动
	XTianqiDrop.store(l1).pity["5:2:5"] = [1, 1]
	kit.save()
	kit.legacy(["v", "drop/pity", "qiyin/seed", "qiyin/rng_n"])
	var raw_tq: Dictionary = kit.raw().flags.tianqi
	_check("legacy_raw_stripped", not raw_tq.has("v") and not raw_tq.drop.has("pity") and not raw_tq.qiyin.has("seed"))
	var l2 := kit.reload()
	_check("legacy_after_load_fills", l2 != null and l2.flags.tianqi.drop.get("pity") is Dictionary and l2.flags.tianqi.drop.pity.is_empty()
		and int(l2.flags.tianqi.drop.seed) == seed0, l2.flags.tianqi.drop if l2 != null else null)
	_check("legacy_qiyin_seed", str(l2.flags.tianqi.qiyin.get("seed", "")) == qseed0 and int(l2.flags.tianqi.qiyin.get("rng_n", -1)) == 0 and int(l2.flags.tianqi.qiyin.keys) == 5)
	_check("legacy_stamped", XTianqiSave.version(l2, "drop") == 1 and XTianqiSave.version(l2, "qiyin") == 1)
	# 门面开关关：读档不跑迁移、不记版本；用到时模块照旧补（结果相同）；再开读档补记
	kit.save()
	kit.legacy(["v", "drop/pity"])
	XTianqiSave.ENABLED = false
	var o := kit.reload()
	_check("off_no_stamp", o != null and not o.flags.tianqi.has("v") and not o.flags.tianqi.drop.has("pity"), o.flags.tianqi.keys() if o != null else null)
	_check("off_module_fills", XTianqiDrop.store(o).pity is Dictionary and not o.flags.tianqi.has("v"))
	XTianqiSave.ENABLED = true
	var o2 := kit.reload()
	_check("on_again_stamps", o2 != null and XTianqiSave.version(o2, "drop") == 1 and o2.flags.tianqi.drop.pity is Dictionary)


# ---- 五条悟：迁移挪到 from_dict 末尾 ----

func _gojo() -> void:
	var s := Kit.new_game()
	s.flags.tianqi.erase(XTianqiGojoTrial.MIGRATE_KEY)
	# 只走 from_dict（不经 XSave）也迁移了：以前要到 XSave._load_data 才迁
	var b := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("gojo_from_dict_migrates", XTianqiSave.version(b, "gojo") == XTianqiGojoTrial.TABLE_VERSION, b.flags.tianqi.keys())
	# 关两阶表：反迁移记 2；再读一次不动（幂等）
	XTianqiGojoTrial.ENABLED = false
	var off := XState.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	var off2 := XState.from_dict(JSON.parse_string(JSON.stringify(off.to_dict())))
	XTianqiGojoTrial.ENABLED = true
	_check("gojo_off_revert", XTianqiSave.version(off, "gojo") == XTianqiGojoTrial.OLD_VERSION and int(off.flags.tianqi[XTianqiGojoTrial.MIGRATE_KEY]) == XTianqiGojoTrial.OLD_VERSION)
	_check("gojo_off_once", XTianqiSave.version(off2, "gojo") == XTianqiGojoTrial.OLD_VERSION)
	# 门面关着：from_dict 不迁移，XSave._load_data 里照旧迁移
	XState.current = s
	XTianqiSave.ENABLED = false
	var f := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("gojo_off_facade_from_dict", XTianqiSave.version(f, "gojo") == 0)
	XState.current = f
	var d := kit.roundtrip()
	XTianqiSave.ENABLED = true
	_check("gojo_off_facade_load_slot", d != null and XTianqiSave.version(d, "gojo") == XTianqiGojoTrial.TABLE_VERSION)


# 五条悟真实角色＋存档时正在试炼（小A 甲档漏测）：老档（没有进阶表标记、旧四阶 4 阶）存档时人在试炼里，
# 读档门面先迁移（from_dict 末尾）、XSave._load_data 再还原试炼现场；两者交集只有生命夹值，断言迁移和还原都对
func _gojo_in_trial() -> void:
	var s := Kit.new_game()
	var before_party := s.party.duplicate()
	XTianqi._joining = true
	s.add_actor(XGojo.ACTOR)
	XTianqi._joining = false
	var a: XActor = s.actor(XGojo.ACTOR)
	a.change_level(80)
	a.recover_all()
	a.refresh_passive()
	var party := s.party.duplicate()
	var slots := s.battle_slots.duplicate()
	var want_hp := maxf(1.0, floorf(a.mhp / 3.0))
	a.hp = want_hp
	_check("gojo_trial_begin", XTianqiGojoTrial.begin(s, 1) and s.party == [XGojo.ACTOR], [before_party, s.party])
	a.hp = 1.0  # 试炼里打残了
	s.actor_advance[XGojo.ACTOR] = 4  # 旧四阶表
	_check("gojo_trial_saved", kit.save())
	kit.legacy([XTianqiGojoTrial.MIGRATE_KEY])  # 老档：没有进阶表标记、也没有通过记录＝纯旧四阶
	var b := kit.reload()
	var ba: XActor = b.actor(XGojo.ACTOR) if b != null else null
	_check("gojo_trial_migrated", b != null and XAdvance.rank(b, XGojo.ACTOR) == 2 and XTianqiGojoTrial.passed(b) == [1, 2]
		and XTianqiSave.version(b, "gojo") == XTianqiGojoTrial.TABLE_VERSION, [XAdvance.rank(b, XGojo.ACTOR), XTianqiGojoTrial.passed(b)] if b != null else null)
	_check("gojo_trial_restored", b != null and not XTianqiGojoTrial.in_trial(b) and b.party == party and b.battle_slots == slots
		and ba != null and is_equal_approx(ba.hp, minf(want_hp, ba.mhp)), [b.party, party, ba.hp if ba != null else null, want_hp] if b != null else null)
	var c := kit.roundtrip()
	_check("gojo_trial_stable", c != null and XAdvance.rank(c, XGojo.ACTOR) == 2 and XTianqiGojoTrial.passed(c) == [1, 2] and c.party == party)


# ---- 小A 甲档返修 ----

func _review_fixes() -> void:
	# P2-1：西游档残留空 tianqi 表（rules 缺）：门面一律当非天启篇档，取分区不写进去；真实写盘读档后仍是空表
	var w := XState.new()
	w.flags["tianqi"] = {}
	XState.current = w
	var wd: Dictionary = XTianqiSave.section(w, "drop")
	var wq := XTianqiQiyin.progress(w)
	var wf = XTianqiSave.section(w, "famine_prologue")
	XTianqiSave.set_version(w, "drop", 9)
	_check("xiyou_empty_tq_detached", wd.pity is Dictionary and wq.has("seed") and wf is Array and (w.flags.tianqi as Dictionary).is_empty()
		and XTianqiSave.peek(w, "drop") == null and XTianqiSave.versions(w).is_empty() and XTianqiSave.root(w).is_empty(), w.flags.tianqi)
	var wb := kit.roundtrip()
	_check("xiyou_empty_tq_disk", wb != null and wb.flags.get("tianqi") is Dictionary and (wb.flags.tianqi as Dictionary).is_empty()
		and XTianqiSave.version(wb, "drop") == 0, wb.flags.get("tianqi") if wb != null else null)
	XTianqiDrop.store(wb)
	var wb2 := kit.roundtrip()
	_check("xiyou_empty_tq_disk_after_use", wb2 != null and (wb2.flags.get("tianqi", {}) as Dictionary).is_empty(), wb2.flags.get("tianqi") if wb2 != null else null)
	# 天启篇档 root() 是 flags.tianqi 本体：经它写的键存读后还在
	var s := Kit.new_game()
	var r := XTianqiSave.root(s)
	r["line"] = "plague"
	_check("root_is_live", is_same(r, s.flags.tianqi) and not r.is_empty())
	var rb := kit.roundtrip()
	_check("root_roundtrip", rb != null and str(XTianqiSave.root(rb).get("line")) == "plague" and is_same(XTianqiSave.root(rb), rb.flags.tianqi))
	# P2-3：数组形分区（famine_prologue）section 返回／新建数组，记版本，存读后还是数组
	var s2 := Kit.new_game()
	s2.flags.tianqi.erase("famine_prologue")
	var fp = XTianqiSave.section(s2, "famine_prologue")
	_check("array_section_made", fp is Array and is_same(fp, s2.flags.tianqi.get("famine_prologue")) and XTianqiSave.version(s2, "famine_prologue") == 1
		and XTianqiSave.peek(s2, "famine_prologue") is Array, s2.flags.tianqi.get("famine_prologue"))
	fp.append(3)
	var again = XTianqiSave.section(s2, "famine_prologue")
	_check("array_section_same", is_same(again, fp) and again == [3])
	s2.flags.tianqi["famine_prologue"] = {"bad": 1}  # 形状不对：peek 不认、section 换成数组
	_check("array_section_shape", XTianqiSave.peek(s2, "famine_prologue") == null and XTianqiSave.section(s2, "famine_prologue") is Array)
	XTianqiSave.section(s2, "famine_prologue").append(5)
	var fb := kit.roundtrip()
	_check("array_section_disk", fb != null and fb.flags.tianqi.get("famine_prologue") is Array and (XTianqiSave.section(fb, "famine_prologue") as Array).map(func(v): return int(v)) == [5],
		fb.flags.tianqi.get("famine_prologue") if fb != null else null)
	_check("dict_section_not_array", XTianqiSave.section(fb, "drop") is Dictionary and not XTianqiSave.is_array("drop") and XTianqiSave.is_array("famine_prologue"))


# ---- 其它 ----

func _misc() -> void:
	var plain := XState.new()
	_check("plain_peek", XTianqiSave.peek(plain, "drop") == null and XTianqiSave.root(plain).is_empty())
	var tmp: Dictionary = XTianqiSave.section(plain, "drop")
	_check("plain_section_detached", tmp.pity is Dictionary and not plain.flags.has("tianqi"))
	var pb := XState.from_dict(JSON.parse_string(JSON.stringify(plain.to_dict())))
	_check("plain_after_load_noop", not pb.flags.has("tianqi"))
	var it := {"name": "x", "tianqi_affixes": [1], "tq_seed_id": "00", "tq_rng_n": 3, "tq_reforges": 2}
	XTianqiSave.strip_on_copy(it)
	_check("strip_on_copy", not it.has("tq_seed_id") and not it.has("tq_rng_n") and it.has("tianqi_affixes") and it.has("tq_reforges"), it)
	# 多种子：每个种子新档的懒建种子都按公式、读档不变
	var ok: Array = kit.each_seed(func(sd):
		var s := Kit.new_game("jianxian", "war", sd)
		var a := int(XTianqiDrop.store(s).seed)
		var q := str(XTianqiQiyin.progress(s).seed)
		var b := kit.roundtrip()
		return b != null and a == _drop_seed(s) and int(XTianqiDrop.store(b).seed) == a and str(XTianqiQiyin.progress(b).seed) == q)
	_check("each_seed_stable", ok.all(func(v): return v), ok)
	var seeds: Array = kit.each_seed(func(sd): return _drop_seed(Kit.new_game("jianxian", "war", sd)))
	_check("each_seed_differs", seeds[0] != seeds[1] and seeds[1] != seeds[2], seeds)


func _run() -> void:
	seed(20261114)
	kit = Kit.new("xiyou_tianqi_save")
	_registry()
	_disk()
	_gojo()
	_gojo_in_trial()
	_review_fixes()
	_misc()
	XTianqiSave.ENABLED = true
	XTianqiGojoTrial.ENABLED = true
	kit.teardown()
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
