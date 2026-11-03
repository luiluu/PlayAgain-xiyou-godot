class_name XHonghuang
extends RefCounted
## 洪荒诅咒（installNativeHonghuangRuntime 的 CodexHonghuang，v0.5 S3）第一期：公共事件 1442「洪荒技能抽奖·诅咒」的自选流程。
## 原版没有随机数：15 种全列，连问 5 次（每次去掉已选的，不可取消），选完写变量 1468～1472，再由 1442 后半按变量全员 learnSkill(7200+N)。
## 选项文字照 CodexHonghuang.curseLabel：【档位·×系数】技能名（技能备注 <pos=APs text=…效果:X size=…> 的 X，去掉零宽空格）。
## 选择中的候选与已选（原版 $gameTemp._hhCurseOffer／_hhCursePicked，不进存档）放静态变量。
## 参照 mv_oracle/honghuang_curse_probe.cjs → tests/fixtures/honghuang_curse_oracle.json（tests/xiyou_honghuang_curse）。
## 第二期：路线判定（只看开关，不看难度）、诅咒加成券、不朽存在权能掉落（CE1439）、洪荒压制被动（CE1445）。
## 参照 mv_oracle/honghuang_reward_probe.cjs → tests/fixtures/honghuang_reward_oracle.json（tests/xiyou_honghuang_reward）。

const FACTOR := {"轻": 1.0, "中": 1.2, "重": 1.5}
const TIER := {7211: "轻", 7206: "轻", 7203: "轻", 7208: "轻",
	7210: "中", 7205: "中", 7207: "中", 7204: "中", 7209: "中", 7215: "中",
	7201: "重", 7202: "重", 7214: "重", 7212: "重", 7213: "重"}
const PICKS := 5
const FIRST_VARIABLE := 1468
const POWER_RATE := 0.03
const SEGMENTS := [[0, 15], [16, 18], [19, 21], [22, 25], [26, 99]]
const BASE_TICKET := 5
const TICKET := 1639

## $gameTemp._hhCurseOffer／_hhCursePicked（null＝没有，同原版 delete 之后）
static var offer = null
static var picked = null
## 原版 powerBattle：最近一场战斗的身份 {eligible, troop, floor, won, rolled}（不进存档；换档在 XState._become_current 清）。
static var power_battle := {}
static var _powers := {}
static var _suppress := -1


## H.isHonghuang：开关 2483（洪荒）或 2463（洪荒补强）。牢妲能单独把怪物难度切到 8，所以不看难度。
static func is_honghuang(s: XState) -> bool:
	return s != null and (s.switch(2483) or s.switch(2463))


## CodexHonghuang.curseLabel(i)
static func curse_label(i: int) -> String:
	var id := 7200 + i
	var s := XDB.rec("Skills", id)
	var t: String = TIER.get(id, "轻")
	var m := RegEx.create_from_string("<pos=APs text=(?:\\\\c\\[\\d+\\])?效果:(.*?) size=").search(str(s.get("note", "")))
	var f: float = FACTOR[t]
	return "【" + t + ("·×" + _num(f) if f > 1.0 else "") + "】" + str(s.get("name", "")) + ("（" + m.get_string(1).replace("\u200b", "") + "）" if m else "")


## CodexHonghuang.curseIds：角色已学的诅咒技能（升序）
static func curse_ids(a: XActor) -> Array:
	var out := []
	for id in TIER:
		if a != null and a.skill_ids.has(int(id)):
			out.append(int(id))
	out.sort()
	return out


## CodexHonghuang.curseBonus：诅咒档位系数连乘（下期发券、权能掉率用）
static func curse_bonus(a: XActor) -> float:
	var r := 1.0
	for id in curse_ids(a):
		r *= float(FACTOR[TIER[id]])
	return r


## 选项还剩哪些（原版 left）
static func left() -> Array:
	return (offer as Array).filter(func(i): return not (picked as Array).has(i))


## JS 数字转字符串（1.2、1.5）
static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


## JS toFixed(1)：String.num 对正好落在中点的数取偶（2.25→2.2），原版取大（2.3）。只有 x.25／x.75 才是二进制里的真中点；
## 4.05 这类实际略小于中点，String.num 与 JS 都舍（snappedf 会进成 4.1，不能用）。
static func _fixed1(v: float) -> String:
	return String.num(v + 0.01 if fmod(v * 4.0, 2.0) == 1.0 else v, 1).pad_decimals(1)


## curseHolder：队伍里第一个学了诅咒的人，没有取队首
static func curse_holder(s: XState) -> XActor:
	var m := s.members()
	for a in m:
		if not curse_ids(a).is_empty():
			return a
	return m[0] if not m.is_empty() else null


## H.curseBonus()（不传角色）
static func party_bonus(s: XState) -> float:
	return curse_bonus(curse_holder(s))


## H.powerChance
static func power_chance(s: XState) -> float:
	return minf(1.0, POWER_RATE * party_bonus(s))


## H.grantTicketBonus（CE1439 开头）：加发 round(5×(倍率−1)) 张券。返回提示文字列表。
static func grant_ticket_bonus(s: XState) -> Array:
	if not is_honghuang(s):
		return []
	var bonus := party_bonus(s)
	var n := maxi(0, roundi(BASE_TICKET * (bonus - 1.0)))
	if n <= 0:
		return []
	s.gain_item(TICKET, n)
	return ["洪荒诅咒加成（×%s）：肝帝积分抽奖券额外+%d" % [_fixed1(bonus), n]]


## 道具备注 <CodexPower: N> 的书，按区段分组（ID 升序）
static func powers(seg: int) -> Array:
	if _powers.is_empty():
		var re := RegEx.create_from_string("<CodexPower:\\s*(\\d+)>")
		for rec in XDB.table("Items"):
			if rec == null:
				continue
			var m := re.search(str(rec.get("note", "")))
			if m:
				var k := int(m.get_string(1))
				if not _powers.has(k):
					_powers[k] = []
				_powers[k].append(int(rec.id))
	return _powers.get(seg, [])


## H.segment
static func segment(floor_no: int) -> int:
	for i in SEGMENTS.size():
		if floor_no >= int(SEGMENTS[i][0]) and floor_no <= int(SEGMENTS[i][1]):
			return i + 1
	return SEGMENTS.size()


## BattleManager.setup／startBattle 包装：记本场身份
static func battle_started(s: XState, troop: int) -> void:
	power_battle = {"eligible": is_honghuang(s) and XYunshangOrders.immortal_clear(s, troop), "troop": troop,
		"floor": XDungeon.boss_floor(s.map_id), "won": false, "rolled": false}


## BattleManager.endBattle 包装
static func battle_ended(result: int) -> void:
	if not power_battle.is_empty():
		power_battle.won = result == 0


## H.rollPower（CE1439 末尾）：本场胜利的不朽存在，每战一次，这一段的书每本掷一次。返回 {got, toasts}。
static func roll_power(s: XState, rand: Callable) -> Dictionary:
	var b := power_battle
	if b.is_empty() or not bool(b.eligible) or not bool(b.won) or bool(b.rolled):
		return {"got": [], "toasts": []}
	b.rolled = true
	var p := minf(1.0, power_chance(s) * XDungeon.power_factor(s, int(b.troop)))
	var got := []
	var toasts := []
	for id in powers(segment(int(b.floor))):
		if float(rand.call()) < p:
			s.gain_item(int(id), 1)
			got.append(int(id))
			toasts.append("洪荒权能掉落：%s！" % str(XDB.rec("Items", int(id)).get("name", "")))
	return {"got": got, "toasts": toasts}


## 带 <CodexHonghuangSuppress> 的第一个技能（洪荒压制被动，CE1445 与 syncNativeTier 共用），没有返回 0
static func suppress_skill() -> int:
	if _suppress < 0:
		_suppress = 0
		for rec in XDB.table("Skills"):
			if rec != null and str(rec.get("note", "")).contains("<CodexHonghuangSuppress>"):
				_suppress = int(rec.id)
				break
	return _suppress
