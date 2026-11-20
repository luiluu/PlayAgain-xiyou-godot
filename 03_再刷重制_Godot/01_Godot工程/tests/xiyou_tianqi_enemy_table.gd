extends Node
## 天启篇敌人六维补录（T303）专项：six_dim.json 的 enemies 段覆盖 13～27 层遇敌、13～33 层守层者、七印里副本；每行都读得出、跟档位一致。
## 一、覆盖：13～27 层各图遇敌敌群里的每只敌人、守层者敌群（XGuardianRework.TROOPS 13～33）里的每只、七印各印的敌群与首领都在表里。
## 二、读取：of_enemy 的六维等于「模板合并覆盖」；战商档（ai_tier）、韧性抗性读得出；野兽模板战商 E＝1 档。
## 三、档位（class）与前缀标签对应：稀有以上都单独覆盖六维、守层者 20～33 为 super。
## 四、没录的（1 层嘤嘤怪）仍回中性、tier 走原版。
var results: Array = []

const LADDER_MAPS := [29, 64, 30, 32, 33, 45, 46, 47, 116, 117, 119, 118, 120, 147, 155, 182]


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _troop_enemies(troop: int) -> Array:
	var out := []
	for m in XDB.rec("Troops", troop).get("members", []):
		out.append(int(m.enemyId))
	return out


func _run() -> void:
	XMessageBox.auto = true
	XTianqiSixDim.ENABLED = true
	var lineup := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
	var st := XTianqi.start_new_game(3, "jianxian", lineup)  # 立天启篇存档，六维表才生效
	XTianqi.take_pending()
	st.map_id = 4
	XState.current = st
	_check("天启篇存档下六维表生效", XTianqiSixDim.active())
	var d := XTianqiSixDim.data()
	var rows: Dictionary = d.get("enemies", {})
	var tpl: Dictionary = d.get("templates", {})
	# 一、覆盖
	var need := {}
	for m in LADDER_MAPS:
		var map = XDB.load_json("maps/Map%03d.json" % m)
		for enc in map.get("encounterList", []):
			for e in _troop_enemies(int(enc.troopId)):
				need[e] = "遇敌 Map%d" % m
	for f in range(13, 34):
		for e in _troop_enemies(int(XGuardianRework.TROOPS[f])):
			need[e] = "守层者 %d 层" % f
	var altar = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/tianqi_data/qiyin_altar.json"))
	for k in altar.seals:
		var s: Dictionary = altar.seals[k]
		need[int(s.boss.enemy)] = "里副本 %s 首领" % k
		for t in s.troops:
			for e in _troop_enemies(int(t)):
				need[e] = "里副本 %s" % k
	var miss := []
	for e in need:
		if not rows.has(str(e)):
			miss.append("%d(%s)" % [e, need[e]])
	_check("覆盖：13～33 层遇敌与守层者、七印里副本每只都录了（共 %d 只）" % need.size(), miss.is_empty(), miss)
	# 二、读取与一致
	var bad := []
	for k in rows:
		var r: Dictionary = rows[k]
		var t = tpl.get(str(r.get("template", "")))
		if not t is Dictionary:
			bad.append("%s 模板不存在" % k)
			continue
		var want := {}
		for dim in XTianqiSixDim.DIMS:
			want[dim] = str(r.get(dim, t.get(dim, "C")))
		var got := XTianqiSixDim.of_enemy(int(k))
		if got != want:
			bad.append("%s %s≠%s" % [k, got, want])
		var tier := XTianqiSixDim.ai_tier_of(got)
		if tier != int(d.ai_tier[want.wit]):
			bad.append("%s 战商档不对" % k)
		if XDB.rec("Enemies", int(k)).is_empty():
			bad.append("%s 敌人不存在" % k)
	_check("读取：of_enemy＝模板合并覆盖、战商档对、敌人存在", bad.is_empty(), bad)
	# 三、档位与标签
	var cls_bad := []
	for k in rows:
		var name := str(XDB.rec("Enemies", int(k)).get("name", ""))
		var r: Dictionary = rows[k]
		var cls := str(r.get("class", tpl[r.template].get("class", "minion")))
		if name.begins_with("【稀有】") or name.begins_with("【前所未见】") or name.begins_with("【亘古未有】") or name.begins_with("【守层者】"):
			if cls == "minion" or cls == "weak":
				cls_bad.append("%s %s class=%s 太低" % [k, name, cls])
			if not (r.has("output") or r.template == "abyss"):
				cls_bad.append("%s %s 没有单独覆盖六维" % [k, name])
	_check("档位：稀有以上／守层者不是 minion／weak 且单独覆盖", cls_bad.is_empty(), cls_bad)
	var guard_bad := []
	for f in range(20, 34):
		for e in _troop_enemies(int(XGuardianRework.TROOPS[f])):
			if str(rows.get(str(e), {}).get("class", "")) != "super":
				guard_bad.append("%d 层 %d" % [f, e])
	_check("守层者 20～33 层都是 super", guard_bad.is_empty(), guard_bad)
	var beast = XTianqiSixDim.of_enemy(107)
	_check("铠甲训狼（野兽模板）战商 E＝1 档", XTianqiSixDim.letter(beast, "wit") == "E" and XTianqiSixDim.ai_tier_of(beast) == 1, beast)
	# 四、没录的
	_check("没录的（嘤嘤怪 1）回中性", XTianqiSixDim.of_enemy(1) == XTianqiSixDim.neutral() and not rows.has("1"))
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
