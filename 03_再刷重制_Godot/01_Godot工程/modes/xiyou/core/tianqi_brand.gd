class_name XTianqiBrand
extends RefCounted
## 【cc·T117·未经审查】天启篇烙印本体（设计仓库《天启篇_烙印 v0.5》第三、五、九、十节，第十三节 T073-b）。
## 开关 ENABLED 默认关（T073-e 翻）；关着时下面每个入口都是「没有烙印」：mult 恒 1、不建存档键、闭关菜单照原来的真气。
##
## 一条线（D150）：烙印 0～100%（存档按万分点整数存，1% ＝ 100），只涨不降。七境各有一个节点（10／25／40／55／70／85／100），
## 烙印涨到本境节点就停，打赢心魔（stand）立入下一境。不刻印的人（甲二）停在铸骨、封顶 40%，不放第 3 场心魔。
##
## | 入口 | 干什么 | 谁调 |
## |---|---|---|
## | mult(角色) | 伤害乘数 1 ＋ 50% × 烙印（只读烙印，不读境、不读刻没刻） | XTianqiBase.k_actor_mult（K 那一项的口子） |
## | battle_setup(logic, s) | 开战时认这一场：特殊战／首领战／不是首领战、合成战斗键、档位、生熟（整场不变） | XBattleLogic.setup 末尾 |
## | settle(logic) | 打赢后：首通、再打、烙实（灼痕满过几次；T073-d2 之前按 0 条）、记首胜 | XBattleLogic.grant |
## | gain(s, 角色, 来源, 量) | 唯一的写入口：万分点四舍五入、封顶、到节点时提示 | settle |
## | carve／stand／can_stand | 刻印；打赢心魔立境；能不能打本境心魔（甲二门禁） | XZhenqi 闭关菜单 |
## | panel(s, 角色) | 面板：亮段、刻度线、「+」、暗段、封住段、瓶颈高亮 | XZhenqi 闭关菜单 |
## | has_cost(角色, key) | T073-c 常驻六条：烙印 **超过** 那一条的节点（万分点）才有（P2-1：不判境） | 下面六个口子 |
## | aggro_mult(logic, 敌人, 角色) | 外人项（2 − 烙印÷100）× 出头鸟（过 10%、上一回合打过敌人 ×2） | BattleLogic._random_target |
## | def_rate(角色, i) | 皮薄：过 25% 每多 3 点物防、魔防 −1%，100% 时 −25% | XActor.param_rate |
## | heal(角色, 量) | 虚不受补：过 40%、生命一半以上时受到的回复 ×0.5（各线削减之后乘） | XResourceContext._gain、BattleLogic._regenerate |
## | filter_group(logic, 施放者, 技能, 目标) | 不合群：过 55%，队友放的全体友方（scope 8）落不到身上 | BattleLogic.targets_for |
## | burn(logic, 角色) | 烧命：过 70%，每次出手前付当前生命 4%（扣不死、不算受到伤害） | BattleLogic.act |
## | blocks_revive／on_revive | 一条命：过 70% 一场只能被复活一次，过 85% 不能被复活；战斗外不拦 | XBattler.remove_state(1) |
## | start_turn(logic) | T073-d1 自己疯：回合开始掷、顺延的先发；保护（隔 2 回合、同回合最多 2 人、生 1／熟 3 回合不掷） | BattleLogic.start_turn 末尾 |
## | forced_action(logic, 角色) | 行动入口最顶上：发呆／断片空过、哑火普攻敌人、抽自己、六亲不认 | BattleLogic.brand_forced ← BattleScene._command 最顶上、decide、run_turn、XBattleReplay |
## | perform(logic, 角色, 合成技能, 目标) | 合成技能换成真的行动；抽自己、六亲不认那一下（15% 封顶、打不倒、不暴击、烙印加成按 1） | BattleLogic.act 开头 |
## | taken_mult(角色) | 破防：这一回合和下一回合受到的生命伤害 ×1.3 | XDamage 天启篇乘区、XTianqiHorsemen._strike |
## | trigger(logic, 角色, 来源) | 被打疯（T073-d2 灼痕满了调）：同一套保护，不能开始就顺延 | （d2） |
##
## 存档（稿第九节）：角色 XActor.zhenqi 的 brand／brand_carved／brand_realm（XZhenqi.from_save 只在读进来的数据里本来就有时原样留）；
## 首胜表在 flags.tianqi.brand.firsts（XTianqiSave 分区 brand，稿里叫 brand_firsts）：战斗键 → 打赢时的最高档位。西游档一个字不读不写。

const PATH := "res://modes/xiyou/tianqi_data/brand.json"
const META := "tianqi_brand"
## 玩家可见文字（交付单单列，合前过小A 文字审）。T140（Kyo 11-17、D174）：玩家看到的不用「境」「锚」作总称，说「加深」＋七段原名（守一～逆命）；
## 代码里 realm／立境 这些内部名不动。%s 依次是角色名、这一段的名字（stage_name）。
const TEXT_BOTTLENECK := "%s 的烙印已到「%s」的极限，打赢心魔才能继续加深"
const TEXT_NO_GAIN := "%s 的烙印已到「%s」的极限，本场未再加深。"
const TEXT_GAIN := "烙印 %s"
const TEXT_CARVE_WARN := ["一旦刻印，烙印只涨不降，没有回头路。", "刻印后，每首通一位守层者都会加深烙印；不刻印则只在首领战挨打时记下烙印，上限 40%。"]
const TEXT_RETREAT := ["\\C[6]烙印\\C[0]", "烙印随首领战加深；每次到达极限，打赢心魔才能继续加深。", "未刻印的烙印最多加深至「铸骨」（40%），刻印后才能继续加深。"]

static var ENABLED := false

static var _data: Dictionary = {}
## 本进程发过的烙印提示（测试核对）
static var toasts: Array = []
## 事件开战（mv_interpreter 301）时记下的地图、事件、敌群；BattleLogic.setup 吃掉（敌群不符作废）
static var pending_event := {}
## 正在打的这一场（battle_setup 记，end_battle 开头清）：一条命、虚不受补只在战斗里算
static var _logic_ref: WeakRef = null


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiBrand: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiBrand: JSON 解析失败 " + PATH)
	return _data


static func clear_cache() -> void:
	_data = {}


## 开关开着、而且是天启篇存档
static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s)


static func scale() -> int:
	return int(data().get("store_scale", 100))


# ---- 角色上的三个键 ----

static func _raw(a) -> int:
	return int(a.zhenqi.get("brand", 0)) if a is XActor else 0


static func realm(a) -> int:
	return int(a.zhenqi.get("brand_realm", 0)) if a is XActor else 0


static func carved(a) -> bool:
	return a is XActor and int(a.zhenqi.get("brand_carved", 0)) != 0


## 第 i 境的节点（万分点）
static func node_of(i: int) -> int:
	var caps: Array = data().get("nodes", {}).get("caps", [10, 25, 40, 55, 70, 85, 100])
	return roundi(float(caps[clampi(i, 0, caps.size() - 1)]) * scale())


## 第 i 段的名字（守一～逆命；超出按两头夹）
static func stage_name(i: int) -> String:
	var names: Array = data().get("nodes", {}).get("realms", [])
	return str(names[clampi(i, 0, names.size() - 1)]) if not names.is_empty() else ""


static func last_realm() -> int:
	return data().get("nodes", {}).get("caps", [0, 0, 0, 0, 0, 0, 0]).size() - 1


static func node(a) -> int:
	return node_of(realm(a))


## 烙印（万分点）：存档里的数按本境节点截断（表改过时只截显示，不改存档，等下一次结算再写；稿第九节）
static func value(a) -> int:
	return mini(_raw(a), node(a))


static func pct(a) -> float:
	return float(value(a)) / scale()


## 烙印正好在本境节点上（逆命的头是终点，不算）
static func at_node(a) -> bool:
	return realm(a) < last_realm() and value(a) >= node(a)


## 甲二门禁（P2-2）：没刻印、已到 uncarved_max_realm（铸骨）的不放下一场心魔
static func blocked_uncarved(a) -> bool:
	return not carved(a) and realm(a) >= int(data().get("gain", {}).get("uncarved_max_realm", 2))


## 能打本境心魔（gate 不看层数，只看节点＋甲二）
static func can_stand(a) -> bool:
	return at_node(a) and not blocked_uncarved(a)


## 伤害乘数：1 ＋ 配满加成 ×（烙印÷100）^形状。只读烙印值；关着、西游档、不是角色恒 1
static func mult(a, s = null) -> float:
	if not a is XActor or not on(s) or is_same(a, _plain_hit):
		return 1.0
	var p: Dictionary = data().get("power", {})
	return 1.0 + float(p.get("max_bonus", 0.5)) * pow(float(value(a)) / (100.0 * scale()), float(p.get("shape", 1.0)))


# ---- 首胜表、层线、封顶（稿第五节第 4～6 条）----

static func firsts(s: XState) -> Dictionary:
	var sec = XTianqiSave.peek(s, "brand")
	return sec.get("firsts", {}) if sec is Dictionary and sec.get("firsts") is Dictionary else {}


static func _firsts_rw(s: XState) -> Dictionary:
	var sec: Dictionary = XTianqiSave.section(s, "brand")
	if not sec.get("firsts") is Dictionary:
		sec["firsts"] = {}
	return sec.firsts


## 这一层首通给多少（百分数）
static func first_amount(f: int) -> float:
	var g: Dictionary = data().get("gain", {}).get("first_clear", {})
	var fl: Dictionary = g.get("floors", {})
	if fl.has(str(f)):
		return float(fl[str(f)])
	for seg in g.get("segments", []):
		if f >= int(seg.from) and f <= int(seg.to):
			return float(seg.each)
	return 0.0


## 层线（万分点）：首通给的数累加到第 f 层
static func line_at(f: int) -> int:
	var t := 0.0
	for i in range(1, clampi(f, 0, 36) + 1):
		t += first_amount(i)
	return roundi(t * scale())


## 已首通到第几层：主塔进度（XZhenqi.progress_floor，1～33）与首胜表里的守层者、鸿钧（34）、影子（35）、骑士（36）取大
static func cleared_floor(s: XState) -> int:
	var f := XZhenqi.progress_floor(s)
	for k in firsts(s):
		var key := str(k)
		if key.begins_with("guardian:"):
			f = maxi(f, int(key.get_slice(":", 1)))
		elif key == "summit:34":
			f = maxi(f, 34)
		elif key.begins_with("shadow:"):
			f = maxi(f, 35)
		elif key.begins_with("horseman:"):
			f = maxi(f, 36)
	return f


## 这一刻烙印最多到（万分点）＝ 进度上限 和 本境节点 取小（稿第五节第 6 条）。
## floor_now：层线按第几层算（settle 里首通那一场把这一层算进去）；cleared36：已通关 36 层（P2-4：36 层首通那一场结算完才置位）
static func cap_now(s: XState, a, floor_now := -1, cleared36 = null) -> int:
	var f := cleared_floor(s) if floor_now < 0 else floor_now
	var done: bool = (f >= 36) if cleared36 == null else bool(cleared36)
	var prog := line_at(f)
	if carved(a):
		prog = 100 * scale() if done else prog
	else:
		prog = mini(roundi(float(data().get("gain", {}).get("uncarved_cap", 40)) * scale()), prog)
	return mini(prog, node(a))


## 唯一的写入口：amount 是百分数（0.125 ＝ 0.125%），先四舍五入到万分点再封顶截断；返回实际涨了多少万分点
static func gain(s: XState, a, _source: String, amount: float, floor_now := -1, cleared36 = null) -> int:
	if not on(s) or not a is XActor or amount <= 0.0:
		return 0
	var cur := value(a)
	var nv := mini(cur + roundi(amount * scale()), cap_now(s, a, floor_now, cleared36))
	if nv <= cur:
		return 0
	_ensure_keys(a)
	(a as XActor).zhenqi["brand"] = nv
	if can_stand(a):
		_toast(TEXT_BOTTLENECK % [a.display_name(), stage_name(realm(a))])
	return nv - cur


## 刻印：每个角色一次，不能反悔
static func carve(a) -> bool:
	if not a is XActor or carved(a):
		return false
	XZhenqi.data(a)["brand_carved"] = 1
	_ensure_keys(a)
	return true


## 打赢心魔：立入下一境（一场一境）
static func stand(a) -> bool:
	if not can_stand(a):
		return false
	_ensure_keys(a)
	a.zhenqi["brand_realm"] = realm(a) + 1
	return true


static func _ensure_keys(a: XActor) -> void:
	var d := XZhenqi.data(a)
	for k in ["brand", "brand_carved", "brand_realm"]:
		if not d.has(k):
			d[k] = 0


# ---- 认这一场（稿第五节第 4 条）----

## 从 logic 抽出认首领要的事实（纯数据，classify 只看它；测试直接喂字典）
static func facts_of(logic, s: XState) -> Dictionary:
	var zb: Dictionary = XZhenqi.battle
	var horse := XTianqiHorsemen.fight(logic)
	var qr := XTianqiQiyinRule.fight(logic)
	var ev := pending_event
	pending_event = {}
	if not ev.is_empty() and int(ev.get("troop", 0)) != int(logic.troop_id):
		ev = {}
	var names := []
	var ids := []
	for e in logic.enemies:
		names.append(str(e.data().get("name", "")))
		ids.append(int(e.enemy_id))
	var summit := false
	for e in logic.enemies:
		if str(e.horseman.get("rec", {}).get("_ref", "")) == "hongjun":
			summit = true
	# T144（D174「四线节末精英都算」）：四条线异化怪的 spread 那一场（战争 35、瘟疫 248、死亡 294、饥荒 430）
	var spread := false
	for fd in [XTianqiWarAlien.fight(logic), XTianqiPlagueAlien.fight(logic), XTianqiDeathAlien.fight(logic), XTianqiFamineAlien.fight(logic)]:
		if str(fd.get("preset", "")) == "spread":
			spread = true
	# T144（D178「都算」）：七印里副本压轴前那场精英（敌群表倒数第二个：250／34／11／297／123／188／220）
	var qiyin_elite := ""
	if not qr.is_empty() and not bool(qr.get("boss", false)) and not bool(qr.get("enemy_only", false)):
		var tr: Array = XTianqiQiyin.seal_info(str(qr.get("seal", ""))).get("troops", [])
		if tr.size() >= 2 and int(tr[tr.size() - 2]) == int(logic.troop_id):
			qiyin_elite = str(qr.get("seal", ""))
	return {
		"heart": not zb.get("trial", {}).is_empty(),
		"weapon": not zb.get("scaled", {}).is_empty(),
		"gojo": XTianqiGojoTrial.active(logic),
		"horse_line": str(horse.get("line", "")), "horse_mode": str(horse.get("mode", "")),
		"dragon": XTianqiQiyinDragonRun.active(logic),
		"qiyin_seal": str(qr.get("seal", "")) if bool(qr.get("boss", false)) and not bool(qr.get("enemy_only", false)) else "",
		"summit": summit,
		"line_spread": spread, "qiyin_elite": qiyin_elite,
		"guardian_floor": XGuardianRework.troop_floor(logic) if not summit else 0,
		"enemy_ids": ids, "enemy_names": names,
		"map": int(ev.get("map", s.map_id)), "event": int(ev.get("event", 0)), "troop": int(logic.troop_id),
		"tier": tier_of(s),
	}


## 这一场的档位：只有在副本里才读副本档位变量（离开副本后不清，是脏数），别处一律 1
static func tier_of(s: XState) -> int:
	return maxi(1, int(s.variable(XDungeon.VAR_TIER))) if XDungeon.inside(s) else 1


## {kind: special／boss／none, key, first_floor（有首通奖的键给楼层，没有 0）}
## T140（Kyo 11-17「都算首领战」）：七印里副本借【首领】敌群的精英战（灰印 297、默印 220）、四线开场节末那一场
## （死亡线 294 罗奇、饥荒线 430 光头强，都是【首领】名）照名字前缀认首领战，不另开例外（T117 R1 那条「七印精英判不是」撤掉）。
static func classify(f: Dictionary) -> Dictionary:
	if bool(f.get("heart", false)) or bool(f.get("weapon", false)) or bool(f.get("gojo", false)):
		return {"kind": "special", "key": "", "first_floor": 0}
	var line := str(f.get("horse_line", ""))
	var mode := str(f.get("horse_mode", ""))
	if line != "" and mode == "survival":
		return {"kind": "none", "key": "", "first_floor": 0}  # 开场生存战
	if line != "" and mode == "shadow":
		return {"kind": "boss", "key": "shadow:" + line, "first_floor": 35}
	if line != "":
		return {"kind": "boss", "key": "horseman:" + line, "first_floor": 36}
	if bool(f.get("dragon", false)):
		return {"kind": "boss", "key": "qiyin_dragon", "first_floor": 0}
	if str(f.get("qiyin_seal", "")) != "":
		return {"kind": "boss", "key": "qiyin:" + str(f.qiyin_seal), "first_floor": 0}
	if bool(f.get("summit", false)):
		return {"kind": "boss", "key": "summit:34", "first_floor": 34}
	if bool(f.get("line_spread", false)) or str(f.get("qiyin_elite", "")) != "":
		return {"kind": "boss", "key": _ev_key(f), "first_floor": 0}  # T144：按上下文认，名字不带首领前缀也算（键同第 5 行）
	var gf := int(f.get("guardian_floor", 0))
	if gf >= 1 and gf <= 33:
		return {"kind": "boss", "key": "guardian:%d" % gf, "first_floor": gf}  # 10／20／30 层的使徒是守层者变的，同一个键
	var b: Dictionary = data().get("boss", {})
	var excl: Array = b.get("exclude_enemy_ids", [])
	for id in f.get("enemy_ids", []):
		if excl.any(func(x): return int(x) == int(id)):
			return {"kind": "none", "key": "", "first_floor": 0}
	var re := RegEx.create_from_string("【(" + "|".join(b.get("prefixes", [])) + ")】")
	for n in f.get("enemy_names", []):
		if re.search(str(n)):
			return {"kind": "boss", "key": _ev_key(f), "first_floor": 0}
	return {"kind": "none", "key": "", "first_floor": 0}


static func _ev_key(f: Dictionary) -> String:
	return "ev:%d:%d:%d" % [int(f.get("map", 0)), int(f.get("event", 0)), int(f.get("troop", 0))]


## 生熟：特殊战生；不是首领战熟；首领战键在首胜表里、而且表里的档位 ≥ 这一场的档位才熟
static func is_ripe(s: XState, c: Dictionary) -> bool:
	match str(c.get("kind", "none")):
		"special": return false
		"boss":
			var t = firsts(s).get(str(c.key))
			return t != null and int(t) >= int(c.get("tier", 1))
	return true


static func is_brand_boss_fight(c: Dictionary) -> bool:
	return str(c.get("kind", "")) == "boss"


## BattleLogic.setup 末尾：认这一场、定生熟（整场不变），记在 logic 上
static func battle_setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	_logic_ref = null
	if not on(s):
		pending_event = {}
		return
	var f := facts_of(logic, s)
	var c := classify(f)
	c["tier"] = int(f.tier)
	c["ripe"] = is_ripe(s, c)
	c["fills"] = {}  # 灼痕这一场满过几次：actor_id → 次数（T073-d2 写；倒下的人照算）
	c["hits"] = {}  # 出头鸟：角色 → 最近一次打敌人的回合
	c["revived"] = {}  # 一条命：角色 → 这一场被复活几次
	logic.set_meta(META, c)
	_logic_ref = weakref(logic)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if logic != null and logic.has_meta(META) else {}


## BattleLogic.end_battle 开头：这一场结束，一条命、虚不受补不再拦（死亡状态战后不自动解，照常由大厅、道具等拉起来）
static func end(logic) -> void:
	if _logic_ref != null and _logic_ref.get_ref() == logic:
		_logic_ref = null


static func active_logic():
	var l = _logic_ref.get_ref() if _logic_ref != null else null
	return l if l != null and l.has_meta(META) else null


# ---- 常驻六条代价（稿第四节第 2 条，第十三节 T073-c）----
## P2-1：一律判「烙印 > 这一条的节点万分点」（1000／2500／4000／5500／7000／8500），不判 brand_realm；
## 刚打赢心魔、烙印正好在节点上的人已在下一段，但这一段的代价要到「超过」才有。

static func cost_row(key: String) -> Dictionary:
	for r in data().get("costs", {}).get("list", []):
		if str(r.get("key", "")) == key:
			return r
	return {}


static func cost_over(key: String) -> int:
	return roundi(float(cost_row(key).get("over", 101)) * scale())


static func has_cost(a, key: String, s = null) -> bool:
	return a is XActor and on(s) and value(a) > cost_over(key)


## a 在正在打的这一场的我方出战里（一条命、虚不受补用）
static func _fighting(b):
	var logic = active_logic()
	return logic if logic != null and b is XActor and logic.actors.has(b) else null


## 出头鸟：我方出手目标里有敌人就记这一回合（BattleLogic._guided_targets；哑火普攻敌人也算出手）
static func note_hit(logic, u, targets: Array) -> void:
	var c := fight(logic)
	if c.is_empty() or not u is XActor:
		return
	for t in targets:
		if t is XEnemy:
			c.hits[u] = int(logic.turn)
			return


## 被敌人随机单体选中的权重乘数（稿第四节「仇恨怎么算」）：外人项 ×（出头鸟 ×2）。只在烙印开着的天启篇战斗里、敌人挑我方时；
## 嘲讽、挑衅在 targets_for 后面几层照常盖过，掩护在 substitute 照常
static func aggro_mult(logic, user, b) -> float:
	var c := fight(logic)
	if c.is_empty() or not user is XEnemy or not b is XActor:
		return 1.0
	var ag: Dictionary = data().get("aggro", {})
	var m := float(ag.get("outsider_base", 2)) - pct(b) / 100.0
	if has_cost(b, "bird", logic.state) and int(c.hits.get(b, -99)) == int(logic.turn) - 1:
		m *= float(ag.get("bird_mult", 2))
	return m


## 皮薄：物防（3）、魔防（5）倍率。过 25% 之后每多 step 点降 per_step，最多 at_full；走防御通过率，不进承伤池
static func def_rate(a, i: int) -> float:
	if (i != 3 and i != 5) or not has_cost(a, "thin"):
		return 1.0
	var r := cost_row("thin")
	var steps := (value(a) - cost_over("thin")) / roundi(float(r.get("step", 3)) * scale())
	return 1.0 - minf(float(steps) * float(r.get("per_step", 0.01)), float(r.get("at_full", 0.25)))


## 虚不受补：战斗中生命高于一半时受到的生命回复 ×heal_mult（各线的回复削减先算；禁疗照禁，0 还是 0）
static func heal(b, amount: float) -> float:
	if amount <= 0.0 or not has_cost(b, "weak_heal") or _fighting(b) == null:
		return amount
	var r := cost_row("weak_heal")
	if b.hp > b.mhp * float(r.get("hp_above", 0.5)):
		return floorf(amount * float(r.get("heal_mult", 0.5)))
	return amount


## 不合群：我方别人放的全体友方（scope 8）技能、物品落不到过 55% 的人身上；自己放的照吃，点名给他的（scope 7）照吃。
## 断片（T073-d1）：这两回合队友点名给他的（scope 7）落不到他身上
static func filter_group(logic, a, skill: Dictionary, list: Array) -> Array:
	if fight(logic).is_empty() or not a is XActor:
		return list
	match int(skill.get("scope", 0)):
		8:
			return list.filter(func(b): return b == a or not has_cost(b, "no_group", logic.state))
		7:
			return list.filter(func(b): return b == a or not blacked_out(logic, b))
	return list


## 烧命：每次出手（技能、物品；防御、被控跳过不算）前付当前生命的 hp_pct，向下取整、扣不死；直接改生命，不算受到伤害、不涨灼痕。返回给画面的记录（没扣为空）
static func burn(logic, u) -> Dictionary:
	if fight(logic).is_empty() or not u is XActor or not has_cost(u, "burn", logic.state):
		return {}
	var paid := minf(floorf(u.hp * float(cost_row("burn").get("hp_pct", 0.04))), u.hp - 1.0)
	if paid <= 0.0:
		return {}
	u.hp -= paid
	u.refresh_resources()
	return {"type": "regen", "target": u, "hp": paid, "views": logic.views([u])}


## 一条命（D149）：过 revive_once_over（70%）一场只能被复活一次，过 no_revive_over（85%）不能被复活。
## XBattler.remove_state(1) 在四骑士、死亡线、异化连命、灰镰之后问（不改它们的先后）；战斗外（end_battle 之后）不拦
static func blocks_revive(b) -> bool:
	if _fighting(b) == null:
		return false
	var ol: Dictionary = data().get("costs", {}).get("one_life", {})
	var v := value(b)
	if v > roundi(float(ol.get("no_revive_over", 85)) * scale()):
		return true
	return v > roundi(float(ol.get("revive_once_over", 70)) * scale()) and int(fight(_fighting(b)).revived.get(b, 0)) >= 1


## 真的被拉起来了（remove_state(1) 把生命设成 1 之后）：记一次
static func on_revive(b) -> void:
	var logic = _fighting(b)
	if logic != null:
		var rv: Dictionary = fight(logic).revived
		rv[b] = int(rv.get(b, 0)) + 1


# ---- 发作：不听指挥一回合（稿第四节第 3、7 条，第十三节 T073-d1）----
## 自己疯：每回合开始（BattleLogic.start_turn 末尾）每个能行动的角色掷一次，几率 ＝（烙印 − from）× per_point 个百分点；
## 熟的战斗 × ripe.chance_coef，前 ripe.no_self_rounds 回合不掷（生的第 1 回合不掷）。用这一场的规则流（同种子可复现），几率为 0 时不取数。
## 花样：已解锁的里面等几率抽（解锁判「烙印 > 那一条的节点万分点」，P2-1，不判境；发呆总在）；熟的只出 ripe.fits。
## 保护：同一人两次发作之间至少隔 gap_rounds 回合（从上一次的最后一回合算）；同一回合全队最多 max_per_round 人开始发作，多的顺延到下一回合。
## 拦截：forced_action 在行动入口最顶上问（BattleScene._command 挂机分支之前、BattleLogic.decide、run_turn、XBattleReplay），三条路同一个结果。
## 被打疯（灼痕满，T073-d2）走 trigger，同一套保护。
## 玩家可见文字（交付单单列，小A 文字审；花样名是 brand.json 里的占位名）：%s 依次是角色名、花样名
const TEXT_FIT := "%s 的烙印发作了：%s！"
const FIT_KEY := "tianqi_brand_fit"
## 抽自己、六亲不认这一下正在算：mult 对这个人按 1（吃 K，不吃烙印加成）
static var _plain_hit = null


static func fit_row(key: String) -> Dictionary:
	for r in data().get("fits", {}).get("list", []):
		if str(r.get("key", "")) == key:
			return r
	return {}


## 花样显示名（断片是换人的兜底）
static func fit_name(kind: String) -> String:
	if kind == "blackout":
		return str(fit_row("swap").get("fallback", "断片"))
	return str(fit_row(kind).get("name", kind))


static func _protect() -> Dictionary:
	return data().get("fits", {}).get("protect", {})


static func _fc(logic) -> Dictionary:
	var c := fight(logic)
	if c.is_empty():
		return c
	for k in ["fit_now", "fit_last", "fit_queue", "fit_starts", "guard_break", "fit_log"]:
		if not c.has(k):
			c[k] = [] if k in ["fit_queue", "fit_log"] else {}
	return c


## 这一回合自己疯的几率（0～1）；熟的乘系数
static func fit_chance(logic, a) -> float:
	var c := fight(logic)
	if c.is_empty() or not a is XActor:
		return 0.0
	var fd: Dictionary = data().get("fits", {})
	var p := maxf(0.0, pct(a) - float(fd.get("from", 10))) * float(fd.get("per_point", 0.15)) / 100.0
	if bool(c.get("ripe", false)):
		p *= float(data().get("ripe", {}).get("chance_coef", 0.4))
	return p


## 这一场里 a 能抽到的花样（键，表里的次序）：发呆总在；其余要烙印超过那一条的 over；熟的只留 ripe.fits 里的
static func fit_kinds(logic, a) -> Array:
	var c := fight(logic)
	var ripe := bool(c.get("ripe", false))
	var allow: Array = data().get("ripe", {}).get("fits", [])
	var out := []
	for r in data().get("fits", {}).get("list", []):
		var k := str(r.get("key", ""))
		if k != "daze" and value(a) <= roundi(float(r.get("over", 101)) * scale()):
			continue
		if ripe and not allow.has(str(r.get("name", ""))):
			continue
		out.append(k)
	if out.is_empty():
		out.append("daze")
	return out


## 前几回合不自己疯：生的 1（first_round_no_self），熟的 ripe.no_self_rounds
static func _guard_rounds(c: Dictionary) -> int:
	if bool(c.get("ripe", false)):
		return int(data().get("ripe", {}).get("no_self_rounds", 3))
	return 1 if bool(_protect().get("first_round_no_self", true)) else 0


## 这一回合 a 正在发作（forced 的那几种、断片两回合）
static func _in_fit(c: Dictionary, a, turn: int) -> bool:
	var f = c.get("fit_now", {}).get(a)
	return f != null and turn >= int(f.from) and turn <= int(f.to)


## 隔 gap 回合：上一次发作的最后一回合 last，下一次最早 last ＋ gap ＋ 1
static func _cooling(c: Dictionary, a, turn: int) -> bool:
	return c.get("fit_last", {}).has(a) and turn - int(c.fit_last[a]) <= int(_protect().get("gap_rounds", 2))


static func _starts(c: Dictionary, turn: int) -> int:
	return int(c.get("fit_starts", {}).get(turn, 0))


static func _queued(c: Dictionary, a) -> bool:
	return c.get("fit_queue", []).any(func(q): return is_same(q[0], a))


## 开始一次发作：抽花样、记保护。返回给画面的记录（破防当场报；其余在轮到他行动时报）
static func _start_fit(logic, c: Dictionary, a, source: String, forced_kind := "") -> Array:
	var turn := int(logic.turn)
	var kinds := fit_kinds(logic, a)
	var kind: String = forced_kind if forced_kind != "" else (kinds[logic._mod(kinds.size(), "brand_fit_kind")] if kinds.size() > 1 else kinds[0])
	var last := turn
	var logs := []
	match kind:
		"break_guard":
			var r := fit_row("break_guard")
			last = turn + maxi(1, int(r.get("rounds", 2))) - 1
			c.guard_break[a] = last
			logs.append({"type": "battle_text", "text": TEXT_FIT % [a.display_name(), fit_name(kind)], "tianqi_fit": true})
		"swap":
			if swap_possible(logic, a):
				c.fit_now[a] = {"kind": kind, "from": turn, "to": turn}  # T086-a 真换人：轮到他时这次行动没了，收尾跑完、人还活着才换（after_act）
			else:
				kind = "blackout"  # 换不了（开关关着、助力位空或倒下、模块角色、超上限、锁定、心魔被考的人）：断片，人还在场上
				last = turn + _blackout_rounds() - 1
				c.fit_now[a] = {"kind": kind, "from": turn, "to": last}
		_:
			c.fit_now[a] = {"kind": kind, "from": turn, "to": turn}
	c.fit_last[a] = last
	c.fit_starts[turn] = _starts(c, turn) + 1
	c.fit_log.append({"turn": turn, "actor": int(a.actor_id), "kind": kind, "source": source})
	return logs


## 能不能现在开始：活着、在出战里、不在发作中、不在间隔里、这一回合还没满人
static func _may_start(logic, c: Dictionary, a, turn: int) -> bool:
	return _starts(c, turn) < int(_protect().get("max_per_round", 2)) and not _in_fit(c, a, turn) and not _cooling(c, a, turn)


## BattleLogic.start_turn 末尾：先发顺延下来的，再按出战次序给每个能行动的人掷自己疯。返回回合开始的记录
static func start_turn(logic) -> Array:
	var c := _fc(logic)
	if c.is_empty():
		return []
	var turn := int(logic.turn)
	var logs := []
	var keep := []
	for q in c.fit_queue:
		var a = q[0]
		if not a.is_alive() or not logic.actors.has(a):
			continue
		if logic.can_move(a) and _may_start(logic, c, a, turn):
			logs.append_array(_start_fit(logic, c, a, str(q[1])))
		else:
			keep.append(q)
	c.fit_queue = keep
	for a in logic.actors.duplicate():
		var tf = TEST_FIT.get(int(a.actor_id)) if a is XActor else null
		if tf != null and int(tf[0]) == turn and a.is_alive() and not _in_fit(c, a, turn):
			logs.append_array(_start_fit(logic, c, a, "test", str(tf[1])))  # 测试／量数钩子：点名触发，不取随机数
	if turn <= _guard_rounds(c):
		return logs
	for a in logic.actors:
		if not a is XActor or not a.is_alive() or not logic.can_move(a) or _queued(c, a) or _in_fit(c, a, turn) or _cooling(c, a, turn):
			continue
		var p := fit_chance(logic, a)
		if p <= 0.0 or logic._float("brand_fit") >= p:
			continue
		if _starts(c, turn) < int(_protect().get("max_per_round", 2)):
			logs.append_array(_start_fit(logic, c, a, "self"))
		else:
			c.fit_queue.append([a, "self"])  # 同回合满人：顺延
	return logs


## 被打疯（T073-d2 的灼痕满了调）：能开始就当场开始，否则顺延（隔回合、满人都顺延）。返回 [开没开（"started"／"queued"／""）, 记录]
static func trigger(logic, a, source := "sear") -> Array:
	var c := _fc(logic)
	if c.is_empty() or not a is XActor or not a.is_alive() or not logic.actors.has(a):
		return ["", []]
	var turn := int(logic.turn)
	if _may_start(logic, c, a, turn) and not _queued(c, a):
		return ["started", _start_fit(logic, c, a, source)]
	# T119 返修（小A P3②）：发作中（发呆、断片等记在 fit_now 的）和破防一样顺延，不再直接丢掉；
	# 发作中一定也在间隔里（fit_last 记到最后一回合），顺延下来的照「隔回合」等间隔过了再发
	if not _queued(c, a):
		c.fit_queue.append([a, source])
		return ["queued", []]
	return ["", []]


## 行动入口最顶上：这一回合 a 在发作就给出这次行动 [合成技能, 目标]，否则 []。
## 发呆、断片：空过；哑火：普攻随机一个活着的敌人；抽自己：普攻自己；六亲不认：普攻随机一个活着的队友（没有队友就发呆）。
## 同一回合的第二个及以后的行动位一律空过（不听指挥的是这一整回合，不重复打人）。不能行动的照原来（被控跳过）
static func forced_action(logic, u) -> Array:
	var c := fight(logic)
	if c.is_empty() or not u is XActor or not u.is_alive() or not logic.can_move(u):
		return []
	var turn := int(logic.turn)
	if not _in_fit(c, u, turn):
		return auto_back(logic, u)
	var f: Dictionary = c.fit_now[u]
	var kind := str(f.kind)
	if int(f.get("used", -1)) == turn:
		return [_cmd("idle"), null]
	if kind == "swap" and not swap_possible(logic, u):
		_to_blackout(logic, c, u)  # 抽到时能换、轮到他时换不了（同回合别人先换锁住了助力位等）：当场改成完整的断片
		return [_cmd("blackout"), null]
	f["used"] = turn
	match kind:
		"misfire":
			var foes: Array = logic.alive(logic.enemies)
			if foes.is_empty():
				return [_cmd("daze"), null]
			return [_cmd(kind), foes[logic._mod(foes.size(), "brand_fit_target")] if foes.size() > 1 else foes[0]]
		"hit_self":
			return [_cmd(kind), u]
		"hit_ally":
			var mates: Array = logic.alive(logic.actors).filter(func(b): return not is_same(b, u))
			if mates.is_empty():
				return [_cmd("daze"), null]
			return [_cmd(kind), mates[logic._mod(mates.size(), "brand_fit_target")] if mates.size() > 1 else mates[0]]
	return [_cmd(kind), null]


## 合成技能：带 id 0（T119 返修，小A P3③：外部回放录制照 int(cmd[0].id) 读也不报错；0 号不是任何技能）
static func _cmd(kind: String) -> Dictionary:
	return {FIT_KEY: kind, "id": 0}


static func is_fit_command(skill) -> bool:
	return skill is Dictionary and skill.has(FIT_KEY)


## BattleLogic.act 开头把合成技能换成真的行动：{logs, skill, target}。哑火换成普攻敌人（照常走 execute，算出手、照付烧命）；
## 抽自己、六亲不认在这里直接结算那一下（不算出手：不付烧命、不加七印层、不走命中反击反射掩护、不涨灼痕、不进瘟疫病灶），之后按放弃行动走
static func perform(logic, u, skill: Dictionary, target) -> Dictionary:
	var kind := str(skill.get(FIT_KEY, ""))
	var logs := []
	if kind != "idle" and kind != "swap_back":
		logs.append({"type": "battle_text", "text": TEXT_FIT % [u.display_name(), fit_name(kind)], "tianqi_fit": true})
	match kind:
		"misfire":
			return {"logs": logs, "skill": u.attack_skill(), "target": target}
		"swap", "swap_back":
			_fc(logic)["swap_due"] = {"actor": u, "kind": kind}  # 按放弃行动走完，act 末尾（收尾之后）after_act 再换
		"hit_self", "hit_ally":
			if target is XActor and target.is_alive():
				var r := strike(logic, u, target)
				if not r.is_empty():
					logs.append(r)
	return {"logs": logs, "skill": null, "target": null}


## 抽自己、六亲不认那一下的伤害（封顶之前）：普攻的公式、K 照乘、烙印加成按 1、不暴击（预演口径，不挂状态）
static func strike_value(logic, u, t) -> float:
	var atk: Dictionary = u.attack_skill()
	_plain_hit = u
	var v := XDamage.finish(logic._calculate_damage(u, atk, t, false), atk, u, t, false)
	_plain_hit = null
	return floorf(maxf(0.0, v))


## 结算那一下：单次不超过目标最大生命的 self_hit_cap，打不倒人（最多打到 1）；直接改生命，画面走一条 regen 记录弹字
static func strike(logic, u, t) -> Dictionary:
	var cap := floorf(t.mhp * float(_protect().get("self_hit_cap", 0.15)))
	var v := minf(minf(strike_value(logic, u, t), cap), t.hp - 1.0)
	if v <= 0.0:
		return {}
	t.hp -= v
	t.refresh_resources()
	return {"type": "regen", "target": t, "hp": v, "views": logic.views([t])}


## 破防：这一回合和下一回合受到的生命伤害 ×(1 ＋ taken_up)（XDamage 的天启篇乘区、四骑士的出伤处乘；不碰瘟疫病灶、灼痕）
static func taken_mult(b) -> float:
	var logic = _fighting(b)
	if logic == null:
		return 1.0
	var until = fight(logic).get("guard_break", {}).get(b)
	if until == null or int(logic.turn) > int(until):
		return 1.0
	return 1.0 + float(fit_row("break_guard").get("taken_up", 0.3))


## 断片的人：这两回合队友点名给他的（scope 7）治疗、增益落不到他身上
static func blacked_out(logic, b) -> bool:
	var c := fight(logic)
	var f = c.get("fit_now", {}).get(b)
	return f != null and str(f.kind) == "blackout" and _in_fit(c, b, int(logic.turn))


# ---- 真换人（T086-a；设计仓库《天启篇_发作真换人 v0.2》第三～七节，D201）----
## 抽到第六种「换人」时先判一次能不能真换（swap_possible）：能就记成 swap（只这一回合），轮到他时这次行动按放弃走完，
## act 末尾行动收尾全部跑完、人还活着才和助力位对调（after_act ← BattleLogic.act 最后；手动换人也是先放弃一次行动再对调）；
## 换不了退回断片（完整 2 回合，间隔从断片最后一回合算）。被换下去的人锁定 lock_rounds 回合（换下那回合算第 1 回合），
## 锁定期间谁都不能换人（BattleLogic.can_tianqi_swap）；过了锁定，自动战斗、挂机时被强制换上来的人在自己下一次行动现判换回（auto_back，不挂记号）。
## 留底：这一场第一次强制换人之前的出战栏 5 格，挂在这场战斗的 fight 上（c.swap.snap），不进存档；BattleLogic.tianqi_restore
## 在胜利结算开头、收口开头还原出战栏＋在场名单。_holds 另记「这份存档有一场没收口的战斗带着留底」：出战栏超强者清理停手
## （XItemMarks.enforce_party）、开新一场先清扫（sweep）、回放导出写留底（patch_save）都只认它。
## 开关默认关：关着第六种一律断片（同 T086 前）。打开之前画面演出 T086-c 必须先合（设计稿第十节）。
static var REAL_SWAP := false
## 测试／量数钩子（设计稿第八节「触发用测试钩子点名，不靠掷」）：{actor_id: [回合, 花样键]}，那一回合开头直接开这次发作（不掷几率、不取随机数、不看保护）。游戏里恒空
static var TEST_FIT := {}
## 玩家可见文字（小A 定稿，T182 核查报告第二节）：%s 是角色名。轮到他时能换、收尾之后换不了了（这次行动里助力位倒下等）
const TEXT_SWAP_FALLBACK := "%s没能退下，当场失神了！"
static var _holds: Array = []  # [{state: WeakRef, logic: WeakRef, snap: Array}]


static func _swap_row() -> Dictionary:
	return fit_row("swap")


static func _blackout_rounds() -> int:
	return maxi(1, int(_swap_row().get("fallback_rounds", 2)))


static func lock_rounds() -> int:
	return maxi(1, int(_swap_row().get("lock_rounds", 2)))


## 只做断片的专属模块角色（brand.json swap.blackout_only；设计稿第四节，D201 第 3 件）
static func blackout_only(id: int) -> bool:
	return (_swap_row().get("blackout_only", []) as Array).any(func(x): return int(x) == id)


## 这一场的换人数据（只在 fight 上，战斗没了跟着没）
static func swap_data(logic) -> Dictionary:
	var c := fight(logic)
	if c.is_empty():
		return {}
	if not c.has("swap"):
		c["swap"] = {"snap": [], "lock_until": -1, "last_out": 0, "last_in": 0, "log": []}
	return c.swap


static func snap_of(logic) -> Array:
	var c := fight(logic)
	return (c.swap.snap as Array) if not c.is_empty() and c.has("swap") else []


static func swap_locked(logic) -> bool:
	var c := fight(logic)
	return not c.is_empty() and c.has("swap") and int(logic.turn) <= int(c.swap.lock_until)


## 心魔战（真气瓶颈、烙印立境）被考的人：他得自己站到最后，抽到换人只断片（设计稿第三节第 6 条第 5 行）
static func trial_actor() -> int:
	var t = XZhenqi.battle.get("trial", {})
	return int(t.get("actorId", 0)) if t is Dictionary else 0


## 能不能真换（第三节第 6 条的表）：开关、助力位活着、两边都不是只断片的模块角色、不是心魔被考的人、没在锁定、上场上限（含九死炼狱的临时口子）
static func swap_possible(logic, a) -> bool:
	if not REAL_SWAP or fight(logic).is_empty() or not a is XActor or not logic.actors.has(a) or logic.state == null:
		return false
	var h = logic.state.helper()
	if h == null or blackout_only(int(a.actor_id)) or blackout_only(int(h.actor_id)) or trial_actor() == int(a.actor_id):
		return false
	return not swap_locked(logic) and logic.can_tianqi_swap(a, true)


## 改成完整的断片：从这一回合起 fallback_rounds 回合不行动，「两次发作隔 2 回合」从断片的最后一回合起算
static func _to_blackout(logic, c: Dictionary, u) -> void:
	var turn := int(logic.turn)
	var last := turn + _blackout_rounds() - 1
	c.fit_now[u] = {"kind": "blackout", "from": turn, "to": last, "used": turn}
	c.fit_last[u] = maxi(int(c.fit_last.get(u, turn)), last)
	for i in range(c.fit_log.size() - 1, -1, -1):
		var r: Dictionary = c.fit_log[i]
		if int(r.actor) == int(u.actor_id) and str(r.kind) == "swap":
			r.kind = "blackout"
			r["fallback"] = true
			break


## 自动战斗、挂机：锁定一过，被强制换上来的人在自己下一次行动时换回（每次现判，不挂记号；设计稿第三节第 3 条）。
## 条件：有留底；助力位上正是最近一次被强制换下去的人、活着；行动的正是那次被强制换上来的人；不在锁定、不超上限（can_tianqi_swap）
static func auto_back(logic, u) -> Array:
	if not REAL_SWAP or not u is XActor or logic.state == null or not (logic.auto or XHangUp.is_active(logic.state)):
		return []
	return [_cmd("swap_back"), null] if _back_ok(logic, u) else []


static func _back_ok(logic, u) -> bool:
	if snap_of(logic).is_empty():
		return false
	var sw := swap_data(logic)
	var h = logic.state.helper()
	return h != null and h.is_alive() and int(h.actor_id) == int(sw.last_out) and int(u.actor_id) == int(sw.last_in) \
		and logic.actors.has(u) and logic.can_tianqi_swap(u)


## BattleLogic.act 最后（行动收尾、倒下结算全部跑完）：这次行动是发作换人／自动换回的，人还活着才换。返回记录（tianqi_swap 一条给画面换图）
static func after_act(logic, u) -> Array:
	var c := fight(logic)
	if c.is_empty() or not c.has("swap_due"):
		return []
	var due: Dictionary = c.swap_due
	c.erase("swap_due")
	if not is_same(due.actor, u) or not u.is_alive() or not logic.actors.has(u):
		return []  # 收尾里倒下了：不换（倒下不补位，D57），这次发作算完
	var kind := str(due.kind)
	var sw := swap_data(logic)
	if kind == "swap":
		if not swap_possible(logic, u):
			_to_blackout(logic, c, u)
			return [{"type": "battle_text", "text": TEXT_SWAP_FALLBACK % u.display_name(), "tianqi_fit": true}]
		var first: bool = (sw.snap as Array).is_empty()
		if first:
			sw.snap = logic.state.battle_slots.duplicate()
		var h = logic.tianqi_swap(u, true)
		if h == null:
			if first:
				sw.snap = []
			_to_blackout(logic, c, u)
			return [{"type": "battle_text", "text": TEXT_SWAP_FALLBACK % u.display_name(), "tianqi_fit": true}]
		if first:
			_hold(logic, sw.snap)
		sw.lock_until = int(logic.turn) + lock_rounds() - 1
		sw.last_out = int(u.actor_id)
		sw.last_in = int(h.actor_id)
		sw.log.append({"turn": int(logic.turn), "out": int(u.actor_id), "in": int(h.actor_id), "kind": kind})
		return logic.take_swap_logs() + [{"type": "tianqi_swap", "out": u, "in": h, "forced": true}]
	if kind == "swap_back" and _back_ok(logic, u):
		var h = logic.tianqi_swap(u)
		if h != null:
			sw.log.append({"turn": int(logic.turn), "out": int(u.actor_id), "in": int(h.actor_id), "kind": kind})
			return logic.take_swap_logs() + [{"type": "tianqi_swap", "out": u, "in": h, "auto": true}]
	return []


## 还原用：取走留底（之后这一场不再有留底，第二次调是空的），放开 _holds
static func take_snap(logic) -> Array:
	var snap := snap_of(logic)
	if snap.is_empty():
		return []
	var out := snap.duplicate()
	swap_data(logic).snap = []
	release(logic)
	return out


static func _hold(logic, snap: Array) -> void:
	_prune()
	_holds.append({"state": weakref(logic.state), "logic": weakref(logic), "snap": snap.duplicate()})


static func _prune() -> void:
	_holds = _holds.filter(func(x): return x.state.get_ref() != null)


## 放开这场战斗的留底登记（不还原）：回放结束、战斗对象要丢掉时
static func release(logic) -> void:
	_holds = _holds.filter(func(x): return x.state.get_ref() != null and x.logic.get_ref() != logic)


## 这份存档有一场还没收口的战斗带着留底（出战栏超强者清理在这时停手，认的是这份存档自己的那一场）。
## 战斗对象已经没了（异常路径没走收口）的登记不算：不让 enforce_party 一直停着（T181 P3-2，T182）；出战栏由下一场开战 sweep 还原
static func swap_hold(s) -> bool:
	if _holds.is_empty() or s == null:
		return false
	return _holds.any(func(x): return x.state.get_ref() == s and x.logic.get_ref() != null)


## 开新一场（BattleLogic.setup 最前）：这份存档上还有上一场没还原的留底，先还原出战栏再开打
static func sweep(s) -> void:
	if _holds.is_empty() or s == null:
		return
	var keep := []
	for x in _holds:
		var st = x.state.get_ref()
		if st == null:
			continue
		if st != s:
			keep.append(x)
			continue
		var now: Array = s.battle_slots.duplicate()
		if same_people(x.snap, now):
			for i in (x.snap as Array).size():
				s.set_battle_slot(i, int(x.snap[i]))
		else:
			push_warning("XTianqiBrand.sweep: 留底和出战栏不是同一批人，不还原 %s / %s" % [x.snap, now])
	_holds = keep


static func same_people(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var x := a.map(func(v): return int(v))
	var y := b.map(func(v): return int(v))
	x.sort()
	y.sort()
	return x == y


## 回放导出（XBattleReplay.record）不走收口：这场战斗还带着留底时，导出的出战栏写留底（设计稿第三节第 4 条「保险」）
static func patch_save(logic, d: Dictionary) -> void:
	var snap := snap_of(logic)
	if not snap.is_empty() and d.has("battleSlots"):
		d["battleSlots"] = snap.duplicate()


# ---- 灼痕（稿第四节第 4 条，第十三节 T073-d2）----
## 每个上场的角色一条，只在这一场里（fight 上的 sear：角色 → 当前值）；被敌人打中、生命确实掉了才涨（闪掉、没命中、护盾全挡下的不涨；
## 掩护的人挨的打算在掩护的人身上，因为挂在实际扣血那一处 BattleLogic.execute_hp_damage）。一次行动（act／强制行动各算一次）
## 对同一个人、同一个出手的敌人最多一次；群体招每个被打中的人各算一次。一下涨多少按出手那只怪的异化级（守层者、使徒、骑士按终焉）。
## 涨到上限（60 ＋ 等级 × 0.5 ＋ 烙印 × 0.5，向下取整）：这一场「满过几次」（fills：actor_id → 次数，倒下不清）＋1、槽清零（溢出不留）、发作一次：
## 他这一回合还没轮到行动就当场开始（XTianqiBrand.trigger，同一套保护，被隔回合、满人挡住、正在发作就顺延）；这一回合已经行动过（或正在行动、
## 被反击打满的）就顺延（start_turn 先发顺延的，照等间隔）。已经排着顺延的不再排第二个。满了就算一次，发作有没有当场开始都算。净化、驱散不碰它，战斗结束随 fight 一起清。
## 玩家可见文字（交付单单列，小A 文字审）：%s 依次是角色名、槽名（brand.json sear.name，占位名，最终名小A 起；不用「境」「锚」「异化」「病」「火」）
const TEXT_SEAR_FULL := "%s 的%s满了！"
const _TIER_CN := {"qinran": "侵染", "shigu": "蚀骨", "huaxing": "化形", "zhongyan": "终焉"}
const _ALIEN_METAS := ["xwar_alien", "xfamine_alien", "xplague_alien", "xdeath_alien", "xrift_alien"]
const _FINALE := "终焉"


static func sear_name() -> String:
	return str(data().get("sear", {}).get("name", "灼痕"))


## 灼痕上限（向下取整）：base ＋ 等级 × per_level ＋ 烙印（百分数）× per_brand
static func sear_cap(a) -> int:
	var cp: Dictionary = data().get("sear", {}).get("cap", {})
	var v := float(cp.get("base", 60)) + float(a.level) * float(cp.get("per_level", 0.5)) + pct(a) * float(cp.get("per_brand", 0.5))
	return int(floorf(v + 1e-6)) if str(cp.get("round", "floor")) == "floor" else roundi(v)


## 这一场 a 的灼痕当前值
static func sear_of(logic, a) -> int:
	return int(fight(logic).get("sear", {}).get(a, 0))


## 这一场 a 的灼痕满过几次（倒下的照算）
static func fills_of(logic, a) -> int:
	return int(fight(logic).get("fills", {}).get(int(a.actor_id), 0)) if a is XActor else 0


## 出手那只敌人的异化级（中文级名；没异化为「没异化」）：骑士、守层者（含变成使徒的）、本线使徒那一场的异化怪按终焉；
## 其余读四线异化模块和漩涡异化记在战斗对象上的 units（按段异化也记在各线模块里）
static func enemy_tier(logic, e) -> String:
	if not e is XEnemy:
		return "没异化"
	if not e.horseman.is_empty():
		return _FINALE
	var as_finale: Array = data().get("sear", {}).get("as_finale", [])
	var nm := str(e.data().get("name", ""))
	for p in as_finale:
		if nm.begins_with("【%s】" % str(p)):
			return _FINALE
	for m in _ALIEN_METAS:
		if not logic.has_meta(m):
			continue
		var f = logic.get_meta(m)
		if not f is Dictionary or not f.get("units", {}).has(e):
			continue
		if str(f.get("preset", "")).begins_with("apostle"):
			return _FINALE
		var t := str(f.units[e].get("tier", ""))
		return str(_TIER_CN.get(t, t)) if t != "" else "没异化"
	return "没异化"


## 一下涨多少
static func sear_per_hit(logic, e) -> int:
	var ph: Dictionary = data().get("sear", {}).get("per_hit", {})
	return int(ph.get(enemy_tier(logic, e), ph.get("没异化", 3)))


## BattleLogic.act、_forced_run 开头：开一次新的行动（「一次行动对同一个人最多一次」按这个分）
static func act_begin(logic) -> void:
	var c := fight(logic)
	if c.is_empty():
		return
	c["sear_seen"] = {}


## BattleLogic.execute_hp_damage 末尾：敌人打中我方出战的人、生命确实掉了 → 这次行动里头一次就涨
static func sear_hit(logic, u, t, hp_before: float) -> void:
	var c := fight(logic)
	if c.is_empty() or not u is XEnemy or not t is XActor or not logic.actors.has(t) or not (t.hp < hp_before):
		return
	if not c.has("sear_seen"):
		c["sear_seen"] = {}
	var seen: Dictionary = c.sear_seen.get(u, {})
	if seen.has(t):
		return
	seen[t] = true
	c.sear_seen[u] = seen
	sear_add(logic, t, sear_per_hit(logic, u))


## 灼痕涨 amount（测试也直接调）；满了记一次、清零、发作。返回这次满了没有（0／1）
static func sear_add(logic, a, amount: int) -> int:
	var c := _fc(logic)
	if c.is_empty() or not a is XActor or amount <= 0:
		return 0
	if not c.has("sear"):
		c["sear"] = {}
	if not c.has("sear_logs"):
		c["sear_logs"] = []
	var v := int(c.sear.get(a, 0)) + amount
	if v < sear_cap(a):
		c.sear[a] = v
		return 0
	c.sear[a] = 0
	var id := int(a.actor_id)
	c.fills[id] = int(c.fills.get(id, 0)) + 1
	c.sear_logs.append({"type": "battle_text", "text": TEXT_SEAR_FULL % [a.display_name(), sear_name()]})
	if a.is_alive():
		if logic.current_order.has(a):
			c.sear_logs.append_array(trigger(logic, a, "sear")[1])
		elif not _queued(c, a):
			c.fit_queue.append([a, "sear"])  # 这一回合已经行动过：顺延（同 trigger：发作中的也顺延，等间隔过了再发）
	return 1


## BattleLogic.act、_forced_run 末尾：灼痕满了的记录（满了的那一行、当场开始的破防）
static func take_logs(logic) -> Array:
	var c := fight(logic)
	if c.is_empty() or c.get("sear_logs", []).is_empty():
		return []
	var out: Array = c.sear_logs
	c.sear_logs = []
	return out


## 灼痕槽界面读：[{actor, value, cap, fills}]（出战的人，烙印关着、不在天启篇战斗里为空）
static func sear_rows(logic) -> Array:
	var c := fight(logic)
	if c.is_empty():
		return []
	var out := []
	for a in logic.actors:
		if a is XActor:
			out.append({"actor": a, "value": sear_of(logic, a), "cap": sear_cap(a), "fills": fills_of(logic, a)})
	return out


# ---- 打赢后结算（稿第五节第 5～7 条；P2-4 次序）----

## 难度系数（五档草案）
static func difficulty_coef(s: XState) -> float:
	var d: Dictionary = data().get("gain", {}).get("replay", {}).get("difficulty", {})
	return float(d.get(str(s.flags.tianqi.get("difficulty", "")), 1.0))


## 打赢后：出战（含倒下）×1、助力位 ×0.5、后备不拿。先按这一场的层线跑完所有人，再记首胜（36 层首通完正好 95%）。返回 [[actor_id, 万分点, 来源]]
static func settle(logic) -> Array:
	var c := fight(logic)
	var s: XState = logic.state
	if c.is_empty() or not on(s) or not is_brand_boss_fight(c):
		return []
	var key := str(c.key)
	var fl := firsts(s)
	var ff := int(c.get("first_floor", 0))
	var first := ff > 0 and not fl.has(key)
	var cleared := cleared_floor(s)
	var floor_now := maxi(cleared, ff) if first else cleared
	var done36 := cleared >= 36  # 这一场之前已通关 36 层
	var g: Dictionary = data().get("gain", {})
	var share: Dictionary = g.get("first_clear", {}).get("share", {})
	var rp: Dictionary = g.get("replay", {})
	var st: Dictionary = data().get("sear", {}).get("settle", {})
	var who := []
	for a in logic.actors:
		who.append([a, float(share.get("出战", 1.0))])
	var h := s.helper()
	if h != null and not logic.actors.has(h):
		who.append([h, float(share.get("助力位", 0.5))])
	var out := []
	var lines := []
	for pair in who:
		var a: XActor = pair[0]
		var k: float = pair[1]
		var before := value(a)
		var stalled := at_node(a)
		if carved(a):
			var amt := 0.0
			if first:
				amt = first_amount(ff) * k
			else:
				var gap := maxf(0.0, float(line_at(floor_now) - before) / scale())
				amt = maxf(gap * float(rp.get("ratio", 0.1)), float(rp.get("floor", 0.25)) * difficulty_coef(s)) * (1.0 if k >= 1.0 else float(rp.get("assist_mult", 0.5)))
			var n := gain(s, a, "first" if first else "replay", amt, floor_now, done36)
			if n > 0:
				out.append([a.actor_id, n, "first" if first else "replay"])
		var fills := mini(int(c.get("fills", {}).get(a.actor_id, 0)), int(st.get("max_per_fight", 2)))
		if fills > 0:
			var n2 := gain(s, a, "sear", float(fills) * float(st.get("per_fill", 0.75)), floor_now, done36)
			if n2 > 0:
				out.append([a.actor_id, n2, "sear"])
		var d := value(a) - before
		if d > 0:
			lines.append("%s +%s%%" % [a.display_name(), _pct_text(d)])
		elif stalled and can_stand(a):
			_toast(TEXT_NO_GAIN % [a.display_name(), stage_name(realm(a))])
	var tier := int(c.get("tier", 1))
	var fw := _firsts_rw(s)
	fw[key] = maxi(int(fw.get(key, 0)), tier)
	if not lines.is_empty():
		_toast(TEXT_GAIN % "，".join(lines))
	return out


static func _pct_text(v: int) -> String:
	var t := "%.2f" % (float(v) / scale())
	while t.ends_with("0"):
		t = t.substr(0, t.length() - 1)
	return t.trim_suffix(".")


static func _toast(msg: String) -> void:
	toasts.append(msg)
	XToast.show_text(msg, false, "zhenqi")


# ---- 面板（稿第三节第 1 条；P2-2、P2-3）----

## {value, node, dark_to, sealed_from（没刻印的从 40% 起封住，否则 -1）, plus（到节点、能打心魔）, highlight（P2-3：节点刻度线高亮）, text}
static func panel(s: XState, a) -> Dictionary:
	var v := value(a)
	var n := node(a)
	var prog := line_at(cleared_floor(s))
	if cleared_floor(s) >= 36:
		prog = 100 * scale()
	var dark_to := maxi(v, mini(prog, 100 * scale())) if carved(a) else v
	var sealed := -1 if carved(a) else roundi(float(data().get("gain", {}).get("uncarved_cap", 40)) * scale())
	var plus := can_stand(a)
	return {"value": v, "node": n, "dark_to": dark_to, "sealed_from": sealed, "plus": plus, "highlight": plus,
		"text": "烙印 %s%%%s" % [_pct_text(v), "+" if plus else ""]}


## 文字条（闭关菜单里画一根 20 格的条：■亮段 ▒暗段 ×封住 □空，节点位置一根 |，高亮时 ‖）
static func bar_text(s: XState, a) -> String:
	var p := panel(s, a)
	var cells := 20
	var unit := 100 * scale() / cells
	var out := ""
	var node_cell := int(p.node) / unit
	for i in cells:
		var lo := i * unit
		if i == node_cell and int(p.node) < 100 * scale():
			out += "‖" if bool(p.highlight) else "|"
		if lo < int(p.value):
			out += "■"
		elif int(p.sealed_from) >= 0 and lo >= int(p.sealed_from):
			out += "×"
		elif lo < int(p.dark_to):
			out += "▒"
		else:
			out += "□"
	return out
