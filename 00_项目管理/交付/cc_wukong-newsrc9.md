# 交付：cc/wukong-newsrc9

- 车道／工作者：DF 流萤与角色零散（换源 v0.62.12；cc，悟空）
- 状态：可合并（流萤一期；二期、三期另派）
- 基线：从 `cc/newsrc-switch` 21cd90eb 切出；工作树 `.claude/worktrees/relaxed-cori-c96dcd`。`generated/` 先克隆集成分支工作树（recursing-shamir-4cd3d8）那份，再 `xiyou_export.py --app …/冻结正式源/v0.62.12/app.nw` 重出（切片加了 179 与 Codex_Sam_SV）。探针显式设 `XIYOU_APP=…/v0.62.12/app.nw`。
- 本分支的 `新建工作树.sh --补齐` 转换那步不认 `XIYOU_APP`，读到旧源 `冻结正式源/app.nw` 后报 Map234 缺失失败；转换要显式传 `--app`。
- **依赖**：切片加了角色 179，`generated/oracle` 要按新切片同步一次才完整（slice_d2、actor_passive、help_card 等通用参照会自动覆盖 179）。本分支没跑整份同步，见「交接板」。

## 盘点（开工时报协调，协调批了分三期）

新源 `installLiuyingRuntime.js`（850 行，运行时 1.2.0，modules.json 第 34 个）对集成分支 21cd90eb：重制里只有 O-212／setHp 遮挡那段，其余 12 块都没有。

| 块 | 内容 | 期 |
|---|---|---|
| 1 | 公式 CodexLiuying.damage＋AI 估值 | 一 ✓ |
| 2 | 伤害钩子 liuying（赤染、紫焰、法宝、终伤、失熵、星河、飞萤、自身减伤） | 一 ✓（印记易伤、萤火、单目标、扩散在二期） |
| 3 | 必中、段数 | 一 ✓ |
| 4 | 击破印记（叠层、引爆真伤＋强制眩晕、不可驱散、易伤、减疗） | 二 |
| 5 | 施放流程（天火付费转护盾走护盾账本、燃烧护盾与回满、冷却、再释放、单目标额外段） | 二 |
| 6 | 能力值、护盾效果、再动、逐火 | 一 ✓ |
| 7 | 萨姆形态、负面免疫、免死 | 二（形态图 Codex_Sam_SV 本单已进切片） |
| 8 | 招募＋号角 3063 上架 Map132 | 一 ✓（上架是八戒 bajie-newsrc3 做的，已在集成分支） |
| 9 | 读档／升级学忘同步、学 10628 连带梦应 | 一 ✓ |
| 10 | 梦应归于何处·萤火印记 | 二 |
| 11 | 说明按阶生成、技能名品质色 | 三（界面） |
| 12 | 萨姆残核掉落 | 三（掉落或 rules） |

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】换源集成：流萤 179 第一期（招募、公式、伤害钩子、能力值、逐火、学忘）、说明卡 10326（dev.待定）

- 跟到 v0.62.12 `installLiuyingRuntime.js`（v0.60～v0.62.08，见 `冻结后改动盘点_v0.29-v0.62.12.md` 第 104、105、110、112 行）：新模块 `core/liuying.gd`（XLiuying）。
  - 公式 `CodexLiuying.damage(a,b,id)`：转换器 `MODULE_FORMULAS` 把 10622／10623 记成 `liuying`，`XFormulaExecution` 调 `XLiuying.formula`：round((基数＋最大生命×3000＋攻击×3888＋敏捷＋护盾×3888)×0.7)，≤0 为 1。护盾取施放前快照（二期写），没有就取 `XShieldLedger.total`（原版 a.shield getter 含账本）。AI 估值（CodexAIEstimators）接进 `XSmartAI._safe_damage`。
  - 伤害钩子并进 `XActorDamageHooks.capture`；赤染之茧的火元素穿透 33% 写在 `XDamage` 建帧处（`resistancePierceByElement` 不在钩子可写字段里，`XLiuying.pierce_by_element` 取较大值）。物理受伤率穿透原版是 max(原值, 0.33)，流萤这两招别的钩子不写它，重制直接设 0.33。
  - 必中、不闪避在 itemHit／itemEva 最外层（原版第 34 个，在云裳、甚尔之外）；段数在 numRepeats 最外层。
  - 能力值：param 包在云裳夹值之外、异化之内（`XActor.param`），所以 99999999 上限乘过倍率会超（参照 hook.ziXian 249999997）；paramPlus／actionPlusSet 走 `XActorModules`；shieldEffectBonus 加在 `XBattler.shield_effect_bonus`。
  - 逐火：`XBattleLogic.grant` 末尾（gainRewards 包装），存 `state_data._codexLbEmber／_codexLbEmberWins`（随存档）。缺胜场字段时按生命÷10 估一次，估完写入、之后不再重估（总装 11-06 要求，测试覆盖已有胜场不被改写）。
  - 学忘同步：`levelUp`／`levelDown`（`XActorModules`）、`change_level_mv` 末尾（原版包 changeLevel，同级也同步）、读档（`XState.from_dict`，extractSaveContents 包装）；learnSkill 学 10628 连带学梦应（`XActor.learn_skill`）。每次都是按等级、进阶的幂等整理，不是一次性迁移。
  - 招募：公共事件 9043 `CodexLiuying.recruit();`（`XMvScript` 语句分支，超强者门槛同别的角色）；`_RECRUITMENTS`、`_module_recruit`、`XItemMarks.RECRUIT_HORNS` 加 3063→179。
  - 战力：`XPower.formula_ok` 认 `CodexLiuying.damage(a,b,N)`（原版 compileFormula 换成 1）。天火要剑（requiredWtypeId1＝2），新开局的流萤没武器，所以战力覆盖记「当前条件不可用」，不再是「尚未完整评估」（ui-newsrc2 转来的 status_power_panel 那项）。
  - 切片：actors 加 179（Codex_Liuying_SV、头像、行走图随角色导出），extraImages 加 `sv_actors/Codex_Sam_SV`（萨姆形态，二期用；界面 DE 的 actor_book 立绘那项要它们）。
- 说明卡 10326 铸环守：新源 `installDisplayPreferencesRuntime` nowGrowthRows 新加了 10326 一条（护盾系数＝成长权重曲线、保底比例 10%～30%，按屠苏等级），`character_help._tusu_xuan_growth_rows` 补上。同函数里别的条目新源改了措辞（「成长权重」→「护盾系数」等），归界面 DE，本单没动。

## 结果（本机，新源）

| 场景 | 前（21cd90eb） | 后 |
|---|---|---|
| liuying（新） | 89/153（旧代码上：学忘、能力值、逐火、招募、战力挂） | 144/144 |
| help_card | 934/1073 | 935/1073（10326 对上；其余是界面措辞、装备战力行） |
| actor_p0 | horn_paths_all_covered 挂 3063 | 号角路径与招募装备过；剩 `oracle_row_179`／`oracle_damage_179`：slice_d2 参照没有 179，要同步 |
| actor_p0（本机把 `XIYOU_PROBE_ACTORS=179 slice_probe.cjs 2` 的 179 行并进 slice_d2 临时验） | — | 3527/3527（验完换回原参照） |
| rules_d2（`RULES_ONLY_ACTORS=179`，同上临时参照） | — | 2555/2555（slice_probe 179 难度 2：3521 条伤害行、0 错） |
| actor_book | 179 立绘挂 | 179 sprite 对上（剩的是 DE 那几项，含「179 技能表」） |

- 先挂后过：测试提交 431798ad 在实现之前；把实现改动换回 21cd90eb 的代码（保留 liuying.gd 让测试能编译）跑出 89/153。

## 验证

- 语法检查 0 问题。工具回归挂「插件备注覆盖」1 项（豁免键 `codexaura` 不在插件标签里；它只读插件与豁免表，不读本分支改的文件，设 XIYOU_APP 也一样）。
- `事件空绿扫描.py --check`：挂 5 条，都是 `m234e22／26／45／46／49p0#a1 在预设里但 event_states.json 没量`（新地图 234 的状态探针要同步，克隆来的产物没有），不是本单。
- 云端选测（提交 a6ecdb53，基准 21cd90eb，411 个场景，[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42247745884)）：89 个挂。与集成分支 7520680b 整轮（111 个挂）比，**没有新挂的场景**，少挂 22 个（alien_affix、casino_batch、enemy_book、power、status_power_panel、map132_shop、script_census 等，多半是 21cd90eb 合进来的单子修的）。云端那次在 Codex_Sam_SV、actor_p0 两个提交之前，这两个之后本机跑了 actor_p0、actor_book。
- 探针 `liuying_probe.cjs` 关了五乘区（`CodexZones.ENABLED=false`，O-044 不移植；不关时专武品质 9 让成长修正 ×1.31，hook.weapon／hook.all 两例对不上）。探针登记检查认它（夹具名对得上）。

## 交接板

- 下一步：
  - 同步：本分支切片加了 179，合并后的整份同步会给 slice_d2、actor_passive、help_card 等参照加上 179。之后预计：actor_p0 两条过；help_card 会多出 10622／10623 两张卡挂（新源说明由 `L.refreshText` 按阶生成，是三期 11），wtype 等通用参照也可能带出 179 的项。三期的「说明按阶生成」建议提到二期之前做，或先交界面。
  - 流萤二期（印记、施放流程、形态与免疫免死、萤火），探针沿用 liuying_probe 的写法加例。
- 需要用户决定：无（一期全照原版，没有新开关）。
- 用户试玩说明：无（集成分支）。

## 进度账

- 无变化（流萤一期是扩展账「冻结后改动」的一部分，二期、三期完成后一起记）。

## 可回退

- 本单没有新开关：都是照搬原版新行为（新角色本来不存在）。setHp 遮挡已由 O-212 管，没加开关。

## 可优化（流程／工具／效率）

- `新建工作树.sh --补齐` 的转换那步应该认 `XIYOU_APP`（或集成分支默认读 v0.62.12）：现在在集成分支上开车道，补齐必失败，要手动克隆产物、显式 `--app` 重出（newsrc8 交付单也记了）。tools80 在 main 上改了 xiyou_export，集成分支还没合。
- 云端结果 result.json 只有失败场景名、没有各场景的通过数，比对「同一场景挂得更多」要翻日志；建议 report 把各场景 passed/total 写进 result.json。
