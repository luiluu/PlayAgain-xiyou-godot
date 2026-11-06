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
- 第二轮：`modes/xiyou/core/shield_ledger.gd`（`ACTOR_HP_LEDGER`、`hp_gain`）、`core/resource_context.gd`（gainHp／setHp 两处改调 `hp_gain`）、`battle/battle_logic.gd`（`_push_rows`、`sequence_gain`、`_regenerate` 一处）、`core/actor.gd`（10455）。

## 验证

- `语法检查.py` 通过。
- `xiyou_rules`：61678/61678（本机，新源产物，`--skip-generated-check`：本树产物克隆自集成分支，跟主工作区旧源产物本来就不同）。
- 云端（运行 42193458592，提交 c35a3d00 之上的交付单 WIP 提交，产物快照 `refs/ci/generated/cc/rules-newsrc1`＝集成分支新源产物）跑 69 个场景：**`xiyou_rules`～`xiyou_rules_d6*` 全部 64 片通过**，`xiyou_multi_element` 通过。没过的 4 个都不是本单改坏的，见下：
  - `xiyou_rules10` 86/90：`floor.2521.false.1/5/10`（开关关时隐月 2521 暴击率 Godot 0.21／0.29／0.39，参照 0.19）与 `floor.2521.db_untouched`。即派单说的「rules10 那 4 项」，样本已拿到，没修（留下一单，见「没做」）。
  - `xiyou_imported_balance` 224/230：6 项都是 141 的持续伤害例（`dot.a141.*`、`dot.rec.a141.*`）。参照里 hrg 为 0、HP 不掉：新源 141 进了禁用名单，它的行动对目标无效，中毒根本挂不上；测试是按夹具直接给 Godot 挂状态再重放，所以 Godot 照常掉血。要改测试（禁用角色的 DOT 例按「挂不上」比，或探针换一个未禁用的导入角色），不是倍率问题。
  - `xiyou_item_use` 11/12：`ce_items_count` 1037≠1029，测试里写死的公共事件物品数，新源多了 8 件（内容数量变化，改断言即可）。
  - `xiyou_module_hooks` 1309/1311：`view.same_source`、`oracle.native_registry`，来源身份夹具还是旧源（同集成分支表一的「只挂 source」一类），要在新源上重出夹具。

## rules10

（第二轮更正）上面的初判不对：不是层数口径，是新源把 2521 的数据改成了 +2%，见第二轮表。

## 第二轮（CM 补 8 项＋上轮遗留 4 项，基于集成分支 31d0628a）

| 项 | 结论 | 改了什么 |
|---|---|---|
| power_books／_boundary／_menu、book_capacity | 新源 `installIntegratedV029Runtime` 的 `Game_Actor.setup` 包装：开放专武（武器备注 `<req_actors>` 列着、角色有名字且不在停用名单）的所属角色开局学 10455「专武·特效吸取」；`installBalanceShopV041Runtime` 的 `skills()` 包装在背包和全体角色身上都没有本人开放专武时不列 | `actor.gd`：`AFFIX_ABSORB_SKILL`、`absorb_owners`、`is_absorb_actor`、`has_absorb_weapon`，`setup` 末尾学、`skills()` 过滤。顺带修好 actor_p0 的 passive_104／163、skills_104 |
| passive_content（书 1652／2237 +3.75%） | 合并第一轮（growth 等）后本机重跑已全过（113142/113142），不用另改 | 无 |
| battle_gaps | 新源多 10462 诛天（`<MP Cost: 15%>`），百分比 MP 技能 43→44，这 5 例本身都过 | 测试计数 44、cost 44×5+2 |
| pushstate 6706 | 新源 v0.62.02：治疗（结算值为负）时 recPushStates 只给行动者友方（`target.isActor()===subject.isActor()`），打吸收属性回血的敌人不挂也不掷 | `battle_logic.gd` `_push_rows` |
| xuan_auto 力壁 | **新源原版代码错误**：流萤运行时（模块序 33）在 `Game_Actor.prototype` 上自定义 `setHp`，捕获的是护盾账本（序 41）包装前的函数；krz 的 `Game_Actor.gainHp` 也捕获插件期原函数。角色的 gainHp／setHp 两条都绕过账本：行动序列 HP -x%、持续伤害、直接设生命不扣璃壁等期限护盾，原生 ShieldSystem 读到子类 getter 的合计、按合计白挡、只扣原生那份（同 O-144 的白挡）。executeHpDamage 和敌人不受影响 | 可撤回开关 **O-212** `XShieldLedger.ACTOR_HP_LEDGER`（默认 true 照旧源经账本；false 照新源）。`shield_ledger.gd` `hp_gain`，gainHp／setHp 四个入口改调它。xuan_auto 比参照时设 false，另加 `_check_actor_hp_ledger` 三例自查默认支（值取旧源 v0.28 参照）。登记状态「待用户确认」 |
| imported_balance 141 DOT 6 项 | 141 进停用名单，参照里 141 的行动（applyItem）附加不上中毒；测试原来直接给 Godot 挂状态 | 测试：禁用角色作附加者时改查 `blocks` 并跳过挂状态 |
| item_use | 新源公共事件物品 1029→1037（数据实数，新源 Items.json 数出来 1037） | 测试计数 |
| rules10 2521 关闭支 | 不是层数问题：新源 2521 的数据本身已从 +0.2% 改成 +2%，O-181 的回退支（读数据库）现在也是 +2% | 测试两支都按 +2%、`db_untouched` 改 0.02；O-181 登记注明两支同值、可考虑退役 |
| module_hooks | `oracle.native_registry`：新源钩子表 11 位多了 liuying，orb-sets 19→20；`view.same_source`：`module_equipment_view.json` 六档 elementBonus 跟新源 cat.json `stats.sword671` 逐项相同，只换 runtimeInputs | 测试下标、夹具来源 |
| 顺带 | actor_p0 的 recruit_141／146／152／161／166：新源这 5 人进停用名单（V029 hiddenActors），重制 `add_actor` 本来就拦停用角色，测试改成「不入队」；raven_reflect 的 0.002 写死改读数据库 | 测试 |

### 验证（本机，新源产物，`--skip-generated-check`）

- `语法检查.py` 通过。
- 目标 11 个场景（power_books×3、book_capacity、passive_content、xuan_auto、battle_gaps、pushstate、imported_balance、item_use、rules10）＋ module_hooks、shield_ledger、item_bag、xuan_bind 全过。
- actor_p0 剩 1 项 `horn_paths_all_covered`（伙伴号角：流萤 3063，新角色流萤没移植，A 内容）。
- 改前改后同样失败、不是本单造成的：`xuan_battle`（source＋cleanse.hard／soft）、`book_capacity_ui`（source）、`raven_reflect`（reffloor 5 项）：三份夹具都还是 v0.28，要在新源上重出（工具／哪吒）；raven_reflect 重出后 0.002 那处已改读数据库。
- `事件空绿扫描.py --check`：退出 1、4739 条 ✗，跟改动前（stash 后同命令）输出逐字相同；全是 event_states 产物与预设对不上（本树产物克隆自集成分支），本单没碰事件。
- 之后 merge 集成分支 1eae323d（哪吒 newsrc2 新夹具），合并提交 62388d6c；冲突两处（item_use 计数注释、module_equipment_view.json）都取集成分支版（夹具改用哪吒重出的 cat_probe 版，内容同）。合并后本机重跑 module_hooks、xuan_battle、book_capacity_ui、item_use、xuan_auto、power_books、imported_balance 全过；actor_p0 只剩流萤号角 1 项；raven_reflect 夹具仍是 v0.28，reffloor 5 项待重出。
- 云端：fdde72b1（合并前）跑选测 310 个场景（运行 42199064992），结果见下。

## 接续

- 本分支已推 GitHub；合回集成分支前看云端结果。

## 没做、留给下一单

- C 规则另 43 个场景（派单说下一单）。其中会被本单影响、要一起看的：`difficulty_troop`／`difficulty_enemy`／`difficulty_actor` 三个探针也读 `b.cnt`，Godot 那边的快照若用 `xparam(6)`，反击率大于 1 的敌人会差；`imported_balance_probe` 的参照要在新源上重出（倍率全 1）。
- 引擎核心 v0.35 另一处：`rpg_managеrs.js` 反击「先承伤后返回实际受击者」（`invokeCounterAttack` 返回 realTarget），本单没碰 `battle_logic.gd` 反击段。
- `CodexImportedEffects` revision 2（恢复 12.27 缩减的专属效果系数）：重制本来就没移植效果补丁，数据直接用库里的，不受影响；`CodexPierceV058` 是旧档迁移，重制不迁移 MV 旧存档。
- 诛仙 162 同源被动只留最高档（v0.08）新源已删，重制原本就没移植，不用动。

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】新源伤害规则追平：穿透打抗性、导入角色解除缩放、属性转换攻守分算、反击概率封顶（dev.待定）

见本交付单「结论」四条；`xiyou_rules` d1 第 0 份 49142 → 61678/61678。云端集成分支 189 失败表里 rules 那行「成长乘区」的初判更正为上面四条。核查：待 Codex。

## 2026-11-06 【cc·rules·未经审查】新源补单：专武·特效吸取开局学、治疗挂状态只给友方、角色掉血绕过护盾账本做成可撤回开关 O-212（dev.待定）

见本交付单「第二轮」表。O-212 待 Kyo 确认（默认照旧源：角色持续伤害／行动序列扣血先扣璃壁等护盾）。核查：待 Codex。

## 交接板

- 下一步：见「接续」。
- 用户试玩说明：新源口径下，穿透装备／被动对有抗性的敌人更有效；导入角色（141～166）伤害不再被压到 1%；停用角色多了 5 个。
- 需要用户决定：O-212（新源里角色的持续伤害、行动序列按比例扣血、直接设生命绕过了璇的璃壁等护盾，看起来是流萤更新的装载次序副作用；重制默认保留「护盾照挡」，开关可回原版）

## 进度账

- 无（集成分支追平，不改进度）

## 可优化（流程／工具／效率）

- 建议：`xiyou_rules` 失败只打印前 12 条，按角色归类要临时改测试；加个环境变量（如 `RULES_DUMP=<路径>`）把全部不符写成 JSON，省一轮手改（C 规则车道，小）。
- 建议：`云端选测.py` 的 `--scenes` 只认带 `.tscn` 的名字，不带时静默变成 0 个场景、运行显示成功；改成自动补后缀或空选时报错（工具／哪吒，小）。
- 建议：集成分支的 189 失败表初判按日志前几条样本写，rules 这行就判错了方向；以后初判最好标「未在本机重跑」并附一条样本的分项对比（已在表头注明过，这里再提一次）。

- 建议：`has_absorb_weapon` 每次 `skills()` 都扫背包和全体角色装备（只对学了 10455 的角色），原版按背包修订号缓存；背包很大时可加同样的缓存（rules，小）。
- 建议：`事件空绿扫描.py --check` 在工作树里因 event_states 产物克隆自集成分支恒报 4739 条，车道交付时只能比对改前改后；可加 `--baseline <文件>` 只报新增（工具，小）。

## 本分支提交

- c35a3d00 rules 新源追平：穿透作用于元素抗性、导入角色解除缩放与禁用名单更新、属性转换攻守分算、反击概率夹 0～1
- fdde72b1 rules 新源补单：10455、RecPushState 只给友方、O-212 角色掉血绕过护盾账本、测试口径与来源夹具
