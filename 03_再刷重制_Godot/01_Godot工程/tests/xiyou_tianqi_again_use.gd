extends Node
## 天启篇改写技能的「再释放」接通（T063，Kyo D124=B；开关 XBattleLogic.TIANQI_AGAIN）：
## 一、改写稿 note_add 写了 AgainUse 的正好 22 处（20 个技能＋armor:3670、weapon:2021），技能卡开时改写后的记录里真有这个标签、说明写着再释放。
## 二、每一处都生效：学了这招（或装上这件）的角色，again_use 几率与改写稿一致；按类型（All／Mf）分、掷在边界上（roll×100 < 几率）。
## 三、只认改写稿新写的：原版留下的再释放（7190 时之主宰 100%、改写里没去掉的 7457 精灵至血 32%）、atkk（1817）天启篇照旧不读；
##     技能卡关、开关关、敌人、心钢 10227 不加。
## 四、实战 execute：198 雪山飞狐（药水）、826 倾国倾城（普攻）、2030 怨咒（魔法）掷中时多打一轮、没掷中照旧；
##     预算先用掉（take_extra 已经 false）照样再放，execute 前后回合预算的记录、再释放计数、extra_used 都不变（不占 take_extra）。
## 五、固定种子下真随机数：198 掷 400 次，触发率在 10% 附近（5%～15%）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit

## 22 处：改写稿里的几率（armor:3670 是 5%）
const EXPECT := {
	198: ["AgainUseAll", 10], 3593: ["AgainUseAll", 10], 826: ["AgainUseAll", 10], 5483: ["AgainUseAll", 10],
	4924: ["AgainUseAll", 10], 2030: ["AgainUseMf", 10], 5477: ["AgainUseAll", 10], 6011: ["AgainUseAll", 10],
	5522: ["AgainUseAll", 10], 5162: ["AgainUseAll", 10], 5506: ["AgainUseAll", 10], 2727: ["AgainUseMf", 10],
	3751: ["AgainUseAll", 10], 3732: ["AgainUseMf", 10], 4948: ["AgainUseAll", 10], 7477: ["AgainUseAll", 10],
	7054: ["AgainUseAll", 10], 7070: ["AgainUseAll", 10], 7046: ["AgainUseAll", 10], 10137: ["AgainUseMf", 10],
	"armor:3670": ["AgainUseAll", 5], "weapon:2021": ["AgainUseAll", 10],
}
const ATTACK := 1
const WAR := 9  # 战技 stypeId 1
const MAGIC := 51  # 魔法 stypeId 2


## 只把再释放这一路的随机数换成定值（roll < 0 时照走真随机数），别的照原样
class RollLogic extends XBattleLogic:
	var roll := -1.0
	func _float(reason: String) -> float:
		if reason == "again_use" and roll >= 0.0:
			return roll
		return super._float(reason)


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state() -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_again_use")
	seed(20261116)
	XTianqiSkills.reload()
	XTianqiSkills.CARDS = true
	_table()
	_each()
	_scope()
	_execute()
	_seeded()
	XTianqiSkills.CARDS = false
	XBattleLogic.TIANQI_AGAIN = true
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(3000))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、22 处 ----
func _table() -> void:
	_state()
	var tab := XTianqiSkills._again_table().duplicate()
	tab.erase("")
	var keys := tab.keys().map(func(k): return str(k))
	keys.sort()
	var want := EXPECT.keys().map(func(k): return str(k))
	want.sort()
	_check("table_is_the_22", keys == want, [keys.size(), keys])
	var bad := []
	for k in EXPECT:
		if k is int:
			var r := XDB.rec("Skills", k)
			var desc := str(r.get("description", "")) + str(r.get("note", ""))
			if not (r.get("meta", {}) as Dictionary).has(EXPECT[k][0]) or not desc.contains("再"):
				bad.append(k)
	_check("rec_meta_has_tag", bad.is_empty(), bad)


# ---- 二、每一处 ----
func _each() -> void:
	var L := RollLogic.new()
	var atk := XDB.rec("Skills", ATTACK)
	var war := XDB.rec("Skills", WAR)
	var mag := XDB.rec("Skills", MAGIC)
	_check("probe_skill_types", int(war.stypeId) == 1 and int(mag.stypeId) == 2, [war.stypeId, mag.stypeId])
	var bad := []
	for k in EXPECT:
		var s := _state()
		var a := s.actor(int(s.battle_slots[0]))
		if k is int:
			a.learn_skill(k)
		else:
			var kind := str(k).split(":")[0]
			var item := XGear.create(kind, int(str(k).split(":")[1]), s)
			var slot := 0 if kind == "weapon" else a.equip_slots().find(int(item.etypeId))
			a.equips[slot] = item
		a.refresh_passive()
		var rate := int(EXPECT[k][1])
		var mf := str(EXPECT[k][0]) == "AgainUseMf"
		var got := {"war": XTianqiSkills.again_use(a, war), "mag": XTianqiSkills.again_use(a, mag), "atk": XTianqiSkills.again_use(a, atk)}
		var want := {"war": 0 if mf else rate, "mag": rate, "atk": 0 if mf else rate}
		# 边界：roll×100 < 几率 才 +1
		L.roll = (rate - 0.01) / 100.0
		var hit := L.passive_repeats(a, mag, 1)
		L.roll = rate / 100.0
		var miss := L.passive_repeats(a, mag, 1)
		L.roll = 0.0
		var war_n := L.passive_repeats(a, war, 1)
		if got != want or hit != 2 or miss != 1 or war_n != (1 if mf else 2):
			bad.append({"k": k, "got": got, "want": want, "hit": hit, "miss": miss, "war": war_n})
	_check("each_of_22_rolls", bad.is_empty(), bad)


# ---- 三、只认改写稿 ----
func _scope() -> void:
	var L := RollLogic.new()
	L.roll = 0.0
	var war := XDB.rec("Skills", WAR)
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	for id in [7190, 7457, 1817]:
		a.learn_skill(id)
	a.refresh_passive()
	_check("original_tags_not_read", XTianqiSkills.again_use(a, war) == 0 and L.passive_repeats(a, war, 1) == 1, L.passive_repeats(a, war, 1))
	a.learn_skill(198)
	a.refresh_passive()
	_check("rework_tag_read", L.passive_repeats(a, war, 1) == 2)
	_check("heartsteel_skipped", L.passive_repeats(a, XDB.rec("Skills", XHeartsteel.SKILL), 1) == 1 and L.passive_repeats(a, XDB.rec("Skills", XHeartsteel.LEV_SKILL), 1) == 1)
	XBattleLogic.TIANQI_AGAIN = false
	_check("switch_off", L.passive_repeats(a, war, 1) == 1)
	XBattleLogic.TIANQI_AGAIN = true
	XTianqiSkills.CARDS = false
	_check("cards_off", XTianqiSkills.again_use(a, war) == 0 and L.passive_repeats(a, war, 1) == 1)
	XTianqiSkills.CARDS = true
	var e := XEnemy.new().setup(1, 3)
	_check("enemy_untouched", L.passive_repeats(e, war, 1) == 1)
	# 西游档不读改写稿（198 原版标签另算：西游档走 passive_again，这里只看 again_use）
	XState.current.flags.erase("tianqi")
	_check("xiyou_no_rework", not XTianqiLedger.active() and XTianqiSkills.again_use(a, war) == 0)


# ---- 四、实战 ----
func _hits(logs: Array, t) -> int:
	return logs.filter(func(l): return str(l.get("type", "")) == "hit" and l.get("target") == t).size()


## 学 id、用 how（"potion" 对自己用药水；否则对敌人用这招）出手一次；返回 [命中数, 预算记录前后是否一样, take_extra 已用完]
func _act(id: int, how, roll: float) -> Dictionary:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	a.learn_skill(id)
	a.refresh_passive()
	var L := RollLogic.new()
	L.roll = roll
	L.elite_roll = 100.0
	L.setup(2, s)
	for e in L.enemies:
		e.hp = e.mhp
	# 先把这回合多 1 次的预算用掉：再释放照样放才算「不占预算」
	var used := XTianqiLedger.take_extra(L, a, "test.prefill", true) and not XTianqiLedger.take_extra(L, a, "test.prefill2", true)
	var before := JSON.stringify(XTianqiLedger._budget(L))
	var extra_before := XTianqiLedger.extra_used(L, a)
	var logs: Array
	var target
	if how is String and how == "potion":
		s.gain_item(1, 3)
		a.hp = 1.0
		target = a
		logs = L.execute(a, XDB.rec("Items", 1), a)
	else:
		var sk := XDB.rec("Skills", int(how))
		a.mp = a.mmp
		a.tp = 100
		target = L.enemies[0]
		logs = L.execute(a, sk, target)
	var after := JSON.stringify(XTianqiLedger._budget(L))
	var out := {"hits": _hits(logs, target), "budget_same": before == after and XTianqiLedger.extra_used(L, a) == extra_before,
		"budget_on": XTianqiLedger.budget_on(L, a), "prefilled": used}
	L.end_battle()
	return out


func _execute() -> void:
	var rows := {}
	var ok := true
	for c in [[198, "potion"], [826, ATTACK], [2030, MAGIC]]:
		var on := _act(int(c[0]), c[1], 0.05)
		var off := _act(int(c[0]), c[1], 0.5)
		rows[c[0]] = [on, off]
		ok = ok and int(off.hits) >= 1 and int(on.hits) == 2 * int(off.hits) and on.budget_same and on.budget_on and on.prefilled
	_check("execute_recasts_free_of_budget", ok, rows)
	# 怨咒是魔法再释放：普攻不加
	var war := _act(2030, ATTACK, 0.05)
	var war_off := _act(2030, ATTACK, 0.5)
	_check("execute_mf_not_on_attack", int(war.hits) == int(war_off.hits) and int(war.hits) >= 1, [war, war_off])


# ---- 五、真随机数 ----
func _seeded() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	a.learn_skill(198)
	a.refresh_passive()
	var L := RollLogic.new()
	L.setup(2, s)
	var war := XDB.rec("Skills", WAR)
	var n := 0
	for i in 400:
		n += L.passive_repeats(a, war, 1) - 1
	L.end_battle()
	_check("seeded_rate_near_10pct", n >= 20 and n <= 60, n)
