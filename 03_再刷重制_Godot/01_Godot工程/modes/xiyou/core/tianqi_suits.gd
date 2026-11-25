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

## 回退开关（O-669）：false＝天启篇也不限套数（回到 T513 之前：原版套装与七印各自全部生效）
static var ENABLED := true
## 回退开关（O-669，同号）：false＝同件数时原版套装号小的优先（T513 首版口径）
static var NEWER_FIRST := true
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
