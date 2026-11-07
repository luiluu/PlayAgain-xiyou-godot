class_name XTier
extends RefCounted
## 【cc·悟空·未经审查】强弱分类唯一来源（正式 v0.44 js/codex/runtime/installTierTagsV044Runtime.js，CodexTier）：
## 角色备注 <KyoTier:超强者>／<KyoTier:强者>，有名字但没有这个标签的角色是弱者，没名字的空位不算任何一档。
## 原版装好后原地重建 CodexBossDifficulty.superStrongIds／strongIds，Boss 难度名单、弱者挑战、天道注视、难度补强（公共事件 1345、1443～1445
## 改成 CodexTier.nonWeakIds()）、新角色强者技能替换都读这里。重制同样由 XItemMarks.super_strong_ids、XPowerBooks.strong_ids、
## XWeakChallenge.is_weak、XState 难度传承读这里。
## 产物里一个标签都没有（v0.44 以前的正式源，如冻结 v0.28）时 tagged() 为 false，各处退回原来的写死名单，旧源对照不变。
## 事件脚本里的 CodexTier.nonWeakIds()／isNonWeak 等翻译（A 车道）调 non_weak_ids()／is_non_weak()。

const SUPER := "超强者"
const STRONG := "强者"
const WEAK := "弱者"
static var _cache := {}
static var _source = null
static var _tag := RegEx.create_from_string("<KyoTier\\s*:\\s*(超强者|强者)\\s*>")


static func _rebuild() -> void:
	var actors = XDB.table("Actors")
	if is_same(actors, _source):
		return
	_source = actors
	_cache = {}
	for a in actors:
		if not a is Dictionary or str(a.get("name", "")) == "":
			continue
		var m := _tag.search(str(a.get("note", "")))
		_cache[int(a.id)] = m.get_string(1) if m != null else WEAK


## 产物里有没有任何 <KyoTier> 标签（没有＝v0.44 以前的源，调用方用旧名单）
static func tagged() -> bool:
	_rebuild()
	return _cache.values().any(func(t): return t != WEAK)


static func tier_of(actor_or_id) -> String:
	_rebuild()
	var id := int(actor_or_id.actor_id) if actor_or_id is Object else int(actor_or_id)
	return str(_cache.get(id, ""))


static func is_super(x) -> bool: return tier_of(x) == SUPER
static func is_strong(x) -> bool: return tier_of(x) == STRONG
static func is_weak(x) -> bool: return tier_of(x) == WEAK
static func is_non_weak(x) -> bool: return tier_of(x) in [SUPER, STRONG]


static func ids(tier: String) -> Array:
	_rebuild()
	var out := []
	for id in _cache:
		if _cache[id] == tier:
			out.append(int(id))
	out.sort()
	return out


## 公共事件 1345、1443～1445 的脚本读这个
static func non_weak_ids() -> Array:
	var out := ids(SUPER) + ids(STRONG)
	out.sort()
	return out
