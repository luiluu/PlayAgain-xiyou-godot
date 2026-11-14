class_name XTianqiQiyinRule
extends RefCounted
## 【cc·天启篇·未经审查】七个里副本的战斗规则（七印祭坛方案 v0.4 第 3 节；参数在 qiyin_altar.json 的 rules）。
## 每条规则敌我都算。只在 XTianqiQiyin.run_dungeon 开的战斗里生效（prepare 过才开），别的战斗一概不动。
##
## - 不愈（白印）：减益不会到期，只能驱散。减益＝能力值减益（buff 层数为负）和「坏状态」（行动限制、HP 再生为负、能力值倍率 <1、
##   命中／闪避等 xparam 为负、属性有效度 >1 的状态，见 debuff_state）。
## - 杀声（红印）：场上每有一个单位倒下（敌我都算），双方出伤 +5%。
## - 限时（黑印）：所有单位魔法、TP 不自然恢复（回合末再生）；我方每回合合计只能放 5 个技能（普攻、防御、物品不算）。
## - 魔塔（灰印）：没有暴击；宝石在 XTianqiQiyin 里每场前选，攻击按我方出伤 ×(1＋累计)、防御和生命按我方受伤 ÷(1＋累计)。
## - 献祭（殉印）：每回合开始，生命最高的单位损失 10% 当前生命，它那一方本回合出伤 +10%。
## - 星坠（震印）：每 3 回合（第 3、6、9…回合开始），全场损失当前生命的 33%（按当前生命，不会致死）。
## - 寂静（默印）：双数回合全场沉默：我方只能普攻、防御、用物品；敌人只普攻。
##
## 里副本的敌人还会按 rebase 重标能力值（Boss 换名字），借 XEnemy.horseman 的合成记录口子（同 XTianqiSummit 的鸿钧）。
## 计量和提示只在战斗日志里报（battle_text）。
##
## 七印书卷（神器，方案 6.4 节）：别的战斗里开战从七条规则随机揭一条（XTianqiQiyinEffects 掷、记在 enemy_only_rule），
## 本模块按「对敌方和佩戴者生效」跑（佩戴者自己也受是书卷的代价，其余队友不受；Kyo 11-14，开关 SCROLL_COST）：
##   不愈：敌人和佩戴者的减益不到期；杀声：打在敌人和佩戴者身上的伤害按倒下数加；限时：敌方合计、佩戴者自己各算 5 个技能，
##   敌人和佩戴者魔法、TP 不自然恢复；魔塔：敌人和佩戴者不能暴击；献祭：敌方生命最高那只和佩戴者各失去 10% 当前生命（都不加伤）；
##   星坠：敌人和佩戴者失去当前生命的 33%；寂静：双数回合敌人只普攻、佩戴者只能普攻、防御、用物品。
##   代价跟着佩戴者走（协调 11-14，gpt 核查 P2）：佩戴者被天启换人换到助力位，只要活着星坠、献祭照扣；不愈、魔塔、寂静、限时、杀声
##   只在他行动、被打、回合结算时才有落点，人在助力位不行动、不挨打、状态不走回合，等于暂停，换回场上接着生效；佩戴者阵亡后代价停、
##   揭开的规则对敌方照旧生效。
## 豁免（Kyo 11-14，开关 SCROLL_BOSS_EXEMPT）：战斗里有天启四骑士（含影子、生存战）或 34～36 层首领（鸿钧）时书卷不揭、不付代价，
##   开场说一句。里副本里本印规则优先，书卷不再叠一条。

const META := "xqiyin_rule"

## 开关（O-425）：true＝七印书卷揭开的规则佩戴者自己也受；false＝回到只对敌方
static var SCROLL_COST := true
## 开关（O-425）：true＝有天启四骑士或 34～36 层首领的战斗里书卷不揭；false＝回到哪场都揭
static var SCROLL_BOSS_EXEMPT := true

static var _pending: Dictionary = {}


## 规则是不是七印书卷揭的（只对敌方和佩戴者）
static func enemy_only(logic) -> bool:
	return bool(fight(logic).get("enemy_only", false))


## 七印书卷的佩戴者（代价落在他身上）；不是书卷的战斗或代价关着时 null
static func scroll_owner(logic):
	if not enemy_only(logic) or not SCROLL_COST:
		return null
	return fight(logic).get("owner")


static func _is_owner(logic, b) -> bool:
	var o = scroll_owner(logic)
	return o != null and b != null and is_same(o, b)


## 这一下规则落不落在 b 身上（书卷落在敌人和佩戴者身上；b 为 null 时按「落」）
static func _hits(logic, b) -> bool:
	return not enemy_only(logic) or b == null or b is XEnemy or _is_owner(logic, b)


## 书卷豁免：这场有天启四骑士（本体、影子、生存战）或 34～36 层首领（鸿钧；35、36 层就是骑士的影子和本体）
static func scroll_exempt(logic) -> bool:
	if not SCROLL_BOSS_EXEMPT or logic == null:
		return false
	if XTianqiHorsemen.active(logic) or XTianqiSummit._at in [34, 35, 36]:
		return true
	for e in logic.enemies:
		var rec = e.horseman.get("rec", {}) if e.horseman is Dictionary else {}
		if bool(e.horseman.get("knight", false)) or (rec is Dictionary and str(rec.get("_ref", "")) == "hongjun"):
			return true
	return false


## 七印书卷：不是里副本的战斗、装备者的神器揭了规则时，第一次用到时建本场记录（XTianqiQiyinEffects.start 之后）
static func _ensure_scroll(logic) -> void:
	if logic == null or logic.has_meta(META) or logic.state == null or not XTianqiQiyin.allowed(logic.state):
		return
	if XTianqiQiyinEffects.scroll_exempted(logic):  # 豁免的战斗：不揭、不付代价，只说一句（规则名空，各钩子都不动）
		var fe := {"seal": "", "rule": "", "boss": false, "gems": {}, "queue": [], "skills_used": 0, "owner_skills": 0,
			"side_bonus": "", "silent": false, "enemy_only": true, "exempt": true}
		logic.set_meta(META, fe)
		_say(fe, "七印书卷沉寂了：天启的骑士与登顶之战面前，七印不肯揭开。")
		return
	var key := XTianqiQiyinEffects.enemy_only_rule(logic)
	var info := XTianqiQiyin.seal_info(key)
	if info.is_empty():
		return
	var owner = XTianqiQiyinEffects.artifact_owner(logic)
	var f := {"seal": key, "rule": str(info.rule), "boss": false, "gems": {}, "queue": [], "skills_used": 0, "owner_skills": 0,
		"side_bonus": "", "silent": false, "enemy_only": true, "owner": owner}
	logic.set_meta(META, f)
	if SCROLL_COST and owner != null:
		_say(f, "七印书卷揭开了【%s】，对敌方和%s生效：%s" % [str(info.rule_name), str(owner.display_name()), str(info.rule_text)])
	else:
		_say(f, "七印书卷揭开了【%s】，只对敌方生效：%s" % [str(info.rule_name), str(info.rule_text)])


## 下一场按这一印的规则打（is_boss＝第三场 Boss 战；gems＝魔塔累计的宝石 {atk, def, hp}）
static func prepare(seal: String, is_boss := false, gems := {}) -> bool:
	if XTianqiQiyin.seal_info(seal).is_empty():
		_pending = {}
		return false
	_pending = {"seal": seal, "boss": is_boss, "gems": gems.duplicate()}
	return true


static func pending() -> Dictionary:
	return _pending


static func active(logic) -> bool:
	return logic != null and logic.has_meta(META)


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if active(logic) else {}


static func rule_of(logic) -> String:
	return str(fight(logic).get("rule", ""))


static func param(key: String) -> Dictionary:
	var v = XTianqiQiyin.data().get("rules", {}).get(key)
	return v if v is Dictionary else {}


## BattleLogic.setup：敌群建完后调（四骑士、战争线异化、34 层之后）
static func setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	var p := _pending
	_pending = {}
	if p.is_empty() or not XTianqiQiyin.allowed(s):
		return
	var info := XTianqiQiyin.seal_info(str(p.seal))
	var f := {"seal": str(p.seal), "rule": str(info.rule), "boss": bool(p.boss), "gems": p.gems,
		"queue": [], "skills_used": 0, "side_bonus": "", "silent": false}
	logic.set_meta(META, f)
	rebase(logic, info, bool(p.boss))
	_say(f, "【%s】%s" % [str(info.rule_name), str(info.rule_text)])


## 敌人按参照敌人重标能力值；Boss 战里那只 Boss 换名字、再乘 boss_rate。掉落清空（掉落走 XTianqiQiyinDrop）。
static func rebase(logic, info: Dictionary, is_boss: bool) -> void:
	var rb: Dictionary = XTianqiQiyin.data().get("rebase", {})
	var ref: Array = XDB.rec("Enemies", int(rb.get("ref", 0))).get("params", [])
	if ref.size() < 8:
		return
	var boss: Dictionary = info.get("boss", {})
	for e in logic.enemies:
		if not e.horseman.is_empty():
			continue
		var rec: Dictionary = XDB.rec("Enemies", int(e.enemy_id)).duplicate(true)
		var is_b := is_boss and int(e.enemy_id) == int(boss.get("enemy", -1))
		var rate: Array = rb.get("boss" if is_b else "elite", [])
		var extra: Array = boss.get("boss_rate", []) if is_b else []
		var params := []
		for i in 8:
			var v := float(ref[i]) * (float(rate[i]) if i < rate.size() else 1.0)
			if i < extra.size():
				v *= float(extra[i])
			params.append(roundf(v))
		rec.params = params
		rec["_ref"] = "qiyin"  # 守层者重算（XGuardianRework）：按鸿蒙老祖重标的，出伤跟 33 层一档
		if is_b:
			rec.name = str(boss.get("name", rec.get("name", "")))
			XTianqiQiyinArt.dress_battler(rec, str(boss.get("battler", "")))
		rec.dropItems = []
		e.horseman = {"rec": rec, "knight": false}
		e.refresh_passive()
		e.recover_all()


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	_ensure_scroll(logic)
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


# ---- 回合开始：献祭、星坠、寂静、限时计数清零 ----

## BattleLogic.start_turn 末尾（turn 已经 +1）
static func start_turn(logic) -> Array:
	_ensure_scroll(logic)
	if not active(logic):
		return []
	var f := fight(logic)
	f.skills_used = 0
	f.owner_skills = 0
	f.side_bonus = ""
	var t := int(logic.turn)
	match str(f.rule):
		"sacrifice":
			var top = null
			for b in logic.actors + logic.enemies:
				if b.is_alive() and _hits(logic, b) and not _is_owner(logic, b) and (top == null or b.hp > top.hp):
					top = b
			if top != null:
				_lose(top, float(param("sacrifice").get("hp_loss", 0.1)))
				if enemy_only(logic):
					_say(f, "献祭：%s失去生命。" % top.display_name())
				else:
					f.side_bonus = "actor" if top is XActor else "enemy"
					_say(f, "献祭：%s失去生命，%s本回合出伤提升。" % [top.display_name(), "我方" if f.side_bonus == "actor" else "敌方"])
			var own = scroll_owner(logic)
			if own != null and own.is_alive():  # 书卷的代价：佩戴者每回合也献一次（不加伤；和敌人比生命基本轮不到他，单算）
				_lose(own, float(param("sacrifice").get("hp_loss", 0.1)))
				_say(f, "献祭：%s失去生命。" % own.display_name())
		"star_fall":
			var every := int(param("star_fall").get("every_turns", 3))
			if every > 0 and t % every == 0:
				var loss := float(param("star_fall").get("hp_loss", 0.33))
				for b in logic.actors + logic.enemies:
					if b.is_alive() and _hits(logic, b) and not _is_owner(logic, b):
						_lose(b, loss)
				var own1 = scroll_owner(logic)
				if own1 != null and own1.is_alive():  # 书卷的代价跟着佩戴者走：换到助力位也照付（死了不付）
					_lose(own1, loss)
				var who := "全场"
				if enemy_only(logic):
					var own2 = scroll_owner(logic)
					who = "敌方和%s" % own2.display_name() if own2 != null else "敌方"
				_say(f, "星坠：天上落下了星星，%s失去当前生命的 %d%%。" % [who, roundi(loss * 100.0)])
		"silence":
			f.silent = t % 2 == 0
			XTianqiQiyinArt.silence_turn(logic, not f.silent)
			if f.silent:
				if not enemy_only(logic):
					_say(f, "寂静：这一回合谁都说不出话。")
				elif scroll_owner(logic) != null:
					_say(f, "寂静：这一回合敌人和%s说不出话。" % scroll_owner(logic).display_name())
				else:
					_say(f, "寂静：这一回合敌人说不出话。")
	return take_logs(logic)


## 按当前生命扣，不致死
static func _lose(b, rate: float) -> void:
	var d := floorf(b.hp * rate)
	b.hp = maxf(1.0, b.hp - d)


# ---- 行动限制：寂静、限时 ----

static func _plain(logic, a, skill: Dictionary) -> bool:
	if skill.is_empty():
		return true
	if XBattleLogic.is_item(skill):
		return true
	var id := int(skill.get("id", 0))
	return id == XBattleLogic.GUARD_SKILL or id == a.attack_skill_id()


## BattleLogic.can_use 末尾：寂静的双数回合、限时用满 5 个技能时，我方只能普攻、防御、用物品
static func can_use(logic, a, skill: Dictionary) -> bool:
	if not XTianqiQiyinEffects.skill_usable(logic, a, skill):  # 默印 5 件「万籁俱寂」每场次数、没穿满
		return false
	if not active(logic) or _plain(logic, a, skill):
		return true
	var f := fight(logic)
	if bool(f.silent) and _hits(logic, a):
		return false
	if str(f.rule) == "exam":
		var k := _exam_key(logic, a)
		if k != "" and int(f.get(k, 0)) >= int(param("exam").get("skills_per_turn", 5)):
			return false
	return true


## 限时的技能数算哪一方：里副本算我方，七印书卷算敌方
static func _exam_side(logic, a) -> bool:
	return a is XEnemy if enemy_only(logic) else a is XActor


## 限时记数的格子：一方合计 skills_used；书卷的佩戴者自己单算 owner_skills；不受限的 ""
static func _exam_key(logic, a) -> String:
	if _exam_side(logic, a):
		return "skills_used"
	return "owner_skills" if _is_owner(logic, a) else ""


## BattleLogic.decide（敌人）：寂静的双数回合只普攻
static func decide_enemy(logic, b) -> Array:
	if active(logic) and bool(fight(logic).silent):
		return [b.attack_skill(), null]
	return []


## BattleLogic.act 开头：记我方这回合放了几个技能（限时）
static func on_act(logic, u, skill) -> void:
	if not active(logic) or str(fight(logic).rule) != "exam":
		return
	var k := _exam_key(logic, u)
	if k == "" or not skill is Dictionary or _plain(logic, u, skill):
		return
	fight(logic)[k] = int(fight(logic).get(k, 0)) + 1


# ---- 不愈、限时（再生）、魔塔（暴击） ----

## 坏状态：行动限制、HP 再生为负、能力值倍率 <1、xparam 为负、属性有效度 >1
static func debuff_state(id: int) -> bool:
	var rec := XDB.rec("States", id)
	if int(rec.get("restriction", 0)) > 0:
		return true
	for tr in rec.get("traits", []):
		var code := int(tr.get("code", 0))
		var v := float(tr.get("value", 0.0))
		if code == XBattler.TRAIT_XPARAM and v < 0.0:
			return true
		if code == 21 and v < 1.0:  # 能力值倍率
			return true
		if code == 11 and v > 1.0:  # 属性有效度
			return true
	return false


## BattleLogic._tick_states：不愈时减益不减回合
static func keeps_state(logic, id: int, b = null) -> bool:
	return active(logic) and str(fight(logic).rule) == "no_cure" and _hits(logic, b) and debuff_state(id)


## BattleLogic._tick_states 的能力值减益（buff 层数为负）
static func keeps_debuff(logic, level: int, b = null) -> bool:
	return active(logic) and str(fight(logic).rule) == "no_cure" and level < 0 and _hits(logic, b)


## BattleLogic._regenerate：限时时魔法、TP 不恢复
static func no_regen(logic, b = null) -> bool:
	return active(logic) and str(fight(logic).rule) == "exam" and _hits(logic, b)


## BattleLogic.item_cri：魔塔没有暴击
static func no_crit(logic, u = null) -> bool:
	return active(logic) and str(fight(logic).rule) == "magic_tower" and _hits(logic, u)


# ---- 伤害：杀声、献祭、魔塔宝石 ----

## BattleLogic._execute_hp_damage_ledger：正伤害按规则乘
static func hp_damage(logic, u, t, value: float) -> float:
	if not active(logic) or value <= 0.0:
		return value
	var f := fight(logic)
	match str(f.rule):
		"war_cry":
			if not _hits(logic, t):
				return value
			var dead := 0
			for b in logic.actors + logic.enemies:
				if b.is_dead():
					dead += 1
			value *= 1.0 + float(param("war_cry").get("per_death", 0.05)) * dead
		"sacrifice":
			if u != null and str(f.side_bonus) == ("actor" if u is XActor else "enemy"):
				value *= 1.0 + float(param("sacrifice").get("dmg_up", 0.1))
		"magic_tower":
			var g: Dictionary = f.get("gems", {})
			if u is XActor:
				value *= 1.0 + float(g.get("atk", 0.0))
			if t is XActor:
				value /= 1.0 + float(g.get("def", 0.0)) + float(g.get("hp", 0.0))
	return value


# ---- 收尾 ----

## BattleLogic.end_battle：清本场；不是里副本的 31～35 层战斗打赢了，掉印钥（XTianqiQiyin.field_drop）
static func end(logic, result: int) -> void:
	if active(logic):
		var dungeon := not enemy_only(logic)
		logic.remove_meta(META)
		if dungeon:
			return
	if result != 0 or logic.state == null:
		return
	XTianqiQiyin.field_drop(logic.state, int(logic.state.map_id), str(XDB.rec("Troops", int(logic.troop_id)).get("name", "")))
