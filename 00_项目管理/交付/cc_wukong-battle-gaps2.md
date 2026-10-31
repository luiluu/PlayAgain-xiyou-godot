# 交付：cc/wukong-battle-gaps2

- 车道／工作者：C 规则（A 车道接）／悟空（cc）
- 基线：从 main dd374cdf（含 dev.239 hp-cost）切出；交付前合了 main 3226cc85。
- 状态：可合并

## 变更记录草稿

## 2026-10-31 【cc·悟空·未经审查】战斗经验与金钱照原版、防御给 TP（dev.待定）

- **战斗经验与金钱（白龙_6 dev.237 报的缺口，查下来比报的大）**：正式版 `BattleManager.makeRewards`（rpg_managers）是金钱 `goldTotal()×5`、经验 `expTotal()×8`；`Game_Enemy.exp／gold` 被后装的 EliteEnemy（插件表 146）改写成「数据库值 × 神话倍率」，Vitsuno_Difficulty（130）包的难度经验／金钱倍率被盖掉、**不生效**。参照 `reward.*`：难度 1／2／3／5／10／13 × 敌群 1／173／300，奖励完全相同。重制原来是「经验、金钱各乘难度 Drop Rate 前两项」、没有 ×8／×5（难度 3 普通是 4.5 倍、5～9 是 10 倍、10 起 1～1.6 倍；原版不分难度都是经验 8 倍、金钱 5 倍）。现在 `XBattleLogic.rewards`：
  - 经验：Σ `exp_reward()`（神话倍率在内）→ 套装（`XEquipSuits.reward` id 0）→ ×8。
  - 金钱：dsPassiveSkill 的 `goldTotal`：出战成员的每个 `passiveGRUP` 依次 `rate += v×0.01×rate`（原来取各人加总的最大值），`floor(Σ gold×rate × 金钱双倍)`（队伍能力 4，原来没算）→ 套装（id 1）→ ×5。累乘照原式写，连乘写法在末位差一点会差一档取整（金钱双倍用例差 5）。
  - 物品掉落 `_roll_drops` 没动（仍读难度第 3 项起，见「下期清单」）。
- **防御给 TP（八戒_92 黑闪期报）**：防御技能 2 的 tpGain 10，原版防御也对自己 `Game_Action.apply`，命中后 `applyItemUserEffect` 得 `floor(tpGain×tcr)`（gainSilentTp，不受上限 100 限制、按 maxTp 夹）。重制 `act` 的防御支不跑 `_apply`，没给。现在防御支在 `guarding = true` 后调新的 `_user_tp_gain`；普通技能的 tpGain 也改走它，补上原版的取整（原来 tcr 非 1 时带小数）。防御支没有本次行动的资源上下文，用 `_operation_resources`／`_finish_lifecycle_operation` 包一次。
- **宿傩专项去掉绕法**：`sukuna_battle_probe.cjs` 的 `guard` 步骤与 `tests/xiyou_sukuna_battle.gd` 都不再在防御后把 TP 定回 100；flash 剧本第 4 步起 TP 与依 TP 的技能条件（meets）随之改变，测量接受单 `04_验证/测量接受/cc_wukong-battle-gaps2.json`（1 条，script.flash observed）。
- **真气瓶颈之战奖励**：`tests/xiyou_zhenqi_break.gd` 原来因经验、金钱对不上只比物品数，现在 `break.fight.*` 的 rewards 整个比（经验 120000／124000、金钱 99750／103075 对上）。
- **参照**：`mv_oracle/battle_gaps_probe.cjs`（不接全量同步）加 21 例 `reward.*`（含 passiveGRUP 连乘、神话、金钱双倍）与 4 例 `guard.*`（TP 0／95、tcr 1.25／0.5），共 262 例；`tests/fixtures/battle_gaps_oracle.json` 已更新。`xiyou_battle` 的奖励断言改为 3×20×8。

## 交接板

- 下一步：无新增（期二谷雨 CFG.mp 只记，见下期清单）。
- 用户试玩说明：战斗经验固定为原版的 8 倍、金钱 5 倍，不再随难度变（以前随难度 1～10 倍）；多人带「金钱上升」被动时按原版依次累乘；队伍有金钱双倍时翻倍。防御一次回 10 TP。
- 需要用户决定：Vitsuno 难度表里配了各难度的经验／金钱倍率（难度 1 为 1.5，5～9 为 10，13～15 为 1.2～1.6），但在原版被 EliteEnemy 盖掉、从没生效过。我按原版改成不生效，没做开关；作者同一插件里亲手注掉了难度掉率那段，加上 makeRewards 写死 ×8／×5，看不出作者想让它生效。若想恢复难度倍率，告诉我，做成可回退开关再登记 O 号。

## 优化登记草稿

优化登记草稿：无。

## 进度账

- 战斗规则：结算奖励与防御 TP 两项对上原版，完成度不变（量小）。

## 下期清单

- 物品掉落疑似也有出入（只看了源码，**没有参照**）：原版 Vitsuno 的难度掉率那段被作者注掉，EliteEnemy 的 `dropItemRate` 是「物品双倍 ? 1 : 0.2」× 神话倍率；重制 `_roll_drops` 乘的是难度 Drop Rate 第 3 项起、没有 0.2 基础。要做 makeDropItems 的定向参照（固定 Math.random）再改。
- 伤害／治疗时挂状态没移植（查蔷薇时发现）：dsPassiveSkill 的 `<PushState N: p%>`（伤害为正时给目标）、`<RecPushState N: p%>`（为负时给目标）、`<PushsubState N: p%>`（伤害为正时给自己），技能 153、武器 95、防具 83 条备注，原版走 installDamageElementRuntime 的 makeDamageValue 包装（`result._after`，结算时按 makeDamageValue 的正负挂，只认角色行动者、异化虚空攻击除外）。重制全工程没有这套，蔷薇刺鞭破防、蔷薇进阶等都不生效。照原版移植（含原版治疗时不看目标是不是我方，Kyo：线上那个 bug 不归我们管），请总装排期。
- O-129（Kyo 定：做）：7225 降众天华 `<MP Cost: 7.5%>` 认小数、按最大 MP 7.5% 收，做成可回退开关。总装七派来时本批选测已跑完，按总装说的放下一批。
- 总装六加的第 3 项「攻击敌人给敌人回血、治疗加成 buff 作用到对面」：就是 Kyo 11:54 报的蔷薇（蔷薇领域→DEBUFF之斩打免疫治疗属性的敌人变回血，RecPushState 1561 挂到敌人）。原版 installDamageElementRuntime 的治疗挂状态不看目标阵营（早期 dsPassiveSkill 有 `target.isActor()`）；重制没有这套，所以不会出。Kyo 12:06：「目前游戏的 bug 不是我们这边处理的，不用管」，本项不做。
- 谷雨按最大 MP 比例收费（installNativeGuyuRuntime 的 `CFG.mp`）：谷雨 175 不在切片、运行模块没移植，本期只记，谷雨上线时一起做。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 参照：`battle_gaps_probe` 262 例、`sukuna_battle_probe` 6 例，都无报错（正式冻结 v0.28）。
- 同步：`同步正式西游.py --accept-additions` 第一次退出码 2（只有 sukuna_battle.json 的 script.flash 变化，合预期）；生成接受单后带 `--accept-changes` 重跑，退出码 0，「显式接受 1 条既有用例改变」。
- 专项：`xiyou_battle_gaps` 1002/1002，`xiyou_sukuna_battle` 通过；奖励相关 `xiyou_battle`、`xiyou_zhenqi_break`、`xiyou_battle_events`、`xiyou_pet_capture`、`xiyou_poison_collapse`、`xiyou_determinism`、`xiyou_item_marks`、`xiyou_zhenqi_daofa` 15 个场景通过。反向：去掉防御支 TP，`xiyou_battle_gaps` 998/1002、`xiyou_sukuna_battle` 失败；金钱连乘写法 993/994（goldDouble 差 5）。
- 选测：本机 `检查.sh --oracle --affected dd374cdf` 全部通过（11496 秒，期间与另两条检查抢槽），含同源检查。
- 合 main（3226cc85，白龙 garou3 改了 battle_logic 与饿狼探针，无冲突）后：`--补齐`、带接受单重跑同步退出码 0；复跑 `xiyou_battle_gaps`、`xiyou_sukuna_battle`、`xiyou_battle`、`xiyou_zhenqi_break`、`xiyou_battle_events`、`xiyou_pet_capture`、`xiyou_raven_soul` 与 `xiyou_garou*` 共 15 个场景全部通过。
- 改动的原沙僧核心文件（请审查重点看）：`battle_logic.gd`（`rewards`、新 `_user_tp_gain`、`act` 防御支、`_apply` 的 tpGain）。没改 actor／battler／damage。

## 本分支提交

- c27ba294 战斗经验与金钱照原版；battle_gaps 参照加 reward.*
- e8c8f159 防御给 TP；battle_gaps 参照加 guard.*
- d8ee36de 宿傩专项去掉防御后定回 100 TP 的绕法
- 2cd2c797 宿傩 flash 剧本测量接受单
- 764946aa 交付单记伤害／治疗时挂状态缺口
- 9f76605b 合并 main（白龙 garou3）
