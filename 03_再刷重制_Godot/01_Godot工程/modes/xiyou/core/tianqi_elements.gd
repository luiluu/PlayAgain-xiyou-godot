class_name XTianqiElements
extends RefCounted
## 【cc·天启篇·未经审查】天启篇元素系统重做（设计仓库《天启篇_元素系统重做方案_v0.7》）。
## 只对天启篇存档（XTianqi.active）生效，发行构建另要 XTianqi.RELEASE_OPEN；原版西游档、还原对照探针均保持原样。
## 数据：modes/xiyou/tianqi_data/elements_table.json。
##
## 开关：
## - ENABLED（O-437）：整套元素重做总开关
## - DECK（O-433）：60/60/20 楼层牌组、固定入口发牌、异化怪仅承免、物理转无属性、移除旧克制网与原版吸/免/抗
## - WEAK_EXPOSURE（O-434）：弱点暴露 +11%（同破绽取 max，不叠加）
## - HIGHER_EFFECTS（O-435）：高阶属性（11 虚空吞没 / 12 混沌随机 / 13 空间空蚀 15% 真伤）
## - SKILL_SHIFTS（O-436）：技能/被动转属（水/风/虚空/混沌）、转换书（1039 改名、3101~3105、互斥与仅炼狱/证道掉落）
## - PHYSICAL_DUAL_KEEP_NEUTRAL：待确认项 B（true＝8 个自然物攻保留 [0, 水/风] 双属性；false＝默认单水/单风）

static var ENABLED := true
static var DECK := true
static var WEAK_EXPOSURE := true
static var HIGHER_EFFECTS := true
static var SKILL_SHIFTS := true
static var PHYSICAL_DUAL_KEEP_NEUTRAL := false

const PATH := "res://modes/xiyou/tianqi_data/elements_table.json"
const BASE_ELEMENTS := [2, 3, 4, 5, 6, 7, 8, 9, 14, 15]
const HIGHER_ELEMENTS := [11, 12, 13]
const CONVERSION_SKILLS := [5068, 5069, 5070, 5071, 5072, 5073, 5074, 5075, 11201, 11202, 11203, 11204, 11205]
const PAWNSHOP_MAP := 204
const TEMPLATE_ITEM := 1035
const TEMPLATE_SKILL := 5068
const TEMPLATE_CE := 641
const OLD_CE_SKILL := 5072

const META_BATTLE := "_tianqi_elements"

static var _data: Dictionary = {}
static var _load_failed := false
static var _recs: Dictionary = {}
static var _synthetic: Dictionary = {}
static var _knight_clamp_warned := false
static var _silence_knight_clamp_error := false
static var _last_knight_clamp_error := ""


# ---- 数据与开关 ----

static func data() -> Dictionary:
	if _data.is_empty():
		if _load_failed or XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiElements: 读不到或解析失败 " + PATH)
			return {}
		_data = parsed
	return _data


static func reload() -> void:
	_data = {}
	_load_failed = false
	_recs = {}
	_synthetic = {}
	_knight_clamp_warned = false
	_last_knight_clamp_error = ""


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) and not data().is_empty()


static func deck_on(s = null) -> bool:
	return DECK and on(s)


static func exposure_on(s = null) -> bool:
	return WEAK_EXPOSURE and on(s)


static func higher_on(s = null) -> bool:
	return HIGHER_EFFECTS and on(s)


static func shifts_on(s = null) -> bool:
	return SKILL_SHIFTS and on(s)


static func element_name(e: int) -> String:
	var names: Dictionary = data().get("element_names", {})
	if names.has(str(e)):
		return str(names[str(e)])
	var sys_el: Array = XDB.system().get("elements", [])
	if e > 0 and e < sys_el.size() and str(sys_el[e]) != "":
		return str(sys_el[e])
	return "无属性" if e <= 1 else "元素%d" % e


# ---- 存档牌组（1~33 层 60/60/20 + 固定入口） ----

static func store(s: XState) -> Dictionary:
	if s == null or not XTianqi.active(s):
		return {}
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("elements") is Dictionary:
		tq["elements"] = {
			"seed": derived_seed(s),
			"floors": {},
			"fixed": {},
			"dropped_books": {},
			"book_fails": {},
		}
	return tq.elements


## 首次建牌组的种子：由存档自带的宝珠种子（orb_seed，新游戏随机、随存档保存，旧档读档时按存档内容算出）
## 加难度派生，不吃全局 randi 和战斗随机流。旧天启篇档（没有 elements 字段）不存档重读，牌组不变（gpt 核查 P2-1）
static func derived_seed(s: XState) -> int:
	if s == null:
		return 1
	var diff := str(s.flags.get("tianqi", {}).get("difficulty", "")) if s.flags.get("tianqi") is Dictionary else ""
	return XOrbs.hash32(JSON.stringify(["tianqi_elements", int(s.orb_seed), diff])) & 0x7fffffff


static func ensure_deck(s: XState, rng_seed := -1) -> Dictionary:
	var st := store(s)
	if st.is_empty():
		return {}
	if rng_seed >= 0:
		st["seed"] = rng_seed
		st["floors"] = {}
	if st.floors.size() == 33:
		for k in st.floors:
			_norm_entry(st.floors[k])
		return st.floors
	st.floors = _generate_floor_deck(int(st.get("seed", 1)))
	return st.floors


## 读档后 JSON 数字是浮点：牌组条目的弱／抗／免列表归一成整数（层牌组与固定入口共用）
static func _norm_entry(r) -> void:
	if not (r is Dictionary):
		return
	for fld in ["weak", "resist", "immune"]:
		var arr = r.get(fld)
		if arr is Array and arr.any(func(x): return not (x is int)):
			r[fld] = arr.map(func(x): return int(x))


static func floor_deck(s: XState, floor_no: int) -> Dictionary:
	if not deck_on(s) or floor_no < 1 or floor_no > 33:
		return {"weak": [], "resist": [], "immune": []}
	var floors := ensure_deck(s)
	var row = floors.get(str(floor_no), {})
	return row if row is Dictionary else {"weak": [], "resist": [], "immune": []}


static func _generate_floor_deck(seed_val: int) -> Dictionary:
	var rules: Dictionary = data().get("deck_rules", {})
	var constits: Dictionary = data().get("guardian_constitutions", {})
	var per_w := int(rules.get("per_element_weak", 6))
	var per_r := int(rules.get("per_element_resist", 6))
	var per_i := int(rules.get("per_element_immune", 2))
	var single_count := int(rules.get("single_floors", 6))
	var imm_min := int(rules.get("immune_min_floor", 6))
	var rng := RandomNumberGenerator.new()
	for attempt in range(400):
		rng.seed = int(seed_val) + attempt * 9973
		var out := _try_generate_floors(rng, constits, per_w, per_r, per_i, single_count, imm_min)
		if validate_floor_deck(out):
			return out
	# 确定性兜底（固定种子保证有解）
	rng.seed = 20261114
	for attempt in range(200):
		rng.seed = 20261114 + attempt * 7919
		var fallback := _try_generate_floors(rng, constits, per_w, per_r, per_i, single_count, imm_min)
		if validate_floor_deck(fallback):
			return fallback
	return {}


static func _try_generate_floors(rng: RandomNumberGenerator, constits: Dictionary, per_w: int, per_r: int, per_i: int, single_count: int, imm_min: int) -> Dictionary:
	var floor_ids := []
	for f in range(1, 34):
		floor_ids.append(f)
	_shuffle_rng(floor_ids, rng)
	var sizes := {}
	for i in range(floor_ids.size()):
		sizes[int(floor_ids[i])] = 1 if i < single_count else 2
	# 先按约束严到松（体质禁用多的层优先）分配弱点，再分配抗性，最后在 6~33 层分配免疫
	var sorted_weak := floor_ids.duplicate()
	sorted_weak.sort_custom(func(a, b):
		var ca: int = (constits.get(str(a), []) as Array).size()
		var cb: int = (constits.get(str(b), []) as Array).size()
		if ca != cb:
			return ca > cb
		return sizes[a] > sizes[b]
	)
	var floors := {}
	for f in range(1, 34):
		floors[str(f)] = {"weak": [], "resist": [], "immune": []}
	var rem_w := {}
	var rem_r := {}
	for e in BASE_ELEMENTS:
		rem_w[e] = per_w
		rem_r[e] = per_r
	# 1) 弱点
	for f in sorted_weak:
		var ban := (constits.get(str(f), []) as Array).map(func(x): return int(x))
		var need := int(sizes[f])
		for _k in range(need):
			var cands: Array = []
			for e in BASE_ELEMENTS:
				if int(rem_w[e]) > 0 and not ban.has(int(e)) and not (floors[str(f)].weak as Array).has(e):
					cands.append(e)
			if cands.is_empty():
				return {}
			cands.sort_custom(func(x, y): return int(rem_w[x]) > int(rem_w[y]))
			var top := int(rem_w[cands[0]])
			var pool := cands.filter(func(x): return int(rem_w[x]) >= top - 1)
			var pick := int(pool[rng.randi_range(0, pool.size() - 1)])
			floors[str(f)].weak.append(pick)
			rem_w[pick] = int(rem_w[pick]) - 1
	# 2) 抗性（同层不与弱点冲突）
	var sorted_res := floor_ids.duplicate()
	_shuffle_rng(sorted_res, rng)
	for f in sorted_res:
		var need := int(sizes[f])
		var w: Array = floors[str(f)].weak
		for _k in range(need):
			var cands := []
			for e in BASE_ELEMENTS:
				if int(rem_r[e]) > 0 and not w.has(e) and not (floors[str(f)].resist as Array).has(e):
					cands.append(e)
			if cands.is_empty():
				return {}
			cands.sort_custom(func(x, y): return int(rem_r[x]) > int(rem_r[y]))
			var top := int(rem_r[cands[0]])
			var pool := cands.filter(func(x): return int(rem_r[x]) >= top - 1)
			var pick := int(pool[rng.randi_range(0, pool.size() - 1)])
			floors[str(f)].resist.append(pick)
			rem_r[pick] = int(rem_r[pick]) - 1
	# 3) 免疫（6~33 层随机选 20 层，不与同层弱点/抗性冲突；20 枚元素各 2）
	var imm_pool := []
	for e in BASE_ELEMENTS:
		for _j in range(per_i):
			imm_pool.append(e)
	_shuffle_rng(imm_pool, rng)
	var imm_floors := []
	for f in range(imm_min, 34):
		imm_floors.append(f)
	_shuffle_rng(imm_floors, rng)
	var chosen_floors := imm_floors.slice(0, imm_pool.size())
	# 用二部匹配/回溯给 20 层分配 20 个免疫元素
	if not _assign_immune(floors, chosen_floors, imm_pool, 0):
		return {}
	return floors


static func _assign_immune(floors: Dictionary, chosen: Array, pool: Array, idx: int) -> bool:
	if idx >= chosen.size():
		return true
	var f := int(chosen[idx])
	var entry: Dictionary = floors[str(f)]
	var w: Array = entry.weak
	var r: Array = entry.resist
	var tried := {}
	for i in range(idx, pool.size()):
		var e := int(pool[i])
		if tried.has(e):
			continue
		tried[e] = true
		if w.has(e) or r.has(e):
			continue
		pool[i] = pool[idx]
		pool[idx] = e
		entry.immune = [e]
		if _assign_immune(floors, chosen, pool, idx + 1):
			return true
		entry.immune = []
		pool[idx] = pool[i]
		pool[i] = e
	return false


static func validate_floor_deck(floors: Dictionary) -> bool:
	if floors.size() != 33:
		return false
	var constits: Dictionary = data().get("guardian_constitutions", {})
	var w_counts := {}
	var r_counts := {}
	var i_counts := {}
	for e in BASE_ELEMENTS:
		w_counts[e] = 0
		r_counts[e] = 0
		i_counts[e] = 0
	var double_n := 0
	var single_n := 0
	var total_imm := 0
	for f in range(1, 34):
		var row = floors.get(str(f))
		if not row is Dictionary:
			return false
		var w: Array = row.get("weak", [])
		var r: Array = row.get("resist", [])
		var im: Array = row.get("immune", [])
		if w.size() != r.size() or not (w.size() == 1 or w.size() == 2):
			return false
		if w.size() == 2:
			double_n += 1
		else:
			single_n += 1
		if f <= 5 and not im.is_empty():
			return false
		if im.size() > 1:
			return false
		var ban := (constits.get(str(f), []) as Array).map(func(x): return int(x))
		var seen := {}
		for e in w:
			var ei := int(e)
			if not BASE_ELEMENTS.has(ei) or ban.has(ei) or seen.has(ei):
				return false
			seen[ei] = true
			w_counts[ei] = int(w_counts[ei]) + 1
		for e in r:
			var ei := int(e)
			if not BASE_ELEMENTS.has(ei) or seen.has(ei):
				return false
			seen[ei] = true
			r_counts[ei] = int(r_counts[ei]) + 1
		for e in im:
			var ei := int(e)
			if not BASE_ELEMENTS.has(ei) or seen.has(ei):
				return false
			seen[ei] = true
			i_counts[ei] = int(i_counts[ei]) + 1
			total_imm += 1
	if double_n != 27 or single_n != 6 or total_imm != 20:
		return false
	for e in BASE_ELEMENTS:
		if int(w_counts[e]) != 6 or int(r_counts[e]) != 6 or int(i_counts[e]) != 2:
			return false
	return true


## 固定入口发牌：hongjun / yingzi / knight / dungeon_boss:<id>
static func fixed_deal(s: XState, key: String, phase := 1) -> Dictionary:
	if not deck_on(s):
		return {"weak": [], "resist": [], "immune": []}
	var st := store(s)
	var fixed: Dictionary = st.fixed
	for fk in fixed:
		_norm_entry(fixed[fk])  # 读档后的浮点归一（条目数个位数）
	if key == "knight":
		var base_key := "knight:%d" % clampi(phase, 1, 3)
		if _knight_needs_redeal(fixed):
			_deal_knight(s, st)
		return fixed.get(base_key, {"weak": [], "resist": [], "immune": []})
	if fixed.has(key):
		return fixed[key]
	var kind := "dungeon_boss" if key.begins_with("dungeon_boss") else key
	var spec: Dictionary = data().get("fixed_entries", {}).get(kind, {})
	if spec.is_empty():
		return {"weak": [], "resist": [], "immune": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s" % [int(st.get("seed", 1)), key]).hash()
	var ban := (spec.get("constitutions", []) as Array).map(func(x): return int(x))
	var dealt := _deal_single_entry(rng, int(spec.get("weak", 2)), int(spec.get("resist", 2)), int(spec.get("immune", 1)), ban)
	fixed[key] = dealt
	return dealt


## 读取并校验骑士三阶段牌组配置：基础十系下，单类上限为 5（超 5 无法保证相邻阶段不重复），
## 且单阶段总数上限为 10（超 10 无法做到同阶段互不重复）。超容时按上限夹紧并 push_error 一次，
## 确保发牌与 _knight_needs_redeal 使用同一夹紧口径，避免少发及读档反复重发。
static func _knight_spec() -> Dictionary:
	var spec: Dictionary = data().get("fixed_entries", {}).get("knight", {})
	var raw_nw := int(spec.get("weak", 2))
	var raw_nr := int(spec.get("resist", 2))
	var raw_ni := int(spec.get("immune", 1))
	var max_per_kind := BASE_ELEMENTS.size() / 2  # 10 / 2 = 5
	var nw := clampi(raw_nw, 0, max_per_kind)
	var nr := clampi(raw_nr, 0, max_per_kind)
	var ni := clampi(raw_ni, 0, max_per_kind)
	var cap := BASE_ELEMENTS.size()
	nw = mini(nw, cap)
	cap -= nw
	nr = mini(nr, cap)
	cap -= nr
	ni = mini(ni, cap)
	if (nw != raw_nw or nr != raw_nr or ni != raw_ni) and not _knight_clamp_warned:
		_knight_clamp_warned = true
		_last_knight_clamp_error = "XTianqiElements: knight 配置超容 (weak=%d, resist=%d, immune=%d)，已夹紧为 (%d, %d, %d)" % [raw_nw, raw_nr, raw_ni, nw, nr, ni]
		if not _silence_knight_clamp_error:
			push_error(_last_knight_clamp_error)
	return {"weak": nw, "resist": nr, "immune": ni}


static func _knight_needs_redeal(fixed: Dictionary) -> bool:
	var spec := _knight_spec()
	var nw := int(spec.weak)
	var nr := int(spec.resist)
	var ni := int(spec.immune)
	for p in range(1, 4):
		var k := "knight:%d" % p
		if not fixed.has(k) or not (fixed[k] is Dictionary):
			return true
		var row: Dictionary = fixed[k]
		if (row.get("weak", []) as Array).size() != nw:
			return true
		if (row.get("resist", []) as Array).size() != nr:
			return true
		if (row.get("immune", []) as Array).size() != ni:
			return true
	return false


static func _deal_knight(_s: XState, st: Dictionary) -> void:
	var spec := _knight_spec()
	var nw := int(spec.weak)
	var nr := int(spec.resist)
	var ni := int(spec.immune)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|knight" % int(st.get("seed", 1))).hash()
	# 配置已在 _knight_spec() 校验并夹紧（单类 <= 5，单阶段总数 <= 10），不进入超容退化分支；
	# 三阶段（P1/P2/P3）尽量各自在弱、抗、免三组内全不重复，且至少保证相邻阶段不重复。
	var used_w := []
	var used_r := []
	var used_i := []
	var prev_w := []
	var prev_r := []
	var prev_i := []
	for p in range(1, 4):
		var dealt := _deal_knight_phase(rng, nw, nr, ni, used_w, used_r, used_i, prev_w, prev_r, prev_i)
		prev_w = dealt.weak.duplicate()
		prev_r = dealt.resist.duplicate()
		prev_i = dealt.immune.duplicate()
		for e in dealt.weak:
			if not used_w.has(e):
				used_w.append(e)
		for e in dealt.resist:
			if not used_r.has(e):
				used_r.append(e)
		for e in dealt.immune:
			if not used_i.has(e):
				used_i.append(e)
		st.fixed["knight:%d" % p] = dealt


static func _pick_from_pool(rng: RandomNumberGenerator, count: int, exclude: Array, prefer_ban: Array, fallback_ban: Array) -> Array:
	var pool := BASE_ELEMENTS.duplicate()
	_shuffle_rng(pool, rng)
	var picked := []
	for ban in [prefer_ban, fallback_ban, []]:
		for e in pool:
			if picked.size() >= count:
				return picked
			var ei := int(e)
			if exclude.has(ei) or picked.has(ei) or ban.has(ei):
				continue
			picked.append(ei)
	return picked


static func _deal_knight_phase(rng: RandomNumberGenerator, nw: int, nr: int, ni: int, used_w: Array, used_r: Array, used_i: Array, prev_w: Array, prev_r: Array, prev_i: Array) -> Dictionary:
	var weak := _pick_from_pool(rng, nw, [], used_w, prev_w)
	var resist := _pick_from_pool(rng, nr, weak, used_r, prev_r)
	var wr := weak + resist
	var immune := _pick_from_pool(rng, ni, wr, used_i, prev_i)
	return {"weak": weak, "resist": resist, "immune": immune}


static func _deal_single_entry(rng: RandomNumberGenerator, nw: int, nr: int, ni: int, weak_ban: Array) -> Dictionary:
	var pool := BASE_ELEMENTS.duplicate()
	_shuffle_rng(pool, rng)
	var banned := weak_ban.map(func(x): return int(x))
	var weak := []
	for e in pool:
		if weak.size() >= nw:
			break
		if not banned.has(int(e)):
			weak.append(int(e))
	var rest := pool.filter(func(e): return not weak.has(int(e)))
	_shuffle_rng(rest, rng)
	var resist := rest.slice(0, nr).map(func(e): return int(e))
	var rem := rest.slice(nr)
	var immune := rem.slice(0, ni).map(func(e): return int(e))
	return {"weak": weak, "resist": resist, "immune": immune}


static func _shuffle_rng(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ---- 战斗画像与倍率判定 ----

static func _state_of(logic) -> XState:
	if logic != null and logic.state != null:
		return logic.state
	return XState.current


## 推断敌人当前对应的元素档案（含源类型与阶段）
static func enemy_profile(e, logic = null, s = null) -> Dictionary:
	if s == null:
		s = _state_of(logic)
	if not deck_on(s) or not (e is XEnemy):
		return {"weak": [], "resist": [], "immune": [], "source": "", "phase": 0}
	var enemy := e as XEnemy
	# 1) 化形/终焉级异化怪：只继承当前楼层「免疫」
	if logic != null:
		for row in XTianqiAlienGear.alien_units(logic):
			if is_same(row.get("enemy"), enemy) and str(row.get("level", "")) in ["huaxing", "zhongyan"]:
				var af := _active_floor(logic, s)
				var fd := floor_deck(s, af)
				return {"weak": [], "resist": [], "immune": fd.immune.duplicate(), "source": "alien", "floor": af, "phase": 0}
	# 2) 34 鸿钧
	if str(enemy.horseman.get("rec", {}).get("_ref", "")) == "hongjun":
		var hd := fixed_deal(s, "hongjun")
		hd["source"] = "hongjun"
		hd["phase"] = 1
		return hd
	# 3) 天启四骑士（35 层影子 vs 36 层本体）
	if bool(enemy.horseman.get("knight", false)):
		var hf: Dictionary = logic.get_meta(XTianqiHorsemen.META, {}) if logic != null else {}
		if str(hf.get("mode", "")) == "shadow":
			var yd := fixed_deal(s, "yingzi")
			yd["source"] = "yingzi"
			yd["phase"] = 1
			return yd
		if str(hf.get("mode", "")) == "survival":
			return {"weak": [], "resist": [], "immune": [], "source": "survival", "phase": 0}
		var phase := int(enemy.get_meta("tianqi_elem_phase", int(hf.get("phase", 1))))
		var kd := fixed_deal(s, "knight", phase)
		kd["source"] = "knight"
		kd["phase"] = phase
		return kd
	# 4) 1~33 层守层者
	var gfloor := XGuardianRework.floor_of(enemy.enemy_id)
	if gfloor >= 1 and gfloor <= 33:
		var fd2 := floor_deck(s, gfloor)
		return {"weak": fd2.weak.duplicate(), "resist": fd2.resist.duplicate(), "immune": fd2.immune.duplicate(), "source": "guardian", "floor": gfloor, "phase": 0}
	# 5) 里副本 / 塔外首领（只含 Boss 本体；七印精英等普通怪走常规无弱抗免）
	var rec_dict: Dictionary = enemy.horseman.get("rec", {})
	var ref_kind := str(rec_dict.get("_ref", ""))
	if ref_kind == "qiyin":
		if enemy.boss_difficulty_boss or bool(rec_dict.get("_qiyin_boss", false)):
			var db := fixed_deal(s, "dungeon_boss:qiyin_%d" % enemy.enemy_id)
			db["source"] = "dungeon_boss"
			db["phase"] = 0
			return db
		return {"weak": [], "resist": [], "immune": [], "source": "", "phase": 0}
	if XEnemy.boss_id(enemy.enemy_id):
		var db2 := fixed_deal(s, "dungeon_boss:%d" % enemy.enemy_id)
		db2["source"] = "dungeon_boss"
		db2["phase"] = 0
		return db2
	return {"weak": [], "resist": [], "immune": [], "source": "", "phase": 0}


static func is_boss_enemy(e) -> bool:
	if not (e is XEnemy):
		return false
	var en := e as XEnemy
	var rec_dict: Dictionary = en.horseman.get("rec", {})
	if en.boss_difficulty_boss or bool(en.horseman.get("knight", false)):
		return true
	if str(rec_dict.get("_ref", "")) == "hongjun" or bool(rec_dict.get("_qiyin_boss", false)):
		return true
	return XEnemy.boss_id(en.enemy_id) or XGuardianRework.floor_of(en.enemy_id) > 0


static func _active_floor(logic, s: XState) -> int:
	if logic != null:
		var gf := XGuardianRework.troop_floor(logic)
		if gf >= 1 and gf <= 33:
			return gf
	if s != null:
		var f := XDungeon.map_floor(s.map_id)
		if f >= 1 and f <= 33:
			return f
	return 1


## 动作列表中的物理(1)在天启篇下按无属性(0)处理
static func map_element_id(e: int, s = null) -> int:
	if deck_on(s) and e == 1:
		return 0
	return e


static func map_elements(es: Array, s = null) -> Array:
	if not deck_on(s):
		return es
	var out := []
	for raw_e in es:
		var e := map_element_id(int(raw_e), s)
		if not out.has(e):
			out.append(e)
	return out if not out.is_empty() else [0]


## 计算天启篇攻击对敌人目标的单候选倍率（不改动旧 Actor 受击逻辑）
static func element_rate_for(b, e: int, converted := false, logic = null, options := {}, s = null) -> Dictionary:
	if s == null:
		s = _state_of(logic)
	if not deck_on(s) or not (b is XEnemy):
		return {"rate": b.element_rate(e) if e > 0 else 1.0, "kind": "neutral"}
	var ei := map_element_id(e, s)
	if ei <= 0:
		return {"rate": 1.0, "kind": "neutral"}
	if HIGHER_ELEMENTS.has(ei):
		if not higher_on(s):
			return {"rate": 1.0, "kind": "neutral"}
		var rates_h: Dictionary = data().get("rates", {})
		match ei:
			11:
				return {"rate": float(rates_h.get("void_bonus", 1.25)), "kind": "higher_void"}
			12:
				var choices: Array = rates_h.get("chaos_choices", [1.11, 1.22, 1.33])
				var r_val: float
				if bool(options.get("preview", false)) or options.get("random") == null:
					r_val = float(choices[0]) if not choices.is_empty() else 1.22
				else:
					var rng = options.get("random")
					var idx: int = rng.next_int_inclusive(0, choices.size() - 1, "tianqi_chaos") if rng is XRandomStream else randi_range(0, choices.size() - 1)
					r_val = float(choices[clampi(idx, 0, choices.size() - 1)])
				return {"rate": r_val, "kind": "higher_chaos"}
			13:
				return {"rate": float(rates_h.get("space_bonus", 1.25)), "kind": "higher_space"}
		return {"rate": 1.0, "kind": "higher"}
	var prof := enemy_profile(b, logic, s)
	var rates: Dictionary = data().get("rates", {})
	if (prof.immune as Array).has(ei):
		return {"rate": float(rates.get("immune", 0.0)), "kind": "immune"}
	if (prof.weak as Array).has(ei):
		var wk := float(rates.get("converted_weak", 1.25)) if converted else float(rates.get("weak", 1.5))
		return {"rate": wk, "kind": "converted_weak" if converted else "weak"}
	if (prof.resist as Array).has(ei):
		if _resist_negated(logic, b):
			return {"rate": float(rates.get("neutral", 1.0)), "kind": "resist_negated"}
		return {"rate": float(rates.get("resist", 0.67)), "kind": "resist"}
	return {"rate": float(rates.get("neutral", 1.0)), "kind": "neutral"}


## 供敌方图鉴、UI 等只读查询单个元素的基础倍率（不抽混沌随机数、忽略战中临时吞没）
static func static_enemy_rate(_e: XEnemy, element: int, s = null) -> float:
	if not deck_on(s):
		return 1.0
	var ei := map_element_id(element, s)
	if ei <= 0 or HIGHER_ELEMENTS.has(ei):
		return 1.0
	var prof := enemy_profile(_e, null, s)
	var rates: Dictionary = data().get("rates", {})
	if (prof.immune as Array).has(ei):
		return float(rates.get("immune", 0.0))
	if (prof.weak as Array).has(ei):
		return float(rates.get("weak", 1.5))
	if (prof.resist as Array).has(ei):
		return float(rates.get("resist", 0.67))
	return 1.0


static func _resist_negated(logic, b) -> bool:
	if logic != null:
		var st := _battle(logic)
		if (st.get("void_engulfed", {}) as Dictionary).get(b, false):
			return true
		if XTianqiQiyinEffects.has_resist_down(logic, b):
			return true
	return false


# ---- 战中临时状态（吞没、弱点暴露、骑士换相） ----

static func _battle(logic) -> Dictionary:
	if logic == null:
		return {}
	if not logic.has_meta(META_BATTLE):
		logic.set_meta(META_BATTLE, {"void_engulfed": {}, "weak_exposure": {}})
	return logic.get_meta(META_BATTLE)


static func start(logic) -> void:
	if logic == null or not deck_on(logic.state):
		return
	ensure_deck(logic.state)
	logic.set_meta(META_BATTLE, {"void_engulfed": {}, "weak_exposure": {}})
	for e in logic.enemies:
		enemy_profile(e, logic, logic.state)


static func finish(logic) -> void:
	if logic != null and logic.has_meta(META_BATTLE):
		logic.remove_meta(META_BATTLE)


static func end_turn(logic) -> void:
	if logic == null or not logic.has_meta(META_BATTLE):
		return
	var st := _battle(logic)
	st.void_engulfed = {}
	st.weak_exposure = {}


static func on_horsemen_phase(logic, knight: XEnemy, phase: int) -> String:
	if logic == null or knight == null or not deck_on(logic.state):
		return ""
	knight.set_meta("tianqi_elem_phase", phase)
	var prof := enemy_profile(knight, logic, logic.state)
	return "【元素切换·P%d】%s" % [phase, format_profile_line(prof)]


static func has_weak_exposure(logic, target) -> bool:
	if logic == null or not exposure_on(logic.state):
		return false
	return bool(_battle(logic).get("weak_exposure", {}).get(target, false))


## 返回与词条「破绽」取 max 后的有效增伤百分数（如 11.0 或 affix_pct）
static func combined_exposure_pct(logic, target, affix_pct: float) -> float:
	if has_weak_exposure(logic, target):
		return maxf(affix_pct, float(data().get("rates", {}).get("weak_exposure", 0.11)) * 100.0)
	return affix_pct


static func has_void_engulfed(logic, target) -> bool:
	if logic == null or not higher_on(logic.state):
		return false
	return bool(_battle(logic).get("void_engulfed", {}).get(target, false))


## 本次 HP 伤害是天启篇元素免疫命中（0%）：BattleLogic._apply 据此跳过 respond／establish 零伤害触发链（gpt 核查 P2-3）。
## 条件与 after_apply 的免疫分支一致；西游档（on() 为假）恒为假
static func immune_hit(logic, u: XBattler, skill: Dictionary, t: XBattler, r: Dictionary) -> bool:
	if logic == null or not on(logic.state):
		return false
	if not (u is XActor) or not (t is XEnemy):
		return false
	if not (int(skill.get("damage", {}).get("type", 0)) in [1, 5]):
		return false
	var row: Dictionary = r.get("best_row", {})
	return str(row.get("tianqiKind", "")) == "immune" and float(row.get("resistance", 1.0)) == 0.0


## after_apply 入口：处理免疫弹字标记、虚空吞没、弱点暴露
static func after_apply(logic, u: XBattler, skill: Dictionary, t: XBattler, r: Dictionary, best_row: Dictionary) -> void:
	if logic == null or not on(logic.state):
		return
	if not (u is XActor) or not (t is XEnemy):
		return
	if bool(r.get("missed", false)) or bool(r.get("evaded", false)):
		return
	var dtype := int(skill.get("damage", {}).get("type", 0))
	if not (dtype in [1, 5]):
		return
	if best_row.is_empty():
		return
	var kind := str(best_row.get("tianqiKind", ""))
	var elem := int(best_row.get("element", 0))
	var st := _battle(logic)
	if kind == "immune" and float(best_row.get("resistance", 1.0)) == 0.0:
		r["element_immune"] = true
		var popups: Array = r.get("custom_popups", []).duplicate()
		popups.append({"target": t, "text": "无效", "format": 2, "log": "%s免疫%s！" % [t.display_name(), element_name(elem)]})
		r["custom_popups"] = popups
		return
	if elem == 11 and higher_on(logic.state):
		st.void_engulfed[t] = true
		r["void_engulfed"] = true
	if exposure_on(logic.state) and is_boss_enemy(t) and (kind in ["weak", "converted_weak"] or HIGHER_ELEMENTS.has(elem)):
		if not st.weak_exposure.get(t, false):
			st.weak_exposure[t] = true
			r["weak_exposed_now"] = true


## 13 空间「空蚀」：对实际扣减的 HP 伤害造成 15% 真实生命流失（无视盾/防/抗，无二次触发）
static func apply_space_erosion(logic, u: XBattler, skill: Dictionary, t: XBattler, net_hp_loss: float, best_row: Dictionary, r: Dictionary) -> float:
	if logic == null or not higher_on(logic.state):
		return 0.0
	if not (u is XActor) or not (t is XEnemy):
		return 0.0
	if net_hp_loss <= 0.0 or int(best_row.get("element", 0)) != 13:
		return 0.0
	var rate := float(data().get("rates", {}).get("space_erosion", 0.15))
	var erosion := floorf(net_hp_loss * rate)
	if erosion <= 0.0:
		return 0.0
	var actual := minf(t.hp, erosion)
	if actual <= 0.0:
		return 0.0
	t.hp = maxf(0.0, t.hp - actual)
	r["space_erosion"] = actual
	var extra: Array = r.get("extra", []).duplicate()
	extra.append(actual)
	r["extra"] = extra
	return actual


# ---- 技能表 / 转换书改写（XDB.rec 与学习/商店/掉落） ----

static func touches(table: String, id: int) -> bool:
	if not shifts_on() or _load_failed:
		return false
	var d := data()
	match table:
		"Skills":
			return d.get("skill_shifts", {}).has(str(id)) or d.get("physical_shifts", {}).has(str(id)) or d.get("passive_elup_shifts", {}).has(str(id))
		"Items":
			var br: Dictionary = d.get("conversion_books", {}).get("base_rename", {})
			return id == int(br.get("item", -1))
		"CommonEvents":
			var br2: Dictionary = d.get("conversion_books", {}).get("base_rename", {})
			return id == int(br2.get("ce", -1))
	return false


static func has_new(table: String, id: int) -> bool:
	if not shifts_on() or _load_failed:
		return false
	return _find_new_book_spec(table, id) != {}


static func _find_new_book_spec(table: String, id: int) -> Dictionary:
	var cb: Dictionary = data().get("conversion_books", {})
	var list: Array = cb.get("shop_pair", []) + cb.get("higher", [])
	var key := "item" if table == "Items" else ("skill" if table == "Skills" else ("ce" if table == "CommonEvents" else ""))
	if key == "":
		return {}
	for entry in list:
		if int(entry.get(key, -1)) == id:
			return entry
	return {}


static func new_rec(table: String, id: int, base_table: Array) -> Dictionary:
	if not shifts_on():
		return {}
	var key := "new:%s:%d" % [table, id]
	if _synthetic.has(key):
		return _synthetic[key]
	var spec := _find_new_book_spec(table, id)
	if spec.is_empty():
		return {}
	var elem := int(spec.get("element", 0))
	var ename := element_name(elem)
	var sname := str(spec.get("name", "元素转换:" + ename))
	var sid := int(spec.get("skill", 0))
	var ceid := int(spec.get("ce", 0))
	var iid := int(spec.get("item", 0))
	var out := {}
	match table:
		"Items":
			var tpl: Dictionary = base_table[TEMPLATE_ITEM] if TEMPLATE_ITEM < base_table.size() and base_table[TEMPLATE_ITEM] is Dictionary else {}
			out = tpl.duplicate(true)
			out["id"] = iid
			out["name"] = sname
			out["iconIndex"] = int(spec.get("icon", out.get("iconIndex", 768)))
			out["price"] = int(spec.get("price", out.get("price", 100)))
			out["description"] = "元素转换\n使角色所有攻击伤害转换为%s属性" % ename
			out["effects"] = [{"code": 44, "dataId": ceid, "value1": 1, "value2": 0}]
			var lines := ["<quality:8>", "<ici:9>"]
			if spec.has("buy_item") and spec.has("buy_price"):
				lines.append("<item %d Buy Price: %d>" % [int(spec.buy_item), int(spec.buy_price)])
			else:
				lines.append("<TianqiHigherBook: %d>" % elem)
			lines.append("<pos=APs text=\\c[1]效果:所有技能伤害转换为%s size=18 color=rgba(255,255,255,1) line=false align=0>" % ename)
			lines.append("<pos=APs text=\\c[2]限制:每名角色仅可持有1种元素转换 size=18 color=rgba(255,255,255,1) line=false align=0>")
			if not spec.has("buy_item"):
				lines.append("<pos=APs text=\\c[1]来源:炼狱/证道难度掉落（单档限1本） size=18 color=rgba(255,255,255,1) line=false align=0>")
			var note := "\n".join(lines)
			out["note"] = note
			out["meta"] = XTianqiSkills.parse_meta(note)
		"Skills":
			var stpl: Dictionary = base_table[TEMPLATE_SKILL] if TEMPLATE_SKILL < base_table.size() and base_table[TEMPLATE_SKILL] is Dictionary else {}
			out = stpl.duplicate(true)
			out["id"] = sid
			out["name"] = sname
			out["iconIndex"] = int(spec.get("icon", out.get("iconIndex", 1072)))
			out["description"] = "所有伤害转换为%s" % ename
			var note_s := "\n".join([
				"<Hide in Battle>", "<quality:8>", "<ici:9>",
				"<pos=APs text=\\c[1]所有伤害转换为%s size=18 color=rgba(255,255,255,1) line=false align=0>" % ename,
				"<pos=APs text=\\c[1]效果:自身增伤仍按原属性 size=18 color=rgba(255,255,255,1) line=false align=0>",
				"<DamageElements: %d>" % elem,
			])
			out["note"] = note_s
			out["meta"] = XTianqiSkills.parse_meta(note_s)
		"CommonEvents":
			var ctpl: Dictionary = base_table[TEMPLATE_CE] if TEMPLATE_CE < base_table.size() and base_table[TEMPLATE_CE] is Dictionary else {}
			out = ctpl.duplicate(true)
			out["id"] = ceid
			out["name"] = "元素" + ename
			var new_list := []
			for cmd in out.get("list", []):
				var c2: Dictionary = cmd.duplicate(true)
				var params: Array = c2.get("parameters", [])
				for i in range(params.size()):
					if params[i] is String:
						params[i] = str(params[i]).replace(str(OLD_CE_SKILL), str(sid))
				new_list.append(c2)
			out["list"] = new_list
	_synthetic[key] = out
	return out


static func rec(table: String, id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not shifts_on() or not touches(table, id):
		return base
	var key := "%s:%d:%s" % [table, id, "dual" if PHYSICAL_DUAL_KEEP_NEUTRAL else "single"]
	var hit = _recs.get(key)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var out := base.duplicate(true)
	var d := data()
	if table == "Items":
		var br: Dictionary = d.get("conversion_books", {}).get("base_rename", {})
		if id == int(br.get("item", -1)):
			out["name"] = str(br.get("item_name", out.get("name", "")))
	elif table == "CommonEvents":
		var br2: Dictionary = d.get("conversion_books", {}).get("base_rename", {})
		if id == int(br2.get("ce", -1)):
			out["name"] = str(br2.get("ce_name", out.get("name", "")))
	elif table == "Skills":
		out = _patch_skill(id, out)
	_recs[key] = [base, out]
	return out


static func _patch_skill(id: int, r: Dictionary) -> Dictionary:
	var d := data()
	var s_key := str(id)
	var note := str(r.get("note", ""))
	if d.get("skill_shifts", {}).has(s_key):
		var sp: Dictionary = d.skill_shifts[s_key]
		var elems: Array = sp.get("elements", [])
		if not elems.is_empty():
			var dmg: Dictionary = r.get("damage", {}).duplicate(true)
			dmg["elementId"] = int(elems[0])
			r["damage"] = dmg
			var yep: Dictionary = r.get("yep", {}).duplicate(true)
			if elems.size() > 1:
				yep["multipleElements"] = elems.slice(1).map(func(x): return int(x))
			else:
				yep.erase("multipleElements")
				yep.erase("multiElementRule")
			r["yep"] = yep
			note = _strip_multi_element_tags(note)
			if elems.size() > 1:
				note += "\n<Multiple Elements: %s>" % ", ".join(elems.map(func(x): return str(int(x))))
			if sp.has("note_attr"):
				note = _replace_attr_text(note, str(sp.note_attr))
	elif d.get("physical_shifts", {}).has(s_key):
		var ps: Dictionary = d.physical_shifts[s_key]
		var pe := int(ps.get("element", 0))
		var dmg2: Dictionary = r.get("damage", {}).duplicate(true)
		var yep2: Dictionary = r.get("yep", {}).duplicate(true)
		if PHYSICAL_DUAL_KEEP_NEUTRAL:
			dmg2["elementId"] = 0
			yep2["multipleElements"] = [pe]
			note = _strip_multi_element_tags(note) + "\n<Multiple Elements: 0, %d>" % pe
			if ps.has("note_attr"):
				note = _replace_attr_text(note, "无属性·" + str(ps.note_attr))
		else:
			dmg2["elementId"] = pe
			yep2.erase("multipleElements")
			note = _strip_multi_element_tags(note)
			if ps.has("note_attr"):
				note = _replace_attr_text(note, str(ps.note_attr))
		r["damage"] = dmg2
		r["yep"] = yep2
	if d.get("passive_elup_shifts", {}).has(s_key):
		var ep: Dictionary = d.passive_elup_shifts[s_key]
		var fc := str(ep.get("from", "03"))
		var tc := str(ep.get("to", "14"))
		note = note.replace("<passiveELUP%s:" % fc, "<passiveELUP%s:" % tc)
		note = note.replace("<passiveELUP0%s:" % str(int(fc)), "<passiveELUP%s:" % tc)
		if ep.has("from_text") and ep.has("to_text"):
			note = note.replace(str(ep.from_text) + "伤害", str(ep.to_text) + "伤害")
			r["description"] = str(r.get("description", "")).replace(str(ep.from_text) + "伤害", str(ep.to_text) + "伤害")
	r["note"] = note
	r["meta"] = XTianqiSkills.parse_meta(note)
	return r


static func _strip_multi_element_tags(note: String) -> String:
	var n := RegEx.create_from_string("(?i)<Multiple Elements:[^>]*>\\n?").sub(note, "", true)
	return RegEx.create_from_string("(?i)<Multi-Element Rule:[^>]*>\\n?").sub(n, "", true)


static func _replace_attr_text(note: String, attr_label: String) -> String:
	return RegEx.create_from_string("(伤害属性:)[^\\s>]+").sub(note, "$1" + attr_label, true)


## 学到任一元素转换技能时，互斥遗忘其余所有转换技能（含老版 5068~5075 与新版 11201~11205）
static func learned_skill(actor: XActor, id: int) -> void:
	if actor == null or not CONVERSION_SKILLS.has(id) or not shifts_on():
		return
	for sid in CONVERSION_SKILLS:
		if sid != id and actor.skill_ids.has(sid):
			actor.forget_skill(sid)


## 8号当铺商品表追加水/风转换书
static func shop_goods(s: XState, map_id: int, goods: Array) -> Array:
	if map_id != PAWNSHOP_MAP or not shifts_on(s):
		return goods
	var out := goods.duplicate(true)
	var existing := {}
	for g in out:
		if int(g[0]) == 0:
			existing[int(g[1])] = true
	for entry in data().get("conversion_books", {}).get("shop_pair", []):
		var iid := int(entry.get("item", 0))
		if iid > 0 and not existing.has(iid):
			out.append([0, iid, 0, 0])
	return out


## 炼狱/证道难度首领/守层者战胜利后掉落高阶转换书（3103~3105，单档每本限一次）
static func grant_higher_books(logic) -> Array:
	if logic == null or not shifts_on(logic.state):
		return []
	var s: XState = logic.state
	var diff := str(s.flags.get("tianqi", {}).get("difficulty", ""))
	var allowed: Array = data().get("conversion_books", {}).get("higher_drop_difficulties", ["lianyu", "zhengdao"])
	if not allowed.has(diff):
		return []
	var boss_win: bool = logic.enemies.any(func(e): return not e.hidden and is_boss_enemy(e))
	if not boss_win:
		return []
	return roll_higher_books(s, logic, func(): return logic.random.reward.next_float("tianqi_elem_book", "battle"))


static func roll_higher_books(s: XState, _logic = null, rand: Callable = Callable()) -> Array:
	if not shifts_on(s):
		return []
	var diff := str(s.flags.get("tianqi", {}).get("difficulty", ""))
	var allowed: Array = data().get("conversion_books", {}).get("higher_drop_difficulties", ["lianyu", "zhengdao"])
	if not allowed.has(diff):
		return []
	var st := store(s)
	var dropped: Dictionary = st.get("dropped_books", {})
	var fails: Dictionary = st.get("book_fails", {})
	var books: Array = data().get("conversion_books", {}).get("higher", [])
	var rate_mult := XTianqiDrop.party_mult(s)
	var texts := []
	for entry in books:
		var iid := int(entry.get("item", 0))
		var key := str(iid)
		if iid <= 0 or bool(dropped.get(key, false)):
			continue
		var nfail := int(fails.get(key, 0))
		var chance := clampf((0.05 + 0.05 * nfail) * rate_mult, 0.0, 1.0)
		var r := float(rand.call()) if rand.is_valid() else randf()
		if r < chance:
			dropped[key] = true
			fails.erase(key)
			s.gain_item(iid, 1)
			var rec_item := XDB.rec("Items", iid)
			texts.append("获得高阶元素转换书：%s！" % str(rec_item.get("name", entry.get("name", ""))))
		else:
			fails[key] = nfail + 1
	return texts


# ---- UI 格式化工具 ----

static func format_profile_line(prof: Dictionary) -> String:
	var parts := []
	var labels := [["weak", "弱"], ["resist", "抗"], ["immune", "免"]]
	for pair in labels:
		var arr: Array = prof.get(pair[0], [])
		var tx := "、".join(arr.map(func(e): return element_name(int(e)))) if not arr.is_empty() else "无"
		parts.append("%s:%s" % [pair[1], tx])
	return "  ".join(parts)


static func party_coverage(s: XState, prof: Dictionary) -> Dictionary:
	if s == null or not deck_on(s):
		return {"weak_hits": [], "immune_blocked": [], "has_higher": false}
	var weak_set: Array = prof.get("weak", [])
	var imm_set: Array = prof.get("immune", [])
	var elems := {}
	for a in s.battle_members():
		if a == null:
			continue
		var conv := int(a.passive_cache().get("damageElement", 0))
		if conv > 0:
			elems[map_element_id(conv, s)] = true
		for sid in a.skill_ids:
			var sk := XDB.rec("Skills", sid)
			if sk.is_empty() or int(sk.get("damage", {}).get("type", 0)) <= 0:
				continue
			for e in XDamage.action_elements(sk, a):
				elems[map_element_id(int(e), s)] = true
	var weak_hits := []
	var immune_blocked := []
	var has_higher := false
	for ek in elems:
		var ei := int(ek)
		if weak_set.has(ei):
			weak_hits.append(ei)
		if imm_set.has(ei):
			immune_blocked.append(ei)
		if HIGHER_ELEMENTS.has(ei):
			has_higher = true
	return {"weak_hits": weak_hits, "immune_blocked": immune_blocked, "has_higher": has_higher}


static func skill_badge(a: XActor, skill: Dictionary, enemies: Array, logic = null) -> Dictionary:
	var s := _state_of(logic)
	if a == null or skill.is_empty() or not deck_on(s):
		return {}
	if not (int(skill.get("damage", {}).get("type", 0)) in [1, 5]):
		return {}
	var target = null
	for e in enemies:
		if e is XEnemy and not e.hidden and e.is_alive():
			if is_boss_enemy(e) or target == null:
				target = e
			if is_boss_enemy(e):
				break
	if target == null:
		return {}
	var es := XDamage.action_elements(skill, a)
	if es.is_empty():
		return {}
	var has_higher := false
	var has_weak := false
	var has_resist := false
	var has_neutral := false
	var has_immune := false
	for raw_e in es:
		var ei := map_element_id(int(raw_e), s)
		var info := element_rate_for(target, ei, false, logic, {"preview": true}, s)
		match str(info.kind):
			"higher_void", "higher_chaos", "higher_space", "higher":
				has_higher = true
			"weak", "converted_weak":
				has_weak = true
			"immune":
				has_immune = true
			"resist":
				has_resist = true
			_:
				has_neutral = true
	if has_higher:
		return {"text": "[高阶]", "color": Color("#d5b3ff")}
	if has_weak:
		return {"text": "[弱点]", "color": Color("#7cff9b")}
	if has_immune and not has_neutral and not has_resist:
		return {"text": "[免疫]", "color": Color("#ff7070")}
	if has_resist and not has_neutral:
		return {"text": "[抗性]", "color": Color("#ffd27d")}
	return {}


static func hud_floor_line(s: XState) -> String:
	if s == null or not deck_on(s):
		return ""
	var f := XDungeon.map_floor(s.map_id)
	if f < 1 or f > 33:
		return ""
	return "  %d层%s" % [f, format_profile_line(floor_deck(s, f))]


static func transfer_floor_line(s: XState, target_map_id: int) -> String:
	if s == null or not deck_on(s) or target_map_id <= 0:
		return ""
	var f := XDungeon.map_floor(target_map_id)
	if f < 1 or f > 33:
		return ""
	return "第%d层元素  %s" % [f, format_profile_line(floor_deck(s, f))]


static func profile_tooltip(prof: Dictionary) -> String:
	if prof.is_empty() or (prof.get("weak", []).is_empty() and prof.get("resist", []).is_empty() and prof.get("immune", []).is_empty()):
		return ""
	var lines := []
	if int(prof.get("phase", 0)) > 0 and str(prof.get("source", "")) == "knight":
		lines.append("当前阶段：P%d" % int(prof.phase))
	var fmt := func(arr: Array): return "、".join(arr.map(func(e): return element_name(int(e)))) if not arr.is_empty() else "无"
	lines.append("弱点（+50%% / 转换书+25%%）：%s" % fmt.call(prof.get("weak", [])))
	lines.append("抗性（-33%%）：%s" % fmt.call(prof.get("resist", [])))
	lines.append("免疫（无效 0%%）：%s" % fmt.call(prof.get("immune", [])))
	return "\n".join(lines)
