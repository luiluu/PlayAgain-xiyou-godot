class_name XTianqiRewards
extends RefCounted
## 【cc·天启篇·未经审查】天启篇奖励（四线剧情与关卡设计稿 v0.4 第 6 节；数据 tianqi_data/rewards.json，数字是测试参数）：
## - 净印装备（项链，每线三档）：开场打完给第一档，10／20／30 层使徒各掉一件；只对本档走的线生效。
## - 骑士遗物（神器栏）：35 层影子首次击败给半强度版，36 层首次击败骑士给完整版；有收益也有代价。
## - 终焉词条：骑士、35 层影子、34 层鸿钧每赢一场掉 1 颗本线终焉级「异化核」（含再挑战＝终焉试炼），存进存档，刻印归异化装备那一步。
## - 开场生存战撑过 6 回合的额外奖励；36 层首次通关点亮本线「骑士徽记」（只做外观，记全局配置）。
##
## 奖励装备是普通装备实例（XState.gear 里的字典）多一个 tq_reward 字段 {kind: seal／relic, line, tier, half}：
## 借 base 那件的图标和栏位，属性、特性、词缀、备注清空，名字和说明换成奖励的；不改原版数据库，存档照装备实例存。
## 发奖进度记在 flags.tianqi.rewards = {got: [来源键…], cores: [{line, affix, level, from}…]}，同一来源只发一次。
##
## 开关（O-330）：ENABLED＝false 时不发奖、已有的奖励装备不生效（还能穿、只是没效果）。
## 只认天启篇存档（XTianqiLine.open_for：发行构建里还要 XTianqi.RELEASE_OPEN）。

static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/rewards.json"
const FIELD := "tq_reward"
const LINES := ["death", "war", "famine", "plague"]
const META := "tq_reward_fight"

static var _data: Dictionary = {}
## 地图上这一场是本线的哪个使徒（XTianqiLine.before_battle 记，地图战斗打完 after_map_battle 取）
static var _apostle := ""
static var _apostle_line := ""


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiRewards: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary:
			push_error("XTianqiRewards: JSON 解析失败 " + PATH)
			return {}
		_data = parsed
	return _data


static func reload() -> void:
	_data = {}


## 表里设计数值含数字 4 的（豁免键见 nice_number_exempt）
static func nice_number_violations() -> Array:
	var out := []
	var d := data()
	XTianqiHorsemen._scan(d, "", d.get("nice_number_exempt", []), out)
	return out


static func on(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and s != null and XTianqiLine.open_for(s)


static func progress(s: XState) -> Dictionary:
	if not s.flags.get("tianqi") is Dictionary:
		s.flags["tianqi"] = {}
	if not s.flags.tianqi.get("rewards") is Dictionary:
		s.flags.tianqi["rewards"] = {"got": [], "cores": []}
	return s.flags.tianqi.rewards


static func got(s: XState, key: String) -> bool:
	return (progress(s).get("got", []) as Array).has(key)


static func _mark_got(s: XState, key: String) -> void:
	var p := progress(s)
	var list: Array = p.get("got", [])
	if not list.has(key):
		list.append(key)
	p["got"] = list


static func line_name(line: String) -> String:
	return str(XTianqi.line_info(line).get("name", line))


# ---- 奖励装备 ----

static func seal_info(line: String) -> Dictionary:
	var v = data().get("seal", {}).get("lines", {}).get(line)
	return v if v is Dictionary else {}


static func relic_info(line: String) -> Dictionary:
	var v = data().get("relic", {}).get("lines", {}).get(line)
	return v if v is Dictionary else {}


## 净印第 tier 档（1～3）的数
static func seal_value(line: String, tier: int) -> float:
	var vals: Array = seal_info(line).get("values", [])
	return float(vals[tier - 1]) if tier >= 1 and tier <= vals.size() else 0.0


## 遗物的数（完整版或半强度）
static func relic_params(line: String, half: bool) -> Dictionary:
	var v = relic_info(line).get("half" if half else "full")
	return v if v is Dictionary else {}


static func _num(v) -> String:
	return XTianqiBalance._num_text(float(v))


static func seal_name(line: String, tier: int) -> String:
	var names: Array = data().get("seal", {}).get("tier_names", [])
	var t := str(names[tier - 1]) if tier >= 1 and tier <= names.size() else str(tier)
	return "%s（%s）" % [str(seal_info(line).get("name", "")), t]


static func seal_text(line: String, tier: int) -> String:
	return str(seal_info(line).get("text", "")) % roundi(seal_value(line, tier))


static func relic_name(line: String, half: bool) -> String:
	return str(relic_info(line).get("name", "")) + (str(data().get("relic", {}).get("half_suffix", "")) if half else "")


static func relic_text(line: String, half: bool) -> String:
	var p := relic_params(line, half)
	var t := str(relic_info(line).get("text", ""))
	match line:
		"death":
			return t % [roundi(float(p.extra_attack_chance)), _num(p.crit_mult)]
		"war":
			return t % [int(p.spark_full), _num(p.bomb_coef), roundi(float(p.dmg_taken_pct))]
		"famine":
			return t % [int(p.stack_step), _num(p.stat_pct), int(p.max_stacks), roundi(float(p.heal_taken_pct))]
		"plague":
			return t % [int(p.taunt_turns), roundi(float(p.def_pct)), roundi(float(p.dmg_dealt_pct))]
	return t


## 做一件奖励装备（没进背包）。kind：seal／relic；seal 用 tier，relic 用 half
static func make_item(kind: String, line: String, tier := 1, half := false) -> Dictionary:
	var sec: Dictionary = data().get(kind, {})
	if sec.is_empty() or not LINES.has(line):
		return {}
	var item := XGear.template("armor", int(sec.get("base", 0)))
	if item.is_empty():
		return {}
	item.etypeId = int(sec.etype)
	item.params = [0, 0, 0, 0, 0, 0, 0, 0]
	item.traits = []
	item.note = ""
	item.meta = {}
	item.price = 0
	item.affixIds = []
	item.upgradeSlots = 0
	item.originalUpgradeSlots = 0
	var eq: Dictionary = item.get("equipment", {})
	eq = eq.duplicate(true)
	eq["affixes"] = []
	eq["slots"] = 0
	item["equipment"] = eq
	if kind == "seal":
		item.name = seal_name(line, tier)
		item.description = "效果：" + seal_text(line, tier)
		item[FIELD] = {"kind": "seal", "line": line, "tier": tier, "half": false}
	else:
		item.name = relic_name(line, half)
		item.description = "效果：%s\n%s" % [relic_text(line, half), str(relic_info(line).get("desc", ""))]
		item[FIELD] = {"kind": "relic", "line": line, "tier": 0, "half": half}
		XTianqiQiyinArt.dress_item(item, XTianqiQiyinArt.small_icon("relic_%s%s" % [line, "_broken" if half else ""]))  # 美术 O3：残缺版用残图
	item.baseName = str(item.name)
	return item


## 放进背包
static func _give(s: XState, item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	s.register_gear(item)
	s.gear.append(item)
	return item


static func tag(item) -> Dictionary:
	if not item is Dictionary:
		return {}
	var t = item.get(FIELD)
	return t if t is Dictionary else {}


## 神器栏收不收这件（XTianqiGear.allows：遗物不在原神武白名单上）
static func is_relic(item) -> bool:
	return str(tag(item).get("kind", "")) == "relic"


# ---- 发奖 ----

## 净印：source＝opening／apostle10／apostle20／apostle30。返回发的那件（发过或没开为空）
static func grant_seal(s: XState, line: String, source: String) -> Dictionary:
	var tier := int(data().get("seal", {}).get("sources", {}).get(source, 0))
	var key := "seal_%s_%s" % [line, source]
	if not on(s) or tier <= 0 or got(s, key):
		return {}
	_mark_got(s, key)
	return _give(s, make_item("seal", line, tier))


## 遗物：half＝35 层影子那件
static func grant_relic(s: XState, line: String, half: bool) -> Dictionary:
	var key := "relic_%s_%s" % [line, "half" if half else "full"]
	if not on(s) or relic_info(line).is_empty() or got(s, key):
		return {}
	_mark_got(s, key)
	return _give(s, make_item("relic", line, 0, half))


## 终焉异化核：本线 4 条里随机 1 条（每赢一场都给）。from 记来源（34／35／36、rechallenge 等）
static func grant_core(s: XState, line: String, from: String) -> Dictionary:
	var keys: Array = data().get("finale", {}).get("lines", {}).get(line, [])
	if not on(s) or keys.is_empty():
		return {}
	var i := clampi(floori(XGear.roll(s) * keys.size()), 0, keys.size() - 1)
	var core := {"line": line, "affix": str(keys[i]), "level": str(data().finale.get("level", "zhongyan")), "from": from}
	var p := progress(s)
	var list: Array = p.get("cores", [])
	list.append(core)
	p["cores"] = list
	return core


static func cores(s: XState) -> Array:
	return progress(s).get("cores", [])


static func core_name(core: Dictionary) -> String:
	var fin: Dictionary = data().get("finale", {})
	return "%s·%s 异化核" % [str(fin.get("level_name", "")), str(fin.get("names", {}).get(str(core.get("affix", "")), core.get("affix", "")))]


## 生存战撑过：额外奖励（只发一次）。返回发了什么（文字列表）
static func grant_survival(s: XState, line: String) -> Array:
	var key := "survival_" + line
	if not on(s) or got(s, key):
		return []
	_mark_got(s, key)
	var sv: Dictionary = data().get("survival", {})
	var out := []
	for e in sv.get("items", []):
		s.gain_item(int(e.item), int(e.amount))
		out.append("%s×%d" % [str(XDB.rec("Items", int(e.item)).get("name", "")), int(e.amount)])
	if int(sv.get("gold", 0)) > 0:
		s.gain_gold(int(sv.gold))
		out.append("%d 金钱" % int(sv.gold))
	return out


# ---- 骑士徽记（全局配置，跨存档只带外观） ----

static func badges() -> Array:
	return XConfig.tianqi_badges()


static func mark_badge(line: String) -> bool:
	return XConfig.tianqi_badge_mark(line)


static func badge_name(line: String) -> String:
	return str(data().get("badge", {}).get("name", "%s")) % line_name(line)


# ---- 关卡流程挂钩（XTianqiLine、XTianqiSummit 调；host 用来说话） ----

static func _say(host, text: String) -> void:
	if host != null and host.has_method("show_text"):
		await host.show_text("", 0, [text])


static func _say_item(host, item: Dictionary) -> void:
	if not item.is_empty():
		await _say(host, "得到了 \\c[2]%s\\c[0]。" % str(item.name))


static func _say_core(host, core: Dictionary) -> void:
	if not core.is_empty():
		await _say(host, "得到了 \\c[2]%s\\c[0]。" % core_name(core))


## 开场「天外裂」打完（输赢都走）：第一件净印；撑过的再给额外奖励
static func after_rift(host, s: XState, line: String, survived: bool) -> void:
	if not on(s):
		return
	if survived:
		var got_list := grant_survival(s, line)
		if not got_list.is_empty():
			await _say(host, "撑过了天外裂：得到了 %s。" % "、".join(PackedStringArray(got_list)))
	await _say_item(host, grant_seal(s, line, "opening"))


## 35 层影子：赢了给终焉核；第一次赢给半强度遗物
static func after_shadow(host, s: XState, line: String, result: int, from := "35") -> void:
	if not on(s) or result != 0:
		return
	await _say_item(host, grant_relic(s, line, true))
	await _say_core(host, grant_core(s, line, from))


## 36 层骑士：赢了给终焉核；第一次赢给完整遗物、点亮徽记。再挑战（终焉试炼）只给核
static func after_final(host, s: XState, line: String, result: int, from := "36") -> void:
	if not on(s) or result != 0:
		return
	if from == "36":
		await _say_item(host, grant_relic(s, line, false))
		if mark_badge(line):
			await _say(host, "点亮了「%s」。" % badge_name(line))
	if XGojo.strongest_check(s):
		await _say(host, XGojo.UNLOCK_TEXT)  # 天启篇五条悟开放方式「最强之名」
	await _say_core(host, grant_core(s, line, from))


## 34 层鸿钧（含再挑战）：赢了给终焉核
static func after_hongjun(host, s: XState, result: int, from := "34") -> void:
	var line := XTianqi.line_of(s)
	if not on(s) or result != 0 or not LINES.has(line):
		return
	await _say_core(host, grant_core(s, line, from))


## 地图开战前（XTianqiLine.before_battle 认出使徒时）
static func note_apostle(line: String, preset: String) -> void:
	_apostle = preset
	_apostle_line = line


## 地图战斗打完（XMapScene.start_battle 末尾）：使徒打赢掉净印；31～33 层终焉 Boss（boss_troops）打赢掉核
static func after_map_battle(host, s: XState, troop_id: int, result: int) -> void:
	var preset := _apostle
	var line := _apostle_line
	_apostle = ""
	_apostle_line = ""
	if s == null or not on(s) or result != 0:
		return
	if preset != "":
		await _say_item(host, grant_seal(s, line, preset))
	var cur := XTianqi.line_of(s)
	if LINES.has(cur) and (data().get("finale", {}).get("boss_troops", []) as Array).any(func(t): return int(t) == troop_id):
		await _say_core(host, grant_core(s, cur, "troop%d" % troop_id))


# ---- 战斗效果 ----

## 角色身上的奖励装备（kind：seal／relic）；关着返回空
static func worn(a, kind: String) -> Array:
	if not a is XActor or not ENABLED:
		return []
	return a.equip_list().filter(func(e): return str(tag(e).get("kind", "")) == kind)


## 这人穿的本线净印最高档（换过线的旧线净印不算）；没有为 0
static func seal_tier(a, line: String) -> int:
	if not a is XActor:
		return 0
	var s: XState = XState.current
	if s == null or not on(s) or XTianqi.line_of(s) != line:
		return 0
	var best := 0
	for e in worn(a, "seal"):
		var t := tag(e)
		if str(t.line) == line:
			best = maxi(best, int(t.tier))
	return best


## 上场的人里最好的本线净印
static func party_seal_tier(logic, line: String) -> int:
	var best := 0
	for a in logic.actors:
		if a.is_alive():
			best = maxi(best, seal_tier(a, line))
	return best


## 这人穿的遗物 {line, half, p}；没穿为空
static func relic_of(a) -> Dictionary:
	if not a is XActor:
		return {}
	var s: XState = XState.current
	if s == null or not on(s):
		return {}
	for e in worn(a, "relic"):
		var t := tag(e)
		return {"line": str(t.line), "half": bool(t.half), "p": relic_params(str(t.line), bool(t.half))}
	return {}


static func _relic_p(a, line: String) -> Dictionary:
	var r := relic_of(a)
	return r.p if not r.is_empty() and str(r.line) == line else {}


# -- 净印 --

## 饥荒（存粮）：饥饿的消耗倍率 m（≥1）往 1 拉回
static func famine_cost_mult(a, m: float) -> float:
	var t := seal_tier(a, "famine")
	return m if t <= 0 or m <= 1.0 else 1.0 + (m - 1.0) * (1.0 - seal_value("famine", t) / 100.0)


## 饥荒（存粮）：饥饿的回复倍率 m（≤1）往 1 拉回
static func famine_heal_mult(a, m: float) -> float:
	var t := seal_tier(a, "famine")
	return m if t <= 0 or m >= 1.0 else 1.0 - (1.0 - m) * (1.0 - seal_value("famine", t) / 100.0)


## 战争（止戈）：敌方火花这次要加 n 点，每点按几率不加，返回实际加几点
static func spark_gain(logic, n: int) -> int:
	if n <= 0 or logic == null:
		return n
	var t := party_seal_tier(logic, "war")
	if t <= 0:
		return n
	var chance := seal_value("war", t) / 100.0
	var out := 0
	for i in range(n):
		if logic._float("tq_seal_war") >= chance:
			out += 1
	return out


## 瘟疫（清心）：病弱每个减益降的比例
static func frail_per(a, per: float) -> float:
	var t := seal_tier(a, "plague")
	return minf(per, seal_value("plague", t) / 100.0) if t > 0 else per


## 死亡（长明）：被挂死期时，几率改为损失一半当前生命。终焉（骑士本体、影子）无效。返回 true＝这次不挂死期，已扣血
static func doom_spared(logic, a, finale: bool) -> bool:
	if finale or logic == null:
		return false
	var t := seal_tier(a, "death")
	if t <= 0 or logic._float("tq_seal_death") >= seal_value("death", t) / 100.0:
		return false
	a.hp = maxf(1.0, floorf(a.hp * (1.0 - float(seal_info("death").get("half_hp", 0.5)))))
	return true


# -- 遗物 --

## 开战（BattleLogic.setup 末尾）：本场记录（资历、火花、追加普攻）
static func setup(logic, _s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	for a in logic.actors:
		if a is XActor and a.has_meta(META):
			a.remove_meta(META)
	if not ENABLED:
		return
	var any := false
	for a in logic.actors:
		if not relic_of(a).is_empty():
			any = true
			a.set_meta(META, {"stacks": 0})
	if any:
		logic.set_meta(META, {"sparks": {}, "extra_turn": {}, "queue": []})


static func _fight(logic) -> Dictionary:
	return logic.get_meta(META) if logic != null and logic.has_meta(META) else {}


static func end(logic) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	for a in logic.actors:
		if a is XActor and a.has_meta(META):
			a.remove_meta(META)


static func take_logs(logic) -> Array:
	var f := _fight(logic)
	if f.is_empty():
		return []
	var out: Array = f.queue
	f.queue = []
	return out


static func _log(logic, text: String) -> void:
	var f := _fight(logic)
	if not f.is_empty():
		f.queue.append({"type": "battle_text", "text": text})


## executeHpDamage（天启篇各线之后）：雷火弹受伤 +、混子之盾出伤 −、卷子受到的回复 −；卷子技能击倒攒资历
static func hp_damage(logic, u, t, value: float, item := {}) -> float:
	if _fight(logic).is_empty():
		return value
	if value > 0.0:
		var pw := _relic_p(t, "war")
		if not pw.is_empty():
			value = floorf(value * (100.0 + float(pw.dmg_taken_pct)) / 100.0)
		var pp := _relic_p(u, "plague")
		if not pp.is_empty() and t is XEnemy:
			value = floorf(value * (100.0 - float(pp.dmg_dealt_pct)) / 100.0)
		var pf := _relic_p(u, "famine")
		if not pf.is_empty() and t is XEnemy and value >= t.hp and t.hp > 0.0 and not item.is_empty() \
				and int(item.get("id", 0)) != u.attack_skill_id() and not logic.is_item(item) and u.has_meta(META):
			var m: Dictionary = u.get_meta(META)
			if int(m.stacks) < int(pf.max_stacks):
				m.stacks = int(m.stacks) + 1
				if int(m.stacks) % int(pf.stack_step) == 0:
					_log(logic, "%s的资历攒到 %d 层：全属性 +%s%%。" % [u.display_name(), int(m.stacks),
						_num(float(pf.stat_pct) * (int(m.stacks) / int(pf.stack_step)))])
					u.param_refresh()
	elif value < 0.0:
		var ph := _relic_p(t, "famine")
		if not ph.is_empty():
			value = -floorf(-value * (100.0 - float(ph.heal_taken_pct)) / 100.0)
	return value


## itemCri：钥匙串的暴击率倍率
static func cri_mult(u) -> float:
	var p := _relic_p(u, "death")
	return float(p.crit_mult) if not p.is_empty() else 1.0


## XActor.param：卷子资历的全属性、混子之盾的双防
static func actor_param(a, i: int, v: float) -> float:
	if not a is XActor or not a.has_meta(META):
		return v
	var mult := 1.0
	var pf := _relic_p(a, "famine")
	if not pf.is_empty():
		var steps := int(a.get_meta(META).stacks) / int(pf.stack_step)
		mult += float(pf.stat_pct) / 100.0 * steps
	var pp := _relic_p(a, "plague")
	if not pp.is_empty() and (i == 3 or i == 5):
		mult += float(pp.def_pct) / 100.0
	return roundf(v * mult) if mult != 1.0 else v


## makeTargets：混子之盾开场嘲讽（敌人对我方的技能只打嘲讽的人）
static func filter_targets(logic, a, list: Array) -> Array:
	if _fight(logic).is_empty() or not a is XEnemy or list.size() <= 1:
		return list
	for b in list:
		var p := _relic_p(b, "plague")
		if not p.is_empty() and b.is_alive() and int(logic.turn) <= int(p.taunt_turns):
			return [b]
	return list


## 行动之后：钥匙串追加普攻（每回合第一次放技能后；普攻 attack_skill_id、防御 2 号不算）、雷火弹攒火花满了轰炸
static func after_action(logic, u, skill: Dictionary) -> Array:
	var f := _fight(logic)
	if f.is_empty() or not u is XActor or not u.is_alive() or skill.is_empty() or logic.is_item(skill):
		return []
	var logs := []
	var pd := _relic_p(u, "death")
	if not pd.is_empty() and int(skill.get("id", 0)) != u.attack_skill_id() and int(skill.get("id", 0)) != 2 \
			and int(f.extra_turn.get(u, -1)) != int(logic.turn):
		f.extra_turn[u] = int(logic.turn)
		if logic._float("tq_relic_death") < float(pd.extra_attack_chance) / 100.0:
			var t = _random_enemy(logic)
			if t != null:
				_log(logic, "%s追加了一次普攻。" % u.display_name())
				logs.append_array(take_logs(logic))
				var atk: Dictionary = u.attack_skill()
				logs.append(logic.horseman_strike(u, t, atk, logic._damage_value(u, atk, t, false), false))
	var pw := _relic_p(u, "war")
	if not pw.is_empty():
		var n := int(f.sparks.get(u, 0)) + 1
		if n >= int(pw.spark_full):
			n = 0
			_log(logic, "%s扔出了最后一枚雷火弹！" % u.display_name())
			logs.append_array(take_logs(logic))
			var atk: Dictionary = u.attack_skill()
			for e in logic.enemies.duplicate():
				if e.is_alive() and not e.hidden:
					logs.append(logic.horseman_strike(u, e, atk, floorf(logic._damage_value(u, atk, e, false) * float(pw.bomb_coef)), false))
		f.sparks[u] = n
	logs.append_array(take_logs(logic))
	return logs


static func _random_enemy(logic):
	var live: Array = logic.enemies.filter(func(e): return e.is_alive() and not e.hidden)
	return live[logic._int(0, live.size() - 1, "tq_relic_target")] if not live.is_empty() else null
