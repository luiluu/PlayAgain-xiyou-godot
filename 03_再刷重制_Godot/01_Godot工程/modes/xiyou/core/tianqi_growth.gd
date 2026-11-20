class_name XTianqiGrowth
extends RefCounted
## 【cc·T256·未经审查】天启篇渡鸦、奈叶、流萤无限成长的底座（私密设计仓库 重制设定/天启篇_无限成长_v0.4.md 第二节、3.5 节、
## 第八节卡①；Kyo 11-19「216全推荐」：Q1 甲、Q6 乙）。数据表 tianqi_data/growth.json（全整数，标定只改表）。只认天启篇存档。
##
## - 层价表（三人共用）：第 1～12 层每层 1 份、13～24 层 2 份、25 层 4 份、26 层起每层翻倍；layers(计数, 基础段, 一份) 算成了几层。
##   T286（Kyo D247「去掉层数」）：层数改成连续的小数层——在层价表这条曲线上按份数线性插值（第 k 层内每多一份走 1/price(k) 层），
##   拐点（24 层＝累计 36 份）、越往后越慢的形状都不变，只是去掉台阶；属性＝每层平加×小数层，取整到整数（roundi）。玩家界面不再说「第几层」。
##   三人的计数都是原有的（渡鸦灵魂、奈叶适应次数、流萤胜场），不加存档字段；小数层不进存档，读属性时现算。
## - floor_ok(s, logic)：Q6 乙「哪些战斗算成长」，三人共用。只管超出基础段的累加（基础段不判，由调用方决定）。
##   floor_ok_facts 是同一判定的纯数据版（测试直接喂字典）。
## - param_flat(a, i)：3.5 节的平加。渡鸦魔法攻击、奈叶最大生命和最大魔法，层数给多少面板就多多少：接在 XActor.param_before_alien
##   最后夹值之前（基础乘率、淬元丹、专属模块、坐骑、云裳战斗内层都乘完了），不吃装备词条、套装、被动、能力强化状态的百分比；
##   敌方压属性（四骑士、饥荒线异化、疫病虚弱）和异化词条（空壳、缄默、饕餮）在外层照常压在含层数的总数上。
## - unrace(a, i, before, after)：种族祝福 XRaceBattle.param 在外层对人族八项 ×1.03、鬼族最大魔法、蛮族最大生命 ×(1＋q)，
##   天启篇照常生效（T256 开工核过），会放大平加。这里把种族放大的那一截从平加上退掉（稿 3.5「生效就挪到它外面」的等效做法：
##   不整个挪出去，免得异化词条把魔法压到 0 时平加还留着）。
## - 流萤不走平加（稿 3.5 末条）：余烬与伤害由 T257 在 liuying.gd 接，本文件只给 layers／表里的数（ember_bonus、dmg_pct_of）。
## 本卡不接三人计数规则（T257）：计数在基础段以内时层数 0，param_flat 恒 0，T220 现数不变。
## 地雷（稿 3.2 第 6 条）：奈叶被动「凤霞」（魔法上限一成算进魔攻）现在没实装；它读面板最大魔法，平加挡不住，实装时 Y 要重标。
##
## 回退开关（O-620）：ENABLED＝false 整个关掉（param_flat 恒 0、layers 恒 0、floor_ok 恒 true，回到 T220）；
## RACE_FLAT＝false 时种族祝福照旧放大平加（回到落点只在 param_before_alien 里的做法）。

static var ENABLED := true
static var RACE_FLAT := true

const PATH := "res://modes/xiyou/tianqi_data/growth.json"
const RAVEN := "raven"
const NANOHA := "nanoha"
const LIUYING := "liuying"
const NANOHA_FLAG := "codexNanohaAdapt"
const LIUYING_WINS := "_codexLbEmberWins"

static var _data: Dictionary = {}
static var _by_actor: Dictionary = {}  # actor_id → 表里的键（只收有 flat 的人）


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容）
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
		_by_actor = {}
		var acts = _data.get("actors", {})
		if acts is Dictionary:
			for k in acts:
				if acts[k] is Dictionary and acts[k].get("flat") is Dictionary and not acts[k].flat.is_empty():
					_by_actor[int(acts[k].get("actor", 0))] = str(k)
	return _data


static func reload_table() -> void:
	_data = {}
	_by_actor = {}


static func on(s: XState = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and not data().is_empty()


static func actor_row(key: String) -> Dictionary:
	var r = data().get("actors", {}).get(key)
	return r if r is Dictionary else {}


# ---- 层价表 ----

## 第 n 层（从 1 数）要多少份
static func price(n: int) -> float:
	if n < 1:
		return 0.0
	var p: Dictionary = data().get("price", {})
	var segs: Array = p.get("segments", [])
	var last := 0.0
	var last_to := 0
	for seg in segs:
		if n >= int(seg.from) and n <= int(seg.to):
			return float(seg.shares)
		if int(seg.to) > last_to:
			last_to = int(seg.to)
			last = float(seg.shares)
	if n <= last_to or last <= 0.0:
		return 0.0
	return last * pow(float(p.get("grow", 2)), n - last_to)


## 到第 n 层累计要多少份（cum(12)＝12、cum(24)＝36、cum(25)＝40、cum(26)＝48）
static func cumulative(n: int) -> float:
	var t := 0.0
	for k in range(1, n + 1):
		t += price(k)
	return t


## 计数 count 超过基础段 base 的部分、每份 share，成了几层（T286：连续的小数层）。
## 份数 x＝超出÷一份；累计到第 n 层要 cumulative(n) 份，x 落在第 n＋1 层里时层数＝n＋(x−cumulative(n))÷price(n＋1)。
## 正好落在整层上（含 k_calibrate 灌的计数）时返回整数值，免得 23.999… 取整差 1。
static func layers(count: float, base: float, share: float) -> float:
	if not ENABLED or share <= 0.0:
		return 0.0
	var excess := count - base
	if excess <= 0.0:
		return 0.0
	var x := excess / share
	var cap := int(data().get("price", {}).get("max_layer", 200))
	var t := 0.0
	var n := 0
	while n < cap:
		var p := price(n + 1)
		if p <= 0.0:
			break
		if t + p > x + 1e-9:
			var lay := float(n) + (x - t) / p
			return roundf(lay) if absf(lay - roundf(lay)) < 1e-9 else lay
		t += p
		n += 1
	return float(n)


# ---- 三人的计数与层数（按表里的键）----

static func count_of(key: String, a) -> float:
	var s := XState.current
	if s == null or not a is XActor:
		return 0.0
	match key:
		RAVEN:
			var need := int(actor_row(RAVEN).get("need_skill", 0))
			if need > 0 and not XRaven.has(a, need):
				return 0.0
			return XRaven.soul(a)
		NANOHA:
			var book = s.flags.get(NANOHA_FLAG, {})
			return maxf(0.0, float(book.get(str(a.actor_id), 0.0))) if book is Dictionary else 0.0
		LIUYING:
			var w = a.state_data.get(LIUYING_WINS)
			return maxf(0.0, float(w)) if w != null else 0.0
	return 0.0


## 某人现在成了几层（小数层；不在天启篇、开关关着、表里没有这人都是 0）
static func layers_of(key: String, a) -> float:
	if not on():
		return 0.0
	var r := actor_row(key)
	if r.is_empty() or not a is XActor or int(a.actor_id) != int(r.get("actor", 0)):
		return 0.0
	return layers(count_of(key, a), float(r.get("base", 0)), float(r.get("share", 0)))


## 流萤：层数给的余烬生命（不含前 ember_cap）＝每层 ember × 小数层，取整（roundi）
static func ember_bonus(n: float) -> int:
	return roundi(maxf(0.0, n) * float(actor_row(LIUYING).get("ember", 0)))


## 流萤：层数给的伤害百分数＝小数层 × dmg_pct ÷ dmg_step，向下取整（附则 E：整数％；即余烬每满 500 点＋1%，没满不给）
static func dmg_pct_of(n: float) -> int:
	var r := actor_row(LIUYING)
	var step := maxi(1, int(r.get("dmg_step", 1)))
	return floori(maxf(0.0, n) * float(r.get("dmg_pct", 0)) / float(step) + 1e-9)


# ---- 状态行（T259：私密设计仓 天启篇_无限成长_v0.4 第八节 Carbon 定稿原文，数值全从表里现读）----

static func _fmt_int(v: int) -> String:
	var neg := v < 0
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


static func _fmt_num(v: float) -> String:
	var tenths := roundi(v * 10.0)
	if tenths % 10 == 0:
		return _fmt_int(tenths / 10)
	return "%s.%d" % [_fmt_int(tenths / 10), absi(tenths % 10)]


## 三人状态行（空串＝未达起点、缺前置技能、或未在天启篇无限成长里）
## T286（D247）：不再说「第几层」，改成「计数 → 加了多少」；括号里一句提示越往后越慢。文字待小A 审。
static func status_line(key: String, a) -> String:
	if not on():
		return ""
	var r := actor_row(key)
	if r.is_empty() or not (a is XActor) or int(a.actor_id) != int(r.get("actor", 0)):
		return ""
	if key == LIUYING and not XTianqiSkills.cards_on():
		return ""
	var need := int(r.get("need_skill", 0))
	if need > 0 and key == RAVEN and not XRaven.has(a, need):
		return ""
	var base := float(r.get("base", 0))
	var share := float(r.get("share", 0))
	var cnt := count_of(key, a)
	if share <= 0.0 or cnt < base:
		return ""
	var n := layers(cnt, base, share)
	match key:
		RAVEN:
			return "冥冠：灵魂 %s → 魔法攻击＋%s（越往后涨得越慢）" % [_fmt_int(floori(cnt)), _fmt_int(flat_amount(RAVEN, 4, n))]
		NANOHA:
			return "超限适应：适应 %s 次 → 最大生命＋%s、最大魔法＋%s（越往后涨得越慢）" % [_fmt_num(cnt), _fmt_int(flat_amount(NANOHA, 0, n)), _fmt_int(flat_amount(NANOHA, 1, n))]
		LIUYING:
			return "不熄之火：胜场 %s → 余烬生命＋%s、伤害＋%d%%（越往后涨得越慢）" % [_fmt_int(floori(cnt)), _fmt_int(ember_bonus(n)), dmg_pct_of(n)]
	return ""


## 5683 适应、10624 模组-偏时迸发 说明卡尾的状态行（渡鸦 10137 走 XRaven.ledger_help）
static func help_rows(skill: Dictionary, a) -> Array:
	if not skill.has("stypeId"):
		return []
	var id := int(skill.get("id", 0))
	var key := ""
	if id == 5683:
		key = NANOHA
	elif id == 10624:
		key = LIUYING
	else:
		return []
	var line := status_line(key, a)
	return [[line, 18, "#ffffff", false, 0]] if line != "" else []


# ---- 平加（稿 3.5）----

## 每层平加多少（表里没有这项 0）
static func flat_per_layer(key: String, i: int) -> float:
	var f = actor_row(key).get("flat", {})
	return float(f.get(str(i), 0)) if f is Dictionary else 0.0


## 小数层 n 给的平加：每层平加 × n，取整（roundi，T286）
static func flat_amount(key: String, i: int, n: float) -> int:
	return roundi(flat_per_layer(key, i) * maxf(0.0, n))


## XActor.param_before_alien 夹值之前加这一项。不是渡鸦、奈叶，或不是表里的能力项，直接 0
static func param_flat(a, i: int) -> float:
	if not ENABLED or not a is XActor:
		return 0.0
	if data().is_empty():
		return 0.0
	var key = _by_actor.get(int(a.actor_id))
	if key == null:
		return 0.0
	if flat_per_layer(key, i) == 0.0:
		return 0.0
	return float(flat_amount(key, i, layers_of(key, a)))


## 种族祝福包装之后调：before＝进种族包装前的值，after＝种族包装的结果。把种族对平加那一截的放大退掉
## T257（T256 核查 P2-1）：before 已经过了内层减益（四骑士疫病／病弱／碎甲、饥荒线枯竭、异化缄默等按比例压总数），
## 这时 before 里的平加只剩 f×(before÷param_before_alien)，按满额 f 退会把种族给别的部分的加成也退掉；改按减益后的比例缩（只缩不放：
## 饥荒遗物这类内层加成放大的那一截照旧留给种族，见 T256 交付单「发现 2」）。
## T257（P2-2）：不再按比例倒推（人族 ×1.03 对平加两次取整差 ±1），直接拿去掉平加的数过一遍种族再加回：XRaceBattle.param(a,i,before−f)＋f。
static func unrace(a, i: int, before: float, after: float) -> float:
	if after == before or not RACE_FLAT or before <= 0.0:
		return after
	var f := param_flat(a, i)
	if f <= 0.0:
		return after
	var inner: float = a.param_before_alien(i)
	if inner > 0.0 and before < inner:
		f = roundf(f * before / inner)
	f = minf(f, before)
	if f <= 0.0:
		return after
	return XRaceBattle.param(a, i, before - f) + f


# ---- 哪些战斗算（Q6 乙）----

## 纯数据版：{progress 已通主塔层, map_floor 地图层号, abyss 是不是深渊, king 王者副本, qiyin 七印里副本, finale 34～36 终局战}
static func floor_ok_facts(f: Dictionary) -> bool:
	if not ENABLED:
		return true
	if bool(f.get("king", false)) or bool(f.get("qiyin", false)) or bool(f.get("finale", false)):
		return true
	var r: Dictionary = data().get("floor_rule", {})
	var window := int(r.get("window", 5))
	var progress := int(f.get("progress", 0))
	var mf := int(f.get("map_floor", 0))
	if bool(f.get("abyss", false)):
		return mf > 0 and mf >= mini(progress, int(r.get("abyss_cap", 29))) - window
	return mf >= progress - window


## 从存档和这一场的 logic 取事实（logic 可以是 null：只按地图和副本档位判）
static func facts(s: XState, logic = null) -> Dictionary:
	var r: Dictionary = data().get("floor_rule", {})
	var info := XDB.rec("MapInfos", s.map_id)
	var name := str(info.get("name", "")) if not info.is_empty() else ""
	var f := {
		"progress": XZhenqi.progress_floor(s),
		"map_floor": XDungeon.map_floor(s.map_id),
		"abyss": name.begins_with(str(r.get("abyss_prefix", "深渊"))),
		"king": XDungeon.inside(s) and int(s.variable(XDungeon.VAR_TIER)) == int(r.get("king_tier", 4)),
		"qiyin": false,
		"finale": false,
	}
	if logic != null:
		var qr := XTianqiQiyinRule.fight(logic)
		f.qiyin = (not qr.is_empty() and not bool(qr.get("enemy_only", false))) or XTianqiQiyinDragonRun.active(logic)
		var horse: Dictionary = XTianqiHorsemen.fight(logic)
		# T257（T256 核查 P3-1）：照 XTianqiBrand.classify，四骑士线的开场生存战（mode＝survival）不算终局战
		f.finale = str(horse.get("line", "")) != "" and str(horse.get("mode", "")) != "survival"
		for e in logic.enemies:
			if str(e.horseman.get("rec", {}).get("_ref", "")) == "hongjun":
				f.finale = true
	return f


static func floor_ok(s: XState, logic = null) -> bool:
	if not ENABLED or s == null:
		return true
	return floor_ok_facts(facts(s, logic))
