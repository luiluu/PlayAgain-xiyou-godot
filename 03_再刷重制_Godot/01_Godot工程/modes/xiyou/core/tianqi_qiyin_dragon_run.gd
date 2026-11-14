class_name XTianqiQiyinDragonRun
extends RefCounted
## 【cc·天启篇·未经审查】七首之龙的流程和战斗（七印祭坛方案 v0.4 第 3.1 节，Kyo 11-12 定稿）。
## 出现判定、龙隙存放、奖励、龙血的数和纯逻辑在 XTianqiQiyinDragon（qiyin_dragon.json）；这里接进祭坛流程、搭战斗。
## 流程表 tianqi_data/qiyin_dragon_run.json（借的敌群、能力值倍率、台词）；演出 XTianqiQiyinShow。
##
## - 出现：里副本 Boss 打赢后（结算之前）判一次；出了就演龙隙（地面裂开、七道印一起灭），掉落照常结算，然后当场问进不进。
##   不进就存着（最多 1 次，存着时不再判、暗保底不涨），祭坛菜单多一项「进龙隙」。不要印钥，输了龙隙合上。
## - 战斗：借 19 层副本古龙祭坛的普拉顿（敌群 221）换名「七首之龙」，生命取本档最大生命，每回合 3 次行动。
##   生命分七段，每断一首揭一道印，把那个里副本的规则搬进这一场（XTianqiQiyinRule 的规则照用，敌我都算），持续到下一首断掉。
##   开场就揭白印（open_reveal），第六首断掉揭默印，一场把七条规则依次过一遍；一次行动的伤害最多打到本段底（segment_lock）。
##   灰印那一段给我方一人挂「缓期」：2 回合后倒下，之前再断一首就解除。
## - 打赢：自选一印的真印套装件、龙血 1 瓶、33% 真印毕业武器、3% 神器（XTianqiQiyinDragon.reward）；东西照里副本进印库（封着，红光）。
##   首杀多招一人：当场在祭坛按本档 30 层那一档的招募表抽（可以稍后再选，留到下次开祭坛）。
## - 龙血：祭坛菜单「龙血」给一名角色喝，全属性 +3%，每人最多 3 瓶，只在本档（XActor.param_rate 乘 param_rate）。
##
## 开关 ENABLED（false＝不判龙隙、菜单不出、龙血不加；已存的龙隙和龙血留在存档里）。只在 XTianqiQiyin.allowed 的存档里。

const PATH := "res://modes/xiyou/tianqi_data/qiyin_dragon_run.json"
const META := "xqiyin_dragon"

## 开关：false＝七首之龙整个不出（龙隙不判、菜单不出、龙血不加成）
static var ENABLED := true

static var _data: Dictionary = {}
## prepare 过的下一场（BattleLogic.setup 取走）：{difficulty}
static var _pending: Dictionary = {}
## 测试注入：龙隙判定、奖励用的随机流。null 时：XTianqiQiyin 注入了测试流就用固定种子的一条（不动祭坛那条流的消耗，
## 祭坛专项照旧），否则由存档派生（XTianqiQiyin.save_rng）
static var rng_override: XRandomStream = null
const TEST_SEED := "7777777777777777"


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiQiyinDragonRun: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiQiyinDragonRun: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


static func _rng(s: XState = null) -> XRandomStream:
	if rng_override != null:
		return rng_override
	if XTianqiQiyin.rng_override != null:
		return XRandomStream.create(TEST_SEED, "qiyin_dragon")
	return XTianqiQiyin.save_rng(s, "qiyin_dragon")  # 存档派生（XTianqiQiyin.SEED_FROM_SAVE 关掉回到每次现开）


static func allowed(s: XState) -> bool:
	return ENABLED and XTianqiQiyin.allowed(s)


## 本档的龙记录（flags.tianqi.qiyin.dragon，字段见 XTianqiQiyinDragon.new_state）；另记 recruit（首杀招募还没领）、offer（招募候选）
static func state(s: XState) -> Dictionary:
	var p := XTianqiQiyin.progress(s)
	if not p.get("dragon") is Dictionary:
		p["dragon"] = XTianqiQiyinDragon.new_state()
	return p["dragon"]


## 存回（纯逻辑模块返回的新状态；本模块自己加的 recruit、offer 留着）
static func _put(s: XState, ns: Dictionary) -> void:
	var old := state(s)
	for k in ["recruit", "offer"]:
		if old.has(k) and not ns.has(k):
			ns[k] = old[k]
	XTianqiQiyin.progress(s)["dragon"] = ns


static func fight_info() -> Dictionary:
	var v = data().get("fight")
	return v if v is Dictionary else {}


# ---- 台词 ----

static func say(host, key: String, args := []) -> void:
	var rows = data().get("scenes", {}).get(key)
	if not rows is Array:
		return
	for row in rows:
		await host.show_text("", 0, [XTianqiQiyin._line(row, args)])


static func ask(host, key: String, options: Array, args := []) -> int:
	var rows = data().get("scenes", {}).get(key, [])
	var head := XTianqiQiyin._line(rows[0], args) if rows is Array and not rows.is_empty() else ""
	return await host.show_text_with_choices("", 0, [head], options, options.size() - 1)


static func _log(key: String, args := []) -> String:
	var t := str(data().get("logs", {}).get(key, ""))
	return t % args if not args.is_empty() else t


# ---- 祭坛流程 ----

## 里副本 Boss 打赢后、结算之前（XTianqiQiyin.run_dungeon）：判龙隙，出了就演一下。返回出没出
static func after_boss(host, s: XState, rng: XRandomStream = null) -> bool:
	if not allowed(s):
		return false
	if rng == null:
		rng = _rng(s)
	var r := XTianqiQiyinDragon.roll_rift(state(s), XTianqiQiyin.difficulty_key(s), rng)
	_put(s, r.state)
	if not bool(r.get("appeared", false)):
		return false
	if host != null:
		await XTianqiQiyinShow.rift(host)
		await say(host, "rift_open")
	return true


## 结算之后：刚出现的龙隙当场问进不进；不进就存着。返回 -1 没问，0 打赢，1 输了，2 存着
static func offer(host, s: XState, appeared: bool) -> int:
	if not appeared or str(state(s).rift) != XTianqiQiyinDragon.RIFT_OFFERED:
		return -1
	var i: int = await ask(host, "rift_ask", ["进去", "先存着（回去整队再来）"])
	if i == 0:
		return await run_fight(host, s)
	_put(s, XTianqiQiyinDragon.store_rift(state(s)).state)
	await say(host, "rift_stored")
	return 2


## 祭坛菜单要加的项（XTianqiQiyin.altar_options，在「离开」之前）
static func altar_options(s: XState) -> Array:
	if not allowed(s):
		return []
	var d := state(s)
	var out := []
	if str(d.rift) == XTianqiQiyinDragon.RIFT_STORED:
		out.append({"id": "dragon", "label": "进龙隙（七首之龙）"})
	if bool(d.get("recruit", false)):
		out.append({"id": "dragon_recruit", "label": "龙的馈赠：招募一名伙伴"})
	if int(d.blood_stock) > 0:
		out.append({"id": "dragon_blood", "label": "龙血（%d 瓶）" % int(d.blood_stock)})
	return out


## 祭坛菜单选了本模块的项（XTianqiQiyin.run_altar）
static func run_option(host, s: XState, id: String) -> void:
	match id:
		"dragon":
			await run_fight(host, s)
		"dragon_recruit":
			await run_recruit(host, s)
		"dragon_blood":
			await run_blood(host, s)


## 进龙隙打一场：0 打赢，1 输了，-1 没有龙隙
static func run_fight(host, s: XState) -> int:
	var en := XTianqiQiyinDragon.enter_rift(state(s))
	if en.has("error"):
		return -1
	_put(s, en.state)
	await say(host, "enter")
	var tone_before: Array = s.screen.tone.duplicate() if s.screen.tone is Array else [0, 0, 0, 0]
	s.screen.start_tint(fight_info().get("tone", [0, 0, 0, 0]), 0)
	prepare(XTianqiQiyin.difficulty_key(s))
	var r: int = await host.start_battle(int(fight_info().get("troop", 0)), false, true)
	_pending = {}
	s.screen.start_tint(tone_before, 0)
	if r != 0:
		_put(s, XTianqiQiyinDragon.lose_rift(state(s)).state)
		await say(host, "lost")
		return 1
	await say(host, "win")
	await settle(host, s)
	return 0


## 打赢的奖励：选印 → XTianqiQiyinDragon.reward → 进印库、龙血、首杀招募。返回进印库的物品（测试用）
static func settle(host, s: XState, rng: XRandomStream = null) -> Array:
	if rng == null:
		rng = _rng(s)
	var seals := XTianqiQiyinDragon.seals()
	var labels: Array = seals.map(func(k): return "%s（%s）" % [str(XTianqiQiyin.seal_info(k).get("seal", k)),
		str(XTianqiQiyinGear.set_of(k).get("name", ""))])
	var i: int = await ask(host, "pick_seal", labels)
	var chosen := str(seals[clampi(i, 0, seals.size() - 1)])
	var r := XTianqiQiyinDragon.reward(state(s), chosen, rng, not XTianqiQiyin.ARTIFACT_PITY)
	if r.has("error"):
		push_error("XTianqiQiyinDragonRun: reward " + str(r.error))
		return []
	_put(s, r.state)
	if XTianqiQiyin.ARTIFACT_PITY:  # 神器保底、防重（和里副本共用计数），掷的位置同原来（奖励的最后一步）
		var art0 := XTianqiQiyin.roll_artifact(s, float(XTianqiQiyinDragon.data().get("reward", {}).get("artifact_chance", 0.0)), rng, "qiyin_dragon.artifact")
		r.artifact = art0 if art0 != "" else null
	var got := []
	var ts: Dictionary = r.true_set_piece
	got.append({"kind": XTianqiQiyinDrop.KIND_SET, "seal": str(ts.seal), "part": str(ts.part), "true_seal": true,
		"grades": XTianqiQiyinDrop._roll_grades(true, rng)})
	if r.weapon is Dictionary:
		var cls := XTianqiQiyinDrop.weapon_classes(str(r.weapon.seal))
		var wtype := str(cls[rng.next_index_mod(cls.size(), "qiyin_dragon.wtype")]) if not cls.is_empty() else ""
		got.append({"kind": XTianqiQiyinDrop.KIND_WEAPON, "seal": str(r.weapon.seal), "wtype": wtype, "true_seal": true,
			"grades": XTianqiQiyinDrop._roll_grades(true, rng)})
	var first_idx: int = XTianqiQiyin.progress(s).bag.size()
	for item in got:
		XTianqiQiyin._stash(s, item)
	var art := str(r.artifact) if r.artifact != null else ""
	if art != "":
		XTianqiQiyin.progress(s).artifacts.append(art)
	if bool(r.extra_recruit):
		state(s)["recruit"] = true
	await say(host, "drop_head")
	for item in got:
		await XTianqiQiyinShow.drop(host, item)
		await host.show_text("", 0, [XTianqiQiyin.sealed_label(item)])
	if art != "":
		await XTianqiQiyinShow.artifact(host, art)
		await host.show_text("", 0, ["神器「%s」" % str(XTianqiQiyinGear.artifact(art).get("name", art))])
	await say(host, "blood_get", [int(r.dragon_blood)])
	var c: int = await host.show_text_with_choices("", 0, ["现在就揭开吗？"], ["揭开", "先收着"], 1)
	if c == 0:
		for idx in range(first_idx, first_idx + got.size()):
			var it := XTianqiQiyin.reveal(s, idx)
			await XTianqiQiyinShow.reveal(host, it)
			await host.show_text("", 0, [XTianqiQiyin._line(XTianqiQiyin.scene("reveal_done")[0], [XTianqiQiyin.revealed_label(it)])])
	if bool(r.extra_recruit):
		await say(host, "recruit_get")
		await run_recruit(host, s)
	return got


# ---- 首杀招募 ----

## 首杀多招一人用的招募表那一次（本档 recruit_floor 层那一档）
static func recruit_rule(s: XState) -> Dictionary:
	var fl := int(XTianqiQiyinDragon.data().get("reward", {}).get("recruit_floor", 30))
	return XTianqi.draw_rule(s, fl / XTianqi.DRAW_EVERY - 1)


## 候选：X 选一掷一次就记进存档（state.offer），不能重抽；自选（count 0）给整池
static func recruit_offer(s: XState, rng: RandomNumberGenerator = null) -> Array:
	var r := recruit_rule(s)
	if r.is_empty():
		return []
	var pool := XTianqi.draw_pool(s, r.tiers)
	if int(r.count) <= 0:
		return pool
	var saved = state(s).get("offer")
	if saved is Array and not saved.is_empty() and saved.all(func(id): return pool.has(int(id))):
		return saved.map(func(id): return int(id))
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = XRandomStream.parse64(XTianqiQiyin.next_seed(s, "qiyin_recruit"))  # 存档派生：读档不能重抽候选（O-427）
	XTianqi._shuffle(pool, rng)
	var offer := pool.slice(0, int(r.count))
	state(s)["offer"] = offer
	return offer


## 收下一位：在候选里才收，入队、清掉招募标记
static func take_recruit(s: XState, id: int) -> bool:
	if not bool(state(s).get("recruit", false)) or not recruit_offer(s).has(id):
		return false
	XTianqi._joining = true
	s.add_actor(id)
	XTianqi._joining = false
	state(s).erase("recruit")
	state(s).erase("offer")
	return s.party.has(id)


static func run_recruit(host, s: XState) -> void:
	if not bool(state(s).get("recruit", false)):
		return
	var r := recruit_rule(s)
	var offer := recruit_offer(s)
	if r.is_empty() or offer.is_empty():
		state(s).erase("recruit")  # 没有候选（档位里的人都在队里了）：这次招募作废
		return
	var opts: Array = offer.map(func(id): return XTianqi._actor_label(int(id)))
	opts.append("稍后再选")
	var head := "龙的馈赠：可以多招募一名伙伴（%s）。" % "／".join(r.tiers)
	var i: int = await host.show_text_with_choices("", 0, XTianqi._line(head), opts, opts.size() - 1)
	if i < 0 or i >= offer.size():
		return
	if take_recruit(s, int(offer[i])):
		await host.show_text("", 0, XTianqi._line("%s加入了队伍。" % XTianqi._actor_label(int(offer[i]))))


# ---- 龙血 ----

static func run_blood(host, s: XState) -> void:
	while int(state(s).blood_stock) > 0:
		var ids: Array = s.party.duplicate()
		var opts: Array = ids.map(func(id): return "%s（已喝 %d 瓶）" % [str(XDB.rec("Actors", int(id)).get("name", "")),
			int(state(s).blood.get(str(id), 0))])
		opts.append("返回")
		var bl: Dictionary = XTianqiQiyinDragon.data().get("dragon_blood", {})
		var i: int = await ask(host, "blood_head", opts, [int(state(s).blood_stock), int(bl.get("max_per_actor", 0)),
			roundi(float(bl.get("per_bottle", 0.0)) * 100.0)])
		if i < 0 or i >= ids.size():
			return
		var name := str(XDB.rec("Actors", int(ids[i])).get("name", ""))
		var r := drink(s, int(ids[i]))
		if bool(r.ok):
			await say(host, "blood_done", [name, int(state(s).blood.get(str(ids[i]), 0))])
		else:
			await say(host, "blood_full", [name])


## 给一名角色喝一瓶（XTianqiQiyinDragon.drink），喝完刷新能力值
static func drink(s: XState, actor_id: int) -> Dictionary:
	var r := XTianqiQiyinDragon.drink(state(s), str(actor_id))
	_put(s, r.state)
	if bool(r.ok):
		var a := s.actor(actor_id)
		if a != null:
			a.param_mark_dirty()
	return r


## XActor.param_rate 乘这个：喝过的龙血 × 3%（全属性）。没喝、原版档、开关关掉都是 1
static func param_rate(a, _i: int) -> float:
	if not ENABLED:
		return 1.0
	var s := XState.current
	if s == null:
		return 1.0
	var t = s.flags.get("tianqi")
	if not t is Dictionary:
		return 1.0
	var q = t.get("qiyin")
	if not q is Dictionary:
		return 1.0
	var d = q.get("dragon")
	if not d is Dictionary or not d.get("blood") is Dictionary or d.blood.is_empty():
		return 1.0
	return 1.0 + XTianqiQiyinDragon.bonus(d, str(a.actor_id))


# ---- 战斗（BattleLogic 挂钩）----

## 下一场按七首之龙打
static func prepare(difficulty: String) -> void:
	_pending = {"difficulty": difficulty}


static func pending() -> Dictionary:
	return _pending


static func active(logic) -> bool:
	return logic != null and logic.has_meta(META)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if active(logic) else {}


## 龙那只
static func dragon(logic) -> XEnemy:
	var f := fight(logic)
	var i := int(f.get("index", -1))
	return logic.enemies[i] if i >= 0 and i < logic.enemies.size() else null


## BattleLogic.setup（各线异化之前）：借来的那只换成七首之龙，建七段；规则记录在 setup_rules 里建
static func setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	var p := _pending
	_pending = {}
	if p.is_empty() or not allowed(s):
		return
	var fd := XTianqiQiyinDragon.fight_data(str(p.difficulty))
	if fd.is_empty():
		return
	var info := fight_info()
	var idx := -1
	for i in logic.enemies.size():
		if int(logic.enemies[i].enemy_id) == int(info.get("shell_enemy", -1)) and logic.enemies[i].horseman.is_empty():
			idx = i
			break
	if idx < 0:
		return
	var e: XEnemy = logic.enemies[idx]
	var rb: Dictionary = XTianqiQiyin.data().get("rebase", {})
	var ref: Array = XDB.rec("Enemies", int(rb.get("ref", 0))).get("params", [])
	var rec: Dictionary = XDB.rec("Enemies", int(info.shell_enemy)).duplicate(true)
	var rate: Array = info.get("rate", [])
	var params := []
	for i in 8:
		var v := float(ref[i]) * (float(rate[i]) if i < rate.size() else 1.0) if ref.size() >= 8 else float(rec.params[i])
		params.append(roundf(v))
	# 生命：先除掉难度倍率 _rates（里面已经乘了本档敌人血量），换上之后再按实际量的校一次
	params[0] = maxf(1.0, roundf(float(fd.max_hp) / maxf(0.0001, float(e._rates[0]))))
	rec.params = params
	rec.name = str(info.get("name", "七首之龙"))
	rec["_ref"] = "dragon"  # 守层者重算（XGuardianRework）：按鸿蒙老祖重标的，出伤跟 33 层一档
	rec.dropItems = []
	rec.note = "NoElite"  # 普拉顿备注里的 <hp: …>、<Enemy Drops>、<Capture> 等不跟着借（同骑士的合成记录）
	rec.meta = {}
	XTianqiQiyinArt.dress_battler(rec, str(info.get("battler", "")))
	rec.exp = 0
	rec.gold = 0
	var traits: Array = rec.get("traits", []).duplicate(true)
	for k in int(info.get("extra_actions", 0)):
		traits.append({"code": 61, "dataId": 0, "value": 1.0})
	rec.traits = traits
	e.horseman = {"rec": rec, "knight": false}
	e.refresh_passive()
	e.recover_all()
	# 借来的普拉顿身上还有能力值比率等特性：按量出来的最大生命再校一次，最后正好是本档的 max_hp
	if e.mhp > 0.0 and absf(e.mhp - float(fd.max_hp)) > 1.0:
		params[0] = roundf(float(params[0]) * float(fd.max_hp) / e.mhp)
		rec.params = params
		e.param_mark_dirty()
		e.refresh_passive()
		e.recover_all()
	# 段底：第 k 首断掉的生命线（最后一段到 0）
	var floors := []
	var left := float(e.mhp)
	var total := 0.0
	for v in fd.segment_hp:
		total += float(v)
	for v in fd.segment_hp:
		left -= float(v) * float(e.mhp) / maxf(1.0, total)
		floors.append(maxf(0.0, roundf(left)))
	floors[floors.size() - 1] = 0.0
	var f := {"index": idx, "floors": floors, "cut": 0, "segments": int(fd.segments), "order": fd.reveal_order,
		"grey": fd.grey_reprieve, "reprieve": {}, "revealed": -1, "logs": []}
	logic.set_meta(META, f)


## BattleLogic.setup（XTianqiQiyinRule.setup 之后）：建规则记录（XTianqiQiyinRule 的七条规则照用），开场揭第一道印
static func setup_rules(logic) -> void:
	if not active(logic):
		return
	var f := fight(logic)
	var info := fight_info()
	var rule := {"seal": "", "rule": "", "boss": true, "gems": {}, "queue": [], "skills_used": 0, "side_bonus": "",
		"silent": false, "dragon": true}
	logic.set_meta(XTianqiQiyinRule.META, rule)
	_push(logic, _log("open", [int(f.segments)]))
	if bool(info.get("open_reveal", true)):
		_reveal(logic, 0)
	rule.queue.append_array(f.logs)
	f.logs = []


static func _push(logic, text: String) -> void:
	fight(logic).logs.append({"type": "battle_text", "text": text})


## 揭第 n 道印（0 起）：规则换成那一印的；灰印挂缓期；离开灰印那段解缓期
static func _reveal(logic, n: int) -> void:
	var f := fight(logic)
	var order: Array = f.order
	if n < 0 or n >= order.size():
		return
	var key := str(order[n])
	var info := XTianqiQiyin.seal_info(key)
	var rule := XTianqiQiyinRule.fight(logic)
	if rule.is_empty() or info.is_empty():
		return
	_clear_reprieve(logic)
	rule.seal = key
	rule.rule = str(info.rule)
	rule.side_bonus = ""
	rule.silent = str(info.rule) == "silence" and int(logic.turn) % 2 == 0 and int(logic.turn) > 0
	f.revealed = n
	_push(logic, _log("reveal", [n + 1, str(info.seal), str(info.rule_name), str(info.rule_text)]))
	if key == str(f.grey.get("seal", "")):
		_put_reprieve(logic)


static func _put_reprieve(logic) -> void:
	var f := fight(logic)
	var alive: Array = logic.actors.filter(func(a): return a.is_alive())
	if alive.is_empty():
		return
	var a = alive[logic._rule().next_index_mod(alive.size(), "qiyin_dragon.reprieve")]
	var turns := int(f.grey.get("turns", 2))
	f.reprieve = {"actor": a, "due": int(logic.turn) + turns}
	_push(logic, _log("reprieve_on", [a.display_name(), turns]))


static func _clear_reprieve(logic) -> void:
	var f := fight(logic)
	if not f.reprieve.is_empty():
		f.reprieve = {}
		_push(logic, _log("reprieve_off"))


## 生命到了段底就断首（一次可能断几首）；断了揭下一道印
static func _check_cuts(logic) -> void:
	var f := fight(logic)
	var e := dragon(logic)
	if e == null or e.hidden:
		return
	var floors: Array = f.floors
	var open := bool(fight_info().get("open_reveal", true))
	while int(f.cut) < floors.size() - 1 and e.hp <= float(floors[int(f.cut)]):
		f.cut = int(f.cut) + 1
		_push(logic, _log("cut", [int(f.cut), int(f.segments) - int(f.cut)]))
		_reveal(logic, int(f.cut) if open else int(f.cut) - 1)
	if e.is_dead() and int(f.cut) < floors.size():
		f.cut = floors.size()
	XTianqiQiyinArt.dragon_cut(e, f.order, int(f.cut))


static func _take(logic) -> Array:
	var f := fight(logic)
	var out: Array = f.logs
	f.logs = []
	return out


## BattleLogic.execute_hp_damage（XTianqiQiyinRule.hp_damage 之后）：segment_lock 时一次行动最多打到本段底
static func hp_damage(logic, t, value: float) -> float:
	if not active(logic) or value <= 0.0 or t != dragon(logic) or not bool(fight_info().get("segment_lock", true)):
		return value
	var f := fight(logic)
	var floors: Array = f.floors
	if int(f.cut) >= floors.size() - 1:
		return value
	var floor_hp := float(floors[int(f.cut)])
	return minf(value, maxf(0.0, t.hp - floor_hp))


## BattleLogic.act 收尾（end_action）：断首、揭印
static func end_action(logic) -> Array:
	if not active(logic):
		return []
	_check_cuts(logic)
	return _take(logic)


## BattleLogic.start_turn（XTianqiQiyinRule.start_turn 之后）：星坠等扣过之后再看断首；缓期到点就倒下
static func start_turn(logic) -> Array:
	if not active(logic):
		return []
	_check_cuts(logic)
	var f := fight(logic)
	var rp: Dictionary = f.reprieve
	if not rp.is_empty() and int(logic.turn) >= int(rp.due):
		var a = rp.actor
		f.reprieve = {}
		if a != null and a.is_alive():
			a.hp = 0.0
			logic._die(a)
			_push(logic, _log("reprieve_fall", [a.display_name()]))
	return _take(logic)
