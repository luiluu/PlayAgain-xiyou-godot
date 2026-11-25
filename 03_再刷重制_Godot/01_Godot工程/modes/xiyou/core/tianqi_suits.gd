class_name XTianqiSuits
extends RefCounted
## 【cc·T513·未经审查】天启篇套装同台上限（养成线二期 2A；私密设计仓《天启篇_原版养成线重做方案_v0.3》第三节第 3 条，
## Kyo 11-14 上午「原版套装照方案」已定；拆卡见 协作交接/派单/T513_二三期拆卡.md）。
## - 一人最多生效 CAP（2）套，七印套装也算在这两套里，件数多的优先。31 层后七印 5 件＋3 件一穿，原版套装自然退场。
## - 「单件就生效」的套装（最高件数档只有 1 件，约 49 套）稿里说「其实不是套装，是这件装备自带的特殊效果」，
##   不占名额、照旧生效（等 2E 拆成装备固有特效）。
## - 候选：原版套装至少有一档生效（穿够这一套最低一档的件数）；七印至少 2 件（七印最低一档 2 件）。
## - 件数相同：七印优先（稿的方向是 31 层后让位七印），再按原版套装号小的、七印印序靠前的。稿没写，交付单列待确认。
## - 老存档：存档里什么都不改，算效果时按件数多的两套算（同节「老存档」）。
## 入口：XEquipSuits._active_now 过滤原版套装、XTianqiQiyinEffects 的套装件数（live_set_counts）过滤七印。
## 只对天启篇存档生效（XTianqi.active）；西游档、开关关时原样。

## 回退开关（O-待定）：false＝天启篇也不限套数（回到 T513 之前：原版套装与七印各自全部生效）
static var ENABLED := true
## 一人最多生效几套（养成线 v0.3 第三节第 3 条：一人最多两套）
const CAP := 2
const QIYIN_MIN := 2


static func on(a) -> bool:
	return ENABLED and a is XActor and XTianqi.active(XState.current)


## 原版套装是不是「单件套」：所有档都只要 1 件
static func single_piece(suit_id: int) -> bool:
	var defs: Array = XDB.table("EquipSuits")
	if suit_id <= 0 or suit_id >= defs.size() or defs[suit_id] == null:
		return false
	var top := 0
	for b in defs[suit_id].bonuses:
		top = maxi(top, int(b.requirePieces))
	return top <= 1


static func _min_pieces(suit_id: int) -> int:
	var defs: Array = XDB.table("EquipSuits")
	if suit_id <= 0 or suit_id >= defs.size() or defs[suit_id] == null:
		return 0
	var low := 0
	for b in defs[suit_id].bonuses:
		var r := int(b.requirePieces)
		low = r if low == 0 else mini(low, r)
	return low


## 候选排序后的列表：[{kind: "suit"|"qiyin", key: 套装号|印, pieces, order}]，按件数降序、七印先、order 升序
static func ranked(a: XActor, suit_pieces: Dictionary, seal_pieces: Dictionary) -> Array:
	var out := []
	for id in suit_pieces:
		var sid := int(id)
		var low := _min_pieces(sid)
		if low <= 0 or single_piece(sid) or int(suit_pieces[id]) < low:
			continue
		out.append({"kind": "suit", "key": sid, "pieces": int(suit_pieces[id]), "order": sid})
	var seals: Array = XTianqiQiyinGear.seal_keys()
	for seal in seal_pieces:
		if int(seal_pieces[seal]) >= QIYIN_MIN:
			out.append({"kind": "qiyin", "key": str(seal), "pieces": int(seal_pieces[seal]), "order": seals.find(str(seal))})
	out.sort_custom(func(x, y):
		if int(x.pieces) != int(y.pieces):
			return int(x.pieces) > int(y.pieces)
		if str(x.kind) != str(y.kind):
			return str(x.kind) == "qiyin"
		return int(x.order) < int(y.order))
	return out


## 生效的那几套：{"suits": [原版套装号], "seals": [七印]}；不限（不在天启篇、开关关）时返回空字典
static func live(a) -> Dictionary:
	if not on(a):
		return {}
	var seal_pieces := XTianqiQiyinEffects.set_counts(a) if XTianqiQiyinEffects.on() else {}
	var keep := {"suits": [], "seals": []}
	var picked := ranked(a, XEquipSuits.counts(a), seal_pieces)
	for i in range(mini(CAP, picked.size())):
		var c: Dictionary = picked[i]
		keep["suits" if str(c.kind) == "suit" else "seals"].append(c.key)
	return keep


## XEquipSuits._active_now 用：去掉没排进前两套的原版套装（单件套、没到最低一档的照旧留着，后者本来就不生效）
static func filter_suits(a, pieces: Dictionary) -> Dictionary:
	if pieces.is_empty():
		return pieces
	var keep := live(a)
	if keep.is_empty():
		return pieces
	var out := {}
	for id in pieces:
		var sid := int(id)
		if single_piece(sid) or keep.suits.has(sid) or int(pieces[id]) < _min_pieces(sid):
			out[id] = pieces[id]
	return out


## XTianqiQiyinEffects 用：去掉没排进前两套的七印
static func filter_seals(a, counts: Dictionary) -> Dictionary:
	if counts.is_empty():
		return counts
	var keep := live(a)
	if keep.is_empty():
		return counts
	var out := {}
	for seal in counts:
		if keep.seals.has(str(seal)) or int(counts[seal]) < QIYIN_MIN:
			out[seal] = counts[seal]
	return out


## 说明卡：这套原版套装穿够了却因为超过两套没生效
static func crowded_out(a, suit_id: int) -> bool:
	var keep := live(a)
	if keep.is_empty() or single_piece(suit_id):
		return false
	var n := int(XEquipSuits.counts(a).get(suit_id, 0))
	var low := _min_pieces(suit_id)
	return low > 0 and n >= low and not keep.suits.has(suit_id)


const TEXT_CROWDED := "（同时最多生效两套，本套未生效）"
