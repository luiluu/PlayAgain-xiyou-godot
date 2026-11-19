extends Node
## 【cc·T249】天启篇：赤狐 97、金狐 98「双生花」强制追击去掉（对齐《天启篇_全角色技能重构 v0.2》双生花＝同场对方打过的目标 +20%，
## 跟 10732 狐火去 [44,2366] 同做法；不是新删内容）。
## 原版：97 放 7057 妖狐之爪 → 公共事件 2365 强制 98 放 7075（灵狐之箭副本）；98 放 7074 灵狐之箭 → 2366 强制 97 放 7063（妖狐之爪副本）。
## 两个副本没进技能卡，期四里照原版公式（3000／5000＋属性×75…）和魔法上限／生命门槛加段打。
## 一、天启篇存档：7057、7074 的记录没有 44 效果；两人同队实放 7057／7074，不预约 2365／2366、日志里没有 7075／7063。
## 二、西游档（对照）：记录照原版带 44；同样实放，会预约公共事件或打出追击（说明上面那条测得到东西）。
## 三、abs_rescale.json T249 三组：敌人技能底数 475 行整组 raw、门槛 7 行逐行定（card 4、card_off 2、raw 1）、custom_regen 25 行 raw。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _logic(tianqi: bool) -> XBattleLogic:
	var lineup := [97, 98]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a: XActor = s.actor(id)
		a.change_level(81)
		for sid in [7057, 7074]:
			a.learn_skill(sid)
		a.recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	for e in lg.enemies:
		e.add_param(0, 99999999)  # 敌人别被打死，追击才有目标
		e.recover_all()
	return lg


func _has_effect(rec: Dictionary, code: int, data_id: int) -> bool:
	for e in rec.get("effects", []):
		if int(e.get("code", -1)) == code and int(e.get("dataId", -1)) == data_id:
			return true
	return false


## 实放一次：返回 [预约的公共事件号, 日志里出现过的技能号]
func _cast(lg: XBattleLogic, user_id: int, skill_id: int) -> Array:
	var u: XActor = lg.state.actor(user_id)
	var t: XBattler = lg.enemies[0]
	var logs := lg.act(u, XDB.rec("Skills", skill_id), t)
	var ce := XBattleCommonEvent.reserved(lg)
	var seen := {}
	for r in logs:
		if r is Dictionary and r.get("skill") is Dictionary:
			seen[int(r.skill.get("id", 0))] = true
	return [ce, seen.keys()]


func _run() -> void:
	XMessageBox.auto = true
	seed(20261119)
	XTianqiBase.clear_cache()
	XTianqiBase.PHASE4 = true
	# 一、天启篇
	var lg := _logic(true)
	_check("tq.active", XTianqi.active(lg.state))
	_check("tq.7057_no_ce", not _has_effect(XDB.rec("Skills", 7057), 44, 2365))
	_check("tq.7074_no_ce", not _has_effect(XDB.rec("Skills", 7074), 44, 2366))
	_check("tq.7074_keeps_crit_state", _has_effect(XDB.rec("Skills", 7074), 21, 1596))  # 卡上「目标受暴击概率 +10%」照旧
	var r1 := _cast(lg, 97, 7057)
	_check("tq.7057_cast", r1[1].has(7057), r1)
	_check("tq.7057_no_followup", r1[0] != 2365 and not r1[1].has(7075), r1)
	var r2 := _cast(lg, 98, 7074)
	_check("tq.7074_cast", r2[1].has(7074), r2)
	_check("tq.7074_no_followup", r2[0] != 2366 and not r2[1].has(7063), r2)
	# 一补（T249 核查 P2-1）：去掉强制追击后双生花「同场 +20%」照旧生效：97 放 7057、98 放 7074 各 ×1.2，单人上场回 1.0，不受影响的技能不变
	var st: XState = lg.state
	var a97: XActor = st.actor(97)
	var a98: XActor = st.actor(98)
	var foe: XBattler = lg.enemies[0]
	var slots_save: Array = st.battle_slots.duplicate()
	var duo := [XTianqiSkills.formula(a97, foe, XDB.rec("Skills", 7057)), XTianqiSkills.formula(a98, foe, XDB.rec("Skills", 7074)), XTianqiSkills.formula(a97, foe, XDB.rec("Skills", 7056))]
	st.battle_slots = [97]
	var solo97 := [XTianqiSkills.formula(a97, foe, XDB.rec("Skills", 7057)), XTianqiSkills.formula(a97, foe, XDB.rec("Skills", 7056))]
	st.battle_slots = [98]
	var solo98 := XTianqiSkills.formula(a98, foe, XDB.rec("Skills", 7074))
	st.battle_slots = slots_save
	_check("twin.7057_plus20", solo97[0] > 0.0 and absf(duo[0] / solo97[0] - 1.2) < 0.01, [duo[0], solo97[0]])
	_check("twin.7074_plus20", solo98 > 0.0 and absf(duo[1] / solo98 - 1.2) < 0.01, [duo[1], solo98])
	_check("twin.7056_unchanged", solo97[1] > 0.0 and absf(duo[2] / solo97[1] - 1.0) < 0.01, [duo[2], solo97[1]])
	# 一补2（T255）：扫表补的 7 张卡（强制追击没进卡的）天启篇档记录里都没有对应的 44；西游档记录不变
	var t255 := {502: 105, 523: 911, 2192: 1085, 5727: 1224, 5782: 1223, 7059: 2368, 7072: 2367}
	for sid in t255:
		_check("t255.%d_no_ce" % sid, not _has_effect(XDB.rec("Skills", sid), 44, int(t255[sid])))
	# 二、西游档对照
	var og := _logic(false)
	_check("xy.not_active", not XTianqi.active(og.state))
	_check("xy.7057_has_ce", _has_effect(XDB.rec("Skills", 7057), 44, 2365))
	_check("xy.7074_has_ce", _has_effect(XDB.rec("Skills", 7074), 44, 2366))
	var x1 := _cast(og, 97, 7057)
	_check("xy.7057_followup", x1[0] == 2365 or x1[1].has(7075), x1)
	for sid in t255:
		_check("xy.t255_%d_has_ce" % sid, _has_effect(XDB.rec("Skills", sid), 44, int(t255[sid])))
	var x2 := _cast(og, 98, 7074)
	_check("xy.7074_followup", x2[0] == 2366 or x2[1].has(7063), x2)
	# 三、表
	var g: Dictionary = XTianqiBase.abs_data().get("groups", {})
	var eb: Dictionary = g.get("enemy_skill_fixed_base", {})
	_check("tbl.enemy_base_raw", str(eb.get("new", {}).get("mode", "")) == "raw" and eb.get("rows", []).size() == 475 and not eb.has("new_rule"), eb.get("new"))
	var modes := {}
	for r in g.get("abs_threshold_in_notes", {}).get("rows", []):
		modes[int(r.id)] = str(r.new.mode)
	_check("tbl.threshold", modes == {1232: "card", 7057: "card", 7063: "card_off", 7074: "card", 7075: "card_off", 9954: "card", 10474: "raw"}, modes)
	var cr: Dictionary = g.get("custom_regen", {})
	_check("tbl.regen", str(cr.get("new", {}).get("mode", "")) == "raw" and cr.get("rows", []).size() == 25, cr.get("rows", []).size())
	_check("tbl.unscanned", not str(XTianqiBase.abs_data().get("unscanned", [])).contains("Custom Regenerate"))
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
