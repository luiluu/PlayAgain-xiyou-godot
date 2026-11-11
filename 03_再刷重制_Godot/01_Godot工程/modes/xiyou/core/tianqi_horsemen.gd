class_name XTianqiHorsemen
extends RefCounted
## 【cc·天启篇·未经审查】天启四骑士 36 层本体战（四骑士 Boss 数值稿 v0.4、四线剧情与关卡设计稿 v0.4 第 5 节）。
## 战争＝莉co、死亡＝勇者、瘟疫＝混子、饥荒＝小镇做题家。数值表在 tianqi_data/horsemen.json（只读）。
##
## 只对天启篇存档生效（XTianqiCombat.on：XTianqi.active 且五档数值开着），发行构建里还要 XTianqi.RELEASE_OPEN；
## 开关 ENABLED＝false 时 prepare 不收，战斗里各处挂钩一概不动（和没有这个模块一样）。原版档、别的敌人一概不受影响。
##
## 怎么开一场：XTianqiHorsemen.prepare("war") 之后照常开战（敌群随便给，setup 时整组换成骑士＋援军／小怪的位子）。
## 36 层的地图事件还没做（四线内容），先由测试和以后的地图事件调。
##
## 战斗侧（BattleLogic 的挂钩，都先看 active(logic)）：
## - 敌人：骑士借 shell_enemy 的外观，名字、能力值、行动都由本表给（XEnemy.horseman）；不是神话、不吃霸体（Kyo 11-11 09:41）、
##   免疫停手的控制（混乱、眩晕、睡眠等）和即死；没有经验、金钱、掉落。援军、小怪也一样借外观、不掉东西。
## - 生命：艰险为基准 × 骑士单用的血量倍率 hp_rate（0.7／1.0／1.5／3.0／5.0），hp_override 直接给某档（混子证道 288 万）；
##   攻击、魔攻 × balance_table 的敌人攻击；防御、魔防、敏捷（按我方上场平均敏捷的几倍）、系数、冷却、计量、终焉五档一样。
## - 出手：骑士每回合 actions 次（战争另加再动），每次由本模块按阶段和计量选招（decide），结算由 perform 直接扣血
##  （一段＝攻击×系数×攻÷(攻＋防)×我方档位承伤，过护盾）。
## - 我方：疫病、病弱、识破、破产、碎甲降最大生命在 actor_param 里乘；绝粮挡住 MP、TP 的恢复；死期死去的人本场不能复活。
##
## 还没做（交付单「未做」）：画面上的计量条和死期、不服标记（现在只在战斗日志里报）；生存战、影子的战斗规则（只给了数值）；
## 绝粮的「消耗再提高一档」和口粮；骑士队长让免即死、不屈失效；疫病让减益清不掉；识破的反击、爆闪几率。

const PATH := "res://modes/xiyou/tianqi_data/horsemen.json"
const LINES := ["death", "war", "famine", "plague"]
const META := "xhorseman"

## 开关：false＝四骑士战一概不开（prepare 不收、挂钩不动）
static var ENABLED := true

static var _data: Dictionary = {}
## 下一场开战要换成哪位骑士（prepare 设、setup 取走）
static var _pending := ""
## 正在打的骑士战（BattleLogic）；挂钩先看它，没有就原样返回
static var _logic_ref: WeakRef = null


# ---- 数据 ----

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiHorsemen: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiHorsemen: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


static func knight(line: String) -> Dictionary:
	var k = data().get("knights", {}).get(line)
	return k if k is Dictionary else {}


## 本档骑士血量倍率
static func hp_rate(key: String) -> float:
	return float(data().get("hp_rate", {}).get(key, 0.0))


## 某档骑士本体的能力值：{hp, atk, mat, def, mdf, agi_rate, actions}。hp 按骑士血量倍率（或直接给的那档），攻击、魔攻按共用的敌人攻击倍率。
static func stats(line: String, key: String) -> Dictionary:
	var k := knight(line)
	var row := XTianqiBalance.difficulty(key)
	if k.is_empty() or row.is_empty():
		return {}
	var over: Dictionary = k.get("hp_override", {})
	var hp := float(over[key]) if over.has(key) else roundf(float(k.hp) * hp_rate(key))
	var atk_rate := float(row.enemy_atk)
	return {"hp": hp, "atk": roundf(float(k.get("atk", 0)) * atk_rate), "mat": roundf(float(k.get("mat", 0)) * atk_rate),
		"def": float(k.get("def", 0)), "mdf": float(k.get("mdf", 0)), "agi_rate": float(k.get("agi_rate", 1.0)),
		"actions": int(k.get("actions", 2)), "name": str(k.get("name", ""))}


## 35 层影子：生命按 35 层守层首领 × 本档敌人血量，攻击是本体（本档）的几成
static func shadow_stats(line: String, key: String) -> Dictionary:
	var body := stats(line, key)
	if body.is_empty():
		return {}
	var sh: Dictionary = data().get("shadow", {})
	var r := float(sh.get("atk_rate", {}).get(line, 1.0))
	var out := body.duplicate()
	out.hp = roundf(float(sh.get("hp", 0)) * float(XTianqiBalance.difficulty(key).enemy_hp))
	out.atk = roundf(float(body.atk) * r)
	out.mat = roundf(float(body.mat) * r)
	out.actions = 1
	return out


## 开场生存战：攻击是本体（本档）的 1 成，生命锁住
static func survival_stats(line: String, key: String) -> Dictionary:
	var body := stats(line, key)
	if body.is_empty():
		return {}
	var r := float(data().get("survival", {}).get("atk_rate", 0.1))
	var out := body.duplicate()
	out.atk = roundf(float(body.atk) * r)
	out.mat = roundf(float(body.mat) * r)
	return out


## 表里设计数值含数字 4 的（和 XTianqiBalance 同一套规则；豁免键是个数、回合数）
static func nice_number_violations() -> Array:
	var exempt: Array = data().get("nice_number_exempt", [])
	var out := []
	_scan(data(), "", exempt, out)
	return out


static func _scan(v, path: String, exempt: Array, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if not exempt.has(k):
				_scan(v[k], path + "/" + str(k), exempt, out)
	elif v is Array:
		for i in v.size():
			_scan(v[i], path + "/" + str(i), exempt, out)
	elif v is float or v is int:
		var s := XTianqiBalance._num_text(float(v))
		if s.contains("4"):
			out.append(path + "=" + s)


# ---- 开关与开战 ----

## 这份存档能打骑士战：开关开着、天启篇存档按五档数值跑、发行构建里天启篇已开放
static func allowed(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and XTianqiCombat.on(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


## 下一场战斗换成这位骑士（line：death／war／famine／plague）。不收时返回 false。
static func prepare(line: String, s: XState = null) -> bool:
	if not LINES.has(line) or not allowed(s):
		_pending = ""
		return false
	_pending = line
	return true


static func pending() -> String:
	return _pending


## 正在打骑士战的 logic（不是就 null）
static func active_logic():
	var l = _logic_ref.get_ref() if _logic_ref != null else null
	return l if l != null and l.has_meta(META) else null


static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if logic != null and logic.has_meta(META) else {}


static func active(logic) -> bool:
	return logic != null and logic.has_meta(META) and ENABLED


## BattleLogic.setup：敌群成员建完后调。有 prepare 过的骑士就把整组换成骑士＋援军／小怪的位子（都先藏着，开战时按规则出场）。
static func setup(logic, s: XState) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	var line := _pending
	_pending = ""
	if line == "" or not allowed(s):
		return
	var key := str(s.flags.tianqi.get("difficulty", ""))
	var st := stats(line, key)
	if st.is_empty():
		return
	var shell: Dictionary = data().get("shell_enemy", {})
	var agi := _avg_agi(logic.actors)
	logic.enemies.clear()
	var kn := XEnemy.new()
	kn.setup_horseman(int(shell.get("knight", 1)), _knight_rec(int(shell.get("knight", 1)), st, agi), true)
	kn.set_meta("x", 600.0)
	kn.set_meta("y", 360.0)
	logic.enemies.append(kn)
	var slots := 0
	match line:
		"war":
			slots = int(knight(line).reinforce.max_adds)
		"famine":
			slots = int(knight(line).start_adds)
		"plague":
			slots = int(knight(line).adds.max)
	var adds := []
	for i in range(slots):
		var e := XEnemy.new()
		e.setup_horseman(int(shell.get("add", 2)), _add_rec(int(shell.get("add", 2)), line, key))
		e.set_meta("x", 300.0 + 70.0 * (i % 3))
		e.set_meta("y", 240.0 + 110.0 * floorf(i / 3.0))
		e.hidden = true
		logic.enemies.append(e)
		adds.append(e)
	var f := {"line": line, "key": key, "knight": kn, "adds": adds, "base": st, "phase": 1, "marks": {},
		"queue": [], "down": {}, "acted": {}}
	match line:
		"death":
			f.merge({"gems": 0, "unique": 0, "captain": false, "doom_last": 0, "finale": 0, "sword_target": null})
		"war":
			f.merge({"sparks": 0, "layer": 1, "cd": {}, "kindled": false, "fire_up": 0.0, "barrage": false})
		"famine":
			f.merge({"seniority": 0, "broke1": false, "broke2": false})
		"plague":
			f.merge({"taunt": true, "shield_acc": 0.0, "shield_open": false, "broken_turn": -1, "plague_down": 0.0, "last_add": 0})
	logic.set_meta(META, f)
	_logic_ref = weakref(logic)


static func _avg_agi(list: Array) -> float:
	var sum := 0.0
	for a in list:
		sum += float(a.agi)
	return sum / maxf(1.0, float(list.size()))


## 骑士的合成记录：借外观（battlerName 等），名字、能力值换掉，行动、备注、掉落、经验金钱清空
static func _knight_rec(shell_id: int, st: Dictionary, agi: float) -> Dictionary:
	var rec: Dictionary = XDB.rec("Enemies", shell_id).duplicate(true)
	rec.name = str(st.name)
	rec.params = [float(st.hp), 1000.0, float(st.atk), float(st.def), float(st.mat), float(st.mdf), roundf(agi * float(st.agi_rate)), 100.0]
	rec.actions = []
	rec.note = "NoElite"
	rec.meta = {}
	rec.traits = []
	rec.dropItems = []
	rec.exp = 0
	rec.gold = 0
	return rec


## 援军、小怪：艰险数值 × 本档敌人血量／攻击（它们是本线普通怪，照共用倍率）
static func _add_rec(shell_id: int, line: String, key: String) -> Dictionary:
	var a: Dictionary = data().get("adds", {})
	var row := XTianqiBalance.difficulty(key)
	var rec: Dictionary = XDB.rec("Enemies", shell_id).duplicate(true)
	rec.name = {"war": "兵临的援军", "famine": "饿出来的小怪", "plague": "混出来的小怪"}.get(line, "援军")
	rec.params = [roundf(float(a.hp) * float(row.enemy_hp)), 100.0, roundf(float(a.atk) * float(row.enemy_atk)), float(a.def),
		roundf(float(a.atk) * float(row.enemy_atk)), float(a.def), 100.0, 100.0]
	rec.actions = []
	rec.note = "NoElite"
	rec.meta = {}
	rec.traits = []
	rec.dropItems = []
	rec.exp = 0
	rec.gold = 0
	return rec


## 开战（BattleLogic.setup 末尾）：本线终焉与开场的援军、小怪
static func start(logic) -> void:
	if not active(logic):
		return
	var f := fight(logic)
	match str(f.line):
		"war":
			_reinforce(logic, f)
		"famine":
			for e in f.adds:
				_summon(logic, f, e)
		"plague":
			var p: Dictionary = knight("plague").plague
			f.plague_down = float(p.down_start)
			for a in logic.actors:
				_mark(f, a).plague = true
			_say(f, "瘟疫笼罩了战场：我方全体染上疫病。")
	_flush_params(logic)


static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		var f := fight(logic)
		logic.remove_meta(META)
		for a in logic.actors:
			if a is XBattler:
				a.param_mark_dirty()
		f.clear()
	_logic_ref = null


# ---- 查询 ----

static func is_knight(logic, b) -> bool:
	return active(logic) and b != null and is_same(fight(logic).knight, b)


static func is_add(logic, b) -> bool:
	return active(logic) and b != null and fight(logic).adds.has(b)


static func _mark(f: Dictionary, a) -> Dictionary:
	if not f.marks.has(a):
		f.marks[a] = {}
	return f.marks[a]


static func mark_of(logic, a) -> Dictionary:
	return fight(logic).get("marks", {}).get(a, {}) if active(logic) else {}


static func _say(f: Dictionary, text: String) -> void:
	f.queue.append({"type": "battle_text", "text": text})


static func take_logs(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var out: Array = f.queue
	f.queue = []
	return out


static func _alive_actors(logic) -> Array:
	return logic.actors.filter(func(a): return a.is_alive())


static func _hp_ratio(f: Dictionary) -> float:
	return f.knight.hp_rate()


## 阶段：死亡、瘟疫按血量 66%／33%；战争按血量换算火药配方（两层一阶段）；饥荒只看资历
static func phase_of(f: Dictionary) -> int:
	if str(f.line) == "famine":
		var lines: Array = knight("famine").seniority.lines
		return 3 if int(f.seniority) >= int(lines[1]) else (2 if int(f.seniority) >= int(lines[0]) else 1)
	var th: Array = data().get("phase_hp", [0.66, 0.33])
	var r := _hp_ratio(f)
	return 3 if r <= float(th[1]) else (2 if r <= float(th[0]) else 1)


## 战争：血量到了几层火药配方（开场 1 层，之后每 1/6 一层）
static func war_layer(hp_ratio: float) -> int:
	var n := 1
	for t in knight("war").layers:
		if hp_ratio <= float(t):
			n += 1
	return n


# ---- 回合 ----

## BattleLogic.start_turn 末尾（行动顺序已排）：死期、援军、疫病、阶段变化。日志放进 turn_start_logs。
static func start_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var turn := int(logic.turn)
	f.acted = {}
	_check_phase(logic, f)
	match str(f.line):
		"death":
			_death_turn_start(logic, f, turn)
		"war":
			var r: Dictionary = knight("war").reinforce
			if turn > 1 and (turn - 1) % int(r.every) == 0:
				_reinforce(logic, f)
		"plague":
			_plague_turn_start(logic, f, turn)
	_flush_params(logic)
	return take_logs(logic)


## BattleLogic.end_turn（回合末各人结算之后）：死期带走、灼烧、疫病、不服、识破到期。
static func end_turn(logic) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	var logs := []
	for a in logic.actors.duplicate():
		var m := _mark(f, a)
		if m.get("doom", false):
			m.doom = false
			if a.is_alive():
				m.no_revive = true
				_say(f, "%s的死期到了。" % a.display_name())
				logs.append_array(take_logs(logic))
				_lose_hp(logic, a, a.hp + a.shield, logs, true)
		if a.is_alive() and int(m.get("burn", 0)) > 0:
			m.burn = int(m.burn) - 1
			_lose_hp(logic, a, floorf(a.mhp * float(knight("war").wave.burn)), logs)
		if a.is_alive() and m.get("plague", false):
			_lose_hp(logic, a, floorf(a.mhp * float(knight("plague").plague.dot)), logs)
		for k in ["seen", "shrapnel"]:
			if int(m.get(k, 0)) > 0:
				m[k] = int(m[k]) - 1
	if str(f.line) == "plague":
		var p: Dictionary = knight("plague").plague
		f.plague_down = minf(float(p.down_cap), float(f.plague_down) + float(p.down_per))
		# 小怪每回合给一人 +1 不服
		for e in f.adds:
			if e.is_alive():
				var live := _alive_actors(logic)
				if not live.is_empty():
					_defiance(logic, f, live[logic._int(0, live.size() - 1, "horseman_defiance")], int(knight("plague").defiance.per_add))
	if str(f.line) == "death" and phase_of(f) == 3:
		f.finale = mini(int(knight("death").finale.full), int(f.finale) + 1)
		_say(f, "终末 %d／%d。" % [int(f.finale), int(knight("death").finale.full)])
	_check_kills(logic, f)
	_flush_params(logic)
	logs.append_array(take_logs(logic))
	return logs


static func _check_phase(logic, f: Dictionary) -> void:
	var p := phase_of(f)
	if str(f.line) == "war":
		var layer := war_layer(_hp_ratio(f))
		while int(f.layer) < layer:
			f.layer = int(f.layer) + 1
			_say(f, ["", "连珠爆竹", "碎甲弹片", "莉co特调", "引信已燃", "满天星火", "炮火连天"][int(f.layer)] + "：火药配方第 %d 层。" % int(f.layer))
			if int(f.layer) >= 6:
				f.sparks = maxi(int(f.sparks), int(knight("war").sparks.full))
	if p <= int(f.phase):
		return
	while int(f.phase) < p:
		f.phase = int(f.phase) + 1
		match str(f.line):
			"death":
				if int(f.phase) == 2:
					_captain(logic, f)
				elif int(f.phase) == 3:
					_say(f, "终局：终末开始叠层。")
			"famine":
				if int(f.phase) == 2:
					f.broke1 = true
					_say(f, "噫~我中了！")
				elif int(f.phase) == 3:
					f.broke2 = true
					var up := float(knight("famine").sword_rain.all_up)
					for i in [2, 3, 4, 5, 6]:
						f.knight.add_param(i, float(f.knight.data().params[i]) * up)
					_say(f, "今日方知我是我：领悟仙法·百亿仙剑。")
			"plague":
				if int(f.phase) == 2:
					f.shield_open = true
					f.shield_acc = 0.0
					_say(f, "混子之盾出现了。")
				elif int(f.phase) == 3:
					_say(f, "病入膏肓。")


# ---- 死亡·勇者 ----

static func _death_turn_start(logic, f: Dictionary, turn: int) -> void:
	var k := knight("death")
	var interval := int(k.doom.phase_interval) if int(f.phase) >= 3 else int(k.doom.interval)
	if turn - int(f.doom_last) >= interval:
		var live := _alive_actors(logic).filter(func(a): return not _mark(f, a).get("doom", false))
		if not live.is_empty():
			var t = live[logic._int(0, live.size() - 1, "horseman_doom")]
			_mark(f, t).doom = true
			f.doom_last = turn
			_say(f, "死期：%s会在本回合结束时死去。" % t.display_name())
	# 神圣剑提前一回合亮出目标（已确认）：下一回合放的，这回合开始就选好
	var every := int(k.holy_sword.every)
	if (turn + 1) % every == 0:
		var live := _alive_actors(logic)
		if not live.is_empty():
			f.sword_target = live[logic._int(0, live.size() - 1, "horseman_sword")]
			_say(f, "勇者的剑指向了%s（下回合神圣剑）。" % f.sword_target.display_name())


static func _captain(logic, f: Dictionary) -> void:
	if bool(f.captain):
		return
	f.captain = true
	var up := float(knight("death").captain)
	f.knight.add_param(2, float(f.base.atk) * up)
	f.knight.add_param(3, float(f.base.def) * up)
	logic.can_escape = false
	_say(f, "勇者变身骑士队长：逃跑必定失败。")


## BattleLogic.try_escape：死亡骑士战里逃跑必定失败；还没变身就当场变身（原稿「有人逃跑就变身」）
static func blocks_escape(logic) -> bool:
	if not active(logic):
		return false
	var f := fight(logic)
	if str(f.line) != "death":
		return false
	_captain(logic, f)
	return true


# ---- 战争·莉co ----

## 补一波援军：一波 per_wave 只，场上最多 max_adds 只（藏着或倒下的位子拿来用）
static func _reinforce(logic, f: Dictionary) -> void:
	var r: Dictionary = knight("war").reinforce
	var n := 0
	for e in f.adds:
		if n >= int(r.per_wave):
			break
		if e.is_alive():
			continue
		_summon(logic, f, e)
		n += 1
	if n > 0:
		_say(f, "兵临：援军到了 %d 只。" % n)


static func _summon(logic, f: Dictionary, e) -> void:
	var idx: int = logic.enemies.find(e)
	if idx < 0:
		return
	f.down.erase(e)
	if e.is_dead():
		f.queue.append_array(logic.enemy_recover_all(idx))
	if e.hidden:
		f.queue.append_array(logic.enemy_appear(idx))
	e.hp = e.mhp
	for l in f.queue:
		if l is Dictionary and l.get("type") == "enemy_change":
			l["tianqi_horseman"] = true


static func war_extra_actions(logic) -> int:
	var f := fight(logic)
	var others: int = logic.alive(logic.enemies).filter(func(e): return not is_same(e, f.knight)).size()
	return mini(int(knight("war").max_extra), floori(others / 2.0))


# ---- 瘟疫·混子 ----

static func _plague_turn_start(logic, f: Dictionary, turn: int) -> void:
	var k := knight("plague")
	# 破盾的下一回合嘲讽解除，再下一回合恢复
	if int(f.broken_turn) >= 0:
		if turn == int(f.broken_turn) + 1:
			f.taunt = false
			_say(f, "盾碎了：这一回合不服来打我失效。")
		elif turn > int(f.broken_turn) + 1:
			f.taunt = true
			f.broken_turn = -1
	if int(f.phase) >= 2 and turn - int(f.last_add) >= int(k.adds.every):
		for e in f.adds:
			if not e.is_alive():
				_summon(logic, f, e)
				f.last_add = turn
				_say(f, "混出了一只小怪。")
				break
	for a in _alive_actors(logic):
		if _mark(f, a).get("plague", false) and logic._float("horseman_plague_confuse") < float(k.plague.confuse):
			_confuse(logic, a)


static func _confuse(logic, a) -> void:
	var id := int(data().get("confusion_state", 124))
	logic._state_add(a, id)
	if a.is_state_affected(id):
		a.state_turns[id] = 1


static func _defiance(logic, f: Dictionary, a, n: int) -> void:
	var k: Dictionary = knight("plague").defiance
	var m := _mark(f, a)
	m.defiance = int(m.get("defiance", 0)) + n
	if int(m.defiance) >= int(k.full):
		m.defiance = 0
		_confuse(logic, a)
		_say(f, "%s不服到失控了。" % a.display_name())
		var mates: Array = _alive_actors(logic).filter(func(x): return not is_same(x, a))
		if not mates.is_empty():
			var to = mates[logic._int(0, mates.size() - 1, "horseman_defiance_pass")]
			var mm := _mark(f, to)
			mm.defiance = int(mm.get("defiance", 0)) + int(k.pass)


## 混子之盾：累计伤害到最大生命的 22%（第三阶段 33%）就碎
static func _shield_hit(f: Dictionary, value: float, turn: int) -> void:
	if not bool(f.shield_open) or value <= 0.0:
		return
	f.shield_acc = float(f.shield_acc) + value
	var k: Dictionary = knight("plague").shield
	var need := float(f.knight.mhp) * float(k.break3 if int(f.phase) >= 3 else k.break)
	if float(f.shield_acc) >= need and int(f.broken_turn) < 0:
		f.shield_acc = 0.0
		f.broken_turn = turn
		_say(f, "混子之盾碎了！")


# ---- 骑士出手 ----

## 骑士本回合行动次数（BattleLogic.make_action_times）；不是骑士返回 -1
static func action_times(logic, b) -> int:
	if not is_knight(logic, b):
		return -1
	var f := fight(logic)
	var n := int(f.base.actions)
	if str(f.line) == "war":
		n += war_extra_actions(logic)
	return n


## 骑士和小怪的行动（BattleLogic.decide）：返回 [合成技能, 目标]；不是本模块的敌人返回 []
static func decide(logic, b) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	if is_add(logic, b):
		# 援军普攻；饥荒、瘟疫的小怪不主动攻击
		return [_skill("add_attack", "攻击", 1, 1, float(data().adds.coef), false), null] if str(f.line) == "war" else [{}, null]
	if not is_knight(logic, b):
		return []
	var i := int(f.acted.get(b, 0))
	f.acted[b] = i + 1
	_check_phase(logic, f)
	match str(f.line):
		"death":
			return _death_pick(logic, f, i)
		"war":
			return _war_pick(logic, f)
		"famine":
			return _famine_pick(logic, f, i)
		"plague":
			return [_skill("bash", "盾击", 1, 1, float(knight("plague").bash.coef), false), null]
	return [{}, null]


## 合成技能：带 tianqi_horseman 标记，BattleLogic.act 见到它就交给 perform；画面只用名字
static func _skill(kind: String, name: String, scope: int, hits: int, coef: float, magical: bool) -> Dictionary:
	return {"id": 0, "tianqi_horseman": kind, "name": name, "scope": scope, "hits": hits, "coef": coef, "magical": magical,
		"animationId": 0, "iconIndex": 0, "message1": "", "message2": "", "note": "", "meta": {}, "effects": [],
		"damage": {"type": 1, "elementId": 0, "formula": "0", "variance": 0, "critical": false}, "repeats": 1, "stypeId": 0,
		"mpCost": 0, "tpCost": 0, "speed": 0, "successRate": 100, "hitType": 0}


static func _death_pick(logic, f: Dictionary, i: int) -> Array:
	var k := knight("death")
	var turn := int(logic.turn)
	if i == 0 and int(f.finale) >= int(k.finale.full):
		return [_skill("finale", "现在一切结束了", 2, 1, float(k.finale.coef), false), null]
	if i == 1 and turn % int(k.holy_sword.every) == 0:
		var t = f.sword_target if f.sword_target != null and f.sword_target.is_alive() else null
		return [_skill("holy_sword", "神圣剑", 1, maxi(1, int(f.unique)), float(k.holy_sword.coef), false), t]
	var kind: String = ["red", "blue", "holy"][int(f.gems) % 3]
	return [_skill(kind, {"red": "红宝石", "blue": "蓝宝石", "holy": "圣水"}[kind], 11, 0, 0.0, false), null]


static func _war_pick(logic, f: Dictionary) -> Array:
	var k := knight("war")
	var cd: Dictionary = f.cd
	var turn := int(logic.turn)
	var layer := int(f.layer)
	if int(f.sparks) >= int(k.sparks.full) and int(cd.get("fireworks", 0)) <= turn:
		var hits := int(k.fireworks.hits) + (int(k.fireworks.bonus_hits) if layer >= 5 else 0)
		return [_skill("fireworks", "漫天烟火", 2, hits, float(k.fireworks.coef), true), null]
	if int(f.sparks) >= int(k.bomb.need) and int(cd.get("bomb", 0)) <= turn:
		var shrapnel := layer >= 2
		return [_skill("bomb", "雷火弹·碎甲" if shrapnel else "雷火弹", 2, int(k.bomb.fire_hits) + (int(k.bomb.shrapnel_hits) if shrapnel else 0),
			float(k.bomb.coef), true), null]
	if int(cd.get("kindle", 0)) <= turn:
		return [_skill("kindle", "添柴加火", 11, 0, 0.0, true), null]
	if turn % 2 == 1:
		var hits := int(k.wave.hits) + (int(k.wave.bonus_hits) if layer >= 1 else 0) + (int(k.wave.kindle_hits) if bool(f.kindled) else 0)
		return [_skill("wave", "焰浪轰击", 2, hits, float(k.wave.coef), true), null]
	return [_skill("crackle", "噼啪三响", 1, int(k.crackle.hits) + (int(k.crackle.bonus_hits) if layer >= 1 else 0), float(k.crackle.coef), true), null]


static func _famine_pick(logic, f: Dictionary, i: int) -> Array:
	var k := knight("famine")
	var turn := int(logic.turn)
	if i == 0:
		if bool(f.broke2) and turn % int(k.sword_rain.every) == 0:
			return [_skill("sword_rain", "仙法：百亿仙剑", 2, int(k.sword_rain.hits), float(k.sword_rain.coef), true), null]
		if bool(f.broke1) and turn % int(k.bankrupt.every) == 0:
			return [_skill("bankrupt", "仙法：破产一剑", 1, 1, float(k.bankrupt.coef), true), null]
		return [_skill("sea", "题海战术", 2, 1, float(k.sea.coef), false), null]
	return [_skill("landing", "上岸剑法", 1, 1, float(k.landing.coef), false), null]


## 执行一次骑士／小怪的行动，返回日志（action、hit、battle_text、regen、collapse）
static func perform(logic, u, skill: Dictionary, chosen) -> Array:
	var f := fight(logic)
	var logs := [{"type": "action", "user": u, "skill": skill, "views": logic.views()}]
	var kind := str(skill.tianqi_horseman)
	match kind:
		"add_attack":
			var t = _pick_target(logic, chosen)
			if t != null:
				var mult := 1.0 + (float(knight("war").add_fire_up) if int(f.get("layer", 0)) >= 6 else 0.0)
				logs.append(_strike(logic, u, t, skill, float(u.atk) * float(skill.coef) * mult, false))
		"red", "blue", "holy":
			var g: Dictionary = knight("death").gems
			if kind == "red":
				u.add_param(2, float(f.base.atk) * float(g.red))
			elif kind == "blue":
				u.add_param(3, float(f.base.def) * float(g.blue))
			else:
				var plus := float(f.base.hp) * float(g.holy)
				u.add_param(0, plus)
				u.hp += plus
			f.gems = int(f.gems) + 1
			f.unique = int(f.unique) + 1
			logs.append_array(_follow_up(logic, f, u))
		"holy_sword":
			var t = _pick_target(logic, chosen)
			for _n in range(int(skill.hits)):
				if t == null or not t.is_alive():
					t = _pick_target(logic, null)
				if t == null:
					break
				logs.append(_strike(logic, u, t, skill, float(u.atk) * float(skill.coef), false))
			f.sword_target = null
			f.unique = int(f.unique) + 1
			logs.append_array(_follow_up(logic, f, u))
		"finale":
			for t in _alive_actors(logic):
				logs.append(_strike(logic, u, t, skill, float(u.atk) * float(skill.coef), false))
			f.finale = 0
		"bash":
			var t = _pick_target(logic, chosen)
			if t != null:
				logs.append(_strike(logic, u, t, skill, float(u.atk) * (1.0 - float(knight("plague").self_atk_down)) * float(skill.coef), false))
		"fireworks", "bomb", "kindle", "wave", "crackle":
			logs.append_array(_war_perform(logic, f, u, skill, chosen))
		"sea", "landing", "bankrupt", "sword_rain":
			logs.append_array(_famine_perform(logic, f, u, skill, chosen))
	_check_kills(logic, f)
	logs.append_array(take_logs(logic))
	return logs


## 勇者：每放一次独有技能追加一次普攻
static func _follow_up(logic, f: Dictionary, u) -> Array:
	var t = _pick_target(logic, null)
	if t == null:
		return []
	return [_strike(logic, u, t, _skill("follow", "追加普攻", 1, 1, float(knight("death").follow_coef), false),
		float(u.atk) * float(knight("death").follow_coef), false)]


static func _war_perform(logic, f: Dictionary, u, skill: Dictionary, chosen) -> Array:
	var k := knight("war")
	var kind := str(skill.tianqi_horseman)
	var turn := int(logic.turn)
	var layer := int(f.layer)
	var logs := []
	var mat := float(u.mat)
	match kind:
		"fireworks":
			var over := maxi(0, int(f.sparks) - int(k.sparks.full))
			var mult := (1.0 + float(k.fireworks.over_per) * over) * (1.0 + (float(k.fireworks.fuse) if layer >= 4 else 0.0))
			f.sparks = int(f.sparks) - int(k.sparks.full)
			f.cd["fireworks"] = turn + int(k.fireworks.cooldown) + 1
			for _n in range(int(skill.hits)):
				for t in _alive_actors(logic):
					logs.append(_war_hit(logic, f, u, t, skill, mat * float(skill.coef) * mult, true, 0.0))
		"bomb":
			f.sparks = int(f.sparks) - int(k.bomb.cost)
			f.cd["bomb"] = turn + int(k.bomb.cooldown) + 1
			var mult := 1.0 + (float(k.bomb.special) if layer >= 3 else 0.0)
			var crit_up := float(k.bomb.special_crit) if layer >= 3 else 0.0
			var thunder: int = logic._int(1, int(k.bomb.rand_hits), "horseman_bomb")
			var hit_any := false
			for n in range(int(skill.hits) + thunder):
				var fire := n < int(skill.hits)
				for t in _alive_actors(logic):
					var r := _war_hit(logic, f, u, t, skill, mat * float(skill.coef) * mult, fire, crit_up)
					logs.append(r)
					hit_any = true
			if hit_any:
				f.fire_up = minf(float(k.bomb.fire_cap), float(f.fire_up) + float(k.bomb.fire_up))
				if layer >= 2:
					for t in _alive_actors(logic):
						var m := _mark(f, t)
						m.shrapnel = int(k.bomb.turns)
						m.mhp_down = minf(float(k.bomb.mhp_cap), float(m.get("mhp_down", 0.0)) + float(k.bomb.mhp_down))
		"kindle":
			f.sparks = int(f.sparks) + int(k.kindle.sparks)
			f.kindled = true
			f.cd["kindle"] = turn + int(k.kindle.cooldown) + 1
		"wave":
			f.kindled = false
			var mult := 1.0
			if int(f.sparks) > 0 and logic._float("horseman_wave") < float(k.wave.spark_chance):
				f.sparks = int(f.sparks) - 1
				mult = float(k.wave.spark_mult)
			for _n in range(int(skill.hits)):
				for t in _alive_actors(logic):
					logs.append(_war_hit(logic, f, u, t, skill, mat * float(skill.coef) * mult, true, 0.0))
			for t in _alive_actors(logic):
				_mark(f, t).burn = int(k.wave.turns)
		"crackle":
			var t = _pick_target(logic, chosen)
			for _n in range(int(skill.hits)):
				if t == null or not t.is_alive():
					t = _pick_target(logic, null)
				if t == null:
					break
				var rnd: int = logic._int(1, int(k.crackle.rand_hits), "horseman_crackle")
				logs.append(_war_hit(logic, f, u, t, skill, mat * float(skill.coef) * rnd, true, 0.0))
			f.sparks = int(f.sparks) + 1
	# 每次行动 +1 火花（炮火连天起 +3）
	f.sparks = int(f.sparks) + (int(k.sparks.barrage_per) if layer >= 6 else int(k.sparks.per_action))
	return logs


## 莉co一段：暴击 33%（×1.5）、火伤加成、碎甲后火雷伤害 +33%
static func _war_hit(logic, f: Dictionary, u, t, skill: Dictionary, base: float, fire: bool, crit_up: float) -> Dictionary:
	var k := knight("war")
	var crit: bool = logic._float("horseman_crit") < float(k.crit) + crit_up
	var v := base * (float(k.crit_mult) if crit else 1.0)
	if fire:
		v *= 1.0 + float(f.fire_up)
	if int(_mark(f, t).get("shrapnel", 0)) > 0:
		v *= 1.0 + float(k.bomb.resist_down)
	return _strike(logic, u, t, skill, v, crit)


static func _famine_perform(logic, f: Dictionary, u, skill: Dictionary, chosen) -> Array:
	var k := knight("famine")
	var kind := str(skill.tianqi_horseman)
	var logs := []
	# 资历：每层技能伤害 +3%，突破后翻倍；结党：吞同场一只小怪 50% 最大生命，这一次伤害 +33%
	var per := float(k.seniority.per) * (2.0 if bool(f.broke1) else 1.0)
	var mult := 1.0 + per * int(f.seniority)
	var food: Array = f.adds.filter(func(e): return e.is_alive())
	if not food.is_empty():
		var e = food[0]
		logs.append_array(_devour(logic, f, e))
		mult *= 1.0 + float(k.devour_up)
	var magical := kind in ["bankrupt", "sword_rain"]
	var power := float(u.mat) if magical else float(u.atk)
	var targets := []
	if int(skill.scope) == 2:
		targets = _alive_actors(logic)
	else:
		var t = _pick_target(logic, chosen)
		if t != null:
			targets = [t]
	if kind == "bankrupt" and not targets.is_empty():
		_mark(f, targets[0]).bankrupt = true
		_flush_params(logic)
	for _n in range(int(skill.hits)):
		for t in targets:
			if not t.is_alive():
				continue
			var r := _strike(logic, u, t, skill, power * float(skill.coef) * mult, false)
			logs.append(r)
			if bool(r.died):
				_seniority(logic, f, int(k.seniority.ko))
	for t in targets:
		var m := _mark(f, t)
		if kind in ["sea", "landing"]:
			m.seen = int(k.seen.turns)
		m.erase("bankrupt")
	_flush_params(logic)
	return logs


static func _devour(logic, f: Dictionary, e) -> Array:
	var logs := []
	var bite := floorf(float(e.mhp) * float(knight("famine").devour))
	_lose_hp(logic, e, bite, logs)
	if e.is_dead():
		f.down[e] = true
		_seniority(logic, f, int(knight("famine").seniority.kill))
		_say(f, "饿：又召来一只小怪。")
		_summon(logic, f, e)
	return logs


static func _seniority(logic, f: Dictionary, n: int) -> void:
	f.seniority = int(f.seniority) + n
	_say(f, "资历 %d 层。" % int(f.seniority))
	_check_phase(logic, f)


static func _pick_target(logic, chosen):
	if chosen != null and chosen is XBattler and chosen.is_alive() and logic.actors.has(chosen):
		return chosen
	var live := _alive_actors(logic)
	if live.is_empty():
		return null
	return live[logic._int(0, live.size() - 1, "horseman_target")]


## 骑士打我方一段：攻×系数×攻÷(攻＋防)×我方档位承伤，过护盾
static func hit_value(power: float, def: float, base: float, taken: float) -> float:
	var pass_rate := power / maxf(1.0, power + maxf(0.0, def))
	return floorf(maxf(0.0, base * pass_rate * taken))


static func _strike(logic, u, t, skill: Dictionary, base: float, critical: bool) -> Dictionary:
	var magical := bool(skill.get("magical", false))
	var power := float(u.mat) if magical else float(u.atk)
	var def := float(t.mdf) if magical else float(t.def)
	var taken := float(XTianqiCombat.taken_parts(t, logic.state).mult)
	return logic.horseman_strike(u, t, skill, hit_value(power, def, base, taken), critical)


static func _lose_hp(logic, t, n: float, logs: Array, through_shield := false) -> void:
	if n <= 0.0 or not t.is_alive():
		return
	var before: float = t.hp
	var v: float = n if through_shield else float(t.absorb_shield(n))
	if through_shield:
		t.shield = 0.0
	t.hp = maxf(0.0, t.hp - v)
	t.refresh_resources()
	logs.append({"type": "regen", "target": t, "hp": before - t.hp, "views": logic.views([t])})
	if t.is_dead():
		logic._die(t)
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})


## 倒下的结算：援军倒下给莉co火花（号令），我方倒下记饥荒资历另算；骑士倒下时援军、小怪一起散去
static func _check_kills(logic, f: Dictionary) -> void:
	for e in f.adds:
		if e.is_dead() and not f.down.has(e):
			f.down[e] = true
			if str(f.line) == "war":
				f.sparks = int(f.sparks) + int(knight("war").sparks.rally)
	if f.knight.is_dead():
		for e in f.adds:
			if e.is_alive():
				e.hp = 0.0
				e.refresh_resources()
				logic._die(e)
				f.queue.append({"type": "collapse", "target": e, "views": logic.views([e])})


## 我方一次行动结束（BattleLogic.act 末尾）：打过混子的人 +1 不服；援军倒下的号令
static func after_action(logic, u) -> Array:
	if not active(logic):
		return []
	var f := fight(logic)
	if str(f.line) == "plague" and u is XActor and bool(f.get("hit_knight", {}).get(u, false)):
		f.hit_knight.erase(u)
		_defiance(logic, f, u, 1)
	_check_kills(logic, f)
	_check_phase(logic, f)
	return take_logs(logic)


# ---- 挂钩（战斗外、别的模块里调） ----

## BattleLogic.execute_hp_damage：混子之盾累计、打混子的人记一笔；疫病让受到的治疗 −50%
static func hp_damage(logic, u, t, value: float) -> float:
	if not active(logic):
		return value
	var f := fight(logic)
	if value < 0.0 and t is XActor and _mark(f, t).get("plague", false):
		return value * (1.0 - float(knight("plague").plague.heal_down))
	if value > 0.0 and is_same(t, f.knight) and str(f.line) == "plague" and u is XActor:
		if not f.has("hit_knight"):
			f.hit_knight = {}
		f.hit_knight[u] = true
		_shield_hit(f, value, int(logic.turn))
	return value


## XTianqiCombat.damage_mult：打到骑士身上的倍率（混子自我修养减伤 11%，嘲讽在时再 −22%）
static func taken_mult(b) -> float:
	var logic = active_logic()
	if logic == null or not is_knight(logic, b):
		return 1.0
	var f := fight(logic)
	if str(f.line) != "plague":
		return 1.0
	var k := knight("plague")
	return (1.0 - float(k.self_reduce)) * ((1.0 - float(k.taunt_reduce)) if bool(f.taunt) else 1.0)


## BattleLogic.item_cri：勇者暴击免疫
static func crit_immune(dt) -> bool:
	var logic = active_logic()
	return logic != null and is_knight(logic, dt) and bool(knight(str(fight(logic).line)).get("crit_immune", false))


## BattleLogic.targets_for：混子嘲讽在时，我方打敌人的技能只能打混子
static func filter_targets(logic, a, list: Array) -> Array:
	if not active(logic) or not a is XActor:
		return list
	var f := fight(logic)
	if str(f.line) != "plague" or not bool(f.taunt) or not f.knight.is_alive():
		return list
	var out := []
	var any_foe := false
	for t in list:
		if t is XEnemy:
			any_foe = true
		else:
			out.append(t)
	if any_foe:
		out.append(f.knight)
	return out


## XEnemy.add_state：骑士免疫停手的控制和即死（生命没归零时挂不上死亡）
static func blocks_state(e, id: int) -> bool:
	if e == null or e.horseman.is_empty() or not bool(e.horseman.get("knight", false)):
		return false
	if id == 1:
		return e.hp > 0.0
	return XEnemy.boss_control_state(id)


## XBattler.remove_state(1)：死期死去的人本场不能复活
static func blocks_revive(b) -> bool:
	var logic = active_logic()
	return logic != null and b is XActor and bool(mark_of(logic, b).get("no_revive", false))


## XResourceContext.gain：绝粮下我方 MP、TP 在战斗中不能恢复
static func starved(b, resource: String, amount: float) -> bool:
	if amount <= 0.0 or not resource in ["mp", "tp"] or not b is XActor:
		return false
	var logic = active_logic()
	return logic != null and str(fight(logic).line) == "famine" and logic.actors.has(b)


## XActor.param：疫病、病弱（全属性）、识破和破产（防御）、碎甲（最大生命）
static func actor_param(a, i: int, v: float) -> float:
	if _logic_ref == null:
		return v
	var logic = active_logic()
	if logic == null:
		return v
	var f := fight(logic)
	var m: Dictionary = f.marks.get(a, {})
	if m.is_empty():
		return v
	var mult := 1.0
	if m.get("plague", false):
		var k := knight("plague")
		var debuffs := debuff_count(f, m)
		mult *= (1.0 - float(f.plague_down)) * (1.0 - minf(float(k.frail.cap), float(k.frail.per) * debuffs))
	if i == 3:
		if int(m.get("seen", 0)) > 0:
			mult *= 1.0 - float(knight("famine").seen.def_down)
		if m.get("bankrupt", false):
			mult *= 1.0 - float(knight("famine").bankrupt.def_down)
	if i == 0 and float(m.get("mhp_down", 0.0)) > 0.0:
		mult *= 1.0 - float(m.mhp_down)
	return roundf(v * mult) if mult != 1.0 else v


## 病弱数的减益：疫病、不服、嘲讽（混子在场且嘲讽着）、识破、破产、灼烧、碎甲
static func debuff_count(f: Dictionary, m: Dictionary) -> int:
	var n := 0
	n += 1 if m.get("plague", false) else 0
	n += 1 if int(m.get("defiance", 0)) > 0 else 0
	n += 1 if str(f.line) == "plague" and bool(f.get("taunt", false)) else 0
	for k in ["seen", "burn", "shrapnel"]:
		n += 1 if int(m.get(k, 0)) > 0 else 0
	n += 1 if m.get("bankrupt", false) else 0
	return n


static func _flush_params(logic) -> void:
	for a in logic.actors:
		a.param_mark_dirty()
