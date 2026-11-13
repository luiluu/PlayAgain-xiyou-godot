extends RefCounted
## 虚拟玩家的养成里「直接调游戏逻辑」的部分（Kyo 2026-11-13：养成不要求逐键操作）。
## 每个函数做的都是菜单里玩家点得到的操作，调的是菜单背后的同一个函数（XOrbs／XRace），不改数值、不跳过条件：
## 材料不够、条件不满足时游戏逻辑自己会拒绝。返回这次做了什么（给报告用的一行行文字）。
## 走路、对话、战斗、换装仍由 virtual_player.gd 按键完成；抽奖是走到希禾面前选「自定义单抽」，只有数量框用 XCasinoBatch.begin 代填。


## 宝珠坊：领暂存的神秘珠 → 把背包里的神秘珠全部鉴定 → 给出战的人身上装备的空孔镶上阶位最高的可镶宝珠
static func orbs(st: XState) -> Array:
	var out := []
	if XOrbs.config().is_empty():
		return out
	var claimed := XOrbs.claim_drops(st)
	if claimed > 0:
		out.append("宝珠坊领回暂存的神秘珠 %d 枚" % claimed)
	for b in XOrbs.config().get("bands", []):
		var id := int(b.itemId)
		var n := XOrbs.max_identify(st, id)
		if n <= 0:
			continue
		var res := XOrbs.identify(st, id, n)
		if bool(res.get("ok", false)):
			out.append("鉴定 %s×%d：%s" % [XOrbs.item_name(id), n,
				"、".join(res.outputs.map(func(o): return "%s×%d" % [XOrbs.item_name(int(o.id)), int(o.quantity)]))])
		else:
			out.append("鉴定 %s 没成：%s" % [XOrbs.item_name(id), str(res.get("reason", ""))])
	for a in st.battle_members():
		for eq in a.equips:
			if not (eq is Dictionary) or eq.is_empty() or XOrbs.slots(eq).is_empty():
				continue
			XOrbs.ensure(eq)
			for slot in XOrbs.slots(eq).size():
				if not XOrbs.valid_slot(eq, slot) or not XOrbs.gem_in_slot(eq, slot).is_empty():
					continue
				var best := {}
				var best_rank := -1
				for row in XOrbs.list(eq, slot, st):
					if row.rec.is_empty() or not bool(row.enabled):
						continue
					var rank := int(XOrbs.spec(int(row.rec.id)).get("rank", 0))   # 原作宝珠没有阶位，记 0
					if rank > best_rank:
						best_rank = rank
						best = row.rec
				if not best.is_empty() and XOrbs.apply(eq, best, slot, st) == "":
					out.append("给 %s 的 %s 镶上 %s" % [a.display_name(), str(eq.get("name", "")), str(best.get("name", ""))])
	return out


## 种族祝福：领暂存的进阶石 → 有下一阶的进阶石就给出战的人逐阶进阶（先出战的，再其余队员）
static func race(st: XState) -> Array:
	var out := []
	if XRace.config().is_empty():
		return out
	XRace.claim_inbox(st)
	var order: Array = st.battle_members()
	for a in st.members():
		if not order.has(a):
			order.append(a)
	for a in order:
		var d := XRace.data(st, a)
		while int(d.race) >= 0 and int(d.rank) < 7:
			var res := XRace.upgrade(st, a, int(d.rank) + 1)
			if not bool(res.get("ok", false)):
				break
			out.append("%s 的%s族祝福进到第 %d 阶" % [a.display_name(), XRace.race_name(int(d.race)), int(d.rank)])
	return out


## 养成材料的现状（给报告用）：神秘珠、宝珠残片、各阶进阶石、每人的种族阶位、已镶的宝珠数
static func materials(st: XState) -> Dictionary:
	var out := {"pearls": 0, "fragments": 0, "stones": [], "race_ranks": [], "gems": 0}
	if not XOrbs.config().is_empty():
		for b in XOrbs.config().get("bands", []):
			out.pearls += st.item_count(int(b.itemId))
		out.fragments = st.item_count(int(XOrbs.config().get("fragment", 0)))
		for a in st.battle_members():
			for eq in a.equips:
				if eq is Dictionary and not eq.is_empty():
					for slot in XOrbs.slots(eq).size():
						if not XOrbs.gem_in_slot(eq, slot).is_empty():
							out.gems += 1
	if not XRace.config().is_empty():
		out.stones = XRace.config().get("stones", []).map(func(id): return st.item_count(int(id)))
		out.race_ranks = st.members().map(func(a): return int(XRace.data(st, a).rank))
	return out
