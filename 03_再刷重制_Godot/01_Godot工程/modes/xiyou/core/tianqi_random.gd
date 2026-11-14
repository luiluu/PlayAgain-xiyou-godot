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
## 5. 战斗：回合内 → 规则流；开战布阵和结算 → 天启篇档由战斗键钉住（R3：battle_random，战斗键＝敌群号｜本档打这个敌群的第几次）；
##    纯表现 → 随便取，行尾注「# 表现」。
## （另：掷完要给玩家看、不能重来的，掷完就把结果存下来，如抽角色候选 offer、深渊商人货架。）
## 不许用全局 randf／randi／randomize／shuffle／pick_random（07_开发环境/随机守卫.py 查）；确需的行尾注「# 表现」或「# 随机守卫：<理由>」。
##
## R1：seed-fix（cc/tianqi-seed-fix，dev.585）的 save_stream／save_roll／seeds_on／has_seed_id／on_register／before_renumber／
## all_gear／assign_all／seed_id／item_roll 原样搬到这里，派生字符串一字不改（老档的号和序列不变，tests/xiyou_tianqi_random 拿搬家前
## 生成的存档夹具逐件比）。XTianqi 留同名转发，保留一个发行版本后删。
## R2：第 2、3、5、7 类旧写法（drop_hash／qiyin_seed／merchant_roll／elements_seed／elements_rng）收进门面同名包装，公式与次序不变。
## 开关仍是 XTianqi.SEED_FROM_SAVE（O-449，搬家不换号；抽角色候选也认它，留在原处，随 R2 再看要不要挪）。
## 读档补号：XTianqiSave.after_load 末尾调 after_load（不受存档门面开关影响，只认 SEED_FROM_SAVE）。
##
## R3（cc/tianqi-random-r3，协调批复：战斗键＝敌群号＋本档打这个敌群第几次；开战布阵掷的算结果一起钉；西游档不钉）：
## - battle_random：天启篇档开战取战斗流，rule／pet 照旧运行时（XState.reserve_battle_random），另按战斗键钉一条种子
##   （XBattleRandom.pin）：布阵阶段（BattleLogic.setup 整段：神话／精英判定、敌人等级、按段异化挂谁、七印书卷、初始 TP、开战状态
##   及其回合数）取 setup 流；结算（敌人掉落与删栏重抽按敌人分子流、通用掉落、异化装备、元素书、米拉、流萤残核，grant／end_battle
##   里各段规则取数）取 reward_for(键)。先手／偷袭（roll_encounter，在 setup 之后）、回合内的暴击命中 AI 照旧 rule。
##   计数 flags.tianqi.rng["battle|敌群号"]，随存档；note_battle 在 setup 里推进（回放从开战前的档重放也推到同一个数）。
## - create_gear：带来源键的装备生成（XState.gain_gear、异化装备掉落）时，底子数值（属性浮动、插槽、强化随机）改走
##   derive(orb_seed, "tq_gear_src|来源键|该来源第几件")，并用一份空的预掷池（rom.x／xs），生成完还原，所以只看来源键、
##   不受先拿了别的装备影响；镶嵌孔数也按来源键（socket_number 代替实例编号）；天启篇词条仍按 affix_src 那一路（同一来源键的不同域，互不挪号）。
##   深渊商人等自己设了 XGear.roll_fn 的、测试磁带（roll_seq／force_roll）照旧优先，不绑。

## 开关：BATTLE_FROM_SAVE（战斗钉住）、GEAR_BASE_FROM_SAVE（底子钉住），同一个 O 号（O-464），false 各自回到运行时流。
static var BATTLE_FROM_SAVE := true
static var GEAR_BASE_FROM_SAVE := true
## create_gear 正在用来源键底子流（XTianqiAffixRoll._default_rng 据此不把它当成深渊商人的 roll_fn）
static var gear_binding := false


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


# ---- B 战斗（R3） ----

static func battle_on(s: XState) -> bool:
	return s != null and BATTLE_FROM_SAVE and XTianqi.active(s)


static func _battle_domain(troop_id: int) -> String:
	return "battle|%d" % troop_id


## 本档下一次打这个敌群的战斗键「敌群号|第几次」（只看，不推进）
static func battle_key(s: XState, troop_id: int) -> String:
	var rng = s.flags.get("tianqi", {}).get("rng")
	var n := int(rng.get(_battle_domain(troop_id), 0)) if rng is Dictionary else 0
	return "%d|%d" % [troop_id, n]


## BattleLogic.setup 没给战斗流时取：rule／pet 照旧运行时；天启篇档另按战斗键钉住布阵与结算
static func battle_random(s: XState, troop_id: int) -> XBattleRandom:
	var out := s.reserve_battle_random()
	if battle_on(s):
		var key := battle_key(s, troop_id)
		out.pin(key, XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "battle|" + key))
	return out


## 钉住的本场里按战斗得到的装备的来源键 b|战斗键|who（心之钢、狂妄这类结算奖励）；没钉住（西游档、关开关、测试自建的流）返回空＝照旧
static func battle_source(logic, who: String) -> String:
	var r = logic.get("random") if logic is Object else null  # 测试替身没有 random 属性时当没钉住
	return "b|%s|%s" % [r.battle_key, who] if r is XBattleRandom and r.pinned() else ""


## BattleLogic.setup 里调：本场钉住的话，把这个敌群的计数推到战斗键之后（回放从开战前的档重放也推到同一个数）
static func note_battle(s: XState, random: XBattleRandom) -> void:
	if s == null or random == null or not random.pinned() or not s.flags.get("tianqi") is Dictionary:
		return
	var parts := random.battle_key.split("|")
	if parts.size() != 2:
		return
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("rng") is Dictionary:
		tq["rng"] = {}
	var dom := _battle_domain(int(parts[0]))
	tq.rng[dom] = maxi(int(tq.rng.get(dom, 0)), int(parts[1]) + 1)


# ---- A 装备底子（R3，方案 2.5） ----

static func gear_base_on(s: XState) -> bool:
	return GEAR_BASE_FROM_SAVE and seeds_on(s) and not XGear.roll_fn.is_valid() and XGear.roll_seq.is_empty() and XGear.force_roll < 0


## 有来源键的装备的底子流：derive(orb_seed, "tq_gear_src|来源键|n")，n＝本档该来源键已登记几件（on_register 随后用同一个 n 分配随机身份）
static func gear_stream(s: XState, source: String) -> Callable:
	var src_n = s.flags.tianqi.get("src_n")
	var n := int(src_n.get(source, 0)) if src_n is Dictionary else 0
	var key := "tq_gear_src|%s|%d" % [source, n]
	var st := XRandomStream.create(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), key), "tianqi_gear")
	return func(): return st.next_float(key)


## 带来源键的装备排孔用的编号（代替实例编号，同一个哈希式，分布不变）：derive(orb_seed, "tq_gear_socket|来源键|n") 的低 31 位
static func socket_number(s: XState, source: String) -> int:
	var src_n = s.flags.tianqi.get("src_n")
	var n := int(src_n.get(source, 0)) if src_n is Dictionary else 0
	return XRandomStream.parse64(XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "tq_gear_socket|%s|%d" % [source, n])) & 0x7fffffff


## 生成一件装备（不登记）：天启篇词条按来源键（source_hint）；有来源键且 gear_base_on 时底子也按来源键、用空预掷池
static func create_gear(s: XState, kind: String, base_id: int, source := "") -> Dictionary:
	XTianqiAffixRoll.source_hint = source  # 天启篇词条也按来源键掷（XTianqiAffixRoll._default_rng）
	if source == "" or not gear_base_on(s):
		var plain := XGear.create(kind, base_id, s)
		XTianqiAffixRoll.source_hint = ""
		return plain
	var saved := {}
	for k in ["x", "xn", "xs", "xsn"]:
		saved[k] = s.rom.get(k)
	s.rom.x = []
	s.rom.xn = 0
	s.rom.xs = []
	s.rom.xsn = 0
	XGear.roll_fn = gear_stream(s, source)
	gear_binding = true
	var inst := XGear.create(kind, base_id, s)
	gear_binding = false
	XGear.roll_fn = Callable()
	# 镶嵌孔数：原版按 orb_seed＋实例编号哈希（先拿了别的装备就会挪号）；这里先按来源键给一个编号排好孔，register_gear 见已有孔不再排
	XOrbs.layout(inst, s.orb_seed, socket_number(s, source))
	for k in saved:
		if saved[k] == null:
			s.rom.erase(k)
		else:
			s.rom[k] = saved[k]
	XTianqiAffixRoll.source_hint = ""
	return inst
