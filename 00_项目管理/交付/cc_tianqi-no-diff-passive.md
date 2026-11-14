# 交付：cc/tianqi-no-diff-passive

- 车道／工作者：天启篇开局不发难度被动／cc（Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·天启篇·未经审查】天启篇开局不发难度被动，净效果并进数值表（O-待定，dev.待定）

- 依据：天启篇设计总览 v0.2 第二节「开局不再发任何难度被动」（Kyo 11-08 已定）；影响审查 v0.6 第二节前三行。
- 天启篇存档不再学「普通难度」5548、「难度适应」5980、「天道诅咒」6168：拦在 `XActor.learn_skill`（开局 learnSkill 5980、公共事件 1319、大厅 EV020 的 5548 都走这里），难度同步 `XState._difficulty_profile` 按开关 2491 补基础被动时也滤掉。开关 2491 等难度开关照旧开着，事件分支不受影响。
- 老天启篇存档：读档 `sync_difficulty_after_load` 开头 `XTianqiNoDiffPassive.strip` 剥掉已学的三个被动和留在身上的 1631／1691／995。西游档不动。
- 主要数值（伤害、治疗、敏捷、暴击、掉率、金钱）不变，但不是严格的全行为等价（见下面已知差别四项），净效果改读 `balance_table.json` 新节 `legacy_passive`：
  - 结算伤害：攻击方确认阶段（`XStateEffects.run "confirm"`）按原三个状态在状态表里的位置插入同样的 ceil 乘三步（正伤害 ×1.5、非零 ×5（连治疗）、正伤害 ×0.8，合计正伤害 ×6、治疗 ×5）。没并成 ×6 放进出伤乘区：那样取整、治疗 ×5、和因果丝线等别的确认乘区的先后都会变。因果丝线（1254／2709）照旧同一乘区逐个连乘，专项实测相等。
  - 敏捷：战斗中（`param_cache_on`）能力倍率特性加 −0.2（CP_StateFloor 下特性 21 本是加算），`XActor.traits_pi`。
  - 暴击率：`_xparam_now` 在 passiveXPBST 同一位置 +0.5。
  - 掉率、金钱 +10%：天启篇原本就不算（drop_table、金钱表的 ignore_skills），走 `scaling.reward` 难度倍率，这次不动。
  - 封印：坐骑封印天启篇本来不认（XTianqiGear），宝宝、圣器、形态三栏天启篇已删，没被动也无需替代。
- 已知差别四项（面板数值不变，行为有差，列给核查）：①身上少三个状态，按状态个数算的效果少算 3 个：三重气元拳 2386／2388 的 `user.states().length>=5` 多一段，虚无 1442／2522／2731 按目标状态数增伤（目标是敌人时不受影响）。②开战少掷三次「开战状态」随机数（100% 也要掷），同一种子后面的随机流错位，期望不变。③战斗外敏捷不再 ×0.8（原版首战后 995 留在身上，影响之后的先制／偷袭判定，略有利玩家）。④指南页「结算倍率」读技能备注，天启篇少显示这 ×6。
- 回退：`XTianqiNoDiffPassive.ENABLED = false`（照学三个被动、不加等价项、读档不剥）。本功能接管过的天启篇档（读档剥过的老档、开关开着新开局的档）在存档 `flags.tianqi.no_diff_passive＝1` 记标记；开关关掉读档时按原开局补回（有名字的角色全学，5548 看开关 2491、5980 看 2492／2491／2500、6168 看变量 14＝1），开战照原样挂 1631／1691／995，读完清标记；开→关→开往返不叠加、不丢。没标记的档开关关着不碰。补回后到下一场开战前，战斗外敏捷没有 ×0.8（同已知差别③）。
- 专项 `xiyou_tianqi_no_diff_passive` 176 项；`xiyou_tianqi_swap_init` 的夹具从普通难度 5548 换成虎狩 2122（天启篇学不到 5548 了）；`xiyou_gojo` 的真走 act 段临时关掉本功能、保留旧基线（夹具没跑开局，原来就不带难度被动；不是补跑开局）；五条悟在本功能开着时的伤害等价另在本专项实跑开局后断言（`op_gojo_equal`）。
- 玩家可见：天启篇战斗侧栏不再显示「难度适应」「破阵——天道诅咒」「普通难度·结算伤害」三个常驻状态，技能页不再有这三个被动；伤害、敏捷、暴击数值不变。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_no_diff_passive.gd`（钩子：`actor.gd` learn_skill／traits_pi／_xparam_now、`xstate.gd` _difficulty_profile／sync_difficulty_after_load、`state_effects.gd` run）；`tianqi_data/balance_table.json` legacy_passive；`tests/xiyou_tianqi_no_diff_passive.gd` | 天启篇借原版「普通」开局，全员学普通难度、难度适应、天道诅咒三个被动 | 天启篇不学、老档读档剥掉，结算伤害／敏捷／暴击的净效果改读数值表、在原位置原乘区生效，主要数值不变（四项已知差别见变更记录）；关开关读档补回被动 | 天启篇设计总览 v0.2 第二节（Kyo 11-08）；影响审查 v0.6；Kyo 11-11 优化直接接受 | `XTianqiNoDiffPassive.ENABLED = false` | cc | 保留 |

## 交接板

- 下一步：影响审查 v0.6「两份稿没对齐」第 1 条（开局不发难度被动）已落实，可从待办里划掉。
- 用户试玩说明：天启篇新开局后技能页没有普通难度／难度适应／天道诅咒，战斗侧栏也没有这三个常驻状态；打同一只怪伤害应和以前一样。老天启篇存档读档后同样没了。
- 需要用户决定：无（已定事项落实；`legacy_passive` 照原值等价搬过来，以后要调 ×6 等由数值线改这一节）。

## 进度账

- 无。

## 验证

- 语法检查（834 个 .gd，0 问题）、天启篇数据校验（含 `--params` 设计仓参数.json）、工具快速回归全部通过。
- 专项 `xiyou_tianqi_no_diff_passive` 106/106（本机）：
  - 一、学不到 6 项：`tianqi_learn_all_blocked`、`tianqi_ce1319_blocked`、`tianqi_profile_no_refill`、`switch_off_learns`、`xiyou_learns`、`xiyou_load_untouched`。
  - 二、等价：`eq_*` 15 项（攻击 1、魔法 902／908 各暴击／不暴击 6 项，治疗 8／335，敌人打角色，战斗中敏捷，暴击率，掉率加成，难度掉率倍率，金钱加成；伤害、治疗、敏捷完全相等，小数项容差 1e-9）；`chain_1254_*`、`chain_2709_*`、`chain_1254_2709_*` 各 15 项（和因果丝线连乘）＋3 项 `chain_bites_*`；`jiusi_*` 15 项；`bites_damage_x6`、`bites_heal_x5`、`bites_agi`、`bites_crit`（新做法和「什么都不乘」确实不同）；`switch_off_bare`、`xiyou_untouched`、`fixture_clean`。
  - 三、老存档：`old_save_stripped`、`old_save_battle_sync_no_refill`、`old_save_*` 15 项（读档后和旧做法相等、没叠两遍）、`old_save_strip_idempotent`。
  - 四、实跑开局：`opening_hub_reached`、`opening_no_passive`（全部有名字的角色都没学）、`opening_first_slot_skills_kept`。
- `xiyou_tianqi_swap_init` 通过。
- 选测（云端，`选测.py main` 选中 546 个场景，含 xiyou_rules 全部段、xiyou_determinism、事件对照；提交 24c2ea28a，运行 43558674625）：545 过，`xiyou_gojo` 2 项挂（`act_red_free`、`act_reverse_heals`）。原因是夹具没跑开局、五条悟原来就没学难度被动，现在天启篇档按数值表结算 ×6，苍一下打死敌人、后面几招没对象；真实开局里五条悟本来就带 ×6，不是机制问题。修法：`xiyou_gojo` 的 `_real_turns` 段临时关 `XTianqiNoDiffPassive.ENABLED`，保留旧基线（那段测的是五条悟花费与印记；不是补跑开局），本机重跑 `xiyou_gojo` 73/73、本专项 106/106。
- 没跑 `--oracle`：原版移植的难度同步只在天启篇档多一层过滤（`on()` 为假时原样返回），西游档路径不变；云端选测已含 xiyou_rules 全部段和同源检查场景。
- 改到的战斗核心文件（请核查重点看）：`actor.gd`（learn_skill 拦截、traits_pi 覆写、_xparam_now 暴击）、`state_effects.gd`（确认阶段插行）、`xstate.gd`（难度同步过滤、读档剥离）。没碰 damage.gd、battler.gd、tianqi_horsemen.gd、tianqi_affix_battle.gd、tianqi_qiyin_*。

## 核查返修

- gpt 甲档核查 P2（`core/tianqi_no_diff_passive.gd`）：strip 永久忘掉三个被动、删 995 等，没有迁移记录也没有反迁移，开关关掉回不到原行为（公共事件 1319 不会再发 6168，难度同步补不回 6168）；开关开着新建的档同样回不去。
  - 修法：存档记迁移标记 `flags.tianqi.no_diff_passive`（读档剥离时、开关开着新开局时记）；读档入口改成 `XTianqiNoDiffPassive.sync_after_load`：开关开＝剥离＋记标记，开关关且有标记＝`restore` 照原开局补学三个被动＋清标记。剥／补都看「有没有」，往返不叠加。新开局记标记在 `XTianqi.start_new_game`（`mark_new_game`）。
  - 测试（`xiyou_tianqi_no_diff_passive` 106→176 项，新增 70 项）：
    - ① 老档开→存→关→读：`rb_on_marked`、`rb_off_restored`、`rb_off_start_tags`、`rb_off1_*` 15 项（伤害、治疗、敏捷、暴击、掉率、金钱和旧做法相等）。
    - ② 实跑开局建的档关开关回退：`op_marked`、`op_off_restored_all_named`（全部有名字的角色补回三个）、`op_off_*` 15 项、`op_off_gojo_equal`。
    - ③ 往返两次不叠加：`rb_on2_stripped`、`rb_on2_*` 15 项、`rb_off2_once`、`rb_off2_states_once`、`rb_off2_*` 15 项、`rb_off_again_noop`、`rb_unmarked_untouched`、`op_roundtrip_once`。
    - 五条悟集成：`op_gojo_clean`、`op_gojo_equal`：实跑开局后入队、本功能开着，普攻、苍、赫的伤害和旧做法（学被动挂状态）完全相等。
  - 交付单措辞：xiyou_gojo 改写成「临时关闭本功能、保留旧基线」；已知差别写全四项（含指南页少显示 ×6），不再说成严格全行为等价。
  - 提交：见「本分支提交」。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 24c2ea28a WIP: 天启篇开局不发难度被动（XTianqiNoDiffPassive）＋专项
