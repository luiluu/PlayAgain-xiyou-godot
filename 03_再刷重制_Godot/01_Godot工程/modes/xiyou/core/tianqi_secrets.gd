class_name XTianqiSecrets
extends RefCounted
## 【小A·天启篇·未经审查】秘籍格核心系统（T446 / T013-1b；设计依据：天启篇_原版养成线重做方案_v0.3 第三节第 8 条、D274）。
##
## 规则：
## - 格数上限＝角色档位基数（balance_table.json tiers.<档位>.secret_cap：弱 6、强 4、超强 3）
##   ＋天启篇当前难度加成（D282，balance_table.json difficulties[].secret_cap_bonus：寻常/艰险 0、九死 +1、炼狱 +2、证道 +3，三档同加）。
## - 占格：功法（stype=6）、通用被动书（code 43 ＋ CE code 44，stype=4）、元素转换书（老 5068~5075 ＋ 新 11201~11205）、
##   深渊六式被动（6192~6203 / 6206~6211）与止戈/天怒（6185 / 6204）。
## - 不占格：号卷（XTianqiTrumpet / <CodexPower>）、抽奖被动（stype=5）、主动书（stype 1/2/3 等）、
##   角色自带/职业/进阶被动、27 本 Boss 血脉（D274④）、58 张外观变身卡（6801~6858）、种族技能、万灵增元丹被动。
## - 元素转换书：首次学占 1 格；当前生效格里已有另一门转换书时原地替换，不要求先空出新格。
## - 花场钱封印：腾出 1 格、不退书、被动立即失效（_skill_records 滤掉已封，不删 skill_ids）；封印记录在 flags.tianqi.secrets。
## - 老存档迁移／换低难度超量封印：读档后（或调 enforce_caps）若某角色生效占格秘籍超出当前难度上限，不没收，超出部分自动移入已封并授予该角色首次免费自选生效格（free_pick）。
## - 回退开关：ENABLED = false 完整回退到旧临时截断；DIFFICULTY_BONUS = false 回退到固定 6/4/3；西游档（XTianqi.active == false）零变化、零存档字段。
##
## 玩家可见文字（待小A/cc Sonnet 审）全部集中在本模块 ui_* / learn_reason / seal / unseal 中，
## 发行空壳替换本脚本后西游发行包零外泄。

static var ENABLED := true
static var DIFFICULTY_BONUS := true
static var GONGFA_REWORK := true
static var EV54_SHOP := true

const PATH := "res://modes/xiyou/tianqi_data/secret_books.json"
const SECTION := "secrets"
const EV54_MAP := 4
const EV54_EVENT := 54
const EV54_HIDE_SWITCH := 681
const EV54_STOCK_GROUP := "人道碎片相关物品购买"

static var _data: Dictionary = {}
static var _load_failed := false
static var _index_ready := false
static var _include_set := {}
static var _exempt_set := {}
static var _conversion_set := {}
static var _conversion_items := {}
static var _ignore_items := {}
static var _slot_stypes := [4, 6]
static var _book_skills := {}
static var _ce_item_info := {}  # item_id -> {skills: Array[int], fixed_actor: int, paths: Array}
static var _gongfa_by_skill := {}  # skill_id -> spec
static var _gongfa_by_item := {}   # item_id -> spec
static var _school_skills := {}    # school_key -> Array[int]
static var _state_specs := {}      # state_id -> spec
static var _banned_items := {}     # item_id -> true
static var _view_cache := {}       # "Table:id" -> Dictionary


# ---- 数据加载与开关 ----

static func data() -> Dictionary:
	if _data.is_empty() and not _load_failed:
		if XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiSecrets: 读不到或解析失败 " + PATH)
			return {}
		_data = parsed
	return _data


static func reload_table() -> void:
	_data = {}
	_load_failed = false
	_index_ready = false
	_include_set = {}
	_exempt_set = {}
	_conversion_set = {}
	_conversion_items = {}
	_ignore_items = {}
	_slot_stypes = [4, 6]
	_book_skills = {}
	_ce_item_info = {}
	_gongfa_by_skill = {}
	_gongfa_by_item = {}
	_school_skills = {}
	_state_specs = {}
	_banned_items = {}
	_view_cache = {}


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) and not data().is_empty()


static func gongfa_on(s = null) -> bool:
	return GONGFA_REWORK and on(s)


static func ev54_on(s = null) -> bool:
	return EV54_SHOP and on(s)


static func _ensure_index() -> void:
	if _index_ready:
		return
	var d := data()
	if d.is_empty():
		return
	_index_ready = true
	var rules: Dictionary = d.get("rules", {})
	var st_raw = rules.get("slot_stypes", [4, 6])
	_slot_stypes = []
	if st_raw is Array:
		for x in st_raw:
			_slot_stypes.append(int(x))
	if _slot_stypes.is_empty():
		_slot_stypes = [4, 6]
	# 豁免名单
	var ex: Dictionary = d.get("seal_exempt", {})
	for k in ["bloodlines", "not_book"]:
		for sid in ex.get(k, []):
			_exempt_set[int(sid)] = true
	var cr: Array = ex.get("costume_range", [])
	if cr.size() >= 2:
		for sid in range(int(cr[0]), int(cr[1]) + 1):
			_exempt_set[sid] = true
	# 显式占格与转换书名单
	var inc: Dictionary = d.get("include_skills", {})
	for k in ["abyss_six_passives", "sect_passives", "conversion_skills"]:
		for sid in inc.get(k, []):
			_include_set[int(sid)] = true
	for sid in inc.get("conversion_skills", []):
		_conversion_set[int(sid)] = true
	for sid in XTianqiElements.CONVERSION_SKILLS:
		_conversion_set[int(sid)] = true
		_include_set[int(sid)] = true
	var ci: Dictionary = d.get("conversion_items", {})
	for k in ci:
		if str(k).is_valid_int():
			_conversion_items[int(k)] = int(ci[k])
	for iid in d.get("ignore_items", []):
		_ignore_items[int(iid)] = true
	# T013-1c：功法重标表、门表、状态表
	var sk_tbl: Dictionary = d.get("skills", {})
	for k in sk_tbl:
		if not str(k).is_valid_int() or not (sk_tbl[k] is Dictionary):
			continue
		var sp: Dictionary = sk_tbl[k]
		var sid := int(k)
		var iid := int(sp.get("item", 0))
		_gongfa_by_skill[sid] = sp
		if iid > 0:
			_gongfa_by_item[iid] = sp
			if bool(sp.get("banned", false)):
				_banned_items[iid] = true
		_book_skills[sid] = true
		_include_set[sid] = true
	var sc_tbl: Dictionary = d.get("schools", {})
	for sc_key in sc_tbl:
		var sc_val = sc_tbl[sc_key]
		if not (sc_val is Dictionary):
			continue
		var tiers_map = sc_val.get("tiers", {})
		var all_sids: Array[int] = []
		if tiers_map is Dictionary:
			for tk in tiers_map:
				var arr = tiers_map[tk]
				if arr is Array:
					for sid in arr:
						if not all_sids.has(int(sid)):
							all_sids.append(int(sid))
		all_sids.sort()
		_school_skills[str(sc_key)] = all_sids
	var st_tbl: Dictionary = d.get("states", {})
	for k in st_tbl:
		if str(k).is_valid_int() and st_tbl[k] is Dictionary:
			_state_specs[int(k)] = st_tbl[k]
	# 扫描物品表（code 43 ＋ CE code 44）建立书教技能索引
	_scan_items()


static func _scan_items() -> void:
	var re_power := RegEx.create_from_string("<CodexPower:\\s*\\d+>")
	var re_learn := RegEx.create_from_string("learnSkill\\((\\d+)\\)")
	var re_var := RegEx.create_from_string("var\\s+\\w+\\s*=\\s*(\\d+)\\s*;")
	var ces = XDB.table("CommonEvents")
	for it in XDB.table("Items"):
		if not it is Dictionary:
			continue
		var iid := int(it.get("id", 0))
		if iid <= 0 or _ignore_items.has(iid) or _conversion_items.has(iid):
			continue
		if re_power.search(str(it.get("note", ""))) != null:
			continue
		var ce_sids := {}
		var ce_paths: Array = []
		var ce_fixed := {}
		var ce_dynamic := false
		for e in it.get("effects", []):
			var code := int(e.get("code", 0))
			var did := int(e.get("dataId", 0))
			if code == 43 and did > 0:
				_book_skills[did] = true
			elif code == 44 and did > 0 and ces is Array and did < ces.size() and ces[did] is Dictionary:
				var info := _scan_ce(ces[did], re_learn, re_var)
				if info.is_empty():
					continue
				for sid in info.skills:
					_book_skills[int(sid)] = true
					ce_sids[int(sid)] = true
				for pt in info.paths:
					ce_paths.append(pt)
				if int(info.fixed_actor) > 0:
					ce_fixed[int(info.fixed_actor)] = true
				else:
					ce_dynamic = true
		if not ce_sids.is_empty():
			var arr: Array[int] = []
			for sid in ce_sids:
				arr.append(int(sid))
			arr.sort()
			var fixed_actor := int(ce_fixed.keys()[0]) if (not ce_dynamic and ce_fixed.size() == 1) else 0
			_ce_item_info[iid] = {"skills": arr, "fixed_actor": fixed_actor, "paths": ce_paths}


static func _scan_ce(ce: Dictionary, re_learn: RegEx, re_var: RegEx) -> Dictionary:
	var lst: Array = ce.get("list", [])
	var recruits := {}
	var has_learn := false
	for c in lst:
		var code := int(c.get("code", 0))
		var p: Array = c.get("parameters", [])
		if code == 129 and p.size() > 1 and int(p[1]) == 0:
			recruits[int(p[0])] = true
		elif code == 318 and p.size() > 3 and int(p[2]) == 0:
			has_learn = true
		elif code in [355, 655] and not p.is_empty():
			if str(p[0]).contains("learnSkill("):
				has_learn = true
	if not has_learn:
		return {}  # 只有 forgetSkill（如转换药剂）或纯辅助事件不收
	var acc := {"all": {}, "fixed": {}, "dynamic": false}
	var parsed := _scan_ce_block(lst, 0, 0, recruits, re_learn, re_var, acc)
	var raw_paths: Array = parsed[1]
	var clean_paths: Array = []
	for pt in raw_paths:
		if not (pt is Dictionary) or pt.is_empty():
			continue
		var arr: Array[int] = []
		for sid in pt:
			arr.append(int(sid))
		arr.sort()
		if not clean_paths.has(arr):
			clean_paths.append(arr)
	var all_arr: Array[int] = []
	for sid in acc.all:
		all_arr.append(int(sid))
	all_arr.sort()
	var fixed_actor := int(acc.fixed.keys()[0]) if (not bool(acc.dynamic) and acc.fixed.size() == 1) else 0
	return {"skills": all_arr, "fixed_actor": fixed_actor, "paths": clean_paths}


static func _scan_ce_block(lst: Array, start: int, indent: int, recruits: Dictionary, re_learn: RegEx, re_var: RegEx, acc: Dictionary) -> Array:
	var paths: Array = [{}]
	var i := start
	while i < lst.size():
		var c: Dictionary = lst[i]
		var ci := int(c.get("indent", 0))
		var code := int(c.get("code", 0))
		var p: Array = c.get("parameters", [])
		if ci < indent:
			break
		if ci == indent and code in [402, 403, 404, 411, 412]:
			break
		if code == 102:
			i += 1
			var branch_paths: Array = []
			while i < lst.size():
				var cc: Dictionary = lst[i]
				var cci := int(cc.get("indent", 0))
				var ccode := int(cc.get("code", 0))
				if cci == indent and ccode == 404:
					i += 1
					break
				if cci == indent and ccode in [402, 403]:
					var sub := _scan_ce_block(lst, i + 1, indent + 1, recruits, re_learn, re_var, acc)
					i = int(sub[0])
					branch_paths.append_array(sub[1])
				else:
					i += 1
			if not branch_paths.is_empty():
				paths = _merge_paths(paths, branch_paths)
			continue
		elif code == 111:
			var sub_then := _scan_ce_block(lst, i + 1, indent + 1, recruits, re_learn, re_var, acc)
			i = int(sub_then[0])
			var else_paths: Array = [{}]
			if i < lst.size() and int(lst[i].get("indent", 0)) == indent and int(lst[i].get("code", 0)) == 411:
				var sub_else := _scan_ce_block(lst, i + 1, indent + 1, recruits, re_learn, re_var, acc)
				i = int(sub_else[0])
				else_paths = sub_else[1]
			if i < lst.size() and int(lst[i].get("indent", 0)) == indent and int(lst[i].get("code", 0)) == 412:
				i += 1
			var combined: Array = []
			combined.append_array(sub_then[1])
			combined.append_array(else_paths)
			paths = _merge_paths(paths, combined)
			continue
		elif code == 318 and p.size() > 3 and int(p[2]) == 0:
			if not (int(p[0]) == 0 and recruits.has(int(p[1]))):
				var sid := int(p[3])
				acc.all[sid] = true
				if int(p[0]) == 0 and int(p[1]) > 0:
					acc.fixed[int(p[1])] = true
				else:
					acc.dynamic = true
				for pt in paths:
					pt[sid] = true
		elif code in [355, 655] and not p.is_empty():
			var line := str(p[0])
			for m in re_learn.search_all(line):
				var sid := int(m.get_string(1))
				acc.all[sid] = true
				acc.dynamic = true
				for pt in paths:
					pt[sid] = true
			for m in re_var.search_all(line):
				var sid := int(m.get_string(1))
				if int(XDB.rec("Skills", sid).get("stypeId", 0)) == 4:
					acc.all[sid] = true
					acc.dynamic = true
		i += 1
	return [i, _dedup_path_dicts(paths)]


static func _merge_paths(base: Array, branches: Array) -> Array:
	var out: Array = []
	for a in base:
		for b in branches:
			var m: Dictionary = (a as Dictionary).duplicate()
			for k in b:
				m[k] = true
			out.append(m)
	return _dedup_path_dicts(out)


static func _dedup_path_dicts(paths: Array) -> Array:
	var out: Array = []
	var seen := {}
	for pt in paths:
		var ks := (pt as Dictionary).keys()
		ks.sort()
		var sig := ",".join(ks.map(func(x): return str(x)))
		if not seen.has(sig):
			seen[sig] = true
			out.append(pt)
	return out


# ---- 占格与格数判定 ----

static func is_conversion_skill(id: int) -> bool:
	if id <= 0:
		return false
	_ensure_index()
	return _conversion_set.has(id)


static func is_exempt(id: int) -> bool:
	if id <= 0:
		return true
	_ensure_index()
	if _exempt_set.has(id):
		return true
	if XTianqiLedger.PILL_PASSIVES.has(id) or XTianqiTrumpet.of_skill(id) != 0 or XPowerBooks.is_power(id):
		return true
	if not XRace.skill_info(id).is_empty():
		return true
	return false


## 该技能是否占秘籍格（功法、通用被动书 code 43/44、元素转换书、深渊六式被动与止戈/天怒）
static func occupies_slot(id: int) -> bool:
	if id <= 0:
		return false
	_ensure_index()
	if is_exempt(id):
		return false
	if _include_set.has(id):
		return true
	var sk := XDB.rec("Skills", id)
	if sk.is_empty():
		return false
	var stype := int(sk.get("stypeId", 0))
	if not _slot_stypes.has(stype):
		return false
	return _book_skills.has(id)


## 角色秘籍格档位：天启篇档按天启篇运行时名单档位（XTianqiSkills.tier_of），西游档零改动按 XTier
static func tier_of(a, s: XState = null) -> String:
	if not (a is XActor):
		return ""
	if s == null:
		s = XState.current
	if XTianqi.active(s) and XTianqiSkills.tiers_on(s):
		var t := XTianqiSkills.tier_of(a, true)
		if t != "":
			return t
	return XTier.tier_of(a)


## 当前存档的天启篇难度键（西游档恒返回 ""，守卫 XTianqi.active）
static func difficulty_key(s: XState = null) -> String:
	if s == null:
		s = XState.current
	if not XTianqi.active(s):
		return ""
	return str(s.flags.tianqi.get("difficulty", ""))


## 当前存档的天启篇难度显示名（如「寻常」「炼狱」「证道」；西游档恒返回 ""）
static func difficulty_name(s: XState = null) -> String:
	var key := difficulty_key(s)
	if key == "":
		return ""
	return str(XTianqiBalance.difficulty(key).get("name", ""))


## 当前存档的难度秘籍格加成（D282：寻常/艰险 0、九死 +1、炼狱 +2、证道 +3；西游档或关 DIFFICULTY_BONUS 恒 0）
static func difficulty_bonus(s: XState = null) -> int:
	if not DIFFICULTY_BONUS:
		return 0
	var key := difficulty_key(s)
	if key == "":
		return 0
	return XTianqiBalance.secret_cap_bonus(key)


static func _cap_prefix(s: XState) -> String:
	var dname := difficulty_name(s)
	return "%s难度下" % dname if dname != "" else ""


## 角色秘籍格上限：档位基数（弱 6 / 强 4 / 超 3）＋天启篇当前难度加成（D282：寻常/艰险 +0、九死 +1、炼狱 +2、证道 +3）
## 西游档（XTianqi.active == false）零改动，只按 XTier 返回基数（difficulty_bonus 恒 0）
static func limit(a, s: XState = null) -> int:
	if not (a is XActor):
		return 0
	if s == null:
		s = XState.current
	var base := XTianqiBalance.secret_cap(tier_of(a, s))
	if base <= 0:
		return 0
	return base + difficulty_bonus(s)


# ---- 存档分区（flags.tianqi.secrets）----

static func fill(d: Dictionary) -> void:
	if not (d.get("actors") is Dictionary):
		d["actors"] = {}
	var actors: Dictionary = d["actors"]
	for k in actors.keys():
		var row = actors[k]
		if not (row is Dictionary):
			actors[k] = {"sealed": [], "free_pick": false, "migrated": false}
			continue
		var raw = row.get("sealed", [])
		var clean: Array[int] = []
		if raw is Array:
			for sid in raw:
				var id := int(sid)
				if id > 0 and not clean.has(id):
					clean.append(id)
		clean.sort()
		row["sealed"] = clean
		row["free_pick"] = bool(row.get("free_pick", false))
		row["migrated"] = bool(row.get("migrated", false))


static func _peek_actor(s: XState, actor_id: int) -> Dictionary:
	if s == null or not on(s):
		return {}
	var sec = XTianqiSave.peek(s, SECTION)
	if not (sec is Dictionary):
		return {}
	var actors = sec.get("actors")
	if not (actors is Dictionary):
		return {}
	var row = actors.get(str(actor_id))
	return row if row is Dictionary else {}


static func _write_actor(s: XState, actor_id: int) -> Dictionary:
	var sec: Dictionary = XTianqiSave.section(s, SECTION)
	var actors: Dictionary = sec["actors"]
	var key := str(actor_id)
	if not (actors.get(key) is Dictionary):
		actors[key] = {"sealed": [], "free_pick": false, "migrated": false}
	return actors[key]


## 该角色当前已封秘籍 ID（仅保留仍在 skill_ids 且占格的技能）
static func sealed_ids(a, s: XState = null) -> Array[int]:
	if not on(s) or not (a is XActor):
		return []
	if s == null:
		s = XState.current
	var row := _peek_actor(s, a.actor_id)
	var raw = row.get("sealed", [])
	var out: Array[int] = []
	if raw is Array:
		for sid in raw:
			var id := int(sid)
			if id > 0 and a.skill_ids.has(id) and occupies_slot(id) and not out.has(id):
				out.append(id)
	out.sort()
	return out


static func is_sealed(a, skill_id: int, s: XState = null) -> bool:
	if not on(s) or not (a is XActor) or skill_id <= 0:
		return false
	if s == null:
		s = XState.current
	var row := _peek_actor(s, a.actor_id)
	var raw = row.get("sealed", [])
	if not (raw is Array):
		return false
	for sid in raw:
		if int(sid) == skill_id:
			return occupies_slot(skill_id)
	return false


## 该角色当前占着生效格的秘籍 ID（升序）
static func active_ids(a, s: XState = null) -> Array[int]:
	if not on(s) or not (a is XActor):
		return []
	if s == null:
		s = XState.current
	var sealed := sealed_ids(a, s)
	var out: Array[int] = []
	for sid in a.skill_ids:
		var id := int(sid)
		if occupies_slot(id) and not sealed.has(id) and not out.has(id):
			out.append(id)
	out.sort()
	return out


static func used_slots(a, s: XState = null) -> int:
	if not on(s):
		return 0
	return active_ids(a, s).size()


static func has_free_pick(a, s: XState = null) -> bool:
	if not on(s) or not (a is XActor):
		return false
	if s == null:
		s = XState.current
	var row := _peek_actor(s, a.actor_id)
	return bool(row.get("free_pick", false)) and not sealed_ids(a, s).is_empty()


## 当前生效格里已装备的元素转换书技能 ID（没有为 0）
static func active_conversion_id(a, s: XState = null) -> int:
	for sid in active_ids(a, s):
		if is_conversion_skill(sid):
			return sid
	return 0


# ---- 学书拦截与物品检测 ----

static func learn_reason(a, skill_id: int, s: XState = null) -> String:
	if not on(s) or not (a is XActor) or not occupies_slot(skill_id):
		return ""
	if s == null:
		s = XState.current
	# T013-1c：停用功法、专属角色限制、同系高阶替换低阶
	if gongfa_on(s):
		_ensure_index()
		if _gongfa_by_skill.has(skill_id):
			var sp: Dictionary = _gongfa_by_skill[skill_id]
			if bool(sp.get("banned", false)):
				return "此秘籍在天启篇已停用，不可修习、不生效"
			var only_aid := int(sp.get("only_actor", 0))
			if only_aid > 0 and a.actor_id != only_aid:
				var who_nm := str(XDB.rec("Actors", only_aid).get("name", "指定角色"))
				return "此秘籍仅%s可修习" % who_nm
	if a.skill_ids.has(skill_id):
		if is_sealed(a, skill_id, s):
			return "已学会此秘籍（已封印），请在技能页启封，启封后生效"
		return "已经学会这本秘籍"
	if gongfa_on(s) and _gongfa_by_skill.has(skill_id):
		var higher := _owned_school_higher_or_same(a, skill_id)
		if higher > 0:
			var hnm := str(XDB.rec("Skills", higher).get("name", ""))
			return "已修习同系更高阶或同阶秘籍%s，无需重复修习" % _quote_name(hnm)
		# 当前生效格里已有同系更低阶 → 原地升级替换，净增 0 格，放行
		if _active_school_lower_id(a, skill_id, s) > 0:
			return ""
	# 元素转换书：当前生效格已有另一门转换书 → 原地替换，不占新格
	if is_conversion_skill(skill_id) and active_conversion_id(a, s) > 0:
		return ""
	var cap := limit(a, s)
	var used := used_slots(a, s)
	if cap > 0 and used >= cap:
		return "%s%s最多装备 %d 本秘籍（当前 %d / %d），请先在技能页封印已有秘籍" % [_cap_prefix(s), tier_of(a, s), cap, used, cap]
	return ""


static func can_learn(a, skill_id: int, s: XState = null) -> bool:
	if not on(s):
		return true
	return learn_reason(a, skill_id, s).is_empty()


## 供 XActor.learn_skill 调用：关着或西游档恒返回 false（不拦）
static func blocks_learn(a, skill_id: int, s: XState = null) -> bool:
	if not on(s):
		return false
	return not learn_reason(a, skill_id, s).is_empty()


## 使用物品前校验（覆盖 code 43、元素转换书、CE code 44 被动书，含单书多技能与固定角色 CE；a 可为空用于无对象直用道具）
static func item_learn_reason(a, item: Dictionary, s: XState = null) -> String:
	if not on(s) or item.is_empty():
		return ""
	if s == null:
		s = XState.current
	_ensure_index()
	var iid := int(item.get("id", 0))
	if _ignore_items.has(iid) or XPowerBooks.book_skill(item) > 0:
		return ""
	var fixed_actor := 0
	var target: XActor = null
	if _ce_item_info.has(iid) and int(_ce_item_info[iid].get("fixed_actor", 0)) > 0:
		fixed_actor = int(_ce_item_info[iid].fixed_actor)
		if s != null and not XDB.rec("Actors", fixed_actor).is_empty():
			target = s.actor(fixed_actor)
	elif a is XActor:
		target = a
	if target == null:
		return ""
	# 1) 元素转换书物品（老版 1035~1042、新版 3101~3105）
	if _conversion_items.has(iid):
		return learn_reason(target, int(_conversion_items[iid]), s)
	# 2) 直接学会技能（code 43，支持同一本书教多个占格技能如物品 1998）
	var sids43: Array[int] = []
	for e in item.get("effects", []):
		if int(e.get("code", 0)) == 43:
			var sid := int(e.get("dataId", 0))
			if occupies_slot(sid) and not sids43.has(sid):
				sids43.append(sid)
	if sids43.size() == 1:
		return learn_reason(target, sids43[0], s)
	if sids43.size() > 1:
		var need43 := 0
		var has_sealed43 := false
		var conv_free := active_conversion_id(target, s) > 0
		for sid in sids43:
			if target.skill_ids.has(sid):
				if is_sealed(target, sid, s):
					has_sealed43 = true
				continue
			if is_conversion_skill(sid) and conv_free:
				conv_free = false
				continue
			need43 += 1
		if need43 == 0:
			return "已学会此秘籍（已封印），请在技能页启封，启封后生效" if has_sealed43 else "已经学会这本秘籍"
		var cap43 := limit(target, s)
		var used43 := used_slots(target, s)
		if cap43 > 0 and used43 + need43 > cap43:
			return "%s%s最多装备 %d 本秘籍（当前 %d / %d，本书需 %d 格），请先在技能页封印已有秘籍" % [_cap_prefix(s), tier_of(target, s), cap43, used43, cap43, need43]
		return ""
	# 3) 公共事件教技能（code 44）
	if _ce_item_info.has(iid):
		var info: Dictionary = _ce_item_info[iid]
		var slot_sids: Array[int] = []
		for sid in info.get("skills", []):
			if occupies_slot(int(sid)):
				slot_sids.append(int(sid))
		if slot_sids.is_empty():
			return ""
		var who := "%s（%s）" % [target.display_name(), tier_of(target, s)] if fixed_actor > 0 else tier_of(target, s)
		if slot_sids.size() == 1:
			var r1 := learn_reason(target, slot_sids[0], s)
			if fixed_actor > 0 and not r1.is_empty():
				return "%s：%s" % [target.display_name(), r1]
			return r1
		# 按每条分支（心法正/逆/邪或条件分支）计算同分支同时新增的占格技能数，取最大值预留格位（T446 P2-2）
		var paths: Array = info.get("paths", [])
		var max_need := 0
		if not paths.is_empty():
			for pt in paths:
				var pn := 0
				for sid in pt:
					var id := int(sid)
					if occupies_slot(id) and not target.skill_ids.has(id):
						pn += 1
				if pn > max_need:
					max_need = pn
		else:
			for sid in slot_sids:
				if not target.skill_ids.has(sid):
					max_need = 1
					break
		if max_need == 0:
			var any_sealed := slot_sids.any(func(id): return is_sealed(target, id, s))
			var msg0 := "已学会此秘籍（已封印），请在技能页启封，启封后生效" if any_sealed else "已经学会这本秘籍"
			return ("%s：%s" % [target.display_name(), msg0]) if fixed_actor > 0 else msg0
		# 非固定角色且每条分支只学 1 个技能的升星/多选一类 CE（精通 1~5★、小药丸、通用心法）：
		# 若当前生效格已有同组中任意一本，则为原地替换/升星，净增 0 格，放行
		var act := active_ids(target, s)
		if max_need == 1 and fixed_actor == 0:
			for sid in slot_sids:
				if act.has(sid):
					return ""
		var cap := limit(target, s)
		var used := act.size()
		if cap > 0 and used + max_need > cap:
			if max_need > 1:
				return "%s%s最多装备 %d 本秘籍（当前 %d / %d，本书需 %d 格），请先在技能页封印已有秘籍" % [_cap_prefix(s), who, cap, used, cap, max_need]
			return "%s%s最多装备 %d 本秘籍（当前 %d / %d），请先在技能页封印已有秘籍" % [_cap_prefix(s), who, cap, used, cap]
	return ""


## 供 item_scene._effective 调用：-1 不归秘籍格管、1 有效、0 无效（满格或已学）
static func item_effective(a, item: Dictionary, s: XState = null) -> int:
	if not on(s) or item.is_empty():
		return -1
	_ensure_index()
	var iid := int(item.get("id", 0))
	if _ignore_items.has(iid) or XPowerBooks.book_skill(item) > 0:
		return -1
	var managed := _conversion_items.has(iid)
	if not managed:
		for e in item.get("effects", []):
			if int(e.get("code", 0)) == 43 and occupies_slot(int(e.get("dataId", 0))):
				managed = true
				break
	if not managed and _ce_item_info.has(iid):
		for sid in _ce_item_info[iid].get("skills", []):
			if occupies_slot(int(sid)):
				managed = true
				break
	if not managed:
		return -1
	return 1 if item_learn_reason(a, item, s).is_empty() else 0


# ---- 封印、启封与免费自选 ----

static func seal_cost(s: XState, a = null) -> int:
	if not on(s):
		return 0
	if s == null:
		s = XState.current
	if a is XActor and has_free_pick(a, s):
		return 0
	var rules: Dictionary = data().get("rules", {})
	var units := float(rules.get("seal_field_units", 5))
	if XTianqiMoney.on(s):
		return XTianqiMoney.price(s, units)
	return int(rules.get("seal_fallback_gold", 1000))


static func seal(s: XState, a: XActor, skill_id: int) -> Dictionary:
	if not on(s):
		return {"ok": false, "reason": "秘籍格系统未开启"}
	if s == null:
		s = XState.current
	if a == null or not a.skill_ids.has(skill_id) or not occupies_slot(skill_id):
		return {"ok": false, "reason": "该技能不属于可封印的秘籍"}
	if is_sealed(a, skill_id, s):
		return {"ok": false, "reason": "该秘籍已经处于封印状态"}
	var cost := seal_cost(s, a)
	if cost > 0 and s.gold < cost:
		return {"ok": false, "reason": "精魂不足（封印需要 %s 精魂）" % XMenu._group(cost), "cost": cost}
	if cost > 0:
		s.gold -= cost
	var row := _write_actor(s, a.actor_id)
	var arr: Array = row["sealed"]
	if not arr.has(skill_id):
		arr.append(skill_id)
		arr.sort()
	_refresh_actor(a)
	return {"ok": true, "cost": cost, "free": cost == 0}


static func unseal(s: XState, a: XActor, skill_id: int) -> Dictionary:
	if not on(s):
		return {"ok": false, "reason": "秘籍格系统未开启"}
	if s == null:
		s = XState.current
	if a == null or not is_sealed(a, skill_id, s):
		return {"ok": false, "reason": "该秘籍未处于封印状态"}
	if gongfa_on(s):
		_ensure_index()
		var sp: Dictionary = _gongfa_by_skill.get(skill_id, {})
		if bool(sp.get("banned", false)):
			return {"ok": false, "reason": "此秘籍在天启篇已停用，不可启用、不生效"}
		var higher := _owned_school_higher_or_same(a, skill_id)
		if higher > 0:
			var hnm := str(XDB.rec("Skills", higher).get("name", ""))
			return {"ok": false, "reason": "已修习同系更高阶或同阶秘籍%s，无法启封低阶" % _quote_name(hnm)}
	var replaced := 0
	var replaced_lower := 0
	if is_conversion_skill(skill_id):
		replaced = active_conversion_id(a, s)
	elif gongfa_on(s) and _gongfa_by_skill.has(skill_id):
		replaced_lower = _active_school_lower_id(a, skill_id, s)
	if replaced == 0 and replaced_lower == 0:
		var cap := limit(a, s)
		var used := used_slots(a, s)
		if cap > 0 and used >= cap:
			return {"ok": false, "reason": "秘籍格已满（%d / %d），请先封印一本生效中的秘籍" % [used, cap]}
	var row := _write_actor(s, a.actor_id)
	var arr: Array = row["sealed"]
	arr.erase(skill_id)
	if replaced > 0 and not arr.has(replaced):
		arr.append(replaced)
	if replaced_lower > 0:
		a.skill_ids.erase(replaced_lower)
		arr.erase(replaced_lower)
	arr.sort()
	_refresh_actor(a)
	return {"ok": true, "replaced": replaced if replaced > 0 else replaced_lower}


static func finish_free_pick(s: XState, a: XActor) -> void:
	if not on(s) or a == null:
		return
	if s == null:
		s = XState.current
	var sec = XTianqiSave.peek(s, SECTION)
	if not (sec is Dictionary):
		return
	var actors = sec.get("actors")
	if not (actors is Dictionary):
		return
	var row = actors.get(str(a.actor_id))
	if row is Dictionary:
		row["free_pick"] = false


## 进入战斗时自动结束全员旧存档免费封印期（不能囤着跨场永久免单；T446 P2-1）
static func on_battle_start(s: XState) -> void:
	if not on(s) or s == null:
		return
	var sec = XTianqiSave.peek(s, SECTION)
	if not (sec is Dictionary):
		return
	var actors = sec.get("actors")
	if not (actors is Dictionary):
		return
	for k in actors.keys():
		var row = actors[k]
		if row is Dictionary and bool(row.get("free_pick", false)):
			row["free_pick"] = false


static func _refresh_actor(a: XActor) -> void:
	a.read_touch()
	a.param_mark_dirty()
	a.refresh_passive()
	a.refresh_resources()


## 按当前存档格数上限收敛全员超格秘籍（老存档迁移与换到低难度共用：不没收、多出的自动进已封，首次迁移授予免费封印期）
static func enforce_caps(s: XState) -> void:
	if not on(s) or s == null:
		return
	for a in s.actors.values():
		if not (a is XActor):
			continue
		var cap := limit(a, s)
		if cap <= 0:
			continue
		var act := active_ids(a, s)
		if act.size() <= cap:
			continue
		var row := _write_actor(s, a.actor_id)
		var sealed: Array = row["sealed"]
		var overflow := act.slice(cap)
		for sid in overflow:
			if not sealed.has(sid):
				sealed.append(sid)
		sealed.sort()
		# 首次迁移才授予免费封印期，避免后续再次超格或反复读档重复赠送（T446 P2-1）
		if not bool(row.get("migrated", false)):
			row["migrated"] = true
			row["free_pick"] = true
		_refresh_actor(a)


# ---- 老存档迁移／降难度收敛（XTianqiSave.after_load 调用，幂等）----

static func migrate_after_load(s: XState) -> void:
	if not on(s) or not XTianqiSave.ENABLED or s == null:
		return
	# 1) 清理已有 secrets 节中已经不在 skill_ids 或不再占格的脏 ID
	var existing = XTianqiSave.peek(s, SECTION)
	if existing is Dictionary:
		fill(existing)
		var actors_map: Dictionary = existing.get("actors", {})
		for k in actors_map.keys():
			var aid := int(k)
			var a: XActor = s.actors.get(aid)
			if a == null:
				continue
			var row: Dictionary = actors_map[k]
			var kept: Array[int] = []
			for sid in row.get("sealed", []):
				var id := int(sid)
				if a.skill_ids.has(id) and occupies_slot(id) and not kept.has(id):
					kept.append(id)
			kept.sort()
			row["sealed"] = kept
	# 1.5) T013-1c：同门功法合并去重（老存档同时有上/下篇时，只保留最高重、遗忘同门低重）
	if gongfa_on(s):
		for a in s.actors.values():
			if a is XActor:
				_dedup_actor_schools(a, s)
	# 2) 检查每名角色是否超格（老存档迁移或换低难度均走同一套超量封印，不丢书）
	enforce_caps(s)


# ---- UI 辅助（供 skill_scene.gd / skin_skill_page.gd 调用，发行空壳零外泄）----

## 该技能分类页是否展示秘籍格（功法 6、被动 4）
static func is_secret_stype(stype: int) -> bool:
	if not on():
		return false
	_ensure_index()
	return _slot_stypes.has(stype)


## 某角色在指定技能分类下的已封秘籍视图数组（附加 _tq_sealed = true，不污染 XDB 原表）
static func sealed_entries_for_stype(a: XActor, stype: int, s: XState = null) -> Array:
	if not on(s) or a == null:
		return []
	var out := []
	for sid in sealed_ids(a, s):
		var rec := XDB.rec("Skills", sid)
		if rec.is_empty() or int(rec.get("stypeId", 0)) != stype:
			continue
		var view := rec.duplicate()
		view["_tq_sealed"] = true
		out.append(view)
	return out


static func is_entry_sealed(sk: Dictionary) -> bool:
	return bool(sk.get("_tq_sealed", false))


static func is_entry_manageable(a: XActor, sk: Dictionary, s: XState = null) -> bool:
	if not on(s) or a == null or sk.is_empty():
		return false
	if is_entry_sealed(sk):
		return true
	var sid := int(sk.get("id", 0))
	return sid > 0 and a.skill_ids.has(sid) and occupies_slot(sid)


## 状态栏／列表顶标题用的秘籍格概要（如「秘籍格 3 / 6」「秘籍格 5 / 5（炼狱 +2，已封 1）」或「秘籍格 3 / 3（已封 2） · 旧档补偿：免费封印中」）
static func ui_slot_text(a: XActor, s: XState = null) -> String:
	if not on(s) or a == null:
		return ""
	if s == null:
		s = XState.current
	var used := used_slots(a, s)
	var cap := limit(a, s)
	var sn := sealed_ids(a, s).size()
	var free := has_free_pick(a, s)
	var bonus := difficulty_bonus(s)
	var dname := difficulty_name(s) if (bonus > 0 and not free) else ""
	var base := "秘籍格 %d / %d" % [used, cap]
	var notes: Array[String] = []
	if bonus > 0 and dname != "":
		notes.append("%s +%d" % [dname, bonus])
	if sn > 0:
		notes.append("已封 %d" % sn)
	if not notes.is_empty():
		base += "（%s）" % "，".join(notes)
	if free:
		base += " · 旧档补偿：免费封印中"
	return base


static func ui_list_title(base_title: String, a: XActor, stype: int, s: XState = null) -> String:
	if not on(s) or a == null or not is_secret_stype(stype):
		return base_title
	return "%s · %s" % [base_title, ui_slot_text(a, s)]


## 列表行右侧标签（新旧两套皮肤统一叫「占格 / 已封」；返回 {} 表示非秘籍）
static func ui_row_meta(a: XActor, sk: Dictionary, s: XState = null) -> Dictionary:
	if not on(s) or a == null or sk.is_empty():
		return {}
	if is_entry_sealed(sk):
		return {
			"sealed": true,
			"badge": "已封",
			"old_badge": "[已封]",
		}
	var sid := int(sk.get("id", 0))
	if sid > 0 and a.skill_ids.has(sid) and occupies_slot(sid):
		return {
			"sealed": false,
			"badge": "占格",
			"old_badge": "[占格]",
		}
	return {}


## 底部按键提示栏「确定」动作名（供新皮肤 skin_skill_page.gd 底栏使用，不在行尾挤技能名）
static func ui_accept_hint(a: XActor, sk: Dictionary, s: XState = null) -> String:
	if not on(s) or a == null or sk.is_empty() or not is_entry_manageable(a, sk, s):
		return ""
	if is_entry_sealed(sk):
		return "启封"
	return "免费封印" if has_free_pick(a, s) else "封印"


## 详情牌按钮与副标题补充（供新皮肤 skin_skill_page.gd 用）
static func ui_card_actions(s: XState, a: XActor, sk: Dictionary) -> Dictionary:
	if not on(s) or a == null or sk.is_empty() or not is_entry_manageable(a, sk, s):
		return {}
	if s == null:
		s = XState.current
	var free := has_free_pick(a, s)
	var btns: Array = []
	var tag := ""
	if is_entry_sealed(sk):
		var sid := int(sk.get("id", 0))
		var can_up := (is_conversion_skill(sid) and active_conversion_id(a, s) > 0) or used_slots(a, s) < limit(a, s)
		tag = "已封印 · 不生效"
		btns.append({"text": "启封秘籍", "action": "unseal", "disabled": not can_up})
	else:
		var cost := seal_cost(s, a)
		var bonus := difficulty_bonus(s)
		var dname := difficulty_name(s) if bonus > 0 else ""
		if bonus > 0 and dname != "":
			tag = "占秘籍格（%d / %d，%s +%d）" % [used_slots(a, s), limit(a, s), dname, bonus]
		else:
			tag = "占秘籍格（%d / %d）" % [used_slots(a, s), limit(a, s)]
		if cost == 0:
			btns.append({"text": "免费封印", "action": "seal", "disabled": false})
		else:
			btns.append({"text": "封印（%s 精魂）" % XMenu._group(cost), "action": "seal", "disabled": s.gold < cost})
	if free:
		btns.append({"text": "结束免费期", "action": "finish_free", "disabled": false})
	return {"tag": tag, "buttons": btns}


static func _quote_name(nm: String) -> String:
	return nm if nm.begins_with("《") else ("「%s」" % nm)


## 封印／启封确认弹窗文案（新旧两套皮肤共用）
static func ui_confirm_spec(s: XState, a: XActor, sk: Dictionary) -> Dictionary:
	if not on(s) or a == null or sk.is_empty() or not is_entry_manageable(a, sk, s):
		return {}
	if s == null:
		s = XState.current
	var nm := str(sk.get("name", ""))
	var qnm := _quote_name(nm)
	var sid := int(sk.get("id", 0))
	var free := has_free_pick(a, s)
	if is_entry_sealed(sk):
		var old_conv := active_conversion_id(a, s) if is_conversion_skill(sid) else 0
		var body := ""
		var can_up := true
		if old_conv > 0:
			var old_nm := str(XDB.rec("Skills", old_conv).get("name", ""))
			body = "启封后将与当前生效的%s互换（不额外占格），被动立即生效。" % _quote_name(old_nm)
		elif used_slots(a, s) >= limit(a, s):
			can_up = false
			body = "当前秘籍格已满（%d / %d），请先封印一本生效中的秘籍。" % [used_slots(a, s), limit(a, s)]
		else:
			body = "启封后将占用 1 个秘籍格（当前 %d / %d），被动立即生效。" % [used_slots(a, s), limit(a, s)]
		var buttons: Array = [{"text": "确认启封", "disabled": not can_up, "action": "unseal"}]
		if free:
			buttons.append({"text": "结束免费期", "disabled": false, "action": "finish_free"})
		buttons.append({"text": "取消", "disabled": false, "action": "cancel"})
		return {"title": "启封%s？" % qnm, "body": body, "danger": false, "buttons": buttons, "skill_id": sid}
	var cost := seal_cost(s, a)
	var body2 := ""
	var can_seal := true
	if cost == 0:
		body2 = "旧存档超格补偿期间本次封印不收费。封印后被动立即失效，腾出 1 个秘籍格（书本不退还，可在已封列表重新启封）。点「结束免费期」、改完离开技能页或进入下一场战斗后免费期自动结束，之后封印要花精魂。"
	else:
		can_seal = s.gold >= cost
		body2 = "封印后被动立即失效，腾出 1 个秘籍格，书本不退还。需花费 %s 精魂（当前 %s）。" % [XMenu._group(cost), XMenu._group(s.gold)]
	var buttons2: Array = [{"text": "确认封印", "disabled": not can_seal, "action": "seal"}]
	if free:
		buttons2.append({"text": "结束免费期", "disabled": false, "action": "finish_free"})
	buttons2.append({"text": "取消", "disabled": false, "action": "cancel"})
	return {"title": "封印%s？" % qnm, "body": body2, "danger": true, "buttons": buttons2, "skill_id": sid}


static func ui_gold_currency(s: XState = null) -> Array:
	if not on(s):
		return []
	if s == null:
		s = XState.current
	return [["精魂", XMenu._group(s.gold)]]


static func ui_action_toast(action: String, sk_name: String, res: Dictionary) -> String:
	if not on():
		return ""
	if not bool(res.get("ok", false)):
		return str(res.get("reason", "操作失败"))
	var qnm := _quote_name(sk_name)
	match action:
		"seal":
			if bool(res.get("free", false)):
				return "已免费封印%s，腾出 1 个秘籍格" % qnm
			return "已封印%s（消耗 %s 精魂），腾出 1 个秘籍格" % [qnm, XMenu._group(int(res.get("cost", 0)))]
		"unseal":
			return "已启封%s，被动已生效" % qnm
		"finish_free":
			return "已结束旧存档免费封印期，后续封印将收取精魂"
	return ""


## 技能页执行封印／启封／完成自选（含音效与提示，成功返回 true；关着或西游档恒返回 false）
static func ui_exec_action(s: XState, a: XActor, action: String, skill_id: int) -> bool:
	if not on(s):
		return false
	if s == null:
		s = XState.current
	var sk_name := str(XDB.rec("Skills", skill_id).get("name", "")) if skill_id > 0 else ""
	if action == "finish_free":
		finish_free_pick(s, a)
		XSound.system(1)
		XToast.show_text(ui_action_toast("finish_free", sk_name, {"ok": true}), true)
		return true
	var res := seal(s, a, skill_id) if action == "seal" else unseal(s, a, skill_id)
	if not bool(res.get("ok", false)):
		XSound.system(3)
		XToast.show_text(ui_action_toast(action, sk_name, res), true)
		return false
	XSound.system(1)
	XToast.show_text(ui_action_toast(action, sk_name, res), true)
	return true


# ==============================================================================
# T013-1c：功法 50 本重标分门三重（补水风、同门互顶）、行字诀首回合提前、
#          状态 1656 重标、封禁禁掉与人族首领 EV054 货架重整（含 K8 丁一插槽）
# ==============================================================================

# ---- 同门查询与互顶 ----

static func school_of(skill_id: int) -> String:
	if skill_id <= 0:
		return ""
	_ensure_index()
	var sp: Dictionary = _gongfa_by_skill.get(skill_id, {})
	return str(sp.get("school", ""))


static func school_tier(skill_id: int) -> int:
	if skill_id <= 0:
		return 0
	_ensure_index()
	var sp: Dictionary = _gongfa_by_skill.get(skill_id, {})
	return int(sp.get("tier", 0))


static func is_banned_skill(skill_id: int, s: XState = null) -> bool:
	if not gongfa_on(s) or skill_id <= 0:
		return false
	_ensure_index()
	return bool(_gongfa_by_skill.get(skill_id, {}).get("banned", false))


static func is_banned_item(item_id: int, s: XState = null) -> bool:
	if not gongfa_on(s) or item_id <= 0:
		return false
	_ensure_index()
	return _banned_items.has(item_id)


static func _owned_school_higher_or_same(a: XActor, skill_id: int) -> int:
	var sc := school_of(skill_id)
	if sc == "":
		return 0
	var cur_t := school_tier(skill_id)
	for sid in _school_skills.get(sc, []):
		var id := int(sid)
		if id != skill_id and a.skill_ids.has(id) and school_tier(id) >= cur_t:
			return id
	return 0


static func _active_school_lower_id(a: XActor, skill_id: int, s: XState) -> int:
	var sc := school_of(skill_id)
	if sc == "":
		return 0
	var cur_t := school_tier(skill_id)
	for sid in active_ids(a, s):
		if sid != skill_id and school_of(sid) == sc and school_tier(sid) < cur_t:
			return sid
	return 0


## XActor.learn_skill 末尾调用：学到同门更高重时，遗忘并清理同门更低重（只占 1 格）
static func learned_skill(a, skill_id: int, s: XState = null) -> void:
	if not gongfa_on(s) or not (a is XActor):
		return
	if s == null:
		s = XState.current
	_ensure_index()
	if not _gongfa_by_skill.has(skill_id):
		return
	var sc := school_of(skill_id)
	var cur_t := school_tier(skill_id)
	if sc == "":
		return
	var removed := false
	for sid in _school_skills.get(sc, []):
		var id := int(sid)
		if id == skill_id or not a.skill_ids.has(id):
			continue
		if school_tier(id) <= cur_t:
			a.skill_ids.erase(id)
			var row := _peek_actor(s, a.actor_id)
			if not row.is_empty():
				var sealed: Array = row.get("sealed", [])
				if sealed.has(id):
					sealed.erase(id)
			removed = true
	if removed:
		_refresh_actor(a)


## 老存档同门去重合并：同一门同时有多本时只保留最高重（优先保留生效态的最高重），清理低重
static func _dedup_actor_schools(a: XActor, s: XState) -> void:
	_ensure_index()
	var by_sc := {}
	for sid in a.skill_ids:
		var id := int(sid)
		var sc := school_of(id)
		if sc == "":
			continue
		if not by_sc.has(sc):
			by_sc[sc] = []
		by_sc[sc].append(id)
	var changed := false
	for sc in by_sc:
		var list: Array = by_sc[sc]
		if list.size() <= 1:
			continue
		var best_id := int(list[0])
		var best_t := school_tier(best_id)
		var best_act := not is_sealed(a, best_id, s)
		for i in range(1, list.size()):
			var cid := int(list[i])
			var ct := school_tier(cid)
			var cact := not is_sealed(a, cid, s)
			if ct > best_t or (ct == best_t and ((cact and not best_act) or (cact == best_act and cid > best_id))):
				best_id = cid
				best_t = ct
				best_act = cact
		var any_active := list.any(func(x): return not is_sealed(a, int(x), s))
		var row := _peek_actor(s, a.actor_id)
		var sealed: Array = row.get("sealed", []) if not row.is_empty() else []
		for cid in list:
			var id := int(cid)
			if id == best_id:
				continue
			a.skill_ids.erase(id)
			if sealed.has(id):
				sealed.erase(id)
			changed = true
		if any_active and sealed.has(best_id):
			sealed.erase(best_id)
			changed = true
	if changed:
		_refresh_actor(a)


# ---- 表外新功法与运行期视图改写（XDB.rec 挂点）----

static func has_new(table: String, id: int) -> bool:
	if not gongfa_on():
		return false
	_ensure_index()
	if table == "Items":
		return _gongfa_by_item.has(id) and int(_gongfa_by_item[id].get("template_item", 0)) > 0
	if table == "Skills":
		return _gongfa_by_skill.has(id) and int(_gongfa_by_skill[id].get("template_skill", 0)) > 0
	return false


static func new_rec(table: String, id: int, base_table: Array) -> Dictionary:
	if not gongfa_on():
		return {}
	_ensure_index()
	var ckey := "new:%s:%d" % [table, id]
	if _view_cache.has(ckey):
		return _view_cache[ckey]
	if table == "Items" and _gongfa_by_item.has(id):
		var sp: Dictionary = _gongfa_by_item[id]
		var tpl_id := int(sp.get("template_item", 0))
		if tpl_id <= 0 or tpl_id >= base_table.size() or not (base_table[tpl_id] is Dictionary):
			return {}
		var out := _build_item_view(base_table[tpl_id], sp)
		_view_cache[ckey] = out
		return out
	if table == "Skills" and _gongfa_by_skill.has(id):
		var sp2: Dictionary = _gongfa_by_skill[id]
		var tpl_sid := int(sp2.get("template_skill", 0))
		if tpl_sid <= 0 or tpl_sid >= base_table.size() or not (base_table[tpl_sid] is Dictionary):
			return {}
		var out2 := _build_skill_view(base_table[tpl_sid], sp2)
		_view_cache[ckey] = out2
		return out2
	return {}


static func touches_rec(table: String, id: int) -> bool:
	if not gongfa_on():
		return false
	_ensure_index()
	match table:
		"Items":
			return _gongfa_by_item.has(id)
		"Skills":
			return _gongfa_by_skill.has(id)
		"States":
			return _state_specs.has(id)
	return false


static func rec_view(table: String, id: int, base: Dictionary) -> Dictionary:
	if not gongfa_on() or base.is_empty():
		return base
	_ensure_index()
	var ckey := "view:%s:%d" % [table, id]
	if _view_cache.has(ckey):
		return _view_cache[ckey]
	var out: Dictionary = base
	match table:
		"Items":
			if _gongfa_by_item.has(id):
				out = _build_item_view(base, _gongfa_by_item[id])
		"Skills":
			if _gongfa_by_skill.has(id):
				out = _build_skill_view(base, _gongfa_by_skill[id])
		"States":
			if _state_specs.has(id):
				out = _build_state_view(base, _state_specs[id])
	_view_cache[ckey] = out
	return out


static func _tier_quality(sp: Dictionary) -> int:
	if bool(sp.get("banned", false)):
		return 1
	match int(sp.get("tier", 1)):
		1:
			return 5
		2:
			return 7
		_:
			return 9


static func _build_skill_view(base: Dictionary, sp: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var sid := int(sp.get("skill", base.get("id", 0)))
	var q := _tier_quality(sp)
	out["id"] = sid
	out["stypeId"] = 6
	out["name"] = str(sp.get("name", base.get("name", "")))
	out["description"] = str(sp.get("description", base.get("description", "")))
	out["traits"] = []
	var lines: Array[String] = ["<Hide in Battle>", "<quality:%d>" % q, "<ici:%d>" % q]
	for tg in sp.get("tags", []):
		lines.append("<%s>" % str(tg))
	var eff := str(sp.get("effect_text", ""))
	if eff != "":
		lines.append("<pos=APs text=\\c[1]效果:%s size=18 color=rgba(255,255,255,1) line=false align=0>" % eff)
	var obtain := str(sp.get("obtain_text", ""))
	if obtain != "":
		lines.append("<pos=APs text=\\c[1]%s size=18 color=rgba(255,255,255,1) line=false align=0>" % obtain)
	var note := "\n".join(lines)
	out["note"] = note
	out["meta"] = XTianqiSkills.parse_meta(note)
	return out


static func _build_item_view(base: Dictionary, sp: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var iid := int(sp.get("item", base.get("id", 0)))
	var sid := int(sp.get("skill", 0))
	var q := _tier_quality(sp)
	var nm := str(sp.get("item_name", sp.get("name", base.get("name", ""))))
	var sk_nm := str(sp.get("name", nm))
	var is_banned := bool(sp.get("banned", false))
	out["id"] = iid
	out["name"] = nm
	out["description"] = str(sp.get("description", "")) if is_banned else ""
	out["price"] = 0
	out["effects"] = [{"code": 43, "dataId": sid, "value1": 1.0, "value2": 0.0}]
	var lines: Array[String] = ["<quality:%d>" % q, "<ici:%d>" % q]
	var bp := int(sp.get("buy_price", 0))
	if bp > 0:
		lines.append("<item 2530 Buy Price: %d>" % bp)
	var eff := str(sp.get("effect_text", ""))
	if is_banned:
		lines.append("<pos=APs text=\\c[2]%s size=18 color=rgba(255,255,255,1) line=false align=0>" % eff)
	else:
		lines.append("<pos=APs text=\\c[1]用法:使用后学会秘籍%s size=18 color=rgba(255,255,255,1) line=false align=0>" % _quote_name(sk_nm))
		if eff != "":
			lines.append("<pos=APs text=\\c[1]效果:%s size=18 color=rgba(255,255,255,1) line=false align=0>" % eff)
		var obtain := str(sp.get("obtain_text", ""))
		if obtain != "":
			lines.append("<pos=APs text=\\c[1]%s size=18 color=rgba(255,255,255,1) line=false align=0>" % obtain)
	var note := "\n".join(lines)
	out["note"] = note
	out["meta"] = XTianqiSkills.parse_meta(note)
	out["_tq_price_ver"] = "gf1"
	return out


static func _build_state_view(base: Dictionary, sp: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	out["name"] = str(sp.get("name", base.get("name", "")))
	var turns := int(sp.get("turns", 2))
	out["minTurns"] = turns
	out["maxTurns"] = turns
	var rate := 1.0 + float(sp.get("stat_rate_pct", 5)) / 100.0
	var traits := []
	for i in range(8):
		traits.append({"code": 21, "dataId": i, "value": rate})
	out["traits"] = traits
	var fd := int(sp.get("final_dmg_pct", 8))
	var sn := str(sp.get("state_note", "全属性+%d%%，最终伤害+%d%%" % [int(sp.get("stat_rate_pct", 5)), fd]))
	var note := "<BuffType:祝福>\n<StateNote>\n%s\n</StateNote>\n<passiveHarmRi:%d>" % [sn, fd]
	out["note"] = note
	out["meta"] = XTianqiSkills.parse_meta(note)
	return out


# ---- 寻宝决掉率直通（供 XTianqiDrop.rework_value 调用，不被 tier() 拍平）----

static func gongfa_drop_value(skill_id: int) -> float:
	if not gongfa_on() or skill_id <= 0:
		return NAN
	_ensure_index()
	var sp: Dictionary = _gongfa_by_skill.get(skill_id, {})
	if sp.has("drop_pct"):
		return float(sp.drop_pct)
	return NAN


# ---- 封禁书掉落过滤（battle_logic.drop_chances 末尾调用）----

static func filter_drop_rows(s, rows: Array) -> Array:
	if not gongfa_on(s) or rows.is_empty():
		return rows
	_ensure_index()
	if _banned_items.is_empty():
		return rows
	return rows.filter(func(r): return not (int(r.get("kind", 0)) == 1 and _banned_items.has(int(r.get("id", 0)))))


# ---- 九秘:行字诀首回合行动提前（battle_logic._make_action_orders 首回合调用）----

## 0=无；1=简篇（首回合速度 +50% 且至少提前 2 位）；2=全篇（首回合最先行动）
static func first_turn_mode(a, s: XState = null) -> int:
	if not gongfa_on(s) or not (a is XActor):
		return 0
	_ensure_index()
	var best := 0
	for sid in active_ids(a, s):
		var m := int(_gongfa_by_skill.get(sid, {}).get("first_turn_mode", 0))
		if m > best:
			best = m
	return best


## 首回合对 current_order 就地重排（偷袭时不生效；第 2 回合不调用自动恢复）
static func apply_first_turn_advance(logic, order: Array) -> void:
	if logic == null or order.size() <= 1:
		return
	var s: XState = logic.state if "state" in logic else XState.current
	if not gongfa_on(s) or bool(logic.surprise):
		return
	var top_list := []
	var boost_list := []  # [[orig_idx, battler]]
	for i in range(order.size()):
		var b = order[i]
		if b is XActor and logic.can_move(b):
			var m := first_turn_mode(b, s)
			if m >= 2:
				top_list.append(b)
			elif m == 1:
				boost_list.append([i, b])
	if top_list.is_empty() and boost_list.is_empty():
		return
	# 1) 全篇（mode 2）：抽出按原相对顺序置顶
	for b in top_list:
		order.erase(b)
	for i in range(top_list.size() - 1, -1, -1):
		order.insert(0, top_list[i])
	var floor_idx := top_list.size()
	# 2) 简篇（mode 1）：等效速度 +50%，并保证至少比原顺位提前 2 位（不越过全篇持有者）
	for entry in boost_list:
		var orig_idx := int(entry[0])
		var b = entry[1]
		var cur_idx := order.find(b)
		if cur_idx < 0:
			continue
		var sp := float(logic._speed.get(b, float(b.agi))) * 1.5
		logic._speed[b] = sp
		var target_idx := cur_idx
		while target_idx > floor_idx:
			var prev = order[target_idx - 1]
			var prev_sp := float(logic._speed.get(prev, float(prev.agi)))
			if sp > prev_sp:
				target_idx -= 1
			else:
				break
		var min_target := maxi(floor_idx, mini(orig_idx, cur_idx) - 2)
		if target_idx > min_target:
			target_idx = min_target
		if target_idx < cur_idx:
			order.remove_at(cur_idx)
			order.insert(target_idx, b)


# ---- 人族首领 EV054 货架重整＋K8 丁一插槽契约（T441 第四节）----

static func ev54_intercepts(s, map_id: int, event_id: int) -> bool:
	return map_id == EV54_MAP and event_id == EV54_EVENT and ev54_on(s) and s != null and not s.switch(EV54_HIDE_SWITCH)


static func ev54_top_floor(s: XState) -> int:
	return maxi(1, int(s.variable(20))) if s != null else 1


## 拼装并过滤 EV054 指定页签货单（必经 XTianqiSect.ev54_extra_goods 与完整商店滤链，供运行与专项共用）
static func ev54_tab_goods(s: XState, tab: String) -> Array:
	if not ev54_on(s) or s == null:
		return []
	var cfg: Dictionary = data().get("ev54_shop", {})
	var tabs: Dictionary = cfg.get("tabs", {})
	var top_floor := ev54_top_floor(s)
	var goods: Array = []
	if tabs.has(tab):
		var tinfo: Dictionary = tabs[tab]
		var mf := int(tinfo.get("min_floor", 1))
		if top_floor < mf:
			return []
		for g in tinfo.get("goods", []):
			goods.append((g as Array).duplicate())
		for blk in tinfo.get("extra_by_floor", []):
			if blk is Dictionary and top_floor >= int(blk.get("min_floor", 1)):
				for g in blk.get("goods", []):
					goods.append((g as Array).duplicate())
	# K8 丁一显式插槽（按楼层与页签追加货品，不依赖原版商品号猜页）
	var extra := XTianqiSect.ev54_extra_goods(s, tab, top_floor)
	for g in extra:
		if g is Array and g.size() >= 2:
			var dup := goods.any(func(x): return int(x[0]) == int(g[0]) and int(x[1]) == int(g[1]))
			if not dup:
				var row: Array = (g as Array).duplicate()
				while row.size() < 4:
					row.append(0)
				goods.append(row)
	# 必经完整商店滤链（含 XTianqiSect.shop_goods(s, 4, 54, goods)）
	goods = XTianqiTrim.shop_goods(s, EV54_MAP, EV54_EVENT, goods)
	goods = XTianqiSect.shop_goods(s, EV54_MAP, EV54_EVENT, goods)
	goods = XTianqiTrumpet.shop_goods(s, goods)
	goods = XTianqiElements.shop_goods(s, EV54_MAP, goods)
	return goods


## 人族首领主菜单：[[显示文字, 动作]]（无「购买丹药」空选项；若 K8 丁一在 "abyss" 页返回货品则自动露出「深渊秘传」）
static func ev54_menu(s: XState) -> Array:
	if not ev54_on(s) or s == null:
		return []
	var top_floor := ev54_top_floor(s)
	var out := [
		["修习功法", ["gongfa"]],
		["法宝与专武" if top_floor >= 13 else "法宝与专武（第 13 层解锁）", ["tab", "fabao"]],
		["神武装备" if top_floor >= 21 else "神武装备（第 21 层解锁）", ["tab", "divine"]],
	]
	if not ev54_tab_goods(s, "abyss").is_empty():
		out.append(["深渊秘传", ["tab", "abyss"]])
	out.append(["离开", []])
	return out


static func ev54_gongfa_menu(s: XState) -> Array:
	if not ev54_on(s) or s == null:
		return []
	var top_floor := ev54_top_floor(s)
	var out := [
		["入门功法（第 1 层）", ["tab", "gongfa_t1"]],
		["小成功法（第 13 层）" if top_floor >= 13 else "小成功法（第 13 层解锁）", ["tab", "gongfa_t2"]],
		["大成功法（第 21 层）" if top_floor >= 21 else "大成功法（第 21 层解锁）", ["tab", "gongfa_t3"]],
	]
	if not ev54_tab_goods(s, "abyss").is_empty():
		out.append(["深渊秘传", ["tab", "abyss"]])
	out.append(["返回", []])
	return out


static func run_ev54(host, s: XState) -> void:
	if not ev54_on(s) or host == null or s == null:
		return
	var cfg: Dictionary = data().get("ev54_shop", {})
	var face_arr: Array = cfg.get("face", ["Package2", 4])
	var face := str(face_arr[0]) if face_arr.size() >= 1 else "Package2"
	var face_idx := int(face_arr[1]) if face_arr.size() >= 2 else 4
	var speaker := str(cfg.get("speaker", "人族首领"))
	var greeting := str(cfg.get("greeting", "以人道意志碎片换取传承功法与法宝吧。"))
	var tabs: Dictionary = cfg.get("tabs", {})
	while true:
		var opts := ev54_menu(s)
		var labels := opts.map(func(o): return str(o[0]))
		var pick: int = await host.show_text_with_choices(face, face_idx, ["\\n<%s>%s" % [speaker, greeting]], labels, labels.size() - 1)
		if pick < 0 or pick >= opts.size():
			return
		var act: Array = opts[pick][1]
		if act.is_empty():
			return
		if str(act[0]) == "gongfa":
			await _run_ev54_gongfa(host, s, face, face_idx, speaker, tabs)
		elif str(act[0]) == "tab":
			await _open_ev54_tab(host, s, str(act[1]), face, face_idx, speaker, tabs)


static func _run_ev54_gongfa(host, s: XState, face: String, face_idx: int, speaker: String, tabs: Dictionary) -> void:
	while true:
		var opts := ev54_gongfa_menu(s)
		var labels := opts.map(func(o): return str(o[0]))
		var pick: int = await host.show_text_with_choices(face, face_idx, ["\\n<%s>功法分入门、小成、大成三重，同系高阶替换低阶，只占 1 个秘籍格。" % speaker], labels, labels.size() - 1)
		if pick < 0 or pick >= opts.size():
			return
		var act: Array = opts[pick][1]
		if act.is_empty():
			return
		if str(act[0]) == "tab":
			await _open_ev54_tab(host, s, str(act[1]), face, face_idx, speaker, tabs)


static func _open_ev54_tab(host, s: XState, tab: String, face: String, face_idx: int, speaker: String, tabs: Dictionary) -> void:
	var goods := ev54_tab_goods(s, tab)
	if goods.is_empty():
		var lock_msg := str(tabs.get(tab, {}).get("lock_text", "继续探索神魔之塔，即可解锁此货架。"))
		await host.show_text(face, face_idx, ["\\n<%s>%s" % [speaker, lock_msg]])
		return
	XShopStock.set_context(EV54_MAP, EV54_EVENT)
	XShopStock.apply_group(s, EV54_STOCK_GROUP)
	await host.open_shop(goods, false)
	s.shop_pending = ""
	XShopStock.shop_context = {}
