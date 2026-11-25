class_name XEnemy
extends XBattler
## 敌人：MV Game_Enemy ＋ Vitsuno_Difficulty 按难度放大能力值 ＋ EliteEnemy 随机「神话」变体。
## 神话（正式版插件参数）：几率 50%（备注 <elite:几率,能力,经验,金钱,掉率> 可单独设定，NoElite 不会变），
## 基础能力值 ×3.5 取整、经验 ×1.2、金钱 ×1.2、掉率 ×5，名字前加「【神话】」，图像放大 1.8 倍并偏色。
## 开关参数「开启」在正式版被读成 NaN（不看开关），所以总是生效。
## 敌人等级（YEP_EnemyLevels，Default Type 5、浮动 ±2；正式数据没有敌人改等级的备注）：开战时＝出战成员最高等级，
## 再 floor(随机×5 + 等级−2)，不低于 1（见 setup_level）。EliteEnemy 排在后面且重写了 paramBase/exp/gold（不调用前面的），
## 所以等级不改能力值、经验、金钱，只给伤害公式里的 a.level / b.level 用；等级显示已关闭。

var enemy_id := 0
var difficulty_id := 2
var letter := ""
## 敌群的隐藏成员（Game_BattlerBase._hidden）：没出现前不算活着也不算阵亡（isAppeared），335 出现
var hidden := false
## 可捕捉（Star_PetSystem 的 Game_Enemy.Capture，开战时掷，见 XPetCapture）：名字加「宝宝」
var capture := false
var _rates: Array = [1, 1, 1, 1, 1, 1, 1, 1]
var _passive_cache := {}
var elite := false
var elite_hue := 0.0              # 0~1，画面偏色用
## 测试用：>= 0 时所有敌人按此值判定神话（0 必为神话，100 必不是）
static var force_roll := -1.0
## 出伤倍率：对我方的 HP 伤害／吸取最后乘它（XDamage.finish）。默认 1；守层者按楼层重算攻击、基准伤害工具量攻击时设
var output_scale := 1.0
## T239 第 6 轮（D248 C）：守层者的集火招（技能号）和它单独的出伤倍率；0＝没有，那招也照 output_scale（XGuardianRework.focus）
var focus_skill := 0
var focus_scale := 1.0
var focus_single := false   # T363：集火招在这名守层者手里只打一人（XGuardianRework.single_action）
## 量数用：这个敌人打出的 HP 伤害累计（XDamage.finish 记，扣血前的值）
var dealt := 0.0

## installBossDifficultyRuntime：本场出战人数快照；倍率在原生缓存外结算。
var boss_strong_count := 0
var boss_difficulty_boss := false
var boss_hyper_armor := false
var _updating_boss_armor := false
static var _boss_ids := {}
const BOSS_ARMOR_STATE := 2651

## 上阵超强者人数（首领属性 1＋20%×N）。天启篇存档按天启篇档位名单（XTianqiSkills，跟上阵上限同一份，T146）；
## 原版档照 super_strong_ids。members 只给出战栏（battle_members 不含助力位，助力位不计）；s 缺省取当前存档
static func deployed_strong_count(members: Array, s: XState = null) -> int:
	if s == null:
		s = XState.current
	return members.filter(func(a): return a is XActor and XItemMarks._super_in(s, int(a.actor_id))).size()

static func boss_id(id: int) -> bool:
	var rec := XDB.rec("Enemies", id)
	if rec.is_empty():
		return false
	if _boss_ids.is_empty():
		var p := XDB.plugin("MOG_BossHP")
		for i in range(1, 570):
			_boss_ids[int(p.get("boss-%d" % i, "0"))] = true
	return _boss_ids.has(id) or RegEx.create_from_string("(?i)<boss(?:\\s*:[^>]*)?\\s*>|BOSS级怪物").search(str(rec.get("note", ""))) != null

func boss_attribute_rate() -> float:
	return 1.0 + 0.2 * boss_strong_count if boss_difficulty_boss else 1.0

## 原版只读Boss身份与霸体标志；死亡复活后暂缺2651图标时仍保留输出倍率。
func boss_output_rate() -> float:
	return boss_attribute_rate() if boss_difficulty_boss and boss_hyper_armor else 1.0

## 控制标签正则预编译（T276 核查 P2-1：state_rate 热路径上每次现编；T277 补）
static var _control_tag_re := RegEx.create_from_string("(?i)<BuffType:\\s*(?:沉默|封印|眩晕|睡眠|麻痹|混乱|魅惑|恐惧|冰冻)\\s*>")

static func boss_control_state(id: int) -> bool:
	var st := XDB.rec("States", id)
	if st.is_empty() or id in [1, BOSS_ARMOR_STATE]:
		return false
	return int(st.get("restriction", 0)) > 0 or _control_tag_re.search(str(st.get("note", ""))) != null or st.get("traits", []).any(func(t): return int(t.code) in [42, 44])

func sync_boss_armor(active: bool, random: XRandomStream = null) -> void:
	boss_hyper_armor = boss_difficulty_boss and active
	_updating_boss_armor = true
	if boss_hyper_armor:
		for id in state_ids.duplicate():
			if boss_control_state(id):
				_boss_drop_state(id)
		if not hidden and not state_ids.has(1) and not is_state_affected(BOSS_ARMOR_STATE):
			add_state(BOSS_ARMOR_STATE, random if random != null else lifecycle_context.get("random"))
		if is_state_affected(BOSS_ARMOR_STATE):
			state_turns[BOSS_ARMOR_STATE] = 1
	elif is_state_affected(BOSS_ARMOR_STATE):
		_boss_drop_state(BOSS_ARMOR_STATE)
	_updating_boss_armor = false

## 冻结源控制状态与2651均不带State Can Added Floor；removeStateCompletely不处理它们，
## dropState随后直接eraseState：不走remove效果、不refresh、不标dirty，也不清stateOrigin。
func _boss_drop_state(id: int) -> void:
	state_ids.erase(id)
	state_turns.erase(id)

func add_state(id: int, random: XRandomStream = null) -> void:
	# 原生 isStateAddable 要求 isAlive；HP0本身不等于原版阵亡状态。
	if hidden or state_ids.has(1):
		return
	if XTianqiHorsemen.blocks_state(self, id):  # 天启四骑士：免疫停手的控制和即死
		return
	if XCat.trial_blocks_state(self, id):  # 小猫试炼 addState 包装：巨龙不吃难度状态
		return
	if boss_hyper_armor and boss_difficulty_boss and boss_control_state(id):
		return
	var tq := XTianqiSkills.boss_add(self, id)  # 天启篇首领减半：1 回合控制无效、按招换成减伤
	if tq < 0:
		return
	super(tq if tq > 0 else id, random)

## 天启篇首领减半：控制、减益回合数减半（XTianqiSkills.boss_turns）
func reset_state_counts(id: int, random: XRandomStream = null) -> void:
	super(id, random)
	if state_turns.has(id):
		state_turns[id] = XTianqiSkills.boss_turns(self, id, int(state_turns[id]))

func remove_state(id: int) -> void:
	if id == BOSS_ARMOR_STATE and boss_hyper_armor and boss_difficulty_boss and not _updating_boss_armor and not (not hidden and state_ids.has(1)):
		return
	super(id)

func recover_all() -> void:
	super()
	if boss_hyper_armor and not _updating_boss_armor:
		sync_boss_armor(true)


## roll < 0 时按几率随机决定神话；测试可传 0（必为神话，除非 NoElite）或 100（必不是）。
func setup(id: int, difficulty: int, roll := -1.0, random: XRandomStream = null, strong_count := -1) -> XEnemy:
	boss_strong_count = strong_count if strong_count >= 0 else (deployed_strong_count(XState.current.battle_members(), XState.current) if XState.current != null else 0)
	boss_difficulty_boss = boss_id(id)
	boss_hyper_armor = false
	enemy_id = id
	difficulty_id = difficulty
	_rates = XTianqiCombat.enemy_rates(difficulty)  # 天启篇：基准难度×本档敌人血量／攻击；原版档照 difficulty_rates
	if roll < 0.0:
		roll = force_roll
	var r := (random.next_float("enemy_elite", str(id)) if random != null else _standalone_random().next_float("enemy_elite", str(id))) * 100.0 if roll < 0.0 else roll
	elite = r < elite_param(0) and not str(data().get("note", "")).contains("NoElite")
	if elite:
		var visual := RandomNumberGenerator.new()
		visual.randomize()
		elite_hue = visual.randf_range(100.0, 170.0) / 360.0
	refresh_passive()
	recover_all()
	return self


## EnemyNameColorByDifficulty：任何与数据库敌人原名（去首尾空白）完全相同的文字，改画成当前难度的颜色。
const NAME_COLORS := {1: "#ffffff", 2: "#39ff39", 3: "#4499ff", 4: "#b050ff", 5: "#ff9922", 6: "#ffd700", 7: "#ff2222", 8: "#ee77ee"}
static var _names := {}

static func name_color(text: String, difficulty: int, base := XUI.TEXT) -> Color:
	if _names.is_empty():
		for e in XDB.table("Enemies"):
			if e is Dictionary and str(e.get("name", "")).strip_edges() != "":
				_names[str(e.name).strip_edges()] = true
	if _names.has(text.strip_edges()) and NAME_COLORS.has(difficulty):
		return Color(NAME_COLORS[difficulty])
	return base


static func difficulty_rates(difficulty: int) -> Array:
	var p := XDB.plugin("Vitsuno_Difficulty")
	var s := str(p.get("%d : Param Rate" % difficulty, ""))
	if s == "":
		return [1, 1, 1, 1, 1, 1, 1, 1]
	return Array(s.split(",")).map(func(x): return float(x))

static func difficulty_name(difficulty: int) -> String:
	return str(XDB.plugin("Vitsuno_Difficulty").get("%d : Name" % difficulty, ""))


func is_alive() -> bool:
	return not hidden and super()

func is_dead() -> bool:
	return not hidden and super()


func data() -> Dictionary:
	if not horseman.is_empty():
		return horseman.rec  # 天启四骑士战的骑士、援军：借外观的合成记录（XTianqiHorsemen）
	return XDB.rec("Enemies", enemy_id)


## 天启四骑士战（XTianqiHorsemen）：{rec: 合成的敌人记录, knight: 是不是骑士本体}；空＝普通敌人
var horseman := {}

## 骑士、援军开战：外观借 shell_id，能力值、名字照 rec；不是神话、不算首领难度（不吃霸体）、难度倍率不再乘（rec 里已按本档算好）
func setup_horseman(shell_id: int, rec: Dictionary, is_knight := false) -> XEnemy:
	horseman = {"rec": rec, "knight": is_knight}
	enemy_id = shell_id
	boss_strong_count = 0
	boss_difficulty_boss = false
	boss_hyper_armor = false
	elite = false
	_rates = [1, 1, 1, 1, 1, 1, 1, 1]
	refresh_passive()
	recover_all()
	return self

func display_name() -> String:
	return XAlienBattle.name_prefix(self) + (str(get_meta("tianqi_prefix")) if has_meta("tianqi_prefix") else "") + original_name() + letter + ("宝宝" if capture else "")  # 天启篇战争线异化「侵染·」等

## Game_Enemy.originalName：EliteEnemy 改写为神话敌人带「【神话】」前缀（不含同名字母）；makeUniqueNames 按它计数，
## 所以同一敌人一只神话一只普通时两边都只有一个，都不加字母
func original_name() -> String:
	return (elite_title() if elite else "") + str(data().get("name", ""))

static func elite_title() -> String:
	return str(XDB.plugin("EliteEnemy").get("EliteEnemyTitle", "【精英】"))

## EliteEnemy 数值：0 几率、1 能力、2 经验、3 金钱、4 掉率；备注 <elite:...> 优先。
func elite_param(i: int) -> float:
	var keys := ["EliteEnemyChances", "EliteEnemyAdditionParamBase", "EliteEnemyAdditionExp", "EliteEnemyAdditionGold", "EliteEnemyAdditionDropItemRate"]
	var defaults := [35.0, 1.5, 3.0, 3.0, 2.0]
	var meta = data().get("meta", {}).get("elite")
	if meta != null:
		var parts := str(meta).split(",")
		# JS：Number(片段 || 默认)——片段为空才用默认
		if i < parts.size() and parts[i].strip_edges() != "":
			return float(parts[i])
	var v := str(XDB.plugin("EliteEnemy").get(keys[i], ""))
	return float(v) if v != "" else defaults[i]

var enemy_level := 1

func _level() -> int:
	return enemy_level


## Game_Enemy.setupEnemyLevel：level = highestLevelBattleMembers，clamp(1, 999999)；浮动 floor(r×5 + level − 2)，再 clamp(1, 999999)。
## r < 0 时取随机数（测试用固定值）。
func setup_level(highest: int, r := -1.0, random: XRandomStream = null) -> void:
	var base := clampi(highest, 1, 999999)
	enemy_level = clampi(floori(((random.next_float("enemy_level", str(enemy_id)) if random != null else _standalone_random().next_float("enemy_level", str(enemy_id))) if r < 0.0 else r) * 5.0 + base - 2), 1, 999999)

## 真气瓶颈之战的幻化（XZhenqi.troop_setup）：{p: 参照敌人 paramBase, k: 倍数}；生命、攻击、魔攻 ×k
var zq_ref := {}
## 幻化的敌人不掉落（makeDropItems／makeRewards 的物品清空）
var zq_trial_loot := false
## 神兵试炼的敌人（原版 _codexZqWeaponTrial，v0.45）：经验、金钱为 0
var zq_weapon_trial := false
## 异化敌人（XAlienBattle，原版 _alienEnemy）：{variant, boss, shieldGranted, mirrorRound, mirrorCharged, plagueRound, drainRound}
var alien := {}

## EliteEnemy 的 paramBase（不含难度倍率 Vitsuno paramRate）
func param_base_raw(i: int) -> float:
	var base := float(data().params[i])
	if elite:
		base = floorf(base * elite_param(1))
	return base

## 不含难度倍率的 paramBase（EliteEnemy／真气幻化后）
func param_base_unscaled(i: int) -> float:
	if not zq_ref.is_empty():
		return float(zq_ref.p[i]) * (float(zq_ref.k) if i in [0, 2, 4] else 1.0)
	return param_base_raw(i)

## 含难度倍率的 paramBase（别处按「基础含倍率」取用：真气探针、特性叠加对照）
func param_base(i: int) -> float:
	if not zq_ref.is_empty():
		return float(zq_ref.p[i]) * (float(zq_ref.k) if i in [0, 2, 4] else 1.0) * float(_rates[i])
	return param_base_raw(i) * float(_rates[i])

## 正式版 Vitsuno_Difficulty 在 Game_Enemy.paramRate 里乘难度倍率：(基础＋加值)×((特性比率×难度倍率)×强化率)＋状态固定值。
## 乘法次序照 JS，倍率不预乘进基础值：预乘时 10250×1.4 得 14349.999999999998，再×1.25＋1500 为 19437.499999999996，
## 四舍五入少 1（二十七层多宝 463 攻击 19438，敌群事件参照）。战斗中经 krz 能力值缓存（见 XBattler.param_cells）。
func param(i: int) -> float:
	if i == 0:
		return XTianqiBase.scale_enemy_mhp(_param_raw(i))  # T501 R2：天启篇敌人最大生命统一 ×enemy_hp_pct%（西游档 100 原样）
	return _param_raw(i)


## T501 R2：敌人生命统一折算之前的最大生命。按绝对目标值重标血量（目标÷当前 mhp）的地方读它，免得把 40% 又约回去
func mhp_raw() -> float:
	return _param_raw(0)


func _param_raw(i: int) -> float:
	var dragon := XCat.dragon_param(self, i)  # 小猫试炼巨龙 param 最外层包装：数据库原值
	if not is_nan(dragon):
		return XHubris.formula_param(self, i, dragon)
	var native := cached_param(i, param_now) if param_cache_on else param_now(i)
	native = XYomiJingliu.enemy_param(self, i, roundf(native * warehouse_rate()))  # 镜流裂隙演化（在仓库倍率之外、首领倍率之内）
	return XHubris.formula_param(self, i, XAlienBattle.hp_param(self, i, roundf(native * boss_attribute_rate())))  # 狂妄 evalDamageFormula 包装（最外层）：公式里物防按穿透打折

## Star_Warehouse 的难度怪物属性：$gameParty.DCultyL1～5（公共事件 714 按难度开关置位，标志存在 XState.flags）从小到大取第一个为真的，
## 按插件参数 DCL1～5（1／1.5／2／2.5／3）乘到 Game_Enemy 的 param（取整）、xparam、sparam 上；L6～8 与全假＝不乘。
## 包装次序：它比 installBossDifficultyRuntime 内层，所以先乘它再乘首领倍率（参照 enemy_warehouse.json）。
func warehouse_rate() -> float:
	if has_meta("fest_road"):
		return 1.0  # 冠军庆典·冠军之路的敌人只吃本档难度倍率，不读存档的 DCultyL（XFestRoad.battle_setup 标记；co 核查 P2）
	var s := XState.current
	if s == null:
		return 1.0
	for k in range(1, 6):
		if bool(s.flags.get("DCultyL%d" % k, false)):
			return float(str(XDB.plugin("Star_Warehouse").get("DCL%d" % k, "1")))
	return 1.0

func xparam(i: int) -> float:
	if i >= 1 and i <= 4 and XTianqiCombat.cap_on() and XTianqiCombat.xparam_cap_pct(self, i) >= 0:  # T285（D237 丙）：天启篇这一项有上限时：去仓库 ×2、底子封顶、不低于 0；上限 -1 的项照原路（r2 P1-1）
		return XTianqiCombat.enemy_xparam(self, i)
	return XTianqiAffixBattle.enemy_xparam(self, i, super.xparam(i) * warehouse_rate())  # 天启篇词条「压制」

## T285：特性 22 第 i 项拆成 [底子, 我方减益]：底子＝敌人数据特性＋状态里的正值；减益＝状态里的负值（≤0）
func xparam_parts(i: int) -> Array:
	var base := 0.0
	var neg := 0.0
	for t in data().get("traits", []):
		if int(t.code) == TRAIT_XPARAM and int(t.dataId) == i:
			base += float(t.value)
	for o in states() + floor_states():
		for t in o.get("traits", []):
			if int(t.code) == TRAIT_XPARAM and int(t.dataId) == i:
				var v := float(t.value)
				if v > 0.0:
					base += v
				else:
					neg += v
	return [base, neg]

## T285：甚尔五感读到的暴击闪避：夹完上限的底子乘 pct%（整数，默认 50），再扣我方减益与压制，不低于 0
func cev_for_toji(pct: int) -> float:
	return XTianqiCombat.enemy_xparam(self, 3, pct)

func sparam(i: int) -> float:
	return super.sparam(i) * warehouse_rate()

## T332（D249 乙，r1 返修）＋T405（D273）：回合末 HP 再生用的 [hrg, rec, 天启篇拆算]。drop＝不算的负再生（异化逆祷挡掉的那部分，原值 ≤0）。
## 天启篇（XTianqiCombat.regen_unscaled）且再生特性里有负值时：照 T285 xparam_parts 把特性 22-7 拆成正值 pos 与负值 neg，
## 正再生照原版吃两次仓库倍率（pos × w × w，原版 hrg、rec 各 ×w），负再生不吃（eff_neg = neg − drop，×1），rec 取不乘倍率的原值；
## T405（D273）：守层者与首领的负再生部分再按 balance_table.combat_rules.boss_neg_hrg_cap_pct 封顶（每回合最多扣 5% 最大生命，普通小怪不封）：
## floor(mhp × (pos×w² ＋ eff_neg) × rec原值)。别的情况（西游档、开关关、没有负再生）逐字照原版 [hrg − drop, rec]。
func regen_rates(drop := 0.0) -> Array:
	if XTianqiCombat.regen_unscaled():
		var pos := 0.0
		var neg := 0.0
		for t in traits_with_id(TRAIT_XPARAM, 7):
			var v := float(t.value)
			if v < 0.0:
				neg += v
			else:
				pos += v
		if neg < 0.0:
			var b_rec := super.sparam(2)
			var eff_neg := cap_neg_hrg(neg - drop, b_rec)
			var w := warehouse_rate()
			return [pos * w * w + eff_neg, b_rec, true]
	return [self.hrg - drop if drop != 0.0 else self.hrg, self.rec, false]


## T405（D273）＋T456：按守层者／首领负再生上限夹住负再生率，先扣掉本回合 XExtDot 已用预算，确保 eff_neg × b_rec ≥ 剩余上限（合计最多扣 cap% 最大生命，不吃正再生）。
func cap_neg_hrg(eff_neg: float, b_rec: float) -> float:
	var cap := XTianqiCombat.boss_neg_hrg_cap(self)
	if cap >= 0.0:
		return eff_neg
	var used := XTianqiCombat.dot_budget_used(self)
	if used > 0.0:
		var left := maxf(0.0, floorf(float(mhp) * -cap) - used)
		if left <= 0.0:
			return maxf(eff_neg, 0.0)
		cap = -left / maxf(1.0, float(mhp))
	if is_equal_approx(b_rec, 1.0):
		return maxf(eff_neg, cap)
	if b_rec > 0.0 and eff_neg * b_rec < cap:
		return cap / b_rec
	return eff_neg

func param_now(i: int) -> float:
	var v := param_base_unscaled(i) + param_plus(i)
	v *= (param_rate(i) * float(_rates[i])) * param_buff_rate(i)
	v += param_state(i, v)
	return roundf(clampf(v, param_min(i), param_max(i)))

## 守层者成长招削弱（XGuardianRework.GROWTH_NERF）：正向强化每层 +12%、最多 3 层；负向、别的敌人照原版
func param_buff_rate(i: int) -> float:
	if buffs[i] > 0 and XGuardianRework.growth_on(self):
		return buffs[i] * XGuardianRework.GROWTH_LAYER_PCT / 100.0 + 1.0
	return super.param_buff_rate(i)

func buff_limit(pid: int, positive: bool) -> int:
	var v := super.buff_limit(pid, positive)
	if positive and XGuardianRework.growth_on(self):
		return mini(v, XGuardianRework.GROWTH_CAP)
	return v

func trait_objects() -> Array:
	var out := [data()]
	out.append_array(states())
	out.append_array(floor_states())  # CP_StateFloor：隐月多出的层
	return out

## Game_Enemy.replaceAttackSkillId：状态 → 敌人
func replace_attack_objects() -> Array:
	var out := super.replace_attack_objects()
	out.append(data())
	return out

## Game_Enemy.weaponUnleashes：状态 → 敌人
func weapon_unleash_objects() -> Array:
	var out := super.weapon_unleash_objects()
	out.append(data())
	return out

## 敌人可用的技能对象（来自行动列表），伤害结算按 objects() 扫描标签时会用到。
## Game_BattlerBase.addParam：敌人也有 _paramPlus（太极破坏 2003），只活在这场战斗
var added_params := {}

func param_plus(i: int) -> float:
	return super.param_plus(i) + float(added_params.get(i, 0.0))

func add_param(i: int, value: float) -> void:
	added_params[i] = float(added_params.get(i, 0.0)) + value
	param_mark_dirty()


func skills() -> Array:
	var out := []
	for a in data().get("actions", []):
		var s := XDB.rec("Skills", int(a.skillId))
		if not s.is_empty() and not out.has(s):
			out.append(s)
	return out

func exp_reward() -> int:
	if zq_weapon_trial:
		return 0
	return int(float(data().get("exp", 0)) * (elite_param(2) if elite else 1.0))

func gold_reward() -> int:
	if zq_weapon_trial:
		return 0
	return int(float(data().get("gold", 0)) * (elite_param(3) if elite else 1.0))

## 掉率倍数（神话 ×5）
func drop_rate_bonus() -> float:
	return elite_param(4) if elite else 1.0

## YEP_X_VisualHpGauge Game_Enemy.hpGaugeVisible（Defeat First=false，Show Always 不影响本判断）：
## 隐藏成员 → 无；备注 <HIDE HP GAUGE> → 无（两个标签都写时 HIDE 先判，赢）；<SHOW HP GAUGE> → 有。
## 默认参数下 SHOW 与不写等价（只在 Defeat First 打开时才有区别）。Olivia 名字窗口不看它，名字照常。
func hp_gauge_visible() -> bool:
	if hidden:
		return false
	return RegEx.create_from_string("(?i)<HIDE HP GAUGE>").search(str(data().get("note", ""))) == null


func race_ids() -> Array:
	var out := []
	for m in RegEx.create_from_string("(?i)<EnemyRace\\s*:\\s*(\\d+)\\s*>").search_all(str(data().get("note", ""))):
		out.append(int(m.get_string(1)))
	return out


## dsPassiveSkill Game_Enemy.refreshPassiveCache：只有元素减伤。扫描行动列表里的技能（Game_Enemy.skills 按行动逐条，
## 同一技能出现几次就算几次，如十七层妖精的「伤害抵抗(1000)」）与状态，不扫敌人自身备注。
func refresh_passive() -> void:
	var c := {"harmRe": {}, "globalHarmRi": 0.0, "critHarmRi": 0.0}
	var objs := []
	for a in data().get("actions", []):
		var sk := XDB.rec("Skills", int(a.skillId))
		if not sk.is_empty():
			objs.append(sk)
	objs.append_array(states())
	for o in objs:
		for m in XActor._scan(str(o.get("note", "")), "<passiveHarmRe(\\d+):\\s*([\\d.]+)>"):
			c.harmRe[int(m[0])] = c.harmRe.get(int(m[0]), 0.0) + float(m[1])
	c.harmRe = XGuardianRework.harm_re(self, c.harmRe)  # 守层者重算（O-402）：按层换伤害抵抗
	output_scale = XGuardianRework.atk_scale(self)  # 守层者重算：按层的出伤倍率（鸿钧、七印里副本、七首之龙换记录后重刷时也跟着改）
	var fz := XGuardianRework.focus(self)  # T239（D248 C）：集火招单独倍率
	focus_skill = int(fz.get("skill", 0))
	focus_scale = float(fz.get("scale", output_scale))
	focus_single = bool(fz.get("single", false))
	_passive_cache = c
	_passive_sig = _passive_signature()

## v0.62 dsPassiveSkill 被动缓存生命周期（v0.51 起）：addState／removeState／eraseState／clearStates 置脏，
## 下一次 refresh 前按签名（状态列表＋敌人编号）重建；敌人没有角色那道 okadd 门。这里读缓存时比签名，
## 状态变了就重建（v0.28 敌人只在开战时建一次，战斗中挂的「七星续命」passiveHarmRe 不生效）。
var _passive_sig := ""

func _passive_signature() -> String:
	return "%d|%s" % [enemy_id, ",".join(state_ids.map(func(x): return str(x)))]

func passive_cache() -> Dictionary:
	if _passive_cache.is_empty() or _passive_sig != _passive_signature():
		refresh_passive()
	return _passive_cache


static func _standalone_random() -> XRandomStream:
	return XRandomStream.create(XRandomStream.hex64(XState._fresh_seed()), "standalone_enemy")


## 这一招对我方 HP 伤害／吸取最后乘的倍率：集火招乘 focus_scale，其余乘 output_scale（XDamage.finish）
func skill_scale(item: Dictionary) -> float:
	return focus_scale if focus_skill > 0 and int(item.get("id", 0)) == focus_skill else output_scale
