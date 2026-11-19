class_name XTianqiWeakB2
extends RefCounted
## 【cc·T230·未经审查】天启篇弱者专属词条批 2 前四人（私密仓 重制设定/天启篇_弱者专属词条设计_v0.3 第四节＋v0.3.1 第三节）。
## 地基在 XTianqiWeakAffix（作用域、根、事件类型、次数、角标出口）；这里只放四条的规则，表 weak_affix_table.json 的 w31／w23／w103／w3，
## 条目默认关（Kyo 11-19：86 人做完统一开放，不接掉落、商人、物品说明）。张三丰、布兰德瓦登归批 2B（另一单）。
##
## w31 露茜「催花」：治愈之歌 623 附加持续回复 55 时（battle_logic _apply_effect 效果 21），队友身上还挂着她上的 55 →
##   剩余回合数×生命上限×每跳比例（状态 55 的 HRG 特性）一次回完，只乘一次目标的受治疗修正 rec，移除旧的、这一次不拿新的；
##   每个目标每自然回合 1 次（同回合第二次照原生刷新）。谁上的 55 记在本场数据 regen_src（note_state）。
## w23 魔雷老人「蓄雷」：XTianqiSkills.end_action 里五雷那一行不再掷；本根有资格掷五雷就蓄 1 格，满格对本根主目标落一次（原生追加，
##   打满五段，伤害 × p×满格数 %），清零；落雷那一根不计格；每回合最多落 1 次（同原生追加的次数）；主目标已倒：不落、格数保留。
## w103 波风水门「黄色闪光」：每自然回合第一次飞雷神这一根 −30%（XTianqiWeakAffix.cut，formula 读）；根收尾时这一根直接有效命中过的敌人
##   下一回合顺序后推 1 格（每敌每回合 1 次）、挂刻印 10830（敏捷 −20%，2 回合，首领按普通减益减半）。
## w3 艾坤「一坤年之威」：end_action 里球来已过全部检查时取消、库存补到 3；队友主动根命中敌人后（root_end）对主目标打一次传球
##   （球来五段 ×33%），每回合 1 次，主目标已倒不打不扣。传球是专属派生（地基 root_end 时这一根已改 DERIVED：不连锁、打混子不记账）。

static var _installed := false


static func install() -> void:
	if _installed:
		return
	_installed = true
	XTianqiWeakAffix.register("w31", Lucy.new())
	XTianqiWeakAffix.register("w23", Molei.new())
	XTianqiWeakAffix.register("w103", Minato.new())
	XTianqiWeakAffix.register("w3", Aikun.new())


## 这个人此刻是否带着生效的 key
static func wears(logic, a, key: String) -> bool:
	return a is XActor and XTianqiWeakAffix.active_keys(logic, a).has(key)


static func _holder(logic, key: String):
	if logic == null:
		return null
	for a in logic.actors:
		if wears(logic, a, key):
			return a
	return null


static func _name(b) -> String:
	return str(b.display_name()) if b != null else ""


## 日志排队：结算深处（效果、追加）产生的行在这一根收尾时一起出
static func _queue(logic, line: Dictionary) -> void:
	if not XTianqiWeakAffix._active(logic):
		return
	var st := XTianqiWeakAffix._store(logic)
	if not st.has("b2_logs"):
		st.b2_logs = []
	st.b2_logs.append(line)


static func _take_logs(logic) -> Array:
	if not XTianqiWeakAffix._active(logic):
		return []
	var st := XTianqiWeakAffix._store(logic)
	var out: Array = st.get("b2_logs", [])
	st.b2_logs = []
	return out


# ---- w31 露茜「催花」 ----

## 效果 21 附加状态成功后：记下持续回复是谁上的（别人上的同名状态不被她结清）
static func note_state(logic, u, t, id: int) -> void:
	if not XTianqiWeakAffix._active(logic) or u == null or t == null:
		return
	var e := XTianqiWeakAffix.entry("w31")
	if e.is_empty() or id != int(e.get("settle", {}).get("state", 0)):
		return
	var st := XTianqiWeakAffix._store(logic)
	if not st.has("regen_src"):
		st.regen_src = {}
	st.regen_src[t] = u


static func regen_src(logic, t):
	if not XTianqiWeakAffix._active(logic):
		return null
	return XTianqiWeakAffix._store(logic).get("regen_src", {}).get(t)


## 状态的每跳回复比例（HRG 特性，code 22 dataId 7）
static func tick_rate(state_id: int) -> float:
	var v := 0.0
	for tr in XDB.rec("States", state_id).get("traits", []):
		if int(tr.get("code", 0)) == XBattler.TRAIT_XPARAM and int(tr.get("dataId", 0)) == 7:
			v += float(tr.get("value", 0.0))
	return v


## battle_logic _apply_effect 效果 21 每个状态前：是露茜戴着催花放治愈之歌、目标挂着她上的持续回复 → 结清并返回 true（这一次不拿新的）
static func settle(logic, u, t, id: int, r: Dictionary) -> bool:
	if not wears(logic, u, "w31") or t == null or not t.is_alive():
		return false
	if XTianqiWeakAffix.kind(logic) != XTianqiWeakAffix.ROOT:
		return false  # 只认主动根：词条再释放、原生追加、派生不结清（v0.3 第二节第 2 条）
	var sp: Dictionary = XTianqiWeakAffix.entry("w31").get("settle", {})
	var sid := int(sp.get("state", 0))
	if id != sid or int(r.get("skill", {}).get("id", 0)) != int(sp.get("skill", 0)):
		return false
	if not t.state_ids.has(sid) or not is_same(regen_src(logic, t), u):
		return false
	if not XTianqiWeakAffix.take_turn(logic, t, "w31"):
		return false  # 同回合第二次：照原生刷新
	var left := int(t.state_turns.get(sid, 0))
	var healed := heal_once(logic, u, t, floorf(t.mhp * tick_rate(sid) * left * t.rec))
	logic._state_remove(t, sid)
	r.removed.append(sid)
	XTianqiWeakAffix._store(logic).get("regen_src", {}).erase(t)
	_queue(logic, XTianqiWeakAffix.say("催花：%s 的持续回复立即结算（剩余 %d 回合，回复 %d）" % [_name(t), left, healed]))
	return true


## 结清的那一次回血（T230 R1 P1-1）：只过一次目标的受治疗修正——rec 已在 v 里，这里再过四骑士疫病减半／证道狂暴（hp_damage 的治疗分支）
## 和 gain 里的各条（禁疗、荒年者、烙印、宿傩伤口……）；不写 r.hp／record_hp（回春不把溢出转盾、不算溢出治疗），
## 也不盖掉这一招 10% 即时治疗写在结果槽里的弹字。返回实际回了多少（满血溢出的部分浪费）。
static func heal_once(logic, u, t, v: float) -> int:
	v = floorf(-float(XTianqiHorsemen.hp_damage(logic, u, t, -v)))
	if v <= 0.0:
		return 0
	var ctx = logic._operation_resources(t)  # 行动里就是这一根的结果槽（同 gain_hp）
	var res: Dictionary = ctx.result(t)
	var keep := {}
	for k in ["hpDamage", "hpAffected"]:
		if res.has(k):
			keep[k] = res[k]
	var before := float(t.hp)
	ctx.gain(t, "hp", v)
	for k in keep:
		res[k] = keep[k]
	logic._finish_lifecycle_operation(ctx, t)
	return maxi(0, int(float(t.hp) - before))


class Lucy:
	func root_end(logic, _f: Dictionary) -> Array:
		return XTianqiWeakB2._take_logs(logic)


# ---- w23 魔雷老人「蓄雷」 ----

static func thunder_full(rate: float) -> int:
	var sp: Dictionary = XTianqiWeakAffix.entry("w23").get("thunder", {})
	return int(sp.get("full_high", 2)) if roundi(rate * 100.0) >= int(sp.get("high_from", 50)) else int(sp.get("full_low", 3))


## XTianqiSkills.end_action 掷追加前：{cands 去掉五雷那一行, fall [招, 伤害百分比, 目标, 行倍率]（空＝不落）, logs}
static func thunder(logic, u, cands: Array, used: bool) -> Dictionary:
	var out := {"cands": cands, "fall": [], "logs": []}
	if not wears(logic, u, "w23"):
		return out
	var casts: Array = XTianqiWeakAffix.entry("w23").get("thunder", {}).get("casts", [])
	var row = null
	for c in cands:
		if casts.has(float(c[0].get("id", 0))) or casts.has(int(c[0].get("id", 0))):
			row = c
			break
	if row == null:
		return out  # 不是原本有资格掷五雷的根：不蓄
	out.cands = cands.filter(func(c): return not is_same(c, row))  # 原生几率不再掷
	var full := thunder_full(float(row[1]))
	var s := XTianqiWeakAffix.stock(logic, u, "w23")
	var n := mini(int(s.get("n", 0)), full)
	if n < full:
		n += 1
		out.logs.append(XTianqiWeakAffix.say("蓄雷 %d/%d" % [n, full]))
	s.n = n
	s.full = full
	if n < full or used:
		return out  # 没满；或满了但这回合已落过（保持满格，下回合第一个合格的根落）
	var t = XTianqiWeakAffix.main_target(logic)
	if t == null or not t.is_alive() or t.is_actor() == u.is_actor():
		out.logs.append(XTianqiWeakAffix.say("蓄雷已满，目标已倒下，暂不落雷"))
		return out
	s.n = 0
	var pct := roundi(float(row[1]) * 100.0) * full
	out.fall = [row[0], pct, t, float(row[2])]
	out.logs.append(XTianqiWeakAffix.say("蓄雷已满，天罡五雷落下！"))
	return out


class Molei:
	func badge(logic, b) -> String:
		if not XTianqiWeakB2.wears(logic, b, "w23"):
			return ""
		if not XTianqiWeakB2.molei_can(b):
			return ""  # 没学天师真言术（5083）：根本蓄不了雷，不挂
		var full := XTianqiWeakB2.thunder_full(XTianqiWeakB2.molei_rate(b))  # 满格数随此刻的几率档位实时算
		return "蓄雷 %d/%d" % [mini(int(XTianqiWeakAffix.stock(logic, b, "w23").get("n", 0)), full), full]


## 显示用：魔雷术那一行五雷追加（表里 casts 认的那一行，学没学都给）
static func molei_row() -> Dictionary:
	var casts: Array = XTianqiWeakAffix.entry("w23").get("thunder", {}).get("casts", [])
	for id in [217]:
		for r in XTianqiSkills.spec(id).get("follow", []):
			if casts.has(float(r.get("cast", 0))) or casts.has(int(r.get("cast", 0))):
				return r
	return {}


## 显示用：他此刻五雷的几率
static func molei_rate(a) -> float:
	var r := molei_row()
	return XTianqiSkills._rate(a, r) if not r.is_empty() else 0.3


## 显示用：他有没有资格掷五雷（那一行的 need_skill，天师真言术 5083）
static func molei_can(a) -> bool:
	var need := int(molei_row().get("need_skill", 0))
	return need <= 0 or XTianqiSkills.owns(a, need)


# ---- w103 波风水门「黄色闪光」 ----

class Minato:
	func root_skill(logic, f: Dictionary, skill) -> void:
		var u = f.get("user")
		var sp: Dictionary = XTianqiWeakAffix.entry("w103").get("mark", {})
		if not XTianqiWeakB2.wears(logic, u, "w103") or not (skill is Dictionary) or int(skill.get("id", 0)) != int(sp.get("skill", 0)):
			return
		if not XTianqiWeakAffix.take_turn(logic, u, "w103"):
			return  # 同回合第二次：不扣、不推
		f.w103 = true
		XTianqiWeakAffix.cut = {"user": u, "skill": int(sp.get("skill", 0)), "pct": int(sp.get("cut_pct", 100))}

	func root_end(logic, f: Dictionary) -> Array:
		if not bool(f.get("w103", false)):
			return []
		var sp: Dictionary = XTianqiWeakAffix.entry("w103").get("mark", {})
		var sid := int(sp.get("state", 0))
		var n := 0
		var seen := []
		for h in f.get("hits", []):
			var t = h.target
			if not seen.has(t) and t is XEnemy and t.is_alive():
				seen.append(t)
		# 从下一回合顺序里排得靠后的先推：相邻的两个都被命中时各退一格，不会互换回原位
		seen.sort_custom(func(x, y): return logic.next_order.find(x) > logic.next_order.find(y))
		for t in seen:
			if not XTianqiWeakAffix.take_turn(logic, t, "w103_push"):
				continue
			logic._shift(t, int(sp.get("shift", -1)), false)  # 下一回合的顺序后推（本回合不动）
			var turns := XTianqiWeakAffix.boss_turns(t, sid, int(sp.get("turns", 2)))
			if sid > 0 and turns > 0:
				logic._state_add(t, sid)
				if t.state_ids.has(sid):
					t.state_turns[sid] = turns  # 不叠加，重复上只刷新；被抵抗、免疫没挂上就不写回合
			n += 1
		if n == 0:
			return []
		return [XTianqiWeakAffix.say("黄色闪光：%d 名敌人下回合行动后推 1 格" % n)]


# ---- w3 艾坤「一坤年之威」 ----

## end_action 里追加招已过全部检查、即将结算：是艾坤带传球、招是球来 → 库存补到上限，返回日志（非空＝这次球来取消）
static func intercept_pass(logic, u, cast: Dictionary) -> Array:
	if not wears(logic, u, "w3"):
		return []
	var sp: Dictionary = XTianqiWeakAffix.entry("w3").get("pass", {})
	if int(cast.get("id", 0)) != int(sp.get("cast", 0)):
		return []
	var s := XTianqiWeakAffix.stock(logic, u, "w3")
	s.n = int(sp.get("stock", 3))  # 补足到上限，多的作废
	return [XTianqiWeakAffix.say("球来蓄势：传球 ×%d" % int(s.n))]


## 传球用的那一份球来（T230 R1 P1-2）：原序列 target 段是「action effect: enemies」（打场上全体），拷一份把段参数清掉，只打传进去的主目标；
## 只改这份拷贝，共享 XDB 记录、关着 w3 时的原生球来不动
static func pass_cast(a, id: int) -> Dictionary:
	var cast: Dictionary = XTianqiWeakAffix.skill_view(XDB.rec("Skills", id), a).duplicate(true)
	if cast.get("yepSeq") is Dictionary:
		for ph in cast.yepSeq:
			if cast.yepSeq[ph] is Array:
				cast.yepSeq[ph] = XTianqiSkills._seq_edit(cast.yepSeq[ph], [{"op": "clear_effect_args"}])
	return cast


class Aikun:
	func root_end(logic, f: Dictionary) -> Array:
		var a = XTianqiWeakB2._holder(logic, "w3")
		var u = f.get("user")
		if a == null or not (u is XActor) or is_same(u, a) or (f.get("hits", []) as Array).is_empty():
			return []
		var s := XTianqiWeakAffix.stock(logic, a, "w3")
		if int(s.get("n", 0)) <= 0:
			return []
		var t = f.get("main")
		if t == null or not (t is XEnemy) or not t.is_alive():
			return []  # 主目标已倒：不打，不扣库存
		if not XTianqiWeakAffix.take_turn(logic, a, "w3"):
			return []
		var sp: Dictionary = XTianqiWeakAffix.entry("w3").get("pass", {})
		s.n = int(s.n) - 1
		var cast := XTianqiWeakB2.pass_cast(a, int(sp.get("cast", 0)))
		var logs := [XTianqiWeakAffix.say("艾坤传球！（剩 %d）" % int(s.n))]
		var prev := XTianqiSkills.follow_scale
		XTianqiSkills.follow_scale = int(sp.get("pct", 100)) / 100.0
		logs.append_array(XTianqiSkills._cast(logic, a, cast, [t]))
		XTianqiSkills.follow_scale = prev
		return logs

	func badge(logic, b) -> String:
		if not XTianqiWeakB2.wears(logic, b, "w3"):
			return ""
		var n := int(XTianqiWeakAffix.stock(logic, b, "w3").get("n", 0))
		return "传球 ×%d" % n if n > 0 else ""
