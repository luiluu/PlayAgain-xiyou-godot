# 交付：claude/bajie-attack-query2

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_77）
- 状态：可合并
- 基线：按派单从期一交付点 f7eb5154（claude/bajie-attack-query，未合）开，含期一全部提交；交付前已合 main（6ecdcef7）。
- 本期：期一交付单「期二清单」逐处对照原版接到统一查询；期一「可优化」里的 can_use 禁用角色一并修（小，一行）。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】普攻技能统一查询期二：写死技能 1 的下游接到 attack_skill_id／is_attack；can_use 禁用导入角色（dev.待定）

1. **逐处对照原版后改用统一查询**（原来都写死技能 1）：
   - `battle_logic.gd`：角色手动「攻击」（decide 非自动分支）、自动战斗最后的退回（XdRs_HangUp makeAction：setSkill(attackSkillId)）、execute 不能用时退回、反击（BattleManager.invokeCounterAttack：反击者 setAttack，读**反击者**的 attackSkillId）、敌人没有可用行动时的退回（见遗留 1）都改 `X.attack_skill()`。
   - `hang_up_auto.gd` scheduled_skill：排表写 1 时与退回都给 `a.attack_skill()`（原版 IsRepSkill = attackSkillId）；`bet_skills`（usaBetSkills）原版就写死 1、2，不改，注释写明。
   - `smart_ai.gd`：预估次数改 `XBattleLogic.attack_repeats`（原版 action.numRepeats，isAttack 看 attackSkillId；也顺带把追加次数从 traits 和改成 attackTimesAdd 的不小于 0）；攻击候选改 `actor.attack_skill()`（chooseScored 的 $dataSkills[attackSkillId]，最后的「打血最少的」退回同用它）。
   - `power.gd`（installCombatPowerRuntime）：攻击技能、repeatCount 的追加次数（`item.id===a.attackSkillId()` 加 attackTimesAdd）、screen 的普攻保底都按替换后的技能。
   - `battle_scene.gd` _perform_action：武器动作改 `a.is_attack(skill)`（Game_Actor.performAction 的 action.isAttack()）。
   - `sequence_player.gd` _cast_animation：施法动画跳过改 `user.is_attack(skill)`（YEP_BattleEngineCore `!isAttack()&&!isGuard()`）。
   - `cat.gd` native_repeats：普攻追加次数改 `a.is_attack(item)`（Game_Action.numRepeats）。
   - `race_battle.gd`：weaponMatches 的普攻恒匹配（`x.isAttack()||id===attackSkillId`）、鬼族残响判定与 ghostCurrent 记录的「不是普攻」（`!x.isAttack()`）都改 is_attack。
2. **`XBattleLogic.can_use` 禁用导入角色全否**（installImportedBalanceRuntime 包了 canUse：`!isDisabledActor(this) && …`）：原来只在行动时由 blocks 挡，指令窗「攻击」、智能 AI 选招仍按可用算。禁用号角那半没加：重制 execute 遇到不能用会退回攻击，而原版是整次行动无效，加了反倒走偏，列遗留 2。
3. **原版探针 `attack_query_probe.cjs` 补测量**（30 例）：每例加 `setAttack`（new Game_Action(b).setAttack() 的技能）、角色加挂机 `hangUpAction`（关智能 AI、没排表的 XdRs makeAction）与 `hangUpScheduled`（排表写 1）；新例 157＋武器 12（禁用角色：替换照样是 12，canAttack 与指令窗都不可用）。专项 `xiyou_attack_query` 对应比 decide／反击者的 attack_skill、auto_battle_action（关智能 AI，排表与不排表），313 项。
   - RED：撤掉本期 modes 改动跑同一专项，setAttack、hangUpAction、hangUpScheduled 共 8 项失败；只撤 can_use 那行，157 的 canAttack、command 两项失败。

## 遗留（对照中发现、本期不改）

1. **敌人没有可用行动**：原版 Game_Enemy.makeActions 列表为空时不设行动（这一轮什么都不做），重制退回普通攻击（本期只把技能 1 换成 `e.attack_skill()`）。改成不行动会动 xiyou_rules 的战斗参照，建议另开一单带探针做。
2. **禁用号角**：原版 canUse 对禁用号角也是否（物品窗灰、行动 isValid 为假整次跳过）；重制物品窗与 execute 退回逻辑都没跟，改法与 1 类似要动 execute 的「不能用」分支，一起做。
3. **YEP_WeaponUnleash 的 Weapon Unleash**（武器 `<Weapon Unleash x%: id>`，普攻时按几率换成别的技能，正式数据 10 余把武器）：重制完全没有，是独立功能，建议另派。
4. 未移植模块里读 attackSkillId 的：installNativeTusuRuntime（绑定中的涂苏攻击改成「归还」）、installNativeGuidanceRuntime／installNativeYunshangRuntime（伤害技能表加上攻击技能）、installNativeBindingChargeRuntime（合契改名）——随模块移植时补。KMS_SkillLevel 不在 plugins.js（未启用）；Olivia_AntiPlayerStress 的命中修正参数 Hit Rate Stacking=false（未生效）；OTB 回合预览期一已接。
5. 指令窗「防御」的 Replace Guard：正式数据里没有 `<Replace Guard>`，不做。

## 待交叉核查（点名原沙僧核心文件）

- `battle_logic.gd`：can_use 加禁用角色判定；enemy_action／auto_battle_action／decide／execute 退回／_invoke 反击 五处 attack_skill。
- 另改：`smart_ai.gd`、`hang_up_auto.gd`、`power.gd`、`battle_scene.gd`、`sequence_player.gd`、`cat.gd`、`race_battle.gd`；探针 `attack_query_probe.cjs`；专项 `xiyou_attack_query.gd`。

## 交接板

- 下一步：遗留 1＋2（敌人无行动、禁用号角的「不能用」分支，带探针）可派 C 车道；遗留 3 Weapon Unleash 另派。
- 用户试玩说明：装着「替换攻击」装备／状态的角色，在自动战斗、挂机排表写「攻击」、技能不能用退回时都使用替换后的技能；被反击时反击方用自己的替换攻击；替换后的普攻也有武器挥动动作、不放施法动画；战力、智能 AI 预估按替换后的技能算。
- 需要用户决定：无

## 进度账

- 战斗规则：普攻替换（YEP_WeaponUnleash Replace Attack）期一＋期二，重制里读攻击技能的下游全部接通；余下的是原版另外的行为差异（遗留 1～3）。

## 可优化（流程／工具／效率）

- 建议：`长任务.py start` 跑 `并行测试.py` 时，失败明细只在 stdout 末尾，进度行用回车覆盖，日志里看不到哪个场景失败；建议 `并行测试.py` 在没给 --log-dir 时默认写到 `04_验证/本地结果/` 下（或车道须知写明带 --log-dir）。预计省一轮 50 分钟的重跑；归工具车道。

## 验证

- 合 main：6ecdcef7（无冲突，带进 enemy_warehouse 探针）。
- 同步 `同步正式西游.py --accept-additions`：只跑改过的 attack_query_probe（executed 1、reused 58），测量不变，产物指纹已留。
- 专项＋必跑（`并行测试.py`，48 场景全过，2984 秒，无偶发）：`xiyou_attack_query`（313）、`xiyou_event_compare`（5）、`xiyou_smart_ai xiyou_smart_ai_b xiyou_smart_ai_c xiyou_smart_ai_d`、`xiyou_hangup xiyou_hangup_auto xiyou_hangup_options`、`xiyou_power xiyou_power_books xiyou_power_books_boundary xiyou_power_books_menu`、`xiyou_race_battle xiyou_race_menu`、`xiyou_cat`、`xiyou_battle_ui`、`xiyou_action_sequence`、`xiyou_battle.tscn`、`xiyou_imported_balance`、`xiyou_alien_battle`、`xiyou_sequence_visual`、`xiyou_attack_element`、`xiyou_enemy_warehouse`；改了普攻判定，`xiyou_rules` 全部 24 段：`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d xiyou_rules_d2 xiyou_rules_d2b xiyou_rules_d2c xiyou_rules_d2d xiyou_rules_d3 xiyou_rules_d3b xiyou_rules_d3c xiyou_rules_d3d xiyou_rules_d4 xiyou_rules_d4b xiyou_rules_d4c xiyou_rules_d4d xiyou_rules_d5 xiyou_rules_d5b xiyou_rules_d5c xiyou_rules_d5d xiyou_rules_d6 xiyou_rules_d6b xiyou_rules_d6c xiyou_rules_d6d`，全过。
- 说明：同一代码第一次跑同一组退出码 1，长任务日志只留了进度行（没带 --log-dir），看不到是哪个场景；当时主工作区同步并行在跑。带 --log-dir 原样重跑一次全过（flaky.jsonl 无新记录）。若沙僧想复核，重点看 xiyou_rules 各段与 smart_ai 在负载下是否超时。

## 本分支提交

- 3bd9e90b 期二：下游接统一查询、can_use 禁用角色、探针补例
- 584b60ba 合 main
- （本提交）交付单
