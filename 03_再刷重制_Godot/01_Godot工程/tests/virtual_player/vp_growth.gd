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
	# 宝珠残片换神秘珠（宝珠坊「残片换神秘珠」，按已通过的层段定价）：残片够几枚换几枚，下面一起鉴定
	var band_now := XOrbs.progress_band(st)
	var price := XOrbs.pearl_price(band_now) if not band_now.is_empty() else 0
	if price > 0:
		var can: int = st.item_count(int(XOrbs.config().get("fragment", 0))) / price
		if can > 0:
			var bought: Dictionary = XOrbs.buy_pearl(st, can)
			if bool(bought.get("ok", false)):
				out.append("宝珠残片换 %s×%d" % [XOrbs.item_name(int(band_now.itemId)), can])
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


## 开关（--vp-plain-score 关掉）：换装比较除了八项能力，还看暴击率、爆伤、终伤和天启篇词条里的伤害加成。
## false＝回到只比八项能力（第五轮及以前的比法）。
static var full_score := true


## 一个人的「出手」估值：物攻、魔攻里高的那项 ×（1＋暴击率×暴击多出来的倍数）×（1＋终伤＋天启篇词条的伤害加成）。
## 只用来比较同一个人换装前后，不是伤害公式。
static func offense(a: XActor) -> float:
	var pc: Dictionary = a.passive_cache()
	var crit_extra := 0.5 + float(pc.get("critHarmRi", 0.0))
	var dmg := float(pc.get("globalHarmRi", 0.0))
	if XTianqiAffixBattle.on():
		var v: Dictionary = XTianqiAffixBattle.view(a)
		if not v.is_empty():
			crit_extra += float(v.d.crit_add) / 100.0
			for k in v.p:
				var pool := str(XTianqiAffixTable.affix(str(k).get_slice(":", 0)).get("pool", ""))
				if pool == "final_damage" or pool == "skill_damage":
					dmg += float(v.p[k]) / 100.0
	return maxf(float(a.atk), float(a.mat)) * (1.0 + clampf(float(a.cri), 0.0, 1.0) * maxf(crit_extra, 0.0)) * maxf(1.0 + dmg, 0.1)


## 换装前（now）后（then）的涨幅，加权相对值。full_score 关着时只比八项能力（同装备页「属性对比」）
static func gain_score(now: XActor, then: XActor) -> float:
	var a := [now.mhp, now.mmp, now.atk, now.def, now.mat, now.mdf, now.agi, now.luk]
	var b := [then.mhp, then.mmp, then.atk, then.def, then.mat, then.mdf, then.agi, then.luk]
	var score := 0.0
	for k in 8:
		if full_score and (k == 2 or k == 4):
			continue                     # 物攻、魔攻并进「出手」估值里算
		score += W8[k] * (float(b[k]) - float(a[k])) / maxf(absf(float(a[k])), 1.0)
	if full_score:
		score += (W8[2] + W8[4]) * (offense(then) - offense(now)) / maxf(absf(offense(now)), 1.0)
	return score


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
			var score := gain_score(a, t)
			# 法宝：这一格还空着就值得买（一级法宝属性不多，靠喂装备升上去）；本人专属的排在通用的前面
			if XMagicWeapon.is_magic(item) and not (a.equips[slot] is Dictionary and not a.equips[slot].is_empty()):
				score = maxf(score, 0.06) + (1.0 if str(item.get("note", "")).contains("req_actors") else 0.0)
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
static func shop(shop_page: XShop, st: XState, wanted: Dictionary = {}) -> Dictionary:
	var out := {"lines": [], "uses": [], "bought": 0}
	var d := shop_page._buy_data()
	# 点名要的物品（如角色进阶缺的魂灯）：{物品号: 还差几个}，先买这些
	for i in d.size():
		var e0: Dictionary = d[i]
		if int(e0.kind) != 0 or not wanted.has(int(e0.gid)) or not shop_page._buy_enabled(e0):
			continue
		var cost0 := _wallet(st)
		var got := _buy(shop_page, i, int(wanted[int(e0.gid)]))
		if got > 0:
			out.bought += got
			out.lines.append("买 %s×%d %s" % [str(e0.rec.get("name", "")), got, _spent(st, cost0)])
	# 种族祝福进阶石（13 层起打赢的守层者卖，七族通用）：出战的人和助力位里谁正好差这一阶，就按人数买
	var stone_need := stone_needs(st)
	for i in d.size():
		var e1: Dictionary = d[i]
		var rank := stone_rank(e1.item) if int(e1.kind) == 0 else 0
		if rank <= 0 or int(stone_need.get(rank, 0)) <= 0 or not shop_page._buy_enabled(e1):
			continue
		var cost1 := _wallet(st)
		var got1 := _buy(shop_page, i, int(stone_need[rank]))
		if got1 > 0:
			stone_need[rank] = int(stone_need[rank]) - got1
			out.bought += got1
			out.lines.append("买 %s×%d %s" % [str(e1.rec.get("name", "")), got1, _spent(st, cost1)])
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
			if XMagicWeapon.is_magic(d[i].item):
				# 法宝买来直接戴上（同装备页的更换）：一级法宝属性涨得少，换装比较不一定挑它
				var mine: Array = st.gear.filter(func(x): return XMagicWeapon.is_magic(x) and str(x.get("name", "")) == str(d[i].item.get("name", "")))
				if not mine.is_empty():
					XEquipment.change(st, st.actor(int(g.actor)), int(g.slot), mine[-1])
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


## 出战的人里有没有人法宝格还空着
static func lacks_fabao(st: XState) -> bool:
	for a in st.battle_members():
		if not a.equips.any(func(e): return XMagicWeapon.is_magic(e)):
			return true
	return false


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


# ---------------------------------------------------------------- 第六轮（Kyo 2026-11-13「盘点所有变强途径，教会虚拟玩家」）第一批

## 出战的人按「出手」估值从高到低排（一本书只有一个人能学时先给主力）
static func fighters_by_offense(st: XState) -> Array:
	var team: Array = st.battle_members()
	team.sort_custom(func(x, y): return offense(x) > offense(y))
	return team


## 背包里捡到的、还没用的东西（抽奖出的被动书、副本首领掉的专属书和流派书、装备盒、精魂补给包）：返回 [{id, actor, n}]。
## 书：效果只有「学会技能」的物品，出战的人里谁还没学会、学得了就给谁（主力优先，一人一本）；
## 盒子：说明以「宝箱」开头的装备盒和名字带「补给包」的，每样每层试一次（没到开启条件的游戏自己会拒绝）。
## tried 记用过没成的（"物品号:角色号"），不再重复试；boxes 记这一层试过的盒子。
static func bag_uses(st: XState, tried: Dictionary, boxes: Dictionary) -> Array:
	var out := []
	var floor_now := int(st.variable(20))
	var ids: Array = st.items.keys()
	ids.sort()
	for id in ids:
		var n := int(st.items[id])
		if n <= 0:
			continue
		var item: Dictionary = XDB.rec("Items", int(id))
		if item.is_empty() or not [0, 2].has(int(item.get("occasion", 0))):
			continue
		var effects: Array = item.get("effects", [])
		var name := str(item.get("name", ""))
		if not effects.is_empty() and effects.all(func(x): return int(x.code) == 43) and int(item.get("scope", 0)) == 7 and not name.begins_with("错误数据"):
			var who := book_learners(st, item)
			var order: Array = fighters_by_offense(st).map(func(a): return a.actor_id)
			who.sort_custom(func(x, y): return order.find(x) < order.find(y))
			for aid in who:
				if n <= 0:
					break
				if tried.has("%d:%d" % [int(id), int(aid)]):
					continue
				out.append({"id": int(id), "actor": int(aid), "n": 1, "kind": "book"})
				n -= 1
		elif (str(item.get("description", "")).strip_edges().begins_with("宝箱") or name.contains("补给包")) and effects.any(func(x): return int(x.code) == 44):
			if int(boxes.get(int(id), -1)) == floor_now or st.battle_members().is_empty():
				continue
			out.append({"id": int(id), "actor": int(st.battle_members()[0].actor_id), "n": 1, "kind": "box"})
	return out


## 角色进阶（兑换大厅奉神老妪「进阶」页背后的同一个函数）：出战的人和助力位，条件够（等级、金币、材料）就一阶阶进。
## 返回这次做了什么。条件由 XAdvance.missing 判，扣金币和材料照游戏的。
static func advance(st: XState) -> Array:
	var out := []
	var team: Array = st.battle_members()
	if st.helper() != null:
		team.append(st.helper())
	for a in team:
		var guard := 0
		while guard < 8 and XAdvance.missing(st, a).is_empty():
			guard += 1
			var before := XAdvance.rank(st, a.actor_id)
			if not XAdvance.advance(st, a) or XAdvance.rank(st, a.actor_id) == before:
				break
			out.append("%s 进阶到第 %d 阶" % [a.display_name(), XAdvance.rank(st, a.actor_id)])
	return out


## 进阶只差材料的：{物品号: 一共还差几个}（等级、金币都够，只缺物品的那些人）。用来决定要不要去兑换大厅买魂灯
static func advance_needs(st: XState) -> Dictionary:
	var need := {}
	var have := {}
	for a in st.battle_members():
		var r = XAdvance.row(st, a.actor_id)
		if r == null or XGarou.own(a) or a.level < int(r.level) or st.gold < int(r.gold):
			continue
		for p in r.items:
			var id := int(p[0])
			if not have.has(id):
				have[id] = st.item_count(id)
			var lack: int = int(p[1]) - int(have[id])
			have[id] = maxi(int(have[id]) - int(p[1]), 0)
			if lack > 0:
				need[id] = int(need.get(id, 0)) + lack
	return need


## 每人的进阶次数（给报告用）
static func advance_ranks(st: XState) -> Array:
	return st.battle_members().map(func(a): return XAdvance.rank(st, a.actor_id))


# ---------------------------------------------------------------- 第二批：整队、通关抽角色

const TIER_RANK := {"弱者": 0, "强者": 1, "超强者": 2}
const SWAP_MARGIN := 1.15          # 板凳上的人比场上最弱的强这么多才换（免得来回倒）


static func tier_rank(id: int) -> int:
	return int(TIER_RANK.get(XTianqiSkills.tier_of(id, true), 0))


## 上场价值（只用来排队）：出手估值 × 生命的平方根 × 档位（强者 ×1.3、超强者 ×1.6）
static func field_value(a: XActor) -> float:
	return offense(a) * sqrt(maxf(float(a.mhp), 1.0)) * (1.0 + 0.3 * tier_rank(a.actor_id))


## 整队（同菜单「整队」改出战栏再点「完成」）：上场 4 人里最弱的，板凳上有明显更强的就换下去（超强者不超过本档上限）；
## 有领袖技能的人放 1 号位；助力位放剩下的人里档位最高、等级最高的（助力位拿满经验）。换下场的人身上的装备卸回背包给别人用。
## 返回这次改了什么；没改返回空。
static func formation(st: XState) -> Array:
	var out := []
	if not XTianqi.active(st) or st.party.size() <= 1:
		return out
	var before: Array = st.battle_slots.duplicate()
	var cap := XTianqi.super_cap(st)
	var fighters: Array = st.battle_members()
	var bench: Array = st.members().filter(func(a): return a != null and not fighters.has(a))
	bench.sort_custom(func(x, y): return field_value(x) > field_value(y))
	for cand in bench:
		if fighters.size() < XTianqi.FIGHTERS:
			if tier_rank(cand.actor_id) == 2 and cap >= 0 and fighters.filter(func(a): return tier_rank(a.actor_id) == 2).size() >= cap:
				continue
			fighters.append(cand)
			continue
		var weakest: XActor = fighters[0]
		for a in fighters:
			if field_value(a) < field_value(weakest):
				weakest = a
		if field_value(cand) <= field_value(weakest) * SWAP_MARGIN:
			continue
		var supers: int = fighters.filter(func(a): return tier_rank(a.actor_id) == 2).size()
		if tier_rank(cand.actor_id) == 2 and tier_rank(weakest.actor_id) != 2 and cap >= 0 and supers >= cap:
			continue
		fighters[fighters.find(weakest)] = cand
	# 领袖：有领袖技能的放 1 号位
	for i in fighters.size():
		if XLeadActor.skill_of(int(fighters[i].actor_id)) > 0:
			var lead: XActor = fighters[i]
			fighters.remove_at(i)
			fighters.push_front(lead)
			break
	var rest: Array = st.members().filter(func(a): return a != null and not fighters.has(a))
	rest.sort_custom(func(x, y):
		if tier_rank(x.actor_id) != tier_rank(y.actor_id):
			return tier_rank(x.actor_id) > tier_rank(y.actor_id)
		return int(x.level) > int(y.level))
	var slots := []
	for a in fighters:
		slots.append(int(a.actor_id))
	while slots.size() < XTianqi.FIGHTERS:
		slots.append(0)
	slots.append(int(rest[0].actor_id) if not rest.is_empty() else 0)
	while slots.size() < XState.MAX_BATTLE_MEMBERS:
		slots.append(0)
	if slots == before:
		return out
	st.battle_slots = slots
	st.rearrange_actors()
	XPartySkills.finish(st)
	out.append("整队：出战栏 %s → %s" % [str(before), str(st.battle_slots)])
	# 不在出战栏里的人：装备卸回背包
	for a in st.members():
		if a == null or st.battle_slots.has(int(a.actor_id)):
			continue
		var n := 0
		for slot in a.equip_slots().size():
			if a.equips[slot] is Dictionary and not a.equips[slot].is_empty() and XEquipment.can_change(a, slot) and XEquipment.change(st, a, slot, null):
				n += 1
		if n > 0:
			out.append("%s 下场，卸下 %d 件装备" % [a.display_name(), n])
	return out


## 通关抽角色的选项里挑哪个：候选带【档位】的挑档位最高的（同档挑第一个）；自选先挑最高的档位。不是抽角色的选项返回 -1
static func draw_choice(choices: Array) -> int:
	if choices.size() < 2 or not (str(choices[-1]) in ["稍后再选", "返回"]):
		return -1
	var best := -1
	var best_rank := -1
	for i in choices.size() - 1:
		var t := str(choices[i])
		var rank := -1
		if TIER_RANK.has(t):
			rank = int(TIER_RANK[t])
		else:
			for k in TIER_RANK:
				if t.ends_with("【%s】" % k):
					rank = int(TIER_RANK[k])
		if rank < 0:
			return -1
		if rank > best_rank:
			best_rank = rank
			best = i
	return best


# ---------------------------------------------------------------- 第三批：种族祝福石（打赢的守层者卖）

const ROMAN := {"Ⅱ": 2, "Ⅲ": 3, "Ⅳ": 4, "Ⅴ": 5, "Ⅵ": 6, "Ⅶ": 7}


## 这件物品是第几阶的祝福进阶石（不是返回 0）
static func stone_rank(item: Dictionary) -> int:
	var name := str(item.get("name", ""))
	if not name.begins_with("祝福进阶石·"):
		return 0
	for k in ROMAN:
		if name.contains(k + "阶"):
			return int(ROMAN[k])
	return 0


## 各阶进阶石还差几块：{阶: 块数}。出战的人和助力位里现在是第 r 阶的，要一块第 r＋1 阶的；手里已有的先抵掉
static func stone_needs(st: XState) -> Dictionary:
	var need := {}
	if XRace.config().is_empty():
		return need
	var team: Array = st.battle_members()
	if st.helper() != null:
		team.append(st.helper())
	for a in team:
		var d := XRace.data(st, a)
		if int(d.race) >= 0 and int(d.rank) >= 1 and int(d.rank) < 7:
			need[int(d.rank) + 1] = int(need.get(int(d.rank) + 1, 0)) + 1
	var stones: Array = XRace.config().get("stones", [])
	for rank in need.keys():
		if rank - 2 < stones.size():
			need[rank] = maxi(0, int(need[rank]) - st.item_count(int(stones[rank - 2])))
	return need


# ---------------------------------------------------------------- 第四批：血脉（兑换大厅嫦娥，用副本首领的头颅换）

## 背包里一共有多少个头颅（名字以「头颅：」开头的物品）
static func heads(st: XState) -> int:
	var n := 0
	for id in st.items:
		if int(st.items[id]) > 0 and str(XDB.rec("Items", int(id)).get("name", "")).begins_with("头颅"):
			n += int(st.items[id])
	return n
