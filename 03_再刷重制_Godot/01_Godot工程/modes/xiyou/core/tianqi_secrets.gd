class_name XTianqiSecrets
extends RefCounted
## 【小A·天启篇·未经审查】秘籍格核心系统（T446 / T013-1b；设计依据：天启篇_原版养成线重做方案_v0.3 第三节第 8 条、D274）。
##
## 规则：
## - 格数上限读 balance_table.json tiers.<档位>.secret_cap（弱者 6、强者 4、超强者 3）。
## - 占格：功法（stype=6）、通用被动书（code 43 ＋ CE code 44，stype=4）、元素转换书（老 5068~5075 ＋ 新 11201~11205）、
##   深渊六式被动（6192~6203 / 6206~6211）与止戈/天怒（6185 / 6204）。
## - 不占格：号卷（XTianqiTrumpet / <CodexPower>）、抽奖被动（stype=5）、主动书（stype 1/2/3 等）、
##   角色自带/职业/进阶被动、27 本 Boss 血脉（D274④）、58 张外观变身卡（6801~6858）、种族技能、万灵增元丹被动。
## - 元素转换书：首次学占 1 格；当前生效格里已有另一门转换书时原地替换，不要求先空出新格。
## - 花场钱封印：腾出 1 格、不退书、被动立即失效（_skill_records 滤掉已封，不删 skill_ids）；封印记录在 flags.tianqi.secrets。
## - 老存档迁移：读档后若某角色生效占格秘籍超出上限，不没收，超出部分自动移入已封并授予该角色一次免费自选生效格（free_pick）。
## - 回退开关：ENABLED = false 完整回退到旧临时截断；西游档（XTianqi.active == false）零变化、零存档字段。
##
## 玩家可见文字（待小A/cc Sonnet 审）全部集中在本模块 ui_* / learn_reason / seal / unseal 中，
## 发行空壳替换本脚本后西游发行包零外泄。

static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/secret_books.json"
const SECTION := "secrets"

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


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) and not data().is_empty()


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


## 角色秘籍格上限（读 balance_table.json：弱 6 / 强 4 / 超 3）
static func limit(a) -> int:
	if not (a is XActor):
		return 0
	return XTianqiBalance.secret_cap(XTier.tier_of(a))


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
	if a.skill_ids.has(skill_id):
		if is_sealed(a, skill_id, s):
			return "已学会此秘籍（已封印），请在技能页启封，启封后生效"
		return "已经学会这本秘籍"
	# 元素转换书：当前生效格已有另一门转换书 → 原地替换，不占新格
	if is_conversion_skill(skill_id) and active_conversion_id(a, s) > 0:
		return ""
	var cap := limit(a)
	var used := used_slots(a, s)
	if cap > 0 and used >= cap:
		return "%s最多装备 %d 本秘籍（当前 %d / %d），请先在技能页封印已有秘籍" % [XTier.tier_of(a), cap, used, cap]
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
		var cap43 := limit(target)
		var used43 := used_slots(target, s)
		if cap43 > 0 and used43 + need43 > cap43:
			return "%s最多装备 %d 本秘籍（当前 %d / %d，本书需 %d 格），请先在技能页封印已有秘籍" % [XTier.tier_of(target), cap43, used43, cap43, need43]
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
		var who := "%s（%s）" % [target.display_name(), XTier.tier_of(target)] if fixed_actor > 0 else XTier.tier_of(target)
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
		var cap := limit(target)
		var used := act.size()
		if cap > 0 and used + max_need > cap:
			if max_need > 1:
				return "%s最多装备 %d 本秘籍（当前 %d / %d，本书需 %d 格），请先在技能页封印已有秘籍" % [who, cap, used, cap, max_need]
			return "%s最多装备 %d 本秘籍（当前 %d / %d），请先在技能页封印已有秘籍" % [who, cap, used, cap]
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
	var replaced := 0
	if is_conversion_skill(skill_id):
		replaced = active_conversion_id(a, s)
	if replaced == 0:
		var cap := limit(a)
		var used := used_slots(a, s)
		if cap > 0 and used >= cap:
			return {"ok": false, "reason": "秘籍格已满（%d / %d），请先封印一本生效中的秘籍" % [used, cap]}
	var row := _write_actor(s, a.actor_id)
	var arr: Array = row["sealed"]
	arr.erase(skill_id)
	if replaced > 0 and not arr.has(replaced):
		arr.append(replaced)
	arr.sort()
	_refresh_actor(a)
	return {"ok": true, "replaced": replaced}


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


# ---- 老存档迁移（XTianqiSave.after_load 调用，幂等）----

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
	# 2) 检查每名角色是否超格（老存档不没收，超出部分自动移入已封并授予一次免费自选）
	for a in s.actors.values():
		if not (a is XActor):
			continue
		var cap := limit(a)
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


## 状态栏／列表顶标题用的秘籍格概要（如「秘籍格 3 / 6」或「秘籍格 3 / 3（已封 2） · 旧档补偿：免费封印中」）
static func ui_slot_text(a: XActor, s: XState = null) -> String:
	if not on(s) or a == null:
		return ""
	var used := used_slots(a, s)
	var cap := limit(a)
	var sn := sealed_ids(a, s).size()
	var base := "秘籍格 %d / %d" % [used, cap]
	if sn > 0:
		base += "（已封 %d）" % sn
	if has_free_pick(a, s):
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
		var can_up := (is_conversion_skill(sid) and active_conversion_id(a, s) > 0) or used_slots(a, s) < limit(a)
		tag = "已封印 · 不生效"
		btns.append({"text": "启封秘籍", "action": "unseal", "disabled": not can_up})
	else:
		var cost := seal_cost(s, a)
		tag = "占秘籍格（%d / %d）" % [used_slots(a, s), limit(a)]
		if cost == 0:
			btns.append({"text": "免费封印", "action": "seal", "disabled": false})
		else:
			btns.append({"text": "封印（%s 精魂）" % XMenu._group(cost), "action": "seal", "disabled": s.gold < cost})
	if free:
		btns.append({"text": "结束免费期", "action": "finish_free", "disabled": false})
	return {"tag": tag, "buttons": btns}


## 封印／启封确认弹窗文案（新旧两套皮肤共用）
static func ui_confirm_spec(s: XState, a: XActor, sk: Dictionary) -> Dictionary:
	if not on(s) or a == null or sk.is_empty() or not is_entry_manageable(a, sk, s):
		return {}
	if s == null:
		s = XState.current
	var nm := str(sk.get("name", ""))
	var sid := int(sk.get("id", 0))
	var free := has_free_pick(a, s)
	if is_entry_sealed(sk):
		var old_conv := active_conversion_id(a, s) if is_conversion_skill(sid) else 0
		var body := ""
		var can_up := true
		if old_conv > 0:
			var old_nm := str(XDB.rec("Skills", old_conv).get("name", ""))
			body = "启封后将与当前生效的「%s」互换（不额外占格），被动立即生效。" % old_nm
		elif used_slots(a, s) >= limit(a):
			can_up = false
			body = "当前秘籍格已满（%d / %d），请先封印一本生效中的秘籍。" % [used_slots(a, s), limit(a)]
		else:
			body = "启封后将占用 1 个秘籍格（当前 %d / %d），被动立即生效。" % [used_slots(a, s), limit(a)]
		var buttons: Array = [{"text": "确认启封", "disabled": not can_up, "action": "unseal"}]
		if free:
			buttons.append({"text": "结束免费期", "disabled": false, "action": "finish_free"})
		buttons.append({"text": "取消", "disabled": false, "action": "cancel"})
		return {"title": "启封「%s」？" % nm, "body": body, "danger": false, "buttons": buttons, "skill_id": sid}
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
	return {"title": "封印「%s」？" % nm, "body": body2, "danger": true, "buttons": buttons2, "skill_id": sid}


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
	match action:
		"seal":
			if bool(res.get("free", false)):
				return "已免费封印「%s」，腾出 1 个秘籍格" % sk_name
			return "已封印「%s」（消耗 %s 精魂），腾出 1 个秘籍格" % [sk_name, XMenu._group(int(res.get("cost", 0)))]
		"unseal":
			return "已启封「%s」，被动已生效" % sk_name
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
