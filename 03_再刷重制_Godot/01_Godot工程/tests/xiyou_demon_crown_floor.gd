extends Node
## 【cc·T548·未经审查】天启篇魔冠头顶（7940）成长只算最高层往下 3 层内的战斗（Kyo 11-26 事项 79「最高层往下3层内。改到启封档」）。
## - 纯数据：crown_floor_ok_facts 窗口 3（主塔／野外、深渊封顶 29、王者副本、七印里副本、终局战口径同 floor_ok_facts）；三人的 5 不变。
## - 真天启篇档：高层胜利涨、低层胜利不涨不减（这一场照常结算、遭遇序号＋1、重打不重掷）；低层倒下照旧减半。
## - 回退开关 CROWN_FLOOR 两态；表里 crown_window 改了跟着变；说明卡天启篇有提示行、西游档没有。
## - 西游档：低层照涨，说明行与改前逐字一样（隔离）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const G := preload("res://modes/xiyou/core/tianqi_growth.gd")
var results: Array = []
var kit: Kit
var s: XState
var wearer: XActor


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))


func _map_of_floor(f: int) -> int:
	for i in range(1, 1000):
		var info := XDB.rec("MapInfos", i)
		if info.is_empty() or str(info.get("name", "")).begins_with("深渊"):
			continue
		if XDungeon.map_floor(i) == f:
			return i
	return 0


func _wear(st: XState, a: XActor) -> void:
	a._lv = maxi(a._lv, 60)  # 头顶有等级要求
	st.gain_gear("armor", XDemonCrown.ARMOR, 1)
	var it: Dictionary = st.gear.filter(XDemonCrown.is_gear).back()
	var slot := a.equip_slots().find(17)
	if not XEquipment.change(st, a, slot, it):
		a.equips[slot] = it
		st.gear.erase(it)
	a.refresh_passive()


func _bonus(st: XState, a: XActor) -> float:
	return XDemonCrown.bonus(XDemonCrown.gear(a))


func _fight(st: XState, map_id: int, result := 0, during = null) -> void:
	st.map_id = map_id
	XDemonCrown.begin(st, 3, func(): return 0.5)
	if during != null:
		(during as Callable).call()
	XDemonCrown.finish(st, result)


func _die_once(a: XActor) -> void:
	a.add_state(1)
	a.remove_state(1)
	a.hp = 1.0


func _rows(st: XState) -> Dictionary:
	var p = XDemonCrown.record(st)
	return p.battles if p != null else {}


## 说明原文去掉空行（describe 每重写一次都多留空行，是改前就有的，不算差别）
func _note(st: XState, a: XActor) -> String:
	return "\n".join(str(XDemonCrown.gear(a).get("note", "")).split("\n", false))


func _facts() -> void:
	G.reload_table()
	var F := G.crown_floor_ok_facts
	_check("cw_window_3", G.crown_window() == 3)
	_check("cw_33_30", F.call({"progress": 33, "map_floor": 30}))
	_check("cw_33_33", F.call({"progress": 33, "map_floor": 33}))
	_check("cw_33_29_no", not F.call({"progress": 33, "map_floor": 29}))
	_check("cw_10_7", F.call({"progress": 10, "map_floor": 7}))
	_check("cw_10_6_no", not F.call({"progress": 10, "map_floor": 6}))
	_check("cw_2_0", F.call({"progress": 2, "map_floor": 0}))  # 开局（已通 2 层）大厅层号 0 也算：0 ≥ −1
	_check("cw_abyss_26", F.call({"progress": 33, "map_floor": 26, "abyss": true}))  # min(33,29)−3＝26
	_check("cw_abyss_25_no", not F.call({"progress": 33, "map_floor": 25, "abyss": true}))
	_check("cw_abyss_0_no", not F.call({"progress": 2, "map_floor": 0, "abyss": true}))
	_check("cw_king", F.call({"progress": 33, "map_floor": 1, "king": true}))
	_check("cw_qiyin", F.call({"progress": 33, "map_floor": 0, "qiyin": true}))
	_check("cw_finale", F.call({"progress": 33, "map_floor": 0, "finale": true}))
	# 三人的窗口 5 不动
	_check("three_window_5", G.floor_ok_facts({"progress": 33, "map_floor": 28}) and not G.floor_ok_facts({"progress": 33, "map_floor": 27}))
	_check("three_abyss_24", G.floor_ok_facts({"progress": 33, "map_floor": 24, "abyss": true}))
	# 三人总开关关掉不影响头顶，头顶开关关掉不影响三人
	G.ENABLED = false
	_check("crown_ignores_growth_switch", not F.call({"progress": 33, "map_floor": 29}))
	G.ENABLED = true
	G.CROWN_FLOOR = false
	_check("crown_switch_off_facts", F.call({"progress": 33, "map_floor": 1}))
	_check("three_ignore_crown_switch", not G.floor_ok_facts({"progress": 33, "map_floor": 27}))
	G.CROWN_FLOOR = true
	# 表里改窗口跟着变
	var fr: Dictionary = G.data().floor_rule
	fr.crown_window = 1
	_check("cw_table_1", F.call({"progress": 33, "map_floor": 32}) and not F.call({"progress": 33, "map_floor": 31}))
	fr.crown_window = 3


func _tianqi() -> void:
	s = Kit.new_game()
	s.set_variable(20, 34)  # 已通主塔 33 层
	var hi := _map_of_floor(31)
	var edge := _map_of_floor(30)
	var lo := _map_of_floor(29)
	var low := _map_of_floor(1)
	_check("tq_maps", hi > 0 and edge > 0 and lo > 0 and low > 0, [hi, edge, lo, low])
	wearer = s.battle_members()[0]
	_wear(s, wearer)
	_check("tq_wear", not XDemonCrown.gear(wearer).is_empty())
	s.map_id = low
	_check("tq_real_low_no", not G.crown_floor_ok(s))
	s.map_id = edge
	_check("tq_real_edge_ok", G.crown_floor_ok(s))
	# 高层赢：涨
	_fight(s, hi)
	var b1 := _bonus(s, wearer)
	_check("tq_hi_grows", b1 > 0.99, b1)
	_fight(s, edge)
	var b2 := _bonus(s, wearer)
	_check("tq_edge_grows", b2 > b1, [b1, b2])
	# 低层赢：不涨、不减，这一场照常结算、序号＋1
	var seq := int(s.flags.get(XDemonCrown.SEQ_FLAG, 0))
	_fight(s, lo)
	_check("tq_lo_no_grow", _bonus(s, wearer) == b2, [b2, _bonus(s, wearer)])
	_check("tq_lo_seq", int(s.flags.get(XDemonCrown.SEQ_FLAG, 0)) == seq + 1)
	_check("tq_lo_settled", not _rows(s).has("b:%d" % seq) or bool(_rows(s)["b:%d" % seq].get("settled", false)), _rows(s))
	_fight(s, low)
	_check("tq_low_no_grow", _bonus(s, wearer) == b2)
	# 低层倒下：照旧减半
	_fight(s, low, 0, func(): _die_once(wearer))
	var b3 := _bonus(s, wearer)
	_check("tq_low_death_halves", is_equal_approx(b3, b2 * 0.5), [b2, b3])
	# 低层输：不涨（本来就不涨）
	_fight(s, low, 1)
	_check("tq_low_lose", _bonus(s, wearer) == b3)
	# 说明卡：天启篇有提示行，显示在成长行下面（同位置后插的在前，所以提示行写在前）
	var note := _note(s, wearer)
	var hint_at := note.find("text=" + XDemonCrown.HINT_MARK)
	var grow_at := note.find("text=成长：八项全属性")
	_check("tq_hint_note", hint_at >= 0 and grow_at > hint_at and note.count("text=" + XDemonCrown.HINT_MARK) == 1 and note.contains("往下 3 层"), note)
	var card := "\n".join(XHelpCard.content(XDemonCrown.gear(wearer), "armor", false, 400.0).map(func(r): return str(r[0])))
	var c_grow := card.find("成长：八项全属性")
	var c_hint := card.find("往下 3 层")
	_check("tq_hint_card_below_growth", c_grow >= 0 and c_hint > c_grow, card)
	print("CARD_TEXT=", JSON.stringify(card))
	XDemonCrown.describe(XDemonCrown.gear(wearer))
	_check("tq_hint_once_after_redescribe", _note(s, wearer).count("text=" + XDemonCrown.HINT_MARK) == 1)
	# 回退开关关掉：低层照涨，提示行去掉
	G.CROWN_FLOOR = false
	_fight(s, low)
	_check("tq_off_low_grows", _bonus(s, wearer) > b3, [b3, _bonus(s, wearer)])
	XDemonCrown.describe(XDemonCrown.gear(wearer))
	_check("tq_off_no_hint", not _note(s, wearer).contains("text=" + XDemonCrown.HINT_MARK))
	G.CROWN_FLOOR = true
	XDemonCrown.describe(XDemonCrown.gear(wearer))
	# 读档后照判：存读一次，低层仍不涨
	s = kit.roundtrip()
	wearer = s.actor(int(wearer.actor_id))
	var b4 := _bonus(s, wearer)
	_fight(s, low)
	_check("tq_reload_low_no_grow", s != null and _bonus(s, wearer) == b4, b4)
	_fight(s, hi)
	_check("tq_reload_hi_grows", _bonus(s, wearer) > b4)


func _xiyou() -> void:
	var x := XState.new_game(2, 1, [8, 9, 10])
	XState.current = x
	x.battle_slots = [1, 8, 9, 10]
	x.set_variable(20, 34)
	_check("xy_not_tianqi", not XTianqi.active(x))
	var a: XActor = x.actor(1)
	_wear(x, a)
	var note_on := _note(x, a)
	G.CROWN_FLOOR = false
	XDemonCrown.describe(XDemonCrown.gear(a))
	var note_off := _note(x, a)
	G.CROWN_FLOOR = true
	XDemonCrown.describe(XDemonCrown.gear(a))
	_check("xy_note_same", note_on == note_off and note_on == _note(x, a) and not note_on.contains("text=" + XDemonCrown.HINT_MARK), [note_on, note_off])
	_check("xy_hint_empty", G.crown_hint(x) == "" and G.crown_floor_ok(x))
	var low := _map_of_floor(1)
	var b0 := _bonus(x, a)
	_fight(x, low)
	_check("xy_low_grows", _bonus(x, a) > b0, [b0, _bonus(x, a)])
	_fight(x, 4)
	_check("xy_grows_again", _bonus(x, a) > b0 + 1.5)


func _run() -> void:
	XTianqi.JOIN_GIFTS = false
	kit = Kit.new("xiyou_demon_crown_floor")
	XDemonCrown.path_override = ProjectSettings.globalize_path(kit.dir).path_join("crown_progress_test.json")
	DirAccess.remove_absolute(XDemonCrown.path_override)
	XDemonCrown.forget_ledger()
	XDemonCrown.storage_error = ""
	_facts()
	_tianqi()
	XDemonCrown.forget_ledger()
	XDemonCrown.storage_error = ""
	_xiyou()
	XDemonCrown.path_override = ""
	XDemonCrown.forget_ledger()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
