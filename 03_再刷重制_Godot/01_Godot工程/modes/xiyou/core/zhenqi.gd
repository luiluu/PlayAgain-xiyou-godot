class_name XZhenqi
extends RefCounted
## 真气（installNativeZhenqiRuntime，CodexZhenqi）第一批：积累、境界、加成值、提示。参照 mv_oracle/zhenqi_probe.cjs → generated/oracle/zhenqi.json
## （tests/xiyou_zhenqi 逐项比）。
## - 每个角色一份 XActor.zhenqi = {qi, firsts, realm, pending, daofa, spec}（同原版 actor._codexZhenqi），随存档；旧档缺省为新角色的初值。
## - 来源（只在战斗胜利结算时记一次，规则层：BattleLogic.grant 调 on_victory）：
##   溢出再动——OTB 首回合排序时追加次数超过 4 的部分每次 1 点（note_overflow），每场每人最多 10；
##   守层者（GUARDIANS 敌群→楼层）——每条路线每层首通 10×层×路线系数，每次胜利再 3×层×系数；
##   非守层者敌群里有 Boss——bossReward(层, 系数)，层取守层者层、本图楼层或修行进度层。只有活着的出战成员得。
## - 加成 rate = √(1＋真气÷10)，境界 9（真仙）起每级再 ×1.1。原版把 rate×天道补偿乘进对敌伤害（growthMultiplier）；
##   重制版按数值平衡（用户 2026-10-12：成长修正不移植）不乘，伤害 growth 仍为 1，这里只算出来供界面显示（APPLY_TO_DAMAGE）。
## - 第二批（未做）：突破与瓶颈之战（心魔 901／天劫 823）、突破奖励与道法、神兵试炼、菜单「真气」闭关、天道使者旧档回退（重制版不读 MV 存档）。

const DIV := 10.0
const OVERFLOW_CAP := 10
const COEF := {"first": 10, "guardian": 3, "boss": 3}
const ROUTES := [
	{"key": "normal", "name": "普通", "coef": 1}, {"key": "hard", "name": "困难", "coef": 2}, {"key": "hell", "name": "地狱", "coef": 3},
	{"key": "calamity", "name": "天灾", "coef": 5}, {"key": "doom", "name": "灭世", "coef": 8}, {"key": "primordial", "name": "洪荒", "coef": 13}]
const GUARDIANS := {4: 1, 5: 2, 8: 3, 22: 4, 28: 5, 245: 5, 39: 6, 52: 7, 53: 8, 67: 9, 69: 10, 109: 11, 110: 12, 111: 13, 118: 14, 138: 15, 172: 16,
	173: 17, 174: 18, 333: 19, 456: 20, 457: 21, 458: 22, 459: 23, 460: 24, 461: 25, 462: 26, 463: 27, 464: 28, 465: 29, 466: 30, 467: 31, 468: 32, 469: 33}
const REALMS := [
	{"name": "炼气", "need": 0, "world": "人界"}, {"name": "筑基", "need": 600, "world": "人界", "trial": "心魔"},
	{"name": "结丹", "need": 2500, "world": "人界", "trial": "心魔"}, {"name": "元婴", "need": 6000, "world": "人界", "trial": "心魔"},
	{"name": "化神", "need": 18000, "world": "人界", "trial": "心魔"}, {"name": "炼虚", "need": 36000, "world": "灵界", "trial": "心魔"},
	{"name": "合体", "need": 66000, "world": "灵界", "trial": "心魔"}, {"name": "大乘", "need": 88000, "world": "灵界", "trial": "心魔"},
	{"name": "渡劫", "need": 111000, "world": "灵界", "trial": "天劫"}, {"name": "真仙", "need": 150000, "world": "仙界", "trial": "天劫"},
	{"name": "金仙", "need": 222000, "world": "仙界", "trial": "天劫"}, {"name": "太乙", "need": 300000, "world": "仙界", "trial": "天劫"},
	{"name": "大罗", "need": 388000, "world": "仙界", "trial": "天劫"}, {"name": "道祖", "need": 500000, "world": "仙界", "trial": "天劫"}]
const DAOFA := ["lianji", "fenshen", "lingtai", "benming", "linggen", "huichun", "jinshen", "pojia", "hufa"]
const DAOFA_NAME := {"lianji": "连击", "fenshen": "分神", "lingtai": "灵台", "benming": "本命兵", "linggen": "灵根", "huichun": "回春", "jinshen": "金身", "pojia": "破甲", "hufa": "护法"}
const COMP_ANCHORS := [[12, 1.0], [21, 15.0], [33, 111.0]]
const SUB3 := ["初期", "中期", "后期"]
const CN := "零一二三四五六七八九十"
## 原版 rate×天道补偿 乘进对敌伤害；按用户 2026-10-12 数值平衡决定不乘（见文件头）
const APPLY_TO_DAMAGE := false

## 本场战斗（BattleManager.setup 时的 Z._battle 与 Z._ovf）；不存档，换档清空
static var battle := {}


# ---- 数据 ----
static func default_data() -> Dictionary:
	return {"qi": 0, "firsts": {}, "realm": 0, "pending": [], "daofa": {}, "spec": {}}


## Z.data：没有就建初值（原版 migrate 只回收 MV 旧档的 _actionDMG 与补发楼层，重制版新档为空操作）
static func data(a: XActor) -> Dictionary:
	if a.zhenqi.is_empty():
		a.zhenqi = default_data()
	return a.zhenqi


## 读档：缺项给默认值，数字统一为整数
static func from_save(d) -> Dictionary:
	var out := default_data()
	if d is Dictionary:
		out.qi = int(d.get("qi", 0))
		out.realm = int(d.get("realm", 0))
		for k in d.get("firsts", {}):
			out.firsts[str(k)] = 1
		out.pending = Array(d.get("pending", [])).map(func(x): return int(x))
		for k in d.get("daofa", {}):
			out.daofa[str(k)] = int(d.daofa[k])
		out.spec = d.get("spec", {}) if d.get("spec", {}) is Dictionary else {}
	return out


# ---- 路线、楼层 ----
static func route(s: XState) -> Dictionary:
	if s.switch(2483) or s.switch(2463):
		return ROUTES[5]
	if s.switch(2487) or s.switch(2462):
		return ROUTES[4]
	if s.switch(2489) or s.switch(2461):
		return ROUTES[3]
	if s.switch(2494):
		return ROUTES[2]
	if s.switch(2500):
		return ROUTES[1]
	return ROUTES[0]


static func progress_floor(s: XState) -> int:
	return clampi(int(s.variable(20)) - 1, 0, 33)


## parseFloor：「N层」阿拉伯数字或「一～三十几层」中文数字
static func parse_floor(text: String) -> int:
	var m := RegEx.create_from_string("(\\d+)\\s*层").search(text)
	if m:
		return int(m.get_string(1))
	m = RegEx.create_from_string("([一二三四五六七八九十]+)层").search(text)
	if m == null:
		return 0
	var t := m.get_string(1)
	if not t.contains("十"):
		return CN.find(t)
	var p := t.split("十")
	return (CN.find(p[0]) if p[0] != "" else 1) * 10 + (CN.find(p[1]) if p.size() > 1 and p[1] != "" else 0)


## Z.mapFloor：MapInfos 的地图名，其次地图显示名
static func map_floor(map_id: int) -> int:
	var info := XDB.rec("MapInfos", map_id)
	var f := parse_floor(str(info.get("name", "")))
	if f == 0:
		f = parse_floor(str(XDB.map(map_id).get("displayName", "")))
	return f


static func allowed_realm(s: XState) -> int:
	var f := progress_floor(s)
	return REALMS.size() - 1 if f >= 33 else mini(6, f / 5)


static func required_floor(realm: int) -> int:
	return 0 if realm <= 0 else (realm * 5 if realm <= 6 else 33)


static func major_by_qi(qi: float) -> int:
	for i in range(REALMS.size() - 1, 0, -1):
		if qi >= REALMS[i].need:
			return i
	return 0


# ---- 加成与境界 ----
static func rate(a: XActor) -> float:
	var d := data(a)
	var x := sqrt(1.0 + float(d.qi) / DIV)
	for i in range(9, mini(int(d.realm), REALMS.size() - 1) + 1):
		x *= 1.1
	return x


static func gate(s: XState, a: XActor) -> Dictionary:
	var d := data(a)
	var i := int(d.realm) + 1
	var req := required_floor(i)
	var ok := i < REALMS.size()
	return {"required": req, "passed": progress_floor(s), "unlocked": ok and progress_floor(s) >= req,
		"ready": ok and int(d.qi) >= int(REALMS[i].need)}


static func cn_num(n: int) -> String:
	if n <= 10:
		return "十" if n == 10 else CN[n]
	if n < 20:
		return "十" + CN[n - 10]
	return CN[n / 10] + "十" + (CN[n % 10] if n % 10 else "")


## Z.state：境界名（炼气 1～13 层、其余初期／中期／后期、到下一境门槛未突破为「大圆满」、道祖每 10 万一重）、加成、门槛
static func state_of(s: XState, a: XActor) -> Dictionary:
	var d := data(a)
	var i := int(d.realm)
	var qi := int(d.qi)
	var capped := major_by_qi(qi) > i
	var name := ""
	if i == REALMS.size() - 1:
		name = "道祖" + cn_num(mini(floori((qi - int(REALMS[i].need)) / 100000.0) + 1, 99)) + "重"
	elif capped:
		name = REALMS[i].name + "大圆满"
	else:
		var lo := float(REALMS[i].need)
		var hi := float(REALMS[i + 1].need)
		var n := 13 if i == 0 else 3
		var k := mini(n - 1, floori((qi - lo) / (hi - lo) * n))
		name = REALMS[i].name + (cn_num(k + 1) + "层" if i == 0 else SUB3[k])
	var next = REALMS[i + 1] if i < REALMS.size() - 1 else null
	var g := gate(s, a)
	return {"name": name, "realm": i, "world": REALMS[i].world, "qi": qi, "rate": rate(a), "capped": capped,
		"next": next.name if next else null, "need": maxi(0, int(next.need) - qi) if next else 0, "pending": d.pending.size(),
		"gate": g, "canBreak": capped and g.unlocked}


static func describe(s: XState, a: XActor) -> String:
	var st := state_of(s, a)
	return "%s %s ×%.1f" % [st.world, st.name, st.rate]


# ---- 天道补偿与 Boss 奖励 ----
static func comp_for(route_key: String, floor: int) -> float:
	var coef := 1.0
	for r in ROUTES:
		if r.key == route_key:
			coef = float(r.coef)
	var pts := COMP_ANCHORS.map(func(p): return [p[0], pow(p[1], coef / 13.0)])
	if floor <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if floor <= pts[i][0]:
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			var t := float(floor - a[0]) / float(b[0] - a[0])
			return exp(log(a[1]) + (log(b[1]) - log(a[1])) * t)
	return pts[pts.size() - 1][1]


## Z.bossReward：1～15 层保留 1/3，16～25 层 1/2，26 层起 2/3；JS Math.round
static func boss_reward(f: int, c: int) -> int:
	var r := 1.0 / 3.0 if f <= 15 else (0.5 if f <= 25 else 2.0 / 3.0)
	return int(floor(float(COEF.boss) * f * c * r + 0.5))


# ---- Boss 判定（CodexBossDifficulty.isBoss 的 bossId，再加名字标记）----
static var _mog_boss := {}


static func is_boss_enemy(e: XEnemy) -> bool:
	if _mog_boss.is_empty():
		var p := XDB.plugin("MOG_BossHP")
		for k in p:
			if RegEx.create_from_string("^boss-\\d+$").search(str(k)) and str(p[k]).is_valid_int():
				_mog_boss[int(p[k])] = true
		_mog_boss[-1] = true
	var d := e.data()
	if _mog_boss.has(int(d.get("id", 0))):
		return true
	if RegEx.create_from_string("(?i)<boss(?:\\s*:[^>]*)?\\s*>|BOSS级怪物").search(str(d.get("note", ""))):
		return true
	return RegEx.create_from_string("【(首领|守层者|守护者|被封印者|未知存在|超级Boos|前所未见|终焉恐惧|神兵)】").search(str(d.get("name", ""))) != null


# ---- 战斗钩子（BattleLogic 调用）----
## BattleManager.setup：记本场路线、守层者层、楼层与天道补偿，清溢出计数
static func battle_setup(s: XState, troop_id: int) -> void:
	var r := route(s)
	var gf := int(GUARDIANS.get(troop_id, 0))
	var f := gf
	if f == 0:
		f = map_floor(s.map_id)
	if f == 0:
		f = progress_floor(s)
	battle = {"troopId": troop_id, "route": r, "guardianFloor": gf, "floor": f, "comp": comp_for(r.key, f), "ovf": {}}
	for a in s.battle_members():
		data(a)


## otbActionTimesModification（只在首回合的当前顺序）：追加次数 extra 超过 4 的部分记为溢出
static func note_overflow(a: XActor, extra: int) -> void:
	if battle.is_empty() or extra <= 4:
		return
	battle.ovf[a.actor_id] = int(battle.ovf.get(a.actor_id, 0)) + (extra - 4)


## Z.onVictory：活着的出战成员按来源记真气（每场只记一次：记完清空本场），弹提示
static func on_victory(s: XState, actors: Array, enemies: Array) -> Array:
	var b := battle
	battle = {}
	if b.is_empty():
		return []
	var boss := int(b.guardianFloor) == 0 and enemies.any(func(e): return is_boss_enemy(e))
	var c := int(b.route.coef)
	var f := int(b.guardianFloor) if int(b.guardianFloor) else int(b.floor)
	var lines := []
	var out := []
	for a in actors:
		if not a.is_alive():
			continue
		var d := data(a)
		var g := mini(OVERFLOW_CAP, int(b.ovf.get(a.actor_id, 0)))
		var first := false
		if int(b.guardianFloor):
			var key := "%s:%d" % [b.route.key, f]
			if not d.firsts.has(key):
				d.firsts[key] = 1
				first = true
				g += COEF.first * f * c
			g += COEF.guardian * f * c
		elif boss and f > 0:
			g += boss_reward(f, c)
		if g > 0:
			gain(s, a, g)
			lines.append("%s +%d%s" % [a.display_name(), g, "（首通）" if first else ""])
			out.append([a.actor_id, g, first])
	if not lines.is_empty():
		_toast("真气 " + "，".join(lines))
	return out


## Z.gain：加真气；刚到大圆满提示突破条件，境界名变化提示「真气精进」
static func gain(s: XState, a: XActor, amount: int) -> void:
	if amount <= 0:
		return
	var d := data(a)
	var before: String = state_of(s, a).name
	var was_capped := major_by_qi(int(d.qi)) > int(d.realm)
	d.qi = int(d.qi) + amount
	var st := state_of(s, a)
	if st.capped and not was_capped:
		var tail: String = "打开菜单「真气」闭关突破" + str(st.next) if st.canBreak else "通关第%d层后可突破" % int(st.gate.required)
		_toast("%s 已至%s大圆满，%s" % [a.display_name(), REALMS[int(d.realm)].name, tail])
	elif st.name != before:
		_toast("%s 真气精进：%s" % [a.display_name(), st.name])


static var toasts: Array = []      # 本进程发过的真气提示（测试核对）


static func _toast(msg: String) -> void:
	toasts.append(msg)
	XToast.show_text(msg, false, "zhenqi")


# ---- 显示格式（CodexGuide.format）----
static func group(n: float) -> String:
	var v := absf(n)
	var t := str(int(floor(v + 0.5)))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("−" if n < 0 else "") + t + out


## CodexGuide.format.mult
static func mult(v: float) -> String:
	if not (v > 0):
		return "×0"
	if v >= 1000:
		return "×" + group(v)
	if v >= 1:
		return "×" + _fixed(v, 1)
	if v >= 0.1:
		return "×" + _fixed(v, 2)
	var e := floori(log(v) / log(10.0))
	if v >= 1e-4:
		# Number(v.toPrecision(2)).toFixed(max(2, 1−e))
		var p := pow(10.0, e - 1)
		return "×" + _fixed(roundf(v / p) * p, maxi(2, 1 - e))
	return "×" + _fixed(v / pow(10, e), 1) + "e" + str(e)


## JS toFixed（四舍五入到 n 位小数，补零）
static func _fixed(v: float, n: int) -> String:
	return String.num(snappedf(v, pow(10, -n)), n).pad_decimals(n)
