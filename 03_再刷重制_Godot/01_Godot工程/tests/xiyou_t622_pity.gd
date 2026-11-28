extends Node
## T622（D302 Kyo 11-28 事项 111）西游档「元素之王的赐福」扩掉落范围＋888 只保底；魔冠「"头顶"」7940 加 33 场保底。
## - coverage：九张「深渊:未知存在」图＋八张第二层深渊（XElementalKing.SECOND_LAYER）逐图逐敌群开一场、敌人全倒：都合格、合格只数＝在场敌人数；
##   低层深渊、单层深渊（174/175/184/211）、旧魔王之渊 107、普通楼层不合格。EXPAND=false 回到只认未知存在图的【未知存在】敌人。
## - bless：计数（胜利发奖时按只累加）、满 888 必出并重算、自然掉也重算、rewards() 再调与 grant 再调不重计、存档读档不丢计数、旧档从 0 起、
##   SL（存 887 → 打出保底 → 读档）计数与赐福一起回到存档时、PITY=false 不计不保底、天启篇零改动。
## - crown：Map162 不朽未知战斗 33 场保底（账本本档 pity）、自然 3% 重算、输了／不合格战斗不计、账本重读计数还在、
##   SL（保底发出后读旧档）头顶不多拿、同一遭遇序号重打不重计、保底那件存仓库存读还在（T616 WAREHOUSE_KEEP）、PITY=false、启封档不计。
const Kit := preload("res://tests/lib/tq_save_kit.gd")

## 逐图敌群（按地图事件的战斗处理＋调用的公共事件扫出；Map 文件 modes/xiyou/generated/maps）
const MAP_TROOPS := {
	141: [413, 414, 415, 416, 577, 578, 579, 580, 581, 582, 661, 767],
	152: [454, 455, 661, 767],
	160: [470, 471, 472, 473, 474, 661, 767],
	161: [544, 545, 546, 547, 548, 661, 767],
	162: [539, 540, 541, 542, 661, 767],
	176: [570, 571, 572, 573, 574, 575, 661, 767],
	177: [584, 585, 586, 587, 588, 589, 661, 767],
	210: [661, 724, 725, 726, 727, 728, 729, 767],
	223: [647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659, 661, 767],
	38: [150, 151, 152, 153],
	51: [207, 208, 209],
	53: [213, 214, 215],
	57: [227, 228, 229, 230],
	59: [235, 236, 237, 238, 371],
	113: [383, 384, 385, 386, 402, 404, 413, 414, 415, 416, 418],
	165: [348, 349, 350, 351],
	168: [383, 384, 385, 386, 402, 404, 413, 414, 415, 416, 418],
}
const EXCLUDED := {37: 145, 50: 204, 52: 210, 56: 223, 58: 231, 110: 379, 164: 344, 167: 379, 174: 551, 175: 559, 184: 640, 211: 717, 107: 344, 87: 145}

var results: Array = []
var kit: Kit
var s: XState
var mode := ""
var coverage_lines: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": mode + "." + name, "passed": ok})
	if not ok:
		print("FAIL ", mode, ".", name, " ", JSON.stringify(detail).left(1200))
	return ok


func _xiyou() -> XState:
	var st := XState.new_game(2, 1, [8, 9, 10])
	st.actor_max_level = 99
	XState.current = st
	return st


func _logic(st: XState, troop: int, seed_name: String) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, st, XBattleRandom.create(seed_name))
	for e in lg.enemies:
		if not e.hidden:
			e.hp = 0.0
	return lg


func _blessings(st: XState) -> int:
	var n := st.gear.filter(func(g): return XElementalKing.is_blessing(g)).size()
	for a in st.actors.values():
		for e in a.equips:
			if XElementalKing.is_blessing(e):
				n += 1
	return n


## 打赢一场：rewards → grant（battle_scene 的胜利结算顺序）；返回 rewards
func _win_bless(st: XState, troop: int, seed_name: String) -> Dictionary:
	var lg := _logic(st, troop, seed_name)
	var r := lg.rewards()
	lg.grant(r)
	return {"logic": lg, "r": r, "meta": lg.get_meta("elem_king_pity", {})}


## 找一个这场自然掉／不掉的种子（走完整 rewards()：没钉住时掉落与赐福共用奖励流，单调 battle_drops 的结果不一样）
func _seed_where(st: XState, troop: int, tag: String, want_hit: bool, tries := 200) -> String:
	var saved = st.flags.get(XElementalKing.PITY_FLAG)
	var found := ""
	for i in range(tries):
		st.flags[XElementalKing.PITY_FLAG] = 0
		var lg := _logic(st, troop, "%s_%d" % [tag, i])
		lg.rewards()
		if (int(lg.get_meta("elem_king_pity", {}).get("drops", 0)) > 0) == want_hit:
			found = "%s_%d" % [tag, i]
			break
	if saved == null:
		st.flags.erase(XElementalKing.PITY_FLAG)
	else:
		st.flags[XElementalKing.PITY_FLAG] = saved
	return found


func _miss_seed(st: XState, troop: int, tag: String) -> String:
	return _seed_where(st, troop, tag, false)


# ---- 赐福：范围 ----
func _coverage() -> void:
	mode = "coverage"
	var st := _xiyou()
	for mid in MAP_TROOPS:
		st.map_id = int(mid)
		_check("map_%d" % mid, XElementalKing.is_drop_map(mid), mid)
		var parts := []
		for troop in MAP_TROOPS[mid]:
			var lg := _logic(st, int(troop), "t622_cov_%d_%d" % [mid, troop])
			XElementalKing.battle_drops(lg)
			var m: Dictionary = lg.get_meta("elem_king_pity", {})
			var shown := lg.enemies.filter(func(e): return not e.hidden).size()
			_check("troop_%d_%d" % [mid, troop], shown > 0 and int(m.get("eligible", -1)) == shown, [m, shown])
			parts.append("%d(%d只)" % [troop, int(m.get("eligible", -1))])
		coverage_lines.append("%d %s：%s" % [mid, str(XDB.rec("MapInfos", mid).get("name", "")), " ".join(parts)])
	for mid in EXCLUDED:
		st.map_id = int(mid)
		var lg := _logic(st, int(EXCLUDED[mid]), "t622_ex_%d" % mid)
		_check("excluded_%d" % mid, not XElementalKing.is_drop_map(mid) and XElementalKing.battle_drops(lg).is_empty() and not lg.has_meta("elem_king_pity"), mid)
	_check("unknown_all_nine", XYunshangOrders.UNKNOWN.keys().all(func(k): return MAP_TROOPS.has(k)), XYunshangOrders.UNKNOWN.keys())
	# 回退：EXPAND=false
	XElementalKing.EXPAND = false
	st.map_id = 38
	_check("expand_off_second_layer", XElementalKing.battle_drops(_logic(st, 150, "t622_off1")).is_empty() and not XElementalKing.is_drop_map(38))
	st.map_id = 152
	var lg661 := _logic(st, 661, "t622_off2")
	XElementalKing.battle_drops(lg661)
	_check("expand_off_non_unknown_enemy", int(lg661.get_meta("elem_king_pity", {}).get("eligible", -1)) == 0, lg661.get_meta("elem_king_pity", {}))
	var lg454 := _logic(st, 454, "t622_off3")
	XElementalKing.battle_drops(lg454)
	_check("expand_off_unknown_enemy_kept", int(lg454.get_meta("elem_king_pity", {}).get("eligible", -1)) > 0, lg454.get_meta("elem_king_pity", {}))
	XElementalKing.EXPAND = true


# ---- 赐福：保底计数 ----
func _bless() -> void:
	mode = "bless"
	s = _xiyou()
	s.map_id = 38
	_check("old_state_zero", XElementalKing.pity_of(s) == 0 and not s.flags.has(XElementalKing.PITY_FLAG))
	var seed := _miss_seed(s, 150, "t622_miss")
	_check("miss_seed", seed != "", seed)
	# 计数：一场一只（150 一只）
	s.flags[XElementalKing.PITY_FLAG] = 100
	var w := _win_bless(s, 150, seed)
	var n := int(w.meta.get("eligible", 0))
	_check("count_add", n > 0 and XElementalKing.pity_of(s) == 100 + n and _blessings(s) == 0, [n, XElementalKing.pity_of(s)])
	# rewards() 再调、grant 再调不重计
	(w.logic as XBattleLogic).rewards()
	(w.logic as XBattleLogic).grant(w.r)
	XElementalKing.commit(w.logic, w.r)
	_check("no_double_count", XElementalKing.pity_of(s) == 100 + n, XElementalKing.pity_of(s))
	# 输了／没发奖：不计
	var lose := _logic(s, 150, seed)
	lose.rewards()
	_check("no_grant_no_count", XElementalKing.pity_of(s) == 100 + n, XElementalKing.pity_of(s))
	# 满 888 必出并重算
	s.flags[XElementalKing.PITY_FLAG] = XElementalKing.PITY_COUNT - 1
	var before := _blessings(s)
	w = _win_bless(s, 150, seed)
	_check("pity_hit", _blessings(s) == before + 1 and int(w.meta.get("pity_hits", 0)) == 1 and XElementalKing.pity_of(s) == 0, [_blessings(s), w.meta, XElementalKing.pity_of(s)])
	# 多只的敌群：第 888 只出、后面的接着从 0 数
	s.map_id = 165
	var seed141 := _miss_seed(s, 349, "t622_m165")
	s.flags[XElementalKing.PITY_FLAG] = XElementalKing.PITY_COUNT - 1
	w = _win_bless(s, 349, seed141)
	var n141 := int(w.meta.get("eligible", 0))
	_check("pity_mid_troop", n141 == 2 and int(w.meta.get("pity_hits", 0)) == 1 and XElementalKing.pity_of(s) == 1, [w.meta, XElementalKing.pity_of(s)])
	# 自然掉也重算：找 152/454 自然命中的种子
	s.map_id = 152
	var hit_seed := _seed_where(s, 454, "t622_hit", true, 20000)
	_check("natural_seed", hit_seed != "", hit_seed)
	if hit_seed != "":
		s.flags[XElementalKing.PITY_FLAG] = 500
		before = _blessings(s)
		w = _win_bless(s, 454, hit_seed)
		_check("natural_resets", _blessings(s) == before + 1 and int(w.meta.get("pity_hits", -1)) == 0 and XElementalKing.pity_of(s) == 0, [w.meta, XElementalKing.pity_of(s)])
	# 存档读档不丢计数
	s.map_id = 38
	s.flags[XElementalKing.PITY_FLAG] = 321
	var back := kit.roundtrip(1)
	_check("save_load_keeps", back != null and XElementalKing.pity_of(back) == 321, XElementalKing.pity_of(back) if back != null else null)
	# 旧档没有这个键：从 0 起
	kit.edit_raw(func(d): d.get("flags", {}).erase(XElementalKing.PITY_FLAG), 1)
	back = kit.reload(1)
	_check("legacy_zero", back != null and XElementalKing.pity_of(back) == 0, back.flags.get(XElementalKing.PITY_FLAG) if back != null else null)
	# SL：存 887 → 打出保底 → 读档：计数和赐福都回到存档时，不多拿
	s = back
	s.map_id = 38
	s.flags[XElementalKing.PITY_FLAG] = XElementalKing.PITY_COUNT - 1
	var saved_bless := _blessings(s)
	_check("sl_save", kit.save(2))
	w = _win_bless(s, 150, seed)
	_check("sl_pity_given", _blessings(s) == saved_bless + 1 and XElementalKing.pity_of(s) == 0, [_blessings(s), XElementalKing.pity_of(s)])
	back = kit.reload(2)
	_check("sl_reload_rolls_back", back != null and XElementalKing.pity_of(back) == XElementalKing.PITY_COUNT - 1 and _blessings(back) == saved_bless, [XElementalKing.pity_of(back), _blessings(back), saved_bless] if back != null else null)
	s = back
	s.map_id = 38
	w = _win_bless(s, 150, seed)
	_check("sl_again_one", _blessings(s) == saved_bless + 1 and XElementalKing.pity_of(s) == 0, [_blessings(s), XElementalKing.pity_of(s)])
	# PITY=false：不计、不保底
	XElementalKing.PITY = false
	s.flags[XElementalKing.PITY_FLAG] = XElementalKing.PITY_COUNT - 1
	before = _blessings(s)
	w = _win_bless(s, 150, seed)
	_check("pity_off", _blessings(s) == before and XElementalKing.pity_of(s) == XElementalKing.PITY_COUNT - 1, [_blessings(s), XElementalKing.pity_of(s)])
	XElementalKing.PITY = true
	# ENABLED=false：不掉也不计
	XElementalKing.ENABLED = false
	w = _win_bless(s, 150, seed)
	_check("disabled_no_count", XElementalKing.pity_of(s) == XElementalKing.PITY_COUNT - 1 and _blessings(s) == before, XElementalKing.pity_of(s))
	XElementalKing.ENABLED = true
	# 启封档零改动
	var tq := Kit.new_game()
	tq.map_id = 38
	tq.flags[XElementalKing.PITY_FLAG] = XElementalKing.PITY_COUNT - 1
	var lgt := _logic(tq, 150, seed)
	var rt := lgt.rewards()
	lgt.grant(rt)
	_check("tianqi_zero", XElementalKing.pity_of(tq) == XElementalKing.PITY_COUNT - 1 and not lgt.has_meta("elem_king_pity") and _blessings(tq) == 0, [XElementalKing.pity_of(tq), _blessings(tq)])
	XState.current = s


# ---- 头顶 ----
func _crown_state(tq: bool) -> void:
	for f in DirAccess.get_files_at(kit.dir):
		DirAccess.remove_absolute(kit.dir.path_join(f))
	XDemonCrown.forget_ledger()
	XDemonCrown.storage_error = ""
	XDemonCrown.battle = null
	XDemonCrown.healed = []
	XDemonCrown.WAREHOUSE_KEEP = true
	XDemonCrown.PITY = true
	s = Kit.new_game() if tq else _xiyou()
	XState.current = s
	XWarehouse.create(s, "<仓库:999>")


func _crowns() -> int:
	return XDemonCrown.owned(s).size() + XDemonCrown.stored(s).size()


func _fight(result: int, roll: float, map := 162, troop := 539, origin = 57) -> void:
	s.map_id = map
	if origin == null:
		s.flags.erase(XYunshangOrders.ORIGIN_FLAG)
	else:
		s.flags[XYunshangOrders.ORIGIN_FLAG] = origin
	XDemonCrown.begin(s, troop, func(): return roll)
	XDemonCrown.finish(s, result)


func _crown() -> void:
	mode = "crown"
	_crown_state(false)
	_check("count_33", XDemonCrown.PITY_COUNT == roundi(1.0 / XDemonCrown.DROP_RATE) and XDemonCrown.PITY_COUNT == 33)
	_check("fresh_zero", XDemonCrown.pity_of(s) == 0)
	for i in XDemonCrown.PITY_COUNT - 1:
		_fight(0, 0.9)
	_check("count_32", XDemonCrown.pity_of(s) == 32 and _crowns() == 0, [XDemonCrown.pity_of(s), _crowns()])
	# 输了、不合格（非不朽来源、别的图）不计
	_fight(1, 0.9)
	_fight(0, 0.9, 162, 539, 38)
	_fight(0, 0.9, 4, 3, null)
	_check("loss_and_ineligible_skip", XDemonCrown.pity_of(s) == 32 and _crowns() == 0, XDemonCrown.pity_of(s))
	# 账本重读：计数还在
	XDemonCrown.forget_ledger()
	_check("ledger_reload_keeps", XDemonCrown.pity_of(s) == 32, XDemonCrown.pity_of(s))
	# SL：存 32 → 第 33 场保底 → 读旧档：头顶不多拿、计数不回退
	_check("sl_save", kit.save(1))
	_fight(0, 0.9)
	_check("pity_33", _crowns() == 1 and XDemonCrown.pity_of(s) == 0, [_crowns(), XDemonCrown.pity_of(s)])
	s = kit.reload(1)
	_check("sl_reload", s != null and _crowns() == 1 and XDemonCrown.pity_of(s) == 0, [_crowns(), XDemonCrown.pity_of(s)] if s != null else null)
	_fight(0, 0.9)  # 同一遭遇序号重打：已结算，不重计
	_check("sl_replay_no_count", _crowns() == 1 and XDemonCrown.pity_of(s) == 0, [_crowns(), XDemonCrown.pity_of(s)])
	_fight(0, 0.9)
	_check("sl_next_counts", _crowns() == 1 and XDemonCrown.pity_of(s) == 1, [_crowns(), XDemonCrown.pity_of(s)])
	# 自然 3% 也重算
	for i in 9:
		_fight(0, 0.9)
	_check("count_10", XDemonCrown.pity_of(s) == 10, XDemonCrown.pity_of(s))
	_fight(0, 0.01)
	_check("natural_resets", _crowns() == 2 and XDemonCrown.pity_of(s) == 0, [_crowns(), XDemonCrown.pity_of(s)])
	# 保底那件存仓库、存读还在（T616）
	var it: Dictionary = XDemonCrown.owned(s).back()
	_check("deposit", XWarehouse.deposit(s, "armor", it))
	_check("deposit_save", kit.save(1))
	s = kit.reload(1)
	_check("deposit_kept", s != null and _crowns() == 2 and XDemonCrown.stored(s).size() == 1, [_crowns(), XDemonCrown.stored(s).size()] if s != null else null)
	# PITY=false：不计、不保底
	XDemonCrown.PITY = false
	var c0 := XDemonCrown.pity_of(s)
	for i in 40:
		_fight(0, 0.9)
	_check("pity_off", _crowns() == 2 and XDemonCrown.pity_of(s) == c0, [_crowns(), XDemonCrown.pity_of(s)])
	XDemonCrown.PITY = true
	# 启封档：不计
	mode = "crown_qifeng"
	_crown_state(true)
	for i in 40:
		_fight(0, 0.9)
	_check("tianqi_no_pity", XDemonCrown.pity_of(s) == 0 and _crowns() == 0, [XDemonCrown.pity_of(s), _crowns()])
	_check("mode", XTianqi.active(s))


func _run() -> void:
	XTianqi.JOIN_GIFTS = false
	kit = Kit.new("xiyou_t622_pity")
	XDemonCrown.path_override = ProjectSettings.globalize_path(kit.dir).path_join("crown_progress_test.json")
	print("XTestMode unlocked=%s enabled=%s" % [XTestMode.unlocked(), XTestMode.enabled()])  # 本机开着测试模式时这里是 true，结果作废
	mode = "env"
	_check("test_mode_off", not XTestMode.unlocked() and not XTestMode.enabled())
	_coverage()
	_bless()
	_crown()
	for line in coverage_lines:
		print("COVER ", line)
	XDemonCrown.path_override = ""
	XDemonCrown.forget_ledger()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
