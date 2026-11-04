extends Node
## 插件备注覆盖扫尾（scan2），对照 oracle/scan2.json（mv_oracle/scan2_probe.cjs 量冻结正式源）：
## ① <Max Item: x>：物品 2933、2934 封顶 130，其余 9999
## ② dsPassiveSkill <SvPngFd: N>：战斗立绘放大倍数（装备→技能→状态，后者盖前者）
## ③ Olivia_BattleSysOTB <SkillKillGoon>：实测「击杀追击」在原版里从不发生（条件里 _subjectActorId 与 _subjectEnemyIndex !== -1 互斥），重制也不做；
##    这里守住原版事实，冻结源变了就会报失败。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ref = XDB.load_json("oracle/scan2.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	_max_item(cases.max_item.observed)
	_svpng(cases.svpng.observed)
	_killgoon(cases.killgoon.observed)
	_finish()


func _max_item(o: Dictionary) -> void:
	check("max_item.rows", o.rows.size() == 4, o.rows.size())
	for row in o.rows:
		var id := int(row.id)
		var s := XState.new_game(3, 1, [8])
		XState.current = s
		s.items.erase(id)
		check("max_item.%d.cap" % id, XState.item_max(id) == int(row.maxItems), [XState.item_max(id), row.maxItems])
		s.gain_item(id, 500)
		check("max_item.%d.after500" % id, s.item_count(id) == int(row.after500), [s.item_count(id), row.after500])
		s.gain_item(id, 500)
		check("max_item.%d.stay" % id, s.item_count(id) == int(row.after500) if int(row.maxItems) < 500 else s.item_count(id) == 1000, s.item_count(id))


func _svpng(o: Dictionary) -> void:
	var seen := 0
	for row in o.rows:
		var armor := int(row.armorId)
		if armor != 0 and armor != 5198 and armor != 5200:
			continue  # 其余防具在原版里这个职业／槽位戴不上（探针里没换成），不比
		seen += 1
		var s := XState.new_game(3, 1, [8])
		XState.current = s
		var a: XActor = s.members()[0]
		a.equips = []
		if armor != 0:
			a.equips.append(XActor.make_equip("armor", armor))
		a.state_ids = []
		if row.withState:
			a.state_ids.append(1120)
		var tag := "svpng.%d.%s" % [armor, row.withState]
		check(tag, is_equal_approx(a.sv_png_scale(), float(row.scale)), [a.sv_png_scale(), row.scale])
	check("svpng.rows_seen", seen == 6, seen)


func _killgoon(o: Dictionary) -> void:
	check("killgoon.flags", int(o.actionFlags.subjectActorId) > 0 and int(o.actionFlags.subjectEnemyIndex) == -1, o.actionFlags)
	for row in o.rows:
		var tag := "killgoon.%s.%s" % [row.tag, row.kill]
		check(tag + ".others_alive", int(row.enemies) >= 3, row.enemies)
		check(tag + ".no_chain", int(row.final.starts) == 1, row.final)
		check(tag + ".others_untouched", row.final.hpLostOthers.all(func(x): return int(x) == 0), row.final.hpLostOthers)
		check(tag + ".no_source_errors", row.sourceErrors.is_empty(), row.sourceErrors)


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
