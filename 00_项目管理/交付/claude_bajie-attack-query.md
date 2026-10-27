# 交付：claude/bajie-attack-query

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_77）
- 状态：进行中
- 基线：按派单从 928ab678（star-warehouse 交付点）开，带着 ce-fix2、petsynth、star-warehouse 三个分支的提交。
- 来源：沙僧 review-pending 的 P2-1（核查报告_20261024_全部待审.md）。原版演员 154 装武器 77 时，实际攻击是 5769，逆骨未就绪；Godot 把攻击固定为 1，误判就绪。

## 接力交接（八戒_77 到上下文 40% 交出；还没改任何代码）

### 已查清的原版行为

- YEP_WeaponUnleash `attackSkillId()`：先看缓存 `_replaceAttackSkillId`（`refresh` 时清掉），再看 `replaceAttackSkillId()`，都没有就是 1。
  - 角色的查找顺序（`Game_Actor.replaceAttackSkillId`，YEP_WeaponUnleash.js 691～711 行）：`states()` → `equips()` → `skills()` → `currentClass()` → `actor()`，第一个带 `<Replace Attack: x>` 的生效。
  - 敌人（812 行）：`states()` → `enemy()`。
  - 备注写法是 `<Replace Attack: id>`，也可以写技能名；`<Custom Replace Attack>` 是 eval，数据里一次也没用到。
- 冻结数据里带 `<Replace Attack>` 的：武器 154 件（77→5769、78→5564、79→6289、83→5769、93→5636、12／25／38／51／341→12……）、状态 12 个（66／125→562、120／121→1199、1309→7317、1335→7508、2630～2633→10216～10219、2681→10301、2697→10333）、防具 2 件（4541→7313、4996→8087）、技能 25 个（2071→2067 等）。职业和角色一个都没有。还要查一下有没有写技能名、不写数字的。
- Codex 运行时又包了两层：`installNativeTojiRuntime.js` 65 行（甚尔，按形态返回 MAIN[形态]）、`installNativeSukunaRuntime.js` 160 行（宿傩 → 10238）。
- 原版用到攻击号的地方：
  - 指令窗的「攻击」（`addAttackCommand`）、`Game_Action.setAttack`（自动战斗和不能用技能时的退回）。
  - `Game_Action.isAttack()`（`item === $dataSkills[subject.attackSkillId()]`）：普攻追加次数 numRepeats、performAction 的武器动作都看它。
  - installCombatPowerRuntime（战力）、Codex_SmartBattleAI、XdRs_HangUp、KMS_SkillLevel、Olivia_AntiPlayerStress、Olivia_BattleSysOTB。
  - installAlienationAffixes 12～13 行：祈祷、逆骨的就绪判断用 `actor.attackSkillId()`。
  - 还有种族、BindingCharge、Guidance、Tusu、Yunshang 几个运行时。

### 重制现状

- 完全没有 ReplaceAttack：「攻击」一律用 `XBattleLogic.ATTACK_SKILL`（1），没有任何代码读 `<Replace Attack>`。
- 写死 1 的地方：
  - `alienation.gd:379`（P2-1 本身）。
  - `battle_scene.gd` 714（指令窗）、764（选攻击目标）、1134（武器动作）。
  - `battle_logic.gd` 458（敌人退回）、505、569（decide）、1153（不能用时退回）、1173、1184（普攻追加次数）。
  - `smart_ai.gd` 160、374；`hang_up_auto.gd` 57、180；`power.gd` 538、552、671。
  - `race_battle.gd` 186、266、455；`cat.gd` 402；`sequence_player.gd` 560。
- 每一处要对照原版那一处读的是 `attackSkillId`／`isAttack`，还是写死的技能 1，再决定改不改。

### 建议做法（给接手者）

1. **先做 RED**：新探针 `03_转换工具/mv_oracle/attack_query_probe.cjs`，写法照 `alien_config_probe.cjs`：卸下装备、学技能，用 `A.ready`，只写 `.sandbox/`。
   - 用例：154＋武器 77（攻击 5769，逆骨／祈祷的 ready）；状态 66、120 盖过武器；防具 4541；技能 2071；同时有状态和武器时看先后；敌人带状态；甚尔、宿傩。
   - 每例记 `attackSkillId`、`isAttack`（拿替换后的技能和技能 1 各问一次）、numRepeats、两种异化的 ready。
   - 新专项 `xiyou_attack_query`，在旧实现上先失败。
2. **统一查询**：`XBattler.attack_skill_id()`（XActor、XEnemy 各自覆盖，按上面的顺序，甚尔、宿傩的运行时也包进来）＋ `is_attack(skill)`。然后把上面那些写死 1 的地方逐个按原版改。
3. **验证**：新专项、`xiyou_alien_*`、`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d`。战力、智能 AI、挂机、猫都会受影响，加跑 `xiyou_power*`、`xiyou_smart_ai*`、`xiyou_hang_up*`、`xiyou_cat`。
4. 要改的原沙僧核心文件：`battle_logic.gd`、`battler.gd`／`actor.gd`、`enemy.gd`。改了要在「待交叉核查」逐个点名。

## 变更记录草稿

（待写）

## 验证

（待写）

## 本分支提交

（待写）
