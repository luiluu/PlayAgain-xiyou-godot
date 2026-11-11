# 交付：cc/tianqi-swap-init

- 车道／工作者：天启篇·换人开战初始化（审查 78 P3-1）／cc（项目线程「完成再刷西游Godot引擎重制」，本机工作树 unruffled-mendel-f95b6d）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·天启篇·未经审查】天启篇战斗中换人：换上来的助力位补开战初始化（dev.待定）
- 审查 78 P3-1（协调转，优化默认接受）：第二批的战斗中「换人」把助力位直接换上场，没做出战成员开战时才有的初始化。
- `XBattleLogic.tianqi_swap` 换完调新的 `_tianqi_enter`：初始 TP（和开战一样随机 0～24，保留 TP 的不动）、技能预热按开战重置（`start_warmups`）、开战状态标签（`StartPushState` 等，`_battle_start_states` 加了只处理给定名单的参数）、种族祝福本场数据（`XRaceBattle.state`，记此刻最大生命）。
- 不重做的两项：开战「battle」状态块在开战时本来就按全队（`state.members()`，含助力位）跑过；心钢蓄力（`XHeartsteel.start_battle`）也按全队建，助力位不行动就一直是开战的 2。
- 开关 `XTianqi.SWAP_INIT`（默认 true）；false 回到第二批，换上来什么都不补。
- 新专项 `xiyou_tianqi_swap_init`（15 项）：开关开时 TP 重置、旧预热清掉、开战状态（普通难度被动的 1631）加上、种族数据建好、心钢蓄力开战已建；开关关时 TP、预热原样、不加开战状态。
- 玩家可见：天启篇战斗里「换人」换上来的伙伴和开战就在场的一样：TP 从开战的初始值起、技能预热重新算、开战触发的被动状态照样挂上。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇战斗中换人，换上来的伙伴开战被动（如开场挂的状态）会生效、TP 从初始值起。
- 需要用户决定：无

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·换人开战初始化 | `modes/xiyou/battle/battle_logic.gd` `_tianqi_enter`；`core/tianqi.gd` `XTianqi.SWAP_INIT` | 原版没有助力位换人；第二批换上来不做开战初始化 | 换上来的助力位补初始 TP、预热、开战状态标签、种族本场数据 | 审查 78 P3-1；Kyo 11-11「优化直接接受」 | `XTianqi.SWAP_INIT = false` | cc（天启篇） | 保留 |

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- 无

## 验证

- `语法检查.py`：0 个问题。
- 本机专项：`xiyou_tianqi_swap_init` 15/15、`xiyou_tianqi_party` 33/33。
- 云端整轮选测（c93c2827e，510 个场景、16 片）全过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43012776806

## 待交叉核查

- 甲档：`battle/battle_logic.gd`（`tianqi_swap`／`_tianqi_enter`、`_battle_start_states` 加参数）。
- 乙档：`core/tianqi.gd`（开关）、专项。

## 本分支提交

- 1a42738cc 换上来的助力位补开战初始化＋专项
- c93c2827e 交付单（进行中）
- （本提交）交付单：可合并
