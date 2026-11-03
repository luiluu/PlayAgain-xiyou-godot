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

## installBossDifficultyRuntime：本场出战人数快照；倍率在原生缓存外结算。
var boss_strong_count := 0
var boss_difficulty_boss := false
var boss_hyper_armor := false
var _updating_boss_armor := false
static var _boss_ids := {}
const BOSS_ARMOR_STATE := 2651

static func deployed_strong_count(members: Array) -> int:
	return members.filter(func(a): return a is XActor and XItemMarks.is_super_strong(a.actor_id)).size()

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

static func boss_control_state(id: int) -> bool:
	var st := XDB.rec("States", id)
	if st.is_empty() or id in [1, BOSS_ARMOR_STATE]:
		return false
	return int(st.get("restriction", 0)) > 0 or RegEx.create_from_string("(?i)<BuffType:\\s*(?:沉默|封印|眩晕|睡眠|麻痹|混乱|魅惑|恐惧|冰冻)\\s*>").search(str(st.get("note", ""))) != null or st.get("traits", []).any(func(t): return int(t.code) in [42, 44])

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
	if XCat.trial_blocks_state(self, id):  # 小猫试炼 addState 包装：巨龙不吃难度状态
		return
	if boss_hyper_armor and boss_difficulty_boss and boss_control_state(id):
		return
	super(id, random)

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
	boss_strong_count = strong_count if strong_count >= 0 else (deployed_strong_count(XState.current.battle_members()) if XState.current != null else 0)
	boss_difficulty_boss = boss_id(id)
	boss_hyper_armor = false
	enemy_id = id
	difficulty_id = difficulty
	_rates = difficulty_rates(difficulty)
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
	return XDB.rec("Enemies", enemy_id)

func display_name() -> String:
	return XAlienBattle.name_prefix(self) + original_name() + letter + ("宝宝" if capture else "")

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
	var s := XState.current
	if s == null:
		return 1.0
	for k in range(1, 6):
		if bool(s.flags.get("DCultyL%d" % k, false)):
			return float(str(XDB.plugin("Star_Warehouse").get("DCL%d" % k, "1")))
	return 1.0

func xparam(i: int) -> float:
	return super.xparam(i) * warehouse_rate()

func sparam(i: int) -> float:
	return super.sparam(i) * warehouse_rate()

func param_now(i: int) -> float:
	var v := param_base_unscaled(i) + param_plus(i)
	v *= (param_rate(i) * float(_rates[i])) * param_buff_rate(i)
	v += param_state(i)
	return roundf(clampf(v, param_min(i), param_max(i)))

func trait_objects() -> Array:
	var out := [data()]
	out.append_array(states())
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
func skills() -> Array:
	var out := []
	for a in data().get("actions", []):
		var s := XDB.rec("Skills", int(a.skillId))
		if not s.is_empty() and not out.has(s):
			out.append(s)
	return out

func exp_reward() -> int:
	return int(float(data().get("exp", 0)) * (elite_param(2) if elite else 1.0))

func gold_reward() -> int:
	return int(float(data().get("gold", 0)) * (elite_param(3) if elite else 1.0))

## 掉率倍数（神话 ×5）
func drop_rate_bonus() -> float:
	return elite_param(4) if elite else 1.0

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
	_passive_cache = c

func passive_cache() -> Dictionary:
	return _passive_cache


static func _standalone_random() -> XRandomStream:
	return XRandomStream.create(XRandomStream.hex64(XState._fresh_seed()), "standalone_enemy")
