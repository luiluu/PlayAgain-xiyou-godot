# 交付：cc/tianqi-ledger-p3

- 车道／工作者：C 规则·数值线「伤害加成总账·期三 回合预算、丹药下架、九线封顶」（cc 车道，Orca task_b05912ecb6ac，T011，Opus＋medium：战斗核心总账、碰多动入口和存档兼容，甲档，交小A 核）
- 状态：可合并

依据：私密设计仓 `重制设定/天启篇_伤害加成总账_v0.4.md` 第五节第 2～5 条、第八节期三行、「期二交付补记」1～4、第十节。回合预算调用点清单用期一交付单那张（本单逐条接，见下）。数值表一个数没改（`balance_table.json`、`qiyin_gear.json` 都没动）；新加的上限数全是稿子定的（+15%／+30%／+35%／+30%／每格 +8%、6／4／3 格、每回合多 1 次）。

## 结论

- 三样都落地，各一个回退开关（默认开，只对天启篇存档）：`XTianqiLedger.NO_PILLS`（丹药下架）、`CAP_NINE`（九线封顶）、`TURN_BUDGET`（回合预算）。总账表 `damage_ledger.json` 进期三（`phase` 3），加 `nine_caps`、`derived`（派生攻击每回合次数表）、`turn_budget`（接了预算的入口），新行 `qiyin_dot`。
- 期二补记四条：1 种族混合招固定一半——期二已按此实装，断言 `xiyou_tianqi_ledger p2_race_demon`（混合 0.15＝物理 0.3 的一半）；2 七印派生系数不归池——`qiyin_derived` 永久允许、加 `phase3` 口径，派生攻击不占出手预算、系数就是表里的「伤害比例」（`note2_qiyin_derived_allowed`）；3 白印持续伤害 ×1.2 保留、不封——新行 `qiyin_dot` 永久允许（`note3_qiyin_dot_allowed`），九线封顶不碰疫；4 暴击敏捷常驻规则保留 O-421 判定——期二已实装，断言 `xiyou_tianqi_difficulty_passive bites_*`、本单没动。
- T004 P3-1：`audit_confirm` 原来凡带 `skipTypes` 的确认阶段效果都放行，改成只认 `suit_confirm_rows` 打的标记 `SUIT_POOLED`（`confirm_skiptypes_not_free`）。
- 西游档不变：三样都先判 `active()`（天启篇存档）；专项各有一条西游档断言。

## 实际改的文件

`tianqi_ledger.gd`、`damage_ledger.json`、`percent_pills.gd`、`item_marks.gd`、`tianqi_qiyin_effects.gd`、`tianqi_affix_battle.gd`、`battle/battle_event_runner.gd`、`battle/battle_logic.gd`、`tianqi_skills.gd`、`actor.gd`（`param_rate` 一行）、`gojo.gd`、`yomi_jingliu.gd`、`liuying.gd`、`race_battle.gd`（专属模块／九九六插队几处）；派单清单外两处：`damage.gd`（九线封顶一行调用，伤害帧钩子之后）、`ui/item_scene.gd`（「使用」后加「（天启篇已下架）」提示，一行）。没动 `zhenqi.gd`、`tianqi_trim.gd`（道法连击／分神属「九线多动停用」，见「没做的」）。新专项 `tests/xiyou_tianqi_ledger_p3`；改了 `tests/xiyou_tianqi_ledger`（期数断言、P3-1 断言、期二段落关封顶）。

## 一、丹药下架（第五节第 3 条）

- 下架范围：1497～1500（万灵增元丹类）、1685～1700、1702～1717（一品到四品）、1726～1728（养神、融灵、破厄）、2882～2887（淬元丹）。商店滤掉（`XItemMarks.shop_goods` 末尾，淬元丹追加之后再滤）；「使用」不可用（`can_acquire_item`）并在指令后提示「（天启篇已下架）」；背包里已有的不删不收。
- 已吃的：淬元丹计数留在存档里、天启篇 `XPercentPills.param` 不读，也不能再吃；万灵增元丹被动期二已不生效；一品到四品进了永久加值合计、剔不掉，照算（稿子口径）。
- 旧档：带 10 颗淬元丹计数存、读，不报错、计数原样、属性不算（`pill_old_save_loads`）。开关关回原样（`pill_switch_off`），西游档照旧（`pill_xiyou_same`）。

## 二、九线来源临时封顶（第五节第 4 条）

`damage._calculate` 在钩子之后、算乘区之前调 `XTianqiLedger.apply_nine_cap`，只扣超出的部分，扣的量记在伤害详情 `row.nineCap`（「九线封顶」）：
- 秘籍格：格数读档位行 `secret_cap`（6／4／3），每本书每个池最多 +8%；学多了按「各池封后最大值相加」从高到低取前几本（同分书号小的先），其余不算——临时规则，第一期秘籍格做出来换正式占格。被动分桶在秘籍那桶并排按本记了一份（`bySource.books`，桶名 `#技能号`）。
- 其余九线（符文之语、宝珠、原版装备与套装、种族、成长装备、真气）：①技能池合计 +15%，②元素池每一系 +30%，③伤害加成池 +35%（包括种族祝福、宝珠共鸣两个钩子这一下进③的量和套装确认阶段 +(k−1)）。④暴击只封秘籍（稿子没给其余九线暴击的数）。
- 属性 +30%：`XActor.param_rate` 末尾乘 `param_cap`：原版套装属性倍率 × 符文之语／成长装备上的属性倍率特性，超过 1.3 压回 1.3。
- 套装状态现在单独分桶 `suit`（原来混在 `state`）。

## 三、回合预算（第五节第 2 条）

入口 `XTianqiLedger.take_extra(logic, u, 来源, recast, in_action)`（设计稿写在 `XTianqiSkills`，我放进总账模块，和其他总账开关、表一起，省得 `tianqi_skills.gd` 多一份状态）。算法不另存「已用几次」：本回合已行动＋顺序里还排着的－1（掷出的再动、九九六、插队都在顺序里，自然算进去）＋直接再释放的次数，小于 `max_extra_actions`（1）才给。只管我方角色；骑士、怪物照旧；不进存档（记在战斗对象 meta 上，按回合号换）。

| 类 | 入口 | 怎么接 |
|---|---|---|
| 追加行动 | 七印击倒再动 `qiyin.kill_extra_action`、五条悟六眼 `gojo.again`、镜流 `jingliu.extra`、人族九九六 `race.human996`、技能卡 `free_action`（造成伤害的 `card.free_action`；不造成伤害的 `note_free`、不占） | 先问，给了才 `push_front`／插入 |
| 再释放 | 词条 `affix.recast`、震印放两次 `qiyin.double`、公共事件再释放三种 `event.recast`／`event.freeze_followup`／`event.push_recast`、流萤 `liuying.rerelease`（行动中途问，`in_action`） | 先掷原来的几率，再问预算（随机数次序不变） |
| 醒来补排 | `battle_logic._sync_orders`／`_insert_orders` 当前回合 | 不重掷，次数＝1＋1－已行动－已用再释放；下个回合照原来 |
| 派生攻击 | 七印连斩、横扫、再射走 `take_derived` 按表每回合次数（18／2／2，都是「每次行动的原上限×2 次出手」，不改实际上限）；补刀用装备表原有 per_turn；专属模块 7 处登记为模块自管、期四到期 | 不占出手预算 |
| 连击段数 | 不动 | 不占 |

专项扫 `tianqi_qiyin_effects.gd` 每个 `_derived` 调用点都要带 `# derived:<来源>`／`# recast:<来源>` 且来源在表里有次数（`derived_sites_registered`），接预算的文件都真调了入口（`budget_sites_wired`）。

## 我不同意的地方

1. **补记 1「混合招固定一半」我同意**：期二对照里混合招都没出现差（32 队次的差全是技能专属被动），没有实测依据要改攻防权重。虚拟玩家对照的 5% 门槛本期没量到（基准队没有魔族／神族混合招主力）。
2. **九线封顶的「④暴击」稿子只给了秘籍**：其余九线的爆伤（宝珠、套装的 `passiveCrHarmRi`）现在不封。请设计稿补一句要不要封、封多少。
3. **属性 +30% 只封得了一半**：宝珠镶进装备的属性、原版装备本身的属性倍率合在装备实例的特性里，分不出来源，没封；真气的属性加在别处也没算进。等宝珠、真气三期重做时自然解决，现在先登记。
4. **「九线来源停用」（特性 34／61、`<passiveAPLUS>`、道法连击分神、符文之语再释放）本单没做**：第八节期三行只写了第五节第 2～4 条，这块在第 2 条表下面、但改的是 `zhenqi.gd` 和装备特性，量不小；回合预算已经把它们的效果压在「每回合多 1 次」以内（掷出的再动占预算）。建议另开小单（Opus＋medium），不然期三拖太长。

## 没做的

- 小A（T035 核查范围外 P3，协调转来）：七印 `end_action` 里的 `_derived`→`logic.apply` 没切弱者专属词条的 DERIVED 种类，补刀也是。本单派生预算按来源计数（`take_derived(logic, u, "qiyin.…")`），不按种类，所以**本单不漏记**；切种类会改弱者专属词条在派生一击上的触发（那张表归 T035），没顺手改，建议归弱者词条车道一并看。

- 九线来源停用（见上 4）。
- 虚拟玩家养成存档的满养成队开关对照（同期二）。

## 变更记录草稿

## 2026-11-16 【cc·伤害加成总账期三·未经审查】天启篇伤害加成总账期三：回合预算、丹药下架、九线来源临时封顶（dev.待定）

- 设计仓《天启篇_伤害加成总账_v0.4》第五节第 2～4 条：我方每人每回合最多多 1 次完整出手，追加行动（七印击倒再动、五条悟六眼、镜流、九九六、技能卡造成伤害的 free_action）和再释放（词条、震印放两次、公共事件再释放、流萤）共用，统一入口 `XTianqiLedger.take_extra`；昏迷醒来补排当前回合不重掷；七印派生攻击按表每回合次数。丹药 1497～1500、1685～1717、1726～1728、2882～2887 天启篇下架（商店不卖、使用不可用并提示、淬元丹已吃的不读）。九线来源进池封顶：秘籍格按 6／4／3 格、每本每池 +8%，其余九线①+15%、②+30%、③+35%、属性 +30%，伤害详情标「九线封顶」。
- 总账表进期三：`nine_caps`、派生攻击次数表、新行白印持续伤害（永久允许）；确认阶段运行期守卫只认套装标记放行（T004 P3-1）。
- 只对天启篇存档，三个回退开关；西游档不变；存档字段零新增。
- 玩家可见：天启篇里丹药不能买、不能吃；同一回合「再动」和「放两次／再释放」只能触发一个；学了很多功法、堆了很多符文之语／宝珠／套装的角色伤害会变低。
- 验证：专项 `xiyou_tianqi_ledger_p3`、`xiyou_tianqi_ledger` 等，见交付单「验证」。
- 提交：（合并时填）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定-1 | `modes/xiyou/core/tianqi_ledger.gd` `take_extra`、`wake_times`、`take_derived`；七印、词条、公共事件、五条悟、镜流、流萤、九九六、技能卡 free_action、`battle_logic._insert_orders` | （天启篇）击倒再动、放两次、词条与公共事件再释放、模块插队各管各的，一人一回合可动三四次；醒来补排重掷再动 | 我方每人每回合最多多 1 次完整出手，统一入口；醒来补排不重掷；派生攻击按表每回合次数 | 伤害加成总账期三（第五节第 2 条） | `XTianqiLedger.TURN_BUDGET = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_ledger.gd` `pill_delisted`、`filter_pill_goods`；`percent_pills.gd`；`item_marks.gd`；`ui/item_scene.gd` | 丹药可买可吃 | 天启篇下架：不卖、不能用并提示、淬元丹已吃的不读 | 同上（第五节第 3 条） | `XTianqiLedger.NO_PILLS = false` | cc | 保留 |
| O-待定-3 | `modes/xiyou/core/tianqi_ledger.gd` `apply_nine_cap`、`param_cap`；`damage.gd`；`actor.gd` `param_rate` | （天启篇）九线来源进池不封顶，功法一本可 +200% | 秘籍格 6／4／3 格每本每池 +8%，其余九线①+15%、②+30%、③+35%、属性 +30% | 同上（第五节第 4 条） | `XTianqiLedger.CAP_NINE = false` | cc | 保留 |

## 交接板

- 下一步：伤害加成总账期四（骑士血量重标、倍率、开卡、专属模块到期）；另开小单做「九线来源停用」（上面「我不同意的地方」4）；设计稿补记 2、3 两条（九线暴击、属性封顶范围）。
- 用户试玩说明：天启篇里丹药不能买、不能吃；同一回合再动和再释放只吃一个；堆功法／符文之语／宝珠／套装的角色伤害变低。西游档不变。
- 需要用户决定：无。

## 进度账

- 天启篇数值线第 3 步（伤害加成总账）：期一、二、三完成，期四待做。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `检查.sh --oracle --affected main --cloud`（跑在 1805f9e1d，基准 main f052f6fb4）：云端选测 479 个场景、16 片**全部通过**；文档登记、参照守卫、MV 参照、同源都过；唯一失败项「发行空壳缺成员」（`take_extra` 没进放行名单、`hook_bonus` 没发行值）已在 92a76b4c1 补上，`发行空壳.py check` 通过（63 个脚本、568 个函数都有；`wake_times` 发行值 −1、`param_cap` 1.0、`apply_nine_cap` 空）。日志 `03_再刷重制_Godot/04_验证/总账期三/cloud_check.log`。
- 之后 `git merge main`（带进 T035 `cc/t035-guard-kind`，dev.639，无冲突），合后本机重跑受影响专项 12 个全过：`xiyou_tianqi_ledger`（67）、`xiyou_tianqi_ledger_p3`（32）、`xiyou_tianqi_affix_battle`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_skills`、`xiyou_tianqi_skill_debt`、`xiyou_tianqi_weak_affix`、`xiyou_determinism`、`xiyou_otb`、`xiyou_battle_common_events`、`xiyou_percent_pills`、`xiyou_item_marks`。合并前另跑过 `xiyou_gojo`、`xiyou_jingliu`／`2`、`xiyou_liuying`／`2`／`3`、`xiyou_race_battle`、`xiyou_yomi_battle`、`xiyou_bulk_pills`、`xiyou_tianqi_alien_affix`，全过。
- 数值卡 DoD（P2-6b）：`explore`＝专项 `xiyou_virtual_player` 通过；短帧 `climb`（种子 2、200000 帧、15.8 分钟）：**卡死 0、脚本报错 0（SCRIPT ERROR 0 行）、违规 0、收工金币 14500、全灭 3 次都经标题「旧的回忆」读档接回（存档读写正常）**、打了 47 场。注意：短帧爬塔停在第 1 层，还没进天启篇选线（第 5 层后），所以这一轮只证明西游流程没被弄坏，**没覆盖天启篇的回合预算／封顶**——这几样靠专项断言。日志里有 `skin_ring_nav.gd:550` 的渲染 ERROR 行（界面皮肤，不是本单代码）。小结存 `04_验证/总账期三/vp_climb_seed2_summary.md`。
- 工具回归 `工具回归.py` 全过；`回退开关覆盖.py` 没有新增缺口（三个新开关都在 `xiyou_tianqi_ledger_p3` 里设 false）。
- 慢／快车道：没改切片、转换器、探针，快车道。

## 待交叉核查

- 甲档（小A）：本分支全部提交。改到的核心文件：`battle_logic.gd`（`_sync_orders`／`_insert_orders` 两处）、`damage.gd`（一行调用）、`actor.gd`（`param_rate`）。请重点看：`extra_used` 的算法在「掷出两次」「插队后再释放」「行动中途问」三种时机是否都不多算少算；九线封顶只扣超出、不足的不加；西游档三样都恒不进。

## 本分支提交

- ce29a3e12 WIP：丹药下架、九线封顶、audit_confirm 收紧
- 093e9619b WIP：回合预算入口与各处接线、派生次数表
- 05867b68a WIP：专项 xiyou_tianqi_ledger_p3
- （后续见 git log）
