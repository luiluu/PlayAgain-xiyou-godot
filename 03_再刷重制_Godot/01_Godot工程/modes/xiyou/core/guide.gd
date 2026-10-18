class_name XGuide
extends RefCounted
## 修行指引（installNativeGuidanceRuntime，CodexGuide）第一批：状态页「修行」页的行（JAH_Window_Status_Zhenqi.buildRows）与战力条旁的真气文字。
## 参照 zhenqi_probe 的 page.* 用例（tests/xiyou_zhenqi 逐行比）。
## - 行：{type: head/text/cols/blank, …}，text 里保留 \C[n] 颜色码（XMVCanvas 按 drawTextEx 画）。
## - 加成只显示、按数值平衡不移植：页上与战力条的「加成 ×N」「天道补偿 ×N」照原版算，但重制版伤害不乘（见 XZhenqi.APPLY_TO_DAMAGE）。
## - 「五个乘区」一段（CodexZones，五乘区预算软上限）按数值平衡不移植（用户 2026-10-12），整段不显示（O-044）。
## - 第二阶段：区段里程碑（首次进新区段时的对话，每段一次，看过记 XState.guide_seen）与方桌大厅「商店向导」→「下一步建议」。
##   区段表 G.ATLAS 照原版（modes/xiyou/guide_atlas.json，冻结源抽出，tests/xiyou_guide 与参照比对）。参照 mv_oracle/guide_probe.cjs → generated/oracle/guide.json。
##   「战力短板」一段来自五乘区预算（CodexZones），同修行页不移植（O-050）；「洪荒权能」一句随洪荒难度（未移植）。
## - Boss 预告原版关闭（G.PREVIEW_ENABLED=false，无调用处），不做。

## 难度技能名单（CodexGuide.difficultySkillIds）
static var MANAGED: Array = _managed()


static func _managed() -> Array:
	var out := [6241, 10300, 5561, 5547, 5548, 5549, 5562, 5564, 5980, 5968, 5969, 5970, 5971, 5972, 5973, 6250, 6251, 6252, 6253, 6168, 6216, 6235,
		8100, 8105, 8106, 8107, 8108, 8109, 8110, 8111]
	for i in range(2872, 2898):
		out.append(i)
	for i in range(7201, 7216):
		out.append(i)
	return out


static func pct(v: float, sign := false) -> String:
	var t := XZhenqi.group(v * 100) + "%"
	return "+" + t if sign and v > 0 else t


## settlement：技能与装备备注 <Start(WT)PushState N: 100%> 推送的状态，取 Custom Confirm Effect 里 value * k 的 k 连乘
static func settlement(a: XActor) -> float:
	var prod := 1.0
	var seen := {}
	var notes := []
	for sk in a.skills():
		notes.append(str((sk if sk is Dictionary else XDB.rec("Skills", int(sk))).get("note", "")))
	for e in a.equip_list():
		if e != null:
			notes.append(str(e.get("note", "")))
	var re := RegEx.create_from_string("(?i)<Start(?:WT)?PushState(\\d+):\\s*100%>")
	var kre := RegEx.create_from_string("(?is)<Custom Confirm Effect>.*?value\\s*\\*\\s*([\\d.]+).*?</Custom Confirm Effect>")
	for n in notes:
		for m in re.search_all(n):
			var id := int(m.get_string(1))
			if seen.has(id):
				continue
			seen[id] = true
			var k := kre.search(str(XDB.rec("States", id).get("note", "")))
			if k:
				prod *= float(k.get_string(1))
	return prod


static func _snap(a: XActor) -> Dictionary:
	a.refresh_passive()
	var pc: Dictionary = a._passive_cache
	return {"cri": a.cri, "hit": a.hit, "crit": float(pc.get("critHarmRi", 0.0)), "fin": float(pc.get("globalHarmRi", 0.0)),
		"atk": a.atk, "mat": a.mat, "settle": settlement(a)}


## CodexGuide.compare：现状与「忘掉难度技能」相减（原版深拷贝角色；这里临时改技能表后原样恢复）
static func compare(a: XActor) -> Dictionary:
	var now := _snap(a)
	var saved := a.skill_ids.duplicate()
	for id in saved:
		if MANAGED.has(int(id)):
			a.forget_skill(int(id))
	var base := _snap(a)
	a.skill_ids = saved
	a.refresh_passive()
	return {"now": now, "base": base, "diff": {"cri": now.cri - base.cri, "hit": now.hit - base.hit, "crit": now.crit - base.crit, "fin": now.fin - base.fin,
		"atk": now.atk / base.atk if base.atk else 1.0, "mat": now.mat / base.mat if base.mat else 1.0, "settle": now.settle / base.settle if base.settle else 1.0}}


static func context(s: XState) -> Dictionary:
	var r := XZhenqi.route(s)
	var f := clampi(int(s.variable(20)) if int(s.variable(20)) else 1, 1, 33)
	return {"route": r, "floor": f, "comp": XZhenqi.comp_for(r.key, f)}


static func tips(s: XState, a: XActor, c: Dictionary) -> Array:
	var out := []
	var st := XZhenqi.state_of(s, a)
	if st.pending:
		out.append("\\C[17]有 %d 项突破奖励未选：打开菜单「真气」选择。" % int(st.pending))
	if st.canBreak:
		out.append("\\C[17]真气已到%s大圆满：打开菜单「真气」挑战%s，突破%s。" % [XZhenqi.REALMS[st.realm].name, XZhenqi.REALMS[st.realm + 1].trial, st.next])
	if c.now.cri < 1:
		out.append("\\C[2]暴击率只有 %s（难度扣了 %s）：学暴击率被动，或换带暴击率的装备。" % [pct(c.now.cri), pct(-c.diff.cri)])
	if 1.5 + c.now.crit <= 1:
		out.append("\\C[2]爆伤被扣到底，暴击只有 ×1：学爆伤被动（爆伤书、天赋、境界奖励）。")
	if c.now.hit < 1:
		out.append("\\C[2]命中只有 %s：带命中或暴击率的被动（命中书已改为暴击率）。" % pct(c.now.hit))
	if c.diff.atk < 0.5 or c.diff.mat < 0.5:
		out.append("\\C[2]难度把攻击压到 %s：学属性%%被动、吃淬元丹。" % XZhenqi.mult(maxf(c.diff.atk, c.diff.mat)))
	if out.is_empty():
		out.append("\\C[3]各项门槛都已越过：现在主要看伤害量（真气、装备、结算类被动）和 Boss 机制。")
	return out


static func _head(t: String) -> Dictionary:
	return {"type": "head", "text": t}


static func _line(t: String) -> Dictionary:
	return {"type": "text", "text": t}


static func _cols(cells: Array, system := false, warn := false) -> Dictionary:
	return {"type": "cols", "cells": cells, "system": system, "warn": warn}


## 真气段（buildRows 的前 5 行）
static func zhenqi_rows(s: XState, a: XActor) -> Array:
	var st := XZhenqi.state_of(s, a)
	var d := XZhenqi.data(a)
	var rows := [_head("真气"),
		_line("境界：\\C[6]%s·%s\\C[0]　真气 %s　加成 \\C[3]%s\\C[0]" % [st.world, st.name, XZhenqi.group(st.qi), XZhenqi.mult(st.rate)])]
	var nxt := ""
	if st.next == null:
		nxt = "已至道祖，之后每 10 万真气一重。"
	elif st.capped and not st.canBreak:
		nxt = "需通关第%d层后突破（已通关%d层）" % [int(st.gate.required), int(st.gate.passed)]
	elif st.capped:
		nxt = "\\C[17]已到瓶颈：打开菜单「真气」打赢%s，突破%s\\C[0]" % [XZhenqi.REALMS[st.realm + 1].trial, st.next]
	else:
		nxt = "下一境：%s（还差 %s 真气）" % [st.next, XZhenqi.group(st.need)]
	rows.append(_line(nxt))
	var df := XZhenqi.DAOFA.filter(func(k): return d.daofa.get(k, 0)).map(func(k): return XZhenqi.DAOFA_NAME[k])
	rows.append(_line("道法：" + ("、".join(df) if not df.is_empty() else "未领悟") + ("　\\C[17]待选奖励 %d 项\\C[0]" % int(st.pending) if st.pending else "")))
	rows.append(_line("来源：守层者（每层一次）、副本 Boss 与神兵试炼（可反复刷）、超出上限的再动（每场最多 10）。层数和难度越高越多。"))
	return rows


## 整页：真气、（五个乘区不移植）、难度对照、建议
static func page_rows(s: XState, a: XActor) -> Array:
	var rows := zhenqi_rows(s, a)
	var c := compare(a)
	var ctx := context(s)
	rows.append({"type": "blank"})
	rows.append(_head("难度对照　%s·第 %d 层　天道补偿 %s" % [ctx.route.name, ctx.floor, XZhenqi.mult(ctx.comp)]))
	rows.append(_cols(["项目", "难度（含补强）", "自身", "当前"], true))
	rows.append(_cols(["暴击率", pct(c.diff.cri, true), pct(c.base.cri), pct(c.now.cri)], false, c.now.cri < 1))
	rows.append(_cols(["爆伤", pct(c.diff.crit, true), pct(c.base.crit, true), "暴击 " + XZhenqi.mult(maxf(1, 1.5 + c.now.crit))], false, 1.5 + c.now.crit <= 1))
	rows.append(_cols(["命中", pct(c.diff.hit, true), pct(c.base.hit), pct(c.now.hit)], false, c.now.hit < 1))
	rows.append(_cols(["终伤", pct(c.diff.fin, true), pct(c.base.fin, true), pct(c.now.fin, true)]))
	rows.append(_cols(["物攻", XZhenqi.mult(c.diff.atk), XZhenqi.group(c.base.atk), XZhenqi.group(c.now.atk)], false, c.diff.atk < 0.5))
	rows.append(_cols(["魔攻", XZhenqi.mult(c.diff.mat), XZhenqi.group(c.base.mat), XZhenqi.group(c.now.mat)], false, c.diff.mat < 0.5))
	rows.append(_cols(["结算倍率", XZhenqi.mult(c.diff.settle), XZhenqi.mult(c.base.settle), XZhenqi.mult(c.now.settle)], false, c.diff.settle < 0.01))
	rows.append(_line("\\C[8]暴击率还要减去敌人的暴击闪避；结算倍率是开战后推送的状态连乘。\\C[0]"))
	rows.append({"type": "blank"})
	rows.append(_head("建议"))
	for t in tips(s, a, c):
		rows.append(_line(t))
	return rows


## 战力条旁的真气文字（refreshCombatPowerSummary 的右端 300 宽）：[文字, 是否瓶颈／待选（橙色）]
static func strip_text(s: XState, a: XActor) -> Array:
	var st := XZhenqi.state_of(s, a)
	return ["真气·" + st.name + " " + XZhenqi.mult(st.rate) + ("（待选）" if st.pending else ("（瓶颈）" if st.capped else "")), st.capped or st.pending > 0]


# ---- 第二阶段：区段里程碑与「下一步建议」 ----
## Scene_Map.update 的里程碑开关（G.MILESTONE_ENABLED）；无画面测试可关掉
static var MILESTONE_ENABLED := true
static var _atlas = null


## G.ATLAS：[{key, lo, hi, title, intro, power, special, bosses:[{f, where, n}]}]
static func atlas() -> Array:
	if _atlas == null:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/guide_atlas.json"))
		_atlas = d.get("atlas", []) if d is Dictionary else []
	return _atlas


## G.segmentOf：落在 lo～hi 的区段，都不在时取最后一段
static func segment_of(f: int) -> Dictionary:
	var a := atlas()
	for seg in a:
		if f >= int(seg.lo) and f <= int(seg.hi):
			return seg
	return a.back() if not a.is_empty() else {}


## G.seen：$gameSystem._codexGuideSeen
static func seen(s: XState, key: String, set_it := false) -> bool:
	if set_it:
		s.guide_seen[key] = 1
	return s.guide_seen.has(key)


static func _boss_summary(seg: Dictionary, n: int) -> String:
	var b: Array = seg.get("bosses", [])
	var shown := PackedStringArray()
	for x in b.slice(0, n):
		shown.append("%d层 %s%s" % [int(x.f), str(x.where), "（%d个）" % int(x.n) if int(x.n) > 1 else ""])
	return "、".join(shown) + (" 等 %d 处" % b.size() if b.size() > n else "")


## powerLine：洪荒难度（开关 2483／2463）下本段不朽存在的权能掉率。洪荒的诅咒倍率与权能掉落未移植，暂不显示
static func _power_line(_seg: Dictionary) -> String:
	return ""


## G.milestoneTexts
static func milestone_texts(seg: Dictionary) -> Array:
	var t := ["\\C[6]%s\\C[0]　%s" % [seg.title, seg.intro]]
	if not seg.get("bosses", []).is_empty():
		t.append("\\C[4]可反复刷的副本Boss\\C[0]：" + _boss_summary(seg, 4) + "。")
	var more: Array = seg.get("special", []).duplicate()
	var pw := _power_line(seg)
	if pw != "":
		more.append(pw)
	if not more.is_empty():
		t.append("".join(PackedStringArray(more)))
	return t


## 原版插入解释器的指令列：每段文字一页（101 无头像、窗口、下方＋401 <WordWrap>），末尾结束指令
static func page_list(texts: Array) -> Array:
	var out := []
	for t in texts:
		out.append({"code": 101, "indent": 0, "parameters": ["", 0, 0, 2]})
		out.append({"code": 401, "indent": 0, "parameters": ["<WordWrap>" + str(t)]})
	out.append({"code": 0, "indent": 0, "parameters": []})
	return out


## Scene_Map.update：修行进度层所在区段没看过时返回该段（调用方记看过并显示），否则空
static func pending_milestone(s: XState) -> Dictionary:
	if not MILESTONE_ENABLED or s == null:
		return {}
	var seg := segment_of(XZhenqi.progress_floor(s))
	if seg.is_empty() or seen(s, "seg:" + str(seg.key)):
		return {}
	return seg


## G.adviceTexts（方桌大厅「商店向导」→「下一步建议」）：进度与待选／可突破、本段副本 Boss、养成入口与祝福石；战力短板段不移植（O-050）
static func advice_texts(s: XState) -> Array:
	var f := XZhenqi.progress_floor(s)
	var seg := segment_of(f)
	var out := []
	var pend := PackedStringArray()
	var cap := PackedStringArray()
	for a in s.members():
		var st := XZhenqi.state_of(s, a)
		if st.pending:
			pend.append(a.display_name())
		elif st.canBreak:
			cap.append(a.display_name() + "→" + str(st.next))
	var p1 := "\\C[6]修行建议\\C[0]　路线：%s，已通过第%d层，" % [XZhenqi.route(s).name, f]
	p1 += "守层者已全部通过，真气主要靠副本Boss、神兵试炼和溢出再动。" if f >= 33 else "下一个守层者在第%d层（每层只能打一次，首通给大量真气）。" % (f + 1)
	if not pend.is_empty():
		p1 += "\\C[2]待选奖励\\C[0]：" + "、".join(pend.slice(0, 6)) + (" 等" if pend.size() > 6 else "") + "——打开菜单「真气」补选。"
	if not cap.is_empty():
		p1 += "\\C[2]可突破\\C[0]：" + "、".join(cap.slice(0, 4)) + (" 等" if cap.size() > 4 else "") + "——打开菜单「真气」打瓶颈之战。"
	out.append(p1)
	if not seg.is_empty():
		out.append("\\C[4]%s\\C[0]可反复刷：%s。胜利给抽奖券（另加 层数÷3 张）和真气（1～15层保留原奖励的1/3，16～25层保留1/2，26～33层保留2/3）；同一个副本Boss打满 1／10／50 次另给 10／30／100 张券，10 次后权能和专属书掉率×2、50 次后×3；每场另有 10%% 掉神秘珠（宝珠坊鉴定，一半出原作宝珠）。" % [seg.title, _boss_summary(seg, 5)])
		var sp := "".join(PackedStringArray(seg.get("special", [])))
		var pw := _power_line(seg)
		if sp != "" or pw != "":
			out.append(sp + pw)
	var entry := "\\C[4]养成入口\\C[0]：菜单「宝珠坊」鉴定、分解并查看套装；「种族祝福」逐人换族与进阶；菜单「真气」突破、领奖与挑战神兵试炼，大厅「闭关」也可操作。"
	var races = XDB.table("CodexRaces")
	var bands: Array = races.get("bands", []) if races is Dictionary else []
	var band := -1
	for i in bands.size():
		if f >= int(bands[i][0]) and f <= int(bands[i][1]):
			band = i
	if band >= 0:
		var first = s.race_supply.get("first", {})
		var claimed := first is Dictionary and bool(first.get(str(band + 2), false))
		entry += "本段副本Boss提供%s，%s每累计5场再1份。" % [str(XDB.rec("Items", int(races.stones[band])).get("name", "")), "" if claimed else "首次胜利1份，"]
	out.append(entry)
	return out
