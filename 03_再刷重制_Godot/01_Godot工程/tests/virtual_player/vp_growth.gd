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


# ---------------------------------------------------------------- 花钱（Kyo 2026-11-13：按法宝与积分重构后的规则）

const W8 := [1.0, 0.3, 1.5, 1.0, 1.5, 1.0, 0.5, 0.2]   # 八项能力的权重（和换装比较用的同一组）
static var _exp_pill_cache := {}


## 法宝经验丹（效果里的公共事件调 MagicWeapon…GainExp）：重构后下架，法宝改靠打怪经验和吃装备升级，机器人不买
static func is_fabao_exp_pill(item: Dictionary) -> bool:
	var id := int(item.get("id", 0))
	if not _exp_pill_cache.has(id):
		var hit := false
		for e in item.get("effects", []):
			if int(e.code) != 44:
				continue
			for c in XDB.rec("CommonEvents", int(e.dataId)).get("list", []):
				if int(c.code) == 356 and str(c.parameters[0]).contains("MagicWeapon") and str(c.parameters[0]).contains("Exp"):
					hit = true
		_exp_pill_cache[id] = hit
	return bool(_exp_pill_cache[id])


## 这件装备给谁、换到哪一格涨得最多：返回 {score, actor, slot}（没人用得上 score＝0）。算法同装备页的「属性对比」
static func gear_gain(st: XState, item: Dictionary, taken: Dictionary) -> Dictionary:
	var best := {"score": 0.0, "actor": 0, "slot": -1}
	for a in st.battle_members():
		for slot in a.equip_slots().size():
			if taken.has("%d:%d" % [a.actor_id, slot]) or not XEquipment.can_change(a, slot) or not XEquipment.fits(a, slot, item) or XEquipment.dual_blocked(a, slot, item):
				continue
			var t := XEquipment.preview(a, slot, item)
			if t == null:
				continue
			var now := [a.mhp, a.mmp, a.atk, a.def, a.mat, a.mdf, a.agi, a.luk]
			var then := [t.mhp, t.mmp, t.atk, t.def, t.mat, t.mdf, t.agi, t.luk]
			var score := 0.0
			for k in 8:
				score += W8[k] * (float(then[k]) - float(now[k])) / maxf(absf(float(now[k])), 1.0)
			if score > float(best.score):
				best = {"score": score, "actor": a.actor_id, "slot": slot}
	return best


## 这本书（效果「学会技能」）出战的人里谁该学：还没学会；主动技能要有这个技能类型、身上武器对得上；洪荒权能照游戏的学习条件
static func book_learners(st: XState, item: Dictionary) -> Array:
	var out := []
	for e in item.get("effects", []):
		if int(e.code) != 43:
			continue
		var sid := int(e.dataId)
		var skill := XDB.rec("Skills", sid)
		if skill.is_empty():
			continue
		for a in st.battle_members():
			if out.has(a.actor_id) or a.skill_ids.has(sid):
				continue
			if XPowerBooks.is_power(sid):
				if not XPowerBooks.can_learn(a, sid):
					continue
			elif int(skill.get("stypeId", 0)) in [1, 2, 3]:
				if not a.traits_set(41).has(int(skill.stypeId)) or not XBattleLogic.wtype_ok(a, skill):
					continue
			out.append(a.actor_id)
	return out


## 在开着的商店里买一样（走商店页自己的数量确认 _trade：扣钱、扣别的货币、扣库存都照游戏的）。返回买到几件
static func _buy(shop: XShop, index: int, n: int) -> int:
	var d := shop._buy_data()
	if index < 0 or index >= d.size() or not shop._buy_enabled(d[index]):
		return 0
	n = mini(n, shop._max_buy(d[index]))
	if n < 1:
		return 0
	shop._buy_index = index
	shop._number_from = "buy"
	shop._number = n
	shop._mode = "number"
	shop._trade()
	return n


## 逛一家开着的店：先买有人换上能变强的装备（含法宝），再买出战的人能学的书（贵的先买），最后买永久加属性的丹药。
## 返回 {lines: 给报告的文字, uses: [{id, actor, n}] 买完要用掉的, bought: 件数}。法宝经验丹不买。
static func shop(shop_page: XShop, st: XState) -> Dictionary:
	var out := {"lines": [], "uses": [], "bought": 0}
	var d := shop_page._buy_data()
	var gears := []
	var books := []
	var pills := []
	for i in d.size():
		var e: Dictionary = d[i]
		if not shop_page._buy_enabled(e):
			continue
		if int(e.kind) != 0:
			gears.append(i)
		elif is_fabao_exp_pill(e.item):
			continue
		elif e.item.get("effects", []).any(func(x): return int(x.code) == 43):
			books.append(i)
		elif e.item.get("effects", []).any(func(x): return int(x.code) == 42) and int(e.item.get("scope", 0)) == 7:
			pills.append(i)
	var taken := {}
	var scored := []
	for i in gears:
		var g := gear_gain(st, d[i].item, taken)
		if float(g.score) > 0.05:
			scored.append([float(g.score), i])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	for row in scored:
		var i: int = row[1]
		var g := gear_gain(st, d[i].item, taken)   # 前面买的占了格子：重算这件还有没有人要
		if float(g.score) <= 0.05:
			continue
		var cost := _wallet(st)
		if _buy(shop_page, i, 1) > 0:
			taken["%d:%d" % [int(g.actor), int(g.slot)]] = true
			out.bought += 1
			out.lines.append("买装备 %s（给 %d 号，预计涨 %d%%）%s" % [str(d[i].rec.get("name", "")), int(g.actor), int(float(g.score) * 100), _spent(st, cost)])
	books.sort_custom(func(x, y): return int(d[x].price) > int(d[y].price))
	for i in books:
		var who := book_learners(st, d[i].item)
		if who.is_empty():
			continue
		var cost := _wallet(st)
		var n := _buy(shop_page, i, who.size())
		if n > 0:
			out.bought += n
			out.lines.append("买书 %s×%d %s" % [str(d[i].rec.get("name", "")), n, _spent(st, cost)])
			for k in n:
				out.uses.append({"id": int(d[i].gid), "actor": int(who[k]), "n": 1})
	var team: Array = st.battle_members()
	for i in pills:
		if team.is_empty():
			break
		var cost := _wallet(st)
		var n := _buy(shop_page, i, 9999)
		if n > 0:
			out.bought += n
			out.lines.append("买丹药 %s×%d %s" % [str(d[i].rec.get("name", "")), n, _spent(st, cost)])
			for k in team.size():   # 平分给出战的人，零头给排前面的
				var share := n / team.size() + (1 if k < n % team.size() else 0)
				if share > 0:
					out.uses.append({"id": int(d[i].gid), "actor": int(team[k].actor_id), "n": share})
	shop_page._mode = "command"
	shop_page._drop_cache()
	shop_page._refresh()
	return out


static func _wallet(st: XState) -> Array:
	return [int(st.gold), int(st.variable(XCasinoBatch.VAR_POINTS))]


static func _spent(st: XState, before: Array) -> String:
	var parts := []
	if int(before[0]) != int(st.gold):
		parts.append("金币 %d" % (int(before[0]) - int(st.gold)))
	if int(before[1]) != int(st.variable(XCasinoBatch.VAR_POINTS)):
		parts.append("积分 %d" % (int(before[1]) - int(st.variable(XCasinoBatch.VAR_POINTS))))
	return "花 " + "、".join(parts) if not parts.is_empty() else "（别的货币）"


## 对某个队员用掉背包里的物品：临时开一个物品页（不显示），走它自己的「使用」（_use：目标有效性、消耗、效果、公共事件预约都照游戏的；
## 支持批量服用的丹药走数量窗 _bulk_ok）。返回用掉几个。效果里带公共事件的会预约到地图上跑，调用方等它跑完再用下一个。
static func use_item(host: Node, st: XState, id: int, a: XActor, n: int) -> int:
	var idx: int = st.members().find(a)
	var before := st.item_count(id)
	if idx < 0 or before <= 0:
		return 0
	var page := XItemScene.new()
	page.visible = false
	host.add_child(page)
	page.set_process_unhandled_input(false)
	page.set_process_input(false)
	page._item = XDB.rec("Items", id)
	page._actor = idx
	if page._usable(page._item):
		page._use()
		if not page._bulk.is_empty():
			page._bulk.number = clampi(n, 1, int(page._bulk.available))
			await page._bulk_ok()
	page.queue_free()
	return before - st.item_count(id)


## 法宝现状（给报告用）：当前存档的等级上限（0＝不限）和出战的人身上每件法宝的等级
static func fabao(st: XState) -> Dictionary:
	var out := {"cap": XMagicWeapon.level_cap(st), "items": []}
	for a in st.battle_members():
		for eq in a.equips:
			if XMagicWeapon.is_magic(eq):
				out.items.append({"actor": a.actor_id, "name": str(eq.get("name", "")), "level": int(XMagicWeapon.level_of(eq)), "max": int(XMagicWeapon.max_level(eq))})
	return out


## 「喂装备给法宝」的脚本（XFabaoFeed，法宝落地车道做的）；这个类还没合进来时返回 null，机器人就不喂
static func feed_script():
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "XFabaoFeed":
			return load(str(c.path))
	return null


## 把背包里的装备喂给出战的人身上没到当层上限的法宝（换装之后做：留在背包里的就是没人穿的）。
## 品质低的先喂，到上限就停；能不能喂、给多少经验都由 XFabaoFeed 自己判。
static func feed_fabao(st: XState) -> Array:
	var out := []
	var feed = feed_script()
	if feed == null or not bool(feed.ENABLED):
		return out
	for a in st.battle_members():
		for eq in a.equips:
			if not XMagicWeapon.is_magic(eq) or XMagicWeapon.level_of(eq) >= XMagicWeapon.max_level(eq):
				continue
			var food: Array = st.gear.filter(func(g): return str(feed.reason(st, eq, g)) == "")
			if food.is_empty():
				continue
			food.sort_custom(func(x, y): return int(feed.exp_of(x)) < int(feed.exp_of(y)))
			var res: Dictionary = feed.feed(st, eq, food, a)
			if int(res.used) > 0:
				out.append("给 %s 的法宝 %s 喂了 %d 件装备：%d 级 → %d 级%s" % [a.display_name(), str(eq.get("name", "")), int(res.used), int(res.from), int(res.to), "（到当层上限）" if bool(res.capped) else ""])
	return out
