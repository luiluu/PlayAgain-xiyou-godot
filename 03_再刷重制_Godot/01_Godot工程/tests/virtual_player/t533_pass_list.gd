extends Node
## 【cc·T533】防御通过率按主属性：全名单对照（不是专项，检查.sh 不跑；单独跑带 --audio-driver Dummy、临时 HOME）。
## 天启篇档，五档候选池并集（＋五条悟）各升到 81 级、不穿装备，取已学会的＋实际攻击指令（T553 普攻）里走角色卡公式的伤害招，
## 目标双防都取标准线 81 级攻击 1640（同《基础数值重构》「六项相等」的标准角色），逐招打一行：
## T533_ROW|角色号|角色名|梯队|招号|招名|mode|卡上属性|改前通过率|A（产品）|B（取最大项）|改前用的攻击值|A 主属性值|B 主属性值
## mixed mode 两侧权重同正式结算按公式微扰取（XDamage._mixed_weights，目标用一只 1 号敌人占位）。

const LV := 81
const REF_DEF := 1640.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ids: Array = []  # T533 R2（小o P1-1）：按天启篇五档候选池的并集枚举（原来按梯队表＋停用表，漏 9 人）
	for dk in XTianqi.DIFFICULTIES:
		var p := XTianqi.pool(str(dk.key))
		for tier in p:
			for id in p[tier]:
				if not ids.has(int(id)):
					ids.append(int(id))
	ids.sort()
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
			print("T533_NOROW|%d|入队失败" % int(id))
			continue
		a.change_level(LV)
		a.keep_unequippable = true
		for i in range(a.equips.size()):
			a.equips[i] = {}
		a.read_touch()
		a.param_mark_dirty()
		a.refresh_passive()
		var items: Array = a.skills()
		var atk_item := a.attack_skill()  # T533 R2：实际攻击指令（T553 我方 1 号普攻走 ATTACK1_SPEC；换了普攻的取替换后那一招）
		if not atk_item.is_empty() and not items.any(func(x): return int(x.id) == int(atk_item.id)):
			items.append(atk_item)
		var before_rows := rows
		for item in items:
			var d := XDamage.card_damage_spec(item, a)
			if not int(item.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]:
				continue
			if d.is_empty():  # T533 R2：不走角色卡公式的伤害招（本卡不改，通过率照旧物攻／魔攻），列出来备查
				var prog: Dictionary = item.get("damage", {}).get("formulaProgram", {})
				print("T533_NONCARD|%d|%s|%d|%s|%s|%s|%s" % [int(id), a.display_name(), int(item.id), str(item.get("name", "")), XDamage.item_mode(item), str(prog.get("status", "")) + "/" + str(prog.get("module", "")), str(item.get("damage", {}).get("formula", "")).substr(0, 60).replace("|", "/")])
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
		if rows == before_rows:  # 没有卡公式伤害招（连普攻都不是）
			print("T533_NOROW|%d|%s" % [int(id), a.display_name()])
	print("T533_LIST_DONE|rows=%d|actors=%d" % [rows, ids.size()])
	get_tree().quit(0)
