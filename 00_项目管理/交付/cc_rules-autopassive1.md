# 交付：cc/rules-autopassive1

- 车道／工作者：C 规则／八戒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-10 【cc·八戒·未经审查】自动被动状态：原版插件停用、不移植；套装状态接上后按优先级再排（dev.待定）

- 接 rules-passive-order1「没做的」第 1 条（YEP_AutoPassiveStates 没移植）。查下来那条判断不成立：正式源 `js/plugins.js` 里 YEP_AutoPassiveStates 是 **status:false**（v0.28 与 v0.62.12 都是），`main.js` 只载入启用的插件，没有别的地方载它。原版实测（新探针 `mv_oracle/auto_passive_probe.cjs`）：`Imported.YEP_AutoPassiveStates` 为假，`passiveStates`／`passiveStatesRaw`／`meetPassiveStateCondition` 都不存在，数据对象的 `passiveStates` 字段也没解析；护摩之杖 79、般若 49／3834 装上，终级平A 7769 学会（含战斗中），`states()` 里都没有 1640／2498／1347。所以重制不加被动状态是对的，不移植、不登 O 号。依赖它的几处（krz_state_re 的缓存包装、GT_EquipSuitCore 套装状态的被动条件检查）在原版也都走「没有这个插件」的分支。
- 查 states() 顺序时发现一处真偏差：GT_EquipSuitCore 的 `states()` 接上套装状态后调 `sortEquipSuitBonusStates`，整表按优先级降序再排（V8 稳定排序，同优先级保持原先后）。套装状态几乎都是优先级 50（一个 60），所以身上有优先级低于 50 的普通状态时，原版套装状态排在它前面；重制一律接在末尾。改：`XActor.states()` 接上套装状态后同样按优先级降序稳定再排（已有序时不动）。这是对齐原版，不登 O 号、不加开关。上一期交付单里写的「末尾接套装状态」不对，以本条为准。
- 影响：states() 顺序会影响按状态先后取第一个的地方（如普攻替换按「状态→装备→技能」找第一个）、状态效果执行先后和概率附加状态的掷骰先后；只在「装着带状态的套装、同时有优先级低于 50 的普通状态」时才和以前不同。
- 玩家可见：无明显变化（极少数套装＋低优先级状态同在时，状态生效先后与原版一致）。
- 验证：新专项 `xiyou_auto_passive` 33/33（插件停用读数；全部数据里带 `<Passive State>` 标签的 6 个对象清单逐个比，换源后多出标签会报；三件装备、一个技能拿到手后 states() 逐个等于原版；套装 8 缝合小刀（防具 487→状态 38）与普通状态 170／11／27 四种组合的 states() 顺序等于原版）。反向验证：把排序去掉，`suit.lower_order`、`suit.mixed_order` 两项失败。语法检查 0 问题。云端选测 416 个场景通过；工具回归通过。

## 交接板

- 下一步：YEP_AutoPassiveStates 不用再派（原版停用，见本期变更记录）。
- 用户试玩说明：无。

## 进度账

- 战斗规则：不改百分比；补依据「YEP 自动被动状态原版停用、已核；套装状态排序对齐」。

## 验证

- 专项：`xiyou_auto_passive` 33/33（本机）。
- 选测：`选测.py main --list` 因改了 `actor.gd` 选中 284 个场景（战斗核心），走云端选测：提交 3ffd6c3def 云端选测通过，416 个场景、15 片（基准 ba19e0ed34，上次云端通过的祖先；含 `xiyou_rules` 全部段、`xiyou_determinism` 等战斗核心），运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42838690384。
- 工具回归：`工具回归.py` 全部通过（65 秒）。
- 补齐时总装正在合并、参照没刷新（云端选测提示）；本期没改切片／转换器，只新增一个独立探针（不进同步），合并时不用重同步。

## 没做的

- **战力有一处与原版不同（战力先藏，按派单不做）**：`core/power.gd` 的 `passive_states()` 会把装备／技能的 `<Passive State>` 状态算进战力；原版战力（installCombatPowerRuntime）读 `obj.passiveStates`，因插件停用这个字段不存在，实际不算。重做战力时去掉这段即可（受影响的只有护摩之杖、般若、终级平A 三类）。
- 状态 1068／1069 备注里的 `<Passive State: 暴击触发>` 等是非数字参数，即便插件启用也不解析，不用管。

## 可优化（流程／工具／效率）

- 建议：派单写「移植某插件」前先看 `plugins.js` 里它的 status（停用的插件代码也在 `js/plugins/` 里，备注标签也还在，容易当成生效）。`插件备注覆盖.py` 已经跳过停用插件（`load_plugin_sources` 的 status），所以这条缺口本来就不在它的报告里，是手查时误判；派单前对一下这份报告即可，不用改工具。

## 本分支提交

- （见 git log cc/rules-autopassive1）
