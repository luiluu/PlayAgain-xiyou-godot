extends Node
## 天启篇档位与五档难度数值表（XTianqiBalance，tianqi_data/balance_table.json）的规则自检：
## 一、三档位、五难度齐全；难度键、顺序、super_cap、min_weak 与 XTianqi.DIFFICULTIES 一致，候选池与它的 pool() 规则一致。
## 二、档位单调：出伤 弱 < 强 < 超强，承伤 弱 ≥ 强 ≥ 超强。
## 三、档位盖过本体 ±20%：0.8×强者出伤倍率 ≥ 1.2×弱者，0.8×超强者 > 1.2×强者。
## 四、协力不让弱者多的队更强：4 人上场，三弱一强 < 二弱二强 < 一弱三强、四弱 < 三弱一强（出伤）；承伤反过来；换上超强者也一样。
## 五、难度单调：敌人血量、攻击从寻常到证道不降；寻常、艰险候选池没有超强者、上限 0。
## 六、数值好看：表里设计数值不含 4（豁免键写在表头）。
## 和设计仓库 参数.json 的逐项对照在 03_转换工具/天启篇数据校验.py --params（游戏仓库里没有参数.json）。
## 不用转换产物，不建存档。

const EPS := 1e-9

var results: Array = []


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


func _run() -> void:
	XTianqiBalance.reload()
	_complete()
	_tiers()
	_assist()
	_difficulties()
	_nice()
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _complete() -> void:
	var d := XTianqiBalance.data()
	_check("表能读", not d.is_empty())
	_check("表头 version／source／dev", d.has("version") and str(d.get("source", "")) != "" and str(d.get("dev", "")) != "", [d.get("version"), d.get("dev")])
	for t in XTianqiBalance.tier_names():
		var row := XTianqiBalance.tier(t)
		_check("档位齐全：" + t, row.has("damage_dealt") and row.has("damage_taken") and row.has("secret_cap"), row)
	_check("档位只有三个", d.get("tiers", {}).size() == 3, d.get("tiers", {}).keys())
	var want: Array = XTianqi.DIFFICULTIES.map(func(x): return x.key)
	_check("难度键与顺序同 XTianqi.DIFFICULTIES", XTianqiBalance.difficulty_keys() == want, [XTianqiBalance.difficulty_keys(), want])
	for x in XTianqi.DIFFICULTIES:
		var row := XTianqiBalance.difficulty(x.key)
		_check("难度名同开局：" + x.key, row.get("name", "") == x.name, row.get("name"))
		_check("super_cap 同开局：" + x.key, row.get("super_cap", -1) == int(x.super_cap), [row.get("super_cap"), x.super_cap])
		_check("min_weak 同开局：" + x.key, row.get("min_weak", -1) == int(x.min_weak), [row.get("min_weak"), x.min_weak])
		# XTianqi.pool：超强者上限 > 0 才进候选池
		var pool_want := [XTier.WEAK, XTier.STRONG] + ([XTier.SUPER] if int(x.super_cap) > 0 else [])
		_check("候选池同开局规则：" + x.key, row.get("pool", []) == pool_want, [row.get("pool"), pool_want])
		for k in ["enemy_hp", "enemy_atk", "party_damage", "quality_offset"]:
			_check("难度有 %s：%s" % [k, x.key], row.has(k))
	_check("没有的难度键返回空", XTianqiBalance.difficulty("nope").is_empty() and XTianqiBalance.tier("nope").is_empty())


func _tiers() -> void:
	var w := XTianqiBalance.tier_damage_mult(XTier.WEAK)
	var s := XTianqiBalance.tier_damage_mult(XTier.STRONG)
	var u := XTianqiBalance.tier_damage_mult(XTier.SUPER)
	_check("出伤 弱 < 强 < 超强", w < s and s < u, [w, s, u])
	var tw := XTianqiBalance.tier_taken_mult(XTier.WEAK)
	var ts := XTianqiBalance.tier_taken_mult(XTier.STRONG)
	var tu := XTianqiBalance.tier_taken_mult(XTier.SUPER)
	_check("承伤 弱 ≥ 强 ≥ 超强", tw >= ts and ts >= tu, [tw, ts, tu])
	_check("秘籍上限 弱 ≥ 强 ≥ 超强", XTianqiBalance.secret_cap(XTier.WEAK) >= XTianqiBalance.secret_cap(XTier.STRONG)
		and XTianqiBalance.secret_cap(XTier.STRONG) >= XTianqiBalance.secret_cap(XTier.SUPER))
	_check("档位盖过本体 ±20%（强者对弱者）", 0.8 * s >= 1.2 * w - EPS, [0.8 * s, 1.2 * w])
	_check("档位盖过本体 ±20%（超强者对强者）", 0.8 * u > 1.2 * s + EPS, [0.8 * u, 1.2 * s])


func _team(weak: int, other: String) -> Array:
	var out := []
	for i in XTianqiBalance.FIELD_SIZE:
		out.append(XTier.WEAK if i < weak else other)
	return out


func _assist() -> void:
	var a0 := XTianqiBalance.assist_bonus(0)
	_check("没有弱者没有协力", is_zero_approx(a0.damage_dealt) and is_zero_approx(a0.damage_taken), a0)
	var a1 := XTianqiBalance.assist_bonus(1)
	_check("协力给出伤、减承伤", a1.damage_dealt > 0 and a1.damage_taken < 0, a1)
	_check("协力按上场人数封顶", XTianqiBalance.assist_bonus(XTianqiBalance.FIELD_SIZE + 3) == XTianqiBalance.assist_bonus(XTianqiBalance.FIELD_SIZE))
	var aura := XTianqiBalance.assist_slot_aura()
	_check("助力位光环在 0～1 之间", aura > 0 and aura < 1, aura)
	for other in [XTier.STRONG, XTier.SUPER]:
		for weak in range(XTianqiBalance.FIELD_SIZE, 0, -1):
			var more := _team(weak, other)
			var less := _team(weak - 1, other)
			var dm := XTianqiBalance.team_damage(more)
			var dl := XTianqiBalance.team_damage(less)
			_check("协力：%d弱 出伤低于 %d弱（换%s）" % [weak, weak - 1, other], dm < dl - EPS, [dm, dl])
			var tm := XTianqiBalance.team_taken(more)
			var tl := XTianqiBalance.team_taken(less)
			_check("协力：%d弱 承伤高于 %d弱（换%s）" % [weak, weak - 1, other], tm > tl + EPS, [tm, tl])


func _difficulties() -> void:
	var keys := XTianqiBalance.difficulty_keys()
	for i in range(1, keys.size()):
		var a := XTianqiBalance.difficulty(keys[i - 1])
		var b := XTianqiBalance.difficulty(keys[i])
		_check("敌人血量不降：%s→%s" % [a.key, b.key], b.enemy_hp >= a.enemy_hp, [a.enemy_hp, b.enemy_hp])
		_check("敌人攻击不降：%s→%s" % [a.key, b.key], b.enemy_atk >= a.enemy_atk, [a.enemy_atk, b.enemy_atk])
	for k in ["xunchang", "jianxian"]:
		var d := XTianqiBalance.difficulty(k)
		_check("低难度候选池没有超强者：" + k, not d.get("pool", []).has(XTier.SUPER) and d.get("super_cap", -1) == 0, d)


func _nice() -> void:
	var bad := XTianqiBalance.nice_number_violations()
	_check("设计数值不含 4", bad.is_empty(), bad)
	_check("豁免键只放个数类", XTianqiBalance.data().get("nice_number_exempt", []).all(
		func(k): return k in ["version", "secret_cap", "super_cap", "min_weak"]))
