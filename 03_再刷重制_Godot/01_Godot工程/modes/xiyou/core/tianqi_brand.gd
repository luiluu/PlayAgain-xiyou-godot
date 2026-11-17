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
##
## 存档（稿第九节）：角色 XActor.zhenqi 的 brand／brand_carved／brand_realm（XZhenqi.from_save 只在读进来的数据里本来就有时原样留）；
## 首胜表在 flags.tianqi.brand.firsts（XTianqiSave 分区 brand，稿里叫 brand_firsts）：战斗键 → 打赢时的最高档位。西游档一个字不读不写。

const PATH := "res://modes/xiyou/tianqi_data/brand.json"
const META := "tianqi_brand"
## 玩家可见文字（交付单单列，合前过小A 文字审）
const TEXT_BOTTLENECK := "%s 的烙印已到瓶颈"
const TEXT_NO_GAIN := "%s 的烙印已到瓶颈，本场未再增长。"
const TEXT_GAIN := "烙印 %s"
const TEXT_CARVE_WARN := ["一旦刻印，烙印只涨不降，没有回头路。", "刻印后，每首通一位守层者都会加深烙印；不刻印则只在首领战挨打时记下烙印，上限 40%。"]
const TEXT_RETREAT := ["\\C[6]烙印\\C[0]", "烙印随首领战加深，到每境节点后，打赢心魔即可立入下一境。", "未刻印只能停在铸骨（40%），刻印后可继续推进。"]

static var ENABLED := false

static var _data: Dictionary = {}
## 本进程发过的烙印提示（测试核对）
static var toasts: Array = []
## 事件开战（mv_interpreter 301）时记下的地图、事件、敌群；BattleLogic.setup 吃掉（敌群不符作废）
static var pending_event := {}


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
	if not a is XActor or not on(s):
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
		_toast(TEXT_BOTTLENECK % a.display_name())
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
	return {
		"heart": not zb.get("trial", {}).is_empty(),
		"weapon": not zb.get("scaled", {}).is_empty(),
		"gojo": XTianqiGojoTrial.active(logic),
		"horse_line": str(horse.get("line", "")), "horse_mode": str(horse.get("mode", "")),
		"dragon": XTianqiQiyinDragonRun.active(logic),
		"qiyin_seal": str(qr.get("seal", "")) if bool(qr.get("boss", false)) and not bool(qr.get("enemy_only", false)) else "",
		"qiyin_elite": not qr.is_empty() and not bool(qr.get("boss", false)) and not bool(qr.get("enemy_only", false)),  # 里副本前两场精英（灰印 297、默印 220 借【首领】敌群）
		"summit": summit,
		"guardian_floor": XGuardianRework.troop_floor(logic) if not summit else 0,
		"enemy_ids": ids, "enemy_names": names,
		"map": int(ev.get("map", s.map_id)), "event": int(ev.get("event", 0)), "troop": int(logic.troop_id),
		"tier": tier_of(s),
	}


## 这一场的档位：只有在副本里才读副本档位变量（离开副本后不清，是脏数），别处一律 1
static func tier_of(s: XState) -> int:
	return maxi(1, int(s.variable(XDungeon.VAR_TIER))) if XDungeon.inside(s) else 1


## {kind: special／boss／none, key, first_floor（有首通奖的键给楼层，没有 0）}
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
	if bool(f.get("qiyin_elite", false)):
		return {"kind": "none", "key": "", "first_floor": 0}  # 七印里副本的精英战：不按名字前缀认首领
	if bool(f.get("summit", false)):
		return {"kind": "boss", "key": "summit:34", "first_floor": 34}
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
			return {"kind": "boss", "key": "ev:%d:%d:%d" % [int(f.get("map", 0)), int(f.get("event", 0)), int(f.get("troop", 0))], "first_floor": 0}
	return {"kind": "none", "key": "", "first_floor": 0}


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
	if not on(s):
		pending_event = {}
		return
	var f := facts_of(logic, s)
	var c := classify(f)
	c["tier"] = int(f.tier)
	c["ripe"] = is_ripe(s, c)
	c["fills"] = {}  # 灼痕这一场满过几次：actor_id → 次数（T073-d2 写；倒下的人照算）
	logic.set_meta(META, c)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if logic != null and logic.has_meta(META) else {}


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
			_toast(TEXT_NO_GAIN % a.display_name())
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
