extends Node
## Star_Warehouse 难度倍率把敌人的 xparam 乘到 1.4～2.85 后的命中／闪避／暴击判定：
## 逐例对冻结 v0.28 参照 hit_warehouse_oracle.json（敌人打角色 1／角色 1 打敌人 × 技能 4 类 × 追加特征 6 组 × 标志 无／L2／L4／L5）。
## 原版量得：itemHit／itemCri 钳到 0～1，itemEva 恒 0；apply 里 随机数≥itemHit 为未命中，随机数<itemEva 为闪避，随机数<itemCri 为暴击。
var checks := 0
var failures: Array = []

## 在敌人数据外再挂几条 xparam 特征（code 22），对应探针里往内存敌人数据追加的特征。
class ExtraEnemy extends XEnemy:
	var extra: Array = []
	func trait_objects() -> Array:
		var out := super.trait_objects()
		out.append({"traits": extra.map(func(x): return {"code": 22, "dataId": int(x[0]), "value": float(x[1])})})
		return out

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 40:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(400))

func near(a, b) -> bool:
	return absf(float(a) - float(b)) <= 1e-5 * maxf(1.0, absf(float(b)))

func run_case(c: Dictionary, skills: Dictionary, logic: XBattleLogic, hero: XBattler) -> void:
	var spec: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := XState.current
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = spec.flags.any(func(f): return int(f) == i)
	var foe := ExtraEnemy.new()
	foe.extra = spec.extra
	foe.setup(int(o.enemyId), int(o.difficulty), 100.0)
	var sk: Dictionary = XDB.rec("Skills", int(skills[spec.skill]))
	var u: XBattler = foe if spec.pair == "enemy_actor" else hero
	var t: XBattler = hero if spec.pair == "enemy_actor" else foe
	var r: Dictionary = o.rates
	var hit := logic.item_hit(u, sk, t)
	var eva := logic.item_eva(u, sk, t)
	var cri := clampf(u.cri * (1.0 - t.cev), 0.0, 1.0)
	check(c.id + ".hit", near(hit, r.hit), [hit, r.hit])
	check(c.id + ".eva", near(eva, r.eva), [eva, r.eva])
	check(c.id + ".cri", near(cri, r.cri), [cri, r.cri])
	check(c.id + ".aHit", near(u.hit, r.aHit), [u.hit, r.aHit])
	check(c.id + ".aCri", near(u.cri, r.aCri), [u.cri, r.aCri])
	check(c.id + ".bEva", near(t.eva, r.bEva), [t.eva, r.bEva])
	check(c.id + ".bCev", near(t.cev, r.bCev), [t.cev, r.bCev])
	for res in o.results:
		var rnd := float(res.random)
		var missed := rnd >= hit
		var evaded := not missed and rnd < eva
		var crit := not missed and not evaded and rnd < cri
		check(c.id + ".r%s" % str(rnd), missed == bool(res.missed) and evaded == bool(res.evaded) and crit == bool(res.critical), [missed, evaded, crit, res])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hit_warehouse_oracle.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	var s := XState.new_game(int(fixture.cases[0].observed.difficulty), 1, [])
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var hero := s.actor(1)
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c, fixture.skills, logic, hero)
	logic.end_battle()
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
