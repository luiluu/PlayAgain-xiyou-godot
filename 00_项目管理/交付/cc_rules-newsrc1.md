# 交付：cc/rules-newsrc1

- 车道／工作者：C 规则／rules（cc）
- 状态：进行中
- 基于集成分支 `cc/newsrc-switch`（cc69f998），交付合回集成分支，**不合 main、不标可合并给 main**。工作树里冻结正式源链接指向 `v0.62.12/app.nw`，转换产物与导入缓存克隆自集成分支工作树（新源产物）。

## 结论：「成长乘区 growth」初判不对

本机重跑 `xiyou_rules`（d1 第 0 份）复现云端 49142/61678。看样本后发现 `xiyou_rules` 本来就按「MV 值 ÷ growth」比较（测试头注释写着首期不移植 growth），growth 不是失败原因。实际是新源（v0.29～v0.62.12）在伤害链上的四处改动 Godot 没跟：

1. **百分比穿透也穿元素抗性**（`installDamageElementRuntime` `applyResistancePierce`）：攻击方被动缓存 `penetrateHarmRe.percent`（`<DepassiveHarmReXX: N%>`）按元素作用于目标 elementRate：0～1 之间 `1-(1-r)(1-通用穿透)(1-元素穿透)`；完全免疫（0）只有该元素穿透 ≥100% 才变 1；吸收不变。固定减伤穿透照旧。`dsPassiveSkill parseDepassiveHarmRe` 同时改成带正负号、同一对象内完全相同的标签只计一次。云端「d1 抗性 1.0≠0.8」就是这条。
2. **导入角色平衡解除**（`installImportedBalanceRuntime` v0.29／v0.36）：`outgoingRate` 恒 1（结算与持续伤害都不再 ×0.01／×0.001），共用伤害技能公式不再 ÷10；禁用名单扩成角色 141、143、144、145、146、152、157、160、161、166，号角 245、255、256、257、274、359、394、440、456、494。
3. **属性转换攻守分算**（`conversionId`／`originalElements`）：被动 `<DamageElements>` 转换时，目标侧（抗性、克制、固定减伤）按转换后属性，攻击方增伤、固定附加、独立乘区按技能原属性，多候选取最高；治疗的属性增伤改看原属性。
4. **反击概率夹 0～1**（引擎核心 `rpg_οbjects.js` v0.35 `cnt` getter）：`XBattler.cnt` 夹到 0～1，`xparam(6)` 本身不夹；`xiyou_rules` 的能力值快照第 6 项改读 `cnt`（参照 slice_probe 读的就是 `b.cnt`）。

结果：`xiyou_rules`（d1 第 0 份）49142/61678 → 61678/61678（先 61677，剩敌人 745 反击率 10 对 1，第 4 条修掉）。

## 改了哪些原沙僧核心文件（请沙僧重点核）

- `modes/xiyou/core/damage.gd`：`_resistance_pierce_by_element`、`apply_resistance_pierce`、`conversion_id`、`original_elements`；伤害循环改成「目标属性 × 原属性」两层；`_healing` 用原属性。
- `modes/xiyou/core/actor.gd` `refresh_passive`：穿透标签带正负号、同对象去重。
- `modes/xiyou/core/battler.gd` `cnt`。
- `modes/xiyou/core/imported_balance.gd`：倍率、÷10、禁用名单。

## 验证

- `语法检查.py` 通过。
- `xiyou_rules`：61678/61678（本机，新源产物，`--skip-generated-check`：本树产物克隆自集成分支，跟主工作区旧源产物本来就不同）。
- 云端（运行 42193458592，提交 c35a3d00 之上的交付单 WIP 提交，产物快照 `refs/ci/generated/cc/rules-newsrc1`＝集成分支新源产物）跑 69 个场景：**`xiyou_rules`～`xiyou_rules_d6*` 全部 64 片通过**，`xiyou_multi_element` 通过。没过的 4 个都不是本单改坏的，见下：
  - `xiyou_rules10` 86/90：`floor.2521.false.1/5/10`（开关关时隐月 2521 暴击率 Godot 0.21／0.29／0.39，参照 0.19）与 `floor.2521.db_untouched`。即派单说的「rules10 那 4 项」，样本已拿到，没修（留下一单，见「没做」）。
  - `xiyou_imported_balance` 224/230：6 项都是 141 的持续伤害例（`dot.a141.*`、`dot.rec.a141.*`）。参照里 hrg 为 0、HP 不掉：新源 141 进了禁用名单，它的行动对目标无效，中毒根本挂不上；测试是按夹具直接给 Godot 挂状态再重放，所以 Godot 照常掉血。要改测试（禁用角色的 DOT 例按「挂不上」比，或探针换一个未禁用的导入角色），不是倍率问题。
  - `xiyou_item_use` 11/12：`ce_items_count` 1037≠1029，测试里写死的公共事件物品数，新源多了 8 件（内容数量变化，改断言即可）。
  - `xiyou_module_hooks` 1309/1311：`view.same_source`、`oracle.native_registry`，来源身份夹具还是旧源（同集成分支表一的「只挂 source」一类），要在新源上重出夹具。

## rules10

样本见「验证」第一条：4 项都在 2521（镜流 10119 的隐月）开关「关」那一支：关时应恒 1 层（0.19），Godot 随层数涨。初判是新源里 2521 本身的数据／`PushsubState` 口径变了，`XBattler.FLOOR_YINYUE` 关闭分支没跟上；没在本单修。

## 接续（本会话到 40% 线停手，下一位接着做）

- 本分支已 merge 集成分支 020aab89（新夹具），合并提交 0e126d7d，还没在合并后重跑任何测试。
- 待做（总装补单「CM 补」）：power_books×4（新源开局多技能 10455）；passive_content 书 1652／2237 伤害 +3.75%；xuan_auto 力壁护盾；battle_gaps 新增 10462 百分比 MP（计数断言要改）；pushstate 6706 不再上 1561。另加本单留下的：rules10 四项、imported_balance 141 DOT 六项、item_use 计数、module_hooks 来源夹具。
- 本机测试槽挤时走云端：`gh workflow run godot-tests.yml -R luiluu/PlayAgain-xiyou-godot --ref cc/rules-newsrc1 -f mode=affected -f force=true -f scenes="<场景名.tscn 空格分隔>"`（**场景名要带 .tscn**，不带会被过滤成 0 个、整轮空跑）；推之前先 `python3 03_再刷重制_Godot/07_开发环境/云端选测.py upload --branch cc/rules-newsrc1`。
- 工作树环境是手搭的（没跑 `--补齐`，因为它会拿主工作区旧源产物覆盖）：冻结正式源链接指向 `v0.62.12/app.nw`，`generated`、`.godot`、`node_modules`、`.sandbox` 克隆自集成分支工作树。本机跑测试要加 `--skip-generated-check`。

## 没做、留给下一单

- C 规则另 43 个场景（派单说下一单）。其中会被本单影响、要一起看的：`difficulty_troop`／`difficulty_enemy`／`difficulty_actor` 三个探针也读 `b.cnt`，Godot 那边的快照若用 `xparam(6)`，反击率大于 1 的敌人会差；`imported_balance_probe` 的参照要在新源上重出（倍率全 1）。
- 引擎核心 v0.35 另一处：`rpg_managеrs.js` 反击「先承伤后返回实际受击者」（`invokeCounterAttack` 返回 realTarget），本单没碰 `battle_logic.gd` 反击段。
- `CodexImportedEffects` revision 2（恢复 12.27 缩减的专属效果系数）：重制本来就没移植效果补丁，数据直接用库里的，不受影响；`CodexPierceV058` 是旧档迁移，重制不迁移 MV 旧存档。
- 诛仙 162 同源被动只留最高档（v0.08）新源已删，重制原本就没移植，不用动。

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】新源伤害规则追平：穿透打抗性、导入角色解除缩放、属性转换攻守分算、反击概率封顶（dev.待定）

见本交付单「结论」四条；`xiyou_rules` d1 第 0 份 49142 → 61678/61678。云端集成分支 189 失败表里 rules 那行「成长乘区」的初判更正为上面四条。核查：待 Codex。

## 交接板

- 下一步：见「接续」。
- 用户试玩说明：新源口径下，穿透装备／被动对有抗性的敌人更有效；导入角色（141～166）伤害不再被压到 1%；停用角色多了 5 个。
- 需要用户决定：无

## 进度账

- 无（集成分支追平，不改进度）

## 可优化（流程／工具／效率）

- 建议：`xiyou_rules` 失败只打印前 12 条，按角色归类要临时改测试；加个环境变量（如 `RULES_DUMP=<路径>`）把全部不符写成 JSON，省一轮手改（C 规则车道，小）。
- 建议：`云端选测.py` 的 `--scenes` 只认带 `.tscn` 的名字，不带时静默变成 0 个场景、运行显示成功；改成自动补后缀或空选时报错（工具／哪吒，小）。
- 建议：集成分支的 189 失败表初判按日志前几条样本写，rules 这行就判错了方向；以后初判最好标「未在本机重跑」并附一条样本的分项对比（已在表头注明过，这里再提一次）。

## 本分支提交

- c35a3d00 rules 新源追平：穿透作用于元素抗性、导入角色解除缩放与禁用名单更新、属性转换攻守分算、反击概率夹 0～1
