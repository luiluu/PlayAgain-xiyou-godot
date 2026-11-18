# 交付：luiluu/t187

- 车道／工作者：T187 期四 live 状态铺开：重分类＋归池／停用＋expires 收口（cc，Opus＋medium）
- 状态：可合并（R1 返修后；行为开关 POOL_LIVE 产品默认关、期四总开关开着就开；K 不复量，归 T192）

## 变更记录草稿

## 2026-11-18 【cc·未经审查】T187 期四 live 状态铺开：重分类、固定 ×k 增伤 43 个归池或停用、秘籍格合并封顶（dev.待定）

依据：T185 样板（dev.714）交付单「铺开前要先做的重分类」；D203（Kyo 11-18 08:4x）：①增伤一律归池 ②洪荒来源挪 never ③秘籍格每本单独封 ＋8。

- `damage_ledger.json` `state_confirm_class`：live 154 个拆开——
  - **挪进 never 55 个**（各带回退开关）：卡已删挂状态标签的技能 20 个、装备卡 4 个（开关 `CARDS`）；删除栏位装备 12 个＋由它们连带挂的星神护符状态 9 个（1712～1714、1717～1720、1722、1726，状态号连带关系已从状态表核实；开关 `GEAR_SLOTS`＝XTianqiGear.ENABLED）；洪荒来源 8 个（1254、1257、1261、1266、2675、2679、1279、1281，开关 `NO_HONGHUANG`）；2709／2711 来源技能号 7241／7243 天启篇给了号卷、备注整个改写（开关 `TRUMPET`＝XTianqiTrumpet.ENABLED）。
  - **pool 表 43 个**（原 `sample` 10 个并入）：确认阶段固定 ×k 的增伤（mul，或只有加成段的 value_steps）。42 个归池 ＋add%（add＝k−1 的整数百分数），cap：秘籍格的书 10 个（带 `book`）、装备 9 个（九线）、角色桶和机制 23 个（不封）；1 个停用（2300 天顶剑）。
  - **reduce 23 个**：×k<1 的挑战、惩罚机制（神魔压制、终伤折算、欠债结算、强者压制等），永久允许。
  - **suit_pooled**：713 铁头娃II 走套装行（POOL_SUIT 期二已进③）。
  - **live 只剩 32 个**：确认阶段是程序、脚本、查询或带暴击专属段的，不是固定 ×k，留 `state_confirm` 豁免（期五到期）。
  - rows：新增 `state_confirm_pool`（pooled，开关 POOL_LIVE）、`state_confirm_reduce`（allowed）；`state_confirm` 行改写说明＝收口到 32 个。
- `tianqi_ledger.gd`：样板逻辑改读整张 pool 表（`live_table`／`live_pool_effects`）；认 value_steps（skipTypes 加在组上）；秘籍格同一本书的几个状态先合并封 ＋8%，再由 `apply_nine_cap` 和这本书上已有的③增伤合并封顶、并进秘籍格排序（`_with_live_books`，只在副本上加，不改被动缓存；T185 P3-1）；`reload()` 清 `_live_table` 等缓存（P3-2）；`confirm_source` 认 pool／reduce；`switch_on` 加 CARDS／GEAR_SLOTS／NO_HONGHUANG／TRUMPET，POOL_LIVE 改成「POOL_LIVE or XTianqiBase.PHASE4」。
- `damage.gd`：九线封顶钩子多传 `live_books`（读 `live.get("books", {})`，发行空壳返回的旧形状也不出错）；`state_effects.gd` 只改注释。
- 专项：`xiyou_tianqi_live_sample` 重写成整表（17 条）；`xiyou_tianqi_ledger` 覆盖检查认 pool／reduce／suit_pooled、never 开关名单加四个、新两行状态；`xiyou_tianqi_no_diff_passive` 人为挂 1254／2709 比连乘那段开 QUIET（这两个现在是 never，守卫会报）。反向验证：去掉秘籍格合并 → secret_merged_cap 失败；不认 value_steps → pool_shape、value_steps_pooled 失败；reload 不清缓存 → reload_clears_cache 失败。
- 验证：`语法检查.py` 0 问题；`并行测试.py` xiyou_tianqi_*、xiyou_state_effects*、xiyou_combat、xiyou_custom_damage、xiyou_formulas、xiyou_state_js、xiyou_pushstate、xiyou_passive、xiyou_determinism 共 89 个场景：88 过、xiyou_tianqi_no_diff_passive 守卫报错（修后与 live_sample、ledger、trumpet 四个复跑全过）；`发行空壳.py check` 678 个函数都有。没跑：`选测.py` 列的其余战斗核心场景（xiyou_rules*、事件对照等）、`--oracle`、虚拟玩家 climb——PHASE4 关着时新代码第一句就返回。

## 交接板

- 下一步：T192 在 PHASE4 开着（POOL_LIVE 跟着开）下复量 K；live 剩 32 个程序／脚本类另开卡逐个读程序（见下表）；文案草稿过小A。
- 用户试玩说明：无（期四总开关默认关）
- 需要用户决定：无新增（见「要 Kyo 定」）

## 进度账

- 无

## 开关默认值的判断

POOL_LIVE 没有单独翻开，跟期四总开关走（`POOL_LIVE or XTianqiBase.PHASE4`，和角色卡 `cards_flag` 同一写法）。理由：口径 D203 已定，再单独关着就要多记一个「期四开了但 live 没开」的中间态；期四其余改动都还挂在 PHASE4 下默认关，live 单独先开会让现行档的数在 K 复量前就变。T192 开 PHASE4 复量 K 时这批自然带上；要单独回退把 POOL_LIVE 判断改回只认自己即可。

## 可优化（流程／工具／效率）

- 发现：类外写 `XTianqiLedger.reload()` 调到的是 Godot 内建的 `Script.reload()`（整个脚本重载、所有开关回默认），不是总账自己的静态 `reload()`。工程里 7 处都在测试里，碰巧效果更狠所以没出错；但专项若在 reload 前改过开关，会被悄悄复原。建议另卡把静态函数改名（如 `reload_table()`），涉及测试 7 处；本卡只在新专项里改用实例调用并写了注释。

## 要 Kyo 定

- 无新增。下面两条是我按 D203 精神自己定的，Kyo 不同意就改表：
  1. 角色自带被动、战技挂的增伤（贝吉特超赛 ＋150～＋500、剑气滚龙壁 ＋500、剑*非天 ＋150 等）归池后算角色桶、不封顶（角色桶本来就不在九线封顶里）。数大，K 复量时会看出来。
  2. 712 铁头娃、2718 紫炎没扫到来源，按同名一族（套装、装备）算九线。

## 剩下的 32 个（程序／脚本类，留豁免）

1062、1352、1421、1422、1424、1522、1642、1747、1834、2522、2556、2559、2568、2583、2731（技能）；38、50、97、1661（装备）；1259、1666（状态挂）；543、719、1310、1401、1406、1441、1703、1707、1730、1733、2803（没扫到来源）。其中 1352、1747 是原版语法错误（不生效），1062 只关暴击不改伤害，1522／2556／1406 有暴击专属段。1441／1730／1733 名字像星神护符（欢愉、纯美、开拓），没核到连带关系，没挪。

## 41 个没扫到来源的（验收第 7 条）

没跑：等 T162 守层者表量完、期四 climb 能爬深再跑 `confirm_seen`。这次重分类后其中 8 个（护符连带）已核实挪进 never，2 个洪荒档挪 never，12 个固定 ×k 进 pool 表，8 个缩小类进 reduce，剩 11 个在 live。

## 文案草稿（待小A 审）

归池、停用后原描述「结算伤害×1.2」「造成的所有伤害结果*110%」不再准确。说明文字都在原版技能、装备备注和 `skill_rework.json`（T191 独占）里，本卡没接线，只出草稿：

- 归池（技能、装备，不封）：「效果：伤害加成 +20%」（数＝pool 表 add）
- 归池（秘籍格的书）：「效果：伤害加成 +20%（秘籍格每本伤害加成最多 +8%）」
- 归池（装备，九线）：「神话特效：伤害加成 +30%（装备、套装、种族、宝珠的伤害加成合计最多 +35%）」
- 停用（天顶剑）：武器下架另卡，不出文案。
- 挪 never 的（删除栏位、洪荒、卡已改写）：天启篇里看不到，不改。

## R1 返修（小A 核查报告 R1）

- P1-1：2739 极光剑一*破、2761 真正的天锁斩月挪出 pool 进 never（CARDS）——唯一挂它们的是武器 4003、70 的 StartPushState，装备卡已删；技能只读不挂。顺手把 pool、reduce、live 全部 134 个按「所有备注来源都被卡删掉」扫了一遍（Skills／Weapons／Armors／Items／Enemies／Actors／Classes／States 的 *PushState 标签对 skill_rework.json 的 note_remove），只有这两个；1770 的技能来源被删，但状态 1764 还会挂，留 reduce。
- P2-1：1454 智识2 没核到来源：护符 4975 智识的演算只挂 1450 智识1，1450 也不挂 1454；转换数据表的备注和效果、地图与公共事件的加状态指令、插件参数、Godot 代码都扫过，找不到任何挂它的地方。按小A 的建议把 1669、1766 也补核了，结果一样（插件里的 1669 是 EMosaicZID，不是状态号）。三个都挪进 never，开关新加 NO_SOURCE（恒开、没有回退）：天启篇里出不来，真出现就说明漏扫了来源，守卫当场报，比按角色桶不封顶留在 pool 稳。
- P3-1：1722 原写「由状态 1714 挂」是笔误：扫到的是 1714 程序摘要里的哈希串，还有 2776 预约的公共事件 1722，两处都不是挂状态。护符 4969 记忆的碎片也不挂 1722（备注只有技能伤害、消耗标签），所以改挂 NO_SOURCE，理由照实写。这一条和报告说的「对应 4969」不一样，见回执异议。
- P3-2：文案草稿的全角「＋」改成半角带前导空格。
- 改后 pool 38 个（37 归池、1 停用），never 新增 60 个（共 67 个），缩小类 23 个，live 32 个。

## 本分支提交

- 97b586aa4 WIP: T187 期四 live 铺开：重分类、固定 ×k 增伤 43 个归池或停用、秘籍格合并封顶、reload 清缓存
- 2014cca20 T187 2709／2711 改挂号卷开关 TRUMPET；无难度被动专项人为挂因果丝线时总账守卫不报
