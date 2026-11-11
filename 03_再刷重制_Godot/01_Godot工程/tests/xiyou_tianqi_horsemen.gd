extends Node
## 天启四骑士（XTianqiHorsemen）数值表专项：四骑士 Boss 数值稿 v0.4 第 2～5 节的五档表照实对、数字避开 4、开关。
## 一、五档生命、攻击（魔攻）：骑士单用的血量倍率 0.7／1.0／1.5／3.0／5.0，混子证道直接 288 万；攻击乘共用的敌人攻击倍率。
## 二、防御、魔防、行动次数五档一样；35 层影子、开场生存战的攻击成数。
## 三、战争的火药配方层数按血量；骑士打我方一段的公式。
## 四、开关：原版档、五档数值关掉、ENABLED 关掉、发行构建（天启篇未开放）都不开骑士战；prepare 不认的线不收。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _run() -> void:
	XMessageBox.auto = true
	_table()
	_shadow()
	_war_layers()
	_hit()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 数值稿 v0.4 第 2.5、3.5、4.5、5.5 节的五档表（生命、攻击；战争是魔攻）
const KEYS := ["xunchang", "jianxian", "jiusi", "lianyu", "zhengdao"]
const WANT := {
	"death": {"hp": [1554000, 2220000, 3330000, 6660000, 11100000], "atk": [79200, 99000, 123750, 148500, 178200]},
	"war": {"hp": [1400000, 2000000, 3000000, 6000000, 10000000], "mat": [31200, 39000, 48750, 58500, 70200]},
	"famine": {"hp": [1239000, 1770000, 2655000, 5310000, 8850000], "atk": [70400, 88000, 110000, 132000, 158400]},
	"plague": {"hp": [462000, 660000, 990000, 1980000, 2880000], "atk": [70400, 88000, 110000, 132000, 158400]},
}


func _table() -> void:
	_check("nice_numbers", XTianqiHorsemen.nice_number_violations().is_empty(), XTianqiHorsemen.nice_number_violations())
	_check("hp_rate_row", KEYS.map(func(k): return XTianqiHorsemen.hp_rate(k)) == [0.7, 1.0, 1.5, 3.0, 5.0])
	for line in WANT:
		var w: Dictionary = WANT[line]
		for i in KEYS.size():
			var st := XTianqiHorsemen.stats(line, KEYS[i])
			for col in w:
				_check("%s_%s_%s" % [line, KEYS[i], col], _near(float(st[col]), float(w[col][i])), [st[col], w[col][i]])
			# 防御、行动次数五档一样
			var base := XTianqiHorsemen.knight(line)
			_check("%s_%s_def" % [line, KEYS[i]], _near(float(st.def), float(base.def)) and int(st.actions) == 2)
	# 混子：证道不按 ×5（330 万），直接 288 万；自我修养后实际出手约 5.9 万
	_check("plague_override", _near(float(XTianqiHorsemen.stats("plague", "zhengdao").hp), 2880000.0))
	var p := XTianqiHorsemen.knight("plague")
	_check("plague_real_atk", absf(88000.0 * (1.0 - float(p.self_atk_down)) - 59000.0) < 100.0)
	# 勇者：魔防 0、敏捷 0、暴击免疫；莉co敏捷 1.33 倍；四位名字
	var d := XTianqiHorsemen.knight("death")
	_check("death_traits", float(d.mdf) == 0.0 and float(d.agi_rate) == 0.0 and bool(d.crit_immune))
	_check("war_agi", _near(float(XTianqiHorsemen.knight("war").agi_rate), 1.33))
	_check("names", ["death", "war", "famine", "plague"].map(func(l): return XTianqiHorsemen.stats(l, "jianxian").name)
		== ["死亡骑士·勇者", "战争骑士·莉co", "饥荒骑士·小镇做题家", "瘟疫骑士·混子"])
	# 死期间隔 5／3、漫天烟火冷却 2、援军一波 3 只最多 5 只、资历线 5／10、不服满 6 层
	_check("death_doom", int(d.doom.interval) == 5 and int(d.doom.phase_interval) == 3)
	var war := XTianqiHorsemen.knight("war")
	_check("war_rules", int(war.fireworks.cooldown) == 2 and int(war.reinforce.per_wave) == 3 and int(war.reinforce.max_adds) == 5)
	_check("famine_lines", XTianqiHorsemen.knight("famine").seniority.lines == [5, 10])
	_check("plague_defiance", int(p.defiance.full) == 6 and _near(float(p.plague.dot), 0.05) and _near(float(p.plague.down_cap), 0.33))
	_check("unknown", XTianqiHorsemen.stats("nope", "jianxian").is_empty() and XTianqiHorsemen.stats("war", "nope").is_empty())


func _shadow() -> void:
	# 35 层影子：生命 167 万 × 本档敌人血量；攻击按本体几成（死亡 5 成、饥荒 9 成）
	var sh := XTianqiHorsemen.shadow_stats("death", "jianxian")
	_check("shadow_death", _near(float(sh.hp), 1670000.0) and _near(float(sh.atk), 49500.0) and int(sh.actions) == 1, sh)
	var sh2 := XTianqiHorsemen.shadow_stats("famine", "jiusi")
	_check("shadow_famine", _near(float(sh2.hp), 2505000.0) and _near(float(sh2.atk), 99000.0), sh2)
	# 生存战：攻击是本体的 1 成
	var sv := XTianqiHorsemen.survival_stats("war", "jianxian")
	_check("survival_war", _near(float(sv.mat), 3900.0), sv)


func _war_layers() -> void:
	var want := {1.0: 1, 0.9: 1, 0.83: 2, 0.7: 2, 0.66: 3, 0.5: 4, 0.4: 4, 0.33: 5, 0.2: 5, 0.16: 6, 0.05: 6}
	for r in want:
		_check("war_layer_%s" % str(r), XTianqiHorsemen.war_layer(float(r)) == int(want[r]), [r, XTianqiHorsemen.war_layer(float(r))])


func _hit() -> void:
	# 攻 9.9 万打防 1.1 万：通过率 0.9，系数 1.0，不减伤 → 8.91 万；超强者承伤 −30%
	_check("hit_value", _near(XTianqiHorsemen.hit_value(99000.0, 11000.0, 99000.0, 1.0), 89100.0))
	_check("hit_value_taken", _near(XTianqiHorsemen.hit_value(99000.0, 11000.0, 99000.0, 0.7), floorf(89100.0 * 0.7)))
	_check("hit_value_zero_def", _near(XTianqiHorsemen.hit_value(1000.0, 0.0, 500.0, 1.0), 500.0))


func _state(key: String) -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var s := XTianqi.start_new_game(3, key, w.slice(0, 5))
	XTianqi.take_pending()
	XState.current = s
	return s


func _switches() -> void:
	var s := _state("jianxian")
	_check("allowed", XTianqiHorsemen.allowed(s))
	_check("prepare_ok", XTianqiHorsemen.prepare("war", s) and XTianqiHorsemen.pending() == "war")
	_check("prepare_bad_line", not XTianqiHorsemen.prepare("nope", s) and XTianqiHorsemen.pending() == "")
	XTianqiHorsemen.ENABLED = false
	_check("off_switch", not XTianqiHorsemen.allowed(s) and not XTianqiHorsemen.prepare("war", s))
	XTianqiHorsemen.ENABLED = true
	XTianqiCombat.ENABLED = false
	_check("off_numbers", not XTianqiHorsemen.allowed(s))
	XTianqiCombat.ENABLED = true
	# 发行构建：RELEASE_OPEN 关着不开，打开才开
	ReleaseEntry.simulate_release = true
	var was := XTianqi.RELEASE_OPEN
	XTianqi.RELEASE_OPEN = false
	_check("release_closed", not XTianqiHorsemen.allowed(s) and not XTianqiHorsemen.prepare("death", s))
	XTianqi.RELEASE_OPEN = true
	_check("release_open", XTianqiHorsemen.allowed(s))
	XTianqi.RELEASE_OPEN = was
	ReleaseEntry.simulate_release = false
	# 原版档
	var plain := XState.new_game_blank()
	XState.current = plain
	_check("plain_save", not XTianqiHorsemen.allowed(plain) and not XTianqiHorsemen.prepare("plague", plain))
	XTianqiHorsemen.prepare("nope")
