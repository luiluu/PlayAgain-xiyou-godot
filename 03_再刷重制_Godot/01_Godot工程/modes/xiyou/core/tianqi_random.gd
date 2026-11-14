class_name XTianqiRandom
extends RefCounted
## 【cc·未经审查】天启篇随机门面（架构二第五节「随机门面」；方案见 cc/save-rng-facade 交付单第 2 节，本文件是 R1 批）。
## 读档后不该变的随机全部从这里取。Kyo 11-14 读档总原则：打完或点完就出结果的读档都不变；战斗过程（先手、暴击）可以变。
##
## 身份规则（车道须知短表抄一份）：
## 1. 这个存档里发生的第几件事（抽角色、新装备掷词条）→ 按本档计数派生（save_stream／save_roll，计数随存档，调用方推进）。
## 2. 同一个东西反复试、要带保底（招牌掉落、号卷）→ 按「键＋该键第几次」派生，保底计数和键放在一起。
## 3. 对这件装备做第几次操作，装备会被搬来搬去 → item_roll；身份 tq_seed_id 写在装备上，复制时不带走（XTianqiSave.GEAR_KEYS）。
## 4. 有稳定来源的东西进包（商店、事件、掉落）→ 入包时按来源键分配身份（on_register 带 source）；同一个来源键在本档第几件。
## 5. 战斗：回合内 → 规则流；开战布阵和结算 → 天启篇档由战斗键钉住（R3，待 Kyo 定方案第 4 节）；纯表现 → 随便取，行尾注「# 表现」。
## （另：掷完要给玩家看、不能重来的，掷完就把结果存下来，如抽角色候选 offer、深渊商人货架。）
## 不许用全局 randf／randi／randomize／shuffle／pick_random（07_开发环境/随机守卫.py 查）；确需的行尾注「# 表现」或「# 随机守卫：<理由>」。
##
## R1：seed-fix（cc/tianqi-seed-fix，dev.585）的 save_stream／save_roll／seeds_on／has_seed_id／on_register／before_renumber／
## all_gear／assign_all／seed_id／item_roll 原样搬到这里，派生字符串一字不改（老档的号和序列不变，tests/xiyou_tianqi_random 拿搬家前
## 生成的存档夹具逐件比）。XTianqi 留同名转发，保留一个发行版本后删。
## R2：第 2、3、5、7 类旧写法（drop_hash／qiyin_seed／merchant_roll／elements_seed／elements_rng）收进门面同名包装，公式与次序不变。
## 开关仍是 XTianqi.SEED_FROM_SAVE（O-449，搬家不换号；抽角色候选也认它，留在原处，随 R2 再看要不要挪）。
## 读档补号：XTianqiSave.after_load 末尾调 after_load（不受存档门面开关影响，只认 SEED_FROM_SAVE）。


## 存档派生的随机流：种子＝存档种子 orb_seed（随存档；更老的档由存档内容算出，XState.from_dict）＋ key。
## key 由调用方给：对象标识＋该对象的次数（计数随存档，调用方负责推进），同一次操作读档后种子相同，不同次、不同对象各自独立
static func save_stream(s: XState, key: String) -> XRandomStream:
	return XRandomStream.create(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tianqi|" + key), "tianqi_save")


## 同上，包成返回 [0,1) 的 Callable（重铸、异化用）；开关关着或没有存档时回到全局 randf
static func save_roll(s: XState, key: String) -> Callable:
	if s == null or not XTianqi.SEED_FROM_SAVE:
		return func(): return randf()  # 随机守卫：开关关时的旧路
	var st := save_stream(s, key)
	return func(): return st.next_float(key)


## 装备的随机身份 tq_seed_id：写在装备字典上随物品走，一经分配永不重编（instanceId、异化 uid 会在星辰仓库取出等路径上重编，
## 不能直接当随机身份）。号只取决于这件装备和本档存档种子，与先洗哪件、什么时候洗无关：
##   - 入包登记时（XState.register_gear，天启篇存档里所有产生装备的入口都经它）立刻分配，分两类：
##     ① 来源本身读档稳定的入口传来源键 source（固定货单商店、事件赠送、号角专属装备、招牌掉落、净印／遗物、七印揭开与神器、
##        天启篇商人、深渊商人、合成），号＝derive(orb_seed, "tq_seed_src|" + source + "|" + 本档该来源键的第几件)，
##        计数在 flags.tianqi.src_n[source]，只看同一来源，先拿别的来源的装备不影响它；
##     ② 来源本身随运行时随机的（普通战斗掉落等）不传，号＝derive(orb_seed, "tq_seed_id|" + instanceId)。这一类掉什么本来就随
##        运行时战斗流变，「普通掉落是否抗读档」是上层问题（R3）。
##   - 读档（XTianqiSave.after_load 末尾）和新开天启篇档时 assign_all 给还没号的老件一次性补号，遍历顺序写死：
##     背包 s.gear（列表顺序）→ 身上（角色号从小到大，每人 raw_equip_list 顺序）→ 各仓库（仓库名排序，类别按 XWarehouse.CATEGORIES，列表顺序）。
##     已有号的不动；新派生的号和已有号撞了（只有原版仓库复制那种同 instanceId 的复制品会撞）就按这个顺序加后缀，结果只取决于存档内容。
##   - 星辰仓库（跨存档）取出的老件在重编 instanceId 之前补号（before_renumber），号用旧 instanceId＋整件内容派生，与取出顺序无关。
## 复制装备的合法路径（魔冠账本重发、云裳订单发货、仓库原版复制）在复制时去掉它，复制品重新登记时另拿新号。
static func seeds_on(s: XState) -> bool:
	return s != null and XTianqi.SEED_FROM_SAVE and XTianqi.active(s)


static func _derive_seed_id(s: XState, who: String) -> String:
	return XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tq_seed_id|" + who)


static func _who(item: Dictionary) -> String:
	var iid := str(item.get("instanceId", ""))
	return iid if iid != "" else "noid|%d" % hash(JSON.stringify(item))


static func has_seed_id(item) -> bool:
	return item is Dictionary and XRandomStream.valid_hex(str(item.get("tq_seed_id", "")))


## 入包登记时调（XState.register_gear）；source 见上
static func on_register(s: XState, item: Dictionary, source := "") -> void:
	if not seeds_on(s) or has_seed_id(item):
		return
	if source == "":
		item["tq_seed_id"] = _derive_seed_id(s, _who(item))
		return
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("src_n") is Dictionary:
		tq["src_n"] = {}
	var n := int(tq.src_n.get(source, 0))
	tq.src_n[source] = n + 1
	item["tq_seed_id"] = XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tq_seed_src|%s|%d" % [source, n])


## 星辰仓库取出、重编 instanceId 之前调：没号的老件用旧 instanceId＋整件内容补号
static func before_renumber(s: XState, item: Dictionary) -> void:
	if seeds_on(s) and not has_seed_id(item):
		item["tq_seed_id"] = _derive_seed_id(s, "star|%s|%d" % [str(item.get("instanceId", "")), hash(JSON.stringify(item))])


## 本档全部装备，按补号的固定顺序（见上）
static func all_gear(s: XState) -> Array:
	var out: Array = s.gear.filter(func(e): return e is Dictionary)
	var ids := s.actors.keys()
	ids.sort()
	for id in ids:
		for e in s.actors[id].raw_equip_list():
			if e is Dictionary:
				out.append(e)
	var titles := s.warehouses.keys()
	titles.sort()
	for title in titles:
		var items = s.warehouses[title].get("items", {})
		for cat in XWarehouse.CATEGORIES:
			for e in (items.get(cat, []) if items is Dictionary else []):
				if e is Dictionary:
					out.append(e)
	return out


## 给本档还没号的装备补号（读档、新开档时）；已有号的不动
static func assign_all(s: XState) -> void:
	if not seeds_on(s):
		return
	var list := all_gear(s)
	var used := {}
	for e in list:
		if has_seed_id(e):
			used[str(e.tq_seed_id)] = true
	for e in list:
		if has_seed_id(e):  # 同一件出现两次（不该有）时第二次已有号，跳过
			continue
		var who := _who(e)
		var id := _derive_seed_id(s, who)
		var k := 1
		while used.has(id):
			k += 1
			id = _derive_seed_id(s, "%s|%d" % [who, k])
		e["tq_seed_id"] = id
		used[id] = true


## 掷的时候取号；正常都已在登记／读档时分好，没有的（没经登记的装备）先整档补一遍再取
static func seed_id(s: XState, item: Dictionary) -> String:
	if not has_seed_id(item):
		assign_all(s)
	if not has_seed_id(item):
		item["tq_seed_id"] = _derive_seed_id(s, _who(item))
	return str(item.tq_seed_id)


## 装备的存档派生流：种子＝随机身份 tq_seed_id＋domain＋装备上的次数 tq_rng_n（随装备存进存档；老装备没有当 0），
## 每开一条计数 +1。流只看装备自己带的东西，存进仓库再取出、换存档都还是那一串。
## 开关关着时不写装备、返回全局 randf
static func item_roll(s: XState, item: Dictionary, domain: String) -> Callable:
	if s == null or not XTianqi.SEED_FROM_SAVE:
		return func(): return randf()  # 随机守卫：开关关时的旧路
	var id := seed_id(s, item)
	var n := int(item.get("tq_rng_n", 0))
	item["tq_rng_n"] = n + 1
	var key := "%s|%d" % [domain, n]
	var st := XRandomStream.create(XRandomStream.derive(id, "tianqi_item|" + key), "tianqi_item")
	return func(): return st.next_float(key)


## 读档后（XTianqiSave.after_load 末尾，即 XState.from_dict 末尾）：老件补随机身份。以前直接挂在 from_dict
static func after_load(s: XState) -> void:
	assign_all(s)


# ---- R2：旧写法收进门面同名包装（公式不变、取数次序不变） ----

## 第 2 类（原 tianqi_drop.gd roll_signature）：招牌掉落，按掉落账种子＋键＋该键总次数做 sha256 取前 32 位
static func drop_hash(drop_seed: int, key: String, total: int) -> float:
	return float(("%d|%s|%d" % [drop_seed, key, total]).sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0


## 第 3 类（原 tianqi_qiyin.gd next_seed）：七印祭坛、七首之龙、首杀招募，按 qiyin.seed＋qiyin.rng_n 派生
static func qiyin_seed(s: XState, domain: String) -> String:
	if s == null or not XTianqiQiyin.SEED_FROM_SAVE:
		return XRandomStream.fresh_seed()  # 随机守卫：开关关时的旧路
	var p := XTianqiQiyin.progress(s)
	var n := int(p.rng_n)
	p.rng_n = n + 1
	return XRandomStream.derive(str(p.seed), "%s|%d" % [domain, n])


## 第 5 类（原 tianqi_merchant.gd draw）：天启篇深渊商人，按本轮种子＋已用次数×104729 构造线性同余流
static func merchant_roll(round_seed: int, used: int) -> Callable:
	return XAbyssMerchant.seed_random(round_seed + used * 104729)


## 第 7 类（原 tianqi_elements.gd derived_seed）：元素牌组存档种子，由 orb_seed＋难度 hash32
static func elements_seed(s: XState) -> int:
	if s == null:
		return 1
	var diff := str(s.flags.get("tianqi", {}).get("difficulty", "")) if s.flags.get("tianqi") is Dictionary else ""
	return XOrbs.hash32(JSON.stringify(["tianqi_elements", int(s.orb_seed), diff])) & 0x7fffffff


## 第 7 类（原 tianqi_elements.gd 楼层牌组／固定入口／骑士）：按元素种子与键拼接 hash 构造 RandomNumberGenerator（空键亦同原式）
static func elements_rng(elem_seed: int, key := "") -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s" % [elem_seed, key]).hash()
	return rng
