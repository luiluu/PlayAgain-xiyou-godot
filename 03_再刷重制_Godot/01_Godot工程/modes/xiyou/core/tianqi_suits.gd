class_name XTianqiSuits
extends RefCounted
## 【cc·T513·未经审查】天启篇套装同台上限（养成线二期 2A；私密设计仓《天启篇_原版养成线重做方案_v0.3》第三节第 3 条，
## Kyo 11-14 上午「原版套装照方案」已定；拆卡见 协作交接/派单/T513_二三期拆卡.md）。
## - 一人最多生效 CAP（2）套，七印套装也算在这两套里，件数多的优先。31 层后七印 5 件＋3 件一穿，原版套装自然退场。
## - 「单件就生效」的套装（所有档都只要 1 件）稿里说「其实不是套装，是这件装备自带的特殊效果」，不占名额、照旧生效（等 2E 拆走）。
##   混合套（有 1 件档又有多件档，如 101 哥布林脚趾 1／3 件）：1 件档同单件套照旧生效、不占名额；多件档才进名额竞争，
##   被挤掉时只退多件档（件数压到 1）。小A 核 T513 P2-2。
## - 候选：原版套装穿够最低一个多件档；七印至少 2 件（七印最低一档 2 件）。
## - 排序用的件数是「生效件数」＝min(穿的件数, 这套最高一档)：2 件套穿 3 件按 2 算、七印穿 6 件按 5 算（P2-1 第 4 点）。
## - 件数相同：七印优先 → 原版套装号大的优先（后期、高层套号大，免得低层旧套挤掉刚换的高层新套；协调 11-25 定，小A 核 P2-1）
##   → 七印按印序。开关 NEWER_FIRST＝false 回到「套装号小的优先」。
## - 老存档：存档里什么都不改，算效果时按件数多的两套算（同节「老存档」）。
## 入口：XEquipSuits._active_now（filter_suits）、XTianqiQiyinEffects.live_set_counts（filter_seals）、装备页说明牌（note）。
## 只对天启篇存档生效（XTianqi.active）；西游档、开关关时原样。
##
## 【cc·T515·未经审查】原版套装模板引擎（养成线二期 2B；同稿同节「模板套」）：表 tianqi_data/suit_template.json。
## 【小A·T529·未经审查】2B 续（预算稿 v0.16 六.3／九.6 甲／附表一 2B＋D290；收 T515 P2）：
## - 攻类（攻·伤害、攻·本系）改为单独乘、同一乘区相加、混穿逐招（XDamage._calculate 按攻击方系 oe 调 attack_mult），不进词条池；
##   攻·伤害沿用默认排（单套 5 件 ×1.15、两套 5+2 ×1.20），攻·本系用独立排 values_by_kind.atk_element（2/3/5 件 1/2/4/6、6/7/10/12、11/13/16/20，单套 5 件 ×1.20、两套 5+2 ×1.26）。
## - 守类、功能类照旧走词条池（XTianqiAffixBattle.personal），掉率类照旧走掉落池（XTianqiDrop.sources_of）。
## - 开关解耦（T515 P2）：template_on 不再依赖 2A 开关 ENABLED；走词条通道的类别在 XTianqiAffixBattle.on() 关着时不替换原效果，避免白板。
## - 回退开关 ATTACK_STANDALONE＝false 回到 T515 做法（攻类回词条池并共用默认 values 排）。
## - 归了类的套装（表 suits）多件档不再读原效果，按「类型 × 件数档 × 阶」从表里取一条；名字、部件、存档都不动，算效果时读表（老存档也一样）。
## - 件数档只取够到的最高一档、不累加，且不超过原套最高件数；原套最低多件档没穿够不算成套（和名额判定同一口径）。1 件档照原样。
## - 阶＝这套身上部件里最低的那一阶（部件 req_level 按词条四阶分界，同宝珠共鸣「按最低阶算」；协调 11-25）。
## - 没归类的套装照旧（表没填完不会全灭套装）。
## 入口：XEquipSuits._active_now（bonuses_of）、XDamage._calculate（attack_mult）、XTianqiAffixBattle.personal（affix_entries）、XTianqiDrop.sources_of（tqTemplate 标记）。

## 回退开关（O-669）：false＝天启篇也不限套数（回到 T513 之前：原版套装与七印各自全部生效）
static var ENABLED := true
## 回退开关（O-669，同号）：false＝同件数时原版套装号小的优先（T513 首版口径）
static var NEWER_FIRST := true
## 回退开关（O-672）：false＝原版套装照原效果（回到 T515 之前），模板表不读
static var TEMPLATE := true
## 回退开关（O-待定，T529）：false＝攻类模板套退回 T515 做法（进终伤／元素词条池，共用默认 values 排，attack_mult 恒 1）
static var ATTACK_STANDALONE := true
## 一人最多生效几套（养成线 v0.3 第三节第 3 条：一人最多两套）
const CAP := 2
const QIYIN_MIN := 2
const QIYIN_TOP := 5
## 装备页说明牌上的提示（小A 文字审 T513 方案 A；玩家可见，待小A 复核）
const TEXT_CROWDED := "本套未生效（每人最多同时生效两套，件数多的优先）"


static func on(a) -> bool:
	return ENABLED and a is XActor and XTianqi.active(XState.current)


## 原版套装各档要的件数（升序去重）；表里没有返回空
static func _tiers(suit_id: int) -> Array:
	var defs: Array = XDB.table("EquipSuits")
	if suit_id <= 0 or suit_id >= defs.size() or defs[suit_id] == null:
		return []
	var out := []
	for b in defs[suit_id].bonuses:
		var r := int(b.requirePieces)
		if not out.has(r):
			out.append(r)
	out.sort()
	return out


## 原版套装是不是「单件套」：所有档都只要 1 件
static func single_piece(suit_id: int) -> bool:
	var t := _tiers(suit_id)
	return not t.is_empty() and int(t[-1]) <= 1


## 最低的多件档（≥2 件）；没有（单件套、表里没有）返回 0
static func _multi_low(suit_id: int) -> int:
	for r in _tiers(suit_id):
		if int(r) >= 2:
			return int(r)
	return 0


## 有没有 1 件档
static func _has_one(suit_id: int) -> bool:
	var t := _tiers(suit_id)
	return not t.is_empty() and int(t[0]) <= 1


## 候选排序后的列表：[{kind: "suit"|"qiyin", key: 套装号|印, pieces（生效件数）, order}]
static func ranked(suit_pieces: Dictionary, seal_pieces: Dictionary) -> Array:
	var out := []
	for id in suit_pieces:
		var sid := int(id)
		var low := _multi_low(sid)
		var n := int(suit_pieces[id])
		if low <= 0 or n < low:
			continue
		out.append({"kind": "suit", "key": sid, "pieces": mini(n, int(_tiers(sid)[-1])), "order": -sid if NEWER_FIRST else sid})
	var seals: Array = XTianqiQiyinGear.seal_keys()
	for seal in seal_pieces:
		var ord := seals.find(str(seal))
		if ord < 0 or int(seal_pieces[seal]) < QIYIN_MIN:  # 不认识的印不进名额（P3-1）
			continue
		out.append({"kind": "qiyin", "key": str(seal), "pieces": mini(int(seal_pieces[seal]), QIYIN_TOP), "order": ord})
	out.sort_custom(func(x, y):
		if int(x.pieces) != int(y.pieces):
			return int(x.pieces) > int(y.pieces)
		if str(x.kind) != str(y.kind):
			return str(x.kind) == "qiyin"
		return int(x.order) < int(y.order))
	return out


## 用已算好的件数挑生效的那几套：{"suits": [原版套装号], "seals": [七印]}
static func _pick(suit_pieces: Dictionary, seal_pieces: Dictionary) -> Dictionary:
	var keep := {"suits": [], "seals": []}
	var picked := ranked(suit_pieces, seal_pieces)
	for i in range(mini(CAP, picked.size())):
		var c: Dictionary = picked[i]
		keep["suits" if str(c.kind) == "suit" else "seals"].append(c.key)
	return keep


static func _seal_pieces(a) -> Dictionary:
	return XTianqiQiyinEffects.set_counts(a) if XTianqiQiyinEffects.on() else {}


## 生效的那几套；不限（不在天启篇、开关关）时返回空字典
static func live(a) -> Dictionary:
	if not on(a):
		return {}
	return _pick(XEquipSuits.counts(a), _seal_pieces(a))


## XEquipSuits._active_now 用（pieces＝XEquipSuits.counts(a)）：没排进前两套的原版套装去掉；单件套、没到多件档的照旧留着；
## 混合套被挤掉时压到 1 件（只留 1 件档）
static func filter_suits(a, pieces: Dictionary) -> Dictionary:
	if pieces.is_empty() or not on(a):
		return pieces
	var keep := _pick(pieces, _seal_pieces(a))
	var out := {}
	for id in pieces:
		var sid := int(id)
		var low := _multi_low(sid)
		if low <= 0 or int(pieces[id]) < low or keep.suits.has(sid):
			out[id] = pieces[id]
		elif _has_one(sid):
			out[id] = 1
	return out


## XTianqiQiyinEffects.live_set_counts 用（counts＝set_counts(a)）：没排进前两套的七印去掉
static func filter_seals(a, counts: Dictionary) -> Dictionary:
	if counts.is_empty() or not on(a):
		return counts
	var keep := _pick(XEquipSuits.counts(a), counts)
	var out := {}
	for seal in counts:
		if keep.seals.has(str(seal)) or int(counts[seal]) < QIYIN_MIN:
			out[seal] = counts[seal]
	return out


## 这套原版套装穿够了多件档却因为超过两套没生效
static func crowded_out(a, suit_id: int) -> bool:
	var keep := live(a)
	if keep.is_empty():
		return false
	var low := _multi_low(suit_id)
	return low > 0 and int(XEquipSuits.counts(a).get(suit_id, 0)) >= low and not keep.suits.has(suit_id)


## 这一印的七印套装穿够 2 件却因为超过两套没生效
static func seal_crowded_out(a, seal: String) -> bool:
	var keep := live(a)
	if keep.is_empty():
		return false
	return int(XTianqiQiyinEffects.set_counts(a).get(seal, 0)) >= QIYIN_MIN and not keep.seals.has(seal)


## 装备页说明牌：这件装备（身上穿着的）所属的套装被挤掉时给提示，否则 ""。原版套装件、七印套装件都认
static func note(a, rec: Dictionary) -> String:
	if rec.is_empty() or not on(a):
		return ""
	var m := XTianqiQiyinEffects.mark_of(rec)
	if str(m.get("kind", "")) == "set" and seal_crowded_out(a, str(m.get("seal", ""))):
		return TEXT_CROWDED
	for sid in rec.get("equipment", {}).get("suits", []):
		if crowded_out(a, int(sid)):
			return TEXT_CROWDED
	return ""


# ---- 原版套装模板（2B，T515） ----

const TEMPLATE_DATA := "res://modes/xiyou/tianqi_data/suit_template.json"
static var _tpl := {}
static var _tpl_failed := false
## 合成出来的套装档（键「套装号|件数档|阶」）；表换了清掉
static var _tpl_bonus := {}


static func template_table() -> Dictionary:
	if _tpl.is_empty() and not _tpl_failed:
		var d = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATE_DATA)) if FileAccess.file_exists(TEMPLATE_DATA) else null
		_tpl = d if d is Dictionary else {}
		_tpl_failed = _tpl.is_empty()
	return _tpl


## 测试用：换掉表（传空字典＝下次重新读文件）
static func reload_template(d := {}) -> void:
	_tpl = d
	_tpl_failed = false
	_tpl_bonus.clear()


## 模板开关与 2A 名额开关 ENABLED 解耦（T515 P2，T529 收）：只看 TEMPLATE、是角色且在天启篇存档
static func template_on(a) -> bool:
	return TEMPLATE and a is XActor and XTianqi.active(XState.current)


static func _kind_standalone(kind: String) -> bool:
	if not ATTACK_STANDALONE:
		return false
	var k: Dictionary = template_table().get("kinds", {}).get(kind, {})
	return bool(k.get("standalone", false))


static func _kind_uses_affix(kind: String) -> bool:
	var k: Dictionary = template_table().get("kinds", {}).get(kind, {})
	if bool(k.get("drop", false)) or _kind_standalone(kind):
		return false
	return str(k.get("affix", "")) != ""


## 这套归了哪一类：{kind, element?…}；没归类返回空
static func template_of(suit_id: int) -> Dictionary:
	var e = template_table().get("suits", {}).get(str(suit_id), null)
	return e if e is Dictionary else {}


## 件数档：穿 n 件（原套最高档封顶）够到的最高一档；原套最低多件档没穿够、或一档都不够返回 0
static func template_step(suit_id: int, n: int) -> int:
	var low := _multi_low(suit_id)
	if low <= 0 or n < low:
		return 0
	var eff := mini(n, int(_tiers(suit_id)[-1]))
	var out := 0
	for s in template_table().get("steps", []):
		if int(s) <= eff and int(s) > out:
			out = int(s)
	return out


## 身上这套部件里最低的那一阶（1～4）；一件都没有返回 0
static func suit_tier(a, suit_id: int) -> int:
	var out := 0
	if not a is XActor:
		return out
	for e in (a as XActor).equip_list():
		if not e is Dictionary:
			continue
		var ids: Array = e.get("equipment", {}).get("suits", [])
		if not ids.has(suit_id) and not ids.has(float(suit_id)):
			continue
		var t := XTianqiAffixRoll.tier_of(e)
		out = t if out == 0 else mini(out, t)
	return out


## 表里的数：件数档 step、阶 tier（1～4，越界夹住），再按这一类的 cap 封顶。
## 独立乘攻类有专属排（values_by_kind[kind]，如 atk_element）时优先读专属排；ATTACK_STANDALONE 关掉时一律读默认 values 排。
static func template_value(kind: String, step: int, tier: int) -> float:
	var tbl := template_table()
	var vals = tbl.get("values_by_kind", {}).get(kind, null) if _kind_standalone(kind) else null
	if not vals is Dictionary:
		vals = tbl.get("values", {})
	var row = vals.get(str(step), null)
	if not row is Array or (row as Array).is_empty():
		return 0.0
	var v := float(row[clampi(tier, 1, row.size()) - 1])
	var k: Dictionary = tbl.get("kinds", {}).get(kind, {})
	if k.has("cap"):
		v = minf(v, float(k.cap))
	return v


## 合成一档套装效果（字段和原版套装档一样，数都是空的）：掉率类填 bResultPlus[2]，独立乘攻类带 tqAttack，其余带 tqAffix（词条汇总用）
static func _template_bonus(suit_id: int, step: int, tier: int) -> Dictionary:
	var t := template_of(suit_id)
	var kind := str(t.get("kind", ""))
	var standalone := _kind_standalone(kind)
	var key := "%d|%d|%d|%d" % [suit_id, step, tier, 1 if standalone else 0]
	if _tpl_bonus.has(key):
		return _tpl_bonus[key]
	var k: Dictionary = template_table().get("kinds", {}).get(kind, {})
	var v := template_value(kind, step, tier)
	var meta := {"suit": suit_id, "kind": kind, "step": step, "tier": tier, "value": v}
	if bool(k.get("needs_element", false)):
		meta["element"] = str(t.get("element", ""))
	var b := {"requirePieces": step, "states": [], "statesResist": [], "skills": [],
		"paramPlus": [0, 0, 0, 0, 0, 0, 0, 0], "paramRate": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"xparamPlus": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "xparamRate": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"sparamPlus": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "sparamRate": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"bResultPlus": [0, 0, 0], "bResultRate": [1.0, 1.0, 1.0],
		"tqTemplate": meta}
	if bool(k.get("drop", false)):
		b.bResultPlus[2] = v
	elif standalone:
		var sa := {"kind": kind, "value": v, "suit": suit_id}
		if bool(k.get("needs_element", false)):
			sa["element"] = str(t.get("element", ""))
		b["tqAttack"] = sa
	elif str(k.get("affix", "")) != "":
		var x := {"key": str(k.affix), "value": v, "suit": suit_id}
		if bool(k.get("needs_element", false)):
			x["extra"] = {"element": str(t.get("element", ""))}
		b["tqAffix"] = x
	_tpl_bonus[key] = b
	return b


## XEquipSuits._active_now 用：这套（穿 n 件，已过名额筛）该读的档。归了类的：1 件档照原样＋够到的那一个模板档；
## 没归类、不在天启篇、开关关、或走词条通道的类在词条战斗层关闭时（T515 P2 防白板）：原样返回 bonuses
static func bonuses_of(a, suit_id: int, n: int, bonuses: Array) -> Array:
	if not template_on(a) or template_of(suit_id).is_empty():
		return bonuses
	if _kind_uses_affix(str(template_of(suit_id).get("kind", ""))) and not XTianqiAffixBattle.on():
		return bonuses
	var out := []
	for b in bonuses:
		if int(b.requirePieces) <= 1:
			out.append(b)
	var step := template_step(suit_id, n)
	if step > 0:
		out.append(_template_bonus(suit_id, step, maxi(1, suit_tier(a, suit_id))))
	return out


## XDamage._calculate 候选循环用（T529）：攻类模板套独立乘区（攻·伤害与对口攻·本系在同一个乘区里相加，混穿按本候选攻击方系 oe 逐招算）。
## 只对天启篇我方打敌人且 ATTACK_STANDALONE 与 TEMPLATE 开着时生效；西游档、开关关恒返回 1.0（发行空壳照首句生成 return 1.0）。
static func attack_mult(a, b, element_id: int) -> float:
	if not ATTACK_STANDALONE or not template_on(a) or b is XActor:
		return 1.0
	var add := 0.0
	for bonus in XEquipSuits.active(a):
		if not bonus.has("tqAttack"):
			continue
		var sa: Dictionary = bonus.tqAttack
		if sa.has("element"):
			var eid := XTianqiAffixBattle.element_id(str(sa.element))
			if eid <= 0 or eid != element_id:
				continue
		add += float(sa.get("value", 0.0))
	return maxf(0.0, 1.0 + add / 100.0)


## XTianqiAffixBattle.personal 用：生效的模板档记成的词条 [{key, value, extra?}]
static func affix_entries(a) -> Array:
	var out := []
	if not template_on(a):
		return out
	for b in XEquipSuits.active(a):
		if b.has("tqAffix"):
			out.append(b.tqAffix)
	return out
