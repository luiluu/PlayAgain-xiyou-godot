extends Node
## 【cc·T082】期四实机标定 K（基础数值重构 v0.4 第九节第 1～3 步）：总开关开着，每人单独对木桩打自己「条件全中后最大的一段」，取暴击里最大的一个伤害数字。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/k_calibrate.tscn -- \
##     [--tier=super|strong|weak|all] [--k=<K，缺省读表>] [--hits=20] [--out=<json>] [--actors=1,2] [--single]
##
## 口径（稿第三节第 3 条，能做到的）：
## - 81 级；每栏从原版装备里挑主属性最高的一件（不限品质、不要专属），实例改成 80 级神话（meta req_level 80、quality 14）→ 新底子按表算；
##   本人专属法宝（没有就破攻／尊魔）99 级；技能熟练度拿满（MASTERY 开）；喝天平酒、助力位空、只上这一个人。
## - 木桩：这一场第一个敌人，物防魔防都改成 8200，每下之前回满；强制暴击（XStateEffects.force_critical）。
## - D195（Kyo 11-18，T175）：口径＝一次施放的总伤害（每段先封单段上限再相加）＝下面的峰值单段 × 整次施放实测的「各段合计÷最大一段」（_cast_ratio，每遍新开一场，3 遍取中位；--single 回到旧口径）。
## - 「这一下」：卡上每个伤害技能各打 hits 次，取最大的一个数；条件全中靠换算——同一下里卡面公式值 v0（XTianqiSkills.formula，含当下的条件）
##   和条件全中的值 v_full（卡面系数×Σ权重×各条件最大倍率，封到档位上限，口径同 天启篇数据校验.py single_hit_effective）都是线性乘在后面所有乘区前面的，
##   所以 峰值 ＝ 量到的数 × v_full ÷ v0。
## - 没做到的（报告里列着，交付单写差多少）：词条掷满挑最大、黑印满配攒五层、真印无视防御、秘籍格、号卷——这几样都进伤害池；烙印 100% 按 ×(1＋max_bonus) 乘在结果上（XTianqiBrand 开关现在关着）。
## 输出：每人一行（技能、量到的最大数、v0、v_full、峰值），再按档位取最大、中位。

const LEVEL := 81
const FABAO := 99
## --level=<L>（T163 量成长曲线）：角色 L 级，装备按 min(80, L−1) 级神话，法宝按 99×L÷81 级；缺省 81／80／99（甲档口径）
static var level := LEVEL
static var gear_level := 80
static var fabao_level := FABAO
const GENERAL_ATK := 3557
const GENERAL_MAT := 3556
const TROOP := 4  # 缺省敌群；_measure 里会往后找第一个「不是守层者、不是首领」的敌人（天启篇元素牌对它恒中性）
const DEF := 8200.0
const MYTH_QUALITY := "14"

var tier_arg := "super"
var k_arg := -1.0
var hits := 20
var out_path := ""
var only: Array = []
var debug := false
var no_advance := false  # --no-advance：不进阶（T163 前的口径，对照用）
var single := false  # --single：D195 前的口径（一次施放里跳出来最大的一个数），对照用
const CAST_RUNS := 3  # D195：每招整次施放几遍，取段数比（合计÷最大段）的中位
var per_skill := false  # --per-skill：每招打印一行（T163 查模块角色的大招有没有量到）
var mastery_seen := 0
var no_mastery := false
var no_fabao := false
var bare := false  # --bare：不补甲档五样（回到 v3 口径，对照用）
var trumpet_n := 2  # 号卷：七卷里打单体加伤害的只有二号血海（目标生命低于 33% +50%）；条件全中＝木桩生命压到 30%
var report := {}
## T204＋T209：停用中但要进量表的超强者（152 徐凤年）
const PROBE_ENABLE := [152]
## T209（协调 11-18）：成长型角色按标定点的成长量量，不是 0 也不是无穷——108 奈叶适应击杀次数（--nanoha-kills=N，缺省 2000＝软上限起点）、
## 179 流萤余烬（天启篇封顶 3000，--ember=N）；167 渡鸦灵魂在条件里按满算（cond_max），天启篇封顶 15 万／20 万
var nanoha_kills := 2000
var ember := 3000.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier_arg = a.substr(7)
		elif a.begins_with("--k="):
			k_arg = float(a.substr(4))
		elif a.begins_with("--hits="):
			hits = int(a.substr(7))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--no-fabao":
			no_fabao = true
		elif a == "--no-fabao-table":  # T163：法宝不读表（XTianqiGear.FABAO_TABLE 关，对照用）
			XTianqiGear.FABAO_TABLE = false
		elif a == "--no-mastery":
			no_mastery = true
		elif a == "--bare":
			bare = true
		elif a == "--no-advance":
			no_advance = true
		elif a.begins_with("--level="):
			level = clampi(int(a.substr(8)), 1, LEVEL)
			gear_level = mini(80, maxi(1, level - 1))
			fabao_level = mini(FABAO, roundi(FABAO * level / float(LEVEL)))
		elif a == "--no-tune":  # T163：D189 逐个调角色的覆盖层关掉（改前对照、量成长曲线用）
			XTianqiBase.TUNE_D189 = false
		elif a == "--no-d198":  # T192：只关 D198（偏弱超强者调高）覆盖层，改前对照用
			XTianqiBase.TUNE_D198 = false
		elif a == "--no-d208":  # T204：只关 D208（宿傩终式按段）覆盖层，改前对照用
			XTianqiBase.TUNE_D208 = false
		elif a == "--no-d209":  # T204＋T209：只关 D209（超强者按名次重排）覆盖层，改前对照用
			XTianqiBase.TUNE_D209 = false
		elif a.begins_with("--nanoha-kills="):
			nanoha_kills = maxi(0, int(a.substr(15)))
		elif a.begins_with("--ember="):
			ember = maxf(0.0, float(a.substr(8)))
		elif a == "--single":
			single = true
		elif a == "--debug-cast":
			_debug_cast = true
		elif a == "--per-skill":
			per_skill = true
		elif a == "--debug":
			debug = true
		elif a.begins_with("--actors="):
			only = Array(a.substr(9).split(",")).map(func(x): return int(x))
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	var rules: Dictionary = XTianqiBalance.data().get("combat_rules", {})
	if k_arg > 0.0:
		rules["base_damage"] = k_arg
	report = {"k": float(rules.get("base_damage", 1.0)), "hits": hits, "tune_d189": XTianqiBase.TUNE_D189, "tune_d198": XTianqiBase.TUNE_D198, "tune_d208": XTianqiBase.TUNE_D208, "tune_d209": XTianqiBase.TUNE_D209, "level": level, "gear_level": gear_level, "fabao_level": fabao_level, "def": DEF, "rows": [], "tiers": {},
		"brand_max_bonus": float(XTianqiBrand.data().get("power", {}).get("max_bonus", 0.5)),
		"caps": XTianqiSkills.data().get("rules", {}).get("single_hit_cap", {}),
		"build": "bare" if bare else "full", "metric": "single" if single else "cast_total",
		"missing": (["词条掷满挑最大", "黑印满配攒五层", "真印无视防御", "秘籍格", "号卷"] if bare else []) + ["烙印（XTianqiBrand 关着＝烙印 0；锚临时取 200 万＝300 万÷1.50，稿第九节第 3 条）"]}
	var tiers := [XTier.SUPER, XTier.STRONG, XTier.WEAK] if tier_arg == "all" else [{"super": XTier.SUPER, "strong": XTier.STRONG, "weak": XTier.WEAK}[tier_arg]]
	# T204＋T209（协调 11-18）：超强者 18 人都要进量表——152 徐凤年（停用中）走 probe_enabled、180 五条悟（天启篇专属、要解锁最强之名）临时当已解锁；量完还原
	var probe_was: Array = XImportedBalance.probe_enabled.duplicate()
	var gojo_was := XGojo.unlock_override
	XImportedBalance.probe_enabled = probe_was + PROBE_ENABLE
	XGojo.unlock_override = 1
	for tier in tiers:
		var peaks := []
		for id in XTianqiSkills.ids(tier, true):
			if not only.is_empty() and not only.has(int(id)):
				continue
			if XImportedBalance.is_disabled_actor(int(id)) and int(id) != XGojo.ACTOR:  # 五条悟的 hidden 看「当前存档」，_state 之前可能还不是天启篇档
				print("K_SKIP %d disabled" % int(id))
				continue
			var row := _measure(int(id), tier)
			if row.is_empty():
				print("K_SKIP %d no_damage_row" % int(id))  # 量不出伤害（如 175 谷雨全是治疗）
				continue
			row["tier"] = tier
			report.rows.append(row)
			peaks.append(float(row.peak))
			print("K_ROW %s" % JSON.stringify(row))
		peaks.sort()
		if not peaks.is_empty():
			report.tiers[tier] = {"n": peaks.size(), "max": peaks[-1], "median": peaks[peaks.size() / 2],
				"max_brand": peaks[-1] * (1.0 + float(report.brand_max_bonus))}
	XImportedBalance.probe_enabled = probe_was
	XGojo.unlock_override = gojo_was
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	report["mastery_max_level_seen"] = mastery_seen
	print("K_REPORT " + JSON.stringify(report.tiers) + " mastery=" + str(mastery_seen))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)  # 相对路径按 Godot 的工作目录算，写不出时报错（T204：用绝对路径）
		if f == null:
			push_error("K 探针写不出 %s（%s）；--out 用绝对路径" % [out_path, FileAccess.get_open_error()])
		else:
			f.store_string(JSON.stringify(report, " "))
	get_tree().quit.call_deferred(0)


## T209：成长型角色的标定点成长量（见 nanoha_kills、ember）
func _growth(s: XState, a) -> void:
	if int(a.actor_id) == 108:
		for i in nanoha_kills:
			XNanoha.adapt(a)
		report["nanoha_kills"] = nanoha_kills
	elif XLiuying.own(a):
		a.state_data["_codexLbEmber"] = ember
		a.state_data["_codexLbEmberWins"] = 0.0
		report["ember"] = ember
	a.param_mark_dirty()


## 条件「成立到最大」的倍率（同 天启篇数据校验.py cond_max）
static func cond_max(c: Dictionary) -> float:
	var i := str(c.get("if", ""))
	if i == "self_mp_frac":
		return minf(1.0, float(c.get("cap", 1.0)))
	var m := 1.0
	if c.has("steps"):
		for st in c.steps:
			m = maxf(m, float(st[1]))
	elif c.has("mult"):
		m = float(c.mult)
	elif c.has("cap"):
		var cap := float(c.cap)
		for v in c.get("cap_with", {}).values():
			cap = maxf(cap, float(v))
		m = 1.0 + cap
	return maxf(1.0, m)


## 条件全中的单段有效系数（不封）
static func eff_full(actor_id: int, sid: int) -> float:
	var d: Dictionary = XTianqiSkills.spec(sid).get("damage", {})
	var m := 1.0
	for c in d.get("conds", []):
		m *= cond_max(c)
	for c in XTianqiSkills.data().get("actors", {}).get(str(actor_id), {}).get("conds", []):
		if c.has("skills") and not (c.skills as Array).any(func(x): return int(x) == sid):
			continue
		m *= cond_max(c)
	return float(d.get("coef", 0.0)) * XTianqiSkills.hit_weight(d) * m


func _state(id: int) -> XState:
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), id, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [id]}
	s.random_master = XRandomStream.hex64(20261117 + id)
	seed(20261117 + id)
	s.set_variable(20, 36)
	s.actor_max_level = level
	XTianqiSkills.MASTERY = true  # 翻开关后熟练度和总开关一起开（稿第七节第 2 条）；开局流程会把它拨回默认值，这里再置一次
	XState.current = s  # 熟练度上限（XTianqiSkills.mastery_on）、装备读表都看当前存档
	if not s.party.has(id):
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	for i in 5:
		s.set_battle_slot(i, id if i == 0 else 0)
	var a := s.actor(id)
	a.change_level_mv(level)
	if not no_advance:
		_advance_max(s, a)
	_dress(a)
	_growth(s, a)
	var fid := _own_fabao(id)
	if fid == 0:
		var mw := main_weights(a)
		fid = GENERAL_ATK if float(mw.get("atk", 0.0)) >= float(mw.get("mat", 0.0)) else GENERAL_MAT
	var item := XGear.template("armor", fid)
	item.level = float(mini(fabao_level, int(XMagicWeapon.max_level(item))))
	var slot := a.equip_slots().find(int(item.etypeId))
	if slot >= 0 and not no_fabao:
		a.equips[slot] = item
	if not bare:
		_qiyin(a)
		_trumpet(a)  # 号卷先学：号卷和权能书共用 XPowerBooks 的上限，秘籍先学满会把号卷挤掉
		_secrets(a)
	for sid in (a.skill_ids if not no_mastery else []):
		XSkillMastery.set_level(a, int(sid), XSkillMastery.max_level(int(sid)))
	if debug:
		print("K_DEBUG mastery_on=%s M=%s on=%s active=%s max=%d" % [XTianqiSkills.mastery_on(), XTianqiSkills.MASTERY, XTianqiSkills.on(), XTianqi.active(s), XSkillMastery.max_level(5703)])
	if debug:
		for q in a.equips.size():
			var it = a.equips[q]
			if it is Dictionary and not it.is_empty():
				print("K_DEBUG equip %d %s %s lv=%s q=%s eff=%s" % [q, it.get("id"), it.get("name"), it.get("level", ""), it.get("meta", {}).get("quality", ""), XTianqiGear.effective_params(it) if XTianqiGear.applies(it) else it.get("params")])
		a.param_mark_dirty()
		print("K_DEBUG layers native=%s rate=%s buff=%s plus=%s before_alien=%s gear_in=%s" % [a.param_native(4), a.param_rate(4), a.param_buff_rate(4), a.param_plus(4), a.param_before_alien(4), XActorModules.param(a, 4, XPercentPills.param(a, 4, a.param_native(4)))])
		for o in a.trait_objects():
			for t in (o.get("traits", []) if o is Dictionary else []):
				if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 4 and float(t.get("value", 1.0)) != 1.0:
					print("K_DEBUG mat-rate %s %s %s" % [o.get("id"), o.get("name"), t.value])
		print("K_DEBUG params %s base=%s" % [[a.param(0), a.param(2), a.param(4)], [a.param_base(2) if a.has_method("param_base") else "", a.param_base(4) if a.has_method("param_base") else ""]])
	if per_skill:
		print("K_ADV %d rank=%d skills=%s" % [id, XAdvance.rank(s, id), a.skill_ids])
	mastery_seen = maxi(mastery_seen, XSkillMastery.max_level(int(a.skill_ids[0])) if not a.skill_ids.is_empty() else 0)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	XState.current = s
	return s


## T163：进阶拉满（「养满」包括进阶：进阶会学招、开形态——饿狼形态、渡鸦、甚尔、谷雨等都挂在进阶后面；T082 v1～v7 都没进阶）。
## 钱、物品、饿狼累计突破和神之触媒都给够，走游戏自己的 XAdvance.advance（含各模块的进阶包装）
static func _advance_max(s: XState, a: XActor) -> void:
	s.gain_gold(999999999)
	if XGarou.own(a):
		s.gain_item(XGarou.CATALYST, 1)
	for _n in 12:
		if XGarou.own(a):
			s.garou["breakthroughs"] = 999  # 每次进阶后 XGarou.sync 会把累计突破夹到当前门槛，下一阶要重新给够（不然停在 2 阶）
		var r = XAdvance.row(s, int(a.actor_id))
		if r != null:
			for p in r.items:
				s.gain_item(int(p[0]), int(p[1]))
		if not XAdvance.advance(s, a):
			break
	a.refresh_passive()


static var _own := {}
static func _own_fabao(actor_id: int) -> int:
	if _own.is_empty():
		for r in XDB.table("Armors"):
			if r is Dictionary and r.get("meta", {}).has("Magic Weapon") and r.meta.has("req_actors"):
				for x in str(r.meta.req_actors).split(","):
					if str(x).strip_edges().is_valid_int() and not _own.has(int(str(x).strip_edges())):
						_own[int(str(x).strip_edges())] = int(r.id)
		_own[-1] = 0
	return int(_own.get(actor_id, 0))


## 每栏挑原版主属性最高的一件（不限品质、不要专属、不要法宝），改成 80 级神话
static var _pool := {}
const PKEYS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]
## 本人条件全中后最大那一招的属性权重（折到标准角色前的原始权重）：挑装备、法宝按它（v4 按物攻魔攻谁高，主招吃魔攻的 108 挑错）
static func main_weights(a: XActor) -> Dictionary:
	var best := -1.0
	var w := {}
	for sid in a.skill_ids:
		var sp := XTianqiSkills.spec(int(sid))
		if not sp.has("damage") or sp.has("heal"):
			continue
		var v := eff_full(int(a.actor_id), int(sid))
		if v > best:
			best = v
			w = sp.damage.get("stats", {})
	return w if not w.is_empty() else ({"atk": 1.0} if a.param(2) >= a.param(4) else {"mat": 1.0})


static func _wscore(p: Array, w: Dictionary) -> float:
	var v := float(p[0]) / 1000.0
	for k in w:
		var i := PKEYS.find(str(k))
		if i >= 0:
			v += float(w[k]) * float(p[i])
	return v


static func _dress(a: XActor) -> void:
	var slots := a.equip_slots()
	var w := main_weights(a)
	for i in slots.size():
		var et := int(slots[i])
		if et == 13 or not XTianqiGear.open_type(et):
			continue
		if not _pool.has(et):
			var list := []
			for rec in XDB.table("Weapons" if et == 1 else "Armors"):
				if not rec is Dictionary or str(rec.get("name", "")) == "" or (et != 1 and int(rec.get("etypeId", 0)) != et):
					continue
				var m: Dictionary = rec.get("meta", {})
				if m.has("Magic Weapon") or m.has("req_actors") or not str(m.get("quality", "")).strip_edges().is_valid_int():
					continue
				list.append(rec)
			_pool[et] = list
		var best := {}
		var best_score := -1.0
		for rec in _pool[et]:
			var item := XGear.template("weapon" if et == 1 else "armor", int(rec.id))
			item.meta = (item.get("meta", {}) as Dictionary).duplicate()
			item.meta["req_level"] = str(gear_level)
			item.meta["quality"] = MYTH_QUALITY
			if not a.can_equip(item) or not XTianqiGear.applies(item):
				continue
			var p := XTianqiGear.effective_params(item)
			var score := _wscore(p, w)
			if score > best_score:
				best_score = score
				best = item
		if not best.is_empty():
			best["instanceId"] = "k_%d_%d" % [int(a.actor_id), i]
			a.equips[i] = best


func _measure(id: int, tier: String) -> Dictionary:
	var s := _state(id)
	var a := s.actor(id)
	var cap := float(XTianqiSkills.data().get("rules", {}).get("single_hit_cap", {}).get(tier, 0.0))
	var logic := XBattleLogic.new()
	logic.setup(_troop(s), s, XBattleRandom.create(str(s.random_master)))
	var foes: Array = logic.alive(logic.enemies)
	if foes.is_empty():
		return {}
	var e = foes[0]
	e.add_param(0, 1.0e9)
	e.param_mark_dirty()
	if XTianqiElements.enemy_profile(e, logic, s).get("source", "") != "":
		push_error("K 木桩 %d 不是元素中性（%s）" % [int(e.enemy_id), XTianqiElements.enemy_profile(e, logic, s)])
	if XGuyu.own(a):
		var g := _measure_guyu(s, a, logic, e)
		logic.end_battle(0)
		return g
	var sids := _scan_ids(a)
	var best := _scan(a, e, logic, sids, cap)
	if not bare and not best.is_empty():
		best["affixes"] = _affix_greedy(a, e, logic, int(best.skill))  # 词条按「这一下最大」挑、掷满（极、四阶），挑完全部技能重量一遍
		var again := _scan(a, e, logic, sids, cap)
		if not again.is_empty():
			again["affixes"] = best.affixes
			best = again
		best["build"] = _build_desc(a)
	logic.end_battle(0)
	# D195（Kyo 11-18）：口径＝一次施放的总伤害（每段先封单段上限再相加）。上面量的峰值单段已是「条件全中、封到上限」；
	# 每招另开一场新战斗整次施放（不让前一招的施放留下的状态、蓄力串到后一招），量「各段合计÷最大一段」（每段在结算里已各自封顶），乘到峰值上。--single 回到旧口径
	if not single and not best.is_empty():
		var affixes = best.get("affixes")
		var build = best.get("build")
		best = {}
		for sid in _rows:
			var row: Dictionary = _rows[sid]
			var cr := _cast_ratio(s, a, XDB.rec("Skills", int(sid)))
			row["segs"] = cr
			row["peak"] = roundf(float(row.peak_single) * float(cr.ratio))
			if per_skill:
				print("K_CAST %d %d single=%d ratio=%s total=%d" % [id, int(sid), row.peak_single, cr.ratio, row.peak])
			if best.is_empty() or float(row.peak) > float(best.peak):
				best = row
		if affixes != null:
			best["affixes"] = affixes
		if build != null:
			best["build"] = build
	if XGarou.own(a) and not best.is_empty():
		best["form"] = XGarou.FORM_NAMES[XGarou.stage(a)]  # T209：饿狼按星空形态量（进阶满＝形态 6）
	return best


## T209（Kyo 11-18「谷雨走A」）：175 谷雨的伤害是多回合叠生命储备再爆发——峰值＝储备叠满后花期里「终结」那一下（同别人「条件全中的一次施放」）。
## 单人木桩：开战（百谷生 60 级自带 30%）后每回合给自己治疗一次（治疗量全记储备，生未央不在花期再 +20%），数到储备到上限要几回合；
## 然后开花期、终结（威力＝全部储备×1.0，减木桩魔防一半；不会心）。词条按终结那一下贪心挑。报告记 rounds（治疗回合数，另加开花期、终结各 1 回合）、cap、reserve。
func _measure_guyu(s: XState, a, logic, e) -> Dictionary:
	if XGuyu.reserve(a) <= 0.0:
		XGuyu.tq_battle_start(a)  # 开战没走 XTianqiModules.battle_start 时补（百谷生 60 级自带 30%）
	var cap := XGuyu.cap(a)
	var r0 := XGuyu.reserve(a)
	var heal := XDB.rec("Skills", int(XGuyu.SKILL.heal))
	var heals := 0
	while XGuyu.reserve(a) < cap and heals < 60:
		heals += 1
		XGuyu.start_turn(heals)
		a.mp = a.mmp
		var r_before := XGuyu.reserve(a)
		var mhp_before: float = a.mhp
		var calc := XDamage.calculate(heal, a, a, {})
		print("K_GUYU_HEAL_CALC value %s breakdown %s" % [str(calc.get("value")), str(calc.get("breakdown"))])
		var heal_logs: Array = logic.execute(a, heal, a, true)
		var healed := 0.0
		for l in heal_logs:
			if l is Dictionary and l.get("target") == a:
				healed += -float(l.get("hp", 0.0))
				print("K_GUYU_HEAL_LOG hp %d type %s elements %s bonus %s" % [-float(l.get("hp", 0.0)), str(l.get("type", "")), str(XDamage.original_elements(heal, a)),
					str(XDamage.original_elements(heal, a).map(func(x): return XDamage.element_bonus(a, int(x))))])
		# T209 第 4 条（核实叠满回合数）：每次治疗记下储备、最大生命（含储备）、治疗比例、这次的回血量
		print("K_GUYU_HEAL %d reserve %d→%d mhp %d base %d heal_ratio %.3f healed %d cap %d rec %.3f" % [heals, r_before, XGuyu.reserve(a), mhp_before, XGuyu.base_mhp(a), XGuyu.heal_ratio(a), healed, cap, a.rec])
		XGuyu.end_round()
	var reserve := XGuyu.reserve(a)
	var fin := XDB.rec("Skills", int(XGuyu.SKILL.finish))
	var opn := XDB.rec("Skills", int(XGuyu.SKILL.open))
	if not bare:
		XGuyu._finish_power = reserve  # 贪心挑词条只算结算（calculating，不减魔防），先把威力摆上
		var affixes := _affix_greedy(a, e, logic, int(fin.id))
		XGuyu._finish_power = 0.0
		report["guyu_affixes"] = affixes
	var segs := []
	XGuyu.start_turn(heals + 1)
	a.mp = a.mmp
	_pin_def(e)
	e.hp = e.mhp
	logic.execute(a, opn, e, true)
	XGuyu.end_round()
	XGuyu.start_turn(heals + 2)
	XGuyu.reserves[a.actor_id] = reserve  # 开花期那回合的绽放付掉的补回来（峰值按叠满算）
	a.mp = a.mmp
	_pin_def(e)
	e.hp = e.mhp
	XStateEffects.force_critical = true
	var logs: Array = logic.execute(a, fin, e, true)
	XStateEffects.force_critical = false
	_collect_hits(logs, e, segs)
	var dealt := 0.0
	for v in segs:
		dealt += float(v)
	if dealt <= 0.0:
		return {}
	return {"actor": int(a.actor_id), "skill": int(fin.id), "peak": roundf(dealt), "peak_single": roundf(dealt), "dealt": dealt, "segs": {"n": segs.size(), "ratio": 1.0, "segs": segs},
		"guyu": {"heal_rounds": heals, "rounds_total": heals + 2, "cap": cap, "cap_rate": XGuyu.tq_cap_rate(a), "reserve_start": r0, "reserve": reserve, "relic": XGuyu.has_relic(a), "base_mhp": XGuyu.base_mhp(a)},
		"atk": a.param(2), "mat": a.param(4), "mhp": a.mhp, "build": _build_desc(a)}


## 要量的技能：自己学会的；176 屠苏另加武装技能（持武者施放，XTusu.apply_subject 让整次结算以屠苏为出手者、按屠苏的属性，
## 卡面写「屠苏属性」——是屠苏的输出，单人木桩上没有持武者，直接让屠苏打，T163）
static func _scan_ids(a) -> Array:
	var ids: Array = a.skill_ids.duplicate()
	if XTusu.is_tusu(a):
		for w in XTusu.ARM_OF:
			for k in XTusu.ARM_OF[w]:
				var sid := XTusu.skill_id(str(k))
				if sid > 0 and not ids.has(sid):
					ids.append(sid)
	return ids


## 172 宿傩终式：主技能（解／捌／伏魔御厨子）打看破三层的目标时转空间斩 9.0／次元斩 10.8（XSukuna.tq_ops 乘在 finalMultiplier 上，
## 不经过 formula 的单段上限）。木桩挂满三层、按游戏的 _new_cast 建施放帧；返回终式对卡面系数的倍数（没转 1.0）
static func _sukuna_terminal(logic, a, e, sid: int) -> float:
	XSukuna.cast = {}
	if not XSukuna.own(a) or not XSukuna.PRIMARY.has(sid):
		return 1.0
	XSukuna._layers(logic, e, 3)
	XSukuna.cast = XSukuna._new_cast(a, sid, e)
	var t := int(XSukuna.cast.get("terminal", 0))
	if t == 0:
		XSukuna.cast = {}
		return 1.0
	# T204（D208）：终式按段打时单打取最大那段（term_seg 指过去，tq_ops 按它取倍率）；合计在 _cast_ratio 的整次施放里收
	var h := XSukuna.tq_terminal_hits(t)
	XSukuna.term_seg = h.find(h.max())
	return float(h.max()) / maxf(0.01, float(XTianqiSkills.spec(sid).get("damage", {}).get("coef", 1.0)))


## 一组技能各打 hits 次，取峰值最大的那一行（每招的那一行另记在 _rows，D195 换算整次施放用）
var _rows := {}
func _scan(a, e, logic, sids: Array, cap: float) -> Dictionary:
	var id := int(a.actor_id)
	var best := {}
	_rows = {}
	for sid in sids:
		var sp := XTianqiSkills.spec(int(sid))
		var gojo_pairs := sp.has("gojo_pairs")  # T209：五条悟茈卡上没 damage、按苍赫印对数取 gojo_pairs（XGojo.formula），木桩前印满 3 对（_prime）
		if (not sp.has("damage") and not gojo_pairs) or sp.has("heal"):
			continue
		var sk := XDB.rec("Skills", int(sid))
		if sk.is_empty() or not XSmartAI.for_opponent(sk):
			if per_skill:
				print("K_SKILL %d %d skip=not_for_opponent" % [id, int(sid)])
			continue
		var d: Dictionary = sp.get("damage", {})
		# D195：「一直生效」的减成条件（如 3922 三连击时每段 ×1/3、4848 每段 ×0.6）是拿段数换的，按总伤算时要算进去，
		# 不然「峰值单段（不含减成）× 段数」会多算 3 倍（T175 v12：9、10、19）。--single 照旧口径不算
		var full_raw := (float((sp.gojo_pairs as Array).max()) if gojo_pairs else eff_full(id, int(sid)) * (1.0 if single else _always_reduce(a, e, d, id, int(sid))))
		var full := minf(full_raw, cap * XTianqiSkills.cap_hits(d)) if cap > 0.0 else full_raw  # T192：cap_hits 按每段封
		var w := XTianqiSkills.hit_weight(d)
		var sk_best := {}
		for n in hits:
			_pin_def(e)
			e.hp = e.mhp * (0.3 if _has_trumpet(a) else 1.0)  # 二号血海：目标生命低于 33% 时 +50%（条件全中）
			a.hp = a.mhp
			a.mp = a.mmp
			a.tp = a.max_tp()
			_prime(logic, a, e, sk)
			var term := _sukuna_terminal(logic, a, e, int(sid))
			XStateEffects.force_critical = true
			var v0 := absf(XGojo.formula(a, e, sk) if gojo_pairs else XTianqiSkills.formula(a, e, sk))
			if debug and n == 0:
				print("K_DEBUG foe def=%s mdf=%s pdr=%s mdr=%s el=%s" % [e.def, e.mdf, e.pdr, e.mdr, [e.element_rate(1), e.element_rate(2), e.element_rate(3), e.element_rate(4)]])
				print("K_DEBUG qiyin fx=%s ops=%s act_w=%s" % [XTianqiQiyinEffects.effects(logic, a).keys(), XTianqiQiyinEffects.damage_ops(sk, a, e), XTianqiQiyinEffects._store(logic).act.get("weight")])
				var calc: Dictionary = logic._calculate_damage(a, sk, e, true)
				print("K_DEBUG %d %s" % [int(sid), JSON.stringify({"value": calc.get("value"), "row": calc.get("breakdown", {}).get("row", {})})])
				var bs: Dictionary = a.passive_cache().get("bySource", {})
				for o in a.stat_equips() + a.skills() + a.states():
					var sc := XActor._note_scans(str(o.get("note", "")))
					if not (sc[4] as Array).is_empty() or not (sc[5] as Array).is_empty():
						print("K_DEBUG obj %s %s fin=%s crit=%s bucket=%s new=%s" % [o.get("id"), o.get("name"), sc[4], sc[5], XTianqiLedger.bucket_of(o, a), o.get("_tianqi_new")])
				print("K_DEBUG elem amp=%s elup=%s by=%s / %s" % [a.passive_cache().get("elementAmplify"), a.passive_cache().get("passiveELUP"), bs.get("elementAmplify"), bs.get("passiveELUP")])
				print("K_DEBUG passive crit=%s fin=%s bySource crit=%s fin=%s" % [a.passive_cache().get("critHarmRi"), a.passive_cache().get("globalHarmRi"), bs.get("critHarmRi"), bs.get("globalHarmRi")])
				for t in calc.get("moduleTrace", []):
					var ops := (t.get("ops", []) as Array).filter(func(o): return o is Dictionary and str(o.get("field", "")) in ["criticalAdd", "finalAdd", "normalAdd", "finalMultiplier", "skillMultiplier", "elementAdd", "elementMultiplier"])
					if not ops.is_empty():
						print("K_DEBUG trace %s %s" % [t.get("module", t.get("id", "?")), JSON.stringify(ops)])
			var r: Dictionary = logic.apply(a, sk, e)
			var dealt := float(r.get("shown", {}).get("hp", r.get("hp", 0.0)))  # 跳出来的那一个数（木桩生命有上限，不能用掉血量）
			XStateEffects.force_critical = false
			XSukuna.cast = {}
			XSukuna.term_seg = 0
			if term != 1.0 and cap > 0.0:
				# 终式倍数乘在单段上限后面：按「条件全中×终式」再封一次上限折回（报告 term、term_capped 两个数都留）
				var ef := eff_full(id, int(sid))
				dealt *= minf(ef * term, cap * XTianqiSkills.cap_hits(d)) / (minf(ef, cap * XTianqiSkills.cap_hits(d)) * term)
			if v0 <= 0.0 or dealt <= 0.0:
				if per_skill and n == 0:
					print("K_SKILL %d %d skip=zero v0=%s dealt=%s" % [id, int(sid), v0, dealt])
				continue
			# v_full：同一个基数（Σ属性×权重 × 等级缩放）乘「条件全中、封到上限」的系数 full÷w
			var base_lv := v0 / maxf(1e-9, _coef_now(a, e, d, int(sid)))
			var v_full := v0 if gojo_pairs else base_lv * full / maxf(1e-9, w)  # 茈：印已按满 3 对摆好，量到的就是条件全中
			var peak := dealt * v_full / v0
			if per_skill and n == hits - 1:
				print("K_SKILL %d %d peak=%d dealt=%d eff=%s" % [id, int(sid), roundf(peak), dealt, eff_full(id, int(sid))])
			if sk_best.is_empty() or peak > float(sk_best.peak):
				sk_best = {"actor": id, "skill": int(sid), "dealt": dealt, "v0": v0, "v_full": v_full, "eff_full": eff_full(id, int(sid)),
					"cap": cap, "peak": roundf(peak), "terminal": term, "formula": str(sk.get("damage", {}).get("formula", "")).left(60), "repeats": int(sk.get("repeats", 1)), "atk": a.param(2), "mat": a.param(4), "mhp": a.mhp}
		if sk_best.is_empty():
			continue
		sk_best["peak_single"] = sk_best.peak
		_rows[int(sid)] = sk_best
		if best.is_empty() or float(sk_best.peak) > float(best.peak):
			best = sk_best
	return best


## D195：整次施放（logic.execute，强制暴击、木桩回满），收这一次打在木桩上的每一段（type hit、target＝木桩、shown.hp＞0），
## 段数比＝合计÷最大一段；跑 CAST_RUNS 遍取中位（随机加段的角色不取最大）。打不到木桩（全随机目标打到别人）按 1
func _cast_ratio(s: XState, a, sk: Dictionary) -> Dictionary:
	var runs := []
	for n in CAST_RUNS:
		var logic := XBattleLogic.new()
		logic.setup(_troop(s), s, XBattleRandom.create(str(s.random_master) + str(n)))
		var foes: Array = logic.alive(logic.enemies)
		if foes.is_empty():
			break
		var e = foes[0]
		# 场上只留木桩：全体技能的 target 阶段每个目标跑一遍、里面的「action effect: enemies」又打全体，3 个敌人时木桩挨 3 遍（T175 v12 91 号 5 段量成 13 段）
		logic.enemies = [e]
		e.add_param(0, 1.0e9)
		e.param_mark_dirty()
		_pin_def(e)
		e.hp = e.mhp * (0.3 if _has_trumpet(a) else 1.0)
		a.hp = a.mhp
		a.mp = a.mmp
		a.tp = a.max_tp()
		_prime(logic, a, e, sk)
		if XSukuna.own(a) and XSukuna.PRIMARY.has(int(sk.get("id", 0))):
			XSukuna._layers(logic, e, 3)  # T204：整次施放同单打口径（看破三层转终式），终式按段打的合计在这里收（T192 前这里没挂层，量的是捌冲击＋斩击两段）
		XStateEffects.force_critical = true
		var logs: Array = logic.execute(a, sk, e, true)
		XStateEffects.force_critical = false
		XSukuna.cast = {}
		var segs := []
		_collect_hits(logs, e, segs)
		logic.end_battle(0)
		var mx := 0.0
		var sum := 0.0
		for v in segs:
			mx = maxf(mx, v)
			sum += v
		runs.append({"n": segs.size(), "ratio": sum / mx if mx > 0.0 else 1.0, "segs": segs.map(func(v): return roundi(v))})
	if runs.is_empty():
		return {"ratio": 1.0, "n": 0, "segs": [], "ratios": []}
	runs.sort_custom(func(x, y): return float(x.ratio) < float(y.ratio))
	var mid: Dictionary = runs[runs.size() / 2]
	# yep_effects：数据里的段数（yepEffects×repeats，智能 AI 估段数同口径），和实测 n 对照（卡面写的段数对不上时看这个）
	return {"ratio": snappedf(float(mid.ratio), 0.001), "n": mid.n, "segs": mid.segs, "ratios": runs.map(func(r): return snappedf(float(r.ratio), 0.001)),
		"yep_effects": int(sk.get("yepEffects", 1)) * maxi(1, int(sk.get("repeats", 1)))}


static var _debug_cast := false
static func _collect_hits(logs, e, out: Array) -> void:
	for x in logs:
		if x is Array:
			_collect_hits(x, e, out)
		elif x is Dictionary:
			if str(x.get("type", "")) == "hit" and is_same(x.get("target"), e) and not bool(x.get("reflected", false)):
				var v := float(x.get("shown", {}).get("hp", 0.0))
				if v > 0.0:
					out.append(v)
					if _debug_cast:
						print("K_SEG skill=%s v=%d" % [x.get("skill", {}).get("id"), v])


## 木桩物防魔防钉到 DEF：敌人的防御要乘难度、首领、天启篇楼层等倍率（还会在第一下时才挂上开战状态），
## 所以每一下之前按「当前值÷加值前」反推加值，迭代到差 <1。v1 只在开场加一次差值：第一招打的是防御 46，后面是 1.2～1.5 万（T082 v1 的 153、163 两例）。
static func _pin_def(e) -> void:
	for i in [3, 5]:
		for _n in 6:
			e.param_mark_dirty()
			e.param_refresh()  # 战斗中读的是能力值缓存格，标脏后要 refresh 才清
			var cur := float(e.param(i))
			if absf(cur - DEF) < 1.0:
				break
			var plus := float(e.added_params.get(i, 0.0))
			var raw := float(e.param_base_unscaled(i)) + plus
			var f := cur / raw if raw > 0.0 and cur > 0.0 else 1.0
			e.add_param(i, (DEF - cur) / maxf(1e-6, f))
	e.param_mark_dirty()
	e.param_refresh()


## 木桩敌群：从 TROOP 往后找第一个首个敌人不是守层者、不是首领的（元素牌对它恒中性，稿第九节第 1 条「元素中性」）
static var _troop_id := 0
static func _troop(s) -> int:
	if _troop_id > 0:
		return _troop_id
	for t in range(TROOP, TROOP + 400):
		var tr := XDB.rec("Troops", t)
		if tr.is_empty() or (tr.get("members", []) as Array).is_empty():
			continue
		var eid := int(tr.members[0].get("enemyId", 0))
		if eid <= 0 or XGuardianRework.floor_of(eid) > 0 or XEnemy.boss_id(eid):
			continue
		_troop_id = t
		return t
	return TROOP


## D195：卡上和角色行里 if＝always、倍率＜1 的条件（学会某招后每段打折、换更多段），按当下是否成立取实际倍率
static func _always_reduce(a, e, d: Dictionary, id: int, sid: int) -> float:
	var m := 1.0
	XTianqiSkills._cur_skill = sid
	var conds: Array = (d.get("conds", []) as Array) + (XTianqiSkills.data().get("actors", {}).get(str(id), {}).get("conds", []) as Array)
	for c in conds:
		if c.has("skills") and not (c.skills as Array).any(func(x): return int(x) == sid):
			continue
		if str(c.get("if", "")) == "always" and float(c.get("mult", 1.0)) < 1.0:
			m *= minf(1.0, XTianqiSkills._cond(c, a, e))
	return m


## 这一下卡面系数×当下条件（不含属性基数和等级缩放）：formula 的 v0 ÷ 它 ＝ 基数×等级缩放
func _coef_now(a, e, d: Dictionary, sid: int) -> float:
	var m := float(d.get("coef", 0.0))
	XTianqiSkills._cur_skill = sid
	for c in d.get("conds", []):
		m *= XTianqiSkills._cond(c, a, e)
	for c in XTianqiSkills.data().get("actors", {}).get(str(int(a.actor_id)), {}).get("conds", []):
		m *= XTianqiSkills._cond(c, a, e)
	var cap := XTianqiBase.single_hit_cap(a)
	var w := XTianqiSkills.hit_weight(d)
	if cap > 0.0 and m * w > cap * XTianqiSkills.cap_hits(d):  # T192：cap_hits 按每段封（同 XTianqiSkills.formula）
		m = cap * XTianqiSkills.cap_hits(d) / w
	return m


# ---- 甲档补齐（稿第三节第 3 条「养成」；T082 第三会话） ----

## 黑印满配：六个防具栏换黑印套装件（五件档：砝码攒满五层必暴、爆伤 +50%；三件档：每层伤害 +15%），
## 武器换真印「一力降十会」（黑印流派：只出手一次 +50%；真印追加：无视目标 33% 防御；独有：上一回合防御再 +50%）。
## 毕业武器按武器类限人（拳套），稿子口径是「人人黑印满配、真印无视防御」，所以这里不看 can_equip 直接穿（交付单写明）。
const QIYIN_SEAL := "hei"
const QIYIN_WTYPE_KEY := "fist"
func _qiyin(a: XActor) -> void:
	var rng := XRandomStream.create(XRandomStream.hex64(7700 + int(a.actor_id)), "rule")
	var slots := a.equip_slots()
	var parts := {}
	for p in XTianqiQiyinGear.parts():
		parts[int(p.etype)] = str(p.key)
	var grades := ["perfect", "perfect", "perfect"]
	for i in slots.size():
		var et := int(slots[i])
		var item := {}
		if et == 1:
			var wname := ""
			for t in XTianqiQiyinGear.weapon_types():
				if str(t.key) == QIYIN_WTYPE_KEY:
					wname = str(t.name)
			item = XTianqiQiyinEquip.make({"kind": "weapon", "seal": QIYIN_SEAL, "wtype": wname, "true_seal": true, "grades": grades, "affixes": []}, "zhengdao", rng)
			if not item.is_empty() and not a.can_equip(item):
				# T163：拳套用不了的人（v5～v8 有 69/134 人）穿上后会被 release_unequippable 卸掉，等于没武器。黑印另一类是枪械，能用就换枪械；
				# 都用不了就把这把黑印武器的武器类改成本人能用的第一类（口径照旧「人人黑印满配」，武器类只影响能不能穿）
				var ok := false
				for t in XTianqiQiyinGear.weapon_types():
					if str(t.key) == "gun" and a.traits_set(51).has(int(t.wtype_id)):
						var g := XTianqiQiyinEquip.make({"kind": "weapon", "seal": QIYIN_SEAL, "wtype": str(t.name), "true_seal": true, "grades": grades, "affixes": []}, "zhengdao", rng)
						if not g.is_empty() and a.can_equip(g):
							item = g
							ok = true
				if not ok:
					for wt in a.traits_set(51):
						item.wtypeId = int(wt)
						if a.can_equip(item):
							ok = true
							break
				if not ok:
					push_error("K 黑印武器 %d 穿不上" % int(a.actor_id))
		elif parts.has(et):
			item = XTianqiQiyinEquip.make({"kind": "set", "seal": QIYIN_SEAL, "part": parts[et], "true_seal": true, "grades": grades, "affixes": []}, "zhengdao", rng)
		else:
			continue
		if item.is_empty():
			push_error("K 七印装备造不出来：栏 %d" % et)
			continue
		item["instanceId"] = "kq_%d_%d" % [int(a.actor_id), i]
		_set_aff(item, [])
		a.equips[i] = item


## 秘籍拿满：先把全部秘籍书的技能都学上，按游戏自己的取舍（XTianqiLedger.secret_kept：档位格数、每本各池封 8% 后按贡献排）
## 取前几本，其余忘掉（只留生效的那几本，免得没生效的书的属性、特性也算进来）
static var _secret_ids: Array = []
func _secrets(a: XActor) -> void:
	if _secret_ids.is_empty():
		for sk in XDB.table("Skills"):
			if sk is Dictionary and int(sk.get("id", 0)) > 0 and str(sk.get("name", "")) != "" \
					and XTianqiLedger.is_secret_skill(int(sk.id), int(sk.get("stypeId", 0))):
				_secret_ids.append(int(sk.id))
	var had := a.skill_ids.duplicate()
	for sid in _secret_ids:
		if not had.has(sid):
			a.learn_skill(sid)
	a.param_mark_dirty()
	a.refresh_passive()
	var by: Dictionary = a.passive_cache().get("bySource", {})
	var kept: Array = XTianqiLedger.secret_kept(a, by).map(func(b): return int(str(b).substr(1)))
	for sid in _secret_ids:
		if not had.has(sid) and not kept.has(sid):
			a.forget_skill(sid)
	a.set_meta("k_secrets", kept)
	a.param_mark_dirty()
	a.refresh_passive()


## 号卷：只学二号血海（打单体加伤害的只有它；超强者 1 卷，强者、弱者多出来的是保命卷，不进这一下）
func _trumpet(a: XActor) -> void:
	var sc := XTianqiTrumpet.scroll(trumpet_n)
	if not sc.is_empty() and XTianqiTrumpet.limit(a) > 0:
		a.learn_skill(int(sc.skill))
	if debug:
		print("K_DEBUG trumpet on=%s limit=%d sc=%s has=%s" % [XTianqiTrumpet.on(), XTianqiTrumpet.limit(a), sc.get("skill"), XTianqiTrumpet.has(a, trumpet_n)])


func _has_trumpet(a) -> bool:
	return not bare and XTianqiTrumpet.has(a, trumpet_n)


## 每一下之前：行动帧（XBattleLogic 出手时才建，探针直接 apply 要自己建）。砝码攒满 5 层、上一回合防御过、本回合第一次出手；词条先声每下都算第一下
func _prime(logic, a, e, sk: Dictionary) -> void:
	var sid := int(sk.get("id", 0))
	if XGojo.own(a) and sid in [XGojo.PURPLE_IN, XGojo.PURPLE_OUT]:  # T209：茈条件全中＝苍印、赫印各 3（上限），形状对上
		var t := XGojo.temp(a)
		t.blue = XGojo.MARK_CAP
		t.red = XGojo.MARK_CAP
		t.last = "blue" if sid == XGojo.PURPLE_IN else "red"
		XGojo.cast = {"skill": sid, "pairs": XGojo.MARK_CAP}
	if bare:
		return
	var un := XTianqiQiyinEffects._unit(logic, a)
	un.weights = 5
	un.idle = true
	un.acted = 0
	XTianqiQiyinEffects.begin_action(logic, a, sk)
	var au := XTianqiAffixBattle._unit(logic, a)
	if not au.is_empty():
		au.first_turn = -1
	XTianqiAffixBattle.begin_action(logic, a, sk)


func _set_aff(item: Dictionary, list: Array) -> void:
	if item.has("qiyin"):
		item.qiyin["affixes"] = list
	else:
		XTianqiAffixRoll.set_affixes(item, list)


## 这一下的确定值（强制暴击；波动关掉）：贪心挑词条的比较用
func _probe_value(a, e, logic, sk: Dictionary) -> float:
	var st := XTianqiAffixBattle._store(logic)
	if not st.is_empty():
		st.views.erase(a)
	a.param_mark_dirty()
	a.refresh_passive()
	_pin_def(e)
	e.hp = e.mhp * (0.3 if _has_trumpet(a) else 1.0)
	_prime(logic, a, e, sk)
	XStateEffects.force_critical = true
	var calc: Dictionary = logic._calculate_damage(a, sk, e, true)
	XStateEffects.force_critical = false
	return absf(float(calc.get("value", 0.0)))


## 词条：每件三槽（神话：特效最多 2、传说最多 1，同件不重名），极、四阶；逐件逐槽在候选里挑让这一下最大的（元素增伤按每一系各试一次）
const DMG_POOLS := ["stat", "crit_multiplier", "final_damage", "skill_damage", "element_damage"]
const AFF := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
func _affix_greedy(a, e, logic, sid: int) -> Array:
	var sk := XDB.rec("Skills", sid)
	var out := []
	var els: Array = AFF.data().get("elements", []).filter(func(x): return str(x.key) != "physical").map(func(x): return str(x.key))
	for i in a.equips.size():
		var item = a.equips[i]
		if not item is Dictionary or item.is_empty():
			continue
		var slot := XTianqiAffixRoll.slot_key(item)
		var group := AFF.slot_group(slot) if slot != "" else ""
		if group == "" or group == "fabao" or group == "zuoqi":
			continue
		var cands := []
		for layer in ["base", "special", "legendary"]:
			for k in AFF.candidates(layer, group):
				if not AFF.available(str(k), 4):
					continue
				var af := AFF.affix(str(k))
				if not str(af.get("pool", "")) in DMG_POOLS:
					continue  # 只挑进这一下的池（属性、暴击倍率、伤害加成、技能伤、元素增伤）；比较值有约千分之几的噪声，不过滤会挑进掉率之类
				if bool(af.get("random_element", false)):
					for el in els:
						cands.append({"key": str(k), "tier": 4, "grade": "perfect", "extra": {"element": el}})
				else:
					var ex := {}
					if not (af.get("variants", []) as Array).is_empty():
						ex.variant = str(af.variants[0].key)
					cands.append({"key": str(k), "tier": 4, "grade": "perfect", "extra": ex})
		var list := []
		for _slot in 3:
			var best_v := _probe_value(a, e, logic, sk)
			var best_c = null
			var count := {}
			for x in list:
				var ly := str(AFF.affix(str(x.key)).get("layer", ""))
				count[ly] = int(count.get(ly, 0)) + 1
			for c in cands:
				var ly := str(AFF.affix(str(c.key)).get("layer", ""))
				var capn = AFF.layer(ly).get("per_item_max")
				if capn != null and int(count.get(ly, 0)) >= int(capn):
					continue
				if list.any(func(x): return str(x.key) == str(c.key)):
					continue
				_set_aff(item, list + [c])
				var v := _probe_value(a, e, logic, sk)
				if v > best_v * 1.005:
					best_v = v
					best_c = c
			if best_c == null:
				break
			list.append(best_c)
			_set_aff(item, list)
		_set_aff(item, list)
		out.append({"slot": i, "name": str(item.get("name", "")), "affixes": list.map(func(x): return x.key + ("/" + str(x.extra.element) if x.extra.has("element") else ""))})
	_probe_value(a, e, logic, sk)
	return out


func _build_desc(a) -> Dictionary:
	return {"secrets": a.get_meta("k_secrets", []), "trumpet": XTianqiTrumpet.learned(a),
		"equips": a.equips.map(func(it): return str(it.get("name", "")) if it is Dictionary else "")}
