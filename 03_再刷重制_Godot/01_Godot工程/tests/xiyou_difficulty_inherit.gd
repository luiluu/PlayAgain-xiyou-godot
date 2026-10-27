extends Node
## 入队／读档／开战的难度继承（installNativeDifficultyInheritanceRuntime 的 syncActor／syncNativeTier）逐例对冻结 v0.28 参照 difficulty_inherit_oracle.json：
## 主角已学技能 × 难度开关 × 补强档开关 × 强弱者分档，对普通（<167）与新增（≥167）队员，比三种时机后各队员的难度类技能（track）与状态。
var checks := 0
var failures: Array = []
## 按时机拆场景（recruit／load／battle），各自不超过测试用时上限的一半
@export var only_mode := "recruit"
const LEADS := {
	"none": [], "base5547": [5547], "base5548": [5548, 5980], "base5561": [5561], "honghuang": [5564, 5980],
	"cls6216": [6216], "cls6235": [6235], "cls6216_5548": [6216, 5548, 5980], "tier5969": [5969], "tier5968": [5968],
	"tier5971_5972": [5971, 5972], "tier_all": [5969, 5971, 5973]}
const DIFFS := {"none": [], "d2492": [2492], "d2491": [2491], "d2494": [2494], "d2483": [2483], "d2500": [2500]}
const TIERS := {"none": [], "t2461": [2461], "t2462": [2462], "t2463": [2463], "t_all": [2461, 2462, 2463]}

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 200:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(400))

func profile(s: XState, spec: Dictionary) -> void:
	for sid in LEADS[spec.lead]:
		s.actor(1).learn_skill(int(sid))
	for sw in DIFFS[spec.diff]:
		s.set_switch(int(sw), true)
	for sw in TIERS[spec.tier]:
		s.set_switch(int(sw), true)

func fresh() -> XState:
	var s := XState.new_game(3, 1, [])
	s.random_master = XRandomStream.hex64(12345)
	return s

func run_case(c: Dictionary, track: Array) -> void:
	var spec: Dictionary = c.setup
	var ids: Array = spec.ids
	var s := fresh()
	match spec.mode:
		"recruit":
			profile(s, spec)
			for id in ids:
				s.add_actor(int(id))
		"load":
			for id in ids:
				s.add_actor(int(id))
			profile(s, spec)
			s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		"battle":
			for id in ids:
				s.add_actor(int(id))
			profile(s, spec)
			XBattleLogic.new().setup(4, s)
	for id in ids:
		var a := s.actor(int(id))
		var skills := track.filter(func(sid): return a.skill_ids.has(int(sid))).map(func(v): return int(v))
		var states := a.state_ids.duplicate()
		states.sort()
		var want: Dictionary = c.observed[str(int(id))]
		var got := {"skills": skills, "states": states}
		check("%s.a%d" % [c.id, id], JSON.stringify(got) == JSON.stringify({"skills": want.skills.map(func(v): return int(v)), "states": want.states.map(func(v): return int(v))}), [got, want])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/difficulty_inherit_oracle.json"))
	for c in fixture.cases:
		if c.setup.mode != only_mode:
			continue
		check(c.id + ".native", c.errors.is_empty())
		if c.errors.is_empty() and c.setup.mode == only_mode:
			run_case(c, fixture.track)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
