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
##   加成只显示、按数值平衡不移植（用户 2026-10-12 已定：成长修正不移植），伤害 growth 仍为 1，这里只算出来供界面显示（APPLY_TO_DAMAGE）；
##   统一调整时再定（数值平衡.md「统一调整时要看的已知问题」）。
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
	{"name": "炼气", "need": 0, "world": "人界"},
	{"name": "筑基", "need": 600, "world": "人界", "trial": "心魔", "scale": 1, "choice": {"split": 30}},
	{"name": "结丹", "need": 2500, "world": "人界", "trial": "心魔", "scale": 1, "fixed": "jindan", "choice": {"split": 50}},
	{"name": "元婴", "need": 6000, "world": "人界", "trial": "心魔", "scale": 1, "fixed": "yuanying", "choice": {"split": 70}},
	{"name": "化神", "need": 18000, "world": "人界", "trial": "心魔", "scale": 1, "choice": {"split": 99}},
	{"name": "炼虚", "need": 36000, "world": "灵界", "trial": "心魔", "scale": 2, "fixed": "lianxu", "choice": {"all": 333}},
	{"name": "合体", "need": 66000, "world": "灵界", "trial": "心魔", "scale": 2, "choice": {"all": 333}},
	{"name": "大乘", "need": 88000, "world": "灵界", "trial": "心魔", "scale": 2, "fixed": "dacheng", "choice": {"all": 500}},
	{"name": "渡劫", "need": 111000, "world": "灵界", "trial": "天劫", "scale": 3, "fixed": "dujie", "choice": {"all": 666}},
	{"name": "真仙", "need": 150000, "world": "仙界", "trial": "天劫", "scale": 5, "fixed": "xianyuan", "choice": {"all": 1000}},
	{"name": "金仙", "need": 222000, "world": "仙界", "trial": "天劫", "scale": 8, "fixed": "xianyuan", "choice": {"all": 1000}},
	{"name": "太乙", "need": 300000, "world": "仙界", "trial": "天劫", "scale": 13, "fixed": "xianyuan", "choice": {"all": 1000}},
	{"name": "大罗", "need": 388000, "world": "仙界", "trial": "天劫", "scale": 21, "fixed": "xianyuan", "choice": {"all": 1000}},
	{"name": "道祖", "need": 500000, "world": "仙界", "trial": "天劫", "scale": 34, "fixed": "xianyuan", "choice": {"all": 1000}}]
const TRIAL_TROOP := {"心魔": 901, "天劫": 823}
const HEART_TROOP := {1: 770}
const LINGGEN_ELEMENTS := [1, 2, 3, 4, 5, 6, 7, 8, 9]
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
		if d.get("daofaStages") is Dictionary:
			out.daofaStages = {}
			for k in d.daofaStages:
				out.daofaStages[str(k)] = int(d.daofaStages[k])
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
	# 显示名只在已转换的地图里有（切片外与地图号 0 不读，免得 XDB 报读取失败）
	if f == 0 and map_id > 0 and FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % map_id):
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
	var trial := pending_trial
	pending_trial = {}
	if not trial.is_empty() and int(trial.troopId) != troop_id:
		trial = {}
	var r := route(s)
	var gf := int(GUARDIANS.get(troop_id, 0))
	var f := gf
	if f == 0 and not trial.is_empty():
		f = int(trial.ref.floor)
	if f == 0:
		f = map_floor(s.map_id)
	if f == 0:
		f = progress_floor(s)
	battle = {"troopId": troop_id, "trial": trial, "route": r, "guardianFloor": 0 if not trial.is_empty() else gf, "floor": f, "comp": comp_for(r.key, f), "ovf": {}}
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
	if not b.trial.is_empty():
		b.trial.won = actors.any(func(a): return a.is_alive() and a.actor_id == int(b.trial.actorId))
		trial_done = b.trial
		return []
	unlock_specs(s, enemies)
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


# ==== 第二批：突破、瓶颈之战、突破奖励与道法（installNativeZhenqiRuntime 89～90、199～278、291～334 行）====
# 闭关流程原版用 interp.setupChild 插入「文字＋选项」指令列，选项回调 CodexZhenqi._cb。这里拆成两层：
# menu(s, node) 按节点给出 {lines, options:[{label, next}], next?, battle?}，记账（突破、学奖励技能、记道法）只在节点里做；
# 画面（XZhenqiRetreat）只负责显示文字、选项与开战，按选中项的 next 走下一个节点。参照 zhenqi_probe「break.*」逐项比。

## 瓶颈之战：startTrial 记下、BattleManager.setup 吃掉（敌群不符就作废）；战斗结束（胜负）写进 trial_done，_trialEnd 结算
static var pending_trial := {}
static var trial_done := {}
## 测试注入 Math.randomInt 的序列（空时用 randi）
static var rand_seq: Array = []


static func _random_int(n: int) -> int:
	if not rand_seq.is_empty():
		return int(rand_seq.pop_front()) % n
	return randi() % n


# ---- 奖励技能（备注 <CodexZhenqi: 键>）----
static var _skills := {}


static func skill_key(key: String) -> int:
	if _skills.is_empty():
		var re := RegEx.create_from_string("<CodexZhenqi:\\s*([^>]+)>")
		for sk in XDB.table("Skills"):
			if sk is Dictionary:
				var m := re.search(str(sk.get("note", "")))
				if m:
					_skills[m.get_string(1).strip_edges()] = int(sk.id)
		_skills[""] = 0
	return int(_skills.get(key, 0))


static func learn_key(a: XActor, key: String) -> int:
	var id := skill_key(key)
	if id and not a.skill_ids.has(id):
		a.learn_skill(id)
	return id


static func grant_fixed(a: XActor, i: int) -> void:
	var f := str(REALMS[i].get("fixed", ""))
	if f != "":
		learn_key(a, "fixed:xianyuan:%d" % i if f == "xianyuan" else "fixed:" + f)


## Z.refreshRewards：奖励被动随境界（daofaScale）与技能变化重算
static func refresh_rewards(a: XActor) -> void:
	a.refresh_passive()
	a.refresh_resources()


## Z.breakthrough：真气够、楼层门槛已过才突破；升一境、学固定奖励、记一笔待选奖励
static func breakthrough(s: XState, a: XActor) -> bool:
	var d := data(a)
	var i := int(d.realm) + 1
	if i >= REALMS.size() or int(d.qi) < int(REALMS[i].need) or not gate(s, a).unlocked:
		return false
	d.realm = i
	grant_fixed(a, i)
	d.pending.append(i)
	_toast("%s 突破至%s！" % [a.display_name(), REALMS[i].name])
	refresh_rewards(a)
	return true


static func has_daofa(a, key: String) -> bool:
	return a is XActor and not a.zhenqi.is_empty() and int(a.zhenqi.daofa.get(key, 0)) != 0


## Z.daofaScale：道法与奖励被动按当前境界的缩放（炼气 1/4、筑基 1/3、结丹 1/2、元婴 2/3、化神起 1）
static func daofa_scale(a: XActor) -> float:
	var i := int(a.zhenqi.get("realm", 0)) if a and not a.zhenqi.is_empty() else 0
	return 1.0 if i >= 5 else (2.0 / 3.0 if i >= 4 else (0.5 if i == 3 else (1.0 / 3.0 if i == 2 else 0.25)))


## Z.patchRewards：数据库载入时把筑基～化神属性奖励改成 30/50/70/99%、金丹 20%、元婴 50%（备注里的被动值与说明文字）
static func patch_rewards(table: Array) -> void:
	var values := [30, 50, 70, 99]
	var tag_re := RegEx.create_from_string("<CodexZhenqi:\\s*([^>]+)>")
	var attr_re := RegEx.create_from_string("^attr:(atk|def|sup):[1-4]$")
	var pas_re := RegEx.create_from_string("(?i)(<passive(?:PBST\\d|XPBST\\d|CrHarmRi):\\s*)[\\d.]+(%?>)")
	var txt_re := RegEx.create_from_string("\\+\\d+(?:\\.\\d+)?%")
	for sk in table:
		if not sk is Dictionary:
			continue
		var m := tag_re.search(str(sk.get("note", "")))
		if m == null:
			continue
		var tag := m.get_string(1)
		var value := 0
		if tag == "fixed:jindan":
			value = 20
		elif tag == "fixed:yuanying":
			value = 50
		elif attr_re.search(tag):
			value = values[int(tag.right(1)) - 1]
		else:
			continue
		var note := pas_re.sub(str(sk.note), "${1}%d${2}" % value, true)
		note = txt_re.sub(note, "+%d%%" % value, true)
		if note != sk.note:
			sk.note = note
			sk.meta = extract_meta(note)


## DataManager.extractMetadata
static func extract_meta(note: String) -> Dictionary:
	var out := {}
	for m in RegEx.create_from_string("<([^<>:]+)(:?)([^>]*)>").search_all(note):
		out[m.get_string(1)] = m.get_string(3) if m.get_string(2) == ":" else true
	return out


## Z.skillView：道法技能的被动值与说明按 daofaScale 缩放（武器 WPNM、元素 ELUP、治疗 HEUP、TP 上限 EXTTP；本命兵、灵根、回春、
## 金身、灵台、护法、破甲的说明文字）。缓存键＝技能 ID＋缩放（技能数据只在载入时改）。
static var _views := {}


static func skill_view(sk: Dictionary, a: XActor) -> Dictionary:
	var m := RegEx.create_from_string("<CodexZhenqi:\\s*(daofa:[^>]+)>").search(str(sk.get("note", "")))
	if m == null:
		return sk
	var tag := m.get_string(1)
	var factor := daofa_scale(a)
	var key := "%d|%s" % [int(sk.id), str(factor)]
	if _views.has(key):
		return _views[key]
	var v := sk.duplicate()
	var note := str(sk.get("note", ""))
	var out := ""
	var at := 0
	for pm in RegEx.create_from_string("(?i)(<passive(?:WPNM\\d+|ELUP\\d+|HEUP|EXTTP):\\s*)([\\d.]+)(%?>)").search_all(note):
		out += note.substr(at, pm.get_start() - at) + pm.get_string(1) + str(_js_round(float(pm.get_string(2)) * factor)) + pm.get_string(3)
		at = pm.get_end()
	note = out + note.substr(at)
	if tag.begins_with("daofa:benming:"):
		note = note.replace("物攻、魔攻+333%", "物攻、魔攻+%d%%" % _js_round(333 * factor))
	elif tag.begins_with("daofa:linggen:"):
		note = note.replace("伤害+500%", "伤害+%d%%" % _js_round(500 * factor))
	elif tag == "daofa:huichun":
		note = note.replace("治疗量+100%", "治疗量+%d%%" % _js_round(100 * factor))
	elif tag == "daofa:jinshen":
		note = note.replace("护盾+100%", "护盾+%s%%" % _pct(100 * factor))
	elif tag == "daofa:lingtai":
		note = note.replace("TP上限+100", "TP上限+%d" % _js_round(100 * factor))
	elif tag == "daofa:hufa":
		note = note.replace("伤害-30%", "伤害-%s%%" % _pct(30 * factor))
	elif tag == "daofa:pojia":
		note = note.replace("双防×0.5", "双防×" + _pct(1 - 0.5 * factor))
	v.note = note
	v.meta = extract_meta(note)
	_views[key] = v
	return v


static func _js_round(x: float) -> int:
	return int(floor(x + 0.5))


## String(Math.round(v*100)/100)
static func _pct(v: float) -> String:
	var r := floor(v * 100 + 0.5) / 100.0
	return str(int(r)) if r == floor(r) else str(r)


# ---- 瓶颈之战 ----
## 守层者敌群里第一个对应该层的（第 5 层有 28 与 245，取 28）
static func guardian_troop_of_floor(f: int) -> int:
	var best := 0
	var keys := GUARDIANS.keys()
	keys.sort()
	for t in keys:
		if int(GUARDIANS[t]) == f and (best == 0 or int(t) != 245):
			best = int(t)
	return best


## Z.trialRef：对手强度＝修行进度层（至少 1）的守层者首个敌人，× 该境界倍数
static func trial_ref(s: XState, i: int) -> Dictionary:
	var f := maxi(1, progress_floor(s))
	var t := guardian_troop_of_floor(f)
	var mem: Array = XDB.rec("Troops", t).get("members", []) if t else []
	return {"floor": f, "troopId": t, "enemyId": int(mem[0].enemyId) if not mem.is_empty() else 0, "scale": int(REALMS[i].scale)}


## Game_Troop.setup 之后：幻化的敌人能力值取参照敌人的 paramBase，生命／攻击／魔攻 ×倍数，回满；不掉落（XEnemy.zq_ref／zq_trial_loot）
static func troop_setup(enemies: Array, difficulty: int, elite_roll := -1.0) -> void:
	var t: Dictionary = battle.get("trial", {})
	if t.is_empty() or int(t.ref.enemyId) == 0:
		return
	var ref := XEnemy.new().setup(int(t.ref.enemyId), difficulty, elite_roll)
	var p := []
	for i in range(8):
		p.append(ref.param_base_raw(i))
	for e in enemies:
		e.zq_ref = {"p": p, "k": float(t.ref.scale)}
		e.zq_trial_loot = true
		e.recover_all()


## 战斗结束（XBattleLogic.end_battle）：胜利已由 on_victory 结算并清空；输了、逃了时瓶颈之战记为未通过
static func on_battle_end() -> void:
	if not battle.is_empty() and not battle.get("trial", {}).is_empty():
		battle.trial.won = false
		trial_done = battle.trial
	battle = {}


## 灵根可指定的元素：击败带 <Element Absorb: …> 的 Boss（1～9 号元素，第一次提示）。$gameSystem._codexZhenqiSpec.e
## 本命兵（.w）只由神兵试炼解锁（第三批）。
static func unlock_specs(s: XState, enemies: Array) -> void:
	var sp := s.zhenqi_spec
	var re := RegEx.create_from_string("(?i)<Element Absorb:\\s*([\\d,\\s]+)>")
	for e in enemies:
		if not is_boss_enemy(e):
			continue
		for m in re.search_all(str(e.data().get("note", ""))):
			for x in m.get_string(1).split(","):
				var n := int(x.strip_edges()) if x.strip_edges().is_valid_int() else 0
				if LINGGEN_ELEMENTS.has(n) and not sp.e.has(str(n)):
					sp.e[str(n)] = 1
					_toast("降服 %s：灵根可指定「%s」" % [str(e.data().get("name", "")), str(XDB.system().elements[n])])


# ---- 闭关菜单（节点）----
## 节点：{"page": retreat|actor|trial|trial_end|pick|daofa|daofa_done, ...}；返回 {lines, options:[{label, next}], next, battle}
static func menu(s: XState, node: Dictionary) -> Dictionary:
	match str(node.page):
		"retreat": return _retreat(s, int(node.get("p", 0)))
		"actor": return _actor_page(s, s.actors[int(node.id)])
		"trial": return _start_trial(s, s.actors[int(node.id)])
		"trial_end": return _trial_end(s)
		"pick": return _pick_flow(s, s.actors[int(node.id)])
		"attr":
			var a: XActor = s.actors[int(node.id)]
			learn_key(a, str(node.key))
			data(a).pending.pop_front()
			refresh_rewards(a)
			return _pick_flow(s, a)
		"daofa": return _roll_daofa(s, s.actors[int(node.id)], int(node.i))
		"daofa_done": return _daofa_done(s, s.actors[int(node.id)], node)
	return {}


static func _ask(lines: Array, options: Array) -> Dictionary:
	return {"lines": lines.slice(0, 4), "options": options}


static func _tell(lines: Array, next = null) -> Dictionary:
	return {"lines": lines.slice(0, 4), "options": [], "next": next}


static func _retreat(s: XState, page: int) -> Dictionary:
	var members := s.members()
	var size := 4
	var pages := maxi(1, ceili(members.size() / float(size)))
	page = clampi(page, 0, pages - 1)
	var opts := []
	for a in members.slice(page * size, (page + 1) * size):
		var st := state_of(s, a)
		var tag := "［待选奖励］" if st.pending else ("［可突破］" if st.canBreak else ("［通关%d层后突破］" % int(st.gate.required) if st.capped else ""))
		opts.append({"label": "%s %s ×%.1f%s" % [a.display_name(), st.name, st.rate, tag], "next": {"page": "actor", "id": a.actor_id}})
	if page > 0:
		opts.append({"label": "上一页（%d/%d）" % [page, pages], "next": {"page": "retreat", "p": page - 1}})
	if page + 1 < pages:
		opts.append({"label": "下一页（%d/%d）" % [page + 2, pages], "next": {"page": "retreat", "p": page + 1}})
	# 神兵试炼（指定本命兵武器）留第三批：选项照原版列出，进去先说明未开放（O-048）
	opts.append({"label": "神兵试炼（指定本命兵武器）", "next": {"page": "weapon"}})
	opts.append({"label": "离开", "next": null})
	return _ask(["\\C[6]闭关之所\\C[0]", "真气达到大圆满、通关对应楼层后，打赢瓶颈之战突破。", "突破后获得境界奖励。"], opts)


static func _actor_page(s: XState, a: XActor) -> Dictionary:
	var st := state_of(s, a)
	var lines := ["\\C[6]%s\\C[0]：%s %s" % [a.display_name(), st.world, st.name], "真气 %d　加成 ×%.1f" % [st.qi, st.rate]]
	if st.next == null:
		lines.append("已至最高境界")
	elif not st.capped:
		lines.append("距%s还差 %d 真气" % [st.next, st.need])
	elif st.canBreak:
		lines.append("已到瓶颈，可挑战「%s」突破%s" % [REALMS[st.realm + 1].trial, st.next])
	else:
		lines.append("需先通关第%d层，当前已通关%d层" % [int(st.gate.required), int(st.gate.passed)])
	var opts := []
	if st.pending:
		opts.append({"label": "选择突破奖励（%d）" % st.pending, "next": {"page": "pick", "id": a.actor_id}})
	if st.canBreak:
		opts.append({"label": "挑战瓶颈之战", "next": {"page": "trial", "id": a.actor_id}})
	opts.append({"label": "返回", "next": {"page": "retreat"}})
	opts.append({"label": "离开", "next": null})
	return _ask(lines, opts)


static func _start_trial(s: XState, a: XActor) -> Dictionary:
	var d := data(a)
	var i := int(d.realm) + 1
	var g := gate(s, a)
	if not g.ready or not g.unlocked:
		return _tell(["需先通关第%d层，当前已通关%d层。" % [int(g.required), int(g.passed)] if g.ready else "真气尚未达到下一境界。"])
	if not s.battle_members().has(a):
		return _tell(["%s 不在出战队伍中。" % a.display_name(), "请先把%s编入出战队伍再闭关。" % a.display_name()])
	var ref := trial_ref(s, i)
	var kind := str(REALMS[i].trial)
	var troop := int(HEART_TROOP.get(a.actor_id, 0)) if kind == "心魔" else 0
	if troop == 0:
		troop = int(TRIAL_TROOP[kind])
	pending_trial = {"actorId": a.actor_id, "target": i, "ref": ref, "kind": kind, "troopId": troop}
	return {"lines": ["\\C[6]%s\\C[0]幻化为第%d层守层者之力（×%d）。" % [kind, ref.floor, ref.scale], "%s必须坚持到战斗结束，才能突破%s。" % [a.display_name(), REALMS[i].name]],
		"options": [], "battle": troop, "next": {"page": "trial_end"}}


static func _trial_end(s: XState) -> Dictionary:
	var t := trial_done
	trial_done = {}
	pending_trial = {}
	if t.is_empty():
		return {}
	var a: XActor = s.actors[int(t.actorId)]
	if bool(t.get("won", false)) and breakthrough(s, a):
		return _tell(["\\C[6]%s 突破至%s！\\C[0]" % [a.display_name(), REALMS[int(t.target)].name]], {"page": "pick", "id": a.actor_id})
	return _tell(["%s 未能突破。" % a.display_name(), "（突破的角色需活到战斗结束）"], {"page": "actor", "id": a.actor_id})


static func _pick_flow(s: XState, a: XActor) -> Dictionary:
	var d := data(a)
	if d.pending.is_empty():
		return _actor_page(s, a)
	var i := int(d.pending[0])
	var R: Dictionary = REALMS[i]
	var ch: Dictionary = R.choice
	var opts := []
	var id := a.actor_id
	if ch.has("split"):
		opts.append({"label": "攻击属性 +%d%%（物攻、魔攻）" % ch.split, "next": {"page": "attr", "id": id, "key": "attr:atk:%d" % i}})
		opts.append({"label": "防御属性 +%d%%（生命、物防、魔防）" % ch.split, "next": {"page": "attr", "id": id, "key": "attr:def:%d" % i}})
		opts.append({"label": "辅助属性 +%d%%（敏捷、幸运、魔法上限）" % ch.split, "next": {"page": "attr", "id": id, "key": "attr:sup:%d" % i}})
	else:
		opts.append({"label": "全属性 +%d%%" % ch.all, "next": {"page": "attr", "id": id, "key": "attr:all:%d" % i}})
	var left := DAOFA.filter(func(k): return not int(d.daofa.get(k, 0)))
	if not left.is_empty():
		opts.append({"label": "道法（随机一项，剩 %d 种）" % left.size(), "next": {"page": "daofa", "id": id, "i": i}})
	opts.append({"label": "稍后再选", "next": null})
	return _ask(["\\C[6]%s\\C[0] %s突破奖励：自选一项" % [a.display_name(), R.name], "属性：稳定提升；道法：对特定打法大幅加成。"], opts)


## Z.rollDaofa：在没领悟的道法里随机一项；本命兵／灵根有已降服的武器类型／元素时可指定，否则随机
static func _roll_daofa(s: XState, a: XActor, i: int) -> Dictionary:
	var d := data(a)
	var left := DAOFA.filter(func(k): return not int(d.daofa.get(k, 0)))
	var k: String = left[_random_int(left.size())]
	var id := a.actor_id
	if k == "benming" or k == "linggen":
		var is_w := k == "benming"
		var pool: Array = range(1, 13) if is_w else LINGGEN_ELEMENTS
		var names: Array = XDB.system().weaponTypes if is_w else XDB.system().elements
		var known_d: Dictionary = s.zhenqi_spec.w if is_w else s.zhenqi_spec.e
		var known := []
		for x in known_d:
			if pool.has(int(x)):
				known.append(int(x))
		known.sort()
		var rnd: int = pool[_random_int(pool.size())]
		var done := func(x: int) -> Dictionary:
			return {"page": "daofa_done", "id": id, "k": k, "i": i, "key": "daofa:%s:%d" % [k, x], "label": "%s·%s" % [DAOFA_NAME[k], names[x]]}
		if known.is_empty():
			return _daofa_done(s, a, done.call(rnd))
		var opts := known.map(func(x): return {"label": "指定「%s」" % names[x], "next": done.call(x)})
		opts.append({"label": "随机（%s）" % names[rnd], "next": done.call(rnd)})
		return _ask(["领悟道法「%s」：" % DAOFA_NAME[k], "已降服过的Boss可让你指定%s。" % ("武器类型" if is_w else "元素")], opts)
	return _daofa_done(s, a, {"page": "daofa_done", "id": id, "k": k, "i": i, "key": "daofa:" + k, "label": DAOFA_NAME[k]})


static func _daofa_done(_s: XState, a: XActor, node: Dictionary) -> Dictionary:
	var d := data(a)
	d.daofa[str(node.k)] = 1
	if not d.has("daofaStages"):
		d.daofaStages = {}
	d.daofaStages[str(node.k)] = int(node.i)
	learn_key(a, str(node.key))
	d.pending.pop_front()
	refresh_rewards(a)
	return _tell(["%s 领悟道法「%s」！" % [a.display_name(), node.label]], {"page": "pick", "id": a.actor_id})
