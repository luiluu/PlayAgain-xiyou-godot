extends Node
## 【cc·T533】防御通过率按主属性：全名单对照（不是专项，检查.sh 不跑；单独跑带 --audio-driver Dummy、临时 HOME）。
## 天启篇档，全体可选角色（超强者／强者／弱者＋天启篇五条悟）各升到 81 级、不穿装备，取已学会的走角色卡公式的伤害招，
## 目标双防都取标准线 81 级攻击 1640（同《基础数值重构》「六项相等」的标准角色），逐招打一行：
## T533_ROW|角色号|角色名|梯队|招号|招名|mode|卡上属性|改前通过率|A（产品）|B（取最大项）|改前用的攻击值|A 主属性值|B 主属性值
## mixed mode 两侧权重同正式结算按公式微扰取（XDamage._mixed_weights，目标用一只 1 号敌人占位）。

const LV := 81
const REF_DEF := 1640.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ids: Array = XTier.ids(XTier.SUPER) + XTier.ids(XTier.STRONG) + XTier.ids(XTier.WEAK)
	ids = ids.filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var weak: Array = XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var s := XTianqi.start_new_game(3, "jianxian", weak.slice(0, 5))
	XTianqi.take_pending()
	s.map_id = 4
	XState.current = s
	if not ids.has(180):
		ids.append(180)  # 五条悟只在天启篇
	var dummy := XEnemy.new().setup(1, 3, 100.0)
	var rows := 0
	for id in ids:
		if s.actor(int(id)) == null:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
		var a: XActor = s.actor(int(id))
		if a == null:
			continue
		a.change_level(LV)
		a.keep_unequippable = true
		for i in range(a.equips.size()):
			a.equips[i] = {}
		a.read_touch()
		a.param_mark_dirty()
		a.refresh_passive()
		for item in a.skills():
			var d := XDamage.card_damage_spec(item, a)
			if d.is_empty() or not int(item.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]:
				continue
			var mode := XDamage.item_mode(item)
			var w := [0.0, 1.0] if mode == "magical" else ([1.0, 0.0])
			if mode == "mixed":
				w = XDamage._mixed_weights(item, a, dummy, [])  # 同正式结算：按公式对物攻、魔攻微扰取权重
			var before: float = w[0] * XDamage.defense_rate(a.atk, REF_DEF) + w[1] * XDamage.defense_rate(a.mat, REF_DEF)
			var va := XDamage.main_stat_value(d, a, "A")
			var vb := XDamage.main_stat_value(d, a, "B")
			var pa: float = XDamage.defense_rate(va, REF_DEF)
			var pb: float = XDamage.defense_rate(vb, REF_DEF)
			var stats := str(d.get("stats", {"atk": 1})) + (" max_of%s" % str(d.max_of) if d.has("max_of") else "")
			var old_att: float = w[0] * a.atk + w[1] * a.mat
			print("T533_ROW|%d|%s|%s|%d|%s|%s|%s|%.4f|%.4f|%.4f|%.0f|%.0f|%.0f" % [int(id), a.display_name(), XTier.tier_of(int(id)), int(item.id), str(item.get("name", "")), mode, stats, before, pa, pb, old_att, va, vb])
			rows += 1
	print("T533_LIST_DONE|rows=%d" % rows)
	get_tree().quit(0)
